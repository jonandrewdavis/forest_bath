extends Node3D

@onready var Bullet_Point = $BulletPoint
var _Camera
var _Viewport
var Player_Ray

var fire_range = 2000
var projectile_velocity = 65
var Spray = Vector2.ZERO
var damage = 1.0
var player_source = false

@onready var BULLET_SCENE = preload("res://player/equipment_system/equipment/bullet.tscn")

var HARDCODED = Vector2(922.0, 518.0)

func _ready():
	if get_parent().is_in_group("players"):
		_Camera = $"../FollowCam".camera_3d
		Player_Ray = $BulletRayCast
		#_Viewport = get_viewport().get_size()
		player_source = true
# players only... since they ahve cameras.
func shoot():	
	var Ray_Origin = _Camera.project_ray_origin(HARDCODED/2)
	var Ray_End = (Ray_Origin + _Camera.project_ray_normal((HARDCODED/2)) * fire_range)
	LaunchProjectile(Ray_End + Vector3.FORWARD + Vector3.FORWARD	)
		#
#var spread_min = 0.008
#var spread = 0.07
func LaunchProjectile(Point: Vector3):
	var Direction_To_Point = (Point - Bullet_Point.global_transform.origin).normalized()
	var Direction = Direction_To_Point * projectile_velocity
	spawn_bullet.rpc(Direction  + Vector3(0.0, 1.3, 0.3), damage, Bullet_Point.global_transform.origin, Point)


@rpc('any_peer', 'call_local')
func spawn_bullet(Direction, Damage, Position, RotationPoint):
	if multiplayer.is_server():
		var Projectile = BULLET_SCENE.instantiate()
		Projectile.position = Position 
		Projectile.set_linear_velocity(Direction)
		Projectile.Damage = Damage
		Projectile.Source = multiplayer.get_remote_sender_id()
		Projectile.is_player_source = player_source
		# I learned the hard way only the server should add things the MultiplayerSpawner will handle the rest.
		Hub.environment_container.add_child(Projectile, true)
		Projectile.look_at(RotationPoint)

		#bullet = bullet_scene.instantiate()
		#bullet.position = pos
		#bullet.transform.basis = rot
		#bullet.is_burst = is_burst
		#bullet.source = multiplayer.get_remote_sender_id()

#
#
## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
	#pass
#
