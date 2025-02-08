# CUSTOM COLLISION SHAPE: DO NOT USE. 

@tool

extends StaticBody3D

@onready var col = $CollisionShape3D

var heightmap: NoiseTexture2D
var shape: HeightMapShape3D = HeightMapShape3D.new()

var test_image = Image.new()

# Called when the node enters the scene tree for the first time.
func _ready():
	heightmap = get_parent().heightmap
	
	if !Engine.is_editor_hint():
		await heightmap.changed
	
	var hmap_img = heightmap.get_image()
	
	# We're not ready yet, return early. May require editor refresh
	if Engine.is_editor_hint() && !hmap_img:
		return
		
	var size = hmap_img.get_width()
	
	# Groundcover for the collsiion shape
	$MeshInstance3D.get_surface_override_material(0).set_shader_parameter('noise', hmap_img)
	
	# 10.0 is the special noise map fix. Could probably do it with SCALE

	#Scaling Issue:
	# The multiplication by 10.0 in your heightmap generation is applying a uniform scale to all height values.
	# This can exaggerate the heights at the edges if your noise function produces larger values there.

	# Generate 32-bit noise and import it with scale
	#var noise := FastNoiseLite.new()
	#noise.frequency = 0.05
	var hmap_data_image: Image = Image.create(size, size, false, Image.FORMAT_RF)
	for x in size:
		for y in size:
			hmap_data_image.set_pixel(x, y, Color(heightmap.noise.get_noise_2d(x, y), 0., 0., 1.))
			
	print('DEBUG: COLLISION MAP GEN', hmap_data_image)
	shape.map_width = hmap_data_image.get_width()
	shape.map_depth = hmap_data_image.get_height()
	shape.map_data = hmap_data_image.get_data().to_float32_array()
	col.shape = shape
	pass # Replace with function body.
