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
		float trunk_bend = pow(height_ratio, 1.6) * trunk_sway * wind_strength;
		
		// Broad traveling wind wave
		float wave_phase = dot(world_pos.xz, w_dir * 0.06);
		float gust_wave = sin(TIME * wind_speed * 0.8 + wave_phase) * 0.7 + cos(TIME * wind_speed * 1.5 - wave_phase * 0.6) * 0.3;
		vec2 trunk_disp = w_dir * (gust_wave * trunk_bend);
		
		// Branch & needle flutter: mid-frequency oscillation
		float branch_phase = dot(world_pos, vec3(1.2, 0.8, 1.5)) + TIME * wind_speed * 2.4;
		float branch_act = clamp(height_ratio * 1.2, 0.1, 1.0);
		vec3 branch_disp = vec3(
			sin(branch_phase) * branch_sway * 0.6,
			cos(branch_phase * 1.3) * branch_sway * 0.3,
			sin(branch_phase * 0.8 + 1.1) * branch_sway * 0.6
		) * branch_act * wind_strength;
		
		// Leaf / needle card micro-flutter along normal
		float micro_phase = TIME * 6.5 + dot(world_pos.xz, vec2(3.7, 2.1));
		float micro_flutter = sin(micro_phase) * leaf_flutter * branch_act * wind_strength;
		
		VERTEX.xz += trunk_disp;
		VERTEX += branch_disp + NORMAL * micro_flutter;
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
