## PS1 look demo: a ruined courtyard with a bonfire.
## The camera orbits on its own. TAB = free camera (WASD + mouse, Q/E down/up).
extends Node3D

var cam: Camera3D
var fire_light: OmniLight3D
var t := 0.0
var free_cam := false
var yaw := 0.0
var pitch := -0.2
var _shot_path := ""
var _shot_frames := 0
var _shot_angle := 0.6

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screenshot="):
			_shot_path = a.trim_prefix("--screenshot=")
		elif a.begins_with("--angle="):
			_shot_angle = float(a.trim_prefix("--angle="))
	_build_environment()
	_build_level()
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 60.0
	add_child(cam)

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

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.62, 0.85)
	moon.light_energy = 0.7
	moon.rotation_degrees = Vector3(-35, 30, 0)
	add_child(moon)

func _mesh(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _build_level() -> void:
	var stone := PS1Textures.stone_bricks()
	var m_ground := PS1.material(PS1Textures.ground(), Color.WHITE, Vector2(24, 24))
	var m_stone := PS1.material(stone, Color.WHITE, Vector2(1, 2))
	var m_wall := PS1.material(stone, Color.WHITE, Vector2(4, 2))
	var m_bark := PS1.material(PS1Textures.bark(), Color.WHITE, Vector2(2, 2))
	var m_metal := PS1.material(PS1Textures.metal(), Color.WHITE, Vector2(1, 1))
	var m_fire := PS1.material(PS1Textures.flat(Color(1, 0.55, 0.15)), Color.WHITE, Vector2.ONE, Color(1.0, 0.45, 0.1), 2.5)
	var m_ash := PS1.material(PS1Textures.flat(Color(0.12, 0.11, 0.1)), Color.WHITE)

	# Ground: subdivided because lighting is per-vertex (a period trick); affine warping still shows.
	var ground := PlaneMesh.new()
	ground.size = Vector2(60, 60)
	ground.subdivide_width = 40
	ground.subdivide_depth = 40
	_mesh(ground, m_ground, Vector3.ZERO)

	# Ring of pillars, some broken.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 10:
		var ang := TAU * i / 10.0
		var h := 5.0 if i % 3 != 0 else rng.randf_range(1.2, 2.6)
		var p := BoxMesh.new()
		p.size = Vector3(1.0, h, 1.0)
		_mesh(p, m_stone, Vector3(cos(ang) * 9.0, h / 2.0, sin(ang) * 9.0), Vector3(0, rng.randf_range(-10, 10), rng.randf_range(-3, 3)))
		if h > 4.0:
			var cap := BoxMesh.new()
			cap.size = Vector3(1.4, 0.4, 1.4)
			_mesh(cap, m_stone, Vector3(cos(ang) * 9.0, h + 0.2, sin(ang) * 9.0))

	# Back wall with an arch.
	for x in [-10.0, -4.0, 4.0, 10.0]:
		var w := BoxMesh.new()
		w.size = Vector3(6.0 if abs(x) > 5 else 2.0, 7.0, 1.2)
		_mesh(w, m_wall, Vector3(x * 1.0 + (0.0 if abs(x) > 5 else sign(x) * -1.0), 3.5, -16))
	var lintel := BoxMesh.new()
	lintel.size = Vector3(6.0, 1.6, 1.4)
	_mesh(lintel, m_wall, Vector3(0, 6.2, -16))

	# Bonfire with a sword stuck in it.
	var logs := CylinderMesh.new()
	logs.top_radius = 0.08
	logs.bottom_radius = 0.08
	logs.height = 1.2
	logs.radial_segments = 5
	for i in 4:
		_mesh(logs, m_bark, Vector3(0, 0.15, 0), Vector3(70, i * 45.0, 0))
	var ash := CylinderMesh.new()
	ash.top_radius = 0.6
	ash.bottom_radius = 0.8
	ash.height = 0.15
	ash.radial_segments = 8
	_mesh(ash, m_ash, Vector3(0, 0.07, 0))
	var flame := CylinderMesh.new()
	flame.top_radius = 0.0
	flame.bottom_radius = 0.35
	flame.height = 0.9
	flame.radial_segments = 5
	_mesh(flame, m_fire, Vector3(0, 0.55, 0))
	var blade := BoxMesh.new()
	blade.size = Vector3(0.08, 1.4, 0.02)
	_mesh(blade, m_metal, Vector3(0, 0.9, 0), Vector3(0, 0, 8))
	var guard := BoxMesh.new()
	guard.size = Vector3(0.4, 0.06, 0.06)
	_mesh(guard, m_metal, Vector3(-0.08, 1.6, 0), Vector3(0, 0, 8))

	fire_light = OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.55, 0.2)
	fire_light.light_energy = 2.0
	fire_light.omni_range = 11.0
	fire_light.omni_attenuation = 0.7
	fire_light.position = Vector3(0, 1.2, 0)
	add_child(fire_light)

	# Placeholder knight by the fire.
	var body := CapsuleMesh.new()
	body.radius = 0.35
	body.height = 1.5
	body.radial_segments = 6
	body.rings = 2
	_mesh(body, m_metal, Vector3(1.8, 0.75, 1.0))
	var helm := BoxMesh.new()
	helm.size = Vector3(0.4, 0.45, 0.45)
	_mesh(helm, m_metal, Vector3(1.8, 1.7, 1.0), Vector3(0, 30, 0))

	# Dead trees and gravestones.
	for i in 7:
		var ang := rng.randf_range(0, TAU)
		var r := rng.randf_range(12, 22)
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.1
		trunk.bottom_radius = 0.3
		trunk.height = rng.randf_range(4, 7)
		trunk.radial_segments = 5
		var pos := Vector3(cos(ang) * r, trunk.height / 2.0, sin(ang) * r)
		_mesh(trunk, m_bark, pos, Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8)))
		var branch := CylinderMesh.new()
		branch.top_radius = 0.03
		branch.bottom_radius = 0.1
		branch.height = 2.0
		branch.radial_segments = 4
		_mesh(branch, m_bark, pos + Vector3(0.5, trunk.height * 0.3, 0), Vector3(0, rng.randf_range(0, 360), -50))
	for i in 12:
		var g := BoxMesh.new()
		g.size = Vector3(0.6, rng.randf_range(0.7, 1.1), 0.15)
		var gp := Vector3(rng.randf_range(-7, 7), g.size.y / 2.0 - 0.1, rng.randf_range(3, 8))
		_mesh(g, m_stone, gp, Vector3(rng.randf_range(-12, 12), rng.randf_range(-20, 20), rng.randf_range(-10, 10)), Vector3.ONE)

