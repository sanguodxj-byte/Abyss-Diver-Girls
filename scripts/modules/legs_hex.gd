extends RefCounted
## 中重巡航六足底盘 HX-6：流线折面装甲巡航车体、八肋炮塔领座、六条军规双箱梁液压步行肢与三爪驻锄足垫
## 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var id: String = ctx.id
	var c: Color = ctx.color
	var serial: String = ctx.get("serial", "06")
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var M_GUN := K.gunmetal()
	var M_ACC := K.accent()
	var root := K.module_root("legs", id, Vector3.ZERO)
	var legs := root
	var M_LEG := K.armor(c, 0.46)
	var M_LEG2 := K.armor_sub(c, 0.50)
	var leg_parts: Array = []
	var hip := 1.28

	# ---- 军用多面折角装甲长船体 + 腹下液压分配总成 + 锥台回转座圈（顶接 hip+0.56 = 1.84） ----
	K.bb(legs, Vector3(1.08, 0.44, 2.18), M_FRAME, Vector3(0, hip, 0.0), Vector3.ZERO, 0.055)
	K.plate(legs, K.crect(1.26, 2.28, [0.30, 0.30, 0.28, 0.28]), 0.24, M_LEG, Vector3(0, hip + 0.16, 0.0), Vector3(90, 0, 0), 0.042)
	K.plate(legs, K.crect(0.98, 1.96, [0.24, 0.24, 0.24, 0.24]), 0.20, M_LEG2, Vector3(0, hip - 0.15, 0.0), Vector3(90, 0, 0), 0.035)
	K.cy(legs, 0.54, 0.30, M_LEG2, Vector3(0, hip + 0.36, 0.0), Vector3.ZERO, 0.68, 26)
	K.cy(legs, 0.52, 0.10, M_DARK, Vector3(0, hip + 0.50, 0.0), Vector3.ZERO, 0.55, 26)
	for i in 8:
		var ga := TAU * i / 8.0
		K.bb(legs, Vector3(0.05, 0.20, 0.16), M_GUN, Vector3(cos(ga) * 0.58, hip + 0.34, sin(ga) * 0.58), Vector3(0, -rad_to_deg(ga), 0), 0.008)

	# 车首楔形装甲防弹板（+36° 斜坡）+ 潜望窗 + 双内嵌战术车灯 + 车尾双散热百叶窗
	var prow := K.node(legs, Vector3(0, hip + 0.06, -1.14), Vector3(36, 0, 0))
	K.plate(prow, K.trap(1.14, 0.96, 0.42, 0.06), 0.14, M_LEG, Vector3.ZERO, Vector3.ZERO, 0.032)
	A.stencil(prow, "HX-" + serial, Vector3(0, 0.0, -0.078), Vector3(0, 180, 0), 0.0026, Color(0.95, 0.93, 0.86, 0.88))
	K.periscope(legs, 0.24, 0.08, Vector3(0, hip + 0.24, -0.96), Vector3.ZERO)
	for sx in [-0.36, 0.36]:
		K.bb(legs, Vector3(0.17, 0.10, 0.10), M_DARK, Vector3(sx, hip + 0.10, -1.16), Vector3.ZERO, 0.012)
		A.lens(legs, Vector3(sx, hip + 0.10, -1.21), Vector3(-90, 0, 0), 0.028, Color(1.0, 0.93, 0.78), 2.2)
	A.add(legs, A.torus(0.032, 0.060, 12), M_GUN, Vector3(0, hip - 0.08, -1.24), Vector3(0, 0, 90), Vector3.ONE, false)
	for sx in [-0.28, 0.28]:
		A.vent(legs, Vector3(0.38, 0.22, 0.05), Vector3(sx, hip + 0.04, 1.16), Vector3(0, 180, 0), 5)

	# ---- 六条军规双梁液压巡航步行肢（FL, FR, ML, MR, RL, RR） ----
	var mounts := [
		Vector3(-0.56, -0.76, -0.44), Vector3(0.56, -0.76, -0.44),
		Vector3(-0.60, 0.0, 0.0),     Vector3(0.60, 0.0, 0.0),
		Vector3(-0.56, 0.76, 0.44),   Vector3(0.56, 0.76, 0.44),
	]
	for m in mounts:
		var sx: float = m.x
		var sz: float = m.y
		var z_aim: float = m.z
		var leg := Node3D.new()
		leg.position = Vector3(sx, hip, sz)
		leg.rotation.y = atan2(sign(sx), z_aim)
		legs.add_child(leg)
		var H := Vector3.ZERO
		var KN := Vector3(0, 0.34, 0.78)
		var FT := Vector3(0, -hip + 0.05, 1.16)

		# 基节回转鼓 + 螺栓法兰圈
		K.cy(leg, 0.19, 0.28, M_DARK, Vector3(0, 0.0, 0.04), Vector3.ZERO, 0.21, 16)
		K.bolt_ring(leg, 0.15, 6, 0.013, Vector3(0, 0.145, 0.04), Vector3.ZERO)
		K.actuator(leg, Vector3(0, 0.02, 0.14), 0.13, 0.28)

		# 股节（双侧承重箱梁 + 切角背甲 + 警示涂装 + 液压缸）
		var up := K.bone(leg, H, KN)
		var l1 := H.distance_to(KN)
		for bx in [-0.085, 0.085]:
			K.bb(up, Vector3(0.065, l1 * 0.92, 0.15), M_FRAME, Vector3(bx, -l1 * 0.5, 0.0), Vector3.ZERO, 0.015)
		K.plate(up, K.trap(0.22, 0.30, l1 * 0.86, 0.04), 0.22, M_LEG, Vector3(0, -l1 * 0.48, 0.07), Vector3.ZERO, 0.026)
		K.plate(up, K.crect(0.26, 0.045), 0.10, M_ACC, Vector3(0, -l1 * 0.34, 0.15), Vector3.ZERO, 0.005)
		K.piston(leg, Vector3(0, -0.12, 0.12), Vector3(0, 0.18, 0.68), 0.028)

		# 膝关节作动器 + 立体护膝盖
		K.actuator(leg, KN, 0.14, 0.30)
		var kp := K.node(leg, KN + Vector3(0, 0.08, 0.10), Vector3(-26, 0, 0))
		K.plate(kp, K.trap(0.26, 0.18, 0.26, 0.04), 0.12, M_LEG, Vector3.ZERO, Vector3.ZERO, 0.022)

		# 胫节（双箱梁 + 斜切外护甲 + 内侧液压推杆 + 高压油管）
		var lo := K.bone(leg, KN, FT)
		var l2 := KN.distance_to(FT)
		for bx in [-0.08, 0.08]:
			K.bb(lo, Vector3(0.07, l2 * 0.90, 0.16), M_FRAME, Vector3(bx, -l2 * 0.46, -0.02), Vector3.ZERO, 0.015)
		K.plate(lo, K.trap(0.18, 0.30, l2 * 0.84, 0.05), 0.13, M_LEG, Vector3(0, -l2 * 0.44, 0.09), Vector3(3, 0, 0), 0.026)
		K.plate(lo, K.trap(0.12, 0.20, l2 * 0.48, 0.03), 0.08, M_LEG2, Vector3(0, -l2 * 0.30, 0.14), Vector3(3, 0, 0), 0.018)
		K.piston(leg, KN + Vector3(0, -0.10, -0.09), KN + (FT - KN) * 0.60 + Vector3(0, 0, -0.07), 0.030)
		A.hose(leg, Vector3(0.10, 0.24, 0.52), KN + Vector3(0.10, -0.36, 0.06), Vector3(0.06, 0.03, 0.10), 0.020)

		# 三趾橡胶缓冲工程足垫
		var pad := K.node(leg, FT + Vector3(0, 0.03, 0))
		K.cy(pad, 0.11, 0.09, M_GUN, Vector3(0, 0.05, 0), Vector3.ZERO, 0.14, 12)
		K.cy(pad, 0.17, 0.045, A.rubber(), Vector3(0, -0.012, 0), Vector3.ZERO, 0.19, 14)
		for ca in [-38.0, 38.0, 180.0]:
			var cl := K.node(pad, Vector3.ZERO, Vector3(0, ca, 0))
			K.bb(cl, Vector3(0.065, 0.05, 0.13), M_LEG2, Vector3(0, 0.008, 0.15), Vector3(14, 0, 0), 0.01)
			K.bb(cl, Vector3(0.07, 0.026, 0.12), A.rubber(), Vector3(0, -0.025, 0.15), Vector3.ZERO, 0.006)
		leg_parts.append(leg)

	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		A.hose(legs, Vector3(cos(a) * 0.48, hip + 0.24, sin(a) * 0.48), Vector3(cos(a) * 0.42, hip + 0.48, sin(a) * 0.42), Vector3(cos(a) * 0.07, 0, sin(a) * 0.07), 0.020)
	K.socket(root, "core", Vector3(0, hip + 0.56, 0), Vector3.UP)
	root.set_meta("leg_parts", leg_parts)
	root.set_meta("leg_type", "hex")
	return root
