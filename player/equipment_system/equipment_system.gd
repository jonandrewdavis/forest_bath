extends Node3D
class_name EquipmentSystem

## A node that listens for signals from a player node to change equipment, or
## to activate and deactivate Area3D equipment nodes.
## When the 'change_signal" emits from the player node, the child #0 under
## the held_mount_point will reparent to the stored_mount_point, and same for
## child #0 of stored, will move to held. Handy for swaping objects from hand
## bones to back bones or similar.

## the Activate and deactivate signals will turn on and off monitoring for the 
## area3d children. Also if they hit things in the target_group they'll emit
## the hit_target signal, and if they hit anything else, they'll emit hit_world
## signal. Hitting target will communicate equipment and player_node info to the
## object receiving the hit.



## The node that will emit the weapon change signal
@export var player_node : CharacterBody3D
## The object group to detect 
@export var target_group : String = "targets"
@export var target_group_secondary : String = "cart"

## The signal name from player_node for when the item should be active.
## items themselves should manage what "active" means, but typically this is
## monitoring/collision shapes, emitters,sound FX, etc. 
@export var activate_signal : String = "attack_started"
## Signal to cancel if the collision monitoring of the held item.
@export var deactivate_signal : String = "hurt_started"
## The signal name should be connected to trigger the equipment swap
@export var change_signal : String = "weapon_changed"
## The primary item location. Bone attachments or Marker3Ds work well for placement
@export var held_mount_point : Node3D
## The secondary item location. Bone attachments or Marker3Ds work well for placement
@export var stored_mount_point : Node3D
## The item currently under the primary held mount node
@onready var current_equipment : EquipmentObject
## The item currently under the stored/sheathed node
@onready var stored_equipment : EquipmentObject
@export var activate_delay : float = .2

@export_flags_3d_physics var collision_detect_layers = 15

signal hit_target
signal hit_world
signal equipment_changed(new_equipment : EquipmentObject)
signal deactivate

func _ready():
	if player_node:
		if player_node.has_signal(change_signal):
			player_node.connect(change_signal,_on_equipment_changed)
		## needed to turn on/off monitoring when attacks start/end
		if player_node.has_signal(activate_signal):
			player_node.connect(activate_signal,_on_activated)
		## needed to turn off monitoring if hurt mid-attack
		if player_node.has_signal(deactivate_signal):
			player_node.connect(deactivate_signal,_on_stop_signal)
			
		deactivate.connect(_on_stop_signal)

	_reset_starting_equipment()

func _reset_starting_equipment():
	if held_mount_point:
		current_equipment = held_mount_point.get_child(0)
		current_equipment.equipped = true
		current_equipment.monitoring = false
		current_equipment.collision_layer = collision_detect_layers
		if current_equipment.has_signal("body_entered"):
			current_equipment.body_entered.connect(_on_body_entered)

	## update what gadget we're holding
	if stored_mount_point:
		stored_equipment = stored_mount_point.get_child(0)
		stored_equipment.equipped = false
		stored_equipment.monitoring = false
		if current_equipment:
			current_equipment.collision_mask = collision_detect_layers	


func _on_equipment_changed():
	#await get_tree().create_timer(player_node.anim_length * .5).timeout
	stored_equipment = stored_mount_point.get_child(0)
	
	## rearrange children
	held_mount_point.remove_child(current_equipment)
	stored_mount_point.remove_child(stored_equipment)
	
	held_mount_point.add_child(stored_equipment)
	stored_mount_point.add_child(current_equipment)
	
	# Update to current equipment, let them know they're equiped
	current_equipment.equipped = false
	if current_equipment.is_connected("body_entered", _on_body_entered):
		current_equipment.disconnect("body_entered",_on_body_entered)
	current_equipment = held_mount_point.get_child(0)
	
	await get_tree().process_frame
	if current_equipment.has_signal("body_entered"):
		current_equipment.body_entered.connect(_on_body_entered)
	current_equipment.equipped = true
	current_equipment.collision_mask = collision_detect_layers
	equipment_changed.emit(current_equipment)

func _on_activated():
	## awaiting so the area3D starts monitoring about after attack wind-up
	if current_equipment:
		await get_tree().create_timer(player_node.anim_length *.35).timeout
		## pause and start monitoring to hit things
		current_equipment.monitoring = true
		await get_tree().create_timer(player_node.anim_length *.5).timeout
		## after moment turn off monitoring to not hit things
		current_equipment.monitoring = false

func _on_body_entered(_hit_body):
	if _hit_body:
		# Early return to prevent self damage.
		if _hit_body == player_node:
			return
		
		if _hit_body.is_in_group(target_group) || _hit_body.is_in_group(target_group_secondary):
			if get_multiplayer_authority() != 1 && _hit_body.is_in_group("players") && _hit_body.pvp_on == false:
				return
			if _hit_body.has_method("hit"):
				hit_target.emit()
				_hit_body.hit(player_node,current_equipment.equipment_info)
			
	else: 
		hit_world.emit()

func _on_stop_signal():
	if current_equipment: 
		current_equipment.monitoring = false


# MULTIPLAYER LOOT


func _find_empty_pivot():
	if held_mount_point.get_node_or_null("EmptyEquipment") != null:
		return "held_mount_point"
	elif stored_mount_point.get_node_or_null("EmptyEquipment") != null:
		return "stored_mount_point"
	else:
		return null

func _find_loot_pivot(array):
	var final = null
	for item in array:
		if held_mount_point.get_node_or_null(item) != null:
			final = "held_mount_point"
		elif stored_mount_point.get_node_or_null(item) != null:
			final = "stored_mount_point"
	return final
