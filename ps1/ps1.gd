## Autoload "PS1": controla os efeitos globais e aplica o pós-processamento em todas as cenas.
## Atalhos (debug): F1 jitter | F2 affine | F3 dither | F4 resolução | F5 profundidade de cor
extends CanvasLayer

const RESOLUTIONS := [Vector2i(320, 240), Vector2i(480, 360), Vector2i(640, 480)]
var _res_index := 0

const LIT_SHADER := preload("res://ps1/shaders/ps1_lit.gdshader")
const POST_SHADER := preload("res://ps1/shaders/ps1_post.gdshader")

func _ready() -> void:
	layer = 100
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = POST_SHADER
	rect.material = m
	add_child(rect)

## Cria um material PS1 pronto para uso.
func material(tex: Texture2D, color := Color.WHITE, uv_scale := Vector2.ONE,
		emission := Color.BLACK, emission_energy := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = LIT_SHADER
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("albedo_color", color)
	m.set_shader_parameter("uv_scale", uv_scale)
	m.set_shader_parameter("emission_color", emission)
	m.set_shader_parameter("emission_energy", emission_energy)
	return m

func toggle(param: String) -> void:
	var v: float = RenderingServer.global_shader_parameter_get(param)
	RenderingServer.global_shader_parameter_set(param, 0.0 if v > 0.5 else 1.0)
	print("%s = %s" % [param, RenderingServer.global_shader_parameter_get(param)])

func cycle_resolution() -> void:
	_res_index = (_res_index + 1) % RESOLUTIONS.size()
	var r: Vector2i = RESOLUTIONS[_res_index]
	get_window().content_scale_size = r
	RenderingServer.global_shader_parameter_set("ps1_snap_resolution", Vector2(r))
	print("resolução base = %s" % r)

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
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
			print("níveis de cor = %s" % lv)
