shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

// Procedural multi-octave billowing snow wisp shader for ground spindrift
// ribbons and mid-air squall veils. Avoids depth-texture reads so hundreds
// of overlapping quads render effortlessly on both discrete and integrated GPUs.

uniform float softness : hint_range(0.1, 3.0) = 1.35;
uniform float density_boost : hint_range(0.2, 3.0) = 1.1;

varying vec4 v_color;
varying float v_seed;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	// Billboard quad facing the camera while preserving particle rotation and scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(INV_VIEW_MATRIX[0].xyz), 0.0),
		vec4(normalize(INV_VIEW_MATRIX[1].xyz), 0.0),
		vec4(normalize(INV_VIEW_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
	v_color = COLOR;
	v_seed = INSTANCE_CUSTOM.x;
}

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	// Guaranteed zero at all four quad edges so billboards never show hard seams.
	float radial = clamp(1.0 - dot(centered * vec2(1.08, 1.22), centered * vec2(1.08, 1.22)), 0.0, 1.0);
	radial = pow(radial, softness);

	float edge_x = smoothstep(0.0, 0.26, UV.x) * (1.0 - smoothstep(0.74, 1.0, UV.x));
	float edge_y = smoothstep(0.0, 0.30, UV.y) * (1.0 - smoothstep(0.70, 1.0, UV.y));
	float envelope = radial * edge_x * edge_y;

	vec2 flow1 = UV * vec2(3.2, 2.0) + vec2(TIME * 0.65 + v_seed * 7.3, -TIME * 0.18);
	vec2 flow2 = UV * vec2(6.4, 3.8) - vec2(TIME * 0.92 - v_seed * 11.1, TIME * 0.27);
	vec2 flow3 = UV * vec2(11.5, 6.2) + vec2(TIME * 1.25 + v_seed * 17.9, TIME * 0.14);
	float turb = noise2d(flow1) * 0.52 + noise2d(flow2) * 0.31 + noise2d(flow3) * 0.17;
	float wisp = smoothstep(0.24, 0.80, turb);

	float alpha = clamp(wisp * envelope * v_color.a * density_boost, 0.0, 1.0);
	ALBEDO = v_color.rgb;
	ALPHA = alpha;
}
