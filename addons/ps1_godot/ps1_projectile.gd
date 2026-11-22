## Arrows, bolts, thrown rocks: flies with gravity, points along its flight, stops (and sticks)
## in the world. It does not do damage by itself: attach your hit detection to it (an Area3D
## child, or your game's hitbox following it) and call stop() when it hits someone.
##
##   var a := PS1Projectile.arrow()
##   get_tree().current_scene.add_child(a)
##   a.launch(hand.global_position, target.global_position + Vector3(0, 1.2, 0), 26.0)
##   a.hit_world.connect(func(pos, normal, collider): ...)
class_name PS1Projectile
extends Node3D

signal hit_world(position: Vector3, normal: Vector3, collider: Object)
signal finished

@export var speed := 26.0
@export var gravity := 6.0
@export var lifetime := 4.0
## Physics layers it stops on (walls, floors).
@export_flags_3d_physics var world_mask := 1
## Seconds it stays stuck where it hit (0 = disappears at once).
@export var stick_time := 5.0

var velocity := Vector3.ZERO
var exclude: Array[RID] = []
var flying := false
var _t := 0.0

## A low-poly arrow (shaft, iron head, fletching), pointing along -Z.
static func arrow(length := 0.8, shaft := Color(0.45, 0.33, 0.2), fletch := Color(0.75, 0.72, 0.65)) -> PS1Projectile:
	var p := PS1Projectile.new()
	p.name = "Arrow"
	var g := PS1Gothic.new()
	g.uv_meters = 0.5
	g.surface("shaft")
	g.limb(Vector3(0, 0, length * 0.5), Vector3(0, 0, -length * 0.45), 0.012, 0.012, 4)
	g.surface("head")
	g.limb(Vector3(0, 0, -length * 0.45), Vector3(0, 0, -length * 0.56), 0.03, 0.002, 4)
	g.surface("fletch")
	for a in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		var o := Vector3(cos(a), sin(a), 0) * 0.045
		var z0 := length * 0.47; var z1 := length * 0.3
		g.tri(Vector3(0, 0, z0), Vector3(0, 0, z1), Vector3(0, 0, z0) + o)
		g.tri(Vector3(0, 0, z0), Vector3(0, 0, z0) + o, Vector3(0, 0, z1))
	var mi := MeshInstance3D.new()
	mi.mesh = g.mesh()
	var mats := {shaft = PS1Convert.make(PS1Textures.flat(shaft), {color = Color.WHITE}),
		head = PS1Convert.make(PS1Textures.flat(Color(0.35, 0.35, 0.38)), {color = Color.WHITE}),
		fletch = PS1Convert.make(PS1Textures.flat(fletch), {color = Color.WHITE})}
	for i in g.surface_names.size():
		mi.set_surface_override_material(i, mats[g.surface_names[i]])
	mi.set_meta("ps1_no_bake", true)
	p.add_child(mi)
	return p

## Velocity that reaches `to` from `from` at `speed_` with this gravity (low arc); straight line
## if out of range.
static func aim(from: Vector3, to: Vector3, speed_: float, gravity_: float) -> Vector3:
	var d := to - from
	var flat := Vector3(d.x, 0, d.z)
	var x := flat.length()
	if x < 0.01 or gravity_ <= 0.0:
		return d.normalized() * speed_
	var y := d.y
	var v2 := speed_ * speed_
	var disc := v2 * v2 - gravity_ * (gravity_ * x * x + 2.0 * y * v2)
	if disc < 0.0:
		return (flat.normalized() + Vector3.UP * 0.35).normalized() * speed_
	var ang := atan((v2 - sqrt(disc)) / (gravity_ * x))
	return flat.normalized() * cos(ang) * speed_ + Vector3.UP * sin(ang) * speed_

## Fire from `from` toward `to` (already in the tree).
func launch(from: Vector3, to: Vector3, speed_ := -1.0) -> void:
	if speed_ > 0.0:
		speed = speed_
	global_position = from
	velocity = aim(from, to, speed, gravity)
	flying = true
	_t = 0.0
	_orient()

func _orient() -> void:
	if velocity.length() > 0.01:
		var up := Vector3.UP if absf(velocity.normalized().y) < 0.98 else Vector3.RIGHT
		global_basis = Basis.looking_at(velocity.normalized(), up)

func _physics_process(dt: float) -> void:
	if not flying:
		return
	_t += dt
	if _t > lifetime:
		stop(false)
		return
	velocity += Vector3.DOWN * gravity * dt
	var from := global_position
	var to := from + velocity * dt
	var q := PhysicsRayQueryParameters3D.create(from, to, world_mask, exclude)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		global_position = r.position
		flying = false
		hit_world.emit(r.position, r.normal, r.collider)
		stop(true)
		return
	global_position = to
	_orient()

## Stop flying. stuck=true leaves it in place for stick_time, else it vanishes now.
func stop(stuck := false) -> void:
	flying = false
	if not stuck or stick_time <= 0.0:
		finished.emit()
		queue_free()
		return
	await get_tree().create_timer(stick_time).timeout
	if is_inside_tree():
		finished.emit()
		queue_free()
