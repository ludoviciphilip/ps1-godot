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
	if (t.a < 0.5) {
		discard;
	}
	vec3 c = t.rgb * tint.rgb;
	c = mix(c, haze_color.rgb, haze);
	c += flash * vec3(0.5, 0.55, 0.72) * 0.18 * (1.0 - dot(c, vec3(0.33)));
	ALBEDO = c;
}
