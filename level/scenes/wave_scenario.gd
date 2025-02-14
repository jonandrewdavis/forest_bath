extends Node3D

const basic_enemy = preload('res://enemy/enemy_base_root_motion.tscn')

@export var current_wave = 0

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

@export var multi = 1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Start.timeout.connect(_on_start)
	$CheckTimer.timeout.connect(_on_check)
	$BreakTimer.timeout.connect(_on_break_end)
	var enemy_preload = basic_enemy.instantiate()
	enemy_preload.queue_free()

func _on_start():
	var tween1 = create_tween()
	tween1.tween_property($Control/Start,"self_modulate:a", 255, 2)
	await tween1.finished
	await get_tree().create_timer(5).timeout
	var tween = create_tween()
	tween.tween_property($Control/Start,"self_modulate:a", 0, 2)
	await tween.finished
	await get_tree().create_timer(5).timeout
	_on_break_end()
	await get_tree().create_timer(1).timeout
	$CheckTimer.start()
	
# Every 5 seconds, check if you win
func _on_check():
	if Hub.enemies_container.get_children().size() == 0 && $BreakTimer.is_stopped():
		$BreakTimer.start()
		if multiplayer.is_server():
			current_wave = current_wave + 1

func _on_break_end():
	if Hub.enemies_container.get_children().size() == 0:
		_start_next_round.rpc()
		var tween_show = create_tween()
		tween_show.tween_property($Control/HereTheyCome,"self_modulate:a", 255, 2)
		await tween_show.finished
		
		await get_tree().create_timer(1).timeout
		var tween_hide = create_tween()
		tween_hide.tween_property($Control/HereTheyCome,"self_modulate:a", 0, 2)
		await tween_hide.finished

@rpc('any_peer', 'call_local')
func _start_next_round():
	if multiplayer.is_server():
		if current_wave <= wave_list.size() - 1:
			var soilders = wave_list[current_wave][0] * multi
			var archers = wave_list[current_wave][1] * multi
			var brutes = wave_list[current_wave][2] * multi
			for i in soilders:
				randomize()
				spawn_for_wave.rpc(randf() * 2)
			for a in archers:
				randomize()
				spawn_for_wave.rpc(randf() * 2, true)
			for b in brutes:
				randomize()		
				spawn_for_wave.rpc(randf() * 2, false, true)
		else: 
			current_wave = 0
			multi = multi + 1
			_start_next_round()

@rpc('any_peer', 'call_local')
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
