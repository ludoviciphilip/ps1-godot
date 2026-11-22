## Procedural low-poly creatures (giant rats, crawling horrors, many-bodied abominations) with a
## ready AnimationPlayer: idle, walk, run, attack (lunge/bite), slam (rear up and smash), spin,
## hit, die. The animations are generated from the body plan and baked into normal Animation
## resources, so anything that drives an AnimationPlayer (state machines, enemy AI) just works.
##
##   var rat := PS1Creature.rat()          # presets: rat(), crawler(), rat_king()
##   add_child(rat)                        # builds on _ready (or call build())
##   rat.get_node("AnimationPlayer").play("walk")
##
## Faces -Z, stands on y = 0. Attach hitboxes to the nodes named "Head" (one per body) or
## "Jaw"; `heads()` lists them. Change the exported shape and call build() again.
@tool
class_name PS1Creature
extends Node3D

@export_group("Body")
@export var body_length := 1.1
@export var body_radius := 0.3
## Vertical squash of the body cross-section (< 1 = flatter).
@export var body_squash := 0.92
## > 1: segmented body (each segment follows the previous one when walking).
@export_range(1, 12) var segments := 1
## Several bodies arranged in a ring, tails knotted in the middle (a rat king, a hydra of
## corpses). They breathe and bite out of phase.
@export_range(1, 12) var cluster := 1
@export var cluster_radius := 0.9
@export_group("Limbs")
@export_range(0, 8) var leg_pairs := 2
@export var leg_length := 0.34
@export var leg_radius := 0.06
## Long human arms as legs, elbows up (spider-like). Grotesque.
@export var human_limbs := false
@export_group("Head")
## "snout" (rodent/beast), "face" (pale human mask), "none".
@export_enum("snout", "face", "none") var head_style := "snout"
@export var head_size := 0.27
@export var ears := true
@export var eye_color := Color(1.0, 0.3, 0.12)
## Horns curving back from the head (0 = none), in meters.
@export var horns := 0.0
@export_group("Wings")
## Bat-like wings on the shoulders, total span when spread (0 = none). Folded at rest.
@export var wing_span := 0.0
@export var wing_color := Color(0.8, 0.8, 0.82)
@export_group("Tail")
@export var tail_length := 1.0
@export_range(0, 12) var tail_segments := 6
@export_group("Look")
@export var body_texture: Texture2D
@export var body_color := Color.WHITE
@export var limb_texture: Texture2D
@export var limb_color := Color(0.75, 0.6, 0.58)
@export_group("Animation")
@export var anim_fps := 15.0
## Seconds per walk cycle (run is 0.6x).
@export var gait_period := 0.45
@export var seed_ := 1

## Every animated node: {node, pos, rot (rest), kind, b (body), k, p (leg pair), s (side), j}
var _parts: Array = []
var _h := 0.0   # body center height

func _ready() -> void:
	if not has_node("Rig"):
		build()

## Head nodes (one per body), for hitboxes / lock-on.
func heads() -> Array[Node3D]:
	var r: Array[Node3D] = []
	for p in _parts:
		if p.kind == "head":
			r.append(p.node)
	return r

func animation_player() -> AnimationPlayer:
	return get_node_or_null("AnimationPlayer")

# ---------------------------------------------------------------- presets

## Giant sewer rat (~0.8 m tall, 1.5 m + tail).
static func rat() -> PS1Creature:
	var c := PS1Creature.new()
	c.body_texture = PS1Textures.fur(Color(0.36, 0.32, 0.3))
	c.limb_texture = PS1Textures.skin(Color(0.62, 0.5, 0.5))
	c.limb_color = Color(0.85, 0.75, 0.75)
	return c

