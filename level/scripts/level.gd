extends Node3D

@onready var master_slider: HSlider = $Menu/MainContainer/MarginContainer/Panel/MarginContainer/VBoxContainer/MenuMasterSlider
@onready var players_container: Node = $PlayersContainer
@onready var menu: Control = $Menu
@export var player_scene: PackedScene

var bus_master = AudioServer.get_bus_index("Master")

const terrain_two = preload("res://terrain_two.tscn")

const environment_arena = preload("res://level/scenes/arena.tscn")
const enemy_scene = preload('res://enemy/enemy_base_root_motion.tscn')
const cart_scene = preload("res://assets/interactable/medieval_carriage/cart.tscn")

const wave_scenario = preload("res://level/scenes/wave_scenario.tscn")

var volume_master_value

func _ready():
	# Check for -- mute
	var args = OS.get_cmdline_args()
	print(args)
	for arg in args:
		var key_value = arg.rsplit("=")
		match key_value[0]:
			#"server":
				#print('DEBUG: SERVER STARTING `-- server` found')
				# THIS WONT WORK BECASUE NETFOX??
				# TODO: ... dedicated... host
				#_on_host_pressed()
			"mute":
				var bus_idx = AudioServer.get_bus_index("Master")
				AudioServer.set_bus_mute(bus_idx, true)

	if get_node_or_null(''):
		get_node_or_null('').get_node("EnvironmentInstanceRoot").environment_tracker_changed.emit($/CAMPMARKER)

	Hub.players_container = $PlayersContainer
	Hub.enemies_container = $EnemiesContainer
	Hub.environment_container = $EnvironmentContainer
	#Hub.world_environment = $Environment/WorldEnvironment
	
	Hub.connect("player_connected", Callable(self, "_on_player_connected"))
	multiplayer.peer_disconnected.connect(_remove_player)

	volume_master_value = db_to_linear(AudioServer.get_bus_volume_db(bus_master))
	master_slider.max_value = volume_master_value * 2
	master_slider.value = volume_master_value

func _spawn_enemy(): 
	await get_tree().create_timer(5.0).timeout
	print('DEBUG: ONE ENMEY SPAWN')
	var enemy = enemy_scene.instantiate()
	enemy.network_randi_seed = 123 + $EnemiesContainer.get_children().size()
	$EnemiesContainer.add_child(enemy, true) 

	enemy.global_position = get_spawn_point()

# Multiplayer. DO not change for single player
func _on_player_connected(peer_id, _player_info):
	for id in Network.players.keys():
		var _player_data = Network.players[id]
		_add_player(peer_id, false)
		#if id != peer_id:
			# These are client only syncs, to set player properties.
			#rpc_id(peer_id, "sync_player_skin", id, player_data["skin"])
			#rpc_id(peer_id, "sync_player_skin", id, player_data["skin"])


func _on_host_pressed(single_player):
	menu.hide()
	# NOTE: Disabled for netfox.
	#Network.start_host()
	# SINGLE PLAYER HERE
	# SINGLE PLAYER HERE
	# SINGLE PLAYER HERE
	# SINGLE PLAYER HERE
	await _on_join_started()
	_add_player(1, true)


func _on_join_started():
	menu.hide()
	$LoadingControl.modulate.a = 0
	$LoadingControl.visible = true
	var tween = create_tween()
	tween.tween_property($LoadingControl,"modulate:a", 1, 1.5)
	await tween.finished
	return OK

func _on_join_failed():
	$LoadingControl.visible = false
	menu.show()
	$Menu/MainContainer/Error.show()

func _add_player(id: int, single_player: bool):
	# Skip a lot of nodes
	if (players_container.has_node(str(id)) or not multiplayer.is_server() or id == 1) && single_player == false:
		return
	
	var player = player_scene.instantiate()
	player.name = str(id)
	players_container.add_child(player, true)

	var nick = Network.players[id]["nick"]
	player.rpc("change_nick", nick)
	
	rpc("sync_player_position", id, player.position)
	
	# Call from the server to a specific client, in this case, the player we just added.
	# Runs this function to attach the environment, etc.
	if id != 1:
		rpc_id(id, "sync_player_client_only_nodes", id)
	elif single_player: 
		_add_single_player_only_nodes_and_finish_loading()

