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
const GLOBAL_COMM_GAP := 4.2   ## 两条普通通讯之间的最小全局间隔（秒）
const LOOT_GROUP_GAP := 14.0   ## 开箱 / 检视 / 拾取共享的搜刮语音最小间隔（秒）
const ONCE_RAID_EVENTS := ["deployed", "drop_landed", "poi_discovered", "enemy_seen", "boss_appeared", "boss_defeated"]
const EVENT_COOLDOWNS := {
	"enemy_killed": 28.0,
	"item_picked": 18.0,
	"item_revealed": 22.0,
	"box_opened": 18.0,
	"item_used": 20.0,
	"player_damaged": 22.0,
	"enemy_seen": 24.0,
	"overload_changed": 25.0,
	"combat_changed": 20.0,
	"cargo_full": 30.0,
}

var auto_scenes := not GameData.is_test_run()   ## 自动把触发到的场景交给对话演出
var auto_comms := true                         ## 自动把触发到的通讯交给无线电小窗
var player                                       ## 正在播放的对话演出
var radio                                        ## HUD 挂上来的无线电小窗
var queue: Array = []                            ## 待播场景 [{"id": 场景 id, "line": 起始句}]
var current := ""                                ## 正在播放的场景 id
var last_comms := {}                             ## 通讯 id -> 上次播出的秒数（同一条通讯的冷却）
var _comm_counts := {}                           ## 通讯 id -> 本局已播放次数（防重复）
var _event_last_time := {}                       ## 事件名 -> 上次触发通讯的秒数（同类事件编排间隔）
var _recent_comms: Array = []                    ## 最近播过的通讯 id 队列（LRU 防复读）
var _last_comm_id := ""
var _last_comm_speaker := ""
var _last_comm_event := ""
var _last_comm_time := -1.0e9
var _last_comm_prio := 0
var _seen_clear_seq := -1
var _rng := RandomNumberGenerator.new()
var _improv_tick := 0.0
var _improv_cd := {}                             ## 临场境遇类型 -> 上次触发秒数
var _improv_seq := 0
var _recent_kill_times: Array = []
var _was_low_hp_combat := false

var _seq := 0
var _fired := {}                                 ## 事件序号 -> {场景 id: true}：同一事件的两遍匹配不重复排场景
var _in_handler := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	Events.any.connect(_on_any)
	Events.deployed.connect(_on_deployed)
	_resume.call_deferred()


func _process(delta: float) -> void:
	if not auto_comms or GameData.is_test_run():
		return
	if radio == null or not is_instance_valid(radio) or player != null:
		return
	_improv_tick += delta
	if _improv_tick < 0.65:
		return
	_improv_tick = 0.0
	_poll_live_encounters()


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
	pass


func _reset_comms_pacing(full_clear := false) -> void:
	last_comms.clear()
	_comm_counts.clear()
	_event_last_time.clear()
	_improv_cd.clear()
	_recent_kill_times.clear()
	_was_low_hp_combat = false
	if full_clear:
		_recent_comms.clear()
	_last_comm_id = ""
	_last_comm_event = ""
	_last_comm_time = -1.0e9
	_last_comm_prio = 0


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
	if not a.has("map_id") or str(a.get("map_id", "")) == "":
		var active = _active_raid()
		a["map_id"] = str(active.map_id) if active != null and "map_id" in active and str(active.map_id) != "" else str(GameData.map_id)
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
			if StoryData.match_when(when, ctx, Story.flags, Story.chapter, str(ctx.get("map_id", GameData.map_id))):
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
	return {"id": id, "speaker": sp, "expr": str(ln.get("expr", "")), "tag": str(ln.get("tag", "")),
		"ja": str(ln.get("ja", "")), "name": str(c.get("name_zh", "")),
		"zh": str(ln.get("zh", "")), "voice": str(ln.get("voice", "")), "priority": priority}