## Grotesque crawler: a long pale segmented body on human arms, wearing a human face.
static func crawler() -> PS1Creature:
	var c := PS1Creature.new()
	c.body_length = 1.8
	c.body_radius = 0.3
	c.body_squash = 0.8
	c.segments = 4
	c.leg_pairs = 4
	c.leg_length = 0.5
	c.leg_radius = 0.065
	c.human_limbs = true
	c.head_style = "face"
	c.head_size = 0.34
	c.ears = false
	c.eye_color = Color(0.85, 0.9, 0.6)
	c.tail_length = 0.5
	c.tail_segments = 3
	c.gait_period = 0.6
	var skin := PS1Textures.skin()
	c.body_texture = skin
	c.limb_texture = skin
	c.limb_color = Color(0.9, 0.85, 0.8)
	return c

## Gargoyle: a horned stone beast with folded bat wings and a long tail. Play "perch" while it
## pretends to be a statue, "wake" when it breaks free, "pounce" for the leap.
static func gargoyle() -> PS1Creature:
	var c := PS1Creature.new()
	c.body_length = 0.95
	c.body_radius = 0.3
	c.body_squash = 1.0
	c.leg_pairs = 2
	c.leg_length = 0.42
	c.leg_radius = 0.075
	c.head_size = 0.3
	c.ears = false
	c.horns = 0.34
	c.eye_color = Color(1.0, 0.55, 0.15)
	c.tail_length = 1.15
	c.tail_segments = 7
	c.wing_span = 2.7
	c.gait_period = 0.5
	var stone := PS1Textures.skin(Color(0.46, 0.47, 0.5), 91)
	c.body_texture = stone
	c.limb_texture = stone
	c.body_color = Color(0.95, 0.95, 1.0)
	c.limb_color = Color(0.85, 0.86, 0.9)
	c.wing_color = Color(0.72, 0.72, 0.76)
	return c

## Rat king: `n` giant rats whose tails are knotted together, moving as one mass.
static func rat_king(n := 7) -> PS1Creature:
	var c := rat()
	c.cluster = n
	c.cluster_radius = 1.25
	c.body_length = 1.25
	c.body_radius = 0.3
	c.tail_length = 1.2
	c.gait_period = 0.55
	c.eye_color = Color(1.0, 0.15, 0.08)
	return c

# ---------------------------------------------------------------- building

func _mat(tex: Texture2D, col: Color, mode := "opaque") -> ShaderMaterial:
	return PS1Convert.make(tex, {color = col, mode = mode})

func _mesh_node(parent: Node3D, g: PS1Gothic, mat: Material, name_ := "Mesh") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = g.mesh()
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _pivot(parent: Node3D, name_: String, pos: Vector3, kind: String, info := {}) -> Node3D:
	var n := Node3D.new()
	n.name = name_
	n.position = pos
	parent.add_child(n)
	var d := {node = n, pos = pos, rot = Vector3.ZERO, kind = kind, b = 0, k = 0, p = 0, s = 1.0, j = 0}
	d.merge(info, true)
	_parts.append(d)
	return n

