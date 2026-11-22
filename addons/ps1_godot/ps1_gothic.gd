## Low-poly gothic / medieval architecture, built in code: walls with crenellations, towers,
## spires, pointed (ogival) arches, lancet and rose windows, buttresses, gable roofs, steps.
## A builder: add shapes (each under the current `xform`), then make a mesh or a ready node.
##
##   var g := PS1Gothic.new()
##   g.wall(Vector3(0, 0, -10), 20.0, 8.0, 1.2)            # curtain wall with merlons
##   g.tower(Vector3(10, 0, -10), 2.5, 14.0)               # round tower (octagonal prism)
##   g.spire(Vector3(10, 14, -10), 2.9, 9.0)                # roof
##   g.surface("glow")                                       # next shapes go to another material
##   g.lancet(Vector3(0, 4, -9.35), 1.0, 2.6)                # glowing window
##   add_child(g.build({stone = stone_mat, glow = glow_mat}, true))   # StaticBody3D + collision
##
## Everything has real polygons for vertex lighting (faces are subdivided ~every `max_edge`
## meters) and box-projected UVs, `uv_meters` per texture repeat, so textures line up.
class_name PS1Gothic
extends RefCounted

## Transform applied to the shapes added next (position/rotation of a whole facade, etc.).
var xform := Transform3D.IDENTITY
## Meters per texture repeat.
var uv_meters := 2.0
## Faces longer than this are split (vertex lighting needs vertices).
var max_edge := 1.6

var _st := {}            # surface name -> SurfaceTool
var _cur := "stone"
var _shapes: Array = []  # [surface, Transform3D, Shape3D] for collisions (boxes / convex)

func surface(name: String) -> PS1Gothic:
	_cur = name
	return self

func _tool() -> SurfaceTool:
	if not _st.has(_cur):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[_cur] = st
	return _st[_cur]

# ------------------------------------------------------------------ primitives

func _uv(p: Vector3, n: Vector3) -> Vector2:
	var a := n.abs()
	if a.y >= a.x and a.y >= a.z:
		return Vector2(p.x, p.z) / uv_meters
	if a.x >= a.z:
		return Vector2(p.z, -p.y) / uv_meters
	return Vector2(p.x, -p.y) / uv_meters

## Quad a-b-c-d (counter-clockwise seen from the front), subdivided, in local space.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, subdivide := true) -> void:
	var st := _tool()
	var A := xform * a; var B := xform * b; var C := xform * c; var D := xform * d
	var n := (B - A).cross(D - A).normalized()
	if n == Vector3.ZERO:
		n = (C - B).cross(A - B).normalized()
	var nu := 1
	var nv := 1
	if subdivide:
		nu = clampi(int(ceil(maxf(A.distance_to(B), D.distance_to(C)) / max_edge)), 1, 24)
		nv = clampi(int(ceil(maxf(A.distance_to(D), B.distance_to(C)) / max_edge)), 1, 24)
	for i in nu:
		for j in nv:
			var u0 := float(i) / nu; var u1 := float(i + 1) / nu
			var v0 := float(j) / nv; var v1 := float(j + 1) / nv
			var p := func(u: float, v: float) -> Vector3:
				return A.lerp(B, u).lerp(D.lerp(C, u), v)
			_tri(st, p.call(u0, v0), p.call(u1, v0), p.call(u1, v1), n)
			_tri(st, p.call(u0, v0), p.call(u1, v1), p.call(u0, v1), n)

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	# Godot front faces are clockwise: emit a, c, b for a counter-clockwise quad
	for p in [a, c, b]:
		st.set_normal(n)
		st.set_uv(_uv(p, n))
		st.add_vertex(p)

## Quad/triangle wound so its front faces AWAY from `center` (organic shapes, where working out
## the winding by hand is error-prone).
func quad_away(center: Vector3, a: Vector3, b: Vector3, c: Vector3, d: Vector3, subdivide := false) -> void:
	var n := (b - a).cross(d - a)
	if n.dot((a + b + c + d) * 0.25 - center) < 0.0:
		quad(b, a, d, c, subdivide)
	else:
		quad(a, b, c, d, subdivide)

## Same, facing TOWARD `center` (insides: vaults, tunnels, rooms seen from within).
func quad_toward(center: Vector3, a: Vector3, b: Vector3, c: Vector3, d: Vector3, subdivide := false) -> void:
	var n := (b - a).cross(d - a)
	if n.dot((a + b + c + d) * 0.25 - center) > 0.0:
		quad(b, a, d, c, subdivide)
	else:
		quad(a, b, c, d, subdivide)

func tri_away(center: Vector3, a: Vector3, b: Vector3, c: Vector3) -> void:
	if (b - a).cross(c - a).dot((a + b + c) / 3.0 - center) < 0.0:
		tri(a, c, b)
	else:
		tri(a, b, c)

