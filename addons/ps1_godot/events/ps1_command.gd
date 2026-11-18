## Base of every event command (RPG Maker style). Subclass it with a class_name in your project
## and it shows up in the "Add command" menu of the PS1 Events panel automatically.
##   run(ctx)       : do the thing; may `await` (text boxes, waits...)
##   describe()     : one line for the command list
##   blocks()       : nested command lists as [label, owner, property], e.g. an If returns
##                    [["Then", self, "then_commands"], ["Else", self, "else_commands"]]
@tool
class_name PS1Command
extends Resource

## Menu name in the editor ("Category/Name"). Override with a const or keep the class name.
func menu_name() -> String:
	return "Custom/" + str(get_script().get_global_name()).trim_prefix("PS1Cmd")

func describe() -> String:
	return menu_name().get_file()

## Row color in the editor list.
func color() -> Color:
	return Color(0.85, 0.85, 0.85)

func blocks() -> Array:
	return []

func run(_ctx: PS1EventContext) -> void:
	pass
