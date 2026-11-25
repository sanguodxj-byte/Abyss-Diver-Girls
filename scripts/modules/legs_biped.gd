extends RefCounted
## 双足底盘 Stride（B.o.T 式泰坦腿）：反关节（鸟足式）结构，
## 多面切角大腿甲 / 尖形护膝 / 长胫甲、外露液压骨架、三趾爪足 + 后跟距
## 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var id: String = ctx.id
	var c: Color = ctx.color
	var serial: String = ctx.get("serial", "00")
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var M_ACC := K.accent()
	var root := K.module_root("legs", id, Vector3.ZERO)
	var M_LEG := K.armor(c)
	var M_LEG2 := K.armor(c.darkened(0.25))
	var M_BARE := A.metal(Color(0.27, 0.28, 0.3))
	var leg_parts: Array = []
	var hip := 1.62

	# ---- 骨盆：重工承力胯架 + 前后楔形裙甲 + 外露液压护腰 ----
	K.bb(root, Vector3(1.06, 0.36, 0.68), M_FRAME, Vector3(0, hip + 0.04, 0.02), Vector3.ZERO, 0.05)
	K.bb(root, Vector3(0.86, 0.18, 0.58), M_LEG2, Vector3(0, hip + 0.23, 0.02), Vector3.ZERO, 0.04)
	K.plate(root, K.trap(0.64, 0.90, 0.46, 0.07), 0.12, M_LEG, Vector3(0, hip + 0.02, -0.38), Vector3(16, 0, 0), 0.032)
	K.plate(root, K.crect(0.38, 0.06), 0.13, M_ACC, Vector3(0, hip + 0.18, -0.42), Vector3(16, 0, 0), 0.008)
	K.plate(root, K.trap(0.74, 0.94, 0.42, 0.06), 0.12, M_LEG2, Vector3(0, hip + 0.02, 0.38), Vector3(-14, 0, 0), 0.032)
	A.vent(root, Vector3(0.46, 0.18, 0.04), Vector3(0, hip + 0.04, 0.44), Vector3(-14, 180, 0), 4)
	for sx_g in [-0.35, 0.35]:
		K.piston(root, Vector3(sx_g, hip + 0.24, -0.22), Vector3(sx_g * 0.78, hip + 0.48, -0.17), 0.026)
		K.piston(root, Vector3(sx_g, hip + 0.24, 0.22), Vector3(sx_g * 0.78, hip + 0.48, 0.17), 0.026)

	for sx in [-0.62, 0.62]:
		var side: float = sign(sx)
		var leg := K.node(root, Vector3(sx, hip, 0))
		var H := Vector3.ZERO
		var KN := Vector3(0, -0.78, -0.34)
		var AN := Vector3(0, -1.3, 0.2)

		# 髋：大作动器 + 外侧多面侧裙护盾
		K.actuator(leg, Vector3(-side * 0.04, 0, 0), 0.23, 0.38)
		K.plate(leg, K.crect(0.64, 0.52, [0.16, 0.08, 0.04, 0.14]), 0.10, M_LEG2, Vector3(side * 0.27, -0.02, 0.0), Vector3(0, side * 90.0, 0), 0.028)
		K.grab_iron(leg, 0.20, 0.038, Vector3(side * 0.32, 0.14, 0.0), Vector3(0, side * -90.0, 0))

		# 大腿：工字承力梁 + 双并联液压缸 + 层叠装甲壳
		var th := K.bone(leg, H, KN)
		var l1 := H.distance_to(KN)
		K.bb(th, Vector3(0.22, l1, 0.24), M_FRAME, Vector3(0, -l1 * 0.5, 0.02), Vector3.ZERO, 0.03)
		K.piston(th, Vector3(side * 0.13, -0.06, 0.16), Vector3(side * 0.11, -l1 + 0.10, 0.14), 0.034)
		K.piston(th, Vector3(-side * 0.11, -0.06, 0.16), Vector3(-side * 0.09, -l1 + 0.10, 0.14), 0.028)
		K.plate(th, K.trap(0.32, 0.48, l1 * 0.84, 0.07), 0.13, M_LEG, Vector3(0, -l1 * 0.46, -0.16), Vector3(-4, 0, 0), 0.035)
		K.plate(th, K.crect(0.26, l1 * 0.50, [0.06, 0.06, 0.02, 0.02]), 0.07, M_LEG2, Vector3(0, -l1 * 0.36, -0.24), Vector3(-4, 0, 0), 0.02)
		K.plate(th, K.crect(0.18, l1 * 0.68, [0.02, 0.08, 0.08, 0.02]), 0.38, M_LEG, Vector3(side * 0.22, -l1 * 0.48, -0.02), Vector3(0, side * 90.0, 0), 0.03)
		K.bb(th, Vector3(0.05, l1 * 0.28, 0.022), M_ACC, Vector3(side * 0.09, -l1 * 0.36, -0.28), Vector3(-4, 0, 0), 0.005)
		K.number(th, serial, Vector3(side * 0.415, -l1 * 0.5, -0.02), Vector3(0, side * 90.0, 0), 0.0034)
		A.hose(leg, Vector3(side * 0.11, -0.12, 0.22), Vector3(side * 0.09, -0.82, -0.14), Vector3(0, -0.05, 0.22), 0.026)

		# 膝：重型铰接鼓 + 立体折面装甲护膝（消除扁平三角贴片感）
		K.actuator(leg, KN, 0.18, 0.40)
		var kp := K.node(leg, KN + Vector3(0, 0.02, -0.18), Vector3(-12, 0, 0))
		K.plate(kp, K.trap(0.36, 0.42, 0.34, 0.06), 0.16, M_LEG2, Vector3(0, -0.02, 0.02), Vector3.ZERO, 0.032)
		K.plate(kp, K.trap(0.22, 0.30, 0.24, 0.04), 0.10, M_LEG, Vector3(0, 0.02, -0.06), Vector3(-8, 0, 0), 0.022)
		K.bb(kp, Vector3(0.28, 0.04, 0.14), K.gunmetal(), Vector3(0, 0.15, -0.02), Vector3.ZERO, 0.008)
		for kx in [-0.21, 0.21]:
			K.cy(kp, 0.032, 0.04, A.chrome(), Vector3(kx, 0.02, 0.02), Vector3(0, 0, 90), -1.0, 8)

		# 小腿（反关节后倾）：挂在膝关节枢轴上，行走时由 IK 驱动弯曲
		var kj := K.node(leg, KN, Vector3.ZERO, "Knee")
		var sh := K.bone(kj, Vector3.ZERO, AN - KN)
		var l2 := KN.distance_to(AN)
		K.bb(sh, Vector3(0.18, l2, 0.20), M_FRAME, Vector3(0, -l2 * 0.5, 0.02), Vector3.ZERO, 0.03)
		K.plate(sh, K.trap(0.28, 0.44, l2 * 0.90, 0.06), 0.11, M_LEG, Vector3(0, -l2 * 0.5, -0.14), Vector3.ZERO, 0.03)
		K.holes(sh, Vector3(0, -l2 * 0.35, -0.20), Vector3.ZERO, 2, 3, 0.07, 0.018)
		for s2 in [-1.0, 1.0]:
			K.plate(sh, K.crect(0.12, l2 * 0.72, [0.05, 0.02, 0.02, 0.05]), 0.26, M_LEG2, Vector3(s2 * 0.18, -l2 * 0.48, -0.03), Vector3(0, 90, 0), 0.02)
		K.piston(kj, Vector3(0, -0.08, 0.17), AN - KN + Vector3(0, 0.12, 0.13), 0.038)
		A.hose(kj, Vector3(-side * 0.1, 0.0, 0.11), AN - KN + Vector3(-side * 0.08, 0.08, 0.06), Vector3(0, 0, 0.14), 0.02)

		# 踝 + 机械接地爪足：踝护套 + 减震油缸 + 棱角铸钢三趾 + 液压驻退后跟
		var aj := K.node(kj, AN - KN, Vector3.ZERO, "Ankle")
		K.actuator(aj, Vector3.ZERO, 0.13, 0.34)
		var ft := K.node(aj, Vector3(0, -1.5, 0.08) - AN)
		K.bb(ft, Vector3(0.38, 0.16, 0.40), M_BARE, Vector3(0, 0.02, 0.04), Vector3.ZERO, 0.035)
		K.plate(ft, K.trap(0.38, 0.28, 0.30, 0.04), 0.12, M_LEG2, Vector3(0, 0.13, -0.09), Vector3(-68, 0, 0), 0.025)
		for t in [[-0.18, -16.0, 0.44], [0.0, 0.0, 0.54], [0.18, 16.0, 0.44]]:
			var toe := K.node(ft, Vector3(t[0], -0.02, -0.13), Vector3(0, t[1], 0))
			var tl: float = t[2]
			K.cy(toe, 0.048, 0.13, M_DARK, Vector3(0, 0.01, 0.0), Vector3(0, 0, 90), -1.0, 10)
			K.bb(toe, Vector3(0.12, 0.10, tl * 0.65), M_LEG, Vector3(0, 0.01, -tl * 0.34), Vector3(6, 0, 0), 0.02)
			K.plate(toe, K.trap(0.11, 0.07, tl * 0.42, 0.015), 0.09, K.gunmetal(), Vector3(0, -0.01, -tl * 0.78), Vector3(90, 0, 0), 0.015)
			K.bb(toe, Vector3(0.125, 0.035, tl * 0.86), A.rubber(), Vector3(0, -0.06, -tl * 0.45), Vector3.ZERO, 0.010)
		var spur := K.node(ft, Vector3(0, -0.02, 0.22), Vector3(0, 180, 0))
		K.bb(spur, Vector3(0.15, 0.10, 0.30), M_LEG2, Vector3(0, 0.01, -0.14), Vector3(8, 0, 0), 0.02)
		K.bb(spur, Vector3(0.16, 0.035, 0.28), A.rubber(), Vector3(0, -0.06, -0.14), Vector3.ZERO, 0.01)
		K.piston(ft, Vector3(0, 0.14, 0.16), Vector3(0, 0.02, 0.34), 0.024)
		K.bb(ft, Vector3(0.12, 0.03, 0.08), M_ACC, Vector3(0, 0.10, 0.24), Vector3.ZERO, 0.006)
		leg.set_meta("knee", kj)
		leg.set_meta("ankle", aj)
		leg.set_meta("KN", KN)
		leg.set_meta("AN", AN)
		leg.set_meta("sole", -1.5 - 0.06 - hip)   # 足底相对髋的高度（地面）
		leg_parts.append(leg)

	# ---- 收口装甲腰柱 + 外露液压管线（彻底收进骨盆厚度内，顶接 HP-C1 母座） ----
	K.cy(root, 0.28, 0.34, M_FRAME, Vector3(0, hip + 0.34, 0), Vector3.ZERO, 0.26, 24)
	K.cy(root, 0.36, 0.10, M_DARK, Vector3(0, hip + 0.485, 0), Vector3.ZERO, 0.315, 26)
	for a in [0.18, -0.18, PI - 0.18, PI + 0.18]:
		A.hose(root, Vector3(cos(a) * 0.31, hip + 0.27, sin(a) * 0.31), Vector3(cos(a) * 0.30, hip + 0.47, sin(a) * 0.30), Vector3(cos(a) * 0.05, 0, sin(a) * 0.05), 0.018)
	K.socket(root, "core", Vector3(0, hip + 0.55, 0), Vector3.UP)
	root.set_meta("leg_parts", leg_parts)
	root.set_meta("leg_type", "biped")
	return root
