shader_type sky;

// Panoramic 360-degree spinning Universe Sky shader for the Dream.
// Renders a slowly revolving celestial sphere with a shaded Milky Way galactic band,
// dark interstellar dust rifts, multiple resolved spinning spiral galaxies at
// horizon-to-mid-sky elevations, 3D normal-shaded emission nebulae, and multi-layer starfields.

uniform float panorama_spin_speed : hint_range(0.005, 0.25) = 0.038;
uniform float galaxy_spin_speed : hint_range(0.05, 1.5) = 0.36;
uniform vec3 horizon_color : source_color = vec3(0.07, 0.08, 0.16);
uniform vec3 zenith_color : source_color = vec3(0.012, 0.014, 0.038);
uniform float cosmic_vividness : hint_range(0.5, 2.5) = 1.45;

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

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
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
		v += a * noise2d(p);
		p = rot * p * 2.02 + vec2(11.3, 23.7);
		a *= 0.5;
	}
	return v;
}

float fbm3(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise3d(p);
		p = p * 2.03 + vec3(9.1, 17.3, 13.7);
		a *= 0.5;
	}
	return v;
}

// Renders a resolved spiral galaxy on the celestial sphere around direction `gal_dir`.
vec3 sky_spiral_galaxy(
	vec3 dir,
	vec3 gal_dir,
	vec3 tilt_axis,
	float angular_radius,
	float inclination,
	float spin,
	float tightness,
	vec3 core_col,
	vec3 arm_col,
	vec3 hii_col,
	vec3 light_dir
) {
	vec3 center = normalize(gal_dir);
	float cos_ang = dot(dir, center);
	if (cos_ang < cos(angular_radius * 1.45)) {
		return vec3(0.0);
	}
	vec3 tangent_x = normalize(cross(tilt_axis, center));
	vec3 tangent_y = cross(center, tangent_x);
	vec2 plane = vec2(dot(dir, tangent_x), dot(dir, tangent_y)) / max(sin(angular_radius), 0.001);
	// Apply disk inclination (foreshortening along tangent_y).
	plane.y *= inclination;
	float r = length(plane);
	if (r > 1.4) {
		return vec3(0.0);
	}

	float theta = atan(plane.y, plane.x) - spin;
	float log_r = log(max(r, 0.015));

	vec2 rot_p = vec2(
		plane.x * cos(spin * 0.5) - plane.y * sin(spin * 0.5),
		plane.x * sin(spin * 0.5) + plane.y * cos(spin * 0.5)
	);
	float turb = fbm2(rot_p * 5.8 + vec2(2.7, -4.1));
	float fine = fbm2(rot_p * 14.5 + vec2(-1.9, 5.3));

	float arm_phase = 2.0 * theta - tightness * log_r + (turb - 0.5) * 1.55;
	float arms = pow(0.5 + 0.5 * cos(arm_phase), 2.6);
	float spurs = pow(0.5 + 0.5 * cos(4.0 * theta - tightness * 1.3 * log_r + (fine - 0.5) * 2.1), 4.2) * 0.5;

	// Dark dust lanes on inner concave spiral edge.
	float dust = pow(0.5 + 0.5 * cos(arm_phase + 0.6), 5.5) * smoothstep(0.07, 0.32, r) * (1.0 - smoothstep(0.75, 1.15, r));
	float dust_atten = clamp(dust * (0.4 + 0.85 * fine), 0.0, 0.78);

	float disk_env = smoothstep(0.02, 0.14, r) * exp(-r * 2.65);
	float edge_fade = 1.0 - smoothstep(0.72, 1.35, r);
	edge_fade *= edge_fade;
	float bulge = (exp(-r * r * 20.0) + 0.42 / (1.0 + r * r * 85.0)) * edge_fade;
	float hii = smoothstep(0.60, 0.86, fine) * arms * disk_env * 2.2;

	// 3D normal-shaded relief on the galactic dust clouds from core + sky directional light.
	vec3 cloud_normal = normalize(center + tangent_x * (turb - 0.5) * 0.6 + tangent_y * (fine - 0.5) * 0.6);
	float shade = 0.68 + 0.32 * max(dot(cloud_normal, light_dir), 0.0);

	vec3 col = core_col * bulge * 1.65;
	col += arm_col * (arms + spurs + 0.16) * disk_env * 1.65 * shade;
	col += hii_col * hii * 1.45;
	col += vec3(0.88, 0.95, 1.0) * pow(max(fine * arms, 0.0), 3.0) * disk_env * 2.4;
	col *= mix(1.0, 0.24, dust_atten) * edge_fade;
	return col;
}

