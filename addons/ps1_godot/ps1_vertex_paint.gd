## Vertex-color painting helpers: the cheap tricks PS1 games used instead of real lighting detail.
## Paint is stored in the mesh's vertex colors; PS1 materials show it (use_vertex_color) and
## PS1Bake MULTIPLIES its light by it, so paint survives baking.
##
##   PS1VertexPaint.gradient($Level, Color(0.35, 0.33, 0.4), Color.WHITE, 0.0, 3.0)  # dark floors
##   await PS1VertexPaint.ambient_occlusion($Level)                              # corners, crevices
##   PS1VertexPaint.grime($Level, 0.2)                                           # dirt variation
##   PS1VertexPaint.clear($Level)
##
## Every helper works on a node and all MeshInstance3D below it (meta "ps1_no_paint" skips one).
## Meshes are made unique first, so painting one piece doesn't paint every copy of it.
## For levels, prefer the "Vertex paint" options of PS1BakedLevel/PS1GridLevel: the paint is
## applied when baking and stored in the bake cache (painted instanced pieces aren't saved
## in the level scene). Editor: 3D toolbar > "PS1 Paint" for meshes your scene owns.
@tool
class_name PS1VertexPaint
extends RefCounted

enum Blend { MULTIPLY, REPLACE }

## true = every paint call gives the mesh a NEW ArrayMesh (the editor uses it so undo can swap
## the old mesh back).
static var always_new := false

static func meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var all: Array = ([node] if node is MeshInstance3D else []) + node.find_children("*", "MeshInstance3D", true, false)
	for n in all:
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.has_meta("ps1_no_paint") or mi.has_meta("ps1_no_bake"):
			continue
		out.append(mi)
	return out

## Makes mi.mesh an ArrayMesh owned by this node (PrimitiveMeshes can't hold vertex colors) and
## returns it. Surface materials are kept.
static func own_mesh(mi: MeshInstance3D) -> ArrayMesh:
	var src := mi.mesh
	if not always_new and src is ArrayMesh and src.has_meta("ps1_painted_owner") and src.get_meta("ps1_painted_owner") == mi.get_instance_id():
		return src
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var prim := (src as ArrayMesh).surface_get_primitive_type(s) if src is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
		out.add_surface_from_arrays(prim, src.surface_get_arrays(s))
		out.surface_set_material(s, src.surface_get_material(s))
		if src is ArrayMesh:
			out.surface_set_name(s, (src as ArrayMesh).surface_get_name(s))
	out.set_meta("ps1_painted_owner", mi.get_instance_id())
	mi.mesh = out
	_enable_vertex_color(mi)
	return out

static func _enable_vertex_color(mi: MeshInstance3D) -> void:
	var mats: Array = [mi.material_override] if mi.material_override else []
	for s in mi.mesh.get_surface_count():
		mats.append(mi.get_active_material(s))
	for m in mats:
		if m is ShaderMaterial and PS1Convert.is_ps1(m) and not m.get_shader_parameter("use_vertex_color"):
			m.set_shader_parameter("use_vertex_color", true)

## Calls f(world_pos, world_normal, old_color) -> Color for every vertex.
static func paint(node: Node, f: Callable) -> int:
	var count := 0
	for mi in meshes(node):
		var m := own_mesh(mi)
		var xf := mi.global_transform
		var nb := xf.basis.inverse().transposed()
		var arrays := []
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nrm = arr[Mesh.ARRAY_NORMAL]
			var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			if cols.size() != v.size():
				cols.resize(v.size())
				cols.fill(Color.WHITE)
			for i in v.size():
				var n: Vector3 = (nb * nrm[i]).normalized() if nrm != null and i < nrm.size() else Vector3.UP
				cols[i] = f.call(xf * v[i], n, cols[i])
			arr[Mesh.ARRAY_COLOR] = cols
			count += v.size()
			arrays.append([m.surface_get_primitive_type(s), arr, m.surface_get_material(s), m.surface_get_name(s)])
		m.clear_surfaces()
		for a in arrays:
			m.add_surface_from_arrays(a[0], a[1])
			var s := m.get_surface_count() - 1
			m.surface_set_material(s, a[2])
			m.surface_set_name(s, a[3])
	return count

