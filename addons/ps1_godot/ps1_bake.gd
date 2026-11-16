## Pre-lit geometry, the way Silent Hill / Resident Evil did it: bakes scene lights (and,
## optionally, raycast shadows) into vertex colors, then switches materials to the unlit
## PS1 variant. Static geometry gets lighting + shadows for free at runtime; keep moving
## characters on lit materials.
##   await PS1Bake.bake_scene($Level, Color(0.15, 0.15, 0.2))
## Skip a mesh:   mesh_instance.set_meta("ps1_no_bake", true)
## Cutout meshes (grass, fences) never cast baked shadows.
## Bake a mesh but don't let it cast shadows (small props near lights, e.g. a sword in a
## bonfire right next to the light):   mesh_instance.set_meta("ps1_no_cast", true)
## Skip shadows from a light:   light.set_meta("ps1_no_shadow", true)
## Tip: lighting is per vertex, so subdivide big surfaces (sharper shadows need more vertices).
class_name PS1Bake

const SHADOW_LAYER := 1 << 19   # temporary collision layer used for the shadow rays

## Bakes every MeshInstance3D under root. lights = [] uses every visible Light3D in the scene.
static func bake_scene(root: Node3D, ambient: Color, shadows := true, lights: Array = [], to_unlit := true) -> void:
	var tree := root.get_tree()
	if lights.is_empty():
		lights = tree.root.find_children("*", "Light3D", true, false).filter(func(l): return l.is_visible_in_tree())
	var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	meshes = meshes.filter(func(m): return m.mesh != null and m.skin == null and m.is_visible_in_tree() and not m.has_meta("ps1_no_bake"))
	var temp: Array[Node] = []
	var space: PhysicsDirectSpaceState3D = null
	if shadows:
		for mi in meshes:
			# Cutout meshes (grass, fences) would cast solid rectangles: the rays can't see alpha.
			if mi.has_meta("ps1_no_cast") or _is_cutout(mi):
				continue
			var body := StaticBody3D.new()
			body.collision_layer = SHADOW_LAYER
			body.collision_mask = 0
			var col := CollisionShape3D.new()
			col.shape = mi.mesh.create_trimesh_shape()
			body.add_child(col)
			mi.add_child(body)
			temp.append(body)
		await tree.physics_frame
		await tree.physics_frame
		space = root.get_world_3d().direct_space_state
	for mi in meshes:
		bake_mesh(mi, ambient, lights, space, to_unlit)
	for b in temp:
		b.queue_free()

static func bake_mesh(mi: MeshInstance3D, ambient: Color, lights: Array, space: PhysicsDirectSpaceState3D = null, to_unlit := true) -> void:
	var src := mi.mesh
	var out := ArrayMesh.new()
	var xf := mi.global_transform
	var nb := xf.basis.inverse().transposed()
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms := PackedVector3Array()
		if arr[Mesh.ARRAY_NORMAL] != null:
			norms = arr[Mesh.ARRAY_NORMAL]
		var cols := PackedColorArray()
		cols.resize(verts.size())
		for i in verts.size():
			var p := xf * verts[i]
			var n := (nb * norms[i]).normalized() if i < norms.size() else Vector3.UP
			var c := ambient
			for l in lights:
				c += _light(l, p, n, space)
			# Stored at half intensity: the unlit shader multiplies by 2 (PS1-style 2x modulation).
			cols[i] = Color(minf(c.r * 0.5, 1.0), minf(c.g * 0.5, 1.0), minf(c.b * 0.5, 1.0), 1.0)
		arr[Mesh.ARRAY_COLOR] = cols
		var mat := mi.get_active_material(s)
		# PrimitiveMesh (BoxMesh, PlaneMesh...) has no surface_get_primitive_type: always triangles.
		var prim := (src as ArrayMesh).surface_get_primitive_type(s) if src is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
		out.add_surface_from_arrays(prim, arr)
		if to_unlit and PS1Convert.is_ps1(mat):
			mat = _unlit(mat)
		out.surface_set_material(s, mat)
	if to_unlit and PS1Convert.is_ps1(mi.material_override):
		mi.material_override = _unlit(mi.material_override)
	for s in mi.get_surface_override_material_count():
		mi.set_surface_override_material(s, null)
	mi.mesh = out

static func _is_cutout(mi: MeshInstance3D) -> bool:
	if PS1Convert.mode_of(mi.material_override).ends_with("cutout"):
		return true
	for s in mi.mesh.get_surface_count():
		if PS1Convert.mode_of(mi.get_active_material(s)).ends_with("cutout"):
			return true
	return false

static func _unlit(m: ShaderMaterial) -> ShaderMaterial:
	var mode := PS1Convert.mode_of(m)
	if mode.begins_with("unlit"):
		return m
	return PS1Convert.with_mode(m, "unlit_cutout" if mode == "cutout" else "unlit")

static func _light(l: Light3D, p: Vector3, n: Vector3, space: PhysicsDirectSpaceState3D) -> Color:
	# Same falloff and Lambert term as Godot's renderer, so baked and realtime lighting match.
	var to: Vector3
	var dist := 200.0
	var att := 1.0
	if l is DirectionalLight3D:
		to = l.global_basis.z
	elif l is OmniLight3D or l is SpotLight3D:
		var v := l.global_position - p
		dist = v.length()
		var r: float = l.omni_range if l is OmniLight3D else l.spot_range
		var decay: float = l.omni_attenuation if l is OmniLight3D else l.spot_attenuation
		if dist >= r or dist < 0.0001:
			return Color.BLACK
		to = v / dist
		att = _godot_attenuation(dist, 1.0 / r, decay)
		if l is SpotLight3D:
			var cos_cone := cos(deg_to_rad(l.spot_angle))
			var cos_a := (-l.global_basis.z).dot(-to)
			att *= clampf((cos_a - cos_cone) / maxf(1.0 - cos_cone, 0.0001), 0.0, 1.0)
	else:
		return Color.BLACK
	var ndl := n.dot(to)
	if ndl <= 0.0 or att <= 0.0:
		return Color.BLACK
	if space and not l.has_meta("ps1_no_shadow"):
		var q := PhysicsRayQueryParameters3D.create(p + n * 0.05, p + to * (dist - 0.05), SHADOW_LAYER)
		q.hit_back_faces = false
		if not space.intersect_ray(q).is_empty():
			return Color.BLACK
	# Calibrated against Godot's realtime vertex lighting (screenshots, same scene):
	# directional lights match with the Lambert 1/PI, omni/spot lights without it.
	var k := 1.0 / PI if l is DirectionalLight3D else 1.0
	return l.light_color * (l.light_energy * ndl * att * k)

## Godot 4's omni/spot attenuation: smooth window at the range, times distance^-decay.
static func _godot_attenuation(distance: float, inv_range: float, decay: float) -> float:
	var nd := distance * inv_range
	nd = nd * nd
	nd = nd * nd
	nd = maxf(1.0 - nd, 0.0)
	nd = nd * nd
	return nd * pow(maxf(distance, 0.0001), -decay)
