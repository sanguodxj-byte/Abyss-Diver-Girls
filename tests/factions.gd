extends "res://tests/lib/test_base.gd"
## 派系：流浪者机甲小队与战斗队友。godot --headless --path . -- --factions
##   1. 注入两名队友（T1 / T3），出击后跟着空投落地，T3 的结构与伤害倍率高于 T1；队友跟随玩家移动
##   2. 在机甲附近放一支 3 台的流浪者小队与一群虫子：流浪者会打虫子、虫子会反击流浪者、流浪者会打玩家，队友会打流浪者
##   3. 流浪者小队沿路线行进；被击毁时散架、掉落「流浪者残骸」物资箱，计入玩家击杀
##   4. 流浪者的随机装配都是合法模块；growth.gd 没有 ally_squad 时读到空列表

const TIMEOUT := 200.0
const Factions = preload("res://scripts/factions/factions.gd")


func run() -> void:
	Factions.rovers_enabled = false
	Factions.test_ally_squad = [{"pilot": "rei", "tier": 1}, {"pilot": "kurumi", "tier": 3}]
	GameData.map_id = "greyport"
	var raid = await deploy()
	if not check(raid != null, "出击失败"):
		return
	var fac = raid.factions
	var m = raid.mech
	m.max_hp = 1e6
	m.hp = 1e6
	if not check(await until(func(): return fac.allies.size() == 2, 5.0), "注入的两名队友没有生成：%d" % fac.allies.size()):
		return
	var a1 = fac.allies[0]
	var a3 = fac.allies[1]
	log_line("allies: %s T%d hp=%.0f dmg=%.2f / %s T%d hp=%.0f dmg=%.2f" % [a1.pilot, a1.tier, a1.max_hp, a1.dmg_mul, a3.pilot, a3.tier, a3.max_hp, a3.dmg_mul])
	if not check(a1.is_in_group("allies") and a1.collision_layer == 32, "队友的分组 / 碰撞层不对"):
		return
	if not check(a3.dmg_mul > a1.dmg_mul and a3.tier == 3, "T3 队友的伤害倍率没有高于 T1"):
		return
	# 清场，测跟随
	for b in get_tree().get_nodes_in_group("bugs"):
		b.queue_free()
	await frames(3)
	# 玩家走一段（可能被建筑挡住），再整体挪到 22 米外的空地：队友要自己走过来，不能靠 70 米外的补位
	var start: Vector3 = m.global_position
	var a1_0: Vector3 = a1.global_position
	Input.action_press("move_right")
	await wait(2.0)
	Input.action_release("move_right")
	m.global_position = fac._free_near(m.global_position + Vector3(22, 0, 0))
	m.velocity = Vector3.ZERO
	await wait(6.0)
	var moved: float = m.global_position.distance_to(start)
	var follow: float = a1.global_position.distance_to(m.global_position)
	var a_moved: float = a1.global_position.distance_to(a1_0)
	log_line("player moved %.1f m, ally moved %.1f m, ally distance %.1f m" % [moved, a_moved, follow])
	if not check(moved > 6.0 and a_moved > 8.0 and follow < 16.0, "队友没有跟随玩家：玩家移动 %.1f 米，队友移动 %.1f 米，距离 %.1f 米" % [moved, a_moved, follow]):
		return
	# 流浪者小队：在机甲东北 30 米外放一支，路线从东往西横穿
	var p0: Vector3 = m.global_position
	var route: Array = [p0 + Vector3(30, 0.3, -8), p0 + Vector3(-60, 0.3, -8)]
	var sq: Dictionary = fac.spawn_squad(3, route)
	if not check(sq.size() > 0 and sq.members.size() == 3, "流浪者小队生成失败"):
		return
	var r0 = sq.members[0]
	for r in sq.members:
		if not check(r.is_in_group("rovers") and r.collision_layer == 16 and r.faction == "rover", "流浪者分组 / 碰撞层不对"):
			return
		for slot in r.loadout:
			var id := str(r.loadout[slot])
			if not check(id == "" or GameData.slot_accepts(slot, id), "流浪者装配了不合法的模块：%s=%s" % [slot, id]):
				return
	log_line("rover loadout: %s" % [r0.loadout])
	# 一群虫子放在流浪者与玩家之间
	var bugs: Array = []
	for i in 6:
		var b = raid.spawn_bug("ling" if i % 2 == 0 else "spitter", p0 + Vector3(18 + i, 0.5, -14))
		if b:
			bugs.append(b)
	var hp_m0: float = m.hp
	var rover_hit_bug := false
	var bug_on_rover := false
	var ally_on_rover := false
	var rover_on_player := false
	var t := 0.0
	while t < 26.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		for b in bugs:
			if is_instance_valid(b):
				if b.aggressor != null and is_instance_valid(b.aggressor) and b.aggressor.is_in_group("rovers"):
					rover_hit_bug = true
				if b.target != null and is_instance_valid(b.target) and b.target.is_in_group("rovers"):
					bug_on_rover = true
		for a in fac.allies:
			if is_instance_valid(a) and a.ai_target != null and is_instance_valid(a.ai_target) and a.ai_target.is_in_group("rovers"):
				ally_on_rover = true
		# 玩家掉血，或有流浪者锁定玩家且视线通畅（开火会被挡在中间的队友吃掉）都算
		if m.hp < hp_m0:
			rover_on_player = true
		for r in sq.members:
			if is_instance_valid(r) and not r.dead and r.ai_target == m and r._los:
				rover_on_player = true
		if rover_hit_bug and bug_on_rover and ally_on_rover and rover_on_player:
			break
	log_line("rover_hit_bug=%s bug_on_rover=%s ally_on_rover=%s player_hurt=%s (%.1fs)" % [rover_hit_bug, bug_on_rover, ally_on_rover, rover_on_player, t])
	if not check(rover_hit_bug, "流浪者没有攻击虫子"):
		return
	if not check(bug_on_rover, "虫子没有反击流浪者"):
		return
	if not check(ally_on_rover, "队友没有攻击流浪者"):
		return
	if not check(rover_on_player, "流浪者没有攻击玩家"):
		return
	# 击毁：散架、掉箱、计入击杀
	var alive: Array = sq.members.filter(func(r): return is_instance_valid(r) and not r.dead)
	if not check(not alive.is_empty(), "流浪者在交战中全灭得太快（无法测掉落）"):
		return
	var victim = alive[0]
	var kills0: int = raid.kills
	var boxes0: int = get_tree().get_nodes_in_group("lootboxes").size()
	victim.aggressor = m
	victim.take_damage(1e6)
	await frames(3)
	var wreck := false
	for b in get_tree().get_nodes_in_group("lootboxes"):
		if b.title == "流浪者残骸" and not b.items.is_empty():
			wreck = true
	log_line("rover killed: dead=%s kills %d→%d boxes %d→%d wreck=%s" % [victim.dead, kills0, raid.kills, boxes0, get_tree().get_nodes_in_group("lootboxes").size(), wreck])
	if not check(victim.dead and not victim.is_in_group("rovers"), "流浪者被击毁后仍在流浪者组里"):
		return
	if not check(raid.kills == kills0 + 1, "击毁流浪者没有计入击杀"):
		return
	if not check(wreck, "流浪者残骸没有掉落物资箱"):
		return
	# 小队路线推进：清场后剩下的成员继续沿路线走
	for b in get_tree().get_nodes_in_group("bugs"):
		b.queue_free()
	m.global_position = p0 + Vector3(0, 0.3, 60)
	for a in fac.allies:
		a.global_position = m.global_position + Vector3(3, 0, 3)
	var idx0: int = sq.idx
	var lead = null
	for r in sq.members:
		if is_instance_valid(r) and not r.dead:
			lead = r
			break
	if lead != null:
		var lp0: Vector3 = lead.global_position
		for k in 8:
			await wait(1.0)
			if is_instance_valid(lead):
				log_line("  t%d fighting=%s calm=%.1f tgt=%s goal=%s pos=%s scale=%.2f v=%.1f spd=%.1f" % [k, sq.fighting, sq.calm, lead.ai_target, lead.goal, lead.global_position, lead.goal_scale, Vector2(lead.velocity.x, lead.velocity.z).length(), float(lead.stats.speed)])
		var gone: bool = not is_instance_valid(lead) or not fac.squads.has(sq)
		var adv: float = 0.0 if gone else lead.global_position.distance_to(lp0)
		log_line("squad advance %.1f m idx %d→%d gone=%s" % [adv, idx0, sq.idx, gone])
		if not check(gone or adv > 6.0 or sq.idx > idx0, "流浪者小队没有沿路线行进"):
			return
	# 自动生成的路线：起点在地图边缘
	var rt: Array = fac.make_route()
	log_line("auto route: %s" % [rt])
	if not check(rt.size() >= 2, "自动路线太短"):
		return
	var s0: Vector3 = rt[0]
	if not check(absf(s0.x) > raid.HALF - 20.0 or absf(s0.z) > raid.HALF - 20.0, "流浪者没有从地图边缘进场：%s" % s0):
		return
	# 接入成长系统：部署仓里买了零（T2，随行）和胡桃（T1，未勾选随行）时，Factions 读到的就是 Growth.ally_squad()
	Factions.test_ally_squad = null
	var G = load("res://scripts/progression/growth.gd")
	var st: Dictionary = G.ensure_defaults()
	var pods0 = st.get("pods", {}).duplicate(true)
	st["pods"] = {"rei": {"tier": 0, "on": true}, "kurumi": {"tier": 0, "on": true}}
	var none: Array = Factions.ally_squad()
	st["pods"] = {"rei": {"tier": 2, "on": true}, "kurumi": {"tier": 1, "on": false}}
	var got: Array = Factions.ally_squad()
	log_line("growth.ally_squad(): none=%s bought=%s" % [none, got])
	st["pods"] = pods0
	if not check(none.is_empty(), "未购买部署仓时队友列表应为空：%s" % [none]):
		return
	if not check(got.size() == 1 and str(got[0].pilot) == "rei" and int(got[0].tier) == 2, "Growth.ally_squad() 没有被正确读取：%s" % [got]):
		return
	Factions.rovers_enabled = true
