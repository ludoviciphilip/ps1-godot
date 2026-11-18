## "variable OP value" (ints). "$name" = variable local to the event.
@tool
class_name PS1Condition
extends Resource

enum Op { EQUAL, NOT_EQUAL, GREATER_OR_EQUAL, LESS_OR_EQUAL, GREATER, LESS }
const OP_TEXT := ["==", "!=", ">=", "<=", ">", "<"]

@export var variable := "":
	set(v): variable = v; emit_changed()
@export var op := Op.EQUAL:
	set(v): op = v; emit_changed()
@export var value := 1:
	set(v): value = v; emit_changed()

func test(get_var: Callable) -> bool:
	if variable == "":
		return true
	var v: int = get_var.call(variable)
	match op:
		Op.EQUAL: return v == value
		Op.NOT_EQUAL: return v != value
		Op.GREATER_OR_EQUAL: return v >= value
		Op.LESS_OR_EQUAL: return v <= value
		Op.GREATER: return v > value
		_: return v < value

func describe() -> String:
	return "(always)" if variable == "" else "%s %s %d" % [variable, OP_TEXT[op], value]
