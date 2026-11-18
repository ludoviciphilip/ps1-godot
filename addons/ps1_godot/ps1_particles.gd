## PS1-style particles: small CPU simulation drawn with one MultiMesh. Looks like the era on
## purpose: few big pixels, 15-bit color, colors that STEP through the gradient, choppy updates
## (update_fps), snapped vertices, additive (fire, glows) or dithered (smoke, mist) blending.
##
##   var p := PS1Particles.preset("embers")      # embers, sparks, smoke, mist, dust, ash,
##   add_child(p)                                # motes, soul, burst, blood, fog_puff
##   PS1Particles.spawn(self, "sparks", pos)     # one-shot, frees itself
##   p.burst(20)                                 # extra particles now
@tool
@icon("res://addons/ps1_godot/icons/particles.svg")
class_name PS1Particles
extends Node3D

enum Shape { POINT, SPHERE, BOX, RING }
enum Blend { ADDITIVE, DITHER }

@export var emitting := true
## Particles per second (continuous). 0 = only bursts.
@export var rate := 10.0
## Max particles alive (MultiMesh size). Can change at runtime.
@export var amount := 32:
	set(v):
		amount = maxi(v, 1)
		if _mm:
			_resize()
## One-shot: emits `burst_count` once, then stops (and frees itself if auto_free).
@export var one_shot := false
@export var burst_count := 20
@export var auto_free := false
@export var lifetime := 1.5
@export_range(0.0, 1.0) var lifetime_random := 0.3
@export_group("Shape")
@export var shape := Shape.POINT
@export var shape_radius := 0.3
@export var shape_extents := Vector3(0.5, 0.5, 0.5)
@export_group("Motion")
@export var direction := Vector3.UP
@export_range(0.0, 180.0) var spread := 20.0
@export var speed_min := 0.5
@export var speed_max := 1.0
@export var gravity := Vector3.ZERO
@export var damping := 0.0
## Sideways wobble (m/s) and how fast it changes.
@export var turbulence := 0.0
@export var turbulence_freq := 1.5
## Simulate in world space (particles stay behind when the node moves).
@export var world_space := true
@export_group("Look")
@export var blend := Blend.ADDITIVE
@export var size_start := 0.08
@export var size_end := 0.04
@export_range(0.0, 1.0) var size_random := 0.3
## Color over life. Leave empty for white -> transparent.
@export var colors: Gradient
## Number of distinct colors a particle goes through (PS1 palettes stepped; 0 = smooth).
@export var color_steps := 4
## Built-in sheet ("dot", "spark", "puff", "ember", "cross") or your own texture.
@export var texture_name := "dot"
@export var texture: Texture2D
@export var hframes := 4
## Frame over life (true) or a random fixed frame per particle (false).
@export var animate_frames := true
## Simulation steps per second (PS1 effects often updated at 15-30).
@export var update_fps := 20.0
@export var preview_in_editor := true

var _mm: MultiMesh
var _mmi: MultiMeshInstance3D
var _pos: PackedVector3Array
var _vel: PackedVector3Array
var _age: PackedFloat32Array
var _life: PackedFloat32Array
var _seed: PackedFloat32Array
var _size: PackedFloat32Array
var _alive := 0
var _acc := 0.0
var _emit_acc := 0.0
var _rng := RandomNumberGenerator.new()
var _done_burst := false
var _time := 0.0

static var _sheets := {}

func _ready() -> void:
	_rng.randomize()
	_build()
	if one_shot and emitting and not Engine.is_editor_hint():
		_first_burst.call_deferred()   # deferred: the caller may still move the node this frame

func _first_burst() -> void:
	if not _done_burst:
		_done_burst = true
		burst(burst_count)

func _build() -> void:
	if _mmi:
		_mmi.queue_free()
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	_mm.mesh = q
	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = _mm
	_mmi.top_level = world_space
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mmi.set_meta("ps1_no_bake", true)
	_mmi.material_override = make_material()
	_mmi.custom_aabb = AABB(Vector3(-50, -50, -50), Vector3(100, 100, 100))
	add_child(_mmi, false, Node.INTERNAL_MODE_BACK)
	if world_space:
		_mmi.global_transform = Transform3D.IDENTITY
	_alive = 0
	_resize()

func _resize() -> void:
	_alive = mini(_alive, amount)
	_mm.instance_count = amount
	_mm.visible_instance_count = _alive
	_pos.resize(amount); _vel.resize(amount); _age.resize(amount); _life.resize(amount)
	_seed.resize(amount); _size.resize(amount)