func build() -> void:
	for ch in get_children():
		remove_child(ch)
		ch.free()
	_parts.clear()
	var fur := body_texture if body_texture else PS1Textures.fur()
	var m_body := _mat(fur, body_color)
	var m_limb := _mat(limb_texture if limb_texture else PS1Textures.skin(), limb_color)
	var m_eye := _mat(PS1Textures.flat(eye_color), Color.WHITE, "unlit")
	var m_teeth := _mat(PS1Textures.flat(Color(0.85, 0.8, 0.62)), Color.WHITE)
	var m_dark := _mat(PS1Textures.flat(Color(0.02, 0.0, 0.0)), Color.WHITE, "unlit")
	var R := body_radius
	_h = leg_length + R * body_squash * 0.75
	var rig := _pivot(self, "Rig", Vector3.ZERO, "rig")
	if cluster > 1:
		var knot := PS1Gothic.new()
		knot.uv_meters = 0.5
		knot.spindle(Vector3.ZERO, R * 2.2, R * 1.1, R * 1.4, R * 1.1, 7, 0.8, 0.2)
		var kn := _pivot(rig, "Knot", Vector3(0, _h * 0.9, 0), "knot")
		_mesh_node(kn, knot, m_body)
	var seg_len := body_length / segments
	for b in cluster:
		var body_pos := Vector3(0, _h, 0)
		var body := _pivot(rig, "Body%d" % b, body_pos, "body", {b = b})
		if cluster > 1:
			var ang := TAU * b / cluster
			body.rotation.y = ang
			body.position = Vector3(-sin(ang), 0, -cos(ang)) * cluster_radius + body_pos
			_parts[-1].pos = body.position
			_parts[-1].rot = body.rotation
		var prev: Node3D = body
		var last: Node3D = body
		for k in segments:
			var z := -body_length * 0.5 + seg_len * 0.5 if k == 0 else seg_len
			var seg := _pivot(prev, "Seg%d" % k, Vector3(0, 0, z), "seg", {b = b, k = k})
			var taper := 1.0 - 0.12 * k / maxf(segments - 1, 1)
			var g := PS1Gothic.new()
			g.uv_meters = 0.5
			if segments == 1:
				g.spindle(Vector3.ZERO, seg_len * 0.95, R * 1.05, R, R * 0.6, 8, body_squash, 0.1)
			else:
				g.spindle(Vector3.ZERO, seg_len * 1.25, R * 0.85 * taper, R * taper, R * 0.85 * taper, 6, body_squash, 0.08)
			_mesh_node(seg, g, m_body)
			prev = seg
			last = seg
		# legs
		for p in leg_pairs:
			var si := 0 if segments == 1 else int(round(float(p) * (segments - 1) / maxf(leg_pairs - 1, 1)))
			var seg: Node3D = body.get_node("Seg0")
			for q in si:
				seg = seg.get_node("Seg%d" % (q + 1))
			var z := 0.0
			if segments == 1:
				z = lerpf(-seg_len * 0.3, seg_len * 0.3, float(p) / maxf(leg_pairs - 1, 1))
			for s: float in [-1.0, 1.0]:
				var drop := _h - R * 0.3 * body_squash
				var hip := _pivot(seg, ("LegL%d" if s < 0 else "LegR%d") % p, Vector3(s * R * 0.7, -R * 0.3 * body_squash, z), "hip", {b = b, p = p, s = s})
				var knee_at: Vector3
				var foot_at: Vector3
				if human_limbs:
					knee_at = Vector3(s * drop * 0.75, drop * 0.75, -0.05)
					foot_at = Vector3(s * drop * 0.55, -drop * 1.75, -0.1)
				else:
					knee_at = Vector3(s * 0.04, -drop * 0.5, -0.04)
					foot_at = Vector3(s * 0.02, -drop * 0.5, 0.05)
				var gu := PS1Gothic.new()
				gu.uv_meters = 0.4
				gu.limb(Vector3.ZERO, knee_at, leg_radius * 1.3, leg_radius, 5)
				_mesh_node(hip, gu, m_body if not human_limbs else m_limb)
				var knee := _pivot(hip, "Knee", knee_at, "knee", {b = b, p = p, s = s})
				var gl := PS1Gothic.new()
				gl.uv_meters = 0.4
				gl.limb(Vector3.ZERO, foot_at, leg_radius, leg_radius * 0.7, 5)
				# paw / hand
				gl.limb(foot_at, foot_at + Vector3(0, -0.01, -leg_radius * 2.6), leg_radius * 0.9, leg_radius * 0.4, 4)
				_mesh_node(knee, gl, m_limb)
		# wings (bat-like: an arm with three fingers and the membrane between them)
		if wing_span > 0.0:
			var m_wing := _mat(limb_texture if limb_texture else PS1Textures.skin(), wing_color)
			var m_wing2 := _mat(limb_texture if limb_texture else PS1Textures.skin(), wing_color * 0.7)
			var seg0w: Node3D = body.get_node("Seg0")
			var L := wing_span * 0.5
			for s: float in [-1.0, 1.0]:
				var wp := _pivot(seg0w, "WingL" if s < 0 else "WingR", Vector3(s * R * 0.45, R * 0.7 * body_squash, -seg_len * 0.1), "wing",
					{b = b, s = s, rot = Vector3(0, -s * 1.3, s * 0.7)})
				wp.rotation = Vector3(0, -s * 1.3, s * 0.7)
				var gw := PS1Gothic.new()
				gw.uv_meters = 0.6
				var elbow := Vector3(s * L * 0.42, L * 0.12, -0.05)
				var wrist := Vector3(s * L * 0.72, L * 0.22, 0.05)
				gw.limb(Vector3.ZERO, elbow, leg_radius * 0.9, leg_radius * 0.7, 4)
				gw.limb(elbow, wrist, leg_radius * 0.7, leg_radius * 0.45, 4)
				var tips := [wrist + Vector3(s * L * 0.3, L * 0.08, 0.05), wrist + Vector3(s * L * 0.22, -L * 0.12, L * 0.32), wrist + Vector3(s * L * 0.05, -L * 0.3, L * 0.5)]
				for tip in tips:
					gw.limb(wrist, tip, leg_radius * 0.35, leg_radius * 0.1, 3)
				_mesh_node(wp, gw, m_limb)
				# membrane: fan from the shoulder/elbow/wrist through the finger tips, both faces
				var gm := PS1Gothic.new()
				gm.uv_meters = 0.8
				var root := Vector3(0, -0.02, R * 0.9)
				for tr in [[Vector3.ZERO, elbow, wrist], [wrist, tips[0], tips[1]], [wrist, tips[1], tips[2]],
						[Vector3.ZERO, wrist, tips[2]], [Vector3.ZERO, tips[2], root]]:
					gm.tri(tr[0], tr[1], tr[2])
					gm.tri(tr[0], tr[2], tr[1])
				_mesh_node(wp, gm, m_wing2, "Membrane")
		# head
		if head_style != "none":
			var seg0: Node3D = body.get_node("Seg0")
			var hs := head_size
			var head := _pivot(seg0, "Head", Vector3(0, R * 0.15, -seg_len * (0.45 if segments == 1 else 0.62)), "head", {b = b})
			var gh := PS1Gothic.new()
			gh.uv_meters = 0.4
			var ge := PS1Gothic.new()
			var gt := PS1Gothic.new()
			var gd := PS1Gothic.new()
			if head_style == "snout":
				gh.spindle(Vector3(0, 0, -hs * 0.6), hs * 1.6, hs * 0.78, hs * 0.62, hs * 0.2, 7, 0.85, 0.2)
				if ears:
					for s: float in [-1.0, 1.0]:
						var e := Vector3(s * hs * 0.42, hs * 0.38, -hs * 0.05)
						gh.tri_away(Vector3(s * hs * 0.2, 0, 0), e, e + Vector3(s * hs * 0.32, hs * 0.38, 0.0), e + Vector3(s * hs * 0.05, hs * 0.2, hs * 0.22))
						gh.tri_away(Vector3(s * hs * 0.8, hs * 0.5, -hs * 0.4), e, e + Vector3(s * hs * 0.05, hs * 0.2, hs * 0.22), e + Vector3(s * hs * 0.32, hs * 0.38, 0.0))
				for s: float in [-1.0, 1.0]:
					ge.box(Vector3(s * hs * 0.33, hs * 0.2, -hs * 0.62), Vector3(hs * 0.16, hs * 0.12, hs * 0.1), 0.0, true, false)
				gt.box(Vector3(-hs * 0.04, -hs * 0.16, -hs * 1.36), Vector3(hs * 0.07, hs * 0.2, hs * 0.05), 0.0, true, false)
				gt.box(Vector3(hs * 0.04, -hs * 0.16, -hs * 1.36), Vector3(hs * 0.07, hs * 0.2, hs * 0.05), 0.0, true, false)
			else:   # face: a pale human mask, too smooth, with black eye holes
				gh.spindle(Vector3(0, 0, -hs * 0.35), hs * 1.1, hs * 0.85, hs * 0.92, hs * 0.55, 7, 1.2, 0.1)
				for s: float in [-1.0, 1.0]:
					gd.box(Vector3(s * hs * 0.3, hs * 0.22, -hs * 0.93), Vector3(hs * 0.26, hs * 0.16, hs * 0.08), 0.0, true, false)
					ge.box(Vector3(s * hs * 0.3, hs * 0.22, -hs * 0.95), Vector3(hs * 0.06, hs * 0.06, hs * 0.06), 0.0, true, false)
			_mesh_node(head, gh, m_body if head_style == "snout" else m_limb)
			_mesh_node(head, ge, m_eye, "Eyes")
			if not gt._st.is_empty():
				_mesh_node(head, gt, m_teeth, "Teeth")
			if head_style == "face":
				_mesh_node(head, gd, m_dark, "Sockets")
			if horns > 0.0:
				var gho := PS1Gothic.new()
				gho.uv_meters = 0.3
				for sx: float in [-1.0, 1.0]:
					var h0 := Vector3(sx * hs * 0.3, hs * 0.32, -hs * 0.2)
					var h1 := h0 + Vector3(sx * horns * 0.35, horns * 0.55, horns * 0.35)
					var h2 := h1 + Vector3(sx * horns * 0.05, horns * 0.2, horns * 0.6)
					gho.limb(h0, h1, hs * 0.13, hs * 0.08, 5)
					gho.limb(h1, h2, hs * 0.08, hs * 0.015, 4)
				_mesh_node(head, gho, m_limb, "Horns")
			var jaw := _pivot(head, "Jaw", Vector3(0, -hs * 0.28, -hs * 0.15), "jaw", {b = b})
			var gj := PS1Gothic.new()
			gj.uv_meters = 0.4
			if head_style == "snout":
				gj.spindle(Vector3(0, 0, -hs * 0.45), hs * 1.0, hs * 0.4, hs * 0.32, hs * 0.1, 5, 0.6, 0.1)
				_mesh_node(jaw, gj, m_body)
			else:   # a mouth that opens far too wide
				gj.spindle(Vector3(0, -hs * 0.05, -hs * 0.45), hs * 0.6, hs * 0.5, hs * 0.55, hs * 0.4, 6, 0.6, 0.05)
				_mesh_node(jaw, gj, m_limb)
				var gm := PS1Gothic.new()
				gm.box(Vector3(0, hs * 0.12, -hs * 0.72), Vector3(hs * 0.6, hs * 0.18, hs * 0.08), 0.0, true, false)
				_mesh_node(jaw, gm, m_dark, "Mouth")
				var gtt := PS1Gothic.new()
				for i in 5:
					gtt.box(Vector3(-hs * 0.24 + i * hs * 0.12, hs * 0.22, -hs * 0.74), Vector3(hs * 0.07, hs * 0.08, hs * 0.04), 0.0, true, false)
				_mesh_node(jaw, gtt, m_teeth, "Teeth")
		# tail
		if tail_segments > 0 and tail_length > 0.0:
			var tl := tail_length / tail_segments
			var tp: Node3D = _pivot(last, "Tail0", Vector3(0, -R * 0.1, seg_len * 0.48 + R * 0.1), "tail", {b = b, j = 0})
			for j in tail_segments:
				var r0 := leg_radius * 0.9 * (1.0 - float(j) / tail_segments) + 0.008
				var r1 := leg_radius * 0.9 * (1.0 - float(j + 1) / tail_segments) + 0.006
				var gtl := PS1Gothic.new()
				gtl.uv_meters = 0.3
				gtl.limb(Vector3.ZERO, Vector3(0, 0, tl), r0, r1, 4)
				_mesh_node(tp, gtl, m_limb)
				if j < tail_segments - 1:
					tp = _pivot(tp, "Tail%d" % (j + 1), Vector3(0, 0, tl), "tail", {b = b, j = j + 1})
	_bake_animations()

