## Headless regression tests for the toolkit:
##   godot --headless --path . res://tests/test_toolkit.tscn
extends Node3D

var _fails := 0

func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1

func _ready() -> void:
	await _test_bake()
	await _test_bake_cache()
	_test_screen_palette()
	_test_palette()
	_test_lod()
	_test_convert()
	_test_sprite()
	_test_grid_level()
	await _test_events()
	await _test_particles()
	_test_audio()
	await _test_crt()
	await _test_vertex_paint()
	_test_level_gen()
	await _test_on_signal()
	_test_settings()
	_test_locale()
	_test_anim()
	await _test_mist()
	await _test_shockwave()
	_test_gothic()
	_test_backdrop()
	_test_creature()
	await _test_collapse()
	await _test_event_freed()
	print("RESULT: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(1 if _fails else 0)

func _vertex_color_near(mi: MeshInstance3D, p: Vector3) -> Color:
	var arr := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var best := 0
	for i in verts.size():
		if (mi.global_transform * verts[i]).distance_to(p) < (mi.global_transform * verts[best]).distance_to(p):
			best = i
	return cols[best]

func _test_bake() -> void:
	print("PS1Bake")
	var root := Node3D.new()
	add_child(root)
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	plane.subdivide_width = 19
	plane.subdivide_depth = 19
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = PS1.make(null, {})
	root.add_child(ground)
	var wall := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 3, 4)
	wall.mesh = bm
	wall.position = Vector3(3, 1.5, 0)
	wall.material_override = PS1.make(null, {})
	root.add_child(wall)
	var light := OmniLight3D.new()
	light.omni_range = 10.0
	light.light_energy = 2.0
	light.position = Vector3(0, 1.0, 0)
	add_child(light)
	await PS1Bake.bake_scene(root, Color.BLACK, true, [light])
	var near := _vertex_color_near(ground, Vector3(1, 0, 0))
	var behind := _vertex_color_near(ground, Vector3(5, 0, 0))
	var side := _vertex_color_near(ground, Vector3(-5, 0, 0))
	print("    near=%s behind_wall=%s same_dist_open=%s" % [near, behind, side])
	check(near.r > 0.1, "ground near the light is lit")
	check(side.r > 0.005, "ground at 5 m (open side) receives light")
	check(behind.r < side.r * 0.2, "ground behind the wall is in shadow")
	check(PS1Convert.mode_of(ground.material_override) == "unlit", "material switched to unlit")
	light.queue_free()
	root.queue_free()

func _scene_for_cache() -> Node3D:
	var root := Node3D.new()
	root.name = "CacheTest"
	add_child(root)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.subdivide_width = 4
	pm.subdivide_depth = 4
	mi.mesh = pm
	mi.material_override = PS1.make(null, {})
	root.add_child(mi)
	return root

func _test_bake_cache() -> void:
	print("PS1Bake cache")
	var path := "user://test_bake_cache.res"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1, 0)
	add_child(light)
	var r1 := _scene_for_cache()
	var first: bool = await PS1Bake.bake_scene_cached(r1, Color.BLACK, path, true, [light])
	var baked_color := _vertex_color_near(r1.get_child(0), Vector3.ZERO)
	r1.free()
	var r2 := _scene_for_cache()
	var second: bool = await PS1Bake.bake_scene_cached(r2, Color.BLACK, path, true, [light])
	var cached_color := _vertex_color_near(r2.get_child(0), Vector3.ZERO)
	check(not first and FileAccess.file_exists(path), "first run bakes and saves the cache")
	check(second, "second run loads from the cache")
	check(baked_color.is_equal_approx(cached_color) and baked_color.r > 0.0, "cached result equals the bake")
	r2.free()
	light.position = Vector3(2, 1, 0)
	var r3 := _scene_for_cache()
	var third: bool = await PS1Bake.bake_scene_cached(r3, Color.BLACK, path, true, [light])
	check(not third, "moving a light invalidates the cache")
	r3.free()
	light.free()

func _test_screen_palette() -> void:
	print("Screen palette")
	PS1.set_screen_palette(PackedColorArray([Color.BLACK, Color.RED, Color.WHITE]))
	check(is_equal_approx(PS1.get_global("ps1_palette_size"), 3.0), "palette size set")
	var tex: Texture2D = PS1.get_global("ps1_palette")
	check(tex != null and tex.get_width() == 3, "palette texture is Nx1")
	PS1.clear_screen_palette()
	check(PS1.get_global("ps1_palette_size") == 0.0, "palette cleared")
	print("PS1 globals")
	check(PS1.get_global("ps1_jitter_enabled") == 1.0, "reads defaults from project settings")
	PS1.toggle("ps1_jitter_enabled")
	check(PS1.get_global("ps1_jitter_enabled") == 0.0, "toggle works at runtime (was broken: get() is editor-only)")
	PS1.toggle("ps1_jitter_enabled")

