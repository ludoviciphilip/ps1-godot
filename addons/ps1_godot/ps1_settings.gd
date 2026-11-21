## Game settings in one place: video, audio, controls and language, saved to
## user://ps1_settings.cfg and applied on startup. Every option is a small descriptor, so the
## ready-made PS1SettingsMenu can draw it, and your game can add its own:
##
##   PS1Settings.add_option({key = "game/shake", section = "video", label = "Screen shake",
##       type = "bool", default = true, apply = func(v): Camera.shake_enabled = v})
##   PS1Settings.add_binding("attack", "Attack")       # rebindable action (keyboard + pad)
##   PS1Settings.hide("audio/voice")                    # no voice acting? hide the slider
##   PS1Settings.setup()                                 # after registering (else: deferred auto)
##   PS1Settings.get_value("input/mouse_sensitivity")   # read anywhere
##
## Built-in: window mode/size, vsync, FPS limit, internal resolution, PS1 effects (jitter, affine,
## dither, color depth), CRT, composite, brightness; master/music/SFX/voice volume; mouse and
## stick sensitivity, invert Y, rebinding; language (PS1Locale).
## Types: bool, range (min/max/step, suffix), choice (choices = [[value, "label"], ...] or a
## Callable returning that), binding.
class_name PS1Settings
extends RefCounted

const PATH := "user://ps1_settings.cfg"
## Section ids in menu order, and their (translatable) titles.
static var sections: PackedStringArray = ["video", "audio", "controls", "general"]
static var section_titles := {video = "Video", audio = "Audio", controls = "Controls", general = "Language"}
static var options: Array[Dictionary] = []
static var is_setup := false
static var _values := {}
static var _hidden := {}
static var _bindings: Array[Dictionary] = []      # {action, label, kb: InputEvent, pad: InputEvent}
static var _builtin_done := false
static var _signals: PS1SettingsSignals

static func signals() -> PS1SettingsSignals:
	if _signals == null:
		_signals = PS1SettingsSignals.new()
	return _signals

# ---------------- registering ----------------

static func add_option(opt: Dictionary) -> void:
	_builtin()
	for k in ["key", "type"]:
		assert(opt.has(k), "PS1Settings option needs '%s'" % k)
	if not opt.has("section"): opt.section = "general"
	if not opt.has("label"): opt.label = opt.key.get_file().capitalize()
	for i in options.size():
		if options[i].key == opt.key:
			options[i] = opt
			return
	options.append(opt)
	if is_setup:
		_values[opt.key] = _load_one(opt)
		_apply(opt)

## Removes an option (and its binding). Call it when the object owning its apply callable goes
## away (static data must not keep callables of freed objects).
static func remove_option(key: String) -> void:
	options = options.filter(func(o): return o.key != key)
	if key.begins_with("bindings/"):
		_bindings = _bindings.filter(func(b): return "bindings/" + String(b.action) != key)
	_values.erase(key)

static func hide(key: String, hidden := true) -> void:
	_hidden[key] = hidden

static func is_hidden(key: String) -> bool:
	if key == "general/language" and PS1Locale.languages().size() < 2:
		return true
	return _hidden.get(key, false)

## A rebindable action. Its current first keyboard/mouse event and first gamepad event are the
## defaults ("Reset" brings them back).
static func add_binding(action: StringName, label: String) -> void:
	_builtin()
	var b := {action = action, label = label, kb = null, pad = null}
	if InputMap.has_action(action):
		for e in InputMap.action_get_events(action):
			if b.kb == null and (e is InputEventKey or e is InputEventMouseButton): b.kb = e
			elif b.pad == null and (e is InputEventJoypadButton or e is InputEventJoypadMotion): b.pad = e
	b.default_kb = b.kb
	b.default_pad = b.pad
	_bindings.append(b)
	add_option({key = "bindings/" + action, section = "controls", label = label, type = "binding", default = ""})

static func option(key: String) -> Dictionary:
	_builtin()
	for o in options:
		if o.key == key:
			return o
	return {}

static func visible_options(section: String) -> Array[Dictionary]:
	_builtin()
	var out: Array[Dictionary] = []
	for o in options:
		if o.section == section and not is_hidden(o.key):
			out.append(o)
	return out

# ---------------- values ----------------

## Loads the saved values and applies everything. Call after registering your own options.
static func setup() -> void:
	_builtin()
	if is_setup:
		return
	is_setup = true
	var cf := ConfigFile.new()
	cf.load(PATH)
	for o in options:
		_values[o.key] = _load_one(o, cf)
	for b in _bindings:
		_load_binding(b, cf)
	for o in options:
		_apply(o)