## Low-poly spindle (body part) along -Z from z = +length/2 (back) to -length/2 (front):
## radii at back, middle and front (the ends are rounded off); `squash` flattens it vertically.
func spindle(center: Vector3, length: float, r_back: float, r_mid: float, r_front: float, sides := 6, squash := 1.0, tip := 0.15) -> PS1Gothic:
	var zs := [length * 0.5, length * 0.27, 0.0, -length * 0.27, -length * 0.5]
	var rs := [r_back * 0.62, r_back, r_mid, lerpf(r_mid, r_front, 0.55), r_front]
	var ring := func(k: int, i: int) -> Vector3:
		var a := TAU * i / sides + PI / sides
		return center + Vector3(cos(a) * rs[k], sin(a) * rs[k] * squash, zs[k])
	for k in zs.size() - 1:
		for i in sides:
			var j := (i + 1) % sides
			var axis := center + Vector3(0, 0, (zs[k] + zs[k + 1]) * 0.5)
			quad_away(axis, ring.call(k, i), ring.call(k, j), ring.call(k + 1, j), ring.call(k + 1, i))
	var n := zs.size() - 1
	var back := center + Vector3(0, 0, length * 0.5 + tip * length * 0.5)
	var front := center + Vector3(0, 0, -length * 0.5 - tip * length)
	for i in sides:
		var j := (i + 1) % sides
		tri_away(center + Vector3(0, 0, length * 0.4), back, ring.call(0, i), ring.call(0, j))
		tri_away(center + Vector3(0, 0, -length * 0.4), front, ring.call(n, j), ring.call(n, i))
	return self

## Tapered limb between two points (legs, arms, tails, horns), `sides`-gon cross-section.
func limb(a: Vector3, b: Vector3, r_a: float, r_b: float, sides := 5) -> PS1Gothic:
	var d := (b - a).normalized()
	var side := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
	var up := side.cross(d).normalized()
	for i in sides:
		var a0 := TAU * i / sides; var a1 := TAU * (i + 1) / sides
		var o0 := side * cos(a0) + up * sin(a0); var o1 := side * cos(a1) + up * sin(a1)
		quad_away((a + b) * 0.5, a + o0 * r_a, a + o1 * r_a, b + o1 * r_b, b + o0 * r_b)
	for i in sides:
		var a0 := TAU * i / sides; var a1 := TAU * (i + 1) / sides
		var o0 := side * cos(a0) + up * sin(a0); var o1 := side * cos(a1) + up * sin(a1)
		tri_away((a + b) * 0.5, b + d * r_b, b + o0 * r_b, b + o1 * r_b)
		tri_away((a + b) * 0.5, a - d * r_a, a + o1 * r_a, a + o0 * r_a)
	return self

func tri(a: Vector3, b: Vector3, c: Vector3) -> void:
	var A := xform * a; var B := xform * b; var C := xform * c
	_tri(_tool(), A, B, C, (B - A).cross(C - A).normalized())

## Axis-aligned box (before `xform`), center + size; `rot_y` in radians. bottom=false skips the
## floor face (things standing on the ground).
func box(center: Vector3, size: Vector3, rot_y := 0.0, bottom := false, collide := true) -> PS1Gothic:
	var b := Basis(Vector3.UP, rot_y)
	var h := size * 0.5
	var c := func(x: float, y: float, z: float) -> Vector3: return center + b * Vector3(x * h.x, y * h.y, z * h.z)
	quad(c.call(-1, -1, 1), c.call(1, -1, 1), c.call(1, 1, 1), c.call(-1, 1, 1))       # +Z
	quad(c.call(1, -1, -1), c.call(-1, -1, -1), c.call(-1, 1, -1), c.call(1, 1, -1))   # -Z
	quad(c.call(1, -1, 1), c.call(1, -1, -1), c.call(1, 1, -1), c.call(1, 1, 1))       # +X
	quad(c.call(-1, -1, -1), c.call(-1, -1, 1), c.call(-1, 1, 1), c.call(-1, 1, -1))   # -X
	quad(c.call(-1, 1, 1), c.call(1, 1, 1), c.call(1, 1, -1), c.call(-1, 1, -1))       # top
	if bottom:
		quad(c.call(-1, -1, -1), c.call(1, -1, -1), c.call(1, -1, 1), c.call(-1, -1, 1))
	if collide:
		var bs := BoxShape3D.new(); bs.size = size
		_shapes.append([xform * Transform3D(b, center), bs])
	return self

## Vertical prism (towers, columns): `sides` faces, open bottom, flat top.
func prism(base: Vector3, radius: float, height: float, sides := 8, top := true, collide := true, rot := 0.0) -> PS1Gothic:
	var pts := _ring(radius, sides, rot)
	for i in sides:
		var a: Vector3 = pts[i]; var b: Vector3 = pts[(i + 1) % sides]
		quad(base + b, base + a, base + a + Vector3.UP * height, base + b + Vector3.UP * height)
	if top:
		var c := base + Vector3.UP * height
		for i in sides:
			tri(c, c + pts[(i + 1) % sides], c + pts[i])
	if collide:
		var cs := CylinderShape3D.new(); cs.radius = radius; cs.height = height
		_shapes.append([xform * Transform3D(Basis(), base + Vector3.UP * height * 0.5), cs])
	return self

func _ring(radius: float, sides: int, rot := 0.0) -> Array:
	var r := []
	for i in sides:
		var a := TAU * i / sides + rot + PI / sides
		r.append(Vector3(cos(a), 0, sin(a)) * radius)
	return r

## Cone/pyramid roof (spires). `flare` > 0 makes the eaves stick out (radius at the base).
func spire(base: Vector3, radius: float, height: float, sides := 8, rot := 0.0) -> PS1Gothic:
	var pts := _ring(radius, sides, rot)
	var tip := base + Vector3.UP * height
	# two rings so the long faces get vertices for the light
	var mid := base + Vector3.UP * height * 0.45
	for i in sides:
		var a: Vector3 = pts[i]; var b: Vector3 = pts[(i + 1) % sides]
		var am := mid + a * 0.55; var bm := mid + b * 0.55
		quad(base + b, base + a, am, bm, false)
		tri(bm, am, tip)
	# underside (seen from below when the eaves overhang)
	for i in sides:
		tri(base, base + pts[i], base + pts[(i + 1) % sides])
	return self

