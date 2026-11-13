extends RefCounted
## 局外成长系统：飞空艇设施、研究、驾驶员成长、船员好感、主线章节。
## 状态存在 Progress.state（存档分区 "progress"）；数据来自 data\ext\progression.gd。
## 机库通过 scripts\progression\growth_panel.gd 操作成长内容；其他系统只用本文件的静态接口。
## 数值影响全部走 GameData.add_stat_hook（不改任何模块基础数值），商品与战区准入走 add_shop_filter / add_map_filter。

const DATA_PATH := "res://data/ext/progression.gd"
const SELF_PATH := "res://scripts/progression/growth.gd"
const MAX_FACILITY := 5
const PILOT_MAX := 12
const CREW_MAX := 5
## 部署仓（战斗队友）最高等级
const POD_MAX_TIER := 3
## 主角在数据表里的角色 id；名字由玩家输入，状态存 player_name。
const PROTAGONIST := "nao"
const DEFAULT_PLAYER_NAME := "奈绪"
## 驾驶员等级的升级间隔：Lv.n → n+1 需要 80 + 45(n-1) + 12(n-1)^2 经验。
const XP_BASE := 80.0
const XP_LINEAR := 45.0
const XP_QUAD := 12.0
## 塔科夫式实战熟练度：单局前 FOCUS_RAW 点享 129% 精力充沛加成，超过 EXHAUST_RAW 点进入 50% 疲劳递减
const ABILITY_MAX_DEFAULT := 10
const FOCUS_RAW := 12.0
const EXHAUST_RAW := 32.0

static var _tables := {}
static var _tables_lang := ""
static var _installed := false
static var _bound := false
static var _self_script: Script
static var network_profile = null ## Scoped stat calculation for a co-op player's own progression.
static var _raid_skill_raw := {}
static var _raid_skill_gained := {}
static var _raid_skill_leveled := {}


static func _self() -> Script:
	if _self_script == null:
		_self_script = load(SELF_PATH)
	return _self_script


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func _node(n: String) -> Node:
	var t := _tree()
	return t.root.get_node_or_null(n) if t != null else null


static func invalidate_lang_cache() -> void:
	_tables.clear()
	_tables_lang = ""


static func tables() -> Dictionary:
	var loc := _node("Loc")
	var cur_lang := str(loc.get("lang")) if loc != null else "zh"
	if _tables.is_empty() or _tables_lang != cur_lang:
		var s: Script = load(DATA_PATH)
		_tables = s.get_script_constant_map().duplicate(true) if s != null else {}
		_tables_lang = cur_lang
		if loc != null and loc.has_method("apply_growth_tables"):
			loc.call("apply_growth_tables", _tables)
	return _tables


static func _table(key: String) -> Dictionary:
	var v = tables().get(key, {})
	return v if typeof(v) == TYPE_DICTIONARY else {}


static func _list(key: String) -> Array:
	var v = tables().get(key, [])
	return v if typeof(v) == TYPE_ARRAY else []


# ---------------------------------------------------------------- 状态与默认值
## Progress 的 state 引用；Progress 还没进树时返回空字典（调用方只在运行期使用本文件）。
static func raw_state() -> Dictionary:
	var p := _node("Progress")
	if p == null:
		return {}
	if typeof(p.state) != TYPE_DICTIONARY:
		p.state = {}
	return p.state


## 补齐缺失字段、修正越界值，并把剧情里已有的章节 flag 并回成长状态。旧存档直接调用即可。
static func ensure_defaults() -> Dictionary:
	var s := raw_state()
	if s.is_empty() and _node("Progress") == null:
		return s
	var fac: Dictionary = s.get("facilities") if typeof(s.get("facilities")) == TYPE_DICTIONARY else {}
	for id in _table("FACILITIES"):
		fac[id] = clampi(int(fac.get(id, 0)), 0, MAX_FACILITY)
	s["facilities"] = fac

	var done: Array = s.get("research") if typeof(s.get("research")) == TYPE_ARRAY else []
	var rd: Array = []
	for id in done:
		if _table("RESEARCH").has(str(id)) and not rd.has(str(id)):
			rd.append(str(id))
	s["research"] = rd

	var pilots: Dictionary = s.get("pilots") if typeof(s.get("pilots")) == TYPE_DICTIONARY else {}
	var pdata := _table("PILOTS")
	for id in pdata:
		var p: Dictionary = pilots.get(id) if typeof(pilots.get(id)) == TYPE_DICTIONARY else {}
		p["level"] = clampi(int(p.get("level", 1)), 1, PILOT_MAX)
		p["xp"] = maxi(0, int(p.get("xp", 0)))
		p["points"] = maxi(0, int(p.get("points", 0)))
		var learned: Array = p.get("talents") if typeof(p.get("talents")) == TYPE_ARRAY else []
		var keep: Array = []
		for t in pdata[id].get("talents", []):
			if learned.has(t.id) and not keep.has(t.id):
				keep.append(t.id)
		p["talents"] = keep
		pilots[id] = p
	s["pilots"] = pilots
	if not pdata.has(str(s.get("active_pilot", ""))):
		s["active_pilot"] = "nao" if pdata.has("nao") else (pdata.keys()[0] if not pdata.is_empty() else "")

	var crew: Dictionary = s.get("crew") if typeof(s.get("crew")) == TYPE_DICTIONARY else {}
	for id in _table("CREW"):
		var c: Dictionary = crew.get(id) if typeof(crew.get(id)) == TYPE_DICTIONARY else {}
		c["level"] = clampi(int(c.get("level", 0)), 0, CREW_MAX)
		c["points"] = maxi(0, int(c.get("points", 0)))
		crew[id] = c
	s["crew"] = crew
	s["meal"] = clampi(int(s.get("meal", 0)), 0, MAX_FACILITY)

	var pname := str(s.get("player_name", "")).strip_edges()
	s["player_name"] = pname if pname != "" else DEFAULT_PLAYER_NAME

	# 塔科夫式角色熟练度技能（abilities 存整数等级供属性与联机同步，ability_xp 存当前级内浮点熟练度）與部署仓。
	var ab: Dictionary = s.get("abilities") if typeof(s.get("abilities")) == TYPE_DICTIONARY else {}
	var ab_xp: Dictionary = s.get("ability_xp") if typeof(s.get("ability_xp")) == TYPE_DICTIONARY else {}
	for id in _table("ABILITIES"):
		var mx := int(_table("ABILITIES")[id].get("max", ABILITY_MAX_DEFAULT))
		var raw_entry = ab.get(id, 0)
		var lv := 0
		var xp_val := float(ab_xp.get(id, 0.0))
		if typeof(raw_entry) == TYPE_DICTIONARY:
			lv = int(raw_entry.get("level", 0))
			xp_val = float(raw_entry.get("xp", xp_val))
		else:
			lv = int(raw_entry)
		lv = clampi(lv, 0, mx)
		ab[id] = lv
		var need := _ability_xp_need_at(lv, mx)
		ab_xp[id] = 0.0 if need <= 0.0 else clampf(xp_val, 0.0, maxf(0.0, need - 0.001))
	s["abilities"] = ab
	s["ability_xp"] = ab_xp
	var pods: Dictionary = s.get("pods") if typeof(s.get("pods")) == TYPE_DICTIONARY else {}
	for id in _table("PODS"):
		var pd: Dictionary = pods.get(id) if typeof(pods.get(id)) == TYPE_DICTIONARY else {}
		pd["tier"] = clampi(int(pd.get("tier", 0)), 0, POD_MAX_TIER)
		pd["on"] = bool(pd.get("on", true))
		pods[id] = pd
	s["pods"] = pods

	var chapters: Array = s.get("chapters") if typeof(s.get("chapters")) == TYPE_ARRAY else []
	var ch_keep: Array = []
	var story := _node("Story")
	for ch in _list("CHAPTERS"):
		var cid := str(ch.id)
		var done_flag := story != null and story.has_method("has_flag") and bool(story.has_flag(str(ch.flag)))
		if (chapters.has(cid) or done_flag) and not ch_keep.has(cid):
			ch_keep.append(cid)
	s["chapters"] = ch_keep
	return s


