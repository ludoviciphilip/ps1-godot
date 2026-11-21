## "PS1 Events" bottom panel: RPG Maker style editor for the selected PS1Event.
## Pages (tabs), trigger, condition, prompt, graphic; the command list with nested blocks
## (If/Else, Choices). Add (menu with every PS1Command subclass in the project, yours included),
## edit in the Inspector (select a row), delete, move, duplicate. Everything goes through undo/redo.
@tool
extends VBoxContainer

var plugin: EditorPlugin
var event: PS1Event
var page_i := 0

var _title: Label
var _tabs: TabBar
var _trigger: OptionButton
var _cond_on: CheckBox
var _cond_var: LineEdit
var _cond_op: OptionButton
var _cond_val: SpinBox
var _prompt: LineEdit
var _signal: OptionButton
var _signal_lbl: Label
var _graphic: OptionButton
var _tree: Tree
var _add: MenuButton
var _classes: Array = []          # [{menu, path}]
var _page_box: Control
var _empty: Label
var _updating := false

const IND := "◆ "

func _init() -> void:
	name = "PS1 Events"
	custom_minimum_size.y = 230

func build() -> void:
	var top := HBoxContainer.new()
	add_child(top)
	_title = Label.new()
	_title.text = "Select a PS1Event"
	top.add_child(_title)
	_tabs = TabBar.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.tab_changed.connect(func(i): if not _updating: page_i = i; refresh())
	top.add_child(_tabs)
	for t in [["+ Page", _add_page], ["Copy page", _copy_page], ["- Page", _remove_page]]:
		var b := Button.new(); b.text = t[0]; b.pressed.connect(t[1]); top.add_child(b)
	_empty = Label.new()
	_empty.text = "This event has no pages yet: press \"+ Page\"."
	add_child(_empty)
	_page_box = VBoxContainer.new()
	_page_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_page_box)
	var row := HBoxContainer.new()
	_page_box.add_child(row)
	row.add_child(_lbl("Trigger"))
	_trigger = OptionButton.new()
	for t in PS1EventPage.TRIGGER_NAMES:
		_trigger.add_item(t)
	_trigger.item_selected.connect(func(i): _set_page("trigger", i))
	row.add_child(_trigger)
	_signal_lbl = _lbl("signal")
	row.add_child(_signal_lbl)
	_signal = OptionButton.new()
	_signal.tooltip_text = "Signal of the source node (signal_source, default the parent) that runs this page.\nE.g. a monster's death signal = \"on defeated\" event."
	_signal.item_selected.connect(func(i): _set_page("signal_name", StringName(_signal.get_item_text(i)) if _signal.get_item_text(i) != "(choose)" else &""))
	row.add_child(_signal)
	row.add_child(VSeparator.new())
	_cond_on = CheckBox.new(); _cond_on.text = "Condition"
	_cond_on.toggled.connect(_cond_toggled)
	row.add_child(_cond_on)
	_cond_var = LineEdit.new(); _cond_var.placeholder_text = "variable ($local)"; _cond_var.custom_minimum_size.x = 130
	_cond_var.text_submitted.connect(func(_t): _set_cond())
	_cond_var.focus_exited.connect(_set_cond)
	row.add_child(_cond_var)
	_cond_op = OptionButton.new()
	for o in PS1Condition.OP_TEXT: _cond_op.add_item(o)
	_cond_op.item_selected.connect(func(_i): _set_cond())
	row.add_child(_cond_op)
	_cond_val = SpinBox.new(); _cond_val.min_value = -999999; _cond_val.max_value = 999999
	_cond_val.value_changed.connect(func(_v): _set_cond())
	row.add_child(_cond_val)
	row.add_child(VSeparator.new())
	row.add_child(_lbl("Prompt"))
	_prompt = LineEdit.new(); _prompt.custom_minimum_size.x = 110
	_prompt.text_submitted.connect(func(t): _set_page("prompt", t))
	_prompt.focus_exited.connect(func(): if page() and _prompt.text != page().prompt: _set_page("prompt", _prompt.text))
	row.add_child(_prompt)
	row.add_child(_lbl("Graphic"))
	_graphic = OptionButton.new()
	_graphic.item_selected.connect(func(i): _set_page("graphic", NodePath(_graphic.get_item_text(i)) if i > 0 else NodePath()))
	row.add_child(_graphic)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_box.add_child(body)
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_select)
	_tree.item_activated.connect(_on_activate)
	_tree.gui_input.connect(_on_tree_key)
	body.add_child(_tree)
	var side := VBoxContainer.new()
	body.add_child(side)
	_add = MenuButton.new(); _add.text = "Add command"; _add.flat = false
	_add.get_popup().id_pressed.connect(_on_add_id)
	_add.about_to_popup.connect(_fill_add_menu)
	side.add_child(_add)
	for t in [["Edit (Inspector)", _edit_selected], ["Duplicate", _duplicate], ["Move up", func(): _move(-1)],
			["Move down", func(): _move(1)], ["Delete", _delete]]:
		var b := Button.new(); b.text = t[0]; b.pressed.connect(t[1]); side.add_child(b)
	var hint := Label.new()
	hint.text = "Double-click ◆ to add.\nSelect a row to edit it\nin the Inspector."
	hint.modulate = Color(1, 1, 1, 0.55)
	side.add_child(hint)
	EditorInterface.get_inspector().property_edited.connect(func(_p): if event: refresh())
	refresh()

