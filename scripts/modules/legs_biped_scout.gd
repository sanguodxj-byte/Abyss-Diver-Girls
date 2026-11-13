extends RefCounted
## 轻型侦察双足底盘 LN-3：铬钼钢管桁架骨盆、双侧斜置固体火箭推进荚舱、外露氮气减震筒、高速双趾猛禽爪足
## 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var id: String = ctx.id
	var c: Color = ctx.color
	var serial: String = ctx.get("serial", "03")
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var M_GUN := K.gunmetal()
	var M_ACC := K.accent()
	var root := K.module_root("legs", id, Vector3.ZERO)
	var M_LEG := K.armor(c, 0.40)
	var M_LEG2 := K.armor_sub(c, 0.44)
	var leg_parts: Array = []
	var hip := 1.54

	# ---- 轻量化桁架骨盆 + 紧凑切角裆甲 + 左右斜置矢量推进器荚舱 ----
	K.bb(root, Vector3(0.88, 0.28, 0.56), M_FRAME, Vector3(0, hip + 0.04, 0.0), Vector3.ZERO, 0.04)
	K.plate(root, K.trap(0.46, 0.72, 0.38, 0.06), 0.10, M_LEG, Vector3(0, hip + 0.02, -0.32), Vector3(18, 0, 0), 0.025)
	K.plate(root, K.crect(0.30, 0.045), 0.11, M_ACC, Vector3(0, hip + 0.14, -0.35), Vector3(18, 0, 0), 0.006)
	K.periscope(root, 0.16, 0.065, Vector3(0, hip + 0.02, -0.36), Vector3(18, 0, 0))
	K.plate(root, K.trap(0.54, 0.76, 0.34, 0.05), 0.10, M_LEG2, Vector3(0, hip + 0.04, 0.30), Vector3(-16, 0, 0), 0.025)

	# 髋部双联固体矢量推进荚舱（侦察型高机动特征 + 刚性耳轴连接臂）
	for sx_p in [-0.52, 0.52]:
		var side_p: float = sign(sx_p)
		K.bb(root, Vector3(0.18, 0.12, 0.18), M_FRAME, Vector3(side_p * 0.42, hip + 0.12, 0.14), Vector3.ZERO, 0.02)
		var pod := K.node(root, Vector3(sx_p, hip + 0.20, 0.20), Vector3(-24, side_p * -14.0, side_p * -18.0))
		K.bb(pod, Vector3(0.22, 0.24, 0.48), M_LEG2, Vector3.ZERO, Vector3.ZERO, 0.03)
		K.plate(pod, K.crect(0.18, 0.04), 0.44, M_ACC, Vector3(side_p * 0.10, 0.04, 0.0), Vector3(0, 90, 0), 0.005)
		K.cy(pod, 0.085, 0.14, M_GUN, Vector3(0, -0.02, 0.27), Vector3(90, 0, 0), 0.065, 14)
		K.barrel_bore(pod, 0.082, 0.058, Vector3(0, -0.02, 0.34), 0.06, Vector3(-90, 0, 0))

	for sx in [-0.54, 0.54]:
		var side: float = sign(sx)
		var leg := K.node(root, Vector3(sx, hip, 0))
		var H := Vector3.ZERO
		var KN := Vector3(0, -0.74, -0.36)
		var AN := Vector3(0, -1.26, 0.24)

		# 髋关节：紧凑镂空法兰鼓 + 轻型防碎石翼片（双侧喷涂编号钢印）
		K.actuator(leg, Vector3(-side * 0.03, 0, 0), 0.18, 0.30)
		var hsh := K.node(leg, Vector3(side * 0.21, 0.02, -0.02), Vector3(0, side * 90.0, -side * 10.0))
		K.plate(hsh, K.trap(0.42, 0.30, 0.34, 0.05), 0.07, M_LEG, Vector3.ZERO, Vector3.ZERO, 0.02)
		A.stencil(hsh, "LN-" + serial, Vector3(0, -0.02, 0.043), Vector3.ZERO, 0.0023, Color(0.95, 0.93, 0.86, 0.88))

		# 大腿：双侧镂空铬钼钢管梁 + 外挂黄铜氮气减震瓶 + 轻质前护板
		var th := K.bone(leg, H, KN)
		var l1 := H.distance_to(KN)
		for bx in [-0.075, 0.075]:
			K.cy(th, 0.038, l1 * 0.94, M_FRAME, Vector3(bx, -l1 * 0.5, 0.0), Vector3.ZERO, -1.0, 10)
		for rt in [0.25, 0.55, 0.82]:
			K.bb(th, Vector3(0.19, 0.05, 0.12), M_GUN, Vector3(0, -l1 * rt, 0.0), Vector3.ZERO, 0.01)
		# 背负式黄铜氮气补偿储气罐 + 镀铬减震活塞
		K.cy(th, 0.048, 0.28, K.brass(), Vector3(side * 0.13, -l1 * 0.32, 0.10), Vector3.ZERO, -1.0, 12)
		K.piston(th, Vector3(0, -0.08, 0.14), Vector3(0, -l1 + 0.10, 0.12), 0.030)
		K.plate(th, K.trap(0.22, 0.34, l1 * 0.78, 0.05), 0.09, M_LEG, Vector3(0, -l1 * 0.46, -0.11), Vector3(-4, 0, 0), 0.024)
		K.holes(th, Vector3(0, -l1 * 0.34, -0.16), Vector3(-4, 0, 0), 2, 2, 0.06, 0.014)
		A.hose(leg, Vector3(side * 0.09, -0.10, 0.16), Vector3(side * 0.08, -0.74, -0.16), Vector3(0, -0.04, 0.18), 0.020)

		# 膝：轻量化转轴鼓 + 锐角导流护膝
		K.actuator(leg, KN, 0.14, 0.30)
		var kp := K.node(leg, KN + Vector3(0, 0.02, -0.14), Vector3(-16, 0, 0))
		K.plate(kp, K.trap(0.24, 0.30, 0.28, 0.04), 0.10, M_LEG2, Vector3.ZERO, Vector3.ZERO, 0.022)
		K.plate(kp, K.crect(0.18, 0.04), 0.11, M_ACC, Vector3(0, 0.06, -0.01), Vector3.ZERO, 0.005)

		# 小腿（修长反关节弹性弓片 + 双撑杆）：IK 驱动
		var kj := K.node(leg, KN, Vector3.ZERO, "Knee")
		var sh := K.bone(kj, Vector3.ZERO, AN - KN)
		var l2 := KN.distance_to(AN)
		for bx in [-0.065, 0.065]:
			K.bb(sh, Vector3(0.055, l2 * 0.94, 0.12), M_FRAME, Vector3(bx, -l2 * 0.5, 0.01), Vector3.ZERO, 0.014)
		K.plate(sh, K.trap(0.18, 0.28, l2 * 0.78, 0.04), 0.08, M_LEG, Vector3(0, -l2 * 0.44, -0.09), Vector3.ZERO, 0.022)
		K.piston(kj, Vector3(0, -0.06, 0.13), AN - KN + Vector3(0, 0.10, 0.10), 0.030)

		# 踝 + 高速双趾猛禽弹性机械爪足
		var aj := K.node(kj, AN - KN, Vector3.ZERO, "Ankle")
		K.actuator(aj, Vector3.ZERO, 0.105, 0.26)
		var ft := K.node(aj, Vector3(0, -1.44, 0.08) - AN)
		K.bb(ft, Vector3(0.28, 0.13, 0.32), M_GUN, Vector3(0, 0.02, 0.02), Vector3.ZERO, 0.025)
		for t in [[-0.10, -11.0, 0.50], [0.10, 11.0, 0.50]]:
			var toe := K.node(ft, Vector3(t[0], -0.02, -0.12), Vector3(0, t[1], 0))
			var tl: float = t[2]
			K.bb(toe, Vector3(0.095, 0.085, tl * 0.68), M_LEG, Vector3(0, 0.01, -tl * 0.34), Vector3(6, 0, 0), 0.018)
			K.plate(toe, K.trap(0.09, 0.05, tl * 0.40, 0.01), 0.075, M_DARK, Vector3(0, -0.01, -tl * 0.78), Vector3(90, 0, 0), 0.012)
			K.bb(toe, Vector3(0.10, 0.032, tl * 0.86), A.rubber(), Vector3(0, -0.06, -tl * 0.44), Vector3.ZERO, 0.008)
		var spur := K.node(ft, Vector3(0, -0.02, 0.18), Vector3(0, 180, 0))
		K.bb(spur, Vector3(0.11, 0.08, 0.28), M_LEG2, Vector3(0, 0.0, -0.13), Vector3(8, 0, 0), 0.016)
		K.bb(spur, Vector3(0.12, 0.032, 0.26), A.rubber(), Vector3(0, -0.06, -0.13), Vector3.ZERO, 0.008)
		K.piston(ft, Vector3(0, 0.12, 0.12), Vector3(0, 0.01, 0.28), 0.020)
		leg.set_meta("knee", kj)
		leg.set_meta("ankle", aj)
		leg.set_meta("KN", KN)
		leg.set_meta("AN", AN)
		leg.set_meta("sole", -1.44 - 0.096 - hip)
		leg_parts.append(leg)

	# 紧凑腰部回转座柱（顶接 HP-C1 母座 hip+0.54）
	K.cy(root, 0.44, 0.38, M_FRAME, Vector3(0, hip + 0.30, 0), Vector3.ZERO, 0.50, 22)
	K.cy(root, 0.50, 0.10, M_DARK, Vector3(0, hip + 0.48, 0), Vector3.ZERO, 0.52, 24)
	for sx_g in [-0.30, 0.30]:
		K.piston(root, Vector3(sx_g, hip + 0.12, -0.18), Vector3(sx_g * 0.82, hip + 0.45, -0.14), 0.024)
	K.socket(root, "core", Vector3(0, hip + 0.54, 0), Vector3.UP)
	root.set_meta("leg_parts", leg_parts)
	root.set_meta("leg_type", "biped")
	return root
