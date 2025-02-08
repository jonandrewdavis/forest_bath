extends Node
class_name HealthSystem

## A very crude health system. A 'hit' reporting node, (player or hit box, etc)
## can emit a damaging signal, or healing signal. That signal shoul dpass the
## the attacking node's information. This system checks for "node.power" of the attack
## or healing effect, and then applies that to healing or hurting.

## It can also work with a "health bar controller" or enemies to show their
## on-screen healthbar for a few seconds after being hit or healed.

@export var total_health : int = 5
@export var current_health = total_health
@export var hit_reporting_node : Node
@export var damage_signal :String = "damage_taken"


# NOTE: I got a bug here because "health_received" was the default name, yet I used "heal_signal"
# TODO: Rename "heal_signal" var to be "heal_signal signal". I called "heal_signal" on the parent. 
# would be nice if we could choose it... but may be better to be slightly more programmatic ...
 
@export var heal_reporting_node : Node
@export var heal_signal : String = "health_received"

@export var health_bar_control : Node
@export var show_time : float = 2
@onready var show_timer : Timer = $ShowTimer

signal max_health_updated
signal health_updated
signal died

func _ready():
	# dont' show the health bar at our feet if it's ours... we just pass.
	if is_multiplayer_authority():
		set_physics_process(false)
		
	if hit_reporting_node:
		if hit_reporting_node.has_signal(damage_signal):
			hit_reporting_node.connect(damage_signal,_on_damage_signal)

	if heal_reporting_node:
		if heal_reporting_node.has_signal(heal_signal):
			heal_reporting_node.connect(heal_signal,_on_health_signal)
			
	if health_bar_control:
		health_bar_control.hide()
		show_timer.one_shot = true
		show_timer.wait_time = show_time
		show_timer.timeout.connect(_on_show_timer_timeout)
		# NOTE: Removed add child here because adding a child timer doesn't spawn it on the puppets

func _physics_process(_delta):
	if show_timer:
		if show_timer.time_left:
			show_health()

func _on_damage_signal(_power_from_emit):
	if _power_from_emit:
		_on_damage_signal_sync.rpc(_power_from_emit)

@rpc("any_peer", "call_local")
func _on_damage_signal_sync(_power):
	var damage_power = _power
	current_health -= damage_power
	health_updated.emit(current_health)
	if current_health <= 0:
		died.emit()

	if health_bar_control:
		show_timer.start()

func _on_health_signal(_power_from_emit):
	if _power_from_emit:
		_on_health_signal_sync.rpc(_power_from_emit)

@rpc("any_peer", "call_local")
func _on_health_signal_sync(_power):
	var healing_power = _power
	current_health += healing_power
	if current_health > total_health:
		current_health = total_health
	health_updated.emit(current_health)
	
	if health_bar_control:
		show_timer.start()
	
func show_health():
	var current_camera = get_viewport().get_camera_3d()
	if current_camera && current_camera.global_position.distance_to(hit_reporting_node.global_position) < 30.0:
		var screenspace = current_camera.unproject_position(hit_reporting_node.global_position)
		health_bar_control.position = screenspace 
		health_bar_control.show()
		
func _on_show_timer_timeout():
	health_bar_control.hide()
