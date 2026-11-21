## What a running event knows: the event, who triggered it, and how to run nested lists.
class_name PS1EventContext
extends RefCounted

var event: PS1Event
var actor: Node
## What triggered an ON_SIGNAL page (the defeated monster...); null otherwise.
var source: Node
var stopped := false

func run_list(list: Array) -> void:
	for cmd in list:
		if stopped or not is_instance_valid(event):
			return
		if cmd == null:
			continue
		await cmd.run(self)

## Variable names starting with "$" are local to the event (RPG Maker "self switches").
func var_key(name: String) -> String:
	return event.local_key(name) if name.begins_with("$") else name

func get_var(name: String) -> int:
	return PS1Events.get_var(var_key(name))

func set_var(name: String, value: int) -> void:
	PS1Events.set_var(var_key(name), value)

func node(path: NodePath) -> Node:
	if path.is_empty():
		return event
	return event.get_node_or_null(path)

## Where things happen for this run: the source (signal events), else the event.
func source_position() -> Vector3:
	if is_instance_valid(source) and source is Node3D:
		return (source as Node3D).global_position
	return event.global_position
