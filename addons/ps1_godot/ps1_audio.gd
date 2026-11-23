## PS1-style audio helpers. Buses "Music" and "SFX" (SFX gets a short hardware-like reverb and
## loses the top end, like the PS1 SPU playing compressed 22 kHz samples), one-shot sounds with
## random pitch and a voice limit, and music with crossfade + loop.
##
##   PS1Audio.sound_dir = "res://assets/sfx"
##   PS1Audio.play("sword_swing", global_position)   # picks sword_swing.wav or a random sword_swing_N.wav
##   PS1Audio.play("ui_ok")                           # 2D
##   PS1Audio.music(load("res://music/boss.ogg"), 1.5)
##   PS1Audio.set_reverb(0.8, 0.35)                   # caves / crypts
class_name PS1Audio
extends RefCounted

static var sound_dir := "res://sounds"
## Same sound playing at most this many times at once (the PS1 had 24 voices in total).
static var max_voices_per_sound := 4
static var pitch_random := 0.06
static var _cache := {}
static var _voices := {}
static var _host: Node
static var _music: Array[AudioStreamPlayer] = []
static var _music_i := 0
static var _music_stream: AudioStream

static func setup() -> void:
	if AudioServer.get_bus_index("SFX") == -1:
		for bus in ["Music", "SFX"]:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
		var sfx := AudioServer.get_bus_index("SFX")
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.45; rv.damping = 0.7; rv.wet = 0.18; rv.dry = 1.0; rv.spread = 0.6
		AudioServer.add_bus_effect(sfx, rv)
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 9000.0
		AudioServer.add_bus_effect(sfx, lp)
		var mlp := AudioEffectLowPassFilter.new()
		mlp.cutoff_hz = 12000.0
		AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), mlp)
	if AudioServer.get_bus_index("Voice") == -1:   # dialogue / narration (own volume slider)
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Voice")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	if PS1Settings.is_setup:   # buses created after the settings were applied: apply volumes now
		for k in ["audio/master", "audio/music", "audio/sfx", "audio/voice"]:
			PS1Settings.set_value(k, PS1Settings.get_value(k), false)
	if not is_instance_valid(_host):
		_host = Node.new()
		_host.name = "PS1Audio"
		_host.process_mode = Node.PROCESS_MODE_ALWAYS
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_host)
		_music.clear()
		for k in 2:
			var p := AudioStreamPlayer.new()
			p.bus = "Music"
			p.volume_db = -80.0
			_host.add_child(p)
			_music.append(p)

## Reverb of the SFX bus (room 0..1, wet 0..1): small for outdoors, big for crypts.
static func set_reverb(room: float, wet: float) -> void:
	setup()
	var rv := AudioServer.get_bus_effect(AudioServer.get_bus_index("SFX"), 0) as AudioEffectReverb
	rv.room_size = room
	rv.wet = wet

## Resolves a name to a list of streams: name.wav/.ogg or name_1, name_2...
static func streams(name: String) -> Array:
	if _cache.has(name):
		return _cache[name]
	var out := []
	for ext in ["wav", "ogg", "mp3"]:
		var p := sound_dir.path_join(name + "." + ext)
		if ResourceLoader.exists(p):
			out.append(load(p))
	var k := 1
	while true:
		var found := false
		for ext in ["wav", "ogg", "mp3"]:
			var p := sound_dir.path_join("%s_%d.%s" % [name, k, ext])
			if ResourceLoader.exists(p):
				out.append(load(p)); found = true
		if not found:
			break
		k += 1
	if out.is_empty():
		push_warning("PS1Audio: no sound '%s' in %s" % [name, sound_dir])
	_cache[name] = out
	return out