## 状态容器的只读视图（已补默认值）
static func state() -> Dictionary:
	return ensure_defaults()


# ---------------------------------------------------------------- 安装：钩子、筛选器、事件
## 由 data\ext\progression.gd 的 register 在启动时调用一次。
static func install() -> void:
	if _installed:
		return
	_installed = true
	var gd := _node("GameData")
	if gd != null:
		var me := _self()
		gd.add_stat_hook(func(stats, lo): me.call("stat_hook", stats, lo))
		gd.add_shop_filter(func(id): return bool(me.call("shop_allowed", id)))
		gd.add_map_filter(func(id): return bool(me.call("map_allowed", id)))
	var t := _tree()
	if t != null:
		t.process_frame.connect(func(): _self().call("_late_bind"), CONNECT_ONE_SHOT)


## 第一个进程帧时全部 autoload 已就绪，在这里接行动结算、委托与 Boss 事件并补默认值。
static func _late_bind() -> void:
	if _bound:
		return
	_bound = true
	ensure_defaults()
	_sync_chapter()
	var gd := _gd()
	if gd != null and not map_allowed(str(gd.map_id)) and map_allowed("greyport"):
		gd.map_id = "greyport"
	var ev := _node("Events")
	if ev == null:
		return
	ev.deployed.connect(func(_m, _lo): _self().call("reset_raid_skill_fatigue"))
	ev.box_opened.connect(func(_k, _p): _self().call("record_skill_xp", "ab_search", 1.4))
	ev.item_revealed.connect(func(_id, rar): _self().call("record_skill_xp", "ab_search", 0.55 + float(rar) * 0.45))
	ev.item_picked.connect(func(id, rar): _self().call("_on_item_picked_skill", id, rar))
	ev.poi_discovered.connect(func(_id, _t, _p):
		_self().call("record_skill_xp", "ab_covert", 2.2)
		_self().call("record_skill_xp", "ab_search", 0.8))
	ev.skill_used.connect(func(key, sk_id): _self().call("_on_tactical_skill_used", key, sk_id))
	ev.item_used.connect(func(id): _self().call("_on_item_used_skill", id))
	ev.player_damaged.connect(func(amt, _hp, _mx): _self().call("record_skill_xp", "ab_frame", clampf(float(amt) * 0.14, 0.3, 4.5)))
	ev.enemy_killed.connect(func(kind, _p): _self().call("_on_enemy_killed_skill", kind))
	ev.nest_destroyed.connect(func(_p):
		_self().call("record_skill_xp", "ab_firearm", 2.0)
		_self().call("record_skill_xp", "ab_covert", 1.8))
	ev.boss_defeated.connect(func(id):
		_self().call("_on_boss_defeated", id)
		_self().call("record_skill_xp", "ab_covert", 6.0)
		_self().call("record_skill_xp", "ab_firearm", 4.0)
		_self().call("record_skill_xp", "ab_plating", 3.0))
	ev.raid_finished.connect(func(success, result): _self().call("_on_raid_finished", success, result))
	ev.request_fulfilled.connect(func(req): _self().call("_on_request_fulfilled", req))


# ---------------------------------------------------------------- 公共小工具
static func _gd() -> Node:
	return _node("GameData")


static func _money() -> int:
	var gd := _gd()
	return int(gd.money) if gd != null else 0


static func _stash() -> Array:
	var gd := _gd()
	return gd.stash if gd != null and typeof(gd.stash) == TYPE_ARRAY else []


static func _count_item(id: String) -> int:
	return _stash().count(id)


static func _take_item(id: String, n: int) -> bool:
	var gd := _gd()
	if gd == null or n <= 0:
		return false
	var k := 0
	while k < n:
		if not gd.stash.has(id):
			return false
		gd.stash.erase(id)
		k += 1
	return true


static func _has_cost(cost: Dictionary) -> bool:
	if _money() < int(cost.get("money", 0)):
		return false
	var items: Dictionary = cost.get("items", {})
	for id in items:
		if _count_item(str(id)) < int(items[id]):
			return false
	return true


static func _pay_cost(cost: Dictionary) -> bool:
	if not _has_cost(cost):
		return false
	var gd := _gd()
	if gd == null:
		return false
	gd.money -= int(cost.get("money", 0))
	var items: Dictionary = cost.get("items", {})
	for id in items:
		_take_item(str(id), int(items[id]))
	return true


static func _save() -> void:
	var gd := _gd()
	if gd != null and gd.has_method("save_game"):
		gd.save_game()


