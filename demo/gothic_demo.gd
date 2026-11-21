## PS1Gothic + PS1Backdrop showcase: a ruined castle courtyard at night with a panorama.
## Run: godot --path . res://demo/gothic_demo.tscn [-- --shot=PATH --angle=DEG]
extends Node3D

func _ready() -> void:
	var haze := Color(0.09, 0.1, 0.14)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = haze
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.32, 0.4)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = haze
	env.fog_depth_begin = 10.0
	env.fog_depth_end = 45.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.66, 0.9)
	moon.rotation_degrees = Vector3(-35, 200, 0)
	add_child(moon)
	var sky := PS1Sky.new()
	sky.clouds = PS1Sky.cloud_texture()
	sky.moon_direction = moon.global_basis.z
	add_child(sky)

	var stone := PS1.material(PS1Textures.ashlar(), Color(0.85, 0.88, 0.95))
	var roof := PS1.material(PS1Textures.slate_roof())
	var floor_m := PS1.material(PS1Textures.flagstones(), Color.WHITE, Vector2(15, 15))
	var glow := PS1.make(PS1Textures.flat(Color(1.0, 0.6, 0.25)), {mode = "unlit"})
	var dark := PS1.make(PS1Textures.flat(Color.BLACK), {mode = "unlit"})

	var level := PS1BakedLevel.new()
	level.ambient = Color(0.25, 0.27, 0.35)
	add_child(level)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); pm.subdivide_width = 20; pm.subdivide_depth = 20
	fl.mesh = pm; fl.material_override = floor_m
	level.add_child(fl)

	var g := PS1Gothic.new()
	g.wall(Vector3(0, 0, -15), 30, 8, 1.2)                  # north curtain wall
	g.wall(Vector3(-15, 0, 0), 30, 8, 1.2, true, PI / 2)     # west
	for sx in [-1.0, 1.0]:
		g.tower(Vector3(15 * sx, 0, -15), 2.6, 13)
	for z in [-8.0, 0.0, 8.0]:
		g.buttress(Vector3(-14.4 + 1.6, 0, z), 1.0, 1.6, 6.0, PI / 2)
	g.arch(Vector3(0, 0, -14.3), 3.0, 3.2, 0.45, 0.5)
	g.column(Vector3(-5, 0, -4), 0.45, 6.0)
	g.column(Vector3(5, 0, -4), 0.45, 6.0, 0.45)
	g.pinnacle(Vector3(0, 0, -6), 1.6, 5.0)
	for i in 6:
		g.tombstone(Vector3(-8 + i * 1.3, 0, 6 + (i % 2) * 0.8), 0.6, 0.9, 0.1 * i, 0.08 * (i % 3 - 1))
	g.cross(Vector3(4, 0, 7), 1.4, 0.3, 0.1)
	g.grave_sword(Vector3(5.5, 0, 6), 0.4, 0.15)
	g.surface("roof")
	for sx in [-1.0, 1.0]:
		g.spire(Vector3(15 * sx, 13.6, -15), 3.2, 9)
	g.surface("dark")
	g.lancet(Vector3(0, 0, -14.32), 3.0, 3.2)
	g.surface("glow")
	for x in [-8.0, 8.0]:
		g.lancet(Vector3(x, 3.5, -14.38), 0.7, 1.6)
	g.rose(Vector3(0, 6.2, -14.38), 0.9)
	level.add_child(g.build({stone = stone, roof = roof, dark = dark, glow = glow}))

	var tree := PS1Gothic.new()
	tree.dead_tree(Vector3(8, 0, 4), 6.0, 4)
	level.add_child(tree.build({bark = PS1.material(PS1Textures.bark())}))
	level.lights = [moon]

	# panorama: mountains + a cathedral on a crag + the keep
	var bd := PS1Backdrop.new()
	bd.haze_color = haze
	bd.mist_height = -4.0
	add_child(bd)
	bd.add_mesh(PS1Backdrop.ridge(3, 900.0, 120.0, 30), Transform3D(Basis(), Vector3(0, -20, -500)), 0.8)
	bd.add_mesh(PS1Backdrop.ridge(8, 700.0, 70.0, 26), Transform3D(Basis(), Vector3(60, -20, -330)), 0.6)
	var keep := PS1Gothic.new()
	keep.box(Vector3(0, 20, 0), Vector3(40, 40, 20))
	keep.tower(Vector3(-24, 0, 0), 6, 55)
	keep.tower(Vector3(24, 0, 0), 6, 48)
	keep.prism(Vector3(0, 40, 0), 7, 30, 8)
	keep.spire(Vector3(0, 70, 0), 8, 35)
	keep.spire(Vector3(-24, 55, 0), 7, 22)
	keep.spire(Vector3(24, 48, 0), 7, 20)
	keep.surface("glow")
	for i in 5:
		keep.lancet(Vector3(-14 + i * 7, 24, 10.1), 2.2, 5.0)
	keep.rose(Vector3(0, 50, 7.1), 3.5)
	bd.add_mesh(keep.mesh(), Transform3D(Basis(), Vector3(0, -6, -150)), 0.3)

	var cam := Camera3D.new()
	cam.fov = 70
	cam.far = 60
	add_child(cam)
	var ang := 0.0
	var shot := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): shot = a.trim_prefix("--shot=")
		if a.begins_with("--angle="): ang = float(a.trim_prefix("--angle="))
		if a.begins_with("--height="): cam.position.y = float(a.trim_prefix("--height="))
	cam.position = Vector3(0, maxf(cam.position.y, 1.7), 10)
	cam.rotation_degrees = Vector3(8, ang, 0)
	if shot != "":
		await level.baked if level.has_signal("baked") else get_tree().create_timer(3.0).timeout
		await get_tree().create_timer(1.0).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png(shot)
		get_tree().quit()
