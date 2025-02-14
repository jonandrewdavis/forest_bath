// I didn't put a lot of thought into this...
shader_type spatial;
render_mode ensure_correct_normals;

global uniform sampler2D heightmap : filter_linear, repeat_enable;
global uniform float heightmap_scale;

uniform vec3 base_color : source_color = vec3(0.05,0.2,0.01);
uniform vec3 tip_color : source_color = vec3(0.5,0.5,0.1);
uniform vec3 subsurface_scattering_color : source_color = vec3(1.0,0.75,0.1);
uniform sampler2D texture_alb;

varying vec3 vertex_world;

render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform ivec2 albedo_texture_size;
uniform float point_size : hint_range(0.1, 128.0, 0.1);

uniform float roughness : hint_range(0.0, 1.0);
uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;

uniform float specular : hint_range(0.0, 1.0, 0.01);
uniform float metallic : hint_range(0.0, 1.0, 0.01);

uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

void fragment() {
	vec2 base_uv = UV;

	vec4 albedo_tex = texture(texture_albedo, base_uv);
	ALBEDO = albedo.rgb * albedo_tex.rgb;

	float metallic_tex = dot(texture(texture_metallic, base_uv), metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	SPECULAR = specular;

	vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
	float roughness_tex = dot(texture(texture_roughness, base_uv), roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
}

float ease_in_quadratic(float x) {
	return x*x;
}

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	float heightmap_offset = (texture(heightmap, VERTEX.xz / vec2(textureSize(heightmap, 0))).x - 0.5) * heightmap_scale;
	VERTEX.y += heightmap_offset;
	vertex_world = VERTEX;
}

//void fragment() {
 //ALBEDO = mix(base_color*0.05, mix(base_color, tip_color, 0.5)*0.5, min(ease_in_quadratic(length(vertex_world.xz - CAMERA_POSITION_WORLD.xz)*0.01), 1.0));
//}

void light() {
	float diffuse_factor = pow(4.0, dot(NORMAL, LIGHT)) / 4.0; // Diffuse never drops to 0 to simulate ambient bounces
	float sss_factor = max(-dot(VIEW, LIGHT), 0.0) * 0.5;
	DIFFUSE_LIGHT += (diffuse_factor + sss_factor*subsurface_scattering_color) * ATTENUATION * LIGHT_COLOR;
}