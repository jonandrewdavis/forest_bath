extends Node3D

var previous_encounter_location = Vector3.ZERO
var encounter_tracker = Node3D

var distance_interval = 180.0
# Position in front of player / tracker
var distance_during_spawn = 80.0

# Nothing nearby
var spawn_distance_radius = 65.0
var despawn_distance_radius = 200.0

var recent_directions = {}


# DO NOT FORGET TO ADD ENCOUNTERS TO SPAWNER
var first_encounter_scene = preload("res://level/scenes/encounter.tscn")
var encounter_rock_scene = preload("res://level/scenes/encounter_rock.tscn")
var encounter_bell_scene = preload("res://level/scenes/encounter_bell.tscn")
var encounter_hut_scene = preload("res://level/scenes/encounter_huts.tscn")

var count = 0
@onready var encounters_array := [first_encounter_scene, encounter_rock_scene, encounter_bell_scene, encounter_hut_scene]

var basic_enemy = preload("res://enemy/enemy_base_root_motion.tscn")
var town = preload("res://level/scenes/town.tscn")

@onready var encounter_timer = $EncounterTimer
@onready var encounter_direction_timer = $RecentDirectionTimer

func _enter_tree():
	set_multiplayer_authority(1)

# TODO: possible to have this node be instantiated only on the server. Probably not much benefit to that, but nonetheless

func _ready():
	# Only the server is listening to these.
	if multiplayer.is_server():
		Hub.encounter_timer_start.connect(_on_begin_encounters)
		Hub.encounter_tracker_changed.connect(_on_encounter_tracker_changed)
		Hub.debug_spawn_new_enemy.connect(_on_debug_spawn_new_enemy)

func _on_begin_encounters():
	# Start up our timers, as we now have a monitorable subject
	encounter_timer.timeout.connect(check_for_encounter)
	encounter_direction_timer.timeout.connect(_record_recent_dir)

	encounter_timer.start()
	encounter_direction_timer.start()
	
	prepare_starting_area()

# TODO: If someone deviates too far... we could theoretically create encounters on them!
# May need to figure out server / client responsibilites for that...
func _on_encounter_tracker_changed(new_encounter_tracker):
	encounter_tracker = new_encounter_tracker

# TODO: SLOW DOWN, REFACTOR. AND FULLY UNDERSTAND HOW AUTHORITY & SPAWNING AND MULTIPLER SPANWER WORK
# WHY DOES THIS NEED TO BE RPC'd TO BE SEEN ON OTHER CLIENTS???
# They are spawning infinitly on the servber now, so i I think the game master only needs to be 
# a node in the server......

# DO NOT FORGET TO ADD ENCOUNTERS TO SPAWNER
func prepare_encounter(new_encounter_position: Vector3):
	var encounter_scene_ready 
	if count < encounters_array.size():
		encounter_scene_ready = encounters_array[count].instantiate()
		count = count + 1
	else:
		encounter_scene_ready = encounters_array[randi_range(0, encounters_array.size())].instantiate()

	Hub.environment_container.call_deferred('add_child', encounter_scene_ready, true)
	await get_tree().process_frame
	encounter_scene_ready.global_position = new_encounter_position
	previous_encounter_location = new_encounter_position
	var enemy_count = int(Hub.players_container.get_children().size() * 1.5)
	for en_count in range(0, enemy_count):
		populate_enemies(new_encounter_position)
		await get_tree().create_timer(0.7).timeout

func prepare_starting_area():
	var first_town = town.instantiate()
	Hub.environment_container.add_child(first_town, true)	
	first_town.global_position = Vector3.ZERO
	previous_encounter_location = Vector3.ZERO

func check_surrounding_area(new_encounter_position) -> bool:
	var min_dist = INF
	# Do not spawn on a previous encounter
	for node in Hub.environment_container.get_children():
		if node.is_in_group("encounters"):
			min_dist = min(min_dist, node.global_position.distance_to(new_encounter_position))

	# Do not spawn if a player is in the area.
	for player in Hub.players_container.get_children():
		min_dist = min(min_dist, player.global_position.distance_to(new_encounter_position))
	return min_dist > spawn_distance_radius 

func check_distance_from_previous(new_encounter_position): 
	return new_encounter_position.distance_to(previous_encounter_location) > distance_interval

var dir_index = 0
func _record_recent_dir():
	recent_directions[dir_index] = encounter_tracker.transform.basis.z
	if dir_index < 20:
		dir_index = dir_index + 1
	else:
		dir_index = 0

func check_for_encounter():
	if encounter_tracker:
		var average_recent_directions =  recent_directions.values().reduce(func(a, b): return a + b, Vector3.ZERO) / recent_directions.size()
		var new_encounter_position = encounter_tracker.global_position + (average_recent_directions * Vector3(distance_during_spawn, 0.0, distance_during_spawn))
		#print('CHECKING FOR ENCOUNTER...', new_encounter_position.distance_to(previous_encounter_location))
		if check_surrounding_area(new_encounter_position) && check_distance_from_previous(new_encounter_position):
			print("DEBUG: ENCOUNTER ALLOWED AT: ", new_encounter_position)
			prepare_encounter(new_encounter_position)

		await get_tree().create_timer(1).timeout 
		clean_up_encounters()

func clean_up_encounters():
	get_tree().call_group("encounters", "check_for_clean_up", encounter_tracker.global_position, despawn_distance_radius)

func populate_enemies(_new_encounter_position: Vector3, is_seeking_players = false):
	var chance_archer = randi_range(0, 2)
	var enemy = basic_enemy.instantiate()
	if chance_archer == 0: 
		enemy.archer = true
	Hub.enemies_container.add_child(enemy, true)
	enemy.global_position = get_spawn_point(_new_encounter_position)
	if is_seeking_players == true:
		if chance_archer == 0:
			enemy.set_new_default_target(Hub.get_cart())
		else: 
			enemy.set_new_default_target(Hub.get_random_player())
			

func get_spawn_point(_new_encounter_position) -> Vector3:
	var spawn_point = Vector2.from_angle(randf() * 2 * PI) * 18 # spawn radius
	return Vector3(spawn_point.x + _new_encounter_position.x, 4.0, spawn_point.y + _new_encounter_position.z)

func _on_debug_spawn_new_enemy():
	# TODO: Add archers?
	print('DEBUG: Spawn a new Debuged Enemy')
	# -100 is behind the current facing of the cart!!!
	# They'll sneak up. lol
	populate_enemies(Hub.get_cart().transform.basis.x * Vector3(-100.0, 0.0, -100.0), true)
