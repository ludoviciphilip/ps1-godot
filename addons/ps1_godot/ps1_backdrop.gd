## Panoramas: far scenery (a castle on a mountain, a cathedral across the valley, mountain
## ridges) drawn PAST the camera's far plane, just in front of the sky. Each layer is flat-shaded
## and fades into the haze the farther it is, with mist rising from below — the classic
## "new area, look at that view" shot, nearly free (no lights, no fog, never culled).
##
##   var bd := PS1Backdrop.new()
##   bd.haze_color = Color(0.1, 0.12, 0.16)      # usually your fog/horizon color
##   add_child(bd)
##   bd.add_mesh(PS1Backdrop.ridge(3, 400.0, 40.0), Transform3D(Basis(), Vector3(0, -10, -260)), 0.75)
##   var castle := PS1Gothic.new()                # any mesh works; PS1Gothic surfaces named
##   castle.tower(Vector3.ZERO, 6, 50)            # "glow" become lit windows
##   bd.add_mesh(castle.mesh(), Transform3D(Basis(), Vector3(0, 0, -150)), 0.35)
@tool
class_name PS1Backdrop
extends Node3D

const SHADER := preload("res://addons/ps1_godot/shaders/ps1_backdrop.gdshader")

## Haze the far layers fade into (use the fog / sky horizon color).
@export var haze_color := Color(0.1, 0.12, 0.16)
## Base color of the silhouettes (before haze).
@export var color := Color(0.07, 0.07, 0.09)
## Color of "glow" surfaces (windows, fires).
@export var glow_color := Color(1.0, 0.62, 0.3)
## Direction the light (moon) comes from, for a slight shading of the faces.
@export var light_dir := Vector3(0.4, 0.5, -0.7)
@export_range(0.0, 1.0) var light_amount := 0.35
## World height of the valley mist and how tall its fade is.
@export var mist_height := 0.0
## Color of the valley mist (moonlit mist reads best a bit lighter than the haze).
@export var mist_color := Color(0.1, 0.12, 0.16)
@export var mist_fade := 12.0

## Adds a node (every mesh inside gets the silhouette look). haze 0 = near (full color),
## 1 = lost in the haze. Layers with less haze are drawn in front. Returns the node.
func add(node: Node3D, xf := Transform3D.IDENTITY, haze := 0.4, tint := Color(0, 0, 0, 0)) -> Node3D:
	node.transform = xf
	add_child(node)
	var order := 1.0 + (1.0 - haze) * 8.0
	var meshes: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mi in meshes:
		_apply(mi as MeshInstance3D, haze, tint if tint.a > 0.0 else color, order)
	return node

## Shortcut: wraps a Mesh in a MeshInstance3D and adds it.
func add_mesh(m: Mesh, xf := Transform3D.IDENTITY, haze := 0.4, tint := Color(0, 0, 0, 0)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	add(mi, xf, haze, tint)
	return mi

func _mat(col: Color, haze: float, order: float, glow: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("haze_color", haze_color)
	m.set_shader_parameter("haze", haze * (0.35 if glow else 1.0))
	m.set_shader_parameter("light_dir", light_dir)
	m.set_shader_parameter("light_amount", 0.0 if glow else light_amount)
	m.set_shader_parameter("mist_height", mist_height)
	m.set_shader_parameter("mist_color", mist_color)
	m.set_shader_parameter("mist_fade", mist_fade)
	m.set_shader_parameter("emission", 1.0 if glow else 0.0)
	m.set_shader_parameter("depth_order", order + (0.05 if glow else 0.0))
	return m

func _apply(mi: MeshInstance3D, haze: float, col: Color, order: float) -> void:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0
	mi.set_meta("ps1_no_bake", true)
	if mi.mesh == null:
		return
	for i in mi.mesh.get_surface_count():
		var glow := mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).surface_get_name(i) == "glow"
		mi.set_surface_override_material(i, _mat(glow_color if glow else col, haze, order, glow))

## A sea of mist filling the valleys up to `mist_height`: a big flat disc in `mist_color`.
## Peaks and buildings rise out of it (their feet already fade into the same color).
func add_mist_sea(radius := 2000.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 16
	for i in n:
		var a := TAU * i / n
		var b := TAU * (i + 1) / n
		for p in [Vector3.ZERO, Vector3(cos(b), 0, sin(b)) * radius, Vector3(cos(a), 0, sin(a)) * radius]:
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	add(mi, Transform3D(Basis(), Vector3(0, mist_height + mist_fade * 0.25, 0)), 0.0, mist_color)
	var m := mi.get_surface_override_material(0) as ShaderMaterial
	m.set_shader_parameter("light_amount", 0.0)
	m.set_shader_parameter("mist_height", -1.0e6)
	m.set_shader_parameter("depth_order", 0.5)   # behind every silhouette
	return mi

## A mountain ridge: a jagged strip `length` wide along X with peaks up to `height`, going down
## to y = -depth (hide its foot in the mist). Deterministic per seed.
static func ridge(seed_ := 1, length := 300.0, height := 40.0, points := 28, depth := 60.0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tops := []
	for i in points + 1:
		var x := -length * 0.5 + length * i / points
		var e := sin(float(i) / points * PI)
		var y := height * (0.35 + 0.65 * e) * rng.randf_range(0.55, 1.0)
		if i % 2 == 1:
			y *= rng.randf_range(0.6, 0.85)
		tops.append(Vector3(x, y, rng.randf_range(-6.0, 6.0)))
	for i in points:
		var a: Vector3 = tops[i]
		var b: Vector3 = tops[i + 1]
		var a0 := Vector3(a.x, -depth, a.z)
		var b0 := Vector3(b.x, -depth, b.z)
		var n := ((b - a).cross(a0 - a)).normalized()
		if n.z < 0.0:
			n = -n
		n = (n + Vector3(0, 0.3, 0)).normalized()
		# front faces +Z (toward a camera looking at -Z): clockwise from the front
		for p in [a0, a, b, a0, b, b0]:
			st.set_normal(n)
			st.add_vertex(p)
	return st.commit()
