## A PS1BakedLevel you paint with pieces on a grid, RPG Maker style (select it in the editor:
## the "PS1 Pieces" panel opens). Every piece is a scene from the palette folders; the root of a
## piece can declare where it sits in a cell with metadata:
##   ps1_slot  : "floor", "wall", "ceiling", "prop"... (default "prop"). One piece per slot per cell;
##               painting another piece in the same slot replaces it.
##   ps1_edge  : true for pieces that sit on a cell EDGE (walls, doors, wall torches): the rotation
##               picks the edge, so a cell can have four walls.
## Pieces keep their cell in metadata (ps1_cell, ps1_rot), so the level can be edited from code too:
##   level.place(load("res://pieces/wall.tscn"), Vector3i(3, 0, -2), 1)
@tool
@icon("res://addons/ps1_godot/icons/grid_level.svg")
class_name PS1GridLevel
extends PS1BakedLevel

## Size of a cell on X/Z (meters).
@export var cell_size := 2.0
## Height of one floor level (meters). Layer N sits at y = N * layer_height.
@export var layer_height := 1.0
## Folders scanned for pieces (.tscn / .glb). Sub-folders become palette categories.
@export var palette_dirs: PackedStringArray = ["res://pieces", "res://addons/ps1_godot/starter_pieces"]
## Slots the painter's "Hide ceilings" button hides in the editor (so you can see inside rooms).
@export var xray_slots: PackedStringArray = ["ceiling"]
@export_group("Auto walls")
## Painting/erasing floors puts this wall on every floor -> empty edge (and removes it when the
## edge stops being one). Only walls of THIS scene are managed: doors and arches you placed stay.
@export var auto_wall: PackedScene
## Optional: every floor cell gets this ceiling (removed with the floor).
@export var auto_ceiling: PackedScene
## Slot that counts as floor for the auto walls.
@export var auto_floor_slot := "floor"
@export_group("")

const _DIRS := [Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0)]
var _slot_cache := {}

func cell_to_local(cell: Vector3i) -> Vector3:
	return Vector3(cell.x * cell_size, cell.y * layer_height, cell.z * cell_size)

func local_to_cell(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / cell_size + 0.5), roundi(p.y / layer_height), floori(p.z / cell_size + 0.5))

static func slot_of(piece: Node) -> String:
	var slot := String(piece.get_meta("ps1_slot", "prop"))
	if piece.get_meta("ps1_edge", false):
		slot += ":%d" % (int(piece.get_meta("ps1_rot", 0)) % 4)
	return slot

## Pieces painted in a cell (optionally only the given slot).
func pieces_at(cell: Vector3i, slot := "") -> Array[Node3D]:
	var r: Array[Node3D] = []
	for c in get_children():
		if c.has_meta("ps1_cell") and c.get_meta("ps1_cell") == cell and (slot == "" or slot_of(c) == slot):
			r.append(c)
	return r

## Every painted piece.
func pieces() -> Array[Node3D]:
	var r: Array[Node3D] = []
	for c in get_children():
		if c.has_meta("ps1_cell"):
			r.append(c)
	return r

## Builds (but does not add) a piece instance for a cell. rot = quarter turns (0..3).
func make_piece(scene: PackedScene, cell: Vector3i, rot := 0) -> Node3D:
	var n := scene.instantiate() as Node3D
	n.set_meta("ps1_cell", cell)
	n.set_meta("ps1_rot", posmod(rot, 4))
	n.set_meta("ps1_scene", scene.resource_path)
	if not n.has_meta("ps1_slot"):
		n.set_meta("ps1_slot", "prop")
	n.position = cell_to_local(cell)
	n.rotation.y = -posmod(rot, 4) * PI / 2.0
	n.name = "%s_%d_%d_%d" % [scene.resource_path.get_file().get_basename(), cell.x, cell.y, cell.z]
	return n

## Adds a piece, replacing whatever was in the same cell + slot. Returns [added, removed_pieces].
## owner_node: the scene root (so the piece is saved with the scene); null = this level's owner.
func place(scene: PackedScene, cell: Vector3i, rot := 0, owner_node: Node = null) -> Array:
	var n := make_piece(scene, cell, rot)
	var removed := pieces_at(cell, slot_of(n))
	for r in removed:
		remove_child(r)
	add_piece(n, owner_node)
	return [n, removed]

