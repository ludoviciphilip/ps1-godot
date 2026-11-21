## PS1LevelGen demo: generates a map at runtime, builds it with the starter pieces, bakes it and
## walks the camera from the start to the end.
## Keys: 1-5 style, R new seed, Tab overview / walk.
## Args: -- --style=0..4 --seed=N --size=WxD --view=top|walk --screenshot=PATH --shot-t=S
extends Node3D

var style := PS1LevelGen.Style.DUNGEON
var map_seed := 1
var map_size := Vector2i(32, 32)
var view := "walk"
var map: PS1LevelGen
var level: PS1GridLevel
var cam: Camera3D
var env: WorldEnvironment
var _path: Array[Vector3] = []
var _t := 0.0
var _shot := ""
var _shot_t := 3.0
var _ready_to_walk := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--style="): style = int(a.get_slice("=", 1))
		elif a.begins_with("--seed="): map_seed = int(a.get_slice("=", 1))
		elif a.begins_with("--size="): map_size = Vector2i(int(a.get_slice("=", 1).get_slice("x", 0)), int(a.get_slice("=", 1).get_slice("x", 1)))
		elif a.begins_with("--view="): view = a.get_slice("=", 1)
		elif a.begins_with("--screenshot="): _shot = a.get_slice("=", 1)
		elif a.begins_with("--shot-t="): _shot_t = float(a.get_slice("=", 1))
	env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.01, 0.01, 0.015)
	env.environment.fog_enabled = true
	env.environment.fog_mode = Environment.FOG_MODE_DEPTH
	env.environment.fog_light_color = Color(0.01, 0.01, 0.015)
	env.environment.fog_depth_begin = 4.0
	env.environment.fog_depth_end = 22.0
	add_child(env)
	cam = Camera3D.new()
	cam.fov = 70
	add_child(cam)
	_regenerate()

func _regenerate() -> void:
	_ready_to_walk = false
	if level:
		level.queue_free()
	var t0 := Time.get_ticks_msec()
	map = PS1LevelGen.generate({style = style, seed = map_seed, width = map_size.x, depth = map_size.y})
	var t1 := Time.get_ticks_msec()
	level = PS1GridLevel.new()
	level.ambient = Color(0.08, 0.08, 0.1) if map.roofed else Color(0.3, 0.3, 0.36)
	level.cache_path = "user://procgen_demo_bake.res"
	level.ao_strength = 0.5
	if "--no-shadows" in OS.get_cmdline_user_args(): level.shadows = false
	map.build(level)
	var t2 := Time.get_ticks_msec()
	if not map.roofed:
		# open sky: a moonlight so the ruins aren't pitch black
		var moon := DirectionalLight3D.new()
		moon.light_color = Color(0.55, 0.6, 0.8)
		moon.light_energy = 0.6
		moon.rotation_degrees = Vector3(-50, 30, 0)
		level.add_child(moon)
	add_child(level)
	print("PROCGEN %s seed %d %dx%d: generate %d ms, build %d ms (%d pieces)" % [PS1LevelGen.STYLE_NAMES[style], map_seed,
		map_size.x, map_size.y, t1 - t0, t2 - t1, level.pieces().size()])
	t0 = Time.get_ticks_msec()
	await level.baked
	print("PROCGEN bake %d ms" % (Time.get_ticks_msec() - t0))
	_make_path()
	_apply_view()
	_t = 0.0
	_ready_to_walk = true

## Shortest walk from start to end (cell centers at eye height).
func _make_path() -> void:
	_path.clear()
	var d := map.distances(map.end)
	var c := map.start
	var guard := 0
	while c != map.end and guard < 5000:
		guard += 1
		_path.append(level.to_global(level.cell_to_local(Vector3i(c.x, 0, c.y))) + Vector3(0, 1.6, 0))
		var nxt := c
		for r in 4:
			var n := c + PS1LevelGen.D2[r]
			if not map.blocked(c, r) and not map.solid(n) and d[map.idx(n)] >= 0 and d[map.idx(n)] < d[map.idx(nxt)]:
				nxt = n
		if nxt == c:
			break
		c = nxt
	_path.append(level.to_global(level.cell_to_local(Vector3i(map.end.x, 0, map.end.y))) + Vector3(0, 1.6, 0))

func _apply_view() -> void:
	var top := view == "top"
	env.environment.fog_enabled = not top
	for p in level.pieces():
		if String(p.get_meta("ps1_slot", "")) == "ceiling":
			p.visible = not top
	if top:
		var w := map_size.x * level.cell_size
		var d := map_size.y * level.cell_size
		cam.position = Vector3(w * 0.5, maxf(w, d) * 0.75, d * 1.05)
		cam.look_at(Vector3(w * 0.5, 0, d * 0.45))

func _process(dt: float) -> void:
	_t += dt
	if _ready_to_walk and view == "walk" and _path.size() > 1:
		# glide along the path at 3 m/s, looking a few cells ahead
		var s := _t * 3.0 / level.cell_size
		var i := mini(int(s), _path.size() - 1)
		var f := s - int(s)
		var p: Vector3 = _path[i].lerp(_path[mini(i + 1, _path.size() - 1)], f) if i < _path.size() - 1 else _path[i]
		var ahead: Vector3 = _path[mini(i + 3, _path.size() - 1)]
		cam.position = cam.position.lerp(p, minf(1.0, dt * 6.0)) if _t > 0.2 else p
		if ahead.distance_to(cam.position) > 0.5:
			var look := cam.global_transform.looking_at(Vector3(ahead.x, cam.position.y - 0.2, ahead.z))
			cam.global_basis = cam.global_basis.slerp(look.basis, minf(1.0, dt * 3.0)) if _t > 0.2 else look.basis
	if _shot != "" and _ready_to_walk and _t >= _shot_t:
		var img := get_viewport().get_texture().get_image()
		img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
		img.save_png(_shot)
		get_tree().quit()

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match e.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			style = e.keycode - KEY_1
			_regenerate()
		KEY_R:
			map_seed += 1
			_regenerate()
		KEY_TAB:
			view = "top" if view == "walk" else "walk"
			_apply_view()
