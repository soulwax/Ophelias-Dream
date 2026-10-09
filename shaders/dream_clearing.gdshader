shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

varying vec3 world_position;

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

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 shape = (UV - 0.5) * 2.0;
	float edge_distance = length(shape);
	float rim = 1.0 - smoothstep(0.76, 1.0, edge_distance);
	vec2 p = world_position.xz;
	float cloud = soft_noise(p * 0.22);
	float grain = soft_noise(p * 0.83 + 19.0);
	float bend = (soft_noise(p * 0.12 + 7.0) - 0.5) * 1.4;
	float vein_a = abs(sin((p.x * 0.44 + p.y * 0.23 + bend) * 5.2));
	float vein_b = abs(sin((p.y * 0.36 - p.x * 0.18 - bend * 0.7) * 5.7));
	float veins = 1.0 - smoothstep(0.015, 0.07, min(vein_a, vein_b));
	veins *= smoothstep(0.36, 0.72, grain) * rim;
	float frost = smoothstep(0.58, 0.96, edge_distance) * smoothstep(0.35, 0.8, grain);
	vec3 deep_ice = vec3(0.025, 0.052, 0.078);
	vec3 cloudy_ice = vec3(0.22, 0.31, 0.38);
	vec3 ice = mix(deep_ice, cloudy_ice, smoothstep(0.18, 0.86, cloud) * 0.62);
	ice = mix(ice, vec3(0.64, 0.75, 0.81), veins * 0.8);
	ice = mix(ice, vec3(0.57, 0.65, 0.7), frost * 0.44);
	ALBEDO = ice;
	ROUGHNESS = mix(0.11, 0.34, frost + veins * 0.5);
	SPECULAR = 0.82;
	EMISSION = vec3(0.012, 0.026, 0.044) + vec3(0.04, 0.07, 0.09) * veins;
	ALPHA = rim * (0.78 + cloud * 0.12);
}
