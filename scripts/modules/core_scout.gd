extends RefCounted
## 侦察躯干 SC-1（B.o.T 式）：楔形机首夹出观察缝、侧挂传感舱、轻薄切角甲
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
	var M_CORE := K.armor(c, 0.44)
	var M_CORE2 := K.armor_sub(c, 0.48)

	# 腰部回转座圈 + 分段护腰齿圈块 + 稳定液压油缸 + 承力底盘托架（消除腰腹黑色空隙断层）
	K.cy(torso, 0.46, 0.24, M_DARK, Vector3(0, 0.06, 0.02), Vector3.ZERO, 0.49, 26)
	A.add(torso, A.torus(0.42, 0.50, 28), M_GUN, Vector3(0, 0.11, 0.02), Vector3.ZERO, Vector3(1, 0.48, 1), false)
	for wi in 6:
		var wa := TAU * float(wi) / 6.0 + PI / 6.0
		K.bb(torso, Vector3(0.18, 0.13, 0.09), M_CORE2 if wi % 2 == 0 else M_GUN, Vector3(cos(wa) * 0.45, 0.04, sin(wa) * 0.45 + 0.02), Vector3(0, -rad_to_deg(wa) + 90.0, 0), 0.014)
	for sx in [-1.0, 1.0]:
		var wx: float = sx * 0.38
		K.piston(torso, Vector3(wx, -0.02, -0.16), Vector3(wx * 1.15, 0.22, -0.26), 0.024)
	K.bb(torso, Vector3(1.04, 0.68, 1.04), M_FRAME, Vector3(0, 0.24, 0.12), Vector3.ZERO, 0.05)
	K.plate(torso, K.crect(1.24, 0.58, [0.16, 0.16, 0.08, 0.08]), 1.08, M_CORE2, Vector3(0, 0.30, 0.18), Vector3.ZERO, 0.045)
	K.plate(torso, K.trap(1.12, 0.82, 0.22, 0.05), 0.92, M_CORE, Vector3(0, 0.63, 0.18), Vector3.ZERO, 0.038)

	# 楔形侦察机首：上下咬合式折角防弹甲 + 外探遮光装甲眉檐 + 深凹镀膜光学观察缝 + 下颚光电转塔
	var nose := K.node(torso, Vector3(0, 0.28, -0.48))
	K.bb(nose, Vector3(0.76, 0.34, 0.36), M_DARK, Vector3(0, 0.0, -0.16), Vector3.ZERO, 0.024)
	# 上下双楔形咬合防弹喙甲（中间留出 y=-0.06..+0.06 的清晰装甲观察槽，绝不吞没观察窗！）
	K.plate(nose, [Vector2(-0.48, -0.04), Vector2(0.48, -0.04), Vector2(0.30, 0.36), Vector2(-0.30, 0.36)], 0.15, M_CORE, Vector3(0, 0.15, -0.04), Vector3(-76, 0, 0), 0.032)
	K.plate(nose, [Vector2(-0.45, -0.04), Vector2(0.45, -0.04), Vector2(0.28, 0.34), Vector2(-0.28, 0.34)], 0.14, M_CORE2, Vector3(0, -0.15, -0.04), Vector3(-104, 0, 0), 0.030)
	for sx in [-1.0, 1.0]:
		var cx: float = sx * 0.36
		K.plate(nose, K.trap(0.24, 0.14, 0.22, 0.03), 0.08, M_CORE2, Vector3(cx, 0.0, -0.22), Vector3(0, sx * 72.0, 0), 0.016)
	# 深凹防弹观察窗框 + 外探遮光眉盾 + 竖向加强隔框 + 暗绿镀膜防弹玻璃
	K.bb(nose, Vector3(0.58, 0.115, 0.09), M_DARK, Vector3(0, 0.0, -0.34), Vector3.ZERO, 0.012)
	K.bb(nose, Vector3(0.62, 0.030, 0.12), M_GUN, Vector3(0, 0.056, -0.375), Vector3(10, 0, 0), 0.006)
	K.bb(nose, Vector3(0.54, 0.020, 0.08), M_GUN, Vector3(0, -0.052, -0.365), Vector3(-6, 0, 0), 0.005)
	K.bb(nose, Vector3(0.50, 0.058, 0.024), K.canopy(K.VISOR, 0.46), Vector3(0, 0.002, -0.382), Vector3.ZERO, 0.004)
	for mx in [-0.14, 0.14]:
		K.bb(nose, Vector3(0.022, 0.070, 0.036), M_DARK, Vector3(mx, 0.002, -0.386), Vector3.ZERO, 0.003)
	# 下颚光电/激光测距球形转塔（EO/IR Gimbal）
	K.cy(nose, 0.11, 0.08, M_GUN, Vector3(0, -0.24, -0.25), Vector3.ZERO, 0.12, 16)
	A.add(nose, A.sphere(0.095, 0.18, 16), M_DARK, Vector3(0, -0.28, -0.27))
	A.lens(nose, Vector3(-0.032, -0.28, -0.355), Vector3(-90, 0, 0), 0.028, Color(0.25, 0.85, 0.65), 1.4)
	A.lens(nose, Vector3(0.036, -0.28, -0.355), Vector3(-90, 0, 0), 0.020, Color(1.0, 0.68, 0.20), 1.2)
	K.plate(nose, K.crect(0.055, 0.26), 0.06, M_ACC, Vector3(-0.22, 0.175, -0.24), Vector3(-76, 0, 0), 0.005)
	A.rivets(nose, Vector3(-0.28, 0.105, -0.34), Vector3(0.28, 0.105, -0.34), 6, 0.012, Vector3(-76, 0, 0))

	# 顶部观察舱盖 + 维修抓手
	K.cy(torso, 0.22, 0.05, M_CORE2, Vector3(-0.14, 0.75, 0.04), Vector3.ZERO, -1.0, 20)
	K.periscope(torso, 0.14, 0.07, Vector3(-0.14, 0.79, -0.12), Vector3.ZERO)
	K.grab_iron(torso, 0.24, 0.045, Vector3(0.24, 0.74, -0.05), Vector3(-90, 0, 0))

	# 两侧复合传感吊舱 + 侧裙板 + 进气百叶 + 烟幕弹筒
	for sx in [-1.0, 1.0]:
		var pod := K.node(torso, Vector3(sx * 0.56, 0.64, -0.18))
		K.bb(pod, Vector3(0.20, 0.18, 0.52), M_CORE2, Vector3.ZERO, Vector3.ZERO, 0.022)
		K.bb(pod, Vector3(0.22, 0.04, 0.20), M_GUN, Vector3(0, 0.09, -0.10), Vector3.ZERO, 0.008)
		A.lens(pod, Vector3(0, 0.0, -0.26), Vector3(-90, 0, 0), 0.042, Color(0.95, 0.72, 0.22), 1.5)
		K.plate(torso, K.trap(0.82, 0.62, 0.46, 0.06), 0.11, M_CORE, Vector3(sx * 0.61, 0.28, 0.20), Vector3(0, sx * 90.0, sx * 4.0), 0.028)
		K.grab_iron(torso, 0.22, 0.04, Vector3(sx * 0.665, 0.44, 0.20), Vector3(0, sx * -90.0, 0))
		A.vent(torso, Vector3(0.32, 0.18, 0.05), Vector3(sx * 0.67, 0.22, 0.36), Vector3(0, sx * 90.0, 0), 4)
		for k in 2:
			K.cy(torso, 0.036, 0.16, M_DARK, Vector3(sx * (0.48 + k * 0.08), 0.68, -0.44), Vector3(66, 0, sx * -16.0), -1.0, 10)
			K.cy(torso, 0.038, 0.02, M_GUN, Vector3(sx * (0.48 + k * 0.08), 0.71, -0.51), Vector3(66, 0, sx * -16.0), -1.0, 10)
		# 带防撞钢护笼的前照灯组 + 锻造牵引环
		var lx: float = sx * 0.32
		K.bb(torso, Vector3(0.15, 0.09, 0.10), M_DARK, Vector3(lx, 0.06, -0.76), Vector3.ZERO, 0.012)
		A.lens(torso, Vector3(lx, 0.06, -0.80), Vector3(-90, 0, 0), 0.028, Color(1.0, 0.94, 0.80), 2.2)
		K.bb(torso, Vector3(0.17, 0.016, 0.05), M_GUN, Vector3(lx, 0.11, -0.80), Vector3.ZERO, 0.004)
		K.bb(torso, Vector3(0.17, 0.016, 0.05), M_GUN, Vector3(lx, 0.01, -0.80), Vector3.ZERO, 0.004)
		A.add(torso, A.torus(0.028, 0.052, 12), M_GUN, Vector3(sx * 0.22, -0.02, -0.78), Vector3(0, 0, 90), Vector3.ONE, false)

	# 顶部散热百叶 + 弹簧底座通信鞭状天线 + 无遮挡编号喷涂
	A.vent(torso, Vector3(0.52, 0.26, 0.05), Vector3(0, 0.74, 0.34), Vector3(-90, 0, 0), 5)
	K.cy(torso, 0.038, 0.09, K.brass(), Vector3(0.36, 0.78, 0.46), Vector3.ZERO, 0.045, 10)
	K.cy(torso, 0.010, 1.05, M_DARK, Vector3(0.36, 1.32, 0.46), Vector3(-6, 0, 0), 0.005, 8)
	K.number(torso, serial, Vector3(-0.672, 0.30, 0.16), Vector3(0, -90, 0), 0.0032)
	A.stencil(torso, "RCN-" + serial, Vector3(0.18, 0.45, -0.785), Vector3(14, 180, 0), 0.0023, Color(0.92, 0.90, 0.82, 0.85))

	if lights:
		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.93, 0.78)
		spot.light_energy = 3.5
		spot.spot_range = 16.0
		spot.spot_angle = 28.0
		spot.spot_attenuation = 0.6
		spot.shadow_enabled = false
		spot.position = Vector3(0, 0.06, -0.84)
		spot.rotation_degrees = Vector3(-20, 0, 0)
		torso.add_child(spot)

	# ---- 标准接口插座 ----
	K.socket(root, "arm_l", Vector3(-0.66, 0.3, 0.0), Vector3.LEFT, -1.0)
	K.socket(root, "arm_r", Vector3(0.66, 0.3, 0.0), Vector3.RIGHT, 1.0)
	K.socket(root, "back", Vector3(0, 0.56, 0.725 - 0.32), Vector3(0, 1, 0.25))
	K.socket(root, "gen", Vector3(0, 0.12, 0.725), Vector3.BACK)
	return root
