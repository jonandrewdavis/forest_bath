shader_type canvas_item;


uniform vec3 luminance: source_color = vec3(0.3086, 0.6094, 0.0820);
uniform float brightness: hint_range(0.01, 20.0, .01) = 0.26;
uniform float contrast: hint_range(1.0, 4.0, .01) = 3.0;
uniform float scale: hint_range(0.1, 10.0, .01) = 1.0;
uniform float rotation: hint_range(0.00, 6.28, .01) = 0.08;
uniform float resolution_downsampling: hint_range(0.0, 8.0, 0.0) = 4.0;
uniform sampler2D screen_texture: hint_screen_texture, filter_nearest, repeat_disable;


mat2 rotate(float a) {
	float sa = sin(a);
	float ca = cos(a);
	return mat2(vec2(ca, sa), vec2(-sa, ca));
}

float dot_matrix(vec2 uv) {
	vec2 rot_uv = rotate(rotation) * uv * scale;
	return sin(rot_uv.x) * sin(rot_uv.y);
}

void fragment() {
	vec2 UV_new = SCREEN_UV - mod(SCREEN_UV, SCREEN_PIXEL_SIZE * resolution_downsampling);
	vec2 resolution = 1.0/SCREEN_PIXEL_SIZE;
	vec3 color = texture(screen_texture, UV_new).rgb;
	//float grey = dot(color, luminance) * contrast;
	//color = vec3(color + dot_matrix(UV * resolution));
	//float vignette = smoothstep(0.45, 0.1, distance(UV, vec2(0.5))) * 1.0;

	//float v_x = smoothstep(0.45, 0.1, distance(UV.x, 0.5));
	//float v_y = smoothstep(0.45, 0.1, distance(UV.y, 0.5));

	COLOR = vec4(color, 1.0);
}