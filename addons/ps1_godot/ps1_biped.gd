## Procedural low-poly humanoid (PS1 style: rigid parts on a node rig, no skinning) with a
## ready AnimationPlayer. Built for enemies that don't have a Mixamo/Blender model yet: hooded
## archers, cultists, ghouls. Presets: archer() (bow + quiver), ghoul(), drowned() (bloated),
## hanged() (gaunt, long arms, hangs from the ceiling).
##
##   var a := PS1Biped.archer()
##   add_child(a)
##   a.animation_player().play("shoot")
##
## Animations: idle, walk, walk_back, run, shoot (draw, hold, release), bash (swing the weapon),
## hit, die, spew (rear back, heave forward and hold: vomiting / breath attacks), claw (both
## arms over the head and down), hang (dangling from the ceiling by the hands, loop) and drop
## (let go, fall, land in a crouch). Faces -Z, stands on y = 0. Nodes for hitboxes: "Head", "HandL", "HandR".
## Poses are data (joint -> rotation, or a direction for limbs), so new animations are a
## dictionary away: see add_animation().
class_name PS1Biped
extends Node3D

## Emitted by the shoot animation at the release frame (spawn the arrow here).
signal released

@export var height := 1.8
## Body build: 1 = normal, < 1 gaunt.
@export var bulk := 1.0
## Swollen belly (0 = none, 1 = huge): drowned, gluttons.
@export var belly := 0.0
## Arm length multiplier (1 = human; 1.4 = too long).
@export var arm_length := 1.0
@export var cloth_texture: Texture2D
@export var cloth_color := Color(0.42, 0.36, 0.3)
@export var skin_texture: Texture2D
@export var skin_color := Color(0.75, 0.68, 0.6)
@export var hood := true
@export var cloak := true
## "bow", "none".
@export_enum("bow", "none") var weapon := "bow"
@export var eye_color := Color(0.9, 0.75, 0.35)
@export var anim_fps := 15.0
@export var gait_period := 0.9

## 0..1, animated by "shoot": how far the bowstring is pulled toward the right hand.
var string_pull := 0.0:
	set(v):
		string_pull = v
		var arrow := get_node_or_null("Rig/Hips/Spine/Chest/ArmR/ForearmR/HandR/NockedArrow") as Node3D
		if arrow:
			arrow.visible = v > 0.15
## Animated: fires `released` when it goes 0 -> 1 (key in the shoot animation).
var release_mark := 0.0:
	set(v):
		if v > 0.5 and release_mark <= 0.5:
			released.emit()
		release_mark = v

var _joints := {}          # name -> Node3D
var _order: Array = []     # joint names, parents first
var _rest := {}            # name -> [position, Basis]
var _limb := {}            # limb joint -> true (points along -Y at rest)
var _anims := {}
var _string: MeshInstance3D
var _imesh: ImmediateMesh

func _ready() -> void:
	if not has_node("Rig"):
		build()

func animation_player() -> AnimationPlayer:
	return get_node_or_null("AnimationPlayer")

## Hooded archer with a longbow and a quiver.
static func archer() -> PS1Biped:
	var b := PS1Biped.new()
	b.cloth_texture = PS1Textures.fur(Color(0.27, 0.25, 0.21), 33)
	b.cloth_color = Color(0.95, 0.9, 0.85)
	b.skin_texture = PS1Textures.skin(Color(0.55, 0.5, 0.46), 13)
	return b

## Gaunt hooded ghoul, empty-handed.
static func ghoul() -> PS1Biped:
	var b := archer()
	b.weapon = "none"
	b.bulk = 0.8
	b.eye_color = Color(0.6, 0.9, 0.5)
	return b

## Drowned: bald, bloated and pale-green, in rags, with a huge belly. Use "spew" to vomit.
static func drowned() -> PS1Biped:
	var b := PS1Biped.new()
	b.weapon = "none"
	b.hood = false
	b.cloak = false
	b.bulk = 1.35
	b.belly = 1.0
	b.height = 1.85
	b.gait_period = 1.25
	b.skin_texture = PS1Textures.skin(Color(0.55, 0.6, 0.47), 57)
	b.skin_color = Color(0.95, 1.0, 0.9)
	b.cloth_texture = PS1Textures.fur(Color(0.26, 0.25, 0.2), 58)
	b.cloth_color = Color(0.8, 0.8, 0.72)
	b.eye_color = Color(0.85, 0.9, 0.55)
	return b

## Hanged one: gaunt, too-long arms, a sack over the head. Play "hang" while it dangles from the
## ceiling and "drop" when it lets go; "claw" swings both arms down.
static func hanged() -> PS1Biped:
	var b := PS1Biped.new()
	b.weapon = "none"
	b.hood = true
	b.cloak = false
	b.bulk = 0.62
	b.arm_length = 1.45
	b.height = 2.0
	b.gait_period = 0.8
	b.skin_texture = PS1Textures.skin(Color(0.6, 0.56, 0.52), 77)
	b.cloth_texture = PS1Textures.fur(Color(0.32, 0.27, 0.2), 78)
	b.cloth_color = Color(0.85, 0.8, 0.7)
	b.eye_color = Color(0.95, 0.35, 0.2)
	return b

