extends "res://tests/lib/test_base.gd"
## 敌人验收：九种新虫与三个 Boss 逐个生成，各自跑一段 AI，检查追击 → 前摇 → 出手的状态切换、受击掉血、死亡移出虫群；
## Boss 另查登场 / 阶段 / 击破三个事件的广播、阶段推进与弱点倍率。
## godot --headless --path . -- --enemies

const ARENA := Vector3(760, 0, 760)
## 炮击型要放进它的射程里才会开火
## 曲炮虫放在 16 米：敌人视野封顶为玩家视野的 0.9 倍，机甲正下方（屏幕下边最近）只有约 17.6 米
const SPAWN_D := {"mortar": 16.0, "wasp": 10.0, "shielder": 11.0}
const REGULARS := ["mantis", "bomber", "crystal_bug", "burrower", "mech_beetle", "wasp", "shielder", "mortar", "ironjaw"]
const BOSSES := ["broodmother", "king_beetle", "abyss_queen"]
const ARENA_AI := {"mantis": "lancer", "bomber": "bomber", "crystal_bug": "shell", "burrower": "burrower",
	"mech_beetle": "jammer", "wasp": "flyer", "shielder": "support", "mortar": "artillery", "ironjaw": "juggernaut"}

var seen := {}
var raid
var mech


func run() -> void:
	Events.any.connect(func(e: String, _a): seen[e] = int(seen.get(e, 0)) + 1)
	raid = await deploy({"core": "core_heavy", "legs": "legs_quad", "arm_l": "arm_mg", "arm_r": "arm_laser", "back": "back_cargo", "gen": "gen_crystal"})
	if not check(raid != null, "出击失败"):
		return
	mech = raid.mech
	# 剧情演出会暂停整棵树播对话；这条测试只验敌人行为，先把剧情系统停掉
	Story.set_process(false)
	Story.data = {}
	get_tree().paused = false
	# 每个已登记战区都要有自己的虫群分布表；有区域 Boss 的战区由布置脚本放 Boss
	var missing: Array = []
	for mid: String in GameData.MAPS:
		if not GameData.SPAWNS.has(mid):
			missing.append(mid)
	if not check(missing.is_empty(), "以下战区没有虫群分布表：%s" % [missing]):
		return
	var no_script: Array = []
	for mid: String in ["redlake", "canyon", "abyss_maw"]:
		if GameData.SPAWNS.has(mid) and str(GameData.SPAWNS[mid].get("script", "")) == "":
			no_script.append(mid)
	if not check(no_script.is_empty(), "以下战区没有布置区域 Boss 的脚本：%s" % [no_script]):
		return
	# 分布表只能引用登记过的虫种，掉落表必须存在；否则生成时会静默退化成默认虫群或空箱
	var bad_kind: Array = []
	var bad_loot: Array = []
	var bad_ai: Array = []
	var ais := {}
	for mid: String in GameData.SPAWNS:
		for k in GameData.SPAWNS[mid].get("kinds", {}):
			if not GameData.ENEMIES.has(str(k)):
				bad_kind.append("%s:%s" % [mid, k])
	for kind: String in GameData.ENEMIES:
		var info: Dictionary = GameData.ENEMIES[kind]
		if float(info.get("drop", 0.0)) > 0.0 and not GameData.LOOT_TABLES.has(str(info.get("loot", "bug"))):
			bad_loot.append("%s:%s" % [kind, info.get("loot", "bug")])
	for kind: String in REGULARS:
		var ai := str(GameData.ENEMIES.get(kind, {}).get("ai", ""))
		if ais.has(ai):
			bad_ai.append("%s 与 %s 都是 %s" % [kind, ais[ai], ai])
		ais[ai] = kind
	if not check(bad_kind.is_empty(), "分布表引用了未登记的虫种：%s" % [bad_kind]):
		return
	if not check(bad_loot.is_empty(), "以下敌人登记了不存在的掉落表：%s" % [bad_loot]):
		return
	if not check(bad_ai.is_empty(), "常规虫的行为原型重复，缺少各自的定位：%s" % [bad_ai]):
		return
	for bk: String in BOSSES:
		var bi: Dictionary = GameData.ENEMIES.get(bk, {})
		var ph: Array = bi.get("phases", [])
		var ok := ph.size() >= 2 and absf(float(ph[0]) - 1.0) < 0.001 and float(bi.get("weak_back", 0.0)) > 0.0
		for i in range(1, ph.size()):
			if float(ph[i]) >= float(ph[i - 1]):
				ok = false
		if not check(ok, "%s 的阶段阈值或背部弱点没有配置正确" % bk):
			return
	log_line("spawns=%s" % [GameData.SPAWNS.keys()])
	# 观察期压缩：AI 的时间轴按缩放后的时间推进，状态切换照样逐帧可见
	Engine.time_scale = 2.0
	await _clear()
	raid._static_box(Vector3(140, 1, 140), ARENA - Vector3(0, 0.5, 0), Color(0.5, 0.5, 0.5))
	mech.global_position = ARENA + Vector3(0, 0.2, 0)
	await wait(0.5)
	for kind: String in REGULARS:
		if not await _test_regular(kind):
			return
	if not await _test_traits():
		return
	for kind: String in BOSSES:
		if not await _test_boss(kind):
			return
	Engine.time_scale = 1.0
	log_line("events=%s" % [seen])
	check(not seen.is_empty(), "整轮测试没有收到任何事件")


