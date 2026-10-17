shader_type sky;
render_mode use_quarter_res_pass, use_debanding, disable_fog;

uniform vec3 sky_color : source_color = vec3(0.25, 0.43, 0.66);
uniform vec3 horizon_color : source_color = vec3(0.78, 0.79, 0.76);
uniform vec3 cloud_light_color : source_color = vec3(0.91, 0.92, 0.90);
uniform vec3 cloud_shadow_color : source_color = vec3(0.39, 0.48, 0.60);
uniform vec3 sun_direction = vec3(0.0, 0.8, 0.6);
uniform vec3 sun_light_color : source_color = vec3(1.0, 0.96, 0.86);
uniform float sun_energy = 1.0;
uniform vec2 sun_screen_uv = vec2(-2.0);
uniform float sun_screen_radius = 0.006;
uniform float screen_aspect = 1.7778;
uniform float sun_screen_visible = 0.0;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.42;
uniform float cloud_opacity : hint_range(0.0, 1.0) = 0.84;
uniform vec2 cloud_offset = vec2(0.0);
uniform vec2 cloud_origin = vec2(0.0);
uniform float sun_warmth : hint_range(0.0, 1.0) = 0.16;
uniform float daylight_amount : hint_range(0.0, 1.0) = 1.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float cloud_noise(vec2 p) {
	float n = 0.0;
	float weight = 0.56;
	mat2 turn = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80));
	for (int i = 0; i < 4; i++) {
		n += noise2(p) * weight;
		p = turn * p * 2.03 + vec2(7.1, 3.7);
		weight *= 0.5;
	}
	return n;
}

vec4 cloud_layer(vec3 view_dir, vec3 sun_dir, vec3 sun_color) {
	float sky_uv_depth = 1.0 / max(view_dir.y + 0.20, 0.24);
	vec2 cloud_uv = view_dir.xz * sky_uv_depth + cloud_origin;
	vec2 wind = cloud_offset;
	// Warp the cloud field at a larger scale before adding smaller puffs and
	// stretched wisps. This breaks up the round, tiled noise blobs into softer,
	// wind-sculpted cloud banks.
	vec2 warp = vec2(
		noise2(cloud_uv * 1.15 + wind * 0.42 + vec2(4.2, -8.1)),
		noise2(cloud_uv * 1.15 + wind * 0.42 + vec2(-7.4, 3.6))
	) - 0.5;
	vec2 cloud_shape_uv = cloud_uv + warp * 0.46;
	float broad = cloud_noise(cloud_shape_uv * 2.05 + wind);
	float detail = cloud_noise(cloud_shape_uv * 4.3 - wind * 1.65 + vec2(13.7, -9.2));
	float wisps = noise2(cloud_shape_uv * vec2(5.8, 1.65) + wind * 0.6);
	float shape = broad * 0.67 + detail * 0.23 + wisps * 0.10;
	float coverage_threshold = mix(0.72, 0.30, cloud_coverage);
	float clouds = smoothstep(coverage_threshold - 0.20, coverage_threshold + 0.25, shape);
	clouds *= smoothstep(-0.12, 0.10, view_dir.y) * cloud_opacity;
	float cloud_edge = smoothstep(0.08, 0.62, shape - coverage_threshold + 0.22);
	float sun_facing = pow(max(dot(normalize(vec3(sun_dir.x, 0.58, sun_dir.z)), normalize(vec3(view_dir.x, 0.72, view_dir.z))), 0.0), 2.2);
	vec3 lit_cloud = mix(cloud_shadow_color, cloud_light_color, 0.48 + 0.34 * sun_facing);
	// The bright silver lining is strongest on the sunward edges; noise gaps
	// remain transparent so the disk and its warm scatter still reach the eye.
	lit_cloud += sun_color * sun_facing * cloud_edge * 0.22;
	return vec4(lit_cloud, clouds);
}

void sky() {
	vec3 view_dir = normalize(EYEDIR);
	vec3 sun_dir = normalize(sun_direction);
	vec3 sun_tint = mix(vec3(1.0, 0.78, 0.48), vec3(1.0, 0.96, 0.84), 1.0 - sun_warmth);
	vec3 sun_color = sun_tint * sun_light_color * sun_energy;
	if (AT_QUARTER_RES_PASS) {
		vec4 cloud = cloud_layer(view_dir, sun_dir, sun_color);
		COLOR = cloud.rgb;
		ALPHA = cloud.a;
	} else {
		float elevation = clamp(view_dir.y * 0.5 + 0.5, 0.0, 1.0);
		float horizon_band = exp(-abs(view_dir.y) * 7.0);
		vec3 base = mix(horizon_color, sky_color, pow(elevation, 0.48));
		base = mix(base, horizon_color * 1.08, horizon_band * 0.18);
		vec2 sun_screen_delta = (SCREEN_UV - sun_screen_uv) * vec2(screen_aspect, 1.0);
		float sun_screen_distance = length(sun_screen_delta);
		float sun_disc = sun_screen_visible * (1.0 - smoothstep(sun_screen_radius * 0.72, sun_screen_radius, sun_screen_distance));
		float near_glow = exp(-sun_screen_distance / max(sun_screen_radius * 12.0, 0.001)) * 0.48;
		float far_glow = exp(-sun_screen_distance / max(sun_screen_radius * 42.0, 0.001)) * 0.07;
		vec3 sky_with_sun = base + sun_color * (near_glow + far_glow) * sun_screen_visible;
		vec3 warm_sun_core = sun_color * vec3(3.2, 2.5, 1.45);
		sky_with_sun = mix(sky_with_sun, warm_sun_core, sun_disc);
		vec3 result = mix(sky_with_sun, QUARTER_RES_COLOR.rgb, QUARTER_RES_COLOR.a);
		float atmospheric_glow = exp(-abs(view_dir.y - sun_dir.y) * 11.0) * pow(max(sun_dir.y, 0.0), 0.45);
		result += sun_color * atmospheric_glow * (0.12 + horizon_band * 0.18) * (1.0 - QUARTER_RES_COLOR.a);
		COLOR = mix(result, horizon_color, 1.0 - daylight_amount);
	}
}