func _test_palette() -> void:
	print("PS1Palette")
	var tex := PS1Textures.mossy_rock()
	var q := PS1Palette.quantize(tex, 16)
	var img := q.get_image()
	var colors := {}
	for y in img.get_height():
		for x in img.get_width():
			colors[img.get_pixel(x, y).to_html()] = true
	var orig := {}
	var oi := tex.get_image()
	for y in oi.get_height():
		for x in oi.get_width():
			orig[oi.get_pixel(x, y).to_html()] = true
	print("    original colors=%d quantized=%d" % [orig.size(), colors.size()])
	check(colors.size() <= 16, "quantized texture has <= 16 colors")
	check(orig.size() > 16, "source texture had more than 16 colors")
	if OS.get_cmdline_user_args().has("--save-images"):
		var a := tex.get_image()
		var b := q.get_image()
		a.convert(Image.FORMAT_RGB8)
		b.convert(Image.FORMAT_RGB8)
		a.resize(256, 256, Image.INTERPOLATE_NEAREST)
		b.resize(256, 256, Image.INTERPOLATE_NEAREST)
		var out := Image.create(520, 256, false, Image.FORMAT_RGB8)
		out.fill(Color.BLACK)
		out.blit_rect(a, Rect2i(0, 0, 256, 256), Vector2i(0, 0))
		out.blit_rect(b, Rect2i(0, 0, 256, 256), Vector2i(264, 0))
		out.save_png(ProjectSettings.globalize_path("res://docs/palette.png"))

func _test_lod() -> void:
	print("PS1LOD")
	var lod := PS1LOD.new()
	lod.distances = PackedFloat32Array([10.0])
	lod.draw_distance = 20.0
	lod.fade = 2.0
	var a := MeshInstance3D.new()
	a.mesh = BoxMesh.new()
	a.material_override = PS1.make(null, {})
	var b := MeshInstance3D.new()
	b.mesh = BoxMesh.new()
	b.material_override = PS1.make(null, {})
	lod.add_child(a)
	lod.add_child(b)
	add_child(lod)
	var fa: Vector4 = a.get_instance_shader_parameter("ps1_fade")
	var fb: Vector4 = b.get_instance_shader_parameter("ps1_fade")
	print("    level0=%s level1=%s" % [fa, fb])
	check(fa == Vector4(0, 0, 9, 11), "level 0 fades out around 10 m")
	check(fb == Vector4(9, 11, 19, 21), "level 1 fades in at 10 m and out at 20 m")
	check(a.visibility_range_end > 11.0 and b.visibility_range_begin < 9.0, "culling ranges have margins")
	lod.queue_free()

func _test_sprite() -> void:
	print("PS1Sprite")
	var sp := PS1Sprite.new()
	sp.hframes = 4
	sp.vframes = 2
	add_child(sp)
	sp.frame = 5
	var r: Vector4 = sp.get_instance_shader_parameter("ps1_uv_rect")
	check(r.is_equal_approx(Vector4(0.25, 0.5, 0.25, 0.5)), "frame 5 of 4x2 -> uv rect (0.25,0.5,0.25,0.5): %s" % r)
	check(PS1Convert.mode_of(sp.material_override) == "billboard", "lit sprite uses billboard material")
	sp.lit = false
	check(PS1Convert.mode_of(sp.material_override) == "billboard_unlit", "unlit sprite uses billboard_unlit")
	check(sp.material_override.get_shader_parameter("use_vertex_color") == false, "unlit sprite ignores vertex color")
	PS1.set_composite(1.0)
	check(PS1.get_global("ps1_composite") == 1.0, "composite filter on")
	PS1.set_composite(0.0)
	sp.queue_free()

func _test_convert() -> void:
	print("PS1Convert")
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	sm.alpha_scissor_threshold = 0.3
	var m := PS1Convert.to_ps1(sm)
	check(PS1Convert.mode_of(m) == "cutout", "alpha scissor -> cutout")
	check(is_equal_approx(m.get_shader_parameter("alpha_cut"), 0.3), "keeps the scissor threshold")
	var sm2 := StandardMaterial3D.new()
	sm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	check(PS1Convert.mode_of(PS1Convert.to_ps1(sm2)) == "dither_alpha", "alpha blend -> dither_alpha")

