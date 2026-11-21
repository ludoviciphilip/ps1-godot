@tool
extends EditorPlugin

const GLOBALS := {
	"ps1_snap_resolution": ["vec2", Vector2(320, 240)],
	"ps1_jitter_enabled": ["float", 1.0],
	"ps1_affine_enabled": ["float", 1.0],
	"ps1_dither_enabled": ["float", 1.0],
	"ps1_color_levels": ["float", 32.0],
	"ps1_palette": ["sampler2D", ""],
	"ps1_palette_size": ["float", 0.0],
	"ps1_composite": ["float", 0.0],
	"ps1_crt": ["float", 0.0],
}

func _enable_plugin() -> void:
	add_autoload_singleton("PS1", "res://addons/ps1_godot/ps1.gd")
	var changed := false
	for key in GLOBALS:
		var setting: String = "shader_globals/" + key
		if not ProjectSettings.has_setting(setting):
			ProjectSettings.set_setting(setting, {"type": GLOBALS[key][0], "value": GLOBALS[key][1]})
			changed = true
	if changed:
		ProjectSettings.save()
		push_warning("PS1 Godot: shader globals added. Restart the editor so they take effect.")

func _disable_plugin() -> void:
	remove_autoload_singleton("PS1")

# ---------------- level painter (PS1GridLevel) ----------------

const Painter := preload("res://addons/ps1_godot/editor/ps1_level_painter.gd")
var _painter: Painter
var _painter_panel: Control

const EventEditor := preload("res://addons/ps1_godot/editor/ps1_event_editor.gd")
var _events: EventEditor
var _editing_event := false

func _handles(object: Object) -> bool:
	return object is PS1GridLevel or object is PS1Event

func _edit(object: Object) -> void:
	_editing_event = object is PS1Event
	if object is PS1GridLevel:
		_painter.edit(object)
	else:
		_painter.release()
	if object is PS1Event:
		_events.edit(object)
	elif object == null:
		pass   # keep the event panel while its commands are open in the Inspector

func _make_visible(visible: bool) -> void:
	if visible:
		make_bottom_panel_item_visible(_events if _editing_event else _painter_panel)
	else:
		_painter.release()

## Hidden ceilings must not be saved hidden.
func _apply_changes() -> void:
	if _painter:
		_painter.apply_xray(false)
		_painter.call_deferred("apply_xray")

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if _painter.input(camera, event):
		update_overlays()
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS

# ---------------- "PS1 Bake" toolbar button ----------------

var _button: Button
var _pid := -1
var _timer: Timer

func _enter_tree() -> void:
	_painter = Painter.new()
	_painter.plugin = self
	add_child(_painter)
	_painter_panel = _painter.build_panel()
	add_control_to_bottom_panel(_painter_panel, "PS1 Pieces")
	_events = EventEditor.new()
	_events.plugin = self
	_events.build()
	add_control_to_bottom_panel(_events, "PS1 Events")
	_button = Button.new()
	_button.text = "PS1 Bake"
	_button.flat = true
	_button.tooltip_text = "Bake the lighting of every PS1BakedLevel in the open scene (saved scene, runs headless)."
	_button.pressed.connect(_bake_pressed)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _button)
	_paint_menu = MenuButton.new()
	_paint_menu.text = "PS1 Paint"
	_paint_menu.tooltip_text = "Vertex-color paint on the selected nodes (and everything under them). Undoable.\nFor whole levels prefer the Vertex paint options of PS1BakedLevel (stored in the bake cache)."
	var pop := _paint_menu.get_popup()
	for item in PAINT_ITEMS:
		pop.add_item(item)
	pop.id_pressed.connect(func(i): _paint_selected(i))
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _paint_menu)
	_event_button = Button.new()
	_event_button.text = "+ Event"
	_event_button.flat = true
	_event_button.tooltip_text = "Add a PS1Event under the selected node.\nOn a monster (a node with a death signal) it's set up as an \"on defeated\" event:\nput drops, messages, variables... in its command list."
	_event_button.pressed.connect(func(): add_event_to_selected())
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _event_button)
	add_tool_menu_item("PS1: Update translation CSV", func(): update_translations())
	_timer = Timer.new()
	_timer.wait_time = 0.5
	_timer.timeout.connect(_poll)
	add_child(_timer)

