// PS1 particles (used by PS1Particles through a MultiMesh). Every quad faces the camera, its
// vertices snap to the PS1 grid, the color is cut to 15-bit (5 bits per channel) and alpha is
// either dithered ("screen-door") or additive (the PS1 "B+F" semi-transparency, for fire/glows).
// Per instance: COLOR = color + alpha, INSTANCE_CUSTOM.x = sprite-sheet frame.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
#define ADDITIVE

global uniform vec2 ps1_snap_resolution;
global uniform float ps1_jitter_enabled;

uniform sampler2D tex : source_color, hint_default_white, filter_nearest;
uniform float hframes = 1.0;
uniform float color_bits = 5.0;

varying vec4 col;
varying float frame;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	vec4 center = VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0);
	vec4 clip = PROJECTION_MATRIX * (center + vec4(VERTEX.xy * s, 0.0, 0.0));
	if (ps1_jitter_enabled > 0.5) {
		vec2 grid = ps1_snap_resolution * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
	col = COLOR;
	frame = INSTANCE_CUSTOM.x;
}

void fragment() {
	vec2 uv = vec2((UV.x + floor(frame + 0.5)) / hframes, UV.y);
	vec4 t = texture(tex, uv);
	float levels = exp2(color_bits) - 1.0;
	vec3 c = floor(t.rgb * col.rgb * levels + 0.5) / levels;
	float a = t.a * col.a;
	ivec2 p = ivec2(FRAGCOORD.xy * ps1_snap_resolution.y / VIEWPORT_SIZE.y) % 4;
	float b = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0;
#ifdef ADDITIVE
	if (a < 0.02) { discard; }
	ALBEDO = c * a;
#else
	if (a < b) { discard; }
	ALBEDO = c;
#endif
}
