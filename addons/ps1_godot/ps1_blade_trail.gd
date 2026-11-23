## Weapon trail: a ribbon swept by a blade (from `base` to `tip`, in the blade node's space),
## smoothed with Catmull-Rom between frames so fast swings stay round arcs, with a white-hot
## edge, a colored body that fades toward the hilt and with age, wind streaks, sparks shed from
## the tip and an optional little light riding the tip. Pauses with time scale (hitstop).
##
##   var trail := PS1BladeTrail.attach(sword_mesh, Vector3(0, 0.1, 0), Vector3(0, 0.95, 0))
##   trail.start()                              # when the swing begins
##   trail.stop()                               # the ribbon fades out on its own
##   trail.start(PS1BladeTrail.STYLES.ember)    # per-swing look (or a Dictionary of your own)
class_name PS1BladeTrail
extends MeshInstance3D

const SHADER := preload("res://addons/ps1_godot/shaders/ps1_trail.gdshader")

## Ready-made looks: color, core (edge line), lifetime (s), glow (extra width past the tip, as a
## fraction of the blade), streaks, sparks (per second, 0 = none), spark colors, light energy.
const STYLES := {
	steel = {color = Color(0.4, 0.55, 0.95), core = Color(1.0, 0.97, 0.92), lifetime = 0.2, glow = 0.18,
		streaks = 0.55, sparks = 45.0, spark_colors = [Color(0.85, 0.92, 1.0), Color(0.45, 0.6, 1.0), Color(0.2, 0.3, 0.7, 0.0)], light = 0.6},
	ember = {color = Color(0.95, 0.38, 0.08), core = Color(1.0, 0.9, 0.55), lifetime = 0.2, glow = 0.22,
		streaks = 0.6, sparks = 70.0, spark_colors = [Color(1, 0.9, 0.5), Color(1, 0.5, 0.1), Color(0.5, 0.1, 0.0, 0.0)], light = 1.0},
	blood = {color = Color(0.6, 0.04, 0.05), core = Color(1.0, 0.55, 0.45), lifetime = 0.2, glow = 0.15,
		streaks = 0.7, sparks = 35.0, spark_colors = [Color(0.9, 0.2, 0.15), Color(0.5, 0.02, 0.02), Color(0.2, 0.0, 0.0, 0.0)], light = 0.0},
	arcane = {color = Color(0.45, 0.2, 0.95), core = Color(0.9, 0.85, 1.0), lifetime = 0.22, glow = 0.25,
		streaks = 0.4, sparks = 50.0, spark_colors = [Color(0.9, 0.8, 1.0), Color(0.6, 0.3, 1.0), Color(0.2, 0.05, 0.5, 0.0)], light = 0.8},
}

var blade: Node3D
var base := Vector3.ZERO
var tip := Vector3(0, 1, 0)
## Catmull-Rom pieces between two frames.
var subdivisions := 4
var emitting := false
var style: Dictionary = STYLES.steel
## Width multiplier (charged attacks).
var width := 1.0

var _samples: Array = []   # [base_w, tip_w, age]
var _imesh := ImmediateMesh.new()
var _mat := ShaderMaterial.new()
var _sparks: PS1Particles
var _light: OmniLight3D
var _intensity := 0.0

## Creates the trail (added to the scene root, world space) following `blade_node`.
static func attach(blade_node: Node3D, base_local: Vector3, tip_local: Vector3, look := "steel") -> PS1BladeTrail:
	var t := PS1BladeTrail.new()
	t.name = "BladeTrail"
	t.blade = blade_node
	t.base = base_local
	t.tip = tip_local
	t.style = STYLES.get(look, STYLES.steel)
	blade_node.add_child(t)
	return t

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _imesh
	_mat.shader = SHADER
	_mat.set_shader_parameter("seed", randf() * 10.0)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0
	set_meta("ps1_no_bake", true)
	_sparks = PS1Particles.preset("sparks")
	_sparks.one_shot = false
	_sparks.auto_free = false
	_sparks.rate = 0.0
	_sparks.amount = 48
	_sparks.lifetime = 0.4
	_sparks.spread = 180.0
	_sparks.speed_min = 0.2
	_sparks.speed_max = 1.1
	_sparks.gravity = Vector3(0, -2.5, 0)
	_sparks.size_start = 0.1
	_sparks.size_end = 0.03
	_sparks.world_space = true
	_sparks.emitting = false
	add_child(_sparks)
	_sparks.top_level = true
	_light = OmniLight3D.new()
	_light.omni_range = 2.5
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)
	_light.top_level = true

