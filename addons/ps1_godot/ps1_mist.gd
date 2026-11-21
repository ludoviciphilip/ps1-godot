## Soft, animated PS1 mist: a few stacked translucent layers with flowing noise, soft edges and
## soft contact with walls/floor (no hard rectangle). For fog walls (souls-like boss gates), fog
## banks over water, mist in doorways. Readable with the CRT on (dither on the low-res grid).
##
##   var m := PS1Mist.new()
##   m.size = Vector3(4, 4, 0.6)         # width, height, depth (the layers spread in depth)
##   add_child(m)
@tool
class_name PS1Mist
extends Node3D

const SHADER := preload("res://addons/ps1_godot/shaders/ps1_mist.gdshader")

@export var size := Vector3(4.0, 4.0, 0.6):
	set(v): size = v; _rebuild()
@export var color := Color(0.82, 0.86, 0.95):
	set(v): color = v; _rebuild()
@export_range(0.0, 1.0) var density := 0.5:
	set(v): density = v; _rebuild()
@export_range(1, 6) var layers := 3:
	set(v): layers = v; _rebuild()
## Flow of the noise (UV units per second): x sideways, y upwards.
@export var flow := Vector2(0.2, 0.45):
	set(v): flow = v; _rebuild()
## Pale motes drifting in the mist (PS1Particles "mist").
@export var motes := true:
	set(v): motes = v; _rebuild()
## Bottom at the node's origin (true) or centered on it.
@export var grounded := true:
	set(v): grounded = v; _rebuild()

var _built: Array[Node] = []

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for n in _built:
		if is_instance_valid(n):
			n.queue_free()
	_built.clear()
	var y := size.y * 0.5 if grounded else 0.0
	for i in layers:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		# outer layers a bit wider so the borders don't line up
		var k := 1.0 + 0.06 * absf(i - (layers - 1) * 0.5)
		q.size = Vector2(size.x * k, size.y * k)
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("color", color)
		m.set_shader_parameter("density", density / sqrt(float(layers)) * 1.3)
		m.set_shader_parameter("flow", flow * (1.0 + 0.25 * i))
		m.set_shader_parameter("noise_scale", Vector2(size.x, size.y) * 0.9)
		m.set_shader_parameter("layer_offset", float(i))
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var dz := 0.0 if layers == 1 else lerpf(-size.z * 0.5, size.z * 0.5, float(i) / (layers - 1))
		mi.position = Vector3(0, y, dz)
		add_child(mi)
		_built.append(mi)
	if motes:
		var p := PS1Particles.preset("mist")
		p.shape_extents = Vector3(size.x * 0.45, size.y * 0.45, maxf(size.z * 0.5, 0.1))
		p.rate = 3.0 * size.x * size.y / 2.6
		p.amount = int(p.rate * p.lifetime) + 8
		p.position.y = y
		add_child(p)
		_built.append(p)
