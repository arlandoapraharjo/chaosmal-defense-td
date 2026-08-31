shader_type canvas_item;

uniform vec4 gem_color_top : source_color = vec4(0.88, 0.60, 1.0, 1.0);
uniform vec4 gem_color_bottom : source_color = vec4(0.48, 0.18, 0.85, 1.0);
uniform vec4 glow_accent : source_color = vec4(1.0, 0.84, 0.42, 1.0);
uniform float pulse_speed : hint_range(0.0, 5.0) = 2.0;

void fragment() {
	vec2 p = UV - vec2(0.5);
	// Diamond SDF
	float d = abs(p.x) * 1.35 + abs(p.y) * 1.0;
	
	float alpha = 1.0 - smoothstep(0.40, 0.42, d);
	if (alpha <= 0.0) {
		discard;
	}
	
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
	
	// Left/Right subtle facet split
	float facet = (p.x > 0.0 ? 0.12 : -0.08) + (p.y > 0.0 ? -0.06 : 0.14);
	
	vec4 col = mix(gem_color_top, gem_color_bottom, clamp(UV.y * 1.1 + facet, 0.0, 1.0));
	
	// Center sparkle glow
	float core = 1.0 - smoothstep(0.0, 0.22, length(p));
	col.rgb += glow_accent.rgb * (core * 0.45 + pulse * 0.12);
	
	// Outline rim
	float rim = smoothstep(0.36, 0.41, d);
	col = mix(col, glow_accent, rim * 0.75);
	col.a *= alpha;
	
	COLOR = col;
}
