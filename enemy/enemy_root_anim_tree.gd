extends AnimationTree

var enemy
@onready var last_oneshot = null
@onready var anim_length : float = .5
@onready var state_machine_node : AnimationNodeStateMachinePlayback = self["parameters/Movement/playback"]
signal animation_measured(anim_length)
@export var max_attack_count : int = 3

# Multiplayer note: This is used in the attack tree and needs to be sync'd to work properly
@export var attack_count = 1

@onready var hurt_count :int = 1

var attack_near_dist = .2


# Called when the node enters the scene tree for the first time.
func _ready():
	enemy = get_parent()

	seed(enemy.network_randi_seed)
	
	enemy.attack_started.connect(_on_attack_started)
	enemy.retreat_started.connect(_on_retreat_started)
	enemy.parried_started.connect(_on_parried_started)
	enemy.hurt_started.connect(_on_hurt_started)
	enemy.death_started.connect(_on_death_started)
	animation_started.connect(_on_animation_started)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if not multiplayer or not multiplayer.is_server():
		return

	set_movement()

func set_movement():
	var speed : Vector2 = Vector2.ZERO
	var near
	var target_pos
	var enemy_target = enemy.target
	
	if not enemy_target:
		return

	#if enemy.current_state:
	match enemy.current_state:
		enemy.state.CIRCLE:
			target_pos = enemy_target.global_position
			near = (target_pos.distance_to(enemy.global_position)  < attack_near_dist)
			var dir = 1.0 if attack_count == 1 else -1.0
			speed.x = dir
			speed.y = -0.25
		enemy.state.FREE:
			target_pos = enemy_target.global_position
			near = (target_pos.distance_to(enemy.global_position) < attack_near_dist)
			if enemy.nav_agent_3d.is_navigation_finished():
				speed.y = 0.0
			else:
				speed.y = .5
		enemy.state.CHASE:
			near = (enemy_target.global_position.distance_to(enemy.global_position)  < 4.0)
			if enemy.panic == true:
				speed.y = .65
			elif near:
				speed.y = .62
			else:
				speed.y = 0.90
			

		# AD NOTE: I think that the check in the aniomation tree had 
		#	enemy.current_state == state.COMBAT
		# but that's not right since there's no state enum on this script 
		# so changed it to:
		#	enemy.current_state == enemy.state.COMBAT 
		enemy.state.DEAD:
			speed.y = 0.0
	
	var blend = lerp(get("parameters/Movement/Movement2D/blend_position"),speed,.1)
	if enemy.brute == true:
		blend = lerp(get("parameters/Movement/Movement2D/blend_position"),speed * 0.6,.1)
	set("parameters/Movement/Movement2D/blend_position",blend)
	
func _on_attack_started():
	attack_count = randi_range(1, max_attack_count)
	if enemy.brute == true:
		attack_count = 5
	request_oneshot("attack")

func _on_retreat_started():
	attack_count = randi_range(1, 2)
	request_oneshot("retreat")

func request_oneshot(oneshot:String):
	last_oneshot = oneshot
	set("parameters/" + oneshot + "/request",true)
	if is_multiplayer_authority():
		# allows the attack_count to sync'd for the client animation trees to pick up - AD.
		await get_tree().create_timer(.05).timeout 
		request_oneshot_sync.rpc(oneshot)

@rpc("any_peer", "call_remote")
func request_oneshot_sync(oneshot:String):
	last_oneshot = oneshot
	set("parameters/" + oneshot + "/request",true)

func abort_oneshot(oneshot):
	set("parameters/"+ str(oneshot) + "/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	if is_multiplayer_authority():
		abort_oneshot_sync.rpc(oneshot)

@rpc("any_peer", "call_remote")
func abort_oneshot_sync(oneshot):
	set("parameters/"+ str(oneshot) + "/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)

func _on_hurt_started():
	hurt_count = randi_range(1,2)
	if enemy.brute == false:
		abort_oneshot(last_oneshot)
		request_oneshot("hurt")
	if is_multiplayer_authority():
		_on_hurt_started_sync.rpc()
	
@rpc("any_peer", "call_remote")
func _on_hurt_started_sync():
	hurt_count = randi_range(1,2)
	if enemy.brute == false:
		abort_oneshot(last_oneshot)
		request_oneshot("hurt")

func _on_parried_started():
	abort_oneshot(last_oneshot)
	request_oneshot("parried")
	
func _on_death_started():
	abort_oneshot(last_oneshot)
	state_machine_node.travel("Dead")

func _on_animation_started(anim_name):
	anim_length = get_node(anim_player).get_animation(anim_name).length
	animation_measured.emit(anim_length)
