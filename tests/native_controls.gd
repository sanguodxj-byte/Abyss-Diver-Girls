extends "res://tests/lib/test_base.gd"
const START := "none"
const TIMEOUT := 240.0

func run() -> void:
	GameData.cargo = []
	var r = await deploy({"core": "core_std", "legs": "legs_biped", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_cargo", "gen": "gen_reactor"})
	if not check(r != null, "出击失败"): return
	var m = r.mech
	m.shield_time = 999.0
	if not check(m.ammo.arm_l == 36 and m.ammo.arm_r == 36 and m.cargo.is_empty(), "空货舱出击仍应满装，不能要求实体弹匣"): return
	# 连续多轮打空：每轮必须停止射击并等待完整装填，不消耗物品。
	for cycle in 3:
		m.arm_cd.arm_l = 0.0
		m.ammo.arm_l = 1
		var e0: float = m.energy
		m.try_fire("arm_l")
		if not check(m.ammo.arm_l == 0 and m.reload_t.arm_l > 0.0 and is_equal_approx(m.energy, e0), "最后一发必须耗弹并自动装填"): return
		var remaining: float = m.reload_t.arm_l
		m.start_reload("arm_l")
		if not check(is_equal_approx(m.reload_t.arm_l, remaining), "重复装填请求不得重置计时"): return
		await wait(0.2)
		m.arm_cd.arm_l = 0.0
		m.try_fire("arm_l")
		if not check(m.reload_t.arm_l > 0.0 and m.arm_cd.arm_l == 0.0 and m.ammo.arm_l == 0, "装填期间不得开火或提前补满"): return
		if not check(await until(func(): return m.reload_t.arm_l <= 0.0), "自动装填未完成"): return
		if not check(m.ammo.arm_l == 36 and m.cargo.is_empty(), "装填结束自动补满，不消耗货舱物品"): return
	m.ammo.arm_l = 12
	m.ammo.arm_r = 18
	m.reload_all()
	if not check(m.reload_t.arm_l > 0.0 and m.reload_t.arm_r > 0.0, "R 应能提前装填双臂"): return
	if not check(await until(func(): return m.reload_t.arm_l <= 0.0 and m.reload_t.arm_r <= 0.0), "双臂装填未完成"): return
	if not check(m.ammo.arm_l == 36 and m.ammo.arm_r == 36, "双臂装填后应补满"): return
	log_line("empty cargo, three timed reload cycles, early R reload PASS")
	m.set_physics_process(false)
	r.set_process(false)
	m.is_aiming = false
	var speed: float = m.speed_mult()
	m.is_aiming = true
	if not check(is_equal_approx(m.speed_mult(), speed * 0.5), "瞄准必须减半移动速度"): return
	m.is_aiming = false
	if not check(is_equal_approx(m.speed_mult(), speed), "松开瞄准必须恢复速度"): return
	r.shake = 0.0
	r.aim_override = m.global_position + Vector3(100, 1.8, 0)
	for i in 120: r._process_impl(1.0 / 60.0)
	var height: float = r.camera.global_position.y
	var basis: Basis = r.camera.global_basis
	var zoom: float = r._eff_zoom
	m.is_aiming = true
	for i in 120: r._process_impl(1.0 / 60.0)
	if not check(absf(r.camera.global_position.y - height) < 0.01 and absf(r._eff_zoom - zoom) < 0.001, "普通瞄准不得抬高镜头"): return
	if not check(r.camera.global_basis.is_equal_approx(basis), "普通瞄准不得改变俯角"): return
	var rect := get_viewport().get_visible_rect()
	if not check(not rect.has_point(r.camera.unproject_position(m.global_position + Vector3(0, 1.5, 0))), "远距观察应允许机体完全离开画面"): return
	if not headless(): await shot("native_aim_offscreen.png")
	m.equip_module_in_raid("arm_l", "arm_sniper")
	r.shake = 0.0
	m.is_aiming = false
	for i in 120: r._process_impl(1.0 / 60.0)
	height = r.camera.global_position.y
	zoom = r._eff_zoom
	basis = r.camera.global_basis
	m.is_aiming = true
	for i in 120: r._process_impl(1.0 / 60.0)
	if not check(absf(r.camera.global_position.y - height) < 0.01 and absf(r._eff_zoom - zoom) < 0.001, "狙击开镜不得抬高镜头"): return
	if not check(r.camera.global_basis.is_equal_approx(basis), "狙击开镜不得改变俯角"): return
	m.is_aiming = false
	for i in 180: r._process_impl(1.0 / 60.0)
	check(r._aim_pan.length() <= 3.01, "松开右键后应回到常规跟随")
	log_line("offscreen aim, fixed height/pitch, half movement speed PASS")
