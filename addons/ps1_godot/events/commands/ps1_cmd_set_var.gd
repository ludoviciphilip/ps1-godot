## Control Variables: set / add / subtract. Switches are just variables at 0 or 1.
## "$name" = local to this event (e.g. "$taken" for a chest).
@tool
class_name PS1CmdSetVar
extends PS1Command

enum Op { SET, ADD, SUBTRACT }
@export var variable := "":
	set(v): variable = v; emit_changed()
@export var op := Op.SET:
	set(v): op = v; emit_changed()
@export var value := 1:
	set(v): value = v; emit_changed()

func menu_name() -> String: return "Variables/Control Variable"
func color() -> Color: return Color(1.0, 0.6, 0.6)
func describe() -> String:
	return "Var %s %s %d" % [variable, ["=", "+=", "-="][op], value]
func run(ctx: PS1EventContext) -> void:
	var v := ctx.get_var(variable)
	ctx.set_var(variable, value if op == Op.SET else (v + value if op == Op.ADD else v - value))
