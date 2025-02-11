extends Node3D

const basic_enemy = preload('res://enemy/enemy_base_root_motion.tscn')

var current_wave = 0

# Sword, Archer, Brute
var wave_list = [
	[2, 0, 0],
	[4, 0, 0],
	[2, 2, 0],
	[4, 2, 0],
	[4, 0, 2],
	[2, 5, 0],
	[8, 4, 0],
	[2, 2, 4]
]

var multi = 1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$CheckTimer.timeout.connect(_on_check)
	$BreakTimer.timeout.connect(_on_break_end)
	print(wave_list[0][0])

# Every 5 seconds, check if you win
func _on_check():
	if Hub.enemies_container.get_children().size() == 0 && $BreakTimer.is_stopped():
		current_wave = current_wave + 1
		$BreakTimer.start()

func _on_break_end():
	if Hub.enemies_container.get_children().size() == 0:
		_start_next_round()

func _start_next_round():

	if current_wave <= wave_list.size() - 1:
		var soilders = wave_list[current_wave][0] * multi
		var archers = wave_list[current_wave][1] * multi
		var brutes = wave_list[current_wave][2] * multi
		for i in soilders:
			randomize()
			spawn_for_wave(randf() * 2)
		for a in archers:
			randomize()
			spawn_for_wave(randf() * 2, true)
		for b in brutes:
			randomize()		
			spawn_for_wave(randf() * 2, false, true)
	else: 
		current_wave = 0
		multi = multi + 1
		_start_next_round()

func spawn_for_wave(_rand, _archer = false, _brute = false):
	if multiplayer.is_server():
		var _dist: = 20.0
		var _radius = 20.0
		var spawn_point = Vector2.from_angle(_rand * PI) * _radius # spawn radius
		var final_location = Vector3(spawn_point.x, 30.0, spawn_point.y)

		var enemy = basic_enemy.instantiate()
		if _archer: 
			enemy.archer = true
		elif _brute == true:
			enemy.archer = false
			enemy.brute = true

		Hub.enemies_container.add_child(enemy, true)
		enemy.global_position = final_location
		if _rand < 1.0:
			enemy.set_new_default_target(Hub.get_cart())
		else:
			enemy.set_new_default_target(Hub.get_random_player())
