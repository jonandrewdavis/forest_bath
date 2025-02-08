extends AnimationTree
class_name AnimationTreeSoulsBase

## A companion to the SoulsCharacterBase, expects a lot of specific signals and will react to them
## by triggering oneshot animations, switching trees, blending run types, etc. This is really 
## the meat of the souls modules since so much relies on animations and their timing.
## Most of the difficulty comes from when the movement tree changes from one weapon type to another.
## There are many ways to approach transitioning between different movement trees,
## I simply found this to be most convenient.


## MULTIPLAYER TEMPLATE FUNCS 
## MULTIPLAYER TEMPLATE FUNCS

# TODO: We may want to export all of these for Syncing, then we can
# turn off some processing probably.

## MULTIPLAYER TEMPLATE FUNCS 
## MULTIPLAYER TEMPLATE FUNCS
var is_menu_open = false

@export var player_node: CharacterBody3D
@onready var base_state_machine : AnimationNodeStateMachinePlayback = self["parameters/MovementStates/playback"]
#@onready var ladder_state_machine = self["parameters/MovementStates/LADDER_tree/playback"]
@onready var current_weapon_tree : AnimationNodeStateMachinePlayback

## MULTIPLAYER TEMPLATE FUNCS 
## MULTIPLAYER TEMPLATE FUNCS

@export var weapon_type : String = "SLASH"
@export var gadget_type : String = "SHIELD"
@export var interact_type :String = "GENERIC"
@export var current_item : ItemResource

## MULTIPLAYER TEMPLATE FUNCS 
## MULTIPLAYER TEMPLATE FUNCS

@onready var max_attack_count : int = 3 ## how many attacks you have in the attack tree
@export var attack_count = 1 ## Used in the anim state tree. The oneShot for the
## ATTACK_tree, under SLASH and HEAVY each route to an animation will use this 
## variable under it's advanced expression to know which route to take.
@onready var attack_timer = Timer.new()
@onready var attack_requested_timer = Timer.new()
@onready var hurt_count = 1

@export var anim_length = 0.0

@export var landing_type = "SOFT"
@export var last_oneshot: String = "Attack"
var lerp_movement
var lerp_movement_aim

var guard_value :float = 0.0

signal animation_measured

## MULTIPLAYER TEMPLATE FUNCS 
## MULTIPLAYER TEMPLATE FUNCS

# NOTE: This is in the player tree, so the parent sets the authority, no need to do it again here.

#func _enter_tree():
	#set_multiplayer_authority(str(name).to_int())

## MULTIPLAYER TEMPLATE FUNCS
## MULTIPLAYER TEMPLATE FUNCS


@onready var anim_player_node: AnimationPlayer = get_node(anim_player)


func _ready():
	if not is_multiplayer_authority():
		return
	
	add_child(attack_timer)
	attack_timer.one_shot = true
	#attack_timer.timeout.connect(_on_attack_timer_timeout)
	add_child(attack_requested_timer)
	attack_requested_timer.one_shot = true
	attack_requested_timer.timeout.connect(_on_attack_requested_timeout)
	
	if !player_node:
		push_warning(str(self) + ": Player node must be set")
		
	player_node.dodge_started.connect(_on_dodge_started)
	player_node.jump_started.connect(_on_jump_started)
	player_node.sprint_started.connect(_on_sprint_started)
	player_node.landed_fall.connect(_on_landed_fall)
	
	player_node.interact_started.connect(_on_interact_started)
	player_node.climb_started.connect(_on_climb_start)
	#player_node.ladder_finished.connect(_on_ladder_finished)

	player_node.weapon_change_started.connect(_on_weapon_change_started)
	player_node.weapon_change_ended.connect(_on_weapon_change_ended)
	# NOTE: Disabled - AD
	player_node.attack_started.connect(_on_attack_started)
	# Added. - AD
	player_node.attack_requested.connect(_on_attack_requested)
	
	player_node.gadget_change_started.connect(_on_gadget_change_started)
	player_node.gadget_change_ended.connect(_on_gadget_change_ended)
	player_node.gadget_started.connect(_on_gadget_started)
	
	player_node.item_change_started.connect(_on_item_change_started)
	player_node.item_change_ended.connect(_on_item_change_ended)
	player_node.use_item_started.connect(_on_use_item_started)
		
	player_node.parry_started.connect(_on_parry_started)
	player_node.hurt_started.connect(_on_hurt_started)
	player_node.block_started.connect(_on_block_started)

	player_node.death_started.connect(_on_death_started)

	_on_weapon_change_ended(player_node.weapon_type)
	_on_gadget_change_ended(player_node.gadget_type)
	_on_item_change_ended(player_node.current_item)
	
	player_node.menu_open.connect(_on_menu_open)
	
	
