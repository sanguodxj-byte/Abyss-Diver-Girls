extends Node
## 音频：Music / SFX / Voice / UI 四条总线（都汇入 Master），音量随存档保存（存档分区 "audio"）。
## 音效按 id 播放，同一 id 的多个变体随机挑选；文件按 audio_registry.gd 里的路径约定自动查找，缺失时静默跳过。
## 音乐按槽位播放并交叉淡化；行动中按交战状态在探索曲与战斗曲之间切换，撤离读条、Boss、结算各有专属槽。
## 界面按钮、列表、分页、弹出菜单在加入场景树时自动接上点击与悬停音效（控件 meta "sfx" / "sfx_hover" 可改 id，空串不发声）。

signal voice_finished(voice_id: String)

const Reg = preload("res://scripts/audio/audio_registry.gd")

const BUSES := ["Music", "SFX", "Voice", "UI"]
const SFX_DIR := "res://assets/audio/sfx"
const MUSIC_DIR := "res://assets/audio/music"
const VOICE_DIR := "res://assets/audio/voice"
const SFX_EXT := [".wav", ".ogg"]
const MUSIC_EXT := [".ogg", ".mp3", ".wav"]
const VOICE_EXT := [".mp3", ".ogg", ".wav"]
const MAX_VARIANTS := 12
const DEFAULT_VOLUME := {"Master": 1.0, "Music": 0.8, "SFX": 1.0, "Voice": 1.0, "UI": 0.9}

var volume := DEFAULT_VOLUME.duplicate()

var _streams := {}        ## id -> Array[AudioStream]（空数组 = 没有文件）
var _info := {}           ## id -> 合并后的参数
var _last_pick := {}
var _last_time := {}
var _pool2: Array = []
var _pool3: Array = []
var _loops := {}          ## key -> 播放器
var _decks: Array = []
var _deck_gain := [0.0, 0.0]
var _deck_tw: Array = [null, null]
var _deck := 0
var _music_streams := {}
var _music_pos := {}
var music_slot := ""
var _voice: AudioStreamPlayer
var voice_id := ""
var _save_t: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_decks.append(p)
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	add_child(_voice)
	_voice.finished.connect(func():
		var v := voice_id
		voice_id = ""
		voice_finished.emit(v))
	_save_t = Timer.new()
	_save_t.one_shot = true
	_save_t.wait_time = 0.4
	_save_t.timeout.connect(func(): GameData.save_game())
	add_child(_save_t)
	GameData.register_section("audio", _save_state, _load_state)
	get_tree().node_added.connect(_on_node_added)
	_connect_events()


# ====================================================================== 音效
## 播放一个音效。id 可以是数组：取第一个有文件的 id（用于「专属音效，没有就用通用音效」）。
## pos 为 null 时按 2D 播放；给出世界坐标时按 3D 定位（参数 d3 = false 的 id 一律 2D）。
## opts：vol（额外 dB）、pitch（固定音高倍率）、bus。返回播放器，没有播放时返回 null。
func play_sfx(id, pos = null, opts := {}) -> Node:
	var sid := ""
	var streams: Array = []
	if typeof(id) == TYPE_ARRAY:
		for x in id:
			streams = _resolve(str(x))
			if not streams.is_empty():
				sid = str(x)
				break
	else:
		sid = str(id)
		streams = _resolve(sid)
	if streams.is_empty():
		return null
	var inf := info(sid)
	var now := Time.get_ticks_msec() * 0.001
	if float(inf.gap) > 0.0 and now - float(_last_time.get(sid, -100.0)) < float(inf.gap):
		return null
	if _count_playing(sid) >= int(inf.max):
		return null
	_last_time[sid] = now
	var st: AudioStream = _pick(sid, streams)
	var d3: bool = bool(inf.d3) and pos != null and typeof(pos) == TYPE_VECTOR3
	var p: Node = _take_player(d3)
	p.stream = st
	p.bus = str(opts.get("bus", inf.bus))
	p.volume_db = float(inf.vol) + float(opts.get("vol", 0.0))
	var pv: float = float(inf.pitch)
	p.pitch_scale = float(opts.get("pitch", 1.0 + randf_range(-pv, pv)))
	p.set_meta("sfx_id", sid)
	if d3:
		p.global_position = pos
		p.unit_size = float(inf.unit)
		p.max_distance = float(inf.dist)
	p.play()
	return p


