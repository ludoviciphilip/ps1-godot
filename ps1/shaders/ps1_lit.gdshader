// Material base PS1: vertex snapping (jitter), texturas affine, iluminação por vértice,
// filtragem nearest sem mipmaps. Parâmetros globais em Project Settings > Shader Globals.
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled, cull_back;

global uniform vec2 ps1_snap_resolution;
global uniform float ps1_jitter_enabled;
global uniform float ps1_affine_enabled;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;

// (uv * w, w): dividir no fragment desfaz a correção de perspectiva -> mapeamento affine.
varying vec3 affine_uv;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (ps1_jitter_enabled > 0.5) {
		vec2 grid = ps1_snap_resolution * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
	float w = mix(1.0, clip.w, ps1_affine_enabled);
	affine_uv = vec3(UV * uv_scale * w, w);
}

void fragment() {
	vec2 uv = affine_uv.xy / affine_uv.z;
	vec4 tex = texture(albedo_tex, uv);
	ALBEDO = tex.rgb * albedo_color.rgb;
	EMISSION = emission_color * emission_energy;
}
