## Editor side of PS1GridLevel: the "PS1 Pieces" bottom panel (palette with thumbnails) and
## painting in the 3D viewport. Driven by plugin.gd (_handles / _forward_3d_gui_input).
##   LMB paint (drag paints a line) · Shift+LMB erase (same kind of piece) · Ctrl+Shift+LMB erase
##   the whole cell · R rotate · PgUp/PgDn layer · Esc stop painting. Right mouse stays the camera.
##   Walls/doors (pieces with meta ps1_edge) snap to the cell edge nearest the mouse.
@tool
extends Node

const THUMB := 80

var plugin: EditorPlugin
var level: PS1GridLevel
var panel: VBoxContainer
var _cats: OptionButton
var _list: ItemList
var _layer: SpinBox
var _eraser: Button
var _xray: Button
var _auto: Button
var _info: Label
var _paths_by_cat := {}         # category -> Array[String]
var _thumbs := {}               # path -> Texture2D
var _thumb_queue: Array[String] = []
var _thumb_busy := false
var selected := ""              # scene path being painted ("" = not painting)
var rot := 0
var _scene_cache := {}
var _ghost: Node3D
var _lines: MeshInstance3D
var _hover := Vector3i.ZERO
var _hover_rot := 0
var _hover_ok := false
var _stroke := 0                # 0 none, 1 paint, 2 erase
var _stroke_all := false
var _added: Array = []
var _removed: Array = []
var _done := {}

# ---------------- panel ----------------

func build_panel() -> Control:
	panel = VBoxContainer.new()
	panel.name = "PS1 Pieces"
	panel.custom_minimum_size = Vector2(0, 190)
	var bar := HBoxContainer.new()
	panel.add_child(bar)
	_cats = OptionButton.new()
	_cats.tooltip_text = "Piece category (sub-folder of the palette folder)"
	_cats.item_selected.connect(func(_i): _fill_list())
	bar.add_child(_cats)
	var l := Label.new(); l.text = "  Layer"; bar.add_child(l)
	_layer = SpinBox.new()
	_layer.min_value = -20; _layer.max_value = 40; _layer.step = 1
	_layer.tooltip_text = "Floor level you paint on (PgUp / PgDn)"
	_layer.value_changed.connect(func(_v): _update_preview())
	bar.add_child(_layer)
	_eraser = Button.new()
	_eraser.text = "Eraser"
	_eraser.toggle_mode = true
	_eraser.tooltip_text = "LMB erases instead of painting (same as Shift+LMB)"
	bar.add_child(_eraser)
	_auto = Button.new()
	_auto.text = "Auto walls"
	_auto.toggle_mode = true
	_auto.button_pressed = true
	_auto.tooltip_text = "Painting/erasing floors adds/removes walls (and ceilings) automatically.\nSet auto_wall / auto_ceiling on the PS1GridLevel."
	bar.add_child(_auto)
	_xray = Button.new()
	_xray.text = "Hide ceilings"
	_xray.toggle_mode = true
	_xray.tooltip_text = "Hide the pieces in the level's xray_slots (ceilings) while editing"
	_xray.toggled.connect(func(_on): apply_xray())
	bar.add_child(_xray)
	var reload := Button.new()
	reload.text = "Rescan"
	reload.tooltip_text = "Reload the palette folders (after adding or editing pieces)"
	reload.pressed.connect(func(): _thumbs.clear(); scan())
	bar.add_child(reload)
	var gen := Button.new()
	gen.text = "Generate..."
	gen.tooltip_text = "Generate a dungeon, catacombs, caves, a maze or ruins procedurally (undoable).\nPieces come from the level's gen_theme (empty = starter pieces + auto walls)."
	gen.pressed.connect(open_generator)
	bar.add_child(gen)
	var test := Button.new()
	test.text = "Test here"
	test.tooltip_text = "Save and run this scene with the player starting at the hovered cell"
	test.pressed.connect(_test_here)
	bar.add_child(test)
	_info = Label.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info.modulate = Color(1, 1, 1, 0.7)
	bar.add_child(_info)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.max_columns = 0
	_list.icon_mode = ItemList.ICON_MODE_TOP
	_list.fixed_icon_size = Vector2i(THUMB, THUMB)
	_list.fixed_column_width = THUMB + 16
	_list.same_column_width = true
	_list.item_selected.connect(_on_pick)
	panel.add_child(_list)
	_set_info()
	return panel