func _exit_tree() -> void:
	if _events:
		remove_control_from_bottom_panel(_events)
		_events.queue_free()
	if _painter_panel:
		remove_control_from_bottom_panel(_painter_panel)
		_painter_panel.queue_free()
	if _painter:
		_painter.release()
		_painter.release_generator()
		_painter.queue_free()
	if _paint_menu:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _paint_menu)
		_paint_menu.queue_free()
	if _event_button:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _event_button)
		_event_button.queue_free()
	remove_tool_menu_item("PS1: Update translation CSV")
	if _button:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _button)
		_button.queue_free()

# ---------------- translations ----------------

## Project > Tools > "PS1: Update translation CSV": collects every event text and tr("...") into
## the CSV (project settings ps1/locale/csv, languages, source), keeps existing translations and
## registers the imported .translation files. Also: godot -e --path . -- --ps1-update-translations
func update_translations() -> Dictionary:
	var defaults := {"ps1/locale/csv": "res://lang/strings.csv", "ps1/locale/source": "en", "ps1/locale/languages": "en,pt,es"}
	for k in defaults:
		if not ProjectSettings.has_setting(k):
			ProjectSettings.set_setting(k, defaults[k])
	var csv: String = ProjectSettings.get_setting("ps1/locale/csv")
	var source: String = ProjectSettings.get_setting("ps1/locale/source")
	var langs := PackedStringArray(String(ProjectSettings.get_setting("ps1/locale/languages")).replace(" ", "").split(",", false))
	var report := PS1Locale.update_csv(csv, langs, source)
	# Godot imports the CSV into <name>.<lang>.translation; list them so they load at startup
	var trs := PackedStringArray(ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray()))
	for l in langs:
		var f := csv.get_basename() + "." + l + ".translation"
		if not f in trs:
			trs.append(f)
	ProjectSettings.set_setting("internationalization/locale/translations", trs)
	ProjectSettings.save()
	EditorInterface.get_resource_filesystem().scan()
	print("PS1 TRANSLATIONS %s: %d texts (+%d new), still to translate: %s, unused: %d" % [csv, report.texts, report.added, report.missing, report.unused])
	return report

# ---------------- "+ Event" toolbar button ----------------

var _event_button: Button

## Adds a PS1Event under the selected node (undoable) and selects it. If the node has a death
## signal the page is ON_SIGNAL on it ("on defeated"). Returns the event.
func add_event_to_selected() -> PS1Event:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return null
	var sel := EditorInterface.get_selection().get_top_selected_nodes()
	var parent: Node = sel[0] if sel.size() and sel[0] is Node3D else root
	var ev := PS1Event.new()
	var page := PS1EventPage.new()
	var death := PS1Event.death_signal_of(parent) if parent != root else ""
	if death != "":
		ev.name = "OnDefeated"
		page.trigger = PS1EventPage.Trigger.ON_SIGNAL
		page.signal_name = StringName(death)
		page.prompt = ""
	else:
		ev.name = "Event"
	ev.pages = [page]
	var ur := get_undo_redo()
	ur.create_action("PS1: add event " + ev.name, UndoRedo.MERGE_DISABLE, root)
	ur.add_do_method(parent, "add_child", ev, true)
	ur.add_do_method(ev, "set_owner", root)
	ur.add_do_reference(ev)
	ur.add_undo_method(parent, "remove_child", ev)
	ur.commit_action()
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(ev)
	EditorInterface.edit_node(ev)
	return ev

# ---------------- "PS1 Paint" toolbar menu ----------------

const PAINT_ITEMS := ["Ambient occlusion", "Darken bottom (height gradient)", "Grime", "Clear paint"]
var _paint_menu: MenuButton

