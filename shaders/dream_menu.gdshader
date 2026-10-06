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
 float iris_region = 1.0-smoothstep(0.064,0.127,length(local));
 vec2 gaze_offset = vec2((gaze-0.5)*0.018,(gaze_y-0.5)*0.010);
 // A continuous local warp moves the painted iris while pinning the lid and face.
 vec2 sample_uv = uv-gaze_offset*iris_region;
 vec3 color = texture(portrait,sample_uv).rgb;
 float shadow = smoothstep(0.3,1.65,sin(uv.x*12.0+uv.y*5.0+TIME*0.12)+sin(uv.y*16.0-TIME*0.09));
 float edges = smoothstep(0.12,0.65,length((uv-center)*vec2(1.0,0.8)));
 color *= 1.0-shadow*edges*0.36;
 float glow = 1.0-smoothstep(0.02,0.11,length(local-gaze_offset*vec2(1.7778,1.0)));
 color += color*vec3(0.02,0.10,0.12)*glow*(0.6+0.4*sin(TIME*1.2));
 color += (grain(FRAGCOORD.xy+floor(TIME*10.0))-0.5)*0.010;
 color *= 0.985+0.015*sin(FRAGCOORD.y*3.14159);
 COLOR = vec4(color,1.0);
}
