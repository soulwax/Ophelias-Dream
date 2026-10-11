shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float dream_weight : hint_range(0.0, 1.0) = 0.0;
uniform float spin : hint_range(0.0, 1.0) = 0.0;
uniform float dream_clock = 0.0;
uniform vec2 focus_point = vec2(0.5, 0.45);
uniform float aspect = 1.777;
uniform int cue = 0;

float film_grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - vec2(0.5);
	vec2 polar = vec2(centered.x * aspect, centered.y);
	float radius = length(polar);
	float angle = atan(polar.y, polar.x);

	// The dream begins with a slow, whole-world turn that loses momentum as
	// Mathilda comes into focus. A soft curl keeps the scene from ever settling
	// into perfectly ordinary camera footage.
	float spin_angle = spin * (dream_clock * 0.055 + sin(dream_clock * 0.36) * 0.055);
	float c = cos(spin_angle);
	float s = sin(spin_angle);
	vec2 turned = mat2(vec2(c, -s), vec2(s, c)) * polar;
	turned *= 1.0 - abs(spin_angle) * 0.12;
	vec2 dream_uv = vec2(turned.x / aspect, turned.y) + vec2(0.5);
	vec2 radial = polar / max(radius, 0.0001);
	float breathing_rings = sin(radius * 22.0 - dream_clock * 0.72 + sin(angle * 3.0 + dream_clock * 0.23) * 0.7);
	float curl = sin(angle * 2.0 + radius * 8.0 - dream_clock * 0.34);
	dream_uv += radial * (breathing_rings * 0.0022 + curl * 0.0013) * dream_weight;
	dream_uv += vec2(sin(uv.y * 10.0 + dream_clock * 0.42), sin(uv.x * 7.0 - dream_clock * 0.31)) * spin * 0.0018;
	dream_uv = clamp(dream_uv, vec2(0.001), vec2(0.999));

	float edge = smoothstep(0.28, 1.08, radius);
	vec2 split = radial * (0.0012 + radius * 0.0018) * dream_weight;
	vec3 scene;
	scene.r = texture(screen_texture, clamp(dream_uv + split, vec2(0.001), vec2(0.999))).r;
	scene.g = texture(screen_texture, dream_uv).g;
	scene.b = texture(screen_texture, clamp(dream_uv - split, vec2(0.001), vec2(0.999))).b;
	vec3 dream_tint = mix(vec3(0.055, 0.10, 0.20), vec3(0.18, 0.065, 0.22), clamp(uv.y + sin(angle * 2.0 + dream_clock * 0.12) * 0.18, 0.0, 1.0));
	scene = mix(scene, scene * vec3(0.88, 0.92, 1.08) + dream_tint * (0.32 + edge * 0.48), dream_weight * 0.44);
	float grain = film_grain(FRAGCOORD.xy + floor(dream_clock * 9.0));
	scene += (grain - 0.5) * 0.018 * dream_weight;

	// Memory cues still make a localized flash on top of the continuous dream
	// optics, with their existing color and cadence.
	vec2 from_focus = uv - focus_point;
	vec2 radial_point = vec2(from_focus.x * aspect, from_focus.y);
	float cue_radius = length(radial_point);
	float mask = exp(-cue_radius * 13.0) * (1.0 - smoothstep(0.19, 0.34, cue_radius));
	vec2 cue_direction = radial_point / max(cue_radius, 0.0001);
	float phase = dream_clock * 1.15;
	float rings = sin(cue_radius * 78.0 - phase + sin(atan(cue_direction.y, cue_direction.x) * 3.0) * 0.22);
	float echo = sin(cue_radius * 77.0 - phase - 0.72);
	float cue_scale = 1.0;
	if (cue == 1) {
		cue_scale = 0.48;
	} else if (cue == 2) {
		cue_scale = 0.32;
	} else if (cue == 4) {
		cue_scale = 0.68;
	} else if (cue == 5) {
		cue_scale = 1.35;
	}
	float burst = exp(-cue_radius * 11.0) * intensity;
	float displacement = rings * 0.0028 * intensity * cue_scale * mask;
	if (cue == 5) {
		displacement += burst * 0.0035 * mask;
	}
	vec2 cue_uv = clamp(dream_uv - cue_direction * displacement, vec2(0.001), vec2(0.999));
	vec3 cue_scene = texture(screen_texture, cue_uv).rgb;
	if (cue == 3 || cue == 5) {
		vec2 cue_split = cue_direction * (cue == 5 ? 0.0018 : 0.0009) * intensity * mask;
		cue_scene.r = mix(cue_scene.r, texture(screen_texture, clamp(cue_uv + cue_split, vec2(0.001), vec2(0.999))).r, cue == 5 ? 0.62 : 1.0);
		cue_scene.b = mix(cue_scene.b, texture(screen_texture, clamp(cue_uv - cue_split, vec2(0.001), vec2(0.999))).b, cue == 5 ? 0.62 : 1.0);
	}
	float interference = max(rings, 0.0) * 0.5 + max(echo, 0.0) * 0.5;
	vec3 cue_tint = cue == 5 ? vec3(0.65, 0.42, 0.18) : mix(vec3(0.16, 0.25, 0.48), vec3(0.42, 0.18, 0.33), clamp(float(cue) / 4.0, 0.0, 1.0));
	cue_scene += cue_tint * interference * intensity * mask * 0.055;
	if (cue == 5) {
		float glint_angle = atan(cue_direction.y, cue_direction.x);
		float glint = pow(max(sin(glint_angle * 5.0 + dream_clock * 2.4), 0.0), 20.0) * exp(-cue_radius * 7.0);
		cue_scene = mix(cue_scene, vec3(1.0, 0.86, 0.64), burst * 0.34);
		cue_scene += vec3(0.36, 0.5, 0.72) * glint * intensity * 0.28;
	}
	float cue_alpha = intensity * mask * (0.10 + interference * 0.07) * cue_scale;
	if (cue == 5) {
		cue_alpha = max(cue_alpha, burst * 0.42);
	}
	scene = mix(scene, cue_scene, clamp(cue_alpha, 0.0, 0.46));
	float dream_alpha = dream_weight * (0.48 + edge * 0.18);
	COLOR = vec4(scene, clamp(dream_alpha + cue_alpha, 0.0, 0.62));
}
