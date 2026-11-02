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
	K.cy(root, 0.44, 0.12, M_DARK, Vector3(0, 0.18, 0), Vector3.ZERO, -1.0, 28)
	A.add(root, A.torus(0.4, 0.47, 36), A.metal(Color(0.3, 0.3, 0.32)), Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1, 0.5, 1), false)
	K.bb(root, Vector3(1.2, 1.0, 1.1), M_FRAME, Vector3(0, 0.74, 0.05), Vector3.ZERO, 0.05)
	# 正面驾驶舱：多面装甲 + 宽幅观察窗
	K.plate(root, K.crect(1.16, 0.84, [0.22, 0.22, 0.1, 0.1]), 0.14, M_A, Vector3(0, 0.76, -0.55), Vector3(12, 0, 0), 0.04)
	K.plate(root, K.crect(0.86, 0.14, [0.04, 0.04, 0.04, 0.04]), 0.04, M_DARK, Vector3(0, 0.96, -0.64), Vector3(12, 0, 0), 0.01)
	K.bb(root, Vector3(0.78, 0.07, 0.02), K.canopy(), Vector3(0, 0.96, -0.665), Vector3(12, 0, 0), 0.006)
	K.plate(root, K.crect(1.0, 0.05), 0.145, M_ACC, Vector3(0, 0.52, -0.6), Vector3(12, 0, 0), 0.004)
	K.number(root, ctx.get("serial", "00"), Vector3(-0.3, 0.68, -0.64), Vector3(-12, 180, 0), 0.0034)
	K.holes(root, Vector3(0.3, 0.68, -0.645), Vector3(-12, 0, 0), 3, 2, 0.06, 0.016)
	# 肩块（HP-A1 母座在外侧）+ 通信箱
	for sx in [-1.0, 1.0]:
		K.bb(root, Vector3(0.22, 0.52, 0.64), M_A2, Vector3(sx * 0.66, 0.42, 0.0), Vector3.ZERO, 0.03)
		K.bb(root, Vector3(0.34, 0.24, 0.46), M_A, Vector3(sx * 0.6, 1.36, 0.0), Vector3.ZERO, 0.03)
		A.vent(root, Vector3(0.3, 0.12, 0.03), Vector3(sx * 0.6, 1.36, -0.245), Vector3.ZERO, 3)
		K.bb(root, Vector3(0.04, 0.05, 0.24), M_ACC, Vector3(sx * 0.775, 1.36, 0.0), Vector3.ZERO, 0.004)
		# 烟幕弹发射器 3 联
		for i in 3:
			K.cy(root, 0.045, 0.2, M_DARK, Vector3(sx * (0.52 + i * 0.09), 1.12, -0.42), Vector3(70, 0, sx * -20.0), -1.0, 10)
	# 传感桅杆（前左）：立杆 + 相控阵面板 + 鞭状天线
	K.cy(root, 0.05, 0.6, M_DARK, Vector3(-0.42, 1.54, -0.3), Vector3.ZERO, -1.0, 12)
	K.cy(root, 0.08, 0.06, M_A2, Vector3(-0.42, 1.27, -0.3), Vector3.ZERO, -1.0, 12)
	var mast := K.node(root, Vector3(-0.42, 1.88, -0.3), Vector3(0, -25, 0))
	K.bb(mast, Vector3(0.5, 0.28, 0.06), M_A, Vector3(0, 0, 0), Vector3(-10, 0, 0), 0.015)
	K.bb(mast, Vector3(0.44, 0.22, 0.01), A.paint(Color(0.12, 0.13, 0.14), 0.4, 0.4, {"panel_scale": 0.0}), Vector3(0, 0, -0.035), Vector3(-10, 0, 0), 0.003)
	for sx in [0.55, 0.72]:
		K.cy(root, 0.008, 1.1, M_DARK, Vector3(sx, 2.0, 0.1))
		K.cy(root, 0.025, 0.06, M_DARK, Vector3(sx, 1.48, 0.1))
	# 后倾甲板（HP-B1 母座在其上）
	K.plate(root, K.crect(1.06, 0.56, [0.08, 0.08, 0.08, 0.08]), 0.08, M_A2, Vector3(0, 1.24, 0.32), Vector3(104, 0, 0), 0.02)
	# 尾部动力舱框
	for sy in [-1.0, 1.0]:
		K.bb(root, Vector3(0.96, 0.06, 0.08), M_DARK, Vector3(0, 0.6 + sy * 0.39, 0.58), Vector3.ZERO, 0.01)
	for sx in [-1.0, 1.0]:
		K.bb(root, Vector3(0.06, 0.84, 0.08), M_DARK, Vector3(sx * 0.46, 0.6, 0.58), Vector3.ZERO, 0.01)
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
	K.socket(root, "arm_l", Vector3(-0.77, 0.42, 0.0), Vector3.LEFT, -1.0)
	K.socket(root, "arm_r", Vector3(0.77, 0.42, 0.0), Vector3.RIGHT, 1.0)
	K.socket(root, "back", Vector3(0, 1.29, 0.32), Vector3(0, 1, 0.25))
	K.socket(root, "gen", Vector3(0, 0.6, 0.625), Vector3.BACK)
	return root
