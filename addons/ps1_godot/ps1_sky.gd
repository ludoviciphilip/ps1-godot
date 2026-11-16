## PS1-style sky: a low-poly dome that follows the active camera. By default the horizon
## takes the fog color of the scene's Environment so the sky melts into the fog.
@tool
class_name PS1Sky
extends MeshInstance3D

@export var zenith_color := Color(0.02, 0.03, 0.07):
	set(v):
		zenith_color = v
		_set_param("zenith_color", v)
@export var horizon_color := Color(0.03, 0.04, 0.05):
	set(v):
		horizon_color = v
		_set_param("horizon_color", v)
## Use the Environment fog color as horizon color (recommended).
@export var match_fog := true
@export var clouds: Texture2D:
	set(v):
		clouds = v
		_set_param("clouds_tex", v)
@export var stars := 0.6:
	set(v):
		stars = v
		_set_param("stars", v)
@export var moon_direction := Vector3(0.4, 0.45, -0.8):
	set(v):
		moon_direction = v
		_set_param("moon_direction", v)
## Dome radius; keep it inside the camera's far distance.
@export var radius := 50.0

var _mat: ShaderMaterial

func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	mesh = sphere
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://addons/ps1_godot/shaders/ps1_sky.gdshader")
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0
	for k in ["zenith_color", "horizon_color", "stars", "moon_direction"]:
		_set_param(k, get(k))
	if clouds:
		_set_param("clouds_tex", clouds)

func _set_param(k: String, v) -> void:
	if _mat:
		_mat.set_shader_parameter(k, v)

func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam:
		global_position = cam.global_position
	if match_fog and _mat:
		var env := get_world_3d().environment if get_world_3d() else null
		if env == null:
			var we := get_tree().root.find_children("*", "WorldEnvironment", true, false)
			env = we[0].environment if not we.is_empty() else null
		if env and env.fog_enabled:
			_mat.set_shader_parameter("horizon_color", env.fog_light_color)

## Simple procedural cloud texture (64x64, 4 grey levels).
static func cloud_texture(seed_ := 5) -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var n := FastNoiseLite.new()
	n.seed = seed_
	n.frequency = 0.08
	n.fractal_octaves = 3
	for y in 64:
		for x in 64:
			var v := clampf((n.get_noise_2d(x, y) + 0.1) * 2.2, 0.0, 1.0)
			v = floor(v * 4.0) / 4.0
			img.set_pixel(x, y, Color(v, v, v))
	var tex := ImageTexture.create_from_image(img)
	return tex
