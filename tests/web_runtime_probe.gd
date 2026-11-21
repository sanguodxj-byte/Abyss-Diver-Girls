extends Node
## Browser-only diagnostic harness, excluded from the player export.
const START := "menu"
const AP = preload("res://scripts/asset_paths.gd")
const Prof = preload("res://scripts/prof.gd")
var _cb
var _elapsed := 0.0

func _ready() -> void:
	if not OS.has_feature("web"):
		get_tree().quit()
		return
	_cb = JavaScriptBridge.create_callback(_command)
	JavaScriptBridge.get_interface("window").gameProbe = _cb
	preload("res://scripts/raid.gd").force_async_load = true
	Prof.on = true

func _command(args: Array) -> void:
	match str(args[0]):
		"audio":
			Audio.stop_music(0.0)
			Audio.play_music("menu", 0.0)
			Audio.play_ui("ui_click")
		"stream":
			for p in Audio._decks:
				p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
			Audio.stop_music(0.0)
			Audio.play_music("menu", 0.0)
		"hub":
			GameData.new_game()
			get_parent().show_hub()
		"raid":
			get_parent().start_raid()
		"menu":
			get_parent().show_menu()
		"portraits":
			var p = preload("res://scripts/story/dialogue_player.gd").PortraitPlace.new()
			var a = preload("res://scripts/story/radio_window.gd").AvatarMark.new()
			add_child(p)
			add_child(a)
			p.set_tex(AP.portrait("nao"))
			a.set_char("rei", "smile")
			assert(p.tex != null and a.tex != null)
			assert(p.view == null and a._view == null)
			assert(AP.portrait_clip("nao") == "" and AP.radio_clip("rei") == "")
			assert(not p.is_processing() and not a.is_processing())
			print("[web_probe] static portraits PASS")
			p.queue_free()
			a.queue_free()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 1.0 or not OS.has_feature("web"):
		return
	_elapsed = 0.0
	var decks := []
	for p in Audio._decks:
		decks.append({"playing": p.playing, "position": p.get_playback_position(), "volume": p.volume_db,
			"stream": p.stream.resource_path if p.stream else "", "type": p.playback_type})
	var r = get_parent().raid
	var d := {"fps": Engine.get_frames_per_second(), "draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"decks": decks, "audio_volume": Audio.volume, "audio_driver": AudioServer.get_driver_name(),
		"playback_default": ProjectSettings.get_setting("audio/general/default_playback_type"), "sfx_cached": Audio._streams.size(),
		"phases": r._tphase if is_instance_valid(r) else {}, "profile": Prof.take()}
	JavaScriptBridge.eval("window.gameMetrics = " + JSON.stringify(d))
