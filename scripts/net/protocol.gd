extends RefCounted
## Only plain values cross the wire. Remote paths, objects, methods and stats are never accepted.
const UI = preload("res://scripts/ui.gd")
const VERSION := 1
const PORT := 27847
const MAX_PLAYERS := 4
const MAX_CARGO := 256
const SLOTS := ["core", "legs", "gen", "arm_l", "arm_r", "back"]

static func player_name(value: String) -> String:
	var result := ""
	for c in value.strip_edges():
		if c.unicode_at(0) >= 32 and c not in ["[", "]", "\u007f"]:
			result += c
	return result.left(20) if result != "" else UI._lt("驾驶员", "Pilot")

static func equipment_error(lo: Dictionary, cargo: Array, data: Node, stats := {}) -> String:
	if lo.size() > SLOTS.size() or cargo.size() > MAX_CARGO:
		return UI._lt("装备或货舱数量超限", "Loadout or cargo count exceeds limit")
	for slot in lo:
		if not slot is String or slot not in SLOTS or not lo[slot] is String:
			return UI._lt("装备格式错误", "Invalid loadout format")
		var id: String = lo[slot]
		if id != "" and (id.length() > 96 or not data.MODULES.has(data.base_id(id)) or not data.slot_accepts(slot, id)):
			return UI._lt("装备与槽位不匹配", "Module does not match slot")
	for slot in ["core", "legs", "gen"]:
		if lo.get(slot, "") == "":
			return UI._lt("缺少必要机甲模块", "Missing required core mech modules")
	if lo.get("arm_l", "") == "" and lo.get("arm_r", "") == "":
		return UI._lt("至少需要一件手臂武装", "Requires at least 1 arm weapon")
	for id in cargo:
		if not id is String or id.length() > 96 or not data.ITEMS.has(data.base_id(id)):
			return UI._lt("货舱存在未知物品", "Unknown item in cargo")
	if stats.is_empty(): stats = data.compute_stats(lo)
	if data.weight_of(cargo) > float(stats.cargo) + 0.001:
		return UI._lt("出击货舱超出容量", "Deploy cargo exceeds capacity")
	return ""

static func valid_input(move: Vector2, aim: Vector3) -> bool:
	return move.is_finite() and aim.is_finite() and absf(aim.x) < 1000.0 and absf(aim.z) < 1000.0 and absf(aim.y) < 100.0

static func growth_profile(raw: Dictionary) -> Dictionary:
	# Local saves are the source of ownership in friend co-op. Only bounded progression
	# selections are accepted; the host derives their stats from its own data tables.
	var script: Script = load("res://data/ext/progression.gd")
	var tables: Dictionary = script.get_script_constant_map()
	var out := {"facilities": {}, "research": [], "pilots": {}, "crew": {}, "abilities": {}, "meal": 0, "active_pilot": "nao"}
	for pair in [["facilities", "FACILITIES", 5], ["abilities", "ABILITIES", 10]]:
		var values = raw.get(pair[0], {})
		if not values is Dictionary: continue
		for id in tables[pair[1]]:
			var level = values.get(id, 0)
			if level is int or level is float:
				out[pair[0]][id] = clampi(int(level), 0, int(tables[pair[1]][id].get("max", pair[2])))
	var research = raw.get("research", [])
	if research is Array:
		for id in tables.RESEARCH:
			if id in research: out.research.append(id)
	var crew = raw.get("crew", {})
	if crew is Dictionary:
		for id in tables.CREW:
			var entry = crew.get(id, {})
			if entry is Dictionary and (entry.get("level", 0) is int or entry.get("level", 0) is float):
				out.crew[id] = {"level": clampi(int(entry.get("level", 0)), 0, 5)}
	var pilot = raw.get("active_pilot", "nao")
	if pilot is String and tables.PILOTS.has(pilot): out.active_pilot = pilot
	var pilots = raw.get("pilots", {})
	if pilots is Dictionary:
		for id in tables.PILOTS:
			var entry = pilots.get(id, {})
			if not entry is Dictionary: continue
			var level = entry.get("level", 1)
			if not (level is int or level is float): continue
			var p := {"level": clampi(int(level), 1, 12), "talents": []}
			var talents = entry.get("talents", [])
			if talents is Array:
				for talent in tables.PILOTS[id].get("talents", []):
					if talent.id in talents and p.level >= int(talent.level): p.talents.append(talent.id)
			out.pilots[id] = p
	var meal = raw.get("meal", 0)
	if meal is int or meal is float: out.meal = clampi(int(meal), 0, 5)
	return out
