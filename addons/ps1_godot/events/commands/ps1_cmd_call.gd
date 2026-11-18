## Script: calls a method on a node (the bridge to your game code), e.g. target "/root/Game",
## method "give_item", args ["key"]. If the method is a coroutine, the event waits for it.
@tool
class_name PS1CmdCall
extends PS1Command

@export var target: NodePath:
	set(v): target = v; emit_changed()
@export var method := "":
	set(v): method = v; emit_changed()
@export var args: Array = []:
	set(v): args = v; emit_changed()

func menu_name() -> String: return "Advanced/Call Method"
func color() -> Color: return Color(0.8, 0.7, 1.0)
func describe() -> String:
	return "Call %s.%s(%s)" % [target, method, ", ".join(args.map(func(a): return var_to_str(a)))]
func run(ctx: PS1EventContext) -> void:
	var n := ctx.node(target)
	if n == null or not n.has_method(method):
		push_warning("PS1CmdCall: %s has no method %s" % [target, method])
		return
	await n.callv(method, args)
