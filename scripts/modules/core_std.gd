extends RefCounted
## 标准躯干 MK-II（B.o.T 式）：多面切角胸甲、偏置三目传感头、肩部护甲
## 接口：插头 HP-C1（向下）；插座 HP-A1×2、HP-B1、HP-G1
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var id: String = ctx.id
	var c: Color = ctx.color
	var lights: bool = ctx.get("lights", true)
	var serial: String = ctx.get("serial", "00")
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var M_GUN := K.gunmetal()
	var M_ACC := K.accent()
	var root := K.module_root("core", id, Vector3.DOWN)
	var torso := root
	var M_CORE := K.armor(c, 0.45)
	var M_CORE2 := K.armor_sub(c, 0.48)

	# 腰部回转座圈 + 机械承力骨架 + 主胸舱
	K.cy(torso, 0.46, 0.22, M_DARK, Vector3(0, 0.06, 0.0), Vector3.ZERO, 0.48, 28)
	A.add(torso, A.torus(0.42, 0.49, 30), M_GUN, Vector3(0, 0.12, 0.0), Vector3.ZERO, Vector3(1, 0.45, 1), false)
	K.bb(torso, Vector3(1.32, 0.88, 1.12), M_FRAME, Vector3(0, 0.26, 0.06), Vector3.ZERO, 0.055)
	K.plate(torso, K.crect(1.52, 0.68, [0.18, 0.18, 0.10, 0.10]), 1.14, M_CORE2, Vector3(0, 0.38, 0.10), Vector3.ZERO, 0.048)

	# 胸甲：中央多面复合主甲 + 下部螺栓副甲 + 两翼外倾反应装甲
	K.plate(torso, K.crect(0.76, 0.64, [0.14, 0.14, 0.20, 0.20]), 0.15, M_CORE, Vector3(0, 0.34, -0.56), Vector3(-10, 0, 0), 0.038)
	K.plate(torso, K.crect(0.46, 0.26, [0.06, 0.06, 0.10, 0.10]), 0.06, M_CORE2, Vector3(0, 0.22, -0.64), Vector3(-10, 0, 0), 0.018)
	K.holes(torso, Vector3(0, 0.19, -0.68), Vector3(-10, 0, 0), 4, 2, 0.07, 0.018)
	# 编号置于胸甲上半部平整区（Ry(180)*Rx(+10) 严格平行于 Rx(-10) 主胸甲，零裁切！）
	K.number(torso, serial, Vector3(-0.16, 0.44, -0.662), Vector3(10, 180, 0), 0.0031)
	A.rivets(torso, Vector3(-0.28, 0.57, -0.678), Vector3(0.28, 0.57, -0.678), 5, 0.013, Vector3(80, 0, 0))

	for sx in [-1.0, 1.0]:
		K.plate(torso, K.trap(0.52, 0.44, 0.62, 0.06), 0.12, M_CORE, Vector3(sx * 0.53, 0.34, -0.46), Vector3(-8, sx * 28.0, 0), 0.032)
		K.era_block(torso, Vector3(0.22, 0.16, 0.055), M_CORE2, Vector3(sx * 0.50, 0.42, -0.53), Vector3(-8, sx * 28.0, 0))
		K.era_block(torso, Vector3(0.22, 0.16, 0.055), M_CORE2, Vector3(sx * 0.50, 0.22, -0.51), Vector3(-8, sx * 28.0, 0))
		K.plate(torso, K.crect(0.055, 0.40), 0.13, M_ACC, Vector3(sx * 0.67, 0.35, -0.39), Vector3(-8, sx * 28.0, 0), 0.006)
		# 肩部承力护甲（带加强筋与维修抓手）
		var sp := K.node(torso, Vector3(sx * 0.72, 0.78, 0.02), Vector3(0, 0, -sx * 14.0))
		K.plate(sp, K.trap(0.64, 0.44, 0.22, 0.05), 0.92, M_CORE, Vector3.ZERO, Vector3(0, 90, 0), 0.038)
		K.plate(sp, K.crect(0.055, 0.24), 0.94, M_ACC, Vector3(0, 0.0, 0.0), Vector3(0, 90, 0), 0.005)
		K.grab_iron(sp, 0.22, 0.04, Vector3(0, 0.12, -0.22), Vector3(-90, 0, 0))
		A.vent(torso, Vector3(0.38, 0.24, 0.05), Vector3(sx * 0.77, 0.28, 0.30), Vector3(0, sx * 90.0, 0), 5)
		# 胸下防撞护笼探照灯 + 牵引耳环
		K.bb(torso, Vector3(0.15, 0.09, 0.09), M_DARK, Vector3(sx * 0.26, 0.01, -0.62), Vector3.ZERO, 0.012)
		A.lens(torso, Vector3(sx * 0.26, 0.01, -0.66), Vector3(-90, 0, 0), 0.026, Color(1.0, 0.95, 0.82), 2.2)
		K.bb(torso, Vector3(0.17, 0.016, 0.05), M_GUN, Vector3(sx * 0.26, 0.058, -0.66), Vector3.ZERO, 0.004)
		A.add(torso, A.torus(0.03, 0.055, 12), M_GUN, Vector3(sx * 0.42, -0.02, -0.58), Vector3(0, 0, 90), Vector3.ONE, false)

	K.plate(torso, K.trap(0.68, 1.04, 0.30, 0.06), 0.14, M_CORE2, Vector3(0, -0.06, -0.50), Vector3(24, 0, 0), 0.032)

	# 顶部左舱盖 + 背部散热格栅 + 弹簧通信鞭状天线 + 动力舱护框
	K.cy(torso, 0.22, 0.05, M_CORE2, Vector3(-0.24, 0.74, -0.10), Vector3.ZERO, -1.0, 20)
	K.periscope(torso, 0.14, 0.07, Vector3(-0.24, 0.78, -0.26), Vector3.ZERO)
	A.vent(torso, Vector3(0.70, 0.30, 0.05), Vector3(0, 0.73, 0.34), Vector3(-90, 0, 0), 6)
	K.cy(torso, 0.038, 0.08, K.brass(), Vector3(-0.52, 0.76, 0.46), Vector3.ZERO, 0.045, 10)
	K.cy(torso, 0.011, 1.02, M_DARK, Vector3(-0.52, 1.28, 0.46), Vector3(-5, 0, 0), 0.005, 8)
	A.stencil(torso, "NO STEP", Vector3(0.35, 0.735, 0.32), Vector3(-90, 0, 0), 0.0028, Color(0.95, 0.92, 0.85, 0.78))

	# 偏置复合传感头：装甲护罩 + 防弹遮光眉檐 + 镀膜观察窗 + 三联光学测距镜组 + 侧面耳轴
	var hd := K.node(torso, Vector3(0.22, 0.86, -0.26))
	K.cy(hd, 0.16, 0.12, M_DARK, Vector3(0, -0.14, 0.04), Vector3.ZERO, 0.18, 18)
	K.plate(hd, K.crect(0.46, 0.31, [0.10, 0.04, 0.02, 0.08]), 0.52, M_CORE, Vector3.ZERO, Vector3.ZERO, 0.038)
	K.bb(hd, Vector3(0.48, 0.032, 0.14), M_GUN, Vector3(0, 0.12, -0.23), Vector3(8, 0, 0), 0.006)
	K.plate(hd, K.trap(0.42, 0.32, 0.12, 0.02), 0.10, M_CORE2, Vector3(0, -0.02, -0.27), Vector3(-28, 0, 0), 0.018)
	K.bb(hd, Vector3(0.34, 0.048, 0.024), K.canopy(K.VISOR, 0.42), Vector3(0, 0.072, -0.262), Vector3.ZERO, 0.004)
	K.cy(hd, 0.065, 0.52, M_GUN, Vector3(0, 0.0, 0.04), Vector3(0, 0, 90), -1.0, 14)
	for i in 3:
		A.lens(hd, Vector3(-0.11 + i * 0.11, -0.065, -0.265), Vector3(-90, 0, 0), 0.026 if i != 1 else 0.038, Color(0.95, 0.76, 0.22), 1.6)

	if lights:
		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.93, 0.78)
		spot.light_energy = 3.5
		spot.spot_range = 16.0
		spot.spot_angle = 28.0
		spot.spot_attenuation = 0.6
		spot.shadow_enabled = false
		spot.position = Vector3(0, 0.02, -0.70)
		spot.rotation_degrees = Vector3(-24, 0, 0)
		torso.add_child(spot)

	# ---- 标准接口插座 ----
	K.socket(root, "arm_l", Vector3(-0.78, 0.3, 0.0), Vector3.LEFT, -1.0)
	K.socket(root, "arm_r", Vector3(0.78, 0.3, 0.0), Vector3.RIGHT, 1.0)
	K.socket(root, "back", Vector3(0, 0.68, 0.68 - 0.32), Vector3(0, 1, 0.25))
	K.socket(root, "gen", Vector3(0, 0.12, 0.66), Vector3.BACK)
	return root
