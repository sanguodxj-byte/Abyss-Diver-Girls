extends "res://tests/lib/test_base.gd"
## 距离衰减：所有弹药不再按射程消失，只按类型衰减；狙击最缓、霰弹最陡。
## godot --headless --path . -- --falloff

const ARENA := Vector3(700, 0, 700)
const P = preload("res://scripts/projectile.gd")


func run() -> void:
	await wait(0.3)
	var sniper: Dictionary = GameData.module("arm_sniper")
	var shotgun: Dictionary = GameData.module("arm_shotgun")
	var fs: Dictionary = GameData.weapon_falloff(sniper)
	var fg: Dictionary = GameData.weapon_falloff(shotgun)
	log_line("sniper near=%.1f far=%.1f min=%.2f | shotgun near=%.1f far=%.1f min=%.2f" % [
		fs["near"], fs["far"], fs["min"], fg["near"], fg["far"], fg["min"]])
	if not check(float(fs["min"]) > float(fg["min"]) and float(fs["far"]) > float(fg["far"]), "狙击衰减应小于霰弹"):
		return

	var p = P.new()
	p.falloff_near = 10.0
	p.falloff_far = 40.0
	p.falloff_min = 0.5
	if not check(absf(p.damage_mult(5.0) - 1.0) < 0.001 and absf(p.damage_mult(25.0) - 0.75) < 0.001 and absf(p.damage_mult(60.0) - 0.5) < 0.001,
			"damage_mult 插值错误：%.2f / %.2f / %.2f" % [p.damage_mult(5.0), p.damage_mult(25.0), p.damage_mult(60.0)]):
		p.free()
		return
	p.free()

	var raid = await deploy({"core": "core_heavy", "legs": "legs_quad", "arm_l": "arm_sniper", "arm_r": "arm_slug", "back": "back_rack", "gen": "gen_crystal"})
	if not check(raid != null, "出击失败"):
		return
	for b in get_tree().get_nodes_in_group("bugs"):
		b.queue_free()
	raid._static_box(Vector3(160, 1, 160), ARENA - Vector3(0, 0.5, 0), Color(0.5, 0.5, 0.5))
	var m = raid.mech
	m.global_position = ARENA + Vector3(0, 0.2, 0)
	m.shield_time = 999
	await wait(0.4)

	# 狙击：目标在 100m（原射程 62m 之外），旧机制会在 62m 消失，新机制应命中并保留约 97% 伤害
	var far_bug = raid.spawn_bug("beetle", ARENA + Vector3(100, 0.5, 0))
	far_bug.hp = 500.0
	far_bug.data = far_bug.data.duplicate()
	far_bug.data.speed = 0.0
	raid.aim_override = far_bug.global_position + Vector3(0, 1.8, 0)
	m.aim_point = raid.aim_override
	await wait(1.0)
	m.arm_cd["arm_l"] = 0.0
	var a0: int = int(m.ammo["arm_l"])
	var hp0: float = far_bug.hp
	log_line("sniper aim=%s dir=%s target=%s ammo=%d muzzle=%s mech=%s layer=%d" % [m.aim_point, m.aim_dir(), far_bug.global_position, a0, m.muzzles["arm_l"].global_position, m.global_position, far_bug.collision_layer])
	m.try_fire("arm_l")
	log_line("sniper fired ammo=%d" % int(m.ammo["arm_l"]))
	await wait(1.8)
	var dealt_sniper: float = hp0 - far_bug.hp
	log_line("sniper @100m dmg=%.1f" % dealt_sniper)
	if not check(dealt_sniper > 40.0, "狙击在 100m 应命中并造成大部分伤害（旧机制会消失）：%.1f" % dealt_sniper):
		return
	far_bug.queue_free()

	# 霰弹：目标在 30m（原射程 16m 之外），应命中但伤害降到最低档
	var near_bug = raid.spawn_bug("beetle", ARENA + Vector3(30, 0.5, 0))
	near_bug.hp = 500.0
	near_bug.data = near_bug.data.duplicate()
	near_bug.data.speed = 0.0
	raid.aim_override = near_bug.global_position + Vector3(0, 1.8, 0)
	m.aim_point = raid.aim_override
	await wait(1.0)
	m.arm_cd["arm_r"] = 0.0
	hp0 = near_bug.hp
	m.try_fire("arm_r")
	await wait(1.8)
	var dealt_shotgun: float = hp0 - near_bug.hp
	log_line("shotgun @30m dmg=%.1f" % dealt_shotgun)
	check(dealt_shotgun > 0.0 and dealt_shotgun < 20.0, "霰弹在 30m 应命中但伤害极低：%.1f" % dealt_shotgun)