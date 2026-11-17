@tool
extends EditorPlugin

const GLOBALS := {
	"ps1_snap_resolution": ["vec2", Vector2(320, 240)],
	"ps1_jitter_enabled": ["float", 1.0],
	"ps1_affine_enabled": ["float", 1.0],
	"ps1_dither_enabled": ["float", 1.0],
	"ps1_color_levels": ["float", 32.0],
	"ps1_palette": ["sampler2D", ""],
	"ps1_palette_size": ["float", 0.0],
	"ps1_composite": ["float", 0.0],
}

func _enable_plugin() -> void:
	add_autoload_singleton("PS1", "res://addons/ps1_godot/ps1.gd")
	var changed := false
	for key in GLOBALS:
		var setting: String = "shader_globals/" + key
		if not ProjectSettings.has_setting(setting):
			ProjectSettings.set_setting(setting, {"type": GLOBALS[key][0], "value": GLOBALS[key][1]})
			changed = true
	if changed:
		ProjectSettings.save()
		push_warning("PS1 Godot: shader globals added. Restart the editor so they take effect.")

func _disable_plugin() -> void:
	remove_autoload_singleton("PS1")

# ---------------- "PS1 Bake" toolbar button ----------------

var _button: Button
var _pid := -1
var _timer: Timer

func _enter_tree() -> void:
	_button = Button.new()
	_button.text = "PS1 Bake"
	_button.flat = true
	_button.tooltip_text = "Bake the lighting of every PS1BakedLevel in the open scene (saved scene, runs headless)."
	_button.pressed.connect(_bake_pressed)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _button)
	_timer = Timer.new()
	_timer.wait_time = 0.5
	_timer.timeout.connect(_poll)
	add_child(_timer)

func _exit_tree() -> void:
	if _button:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _button)
		_button.queue_free()

func _bake_pressed() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null or root.scene_file_path == "":
		push_warning("PS1 Bake: save the scene first.")
		return
	if root.find_children("*", "PS1BakedLevel", true, false).is_empty() and not root is PS1BakedLevel:
		push_warning("PS1 Bake: the scene has no PS1BakedLevel node (put your static geometry under one).")
		return
	EditorInterface.save_scene()
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
		root.scene_file_path, "--", "--ps1-bake-only", "--ps1-bake-force"])
	_pid = OS.create_process(OS.get_executable_path(), args)
	if _pid <= 0:
		push_error("PS1 Bake: could not start the bake process.")
		return
	_button.text = "Baking..."
	_button.disabled = true
	_timer.start()

func _poll() -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		return
	_timer.stop()
	_pid = -1
	_button.text = "PS1 Bake"
	_button.disabled = false
	EditorInterface.get_resource_filesystem().scan()
	print("PS1 Bake: done. Cache files are in res://ps1_bake_cache/.")
