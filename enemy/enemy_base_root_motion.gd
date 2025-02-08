extends CharacterBody3D

@export var group_name :String = "targets"
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var nav_agent_3d = $NavigationAgent3D
@onready var animation_tree = $AnimationTree
@onready var anim_length = .5

@export var speed :float = 4.0
@onready var direction : Vector3 = Vector3.ZERO

@export var target_sensor : Area3D 
@export var target : Node3D
## Use for pathfinding, it will return to following this default target after
## giving up a chase. Most commonly this is a pathfollow node, following a Path.
## if left blank, then the default target is simply the same locationw here this
## enemy spawns.
@export var health_system : HealthSystem

@export var default_target : Node3D
@onready var spawn_location : Marker3D = Marker3D.new()
var combat_range :float = 1.9
@onready var combat_timer: Timer = $CombatTimer
@onready var chase_timer: Timer = $ChaseTimer2
@onready var patrol_timer: Timer = $PatrolTimer

@onready var hurt_cool_down = $HurtTimer
@onready var ragdoll_death :bool = false
@onready var general_skeleton = $vampire/GeneralSkeleton

var colliding_with_target = false

signal hurt_started
signal damage_taken
signal parried_started
signal death_started
signal attack_started
signal retreat_started
signal smash_signal

@export var archer = false
@export var brute = false

# Added export for multiplayer for this - AD 
@export var current_state = state.FREE : set = update_current_state # Enemy states controlled by enum PlayerStates

enum state {
	FREE,
	CHASE,
	COMBAT,
	ATTACK,
	DEAD,
	CIRCLE
}
signal state_changed

var panic = false

func _enter_tree() -> void:
	set_multiplayer_authority(1)

@export var network_randi_seed = 1

func _ready():
	seed(network_randi_seed)
	
	if archer == true:
		combat_range = 10.0
		$EquipmentSystem/BoneAttachment3D.visible = false
	else:
		$EquipmentSystem/LeftHand.visible = false

	if brute == true:
		$vampire.scale = Vector3(3.0, 3.0, 3.0)
		$EquipmentSystem/BoneAttachment3D/HandPivot.scale = Vector3(1.3, 1.3, 1.3)
		combat_range = 3.5
		$CollisionShape3D.scale = Vector3(2.2, 2.2, 2.2)
		$CollisionShape3D.position  = $CollisionShape3D.position + Vector3(0.0, 0.9, 0.0)

	if animation_tree:
		animation_tree.animation_measured.connect(_on_animation_measured)
	
	hurt_cool_down.one_shot = true
	
	add_to_group(group_name)
	add_to_group('enemies')
	collision_layer = 5

	set_default_target()

	if health_system:
		if brute == true:
			health_system.total_health = 25
			health_system.current_health = 25
			health_system.max_health_updated.emit(25)
			health_system.health_updated.emit(25)
		else:
			var curr_max = Hub.enemy_max
			health_system.total_health = curr_max
			health_system.current_health = curr_max
			health_system.max_health_updated.emit(curr_max)
			health_system.health_updated.emit(curr_max)				

		health_system.died.connect(death)

	multiplayer.peer_disconnected.connect(_remove_player_change_target)

	if multiplayer.is_server():
		patrol_timer.timeout.connect(_on_patrol_timer_timeout)
		combat_timer.timeout.connect(_on_combat_timer_timeout)
		chase_timer.timeout.connect(_on_chase_timer_timeout)
		combat_timer.start()

		if target_sensor:
			target_sensor.target_spotted.connect(_on_target_spotted)
			#target_sensor.target_lost.connect(_on_target_lost)
		
		$AttackAreaSensor.body_entered.connect(_on_target_entered)
		$AttackAreaSensor.body_exited.connect(_on_target_exited)
	else:
		# NOTE: HUUUUUUUUUUGE frame rate and processing savings if we disable Collision shapes on the client side. 24 -> 60 fps
		# NOTE: TODO: make sure all collisions still happen for the most part! 
		set_process(false)
		set_physics_process(false)
		$AttackAreaSensor/AttackAreaCollisionShape.disabled = true


func _remove_player_change_target(id):
	if target.name == str(id) or default_target.name == str(id):
		target = Hub.get_random_player()
		default_target = Hub.get_cart()

func _on_target_entered(_body):
	if _body == target:
		colliding_with_target = true
		
func _on_target_exited(_body):
	colliding_with_target = false
		
func _process(delta):
	apply_gravity(delta)
	if current_state == state.DEAD:
		return

	if target == null:
		return
	rotate_character()
	navigation()
	free_movement(delta)
	if current_state != state.CIRCLE && panic == false:
		evaluate_state()
	
