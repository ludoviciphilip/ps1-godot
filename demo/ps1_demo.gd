## PS1 Godot demo: a ruined courtyard with a bonfire, showing every toolkit feature.
## The camera orbits on its own. TAB = free camera (WASD + mouse, Q/E down/up).
## F1-F5: global effects (see PS1 autoload) | F6: baked vertex lighting | F7: 16-color texture palettes
## F8: screen palette taken from the current frame (off -> 24 -> 12 colors) | F9: composite video
## Command line (screenshots): -- --screenshot=PATH [--angle=RAD] [--baked] [--palette] [--dist=M] [--screen-palette=N] [--composite] [--crt]
extends Node3D

var cam: Camera3D
var fire_light: OmniLight3D
var level: Node3D
var ghost: Node3D
var t := 0.0
var free_cam := false
var yaw := 0.0
var pitch := -0.2
var _shot_path := ""
var _shot_frames := 0
var _shot_angle := 0.6
var _orbit := 6.0
var _baked := false
var _bake_ready := false
var _lit_state := {}     # MeshInstance3D -> [mesh, material_override] (realtime)
var _baked_state := {}   # MeshInstance3D -> [mesh, material_override] (baked)
var _palette_on := false
var _palette_swaps: Array = []   # [material, original_tex, palette_tex]
var _info: Label
var _screen_palette := 0
var _moon: DirectionalLight3D

func _ready() -> void:
	var want_baked := false
	var want_palette := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screenshot="):
			_shot_path = a.trim_prefix("--screenshot=")
		elif a.begins_with("--angle="):
			_shot_angle = float(a.trim_prefix("--angle="))
		elif a.begins_with("--dist="):
			_orbit = float(a.trim_prefix("--dist="))
		elif a == "--baked":
			want_baked = true
		elif a == "--palette":
			want_palette = true
		elif a == "--composite":
			PS1.set_composite(1.0)
		elif a == "--crt":
			PS1.set_crt(1.0)
		elif a.begins_with("--screen-palette="):
			_screen_palette = int(a.trim_prefix("--screen-palette="))
	level = Node3D.new()
	level.name = "Level"
	add_child(level)
	_build_environment()
	_build_level()
	_build_dynamic()
	_build_info()
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 60.0
	add_child(cam)
	_bake()
	if want_palette:
		_toggle_palette()
	if want_baked:
		await _wait_bake()
		_toggle_baked()
	if _screen_palette > 0:
		await _wait_bake()
		await PS1.palette_from_screen(_screen_palette)
		_update_info()

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.28, 0.35)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.03, 0.04, 0.05)
	env.fog_depth_begin = 4.0
	env.fog_depth_end = 32.0
	env.fog_depth_curve = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	_moon = DirectionalLight3D.new()
	_moon.light_color = Color(0.55, 0.62, 0.85)
	_moon.light_energy = 0.7
	_moon.rotation_degrees = Vector3(-35, 30, 0)
	add_child(_moon)

	# Sky dome: melts into the fog at the horizon, moon placed where the moonlight comes from.
	var sky := PS1Sky.new()
	sky.clouds = PS1Sky.cloud_texture()
	sky.moon_direction = _moon.global_basis.z
	add_child(sky)

func _mesh(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else level).add_child(mi)
	return mi

func _box(size: Vector3, step := 1.0) -> BoxMesh:
	# Subdivided so per-vertex lighting (and baked shadows) has vertices to work with.
	var b := BoxMesh.new()
	b.size = size
	b.subdivide_width = int(size.x / step)
	b.subdivide_height = int(size.y / step)
	b.subdivide_depth = int(size.z / step)
	return b

