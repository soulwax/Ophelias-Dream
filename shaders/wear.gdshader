shader_type spatial;
render_mode cull_disabled, diffuse_burley;

// Fabric and hair for the walker. Vertex COLOR carries the dye (rgb) and
// roughness (a); meshes without colors read as white and use tint instead.
// Back faces show the lining, so the inside of the coat is never a hole.
// Velvet is mostly a dark dye plus a bright fresnel sheen at grazing angles.

uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 lining : source_color = vec3(0.05, 0.04, 0.05);
uniform float roughness_scale = 1.0;
uniform vec3 sheen_color : source_color = vec3(0.2, 0.19, 0.23);
uniform float sheen = 0.0;
uniform float rim_light = 0.0;
uniform float specular_level = 0.3;
uniform sampler2D weave : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float weave_scale = 24.0;
uniform float weave_depth = 0.3;

void fragment() {
	vec3 dye = COLOR.rgb * tint;
	vec3 surface = FRONT_FACING ? dye : lining;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = mix(surface, sheen_color, fresnel * sheen);
	ROUGHNESS = clamp(COLOR.a * roughness_scale, 0.05, 1.0);
	SPECULAR = specular_level;
	RIM = rim_light;
	RIM_TINT = 0.6;
	NORMAL_MAP = texture(weave, UV * weave_scale).rgb;
	NORMAL_MAP_DEPTH = weave_depth;
}
