shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_disabled, shadows_disabled;

uniform float fade = 1.0;
uniform float press = 0.7;

float boot_half(float along) {
	float width = 0.42;
	width = mix(width, 0.26, smoothstep(0.12, 0.30, along));
	width = mix(width, 0.48, smoothstep(0.38, 0.60, along));
	width = mix(width, 0.16, smoothstep(0.80, 1.0, along));
	return width;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// inside: under the sole. rim: the snow shoved out. tread: the lug grooves.
void boot_weights(vec2 uv, out float inside, out float rim, out float tread) {
	float along = clamp(uv.y, 0.0, 1.0);
	float across = abs(uv.x - 0.5) * 2.0;
	float half_width = boot_half(along);
	float reach = across / max(half_width, 0.05);
	float cap = smoothstep(0.0, 0.045, along) * (1.0 - smoothstep(0.9, 1.0, along));
	inside = (1.0 - smoothstep(0.78, 0.98, reach)) * cap;
	rim = smoothstep(0.52, 0.78, reach) * (1.0 - smoothstep(0.78, 1.05, reach)) * cap;
	float lugs = abs(fract(along * 10.0) - 0.5);
	tread = smoothstep(0.22, 0.38, lugs);
	tread *= smoothstep(0.08, 0.16, along) * (1.0 - smoothstep(0.86, 0.94, along));
	tread *= inside;
}

// Metres along the patch normal. The sole sinks; the rim is the snow that left it.
float displaced(vec2 uv) {
	float inside;
	float rim;
	float tread;
	boot_weights(uv, inside, rim, tread);
	float sink = mix(0.008, 0.02, press);
	float berm = mix(0.012, 0.032, press);
	return -sink * inside - tread * 0.004 + berm * rim;
}

void vertex() {
	float h = displaced(UV);
	float hx = displaced(UV + vec2(0.02, 0.0));
	float hy = displaced(UV + vec2(0.0, 0.02));
	VERTEX.z += h;
	float inside;
	float rim;
	float tread;
	boot_weights(UV, inside, rim, tread);
	// The berm spreads a little, so the displaced snow is wider than the sole.
	VERTEX.xy += (UV - vec2(0.5, 0.5)) * rim * 0.28;
	NORMAL = normalize(vec3(-(hx - h) / 0.02, -(hy - h) / 0.02, 1.0));
}

void fragment() {
	float inside;
	float rim;
	float tread;
	boot_weights(UV, inside, rim, tread);
	float wall = smoothstep(0.35, 0.9, rim + (1.0 - inside) * inside);
	float seam = (1.0 - smoothstep(0.0, 0.07, abs(UV.x - 0.5))) * inside;
	float grain = hash(UV * vec2(220.0, 90.0));
	vec3 packed = vec3(0.55, 0.60, 0.66);
	vec3 hollow = vec3(0.30, 0.34, 0.40);
	vec3 ridge = vec3(0.90, 0.93, 0.96);
	vec3 color = mix(packed, hollow, press * 0.55 + wall * 0.35);
	color = mix(color, hollow * 0.82, max(tread, seam) * 0.7);
	color = mix(color, ridge, rim);
	color *= mix(0.94, 1.03, grain);

	float alpha = max(inside * mix(0.78, 0.92, press), rim * 0.72);
	alpha *= smoothstep(0.0, 0.08, inside + rim);
	ALBEDO = color;
	ALPHA = alpha * fade;
	ROUGHNESS = mix(0.96, 0.72, rim);
	// The sole sits in the snow. Pull the patch toward the camera so the
	// surface underneath does not paint over the hole.
	vec3 closer = vec3(VERTEX.xy, VERTEX.z + 0.03);
	vec4 clip_pos = PROJECTION_MATRIX * vec4(closer, 1.0);
	DEPTH = clip_pos.z / clip_pos.w;
}