# ---------------------------------------------------------------- building

func _mat(tex: Texture2D, col: Color, mode := "opaque") -> ShaderMaterial:
	return PS1Convert.make(tex, {color = col, mode = mode})

func _joint(parent: String, name_: String, pos: Vector3, limb := false) -> Node3D:
	var n := Node3D.new()
	n.name = name_
	n.position = pos
	(_joints[parent] if parent != "" else self).add_child(n)
	_joints[name_] = n
	_order.append(name_)
	_rest[name_] = [pos, Basis()]
	if limb:
		_limb[name_] = true
	return n

func _mesh(j: String, g: PS1Gothic, mat: Material, name_ := "Mesh") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = g.mesh()
	mi.material_override = mat
	_joints[j].add_child(mi)
	return mi

func build() -> void:
	for ch in get_children():
		remove_child(ch)
		ch.free()
	_joints.clear(); _order.clear(); _rest.clear(); _limb.clear()
	var k := height / 1.8
	var bk := bulk
	var m_cloth := _mat(cloth_texture if cloth_texture else PS1Textures.fur(), cloth_color)
	var m_dark := _mat(cloth_texture if cloth_texture else PS1Textures.fur(), cloth_color * 0.62)
	var m_skin := _mat(skin_texture if skin_texture else PS1Textures.skin(), skin_color)
	var m_leather := _mat(PS1Textures.flat(Color(0.3, 0.22, 0.15)), Color.WHITE)
	var m_wood := _mat(PS1Textures.bark(), Color(0.8, 0.62, 0.45))
	var m_eye := _mat(PS1Textures.flat(eye_color), Color.WHITE, "unlit")
	var m_void := _mat(PS1Textures.flat(Color(0.02, 0.015, 0.01)), Color.WHITE, "unlit")
	var hip_h := 0.95 * k
	_joint("", "Rig", Vector3.ZERO)
	_joint("Rig", "Hips", Vector3(0, hip_h, 0))
	_joint("Hips", "Spine", Vector3(0, 0.1 * k, 0))
	_joint("Spine", "Chest", Vector3(0, 0.24 * k, 0))
	_joint("Chest", "Head", Vector3(0, 0.3 * k, 0))
	for s: float in [-1.0, 1.0]:
		var sd := "L" if s < 0 else "R"
		_joint("Chest", "Arm" + sd, Vector3(s * 0.21 * k * bk, 0.22 * k, 0), true)
		_joint("Arm" + sd, "Forearm" + sd, Vector3(0, -0.29 * k * arm_length, 0), true)
		_joint("Forearm" + sd, "Hand" + sd, Vector3(0, -0.26 * k * arm_length, 0), true)
		_joint("Hips", "Thigh" + sd, Vector3(s * 0.1 * k * bk, -0.04 * k, 0), true)
		_joint("Thigh" + sd, "Shin" + sd, Vector3(0, -0.44 * k, 0), true)
	# --- body meshes
	var g := PS1Gothic.new(); g.uv_meters = 0.5
	g.xform = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO)   # spindle along Y
	g.spindle(Vector3(0, 0, -0.02 * k), 0.26 * k, 0.15 * k * bk, 0.16 * k * bk, 0.14 * k * bk, 6, 0.75, 0.05)
	_mesh("Hips", g, m_dark)
	g = PS1Gothic.new(); g.uv_meters = 0.5
	g.xform = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO)
	g.spindle(Vector3(0, 0, -0.12 * k), 0.3 * k, 0.13 * k * bk, 0.15 * k * bk, 0.17 * k * bk, 6, 0.7, 0.05)
	_mesh("Spine", g, m_cloth)
	g = PS1Gothic.new(); g.uv_meters = 0.5
	g.xform = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO)
	g.spindle(Vector3(0, 0, -0.13 * k), 0.34 * k, 0.17 * k * bk, 0.2 * k * bk, 0.15 * k * bk, 7, 0.68, 0.08)
	_mesh("Chest", g, m_cloth)
	if belly > 0.0:   # swollen gut, bare skin, hanging over the belt
		g = PS1Gothic.new(); g.uv_meters = 0.4
		g.xform = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, -0.1 * k * belly))
		g.spindle(Vector3(0, 0, 0.04 * k), 0.44 * k, (0.12 + 0.05 * belly) * k, (0.15 + 0.08 * belly) * k, (0.11 + 0.04 * belly) * k, 7, 1.25, 0.08)
		_mesh("Spine", g, m_skin, "Belly")
	# tabard: cloth hanging from the belt, front and back, to the knees
	g = PS1Gothic.new(); g.uv_meters = 0.6
	for sz: float in [-1.0, 1.0]:
		var z := sz * 0.13 * k * bk
		g.quad_away(Vector3(0, -0.2 * k, 0), Vector3(-0.14 * k, 0.02 * k, z), Vector3(0.14 * k, 0.02 * k, z),
			Vector3(0.12 * k, -0.42 * k, z * 1.25), Vector3(-0.12 * k, -0.42 * k, z * 1.25))
		g.quad_toward(Vector3(0, -0.2 * k, 0), Vector3(-0.14 * k, 0.02 * k, z), Vector3(0.14 * k, 0.02 * k, z),
			Vector3(0.12 * k, -0.42 * k, z * 1.25), Vector3(-0.12 * k, -0.42 * k, z * 1.25))
	_mesh("Hips", g, m_dark, "Tabard")
	# belt
	g = PS1Gothic.new()
	g.prism(Vector3(0, -0.03 * k, 0), 0.165 * k * bk, 0.06 * k, 7, false, false)
	_mesh("Hips", g, m_leather, "Belt")
	if cloak:
		g = PS1Gothic.new(); g.uv_meters = 0.7
		var c0 := Vector3(0, 0.25 * k, 0.1 * k)
		var pts := [Vector3(-0.24 * k, 0.24 * k, 0.08 * k), Vector3(0.24 * k, 0.24 * k, 0.08 * k),
			Vector3(0.3 * k, -0.62 * k, 0.24 * k), Vector3(-0.3 * k, -0.62 * k, 0.24 * k)]
		g.quad(pts[1], pts[0], pts[3], pts[2])
		g.quad(pts[0], pts[1], pts[2], pts[3])
		for sx: float in [-1.0, 1.0]:   # sides wrapping the shoulders
			var a := Vector3(sx * 0.24 * k, 0.24 * k, 0.08 * k)
			var b2 := Vector3(sx * 0.26 * k, 0.2 * k, -0.06 * k)
			var c := Vector3(sx * 0.3 * k, -0.5 * k, 0.05 * k)
			var d := Vector3(sx * 0.3 * k, -0.62 * k, 0.24 * k)
			g.quad_away(c0 - Vector3(0, 0.3 * k, 0), a, b2, c, d)
			g.quad_toward(c0 - Vector3(0, 0.3 * k, 0), a, b2, c, d)
		_mesh("Chest", g, m_dark, "Cloak")
	# head + hood
	g = PS1Gothic.new(); g.uv_meters = 0.3
	g.xform = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO)
	g.spindle(Vector3(0, 0, -0.12 * k), 0.24 * k, 0.09 * k, 0.11 * k, 0.09 * k, 6, 0.95, 0.1)
	_mesh("Head", g, m_skin)
	var ge := PS1Gothic.new()
	if not hood:
		for sx: float in [-1.0, 1.0]:
			ge.box(Vector3(sx * 0.04 * k, 0.13 * k, -0.105 * k), Vector3(0.03 * k, 0.018 * k, 0.02 * k), 0.0, true, false)
		_mesh("Head", ge, m_eye, "Eyes")
	else:
		g = PS1Gothic.new(); g.uv_meters = 0.4
		var hr := 0.15 * k
		g.lathe(Vector3(0, 0.02 * k, 0.02 * k), PackedVector2Array([Vector2(hr * 1.05, 0.0), Vector2(hr * 1.1, 0.1 * k),
			Vector2(hr * 0.95, 0.2 * k), Vector2(hr * 0.55, 0.28 * k), Vector2(0.0, 0.31 * k)]), 7, true)
		_mesh("Head", g, m_dark, "Hood")
		var gv := PS1Gothic.new()   # shadowed face opening
		gv.quad(Vector3(-0.08 * k, 0.05 * k, -0.118 * k), Vector3(0.08 * k, 0.05 * k, -0.118 * k), Vector3(0.07 * k, 0.2 * k, -0.118 * k), Vector3(-0.07 * k, 0.2 * k, -0.118 * k), false)
		_mesh("Head", gv, m_void, "Shadow")
		ge = PS1Gothic.new()
		for sx: float in [-1.0, 1.0]:
			ge.box(Vector3(sx * 0.035 * k, 0.135 * k, -0.125 * k), Vector3(0.028 * k, 0.016 * k, 0.01 * k), 0.0, true, false)
		_mesh("Head", ge, m_eye, "Eyes")
	# limbs
	for s: float in [-1.0, 1.0]:
		var sd := "L" if s < 0 else "R"
		var al := arm_length
		var bare := weapon == "none"   # no gloves/bracers: bare skin forearms
		g = PS1Gothic.new(); g.uv_meters = 0.4
		g.limb(Vector3(0, 0.02 * k, 0), Vector3(0, -0.29 * k * al, 0), 0.065 * k * bk, 0.05 * k * bk, 5)
		_mesh("Arm" + sd, g, m_cloth if not bare or belly == 0.0 else m_skin)
		g = PS1Gothic.new(); g.uv_meters = 0.4
		g.limb(Vector3.ZERO, Vector3(0, -0.26 * k * al, 0), 0.05 * k * bk, 0.038 * k, 5)
		_mesh("Forearm" + sd, g, m_skin if bare else m_leather)
		g = PS1Gothic.new()
		g.box(Vector3(0, -0.05 * k, 0), Vector3(0.06 * k, 0.1 * k, 0.07 * k), 0.0, true, false)
		if al > 1.2:   # long arms end in long fingers
			for f in 3:
				var fx := (f - 1) * 0.022 * k
				g.limb(Vector3(fx, -0.09 * k, 0), Vector3(fx * 1.6, -0.2 * k * al, -0.03 * k), 0.012 * k, 0.005 * k, 3)
		_mesh("Hand" + sd, g, m_skin)
		g = PS1Gothic.new(); g.uv_meters = 0.4
		g.limb(Vector3(0, 0.03 * k, 0), Vector3(0, -0.44 * k, 0), 0.085 * k * bk, 0.06 * k * bk, 5)
		_mesh("Thigh" + sd, g, m_dark)
		g = PS1Gothic.new(); g.uv_meters = 0.4
		g.limb(Vector3.ZERO, Vector3(0, -0.42 * k, 0), 0.06 * k * bk, 0.05 * k, 5)
		g.box(Vector3(0, -0.45 * k, -0.04 * k), Vector3(0.09 * k, 0.07 * k, 0.2 * k), 0.0, true, false)   # boot
		_mesh("Shin" + sd, g, m_leather)
	if weapon == "bow":
		_build_bow(k, m_wood, m_leather)
	_bake()

