shader_type spatial;
render_mode cull_disabled;
uniform sampler2D base_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 cloth_color : source_color;
uniform vec4 trim_color : source_color;
void fragment() {
	vec3 base = texture(base_texture, UV).rgb;
	float shade = dot(base, vec3(0.2126, 0.7152, 0.0722));
	bool cloth = base.g > base.r * 1.06 && base.g > base.b * 1.1;
	bool trim = base.r > base.g * 1.025 && base.g > base.b * 1.35 && base.r > 0.20;
	ALBEDO = cloth ? cloth_color.rgb * clamp(shade / 0.12, 0.1, 2.0) : (trim ? trim_color.rgb * clamp(shade / 0.45, 0.1, 1.8) : base);
	ROUGHNESS = 0.82;
}
