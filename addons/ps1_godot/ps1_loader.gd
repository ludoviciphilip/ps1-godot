## Loading screen + background scene loading, PS1 style ("NOW LOADING" with a spinning gem, a
## progress bar and tips), so the game never looks frozen:
##
##   await PS1Loader.change_scene("res://levels/crypt.tscn")
##
## It loads the scene on a thread, switches to it, and keeps the screen up until the new scene is
## READY: every PS1BakedLevel has baked (runtime bakes of generated maps take seconds) and every
## node in the group "ps1_loading" has left that group (add your own waits: streaming, generation).
## Customize with the static vars (title, tips, colors, background, min_time) or swap the whole
## look by setting `screen_scene` to your own scene (it gets set_progress(0..1) / set_tip(text)).
class_name PS1Loader
extends CanvasLayer

signal finished

static var title := "NOW LOADING"
static var tips: PackedStringArray = []
static var text_color := Color(0.85, 0.8, 0.7)
static var accent := Color(0.9, 0.45, 0.15)
static var background_color := Color(0, 0, 0)
static var background: Texture2D
## The screen stays at least this long (a flash of loading screen looks like a glitch).
static var min_time := 0.6
static var fade_time := 0.25
## Optional custom screen (a scene with set_progress(float) and set_tip(String) methods).
static var screen_scene: PackedScene
## True while a load is running (games can freeze input / make the player invulnerable).
static var is_loading := false
static var _current: PS1Loader

var _root: Control
var _bar: ColorRect
var _bar_bg: ColorRect
var _label: Label
var _tip: Label
var _gem: Control
var _custom: Node
var _t := 0.0
var _shown := 0.0
var _progress := 0.0

## Loads `path` behind the loading screen and switches to it. Awaitable.
static func change_scene(path: String) -> void:
	if is_loading:
		return
	var tree := Engine.get_main_loop() as SceneTree
	var l := PS1Loader.new()
	_current = l
	is_loading = true
	tree.root.add_child.call_deferred(l)   # may be called from a scene's _ready (root busy)
	await l.ready
	await l._run(path)
	is_loading = false
	_current = null

## Shows the screen while `job` (a Callable, awaited) runs, without changing scene: generating
## a level, saving, streaming...
static func run_job(job: Callable, tip := "") -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var l := PS1Loader.new()
	is_loading = true
	tree.root.add_child.call_deferred(l)
	await l.ready
	if tip != "": l._set_tip(tip)
	await l._fade(1.0)
	await job.call()
	await l._wait_ready()
	await l._fade(0.0)
	l.queue_free()
	is_loading = false

func _init() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.modulate.a = 0.0
	add_child(_root)
	if screen_scene:
		_custom = screen_scene.instantiate()
		_root.add_child(_custom)
	else:
		_build()
	if tips.size():
		_set_tip(tips[randi() % tips.size()])

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = background_color
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	if background:
		var tr := TextureRect.new()
		tr.texture = background
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.modulate = Color(0.55, 0.55, 0.55)
		_root.add_child(tr)
	_label = Label.new()
	_label.text = title
	_label.add_theme_color_override("font_color", text_color)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_root.add_child(_label)
	_gem = Control.new()
	_gem.size = Vector2(16, 16)
	_gem.draw.connect(_draw_gem)
	_root.add_child(_gem)
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(text_color, 0.18)
	_root.add_child(_bar_bg)
	_bar = ColorRect.new()
	_bar.color = accent
	_bar_bg.add_child(_bar)
	_tip = Label.new()
	_tip.add_theme_color_override("font_color", Color(text_color, 0.7))
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_root.add_child(_tip)

