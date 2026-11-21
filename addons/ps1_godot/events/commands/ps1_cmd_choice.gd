## Show Choices: options in a box; runs the branch the player picked. Cancel picks `cancel_branch`
## (-1 = cancel not allowed).
@tool
class_name PS1CmdChoice
extends PS1Command

@export_multiline var question := "":
	set(v): question = v; emit_changed()
@export var branches: Array[PS1Branch] = []:
	set(v): branches = v; emit_changed()
@export var cancel_branch := -1

func _init() -> void:
	if branches.is_empty():
		for l in ["Yes", "No"]:
			var b := PS1Branch.new()
			b.label = l
			branches.append(b)

func menu_name() -> String: return "Message/Show Choices"
func color() -> Color: return Color(0.95, 0.85, 0.5)
func describe() -> String:
	return "Choices: " + (question.replace("\n", " ") + "  " if question != "" else "") + " / ".join(branches.map(func(b): return "[%s]" % b.label))
func blocks() -> Array:
	var out := []
	for i in branches.size():
		out.append(["When [%s]" % branches[i].label, branches[i], "commands"])
	return out
func run(ctx: PS1EventContext) -> void:
	var labels := PackedStringArray(branches.map(func(b): return PS1Locale.t(b.label)))
	var i: int = await PS1Events.dialog().choose(PS1CmdText.format(PS1Locale.t(question), ctx), labels, cancel_branch)
	if i >= 0 and i < branches.size():
		await ctx.run_list(branches[i].commands)
