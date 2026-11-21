## Procedural maps for PS1GridLevel: dungeons, catacombs, caves, mazes and ruins.
##
##   var map := PS1LevelGen.generate({style = PS1LevelGen.Style.DUNGEON, width = 32, depth = 32, seed = 7})
##   map.build($Level)                        # starter pieces, or pass a PS1GenTheme
##   print(map.start, map.end, map.spawns)    # cells; markers are placed too
##
## Generation is pure data (fast, deterministic per seed) and the result is ordinary grid pieces,
## so a generated map can be edited by hand in the "PS1 Pieces" panel afterwards (button
## "Generate..." there). Every map is checked to be fully connected.
##
## Cells: x/z on the grid; edges use the grid's rotations (0 = N/-Z, 1 = E/+X, 2 = S/+Z, 3 = W/-X).
@tool
class_name PS1LevelGen
extends RefCounted

enum Style { DUNGEON, CATACOMBS, CAVES, MAZE, RUINS }
const STYLE_NAMES := ["Dungeon", "Catacombs", "Caves", "Maze", "Ruins"]

## Cell kinds.
const EMPTY := 0
const ROOM := 1
const HALL := 2     # corridor, cave floor, maze cell
const GROUND := 3   # open ground (ruins)

const D2: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var size := Vector2i(32, 32)
var style := Style.DUNGEON
var map_seed := 0
var kind := PackedByteArray()
var room_id := PackedInt32Array()
var rooms: Array[Rect2i] = []
## Thin walls between two floor cells: Vector3i(x, z, rot) -> true (walls next to empty cells
## are implicit).
var walls := {}
## Doorways: Vector3i(x, z, rot) -> true, on the room side.
var doors := {}
## Wall torches: Vector3i(x, z, rot).
var lights: Array[Vector3i] = []
## Vector2i -> [type, rot]; type = "pillar", "prop", "niche", "brazier".
var props := {}
var start := Vector2i(-1, -1)
var end := Vector2i(-1, -1)
var spawns: Array[Vector2i] = []
## Whether build() puts ceilings (style default, or the "ceiling" option).
var roofed := true

var _rng := RandomNumberGenerator.new()
var _o := {}

## Options (all optional). Sizes in cells (default 2 m each).
static func defaults() -> Dictionary:
	return {
		style = Style.DUNGEON, width = 32, depth = 32, seed = 0,
		rooms = 8,          # target room count (dungeon/catacombs/ruins; maze: a few open halls)
		room_min = 3, room_max = 7,
		loops = 0.2,        # extra connections (0 = tree, every dead end is a dead end)
		enemies = 6,
		props = 0.5,        # amount of clutter, pillars, niches (0..1)
		lights = 1.0,       # torch density (0 = none)
		ceiling = null,     # null = style default (ruins are open)
		braid = 0.15,       # maze: share of dead ends opened into loops
		fill = 0.46,        # caves: initial rock density
	}

static func generate(options := {}) -> PS1LevelGen:
	var g := PS1LevelGen.new()
	var o := defaults()
	o.merge(options, true)
	g._o = o
	g.style = int(o.style)
	g.size = Vector2i(clampi(int(o.width), 8, 128), clampi(int(o.depth), 8, 128))
	g.map_seed = int(o.seed)
	g._rng.seed = hash(g.map_seed * 7919 + g.style)
	g.kind.resize(g.size.x * g.size.y)
	g.room_id.resize(g.size.x * g.size.y)
	g.room_id.fill(-1)
	match g.style:
		Style.DUNGEON: g._dungeon(int(o.room_min), int(o.room_max), 1)
		Style.CATACOMBS: g._dungeon(2, mini(int(o.room_max), 4), 1)
		Style.CAVES: g._caves()
		Style.MAZE: g._maze()
		Style.RUINS: g._ruins()
	g.roofed = o.ceiling if o.ceiling != null else g.style != Style.RUINS
	g._ends()
	g._decorate()
	g._spawns(int(o.enemies))
	return g

# ---------------- grid helpers ----------------

func idx(c: Vector2i) -> int:
	return c.y * size.x + c.x

func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y

func is_floor(c: Vector2i) -> bool:
	return inside(c) and kind[idx(c)] != EMPTY