vec3 sky_stars(vec3 dir, float scale, float density_thresh, float time) {
	vec3 p = dir * scale;
	vec3 cell = floor(p);
	vec3 f = fract(p) - 0.5;
	vec3 rnd = hash33(cell);
	if (rnd.z < density_thresh) {
		return vec3(0.0);
	}
	vec3 pos = (rnd - 0.5) * 0.72;
	float d = length(f - pos);
	float sz = mix(0.028, 0.092, pow((rnd.z - density_thresh) / (1.0 - density_thresh), 2.5));
	float core = smoothstep(sz, 0.0, d);
	float halo = exp(-d * d / max(sz * sz * 2.4, 0.0002)) * 0.5;
	float twinkle = 0.76 + 0.24 * sin(time * (1.8 + rnd.x * 4.5) + rnd.y * 23.0);
	vec3 col = mix(
		mix(vec3(0.55, 0.78, 1.0), vec3(1.0, 0.98, 0.94), smoothstep(0.0, 0.5, rnd.x)),
		mix(vec3(1.0, 0.84, 0.54), vec3(1.0, 0.52, 0.68), smoothstep(0.5, 1.0, rnd.x)),
		step(0.5, rnd.x)
	);
	return col * (core * 2.1 + halo) * twinkle;
}

void sky() {
	vec3 view_dir = normalize(EYEDIR);
	float elevation = view_dir.y;

	// Panoramic rotation of the entire universe around a tilted celestial pole.
	float pan_angle = TIME * panorama_spin_speed;
	float cp = cos(pan_angle);
	float sp = sin(pan_angle);
	// Rotate around Y (panorama sweep) and tilt slightly so the cosmos arches overhead.
	vec3 pan_dir = vec3(
		view_dir.x * cp - view_dir.z * sp,
		view_dir.y,
		view_dir.x * sp + view_dir.z * cp
	);
	// Tilted galactic coordinate frame (inclined 36 degrees).
	mat3 gal_frame = mat3(
		vec3(0.809, 0.588, 0.0),
		vec3(-0.558, 0.768, 0.314),
		vec3(0.185, -0.254, 0.949)
	);
	vec3 gdir = gal_frame * pan_dir;

	vec3 light_dir = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION) : normalize(vec3(0.3, 0.6, -0.7));

	// Deep cosmic backdrop gradient.
	float up_factor = clamp(elevation, 0.0, 1.0);
	vec3 sky_col = mix(horizon_color, zenith_color, pow(up_factor, 0.55));

	if (elevation > -0.08) {
		float spin_t = TIME * galaxy_spin_speed;

		// 1. Panoramic Milky Way Galactic Band arching across the sky.
		float gal_lat = gdir.y;
		float gal_lon = atan(gdir.z, gdir.x);
		float band_profile = exp(-gal_lat * gal_lat * 11.5);
		float core_prox = exp(-pow(gal_lon - 0.35, 2.0) * 1.4) * exp(-gal_lat * gal_lat * 6.5);

		vec3 mw_coord = gdir * 3.8 + vec3(TIME * 0.008, 0.0, -TIME * 0.006);
		float mw_clouds = fbm3(mw_coord);
		float mw_fine = fbm3(mw_coord * 2.4 + vec3(4.1, 8.3, -2.7));

		// Dark Great Rift dust lanes carving through the galactic plane with 3D shaded edges.
		float rift_mask = smoothstep(0.42, 0.68, fbm3(gdir * 5.2 + vec3(1.7, -3.2, 0.9))) * exp(-gal_lat * gal_lat * 32.0);
		vec3 mw_normal = normalize(gdir + vec3(mw_clouds - 0.5, mw_fine - 0.5, 0.0) * 0.45);
		float mw_shade = 0.62 + 0.38 * max(dot(mw_normal, light_dir), 0.0);

		vec3 mw_col = mix(vec3(0.18, 0.36, 0.76), vec3(0.68, 0.42, 0.95), mw_clouds);
		mw_col = mix(mw_col, vec3(1.0, 0.78, 0.48), core_prox * 0.78);
		mw_col += vec3(0.95, 0.32, 0.64) * smoothstep(0.58, 0.85, mw_fine) * band_profile * 0.85;
		mw_col *= (0.35 + 1.15 * mw_clouds) * band_profile * mw_shade;
		mw_col += vec3(1.0, 0.86, 0.62) * core_prox * (0.45 + 0.65 * mw_fine) * 0.85;
		mw_col *= mix(1.0, 0.18, clamp(rift_mask * 0.92, 0.0, 0.86));

		// 2. Hero Resolved Spinning Galaxies across the 360-degree panorama:
		//Placed at elevation 16-42 degrees so they are prominently visible above the winter trees!
		vec3 gal_andromeda = sky_spiral_galaxy(
			pan_dir,
			normalize(vec3(-0.42, 0.34, -0.84)),
			vec3(0.25, 0.92, 0.30),
			0.26, 1.65, spin_t * 1.0, 4.3,
			vec3(1.0, 0.90, 0.66), vec3(0.38, 0.76, 1.0), vec3(1.0, 0.34, 0.68), light_dir
		);
		vec3 gal_whirlpool = sky_spiral_galaxy(
			pan_dir,
			normalize(vec3(0.54, 0.29, -0.79)),
			vec3(-0.35, 0.88, -0.31),
			0.22, 1.18, -spin_t * 0.85, 3.9,
			vec3(1.0, 0.82, 0.90), vec3(0.32, 0.88, 0.96), vec3(0.80, 0.40, 1.0), light_dir
		);
		vec3 gal_southern = sky_spiral_galaxy(
			pan_dir,
			normalize(vec3(0.82, 0.36, 0.44)),
			vec3(0.18, 0.95, -0.24),
			0.24, 1.52, spin_t * 0.92, 4.5,
			vec3(1.0, 0.88, 0.62), vec3(0.46, 0.68, 1.0), vec3(1.0, 0.42, 0.64), light_dir
		);
		vec3 gal_western = sky_spiral_galaxy(
			pan_dir,
			normalize(vec3(-0.78, 0.31, 0.54)),
			vec3(-0.22, 0.91, 0.35),
			0.21, 1.35, -spin_t * 1.1, 4.1,
			vec3(0.94, 0.92, 1.0), vec3(0.36, 0.82, 0.98), vec3(0.98, 0.38, 0.74), light_dir
		);
		vec3 gal_zenith = sky_spiral_galaxy(
			pan_dir,
			normalize(vec3(0.08, 0.72, -0.69)),
			vec3(0.88, 0.22, 0.42),
			0.25, 1.28, spin_t * 0.76, 4.0,
			vec3(1.0, 0.86, 0.72), vec3(0.48, 0.74, 1.0), vec3(1.0, 0.36, 0.68), light_dir
		);

		// 3. Multi-layered panoramic starfields spinning with the universe.
		vec3 stars_bright = vec3(0.0);
		if (!AT_CUBEMAP_PASS) {
			stars_bright = sky_stars(pan_dir, 42.0, 0.55, TIME) * 1.35
				+ sky_stars(pan_dir, 95.0, 0.42, TIME * 0.8) * 0.85
				+ sky_stars(gdir, 145.0, max(0.28, 0.68 - band_profile * 0.42), TIME * 0.6) * 0.65;
		}

		vec3 cosmos = (mw_col + gal_andromeda + gal_whirlpool + gal_southern + gal_western + gal_zenith + stars_bright) * cosmic_vividness;

		// Smooth atmospheric horizon blend so mountains and tree line sit naturally in the winter night.
		float horizon_visibility = smoothstep(-0.02, 0.14, elevation);
		sky_col += cosmos * horizon_visibility;
	}

	// Subtle horizon aurora glow where the spinning cosmos meets the snow.
	float horizon_band = exp(-pow((elevation - 0.05) / 0.09, 2.0));
	vec3 horizon_glow = mix(vec3(0.16, 0.26, 0.48), vec3(0.38, 0.20, 0.52), 0.5 + 0.5 * sin(pan_angle * 2.0 + view_dir.x * 3.0));
	sky_col += horizon_glow * horizon_band * 0.28;

	COLOR = sky_col;
}
