extends RefCounted
## 重型甲虫六足底盘 BT-9：宽体大倾角防化重装甲背壳、前置双分叉破障撞角、侧悬耳轴护裙与ERA反应砖、六扇弧面重盾步足
## 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var id: String = ctx.id
	var c: Color = ctx.color
	var serial: String = ctx.get("serial", "09")
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var M_GUN := K.gunmetal()
	var M_ACC := K.accent()
	var root := K.module_root("legs", id, Vector3.ZERO)
	var legs := root
	var M_LEG := K.armor(c, 0.50)
	var M_LEG2 := K.armor_sub(c, 0.54)
	var leg_parts: Array = []
	var hip := 1.26

	# ---- 宽体三防全密封甲虫式重装甲车壳 + 侧伸基节遮蔽肩裙 + 顶部防爆座圈（顶接 hip+0.56 = 1.82） ----
	K.bb(legs, Vector3(1.38, 0.46, 2.24), M_FRAME, Vector3(0, hip, 0.0), Vector3.ZERO, 0.06)
	K.plate(legs, K.crect(1.66, 2.38, [0.42, 0.42, 0.36, 0.36]), 0.28, M_LEG, Vector3(0, hip + 0.18, 0.0), Vector3(90, 0, 0), 0.048)
	K.plate(legs, K.crect(1.30, 2.02, [0.30, 0.30, 0.30, 0.30]), 0.22, M_LEG2, Vector3(0, hip - 0.15, 0.0), Vector3(90, 0, 0), 0.04)
	# 左右外悬式装甲护檐（遮蔽六足髋轴承顶部，赋予重装兜虫甲壳轮廓）+ 外挂 ERA 反应装甲砖
	for sx in [-0.74, 0.74]:
		var side_b: float = sign(sx)
		K.plate(legs, K.trap(2.06, 1.78, 0.26, 0.06), 0.14, M_LEG2, Vector3(sx, hip + 0.14, 0.0), Vector3(0, side_b * 90.0, side_b * -24.0), 0.03)
		for ez in [-0.56, 0.0, 0.56]:
			K.era_block(legs, Vector3(0.42, 0.18, 0.07), M_LEG, Vector3(sx + side_b * 0.06, hip + 0.22, ez), Vector3(0, side_b * -90.0, -side_b * 24.0))
	K.cy(legs, 0.58, 0.28, M_LEG2, Vector3(0, hip + 0.36, 0.0), Vector3.ZERO, 0.72, 26)
	K.cy(legs, 0.55, 0.10, M_DARK, Vector3(0, hip + 0.50, 0.0), Vector3.ZERO, 0.58, 28)

	# 标志性前置双分叉破障撞角（独角仙/锹甲重工撞铲 + 铸钢铰接耳座）+ 防酸密封潜望窗
	var prow := K.node(legs, Vector3(0, hip + 0.08, -1.18), Vector3(38, 0, 0))
	K.plate(prow, K.trap(1.48, 1.24, 0.44, 0.08), 0.16, M_LEG, Vector3.ZERO, Vector3.ZERO, 0.038)
	A.stencil(prow, "BT-" + serial, Vector3(0, 0.02, -0.088), Vector3(0, 180, 0), 0.0027, Color(0.95, 0.93, 0.86, 0.88))
	K.periscope(legs, 0.28, 0.08, Vector3(0, hip + 0.26, -1.00), Vector3.ZERO)
	for sx in [-0.36, 0.36]:
		var side_h: float = sign(sx)
		K.bb(legs, Vector3(0.24, 0.20, 0.24), M_DARK, Vector3(sx, hip - 0.10, -1.26), Vector3.ZERO, 0.02)
		K.actuator(legs, Vector3(sx, hip - 0.10, -1.32), 0.09, 0.26)
		var horn := K.node(legs, Vector3(sx, hip - 0.10, -1.36), Vector3(-12, side_h * -10.0, 0))
		K.plate(horn, K.trap(0.28, 0.14, 0.56, 0.03), 0.14, M_GUN, Vector3(0, 0, -0.20), Vector3(90, 0, 0), 0.022)
		K.plate(horn, K.crect(0.22, 0.05), 0.15, M_ACC, Vector3(0, 0.02, -0.08), Vector3(90, 0, 0), 0.005)
		K.piston(legs, Vector3(sx, hip + 0.10, -1.14), Vector3(sx, hip - 0.05, -1.44), 0.032)
		A.lens(legs, Vector3(sx * 1.32, hip + 0.14, -1.22), Vector3(-90, 0, 0), 0.026, Color(1.0, 0.90, 0.70), 2.0)

	# 车尾双联三防（NBC/防酸雾）正压过滤鼓罐 + 重型格栅
	A.vent(legs, Vector3(0.76, 0.24, 0.05), Vector3(0, hip + 0.02, 1.22), Vector3(0, 180, 0), 6)
	for sx in [-0.36, 0.36]:
		K.cy(legs, 0.16, 0.44, M_LEG2, Vector3(sx, hip + 0.22, 1.24), Vector3(0, 0, 90), -1.0, 16)
		K.cy(legs, 0.17, 0.04, K.brass(), Vector3(sx, hip + 0.22, 1.24), Vector3(0, 0, 90), -1.0, 16)

	# ---- 六条重型防酸密封盾甲步足（FL, FR, ML, MR, RL, RR） ----
	var mounts := [
		Vector3(-0.68, -0.76, -0.40), Vector3(0.68, -0.76, -0.40),
		Vector3(-0.72, 0.0, 0.0),     Vector3(0.72, 0.0, 0.0),
		Vector3(-0.68, 0.76, 0.40),   Vector3(0.68, 0.76, 0.40),
	]
	for m in mounts:
		var sx: float = m.x
		var sz: float = m.y
		var z_aim: float = m.z
		var leg := Node3D.new()
		leg.position = Vector3(sx, hip - 0.04, sz)
		leg.rotation.y = atan2(sign(sx), z_aim)
		legs.add_child(leg)
		var H := Vector3.ZERO
		var KN := Vector3(0, 0.30, 0.78)
		var FT := Vector3(0, -(hip - 0.04) + 0.05, 1.18)

		# 密封波纹护套基节 + 股节厚甲箱
		K.cy(leg, 0.21, 0.30, M_DARK, Vector3(0, 0.0, 0.05), Vector3.ZERO, 0.23, 16)
		K.actuator(leg, Vector3(0, 0.02, 0.15), 0.15, 0.32)

		var up := K.bone(leg, H, KN)
		var l1 := H.distance_to(KN)
		K.bb(up, Vector3(0.26, l1 * 0.92, 0.24), M_FRAME, Vector3(0, -l1 * 0.5, 0.0), Vector3.ZERO, 0.025)
		K.plate(up, K.trap(0.30, 0.38, l1 * 0.86, 0.05), 0.18, M_LEG, Vector3(0, -l1 * 0.48, 0.11), Vector3.ZERO, 0.03)
		K.piston(leg, Vector3(0, -0.12, 0.14), Vector3(0, 0.16, 0.68), 0.030)

		# 膝部密封轴鼓 + 宽幅曲折甲虫护胫盾
		K.actuator(leg, KN, 0.16, 0.34)
		var lo := K.bone(leg, KN, FT)
		var l2 := KN.distance_to(FT)
		K.bb(lo, Vector3(0.22, l2 * 0.90, 0.22), M_FRAME, Vector3(0, -l2 * 0.46, -0.02), Vector3.ZERO, 0.025)
		var shd := K.node(lo, Vector3(0, -l2 * 0.42, 0.13), Vector3(4, 0, 0))
		K.plate(shd, K.trap(0.28, 0.46, l2 * 0.90, 0.06), 0.15, M_LEG, Vector3.ZERO, Vector3.ZERO, 0.032)
		K.plate(shd, K.trap(0.18, 0.30, l2 * 0.56, 0.04), 0.09, M_LEG2, Vector3(0, 0.08, 0.07), Vector3.ZERO, 0.02)
		K.grab_iron(shd, 0.18, 0.038, Vector3(0, 0.34, 0.07), Vector3(180, 0, 0), 0.012)
		K.piston(leg, KN + Vector3(0, -0.10, -0.10), KN + (FT - KN) * 0.62 + Vector3(0, 0, -0.08), 0.034)

		# 耐酸橡胶包覆三铲重足
		var pad := K.node(leg, FT + Vector3(0, 0.03, 0))
		K.cy(pad, 0.13, 0.10, M_GUN, Vector3(0, 0.05, 0), Vector3.ZERO, 0.16, 14)
		K.cy(pad, 0.20, 0.05, A.rubber(), Vector3(0, -0.012, 0), Vector3.ZERO, 0.22, 16)
		for ca in [-40.0, 40.0, 180.0]:
			var cl := K.node(pad, Vector3.ZERO, Vector3(0, ca, 0))
			K.plate(cl, K.trap(0.11, 0.07, 0.16, 0.012), 0.085, M_DARK, Vector3(0, 0.008, 0.18), Vector3(78, 0, 0), 0.012)
			K.bb(cl, Vector3(0.10, 0.028, 0.15), A.rubber(), Vector3(0, -0.025, 0.18), Vector3.ZERO, 0.006)
		leg_parts.append(leg)

	K.socket(root, "core", Vector3(0, hip + 0.56, 0), Vector3.UP)
	root.set_meta("leg_parts", leg_parts)
	root.set_meta("leg_type", "hex")
	return root