## Battlements along X: merlons of `merlon` width with `gap` between, on top of y = `base.y`.
func crenels(base: Vector3, length: float, height := 0.8, thickness := 0.6, merlon := 0.7, gap := 0.55, rot_y := 0.0) -> PS1Gothic:
	var n := maxi(int((length + gap) / (merlon + gap)), 1)
	var used := n * merlon + (n - 1) * gap
	var b := Basis(Vector3.UP, rot_y)
	for i in n:
		var x := -used * 0.5 + merlon * 0.5 + i * (merlon + gap)
		box(base + b * Vector3(x, height * 0.5, 0), Vector3(merlon, height, thickness), rot_y, false, false)
	return self

## Curtain wall along X centered at `base` (on the ground), with battlements.
func wall(base: Vector3, length: float, height: float, thickness := 1.0, battlements := true, rot_y := 0.0) -> PS1Gothic:
	box(base + Vector3.UP * height * 0.5, Vector3(length, height, thickness), rot_y)
	if battlements:
		var b := Basis(Vector3.UP, rot_y)
		crenels(base + Vector3.UP * height + b * Vector3(0, 0, thickness * 0.3), length, 0.8, thickness * 0.4, 0.7, 0.55, rot_y)
	return self

## Round (polygonal) tower with a corbelled parapet and battlements on top.
func tower(base: Vector3, radius: float, height: float, sides := 8, battlements := true) -> PS1Gothic:
	prism(base, radius, height, sides, true)
	if battlements:
		var top := base + Vector3.UP * height
		prism(top + Vector3.DOWN * 0.6, radius + 0.35, 0.6, sides, false, false)   # corbel ring
		var pts := _ring(radius + 0.2, sides)
		for i in sides:
			var a: Vector3 = pts[i]; var b: Vector3 = pts[(i + 1) % sides]
			var m := (a + b) * 0.5
			box(top + m + Vector3.UP * 0.45, Vector3(a.distance_to(b) * 0.55, 0.9, 0.35), -atan2(b.z - a.z, b.x - a.x), false, false)
	return self

## Points of a pointed (equilateral gothic) arch outline: from the left foot up the left jamb,
## over the apex and down to the right foot. `span` = opening width, `spring` = jamb height.
static func arch_outline(span: float, spring: float, segments := 6) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var w := span
	pts.append(Vector2(-w * 0.5, 0))
	for i in segments + 1:      # left arc: center (w/2, spring), radius w, angle 180 -> 120
		var a := PI - (PI / 3.0) * i / segments
		pts.append(Vector2(w * 0.5 + w * cos(a), spring + w * sin(a)))
	for i in range(segments - 1, -1, -1):   # right arc, mirrored
		var a := PI - (PI / 3.0) * i / segments
		pts.append(Vector2(-(w * 0.5 + w * cos(a)), spring + w * sin(a)))
	pts.append(Vector2(w * 0.5, 0))
	return pts

## Arch molding (frame band around a pointed opening) in the XY plane facing +Z, `depth` thick.
## Put it on a wall face around a dark opening or a window.
func arch(center_bottom: Vector3, span: float, spring: float, band := 0.35, depth := 0.4, segments := 6) -> PS1Gothic:
	var inner := arch_outline(span, spring, segments)
	var outer := arch_outline(span + band * 2.0, spring, segments)
	var z0 := center_bottom.z + depth * 0.5
	var z1 := center_bottom.z - depth * 0.5
	var o := Vector3(center_bottom.x, center_bottom.y, 0)
	for i in inner.size() - 1:
		var i0 := o + Vector3(inner[i].x, inner[i].y, 0); var i1 := o + Vector3(inner[i + 1].x, inner[i + 1].y, 0)
		var o0 := o + Vector3(outer[i].x, outer[i].y, 0); var o1 := o + Vector3(outer[i + 1].x, outer[i + 1].y, 0)
		var f := func(p: Vector3, z: float) -> Vector3: return Vector3(p.x, p.y, z)
		quad(f.call(i0, z0), f.call(i1, z0), f.call(o1, z0), f.call(o0, z0), false)   # front
		quad(f.call(i0, z1), f.call(o0, z1), f.call(o1, z1), f.call(i1, z1), false)   # back
		quad(f.call(i0, z0), f.call(i0, z1), f.call(i1, z1), f.call(i1, z0), false)   # soffit
		quad(f.call(o1, z0), f.call(o1, z1), f.call(o0, z1), f.call(o0, z0), false)   # outside
	return self

## Filled pointed panel (window glass, dark doorway) in the XY plane facing +Z.
func lancet(center_bottom: Vector3, span: float, spring: float, segments := 6) -> PS1Gothic:
	var pts := arch_outline(span, spring, segments)
	var o := center_bottom
	var c := o + Vector3(0, spring * 0.5, 0)
	for i in pts.size() - 1:
		tri(c, o + Vector3(pts[i + 1].x, pts[i + 1].y, 0), o + Vector3(pts[i].x, pts[i].y, 0))
	tri(c, o + Vector3(pts[0].x, pts[0].y, 0), o + Vector3(pts[pts.size() - 1].x, pts[pts.size() - 1].y, 0))
	return self

## Round rose window (disc) facing +Z.
func rose(center: Vector3, radius: float, sides := 12) -> PS1Gothic:
	for i in sides:
		var a := TAU * i / sides
		var b := TAU * (i + 1) / sides
		tri(center, center + Vector3(cos(a), sin(a), 0) * radius, center + Vector3(cos(b), sin(b), 0) * radius)
	return self

