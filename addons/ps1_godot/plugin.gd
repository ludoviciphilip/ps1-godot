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