func _build_bow(k: float, m_wood: Material, m_leather: Material) -> void:
	# Bow in the left hand, along the hand's local Z (vertical when the arm points forward),
	# belly bent toward -Y (away from the archer).
	var g := PS1Gothic.new(); g.uv_meters = 0.4
	var half := 0.7 * k
	var pts := []
	for i in 7:
		var u := -1.0 + 2.0 * i / 6.0
		pts.append(Vector3(0, -0.07 * k - (1.0 - u * u) * 0.12 * k + 0.12 * k, u * half))
	for i in 6:
		var r := 0.02 * k * (1.0 - absf(-1.0 + 2.0 * (i + 0.5) / 6.0) * 0.5)
		g.limb(pts[i], pts[i + 1], r, r, 4)
	var bow := MeshInstance3D.new()
	bow.name = "Bow"
	bow.mesh = g.mesh()
	bow.material_override = m_wood
	_joints["HandL"].add_child(bow)
	bow.position = Vector3(0, -0.06 * k, 0)
	for sgn: float in [-1.0, 1.0]:
		var tip := Node3D.new()
		tip.name = "TipTop" if sgn < 0 else "TipBottom"
		tip.position = pts[0 if sgn < 0 else 6]
		bow.add_child(tip)
	var grip := Node3D.new(); grip.name = "Grip"; grip.position = Vector3(0, 0.01 * k, 0)
	bow.add_child(grip)
	# quiver on the back
	var gq := PS1Gothic.new(); gq.uv_meters = 0.4
	gq.xform = Transform3D(Basis(Vector3.FORWARD, 0.4), Vector3(0.08 * k, 0.05 * k, 0.17 * k))
	gq.prism(Vector3(0, -0.3 * k, 0), 0.055 * k, 0.5 * k, 6, false, false)
	var q := MeshInstance3D.new(); q.name = "Quiver"; q.mesh = gq.mesh(); q.material_override = m_leather
	_joints["Chest"].add_child(q)
	var gf := PS1Gothic.new()
	gf.xform = gq.xform
	for i in 4:
		var o := Vector3(cos(i * 1.6) * 0.03 * k, 0.2 * k, sin(i * 1.6) * 0.03 * k)
		gf.limb(o, o + Vector3(0, 0.08 * k, 0), 0.02 * k, 0.005 * k, 3)
	var f := MeshInstance3D.new(); f.name = "Fletching"; f.mesh = gf.mesh()
	f.material_override = _mat(PS1Textures.flat(Color(0.8, 0.78, 0.72)), Color.WHITE)
	_joints["Chest"].add_child(f)
	# arrow on the string (shown while drawing), in the right hand pointing forward
	var arrow := PS1Projectile.arrow(0.78 * k)
	var am := arrow.get_child(0)
	arrow.remove_child(am)
	arrow.free()
	var na := Node3D.new(); na.name = "NockedArrow"; na.visible = false
	am.position = Vector3(0, 0, -0.33 * k)
	na.add_child(am)
	_joints["HandR"].add_child(na)
	# string: drawn every frame from the tips to the nock (or straight when relaxed)
	_imesh = ImmediateMesh.new()
	_string = MeshInstance3D.new()
	_string.name = "String"
	_string.mesh = _imesh
	_string.material_override = _mat(PS1Textures.flat(Color(0.85, 0.82, 0.72)), Color.WHITE, "unlit")
	_string.set_meta("ps1_no_bake", true)
	add_child(_string)