func _set_info() -> void:
	if _info:
		_info.text = ("Painting: %s  ·  rot %d°  ·  " % [selected.get_file().get_basename(), rot * 90] if selected != "" else "Pick a piece  ·  ") + \
			"LMB paint · Shift+LMB erase · R rotate · PgUp/PgDn layer · Esc stop"

## Scans the level's palette folders. Category = first sub-folder ("1_walls" -> "walls").
func scan() -> void:
	_paths_by_cat.clear()
	if level == null:
		return
	for root in level.palette_dirs:
		_scan_dir(root, root)
	_cats.clear()
	var keys := _paths_by_cat.keys()
	keys.sort()
	for k in keys:
		_cats.add_item(_pretty(k))
		_cats.set_item_metadata(_cats.item_count - 1, k)
	_fill_list()

func _scan_dir(root: String, dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.get_extension() in ["tscn", "scn", "glb", "gltf"]:
			var rel := dir.trim_prefix(root).trim_prefix("/")
			var cat := rel.split("/")[0] if rel != "" else "pieces"
			if not _paths_by_cat.has(cat):
				_paths_by_cat[cat] = []
			_paths_by_cat[cat].append(dir.path_join(f))
	for sub in d.get_directories():
		if not sub.begins_with("."):
			_scan_dir(root, dir.path_join(sub))

static func _pretty(cat: String) -> String:
	var i := 0
	while i < cat.length() and (cat[i].is_valid_int() or cat[i] == "_"):
		i += 1
	return cat.substr(i).capitalize() if i < cat.length() else cat

func _fill_list() -> void:
	_list.clear()
	if _cats.selected < 0:
		return
	var paths: Array = _paths_by_cat[_cats.get_item_metadata(_cats.selected)]
	paths.sort()
	for p in paths:
		var idx := _list.add_item(p.get_file().get_basename().replace("_", " "), _thumbs.get(p, null))
		_list.set_item_metadata(idx, p)
		_list.set_item_tooltip(idx, p)
		if p == selected:
			_list.select(idx)
		if not _thumbs.has(p) and not p in _thumb_queue:
			_thumb_queue.append(p)
	_next_thumb()

func _on_pick(idx: int) -> void:
	selected = _list.get_item_metadata(idx)
	_rebuild_ghost()
	_set_info()

func stop_painting() -> void:
	selected = ""
	if _list:
		_list.deselect_all()
	_clear_ghost()
	_set_info()

# ---------------- thumbnails (own renderer: works for scenes saved from code too) ----------------

func _next_thumb() -> void:
	if _thumb_busy or _thumb_queue.is_empty() or not is_inside_tree():
		return
	_thumb_busy = true
	var path: String = _thumb_queue.pop_front()
	var tex := await _render_thumb(path)
	_thumbs[path] = tex
	for i in _list.item_count:
		if _list.get_item_metadata(i) == path:
			_list.set_item_icon(i, tex)
	_thumb_busy = false
	_next_thumb()

func _render_thumb(path: String) -> Texture2D:
	var scene := _scene(path)
	if scene == null:
		return null
	var vp := SubViewport.new()
	vp.size = Vector2i(THUMB * 2, THUMB * 2)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	vp.add_child(sun)
	var n := scene.instantiate()
	vp.add_child(n)
	var cam := Camera3D.new()
	vp.add_child(cam)
	add_child(vp)
	await get_tree().process_frame
	var box := _aabb(n)
	var c := box.get_center()
	var r := maxf(box.size.length() * 0.5, 0.3)
	cam.fov = 35.0
	cam.look_at_from_position(c + Vector3(1.0, 0.8, 1.2).normalized() * r / tan(deg_to_rad(cam.fov * 0.5)), c)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	img.resize(THUMB, THUMB, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

static func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	var all: Array = n.find_children("*", "VisualInstance3D", true, false)
	if n is VisualInstance3D:
		all.append(n)
	for v in all:
		if v is Light3D:
			continue
		var b: AABB = (v as VisualInstance3D).global_transform * (v as VisualInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box if not first else AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))

func _scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path) as PackedScene
	return _scene_cache[path]

