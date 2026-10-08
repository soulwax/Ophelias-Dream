shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_lambert_wrap, specular_disabled;

// Wood smoke on GPUParticles3D billboards. Each puff is noise, not a disc: its
// edge breaks up, it turns slowly, and it erodes from the thin parts inward
// as it ages, the way real smoke thins out rather than fades. It is lit, so
// the fire warms it from below and the dusk greys it, and it melts softly into
// anything it touches. INSTANCE_CUSTOM.x is its spin, .y its age (0..1).
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear;
uniform vec3 tint : source_color = vec3(0.6, 0.6, 0.62);
uniform float density = 0.85;
uniform float softness = 0.5;

varying float age;
varying float seed;
varying float spin;

void vertex() {
	mat4 face = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	face = face * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * face;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	age = INSTANCE_CUSTOM.y;
	spin = INSTANCE_CUSTOM.x;
	seed = fract(float(INSTANCE_ID) * 0.6180339);
}

void fragment() {
	vec2 c = UV - 0.5;
	float cs = cos(spin * 0.4 + age * 1.2);
	float sn = sin(spin * 0.4 + age * 1.2);
	vec2 r = vec2(c.x * cs - c.y * sn, c.x * sn + c.y * cs);
	vec2 p = r * 0.9 + vec2(seed * 7.1, seed * 3.3);
	float n = texture(noise, p + vec2(0.0, -TIME * 0.02)).r * 0.6
		+ texture(noise, p * 2.4 + vec2(TIME * 0.015, seed)).r * 0.3
		+ texture(noise, p * 5.1 - vec2(seed, TIME * 0.03)).r * 0.1;
	float d = length(c) * 2.0;
	float puff = 1.0 - smoothstep(0.2, 1.0, d + (n - 0.5) * 0.7);
	float erode = smoothstep(age * 0.75 - 0.05, age * 0.75 + 0.3, n);
	float life = smoothstep(0.0, 0.1, age) * (1.0 - smoothstep(0.55, 1.0, age));
	// Soft edge against the ground, the tent and the logs.
	float scene = texture(depth_texture, SCREEN_UV).r;
	vec4 world = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	world.xyz /= world.w;
	float fade = clamp((VERTEX.z - world.z) / softness, 0.0, 1.0);
	ALBEDO = tint * COLOR.rgb * mix(0.78, 1.06, n);
	ALPHA = clamp(puff * erode * life * density * fade * COLOR.a, 0.0, 1.0);
	ROUGHNESS = 1.0;
	BACKLIGHT = vec3(0.35);
}
