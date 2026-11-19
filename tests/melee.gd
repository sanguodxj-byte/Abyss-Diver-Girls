extends "res://tests/lib/test_base.gd"
## 近战：只命中身前约 3m 扇形，不再生成飞行弹丸。
## godot --headless --path . -- --melee

const ARENA := Vector3(760, 0, 760)


func run() -> void:
	await wait(0.3)
	var m0: Dictionary = GameData.module("arm_pb09")
	var reach: float = GameData.weapon_range_m(m0)
	log_line("pb09 reach=%.1f range=%.1f dmg=%.0f" % [reach, float(m0.get("range", 0.0)), float(m0.get("dmg", 0.0))])
	if not check(reach <= 4.0, "近战射程仍过远：%.1fm" % reach):
		return

	var raid = await deploy({"core": "core_heavy", "legs": "legs_quad", "arm_l": "arm_pb09", "arm_r": "arm_slug", "back": "back_rack", "gen": "gen_crystal"})
	if not check(raid != null, "出击失败"):
		return
	for b in get_tree().get_nodes_in_group("bugs"):
		b.queue_free()
	raid._static_box(Vector3(160, 1, 160), ARENA - Vector3(0, 0.5, 0), Color(0.5, 0.5, 0.5))
	var m = raid.mech
	m.global_position = ARENA + Vector3(0, 0.2, 0)
	m.shield_time = 999
	await wait(0.4)

	# 2m 正前方：应命中
	var near_bug = raid.spawn_bug("beetle", ARENA + Vector3(2.0, 0.5, 0))
	near_bug.hp = 500.0
	near_bug.data = near_bug.data.duplicate()
	near_bug.data.speed = 0.0
	raid.aim_override = near_bug.global_position + Vector3(0, 1.8, 0)
	m.aim_point = raid.aim_override
	await wait(1.0)
	m.arm_cd["arm_l"] = 0.0
	var hp0: float = near_bug.hp
	var en0: float = m.energy
	m.try_fire("arm_l")
	var dealt: float = hp0 - near_bug.hp
	var spent: float = en0 - m.energy
	await wait(0.4)
	log_line("melee @2m dmg=%.1f energy=%.2f" % [dealt, spent])
	if not check(dealt > 20.0, "2m 内近战应命中并造成伤害：%.1f" % dealt):
		return
	if not check(absf(spent - 0.30) < 0.05, "近战每击应耗 0.3 能量：%.2f" % spent):
		return

	# 6m 正前方：不应命中
	var far_bug = raid.spawn_bug("beetle", ARENA + Vector3(6.0, 0.5, 0))
	far_bug.hp = 500.0
	far_bug.data = far_bug.data.duplicate()
	far_bug.data.speed = 0.0
	raid.aim_override = far_bug.global_position + Vector3(0, 1.8, 0)
	m.aim_point = raid.aim_override
	await wait(0.8)
	m.arm_cd["arm_l"] = 0.0
	var fhp0: float = far_bug.hp
	log_line("far pos=%s mech=%s dist=%.2f" % [far_bug.global_position, m.global_position, m.global_position.distance_to(far_bug.global_position)])
	m.try_fire("arm_l")
	await wait(0.4)
	var fdealt: float = fhp0 - far_bug.hp
	log_line("melee @6m dmg=%.1f" % fdealt)
	check(absf(fdealt) < 0.01, "6m 外近战不应命中：%.1f" % fdealt)

	# 身后 1m：不应命中
	raid.aim_override = ARENA + Vector3(-6.0, 1.8, 0)
	m.aim_point = raid.aim_override
	await wait(0.6)
	m.arm_cd["arm_l"] = 0.0
	var bhp0: float = far_bug.hp
	m.try_fire("arm_l")
	await wait(0.4)
	log_line("melee behind=%.1f" % (bhp0 - far_bug.hp))
	check(absf(bhp0 - far_bug.hp) < 0.01, "身后目标不应被近战命中：%.1f" % (bhp0 - far_bug.hp))

	done()