func play_ui(id: String) -> Node:
	return play_sfx(id, null, {"bus": "UI"})


## 这个 id 现在能不能播（有没有文件）
func has_sfx(id: String) -> bool:
	return not _resolve(id).is_empty()


## 合并后的参数（DEFAULT ← 前缀 ← 条目）
func info(id: String) -> Dictionary:
	if not _info.has(id):
		_info[id] = Reg.sfx_info(id, sfx_table())
	return _info[id]


## 合并了 data\ext 扩展的音效表与音乐槽表（GameData 启动时合并；合并前退回核心表）
func sfx_table() -> Dictionary:
	return GameData.SFX if not GameData.SFX.is_empty() else Reg.SFX


func music_table() -> Dictionary:
	return GameData.MUSIC if not GameData.MUSIC.is_empty() else Reg.MUSIC


## 测试与工具用：直接给某个 id 指定音频（不经过文件查找）
func set_streams(id: String, streams: Array) -> void:
	_streams[id] = streams


## 变体文件：先取登记的 files，再按命名约定补上没有登记的（<id>.wav、<id>_01.wav 起连续编号），同一路径只取一次
func _resolve(id: String) -> Array:
	if _streams.has(id):
		return _streams[id]
	var paths: Array = []
	for p: String in Reg.sfx_paths(id, sfx_table()):
		if ResourceLoader.exists(p) and not paths.has(p):
			paths.append(p)
	for ext: String in SFX_EXT:
		var p := "%s/%s%s" % [SFX_DIR, id, ext]
		if ResourceLoader.exists(p):
			if not paths.has(p):
				paths.append(p)
			break
	for i in range(1, MAX_VARIANTS + 1):
		var found := false
		for ext: String in SFX_EXT:
			var p := "%s/%s_%02d%s" % [SFX_DIR, id, i, ext]
			if ResourceLoader.exists(p):
				if not paths.has(p):
					paths.append(p)
				found = true
				break
		if not found:
			break
	var out: Array = []
	for p: String in paths:
		var s = load(p)
		if s is AudioStream:
			out.append(s)
	_streams[id] = out
	return out


func _pick(id: String, streams: Array) -> AudioStream:
	if streams.size() == 1:
		return streams[0]
	var last: int = _last_pick.get(id, -1)
	var i := randi() % streams.size()
	if i == last:
		i = (i + 1 + randi() % (streams.size() - 1)) % streams.size()
	_last_pick[id] = i
	return streams[i]


func _take_player(d3: bool) -> Node:
	var pool: Array = _pool3 if d3 else _pool2
	for p in pool:
		if not p.playing:
			return p
	if pool.size() < (32 if d3 else 24):
		var n: Node
		if d3:
			var p3 := AudioStreamPlayer3D.new()
			p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
			n = p3
		else:
			n = AudioStreamPlayer.new()
		add_child(n)
		pool.append(n)
		return n
	var oldest: Node = pool[0]
	pool.remove_at(0)
	pool.append(oldest)
	oldest.stop()
	return oldest


func _count_playing(id: String) -> int:
	var n := 0
	for pool in [_pool2, _pool3]:
		for p in pool:
			if p.playing and p.get_meta("sfx_id", "") == id:
				n += 1
	return n