# ---------------------------------------------------------------- animation

const ANIMS := {idle = [1.6, true], walk = [0.0, true], run = [0.0, true], attack = [0.9, false],
	slam = [1.4, false], spin = [1.0, false], hit = [0.35, false], die = [1.2, false],
	pounce = [1.2, false], perch = [1.0, true], wake = [0.9, false]}

func _length(a: String) -> float:
	if a == "walk":
		return gait_period
	if a == "run":
		return gait_period * 0.6
	return ANIMS[a][0]

func _bake_animations() -> void:
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	add_child(ap)
	var lib := AnimationLibrary.new()
	for a in ANIMS:
		var anim := Animation.new()
		var length := _length(a)
		anim.length = length
		anim.loop_mode = Animation.LOOP_LINEAR if ANIMS[a][1] else Animation.LOOP_NONE
		var tracks := []
		for part in _parts:
			var path := String(get_path_to(part.node))
			var tk := anim.add_track(Animation.TYPE_VALUE)
			anim.track_set_path(tk, NodePath(path + ":rotation"))
			var tp := anim.add_track(Animation.TYPE_VALUE)
			anim.track_set_path(tp, NodePath(path + ":position"))
			tracks.append([tk, tp])
		var frames := maxi(int(ceil(length * anim_fps)), 2)
		for f in frames + 1:
			var t := minf(f / anim_fps, length)
			for i in _parts.size():
				var d: Array = _pose(a, t, length, _parts[i])
				anim.track_insert_key(tracks[i][0], t, _parts[i].rot + d[1])
				anim.track_insert_key(tracks[i][1], t, _parts[i].pos + d[0])
		lib.add_animation(a, anim)
	ap.add_animation_library("", lib)
	ap.play("idle")

