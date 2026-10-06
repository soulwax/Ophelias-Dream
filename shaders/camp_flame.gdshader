shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

// A layer of the campfire's flames, drawn entirely by this shader on one
// upright quad that turns about the vertical to face the camera. Two octaves
// of noise scroll up through a tapering mask; the heat that survives picks a
// colour from deep red through orange and yellow to a pale core, and its
// edge sets the alpha, so the fire reads as fire in daylight and glows at night.
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float seed = 0.0;
uniform float brightness = 2.4;
uniform float rise = 1.1;
uniform float width = 1.0;

void vertex() {
	vec3 centre = NODE_POSITION_WORLD;
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - centre;
	to_cam.y = 0.0;
	to_cam = length(to_cam) > 0.001 ? normalize(to_cam) : vec3(0.0, 0.0, 1.0);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), to_cam));
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 world = centre + right * VERTEX.x * sx * width + vec3(0.0, 1.0, 0.0) * VERTEX.y * sy;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float t = TIME * rise;
	vec2 q = vec2(uv.x * 1.1 + seed * 3.7, uv.y * 0.85 - t);
	float n1 = texture(noise, q).r;
	float n2 = texture(noise, q * 2.3 + vec2(seed * 1.3, -t * 0.7)).r;
	float n = n1 * 0.62 + n2 * 0.38;
	// Tongues lean and lick: the noise pushes them sideways, more toward the top.
	float x = (uv.x - 0.5) * 2.0 + (n2 - 0.5) * 0.7 * uv.y + sin(TIME * 2.3 + seed * 6.0) * 0.06 * uv.y;
	float taper = mix(0.9, 0.12, pow(uv.y, 0.75));
	float shape = 1.0 - smoothstep(taper * 0.45, taper, abs(x));
	float base = smoothstep(0.0, 0.07, uv.y);
	float heat = shape * base * (n * 1.35 - uv.y * 0.95 + 0.42);
	float alpha = smoothstep(0.12, 0.34, heat);
	vec3 col = mix(vec3(0.5, 0.06, 0.01), vec3(1.0, 0.33, 0.04), smoothstep(0.12, 0.42, heat));
	col = mix(col, vec3(1.0, 0.68, 0.2), smoothstep(0.42, 0.78, heat));
	col = mix(col, vec3(1.0, 0.93, 0.74), smoothstep(0.82, 1.15, heat));
	ALBEDO = col * brightness;
	ALPHA = alpha;
}
