## Show Text: a text box (speaker optional). Waits for the player to confirm.
@tool
class_name PS1CmdText
extends PS1Command

@export var speaker := "":
	set(v): speaker = v; emit_changed()
@export_multiline var text := "":
	set(v): text = v; emit_changed()

func menu_name() -> String: return "Message/Show Text"
func color() -> Color: return Color(0.95, 0.95, 0.95)
func describe() -> String:
	return "Text: " + ("[%s] " % speaker if speaker != "" else "") + text.replace("\n", " / ")
func run(_ctx: PS1EventContext) -> void:
	await PS1Events.dialog().show_text(speaker, text)