func _test_grid_level() -> void:
	print("PS1GridLevel")
	var lvl := PS1GridLevel.new()
	add_child(lvl)
	var floor_s := _piece_scene("floor", false)
	var wall_s := _piece_scene("wall", true)
	var r := lvl.place(floor_s, Vector3i(2, 0, -1))
	check(r[0].position == Vector3(4, 0, -2), "cell -> position (cell 2 m)")
	check(lvl.local_to_cell(Vector3(4.6, 0.2, -2.7)) == Vector3i(2, 0, -1), "position -> cell")
	r = lvl.place(floor_s, Vector3i(2, 0, -1))
	check(r[1].size() == 1 and lvl.pieces_at(Vector3i(2, 0, -1)).size() == 1, "same slot replaces")
	lvl.place(wall_s, Vector3i(2, 0, -1), 0)
	lvl.place(wall_s, Vector3i(2, 0, -1), 1)
	check(lvl.pieces_at(Vector3i(2, 0, -1)).size() == 3, "edge pieces: one per edge + floor")
	var w1: Node3D = lvl.pieces_at(Vector3i(2, 0, -1), "wall:1")[0]
	check(w1.global_transform * Vector3(0, 0, -1) == Vector3(5, 0, -2).snapped(Vector3.ONE * 0.001) or
		(w1.global_transform * Vector3(0, 0, -1)).distance_to(Vector3(5, 0, -2)) < 0.01, "rot 1 = east edge")
	var gone := lvl.erase(Vector3i(2, 0, -1), "wall:0")
	check(gone.size() == 1 and lvl.pieces_at(Vector3i(2, 0, -1)).size() == 2, "erase one slot")
	var n := lvl.paint_ascii(PackedStringArray(["#.", ".#"]), {"#": [floor_s], ".": [[wall_s, 2]]}, 1, Vector2i(10, 10))
	check(n == 4 and lvl.pieces_at(Vector3i(11, 1, 10), "wall:2").size() == 1, "paint_ascii")
	for g in gone:
		g.free()
	# auto walls
	var auto := PS1GridLevel.new()
	add_child(auto)
	auto.auto_wall = wall_s
	auto.auto_ceiling = _piece_scene("ceiling", false)
	auto.place(floor_s, Vector3i(0, 0, 0))
	var a1 := auto.update_auto([Vector3i(0, 0, 0)])
	check(a1[0].size() == 5, "1 floor -> 4 walls + ceiling (%d)" % a1[0].size())
	auto.place(floor_s, Vector3i(1, 0, 0))
	var a2 := auto.update_auto([Vector3i(1, 0, 0)])
	check(a2[1].size() == 1 and auto.pieces_at(Vector3i(0, 0, 0), "wall:1").is_empty(), "neighbor floor removes the shared wall")
	check(auto.pieces_at(Vector3i(1, 0, 0), "wall:1").size() == 1 and auto.pieces_at(Vector3i(1, 0, 0), "wall:3").is_empty(), "new cell walls only outside")
	for e in auto.erase(Vector3i(1, 0, 0), "floor"):
		e.free()
	var a3 := auto.update_auto([Vector3i(1, 0, 0)])
	check(auto.pieces_at(Vector3i(0, 0, 0), "wall:1").size() == 1 and auto.pieces_at(Vector3i(1, 0, 0)).is_empty(), "erasing floor restores the wall, cleans the cell")
	for x in a2[1] + a3[1]:
		if is_instance_valid(x) and x.get_parent() == null:
			x.free()
	auto.queue_free()
	lvl.queue_free()

func _piece_scene(slot: String, edge: bool) -> PackedScene:
	var n := StaticBody3D.new()
	n.set_meta("ps1_slot", slot)
	if edge:
		n.set_meta("ps1_edge", true)
	var ps := PackedScene.new()
	ps.pack(n)
	n.free()
	return ps

class _Probe extends Node3D:
	var calls := []
	func hello(x) -> void:
		calls.append(x)

func _test_events() -> void:
	print("PS1Event")
	PS1Events.reset()
	var ev := PS1Event.new()
	ev.name = "Chest"
	var probe := _Probe.new()
	probe.name = "Probe"
	ev.add_child(probe)
	var closed := Node3D.new(); closed.name = "Closed"; ev.add_child(closed)
	var open := Node3D.new(); open.name = "Open"; ev.add_child(open)
	# page 1: interact -> if gold >= 0 then call probe + set $taken = 1 + gold += 5
	var p1 := PS1EventPage.new()
	p1.graphic = NodePath("Closed")
	var call := PS1CmdCall.new(); call.target = NodePath("Probe"); call.method = "hello"; call.args = ["hi"]
	var taken := PS1CmdSetVar.new(); taken.variable = "$taken"; taken.value = 1
	var gold := PS1CmdSetVar.new(); gold.variable = "gold"; gold.op = PS1CmdSetVar.Op.ADD; gold.value = 5
	var cif := PS1CmdIf.new(); cif.condition.variable = "gold"; cif.condition.op = PS1Condition.Op.GREATER_OR_EQUAL; cif.condition.value = 0
	cif.then_commands = [call, taken]
	var never := PS1CmdSetVar.new(); never.variable = "never"; never.value = 9
	cif.else_commands = [never]
	p1.commands = [cif, gold]
	# page 2: only after $taken == 1 (no trigger)
	var p2 := PS1EventPage.new()
	p2.trigger = PS1EventPage.Trigger.NONE
	p2.graphic = NodePath("Open")
	p2.condition = PS1Condition.new(); p2.condition.variable = "$taken"; p2.condition.value = 1
	ev.pages = [p1, p2]
	add_child(ev)
	var actor := Node3D.new()
	add_child(actor)
	await get_tree().process_frame
	await get_tree().process_frame
	check(ev.page == p1 and closed.visible and not open.visible, "page 1 active, its graphic shown")
	check(ev.can_interact(actor), "can interact in range")
	actor.position = Vector3(10, 0, 0)
	check(not ev.can_interact(actor), "not out of range")
	actor.position = Vector3.ZERO
	var started := [0]
	var on_start := func(): started[0] += 1
	PS1Events.signals().event_started.connect(on_start)
	await ev.run(actor)
	check(probe.calls == ["hi"], "call method ran (%s)" % [probe.calls])
	check(PS1Events.get_var("gold") == 5 and PS1Events.get_var("never") == 0, "if/then + add var")
	check(ev.page == p2 and open.visible and not closed.visible, "local var switched to page 2")
	check(not ev.can_interact(actor) and started[0] == 1, "page 2 has no trigger; started signal once")
	PS1Events.signals().event_started.disconnect(on_start)
	# choices through the default dialog box
	var ch := PS1CmdChoice.new()
	ch.question = "Pray?"
	var a := PS1CmdSetVar.new(); a.variable = "prayed"; a.value = 1
	var b := PS1CmdSetVar.new(); b.variable = "prayed"; b.value = 2
	ch.branches[0].commands = [a]
	ch.branches[1].commands = [b]
	var txt := PS1CmdText.new(); txt.speaker = "Stone"; txt.text = "Here lies..."
	var p3 := PS1EventPage.new(); p3.commands = [txt, ch]
	var done := [false]
	var runner := func(): await ev.run(actor, p3); done[0] = true
	runner.call()
	for i in 3: await get_tree().process_frame
	var box := PS1Events.dialog()
	check(box.is_open(), "dialog box opened for Show Text")
	box.debug_confirm()
	for i in 3: await get_tree().process_frame
	box.debug_confirm(1)
	for i in 3: await get_tree().process_frame
	check(done[0] and PS1Events.get_var("prayed") == 2, "choice picked branch 2")
	check(ch.describe().contains("[Yes]") and cif.describe() == "If gold >= 0", "describe(): %s | %s" % [ch.describe(), cif.describe()])
	ev.queue_free()
	actor.queue_free()

