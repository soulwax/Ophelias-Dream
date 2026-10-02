shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Hair cards. The strand texture holds fine strands with staggered, tapered
// tips; vertex COLOR carries the root-to-tip tone of each lock. Anisotropy
// stretches the highlight along the strands into a soft sheen band.

uniform sampler2D strands : source_color, filter_linear_mipmap, repeat_enable;
uniform float cutoff = 0.42;
uniform float shine = 0.55;

void fragment() {
	vec4 strand = texture(strands, UV);
	ALBEDO = COLOR.rgb * strand.rgb;
	ALPHA = strand.a;
	ALPHA_SCISSOR_THRESHOLD = cutoff;
	ROUGHNESS = 0.38;
	SPECULAR = shine;
	ANISOTROPY = 0.75;
	ANISOTROPY_FLOW = vec2(0.0, 1.0);
	BACKLIGHT = COLOR.rgb * 0.35;
}
