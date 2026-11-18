## Global state of the event system: variables (ints; switches are 0/1), signals for the game
## to freeze the player while an event runs, and the default dialog box.
## Variables live for the whole session (scene changes included); save them with `PS1Events.vars`.
class_name PS1Events
extends RefCounted

static var vars := {}
static var running := 0
static var _signals: PS1EventSignals
static var _dialog: PS1DialogBox

static func signals() -> PS1EventSignals:
	if _signals == null:
		_signals = PS1EventSignals.new()
	return _signals

static func get_var(name: String) -> int:
	return int(vars.get(name, 0))

static func set_var(name: String, value: int) -> void:
	if vars.get(name, 0) == value and vars.has(name):
		return
	vars[name] = value
	signals().var_changed.emit(name, value)

static func reset() -> void:
	vars = {}
	signals().var_changed.emit("", 0)

## Default text box (created on first use, lives on the root so it survives scene changes).
static func dialog() -> PS1DialogBox:
	if not is_instance_valid(_dialog):
		_dialog = PS1DialogBox.new()
		var tree := Engine.get_main_loop() as SceneTree
		tree.root.add_child(_dialog)
	return _dialog

static func _started() -> void:
	running += 1
	if running == 1:
		signals().event_started.emit()

static func _finished() -> void:
	running = maxi(running - 1, 0)
	if running == 0:
		signals().event_finished.emit()