static func _ss(a: float, b: float, t: float) -> float:
	return smoothstep(a, b, t)

## Offset [position, rotation] of one part at time t of an animation.
func _pose(a: String, t: float, length: float, part: Dictionary) -> Array:
	var dp := Vector3.ZERO
	var dr := Vector3.ZERO
	var kind: String = part.kind
	var phb := float(part.b) * 1.7 + float(seed_) * 0.37    # bodies of a cluster move out of phase
	var u := t / length
	var w := TAU * u
	var hind: bool = part.p > 0 and part.p == leg_pairs - 1
	var front: bool = part.p == 0
	if kind == "wing":
		return _wing_pose(a, t, length, part)
	match a:
		"perch":
			# crouched statue: rears up a little on the front legs, head high, tail coiled
			match kind:
				"body":
					dr.x = 0.35
					dp.y = -_h * 0.08
				"head":
					dr.x = -0.25
				"jaw":
					dr.x = 0.12
				"hip":
					dr.x = -0.2 if front else 0.9
				"knee":
					dr.x = 0.1 if front else -1.5
				"tail":
					dr.y = 0.35
					dr.x = 0.12
			return [dp, dr]
		"wake":
			var p0 := 1.0 - _ss(0.15, 0.75, t)
			var shake := sin(t * 55.0) * 0.07 * (1.0 - _ss(0.0, 0.6, t))
			var perch := _pose("perch", 0.0, 1.0, part)
			dp = perch[0] * p0
			dr = perch[1] * p0
			match kind:
				"rig":
					dr.y += shake
				"head":
					dr.x += -0.5 * sin(PI * _ss(0.3, 0.9, t))
				"jaw":
					dr.x += 0.7 * sin(PI * _ss(0.3, 0.9, t))
			return [dp, dr]
		"pounce":
			var crouch := _ss(0.0, 0.3, t) * (1.0 - _ss(0.3, 0.4, t))
			var air := _ss(0.35, 0.5, t) * (1.0 - _ss(0.75, 0.9, t))
			var land := _ss(0.82, 0.9, t) * (1.0 - _ss(0.95, 1.2, t))
			match kind:
				"rig":
					dp.y = sin(PI * clampf((t - 0.35) / 0.5, 0.0, 1.0)) * _h * 1.1 - crouch * _h * 0.25 - land * _h * 0.2
				"body":
					dr.x = 0.25 * crouch - 0.3 * air + 0.2 * land
				"head":
					dr.x = -0.3 * crouch + 0.35 * air
				"jaw":
					dr.x = 0.8 * air
				"hip":
					dr.x = (-0.6 if front else 0.5) * crouch + (0.8 if front else -0.9) * air
				"knee":
					dr.x = -0.9 * crouch - 0.2 * air
				"tail":
					dr.x = -0.25 * air
					dr.y = sin(t * 9.0 - part.j) * 0.2
			return [dp, dr]
		"walk", "run":
			var amp := 0.55 if a == "walk" else 0.8
			var ph: float = w + (PI if part.p % 2 == 1 else 0.0) + (PI if part.s > 0.0 else 0.0) + (phb if cluster > 1 else 0.0)
			match kind:
				"hip":
					dr.x = sin(ph) * amp * (0.6 if human_limbs else 1.0)
					if human_limbs:
						dr.z = part.s * maxf(0.0, cos(ph)) * 0.35
				"knee":
					dr.x = -maxf(0.0, cos(ph)) * (0.8 if not human_limbs else 0.3)
				"seg":
					if part.k > 0:
						dr.y = sin(w + part.k * 1.1) * 0.16
				"body":
					dp.y = absf(sin(w + phb)) * body_radius * 0.12
					dr.x = sin(w * 2.0) * 0.03
				"head":
					dr.x = sin(w * 2.0) * 0.07
					dr.y = sin(w + phb) * 0.12
				"tail":
					dr.y = sin(w - part.j * 0.8 + phb) * 0.3
					dr.x = 0.04
				"knot":
					dp.y = sin(w * 2.0) * 0.03
		"idle":
			match kind:
				"body":
					dp.y = sin(w + phb) * body_radius * 0.05
				"head":
					dr.y = sin(w + phb) * 0.28 + sin(w * 7.0 + phb) * 0.04
					dr.x = sin(w * 3.0 + phb) * 0.06
				"jaw":
					dr.x = maxf(0.0, sin(w * 5.0 + phb)) * 0.1
				"tail":
					dr.y = sin(w - part.j * 0.6 + phb) * 0.18
				"seg":
					if part.k > 0:
						dr.y = sin(w + part.k) * 0.06
				"knot":
					dp.y = sin(w) * 0.02
		"attack":
			var wind := _ss(0.0, 0.35, t)
			var strike := _ss(0.35, 0.5, t)
			var back := _ss(0.55, 0.9, t)
			var lunge := (0.18 * wind - 0.6 * strike) * (1.0 - back)
			# cluster: only the bodies facing forward really strike
			var aim := 1.0
			if cluster > 1:
				var ang: float = TAU * part.b / cluster
				aim = clampf(cos(ang) * 1.4, 0.15, 1.0)
			match kind:
				"rig":
					dp.z = lunge * body_length * 0.7 if cluster == 1 else lunge * 0.5
				"body":
					dr.x = (-0.25 * wind + 0.4 * strike) * (1.0 - back) * aim
					if cluster > 1:
						dp += Vector3(-sin(TAU * part.b / cluster), 0, -cos(TAU * part.b / cluster)) * -lunge * 0.6 * aim
				"head":
					dr.x = (-0.35 * wind + 0.6 * strike) * (1.0 - back) * aim
				"jaw":
					dr.x = 0.7 * wind * (1.0 - _ss(0.44, 0.5, t)) * aim
				"hip":
					if hind:
						dr.x = -0.5 * strike * (1.0 - back)
					if front:
						dr.x = 0.4 * wind * (1.0 - strike)
				"tail":
					dr.y = sin(t * 18.0 - part.j) * 0.2 * (1.0 - back)
		"slam":
			var up := _ss(0.0, 0.6, t)
			var down := _ss(0.6, 0.74, t)
			var back := _ss(0.9, 1.4, t)
			var rear := (up - down * 1.15) * (1.0 - back)
			match kind:
				"rig":
					dp.y = maxf(rear, 0.0) * _h * 0.35
				"body":
					dr.x = -0.85 * rear
					dp.y = maxf(rear, 0.0) * body_length * 0.25
				"head":
					dr.x = -0.3 * up * (1.0 - down) + 0.5 * down * (1.0 - back)
				"jaw":
					dr.x = 0.6 * up * (1.0 - down)
				"hip":
					if not hind:
						dr.x = -0.9 * up * (1.0 - down) + 0.3 * down * (1.0 - back)
				"knee":
					if not hind:
						dr.x = -0.6 * up * (1.0 - down)
		"spin":
			var turn := _ss(0.12, 0.85, t)
			match kind:
				"rig":
					dr.y = -TAU * turn
				"body":
					dp.y = sin(PI * turn) * 0.08
					dr.z = sin(PI * turn) * 0.2
				"head":
					dr.x = -0.3 * sin(PI * turn)
				"jaw":
					dr.x = 0.5 * sin(PI * turn)
				"tail":
					dr.y = 0.6 * sin(PI * turn)
				"hip":
					dr.x = sin(t * 30.0 + part.p) * 0.5 * sin(PI * turn)
		"hit":
			var bump := sin(PI * u)
			match kind:
				"rig":
					dp.z = 0.12 * bump
				"body":
					dr.x = -0.3 * bump
				"head":
					dr.x = -0.4 * bump
				"jaw":
					dr.x = 0.5 * bump
		"die":
			var fall := _ss(0.0, 0.55, t)
			var curl := _ss(0.3, 1.0, t)
			var twitch := sin(t * 26.0) * (1.0 - _ss(0.5, 1.2, t))
			match kind:
				"rig":
					if cluster == 1:
						dr.z = 1.45 * fall
						dp.y = -_h * 0.45 * fall
					else:
						dp.y = -_h * 0.5 * fall
				"body":
					if cluster > 1:
						dr.z = 1.3 * fall * (1.0 if part.b % 2 == 0 else -1.0)
						dp.y = -_h * 0.3 * fall
				"hip":
					dr.x = 0.4 * twitch - 0.5 * curl
				"knee":
					dr.x = -0.9 * curl
				"head":
					dr.x = 0.35 * fall
				"jaw":
					dr.x = 0.45 * fall
				"tail":
					dr.y = 0.1 * twitch
	return [dp, dr]

