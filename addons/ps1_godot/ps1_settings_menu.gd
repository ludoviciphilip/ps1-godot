## Ready-made settings screen for PS1Settings: tabs (Video / Audio / Controls / Language), one
## row per option, built from the option descriptors (your own options show up too). Keyboard,
## gamepad and mouse; key/button rebinding with conflict swap; "Reset to defaults" per tab.
##
##   var m := PS1SettingsMenu.open()      # on top of everything (works while the tree is paused)
##   await m.closed
##
## Style it with the static vars (colors, font, font_size) and feed your own input actions to
## the static action lists (PS1DialogBox's accept/cancel/up/down lists are used too).
class_name PS1SettingsMenu
extends Control

signal closed

static var font: Font
static var font_size := 8
static var color := Color(0.92, 0.88, 0.76)
static var color_dim := Color(0.58, 0.55, 0.48)
static var color_sel := Color(1.0, 0.72, 0.35)
static var background := Color(0.02, 0.02, 0.03, 0.9)
static var left_actions: Array[StringName] = [&"ui_left"]
static var right_actions: Array[StringName] = [&"ui_right"]
static var next_tab_actions: Array[StringName] = [&"ui_focus_next"]
static var prev_tab_actions: Array[StringName] = [&"ui_focus_prev"]

var tab := 0
var sel := -1            # -1 = the tab row
var col := 0             # binding rows: 0 keyboard/mouse, 1 gamepad
var waiting := false
var _tabs: PackedStringArray = []
var _rows: Array[Dictionary] = []
var _scroll := 0
var _drawn: Array[Node] = []
var _row_y: Array[float] = []
var _tab_x: Array[Vector2] = []
var _value_x := 0.0
var _hold := 0.0
var _hold_dir := 0
var _row_h := 12.0
var _just_opened := true

static func open(parent: Node = null) -> PS1SettingsMenu:
	var tree := Engine.get_main_loop() as SceneTree
	var cl := CanvasLayer.new()
	cl.layer = 120
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	var m := PS1SettingsMenu.new()
	cl.add_child(m)
	(parent if parent else tree.root).add_child(cl)
	m.closed.connect(cl.queue_free)
	return m

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	PS1Settings.setup()
	for s in PS1Settings.sections:
		if not PS1Settings.visible_options(s).is_empty():
			_tabs.append(s)
	_select_tab(0)
	PS1Locale.signals().changed.connect(_on_language)
	resized.connect(_redraw)
	(func(): _just_opened = false).call_deferred()

func _exit_tree() -> void:
	if PS1Locale.signals().changed.is_connected(_on_language):
		PS1Locale.signals().changed.disconnect(_on_language)

func _on_language(_l: String) -> void:
	_redraw()

func _select_tab(i: int) -> void:
	tab = posmod(i, _tabs.size())
	_rows.assign(PS1Settings.visible_options(_tabs[tab]))
	_rows.append({key = "", type = "reset", label = "Reset to defaults"})
	_scroll = 0
	_redraw()

func close() -> void:
	PS1Settings.save_all()
	closed.emit()
	queue_free()

# ---------------- drawing ----------------

func _label(t: String, pos: Vector2, c: Color, w := 0.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	if font: l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	if w > 0.0:
		l.size.x = w
		l.horizontal_alignment = align
		l.clip_text = true
	add_child(l)
	_drawn.append(l)
	return l

func _rect(r: Rect2, c: Color) -> void:
	var cr := ColorRect.new()
	cr.position = r.position
	cr.size = r.size
	cr.color = c
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cr)
	_drawn.append(cr)

