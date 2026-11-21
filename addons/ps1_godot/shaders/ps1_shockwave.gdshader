// Ground ring of a PS1Shockwave: dusty band at the edge of a disc, dithered on the low-res grid.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_mix;

global uniform vec2 ps1_snap_resolution;

uniform vec4 color : source_color = vec4(0.62, 0.56, 0.46, 1.0);
uniform float thickness = 0.2;   // band width as a fraction of the radius
uniform float fade = 1.0;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float rough = 0.08 * (hash(vec2(floor(ang * 12.0), 3.0)) - 0.5);   // ragged front
	float band = smoothstep(1.0 - thickness, 1.0 - thickness * 0.4, r + rough) * (1.0 - smoothstep(0.96, 1.0, r + rough));
	float inner = smoothstep(0.35, 1.0 - thickness, r) * 0.12;   // a little dust left behind the front
	float a = (band * 0.7 + inner) * fade;
	ivec2 q = ivec2(FRAGCOORD.xy * ps1_snap_resolution.y / VIEWPORT_SIZE.y) % 4;
	float b = (BAYER[q.y * 4 + q.x] + 0.5) / 16.0;
	a = floor(a * 4.0 + b) / 4.0;
	if (a <= 0.0) discard;
	ALPHA = a;
	ALBEDO = color.rgb * (0.85 + 0.3 * band);
}