## Begins a swing (keeps the old ribbon fading). `look`: a STYLES key or a Dictionary.
func start(look: Variant = null, width_mult := 1.0) -> void:
	if look is String or look is StringName:
		style = STYLES.get(look, STYLES.steel)
	elif look is Dictionary:
		style = look
	width = width_mult
	emitting = true
	_mat.set_shader_parameter("color", style.color)
	_mat.set_shader_parameter("core_color", style.core)
	_mat.set_shader_parameter("streaks", style.streaks)
	_sparks.colors = PS1Particles._grad(style.spark_colors)
	_sparks.rate = style.sparks
	_sparks.emitting = style.sparks > 0.0
	_light.light_color = style.color.lerp(Color.WHITE, 0.3)

func stop() -> void:
	emitting = false
	_sparks.emitting = false

func _process(dt: float) -> void:
	if not is_instance_valid(blade) or not blade.is_inside_tree():
		return
	var gt := blade.global_transform
	var lifetime: float = style.lifetime
	for s in _samples:
		s[2] += dt
	while not _samples.is_empty() and _samples[0][2] > lifetime:
		_samples.pop_front()
	var b := gt * base
	var t := gt * tip
	t = t + (t - b) * (style.glow * width)   # the ribbon reaches past the tip (glow)
	if emitting and dt > 0.0:
		_samples.append([b, t, 0.0])
	elif emitting and not _samples.is_empty():
		_samples[-1][0] = b
		_samples[-1][1] = t
	_intensity = move_toward(_intensity, 1.0 if emitting else 0.0, dt / 0.08)
	_sparks.global_position = gt * tip
	_light.global_position = gt * tip
	_light.light_energy = style.light * _intensity
	_build(lifetime)

func _build(lifetime: float) -> void:
	_imesh.clear_surfaces()
	var n := _samples.size()
	if n < 2:
		return
	_mat.set_shader_parameter("edge", 1.0 / (1.0 + style.glow * width))
	var rails_b := PackedVector3Array()
	var rails_t := PackedVector3Array()
	var ages := PackedFloat32Array()
	for i in n - 1:
		var p0: Array = _samples[maxi(i - 1, 0)]
		var p1: Array = _samples[i]
		var p2: Array = _samples[i + 1]
		var p3: Array = _samples[mini(i + 2, n - 1)]
		for k in subdivisions:
			var u := float(k) / subdivisions
			rails_b.append(_cr(p0[0], p1[0], p2[0], p3[0], u))
			rails_t.append(_cr(p0[1], p1[1], p2[1], p3[1], u))
			ages.append(lerpf(p1[2], p2[2], u))
	rails_b.append(_samples[n - 1][0])
	rails_t.append(_samples[n - 1][1])
	ages.append(_samples[n - 1][2])
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rails_b.size() - 1:
		var x0 := clampf(ages[i] / lifetime, 0.0, 1.0)
		var x1 := clampf(ages[i + 1] / lifetime, 0.0, 1.0)
		# two rows across the blade: hilt->edge is one quad, kept as 3 bands so the gradient
		# isn't stretched by affine interpolation
		for j in 3:
			var v0 := float(j) / 3.0
			var v1 := float(j + 1) / 3.0
			var a0 := rails_b[i].lerp(rails_t[i], v0)
			var a1 := rails_b[i].lerp(rails_t[i], v1)
			var b0 := rails_b[i + 1].lerp(rails_t[i + 1], v0)
			var b1 := rails_b[i + 1].lerp(rails_t[i + 1], v1)
			_v(a0, x0, v0); _v(b0, x1, v0); _v(b1, x1, v1)
			_v(a0, x0, v0); _v(b1, x1, v1); _v(a1, x0, v1)
	_imesh.surface_end()
	_mat.set_shader_parameter("intensity", 1.0)

func _v(p: Vector3, x: float, y: float) -> void:
	_imesh.surface_set_uv(Vector2(x, y))
	_imesh.surface_add_vertex(p)

static func _cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
