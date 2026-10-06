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
float grain(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
 vec2 ratio = vec2(1.7778,1.0);
 vec2 uv = (UV-0.5)*vec2(min(aspect/1.7778,1.0),min(1.7778/aspect,1.0))+0.5;
 vec3 stationary = texture(portrait,uv).rgb;
 // Move the globe, keeping the image's dark lashes and skin stationary.
 vec2 angle = vec2((gaze-0.5)*1.05,(gaze_y-0.5)*0.80)*mobility;
 vec2 offset = sin(angle)*vec2(0.11,0.12);
 vec2 local = (uv-eye_center-offset)*ratio/vec2(cos(angle.x),cos(angle.y));
 float radius = length(local)/iris_radius;
 // Remap only the iris annulus. Its outer edge stays fixed as the pupil
 // contracts, so the iris fibres stretch instead of the entire eye swelling.
 float pupil = mix(0.44,0.16,light_level);
 float mapped = radius < pupil ? radius*source_pupil/pupil
  : source_pupil+(radius-pupil)*(1.0-source_pupil)/(1.0-pupil);
 float iris_blend = 1.0-smoothstep(0.96,1.0,radius);
 // Corneal catchlight follows gaze but does not stretch with the pupil.
 iris_blend *= smoothstep(0.065,0.11,length(local-vec2(0.084,-0.05)));
 vec2 sampled_local = local*mix(1.0,mapped/max(radius,0.0001),iris_blend);
 vec2 sample_uv = eye_center+sampled_local/ratio;
 vec3 globe = texture(portrait,sample_uv).rgb;
 // The sclera and blue iris form the opening mask in this flat-shaded art.
 // Include the black pupil explicitly; dark lashes remain outside the mask.
 float blue = smoothstep(0.035,0.039,stationary.b-stationary.r);
 float sclera = smoothstep(0.30,0.305,dot(stationary,vec3(0.2126,0.7152,0.0722)));
 float old_pupil = 1.0-smoothstep(0.28,0.33,length((uv-eye_center)*ratio)/iris_radius);
 float opening = max(max(blue,sclera),old_pupil);
 float region = 1.0-smoothstep(0.30,0.43,length((uv-eye_center)*ratio));
 vec3 color = mix(stationary,globe,opening*region);
 color *= mix(0.82,1.0,light_level);
 color += (grain(FRAGCOORD.xy+floor(TIME*8.0))-0.5)*0.006;
 COLOR = vec4(color,1.0);
}