## True if you can't walk from c through edge r (no floor there or a wall in between).
func blocked(c: Vector2i, r: int) -> bool:
	var n := c + D2[r]
	if not is_floor(n):
		return true
	return walls.has(Vector3i(c.x, c.y, r)) or walls.has(Vector3i(n.x, n.y, (r + 2) % 4))

## True if a prop blocks the cell.
func solid(c: Vector2i) -> bool:
	return props.has(c)

func floor_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for z in size.y:
		for x in size.x:
			if kind[z * size.x + x] != EMPTY:
				out.append(Vector2i(x, z))
	return out

## Walking distance from `from` to every cell (-1 = unreachable). Props block.
func distances(from: Vector2i) -> PackedInt32Array:
	var d := PackedInt32Array()
	d.resize(size.x * size.y)
	d.fill(-1)
	if not is_floor(from):
		return d
	d[idx(from)] = 0
	var q: Array[Vector2i] = [from]
	var i := 0
	while i < q.size():
		var c := q[i]
		i += 1
		for r in 4:
			var n := c + D2[r]
			if blocked(c, r) or solid(n) or d[idx(n)] >= 0:
				continue
			d[idx(n)] = d[idx(c)] + 1
			q.append(n)
	return d

## {floors, reachable, unreachable: Array} from start, ignoring prop cells.
func check() -> Dictionary:
	var d := distances(start)
	var bad: Array[Vector2i] = []
	var n := 0
	for c in floor_cells():
		if solid(c):
			continue
		n += 1
		if d[idx(c)] < 0:
			bad.append(c)
	return {floors = n, reachable = n - bad.size(), unreachable = bad}

# ---------------- dungeon / catacombs ----------------

func _place_rooms(count: int, rmin: int, rmax: int, pad: int, margin := 1) -> void:
	var tries := count * 40
	while rooms.size() < count and tries > 0:
		tries -= 1
		var w := _rng.randi_range(rmin, rmax)
		var d := _rng.randi_range(rmin, rmax)
		if w + 2 * margin > size.x or d + 2 * margin > size.y:
			continue
		var r := Rect2i(_rng.randi_range(margin, size.x - w - margin), _rng.randi_range(margin, size.y - d - margin), w, d)
		if rooms.any(func(o: Rect2i): return o.grow(pad).intersects(r)):
			continue
		rooms.append(r)
	for i in rooms.size():
		var r := rooms[i]
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				kind[z * size.x + x] = ROOM
				room_id[z * size.x + x] = i

func _center(r: Rect2i) -> Vector2i:
	return r.position + r.size / 2

func _dungeon(rmin: int, rmax: int, pad: int) -> void:
	var count := int(_o.rooms)
	if style == Style.CATACOMBS:
		count = int(count * 1.6)
	_place_rooms(count, rmin, rmax, pad + (1 if style == Style.DUNGEON else 0))
	# Minimum spanning tree over the room centers (Prim), then some extra links for loops.
	var links: Array[Vector2i] = []
	var in_tree := {0: true}
	while in_tree.size() < rooms.size():
		var best := Vector2i(-1, -1)
		var bd := INF
		for a in in_tree:
			for b in rooms.size():
				if in_tree.has(b):
					continue
				var dd := Vector2(_center(rooms[a])).distance_to(Vector2(_center(rooms[b])))
				if dd < bd:
					bd = dd
					best = Vector2i(a, b)
		in_tree[best.y] = true
		links.append(best)
	var loops := float(_o.loops) * (1.5 if style == Style.CATACOMBS else 1.0)
	for a in rooms.size():
		var near := range(rooms.size())
		near.sort_custom(func(x, y): return _center(rooms[a]).distance_squared_to(_center(rooms[x])) < _center(rooms[a]).distance_squared_to(_center(rooms[y])))
		for b in near.slice(1, 4):
			if a < b and not links.has(Vector2i(a, b)) and not links.has(Vector2i(b, a)) and _rng.randf() < loops:
				links.append(Vector2i(a, b))
	for l in links:
		_corridor(l.x, l.y)
	_room_walls()
	if style == Style.CATACOMBS:
		_niches(0.35 * float(_o.props) * 2.0)

