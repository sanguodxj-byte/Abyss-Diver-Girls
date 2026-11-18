extends "res://tests/lib/test_base.gd"
## 武器射击资源：实弹耗弹匣不耗能、激光耗能不耗弹、近战工程臂每击少量耗能。
## 同时校验 42 件手臂武器的类型与 AMMO 表一致（9 类现实枪械分类）。
## godot --headless --path . -- --weapons

const ARENA := Vector3(700, 0, 700)
const MODES := ["ammo", "energy", "melee"]
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

	# ---- 实弹：扣弹匣、不扣能量 ----
	m.arm_cd["arm_r"] = 0.0
	var e0: float = m.energy
	var a0: int = int(m.ammo["arm_r"])
	m.try_fire("arm_r")
	var de_ammo: float = e0 - m.energy
	var da_ammo: int = a0 - int(m.ammo["arm_r"])
	log_line("mg: energy -%.4f ammo -%d" % [de_ammo, da_ammo])
	if not check(absf(de_ammo) < 0.001 and da_ammo == 1, "实弹武器应只耗弹药、不耗能量：能量 %.4f 弹药 %d" % [de_ammo, da_ammo]):
		return

	# ---- 激光：扣能量、不占弹匣 ----
	m.arm_cd["arm_l"] = 0.0
	e0 = m.energy
	a0 = int(m.ammo["arm_l"])
	m.try_fire("arm_l")
	var de_laser: float = e0 - m.energy
	var da_laser: int = a0 - int(m.ammo["arm_l"])
	log_line("laser: energy -%.4f ammo -%d" % [de_laser, da_laser])
	if not check(absf(de_laser - 1.6) < 0.001 and da_laser == 0 and int(m.mag["arm_l"]) == 0, "激光应每发扣 1.6 能量且不占弹匣：能量 %.4f 弹药 %d 弹匣 %d" % [de_laser, da_laser, int(m.mag["arm_l"])]):
		return

	# ---- 近战工程臂：每击 0.3 能量、不占弹匣 ----
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
	if not check(absf(de_melee - 0.3) < 0.001 and da_melee == 0, "近战工程臂应每击扣 0.3 能量且不耗弹药：能量 %.4f 弹药 %d" % [de_melee, da_melee]):
		return

	# ---- 换弹只对实弹生效 ----
	m.arm_cd["arm_r"] = 0.0
	m.ammo["arm_r"] = 1
	m.try_fire("arm_r")
	if not check(int(m.ammo["arm_r"]) == 0 and float(m.reload_t["arm_r"]) > 0.0, "实弹打空后应进入换弹：ammo=%d reload=%.2f" % [int(m.ammo["arm_r"]), float(m.reload_t["arm_r"])]):
		return
	m.start_reload("arm_l")
	check(float(m.reload_t["arm_l"]) == 0.0, "激光不应进入换弹（reload=%.2f）" % float(m.reload_t["arm_l"]))
	log_line("reload rules ok")


func _check_tables() -> void:
	var arms := 0
	var by_type := {}
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
		if not check(mode in MODES, "%s 的 AMMO.mode 非法：%s" % [w, mode]):
			return
		if mode == "ammo":
			check(int(am.get("mag", 0)) > 0 and float(am.get("reload", 0.0)) > 0.0, "%s 实弹类型缺弹匣/换弹参数" % w)
		else:
			check(int(am.get("mag", 1)) == 0, "%s 非实弹类型不应有弹匣" % w)
			check(GameData.shot_energy_cost(mm) > 0.0, "%s 的 %s 未配置每发能量消耗" % [id, w])
	for w: String in TYPES:
		check(by_type.has(w), "9 类现实枪械分类缺少 %s" % w)
	log_line("tables ok: %d arms / %s" % [arms, str(by_type)])