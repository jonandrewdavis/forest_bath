extends CharacterBody3D

@export_range(1,50,1) var mouse_sensitivity = 15.0
@export_range(1,50,1) var joystick_sensitivity = 15.0

# MULTIPLAYER TEMPLATE VARS
# MULTIPLAYER TEMPLATE VARS
@export var coins: int = 0
@export var kills: int = 0
@export var deaths: int = 0

const CONST_MAX_HEALTH = 8;
const CONST_MAX_STAMNIA = 30;

@export var max_stamina: int = CONST_MAX_STAMNIA
@export var stamina: int = CONST_MAX_STAMNIA

@onready var nickname: Label3D = $PlayerNick/Nickname

@export_category("Objects")
#@export var _body: Node3D = null
#@export var _spring_arm_offset: Node3D = null

# MULTIPLAYER TEMPLATE VARS
# MULTIPLAYER TEMPLATE VARS
@onready var sensor_cast : ShapeCast3D
@export var animation_tree : AnimationTree

# Mutliplayer : Exported - AD. for combo attacks
@export var anim_length = .5 # updates as new animnations start
signal event_finished
## default/1st camera is a follow cam.
@onready var current_camera = get_viewport().get_camera_3d()

## Aids strafe rotation when alternating between cameras. I found it best to keep
## track of whatever the starting camera was, rather than update it if camera's change.
@onready var orientation_target = current_camera

## Interactables that update based on entering a Ladder Area or, the sensor_cast
## colliding with an interactable.
@onready var interactable : Node3D

# Added this... -AD
@onready var interactable_custom : Node3D

@onready var ladder
signal climb_started
signal interact_started(interact_type)

## A generic EquipmentSystem class, used to manage moving Weapons 
## between a hand and sheathed location as well as activating collision hitbox 
## monitoring and reporting hits have happened. Very handy.
@export var weapon_system : EquipmentSystem

## A helper variable, tracks the current weapon type for easier referencing from
## the animation_tree and anywhere else that may want to know what weapon type is held.
var weapon_type :String = "SLASH"
signal weapon_change_started ## to start the animation
signal weapon_change_ended(weapon_type:String) ## informing the change is complete
signal attack_started ## to start the animation
signal attack_requested


## New stuff - AD
signal eyeline_check
signal menu_open
signal open_debug


## A helper variable for keyboard events across 2 key inputs "shift+ attack", etc.
## there may be a better way to capture combo key presses across multiple device types,
## but this worked for me in a pinch.
var secondary_action

## Gadgets and guarding equipment system that manages moving nodes from the 
## off-hand, to their hip location, the same EquipmentSystem as the weapon system.
@export var gadget_system : EquipmentSystem
## A helper variable, tracks the current gadget type for easier referencing from
## the AnimationStateTree or anywhere else that may need to know what gadget type is held.
@export var gadget_type :String = "SHIELD"
signal gadget_change_started ## to start the animation
signal gadget_change_ended(gadget_type:String) ## to end the animation
signal gadget_started ## when the gadget attack starts

@export var gadget_power = 0

## When guarding this substate is true. Drives animation and hitbox logic for blocking.
## The first moments of guarding, the parry window is active, allowing to parry()
## attacks and avoid damage


## Turns on when the perfect parry window is active, making regular blocks turn into parries.
@export var parry_active = false
## How brief the perfect parry window is in seconds.
@export var parry_window = .3
signal parry_started
signal block_started

## The HealthSystem node that will take in information about damage and healing received.
@export var health_system : HealthSystem
@onready var hurt_cool_down = Timer.new() # while running, player can't be hurt
signal hurt_started # to start the animation
signal damage_taken(by_what:EquipmentObject) # to indicate the damage value
signal health_received(by_what:ItemObject) # CHANGED to just be power - AD
signal death_started
@export var is_dead :bool = false

@export var inventory_system : InventorySystem
var current_item : ItemResource
signal item_change_started
signal item_change_ended(current_item:ItemObject)
signal use_item_started
signal item_used

var is_using_item = false
@export var pvp_on = false

# Jump and Gravity
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var jump_velocity = 8
@onready var last_altitude = global_position
@export var hard_landing_height :float = 2 # how far they can fall before 'hard landing'
signal landed_fall(hard_or_soft:String)
signal jump_started

## Dodge and Sprint Mechanics.
@onready var sprint_timer :Timer = Timer.new()
signal dodge_started
signal sprint_started
signal stamina_depleted

# Movement Mechanics
@export var input_dir : Vector2
@export var default_speed = 6.0
@onready var speed = default_speed

@export_category("PLAYER NETWORK EXPORTS")

# Strafing
@export var strafing :bool = false # substate - EXPORTED FOR MULTIPLAYER
@onready var strafe_cross_product = 0.0
@onready var move_dot_product = 0.0
signal strafe_toggled(toggle:bool)

# Laddering
signal ladder_started(top_or_bottom:String)
signal ladder_finished(top_or_bottom:String)