static func _load_one(o: Dictionary, cf: ConfigFile = null) -> Variant:
	if cf == null:
		cf = ConfigFile.new()
		cf.load(PATH)
	var v = cf.get_value(o.key.get_base_dir(), o.key.get_file(), _default(o))
	return _sanitize(o, v)

static func _default(o: Dictionary) -> Variant:
	return o.default.call() if o.default is Callable else o.default

static func _sanitize(o: Dictionary, v) -> Variant:
	match o.type:
		"bool": return bool(v)
		"range": return clampf(float(v), float(o.get("min", 0.0)), float(o.get("max", 100.0)))
		"choice":
			var vals := choices(o).map(func(c): return c[0])
			if vals.is_empty(): return v
			return v if v in vals else (_default(o) if _default(o) in vals else vals[0])
	return v

static func choices(o: Dictionary) -> Array:
	var c = o.get("choices", [])
	return c.call() if c is Callable else c

static func get_value(key: String) -> Variant:
	if not is_setup:
		setup()
	return _values.get(key, _default(option(key)) if not option(key).is_empty() else null)

static func set_value(key: String, value, save := true) -> void:
	var o := option(key)
	if o.is_empty():
		push_warning("PS1Settings: unknown option " + key)
		return
	_values[key] = _sanitize(o, value)
	_apply(o)
	signals().changed.emit(key, _values[key])
	if save:
		save_all()

static func _apply(o: Dictionary) -> void:
	if o.has("apply") and o.apply is Callable and o.apply.is_valid():
		o.apply.call(_values.get(o.key))

static func reset_section(section: String) -> void:
	for o in options:
		if o.section == section and o.type != "binding":
			set_value(o.key, _default(o), false)
	if section == "controls":
		for b in _bindings:
			_set_event(b, "kb", b.default_kb)
			_set_event(b, "pad", b.default_pad)
	save_all()

static func save_all() -> void:
	var cf := ConfigFile.new()
	for o in options:
		if o.type != "binding":
			cf.set_value(o.key.get_base_dir(), o.key.get_file(), _values.get(o.key))
	for b in _bindings:
		cf.set_value("bindings", String(b.action), [event_to_string(b.kb), event_to_string(b.pad)])
	cf.save(PATH)

# ---------------- bindings ----------------

static func bindings() -> Array[Dictionary]:
	return _bindings

static func binding(action: StringName) -> Dictionary:
	for b in _bindings:
		if b.action == action:
			return b
	return {}

## Sets the keyboard/mouse ("kb") or gamepad ("pad") event of an action. If another managed
## action used that input, the two swap. Saves.
static func rebind(action: StringName, slot: String, event: InputEvent) -> void:
	var b := binding(action)
	if b.is_empty():
		return
	var old: InputEvent = b[slot]
	for other in _bindings:
		if other != b and other[slot] != null and _same(other[slot], event):
			_set_event(other, slot, old)
	_set_event(b, slot, event)
	save_all()
	signals().changed.emit("bindings/" + action, event_label(event))

static func _set_event(b: Dictionary, slot: String, e: InputEvent) -> void:
	if not InputMap.has_action(b.action):
		return
	if b[slot] != null:
		for ev in InputMap.action_get_events(b.action):
			if _same(ev, b[slot]):
				InputMap.action_erase_event(b.action, ev)
	b[slot] = e
	if e != null:
		InputMap.action_add_event(b.action, e)

static func _same(a: InputEvent, b: InputEvent) -> bool:
	return a != null and b != null and event_to_string(a) == event_to_string(b)

static func _load_binding(b: Dictionary, cf: ConfigFile) -> void:
	var saved = cf.get_value("bindings", String(b.action)) if cf.has_section_key("bindings", String(b.action)) else null
	if saved is Array and saved.size() == 2:
		_set_event(b, "kb", string_to_event(saved[0]))
		_set_event(b, "pad", string_to_event(saved[1]))

static func event_to_string(e: InputEvent) -> String:
	if e is InputEventKey:
		return "key:%d" % (e.physical_keycode if e.physical_keycode != 0 else e.keycode)
	if e is InputEventMouseButton:
		return "mouse:%d" % e.button_index
	if e is InputEventJoypadButton:
		return "joy:%d" % e.button_index
	if e is InputEventJoypadMotion:
		return "axis:%d:%d" % [e.axis, 1 if e.axis_value > 0 else -1]
	return ""

static func string_to_event(s: String) -> InputEvent:
	var p := s.split(":")
	match p[0]:
		"key":
			var e := InputEventKey.new(); e.physical_keycode = int(p[1]); return e
		"mouse":
			var e := InputEventMouseButton.new(); e.button_index = int(p[1]); return e
		"joy":
			var e := InputEventJoypadButton.new(); e.button_index = int(p[1]); return e
		"axis":
			var e := InputEventJoypadMotion.new(); e.axis = int(p[1]); e.axis_value = float(p[2]); return e
	return null