## Stone tracery for a rose window: an outer ring and `spokes` radial bars, slightly in front
## of the glass (call with your stone surface active, after rose()).
func rose_tracery(center: Vector3, radius: float, spokes := 8, bar := 0.18, depth := 0.15) -> PS1Gothic:
	var c := center + Vector3(0, 0, depth * 0.5)
	var sides := maxi(spokes * 2, 12)
	for i in sides:
		var a := TAU * i / sides; var b := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a), sin(a), 0); var d1 := Vector3(cos(b), sin(b), 0)
		quad(c + d0 * (radius - bar), c + d0 * (radius + bar * 0.5), c + d1 * (radius + bar * 0.5), c + d1 * (radius - bar), false)
	for i in spokes:
		var a := TAU * i / spokes
		var d := Vector3(cos(a), sin(a), 0)
		var s := Vector3(-d.y, d.x, 0) * bar * 0.5
		quad(c + d * radius * 0.18 - s, c + d * radius - s, c + d * radius + s, c + d * radius * 0.18 + s, false)
	quad(c + Vector3(-1, -1, 0) * radius * 0.2, c + Vector3(1, -1, 0) * radius * 0.2, c + Vector3(1, 1, 0) * radius * 0.2, c + Vector3(-1, 1, 0) * radius * 0.2, false)
	return self

## Central mullion (vertical stone bar) for a lancet window, in front of the glass.
func mullion(center_bottom: Vector3, span: float, spring: float, bar := 0.14, depth := 0.15) -> PS1Gothic:
	var h := spring + span * 0.866
	var c := center_bottom + Vector3(0, 0, depth * 0.5)
	quad(c + Vector3(-bar * 0.5, 0, 0), c + Vector3(bar * 0.5, 0, 0), c + Vector3(bar * 0.5, h, 0), c + Vector3(-bar * 0.5, h, 0), false)
	quad(c + Vector3(-span * 0.5, spring, 0), c + Vector3(span * 0.5, spring, 0), c + Vector3(span * 0.5, spring + bar, 0), c + Vector3(-span * 0.5, spring + bar, 0), false)
	return self

## Flying-buttress-like pier: a block with a sloped top, leaning against a wall at -Z.
func buttress(base: Vector3, width: float, depth: float, height: float, rot_y := 0.0) -> PS1Gothic:
	var b := Basis(Vector3.UP, rot_y)
	var hw := width * 0.5
	var low := height * 0.55
	var p := func(x: float, y: float, z: float) -> Vector3: return base + b * Vector3(x, y, z)
	# sides (trapezoids) + front + slope
	quad(p.call(hw, 0, 0), p.call(hw, 0, -depth), p.call(hw, height, -depth), p.call(hw, low, 0))
	quad(p.call(-hw, 0, -depth), p.call(-hw, 0, 0), p.call(-hw, low, 0), p.call(-hw, height, -depth))
	quad(p.call(-hw, 0, 0), p.call(hw, 0, 0), p.call(hw, low, 0), p.call(-hw, low, 0))
	quad(p.call(-hw, low, 0), p.call(hw, low, 0), p.call(hw, height, -depth), p.call(-hw, height, -depth))
	var bs := BoxShape3D.new(); bs.size = Vector3(width, low, depth)
	_shapes.append([xform * Transform3D(b, base + b * Vector3(0, low * 0.5, -depth * 0.5)), bs])
	return self

## Gable roof along X (ridge along X) over a `size` footprint, `height` tall.
func gable(base: Vector3, size: Vector2, height: float) -> PS1Gothic:
	var hx := size.x * 0.5; var hz := size.y * 0.5
	var r0 := base + Vector3(-hx, height, 0); var r1 := base + Vector3(hx, height, 0)
	quad(base + Vector3(-hx, 0, hz), base + Vector3(hx, 0, hz), r1, r0)
	quad(base + Vector3(hx, 0, -hz), base + Vector3(-hx, 0, -hz), r0, r1)
	tri(base + Vector3(hx, 0, hz), base + Vector3(hx, 0, -hz), r1)
	tri(base + Vector3(-hx, 0, -hz), base + Vector3(-hx, 0, hz), r0)
	return self

## Flight of steps going up toward -Z from `base` (front edge of the first step). Collision is a
## single ramp so characters walk up smoothly.
func steps(base: Vector3, width: float, count: int, rise := 0.2, run := 0.35) -> PS1Gothic:
	for i in count:
		var h := rise * (i + 1)
		box(base + Vector3(0, h * 0.5, -run * (i + 0.5)), Vector3(width, h, run), 0.0, false, false)
	var length := run * count
	var height := rise * count
	var ang := atan2(height, length)
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, 0.2, sqrt(length * length + height * height))
	var t := Transform3D(Basis(Vector3.RIGHT, ang), base + Vector3(0, height * 0.5 - 0.1, -length * 0.5))
	_shapes.append([xform * t, bs])
	# top landing stays solid
	return self

