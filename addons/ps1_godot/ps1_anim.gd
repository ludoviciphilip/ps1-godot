## Animation helpers for skeletal (Mixamo-style) characters.
##
## graft(): give an upper-body animation real footwork by copying the legs/hips of another
## animation of the SAME rig (mocap step, lunge...), time-warped so the key moments line up.
##
##   var legs := PS1Anim.lower_body(skeleton)                  # Hips + legs, not the spine
##   PS1Anim.graft(ap.get_animation("my_slash"), ap.get_animation("mixamo_combo"), legs,
##       [Vector2(0.0, 0.45), Vector2(0.35, 0.98), Vector2(0.87, 1.35)])   # (dst_t, src_t)
##
## fade_in / fade_out (s) blend from / back to the animation's own pose at the ends, so it still
## starts and ends where it did (smooth transitions to idle).
## The map pairs say "at this time of my animation, use that time of the source"; times in
## between are linear. Hand-made attacks often key only the arms and torso: their legs stay in
## one frozen pose, which looks stiff. Grafting a real step underneath fixes it.
class_name PS1Anim
extends RefCounted

## Bone names under `root` (included) that are NOT under `exclude_from` (default: the spine),
## i.e. hips + legs + feet + toes for a Mixamo/Rigify-like skeleton.
static func lower_body(skeleton: Skeleton3D, root := "", exclude_from := "") -> PackedStringArray:
	var r := skeleton.find_bone(root) if root != "" else _find(skeleton, ["Hips", "hips", "pelvis", "Pelvis"])
	if r < 0:
		push_warning("PS1Anim.lower_body: root bone not found")
		return PackedStringArray()
	var ex := skeleton.find_bone(exclude_from) if exclude_from != "" else _find(skeleton, ["Spine", "spine"])
	var out := PackedStringArray()
	var stack := [r]
	while stack.size():
		var b: int = stack.pop_back()
		if b == ex:
			continue
		out.append(skeleton.get_bone_name(b))
		for c in skeleton.get_bone_children(b):
			stack.append(c)
	return out

static func _find(sk: Skeleton3D, endings: Array) -> int:
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		for e in endings:
			if n.ends_with(e) or n.ends_with("_" + e) or n.ends_with(":" + e):
				# the spine root only, not Spine1/Spine2
				return i
	return -1

## Copies the rotation (and the root's height, see `root_height_of`) tracks of `bones` from
## `src` into `dst`, sampled at `fps`, time-warped by `time_map` (Vector2(dst_t, src_t) pairs,
## increasing). weight < 1 blends with what dst already had; bone_weights overrides it per bone
## (keys = name endings, e.g. {"Hips": 0.3} keeps most of the original hip turn so the upper
## body still faces where it was animated). Returns the number of tracks written.
## root_height_of: bone whose POSITION track is also copied (vertical only, X/Z keep dst's), so
## the character crouches into the lunge; "" to skip.
static func graft(dst: Animation, src: Animation, bones: PackedStringArray, time_map: Array,
		weight := 1.0, fps := 30.0, root_height_of := "Hips", bone_weights := {}, fade_in := 0.0, fade_out := 0.0) -> int:
	var n := 0
	for bone in bones:
		var w := weight
		for k in bone_weights:
			if bone.ends_with(k):
				w = bone_weights[k]
		var s_rot := _track(src, bone, Animation.TYPE_ROTATION_3D)
		if s_rot >= 0:
			n += _copy(dst, src, s_rot, bone, Animation.TYPE_ROTATION_3D, time_map, w, fps, fade_in, fade_out)
		if root_height_of != "" and bone.ends_with(root_height_of):
			var s_pos := _track(src, bone, Animation.TYPE_POSITION_3D)
			if s_pos >= 0:
				n += _copy(dst, src, s_pos, bone, Animation.TYPE_POSITION_3D, time_map, w, fps, fade_in, fade_out)
	return n

static func _track(a: Animation, bone: String, type: int) -> int:
	for i in a.get_track_count():
		if a.track_get_type(i) == type and String(a.track_get_path(i)).get_slice(":", 1) == bone:
			return i
	return -1

static func src_time(time_map: Array, t: float) -> float:
	if time_map.is_empty():
		return t
	if t <= time_map[0].x:
		return time_map[0].y + (t - time_map[0].x)
	for i in range(1, time_map.size()):
		var a: Vector2 = time_map[i - 1]
		var b: Vector2 = time_map[i]
		if t <= b.x:
			return lerpf(a.y, b.y, (t - a.x) / maxf(b.x - a.x, 0.0001))
	var last: Vector2 = time_map[-1]
	return last.y + (t - last.x)

static func _copy(dst: Animation, src: Animation, s: int, bone: String, type: int, time_map: Array,
		weight: float, fps: float, fade_in := 0.0, fade_out := 0.0) -> int:
	var d := _track(dst, bone, type)
	var old_track := -1
	if d < 0:
		# a track path like the dst's other bones ("Skeleton3D:bone"), else the src's
		var prefix := String(src.track_get_path(s)).get_slice(":", 0)
		for i in dst.get_track_count():
			var p := String(dst.track_get_path(i))
			if p.contains(":"):
				prefix = p.get_slice(":", 0)
				break
		d = dst.add_track(type)
		dst.track_set_path(d, NodePath(prefix + ":" + bone))
	else:
		old_track = d
	# sample the old values before clearing (for blending and to keep X/Z of the root)
	var steps := maxi(int(ceil(dst.length * fps)), 1)
	var old_vals := []
	for k in steps + 1:
		var t := minf(k / fps, dst.length)
		if old_track >= 0:
			old_vals.append(dst.position_track_interpolate(d, t) if type == Animation.TYPE_POSITION_3D else dst.rotation_track_interpolate(d, t))
		else:
			old_vals.append(null)
	while dst.track_get_key_count(d) > 0:
		dst.track_remove_key(d, 0)
	var src_len := src.length
	for k in steps + 1:
		var t := minf(k / fps, dst.length)
		var st := clampf(src_time(time_map, t), 0.0, src_len)
		# envelope: blend in from / back to dst's own pose at the start / end
		var w := weight
		if fade_in > 0.0:
			w *= smoothstep(0.0, fade_in, t)
		if fade_out > 0.0:
			w *= smoothstep(0.0, fade_out, dst.length - t)
		if type == Animation.TYPE_ROTATION_3D:
			var q := src.rotation_track_interpolate(s, st)
			if old_vals[k] != null and w < 1.0:
				q = (old_vals[k] as Quaternion).slerp(q, w)
			dst.rotation_track_insert_key(d, t, q)
		else:
			var p := src.position_track_interpolate(s, st)
			if old_vals[k] != null:
				var o: Vector3 = old_vals[k]
				p = Vector3(o.x, lerpf(o.y, p.y, w), o.z)
			dst.position_track_insert_key(d, t, p)
	return 1