## Paints the selected nodes. Returns the number of painted vertices (self-test uses it).
func _paint_selected(item: int) -> int:
	var sel := EditorInterface.get_selection().get_top_selected_nodes()
	var scene_root := EditorInterface.get_edited_scene_root()
	var targets: Array[MeshInstance3D] = []
	for n in sel:
		targets.append_array(PS1VertexPaint.meshes(n))
	if targets.is_empty():
		push_warning("PS1 Paint: select nodes with meshes first.")
		return 0
	var old := targets.map(func(mi): return mi.mesh)
	PS1VertexPaint.always_new = true
	var count := 0
	for n in sel:
		match item:
			0: count += await PS1VertexPaint.ambient_occlusion(n)
			1:
				var y0 := INF
				for mi in PS1VertexPaint.meshes(n):
					y0 = minf(y0, (mi.global_transform * mi.get_aabb()).position.y)
				count += PS1VertexPaint.gradient(n, Color(0.45, 0.43, 0.5), Color.WHITE, y0, y0 + 2.5)
			2: count += PS1VertexPaint.grime(n, 0.2)
			3: count += PS1VertexPaint.clear(n)
	PS1VertexPaint.always_new = false
	var ur := get_undo_redo()
	ur.create_action("PS1 Paint: " + PAINT_ITEMS[item], UndoRedo.MERGE_DISABLE, scene_root)
	for i in targets.size():
		var mi := targets[i]
		ur.add_do_property(mi, "mesh", mi.mesh)
		ur.add_undo_property(mi, "mesh", old[i])
		# meshes inside an instanced piece are only saved if the instance is editable
		if mi.owner and mi.owner != scene_root and scene_root.is_ancestor_of(mi.owner):
			scene_root.set_editable_instance(mi.owner, true)
	ur.commit_action(false)
	print("PS1 Paint: %s on %d meshes (%d vertices)" % [PAINT_ITEMS[item], targets.size(), count])
	return count

func _bake_pressed() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null or root.scene_file_path == "":
		push_warning("PS1 Bake: save the scene first.")
		return
	if root.find_children("*", "PS1BakedLevel", true, false).is_empty() and not root is PS1BakedLevel:
		push_warning("PS1 Bake: the scene has no PS1BakedLevel node (put your static geometry under one).")
		return
	EditorInterface.save_scene()
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
		root.scene_file_path, "--", "--ps1-bake-only", "--ps1-bake-force"])
	_pid = OS.create_process(OS.get_executable_path(), args)
	if _pid <= 0:
		push_error("PS1 Bake: could not start the bake process.")
		return
	_button.text = "Baking..."
	_button.disabled = true
	_timer.start()

func _poll() -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		return
	_timer.stop()
	_pid = -1
	_button.text = "PS1 Bake"
	_button.disabled = false
	EditorInterface.get_resource_filesystem().scan()
	print("PS1 Bake: done. Cache files are in res://ps1_bake_cache/.")

# ---------------- painter self-test (developers) ----------------
# godot -e --path . -- --ps1-painter-selftest=res://level.tscn [--ps1-painter-selftest-shot=C:/x.png]
# Opens the scene, selects its PS1GridLevel, picks the first palette piece, paints two cells with
# synthetic mouse events in the real 3D viewport, undoes, prints PASS/FAIL and quits (no save).

func _ready() -> void:
	var scene := ""
	var shot := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ps1-painter-selftest="): scene = a.get_slice("=", 1)
		elif a.begins_with("--ps1-painter-selftest-shot="): shot = a.get_slice("=", 1)
	if scene != "":
		_selftest(scene, shot)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ps1-events-selftest="):
			_events_selftest(a.get_slice("=", 1), shot)
		if a.begins_with("--ps1-paint-selftest="):
			_paint_selftest(a.get_slice("=", 1))
		if a == "--ps1-update-translations":
			(func():
				for i in 10: await get_tree().process_frame
				update_translations()
				get_tree().quit()).call()
		if a.begins_with("--ps1-drop-selftest="):
			_drop_selftest(a.get_slice("=", 1), shot)
		if a.begins_with("--ps1-gen-selftest="):
			_gen_selftest(a.get_slice("=", 1), shot)

