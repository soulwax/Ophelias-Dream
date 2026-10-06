shader_type spatial;
render_mode cull_disabled;

// Weathered cotton canvas for Mathilda's tent: a woven normal, uneven fading,
// damp darkening near the hem, and snow that settles where the panels face up.
uniform vec3 canvas : source_color = vec3(0.50, 0.49, 0.42);
uniform sampler2D weave : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grime : filter_linear_mipmap, repeat_enable;
uniform float weave_scale = 7.0;
uniform float snow_amount = 0.75;
// Height of the tent in metres, so the hem darkens from the ground up.
uniform float height = 1.4;
// Warm light from inside glowing through the cloth.
uniform vec3 glow : source_color = vec3(0.55, 0.32, 0.14);

varying vec3 world_normal;
varying float local_y;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	local_y = VERTEX.y;
}

void fragment() {
	float g = texture(grime, UV * 0.45).r;
	float fine = texture(grime, UV * 3.1).r;
	vec3 cloth = canvas * mix(0.86, 1.05, g) * mix(0.95, 1.02, fine);
	float hem = 1.0 - smoothstep(0.0, 0.35 * height, local_y);
	cloth *= mix(1.0, 0.62, hem * (0.6 + 0.4 * g));
	// Whichever side of the cloth faces the sky gathers snow.
	float up = FRONT_FACING ? world_normal.y : -world_normal.y;
	// An even dusting with soft drifts, not spots: broad variation only, and a
	// little fine noise to break the edge where the slope steepens.
	float settle = smoothstep(0.30, 0.6, up) * mix(0.55, 1.0, smoothstep(0.3, 0.75, g));
	float snow = clamp(settle + (fine - 0.5) * 0.12, 0.0, 1.0) * snow_amount;
	ALBEDO = mix(cloth, vec3(0.90, 0.93, 0.97), snow);
	ROUGHNESS = mix(0.93, 0.70, snow);
	SPECULAR = 0.25;
	NORMAL_MAP = texture(weave, UV * weave_scale).xyz;
	NORMAL_MAP_DEPTH = mix(0.85, 0.2, snow);
	BACKLIGHT = glow * (1.0 - snow);
}
