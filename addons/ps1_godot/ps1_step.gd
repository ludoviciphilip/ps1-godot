## Step climbing for CharacterBody3D (players and enemies): walking into a low ledge (curb,
## bonfire dais, rubble, stairs built from boxes) lifts the body onto it, and the visible model
## glides up over a few frames instead of popping — no teleport look.
##
##   func _physics_process(dt):
##       ... set velocity ...
##       PS1Step.climb(self, $Visual)     # before move_and_slide()
##       move_and_slide()
##       PS1Step.smooth(self, $Visual, dt)
##
## Only looks at the level (collision layer `mask`), never at other bodies.
class_name PS1Step
extends RefCounted

## Highest ledge climbed (meters).
static var max_height := 0.36
## How long the model takes to catch up with the body (seconds, roughly).
static var glide := 0.12

## Tries to climb; returns the height climbed (0 = nothing to climb). `visual` (optional) is
## the model node: it is held back where it was and glides up in smooth().
static func climb(body: CharacterBody3D, visual: Node3D = null, mask := 1, reach := 0.6) -> float:
	if not body.is_on_floor():
		return 0.0
	var h := Vector3(body.velocity.x, 0.0, body.velocity.z)
	if h.length() < 0.5:
		return 0.0
	var d := h.normalized()
	var space := body.get_world_3d().direct_space_state
	var p := body.global_position
	var ex: Array[RID] = [body.get_rid()]
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.1, p + Vector3.UP * 0.1 + d * reach, mask, ex)
	var wall := space.intersect_ray(q)
	if wall.is_empty() or absf((wall.normal as Vector3).y) > 0.35:
		return 0.0   # nothing at foot height, or a ramp (the body walks up those on its own)
	var top := p + d * (reach - 0.05) + Vector3.UP * (max_height + 0.05)
	var r := space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * (max_height + 0.04), mask, ex))
	if r.is_empty() or (r.normal as Vector3).y < 0.7:
		return 0.0
	var up: float = (r.position as Vector3).y - p.y
	if up < 0.04 or up > max_height:
		return 0.0
	# room for the body on top, and nothing right in front at the new height
	if not space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * (up + 0.2), p + Vector3.UP * (up + 1.7), mask, ex)).is_empty():
		return 0.0
	var fwd := minf(0.35, reach * 0.6)
	if not space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * (up + 0.25), p + Vector3.UP * (up + 0.25) + d * (fwd + 0.4), mask, ex)).is_empty():
		return 0.0
	var jump := Vector3.UP * (up + 0.02) + d * fwd
	body.global_position += jump
	body.velocity.y = 0.0
	if visual:
		# hold the model where it was; smooth() lets it catch up
		var off: Vector3 = body.get_meta("_ps1_step_off", Vector3.ZERO) - jump
		_apply(body, visual, off)
	return up

## Glides the model back onto the body after a climb. Call every physics frame.
static func smooth(body: CharacterBody3D, visual: Node3D, dt: float) -> void:
	var off: Vector3 = body.get_meta("_ps1_step_off", Vector3.ZERO)
	if off == Vector3.ZERO:
		return
	var k := 1.0 - exp(-dt * 3.0 / maxf(glide, 0.01))
	var nxt := off.lerp(Vector3.ZERO, k)
	if nxt.length() < 0.005:
		nxt = Vector3.ZERO
	_apply(body, visual, nxt)

## Current offset of the model (global space) — e.g. to keep a camera on the model.
static func offset(body: Node3D) -> Vector3:
	return body.get_meta("_ps1_step_off", Vector3.ZERO)

# moves the model by the change in offset (additive: other code may also move the model)
static func _apply(body: Node3D, visual: Node3D, off: Vector3) -> void:
	var prev: Vector3 = body.get_meta("_ps1_step_off", Vector3.ZERO)
	var parent := visual.get_parent() as Node3D
	var inv := parent.global_basis.inverse() if parent else Basis()
	visual.position += inv * (off - prev)
	body.set_meta("_ps1_step_off", off)
