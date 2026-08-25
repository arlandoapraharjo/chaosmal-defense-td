shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.07, 0.09, 0.14, 0.90);
uniform vec4 bg_gradient_color : source_color = vec4(0.12, 0.16, 0.24, 0.95);
uniform vec4 border_color : source_color = vec4(0.35, 0.65, 0.95, 0.90);
uniform float slant_amount : hint_range(0.0, 0.5) = 0.18;
uniform float border_width : hint_range(0.0, 0.05) = 0.006;
uniform float gloss_intensity : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	// Calculate slanted right boundary: top at 1.0, bottom at (1.0 - slant_amount)
	float right_edge = 1.0 - UV.y * slant_amount;
	float dist_to_edge = right_edge - UV.x;

	if (dist_to_edge < 0.0) {
		discard;
	}

	// Antialiased outer edge alpha cutoff
	float edge_alpha = smoothstep(0.0, 0.003, dist_to_edge);

	// Vertical gradient background
	vec4 base_bg = mix(bg_color, bg_gradient_color, UV.y);

	// Subtle top gloss line
	float gloss = smoothstep(0.15, 0.0, UV.y) * gloss_intensity;
	base_bg.rgb += vec3(gloss);

	// Right border highlight
	float border_mask = 1.0 - smoothstep(0.0, border_width, dist_to_edge);

	vec4 final_color = mix(base_bg, border_color, border_mask);
	final_color.a *= edge_alpha;

	COLOR = final_color;
}
