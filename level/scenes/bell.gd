extends RigidBody3D

@export var replicated_position : Vector3
@export var replicated_rotation : Vector3
@export var replicated_linear_velocity : Vector3
@export var replicated_angular_velocity : Vector3


var limit = 30
var most_recent_player = ''

signal ring

func _enter_tree():
	set_multiplayer_authority(1)

# Called when the node enters the scene tree for the first time.
func _ready():
	if not multiplayer.is_server():
		set_process(false)
		set_physics_process(false)
		%RingTimer.start()

func _integrate_forces(state):
		if is_multiplayer_authority():
			replicated_position = position
			replicated_rotation = rotation
			replicated_linear_velocity = state.linear_velocity
			replicated_angular_velocity = state.angular_velocity
		else:
			state.linear_velocity = replicated_linear_velocity
			state.angular_velocity = replicated_angular_velocity
			position = replicated_position
			rotation = replicated_rotation		

func _physics_process(_delta):
	for col in get_colliding_bodies():
		if col is CharacterBody3D:
			var normal_dir = col.global_position.direction_to(self.global_position).normalized()
			apply_central_impulse(normal_dir * 1.5)
			apply_impulse(normal_dir * 0.01, get_position())
			col.velocity = col.velocity + linear_velocity
			most_recent_player = col.name

	try_ring()
		
func try_ring():
	if linear_velocity.z > 2.2 or linear_velocity.x > 2.2:
		ring.emit()	
		_on_ring.rpc(most_recent_player)
		_ring_sound.rpc()

@rpc("any_peer", 'call_local')
func _ring_sound():
	$"../SoundFXTrigger".play()

func hit(_player, _equipment):
	ring.emit()
	_on_ring.rpc(_player.name)

@rpc("any_peer", 'call_local')
func _on_ring(_player = null):
	if is_multiplayer_authority() && %RingTimer.is_stopped() && limit > 0:
		limit = limit - 1
		if _player != null:
			Hub.spawn_enemy_at_location.rpc(global_position, 40.0, _player)
			print('SPAWNED RING', global_position, _player, ' limit', limit)
		else:
			Hub.spawn_enemy_at_location.rpc(global_position, 40.0, most_recent_player)
			print('SPAWNED HIT',  global_position, _player,  ' limit', limit)
		%RingTimer.start(2.5)

func _client_ring():
	$"../SoundFXTrigger".play()
