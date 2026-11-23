## A cave-in: rocks rain from the ceiling over an area, each one hitting the floor with a dust
## puff and staying as rubble, while the camera shakes. For collapsing arenas, falling ceilings
## in traps, a boss smashing through a wall.
##
##   var c := PS1Collapse.spawn(self, arena_center, 8.0, 3.0)   # radius, seconds
##   await c.finished
##
## A tremor (the ground shakes, dust and grit sift down, a few pebbles, nothing stays):
##
##   PS1Collapse.tremor(self, room_center, 7.0, 2.5)          # radius, seconds
##
## Shake: every node in group "ps1_shake" gets `ps1_shake(strength)` called (add your camera to
## it), and the `rumble(strength)` signal fires. Rocks are visual only (no physics bodies).
class_name PS1Collapse
extends Node3D

signal rumble(strength: float)
signal finished

@export var radius := 8.0
## Height the rocks fall from, above this node.
@export var ceiling := 8.0
@export var duration := 3.0
@export var rocks := 45
@export var rock_size := Vector2(0.3, 1.1)
## Rubble stays on the floor afterwards.
@export var keep_debris := true
@export var shake := 1.2
## PS1Audio sound played at the start ("" = none).
@export var sound := ""
@export var material: Material
## Dust sifting down from the ceiling: this many falling sheets ("dust_fall" particles) at random
## spots, staggered over the duration.
@export var dust_streams := 8

var _t := 0.0
var _next_rock := 0.0
var _next_shake := 0.0
var _falling: Array = []   # [node, velocity, floor_y, spin]
var _spawned := 0
var _done := false

## A tremor instead of a cave-in: shaking, dust sifting down from `ceiling`, a few pebbles that
## don't stay. Warn the player that a place is about to give way.
static func tremor(parent: Node, at: Vector3, radius_ := 7.0, duration_ := 2.5, shake_ := 0.6, ceiling_ := 6.0) -> PS1Collapse:
	var c := PS1Collapse.new()
	c.radius = radius_
	c.duration = duration_
	c.shake = shake_
	c.ceiling = ceiling_
	c.rocks = int(radius_ * 1.2)
	c.rock_size = Vector2(0.07, 0.2)
	c.keep_debris = false
	c.dust_streams = int(radius_ * 1.8)
	parent.add_child(c)
	c.global_position = at
	return c

static func spawn(parent: Node, at: Vector3, radius_ := 8.0, duration_ := 3.0) -> PS1Collapse:
	var c := PS1Collapse.new()
	c.radius = radius_
	c.duration = duration_
	parent.add_child(c)
	c.global_position = at
	return c

func _ready() -> void:
	if material == null:
		material = PS1Convert.make(PS1Textures.mossy_rock(), {color = Color(0.7, 0.7, 0.72)})
	if sound != "":
		PS1Audio.play(sound, global_position + Vector3.UP * 2.0)
	for i in dust_streams:
		_dust_stream(float(i) / maxf(dust_streams, 1) * duration * 0.6)

func _dust_stream(delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	if not is_inside_tree():
		return
	var a := randf() * TAU
	var r := sqrt(randf()) * radius
	var p := PS1Particles.preset("dust_fall")
	p.rate *= randf_range(0.6, 1.3)
	get_parent().add_child(p)
	p.global_position = global_position + Vector3(cos(a) * r, ceiling - 0.2, sin(a) * r)
	await get_tree().create_timer(maxf(duration - delay, 0.4) * randf_range(0.6, 1.0), false).timeout
	if is_instance_valid(p):
		p.stop(true)

func _process(dt: float) -> void:
	_t += dt
	var active := _t < duration
	# rocks: more at the start, fewer at the end
	if active and _spawned < rocks:
		_next_rock -= dt
		while _next_rock <= 0.0 and _spawned < rocks:
			_next_rock += duration / rocks * (0.5 + _t / duration)
			_drop_rock()
	for i in range(_falling.size() - 1, -1, -1):
		var f: Array = _falling[i]
		var n: Node3D = f[0]
		if not is_instance_valid(n):
			_falling.remove_at(i)
			continue
		f[1] += 20.0 * dt
		n.position.y -= f[1] * dt
		n.rotate(f[3], dt * 4.0)
		if n.position.y <= f[2]:
			n.position.y = f[2]
			_falling.remove_at(i)
			PS1Particles.spawn(get_parent(), "dust", n.global_position, clampf(n.scale.x * 2.0, 0.6, 2.0))
			if not keep_debris:
				n.queue_free()
	if active:
		_next_shake -= dt
		if _next_shake <= 0.0:
			_next_shake = 0.22
			var s := shake * (1.0 - 0.6 * _t / duration)
			rumble.emit(s)
			get_tree().call_group("ps1_shake", "ps1_shake", s)
	elif not _done and _falling.is_empty():
		_done = true
		finished.emit()

func _drop_rock() -> void:
	_spawned += 1
	var g := PS1Gothic.new()
	var sz := randf_range(rock_size.x, rock_size.y)
	g.rock(Vector3.ZERO, Vector3(sz, sz * randf_range(0.5, 0.9), sz * randf_range(0.7, 1.0)), randi())
	var mi := MeshInstance3D.new()
	mi.mesh = g.mesh()
	mi.material_override = material
	var a := randf() * TAU
	var r := sqrt(randf()) * radius
	mi.position = Vector3(cos(a) * r, ceiling + randf() * 2.0, sin(a) * r)
	mi.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
	add_child(mi)
	_falling.append([mi, 0.0, sz * 0.25, Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized()])