func _selftest(scene: String, shot: String) -> void:
	var wait := func(s): await get_tree().create_timer(s).timeout
	await wait.call(4.0)
	EditorInterface.open_scene_from_path(scene)
	await wait.call(3.0)
	var root := EditorInterface.get_edited_scene_root()
	var lvl: PS1GridLevel = root if root is PS1GridLevel else root.find_children("*", "PS1GridLevel", true, false)[0]
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(lvl)
	EditorInterface.edit_node(lvl)
	await wait.call(1.0)
	_painter.edit(lvl)
	await wait.call(4.0)   # thumbnails
	var fails := []
	if _painter._list.item_count == 0:
		fails.append("empty palette")
	var pick := 0
	for i in _painter._list.item_count:
		var path := String(_painter._list.get_item_metadata(i))
		if path.get_file().get_basename() in ["floor", "chao"]:
			pick = i
	_painter._list.select(pick)
	_painter._on_pick(pick)
	# Frame the middle of the level like a user would (select a piece, press F), ceilings hidden.
	var ps := lvl.pieces()
	ps.sort_custom(func(a, b): return a.position.length() < b.position.length())
	var mid: Node3D = ps[ps.size() / 2]
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(mid)
	await wait.call(0.5)
	# "Focus Selection" from the viewport's View menu (found by its shortcut, language-independent).
	var vpc := EditorInterface.get_editor_viewport_3d(0).get_parent()
	while vpc and vpc.get_class() != "Node3DEditorViewport":
		vpc = vpc.get_parent()
	var focused := false
	for pm in (vpc.find_children("*", "PopupMenu", true, false) if vpc else []):
		for i in pm.item_count:
			var sc: Shortcut = pm.get_item_shortcut(i)
			if sc and sc.resource_name.to_lower().contains("focus") and sc.resource_name.to_lower().contains("selection"):
				pm.id_pressed.emit(pm.get_item_id(i))
				focused = true
	print("PS1 SELFTEST focus selection: ", focused)
	# zoom out: mouse wheel on the viewport surface
	var surf: Control = null
	for c in (vpc.find_children("*", "Control", true, false) if vpc else []):
		if c.get_signal_connection_list("gui_input").size() > 0 and c.size.x > 300:
			surf = c
			break
	if surf:
		for i in 9:
			var wh := InputEventMouseButton.new()
			wh.button_index = MOUSE_BUTTON_WHEEL_DOWN; wh.pressed = true; wh.position = surf.size / 2
			surf.gui_input.emit(wh)
			await get_tree().process_frame
	await wait.call(1.0)
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(lvl)
	_painter.edit(lvl)
	_painter._xray.button_pressed = true
	await wait.call(0.5)
	var cam := EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	# an empty pair of cells that is on screen, closest to the screen center
	var vp_size := EditorInterface.get_editor_viewport_3d(0).size
	var c0: Vector3i = mid.get_meta("ps1_cell")
	var target := c0
	var best := INF
	for x in range(c0.x - 25, c0.x + 25):
		for z in range(c0.z - 25, c0.z + 25):
			var a := Vector3i(x, 0, z)
			if not (lvl.pieces_at(a).is_empty() and lvl.pieces_at(a + Vector3i(1, 0, 0)).is_empty()):
				continue
			var w := lvl.to_global(lvl.cell_to_local(a))
			if cam.is_position_behind(w):
				continue
			var sp := cam.unproject_position(w)
			var d := sp.distance_to(Vector2(vp_size) / 2)
			if Rect2(Vector2(vp_size) * 0.15, Vector2(vp_size) * 0.7).has_point(sp) and d < best:
				best = d
				target = a
	var n0 := lvl.pieces().size()
	var p1 := cam.unproject_position(lvl.to_global(lvl.cell_to_local(target)))
	var p2 := cam.unproject_position(lvl.to_global(lvl.cell_to_local(target + Vector3i(1, 0, 0))))
	var mv := InputEventMouseMotion.new(); mv.position = p1
	_painter.input(cam, mv)
	var down := InputEventMouseButton.new(); down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true; down.position = p1
	_painter.input(cam, down)
	var mv2 := InputEventMouseMotion.new(); mv2.position = p2
	_painter.input(cam, mv2)
	var up := InputEventMouseButton.new(); up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false; up.position = p2
	_painter.input(cam, up)
	var n1 := lvl.pieces().size()
	if lvl.auto_wall and _painter._slot_selected() == lvl.auto_floor_slot:
		var ws := lvl._base_slot(lvl.auto_wall)
		var faltando := 0
		for c in [target, target + Vector3i(1, 0, 0)]:
			for r in 4:
				if not lvl._open(c + PS1GridLevel._DIRS[r]) and lvl.pieces_at(c, "%s:%d" % [ws, r]).is_empty():
					faltando += 1
		print("PS1 SELFTEST auto walls: edges without wall = %d" % faltando)
		if faltando > 0:
			fails.append("auto walls: %d closed edges without a wall" % faltando)
	if lvl.pieces_at(target).is_empty() or lvl.pieces_at(target + Vector3i(1, 0, 0)).is_empty():
		fails.append("paint: pieces not at the hovered cells (%s -> %s)" % [target, lvl.pieces_at(target)])
	print("PS1 SELFTEST auto walls: +%d pieces for 2 floor cells" % (n1 - n0))
	print("PS1 SELFTEST palette=%d categories=%d picked=%s pieces %d -> %d" % [_painter._list.item_count,
		_painter._cats.item_count, _painter.selected, n0, n1])
	var vis := lvl.pieces().filter(func(n): return n.is_visible_in_tree()).size()
	print("PS1 SELFTEST cam=%s fwd=%s far=%.0f visible=%d/%d" % [cam.global_position, -cam.global_basis.z, cam.far, vis, lvl.pieces().size()])
	for c in [Vector3i(10, 0, 13), Vector3i(0, 0, 0), Vector3i(20, 0, 27)]:
		var w := lvl.to_global(lvl.cell_to_local(c))
		print("   cell %s world %s screen %s behind=%s" % [c, w, cam.unproject_position(w), cam.is_position_behind(w)])
	var mi: MeshInstance3D = lvl.pieces()[0].find_children("*", "MeshInstance3D", true, false)[0]
	print("   first piece %s mesh=%s mat=%s visible=%s layers=%d" % [lvl.pieces()[0].name, mi.mesh, mi.get_active_material(0), mi.is_visible_in_tree(), mi.layers])
	await wait.call(1.5)
	if shot != "":
		EditorInterface.get_base_control().get_viewport().get_texture().get_image().save_png(shot)
	var ur := get_undo_redo()
	ur.get_history_undo_redo(ur.get_object_history_id(lvl)).undo()
	var n2 := lvl.pieces().size()
	if n2 != n0:
		fails.append("undo: %d pieces, expected %d" % [n2, n0])
	print("PS1 SELFTEST undo -> %d pieces" % n2)
	print("PS1 SELFTEST RESULT: ", "PASS" if fails.is_empty() else "FAIL " + str(fails))
	get_tree().quit()