func _clear() -> void:
	for b in get_tree().get_nodes_in_group("bugs"):
		b.queue_free()
	for n in get_tree().get_nodes_in_group("nests"):
		n.queue_free()
	await frames(3)


func _hold_mech() -> void:
	mech.hp = mech.max_hp
	mech.energy = mech.max_energy
	mech.shield_time = 999.0


func _test_regular(kind: String) -> bool:
	if not check(GameData.ENEMIES.has(kind), "种类 %s 没有登记" % kind):
		return false
	var info: Dictionary = GameData.ENEMIES[kind]
	if not check(str(info.get("script", "")) != "", "%s 没有登记行为脚本" % kind):
		return false
	if not check(str(info.get("ai", "")) == str(ARENA_AI.get(kind, "")), "%s 的 ai 字段与预期不符：%s" % [kind, info.get("ai", "")]):
		return false
	await _clear()
	var d: float = float(SPAWN_D.get(kind, 9.0))
	var b = raid.spawn_bug(kind, ARENA + Vector3(0, 0.5, d))
	if not check(b != null, "%s 生成失败" % kind):
		return false
	if not check(b.data.get("boss", false) == false, "%s 不该登记成 Boss" % kind):
		return false
	var acts := {}
	var states := {}
	var tg_seen := false
	var killed0: int = int(seen.get("enemy_killed", 0))
	var t := 0.0
	while t < 5.0 and is_instance_valid(b):
		await get_tree().process_frame
		t += get_process_delta_time()
		get_tree().paused = false
		_hold_mech()
		if not is_instance_valid(b):
			break
		if b.act != "":
			acts[b.act] = true
		if b.act == "wind" and is_instance_valid(b.telegraph):
			tg_seen = true
		states[b.state] = true
	if not check(is_instance_valid(b), "%s 在观察期内消失" % kind):
		return false
	log_line("%s ai=%s states=%s acts=%s hp=%.0f" % [kind, b.ai, states.keys(), acts.keys(), b.hp])
	if not check(states.has("chase"), "%s 没有进入追击状态：%s" % [kind, states.keys()]):
		return false
	if not check(acts.has("wind"), "%s 没有出现可读的出手前摇：%s" % [kind, acts.keys()]):
		return false
	if not check(tg_seen, "%s 的前摇没有在地面上画出攻击范围" % kind):
		return false
	# 自爆型会在观察期里自己炸掉：这条路径也要确实算一次击杀
	if b.hp <= 0.0 or b.dying:
		if not check(int(seen.get("enemy_killed", 0)) > killed0, "%s 自己炸掉时没有广播 enemy_killed" % kind):
			return false
		return true
	# 受击：从机甲方向打进去，血量必须下降
	await until(func(): return not b.underground, 6.0)
	var hp0: float = b.hp
	b.take_damage(14.0, mech.global_position)
	if not check(b.hp < hp0, "%s 受击后血量没有下降：%.1f → %.1f" % [kind, hp0, b.hp]):
		return false
	# 死亡：从虫群组里移除，并且广播 enemy_killed
	var kills: int = int(seen.get("enemy_killed", 0))
	b.take_damage(99999.0, mech.global_position)
	if not check(b.dying, "%s 受到致命伤后没有进入死亡" % kind):
		return false
	if not check(int(seen.get("enemy_killed", 0)) == kills + 1, "%s 死亡没有广播 enemy_killed" % kind):
		return false
	await frames(3)
	if not check(not b.is_in_group("bugs"), "%s 死亡后仍留在虫群组里" % kind):
		return false
	return true


