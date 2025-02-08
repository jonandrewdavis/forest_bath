extends StaticBody3D

## All interactables function similarly. They have a function called "activate"
## that takes in the player node as an argument. Typically the interactable
## forces the player to a STATIC state, moves the player into a ready postiion,
## triggers the interact on the player while making any changes needed here.

@onready var opened = false
@onready var chest_anim_player :AnimationPlayer = $ChestAnimPlayer
@export var locked : bool = false
@export var player_offset : Vector3 = Vector3(0,0,1)
@onready var interact_type = "CHEST"
@export var anim_delay : float = .2
var anim
signal interactable_activated

@export var is_store_chest = false

func _ready():
	if is_store_chest == false: 
		add_to_group("interactable")
		collision_layer = 9

func activate(player: CharacterBody3D):
	if is_store_chest == true:
		if opened == false:
			open_chest()
		else:
			close_chest()
			
		# return early if we're the store chest...
		return
	
	var roll = randi_range(0, 10)
	#if locked:
		#shake_chest()
	if opened:
		return
	if roll != 0:
		if $ChestAnimPlayer.is_playing() == false:
			shake_chest()
		$InteractTimer.start(0.4)
	else:
		$ChestAnimPlayer.play("RESET")
		$InteractTimer.start(1.0)
		interactable_activated.emit()
		var new_translation = global_transform.translated_local(player_offset).rotated_local(Vector3.UP,PI)

		var tween = create_tween()
		tween.tween_property(player,"global_transform", new_translation,.2)
		await tween.finished
		
		if opened == false:
			player.trigger_interact(interact_type)
			await get_tree().create_timer(anim_delay).timeout
			open_chest()
			await get_tree().create_timer(1.0).timeout
			player.get_loot()


func shake_chest():
	chest_anim_player.play("Locked")
	
func open_chest():
	anim = "open"
	chest_anim_player.play(anim)
	opened = true
	
	
func close_chest():
	anim = "open"
	chest_anim_player.play_backwards(anim)
	opened = false