func add_piece(n: Node3D, owner_node: Node = null) -> void:
	if n.get_parent() == null:
		add_child(n, true)
	var o := owner_node if owner_node else (owner if owner else self)
	if n != o:
		n.owner = o

## Removes the pieces of a cell (optionally only one slot). Returns them (not freed: undo can re-add).
func erase(cell: Vector3i, slot := "") -> Array[Node3D]:
	var removed := pieces_at(cell, slot)
	for r in removed:
		remove_child(r)
	return removed

## Paints a whole map from text, one character per cell (handy for blocking out a level from code):
##   legend = {"#": [wall_scene...], ".": [floor_scene]}  — each value is an Array of
##   PackedScene, or [PackedScene, rot] pairs. Row 0 is the most negative Z.
func paint_ascii(rows: PackedStringArray, legend: Dictionary, layer := 0, origin := Vector2i.ZERO, owner_node: Node = null) -> int:
	var count := 0
	for z in rows.size():
		for x in rows[z].length():
			var ch := rows[z][x]
			if not legend.has(ch):
				continue
			for item in legend[ch]:
				var scene: PackedScene = item[0] if item is Array else item
				var rot: int = item[1] if item is Array else 0
				place(scene, Vector3i(origin.x + x, layer, origin.y + z), rot, owner_node)
				count += 1
	return count

# ---------------- auto walls / ceilings ----------------

func has_floor(cell: Vector3i) -> bool:
	return not pieces_at(cell, auto_floor_slot).is_empty()

## An edge is open if the neighbor has floor on the same layer or one layer up/down (stairs,
## platforms: their floor blocks fill down to the layer below).
func _open(cell: Vector3i) -> bool:
	return has_floor(cell) or has_floor(cell + Vector3i(0, 1, 0)) or has_floor(cell - Vector3i(0, 1, 0))

func _base_slot(scene: PackedScene) -> String:
	var key := scene.get_instance_id()   # not the path: scenes made in code have none
	if not _slot_cache.has(key):
		var n := scene.instantiate()
		_slot_cache[key] = String(n.get_meta("ps1_slot", "prop"))
		n.free()
	return _slot_cache[key]

## Re-evaluates walls/ceiling of the given cells and their neighbors. Returns [added, removed]
## (removed nodes are detached, not freed, so an undo can put them back).
func update_auto(cells: Array, owner_node: Node = null) -> Array:
	var added: Array[Node3D] = []
	var removed: Array[Node3D] = []
	if auto_wall == null and auto_ceiling == null:
		return [added, removed]
	var todo := {}
	for c in cells:
		todo[c] = true
		for d in _DIRS:
			todo[c + d] = true
	for c in todo:
		var floor_here := has_floor(c)
		if auto_ceiling:
			var cs := _base_slot(auto_ceiling)
			var ceil := pieces_at(c, cs)
			if floor_here and ceil.is_empty():
				added.append(place(auto_ceiling, c, 0, owner_node)[0])
			elif not floor_here:
				for p in ceil:
					if p.get_meta("ps1_scene", "") == auto_ceiling.resource_path:
						remove_child(p)
						removed.append(p)
		if auto_wall == null:
			continue
		var ws := _base_slot(auto_wall)
		for r in 4:
			var need := floor_here and not _open(c + _DIRS[r])
			var on_edge := pieces_at(c, "%s:%d" % [ws, r])
			if need and on_edge.is_empty():
				added.append(place(auto_wall, c, r, owner_node)[0])
			elif not need:
				var had_auto := on_edge.any(func(p): return p.get_meta("ps1_scene", "") == auto_wall.resource_path)
				if had_auto:
					# the auto wall goes, and so does whatever hung on it (torches...)
					for p in pieces_at(c):
						if p.get_meta("ps1_edge", false) and int(p.get_meta("ps1_rot", 0)) % 4 == r:
							remove_child(p)
							removed.append(p)
	return [added, removed]

## Recomputes the auto walls/ceilings of the whole level.
func rebuild_auto(owner_node: Node = null) -> Array:
	var cells := {}
	for p in pieces():
		cells[p.get_meta("ps1_cell")] = true
	return update_auto(cells.keys(), owner_node)
