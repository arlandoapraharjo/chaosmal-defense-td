shader_type canvas_item;

uniform vec4 bg_color_top : source_color = vec4(0.12, 0.10, 0.17, 0.94);
uniform vec4 bg_color_bottom : source_color = vec4(0.07, 0.06, 0.10, 0.97);
uniform vec4 border_color : source_color = vec4(0.96, 0.78, 0.36, 0.90);
uniform vec4 border_color_dim : source_color = vec4(0.40, 0.32, 0.22, 0.50);
uniform float corner_radius : hint_range(0.0, 0.2) = 0.035;
uniform float border_width : hint_range(0.0, 0.05) = 0.004;
uniform float inner_glow : hint_range(0.0, 1.0) = 0.25;

float rounded_box_sdf(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	vec2 half_size = vec2(0.5, 0.5);
	
	float dist = rounded_box_sdf(p, half_size, corner_radius);
	
	// Antialiased outer clipping
	float alpha = 1.0 - smoothstep(0.0, 0.004, dist);
	if (alpha <= 0.0) {
		discard;
	}
	
	// Vertical gradient
	vec4 bg = mix(bg_color_top, bg_color_bottom, UV.y);
	
	// Subtle top ambient gloss
	float gloss = smoothstep(0.18, 0.0, UV.y) * 0.08;
	bg.rgb += vec3(gloss);
	
	// Golden border highlight (brighter at the top, softer towards the bottom)
	float border_mask = smoothstep(-border_width, 0.0, dist);
	vec4 current_border = mix(border_color, border_color_dim, UV.y * 0.75);
	
	// Inner border warm ambient glow
	float inner_glow_mask = smoothstep(-0.04, 0.0, dist) * (1.0 - border_mask) * inner_glow;
	bg.rgb = mix(bg.rgb, border_color.rgb, inner_glow_mask * 0.35);
	
	vec4 final_color = mix(bg, current_border, border_mask);
	final_color.a *= alpha;
	
	COLOR = final_color;
}
