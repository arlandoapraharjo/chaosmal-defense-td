shader_type spatial;
render_mode depth_draw_opaque, cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float sway_speed = 2.0;
uniform float sway_strength = 0.15;

void vertex() {
	// World position for phase variation per tree instance
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world_pos.x * 0.4 + world_pos.z * 0.4;
	
	// Since we are only applying this to the leaves, the whole leaf cluster can sway
	float height_factor = 1.0;
	
	// Smooth sine wave swaying along X and Z
	float sway_x = sin(TIME * sway_speed + phase) * sway_strength * height_factor * 0.1;
	float sway_z = cos(TIME * sway_speed * 0.85 + phase + 1.2) * sway_strength * height_factor * 0.08;
	
	VERTEX.x += sway_x;
	VERTEX.z += sway_z;
}

void fragment() {
	// Invert normal for back-facing polygons so two-sided leaf quads calculate lighting correctly
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	
	vec4 tex_color = texture(albedo_texture, UV);
	vec4 final_color = tex_color * albedo_color;
	ALBEDO = final_color.rgb;
	ALPHA = final_color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.6;
	SPECULAR = 0.1;
}
