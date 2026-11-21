## PS1Settings / PS1SettingsMenu / PS1PauseMenu demo on top of the PS1 demo scene.
## Esc opens the pause menu (Resume / Settings / Quit). Args: -- --shot=PATH --page=pause|video|audio|controls|general
extends Node

func _ready() -> void:
	PS1PauseMenu.open_action = &"ui_cancel"
	add_child(load("res://demo/ps1_demo.tscn").instantiate())
	var shot := ""
	var page := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): shot = a.get_slice("=", 1)
		elif a.begins_with("--page="): page = a.get_slice("=", 1)
	if shot == "":
		return
	await get_tree().create_timer(1.0).timeout
	var pm := PS1PauseMenu.open()
	if page != "pause":
		pm.sel = 1
		pm.activate(1)
		await get_tree().process_frame
		var sm: PS1SettingsMenu = get_tree().root.find_children("*", "PS1SettingsMenu", true, false)[0]
		sm._select_tab(maxi(PS1Settings.sections.find(page), 0))
		sm.sel = 2
		sm._redraw()
	for i in 10: await get_tree().process_frame
	var img := get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(shot)
	get_tree().quit()
