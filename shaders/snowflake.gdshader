shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform float alpha_scale = 0.55;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float soft = smoothstep(1.0, 0.15, d);
	ALBEDO = vec3(0.95, 0.97, 1.0);
	ALPHA = soft * alpha_scale;
}
