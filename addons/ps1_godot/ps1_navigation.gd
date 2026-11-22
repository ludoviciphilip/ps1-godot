## Runtime navigation for code-built levels: bakes a navigation mesh from the level's static
## colliders (PS1Gothic, grid pieces, anything with StaticBody3D shapes) when the level loads,
## and answers "which way do I walk to reach X" for enemies, going around walls instead of
## pushing against them.
##
##   PS1Navigation.bake(level_root)                  # once, after the level is built
##   var dir := PS1Navigation.steer(self, target_pos)   # every frame, in an enemy
##
## steer() walks straight when the way is clear (cheap ray) and follows the navmesh path when a
## wall is in the way, re-planning a few times per second. It also notices when the body is
## stuck (pushing but not moving) and then trusts the path.
class_name PS1Navigation
extends RefCounted

## Agent size used for the bake (meters).
static var agent_radius := 0.32   # small: 1,2 m arches must stay open; steer() keeps the body's width off the jambs
static var agent_height := 1.8
static var max_climb := 0.38
static var max_slope := 42.0
static var cell := 0.125
## Off = steer() always walks straight (A/B tests).
static var enabled := true

static func bake(root: Node3D, collision_mask := 1) -> NavigationRegion3D:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = collision_mask
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	nm.agent_radius = agent_radius
	nm.agent_height = agent_height
	nm.agent_max_climb = max_climb
	nm.agent_max_slope = max_slope
	nm.cell_size = cell
	nm.cell_height = cell * 0.5
	nm.region_min_size = 1.0
	if root.is_inside_tree():
		var map := root.get_world_3d().navigation_map
		NavigationServer3D.map_set_cell_size(map, cell)
		NavigationServer3D.map_set_cell_height(map, cell * 0.5)
	var region := NavigationRegion3D.new()
	region.name = "PS1Navigation"
	region.navigation_mesh = nm
	root.add_child(region)
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, root)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	region.navigation_mesh = nm
	return region

## Polygons in the baked mesh (0 = nothing walkable was found).
static func polygon_count(region: NavigationRegion3D) -> int:
	return region.navigation_mesh.get_polygon_count() if region and region.navigation_mesh else 0

## Horizontal direction (unit or zero) to walk from `body` toward `target`.
static func steer(body: Node3D, target: Vector3, eye_height := 0.8) -> Vector3:
	var from := body.global_position
	var flat := Vector3(target.x - from.x, 0, target.z - from.z)
	if flat.length() < 0.05:
		return Vector3.ZERO
	if not enabled:
		return flat.normalized()
	var st: Dictionary = body.get_meta("_ps1_nav", {})
	var now := Time.get_ticks_msec() / 1000.0
	# stuck detector: wanted to move but barely moved in the last 0.5 s
	var last_pos: Vector3 = st.get("pos", from)
	if now - float(st.get("pos_t", 0.0)) > 0.5:
		st["stuck"] = from.distance_to(last_pos) < 0.15 and float(st.get("pos_t", 0.0)) > 0.0
		st["pos"] = from
		st["pos_t"] = now
	var clear: bool = not st.get("stuck", false) and _clear(body, from + Vector3.UP * eye_height, target + Vector3.UP * eye_height)
	if clear:
		st.erase("path")
		st["reach"] = true
		body.set_meta("_ps1_nav", st)
		return flat.normalized()
	var path: PackedVector3Array = st.get("path", PackedVector3Array())
	if path.is_empty() or now - float(st.get("path_t", 0.0)) > 0.35 or (st.get("goal", target) as Vector3).distance_to(target) > 1.0:
		var map := body.get_world_3d().navigation_map
		path = NavigationServer3D.map_get_path(map, NavigationServer3D.map_get_closest_point(map, from),
			NavigationServer3D.map_get_closest_point(map, target), true)
		st["path"] = path
		st["path_t"] = now
		st["goal"] = target
		var end_ok := not path.is_empty() and Vector2(path[-1].x - target.x, path[-1].z - target.z).length() < 1.5 and absf(path[-1].y - target.y) < 1.5
		st["reach"] = end_ok
	# aim at the farthest of the next waypoints the body can walk to in a straight line (its
	# width included): cuts open corners, but never aims through a door jamb
	var dir := flat.normalized()
	var first := -1
	for i in path.size():
		if Vector2(path[i].x - from.x, path[i].z - from.z).length() > 0.35:
			first = i
			break
	if first >= 0:
		var pick := first
		for i in range(first + 1, mini(first + 4, path.size())):
			if _clear(body, from + Vector3.UP * 0.5, Vector3(path[i].x, from.y + 0.5, path[i].z)):
				pick = i
			else:
				break
		dir = Vector3(path[pick].x - from.x, 0, path[pick].z - from.z).normalized()
	# pressed against a wall (stuck): drop the part of the direction that goes into it, so the body
	# slides along the wall toward the opening instead of pushing in place
	if st.get("stuck", false) and body is CharacterBody3D:
		var cb := body as CharacterBody3D
		for k in cb.get_slide_collision_count():
			var n := cb.get_slide_collision(k).get_normal()
			n.y = 0.0
			if n.length() < 0.5:
				continue
			n = n.normalized()
			var into := dir.dot(n)
			if into < 0.0:
				dir -= n * into
				if dir.length() < 0.2:   # pushing straight in: pick the side the target is on
					var t := Vector3(-n.z, 0, n.x)
					dir = t if t.dot(flat) >= 0.0 else -t
				dir = (dir.normalized() + n * 0.25).normalized()
	body.set_meta("_ps1_nav", st)
	return dir

## After steer(): false when the last plan found no way to the target (closed door, other
## floor, behind a wall with no gap). Enemies can give up instead of pushing the wall.
static func reachable(body: Node3D) -> bool:
	return bool((body.get_meta("_ps1_nav", {}) as Dictionary).get("reach", true))

## Line of sight between two points through the world (layer mask), ignoring `body`.
static func can_see(body: Node3D, from: Vector3, to: Vector3, mask := 1) -> bool:
	var excl: Array[RID] = []
	if body is CollisionObject3D:
		excl.append((body as CollisionObject3D).get_rid())
	var q := PhysicsRayQueryParameters3D.create(from, to, mask, excl)
	return body.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## Bake again (doors opened, bridges lowered). Same settings as the region already has.
static func rebake(region: NavigationRegion3D) -> void:
	if region == null or not region.is_inside_tree():
		return
	var nm := region.navigation_mesh
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, region.get_parent())
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	region.navigation_mesh = nm

static func _clear(body: Node3D, a: Vector3, b: Vector3) -> bool:
	var space := body.get_world_3d().direct_space_state
	var excl: Array[RID] = []
	if body is CollisionObject3D:
		excl.append((body as CollisionObject3D).get_rid())
	var side := Vector3(b.z - a.z, 0, a.x - b.x).normalized() * 0.35   # two rays, body width apart
	for o in [side, -side]:
		var q := PhysicsRayQueryParameters3D.create(a + o, b + o, 1, excl)
		if not space.intersect_ray(q).is_empty():
			return false
	return true
