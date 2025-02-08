extends Node3D

@export var custom_ignore_mesh: MeshInstance3D 
@export var scenery_container: Node3D 

@onready var ignore_zone = MeshInstance3D.new()
@onready var ignore_zone_mesh = CylinderMesh.new()

const HEIGHTMAP_SCALE = 5.0
const HEIGHTMAP_NOISE_WIDTH = 1024

const h_scale = 1.0

const ignore_zone_radius = 17.0

# Called when the node enters the scene tree for the first time.
func _ready():
	add_to_group("encounters")
		
	# Because it's at 0.0.0 when created, we wait a second before emitting, so we have the right global position
	await get_tree().create_timer(0.1).timeout
	
	# TODO: This code doesn't work probably because it needs a spawner, but it should work on each client?
	if custom_ignore_mesh: 
		Hub.environment_ignore_add.emit(custom_ignore_mesh, name)
	else:
		ignore_zone_mesh.bottom_radius = ignore_zone_radius
		ignore_zone_mesh.top_radius = ignore_zone_radius
		ignore_zone_mesh.height = 15.0
		ignore_zone.mesh = ignore_zone_mesh
		ignore_zone.visible = false
		add_child(ignore_zone)
		Hub.environment_ignore_add.emit(ignore_zone, name)
		
		await get_tree().create_timer(0.2).timeout

	height_map_check()

func height_map_check():
	var hmap_img = Hub.HEIGHTMAP.noise.get_image(HEIGHTMAP_NOISE_WIDTH, HEIGHTMAP_NOISE_WIDTH)
	if scenery_container:
		for object in scenery_container.get_children():
			await get_tree().create_timer(0.05).timeout
			object.global_position.y = get_heightmap_y(object.global_position.x, object.global_position.z, hmap_img) + 0.5
			
# If there are no more nearby players, it's safe to remove this encounter:
# TODO: Needs to be RPC'd because server scenario manager is calling as group
func check_for_clean_up(tracker_global_position, despawn_distance):
	var min_distance = INF
	for player in Hub.players_container.get_children():
		min_distance = min(min_distance, global_position.distance_to(player.global_position))

	min_distance = min(min_distance, global_position.distance_to(tracker_global_position))
	if min_distance > despawn_distance:
		Hub.environment_ignore_remove.emit(name)
		for player in Hub.players_container.get_children():
			player.environment_clean_up.rpc(name)
		await get_tree().create_timer(0.1).timeout
		queue_free()

func get_heightmap_y(x, z, _hmap_img):
	var width = _hmap_img.get_width()
	var height = _hmap_img.get_height()
	# Sample the heightmap texture to get the Y position based on X and Z coordinates
	@warning_ignore("integer_division")
	var pixel_x = (width / 2) + x / h_scale 
	@warning_ignore("integer_division")
	var pixel_z = (height / 2) + z / h_scale 
	
	if pixel_x > width: pixel_x -= width 
	if pixel_z > height: pixel_z -= height 
	if pixel_x < 0: pixel_x += width 
	if pixel_z < 0: pixel_z += height 
 
	#var color = hmap_img.get_pixel(pixel_x, pixel_z)
	var color = (_hmap_img.get_pixel(pixel_x, pixel_z).r - 0.5)* HEIGHTMAP_SCALE
	#return color.r * terrain_height * v_scale
	return color
	
@rpc("authority", "call_local")	
func place_location_sync(_position):
	global_position = _position