func _lbl(t: String) -> Label:
	var l := Label.new(); l.text = t; return l

# ---------------- state ----------------

func edit(ev: PS1Event) -> void:
	event = ev
	page_i = clampi(page_i, 0, maxi(ev.pages.size() - 1, 0)) if ev else 0
	refresh()

func release() -> void:
	event = null
	refresh()

func page() -> PS1EventPage:
	if event == null or page_i >= event.pages.size():
		return null
	return event.pages[page_i]

func _ur() -> EditorUndoRedoManager:
	return plugin.get_undo_redo()

func refresh() -> void:
	if _tree == null:
		return
	_updating = true
	var sel_path := _selected_path()
	_title.text = ("Event: " + event.name) if event else "Select a PS1Event"
	_tabs.clear_tabs()
	if event:
		for i in event.pages.size():
			_tabs.add_tab("Page %d" % (i + 1))
		if event.pages.size() > 0:
			page_i = clampi(page_i, 0, event.pages.size() - 1)
			_tabs.current_tab = page_i
	var p := page()
	_empty.visible = event != null and p == null
	_page_box.visible = p != null
	_tree.clear()
	if p:
		_trigger.selected = p.trigger
		_cond_on.set_pressed_no_signal(p.condition != null)
		_cond_var.editable = p.condition != null
		_cond_val.editable = p.condition != null
		_cond_op.disabled = p.condition == null
		if p.condition:
			_cond_var.text = p.condition.variable
			_cond_op.selected = p.condition.op
			_cond_val.set_value_no_signal(p.condition.value)
		else:
			_cond_var.text = ""
		_prompt.text = p.prompt
		var on_sig := p.trigger == PS1EventPage.Trigger.ON_SIGNAL
		_signal.visible = on_sig
		_signal_lbl.visible = on_sig
		if on_sig:
			_signal.clear()
			_signal.add_item("(choose)")
			var names := PS1Event.signals_of(event.get_node_or_null(p.signal_source))
			if p.signal_name != &"" and not String(p.signal_name) in names:
				names.append(String(p.signal_name))
			for n in names:
				_signal.add_item(n)
				if n == String(p.signal_name):
					_signal.selected = _signal.item_count - 1
			if p.signal_name == &"":
				_signal.selected = 0
		_graphic.clear()
		_graphic.add_item("(none)")
		for c in event.get_children():
			_graphic.add_item(str(event.get_path_to(c)))
			if event.get_path_to(c) == p.graphic:
				_graphic.selected = _graphic.item_count - 1
		if p.graphic.is_empty():
			_graphic.selected = 0
		var root := _tree.create_item()
		_add_list(root, p, "commands")
		_select_path(sel_path)
	_updating = false

