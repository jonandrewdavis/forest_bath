@tool
extends Node3D

signal environment_tracker_changed

@onready var sun = $NewSun

func _on_reset_body_entered(body: Node3D) -> void:
	print('BODY', body)
	if body.is_in_group('players'):
		print('BODY')
		body.death()
	elif body.is_in_group('enemies'):
		if multiplayer.is_server():
			body.queue_free()
