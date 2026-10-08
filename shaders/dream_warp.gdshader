shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 focus_point = vec2(0.5, 0.45);
uniform float aspect = 1.777;

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_focus = uv - focus_point;
	vec2 radial_point = vec2(from_focus.x * aspect, from_focus.y);
	float radius = length(radial_point);
	float breath = sin(TIME * 2.5 - radius * 32.0 + sin(uv.y * 8.0) * 1.4);
	float rings = exp(-abs(breath) * 17.0) * exp(-radius * 2.7);
	float doubled_radius = length(radial_point + vec2(0.018, -0.006));
	float doubled_wave = sin(TIME * 2.1 - doubled_radius * 32.0 + sin(uv.y * 8.0) * 1.4);
	float double_rings = exp(-abs(doubled_wave) * 19.0) * exp(-doubled_radius * 2.7);
	float haze = exp(-radius * 7.0) * (0.45 + 0.25 * sin(TIME * 1.3));
	float static_grain = grain(uv / SCREEN_PIXEL_SIZE + vec2(TIME * 63.0));
	vec3 color = vec3(0.34, 0.56, 0.92) * rings + vec3(0.88, 0.34, 0.42) * double_rings;
	color += vec3(0.18, 0.24, 0.48) * haze;
	float alpha = intensity * (0.075 * rings + 0.055 * double_rings + 0.022 * haze);
	alpha += intensity * (static_grain - 0.5) * 0.012;
	COLOR = vec4(color, clamp(alpha, 0.0, 0.13));
}
