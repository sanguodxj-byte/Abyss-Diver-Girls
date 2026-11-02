extends "res://tests/lib/test_base.gd"
## 内容注册表校验：核心表与 data\ext 扩展数据合并后的物品、模块、弹匣、技能、掉落表、商店、委托、战区、POI、敌人、
## 虫群分布，以及剧情数据（data\story）与音频清单的格式。团队新增内容后运行它查漏。godot --headless --path . -- --registry
const START := "none"
const StoryData = preload("res://scripts/story/story_data.gd")
const AudioReg = preload("res://scripts/audio/audio_registry.gd")
const MapsData = preload("res://scripts/maps.gd")

var problems: Array = []


func p(msg: String) -> void:
	problems.append(msg)


func run() -> void:
	await frames(1)
	_items_modules()
	_loot_shop_requests()
	_maps_pois()
	_enemies_spawns()
	_behaviour_scripts()
	for e in StoryData.validate():
		p("剧情数据：" + str(e))
	_story_selftest()
	_audio()
	log_line("ext=%s items=%d modules=%d enemies=%d maps=%d pois=%d" % [GameData.ext_scripts, GameData.ITEMS.size(), GameData.MODULES.size(), GameData.ENEMIES.size(), GameData.MAPS.size(), GameData.POIS.size()])
	for x in problems.slice(0, 40):
		log_line("  " + str(x))
	check(problems.is_empty(), "%d 处问题，首条：%s" % [problems.size(), problems[0] if not problems.is_empty() else ""])


func _items_modules() -> void:
	for id: String in GameData.ITEMS:
		var it: Dictionary = GameData.ITEMS[id]
		if not StoryData.valid_id(id):
			p("物品 id「%s」不是小写 ASCII" % id)
		for k in ["name", "cat", "w", "v", "rar"]:
			if not it.has(k):
				p("物品 %s 缺少字段 %s" % [id, k])
		if it.has("rar") and (int(it.rar) < 0 or int(it.rar) >= GameData.RARITY_NAMES.size()):
			p("物品 %s 的 rar 超出 0..%d" % [id, GameData.RARITY_NAMES.size() - 1])
		if it.has("cat") and not GameData.CAT_NAMES.has(it.cat):
			p("物品 %s 的 cat「%s」不在 CAT_NAMES 里" % [id, it.cat])
	var slots := ["core", "legs", "arm", "back", "gen"]
	for id: String in GameData.MODULES:
		var m: Dictionary = GameData.MODULES[id]
		if not (str(m.get("slot", "")) in slots):
			p("模块 %s 的 slot「%s」不在 %s 里" % [id, m.get("slot", ""), slots])
			continue
		for k in ["name", "w", "v", "rar", "color"]:
			if not m.has(k):
				p("模块 %s 缺少字段 %s" % [id, k])
		match str(m.slot):
			"arm":
				for k in ["weapon", "dmg", "rate", "cost", "range"]:
					if not m.has(k):
						p("武器模块 %s 缺少字段 %s" % [id, k])
				if m.has("weapon") and not GameData.AMMO.has(m.weapon):
					p("武器模块 %s 的 weapon「%s」在 AMMO 里没有弹匣" % [id, m.weapon])
			"legs":
				for k in ["speed", "load", "type"]:
					if not m.has(k):
						p("底盘模块 %s 缺少字段 %s" % [id, k])
				if m.has("type") and not GameData.SKILLS.has(m.type):
					p("底盘模块 %s 的 type「%s」在 SKILLS 里没有位移技能" % [id, m.type])
			"back":
				if not GameData.SKILLS.has(str(m.get("ability", ""))):
					p("背部模块 %s 的 ability「%s」不在 SKILLS 里" % [id, m.get("ability", "")])
				elif str(m.ability) != "none" and not (m.has("cd") and m.has("cost")):
					p("背部模块 %s 缺少 cd / cost" % id)
			"gen":
				for k in ["energy", "eff"]:
					if not m.has(k):
						p("动力炉模块 %s 缺少字段 %s" % [id, k])
		if not GameData.ITEMS.has(id) or GameData.ITEMS[id].get("cat") != "module":
			p("模块 %s 没有登记为物品（id 可能与普通物品重名）" % id)
	for w: String in GameData.AMMO:
		var a: Dictionary = GameData.AMMO[w]
		for k in ["mag", "reload", "tex"]:
			if not a.has(k):
				p("弹匣 %s 缺少字段 %s" % [w, k])
		if a.has("tex") and not ResourceLoader.exists("res://assets/ui/%s.png" % a.tex):
			p("弹匣 %s 的子弹贴图 assets\\ui\\%s.png 不存在" % [w, a.tex])
	for s: String in GameData.SKILLS:
		var sk: Dictionary = GameData.SKILLS[s]
		if not sk.has("name") or not sk.has("icon"):
			p("技能 %s 缺少 name / icon" % s)
		elif not ResourceLoader.exists("res://assets/ui/ic_%s.png" % sk.icon):
			p("技能 %s 的图标 assets\\ui\\ic_%s.png 不存在" % [s, sk.icon])