## Manual layout from the visible size (works at any base resolution / stretch mode).
func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var m := roundf(vs.y * 0.05)
	_root.size = vs
	_bar_bg.position = Vector2(m, vs.y - m * 0.6 - 2)
	_bar_bg.size = Vector2(vs.x - 2 * m, 2)
	_bar.size = Vector2(_bar_bg.size.x * _progress, 2)
	var ls := _label.get_minimum_size()
	var dots_w := _label.get_theme_font("font").get_string_size("...", HORIZONTAL_ALIGNMENT_LEFT, -1, _label.get_theme_font_size("font_size")).x
	_label.position = Vector2(vs.x - m - ls.x - dots_w + (dots_w if _label.text.ends_with("...") else 0.0) - (0.0), _bar_bg.position.y - ls.y - 4)
	_label.position.x = vs.x - m - _title_w() - dots_w
	_gem.position = Vector2(_label.position.x - 22, _label.position.y + (ls.y - 16) / 2.0)
	# tip: bottom-left, above the title row, wrapped to ~60% of the width
	_tip.size = Vector2(maxf(vs.x * 0.6, 80.0), 0)
	var lines := maxi(_tip.get_line_count(), 1)
	var h := lines * (_tip.get_line_height() + _tip.get_theme_constant("line_spacing"))
	_tip.size.y = h
	_tip.position = Vector2(m, _label.position.y - h - 6)

func _title_w() -> float:
	return _label.get_theme_font("font").get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, _label.get_theme_font_size("font_size")).x

func _set_tip(t: String) -> void:
	if _custom and _custom.has_method("set_tip"):
		_custom.set_tip(t)
	elif _tip:
		_tip.text = t

func _set_progress(p: float) -> void:
	_progress = maxf(_progress, clampf(p, 0.0, 1.0))
	if _custom and _custom.has_method("set_progress"):
		_custom.set_progress(_progress)

## Spinning PS1 "gem": an octahedron projected with no perspective, flat-shaded faces.
func _draw_gem() -> void:
	var c := Vector2(8, 8)
	var r := 7.0
	var a := _t * 2.4
	var pts := [Vector3(0, 1, 0), Vector3(0, -1, 0)]
	for i in 4:
		var ang := a + i * PI / 2.0
		pts.append(Vector3(cos(ang), 0, sin(ang)))
	var faces := []
	for i in 4:
		var e1: Vector3 = pts[2 + i]
		var e2: Vector3 = pts[2 + (i + 1) % 4]
		faces.append([pts[0], e1, e2])
		faces.append([pts[1], e2, e1])
	for f in faces:
		var n: Vector3 = (f[1] - f[0]).cross(f[2] - f[0])
		if n.z <= 0.0:
			continue
		var shade := clampf(0.35 + 0.65 * n.normalized().dot(Vector3(0.3, 0.6, 0.75).normalized()), 0.2, 1.0)
		var poly := PackedVector2Array()
		for v in f:
			poly.append(c + Vector2(v.x, -v.y) * r)
		_gem.draw_colored_polygon(poly, Color(accent.r * shade, accent.g * shade, accent.b * shade))

func _process(dt: float) -> void:
	_t += dt
	if _label:
		_label.text = title + ".".repeat(int(_t * 3.0) % 4)
		_layout()
		_gem.queue_redraw()

func _fade(to: float) -> void:
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", to, fade_time)
	await tw.finished

func _run(path: String) -> void:
	var tree := get_tree()
	await _fade(1.0)
	_shown = Time.get_ticks_msec() / 1000.0
	var err := ResourceLoader.load_threaded_request(path, "PackedScene", true)
	if err != OK:
		push_error("PS1Loader: can't load %s (%d)" % [path, err])
	else:
		var prog := []
		while true:
			var st := ResourceLoader.load_threaded_get_status(path, prog)
			if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				_set_progress(prog[0] * 0.6 if prog.size() else 0.0)
				await tree.process_frame
				continue
			break
		var ps := ResourceLoader.load_threaded_get(path) as PackedScene
		if ps:
			tree.paused = false
			tree.change_scene_to_packed(ps)
	await tree.process_frame
	await tree.process_frame
	await _wait_ready()
	_set_progress(1.0)
	var left := min_time - (Time.get_ticks_msec() / 1000.0 - _shown)
	if left > 0.0:
		await tree.create_timer(left, true).timeout
	await _fade(0.0)
	finished.emit()
	queue_free()

## Waits for every PS1BakedLevel to bake and the group "ps1_loading" to empty.
func _wait_ready() -> void:
	var tree := get_tree()
	var guard := 0.0
	while guard < 120.0:
		var busy := false
		for n in tree.get_nodes_in_group("ps1_baked_level"):
			if not n.is_baked:
				busy = true
		if not tree.get_nodes_in_group("ps1_loading").is_empty():
			busy = true
		if not busy:
			return
		_set_progress(0.6 + 0.4 * PS1Bake.progress)
		await tree.process_frame
		guard += get_process_delta_time()
