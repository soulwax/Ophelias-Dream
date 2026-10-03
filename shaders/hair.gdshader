shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Hair cards. The strand texture holds fine strands with staggered, tapered
// tips; vertex COLOR carries the root-to-tip tone. Anisotropy stretches the
// highlight along the strands into a soft sheen band.
//
// UV2.x is how freely a vertex sways (0 on the scalp, 1 at the long tips);
// `sway` is the world-space lag of the hanging length, set by HairRig.

uniform sampler2D strands : source_color, filter_linear_mipmap, repeat_enable;
uniform float cutoff = 0.42;
uniform float shine = 0.35;
uniform vec3 sway = vec3(0.0);

void vertex() {
	float freedom = pow(UV2.x, 1.4);
	VERTEX += (inverse(MODEL_MATRIX) * vec4(sway, 0.0)).xyz * freedom;
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
