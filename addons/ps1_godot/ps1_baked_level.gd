@tool
## Put your static level geometry under this node: at runtime it loads the baked lighting
## from its cache instantly (or bakes and saves it the first time). Use the "PS1 Bake" button
## in the 3D editor toolbar to (re)bake the open scene with one click.
@icon("res://addons/ps1_godot/icons/baked_level.svg")
class_name PS1BakedLevel
extends Node3D

signal baked(from_cache: bool)

@export var ambient := Color(0.2, 0.2, 0.25)
@export var shadows := true
## Empty = res://ps1_bake_cache/<scene>_<node>.res
@export var cache_path := ""
## Lights to bake. Empty = every visible light in the scene.
@export var lights: Array[Light3D] = []

var is_baked := false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("ps1_baked_level")
	# Let sibling nodes (lights, spawned props) enter the tree first.
	await get_tree().process_frame
	var args := OS.get_cmdline_user_args()
	if args.has("--ps1-bake-force"):
		var path := resolved_cache_path()
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var from_cache := await PS1Bake.bake_scene_cached(self, ambient, resolved_cache_path(), shadows, lights)
	is_baked = true
	baked.emit(from_cache)
	print("PS1BakedLevel %s: %s (%s)" % [name, "loaded from cache" if from_cache else "baked + saved", resolved_cache_path()])
	if args.has("--ps1-bake-only"):
		for n in get_tree().get_nodes_in_group("ps1_baked_level"):
			if not n.is_baked:
				return
		get_tree().quit()

func resolved_cache_path() -> String:
	if cache_path != "":
		return cache_path
	var scene_file := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	return "res://ps1_bake_cache/%s_%s.res" % [scene_file.get_file().get_basename() if scene_file else "scene", name]
