shader_type spatial;
render_mode cull_disabled;

// The frozen lake: clear black-blue ice with milky patches and white cracks,
// snow drifted across it (deep at the shore), and the old hole, refrozen dark
// with cracks running out from it like spokes.
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D cells : filter_linear_mipmap, repeat_enable;
uniform vec3 centre = vec3(0.0);
uniform float radius = 24.0;
uniform vec2 hole = vec2(0.0);
uniform float hole_radius = 1.1;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float d = length(p - centre.xz) / radius;
	float n = texture(noise, p * 0.035).r;
	float fine = texture(noise, p * 0.23).r;
	float shore = smoothstep(0.72, 1.0, d);
	float drift = smoothstep(0.5, 0.68, n + (fine - 0.5) * 0.3 + shore * 0.75 - 0.08);
	// Stress cracks: cell edges bent by noise so they wander, thin, and only
	// running through some of the ice.
	vec2 warp = vec2(texture(noise, p * 0.05 + 3.1).r, texture(noise, p * 0.05 - 7.7).r) - 0.5;
	float crack = 1.0 - smoothstep(0.0, 0.016, texture(cells, (p + warp * 9.0) * 0.06).r);
	crack *= smoothstep(0.38, 0.62, texture(noise, p * 0.017 + 41.0).r);
	crack = max(crack, (1.0 - smoothstep(0.0, 0.012, texture(cells, (p + warp * 5.0) * 0.17 + 13.0).r))
		* smoothstep(0.5, 0.7, texture(noise, p * 0.03 - 19.0).r) * 0.55);
	vec3 deep = vec3(0.04, 0.075, 0.11);
	vec3 milky = vec3(0.4, 0.5, 0.58);
	vec3 ice = mix(deep, milky, smoothstep(0.38, 0.85, fine) * 0.5 + smoothstep(0.55, 0.8, n) * 0.2);
	ice = mix(ice, vec3(0.78, 0.84, 0.9), crack * 0.75);
	// The old hole: frozen over again, darker, cracked outward.
	vec2 to_hole = p - hole;
	float h = length(to_hole);
	float scar = 1.0 - smoothstep(hole_radius, hole_radius * 1.8, h + (fine - 0.5) * 0.4);
	float angle = atan(to_hole.y, to_hole.x);
	float spoke = 1.0 - smoothstep(0.0, 0.05, abs(sin(angle * 7.0 + fine * 3.0)));
	spoke *= (1.0 - smoothstep(hole_radius * 1.3, hole_radius * 4.5, h)) * smoothstep(hole_radius * 0.9, hole_radius * 1.3, h);
	ice = mix(ice, vec3(0.015, 0.03, 0.045), scar * 0.92);
	ice = mix(ice, vec3(0.8, 0.86, 0.9), spoke * 0.8);
	float snow = drift * (1.0 - scar);
	ALBEDO = mix(ice, vec3(0.86, 0.9, 0.95) * mix(0.9, 1.03, fine), snow);
	ROUGHNESS = mix(mix(0.03, 0.3, crack), 0.85, snow);
	SPECULAR = mix(0.75, 0.4, snow);
}
