shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_back, blend_mix;

uniform vec4 silhouette_color : source_color = vec4(0.20, 0.88, 0.35, 1.0);
uniform float silhouette_alpha : hint_range(0.0, 1.0, 0.05) = 0.75;
uniform float obstacle_clearance_threshold : hint_range(0.1, 5.0, 0.05) = 1.2;
uniform float fresnel_power : hint_range(0.1, 8.0, 0.1) = 2.5;
uniform bool silhouette_enabled = true;

// Optional spatial mask
uniform float max_radial_distance : hint_range(0.0, 10.0, 0.01) = 0.0; // 0.0 = disabled
uniform float min_height_threshold : hint_range(-10.0, 10.0, 0.01) = -999.0; // -999 = disabled

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

varying float v_mesh_center_depth;
varying float v_mask_discard;

void vertex() {
	v_mask_discard = 0.0;
	if (max_radial_distance > 0.001) {
		if (length(VERTEX.xz) > max_radial_distance) {
			v_mask_discard = 1.0;
		}
	}
	if (min_height_threshold > -990.0) {
		if (VERTEX.y < min_height_threshold) {
			v_mask_discard = 1.0;
		}
	}
	// Reconstruct view-space depth of this mesh's center origin
	vec3 center_in_view = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	v_mesh_center_depth = -center_in_view.z;
}

void fragment() {
	if (v_mask_discard > 0.5 || !silhouette_enabled) {
		discard;
	}
	
	// Sample existing depth buffer at current screen position
	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	
	// In Reverse-Z, raw_depth <= 0.0001 is the background/sky (no occluder)
	if (raw_depth <= 0.0001) {
		discard;
	}
	
	// Reconstruct linear view-space depth for the occluder (scene)
	vec4 scene_ndc = vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	vec4 scene_view = INV_PROJECTION_MATRIX * scene_ndc;
	float scene_depth = -scene_view.z / scene_view.w;
	
	// Fragment linear view-space depth
	float frag_depth = -VERTEX.z;
	
	// Prevent self-x-ray: an occluder must be an external obstacle (e.g. tree, rock)
	// that sits significantly in front of the entire turret's local volume
	bool is_external_obstacle = scene_depth < (v_mesh_center_depth - obstacle_clearance_threshold);
	bool is_behind_surface = frag_depth > (scene_depth + 0.20);
	
	if (is_external_obstacle && is_behind_surface) {
		// Subtle fresnel rim enhancement for crisp readability
		float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
		float rim = pow(1.0 - ndotv, fresnel_power) * 0.25;
		
		ALBEDO = silhouette_color.rgb;
		ALPHA = silhouette_color.a * clamp(silhouette_alpha + rim, 0.0, 1.0);
	} else {
		discard;
	}
}