func _add_list(parent: TreeItem, owner: Object, prop: String) -> void:
	var list: Array = owner.get(prop)
	for i in list.size():
		var cmd: PS1Command = list[i]
		var it := _tree.create_item(parent)
		it.set_text(0, IND + (cmd.describe() if cmd else "(empty)"))
		if cmd:
			it.set_custom_color(0, cmd.color())
		it.set_metadata(0, {owner = owner, prop = prop, index = i, cmd = cmd})
		if cmd:
			for b in cmd.blocks():
				var h := _tree.create_item(it)
				h.set_text(0, ": " + b[0])
				h.set_custom_color(0, Color(0.6, 0.6, 0.6))
				h.set_metadata(0, {owner = b[1], prop = b[2], index = 0, header = true})
				_add_list(h, b[1], b[2])
	var end := _tree.create_item(parent)
	end.set_text(0, IND)
	end.set_custom_color(0, Color(0.5, 0.5, 0.5))
	end.set_metadata(0, {owner = owner, prop = prop, index = list.size(), end = true})

## Row path as a list of indices (to keep the selection after refresh).
func _selected_path() -> Array:
	var it := _tree.get_selected() if _tree else null
	var path := []
	while it and it.get_parent():
		path.push_front(it.get_index())
		it = it.get_parent()
	return path

func _select_path(path: Array) -> void:
	var it := _tree.get_root()
	for i in path:
		if it == null or i >= it.get_child_count():
			return
		it = it.get_child(i)
	if it and it != _tree.get_root():
		it.select(0)

# ---------------- pages ----------------

func _set_pages(new_pages: Array, action: String, new_index: int) -> void:
	var typed: Array[PS1EventPage] = []
	typed.assign(new_pages)
	var ur := _ur()
	ur.create_action(action, UndoRedo.MERGE_DISABLE, event)
	ur.add_do_property(event, "pages", typed)
	ur.add_undo_property(event, "pages", event.pages.duplicate())
	ur.add_do_property(self, "page_i", new_index)
	ur.add_undo_property(self, "page_i", page_i)
	ur.add_do_method(self, "refresh")
	ur.add_undo_method(self, "refresh")
	ur.commit_action()

func _add_page() -> void:
	if event == null: return
	var p := PS1EventPage.new()
	var l := event.pages.duplicate(); l.append(p)
	_set_pages(l, "Add event page", l.size() - 1)

func _copy_page() -> void:
	if page() == null: return
	var l := event.pages.duplicate(); l.append(_deep(page()))
	_set_pages(l, "Copy event page", l.size() - 1)

func _remove_page() -> void:
	if page() == null: return
	var l := event.pages.duplicate(); l.remove_at(page_i)
	_set_pages(l, "Remove event page", maxi(page_i - 1, 0))

func _set_page(prop: String, value) -> void:
	var p := page()
	if p == null or _updating or p.get(prop) == value:
		return
	var ur := _ur()
	ur.create_action("Event page: " + prop, UndoRedo.MERGE_DISABLE, event)
	ur.add_do_property(p, prop, value)
	ur.add_undo_property(p, prop, p.get(prop))
	ur.add_do_method(self, "refresh")
	ur.add_undo_method(self, "refresh")
	ur.commit_action()

func _cond_toggled(on: bool) -> void:
	if _updating: return
	var c: PS1Condition = null
	if on:
		c = PS1Condition.new()
		c.variable = _cond_var.text
		c.op = _cond_op.selected
		c.value = int(_cond_val.value)
	_set_page("condition", c)

func _set_cond() -> void:
	var p := page()
	if _updating or p == null or p.condition == null:
		return
	var c := PS1Condition.new()
	c.variable = _cond_var.text.strip_edges()
	c.op = _cond_op.selected
	c.value = int(_cond_val.value)
	if c.variable == p.condition.variable and c.op == p.condition.op and c.value == p.condition.value:
		return
	_set_page("condition", c)

# ---------------- commands ----------------

func command_classes() -> Array:
	var base := {}
	var path := {}
	for c in ProjectSettings.get_global_class_list():
		base[c["class"]] = c["base"]
		path[c["class"]] = c["path"]
	var out := []
	for cls in base:
		var b = cls
		var ok := false
		while base.has(b):
			b = base[b]
			if b == &"PS1Command":
				ok = true
				break
		if ok:
			var inst = load(path[cls]).new()
			out.append({menu = inst.menu_name(), path = path[cls], cls = cls})
	out.sort_custom(func(a, b): return a.menu < b.menu)
	return out

