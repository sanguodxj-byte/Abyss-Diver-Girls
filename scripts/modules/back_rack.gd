extends RefCounted
## 外挂货架 R-14：管焊框架 + 网格底板，捆着弹药木箱、两只油桶、帆布卷，橙色棘轮绑带
## 接口：插头 HP-B1 → b1_mount → 货架；局部 +Y 远离躯干
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var c: Color = ctx.color
	var root := K.module_root("back", ctx.id, Vector3(0, -1, -0.25))
	var M_A := K.armor(c, 0.60)
	var M_DARK := K.dark()
	var M_GUN := K.gunmetal()
	var top := K.b1_mount(root, M_A, 1.22)
	var M_TUBE := A.metal(Color(0.21, 0.22, 0.23))
	# 镂空加强筋货盘底板 + 焊接圆管防滚架 + 角部三角筋板
	K.bb(top, Vector3(1.22, 0.05, 0.64), K.frame(), Vector3(0, 0.025, 0), Vector3.ZERO, 0.012)
	for ix in [-0.44, -0.22, 0.0, 0.22, 0.44]:
		K.bb(top, Vector3(0.04, 0.02, 0.58), M_GUN, Vector3(ix, 0.052, 0), Vector3.ZERO, 0.005)
	for sx in [-0.58, 0.58]:
		for sz in [-0.28, 0.28]:
			K.cy(top, 0.028, 0.66, M_TUBE, Vector3(sx, 0.36, sz), Vector3.ZERO, -1.0, 10)
			K.plate(top, [Vector2(0, 0), Vector2(0.11, 0), Vector2(0, 0.11)], 0.022, M_GUN, Vector3(sx - signf(sx) * 0.05, 0.08, sz), Vector3(0, 0 if sx < 0 else 180, 0), 0.004)
		K.cy(top, 0.028, 0.58, M_TUBE, Vector3(sx, 0.69, 0), Vector3(90, 0, 0), -1.0, 10)
		K.cy(top, 0.022, 0.58, M_TUBE, Vector3(sx, 0.36, 0), Vector3(90, 0, 0), -1.0, 8)
	for sz in [-0.28, 0.28]:
		K.cy(top, 0.028, 1.18, M_TUBE, Vector3(0, 0.69, sz), Vector3(0, 0, 90), -1.0, 10)
	# 30MM 军规弹药箱：钢包角 + 锁扣 + 提把
	var M_CRATE := A.paint(Color(0.28, 0.31, 0.22), 0.06, 0.78, {"wear": 0.62, "panel_scale": 0.0})
	K.bb(top, Vector3(0.50, 0.36, 0.46), M_CRATE, Vector3(-0.28, 0.23, 0), Vector3.ZERO, 0.02)
	K.bb(top, Vector3(0.52, 0.06, 0.48), M_CRATE, Vector3(-0.28, 0.39, 0), Vector3.ZERO, 0.015)
	for sz in [-0.18, 0.18]:
		K.bb(top, Vector3(0.525, 0.38, 0.032), M_GUN, Vector3(-0.28, 0.23, sz), Vector3.ZERO, 0.005)
	for lx in [-0.42, -0.14]:
		K.bb(top, Vector3(0.036, 0.08, 0.022), A.chrome(), Vector3(lx, 0.34, 0.242), Vector3.ZERO, 0.004)
	K.grab_iron(top, 0.16, 0.035, Vector3(-0.535, 0.25, 0), Vector3(0, 90, 0))
	A.stencil(top, "AMMO 30MM", Vector3(-0.28, 0.24, 0.236), Vector3.ZERO, 0.0026, Color(0.90, 0.86, 0.58, 0.85))
	# 两只北约 20L 冲压钢油桶（橄榄褐与暗锈红混装，消除鲜艳塑料感）
	var can_cols := [Color(0.35, 0.17, 0.12), Color(0.26, 0.29, 0.22)]
	for i in 2:
		var M_CAN := A.paint(can_cols[i], 0.16, 0.58, {"wear": 0.58, "panel_scale": 0.0})
		var p := Vector3(0.14 + i * 0.20, 0.22, 0.10)
		K.bb(top, Vector3(0.165, 0.35, 0.26), M_CAN, p, Vector3.ZERO, 0.022)
		K.bb(top, Vector3(0.175, 0.022, 0.22), M_CAN, p + Vector3(0, 0.02, 0), Vector3(32, 0, 0), 0.004)
		K.bb(top, Vector3(0.175, 0.022, 0.22), M_CAN, p + Vector3(0, 0.02, 0), Vector3(-32, 0, 0), 0.004)
		for hx in [-0.035, 0.0, 0.035]:
			K.cy(top, 0.010, 0.13, M_CAN, p + Vector3(hx, 0.205, 0.03), Vector3(90, 0, 0), -1.0, 6)
		K.cy(top, 0.026, 0.055, K.brass(), p + Vector3(0, 0.195, -0.085), Vector3(22, 0, 0), -1.0, 8)
	# 捆扎伪装帆布卷（带皮带箍）
	var M_CANVAS := A.paint(Color(0.41, 0.39, 0.31), 0.0, 0.94, {"wear": 0.25, "panel_scale": 0.0})
	K.cy(top, 0.125, 0.50, M_CANVAS, Vector3(0.24, 0.51, -0.11), Vector3(0, 0, 90), -1.0, 16)
	for bx in [0.09, 0.39]:
		K.cy(top, 0.132, 0.032, M_DARK, Vector3(bx, 0.51, -0.11), Vector3(0, 0, 90), -1.0, 16)
	# 战地黄褐重型绑带 + 钢制棘轮紧固器 + 后挂拖曳钢缆圈
	var M_STRAP := A.paint(Color(0.58, 0.43, 0.16), 0.0, 0.85, {"wear": 0.35, "panel_scale": 0.0})
	for sx in [-0.40, -0.16, 0.24]:
		K.bb(top, Vector3(0.042, 0.014, 0.61), M_STRAP, Vector3(sx, 0.695, 0), Vector3.ZERO, 0.003)
		for sz in [-0.30, 0.30]:
			K.bb(top, Vector3(0.042, 0.65, 0.014), M_STRAP, Vector3(sx, 0.36, sz), Vector3.ZERO, 0.003)
		K.bb(top, Vector3(0.068, 0.075, 0.038), M_GUN, Vector3(sx, 0.36, 0.31), Vector3.ZERO, 0.006)
	A.add(top, A.torus(0.14, 0.175, 20), M_GUN, Vector3(-0.28, 0.42, 0.32), Vector3.ZERO, Vector3(1, 1, 0.65), false)
	return root