func _loot_shop_requests() -> void:
	for t: String in GameData.LOOT_TABLES:
		var lt: Dictionary = GameData.LOOT_TABLES[t]
		if str(lt.get("name", "")) == "" or typeof(lt.get("rolls")) != TYPE_ARRAY or typeof(lt.get("pool")) != TYPE_DICTIONARY:
			p("掉落表 %s 需要 name / rolls / pool" % t)
			continue
		if lt.rolls.size() != 2 or int(lt.rolls[0]) > int(lt.rolls[1]) or int(lt.rolls[0]) < 0:
			p("掉落表 %s 的 rolls 应为 [最少, 最多]" % t)
		for id in lt.pool:
			if id != "@module" and not GameData.ITEMS.has(id):
				p("掉落表 %s 里的物品 %s 不存在" % [t, id])
			if float(lt.pool[id]) <= 0.0:
				p("掉落表 %s 里 %s 的权重不大于 0" % [t, id])
	for id in GameData.SHOP:
		if not GameData.ITEMS.has(id):
			p("商店里的 %s 不存在" % id)
	for slot in GameData.STARTER:
		if not GameData.slot_accepts(slot, GameData.STARTER[slot]):
			p("应急机架的 %s 槽装不上 %s" % [slot, GameData.STARTER[slot]])
	for rq in GameData.REQUEST_POOL:
		if not GameData.ITEMS.has(str(rq.get("id", ""))) or int(rq.get("count", 0)) <= 0 or int(rq.get("reward", 0)) <= 0 or str(rq.get("who", "")) == "":
			p("委托 %s 需要存在的 id、正的 count / reward 与 who" % [rq])
	for l in GameData.DISPATCH_LINES:
		if typeof(l) != TYPE_STRING or str(l) == "":
			p("电台台词应为非空字符串：%s" % [l])


func _maps_pois() -> void:
	for pid: String in GameData.POIS:
		var pi: Dictionary = GameData.POIS[pid]
		if str(pi.get("name", "")) == "":
			p("POI %s 缺少 name" % pid)
		if pi.has("script") and not ResourceLoader.exists(str(pi.script)):
			p("POI %s 的脚本 %s 不存在" % [pid, pi.script])
		if not pi.has("script") and not (pid in MapsData.POI_ORDER):
			p("POI %s 没有 script，raid.gd 不会为它建模" % pid)
	for mid: String in GameData.MAPS:
		var md: Dictionary = GameData.MAPS[mid]
		for k in ["name", "tag", "desc", "zones", "roads", "river", "rails", "pois", "labels", "extracts"]:
			if not md.has(k):
				p("战区 %s 缺少字段 %s" % [mid, k])
		if not md.has("zones"):
			continue
		if md.zones.size() != 9:
			p("战区 %s 的 zones 应为 9 行" % mid)
		for row in md.zones:
			if str(row).length() != 9:
				p("战区 %s 的 zones 每行应为 9 个区块字符：%s" % [mid, row])
			for ch in str(row):
				if not MapsData.ZONE_NAMES.has(ch):
					p("战区 %s 用了未登记的区块字符 %s" % [mid, ch])
		if md.has("extracts") and md.extracts.size() < 2:
			p("战区 %s 至少需要 2 个撤离点" % mid)
		for c in md.get("pois", []):
			if c.size() > 2 and not GameData.POIS.has(str(c[2])):
				p("战区 %s 的 POI 类型 %s 不存在" % [mid, c[2]])


