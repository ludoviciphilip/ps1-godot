## PS1-style sprite: a camera-facing quad with jitter, affine UVs, alpha test and optional
## sprite-sheet animation. Pivot at the bottom center (stands on the ground).
##   var tree := PS1Sprite.new(); tree.texture = tex; tree.size = Vector2(3, 5)
##   var fire := PS1Sprite.new(); fire.texture = sheet; fire.hframes = 4; fire.fps = 10; fire.lit = false
@tool
class_name PS1Sprite
extends MeshInstance3D

@export var texture: Texture2D:
	set(v):
		texture = v
		_param("albedo_tex", v)
@export var size := Vector2(1, 1):
	set(v):
		size = v
		_rebuild()
## Lit sprites turn only around Y (trees). Unlit ones always face the camera (fire, effects).
@export var lit := true:
	set(v):
		lit = v
		_rebuild()
@export var color := Color.WHITE:
	set(v):
		color = v
		_param("albedo_color", v)
@export_range(1, 64) var hframes := 1:
	set(v):
		hframes = v
		_update_frame()
@export_range(1, 64) var vframes := 1:
	set(v):
		vframes = v
		_update_frame()
@export var frame := 0:
	set(v):
		frame = v
		_update_frame()
## Animate through all frames at this rate (0 = static).
@export var fps := 0.0
## Start on a random frame, so a row of torches doesn't flicker in sync.
@export var random_start := true

var _mat: ShaderMaterial
var _t := 0.0

func _ready() -> void:
	_rebuild()
	if random_start and fps > 0.0:
		_t = randf() * 10.0

func _param(k: String, v) -> void:
	if _mat:
		_mat.set_shader_parameter(k, v)

func _rebuild() -> void:
	if not is_inside_tree():
		return
	var q := QuadMesh.new()
	q.size = size
	q.center_offset = Vector3(0, size.y * 0.5, 0)
	mesh = q
	_mat = PS1Convert.make(texture, {mode = "billboard" if lit else "billboard_unlit", color = color})
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_meta("ps1_no_bake", true)
	_update_frame()

func _update_frame() -> void:
	if not is_inside_tree():
		return
	var n := hframes * vframes
	var f := posmod(frame, maxi(n, 1))
	var sx := 1.0 / hframes
	var sy := 1.0 / vframes
	set_instance_shader_parameter("ps1_uv_rect", Vector4(sx, sy, (f % hframes) * sx, (f / hframes) * sy))

func _process(dt: float) -> void:
	if fps > 0.0 and hframes * vframes > 1:
		_t += dt
		var f := int(_t * fps) % (hframes * vframes)
		if f != frame:
			frame = f
