shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

// Nature wind animation shader for winter trees, pines, spruces, bushes, and grasses.
// Animates trunk sway, branch oscillation, and foliage micro-flutter driven by the wind.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.35;
uniform float roughness : hint_range(0.0, 1.0) = 0.92;
uniform float specular : hint_range(0.0, 1.0) = 0.2;

uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool normal_enabled = false;

uniform sampler2D ao_texture : filter_linear_mipmap, repeat_enable;
uniform bool ao_enabled = false;

uniform sampler2D orm_texture : filter_linear_mipmap, repeat_enable;
uniform bool orm_enabled = false;

uniform vec4 backlight : source_color = vec4(0.18, 0.22, 0.14, 1.0);
uniform bool backlight_enabled = true;

// Wind motion uniforms
uniform vec2 wind_dir = vec2(0.92, 0.38);
uniform float wind_speed = 2.4;
uniform float wind_strength = 1.0;
uniform float trunk_sway = 0.08;
uniform float branch_sway = 0.12;
uniform float leaf_flutter = 0.04;
uniform float height_reference = 12.0;
uniform bool is_undergrowth = false;

// A spatially coherent gust field keeps neighbouring trees moving together,
// while each crown still responds at a slightly different phase.
float wind_field(vec3 p, vec2 direction, float speed) {
	vec2 crosswind = vec2(-direction.y, direction.x);
	float along = dot(p.xz, direction);
	float across = dot(p.xz, crosswind);
	float travel = TIME * speed;
	float broad = sin(along * 0.035 - travel * 0.42 + sin(across * 0.018 + travel * 0.13) * 0.8);
	float medium = sin(along * 0.11 - travel * 0.78 + across * 0.035);
	return 1.0 + broad * 0.22 + medium * 0.12;
}

varying vec3 world_normal;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);

	vec2 w_dir = normalize(wind_dir);
	float h = max(VERTEX.y, 0.0);
	
	if (is_undergrowth) {
		// Undergrowth / grass: fast ripples along ground traveling downwind.
		float grass_h = clamp(h / 1.2, 0.0, 1.0);
		float ripple = sin(dot(world_pos.xz, w_dir * 0.8) - TIME * wind_speed * 2.2);
		float cross_ripple = cos(dot(world_pos.xz, vec2(-w_dir.y, w_dir.x) * 1.4) + TIME * wind_speed * 1.6);
		vec2 grass_disp = w_dir * (ripple * 0.12 + cross_ripple * 0.05) * grass_h * wind_strength;
		VERTEX.xz += grass_disp;
	} else {
		// Trees: quadratic trunk sway increasing with height from ground.
		float height_ratio = clamp(h / height_reference, 0.0, 1.4);
		float eased_height = clamp(height_ratio, 0.0, 1.0);
		float height_ease = eased_height * eased_height * (3.0 - 2.0 * eased_height);
		float field = wind_field(world_pos, w_dir, wind_speed);
		float force = wind_strength * field;
		// Displacement grows from the root to the crown, giving the trunk a
		// readable whole-tree lean instead of only shaking the needles.
		float trunk_bend = pow(height_ratio, 1.8) * trunk_sway * force;
		vec2 crosswind = vec2(-w_dir.y, w_dir.x);
		float crown_phase = dot(world_pos.xz, w_dir * 0.075 + crosswind * 0.023);
		float crown_sway = sin(crown_phase - TIME * wind_speed * 0.58) * 0.72
			+ sin(crown_phase * 0.53 - TIME * wind_speed * 0.31 + 1.7) * 0.28;
		vec2 trunk_disp = w_dir * crown_sway * trunk_bend;

		// Branches flex out of phase with the trunk, strongest in the crown.
		float branch_phase = dot(world_pos, vec3(0.37, 0.19, 0.51)) - TIME * wind_speed * 1.15;
		float branch_act = height_ease * clamp(height_ratio * 1.25, 0.0, 1.0);
		float branch_wave = sin(branch_phase + sin(branch_phase * 0.31) * 0.7);
		vec3 branch_disp = vec3(w_dir.x, 0.0, w_dir.y) * branch_wave * branch_sway * branch_act * force;
		branch_disp += vec3(crosswind.x, 0.0, crosswind.y) * cos(branch_phase * 0.73 + 0.8) * branch_sway * 0.32 * branch_act * force;
		branch_disp.y = sin(branch_phase * 0.67 + 1.1) * branch_sway * 0.12 * branch_act * force;

		// Fine needle flutter follows faster, smaller turbulence in the crown.
		float micro_phase = dot(world_pos.xz, vec2(1.7, 2.3)) - TIME * (4.2 + wind_speed * 0.42);
		float turbulence = sin(micro_phase + sin(micro_phase * 0.37)) * 0.65 + cos(micro_phase * 1.41) * 0.35;
		float micro_flutter = turbulence * leaf_flutter * branch_act * force;

		VERTEX.xz += trunk_disp + branch_disp.xz;
		VERTEX.y += branch_disp.y;
		VERTEX += NORMAL * micro_flutter;
	}
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	vec4 col = tex * albedo_color;
	ALBEDO = col.rgb;
	ALPHA = col.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	if (orm_enabled) {
		vec3 orm = texture(orm_texture, UV).rgb;
		AO = orm.r;
		ROUGHNESS = orm.g;
		METALLIC = orm.b;
	} else {
		ROUGHNESS = roughness;
		SPECULAR = specular;
		if (ao_enabled) {
			AO = texture(ao_texture, UV).r;
		}
	}
	if (normal_enabled) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
	}
	if (backlight_enabled) {
		BACKLIGHT = backlight.rgb;
	}
}
