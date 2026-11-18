extends Node
## Centralized localization manager supporting "zh" (Simplified Chinese) and "en" (English).

signal language_changed(new_lang: String)

const I18nEq := preload("res://scripts/i18n/i18n_equipment.gd")
const I18nWorld := preload("res://scripts/i18n/i18n_world.gd")
const I18nProg := preload("res://scripts/i18n/i18n_progression.gd")
const I18nComms := preload("res://scripts/i18n/i18n_comms.gd")
const I18nUi := preload("res://scripts/i18n/i18n_ui.gd")

const MENU_CFG_PATH := "user://menu.cfg"

var lang := "zh"


func _init() -> void:
	lang = _detect_initial_lang()


func _detect_initial_lang() -> String:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--"):
			return "zh"
	var cfg := ConfigFile.new()
	if cfg.load(MENU_CFG_PATH) == OK:
		var saved := str(cfg.get_value("ui", "lang", cfg.get_value("ui", "title_lang", cfg.get_value("menu", "title_lang", "zh"))))
		if saved == "en" or saved == "zh":
			return saved
	return "zh"


func is_en() -> bool:
	return lang == "en"


func t(zh_text: String, en_text: String = "") -> String:
	if lang != "en":
		return zh_text
	if en_text != "":
		return en_text
	return str(I18nUi.UI_EN.get(zh_text, zh_text))


func map_label(zh_label: String) -> String:
	if lang != "en":
		return zh_label
	return str(I18nWorld.MAP_LABELS_EN.get(zh_label, I18nUi.UI_EN.get(zh_label, zh_label)))


func comm_text(comm_id: String, zh_fallback: String = "") -> String:
	if lang == "en" and comm_id != "" and I18nComms.COMMS_EN.has(comm_id):
		return str(I18nComms.COMMS_EN[comm_id])
	return zh_fallback


func emotion(label_zh: String) -> String:
	if lang != "en":
		return label_zh
	return str(I18nProg.EMOTION_EN.get(label_zh, label_zh))


func zone_name(letter: String, zh_fallback: String = "") -> String:
	if lang == "en":
		return str(I18nWorld.ZONE_NAMES_EN.get(letter, zh_fallback if zh_fallback != "" else letter))
	return zh_fallback if zh_fallback != "" else letter


func landmark_name(ltype: String, zh_fallback: String = "") -> String:
	if lang == "en":
		return str(I18nWorld.LM_NAMES_EN.get(ltype, zh_fallback if zh_fallback != "" else ltype))
	return zh_fallback if zh_fallback != "" else ltype


func leg_type(lt: String) -> String:
	if lang == "en":
		return str(I18nEq.LEG_TYPES_EN.get(lt, lt))
	const ZH := {"biped": "双足", "tread": "履带", "quad": "四足", "hex": "六足"}
	return str(ZH.get(lt, lt))


func lv(n: int) -> String:
	return ("Lv.%d" % n) if lang == "en" else ("%d级" % n)


func armor_tier(n: int) -> String:
	return ("Class %d" % n) if lang == "en" else ("%d级防护" % n)


func pod_tier_str(n: int) -> String:
	return ("Tier %d" % n) if lang == "en" else ("%d阶" % n)


func space_key() -> String:
	return "SPACE" if lang == "en" else "空格"


func reason(r: String) -> String:
	if r == "":
		return ""
	if r.begins_with("研究室 Lv"):
		var n := r.substr("研究室 Lv".length())
		return ("Lab Lv.%s" % n) if lang == "en" else ("研究室 %s级" % n)
	return t(r)


func merchant_info(mid: String, field: String, zh_val: String) -> String:
	if lang != "en":
		return zh_val
	var m: Dictionary = I18nProg.MERCHANTS_EN.get(mid, {})
	return str(m.get(field, zh_val))


func crew_role(cid: String, zh_val: String) -> String:
	if lang != "en":
		return zh_val
	return str(I18nProg.CREW_ROLE_EN.get(cid, zh_val))


func char_profile(cid: String, field: String, zh_val: String) -> String:
	if lang != "en":
		return zh_val
	var p: Dictionary = I18nProg.CHAR_PROFILES_EN.get(cid, {})
	return str(p.get(field, zh_val))


func who_text(zh_who: String) -> String:
	if lang != "en":
		return zh_who
	return str(I18nProg.WHO_EN.get(zh_who, t(zh_who)))


func quest_title(zh_title: String) -> String:
	if lang != "en":
		return zh_title
	return str(I18nProg.QUEST_TITLES_EN.get(zh_title, zh_title))


func set_lang(new_lang: String, persist: bool = true) -> void:
	var norm := "en" if new_lang == "en" else "zh"
	if norm == lang:
		return
	lang = norm
	var gd := get_node_or_null("/root/GameData")
	var is_test := gd != null and bool(gd.call("is_test_run"))
	if persist and not is_test:
		var cfg := ConfigFile.new()
		cfg.load(MENU_CFG_PATH)
		cfg.set_value("ui", "lang", lang)
		cfg.set_value("ui", "title_lang", lang)
		cfg.set_value("menu", "title_lang", lang)
		cfg.save(MENU_CFG_PATH)
	if gd != null and gd.has_method("apply_lang"):
		gd.call("apply_lang", lang)
	var growth_script = load("res://scripts/progression/growth.gd")
	if growth_script != null and growth_script.has_method("invalidate_lang_cache"):
		growth_script.call("invalidate_lang_cache")
	language_changed.emit(lang)


