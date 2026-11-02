extends Node
## 剧情流程：订阅事件总线，按 data\story 里写的 trigger / once / flag 规则挑出场景并排进队列。
##   · 出击简报、结算后、章节过场、支线解锁等发生在安全时机的场景交给全屏对话演出（scripts\story\dialogue_player.gd）；
##   · 行动中的节点剧情（遭遇、POI、Boss 登场、能源告警……）拆成逐句的无线电通讯交给 HUD 挂上来的小窗，
##     不暂停、不接管输入；
##   · 同一条事件只播最高优先级的通讯；档案图鉴按 unlock 条件解锁；演出进度写进 Story.progress，载入后接着播。
## 测试运行默认不开自动播剧情（自动播放会把其它测试的输入与空投流程暂停），测试用 Story.play_scene / Story.play_comms 显式调用。

const DialogueScript = preload("res://scripts/story/dialogue_player.gd")
const StoryData = preload("res://scripts/story/story_data.gd")

## 这些事件发生在行动里：对应场景按无线电逐句播出
const RAID_EVENTS := ["drop_landed", "box_opened", "item_revealed", "item_picked", "cargo_full", "overload_changed",
	"enemy_seen", "enemy_killed", "nest_destroyed", "combat_changed", "player_damaged", "part_destroyed", "skill_used",
	"item_used", "energy_low", "emergency_entered", "emergency_exited", "extract_started", "extract_cancelled",
	"extract_completed", "transport_called", "transport_landed", "transport_departed", "poi_discovered",
	"district_entered", "boss_appeared", "boss_phase_changed", "boss_defeated"]
const MAX_QUEUE := 12
const RADIO_PRIORITY := 6

var auto_scenes := not GameData.is_test_run()   ## 自动把触发到的场景交给对话演出
var auto_comms := true                         ## 自动把触发到的通讯交给无线电小窗
var player                                       ## 正在播放的对话演出
var radio                                        ## HUD 挂上来的无线电小窗
var queue: Array = []                            ## 待播场景 [{"id": 场景 id, "line": 起始句}]
var current := ""                                ## 正在播放的场景 id
var last_comms := {}                             ## 通讯 id -> 上次播出的秒数（同一条通讯的冷却）

var _seq := 0
var _fired := {}                                 ## 事件序号 -> {场景 id: true}：同一事件的两遍匹配不重复排场景
var _in_handler := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.any.connect(_on_any)
	Events.deployed.connect(_on_deployed)
	_resume.call_deferred()


func _resume() -> void:
	_unlock_free_codex()
	if not auto_scenes:
		return
	var p: Dictionary = Story.progress
	var sid := str(p.get("scene", ""))
	if sid == "":
		return
	var s: Dictionary = Story.scene(sid)
	if s.is_empty():
		Story.clear_progress()
		return
	# 演出进度随存档保存：载入后从这里接着播，Esc 与跳过仍然随时可结束
	play_now(sid, int(p.get("line", 0)))


func _on_deployed(_map_id: String, _lo: Dictionary) -> void:
	last_comms.clear()


# ============================================================ 事件入口
func _on_any(event: String, args: Dictionary) -> void:
	if _in_handler or event == "":
		return
	_in_handler = true
	var ctx := _context(event, args)
	_seq += 1
	var token := _seq
	var fired := false
	if auto_scenes:
		fired = _try_scenes(event, ctx, token)
	if auto_comms and not fired:
		_try_comms(event, ctx)
	_check_codex(event, ctx)
	_in_handler = false
	if auto_scenes:
		call_deferred("_second_pass", event, ctx, token)


## 第二遍：同一个事件的后处理方可能刚刚写入 flag（章节完成、好感升级），补上第一遍条件还不成立的场景
func _second_pass(event: String, ctx: Dictionary, token: int) -> void:
	if not is_inside_tree():
		return
	if auto_scenes:
		_try_scenes(event, ctx, token)
	_fired.erase(token)


## 事件参数补全：变体物品按基础 id 匹配，行动结束带上战区，所有事件都能按 map_id 筛
func _context(_event: String, args: Dictionary) -> Dictionary:
	var a: Dictionary = args.duplicate(true)
	if a.has("item_id"):
		var raw := str(a.item_id)
		a["item_id"] = GameData.base_id(raw)
		a["variant_id"] = raw
	if a.has("result") and typeof(a.result) == TYPE_DICTIONARY:
		var r: Dictionary = a.result
		if r.has("map_id") and not a.has("map_id"):
			a["map_id"] = str(r.map_id)
	if not a.has("map_id"):
		a["map_id"] = str(GameData.map_id)
	return a