func _test_particles() -> void:
	print("PS1Particles")
	var p := PS1Particles.preset("embers")
	p.update_fps = 1000.0
	add_child(p)
	await get_tree().create_timer(0.5).timeout   # tempo real: quadros headless podem durar ~1 ms
	check(p.alive_count() > 0, "continuous emitter spawns (%d alive)" % p.alive_count())
	var b := PS1Particles.spawn(self, "sparks", Vector3(3, 1, 0))
	b.update_fps = 1000.0
	await get_tree().process_frame
	check(b.alive_count() == b.burst_count, "one-shot burst at spawn (%d)" % b.alive_count())
	check(b._pos[0].distance_to(Vector3(3, 1, 0)) < 0.5, "burst happens where it was placed (deferred)")
	b.amount = 4
	check(b.alive_count() <= 4 and b._pos.size() == 4, "amount can shrink at runtime")
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(b) and Time.get_ticks_msec() - t0 < 3000:
		await get_tree().process_frame
	check(not is_instance_valid(b), "one-shot frees itself")
	for n in ["embers", "sparks", "smoke", "mist", "dust", "ash", "motes", "soul", "burst", "blood", "fog_puff"]:
		var q := PS1Particles.preset(n)
		check(q.texture_name != "" and PS1Particles.sheet(q.texture_name) != null, "preset " + n)
		q.free()
	p.queue_free()

func _test_audio() -> void:
	print("PS1Audio")
	PS1Audio.setup()
	check(AudioServer.get_bus_index("SFX") != -1 and AudioServer.get_bus_index("Music") != -1, "buses created")
	var old := PS1Audio.sound_dir
	PS1Audio.sound_dir = "res://tests/_no_such_dir"
	check(PS1Audio.streams("nothing").is_empty(), "missing sound -> empty list, no crash")
	PS1Audio.sound_dir = old
	var gen := AudioStreamGenerator.new()
	check(PS1Audio.play(gen, Vector3.ZERO) != null, "play 3D stream")
	PS1Audio.set_reverb(0.9, 0.4)
	var rv := AudioServer.get_bus_effect(AudioServer.get_bus_index("SFX"), 0) as AudioEffectReverb
	check(is_equal_approx(rv.room_size, 0.9), "set_reverb")

func _test_crt() -> void:
	print("CRT")
	var w := get_window()
	var before := w.content_scale_mode
	PS1.set_crt(1.0)
	await get_tree().process_frame
	check(w.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and is_equal_approx(float(PS1.get_global("ps1_crt")), 1.0), "crt on: native resolution")
	PS1.set_crt(0.0)
	await get_tree().process_frame
	check(w.content_scale_mode == before, "crt off: back to the base stretch mode")

func _test_vertex_paint() -> void:
	print("PS1VertexPaint")
	var root := Node3D.new()
	add_child(root)
	# a floor with a wall on it: AO must darken the floor next to the wall, not far away
	var floor_ := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(6, 6); pm.subdivide_width = 11; pm.subdivide_depth = 11
	floor_.mesh = pm
	floor_.material_override = PS1.make(null, {})
	root.add_child(floor_)
	var wall := StaticBody3D.new()
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(6, 3, 0.4); cs.shape = bs
	wall.add_child(cs); wall.position = Vector3(0, 1.5, -2.0)
	root.add_child(wall)
	var copy := MeshInstance3D.new(); copy.mesh = pm; root.add_child(copy)
	var n: int = await PS1VertexPaint.ambient_occlusion(floor_, 1.5, 0.8)
	check(n > 100, "AO painted %d vertices" % n)
	check(copy.mesh == pm and floor_.mesh != pm, "painting made the mesh unique (copy untouched)")
	var arr := floor_.mesh.surface_get_arrays(0)
	var near := 1.0
	var far := 0.0
	for i in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		var v: Vector3 = arr[Mesh.ARRAY_VERTEX][i]
		var l: float = (arr[Mesh.ARRAY_COLOR][i] as Color).get_luminance()
		if v.z < -1.6 and absf(v.x) < 2.0: near = minf(near, l)
		if v.z > 2.0: far = maxf(far, l)
	check(near < far - 0.15, "AO darker by the wall (%.2f) than in the open (%.2f)" % [near, far])
	check(floor_.material_override.get_shader_parameter("use_vertex_color") == true, "material shows vertex colors")
	PS1VertexPaint.clear(floor_)
	PS1VertexPaint.gradient(floor_, Color(0.2, 0.2, 0.2), Color.WHITE, 0.0, 1.0)
	check(is_equal_approx((floor_.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR][0] as Color).r, 0.2), "gradient at floor height")
	# bake multiplies by paint
	var light := OmniLight3D.new(); light.position = Vector3(0, 2, 2); light.omni_range = 10; root.add_child(light)
	PS1Bake.bake_mesh(floor_, Color(1, 1, 1), [])
	var baked: Color = floor_.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR][0]
	check(absf(baked.r - 0.1) < 0.01, "bake multiplies light by paint (%.3f, expected 0.1)" % baked.r)
	root.queue_free()