func _process(_delta):
	## MULTIPLAYER TEMPLATE FUNCS
	# NOTE: Required for all authorities

	if player_node.strafing:
		set_strafe()
	else:
		set_free_move()

		
	if player_node.current_state == player_node.state.CLIMB:
		set_ladder()
		
	set_guarding()

# RPC THIS? 
func request_oneshot(oneshot:String):
	last_oneshot = oneshot
	set("parameters/" + oneshot + "/request", true)
	if is_multiplayer_authority():
		sync_player_oneshot.rpc(oneshot)
	

func _on_landed_fall(_hard_or_soft = "HARD"):
	landing_type = _hard_or_soft
	if _hard_or_soft == "HARD":
		request_oneshot("Landed")

func set_guarding():
	if player_node.guarding && !player_node.busy && player_node.dodging == false:
		guard_value = 1
	else:
		guard_value = 0

	var new_blend = lerp(get("parameters/Guarding/blend_amount"),guard_value,.2)
	if weapon_type == "BOW":
		set("parameters/Aiming/blend_amount", new_blend)
	else:
		set("parameters/Guarding/blend_amount", new_blend)
		

func _on_parry_started():
	request_oneshot("Parry")

@export var is_combo = false

# TODO: do we need stop here?
func _on_attack_requested():
	is_combo = true
	attack_requested_timer.start(0.5)

func _on_attack_requested_timeout():
	is_combo = false
	if attack_count > 1 && get("parameters/Attack/active") == false:
		_on_attack_end()
	#var current_node = get("parameters/ATTACK_tree/" + weapon_type +"/playback").get_current_node()
	#if attack_count == 2 && get("parameters/ATTACK_tree/" + weapon_type +"/playback").get_current_node() == "Slash1":
		#_on_attack_end()
	#if get("parameters/ATTACK_tree/" + weapon_type +"/playback").is_playing() == false:
		#_on_attack_end()
		
# TODO: refactor this to emit properly. The first request Attack to the player perhaps... Its tough.
# It would allow allow attack to emit more freely
# NOTE: Doesn't work over RPC yet.

# TODO: this is a mess and needs to be seperated out from the signal.
# calling emit should only turn it on, not retrigger this function.

# NOTE: Emitting attack now only handles things outside animation tree, like turning weapons
# on and off
func _on_attack_started():
	_on_sync_attack_started.rpc()
	pass

@rpc("any_peer", "call_remote")
func _on_sync_attack_started():
	player_node.attack_started.emit()

func attack_once():
	await animation_measured
	player_node.attack_started.emit()
	await get_tree().create_timer(player_node.anim_length).timeout
	_on_attack_end()
	
func attack_chain_current_length():
	return get("parameters/ATTACK_tree/" + weapon_type +"/playback").get_current_length()
	

# TODO: Finally got this working after like 3 weeks
# This "attack_chain_current_length() > 0:" prevents the "running in place" busy, because 
# the oneshot was ending too early, and the combo was continuing. This makes sure we fall into the "end"
# So we don't get stuck doing a combo & busy without the oneshot running
# This adds an almost imperceptible pause to the combo, nice to have:  + 0.01
# Obviously there is a TON of repetition, so all of this could be really simple, but each case
# has a lot of duplication because... this is how I built it. Yikes.

func attack_chain():
	if attack_count == 1:
		request_oneshot("Attack")
		animation_measured.emit(attack_chain_current_length() - 0.2)
		await animation_measured
		player_node.attack_started.emit()
		await get_tree().create_timer(attack_chain_current_length() - 0.2).timeout
		attack_count = 2
		attack_chain()
	elif is_combo == true && attack_count == 2 && get("parameters/Attack/active"):
		get("parameters/ATTACK_tree/" + weapon_type +"/playback").travel(weapon_type.to_pascal_case()+ str(attack_count))
		animation_measured.emit(attack_chain_current_length() - 0.2)
		await animation_measured
		player_node.attack_started.emit()
		sync_combo_attack.rpc(weapon_type, attack_count)
		await get_tree().create_timer(attack_chain_current_length()  - 0.2).timeout
		attack_count = 3
		attack_chain()
	elif is_combo == true && attack_count == 3 && get("parameters/Attack/active"):
		get("parameters/ATTACK_tree/" + weapon_type +"/playback").travel(weapon_type.to_pascal_case() + str(attack_count))
		animation_measured.emit(attack_chain_current_length()  - 0.2)
		await animation_measured
		player_node.attack_started.emit()
		sync_combo_attack.rpc(weapon_type, attack_count)
		await get_tree().create_timer(attack_chain_current_length()  - 0.2).timeout
		_on_attack_end()
	else:
		_on_attack_end()

