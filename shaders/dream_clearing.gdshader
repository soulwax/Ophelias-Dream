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
	float fracture_field = soft_noise(p * 0.42 + vec2(bend, -bend * 0.63));
	float veins = 1.0 - smoothstep(0.012, 0.034, abs(fracture_field - 0.51));
	veins *= smoothstep(0.42, 0.72, soft_noise(p * 0.17 + 31.0)) * rim;
	float fine_fracture = 1.0 - smoothstep(0.009, 0.024, abs(soft_noise(p * 0.91 + 53.0) - 0.48));
	veins = max(veins, fine_fracture * smoothstep(0.64, 0.82, grain) * rim * 0.24);
	float frost = smoothstep(0.58, 0.96, edge_distance) * smoothstep(0.35, 0.8, grain);
	vec3 deep_ice = vec3(0.045, 0.08, 0.115);
	vec3 cloudy_ice = vec3(0.27, 0.37, 0.44);
	vec3 ice = mix(deep_ice, cloudy_ice, smoothstep(0.18, 0.86, cloud) * 0.62);
	ice = mix(ice, vec3(0.62, 0.73, 0.79), veins * 0.48);
	ice = mix(ice, vec3(0.57, 0.65, 0.7), frost * 0.44);
	ALBEDO = ice;
	ROUGHNESS = mix(0.16, 0.42, frost + veins * 0.4);
	SPECULAR = 0.76;
	EMISSION = vec3(0.012, 0.026, 0.044) + vec3(0.04, 0.07, 0.09) * veins;
	ALPHA = rim * (0.66 + cloud * 0.12);
}
