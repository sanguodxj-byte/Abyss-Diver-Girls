extends RefCounted
## 重型攻坚履带底盘 KV-6：前置V型液压破障推土铲、全车体ERA爆炸反应装甲砖、六负重轮宽履带、立式装甲排烟囱
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
	var M_TRACK := A.metal(Color(0.15, 0.15, 0.145))
	var leg_parts: Array = []
	var hip := 1.13

	# 宽体工程破障坦克底盘 + 八筋加强炮塔座圈（顶接 hip+0.55 = 1.68）
	K.bb(legs, Vector3(1.36, 0.62, 2.24), M_FRAME, Vector3(0, 0.76, 0.04), Vector3.ZERO, 0.055)
	K.plate(legs, K.crect(2.32, 0.40, [0.36, 0.16, 0.08, 0.14]), 1.42, M_LEG, Vector3(0, 1.10, 0.04), Vector3(0, 90, 0), 0.045)
	K.plate(legs, K.crect(1.34, 1.44, [0.30, 0.30, 0.28, 0.28]), 0.26, M_LEG2, Vector3(0, 1.34, 0.02), Vector3(90, 0, 0), 0.042)
	K.cy(legs, 0.58, 0.24, M_LEG, Vector3(0, 1.50, 0.0), Vector3.ZERO, 0.68, 26)
	K.cy(legs, 0.56, 0.10, M_DARK, Vector3(0, 1.62, 0.0), Vector3.ZERO, 0.58, 28)
	for i in 8:
		var ga := TAU * i / 8.0
		K.bb(legs, Vector3(0.055, 0.20, 0.18), M_GUN, Vector3(cos(ga) * 0.62, 1.46, sin(ga) * 0.62), Vector3(0, -rad_to_deg(ga), 0), 0.008)

	# 首上倾斜装甲（向上后倾 +44°）+ 6块 Kontakt 重型爆炸反应装甲砖（ERA 贴合坡面朝上迎弹）+ 双潜望镜 + 笼式防爆大灯
	var glacis := K.node(legs, Vector3(0, 0.98, -1.06), Vector3(44, 0, 0))
	K.plate(glacis, K.trap(1.38, 1.24, 0.56, 0.08), 0.16, M_LEG2, Vector3.ZERO, Vector3.ZERO, 0.038)
	for ex in [-0.38, 0.0, 0.38]:
		K.era_block(glacis, Vector3(0.34, 0.20, 0.075), M_LEG, Vector3(ex, 0.11, -0.115))
		K.era_block(glacis, Vector3(0.34, 0.18, 0.075), M_LEG2, Vector3(ex, -0.11, -0.115))
	for sx in [-0.26, 0.26]:
		K.periscope(legs, 0.18, 0.08, Vector3(sx, 1.32, -0.74), Vector3.ZERO)
	for sx in [-0.52, 0.52]:
		K.bb(legs, Vector3(0.18, 0.11, 0.11), M_DARK, Vector3(sx, 1.14, -1.12), Vector3.ZERO, 0.015)
		A.lens(legs, Vector3(sx, 1.14, -1.175), Vector3(-90, 0, 0), 0.032, Color(1.0, 0.90, 0.72), 2.2)
		K.grab_iron(legs, 0.20, 0.06, Vector3(sx, 1.14, -1.14), Vector3.ZERO, 0.011)

	# ---- 标志性前置 V 型重型液压破障/扫雷推土铲 ----
	var dozer := K.node(legs, Vector3(0, 0.0, -1.48))
	for sx in [-1.0, 1.0]:
		var wing := K.node(dozer, Vector3(sx * 0.56, 0.36, 0.08), Vector3(8, -sx * 16.0, 0))
		K.plate(wing, K.trap(1.18, 1.14, 0.54, 0.05), 0.11, M_LEG, Vector3.ZERO, Vector3.ZERO, 0.025)
		K.bb(wing, Vector3(1.18, 0.08, 0.13), M_GUN, Vector3(0, -0.26, -0.03), Vector3(22, 0, 0), 0.012)
		K.plate(wing, K.crect(1.06, 0.06), 0.12, M_ACC, Vector3(0, 0.18, -0.01), Vector3.ZERO, 0.006)
		if sx > 0.0:
			A.stencil(wing, "KV-" + serial, Vector3(-0.22, 0.0, -0.064), Vector3(0, 180, 0), 0.0028, Color(0.95, 0.93, 0.86, 0.88))
		for ti in 4:
			var tx := -0.42 + ti * 0.28
			K.bb(wing, Vector3(0.09, 0.14, 0.16), M_DARK, Vector3(tx, -0.28, -0.09), Vector3(32, 0, 0), 0.01)
		# 后方加强肋板
		for rx in [-0.36, 0.0, 0.36]:
			K.bb(wing, Vector3(0.06, 0.44, 0.20), M_FRAME, Vector3(rx, -0.02, 0.12), Vector3.ZERO, 0.01)
	# 中央分土脊 + 上沿防溢格栅 + 下推力臂与双液压举升油缸
	K.bb(dozer, Vector3(0.16, 0.56, 0.20), M_GUN, Vector3(0, 0.36, -0.06), Vector3(8, 0, 0), 0.02)
	K.holes(dozer, Vector3(0, 0.66, 0.02), Vector3(0, 180, 0), 6, 1, 0.16, 0.022)
	for sx in [-0.46, 0.46]:
		K.bb(legs, Vector3(0.14, 0.14, 0.62), M_FRAME, Vector3(sx, 0.30, -1.18), Vector3(6, 0, 0), 0.018)
		K.piston(legs, Vector3(sx, 0.86, -1.08), Vector3(sx, 0.44, -1.42), 0.042)

	# 车尾重装甲散热百叶 + 双立式装甲防弹排烟囱 + 备用履带节挂架
	A.vent(legs, Vector3(0.88, 0.32, 0.06), Vector3(0, 0.94, 1.18), Vector3(0, 180, 0), 6)
	for sx in [-0.42, 0.42]:
		K.cy(legs, 0.11, 0.56, M_DARK, Vector3(sx, 1.32, 1.14), Vector3.ZERO, 0.12, 14)
		K.cy(legs, 0.135, 0.32, M_GUN, Vector3(sx, 1.28, 1.14), Vector3.ZERO, -1.0, 14)
		K.holes(legs, Vector3(sx, 1.28, 1.28), Vector3(0, 180, 0), 2, 3, 0.06, 0.015)
		K.barrel_bore(legs, 0.105, 0.075, Vector3(sx, 1.60, 1.14), 0.07, Vector3.ZERO)

	# 左右超宽攻坚履带总成（6对负重轮 + 全长重型裙甲 + 外挂ERA反应装甲砖）
	for sx in [-0.98, 0.98]:
		var side: float = sign(sx)
		var tr := Node3D.new()
		tr.position = Vector3(sx, 0, 0.04)
		legs.add_child(tr)

		var straight := 2.34
		var r_arc := 0.35
		K.bb(tr, Vector3(0.64, 0.055, straight + 0.06), A.rubber(), Vector3(0, 0.75, 0), Vector3.ZERO, 0.01)
		K.bb(tr, Vector3(0.64, 0.055, straight + 0.06), A.rubber(), Vector3(0, 0.07, 0), Vector3.ZERO, 0.01)
		for ez in [-straight * 0.5, straight * 0.5]:
			K.cy(tr, 0.33, 0.64, A.rubber(), Vector3(0, 0.41, ez), Vector3(0, 0, 90), -1.0, 20)

		var links := 42
		var per := 2.0 * straight + TAU * r_arc
		for i in links:
			var d := (float(i) / float(links)) * per
			var pos: Vector3
			var ang := 0.0
			if d < straight:
				pos = Vector3(0, 0.76, -straight * 0.5 + d); ang = 0.0
			elif d < straight + PI * r_arc:
				var a := (d - straight) / r_arc
				pos = Vector3(0, 0.41 + cos(a) * r_arc, straight * 0.5 + sin(a) * r_arc); ang = -rad_to_deg(a)
			elif d < 2.0 * straight + PI * r_arc:
				pos = Vector3(0, 0.06, straight * 0.5 - (d - straight - PI * r_arc)); ang = 180.0
			else:
				var a := (d - 2.0 * straight - PI * r_arc) / r_arc
				pos = Vector3(0, 0.41 - cos(a) * r_arc, -straight * 0.5 - sin(a) * r_arc); ang = 180.0 - rad_to_deg(a)
			var shoe := K.node(tr, pos, Vector3(ang, 0, 0))
			K.bb(shoe, Vector3(0.70, 0.052, 0.16), M_TRACK, Vector3.ZERO, Vector3.ZERO, 0.01)
			K.bb(shoe, Vector3(0.66, 0.030, 0.05), M_GUN, Vector3(0, 0.034, 0), Vector3.ZERO, 0.005)

		for ez in [-1.17, 1.17]:
			K.cy(tr, 0.30, 0.54, M_DARK, Vector3(0, 0.42, ez), Vector3(0, 0, 90), -1.0, 20)
			K.cy(tr, 0.14, 0.62, M_GUN, Vector3(0, 0.42, ez), Vector3(0, 0, 90), -1.0, 12)
			K.bolt_ring(tr, 0.20, 8, 0.016, Vector3(side * 0.28, 0.42, ez), Vector3(0, 0, -side * 90.0))

		for wi in 6:
			var wz := -0.85 + wi * 0.34
			for wx in [-0.16, 0.16]:
				K.cy(tr, 0.20, 0.17, M_DARK, Vector3(wx, 0.27, wz), Vector3(0, 0, 90), -1.0, 16)
				K.cy(tr, 0.135, 0.18, M_LEG2, Vector3(wx, 0.27, wz), Vector3(0, 0, 90), -1.0, 14)
			K.cy(tr, 0.075, 0.58, A.chrome(), Vector3(0, 0.27, wz), Vector3(0, 0, 90), -1.0, 10)
		for rz in [-0.62, 0.0, 0.62]:
			K.cy(tr, 0.085, 0.48, M_DARK, Vector3(0, 0.64, rz), Vector3(0, 0, 90), -1.0, 12)

		# 重型全覆侧裙板 + 外挂 5 块 ERA 爆炸反应装甲砖
		K.plate(tr, K.crect(2.68, 0.09, [0.08, 0.08, 0.0, 0.0]), 0.80, M_LEG2, Vector3(side * 0.04, 0.90, 0), Vector3(0, 90, 0), 0.022)
		for k in 5:
			var sz := -0.96 + k * 0.48
			K.plate(tr, K.crect(0.46, 0.54, [0.04, 0.04, 0.06, 0.06]), 0.11, M_LEG if k % 2 == 0 else M_LEG2, Vector3(side * 0.41, 0.58, sz), Vector3(0, 90, 0), 0.025)
			if k < 4:
				K.era_block(tr, Vector3(0.40, 0.24, 0.075), M_LEG2 if k % 2 == 0 else M_LEG, Vector3(side * 0.48, 0.66, sz), Vector3(0, side * -90.0, 0))
		for fz in [-1.36, 1.36]:
			K.bb(tr, Vector3(0.74, 0.28, 0.055), A.rubber(), Vector3(side * 0.04, 0.72, fz), Vector3(fz * 12.0, 0, 0), 0.01)
		leg_parts.append(tr)

	K.socket(root, "core", Vector3(0, hip + 0.55, 0), Vector3.UP)
	root.set_meta("leg_parts", leg_parts)
	root.set_meta("leg_type", "tread")
	return root
