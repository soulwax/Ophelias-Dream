shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec4 shadow_color : source_color = vec4(0.018, 0.014, 0.032, 0.26);
uniform float edge_softness : hint_range(0.08, 0.8) = 0.34;

void fragment() {
	vec2 centered = abs(UV - vec2(0.5)) * 2.0;
	float shape = length(centered * vec2(0.82, 0.72));
	float feather = 1.0 - smoothstep(1.0 - edge_softness, 1.0, shape);
	ALBEDO = shadow_color.rgb;
	ALPHA = shadow_color.a * feather;
}