func _redraw() -> void:
	for n in _drawn:
		n.queue_free()
	_drawn.clear()
	_row_y.clear()
	_tab_x.clear()
	var vs := get_viewport_rect().size
	var m := roundf(vs.y * 0.045)
	_row_h = font_size + 5.0
	_rect(Rect2(Vector2.ZERO, vs), background)
	# tabs
	var x := m
	_label(PS1Locale.t("Settings").to_upper(), Vector2(m, m - 2), color_dim)
	var ty := m + _row_h + 2
	for i in _tabs.size():
		var t := PS1Locale.t(PS1Settings.section_titles.get(_tabs[i], _tabs[i].capitalize())).to_upper()
		var on := i == tab
		var l := _label(t, Vector2(x, ty), color_sel if on else (color if sel == -1 else color_dim))
		var w := l.get_minimum_size().x
		if on:
			_rect(Rect2(x, ty + _row_h - 2, w, 1), color_sel if sel == -1 else color_dim)
		_tab_x.append(Vector2(x, x + w))
		x += w + 12
	# rows
	var top := ty + _row_h + 6
	var bottom := vs.y - m - _row_h - 4
	var per_page := maxi(int((bottom - top) / _row_h), 3)
	if sel >= 0:
		if sel < _scroll: _scroll = sel
		if sel >= _scroll + per_page: _scroll = sel - per_page + 1
	_value_x = roundf(vs.x * 0.54)
	var vw := vs.x - m - _value_x
	for i in range(_scroll, mini(_rows.size(), _scroll + per_page)):
		var o := _rows[i]
		var y := top + (i - _scroll) * _row_h
		_row_y.append(y)
		var is_sel := i == sel
		var c := color_sel if is_sel else color
		if is_sel:
			_rect(Rect2(m - 4, y - 1, vs.x - 2 * m + 8, _row_h), Color(color_sel, 0.08))
			_label(">", Vector2(m - 2, y), color_sel)
		_label(PS1Locale.t(o.label), Vector2(m + 6, y), c, _value_x - m - 10)
		_draw_value(o, Vector2(_value_x, y), vw, is_sel)
	if _scroll > 0:
		_label("^", Vector2(vs.x - m - 6, top - _row_h + 2), color_dim)
	if _scroll + per_page < _rows.size():
		_label("v", Vector2(vs.x - m - 6, bottom - 2), color_dim)
	# footer
	var hint := ""
	if waiting:
		hint = PS1Locale.t("Press a key or button...  (Esc: cancel)") if col == 0 else PS1Locale.t("Press a gamepad button...  (Esc: cancel)")
	elif sel == -1:
		hint = PS1Locale.t("<  > tabs    v options    back: close")
	elif sel < _rows.size() and _rows[sel].type == "binding":
		hint = PS1Locale.t("<  > keyboard / gamepad    confirm: change")
	else:
		hint = PS1Locale.t("^ v select    <  > change    back: close")
	_rect(Rect2(m, vs.y - m - _row_h, vs.x - 2 * m, 1), Color(color_dim, 0.4))
	_label(hint, Vector2(m, vs.y - m - _row_h + 2), color_dim)

func _draw_value(o: Dictionary, pos: Vector2, w: float, is_sel: bool) -> void:
	var c := color_sel if is_sel else color
	var v = PS1Settings.get_value(o.key) if o.key != "" else null
	match o.type:
		"bool":
			_label(PS1Locale.t("On") if v else PS1Locale.t("Off"), pos, c)
		"choice":
			var label := str(v)
			for ch in PS1Settings.choices(o):
				if ch[0] == v:
					label = PS1Locale.t(ch[1])
			_label(("<  %s  >" if is_sel else "%s") % label, pos, c)
		"range":
			var lo: float = o.get("min", 0.0)
			var hi: float = o.get("max", 100.0)
			var bw := minf(w * 0.6, 70.0)
			var t := (float(v) - lo) / maxf(hi - lo, 0.001)
			_rect(Rect2(pos.x, pos.y + _row_h * 0.35, bw, 3), Color(color_dim, 0.35))
			_rect(Rect2(pos.x, pos.y + _row_h * 0.35, bw * t, 3), c)
			_label("%d%s" % [roundi(float(v)), o.get("suffix", "")], Vector2(pos.x + bw + 6, pos.y), c)
		"binding":
			var b := PS1Settings.binding(StringName(o.key.get_file()))
			for k in 2:
				var e = b.get("kb" if k == 0 else "pad")
				var t := PS1Settings.event_label(e)
				if waiting and is_sel and col == k:
					t = "..."
				var on := is_sel and col == k
				_label(("[%s]" if on else " %s ") % t, Vector2(pos.x + k * w * 0.5, pos.y), color_sel if on else (color if is_sel else color_dim), w * 0.5)

# ---------------- input ----------------

static func _any(e: InputEvent, actions: Array) -> bool:
	for a in actions:
		if InputMap.has_action(a) and e.is_action_pressed(a, false, true):
			return true
	return false

