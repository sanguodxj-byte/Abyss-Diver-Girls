extends "res://tests/lib/test_base.gd"
## 武器与技能命中：在地图外的空地上，左臂激光、右臂火焰各对一只定身甲虫开火，蜂巢导弹打一只定身跳虫，
## 再让酸液虫攻击机甲。每一项都必须打出伤害。godot --headless --path . -- --combat

const ARENA := Vector3(700, 0, 700)


func run() -> void:
	await wait(0.3)
	var raid = await deploy({"core": "core_heavy", "legs": "legs_quad", "arm_l": "arm_laser", "arm_r": "arm_flamer", "back": "back_missile", "gen": "gen_crystal"})
	if not check(raid != null, "出击失败"):
		return
	for b in get_tree().get_nodes_in_group("bugs"):
		b.queue_free()
	raid._static_box(Vector3(80, 1, 80), ARENA - Vector3(0, 0.5, 0), Color(0.5, 0.5, 0.5))
	var m = raid.mech
	m.global_position = ARENA + Vector3(0, 0.2, 0)
	m.shield_time = 999
	await wait(0.5)
	var results := {}
	# 左键按住交替射击（左臂激光 + 右臂火焰），并验证右键仅进入瞄准态
	var bug = raid.spawn_bug("beetle", m.global_position + Vector3(0, 0.5, -5.5))
	bug.hp = 500.0
	bug.data = bug.data.duplicate()
	bug.data.speed = 0.0
	raid.aim_override = bug.global_position + Vector3(0, 1.8, 0)
	await wait(0.4)
	var hp0: float = bug.hp
	var l_ammo0: int = int(m.ammo.get("arm_l", 0))
	var r_ammo0: int = int(m.ammo.get("arm_r", 0))
	var energy0: float = m.energy
	Input.action_press("fire_left")
	await wait(1.5)
	Input.action_release("fire_left")
	var hp1: float = bug.hp
	var l_ammo1: int = int(m.ammo.get("arm_l", 0))
	var r_ammo1: int = int(m.ammo.get("arm_r", 0))
	results["alt_fire"] = [hp0, hp1, l_ammo0 - l_ammo1, r_ammo0 - r_ammo1, energy0 - m.energy]
	bug.queue_free()
	await wait(0.2)
	if not check(hp1 < hp0 and r_ammo1 < r_ammo0 and m.energy < energy0, "左键交替射击未同时触发左右臂并造成伤害（激光耗能、火焰耗弹）：%s" % [results["alt_fire"]]):
		return
	var z0: float = raid.cam_zoom
	Input.action_press("fire_right")
	await wait(0.35)
	var aiming_ok: bool = bool(m.is_aiming)
	var z1: float = raid.cam_zoom
	Input.action_release("fire_right")
	results["aim"] = [aiming_ok, z0, z1]
	if not check(aiming_ok and z1 >= z0, "右键未能激活瞄准态：%s" % [results["aim"]]):
		return
	var bug2 = raid.spawn_bug("ling", m.global_position + Vector3(6, 0.5, 0))
	bug2.data = bug2.data.duplicate()
	bug2.data.speed = 0.0
	var ling_hp0: float = bug2.hp
	m.try_ability()
	await wait(2.5)
	results["missile"] = [ling_hp0, bug2.hp]
	log_line("%s kills=%d energy=%.1f/%.1f drain=%.3f" % [results, raid.kills, m.energy, m.max_energy, m.stats.drain])
	if not check(bug2.hp < ling_hp0, "蜂巢导弹没有打出伤害：%s" % [results.missile]):
		return
	# 酸液虫攻击机甲
	m.shield_time = 0
	var hp_before: float = m.hp
	var sp = raid.spawn_bug("spitter", m.global_position + Vector3(0, 0.5, 10))
	sp.state = "chase"
	await wait(5.0)
	log_line("spitter dmg dealt: %.1f" % (hp_before - m.hp))
	check(m.hp < hp_before, "酸液虫没有对机甲造成伤害")