## Editor-only visibility: hidden pieces are restored when the level is released or saved
## (the plugin calls apply_xray(false) before saving).
func apply_xray(force := true) -> void:
	if level == null:
		return
	var on := force and _xray and _xray.button_pressed
	for p in level.pieces():
		var slot := String(p.get_meta("ps1_slot", ""))
		if slot in level.xray_slots:
			p.visible = not on

# ---------------- viewport ----------------

func edit(l: PS1GridLevel) -> void:
	if level == l:
		return
	_clear_ghost()
	level = l
	if level:
		_layer.value = 0
		scan()
		apply_xray()
		if selected != "":
			_rebuild_ghost()  # coming back to the level with a piece still picked

func release() -> void:
	apply_xray(false)
	_clear_ghost()
	_clear_lines()
	level = null

func _rebuild_ghost() -> void:
	_clear_ghost()
	if level == null or selected == "":
		return
	var s := _scene(selected)
	if s == null:
		return
	_ghost = s.instantiate() as Node3D
	level.add_child(_ghost, false, Node.INTERNAL_MODE_BACK)
	_ghost.visible = false
	_update_preview()

func _clear_ghost() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null

func _clear_lines() -> void:
	if is_instance_valid(_lines):
		_lines.queue_free()
	_lines = null

func _is_edge() -> bool:
	return is_instance_valid(_ghost) and _ghost.get_meta("ps1_edge", false)

func _slot_selected() -> String:
	if not is_instance_valid(_ghost) and selected != "" and level:
		_rebuild_ghost()
	if not is_instance_valid(_ghost):
		return ""
	var s := String(_ghost.get_meta("ps1_slot", "prop"))
	return s + (":%d" % _hover_rot if _is_edge() else "")

## Mouse -> cell on the current layer plane (and the nearest edge, for edge pieces).
func _pick(camera: Camera3D, pos: Vector2) -> bool:
	var from := level.to_local(camera.project_ray_origin(pos))
	var dir := level.global_basis.inverse() * camera.project_ray_normal(pos)
	var h := int(_layer.value) * level.layer_height
	if absf(dir.y) < 1e-5:
		return false
	var t := (h - from.y) / dir.y
	if t < 0.0:
		return false
	var p := from + dir * t
	var cs := level.cell_size
	_hover = Vector3i(floori(p.x / cs + 0.5), int(_layer.value), floori(p.z / cs + 0.5))
	var off := Vector2(p.x / cs - _hover.x, p.z / cs - _hover.z)
	if absf(off.y) >= absf(off.x):
		_hover_rot = 0 if off.y < 0.0 else 2
	else:
		_hover_rot = 1 if off.x > 0.0 else 3
	if not _is_edge():
		_hover_rot = rot
	return true

func _update_preview() -> void:
	if level == null:
		return
	if is_instance_valid(_ghost):
		_ghost.visible = _hover_ok and not _erasing()
		_ghost.position = level.cell_to_local(_hover)
		_ghost.rotation.y = -_hover_rot * PI / 2.0
	_draw_lines()

func _erasing() -> bool:
	return _stroke == 2 or (_eraser and _eraser.button_pressed) or Input.is_key_pressed(KEY_SHIFT)

