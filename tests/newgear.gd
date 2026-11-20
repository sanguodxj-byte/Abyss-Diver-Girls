extends "res://tests/lib/test_base.gd"
## 新增模块与写实工程系统冒烟：仅保留 SPACE（底盘）与 F（背挂）主动子系统，R 为重装填，验证防弹等级/穿深/工效/部位机械故障
const START := "none"


func run() -> void:
	# 验证 E / R 技能定义已完全移除，且 R 键已绑定为 reload
	for k in GameData.SKILLS:
		if not check(not k.begins_with("core_") and not k.begins_with("gen_"), "GameData.SKILLS 仍残留已移除的躯干/动力炉技能：%s" % k):
			return
	if not check(GameData.module_skill_info("core_assault").is_empty() and GameData.module_skill_info("gen_hfc").is_empty(), "躯干与动力炉不应绑定主动技能"):
		return
	if not check(InputMap.has_action("reload") and not InputMap.has_action("skill_e") and not InputMap.has_action("skill_r"), "输入映射未移除 skill_e/skill_r 或未登记 reload"):
		return

	var m = await _deploy({"core": "core_std", "legs": "legs_titan", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_rocket", "gen": "gen_hfc"})
	if not check(m != null, "TT-8 出击失败"):
		return
	if not check(m.raid.hud.skill_slots.size() == 2 and m.raid.hud.skill_slots.has("space") and m.raid.hud.skill_slots.has("f") and not m.raid.hud.skill_slots.has("e") and not m.raid.hud.skill_slots.has("r"), "HUD 技能栏应仅保留 SPACE 与 F 两个槽位"):
		return
	# 验证移除换弹后 reload_all 不再进入换弹，双臂均直接消耗能量射击
	m.reload_all()
	if not check(m.reload_t["arm_l"] == 0.0 and m.reload_t["arm_r"] == 0.0, "移除弹药设定后不应触发换弹"):
		return

	# 验证 TT-8 重装双足与 HX-6 六足底盘换装及 SPACE 位移技能
	m.shield_time = 999.0
	var from: Vector3 = m.global_position
	m.try_dash(Vector3.FORWARD)
	await wait(0.65)
	if not check(m.global_position.distance_to(from) > 2.0, "TT-8 重装双足没有突进"):
		return
	m.equip_module_in_raid("legs", "legs_hex")
	m.dash_cd = 0.0
	m.energy = m.max_energy
	var from_hex: Vector3 = m.global_position
	m.try_dash(Vector3.FORWARD)
	await wait(0.6)
	if not check(m.leg_type == "hex" and m.global_position.distance_to(from_hex) > 2.0, "HX-6 六足底盘换装或震踏突进异常"):
		return

	# 验证写实化工程参数（防弹等级 Class 1~6、穿甲深度 mm、MOA 散布、人机工效）与部位受损机械故障
	for mid in GameData.MODULES:
		var md: Dictionary = GameData.MODULES[mid]
		var slot := str(md.get("slot", ""))
		if slot in ["core", "legs"]:
			if not check(md.has("armor_class") and md.has("ergo"), "模块 %s 缺少写实防弹等级或人机工效参数" % mid):
				return
		elif slot == "arm":
			if not check(md.has("caliber") and md.has("pen") and md.has("ergo") and md.has("moa"), "武装 %s 缺少口径/穿深/工效/MOA参数" % mid):
				return
	var light_st := GameData.compute_stats(GameData.STARTER)
	var heavy_st := GameData.compute_stats({"core": "core_fortress", "legs": "legs_titan", "arm_l": "arm_rail", "arm_r": "arm_cannon", "back": "back_vls", "gen": "gen_crystal"})
	if not check(int(heavy_st.armor_class) == 6 and int(light_st.armor_class) == 2 and float(light_st.ergo) > float(heavy_st.ergo), "防弹等级或人机工效计算异常"):
		return
	# 验证部位受损 < 50% 时的渐进机械故障（手臂散布扩大、底盘液压减速）
	var base_sp: float = m.eff_spread("arm_l", 5.0)
	var base_spd: float = m.speed_mult()
	m.parts["arm_l"] = 0.2
	m.parts["legs"] = 0.2
	if not check(m.eff_spread("arm_l", 5.0) > base_sp and m.speed_mult() < base_spd, "部位受损低于50%时未触发散布扩大/底盘减速机械故障"):
		return
	# 验证穿甲深度 ap 对重甲敌人的穿透加成
	var bug = m.raid.spawn_bug("aegis", m.global_position + Vector3(8, 0, 0))
	if bug != null:
		var hp0: float = bug.hp
		bug.take_damage(30.0, m.global_position, 0.0)
		var dmg_low_ap: float = hp0 - bug.hp
		var hp1: float = bug.hp
		bug.take_damage(30.0, m.global_position, 0.75)
		var dmg_high_ap: float = hp1 - bug.hp
		if not check(dmg_high_ap > dmg_low_ap, "高穿深弹药未穿透重甲甲壳（低穿 %.1f vs 高穿 %.1f）" % [dmg_low_ap, dmg_high_ap]):
			return
	log_line("new gear realistic specs, R reload, penetration, ergonomics & part trauma ok")


func _deploy(lo: Dictionary):
	var raid = await deploy(lo)
	if raid == null:
		return null
	for b in get_tree().get_nodes_in_group("bugs"):
		b.queue_free()
	raid.mech.shield_time = 999.0
	await wait(0.3)
	return raid.mech
