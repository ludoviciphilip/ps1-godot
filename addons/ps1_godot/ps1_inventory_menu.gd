## Inventory screen in the PS1 menu style (same font/colors as PS1SettingsMenu): tabs per item
## kind on the left/right keys, the list in the middle, the description below. Accept equips
## (or unequips) equipment; consumables call `use_item` if you set it.
##
##   pause_menu.push(PS1InventoryMenu.create(inventory))     # as a pause-menu page
##   PS1InventoryMenu.open(inventory)                         # standalone (own layer)
class_name PS1InventoryMenu
extends Control

signal closed

var inventory: PS1Inventory
## Called with the PS1Item when the player picks a consumable. Return true to consume one.
var use_item: Callable
## Kinds shown as tabs (only those with something in them appear).
var kinds: Array = [PS1Item.Kind.WEAPON, PS1Item.Kind.SHIELD, PS1Item.Kind.ARMOR, PS1Item.Kind.RING,
	PS1Item.Kind.CONSUMABLE, PS1Item.Kind.KEY, PS1Item.Kind.MISC]
var title := "Inventory"
## Sound played on equip (a PS1Audio name; missing = silent).
var ok_sound := "ui_ok"

var tab := 0
var sel := 0
var _layer: CanvasLayer
var _drawn: Array[Node] = []
var _standalone := false

static func create(inv: PS1Inventory) -> PS1InventoryMenu:
	var m := PS1InventoryMenu.new()
	m.inventory = inv
	return m

static func open(inv: PS1Inventory) -> PS1InventoryMenu:
	var tree := Engine.get_main_loop() as SceneTree
	var cl := CanvasLayer.new()
	cl.layer = 116
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	var m := create(inv)
	m._layer = cl
	m._standalone = true
	cl.add_child(m)
	tree.root.add_child(cl)
	return m

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory.changed.connect(_redraw)
	_redraw()

func _exit_tree() -> void:
	if inventory and inventory.changed.is_connected(_redraw):
		inventory.changed.disconnect(_redraw)

func _tabs() -> Array:
	var out := []
	for k in kinds:
		if not inventory.carried(k).is_empty():
			out.append(k)
	return out

func current_list() -> Array[PS1Item]:
	var t := _tabs()
	if t.is_empty():
		return []
	return inventory.carried(t[clampi(tab, 0, t.size() - 1)])

func _redraw() -> void:
	for n in _drawn:
		n.queue_free()
	_drawn.clear()
	var vs := get_viewport_rect().size
	var m := roundf(vs.y * 0.06)
	var lh := PS1SettingsMenu.font_size + 7.0
	if _standalone:
		var bg := ColorRect.new()
		bg.color = PS1SettingsMenu.background
		bg.size = vs
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		_drawn.append(bg)
	_lbl(PS1Locale.t(title).to_upper(), Vector2(m, m), PS1SettingsMenu.color_dim)
	var tabs := _tabs()
	if tabs.is_empty():
		_lbl(PS1Locale.t("(empty)"), Vector2(m, m + lh * 2.0), PS1SettingsMenu.color_dim)
		return
	tab = clampi(tab, 0, tabs.size() - 1)
	var x := m
	for i in tabs.size():
		var nm := PS1Locale.t(PS1Item.kind_name(tabs[i]))
		var on := i == tab
		var l := _lbl(("[%s]" if on else " %s ") % nm, Vector2(x, m + lh * 1.5),
			PS1SettingsMenu.color_sel if on else PS1SettingsMenu.color_dim)
		x += l.get_minimum_size().x + 10.0
	var list := current_list()
	sel = clampi(sel, 0, maxi(list.size() - 1, 0))
	var y := m + lh * 3.2
	for i in list.size():
		var it := list[i]
		var on := i == sel
		var txt := ("> " if on else "  ") + PS1Locale.t(it.name)
		if it.stackable:
			txt += "  x%d" % inventory.count(it.id)
		if inventory.is_equipped(it.id):
			txt += "   " + PS1Locale.t("(equipped)")
		_lbl(txt, Vector2(m, y), PS1SettingsMenu.color_sel if on else PS1SettingsMenu.color)
		y += lh
	if not list.is_empty():
		var it := list[sel]
		var d := _lbl(PS1Locale.t(it.description), Vector2(m, vs.y - m - lh * 3.0), PS1SettingsMenu.color_dim)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD
		d.size.x = vs.x - m * 2.0

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

## Accept on the selected entry: equip/unequip, or use a consumable.
func activate() -> void:
	var list := current_list()
	if list.is_empty():
		return
	var it := list[sel]
	if it.slot != "":
		if inventory.is_equipped(it.id):
			inventory.unequip(it.slot)
		else:
			inventory.equip(it.id)
		if not PS1Audio.streams(ok_sound).is_empty():
			PS1Audio.play(ok_sound)
	elif it.kind == PS1Item.Kind.CONSUMABLE and use_item.is_valid():
		if use_item.call(it):
			inventory.remove(it.id)
	_redraw()

func close() -> void:
	closed.emit()
	if is_instance_valid(_layer): _layer.queue_free()
	else: queue_free()

func _input(e: InputEvent) -> void:
	if not visible or not (e is InputEventKey or e is InputEventJoypadButton or e is InputEventJoypadMotion):
		return
	var handled := true
	var n := current_list().size()
	if PS1SettingsMenu._any(e, PS1DialogBox.up_actions) and n > 0: sel = posmod(sel - 1, n); _redraw()
	elif PS1SettingsMenu._any(e, PS1DialogBox.down_actions) and n > 0: sel = posmod(sel + 1, n); _redraw()
	elif PS1SettingsMenu._any(e, PS1SettingsMenu.left_actions): tab -= 1; sel = 0; _wrap_tab(); _redraw()
	elif PS1SettingsMenu._any(e, PS1SettingsMenu.right_actions): tab += 1; sel = 0; _wrap_tab(); _redraw()
	elif PS1SettingsMenu._any(e, PS1DialogBox.accept_actions): activate()
	elif _standalone and PS1SettingsMenu._any(e, PS1DialogBox.cancel_actions): close()
	else: handled = false
	if handled:
		get_viewport().set_input_as_handled()

func _wrap_tab() -> void:
	var t := _tabs().size()
	tab = posmod(tab, maxi(t, 1))
