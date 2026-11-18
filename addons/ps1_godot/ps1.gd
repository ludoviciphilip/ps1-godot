## Autoload "PS1": applies the post-process to every scene and controls the global effects.
## Debug keys (only in debug builds): F1 jitter | F2 affine | F3 dither | F4 resolution | F5 color depth
## | F9 composite video filter
extends CanvasLayer

const RESOLUTIONS := [Vector2i(320, 240), Vector2i(480, 360), Vector2i(640, 480)]
var _res_index := 0


## Set to false to disable the F1-F5 debug keys.
var debug_keys := OS.is_debug_build()
const POST_SHADER := preload("res://addons/ps1_godot/shaders/ps1_post.gdshader")

## Current values of the ps1_* shader globals. RenderingServer.global_shader_parameter_get()
## only works in the editor, so the toolkit tracks the values itself.
var _globals := {}

func _ready() -> void:
	for key in ["ps1_snap_resolution", "ps1_jitter_enabled", "ps1_affine_enabled", "ps1_dither_enabled",
			"ps1_color_levels", "ps1_palette_size", "ps1_composite"]:
		var entry = ProjectSettings.get_setting("shader_globals/" + key)
		_globals[key] = entry["value"] if entry is Dictionary else null
	layer = 100
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = POST_SHADER
	rect.material = m
	add_child(rect)

## Creates a ready-to-use PS1 material (shortcut; see make() for every option).
func material(tex: Texture2D, color := Color.WHITE, uv_scale := Vector2.ONE,
		emission := Color.BLACK, emission_energy := 0.0, double_sided := false) -> ShaderMaterial:
	return PS1Convert.make(tex, {color = color, uv_scale = uv_scale, emission = emission,
		emission_energy = emission_energy, mode = "double_sided" if double_sided else "opaque"})

## Creates a PS1 material with options: color, uv_scale, emission, emission_energy,
## mode ("opaque", "double_sided", "cutout", "dither_alpha", "unlit", "unlit_cutout"),
## alpha_cut, texture_color_levels, vertex_color.
func make(tex: Texture2D, opts := {}) -> ShaderMaterial:
	return PS1Convert.make(tex, opts)

## Hides every mesh under node beyond `distance` (meters), with a dithered fade of `fade` meters.
## The classic PS1 draw distance; pair it with fog.
func draw_distance(node: Node, distance: float, fade := 3.0) -> void:
	for g in PS1LOD.geometries(node):
		g.set_instance_shader_parameter("ps1_fade", Vector4(0, 0, distance - fade, distance))
		g.visibility_range_end = distance + PS1LOD.radius(g)
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

## Flashes every mesh under node (hit feedback). Works with PS1 materials only.
func flash(node: Node, color := Color.WHITE, duration := 0.12) -> void:
	var meshes: Array[GeometryInstance3D] = []
	if node is GeometryInstance3D:
		meshes.append(node)
	for n in node.find_children("*", "GeometryInstance3D", true, false):
		meshes.append(n)
	var tw := node.create_tween()
	tw.tween_method(func(a: float) -> void:
		for m in meshes:
			if is_instance_valid(m):
				m.set_instance_shader_parameter("ps1_flash", Color(color.r, color.g, color.b, a)),
		1.0, 0.0, duration)

## Composite video filter (chroma bleed, line jitter, grain, vignette): 0 = off, 1 = full.
func set_composite(strength: float) -> void:
	set_global("ps1_composite", clampf(strength, 0.0, 1.0))

## Limits the whole screen to these colors (max 256), like a fixed hardware palette.
func set_screen_palette(colors: PackedColorArray) -> void:
	var n := mini(colors.size(), 256)
	if n == 0:
		clear_screen_palette()
		return
	var img := Image.create(n, 1, false, Image.FORMAT_RGBA8)
	for i in n:
		img.set_pixel(i, 0, colors[i])
	set_global("ps1_palette", ImageTexture.create_from_image(img))
	set_global("ps1_palette_size", float(n))

func clear_screen_palette() -> void:
	set_global("ps1_palette_size", 0.0)

## Builds a palette from the current frame (k-means) and applies it: a quick way to lock a
## scene into its own N-color look. Call it after a few frames have rendered.
func palette_from_screen(colors := 32) -> PackedColorArray:
	clear_screen_palette()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var pal := PS1Palette.palette(img, colors, 10, true)
	set_screen_palette(pal)
	return pal

## Sets a ps1_* shader global (and remembers it; see get_global()).
func set_global(param: String, value) -> void:
	_globals[param] = value
	RenderingServer.global_shader_parameter_set(param, value)

func get_global(param: String):
	return _globals.get(param)

func toggle(param: String) -> void:
	var v = get_global(param)
	set_global(param, 0.0 if v != null and float(v) > 0.5 else 1.0)
	print("%s = %s" % [param, get_global(param)])

func cycle_resolution() -> void:
	_res_index = (_res_index + 1) % RESOLUTIONS.size()
	var r: Vector2i = RESOLUTIONS[_res_index]
	get_window().content_scale_size = r
	set_global("ps1_snap_resolution", Vector2(r))
	print("base resolution = %s" % r)

func _unhandled_input(e: InputEvent) -> void:
	if not debug_keys or not (e is InputEventKey and e.pressed and not e.echo):
		return
	match e.keycode:
		KEY_F1: toggle("ps1_jitter_enabled")
		KEY_F2: toggle("ps1_affine_enabled")
		KEY_F3: toggle("ps1_dither_enabled")
		KEY_F4: cycle_resolution()
		KEY_F9:
			var cv = get_global("ps1_composite")
			set_composite(0.0 if cv != null and float(cv) > 0.0 else 1.0)
			print("composite = %s" % get_global("ps1_composite"))
		KEY_F5:
			var lv: float = float(get_global("ps1_color_levels")) if get_global("ps1_color_levels") != null else 32.0
			lv = 8.0 if lv >= 32.0 else lv * 2.0
			set_global("ps1_color_levels", lv)
			print("color levels = %s" % lv)

# ---------------- "Test here" (PS1GridLevel painter) ----------------

const _TEST_SPAWN := "user://ps1_test_spawn.json"

## For the game: where the editor asked the player to start ({} = normal start). One-shot:
## the request is consumed, so the next normal run starts normally.
##   var t := PS1.take_test_spawn(scene_file_path)
##   if t: player.global_position = t.position; player.rotation.y = t.yaw
func take_test_spawn(scene_path: String) -> Dictionary:
	if not FileAccess.file_exists(_TEST_SPAWN):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(_TEST_SPAWN))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_TEST_SPAWN))
	if not d is Dictionary or d.get("scene", "") != scene_path or Time.get_unix_time_from_system() - d.get("time", 0.0) > 120.0:
		return {}
	return {position = Vector3(d.pos[0], d.pos[1], d.pos[2]), yaw = d.yaw}