func _build_level() -> void:
	var stone := PS1Textures.stone_bricks()
	var ground_tex := PS1Textures.ground()
	var rock_tex := PS1Textures.mossy_rock()
	var m_ground := PS1.material(ground_tex, Color.WHITE, Vector2(24, 24))
	var m_stone := PS1.material(stone, Color.WHITE, Vector2(1, 2))
	var m_wall := PS1.material(stone, Color.WHITE, Vector2(4, 2))
	var m_bark := PS1.material(PS1Textures.bark(), Color.WHITE, Vector2(2, 2))
	var m_metal := PS1.material(PS1Textures.metal(), Color.WHITE, Vector2(1, 1))
	var m_fire := PS1.material(PS1Textures.flat(Color(1, 0.55, 0.15)), Color.WHITE, Vector2.ONE, Color(1.0, 0.45, 0.1), 2.5)
	var m_ash := PS1.material(PS1Textures.flat(Color(0.12, 0.11, 0.1)), Color.WHITE)
	var m_rock := PS1.material(rock_tex, Color.WHITE, Vector2(2, 1))
	var m_fence := PS1.make(PS1Textures.iron_fence(), {mode = "cutout", uv_scale = Vector2(2, 1)})
	var m_grass := PS1.make(PS1Textures.grass(), {mode = "cutout", alpha_cut = 0.5})
	# Palette swaps for F7 (computed once, like converting textures to 4-bit CLUTs).
	for pair in [[m_ground, ground_tex], [m_stone, stone], [m_wall, stone], [m_rock, rock_tex]]:
		_palette_swaps.append([pair[0], pair[1], null])

	# Ground: subdivided because lighting is per-vertex (a period trick); affine warping still shows.
	var ground := PlaneMesh.new()
	ground.size = Vector2(60, 60)
	ground.subdivide_width = 60
	ground.subdivide_depth = 60
	_mesh(ground, m_ground, Vector3.ZERO)

	# Ring of pillars, some broken.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 10:
		var ang := TAU * i / 10.0
		var h := 5.0 if i % 3 != 0 else rng.randf_range(1.2, 2.6)
		_mesh(_box(Vector3(1.0, h, 1.0)), m_stone, Vector3(cos(ang) * 9.0, h / 2.0, sin(ang) * 9.0), Vector3(0, rng.randf_range(-10, 10), rng.randf_range(-3, 3)))
		if h > 4.0:
			_mesh(_box(Vector3(1.4, 0.4, 1.4)), m_stone, Vector3(cos(ang) * 9.0, h + 0.2, sin(ang) * 9.0))

	# Back wall with an arch.
	for x in [-10.0, -4.0, 4.0, 10.0]:
		var wsize := Vector3(6.0 if abs(x) > 5 else 2.0, 7.0, 1.2)
		_mesh(_box(wsize), m_wall, Vector3(x * 1.0 + (0.0 if abs(x) > 5 else sign(x) * -1.0), 3.5, -16))
	_mesh(_box(Vector3(6.0, 1.6, 1.4)), m_wall, Vector3(0, 6.2, -16))

	# Bonfire with a sword stuck in it.
	var logs := CylinderMesh.new()
	logs.top_radius = 0.08
	logs.bottom_radius = 0.08
	logs.height = 1.2
	logs.radial_segments = 5
	for i in 4:
		_mesh(logs, m_bark, Vector3(0, 0.15, 0), Vector3(70, i * 45.0, 0)).set_meta("ps1_no_cast", true)
	var ash := CylinderMesh.new()
	ash.top_radius = 0.6
	ash.bottom_radius = 0.8
	ash.height = 0.15
	ash.radial_segments = 8
	_mesh(ash, m_ash, Vector3(0, 0.07, 0)).set_meta("ps1_no_cast", true)
	var flame := CylinderMesh.new()
	flame.top_radius = 0.0
	flame.bottom_radius = 0.35
	flame.height = 0.9
	flame.radial_segments = 5
	_mesh(flame, m_fire, Vector3(0, 0.45, 0), Vector3.ZERO, Vector3(0.6, 0.6, 0.6)).set_meta("ps1_no_bake", true)
	# Animated flame: unlit PS1Sprite playing a 4-frame sheet, always facing the camera.
	var fire_sprite := PS1Sprite.new()
	fire_sprite.texture = PS1Textures.flame_sheet()
	fire_sprite.hframes = 4
	fire_sprite.fps = 10.0
	fire_sprite.lit = false
	fire_sprite.size = Vector2(0.9, 1.1)
	fire_sprite.position = Vector3(0, 0.1, 0)
	add_child(fire_sprite)
	var blade := BoxMesh.new()
	blade.size = Vector3(0.08, 1.4, 0.02)
	# The sword sits right on the fire light: it must not cast baked shadows.
	_mesh(blade, m_metal, Vector3(0, 0.9, 0), Vector3(0, 0, 8)).set_meta("ps1_no_cast", true)
	var guard := BoxMesh.new()
	guard.size = Vector3(0.4, 0.06, 0.06)
	_mesh(guard, m_metal, Vector3(-0.08, 1.6, 0), Vector3(0, 0, 8)).set_meta("ps1_no_cast", true)

	fire_light = OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.55, 0.2)
	fire_light.light_energy = 3.0
	fire_light.omni_range = 11.0
	fire_light.omni_attenuation = 0.7
	fire_light.position = Vector3(0, 1.2, 0)
	add_child(fire_light)

	# Dead trees, with a PS1-style draw distance (dithered fade at 20 m).
	for i in 7:
		var ang := rng.randf_range(0, TAU)
		var r := rng.randf_range(12, 22)
		var tree := Node3D.new()
		level.add_child(tree)
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.1
		trunk.bottom_radius = 0.3
		trunk.height = rng.randf_range(4, 7)
		trunk.radial_segments = 5
		var pos := Vector3(cos(ang) * r, trunk.height / 2.0, sin(ang) * r)
		_mesh(trunk, m_bark, pos, Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8)), Vector3.ONE, tree)
		var branch := CylinderMesh.new()
		branch.top_radius = 0.03
		branch.bottom_radius = 0.1
		branch.height = 2.0
		branch.radial_segments = 4
		_mesh(branch, m_bark, pos + Vector3(0.5, trunk.height * 0.3, 0), Vector3(0, rng.randf_range(0, 360), -50), Vector3.ONE, tree)
		PS1.draw_distance(tree, 20.0, 4.0)

	# Distant pine forest: lit PS1Sprites (turn around Y only), the cheap PS1 way.
	var pine_tex := PS1Textures.pine()
	for i in 36:
		var ang := TAU * i / 36.0 + rng.randf_range(-0.05, 0.05)
		var r := rng.randf_range(24.0, 29.0)
		var pine := PS1Sprite.new()
		pine.texture = pine_tex
		var hgt := rng.randf_range(5.0, 8.0)
		pine.size = Vector2(hgt * 0.5, hgt)
		pine.position = Vector3(cos(ang) * r, 0, sin(ang) * r)
		add_child(pine)

	# Gravestones.
	for i in 12:
		var g := BoxMesh.new()
		g.size = Vector3(0.6, rng.randf_range(0.7, 1.1), 0.15)
		var gp := Vector3(rng.randf_range(-7, 7), g.size.y / 2.0 - 0.1, rng.randf_range(3, 8))
		_mesh(g, m_stone, gp, Vector3(rng.randf_range(-12, 12), rng.randf_range(-20, 20), rng.randf_range(-10, 10)))

	# Iron fence (alpha-tested "cutout" material).
	for i in 6:
		var q := QuadMesh.new()
		q.size = Vector2(2.0, 1.3)
		_mesh(q, m_fence, Vector3(-5.0 + i * 2.0, 0.65, -6.5))

	# Grass tufts: two crossed cutout quads each.
	for i in 40:
		var ang := rng.randf_range(0, TAU)
		var r := rng.randf_range(2.0, 8.0)
		var p := Vector3(cos(ang) * r, 0.3, sin(ang) * r)
		var q := QuadMesh.new()
		q.size = Vector2(0.7, 0.6)
		var yr := rng.randf_range(0, 180)
		_mesh(q, m_grass, p, Vector3(0, yr, 0))
		_mesh(q, m_grass, p, Vector3(0, yr + 90, 0))

	# Pond: PS1Water (vertex waves, scrolling affine layers, dithered transparency) in a stone ring.
	var pond := PS1Water.new()
	pond.size = Vector2(4.0, 3.0)
	pond.position = Vector3(4.6, 0.12, -2.6)
	add_child(pond)
	for i in 14:
		var ang := TAU * i / 14.0
		var st := _box(Vector3(0.7, 0.35, 0.5))
		_mesh(st, m_stone, pond.position + Vector3(cos(ang) * 2.3, 0.05, sin(ang) * 1.8), Vector3(0, -rad_to_deg(ang), rng.randf_range(-8, 8)))

	# Mossy boulder: smooth, many-colored texture to show F7 (16-color palette).
	var boulder := SphereMesh.new()
	boulder.radius = 0.9
	boulder.height = 1.4
	boulder.radial_segments = 9
	boulder.rings = 5
	_mesh(boulder, m_rock, Vector3(-3.2, 0.45, 2.4), Vector3(0, 20, 8), Vector3(1.3, 1.0, 1.0))

	# Obelisks with two LOD levels (detailed -> box) and a draw distance.
	for i in 12:
		var ang := TAU * i / 12.0 + 0.13
		var lod := PS1LOD.new()
		lod.distances = PackedFloat32Array([15.0])
		lod.draw_distance = 27.0
		lod.fade = 3.0
		lod.position = Vector3(cos(ang) * 17.0, 0, sin(ang) * 17.0)
		level.add_child(lod)
		var hi := Node3D.new()
		lod.add_child(hi)
		var col := CylinderMesh.new()
		col.top_radius = 0.35
		col.bottom_radius = 0.55
		col.height = 4.0
		col.radial_segments = 10
		col.rings = 4
		_mesh(col, m_stone, Vector3(0, 2.0, 0), Vector3.ZERO, Vector3.ONE, hi)
		var tip := CylinderMesh.new()
		tip.top_radius = 0.0
		tip.bottom_radius = 0.4
		tip.height = 0.8
		tip.radial_segments = 10
		_mesh(tip, m_metal, Vector3(0, 4.4, 0), Vector3.ZERO, Vector3.ONE, hi)
		var lo := Node3D.new()
		lod.add_child(lo)
		_mesh(BoxMesh.new(), m_stone, Vector3(0, 2.4, 0), Vector3.ZERO, Vector3(0.9, 4.8, 0.9), lo)