# ====================================================================== 循环音效
## 开始一个循环音效。key 区分同时存在的多个循环（如每台机甲的履带声）；同一个 key 已在播放时不重复开始。
## host 不为空时播放器挂在 host 下（3D 节点跟随它移动，host 被释放时声音一起结束）；
## opts：d3（默认 host 是 3D 节点时为 true）、vol、pitch。没有文件时返回 null。
func loop_start(key: String, id: String, host: Node = null, opts := {}) -> Node:
	if _loops.has(key) and is_instance_valid(_loops[key]):
		return _loops[key]
	var streams := _resolve(id)
	if streams.is_empty():
		return null
	var inf := info(id)
	var st: AudioStream = streams[0]
	_set_loop(st, true)
	var d3: bool = bool(opts.get("d3", host is Node3D and bool(inf.d3)))
	var p: Node
	if d3:
		var p3 := AudioStreamPlayer3D.new()
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p3.unit_size = float(inf.unit)
		p3.max_distance = float(inf.dist)
		p = p3
	else:
		p = AudioStreamPlayer.new()
	p.stream = st
	p.bus = str(opts.get("bus", inf.bus))
	p.volume_db = float(inf.vol) + float(opts.get("vol", 0.0))
	p.pitch_scale = float(opts.get("pitch", 1.0))
	p.set_meta("loop_key", key)
	p.set_meta("sfx_id", id)
	(host if host != null else self).add_child(p)
	p.finished.connect(_replay_loop.bind(key, p))
	_loops[key] = p
	if p.is_inside_tree():
		p.play()
	else:
		p.tree_entered.connect(_replay_loop.bind(key, p), CONNECT_ONE_SHOT)
	return p


## 循环播放器播完一遍（或首次进入场景树）时，仍登记在册就从头再播
func _replay_loop(key: String, p: Node) -> void:
	if _loops.get(key) == p and is_instance_valid(p) and p.is_inside_tree():
		p.play()


## 调整循环音效：vol_db 为相对条目音量的 dB，pitch 为音高倍率
func loop_set(key: String, vol_db: float, pitch := 1.0) -> void:
	var p = _loops.get(key)
	if p == null or not is_instance_valid(p):
		return
	p.volume_db = float(info(str(p.get_meta("sfx_id", ""))).vol) + vol_db
	p.pitch_scale = maxf(0.05, pitch)


func loop_stop(key: String, fade := 0.15) -> void:
	var p = _loops.get(key)
	_loops.erase(key)
	if p == null or not is_instance_valid(p):
		return
	if fade <= 0.0 or not p.is_inside_tree():
		p.queue_free()
		return
	var tw: Tween = p.create_tween()
	tw.tween_property(p, "volume_db", -60.0, fade)
	tw.tween_callback(p.queue_free)


func has_loop(key: String) -> bool:
	return _loops.has(key) and is_instance_valid(_loops[key])


func stop_all_loops() -> void:
	for k in _loops.keys():
		loop_stop(k, 0.0)


## 停掉全部声音并断开音频流。退出时必须调用：正在播放的播放实例由音频服务器持有，
## 进程结束时仍按引用算作「资源还在占用」，引擎会报 resources still in use at exit。
func stop_all() -> void:
	stop_all_loops()
	if _voice:
		_voice.stop()
		_voice.stream = null
		voice_id = ""
	for pool in [_pool2, _pool3]:
		for p in pool:
			p.stop()
			p.stream = null
	for d in _decks:
		d.stop()
		d.stream = null
	_streams.clear()
	_music_streams.clear()
	music_slot = ""


func _exit_tree() -> void:
	stop_all()


func _set_loop(st: AudioStream, on: bool) -> void:
	if st is AudioStreamWAV:
		var w: AudioStreamWAV = st
		if on and w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate)
		elif not on:
			w.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif "loop" in st:
		st.set("loop", on)


