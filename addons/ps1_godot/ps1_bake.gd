## Pre-lit geometry, the way Silent Hill / Resident Evil did it: bakes scene lights (and,
## optionally, raycast shadows) into vertex colors, then switches materials to the unlit
## PS1 variant. Static geometry gets lighting + shadows for free at runtime; keep moving
## characters on lit materials.
##   await PS1Bake.bake_scene($Level, Color(0.15, 0.15, 0.2))
## Skip a mesh (or a light that changes at runtime):   node.set_meta("ps1_no_bake", true)
## Cutout meshes (grass, fences) never cast baked shadows.
## Bake a mesh but don't let it cast shadows (small props near lights, e.g. a sword in a
## bonfire right next to the light):   mesh_instance.set_meta("ps1_no_cast", true)
## Skip shadows from a light:   light.set_meta("ps1_no_shadow", true)
## Tip: lighting is per vertex, so subdivide big surfaces (sharper shadows need more vertices).
##
## Bake once, load instantly: bake_scene_cached() saves the baked meshes to a resource and
## reuses them while the scene (meshes, transforms, lights) is unchanged. Run the scene once
## from the editor and ship the cache file with the game (res:// is read-only in exports).
class_name PS1Bake

const SHADOW_LAYER := 1 << 19   # temporary collision layer used for the shadow rays

## Bakes every MeshInstance3D under root. lights = [] uses every visible Light3D in the scene.
static func bake_scene(root: Node3D, ambient: Color, shadows := true, lights: Array = [], to_unlit := true) -> void:
	var tree := root.get_tree()
	if lights.is_empty():
		lights = _scene_lights(tree)
	var meshes := _bakeable(root)
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

## Like bake_scene(), but loads the result from cache_path when it is still valid and saves
## it after a fresh bake. Returns true if the cache was used.
## extra_sig: anything else that changes the result (e.g. vertex-paint settings).
## before_bake: awaited only when the cache is stale, right before baking (vertex paint).
static func bake_scene_cached(root: Node3D, ambient: Color, cache_path := "", shadows := true, lights: Array = [],
		extra_sig := "", before_bake := Callable()) -> bool:
	var tree := root.get_tree()
	if lights.is_empty():
		lights = _scene_lights(tree)
	if cache_path == "":
		var scene_file := tree.current_scene.scene_file_path if tree.current_scene else ""
		cache_path = "res://ps1_bake_cache/%s_%s.res" % [scene_file.get_file().get_basename() if scene_file else "scene", root.name]
	var meshes := _bakeable(root)
	var sig := (_signature(root, meshes, lights, ambient, shadows) + extra_sig).md5_text()
	if ResourceLoader.exists(cache_path):
		var cache := load(cache_path) as PS1BakeCache
		if cache and cache.signature == sig:
			for mi in meshes:
				var key := _key(root, mi)
				if cache.meshes.has(key):
					_apply_baked(mi, cache.meshes[key])
			return true
	if before_bake.is_valid():
		await before_bake.call()
	await bake_scene(root, ambient, shadows, lights)
	var out := PS1BakeCache.new()
	out.signature = sig
	for mi in meshes:
		out.meshes[_key(root, mi)] = [mi.mesh, mi.material_override]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache_path.get_base_dir()))
	var err := ResourceSaver.save(out, cache_path)
	if err != OK and OS.has_feature("editor"):
		push_warning("PS1Bake: could not save cache to %s (%s)" % [cache_path, error_string(err)])
	return false

## Stable key for a node: its child-index path from root (auto-generated names like
## "@MeshInstance3D@42" change between runs, indices don't).
static func _key(root: Node, n: Node) -> String:
	var idx := PackedStringArray()
	while n != root and n != null:
		idx.append(str(n.get_index()))
		n = n.get_parent()
	idx.reverse()
	return "/".join(idx)

static func _apply_baked(mi: MeshInstance3D, data: Array) -> void:
	mi.mesh = data[0]
	mi.material_override = data[1]
	for s in mi.get_surface_override_material_count():
		mi.set_surface_override_material(s, null)

static func _scene_lights(tree: SceneTree) -> Array:
	# Lights that change at runtime (a bonfire you light) opt out with meta "ps1_no_bake".
	return tree.root.find_children("*", "Light3D", true, false).filter(
		func(l): return l.is_visible_in_tree() and not l.has_meta("ps1_no_bake"))