func _process(_dt: float) -> void:
	if _string == null or not is_inside_tree():
		return
	var bow := get_node_or_null("Rig/Hips/Spine/Chest/ArmL/ForearmL/HandL/Bow")
	if bow == null:
		return
	var inv := global_transform.affine_inverse()
	var a: Vector3 = inv * (bow.get_node("TipTop") as Node3D).global_position
	var b: Vector3 = inv * (bow.get_node("TipBottom") as Node3D).global_position
	var rest := (a + b) * 0.5
	var hand: Vector3 = inv * (_joints["HandR"] as Node3D).global_transform * Vector3(0, -0.06, 0)
	var nock := rest.lerp(hand, clampf(string_pull, 0.0, 1.0))
	var cam := get_viewport().get_camera_3d()
	var side := Vector3.RIGHT * 0.006
	if cam:
		side = (inv.basis * cam.global_basis.x).normalized() * 0.006 * height / 1.8
	_imesh.clear_surfaces()
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for seg in [[a, nock], [nock, b]]:
		var p0: Vector3 = seg[0]; var p1: Vector3 = seg[1]
		for v in [p0 - side, p0 + side, p1 + side, p0 - side, p1 + side, p1 - side]:
			_imesh.surface_add_vertex(v)
	_imesh.surface_end()

