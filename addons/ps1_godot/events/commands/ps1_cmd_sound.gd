## Play a sound (2D, at full volume) and optionally wait for it.
@tool
class_name PS1CmdSound
extends PS1Command

@export var stream: AudioStream:
	set(v): stream = v; emit_changed()
@export var volume_db := 0.0
@export var wait := false

func menu_name() -> String: return "Audio/Play Sound"
func describe() -> String:
	return "Sound " + (stream.resource_path.get_file() if stream else "(none)")
func run(ctx: PS1EventContext) -> void:
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	ctx.event.get_tree().root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	if wait:
		await p.finished
