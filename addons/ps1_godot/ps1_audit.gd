## Level checks for code-built levels, meant for headless test runs:
##
##   var holes := await PS1Audit.missing_collision(level_root, AABB(Vector3(-60, -10, -70), Vector3(80, 14, 80)))
##   for h in holes: print("visible wall without collider at ", h)
##
## missing_collision() finds walls you can SEE but walk through: it gives every visible mesh a
## temporary trimesh collider on a spare physics layer, then, on a grid over the walkable floor,
## casts short rays at knee and chest height and compares what the eye hits with what the body
## would hit. Meshes with meta "ps1_no_audit" (decor you may walk through: grass, cobwebs,
## light shafts) are skipped, as are characters, sprites and particles.
class_name PS1Audit
extends RefCounted

const VISUAL_LAYER := 1 << 30

## Returns one point per 1 m cell where a visible surface has no collider behind it (within
## `slack` m). `floors_from` = heights to look down from for walkable floor (one per storey).
## `reach_from` (e.g. the player's position) drops spots the navmesh can't reach from there.
static func missing_collision(root: Node3D, area: AABB, step := 0.5, floors_from: Array = [], ray := 0.9,
		heights: Array = [0.45, 0.95], slack := 0.25, mask := 1, verbose := false, body_radius := 0.28, reach_from := Vector3.INF) -> Array[Vector3]:
	var tmp := _visual_colliders(root)
	await root.get_tree().physics_frame
	await root.get_tree().physics_frame
	var space := root.get_world_3d().direct_space_state
	if floors_from.is_empty():
		floors_from = [area.end.y]
	var cells := {}
	var out: Array[Vector3] = []
	var floors: Array[Vector3] = []
	var nav := root.get_world_3d().navigation_map
	var use_nav := NavigationServer3D.map_get_regions(nav).size() > 0
	var probe := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new(); sph.radius = body_radius
	probe.shape = sph
	probe.collision_mask = mask
	var x := area.position.x
	while x <= area.end.x:
		var z := area.position.z
		while z <= area.end.z:
			for top in floors_from:
				var f := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, top, z), Vector3(x, top - 4.0, z), mask))
				if f.is_empty() or (f.normal as Vector3).y < 0.7:
					continue
				var fp: Vector3 = f.position
				# only where a body can actually get (on the navmesh, when there is one): wall tops
				# and roofs aren't floors
				if use_nav:
					var np := NavigationServer3D.map_get_closest_point(nav, fp)
					if Vector2(np.x - fp.x, np.z - fp.z).length() > 0.5 or absf(np.y - fp.y) > 0.6:
						continue
				# room for a body to stand here? (a capsule-ish sphere clear of colliders)
				if not space.intersect_ray(PhysicsRayQueryParameters3D.create(fp + Vector3.UP * 0.1, fp + Vector3.UP * 1.7, mask)).is_empty():
					continue
				probe.transform = Transform3D(Basis(), fp + Vector3.UP * 0.75)
				if not space.intersect_shape(probe, 1).is_empty():
					continue
				# a hole = the eye sees a surface but the body would pass at EVERY height tested (a
				# missing wall); a thin visual lip over a collider (stair nosings) is not one
				for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
					var first_hit := Vector3.INF
					var holes := 0
					for h in heights:
						var o := fp + Vector3.UP * float(h)
						var v := space.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + d * ray, VISUAL_LAYER))
						if v.is_empty():
							continue
						var vd: float = (v.position as Vector3).distance_to(o)
						if vd < body_radius:
							holes = -99   # the body could never stand that close
							continue
						var c := space.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + d * (vd + slack), mask))
						if c.is_empty():
							holes += 1
							if not first_hit.is_finite():
								first_hit = v.position
								if verbose:
									var src: Node = (v.collider as Node).get_meta("src") if v.collider else null
									print("  audit: ", v.position, " <- ", src.get_path() if src else "?")
					if holes == heights.size() and first_hit.is_finite():
						var key := Vector3i(floori(first_hit.x), floori(first_hit.y), floori(first_hit.z))
						if not cells.has(key):
							cells[key] = true
							out.append(first_hit)
							floors.append(fp)
			z += step
		x += step
	for b in tmp:
		b.queue_free()
	# keep only spots a body can actually walk to from `reach_from` (rooftops are navmesh too)
	if use_nav and reach_from.is_finite():
		var kept: Array[Vector3] = []
		for k in out.size():
			var goal: Vector3 = floors[k]
			var path := NavigationServer3D.map_get_path(nav, NavigationServer3D.map_get_closest_point(nav, reach_from), goal, true)
			if not path.is_empty() and path[-1].distance_to(goal) < 0.8:
				kept.append(out[k])
		out = kept
	return out

static func _visual_colliders(root: Node3D) -> Array[StaticBody3D]:
	var made: Array[StaticBody3D] = []
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() or mi.mesh == null or mi.has_meta("ps1_no_audit"):
			continue
		if _under_character(mi):
			continue
		var bb := mi.mesh.get_aabb()
		if bb.size.x > 60.0 and bb.size.z > 60.0 and bb.size.y > 30.0:
			continue   # sky domes, fog shells
		var shape := mi.mesh.create_trimesh_shape()
		if shape == null:
			continue
		var b := StaticBody3D.new()
		b.collision_layer = VISUAL_LAYER
		b.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = shape
		b.add_child(cs)
		root.add_child(b)
		b.global_transform = mi.global_transform
		b.set_meta("src", mi)
		made.append(b)
	return made

static func _under_character(n: Node) -> bool:
	var p := n.get_parent()
	while p:
		if p is CharacterBody3D or p is RigidBody3D or p is GPUParticles3D or p is CPUParticles3D:
			return true
		p = p.get_parent()
	return false