# ---------------- events panel self-test (developers) ----------------
# godot -e --path . -- --ps1-events-selftest=res://scene.tscn [--ps1-painter-selftest-shot=C:/x.png]
# Adds a temporary PS1Event, builds pages/commands through the panel API (nested If + Choices),
# checks the rows, undoes everything, screenshots, quits without saving.

func _events_selftest(scene: String, shot: String) -> void:
	var fails: Array[String] = []
	for i in 10: await get_tree().process_frame
	EditorInterface.open_scene_from_path(scene)
	for i in 20: await get_tree().process_frame
	var root := EditorInterface.get_edited_scene_root()
	var ev := PS1Event.new()
	ev.name = "SelftestEvent"
	root.add_child(ev)
	ev.owner = root
	var gfx := Node3D.new(); gfx.name = "Glint"; ev.add_child(gfx); gfx.owner = root
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(ev)
	EditorInterface.edit_node(ev)
	for i in 5: await get_tree().process_frame
	_events.edit(ev)
	_events._add_page()
	if ev.pages.size() != 1: fails.append("add page")
	var classes := _events.command_classes()
	var names := classes.map(func(c): return c.menu)
	print("PS1 EVENTS SELFTEST commands: ", ", ".join(names))
	if not names.has("Message/Show Text") or not names.has("Flow/Conditional Branch"): fails.append("command list")
	var t := PS1CmdText.new(); t.speaker = "Old man"; t.text = "Welcome."
	_events.add_command(t)
	var cif := PS1CmdIf.new(); cif.condition.variable = "$taken"; cif.condition.value = 0
	_events._tree.deselect_all()
	_events.add_command(cif)
	# insert inside "Then": select its header row (child 0 of the If row)
	var if_row := _events._tree.get_root().get_child(1)
	if_row.get_child(0).select(0)
	var ch := PS1CmdChoice.new(); ch.question = "Take the flask?"
	_events.add_command(ch)
	var sv := PS1CmdSetVar.new(); sv.variable = "$taken"
	# inside the first choice branch
	_events.refresh()
	var choice_row := _events._tree.get_root().get_child(1).get_child(0).get_child(0)
	choice_row.get_child(0).select(0)
	_events.add_command(sv)
	_events._set_page("graphic", NodePath("Glint"))
	_events._set_page("prompt", "Search")
	var rows := _events.rows()
	print("PS1 EVENTS SELFTEST rows:\n  " + "\n  ".join(rows))
	if ev.pages[0].commands.size() != 2: fails.append("top-level commands = %d" % ev.pages[0].commands.size())
	if cif.then_commands.size() != 1 or cif.then_commands[0] != ch: fails.append("choice not inside Then")
	if ch.branches[0].commands.size() != 1: fails.append("set var not inside branch")
	if not rows[0].contains("Text: [Old man] Welcome."): fails.append("row text")
	make_bottom_panel_item_visible(_events)
	_events.get_parent().get_parent().size.y = 330
	for i in 10: await get_tree().process_frame
	if shot != "":
		await RenderingServer.frame_post_draw
		EditorInterface.get_base_control().get_viewport().get_texture().get_image().save_png(shot)
	var ur := get_undo_redo()
	var undos := 0
	var hist := ur.get_history_undo_redo(ur.get_object_history_id(ev))
	while hist.has_undo() and undos < 20 and ev.pages.size() > 0:
		hist.undo()
		undos += 1
	if ev.pages.size() != 0: fails.append("undo left %d pages" % ev.pages.size())
	print("PS1 EVENTS SELFTEST undo x%d -> pages=%d" % [undos, ev.pages.size()])
	print("PS1 EVENTS SELFTEST RESULT: ", "PASS" if fails.is_empty() else "FAIL " + str(fails))
	get_tree().quit()