const _JOY := ["A", "B", "X", "Y", "Back", "Guide", "Start", "L3", "R3", "LB", "RB", "D-pad Up", "D-pad Down", "D-pad Left", "D-pad Right"]
const _MOUSE := {1: "Mouse L", 2: "Mouse R", 3: "Mouse M", 4: "Wheel Up", 5: "Wheel Down", 8: "Mouse 4", 9: "Mouse 5"}

## Short readable name of an input ("W", "Mouse L", "Pad A", "RT"...).
static func event_label(e: InputEvent) -> String:
	if e == null:
		return "—"
	if e is InputEventKey:
		var k: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
		if e.physical_keycode != 0 and DisplayServer.get_name() != "headless":
			k = DisplayServer.keyboard_get_keycode_from_physical(e.physical_keycode)
		return OS.get_keycode_string(k)
	if e is InputEventMouseButton:
		return PS1Locale.t(_MOUSE.get(e.button_index, "Mouse %d" % e.button_index))
	if e is InputEventJoypadButton:
		return "Pad " + (_JOY[e.button_index] if e.button_index < _JOY.size() else str(e.button_index))
	if e is InputEventJoypadMotion:
		match e.axis:
			JOY_AXIS_TRIGGER_LEFT: return "LT"
			JOY_AXIS_TRIGGER_RIGHT: return "RT"
			JOY_AXIS_LEFT_X: return "LS " + ("→" if e.axis_value > 0 else "←")
			JOY_AXIS_LEFT_Y: return "LS " + ("↓" if e.axis_value > 0 else "↑")
			JOY_AXIS_RIGHT_X: return "RS " + ("→" if e.axis_value > 0 else "←")
			JOY_AXIS_RIGHT_Y: return "RS " + ("↓" if e.axis_value > 0 else "↑")
	return "?"

# ---------------- convenience for games ----------------

## Mouse look multiplier (1.0 = 100%).
static func mouse_sensitivity() -> float:
	return float(get_value("input/mouse_sensitivity")) / 100.0

static func stick_sensitivity() -> float:
	return float(get_value("input/stick_sensitivity")) / 100.0

static func invert_y() -> bool:
	return bool(get_value("input/invert_y"))

# ---------------- built-in options ----------------

static func _ps1() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("PS1") if tree else null

static func _window() -> Window:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root if tree else null

## Window size the game starts with (project override, else the real window).
static func _current_size() -> String:
	var w := int(ProjectSettings.get_setting("display/window/size/window_width_override", 0))
	var h := int(ProjectSettings.get_setting("display/window/size/window_height_override", 0))
	if w == 0 and _has_window() and _window():
		return "%dx%d" % [_window().size.x, _window().size.y]
	return "%dx%d" % [w, h]

static func _has_window() -> bool:
	return DisplayServer.get_name() != "headless"