func apply_game_data(gd: Node) -> void:
	var is_e := is_en()
	gd.SLOT_NAMES = I18nEq.SLOT_NAMES_EN.duplicate() if is_e else gd._ZH_SLOT_NAMES.duplicate()
	gd.RARITY_NAMES = I18nEq.RARITY_NAMES_EN.duplicate() if is_e else gd._ZH_RARITY_NAMES.duplicate()
	gd.CAT_NAMES = I18nEq.CAT_NAMES_EN.duplicate() if is_e else gd._ZH_CAT_NAMES.duplicate()
	gd.QUALITY_NAMES = I18nEq.QUALITY_NAMES_EN.duplicate() if is_e else gd._ZH_QUALITY_NAMES.duplicate()
	gd.QUEST_NAMES = I18nProg.QUEST_NAMES_EN.duplicate() if is_e else gd._ZH_QUEST_NAMES.duplicate()

	if not is_e:
		return

	for mid in I18nEq.MODULES_EN:
		if gd.MODULES.has(mid):
			_overlay(gd.MODULES[mid], I18nEq.MODULES_EN[mid])
		if gd.ITEMS.has(mid):
			_overlay(gd.ITEMS[mid], I18nEq.MODULES_EN[mid])
	for iid in I18nEq.ITEMS_EN:
		if gd.ITEMS.has(iid):
			_overlay(gd.ITEMS[iid], I18nEq.ITEMS_EN[iid])
	for sid in I18nEq.SKILLS_EN:
		if gd.SKILLS.has(sid):
			_overlay(gd.SKILLS[sid], I18nEq.SKILLS_EN[sid])
	for lid in I18nEq.LOOT_TABLES_EN:
		if gd.LOOT_TABLES.has(lid):
			_overlay(gd.LOOT_TABLES[lid], I18nEq.LOOT_TABLES_EN[lid])
	for eid in I18nWorld.ENEMIES_EN:
		if gd.ENEMIES.has(eid):
			gd.ENEMIES[eid]["name"] = str(I18nWorld.ENEMIES_EN[eid])
	for pid in I18nWorld.POIS_EN:
		if gd.POIS.has(pid):
			_overlay(gd.POIS[pid], I18nWorld.POIS_EN[pid])
	for mp in I18nWorld.MAPS_EN:
		if gd.MAPS.has(mp):
			var md: Dictionary = gd.MAPS[mp]
			_overlay(md, I18nWorld.MAPS_EN[mp])
			if md.has("labels") and typeof(md["labels"]) == TYPE_ARRAY:
				for row in md["labels"]:
					if typeof(row) == TYPE_ARRAY and row.size() > 0:
						row[0] = map_label(str(row[0]))
			if md.has("extracts") and typeof(md["extracts"]) == TYPE_ARRAY:
				for row in md["extracts"]:
					if typeof(row) == TYPE_ARRAY and row.size() > 0:
						row[0] = map_label(str(row[0]))
	for rq in gd.REQUEST_POOL:
		if typeof(rq) == TYPE_DICTIONARY and rq.has("who"):
			rq["who"] = who_text(str(rq["who"]))
	for m in gd.QUEST_CHAINS:
		var chain: Array = gd.QUEST_CHAINS[m]
		for q in chain:
			if typeof(q) == TYPE_DICTIONARY and q.has("name"):
				q["name"] = quest_title(str(q["name"]))


func apply_growth_tables(tables: Dictionary) -> void:
	if not is_en():
		return
	var facs: Dictionary = tables.get("FACILITIES", {})
	for fid in I18nProg.FACILITIES_EN:
		if facs.has(fid):
			_overlay(facs[fid], I18nProg.FACILITIES_EN[fid])
	var res: Dictionary = tables.get("RESEARCH", {})
	for rid in I18nProg.RESEARCH_EN:
		if res.has(rid):
			_overlay(res[rid], I18nProg.RESEARCH_EN[rid])
	var pilots: Dictionary = tables.get("PILOTS", {})
	for pid in I18nProg.PILOTS_EN:
		if pilots.has(pid):
			var pe: Dictionary = I18nProg.PILOTS_EN[pid]
			if pe.has("name"):
				pilots[pid]["name"] = pe["name"]
	var crew: Dictionary = tables.get("CREW", {})
	for cid in I18nProg.CREW_EN:
		if crew.has(cid):
			_overlay(crew[cid], I18nProg.CREW_EN[cid])
	var chapters: Array = tables.get("CHAPTERS", [])
	for ch in chapters:
		var chid := str(ch.get("id", ""))
		if I18nProg.CHAPTERS_EN.has(chid):
			_overlay(ch, I18nProg.CHAPTERS_EN[chid])
	var meal: Dictionary = tables.get("MEAL", {})
	if not meal.is_empty():
		_overlay(meal, I18nProg.MEAL_EN)
	var abil: Dictionary = tables.get("ABILITIES", {})
	for aid in I18nProg.ABILITIES_EN:
		if abil.has(aid):
			_overlay(abil[aid], I18nProg.ABILITIES_EN[aid])
	var pods: Dictionary = tables.get("PODS", {})
	for poid in I18nProg.PODS_EN:
		if pods.has(poid):
			_overlay(pods[poid], I18nProg.PODS_EN[poid])
	var reqs: Array = tables.get("REQUEST_POOL", [])
	for rq in reqs:
		if typeof(rq) == TYPE_DICTIONARY and rq.has("who"):
			rq["who"] = who_text(str(rq["who"]))


static func _overlay(dst: Dictionary, src: Dictionary) -> void:
	for k in src:
		var v = src[k]
		if typeof(v) == TYPE_ARRAY:
			dst[k] = v.duplicate(true)
		elif typeof(v) == TYPE_DICTIONARY:
			if dst.has(k) and typeof(dst[k]) == TYPE_DICTIONARY:
				_overlay(dst[k], v)
			else:
				dst[k] = v.duplicate(true)
		else:
			dst[k] = v
