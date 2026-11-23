// PS1 sky dome: vertical gradient that melts into the fog color at the horizon, optional
// scrolling cloud texture, procedural stars and a moon. Unlit, unaffected by fog, drawn behind
// everything (the dome follows the camera; see PS1Sky).
shader_type spatial;
render_mode unshaded, fog_disabled, cull_front, depth_draw_never, shadows_disabled;

global uniform vec2 ps1_snap_resolution;
global uniform float ps1_jitter_enabled;

uniform vec4 zenith_color : source_color = vec4(0.02, 0.03, 0.07, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.03, 0.04, 0.05, 1.0);
uniform float horizon_height = 0.25;
uniform sampler2D clouds_tex : source_color, hint_default_black, filter_nearest, repeat_enable;
uniform vec4 clouds_color : source_color = vec4(0.25, 0.27, 0.35, 1.0);
uniform float clouds_scale = 3.0;
uniform vec2 clouds_speed = vec2(0.004, 0.0);
uniform float stars = 0.6;
uniform vec3 moon_direction = vec3(0.4, 0.45, -0.8);
uniform vec4 moon_color : source_color = vec4(0.85, 0.88, 0.95, 1.0);
uniform float moon_size = 0.035;
uniform float moon_halo = 0.0;          // glow ring around the moon (0 = none)
uniform vec3 glow_direction = vec3(1.0, 0.0, 0.0);   // a glowing patch of horizon (fires, a far city)
uniform vec4 glow_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);   // alpha = strength
uniform float glow_spread = 6.0;        // bigger = narrower patch
uniform float glow_height = 0.35;
uniform float flash = 0.0;              // lightning: lights the clouds and the sky for a moment

varying vec3 dir;

float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

void vertex() {
	dir = normalize(VERTEX);
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (ps1_jitter_enabled > 0.5) {
		vec2 grid = ps1_snap_resolution * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	// Godot 4 uses reversed-Z (far plane = 0): pin the dome just in front of it, behind everything.
	clip.z = clip.w * 0.000001;
	POSITION = clip;
}

void fragment() {
	vec3 d = normalize(dir);
	float h = clamp(d.y / max(horizon_height, 0.001), 0.0, 1.0);
	vec3 c = mix(horizon_color.rgb, zenith_color.rgb, h);
	// Stars: a few cells of a coarse direction grid, only high in the sky.
	vec3 cell = floor(d * 90.0);
	float s = step(1.0 - 0.012 * stars, hash3(cell)) * smoothstep(0.15, 0.5, d.y);
	c += vec3(s) * 0.7 * stars;
	// Moon.
	float m = dot(d, normalize(moon_direction));
	// Horizon glow (quantized in 4 bands, PS1-style).
	vec2 gd = normalize(glow_direction.xz + vec2(1e-5));
	float g = pow(max(dot(normalize(d.xz + vec2(1e-5)), gd), 0.0), glow_spread) * (1.0 - smoothstep(0.0, glow_height, d.y)) * smoothstep(-0.12, 0.0, d.y);
	c += glow_color.rgb * floor(g * glow_color.a * 4.0 + 0.5) / 4.0;
	// Moon halo (two hard rings) and the moon.
	float r2 = moon_size * moon_size;
	c += moon_color.rgb * moon_halo * (step(1.0 - r2 * 9.0, m) * 0.12 + step(1.0 - r2 * 3.5, m) * 0.12);
	c = mix(c, moon_color.rgb, step(1.0 - r2, m));
	// Clouds: planar projection of the dome, scrolling.
	vec2 uv = d.xz / max(d.y + 0.15, 0.05) / clouds_scale + clouds_speed * TIME;
	float cl = texture(clouds_tex, uv).r * smoothstep(0.0, 0.35, d.y);
	c = mix(c, clouds_color.rgb, cl * clouds_color.a);
	// Lightning: clouds light up from inside, the whole sky a little.
	c += flash * vec3(0.55, 0.6, 0.78) * (0.3 + cl * 1.5);
	ALBEDO = c;
}
