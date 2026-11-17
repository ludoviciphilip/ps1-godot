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
