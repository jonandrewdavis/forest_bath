@tool
extends Node3D

signal environment_tracker_changed

@onready var sun = $MountainEnviromentV3/DirectionalLight3D
@onready var env: WorldEnvironment = $MountainEnviromentV3/WorldEnvironment

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group('players'):
		body.global_position = Vector3(5.0, 15.0, 5.0)
