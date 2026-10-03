shader_type spatial;
render_mode world_vertex_coords, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Simulated hair (HairRig). Each vertex follows one guide strand:
//   UV2.x   which guide (row of the point textures)
//   UV2.y   how far along it, 0 root .. 1 tip
//   CUSTOM0 its rest-space offset from the guide at that point
// rest_points holds the guides in rest space, current_points their simulated
// world positions this frame, `head` carries rest space to the world as the
// head does. The offset (and the normal) is carried by the head, then turned
// by however much the guide has bent there away from its rigidly-carried shape.

uniform sampler2D strands : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rest_points : filter_nearest;
uniform sampler2D current_points : filter_nearest;
uniform int points = 15;
uniform mat4 head = mat4(1.0);
uniform float cutoff = 0.42;
uniform float shine = 0.35;

vec3 turn(vec3 v, vec3 from, vec3 to) {
	vec3 axis = cross(from, to);
	float s = length(axis);
	float c = dot(from, to);
	if (s < 1e-5) {
		return v;
	}
	axis /= s;
	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

vec3 now_at(int i, int g) {
	return texelFetch(current_points, ivec2(clamp(i, 0, points - 1), g), 0).xyz;
}

vec3 rest_at(int i, int g) {
	return (head * vec4(texelFetch(rest_points, ivec2(clamp(i, 0, points - 1), g), 0).xyz, 1.0)).xyz;
}

vec3 catmull(vec3 p0, vec3 p1, vec3 p2, vec3 p3, float t) {
	return 0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t);
}

// One guide's take on where this vertex is: the guide's smooth curve at s,
// plus the vertex's offset from it, carried by the head and turned by the
// guide's bend there. Also hands back the turned normal.
vec3 follow(int g, float s, vec3 rest_offset, vec3 normal_in, out vec3 normal_out) {
	int i0 = min(int(floor(s)), points - 2);
	float f = s - float(i0);
	vec3 c_1 = now_at(i0 - 1, g);
	vec3 c0 = now_at(i0, g);
	vec3 c1 = now_at(i0 + 1, g);
	vec3 c2 = now_at(i0 + 2, g);
	vec3 r_1 = rest_at(i0 - 1, g);
	vec3 r0 = rest_at(i0, g);
	vec3 r1 = rest_at(i0 + 1, g);
	vec3 r2 = rest_at(i0 + 2, g);
	// Tangents at the two guide points, blended: the bend is continuous
	// along the strand instead of turning in steps at each particle.
	vec3 from = normalize(mix(normalize(r1 - r_1), normalize(r2 - r0), f));
	vec3 to = normalize(mix(normalize(c1 - c_1), normalize(c2 - c0), f));
	mat3 carry = mat3(head);
	normal_out = turn(carry * normal_in, from, to);
	return catmull(c_1, c0, c1, c2, f) + turn(carry * rest_offset, from, to);
}

void vertex() {
	// Three guides, packed exactly as g0 + n*g1 + n*n*g2.
	int packed = int(UV2.x + 0.5);
	int n = textureSize(current_points, 0).y;
	int g0 = packed % n;
	int g1 = (packed / n) % n;
	int g2 = packed / (n * n);
	float s = clamp(UV2.y, 0.0, 1.0) * float(points - 1);
	vec3 n0;
	vec3 n1;
	vec3 n2;
	vec3 p0 = follow(g0, s, CUSTOM0.xyz, NORMAL, n0);
	vec3 p1 = follow(g1, s, CUSTOM1.xyz, NORMAL, n1);
	vec3 p2 = follow(g2, s, CUSTOM2.xyz, NORMAL, n2);
	VERTEX = p0 * CUSTOM0.w + p1 * CUSTOM1.w + p2 * CUSTOM2.w;
	NORMAL = normalize(n0 * CUSTOM0.w + n1 * CUSTOM1.w + n2 * CUSTOM2.w);
}

void fragment() {
	vec4 strand = texture(strands, UV);
	ALBEDO = COLOR.rgb * strand.rgb;
	ALPHA = strand.a;
	ALPHA_SCISSOR_THRESHOLD = cutoff;
	ROUGHNESS = 0.46;
	SPECULAR = shine;
	ANISOTROPY = 0.7;
	ANISOTROPY_FLOW = vec2(0.0, 1.0);
	BACKLIGHT = COLOR.rgb * 0.3;
}
