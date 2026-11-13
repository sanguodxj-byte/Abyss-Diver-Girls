extends RefCounted
## 履带底盘 Mole：分节履带板、负重轮、侧裙甲、斜装甲车体
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
	var M_LEG := K.armor(c, 0.48)
	var M_LEG2 := K.armor_sub(c, 0.52)
	var M_TRACK := A.metal(Color(0.16, 0.155, 0.15))
	var leg_parts: Array = []
	var hip := 1.05

	# 主战坦克底盘车体：大倾角首上/首下装甲 + 宽体炮塔座圈领口（消除车顶细圆管悬空感）+ 尾部动力散热百叶与副油箱
	K.bb(legs, Vector3(1.18, 0.56, 1.92), M_FRAME, Vector3(0, 0.72, 0.02), Vector3.ZERO, 0.05)
	K.plate(legs, K.crect(2.02, 0.36, [0.34, 0.14, 0.06, 0.12]), 1.24, M_LEG, Vector3(0, 1.04, 0.04), Vector3(0, 90, 0), 0.04)
	# 倾斜炮塔座圈基座（Barbette）：从 y=1.12 平顺过渡至 hip+0.55 (1.60)
	K.plate(legs, K.crect(1.18, 1.28, [0.28, 0.28, 0.24, 0.24]), 0.26, M_LEG2, Vector3(0, 1.28, 0.0), Vector3(90, 0, 0), 0.04)
	K.cy(legs, 0.54, 0.24, M_LEG, Vector3(0, 1.44, 0.0), Vector3.ZERO, 0.64, 26)
	K.cy(legs, 0.52, 0.08, M_DARK, Vector3(0, 1.56, 0.0), Vector3.ZERO, 0.54, 26)
	K.periscope(legs, 0.20, 0.08, Vector3(0, 1.25, -0.68), Vector3.ZERO)

	# 首上反应甲与防浪板 + 首下推土/防雷倾板 + 锻钢牵引钩
	K.plate(legs, K.trap(1.06, 1.22, 0.48, 0.08), 0.14, M_LEG2, Vector3(0, 0.84, -1.04), Vector3(-40, 0, 0), 0.035)
	K.plate(legs, K.trap(1.18, 1.00, 0.34, 0.06), 0.12, M_FRAME, Vector3(0, 0.50, -1.02), Vector3(36, 0, 0), 0.03)
	K.plate(legs, K.crect(0.07, 0.36), 0.15, M_ACC, Vector3(-0.40, 0.86, -1.05), Vector3(-40, 0, 0), 0.006)
	for sx in [-0.36, 0.36]:
		K.bb(legs, Vector3(0.18, 0.10, 0.10), M_DARK, Vector3(sx, 0.96, -1.10), Vector3.ZERO, 0.015)
		A.lens(legs, Vector3(sx, 0.96, -1.15), Vector3(-90, 0, 0), 0.030, Color(1.0, 0.92, 0.76), 2.2)
		K.bb(legs, Vector3(0.20, 0.016, 0.05), M_GUN, Vector3(sx, 1.015, -1.15), Vector3.ZERO, 0.004)
		A.add(legs, A.torus(0.035, 0.065, 12), M_GUN, Vector3(sx * 0.72, 0.58, -1.14), Vector3(0, 0, 90), Vector3.ONE, false)

	# 车尾百叶散热窗 + 外挂双联备用燃油桶
	A.vent(legs, Vector3(0.72, 0.28, 0.05), Vector3(0, 0.92, 1.05), Vector3(0, 180, 0), 5)
	for sx in [-0.34, 0.34]:
		K.cy(legs, 0.15, 0.48, M_LEG2, Vector3(sx, 1.12, 1.12), Vector3(0, 0, 90), -1.0, 16)
		for strap_x in [-0.14, 0.14]:
			K.cy(legs, 0.156, 0.025, M_DARK, Vector3(sx + strap_x, 1.12, 1.12), Vector3(0, 0, 90), -1.0, 16)

	# 左右重型履带总成：内衬连续橡胶带 + 38节啮合防滑钢履带 + 齿圈主动轮/诱导轮 + 双排负重轮与扭力臂 + 重装甲侧裙
	for sx in [-0.88, 0.88]:
		var side: float = sign(sx)
		var tr := Node3D.new()
		tr.position = Vector3(sx, 0, 0)
		legs.add_child(tr)

		# 连续履带内衬基带（彻底消除履带板之间的透光漏空感）
		K.bb(tr, Vector3(0.54, 0.05, 2.12), A.rubber(), Vector3(0, 0.71, 0), Vector3.ZERO, 0.01)
		K.bb(tr, Vector3(0.54, 0.05, 2.12), A.rubber(), Vector3(0, 0.07, 0), Vector3.ZERO, 0.01)
		for ez in [-1.04, 1.04]:
			K.cy(tr, 0.31, 0.54, A.rubber(), Vector3(0, 0.39, ez), Vector3(0, 0, 90), -1.0, 20)

		var links := 38
		var straight := 2.08
		var r_arc := 0.33
		var per := 2.0 * straight + TAU * r_arc
		for i in links:
			var d := (float(i) / float(links)) * per
			var pos: Vector3
			var ang := 0.0
			if d < straight:
				pos = Vector3(0, 0.72, -straight * 0.5 + d); ang = 0.0
			elif d < straight + PI * r_arc:
				var a := (d - straight) / r_arc
				pos = Vector3(0, 0.39 + cos(a) * r_arc, straight * 0.5 + sin(a) * r_arc); ang = -rad_to_deg(a)
			elif d < 2.0 * straight + PI * r_arc:
				pos = Vector3(0, 0.06, straight * 0.5 - (d - straight - PI * r_arc)); ang = 180.0
			else:
				var a := (d - 2.0 * straight - PI * r_arc) / r_arc
				pos = Vector3(0, 0.39 - cos(a) * r_arc, -straight * 0.5 - sin(a) * r_arc); ang = 180.0 - rad_to_deg(a)
			var shoe := K.node(tr, pos, Vector3(ang, 0, 0))
			K.bb(shoe, Vector3(0.60, 0.048, 0.155), M_TRACK, Vector3.ZERO, Vector3.ZERO, 0.010)
			K.bb(shoe, Vector3(0.56, 0.028, 0.045), M_GUN, Vector3(0, 0.032, 0), Vector3.ZERO, 0.005)

		# 前主动齿轮 + 后张紧诱导轮 + 4组双排负重轮 + 2组托带轮
		for ez in [-1.04, 1.04]:
			K.cy(tr, 0.28, 0.46, M_DARK, Vector3(0, 0.40, ez), Vector3(0, 0, 90), -1.0, 20)
			K.cy(tr, 0.12, 0.52, M_GUN, Vector3(0, 0.40, ez), Vector3(0, 0, 90), -1.0, 12)
			K.bolt_ring(tr, 0.18, 8, 0.015, Vector3(side * 0.24, 0.40, ez), Vector3(0, 0, -side * 90.0))
		for wz in [-0.63, -0.21, 0.21, 0.63]:
			for wx in [-0.14, 0.14]:
				K.cy(tr, 0.22, 0.16, M_DARK, Vector3(wx, 0.29, wz), Vector3(0, 0, 90), -1.0, 18)
				K.cy(tr, 0.15, 0.17, M_LEG2, Vector3(wx, 0.29, wz), Vector3(0, 0, 90), -1.0, 16)
			K.cy(tr, 0.08, 0.50, A.chrome(), Vector3(0, 0.29, wz), Vector3(0, 0, 90), -1.0, 10)
			# 扭力杆悬挂摆臂
			K.bb(tr, Vector3(0.10, 0.08, 0.26), M_FRAME, Vector3(-side * 0.22, 0.35, wz - 0.08), Vector3(24, 0, 0), 0.012)
		for rz in [-0.42, 0.42]:
			K.cy(tr, 0.085, 0.42, M_DARK, Vector3(0, 0.61, rz), Vector3(0, 0, 90), -1.0, 12)

		# 分段螺栓重装甲侧裙板 + 前后橡胶挡泥板 + 上翼子板工具箱
		for k in 4:
			var z := -0.84 + k * 0.56
			var cut := [0.16, 0.0, 0.06, 0.08] if k == 0 else ([0.0, 0.14, 0.08, 0.06] if k == 3 else [0.0, 0.0, 0.06, 0.06])
			K.plate(tr, K.crect(0.54, 0.46, cut), 0.10, M_LEG if k % 2 == 0 else M_LEG2, Vector3(side * 0.36, 0.58, z), Vector3(0, 90, 0), 0.025)
			for bz in [-0.18, 0.18]:
				K.cy(tr, 0.016, 0.025, A.chrome(), Vector3(side * 0.415, 0.74, z + bz), Vector3(0, 0, 90), -1.0, 6)
		K.plate(tr, K.crect(2.44, 0.08, [0.08, 0.08, 0.0, 0.0]), 0.70, M_LEG2, Vector3(side * 0.04, 0.84, 0), Vector3(0, 90, 0), 0.02)
		for fz in [-1.24, 1.24]:
			K.bb(tr, Vector3(0.66, 0.26, 0.05), A.rubber(), Vector3(side * 0.04, 0.68, fz), Vector3(fz * 14.0, 0, 0), 0.01)
		K.bb(tr, Vector3(0.30, 0.16, 0.56), M_LEG, Vector3(side * 0.14, 0.95, 0.36), Vector3.ZERO, 0.02)
		K.plate(tr, K.crect(0.48, 0.055), 0.11, M_ACC, Vector3(side * 0.42, 0.70, -0.82), Vector3(0, 90, 0), 0.005)
		A.stencil(tr, serial, Vector3(side * 0.42, 0.54, 0.28), Vector3(0, side * 90.0, 0), 0.0032, Color(0.95, 0.93, 0.88, 0.72), 64)
		leg_parts.append(tr)

	K.socket(root, "core", Vector3(0, hip + 0.55, 0), Vector3.UP)
	root.set_meta("leg_parts", leg_parts)
	root.set_meta("leg_type", "tread")
	return root
