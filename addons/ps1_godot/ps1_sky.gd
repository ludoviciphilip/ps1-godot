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
## Apparent moon size (radius, in radians-ish) and a glow ring around it.
@export var moon_size := 0.035:
	set(v):
		moon_size = v
		_set_param("moon_size", v)
@export_range(0.0, 2.0) var moon_halo := 0.0:
	set(v):
		moon_halo = v
		_set_param("moon_halo", v)
## A glowing patch of horizon (a burning city, a sunset, a far fire): color (alpha = strength),
## direction, how narrow (bigger = narrower) and how high it reaches.
@export var glow_color := Color(0, 0, 0, 0):
	set(v):
		glow_color = v
		_set_param("glow_color", v)
@export var glow_direction := Vector3(1, 0, 0):
	set(v):
		glow_direction = v
		_set_param("glow_direction", v)
@export var glow_spread := 6.0:
	set(v):
		glow_spread = v
		_set_param("glow_spread", v)
@export var glow_height := 0.35:
	set(v):
		glow_height = v
		_set_param("glow_height", v)
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
	for k in ["zenith_color", "horizon_color", "stars", "moon_direction", "moon_size", "moon_halo", "glow_color", "glow_direction", "glow_spread", "glow_height"]:
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

## Lightning flash on the sky (0..1). PS1Backdrop.add_lightning() drives it.
func set_flash(v: float) -> void:
	_set_param("flash", v)

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
