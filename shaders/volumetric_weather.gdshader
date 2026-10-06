shader_type fog;

// Heavy volumetric alpine weather shader for Ophelia's Dream.
// Models wind-sheared snow curtains, rolling squall banks, and low spindrift
// hugging the ridge while carving out the cabin and cellar interior so rooms
// stay clear while visible blizzard banks sweep past the windows.

uniform float base_density : hint_range(0.0, 0.25) = 0.014;
uniform float squall_density : hint_range(0.0, 0.35) = 0.032;
uniform float spindrift_density : hint_range(0.0, 0.35) = 0.042;
uniform float ground_level = 0.0;
uniform float weather_intensity : hint_range(0.0, 1.0) = 0.45;
uniform float gust_strength : hint_range(0.0, 1.0) = 0.25;
uniform float whiteout : hint_range(0.0, 1.0) = 0.0;
uniform vec2 wind_dir = vec2(0.92, 0.38);
uniform vec3 wind_scroll = vec3(0.0);
uniform vec4 cold_albedo : source_color = vec4(0.88, 0.92, 0.97, 1.0);
uniform vec4 squall_albedo : source_color = vec4(0.95, 0.97, 1.0, 1.0);
uniform vec4 emission_tint : source_color = vec4(0.66, 0.74, 0.84, 1.0);
uniform float emission_energy : hint_range(0.0, 1.0) = 0.14;
uniform mat4 house_inv_transform = mat4(1.0);
uniform vec3 house_half_extents = vec3(7.4, 5.2, 5.6);
uniform vec3 cellar_center = vec3(0.0, -2.5, -1.6);
uniform vec3 cellar_half_extents = vec3(9.8, 2.8, 7.6);

float hash31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3d(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	float nxy0 = mix(nx00, nx10, f.y);
	float nxy1 = mix(nx01, nx11, f.y);
	return mix(nxy0, nxy1, f.z);
}

float fbm2(vec3 p) {
	float v = 0.65 * noise3d(p);
	p = p * 2.07 + vec3(13.7, -7.3, 5.1);
	v += 0.35 * noise3d(p);
	return v;
}

float box_sdf(vec3 p, vec3 b) {
	vec3 q = abs(p) - b;
	return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

void fog() {
	// Carve out the cabin and subterranean mortuary so indoor air stays crisp.
	vec3 local_house = (house_inv_transform * vec4(WORLD_POSITION, 1.0)).xyz;
	float d_cabin = box_sdf(local_house - vec3(0.0, 2.2, 0.0), house_half_extents);
	float d_cellar = box_sdf(local_house - cellar_center, cellar_half_extents);
	float indoor_mask = smoothstep(-0.35, 0.85, min(d_cabin, d_cellar));

	// Height above the local snow plane.
	float rel_y = WORLD_POSITION.y - ground_level;
	float canopy_fade = 1.0 - smoothstep(5.0, 26.0, rel_y);

	// Wind-sheared coordinate frame so snow curtains slant into the gale.
	vec3 sheared = WORLD_POSITION;
	sheared.xz -= rel_y * wind_dir * (0.34 + 0.42 * gust_strength);

	// Rolling squall fronts and vertical snow shafts advected by wind_scroll.
	vec3 bank_coord = sheared * vec3(0.042, 0.075, 0.042) - wind_scroll * 0.11;
	float bank = fbm2(bank_coord);
	vec3 curtain_coord = sheared * vec3(0.13, 0.048, 0.13) - wind_scroll * 0.26 + vec3(0.0, TIME * 0.85, 0.0);
	float curtains = noise3d(curtain_coord);
	float squall_wave = smoothstep(0.30 - 0.14 * whiteout, 0.78, bank * 0.62 + curtains * 0.38);

	// Ground-hugging spindrift ribbon (0..3.8 m above snow level).
	float drift_band = exp(-max(rel_y + 0.35, 0.0) * (0.62 - 0.22 * gust_strength));
	vec3 drift_coord = WORLD_POSITION * vec3(0.18, 0.32, 0.18) - wind_scroll * 0.38;
	float drift_swirl = noise3d(drift_coord);
	float spindrift = drift_band * smoothstep(0.24, 0.76, drift_swirl) * (0.45 + 0.55 * gust_strength);

	// Soft 3D volume boundary feathering so local squall volumes never clip sharply.
	vec3 edge = smoothstep(vec3(0.0), vec3(0.16), UVW) * (1.0 - smoothstep(vec3(0.84), vec3(1.0), UVW));
	float bounds_fade = edge.x * edge.y * edge.z;

	float body = base_density * mix(0.65, 1.45, weather_intensity) * canopy_fade;
	float squalls = squall_density * squall_wave * (0.35 + 0.65 * weather_intensity + 0.45 * whiteout) * canopy_fade;
	float low_drift = spindrift_density * spindrift * (0.4 + 0.6 * weather_intensity);

	DENSITY = (body + squalls + low_drift) * indoor_mask * bounds_fade;
	float billow = clamp(squall_wave * 0.65 + spindrift * 0.5, 0.0, 1.0);
	ALBEDO = mix(cold_albedo.rgb, squall_albedo.rgb, billow);
	EMISSION = emission_tint.rgb * (emission_energy * (0.55 + 0.45 * whiteout + 0.25 * billow));
}
