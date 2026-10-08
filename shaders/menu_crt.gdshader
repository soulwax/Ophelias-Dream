shader_type canvas_item;

// The Esc menu's terminal glass, laid over everything drawn beneath it:
// split colour fringes, scanlines, phosphor grain, a slow rolling band and a
// darkened rim. strength 0 leaves the screen untouched (Settings.screen_effects).

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float aberration = 1.4;
uniform float scan = 0.14;
uniform float grain = 0.045;
uniform vec4 tint : source_color = vec4(0.86, 0.12, 0.16, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV;
	// A faint band rolls down the glass and nudges the lines it crosses.
	float roll = abs(fract(uv.y * 0.6 - TIME * 0.05) - 0.5);
	float band = 1.0 - smoothstep(0.0, 0.035, roll);
	uv.x += band * 0.0012 * strength;
	float split = aberration * strength;
	vec3 c;
	c.r = texture(screen, uv + vec2(px.x * split, 0.0)).r;
	c.g = texture(screen, uv).g;
	c.b = texture(screen, uv - vec2(px.x * split, 0.0)).b;
	float line = 0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159);
	c *= 1.0 - scan * strength * line;
	c += band * 0.025 * strength * tint.rgb;
	float n = hash(floor(FRAGCOORD.xy * 0.5) + floor(TIME * 24.0));
	c += (n - 0.5) * grain * strength;
	vec2 v = SCREEN_UV * 2.0 - 1.0;
	c *= 1.0 - 0.22 * strength * dot(v, v);
	c *= 1.0 - 0.012 * strength * sin(TIME * 47.0);
	COLOR = vec4(c, 1.0);
}