static func _mix(old: Color, c: Color, blend: Blend) -> Color:
	return Color(old.r * c.r, old.g * c.g, old.b * c.b, old.a) if blend == Blend.MULTIPLY else Color(c.r, c.g, c.b, old.a)

static func fill(node: Node, color: Color, blend := Blend.REPLACE) -> int:
	return paint(node, func(_p, _n, old): return _mix(old, color, blend))

## Back to white (no paint).
static func clear(node: Node) -> int:
	return fill(node, Color.WHITE, Blend.REPLACE)

## World-space height gradient: `bottom` at y0 and below, `top` at y1 and above (stepped into
## `steps` bands, 0 = smooth). Classic use: darker floors and wall bases, like fog pooling.
static func gradient(node: Node, bottom: Color, top: Color, y0: float, y1: float, steps := 0, blend := Blend.MULTIPLY) -> int:
	return paint(node, func(p, _n, old):
		var t := clampf(inverse_lerp(y0, y1, p.y), 0.0, 1.0) if y1 != y0 else 1.0
		if steps > 0:
			t = floorf(t * steps + 0.5) / steps
		return _mix(old, bottom.lerp(top, t), blend))

## Grime: per-vertex brightness variation (hashed from the world position, so vertices shared by
## two faces/pieces get the same value: no seams). amount 0..1.
static func grime(node: Node, amount := 0.2, scale := 1.3, tint := Color(0.85, 0.8, 0.7), seed := 0) -> int:
	return paint(node, func(p, _n, old):
		var q: Vector3 = (p / scale).snapped(Vector3.ONE * 0.01)
		var h := float(hash(Vector3i(q * 100.0) + Vector3i(seed, seed * 7, seed * 13)) % 1000) / 1000.0
		var k := 1.0 - amount * h
		return _mix(old, Color.WHITE.lerp(tint, amount * h) * k, Blend.MULTIPLY))

## Ambient occlusion by raycasting a hemisphere at every vertex against the physics world
## (geometry needs collision shapes). Darkens corners, floor/wall joints, under props.
## Coroutine (waits a physics frame). strength 0..1, radius in meters.
## mask: physics layers that occlude (default 1 = static world; characters don't count).
static func ambient_occlusion(node: Node, radius := 1.2, strength := 0.6, samples := 12, tint := Color(0.75, 0.72, 0.85), mask := 1) -> int:
	var n3 := node as Node3D if node is Node3D else (node.find_children("*", "Node3D", true, false).front() if node.find_children("*", "Node3D", true, false).size() else null)
	if n3 == null:
		return 0
	await n3.get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = n3.get_world_3d().direct_space_state
	var dirs := _hemisphere(samples)
	var q := PhysicsRayQueryParameters3D.new()
	q.hit_back_faces = false
	q.collision_mask = mask
	return paint(node, func(p, n, old):
		var basis: Basis = Basis(Quaternion(Vector3.UP, n)) if n.dot(Vector3.UP) > -0.999 else Basis(Vector3.RIGHT, PI)
		var occ := 0.0
		for d in dirs:
			q.from = p + n * 0.03
			q.to = q.from + basis * d * radius
			var hit: Dictionary = space.intersect_ray(q)
			if hit:
				occ += 1.0 - (hit.position - q.from).length() / radius
		var a := clampf(occ / dirs.size() * 2.0 * strength, 0.0, 1.0)
		return _mix(old, Color.WHITE.lerp(tint * (1.0 - a * 0.5), a), Blend.MULTIPLY))

## Evenly spread cosine-weighted directions around +Y (deterministic: no noise between runs).
static func _hemisphere(n: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var ga := PI * (3.0 - sqrt(5.0))
	for i in n:
		var r := sqrt((i + 0.5) / n)
		var a := i * ga
		out.append(Vector3(r * cos(a), sqrt(maxf(0.0, 1.0 - r * r)), r * sin(a)))
	return out
