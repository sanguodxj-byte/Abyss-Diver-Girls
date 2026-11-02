extends RefCounted
## 重型双足 Titan：比 Stride 高约 0.4m、粗约 1.4 倍的反关节泰坦腿。
## 箱形骨盆 + 双层裙甲、三液压大腿、厚胫甲、象足式平底大足（四趾垫 + 后跟）
## 接口：提供插座 HP-C1（躯干，粗壮腰柱顶端）；自身是装配树的根，无插头
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var c: Color = ctx.color
	var serial: String = ctx.get("serial", "00")
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var M_ACC := K.accent()
	var root := K.module_root("legs", ctx.id, Vector3.ZERO)
	var M_LEG := K.armor(c, 0.5)
	var M_LEG2 := K.armor(c.darkened(0.25), 0.5)
	var M_BARE := A.metal(Color(0.27, 0.28, 0.3))
	var leg_parts: Array = []
	var hip := 1.72

	# ---- 骨盆：宽厚箱形腰胯 + 前后双层裙甲 ----
	K.bb(root, Vector3(1.7, 0.7, 1.3), M_FRAME, Vector3(0, hip + 0.04, 0.02), Vector3.ZERO, 0.08)
	K.bb(root, Vector3(1.3, 0.34, 1.1), M_LEG2, Vector3(0, hip + 0.38, 0.02), Vector3.ZERO, 0.06)
	K.plate(root, K.trap(1.0, 1.4, 0.66, 0.12), 0.24, M_LEG, Vector3(0, hip - 0.06, -0.74), Vector3(14, 0, 0), 0.05)
	K.plate(root, K.trap(0.7, 1.0, 0.34, 0.08), 0.12, M_LEG2, Vector3(0, hip - 0.06, -0.9), Vector3(14, 0, 0), 0.03)
	K.plate(root, K.crect(0.7, 0.08), 0.25, M_ACC, Vector3(0, hip + 0.2, -0.78), Vector3(14, 0, 0), 0.01)
	K.plate(root, K.trap(1.1, 1.5, 0.6, 0.1), 0.24, M_LEG2, Vector3(0, hip - 0.06, 0.74), Vector3(-12, 0, 0), 0.05)
	K.holes(root, Vector3(0, hip - 0.06, 0.87), Vector3(-12, 180, 0), 6, 2, 0.12, 0.034)

	for sx in [-0.92, 0.92]:
		var side: float = sign(sx)
		var leg := K.node(root, Vector3(sx, hip, 0))
		var KN := Vector3(0, -0.74, -0.34)
		var AN := Vector3(0, -1.24, 0.2)

		# 髋：粗大作动器 + 外侧厚盾
		K.actuator(leg, Vector3(-side * 0.06, 0, 0), 0.5, 0.6)
		K.plate(leg, K.crect(1.24, 1.0, [0.3, 0.14, 0.0, 0.26]), 0.2, M_LEG2, Vector3(side * 0.44, -0.06, 0.0), Vector3(0, side * 90.0, 0), 0.05)
		K.plate(leg, K.crect(0.7, 0.1), 0.21, M_ACC, Vector3(side * 0.45, 0.3, 0.0), Vector3(0, side * 90.0, 0), 0.01)
		for i in 4:
			K.cy(leg, 0.035, 0.04, A.metal(Color(0.45, 0.45, 0.45)), Vector3(side * 0.55, -0.42, -0.42 + i * 0.28), Vector3(0, 0, 90), -1.0, 8)

		# 大腿：整块装甲箱 + 前侧双层厚甲 + 后侧液压块
		var th := K.bone(leg, Vector3.ZERO, KN)
		var l1 := KN.length()
		K.bb(th, Vector3(0.72, l1 + 0.12, 0.92), M_LEG2, Vector3(0, -l1 * 0.5, 0.04), Vector3.ZERO, 0.16)
		K.plate(th, K.trap(0.62, 0.8, l1 * 0.95, 0.14), 0.24, M_LEG, Vector3(0, -l1 * 0.48, -0.5), Vector3(-3, 0, 0), 0.06)
		K.plate(th, K.crect(0.5, l1 * 0.55, [0.1, 0.1, 0.0, 0.0]), 0.14, M_LEG2, Vector3(0, -l1 * 0.36, -0.65), Vector3(-3, 0, 0), 0.035)
		for s2 in [-1.0, 1.0]:
			K.plate(th, K.crect(0.8, l1 * 0.82, [0.12, 0.2, 0.2, 0.12]), 0.14, M_LEG, Vector3(s2 * 0.41, -l1 * 0.5, 0.0), Vector3(0, s2 * 90.0, 0), 0.04)
		K.bb(th, Vector3(0.54, l1 * 0.74, 0.28), M_FRAME, Vector3(0, -l1 * 0.5, 0.6), Vector3.ZERO, 0.04)
		for s2 in [-1.0, 1.0]:
			K.cy(th, 0.075, l1 * 0.66, A.chrome(), Vector3(s2 * 0.15, -l1 * 0.5, 0.76), Vector3.ZERO, -1.0, 12)
		A.rivets(th, Vector3(side * 0.485, -0.12, -0.28), Vector3(side * 0.485, -l1 + 0.12, -0.28), 6, 0.022, Vector3(0, 0, 90))
		K.number(th, serial, Vector3(side * 0.485, -l1 * 0.5, 0.08), Vector3(0, side * 90.0, 0), 0.005)
		A.hose(leg, Vector3(side * 0.2, -0.2, 0.5), Vector3(side * 0.2, -0.8, 0.1), Vector3(0, -0.06, 0.3), 0.045)

		# 膝：粗作动器 + 大护膝
		K.actuator(leg, KN, 0.4, 0.7)
		var kp := K.node(leg, KN + Vector3(0, 0.04, -0.44), Vector3(-10, 0, 0))
		K.plate(kp, [Vector2(-0.42, 0.28), Vector2(0.42, 0.28), Vector2(0.44, -0.1), Vector2(0.0, -0.42), Vector2(-0.44, -0.1)], 0.34, M_LEG2, Vector3.ZERO, Vector3.ZERO, 0.08)
		K.plate(kp, [Vector2(-0.24, 0.18), Vector2(0.24, 0.18), Vector2(0.0, -0.24)], 0.35, M_LEG, Vector3(0, 0.0, -0.01), Vector3.ZERO, 0.03)

		# 小腿：厚装甲箱 + 前甲 + 后侧大液压
		var kj := K.node(leg, KN, Vector3.ZERO, "Knee")
		var sh := K.bone(kj, Vector3.ZERO, AN - KN)
		var l2 := KN.distance_to(AN)
		K.bb(sh, Vector3(0.66, l2 + 0.08, 0.86), M_LEG2, Vector3(0, -l2 * 0.5, 0.06), Vector3.ZERO, 0.15)
		K.plate(sh, K.trap(0.56, 0.74, l2 * 0.92, 0.12), 0.22, M_LEG, Vector3(0, -l2 * 0.5, -0.45), Vector3.ZERO, 0.05)
		K.holes(sh, Vector3(0, -l2 * 0.4, -0.565), Vector3.ZERO, 4, 2, 0.1, 0.03)
		for s2 in [-1.0, 1.0]:
			K.plate(sh, K.crect(0.74, l2 * 0.78, [0.14, 0.06, 0.06, 0.14]), 0.12, M_LEG, Vector3(s2 * 0.37, -l2 * 0.48, 0.04), Vector3(0, s2 * 90.0, 0), 0.03)
		K.piston(kj, Vector3(0, -0.08, 0.5), AN - KN + Vector3(0, 0.22, 0.46), 0.11)
		K.piston(kj, Vector3(side * 0.22, -0.08, 0.46), AN - KN + Vector3(side * 0.22, 0.22, 0.42), 0.075)

		# 踝 + 象足式宽厚大足
		var aj := K.node(kj, AN - KN, Vector3.ZERO, "Ankle")
		K.actuator(aj, Vector3.ZERO, 0.32, 0.58)
		var ft := K.node(aj, Vector3(0, -1.5, 0.06) - AN)
		K.bb(ft, Vector3(0.84, 0.34, 1.0), M_BARE, Vector3(0, 0.04, 0.0), Vector3.ZERO, 0.08)
		K.plate(ft, K.trap(0.84, 0.6, 0.54, 0.08), 0.26, M_LEG2, Vector3(0, 0.24, -0.22), Vector3(-58, 0, 0), 0.045)
		K.bb(ft, Vector3(0.88, 0.07, 1.04), A.rubber(), Vector3(0, -0.15, 0.0), Vector3.ZERO, 0.02)
		for i in 4:
			var tx := -0.3 + i * 0.2
			var toe := K.node(ft, Vector3(tx, -0.02, -0.5), Vector3(0, (i - 1.5) * 8.0, 0))
			K.bb(toe, Vector3(0.19, 0.28, 0.32), M_LEG, Vector3(0, 0.0, -0.1), Vector3(-10, 0, 0), 0.05)
			K.bb(toe, Vector3(0.2, 0.06, 0.32), A.rubber(), Vector3(0, -0.15, -0.11), Vector3.ZERO, 0.015)
		K.bb(ft, Vector3(0.6, 0.24, 0.26), M_LEG2, Vector3(0, 0.0, 0.56), Vector3(12, 0, 0), 0.05)
		K.bb(ft, Vector3(0.2, 0.05, 0.12), M_ACC, Vector3(0, 0.22, 0.48), Vector3.ZERO, 0.008)
		leg.set_meta("knee", kj)
		leg.set_meta("ankle", aj)
		leg.set_meta("KN", KN)
		leg.set_meta("AN", AN)
		leg.set_meta("sole", -1.52 - 0.185 - hip)
		leg_parts.append(leg)

	# ---- 粗壮腰柱（顶端 HP-C1 母座） ----
	K.cy(root, 0.6, 0.7, M_FRAME, Vector3(0, hip + 0.2, 0), Vector3.ZERO, 0.6, 28)
	K.cy(root, 0.62, 0.1, M_DARK, Vector3(0, hip + 0.5, 0), Vector3.ZERO, 0.64, 28)
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		A.hose(root, Vector3(cos(a) * 0.6, hip + 0.26, sin(a) * 0.6), Vector3(cos(a) * 0.5, hip + 0.52, sin(a) * 0.5), Vector3(cos(a) * 0.1, 0, sin(a) * 0.1), 0.024)
	K.socket(root, "core", Vector3(0, hip + 0.55, 0), Vector3.UP)
	root.set_meta("leg_parts", leg_parts)
	root.set_meta("leg_type", "biped")
	return root
