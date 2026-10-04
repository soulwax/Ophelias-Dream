shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_always, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

// Pass 0 (shell = false, render_priority = 10): masks interior depth and adds a soft surface rim.
// Pass 1 (shell = true, render_priority = 11): extrudes a watertight silhouette outline around the object.
uniform bool shell = false;
uniform vec4 outline_color : source_color = vec4(0.96, 0.88, 0.70, 0.94);
uniform vec4 rim_color : source_color = vec4(0.98, 0.91, 0.76, 0.12);
uniform float outline_width : hint_range(0.001, 0.05) = 0.014;
uniform float pulse_speed : hint_range(0.0, 8.0) = 2.4;
uniform float pulse_amount : hint_range(0.0, 0.5) = 0.14;
uniform float front_bias = 0.068;
uniform float shell_bias = 0.018;

void vertex() {
	vec3 base_view = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 view_pos = base_view;
	if (shell) {
		float breathe = 1.0 + sin(TIME * pulse_speed) * (pulse_amount * 0.5);
		float width = outline_width * breathe;
		vec3 model_scale = vec3(
			max(length(MODEL_MATRIX[0].xyz), 0.0001),
			max(length(MODEL_MATRIX[1].xyz), 0.0001),
			max(length(MODEL_MATRIX[2].xyz), 0.0001)
		);
		// Continuous corner expansion for boxes and 3D props, falling back to
		// vertex normals along flat axes (such as thin paper sheets).
		vec3 radial = clamp(VERTEX * 250.0, -1.0, 1.0);
		vec3 dir = mix(NORMAL, radial, step(vec3(0.0015), abs(VERTEX)));
		vec3 local_pos = VERTEX + (dir / model_scale) * (width * 0.65);
		view_pos = (MODELVIEW_MATRIX * vec4(local_pos, 1.0)).xyz;
		vec3 view_center = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		vec2 screen_radial = clamp((view_pos.xy - view_center.xy) * 40.0, -1.0, 1.0);
		float dist_scale = clamp(-base_view.z * 0.55, 0.55, 1.35);
		view_pos.xy += screen_radial * (width * 0.55 * dist_scale);
		// Keep the extruded shell on the same view-space depth plane as the
		// un-extruded surface so Pass 0's front_bias cleanly masks the interior.
		view_pos.z = base_view.z;
	}
	VERTEX = view_pos;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float pulse = 1.0 - pulse_amount * 0.5 + sin(TIME * pulse_speed) * (pulse_amount * 0.5);
	float bias = shell ? shell_bias : front_bias;
	vec3 closer = vec3(VERTEX.xy, VERTEX.z + bias);
	vec4 clip_pos = PROJECTION_MATRIX * vec4(closer, 1.0);
	DEPTH = clip_pos.z / clip_pos.w;
	if (shell) {
		ALBEDO = outline_color.rgb;
		ALPHA = clamp(outline_color.a * pulse, 0.0, 1.0);
	} else {
		float ndotv = abs(dot(normalize(NORMAL), normalize(VIEW)));
		float fresnel = pow(clamp(1.0 - ndotv, 0.0, 1.0), 3.0);
		ALBEDO = rim_color.rgb;
		// Keep a tiny non-zero floor so the alpha pass never discards fragments
		// before writing the interior depth mask.
		ALPHA = max(0.004, rim_color.a * (0.08 + 0.92 * fresnel) * pulse);
	}
}