func free_movement(delta):
	#set_quaternion(get_quaternion() * animation_tree.get_root_motion_rotation())
	var rate : float # imiates directional change acceleration rate
	if is_on_floor():
		rate = .5
	else:
		rate = .1
	var new_velocity = get_quaternion() * animation_tree.get_root_motion_position() / delta

	if is_on_floor():
		velocity.x = move_toward(velocity.x, new_velocity.x, rate)
		velocity.y = move_toward(velocity.y, new_velocity.y, rate)
		velocity.z = move_toward(velocity.z, new_velocity.z, rate)
	else:
		velocity.x = move_toward(velocity.x, calc_direction().x * speed, rate)
		velocity.z = move_toward(velocity.z, calc_direction().z * speed, rate)
		
	move_and_slide()
		
func calc_direction() -> Vector3 :
	var new_direction = global_transform.basis.z
	return new_direction
	
func update_current_state(_new_state):
	current_state = _new_state
	state_changed.emit(_new_state)
	
# TODO: Tons of bugs in navigation
# TODO: Painful to strip y index everywhere. The default target is always above or below the mesh	
func navigation():
	if target != null:
		if panic:
			nav_agent_3d.target_position = target.global_position * Vector3(1.0,0,1.0) * -1.0
		elif is_patrolling && current_state == state.FREE: 
			nav_agent_3d.target_position = target.global_position + Vector3(patrol_dir.x, 0.0, patrol_dir.y) 
		else:
			nav_agent_3d.target_position = target.global_position
		var new_dir = (nav_agent_3d.get_next_path_position() - global_position).normalized()
		new_dir *= Vector3(1,0,1) # strip the y value so enemy stays at current level
		direction = new_dir

func rotate_character():
	if animation_tree.get("parameters/attack/active") == true && brute == true:
		return  

	var rate = .05
	var new_direction = global_position.direction_to(nav_agent_3d.get_next_path_position())
	var current_rotation = global_transform.basis.get_rotation_quaternion()
	var target_rotation = current_rotation.slerp(Quaternion(Vector3.UP, atan2(new_direction.x, new_direction.z)), rate)
	global_transform.basis = Basis(target_rotation)

func evaluate_state(): ## depending on distance to target, run or walk
	if target:
		if target == default_target && target.is_in_group("targets") == false:			
			current_state = state.FREE
		else:
			if target != null:
				var current_distance = global_position.distance_to(target.global_position)
				if current_distance > combat_range:
					if colliding_with_target: 
						current_state = state.COMBAT
						#_on_combat_timer_timeout()
					else:
						current_state = state.CHASE
				elif current_distance <= combat_range && current_state != state.COMBAT:
					current_state = state.COMBAT
					
## added random times between attacks. Might be a bit much
func _on_combat_timer_timeout():
	if target == null:
		return
	if current_state == state.COMBAT && is_multiplayer_authority():
		if target.is_in_group("players") && target.is_dead:
			target = Hub.get_cart()
			default_target = Hub.get_cart()
			combat_timer.start(randf_range(0.7,2.8))
			return

		if target.is_in_group("cart") && target.is_dead:
			target = Hub.get_random_player()
			default_target = Hub.get_cart()
			combat_timer.start(randf_range(0.7,2.8))
			return

		if archer == true:
			if target != null && global_position.distance_to(target.global_position) < combat_range / 4: 
				if randi_range(0, 1) == 0:
					start_panic()
					combat_timer.stop()
				return
			attack_ranged()
			combat_timer.start(randf_range(4.0,5.0))
			return

		if brute == true:
			attack.rpc()
			combat_timer.start(randf_range(6.0, 7.0))
			await get_tree().create_timer(2.6).timeout 
			_smash()
			return	
			
		@warning_ignore("integer_division")
		if health_system.current_health < (health_system.total_health / 2):
			if randi_range(0, 3) == 0:
				start_panic() 
				return

		combat_randomizer()
		combat_timer.start(randf_range(0.7,2.8))

func start_panic():
	panic = true
	current_state = state.CHASE
	await get_tree().create_timer(5.0).timeout 
	panic = false
	current_state = state.COMBAT
	combat_timer.start(1.0)

func combat_randomizer():
	if multiplayer.is_server():
		if colliding_with_target == true:
			attack.rpc()

		var random_choice = randi_range(1,30)
		if random_choice <= 4:
			retreat.rpc()
		if random_choice <= 8:
			circle.rpc()
		else:
			attack.rpc()

# Multiplayer: changed to RPCs so the emits activate the equipment.
@rpc("authority", "call_local")
func attack():
	attack_started.emit()
	chase_timer.start()

func attack_ranged():
	animation_tree.request_oneshot("shoot")
	await get_tree().create_timer(1.4).timeout 
	# Allows strafing / evading... they can't be perfect, but if you're standing still they hit.
	var save_prev_pos = target.global_position
	await get_tree().create_timer(0.4).timeout 
	# if no target or we get hurt:
	if target != null && animation_tree.get("parameters/shoot/active") == true:  
		$ArrowSystem.LaunchProjectile(save_prev_pos + Vector3(0.0, 0.8, 0.0))

@rpc("authority", "call_local")
func retreat(): # Back away for a period of time
	retreat_started.emit()