func _test_level_gen() -> void:
	print("PS1LevelGen")
	var bad := 0
	var total := 0
	for st in PS1LevelGen.STYLE_NAMES.size():
		for sd in 12:
			for sz in [Vector2i(12, 12), Vector2i(24, 40), Vector2i(48, 48)]:
				var m := PS1LevelGen.generate({style = st, seed = sd, width = sz.x, depth = sz.y, enemies = 5})
				var ck := m.check()
				total += 1
				var ok: bool = ck.floors > 0 and ck.unreachable.is_empty() and m.is_floor(m.start) and m.is_floor(m.end) \
					and m.start != m.end and not m.solid(m.start) and not m.solid(m.end)
				for sp in m.spawns:
					if not m.is_floor(sp) or m.solid(sp) or sp == m.start:
						ok = false
				if not ok:
					bad += 1
					if bad < 4:
						print("    bad: %s seed %d %s: %s" % [PS1LevelGen.STYLE_NAMES[st], sd, sz, ck])
	check(bad == 0, "%d maps (5 styles x 12 seeds x 3 sizes) connected, start/end/spawns valid (%d bad)" % [total, bad])
	var a := PS1LevelGen.generate({style = 0, seed = 42})
	var b := PS1LevelGen.generate({style = 0, seed = 42})
	var c := PS1LevelGen.generate({style = 0, seed = 43})
	check(a.ascii() == b.ascii() and a.ascii() != c.ascii(), "same seed = same map, other seed = other map")
	var lvl := PS1GridLevel.new()
	lvl.cache_path = "user://test_gen_bake.res"
	var m := PS1LevelGen.generate({style = PS1LevelGen.Style.CATACOMBS, seed = 1, width = 16, depth = 16})
	var r: Array = m.build(lvl)
	var starts: Array = r[0].filter(func(n): return n.is_in_group("ps1_gen_start"))
	check(r[0].size() > 100 and r[1].is_empty() and starts.size() == 1, "build: %d pieces, one start marker" % r[0].size())
	var r2: Array = m.build(lvl, null, 0, Vector2i.ZERO, false)
	check(lvl.pieces().size() == r[0].size(), "building again without clear replaces cell by cell (%d pieces)" % lvl.pieces().size())
	for n in r2[1]:
		n.free()
	lvl.free()

