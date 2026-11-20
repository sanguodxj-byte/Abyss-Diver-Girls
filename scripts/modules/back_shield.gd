extends RefCounted
## 相位护盾：发生器箱、桅杆、环形发射器
## 接口：插头 HP-B1（朝下，贴躯干顶部后方导轨）；局部 +Y 向上，+Z 向后
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")
const DM = preload("res://scripts/modules/device_models.gd")


static func build(ctx: Dictionary) -> Node3D:
	var id: String = ctx.id
	var c: Color = ctx.color
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var M_GUN := K.gunmetal()
	var root := K.module_root("back", id, Vector3(0, -1, -0.25))
	var M_BACK := K.armor(c, 0.54)
	var M_SUB := K.armor_sub(c, 0.58)
	var ec := Color(0.32, 0.62, 0.78)
	# 脉冲成形电容装甲主机箱（取代原外露霓虹灯管）
	K.bb(root, Vector3(0.82, 0.18, 0.44), M_FRAME, Vector3(0, 0.04, 0.09), Vector3.ZERO, 0.024)
	K.plate(root, K.crect(0.64, 0.52, [0.12, 0.10, 0.04, 0.04]), 0.84, M_BACK, Vector3(0, 0.30, 0.18), Vector3(0, 90, 0), 0.036)
	K.plate(root, K.crect(0.06, 0.32), 0.86, K.accent(), Vector3(0, 0.36, -0.04), Vector3(0, 90, 0), 0.005)
	A.vent(root, Vector3(0.54, 0.28, 0.04), Vector3(0, 0.30, 0.495), Vector3(0, 180, 0), 5)
	# 两侧油冷脉冲变压器模块 + 铜汇流排 + 陶瓷绝缘子
	for sx in [-1.0, 1.0]:
		K.bb(root, Vector3(0.16, 0.36, 0.42), M_SUB, Vector3(sx * 0.49, 0.30, 0.18), Vector3.ZERO, 0.02)
		for fz in [-0.14, -0.05, 0.04, 0.13, 0.22]:
			K.bb(root, Vector3(0.19, 0.28, 0.018), M_GUN, Vector3(sx * 0.50, 0.30, 0.14 + fz), Vector3.ZERO, 0.004)
		# 高压套管绝缘子：棕釉瓷芯 + 6 片大小交替伞裙 + 铸钢法兰（6 颗螺栓）+ 铜接线帽与均压环
		var M_CER := A.paint(Color(0.46, 0.24, 0.13), 0.04, 0.22, {"panel_scale": 0.0})
		var bx: float = sx * 0.49
		K.cy(root, 0.048, 0.026, M_GUN, Vector3(bx, 0.488, 0.14), Vector3.ZERO, 0.052, 28)
		for bi in 6:
			var ba := TAU * float(bi) / 6.0
			K.cy(root, 0.006, 0.012, K.dark(), Vector3(bx + cos(ba) * 0.042, 0.505, 0.14 + sin(ba) * 0.042), Vector3.ZERO, 0.006, 6)
		K.cy(root, 0.022, 0.20, M_CER, Vector3(bx, 0.60, 0.14), Vector3.ZERO, 0.026, 24)
		for si in 6:
			var big := si % 2 == 0
			A.add(root, DM.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.060 if big else 0.044, -0.004), Vector2(0.062 if big else 0.046, 0.0), Vector2(0.026, 0.016), Vector2(0.0, 0.018)]), 28), M_CER, Vector3(bx, 0.515 + si * 0.028, 0.14), Vector3.ZERO, Vector3.ONE, false)
		K.cy(root, 0.026, 0.034, K.copper(), Vector3(bx, 0.715, 0.14), Vector3.ZERO, 0.030, 24)
		A.add(root, A.torus(0.040, 0.054, 32), A.chrome(), Vector3(bx, 0.70, 0.14), Vector3.ZERO, Vector3.ONE, false)
		A.hose(root, Vector3(sx * 0.49, 0.73, 0.14), Vector3(sx * 0.14, 0.96, 0.30), Vector3(sx * 0.06, 0.14, 0.06), 0.022)
	# 顶部脉冲电容组：2×2 圆柱电容罐（卷边顶盖 + 防爆刻痕 + 双接线柱 + 铜汇流排）
	var M_CAP := A.paint(Color(0.16, 0.20, 0.26), 0.55, 0.36, {"panel_scale": 0.0})
	for cx in [-0.31, -0.20]:
		for cz in [-0.08, 0.03]:
			for sgn in [-1.0, 1.0]:
				var px: float = cx * sgn
				K.cy(root, 0.046, 0.15, M_CAP, Vector3(px, 0.635, cz), Vector3.ZERO, 0.046, 28)
				A.add(root, A.torus(0.040, 0.050, 28), A.chrome(), Vector3(px, 0.712, cz), Vector3.ZERO, Vector3.ONE, false)
				K.cy(root, 0.008, 0.03, K.brass(), Vector3(px - 0.018, 0.728, cz), Vector3.ZERO, 0.008, 16)
				K.cy(root, 0.008, 0.03, K.brass(), Vector3(px + 0.018, 0.728, cz), Vector3.ZERO, 0.008, 16)
		for sgn in [-1.0, 1.0]:
			K.bb(root, Vector3(0.016, 0.008, 0.16), K.copper(), Vector3(cx * sgn - 0.018, 0.744, -0.025), Vector3.ZERO, 0.002)
	# 桅杆根部三匝铜质场线圈（环绕桅杆）
	for ci in 3:
		A.add(root, A.torus(0.17, 0.21, 40), K.copper(), Vector3(0, 0.64 + ci * 0.055, 0.30), Vector3.ZERO, Vector3.ONE, false)
	K.cy(root, 0.22, 0.03, M_GUN, Vector3(0, 0.60, 0.30), Vector3.ZERO, 0.22, 36)
	# 折叠桁架支撑桅杆 + 俯仰液压撑杆
	for sx in [-0.13, 0.13]:
		K.bb(root, Vector3(0.065, 0.72, 0.09), M_GUN, Vector3(sx, 0.82, 0.30), Vector3(-8, 0, 0), 0.012)
	K.bb(root, Vector3(0.32, 0.08, 0.10), M_FRAME, Vector3(0, 0.78, 0.29), Vector3.ZERO, 0.012)
	K.piston(root, Vector3(0, 0.48, 0.12), Vector3(0, 0.98, 0.27), 0.030)
	# 军工三联装八角相控阵电磁偏导天线（彻底取代棒棒糖圆盘与悬浮发光球）
	var array_head := K.node(root, Vector3(0, 1.18, 0.28), Vector3(-28, 0, 0))
	K.bb(array_head, Vector3(0.56, 0.28, 0.18), M_GUN, Vector3(0, 0, 0.09), Vector3.ZERO, 0.02)
	for p_idx in [-1, 0, 1]:
		var px := float(p_idx) * 0.40
		var yaw := float(p_idx) * -22.0
		var pz := absf(float(p_idx)) * 0.08
		var pan := K.node(array_head, Vector3(px, 0, pz), Vector3(0, yaw, 0))
		var w := 0.40 if p_idx == 0 else 0.34
		var h := 0.44 if p_idx == 0 else 0.38
		K.plate(pan, K.crect(w, h, [0.08, 0.08, 0.08, 0.08]), 0.09, M_BACK, Vector3.ZERO, Vector3.ZERO, 0.018)
		K.plate(pan, K.crect(w * 0.84, h * 0.84, [0.06, 0.06, 0.06, 0.06]), 0.03, K.bore_mat(), Vector3(0, 0, -0.042), Vector3.ZERO, 0.006)
		# 相控阵铜波导偶极子阵列与深凹低亮度工作指示窄缝
		for ry in [-0.11, 0.0, 0.11]:
			K.bb(pan, Vector3(w * 0.70, 0.018, 0.016), K.copper(), Vector3(0, ry, -0.050), Vector3.ZERO, 0.003)
		K.bb(pan, Vector3(w * 0.56, 0.018, 0.012), K.canopy(ec, 0.55), Vector3(0, 0.055, -0.052), Vector3.ZERO, 0.002)
		# 外围防撞钢护栏
		K.grab_iron(pan, w * 0.88, 0.045, Vector3(0, h * 0.42, -0.03), Vector3.ZERO, 0.011)
		K.grab_iron(pan, w * 0.88, 0.045, Vector3(0, -h * 0.42, -0.03), Vector3.ZERO, 0.011)
	# 顶部避雷与场强探针
	K.cy(array_head, 0.018, 0.12, K.brass(), Vector3(0, 0.27, 0.02), Vector3.ZERO, 0.022, 20)
	A.add(array_head, A.torus(0.016, 0.028, 24), M_GUN, Vector3(0, 0.33, 0.02), Vector3.ZERO, Vector3.ONE, false)
	K.cy(array_head, 0.007, 0.30, M_GUN, Vector3(0, 0.45, 0.02), Vector3.ZERO, 0.004, 16)
	A.add(array_head, A.sphere(0.012, -1, 20), A.chrome(), Vector3(0, 0.605, 0.02), Vector3.ZERO, Vector3.ONE, false)
	A.stencil(root, "EM-BARRIER", Vector3(0, 0.46, 0.49), Vector3(0, 180, 0), 0.0026, Color(0.92, 0.88, 0.78, 0.78))
	return root