## Carves a corridor between two rooms with A* (turns cost extra so corridors run straight,
## existing corridors are cheap so they merge, hugging other rooms is expensive).
func _corridor(ra: int, rb: int) -> void:
	var a := _center(rooms[ra])
	var b := _center(rooms[rb])
	var n := size.x * size.y
	var best := PackedFloat32Array()
	best.resize(n * 4)
	best.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(n * 4)
	prev.fill(-1)
	_hp = PackedFloat32Array()
	_hs = PackedInt32Array()
	for d in 4:
		best[idx(a) * 4 + d] = 0.0
		_push(0.0, idx(a) * 4 + d)
	var goal := -1
	while _hs.size() > 0:
		var s := _pop()
		var c := Vector2i((s / 4) % size.x, (s / 4) / size.x)
		var d := s % 4
		if c == b:
			goal = s
			break
		var g := best[s]
		for nd in 4:
			if nd == (d + 2) % 4:
				continue
			var nc := c + D2[nd]
			if nc.x < 1 or nc.y < 1 or nc.x >= size.x - 1 or nc.y >= size.y - 1:
				continue
			var step := _cost(nc, ra, rb)
			if step < 0.0:
				continue
			if nd != d:
				step += 2.5
			var ns := idx(nc) * 4 + nd
			if g + step < best[ns]:
				best[ns] = g + step
				prev[ns] = s
				_push(g + step + absi(nc.x - b.x) + absi(nc.y - b.y), ns)
	if goal < 0:
		return
	var path: Array[Vector2i] = []
	var s := goal
	while s >= 0:
		path.push_front(Vector2i((s / 4) % size.x, (s / 4) / size.x))
		s = prev[s]
	for i in path.size():
		var c := path[i]
		if kind[idx(c)] == EMPTY:
			kind[idx(c)] = HALL
		if i > 0:
			var p := path[i - 1]
			var rp := room_id[idx(p)]
			var rc := room_id[idx(c)]
			if rp != rc:
				if rp >= 0:
					doors[Vector3i(p.x, p.y, D2.find(c - p))] = true
				else:
					doors[Vector3i(c.x, c.y, D2.find(p - c))] = true

func _cost(c: Vector2i, ra: int, rb: int) -> float:
	var i := idx(c)
	var r := room_id[i]
	if r >= 0:
		return 1.0 if r == ra or r == rb else -1.0
	var cost := 0.45 if kind[i] == HALL else 1.0
	for d in D2:
		var n := c + d
		if inside(n):
			var rn := room_id[idx(n)]
			if rn >= 0 and rn != ra and rn != rb:
				cost += 4.0
	return cost

# binary heap (packed arrays are copied when passed around, so it lives in members)
var _hp := PackedFloat32Array()
var _hs := PackedInt32Array()

func _push(p: float, s: int) -> void:
	_hp.append(p)
	_hs.append(s)
	var i := _hp.size() - 1
	while i > 0:
		var up := (i - 1) / 2
		if _hp[up] <= _hp[i]:
			break
		var tp := _hp[up]; _hp[up] = _hp[i]; _hp[i] = tp
		var ts := _hs[up]; _hs[up] = _hs[i]; _hs[i] = ts
		i = up

func _pop() -> int:
	var top := _hs[0]
	var last := _hp.size() - 1
	_hp[0] = _hp[last]
	_hs[0] = _hs[last]
	_hp.resize(last)
	_hs.resize(last)
	var i := 0
	while true:
		var l := i * 2 + 1
		var m := i
		if l < last and _hp[l] < _hp[m]: m = l
		if l + 1 < last and _hp[l + 1] < _hp[m]: m = l + 1
		if m == i:
			break
		var tp := _hp[m]; _hp[m] = _hp[i]; _hp[i] = tp
		var ts := _hs[m]; _hs[m] = _hs[i]; _hs[i] = ts
		i = m
	return top

## Rooms are closed by thin walls wherever they touch other floor, except at doorways.
func _room_walls() -> void:
	for i in rooms.size():
		var r := rooms[i]
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, z)
				for e in 4:
					var nb := c + D2[e]
					if is_floor(nb) and room_id[idx(nb)] != i and not doors.has(Vector3i(x, z, e)):
						walls[Vector3i(x, z, e)] = true