func _build_dynamic() -> void:
	# Dynamic objects stay on realtime (lit) materials even when the level is baked.
	var m_metal := PS1.material(PS1Textures.metal(), Color.WHITE, Vector2(1, 1))
	var body := CapsuleMesh.new()
	body.radius = 0.35
	body.height = 1.5
	body.radial_segments = 6
	body.rings = 2
	_mesh(body, m_metal, Vector3(1.8, 0.75, 1.0), Vector3.ZERO, Vector3.ONE, self)
	var helm := BoxMesh.new()
	helm.size = Vector3(0.4, 0.45, 0.45)
	_mesh(helm, m_metal, Vector3(1.8, 1.7, 1.0), Vector3(0, 30, 0), Vector3.ONE, self)

	# Ghost: screen-door ("dither_alpha") transparency, no alpha blending.
	ghost = Node3D.new()
	ghost.position = Vector3(-2.4, 0.0, -2.0)
	add_child(ghost)
	var m_ghost := PS1.make(PS1Textures.flat(Color(0.7, 0.85, 1.0)), {mode = "dither_alpha",
		color = Color(1, 1, 1, 0.45), emission = Color(0.4, 0.6, 1.0), emission_energy = 0.8})
	var gbody := CapsuleMesh.new()
	gbody.radius = 0.3
	gbody.height = 1.4
	gbody.radial_segments = 6
	gbody.rings = 2
	_mesh(gbody, m_ghost, Vector3(0, 0.9, 0), Vector3.ZERO, Vector3.ONE, ghost)
	var ghead := SphereMesh.new()
	ghead.radius = 0.22
	ghead.height = 0.44
	ghead.radial_segments = 6
	ghead.rings = 3
	_mesh(ghead, m_ghost, Vector3(0, 1.8, 0), Vector3.ZERO, Vector3.ONE, ghost)