func _test_on_signal() -> void:
	print("PS1Event on signal (drops)")
	var mon := Node3D.new()
	var gd := GDScript.new()
	gd.source_code = "extends Node3D\nsignal died(who)\nfunc kill():\n\tdied.emit(self)\n"
	gd.reload()
	mon.set_script(gd)
	mon.position = Vector3(5, 0, -3)
	add_child(mon)
	check(PS1Event.death_signal_of(mon) == "died", "death signal detected on the monster")
	var loot := Node3D.new()
	loot.name = "Loot"
	var ps := PackedScene.new()
	ps.pack(loot)
	loot.free()
	var ev := PS1Event.new()
	var page := PS1EventPage.new()
	page.trigger = PS1EventPage.Trigger.ON_SIGNAL
	page.signal_name = &"died"
	var kills := PS1CmdSetVar.new(); kills.variable = "test_kills"; kills.op = PS1CmdSetVar.Op.ADD
	var spawn := PS1CmdSpawn.new(); spawn.scene = ps; spawn.bounce = false
	var always := PS1CmdChance.new(); always.percent = 100.0; always.then_commands = [spawn]
	var never := PS1CmdChance.new(); never.percent = 0.0; never.has_else = true
	var flag := PS1CmdSetVar.new(); flag.variable = "test_else"; flag.value = 1
	never.else_commands = [flag]
	page.commands = [kills, always, never]
	ev.pages = [page]
	ev.position = Vector3(-1, 0, 0)   # the event is NOT where the monster dies
	mon.add_child(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	mon.global_position = Vector3(7, 0, -4)   # it walked before dying
	mon.kill()
	await get_tree().process_frame
	var drops := get_tree().current_scene.find_children("Loot*", "", false, false)
	check(PS1Events.get_var("test_kills") == 1 and PS1Events.get_var("test_else") == 1, "on-defeated page ran (var + chance else)")
	check(drops.size() == 1 and drops[0].global_position.distance_to(Vector3(7, 0, -4)) < 0.01, "drop spawned where the monster fell")
	mon.kill()
	await get_tree().process_frame
	check(PS1Events.get_var("test_kills") == 2, "runs again on the next death (conditions decide 'once')")
	var t := PS1CmdText.new()
	PS1Events.set_var("runes", 2)
	check(PS1CmdText.format("Runes: {runes}/3", null) == "Runes: 2/3", "{variables} in text")
	for d in get_tree().current_scene.find_children("Loot*", "", false, false):
		d.queue_free()
	mon.queue_free()

func _test_settings() -> void:
	print("PS1Settings")
	PS1Settings.setup()
	PS1Settings.set_value("video/jitter", false)
	check(float(PS1.get_global("ps1_jitter_enabled")) == 0.0, "jitter off applied to the shader global")
	PS1Settings.set_value("video/jitter", true)
	PS1Audio.setup()
	PS1Settings.set_value("audio/music", 50.0)
	var db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	check(absf(db - linear_to_db(0.5)) < 0.1, "music 50%% -> %.1f dB" % db)
	PS1Settings.set_value("audio/sfx", 400.0)
	check(PS1Settings.get_value("audio/sfx") == 100.0, "ranges are clamped")
	PS1Settings.set_value("video/brightness", 120.0)
	var cf := ConfigFile.new()
	cf.load(PS1Settings.PATH)
	check(cf.get_value("video", "brightness") == 120.0, "saved to %s" % PS1Settings.PATH)
	PS1Settings.reset_section("video")
	check(PS1Settings.get_value("video/brightness") == 100.0, "reset section")
	# custom option + rebinding with swap
	var hits := [0]
	PS1Settings.add_option({key = "game/shake", section = "video", label = "Screen shake", type = "bool", default = true,
		apply = func(_v): hits[0] += 1})
	PS1Settings.set_value("game/shake", false)
	check(hits[0] >= 1 and PS1Settings.get_value("game/shake") == false, "custom option applied")
	for a in ["t_jump", "t_attack"]:
		if not InputMap.has_action(a): InputMap.add_action(a)
		InputMap.action_erase_events(a)
	var k1 := InputEventKey.new(); k1.physical_keycode = KEY_SPACE
	var k2 := InputEventKey.new(); k2.physical_keycode = KEY_F
	InputMap.action_add_event("t_jump", k1)
	InputMap.action_add_event("t_attack", k2)
	PS1Settings.add_binding("t_jump", "Jump")
	PS1Settings.add_binding("t_attack", "Attack")
	var nk := InputEventKey.new(); nk.physical_keycode = KEY_F
	PS1Settings.rebind("t_jump", "kb", nk)
	check(PS1Settings.event_label(PS1Settings.binding("t_jump").kb) != "" and InputMap.action_has_event("t_jump", nk)
		and PS1Settings.event_to_string(PS1Settings.binding("t_attack").kb) == "key:%d" % KEY_SPACE, "rebind F to jump swaps attack to Space")
	var j := PS1Settings.string_to_event("axis:5:1")
	check(j is InputEventJoypadMotion and PS1Settings.event_label(j) == "RT", "gamepad trigger serialized (%s)" % PS1Settings.event_label(j))
	PS1Settings.reset_section("controls")
	check(PS1Settings.event_to_string(PS1Settings.binding("t_jump").kb) == "key:%d" % KEY_SPACE, "reset restores bindings")
	PS1Settings.reset_section("audio")
	for k in ["game/shake", "bindings/t_jump", "bindings/t_attack"]:
		PS1Settings.remove_option(k)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PS1Settings.PATH))

func _test_locale() -> void:
	print("PS1Locale")
	var tr_es := Translation.new()
	tr_es.locale = "es"
	tr_es.add_message("Open the chest", "Abrir el cofre")
	tr_es.add_message("Runes: {runes}/3", "Runas: {runes}/3")
	TranslationServer.add_translation(tr_es)
	PS1Locale.set_language("es")
	check(PS1Locale.t("Open the chest") == "Abrir el cofre" and PS1Locale.t("Untranslated") == "Untranslated", "translate + fallback to the original")
	PS1Events.set_var("runes", 2)
	check(PS1CmdText.format(PS1Locale.t("Runes: {runes}/3"), null) == "Runas: 2/3", "translated text keeps {variables}")
	var ev := PS1Event.new()
	var pg := PS1EventPage.new(); pg.prompt = "Open the chest"
	ev.pages = [pg]
	ev.page = pg
	check(ev.prompt_text() == "Abrir el cofre", "event prompts are translated")
	ev.free()
	PS1Locale.set_language("en")
	TranslationServer.remove_translation(tr_es)
	var csv := "user://test_strings.csv"
	if FileAccess.file_exists(csv): DirAccess.remove_absolute(ProjectSettings.globalize_path(csv))
	var r := PS1Locale.update_csv(csv, ["pt", "es"], "en", ["res://tests"])
	var r2 := PS1Locale.update_csv(csv, ["pt", "es"], "en", ["res://tests"])
	var txt := FileAccess.get_file_as_string(csv)
	check(r.added > 0 and r2.added == 0 and txt.begins_with("keys,en,pt,es") and txt.contains("Collected by the CSV test"),
		"CSV: %d texts collected, second run adds none" % r.added)
	print("    (%s)" % tr("Collected by the CSV test"))