## Burial niches: one-cell alcoves dug into corridor walls, each holding a niche piece.
func _niches(chance: float) -> void:
	for c in floor_cells():
		if kind[idx(c)] != HALL:
			continue
		for r in 4:
			var n := c + D2[r]
			if n.x < 1 or n.y < 1 or n.x >= size.x - 1 or n.y >= size.y - 1 or kind[idx(n)] != EMPTY:
				continue
			var lonely := true
			for r2 in 4:
				var m := n + D2[r2]
				if m != c and is_floor(m):
					lonely = false
			# not right next to another niche
			for r2 in 4:
				if props.has(n + D2[r2]) or props.has(c + D2[r2]) and props[c + D2[r2]][0] == "niche":
					lonely = false
			if lonely and _rng.randf() < chance:
				kind[idx(n)] = HALL
				props[n] = ["niche", r]

# ---------------- caves ----------------

func _caves() -> void:
	# small maps can close up completely: retry with less rock until a decent cave is left
	var fill := float(_o.fill)
	for attempt in 8:
		_cave_pass(fill)
		if floor_cells().size() >= size.x * size.y * 0.25:
			return
		fill -= 0.03

func _cave_pass(fill: float) -> void:
	kind.fill(EMPTY)
	var rock := PackedByteArray()
	rock.resize(size.x * size.y)
	for z in size.y:
		for x in size.x:
			var edge := x == 0 or z == 0 or x == size.x - 1 or z == size.y - 1
			rock[z * size.x + x] = 1 if edge or _rng.randf() < fill else 0
	for it in 5:
		var nxt := rock.duplicate()
		for z in range(1, size.y - 1):
			for x in range(1, size.x - 1):
				var w := 0
				for dz in range(-1, 2):
					for dx in range(-1, 2):
						if (dx != 0 or dz != 0) and rock[(z + dz) * size.x + x + dx] == 1:
							w += 1
				nxt[z * size.x + x] = 1 if w >= 5 or (it < 2 and w == 0) else (0 if w <= 3 else rock[z * size.x + x])
		rock = nxt
	for i in rock.size():
		kind[i] = EMPTY if rock[i] else HALL
	_keep_largest()

## Removes every floor region but the largest one.
func _keep_largest() -> void:
	var region := PackedInt32Array()
	region.resize(size.x * size.y)
	region.fill(-1)
	var sizes: Array[int] = []
	for c in floor_cells():
		if region[idx(c)] >= 0:
			continue
		var id := sizes.size()
		var q: Array[Vector2i] = [c]
		region[idx(c)] = id
		var i := 0
		while i < q.size():
			var p := q[i]
			i += 1
			for r in 4:
				var n := p + D2[r]
				if is_floor(n) and region[idx(n)] < 0 and not blocked(p, r):
					region[idx(n)] = id
					q.append(n)
		sizes.append(q.size())
	var keep := sizes.find(sizes.max()) if sizes.size() else -1
	for i in region.size():
		if region[i] >= 0 and region[i] != keep:
			kind[i] = EMPTY

# ---------------- maze ----------------

func _maze() -> void:
	kind.fill(HALL)
	# every inner edge starts walled (stored once, on the E/S side)
	for z in size.y:
		for x in size.x:
			if x < size.x - 1: walls[Vector3i(x, z, 1)] = true
			if z < size.y - 1: walls[Vector3i(x, z, 2)] = true
	# a few open halls (rooms) first; the maze runs around and into them
	_place_rooms(maxi(0, int(_o.rooms) / 4), 3, 4, 2, 1)
	for i in rooms.size():
		var r := rooms[i]
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if x < r.end.x - 1: _open_edge(Vector2i(x, z), 1)
				if z < r.end.y - 1: _open_edge(Vector2i(x, z), 2)
	# recursive backtracker; a room counts as one big cell (entered once)
	var seen := {}
	var stack: Array[Vector2i] = [Vector2i(_rng.randi_range(0, size.x - 1), _rng.randi_range(0, size.y - 1))]
	_mark(stack[0], seen)
	while stack.size():
		var c: Vector2i = stack.back()
		var opts: Array[int] = []
		for r in 4:
			var n := c + D2[r]
			if inside(n) and not seen.has(n):
				opts.append(r)
		if opts.is_empty():
			stack.pop_back()
			continue
		var r := opts[_rng.randi() % opts.size()]
		var n := c + D2[r]
		_open_edge(c, r)
		var marked := _mark(n, seen)
		stack.append_array(marked)
	# braid: open some dead ends into loops
	for c in floor_cells():
		var closed: Array[int] = []
		for r in 4:
			if blocked(c, r):
				closed.append(r)
		if closed.size() == 3 and _rng.randf() < float(_o.braid):
			var inner := closed.filter(func(r): return is_floor(c + D2[r]))
			if inner.size():
				_open_edge(c, inner[_rng.randi() % inner.size()])
	# doorways where the maze enters a hall
	for c in floor_cells():
		var rc := room_id[idx(c)]
		if rc < 0:
			continue
		for r in 4:
			var n := c + D2[r]
			if is_floor(n) and room_id[idx(n)] != rc and not blocked(c, r):
				doors[Vector3i(c.x, c.y, r)] = true

