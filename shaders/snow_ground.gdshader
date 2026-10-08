shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying vec3 world_pos;
varying vec3 world_normal;
varying float snow_weight;
varying float crystal;

uniform sampler2D snow_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D dirt_tex : repeat_enable, filter_linear_mipmap;
// Baked periodic gradient noise: linear data, not a colour texture.
uniform sampler2D terrain_noise : repeat_enable, filter_linear_mipmap;
uniform sampler2D green_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D grass_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D mud_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D green_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D grass_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D mud_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform bool ground_textures = false;
uniform bool lean_graphics = true;
// House snow patches have no vertex colors. They explicitly use this default;
// only terrain opts into its biome weight stored in COLOR.r.
uniform bool use_vertex_snow = false;
uniform float snow_default : hint_range(0.0, 1.0) = 1.0;
uniform float uv_scale = 0.08;
uniform float ground_uv_scale = 0.22;
uniform float grass_uv_scale = 0.1;
uniform vec3 tint = vec3(0.82, 0.86, 0.9);
uniform vec3 shade = vec3(0.4, 0.52, 0.7);
uniform vec3 dirt_color = vec3(0.36, 0.22, 0.11);
uniform vec3 rock_color = vec3(0.30, 0.30, 0.32);
// How far green land is pushed from the textures' olive toward lush green.
uniform float lushness : hint_range(0.0, 1.0) = 0.7;
uniform vec3 moss_color = vec3(0.12, 0.22, 0.06);
uniform float snow_depth = 0.2;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

// A small soft point somewhere in this cell of the grid, so glints read as
// grains of ice and not as the grid's squares.
float point_in_cell(vec2 p, float radius) {
	vec2 cell = floor(p);
	vec2 at = vec2(hash21(cell + 17.0), hash21(cell + 71.0)) * (1.0 - 2.0 * radius) + radius;
	float d = length(fract(p) - at);
	return 1.0 - smoothstep(radius * 0.35, radius, d);
}

float gradient_noise(vec2 p) {
	return texture(terrain_noise, p / 64.0).r * 2.0 - 1.0;
}

// Rotate the noise basis and warp it before every octave, including the thaw
// edge, to hide the underlying lattice across horizontal and cliff surfaces.
float field_noise(vec2 p) {
	vec2 rotated = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p;
	vec2 warp = vec2(gradient_noise(rotated * 0.43 + vec2(17.1, 8.7)), gradient_noise(rotated * 0.43 + vec2(-7.4, 31.2)));
	return clamp(0.5 + gradient_noise(rotated + warp * 1.6), 0.0, 1.0);
}

// The slope of wind ripples in the snow: a few long waves in unrelated
// directions, summed. Its gradient is exact and smooth everywhere, so lighting
// shows no lattice (finite differences of lattice noise did: faint squares).
vec2 ripple_slope(vec2 p) {
	vec2 slope = vec2(0.0);
	vec2 dirs[5] = vec2[](vec2(0.94, 0.34), vec2(-0.41, 0.91), vec2(0.62, -0.78), vec2(-0.97, -0.24), vec2(0.17, 0.99));
	float freq[5] = float[](1.7, 2.9, 4.3, 6.1, 8.9);
	float amp[5] = float[](0.09, 0.06, 0.045, 0.03, 0.02);
	float phase[5] = float[](0.3, 1.9, 4.1, 2.6, 5.2);
	for (int k = 0; k < 5; k++) {
		slope += dirs[k] * cos(dot(dirs[k], p) * freq[k] + phase[k]) * amp[k];
	}
	return slope;
}

vec3 triplanar_color(sampler2D map, vec3 p, vec3 weights) {
	return texture(map, p.yz).rgb * weights.x + texture(map, p.xz).rgb * weights.y + texture(map, p.xy).rgb * weights.z;
}

