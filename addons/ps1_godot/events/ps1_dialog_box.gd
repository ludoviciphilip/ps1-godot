## Default text box: PS1-style panel at the bottom, typewriter text, choices list.
## Inputs come from action lists (add your game's actions once, e.g. in an autoload):
##   PS1DialogBox.accept_actions.append(&"interact")
## Replace the look by editing the exported colors/size or by drawing your own and calling
## the same awaitable API: show_text(speaker, text) / choose(question, options, cancel) -> int.
class_name PS1DialogBox
extends CanvasLayer

static var accept_actions: Array[StringName] = [&"ui_accept"]
static var cancel_actions: Array[StringName] = [&"ui_cancel"]
static var up_actions: Array[StringName] = [&"ui_up"]
static var down_actions: Array[StringName] = [&"ui_down"]

@export var font_size := 8
@export var chars_per_second := 45.0
@export var box_color := Color(0.03, 0.03, 0.05, 0.88)
@export var border_color := Color(0.55, 0.5, 0.42)
@export var text_color := Color(0.92, 0.88, 0.76)
@export var name_color := Color(1.0, 0.72, 0.35)
@export var select_color := Color(1.0, 0.72, 0.35)

signal _advance

var _panel: Panel
var _label: RichTextLabel
var _name: Label
var _arrow: Label
var _options: Array[String] = []
var _sel := 0
var _mode := ""          # "" | "text" | "choice"
var _cancel := -1
var _frames_open := 0

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = box_color
	sb.border_color = border_color
	sb.set_border_width_all(1)
	sb.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.scroll_active = false
	_label.add_theme_font_size_override("normal_font_size", font_size)
	_label.add_theme_color_override("default_color", text_color)
	_panel.add_child(_label)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", font_size)
	_name.add_theme_color_override("font_color", name_color)
	_name.add_theme_color_override("font_shadow_color", Color.BLACK)
	_panel.add_child(_name)
	_arrow = Label.new()
	_arrow.text = "v"
	_arrow.add_theme_font_size_override("font_size", font_size)
	_arrow.add_theme_color_override("font_color", select_color)
	_panel.add_child(_arrow)
	_panel.visible = false

func is_open() -> bool:
	return _panel.visible

func _layout(lines: int) -> void:
	var vp := get_viewport().get_visible_rect().size
	var h := font_size * 1.35 * lines + 16
	_panel.size = Vector2(vp.x - 16, h)
	_panel.position = Vector2(8, vp.y - h - 8)
	_label.position = Vector2(8, 6)
	_label.size = _panel.size - Vector2(16, 10)
	_name.position = Vector2(8, -font_size - 4)
	_arrow.position = _panel.size - Vector2(12, font_size + 6)

func show_text(speaker: String, text: String) -> void:
	_mode = "text"
	_name.text = speaker
	_name.visible = speaker != ""
	_label.text = text
	_label.visible_ratio = 0.0
	_layout(maxi(3, text.count("\n") + 1))
	_panel.visible = true
	_arrow.visible = false
	_frames_open = 0
	await _advance
	_close()

func choose(question: String, options: PackedStringArray, cancel_index := -1) -> int:
	_mode = "choice"
	_options.assign(options)
	_sel = 0
	_cancel = cancel_index
	_name.visible = false
	_question = question
	_draw_choice()
	_label.visible_ratio = 1.0
	_panel.visible = true
	_arrow.visible = false
	_frames_open = 0
	await _advance
	_close()
	return _sel

var _question := ""

func _draw_choice() -> void:
	var t := _question + ("\n" if _question != "" else "")
	for i in _options.size():
		t += ("[color=#%s]> %s[/color]\n" % [select_color.to_html(false), _options[i]]) if i == _sel else "  %s\n" % _options[i]
	_label.text = t
	_layout(_options.size() + (_question.count("\n") + 1 if _question != "" else 0))

func _close() -> void:
	_mode = ""
	_panel.visible = false

static func _pressed(actions: Array[StringName]) -> bool:
	for a in actions:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			return true
	return false

func _process(dt: float) -> void:
	if _mode == "":
		return
	_frames_open += 1
	if _frames_open < 2:   # the button that started the event must not skip the text
		return
	if _mode == "text":
		var total := maxi(_label.get_total_character_count(), 1)
		if _label.visible_ratio < 1.0:
			_label.visible_ratio = minf(1.0, _label.visible_ratio + chars_per_second * dt / total)
			if _pressed(accept_actions):
				_label.visible_ratio = 1.0
		else:
			_arrow.visible = fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.4
			if _pressed(accept_actions) or _pressed(cancel_actions):
				_advance.emit()
	else:
		if _pressed(up_actions):
			_sel = posmod(_sel - 1, _options.size()); _draw_choice()
		elif _pressed(down_actions):
			_sel = posmod(_sel + 1, _options.size()); _draw_choice()
		elif _pressed(accept_actions):
			_advance.emit()
		elif _cancel >= 0 and _pressed(cancel_actions):
			_sel = _cancel
			_advance.emit()

## For tests/scripts: confirm the current text or pick option i.
func debug_confirm(option := -1) -> void:
	if option >= 0:
		_sel = option
	_advance.emit()
