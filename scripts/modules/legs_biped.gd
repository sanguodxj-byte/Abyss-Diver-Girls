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

	# ---- 骨盆：机械腰胯 + 前后多面裙甲 ----
	K.bb(root, Vector3(1.0, 0.3, 0.6), M_FRAME, Vector3(0, hip + 0.02, 0.02), Vector3.ZERO, 0.05)
	K.plate(root, K.trap(0.62, 0.86, 0.42, 0.07), 0.1, M_LEG, Vector3(0, hip - 0.02, -0.36), Vector3(16, 0, 0), 0.03)
	K.plate(root, K.crect(0.34, 0.06), 0.11, M_ACC, Vector3(0, hip + 0.14, -0.4), Vector3(16, 0, 0), 0.01)
	K.plate(root, K.trap(0.7, 0.9, 0.36, 0.06), 0.1, M_LEG2, Vector3(0, hip - 0.02, 0.36), Vector3(-14, 0, 0), 0.03)
	K.holes(root, Vector3(0, hip - 0.02, 0.42), Vector3(-14, 180, 0), 5, 2, 0.08, 0.022)

	for sx in [-0.62, 0.62]:
		var side: float = sign(sx)
		var leg := K.node(root, Vector3(sx, hip, 0))
		var H := Vector3.ZERO
		var KN := Vector3(0, -0.78, -0.34)
		var AN := Vector3(0, -1.3, 0.2)

		# 髋：大作动器 + 外侧切角护甲
		K.actuator(leg, Vector3(-side * 0.04, 0, 0), 0.22, 0.36)
		K.plate(leg, K.crect(0.62, 0.5, [0.16, 0.08, 0.0, 0.14]), 0.08, M_LEG2, Vector3(side * 0.26, -0.02, 0.0), Vector3(0, side * 90.0, 0), 0.025)

		# 大腿：工字骨架 + 双液压 + 前侧多面甲
		var th := K.bone(leg, H, KN)
		var l1 := H.distance_to(KN)
		K.bb(th, Vector3(0.18, l1, 0.2), M_FRAME, Vector3(0, -l1 * 0.5, 0.02), Vector3.ZERO, 0.03)
		K.piston(th, Vector3(side * 0.12, -0.06, 0.14), Vector3(side * 0.1, -l1 + 0.1, 0.12), 0.032)
		K.piston(th, Vector3(-side * 0.1, -0.06, 0.14), Vector3(-side * 0.08, -l1 + 0.1, 0.12), 0.026)
		K.plate(th, K.trap(0.3, 0.46, l1 * 0.82, 0.07), 0.12, M_LEG, Vector3(0, -l1 * 0.46, -0.16), Vector3(-4, 0, 0), 0.035)
		K.plate(th, K.crect(0.24, l1 * 0.5, [0.06, 0.06, 0.0, 0.0]), 0.06, M_LEG2, Vector3(0, -l1 * 0.36, -0.24), Vector3(-4, 0, 0), 0.02)
		K.plate(th, K.crect(0.16, l1 * 0.66, [0.0, 0.08, 0.08, 0.0]), 0.36, M_LEG, Vector3(side * 0.22, -l1 * 0.48, -0.02), Vector3(0, side * 90.0, 0), 0.03)
		K.bb(th, Vector3(0.05, l1 * 0.3, 0.02), M_ACC, Vector3(side * 0.08, -l1 * 0.36, -0.275), Vector3(-4, 0, 0), 0.005)
		K.number(th, serial, Vector3(side * 0.305, -l1 * 0.5, -0.02), Vector3(0, side * 90.0, 0), 0.0034)
		A.hose(leg, Vector3(side * 0.1, -0.12, 0.2), Vector3(side * 0.08, -0.82, -0.14), Vector3(0, -0.05, 0.22), 0.026)

		# 膝：作动器 + 尖形护膝（五边形）
		K.actuator(leg, KN, 0.17, 0.38)
		var kp := K.node(leg, KN + Vector3(0, 0.02, -0.17), Vector3(-12, 0, 0))
		K.plate(kp, [Vector2(-0.2, 0.16), Vector2(0.2, 0.16), Vector2(0.22, -0.06), Vector2(0.0, -0.26), Vector2(-0.22, -0.06)], 0.12, M_LEG2, Vector3.ZERO, Vector3.ZERO, 0.035)
		K.plate(kp, [Vector2(-0.12, 0.1), Vector2(0.12, 0.1), Vector2(0.0, -0.14)], 0.13, M_LEG, Vector3(0, 0.0, -0.01), Vector3.ZERO, 0.02)

		# 小腿（后倾）：挂在膝关节枢轴上，行走时由 IK 驱动弯曲
		var kj := K.node(leg, KN, Vector3.ZERO, "Knee")
		var sh := K.bone(kj, Vector3.ZERO, AN - KN)
		var l2 := KN.distance_to(AN)
		K.bb(sh, Vector3(0.16, l2, 0.18), M_FRAME, Vector3(0, -l2 * 0.5, 0.02), Vector3.ZERO, 0.03)
		K.plate(sh, K.trap(0.26, 0.42, l2 * 0.9, 0.06), 0.1, M_LEG, Vector3(0, -l2 * 0.5, -0.14), Vector3.ZERO, 0.03)
		K.holes(sh, Vector3(0, -l2 * 0.35, -0.195), Vector3.ZERO, 2, 3, 0.07, 0.02)
		for s2 in [-1.0, 1.0]:
			K.plate(sh, K.crect(0.1, l2 * 0.7, [0.05, 0.0, 0.0, 0.05]), 0.24, M_LEG2, Vector3(s2 * 0.17, -l2 * 0.48, -0.03), Vector3(0, 90, 0), 0.02)
		K.piston(kj, Vector3(0, -0.08, 0.16), AN - KN + Vector3(0, 0.12, 0.12), 0.034)
		A.hose(kj, Vector3(-side * 0.1, 0.0, 0.1), AN - KN + Vector3(-side * 0.08, 0.08, 0.06), Vector3(0, 0, 0.14), 0.02, A.paint(Color(0.1, 0.1, 0.11), 0.0, 0.7, {"panel_scale": 0.0}))

		# 踝 + 爪足：中央足掌、三根前趾（中趾最长）、后跟距
		var aj := K.node(kj, AN - KN, Vector3.ZERO, "Ankle")
		K.actuator(aj, Vector3.ZERO, 0.12, 0.32)
		var ft := K.node(aj, Vector3(0, -1.5, 0.08) - AN)
		K.bb(ft, Vector3(0.34, 0.16, 0.36), M_BARE, Vector3(0, 0.02, 0.04), Vector3.ZERO, 0.04)
		K.plate(ft, K.trap(0.36, 0.26, 0.3, 0.04), 0.12, M_LEG2, Vector3(0, 0.12, -0.08), Vector3(-70, 0, 0), 0.025)
		for t in [[-0.17, -18.0, 0.44], [0.0, 0.0, 0.54], [0.17, 18.0, 0.44]]:
			var toe := K.node(ft, Vector3(t[0], -0.02, -0.12), Vector3(0, t[1], 0))
			var tl: float = t[2]
			K.plate(toe, [Vector2(-0.07, 0.0), Vector2(0.07, 0.0), Vector2(0.06, -tl * 0.8), Vector2(0.0, -tl), Vector2(-0.06, -tl * 0.8)], 0.11, M_LEG, Vector3(0, 0.02, 0), Vector3(90, 0, 0), 0.025)
			K.bb(toe, Vector3(0.12, 0.04, tl * 0.75), A.rubber(), Vector3(0, -0.06, -tl * 0.4), Vector3.ZERO, 0.012)
			K.cy(toe, 0.05, 0.12, M_FRAME, Vector3(0, 0.0, 0.0), Vector3(0, 0, 90), -1.0, 10)
		var spur := K.node(ft, Vector3(0, -0.02, 0.2), Vector3(0, 180, 0))
		K.plate(spur, [Vector2(-0.07, 0.0), Vector2(0.07, 0.0), Vector2(0.0, -0.3)], 0.1, M_LEG2, Vector3(0, 0.02, 0), Vector3(90, 0, 0), 0.02)
		K.bb(ft, Vector3(0.1, 0.03, 0.08), M_ACC, Vector3(0, 0.1, 0.23), Vector3.ZERO, 0.008)
		leg.set_meta("knee", kj)
		leg.set_meta("ankle", aj)
		leg.set_meta("KN", KN)
		leg.set_meta("AN", AN)
		leg.set_meta("sole", -1.5 - 0.06 - hip)   # 足底相对髋的高度（地面）
		leg_parts.append(leg)

	# ---- 腰部回转轴（顶端是 HP-C1 母座） ----
	K.cy(root, 0.3, 0.8, M_FRAME, Vector3(0, hip + 0.12, 0), Vector3.ZERO, 0.36, 20)
	K.cy(root, 0.44, 0.1, M_DARK, Vector3(0, hip + 0.2, 0), Vector3.ZERO, 0.46, 24)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		A.hose(root, Vector3(cos(a) * 0.32, hip + 0.24, sin(a) * 0.32), Vector3(cos(a) * 0.27, hip + 0.48, sin(a) * 0.27), Vector3(cos(a) * 0.08, 0, sin(a) * 0.08), 0.018)
	K.socket(root, "core", Vector3(0, hip + 0.55, 0), Vector3.UP)
	root.set_meta("leg_parts", leg_parts)
	root.set_meta("leg_type", "biped")
	return root
