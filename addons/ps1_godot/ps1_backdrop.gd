## Panoramas: far scenery (a castle on a mountain, a cathedral across the valley, mountain
## ridges) drawn PAST the camera's far plane, just in front of the sky. Each layer is flat-shaded
## and fades into the haze the farther it is, with mist rising from below — the classic
## "new area, look at that view" shot, nearly free (no lights, no fog, never culled).
##
##   var bd := PS1Backdrop.new()
##   bd.haze_color = Color(0.1, 0.12, 0.16)      # usually your fog/horizon color
##   add_child(bd)
##   bd.add_mesh(PS1Backdrop.ridge(3, 400.0, 40.0), Transform3D(Basis(), Vector3(0, -10, -260)), 0.75)
##   var castle := PS1Gothic.new()                # any mesh works; PS1Gothic surfaces named
##   castle.tower(Vector3.ZERO, 6, 50)            # "glow" become lit windows
##   bd.add_mesh(castle.mesh(), Transform3D(Basis(), Vector3(0, 0, -150)), 0.35)
##
## The big-reveal kit: citadel() (a cathedral city on a crag, lit windows), colossus() (a
## kneeling stone giant in the mist), broken_bridge(), add_lightning() (sheet lightning that
## lights the sky, the clouds and the far layers, with a bolt now and then; `lightning` signal
## for your thunder) and add_birds() (crows circling a point).
@tool
class_name PS1Backdrop
extends Node3D

## A lightning strike: strength 0..1 and the direction it came from (play thunder a bit later).
signal lightning(strength: float, direction: Vector3)

const SHADER := preload("res://addons/ps1_godot/shaders/ps1_backdrop.gdshader")

## Haze the far layers fade into (use the fog / sky horizon color).
@export var haze_color := Color(0.1, 0.12, 0.16)
## Base color of the silhouettes (before haze).
@export var color := Color(0.07, 0.07, 0.09)
## Color of "glow" surfaces (windows, fires).
@export var glow_color := Color(1.0, 0.62, 0.3)
## Direction the light (moon) comes from, for a slight shading of the faces.
@export var light_dir := Vector3(0.4, 0.5, -0.7)
@export_range(0.0, 1.0) var light_amount := 0.35
## World height of the valley mist and how tall its fade is.
@export var mist_height := 0.0
## Color of the valley mist (moonlit mist reads best a bit lighter than the haze).
@export var mist_color := Color(0.1, 0.12, 0.16)
@export var mist_fade := 12.0

## Adds a node (every mesh inside gets the silhouette look). haze 0 = near (full color),
## 1 = lost in the haze. Layers with less haze are drawn in front. Returns the node.
func add(node: Node3D, xf := Transform3D.IDENTITY, haze := 0.4, tint := Color(0, 0, 0, 0)) -> Node3D:
	node.transform = xf
	add_child(node)
	var order := 1.0 + (1.0 - haze) * 8.0
	var meshes: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mi in meshes:
		_apply(mi as MeshInstance3D, haze, tint if tint.a > 0.0 else color, order)
	return node

