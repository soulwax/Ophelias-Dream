shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx, shadows_disabled;

uniform float fade = 1.0;
uniform float press = 0.7;
// 0 her stride (bowl and berm), 1 a sole that shoved nothing, 2 a berm with no sole.
uniform float mark = 0.0;
// Quad width and length in metres, so a shove in the shader is a shove on the snow.
uniform vec2 span = vec2(0.12, 0.32);

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

// inside: under the sole. rim: where the snow was shoved. tread: the lug grooves.
void boot_weights(vec2 uv, out float inside, out float rim, out float tread) {
	float along = clamp(uv.y, 0.0, 1.0);
	float across = abs(uv.x - 0.5) * 2.0;
	float half_width = boot_half(along);
	float reach = across / max(half_width, 0.05);
	float cap = smoothstep(0.0, 0.06, along) * (1.0 - smoothstep(0.88, 1.0, along));
	inside = (1.0 - smoothstep(0.72, 0.96, reach)) * cap;
	// A wide soft shoulder, not a knife edge the grid cannot hold.
	rim = smoothstep(0.38, 0.78, reach) * (1.0 - smoothstep(0.78, 1.35, reach)) * cap;
	float lugs = abs(fract(along * 9.0) - 0.5);
	tread = smoothstep(0.28, 0.42, lugs);
	tread *= smoothstep(0.1, 0.18, along) * (1.0 - smoothstep(0.84, 0.94, along));
	tread *= inside;
	if (mark > 1.5) {
		inside = 0.0;
		tread = 0.0;
	} else if (mark > 0.5) {
		rim = 0.0;
	}
}

// Metres along the patch normal. Negative is into the snow.
float displaced(vec2 uv) {
	float inside;
	float rim;
	float tread;
	boot_weights(uv, inside, rim, tread);
	float along = clamp(uv.y, 0.0, 1.0);
	// The heel takes the weight. The toe throws a little more snow forward.
	float heel = mix(1.2, 0.74, smoothstep(0.1, 0.72, along));
	float sink = mix(0.008, 0.015, press) * heel;
	float bowl = inside * mix(0.72, 1.0, inside);
	float berm = mix(0.007, 0.015, press);
	berm *= mix(0.85, 1.3, smoothstep(0.55, 0.9, along));
	float grain = hash(uv * vec2(37.0, 17.0)) - 0.5;
	float h = -sink * bowl - tread * 0.0022 + berm * rim + grain * rim * 0.0025;
	// It fills back in before it fades away.
	return h * smoothstep(0.0, 0.62, fade);
}

void vertex() {
	float h = displaced(UV);
	float hx = displaced(UV + vec2(0.03, 0.0));
	float hy = displaced(UV + vec2(0.0, 0.03));
	VERTEX.z += h;
	float inside;
	float rim;
	float tread;
	boot_weights(UV, inside, rim, tread);
	vec2 out_dir = UV - vec2(0.5, 0.46);
	float out_len = max(length(out_dir), 0.001);
	vec2 shove = out_dir / out_len * rim * 0.011 * smoothstep(0.0, 0.62, fade);
	VERTEX.x += shove.x / max(span.x, 0.05);
	VERTEX.y += shove.y / max(span.y, 0.05);
	NORMAL = normalize(vec3(-(hx - h) / 0.03, -(hy - h) / 0.03, 1.0));
}

void fragment() {
	float inside;
	float rim;
	float tread;
	boot_weights(UV, inside, rim, tread);
	float grain = hash(UV * vec2(220.0, 90.0));
	vec3 loose = vec3(0.90, 0.93, 0.97);
	vec3 packed = vec3(0.70, 0.76, 0.82);
	vec3 color = mix(loose, packed, inside * (0.45 + press * 0.4));
	color = mix(color, packed * 0.9, tread * 0.65);
	color = mix(color, loose * 1.03, rim * (1.0 - inside));
	color *= mix(0.96, 1.03, grain);

	float cover = max(inside, rim);
	float alpha = max(inside * 0.96, rim * 0.8);
	alpha *= smoothstep(0.0, 0.12, cover);
	alpha *= smoothstep(0.0, 0.22, fade);
	ALBEDO = color;
	ALPHA = alpha;
	ROUGHNESS = mix(0.94, 0.58, inside * press);
	SPECULAR = mix(0.1, 0.38, inside);
	// A few millimetres, so the sole wins against the snow without the berm floating.
	vec3 closer = vec3(VERTEX.xy, VERTEX.z + 0.01);
	vec4 clip_pos = PROJECTION_MATRIX * vec4(closer, 1.0);
	DEPTH = clip_pos.z / clip_pos.w;
}
