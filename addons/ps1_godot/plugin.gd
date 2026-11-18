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

func _handles(object: Object) -> bool:
	return object is PS1GridLevel

func _edit(object: Object) -> void:
	if object is PS1GridLevel:
		_painter.edit(object)
	else:
		_painter.release()

func _make_visible(visible: bool) -> void:
	if visible:
		make_bottom_panel_item_visible(_painter_panel)
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
	_button = Button.new()
	_button.text = "PS1 Bake"
	_button.flat = true
	_button.tooltip_text = "Bake the lighting of every PS1BakedLevel in the open scene (saved scene, runs headless)."
	_button.pressed.connect(_bake_pressed)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _button)
	_timer = Timer.new()
	_timer.wait_time = 0.5
	_timer.timeout.connect(_poll)
	add_child(_timer)

func _exit_tree() -> void:
	if _painter_panel:
		remove_control_from_bottom_panel(_painter_panel)
		_painter_panel.queue_free()
	if _painter:
		_painter.release()
		_painter.queue_free()
	if _button:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _button)
		_button.queue_free()

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