func make_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://addons/ps1_godot/shaders/ps1_particles_add.gdshader") if blend == Blend.ADDITIVE \
		else preload("res://addons/ps1_godot/shaders/ps1_particles.gdshader")
	var t := texture if texture else sheet(texture_name)
	m.set_shader_parameter("tex", t)
	m.set_shader_parameter("hframes", float(hframes if texture else 4))
	return m

## Built-in 4-frame 8x8 sheets, made in code (no files).
static func sheet(name: String) -> Texture2D:
	if _sheets.has(name):
		return _sheets[name]
	var img := Image.create(32, 8, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	for f in 4:
		for y in 8:
			for x in 8:
				var d := Vector2(x - 3.5, y - 3.5)
				var r := d.length()
				var a := 0.0
				var shrink := f * 0.45
				match name:
					"dot":
						a = 1.0 if r < 3.0 - shrink else (0.45 if r < 3.9 - shrink else 0.0)
					"spark", "cross":
						var arm := minf(absf(d.x), absf(d.y))
						a = 1.0 if (arm < 0.6 and r < 4.0 - shrink) or r < 1.6 - shrink * 0.5 else (0.4 if r < 2.3 - shrink * 0.5 else 0.0)
					"ember":
						a = 1.0 if r < 2.0 - shrink * 0.6 else (0.5 if r < 3.4 - shrink else 0.0)
					"puff":
						var n := rng.randf()
						a = (1.0 if r < 2.6 - shrink * 0.3 else (0.55 if r < 3.8 - shrink * 0.3 else 0.0)) * (0.65 + 0.35 * n)
				img.set_pixel(f * 8 + x, y, Color(1, 1, 1, a))
	var t := ImageTexture.create_from_image(img)
	_sheets[name] = t
	return t

## Emits n particles right now.
func burst(n: int) -> void:
	for i in n:
		_emit_one()

func _emit_one() -> void:
	if _alive >= amount:
		return
	var i := _alive
	_alive += 1
	var p := Vector3.ZERO
	match shape:
		Shape.SPHERE:
			p = Vector3(_rng.randfn(), _rng.randfn(), _rng.randfn()).normalized() * shape_radius * pow(_rng.randf(), 0.33)
		Shape.BOX:
			p = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * shape_extents
		Shape.RING:
			var ang := _rng.randf() * TAU
			p = Vector3(cos(ang), 0, sin(ang)) * shape_radius
	var dir := direction.normalized() if direction.length() > 0.0001 else Vector3.UP
	var sp := deg_to_rad(spread)
	if sp > 0.0:
		var axis := dir.cross(Vector3.RIGHT if absf(dir.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
		dir = dir.rotated(axis, _rng.randf() * sp).rotated(direction.normalized() if direction.length() > 0.0001 else Vector3.UP, _rng.randf() * TAU)
	var v := dir * _rng.randf_range(speed_min, speed_max)
	if world_space:
		p = global_transform * p
		v = global_basis * v
	_pos[i] = p
	_vel[i] = v
	_age[i] = 0.0
	_life[i] = lifetime * (1.0 - _rng.randf() * lifetime_random)
	_seed[i] = _rng.randf() * 100.0
	_size[i] = 1.0 - _rng.randf() * size_random

func _process(dt: float) -> void:
	if Engine.is_editor_hint() and not preview_in_editor:
		return
	_time += dt
	_acc += dt
	var step := 1.0 / maxf(update_fps, 1.0)
	if _acc < step:
		return
	var h := _acc
	_acc = 0.0
	if emitting and not one_shot and rate > 0.0:
		_emit_acc += h * rate
		while _emit_acc >= 1.0:
			_emit_acc -= 1.0
			_emit_one()
	if one_shot and Engine.is_editor_hint() and _alive == 0:
		burst(burst_count)   # editor preview loops one-shots
	var damp := exp(-damping * h)
	var i := 0
	while i < _alive:
		_age[i] += h
		if _age[i] >= _life[i]:
			_alive -= 1
			_pos[i] = _pos[_alive]; _vel[i] = _vel[_alive]; _age[i] = _age[_alive]
			_life[i] = _life[_alive]; _seed[i] = _seed[_alive]; _size[i] = _size[_alive]
			continue
		var v := _vel[i] + gravity * h
		v *= damp
		var wob := Vector3.ZERO
		if turbulence > 0.0:
			var s := _seed[i] + _time * turbulence_freq
			wob = Vector3(sin(s * 1.7), sin(s * 1.3 + 2.0) * 0.4, cos(s * 1.1)) * turbulence
		_vel[i] = v
		_pos[i] += (v + wob) * h
		i += 1
	_draw_instances()
	if one_shot and _done_burst and _alive == 0 and auto_free and not Engine.is_editor_hint():
		queue_free()

func _draw_instances() -> void:
	_mm.visible_instance_count = _alive
	for i in _alive:
		var t := _age[i] / _life[i]
		var st := t
		if color_steps > 0:
			st = minf(floorf(t * color_steps) / maxf(color_steps - 1, 1), 1.0)
		var c := colors.sample(st) if colors else Color(1, 1, 1, 1.0 - st)
		var s := lerpf(size_start, size_end, t) * _size[i]
		_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * s), _pos[i]))
		_mm.set_instance_color(i, c)
		var f := floorf(t * 3.999) if animate_frames else floorf(fmod(_seed[i], 4.0))
		_mm.set_instance_custom_data(i, Color(f, 0, 0, 0))

