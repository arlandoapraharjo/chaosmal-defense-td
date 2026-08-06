shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float desaturation : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tint_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);

void fragment() {
	vec4 color = texture(SCREEN_TEXTURE, SCREEN_UV);
	float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	
	// Create a washed out grayscale look
	vec3 washed_out = mix(vec3(gray), tint_color.rgb * gray, 0.5);
	
	COLOR.rgb = mix(color.rgb, washed_out, desaturation);
}
