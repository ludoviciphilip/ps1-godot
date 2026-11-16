## Autoload "PS1": applies the post-process to every scene and controls the global effects.
## Debug keys (only in debug builds): F1 jitter | F2 affine | F3 dither | F4 resolution | F5 color depth
extends CanvasLayer

const RESOLUTIONS := [Vector2i(320, 240), Vector2i(480, 360), Vector2i(640, 480)]
var _res_index := 0

const LIT_SHADER := preload("res://addons/ps1_godot/shaders/ps1_lit.gdshader")
const LIT_DOUBLE_SHADER := preload("res://addons/ps1_godot/shaders/ps1_lit_double_sided.gdshader")

## Set to false to disable the F1-F5 debug keys.
var debug_keys := OS.is_debug_build()
const POST_SHADER := preload("res://addons/ps1_godot/shaders/ps1_post.gdshader")

func _ready() -> void:
	layer = 100
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = POST_SHADER
	rect.material = m
	add_child(rect)

## Creates a ready-to-use PS1 material.
func material(tex: Texture2D, color := Color.WHITE, uv_scale := Vector2.ONE,
		emission := Color.BLACK, emission_energy := 0.0, double_sided := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = LIT_DOUBLE_SHADER if double_sided else LIT_SHADER
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("albedo_color", color)
	m.set_shader_parameter("uv_scale", uv_scale)
	m.set_shader_parameter("emission_color", emission)
	m.set_shader_parameter("emission_energy", emission_energy)
	return m

## Flashes every mesh under node (hit feedback). Works with PS1 materials only.
func flash(node: Node, color := Color.WHITE, duration := 0.12) -> void:
	var meshes: Array[GeometryInstance3D] = []
	if node is GeometryInstance3D:
		meshes.append(node)
	for n in node.find_children("*", "GeometryInstance3D", true, false):
		meshes.append(n)
	var tw := node.create_tween()
	tw.tween_method(func(a: float) -> void:
		for m in meshes:
			if is_instance_valid(m):
				m.set_instance_shader_parameter("ps1_flash", Color(color.r, color.g, color.b, a)),
		1.0, 0.0, duration)

func toggle(param: String) -> void:
	var v: float = RenderingServer.global_shader_parameter_get(param)
	RenderingServer.global_shader_parameter_set(param, 0.0 if v > 0.5 else 1.0)
	print("%s = %s" % [param, RenderingServer.global_shader_parameter_get(param)])

func cycle_resolution() -> void:
	_res_index = (_res_index + 1) % RESOLUTIONS.size()
	var r: Vector2i = RESOLUTIONS[_res_index]
	get_window().content_scale_size = r
	RenderingServer.global_shader_parameter_set("ps1_snap_resolution", Vector2(r))
	print("base resolution = %s" % r)

func _unhandled_input(e: InputEvent) -> void:
	if not debug_keys or not (e is InputEventKey and e.pressed and not e.echo):
		return
	match e.keycode:
		KEY_F1: toggle("ps1_jitter_enabled")
		KEY_F2: toggle("ps1_affine_enabled")
		KEY_F3: toggle("ps1_dither_enabled")
		KEY_F4: cycle_resolution()
		KEY_F5:
			var lv: float = RenderingServer.global_shader_parameter_get("ps1_color_levels")
			lv = 8.0 if lv >= 32.0 else lv * 2.0
			RenderingServer.global_shader_parameter_set("ps1_color_levels", lv)
			print("color levels = %s" % lv)
