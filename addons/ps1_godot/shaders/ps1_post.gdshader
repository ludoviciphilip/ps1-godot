// Post-process: 15-bit color (32 levels/channel) with 4x4 Bayer dithering, optional fixed
// screen palette, and an optional composite-video filter (chroma bleed, line jitter, noise,
// vignette). The filter runs after quantization, like a real TV blurring the console's output,
// which is also why dithering "melts" on a CRT.
shader_type canvas_item;

global uniform float ps1_dither_enabled;
global uniform float ps1_color_levels;
// Optional screen palette (PS1.set_screen_palette): Nx1 texture, ps1_palette_size = N (0 = off).
global uniform sampler2D ps1_palette;
global uniform float ps1_palette_size;
// Composite video filter strength (0 = off, 1 = full). PS1.set_composite().
global uniform float ps1_composite;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

// The console's digital output for one pixel: quantized (or palettized) with dithering.
vec3 console_pixel(vec2 uv, vec2 frag) {
	vec3 c = texture(screen_tex, uv).rgb;
	ivec2 p = ivec2(frag) % 4;
	float t = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0 - 0.5;
	if (ps1_palette_size > 0.5) {
		int n = int(ps1_palette_size);
		c += t * ps1_dither_enabled * 0.3 / pow(ps1_palette_size, 1.0 / 3.0);
		vec3 best = vec3(0.0);
		float bd = 1e9;
		for (int i = 0; i < n; i++) {
			vec3 q = texelFetch(ps1_palette, ivec2(i, 0), 0).rgb;
			vec3 dlt = c - q;
			float d = dot(dlt * vec3(0.3, 0.59, 0.11), dlt);
			if (d < bd) {
				bd = d;
				best = q;
			}
		}
		return best;
	}
	float levels = max(ps1_color_levels - 1.0, 1.0);
	c += t / levels * ps1_dither_enabled;
	return floor(clamp(c, 0.0, 1.0) * levels + 0.5) / levels;
}

const mat3 RGB2YIQ = mat3(vec3(0.299, 0.596, 0.211), vec3(0.587, -0.274, -0.523), vec3(0.114, -0.322, 0.312));
const mat3 YIQ2RGB = mat3(vec3(1.0, 1.0, 1.0), vec3(0.956, -0.272, -1.106), vec3(0.621, -0.647, 1.703));

void fragment() {
	if (ps1_composite <= 0.001) {
		COLOR = vec4(console_pixel(SCREEN_UV, FRAGCOORD.xy), 1.0);
	} else {
		float k = ps1_composite;
		vec2 px = SCREEN_PIXEL_SIZE;
		// Occasional one-pixel horizontal line jitter (unstable sync).
		float line = floor(FRAGCOORD.y);
		float shift = step(1.0 - 0.025 * k, hash(vec2(line, floor(TIME * 24.0)))) * sign(hash(vec2(line, TIME)) - 0.5);
		vec2 uv = SCREEN_UV + vec2(shift * px.x, 0.0);
		vec2 fr = FRAGCOORD.xy + vec2(shift, 0.0);
		// Luma stays sharp; chroma (I/Q) bleeds horizontally over a few pixels.
		vec3 y0 = RGB2YIQ * console_pixel(uv, fr);
		vec3 acc = y0 * 0.34;
		acc += RGB2YIQ * console_pixel(uv - vec2(px.x, 0.0), fr - vec2(1.0, 0.0)) * 0.26;
		acc += RGB2YIQ * console_pixel(uv - vec2(2.0 * px.x, 0.0), fr - vec2(2.0, 0.0)) * 0.16;
		acc += RGB2YIQ * console_pixel(uv + vec2(px.x, 0.0), fr + vec2(1.0, 0.0)) * 0.24;
		vec3 yiq = vec3(mix(y0.x, acc.x, 0.35 * k), mix(y0.yz, acc.yz, k));
		vec3 c = YIQ2RGB * yiq;
		// Grain and a soft vignette.
		c += (hash(FRAGCOORD.xy + fract(TIME) * 61.0) - 0.5) * 0.045 * k;
		vec2 d = SCREEN_UV - 0.5;
		c *= 1.0 - 0.45 * k * dot(d, d);
		COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
	}
}