# ============================================================ 场景
func _try_scenes(event: String, ctx: Dictionary, token: int) -> bool:
	var hits := _match_scenes(event, ctx, token)
	if hits.is_empty():
		return false
	var as_radio := event in RAID_EVENTS and radio != null and is_instance_valid(radio)
	for sid: String in hits:
		if not _fired.has(token):
			_fired[token] = {}
		_fired[token][sid] = true
		if as_radio:
			_queue_radio_scene(sid)
		else:
			_queue_scene(sid, 0)
	return true


func _match_scenes(event: String, ctx: Dictionary, token: int) -> Array:
	var out: Array = []
	var fired_tokens: Dictionary = _fired.get(token, {})
	for part in ["main", "side"]:
		var d: Dictionary = Story.data.get(part, {})
		for sid in d:
			var id := str(sid)
			if fired_tokens.has(id) or _queued(id):
				continue
			var s = d[sid]
			if typeof(s) != TYPE_DICTIONARY:
				continue
			if bool(s.get("once", true)) and Story.was_seen(id):
				continue
			var t = s.get("trigger")
			if typeof(t) != TYPE_DICTIONARY or str(t.get("event", "")) != event:
				continue
			var when = t.get("when", {})
			if typeof(when) != TYPE_DICTIONARY:
				continue
			if StoryData.match_when(when, ctx, Story.flags, Story.chapter, str(GameData.map_id)):
				out.append(id)
	return out


func _queued(sid: String) -> bool:
	if current == sid:
		return true
	for e in queue:
		if str(e.get("id", "")) == sid:
			return true
	return false


func _queue_scene(sid: String, line: int) -> void:
	if queue.size() >= MAX_QUEUE:
		return
	queue.append({"id": sid, "line": max(0, line)})
	if player == null and current == "":
		_play_next()


func _play_next() -> void:
	if player != null:
		return
	while not queue.is_empty():
		var e: Dictionary = queue.pop_front()
		var sid := str(e.get("id", ""))
		var s: Dictionary = Story.scene(sid)
		if s.is_empty():
			continue
		_open_scene(sid, s, int(e.get("line", 0)))
		return


func _open_scene(sid: String, s: Dictionary, line: int) -> void:
	current = sid
	# 全屏演出接管画面与配音：无线电小窗里排队的通讯与正在播的语音让位，退出演出后不再补播
	if radio != null and is_instance_valid(radio):
		radio.clear()
	Story.mark_seen(sid)
	_apply_scene_flags(s)
	Story.set_progress(sid, line)
	GameData.save_game()
	player = DialogueScript.new()
	add_child(player)
	player.finished.connect(_on_dialogue_finished)
	player.open(Story, s, sid, line)
	Events.emit_custom("story_scene_started", {"scene_id": sid})


func _on_dialogue_finished(reason: String) -> void:
	var sid := current
	player = null
	current = ""
	Story.clear_progress()
	GameData.save_game()
	Events.emit_custom("story_scene_finished", {"scene_id": sid, "reason": reason})
	_play_next()


## 场景里写的 set_flag：字符串、字符串数组，或 {flag: 值} 字典；场景一开始就写入，跳过也照常生效
func _apply_scene_flags(s: Dictionary) -> void:
	var f = s.get("set_flag")
	match typeof(f):
		TYPE_STRING:
			if str(f) != "":
				Story.set_flag(str(f), true)
		TYPE_ARRAY:
			for x in f:
				Story.set_flag(str(x), true)
		TYPE_DICTIONARY:
			for k in f:
				Story.set_flag(str(k), f[k])


## 行动中的剧情：逐句交给无线电小窗，不暂停、不接管输入
func _queue_radio_scene(sid: String) -> void:
	var s: Dictionary = Story.scene(sid)
	if s.is_empty() or radio == null or not is_instance_valid(radio):
		return
	Story.mark_seen(sid)
	_apply_scene_flags(s)
	var lines: Array = s.get("lines", [])
	for i in lines.size():
		var ln = lines[i]
		if typeof(ln) != TYPE_DICTIONARY:
			continue
		radio.push(_line_entry(ln, "%s_%d" % [sid, i], RADIO_PRIORITY))
	Events.emit_custom("story_radio_scene", {"scene_id": sid, "lines": lines.size()})
	GameData.save_game()