func _build_info() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_info = Label.new()
	_info.position = Vector2(4, 2)
	_info.add_theme_font_size_override("font_size", 8)
	_info.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	_info.add_theme_color_override("font_shadow_color", Color.BLACK)
	layer.add_child(_info)
	_update_info()

func _update_info() -> void:
	_info.text = "F1 jitter  F2 affine  F3 dither  F4 res  F5 color\nF6 baked light: %s   F7 tex palette: %s\nF8 screen palette: %s   F9 composite   TAB cam" % [
		("ON" if _baked else "off") if _bake_ready else "baking...", "16 colors" if _palette_on else "off",
		("%d colors" % _screen_palette) if _screen_palette > 0 else "off"]

# ---------------- F6: baked vertex lighting ----------------

func _bake() -> void:
	for mi in level.find_children("*", "MeshInstance3D", true, false):
		_lit_state[mi] = [mi.mesh, mi.material_override]
	# Bake against the static lights only (fire at its average brightness).
	# Cached: the first run bakes and saves res://ps1_bake_cache/..., later runs load it instantly.
	var t0 := Time.get_ticks_msec()
	var cached := await PS1Bake.bake_scene_cached(level, Color(0.25, 0.28, 0.35) * 0.9)
	print("bake: %s in %d ms" % ["loaded from cache" if cached else "baked + saved", Time.get_ticks_msec() - t0])
	for mi in _lit_state:
		_baked_state[mi] = [mi.mesh, mi.material_override]
		mi.mesh = _lit_state[mi][0]
		mi.material_override = _lit_state[mi][1]
	_bake_ready = true
	_update_info()
	if OS.get_cmdline_user_args().has("--debug-bake"):
		for mi in _baked_state:
			if _lit_state[mi][0] is PlaneMesh:
				var arr: Array = _baked_state[mi][0].surface_get_arrays(0)
				var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var cs: PackedColorArray = arr[Mesh.ARRAY_COLOR]
				for i in vs.size():
					if absf(vs[i].z) < 0.5 and vs[i].x >= 0.0 and vs[i].x <= 6.0:
						print("ground x=%.1f color=%s" % [vs[i].x, cs[i]])
		print("lights: ", get_tree().root.find_children("*", "Light3D", true, false).map(func(l): return "%s %s" % [l.name, l.global_position]))

