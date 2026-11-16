// PS1 water: vertex waves (subdivide the plane!), two affine scrolling texture layers,
// per-vertex lighting and screen-door transparency (no alpha blending).
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled, cull_disabled;

global uniform vec2 ps1_snap_resolution;
global uniform float ps1_jitter_enabled;
global uniform float ps1_affine_enabled;

uniform sampler2D water_tex : source_color, hint_default_white, filter_nearest, repeat_enable;
uniform vec4 color : source_color = vec4(0.25, 0.4, 0.5, 0.75);
uniform vec2 uv_scale = vec2(6.0);
uniform vec2 speed_a = vec2(0.03, 0.01);
uniform vec2 speed_b = vec2(-0.015, 0.025);
uniform float wave_height = 0.06;
uniform float wave_length = 3.0;
uniform float wave_speed = 1.2;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;

instance uniform vec4 ps1_fade = vec4(0.0);

varying vec4 affine_uv;   // two layers: (uv_a * w), (uv_b * w)
varying float affine_w;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = 6.2831 / wave_length;
	VERTEX.y += wave_height * (sin(wp.x * k + TIME * wave_speed) + sin(wp.z * k * 0.8 - TIME * wave_speed * 1.3)) * 0.5;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (ps1_jitter_enabled > 0.5) {
		vec2 grid = ps1_snap_resolution * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
	float w = mix(1.0, clip.w, ps1_affine_enabled);
	vec2 uva = UV * uv_scale + speed_a * TIME;
	vec2 uvb = UV * uv_scale * 0.7 + speed_b * TIME;
	affine_uv = vec4(uva * w, uvb * w);
	affine_w = w;
}

void fragment() {
	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float b = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0;
	if (color.a < b) {
		discard;
	}
	if (ps1_fade.w > 0.0 && 1.0 - smoothstep(ps1_fade.z, ps1_fade.w, length(VERTEX)) < b) {
		discard;
	}
	vec3 ta = texture(water_tex, affine_uv.xy / affine_w).rgb;
	vec3 tb = texture(water_tex, affine_uv.zw / affine_w).rgb;
	ALBEDO = color.rgb * (ta * 0.6 + tb * 0.6);
	EMISSION = emission_color * emission_energy;
}