# ---------------------------------------------------------------- poses

## Pose = {joint: value}. Value: Vector3 = local euler rotation (radians); for limbs
## {dir = Vector3} = point the limb that way, in MODEL space (-Z forward, +X right);
## "Hips_pos" / "Rig_pos" = offset of that joint. Missing joints keep their rest.
func _resolve(pose: Dictionary) -> Dictionary:
	var out := {}
	var glob := {}   # joint -> model-space basis
	for j in _order:
		var parent := String((_joints[j] as Node3D).get_parent().name)
		var pb: Basis = glob.get(parent, Basis())
		var local := Basis()
		var v = pose.get(j)
		if v is Vector3:
			local = Basis.from_euler(v)
		elif v is Dictionary and v.has("dir"):
			var dl: Vector3 = (pb.inverse() * (v.dir as Vector3)).normalized()
			local = Basis(Quaternion(Vector3.DOWN, dl))
			if v.has("z"):   # roll the limb so its local +Z points as close as possible to v.z
				var zl: Vector3 = (pb * local).inverse() * (v.z as Vector3)
				local = local * Basis(Vector3.UP, atan2(zl.x, zl.z))
		glob[j] = pb * local
		out[j] = local.get_rotation_quaternion()
	for extra: String in ["Hips_pos", "Rig_pos"]:
		if pose.has(extra):
			out[extra] = pose[extra]
	if pose.has("string"):
		out["string"] = pose.string
	if pose.has("release"):
		out["release"] = pose.release
	return out

## Add (or replace) an animation from keyed poses: keys = [[time, pose], ...] (see _resolve).
## Between keys the motion eases in/out. Call before build(), or rebuild after. Replaces the
## default animation of the same name; the other defaults stay.
func add_animation(anim_name: String, keys: Array, loop := false) -> void:
	_custom[anim_name] = [keys, loop]

var _custom := {}

func _put(anim_name: String, keys: Array, loop := false) -> void:
	_anims[anim_name] = [keys, loop]

