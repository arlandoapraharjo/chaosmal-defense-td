shader_type spatial;
render_mode cull_front, unshaded;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 20.0, 0.1) = 3.2;
uniform float smooth_weld_weight : hint_range(0.0, 1.0, 0.05) = 0.65;
uniform float emission_boost : hint_range(0.0, 2.0, 0.05) = 0.25;

// Optional spatial mask (e.g. outline only hole structure on a combined tile)
uniform float max_radial_distance : hint_range(0.0, 10.0, 0.01) = 0.0; // 0.0 = disabled
uniform float min_height_threshold : hint_range(-10.0, 10.0, 0.01) = -999.0; // -999 = disabled

varying float v_mask_discard;

// Hand-Drawn "Line Boil" controls
uniform bool squiggly_enabled = false;
uniform float squiggly_intensity : hint_range(0.0, 2.0, 0.05) = 0.40;
uniform float squiggly_frequency : hint_range(1.0, 50.0, 0.5) = 10.0;
uniform float squiggly_speed : hint_range(0.0, 20.0, 0.5) = 6.0;
uniform float squiggly_fps : hint_range(0.0, 30.0, 1.0) = 8.0;
uniform float squiggly_jitter_amount : hint_range(0.0, 5.0, 0.1) = 0.8;

// Deterministic pseudo-random 2D hash for stop-motion jitter
vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return (fract((p3.xx + p3.yz) * p3.zy) * 2.0 - 1.0);
}

void vertex() {
	vec4 clip_position = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	
	// 1. Normal-based direction in view/clip space
	vec3 view_normal = mat3(MODELVIEW_MATRIX) * NORMAL;
	vec2 clip_normal = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	if (length(clip_normal) > 0.0001) {
		clip_normal = normalize(clip_normal);
	} else {
		clip_normal = vec2(0.0, 1.0);
	}

	// 2. Continuous position-based radial direction for welding coincident vertices at hard corners
	vec3 local_radial = (length(VERTEX) > 0.0001) ? normalize(VERTEX) : NORMAL;
	vec3 view_radial = mat3(MODELVIEW_MATRIX) * local_radial;
	vec2 clip_radial = (PROJECTION_MATRIX * vec4(view_radial, 0.0)).xy;
	if (length(clip_radial) > 0.0001) {
		clip_radial = normalize(clip_radial);
	} else {
		clip_radial = clip_normal;
	}
	
	// Blend between normal and radial weld to close disconnected face cracks seamlessly
	vec2 final_dir = normalize(mix(clip_normal, clip_radial, smooth_weld_weight));
	
	// 3. Hand-drawn Line Boil (Stop-motion stepped jitter + dynamic width + tangential wiggle)
	float current_width = outline_width;
	
	v_mask_discard = 0.0;
	if (max_radial_distance > 0.001) {
		if (length(VERTEX.xz) > max_radial_distance) {
			v_mask_discard = 1.0;
			current_width = 0.0;
		}
	}
	if (min_height_threshold > -990.0) {
		if (VERTEX.y < min_height_threshold) {
			v_mask_discard = 1.0;
			current_width = 0.0;
		}
	}
	
	if (squiggly_enabled) {
		float frame_id = (squiggly_fps > 0.0) ? floor(TIME * squiggly_fps) : (TIME * squiggly_speed);
		
		// Spatial harmonic waves linked to stepped frame time for continuous edge stability
		vec3 p = VERTEX * squiggly_frequency;
		float n1 = sin(p.y + frame_id * 1.732 + cos(p.x * 0.7 + frame_id * 2.113));
		float n2 = cos(p.x + p.z + frame_id * 2.414 + sin(p.y * 0.8 + frame_id * 1.317));
		float n3 = sin(p.z - p.x * 0.5 + frame_id * 3.141);
		float boil_val = (n1 * 0.50 + n2 * 0.35 + n3 * 0.15) * squiggly_intensity;
		
		// Modulate stroke width (thickness variance per line segment)
		current_width = max(0.5, outline_width * (1.0 + boil_val * 0.35));
		
		// Tangential displacement (lines wobble along their length)
		vec2 tangent_dir = vec2(-final_dir.y, final_dir.x);
		float tangent_wave = cos(p.y * 1.2 - p.x + frame_id * 2.718) * (squiggly_intensity * 0.25);
		
		// Frame-wide subtle hand tremor jitter
		vec2 frame_jitter = hash22(vec2(frame_id, frame_id * 0.37)) * (squiggly_jitter_amount * 0.15);
		
		// Blend tangential and normal components
		final_dir = normalize(final_dir + tangent_dir * tangent_wave + frame_jitter);
	}
	
	// Pixel-perfect screen-space offset
	vec2 offset = final_dir / VIEWPORT_SIZE * clip_position.w * current_width * 2.0;
	clip_position.xy += offset;
	
	// In Reverse-Z (Godot 4 Forward+), pushing Z back guarantees it NEVER overlaps the front faces
	clip_position.z -= 0.0004 * clip_position.w;
	
	POSITION = clip_position;
}

void fragment() {
	if (v_mask_discard > 0.5) {
		discard;
	}
	// Clean comic ink with subtle emission for high contrast
	ALBEDO = outline_color.rgb * (1.0 + emission_boost);
	if (outline_color.a < 1.0) {
		ALPHA = outline_color.a;
	}
}