# godot -e --path . -- --ps1-paint-selftest=res://scene.tscn : paints the first MeshInstance3D
# via the toolbar menu code, checks the colors, undoes, checks the old mesh is back.
func _paint_selftest(scene: String) -> void:
	for i in 10: await get_tree().process_frame
	EditorInterface.open_scene_from_path(scene)
	for i in 20: await get_tree().process_frame
	var root := EditorInterface.get_edited_scene_root()
	var mi: MeshInstance3D = null
	for m in root.find_children("*", "MeshInstance3D", true, false):
		if not m.has_meta("ps1_no_bake") and m.mesh:
			mi = m
			break
	var fails: Array[String] = []
	var before := mi.mesh
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(mi)
	for i in 3: await get_tree().process_frame   # the selection updates on the next frame
	var n: int = await _paint_selected(1)
	var cols = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	if n == 0 or cols == null or mi.mesh == before: fails.append("paint did nothing")
	var hist := get_undo_redo().get_history_undo_redo(get_undo_redo().get_object_history_id(root))
	hist.undo()
	if mi.mesh != before: fails.append("undo did not restore the mesh")
	print("PS1 PAINT SELFTEST %s: %d vertices; RESULT: %s" % [mi.name, n, "PASS" if fails.is_empty() else "FAIL " + str(fails)])
	get_tree().quit()

