extends Node

@export_category("UI")
@export var connect_ui: Control
@export var address_input: LineEdit
@export var port_input: LineEdit


@onready var level_root = get_parent().level_root

func host_only():
	#var brawler_spawner: BrawlerSpawner = %"Brawler Spawner"
	#if brawler_spawner != null:
		#brawler_spawner.spawn_host_avatar = false
	host(false)

func host(_single_player: bool = false):
	var _host = _parse_input()
	if _host.size() == 0:
		return ERR_CANT_RESOLVE

	var port = _host.port

	# Start host
	print("Starting host on port %s" % port)
	var peer
	if _single_player:
		peer = OfflineMultiplayerPeer.new()
	else:
		peer = ENetMultiplayerPeer.new()
		if peer.create_server(port) != OK:
			print("Failed to listen on port %s" % port)

	get_tree().get_multiplayer().multiplayer_peer = peer
	print("Listening on port %s" % port)
	
	# Wait for server to start
	await Async.condition(
		func():
			return peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTING
	)

	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		OS.alert("Failed to start server!")
		return
	
	print("Server started")
	get_tree().get_multiplayer().server_relay = true

	connect_ui.hide()
	Network.player_info["nick"] = "Player_" + str(1)
	Network.players[1] = Network.player_info
	Hub.player_connected.emit(1, Network.player_info)

	level_root._on_host_pressed(true)
	
	# NOTE: This is not needed when using NetworkEvents
	# However, this script also runs in multiplayer-simple where NetworkEvents
	# are assumed to be absent, hence starting NetworkTime manually
	NetworkTime.start()

func join():
	var host_join = _parse_input()
	await level_root._on_join_started()
	if host_join.size() == 0:
		level_root._on_join_failed()
		return ERR_CANT_RESOLVE
		
	var address = host_join.address
	var port = host_join.port

	# Connect
	print("Connecting to %s:%s" % [address, port])
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(address, port)
	if err != OK:
		level_root._on_join_failed()
		OS.alert("Failed to create client, reason: %s" % error_string(err))
		return err

	get_tree().get_multiplayer().multiplayer_peer = peer
	
	# Wait for connection process to conclude
	await Async.condition(
		func():
			return peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTING
	)

	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		level_root._on_join_failed()
		OS.alert("Failed to connect to %s:%s" % [address, port])
		return

	print("Client started")
	connect_ui.hide()
		
	# NOTE: This is not needed when using NetworkEvents
	# However, this script also runs in multiplayer-simple where NetworkEvents
	# are assumed to be absent, hence starting NetworkTime manually
	NetworkTime.start()

func _parse_input() -> Dictionary:
	# Validate inputs
	var address = address_input.text
	var port = port_input.text
	
	if address == "":
		OS.alert("No host specified!")
		return {}
		
	if not port.is_valid_int():
		OS.alert("Invalid port!")
		return {}
	port = port.to_int()

	return {
		"address": address,
		"port": port
	}


func _on_start_single_player_pressed() -> void:
	connect_ui.hide()
	Network.player_info["nick"] = "Player_" + str(1)
	Network.players[1] = Network.player_info
	Hub.player_connected.emit(1, Network.player_info)
	
	host(true)
	level_root._on_single_player_start()