func _fill_add_menu() -> void:
	var pop := _add.get_popup()
	pop.clear()
	_classes = command_classes()
	var cat := ""
	for i in _classes.size():
		var m: String = _classes[i].menu
		if m.get_base_dir() != cat:
			cat = m.get_base_dir()
			pop.add_separator(cat)
		pop.add_item(m.get_file(), i)

func _on_add_id(id: int) -> void:
	add_command(load(_classes[id].path).new())

## Where a new command goes: before the selected command / start of a block / end of a list.
func _insert_point() -> Dictionary:
	var it := _tree.get_selected()
	if it == null:
		return {owner = page(), prop = "commands", index = page().commands.size()}
	return it.get_metadata(0)

func add_command(cmd: PS1Command) -> void:
	if page() == null: return
	var ip := _insert_point()
	var l: Array = ip.owner.get(ip.prop).duplicate()
	l.insert(ip.index, cmd)
	_set_list(ip.owner, ip.prop, l, "Add " + cmd.menu_name().get_file())
	# select the new row and open it in the Inspector
	_select_command(cmd)
	_edit_selected()

func _select_command(cmd: PS1Command) -> void:
	var stack := [_tree.get_root()]
	while not stack.is_empty():
		var it: TreeItem = stack.pop_back()
		if it == null: continue
		var md = it.get_metadata(0) if it != _tree.get_root() else null
		if md is Dictionary and md.get("cmd") == cmd:
			it.select(0)
			_tree.scroll_to_item(it)
			return
		for c in it.get_children():
			stack.append(c)

func _set_list(owner: Object, prop: String, new_list: Array, action: String) -> void:
	var typed: Array[PS1Command] = []
	typed.assign(new_list)
	var ur := _ur()
	ur.create_action(action, UndoRedo.MERGE_DISABLE, event)
	ur.add_do_property(owner, prop, typed)
	ur.add_undo_property(owner, prop, owner.get(prop).duplicate())
	ur.add_do_method(self, "refresh")
	ur.add_undo_method(self, "refresh")
	ur.commit_action()

func _selected_cmd() -> Dictionary:
	var it := _tree.get_selected()
	if it == null: return {}
	var md: Dictionary = it.get_metadata(0)
	return md if md.has("cmd") else {}

func _on_select() -> void:
	var md := _selected_cmd()
	if not md.is_empty() and md.cmd:
		EditorInterface.inspect_object(md.cmd, "", true)

func _edit_selected() -> void:
	_on_select()

func _on_activate() -> void:
	var it := _tree.get_selected()
	if it == null: return
	var md: Dictionary = it.get_metadata(0)
	if md.has("cmd"):
		_on_select()
	else:
		_fill_add_menu()
		var pop := _add.get_popup()
		pop.position = Vector2i(get_screen_position() + get_local_mouse_position())
		pop.popup()

func _on_tree_key(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_DELETE: _delete(); accept_event()
			KEY_D: if e.ctrl_pressed: _duplicate(); accept_event()

func _delete() -> void:
	var md := _selected_cmd()
	if md.is_empty(): return
	var l: Array = md.owner.get(md.prop).duplicate()
	l.remove_at(md.index)
	_set_list(md.owner, md.prop, l, "Delete command")

func _duplicate() -> void:
	var md := _selected_cmd()
	if md.is_empty(): return
	var l: Array = md.owner.get(md.prop).duplicate()
	l.insert(md.index + 1, _deep(md.cmd))
	_set_list(md.owner, md.prop, l, "Duplicate command")

func _move(d: int) -> void:
	var md := _selected_cmd()
	if md.is_empty(): return
	var l: Array = md.owner.get(md.prop).duplicate()
	var j: int = md.index + d
	if j < 0 or j >= l.size(): return
	var c = l[md.index]
	l.remove_at(md.index)
	l.insert(j, c)
	_set_list(md.owner, md.prop, l, "Move command")
	_select_command(c)

static func _deep(r: Resource) -> Resource:
	if r.has_method("duplicate_deep"):
		return r.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	return r.duplicate(true)

## Text of every row (tests).
func rows() -> PackedStringArray:
	var out := PackedStringArray()
	var walk := func(it: TreeItem, depth: int, f: Callable) -> void:
		for c in it.get_children():
			out.append("  ".repeat(depth) + c.get_text(0))
			f.call(c, depth + 1, f)
	if _tree.get_root():
		walk.call(_tree.get_root(), 0, walk)
	return out