func alive_count() -> int:
	return _alive

## Stops emitting; frees itself when the last particle dies (if auto_free).
func stop(free_when_done := true) -> void:
	emitting = false
	rate = 0.0
	if free_when_done:
		one_shot = true
		_done_burst = true
		auto_free = true

# ---------------- presets ----------------

static func _grad(cols: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(range(cols.size()).map(func(i): return float(i) / maxf(cols.size() - 1, 1)))
	g.colors = PackedColorArray(cols)
	return g

## Ready-made effects. Tweak the returned node freely before adding it.
static func preset(name: String) -> PS1Particles:
	var p := PS1Particles.new()
	match name:
		"embers":     # fire: rising embers that cool down
			p.rate = 7; p.amount = 24; p.lifetime = 1.6; p.shape = Shape.SPHERE; p.shape_radius = 0.25
			p.speed_min = 0.5; p.speed_max = 1.2; p.spread = 15; p.turbulence = 0.35
			p.size_start = 0.14; p.size_end = 0.06; p.texture_name = "ember"
			p.colors = _grad([Color(1, 0.9, 0.5), Color(1, 0.55, 0.15), Color(0.8, 0.2, 0.05), Color(0.3, 0.05, 0.0, 0.0)])
		"sparks":     # hit: fast sparks that fall
			p.one_shot = true; p.burst_count = 10; p.amount = 16; p.lifetime = 0.35; p.auto_free = true
			p.spread = 70; p.speed_min = 2.5; p.speed_max = 5.0; p.gravity = Vector3(0, -9, 0); p.damping = 2.0
			p.size_start = 0.18; p.size_end = 0.06; p.texture_name = "spark"; p.update_fps = 30
			p.colors = _grad([Color(1, 1, 0.85), Color(1, 0.7, 0.3), Color(0.6, 0.2, 0.05, 0.0)])
		"smoke":
			p.rate = 2; p.amount = 10; p.lifetime = 3.0; p.blend = Blend.DITHER; p.shape = Shape.SPHERE; p.shape_radius = 0.2
			p.speed_min = 0.3; p.speed_max = 0.6; p.spread = 12; p.turbulence = 0.25
			p.size_start = 0.50; p.size_end = 1.40; p.texture_name = "puff"; p.update_fps = 12
			p.colors = _grad([Color(0.25, 0.23, 0.22, 0.55), Color(0.2, 0.2, 0.2, 0.35), Color(0.15, 0.15, 0.15, 0.0)])
		"mist":       # slow pale motes drifting on a surface (fog walls)
			p.rate = 10; p.amount = 48; p.lifetime = 4.0; p.shape = Shape.BOX; p.shape_extents = Vector3(1.0, 1.3, 0.1)
			p.speed_min = 0.05; p.speed_max = 0.2; p.spread = 180; p.turbulence = 0.25; p.turbulence_freq = 0.6
			p.size_start = 0.10; p.size_end = 0.18; p.texture_name = "dot"; p.update_fps = 15
			p.colors = _grad([Color(0.75, 0.8, 0.9, 0.5), Color(0.85, 0.9, 1.0, 0.9), Color(0.7, 0.75, 0.9, 0.35)])
		"dust":
			p.rate = 3; p.amount = 30; p.lifetime = 6.0; p.blend = Blend.DITHER; p.shape = Shape.BOX; p.shape_extents = Vector3(4, 1.5, 4)
			p.speed_min = 0.02; p.speed_max = 0.08; p.spread = 180; p.turbulence = 0.08
			p.size_start = 0.06; p.size_end = 0.06; p.update_fps = 12
			p.colors = _grad([Color(0.6, 0.55, 0.45, 0.6), Color(0.65, 0.6, 0.5, 0.8), Color(0.6, 0.55, 0.45, 0.3)])
		"ash":        # body crumbling to ash (one-shot): grey flakes drift up and away
			p.one_shot = true; p.burst_count = 40; p.amount = 48; p.lifetime = 1.8; p.auto_free = true; p.blend = Blend.DITHER
			p.shape = Shape.BOX; p.shape_extents = Vector3(0.35, 0.8, 0.35); p.spread = 50; p.speed_min = 0.3; p.speed_max = 1.0
			p.gravity = Vector3(0, 0.6, 0); p.turbulence = 0.5; p.size_start = 0.16; p.size_end = 0.06; p.texture_name = "puff"; p.update_fps = 15
			p.colors = _grad([Color(0.35, 0.33, 0.3, 1.0), Color(0.22, 0.2, 0.19, 0.8), Color(0.1, 0.1, 0.1, 0.0)])
		"motes":      # golden motes rising (souls/currency)
			p.one_shot = true; p.burst_count = 14; p.amount = 20; p.lifetime = 2.2; p.auto_free = true
			p.shape = Shape.SPHERE; p.shape_radius = 0.5; p.spread = 25; p.speed_min = 0.6; p.speed_max = 1.4; p.turbulence = 0.4
			p.size_start = 0.12; p.size_end = 0.04; p.texture_name = "spark"
			p.colors = _grad([Color(1, 0.95, 0.6), Color(1, 0.75, 0.3), Color(0.6, 0.35, 0.1, 0.0)])
		"soul":       # continuous version of motes (bonus loot glow, lost souls)
			p.rate = 7; p.amount = 20; p.lifetime = 1.8; p.shape = Shape.SPHERE; p.shape_radius = 0.2
			p.speed_min = 0.3; p.speed_max = 0.6; p.spread = 15; p.turbulence = 0.2
			p.size_start = 0.14; p.size_end = 0.06; p.texture_name = "spark"
			p.colors = _grad([Color(0.9, 0.95, 1.0), Color(0.6, 0.8, 1.0), Color(0.2, 0.3, 0.6, 0.0)])
		"burst":      # big explosion (bosses): embers flying everywhere
			p.one_shot = true; p.burst_count = 90; p.amount = 100; p.lifetime = 1.6; p.auto_free = true
			p.shape = Shape.SPHERE; p.shape_radius = 0.6; p.spread = 180; p.speed_min = 2.0; p.speed_max = 6.0
			p.gravity = Vector3(0, -2.5, 0); p.damping = 1.5; p.turbulence = 0.6
			p.size_start = 0.28; p.size_end = 0.08; p.texture_name = "ember"
			p.colors = _grad([Color(1, 1, 0.8), Color(1, 0.7, 0.25), Color(0.85, 0.25, 0.05), Color(0.2, 0.0, 0.0, 0.0)])
		"blood":
			p.one_shot = true; p.burst_count = 12; p.amount = 16; p.lifetime = 0.5; p.auto_free = true; p.blend = Blend.DITHER
			p.spread = 55; p.speed_min = 1.5; p.speed_max = 3.5; p.gravity = Vector3(0, -12, 0)
			p.size_start = 0.16; p.size_end = 0.10; p.texture_name = "dot"; p.update_fps = 30
			p.colors = _grad([Color(0.6, 0.02, 0.02), Color(0.35, 0.0, 0.0), Color(0.2, 0.0, 0.0, 0.0)])
		"fog_puff":   # crossing a fog wall
			p.one_shot = true; p.burst_count = 26; p.amount = 32; p.lifetime = 1.2; p.auto_free = true
			p.shape = Shape.BOX; p.shape_extents = Vector3(0.8, 1.2, 0.1); p.direction = Vector3(0, 0.2, 1); p.spread = 60
			p.speed_min = 0.6; p.speed_max = 1.6; p.damping = 2.0; p.turbulence = 0.3
			p.size_start = 0.16; p.size_end = 0.32; p.texture_name = "dot"; p.update_fps = 20
			p.colors = _grad([Color(0.9, 0.95, 1.0, 0.9), Color(0.7, 0.75, 0.9, 0.5), Color(0.5, 0.55, 0.7, 0.0)])
		_:
			push_warning("PS1Particles: unknown preset '%s'" % name)
	return p

## One-shot effect at a world position (frees itself). Returns the node.
static func spawn(parent: Node, preset_name: String, at: Vector3, scale_ := 1.0) -> PS1Particles:
	var p := preset(preset_name)
	if scale_ != 1.0:
		p.size_start *= scale_; p.size_end *= scale_
		p.shape_radius *= scale_; p.shape_extents *= scale_
		p.speed_min *= sqrt(scale_); p.speed_max *= sqrt(scale_)
	parent.add_child(p)
	p.global_position = at
	return p
