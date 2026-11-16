## Converts regular Godot materials (e.g. imported from Blender) into PS1 materials,
## keeping albedo color/texture, uv scale, emission, cull mode, transparency and vertex colors.
##   PS1Convert.apply($MyModel)
class_name PS1Convert

const SHADERS := {
	"opaque": preload("res://addons/ps1_godot/shaders/ps1_lit.gdshader"),
	"double_sided": preload("res://addons/ps1_godot/shaders/ps1_lit_double_sided.gdshader"),
	"cutout": preload("res://addons/ps1_godot/shaders/ps1_cutout.gdshader"),
	"dither_alpha": preload("res://addons/ps1_godot/shaders/ps1_dither_alpha.gdshader"),
	"unlit": preload("res://addons/ps1_godot/shaders/ps1_unlit.gdshader"),
	"unlit_cutout": preload("res://addons/ps1_godot/shaders/ps1_unlit_cutout.gdshader"),
}
# Kept for backwards compatibility.
const LIT := preload("res://addons/ps1_godot/shaders/ps1_lit.gdshader")
const LIT_DOUBLE := preload("res://addons/ps1_godot/shaders/ps1_lit_double_sided.gdshader")

static var _cache := {}

static func is_ps1(m: Material) -> bool:
	return m is ShaderMaterial and SHADERS.values().has((m as ShaderMaterial).shader)

## Mode name of a PS1 material ("" if it isn't one).
static func mode_of(m: Material) -> String:
	if not is_ps1(m):
		return ""
	return SHADERS.find_key((m as ShaderMaterial).shader)

## Builds a PS1 material. opts: color, uv_scale, emission, emission_energy, mode
## ("opaque", "double_sided", "cutout", "dither_alpha", "unlit", "unlit_cutout"),
## alpha_cut, texture_color_levels, vertex_color.
static func make(tex: Texture2D, opts := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADERS[opts.get("mode", "opaque")]
	if tex:
		m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("albedo_color", opts.get("color", Color.WHITE))
	m.set_shader_parameter("uv_scale", opts.get("uv_scale", Vector2.ONE))
	m.set_shader_parameter("emission_color", opts.get("emission", Color.BLACK))
	m.set_shader_parameter("emission_energy", opts.get("emission_energy", 0.0))
	m.set_shader_parameter("texture_color_levels", opts.get("texture_color_levels", 0.0))
	m.set_shader_parameter("use_vertex_color", opts.get("vertex_color", false))
	if opts.has("alpha_cut"):
		m.set_shader_parameter("alpha_cut", opts.alpha_cut)
	return m

## Same material in another mode (keeps every parameter).
static func with_mode(m: ShaderMaterial, mode: String) -> ShaderMaterial:
	var n := m.duplicate() as ShaderMaterial
	n.shader = SHADERS[mode]
	return n

## Replaces the materials of every MeshInstance3D under (and including) root.
static func apply(root: Node) -> void:
	var nodes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		nodes.append(root)
	for n in nodes:
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, to_ps1(mi.get_active_material(s)))

static func to_ps1(src: Material) -> Material:
	if is_ps1(src):
		return src
	if src != null and _cache.has(src):
		return _cache[src]
	var opts := {}
	var tex: Texture2D = null
	if src is BaseMaterial3D:
		var b := src as BaseMaterial3D
		tex = b.albedo_texture
		opts.color = b.albedo_color
		opts.uv_scale = Vector2(b.uv1_scale.x, b.uv1_scale.y)
		opts.vertex_color = b.vertex_color_use_as_albedo
		if b.emission_enabled:
			opts.emission = b.emission
			opts.emission_energy = b.emission_energy_multiplier
		match b.transparency:
			BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
				opts.mode = "cutout"
				opts.alpha_cut = b.alpha_scissor_threshold
			BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_HASH, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
				opts.mode = "dither_alpha"
			_:
				opts.mode = "double_sided" if b.cull_mode == BaseMaterial3D.CULL_DISABLED else "opaque"
	var m := make(tex, opts)
	if src != null:
		_cache[src] = m
	return m