# State management
enum state {FREE,STATIC,CLIMB}

#  EXPORTED FOR MULTIPLAYER
#  EXPORTED FOR MULTIPLAYER
#  EXPORTED FOR MULTIPLAYER
#  EXPORTED FOR MULTIPLAYER
#  EXPORTED FOR MULTIPLAYER

@export var busy : bool = false # substate: to prevent input spamming
@export var guarding = false # substate
@export var sprinting : bool = false # substate
@export var dodging : bool = false # substate
@export var slowed : bool = false # substate:  force a slower walking speed

@export var current_state = state.FREE : set = change_state
signal changed_state(new_state: state)

var is_out_of_bounds = false

# TODO: Enum? ADDED - AD 11/21/2024
var combo_enabled_weapons = ['SLASH', 'HEAVY']
var two_handed_weapons = ['HEAVY', 'BOW']

signal store_error
signal store_success
signal store_loot

@onready var sprint_drain_timer = $SprintDrainTimer

## MULTIPLAYER TEMPLATE FUNCS
## MULTIPLAYER TEMPLATE FUNCS

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
## MULTIPLAYER TEMPLATE FUNCS
## MULTIPLAYER TEMPLATE FUNCS


func _ready():
	## MULTIPLAYER TEMPLATE FUNCS
	# NOTE: Replicated vars + rpc on `request_oneshot` should cover ALL cases.
	# NOTE: That means we can disable any signals if we're not authority.
	set_process(is_multiplayer_authority())
	if not is_multiplayer_authority():
		if multiplayer.is_server():
			set_physics_process(false)
		return
	
	$GUI.hide()
		
	if animation_tree:
		animation_tree.animation_measured.connect(_on_animation_measured)
		
	if weapon_system:
		weapon_system.equipment_changed.connect(_on_weapon_equipment_changed)
		
	if gadget_system:
		gadget_system.equipment_changed.connect(_on_gadget_equipment_changed)
		
	if inventory_system:
		inventory_system.item_used.connect(_on_inventory_item_used)
			
	if health_system:
		health_system.health_updated.connect(func(_health): %HealthLabel.text = str(_health * 10))
		%HealthLabel.text = str(health_system.current_health * 10)
		health_system.died.connect(death)
		
	climb_started.connect(_on_climb_started)
	$RelocateTimer.timeout.connect(_show_environment)
	
	nickname.visible = false

	$FollowCam.eyeline_enter.connect(_on_eyeline_enter)
	$FollowCam.eyeline_exit.connect(_on_eyeline_leave)

	add_child(sprint_timer)
	sprint_timer.one_shot = true
	
	hurt_cool_down.one_shot = true
	hurt_cool_down.wait_time = .5
	add_child(hurt_cool_down)

	if animation_tree:
		await animation_tree.animation_measured
	await get_tree().create_timer(anim_length).timeout
	current_state = state.FREE

	sprint_drain_timer.timeout.connect(stamina_drain)
	
	#weapon_change_ended.emit(weapon_type)
	health_system.total_health = CONST_MAX_HEALTH
	health_system.max_health_updated.emit(CONST_MAX_HEALTH)
	$GUI/GUIFullRect/HealthMarginContainer/HealthBar.max_value = CONST_MAX_HEALTH
	await get_tree().process_frame
	health_received.emit(CONST_MAX_HEALTH)

	Hub.coin.connect(get_coin)
	store_error.connect(_on_update_coin)
	store_success.connect(_on_update_coin)
	store_loot.connect(_on_loot_added)
	
	# TODO: Remove before launch
	DebugMenu.style = DebugMenu.Style.VISIBLE_COMPACT
	DebugMenu.hide()
	
## Makes variable changes for each state, primiarily used for updating movement speeds
func change_state(new_state):
	## MULTIPLAYER TEMPLATE FUNCS
	# NOTE: Not required for basinc functioning, BUT: probably doesn't ever leave FREE.	
	if not is_multiplayer_authority():
		return

	current_state = new_state
	changed_state.emit(current_state)
	
	match current_state:
		state.FREE:
			speed = default_speed

		state.STATIC:
			speed = 0.0
			velocity = Vector3.ZERO
	
	# TODO: Add back ladders........................ - AD
	# Currently, we're disabling another way, on weapon change, to enforce a disadvantage on 2 handers.
	
	#if current_state == state.CLIMB:
		#system_visible(weapon_system,false)
		#system_visible(gadget_system,false)
	#else:
		#system_visible(weapon_system,true)
		#system_visible(gadget_system,true)

func _process(_delta):
	%StaminaBar.value = stamina
	%StaminaLabel.text = str(stamina)
	if is_on_floor() == true && busy == false && sprinting == false && guarding == false:
		recover_stamina()


