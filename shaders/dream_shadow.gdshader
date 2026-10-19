shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Vivid Starchild shader for Dream Mathilda.
// Uses spatial 3D shading (wrapped diffuse, subsurface cosmic scattering, and
// iridescent specular highlights) combined with multi-layer 3D interior parallax
// rendering realistic spinning spiral galaxies, dark dust lanes, H-II nebulae,
// and crisp starfields within her form.

uniform vec3 shadow_tint : source_color = vec3(0.001, 0.001, 0.004);
uniform vec3 aura_tint : source_color = vec3(0.58, 0.36, 0.96);
uniform float opacity : hint_range(0.0, 0.99) = 0.97;
uniform float dissolve : hint_range(0.0, 0.4) = 0.0;
uniform float lantern_warmth : hint_range(0.0, 1.0) = 0.0;
uniform float galaxy_spin_speed : hint_range(0.05, 2.0) = 0.52;
uniform float star_vividness : hint_range(0.5, 3.0) = 1.65;

varying vec3 local_pos;
varying vec3 local_normal;
varying vec3 world_pos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 hash33(vec3 p3) {
	p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yxx) * p3.zyx);
}

float soft_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = fract(p);
	blend = blend * blend * (3.0 - 2.0 * blend);
	float lower = mix(hash12(cell), hash12(cell + vec2(1.0, 0.0)), blend.x);
	float upper = mix(hash12(cell + vec2(0.0, 1.0)), hash12(cell + vec2(1.0, 1.0)), blend.x);
	return mix(lower, upper, blend.y);
}

float noise3d(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash12(i.xy + i.z * vec2(17.0, 31.0));
	float n100 = hash12(i.xy + vec2(1.0, 0.0) + i.z * vec2(17.0, 31.0));
	float n010 = hash12(i.xy + vec2(0.0, 1.0) + i.z * vec2(17.0, 31.0));
	float n110 = hash12(i.xy + vec2(1.0, 1.0) + i.z * vec2(17.0, 31.0));
	float n001 = hash12(i.xy + (i.z + 1.0) * vec2(17.0, 31.0));
	float n101 = hash12(i.xy + vec2(1.0, 0.0) + (i.z + 1.0) * vec2(17.0, 31.0));
	float n011 = hash12(i.xy + vec2(0.0, 1.0) + (i.z + 1.0) * vec2(17.0, 31.0));
	float n111 = hash12(i.xy + vec2(1.0, 1.0) + (i.z + 1.0) * vec2(17.0, 31.0));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	return mix(mix(nx00, nx10, f.y), mix(nx01, nx11, f.y), f.z);
}

float fbm2(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 4; i++) {
		v += a * soft_noise(p);
		p = rot * p * 2.03 + vec2(13.7, 29.1);
		a *= 0.5;
	}
	return v;
}

float fbm3(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise3d(p);
		p = p * 2.02 + vec3(7.3, 19.1, 11.7);
		a *= 0.5;
	}
	return v;
}

