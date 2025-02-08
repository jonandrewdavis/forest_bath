extends Node

signal player_connected(peer_id, player_info)
signal server_disconnected

# Scenario Manager / Encounter
signal encounter_timer_start
signal encounter_tracker_changed

# Environment Instance Root 
signal environment_ignore_add
signal environment_ignore_remove

###############
# NOTE: Keeping environment tracker changed on the parent of the instancer, not here, as they are naturally grouped.
# signal environment_tracker_changed
###############

signal equipment_is_using
signal coin
signal debug_spawn_new_enemy
signal debug_kill_all_enemies

const HEIGHTMAP = preload('res://assets/environment/heightmap_grass_main.tres')
const basic_enemy = preload('res://enemy/enemy_base_root_motion.tscn')

# Nodes for spawning
# Remember to add new Scenes to the Auto Spawn List
var environment_container: Node3D
var players_container: Node3D
var enemies_container: Node3D

var world_environment: WorldEnvironment
var forest_sun: DirectionalLight3D

const player_scene = preload("res://player/player_charbody3d.tscn")

# Server tracking
var distance_travelled = 0
var enemy_max = 5

func get_player(player_id: int):
	for player in players_container.get_children():
		if player.name == str(player_id):
			return player

func get_player_by_name(player_name: StringName):
	for player in players_container.get_children():
		if player.name == player_name:
			return player

	return null

func get_random_player():
	var count_up = 0
	var roll_for_player = randi_range(0, players_container.get_children().size() - 1)
	for player in players_container.get_children():
		if count_up == roll_for_player:
			return player
		else:
			count_up = count_up + 1

func get_cart() -> Node3D:
	return environment_container.get_node("Cart")
	
func add_coins(amount):
	add_coins_sync.rpc(amount)
	
@rpc("any_peer", "call_local")
func add_coins_sync(amount):
	coin.emit(amount)

@rpc('any_peer', 'call_local')
func debug_spawn_new_enemy_sync():
	if multiplayer.is_server():
		debug_spawn_new_enemy.emit()

@rpc('any_peer')
func debug_kill_all_enemies_sync():
	if multiplayer.is_server():
		var count = 0
		for enemy in enemies_container.get_children():
			var min_dist = INF
			for player in Hub.players_container.get_children():
				min_dist = min(min_dist, player.global_position.distance_to(enemy.global_position))

			if min_dist > 80.0:
				enemy.queue_free()
				count = count + 1

		print('DEBUG: Removed out of bounds enemies: ', count)

func get_environment_root() -> Node3D:
	return environment_container.get_node("EnvironmentInstanceRoot")

@rpc("any_peer", 'call_local')
func spawn_enemy_at_location(_new_location: Vector3, _dist: = 60.0, _target_name = null, _radius = 10, _brute = false):
	if multiplayer.is_server():
		var chance_archer = randi_range(0, 2)
		var spawn_point = Vector2.from_angle(randf() * 2 * PI) * _radius # spawn radius
		var spawn_dir = Vector2.from_angle(randf() * 2 * PI)
		var _new_location_dist = _new_location + Vector3(spawn_dir.x, 1.0, spawn_dir.y) * Vector3(_dist, 1.0, _dist)
		var final_location = Vector3(spawn_point.x + _new_location_dist.x, 4.0, spawn_point.y + _new_location_dist.z)

		var enemy = basic_enemy.instantiate()
		if chance_archer == 0: 
			enemy.archer = true
		if _brute == true:
			enemy.archer = false
			enemy.brute = true

		Hub.enemies_container.add_child(enemy, true)
		enemy.global_position = final_location
		if _target_name != null:
			enemy.set_new_default_target(Hub.get_player_by_name(_target_name))
		else:
			enemy.set_new_default_target(Hub.get_random_player())

@rpc("any_peer", 'call_local')
func debug_spawn_new_brute(_location):
	if multiplayer.is_server():
		spawn_enemy_at_location.rpc(_location, 60.0, get_random_player().name, 10, true)


@rpc("any_peer", 'call_local')
func increase_enemy_health():
	enemy_max = enemy_max + 1
