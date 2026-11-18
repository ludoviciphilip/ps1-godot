## Comment: does nothing (notes for yourself).
@tool
class_name PS1CmdComment
extends PS1Command

@export_multiline var note := "":
	set(v): note = v; emit_changed()

func menu_name() -> String: return "Flow/Comment"
func color() -> Color: return Color(0.5, 0.75, 0.5)
func describe() -> String: return "# " + note.replace("\n", " / ")