static func money_text(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


## 费用显示：¥1,200 · 电路板×1 · 铜线×2；费用为空时返回「—」
static func cost_text(cost: Dictionary) -> String:
	if cost.is_empty():
		return "—"
	var parts: Array = ["¥" + money_text(int(cost.get("money", 0)))]
	var items: Dictionary = cost.get("items", {})
	var gd := _gd()
	for id in items:
		var nm := str(id)
		if gd != null:
			nm = str(gd.item_name(str(id)))
		parts.append("%s×%d" % [nm, int(items[id])])
	return " · ".join(parts)


# ---------------------------------------------------------------- 设施
static func facility_ids() -> Array:
	return _table("FACILITIES").keys()


static func facility_name(id: String) -> String:
	return str(_table("FACILITIES").get(id, {}).get("name", id))


static func facility_effects(id: String) -> Array:
	var v = _table("FACILITIES").get(id, {}).get("effect", [])
	return v if typeof(v) == TYPE_ARRAY else []


static func facility_level(id: String) -> int:
	var s := ensure_defaults()
	var fac: Dictionary = s.get("facilities", {})
	return clampi(int(fac.get(id, 0)), 0, MAX_FACILITY)


static func facility_max(id: String) -> int:
	return int(_table("FACILITIES").get(id, {}).get("max", MAX_FACILITY))


## 下一级的升级费用；已满级或未知设施返回空字典
static func facility_cost(id: String) -> Dictionary:
	var d: Dictionary = _table("FACILITIES").get(id, {})
	var costs: Array = d.get("cost", [])
	var lv := facility_level(id)
	if lv >= facility_max(id) or lv >= costs.size():
		return {}
	return costs[lv]


static func facility_effect(id: String) -> String:
	var d: Dictionary = _table("FACILITIES").get(id, {})
	var effects: Array = d.get("effect", [])
	var lv := facility_level(id)
	return str(effects[lv - 1]) if lv > 0 and lv <= effects.size() else ""


## 空串表示可以升级；否则是拒绝原因（同时用作按钮的置灰说明）
static func can_upgrade(id: String) -> String:
	if not _table("FACILITIES").has(id):
		return "未知设施"
	if facility_level(id) >= facility_max(id):
		return "已满级"
	var cost := facility_cost(id)
	if cost.is_empty():
		return "已满级"
	if _money() < int(cost.get("money", 0)):
		return "信用点不足"
	var items: Dictionary = cost.get("items", {})
	for iid in items:
		if _count_item(str(iid)) < int(items[iid]):
			return "材料不足"
	return ""


static func upgrade_facility(id: String) -> bool:
	if can_upgrade(id) != "":
		return false
	var cost := facility_cost(id)
	if not _pay_cost(cost):
		return false
	var s := ensure_defaults()
	s.facilities[id] = facility_level(id) + 1
	Audio.play_ui("grow_upgrade")
	Events.emit_custom("facility_upgraded", {"id": id, "level": int(s.facilities[id])})
	_save()
	return true


# ---------------------------------------------------------------- 研究
static func research_data(id: String) -> Dictionary:
	return _table("RESEARCH").get(id, {})


static func research_done(id: String) -> bool:
	var s := ensure_defaults()
	return (s.get("research", []) as Array).has(id)


static func research_ids() -> Array:
	return (_table("RESEARCH").keys())


## 空串表示可以开始；否则是拒绝原因
static func can_research(id: String) -> String:
	var d: Dictionary = _table("RESEARCH").get(id, {})
	if d.is_empty():
		return "未知研究"
	if research_done(id):
		return "已完成"
	var lab := int(d.get("lab", 1))
	if facility_level("lab") < lab:
		return "研究室 Lv%d" % lab
	for n in d.get("needs", []):
		if not research_done(str(n)):
			return "前置研究未完成"
	var cost: Dictionary = d.get("cost", {})
	if _money() < int(cost.get("money", 0)):
		return "信用点不足"
	var items: Dictionary = cost.get("items", {})
	for iid in items:
		if _count_item(str(iid)) < int(items[iid]):
			return "材料不足"
	return ""


static func do_research(id: String) -> bool:
	if can_research(id) != "":
		return false
	var cost: Dictionary = _table("RESEARCH")[id].get("cost", {})
	if not _pay_cost(cost):
		return false
	var s := ensure_defaults()
	(s["research"] as Array).append(id)
	Audio.play_ui("grow_research")
	Events.emit_custom("research_done", {"id": id})
	_save()
	return true


# ---------------------------------------------------------------- 驾驶员
static func pilot_ids() -> Array:
	return _table("PILOTS").keys()


static func pilot_data(id: String) -> Dictionary:
	var d: Dictionary = _table("PILOTS").get(id, {})
	if id == PROTAGONIST and not d.is_empty():
		var c := d.duplicate(true)
		c["name"] = player_name()
		return c
	return d


## 主角身份：名字由玩家输入，预填默认名。
static func player_name() -> String:
	var n := str(ensure_defaults().get("player_name", DEFAULT_PLAYER_NAME))
	var loc := _node("Loc")
	if n == DEFAULT_PLAYER_NAME and loc != null and loc.has_method("is_en") and bool(loc.call("is_en")):
		return "Nao"
	return n


static func set_player_name(v: String) -> void:
	var s := ensure_defaults()
	var n := v.strip_edges()
	s["player_name"] = DEFAULT_PLAYER_NAME if (n == "" or n == "Nao") else n
	_save()


## 剧情文案占位符替换：{player_name} 名字、{player_kin} 姐、{player_ta} 她、{player_plural} 她们。
## 只替换主角相关称呼，不含占位符的文案原样返回。
static func subst(text: String) -> String:
	if text.find("{player_") < 0:
		return text
	var loc := _node("Loc")
	var en := loc != null and loc.has_method("is_en") and bool(loc.call("is_en"))
	var out := text
	out = out.replace("{player_name}", player_name())
	out = out.replace("{player_kin}", "" if en else "姐")
	out = out.replace("{player_ta}", "she" if en else "她")
	out = out.replace("{player_plural}", "they" if en else "她们")
	return out


static func pilot_state(id: String) -> Dictionary:
	var s := ensure_defaults()
	var pilots: Dictionary = s.get("pilots", {})
	return pilots.get(id, {})


static func pilot_level(id: String) -> int:
	return int(pilot_state(id).get("level", 1))


static func pilot_xp(id: String) -> int:
	return int(pilot_state(id).get("xp", 0))


static func pilot_points(id: String) -> int:
	return int(pilot_state(id).get("points", 0))


## 当前等级升到下一级所需经验；满级返回 0
static func pilot_xp_next(level: int) -> int:
	if level >= PILOT_MAX:
		return 0
	var n := float(level - 1)
	return int(XP_BASE + XP_LINEAR * n + XP_QUAD * n * n)


static func active_pilot() -> String:
	var s := ensure_defaults()
	return str(s.get("active_pilot", "nao"))


static func set_active_pilot(id: String) -> bool:
	if not _table("PILOTS").has(id):
		return false
	var s := ensure_defaults()
	s["active_pilot"] = id
	_save()
	return true


## 加经验并结算升级；返回 {"levels": 升了几级, "level": 新等级, "points": 当前天赋点}
static func add_pilot_xp(id: String, amount: int) -> Dictionary:
	if not _table("PILOTS").has(id) or amount <= 0:
		return {}
	var gained := _add_pilot_xp_raw(id, amount)
	var lv := pilot_level(id)
	if gained > 0:
		Audio.play_ui("grow_level")
		Events.emit_custom("pilot_leveled", {"id": id, "level": lv, "gained": gained})
	_save()
	return {"levels": gained, "level": lv, "points": pilot_points(id)}


## 不发声音、不存档的升级结算，供一次行动里给三位驾驶员统一结算。
static func _add_pilot_xp_raw(id: String, amount: int) -> int:
	var p := pilot_state(id)
	if p.is_empty():
		return 0
	var gained := 0
	p["xp"] = int(p.get("xp", 0)) + amount
	while int(p.level) < PILOT_MAX and int(p.xp) >= pilot_xp_next(int(p.level)):
		p["xp"] = int(p.xp) - pilot_xp_next(int(p.level))
		p["level"] = int(p.level) + 1
		p["points"] = int(p.get("points", 0)) + 1
		gained += 1
	if int(p.level) >= PILOT_MAX:
		p["xp"] = 0
	return gained


static func _talent(pid: String, tid: String) -> Dictionary:
	for t in _table("PILOTS").get(pid, {}).get("talents", []):
		if str(t.id) == tid:
			return t
	return {}


static func talent_learned(pid: String, tid: String) -> bool:
	return (pilot_state(pid).get("talents", []) as Array).has(tid)


## 空串表示可以习得；否则是拒绝原因
static func can_learn_talent(pid: String, tid: String) -> String:
	var t := _talent(pid, tid)
	if t.is_empty():
		return "未知天赋"
	if talent_learned(pid, tid):
		return "已习得"
	if pilot_level(pid) < int(t.get("level", 1)):
		return "等级不足"
	if pilot_points(pid) < int(t.get("points", 1)):
		return "天赋点不足"
	return ""


static func learn_talent(pid: String, tid: String) -> bool:
	if can_learn_talent(pid, tid) != "":
		return false
	var t := _talent(pid, tid)
	var p := pilot_state(pid)
	p["points"] = int(p.get("points", 0)) - int(t.get("points", 1))
	(p["talents"] as Array).append(tid)
	Audio.play_ui("grow_level")
	Events.emit_custom("talent_learned", {"pilot": pid, "talent": tid})
	_save()
	return true


# ---------------------------------------------------------------- 船员好感
static func crew_ids() -> Array:
	return _table("CREW").keys()


static func crew_data(id: String) -> Dictionary:
	return _table("CREW").get(id, {})


static func crew_state(id: String) -> Dictionary:
	var s := ensure_defaults()
	var crew: Dictionary = s.get("crew", {})
	return crew.get(id, {})


static func crew_level(id: String) -> int:
	return int(crew_state(id).get("level", 0))


static func crew_points(id: String) -> int:
	return int(crew_state(id).get("points", 0))


## 当前好感等级升到下一级需要的点数；满级返回 0
static func crew_need(level: int) -> int:
	return 0 if level >= CREW_MAX else level + 1


## 加好感；每升一级广播一次 affinity_changed（剧情支线按 char + level 触发）。返回升了几级。
static func grant_affinity(char_id: String, points: int) -> int:
	if not _table("CREW").has(char_id) or points <= 0:
		return 0
	var c := crew_state(char_id)
	c["points"] = int(c.get("points", 0)) + points
	var gained := 0
	while int(c.level) < CREW_MAX and int(c.points) >= crew_need(int(c.level)):
		c["points"] = int(c.points) - crew_need(int(c.level))
		c["level"] = int(c.level) + 1
		gained += 1
		Events.emit_custom("affinity_changed", {"char": char_id, "level": int(c.level)})
	if gained > 0:
		Audio.play_ui("grow_affinity")
		Events.emit_custom("affinity_level", {"char": char_id, "level": int(c.level)})
	_save()
	return gained


## 一件物品送给某位船员的好感点数；0 表示这件东西不能当赠礼
static func gift_points(char_id: String, item_id: String) -> int:
	var gd := _gd()
	if gd == null:
		return 0
	var it: Dictionary = gd.item(item_id)
	if it.has("gift") and typeof(it.gift) == TYPE_DICTIONARY:
		if str(it.gift.get("char", "")) == char_id:
			return int(it.gift.get("points", 2))
		return 0
	var generic: Dictionary = tables().get("GENERIC_GIFTS", {})
	return int(generic.get(item_id, 0))


## 仓库里可以送给该船员的赠礼：{物品 id: 数量}，偏爱赠礼排在前面
static func gift_items(char_id: String) -> Dictionary:
	var counts := {}
	for id in _stash():
		var pts := gift_points(char_id, str(id))
		if pts > 0:
			counts[str(id)] = int(counts.get(str(id), 0)) + 1
	var ids: Array = counts.keys()
	ids.sort_custom(func(a, b): return gift_points(char_id, a) > gift_points(char_id, b))
	var out := {}
	for id in ids:
		out[id] = counts[id]
	return out


static func give_gift(char_id: String, item_id: String) -> bool:
	if gift_points(char_id, item_id) <= 0:
		return false
	if not _take_item(item_id, 1):
		return false
	grant_affinity(char_id, gift_points(char_id, item_id))
	Audio.play_ui("grow_gift")
	Events.emit_custom("gift_given", {"char": char_id, "item": item_id})
	_save()
	return true


# ---------------------------------------------------------------- 出击食堂
static func meal_cost() -> Dictionary:
	var v = _table("MEAL").get("cost", {})
	return v if typeof(v) == TYPE_DICTIONARY else {}


static func meal_ready() -> int:
	var s := ensure_defaults()
	return int(s.get("meal", 0))


static func meal_text() -> String:
	var lv := meal_ready()
	if lv <= 0:
		return ""
	var m := _table("MEAL")
	var texts: Array = m.get("text", [])
	var out := str(texts[lv - 1]) if lv <= texts.size() else ""
	if research_done("res_ration"):
		var r := str(m.get("ration", ""))
		if r != "":
			out += " · " + r
	return out


## 餐点对下一局行动的数值加成；没有待用餐点返回空字典
static func meal_bonus() -> Dictionary:
	if network_profile != null:
		return _meal_bonus_for(network_profile)
	var lv := meal_ready()
	if lv <= 0:
		return {}
	var m := _table("MEAL")
	var out := {"energy": 8.0 + float(m.get("energy", 0.0)) * lv,
		"hp": float(m.get("hp", 0.0)) * lv,
		"drain": float(m.get("drain", 0.0)) * lv}
	if research_done("res_ration"):
		out.energy += float(m.get("ration_energy", 0.0))
		out.hp += float(m.get("ration_hp", 0.0))
	return out


static func serve_meal() -> bool:
	var lv := facility_level("kitchen")
	if lv <= 0 or meal_ready() > 0:
		return false
	var cost: Dictionary = _table("MEAL").get("cost", {})
	for id in cost:
		if _count_item(str(id)) < int(cost[id]):
			return false
	for id in cost:
		_take_item(str(id), int(cost[id]))
	var s := ensure_defaults()
	s["meal"] = lv
	Audio.play_ui("grow_meal")
	Events.emit_custom("meal_served", {"level": lv})
	_save()
	return true


# ---------------------------------------------------------------- 主线章节
static func chapters() -> Array:
	return _list("CHAPTERS")


static func _chapter(id: String) -> Dictionary:
	for ch in _list("CHAPTERS"):
		if str(ch.id) == id:
			return ch
	return {}


static func _chapter_index(id: String) -> int:
	var chapters := _list("CHAPTERS")
	for i in chapters.size():
		if str(chapters[i].id) == id:
			return i
	return -1


static func chapter_done(id: String) -> bool:
	var ch := _chapter(id)
	if ch.is_empty():
		return false
	if (ensure_defaults().get("chapters", []) as Array).has(id):
		return true
	var story := _node("Story")
	return story != null and story.has_method("has_flag") and bool(story.has_flag(str(ch.flag)))


## 章节前置是否达成（章节自身是否完成不影响它「已经走到这里」）
static func chapter_unlocked(id: String) -> bool:
	var ch := _chapter(id)
	if ch.is_empty():
		return false
	var req := str(ch.get("requires", ""))
	return req == "" or _flag(req)


static func chapter_status(id: String) -> String:
	if chapter_done(id):
		return "已完成"
	if not chapter_unlocked(id):
		return "未解锁"
	return "进行中"


## 当前章节：第一个已解锁且未完成的章节；全部完成时返回最后一章
static func current_chapter() -> String:
	var chapters := _list("CHAPTERS")
	var last := ""
	for ch in chapters:
		last = str(ch.id)
		if chapter_unlocked(str(ch.id)) and not chapter_done(str(ch.id)):
			return str(ch.id)
	return last


static func _flag(flag_name: String) -> bool:
	if flag_name == "":
		return true
	var done: Array = ensure_defaults().get("chapters", [])
	for ch in _list("CHAPTERS"):
		if str(ch.flag) == flag_name and done.has(str(ch.id)):
			return true
	var story := _node("Story")
	return story != null and story.has_method("has_flag") and bool(story.has_flag(flag_name))


## 把剧情当前章节推进到最新的已解锁章节（不倒退）
static func _sync_chapter() -> void:
	var want := current_chapter()
	var story := _node("Story")
	if story == null or want == "":
		return
	var cur := str(story.chapter)
	if cur == "" or _chapter_index(want) > _chapter_index(cur):
		story.set_chapter(want)


static func _complete_chapter(ch: Dictionary) -> bool:
	var id := str(ch.get("id", ""))
	if id == "" or chapter_done(id):
		return false
	var s := ensure_defaults()
	(s["chapters"] as Array).append(id)
	var story := _node("Story")
	if story != null and story.has_method("set_flag"):
		story.set_flag(str(ch.get("flag", "")), true)
	Audio.play_ui("grow_level")
	Events.emit_custom("chapter_completed", {"id": id, "title": str(ch.get("title", ""))})
	_sync_chapter()
	_save()
	return true


## 撤离成功推进该战区的章节（击破 Boss 才算完成的章节不在此列）
static func _complete_map_chapter(map_id: String) -> void:
	for ch in _list("CHAPTERS"):
		if str(ch.map) != map_id or str(ch.complete_on) == "boss":
			continue
		if chapter_unlocked(str(ch.id)) and not chapter_done(str(ch.id)):
			_complete_chapter(ch)
			return


static func _on_boss_defeated(boss_id: String) -> void:
	for ch in _list("CHAPTERS"):
		if str(ch.get("boss", "")) != boss_id:
			continue
		if chapter_unlocked(str(ch.id)) and not chapter_done(str(ch.id)):
			_complete_chapter(ch)


# ---------------------------------------------------------------- 准入筛选
## 商店里由研究节点解锁的商品：对应研究未完成时不上架
static func shop_allowed(id: String) -> bool:
	var gated := false
	for rid in _table("RESEARCH"):
		var shop: Array = _table("RESEARCH")[rid].get("shop", [])
		if not shop.has(id):
			continue
		if research_done(str(rid)):
			return true
		gated = true
	return not gated


## 章节战区：移除未开放封堵，全部战区默认开放
static func map_allowed(_id: String) -> bool:
	return true


# ---------------------------------------------------------------- 机体数值
static func _add_stats(dst: Dictionary, add: Dictionary, mult: float) -> void:
	if mult == 0.0:
		return
	for k in add:
		dst[k] = float(dst.get(k, 0.0)) + float(add[k]) * mult


## GameData.compute_stats 的钩子：在模块基础数值之后叠加设施、研究、驾驶员、船员与餐点加成。
## 模块本身的数值不改，这里只改本次计算的合计结果。
static func stat_hook(stats: Dictionary, _loadout: Dictionary) -> void:
	var s: Dictionary = network_profile if network_profile != null else ensure_defaults()
	var fac: Dictionary = s.get("facilities", {})
	for id in _table("FACILITIES"):
		var lv := int(fac.get(id, 0))
		if lv > 0:
			_add_stats(stats, _table("FACILITIES")[id].get("stat", {}), lv)
	var done: Array = s.get("research", [])
	for rid in done:
		if _table("RESEARCH").has(str(rid)):
			_add_stats(stats, _table("RESEARCH")[rid].get("stat", {}), 1.0)
	var pilots: Dictionary = s.get("pilots", {})
	var pid := str(s.get("active_pilot", "nao"))
	var pd: Dictionary = _table("PILOTS").get(pid, {})
	var p: Dictionary = pilots.get(pid, {})
	if not pd.is_empty() and not p.is_empty():
		_add_stats(stats, pd.get("level_stat", {}), float(int(p.get("level", 1)) - 1))
		for tid in p.get("talents", []):
			var t := _talent(pid, str(tid))
			if not t.is_empty():
				_add_stats(stats, t.get("stat", {}), 1.0)
	var crew: Dictionary = s.get("crew", {})
	for cid in _table("CREW"):
		var lv := int((crew.get(cid, {}) as Dictionary).get("level", 0))
		if lv > 0:
			_add_stats(stats, _table("CREW")[cid].get("stat", {}), lv)
	_add_stats(stats, meal_bonus(), 1.0)
	var ab: Dictionary = s.get("abilities", {})
	for aid in _table("ABILITIES"):
		var alv := int(ab.get(aid, 0))
		if alv > 0:
			_add_stats(stats, _table("ABILITIES")[aid].get("stat", {}), alv)
	stats["drain"] = maxf(0.02, float(stats.get("drain", 0.1)))
	stats["hp"] = maxf(30.0, float(stats.get("hp", 30.0)))
	stats["energy"] = maxf(30.0, float(stats.get("energy", 30.0)))
	stats["speed"] = maxf(1.0, float(stats.get("speed", 1.0)))
	stats["load"] = maxf(5.0, float(stats.get("load", 5.0)))
	stats["cargo"] = maxf(0.0, float(stats.get("cargo", 0.0)))
	stats["armor"] = clampf(float(stats.get("armor", 0.0)), 0.0, 0.6)


static func _meal_bonus_for(s: Dictionary) -> Dictionary:
	var lv := int(s.get("meal", 0))
	if lv <= 0: return {}
	var m := _table("MEAL")
	var out := {"energy": 8.0 + float(m.get("energy", 0.0)) * lv, "hp": float(m.get("hp", 0.0)) * lv, "drain": float(m.get("drain", 0.0)) * lv}
	if "res_ration" in s.get("research", []):
		out.energy += float(m.get("ration_energy", 0.0))
		out.hp += float(m.get("ration_hp", 0.0))
	return out


## 工坊等级降低的后勤售价倍率（机库商店可选接入；基础倍率 1.25，每级 -0.03）
static func price_mult() -> float:
	return clampf(1.25 - 0.03 * facility_level("workshop"), 1.0, 1.25)


## 机库应急机架：机库达到 3 级换标准躯干，5 级再把底盘换成履带、右臂换成霰弹
static func starter_kit() -> Dictionary:
	var gd := _gd()
	if gd == null:
		return {}
	var kit: Dictionary = gd.STARTER.duplicate()
	var lv := facility_level("hangar")
	if lv >= 3:
		kit["core"] = "core_std"
	if lv >= 5:
		kit["legs"] = "legs_tread"
		kit["arm_r"] = "arm_shotgun"
	return kit


# ---------------------------------------------------------------- 行动结算
static func _map_index(map_id: String) -> int:
	var gd := _gd()
	if gd == null:
		return 0
	return maxi(0, (gd.map_ids() as Array).find(map_id))


static func _raid_xp(success: bool, result: Dictionary) -> int:
	var kills := int(result.get("kills", 0))
	var value := 0
	var gd := _gd()
	if gd != null:
		value = int(gd.value_of(result.get("cargo", [])))
	var idx := _map_index(str(result.get("map_id", "")))
	if success:
		return 70 + kills * 4 + mini(240, int(value / 12.0)) + idx * 20
	return 25 + kills * 2 + idx * 10


## 行动结束：发放驾驶员经验、推进章节、清掉本局的出击餐点；失败时按医务室等级回收一件模块。
## main.gd 在广播 raid_finished 之前已经把货物与货币入账，这里的改动会随同一次存档一起保存。
static func _on_raid_finished(success: bool, result: Dictionary) -> void:
	ensure_defaults()
	var map_id := str(result.get("map_id", ""))
	if success:
		_complete_map_chapter(map_id)
		record_skill_xp("ab_covert", 4.5)
		var gd_w := _gd()
		if gd_w != null:
			var cw := float(gd_w.weight_of(result.get("cargo", [])))
			if cw > 0.5:
				record_skill_xp("ab_rack", clampf(cw * 0.16, 0.4, 5.5))
	var xp := _raid_xp(success, result)
	var report := {"xp": xp, "map_id": map_id, "success": success, "levels": {}, "skills": raid_skill_summary()}
	var active := active_pilot()
	var leveled := {}
	for pid in _table("PILOTS"):
		var amount := xp if str(pid) == active else int(xp * 0.25)
		var gained := _add_pilot_xp_raw(str(pid), amount)
		if gained > 0:
			leveled[str(pid)] = gained
			Events.emit_custom("pilot_leveled", {"id": str(pid), "level": pilot_level(str(pid)), "gained": gained})
	report["levels"] = leveled
	if not success:
		var back := _try_recover(result)
		if back != "":
			report["recovered"] = back
	if meal_ready() > 0:
		var ss := ensure_defaults()
		ss["meal"] = 0
		report["meal_used"] = true
	result["skill_summary"] = report["skills"]
	Events.emit_custom("growth_report", report)
	_save()


## 医务室：行动失败时按等级概率把一件遗失模块捞回仓库（5 级必定回收一件）
static func _try_recover(result: Dictionary) -> String:
	var lv := facility_level("infirmary")
	if lv <= 0 or randf() > 0.2 * lv:
		return ""
	var lost: Array = []
	var lo = result.get("loadout", {})
	if typeof(lo) != TYPE_DICTIONARY:
		return ""
	for slot in lo:
		var id := str(lo[slot])
		if id != "":
			lost.append(id)
	if lost.is_empty():
		return ""
	var pick := str(lost[randi() % lost.size()])
	var gd := _gd()
	if gd == null:
		return ""
	gd.stash.append(pick)
	Audio.play_ui("grow_recover")
	Events.emit_custom("module_recovered", {"id": pick})
	return pick


static func _who_char(who: String) -> String:
	var map: Dictionary = tables().get("WHO_CHAR", {})
	for name in map:
		if who.begins_with(str(name)):
			return str(map[name])
	const EXTRA := {"Chef Ajin": "ajin", "Mechanic Mia": "mia", "Armor Workshop": "mia"}
	for name in EXTRA:
		if who.begins_with(name):
			return str(EXTRA[name])
	return ""


## 后勤委托提交后按委托人加好感；新委托条目可以直接写 "char"。
static func _on_request_fulfilled(req: Dictionary) -> void:
	var char_id := str(req.get("char", ""))
	if char_id == "":
		char_id = _who_char(str(req.get("who", "")))
	if char_id != "":
		grant_affinity(char_id, 1)


# ---------------------------------------------------------------- 打捞杂物（技能页的升级材料）
## 技能页展示的材料 id（数据表 MATERIALS 的顺序）
static func material_ids() -> Array:
	return _list("MATERIALS")


static func material_count(id: String) -> int:
	return _count_item(id)


## 费用里每一项的缺口：[{"id", "need", "have"}]；money 用 id "money"。供界面把不够的材料标红。
static func cost_parts(cost: Dictionary) -> Array:
	var out: Array = []
	if cost.is_empty():
		return out
	out.append({"id": "money", "need": int(cost.get("money", 0)), "have": _money()})
	var items: Dictionary = cost.get("items", {})
	for id in items:
		out.append({"id": str(id), "need": int(items[id]), "have": _count_item(str(id))})
	return out


static func can_afford(cost: Dictionary) -> bool:
	return not cost.is_empty() and _has_cost(cost)


## 某件物品作为升级材料出现在哪些「下一级」费用里（仓库页提示用途）；返回显示名列表
static func material_uses(item_id: String) -> Array:
	var out: Array = []
	var loc := _node("Loc")
	for id in facility_ids():
		if (facility_cost(id).get("items", {}) as Dictionary).has(item_id):
			var lv_s := str(loc.call("lv", facility_level(id) + 1)) if loc != null and loc.has_method("lv") else ("%d级" % (facility_level(id) + 1))
			out.append("%s %s" % [facility_name(id), lv_s])
	for id in pod_ids():
		if (pod_cost(id).get("items", {}) as Dictionary).has(item_id):
			var tier_s := str(loc.call("pod_tier_str", pod_tier(id) + 1)) if loc != null and loc.has_method("pod_tier_str") else ("%d阶" % (pod_tier(id) + 1))
			out.append("%s %s" % [pod_name(id), tier_s])
	return out


# ---------------------------------------------------------------- 塔科夫式实战熟练度技能（通过行动使用自动升级，零资源消耗）
static func _ability_xp_need_at(lv: int, mx: int) -> float:
	if lv >= mx:
		return 0.0
	return float(10 * (lv + 1))


static func ability_ids() -> Array:
	return _table("ABILITIES").keys()


static func ability_data(id: String) -> Dictionary:
	return _table("ABILITIES").get(id, {})


static func ability_name(id: String) -> String:
	return str(ability_data(id).get("name", id))


static func ability_max(id: String) -> int:
	return int(ability_data(id).get("max", ABILITY_MAX_DEFAULT))


static func ability_level(id: String) -> int:
	if network_profile != null and typeof(network_profile) == TYPE_DICTIONARY:
		return clampi(int((network_profile.get("abilities", {}) as Dictionary).get(id, 0)), 0, ability_max(id))
	var ab: Dictionary = ensure_defaults().get("abilities", {})
	return clampi(int(ab.get(id, 0)), 0, ability_max(id))


static func ability_xp(id: String) -> float:
	var ax: Dictionary = ensure_defaults().get("ability_xp", {})
	return float(ax.get(id, 0.0))


static func ability_xp_next(id: String) -> float:
	return _ability_xp_need_at(ability_level(id), ability_max(id))


static func ability_elite(id: String) -> bool:
	return ability_level(id) >= ability_max(id)


## 塔科夫式单局精力充沛 / 疲劳递减倍率：初段 1.29x，常规 1.0x，重复过多 0.5x
static func ability_focus_mult(id: String) -> float:
	var raw := float(_raid_skill_raw.get(id, 0.0))
	if raw < FOCUS_RAW:
		return 1.29
	if raw < EXHAUST_RAW:
		return 1.0
	return 0.5


static func reset_raid_skill_fatigue() -> void:
	_raid_skill_raw.clear()
	_raid_skill_gained.clear()
	_raid_skill_leveled.clear()


static func raid_skill_summary() -> Array:
	var out: Array = []
	for id in ability_ids():
		var g := float(_raid_skill_gained.get(id, 0.0))
		var up := int(_raid_skill_leveled.get(id, 0))
		if g >= 0.05 or up > 0:
			out.append({"id": str(id), "name": ability_name(str(id)), "xp": g, "levels": up, "level": ability_level(str(id))})
	return out


## 记录某项实战熟练度动作经验（自动应用塔科夫式单局专注/疲劳倍率，满额自动升级并实时刷新机体数值）
static func record_skill_xp(id: String, raw_amount: float, use_fatigue := true, save_now := false) -> Dictionary:
	var d := ability_data(id)
	if d.is_empty() or raw_amount <= 0.0:
		return {"gained_xp": 0.0, "levels": 0, "level": 0}
	var s := ensure_defaults()
	if s.is_empty():
		return {"gained_xp": 0.0, "levels": 0, "level": 0}
	var mx := ability_max(id)
	var lv := int(s.abilities.get(id, 0))
	if lv >= mx:
		return {"gained_xp": 0.0, "levels": 0, "level": lv}
	var mult := ability_focus_mult(id) if use_fatigue else 1.0
	var eff := raw_amount * mult
	if use_fatigue:
		_raid_skill_raw[id] = float(_raid_skill_raw.get(id, 0.0)) + raw_amount
	_raid_skill_gained[id] = float(_raid_skill_gained.get(id, 0.0)) + eff
	var xp := float(s.ability_xp.get(id, 0.0)) + eff
	var up := 0
	while lv < mx:
		var need := _ability_xp_need_at(lv, mx)
		if need <= 0.0 or xp + 0.0001 < need:
			break
		xp = maxf(0.0, xp - need)
		lv += 1
		up += 1
	if lv >= mx:
		xp = 0.0
	s.abilities[id] = lv
	s.ability_xp[id] = xp
	if up > 0:
		_raid_skill_leveled[id] = int(_raid_skill_leveled.get(id, 0)) + up
		var aud := _node("Audio")
		if aud != null and aud.has_method("play_ui"):
			aud.play_ui("grow_level")
		var ev := _node("Events")
		if ev != null:
			ev.emit_custom("ability_upgraded", {"id": id, "level": lv, "gained": up})
		_notify_live_mech_skill_up(id, lv, d)
	if save_now:
		_save()
	return {"gained_xp": eff, "levels": up, "level": lv, "xp": xp}


static func _notify_live_mech_skill_up(id: String, lv: int, d: Dictionary) -> void:
	var t := _tree()
	if t == null or t.current_scene == null:
		return
	var r = t.current_scene.get("raid")
	if r == null or not is_instance_valid(r) or r.get("mech") == null or not is_instance_valid(r.mech):
		return
	var m = r.mech
	if m.has_method("refresh_growth_stats"):
		m.refresh_growth_stats()
	var bonus_txt := str(d.get("elite", "")) if lv >= int(d.get("max", ABILITY_MAX_DEFAULT)) else str(d.get("effect", ""))
	if m.has_signal("message"):
		var loc := _node("Loc")
		var is_e := loc != null and loc.has_method("is_en") and bool(loc.call("is_en"))
		var fmt := "◆ Skill Up: %s Lv.%d (%s)" if is_e else "◆ 熟练度升级：%s %d级（%s）"
		m.message.emit(fmt % [str(d.get("name", id)), lv, bonus_txt])


static func _on_item_picked_skill(id: String, rar: int) -> void:
	record_skill_xp("ab_search", 0.35 + float(rar) * 0.35)
	var gd := _gd()
	if gd != null:
		var w := float(gd.item(id).get("w", 0.0))
		if w >= 3.0:
			record_skill_xp("ab_rack", clampf(w * 0.16, 0.3, 2.2))


static func _on_tactical_skill_used(key: String, sk_id: String) -> void:
	if key == "space":
		record_skill_xp("ab_servo", 1.15)
	elif key == "f":
		record_skill_xp("ab_reactor", 1.35)
		if sk_id == "shield":
			record_skill_xp("ab_plating", 1.1)
		elif sk_id == "missile":
			record_skill_xp("ab_firearm", 0.9)


static func _on_item_used_skill(id: String) -> void:
	var gd := _gd()
	var b := str(gd.base_id(id)) if gd != null and gd.has_method("base_id") else id
	match b:
		"repair_kit":
			record_skill_xp("ab_frame", 3.2)
		"fuel_cell", "energy_rod", "surge_cell", "coolant_pack":
			record_skill_xp("ab_reactor", 2.4)
		"can_food", "biscuit", "water_tab", "coffee":
			record_skill_xp("ab_reactor", 1.8)
			record_skill_xp("ab_frame", 0.8)
		"sonic_decoy", "extract_flare", "extract_barrier", "beacon":
			record_skill_xp("ab_covert", 2.8)


static func _on_enemy_killed_skill(kind: String) -> void:
	record_skill_xp("ab_firearm", 1.15)
	if kind in ["beetle", "aegis", "crystal_bug", "ironjaw", "mech_beetle", "mortar"]:
		record_skill_xp("ab_plating", 0.95)


## 角色技能已改为塔科夫式使用升级，不再有任何货币或物资消耗
static func ability_cost(_id: String) -> Dictionary:
	return {}


static func can_upgrade_ability(id: String) -> String:
	if ability_data(id).is_empty():
		return "未知技能"
	if ability_level(id) >= ability_max(id):
		return "已满级"
	return "实战使用自动升级"


static func upgrade_ability(_id: String) -> bool:
	return false


static func training_cost() -> Dictionary:
	return {}


static func training_xp() -> int:
	return 0


static func can_train() -> String:
	return "实战行动自动升级"


static func train_protagonist() -> Dictionary:
	return {}


# ---------------------------------------------------------------- 部署仓（战斗队友）
static func pod_ids() -> Array:
	return _table("PODS").keys()


static func pod_data(id: String) -> Dictionary:
	return _table("PODS").get(id, {})


static func pod_name(id: String) -> String:
	return str(pod_data(id).get("name", id))


static func pod_pilot(id: String) -> String:
	return str(pod_data(id).get("pilot", id))


static func _pod_state(id: String) -> Dictionary:
	var pods: Dictionary = ensure_defaults().get("pods", {})
	return pods.get(id, {})


## 0 = 未购买，1..3 = 已购等级
static func pod_tier(id: String) -> int:
	return int(_pod_state(id).get("tier", 0))


static func pod_on(id: String) -> bool:
	return pod_tier(id) > 0 and bool(_pod_state(id).get("on", true))


## 下一级（购买 = tier 1）费用；满级返回空字典
static func pod_cost(id: String) -> Dictionary:
	var costs: Array = pod_data(id).get("cost", [])
	var t := pod_tier(id)
	if t >= POD_MAX_TIER or t >= costs.size():
		return {}
	return costs[t]


static func can_buy_pod(id: String) -> String:
	if pod_data(id).is_empty():
		return "未知部署仓"
	var cost := pod_cost(id)
	if cost.is_empty():
		return "已满级"
	if _money() < int(cost.get("money", 0)):
		return "信用点不足"
	if not _has_cost(cost):
		return "材料不足"
	return ""


## 购买（tier 0→1）或升级（→2、3）；扣钱和仓库杂物
static func buy_pod(id: String) -> bool:
	if can_buy_pod(id) != "":
		return false
	if not _pay_cost(pod_cost(id)):
		return false
	var s := ensure_defaults()
	var pd: Dictionary = s.pods[id]
	pd["tier"] = pod_tier(id) + 1
	if int(pd.tier) == 1:
		pd["on"] = true
	Audio.play_ui("grow_upgrade")
	Events.emit_custom("pod_upgraded", {"id": id, "pilot": pod_pilot(id), "tier": int(pd.tier)})
	_save()
	return true


## 已购部署仓是否随本次出击
static func set_pod_on(id: String, on: bool) -> bool:
	if pod_tier(id) <= 0:
		return false
	var s := ensure_defaults()
	(s.pods[id] as Dictionary)["on"] = on
	_save()
	return true


## 给战斗系统的接口：本次出击随行的 AI 队友。每项 {"pilot": "rei", "tier": 1}（tier 1..3），没买时返回 []。
## 顺序按数据表 PODS 的顺序。
static func ally_squad() -> Array:
	var out: Array = []
	for id in pod_ids():
		if pod_on(id):
			out.append({"pilot": pod_pilot(id), "tier": pod_tier(id)})
	return out