# ====================================================================== 音乐
## 切到某个音乐槽（交叉淡化）。槽位没有文件时淡出当前音乐。回到循环曲时从上次离开的位置接着放。
func play_music(slot: String, fade := 1.2) -> void:
	if slot == music_slot:
		return
	var cur: AudioStreamPlayer = _decks[_deck]
	if music_slot != "" and cur.playing:
		_music_pos[music_slot] = cur.get_playback_position()
	_fade(_deck, 0.0, fade, true)
	music_slot = slot
	var st := _music_stream(slot)
	if st == null:
		return
	_deck = 1 - _deck
	var nd: AudioStreamPlayer = _decks[_deck]
	if _deck_tw[_deck]:
		_deck_tw[_deck].kill()
	nd.stop()
	nd.stream = st
	var inf := Reg.music_info(slot, music_table())
	var from: float = float(_music_pos.get(slot, 0.0)) if bool(inf.get("loop", true)) else 0.0
	if from >= st.get_length() - 0.5:
		from = 0.0
	_set_gain(_deck, 0.0)
	nd.play(from)
	_fade(_deck, 1.0, fade, false)


func stop_music(fade := 1.0) -> void:
	var cur: AudioStreamPlayer = _decks[_deck]
	if music_slot != "" and cur.playing:
		_music_pos[music_slot] = cur.get_playback_position()
	music_slot = ""
	_fade(0, 0.0, fade, true)
	_fade(1, 0.0, fade, true)


## 这个音乐槽有没有文件
func has_music(slot: String) -> bool:
	return _music_stream(slot) != null


func _music_stream(slot: String) -> AudioStream:
	if _music_streams.has(slot):
		return _music_streams[slot]
	var inf := Reg.music_info(slot, music_table())
	var st: AudioStream = null
	var names: Array = [str(inf.file)]
	for ext: String in MUSIC_EXT:
		names.append(slot + ext)
	for n: String in names:
		var p := MUSIC_DIR.path_join(n)
		if ResourceLoader.exists(p):
			st = load(p)
			if st:
				break
	if st:
		_set_loop(st, bool(inf.get("loop", true)))
	_music_streams[slot] = st
	return st


func _fade(i: int, to: float, dur: float, stop_after: bool) -> void:
	if _deck_tw[i]:
		_deck_tw[i].kill()
		_deck_tw[i] = null
	if dur <= 0.0:
		_set_gain(i, to)
		if stop_after and to <= 0.0:
			_decks[i].stop()
		return
	var tw := create_tween()
	tw.tween_method(func(g: float): _set_gain(i, g), _deck_gain[i], to, dur)
	if stop_after and to <= 0.0:
		tw.tween_callback(_decks[i].stop)
	_deck_tw[i] = tw


func _set_gain(i: int, g: float) -> void:
	_deck_gain[i] = g
	_decks[i].volume_db = linear_to_db(maxf(g, 0.0001))


# ====================================================================== 配音
## 播放一句配音（打断上一句）。返回时长（秒），没有文件时返回 0 且不发声。
func play_voice(id: String) -> float:
	var st: AudioStream = null
	for ext: String in VOICE_EXT:
		var p := "%s/%s%s" % [VOICE_DIR, id, ext]
		if ResourceLoader.exists(p):
			st = load(p)
			if st:
				break
	if st == null:
		return 0.0
	_set_loop(st, false)
	_voice.stop()
	voice_id = id
	_voice.stream = st
	_voice.play()
	return st.get_length()


func has_voice(id: String) -> bool:
	for ext: String in VOICE_EXT:
		if ResourceLoader.exists("%s/%s%s" % [VOICE_DIR, id, ext]):
			return true
	return false


func stop_voice() -> void:
	_voice.stop()
	voice_id = ""


func is_voice_playing() -> bool:
	return _voice.playing


# ====================================================================== 音量
## 线性音量 0..1；bus 为 Master / Music / SFX / Voice / UI。修改后稍后自动存档。
func set_volume(bus: String, v: float) -> void:
	volume[bus] = clampf(v, 0.0, 1.0)
	_apply_volume(bus)
	if is_inside_tree():
		_save_t.start()


func get_volume(bus: String) -> float:
	return float(volume.get(bus, 1.0))


func _apply_volume(bus: String) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(get_volume(bus), 0.0001)))