static func _bakeable(root: Node3D) -> Array:
	var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	return meshes.filter(func(m): return m.mesh != null and m.skin == null and m.is_visible_in_tree() and not m.has_meta("ps1_no_bake"))

## Changes when geometry, transforms, materials' modes or lights change (then the cache is rebuilt).
static func _signature(root: Node3D, meshes: Array, lights: Array, ambient: Color, shadows: bool) -> String:
	var parts := PackedStringArray([str(ambient), str(shadows), "v3"])
	for mi in meshes:
		var vcount := 0
		var paint_sum := 0.0
		for s in mi.mesh.get_surface_count():
			var sa: Array = mi.mesh.surface_get_arrays(s)
			vcount += (sa[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			if sa[Mesh.ARRAY_COLOR] != null:
				for c in (sa[Mesh.ARRAY_COLOR] as PackedColorArray):
					paint_sum += c.r * 1.0 + c.g * 3.0 + c.b * 7.0
		# node class + texture too: swapping a piece (or its texture) must invalidate the cache,
		# otherwise baked meshes get applied to the wrong nodes
		var tex = mi.material_override.get_shader_parameter("albedo_tex") if mi.material_override is ShaderMaterial else null
		parts.append("%s|%s|%d|%.3f|%s|%s|%s|%s|%s" % [_key(root, mi), mi.global_transform, vcount, paint_sum,
			PS1Convert.mode_of(mi.material_override), mi.has_meta("ps1_no_cast"), mi.mesh.get_class(), mi.get_class(),
			tex.resource_path if tex is Resource else ""])
	for l in lights:
		parts.append("%s|%s|%s|%s|%s" % [l.get_class(), l.global_transform, l.light_color, l.light_energy,
			[l.get("omni_range"), l.get("omni_attenuation"), l.get("spot_range"), l.get("spot_angle")]])
	return "|".join(parts).md5_text()

static func bake_mesh(mi: MeshInstance3D, ambient: Color, lights: Array, space: PhysicsDirectSpaceState3D = null, to_unlit := true) -> void:
	var src := mi.mesh
	var out := ArrayMesh.new()
	var xf := mi.global_transform
	var nb := xf.basis.inverse().transposed()
	# Only the lights whose range reaches this mesh (big levels have dozens of torches).
	var box := xf * mi.get_aabb()
	lights = lights.filter(func(l): return _reaches(l, box))
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms := PackedVector3Array()
		if arr[Mesh.ARRAY_NORMAL] != null:
			norms = arr[Mesh.ARRAY_NORMAL]
		# Vertex paint (PS1VertexPaint: AO, gradients, grime) multiplies the baked light.
		var paint: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var cols := PackedColorArray()
		cols.resize(verts.size())
		for i in verts.size():
			var p := xf * verts[i]
			var n := (nb * norms[i]).normalized() if i < norms.size() else Vector3.UP
			var c := ambient
			for l in lights:
				c += _light(l, p, n, space)
			# Stored at half intensity: the unlit shader multiplies by 2 (PS1-style 2x modulation).
			if i < paint.size():
				c = Color(c.r * paint[i].r, c.g * paint[i].g, c.b * paint[i].b)
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

static func _reaches(l: Light3D, box: AABB) -> bool:
	if not (l is OmniLight3D or l is SpotLight3D):
		return true
	var r: float = l.omni_range if l is OmniLight3D else l.spot_range
	var p := l.global_position
	var closest := p.clamp(box.position, box.end)
	return closest.distance_squared_to(p) < r * r

static func _is_cutout(mi: MeshInstance3D) -> bool:
	if PS1Convert.mode_of(mi.material_override).ends_with("cutout"):
		return true
	for s in mi.mesh.get_surface_count():
		if PS1Convert.mode_of(mi.get_active_material(s)).ends_with("cutout"):
			return true
	return false

static func _unlit(m: ShaderMaterial) -> ShaderMaterial:
	var mode := PS1Convert.mode_of(m)
	if mode.begins_with("unlit") or mode.begins_with("billboard"):
		return m
	var n := PS1Convert.with_mode(m, "unlit_cutout" if mode == "cutout" else "unlit")
	n.set_shader_parameter("use_vertex_color", true)
	return n

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
