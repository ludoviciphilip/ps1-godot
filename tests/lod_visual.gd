## Visual check for PS1LOD: a row of obelisks from 6 to 30 m. Detailed (light) up to 15 m,
## dithered cross-fade to boxes (blue), dithered fade-out at 27 m (distances from the origin; the
## camera sits close to it).
##   godot --path . res://tests/lod_visual.tscn -- --screenshot=PATH
extends Node3D

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.1, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.45, 0.45)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -40, 0)
	add_child(sun)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var hi_mat := PS1.make(PS1Textures.flat(Color(0.85, 0.8, 0.6)), {})
	var lo_mat := PS1.make(PS1Textures.flat(Color(0.3, 0.35, 0.6)), {})
	for i in 17:
		var z := -6.0 - i * 1.5
		var x := -7.0 + i * 0.9
		var lod := PS1LOD.new()
		lod.distances = PackedFloat32Array([15.0])
		lod.draw_distance = 27.0
		lod.fade = 3.0
		lod.position = Vector3(x, 0, z)
		# Measure LOD distance from the origin (the camera is nearby); good enough for the check.
		add_child(lod)
		var hi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.3
		cyl.bottom_radius = 0.45
		cyl.height = 3.0
		cyl.radial_segments = 12
		hi.mesh = cyl
		hi.material_override = hi_mat
		hi.position.y = 1.5
		lod.add_child(hi)
		var lo := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.8, 3.0, 0.8)
		lo.mesh = bm
		lo.material_override = lo_mat
		lo.position.y = 1.5
		lod.add_child(lo)
	var cam := Camera3D.new()
	cam.position = Vector3(-9.0, 7.0, 2.0)
	cam.fov = 50
	add_child(cam)
	cam.look_at(Vector3(0, 0.5, -17))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screenshot="):
			for _i in 30:
				await get_tree().process_frame
			var img := get_viewport().get_texture().get_image()
			img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
			img.save_png(a.trim_prefix("--screenshot="))
			get_tree().quit()