func attack_air():
	await animation_measured
	player_node.attack_started.emit()
	await get_tree().create_timer(player_node.anim_length).timeout
	# Do not call _end. AnimationTree Moves to end if on floor. - AD 10/30/2024

@rpc("authority", "call_remote", "reliable")
func sync_combo_attack(weapon_type_rpc, number):
	get("parameters/ATTACK_tree/" + weapon_type_rpc +"/playback").travel(weapon_type_rpc.to_pascal_case()  + str(number))

func _on_attack_end():
	#print("DEBUG: Ended on attack: ", player_node.state, player_node.busy)
	player_node.busy = false
	player_node.current_state = player_node.state.FREE
	attack_count = 1


func _on_block_started():
	request_oneshot("Block")

func _on_hurt_started(): ## Picks a hurt animation between "Hurt1" and "Hurt2"
	if player_node.current_state == player_node.state.CLIMB:
		hurt_count = 3
	else:
		# AD - Added
		_on_attack_end()
		abort_oneshot(last_oneshot)
		hurt_count = randi_range(1,2)
		request_oneshot("Hurt")
		if (current_weapon_tree):
			current_weapon_tree.start("MoveStrafe")
		
func abort_oneshot(_last_oneshot:String):
	set("parameters/" + _last_oneshot + "/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)

func _on_death_started():
	base_state_machine.travel("Death")
	_death_started_sync.rpc()

@rpc("any_peer")
func _death_started_sync():
	base_state_machine.travel("Death")

func _on_spawn_started():
	base_state_machine.travel("Start")
	_on_spawn_started_sync.rpc()

@rpc('any_peer')
func _on_spawn_started_sync():
	base_state_machine.travel("Start")

func _on_use_item_started():
	request_oneshot("UseItem")

func _on_gadget_started():
	request_oneshot("Gadget")

func _on_sprint_started():
	base_state_machine.travel("SPRINT_tree")
	if is_multiplayer_authority():
		sync_player_sprinting.rpc()
	
func _on_dodge_started():
	request_oneshot("Dodge")

func _on_interact_started(_new_interact_type):
	interact_type = _new_interact_type
	await get_tree().process_frame
	request_oneshot("Interacts")

func _on_jump_started():
	request_oneshot("Jump")

func _on_weapon_change_started():
	request_oneshot("WeaponChange")

func _on_weapon_change_ended(_new_weapon_type):
	# if a wapon tree exixts, swap to it, otherwise, just use the "SLASH_tree" for rmovements.
	var weapon_tree_exists = tree_root.get_node("MovementStates").has_node(str(_new_weapon_type)+"_tree")
	if weapon_tree_exists:
		weapon_type = _new_weapon_type
		current_weapon_tree = get("parameters/MovementStates/"+str(_new_weapon_type)+"_tree/playback")
	else:
		weapon_type = "SLASH"
		current_weapon_tree = get("parameters/MovementStates/"+str(_new_weapon_type)+"_tree/playback")

func _on_gadget_change_started():
	request_oneshot("GadgetChange")

func _on_gadget_change_ended(_new_gadget_type):
	gadget_type = _new_gadget_type

func _on_item_change_started():
	request_oneshot("ItemChange")

func _on_item_change_ended(_new_item):
	current_item = _new_item

func _on_climb_start():
	#set("parameters/MovementStates/LADDER_tree/LadderBlender/blend_position",0)
	#base_state_machine.start("LADDER_tree")
	base_state_machine.travel("LADDER_tree")
	#ladder_state_machine.travel("LadderStart_" + top_or_bottom)
	
#func _on_ladder_finished(top_or_bottom):
	##ladder_state_machine.travel("LadderEnd_" + top_or_bottom)
	#pass
	
func set_ladder():
	#set("parameters/MovementStates/LADDER_tree/LadderBlend/blend_position",-player_node.input_dir.y)
	#var ladder_frame = get("parameters/MovementStates/LADDER_tree/LadderBlender/blend_position")
	#print(ladder_frame)
	#if ladder_frame > 1:
		#ladder_frame = 0
	#elif ladder_frame < 0:
		#ladder_frame = 1
	#set("parameters/MovementStates/LADDER_tree/LadderBlender/blend_position",ladder_frame - (player_node.input_dir.y * .015)) # otherwise, play the animation at the speed of player input (* a speed if climb anim is slow)
	set("parameters/MovementStates/LADDER_tree/LadderTime/scale",-player_node.input_dir.y)
			

func set_strafe():
	# Strafe left and right animations run by the player's velocity cross product
	# Forward and back are acording to input, since direction changes by fixed camera orientation
	var new_blend = Vector2(player_node.strafe_cross_product,player_node.move_dot_product)
	#if player_node.current_state == player_node.state.DYNAMIC_ACTION:
	if new_blend == null:
		return

	if player_node.slowed:
		new_blend *= .25 # Force a walk animiation
	else:
		# apply input as a magnatude for more natural run versus walk animation blending
		new_blend *= Vector2(abs(player_node.input_dir.x),abs(player_node.input_dir.y))
	lerp_movement = get("parameters/MovementStates/" + weapon_type + "_tree/MoveStrafe/blend_position")
	if !lerp_movement:
		lerp_movement = Vector2(0.0, 0.0)
		return

	if get("parameters/Shoot/active") == true:
		# Case where they let go too soon....
		new_blend = Vector2(player_node.input_dir.x, player_node.input_dir.y * -1.0)
		new_blend *= .1

	lerp_movement = lerp(lerp_movement,new_blend,.2)
	set("parameters/MovementStates/" + weapon_type + "_tree/MoveStrafe/blend_position", lerp_movement)
	set("parameters/MovementStates/" + weapon_type + "_tree/MoveStrafeAim/blend_position", lerp_movement)

# TODO: Clean all this up... - AD
# Cloning this func cause of all the bugs... i hate this thing
# TON OF BUGS HERE...
#func set_strafe_bow():
	##var new_blend_aim = Vector2(player_node.strafe_cross_product,player_node.move_dot_product)
	#var new_blend_aim = Vector2(player_node.strafe_cross_product,player_node.move_dot_product)
	#if new_blend_aim == null:
		#return
	#if get("parameters/MovementStates/" + weapon_type + "_tree/MoveStrafeAim/blend_position") == null:
		#return
	#if !lerp_movement_aim:
		#lerp_movement_aim = Vector2(0.0, 0.0)
#
	#if get("parameters/Shoot/active") == true:
		## Case where they let go too soon....
		#new_blend_aim = Vector2(player_node.input_dir.x, player_node.input_dir.y * -1.0)
		#new_blend_aim *= .4
#
	#lerp_movement_aim = lerp(lerp_movement_aim,new_blend_aim,.2)
	#set("parameters/MovementStates/" + weapon_type + "_tree/MoveStrafeAim/blend_position", lerp_movement_aim)
	#return

func set_free_move():
	# Non-strafing "free" movement, is just the forward input direction.
	var new_blend = Vector2(0,abs(player_node.input_dir.x) + abs(player_node.input_dir.y))
	if player_node.slowed:
		new_blend *= .4 # force a walk speed
	if get("parameters/Shoot/active") == true:
		# Case where they let go too soon....
		new_blend = Vector2(player_node.input_dir.x, player_node.input_dir.y * -1.0)
		new_blend *= .4
	
	lerp_movement = get("parameters/MovementStates/" + weapon_type + "_tree/MoveStrafe/blend_position")
	lerp_movement = lerp(lerp_movement,new_blend,.2)
	set("parameters/MovementStates/" + weapon_type + "_tree/MoveStrafe/blend_position",lerp_movement)

func _on_animation_started(anim_name):
	if get_node(anim_player) && anim_name:
		anim_length = get_node(anim_player).get_animation(anim_name).length
		#print("DEBUG: Animation Measured, emit: " + str(anim_name), anim_length)
		animation_measured.emit(anim_length)


## MULTIPLAYER RPCs
## MULTIPLAYER RPCs
## MULTIPLAYER RPCs
	
@rpc("any_peer", "reliable")
func sync_player_oneshot(one_shot) -> void:
	request_oneshot(one_shot)

@rpc("any_peer", "reliable")
func sync_player_sprinting() -> void:
	base_state_machine.travel("SPRINT_tree")


func _on_menu_open(_on_off):
	is_menu_open = _on_off
