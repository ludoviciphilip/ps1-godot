## Wait N seconds.
@tool
class_name PS1CmdWait
extends PS1Command

@export var seconds := 0.5:
	set(v): seconds = v; emit_changed()

func menu_name() -> String: return "Flow/Wait"
func describe() -> String: return "Wait %.2f s" % seconds
func run(ctx: PS1EventContext) -> void:
	await ctx.event.get_tree().create_timer(seconds).timeout
