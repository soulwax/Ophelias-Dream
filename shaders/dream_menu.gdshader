shader_type canvas_item;
uniform float gaze = 0.5;
uniform float gaze_y = 0.65;
uniform float aspect = 1.7778;
float grain(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float triangle(vec2 p, vec2 a, vec2 b, vec2 c) {
 vec2 ab = b-a; vec2 bc = c-b; vec2 ca = a-c;
 float d1 = ab.x*(p.y-a.y)-ab.y*(p.x-a.x);
 float d2 = bc.x*(p.y-b.y)-bc.y*(p.x-b.x);
 float d3 = ca.x*(p.y-c.y)-ca.y*(p.x-c.x);
 return float((d1>=0.0 && d2>=0.0 && d3>=0.0) || (d1<=0.0 && d2<=0.0 && d3<=0.0));
}
void fragment() {
 // Deliberately coarse, original cel-shaded portrait. The iris remains live.
 vec2 p = floor(UV * vec2(800.0,450.0))/vec2(800.0,450.0);
 vec2 e = vec2((p.x-0.50)*1.7778, (p.y-0.49));
 e.y += e.x*0.13;
 float span = clamp(1.0-pow(abs(e.x)/0.65,2.0),0.0,1.0);
 float upper = -0.155*span;
 float lower = 0.205*span;
 float eye_mask = step(upper,e.y)*step(e.y,lower)*step(abs(e.x),0.65);
 vec3 ink = vec3(0.12,0.115,0.14);
 ink += vec3(0.035)*step(-0.34,e.y)*step(e.y,-0.22);
 ink -= vec3(0.035)*step(0.27,e.y);
 // Angular planes of forehead, cheek and the fold above the lid.
 ink += vec3(0.035)*triangle(p,vec2(0.25,0.18),vec2(0.73,0.16),vec2(0.63,0.34));
 ink += vec3(0.025)*triangle(p,vec2(0.46,0.77),vec2(0.84,0.57),vec2(0.83,0.91));
 float crease = step(upper-0.075,e.y)*step(e.y,upper-0.063)*span;
 ink = mix(ink,vec3(0.04,0.04,0.055),crease);
 float liner = step(upper-0.038,e.y)*step(e.y,lower+0.023)*step(abs(e.x),0.69);
 ink = mix(ink,vec3(0.008,0.013,0.019),liner);
 vec3 white = vec3(0.48,0.48,0.56);
 white += vec3(0.12)*step(0.115,e.y)*span;
 white -= vec3(0.12)*step(e.y,upper+0.036);
 vec2 iris_p = vec2(e.x-(gaze-0.5)*0.59,e.y-((gaze_y-0.5)*0.16+0.02));
 iris_p.y *= 1.7778;
 float r = length(iris_p);
 float angle = atan(iris_p.y,iris_p.x);
 float iris = step(r,0.245);
 float bands = floor(clamp((0.245-r)/0.20,0.0,1.0)*5.0)/5.0;
 vec3 iris_color = mix(vec3(0.025,0.06,0.095),vec3(0.07,0.38,0.44),bands);
 iris_color += vec3(0.015,0.085,0.08)*step(0.1,sin(angle*47.0+r*20.0))*step(0.1,r);
 iris_color *= mix(0.28,1.0,smoothstep(-0.06,0.18,iris_p.y));
 iris_color = mix(iris_color,vec3(0.005,0.008,0.014),step(r,0.10));
 float glint = step(length((iris_p-vec2(0.065,-0.095))*vec2(1.0,1.8)),0.035);
 iris_color = mix(iris_color,vec3(0.83,0.85,0.84),glint);
 white = mix(white,iris_color,iris);
 ink = mix(ink,white,eye_mask);
 // A thick tapered brow and dark hair crossing the crop.
 float brow = step(-0.31+e.x*0.1,e.y)*step(e.y,-0.24+e.x*0.055)*step(abs(e.x+0.07),0.61);
 ink = mix(ink,vec3(0.012,0.018,0.025),brow);
 float hair = max(triangle(p,vec2(0.02,0.10),vec2(0.16,0.10),vec2(0.43,0.99)),triangle(p,vec2(0.70,0.09),vec2(0.92,0.08),vec2(1.0,0.79)));
 ink = mix(ink,vec3(0.007,0.026,0.034),hair);
 float strand = triangle(p,vec2(0.04,0.15),vec2(0.065,0.16),vec2(0.35,0.92));
 ink += vec3(0.01,0.025,0.03)*strand;
 float creeping = smoothstep(0.0,1.6,sin(p.x*7.0+p.y*4.0+TIME*0.08)+sin(p.y*9.0-TIME*0.1));
 ink *= 1.0-creeping*0.40;
 float vignette = smoothstep(0.15,0.77,length((UV-0.5)*vec2(1.1,0.85)));
 ink *= 1.0-vignette*0.85;
 ink += (grain(FRAGCOORD.xy+floor(TIME*8.0))-0.5)*0.024;
 ink *= 0.96+0.04*sin(FRAGCOORD.y*3.14159);
 float crop = step(0.12,UV.y)*step(UV.y,0.94)*step(0.06,UV.x)*step(UV.x,0.94);
 COLOR = vec4(ink*crop,1.0);
}