## 三种定位必须真的成立：晶背虫的正面折射、盾脉虫的群体修复、钻地虫的潜地免疫。
func _test_traits() -> bool:
	await _clear()
	# 晶背虫：同一发伤害，从正面打进去要被晶甲折掉大半，从背后打则吃满
	var c = raid.spawn_bug("crystal_bug", ARENA + Vector3(0, 0.5, 10))
	if not check(c != null, "晶背虫生成失败"):
		return false
	c.visual.rotation.y = 0.0
	c.hp = float(c.data.hp)
	c.take_damage(20.0, mech.global_position)
	var front: float = float(c.data.hp) - c.hp
	c.hp = float(c.data.hp)
	c.take_damage(20.0, c.global_position + Vector3(0, 0, 30))
	var back: float = float(c.data.hp) - c.hp
	log_line("crystal_bug front=%.1f back=%.1f" % [front, back])
	if not check(back > front * 1.8, "晶背虫的正面折射没有生效：正面 %.1f / 背后 %.1f" % [front, back]):
		return false
	# 盾脉虫：脉冲要同时修甲与上盾，够把一只残血跳虫救回来
	var s = raid.spawn_bug("shielder", ARENA + Vector3(0, 0.5, 7))
	var ally = raid.spawn_bug("ling", ARENA + Vector3(2.5, 0.5, 7))
	if not check(s != null and ally != null, "盾脉虫或同伴生成失败"):
		return false
	ally.hp = 5.0
	s._pulse()
	log_line("shielder ally hp=%.1f shield=%s" % [ally.hp, ally.has_meta("shield_fx")])
	if not check(ally.hp > 5.0, "盾脉虫的脉冲没有修复同伴：%.1f" % ally.hp):
		return false
	if not check(ally.has_meta("shield_fx"), "盾脉虫的脉冲没有给同伴挂上护盾外壳"):
		return false
	# 钻地虫：钻入地下后碰撞关闭、外观隐藏，任何伤害都打不进去
	var bu = raid.spawn_bug("burrower", ARENA + Vector3(0, 0.5, 8))
	if not check(bu != null, "钻地虫生成失败"):
		return false
	bu._burrow_in()
	if not check(bu.underground and bu.collision_layer == 0 and not bu.visual.visible, "钻地虫钻地后没有关闭碰撞与外观"):
		return false
	var hp0: float = bu.hp
	bu.take_damage(50.0, mech.global_position)
	if not check(is_equal_approx(bu.hp, hp0), "钻地虫在地下仍然能被打中"):
		return false
	bu._surface()
	if not check(not bu.underground and bu.collision_layer == 4 and bu.visual.visible, "钻地虫破土后没有恢复碰撞与外观"):
		return false
	return true


