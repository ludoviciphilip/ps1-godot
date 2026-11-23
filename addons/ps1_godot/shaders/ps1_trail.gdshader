// PS1BladeTrail: the swept ribbon behind a weapon. UV.x = age along the trail (0 = the blade
// now, 1 = oldest), UV.y = across the blade (0 = hilt side, ~0.86 = the edge, 1 = outer glow).
// Additive like the PS1's B+F blend; a white-hot edge line, the colored body fading toward the
// hilt and with age, streaks running along the swing, alpha in 5 dithered steps on the low-res
// grid and color cut to 5 bits per channel.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_add;

global uniform vec2 ps1_snap_resolution;
global uniform float ps1_jitter_enabled;

uniform vec4 color : source_color = vec4(0.45, 0.6, 0.95, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform float intensity = 1.0;
uniform float edge = 0.86;          // where the blade's edge line runs across the ribbon
uniform float streaks = 0.5;        // 0 = smooth, 1 = strong wind streaks
uniform float seed = 0.0;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float hash(float n) { return fract(sin(n * 12.9898 + seed * 78.233) * 43758.5453); }

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (ps1_jitter_enabled > 0.5) {
		vec2 grid = ps1_snap_resolution * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	float x = UV.x;
	float y = UV.y;
	float young = 1.0 - x;
	// body: grows from the hilt to the edge, then a short glow past it
	float body = (0.25 + 0.75 * smoothstep(0.0, edge, y)) * smoothstep(0.0, 0.12, y) * (1.0 - smoothstep(edge, 1.0, y));
	// the edge line: thin, white-hot, longer-lived than the body
	float core = exp(-pow((y - edge) / 0.045, 2.0)) * pow(young, 0.6);
	// streaks: bands across the ribbon, broken along it (like air torn by the blade)
	float band = floor(y * 11.0);
	float r = hash(band);
	float s = step(0.35, fract(x * (2.0 + r * 3.0) + r * 7.0));
	float streak = mix(1.0, 0.45 + 0.75 * s * (0.6 + 0.4 * r), streaks);
	float a = body * pow(young, 1.15) * streak * 1.35 + core * 1.2;
	a *= intensity;
	ivec2 q = ivec2(FRAGCOORD.xy * ps1_snap_resolution.y / VIEWPORT_SIZE.y) % 4;
	float b = (BAYER[q.y * 4 + q.x] + 0.5) / 16.0;
	float steps = floor(min(a, 1.6) * 5.0 + b) / 5.0;
	if (steps <= 0.0) { discard; }
	vec3 c = mix(color.rgb, core_color.rgb, clamp(core * 1.3 + young * 0.15, 0.0, 1.0));
	c = floor(c * steps * 31.0 + 0.5) / 31.0;
	ALBEDO = c;
}
