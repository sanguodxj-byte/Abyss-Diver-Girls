extends "res://tests/lib/test_base.gd"
## 武器射击资源：移除弹药与装填设定，所有 9 类武器均消耗动力炉能量射击，且同武器类型单发能量消耗固定一致。
## 同时校验 42 件手臂武器的类型与 AMMO 表一致（9 类现实枪械分类）。
## godot --headless --path . -- --weapons

const ARENA := Vector3(700, 0, 700)
const TYPES := ["mg", "autocannon", "cannon", "shotgun", "sniper", "launcher", "flamer", "laser", "melee"]


func run() -> void:
	await wait(0.3)
	_check_tables()
	var raid = await deploy({"core": "core_heavy", "legs": "legs_quad", "arm_l": "arm_laser", "arm_r": "arm_mg", "back": "back_rack", "gen": "gen_crystal"})
	if not check(raid != null, "出击失败"):
		return
	for b in get_tree().get_nodes_in_group("bugs"):
		b.queue_free()
	var m = raid.mech
	m.global_position = ARENA + Vector3(0, 0.2, 0)
	m.shield_time = 999
	await wait(0.4)

	# ---- 机枪（mg）：同类型固定扣 0.05 能量、不占弹匣 ----
	m.arm_cd["arm_r"] = 0.0
	var e0: float = m.energy
	var a0: int = int(m.ammo["arm_r"])
	m.try_fire("arm_r")
	var de_mg: float = e0 - m.energy
	var da_mg: int = a0 - int(m.ammo["arm_r"])
	log_line("mg (arm_mg): energy -%.4f ammo -%d" % [de_mg, da_mg])
	if not check(absf(de_mg - 0.05) < 0.001 and da_mg == 0 and int(m.mag["arm_r"]) == 0, "mg 武器应每发固定扣 0.05 能量且无弹匣：能量 %.4f 弹药 %d 弹匣 %d" % [de_mg, da_mg, int(m.mag["arm_r"])]):
		return

	# ---- 同类型另一把机枪（arm_gatling）：单发能量消耗必须与 arm_mg 完全一致 ----
	m.equip_module_in_raid("arm_r", "arm_gatling")
	await frames(2)
	m.arm_cd["arm_r"] = 0.0
	e0 = m.energy
	m.try_fire("arm_r")
	var de_gatling: float = e0 - m.energy
	log_line("mg (arm_gatling): energy -%.4f" % de_gatling)
	if not check(absf(de_gatling - de_mg) < 0.001, "同类型武器单发能耗必须固定一致：arm_mg=%.4f arm_gatling=%.4f" % [de_mg, de_gatling]):
		return

	# ---- 激光（laser）：每发固定扣 1.60 能量、不占弹匣 ----
	m.arm_cd["arm_l"] = 0.0
	e0 = m.energy
	a0 = int(m.ammo["arm_l"])
	m.try_fire("arm_l")
	var de_laser: float = e0 - m.energy
	var da_laser: int = a0 - int(m.ammo["arm_l"])
	log_line("laser: energy -%.4f ammo -%d" % [de_laser, da_laser])
	if not check(absf(de_laser - 1.6) < 0.001 and da_laser == 0 and int(m.mag["arm_l"]) == 0, "激光应每发固定扣 1.6 能量且不占弹匣：能量 %.4f 弹药 %d 弹匣 %d" % [de_laser, da_laser, int(m.mag["arm_l"])]):
		return

	# ---- 近战工程臂（melee）：每击固定扣 0.30 能量、不占弹匣 ----
	m.equip_module_in_raid("arm_l", "arm_pb09")
	await frames(2)
	check(int(m.mag["arm_l"]) == 0, "近战工程臂不应有弹匣（mag=%d）" % int(m.mag["arm_l"]))
	m.arm_cd["arm_l"] = 0.0
	e0 = m.energy
	a0 = int(m.ammo["arm_l"])
	m.try_fire("arm_l")
	var de_melee: float = e0 - m.energy
	var da_melee: int = a0 - int(m.ammo["arm_l"])
	log_line("melee: energy -%.4f ammo -%d" % [de_melee, da_melee])
	if not check(absf(de_melee - 0.3) < 0.001 and da_melee == 0, "近战工程臂应每击固定扣 0.3 能量且不耗弹药：能量 %.4f 弹药 %d" % [de_melee, da_melee]):
		return

	# ---- 换弹已彻底移除，能量不足时无法射击 ----
	m.start_reload("arm_r")
	m.reload_all()
	if not check(float(m.reload_t["arm_l"]) == 0.0 and float(m.reload_t["arm_r"]) == 0.0, "弹药设定移除后不应进入换弹（reload_l=%.2f reload_r=%.2f）" % [float(m.reload_t["arm_l"]), float(m.reload_t["arm_r"])]):
		return
	m.arm_cd["arm_l"] = 0.0
	m.energy = 0.10
	m.try_fire("arm_l")
	if not check(m.arm_cd["arm_l"] <= 0.0 and absf(m.energy - 0.10) < 0.001, "能量不足单发消耗时不应开火"):
		return
	m.energy = m.max_energy
	log_line("energy-only firing & no-reload rules ok")


func _check_tables() -> void:
	var arms := 0
	var by_type := {}
	var cost_by_type := {}
	for id: String in GameData.ITEMS:
		check(not id.begins_with("mag_"), "弹匣物品应已移除：%s" % id)
	for id: String in GameData.MODULES:
		var mm: Dictionary = GameData.module(id)
		if str(mm.get("slot", "")) != "arm":
			continue
		arms += 1
		var w := str(mm.get("weapon", ""))
		by_type[w] = int(by_type.get(w, 0)) + 1
		if not check(GameData.AMMO.has(w), "%s 的武器类型 %s 未登记在 AMMO" % [id, w]):
			return
		var am: Dictionary = GameData.AMMO[w]
		var mode := str(am.get("mode", ""))
		if not check(mode == "energy" and not GameData.weapon_uses_ammo(w), "%s 应统一为能量射击模式：%s" % [w, mode]):
			return
		check(int(am.get("mag", 1)) == 0 and float(am.get("reload", 1.0)) == 0.0, "%s 不应有弹匣或换弹时长" % w)
		var c := GameData.shot_energy_cost(mm)
		check(c > 0.0, "%s 的 %s 未配置每发能量消耗" % [id, w])
		if cost_by_type.has(w):
			check(absf(float(cost_by_type[w]) - c) < 0.0001, "同武器类型 %s 的单发能耗不一致：%.4f vs %.4f (%s)" % [w, float(cost_by_type[w]), c, id])
		else:
			cost_by_type[w] = c
	for w: String in TYPES:
		check(by_type.has(w), "9 类现实枪械分类缺少 %s" % w)
	log_line("tables ok: %d arms / %s / costs=%s" % [arms, str(by_type), str(cost_by_type)])