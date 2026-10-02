shader_type spatial;
render_mode diffuse_burley, specular_disabled;

varying float slope;

uniform sampler2D snow_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D dirt_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform float uv_scale = 0.08;
uniform vec3 tint = vec3(0.84, 0.88, 0.94);
uniform vec3 shade = vec3(0.58, 0.63, 0.7);
uniform vec3 dirt_color = vec3(0.36, 0.22, 0.11);
uniform vec3 rock_color = vec3(0.42, 0.41, 0.4);

void vertex() {
	vec3 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	slope = clamp(1.0 - world_normal.y, 0.0, 1.0);
}

void fragment() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = world.xz * uv_scale;
	vec3 tex = texture(snow_tex, uv).rgb;
	float broad = texture(snow_tex, uv * 0.21).r;
	vec3 snow = mix(shade, tex * tint, 0.9) * mix(0.9, 1.08, broad);

	float patch = texture(dirt_tex, world.xz * 0.015).r;
	float speckle = texture(dirt_tex, world.xz * 0.07 + vec2(19.0, 4.0)).r;
	float dirt_mask = smoothstep(0.56, 0.74, patch);
	dirt_mask = max(dirt_mask, smoothstep(0.7, 0.88, speckle) * smoothstep(0.46, 0.62, patch));
	float hollow = smoothstep(1.2, -5.5, world.y);
	dirt_mask = clamp(dirt_mask + hollow * 0.4, 0.0, 1.0);

	vec3 ground_color = mix(snow, dirt_color * mix(0.72, 1.08, speckle), dirt_mask);
	float rock_mask = smoothstep(0.32, 0.6, slope);
	ALBEDO = mix(ground_color, rock_color, rock_mask);
	ROUGHNESS = mix(0.88, 1.0, max(dirt_mask, rock_mask));
}