## Wall section with a pointed doorway through it (XY plane, facing +Z, centered on
## `center_bottom`): `wall_w` x `wall_h` x `depth`, opening `span` wide whose jambs rise
## `spring` before the arch. Collision leaves the doorway walkable.
func portal(center_bottom: Vector3, wall_w: float, wall_h: float, span: float, spring: float, depth := 1.0, segments := 6) -> PS1Gothic:
	var o := center_bottom
	var pts := arch_outline(span, spring, segments)
	var hw := wall_w * 0.5; var hs := span * 0.5
	var zf := depth * 0.5; var zb := -depth * 0.5
	var v := func(x: float, y: float, z: float) -> Vector3: return o + Vector3(x, y, z)
	# front and back: side panels + strips above the arch
	quad(v.call(-hw, 0, zf), v.call(-hs, 0, zf), v.call(-hs, wall_h, zf), v.call(-hw, wall_h, zf))
	quad(v.call(hs, 0, zf), v.call(hw, 0, zf), v.call(hw, wall_h, zf), v.call(hs, wall_h, zf))
	quad(v.call(-hs, 0, zb), v.call(-hw, 0, zb), v.call(-hw, wall_h, zb), v.call(-hs, wall_h, zb))
	quad(v.call(hw, 0, zb), v.call(hs, 0, zb), v.call(hs, wall_h, zb), v.call(hw, wall_h, zb))
	for i in range(1, pts.size() - 2):
		var a := pts[i]; var b := pts[i + 1]
		quad(v.call(a.x, a.y, zf), v.call(b.x, b.y, zf), v.call(b.x, wall_h, zf), v.call(a.x, wall_h, zf), false)
		quad(v.call(b.x, b.y, zb), v.call(a.x, a.y, zb), v.call(a.x, wall_h, zb), v.call(b.x, wall_h, zb), false)
	# reveal (inside of the opening)
	for i in pts.size() - 1:
		var a := pts[i]; var b := pts[i + 1]
		quad(v.call(a.x, a.y, zf), v.call(a.x, a.y, zb), v.call(b.x, b.y, zb), v.call(b.x, b.y, zf), i == 0 or i == pts.size() - 2)
	# ends and top
	quad(v.call(-hw, 0, zb), v.call(-hw, 0, zf), v.call(-hw, wall_h, zf), v.call(-hw, wall_h, zb))
	quad(v.call(hw, 0, zf), v.call(hw, 0, zb), v.call(hw, wall_h, zb), v.call(hw, wall_h, zf))
	quad(v.call(-hw, wall_h, zf), v.call(hw, wall_h, zf), v.call(hw, wall_h, zb), v.call(-hw, wall_h, zb))
	var apex := spring + span * 0.866
	var side_w := hw - hs
	for sx in [-1.0, 1.0]:
		var bs := BoxShape3D.new(); bs.size = Vector3(side_w, wall_h, depth)
		_shapes.append([xform * Transform3D(Basis(), o + Vector3(sx * (hs + side_w * 0.5), wall_h * 0.5, 0)), bs])
	var top_y := spring + (apex - spring) * 0.55
	var tb := BoxShape3D.new(); tb.size = Vector3(span, wall_h - top_y, depth)
	_shapes.append([xform * Transform3D(Basis(), o + Vector3(0, (wall_h + top_y) * 0.5, 0)), tb])
	return self

## Iron/stone brazier: stand and a flared bowl. The fire (sprite + light) is up to you; its
## center is `base + (0, height + 0.1, 0)`.
func brazier(base: Vector3, height := 1.0, radius := 0.45) -> PS1Gothic:
	prism(base, radius * 0.6, 0.15, 6, true, false)
	prism(base + Vector3.UP * 0.15, radius * 0.2, height - 0.4, 6, false, false)
	var b0 := base + Vector3.UP * (height - 0.25)
	var b1 := base + Vector3.UP * height
	var r0 := _ring(radius * 0.35, 8); var r1 := _ring(radius, 8)
	for i in 8:
		var j := (i + 1) % 8
		quad(b0 + r0[j], b0 + r0[i], b1 + r1[i], b1 + r1[j], false)   # outside
		quad(b0 + r0[i], b0 + r0[j], b1 + r1[j], b1 + r1[i], false)   # inside
	var cs := CylinderShape3D.new(); cs.radius = radius * 0.6; cs.height = height
	_shapes.append([xform * Transform3D(Basis(), base + Vector3.UP * height * 0.5), cs])
	return self

## Irregular rock / rubble chunk (jittered octahedron-ish blob), deterministic per seed.
func rock(center: Vector3, size: Vector3, seed_ := 1, collide := false) -> PS1Gothic:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var ring := 6
	var pts := []
	for i in ring:
		var a := TAU * i / ring + rng.randf_range(-0.3, 0.3)
		pts.append(center + Vector3(cos(a) * size.x * 0.5 * rng.randf_range(0.7, 1.0),
			rng.randf_range(-0.15, 0.15) * size.y, sin(a) * size.z * 0.5 * rng.randf_range(0.7, 1.0)))
	var top := center + Vector3(rng.randf_range(-0.15, 0.15) * size.x, size.y * 0.5, rng.randf_range(-0.15, 0.15) * size.z)
	var bot := center + Vector3(0, -size.y * 0.45, 0)
	for i in ring:
		var a: Vector3 = pts[i]; var b: Vector3 = pts[(i + 1) % ring]
		tri_away(center, top, a, b)
		tri_away(center, bot, b, a)
	if collide:
		var bs := BoxShape3D.new(); bs.size = size * 0.8
		_shapes.append([xform * Transform3D(Basis(), center), bs])
	return self