## Wings: folded at rest (their rest rotation), half open and beating when moving, spread
## wide for slams and pounces, limp when dying.
func _wing_pose(a: String, t: float, length: float, part: Dictionary) -> Array:
	var s: float = part.s
	var dr := Vector3.ZERO
	var u := t / length
	var w := TAU * u
	# opening: rotate back around Y toward spread (rest y = -s*1.3), raise around Z
	var open := 0.0
	var flap := 0.0
	match a:
		"idle":
			open = 0.05 + 0.04 * sin(w)
		"walk":
			open = 0.15
			flap = sin(w) * 0.1
		"run":
			open = 0.35
			flap = sin(w) * 0.3
		"attack":
			open = 0.7 * _ss(0.0, 0.35, t) * (1.0 - _ss(0.55, 0.9, t))
			flap = -0.4 * _ss(0.35, 0.5, t) * (1.0 - _ss(0.55, 0.9, t))
		"slam":
			open = _ss(0.0, 0.6, t) * (1.0 - _ss(0.9, 1.4, t))
			flap = sin(t * 14.0) * 0.4 * _ss(0.0, 0.6, t) * (1.0 - _ss(0.6, 0.8, t))
		"spin":
			open = 0.8 * sin(PI * _ss(0.1, 0.9, t))
		"hit":
			open = 0.3 * sin(PI * u)
		"die":
			open = 0.6 * _ss(0.0, 0.5, t)
			flap = -0.9 * _ss(0.3, 1.1, t)
		"perch":
			open = -0.08
		"wake":
			open = sin(PI * _ss(0.2, 0.9, t)) * 1.0
			flap = sin(t * 20.0) * 0.3 * sin(PI * _ss(0.2, 0.9, t))
		"pounce":
			open = _ss(0.25, 0.4, t) * (1.0 - _ss(0.85, 1.15, t))
			flap = sin(clampf(t - 0.35, 0.0, 9.0) * 17.0) * 0.55 * _ss(0.35, 0.45, t) * (1.0 - _ss(0.8, 0.9, t))
	dr.y = s * 1.25 * open
	dr.z = -s * (0.45 * open - flap)
	return [Vector3.ZERO, dr]