func _physics_process(_delta):
	## MULTIPLAYER TEMPLATE FUNCS
	# NOTE: All 3 Required for all authorities because of "flying" bug.
	# TODO: Adding Ladders may just need everything here.
	#for col_idx in get_slide_collision_count():
		#var col := get_slide_collision(col_idx)
		#if col.get_collider() is RigidBody3D:
			#col.get_collider().apply_central_impulse(-col.get_normal() * 1.2)
			#col.get_collider().apply_impulse(-col.get_normal() * 0.01, col.get_position())
#
   ## col.get_collider().apply_impulse(-col.get_normal() * 100 * delta, col.get_position() - col.get_collider().global_position)

	if not is_multiplayer_authority():
		apply_gravity(_delta)
		fall_check()
		move_and_slide()
		return

	match current_state:
		state.FREE:
			rotate_player()
			
		state.CLIMB:
			set_root_climb(_delta)
			
	set_root_move(_delta)
	move_and_slide()
	apply_gravity(_delta)
	fall_check()
	out_of_bounds_check()
	
func _input(_event:InputEvent):
	if not is_multiplayer_authority():
		return
		
	if $FollowCam.is_menu_open == true:
		return

	# Update current orientation to camera when nothing pressed
	if !Input.is_anything_pressed():
		current_camera = get_viewport().get_camera_3d()

	if is_dead:
		return
	## strafe toggle on/off
	if _event.is_action_pressed("strafe_target"):
		set_strafe_targeting()
		
	# a helper for keyboard controls, not really used for joypad
	#if Input.is_action_pressed("secondary_action"):
		#secondary_action = true
	#else:
		#secondary_action = false

	if _event.is_action_pressed("use_weapon_light"):
		emit_signal("attack_requested")
	
	if current_state == state.FREE:
		if nickname.text == 'z' && busy == false:
			attack()

		if _event.is_action_pressed("debug"):
			Hub.spawn_enemy_at_location.rpc(global_position)

		if _event.is_action_pressed("debug_1"):
			print("DEBUG: Killing all enemies")
			Hub.debug_kill_all_enemies_sync.rpc()

		if _event.is_action_pressed("debug_2"):
			open_debug.emit()
			
		if _event.is_action_pressed("debug_3"):
			Hub.add_coins(5)

		if _event.is_action_pressed("debug_4"):
			Hub.debug_spawn_new_brute.rpc(global_position)

		if _event.is_action_pressed("debug_5"):
			Hub.increase_enemy_health.rpc()

		if _event.is_action_pressed("use_weapon_light") && hurt_cool_down.is_stopped():
			attack()
		elif _event.is_action_pressed("use_weapon_strong"):
			attack_strong()
		if is_on_floor():
			# if interactable exists, activate its action
			if _event.is_action_pressed("interact"):
				interact()
			
			elif _event.is_action_pressed("jump"):
				jump()
				
			elif _event.is_action_pressed("sprint"):
				sprint()
				
			elif _event.is_action_pressed("dodge"):
				dodge()
			
			elif _event.is_action_pressed("change_primary"):
				weapon_change()
			elif _event.is_action_pressed("change_secondary"):
				gadget_change()

			elif _event.is_action_pressed("use_gadget_strong"):
				use_gadget()
					
			elif _event.is_action_pressed("use_gadget_light"):
				if two_handed_weapons.has(weapon_system.current_equipment.equipment_info.object_type):
					if weapon_type == "BOW":
						start_guard()
					# early return to disallow two handed from doing any gadgets
					return
				if secondary_action:
					use_gadget()
				elif gadget_type == "SHIELD":
					start_guard()
								
			elif _event.is_action_pressed("change_item"):
				item_change()
			elif _event.is_action_pressed("use_item"):
				use_item()
	
	elif current_state == state.CLIMB:
			#aiming = false
		if _event.is_action_pressed("interact"):
			abort_climb()
	
	if sprinting:
		
		if !input_dir:
			end_sprint()
		
		if _event.is_action_released("sprint"):
			end_sprint()
		
		if stamina == 0:
			end_sprint()
			start_recovery()
				
	if _event.is_action_released("use_gadget_light"):
		end_guard()

func apply_gravity(_delta):
	if !is_on_floor() \
	&& current_state != state.CLIMB:
		velocity.y -= gravity * _delta
		
func rotate_player():
	if busy && not dodging && not is_using_item:
		return

	var rate = .15
	
	var target_rotation
	var current_rotation = global_transform.basis.get_rotation_quaternion()
	# FreeCam rotation code, slerps to input oriented to the camera perspective, and only calculates when input is given
	if strafing:
		rate = .4
		# StrafeCam code - Look at target, slerping current rotation to the camera's rotation.
		target_rotation = current_rotation.slerp(Quaternion(Vector3.UP, orientation_target.global_rotation.y + PI), rate)
		global_transform.basis = Basis(target_rotation)
		var new_direction = calc_direction().normalized()
		
		var forward_vector = global_transform.basis.z.normalized()
		strafe_cross_product = -forward_vector.cross(new_direction).y
		move_dot_product = forward_vector.dot(new_direction)
		return
	
	if input_dir:
		var new_direction = calc_direction().normalized()
		# Rotate the player per the perspective of the camera
		target_rotation = current_rotation.slerp(Quaternion(Vector3.UP, atan2(new_direction.x, new_direction.z)), rate)
		global_transform.basis = Basis(target_rotation)