## Shortcut: wraps a Mesh in a MeshInstance3D and adds it.
func add_mesh(m: Mesh, xf := Transform3D.IDENTITY, haze := 0.4, tint := Color(0, 0, 0, 0)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	add(mi, xf, haze, tint)
	return mi

func _mat(col: Color, haze: float, order: float, glow: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("haze_color", haze_color)
	m.set_shader_parameter("haze", haze * (0.35 if glow else 1.0))
	m.set_shader_parameter("light_dir", light_dir)
	m.set_shader_parameter("light_amount", 0.0 if glow else light_amount)
	m.set_shader_parameter("mist_height", mist_height)
	m.set_shader_parameter("mist_color", mist_color)
	m.set_shader_parameter("mist_fade", mist_fade)
	m.set_shader_parameter("emission", 1.0 if glow else 0.0)
	m.set_shader_parameter("depth_order", order + (0.05 if glow else 0.0))
	return m

func _apply(mi: MeshInstance3D, haze: float, col: Color, order: float) -> void:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0
	mi.set_meta("ps1_no_bake", true)
	if mi.mesh == null:
		return
	for i in mi.mesh.get_surface_count():
		var glow := mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).surface_get_name(i) == "glow"
		mi.set_surface_override_material(i, _mat(glow_color if glow else col, haze, order, glow))

## A sea of mist filling the valleys up to `mist_height`: a big flat disc in `mist_color`.
## Peaks and buildings rise out of it (their feet already fade into the same color).
func add_mist_sea(radius := 2000.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 16
	for i in n:
		var a := TAU * i / n
		var b := TAU * (i + 1) / n
		for p in [Vector3.ZERO, Vector3(cos(b), 0, sin(b)) * radius, Vector3(cos(a), 0, sin(a)) * radius]:
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	add(mi, Transform3D(Basis(), Vector3(0, mist_height + mist_fade * 0.25, 0)), 0.0, mist_color)
	var m := mi.get_surface_override_material(0) as ShaderMaterial
	m.set_shader_parameter("light_amount", 0.0)
	m.set_shader_parameter("mist_height", -1.0e6)
	m.set_shader_parameter("depth_order", 0.5)   # behind every silhouette
	return mi

## A mountain ridge: a jagged strip `length` wide along X with peaks up to `height`, going down
## to y = -depth (hide its foot in the mist). Deterministic per seed.
static func ridge(seed_ := 1, length := 300.0, height := 40.0, points := 28, depth := 60.0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tops := []
	for i in points + 1:
		var x := -length * 0.5 + length * i / points
		var e := sin(float(i) / points * PI)
		var y := height * (0.35 + 0.65 * e) * rng.randf_range(0.55, 1.0)
		if i % 2 == 1:
			y *= rng.randf_range(0.6, 0.85)
		tops.append(Vector3(x, y, rng.randf_range(-6.0, 6.0)))
	for i in points:
		var a: Vector3 = tops[i]
		var b: Vector3 = tops[i + 1]
		var a0 := Vector3(a.x, -depth, a.z)
		var b0 := Vector3(b.x, -depth, b.z)
		var n := ((b - a).cross(a0 - a)).normalized()
		if n.z < 0.0:
			n = -n
		n = (n + Vector3(0, 0.3, 0)).normalized()
		# front faces +Z (toward a camera looking at -Z): clockwise from the front
		for p in [a0, a, b, a0, b, b0]:
			st.set_normal(n)
			st.add_vertex(p)
	return st.commit()

# ------------------------------------------------------------------ the big reveal

## A cathedral city on a crag, about 220 m wide and 150 m tall (scale with `size`), facing +Z.
## Windows are a "glow" surface (they take `glow_color`). Deterministic per seed.
static func citadel(seed_ := 1, size := 1.0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var k := size
	var g := PS1Gothic.new()
	g.surface("stone")
	# the crag: a pile of rocks narrowing to the top
	for i in 7:
		var w := rng.randf_range(50, 90) * k
		g.rock(Vector3(rng.randf_range(-90, 90) * k, rng.randf_range(-70, -35) * k, rng.randf_range(-40, 10) * k), Vector3(w, rng.randf_range(50, 80) * k, w * 0.7), seed_ * 10 + i)
	g.rock(Vector3(0, -30 * k, -10 * k), Vector3(200 * k, 60 * k, 90 * k), seed_ * 10 + 9)
	# curtain wall along the crag's edge
	g.box(Vector3(0, 6 * k, 22 * k), Vector3(190 * k, 12 * k, 3 * k))
	for x in range(-90, 91, 30):
		g.tower(Vector3(x * k, 0, 22 * k), 4.5 * k, rng.randf_range(16, 24) * k, 8, true)
	# the cathedral, facing +Z (the viewer): a twin-towered west front, the nave running back,
	# and behind it the crossing tower with one immense spire that rules the skyline
	g.box(Vector3(0, 24 * k, -22 * k), Vector3(26 * k, 48 * k, 60 * k))          # nave
	g.xform = Transform3D(Basis(Vector3.UP, PI / 2), Vector3.ZERO)
	g.gable(Vector3(22 * k, 48 * k, 0), Vector2(62 * k, 28 * k), 18 * k)
	g.xform = Transform3D.IDENTITY
	for sz in range(-46, 3, 10):
		for sx in [-1.0, 1.0]:
			g.buttress(Vector3(sx * 15 * k, 0, sz * k), 2.4 * k, 9 * k, 36 * k, sx * PI / 2)
			g.spire(Vector3(sx * 19 * k, 36 * k, sz * k), 1.4 * k, 10 * k, 4)
	for sx in [-1.0, 1.0]:   # west towers
		g.tower(Vector3(sx * 17 * k, 0, 9 * k), 7 * k, 72 * k, 8, false)
		g.spire(Vector3(sx * 17 * k, 72 * k, 9 * k), 7.6 * k, 36 * k, 8)
	g.box(Vector3(0, 30 * k, 10 * k), Vector3(22 * k, 60 * k, 8 * k))             # the front between them
	g.tower(Vector3(0, 48 * k, -30 * k), 10 * k, 46 * k, 8, false)                 # crossing tower
	g.spire(Vector3(0, 94 * k, -30 * k), 10.6 * k, 120 * k, 8)
	# the town crowding the slopes: towers with spires, gabled houses
	for i in 26:
		var x := rng.randf_range(-100, 100) * k
		if absf(x) < 34 * k:
			x += signf(x + 0.01) * 34 * k   # keep the cathedral front clear
		var z := rng.randf_range(-30, 18) * k
		var y := -absf(x) * 0.12
		if rng.randf() < 0.45:
			var r := rng.randf_range(2.5, 5.0) * k
			var h := rng.randf_range(18, 52) * k
			g.tower(Vector3(x, y, z), r, h, 6, rng.randf() < 0.4)
			if rng.randf() < 0.7:
				g.spire(Vector3(x, y + h, z), r * 1.1, rng.randf_range(8, 22) * k, 6)
		else:
			var w := rng.randf_range(8, 16) * k
			var h2 := rng.randf_range(8, 16) * k
			g.box(Vector3(x, y + h2 * 0.5, z), Vector3(w, h2, w * 0.7))
			g.gable(Vector3(x, y + h2, z), Vector2(w * 1.05, w * 0.75), w * 0.45)
	# windows: tall lancets on the nave, the rose, lit slits on the towers, a few house lights
	g.surface("glow")
	g.lancet(Vector3(0, 6 * k, 14.1 * k), 7 * k, 14 * k, 4)                        # the great door, lit
	g.rose(Vector3(0, 40 * k, 14.2 * k), 7 * k, 12)                                 # the rose window
	for sx in [-1.0, 1.0]:
		for y in [20, 40, 58]:
			g.lancet(Vector3(sx * 17 * k, y * k, 16.2 * k), 2.4 * k, 7 * k, 3)
	g.lancet(Vector3(0, 70 * k, -19.9 * k), 3.0 * k, 12 * k, 3)                     # belfry of the crossing
	for i in 70:   # house and tower lights (some pairs), big enough to read from far away
		var wx := rng.randf_range(-95, 95) * k
		var wy := rng.randf_range(-6, 40) * k
		var wz := rng.randf_range(8, 26) * k
		var ws := rng.randf_range(3.0, 5.5)
		g.box(Vector3(wx, wy, wz), Vector3(ws, ws * 1.5, 0.4) * k, 0.0, true, false)
		if rng.randf() < 0.35:
			g.box(Vector3(wx + ws * 1.8 * k, wy, wz), Vector3(ws, ws * 1.5, 0.4) * k, 0.0, true, false)
	# the nave's clerestory: a row of lit slits up high on both sides
	for z in range(-48, 2, 6):
		for sx in [-1.0, 1.0]:
			g.box(Vector3(sx * 13.2 * k, 36 * k, z * k), Vector3(0.4, 7.0, 2.6) * k, 0.0, true, false)
	return g.mesh()

## A kneeling stone giant (about 90 m tall with `size` 1), head bowed over a sword planted in
## the ground — the kind of thing half-sunk in the mist of a valley. Facing +Z.
static func colossus(size := 1.0) -> ArrayMesh:
	var k := size
	var g := PS1Gothic.new()
	g.surface("stone")
	# legs: one knee down, one up
	g.limb(Vector3(-10, 0, 0) * k, Vector3(-11, 22, 14) * k, 7 * k, 6 * k, 6)       # shin, kneeling leg
	g.limb(Vector3(-11, 22, 14) * k, Vector3(-8, 36, -4) * k, 7.5 * k, 8 * k, 6)    # thigh
	g.limb(Vector3(12, 0, 12) * k, Vector3(12, 30, 10) * k, 6.5 * k, 6 * k, 6)       # shin, raised knee
	g.limb(Vector3(12, 30, 10) * k, Vector3(6, 36, -6) * k, 7.5 * k, 8 * k, 6)
	# body bent forward, head bowed
	g.spindle(Vector3(0, 52, -2) * k, 34 * k, 11 * k, 14 * k, 10 * k, 7, 1.0, 0.1)
	g.limb(Vector3(0, 36, -4) * k, Vector3(0, 66, 4) * k, 11 * k, 13 * k, 7)
	g.limb(Vector3(0, 68, 6) * k, Vector3(0, 76, 14) * k, 6 * k, 5 * k, 6)           # neck
	g.spindle(Vector3(0, 74, 17) * k, 11 * k, 5 * k, 6.5 * k, 5 * k, 6, 1.0, 0.2)   # head
	# both hands on the pommel of a planted sword
	for sx in [-1.0, 1.0]:
		g.limb(Vector3(sx * 13, 64, 2) * k, Vector3(sx * 10, 48, 18) * k, 4.5 * k, 4 * k, 5)
		g.limb(Vector3(sx * 10, 48, 18) * k, Vector3(sx * 2.5, 50, 26) * k, 4 * k, 3.5 * k, 5)
	g.box(Vector3(0, 51, 27) * k, Vector3(10, 3, 3) * k)                               # crossguard
	g.box(Vector3(0, 22, 27) * k, Vector3(3.5, 56, 1.2) * k)                           # blade
	g.limb(Vector3(0, 52, 27) * k, Vector3(0, 58, 27) * k, 1.6 * k, 1.6 * k, 5)       # grip
	return g.mesh()

## A stone bridge on tall arches, `length` m along -Z from the origin, broken off near the end
## (the last arches fallen). Deck at y = 0.
static func broken_bridge(length := 300.0, span := 30.0, height := 60.0, broken_at := 0.7) -> ArrayMesh:
	var g := PS1Gothic.new()
	g.surface("stone")
	var n := int(length / span)
	var stop := int(n * broken_at)
	for i in n:
		var z := -span * (i + 0.5)
		if i < stop:
			g.box(Vector3(0, -1.5, z), Vector3(9, 3, span))                      # deck
			g.box(Vector3(-4, 1, z), Vector3(1, 2, span), 0.0, false, false)     # parapets
			g.box(Vector3(4, 1, z), Vector3(1, 2, span), 0.0, false, false)
		elif i == stop:
			# the jagged end: half a span, stepping down
			for j in 3:
				g.box(Vector3(0, -1.5 - j * 1.5, z + span * 0.5 - (j + 0.5) * span / 6.0), Vector3(9 - j * 2, 3, span / 6.0))
		# piers (the ones past the break still stand, shorter)
		var ph := height if i <= stop else height * (0.35 + 0.1 * (i % 3))
		g.box(Vector3(0, -3 - ph * 0.5, -span * (i + 1)), Vector3(10, ph, 6))
		if i < stop:
			g.box(Vector3(0, -6, -span * (i + 1)), Vector3(10, 6, 9))
	return g.mesh()

## Sheet lightning over the far scenery every `every` seconds (random in that range), from
## `direction` (on the horizon). Flashes the sky (if given) and the far layers, sometimes with a
## visible bolt, and emits `lightning(strength, direction)` — play your thunder from it.
## Call strike() to force one (a reveal).
func add_lightning(sky: PS1Sky = null, every := Vector2(7.0, 16.0), direction := Vector3(1, 0, 0), light: Light3D = null) -> void:
	_sky = sky
	_flash_light = light
	_flash_light_base = light.light_energy if light else 0.0
	_lightning_every = every
	_lightning_dir = Vector3(direction.x, 0, direction.z).normalized()
	_next_strike = randf_range(every.x, every.y)
	_bolt = MeshInstance3D.new()
	_bolt.visible = false
	add_child(_bolt)
	set_process(true)

## Strike now (strength 0..1).
func strike(strength := 1.0) -> void:
	if _lightning_dir == Vector3.ZERO:
		_lightning_dir = Vector3.RIGHT
	lightning.emit(strength, _lightning_dir)
	# a bolt: a jagged glowing line from the clouds to the horizon, somewhere in that direction
	if _bolt and (strength >= 0.99 or randf() < 0.75):
		var side := _lightning_dir.cross(Vector3.UP)
		var base := _lightning_dir * 700.0 + side * randf_range(-220.0, 220.0)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var p := base + Vector3(0, 420, 0)
		var w := 16.0
		while p.y > -20.0:
			var q := p + Vector3(0, -randf_range(30, 60), 0) + side * randf_range(-35, 35)
			var quad := [p - side * w, p + side * w, q + side * w * 0.8, p - side * w, q + side * w * 0.8, q - side * w * 0.8]
			for v in quad:
				st.add_vertex(v)
			quad.reverse()   # both faces
			for v in quad:
				st.add_vertex(v)
			p = q
			w *= 0.9
		_bolt.mesh = st.commit()
		# drawn like the far layers (past the far plane), full color
		var bm := _mat(Color(0.92, 0.95, 1.0), 0.0, 9.5, true)   # in front of every far layer
		bm.set_shader_parameter("mist_height", -1.0e6)
		_bolt.material_override = bm
		_bolt.extra_cull_margin = 16384.0
	# flicker: on, dim, on again, fade
	var tw := create_tween()
	tw.tween_method(_set_flash, 0.0, strength, 0.04)
	tw.tween_callback(func(): if _bolt and _bolt.mesh: _bolt.visible = true)
	tw.tween_method(_set_flash, strength, strength * 0.25, 0.08)
	tw.tween_method(_set_flash, strength * 0.25, strength * 0.9, 0.05)
	tw.tween_method(_set_flash, strength * 0.9, strength * 0.6, 0.25)
	tw.tween_callback(func(): if _bolt: _bolt.visible = false)
	tw.tween_method(_set_flash, strength * 0.6, 0.0, 0.6)

var _sky: PS1Sky
var _flash_light: Light3D
var _flash_light_base := 0.0
var _lightning_every := Vector2.ZERO
var _lightning_dir := Vector3.ZERO
var _next_strike := 0.0
var _bolt: MeshInstance3D

func _set_flash(v: float) -> void:
	if _sky:
		_sky.set_flash(v)
	if _flash_light:
		_flash_light.light_energy = _flash_light_base + v * 2.2
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		for i in mi.get_surface_override_material_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m:
				m.set_shader_parameter("flash", v)

func _process(dt: float) -> void:
	if Engine.is_editor_hint() or _lightning_every == Vector2.ZERO:
		return
	_next_strike -= dt
	if _next_strike <= 0.0:
		_next_strike = randf_range(_lightning_every.x, _lightning_every.y)
		strike(randf_range(0.45, 1.0))

## Crows circling `center` (radius, height spread), black flapping V shapes. Returns the node.
func add_birds(count := 12, center := Vector3.ZERO, radius := 25.0, spread := 8.0, color := Color(0.03, 0.03, 0.035)) -> Node3D:
	var root := Node3D.new()
	root.name = "Birds"
	add_child(root)
	root.top_level = true
	# one bird: body + two wings (the wing tips flap in the shader, marked by UV.x = 1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := func(a: Vector3, b: Vector3, c: Vector3, tip: Array) -> void:
		for i in 3:
			st.set_uv(Vector2(tip[i], 0))
			st.add_vertex([a, b, c][i])
	tri.call(Vector3(0, 0, -0.5), Vector3(-0.08, 0, 0.4), Vector3(0.08, 0, 0.4), [0, 0, 0])
	for sx in [-1.0, 1.0]:
		tri.call(Vector3(0, 0, -0.15), Vector3(sx * 0.95, 0, 0.1), Vector3(0, 0, 0.2), [0, 1, 0])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = st.commit()
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 color : source_color;
void vertex() {
	float ph = INSTANCE_CUSTOM.x;
	VERTEX.y += UV.x * sin(TIME * 9.0 + ph) * 0.55;
}
void fragment() { ALBEDO = color.rgb; }
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("color", color)
	mmi.material_override = m
	mmi.extra_cull_margin = 200.0
	root.add_child(mmi)
	var birds := []
	for i in count:
		birds.append([randf() * TAU, randf_range(0.6, 1.0) * radius, randf_range(-spread, spread), randf_range(0.18, 0.32) * (1.0 if randf() < 0.75 else -1.0), randf_range(1.6, 2.4)])
		mm.set_instance_custom_data(i, Color(randf() * TAU, 0, 0, 0))
	root.set_meta("birds", birds)
	root.set_meta("center", center)
	_bird_roots.append(root)
	set_process(true)
	return root

var _bird_roots: Array[Node3D] = []

func _physics_process(dt: float) -> void:
	for root in _bird_roots:
		if not is_instance_valid(root):
			continue
		var mm := (root.get_child(0) as MultiMeshInstance3D).multimesh
		var c: Vector3 = root.get_meta("center")
		var birds: Array = root.get_meta("birds")
		for i in birds.size():
			var b: Array = birds[i]
			b[0] += b[3] * dt
			var a: float = b[0]
			var p := c + Vector3(cos(a) * b[1], b[2] + sin(a * 2.3 + i) * 1.5, sin(a) * b[1])
			var fwd := Vector3(-sin(a), 0, cos(a)) * signf(b[3])
			var bas := Basis.looking_at(fwd, Vector3.UP).rotated(fwd, -signf(b[3]) * 0.35).scaled(Vector3.ONE * b[4])
			mm.set_instance_transform(i, Transform3D(bas, p))
