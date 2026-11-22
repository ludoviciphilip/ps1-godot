// PS1Aura: a glowing shell around a mesh (charged weapons, buffs, possessed enemies). The copy is
// pushed out along its normals and drawn additive with a rim (fresnel) glow that pulses; color
// cut to 5 bits per channel and vertices snapped to the PS1 grid like everything else.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_add;

global uniform vec2 ps1_snap_resolution;
global uniform float ps1_jitter_enabled;

uniform vec4 color : source_color = vec4(0.6, 0.8, 1.0, 1.0);
uniform float level = 0.0;       // 0 = off, 1 = full aura
uniform float grow = 0.04;       // shell thickness at level 1 (model units)
uniform float pulse = 6.0;       // pulses per second

void vertex() {
	float g = grow * level * (0.85 + 0.15 * sin(TIME * pulse));
	VERTEX += NORMAL * g;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (ps1_jitter_enabled > 0.5) {
		vec2 grid = ps1_snap_resolution * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float a = level * (0.55 + 0.45 * rim) * (0.8 + 0.2 * sin(TIME * pulse * 1.7)) * 1.4;
	vec3 c = floor(color.rgb * a * 31.0 + 0.5) / 31.0;
	if (a < 0.03) { discard; }
	ALBEDO = c;
}