## Sewer tunnel along -Z from `start` (walkway level): a sunken channel (`channel_w` wide,
## `channel_d` deep) between two walkways, side walls and a barrel vault. `bridges` are
## distances from the start where a stone slab crosses the channel; elsewhere an invisible
## railing keeps characters from dropping into it (no jump needed to get out). Put water on
## top of the channel floor (e.g. a PS1Water at start.y - channel_d + 0.35).
func sewer(start: Vector3, length: float, width := 8.0, height := 4.5, channel_w := 1.8, channel_d := 1.0,
		bridges := PackedFloat32Array(), rail_height := 1.4, vault_segments := 6, end_grates := true,
		grate_surface := "") -> PS1Gothic:
	if grate_surface == "":
		grate_surface = _cur
	var hw := width * 0.5
	var hc := channel_w * 0.5
	var z0 := start.z
	var z1 := start.z - length
	var zc := (z0 + z1) * 0.5
	var y := start.y
	var x := start.x
	for sx in [-1.0, 1.0]:
		box(Vector3(x + sx * (hc + (hw - hc) * 0.5), y - 0.25, zc), Vector3(hw - hc, 0.5, length), 0.0, false)
		# stone curb along the channel
		box(Vector3(x + sx * (hc + 0.15), y + 0.1, zc), Vector3(0.3, 0.2, length), 0.0, false, false)
	box(Vector3(x, y - channel_d - 0.25, zc), Vector3(channel_w, 0.5, length), 0.0, false)
	for sx in [-1.0, 1.0]:
		quad_toward(Vector3(x, y - channel_d * 0.5, zc), Vector3(x + sx * hc, y - channel_d, z0), Vector3(x + sx * hc, y - channel_d, z1),
			Vector3(x + sx * hc, y, z1), Vector3(x + sx * hc, y, z0), true)
	# bridges + railings between them
	var cuts := [0.0]
	for bz in bridges:
		box(Vector3(x, y - 0.15, z0 - bz), Vector3(channel_w + 0.6, 0.3, 1.8), 0.0, true)
		cuts.append(bz - 1.0)
		cuts.append(bz + 1.0)
		# low stone curbs on both sides of the bridge + invisible railing over the water, so
		# crossing at an angle can't drop you in
		for sz in [-1.0, 1.0]:
			var ez: float = z0 - bz + sz * 0.8
			box(Vector3(x, y + 0.15, ez), Vector3(channel_w + 0.2, 0.3, 0.2), 0.0, true, false)
			var rs := BoxShape3D.new(); rs.size = Vector3(channel_w + 0.4, rail_height, 0.25)
			_shapes.append([xform * Transform3D(Basis(), Vector3(x, y + rail_height * 0.5, ez + sz * 0.12)), rs])
	cuts.append(length)
	for k in range(0, cuts.size(), 2):
		var a: float = cuts[k]
		var b: float = cuts[k + 1]
		if b - a < 0.2:
			continue
		for sx in [-1.0, 1.0]:
			var bs := BoxShape3D.new(); bs.size = Vector3(0.2, rail_height, b - a)
			_shapes.append([xform * Transform3D(Basis(), Vector3(x + sx * (hc + 0.1), y + rail_height * 0.5, z0 - (a + b) * 0.5)), bs])
	# both ends: an iron grate across the channel (the water runs under it) closes the trench,
	# so nobody walks in from the rooms the tunnel connects
	if end_grates:
		for zz in [z0 - 0.15, z1 + 0.15]:
			var gs := BoxShape3D.new(); gs.size = Vector3(channel_w + 0.4, rail_height + channel_d, 0.3)
			_shapes.append([xform * Transform3D(Basis(), Vector3(x, y - channel_d + (rail_height + channel_d) * 0.5, zz)), gs])
			var old := _cur
			surface(grate_surface)
			box(Vector3(x, y + 0.45, zz), Vector3(channel_w + 0.3, 0.12, 0.12), 0.0, true, false)
			for k in 7:
				var bx := x - channel_w * 0.5 + channel_w * (k + 0.5) / 7.0
				box(Vector3(bx, y - channel_d * 0.5 + 0.2, zz), Vector3(0.07, channel_d + 0.5, 0.07), 0.0, true, false)
			surface(old)
	var spring := height - hw * 0.6
	for sx in [-1.0, 1.0]:
		box(Vector3(x + sx * (hw + 0.3), y + spring * 0.5, zc), Vector3(0.6, spring, length))
	var prev := Vector3(x - hw, y + spring, 0)
	for i in range(1, vault_segments + 1):
		var a := PI - PI * i / vault_segments
		var p := Vector3(x + cos(a) * hw, y + spring + sin(a) * hw * 0.6, 0)
		quad_toward(Vector3(x, y + spring - 1.0, zc), Vector3(prev.x, prev.y, z0), Vector3(p.x, p.y, z0), Vector3(p.x, p.y, z1), Vector3(prev.x, prev.y, z1), true)
		prev = p
	return self

