shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 5.0) = 2.0;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

void fragment() {
	vec2 ps = SCREEN_PIXEL_SIZE * blur_amount;
	vec4 color = vec4(0.0);

	// 9-tap gaussian blur (3x3 kernel)
	color += texture(screen_texture, SCREEN_UV + vec2(-1.0, -1.0) * ps) * 0.0625;
	color += texture(screen_texture, SCREEN_UV + vec2(0.0, -1.0) * ps) * 0.125;
	color += texture(screen_texture, SCREEN_UV + vec2(1.0, -1.0) * ps) * 0.0625;
	color += texture(screen_texture, SCREEN_UV + vec2(-1.0, 0.0) * ps) * 0.125;
	color += texture(screen_texture, SCREEN_UV) * 0.25;
	color += texture(screen_texture, SCREEN_UV + vec2(1.0, 0.0) * ps) * 0.125;
	color += texture(screen_texture, SCREEN_UV + vec2(-1.0, 1.0) * ps) * 0.0625;
	color += texture(screen_texture, SCREEN_UV + vec2(0.0, 1.0) * ps) * 0.125;
	color += texture(screen_texture, SCREEN_UV + vec2(1.0, 1.0) * ps) * 0.0625;

	COLOR = color;
	COLOR.a = 1.0;
}
