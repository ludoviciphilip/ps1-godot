## Planted feet for characters that code moves around (lunges, attack steps, knockback, slides).
##
## When gameplay pushes the body while the animation keeps its feet still (root motion locked,
## the lunge done in code), the feet glide over the floor like on ice. PS1FootLock pins each
## planted foot to the floor in the world and, once the body has moved `stride` away from it,
## takes a quick step (lift, arc, plant) to where the animation wants it — one foot at a time,
## so a lunge turns into real footwork. Feet the animation itself lifts (kicks, steps) follow
## the animation. Legs are bent with an analytic two-bone IK that keeps the knee pointing where
## the animation had it.
##
##   var lock := PS1FootLock.attach(skeleton, $Player)   # floor = $Player's origin
##   lock.enable(true)    # during attacks / knockback
##   lock.enable(false)   # back to the plain animation (fades out)
##
## Works with Mixamo/Rigify-like names (LeftUpLeg/LeftLeg/LeftFoot, thigh/shin/foot). Godot 4.5+.
class_name PS1FootLock
extends SkeletonModifier3D

## How far (m) the body may move off a planted foot before that foot steps.
@export var stride := 0.28
## Duration of one step (s) and how high the foot lifts (m).
@export var step_time := 0.13
@export var step_height := 0.08
## The animation's own foot lifted this much above its planted height = the animation is
## stepping/kicking: follow it instead of pinning.
@export var lift_height := 0.07
## Fade times (s) of enable(true) / enable(false). Fade in fast: a lunge is over in ~0.2 s.
@export var fade_in := 0.04
@export var fade_out := 0.2
## Node whose global Y is the floor under the character (usually the CharacterBody3D).
var ground: Node3D

var _legs: Array = []
var _target_influence := 0.0
var _last_us := 0
var steps_taken := 0   # for tests: how many steps were triggered

enum { PLANTED, STEPPING, FREE }

## Adds a foot lock to `skeleton` (inactive until enable(true)). Returns null if no legs found.
static func attach(skeleton: Skeleton3D, ground_node: Node3D = null) -> PS1FootLock:
	var fl := PS1FootLock.new()
	fl.name = "PS1FootLock"
	fl.ground = ground_node
	for side in [["Left", "left", "L"], ["Right", "right", "R"]]:
		var hip := _bone(skeleton, [side[0] + "UpLeg", "thigh." + side[2], "thigh_" + side[2].to_lower(), side[1] + "_thigh"])
		var knee := _bone(skeleton, [side[0] + "Leg", "shin." + side[2], "calf_" + side[2].to_lower(), side[1] + "_shin"])
		var foot := _bone(skeleton, [side[0] + "Foot", "foot." + side[2], "foot_" + side[2].to_lower(), side[1] + "_foot"])
		if hip < 0 or knee < 0 or foot < 0:
			push_warning("PS1FootLock: %s leg bones not found" % side[0])
			continue
		fl._legs.append({hip = hip, knee = knee, foot = foot, state = PLANTED, lock = Vector3.ZERO, from = Vector3.ZERO,
			t = 0.0, rest_h = 0.0, init = false})
	if fl._legs.is_empty():
		fl.free()
		return null
	fl.influence = 0.0
	skeleton.add_child(fl)
	return fl

static func _bone(sk: Skeleton3D, names: Array) -> int:
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		for e in names:
			if n == e or n.ends_with("_" + e) or n.ends_with(":" + e):
				return i
	return -1

## Turns the lock on (feet start planted where they are now) or fades it out.
func enable(on: bool) -> void:
	_target_influence = 1.0 if on else 0.0
	if on and influence < 0.01:
		for leg in _legs:
			leg.init = false

# the fade runs here: at influence 0 Godot may skip _process_modification
func _process(delta: float) -> void:
	var f := fade_in if _target_influence > influence else fade_out
	influence = move_toward(influence, _target_influence, delta / f) if f > 0.0 else _target_influence   # Godot blends by it

func is_enabled() -> bool:
	return _target_influence > 0.5

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var now := Time.get_ticks_usec()
	var dt := clampf((now - _last_us) / 1000000.0, 0.0, 0.1) if _last_us > 0 else 0.0
	_last_us = now
	if influence <= 0.0:
		for leg in _legs:
			leg.init = false
		return
	var gt := sk.global_transform
	var floor_y := ground.global_position.y if is_instance_valid(ground) else gt.origin.y
	# planted ankle height: the lower ankle when the lock starts (one foot may be lifted)
	if not _legs[0].init:
		var low := INF
		for leg in _legs:
			low = minf(low, (gt * sk.get_bone_global_pose(leg.foot)).origin.y - floor_y)
		for leg in _legs:
			leg.rest_h = low
	for leg in _legs:
		_leg(sk, gt, floor_y, leg, dt)

