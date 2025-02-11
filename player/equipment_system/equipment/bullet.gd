extends RigidBody3D

var shell = false
var Damage: int = 1
var Source: int
var stick_target = null
var is_player_source = false

func _ready():
	if shell == true:
		$Timer.wait_time = 0.3
		$Timer.start()
		
func _process(_delta: float) -> void:
	if freeze == true && stick_target:
		global_position = Vector3(stick_target.global_position.x, global_position.y, stick_target.global_position.z)
		
func _on_body_entered(body):
	# Prevents self damage.
	if Source == 0:
		return
		
	#print(Source, is_player_source, body)
	if Source == 1 && is_player_source && body.is_in_group("players"):
		return 
	elif(is_player_source && body.is_in_group("enemies")):
		if body.has_method("hit"):
			# source, damage, position, rotation
			body.hit_sync.rpc(str(Source), Damage)
			call_deferred('_freeze_arrow', body)
			if multiplayer.is_server(): 
				await get_tree().create_timer(0.3).timeout
				queue_free()
		
	if body.name == 'Cart':
		var by_who = {'name': 'arrow'}
		var by_what = {'power': 1}
		body.hit(by_who, by_what)
		call_deferred('_freeze_arrow', body)
		return

	
	if body.get_multiplayer_authority() == Source:		
		if Source == 1 && body.is_in_group("players"):
			body.hit_sync.rpc(str(Source), Damage)
			call_deferred('_freeze_arrow', body)
		return
	
	#if Source != 1 && body.is_in_group("players") && body.pvp_on == false:
		#return

	if body.has_method("hit"):
		# source, damage, position, rotation
		body.hit_sync.rpc(str(Source), Damage)
		call_deferred('_freeze_arrow', body)
		if multiplayer.is_server(): 
			await get_tree().create_timer(0.3).timeout
			queue_free()

func _on_timer_timeout():
	if multiplayer.is_server():	
		queue_free()


func _freeze_arrow(_body):
	freeze = true
	stick_target = _body
	set_linear_velocity(Vector3.ZERO)
	$CollisionShape3D.disabled = true