// Evaluates a realistic 3D spiral galaxy centered at `center` with basis rows `ax`, `ay`, `az`.
// Returns rgb emission and alpha density in w.
vec4 eval_spiral_galaxy(
	vec3 sample_p,
	vec3 center,
	vec3 ax,
	vec3 ay,
	vec3 az,
	float radius,
	float spin,
	float wind_tightness,
	vec3 core_col,
	vec3 arm_col,
	vec3 hii_col,
	bool barred
) {
	vec3 rel = (sample_p - center) / max(radius, 0.001);
	vec2 disk = vec2(dot(rel, ax), dot(rel, ay));
	float z_off = dot(rel, az);
	float r = length(disk);
	if (r > 1.45 || abs(z_off) > 1.85) {
		return vec4(0.0);
	}

	// Vertical disk thickness profile spanning her torso depth with smooth radial edge fade.
	float scale_h = mix(0.95, 0.45, smoothstep(0.0, 0.85, r));
	float z_profile = exp(-abs(z_off) / scale_h) * (1.0 - smoothstep(0.95, 1.42, r));

	// Differential rotation: inner regions rotate faster than outer disk, plus steady global spin.
	float theta = atan(disk.y, disk.x) - spin;
	float log_r = log(max(r, 0.018));

	// Turbulence for flocculent spiral spurs and dust knots.
	vec2 rot_uv = vec2(
		disk.x * cos(spin * 0.6) - disk.y * sin(spin * 0.6),
		disk.x * sin(spin * 0.6) + disk.y * cos(spin * 0.6)
	);
	float turb = fbm2(rot_uv * 6.5 + vec2(4.2, -3.1));
	float fine_turb = fbm2(rot_uv * 16.0 - vec2(spin * 0.4, 1.7));

	// Two primary logarithmic spiral arms + four secondary spurs.
	float arm_phase = 2.0 * theta - wind_tightness * log_r + (turb - 0.5) * 1.65;
	float main_arms = pow(0.5 + 0.5 * cos(arm_phase), 2.6);
	float spur_phase = 4.0 * theta - (wind_tightness * 1.35) * log_r + (fine_turb - 0.5) * 2.2;
	float spurs = pow(0.5 + 0.5 * cos(spur_phase), 4.2) * 0.6;

	// Dark interstellar dust lanes hugging the inner concave edge of the spiral arms.
	float dust_phase = arm_phase + 0.58;
	float dust_lane = pow(0.5 + 0.5 * cos(dust_phase), 5.5) * smoothstep(0.07, 0.32, r) * (1.0 - smoothstep(0.75, 1.2, r));
	float dust_absorption = clamp(dust_lane * (0.48 + 0.85 * fine_turb), 0.0, 0.82);

	// Radial disk envelope and central galactic bulge / bar.
	float disk_env = smoothstep(0.02, 0.14, r) * exp(-r * 2.35);
	float bulge = exp(-r * r * 20.0) + 0.62 / (1.0 + r * r * 85.0);
	float bar = 0.0;
	if (barred) {
		vec2 bar_p = vec2(
			disk.x * cos(spin) + disk.y * sin(spin),
			-disk.x * sin(spin) + disk.y * cos(spin)
		);
		bar = exp(-(bar_p.x * bar_p.x * 8.5 + bar_p.y * bar_p.y * 52.0)) * 0.95;
	}

	// H-II star-forming knots sparkling along the spiral ridges.
	float hii_knots = smoothstep(0.58, 0.86, fine_turb) * main_arms * disk_env * 2.8;
	float star_associations = pow(max(fine_turb * main_arms, 0.0), 3.0) * disk_env * 3.4;

	vec3 col = vec3(0.0);
	// Warm golden-white galactic core & bar.
	col += core_col * (bulge * 2.1 + bar * 1.35);
	// Sweeping spiral arms with young blue-white and cyan giants.
	col += arm_col * (main_arms + spurs + 0.18) * disk_env * 2.25;
	// Vivid H-alpha magenta/rose star-forming nebulae and crisp blue-white star clusters.
	col += hii_col * hii_knots * 1.75;
	col += vec3(0.88, 0.96, 1.0) * star_associations;

	// Attenuate by dark dust lanes for authentic photographic depth.
	col *= mix(1.0, 0.18, dust_absorption);
	col *= z_profile;

	float density = clamp((bulge * 0.95 + (main_arms + spurs) * disk_env * 0.9) * z_profile, 0.0, 1.0);
	return vec4(col, density);
}

// 3D volumetric starfield with stellar blackbody color temperatures.
vec3 starfield_3d(vec3 p, float time) {
	vec3 cell = floor(p);
	vec3 local = fract(p) - 0.5;
	vec3 rnd = hash33(cell);
	vec3 star_pos = (rnd - 0.5) * 0.72;
	float d = length(local - star_pos);
	float twinkle = 0.72 + 0.28 * sin(time * (2.2 + rnd.x * 5.0) + rnd.y * 19.0);
	float size = mix(0.028, 0.105, pow(rnd.z, 2.8));
	float core = smoothstep(size, 0.0, d);
	float halo = exp(-d * d / max(size * size * 2.4, 0.0002)) * 0.65;
	// Stellar temperature palette: O/B blue-white, A white, G gold, K/M rose-amber.
	vec3 star_col = mix(
		mix(vec3(0.52, 0.78, 1.0), vec3(1.0, 0.98, 0.94), smoothstep(0.0, 0.45, rnd.x)),
		mix(vec3(1.0, 0.84, 0.52), vec3(1.0, 0.48, 0.70), smoothstep(0.45, 1.0, rnd.x)),
		step(0.45, rnd.x)
	);
	float bright = step(0.28, rnd.z) * (core * 2.5 + halo) * twinkle;
	return star_col * bright;
}

