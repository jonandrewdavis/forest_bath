extends RigidBody3D

var shell = false
var Damage: int = 1
var Source: int

func _ready():
	if shell == true:
		$Timer.wait_time = 0.3
		$Timer.start()

func _on_body_entered(body):
	# Prevents self damage.

	if Source == 0:
		return
		
	if body.name == 'Cart':
		var by_who = {'name': 'arrow'}
		var by_what = {'power': 1}
		body.hit(by_who, by_what)
		freeze = true
		set_linear_velocity(Vector3.ZERO)
		return
	
	if body.get_multiplayer_authority() == Source:		
		if Source == 1 && body.is_in_group("players"):
			body.hit_sync.rpc(str(Source), Damage)
		return
	
	if Source != 1 && body.is_in_group("players") && body.pvp_on == false:
		return

	if body.has_method("hit"):
		# source, damage, position, rotation
		body.hit_sync.rpc(str(Source), Damage)
		freeze = true
		set_linear_velocity(Vector3.ZERO)
		if multiplayer.is_server(): 
			await get_tree().create_timer(0.3).timeout
			queue_free()

func _on_timer_timeout():
	if multiplayer.is_server():	
		queue_free()
