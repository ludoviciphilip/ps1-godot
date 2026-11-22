## Puzzle step: sends `step_id` to a PS1Sequence and branches on the answer (right step,
## puzzle solved, wrong step, already solved).
@tool
class_name PS1CmdSequence
extends PS1Command

## The PS1Sequence node (path from the event), or its name anywhere in the scene.
@export var sequence: NodePath:
	set(v): sequence = v; emit_changed()
@export var step_id := "":
	set(v): step_id = v; emit_changed()
@export var correct_commands: Array[PS1Command] = []
@export var solved_commands: Array[PS1Command] = []
@export var wrong_commands: Array[PS1Command] = []
@export var done_commands: Array[PS1Command] = []

func menu_name() -> String: return "Puzzle/Sequence Step"
func color() -> Color: return Color(0.95, 0.85, 0.4)
func describe() -> String: return "Sequence %s <- \"%s\"" % [sequence, step_id]
func blocks() -> Array:
	return [["Correct", self, "correct_commands"], ["Solved", self, "solved_commands"],
		["Wrong", self, "wrong_commands"], ["Already solved", self, "done_commands"]]

func run(ctx: PS1EventContext) -> void:
	var seq := ctx.node(sequence) as PS1Sequence
	if seq == null:
		seq = PS1Sequence.find(ctx.event.get_tree(), String(sequence).get_file())
	if seq == null:
		push_warning("PS1CmdSequence: sequence not found: %s" % sequence)
		return
	match seq.step(step_id):
		PS1Sequence.Result.CORRECT: await ctx.run_list(correct_commands)
		PS1Sequence.Result.SOLVED: await ctx.run_list(solved_commands)
		PS1Sequence.Result.WRONG: await ctx.run_list(wrong_commands)
		PS1Sequence.Result.DONE: await ctx.run_list(done_commands)