func _default_anims() -> void:
	var k := height / 1.8
	var fw := Vector3(0, -0.45, -1).normalized()
	# --- idle: bow held low in the left hand, slow breathing
	var idle := {
		"ArmL": {dir = Vector3(-0.25, -1, -0.45)}, "ForearmL": {dir = Vector3(-0.05, -0.4, -1)}, "HandL": {dir = Vector3(-0.05, -0.4, -1), z = Vector3(0, 0.25, 1)},
		"ArmR": {dir = Vector3(0.2, -1, 0.05)}, "ForearmR": {dir = Vector3(0.1, -1, -0.3)},
		"ThighL": {dir = Vector3(-0.08, -1, 0)}, "ThighR": {dir = Vector3(0.08, -1, 0.05)}, "ShinL": {dir = Vector3(-0.05, -1, 0.05)}, "ShinR": {dir = Vector3(0.05, -1, 0.1)},
		"Spine": Vector3(0.05, 0, 0), "Head": Vector3(0.1, 0, 0)}
	if weapon == "none":   # empty hands: arms hang a little forward, shoulders slumped
		idle["ArmL"] = {dir = Vector3(-0.18 - 0.1 * belly, -1, -0.2)}
		idle["ForearmL"] = {dir = Vector3(-0.08, -1, -0.45)}
		idle["HandL"] = {dir = Vector3(-0.05, -1, -0.5)}
		idle["ArmR"] = {dir = Vector3(0.18 + 0.1 * belly, -1, -0.2)}
		idle["ForearmR"] = {dir = Vector3(0.08, -1, -0.45)}
		idle["HandR"] = {dir = Vector3(0.05, -1, -0.5)}
		idle["Spine"] = Vector3(0.12 - 0.15 * belly, 0, 0)
		idle["Head"] = Vector3(0.25, 0, 0)
	var idle2 := idle.duplicate(true)
	idle2["Spine"] = Vector3(0.09, 0, 0)
	idle2["Head"] = Vector3(0.05, 0.1, 0)
	idle2["Hips_pos"] = Vector3(0, -0.015 * k, 0)
	_put("idle", [[0.0, idle], [1.0, idle2], [2.0, idle]], true)
	# --- walk / run cycles
	for name_: String in ["walk", "run", "walk_back"]:
		var run := name_ == "run"
		var amp := 0.75 if run else 0.5
		var keys := []
		var per := gait_period * (0.62 if run else 1.0)
		for i in 5:
			var ph := TAU * i / 4.0
			var sw := sin(ph) * (-1.0 if name_ == "walk_back" else 1.0)
			var p := idle.duplicate(true)
			p["ThighL"] = {dir = Vector3(-0.06, -1, -sw * amp)}
			p["ThighR"] = {dir = Vector3(0.06, -1, sw * amp)}
			p["ShinL"] = {dir = Vector3(-0.04, -1, -sw * amp * 0.5 + maxf(0.0, -cos(ph)) * amp * 0.9)}
			p["ShinR"] = {dir = Vector3(0.04, -1, sw * amp * 0.5 + maxf(0.0, cos(ph)) * amp * 0.9)}
			p["ArmR"] = {dir = Vector3(0.18, -1, -sw * amp * 0.6)}
			p["Hips_pos"] = Vector3(0, -absf(cos(ph)) * 0.04 * k, 0)
			p["Spine"] = Vector3(0.15 if run else 0.05, sw * 0.08, 0)
			keys.append([per * i / 4.0, p])
		_put(name_, keys, true)
	# --- shoot: turn sideways, raise the bow, nock and draw to the cheek, hold, release
	var aim := {
		"Spine": Vector3(0.0, -0.7, 0), "Chest": Vector3(0.0, -0.45, 0), "Head": Vector3(0.0, 1.05, 0),
		"ArmL": {dir = Vector3(-0.02, 0.04, -1)}, "ForearmL": {dir = Vector3(0.0, 0.04, -1)}, "HandL": {dir = Vector3(0.0, 0.04, -1), z = Vector3(0.12, -1, 0)},
		"ArmR": {dir = Vector3(0.7, 0.2, -0.7)}, "ForearmR": {dir = Vector3(-0.95, 0.1, -0.3)},
		"ThighL": {dir = Vector3(-0.25, -1, -0.12)}, "ThighR": {dir = Vector3(0.22, -1, 0.12)}, "ShinL": {dir = Vector3(-0.15, -1, 0)}, "ShinR": {dir = Vector3(0.12, -1, 0.1)},
		"string": 1.0}
	var nock := aim.duplicate(true)
	nock["ArmR"] = {dir = Vector3(0.1, -0.1, -1)}
	nock["ForearmR"] = {dir = Vector3(-0.1, 0.0, -1)}
	nock["string"] = 0.0
	var raise := idle.duplicate(true)
	raise["Spine"] = Vector3(0.0, -0.4, 0)
	raise["ArmL"] = {dir = Vector3(-0.1, -0.4, -1)}
	raise["ForearmL"] = {dir = Vector3(0, -0.1, -1)}
	raise["HandL"] = {dir = Vector3(0, -0.1, -1), z = Vector3(0.3, -1, 0)}
	raise["ArmR"] = {dir = Vector3(0.6, -0.8, 0.6)}   # reaching for the quiver
	raise["ForearmR"] = {dir = Vector3(0.1, 0.6, 1)}
	var released_p := aim.duplicate(true)
	released_p["ArmR"] = {dir = Vector3(1, 0.1, 0.25)}
	released_p["ForearmR"] = {dir = Vector3(0.6, 0.2, 0.6)}
	released_p["string"] = 0.0
	released_p["release"] = 1.0
	aim["release"] = 0.0
	_put("shoot", [[0.0, idle], [0.3, raise], [0.55, nock], [1.0, aim], [1.15, aim], [1.17, released_p], [1.45, released_p], [1.8, idle]])
	# --- bash: swing the bow across
	var wind := idle.duplicate(true)
	wind["Spine"] = Vector3(0, 0.6, 0)
	wind["ArmL"] = {dir = Vector3(-1, 0.3, 0.3)}
	wind["ForearmL"] = {dir = Vector3(-0.6, 0.3, 0.8)}
	wind["HandL"] = {dir = Vector3(-0.6, 0.3, 0.8), z = Vector3(0, -1, 0)}
	var swing := idle.duplicate(true)
	swing["Spine"] = Vector3(0.15, -0.6, 0)
	swing["ArmL"] = {dir = Vector3(0.6, 0.1, -1)}
	swing["ForearmL"] = {dir = Vector3(1, 0.1, -0.3)}
	swing["HandL"] = {dir = Vector3(1, 0.1, -0.3), z = Vector3(0, -1, 0)}
	_put("bash", [[0.0, idle], [0.35, wind], [0.52, swing], [0.7, swing], [1.0, idle]])
	# --- hit, die
	var hit := idle.duplicate(true)
	hit["Spine"] = Vector3(-0.35, 0, 0.1)
	hit["Head"] = Vector3(-0.4, 0, 0)
	hit["Hips_pos"] = Vector3(0, 0, 0.06 * k)
	_put("hit", [[0.0, idle], [0.12, hit], [0.35, idle]])
	var knees := idle.duplicate(true)
	knees["Hips_pos"] = Vector3(0, -0.42 * k, 0.05 * k)
	knees["ThighL"] = {dir = Vector3(-0.1, -0.3, -1)}
	knees["ThighR"] = {dir = Vector3(0.1, -0.3, -1)}
	knees["ShinL"] = {dir = Vector3(0, -1, 0.9)}
	knees["ShinR"] = {dir = Vector3(0, -1, 0.9)}
	knees["Spine"] = Vector3(-0.3, 0, 0)
	knees["Head"] = Vector3(-0.5, 0, 0)
	knees["ArmL"] = {dir = Vector3(-0.3, -1, 0)}
	var down := knees.duplicate(true)
	down["Rig"] = Vector3(-1.45, 0, 0)
	down["Hips_pos"] = Vector3(0, -0.8 * k, 0.1 * k)
	down["Spine"] = Vector3(0.1, 0, 0.1)
	down["Head"] = Vector3(0.3, 0.6, 0)
	_put("die", [[0.0, idle], [0.1, hit], [0.55, knees], [1.1, down], [1.4, down]])
	# --- spew: rear back (0.55), heave forward (0.8) and hold it, recover
	var rear := idle.duplicate(true)
	rear["Spine"] = Vector3(-0.4, 0, 0); rear["Chest"] = Vector3(-0.2, 0, 0); rear["Head"] = Vector3(-0.55, 0, 0)
	rear["ArmL"] = {dir = Vector3(-0.7, -0.6, 0.4)}; rear["ArmR"] = {dir = Vector3(0.7, -0.6, 0.4)}
	rear["ForearmL"] = {dir = Vector3(-0.5, -0.4, 0.6)}; rear["ForearmR"] = {dir = Vector3(0.5, -0.4, 0.6)}
	rear["Hips_pos"] = Vector3(0, -0.03 * k, 0.06 * k)
	var heave := idle.duplicate(true)
	heave["Spine"] = Vector3(0.5, 0, 0); heave["Chest"] = Vector3(0.2, 0, 0); heave["Head"] = Vector3(0.1, 0, 0)
	heave["ArmL"] = {dir = Vector3(-0.5, -0.8, -0.5)}; heave["ArmR"] = {dir = Vector3(0.5, -0.8, -0.5)}
	heave["ForearmL"] = {dir = Vector3(-0.2, -1, -0.3)}; heave["ForearmR"] = {dir = Vector3(0.2, -1, -0.3)}
	heave["ThighL"] = {dir = Vector3(-0.15, -1, -0.2)}; heave["ShinL"] = {dir = Vector3(-0.1, -1, 0.15)}
	heave["Hips_pos"] = Vector3(0, -0.06 * k, -0.04 * k)
	var heave2 := heave.duplicate(true)
	heave2["Head"] = Vector3(0.2, 0.08, 0)
	_put("spew", [[0.0, idle], [0.55, rear], [0.8, heave], [1.25, heave2], [1.55, heave], [2.0, idle]])
	# --- claw: both arms high and back, then raked down in front
	var up := idle.duplicate(true)
	up["Spine"] = Vector3(-0.25, 0, 0); up["Head"] = Vector3(-0.2, 0, 0)
	up["ArmL"] = {dir = Vector3(-0.35, 1, 0.25)}; up["ArmR"] = {dir = Vector3(0.35, 1, 0.25)}
	up["ForearmL"] = {dir = Vector3(-0.2, 0.7, 0.8)}; up["ForearmR"] = {dir = Vector3(0.2, 0.7, 0.8)}
	up["HandL"] = {dir = Vector3(-0.1, 0.3, 1)}; up["HandR"] = {dir = Vector3(0.1, 0.3, 1)}
	var rake := idle.duplicate(true)
	rake["Spine"] = Vector3(0.55, 0, 0); rake["Head"] = Vector3(0.0, 0, 0)
	rake["ArmL"] = {dir = Vector3(-0.15, -0.5, -1)}; rake["ArmR"] = {dir = Vector3(0.15, -0.5, -1)}
	rake["ForearmL"] = {dir = Vector3(0.05, -1, -0.4)}; rake["ForearmR"] = {dir = Vector3(-0.05, -1, -0.4)}
	rake["HandL"] = {dir = Vector3(0.0, -1, 0.2)}; rake["HandR"] = {dir = Vector3(0.0, -1, 0.2)}
	rake["ThighL"] = {dir = Vector3(-0.1, -1, -0.35)}; rake["ShinL"] = {dir = Vector3(-0.05, -1, 0.2)}
	rake["Hips_pos"] = Vector3(0, -0.08 * k, -0.06 * k)
	_put("claw", [[0.0, idle], [0.45, up], [0.62, rake], [0.85, rake], [1.25, idle]])
	# --- hang: hands gripping above the head, body limp, legs dangling, slow sway
	var hang := {
		"ArmL": {dir = Vector3(-0.12, 1, 0.02)}, "ForearmL": {dir = Vector3(-0.04, 1, 0)}, "HandL": {dir = Vector3(0, 1, 0)},
		"ArmR": {dir = Vector3(0.12, 1, 0.02)}, "ForearmR": {dir = Vector3(0.04, 1, 0)}, "HandR": {dir = Vector3(0, 1, 0)},
		"ThighL": {dir = Vector3(-0.04, -1, -0.05)}, "ThighR": {dir = Vector3(0.05, -1, 0.04)},
		"ShinL": {dir = Vector3(-0.02, -1, 0.12)}, "ShinR": {dir = Vector3(0.02, -1, 0.2)},
		"Spine": Vector3(0.0, 0, 0), "Head": Vector3(0.75, 0, 0.1), "Rig": Vector3(0, 0, 0.04)}
	var hang2 := hang.duplicate(true)
	hang2["Rig"] = Vector3(0.02, 0.15, -0.04)
	hang2["Head"] = Vector3(0.7, -0.1, -0.05)
	_put("hang", [[0.0, hang], [1.6, hang2], [3.2, hang]], true)
	# --- drop: let go (flailing), land hard in a crouch, rise
	var fall := idle.duplicate(true)
	fall["ArmL"] = {dir = Vector3(-0.8, 0.7, -0.3)}; fall["ArmR"] = {dir = Vector3(0.8, 0.7, -0.3)}
	fall["ForearmL"] = {dir = Vector3(-0.4, 0.4, -1)}; fall["ForearmR"] = {dir = Vector3(0.4, 0.4, -1)}
	fall["ThighL"] = {dir = Vector3(-0.2, -1, -0.5)}; fall["ThighR"] = {dir = Vector3(0.2, -1, -0.3)}
	fall["ShinL"] = {dir = Vector3(-0.1, -1, 0.5)}; fall["ShinR"] = {dir = Vector3(0.1, -1, 0.6)}
	fall["Head"] = Vector3(-0.3, 0, 0)
	var land := idle.duplicate(true)
	land["Hips_pos"] = Vector3(0, -0.4 * k, 0.05 * k)
	land["Spine"] = Vector3(0.6, 0, 0); land["Head"] = Vector3(-0.4, 0, 0)
	land["ThighL"] = {dir = Vector3(-0.35, -0.35, -1)}; land["ThighR"] = {dir = Vector3(0.35, -0.35, -1)}
	land["ShinL"] = {dir = Vector3(-0.1, -1, 0.7)}; land["ShinR"] = {dir = Vector3(0.1, -1, 0.7)}
	land["ArmL"] = {dir = Vector3(-0.6, -0.8, -0.4)}; land["ArmR"] = {dir = Vector3(0.6, -0.8, -0.4)}
	land["ForearmL"] = {dir = Vector3(-0.2, -1, -0.2)}; land["ForearmR"] = {dir = Vector3(0.2, -1, -0.2)}
	_put("drop", [[0.0, hang], [0.15, fall], [0.42, fall], [0.5, land], [0.95, land], [1.35, idle]])

