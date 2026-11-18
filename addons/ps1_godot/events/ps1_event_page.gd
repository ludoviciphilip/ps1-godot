## One page of an event. The active page is the LAST one whose condition is true (RPG Maker rule):
## e.g. page 1 "closed chest" (interact: give item, set $open = 1), page 2 "if $open == 1" (no trigger).
@tool
class_name PS1EventPage
extends Resource

enum Trigger { INTERACT, TOUCH, AUTORUN, NONE }

@export var trigger := Trigger.INTERACT:
	set(v): trigger = v; emit_changed()
@export var condition: PS1Condition
## Child of the event shown only while this page is active (chest closed / open, NPC...).
@export var graphic: NodePath
## Text of the interaction prompt (games read it via PS1Event.prompt_text()).
@export var prompt := "Examine"
@export var commands: Array[PS1Command] = []

func is_active(get_var: Callable) -> bool:
	return condition == null or condition.test(get_var)
