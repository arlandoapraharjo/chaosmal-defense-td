shader_type spatial;
render_mode cull_front, unshaded;

uniform vec4 outline_color : source_color = vec4(0.15, 0.85, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 20.0, 0.1) = 6.0;
uniform float smooth_weld_weight : hint_range(0.0, 1.0, 0.05) = 1.0;

// Squiggly animated hand-drawn effect controls
uniform bool squiggly_enabled = false;
uniform float squiggly_intensity : hint_range(0.0, 1.0, 0.05) = 0.35;
uniform float squiggly_frequency : hint_range(1.0, 30.0, 0.5) = 8.0;
uniform float squiggly_speed : hint_range(0.0, 20.0, 0.5) = 6.0;
uniform float squiggly_fps : hint_range(0.0, 30.0, 1.0) = 10.0; // 0 = smooth, >0 = stop-motion hand-drawn boil

void vertex() {
	vec4 clip_position = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	
	// 1. Normal-based direction in view/clip space
	vec3 view_normal = normalize(mat3(MODELVIEW_MATRIX) * NORMAL);
	vec2 clip_normal = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	if (length(clip_normal) > 0.0001) {
		clip_normal = normalize(clip_normal);
	}
	
	// 2. Continuous position-based direction (identical for all coincident vertices sharing hard edges)
	// Extruding along VERTEX ensures adjacent flat-shaded faces stay completely welded with zero disconnected gaps
	vec3 local_dir = (length(VERTEX) > 0.0001) ? normalize(VERTEX) : NORMAL;
	vec3 view_dir = normalize(mat3(MODELVIEW_MATRIX) * local_dir);
	vec2 clip_dir = (PROJECTION_MATRIX * vec4(view_dir, 0.0)).xy;
	if (length(clip_dir) > 0.0001) {
		clip_dir = normalize(clip_dir);
	} else {
		clip_dir = clip_normal;
	}
	
	// Blend: 1.0 = completely seamless crack-free hull
	vec2 final_dir = normalize(mix(clip_normal, clip_dir, smooth_weld_weight));
	
	// 3. Squiggly hand-drawn width & position modulation
	float current_width = outline_width;
	if (squiggly_enabled) {
		float anim_time = (squiggly_fps > 0.0) ? (floor(TIME * squiggly_fps) / squiggly_fps) : TIME;
		float wave1 = sin(VERTEX.y * squiggly_frequency + anim_time * squiggly_speed);
		float wave2 = cos((VERTEX.x + VERTEX.z) * (squiggly_frequency * 1.35) - anim_time * (squiggly_speed * 1.15));
		float wave3 = sin((VERTEX.x - VERTEX.z + VERTEX.y) * (squiggly_frequency * 0.75) + anim_time * (squiggly_speed * 0.85));
		float squiggle = (wave1 * 0.50 + wave2 * 0.30 + wave3 * 0.20) * squiggly_intensity;
		current_width = max(1.0, outline_width * (1.0 + squiggle));
	}
	
	vec2 offset = final_dir / VIEWPORT_SIZE * clip_position.w * current_width * 2.0;
	clip_position.xy += offset;
	
	POSITION = clip_position;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	if (outline_color.a < 1.0) {
		ALPHA = outline_color.a;
	}
}