## One-shot. `what` = name (see streams()) or an AudioStream. `at` = Vector3 / Node3D (3D) or null (2D).
## opts: volume_db, pitch, pitch_random, bus, max_distance, unit_size.
static func play(what, at = null, opts := {}) -> Node:
	setup()
	var list: Array = streams(what) if what is String else [what]
	if list.is_empty():
		return null
	var tree := Engine.get_main_loop() as SceneTree
	# very first frame: the host node is added deferred, use the current scene meanwhile
	var host: Node = _host if is_instance_valid(_host) and _host.is_inside_tree() else tree.current_scene
	if host == null:
		return null
	var key := str(what)
	var alive: Array = _voices.get(key, []).filter(func(n): return is_instance_valid(n))
	if alive.size() >= max_voices_per_sound:
		alive[0].queue_free()
		alive.remove_at(0)
	var s: AudioStream = list[randi() % list.size()]
	var pr: float = opts.get("pitch_random", pitch_random)
	var pitch: float = opts.get("pitch", 1.0) * (1.0 + randf_range(-pr, pr))
	var p: Node
	if at == null:
		var p2 := AudioStreamPlayer.new()
		p2.stream = s; p2.pitch_scale = pitch; p2.volume_db = opts.get("volume_db", 0.0)
		p2.bus = opts.get("bus", "SFX")
		p2.finished.connect(p2.queue_free)
		host.add_child(p2)
		p2.play()
		p = p2
	else:
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = s; p3.pitch_scale = pitch; p3.volume_db = opts.get("volume_db", 0.0)
		p3.bus = opts.get("bus", "SFX")
		p3.unit_size = opts.get("unit_size", 6.0)
		p3.max_distance = opts.get("max_distance", 45.0)
		p3.attenuation_filter_cutoff_hz = 6000.0
		p3.finished.connect(p3.queue_free)
		var parent: Node = at if at is Node3D and opts.get("follow", false) else (tree.current_scene if tree.current_scene else host)
		parent.add_child(p3)
		if not (at is Node3D and opts.get("follow", false)):
			p3.global_position = at.global_position if at is Node3D else at
		p3.play()
		p = p3
	alive.append(p)
	_voices[key] = alive
	return p

## Looping 3D sound attached to a node (fire crackle, waterfall...). Returns the player.
static func loop(what, parent: Node3D, volume_db := 0.0, unit_size := 4.0) -> AudioStreamPlayer3D:
	setup()
	var list: Array = streams(what) if what is String else [what]
	if list.is_empty():
		return null
	var s: AudioStream = list[0].duplicate()
	if "loop" in s: s.loop = true
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = int(s.get_length() * s.mix_rate)
	var p := AudioStreamPlayer3D.new()
	p.stream = s; p.bus = "SFX"; p.volume_db = volume_db; p.unit_size = unit_size; p.max_distance = 25.0
	p.autoplay = true
	parent.add_child(p)
	return p

## Music with crossfade. Same stream again = keeps playing. null = fade out.
static func music(stream: AudioStream, fade := 1.5, volume_db := 0.0) -> void:
	setup()
	if _music.is_empty():
		return
	if stream == _music_stream and stream != null:
		return
	_music_stream = stream
	var old := _music[_music_i]
	if not _music[0].is_inside_tree():
		# host not in the tree yet (very first frame): try again next frame
		(Engine.get_main_loop() as SceneTree).process_frame.connect(func(): _music_stream = null; music(stream, fade, volume_db), CONNECT_ONE_SHOT)
		return
	if old.playing:
		_music_fade(old, -80.0, fade, true)
	if stream:
		_music_i = 1 - _music_i
		var nw := _music[_music_i]
		var s := stream
		if "loop" in s: s.loop = true
		nw.stream = s
		nw.volume_db = -40.0
		nw.play()
		_music_fade(nw, volume_db, fade, false)

# One tween per player: a quick A -> B -> C switch reuses A's player while its fade-out (which
# ends in stop()) is still running — without killing it, the new track got faded out and stopped,
# and the music went silent.
static func _music_fade(p: AudioStreamPlayer, to: float, fade: float, stop_after: bool) -> void:
	var old_tw: Tween = p.get_meta("ps1_fade") if p.has_meta("ps1_fade") else null
	if old_tw and old_tw.is_valid():
		old_tw.kill()
	var tw := p.create_tween()
	tw.tween_property(p, "volume_db", to, fade)
	if stop_after:
		tw.tween_callback(p.stop)
	p.set_meta("ps1_fade", tw)

static func current_music() -> AudioStream:
	return _music_stream
