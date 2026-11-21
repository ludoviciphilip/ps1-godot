## Show Text: a text box (speaker optional). Waits for the player to confirm.
## {name} / {$local} in the text are replaced by variable values ("Runes: {runes}/3").
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
func run(ctx: PS1EventContext) -> void:
	await PS1Events.dialog().show_text(speaker, format(text, ctx))

## Replaces {variable} with its value.
static func format(t: String, ctx: PS1EventContext) -> String:
	var re := RegEx.create_from_string("\\{(\\$?[A-Za-z0-9_./:]+)\\}")
	var out := t
	for m in re.search_all(t):
		out = out.replace(m.get_string(), str(ctx.get_var(m.get_string(1)) if ctx else PS1Events.get_var(m.get_string(1))))
	return out
