extends RefCounted
## 中重突击双足底盘 VK-5：正关节人形战术重甲腿、铰接防弹腰裙甲、高耸反应装甲撞膝盾、小腿喷口与重型平底战靴
## 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var id: String = ctx.id
	var c: Color = ctx.color
	var serial: String = ctx.get("serial", "05")
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var M_GUN := K.gunmetal()
	var M_ACC := K.accent()
	var root := K.module_root("legs", id, Vector3.ZERO)
	var M_LEG := K.armor(c, 0.48)
	var M_LEG2 := K.armor_sub(c, 0.52)
	var M_BARE := A.metal(Color(0.25, 0.26, 0.28))
	var leg_parts: Array = []
	var hip := 1.66

	# ---- 军用正关节战术骨盆：中央楔形防弹裆块 + 左右独立铰接前裙甲（Faulds）+ 后置散热尾裙 ----
	K.bb(root, Vector3(1.28, 0.46, 0.86), M_FRAME, Vector3(0, hip + 0.06, 0.02), Vector3.ZERO, 0.06)
	K.bb(root, Vector3(1.04, 0.30, 0.76), M_LEG2, Vector3(0, hip + 0.34, 0.02), Vector3.ZERO, 0.05)
	# 中央突击裆部重甲
	K.plate(root, K.trap(0.38, 0.48, 0.54, 0.05), 0.22, M_LEG2, Vector3(0, hip - 0.04, -0.48), Vector3(10, 0, 0), 0.035)
	K.plate(root, K.crect(0.28, 0.055), 0.23, M_ACC, Vector3(0, hip + 0.14, -0.50), Vector3(10, 0, 0), 0.006)
	# 左右铰接战术前裙板（右侧裙板喷涂部队编号钢印）
	for sx_f in [-0.42, 0.42]:
		var side_f: float = sign(sx_f)
		var flap := K.node(root, Vector3(sx_f, hip + 0.02, -0.44), Vector3(14, side_f * -10.0, side_f * -6.0))
		K.plate(flap, K.trap(0.42, 0.36, 0.46, 0.05), 0.11, M_LEG, Vector3(0, -0.08, 0), Vector3.ZERO, 0.028)
		K.cy(flap, 0.035, 0.16, M_GUN, Vector3(0, 0.14, 0.02), Vector3(0, 0, 90), -1.0, 10)
		if side_f > 0.0:
			A.stencil(flap, "VK-" + serial, Vector3(0, -0.08, -0.063), Vector3(0, 180, 0), 0.0025, Color(0.95, 0.93, 0.86, 0.88))
	# 后置防弹尾裙 + 散热百叶
	K.plate(root, K.trap(0.96, 1.18, 0.48, 0.08), 0.14, M_LEG2, Vector3(0, hip - 0.02, 0.48), Vector3(-14, 0, 0), 0.035)
	A.vent(root, Vector3(0.62, 0.20, 0.05), Vector3(0, hip + 0.02, 0.56), Vector3(-14, 180, 0), 5)

	for sx in [-0.70, 0.70]:
		var side: float = sign(sx)
		var leg := K.node(root, Vector3(sx, hip, 0))
		# 正关节人形步态几何：膝盖朝前（z=-0.22），脚踝近垂直落于重心下方（z=-0.02）
		var H := Vector3.ZERO
		var KN := Vector3(0, -0.76, -0.22)
		var AN := Vector3(0, -1.38, -0.02)

		# 髋部外挂重型侧裙盾 + 战术导轨挂点
		K.actuator(leg, Vector3(-side * 0.05, 0, 0), 0.28, 0.44)
		var hsh := K.node(leg, Vector3(side * 0.31, -0.04, 0.0), Vector3(0, side * 90.0, -side * 8.0))
		K.plate(hsh, K.trap(0.76, 0.58, 0.54, 0.08), 0.13, M_LEG2, Vector3.ZERO, Vector3.ZERO, 0.032)
		K.era_block(hsh, Vector3(0.38, 0.20, 0.07), M_LEG, Vector3(0, 0.06, -0.09))
		K.grab_iron(hsh, 0.22, 0.04, Vector3(0, 0.24, -0.02), Vector3(-90, 0, 0), 0.013)

		# 大腿：棱角焊接装甲箱梁 + 两侧皮卡汀尼式外挂导轨 + 后置双液压肌群
		var th := K.bone(leg, H, KN)
		var l1 := H.distance_to(KN)
		K.bb(th, Vector3(0.46, l1 * 0.96, 0.54), M_FRAME, Vector3(0, -l1 * 0.5, 0.02), Vector3.ZERO, 0.06)
		K.plate(th, K.trap(0.44, 0.52, l1 * 0.88, 0.07), 0.16, M_LEG, Vector3(0, -l1 * 0.48, -0.26), Vector3(-2, 0, 0), 0.038)
		for s2 in [-1.0, 1.0]:
			K.plate(th, K.crect(0.48, l1 * 0.78, [0.08, 0.08, 0.06, 0.06]), 0.11, M_LEG2, Vector3(s2 * 0.25, -l1 * 0.48, 0.0), Vector3(0, s2 * 90.0, 0), 0.025)
		K.piston(th, Vector3(side * 0.12, -0.08, 0.28), Vector3(side * 0.12, -l1 + 0.08, 0.24), 0.042)
		K.piston(th, Vector3(-side * 0.12, -0.08, 0.28), Vector3(-side * 0.12, -l1 + 0.08, 0.24), 0.036)

		# 小腿与高耸重装撞膝盾（挂在 Knee 节点上，随小腿摆动呈真实外骨骼护胫结构！）
		K.actuator(leg, KN, 0.22, 0.48)
		var kj := K.node(leg, KN, Vector3.ZERO, "Knee")
		var sh := K.bone(kj, Vector3.ZERO, AN - KN)
		var l2 := KN.distance_to(AN)

		# 高耸突击护膝盾（向上遮蔽膝关节正面 + 外嵌 ERA 反应装甲块）
		var ksh := K.node(kj, Vector3(0, 0.08, -0.28), Vector3(-12, 0, 0))
		K.plate(ksh, K.trap(0.50, 0.38, 0.48, 0.07), 0.18, M_LEG, Vector3.ZERO, Vector3.ZERO, 0.038)
		K.era_block(ksh, Vector3(0.30, 0.16, 0.07), M_LEG2, Vector3(0, 0.06, -0.11))
		K.plate(ksh, K.crect(0.32, 0.05), 0.19, M_ACC, Vector3(0, -0.12, -0.01), Vector3.ZERO, 0.005)

		# 宽幅外扩重型胫甲（Wanzer 风格喇叭形装甲护胫 + 后部辅助跳跃喷口荚舱）
		K.bb(sh, Vector3(0.48, l2 * 0.94, 0.56), M_FRAME, Vector3(0, -l2 * 0.52, 0.04), Vector3.ZERO, 0.06)
		K.plate(sh, K.trap(0.56, 0.44, l2 * 0.90, 0.07), 0.18, M_LEG, Vector3(0, -l2 * 0.52, -0.26), Vector3(4, 0, 0), 0.038)
		for s2 in [-1.0, 1.0]:
			K.plate(sh, K.trap(0.60, 0.44, l2 * 0.86, 0.06), 0.12, M_LEG2, Vector3(s2 * 0.27, -l2 * 0.54, 0.04), Vector3(0, s2 * 90.0, s2 * -4.0), 0.03)
		# 小腿后侧机动喷射导流舱 + 双喷管
		var calf_pod := K.node(sh, Vector3(0, -l2 * 0.42, 0.34), Vector3(16, 0, 0))
		K.bb(calf_pod, Vector3(0.42, 0.36, 0.22), M_LEG2, Vector3.ZERO, Vector3.ZERO, 0.03)
		A.vent(calf_pod, Vector3(0.32, 0.14, 0.04), Vector3(0, 0.06, 0.11), Vector3(0, 180, 0), 4)
		for nz_x in [-0.11, 0.11]:
			K.cy(calf_pod, 0.065, 0.10, M_GUN, Vector3(nz_x, -0.18, 0.04), Vector3(-20, 0, 0), 0.05, 12)
			K.barrel_bore(calf_pod, 0.062, 0.044, Vector3(nz_x, -0.23, 0.06), 0.04, Vector3(160, 0, 0))
		A.hose(leg, Vector3(side * 0.16, -0.16, 0.26), KN + Vector3(side * 0.16, -0.20, 0.22), Vector3(side * 0.06, 0, 0.16), 0.028)

		# 踝 + 宽大矩形平底装甲战靴（Sabaton：斜切防弹鞋头 + 橡胶防滑大底 + 液压驻退后跟铲）
		var aj := K.node(kj, AN - KN, Vector3.ZERO, "Ankle")
		K.actuator(aj, Vector3.ZERO, 0.18, 0.42)
		var ft := K.node(aj, Vector3(0, -1.54, -0.04) - AN)
		K.bb(ft, Vector3(0.54, 0.20, 0.76), M_BARE, Vector3(0, 0.02, -0.04), Vector3.ZERO, 0.045)
		K.plate(ft, K.trap(0.52, 0.40, 0.44, 0.06), 0.18, M_LEG, Vector3(0, 0.13, -0.22), Vector3(-68, 0, 0), 0.032)
		K.plate(ft, K.trap(0.50, 0.44, 0.26, 0.04), 0.14, M_LEG2, Vector3(0, 0.02, -0.44), Vector3(-24, 0, 0), 0.025)
		K.bb(ft, Vector3(0.58, 0.05, 0.82), A.rubber(), Vector3(0, -0.095, -0.04), Vector3.ZERO, 0.015)
		# 后跟液压驻锄铲
		K.plate(ft, K.trap(0.46, 0.38, 0.22, 0.04), 0.10, M_GUN, Vector3(0, 0.0, 0.38), Vector3(24, 0, 0), 0.02)
		K.piston(ft, Vector3(-0.15, 0.16, 0.18), Vector3(-0.15, 0.02, 0.36), 0.026)
		K.piston(ft, Vector3(0.15, 0.16, 0.18), Vector3(0.15, 0.02, 0.36), 0.026)
		leg.set_meta("knee", kj)
		leg.set_meta("ankle", aj)
		leg.set_meta("KN", KN)
		leg.set_meta("AN", AN)
		leg.set_meta("sole", -1.54 - 0.12 - hip)
		leg_parts.append(leg)

	# 装甲腰柱（顶接 HP-C1 母座 hip+0.55）
	K.cy(root, 0.52, 0.42, M_FRAME, Vector3(0, hip + 0.32, 0), Vector3.ZERO, 0.56, 26)
	K.cy(root, 0.54, 0.10, M_DARK, Vector3(0, hip + 0.49, 0), Vector3.ZERO, 0.56, 26)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		A.hose(root, Vector3(cos(a) * 0.48, hip + 0.22, sin(a) * 0.48), Vector3(cos(a) * 0.42, hip + 0.48, sin(a) * 0.42), Vector3(cos(a) * 0.07, 0, sin(a) * 0.07), 0.022)
	K.socket(root, "core", Vector3(0, hip + 0.55, 0), Vector3.UP)
	root.set_meta("leg_parts", leg_parts)
	root.set_meta("leg_type", "biped")
	return root
