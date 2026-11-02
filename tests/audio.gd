extends "res://tests/lib/test_base.gd"
## 音频与事件总线：四条总线、缺文件静默、变体随机且不连续重复、最小间隔、3D / 2D 播放器选择、循环音效、
## 音量换算、界面按钮自动接线、事件转发到 any、随事件切换音乐槽。godot --headless --path . -- --audio
const START := "none"


func run() -> void:
	await frames(1)
	for b: String in Audio.BUSES:
		var i := AudioServer.get_bus_index(b)
		if not check(i >= 0 and AudioServer.get_bus_send(i) == "Master", "总线 %s 不存在或没有汇入 Master" % b):
			return
	# 缺文件：静默返回 null
	if not check(Audio.play_sfx("zz_missing_sfx") == null and Audio.play_voice("zz_missing_voice") == 0.0 and not Audio.has_music("zz_missing_slot"), "缺文件时应静默跳过"):
		return
	if not check(Audio.loop_start("zz_loop", "zz_missing_loop") == null and not Audio.has_loop("zz_loop"), "缺文件的循环音效不应开始"):
		return
	# 变体随机、不连续重复
	var s1 := _tone(0.4)
	var s2 := _tone(0.4)
	var s3 := _tone(0.4)
	Audio.set_streams("zz_var", [s1, s2, s3])
	var last = null
	var seen := {}
	for i in 30:
		var pk = Audio._pick("zz_var", [s1, s2, s3])
		if not check(pk != last, "变体连续重复"):
			return
		last = pk
		seen[pk] = true
	if not check(seen.size() == 3, "30 次挑选没有用到全部 3 个变体"):
		return
	# 最小间隔：mech_hurt 的 gap = 0.12 秒
	Audio.set_streams("mech_hurt", [s1])
	var a = Audio.play_sfx("mech_hurt")
	var b2 = Audio.play_sfx("mech_hurt")
	if not check(a != null and b2 == null, "gap 内的第二次播放应被跳过"):
		return
	var t0 := Time.get_ticks_msec()
	await wait_real(0.2)
	var c3 = Audio.play_sfx("mech_hurt")
	if not check(c3 != null, "过了 gap 应能再次播放（间隔 %d ms，正在播放 %d 个，参数 %s）" % [Time.get_ticks_msec() - t0, Audio._count_playing("mech_hurt"), Audio.info("mech_hurt")]):
		return
	# 数组 id：取第一个有文件的
	var p = Audio.play_sfx(["zz_none", "zz_var"])
	if not check(p != null and p.get_meta("sfx_id") == "zz_var", "数组 id 应退回到有文件的 id"):
		return
	# 3D / 2D：给位置时用 AudioStreamPlayer3D；d3 = false 的前缀（ui_）一律 2D
	if not check(Audio.play_sfx("zz_var", Vector3(1, 2, 3)) is AudioStreamPlayer3D, "带位置的音效应为 3D"):
		return
	Audio.set_streams("ui_zz", [s1])
	if not check(Audio.play_sfx("ui_zz", Vector3(1, 2, 3)) is AudioStreamPlayer, "界面音效应为 2D"):
		return
	# 循环：挂在宿主下，宿主释放后结束
	Audio.set_streams("zz_loopok", [_tone(0.3)])
	var host := Node3D.new()
	add_child(host)
	var lp = Audio.loop_start("zz_lk", "zz_loopok", host)
	await frames(2)
	if not check(lp != null and Audio.has_loop("zz_lk") and lp.get_parent() == host and lp.playing, "循环音效没有在宿主下播放"):
		return
	Audio.loop_set("zz_lk", -6.0, 1.2)
	if not check(is_equal_approx(lp.pitch_scale, 1.2), "loop_set 没有生效"):
		return
	host.queue_free()
	await frames(2)
	if not check(not Audio.has_loop("zz_lk"), "宿主释放后循环音效应结束"):
		return
	# 音量：线性 0..1 对应总线 dB
	Audio.set_volume("SFX", 0.5)
	if not check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")) - linear_to_db(0.5)) < 0.01, "音量没有换算到总线"):
		return
	Audio.set_volume("SFX", 1.0)
	# 界面按钮自动接线：默认 ui_click，meta sfx = "" 不发声
	Audio.set_streams("ui_click", [s1])
	var btn := Button.new()
	add_child(btn)
	var silent := Button.new()
	silent.set_meta("sfx", "")
	add_child(silent)
	Audio._last_time.erase("ui_click")
	silent.pressed.emit()
	if not check(not Audio._last_time.has("ui_click"), "meta sfx 为空串的按钮不应发声"):
		return
	btn.pressed.emit()
	if not check(Audio._last_time.has("ui_click"), "按钮没有自动接上 ui_click"):
		return
	# 事件总线：具名信号转发到 any，custom 以自己的事件名转发
	var got := []
	var f := func(e: String, args: Dictionary): got.append([e, args])
	Events.any.connect(f)
	Events.drop_landed.emit(Vector3(1, 0, 2))
	Events.emit_custom("zz_custom", {"k": 3})
	Events.any.disconnect(f)
	if not check(got.size() == 2 and got[0][0] == "drop_landed" and got[0][1].get("pos") == Vector3(1, 0, 2) and got[1][0] == "zz_custom" and got[1][1].get("k") == 3, "事件没有正确转发到 any：%s" % [got]):
		return
	if not check(Events.args_of("player_damaged") == ["amount", "hp", "max_hp"], "args_of 返回的参数名不对：%s" % [Events.args_of("player_damaged")]):
		return
	# 音乐槽随事件切换（直接给槽位装上测试音频）
	for slot in ["greyport_explore", "combat", "extract", "result_success", "hangar"]:
		var t := _tone(2.0)
		t.loop_mode = AudioStreamWAV.LOOP_FORWARD
		t.loop_end = int(t.get_length() * t.mix_rate)
		Audio._music_streams[slot] = t
	var steps := [
		[func(): Events.deployed.emit("greyport", {}), "greyport_explore"],
		[func(): Events.combat_changed.emit(true), "combat"],
		[func(): Events.extract_started.emit("撤离点 A", 8.0, false), "extract"],
		[func(): Events.extract_cancelled.emit("撤离点 A"), "combat"],
		[func(): Events.combat_changed.emit(false), "greyport_explore"],
		[func(): Events.raid_finished.emit(true, {}), "result_success"],
		[func(): Events.returned_to_hub.emit(true), "hangar"],
	]
	for st in steps:
		st[0].call()
		if not check(Audio.music_slot == st[1], "音乐槽应为 %s，实际 %s" % [st[1], Audio.music_slot]):
			return
	Audio.stop_music(0.0)


## 生成一段静音的 16 位单声道 WAV
func _tone(sec: float) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	w.stereo = false
	var data := PackedByteArray()
	data.resize(int(22050 * sec) * 2)
	w.data = data
	return w
