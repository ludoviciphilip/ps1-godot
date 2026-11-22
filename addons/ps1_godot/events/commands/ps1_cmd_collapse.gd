## Cave-in at the event (or a node): rocks fall, dust, camera shake (PS1Collapse).
@tool
class_name PS1CmdCollapse
extends PS1Command

## Node to center it on (empty = the event; for ON_SIGNAL pages, the source, e.g. the boss).
@export var target: NodePath:
	set(v): target = v; emit_changed()
@export var offset := Vector3.ZERO:
	set(v): offset = v; emit_changed()
@export var radius := 8.0:
	set(v): radius = v; emit_changed()
@export var ceiling := 8.0:
	set(v): ceiling = v; emit_changed()
@export var duration := 3.0:
	set(v): duration = v; emit_changed()
@export var rocks := 45:
	set(v): rocks = v; emit_changed()
@export var sound := "":
	set(v): sound = v; emit_changed()
## Wait for the last rock to land before the next command.
@export var wait := true:
	set(v): wait = v; emit_changed()

func menu_name() -> String: return "Scene/Collapse"
func describe() -> String: return "Collapse r=%.1f m, %.1f s%s" % [radius, duration, "" if wait else " (no wait)"]
func color() -> Color: return Color(0.85, 0.65, 0.45)

func run(ctx: PS1EventContext) -> void:
	var at := ctx.source_position()
	if not target.is_empty():
		var n := ctx.node(target)
		if n is Node3D:
			at = (n as Node3D).global_position
	var scene := ctx.event.get_tree().current_scene
	var c := PS1Collapse.new()
	c.radius = radius
	c.ceiling = ceiling
	c.duration = duration
	c.rocks = rocks
	c.sound = sound
	scene.add_child(c)
	c.global_position = at + offset
	if wait:
		await c.finished
