shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_disabled;

uniform vec3 shadow_tint : source_color = vec3(0.028, 0.022, 0.052);
uniform float opacity : hint_range(0.0, 0.95) = 0.76;
uniform float dissolve : hint_range(0.0, 0.25) = 0.0;
uniform float lantern_warmth : hint_range(0.0, 1.0) = 0.0;

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
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - clamp(facing, 0.0, 1.0), 2.6);
	float breath = sin(TIME * 1.15 + UV.y * 8.0 + UV.x * 2.0) * 0.028;
	float veil = sin(TIME * 0.62 - UV.y * 5.2) * 0.022;
	float noise = soft_noise(UV * vec2(39.0, 63.0) + vec2(TIME * 0.2, -TIME * 0.12));
	float cutoff = dissolve * 3.2;
	float intact = dissolve <= 0.001 ? 1.0 : 1.0 - smoothstep(cutoff - 0.035, cutoff + 0.035, noise);
	float edge = 1.0 - smoothstep(cutoff, cutoff + 0.09, noise);
	ALBEDO = shadow_tint + vec3(0.018, 0.027, 0.075) * rim;
	ALBEDO += vec3(0.095, 0.047, 0.012) * rim * lantern_warmth;
	ALBEDO += vec3(0.12, 0.10, 0.23) * edge * step(0.001, dissolve);
	ALPHA = clamp(opacity + rim * 0.15 + breath + veil, 0.0, 0.92) * intact;
	EMISSION = vec3(0.018, 0.026, 0.085) * (0.12 + rim) * opacity;
}
