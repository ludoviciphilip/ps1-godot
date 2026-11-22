## PS1Creature / PS1Biped showcase: giant rat, crawler, rat king, gargoyle, hooded archer, giant
## leech, drowned and hanged one.
## Run: godot --path . res://demo/creature_demo.tscn [-- --anim=walk --t=0.2 --shot=PATH]
extends Node3D

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.08, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.45, 0.5)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(20, 20)
	fl.mesh = pm
	fl.material_override = PS1.material(PS1Textures.flagstones(), Color.WHITE, Vector2(8, 8))
	add_child(fl)
	var anim := "idle"
	var t := 0.3
	var shot := ""
	var yaw := 35.0
	var only := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--anim="): anim = a.trim_prefix("--anim=")
		if a.begins_with("--t="): t = float(a.trim_prefix("--t="))
		if a.begins_with("--shot="): shot = a.trim_prefix("--shot=")
		if a.begins_with("--yaw="): yaw = float(a.trim_prefix("--yaw="))
		if a.begins_with("--only="): only = int(a.trim_prefix("--only="))
	var list := [PS1Creature.rat(), PS1Creature.crawler(), PS1Creature.rat_king(), PS1Creature.gargoyle(), PS1Biped.archer(),
		PS1Creature.leech(), PS1Biped.drowned(), PS1Biped.hanged()]
	for i in list.size():
		var c: Node3D = list[i]
		if only >= 0 and i != only:
			continue
		c.position = Vector3(-11.2 + i * 3.2, 0, 0) if only < 0 else Vector3.ZERO
		c.rotation_degrees.y = yaw
		add_child(c)
		var ap: AnimationPlayer = c.animation_player()
		if not ap.has_animation(anim):
			continue
		ap.play(anim)
		ap.seek(t, true)
		ap.pause()
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 3.2, 13.0) if only < 0 else (Vector3(0, 1.4, 3.2 + only * 0.6) if only < 3 else Vector3(0, 1.1, 4.2))
	cam.rotation_degrees.x = -14 if only < 3 else -6
	cam.fov = 60
	add_child(cam)
	if shot != "":
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()