func _draw_lines() -> void:
	if not is_instance_valid(_lines):
		_lines = MeshInstance3D.new()
		_lines.mesh = ImmediateMesh.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = false
		_lines.material_override = m
		_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		level.add_child(_lines, false, Node.INTERNAL_MODE_BACK)
	var im := _lines.mesh as ImmediateMesh
	im.clear_surfaces()
	if not _hover_ok or selected == "" and not (_eraser and _eraser.button_pressed):
		return
	var cs := level.cell_size
	var y := _hover.y * level.layer_height + 0.02
	var n := 6
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var gc := Color(0.6, 0.85, 1.0, 0.35)
	for i in range(-n, n + 2):
		var a := (_hover.x + i - 0.5) * cs
		var b := (_hover.z + i - 0.5) * cs
		im.surface_set_color(gc); im.surface_add_vertex(Vector3(a, y, (_hover.z - n - 0.5) * cs))
		im.surface_set_color(gc); im.surface_add_vertex(Vector3(a, y, (_hover.z + n + 0.5) * cs))
		im.surface_set_color(gc); im.surface_add_vertex(Vector3((_hover.x - n - 0.5) * cs, y, b))
		im.surface_set_color(gc); im.surface_add_vertex(Vector3((_hover.x + n + 0.5) * cs, y, b))
	# cursor: cell square (or the chosen edge), red when erasing
	var cc := Color(1.0, 0.3, 0.25) if _erasing() else Color(1.0, 0.75, 0.2)
	var x0 := (_hover.x - 0.5) * cs; var x1 := (_hover.x + 0.5) * cs
	var z0 := (_hover.z - 0.5) * cs; var z1 := (_hover.z + 0.5) * cs
	var pts := [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]
	for k in 4:
		var col := cc
		if _is_edge():
			# highlight the edge the piece will sit on (0 = -Z, 1 = +X, 2 = +Z, 3 = -X)
			col = cc if k == _hover_rot else Color(cc, 0.25)
		for e in [pts[k], pts[(k + 1) % 4]]:
			for dy in [0.0, 0.05]:
				im.surface_set_color(col); im.surface_add_vertex(e + Vector3(0, dy, 0))
	im.surface_end()

## Returns true when the event was used (plugin then stops it).
func input(camera: Camera3D, event: InputEvent) -> bool:
	if level == null:
		return false
	var painting := selected != "" or (_eraser and _eraser.button_pressed)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				if selected != "":
					rot = posmod(rot + (-1 if event.shift_pressed else 1), 4)
					_hover_rot = rot if not _is_edge() else _hover_rot
					_set_info(); _update_preview()
					return true
			KEY_PAGEUP:
				_layer.value += 1; return painting
			KEY_PAGEDOWN:
				_layer.value -= 1; return painting
			KEY_ESCAPE:
				if painting:
					_eraser.button_pressed = false
					stop_painting(); _update_preview()
					return true
		return false
	if not painting:
		return false
	if event is InputEventMouseMotion:
		var old := [_hover, _hover_rot]
		_hover_ok = _pick(camera, event.position)
		if _stroke != 0 and _hover_ok and [_hover, _hover_rot] != old:
			_apply()
		_update_preview()
		return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_hover_ok = _pick(camera, event.position)
			if not _hover_ok:
				return false
			_stroke = 2 if (event.shift_pressed or _eraser.button_pressed) else 1
			_stroke_all = event.ctrl_pressed or selected == ""
			_added.clear(); _removed.clear(); _done.clear()
			_apply()
			_update_preview()
		else:
			if _stroke != 0:
				_commit()
			_stroke = 0
			_update_preview()
		return true
	return false

func _apply() -> void:
	var key := [_hover, _hover_rot]
	if _done.has(key):
		return
	_done[key] = true
	var root := EditorInterface.get_edited_scene_root()
	if _stroke == 1:
		var s := _scene(selected)
		for p in level.pieces_at(_hover, _slot_selected()):
			if p.get_meta("ps1_scene", "") == selected and int(p.get_meta("ps1_rot", 0)) == _hover_rot:
				return  # already there
		var r := level.place(s, _hover, _hover_rot, root)
		_added.append(r[0])
		_note_removed(r[1])
	else:
		_note_removed(level.erase(_hover, "" if _stroke_all else _slot_selected()))
	if _auto.button_pressed and (_stroke_all or _slot_selected() == level.auto_floor_slot or selected == ""):
		var a := level.update_auto([_hover], root)
		_added.append_array(a[0])
		_note_removed(a[1])
	if _xray.button_pressed:
		for n in _added:
			if String(n.get_meta("ps1_slot", "")) in level.xray_slots:
				n.visible = false

