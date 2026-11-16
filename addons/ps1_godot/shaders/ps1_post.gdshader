// Post-process: reduces color depth (15-bit = 32 levels/channel) with 4x4 Bayer dithering.
shader_type canvas_item;

global uniform float ps1_dither_enabled;
global uniform float ps1_color_levels;
// Optional screen palette (PS1.set_screen_palette): Nx1 texture, ps1_palette_size = N (0 = off).
global uniform sampler2D ps1_palette;
global uniform float ps1_palette_size;

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
	if (ps1_palette_size > 0.5) {
		// Nearest palette color (with ordered dithering, scaled to the palette's spacing).
		int n = int(ps1_palette_size);
		c += t * ps1_dither_enabled * 0.3 / pow(ps1_palette_size, 1.0 / 3.0);
		vec3 best = vec3(0.0);
		float bd = 1e9;
		for (int i = 0; i < n; i++) {
			vec3 p = texelFetch(ps1_palette, ivec2(i, 0), 0).rgb;
			vec3 dlt = c - p;
			float d = dot(dlt * vec3(0.3, 0.59, 0.11), dlt);
			if (d < bd) {
				bd = d;
				best = p;
			}
		}
		COLOR = vec4(best, 1.0);
	} else {
		c += t / levels * ps1_dither_enabled;
		c = floor(clamp(c, 0.0, 1.0) * levels + 0.5) / levels;
		COLOR = vec4(c, 1.0);
	}
}
