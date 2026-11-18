extends "res://tests/lib/test_base.gd"
## 验证全部系统消息位于左上对话框与左下 UI 之间、背景半透明且不遮挡/拦截游戏界面：
##   godot --headless --path . -- --hud_msg_layout
##   godot --path . --resolution 1920x1080 -- --hud_msg_layout

const TIMEOUT := 120.0
const START := "hub"


func _assert_msg_region(hud, expect_coop := false) -> void:
	var rr: Rect2 = hud.radio.get_global_rect()
	var ar: Rect2 = hud.ammo_rail.get_global_rect()
	if not check(hud.sys_clip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "sys_clip 必须忽略鼠标输入"):
		return
	if not check(hud.sys_col.mouse_filter == Control.MOUSE_FILTER_IGNORE, "sys_col 必须忽略鼠标输入"):
		return
	if not check(hud.log_box.mouse_filter == Control.MOUSE_FILTER_IGNORE, "log_box 必须忽略鼠标输入"):
		return
	if not check(hud.coop_bar.mouse_filter == Control.MOUSE_FILTER_IGNORE, "coop_bar 必须忽略鼠标输入"):
		return
	var sr: Rect2 = hud.sys_clip.get_global_rect()
	if not check(sr.position.y >= rr.end.y + 4.0, "系统消息区域上边界压住对话框：sys=%s radio=%s" % [sr, rr]):
		return
	if not check(sr.end.y <= ar.position.y - 4.0, "系统消息区域下边界压住左下UI：sys=%s ammo=%s" % [sr, ar]):
		return
	if not check(hud.log_box.get_child_count() >= 2 and hud.log_box.get_child_count() <= 5, "可见系统消息数量异常：%d" % hud.log_box.get_child_count()):
		return
	var coop_end_y := rr.end.y + 4.0
	if expect_coop:
		if not check(hud.coop_bar.visible, "合作小队状态条未显示"):
			return
		var cr: Rect2 = hud.coop_bar.get_global_rect()
		if not check(cr.position.y >= rr.end.y + 4.0 and cr.end.y <= ar.position.y - 4.0, "合作状态条超出对话框与左下UI之间：%s" % [cr]):
			return
		if not check(cr.position.x >= 14.0 and cr.end.x <= rr.end.x + 2.0, "合作状态条水平越界：%s / radio=%s" % [cr, rr]):
			return
		var csb := hud.coop_bar.get_theme_stylebox("panel") as StyleBoxFlat
		if not check(csb != null and csb.bg_color.a >= 0.20 and csb.bg_color.a <= 0.45, "合作状态条背景不是半透明：%s" % [csb.bg_color if csb else Color()]):
			return
		coop_end_y = cr.end.y + 1.0
	for c in hud.log_box.get_children():
		var p := c as Control
		var gr: Rect2 = p.get_global_rect()
		if not check(p.mouse_filter == Control.MOUSE_FILTER_IGNORE, "消息条目必须忽略鼠标：%s" % p):
			return
		if not check(gr.position.y >= rr.end.y + 4.0, "系统消息压住对话框：%s vs radio=%s" % [gr, rr]):
			return
		if expect_coop and not check(gr.position.y >= coop_end_y, "系统消息与合作状态条重叠：%s vs coop_end_y=%.1f" % [gr, coop_end_y]):
			return
		if not check(gr.end.y <= ar.position.y - 4.0, "系统消息压住左下UI：%s vs ammo=%s" % [gr, ar]):
			return
		if not check(gr.position.x >= 14.0 and gr.end.x <= rr.end.x + 2.0, "系统消息水平超出左栏侵入画面：%s vs radio=%s" % [gr, rr]):
			return
		var sb := p.get_theme_stylebox("panel") as StyleBoxFlat
		if not check(sb != null and sb.bg_color.a >= 0.20 and sb.bg_color.a <= 0.45, "系统消息背景不是半透明：alpha=%s" % (str(sb.bg_color.a) if sb else "null")):
			return