func _leg(sk: Skeleton3D, gt: Transform3D, floor_y: float, leg: Dictionary, dt: float) -> void:
	var ph := sk.get_bone_global_pose(leg.hip)
	var pk := sk.get_bone_global_pose(leg.knee)
	var pf := sk.get_bone_global_pose(leg.foot)
	var anim_w: Vector3 = gt * pf.origin   # where the animation puts the ankle (world)
	if not leg.init:
		leg.init = true
		leg.state = PLANTED
		leg.lock = anim_w
	var h: float = anim_w.y - floor_y - leg.rest_h
	var other: Dictionary = _legs[1] if leg == _legs[0] and _legs.size() > 1 else _legs[0]
	match leg.state:
		PLANTED:
			if h > lift_height:
				leg.state = FREE
			else:
				var off := Vector2(anim_w.x - leg.lock.x, anim_w.z - leg.lock.z).length()
				var reach := (gt * ph.origin).distance_to(leg.lock) > _len(sk, gt, leg) * 0.995
				if (off > stride and other.state != STEPPING) or off > stride * 2.2 or reach:
					leg.state = STEPPING
					leg.from = leg.lock
					leg.t = 0.0
					steps_taken += 1
		STEPPING:
			leg.t += dt / maxf(step_time, 0.01)
			if leg.t >= 1.0:
				leg.state = PLANTED
				leg.lock = Vector3(anim_w.x, floor_y + leg.rest_h + minf(maxf(h, 0.0), lift_height * 0.5), anim_w.z)
		FREE:
			if h < lift_height * 0.5:
				leg.state = PLANTED
				leg.lock = anim_w
	var target: Vector3 = anim_w
	if leg.state == PLANTED:
		target = leg.lock
	elif leg.state == STEPPING:
		var e: float = leg.t * leg.t * (3.0 - 2.0 * leg.t)
		target = leg.from.lerp(anim_w, e)
		target.y = lerpf(leg.from.y, anim_w.y, e) + sin(PI * leg.t) * step_height
	_ik(sk, gt, leg, ph, pk, pf, target)

func _len(sk: Skeleton3D, gt: Transform3D, leg: Dictionary) -> float:
	var s := gt.basis.get_scale().x
	return (sk.get_bone_global_pose(leg.knee).origin.distance_to(sk.get_bone_global_pose(leg.hip).origin)
		+ sk.get_bone_global_pose(leg.foot).origin.distance_to(sk.get_bone_global_pose(leg.knee).origin)) * s

## Two-bone IK in skeleton space (uniform scale keeps angles); the knee stays in the plane the
## animation had it in, the foot keeps its animated orientation.
func _ik(sk: Skeleton3D, gt: Transform3D, leg: Dictionary, ph: Transform3D, pk: Transform3D, pf: Transform3D, target_w: Vector3) -> void:
	var t: Vector3 = gt.affine_inverse() * target_w
	var a := ph.origin
	var b := pk.origin
	var c := pf.origin
	var l1 := a.distance_to(b)
	var l2 := b.distance_to(c)
	var to_t := t - a
	var d := clampf(to_t.length(), absf(l1 - l2) + 0.001, (l1 + l2) * 0.9995)
	if to_t.length() < 0.0001:
		return
	var dir := to_t.normalized()
	var pole := (b - a) - (c - a).normalized() * (b - a).dot((c - a).normalized())
	pole = pole - dir * pole.dot(dir)
	if pole.length() < 0.0001:
		pole = (ph.basis.z - dir * ph.basis.z.dot(dir))
	pole = pole.normalized()
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var b2 := a + dir * (cos_a * l1) + pole * (sqrt(1.0 - cos_a * cos_a) * l1)
	var c2 := a + dir * d
	var q1 := _arc(b - a, b2 - a)
	var hip := Transform3D(Basis(q1) * ph.basis, a)
	var q2 := _arc(Basis(q1) * (c - b), c2 - b2)
	var knee := Transform3D(Basis(q2 * q1) * pk.basis, b2)
	var foot := Transform3D(pf.basis, c2)
	sk.set_bone_global_pose(leg.hip, hip)
	sk.set_bone_global_pose(leg.knee, knee)
	sk.set_bone_global_pose(leg.foot, foot)

static func _arc(from: Vector3, to: Vector3) -> Quaternion:
	var f := from.normalized()
	var t := to.normalized()
	if f.length() < 0.5 or t.length() < 0.5:
		return Quaternion.IDENTITY
	var dot := clampf(f.dot(t), -1.0, 1.0)
	if dot > 0.99999:
		return Quaternion.IDENTITY
	var axis := f.cross(t)
	if axis.length() < 0.00001:
		axis = f.cross(Vector3.UP if absf(f.y) < 0.9 else Vector3.RIGHT)
	return Quaternion(axis.normalized(), acos(dot))
