shader_type spatial;
render_mode blend_add, depth_draw_never, unshaded;

uniform vec4 mood_color : source_color = vec4(0.71, 0.55, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 0.7;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;
uniform float reveal : hint_range(0.0, 1.0) = 1.0;

varying vec3 shell_position;

void vertex() {
	shell_position = VERTEX;
	VERTEX += NORMAL * 0.055;
}

void fragment() {
	vec3 normal = normalize(NORMAL);
	vec3 view_direction = normalize(VIEW);
	float rim = pow(1.0 - abs(dot(normal, view_direction)), 3.5);
	float angle = atan(shell_position.z, shell_position.x);
	float current_phase = shell_position.y * 7.5 - time * (1.4 + pulse * 1.8)
		+ sin(angle * 3.0 + time * 0.8) * 0.8;
	float ribbons = pow(max(sin(current_phase), 0.0), 5.0);
	float drifting_threads = pow(max(sin(angle * 5.0 - time * 0.55 + shell_position.y * 3.0), 0.0), 7.0);
	float height_fade = smoothstep(-1.12, -0.48, shell_position.y)
		* (1.0 - smoothstep(1.18, 1.72, shell_position.y));
	float shimmer = 0.82 + 0.18 * sin(time * 4.2 + angle * 4.0 + shell_position.y * 8.0);
	float wisps = (ribbons * 0.15 + drifting_threads * 0.09) * height_fade;
	float aura_alpha = (rim * 0.12 + wisps * 0.5) * intensity * shimmer * reveal;
	vec3 aura = mood_color.rgb * (0.65 + pulse * 0.5 + wisps * 0.4);
	ALBEDO = aura;
	EMISSION = aura;
	ALPHA = clamp(aura_alpha, 0.0, 0.08);
}
