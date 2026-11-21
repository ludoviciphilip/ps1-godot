## Spawn Scene: instances a scene where the event's source is (a defeated monster), at the event,
## at the actor or at a node: item drops, loot piles, effects, reinforcements...
## Drops are usually a PS1Event scene themselves ("Pick up" -> give the item -> Delete this event).
## Combine with Random Chance for drop rates.
@tool
class_name PS1CmdSpawn
extends PS1Command

enum At { SOURCE, EVENT, ACTOR, NODE }
@export var scene: PackedScene:
	set(v): scene = v; emit_changed()
@export var at := At.SOURCE:
	set(v): at = v; emit_changed()
## At = NODE: where.
@export var node: NodePath
@export var offset := Vector3.ZERO
@export_range(1, 50) var count := 1:
	set(v): count = v; emit_changed()
## Random spread radius (meters) when spawning several.
@export var scatter := 0.6
## Pops up and falls back to the ground (loot feel).
@export var bounce := true

func menu_name() -> String: return "Scene/Spawn Scene (drop)"
func color() -> Color: return Color(0.7, 1.0, 0.7)
func describe() -> String:
	return "Spawn %s%s at %s" % ["%dx " % count if count > 1 else "",
		scene.resource_path.get_file().get_basename() if scene else "(no scene)", At.keys()[at].to_lower()]

func run(ctx: PS1EventContext) -> void:
	if scene == null:
		return
	var pos := ctx.event.global_position
	match at:
		At.SOURCE: pos = ctx.source_position()
		At.ACTOR: if ctx.actor is Node3D: pos = (ctx.actor as Node3D).global_position
		At.NODE:
			var n := ctx.node(node)
			if n is Node3D: pos = (n as Node3D).global_position
	var tree := ctx.event.get_tree()
	var parent: Node = tree.current_scene if tree.current_scene else ctx.event.get_parent()
	for i in count:
		var inst := scene.instantiate()
		var p := pos + offset
		if count > 1 or scatter > 0.0 and i > 0:
			var a := randf() * TAU
			p += Vector3(cos(a), 0, sin(a)) * scatter * sqrt(randf())
		parent.add_child(inst)
		if inst is Node3D:
			var n3 := inst as Node3D
			n3.global_position = p
			if bounce:
				var tw := n3.create_tween()
				tw.tween_property(n3, "global_position:y", p.y + 0.8, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
				tw.tween_property(n3, "global_position:y", p.y, 0.32).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
