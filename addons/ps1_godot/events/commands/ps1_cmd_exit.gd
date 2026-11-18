## Exit Event Processing: stops the event here.
@tool
class_name PS1CmdExit
extends PS1Command

func menu_name() -> String: return "Flow/Exit Event"
func color() -> Color: return Color(0.6, 0.8, 1.0)
func describe() -> String: return "Exit event"
func run(ctx: PS1EventContext) -> void:
	ctx.stopped = true
