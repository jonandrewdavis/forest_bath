@tool
extends Node3D

signal environment_tracker_changed


func _ready() -> void:
	#Hub.world_environment = $Environment/WorldEnvironment
	Hub.forest_sun = $ForestSun