func set_strafe_targeting():
	strafing = !strafing
	strafe_toggled.emit(strafing)
	
func _on_target_cleared():
	strafing = false

func attack_face_forward():
	var rate = 1.0
	var target_rotation
	var current_rotation = global_transform.basis.get_rotation_quaternion()
	var new_direction = calc_direction_based_on_camera().normalized()
	
	# Rotate the player per the perspective of the camera
	target_rotation = current_rotation.slerp(Quaternion(Vector3.UP, orientation_target.global_rotation.y + PI), rate)
	global_transform.basis = Basis(target_rotation)
	
	var forward_vector = global_transform.basis.z.normalized()
	strafe_cross_product = -forward_vector.cross(new_direction).y
	move_dot_product = forward_vector.dot(new_direction)




# AD Notes:
# Lots of changes to attacking to enable combos and face forward on start.
# Signals still used to emit effects & enable weapons
func attack():
	if dodging or weapon_type == "OTHER":
		return
	attack_face_forward()
	if busy == true:
		return

	if weapon_type == "BOW":
		if guarding == true:
			busy = true
			animation_tree.request_oneshot("Shoot")
			animation_tree.attack_once()
			$ArrowSystem.shoot()
		return

	busy = true
	if not is_on_floor():
		animation_tree.request_oneshot("Attack")
		animation_tree.attack_air()
		return

	if sprinting:
		animation_tree.request_oneshot("Attack")
		animation_tree.attack_once()
		return

	if combo_enabled_weapons.has(weapon_type):
		animation_tree.attack_count = 1
		animation_tree.attack_chain()
	else:
		animation_tree.request_oneshot("Attack")
		animation_tree.attack_once()


# TODO: Implement
func attack_strong():
	pass
	#attack_face_forward()
	#if busy or dodging:
		#return
	#secondary_action = true
	#trigger_event("attack_started")
	#await attack_started
	#secondary_action = false


func fall_check():
	## If you leave the floor, store last position.
	## When you land again, compare the distances of both location y values, if greater
	## than the hard_landing_height, then trigger a hard landing. Otherwise, 
	## clear the last_altitude variable.

	if !is_on_floor() && last_altitude == null:
		last_altitude = global_position
	if is_on_floor() && last_altitude != null:
		var fall_distance = last_altitude.y - global_position.y
		if fall_distance > hard_landing_height:
			trigger_event("landed_fall")
		last_altitude = null
		# Helps air attacks "land"
		if busy:
			busy = false
			


func sprint():
	if sprint_timer.is_stopped():
		sprint_timer.start(.3)
		await sprint_timer.timeout
		if !dodging && input_dir:
			sprinting = true
			sprint_started.emit() # triggers the change in anim tree
			sprint_drain_timer.start()

func end_sprint():
	sprinting = false
	sprint_drain_timer.stop()
			
var guard_local
var strafe_local

func dodge():
	if dodging or busy:
		return
		
	if check_stamina(actions.DODGE) == false:
		return
		
	# While dodging, save out theese locals	
	guard_local = guarding
	strafe_local = strafing
	busy = true

	guarding = false
	strafing = false
	dodging = true
	dodge_started.emit()
	
	# Stop the weapon from being active during dodge since we allow dodge interrupts
	# to attacks - AD 10/30/2024
	if weapon_system:
		weapon_system.deactivate.emit()
	
	if animation_tree:
		await animation_tree.animation_measured
	hurt_cool_down.start(anim_length)
	await get_tree().create_timer(anim_length).timeout
	guarding = guard_local
	strafing = strafe_local
	dodging = false
	busy = false
 
func _on_animation_measured(_new_length ):
	anim_length = _new_length - .05

func interact():
	if is_on_floor() && !busy:
		# ADDED: For shopping... & Cart - AD
		if interactable_custom && interactable_custom.name == 'Cart':
			interactable_custom.get_parent().activate(self)
		elif interactable_custom && interactable_custom.get_parent().has_method("activate"):
			interactable_custom.get_parent().activate(self, interactable_custom.name)
		elif interactable && interactable.has_method("activate"):
			interactable.activate(self)
		elif ladder:
			ladder.activate(self)

func _on_climb_started():
	#interactable = null
	current_state = state.CLIMB
	
func abort_climb():
	if current_state == state.CLIMB:
		last_altitude = global_position
		current_state = state.FREE

