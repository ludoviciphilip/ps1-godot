// PS1Mist: soft animated mist (fog walls, fog banks, waterfalls of mist).
// PS1-style: the noise is sampled on the low-res pixel grid and its brightness/opacity move in a
// few steps (like the console's 50% semi-transparency + dithering), so it reads as mist, not as a
// see-through grid. Dither cells follow the low-res grid also when the screen renders at native
// resolution (CRT on).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_mix;

global uniform vec2 ps1_snap_resolution;
global uniform float ps1_dither_enabled;

uniform vec4 color : source_color = vec4(0.82, 0.86, 0.95, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.7;
uniform vec2 noise_scale = vec2(4.0, 3.0);
uniform vec2 flow = vec2(0.2, 0.45);
uniform float edge_fade : hint_range(0.0, 0.5) = 0.18;
uniform float steps = 5.0;
uniform float layer_offset = 0.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float soft_contact = 0.6;   // fades where the mist meets walls/floor (meters)

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float t = TIME + layer_offset * 7.3;
	vec2 uv = UV * noise_scale + vec2(layer_offset * 3.1, layer_offset * 1.7);
	float n = vnoise(uv + flow * t) * 0.55 + vnoise(uv * 2.1 - vec2(0.0, flow.y * 1.4 * t)) * 0.3
		+ vnoise(uv * 4.3 + vec2(flow.x * 2.0 * t, 0.0)) * 0.15;
	// soft borders so the slab has no hard rectangle edges
	vec2 e = min(UV, 1.0 - UV);
	float edge = smoothstep(0.0, edge_fade, e.x) * smoothstep(0.0, edge_fade * 1.8, UV.y) * smoothstep(0.0, edge_fade * 0.5, 1.0 - UV.y);
	// wisps: strong contrast between thick and thin mist
	float a = density * edge * smoothstep(0.22, 0.78, n);
	// soft contact with geometry behind it
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_z = -vp.z / vp.w;
	a *= clamp((scene_z + VERTEX.z) / max(soft_contact, 0.001), 0.0, 1.0);
	// low-res grid dither, then a few opacity steps
	float b = 0.5;
	if (ps1_dither_enabled > 0.5) {
		ivec2 p = ivec2(FRAGCOORD.xy * ps1_snap_resolution.y / VIEWPORT_SIZE.y) % 4;
		b = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0;
	}
	a = floor(a * steps + b) / steps;
	ALPHA = clamp(a, 0.0, 1.0);
	ALBEDO = color.rgb * (0.55 + 0.6 * n);
}
