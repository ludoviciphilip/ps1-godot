// Post-process: reduces color depth (15-bit = 32 levels/channel) with 4x4 Bayer dithering.
shader_type canvas_item;

global uniform float ps1_dither_enabled;
global uniform float ps1_color_levels;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float levels = max(ps1_color_levels - 1.0, 1.0);
	float t = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0 - 0.5;
	c += t / levels * ps1_dither_enabled;
	c = floor(clamp(c, 0.0, 1.0) * levels + 0.5) / levels;
	COLOR = vec4(c, 1.0);
}
