## Scripted camera shots (area reveals, a door opening far away, a boss entrance): a temporary
## camera takes over from the current one, flies through keyed points while looking at targets,
## then glides back and hands control back.
##
##   await PS1Shot.fly(self, [
##       {pos = Vector3(4, 5, -20), look = cathedral_pos, t = 1.8},   # get there in 1.8 s
##       {pos = Vector3(5, 6, -24), look = cathedral_pos, t = 4.0},   # slow drift while it holds
##   ], 1.4)                                                          # 1.4 s back to the player
##
## `fov` per key is optional. Movement eases in/out between keys. Emits nothing; await it.
class_name PS1Shot
extends RefCounted

static func fly(owner: Node, keys: Array, back := 1.2) -> void:
	var vp := owner.get_viewport()
	var game_cam := vp.get_camera_3d()
	if game_cam == null or keys.is_empty():
		return
	var cam := Camera3D.new()
	cam.name = "PS1ShotCamera"
	cam.fov = game_cam.fov
	cam.near = game_cam.near
	cam.far = game_cam.far
	cam.cull_mask = game_cam.cull_mask
	cam.environment = game_cam.environment
	owner.get_tree().current_scene.add_child(cam)
	cam.global_transform = game_cam.global_transform
	cam.current = true
	var from := cam.global_transform
	var fov0 := cam.fov
	for k: Dictionary in keys:
		var to := Transform3D(Basis(), k.pos as Vector3).looking_at(k.look as Vector3, Vector3.UP)
		await _move(cam, from, to, fov0, float(k.get("fov", fov0)), float(k.get("t", 2.0)))
		from = to
		fov0 = cam.fov
	# back: chase the game camera (it may have moved)
	var t := 0.0
	var start := cam.global_transform
	var f0 := cam.fov
	while t < back and is_instance_valid(game_cam):
		await owner.get_tree().process_frame
		t += owner.get_process_delta_time()
		var e := smoothstep(0.0, 1.0, minf(t / maxf(back, 0.01), 1.0))
		cam.global_transform = start.interpolate_with(game_cam.global_transform, e)
		cam.fov = lerpf(f0, game_cam.fov, e)
	if is_instance_valid(game_cam):
		game_cam.current = true
	cam.queue_free()

static func _move(cam: Camera3D, a: Transform3D, b: Transform3D, fa: float, fb: float, dur: float) -> void:
	var t := 0.0
	while t < dur and is_instance_valid(cam):
		await cam.get_tree().process_frame
		t += cam.get_process_delta_time()
		var e := smoothstep(0.0, 1.0, minf(t / maxf(dur, 0.01), 1.0))
		cam.global_transform = a.interpolate_with(b, e)
		cam.fov = lerpf(fa, fb, e)