func _save_state() -> Dictionary:
	return {"volume": volume.duplicate()}


func _load_state(d: Dictionary) -> void:
	volume = DEFAULT_VOLUME.duplicate()
	var v = d.get("volume", {})
	if typeof(v) == TYPE_DICTIONARY:
		for k in v:
			volume[str(k)] = clampf(float(v[k]), 0.0, 1.0)
	for b in volume:
		_apply_volume(b)


func _ensure_buses() -> void:
	for b: String in BUSES:
		if AudioServer.get_bus_index(b) >= 0:
			continue
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, b)
		AudioServer.set_bus_send(i, "Master")


# ====================================================================== 界面自动接线
func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		if n.has_meta("_sfx_hooked"):
			return
		n.set_meta("_sfx_hooked", true)
		n.pressed.connect(_ui_press.bind(n))
		n.mouse_entered.connect(_ui_hover.bind(n))
	elif n is ItemList:
		if n.has_meta("_sfx_hooked"):
			return
		n.set_meta("_sfx_hooked", true)
		n.item_selected.connect(func(_i): _ui_meta(n, "sfx", "ui_click"))
	elif n is TabContainer:
		if n.has_meta("_sfx_hooked"):
			return
		n.set_meta("_sfx_hooked", true)
		n.tab_changed.connect(func(_i): _ui_meta(n, "sfx", "ui_tab"))
	elif n is PopupMenu:
		if n.has_meta("_sfx_hooked"):
			return
		n.set_meta("_sfx_hooked", true)
		n.id_pressed.connect(func(_i): _ui_meta(n, "sfx", "ui_click"))


func _ui_press(b: BaseButton) -> void:
	_ui_meta(b, "sfx", "ui_click")


func _ui_hover(b: BaseButton) -> void:
	if is_instance_valid(b) and not b.disabled:
		_ui_meta(b, "sfx_hover", "ui_hover")


func _ui_meta(n: Node, key: String, def: String) -> void:
	if not is_instance_valid(n):
		return
	var id := str(n.get_meta(key, def))
	if id != "":
		play_ui(id)


# ====================================================================== 随游戏事件切换音乐
var _raid_map := ""
var _in_combat := false
var _in_boss := false
var _in_extract := false

func _connect_events() -> void:
	Events.deployed.connect(func(map_id: String, _lo):
		_raid_map = map_id
		_in_combat = false
		_in_boss = false
		_in_extract = false
		_raid_music(2.0))
	Events.combat_changed.connect(func(on: bool):
		_in_combat = on
		_raid_music(1.5 if on else 3.0))
	Events.boss_appeared.connect(func(_id, _t):
		_in_boss = true
		_raid_music(0.8))
	Events.boss_defeated.connect(func(_id):
		_in_boss = false
		_raid_music(2.5))
	Events.extract_started.connect(func(_t, _n, _x):
		_in_extract = true
		_raid_music(0.6))
	Events.extract_cancelled.connect(func(_t):
		_in_extract = false
		_raid_music(1.5))
	Events.mech_destroyed.connect(func(_r):
		_raid_map = ""
		stop_music(1.2))
	Events.raid_finished.connect(func(ok: bool, _r):
		_raid_map = ""
		stop_all_loops()
		play_music("result_success" if ok else "result_fail", 0.8))
	Events.returned_to_hub.connect(func(_after):
		_raid_map = ""
		stop_all_loops()
		play_music("hangar", 1.5))


## 行动中的音乐：撤离读条 > Boss > 交战 > 本战区探索曲；对应槽没有文件时退回探索曲
func _raid_music(fade: float) -> void:
	if _raid_map == "":
		return
	var md: Dictionary = GameData.map_data(_raid_map)
	var base := str(md.get("music", _raid_map + "_explore"))
	var want := base
	if _in_extract:
		want = "extract"
	elif _in_boss:
		want = "boss"
	elif _in_combat:
		want = "combat"
	if want != base and not has_music(want):
		want = base
	play_music(want, fade)
