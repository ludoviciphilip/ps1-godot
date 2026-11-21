## PS1Loader demo: loads the procedural demo (which generates + bakes a map at runtime) behind
## the loading screen. Args: -- --shot=PATH (screenshot of the loading screen mid-way)
extends Node

func _ready() -> void:
	PS1Loader.tips = ["Tip: the loading screen waits for runtime bakes, so you never see an unlit level."]
	# a watcher on the root survives the scene change (this node doesn't)
	var w := Node.new()
	w.set_script(preload("res://demo/loader_watch.gd"))
	get_tree().root.add_child.call_deferred(w)
	PS1Loader.change_scene("res://demo/procgen_demo.tscn")
