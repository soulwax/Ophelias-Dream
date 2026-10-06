shader_type spatial;
render_mode cull_disabled;
uniform vec4 cloth_color : source_color;
uniform vec4 accent_color : source_color;
uniform int design = 0;
varying vec3 rest_position;
void vertex() {
	rest_position = VERTEX;
}
void fragment() {
	float x = abs(rest_position.x);
	float height = rest_position.y;
	float panel = 0.0;
	if (design == 0) {
		panel = smoothstep(0.145, 0.158, x) * (1.0-smoothstep(1.67, 1.73, height));
	} else if (design == 1) {
		panel = (1.0-smoothstep(0.030, 0.044, x)) * smoothstep(1.38, 1.43, height) * (1.0-smoothstep(1.69, 1.74, height)) * smoothstep(0.03, 0.06, rest_position.z);
	} else {
		panel = smoothstep(0.108, 0.125, x) * smoothstep(1.30, 1.37, height) * (1.0-smoothstep(1.68, 1.73, height));
	}
	ALBEDO = mix(cloth_color.rgb, accent_color.rgb, panel);
	ROUGHNESS = design == 1 ? 0.58 : 0.84;
}