# ============================================================ 无线电通讯
func _try_comms(event: String, ctx: Dictionary) -> void:
	if radio == null or not is_instance_valid(radio):
		return
	if player != null:
		return
	if "clear_seq" in radio and int(radio.clear_seq) != _seen_clear_seq:
		_seen_clear_seq = int(radio.clear_seq)
		_reset_comms_pacing(GameData.is_test_run())
	if event == "deployed":
		_reset_comms_pacing(GameData.is_test_run())
	var now := Time.get_ticks_msec() * 0.001
	if event == "enemy_killed" and not GameData.is_test_run():
		_recent_kill_times.append(now)
		while not _recent_kill_times.is_empty() and now - float(_recent_kill_times[0]) > 7.5:
			_recent_kill_times.pop_front()
	var ev_cd := float(EVENT_COOLDOWNS.get(event, 0.0))
	if ev_cd > 0.0 and now - float(_event_last_time.get(event, -1.0e9)) < ev_cd:
		return
	if event in ["box_opened", "item_revealed", "item_picked"]:
		if now - float(_event_last_time.get("_loot_group", -1.0e9)) < LOOT_GROUP_GAP:
			return
	# 实机模式下优先根据当前真实遭遇进行临场发挥
	if not GameData.is_test_run() and _try_improv_event(event, ctx, now):
		return
	var map_id := str(ctx.get("map_id", GameData.map_id))
	var cands: Array = []
	for c in Story.data.get("comms", []):
		if typeof(c) != TYPE_DICTIONARY or str(c.get("event", "")) != event:
			continue
		var when = c.get("when", {})
		if typeof(when) == TYPE_DICTIONARY and not when.is_empty():
			if not StoryData.match_when(when, ctx, Story.flags, Story.chapter, map_id):
				continue
		var id := str(c.get("id", ""))
		var play_cnt := int(_comm_counts.get(id, 0))
		if event in ONCE_RAID_EVENTS and play_cnt >= 1:
			continue
		var cd := maxf(float(c.get("cooldown", 0.0)), 45.0 if play_cnt > 0 else 0.0)
		if cd > 0.0 and now - float(last_comms.get(id, -1.0e9)) < cd:
			continue
		if id == _last_comm_id and now - _last_comm_time < 90.0:
			continue
		var p := int(c.get("priority", 0))
		if now - _last_comm_time < GLOBAL_COMM_GAP and p < 6 and p <= _last_comm_prio:
			continue
		cands.append(c)
	if cands.is_empty():
		return
	# 预计算综合得分与随机扰动（避免 sort_custom 内部调用 randf 导致排序器违背严格弱序报错，并打破固定顺序）
	var scored: Array = []
	for c: Dictionary in cands:
		scored.append([_comm_score(c) + _rng.randf_range(0.0, 9.5), c])
	scored.sort_custom(func(a: Array, b: Array) -> bool:
		return float(a[0]) > float(b[0])
	)
	for pair: Array in scored:
		var c: Dictionary = pair[1]
		if _rng.randf() > float(c.get("chance", 1.0)):
			continue
		var id := str(c.get("id", ""))
		var sp := str(c.get("speaker", ""))
		last_comms[id] = now
		_comm_counts[id] = int(_comm_counts.get(id, 0)) + 1
		_event_last_time[event] = now
		if event in ["box_opened", "item_revealed", "item_picked"]:
			_event_last_time["_loot_group"] = now
		_last_comm_id = id
		_last_comm_speaker = sp
		_last_comm_event = event
		_last_comm_time = now
		_last_comm_prio = int(c.get("priority", 0))
		_recent_comms.erase(id)
		_recent_comms.push_back(id)
		if _recent_comms.size() > 14:
			_recent_comms.pop_front()
		radio.push(_comm_entry(c))
		Events.emit_custom("story_comms", {"id": id})
		return


