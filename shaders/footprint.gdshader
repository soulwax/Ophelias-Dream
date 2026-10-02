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

void fragment() {
	// UV.y 0 is the heel, UV.y 1 is the toe.
	float along = clamp(UV.y, 0.0, 1.0);
	float across = abs(UV.x - 0.5) * 2.0;
	float half_width = boot_half(along);
	float reach = across / max(half_width, 0.05);
	float heel_cap = smoothstep(0.0, 0.045, along);
	float toe_cap = 1.0 - smoothstep(0.9, 1.0, along);
	float inside = (1.0 - smoothstep(0.78, 0.98, reach)) * heel_cap * toe_cap;
	float rim = smoothstep(0.62, 0.86, reach) * (1.0 - smoothstep(0.86, 1.06, reach)) * heel_cap * toe_cap;
	float wall = smoothstep(0.5, 0.84, reach) * inside;

	float lugs = abs(fract(along * 10.0) - 0.5);
	float tread = smoothstep(0.22, 0.38, lugs);
	tread *= smoothstep(0.08, 0.16, along) * (1.0 - smoothstep(0.86, 0.94, along));
	tread *= inside;
	float seam = (1.0 - smoothstep(0.0, 0.07, abs(UV.x - 0.5))) * inside;

	float grain = hash(UV * vec2(220.0, 90.0));
	vec3 packed = vec3(0.55, 0.60, 0.66);
	vec3 hollow = vec3(0.30, 0.34, 0.40);
	vec3 ridge = vec3(0.90, 0.93, 0.96);
	vec3 color = mix(packed, hollow, press * 0.55 + wall * 0.35);
	color = mix(color, hollow * 0.82, max(tread, seam) * 0.7);
	color = mix(color, ridge, rim);
	color *= mix(0.94, 1.03, grain);

	float alpha = max(inside * mix(0.78, 0.92, press), rim * 0.62);
	alpha *= smoothstep(0.0, 0.08, inside + rim);
	ALBEDO = color;
	ALPHA = alpha * fade;
	ROUGHNESS = mix(0.96, 0.78, rim);
}