func _test_anim() -> void:
	print("PS1Anim")
	var src := Animation.new(); src.length = 2.0
	var dst := Animation.new(); dst.length = 1.0
	var ts := src.add_track(Animation.TYPE_ROTATION_3D); src.track_set_path(ts, "Skel:LeftLeg")
	src.rotation_track_insert_key(ts, 0.0, Quaternion.IDENTITY)
	src.rotation_track_insert_key(ts, 2.0, Quaternion(Vector3.RIGHT, PI * 0.5))
	var hp := src.add_track(Animation.TYPE_POSITION_3D); src.track_set_path(hp, "Skel:Hips")
	src.position_track_insert_key(hp, 0.0, Vector3(5, 1.0, 5)); src.position_track_insert_key(hp, 2.0, Vector3(5, 0.5, 5))
	var td := dst.add_track(Animation.TYPE_ROTATION_3D); dst.track_set_path(td, "Skel:LeftLeg")
	dst.rotation_track_insert_key(td, 0.0, Quaternion.IDENTITY)
	var hd := dst.add_track(Animation.TYPE_POSITION_3D); dst.track_set_path(hd, "Skel:Hips")
	dst.position_track_insert_key(hd, 0.0, Vector3(0, 1.0, 0))
	# dst 0..1 plays src 1..2
	var n := PS1Anim.graft(dst, src, PackedStringArray(["Hips", "LeftLeg"]), [Vector2(0, 1), Vector2(1, 2)])
	var q := dst.rotation_track_interpolate(td, 0.0)
	var hip := dst.position_track_interpolate(hd, 1.0)
	check(n == 2 and absf(q.get_angle() - PI * 0.25) < 0.05, "graft time-warps the leg (%.2f rad at t=0)" % q.get_angle())
	check(absf(hip.y - 0.5) < 0.01 and hip.x == 0.0, "root height follows the source, X/Z stay (%s)" % hip)
	var sk := Skeleton3D.new()
	for b in ["Hips", "Spine", "Spine1", "LeftUpLeg", "LeftLeg", "RightUpLeg"]:
		sk.add_bone(b)
	sk.set_bone_parent(1, 0); sk.set_bone_parent(2, 1); sk.set_bone_parent(3, 0); sk.set_bone_parent(4, 3); sk.set_bone_parent(5, 0)
	var lb := PS1Anim.lower_body(sk)
	check(lb.size() == 4 and not "Spine" in lb and "LeftLeg" in lb, "lower_body = hips + legs (%s)" % ",".join(lb))
	sk.free()

func _test_mist() -> void:
	print("PS1Mist")
	var m := PS1Mist.new()
	m.layers = 3
	add_child(m)
	var quads := m.find_children("*", "MeshInstance3D", true, false)
	check(quads.size() == 3 and m.find_children("*", "PS1Particles", true, false).size() == 1, "3 layers + motes")
	m.layers = 2
	await get_tree().process_frame
	check(m.find_children("*", "MeshInstance3D", true, false).size() == 2, "rebuilds when changed")
	m.queue_free()

func _test_shockwave() -> void:
	print("PS1Shockwave")
	var floor_ := StaticBody3D.new()
	add_child(floor_)
	var near := Node3D.new(); near.add_to_group("t_wave"); add_child(near); near.position = Vector3(0.5, 0, 0)
	var far_ := Node3D.new(); far_.add_to_group("t_wave"); add_child(far_); far_.position = Vector3(4, 0, 0)
	var high := Node3D.new(); high.add_to_group("t_wave"); add_child(high); high.position = Vector3(0, 2.0, 3)
	var out_ := Node3D.new(); out_.add_to_group("t_wave"); add_child(out_); out_.position = Vector3(9, 0, 0)
	var w := PS1Shockwave.spawn(self, Vector3.ZERO, 6.0, 0.5, "t_wave")
	w.min_radius = 1.5
	var hits := []
	w.reached.connect(func(b): hits.append(b))
	for i in 45: await get_tree().physics_frame
	check(far_ in hits and not near in hits and not high in hits and not out_ in hits,
		"reaches 4 m, not inside min_radius, not above it, not beyond 6 m (%d hits)" % hits.size())
	for i in 90: await get_tree().physics_frame
	check(not is_instance_valid(w), "frees itself")
	for n in [floor_, near, far_, high, out_]: n.queue_free()

func _test_gothic() -> void:
	var g := PS1Gothic.new()
	g.wall(Vector3.ZERO, 10.0, 6.0, 1.0)
	g.tower(Vector3(5, 0, 0), 2.0, 10.0)
	g.portal(Vector3(0, 0, 3), 5.0, 8.0, 3.0, 2.0, 1.0)
	g.steps(Vector3(0, 0, 8), 3.0, 5)
	g.surface("glow")
	g.lancet(Vector3(0, 2, 0.51), 1.0, 2.0)
	g.rose(Vector3(0, 5, 0.51), 0.8)
	var m := g.mesh()
	check(m.get_surface_count() == 2, "gothic: one surface per name")
	check(g.surface_names == PackedStringArray(["glow", "stone"]), "gothic: surface names sorted")
	check(m.surface_get_name(0) == "glow", "gothic: surface named in the mesh")
	var aabb := m.get_aabb()
	check(aabb.size.x >= 10.0 and aabb.end.y >= 10.0, "gothic: mesh covers the shapes")
	# every face of a closed box points outward
	var b := PS1Gothic.new()
	b.box(Vector3.ZERO, Vector3(2, 2, 2), 0.0, true)
	var arr := b.mesh().surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var outward := true
	var wind_ok := true
	for i in range(0, v.size(), 3):
		var c := (v[i] + v[i + 1] + v[i + 2]) / 3.0
		if n[i].dot(c) <= 0.0: outward = false
		# Godot front faces are clockwise: (b - a) x (c - a) points AGAINST the normal
		if (v[i + 1] - v[i]).cross(v[i + 2] - v[i]).dot(n[i]) >= 0.0: wind_ok = false
	check(outward, "gothic: box normals point outward")
	check(wind_ok, "gothic: front faces wound clockwise")
	var body := g.build({stone = PS1.material(PS1Textures.ashlar()), glow = PS1.material(PS1Textures.flat(Color.ORANGE))})
	var shapes := body.find_children("*", "CollisionShape3D", false, false)
	check(body is StaticBody3D and shapes.size() >= 6, "gothic: build() adds collision shapes")
	var mi := body.get_child(0) as MeshInstance3D
	check(mi.get_surface_override_material(0) != mi.get_surface_override_material(1), "gothic: materials per surface")
	body.free()
	# vertex paint keeps per-surface materials of built pieces
	var painted := g.build({stone = PS1.material(PS1Textures.ashlar()), glow = PS1.material(PS1Textures.flat(Color.ORANGE))}, false) as MeshInstance3D
	add_child(painted)
	PS1VertexPaint.fill(painted, Color(0.5, 0.5, 0.5))
	check(painted.get_active_material(0) != null and painted.get_active_material(1) != null, "gothic: vertex paint keeps surface materials")
	painted.free()
	var tree := PS1Gothic.new()
	tree.dead_tree(Vector3.ZERO, 5.0, 3)
	check(tree.mesh().get_aabb().end.y > 3.0, "gothic: dead tree has height")
	for tex in [PS1Textures.ashlar(), PS1Textures.flagstones(), PS1Textures.slate_roof(), PS1Textures.banner()]:
		check(tex.get_width() == 64, "gothic: texture generated")

