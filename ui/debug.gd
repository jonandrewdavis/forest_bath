extends Control

@export var player: CharacterBody3D
@onready var debug_text_node = $MarginContainer/DebugText

var timer

# Called when the node enters the scene tree for the first time.
func _ready():
	player.open_debug.connect(_open_or_close_debug)
	timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(_update_debug_text)
	timer.wait_time = 2.0
	timer.start()

func _open_or_close_debug():
	if visible: 
		visible = false
		DebugMenu.hide()
	else:
		visible = true
		_update_debug_text()
		DebugMenu.show()

func _update_debug_text():
	var encounters_count =	0
	for object in Hub.environment_container.get_children():
		if object.is_in_group('encounters'): encounters_count = encounters_count + 1

	var out_of_bounds = 0
	for enemy in Hub.enemies_container.get_children():
		var min_dist = INF
		for get_player in Hub.players_container.get_children():
			min_dist = min(min_dist, get_player.global_position.distance_to(enemy.global_position))
		if min_dist > 80.0:
			out_of_bounds = out_of_bounds + 1

	var text: Array[String] = [
		' ',
		' ',
		' ',
		"Players: " + str(Hub.players_container.get_child_count()),
		"Enemies: " + str(Hub.enemies_container.get_child_count()), 
		"Enemies (Out of bounds): " + str(out_of_bounds),
		"Encounters: " + str(encounters_count),
		"Cart Dist: " + str(Hub.get_cart().global_position.distance_to(player.global_position))
	]
	
	var text_with_p = []
	for item in text:
		text_with_p.append("[p]" + item + "[p]")
	
	debug_text_node.text = "".join(text_with_p)