func _input(e: InputEvent) -> void:
	if not is_visible_in_tree() or _just_opened:
		return
	if waiting:
		_capture(e)
		get_viewport().set_input_as_handled()
		return
	if not (e is InputEventKey or e is InputEventJoypadButton or e is InputEventJoypadMotion):
		return
	var handled := true
	if _any(e, PS1DialogBox.cancel_actions):
		if sel >= 0: sel = -1; _redraw()
		else: close()
	elif _any(e, next_tab_actions): _select_tab(tab + 1); sel = -1; _redraw()
	elif _any(e, prev_tab_actions): _select_tab(tab - 1); sel = -1; _redraw()
	elif _any(e, PS1DialogBox.up_actions): _move(-1)
	elif _any(e, PS1DialogBox.down_actions): _move(1)
	elif _any(e, left_actions): _change(-1); _hold = 0.0; _hold_dir = -1
	elif _any(e, right_actions): _change(1); _hold = 0.0; _hold_dir = 1
	elif _any(e, PS1DialogBox.accept_actions): _accept()
	else: handled = false
	if handled:
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	# holding left/right repeats on sliders
	if _hold_dir == 0 or waiting:
		return
	var acts := left_actions if _hold_dir < 0 else right_actions
	var held := false
	for a in acts:
		if InputMap.has_action(a) and Input.is_action_pressed(a):
			held = true
	if not held:
		_hold_dir = 0
		return
	_hold += dt
	if _hold > 0.35 and sel >= 0 and sel < _rows.size() and _rows[sel].type == "range":
		_hold -= 0.07
		_change(_hold_dir)

func _move(d: int) -> void:
	sel = clampi(sel + d, -1, _rows.size() - 1)
	col = 0
	PS1Audio.play(PS1DialogBox.move_sound) if PS1DialogBox.move_sound else null
	_redraw()

func _change(d: int) -> void:
	if sel == -1:
		_select_tab(tab + d)
		return
	var o := _rows[sel]
	match o.type:
		"bool": PS1Settings.set_value(o.key, not PS1Settings.get_value(o.key))
		"choice":
			var ch := PS1Settings.choices(o)
			if ch.is_empty(): return
			var i := 0
			for k in ch.size():
				if ch[k][0] == PS1Settings.get_value(o.key): i = k
			PS1Settings.set_value(o.key, ch[posmod(i + d, ch.size())][0])
		"range":
			PS1Settings.set_value(o.key, float(PS1Settings.get_value(o.key)) + d * float(o.get("step", 1.0)))
		"binding":
			col = clampi(col + d, 0, 1)
		_:
			return
	_redraw()

func _accept() -> void:
	if sel == -1:
		sel = 0
		_redraw()
		return
	var o := _rows[sel]
	match o.type:
		"reset":
			PS1Settings.reset_section(_tabs[tab])
			_redraw()
		"binding":
			waiting = true
			_redraw()
		"range":
			pass
		_:
			_change(1)

func _capture(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE:
		waiting = false
		_redraw()
		return
	var got: InputEvent = null
	if col == 0:
		if e is InputEventKey and e.pressed and not e.echo:
			got = InputEventKey.new(); got.physical_keycode = e.physical_keycode if e.physical_keycode != 0 else e.keycode
		elif e is InputEventMouseButton and e.pressed:
			got = InputEventMouseButton.new(); got.button_index = e.button_index
	else:
		if e is InputEventJoypadButton and e.pressed:
			got = InputEventJoypadButton.new(); got.button_index = e.button_index
		elif e is InputEventJoypadMotion and absf(e.axis_value) > 0.6:
			got = InputEventJoypadMotion.new(); got.axis = e.axis; got.axis_value = signf(e.axis_value)
	if got == null:
		return
	PS1Settings.rebind(StringName(_rows[sel].key.get_file()), "kb" if col == 0 else "pad", got)
	waiting = false
	(func(): _just_opened = false).call_deferred()
	_just_opened = true   # the press that set the binding must not also act on the menu
	_redraw()

func _gui_input(e: InputEvent) -> void:
	if waiting:
		return
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: _scroll = maxi(_scroll - 1, 0); _redraw(); return
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN: _scroll = mini(_scroll + 1, maxi(_rows.size() - 1, 0)); _redraw(); return
	if not (e is InputEventMouseMotion or (e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT])):
		return
	var p: Vector2 = e.position
	# tabs
	if _tab_x.size() and p.y < (_row_y[0] if _row_y.size() else 999.0) - 3:
		for i in _tab_x.size():
			if p.x >= _tab_x[i].x - 4 and p.x <= _tab_x[i].y + 4 and e is InputEventMouseButton:
				_select_tab(i)
				sel = -1
				_redraw()
		return
	for k in _row_y.size():
		if p.y >= _row_y[k] - 1 and p.y < _row_y[k] + _row_h - 1:
			var i := _scroll + k
			if e is InputEventMouseMotion:
				if sel != i: sel = i; _redraw()
				return
			sel = i
			var o := _rows[i]
			if o.type == "binding":
				col = 0 if p.x < _value_x + (size.x - _value_x) * 0.45 else 1
				waiting = p.x >= _value_x
				_redraw()
			elif o.type == "reset":
				_accept()
			elif p.x >= _value_x:
				var right: bool = e.button_index == MOUSE_BUTTON_LEFT and (o.type != "range" or p.x > _value_x + 35)
				_change(1 if right else -1)
			else:
				_redraw()
			return
