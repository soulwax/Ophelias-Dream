shader_type canvas_item;
uniform sampler2D portrait : source_color, filter_linear;
uniform float gaze = 0.5;
uniform float gaze_y = 0.65;
uniform float aspect = 1.7778;
float grain(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
void fragment() {
 // Preserve the portrait proportions, cropping gently on narrower displays.
 vec2 uv = (UV-0.5)*vec2(min(aspect/1.7778,1.0),min(1.7778/aspect,1.0))+0.5;
 vec2 center = vec2(0.503,0.427);
 vec2 local = (uv-center)*vec2(1.7778,1.0);
 // The upper and lower lid contours are fixed in portrait coordinates.
 // Clip the moving globe inside them instead of dragging skin with the iris.
 float lid_x = clamp((uv.x - 0.397) / 0.213, 0.0, 1.0);
 float lid_arch = sin(lid_x * 3.14159265);
 float lid_line = mix(0.387, 0.498, lid_x);
 float upper_lid = lid_line - 0.086 * lid_arch;
 float lower_lid = lid_line + 0.075 * lid_arch;
 float opening = smoothstep(upper_lid, upper_lid + 0.007, uv.y)
  * (1.0 - smoothstep(lower_lid - 0.007, lower_lid, uv.y))
  * smoothstep(0.397, 0.407, uv.x) * (1.0 - smoothstep(0.600, 0.610, uv.x));
 // A small rotation of a spherical globe foreshortens the iris at side gaze.
 // Use one affine transform across the iris, with no radial swelling.
 vec2 angle = vec2((gaze - 0.5) * 0.22, (gaze_y - 0.5) * 0.15);
 vec2 gaze_offset = vec2(sin(angle.x) * 0.047, sin(angle.y) * 0.061);
 vec2 iris_local = uv - center - gaze_offset;
 vec2 rotated = iris_local / vec2(cos(angle.x), cos(angle.y));
 vec2 moved_uv = center + rotated;
 float globe_region = 1.0 - smoothstep(0.094, 0.146, length(local));
 vec3 stationary = texture(portrait, uv).rgb;
 vec3 globe = texture(portrait, moved_uv).rgb;
 vec3 color = mix(stationary, globe, opening * globe_region);
 float shadow = smoothstep(0.3,1.65,sin(uv.x*12.0+uv.y*5.0+TIME*0.12)+sin(uv.y*16.0-TIME*0.09));
 float edges = smoothstep(0.12,0.65,length((uv-center)*vec2(1.0,0.8)));
 color *= 1.0-shadow*edges*0.36;
 float glow = 1.0-smoothstep(0.02,0.11,length(local-gaze_offset*vec2(1.7778,1.0)));
 color += color*vec3(0.02,0.10,0.12)*glow*(0.6+0.4*sin(TIME*1.2));
 color += (grain(FRAGCOORD.xy+floor(TIME*10.0))-0.5)*0.010;
 color *= 0.985+0.015*sin(FRAGCOORD.y*3.14159);
 COLOR = vec4(color,1.0);
}