static func _builtin() -> void:
	if _builtin_done:
		return
	_builtin_done = true
	var base := Vector2i(int(ProjectSettings.get_setting("display/window/size/viewport_width", 320)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 240)))
	var add := func(o: Dictionary): options.append(o)
	# ---- video ----
	add.call({key = "video/window_mode", section = "video", label = "Display", type = "choice", default = 0,
		choices = [[0, "Windowed"], [1, "Fullscreen"], [2, "Exclusive fullscreen"]],
		apply = func(v):
			if not _has_window(): return
			var w := _window()
			var m: int = [Window.MODE_WINDOWED, Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN][v]
			if w.mode != m:
				w.mode = m
				if m == Window.MODE_WINDOWED:
					_apply(option("video/window_size"))})
	add.call({key = "video/window_size", section = "video", label = "Window size", type = "choice",
		default = func(): return _current_size(),
		choices = func():
			var out := []
			var scr := DisplayServer.screen_get_usable_rect().size if _has_window() else Vector2i(3840, 2160)
			for s in [Vector2i(960, 720), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3200, 1800), Vector2i(3840, 2160)]:
				if s.x <= scr.x and s.y <= scr.y:
					out.append(["%dx%d" % [s.x, s.y], "%d x %d" % [s.x, s.y]])
			var cur := _current_size()
			if not out.any(func(c): return c[0] == cur) and not cur.begins_with("0x"):
				out.append([cur, cur.replace("x", " x ")])
			return out,
		apply = func(v):
			if not _has_window() or str(v).begins_with("0x"): return
			var w := _window()
			if w.mode != Window.MODE_WINDOWED: return
			var s := Vector2i(int(str(v).get_slice("x", 0)), int(str(v).get_slice("x", 1)))
			var scr := DisplayServer.screen_get_usable_rect(w.current_screen)
			w.size = Vector2i(mini(s.x, scr.size.x), mini(s.y, scr.size.y))
			w.position = scr.position + (scr.size - w.size) / 2})
	add.call({key = "video/vsync", section = "video", label = "V-Sync", type = "bool", default = true,
		apply = func(v): if _has_window(): DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v else DisplayServer.VSYNC_DISABLED)})
	add.call({key = "video/max_fps", section = "video", label = "FPS limit", type = "choice", default = 0,
		choices = [[0, "Unlimited"], [30, "30"], [60, "60"], [120, "120"], [144, "144"]],
		apply = func(v): Engine.max_fps = int(v)})
	add.call({key = "video/internal_resolution", section = "video", label = "Internal resolution", type = "choice", default = 1.0,
		choices = [[1.0, "%dp (PS1)" % base.y], [1.5, "%dp" % int(base.y * 1.5)], [2.0, "%dp" % (base.y * 2)], [3.0, "%dp" % (base.y * 3)]],
		apply = func(v):
			var ps1 := _ps1()
			if ps1: ps1.set_internal_resolution(float(v))})
	for fx in [["video/jitter", "Vertex jitter", "ps1_jitter_enabled"], ["video/affine", "Texture warping", "ps1_affine_enabled"],
			["video/dither", "Dithering", "ps1_dither_enabled"]]:
		var g: String = fx[2]
		add.call({key = fx[0], section = "video", label = fx[1], type = "bool", default = true,
			apply = func(v):
				var ps1 := _ps1()
				if ps1: ps1.set_global(g, 1.0 if v else 0.0)})
	add.call({key = "video/color_depth", section = "video", label = "Color depth", type = "choice", default = 32.0,
		choices = [[32.0, "15-bit (PS1)"], [256.0, "24-bit"]],
		apply = func(v):
			var ps1 := _ps1()
			if ps1: ps1.set_global("ps1_color_levels", float(v))})
	add.call({key = "video/crt", section = "video", label = "CRT filter", type = "range", default = 0.0, min = 0.0, max = 100.0, step = 10.0, suffix = "%",
		apply = func(v):
			var ps1 := _ps1()
			if ps1: ps1.set_crt(float(v) / 100.0)})
	add.call({key = "video/composite", section = "video", label = "TV signal (composite)", type = "range", default = 0.0, min = 0.0, max = 100.0, step = 10.0, suffix = "%",
		apply = func(v):
			var ps1 := _ps1()
			if ps1: ps1.set_composite(float(v) / 100.0)})
	add.call({key = "video/brightness", section = "video", label = "Brightness", type = "range", default = 100.0, min = 50.0, max = 150.0, step = 5.0, suffix = "%",
		apply = func(v):
			var ps1 := _ps1()
			if ps1: ps1.set_brightness(float(v) / 100.0)})
	# ---- audio ----
	for a in [["audio/master", "Master volume", "Master"], ["audio/music", "Music", "Music"], ["audio/sfx", "Sound effects", "SFX"], ["audio/voice", "Voices", "Voice"]]:
		var bus: String = a[2]
		add.call({key = a[0], section = "audio", label = a[1], type = "range", default = 100.0 if bus != "Music" else 80.0,
			min = 0.0, max = 100.0, step = 5.0, suffix = "%",
			apply = func(v):
				var i := AudioServer.get_bus_index(bus)
				if i >= 0:
					AudioServer.set_bus_volume_db(i, linear_to_db(maxf(float(v) / 100.0, 0.0001)))
					AudioServer.set_bus_mute(i, float(v) <= 0.0)})
	# ---- controls ----
	add.call({key = "input/mouse_sensitivity", section = "controls", label = "Mouse sensitivity", type = "range", default = 100.0, min = 10.0, max = 300.0, step = 10.0, suffix = "%"})
	add.call({key = "input/stick_sensitivity", section = "controls", label = "Stick sensitivity", type = "range", default = 100.0, min = 10.0, max = 300.0, step = 10.0, suffix = "%"})
	add.call({key = "input/invert_y", section = "controls", label = "Invert camera Y", type = "bool", default = false})
	# ---- language ----
	add.call({key = "general/language", section = "general", label = "Language", type = "choice", default = "",
		choices = func():
			var out := []
			for l in PS1Locale.languages():
				out.append([l, PS1Locale.native_name(l)])
			return out,
		apply = func(v): if PS1Locale.languages().size() > 0: PS1Locale.set_language(str(v))})
