shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 mood_color : source_color = vec4(0.76, 0.62, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 0.85;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;
uniform float reveal : hint_range(0.0, 1.0) = 1.0;

varying vec3 shell_position;

float hash_aura(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	shell_position = VERTEX;
	float wave = sin(VERTEX.y * 5.0 - time * 1.6 + atan(VERTEX.z, VERTEX.x) * 2.0) * 0.018;
	VERTEX += NORMAL * (0.048 + wave);
}

void fragment() {
	vec3 normal = normalize(NORMAL);
	vec3 view_direction = normalize(VIEW);
	float facing = clamp(abs(dot(normal, view_direction)), 0.0, 1.0);
	// Fade to zero at the sphere silhouette so the helper mesh never forms a visible bubble/egg.
	float interior_mask = smoothstep(0.18, 0.72, facing) * (1.0 - smoothstep(0.78, 0.99, facing));
	float angle = atan(shell_position.z, shell_position.x);

	// Orbiting galactic spiral ribbons around her starchild corona.
	float spiral_a = shell_position.y * 6.2 - time * (1.25 + pulse * 1.6) + angle * 2.0;
	float spiral_b = shell_position.y * 4.4 + time * 0.82 - angle * 3.0;
	float ribbons = pow(max(sin(spiral_a), 0.0), 5.0);
	float counter_threads = pow(max(sin(spiral_b), 0.0), 7.0);

	// Orbiting micro-stars embedded in the aura field.
	vec2 star_uv = vec2((angle / 6.2831853 + 0.5) * 28.0 + time * 0.35, (shell_position.y + 1.0) * 18.0 - time * 0.22);
	vec2 star_cell = floor(star_uv);
	vec2 star_f = fract(star_uv) - 0.5;
	float rnd = hash_aura(star_cell);
	float star_d = length(star_f - (vec2(rnd, fract(rnd * 17.3)) - 0.5) * 0.5);
	float star_spark = smoothstep(0.10, 0.0, star_d) * step(0.74, rnd) * (0.6 + 0.4 * sin(time * 4.5 + rnd * 25.0));

	float height_fade = smoothstep(-0.85, -0.25, shell_position.y)
		* (1.0 - smoothstep(0.65, 1.02, shell_position.y));
	float shimmer = 0.84 + 0.16 * sin(time * 3.6 + angle * 3.0 + shell_position.y * 7.0);
	float wisps = (ribbons * 0.22 + counter_threads * 0.14 + star_spark * 0.65) * height_fade * interior_mask;

	vec3 cyan_shift = vec3(0.42, 0.88, 1.0);
	vec3 gold_shift = vec3(1.0, 0.88, 0.62);
	vec3 palette = mix(mood_color.rgb, cyan_shift, ribbons * 0.48);
	palette = mix(palette, gold_shift, star_spark * 0.75);

	float aura_alpha = wisps * intensity * shimmer * reveal;
	vec3 aura = palette * (0.85 + pulse * 0.65 + wisps * 0.85);
	ALBEDO = vec3(0.0);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = aura * 1.15;
	ALPHA = clamp(aura_alpha, 0.0, 0.16);
}
