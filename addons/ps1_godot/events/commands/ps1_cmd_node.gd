## Node: show / hide / enable / disable collisions / delete a node (doors, bridges, walls...).
## Empty path = the event itself. MOVE_TO_SOURCE puts the node where the event's source is
## (signal events: where the monster fell).
@tool
class_name PS1CmdNode
extends PS1Command

enum Action { SHOW, HIDE, DELETE, ENABLE_COLLISION, DISABLE_COLLISION, MOVE_TO_SOURCE }
@export var target: NodePath:
	set(v): target = v; emit_changed()
@export var action := Action.HIDE:
	set(v): action = v; emit_changed()

func menu_name() -> String: return "Scene/Node"
func color() -> Color: return Color(0.7, 1.0, 0.7)
func describe() -> String:
	return "%s %s" % [["Show", "Hide", "Delete", "Enable collision", "Disable collision", "Move to source:"][action], target if not target.is_empty() else "(this event)"]
func run(ctx: PS1EventContext) -> void:
	var n := ctx.node(target)
	if n == null:
		push_warning("PS1CmdNode: node not found: %s" % target)
		return
	match action:
		Action.SHOW, Action.HIDE:
			if n is Node3D or n is CanvasItem:
				n.visible = action == Action.SHOW
		Action.DELETE:
			n.queue_free()
		Action.MOVE_TO_SOURCE:
			if n is Node3D:
				var p := ctx.source_position()
				(n as Node3D).global_position = Vector3(p.x, (n as Node3D).global_position.y, p.z)
		_:
			for c in [n] + n.find_children("*", "CollisionShape3D", true, false):
				if c is CollisionShape3D:
					c.set_deferred("disabled", action == Action.DISABLE_COLLISION)
