## Conditional Branch: "if variable OP value" -> then / else.
@tool
class_name PS1CmdIf
extends PS1Command

@export var condition: PS1Condition:
	set(v): condition = v; emit_changed()
@export var then_commands: Array[PS1Command] = []
@export var has_else := true:
	set(v): has_else = v; emit_changed()
@export var else_commands: Array[PS1Command] = []

func _init() -> void:
	if condition == null:
		condition = PS1Condition.new()

func menu_name() -> String: return "Flow/Conditional Branch"
func color() -> Color: return Color(0.6, 0.8, 1.0)
func describe() -> String:
	return "If " + (condition.describe() if condition else "(always)")
func blocks() -> Array:
	var out := [["Then", self, "then_commands"]]
	if has_else:
		out.append(["Else", self, "else_commands"])
	return out
func run(ctx: PS1EventContext) -> void:
	if condition == null or condition.test(ctx.get_var):
		await ctx.run_list(then_commands)
	elif has_else:
		await ctx.run_list(else_commands)