func _line_entry(ln: Dictionary, id: String, priority: int) -> Dictionary:
	var sp := str(ln.get("speaker", ""))
	var c: Dictionary = Story.character(sp)
	return {"id": id, "speaker": sp, "expr": str(ln.get("expr", "")), "name": str(c.get("name_zh", "")),
		"zh": str(ln.get("zh", "")), "voice": str(ln.get("voice", "")), "priority": priority}


# ============================================================ 无线电通讯
func _try_comms(event: String, ctx: Dictionary) -> void:
	if radio == null or not is_instance_valid(radio):
		return
	if player != null:
		return
	var now := Time.get_ticks_msec() * 0.001
	var best := -9999
	var cands: Array = []
	for c in Story.data.get("comms", []):
		if typeof(c) != TYPE_DICTIONARY or str(c.get("event", "")) != event:
			continue
		var when = c.get("when", {})
		if typeof(when) == TYPE_DICTIONARY and not when.is_empty():
			if not StoryData.match_when(when, ctx, Story.flags, Story.chapter, str(GameData.map_id)):
				continue
		var id := str(c.get("id", ""))
		var cd := float(c.get("cooldown", 0.0))
		if cd > 0.0 and now - float(last_comms.get(id, -1.0e9)) < cd:
			continue
		var p := int(c.get("priority", 0))
		if p > best:
			best = p
			cands = [c]
		elif p == best:
			cands.append(c)
	if cands.is_empty():
		return
	cands.shuffle()
	for c: Dictionary in cands:
		if randf() > float(c.get("chance", 1.0)):
			continue
		var id := str(c.get("id", ""))
		last_comms[id] = now
		radio.push(_comm_entry(c))
		Events.emit_custom("story_comms", {"id": id})
		return


func _comm_entry(c: Dictionary) -> Dictionary:
	var sp := str(c.get("speaker", ""))
	var ch: Dictionary = Story.character(sp)
	return {"id": str(c.get("id", "")), "speaker": sp, "expr": str(c.get("expr", "")), "name": str(ch.get("name_zh", "")),
		"zh": str(c.get("zh", "")), "voice": str(c.get("voice", "")), "priority": int(c.get("priority", 0))}


# ============================================================ 档案图鉴
func _check_codex(event: String, ctx: Dictionary) -> void:
	var entries: Dictionary = Story.data.get("codex", {})
	for id in entries:
		if Story.is_codex_unlocked(str(id)):
			continue
		var e = entries[id]
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var u = e.get("unlock")
		if typeof(u) != TYPE_DICTIONARY or str(u.get("event", "")) != event:
			continue
		var when = u.get("when", {})
		if typeof(when) == TYPE_DICTIONARY and StoryData.match_when(when, ctx, Story.flags, Story.chapter, str(GameData.map_id)):
			Story.unlock_codex(str(id))


## 没有 unlock 条件的条目一开始就解锁
func _unlock_free_codex() -> void:
	var entries: Dictionary = Story.data.get("codex", {})
	for id in entries:
		var e = entries[id]
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var u = e.get("unlock")
		if typeof(u) == TYPE_DICTIONARY and str(u.get("event", "")) != "":
			continue
		Story.unlock_codex(str(id))


# ============================================================ 外部入口
## 立刻播放一个场景（不排队，自动播放关闭时也生效）；章节过场与支线解锁也走这里
func play_now(sid: String, line := 0) -> bool:
	var s: Dictionary = Story.scene(sid)
	if s.is_empty():
		return false
	if player != null:
		_queue_scene(sid, line)
		return true
	_open_scene(sid, s, max(0, line))
	return true


## 立刻播放一条通讯；无线电小窗没挂上（不在行动里）时返回 false
func play_comms_now(comm_id: String) -> bool:
	if radio == null or not is_instance_valid(radio):
		return false
	for c in Story.data.get("comms", []):
		if typeof(c) == TYPE_DICTIONARY and str(c.get("id", "")) == comm_id:
			radio.push(_comm_entry(c))
			return true
	return false


func is_playing() -> bool:
	return player != null


func attach_radio(win) -> void:
	if radio != null and radio != win and is_instance_valid(radio):
		radio.clear()
	radio = win


func detach_radio(win) -> void:
	if radio == win:
		if radio != null and is_instance_valid(radio):
			radio.clear()
		radio = null


## 测试用：开关自动播放
func set_auto(scenes: bool, comms: bool) -> void:
	auto_scenes = scenes
	auto_comms = comms


func queued_scenes() -> int:
	return queue.size()