func _process(delta: float) -> void:
	t += delta
	fire_light.light_energy = 3.0 + 0.5 * sin(t * 13.0) + 0.2 * sin(t * 31.0)
	if not free_cam:
		var a := _shot_angle if _shot_path != "" else t * 0.15 + 0.6
		cam.position = Vector3(sin(a) * 6.0, 1.7, cos(a) * 6.0)
		cam.look_at(Vector3(0, 1.0, 0))
	else:
		var dir := Vector3(
			Input.get_axis(&"ui_left", &"ui_right") + float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
			float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q)),
			float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
		cam.rotation = Vector3(pitch, yaw, 0)
		cam.position += cam.basis * dir * delta * 5.0
	if _shot_path != "":
		_shot_frames += 1
		if _shot_frames == 60:
			var img := get_viewport().get_texture().get_image()
			img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
			img.save_png(_shot_path)
			print("screenshot saved: ", _shot_path)
			get_tree().quit()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_TAB:
		free_cam = not free_cam
		if free_cam:
			yaw = cam.rotation.y
			pitch = cam.rotation.x
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if free_cam else Input.MOUSE_MODE_VISIBLE
	elif e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		get_tree().quit()
	elif e is InputEventMouseMotion and free_cam:
		yaw -= e.relative.x * 0.004
		pitch = clamp(pitch - e.relative.y * 0.004, -1.4, 1.4)
