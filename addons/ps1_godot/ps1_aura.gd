## Glowing shell around a mesh (see PS1FX.aura()): `level` 0..1 fades it in, grows the shell,
## (from `sparks_from`) sheds sparks and (with `light_energy`) lights the surroundings.
class_name PS1Aura
extends MeshInstance3D

@export var color := Color(0.6, 0.8, 1.0):
	set(v):
		color = v
		if _mat: _mat.set_shader_parameter("color", v)
		if _light: _light.light_color = v
@export var grow := 0.04:
	set(v):
		grow = v
		if _mat: _mat.set_shader_parameter("grow", v)
@export_range(0.0, 1.0) var level := 0.0:
	set(v):
		level = clampf(v, 0.0, 1.0)
		if _mat: _mat.set_shader_parameter("level", level)
		visible = level > 0.01
		if _sparks:
			_sparks.emitting = level >= sparks_from
		if _light:
			_light.light_energy = light_energy * level
			_light.visible = level > 0.01
## Sparks start at this level (> 1 = never).
@export var sparks_from := 0.75
## Small light that grows with the level (0 = none): the charged weapon lights its surroundings.
@export var light_energy := 0.0
## Light range in world meters (the mesh may be scaled).
@export var light_range := 3.0

var _mat: ShaderMaterial
var _sparks: PS1Particles
var _light: OmniLight3D

func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = PS1FX.AURA_SHADER
	_mat.set_shader_parameter("color", color)
	_mat.set_shader_parameter("grow", grow)
	_mat.set_shader_parameter("level", level)
	material_override = _mat
	var ab := mesh.get_aabb() if mesh else AABB(Vector3.ZERO, Vector3.ONE * 0.2)
	if sparks_from <= 1.0:
		_sparks = PS1Particles.new()
		_sparks.rate = 16.0; _sparks.amount = 24; _sparks.lifetime = 0.5
		_sparks.shape = PS1Particles.Shape.BOX
		_sparks.shape_extents = ab.size * 0.5
		_sparks.position = ab.get_center()
		_sparks.spread = 180.0; _sparks.speed_min = 0.2; _sparks.speed_max = 0.7
		_sparks.size_start = 0.09; _sparks.size_end = 0.02; _sparks.texture_name = "spark"; _sparks.update_fps = 24
		_sparks.colors = PS1Particles._grad([Color(1, 1, 1), color, Color(color.r, color.g, color.b, 0.0)])
		_sparks.emitting = false
		add_child(_sparks)
	if light_energy > 0.0:
		_light = OmniLight3D.new()
		_light.light_color = color
		_light.shadow_enabled = false
		_light.position = ab.get_center()
		_light.omni_range = light_range / maxf(global_basis.get_scale().x, 0.0001)
		_light.light_energy = light_energy * level
		_light.visible = level > 0.01
		add_child(_light)
	visible = level > 0.01