func _enemies_spawns() -> void:
	for k: String in GameData.ENEMIES:
		var e: Dictionary = GameData.ENEMIES[k]
		for f in ["name", "hp", "speed", "dmg", "range", "rate", "radius", "scale", "drop"]:
			if not e.has(f):
				p("敌人 %s 缺少字段 %s" % [k, f])
		if e.has("script") and not ResourceLoader.exists(str(e.script)):
			p("敌人 %s 的脚本 %s 不存在" % [k, e.script])
	for mid: String in GameData.SPAWNS:
		var sp: Dictionary = GameData.SPAWNS[mid]
		if not GameData.MAPS.has(mid):
			p("虫群分布指向不存在的战区 %s" % mid)
		if sp.has("script") and not ResourceLoader.exists(str(sp.script)):
			p("战区 %s 的虫群布置脚本 %s 不存在" % [mid, sp.script])
		for kind in sp.get("kinds", {}):
			if not GameData.ENEMIES.has(kind):
				p("战区 %s 的虫群分布里有未登记的敌人 %s" % [mid, kind])


## 行为脚本字段：AMMO.script 要有 static func fire，SKILLS.script 与 ITEMS.script 要有 static func use
func _behaviour_scripts() -> void:
	for pair in [[GameData.AMMO, "AMMO", "fire"], [GameData.SKILLS, "SKILLS", "use"], [GameData.ITEMS, "ITEMS", "use"]]:
		var reg: Dictionary = pair[0]
		for id in reg:
			var path := str(reg[id].get("script", ""))
			if path == "":
				continue
			var s: Script = load(path) if ResourceLoader.exists(path) else null
			if s == null:
				p("%s.%s 的行为脚本 %s 不存在" % [pair[1], id, path])
				continue
			var ok := false
			for m in s.get_script_method_list():
				if m.name == pair[2]:
					ok = true
					break
			if not ok:
				p("%s.%s 的行为脚本 %s 缺少 static func %s" % [pair[1], id, path, pair[2]])


## 剧情数据校验器自检：一份完整合法的样例应零问题，一份逐项写错的样例每处都要被指出；条件匹配逐项验证
func _story_selftest() -> void:
	var line := {"speaker": "zz_a", "expr": "smile", "zh": "中", "ja": "日", "voice": "main_zz_001"}
	var good := {
		"characters": {"zz_a": {"name_zh": "甲", "name_ja": "コウ", "expressions": ["smile"]}},
		"main": {"zz_scene": {"chapter": "zz_ch", "title": "标题", "trigger": {"event": "drop_landed", "when": {}}, "once": true, "bg": "", "lines": [line, {"speaker": "", "expr": "", "zh": "旁白", "ja": "", "voice": ""}]}},
		"side": {},
		"comms": [{"id": "comm_zz", "event": "enemy_seen", "when": {"kind": ["ling", "beetle"]}, "speaker": "zz_a", "expr": "", "zh": "来了", "ja": "来た", "voice": "comm_zz_001", "priority": 1}],
		"codex": {"zz_entry": {"cat": "enemy", "ref": "ling", "title": "跳虫", "body": "正文", "unlock": {"event": "enemy_seen", "when": {"kind": "ling"}}}},
		"chapters": [{"id": "zz_ch", "title": "第一章", "maps": ["greyport"], "intro": "zz_scene", "outro": ""}],
	}
	var ge := StoryData.validate(good)
	if not ge.is_empty():
		p("剧情校验器把合法样例判为有问题：%s" % [ge])
	var bad := good.duplicate(true)
	bad.main["zz_scene"].lines.append({"speaker": "nobody", "expr": "", "zh": "x", "ja": "y", "voice": "main_zz_001"})
	bad.main["zz_scene"].lines.append({"speaker": "zz_a", "expr": "angry", "zh": "", "ja": "", "voice": "Bad Id"})
	bad.comms.append({"id": "comm_zz", "event": "", "speaker": "zz_a", "zh": "x"})
	bad.codex["zz_bad"] = {"cat": "enemy", "ref": "no_such_enemy", "title": "", "body": ""}
	bad.chapters.append({"id": "zz_ch2", "maps": ["no_such_map"], "intro": "no_such_scene"})
	var be := StoryData.validate(bad)
	var want := ["不在 characters.json", "main_zz_001」与", "表情「angry」", "缺少 zh", "Bad Id", "comms.json[1]：id", "缺少 event", "no_such_enemy", "缺少 title", "no_such_map", "no_such_scene"]
	for w in want:
		var hit := false
		for e in be:
			if str(e).contains(w):
				hit = true
				break
		if not hit:
			p("剧情校验器没有指出「%s」：%s" % [w, be])
	var cases := [
		[StoryData.match_when({"kind": "ling"}, {"kind": "ling"}), true],
		[StoryData.match_when({"kind": ["ling", "beetle"]}, {"kind": "beetle"}), true],
		[StoryData.match_when({"kind": "ling"}, {"kind": "spitter"}), false],
		[StoryData.match_when({"kind": "ling"}, {}), false],
		[StoryData.match_when({"rarity": 2}, {"rarity": 2.0}), true],
		[StoryData.match_when({"flag": "f1"}, {}, {"f1": true}), true],
		[StoryData.match_when({"flag": "f1"}, {}, {}), false],
		[StoryData.match_when({"not_flag": "f1"}, {}, {"f1": true}), false],
		[StoryData.match_when({"map": "greyport", "chapter": "c1"}, {}, {}, "c1", "greyport"), true],
		[StoryData.match_when({"map": "greyport"}, {}, {}, "", "canyon"), false],
	]
	for i in cases.size():
		if cases[i][0] != cases[i][1]:
			p("条件匹配第 %d 例结果应为 %s" % [i, cases[i][1]])


