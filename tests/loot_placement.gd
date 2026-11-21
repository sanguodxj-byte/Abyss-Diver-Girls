extends "res://tests/lib/test_base.gd"
## 校验全 7 张战区的物资箱与建筑/设施语义匹配、分布多样性、可达性与无错位。
## godot --headless --path . -- --loot_placement

const START := "none"
const RaidScript = preload("res://scripts/raid.gd")

const FORBIDDEN_PAIRS := {
	"register": ["military_bldg", "bunker", "sandbags", "tank_wreck", "hive_cache", "wild_cache", "oil_tank", "chimney", "bldg:farm", "bldg:barn", "bldg:silo_barn", "bldg:house", "bldg:apt", "bldg:tenement", "bldg:foundry", "bldg:chem_plant", "bldg:substation", "park_statue"],
	"car_wreck": ["bldg:", "military_bldg", "bunker", "sandbags", "hive_cache", "wild_cache", "park_statue", "oil_tank", "chimney", "harbor_container", "ind_container", "wagon"],
	"container": ["military_bldg", "bunker", "sandbags", "tank_wreck", "hive_cache", "wild_cache", "park_statue", "bldg:house", "bldg:apt", "bldg:tenement", "bldg:terrace", "bldg:duplex", "bldg:arcade_shop", "bldg:stepped_tower", "bldg:farm", "bldg:barn"],
	"cache": ["bldg:arcade_shop", "bldg:stepped_tower", "bldg:courtyard_blk", "bldg:apt", "bldg:tenement", "bldg:substation", "bldg:foundry", "bldg:chem_plant", "bldg:wh", "bldg:cold_store", "military_bldg", "bunker", "sandbags", "park_statue", "oil_tank", "chimney", "harbor_container", "ind_container"],
	"med": ["oil_tank", "chimney", "bldg:foundry", "bldg:substation", "bldg:loco_shed", "harbor_container", "ind_container", "wagon", "gantry"],
	"tech": ["bldg:farm", "bldg:barn", "bldg:silo_barn", "bldg:house", "bldg:apt", "bldg:tenement", "bldg:terrace", "bldg:duplex", "park_statue", "sandbags"],
	"weapon": ["bldg:house", "bldg:apt", "bldg:tenement", "bldg:terrace", "bldg:duplex", "bldg:arcade_shop", "bldg:farm", "bldg:barn", "park_statue", "oil_tank", "chimney"],
}

var problems: Array = []


func _tag_matches(tag: String, rule: String) -> bool:
	if rule.ends_with(":"):
		return tag.begins_with(rule)
	return tag == rule or tag.begins_with(rule + ":")


func run() -> void:
	await frames(2)
	var only := OS.get_environment("MAPS_ONLY")
	var global_kinds := {}
	for mid: String in GameData.map_ids():
		if only != "" and mid != only:
			continue
		await _audit_map(mid, global_kinds)
	log_line("global kind totals: %s" % [global_kinds])
	if only == "":
		for req_k: String in ["supply", "tool", "military", "safe", "ammo", "med", "tech", "register", "weapon", "car_wreck", "container", "cache"]:
			if int(global_kinds.get(req_k, 0)) <= 0:
				problems.append("全图缺少容器类型 %s" % req_k)
	for x in problems.slice(0, 30):
		log_line("  PROBLEM: " + str(x))
	check(problems.is_empty(), "%d 处物资箱配置问题，首条：%s" % [problems.size(), problems[0] if not problems.is_empty() else ""])


func _audit_map(mid: String, global_kinds: Dictionary) -> void:
	GameData.map_id = mid
	var raid = RaidScript.new()
	add_child(raid)
	raid.start(GameData.STARTER.duplicate(), [])
	await frames(2)
	var boxes := get_tree().get_nodes_in_group("lootboxes")
	var kinds := {}
	var ctx_pairs := {}
	var ctx_n := 0
	var poi_n := 0
	for b in boxes:
		var k := str(b.kind)
		kinds[k] = int(kinds.get(k, 0)) + 1
		global_kinds[k] = int(global_kinds.get(k, 0)) + 1
		if b.items.is_empty():
			problems.append("[%s] 空箱 %s @ %s" % [mid, k, b.global_position])
		if raid.in_wet(Vector2(b.global_position.x, b.global_position.z), 1.0):
			problems.append("[%s] 箱子落水 %s @ %s" % [mid, k, b.global_position])
		if raid.nav != null and not raid.nav.is_reachable(b.global_position, true, 3.2):
			problems.append("[%s] 箱子不可达 %s @ %s" % [mid, k, b.global_position])
		if b.has_meta("poi"):
			poi_n += 1
		if b.has_meta("contextual_loot"):
			ctx_n += 1
			var tag := str(b.get_meta("contextual_loot"))
			var pk := "%s->%s" % [tag, k]
			ctx_pairs[pk] = int(ctx_pairs.get(pk, 0)) + 1
			var bad_list: Array = FORBIDDEN_PAIRS.get(k, [])
			for rule: String in bad_list:
				if _tag_matches(tag, rule):
					problems.append("[%s] 建筑/容器错配: %s 刷出 %s @ (%.0f, %.0f)" % [mid, tag, k, b.global_position.x, b.global_position.z])
	log_line("[%s] total=%d (ctx=%d poi=%d) kinds=%s" % [mid, boxes.size(), ctx_n, poi_n, kinds])
	var pair_keys := ctx_pairs.keys()
	pair_keys.sort()
	var sample: Array = []
	for pk in pair_keys:
		sample.append("%s:%d" % [pk, ctx_pairs[pk]])
	log_line("[%s] pairs=%s" % [mid, ", ".join(sample)])
	raid.queue_free()
	await frames(3)