func _test_backdrop() -> void:
	var bd := PS1Backdrop.new()
	add_child(bd)
	var r := PS1Backdrop.ridge(2, 200.0, 40.0)
	check(r.get_aabb().size.x >= 190.0, "backdrop: ridge spans its length")
	var g := PS1Gothic.new()
	g.box(Vector3.ZERO, Vector3(4, 4, 4))
	g.surface("glow")
	g.lancet(Vector3(0, 0, 2.05), 1.0, 1.0)
	var mi := bd.add_mesh(g.mesh(), Transform3D(Basis(), Vector3(0, 0, -100)), 0.3)
	var m0 := mi.get_surface_override_material(0) as ShaderMaterial
	var m1 := mi.get_surface_override_material(1) as ShaderMaterial
	check(m0 != null and m0.get_shader_parameter("emission") == 1.0, "backdrop: glow surface emits")
	check(m1.get_shader_parameter("emission") == 0.0, "backdrop: stone surface is a silhouette")
	check(mi.extra_cull_margin > 1000.0, "backdrop: never culled by far plane")
	var sea := bd.add_mist_sea()
	check(sea.get_surface_override_material(0) != null, "backdrop: mist sea")
	bd.free()

func _test_creature() -> void:
	for c in [PS1Creature.rat(), PS1Creature.crawler(), PS1Creature.rat_king(5)]:
		add_child(c)
		var ap: AnimationPlayer = c.animation_player()
		check(ap != null, "creature: has an AnimationPlayer")
		for a in ["idle", "walk", "run", "attack", "slam", "spin", "hit", "die"]:
			check(ap.has_animation(a), "creature: animation %s" % a)
		check(c.heads().size() == c.cluster, "creature: one head per body")
		ap.play("attack")
		ap.seek(0.45, true)
		var head: Node3D = c.heads()[0]
		check(head.global_position.z < -0.2, "creature: head is in front (faces -Z)")
		c.free()
	var g := PS1Gothic.new()
	g.sewer(Vector3.ZERO, 20.0, 8.0, 4.5, 1.8, 1.0, PackedFloat32Array([10.0]))
	g.room(Vector3(0, 0, -26), Vector3(10, 6, 12), [Vector3(2, 0, 8), Vector3(0, 0, 4)])
	var body := g.build({stone = PS1.material(PS1Textures.ashlar())})
	check(body.find_children("*", "CollisionShape3D", false, false).size() > 10, "gothic: sewer/room colliders")
	body.free()

func _test_collapse() -> void:
	var c := PS1Collapse.new()
	c.duration = 0.4
	c.rocks = 6
	c.ceiling = 1.0
	var shakes := [0]
	c.rumble.connect(func(_s): shakes[0] += 1)
	add_child(c)
	await get_tree().create_timer(2.5).timeout
	check(shakes[0] > 0, "collapse: shakes")
	check(c.get_child_count() == 6, "collapse: rubble stays")
	c.free()

## An event freed mid-run (scene change) must release PS1Events.running.
func _test_event_freed() -> void:
	var ev := PS1Event.new()
	var pg := PS1EventPage.new()
	pg.trigger = PS1EventPage.Trigger.NONE
	var w := PS1CmdWait.new(); w.seconds = 5.0
	pg.commands = [w]
	ev.pages = [pg]
	add_child(ev)
	var before := PS1Events.running
	ev.run(null, pg)
	check(PS1Events.running == before + 1, "events: running while the page runs")
	ev.free()
	check(PS1Events.running == before, "events: freed event releases the running count")
	var g := PS1Gothic.new()
	g.tombstone(Vector3.ZERO)
	g.cross(Vector3(2, 0, 0))
	g.grave_sword(Vector3(4, 0, 0))
	var b := g.build({stone = PS1.material(PS1Textures.ashlar())})
	check(b.find_children("*", "CollisionShape3D", false, false).size() == 3, "gothic: graveyard props collide")
	b.free()
