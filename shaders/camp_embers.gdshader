shader_type spatial;

// Charcoal and glowing coals: dark, rough char whose cracks breathe orange.
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec3 char_color : source_color = vec3(0.045, 0.04, 0.038);
uniform float glow = 2.2;
uniform float coverage = 0.68;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * 0.9;
	float cells = texture(noise, p).r;
	float breath = texture(noise, p * 0.6 + vec2(TIME * 0.04, -TIME * 0.03)).r;
	float flick = texture(noise, vec2(TIME * 0.31, p.x * 0.2)).r;
	// Hottest at the heart of the fire, cooling to grey ash at the rim.
	float heart = 1.0 - smoothstep(0.08, 0.38, length(world_pos.xz - NODE_POSITION_WORLD.xz));
	float hot = smoothstep(coverage, coverage + 0.12, cells * 0.55 + breath * 0.45 + heart * 0.3);
	hot *= (0.6 + 0.8 * flick) * (0.35 + 0.65 * heart);
	float ash = (1.0 - heart) * smoothstep(0.45, 0.7, cells);
	ALBEDO = mix(char_color * (0.7 + 0.6 * cells), vec3(0.17, 0.165, 0.16), ash * 0.6);
	ROUGHNESS = 0.95;
	EMISSION = mix(vec3(0.9, 0.18, 0.02), vec3(1.0, 0.5, 0.12), hot) * hot * glow;
}
