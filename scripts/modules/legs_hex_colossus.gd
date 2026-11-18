extends RefCounted
## 巨像攻城六足底盘 CL-12：三段式超重型攻城铆接堡垒船体、前置攻城破城锤铲、双立式防烫柴油烟囱、六根双缸液压打桩重足
## 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var id: String = ctx.id
	var c: Color = ctx.color
	var serial: String = ctx.get("serial", "12")
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var M_GUN := K.gunmetal()
	var M_ACC := K.accent()
	var root := K.module_root("legs", id, Vector3.ZERO)
	var legs := root
	var M_LEG := K.armor(c, 0.54)
	var M_LEG2 := K.armor_sub(c, 0.58)
	var leg_parts: Array = []
	var hip := 1.38

	# ---- 三段式超重型铆接攻城平台船体（全长 2.7m）+ 八筋重型炮塔座圈（顶接 hip+0.58 = 1.96） ----
	K.bb(legs, Vector3(1.48, 0.56, 2.66), M_FRAME, Vector3(0, hip, 0.0), Vector3.ZERO, 0.065)
	# 前中后三段分体厚重装甲甲板
	for seg_z in [-0.88, 0.0, 0.88]:
		var sw := 1.62 if seg_z == 0.0 else 1.48
		K.plate(legs, K.crect(sw, 0.84, [0.18, 0.18, 0.18, 0.18]), 0.28, M_LEG if seg_z == 0.0 else M_LEG2, Vector3(0, hip + 0.20, seg_z), Vector3(90, 0, 0), 0.042)
	K.plate(legs, K.crect(1.32, 2.36, [0.28, 0.28, 0.28, 0.28]), 0.24, M_LEG2, Vector3(0, hip - 0.18, 0.0), Vector3(90, 0, 0), 0.04)
	# 中央重装回转座塔台 + 8道加强腹板 + 6根液压脐带软管
	K.cy(legs, 0.66, 0.30, M_LEG, Vector3(0, hip + 0.38, 0.0), Vector3.ZERO, 0.78, 28)
	K.cy(legs, 0.62, 0.10, M_DARK, Vector3(0, hip + 0.52, 0.0), Vector3.ZERO, 0.64, 28)
	for i in 8:
		var ga := TAU * i / 8.0
		K.bb(legs, Vector3(0.06, 0.24, 0.20), M_GUN, Vector3(cos(ga) * 0.68, hip + 0.36, sin(ga) * 0.68), Vector3(0, -rad_to_deg(ga), 0), 0.01)
	for i in 6:
		var ha := TAU * i / 6.0 + 0.25
		A.hose(legs, Vector3(cos(ha) * 0.64, hip + 0.26, sin(ha) * 0.64), Vector3(cos(ha) * 0.54, hip + 0.52, sin(ha) * 0.54), Vector3(cos(ha) * 0.09, 0, sin(ha) * 0.09), 0.024)

	# ---- 车首楔形攻城破障撞锤船首（四缸液压缓冲驻退梁 + 上倾反应装甲迎弹坡面 + 笼罩探照灯） ----
	var prow := K.node(legs, Vector3(0, hip + 0.10, -1.38), Vector3(34, 0, 0))
	K.plate(prow, K.trap(1.48, 1.30, 0.44, 0.06), 0.18, M_LEG, Vector3.ZERO, Vector3.ZERO, 0.035)
	A.stencil(prow, "CL-" + serial, Vector3(0, 0.08, -0.098), Vector3(0, 180, 0), 0.0028, Color(0.95, 0.93, 0.86, 0.90))
	for ex in [-0.42, 0.42]:
		K.era_block(prow, Vector3(0.36, 0.18, 0.075), M_LEG2, Vector3(ex, -0.04, -0.125))
		K.bb(legs, Vector3(0.20, 0.12, 0.12), M_DARK, Vector3(ex * 1.25, hip + 0.24, -1.30), Vector3.ZERO, 0.015)
		A.lens(legs, Vector3(ex * 1.25, hip + 0.24, -1.36), Vector3(-90, 0, 0), 0.032, Color(1.0, 0.90, 0.70), 2.4)
	# 前探液压驻退攻城撞锤横梁（带4座镀铬缓冲油缸与破墙凸齿）
	var ram := K.node(legs, Vector3(0, hip - 0.12, -1.62))
	K.bb(ram, Vector3(1.52, 0.24, 0.22), M_GUN, Vector3.ZERO, Vector3.ZERO, 0.03)
	K.plate(ram, K.crect(1.24, 0.065), 0.23, M_ACC, Vector3(0, 0.06, -0.01), Vector3.ZERO, 0.005)
	for rx_i in [-0.48, -0.18, 0.18, 0.48]:
		K.cy(legs, 0.052, 0.28, A.chrome(), Vector3(rx_i, hip - 0.12, -1.44), Vector3(90, 0, 0), -1.0, 12)
		K.cy(legs, 0.068, 0.08, K.brass(), Vector3(rx_i, hip - 0.12, -1.34), Vector3(90, 0, 0), -1.0, 12)
		K.bb(ram, Vector3(0.11, 0.18, 0.14), M_DARK, Vector3(rx_i, -0.02, -0.12), Vector3.ZERO, 0.015)
	for sx_t in [-0.62, 0.62]:
		A.add(ram, A.torus(0.036, 0.068, 12), M_DARK, Vector3(sx_t, -0.04, -0.12), Vector3(0, 0, 90), Vector3.ONE, false)
	K.periscope(legs, 0.30, 0.09, Vector3(0, hip + 0.30, -1.16), Vector3.ZERO)

	# ---- 车尾重型辅机动力舱：双立式防烫网罩柴油烟囱 + 双外挂储油罐 ----
	A.vent(legs, Vector3(0.96, 0.30, 0.06), Vector3(0, hip + 0.02, 1.36), Vector3(0, 180, 0), 6)
	for sx in [-0.46, 0.46]:
		K.cy(legs, 0.12, 0.68, M_DARK, Vector3(sx, hip + 0.42, 1.24), Vector3.ZERO, 0.13, 14)
		K.cy(legs, 0.15, 0.40, M_GUN, Vector3(sx, hip + 0.36, 1.24), Vector3.ZERO, -1.0, 14)
		K.holes(legs, Vector3(sx, hip + 0.36, 1.39), Vector3(0, 180, 0), 2, 3, 0.065, 0.016)
		K.barrel_bore(legs, 0.115, 0.082, Vector3(sx, hip + 0.76, 1.24), 0.08, Vector3.ZERO)
		K.cy(legs, 0.16, 0.46, M_LEG2, Vector3(sx * 0.72, hip - 0.12, 1.44), Vector3(0, 0, 90), -1.0, 14)

	# ---- 六根巨像级双缸液压打桩重足（FL, FR, ML, MR, RL, RR） ----
	var mounts := [
		Vector3(-0.74, -0.92, -0.36), Vector3(0.74, -0.92, -0.36),
		Vector3(-0.78, 0.0, 0.0),     Vector3(0.78, 0.0, 0.0),
		Vector3(-0.74, 0.92, 0.36),   Vector3(0.74, 0.92, 0.36),
	]
	for m in mounts:
		var sx: float = m.x
		var sz: float = m.y
		var z_aim: float = m.z
		var leg := Node3D.new()
		leg.position = Vector3(sx, hip + 0.02, sz)
		leg.rotation.y = atan2(sign(sx), z_aim)
		legs.add_child(leg)
		var H := Vector3.ZERO
		var KN := Vector3(0, 0.24, 0.76)
		var FT := Vector3(0, -(hip + 0.02) + 0.06, 1.06)

		# 重工铸钢回转肩鼓 + 螺栓盘
		K.cy(leg, 0.24, 0.38, M_DARK, Vector3(0, 0.0, 0.04), Vector3.ZERO, 0.26, 18)
		K.bolt_ring(leg, 0.19, 8, 0.015, Vector3(0, 0.195, 0.04), Vector3.ZERO)

		# 铆接重装甲股节枢轴箱梁 + 双顶置粗液压推杆
		var fm := K.node(leg, H, Vector3.ZERO, "Femur")
		var up := K.bone(fm, H, KN)
		var l1 := H.distance_to(KN)
		K.bb(up, Vector3(0.36, l1 * 0.94, 0.32), M_LEG2, Vector3(0, -l1 * 0.5, 0.0), Vector3.ZERO, 0.035)
		K.plate(up, K.trap(0.38, 0.44, l1 * 0.84, 0.05), 0.14, M_LEG, Vector3(0, -l1 * 0.48, 0.15), Vector3.ZERO, 0.028)
		for px_o in [-0.12, 0.12]:
			K.piston(fm, Vector3(px_o, 0.18, 0.12), KN + Vector3(px_o, 0.20, -0.06), 0.036)

		# 膝部重型打桩导套头 + 胫节枢轴双并联粗镀铬打桩液压柱 + 外挂重型防爆胫盾
		K.actuator(fm, KN, 0.20, 0.42)
		var kj := K.node(fm, KN, Vector3.ZERO, "Knee")
		var lo := K.bone(kj, Vector3.ZERO, FT - KN)
		var l2 := KN.distance_to(FT)
		K.bb(lo, Vector3(0.38, l2 * 0.62, 0.36), M_LEG2, Vector3(0, -l2 * 0.30, 0.0), Vector3.ZERO, 0.038)
		K.plate(lo, K.trap(0.32, 0.48, l2 * 0.86, 0.06), 0.16, M_LEG, Vector3(0, -l2 * 0.44, 0.16), Vector3(3, 0, 0), 0.032)
		K.plate(lo, K.crect(0.36, 0.055), 0.17, M_ACC, Vector3(0, -l2 * 0.24, 0.17), Vector3(3, 0, 0), 0.005)
		A.rivets(lo, Vector3(0.20, -0.12, 0.12), Vector3(0.20, -l2 * 0.56, 0.12), 4, 0.017, Vector3(0, 0, 90))
		for cx_r in [-0.11, 0.11]:
			K.cy(lo, 0.058, l2 * 0.88, A.chrome(), Vector3(cx_r, -l2 * 0.52, -0.04), Vector3.ZERO, -1.0, 12)
			K.cy(lo, 0.076, 0.05, K.brass(), Vector3(cx_r, -l2 * 0.60, -0.04), Vector3.ZERO, -1.0, 12)
		A.hose(kj, Vector3(0.18, -0.04, -0.34), Vector3(0.18, -0.38, 0.08), Vector3(0.09, 0.04, 0.10), 0.026)

		# 踝枢轴与矩形攻城夯地驻锄大足 + 前后液压缓冲齿块
		var aj := K.node(kj, FT - KN, Vector3.ZERO, "Ankle")
		var pad := K.node(aj, Vector3(0, 0.02, 0))
		K.bb(pad, Vector3(0.42, 0.12, 0.46), M_GUN, Vector3(0, 0.04, 0), Vector3.ZERO, 0.025)
		K.bb(pad, Vector3(0.46, 0.055, 0.50), A.rubber(), Vector3(0, -0.052, 0), Vector3.ZERO, 0.015)
		for fz_c in [-0.24, 0.24]:
			K.bb(pad, Vector3(0.36, 0.08, 0.10), M_DARK, Vector3(0, -0.01, fz_c), Vector3(sign(fz_c) * 18.0, 0, 0), 0.012)
		leg.set_meta("femur", fm)
		leg.set_meta("knee", kj)
		leg.set_meta("ankle", aj)
		leg.set_meta("KN", KN)
		leg.set_meta("AN", FT)
		leg.set_meta("base_yaw", leg.rotation.y)
		leg_parts.append(leg)

	K.socket(root, "core", Vector3(0, hip + 0.58, 0), Vector3.UP)
	root.set_meta("leg_parts", leg_parts)
	root.set_meta("leg_type", "hex")
	return root
