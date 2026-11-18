extends "res://tests/lib/test_base.gd"
## 背部模块：护盾的 4 秒覆盖 + 部位 35% 修复、导弹的齐射冷却与能耗、货舱净增，以及所有背件字段完整性。
## godot --headless --path . -- --backgear

const ARENA := Vector3(700, 0, 700)


func run() -> void:
	await wait(0.3)
	_check_tables()
	var raid = await deploy({"core": "core_heavy", "legs": "legs_quad", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_shield", "gen": "gen_crystal"})
	if not check(raid != null, "出击失败"):
		return
	for b in get_tree().get_nodes_in_group("bugs"):
		b.queue_free()
	var m = raid.mech
	m.global_position = ARENA + Vector3(0, 0.2, 0)
	m.shield_time = 0.0
	m.ability_cd = 0.0
	m.parts["arm_l"] = 0.5
	var e0: float = m.energy
	m.try_ability()
	var de: float = e0 - m.energy
	log_line("shield: energy -%.1f time=%.1f arm_l=%.3f" % [de, m.shield_time, m.parts["arm_l"]])
	if not check(absf(de - 10.0) < 0.001 and m.shield_time > 3.8 and m.shield_time <= 4.0 and absf(float(m.parts["arm_l"]) - 0.675) < 0.001,
			"护盾应为 4 秒、耗能 10、修复 35%% 部位损伤：能量 %.2f 时长 %.2f 部位 %.3f" % [de, m.shield_time, m.parts["arm_l"]]):
		return

	m.equip_module_in_raid("back", "back_missile")
	await frames(2)
	m.ability_cd = 0.0
	e0 = m.energy
	m.try_ability()
	de = e0 - m.energy
	log_line("missile: energy -%.1f cd=%.2f" % [de, m.ability_cd])
	check(absf(de - 8.0) < 0.001 and m.ability_cd > 6.8 and m.ability_cd <= 7.0, "导弹应耗能 8、冷却 7 秒：能量 %.2f 冷却 %.2f" % [de, m.ability_cd])


func _check_tables() -> void:
	var n := 0
	for id: String in GameData.MODULES:
		var mm: Dictionary = GameData.module(id)
		if str(mm.get("slot", "")) != "back":
			continue
		n += 1
		var ab := str(mm.get("ability", "none"))
		if not check(ab in ["missile", "shield", "none"], "%s 的 ability 非法：%s" % [id, ab]):
			return
		if ab == "missile":
			for k in ["cd", "cost", "dmg", "count"]:
				if not check(mm.has(k) and float(mm[k]) > 0.0, "%s 导弹缺少 %s" % [id, k]):
					return
		elif ab == "shield":
			for k in ["cd", "cost", "dur"]:
				if not check(mm.has(k) and float(mm[k]) > 0.0, "%s 护盾缺少 %s" % [id, k]):
					return
		else:
			check(float(mm.get("cargo", 0.0)) > float(mm.get("w", 0.0)) * 1.5, "%s 货舱净增不足" % id)
	log_line("back tables ok: %d modules" % n)