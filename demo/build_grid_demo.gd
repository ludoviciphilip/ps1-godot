## Rebuilds demo/grid_level_demo.tscn with PS1GridLevel.paint_ascii + automatic walls:
##   godot --headless --path . -s res://demo/build_grid_demo.gd
extends SceneTree

const K := "res://addons/ps1_godot/starter_pieces/"

func _init() -> void:
	var root := Node3D.new()
	root.name = "GridLevelDemo"
	root.set_script(load("res://demo/grid_level_demo.gd"))
	var env := WorldEnvironment.new()
	env.name = "Env"
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.01, 0.01, 0.015)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.1, 0.1, 0.12)
	env.environment.fog_enabled = true
	env.environment.fog_mode = Environment.FOG_MODE_DEPTH
	env.environment.fog_light_color = Color(0.01, 0.01, 0.015)
	env.environment.fog_depth_begin = 4.0
	env.environment.fog_depth_end = 22.0
	root.add_child(env)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.position = Vector3(8, 2.6, 13)
	root.add_child(cam)
	var lvl := PS1GridLevel.new()
	lvl.name = "Level"
	lvl.ambient = Color(0.08, 0.08, 0.1)
	root.add_child(lvl)
	var P := func(n): return load(K + n + ".tscn")
	# '.' floor, 'P' floor + pillar, 'C' floor + coffin, 'B' floor + brazier, 'S' stairs (up north), 'U' raised floor
	var rows := PackedStringArray([
		"  UUU  ",
		"  USU  ",
		"...P...",
		".C...C.",
		"...B...",
		".C...C.",
		"...P...",
	])
	var floor_s = P.call("1_structure/floor")
	lvl.paint_ascii(rows, {".": [floor_s], "P": [floor_s, P.call("1_structure/pillar")],
		"C": [floor_s, P.call("2_props/coffin")], "B": [floor_s, P.call("3_lights/brazier")],
		"S": [P.call("1_structure/stairs")]}, 0, Vector2i(1, 0), root)
	# raised platform (layer 1) north of the stairs
	lvl.paint_ascii(rows.slice(0, 1) + PackedStringArray(["  U U  "]), {"U": [floor_s]}, 1, Vector2i(1, 0), root)
	# automatic walls on every floor -> empty edge, a torch every few walls
	var dirs := [Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0)]
	var wall = P.call("1_structure/wall")
	var torch = P.call("3_lights/wall_torch")
	var k := 0
	for p in lvl.pieces():
		if p.get_meta("ps1_slot") != "floor":
			continue
		var c: Vector3i = p.get_meta("ps1_cell")
		for r in 4:
			var n: Vector3i = c + dirs[r]
			var open := not lvl.pieces_at(n, "floor").is_empty() or not lvl.pieces_at(n + Vector3i(0, 1, 0), "floor").is_empty() \
				or not lvl.pieces_at(n - Vector3i(0, 1, 0), "floor").is_empty()
			if not open:
				lvl.place(wall, c, r, root)
				k += 1
				if k % 3 == 0:
					lvl.place(torch, c, r, root)
	for n in [env, cam, lvl]:
		n.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	print("DEMO ", ResourceSaver.save(ps, "res://demo/grid_level_demo.tscn"), " pieces=", lvl.pieces().size())
	root.free()
	quit()
