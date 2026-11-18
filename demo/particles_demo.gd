extends Node3D
## Every PS1Particles preset side by side (one-shots re-fire every 1.5 s).
##   godot --path . res://demo/particles_demo.tscn [-- --screenshot=PATH --shot-t=2.2]
const PRESETS := ["embers", "smoke", "mist", "soul", "dust", "sparks", "ash", "motes", "burst", "blood", "fog_puff"]
var _t := 0.0
var _shot := ""
var _shot_t := 2.2
var _ones := []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screenshot="): _shot = a.get_slice("=", 1)
		elif a.begins_with("--shot-t="): _shot_t = float(a.get_slice("=", 1))
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.05, 0.05, 0.07)
	add_child(env)
	var floor_ := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(20, 12); floor_.mesh = pm
	floor_.material_override = PS1.make(null, {color = Color(0.18, 0.17, 0.16)}); add_child(floor_)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 20, 0); add_child(sun)
	for i in PRESETS.size():
		var row := 0 if i < 6 else 1
		var col := i if i < 6 else i - 6
		var x := (col - 2.5) * 2.3
		var z := -row * 3.2
		var l := Label3D.new(); l.text = PRESETS[i]; l.font_size = 28; l.pixel_size = 0.01
		l.position = Vector3(x, 0.15, z + 1.2); l.rotation_degrees.x = -30; add_child(l)
		var p := PS1Particles.preset(PRESETS[i])
		p.position = Vector3(x, 0.9 if PRESETS[i] in ["sparks", "blood", "burst", "fog_puff", "ash"] else 0.3, 0)
		if PRESETS[i] in ["mist", "fog_puff"]: p.position.y = 1.2
		p.position.z = z
		if p.one_shot:
			p.auto_free = false
			_ones.append(p)
		add_child(p)
	var cam := Camera3D.new(); add_child(cam)
	cam.position = Vector3(0, 3.2, 8.5); cam.look_at(Vector3(0, 0.8, -1.6)); cam.fov = 60

func _process(dt: float) -> void:
	_t += dt
	if fmod(_t, 1.5) < dt:
		for p in _ones:
			p.burst(p.burst_count)
	if _shot != "" and _t >= _shot_t:
		get_viewport().get_texture().get_image().save_png(_shot)
		_shot = ""
		get_tree().quit()