func weapon_change():
	if busy or guarding:
		return	
	is_using_item = true
	slowed = true
	#_should_show_bow(false)
	if weapon_system.stored_equipment != null && weapon_system.stored_equipment.equipment_info.object_type == "BOW":
		$WeaponSystem/BackBone.visible = false
		$WeaponSystem/LeftHand.visible = false
		$WeaponSystem/RightHand.visible = true
	trigger_event("weapon_change_started")
	await event_finished
	if two_handed_weapons.has(weapon_type):
		system_visible(gadget_system,false)
	else:
		system_visible(gadget_system,true)
	weapon_change_ended.emit(weapon_type)
	slowed = false
	is_using_item = false
	if weapon_system.current_equipment != null && weapon_system.current_equipment.equipment_info.object_type == "BOW":
		$WeaponSystem/RightHand.visible = false
		$WeaponSystem/LeftHand.visible = true
		$WeaponSystem/BackBone.visible = true
	
func _on_weapon_equipment_changed(_new_weapon:EquipmentObject):
	weapon_type = _new_weapon.equipment_info.object_type

func _on_gadget_equipment_changed(_new_gadget:EquipmentObject):
	if _new_gadget:
		gadget_power = _new_gadget.equipment_info.power
		gadget_type = _new_gadget.equipment_info.object_type

func _on_inventory_item_used(_item):
	current_item = _item
	
func gadget_change():
	slowed = true
	trigger_event("gadget_change_started")
	await event_finished
	gadget_change_ended.emit(gadget_type)
	await get_tree().create_timer(anim_length *.5).timeout
	slowed = false

# TODO: We're just using health potion for now.
func item_change():
	return
	#slowed = true
	#trigger_event("item_change_started")
	#await event_finished
	#item_change_ended.emit(current_item)
	#slowed = false
	
func start_guard(): # Guarding, and for a short window, parring is possible
	set_strafe_targeting()
	slowed = true
	guard_local = true
	strafe_local = true
	guarding = true
	Hub.equipment_is_using.emit(true)
	if weapon_type != "BOW":
		parry_active = true
		await get_tree().create_timer(parry_window).timeout
		parry_active = false

func end_guard():
	guarding = false
	guard_local = false
	strafe_local = false
	slowed = false
	strafing = false
	strafe_local = false
	strafe_toggled.emit(false)
	Hub.equipment_is_using.emit(false)

func use_gadget(): # emits to start the gadget, and runs some timers before stopping the gadget
	trigger_event("gadget_started")

func hit(_who, _by_what):
	if is_dead:
		return
	if parry_active:
		parry.rpc()
		if _who.has_method("parried"):
			_who.parried.rpc()
			return
	else:
		if _who.is_in_group("enemies"):
			if _who.brute == true:	
				hit_sync.rpc(_who.name, _by_what.power + 2)

	hit_sync.rpc(_who.name, _by_what.power)
			
@rpc("any_peer", "call_local")
func hit_sync(_by_who_name: String, power: int):
	if is_dead:
		return
	if multiplayer.get_remote_sender_id() != 1 && pvp_on == false:
		return

	# only get hit by things on your client.
	if is_multiplayer_authority():
		if parry_active:
			return

		if hurt_cool_down.is_stopped() == false:
			return
		elif guarding && gadget_power != 0:
			block()
			stamina = stamina - 5
			if stamina <= 0:
				hurt_cool_down.start(0.3)
				end_guard()
		else:
			hurt()
			damage_taken.emit(power)
			if Hub.get_player_by_name(_by_who_name) != null &&  power > 1:
				var normal_dir = Hub.get_player_by_name(_by_who_name).global_position.direction_to(self.global_position).normalized()
				velocity = velocity + (normal_dir + Vector3(0.0, 0.4, 0.0))  * 10

func heal(_by_what):
	health_received.emit(_by_what.power)

func block():
	block_started.emit()

@rpc('any_peer', 'call_local')
func parried():
	if is_multiplayer_authority():
		animation_tree.abort_oneshot(animation_tree.last_oneshot)
		animation_tree._on_attack_end()
		busy = true
		animation_tree.request_oneshot("Parried")
		await get_tree().create_timer(4.0).timeout
		busy = false

@rpc('any_peer', 'call_local')
func parry():
	if is_multiplayer_authority():
		parry_active = true
		parry_started.emit()
		if animation_tree:
			await animation_tree.animation_measured
		await get_tree().create_timer(anim_length).timeout
		hurt_cool_down.start(anim_length)
		parry_active = false
		
func hurt():
	hurt_started.emit() # before state change in case on ladder,etc
	if animation_tree:
		await animation_tree.animation_measured
	hurt_cool_down.start(anim_length + 0.8)
	await get_tree().create_timer(anim_length).timeout

func use_item():
	if inventory_system.current_item.count == 0:
		return
	if not busy or dodging:
		busy = true
		slowed = true
		is_using_item = true
		use_item_started.emit()
		await get_tree().create_timer(anim_length * .5).timeout
		item_used.emit()
		await get_tree().create_timer(anim_length * .5).timeout
		slowed = false
		busy = false
		is_using_item = false
		