## 音效与音乐槽：校验合并后的表（核心清单 + data\ext 的 SFX / MUSIC）
func _audio() -> void:
	for id: String in AudioReg.SFX:
		if not GameData.SFX.has(id):
			p("核心音效 %s 没有并入 GameData.SFX" % id)
	var owner := {}
	for id: String in GameData.SFX:
		if not StoryData.valid_id(id):
			p("音效 id「%s」不是小写 ASCII" % id)
		var e: Dictionary = GameData.SFX[id]
		var files = e.get("files", [])
		if typeof(files) != TYPE_ARRAY or files.is_empty() or str(e.get("when", "")) == "":
			p("音效 %s 需要非空的 files 列表与 when" % id)
			continue
		for f in files:
			var fn := str(f)
			var stem := fn.get_basename()
			if not (fn.get_extension() in ["wav", "ogg"]) or not (stem == id or (stem.begins_with(id + "_") and stem.substr(id.length() + 1).is_valid_int())):
				p("音效 %s 的文件名「%s」应为 %s.wav 或 %s_<两位编号>.wav" % [id, fn, id, id])
			if owner.has(fn):
				p("音效文件 %s 同时登记在 %s 与 %s" % [fn, owner[fn], id])
			owner[fn] = id
		if str(Audio.info(id).bus) not in Audio.BUSES:
			p("音效 %s 的总线不在 %s 里" % [id, Audio.BUSES])
	for slot: String in GameData.MUSIC:
		var mu: Dictionary = GameData.MUSIC[slot]
		if not StoryData.valid_id(slot) or str(mu.get("file", "")) == "" or typeof(mu.get("loop")) != TYPE_BOOL:
			p("音乐槽 %s 需要小写 ASCII id、file 与 loop" % slot)
	for mid: String in GameData.MAPS:
		var slot := str(GameData.MAPS[mid].get("music", mid + "_explore"))
		if not StoryData.valid_id(slot):
			p("战区 %s 的探索曲槽「%s」不是小写 ASCII" % [mid, slot])
		elif not GameData.MUSIC.has(slot):
			log_line("战区 %s 的探索曲槽 %s 未在清单登记，按约定读取 assets\\audio\\music\\%s.ogg" % [mid, slot, slot])
	for path in GameData.RAID_SCRIPTS:
		if not ResourceLoader.exists(str(path)):
			p("行动扩展脚本 %s 不存在" % path)
