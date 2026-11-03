extends "res://tests/lib/test_base.gd"
## 虫群巡逻：没发现目标时群首在领地里走路点、成员跟着群首；发现机甲整群扑上来；目标跑远后回到巡逻。
## 同时校验数量（地图自然生成的虫数约为旧版上限 60 的 2.5 倍）、十二种常规虫在地表战区都会出现、远处虫子进入低频 LOD。
## godot --headless --path . -- --patrol

const TIMEOUT := 220.0
const Factions = preload("res://scripts/factions/factions.gd")
const REGULAR := ["ling", "spitter", "beetle", "mantis", "bomber", "crystal_bug", "burrower", "mech_beetle", "wasp", "shielder", "mortar", "ironjaw"]


func run() -> void:
	Factions.rovers_enabled = false
	# 生成表：地表五个战区都登记了全部十二种常规虫
	for mid in ["greyport", "ironbelt", "dustfield", "redlake", "canyon"]:
		var kinds: Dictionary = GameData.SPAWNS.get(mid, {}).get("kinds", {})
		for k in REGULAR:
			if not check(kinds.has(k) and float(kinds[k]) > 0.0, "%s 的生成表缺少 %s" % [mid, k]):
				return
	GameData.map_id = "greyport"
	var raid = await deploy()
	if not check(raid != null, "出击失败"):
		return
	var m = raid.mech
	m.max_hp = 1e6
	m.hp = 1e6
	m.shield_time = 9999.0
	var bugs: Array = get_tree().get_nodes_in_group("bugs")
	var leaders: Array = []
	var followers := 0
	var kinds := {}
	for b in bugs:
		kinds[b.kind] = true
		if b.pack_leader == null and b.pack.size() > 0:
			leaders.append(b)
		elif b.pack_leader != null:
			followers += 1
	log_line("bugs=%d leaders=%d followers=%d kinds=%s" % [bugs.size(), leaders.size(), followers, kinds.keys()])
	if not check(bugs.size() >= 120, "地图虫数没有明显增加：%d" % bugs.size()):
		return
	if not check(leaders.size() >= 20 and followers >= 60, "虫群没有编成群首 + 成员"):
		return
	# 巡逻：远离机甲的群首在走动，成员贴着群首
	var far: Array = leaders.filter(func(b): return b.global_position.distance_to(m.global_position) > 60.0)
	var pos0 := {}
	for b in far:
		pos0[b] = b.global_position
	Engine.time_scale = 2.0
	await wait(12.0)
	Engine.time_scale = 1.0
	var moved := 0
	var valid := 0
	for b in far:
		if is_instance_valid(b) and b.state == "idle":
			valid += 1
			if b.global_position.distance_to(pos0[b]) > 3.0:
				moved += 1
	var near_lead := 0
	var fcount := 0
	var lod_far := 0
	for b in get_tree().get_nodes_in_group("bugs"):
		if b.lod == 2:
			lod_far += 1
		if b.pack_leader != null and is_instance_valid(b.pack_leader) and b.state == "idle" and b.pack_leader.state == "idle":
			fcount += 1
			if b.global_position.distance_to(b.pack_leader.global_position) < 16.0:
				near_lead += 1
	log_line("far idle leaders moved %d/%d, followers near leader %d/%d, far-LOD bugs %d" % [moved, valid, near_lead, fcount, lod_far])
	if not check(valid > 0 and moved * 2 >= valid, "远处的群首大多没有走动（%d/%d）" % [moved, valid]):
		return
	if not check(fcount > 0 and near_lead * 10 >= fcount * 7, "成员没有跟住群首（%d/%d）" % [near_lead, fcount]):
		return
	if not check(lod_far > 20, "远处的虫子没有进入低频 LOD：%d" % lod_far):
		return
	# 发现 → 整群追击
	var pick = null
	for b in leaders:
		if is_instance_valid(b) and b.state == "idle" and b.pack.size() >= 2 and not bool(b.data.get("boss", false)) and b.aggro_range >= 12.0:
			pick = b
			break
	if not check(pick != null, "找不到可测的虫群"):
		return
	var home: Vector3 = pick.home
	var lp: Vector3 = pick.global_position
	m.global_position = lp + Vector3(6, 0.3, 0)
	m.velocity = Vector3.ZERO
	var ok: bool = await until(func(): return is_instance_valid(pick) and pick.state == "chase", 4.0)
	if not check(ok, "机甲贴近后群首没有转入追击"):
		return
	await wait(0.5)
	var chasing := 0
	for f in pick.pack:
		if is_instance_valid(f) and f.state == "chase":
			chasing += 1
	log_line("pack alerted: leader chase, %d/%d members chase" % [chasing, pick.pack.size()])
	if not check(chasing >= 1, "同群成员没有一起追击"):
		return
	# 目标跑远 → 回到巡逻，并走回领地
	m.global_position = Vector3(-lp.x, 0.3, -lp.z).limit_length(150.0)
	if m.global_position.distance_to(lp) < 100.0:
		m.global_position = lp + (Vector3(1, 0, 0) if lp.x < 0 else Vector3(-1, 0, 0)) * 120.0
		m.global_position.y = 0.3
	Engine.time_scale = 2.0
	ok = await until(func(): return not is_instance_valid(pick) or pick.state == "idle", 12.0)
	if not check(ok and is_instance_valid(pick), "目标跑远后群首没有回到巡逻"):
		Engine.time_scale = 1.0
		return
	await wait(10.0)
	Engine.time_scale = 1.0
	var back: float = pick.global_position.distance_to(home) if is_instance_valid(pick) else 0.0
	log_line("leader back to patrol, %.1f m from home (territory %.0f)" % [back, pick.territory])
	if not check(back < pick.territory + 15.0, "群首没有回到自己的领地：离 home %.1f 米" % back):
		return
	Factions.rovers_enabled = true
