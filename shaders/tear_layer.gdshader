shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float menu_time = 0.0;
uniform float aspect = 1.7778;
uniform float light_level : hint_range(0.0, 1.0) = 0.45;

float cheek_path_x(float y) {
	float dy = y - 0.710;
	return 0.420 + 0.010 * sin(dy * 8.5) * dy + dy * 0.022;
}

float eye_path_x(float y) {
	float dy = clamp((y - 0.50) / 0.210, 0.0, 1.0);
	return 0.422 - 0.006 * sin(dy * 3.14159265);
}

// Computes tear height profile and surface normal in screen/UV space
void compute_tear(vec2 uv, out float out_h, out vec3 out_norm, out float out_wet, out float out_rim) {
	float total_h = 0.0;
	vec3 norm_acc = vec3(0.0, 0.0, 1.0);
	float wet_intensity = 0.0;
	float meniscus_rim = 0.0;

	if (uv.x >= 0.380 && uv.x <= 0.470 && uv.y >= 0.480 && uv.y <= 1.05) {
		// 1. Lower lid welling pool (starts ~14s, holds through entire sequence)
		float welling_time_weight = 0.0;
		if (menu_time >= 14.0) {
			float build = smoothstep(14.0, 20.0, menu_time);
			float sustain = 1.0 - smoothstep(62.0, 68.0, menu_time);
			welling_time_weight = build * sustain;
		}

		if (welling_time_weight > 0.001) {
			vec2 pool_center = vec2(0.421, 0.712);
			vec2 pool_d = vec2((uv.x - pool_center.x) * 1.7778, (uv.y - pool_center.y) * 2.4);
			float pool_dist = length(pool_d);
			float pool_r = 0.0145;
			if (pool_dist < pool_r) {
				float norm_d = pool_dist / pool_r;
				float h_pool = sqrt(max(0.0, 1.0 - norm_d * norm_d)) * 0.75 * welling_time_weight;
				if (h_pool > total_h) {
					total_h = h_pool;
					vec2 n_xy = pool_d / pool_r;
					norm_acc = normalize(vec3(n_xy, sqrt(max(0.04, 1.0 - norm_d * norm_d))));
					wet_intensity = max(wet_intensity, 0.85 * welling_time_weight);
					meniscus_rim = max(meniscus_rim, smoothstep(0.65, 0.98, norm_d) * welling_time_weight);
				}
			}
		}

		// 2. Eye droplet (rolling down eye from 30s to 46s)
		if (menu_time >= 29.5 && menu_time <= 48.0) {
			float t_eye = clamp((menu_time - 30.0) / 14.5, 0.0, 1.0);
			float eased_eye = smoothstep(0.0, 1.0, t_eye);
			float y_eye_head = mix(0.50, 0.715, eased_eye);
			float eye_fade = smoothstep(29.5, 30.5, menu_time) * (1.0 - smoothstep(45.5, 48.0, menu_time));

		if (uv.y >= 0.490 && uv.y <= y_eye_head + 0.015) {
				float x_center = eye_path_x(uv.y);
				float dx = (uv.x - x_center) * 1.7778;
				float dy = uv.y - y_eye_head;
				float bead_shape_y = dy < 0.0 ? dy * 1.35 : dy;
				vec2 bead_vec = vec2(dx, bead_shape_y);
				float bead_d = length(bead_vec);
				float r_eye_bead = 0.0110;

				if (bead_d < r_eye_bead && t_eye < 0.98) {
					float norm_d = bead_d / r_eye_bead;
					float h_eb = sqrt(max(0.0, 1.0 - norm_d * norm_d)) * 1.05 * eye_fade;
					if (h_eb > total_h) {
						total_h = h_eb;
						vec2 n_xy = bead_vec / r_eye_bead;
						norm_acc = normalize(vec3(n_xy, sqrt(max(0.04, 1.0 - norm_d * norm_d))));
						wet_intensity = max(wet_intensity, 1.0 * eye_fade);
						meniscus_rim = max(meniscus_rim, smoothstep(0.70, 0.98, norm_d) * eye_fade);
					}
				}

				float r_eye_trail = 0.0042;
				if (abs(dx) < r_eye_trail && uv.y < y_eye_head) {
					float norm_dx = abs(dx) / r_eye_trail;
					float h_et = sqrt(max(0.0, 1.0 - norm_dx * norm_dx)) * 0.48 * eye_fade;
					if (h_et > total_h) {
						total_h = h_et;
						vec2 n_xy = vec2(dx / r_eye_trail, 0.0);
						norm_acc = normalize(vec3(n_xy, sqrt(max(0.04, 1.0 - norm_dx * norm_dx))));
						wet_intensity = max(wet_intensity, 0.75 * eye_fade);
						meniscus_rim = max(meniscus_rim, smoothstep(0.65, 0.98, norm_dx) * 0.6 * eye_fade);
					}
				}
			}
		}

		// 3. Cheek tear stream (flowing from 20s to 60s)
		if (menu_time >= 19.8) {
			float t_cheek = clamp((menu_time - 20.0) / 40.0, 0.0, 1.0);
			float eased_cheek = pow(t_cheek, 1.12);
			float y_cheek_head = mix(0.710, 1.035, eased_cheek);
			float cheek_active = smoothstep(19.8, 20.3, menu_time) * (1.0 - smoothstep(62.0, 68.0, menu_time));
			float trail_sustain = 1.0 - smoothstep(60.0, 68.0, menu_time);

			if (uv.y >= 0.708 && uv.y <= y_cheek_head + 0.018) {
				float x_center = cheek_path_x(uv.y);
				float dx = (uv.x - x_center) * 1.7778;
				float dy = uv.y - y_cheek_head;
				float bead_shape_y = dy < 0.0 ? dy * 1.25 : dy;
				vec2 bead_vec = vec2(dx, bead_shape_y);
				float bead_d = length(bead_vec);
				float r_cheek_bead = 0.0135 * mix(0.85, 1.25, clamp(t_cheek * 2.5, 0.0, 1.0));

				if (bead_d < r_cheek_bead && t_cheek < 0.99) {
					float norm_d = bead_d / r_cheek_bead;
					float h_cb = sqrt(max(0.0, 1.0 - norm_d * norm_d)) * 1.15 * cheek_active;
					if (h_cb > total_h) {
						total_h = h_cb;
						vec2 n_xy = bead_vec / r_cheek_bead;
						norm_acc = normalize(vec3(n_xy, sqrt(max(0.04, 1.0 - norm_d * norm_d))));
						wet_intensity = max(wet_intensity, 1.0 * cheek_active);
						meniscus_rim = max(meniscus_rim, smoothstep(0.70, 0.98, norm_d) * cheek_active);
					}
				}

				float r_cheek_trail = 0.0048;
				if (abs(dx) < r_cheek_trail && uv.y < y_cheek_head) {
					float norm_dx = abs(dx) / r_cheek_trail;
					float h_ct = sqrt(max(0.0, 1.0 - norm_dx * norm_dx)) * 0.55 * cheek_active * trail_sustain;
					if (h_ct > total_h) {
						total_h = h_ct;
						vec2 n_xy = vec2(dx / r_cheek_trail, 0.0);
						norm_acc = normalize(vec3(n_xy, sqrt(max(0.04, 1.0 - norm_dx * norm_dx))));
						wet_intensity = max(wet_intensity, 0.88 * cheek_active * trail_sustain);
						meniscus_rim = max(meniscus_rim, smoothstep(0.65, 0.98, norm_dx) * 0.7 * cheek_active * trail_sustain);
					}
				}
			}
		}
	}

	out_h = total_h;
	out_norm = norm_acc;
	out_wet = wet_intensity;
	out_rim = meniscus_rim;
}

