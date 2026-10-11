shader_type canvas_item;

// Keep the optical treatment in place. Sampling and blending the scene in
// another full-screen pass left actor-sized copies after camera cuts.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float dream_weight : hint_range(0.0, 1.0) = 0.0;
uniform float dream_clock = 0.0;
uniform vec2 focus_point = vec2(0.5, 0.45);
uniform float aspect = 1.777;
uniform int cue = 0;

float film_grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = vec2((uv.x - 0.5) * aspect, uv.y - 0.5);
	float radius = length(centered);
	float angle = atan(centered.y, centered.x);
	float edge = smoothstep(0.34, 0.92, radius);
	float breath = 0.92 + 0.08 * sin(dream_clock * 0.42);
	float grain = film_grain(floor(FRAGCOORD.xy * 0.5) + floor(dream_clock * 7.0));
	vec3 color = mix(vec3(0.045, 0.12, 0.24), vec3(0.23, 0.065, 0.27),
		clamp(uv.y + sin(angle * 2.0 + dream_clock * 0.12) * 0.2, 0.0, 1.0));
	float base_alpha = dream_weight * (0.016 + edge * 0.06) * breath;
	base_alpha += (grain - 0.5) * dream_weight * 0.006;

	vec2 from_focus = vec2((uv.x - focus_point.x) * aspect, uv.y - focus_point.y);
	float distance_to_cue = length(from_focus);
	float mask = exp(-distance_to_cue * 8.5);
	float phase = distance_to_cue * 70.0 - dream_clock * 1.15;
	float ring = pow(max(sin(phase + sin(angle * 3.0) * 0.24), 0.0), 5.0);
	float echo = pow(max(sin(phase - 1.2), 0.0), 7.0);
	float cue_scale = 1.0;
	if (cue == 1) {
		cue_scale = 0.58;
	} else if (cue == 2) {
		cue_scale = 0.42;
	} else if (cue == 4) {
		cue_scale = 0.8;
	} else if (cue == 5) {
		cue_scale = 1.25;
	}
	vec3 cue_color = cue == 5 ? vec3(0.75, 0.45, 0.22) :
		mix(vec3(0.24, 0.34, 0.6), vec3(0.52, 0.22, 0.4), clamp(float(cue) / 4.0, 0.0, 1.0));
	float cue_alpha = intensity * cue_scale * mask * (0.035 + ring * 0.13 + echo * 0.045);
	if (cue == 5) {
		cue_alpha += intensity * exp(-distance_to_cue * 15.0) * 0.16;
	}
	color = mix(color, cue_color, clamp(cue_alpha * 4.0, 0.0, 1.0));
	COLOR = vec4(color, clamp(base_alpha + cue_alpha, 0.0, 0.35));
}