vec3 triplanar_normal(sampler2D map, vec3 p, vec3 weights, vec3 base) {
	vec3 x = texture(map, p.yz).xyz * 2.0 - 1.0;
	vec3 y = texture(map, p.xz).xyz * 2.0 - 1.0;
	vec3 z = texture(map, p.xy).xyz * 2.0 - 1.0;
	return normalize(vec3(x.z * sign(base.x), x.x, x.y) * weights.x
		+ vec3(y.x, y.z * sign(base.y), y.y) * weights.y
		+ vec3(z.x, z.y, z.z * sign(base.z)) * weights.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	snow_weight = use_vertex_snow ? clamp(COLOR.r, 0.0, 1.0) : snow_default;
}

void fragment() {
	vec3 base = normalize(world_normal);
	vec3 weights = pow(abs(base), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.0001);
	float thaw = 4.0 * snow_weight * (1.0 - snow_weight);
	float edge_noise = 0.0;
	if (thaw > 0.0) {
		edge_noise = field_noise(world_pos.xz * 0.7 + vec2(41.7, -8.1)) - 0.5;
	}
	float cover = smoothstep(0.35, 0.65, snow_weight + edge_noise * 0.65 * thaw);
	float slope = clamp(1.0 - base.y, 0.0, 1.0);
	float rock_mask = use_vertex_snow ? smoothstep(0.22, 0.5, slope) : 0.0;
	cover *= 1.0 - rock_mask;

	// These branches are coherent over whole snowfields/green hills. Do not
	// shade an invisible earth layer under pure snow (or snow under grass).
	float drift = 0.5;
	float grains = 0.5;
	vec3 snow = tint;
	if (cover > 0.0) {
		vec2 uv = world_pos.xz * uv_scale;
		float cloth = dot(texture(snow_tex, uv).rgb, vec3(0.3, 0.59, 0.11));
		float broad = texture(snow_tex, uv * 0.21).r;
		drift = field_noise(world_pos.xz * 0.31);
		float clumps = field_noise(world_pos.xz * 1.5);
		grains = field_noise(world_pos.xz * 6.5);
		float pack = clamp(0.28 + drift * 0.34 + clumps * 0.28 + grains * 0.16, 0.0, 1.0);
		snow = mix(shade, tint, pack) * mix(0.86, 1.08, broad) * mix(0.92, 1.05, cloth);
		float fleck = pow(hash21(floor(world_pos.xz * 32.0)), 36.0) * point_in_cell(world_pos.xz * 32.0, 0.22);
		snow = mix(snow, vec3(0.95, 0.97, 1.0), fleck);
	}

	float biome_mix = 0.5;
	vec3 earth = dirt_color;
	vec3 rock = rock_color;
	if (cover < 1.0) {
		biome_mix = field_noise(world_pos.xz * 0.045);
		float speckle = texture(dirt_tex, world_pos.xz * 0.07).r;
		vec3 floor_color = mix(vec3(0.16, 0.23, 0.10), dirt_color, biome_mix) * mix(0.72, 1.08, speckle);
		vec3 mud = dirt_color * mix(0.60, 0.88, speckle);
		if (ground_textures) {
			floor_color = mix(texture(green_tex, world_pos.xz * ground_uv_scale).rgb,
				texture(grass_tex, world_pos.xz * grass_uv_scale).rgb, smoothstep(0.3, 0.7, biome_mix));
			if (thaw > 0.0) {
				mud = texture(mud_tex, world_pos.xz * ground_uv_scale).rgb * 0.62;
			}
		}
		float green_level = dot(floor_color, vec3(0.3, 0.59, 0.11));
		vec3 lush = vec3(green_level * 0.62, green_level * 1.12 + 0.03, green_level * 0.42);
		floor_color = mix(floor_color, lush, lushness);
		floor_color = mix(floor_color, moss_color * mix(0.8, 1.2, speckle), smoothstep(0.55, 0.8, field_noise(world_pos.xz * 0.12 + vec2(-13.0, 5.0))) * lushness * 0.7);
		earth = mix(floor_color, mud, thaw * 0.85);
	}
	if (rock_mask > 0.0) {
		if (cover == 0.0) {
			grains = field_noise(world_pos.xz * 6.5);
		}
		rock = rock_color * mix(0.75, 1.12, grains);
		if (ground_textures) {
			vec3 rock_sample = triplanar_color(grass_tex, world_pos * ground_uv_scale, weights);
			rock = rock_color * mix(0.6, 1.35, dot(rock_sample, vec3(0.3, 0.59, 0.11)));
		}
		float strata = field_noise(vec2(world_pos.y * 0.9 + field_noise(world_pos.xz * 0.05) * 3.0, dot(world_pos.xz, vec2(0.02, 0.03))));
		rock *= mix(0.72, 1.18, strata);
	}
	ALBEDO = mix(mix(earth, snow, cover), rock, rock_mask);

	vec3 n = base;
	float detail = 1.0 - smoothstep(12.0, 45.0, length(VERTEX));
	if (!lean_graphics && detail > 0.0) {
		vec3 snow_n = base;
		if (cover > 0.0) {
			vec2 warp = vec2(field_noise(world_pos.xz * 0.11), field_noise(world_pos.xz * 0.11 + vec2(23.0, -9.0))) * 6.0;
			vec2 ripple = ripple_slope(world_pos.xz + warp) * mix(0.6, 1.4, drift);
			snow_n = normalize(base + vec3(-ripple.x, 0.0, -ripple.y) * 1.6);
		}
		vec3 earth_n = base;
		if (ground_textures && cover < 1.0) {
			vec3 floor_n = mix(texture(green_normal, world_pos.xz * ground_uv_scale).xyz,
				texture(grass_normal, world_pos.xz * grass_uv_scale).xyz, smoothstep(0.3, 0.7, biome_mix)) * 2.0 - 1.0;
			vec3 detail_n = floor_n;
			if (thaw > 0.0) {
				vec3 mud_n = texture(mud_normal, world_pos.xz * ground_uv_scale).xyz * 2.0 - 1.0;
				detail_n = mix(floor_n, mud_n, thaw * 0.85);
			}
			earth_n = normalize(base + vec3(detail_n.x, 0.0, detail_n.y) * 0.45);
			if (rock_mask > 0.0) {
				earth_n = normalize(mix(earth_n, triplanar_normal(grass_normal, world_pos * ground_uv_scale, weights, base), rock_mask * 0.5));
			}
		}
		n = normalize(mix(base, mix(earth_n, snow_n, cover), detail));
	}
	NORMAL = normalize(mat3(VIEW_MATRIX) * n);
	crystal = cover > 0.0 ? pow(hash21(floor(world_pos.xz * 40.0)), 16.0) * point_in_cell(world_pos.xz * 40.0, 0.18) * cover : 0.0;
	float earth_roughness = mix(0.98, 0.48, thaw);
	ROUGHNESS = mix(mix(earth_roughness, mix(0.82, 0.22, crystal), cover), 0.98, rock_mask);
	SPECULAR = mix(0.16 + thaw * 0.22, 0.45, cover);
	SSS_STRENGTH = 0.42 * cover;
	SSS_TRANSMITTANCE_COLOR = vec4(0.5, 0.7, 0.95, 1.0);
	SSS_TRANSMITTANCE_DEPTH = snow_depth;
	SSS_TRANSMITTANCE_BOOST = 1.2;
}

void light() {
	DIFFUSE_LIGHT += max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION * LIGHT_COLOR / PI * 0.28;
	float spec = pow(clamp(dot(normalize(LIGHT + VIEW), NORMAL), 0.0, 1.0), 64.0);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * spec * crystal * 4.0 * SPECULAR_AMOUNT;
}
