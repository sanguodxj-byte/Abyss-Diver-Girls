extends RefCounted
## 指挥躯干 CM-7：高车体、宽幅观察窗、肩部通信箱、前置传感桅杆（相控阵面板 + 鞭状天线）、烟幕弹发射器
## 接口：插头 HP-C1（向下）；插座 HP-A1×2（肩块外侧）、HP-B1（后倾甲板）、HP-G1（尾部动力舱框）
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var c: Color = ctx.color
	var lights: bool = ctx.get("lights", true)
	var root := K.module_root("core", ctx.id, Vector3.DOWN)
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var M_ACC := K.accent()
	var M_A := K.armor(c, 0.45)
	var M_A2 := K.armor(c.darkened(0.22), 0.45)
	K.cy(root, 0.46, 0.30, M_DARK, Vector3(0, 0.12, 0), Vector3.ZERO, 0.48, 28)
	A.add(root, A.torus(0.42, 0.49, 36), A.metal(Color(0.3, 0.3, 0.32)), Vector3(0, 0.18, 0), Vector3.ZERO, Vector3(1, 0.5, 1), false)
	K.bb(root, Vector3(1.06, 0.24, 0.96), M_FRAME, Vector3(0, 0.18, 0.04), Vector3.ZERO, 0.04)
	K.bb(root, Vector3(1.2, 1.0, 1.1), M_FRAME, Vector3(0, 0.74, 0.05), Vector3.ZERO, 0.05)
	# 正面战术舰桥舱：多面装甲 + 防弹眉檐 + 三分格镀膜观察窗 + 下颔数据链天线盒
	K.plate(root, K.crect(1.16, 0.84, [0.22, 0.22, 0.1, 0.1]), 0.14, M_A, Vector3(0, 0.76, -0.55), Vector3(12, 0, 0), 0.04)
	K.plate(root, K.crect(0.88, 0.16, [0.04, 0.04, 0.04, 0.04]), 0.05, M_DARK, Vector3(0, 0.96, -0.64), Vector3(12, 0, 0), 0.01)
	K.bb(root, Vector3(0.92, 0.03, 0.11), K.gunmetal(), Vector3(0, 1.03, -0.66), Vector3(18, 0, 0), 0.005)
	K.bb(root, Vector3(0.78, 0.075, 0.022), K.canopy(K.VISOR, 0.38), Vector3(0, 0.96, -0.668), Vector3(12, 0, 0), 0.005)
	for mx in [-0.22, 0.22]:
		K.bb(root, Vector3(0.022, 0.085, 0.035), M_DARK, Vector3(mx, 0.96, -0.672), Vector3(12, 0, 0), 0.003)
	K.plate(root, K.crect(1.0, 0.05), 0.145, M_ACC, Vector3(0, 0.52, -0.6), Vector3(12, 0, 0), 0.004)
	K.number(root, ctx.get("serial", "00"), Vector3(-0.30, 0.68, -0.645), Vector3(-12, 180, 0), 0.0034)
	K.holes(root, Vector3(0.3, 0.68, -0.645), Vector3(-12, 0, 0), 3, 2, 0.06, 0.016)
	for sx in [-0.38, 0.38]:
		K.bb(root, Vector3(0.14, 0.08, 0.08), M_DARK, Vector3(sx, 0.40, -0.59), Vector3.ZERO, 0.010)
		A.lens(root, Vector3(sx, 0.40, -0.635), Vector3(-90, 0, 0), 0.024, Color(1.0, 0.94, 0.80), 2.0)
	# 肩块（HP-A1 母座在外侧）+ 军规加密通信机箱 + 线缆导管
	for sx in [-1.0, 1.0]:
		K.bb(root, Vector3(0.22, 0.52, 0.64), M_A2, Vector3(sx * 0.66, 0.42, 0.0), Vector3.ZERO, 0.03)
		K.bb(root, Vector3(0.36, 0.26, 0.48), M_A, Vector3(sx * 0.60, 1.36, 0.0), Vector3.ZERO, 0.03)
		A.vent(root, Vector3(0.30, 0.13, 0.03), Vector3(sx * 0.60, 1.36, -0.25), Vector3.ZERO, 4)
		K.bb(root, Vector3(0.04, 0.05, 0.24), M_ACC, Vector3(sx * 0.785, 1.36, 0.0), Vector3.ZERO, 0.004)
		K.grab_iron(root, 0.20, 0.04, Vector3(sx * 0.60, 1.50, 0.0), Vector3(-90, 90, 0))
		# 烟幕弹发射器 3 联（带密封盖）
		for i in 3:
			K.cy(root, 0.044, 0.20, M_DARK, Vector3(sx * (0.52 + i * 0.09), 1.12, -0.42), Vector3(70, 0, sx * -20.0), -1.0, 10)
			K.cy(root, 0.047, 0.02, K.gunmetal(), Vector3(sx * (0.52 + i * 0.09), 1.155, -0.51), Vector3(70, 0, sx * -20.0), -1.0, 10)
	# 复合侦搜桅杆（左前）：桁架支柱 + 相控阵雷达阵列 + 顶置光电观瞄球；右侧卫通圆盘 + 双鞭天线
	K.cy(root, 0.055, 0.58, M_DARK, Vector3(-0.42, 1.53, -0.30), Vector3.ZERO, -1.0, 12)
	K.cy(root, 0.095, 0.08, K.gunmetal(), Vector3(-0.42, 1.28, -0.30), Vector3.ZERO, -1.0, 14)
	var mast := K.node(root, Vector3(-0.42, 1.88, -0.30), Vector3(0, -22, 0))
	K.bb(mast, Vector3(0.54, 0.30, 0.08), M_A2, Vector3(0, 0, 0), Vector3(-10, 0, 0), 0.018)
	K.bb(mast, Vector3(0.46, 0.22, 0.02), A.paint(Color(0.15, 0.17, 0.18), 0.45, 0.38, {"panel_scale": 2.4}), Vector3(0, 0, -0.045), Vector3(-10, 0, 0), 0.004)
	for rx in [-0.24, 0.24]:
		K.grab_iron(mast, 0.14, 0.035, Vector3(rx, 0, -0.02), Vector3(0, 0, 90))
	A.add(mast, A.sphere(0.085, 0.16, 14), M_DARK, Vector3(0, 0.22, 0.0))
	A.lens(mast, Vector3(0, 0.22, -0.08), Vector3(-90, 0, 0), 0.028, Color(0.28, 0.85, 0.65), 1.4)
	# 右顶低剖面卫通天线罩 + 弹簧底座双鞭天线
	K.cy(root, 0.18, 0.07, M_A, Vector3(0.22, 1.28, -0.18), Vector3.ZERO, 0.21, 18)
	K.cy(root, 0.14, 0.03, M_A2, Vector3(0.22, 1.325, -0.18), Vector3.ZERO, -1.0, 16)
	for sx in [0.55, 0.72]:
		K.cy(root, 0.032, 0.08, K.brass(), Vector3(sx, 1.50, 0.10), Vector3.ZERO, 0.038, 10)
		K.cy(root, 0.009, 1.08, M_DARK, Vector3(sx, 2.04, 0.10), Vector3(-4, 0, 0), 0.004, 8)
	# 后倾甲板（HP-B1 母座在其上）
	K.plate(root, K.crect(1.06, 0.56, [0.08, 0.08, 0.08, 0.08]), 0.08, M_A2, Vector3(0, 1.24, 0.32), Vector3(104, 0, 0), 0.02)
	# 尾部动力舱框
	for sy in [-1.0, 1.0]:
		K.bb(root, Vector3(0.96, 0.06, 0.08), M_DARK, Vector3(0, 0.6 + sy * 0.39, 0.58), Vector3.ZERO, 0.01)
	for sx in [-1.0, 1.0]:
		K.bb(root, Vector3(0.06, 0.72, 0.08), M_DARK, Vector3(sx * 0.46, 0.6, 0.58), Vector3.ZERO, 0.01)
	if lights:
		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.93, 0.78)
		spot.light_energy = 3.5
		spot.spot_range = 18.0
		spot.spot_angle = 30.0
		spot.shadow_enabled = false
		spot.position = Vector3(0, 0.5, -0.7)
		spot.rotation_degrees = Vector3(-22, 0, 0)
		root.add_child(spot)
	K.socket(root, "arm_l", Vector3(-0.75, 0.42, 0.0), Vector3.LEFT, -1.0)
	K.socket(root, "arm_r", Vector3(0.75, 0.42, 0.0), Vector3.RIGHT, 1.0)
	K.socket(root, "back", Vector3(0, 1.22, 0.30), Vector3(0, 1, 0.25))
	K.socket(root, "gen", Vector3(0, 0.6, 0.60), Vector3.BACK)
	return root
