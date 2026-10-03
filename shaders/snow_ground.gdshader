shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying float slope;
varying vec3 world_pos;
varying vec3 world_normal;
varying float crystal;

uniform sampler2D snow_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D dirt_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform float uv_scale = 0.08;
uniform vec3 tint = vec3(0.82, 0.86, 0.9);
uniform vec3 shade = vec3(0.4, 0.52, 0.7);
uniform vec3 dirt_color = vec3(0.36, 0.22, 0.11);
uniform vec3 rock_color = vec3(0.42, 0.41, 0.4);
uniform float snow_depth = 0.2;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	slope = clamp(1.0 - world_normal.y, 0.0, 1.0);
}

void fragment() {
	vec2 uv = world_pos.xz * uv_scale;
	float cloth = dot(texture(snow_tex, uv).rgb, vec3(0.3, 0.59, 0.11));
	float broad = texture(snow_tex, uv * 0.21).r;
	float drift = vnoise(world_pos.xz * 0.31);
	float clumps = vnoise(world_pos.xz * 1.5);
	float grains = vnoise(world_pos.xz * 6.5);
	float pack = clamp(0.28 + drift * 0.34 + clumps * 0.28 + grains * 0.16, 0.0, 1.0);
	vec3 snow = mix(shade, tint, pack);
	snow *= mix(0.86, 1.08, broad);
	snow *= mix(0.92, 1.05, cloth);
	float fleck = pow(hash21(floor(world_pos.xz * 32.0)), 36.0);
	snow = mix(snow, vec3(0.95, 0.97, 1.0), fleck);

	float patch = texture(dirt_tex, world_pos.xz * 0.015).r;
	float speckle = texture(dirt_tex, world_pos.xz * 0.07 + vec2(19.0, 4.0)).r;
	float dirt_mask = smoothstep(0.56, 0.74, patch);
	dirt_mask = max(dirt_mask, smoothstep(0.7, 0.88, speckle) * smoothstep(0.46, 0.62, patch));
	float hollow = smoothstep(1.2, -5.5, world_pos.y);
	dirt_mask = clamp(dirt_mask + hollow * 0.4, 0.0, 1.0);

	vec3 ground_color = mix(snow, dirt_color * mix(0.72, 1.08, speckle), dirt_mask);
	float rock_mask = smoothstep(0.32, 0.6, slope);
	float cover = 1.0 - max(dirt_mask, rock_mask);
	ALBEDO = mix(ground_color, rock_color, rock_mask);

	float e = 0.08;
	float hx = vnoise(world_pos.xz * 2.2 + vec2(e, 0.0)) - vnoise(world_pos.xz * 2.2);
	float hz = vnoise(world_pos.xz * 2.2 + vec2(0.0, e)) - vnoise(world_pos.xz * 2.2);
	float fx = vnoise(world_pos.xz * 8.0 + vec2(0.03, 0.0)) - vnoise(world_pos.xz * 8.0);
	float fz = vnoise(world_pos.xz * 8.0 + vec2(0.0, 0.03)) - vnoise(world_pos.xz * 8.0);
	vec3 n = normalize(world_normal + vec3(-hx - fx * 0.55, 0.0, -hz - fz * 0.55) * 7.0 * cover);
	NORMAL = normalize(mat3(VIEW_MATRIX) * n);

	crystal = pow(hash21(floor(world_pos.xz * 40.0)), 16.0) * cover;
	ROUGHNESS = mix(mix(0.82, 0.22, crystal), 0.98, max(dirt_mask, rock_mask));
	SPECULAR = mix(0.45, 0.12, max(dirt_mask, rock_mask));
	SSS_STRENGTH = 0.42 * cover;
	SSS_TRANSMITTANCE_COLOR = vec4(0.5, 0.7, 0.95, 1.0);
	SSS_TRANSMITTANCE_DEPTH = snow_depth;
	SSS_TRANSMITTANCE_BOOST = 1.2;
}

void light() {
	DIFFUSE_LIGHT += max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION * LIGHT_COLOR / PI * 0.28;
	float spec = pow(clamp(dot(normalize(LIGHT + VIEW), NORMAL), 0.0, 1.0), 64.0);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * spec * crystal * 4.0;
}