func run() -> void:
	GameData.map_id = "ironbelt"
	main.show_hub()
	await frames(4)
	var raid = await deploy()
	if not check(raid != null and raid.hud != null and raid.mech != null, "出击失败"):
		return
	var hud = raid.hud
	raid.mech.shield_time = 999.0
	Story.flow.set_auto(false, true)
	hud.radio.clear()
	Events.extract_cancelled.emit("撤离点 A")
	await wait(0.35)
	if not check(hud.radio.busy() and hud.radio.modulate.a > 0.8, "左上角无线电对话框未激活"):
		return

	hud.msg("脉冲信标升空，「信天翁-2」40 秒后切入降落航线；信标蜂鸣将吸引附近虫群。")
	hud.msg("战地换装：左臂武装 → SG-7 重型霰弹枪")
	hud.msg("◆ 熟练度升级：弹道校准 2级（散射与后坐稳定 +6%）")
	hud.msg("▲ 左臂 损毁！")
	hud.msg("战地抢修完成，修复 35 结构与受损部件")
	await wait(0.35)

	_assert_msg_region(hud, false)
	if _finished:
		return
	await shot("hud_msg_01_raid.png")

	# 检验合作模式小队状态条 + 撤离读条 + 警告/普通消息同框不重叠、不遮挡
	for c in hud.log_box.get_children():
		c.queue_free()
	await frames(2)
	hud.set_coop_status("合作小队 2/4  ·  房主\n奈绪  100%  行动中", false)
	if raid.extracts.size() > 0:
		var ez = raid.extracts[0]
		raid.mech.global_position = Vector3(ez.global_position.x, raid.mech.global_position.y, ez.global_position.z)
		raid.camera.global_position = raid.mech.global_position + raid.CAM_OFFSET * raid.cam_zoom
	hud.radio.clear()
	Events.extract_cancelled.emit("撤离点 A")
	await wait(0.35)
	hud.msg("战地换装完成：[右臂] M99 精确狙击步枪")
	hud.msg("▲ 动力炉断电 · 应急电源维持 15 秒")
	hud.msg("货舱剩余承重或格位不足，无法继续装载")
	await wait(0.35)

	_assert_msg_region(hud, true)
	if _finished:
		return
	var esb := hud.extract_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if not check(esb != null and esb.bg_color.a <= 0.45 and hud.extract_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "撤离面板需半透明且忽略鼠标"):
		return
	await shot("hud_msg_02_coop_extract.png")
	if not raid.lakes.is_empty() and raid.extracts.size() > 0:
		var lk: Vector3 = raid.lakes[0]
		var ang := -PI * 0.15
		var lr: float = preload("res://scripts/world_city.gd").lake_radius(lk, ang)
		var sp := Vector3(lk.x + cos(ang) * (lr + 5.2), 0.0, lk.y + sin(ang) * (lr + 5.2))
		raid.extracts[0].global_position = sp
		raid.mech.global_position = Vector3(sp.x, raid.mech.global_position.y, sp.z)
		raid.mech._shield_surge = 0.55
		raid.camera.global_position = raid.mech.global_position + raid.CAM_OFFSET * raid.cam_zoom
		raid._bug_spire(sp + Vector3(-7.5, 0.0, -5.0), 5.2)
		var tg = preload("res://scripts/enemies/hazards.gd").Telegraph.new()
		raid.fx.add_child(tg)
		tg.setup_lane(null, sp + Vector3(1.8, 0.0, -6.5), Vector3(-0.32, 0.0, 0.95), 2.2, 11.5, 3.0)
		await wait(0.25)
		await shot("hud_msg_03_shore_extract.png")
	hud.set_coop_status("", false)
	log_line("hud_msg_layout ok: radio=%s ammo=%s count=%d" % [hud.radio.get_global_rect(), hud.ammo_rail.get_global_rect(), hud.log_box.get_child_count()])
