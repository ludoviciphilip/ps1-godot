## Autoload "PS1": applies the post-process to every scene and controls the global effects.
## Debug keys (only in debug builds): F1 jitter | F2 affine | F3 dither | F4 resolution | F5 color depth
## | F9 composite video filter | F10 CRT
extends CanvasLayer

const RESOLUTIONS := [Vector2i(320, 240), Vector2i(480, 360), Vector2i(640, 480)]
var _res_index := 0


## Set to false to disable the F1-F5 debug keys.
var debug_keys := OS.is_debug_build()
const GLOBAL_DEFAULTS := {"ps1_snap_resolution": null, "ps1_jitter_enabled": null, "ps1_affine_enabled": null,
	"ps1_dither_enabled": null, "ps1_color_levels": null, "ps1_palette_size": null, "ps1_composite": 0.0, "ps1_crt": 0.0}
const POST_SHADER := preload("res://addons/ps1_godot/shaders/ps1_post.gdshader")

## Current values of the ps1_* shader globals. RenderingServer.global_shader_parameter_get()
## only works in the editor, so the toolkit tracks the values itself.
var _globals := {}
var _post: ShaderMaterial
var _base_scale_mode := Window.CONTENT_SCALE_MODE_VIEWPORT
var _base_size := Vector2i(320, 240)

func _ready() -> void:
	# Globals added in newer versions may be missing from older projects: add them at runtime.
	for key in GLOBAL_DEFAULTS:
		var entry = ProjectSettings.get_setting("shader_globals/" + key)
		if entry is Dictionary:
			_globals[key] = entry["value"]
		elif GLOBAL_DEFAULTS[key] != null:
			RenderingServer.global_shader_parameter_add(key, RenderingServer.GLOBAL_VAR_TYPE_FLOAT, GLOBAL_DEFAULTS[key])
			_globals[key] = GLOBAL_DEFAULTS[key]
		else:
			_globals[key] = null
	layer = 100
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = POST_SHADER
	rect.material = m
	_post = m
	add_child(rect)
	_base_scale_mode = get_window().content_scale_mode
	_base_size = get_window().content_scale_size
	get_viewport().size_changed.connect(_update_low_res)
	_update_low_res()
	# Saved settings (PS1Settings): applied after every autoload/main scene _ready, so the game
	# can register its own options and rebindable actions first (or call setup() itself).
	(func(): if not PS1Settings.is_setup: PS1Settings.setup()).call_deferred()

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
	for n in ([node] if node is GeometryInstance3D else []) + node.find_children("*", "GeometryInstance3D", true, false):
		if _has_shader_material(n):
			meshes.append(n)
	var tw := node.create_tween()
	tw.tween_method(func(a: float) -> void:
		for m in meshes:
			if is_instance_valid(m):
				m.set_instance_shader_parameter("ps1_flash", Color(color.r, color.g, color.b, a)),
		1.0, 0.0, duration)

## Instance uniforms only exist on shader materials: setting one on a surface without a material
## (or on a Label3D) floods the log with errors.
static func _has_shader_material(g: GeometryInstance3D) -> bool:
	if g.material_override:
		return g.material_override is ShaderMaterial
	if g is MeshInstance3D and (g as MeshInstance3D).mesh:
		var mi := g as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			if not mi.get_active_material(i) is ShaderMaterial:
				return false
		return mi.mesh.get_surface_count() > 0
	return false

## CRT pass at the monitor's native resolution: scanlines, aperture grille, curvature
## (0 = off, 1 = full). While on, the game renders at native resolution and the post-process
## samples it on the low-res grid, so the picture itself doesn't change (costs more GPU).
func set_crt(strength: float) -> void:
	strength = clampf(strength, 0.0, 1.0)
	var w := get_window()
	if strength > 0.0 and w.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT:
		w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	elif strength <= 0.0 and w.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS \
			and _base_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT:
		w.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	set_global("ps1_crt", strength)
	_update_low_res.call_deferred()
	if not get_window().size_changed.is_connected(_update_low_res):
		get_window().size_changed.connect(_update_low_res)

## Internal (rendering) resolution as a multiple of the project's base resolution: 1 = the
## authentic PS1 grid, 2 = twice as sharp. Vertex snapping follows it.
func set_internal_resolution(scale: float) -> void:
	var r := Vector2i(roundi(_base_size.x * scale), roundi(_base_size.y * scale))
	get_window().content_scale_size = r
	set_global("ps1_snap_resolution", Vector2(r))
	_update_low_res.call_deferred()

## Overall brightness (gamma): 1 = as rendered, 1.3 = brighter darks.
func set_brightness(value: float) -> void:
	_post.set_shader_parameter("brightness", clampf(value, 0.3, 3.0))

## Tweak the CRT look: curvature, scanlines, mask (aperture grille), brightness.
func crt_params(curvature := 0.08, scanlines := 0.6, mask := 0.25, brightness := 1.35) -> void:
	_post.set_shader_parameter("crt_curvature", curvature)
	_post.set_shader_parameter("crt_scanlines", scanlines)
	_post.set_shader_parameter("crt_mask", mask)
	_post.set_shader_parameter("crt_brightness", brightness)

## The low-res grid = the canvas size (base resolution widened by stretch aspect "expand").
## Projects that don't render at a low base resolution (stretch mode disabled) get the snap grid
## (e.g. 240 lines) so the CRT always has a console-like signal to draw.
func _update_low_res() -> void:
	if not _post:
		return
	var low := get_viewport().get_visible_rect().size
	if _base_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED:
		var snap = get_global("ps1_snap_resolution")
		var h: float = snap.y if snap is Vector2 else 240.0
		var win := Vector2(get_window().size)
		low = Vector2(roundf(h * win.x / maxf(win.y, 1.0)), h)
	_post.set_shader_parameter("low_res", low)

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
	set_internal_resolution([1.0, 1.5, 2.0][_res_index])
	print("base resolution = %s" % get_window().content_scale_size)

func _unhandled_input(e: InputEvent) -> void:
	if PS1PauseMenu.open_action != &"" and e.is_action_pressed(PS1PauseMenu.open_action) and not e.is_echo() \
			and PS1PauseMenu.can_open.call():
		get_viewport().set_input_as_handled()
		PS1PauseMenu.open()
		return
	if not debug_keys or not (e is InputEventKey and e.pressed and not e.echo):
		return
	match e.keycode:
		KEY_F1: toggle("ps1_jitter_enabled")
		KEY_F2: toggle("ps1_affine_enabled")
		KEY_F3: toggle("ps1_dither_enabled")
		KEY_F4: cycle_resolution()
		KEY_F10:
			var cr = get_global("ps1_crt")
			set_crt(0.0 if cr != null and float(cr) > 0.0 else 1.0)
			print("crt = %s" % get_global("ps1_crt"))
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
