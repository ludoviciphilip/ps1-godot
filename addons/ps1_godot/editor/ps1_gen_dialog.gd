## "Generate..." dialog of the PS1 Pieces panel: pick a style and a size, see the map, build it.
@tool
extends ConfirmationDialog

signal generate_requested(options: Dictionary)

var _style: OptionButton
var _w: SpinBox
var _d: SpinBox
var _seed: SpinBox
var _rooms: SpinBox
var _loops: HSlider
var _props: HSlider
var _lights: HSlider
var _enemies: SpinBox
var _ceiling: CheckBox
var _clear: CheckBox
var _preview: TextureRect
var _info: Label
var map: PS1LevelGen

func _init() -> void:
	title = "PS1: Generate level"
	ok_button_text = "Generate"
	min_size = Vector2i(760, 470)
	var h := HBoxContainer.new()
	add_child(h)
	var g := GridContainer.new()
	g.columns = 2
	g.custom_minimum_size.x = 300
	h.add_child(g)
	_style = OptionButton.new()
	for n in PS1LevelGen.STYLE_NAMES:
		_style.add_item(n)
	_row(g, "Style", _style)
	_w = _spin(8, 96, 32); _row(g, "Width (cells)", _w)
	_d = _spin(8, 96, 32); _row(g, "Depth (cells)", _d)
	var sh := HBoxContainer.new()
	_seed = _spin(0, 999999, 1)
	_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(_seed)
	var dice := Button.new()
	dice.text = "Random"
	dice.pressed.connect(func(): _seed.value = randi() % 1000000)
	sh.add_child(dice)
	_row(g, "Seed", sh)
	_rooms = _spin(1, 40, 8); _row(g, "Rooms", _rooms)
	_loops = _slider(0.2); _row(g, "Loops", _loops)
	_props = _slider(0.5); _row(g, "Props", _props)
	_lights = _slider(0.5); _lights.max_value = 2.0; _lights.value = 1.0; _row(g, "Lights", _lights)
	_enemies = _spin(0, 60, 6); _row(g, "Enemies", _enemies)
	_ceiling = CheckBox.new(); _ceiling.text = "Ceilings (Ruins: open sky)"; _ceiling.button_pressed = true
	_row(g, "", _ceiling)
	_clear = CheckBox.new(); _clear.text = "Replace the whole level"; _clear.button_pressed = true
	_clear.tooltip_text = "Off: the map is added on the current layer, replacing only the cells it covers."
	_row(g, "", _clear)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_preview = TextureRect.new()
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	v.add_child(_preview)
	_info = Label.new()
	_info.modulate = Color(1, 1, 1, 0.7)
	v.add_child(_info)
	for c: Range in [_w, _d, _seed, _rooms, _loops, _props, _lights, _enemies]:
		c.value_changed.connect(func(_v): _refresh())
	_style.item_selected.connect(func(i):
		_ceiling.button_pressed = i != PS1LevelGen.Style.RUINS
		_refresh())
	confirmed.connect(func(): generate_requested.emit(options()))
	_refresh.call_deferred()

func _row(g: GridContainer, label: String, c: Control) -> void:
	var l := Label.new()
	l.text = label
	g.add_child(l)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(c)

func _spin(lo: float, hi: float, val: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo; s.max_value = hi; s.step = 1; s.value = val
	return s

func _slider(val: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0; s.max_value = 1.0; s.step = 0.05; s.value = val
	s.custom_minimum_size.x = 120
	return s

func options() -> Dictionary:
	return {style = _style.selected, width = int(_w.value), depth = int(_d.value), seed = int(_seed.value),
		rooms = int(_rooms.value), loops = _loops.value, props = _props.value, lights = _lights.value,
		enemies = int(_enemies.value), ceiling = _ceiling.button_pressed, clear = _clear.button_pressed}

func set_options(o: Dictionary) -> void:
	if o.has("style"): _style.select(int(o.style))
	if o.has("width"): _w.value = o.width
	if o.has("depth"): _d.value = o.depth
	if o.has("seed"): _seed.value = o.seed
	_refresh()

func _refresh() -> void:
	var o := options()
	map = PS1LevelGen.generate(o)
	var s := clampi(360 / maxi(map.size.x, map.size.y), 3, 10)
	_preview.texture = ImageTexture.create_from_image(map.preview(s))
	var pieces := map.floor_cells().size() * (2 if o.ceiling else 1) + map.walls.size() + map.lights.size() + map.props.size()
	_info.text = "%d rooms · %d floor cells · %d enemies · ~%d+ pieces%s\ngreen start · red end · magenta enemies · yellow doors · orange lights" % [
		map.rooms.size(), map.floor_cells().size(), map.spawns.size(), pieces,
		"  (big: baking takes a while)" if pieces > 2500 else ""]
