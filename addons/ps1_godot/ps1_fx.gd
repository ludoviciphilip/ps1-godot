## Combat feedback effects: glowing sword arcs on the ground (PS1SweepFX-style spin attacks,
## telegraphs of area attacks) and auras around meshes (a charging weapon, a buffed enemy).
##
##   var aura := PS1FX.aura(sword_mesh, Color(0.6, 0.8, 1.0))   # PS1Aura node, level 0..1
##   aura.level = 0.4
##   PS1FX.sweep(get_tree().current_scene, player.global_position, 3.0, 0.35)   # 360° spin
class_name PS1FX
extends RefCounted

const SWEEP_SHADER := preload("res://addons/ps1_godot/shaders/ps1_sweep.gdshader")
const AURA_SHADER := preload("res://addons/ps1_godot/shaders/ps1_aura.gdshader")

## Glowing arc that runs around `center` on the ground: `arc` radians (TAU = full spin) in
## `duration` seconds starting at `start_angle` (radians, 0 = +X, counter-clockwise seen from
## above; `clockwise` reverses). Fades out and frees itself. Returns the MeshInstance3D.
static func sweep(parent: Node, center: Vector3, radius: float, duration := 0.35, color := Color(0.75, 0.85, 1.0),
		arc := TAU, start_angle := 0.0, clockwise := false, inner := 0.55) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "SweepFX"
	var q := QuadMesh.new()
	q.size = Vector2.ONE * radius * 2.0
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("ps1_no_bake", true)
	var m := ShaderMaterial.new()
	m.shader = SWEEP_SHADER
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("inner", inner)
	m.set_shader_parameter("start", start_angle)
	m.set_shader_parameter("dir", -1.0 if clockwise else 1.0)
	m.set_shader_parameter("tail", minf(arc, 3.2))
	mi.material_override = m
	parent.add_child(mi)
	mi.global_position = center + Vector3.UP * 0.06
	var d := -1.0 if clockwise else 1.0
	var tw := mi.create_tween()
	var step := func(u: float) -> void:
		var sw := arc * minf(u / 0.75, 1.0)
		m.set_shader_parameter("swept", sw)
		m.set_shader_parameter("head", start_angle + d * sw)
		m.set_shader_parameter("fade", 1.0 - smoothstep(0.7, 1.0, u))
	tw.tween_method(step, 0.0, 1.0, duration)
	tw.tween_callback(mi.queue_free)
	return mi

## Aura shell over `mesh` (added as its child, same mesh). Drive `level` (0..1) on the returned
## node; 0 hides it.
static func aura(mesh: MeshInstance3D, color := Color(0.6, 0.8, 1.0), grow := 0.04, light_energy := 0.0) -> PS1Aura:
	var a := PS1Aura.new()
	a.light_energy = light_energy
	a.name = "Aura"
	a.mesh = mesh.mesh
	a.color = color
	a.grow = grow
	a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.set_meta("ps1_no_bake", true)
	mesh.add_child(a)
	return a
