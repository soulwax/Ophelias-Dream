shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_disabled, shadows_disabled;

uniform float fade = 1.0;

void fragment() {
	vec2 heel_uv = (UV - vec2(0.5, 0.78)) * vec2(3.4, 5.2);
	vec2 sole_uv = (UV - vec2(0.5, 0.42)) * vec2(2.15, 2.5);
	float heel = smoothstep(1.0, 0.35, length(heel_uv));
	float sole = smoothstep(1.0, 0.28, length(sole_uv));
	float arch = smoothstep(0.55, 0.0, abs(UV.y - 0.58)) * smoothstep(0.22, 0.05, abs(UV.x - 0.5));
	float mark = max(max(heel, sole * 0.85), 0.0) - arch * 0.35;
	mark = clamp(mark, 0.0, 1.0);
	float rim = smoothstep(0.15, 0.85, mark);
	ALBEDO = mix(vec3(0.45, 0.48, 0.52), vec3(0.16, 0.17, 0.2), rim);
	ALPHA = rim * fade * 0.82;
	ROUGHNESS = 1.0;
}