## A piece added earlier in this same stroke and removed again just disappears (no undo entry).
func _note_removed(nodes: Array) -> void:
	for n in nodes:
		if n in _added:
			_added.erase(n)
			n.queue_free()
		else:
			_removed.append(n)

## Already applied while dragging: register one undo step for the whole stroke.
func _commit() -> void:
	if _added.is_empty() and _removed.is_empty():
		return
	var ur := plugin.get_undo_redo()
	var root := EditorInterface.get_edited_scene_root()
	ur.create_action("PS1: %s %d piece(s)" % ["paint" if _stroke == 1 else "erase", maxi(_added.size(), _removed.size())],
		UndoRedo.MERGE_DISABLE, level)
	for n in _removed:
		ur.add_do_method(level, "remove_child", n)
	for n in _added:
		ur.add_do_method(level, "add_piece", n, root)
		ur.add_do_reference(n)
	for n in _added:
		ur.add_undo_method(level, "remove_child", n)
	for n in _removed:
		ur.add_undo_method(level, "add_piece", n, root)
		ur.add_undo_reference(n)
	ur.commit_action(false)
	_added = []; _removed = []

# ---------------- procedural generation ----------------

const GenDialog := preload("res://addons/ps1_godot/editor/ps1_gen_dialog.gd")
var _gen_dialog: ConfirmationDialog

func open_generator() -> void:
	if level == null:
		return
	if _gen_dialog == null:
		_gen_dialog = GenDialog.new()
		_gen_dialog.generate_requested.connect(func(o): generate(o))
		EditorInterface.get_base_control().add_child(_gen_dialog)
	_gen_dialog.popup_centered()

## Generates into the edited level as ONE undo step. Returns [added, removed] counts.
func generate(options: Dictionary) -> Array:
	var root := EditorInterface.get_edited_scene_root()
	var map := PS1LevelGen.generate(options)
	var theme: PS1GenTheme = level.gen_theme if level.gen_theme else PS1GenTheme.starter(level)
	var r := map.build(level, theme, int(_layer.value), Vector2i.ZERO, options.get("clear", true), root)
	var added: Array = r[0]
	var removed: Array = r[1]
	var ur := plugin.get_undo_redo()
	ur.create_action("PS1: generate %s (%d pieces)" % [PS1LevelGen.STYLE_NAMES[map.style], added.size()], UndoRedo.MERGE_DISABLE, level)
	for n in removed:
		ur.add_do_method(level, "remove_child", n)
	for n in added:
		ur.add_do_method(level, "add_piece", n, root)
		ur.add_do_reference(n)
	for n in added:
		ur.add_undo_method(level, "remove_child", n)
	for n in removed:
		ur.add_undo_method(level, "add_piece", n, root)
		ur.add_undo_reference(n)
	ur.commit_action(false)
	apply_xray()
	print("PS1: generated %s %dx%d seed %d: +%d / -%d pieces" % [PS1LevelGen.STYLE_NAMES[map.style], map.size.x, map.size.y,
		map.map_seed, added.size(), removed.size()])
	return [added.size(), removed.size()]

func release_generator() -> void:
	if _gen_dialog:
		_gen_dialog.queue_free()
		_gen_dialog = null

# ---------------- test from here ----------------

func _test_here() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null or level == null:
		return
	if root.scene_file_path == "":
		push_warning("PS1: save the scene first.")
		return
	var cam := EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	var f := -cam.global_basis.z
	var pos := level.to_global(level.cell_to_local(_hover)) if _hover_ok else cam.global_position
	# Same file/format PS1.take_test_spawn() reads (the PS1 autoload doesn't run inside the editor).
	var fa := FileAccess.open("user://ps1_test_spawn.json", FileAccess.WRITE)
	if fa:
		var p := pos + Vector3(0, 0.1, 0)
		fa.store_string(JSON.stringify({scene = root.scene_file_path, pos = [p.x, p.y, p.z],
			yaw = atan2(-f.x, -f.z), time = Time.get_unix_time_from_system()}))
		fa.close()
	EditorInterface.save_scene()
	EditorInterface.play_current_scene()
