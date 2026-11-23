// PS1Backdrop image panorama: a painted/rendered landscape on a band around the horizon, drawn
// past the far plane like the other far layers. The sky in the picture is cut out (alpha), so
// the live PS1Sky (moon, clouds, horizon glow, lightning) shows above the land.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, shadows_disabled;

global uniform vec2 ps1_snap_resolution;
global uniform float ps1_jitter_enabled;

uniform sampler2D tex : source_color, filter_nearest, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 haze_color : source_color = vec4(0.1, 0.12, 0.16, 1.0);
uniform float haze : hint_range(0.0, 1.0) = 0.0;
uniform float depth_order = 1.0;
uniform float flash = 0.0;
// soft edges: the picture fades out (PS1 screen-door dither) over this fraction of its width at
// the sides and of its height at the bottom, so it melts into the mist/ridges instead of
// reading as a framed rectangle
uniform float side_fade = 0.12;
uniform float bottom_fade = 0.25;
// drifting fog banks eating the lower part of the picture (PS1Backdrop.fog_panorama): denser at
// the bottom, broken into slow-moving patches, in 4 dithered steps on the low-res grid
uniform vec4 fog_color : source_color = vec4(0.32, 0.34, 0.4, 1.0);
uniform float fog_amount = 0.0;       // 0 = off, 1 = the bottom is fully swallowed
uniform float fog_height = 0.55;      // how far up the picture (0..1 of its height) the fog reaches
uniform float fog_patchy = 0.6;       // 0 = smooth gradient, 1 = broken banks
uniform float fog_scale = 6.0;        // bank size: patches across the picture's height
uniform float fog_drift = 0.012;      // horizontal drift (picture widths per second)
uniform float fog_aspect = 2.0;       // picture width / height (set by fog_panorama)

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (ps1_jitter_enabled > 0.5) {
		vec2 grid = ps1_snap_resolution * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	clip.z = clip.w * (2e-6 + 1e-6 * depth_order);
	POSITION = clip;
}

void fragment() {
	vec4 t = texture(tex, UV);
	float f = smoothstep(0.0, side_fade, UV.x) * smoothstep(0.0, side_fade, 1.0 - UV.x) * smoothstep(0.0, bottom_fade, 1.0 - UV.y);
	ivec2 q = ivec2(FRAGCOORD.xy * ps1_snap_resolution.y / VIEWPORT_SIZE.y) % 4;
	const float B[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	float bayer = (B[q.y * 4 + q.x] + 0.5) / 16.0;
	if (t.a < 0.5 || f < bayer) {
		discard;
	}
	vec3 c = t.rgb * tint.rgb;
	c = mix(c, haze_color.rgb, haze);
	if (fog_amount > 0.0) {
		float up = 1.0 - UV.y;   // 0 = bottom of the picture
		float base = 1.0 - smoothstep(0.0, fog_height, up);
		vec2 p = vec2(UV.x * fog_aspect, UV.y) * fog_scale;
		float n = vnoise(p * vec2(0.5, 1.0) + vec2(TIME * fog_drift * fog_scale * fog_aspect, 0.0)) * 0.65
			+ vnoise(p * vec2(1.1, 2.2) - vec2(TIME * fog_drift * 1.7 * fog_scale * fog_aspect, 0.0)) * 0.35;
		float d = base + (n - 0.5) * fog_patchy * (0.4 + base);
		d = clamp(d, 0.0, 1.0) * fog_amount;
		d = floor(d * 4.0 + bayer) / 4.0;
		vec3 fc = fog_color.rgb + flash * vec3(0.3, 0.33, 0.45) * 0.35;
		c = mix(c, fc, clamp(d, 0.0, 1.0));
	}
	c += flash * vec3(0.5, 0.55, 0.72) * 0.18 * (1.0 - dot(c, vec3(0.33)));
	ALBEDO = c;
}
