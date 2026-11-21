## One page of an event. The active page is the LAST one whose condition is true (RPG Maker rule):
## e.g. page 1 "closed chest" (interact: give item, set $open = 1), page 2 "if $open == 1" (no trigger).
## Trigger ON_SIGNAL runs the page when a node emits a signal: by default the event's PARENT, so
## an event under a monster with signal "died" is an RPG Maker "on defeated" event (drops,
## messages, variables...). The signal's first Node argument (or the emitter) is the event's
## "source": Spawn Scene / Move to source use its position (where the monster fell).
@tool
class_name PS1EventPage
extends Resource

enum Trigger { INTERACT, TOUCH, AUTORUN, NONE, ON_SIGNAL }
const TRIGGER_NAMES := ["Interact", "Touch", "Autorun", "None", "On signal"]

@export var trigger := Trigger.INTERACT:
	set(v): trigger = v; emit_changed()
@export var condition: PS1Condition
## ON_SIGNAL: node that emits the signal (relative to the event; ".." = its parent).
@export var signal_source := NodePath(".."):
	set(v): signal_source = v; emit_changed()
## ON_SIGNAL: signal name (e.g. "died", "defeated", "opened").
@export var signal_name := &"":
	set(v): signal_name = v; emit_changed()
## Child of the event shown only while this page is active (chest closed / open, NPC...).
@export var graphic: NodePath
## Text of the interaction prompt (games read it via PS1Event.prompt_text()).
@export var prompt := "Examine"
@export var commands: Array[PS1Command] = []

func is_active(get_var: Callable) -> bool:
	return condition == null or condition.test(get_var)