func get_spawn_point() -> Vector3:
	var spawn_point = Vector2.from_angle(randf() * 2 * PI) * 15 # spawn radius
	return Vector3(spawn_point.x, 5.0, spawn_point.y)
	
func _remove_player(id):
	if not multiplayer.is_server() or not players_container.has_node(str(id)):
		return
	var player_node = players_container.get_node(str(id))
	if player_node:
		player_node.queue_free()

# Is this necessary?
@rpc("any_peer", "call_local")
func sync_player_position(id: int, new_position: Vector3):
	var player = players_container.get_node(str(id))
	if player:
		player.position = new_position
		# TODO: Proper loading signal / bus for users to load their scenery.
		#$EnvironmentInstanceRoot.set_new_root(player)
	
@rpc
func sync_player_client_only_nodes(peer_id):
	var player_node = Hub.get_player(peer_id)
	player_node.position = get_spawn_point()

	# HACKY WARNING!!!!
	# HACKY WARNING!!!!
	# HACKY WARNING!!!!
	# HACKY WARNING!!!!
	# HACKY WARNING!!!!
	var prepare_terrain_two = terrain_two.instantiate()
	$EnvironmentContainer.add_child(prepare_terrain_two)
	# Emits for grass tracking
	prepare_terrain_two.environment_tracker_changed.emit(player_node)
	
	var wave_prep = wave_scenario.instantiate()
	$EnvironmentContainer.add_child.call_deferred(wave_prep)

	await get_tree().create_timer(1.2).timeout
	var tween = create_tween()
	tween.tween_property($LoadingControl,"modulate:a", 0, 1.5)
	await tween.finished
	player_node.spawn()

# SINGLE PLAYER, 
# NO CART.
# NEW BLENDER TERRAIN
var debug_arena = false
var new_single_player_terrain = true

func _add_single_player_only_nodes_and_finish_loading():
	var player_node = Hub.get_player(1)
	_new_game_mode()

	player_node.position = get_spawn_point()

	await get_tree().create_timer(3.0).timeout
	var tween = create_tween()
	tween.tween_property($LoadingControl,"modulate:a", 0, 1.5)
	await tween.finished
	player_node.spawn()	


func _new_game_mode():
	var prepare_terrain_two = terrain_two.instantiate()
	$EnvironmentContainer.add_child(prepare_terrain_two)
	# Emits for grass tracking
	var player_node = Hub.get_player(1)
	prepare_terrain_two.environment_tracker_changed.emit(player_node)

	Hub.forest_sun = $EnvironmentContainer.get_node("TerrainTwo").sun
	var cart = cart_scene.instantiate()
	$EnvironmentContainer.add_child.call_deferred(cart, true)

	
	var wave_prep = wave_scenario.instantiate()
	$EnvironmentContainer.add_child.call_deferred(wave_prep)
	
	await get_tree().create_timer(0.2).timeout
	cart.global_position = Vector3(-8.0, 2.0, 2.0)


func add_server_only_nodes():
	var prepare_terrain_two = terrain_two.instantiate()
	$EnvironmentContainer.add_child(prepare_terrain_two)

	# Emits for grass tracking
	var cart = cart_scene.instantiate()
	$EnvironmentContainer.add_child.call_deferred(cart, true)
	
	var wave_prep = wave_scenario.instantiate()
	$EnvironmentContainer.add_child.call_deferred(wave_prep)
	
	await get_tree().create_timer(0.2).timeout
	cart.global_position = Vector3(-8.0, 2.0, 2.0)

	


func _on_menu_master_slider_value_changed(value):	
	AudioServer.set_bus_volume_db(bus_master, linear_to_db(value))

func _on_quit_pressed():
	get_tree().quit()

func _single_player_loading():
	menu.hide()
	$LoadingControl.modulate.a = 0
	$LoadingControl.visible = true
	var tween = create_tween()
	tween.tween_property($LoadingControl,"modulate:a", 1, 1.5)
	await tween.finished	
	return OK

func _on_single_player_start():
	pass
