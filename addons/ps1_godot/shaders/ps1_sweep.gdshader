// PS1SweepFX: a flat glowing arc on the ground plane (sword sweeps, spin attacks, area
// telegraphs). An annulus sector whose bright head runs around `head` (radians from +X, CCW
// seen from above) with a tail fading behind it; additive (the PS1 "B+F" blend), color cut to
// 5 bits per channel and the edge stepped on the low-res grid.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_add;

global uniform vec2 ps1_snap_resolution;

uniform vec4 color : source_color = vec4(0.75, 0.85, 1.0, 1.0);
uniform float inner = 0.55;      // inner radius as a fraction of the outer one
uniform float head = 0.0;        // angle of the bright front
uniform float tail = 3.0;        // length of the fading tail (radians)
uniform float start = 0.0;       // nothing is drawn before this angle (the sweep began here)
uniform float swept = 6.3;       // how far the head has gone from `start` (radians)
uniform float dir = 1.0;         // 1 = counter-clockwise, -1 = clockwise
uniform float fade = 1.0;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0 || r < inner) { discard; }
	float ang = atan(-p.y, p.x);   // UV.y grows toward +Z: flip so the angle is CCW from above
	// how far behind the head this pixel is, along the sweep direction
	float behind = mod((head - ang) * dir + 12.566370, 6.283185);
	float since_start = mod((ang - start) * dir + 12.566370, 6.283185);
	if (since_start > swept + 0.02 || behind > tail) { discard; }
	float k = 1.0 - behind / tail;
	float band = 1.0 - abs((r - inner) / (1.0 - inner) * 2.0 - 1.0);   // brightest mid-band
	float a = k * k * (0.35 + 0.65 * band) * fade;
	ivec2 q = ivec2(FRAGCOORD.xy * ps1_snap_resolution.y / VIEWPORT_SIZE.y) % 4;
	float b = (BAYER[q.y * 4 + q.x] + 0.5) / 16.0;
	a = floor(a * 5.0 + b) / 5.0;
	if (a <= 0.0) { discard; }
	vec3 c = floor(color.rgb * a * 31.0 + 0.5) / 31.0;
	ALBEDO = c;
}
