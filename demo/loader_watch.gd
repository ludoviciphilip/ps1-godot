extends Node
## Measures the frames while PS1Loader works (proves the screen never freezes) and screenshots it.
func _ready() -> void:
	var shot := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): shot = a.get_slice("=", 1)
	var t0 := Time.get_ticks_msec()
	var frames := 0
	var worst := 0.0
	var last := Time.get_ticks_usec()
	var shot_done := false
	await get_tree().process_frame
	while PS1Loader.is_loading:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1e6
		last = now
		frames += 1
		worst = maxf(worst, dt)
		if shot != "" and not shot_done and PS1Bake.progress > 0.3 and PS1Bake.progress < 0.9:
			shot_done = true
			var img := get_tree().root.get_texture().get_image()
			print("LOADER shot ", img.get_size())
			img.save_png(shot)
	print("LOADER done in %d ms; %d frames on the loading screen, worst frame %.0f ms" % [Time.get_ticks_msec() - t0, frames, worst * 1000.0])
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()