void vertex() {
	// Keep skinned vertices intact without normal displacement so flat-shaded low-poly triangles stay seamless.
	local_pos = VERTEX;
	local_normal = NORMAL;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float facing = clamp(abs(dot(n, v)), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.45);
	float fine_rim = pow(1.0 - facing, 5.2);

	// True meter-scale world position of the skinned fragment relative to Dream Mathilda's feet origin.
	vec3 frag_world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 char_origin = MODEL_MATRIX[3].xyz;
	vec3 char_pos = frag_world - char_origin;

	// Camera-aligned basis vectors so the 3D tilted galaxies inside her silhouette are always
	// seen at rich 3D inclinations regardless of whether Ophelia views her from behind or front.
	vec3 world_view = normalize(frag_world - INV_VIEW_MATRIX[3].xyz);
	vec3 cam_right = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 world_up = vec3(0.0, 1.0, 0.0);
	vec3 cam_fwd = normalize(cross(cam_right, world_up));
	vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);

	// Dissolve / apparition noise for departures and arrivals.
	float noise = soft_noise(char_pos.xy * vec2(18.0, 22.0) + vec2(TIME * 0.2, -TIME * 0.12));
	float cutoff = dissolve * 3.0;
	float intact = dissolve <= 0.001 ? 1.0 : 1.0 - smoothstep(cutoff - 0.035, cutoff + 0.035, noise);
	float dissolve_edge = smoothstep(cutoff - 0.055, cutoff - 0.018, noise) * (1.0 - smoothstep(cutoff + 0.018, cutoff + 0.055, noise));

	float spin_t = TIME * galaxy_spin_speed;

	// Multi-layer 3D interior raymarching inside her silhouette in meter space.
	vec3 interior_cosmos = vec3(0.0);
	float galaxy_luma = 0.0;

	// Tilted 3D galaxy coordinate frames anchored inside her body:
	// 1. Heart / Chest Grand Design Spiral Galaxy (inclined 24 deg).
	vec3 g1_ax = normalize(cam_right * 0.94 + world_up * 0.24 - cam_fwd * 0.22);
	vec3 g1_az = normalize(-cam_right * 0.18 + world_up * 0.36 + cam_fwd * 0.91);
	vec3 g1_ay = normalize(cross(g1_az, g1_ax));

	// 2. Solar Plexus / Abdomen Counter-Spinning Barred Spiral Galaxy (inclined -32 deg).
	vec3 g2_ax = normalize(cam_right * 0.89 - world_up * 0.36 + cam_fwd * 0.26);
	vec3 g2_az = normalize(cam_right * 0.28 + world_up * 0.42 + cam_fwd * 0.86);
	vec3 g2_ay = normalize(cross(g2_az, g2_ax));

	// 3. Crown / Head Astral Whirlpool Galaxy.
	vec3 g3_ax = normalize(cam_right * 0.95 + world_up * 0.16 + cam_fwd * 0.26);
	vec3 g3_az = normalize(-cam_right * 0.24 + world_up * 0.38 + cam_fwd * 0.89);
	vec3 g3_ay = normalize(cross(g3_az, g3_ax));

	// 4. Lower Dress / Skirt Deep-Space Spiral Galaxy.
	vec3 g4_ax = normalize(cam_right * 0.88 + world_up * 0.34 - cam_fwd * 0.32);
	vec3 g4_az = normalize(-cam_right * 0.26 + world_up * 0.44 + cam_fwd * 0.86);
	vec3 g4_ay = normalize(cross(g4_az, g4_ax));

	for (int layer = 0; layer < 3; layer++) {
		float lf = float(layer);
		float depth = 0.02 + lf * 0.055;
		float weight = (layer == 0) ? 0.48 : ((layer == 1) ? 0.34 : 0.18);
		// Step deeper into her 3D volume along the view ray for authentic interior parallax.
		vec3 p = char_pos + world_view * depth - world_n * (0.015 + lf * 0.015);

		// Evaluate the 4 anatomical hero galaxies (in meters above her feet):
		vec4 gal_heart = eval_spiral_galaxy(
			p, vec3(0.0, 1.22, 0.0), g1_ax, g1_ay, g1_az,
			0.22, spin_t * 1.15 + lf * 0.18, 4.3,
			vec3(1.0, 0.92, 0.68), vec3(0.32, 0.78, 1.0), vec3(1.0, 0.32, 0.68), false
		);
		vec4 gal_plexus = eval_spiral_galaxy(
			p, vec3(-0.02, 0.88, 0.0), g2_ax, g2_ay, g2_az,
			0.20, -spin_t * 0.92 - lf * 0.15, 3.8,
			vec3(1.0, 0.80, 0.90), vec3(0.28, 0.90, 0.94), vec3(0.78, 0.40, 1.0), true
		);
		vec4 gal_crown = eval_spiral_galaxy(
			p, vec3(0.0, 1.54, 0.0), g3_ax, g3_ay, g3_az,
			0.15, spin_t * 1.38, 4.6,
			vec3(0.96, 0.97, 1.0), vec3(0.52, 0.72, 1.0), vec3(1.0, 0.52, 0.84), false
		);
		vec4 gal_skirt = eval_spiral_galaxy(
			p, vec3(0.01, 0.48, 0.0), g4_ax, g4_ay, g4_az,
			0.25, spin_t * 0.78, 4.1,
			vec3(1.0, 0.86, 0.58), vec3(0.40, 0.66, 1.0), vec3(0.96, 0.36, 0.66), true
		);

		// Secondary cellular mini-galaxies spinning throughout her arms, shoulders, and legs.
		vec3 cell_uvw = p * 6.4 + vec3(0.0, 0.0, lf * 1.7);
		vec3 cell_id = floor(cell_uvw);
		vec3 cell_f = fract(cell_uvw) - 0.5;
		vec3 cell_rnd = hash33(cell_id);
		float mini_spin = spin_t * (1.2 + cell_rnd.x * 1.4) * (cell_rnd.y > 0.5 ? 1.0 : -1.0);
		vec2 mini_disk = vec2(
			dot(cell_f, g1_ax),
			dot(cell_f, g1_ay)
		);
		float mr = length(mini_disk) * 2.6;
		float mtheta = atan(mini_disk.y, mini_disk.x) - mini_spin;
		float marm = pow(0.5 + 0.5 * cos(2.0 * mtheta - 4.2 * log(max(mr, 0.02))), 3.0);
		float mcore = exp(-mr * mr * 15.0);
		float m_env = exp(-mr * 2.6) * step(0.32, cell_rnd.x);
		vec3 mini_gal = mix(vec3(0.36, 0.80, 1.0), vec3(1.0, 0.50, 0.82), cell_rnd.y) * (mcore * 1.45 + marm * 1.05) * m_env * 0.78;

		// Swirling cosmic nebula clouds inside her silhouette.
		vec3 neb_p = p * 4.2 + vec3(sin(spin_t * 0.25) * 0.35, -spin_t * 0.16, cos(spin_t * 0.22) * 0.35);
		float neb_a = fbm3(neb_p);
		float neb_b = fbm3(neb_p * 1.9 + vec3(5.2, -3.7, 8.1));
		float neb_ridge = smoothstep(0.38, 0.80, neb_a) * (0.4 + 0.6 * neb_b);
		vec3 nebula_col = mix(
			mix(vec3(0.10, 0.04, 0.28), aura_tint * 0.85, neb_a),
			mix(vec3(0.16, 0.74, 0.98), vec3(1.0, 0.38, 0.72), neb_b),
			smoothstep(0.35, 0.78, neb_b)
		) * neb_ridge * 0.75;

		// Crisp multi-scale 3D stars at this parallax depth.
		vec3 stars_near = starfield_3d(p * (24.0 + lf * 9.0) + vec3(0.0, spin_t * 0.10, 0.0), TIME);
		vec3 stars_fine = starfield_3d(p * (52.0 + lf * 16.0) - vec3(spin_t * 0.07, 0.0, 0.0), TIME * 1.3) * 0.72;

		vec3 galactic_clouds = gal_heart.rgb + gal_plexus.rgb + gal_crown.rgb + gal_skirt.rgb
			+ mini_gal;

		// Keep clouds submerged in the void; sparse stars remain crisp points of contrast.
		interior_cosmos += (galactic_clouds * 0.12 + nebula_col * 0.06
			+ (stars_near + stars_fine) * star_vividness * 0.78) * weight;
		galaxy_luma += (gal_heart.w + gal_plexus.w + gal_crown.w + gal_skirt.w) * weight;
	}

	// Perturb the surface normal slightly with cosmic currents so 3D lighting catches subtle astral ripples.
	float ripple_u = soft_noise(char_pos.xy * 14.0 + vec2(TIME * 0.35, 0.0));
	float ripple_v = soft_noise(char_pos.zy * 14.0 - vec2(0.0, TIME * 0.35));
	NORMAL = normalize(n + vec3(ripple_u - 0.5, 0.0, ripple_v - 0.5) * 0.10);

	// Starchild pearlescent rim & lantern warmth response.
	vec3 iridescent_rim = mix(
		mix(aura_tint, vec3(0.38, 0.88, 1.0), 0.5 + 0.5 * sin(char_pos.y * 4.5 - TIME * 0.9)),
		vec3(1.0, 0.90, 0.66),
		clamp(fine_rim * 0.65 + lantern_warmth * 0.55, 0.0, 1.0)
	);

	// Deep cosmic midnight albedo in the interior window so the spinning galaxies stay high-contrast,
	// with shaded pearlescent starlight on grazing 3D contours.
	vec3 base_albedo = mix(shadow_tint * 0.04, iridescent_rim * 0.10, rim * 0.52);
	base_albedo += vec3(0.22, 0.12, 0.04) * lantern_warmth * rim;

	ALBEDO = base_albedo;
	ROUGHNESS = mix(0.42, 0.24, rim);
	METALLIC = mix(0.02, 0.12, rim);
	SPECULAR = 0.28;

	// Interior galaxies shine vividly through her dark cosmic core, framed by the shaded starchild rim.
	float interior_window = mix(0.78, 0.42, rim);
