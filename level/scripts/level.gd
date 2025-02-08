extends Node3D

@onready var master_slider: HSlider = $Menu/MainContainer/MarginContainer/Panel/MarginContainer/VBoxContainer/MenuMasterSlider
@onready var skin_input: LineEdit = $Menu/MainContainer/NetfoxMenuContainer/OldMenu/Option2/SkinInput
@onready var nick_input: LineEdit = $Menu/MainContainer/NetfoxMenuContainer/OldMenu/Option1/NickInput
@onready var address_input: LineEdit = $Menu/MainContainer/NetfoxMenuContainer/OldMenu/Option3/AddressInput
@onready var players_container: Node = $PlayersContainer
@onready var menu: Control = $Menu
@export var player_scene: PackedScene

var bus_master = AudioServer.get_bus_index("Master")

const environment_arena = preload("res://level/scenes/arena.tscn")
const environment_instance_root_scene = preload("res://assets/environment_instances/environment_instance_root.tscn")
const enemy_scene = preload('res://enemy/enemy_base_root_motion.tscn')
const cart_scene = preload("res://assets/interactable/medieval_carriage/cart.tscn")
const server_scenario_manager_scene = preload("res://level/scenes/server_scenario_manager.tscn")

var volume_master_value

func _ready():
	# Check for -- server
	#var args = OS.get_cmdline_user_args()
	#for arg in args:
		#var key_value = arg.rsplit("=")
		#match key_value[0]:
			#"server":
				#print('DEBUG: SERVER STARTING `-- server` found')
				#_on_host_pressed()

	if get_node_or_null('MenuEnvironmentArea'):
		get_node_or_null('MenuEnvironmentArea').get_node("EnvironmentInstanceRoot").environment_tracker_changed.emit($MenuEnvironmentArea/CAMPMARKER)

	Hub.players_container = $PlayersContainer
	Hub.enemies_container = $EnemiesContainer
	Hub.environment_container = $EnvironmentContainer
	Hub.world_environment = $Environment/WorldEnvironment
	Hub.forest_sun = $Environment/ForestSun
	
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

func _on_player_connected(peer_id, _player_info):
	for id in Network.players.keys():
		var _player_data = Network.players[id]
		#if id != peer_id:
			# These are client only syncs, to set player properties.
			#rpc_id(peer_id, "sync_player_skin", id, player_data["skin"])
			#rpc_id(peer_id, "sync_player_skin", id, player_data["skin"])
				
	_add_player(peer_id)

func _on_host_pressed():
	menu.hide()
	# NOTE: Disabled for netfox.
	#Network.start_host()

	var bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_idx, true)
	
	add_server_only_nodes()
	await _on_join_started()
	RenderingServer.render_loop_enabled = false

func _on_join_pressed():
	menu.hide()
	$LoadingControl.modulate.a = 0
	$LoadingControl.visible = true
	var tween = create_tween()
	tween.tween_property($LoadingControl,"modulate:a", 1, 1.5)
	await tween.finished
	# NOTE: Disabled for netfox.
	#var check_join_game = Network.join_game(nick_input.text.strip_edges(), skin_input.text.strip_edges(), address_input.text.strip_edges())
	var check_join_game = false
	if check_join_game != OK:
		$LoadingControl.visible = false
		menu.show()
		$Menu/MainContainer/Error.show()
		
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

func _add_player(id: int):
	# Skip a lot of nodes
	if players_container.has_node(str(id)) or not multiplayer.is_server() or id == 1:
		return
	
	var player = player_scene.instantiate()
	player.name = str(id)
	players_container.add_child(player, true)

	var nick = Network.players[id]["nick"]
	player.rpc("change_nick", nick)
	
	rpc("sync_player_position", id, player.position)
	
	# Call from the server to a specific client, in this case, the player we just added.
	# Runs this function to attach the environment, etc.
	rpc_id(id, "sync_player_client_only_nodes", id)

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
	$MenuEnvironmentArea.queue_free()

	var player_node = Hub.get_player(peer_id)
	var prepare_environment = environment_instance_root_scene.instantiate()
	$EnvironmentContainer.add_child(prepare_environment)
	prepare_environment.environment_tracker_changed.emit(player_node) 
	player_node.position = get_spawn_point()
	#var server_scenario_manager = server_scenario_manager_scene.instantiate()
	#add_child(server_scenario_manager)

	await get_tree().create_timer(1.2).timeout
	var tween = create_tween()
	tween.tween_property($LoadingControl,"modulate:a", 0, 1.5)
	await tween.finished
	player_node.spawn()
	
func add_server_only_nodes():
	$MenuEnvironmentArea.queue_free()

	var prepare_environment = environment_instance_root_scene.instantiate()
	var server_scenario_manager = server_scenario_manager_scene.instantiate()
	var cart = cart_scene.instantiate()

	add_child(server_scenario_manager)
	$EnvironmentContainer.add_child.call_deferred(prepare_environment)
	$EnvironmentContainer.add_child.call_deferred(cart, true)

	await get_tree().create_timer(.1).timeout
	prepare_environment.environment_tracker_changed.emit(cart) 
	cart.global_position = Vector3(-7.0, 1.0, -10.0)
	
	# Begin Scenarios
	Hub.encounter_timer_start.emit()
	Hub.encounter_tracker_changed.emit(cart)

func _on_menu_master_slider_value_changed(value):	
	AudioServer.set_bus_volume_db(bus_master, linear_to_db(value))

func _on_quit_pressed():
	get_tree().quit()
