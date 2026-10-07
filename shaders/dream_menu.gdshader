shader_type canvas_item;
uniform sampler2D portrait : source_color, filter_linear;
uniform float gaze = 0.5;
uniform float gaze_y = 0.65;
uniform vec2 eye_center = vec2(0.424, 0.454);
uniform float iris_radius = 0.205;
uniform float source_pupil = 0.29;
uniform float light_level : hint_range(0.0, 1.0) = 0.45;
uniform float mobility = 1.0;
uniform float aspect = 1.7778;

// Eye opening traced in the original 1672 x 941 portrait. Includes the dark
// iris rim; excludes foreground lids and lashes, regardless of their colour.
const vec2 OPENING[29] = {
	vec2(430,665), vec2(430,607), vec2(437,542), vec2(467,479),
	vec2(493,451), vec2(534,434), vec2(580,417), vec2(626,399),
	vec2(672,377), vec2(724,356), vec2(783,336), vec2(830,327),
	vec2(898,309), vec2(962,302), vec2(1029,306), vec2(1103,315),
	vec2(1177,324), vec2(1166,365), vec2(1150,405), vec2(1122,452),
	vec2(1084,497), vec2(1039,537), vec2(980,576), vec2(918,609),
	vec2(845,632), vec2(762,650), vec2(670,661), vec2(558,669), vec2(480,669)
};

float opening_distance(vec2 uv) {
	vec2 p = uv * vec2(1672.0, 941.0);
	float nearest = 10000.0;
	bool inside = false;
	for (int i = 0; i < 29; i++) {
		vec2 a = OPENING[i];
		vec2 b = OPENING[(i + 1) % 29];
		vec2 edge = b - a;
		vec2 delta = p - a;
		nearest = min(nearest, length(delta - edge * clamp(dot(delta, edge) / dot(edge, edge), 0.0, 1.0)));
		if ((a.y > p.y) != (b.y > p.y)) {
			if (p.x < a.x + (p.y - a.y) * edge.x / edge.y) { inside = !inside; }
		}
	}
	return inside ? nearest : -nearest;
}

float grain(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// Static (no TIME term): used for the iris's own fibre pattern, so it sits
// fixed on the iris and travels with it rather than flickering per frame.
float fibre(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }

void fragment() {
	vec2 ratio = vec2(1.7778, 1.0);
	vec2 uv = (UV - 0.5) * vec2(min(aspect / 1.7778, 1.0), min(1.7778 / aspect, 1.0)) + 0.5;
	vec3 color = texture(portrait, uv).rgb;
	float edge_distance = opening_distance(uv);
	float edge_aa = max(fwidth(edge_distance), 0.6);
	float opening = smoothstep(-edge_aa, edge_aa, edge_distance);
	if (opening > 0.0) {
		// Replace the whole old globe with a clean sclera, not selected colours.
		float bowl = clamp((uv.y - 0.32) / 0.39, 0.0, 1.0);
		vec3 sclera = mix(vec3(0.39, 0.43, 0.54), vec3(0.76, 0.78, 0.84), bowl);
		sclera *= mix(0.70, 1.0, smoothstep(0.0, 24.0, edge_distance));
		vec2 angle = vec2((gaze - 0.5) * 0.85, (gaze_y - 0.5) * 0.65) * mobility;
		vec2 offset = sin(angle) * vec2(0.075, 0.085);
		vec2 local = (uv - eye_center - offset) * ratio / vec2(cos(angle.x), cos(angle.y));
		float radius = length(local) / iris_radius;
		float aa = max(fwidth(radius), 0.001);
		float pupil = mix(0.43, 0.19, light_level);
		float annulus = clamp((radius - pupil) / (1.0 - pupil), 0.0, 1.0);
		float mapped = mix(source_pupil + 0.025, 0.89, annulus);
		// Recover the obscured upper iris from the unobstructed lower half.
		// These bounded samples cannot pull in lashes or the baked catchlight.
		vec2 direction = local / max(length(local), 0.00001);
		vec2 source = vec2(direction.x, abs(direction.y)) * mapped * iris_radius;
		vec3 iris = texture(portrait, eye_center + source / ratio).rgb;
		// Fibre-like variation, randomised by angle and radius rather than the
		// mirrored sample itself, so the recovered upper iris does not read as
		// a plain reflection of the lower half. Stronger in good light, the
		// way iris detail only really shows once the pupil has drawn in.
		float angle_for_fibre = atan(local.y, local.x);
		float fibre_a = fibre(vec2(angle_for_fibre * 11.0, mapped * 7.3));
		float fibre_b = fibre(vec2(angle_for_fibre * 23.0 + 4.1, mapped * 13.7 + 1.7));
		float fibre_reach = mix(0.35, 1.0, light_level);
		iris *= mix(1.0 - 0.10 * fibre_reach, 1.0 + 0.08 * fibre_reach, fibre_a);
		iris *= mix(1.0 - 0.05 * fibre_reach, 1.0 + 0.05 * fibre_reach, fibre_b);
		iris *= mix(0.40, 1.0, smoothstep(-0.07, 0.12, local.y));
		iris = mix(iris, vec3(0.008, 0.019, 0.027), smoothstep(0.87, 0.97, radius));
		iris = mix(vec3(0.002, 0.009, 0.012), iris, smoothstep(pupil - aa, pupil + aa, radius));
		vec3 globe = mix(sclera, iris, 1.0 - smoothstep(1.0 - aa, 1.0 + aa, radius));
		// A corneal catchlight is a reflection off the eye's own wet surface,
		// not a mark on the iris: it stays put as the iris turns underneath
		// it, so it is placed in eye-socket space (barely coupled to offset),
		// never in the iris-local frame the way the iris sample itself is.
		vec2 fixed_local = (uv - eye_center - offset * 0.12) * ratio;
		vec2 reflection = (fixed_local - vec2(0.075, -0.051)) / vec2(0.038, 0.023);
		reflection = vec2(reflection.x + reflection.y * 0.32, reflection.y);
		float highlight = 1.0 - smoothstep(0.88, 1.05, length(reflection));
		float secondary = 1.0 - smoothstep(0.005, 0.011, length(fixed_local - vec2(0.035, -0.025)));
		globe = mix(globe, vec3(0.90, 0.96, 1.0), highlight * 0.96);
		globe += vec3(0.40, 0.56, 0.60) * secondary;
		// A thin welling line of moisture along the lower lid margin: a slightly
		// teary look, not a streaming one.
		float lower_lid = clamp(smoothstep(0.10, 0.34, uv.y - eye_center.y), 0.0, 1.0);
		float lid_margin = 1.0 - smoothstep(1.2, 8.0, edge_distance);
		float tear_rim = lower_lid * lid_margin;
		globe = mix(globe, vec3(0.88, 0.93, 0.99), tear_rim * 0.30);
		color = mix(color, globe, opening);
	}
	color *= mix(0.82, 1.0, light_level);
	color += (grain(FRAGCOORD.xy + floor(TIME * 8.0)) - 0.5) * 0.006;
	COLOR = vec4(color, 1.0);
}
