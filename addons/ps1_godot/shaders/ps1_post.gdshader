// Post-process: 15-bit color (32 levels/channel) with 4x4 Bayer dithering, optional fixed
// screen palette, an optional composite-video filter (chroma bleed, line jitter, noise,
// vignette) and an optional CRT pass (PS1.set_crt). The composite filter runs after
// quantization, like a real TV blurring the console's output, which is also why dithering
// "melts" on a CRT.
//
// Normal mode: the window renders at the low base resolution and Godot upscales it.
// CRT mode: the window renders at native resolution (PS1 switches the stretch mode to
// canvas_items); this shader samples it on the low-res grid (`low_res`), so the image is the
// same, and then draws scanlines, an aperture grille and screen curvature at native resolution.
shader_type canvas_item;

global uniform float ps1_dither_enabled;
global uniform float ps1_color_levels;
// Optional screen palette (PS1.set_screen_palette): Nx1 texture, ps1_palette_size = N (0 = off).
global uniform sampler2D ps1_palette;
global uniform float ps1_palette_size;
// Composite video filter strength (0 = off, 1 = full). PS1.set_composite().
global uniform float ps1_composite;
// CRT strength (0 = off). PS1.set_crt().
global uniform float ps1_crt;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
// Low-res grid (the game's canvas size, e.g. 427x240). Set by PS1.
uniform vec2 low_res = vec2(320.0, 240.0);
uniform float crt_curvature = 0.08;
uniform float crt_scanlines = 0.6;
uniform float crt_mask = 0.25;
uniform float crt_brightness = 1.35;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

// The console's digital output for one pixel: quantized (or palettized) with dithering.
// frag = pixel coordinate on the console's (low-res) grid.
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

// Console pixel (+ composite filter) of the low-res cell containing uv. res = grid size.
vec3 tv_signal(vec2 uv, vec2 res) {
	vec2 frag = floor(uv * res) + 0.5;
	vec2 px = 1.0 / res;
	float k = ps1_composite;
	if (k <= 0.001) {
		return console_pixel(frag * px, frag);
	}
	// Occasional one-pixel horizontal line jitter (unstable sync).
	float line = floor(frag.y);
	float shift = step(1.0 - 0.025 * k, hash(vec2(line, floor(TIME * 24.0)))) * sign(hash(vec2(line, TIME)) - 0.5);
	vec2 fr = frag + vec2(shift, 0.0);
	vec2 u = fr * px;
	// Luma stays sharp; chroma (I/Q) bleeds horizontally over a few pixels.
	vec3 y0 = RGB2YIQ * console_pixel(u, fr);
	vec3 acc = y0 * 0.34;
	acc += RGB2YIQ * console_pixel(u - vec2(px.x, 0.0), fr - vec2(1.0, 0.0)) * 0.26;
	acc += RGB2YIQ * console_pixel(u - vec2(2.0 * px.x, 0.0), fr - vec2(2.0, 0.0)) * 0.16;
	acc += RGB2YIQ * console_pixel(u + vec2(px.x, 0.0), fr + vec2(1.0, 0.0)) * 0.24;
	vec3 yiq = vec3(mix(y0.x, acc.x, 0.35 * k), mix(y0.yz, acc.yz, k));
	vec3 c = YIQ2RGB * yiq;
	// Grain and a soft vignette.
	c += (hash(frag + fract(TIME) * 61.0) - 0.5) * 0.045 * k;
	vec2 d = u - 0.5;
	c *= 1.0 - 0.45 * k * dot(d, d);
	return clamp(c, 0.0, 1.0);
}

// One scanline row of the CRT: the beam is a bit soft horizontally.
vec3 crt_row(float x, float row) {
	float xl = floor(x);
	vec3 a = tv_signal((vec2(xl, row) + 0.5) / low_res, low_res);
	vec3 b = tv_signal((vec2(xl + 1.0, row) + 0.5) / low_res, low_res);
	return mix(a, b, smoothstep(0.25, 0.75, fract(x)));
}

void fragment() {
	if (ps1_crt <= 0.001) {
		COLOR = vec4(tv_signal(SCREEN_UV, 1.0 / SCREEN_PIXEL_SIZE), 1.0);
	} else {
		float k = ps1_crt;
		// Barrel curvature; outside the tube is black.
		vec2 d = SCREEN_UV - 0.5;
		float curv = crt_curvature * k;
		vec2 uv = 0.5 + d * (1.0 + curv * dot(d, d)) / (1.0 + curv * 0.25);
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		} else {
			vec2 p = uv * low_res - 0.5;
			float row = floor(p.y);
			float fy = fract(p.y);
			vec3 c0 = crt_row(p.x, row);
			vec3 c1 = crt_row(p.x, row + 1.0);
			// Gaussian beam per row; bright lines get wider (bloom-ish), dark ones thinner.
			float s0 = mix(0.22, 0.40, dot(c0, vec3(0.3, 0.59, 0.11)));
			float s1 = mix(0.22, 0.40, dot(c1, vec3(0.3, 0.59, 0.11)));
			vec3 beam = c0 * exp(-fy * fy / (2.0 * s0 * s0)) + c1 * exp(-(1.0 - fy) * (1.0 - fy) / (2.0 * s1 * s1));
			vec3 flat_ = mix(c0, c1, step(0.5, fy));
			vec3 c = mix(flat_, beam * crt_brightness, crt_scanlines * k);
			// Aperture grille: RGB phosphor stripes on the real screen pixels.
			int m = int(FRAGCOORD.x) % 3;
			vec3 mk = vec3(m == 0 ? 1.15 : 0.8, m == 1 ? 1.15 : 0.8, m == 2 ? 1.15 : 0.8);
			c *= mix(vec3(1.0), mk, crt_mask * k);
			// Edges of the tube fade out, plus a soft vignette.
			vec2 e = smoothstep(vec2(0.0), vec2(0.012), uv) * smoothstep(vec2(0.0), vec2(0.012), 1.0 - uv);
			c *= e.x * e.y * (1.0 - 0.3 * k * dot(d, d));
			COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
		}
	}
}
