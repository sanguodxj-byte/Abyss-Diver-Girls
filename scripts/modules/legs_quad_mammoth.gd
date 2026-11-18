extends RefCounted
## 巨象支腿四足底盘 MM-10：重工龙门桁架承重平台、四角防撞警示块、四根垂直双缸液压打桩立柱腿与八角调平驻锄巨足
## 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var id: String = ctx.id
	var c: Color = ctx.color
	var serial: String = ctx.get("serial", "10")
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var M_GUN := K.gunmetal()
	var M_ACC := K.accent()
	var root := K.module_root("legs", id, Vector3.ZERO)
	var legs := root
	var M_LEG := K.armor(c, 0.52)
	var M_LEG2 := K.armor_sub(c, 0.56)
	var leg_parts: Array = []
	var hip := 1.52

	# ---- 重工铆接箱梁龙门甲板 + 腹下双联高压油箱 + 巨型八筋炮塔座圈（顶接 hip+0.56 = 2.08） ----
	K.bb(legs, Vector3(1.56, 0.52, 1.64), M_FRAME, Vector3(0, hip, 0.0), Vector3.ZERO, 0.06)
	K.plate(legs, K.crect(1.74, 1.82, [0.24, 0.24, 0.24, 0.24]), 0.24, M_LEG, Vector3(0, hip + 0.20, 0.0), Vector3(90, 0, 0), 0.04)
	# 腹下重型液压油箱群与防护笼
	for sx in [-0.34, 0.34]:
		K.cy(legs, 0.16, 1.12, M_LEG2, Vector3(sx, hip - 0.30, 0.0), Vector3(90, 0, 0), -1.0, 16)
		K.cy(legs, 0.17, 0.04, M_DARK, Vector3(sx, hip - 0.30, -0.34), Vector3(90, 0, 0), -1.0, 16)
		K.cy(legs, 0.17, 0.04, M_DARK, Vector3(sx, hip - 0.30, 0.34), Vector3(90, 0, 0), -1.0, 16)
	# 平台侧面检修扶手栏杆与防撞警示涂装
	for sx in [-0.88, 0.88]:
		var side_m: float = sign(sx)
		K.grab_iron(legs, 0.72, 0.07, Vector3(sx, hip + 0.26, 0.0), Vector3(0, side_m * -90.0, 0), 0.016)
		K.plate(legs, K.crect(0.84, 0.07), 0.06, M_ACC, Vector3(sx, hip + 0.06, 0.0), Vector3(0, 90, 0), 0.006)
	K.cy(legs, 0.64, 0.28, M_LEG2, Vector3(0, hip + 0.38, 0.0), Vector3.ZERO, 0.76, 28)
	K.cy(legs, 0.60, 0.10, M_DARK, Vector3(0, hip + 0.50, 0.0), Vector3.ZERO, 0.62, 28)
	for i in 8:
		var ga := TAU * i / 8.0
		K.bb(legs, Vector3(0.06, 0.24, 0.20), M_GUN, Vector3(cos(ga) * 0.66, hip + 0.36, sin(ga) * 0.66), Vector3(0, -rad_to_deg(ga), 0), 0.01)

	# 车首重工探照灯组 + 牵引耳座 + 车尾大型散热风机格栅
	for sx in [-0.42, 0.42]:
		K.bb(legs, Vector3(0.20, 0.12, 0.12), M_DARK, Vector3(sx, hip + 0.08, -0.92), Vector3.ZERO, 0.015)
		A.lens(legs, Vector3(sx, hip + 0.08, -0.98), Vector3(-90, 0, 0), 0.032, Color(1.0, 0.92, 0.74), 2.4)
		A.add(legs, A.torus(0.036, 0.068, 12), M_GUN, Vector3(sx, hip - 0.12, -0.94), Vector3(0, 0, 90), Vector3.ONE, false)
	A.vent(legs, Vector3(0.84, 0.28, 0.06), Vector3(0, hip + 0.04, 0.92), Vector3(0, 180, 0), 6)
	A.stencil(legs, "MM-" + serial, Vector3(0, hip + 0.20, -0.92), Vector3(0, 180, 0), 0.0028, Color(0.95, 0.93, 0.86, 0.86))

	# ---- 四根巨象级悬臂套筒打桩液压立柱腿（短壮水平悬臂肩 + 垂直粗壮双缸套筒立柱 + 八角重型驻锄圆盘足） ----
	for p in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var leg := Node3D.new()
		leg.position = Vector3(p.x * 0.68, hip + 0.02, p.y * 0.68)
		leg.rotation.y = atan2(p.x, p.y)
		legs.add_child(leg)
		var H := Vector3.ZERO
		var KN := Vector3(0, 0.10, 0.74)
		var FT := Vector3(0, -(hip + 0.02) + 0.06, 0.90)

		# 重工回转肩座法兰鼓
		K.cy(leg, 0.26, 0.42, M_DARK, Vector3(0, 0.0, 0.04), Vector3.ZERO, 0.28, 20)
		K.bolt_ring(leg, 0.21, 8, 0.016, Vector3(0, 0.215, 0.04), Vector3.ZERO)

		# 水平粗壮悬臂梁枢轴（H -> KN）+ 顶部斜拉液压油缸
		var fm := K.node(leg, H, Vector3.ZERO, "Femur")
		var up := K.bone(fm, H, KN)
		var l1 := H.distance_to(KN)
		K.bb(up, Vector3(0.42, l1 * 0.96, 0.36), M_LEG2, Vector3(0, -l1 * 0.5, 0.0), Vector3.ZERO, 0.04)
		K.plate(up, K.crect(0.46, l1 * 0.82, [0.06, 0.06, 0.06, 0.06]), 0.12, M_LEG, Vector3(0, -l1 * 0.5, 0.18), Vector3.ZERO, 0.025)
		K.plate(up, K.crect(0.38, 0.065), 0.13, M_ACC, Vector3(0, -l1 * 0.5, 0.19), Vector3.ZERO, 0.005)
		K.piston(fm, Vector3(0, 0.22, 0.12), KN + Vector3(0, 0.24, -0.06), 0.044)

		# 柱顶方形套筒耳轴箱（KN）+ 顶部高压油封端盖
		K.bb(fm, Vector3(0.48, 0.42, 0.48), M_GUN, KN + Vector3(0, 0.04, 0.02), Vector3.ZERO, 0.04)
		for cx_p in [-0.13, 0.13]:
			K.cy(fm, 0.075, 0.16, K.brass(), KN + Vector3(cx_p, 0.28, 0.02), Vector3.ZERO, -1.0, 12)

		# 垂直重型套筒液压打桩柱枢轴（KN -> FT）：上段厚装甲导套 + 下段双粗镀铬主油缸杆 + 侧面防撞护板
		var kj := K.node(fm, KN, Vector3.ZERO, "Knee")
		var lo := K.bone(kj, Vector3.ZERO, FT - KN)
		var l2 := KN.distance_to(FT)
		K.bb(lo, Vector3(0.46, l2 * 0.56, 0.44), M_LEG, Vector3(0, -l2 * 0.28, 0.0), Vector3.ZERO, 0.045)
		A.rivets(lo, Vector3(0.24, -0.12, 0.14), Vector3(0.24, -l2 * 0.52, 0.14), 4, 0.018, Vector3(0, 0, 90))
		K.grab_iron(lo, 0.22, 0.045, Vector3(0, -l2 * 0.26, 0.23), Vector3(180, 0, 0), 0.014)
		# 下段双并联巨型镀铬液压主柱塞 + 中央导向齿条梁
		K.bb(lo, Vector3(0.16, l2 * 0.90, 0.20), M_FRAME, Vector3(0, -l2 * 0.50, 0.0), Vector3.ZERO, 0.02)
		for cx_r in [-0.13, 0.13]:
			K.cy(lo, 0.068, l2 * 0.88, A.chrome(), Vector3(cx_r, -l2 * 0.52, 0.04), Vector3.ZERO, -1.0, 14)
			K.cy(lo, 0.088, 0.06, K.brass(), Vector3(cx_r, -l2 * 0.56, 0.04), Vector3.ZERO, -1.0, 14)
		A.hose(kj, Vector3(0.20, 0.06, -0.40), Vector3(0.22, -0.36, 0.10), Vector3(0.10, 0.06, 0.10), 0.028)

		# 踝枢轴与八角重型工程调平驻锄圆盘巨足 + 四向钢制抓地齿块
		var aj := K.node(kj, FT - KN, Vector3.ZERO, "Ankle")
		var pad := K.node(aj, Vector3(0, 0.02, 0))
		K.cy(pad, 0.18, 0.14, M_DARK, Vector3(0, 0.08, 0), Vector3.ZERO, 0.22, 16)
		K.plate(pad, K.crect(0.62, 0.62, [0.16, 0.16, 0.16, 0.16]), 0.09, M_LEG2, Vector3(0, 0.01, 0), Vector3(90, 0, 0), 0.022)
		K.cy(pad, 0.31, 0.05, A.rubber(), Vector3(0, -0.055, 0), Vector3.ZERO, 0.33, 18)
		for ci in 4:
			var ca := ci * 90.0 + 45.0
			var cl := K.node(pad, Vector3.ZERO, Vector3(0, ca, 0))
			K.bb(cl, Vector3(0.12, 0.08, 0.16), M_GUN, Vector3(0, -0.01, 0.28), Vector3(16, 0, 0), 0.012)
		leg.set_meta("femur", fm)
		leg.set_meta("knee", kj)
		leg.set_meta("ankle", aj)
		leg.set_meta("KN", KN)
		leg.set_meta("AN", FT)
		leg.set_meta("base_yaw", leg.rotation.y)
		leg_parts.append(leg)

	K.socket(root, "core", Vector3(0, hip + 0.56, 0), Vector3.UP)
	root.set_meta("leg_parts", leg_parts)
	root.set_meta("leg_type", "quad")
	return root