func _wait_bake() -> void:
	while not _bake_ready:
		await get_tree().process_frame

func _toggle_baked() -> void:
	if not _bake_ready:
		return
	_baked = not _baked
	var state := _baked_state if _baked else _lit_state
	for mi in state:
		mi.mesh = state[mi][0]
		mi.material_override = state[mi][1]
	# The palette swap edits materials in place: re-apply it to the other state's materials.
	if _palette_on:
		_palette_on = false
		_toggle_palette()
	_update_info()

# ---------------- F7: texture palettes ----------------

func _toggle_palette() -> void:
	_palette_on = not _palette_on
	for s in _palette_swaps:
		if s[2] == null:
			s[2] = PS1Palette.quantize(s[1], 16)
		s[0].set_shader_parameter("albedo_tex", s[2] if _palette_on else s[1])
	# Baked materials are duplicates: keep them in sync.
	for mi in _baked_state:
		var m: ShaderMaterial = _baked_state[mi][1]
		for s in _palette_swaps:
			if m and m.get_shader_parameter("albedo_tex") in [s[1], s[2]]:
				m.set_shader_parameter("albedo_tex", s[2] if _palette_on else s[1])
	_update_info()

func _process(delta: float) -> void:
	t += delta
	fire_light.light_energy = 3.0 + 0.5 * sin(t * 13.0) + 0.2 * sin(t * 31.0)
	ghost.position.y = 0.15 * sin(t * 1.7)
	ghost.rotation.y = 0.4 * sin(t * 0.5)
	if not free_cam:
		var a := _shot_angle if _shot_path != "" else t * 0.15 + 0.6
		cam.position = Vector3(sin(a) * _orbit, 1.7, cos(a) * _orbit)
		cam.look_at(Vector3(0, 1.0, 0))
	else:
		var dir := Vector3(
			float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
			float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q)),
			float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
		cam.rotation = Vector3(pitch, yaw, 0)
		cam.position += cam.basis * dir * delta * 5.0
	if _shot_path != "" and _bake_ready:
		_shot_frames += 1
		if _shot_frames == 45:
			var img := get_viewport().get_texture().get_image()
			img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
			img.save_png(_shot_path)
			print("screenshot saved: ", _shot_path)
			get_tree().quit()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_TAB:
				free_cam = not free_cam
				if free_cam:
					yaw = cam.rotation.y
					pitch = cam.rotation.x
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if free_cam else Input.MOUSE_MODE_VISIBLE
			KEY_F6:
				_toggle_baked()
			KEY_F7:
				_toggle_palette()
			KEY_F8:
				_screen_palette = {0: 24, 24: 12}.get(_screen_palette, 0)
				if _screen_palette > 0:
					PS1.palette_from_screen(_screen_palette)
				else:
					PS1.clear_screen_palette()
				_update_info()
			KEY_ESCAPE:
				get_tree().quit()
	elif e is InputEventMouseMotion and free_cam:
		yaw -= e.screen_relative.x * 0.003
		pitch = clamp(pitch - e.screen_relative.y * 0.003, -1.4, 1.4)