@rpc("authority", "call_local")
func circle(): 
	animation_tree.attack_count = randi_range(1, 2)
	await get_tree().create_timer(.1).timeout 
	update_current_state(state.CIRCLE)
	await get_tree().create_timer(randi_range(3, 6)).timeout
	update_current_state(state.COMBAT)
	
func set_default_target(): 
	await get_tree().create_timer(1.0).timeout
	$EnemyMarkerSpawn.global_position = global_position * Vector3(1.0, 0, 1.0)
	if not default_target:
		default_target = $EnemyMarkerSpawn
	if !target:
		target = default_target

func set_new_default_target(_new_default_target: Node3D):
	if _new_default_target:
		default_target = _new_default_target
		target = default_target
			
func _target_to_player_node(_spotted_target: Node3D):
	for player in Hub.players_container.get_children():
		if player.name == _spotted_target.name:
			return player

func _on_target_spotted(_spotted_target): # Updates from a TargetSensor if a target is found.
	if target != null && target.name != _spotted_target.name:
		target = _spotted_target
		chase_timer.start()

func _on_chase_timer_timeout():
	give_up()
	
func give_up():
	await get_tree().create_timer(3).timeout
	target = default_target
	
func apply_gravity(_delta):
	if !is_on_floor():
		velocity.y -= gravity * _delta
		move_and_slide()

func hit(_by_who, _by_what):
	#var get_player_targeted = _target_to_player_node(_by_who)
	#if (get_player_targeted):
		#target = get_player_targeted
		#if hurt_cool_down.is_stopped():
			#hurt_cool_down.start()
			#hurt_started.emit()
			#damage_taken.emit(_by_what)
	if (_by_who.name && _by_what.power):
		hit_sync.rpc(_by_who.name, _by_what.power)

@rpc("any_peer", "call_local")
func hit_sync(_by_who_name: String, power: int):
	if is_multiplayer_authority():
		# During RPC, this is an EncodedObjectAsID, so if we're host, let's  instance_from_id before:
		var get_player_targeted = Hub.get_player_by_name(_by_who_name)
		if (get_player_targeted):
			target = get_player_targeted

		if hurt_cool_down.is_stopped():
			hurt_cool_down.start(0.4)
			hurt_started.emit()
			sync_back_hit.rpc()
			damage_taken.emit(power)

@rpc("any_peer", "call_local")
func knockback_enemy(_dir):
	velocity = velocity + _dir * 9

@rpc("any_peer", "call_local")
func sync_back_hit():
		hurt_started.emit()

@rpc("any_peer", "call_local")
func parried():
	if multiplayer.is_server() && hurt_cool_down.is_stopped():
		combat_timer.stop()
		parried_started.emit()
		combat_timer.start(3)
		
func death():
	combat_timer.stop()
	update_current_state(state.DEAD)
	hurt_cool_down.start(10)
	death_sync.rpc()
	if multiplayer.is_server():
		await get_tree().create_timer(2.0).timeout
		Hub.add_coins(randi_range(1,5))
	# Note: always queue_free on the server. - AD
	await get_tree().create_timer(2.0).timeout
	if multiplayer.is_server():
		if target.is_in_group("players"):
			target.get_kill.rpc()
		queue_free()
		
@rpc("any_peer", "call_local")
func death_sync():
	update_current_state(state.DEAD)
	remove_from_group(group_name)
	if ragdoll_death:
		apply_ragdoll()
	else:
		death_started.emit()

# TODO: Ragdoll on the clients
func apply_ragdoll():
	general_skeleton.physical_bones_start_simulation()
	animation_tree.active = false
	
	# if you want to stop the rag doll after a few seconds, uncomment this code.
	await get_tree().create_timer(3).timeout
	var bone_transforms = []
	var bone_count = general_skeleton.get_bone_count()
	for i in bone_count:
		bone_transforms.append(general_skeleton.get_bone_global_pose(i))
	general_skeleton.physical_bones_stop_simulation()
	for i in bone_count:
		general_skeleton.set_bone_global_pose_override(i, bone_transforms[i],1,true)

func _on_animation_measured(_new_length):
	anim_length = _new_length - .05 # offset slightly for the process frame

var is_patrolling = false
var patrol_dir: Vector2

func _on_patrol_timer_timeout():
	if current_state == state.FREE && is_patrolling == false && randi_range(0, 2) != 0:
		patrol_dir = Vector2.from_angle(randf() * 2 * PI) * 10 # spawn radius
		is_patrolling = true
		patrol_timer.start(randi_range(5, 10))
	else:
		is_patrolling = false
		patrol_timer.start(randi_range(8, 16))


func _smash():
	_sound.rpc()
	for player in Hub.players_container.get_children():
		if global_position.distance_to(player.global_position) < 3.0:
			var normal_dir = player.global_position.direction_to(self.global_position).normalized()
			#player.apply_central_impulse(normal_dir * 1.5)
			#player.apply_impulse(normal_dir * 0.01, get_position())
			player.knockback.rpc(-normal_dir + Vector3(0.0, 0.4, 0.0))

@rpc('any_peer', 'call_local')
func _sound():
	smash_signal.emit()