# godot -e --path . -- --ps1-gen-selftest=res://level.tscn [--ps1-painter-selftest-shot=PNG]
# Opens the Generate dialog (screenshot), generates every style into the level, undoes back.
func _gen_selftest(scene: String, shot: String) -> void:
	for i in 10: await get_tree().process_frame
	EditorInterface.open_scene_from_path(scene)
	for i in 20: await get_tree().process_frame
	var root := EditorInterface.get_edited_scene_root()
	var lvl: PS1GridLevel = root.find_children("*", "PS1GridLevel", true, false).front() if not root is PS1GridLevel else root
	EditorInterface.edit_node(lvl)
	for i in 5: await get_tree().process_frame
	var fails: Array[String] = []
	var before := lvl.pieces().size()
	_painter.open_generator()
	_painter._gen_dialog.set_options({style = 0, seed = 3, width = 28, depth = 28})
	for i in 10: await get_tree().process_frame
	if shot != "":
		# the dialog may be its own OS window: capture both
		EditorInterface.get_base_control().get_viewport().get_texture().get_image().save_png(shot)
		_painter._gen_dialog.get_texture().get_image().save_png(shot.get_basename() + "_dialog.png")
	if _painter._gen_dialog.map == null or _painter._gen_dialog.map.floor_cells().is_empty():
		fails.append("dialog preview empty")
	_painter._gen_dialog.hide()
	var ur := get_undo_redo()
	var hist := ur.get_history_undo_redo(ur.get_object_history_id(lvl))
	var steps := 0
	for st in PS1LevelGen.STYLE_NAMES.size():
		var r: Array = _painter.generate({style = st, seed = 3, width = 20, depth = 20, clear = true})
		steps += 1
		var now := lvl.pieces().size()
		print("PS1 GEN SELFTEST %s: +%d -%d -> %d pieces" % [PS1LevelGen.STYLE_NAMES[st], r[0], r[1], now])
		if r[0] == 0 or now != r[0]:
			fails.append("%s: level should hold exactly the generated pieces" % PS1LevelGen.STYLE_NAMES[st])
	for i in steps:
		hist.undo()
	if lvl.pieces().size() != before:
		fails.append("undo x%d: %d pieces, expected %d" % [steps, lvl.pieces().size(), before])
	print("PS1 GEN SELFTEST undo x%d -> %d pieces (was %d); RESULT: %s" % [steps, lvl.pieces().size(), before,
		"PASS" if fails.is_empty() else "FAIL " + str(fails)])
	get_tree().quit()

# godot -e --path . -- --ps1-drop-selftest=res://scene.tscn
# Adds a node with a "died" signal, "+ Event" on it (must become ON_SIGNAL "died"), adds commands
# through the panel, checks the panel shows the signal, undoes.
func _drop_selftest(scene: String, shot: String) -> void:
	for i in 10: await get_tree().process_frame
	EditorInterface.open_scene_from_path(scene)
	for i in 20: await get_tree().process_frame
	var root := EditorInterface.get_edited_scene_root()
	var fails: Array[String] = []
	var mon := Node3D.new()
	mon.name = "Monster"
	var gd := GDScript.new()
	gd.source_code = "extends Node3D\nsignal died(who)\n"
	gd.reload()
	mon.set_script(gd)
	root.add_child(mon)
	mon.owner = root
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(mon)
	for i in 3: await get_tree().process_frame
	var ev := add_event_to_selected()
	for i in 5: await get_tree().process_frame
	if ev == null or ev.get_parent() != mon or ev.pages[0].trigger != PS1EventPage.Trigger.ON_SIGNAL or ev.pages[0].signal_name != &"died":
		fails.append("+Event did not make an on-died event")
	_events.edit(ev)
	_events.refresh()
	if not _events._signal.visible or _events._signal.get_item_text(_events._signal.selected) != "died":
		fails.append("panel does not show the signal")
	var ch := PS1CmdChance.new()
	_events.add_command(ch)
	var sp := PS1CmdSpawn.new()
	_events.add_command(sp)
	var total: int = ev.pages[0].commands.size() + ch.then_commands.size()
	if total != 2:
		fails.append("commands not added (%d)" % total)
	make_bottom_panel_item_visible(_events)
	for i in 10: await get_tree().process_frame
	if shot != "":
		EditorInterface.get_base_control().get_viewport().get_texture().get_image().save_png(shot)
	print("PS1 DROP SELFTEST rows: ", _events.rows())
	var ur := get_undo_redo()
	var hist := ur.get_history_undo_redo(ur.get_object_history_id(root))
	for i in 3: hist.undo()
	if ev.get_parent() != null:
		fails.append("undo did not remove the event")
	mon.free()
	print("PS1 DROP SELFTEST RESULT: %s" % ("PASS" if fails.is_empty() else "FAIL " + str(fails)))
	get_tree().quit()