func _comm_score(c: Dictionary) -> float:
	var id := str(c.get("id", ""))
	var sp := str(c.get("speaker", ""))
	var p := float(c.get("priority", 0))
	var cnt := float(_comm_counts.get(id, 0))
	var recent_pen := 14.0 if _recent_comms.has(id) else 0.0
	var speaker_pen := 7.5 if (sp != "" and sp == _last_comm_speaker) else 0.0
	return p * 8.0 - cnt * 22.0 - recent_pen - speaker_pen


# ============================================================ 实机遭遇临场发挥系统
const ENEMY_ZH := {
	"ling": "跳虫",
	"mite": "蚀甲工虫",
	"spitter": "酸液喷吐虫",
	"beetle": "重甲铁甲虫",
	"mantis": "镰爪突袭虫",
	"bomber": "自爆囊虫",
	"burrower": "潜地猎虫",
	"broodmother": "赤湖巢母",
	"iron_warden": "铁带守卫长",
	"abyss_queen": "深渊女皇",
}

const ENEMY_EN := {
	"ling": "Skitterling",
	"mite": "Chitin Mite",
	"spitter": "Acid Spitter",
	"beetle": "Armored Beetle",
	"mantis": "Scythe Mantis",
	"bomber": "Plague Bomber",
	"burrower": "Burrower",
	"broodmother": "Redlake Broodmother",
	"iron_warden": "Rustclad Warden",
	"abyss_queen": "Abyssal Queen",
}

const SLOT_ZH := {
	"core": "核心躯干",
	"legs": "行进底盘",
	"arm_l": "左臂武器挂架",
	"arm_r": "右臂武器挂架",
	"back": "背部战术模组",
	"gen": "动力炉",
}

const SLOT_EN := {
	"core": "Core Chassis",
	"legs": "Mobility Legs",
	"arm_l": "Left Arm Weapon",
	"arm_r": "Right Arm Weapon",
	"back": "Back Module",
	"gen": "Reactor",
}


func _active_raid():
	var tree := get_tree()
	if tree == null:
		return null
	var sc := tree.current_scene
	if sc == null or not is_instance_valid(sc):
		return null
	if "raid" in sc and sc.raid != null and is_instance_valid(sc.raid):
		var r = sc.raid
		if "mech" in r and r.mech != null and is_instance_valid(r.mech):
			return r
	if "mech" in sc and sc.mech != null and is_instance_valid(sc.mech):
		return sc
	return null


func _raid_bugs() -> Array:
	var tree := get_tree()
	return tree.get_nodes_in_group("bugs") if tree != null else []


func _enemy_zh(kind: String) -> String:
	var ed: Dictionary = GameData.ENEMIES.get(kind, {})
	if ed.has("name"):
		return str(ed.name)
	return str((ENEMY_EN if Loc.is_en() else ENEMY_ZH).get(kind, Loc.t("异虫", "Swarm")))


func _pick_operator(preferred: Array = []) -> String:
	var pool := preferred.duplicate() if not preferred.is_empty() else ["lina", "kurumi", "mia", "nao", "rei"]
	if pool.size() > 1 and _last_comm_speaker in pool:
		pool.erase(_last_comm_speaker)
	return str(pool[_rng.randi() % pool.size()])


func _push_improv(tag_key: String, speaker: String, expr: String, tag: String, zh: String, prio := 4, cd := 28.0, bypass_gap := false) -> bool:
	if radio == null or not is_instance_valid(radio) or zh == "":
		return false
	var now := Time.get_ticks_msec() * 0.001
	if now - float(_improv_cd.get(tag_key, -1.0e9)) < cd:
		return false
	if not bypass_gap and now - _last_comm_time < GLOBAL_COMM_GAP and prio < 6 and prio <= _last_comm_prio:
		return false
	_improv_seq += 1
	var id := "improv_%s_%d" % [tag_key, _improv_seq]
	_improv_cd[tag_key] = now
	_last_comm_id = id
	_last_comm_speaker = speaker
	_last_comm_event = tag_key
	_last_comm_time = now
	_last_comm_prio = prio
	radio.push({
		"id": id,
		"speaker": speaker,
		"expr": expr,
		"tag": Loc.emotion(tag) if Loc.is_en() else tag,
		"ja": "",
		"name": Story.char_name(speaker),
		"zh": zh,
		"en": zh,
		"voice": "",
		"priority": prio,
	})
	Events.emit_custom("story_comms", {"id": id})
	return true


