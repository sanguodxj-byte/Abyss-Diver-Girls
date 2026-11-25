extends RefCounted
## 重甲堡垒四足底盘 CR-6：低矮宽体六边形暗堡车壳、前置钢缆绞盘、四扇弧面重型防爆盾甲蟹足（带ERA反应装甲块）
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
	var M_LEG := K.armor(c, 0.52)
	var M_LEG2 := K.armor_sub(c, 0.56)
	var leg_parts: Array = []
	var hip := 1.24

	# ---- 低矮宽体六边形重装暗堡车壳 + 顶部下沉式防弹领圈（顶接 hip+0.54 = 1.78） ----
	K.bb(legs, Vector3(1.52, 0.46, 1.44), M_FRAME, Vector3(0, hip, 0.0), Vector3.ZERO, 0.06)
	K.plate(legs, K.crect(1.78, 1.66, [0.44, 0.44, 0.40, 0.40]), 0.28, M_LEG, Vector3(0, hip + 0.16, 0.0), Vector3(90, 0, 0), 0.048)
	K.plate(legs, K.crect(1.42, 1.34, [0.32, 0.32, 0.32, 0.32]), 0.22, M_LEG2, Vector3(0, hip - 0.15, 0.0), Vector3(90, 0, 0), 0.04)
	K.cy(legs, 0.40, 0.24, M_LEG2, Vector3(0, hip + 0.36, 0.0), Vector3.ZERO, 0.54, 26)
	K.cy(legs, 0.36, 0.09, M_DARK, Vector3(0, hip + 0.48, 0.0), Vector3.ZERO, 0.42, 28)
	K.bolt_ring(legs, 0.56, 14, 0.015, Vector3(0, hip + 0.30, 0.0), Vector3.ZERO)

	# 车首重型液压钢缆绞盘鼓 + 潜望观察缝 + 左右斜颊 ERA 反应装甲砖
	K.bb(legs, Vector3(0.62, 0.26, 0.22), M_DARK, Vector3(0, hip - 0.02, -0.84), Vector3.ZERO, 0.02)
	K.cy(legs, 0.10, 0.44, K.copper(), Vector3(0, hip - 0.02, -0.88), Vector3(0, 0, 90), -1.0, 14)
	A.add(legs, A.torus(0.036, 0.068, 12), M_GUN, Vector3(0, hip - 0.02, -0.99), Vector3(0, 0, 90), Vector3.ONE, false)
	K.periscope(legs, 0.28, 0.08, Vector3(0, hip + 0.20, -0.80), Vector3.ZERO)
	for sx in [-0.52, 0.52]:
		var side_c: float = sign(sx)
		K.era_block(legs, Vector3(0.34, 0.20, 0.08), M_LEG2, Vector3(sx, hip + 0.10, -0.78), Vector3(-18, side_c * -28.0, 0))
		A.lens(legs, Vector3(sx * 0.72, hip + 0.14, -0.86), Vector3(-90, 0, 0), 0.026, Color(1.0, 0.90, 0.72), 2.0)
	A.vent(legs, Vector3(0.76, 0.24, 0.05), Vector3(0, hip + 0.04, 0.84), Vector3(0, 180, 0), 6)

	# ---- 四扇重装防爆盾甲蟹足（外覆超大宽幅曲折装甲盾壳 + 反应装甲砖 + 重型破岩锚爪） ----
	for p in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var leg := Node3D.new()
		leg.position = Vector3(p.x * 0.68, hip, p.y * 0.56)
		leg.rotation.y = atan2(p.x, p.y * 0.82)
		legs.add_child(leg)
		var H := Vector3.ZERO
		var KN := Vector3(0, 0.36, 0.96)
		var FT := Vector3(0, -hip + 0.05, 1.44)

		# 重型耳轴护罩基节
		K.cy(leg, 0.25, 0.36, M_DARK, Vector3(0, 0.0, 0.06), Vector3.ZERO, 0.27, 18)
		K.plate(leg, K.trap(0.46, 0.38, 0.26, 0.04), 0.14, M_LEG2, Vector3(0, 0.18, 0.10), Vector3(90, 0, 0), 0.025)
		K.actuator(leg, Vector3(0, 0.02, 0.18), 0.17, 0.40)

		# 粗短股节枢轴（H -> KN）：箱式承力梁 + 厚甲背壳 + 双粗液压缸
		var fm := K.node(leg, H, Vector3.ZERO, "Femur")
		var up := K.bone(fm, H, KN)
		var l1 := H.distance_to(KN)
		K.bb(up, Vector3(0.32, l1 * 0.92, 0.28), M_FRAME, Vector3(0, -l1 * 0.5, 0.0), Vector3.ZERO, 0.03)
		K.plate(up, K.trap(0.38, 0.48, l1 * 0.88, 0.06), 0.22, M_LEG, Vector3(0, -l1 * 0.48, 0.14), Vector3.ZERO, 0.035)
		for sx_p in [-0.14, 0.14]:
			K.piston(fm, Vector3(sx_p, -0.14, 0.16), Vector3(sx_p, 0.18, 0.84), 0.034)

		# 膝部重型铰接鼓
		K.actuator(fm, KN, 0.20, 0.44)

		# 胫节枢轴（KN -> FT）：外挂超宽攻城防爆盾板
		var kj := K.node(fm, KN, Vector3.ZERO, "Knee")
		var lo := K.bone(kj, Vector3.ZERO, FT - KN)
		var l2 := KN.distance_to(FT)
		K.bb(lo, Vector3(0.28, l2 * 0.90, 0.26), M_FRAME, Vector3(0, -l2 * 0.46, -0.03), Vector3.ZERO, 0.03)
		# 外侧巨型多面折角防爆盾板 + ERA 反应装甲块 + 维修抓手
		var shd := K.node(lo, Vector3(0, -l2 * 0.42, 0.16), Vector3(4, 0, 0))
		K.plate(shd, K.trap(0.38, 0.62, l2 * 0.92, 0.08), 0.18, M_LEG, Vector3.ZERO, Vector3.ZERO, 0.038)
		for side_w in [-1.0, 1.0]:
			K.plate(shd, K.trap(0.16, 0.24, l2 * 0.80, 0.04), 0.12, M_LEG2, Vector3(side_w * 0.28, 0.02, -0.06), Vector3(0, side_w * 28.0, 0), 0.025)
		K.era_block(shd, Vector3(0.38, 0.22, 0.075), M_LEG2, Vector3(0, 0.22, 0.11), Vector3(0, 180, 0))
		K.plate(shd, K.crect(0.44, 0.055), 0.19, M_ACC, Vector3(0, -0.18, 0.01), Vector3.ZERO, 0.005)
		if p.y < 0.0:
			A.stencil(shd, "CR-" + serial, Vector3(0, -0.02, 0.098), Vector3.ZERO, 0.0030, Color(0.95, 0.93, 0.86, 0.88))
		K.grab_iron(shd, 0.24, 0.045, Vector3(0, 0.42, 0.08), Vector3(180, 0, 0), 0.014)
		K.piston(kj, Vector3(0, -0.12, -0.12), (FT - KN) * 0.65 + Vector3(0, 0, -0.10), 0.042)
		A.hose(kj, Vector3(0.16, -0.10, -0.32), Vector3(0.16, -0.44, 0.06), Vector3(0.08, 0.04, 0.14), 0.026)

		# 踝枢轴与重型破岩三叉锚定蟹爪足垫
		var aj := K.node(kj, FT - KN, Vector3.ZERO, "Ankle")
		var pad := K.node(aj, Vector3(0, 0.03, 0))
		K.cy(pad, 0.16, 0.11, M_GUN, Vector3(0, 0.06, 0), Vector3.ZERO, 0.20, 14)
		K.cy(pad, 0.24, 0.055, A.rubber(), Vector3(0, -0.012, 0), Vector3.ZERO, 0.26, 16)
		for ca in [-42.0, 42.0, 180.0]:
			var cl := K.node(pad, Vector3.ZERO, Vector3(0, ca, 0))
			K.plate(cl, K.trap(0.14, 0.08, 0.20, 0.015), 0.10, M_DARK, Vector3(0, 0.01, 0.21), Vector3(76, 0, 0), 0.015)
			K.bb(cl, Vector3(0.13, 0.032, 0.18), A.rubber(), Vector3(0, -0.025, 0.21), Vector3.ZERO, 0.008)
		leg.set_meta("femur", fm)
		leg.set_meta("knee", kj)
		leg.set_meta("ankle", aj)
		leg.set_meta("KN", KN)
		leg.set_meta("AN", FT)
		leg.set_meta("base_yaw", leg.rotation.y)
		leg_parts.append(leg)

	K.socket(root, "core", Vector3(0, hip + 0.54, 0), Vector3.UP)
	root.set_meta("leg_parts", leg_parts)
	root.set_meta("leg_type", "quad")
	return root
