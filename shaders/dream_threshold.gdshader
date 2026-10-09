shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.72, 0.62, 0.84, 1.0);

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float edge = max(abs(uv.x), abs(uv.y));
	float border = 1.0 - smoothstep(0.72, 1.0, edge);
	float slow_fold = sin(uv.y * 5.0 + TIME * 0.22 + sin(uv.x * 3.0 + TIME * 0.12));
	float fine_fold = sin(uv.x * 9.0 - uv.y * 4.0 - TIME * 0.16);
	float fold = smoothstep(-0.8, 0.85, slow_fold * 0.7 + fine_fold * 0.18);
	float pulse = 0.94 + 0.06 * sin(TIME * 0.31 + uv.y * 1.8);
	vec3 deep = vec3(0.012, 0.018, 0.031);
	vec3 reflected = tint.rgb * (0.035 + fold * 0.06 + border * 0.04);
	ALBEDO = deep + reflected;
	EMISSION = reflected * pulse;
	ALPHA = 0.99;
}