# TODO: Death is messy.
# TODO: Reset their weapons somehow.................
# TODO: Would be nice to do anyway so they can drop something. 
func death():
	if is_dead == true:
		return
	deaths = deaths + 1
	#$CollisionShape3D.disabled = true
	hurt_cool_down.start(8.0)
	current_state = state.STATIC
	is_dead = true
	# TODO: Death is hacky. Don't call directly perhaps?	
	animation_tree._on_death_started()
	await get_tree().create_timer(0.2).timeout
	$FootstepSoundSystem/TriggeredSounds/LifeCardAnimations/LifeDeathCard/DeathSound.play()
	await get_tree().create_timer(3).timeout
	visible = false
	await get_tree().create_timer(5).timeout
	restore()

# TODO: Needs to take all your weapons away.
# Could also orbit the Cart cam for a hot second... 
# Could... also. QUEUE Free the player for a bit. LOL.
func restore():
	# I'm kind of a genius 0_0. i just reversed the Store shopping logic (after like 2hours) to strip loot
	replace_loot_on_system.rpc('WeaponSystem', "empty_scene")
	replace_loot_on_system.rpc('GadgetSystem', "empty_scene")
	health_system.total_health = CONST_MAX_HEALTH
	health_system.max_health_updated.emit(CONST_MAX_HEALTH)
	max_stamina = CONST_MAX_STAMNIA
	coins = 0
	_on_update_coin()
	health_received.emit(CONST_MAX_HEALTH)
	global_position = get_spawn_point() + Hub.get_cart().global_position
	is_dead = false
	visible = true
	current_state = state.FREE
	animation_tree._on_weapon_change_ended('')
	animation_tree._on_spawn_started()
	$WeaponSystem/RightHand.visible = true
	$WeaponSystem/BackBone.visible = true
	$WeaponSystem/LeftHand.visible = false

func get_spawn_point() -> Vector3:
	var spawn_point = Vector2.from_angle(randf() * 2 * PI) * 10 # spawn radius
	return Vector3(spawn_point.x, 5.0, spawn_point.y)

func system_visible(_system_node,_new_toggle):
	if _system_node:
		_system_node.visible = _new_toggle

func trigger_interact(interact_type:String):
	if busy:
		return
	busy = true
	interact_started.emit(interact_type)
	await animation_tree.animation_measured
	await get_tree().create_timer(anim_length).timeout
	busy = false

func trigger_event(signal_name:String):
	if busy or dodging:
		return
	trigger_event_sync.rpc(signal_name)
	busy = true
	emit_signal(signal_name)
	await animation_tree.animation_measured
	await get_tree().create_timer(anim_length).timeout
	event_finished.emit()
	busy = false

@rpc("any_peer", "call_remote")
func trigger_event_sync(signal_name):
	emit_signal(signal_name)
	await animation_tree.animation_measured
	await get_tree().create_timer(anim_length).timeout
	event_finished.emit()

func jump():
	# Handle jump.
	# Added some extra checks to prevent nonsense - AD.
	if is_on_floor() && busy == false && dodging == false && guarding == false:
		if check_stamina(actions.JUMP) == false:
			return
		jump_started.emit()
		await get_tree().create_timer(.1).timeout # for the windup
		velocity.y = jump_velocity

func set_root_move(delta):
	input_dir = Input.get_vector("move_left","move_right","move_up","move_down")
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

	
func set_root_climb(delta):
	input_dir = Input.get_vector("move_left","move_right","move_up","move_down")
	
	var rate = 2
	var new_velocity = get_quaternion() * animation_tree.get_root_motion_rotation() * animation_tree.get_root_motion_position() / delta
	
	#velocity = lerp (velocity,new_velocity,rate) #buggier than move_toward
	velocity.x = move_toward(velocity.x, new_velocity.x, rate)
	velocity.y = move_toward(velocity.y, new_velocity.y, rate)
	velocity.z = move_toward(velocity.z, new_velocity.z, rate)
	# dismount logic
	if !sensor_cast.is_colliding():
		#print("cast not colliding")
		current_state = state.FREE
		last_altitude = global_position
		var dismount_pos = to_global(Vector3.BACK)
		dismount_pos.y += .5
		var tween = create_tween()

		tween.tween_property(self,"global_position",dismount_pos,.3)
	if is_on_floor():
		current_state = state.FREE
		#free_started.emit()
		
func calc_direction() -> Vector3 :
	var new_direction = (current_camera.global_transform.basis.z * input_dir.y + \
	current_camera.global_transform.basis.x * input_dir.x)
	return new_direction

# New: - AD
func calc_direction_based_on_camera() -> Vector3:
	var new_camera_direction = current_camera.global_transform.basis.z + current_camera.global_transform.basis.x
	return new_camera_direction
	
	
	
# MULTIPLAYER TEMPLATE RPCS
# MULTIPLAYER TEMPLATE RPCS

@rpc("any_peer", "reliable")
func change_nick(new_nick: String):
	if nickname:
		nickname.text = new_nick
		