vec3 emission = vec3(0.001, 0.001, 0.004) + interior_cosmos * interior_window;
emission += iridescent_rim * (rim * 0.24 + fine_rim * 0.72) * opacity;
	emission += vec3(1.0, 0.68, 0.32) * rim * lantern_warmth * 0.55;
	emission += aura_tint * 2.2 * dissolve_edge * step(0.001, dissolve);

	EMISSION = emission;
ALPHA = clamp(opacity + 0.015 + rim * 0.025 + clamp(galaxy_luma, 0.0, 0.08), 0.0, 0.99) * intact;
}

void light() {
	vec3 n = normalize(NORMAL);
	vec3 l = normalize(LIGHT);
	vec3 v = normalize(VIEW);
	vec3 h = normalize(l + v);

	// Wrapped celestial diffuse shading across her 3D anatomy and garments, weighted toward contours
	// so external lights sculpt her 3D form without washing out the dark cosmos inside her silhouette.
	float ndotl = dot(n, l);
	float wrapped_diffuse = smoothstep(-0.35, 1.0, ndotl);
	float fresnel = pow(1.0 - clamp(abs(dot(n, v)), 0.0, 1.0), 2.2);

	// Subsurface translucent scattering when light passes through her star-filled form.
	vec3 back_dir = normalize(l + n * 0.38);
	float translucency = pow(clamp(dot(-v, back_dir), 0.0, 1.0), 3.2) * 0.55;

	// Pearlescent Schlick-GGX specular highlight on her contours.
	float ndoth = max(dot(n, h), 0.0);
	float spec = pow(ndoth, 48.0) * 0.18;

	vec3 iridescent_tint = mix(aura_tint, vec3(0.58, 0.90, 1.0), fresnel);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (
		ALBEDO * wrapped_diffuse * 0.35
		+ iridescent_tint * translucency * fresnel * 0.18
		+ iridescent_tint * fresnel * max(ndotl + 0.25, 0.0) * 0.12
	);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * mix(vec3(1.0), iridescent_tint, 0.4) * spec * (0.35 + 0.65 * fresnel);
}
