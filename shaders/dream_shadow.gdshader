shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_disabled;

uniform vec3 shadow_tint : source_color = vec3(0.028, 0.022, 0.052);
uniform float opacity : hint_range(0.0, 0.95) = 0.76;

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - clamp(facing, 0.0, 1.0), 2.6);
	float breath = sin(TIME * 1.15 + UV.y * 8.0 + UV.x * 2.0) * 0.028;
	float veil = sin(TIME * 0.62 - UV.y * 5.2) * 0.022;
	ALBEDO = shadow_tint + vec3(0.018, 0.027, 0.075) * rim;
	ALPHA = clamp(opacity + rim * 0.15 + breath + veil, 0.0, 0.92);
	EMISSION = vec3(0.018, 0.026, 0.085) * (0.12 + rim) * opacity;
}
