shader_type canvas_item;

uniform vec4 aura_tint : source_color = vec4(0.12, 0.055, 0.24, 1.0);
uniform float intensity : hint_range(0.0, 0.3) = 0.18;

void fragment() {
	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	float radius = length(vec2(centered.x * 0.82, centered.y));
	float edge = smoothstep(0.35, 1.18, radius);
	float horizon = exp(-pow((SCREEN_UV.y - 0.64) / 0.25, 2.0));
	float breath = 0.94 + 0.06 * sin(TIME * 0.31);

	// Slow, offset aurora veils drift across the high sky. Their broken bands
	// and soft interference make the dream feel painted into the weather.
	float flow_x = SCREEN_UV.x + sin(SCREEN_UV.y * 7.0 + TIME * 0.12) * 0.07;
	float veil_a = exp(-pow((SCREEN_UV.y - (0.24 + sin(flow_x * 5.0 + TIME * 0.09) * 0.08)) / 0.12, 2.0));
	float veil_b = exp(-pow((SCREEN_UV.y - (0.38 + sin(flow_x * 3.0 - TIME * 0.07 + 1.8) * 0.10)) / 0.16, 2.0));
	float curtains = clamp(veil_a * (0.48 + 0.52 * sin(flow_x * 15.0 + TIME * 0.15)) + veil_b * 0.36, 0.0, 1.0);
	float orbit = 0.5 + 0.5 * sin(radius * 18.0 - TIME * 0.22 + sin(atan(centered.y, centered.x) * 3.0) * 0.8);
	float memory_ring = smoothstep(0.88, 0.98, orbit) * exp(-radius * 0.75);
	vec3 tint = mix(aura_tint.rgb, vec3(0.16, 0.42, 0.66), clamp(curtains * 0.72 + horizon * 0.22, 0.0, 1.0));
	float alpha = intensity * clamp(edge * 0.62 + horizon * 0.12 + curtains * 0.23 + memory_ring * 0.08, 0.0, 0.82) * breath;
	COLOR = vec4(tint, alpha);
}