## 根据实机事件与当前周边战况即兴生成台词（返回 true 表示已由临场系统接管）
func _try_improv_event(event: String, ctx: Dictionary, now: float) -> bool:
	var raid = _active_raid()
	if raid == null:
		return false
	var mech = raid.mech
	var pos: Vector3 = mech.global_position
	var near_bugs := 0
	var near_kinds := {}
	for b in _raid_bugs():
		if is_instance_valid(b) and not bool(b.get("dying")) and float(b.get("hp")) > 0.0:
			var d: float = (b as Node3D).global_position.distance_to(pos)
			if d <= 28.0:
				near_bugs += 1
				var k := str(b.kind)
				near_kinds[k] = int(near_kinds.get(k, 0)) + 1
	var en := Loc.is_en()
	match event:
		"drop_landed":
			_event_last_time[event] = now
			var cur_d := str(raid.cur_district) if "cur_district" in raid else ""
			if cur_d == "" and raid.has_method("district_at"):
				cur_d = str(raid.district_at(pos))
			var dist_name := Loc.map_label(cur_d) if cur_d != "" else str(raid.MAP.get("name", Loc.t("战区", "Sector")))
			if near_bugs >= 2:
				var top_kind := Loc.t("虫群", "Swarm")
				for k in near_kinds:
					top_kind = _enemy_zh(str(k))
					break
				var sp := _pick_operator(["lina", "nao", "rei"])
				var lines := [
					"Touchdown right inside a swarm nest! Radar shows %d contacts (incl. %s) — clear the drop crater and get firing lanes!" % [near_bugs, top_kind],
					"Hot drop! %d thermal signatures converging from %s. Keep shields and thrusters ready — fight moving!" % [near_bugs, dist_name],
					"Drop shock stirred up nearby %s — %d contacts total. Clear the ones in your face first!" % [top_kind, near_bugs],
				] if en else [
					"接地位置就在虫群活动圈里！雷达扫到 %d 只目标（含%s），别在降落坑里久留，先拉出射界！" % [near_bugs, top_kind],
					"是热降落！%s方向 %d 个热源正在合围，护盾和冲刺先留好，边退边打！" % [dist_name, near_bugs],
					"降落震波惊动周边的%s了，共 %d 个接触点，先把贴脸的清掉！" % [top_kind, near_bugs],
				]
				return _push_improv("drop_hot", sp, "serious", "警戒", lines[_rng.randi() % lines.size()], 5, 40.0, true)
			elif now - float(_event_last_time.get("deployed", -1.0e9)) < 8.0:
				return true
			return false
		"enemy_seen":
			var kind := str(ctx.get("kind", ""))
			var k_zh := _enemy_zh(kind)
			if _rng.randf() < 0.72:
				_event_last_time[event] = now
				var sp := _pick_operator(["lina", "nao", "rei"])
				var lines := [
					"Visual on %s! %d hostile thermals within 28m — keep spacing and mobility!" % [k_zh, maxi(1, near_bugs)],
					"%s ahead, %s — aim for the carapace seams!" % [k_zh, "flankers moving in" if near_bugs >= 3 else "it's isolated, drop it fast"],
				] if en else [
					"目视接触%s！周围28米内共有 %d 个敌方热源，注意保持机动距离。" % [k_zh, maxi(1, near_bugs)],
					"前方发现%s，%s，优先瞄准甲壳接缝！" % [k_zh, "还有伴随虫群正在包抄" if near_bugs >= 3 else "目前落单，可以速战速决"],
				]
				if kind == "bomber":
					lines = ["Careful — Volatile Sac! Don't let it inside 10m; detonate it at range!" if en else "当心！是自爆囊虫，千万别让它贴进近身范围，在十米外提前点爆它！"]
				elif kind == "spitter":
					lines = ["Acid Spitter setting up long-range fire! Strafe laterally or break line of sight!" if en else "酸液喷吐虫在远处架炮了！别走直线，横向切步贴近或者找掩体卡它视角！"]
				elif kind == "burrower":
					lines = ["Subterranean tremors — Burrower! Watch the churned soil and focus fire when it surfaces!" if en else "地下有震动波纹——是潜地猎虫！看脚下翻土位置，等它破土瞬间集火！"]
				elif kind == "mantis":
					lines = ["High-speed Scythe Mantis closing in! Short lunge windup — keep boost charge ready to dodge!" if en else "高机动镰爪虫逼近！它的扑击前摇很短，留一段冲刺能量随时闪避！"]
				return _push_improv("seen_" + kind, sp, "serious", "警戒", lines[_rng.randi() % lines.size()], 4, 24.0)
		"part_destroyed":
			var slot := str(ctx.get("slot", "core"))
			var s_zh := str((SLOT_EN if en else SLOT_ZH).get(slot, Loc.t("机体模块", "mech module")))
			_event_last_time[event] = now
			var sp := _pick_operator(["kurumi", "mia", "lina"])
			var lines := [
				"Warning! %s structure at zero! %s — pull back and use a repair kit!" % [s_zh, "Mobility severely degraded" if slot == "legs" else "Firepower heavily compromised"],
				"%s is breached! Break line of sight behind cover and patch it before pushing!" % s_zh,
			] if en else [
				"警报！%s结构归零受损！%s，赶紧拉开距离用维修包抢修！" % [s_zh, "移动速度会大幅下降" if slot == "legs" else "火力输出受到严重影响"],
				"%s被打穿了！现在硬拼太吃亏，找面墙卡住视线先把模块修好！" % s_zh,
			]
			return _push_improv("part_" + slot, sp, "surprised", "急促", lines[_rng.randi() % lines.size()], 6, 18.0)
		"district_entered":
			if near_bugs >= 2 or _rng.randf() < 0.65:
				_event_last_time[event] = now
				var raw_d := str(ctx.get("district", ctx.get("name", "")))
				var dname := Loc.map_label(raw_d) if raw_d != "" else Loc.t("新街区", "new district")
				var sp := _pick_operator(["lina", "nao", "mia"])
				var msg := ""
				if en:
					msg = ("Entering %s. Radar shows %d active swarm signals nearby — watch your exfil route." % [dname, near_bugs]) if near_bugs >= 2 else ("Crossed into %s. Cargo load %.1f kg — check building interiors for supply crates." % [dname, mech.cargo_weight()])
				else:
					msg = "进入%s。雷达显示周边有 %d 个活跃虫群信号，搜刮时留意退路。" % [dname, near_bugs] if near_bugs >= 2 else "已切入%s区域，目前负重 %.1f kg，注意搜索建筑物内侧的物资箱。" % [dname, mech.cargo_weight()]
				return _push_improv("dist_" + dname, sp, "neutral", "沉着", msg, 3, 32.0)
	return false