void fragment() {
	vec2 portrait_scale = vec2(min(aspect / 1.7778, 1.0), min(1.7778 / aspect, 1.0));
	vec2 uv = (UV - 0.5) * portrait_scale + 0.5;

	float total_h = 0.0;
	vec3 total_norm = vec3(0.0, 0.0, 1.0);
	float wet_intensity = 0.0;
	float meniscus_rim = 0.0;

	compute_tear(uv, total_h, total_norm, wet_intensity, meniscus_rim);

	if (total_h > 0.002) {
		// Optical refraction: water bends light downward and towards center of drop
		vec2 screen_disp = (total_norm.xy * total_h * 0.035) / portrait_scale;
		vec3 base_color = texture(screen, SCREEN_UV + screen_disp).rgb;

		// Wet skin / sclera darkening: water fills microscopic surface roughness
		vec3 wet_color = mix(base_color, base_color * vec3(0.48, 0.42, 0.40), wet_intensity * 0.70);

		// Key light direction: warm cabin lantern located up and right (-y in UV is upward)
		vec3 light_dir = normalize(vec3(0.35, -0.45, 0.70));
		vec3 view_dir = vec3(0.0, 0.0, 1.0);
		vec3 half_vec = normalize(light_dir + view_dir);

		float n_dot_h = max(dot(total_norm, half_vec), 0.0);

		// Cool ambient fill from left winter window
		vec3 sky_dir = normalize(vec3(-0.45, -0.25, 0.75));
		vec3 half_sky = normalize(sky_dir + view_dir);
		float n_dot_sky = max(dot(total_norm, half_sky), 0.0);

		// Highlights:
		// 1. Lantern specular glint: broad lustrous lobe + tight glint
		float spec_broad = pow(n_dot_h, 6.0) * 0.95;
		float spec_tight = pow(n_dot_h, 28.0) * 2.80;
		vec3 lantern_specular = vec3(1.0, 0.95, 0.88) * (spec_broad + spec_tight);

		// 2. Soft winter sky sheen
		vec3 sky_specular = vec3(0.72, 0.85, 1.00) * pow(n_dot_sky, 5.0) * 0.75;

		// 3. Fresnel edge reflectance (water-air boundary)
		float fresnel = pow(1.0 - max(dot(total_norm, view_dir), 0.0), 2.0);
		vec3 rim_glow = vec3(0.92, 0.96, 1.00) * fresnel * 0.90;

		// 4. Meniscus contact edge glint (high surface tension curvature where tear meets skin)
		vec3 meniscus_highlight = vec3(1.0, 0.98, 0.94) * meniscus_rim * 0.95;

		// 5. Caustic internal focus at bottom edge of tear bead (+y is down)
		float bottom_caustic = max(0.0, total_norm.y) * total_h * 0.70;
		vec3 caustic_color = vec3(1.0, 0.88, 0.72) * bottom_caustic * 1.60;

		vec3 water_tint = vec3(0.94, 0.97, 1.00);
		vec3 total_highlight = (lantern_specular + sky_specular + rim_glow + meniscus_highlight + caustic_color) * mix(0.75, 1.25, light_level);

		// Water body translucency and surface brilliance
		vec3 final_color = wet_color * water_tint + total_highlight;
		float alpha_blend = clamp(total_h * 2.5 + meniscus_rim * 0.6, 0.0, 1.0);

		COLOR = vec4(mix(base_color, final_color, alpha_blend), 1.0);
	} else {
		discard;
	}
}
