shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float strength : hint_range(0.0, 0.35) = 0.0;
uniform float aspect = 3.0;

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
	vec2 capsule = UV * 2.0 - 1.0;
	float segment_end = max(1.0 - 1.0 / max(aspect, 1.0), 0.0);
	float nearest_end = clamp(capsule.y, -segment_end, segment_end);
	float distance_to_edge = length(vec2(capsule.x, (capsule.y - nearest_end) * aspect));
	float body = 1.0 - smoothstep(0.76, 1.16, distance_to_edge);
	float grain = soft_noise(world_position.xz * 2.8 + vec2(TIME * 0.04, -TIME * 0.027));
	float slow_breath = 0.94 + 0.06 * sin(TIME * 0.55 + world_position.x * 0.4);
	float wisp = smoothstep(0.2, 0.82, grain);
	float alpha = strength * body * mix(0.78, 1.0, wisp) * slow_breath;
	float rim = 1.0 - smoothstep(0.62, 1.12, distance_to_edge);
	ALBEDO = mix(vec3(0.018, 0.026, 0.057), vec3(0.07, 0.045, 0.12), rim * 0.45);
	EMISSION = vec3(0.016, 0.022, 0.052) * rim;
	ALPHA = alpha;
}