## 周期性扫描实机战场态势，触发完全基于当场遭遇的临场语音
func _poll_live_encounters() -> void:
	var raid = _active_raid()
	if raid == null or radio.busy():
		return
	var mech = raid.mech
	if mech.dead or ("dropping" in raid and bool(raid.dropping)):
		return
	var now := Time.get_ticks_msec() * 0.001
	if now - _last_comm_time < 7.5:
		return
	var pos: Vector3 = mech.global_position
	var close_bugs := 0
	var mid_bugs := 0
	var spitters := 0
	var bombers := 0
	var heavies := 0
	for b in _raid_bugs():
		if not is_instance_valid(b) or bool(b.get("dying")) or float(b.get("hp")) <= 0.0:
			continue
		var d: float = (b as Node3D).global_position.distance_to(pos)
		if d <= 19.0:
			mid_bugs += 1
			if d <= 10.5:
				close_bugs += 1
			var k := str(b.kind)
			if k == "spitter":
				spitters += 1
			elif k == "bomber" and d <= 13.0:
				bombers += 1
			elif k in ["beetle", "mantis", "burrower"] and d <= 13.0:
				heavies += 1
	var hp_ratio := float(mech.hp) / maxf(1.0, float(mech.max_hp))
	if hp_ratio < 0.42 and mid_bugs >= 2:
		_was_low_hp_combat = true
	var en := Loc.is_en()

	# 1. 自爆虫贴脸预警
	if bombers >= 1:
		var sp := _pick_operator(["lina", "rei", "kurumi"])
		var m_bomb := ("Watch your step! %d Volatile Sac(s) inside 10m — boost clear or focus fire now!" % bombers) if en else ("小心脚下！有 %d 只自爆囊虫冲进十米圈了，快用冲刺拉开或者立刻集火打爆它！" % bombers)
		if _push_improv("live_bomber", sp, "surprised", "急促", m_bomb, 6, 26.0):
			return

	# 2. 被多只虫群近身合围
	if mid_bugs >= 5 and close_bugs >= 2:
		var sp := _pick_operator(["lina", "nao", "kurumi"])
		var lines := [
			"%d hostiles swarming inside 19m! Don't get cornered — kite back toward open street!" % mid_bugs,
			"Swarm closing in — %d right on top of you! Pop an AoE module or boost out!" % close_bugs,
		] if en else [
			"周围十九米内聚集了 %d 只异虫！别被堵在死角，边退边向开阔街面拉扯！" % mid_bugs,
			"虫群正在合围，贴身已经有 %d 只了！有范围模块或冲刺的话立刻交，别省能量！" % close_bugs,
		]
		if _push_improv("live_swarm", sp, "serious", "急促", lines[_rng.randi() % lines.size()], 5, 34.0):
			return

	# 3. 双臂同时装填且周围有敌人逼近
	var rl_l := float(mech.reload_t.get("arm_l", 0.0))
	var rl_r := float(mech.reload_t.get("arm_r", 0.0))
	if rl_l > 0.35 and rl_r > 0.35 and mid_bugs >= 2:
		var sp := _pick_operator(["kurumi", "rei"])
		var m_rl := "Both arms reloading at once! Strafe sideways until the feed rails cycle — don't tank hits!" if en else "左右臂同时在装填！趁供弹导轨复位的这两秒先横向机动，别站在原地硬吃伤害！"
		if _push_improv("live_reload_gap", sp, "serious", "警戒", m_rl, 5, 35.0):
			return

	# 4. 多只酸液喷吐虫交叉火力
	if spitters >= 2 and mid_bugs >= 2:
		var sp := _pick_operator(["nao", "lina"])
		var m_sp := ("%d Acid Spitters setting up crossfire — pools corrode over time! Flank cover and drop the backline!" % spitters) if en else ("检测到 %d 只酸液喷吐虫正在交叉封路，酸液落点有腐蚀残留，先绕掩体切掉后排！" % spitters)
		if _push_improv("live_spitters", sp, "serious", "警戒", m_sp, 4, 38.0):
			return

	# 5. 短时间连续击杀高潮
	while not _recent_kill_times.is_empty() and now - float(_recent_kill_times[0]) > 7.5:
		_recent_kill_times.pop_front()
	if _recent_kill_times.size() >= 4:
		var k_cnt := _recent_kill_times.size()
		_recent_kill_times.clear()
		var sp := _pick_operator(["kurumi", "nao", "lina"])
		var lines := [
			"Clean sweep — %d targets dropped in seconds! That's textbook suppression!" % k_cnt,
			"%d thermal signatures down back-to-back! Front line cracked wide open — keep the pressure!" % k_cnt,
		] if en else [
			"漂亮！短短几秒连续清掉了 %d 只目标，这波火力压制太干脆了！" % k_cnt,
			"连续击破 %d 个热源！正面防线已经被你撕开了，保持这个节奏！" % k_cnt,
		]
		if _push_improv("live_streak", sp, "smile", "振奋", lines[_rng.randi() % lines.size()], 4, 42.0):
			return

	# 6. 残血脱离险境后的喘息反馈
	if _was_low_hp_combat and mid_bugs == 0:
		_was_low_hp_combat = false
		var sp := _pick_operator(["mia", "kurumi", "lina"])
		var lines := [
			"Phew... shook them off. Armor at %d%% — pop a repair kit while the sector's quiet." % int(round(hp_ratio * 100.0)),
			"That was close! Area clear for now — reload and top up hull integrity before moving out.",
		] if en else [
			"呼……总算把追兵甩开了。目前装甲还剩 %d%%，趁周围没动静赶紧打个维修包缓一口气。" % int(round(hp_ratio * 100.0)),
			"刚才那波太悬了！现在附近热源清零了，先整备弹药和机体耐久再继续走。" % [],
		]
		if _push_improv("live_clutch", sp, "tired" if sp == "mia" else "smile", "释然", lines[_rng.randi() % lines.size()], 4, 45.0):
			return

	# 7. 附近有友方或中立游荡机甲交火
	var npc_tree := get_tree()
	for nm in (npc_tree.get_nodes_in_group("npc_mechs") if npc_tree else []):
		if is_instance_valid(nm) and not bool(nm.get("dead")) and float(nm.get("hp")) > 0.0 and nm.global_position.distance_to(pos) <= 26.0:
			var is_ally := str(nm.faction) == "ally"
			var sp := _pick_operator(["lina", "nao"])
			var msg := ""
			if en:
				msg = "Allied mech transponder within 25m — use their crossfire to push!" if is_ally else "Heads up — roaming scavenger mech nearby! Watch their muzzle line and stay out of a three-way!"
			else:
				msg = "二十五米内识别到友方机甲信标，可以借它的火力交叉掩护推进！" if is_ally else "注意！附近有游荡拾荒机甲活动，留意它的枪口朝向，别被卷进乱战！"
			if _push_improv("live_npc_mech", sp, "serious", "警觉", msg, 4, 55.0):
				return

	# 8. 满载高价值物资提示撤离方位
	var cap := float(mech.cargo_cap())
	var w := float(mech.cargo_weight())
	if cap > 0.0 and w / cap >= 0.80 and mid_bugs == 0:
		var sp := _pick_operator(["lina", "mia"])
		var m_haul := ("Cargo hold at %.1f / %.0f kg. Mobility will suffer if you push deeper — plot an exfil route." % [w, cap]) if en else ("货舱已经装到 %.1f / %.0f kg 了。再贪下去机动性会吃亏，建议规划去撤离点的路线。" % [w, cap])
		if _push_improv("live_heavy_haul", sp, "neutral", "沉着", m_haul, 3, 65.0):
			return


func _comm_entry(c: Dictionary) -> Dictionary:
	var sp := str(c.get("speaker", ""))
	var cid := str(c.get("id", ""))
	var tag := str(c.get("tag", ""))
	var zh := str(c.get("zh", ""))
	return {"id": cid, "speaker": sp, "expr": str(c.get("expr", "")),
		"tag": Loc.emotion(tag) if Loc.is_en() else tag,
		"ja": str(c.get("ja", "")), "name": Story.char_name(sp),
		"zh": zh, "en": Loc.comm_text(cid, zh),
		"voice": str(c.get("voice", "")), "priority": int(c.get("priority", 0))}


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
		if typeof(when) == TYPE_DICTIONARY and StoryData.match_when(when, ctx, Story.flags, Story.chapter, str(ctx.get("map_id", GameData.map_id))):
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
