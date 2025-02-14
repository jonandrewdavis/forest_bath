extends RigidBody3D

@export var replicated_position : Vector3
@export var replicated_rotation : Vector3
@export var replicated_linear_velocity : Vector3
@export var replicated_angular_velocity : Vector3

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
	Hub.get_cart()

# Called when the node enters the scene tree for the first time.
func _ready():
	#add_to_group("interactable")
	#collision_layer = 9
	#$CartCam.clear_current()
	# For health bar
	add_to_group("targets")
	collision_layer = 5
	
	$HealthSystem.died.connect(_on_cart_death)

var prev_position = Vector3.ZERO

func _process(_delta):
	if not is_multiplayer_authority():
		return

	if abs(global_position.x) > 465.0 or abs(global_position.z) > 465.0:
		death_signal.emit()
		await get_tree().create_timer(1.0).timeout
		_on_cart_death()

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
	$Death.show()
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
