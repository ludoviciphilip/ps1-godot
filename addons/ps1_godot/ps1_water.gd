## PS1-style water surface: a subdivided plane with vertex waves, two scrolling affine
## texture layers and dithered transparency. Size is in meters (X/Z), centered on the node.
@tool
class_name PS1Water
extends MeshInstance3D

@export var size := Vector2(8, 8):
	set(v):
		size = v
		_rebuild()
## Quads per meter. Waves and per-vertex lighting need vertices.
@export var density := 1.5:
	set(v):
		density = v
		_rebuild()
@export var color := Color(0.35, 0.5, 0.62, 0.7):
	set(v):
		color = v
		_param("color", v)
@export var wave_height := 0.06:
	set(v):
		wave_height = v
		_param("wave_height", v)
## Faint self-glow (a fake sky/fog reflection that keeps night water readable). Tint it to the
## room: bluish under the sky, sick green in a sewer, 0 energy for black water.
@export var glow_color := Color(0.25, 0.32, 0.45):
	set(v):
		glow_color = v
		_param("emission_color", v)
@export var glow_energy := 0.35:
	set(v):
		glow_energy = v
		_param("emission_energy", v)
@export var texture: Texture2D:
	set(v):
		texture = v
		_param("water_tex", v)

var _mat: ShaderMaterial

func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://addons/ps1_godot/shaders/ps1_water.gdshader")
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if texture == null:
		texture = water_texture()
	_param("water_tex", texture)
	_param("color", color)
	_param("wave_height", wave_height)
	_param("uv_scale", size / 2.0)
	_param("emission_color", glow_color)
	_param("emission_energy", glow_energy)
	_rebuild()

func _param(k: String, v) -> void:
	if _mat:
		_mat.set_shader_parameter(k, v)

func _rebuild() -> void:
	if not is_inside_tree():
		return
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = maxi(int(size.x * density), 1)
	pm.subdivide_depth = maxi(int(size.y * density), 1)
	mesh = pm
	_param("uv_scale", size / 2.0)

## Procedural ripple texture (32x32, few levels).
static func water_texture(seed_ := 3) -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	var n := FastNoiseLite.new()
	n.seed = seed_
	n.frequency = 0.18
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	for y in 32:
		for x in 32:
			var v := 0.55 + 0.45 * n.get_noise_2d(x, y)
			v = floor(v * 5.0) / 5.0
			img.set_pixel(x, y, Color(v, v, v))
	return ImageTexture.create_from_image(img)
