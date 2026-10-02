shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.35;
uniform vec3 hurt = vec3(0.25, 0.0, 0.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = smoothstep(0.55, 1.2, length(p));
	float pulse = edge * strength;
	COLOR = vec4(hurt, pulse);
}
