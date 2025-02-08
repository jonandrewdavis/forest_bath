extends GPUParticles3D



# NOTE: Without this authority check, each new player would adjust the trigget to THEM, resulting in the 
# flames pointing FROM the position of the LATEST JOINED PLAYER. This is incorrect. 
# Each of the "clones" were taking posession, away from the real player, as they all had torches.
# Latest clone wins (without this "is_multiplayer_authority" check).

# Note that the multiplayer authority is properly inherited because it's a child of the player!
func _ready():
	if is_multiplayer_authority():
		Hub.equipment_is_using.connect(point_at_cart)

func point_at_cart(_new_value):
	if is_multiplayer_authority():
		if Hub.get_cart() && _new_value == true:
			var cart = Hub.get_cart()
			var particle_dir_texture: CurveXYZTexture = process_material.directional_velocity_curve
			var dir_to = get_parent().global_position.direction_to(cart.global_position)
			particle_dir_texture.curve_x.clear_points()
			particle_dir_texture.curve_z.clear_points()
			particle_dir_texture.curve_x.add_point(Vector2(dir_to.x, dir_to.x))
			particle_dir_texture.curve_z.add_point(Vector2(dir_to.z, dir_to.z))
		else:
			var particle_dir_texture: CurveXYZTexture = process_material.directional_velocity_curve
			particle_dir_texture.curve_x.clear_points()
			particle_dir_texture.curve_z.clear_points()
