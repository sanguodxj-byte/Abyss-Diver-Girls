extends "res://tests/lib/test_base.gd"
## 验证左下角弹药栏根据左右臂单弹匣子弹数量自适应高度，以及系统消息区同步让位：
##   godot --headless --path . -- --hud_ammo_height
##   godot --path . --resolution 1280x720 -- --hud_ammo_height

const TIMEOUT := 120.0
const START := "hub"


func _swap_arms(m, l_id: String, r_id: String) -> void:
	m.equip_module_in_raid("arm_l", l_id)
	m.equip_module_in_raid("arm_r", r_id)
	await frames(3)


func _check_sys_clear(hud, tag: String) -> bool:
	var ar: Rect2 = hud.ammo_rail.get_global_rect()
	var sr: Rect2 = hud.sys_clip.get_global_rect()
	return check(sr.end.y <= ar.position.y - 4.0, "%s: sys_clip 压住 ammo_rail (sys=%s ammo=%s)" % [tag, sr, ar])


func run() -> void:
	var raid = await deploy({"core": "core_std", "legs": "legs_biped", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_cargo", "gen": "gen_cell"})
	if not check(raid != null and raid.hud != null and raid.mech != null, "出击失败"):
		return
	var hud = raid.hud
	var m = raid.mech
	m.shield_time = 999.0
	Story.flow.set_auto(false, true)
	hud.radio.clear()
	hud.msg("弹药栏自适应高度测试")
	await frames(3)

	# 1. 双机枪 (36 + 36)
	var h_mg: float = hud.ammo_rail.size.y
	var col_mg: float = hud.ammo_cols["arm_l"].size.y
	if not check(hud.ammo_rail.visible and h_mg <= 244.5 and h_mg >= 200.0, "双机枪高度异常：%.1f" % h_mg):
		return
	if not _check_sys_clear(hud, "dual_mg"):
		return
	log_line("dual_mg: rail_h=%.1f col_l=%.1f col_r=%.1f" % [h_mg, col_mg, hud.ammo_cols["arm_r"].size.y])

	# 2. 双狙击 (5 + 5)
	await _swap_arms(m, "arm_sniper", "arm_sniper")
	var h_sniper: float = hud.ammo_rail.size.y
	var col_sniper: float = hud.ammo_cols["arm_l"].size.y
	if not check(hud.ammo_rail.visible and h_sniper < 100.0 and h_sniper >= 48.0, "双狙击高度应明显收短：%.1f" % h_sniper):
		return
	if not _check_sys_clear(hud, "dual_sniper"):
		return
	log_line("dual_sniper: rail_h=%.1f col_l=%.1f col_r=%.1f" % [h_sniper, col_sniper, hud.ammo_cols["arm_r"].size.y])
	await shot("ammo_01_dual_sniper.png")

	# 3. 双霰弹/炮 (6 + 6)
	await _swap_arms(m, "arm_shotgun", "arm_cannon")
	var h_shell: float = hud.ammo_rail.size.y
	if not check(h_shell > h_sniper and h_shell < h_mg, "6发大口径弹匣高度应在5发狙击与36发机枪之间：sniper=%.1f shell=%.1f mg=%.1f" % [h_sniper, h_shell, h_mg]):
		return
	if not _check_sys_clear(hud, "dual_shotgun"):
		return
	log_line("dual_shotgun: rail_h=%.1f col_l=%.1f col_r=%.1f" % [h_shell, hud.ammo_cols["arm_l"].size.y, hud.ammo_cols["arm_r"].size.y])

	# 4. 双发射器 (10 + 10)
	await _swap_arms(m, "arm_cg84", "arm_cg84")
	var h_launcher: float = hud.ammo_rail.size.y
	if not check(h_launcher > h_shell and h_launcher < h_mg, "10发发射器高度应在6发与36发之间：shell=%.1f launcher=%.1f mg=%.1f" % [h_shell, h_launcher, h_mg]):
		return
	if not _check_sys_clear(hud, "dual_launcher"):
		return
	log_line("dual_launcher: rail_h=%.1f col_l=%.1f col_r=%.1f" % [h_launcher, hud.ammo_cols["arm_l"].size.y, hud.ammo_cols["arm_r"].size.y])
	await shot("ammo_02_dual_launcher.png")

	# 5. 非对称：左机枪(36) + 右狙击(5)
	await _swap_arms(m, "arm_mg", "arm_sniper")
	if not check(is_equal_approx(hud.ammo_cols["arm_l"].size.y, col_mg) and is_equal_approx(hud.ammo_cols["arm_r"].size.y, col_sniper), "非对称左右列高度应各自适配：l=%.1f r=%.1f" % [hud.ammo_cols["arm_l"].size.y, hud.ammo_cols["arm_r"].size.y]):
		return
	if not check(is_equal_approx(hud.ammo_rail.size.y, h_mg), "非对称整轨外框应取较高侧高度：%.1f vs %.1f" % [hud.ammo_rail.size.y, h_mg]):
		return
	if not _check_sys_clear(hud, "asym_mg_sniper"):
		return
	await shot("ammo_03_asym_mg_sniper.png")

	# 6. 非对称：左狙击(5) + 右机枪(36)
	await _swap_arms(m, "arm_sniper", "arm_mg")
	if not check(is_equal_approx(hud.ammo_cols["arm_l"].size.y, col_sniper) and is_equal_approx(hud.ammo_cols["arm_r"].size.y, col_mg), "反向非对称左右列高度异常：l=%.1f r=%.1f" % [hud.ammo_cols["arm_l"].size.y, hud.ammo_cols["arm_r"].size.y]):
		return
	if not _check_sys_clear(hud, "asym_sniper_mg"):
		return
	await shot("ammo_04_asym_sniper_mg.png")

	# 7. 单侧实弹：左霰弹(6) + 右激光(0)
	await _swap_arms(m, "arm_shotgun", "arm_laser")
	if not check(hud.ammo_rail.visible and hud.ammo_cols["arm_l"].visible and not hud.ammo_cols["arm_r"].visible and is_equal_approx(hud.ammo_rail.size.y, h_shell), "单左实弹布局异常"):
		return
	await shot("ammo_05_single_left.png")

	# 8. 单侧实弹：左近战(0) + 右狙击(5)
	await _swap_arms(m, "arm_pb09", "arm_sniper")
	if not check(hud.ammo_rail.visible and not hud.ammo_cols["arm_l"].visible and hud.ammo_cols["arm_r"].visible and is_equal_approx(hud.ammo_rail.size.y, h_sniper), "单右实弹布局异常"):
		return
	await shot("ammo_06_single_right.png")

	# 9. 双非实弹：左激光(0) + 右近战(0)
	await _swap_arms(m, "arm_laser", "arm_pb09")
	if not check(not hud.ammo_rail.visible and is_equal_approx(hud.ammo_rail.size.y, 0.0), "无实弹武器时弹药栏应隐藏：vis=%s h=%.1f" % [hud.ammo_rail.visible, hud.ammo_rail.size.y]):
		return
	if not _check_sys_clear(hud, "dual_no_ammo"):
		return
	await shot("ammo_07_no_ammo.png")

	# 10. 喷火器(60) + 机枪(36) 上限压缩验证
	await _swap_arms(m, "arm_flamer", "arm_mg")
	if not check(hud.ammo_rail.visible and hud.ammo_rail.size.y <= 244.5, "60发喷火器不应越过屏幕高度上限：%.1f" % hud.ammo_rail.size.y):
		return
	if not _check_sys_clear(hud, "flamer_mg"):
		return
	await shot("ammo_08_flamer_mg.png")

	# 11. 短弹匣开火 + 换弹 + 臂部损毁显示验证
	await _swap_arms(m, "arm_sniper", "arm_shotgun")
	m.arm_cd["arm_l"] = 0.0
	m.try_fire("arm_l")
	m.try_fire("arm_l")
	m.start_reload("arm_l")
	m.parts["arm_r"] = 0.0
	await wait(0.35)
	await shot("ammo_09_reload_damaged.png")

	log_line("hud_ammo_height ok: sniper=%.1f shell=%.1f launcher=%.1f mg=%.1f" % [h_sniper, h_shell, h_launcher, h_mg])
