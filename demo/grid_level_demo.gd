## PS1GridLevel demo: a small crypt painted with the starter pieces. Open grid_level_demo.tscn,
## select the "Level" node and the "PS1 Pieces" panel opens: paint, erase, change layers.
## Run it to see the baked result (the camera orbits). Args: -- --screenshot=PATH --shot-t=S
extends Node3D

@onready var cam: Camera3D = $Camera3D
var _t := 0.0
var _shot := ""
var _shot_t := 2.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screenshot="): _shot = a.get_slice("=", 1)
		elif a.begins_with("--shot-t="): _shot_t = float(a.get_slice("=", 1))

func _process(dt: float) -> void:
	_t += dt
	var ang := 0.6 + _t * 0.15
	cam.position = Vector3(8 + cos(ang) * 7.0, 2.6, 6 + sin(ang) * 7.0)
	cam.look_at(Vector3(8, 1.2, 6))
	if _shot != "" and _t >= _shot_t:
		var img := get_viewport().get_texture().get_image()
		img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
		img.save_png(_shot)
		get_tree().quit()
