## Converts regular Godot materials (e.g. imported from Blender) into PS1 materials,
## keeping albedo color, albedo texture, emission and cull mode.
##   PS1Convert.apply($MyModel)
class_name PS1Convert

const LIT := preload("res://addons/ps1_godot/shaders/ps1_lit.gdshader")
const LIT_DOUBLE := preload("res://addons/ps1_godot/shaders/ps1_lit_double_sided.gdshader")

static var _cache := {}

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
	if src is ShaderMaterial and (src.shader == LIT or src.shader == LIT_DOUBLE):
		return src
	if src != null and _cache.has(src):
		return _cache[src]
	var m := ShaderMaterial.new()
	m.shader = LIT
	if src is BaseMaterial3D:
		var b := src as BaseMaterial3D
		if b.cull_mode == BaseMaterial3D.CULL_DISABLED:
			m.shader = LIT_DOUBLE
		m.set_shader_parameter("albedo_color", b.albedo_color)
		if b.albedo_texture:
			m.set_shader_parameter("albedo_tex", b.albedo_texture)
		m.set_shader_parameter("uv_scale", Vector2(b.uv1_scale.x, b.uv1_scale.y))
		if b.emission_enabled:
			m.set_shader_parameter("emission_color", b.emission)
			m.set_shader_parameter("emission_energy", b.emission_energy_multiplier)
	if src != null:
		_cache[src] = m
	return m
