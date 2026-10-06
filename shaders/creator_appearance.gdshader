shader_type spatial;
render_mode cull_disabled;

uniform sampler2D base_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D region_mask : filter_linear, repeat_enable;
uniform vec4 hair_color : source_color = vec4(0.22, 0.09, 0.045, 1.0);
uniform vec4 eye_color : source_color = vec4(0.13, 0.45, 0.60, 1.0);

void fragment() {
	vec4 source = texture(base_texture, UV);
	vec2 masks = texture(region_mask, UV).rg;
	float shade = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 hair = hair_color.rgb * clamp(shade / 0.30, 0.12, 2.0);
	vec3 iris = eye_color.rgb * clamp(shade / 0.12, 0.12, 2.2);
	ALBEDO = mix(mix(source.rgb, hair, masks.r), iris, masks.g);
	ROUGHNESS = 0.78;
}
