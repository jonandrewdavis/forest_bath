extends RigidBody3D

@export var replicated_position : Vector3
@export var replicated_rotation : Vector3
@export var replicated_linear_velocity : Vector3
@export var replicated_angular_velocity : Vector3

@onready var rope_end = $Rope/End

@onready var idle_timer = $IdleTimer
var speed: float = 0.2

var player_attached: CharacterBody3D = null
@export var is_player_attached_sync = false

var cart_speed = 5.0

signal damage_taken
signal hurt_started
signal health_received
signal death_signal

# change to to signal?
@export var is_dead = false

func _enter_tree():
	set_multiplayer_authority(1)

# Called when the node enters the scene tree for the first time.
func _ready():
	if not multiplayer.is_server():
		set_process(false)
		set_physics_process(false)
	
	add_to_group("interactable")
	collision_layer = 9
	#$CartCam.clear_current()
	idle_timer.timeout.connect(idle_deactivate)
	
	# For health bar
	add_to_group("targets")
	collision_layer = 5
	
	$HealthSystem.died.connect(_on_cart_death)
	
func _integrate_forces(state):
	if global_position.distance_to(prev_position) > 1.0:
		prev_position = global_position
		Hub.distance_travelled = Hub.distance_travelled + 1

	if is_multiplayer_authority():
		if not player_attached:
			var down = 0.0
			if $CartCenterCast.is_colliding() == false:
				down = -1.0
			var down_dir: Vector3 = (basis * Vector3(0, down, 0)).normalized()
			state.linear_velocity = 3.0 * down_dir
			#state.angular_velocity = 10 * target_dir

			replicated_position = position
			replicated_rotation = rotation
			replicated_linear_velocity = state.linear_velocity
			replicated_angular_velocity = state.angular_velocity
			return

		var target_position = player_attached.global_transform.origin

		var forward_local_axis: Vector3 = Vector3(0, 0, 1)
		var forward_dir: Vector3 = (basis * forward_local_axis).normalized()
		var target_dir: Vector3 = (target_position - transform.origin).normalized()
		var local_speed: float = clampf(speed, 0, acos(forward_dir.dot(target_dir))) / 4
		if forward_dir.dot(target_dir) > 1e-4:
			state.angular_velocity = local_speed * forward_dir.cross(target_dir * Vector3(1.0, 1.0, 1.0)) / state.step / 2
			
		var distance_to_target = transform.origin.distance_to(target_position)
		if distance_to_target > 7.0:
			state.linear_velocity = 0.1 * target_dir / state.step
		elif distance_to_target > 5.5:
			state.linear_velocity = 0.05 * target_dir / state.step
		elif distance_to_target < 3.5:
			state.linear_velocity = 0.05 * -target_dir / state.step

		# CAUSES JITTER
		replicated_position = position
		replicated_rotation = rotation
		replicated_linear_velocity = state.linear_velocity
		replicated_angular_velocity = state.angular_velocity
		if $CartCenterCast.is_colliding() == false:
			player_attached = null
			cart_player_id_sync.rpc(null)
	else:
		state.linear_velocity = replicated_linear_velocity
		state.angular_velocity = replicated_angular_velocity
		position = replicated_position
		rotation = replicated_rotation

var prev_position = Vector3.ZERO

func _process(_delta):
	if not is_multiplayer_authority():
		return

	if abs(global_position.x) > 465.0 or abs(global_position.z) > 465.0:
		death_signal.emit()
		await get_tree().create_timer(1.0).timeout
		_on_cart_death()


	if player_attached == null:
		$Rope.visible = false
		$Rope2.visible = false
		rope_end.global_position = $InteractionPoint.global_position
		return
		
	if player_attached:
		$Rope.visible = true
		$Rope2.visible = true
		rope_end.global_position = Vector3(player_attached.transform.origin.x, player_attached.global_position.y + 0.8, player_attached.transform.origin.z)
	else: 
		$Rope.visible = false
		$Rope2.visible = false
		rope_end.global_position = $InteractionPoint.global_position

		
	#$CartCam.global_position = Vector3(global_position.x, $CartCam.global_position.y, global_position.z - 15.00)
	#$CartCam.look_at(Vector3(global_position.x, 2.0,  global_position.z))
	
func activate(_activated_player: CharacterBody3D):
	cart_player_sync.rpc()

func idle_deactivate():
	if is_multiplayer_authority():
		if not player_attached:
			return
		var distance_to_target = transform.origin.distance_to(player_attached.global_position)
		if distance_to_target > 10.0:
			player_attached = null
			cart_player_id_sync.rpc(null)

@rpc("any_peer", "reliable")
func cart_player_sync():
	if is_multiplayer_authority():
		var player_requesting = Hub.get_player(multiplayer.get_remote_sender_id())

		if not player_attached:
			var test_distance = player_requesting.global_position.distance_to($InteractionPoint.global_position)		
			if (test_distance < 2.2):
				player_attached = player_requesting
		elif player_attached.name == player_requesting.name:
			player_attached = null
		
		if player_attached:
			cart_player_id_sync.rpc(multiplayer.get_remote_sender_id())
		else: 
			cart_player_id_sync.rpc(null)

# Clients get an id and set their 
@rpc("authority", "call_remote", "reliable")
func cart_player_id_sync(player_id):
	if player_id:
		var get_player_node = Hub.get_player(player_id)
		if get_player_node: player_attached = get_player_node
	else: 
		player_attached = null

func hit(_by_who, _by_what):
	#var get_player_targeted = _target_to_player_node(_by_who)
	#if (get_player_targeted):
		#target = get_player_targeted
		#if hurt_cool_down.is_stopped():
			#hurt_cool_down.start()
			#hurt_started.emit()
			#damage_taken.emit(_by_what)
	if (_by_who.name && _by_what.power):
		#hurt_cool_down.start()
		hurt_started.emit()
		hit_sync.rpc(_by_who.name, _by_what.power)

@rpc("any_peer", "call_local")
func hit_sync(_by_who_name: String, power: int):
	if is_multiplayer_authority():
		# During RPC, this is an EncodedObjectAsID, so if we're host, let's  instance_from_id before:
		damage_taken.emit(power)
	elif $SoundFXTrigger.is_playing() == false:
		$SoundFXTrigger.play()

func _on_cart_death():
	death_signal.emit()
	is_dead = true
	await get_tree().create_timer(2.0).timeout
	visible = false
	global_position = Vector3(-8.0, 1.0, 8.0)
	health_received.emit(500)
	await get_tree().create_timer(10.0).timeout
	is_dead = false
	visible = true
	Hub.distance_travelled = 0
