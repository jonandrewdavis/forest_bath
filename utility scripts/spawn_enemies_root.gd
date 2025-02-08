extends Node

const enemy_scene := preload('res://enemy/enemy_base_root_motion.tscn')

@export var multiplayer_id:int = 1

func _enter_tree() -> void:
	if multiplayer.is_server():
		set_multiplayer_authority(multiplayer_id)

func _ready():
	pass
