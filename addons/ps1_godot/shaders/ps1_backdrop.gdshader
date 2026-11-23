// PS1Backdrop silhouettes: far scenery (castles, mountains, cathedral) drawn past the camera's
// far plane, just in front of the sky, flat-shaded and faded into the haze by layer. Fog of the
// scene doesn't touch it: the haze is its own (`haze_color`, `haze`), plus mist at the bottom.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back, shadows_disabled;

global uniform vec2 ps1_snap_resolution;
global uniform float ps1_jitter_enabled;

uniform vec4 color : source_color = vec4(0.08, 0.08, 0.1, 1.0);
uniform vec4 haze_color : source_color = vec4(0.1, 0.12, 0.16, 1.0);
uniform float haze : hint_range(0.0, 1.0) = 0.4;
uniform vec3 light_dir = vec3(0.4, 0.5, -0.7);   // moon: lit faces get a little brighter
uniform float light_amount = 0.35;
uniform vec4 mist_color : source_color = vec4(0.1, 0.12, 0.16, 1.0);
uniform float mist_height = 0.0;     // world Y below which the mist covers it
uniform float mist_fade = 12.0;
uniform float emission = 0.0;        // windows: 1 = full color, untouched by haze/light
uniform float depth_order = 1.0;     // layers: bigger = drawn nearer (in front of others)
uniform float flash = 0.0;           // lightning: far layers wash out toward a pale flash

varying vec3 world_pos;
varying vec3 world_n;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (ps1_jitter_enabled > 0.5) {
		vec2 grid = ps1_snap_resolution * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	// reversed-Z: tiny depth = far away. Behind all scene geometry, in front of the sky (1e-6).
	clip.z = clip.w * (2e-6 + 1e-6 * depth_order);
	POSITION = clip;
}

void fragment() {
	float ndl = max(dot(world_n, normalize(light_dir)), 0.0);
	vec3 c = color.rgb * (1.0 - light_amount + light_amount * 2.0 * ndl);
	c = mix(c, haze_color.rgb, haze);
	float mist = 1.0 - smoothstep(mist_height, mist_height + mist_fade, world_pos.y);
	c = mix(c, mist_color.rgb, mist * 0.85);
	c = mix(c, color.rgb, emission * (1.0 - mist * 0.6));
	c += flash * vec3(0.5, 0.55, 0.72) * (0.14 + haze * 0.6) * (1.0 - emission);
	ALBEDO = c;
}
