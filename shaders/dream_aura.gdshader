shader_type canvas_item;

uniform vec4 aura_tint : source_color = vec4(0.14, 0.07, 0.28, 1.0);
uniform float intensity : hint_range(0.0, 0.3) = 0.14;

void fragment() {
	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	float radius = length(vec2(centered.x * 0.82, centered.y));
	float edge = smoothstep(0.55, 1.28, radius);
	float horizon = exp(-pow((SCREEN_UV.y - 0.68) / 0.22, 2.0));
	float breath = 0.94 + 0.06 * sin(TIME * 0.31);

	float flow_x = SCREEN_UV.x + sin(SCREEN_UV.y * 6.0 + TIME * 0.08) * 0.06;
	float veil = exp(-pow((SCREEN_UV.y - (0.28 + sin(flow_x * 4.0 + TIME * 0.06) * 0.07)) / 0.14, 2.0));
	float curtains = clamp(veil * (0.45 + 0.55 * sin(flow_x * 12.0 + TIME * 0.11)), 0.0, 1.0);
	vec3 tint = mix(aura_tint.rgb, vec3(0.20, 0.48, 0.78), clamp(curtains * 0.68 + horizon * 0.25, 0.0, 1.0));
	float alpha = intensity * clamp(edge * 0.42 + horizon * 0.06 + curtains * 0.08, 0.0, 0.45) * breath;
	COLOR = vec4(tint, alpha);
}