func _bake() -> void:
	_anims.clear()
	_default_anims()
	for an in _custom:
		_anims[an] = _custom[an]
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	add_child(ap)
	var lib := AnimationLibrary.new()
	for an in _anims:
		var keys: Array = _anims[an][0]
		var resolved := []
		for kp in keys:
			resolved.append([float(kp[0]), _resolve(kp[1])])
		var anim := Animation.new()
		var length: float = resolved[-1][0]
		anim.length = length
		anim.loop_mode = Animation.LOOP_LINEAR if _anims[an][1] else Animation.LOOP_NONE
		var tr := {}
		for j in _order:
			var t := anim.add_track(Animation.TYPE_VALUE)
			anim.track_set_path(t, NodePath(String(get_path_to(_joints[j])) + ":quaternion"))
			tr[j] = t
		for extra: String in ["Hips", "Rig"]:
			var t := anim.add_track(Animation.TYPE_VALUE)
			anim.track_set_path(t, NodePath(String(get_path_to(_joints[extra])) + ":position"))
			tr[extra + "_pos"] = t
		var t_str := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(t_str, NodePath(".:string_pull"))
		var t_rel := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(t_rel, NodePath(".:release_mark"))
		anim.value_track_set_update_mode(t_rel, Animation.UPDATE_DISCRETE)
		var frames := maxi(int(ceil(length * anim_fps)), 2)
		for f in frames + 1:
			var t := minf(f / anim_fps, length)
			var i := 0
			while i < resolved.size() - 2 and resolved[i + 1][0] <= t:
				i += 1
			var a: Dictionary = resolved[i][1]
			var b: Dictionary = resolved[mini(i + 1, resolved.size() - 1)][1]
			var t0: float = resolved[i][0]
			var t1: float = resolved[mini(i + 1, resolved.size() - 1)][0]
			var u := 0.0 if t1 <= t0 else clampf((t - t0) / (t1 - t0), 0.0, 1.0)
			var e := u * u * (3.0 - 2.0 * u)
			for j in _order:
				var qa: Quaternion = a[j]; var qb: Quaternion = b[j]
				anim.track_insert_key(tr[j], t, qa.slerp(qb, e))
			for extra: String in ["Hips", "Rig"]:
				var rest: Vector3 = _rest[extra][0]
				var pa: Vector3 = a.get(extra + "_pos", Vector3.ZERO)
				var pb: Vector3 = b.get(extra + "_pos", Vector3.ZERO)
				anim.track_insert_key(tr[extra + "_pos"], t, rest + pa.lerp(pb, e))
			anim.track_insert_key(t_str, t, lerpf(float(a.get("string", 0.0)), float(b.get("string", 0.0)), e))
			anim.track_insert_key(t_rel, t, float(a.get("release", 0.0)) if e < 0.5 else float(b.get("release", 0.0)))
		lib.add_animation(an, anim)
	ap.add_animation_library("", lib)
	ap.play("idle")

## Head, hands (for hitboxes / lock-on).
func part(n: String) -> Node3D:
	return _joints.get(n)
