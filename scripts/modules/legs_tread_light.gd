extends RefCounted
## 轻型高速履带底盘 MT-2：克里斯蒂大负重轮悬挂、楔形侦察车体、冲孔轻量化挡泥板、双置消音排气管
## 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var id: String = ctx.id
	var c: Color = ctx.color
	var serial: String = ctx.get("serial", "02")
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var M_GUN := K.gunmetal()
	var M_ACC := K.accent()
	var root := K.module_root("legs", id, Vector3.ZERO)
	var legs := root
	var M_LEG := K.armor(c, 0.42)
	var M_LEG2 := K.armor_sub(c, 0.46)
	var M_TRACK := A.metal(Color(0.17, 0.165, 0.16))
	var leg_parts: Array = []
	var hip := 0.95

	# 紧凑楔形侦察车体 + 倾斜首上/首下装甲 + 低矮回转座圈领口（无缝承托至 hip+0.55 = 1.50）
	K.bb(legs, Vector3(0.96, 0.48, 1.64), M_FRAME, Vector3(0, 0.66, 0.02), Vector3.ZERO, 0.045)
	K.plate(legs, K.crect(1.72, 0.30, [0.32, 0.14, 0.06, 0.10]), 1.02, M_LEG, Vector3(0, 0.94, 0.02), Vector3(0, 90, 0), 0.035)
	K.plate(legs, K.crect(1.02, 1.10, [0.22, 0.22, 0.20, 0.20]), 0.22, M_LEG2, Vector3(0, 1.16, 0.0), Vector3(90, 0, 0), 0.035)
	K.cy(legs, 0.50, 0.24, M_LEG, Vector3(0, 1.32, 0.0), Vector3.ZERO, 0.58, 24)
	K.cy(legs, 0.51, 0.10, M_DARK, Vector3(0, 1.44, 0.0), Vector3.ZERO, 0.53, 26)
	K.bolt_ring(legs, 0.46, 12, 0.015, Vector3(0, 1.26, 0.0), Vector3.ZERO)

	# 锐角侦察首上防弹板（向上后倾 +46°）+ 首下防雷倾板（-38°）+ 驾驶员广角潜望镜 + 防撞护栏与战术雾灯
	var prow := K.node(legs, Vector3(0, 0.80, -0.84), Vector3(46, 0, 0))
	K.plate(prow, K.trap(1.00, 0.88, 0.46, 0.06), 0.11, M_LEG, Vector3.ZERO, Vector3.ZERO, 0.03)
	A.stencil(prow, "MT-" + serial, Vector3(0.20, -0.02, -0.063), Vector3(0, 180, 0), 0.0024, Color(0.95, 0.93, 0.86, 0.86))
	K.plate(legs, K.trap(0.84, 0.98, 0.30, 0.05), 0.10, M_FRAME, Vector3(0, 0.50, -0.86), Vector3(-38, 0, 0), 0.025)
	K.periscope(legs, 0.24, 0.085, Vector3(0, 1.12, -0.58), Vector3.ZERO)
	K.grab_iron(legs, 0.68, 0.09, Vector3(0, 0.72, -0.98), Vector3.ZERO, 0.016)
	for sx in [-0.34, 0.34]:
		K.bb(legs, Vector3(0.15, 0.09, 0.09), M_DARK, Vector3(sx, 0.90, -0.90), Vector3.ZERO, 0.012)
		A.lens(legs, Vector3(sx, 0.90, -0.945), Vector3(-90, 0, 0), 0.028, Color(1.0, 0.94, 0.80), 2.2)
		A.add(legs, A.torus(0.030, 0.056, 12), M_GUN, Vector3(sx * 0.82, 0.54, -0.98), Vector3(0, 0, 90), Vector3.ONE, false)

	# 车尾高转速涡轮散热格栅 + 双纵置防烫护罩消音排气管（沿车尾两侧翼根纵向布置，尾口朝后）
	A.vent(legs, Vector3(0.60, 0.24, 0.04), Vector3(0, 0.84, 0.88), Vector3(0, 180, 0), 5)
	for sx in [-0.38, 0.38]:
		K.cy(legs, 0.075, 0.44, M_DARK, Vector3(sx, 1.00, 0.66), Vector3(90, 0, 0), -1.0, 14)
		K.cy(legs, 0.086, 0.28, M_GUN, Vector3(sx, 1.00, 0.64), Vector3(90, 0, 0), -1.0, 14)
		for sz_s in [0.52, 0.76]:
			K.cy(legs, 0.092, 0.024, M_FRAME, Vector3(sx, 1.00, sz_s), Vector3(90, 0, 0), -1.0, 14)
		K.cy(legs, 0.055, 0.10, M_GUN, Vector3(sx, 1.00, 0.91), Vector3(90, 0, 0), -1.0, 12)
		K.barrel_bore(legs, 0.054, 0.038, Vector3(sx, 1.00, 0.96), 0.05, Vector3(-90, 0, 0))

	# 左右高速挂胶履带总成：3组大直径克里斯蒂辐条负重轮 + 外露倾斜氮气弹簧减震筒 + 冲孔轻型翼子板
	for sx in [-0.74, 0.74]:
		var side: float = sign(sx)
		var tr := Node3D.new()
		tr.position = Vector3(sx, 0, 0)
		legs.add_child(tr)

		var straight := 1.68
		var r_arc := 0.28
		K.bb(tr, Vector3(0.40, 0.045, straight + 0.04), A.rubber(), Vector3(0, 0.61, 0), Vector3.ZERO, 0.008)
		K.bb(tr, Vector3(0.40, 0.045, straight + 0.04), A.rubber(), Vector3(0, 0.06, 0), Vector3.ZERO, 0.008)
		for ez in [-straight * 0.5, straight * 0.5]:
			K.cy(tr, 0.26, 0.40, A.rubber(), Vector3(0, 0.335, ez), Vector3(0, 0, 90), -1.0, 18)

		var links := 32
		var per := 2.0 * straight + TAU * r_arc
		for i in links:
			var d := (float(i) / float(links)) * per
			var pos: Vector3
			var ang := 0.0
			if d < straight:
				pos = Vector3(0, 0.615, -straight * 0.5 + d); ang = 0.0
			elif d < straight + PI * r_arc:
				var a := (d - straight) / r_arc
				pos = Vector3(0, 0.335 + cos(a) * r_arc, straight * 0.5 + sin(a) * r_arc); ang = -rad_to_deg(a)
			elif d < 2.0 * straight + PI * r_arc:
				pos = Vector3(0, 0.055, straight * 0.5 - (d - straight - PI * r_arc)); ang = 180.0
			else:
				var a := (d - 2.0 * straight - PI * r_arc) / r_arc
				pos = Vector3(0, 0.335 - cos(a) * r_arc, -straight * 0.5 - sin(a) * r_arc); ang = 180.0 - rad_to_deg(a)
			var shoe := K.node(tr, pos, Vector3(ang, 0, 0))
			K.bb(shoe, Vector3(0.44, 0.042, 0.14), M_TRACK, Vector3.ZERO, Vector3.ZERO, 0.008)
			K.bb(shoe, Vector3(0.38, 0.024, 0.05), A.rubber(), Vector3(0, 0.028, 0), Vector3.ZERO, 0.005)

		# 前后齿圈主动/诱导轮
		for ez in [-0.84, 0.84]:
			K.cy(tr, 0.23, 0.34, M_DARK, Vector3(0, 0.34, ez), Vector3(0, 0, 90), -1.0, 18)
			K.cy(tr, 0.10, 0.40, M_GUN, Vector3(0, 0.34, ez), Vector3(0, 0, 90), -1.0, 12)
			K.bolt_ring(tr, 0.15, 6, 0.013, Vector3(side * 0.18, 0.34, ez), Vector3(0, 0, -side * 90.0))

		# 3组大直径克里斯蒂高速负重轮 + 外露液压减震支柱
		for wz in [-0.50, 0.0, 0.50]:
			for wx in [-0.11, 0.11]:
				K.cy(tr, 0.245, 0.13, A.rubber(), Vector3(wx, 0.285, wz), Vector3(0, 0, 90), -1.0, 20)
				K.cy(tr, 0.185, 0.14, M_LEG, Vector3(wx, 0.285, wz), Vector3(0, 0, 90), -1.0, 18)
			K.cy(tr, 0.065, 0.38, A.chrome(), Vector3(0, 0.285, wz), Vector3(0, 0, 90), -1.0, 10)
			K.bolt_ring(tr, 0.12, 6, 0.012, Vector3(side * 0.185, 0.285, wz), Vector3(0, 0, -side * 90.0))
			K.piston(tr, Vector3(-side * 0.14, 0.68, wz - 0.10), Vector3(-side * 0.08, 0.31, wz), 0.024)

		# 轻型高翼子板 + 半截前护裙（下半部敞露展现高速负重轮机构）+ 随车工兵箱
		K.plate(tr, K.crect(2.02, 0.065, [0.10, 0.10, 0.0, 0.0]), 0.52, M_LEG2, Vector3(side * 0.02, 0.72, 0), Vector3(0, 90, 0), 0.018)
		K.plate(tr, K.trap(0.56, 0.42, 0.22, 0.04), 0.07, M_LEG, Vector3(side * 0.25, 0.62, -0.68), Vector3(0, 90, 0), 0.018)
		K.plate(tr, K.crect(0.36, 0.045), 0.08, M_ACC, Vector3(side * 0.26, 0.66, -0.68), Vector3(0, 90, 0), 0.005)
		K.holes(tr, Vector3(side * 0.29, 0.60, -0.68), Vector3(0, side * -90.0, 0), 3, 2, 0.06, 0.014)
		for fz in [-1.02, 1.02]:
			K.bb(tr, Vector3(0.48, 0.22, 0.04), A.rubber(), Vector3(side * 0.02, 0.58, fz), Vector3(fz * 18.0, 0, 0), 0.008)
		K.bb(tr, Vector3(0.22, 0.14, 0.48), M_LEG, Vector3(side * 0.08, 0.82, 0.28), Vector3.ZERO, 0.018)
		K.grab_iron(tr, 0.26, 0.035, Vector3(side * 0.20, 0.82, 0.28), Vector3(0, side * -90.0, 0), 0.012)
		leg_parts.append(tr)

	K.socket(root, "core", Vector3(0, hip + 0.55, 0), Vector3.UP)
	root.set_meta("leg_parts", leg_parts)
	root.set_meta("leg_type", "tread")
	return root
