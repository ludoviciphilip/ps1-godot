## Random Chance: runs "Then" with the given probability, else "Else" (drop rates, random lines).
@tool
class_name PS1CmdChance
extends PS1Command

@export_range(0.0, 100.0, 0.5) var percent := 50.0:
	set(v): percent = v; emit_changed()
@export var then_commands: Array[PS1Command] = []
@export var has_else := false:
	set(v): has_else = v; emit_changed()
@export var else_commands: Array[PS1Command] = []

func menu_name() -> String: return "Flow/Random Chance"
func color() -> Color: return Color(0.6, 0.8, 1.0)
func describe() -> String: return "Chance %s%%" % str(percent)
func blocks() -> Array:
	var out := [["Then", self, "then_commands"]]
	if has_else:
		out.append(["Else", self, "else_commands"])
	return out
func run(ctx: PS1EventContext) -> void:
	if randf() * 100.0 < percent:
		await ctx.run_list(then_commands)
	elif has_else:
		await ctx.run_list(else_commands)
