extends RefCounted
## 四足底盘 Arachne：骨架 + 装甲 + 活塞的蜘蛛腿
## 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var id: String = ctx.id
	var c: Color = ctx.color
	var serial: String = ctx.get("serial", "00")
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var M_GUN := K.gunmetal()
	var M_ACC := K.accent()
	var root := K.module_root("legs", id, Vector3.ZERO)
	var legs := root
	var M_LEG := K.armor(c, 0.46)
	var M_LEG2 := K.armor_sub(c, 0.50)
	var leg_parts: Array = []
	var hip := 1.4

	# 中央八边形重工承力底盘 + 腹下液压分配箱 + 顶部锥台炮塔座圈（无缝衔接至 hip+0.55）
	K.bb(legs, Vector3(1.26, 0.44, 1.26), M_FRAME, Vector3(0, hip, 0), Vector3.ZERO, 0.06)
	K.plate(legs, K.crect(1.48, 1.48, [0.36, 0.36, 0.36, 0.36]), 0.24, M_LEG, Vector3(0, hip + 0.16, 0), Vector3(90, 0, 0), 0.045)
	K.plate(legs, K.crect(1.18, 1.18, [0.28, 0.28, 0.28, 0.28]), 0.22, M_LEG2, Vector3(0, hip - 0.14, 0), Vector3(90, 0, 0), 0.04)
	K.cy(legs, 0.54, 0.34, M_LEG2, Vector3(0, hip + 0.36, 0), Vector3.ZERO, 0.68, 24)
	K.cy(legs, 0.52, 0.10, M_DARK, Vector3(0, hip + 0.50, 0), Vector3.ZERO, 0.55, 26)
	for i in 8:
		var ga := TAU * i / 8.0
		K.bb(legs, Vector3(0.05, 0.22, 0.18), M_GUN, Vector3(cos(ga) * 0.58, hip + 0.34, sin(ga) * 0.58), Vector3(0, -rad_to_deg(ga), 0), 0.008)
	for sx in [-0.28, 0.28]:
		K.bb(legs, Vector3(0.15, 0.09, 0.09), M_DARK, Vector3(sx, hip + 0.06, -0.74), Vector3.ZERO, 0.012)
		A.lens(legs, Vector3(sx, hip + 0.06, -0.785), Vector3(-90, 0, 0), 0.026, Color(1.0, 0.94, 0.80), 2.0)
	A.vent(legs, Vector3(0.52, 0.22, 0.04), Vector3(0, hip + 0.06, 0.75), Vector3(0, 180, 0), 5)
	A.add(legs, A.torus(0.030, 0.056, 12), M_GUN, Vector3(0, hip - 0.04, -0.75), Vector3(0, 0, 90), Vector3.ONE, false)
	A.stencil(legs, "ARC-" + serial, Vector3(0, hip + 0.16, -0.752), Vector3(0, 180, 0), 0.0024, Color(0.94, 0.92, 0.84, 0.85))

	# 四足工程步进肢：重型基节回转鼓 + 双梁桁架大腿 + 悬臂装甲膝盖 + A字双撑胫骨 + 三趾液压驻锄足垫
	for p in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var leg := Node3D.new()
		leg.position = Vector3(p.x * 0.55, hip, p.y * 0.55)
		leg.rotation.y = atan2(p.x, p.y)
		legs.add_child(leg)
		var H := Vector3.ZERO
		var KN := Vector3(0, 0.44, 0.94)
		var FT := Vector3(0, -hip + 0.05, 1.36)

		# 基节回转轴承鼓 + 耳轴叉架
		K.cy(leg, 0.22, 0.32, M_DARK, Vector3(0, 0.0, 0.04), Vector3.ZERO, 0.24, 18)
		K.bolt_ring(leg, 0.18, 8, 0.014, Vector3(0, 0.165, 0.04), Vector3(0, 0, 0))
		K.actuator(leg, Vector3(0, 0.02, 0.16), 0.15, 0.34)

		# 股节（H -> KN）：双侧箱梁 + 顶部切角背甲 + 双液压推杆
		var up := K.bone(leg, H, KN)
		var l1 := H.distance_to(KN)
		for sx in [-0.11, 0.11]:
			K.bb(up, Vector3(0.08, l1 * 0.92, 0.18), M_FRAME, Vector3(sx, -l1 * 0.5, 0.0), Vector3.ZERO, 0.018)
		K.plate(up, K.trap(0.28, 0.38, l1 * 0.88, 0.05), 0.34, M_LEG, Vector3(0, -l1 * 0.50, 0.08), Vector3(0, 0, 0), 0.032)
		K.plate(up, K.crect(0.36, 0.06), 0.12, M_ACC, Vector3(0, -l1 * 0.35, 0.21), Vector3(0, 0, 0), 0.005)
		for sx in [-0.12, 0.12]:
			K.piston(leg, Vector3(sx, -0.12, 0.14), Vector3(sx, 0.24, 0.82), 0.028)

		# 膝关节重型油缸鼓 + 立体装甲护罩
		K.actuator(leg, KN, 0.17, 0.36)
		var kp := K.node(leg, KN + Vector3(0, 0.10, 0.12), Vector3(-28, 0, 0))
		K.plate(kp, K.trap(0.34, 0.24, 0.34, 0.05), 0.16, M_LEG, Vector3.ZERO, Vector3.ZERO, 0.03)
		K.grab_iron(kp, 0.18, 0.035, Vector3(0, 0.10, 0.08), Vector3(180, 0, 0))

		# 胫节（KN -> FT）：彻底告别单薄五边形纸片，采用双侧承重箱梁 + 外覆重型斜切胫甲 + 内侧减震连杆
		var lo := K.bone(leg, KN, FT)
		var l2 := KN.distance_to(FT)
		for sx in [-0.10, 0.10]:
			K.bb(lo, Vector3(0.085, l2 * 0.90, 0.20), M_FRAME, Vector3(sx, -l2 * 0.46, -0.02), Vector3(0, 0, sx * 2.2), 0.018)
		for rung_t in [0.28, 0.56, 0.80]:
			K.bb(lo, Vector3(0.24, 0.07, 0.14), M_GUN, Vector3(0, -l2 * rung_t, -0.02), Vector3.ZERO, 0.012)
		# 外向主装甲护盾 + 散热孔排
		K.plate(lo, K.trap(0.22, 0.38, l2 * 0.84, 0.06), 0.16, M_LEG, Vector3(0, -l2 * 0.44, 0.11), Vector3(3, 0, 0), 0.032)
		K.plate(lo, K.trap(0.16, 0.26, l2 * 0.52, 0.04), 0.10, M_LEG2, Vector3(0, -l2 * 0.32, 0.18), Vector3(3, 0, 0), 0.022)
		K.holes(lo, Vector3(0, -l2 * 0.26, 0.235), Vector3(3, 180, 0), 3, 2, 0.065, 0.016)
		for sx in [-0.15, 0.15]:
			K.plate(lo, K.trap(0.14, 0.24, l2 * 0.72, 0.04), 0.08, M_LEG2, Vector3(sx, -l2 * 0.44, 0.01), Vector3(0, 90, 0), 0.02)
		A.hose(leg, Vector3(0.13, 0.30, 0.62), KN + Vector3(0.13, -0.48, 0.08), Vector3(0.07, 0.04, 0.14), 0.024)
		K.piston(leg, KN + Vector3(0, -0.12, -0.10), KN + (FT - KN) * 0.62 + Vector3(0, 0, -0.08), 0.036)

		# 接地液压工程驻锄足掌（FT）：球铰踝座 + 宽幅圆盘橡胶减震底 + 前二后一抓地钢爪
		var pad := K.node(leg, FT + Vector3(0, 0.03, 0))
		K.cy(pad, 0.13, 0.10, M_GUN, Vector3(0, 0.06, 0), Vector3.ZERO, 0.16, 14)
		K.cy(pad, 0.20, 0.05, A.rubber(), Vector3(0, -0.01, 0), Vector3.ZERO, 0.22, 16)
		for ca in [-38.0, 38.0, 180.0]:
			var cl := K.node(pad, Vector3.ZERO, Vector3(0, ca, 0))
			K.bb(cl, Vector3(0.08, 0.06, 0.16), M_LEG2, Vector3(0, 0.01, 0.18), Vector3(14, 0, 0), 0.012)
			K.bb(cl, Vector3(0.085, 0.03, 0.14), A.rubber(), Vector3(0, -0.025, 0.19), Vector3.ZERO, 0.008)
		leg_parts.append(leg)

	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		A.hose(legs, Vector3(cos(a) * 0.48, hip + 0.22, sin(a) * 0.48), Vector3(cos(a) * 0.42, hip + 0.48, sin(a) * 0.42), Vector3(cos(a) * 0.07, 0, sin(a) * 0.07), 0.020)
	K.socket(root, "core", Vector3(0, hip + 0.55, 0), Vector3.UP)
	root.set_meta("leg_parts", leg_parts)
	root.set_meta("leg_type", "quad")
	return root
