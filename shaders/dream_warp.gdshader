shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 focus_point = vec2(0.5, 0.45);
uniform float aspect = 1.777;
uniform int cue = 0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_focus = uv - focus_point;
	vec2 radial_point = vec2(from_focus.x * aspect, from_focus.y);
	float radius = length(radial_point);
	if (radius > 0.34 || intensity <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		float mask = exp(-radius * 13.0) * (1.0 - smoothstep(0.19, 0.34, radius));
		vec2 direction = radial_point / max(radius, 0.0001);
		float phase = TIME * 1.15;
		float rings = sin(radius * 78.0 - phase + sin(atan(direction.y, direction.x) * 3.0) * 0.22);
		float echo = sin(radius * 77.0 - phase - 0.72);
		float cue_scale = 1.0;
		if (cue == 1) {
			cue_scale = 0.48;
		} else if (cue == 2) {
			cue_scale = 0.32;
		} else if (cue == 3) {
			cue_scale = 1.0;
		} else if (cue == 4) {
			cue_scale = 0.68;
		}
		float displacement = rings * 0.0028 * intensity * cue_scale * mask;
		vec2 warped_uv = clamp(uv - direction * displacement, vec2(0.001), vec2(0.999));
		float interference = max(rings, 0.0) * 0.5 + max(echo, 0.0) * 0.5;
		vec3 scene = texture(screen_texture, warped_uv).rgb;
		if (cue == 3) {
			vec2 split = direction * 0.0009 * intensity * mask;
			scene.r = texture(screen_texture, clamp(warped_uv + split, vec2(0.001), vec2(0.999))).r;
			scene.b = texture(screen_texture, clamp(warped_uv - split, vec2(0.001), vec2(0.999))).b;
		}
		vec3 tint = mix(vec3(0.16, 0.25, 0.48), vec3(0.42, 0.18, 0.33), clamp(float(cue) / 4.0, 0.0, 1.0));
		scene += tint * interference * intensity * mask * 0.055;
		float alpha = intensity * mask * (0.10 + interference * 0.07) * cue_scale;
		COLOR = vec4(scene, clamp(alpha, 0.0, 0.12));
	}
}