#@rpc("any_peer", "reliable")
#func set_player_skin(skin_name: String) -> void:
	#var texture = get_texture_from_name(skin_name)
	#var bottom: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Bottom")
	#var chest: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Chest")
	#var face: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Face")
	#var limbs_head: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Llimbs and head")
	#
	#set_mesh_texture(bottom, texture)
	#set_mesh_texture(chest, texture)
	#set_mesh_texture(face, texture)
	#set_mesh_texture(limbs_head, texture)
	
# MULTIPLAYER TEMPLATE RPCS
# MULTIPLAYER TEMPLATE RPCS

# So that we're not in falling state during engine hint
func prevent_engine():
	return not Engine.is_editor_hint()

func get_coin(amount):
	coins = coins + amount
	# Adds the coins (GetLoot) sound.
	_on_update_coin()
	store_loot.emit()

func _on_update_coin():
	$GUI/GUIFullRect/MarginContainer/ItemSlot/CoinCount.text = str(coins)
	
func _on_eyeline_enter(_interactable):
	if _interactable && _interactable.is_in_group("interactable") or _interactable.name == "Cart":
		$GUI/GUIFullRect/InteractTooltip.text = str(_interactable.name)
		interactable_custom = _interactable
	
func _on_eyeline_leave(_interactable):
	$GUI/GUIFullRect/InteractTooltip.text = ''
	interactable_custom = null


## EQUIPMENT
var shield_scene = preload("res://player/equipment_system/equipment/shield.tscn")
var axe_scene = preload("res://player/equipment_system/equipment/Ax.tscn")
var bow_scene = preload("res://player/equipment_system/equipment/Bow.tscn")
var empty_scene = preload("res://player/equipment_system/equipment/EmptyEquipment.tscn")

## EQUIPMENT

var new_packed_scene = {
	"shield_scene": shield_scene,
	"axe_scene": axe_scene,
	"bow_scene": bow_scene,
	"empty_scene": empty_scene
}

# NOTE: This is an RPC because we are spawning items (see mulitplayer spawner in player).
@rpc("authority", "call_local")
func replace_empty_on_system(system_name, scene_name, cost: int):
	if Hub.get_player(multiplayer.get_remote_sender_id()).coins < cost:
		store_error.emit()
		return
	var system = get_node_or_null(system_name)
	if system != null:
		var mount_string = system._find_empty_pivot()
		if mount_string != null:
			var mount_point = system[mount_string]
			var free_eq = mount_point.get_child(0)
			mount_point.remove_child(free_eq)
			var new_scene = new_packed_scene[scene_name].instantiate()
			system[mount_string].add_child(new_scene)
			if mount_string == "held_mount_point":
				system.current_equipment = new_scene
				system._on_stop_signal()
				if (system.name == 'GadgetSystem'):
					_on_gadget_equipment_changed(system.current_equipment)
				else:
					_on_weapon_equipment_changed(system.current_equipment)
					if system.current_equipment.equipment_info.object_type == "BOW":
						weapon_change()
						weapon_change()
			else:
				system.stored_equipment = new_scene
				system.stored_equipment.equipped = false
				system.stored_equipment.monitoring = false
				# Remove the empty equipment
			coins = coins - cost
			store_success.emit()
			# sound
			# TODO: Double emit here... lame
			store_loot.emit()
			await get_tree().create_timer(.1).timeout
			free_eq.queue_free()
		else:
			store_error.emit()

@rpc("authority", "call_local")
func replace_loot_on_system(system_name, scene_name):
	var system = get_node_or_null(system_name)
	if system != null:
		var mount_string = system._find_loot_pivot(["Ax", "Bow", "Shield"])
		if mount_string != null:
			var mount_point = system[mount_string]
			var free_eq = mount_point.get_child(0)
			mount_point.remove_child(free_eq)
			var new_scene = new_packed_scene[scene_name].instantiate()
			system[mount_string].add_child(new_scene)
			if mount_string == "held_mount_point":
				system.current_equipment = new_scene
				system._on_stop_signal()
				if (system.name == 'GadgetSystem'):
					_on_gadget_equipment_changed(system.current_equipment)
				else:
					_on_weapon_equipment_changed(system.current_equipment)
			else:
				system.stored_equipment = new_scene
				system.stored_equipment.equipped = false
				system.stored_equipment.monitoring = false
				# Remove the empty equipment
			await get_tree().create_timer(.1).timeout
			free_eq.queue_free()
				
# TODO: make this a lot more robust
func spawn():
	$GUI.show()
	#animation_tree.abort_oneshot(animation_tree.last_oneshot)
	#animation_tree.request_oneshot("Spawn")
	
func add_new_potion(_cost):
	if coins >= _cost:
		$InventorySystem.add_potion()
		coins = coins - _cost
		store_success.emit()
	else:
		store_error.emit()


enum actions { SLASH, DODGE, BOW, HEAVY, JUMP}

