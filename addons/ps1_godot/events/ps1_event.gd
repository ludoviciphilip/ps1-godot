## RPG Maker style event: pages (condition + trigger + command list), edited in the
## "PS1 Events" bottom panel. Triggers: INTERACT (the game calls interact()), TOUCH (actor in the
## "player" group enters the box), AUTORUN (when the page becomes active), ON_SIGNAL (a node
## emits a signal, e.g. the parent monster's "died": an "on defeated" event).
## Game hookup (once): put the player in the "player" group, call `interact(player)` when the
## interact button is pressed near a node of group "ps1_interactable" whose can_interact() is true,
## and freeze the player on PS1Events.signals().event_started / event_finished.
@tool
@icon("res://addons/ps1_godot/icons/event.svg")
class_name PS1Event
extends Node3D

signal finished

@export var pages: Array[PS1EventPage] = []:
	set(v):
		pages = v
		_refresh_editor()
@export var interact_radius := 1.8
@export var touch_size := Vector3(2, 2.5, 2)
@export var actor_group := "player"

var running := false
var page: PS1EventPage
var _area: Area3D

func _ready() -> void:
	if Engine.is_editor_hint():
		_refresh_editor()
		return
	add_to_group("ps1_interactable")
	PS1Events.signals().var_changed.connect(func(_n, _v): _update_page())
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = 0xFFFFFFFF
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = touch_size
	cs.shape = box
	cs.position.y = touch_size.y / 2.0
	_area.add_child(cs)
	add_child(_area)
	_area.body_entered.connect(_on_body)
	_update_page.call_deferred()
	_connect_signals.call_deferred()

## ON_SIGNAL pages: listen to their source nodes (each signal once, whatever its argument count).
func _connect_signals() -> void:
	var done := {}
	for i in pages.size():
		var p := pages[i]
		if p == null or p.trigger != PS1EventPage.Trigger.ON_SIGNAL or p.signal_name == &"":
			continue
		var src := get_node_or_null(p.signal_source)
		if src == null or not src.has_signal(p.signal_name):
			push_warning("PS1Event %s: no signal '%s' on %s" % [name, p.signal_name, p.signal_source])
			continue
		var key := "%s|%s" % [src.get_instance_id(), p.signal_name]
		if done.has(key):
			continue
		done[key] = true
		var argc := 0
		for sig in src.get_signal_list():
			if sig.name == p.signal_name:
				argc = sig.args.size()
		var sname: StringName = p.signal_name
		var f: Callable
		match argc:
			0: f = func(): _on_signal(src, sname, null)
			1: f = func(a): _on_signal(src, sname, a)
			2: f = func(a, _b): _on_signal(src, sname, a)
			3: f = func(a, _b, _c): _on_signal(src, sname, a)
			_: f = func(a, _b, _c, _d): _on_signal(src, sname, a)
		src.connect(sname, f)

func _on_signal(src: Node, sname: StringName, arg) -> void:
	if page == null or page.trigger != PS1EventPage.Trigger.ON_SIGNAL or page.signal_name != sname:
		return
	if get_node_or_null(page.signal_source) != src:
		return
	run(null, page, arg if arg is Node else src)

## Key of a "$local" variable: unique per scene + node path.
func local_key(name: String) -> String:
	var scene := get_tree().current_scene.scene_file_path.get_file().get_basename() if get_tree().current_scene else ""
	var path := str(get_tree().current_scene.get_path_to(self)) if get_tree().current_scene else str(name)
	return "%s/%s:%s" % [scene, path, name.trim_prefix("$")]

func active_page() -> PS1EventPage:
	var gv := func(n: String): return PS1Events.get_var(local_key(n) if n.begins_with("$") else n)
	for i in range(pages.size() - 1, -1, -1):
		if pages[i] and pages[i].is_active(gv):
			return pages[i]
	return null

func _update_page() -> void:
	var old := page
	page = active_page()
	for p in pages:
		if p and not p.graphic.is_empty():
			var g := get_node_or_null(p.graphic)
			if g: g.visible = false
	if page and not page.graphic.is_empty():
		var g := get_node_or_null(page.graphic)
		if g: g.visible = true
	if page != old and page and page.trigger == PS1EventPage.Trigger.AUTORUN:
		run.call_deferred()

func can_interact(actor: Node) -> bool:
	if running or page == null or page.trigger != PS1EventPage.Trigger.INTERACT:
		return false
	return actor is Node3D and (actor as Node3D).global_position.distance_to(global_position) <= interact_radius

func prompt_text() -> String:
	return page.prompt if page else ""

func interact(actor: Node) -> void:
	if can_interact(actor):
		run(actor)

func _on_body(body: Node) -> void:
	if page and page.trigger == PS1EventPage.Trigger.TOUCH and body.is_in_group(actor_group) and not running:
		run(body)

## Runs the active page (or `with_page`). Awaitable. source = what triggered it (signal pages).
func run(actor: Node = null, with_page: PS1EventPage = null, source: Node = null) -> void:
	var p := with_page if with_page else page
	if p == null or running:
		return
	running = true
	PS1Events._started()
	var ctx := PS1EventContext.new()
	ctx.event = self
	ctx.actor = actor
	ctx.source = source
	await ctx.run_list(p.commands)
	running = false
	PS1Events._finished()
	finished.emit()
	_update_page()

# ---------------- editor marker ----------------

func _refresh_editor() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	for c in get_children(true):
		if c.has_meta("ps1_event_marker"):
			c.queue_free()
	var l := Label3D.new()
	l.set_meta("ps1_event_marker", true)
	l.set_meta("ps1_no_bake", true)
	var sig := ""
	for p in pages:
		if p and p.trigger == PS1EventPage.Trigger.ON_SIGNAL:
			sig = "\non %s" % p.signal_name
	l.text = "EV " + name + ("\n%d page(s)" % pages.size() if pages.size() != 1 else "") + sig
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 40
	l.pixel_size = 0.006
	l.modulate = Color(0.45, 0.85, 1.0)
	l.position.y = 1.6
	add_child(l, false, Node.INTERNAL_MODE_BACK)
	var box := MeshInstance3D.new()
	box.set_meta("ps1_event_marker", true)
	box.set_meta("ps1_no_bake", true)
	var bm := BoxMesh.new()
	bm.size = Vector3(1.6, 0.05, 1.6)
	box.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.75, 1.0, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material_override = m
	box.position.y = 0.03
	add_child(box, false, Node.INTERNAL_MODE_BACK)

## Signals of `node` worth listening to (script signals first), e.g. for the editor dropdown.
static func signals_of(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if node == null:
		return out
	if node.get_script():
		for sig in (node.get_script() as Script).get_script_signal_list():
			if not sig.name in out:
				out.append(sig.name)
	for sig in node.get_signal_list():
		if not sig.name in out and sig.name in ["body_entered", "area_entered", "tree_exiting", "visibility_changed", "animation_finished", "timeout", "finished"]:
			out.append(sig.name)
	return out

## Best guess for an "on defeated" signal of `node` ("" if none).
static func death_signal_of(node: Node) -> String:
	for s in signals_of(node):
		var l := s.to_lower()
		for k in ["defeat", "died", "death", "die", "killed", "dead", "morreu", "derrot", "morte"]:
			if l.contains(k):
				return s
	return ""