func _test_boss(kind: String) -> bool:
	await _clear()
	var ev0: int = int(seen.get("boss_appeared", 0))
	var b = raid.spawn_bug(kind, ARENA + Vector3(0, 0.5, 15.0))
	if not check(b != null, "%s 生成失败" % kind):
		return false
	if not check(b.has_method("hp_ratio"), "%s 不是 Boss 行为脚本" % kind):
		return false
	if not check(await until(func(): return b.awake, 10.0), "%s 被靠近后没有苏醒" % kind):
		return false
	if not check(int(seen.get("boss_appeared", 0)) == ev0 + 1, "%s 苏醒没有广播 boss_appeared" % kind):
		return false
	if not check(b.boss_id == kind and b.title != "", "%s 的 boss_id / title 不正确" % kind):
		return false
	if not check(absf(b.hp_ratio() - 1.0) < 0.02, "%s 苏醒时血量读数不是满的" % kind):
		return false
	# 一阶段的出招：必须有前摇，并且至少放出一招
	var acts := {}
	var tg_seen := false
	var t := 0.0
	while t < 4.5:
		await get_tree().process_frame
		t += get_process_delta_time()
		_hold_mech()
		if b.act != "":
			acts[b.act] = true
		if b.act == "wind" and is_instance_valid(b.telegraph):
			tg_seen = true
	log_line("%s phase=%d acts=%s summoned=%d" % [kind, b.phase, acts.keys(), b.summoned])
	if not check(acts.has("wind"), "%s 一阶段没有出招前摇：%s" % [kind, acts.keys()]):
		return false
	if not check(tg_seen, "%s 的出招前摇没有地面预告" % kind):
		return false
	# 弱点：从背后打的伤害必须高于正面（弱点倍率来自 data.weak_back）
	var away: Vector3 = (b.global_position - mech.global_position).normalized()
	var hp_before: float = b.hp
	b.take_damage(20.0, mech.global_position)
	var front: float = hp_before - b.hp
	b.hp = hp_before
	b.take_damage(20.0, b.global_position + away * 30.0)
	var back: float = hp_before - b.hp
	log_line("%s weak: front=%.1f back=%.1f" % [kind, front, back])
	if not check(back > front * 1.4, "%s 的背部弱点没有生效：正面 %.1f / 背后 %.1f" % [kind, front, back]):
		return false
	# 阶段推进：跨过 data.phases 的阈值就广播 boss_phase_changed
	var ev1: int = int(seen.get("boss_phase_changed", 0))
	b.hp = float(b.data.hp) * 0.55
	if not check(await until(func(): return b.phase >= 2, 6.0), "%s 血量掉到 55%% 没有进入二阶段" % kind):
		return false
	if not check(int(seen.get("boss_phase_changed", 0)) == ev1 + 1, "%s 二阶段没有广播 boss_phase_changed" % kind):
		return false
	await until(func(): return b.guard_t <= 0.0, 6.0)
	b.hp = float(b.data.hp) * 0.2
	if not check(await until(func(): return b.phase >= 3, 6.0), "%s 血量掉到 20%% 没有进入三阶段" % kind):
		return false
	if not check(int(seen.get("boss_phase_changed", 0)) == ev1 + 2, "%s 三阶段没有广播 boss_phase_changed" % kind):
		return false
	# 有晶核弱点的 Boss：三阶段必须把护板打开、核心辉光抬起来
	if b.weak_core > 0.0:
		await wait(0.6)
		log_line("%s core_vis=%.2f" % [kind, b.core_vis])
		if not check(b.core_vis > 0.5, "%s 的晶核暴露没有打开护板" % kind):
			return false
	# 击破
	var ev2: int = int(seen.get("boss_defeated", 0))
	await until(func(): return b.guard_t <= 0.0, 6.0)
	b.take_damage(999999.0, mech.global_position)
	if not check(b.dying, "%s 受到致命伤后没有进入死亡" % kind):
		return false
	if not check(int(seen.get("boss_defeated", 0)) == ev2 + 1, "%s 死亡没有广播 boss_defeated" % kind):
		return false
	await frames(3)
	if not check(not b.is_in_group("boss") and not b.is_in_group("bugs"), "%s 死亡后仍留在虫群 / Boss 组里" % kind):
		return false
	return true
