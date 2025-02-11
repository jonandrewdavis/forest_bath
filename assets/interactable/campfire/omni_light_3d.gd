@tool 

extends OmniLight3D

@export var noise: NoiseTexture3D
var time_passed := 0.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	time_passed += delta
	#print(time_passed)
	
	var sampled_noise = noise.noise.get_noise_1d(time_passed * 2)
	sampled_noise = abs(sampled_noise)
	light_energy = (sampled_noise * 10) / 1.5 + 12
	pass