## Closed room seen from inside: floor, flat ceiling and walls (0.6 m thick) with door gaps.
## `center` is the floor center; `size` = (width x, height, depth z). `doors` items are
## Vector3(side, offset, width): side 0 = north (-Z), 1 = east, 2 = south, 3 = west; offset
## along the wall from its middle. Doors are `door_h` tall (lintel above).
func room(center: Vector3, size: Vector3, doors: Array = [], door_h := 4.5, ceiling := true) -> PS1Gothic:
	var w := size.x; var h := size.y; var d := size.z
	box(center + Vector3(0, -0.25, 0), Vector3(w, 0.5, d), 0.0, false)
	if ceiling:
		box(center + Vector3(0, h + 0.25, 0), Vector3(w, 0.5, d), 0.0, true)
	for side in 4:
		var along_x := side % 2 == 0
		var length := w if along_x else d
		var wall_c: Vector3
		match side:
			0: wall_c = center + Vector3(0, 0, -d * 0.5 - 0.3)
			1: wall_c = center + Vector3(w * 0.5 + 0.3, 0, 0)
			2: wall_c = center + Vector3(0, 0, d * 0.5 + 0.3)
			3: wall_c = center + Vector3(-w * 0.5 - 0.3, 0, 0)
		var gaps := []
		for dr in doors:
			if int(dr.x) == side:
				gaps.append([dr.y - dr.z * 0.5, dr.y + dr.z * 0.5])
		gaps.sort_custom(func(a, b): return a[0] < b[0])
		var t := -length * 0.5 - (0.6 if along_x else 0.0)
		var end := length * 0.5 + (0.6 if along_x else 0.0)
		var spans := []
		for g in gaps:
			spans.append([t, g[0]])
			t = g[1]
			# lintel over the door
			var mid: float = (g[0] + g[1]) * 0.5
			var lw: float = g[1] - g[0]
			var lc := wall_c + (Vector3(mid, door_h + (h - door_h) * 0.5, 0) if along_x else Vector3(0, door_h + (h - door_h) * 0.5, mid))
			if h - door_h > 0.05:
				box(lc, Vector3(lw, h - door_h, 0.6) if along_x else Vector3(0.6, h - door_h, lw))
			# threshold: floor under the doorway (the wall is outside the room's floor), or two
			# rooms joined at a door leave a gap you fall into
			var tc := wall_c + (Vector3(mid, -0.25, 0) if along_x else Vector3(0, -0.25, mid))
			box(tc, Vector3(lw, 0.5, 0.62) if along_x else Vector3(0.62, 0.5, lw), 0.0, false)
		spans.append([t, end])
		for sp in spans:
			var a: float = sp[0]
			var b: float = sp[1]
			if b - a < 0.05:
				continue
			var m := (a + b) * 0.5
			var c := wall_c + (Vector3(m, h * 0.5, 0) if along_x else Vector3(0, h * 0.5, m))
			box(c, Vector3(b - a, h, 0.6) if along_x else Vector3(0.6, h, b - a))
	return self

## Ruined tower stump: like tower() but the top is broken into uneven chunks.
func ruined_tower(base: Vector3, radius: float, height: float, seed_ := 1, sides := 8) -> PS1Gothic:
	prism(base, radius, height, sides, true)
	var rng := RandomNumberGenerator.new(); rng.seed = seed_
	var pts := _ring(radius - 0.15, sides)
	for i in sides:
		if rng.randf() < 0.35:
			continue
		var a: Vector3 = pts[i]; var b: Vector3 = pts[(i + 1) % sides]
		var h := rng.randf_range(0.4, 2.2)
		box(base + Vector3.UP * (height + h * 0.5) + (a + b) * 0.5, Vector3(a.distance_to(b) * 0.9, h, 0.5),
			-atan2(b.z - a.z, b.x - a.x), false, false)
	return self

# ------------------------------------------------------------------ props

## Gothic pier: plinth, octagonal shaft, capital. `broken` > 0 cuts it at that fraction with a
## slanted break (ruins).
func column(base: Vector3, radius: float, height: float, broken := 0.0) -> PS1Gothic:
	box(base + Vector3.UP * 0.25, Vector3(radius * 2.6, 0.5, radius * 2.6))
	var h := height if broken <= 0.0 else height * broken
	prism(base + Vector3.UP * 0.5, radius, h - 0.5, 8, broken > 0.0, true)
	if broken <= 0.0:
		box(base + Vector3.UP * (height + 0.2), Vector3(radius * 2.8, 0.4, radius * 2.8), 0.0, true, false)
	else:
		# jagged stub on top of the break
		var t := base + Vector3.UP * h
		tri(t + Vector3(-radius, 0, 0), t + Vector3(0, radius * 1.2, radius * 0.3), t + Vector3(radius, 0, 0))
		tri(t + Vector3(radius, 0, 0), t + Vector3(0, radius * 1.2, radius * 0.3), t + Vector3(-radius, 0, 0))
	return self

## Rounded-top tombstone, slightly tilted by `lean` (radians) toward +Z.
func tombstone(base: Vector3, width := 0.6, height := 0.9, rot_y := 0.0, lean := 0.0) -> PS1Gothic:
	var old := xform
	xform = xform * Transform3D(Basis(Vector3.UP, rot_y) * Basis(Vector3.RIGHT, lean), base)
	box(Vector3(0, height * 0.4, 0), Vector3(width, height * 0.8, 0.16), 0.0, false, false)
	_solid(Vector3(0, height * 0.5, 0), Vector3(width, height, 0.3))
	var pts := 5
	for i in pts:
		var a0 := PI * i / pts
		var a1 := PI * (i + 1) / pts
		var r := width * 0.5
		var c := Vector3(0, height * 0.8, 0)
		var p0 := c + Vector3(cos(a0) * r, sin(a0) * r * 0.5, 0)
		var p1 := c + Vector3(cos(a1) * r, sin(a1) * r * 0.5, 0)
		var f := Vector3(0, 0, 0.08)
		tri(c + f, p0 + f, p1 + f)
		tri(c - f, p1 - f, p0 - f)
		quad(p1 + f, p0 + f, p0 - f, p1 - f, false)
	xform = old
	return self

