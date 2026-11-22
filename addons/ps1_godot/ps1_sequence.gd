## Ordered-sequence puzzle: ring the bells in the right order, pull the levers, light the
## braziers... Each interaction calls step("id"); the node checks it against `order`, keeps the
## progress in an event variable (so it is saved with the game) and tells you what happened.
##
##   var seq := PS1Sequence.new()
##   seq.name = "Bells"
##   seq.order = ["moon", "valley", "dead"]
##   seq.solved_variable = "bells_solved"     # 1 when done (doors can open on it)
##   add_child(seq)
##   match seq.step("valley"):                # or the event command "Puzzle/Sequence Step"
##       PS1Sequence.Result.CORRECT: ...
##
## A wrong step resets the progress (unless reset_on_fail is off); when the wrong step is the
## first one of the order it counts as a fresh start (1 of N), like in most games.
class_name PS1Sequence
extends Node

signal advanced(id: String, progress: int)
signal solved
signal failed(id: String)

enum Result { CORRECT, SOLVED, WRONG, DONE }

@export var order: PackedStringArray = []
## Event variable set to 1 when solved (empty = "<node name>_solved").
@export var solved_variable := ""
## Event variable with the number of correct steps so far (empty = "<solved_variable>_step").
@export var progress_variable := ""
@export var reset_on_fail := true

func _var_solved() -> String:
	return solved_variable if solved_variable != "" else String(name).to_snake_case() + "_solved"

func _var_progress() -> String:
	return progress_variable if progress_variable != "" else _var_solved() + "_step"

func progress() -> int:
	return PS1Events.get_var(_var_progress())

func is_solved() -> bool:
	return PS1Events.get_var(_var_solved()) >= 1

## Which id comes next ("" when solved).
func expected() -> String:
	if is_solved() or order.is_empty():
		return ""
	return order[clampi(progress(), 0, order.size() - 1)]

func reset() -> void:
	PS1Events.set_var(_var_progress(), 0)

func step(id: String) -> Result:
	if is_solved():
		return Result.DONE
	var i := progress()
	if i < order.size() and order[i] == id:
		i += 1
		PS1Events.set_var(_var_progress(), i)
		if i >= order.size():
			PS1Events.set_var(_var_solved(), 1)
			advanced.emit(id, i)
			solved.emit()
			return Result.SOLVED
		advanced.emit(id, i)
		return Result.CORRECT
	if reset_on_fail:
		var restart := not order.is_empty() and order[0] == id
		PS1Events.set_var(_var_progress(), 1 if restart else 0)
		failed.emit(id)
		if restart:
			advanced.emit(id, 1)
			return Result.CORRECT
		return Result.WRONG
	failed.emit(id)
	return Result.WRONG

## The sequence named `node_name` in the current scene (for code that only has the name).
static func find(tree: SceneTree, node_name: String) -> PS1Sequence:
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.find_child(node_name, true, false) as PS1Sequence
