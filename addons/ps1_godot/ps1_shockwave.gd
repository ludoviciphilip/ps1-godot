## Shockwave: a ring of dust that rolls out over the ground from an impact (boss slams, falling
## boulders, explosions). It's also the hit area: `reached(body)` fires once for every body in
## `target_group` that the ring front passes while it is on the ground (jumping over it or being
## invulnerable is the game's call). Frees itself when done.
##
##   var w := PS1Shockwave.spawn(get_tree().current_scene, impact_pos, 7.0, 0.9)
##   w.reached.connect(func(b): b.take_hit(30))
class_name PS1Shockwave
extends Node3D

signal reached(body: Node3D)

## Final radius (m) and the time to get there (s).
@export var radius := 6.0
@export var duration := 0.8
## Thickness of the ring front that hurts (m) and how high it reaches above the ground.
@export var width := 1.0
@export var height := 0.9
## Bodies closer than this to the center are ignored (they were already hit by the blow itself).
@export var min_radius := 0.0
## Who it can reach (group name).
@export var target_group := "player"
@export var color := Color(0.5, 0.45, 0.37)
## Particle density.
@export var dust := 1.0

var _t := 0.0
var _done := {}
var _ring: MeshInstance3D
var _mat: ShaderMaterial
var _front: PS1Particles
var _puff: PS1Particles

static func spawn(parent: Node, at: Vector3, radius_ := 6.0, duration_ := 0.8, group := "player") -> PS1Shockwave:
	var w := PS1Shockwave.new()
	w.name = "Shockwave"
	w.radius = radius_
	w.duration = duration_
	w.target_group = group
	parent.add_child(w)
	w.global_position = at
	return w

func _ready() -> void:
	# flat dusty ring on the ground
	_ring = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 2.0
	q.orientation = PlaneMesh.FACE_Y
	_ring.mesh = q
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://addons/ps1_godot/shaders/ps1_shockwave.gdshader")
	_mat.set_shader_parameter("color", color)
	_ring.material_override = _mat
	_ring.position.y = 0.04
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	# dust kicked up along the ring front (emitter grows with it)
	_front = PS1Particles.new()
	_front.shape = PS1Particles.Shape.RING
	_front.rate = 90.0 * dust * clampf(radius / 6.0, 0.6, 2.0)
	_front.amount = int(_front.rate * 0.9) + 16
	_front.lifetime = 0.7
	_front.direction = Vector3.UP
	_front.spread = 35.0
	_front.speed_min = 0.6; _front.speed_max = 1.8
	_front.gravity = Vector3(0, -1.5, 0); _front.damping = 1.5; _front.turbulence = 0.3
	_front.blend = PS1Particles.Blend.DITHER
	_front.size_start = 0.35; _front.size_end = 0.7
	_front.texture_name = "puff"; _front.update_fps = 20
	_front.colors = PS1Particles._grad([Color(color, 0.9), Color(color.darkened(0.15), 0.6), Color(color.darkened(0.3), 0.0)])
	_front.position.y = 0.15
	add_child(_front)
	# a burst at the center
	_puff = PS1Particles.preset("smoke")
	_puff.one_shot = true; _puff.burst_count = int(18 * dust); _puff.amount = _puff.burst_count + 4
	_puff.shape_radius = 0.6; _puff.spread = 70; _puff.speed_min = 1.0; _puff.speed_max = 2.5
	_puff.damping = 2.0; _puff.lifetime = 1.1
	_puff.colors = PS1Particles._grad([Color(color, 0.9), Color(color.darkened(0.2), 0.5), Color(color.darkened(0.3), 0.0)])
	add_child(_puff)

func current_radius() -> float:
	return radius * ease(clampf(_t / duration, 0.0, 1.0), 0.6)   # fast start, slows down

func _physics_process(dt: float) -> void:
	_t += dt
	var r := current_radius()
	var k := clampf(_t / duration, 0.0, 1.0)
	_ring.scale = Vector3.ONE * maxf(r, 0.01)
	_mat.set_shader_parameter("thickness", clampf(width / maxf(r, 0.5), 0.05, 1.0))
	_mat.set_shader_parameter("fade", 1.0 - k * k)
	_front.shape_radius = r
	if k >= 1.0:
		_front.emitting = false
	if k < 1.0:
		for b in get_tree().get_nodes_in_group(target_group):
			if not b is Node3D or _done.has(b):
				continue
			var d: Vector3 = (b as Node3D).global_position - global_position
			var flat := Vector2(d.x, d.z).length()
			if flat <= r and flat >= maxf(r - width, min_radius) and d.y <= height and d.y > -1.0:
				_done[b] = true
				reached.emit(b)
	if _t > duration + 1.2:
		queue_free()