## Stone or wooden grave cross.
func cross(base: Vector3, height := 1.3, rot_y := 0.0, lean := 0.0, thick := 0.14) -> PS1Gothic:
	var old := xform
	xform = xform * Transform3D(Basis(Vector3.UP, rot_y) * Basis(Vector3.RIGHT, lean), base)
	box(Vector3(0, height * 0.5, 0), Vector3(thick, height, thick), 0.0, false, false)
	box(Vector3(0, height * 0.72, 0), Vector3(height * 0.55, thick, thick), 0.0, true, false)
	_solid(Vector3(0, height * 0.5, 0), Vector3(maxf(thick, 0.3), height, maxf(thick, 0.3)))
	xform = old
	return self

## A sword stuck in the ground (fallen warrior's grave): blade, guard, grip, pommel.
func grave_sword(base: Vector3, rot_y := 0.0, lean := 0.0, length := 1.1) -> PS1Gothic:
	var old := xform
	xform = xform * Transform3D(Basis(Vector3.UP, rot_y) * Basis(Vector3.RIGHT, lean), base)
	box(Vector3(0, length * 0.35, 0), Vector3(0.08, length * 0.7, 0.025), 0.0, false, false)
	box(Vector3(0, length * 0.72, 0), Vector3(0.36, 0.05, 0.06), 0.0, true, false)
	box(Vector3(0, length * 0.84, 0), Vector3(0.045, length * 0.2, 0.045), 0.0, false, false)
	box(Vector3(0, length * 0.96, 0), Vector3(0.08, 0.06, 0.08), 0.0, true, false)
	_solid(Vector3(0, length * 0.5, 0), Vector3(0.36, length, 0.3))
	xform = old
	return self

## Collision box (in the current `xform`) for props whose visible parts don't collide.
## `props_collide = false` turns it off for every prop (tombstones, crosses, grave swords).
var props_collide := true

func _solid(center: Vector3, size: Vector3) -> void:
	if not props_collide:
		return
	var bs := BoxShape3D.new(); bs.size = size
	_shapes.append([xform * Transform3D(Basis(), center), bs])

## Leafless, gnarled tree: tapered trunk and branches that split `depth` times. Deterministic
## per seed. Use a bark material.
func dead_tree(base: Vector3, height := 5.0, seed_ := 1, depth := 3) -> PS1Gothic:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	_branch(base, Vector3(rng.randf_range(-0.15, 0.15), 1, rng.randf_range(-0.15, 0.15)).normalized(),
		height * 0.45, height * 0.035, depth, rng)
	var cs := CylinderShape3D.new(); cs.radius = height * 0.04; cs.height = height * 0.45
	_shapes.append([xform * Transform3D(Basis(), base + Vector3.UP * height * 0.22), cs])
	return self

func _branch(from: Vector3, dir: Vector3, length: float, radius: float, depth: int, rng: RandomNumberGenerator) -> void:
	var to := from + dir * length
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	var up := side.cross(dir).normalized()
	var r1 := radius * 0.62
	var s := 5
	for i in s:
		var a0 := TAU * i / s; var a1 := TAU * (i + 1) / s
		var o0 := side * cos(a0) + up * sin(a0); var o1 := side * cos(a1) + up * sin(a1)
		quad(from + o1 * radius, from + o0 * radius, to + o0 * r1, to + o1 * r1, false)
	if depth <= 0:
		return
	var n := 2 if depth > 1 else rng.randi_range(2, 3)
	for k in n:
		var bend := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.1, 0.6), rng.randf_range(-1, 1)).normalized()
		var nd := (dir + bend * rng.randf_range(0.6, 1.1)).normalized()
		_branch(to, nd, length * rng.randf_range(0.55, 0.75), r1, depth - 1, rng)

## Gothic pinnacle / monument: square base, open arcade of 4 thin columns, little spire.
func pinnacle(base: Vector3, width := 1.6, height := 4.0) -> PS1Gothic:
	var w := width
	box(base + Vector3.UP * 0.4, Vector3(w, 0.8, w))
	var ch := height * 0.45
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			prism(base + Vector3(sx * w * 0.36, 0.8, sz * w * 0.36), w * 0.08, ch, 6, false, false)
	box(base + Vector3.UP * (0.8 + ch + 0.15), Vector3(w * 1.05, 0.3, w * 1.05), 0.0, true, false)
	spire(base + Vector3.UP * (0.8 + ch + 0.3), w * 0.62, height - ch - 1.1, 4, PI / 4.0)
	return self

# ------------------------------------------------------------------ output

## ArrayMesh with one surface per surface name used (order: sorted by name). Returns also the
## names in `surface_names`.
var surface_names: PackedStringArray = []

func mesh() -> ArrayMesh:
	var m := ArrayMesh.new()
	surface_names = PackedStringArray()
	var names: Array = _st.keys()
	names.sort()
	for n in names:
		var st: SurfaceTool = _st[n]
		st.commit(m)
		m.surface_set_name(m.get_surface_count() - 1, n)
		surface_names.append(n)
	return m

## Node ready to add: MeshInstance3D with the materials per surface name (missing names fall
## back to the first material); with collide=true, a StaticBody3D with box/cylinder shapes.
func build(materials: Dictionary, collide := true) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh()
	for i in surface_names.size():
		var mat = materials.get(surface_names[i], materials.values()[0] if materials.size() else null)
		mi.set_surface_override_material(i, mat)
	if not collide:
		return mi
	var body := StaticBody3D.new()
	body.add_child(mi)
	for s in _shapes:
		var cs := CollisionShape3D.new()
		cs.shape = s[1]
		cs.transform = s[0]
		body.add_child(cs)
	return body
