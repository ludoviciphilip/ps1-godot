## A labelled list of commands (one option of a Show Choices).
@tool
class_name PS1Branch
extends Resource

@export var label := "":
	set(v): label = v; emit_changed()
@export var commands: Array[PS1Command] = []
