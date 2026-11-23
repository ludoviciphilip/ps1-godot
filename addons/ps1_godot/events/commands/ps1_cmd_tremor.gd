## The ground shakes: dust and grit sift down from the ceiling, a few pebbles fall, the camera
## shakes (PS1Collapse.tremor). Nothing stays — a warning that the place may give way.
@tool
class_name PS1CmdTremor
extends PS1Command

## Node to center it on (empty = the event).
@export var target: NodePath:
	set(v): target = v; emit_changed()
@export var offset := Vector3.ZERO:
	set(v): offset = v; emit_changed()
@export var radius := 7.0:
	set(v): radius = v; emit_changed()
## Height the dust falls from, above the center.
@export var ceiling := 6.0:
	set(v): ceiling = v; emit_changed()
@export var duration := 2.5:
	set(v): duration = v; emit_changed()
@export var strength := 0.6:
	set(v): strength = v; emit_changed()
@export var sound := "":
	set(v): sound = v; emit_changed()
## Wait until it stops shaking before the next command.
@export var wait := true:
	set(v): wait = v; emit_changed()

func menu_name() -> String: return "Scene/Tremor"
func describe() -> String: return "Tremor r=%.1f m, %.1f s%s" % [radius, duration, "" if wait else " (no wait)"]
func color() -> Color: return Color(0.8, 0.7, 0.55)

func run(ctx: PS1EventContext) -> void:
	var at := ctx.source_position()
	if not target.is_empty():
		var n := ctx.node(target)
		if n is Node3D:
			at = (n as Node3D).global_position
	var scene := ctx.event.get_tree().current_scene
	var c := PS1Collapse.tremor(scene, at + offset, radius, duration, strength, ceiling)
	if sound != "":
		PS1Audio.play(sound, c.global_position + Vector3.UP * 2.0)
	if wait:
		await c.finished
