## In-game pause menu (Esc / Start): pauses the game and lists entries. The defaults are
## Resume / Settings / Quit; give it your own:
##
##   PS1PauseMenu.open_action = &"menu"                       # the PS1 autoload opens it
##   PS1PauseMenu.can_open = func(): return not player.dead   # when it's allowed
##   PS1PauseMenu.entries = [
##       ["Resume", PS1PauseMenu.RESUME],
##       ["Status", func(menu): menu.push(make_status_panel())],   # a sub-page (back closes it)
##       ["Settings", PS1PauseMenu.SETTINGS],
##       ["Save", func(menu): save_game(); menu.toast("Saved")],
##       ["Quit to title", func(menu): menu.close(); go_to_title()],
##   ]
## Labels are translated (PS1Locale). Style comes from PS1SettingsMenu's static vars.
class_name PS1PauseMenu
extends Control

signal closed

const RESUME := "__resume"
const SETTINGS := "__settings"
const QUIT := "__quit"

static var open_action: StringName = &""
static var can_open: Callable = func(): return true
static var title := "Paused"
static var entries: Array = [["Resume", RESUME], ["Settings", SETTINGS], ["Quit", QUIT]]
static var current: PS1PauseMenu

var sel := 0
var _layer: CanvasLayer
var _drawn: Array[Node] = []
var _panel: Control
var _settings: PS1SettingsMenu
var _mouse_mode := Input.MOUSE_MODE_VISIBLE
var _was_paused := false
var _toast: Label
var _row_y: Array[float] = []
var _just_opened := true

static func is_open() -> bool:
	return is_instance_valid(current)

static func open() -> PS1PauseMenu:
	if is_open():
		return current
	var tree := Engine.get_main_loop() as SceneTree
	var cl := CanvasLayer.new()
	cl.layer = 115
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	var m := PS1PauseMenu.new()
	m._layer = cl
	cl.add_child(m)
	tree.root.add_child(cl)
	current = m
	return m

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_was_paused = get_tree().paused
	get_tree().paused = true
	PS1Locale.signals().changed.connect(_on_language)
	_redraw()
	(func(): _just_opened = false).call_deferred()

func _on_language(_l: String) -> void:
	_redraw()

func close() -> void:
	if PS1Locale.signals().changed.is_connected(_on_language):
		PS1Locale.signals().changed.disconnect(_on_language)
	get_tree().paused = _was_paused
	Input.mouse_mode = _mouse_mode
	if current == self:
		current = null
	closed.emit()
	if is_instance_valid(_layer): _layer.queue_free()
	else: queue_free()

## Shows a sub-page (status screen...). Back / Esc returns to the list.
func push(panel: Control) -> void:
	pop()
	_panel = panel
	add_child(panel)
	_redraw()

func pop() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	_redraw()

func toast(text: String, seconds := 1.6) -> void:
	if is_instance_valid(_toast): _toast.queue_free()
	_toast = Label.new()
	_toast.text = PS1Locale.t(text)
	_toast.add_theme_font_size_override("font_size", PS1SettingsMenu.font_size)
	_toast.add_theme_color_override("font_color", PS1SettingsMenu.color_sel)
	var vs := get_viewport_rect().size
	_toast.position = Vector2(roundf(vs.y * 0.06), vs.y - roundf(vs.y * 0.06) - 12)
	add_child(_toast)
	var tw := _toast.create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)

func _redraw() -> void:
	for n in _drawn:
		n.queue_free()
	_drawn.clear()
	_row_y.clear()
	var vs := get_viewport_rect().size
	var m := roundf(vs.y * 0.06)
	var bg := ColorRect.new()
	bg.color = PS1SettingsMenu.background
	bg.size = vs
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)
	_drawn.append(bg)
	if is_instance_valid(_panel):
		return
	var lh := PS1SettingsMenu.font_size + 7.0
	var t := _lbl(PS1Locale.t(title).to_upper(), Vector2(m, m), PS1SettingsMenu.color_dim)
	var y := m + lh * 1.8
	for i in entries.size():
		var on := i == sel
		_lbl(("> " if on else "  ") + PS1Locale.t(entries[i][0]), Vector2(m, y), PS1SettingsMenu.color_sel if on else PS1SettingsMenu.color)
		_row_y.append(y)
		y += lh

func _lbl(t: String, pos: Vector2, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	if PS1SettingsMenu.font: l.add_theme_font_override("font", PS1SettingsMenu.font)
	l.add_theme_font_size_override("font_size", PS1SettingsMenu.font_size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	add_child(l)
	_drawn.append(l)
	return l

func activate(i: int) -> void:
	var what = entries[i][1]
	match what:
		RESUME: close()
		QUIT: get_tree().quit()
		SETTINGS:
			visible = false
			_settings = PS1SettingsMenu.open(_layer)
			await _settings.closed
			if is_instance_valid(self):
				visible = true
				_just_opened = true
				(func(): _just_opened = false).call_deferred()
				_redraw()
		_:
			if what is Callable:
				what.call(self)

func _input(e: InputEvent) -> void:
	if not visible or _just_opened or is_instance_valid(_settings) and _settings.is_inside_tree():
		return
	if not (e is InputEventKey or e is InputEventJoypadButton or e is InputEventJoypadMotion):
		return
	var handled := true
	if PS1SettingsMenu._any(e, PS1DialogBox.cancel_actions) or (open_action != &"" and e.is_action_pressed(open_action)):
		if is_instance_valid(_panel): pop()
		else: close()
	elif is_instance_valid(_panel):
		handled = false
	elif PS1SettingsMenu._any(e, PS1DialogBox.up_actions): sel = posmod(sel - 1, entries.size()); _redraw()
	elif PS1SettingsMenu._any(e, PS1DialogBox.down_actions): sel = posmod(sel + 1, entries.size()); _redraw()
	elif PS1SettingsMenu._any(e, PS1DialogBox.accept_actions): activate(sel)
	else: handled = false
	if handled:
		get_viewport().set_input_as_handled()

func _gui_input(e: InputEvent) -> void:
	if is_instance_valid(_panel) or not (e is InputEventMouse):
		return
	var lh := PS1SettingsMenu.font_size + 7.0
	for i in _row_y.size():
		if e.position.y >= _row_y[i] - 1 and e.position.y < _row_y[i] + lh - 1:
			if e is InputEventMouseMotion and sel != i:
				sel = i; _redraw()
			elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				sel = i; activate(i)
