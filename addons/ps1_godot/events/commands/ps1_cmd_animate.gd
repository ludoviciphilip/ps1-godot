## Animate a node without an AnimationPlayer: swing it like a bell or a hanging sign
## (pendulum that dies down), shake it, turn it (statues, valves, levers) or slide it (doors,
## drawbridges, secret walls).
@tool
class_name PS1CmdAnimate
extends PS1Command

enum Mode { SWING, SHAKE, ROTATE_BY, MOVE_BY }
## Node to animate (empty = the event).
@export var target: NodePath:
	set(v): target = v; emit_changed()
@export var mode := Mode.SWING:
	set(v): mode = v; emit_changed()
## SWING: local axis; ROTATE_BY: degrees per axis; MOVE_BY: meters (local to the parent).
@export var amount := Vector3(25, 0, 0):
	set(v): amount = v; emit_changed()
@export var duration := 2.5:
	set(v): duration = v; emit_changed()
## SWING/SHAKE: swings per second.
@export var frequency := 0.9:
	set(v): frequency = v; emit_changed()
@export var wait := false:
	set(v): wait = v; emit_changed()

func menu_name() -> String: return "Scene/Animate Node"
func color() -> Color: return Color(0.7, 0.95, 0.85)
func describe() -> String:
	return "%s %s %s, %.1f s%s" % [Mode.keys()[mode].capitalize(), target if not target.is_empty() else "(this event)", amount, duration, " (wait)" if wait else ""]

func run(ctx: PS1EventContext) -> void:
	var n := ctx.node(target) as Node3D
	if n == null:
		push_warning("PS1CmdAnimate: node not found: %s" % target)
		return
	var tw := animate(n, mode, amount, duration, frequency)
	if wait and tw:
		await tw.finished

## Same thing from code. Returns the Tween.
static func animate(n: Node3D, mode_: Mode, amount_: Vector3, duration_ := 2.5, frequency_ := 0.9) -> Tween:
	if n.has_meta("_ps1_anim_tween"):
		var old: Tween = n.get_meta("_ps1_anim_tween")
		if old and old.is_valid():
			old.kill()
			if n.has_meta("_ps1_anim_rest"):
				var r: Array = n.get_meta("_ps1_anim_rest")
				n.rotation = r[0]; n.position = r[1]
	var rot0 := n.rotation
	var pos0 := n.position
	n.set_meta("_ps1_anim_rest", [rot0, pos0])
	var tw := n.create_tween()
	n.set_meta("_ps1_anim_tween", tw)
	match mode_:
		Mode.SWING, Mode.SHAKE:
			var amp := amount_ * (PI / 180.0) if mode_ == Mode.SWING else amount_
			var step := func(t: float) -> void:
				var k := exp(-3.0 * t / duration_) * (1.0 - smoothstep(0.85, 1.0, t / duration_))
				var w := sin(TAU * frequency_ * t) * k
				if mode_ == Mode.SWING:
					n.rotation = rot0 + amp * w
				else:
					n.position = pos0 + amp * Vector3(sin(TAU * frequency_ * t * 1.3), cos(TAU * frequency_ * t * 0.7), sin(TAU * frequency_ * t)) * k
			tw.tween_method(step, 0.0, duration_, duration_)
			tw.tween_callback(func(): n.rotation = rot0; n.position = pos0)
		Mode.ROTATE_BY:
			tw.tween_property(n, "rotation", rot0 + amount_ * (PI / 180.0), duration_).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		Mode.MOVE_BY:
			tw.tween_property(n, "position", pos0 + amount_, duration_).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw
