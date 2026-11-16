## Level-of-detail switcher with PS1-style dithered cross-fades.
## Children are the levels: child 0 is shown up close, child 1 beyond distances[0], and so on.
## The last level disappears at draw_distance (0 = never). fade = width (m) of the dithered
## transition; 0 = hard pop, like many PS1 games.
@tool
class_name PS1LOD
extends Node3D

@export var distances: PackedFloat32Array = PackedFloat32Array([12.0]):
	set(v):
		distances = v
		_apply()
@export var draw_distance := 0.0:
	set(v):
		draw_distance = v
		_apply()
@export var fade := 2.0:
	set(v):
		fade = v
		_apply()

func _ready() -> void:
	_apply()
	child_order_changed.connect(_apply)

func _apply() -> void:
	if not is_inside_tree():
		return
	var levels := get_children().filter(func(c): return c is Node3D)
	for i in levels.size():
		var b := 0.0 if i == 0 else (distances[i - 1] if i - 1 < distances.size() else -1.0)
		var e := distances[i] if i < distances.size() else draw_distance
		var h := fade * 0.5
		for g in geometries(levels[i]):
			g.visible = b >= 0.0
			var r := radius(g)
			g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			var fin := Vector2.ZERO
			var fout := Vector2.ZERO
			if fade > 0.0:
				# Culling ranges are per object (from its center), so they get a margin;
				# the shader does the exact per-pixel dithered fade.
				g.visibility_range_begin = maxf(b - h - r, 0.0) if i > 0 else 0.0
				g.visibility_range_end = e + h + r if e > 0.0 else 0.0
				if i > 0:
					fin = Vector2(b - h, b + h)
				if e > 0.0:
					fout = Vector2(e - h, e + h)
			else:
				g.visibility_range_begin = b if i > 0 else 0.0
				g.visibility_range_end = e
			g.set_instance_shader_parameter("ps1_fade", Vector4(fin.x, fin.y, fout.x, fout.y))

static func geometries(n: Node) -> Array[GeometryInstance3D]:
	var r: Array[GeometryInstance3D] = []
	if n is GeometryInstance3D:
		r.append(n)
	for c in n.find_children("*", "GeometryInstance3D", true, false):
		r.append(c)
	return r

static func radius(g: GeometryInstance3D) -> float:
	if not g.is_inside_tree():
		return 0.0
	return (g.get_aabb().size * g.global_basis.get_scale()).length() * 0.5
