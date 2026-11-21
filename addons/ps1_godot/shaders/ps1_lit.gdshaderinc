// Shared body of all PS1 materials. Variants set render_mode and optional defines:
//   PS1_CUTOUT        alpha test (fences, foliage)       uniform alpha_cut
//   PS1_DITHER_ALPHA  "screen-door" transparency (no blending, like the PS1)
//   PS1_UNLIT         pre-lit: color = texture * vertex color * 2 (see PS1Bake), or just the
//                     texture when use_vertex_color is off (sprites, effects)
//   PS1_BILLBOARD     the quad always faces the camera (sprites, particles)
//   PS1_BILLBOARD_Y   faces the camera turning only around Y (trees, characters as sprites)
global uniform vec2 ps1_snap_resolution;
global uniform float ps1_jitter_enabled;
global uniform float ps1_affine_enabled;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_nearest, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
// Per-channel levels applied to the texture color (0 = off). For real palettes use PS1Palette.
uniform float texture_color_levels = 0.0;
// Multiply by the mesh vertex colors (unlit variants: baked light, 2x modulation).
uniform bool use_vertex_color = false;
#ifdef PS1_CUTOUT
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
#endif

// Per-instance UV rectangle (scale.xy, offset.zw): sprite-sheet frames. Set by PS1Sprite.
instance uniform vec4 ps1_uv_rect = vec4(1.0, 1.0, 0.0, 0.0);
// Per-instance flash (hit feedback): rgb = color, a = amount. Set with PS1.flash().
instance uniform vec4 ps1_flash = vec4(0.0);
// Per-instance dithered distance fade: xy = fade-in range, zw = fade-out range (0 = off).
// Set by PS1LOD / PS1.draw_distance(). In and out use complementary dither patterns,
// so two LOD levels cross-fade without holes or overlap.
instance uniform vec4 ps1_fade = vec4(0.0);

// (uv * w, w): dividing in fragment() undoes perspective correction -> affine mapping.
varying vec3 affine_uv;

const float PS1_BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

float ps1_bayer(vec2 frag) {
	ivec2 p = ivec2(frag) % 4;
	return (PS1_BAYER[p.y * 4 + p.x] + 0.5) / 16.0;
}

void vertex() {
	mat4 mv = MODELVIEW_MATRIX;
#if defined(PS1_BILLBOARD) || defined(PS1_BILLBOARD_Y)
	vec3 scl = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
#ifdef PS1_BILLBOARD
	mat4 bb = mat4(INV_VIEW_MATRIX[0] * scl.x, INV_VIEW_MATRIX[1] * scl.y, INV_VIEW_MATRIX[2] * scl.z, MODEL_MATRIX[3]);
#else
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 back = vec3(-right.z, 0.0, right.x);
	mat4 bb = mat4(vec4(right * scl.x, 0.0), vec4(0.0, scl.y, 0.0, 0.0), vec4(back * scl.z, 0.0), MODEL_MATRIX[3]);
#endif
	mv = VIEW_MATRIX * bb;
	MODELVIEW_MATRIX = mv;
	NORMAL = vec3(0.0, 0.0, 1.0);
	MODELVIEW_NORMAL_MATRIX = mat3(1.0);
#endif
	vec4 clip = PROJECTION_MATRIX * mv * vec4(VERTEX, 1.0);
	if (ps1_jitter_enabled > 0.5) {
		vec2 grid = ps1_snap_resolution * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
	float w = mix(1.0, clip.w, ps1_affine_enabled);
	affine_uv = vec3((UV * ps1_uv_rect.xy + ps1_uv_rect.zw) * uv_scale * w, w);
}

void fragment() {
	// Dither cell = one low-res pixel, also when the screen renders at native resolution (CRT).
	float b = ps1_bayer(FRAGCOORD.xy * ps1_snap_resolution.y / VIEWPORT_SIZE.y);
	if (ps1_fade.y > 0.0 || ps1_fade.w > 0.0) {
		float d = length(VERTEX);
		if (ps1_fade.y > 0.0 && smoothstep(ps1_fade.x, ps1_fade.y, d) <= 1.0 - b) {
			discard;
		}
		if (ps1_fade.w > 0.0 && 1.0 - smoothstep(ps1_fade.z, ps1_fade.w, d) < b) {
			discard;
		}
	}
	vec2 uv = affine_uv.xy / affine_uv.z;
	vec4 tex = texture(albedo_tex, uv);
	vec3 c = tex.rgb;
	if (texture_color_levels > 1.5) {
		float l = texture_color_levels - 1.0;
		c = floor(c * l + 0.5) / l;
	}
	vec3 albedo = c * albedo_color.rgb;
	float a = tex.a * albedo_color.a;
#ifdef PS1_CUTOUT
	if (a < alpha_cut) {
		discard;
	}
#endif
#ifdef PS1_DITHER_ALPHA
	if (a < b) {
		discard;
	}
#endif
	albedo = mix(albedo, ps1_flash.rgb, ps1_flash.a);
#ifdef PS1_UNLIT
	// PS1 vertex colors were a 2x modulation (128 = 1.0): lets baked light go above 1.
	vec3 vc = use_vertex_color ? COLOR.rgb * 2.0 : vec3(1.0);
	ALBEDO = albedo * vc + emission_color * emission_energy + ps1_flash.rgb * ps1_flash.a * 0.6;
#else
	if (use_vertex_color) {
		albedo *= COLOR.rgb;
	}
	ALBEDO = albedo;
	EMISSION = emission_color * emission_energy + ps1_flash.rgb * ps1_flash.a * 0.6;
#endif
}
