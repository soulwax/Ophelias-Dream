shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform sampler2D snow_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform float uv_scale = 0.07;
uniform vec3 tint = vec3(0.55, 0.62, 0.72);
uniform vec3 shade = vec3(0.08, 0.1, 0.14);

void fragment() {
	vec2 uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz * uv_scale;
	vec3 tex = texture(snow_tex, uv).rgb;
	float broad = texture(snow_tex, uv * 0.23).r;
	ALBEDO = mix(shade, tex * tint, 0.82) * mix(0.86, 1.05, broad);
	ROUGHNESS = 0.97;
}
