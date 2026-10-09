shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

uniform float reveal : hint_range(0.0, 1.0) = 0.0;

float hash_cell(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float soft_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = fract(p);
	blend = blend * blend * (3.0 - 2.0 * blend);
	float lower = mix(hash_cell(cell), hash_cell(cell + vec2(1.0, 0.0)), blend.x);
	float upper = mix(hash_cell(cell + vec2(0.0, 1.0)), hash_cell(cell + vec2(1.0)), blend.x);
	return mix(lower, upper, blend.y);
}

void fragment() {
	float side = abs(UV.x - 0.5) * 2.0;
	float soft_edge = 1.0 - smoothstep(0.82, 1.0, side);
	float distant = smoothstep(0.16, 0.9, UV.y);
	float frost = soft_noise(vec2(UV.x * 7.0, UV.y * 31.0));
	float broken_edge = soft_noise(vec2(UV.y * 19.0, UV.x * 5.0) + 23.0);
	vec3 near_snow = vec3(0.40, 0.47, 0.55);
	vec3 folded_snow = vec3(0.14, 0.18, 0.27);
	ALBEDO = mix(near_snow, folded_snow, distant * (0.58 + frost * 0.18));
	ROUGHNESS = mix(0.82, 0.48, distant);
	SPECULAR = 0.34;
	EMISSION = vec3(0.006, 0.01, 0.022) * distant;
	float emergence = smoothstep(UV.y * 0.92 - 0.05, UV.y * 0.92 + 0.16, reveal);
	float end_fade = 1.0 - smoothstep(0.86, 1.0, UV.y);
	ALPHA = soft_edge * emergence * mix(0.78, 1.0, broken_edge) * mix(1.0, end_fade, distant);
}
