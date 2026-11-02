extends "res://tests/lib/test_base.gd"
## 新增模块技能冒烟：躯干/动力炉主动技与重装四足位移
const START := "none"


func run() -> void:
	var m = await _deploy({"core": "core_assault", "legs": "legs_biped", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_cargo", "gen": "gen_hfc"})
	if not check(m != null, "AS-2 出击失败"):
		return
	m.try_skill_e()
	if not check(m.overdrive_t > 0.0, "AS-2 火控过载没有生效"):
		return

	m = await _deploy({"core": "core_fortress", "legs": "legs_biped", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_cargo", "gen": "gen_hfc"})
	if not check(m != null, "FT-5 出击失败"):
		return
	m.try_skill_e()
	if not check(m.guard_t > 0.0, "FT-5 要塞护盾没有生效"):
		return

	m = await _deploy({"core": "core_std", "legs": "legs_biped", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_cargo", "gen": "gen_hfc"})
	if not check(m != null, "HFC-3 出击失败"):
		return
	m.energy = 10.0
	m.try_skill_r()
	if not check(m.energy > 10.0, "HFC-3 应急充能没有补能"):
		return

	m = await _deploy({"core": "core_std", "legs": "legs_titan", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_cargo", "gen": "gen_hfc"})
	if not check(m != null, "TT-8 出击失败"):
		return
	m.shield_time = 999.0
	var from: Vector3 = m.global_position
	m.try_dash(Vector3.FORWARD)
	await wait(0.6)
	if not check(m.global_position.distance_to(from) > 2.0, "TT-8 重装四足没有突进"):
		return
	log_line("new gear skills ok")


func _deploy(lo: Dictionary):
	var raid = await deploy(lo)
	if raid == null:
		return null
	for b in get_tree().get_nodes_in_group("bugs"):
		b.queue_free()
	raid.mech.shield_time = 999.0
	await wait(0.3)
	return raid.mech