func _mark(c: Vector2i, seen: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var rid := room_id[idx(c)]
	if rid < 0:
		seen[c] = true
		out.append(c)
		return out
	var r := rooms[rid]
	for z in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			seen[Vector2i(x, z)] = true
			out.append(Vector2i(x, z))
	# leave the hall from a "random" side, deterministic per seed
	out.sort_custom(func(a, b): return hash(a + Vector2i(map_seed, map_seed)) < hash(b + Vector2i(map_seed, map_seed)))
	return out

func _open_edge(c: Vector2i, r: int) -> void:
	var n := c + D2[r]
	walls.erase(Vector3i(c.x, c.y, r))
	walls.erase(Vector3i(n.x, n.y, (r + 2) % 4))

# ---------------- ruins ----------------

func _ruins() -> void:
	kind.fill(GROUND)
	_place_rooms(int(_o.rooms), int(_o.room_min), int(_o.room_max), 2, 2)
	var broken := 0.3
	for i in rooms.size():
		var r := rooms[i]
		var edges: Array[Vector3i] = []
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				for e in 4:
					var nb := Vector2i(x, z) + D2[e]
					if room_id[idx(nb)] != i:
						edges.append(Vector3i(x, z, e))
		var door: Vector3i = edges[_rng.randi() % edges.size()]
		doors[door] = true
		for e in edges:
			if e == door:
				continue
			if _rng.randf() < broken:
				if _rng.randf() < float(_o.props) * 0.6:
					var out := Vector2i(e.x, e.y) + D2[e.z]
					if not props.has(out):
						props[out] = ["prop", _rng.randi() % 4]   # rubble where the wall fell
				continue
			walls[e] = true

# ---------------- start / end / decoration / enemies ----------------

func _farthest(from: Vector2i) -> Vector2i:
	var d := distances(from)
	var best := from
	for c in floor_cells():
		if d[idx(c)] > d[idx(best)]:
			best = c
	return best

func _ends() -> void:
	var cells := floor_cells()
	if cells.is_empty():
		return
	if rooms.size() >= 2 and style != Style.MAZE:
		# start in a room at one end of the map, end in the room farthest away from it
		var any := _center(rooms[_rng.randi() % rooms.size()])
		var far := _farthest(any)
		var d := distances(far)
		var sr := _room_near(far)
		start = _center(rooms[sr])
		d = distances(start)
		var er := -1
		for i in rooms.size():
			if i != sr and (er < 0 or d[idx(_center(rooms[i]))] > d[idx(_center(rooms[er]))]):
				er = i
		end = _center(rooms[er])
	else:
		# the two ends of the longest walk
		var a := _farthest(cells[_rng.randi() % cells.size()])
		start = a
		end = _farthest(a)

func _room_near(c: Vector2i) -> int:
	var best := 0
	for i in rooms.size():
		if _center(rooms[i]).distance_squared_to(c) < _center(rooms[best]).distance_squared_to(c):
			best = i
	return best

func _reserved(c: Vector2i) -> bool:
	if c.distance_squared_to(start) <= 2 or c.distance_squared_to(end) <= 2:
		return true
	for r in 4:
		var n := c + D2[r]
		# in front of a doorway (both sides)
		if doors.has(Vector3i(c.x, c.y, r)) or doors.has(Vector3i(n.x, n.y, (r + 2) % 4)):
			return true
	return false

## Puts a blocking prop only if the map stays fully connected.
func _try_prop(c: Vector2i, type: String, rot: int) -> bool:
	if props.has(c) or not is_floor(c) or _reserved(c):
		return false
	props[c] = [type, rot]
	var d := distances(start)
	for n in D2:
		var m := c + n
		if is_floor(m) and not solid(m) and d[idx(m)] < 0:
			props.erase(c)
			return false
	return true

func _wall_side(c: Vector2i) -> int:
	for r in 4:
		if blocked(c, r) and not doors.has(Vector3i(c.x, c.y, r)):
			return r
	return -1

func _decorate() -> void:
	var amount := float(_o.props)
	# pillars: inset from the corners of big rooms (and down the middle of long halls)
	for i in rooms.size():
		var r := rooms[i]
		if r.size.x >= 5 and r.size.y >= 5 and amount > 0.0 and style != Style.MAZE:
			var xs := [r.position.x + 1, r.end.x - 2]
			var zs := [r.position.y + 1, r.end.y - 2]
			if r.size.x >= 8: xs.append(r.position.x + r.size.x / 2)
			if r.size.y >= 8: zs.append(r.position.y + r.size.y / 2)
			for x in xs:
				for z in zs:
					if (x == xs[0] or x == xs[1]) or (z == zs[0] or z == zs[1]):
						_try_prop(Vector2i(x, z), "pillar", 0)
		# brazier in the middle of big rooms
		if r.size.x >= 5 and r.size.y >= 5 and float(_o.lights) > 0.0:
			_try_prop(_center(r) + Vector2i(0, 1) if _center(r) in [start, end] else _center(r), "brazier", 0)
	# ruins: broken colonnades on the open ground
	if style == Style.RUINS:
		for c in floor_cells():
			if room_id[idx(c)] < 0 and c.x % 3 == 1 and c.y % 3 == 1 and _rng.randf() < 0.35 * amount:
				var near_room := false
				for r in 4:
					if is_floor(c + D2[r]) and room_id[idx(c + D2[r])] >= 0: near_room = true
				if not near_room:
					_try_prop(c, "pillar", 0)
	# caves: rock columns
	if style == Style.CAVES:
		for c in floor_cells():
			var open := 0
			for r in 4:
				if not blocked(c, r): open += 1
			if open == 4 and _rng.randf() < 0.05 * amount:
				_try_prop(c, "pillar", 0)
	# clutter along room walls
	for c in floor_cells():
		if room_id[idx(c)] < 0 and style != Style.CAVES:
			continue
		var side := _wall_side(c)
		if side >= 0 and _rng.randf() < 0.12 * amount:
			_try_prop(c, "prop", side)
	# torches on walls, spaced out
	var dens := float(_o.lights)
	if dens <= 0.0:
		return
	var spacing := 6 if style == Style.CAVES else (5 if style == Style.MAZE else 4)
	spacing = int(spacing / clampf(dens, 0.3, 2.0))
	var cells := floor_cells()
	cells.sort_custom(func(a, b): return hash(a * 31 + Vector2i(map_seed, 0)) < hash(b * 31 + Vector2i(map_seed, 0)))
	for c in cells:
		if solid(c):
			continue
		var sides: Array[int] = []
		for r in 4:
			if blocked(c, r) and not doors.has(Vector3i(c.x, c.y, r)):
				sides.append(r)
		if sides.is_empty():
			continue
		if lights.any(func(l: Vector3i): return absi(l.x - c.x) + absi(l.y - c.y) < spacing):
			continue
		if style == Style.RUINS and room_id[idx(c)] < 0:
			continue   # no torches on the open-air map border
		lights.append(Vector3i(c.x, c.y, sides[_rng.randi() % sides.size()]))

func _spawns(count: int) -> void:
	var d := distances(start)
	var maxd := 0
	for v in d:
		maxd = maxi(maxd, v)
	var min_d := mini(8, maxd / 3)
	var cand: Array[Vector2i] = []
	for c in floor_cells():
		var dc := d[idx(c)]
		if dc >= min_d and not solid(c) and c.distance_squared_to(end) > 2 and not _reserved(c):
			cand.append(c)
	# prefer rooms (fights in the open), then corridors
	cand.sort_custom(func(a, b):
		var ra := 0 if room_id[idx(a)] >= 0 else 1
		var rb := 0 if room_id[idx(b)] >= 0 else 1
		if ra != rb: return ra < rb
		return hash(a + Vector2i(map_seed, 3)) < hash(b + Vector2i(map_seed, 3)))
	var per_room := {}
	for pass_ in 2:
		for c in cand:
			if spawns.size() >= count:
				return
			if c in spawns or spawns.any(func(s): return absi(s.x - c.x) + absi(s.y - c.y) < 4):
				continue
			var rid := room_id[idx(c)]
			if pass_ == 0 and rid >= 0 and per_room.get(rid, 0) >= 2:
				continue
			per_room[rid] = per_room.get(rid, 0) + 1
			spawns.append(c)

# ---------------- output ----------------

## Builds the map into a PS1GridLevel. Returns [added, removed] (removed pieces are detached,
## not freed, so an editor undo can put them back). clear = remove every existing piece first.
func build(level: PS1GridLevel, theme: PS1GenTheme = null, layer := 0, origin := Vector2i.ZERO,
		clear := true, owner_node: Node = null) -> Array:
	if theme == null:
		theme = PS1GenTheme.starter(level)
	var ctx := {level = level, owner = owner_node, index = {}, added = [] as Array[Node3D], removed = [] as Array[Node3D],
		layer = layer, origin = origin}
	for p in level.pieces():
		if clear:
			level.remove_child(p)
			ctx.removed.append(p)
		else:
			ctx.index[str(p.get_meta("ps1_cell")) + PS1GridLevel.slot_of(p)] = p
	var brng := RandomNumberGenerator.new()
	brng.seed = hash(map_seed + 99)
	for c in floor_cells():
		var ground := kind[idx(c)] == GROUND and theme.ground_scene != null
		_put(ctx, theme.ground_scene if ground else theme.floor_scene, c, 0)
		if roofed:
			_put(ctx, theme.ceiling_scene, c, 0)
		for r in 4:
			var e := Vector3i(c.x, c.y, r)
			if doors.has(e):
				_put(ctx, theme.door_scene if theme.door_scene else null, c, r)
			elif not is_floor(c + D2[r]) or walls.has(e):
				_put(ctx, theme.wall_scene, c, r)
	for l in lights:
		_put(ctx, theme.torch_scene, Vector2i(l.x, l.y), l.z)
	for c in props:
		var p: Array = props[c]
		var scene: PackedScene = null
		match p[0]:
			"pillar": scene = theme.pillar_scene
			"brazier": scene = theme.brazier_scene
			"niche": scene = theme.niche_scene
			"prop": scene = theme.prop_scenes[brng.randi() % theme.prop_scenes.size()] if theme.prop_scenes.size() else null
		_put(ctx, scene, c, p[1])
	# markers: face the inside of the map from the start
	_put_marker(ctx, theme.start_scene, start, "start", _facing(start))
	_put_marker(ctx, theme.end_scene, end, "end", 0)
	for i in spawns.size():
		var sc: PackedScene = theme.enemy_scenes[brng.randi() % theme.enemy_scenes.size()] if theme.enemy_scenes.size() else null
		_put_marker(ctx, sc, spawns[i], "spawn", brng.randi() % 4)
	return [ctx.added, ctx.removed]

func _facing(c: Vector2i) -> int:
	var best := 0
	var bl := -1
	for r in 4:
		var l := 0
		var p := c
		while not blocked(p, r) and l < 20:
			p += D2[r]
			l += 1
		if l > bl:
			bl = l
			best = r
	return best

func _cell3(ctx: Dictionary, c: Vector2i) -> Vector3i:
	return Vector3i(ctx.origin.x + c.x, ctx.layer, ctx.origin.y + c.y)

func _put(ctx: Dictionary, scene: PackedScene, c: Vector2i, rot: int) -> void:
	if scene == null:
		return
	_add(ctx, (ctx.level as PS1GridLevel).make_piece(scene, _cell3(ctx, c), rot))

func _add(ctx: Dictionary, n: Node3D) -> void:
	var level: PS1GridLevel = ctx.level
	var key := str(n.get_meta("ps1_cell")) + PS1GridLevel.slot_of(n)
	var old: Node3D = ctx.index.get(key)
	if old and old.get_parent() == level:
		level.remove_child(old)
		if old in ctx.added:
			ctx.added.erase(old)
			old.free()
		else:
			ctx.removed.append(old)
	ctx.index[key] = n
	level.add_piece(n, ctx.owner)
	ctx.added.append(n)

func _put_marker(ctx: Dictionary, scene: PackedScene, c: Vector2i, what: String, rot: int) -> void:
	if not is_floor(c):
		return
	var level: PS1GridLevel = ctx.level
	var n: Node3D
	if scene:
		n = level.make_piece(scene, _cell3(ctx, c), rot)
	else:
		n = Marker3D.new()
		n.set_meta("ps1_cell", _cell3(ctx, c))
		n.set_meta("ps1_rot", rot)
		n.position = level.cell_to_local(_cell3(ctx, c))
		n.rotation.y = -rot * PI / 2.0
		n.name = "%s_%d_%d" % [what.capitalize(), c.x, c.y]
		n.add_to_group("ps1_gen_" + what, true)
	# markers never replace each other or a prop sharing the cell
	n.set_meta("ps1_slot", "ps1_gen_" + what if what != "spawn" else "ps1_gen_spawn_%d_%d" % [c.x, c.y])
	_add(ctx, n)

## Top-down picture of the map (scale = pixels per cell): floors, walls, doors (yellow), torches
## (orange), props, start (green), end (red), enemies (magenta).
func preview(scale := 6) -> Image:
	var img := Image.create_empty(size.x * scale + 1, size.y * scale + 1, false, Image.FORMAT_RGB8)
	img.fill(Color(0.07, 0.06, 0.09))
	var col := {ROOM: Color(0.62, 0.58, 0.5), HALL: Color(0.42, 0.4, 0.38), GROUND: Color(0.36, 0.42, 0.3)}
	for c in floor_cells():
		img.fill_rect(Rect2i(c * scale, Vector2i(scale, scale) + Vector2i.ONE), col[kind[idx(c)]])
	var wall_c := Color(0.02, 0.02, 0.03)
	for c in floor_cells():
		for r in 4:
			var e := Vector3i(c.x, c.y, r)
			var col_e: Color
			if doors.has(e): col_e = Color(0.95, 0.8, 0.2)
			elif blocked(c, r): col_e = wall_c
			else: continue
			var p := c * scale
			match r:
				0: img.fill_rect(Rect2i(p.x, p.y, scale + 1, 1), col_e)
				1: img.fill_rect(Rect2i(p.x + scale, p.y, 1, scale + 1), col_e)
				2: img.fill_rect(Rect2i(p.x, p.y + scale, scale + 1, 1), col_e)
				3: img.fill_rect(Rect2i(p.x, p.y, 1, scale + 1), col_e)
	var dot := func(c: Vector2i, color: Color, s: int) -> void:
		var o := c * scale + Vector2i(scale - s, scale - s) / 2 + Vector2i.ONE
		img.fill_rect(Rect2i(o, Vector2i(s, s)), color)
	for c in props:
		match props[c][0]:
			"pillar": dot.call(c, Color(0.2, 0.2, 0.22), scale - 2)
			"brazier": dot.call(c, Color(1.0, 0.45, 0.1), scale - 2)
			_: dot.call(c, Color(0.35, 0.25, 0.15), scale - 2)
	for l in lights:
		var c := Vector2i(l.x, l.y)
		dot.call(c + Vector2i.ZERO, Color(1.0, 0.55, 0.1), maxi(2, scale / 3))
	for s in spawns:
		dot.call(s, Color(0.9, 0.2, 0.8), maxi(2, scale / 2))
	if is_floor(start): dot.call(start, Color(0.2, 1.0, 0.3), scale - 1)
	if is_floor(end): dot.call(end, Color(1.0, 0.15, 0.1), scale - 1)
	return img

## The map as text (# wall, . floor, , ground, D door cell, S start, E end, x enemy, o prop).
func ascii() -> String:
	var lines := PackedStringArray()
	for z in size.y:
		var s := ""
		for x in size.x:
			var c := Vector2i(x, z)
			var ch := "#"
			if is_floor(c):
				ch = "," if kind[idx(c)] == GROUND else "."
				if props.has(c): ch = "o"
				if c in spawns: ch = "x"
				if c == start: ch = "S"
				if c == end: ch = "E"
			s += ch
		lines.append(s)
	return "\n".join(lines)