var actions_cost = {
	actions.SLASH: 6,
	actions.DODGE: 12,
	actions.BOW: 7,
	actions.HEAVY: 9,
	actions.JUMP: 12,
}

func check_stamina(_action: actions):
	var current_cost = actions_cost[_action]
	if current_cost <= stamina: 
		stamina = stamina - current_cost	
		return true
	else:
		flash_stamina()
		return false

func start_recovery():
	$RecoveryTimer.start(0.6)

func recover_stamina():
	if $RecoveryTimer.time_left == 0:
		$RecoveryTimer.start(0.1)
		stamina = clamp(stamina + 2, 0, max_stamina)

func flash_stamina():
	stamina_depleted.emit()
	start_recovery()
	%StaminaContainer.modulate.a = 0
	await get_tree().create_timer(0.1).timeout
	%StaminaContainer.modulate.a = 1
	await get_tree().create_timer(0.1).timeout
	%StaminaContainer.modulate.a = 0
	await get_tree().create_timer(0.1).timeout
	%StaminaContainer.modulate.a = 1


func stamina_drain():
	if is_on_floor() == false:
		return
	if stamina == 0:
		end_sprint()
		return
	stamina = stamina - 2
	
var mult_lerp = 0.0001
var dark_lerp = 0.8
	
func out_of_bounds_check():
	if abs(global_position.x) < 350.0 && abs(global_position.z) < 350.0:
		fog(false)
		return
	
	if abs(global_position.x) > 490.0 or abs(global_position.z) > 490.0:
		if not $RelocateTimer.is_stopped():
			return
		var sign1 = 1 if (randi_range(0,1) == 1) else -1
		var sign2 = 1 if (randi_range(0,1) == 1) else -1
		global_position.x = randi_range(0, 450) * sign1
		global_position.z = randi_range(0, 450) * sign2
		global_position.y = 1.7
		fog(true, 0.01, 0.0)
		Hub.get_environment_root()._on_hide()
		$RelocateTimer.start(1.5)
		return

	if abs(global_position.x) > 465.0 or abs(global_position.z) > 465.0:
		fog(true, 0.001, 0.3)
	elif abs(global_position.x) > 430.0 or abs(global_position.z) > 430.0:
		fog(true, 0.0004, 0.6)
	elif abs(global_position.x) > 390.0 or abs(global_position.z) > 390.0:
		fog(true, 0.0002, 0.9)
	elif abs(global_position.x) > 350.0 or abs(global_position.z) > 350.0:
		fog(true, 0.0001)

func _show_environment():
	Hub.get_environment_root()._on_show()

func fog(on, mult = 0.0005, dark = 1.0):
	if $RelocateTimer.time_left > 0:
		return
	mult_lerp = lerp(mult_lerp, mult, 0.5)
	dark_lerp = lerp(dark_lerp, dark, 0.5)
	if on:
		if abs(global_position.x) > abs(global_position.z):
			Hub.world_environment.environment.volumetric_fog_density = clampf(mult_lerp * abs(global_position.x), 0.07, 1.0)
		else:
			Hub.world_environment.environment.volumetric_fog_density = clampf(mult_lerp * abs(global_position.z), 0.07, 1.0)
		Hub.world_environment.environment.adjustment_brightness = dark_lerp
	else:
		Hub.world_environment.environment.volumetric_fog_density = clampf(mult_lerp, 0.07, 1.0)
		Hub.world_environment.environment.adjustment_brightness = dark_lerp
		
# TODO: more Signals emit
func get_loot():
	var random = randi_range(0, 2)
	match random:
		0:
			health_system.total_health = health_system.total_health + 1
			$GUI/GUIFullRect/HealthMarginContainer/HealthBar.max_value = health_system.total_health
			health_system.max_health_updated.emit(health_system.total_health)
			store_loot.emit('+10 Health.')
			await get_tree().create_timer(1).timeout
			health_received.emit(health_system.total_health)
		1:
			max_stamina = max_stamina + 5
			%StaminaBar.max_value = max_stamina
			store_loot.emit('+5 Stamina.')
			await get_tree().create_timer(1).timeout
			start_recovery()
		2:
			var coin_rand = randi_range(8, 18)
			get_coin(coin_rand)	
			store_loot.emit('+' + str(coin_rand) + ' coin')

func _on_loot_added(_status = null):
	if _status:
		var status_label = $PlayerNick/Status
		status_label.text = _status
		status_label.visible = true
		await get_tree().create_timer(1.2).timeout
		status_label.visible = false
		status_label.text = ''


@rpc("any_peer", "call_local")
func environment_clean_up(_encounter_name: String):
	print('DEBUG: Removing Encounter:', _encounter_name)
	Hub.environment_ignore_remove.emit(_encounter_name)


@rpc('any_peer', 'call_local')
func knockback(_dir):
	velocity = velocity + _dir * 8

@rpc("any_peer", 'call_local')
func get_kill():
	if is_multiplayer_authority():
		kills = kills + 1
