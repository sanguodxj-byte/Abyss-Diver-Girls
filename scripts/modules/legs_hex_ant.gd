extends RefCounted
## 轻型工兵六足底盘 AT-6：敞露钢管桁架长车体、前置工兵电动绞盘与探照灯、尾部物资备件架、六条双管液压工兵步进肢
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
	var M_LEG := K.armor(c, 0.42)
	var M_LEG2 := K.armor_sub(c, 0.46)
	var leg_parts: Array = []
	var hip := 1.18

	# ---- 细长敞露钢管桁架工兵底盘 + 防滑冲孔顶甲板 + 中央紧凑回转座（顶接 hip+0.54 = 1.72） ----
	K.bb(legs, Vector3(0.84, 0.36, 1.96), M_FRAME, Vector3(0, hip, 0.0), Vector3.ZERO, 0.045)
	K.plate(legs, K.crect(0.98, 2.04, [0.20, 0.20, 0.18, 0.18]), 0.16, M_LEG, Vector3(0, hip + 0.14, 0.0), Vector3(90, 0, 0), 0.03)
	for sx in [-0.46, 0.46]:
		K.cy(legs, 0.036, 1.84, M_GUN, Vector3(sx, hip - 0.12, 0.0), Vector3(90, 0, 0), -1.0, 10)
		K.grab_iron(legs, 0.52, 0.05, Vector3(sx, hip + 0.18, -0.52), Vector3(0, sign(sx) * -90.0, 0), 0.013)
	K.cy(legs, 0.34, 0.26, M_LEG2, Vector3(0, hip + 0.34, 0.0), Vector3.ZERO, 0.40, 24)
	K.cy(legs, 0.36, 0.09, M_DARK, Vector3(0, hip + 0.48, 0.0), Vector3.ZERO, 0.37, 24)

	# 车首工兵电动牵引绞盘 + 黄黑警示保险杠 + 双工兵强光作业灯
	K.bb(legs, Vector3(0.86, 0.16, 0.14), M_GUN, Vector3(0, hip - 0.04, -1.04), Vector3.ZERO, 0.02)
	K.plate(legs, K.crect(0.56, 0.05), 0.15, M_ACC, Vector3(0, hip + 0.02, -1.05), Vector3.ZERO, 0.005)
	K.cy(legs, 0.085, 0.34, K.copper(), Vector3(0, hip - 0.04, -1.08), Vector3(0, 0, 90), -1.0, 12)
	A.add(legs, A.torus(0.028, 0.054, 12), M_DARK, Vector3(0, hip - 0.04, -1.18), Vector3(0, 0, 90), Vector3.ONE, false)
	for sx in [-0.30, 0.30]:
		K.bb(legs, Vector3(0.16, 0.10, 0.10), M_DARK, Vector3(sx, hip + 0.12, -1.02), Vector3.ZERO, 0.012)
		A.lens(legs, Vector3(sx, hip + 0.12, -1.07), Vector3(-90, 0, 0), 0.028, Color(1.0, 0.94, 0.78), 2.2)
	A.stencil(legs, "AT-" + serial, Vector3(0, hip + 0.18, -1.03), Vector3(0, 180, 0), 0.0024, Color(0.95, 0.93, 0.86, 0.86))

	# 车尾工兵外挂备件筐 + 竖置备用液压油桶（配防脱紧固钢箍与护栏）
	K.bb(legs, Vector3(0.78, 0.24, 0.30), M_LEG2, Vector3(0, hip + 0.06, 1.06), Vector3.ZERO, 0.025)
	A.vent(legs, Vector3(0.56, 0.16, 0.04), Vector3(0, hip + 0.04, 1.22), Vector3(0, 180, 0), 4)
	K.grab_iron(legs, 0.68, 0.14, Vector3(0, hip + 0.24, 1.08), Vector3(0, 180, 0), 0.013)
	for sx in [-0.22, 0.22]:
		K.cy(legs, 0.095, 0.30, K.brass() if sx < 0 else M_LEG, Vector3(sx, hip + 0.24, 1.06), Vector3.ZERO, -1.0, 12)
		K.cy(legs, 0.102, 0.024, M_DARK, Vector3(sx, hip + 0.24, 1.06), Vector3.ZERO, -1.0, 12)

	# ---- 六条轻量化双管液压工兵步进肢（按 FL, FR, ML, MR, RL, RR 顺序排列，驱动三角交替步态） ----
	var mounts := [
		Vector3(-0.46, -0.68, -0.42), Vector3(0.46, -0.68, -0.42),
		Vector3(-0.50, 0.0, 0.0),     Vector3(0.50, 0.0, 0.0),
		Vector3(-0.46, 0.68, 0.42),   Vector3(0.46, 0.68, 0.42),
	]
	for m in mounts:
		var sx: float = m.x
		var sz: float = m.y
		var z_aim: float = m.z
		var leg := Node3D.new()
		leg.position = Vector3(sx, hip - 0.02, sz)
		leg.rotation.y = atan2(sign(sx), z_aim)
		legs.add_child(leg)
		var H := Vector3.ZERO
		var KN := Vector3(0, 0.28, 0.68)
		var FT := Vector3(0, -(hip - 0.02) + 0.04, 1.02)

		# 基节回转轴承座
		K.cy(leg, 0.15, 0.24, M_DARK, Vector3(0, 0, 0.04), Vector3.ZERO, 0.16, 14)
		K.actuator(leg, Vector3(0, 0.01, 0.12), 0.11, 0.24)

		# 股节枢轴（双钢管 + 轻质背板 + 黄铜封口液压缸）
		var fm := K.node(leg, H, Vector3.ZERO, "Femur")
		var up := K.bone(fm, H, KN)
		var l1 := H.distance_to(KN)
		for bx in [-0.065, 0.065]:
			K.cy(up, 0.032, l1 * 0.92, M_FRAME, Vector3(bx, -l1 * 0.5, 0.0), Vector3.ZERO, -1.0, 10)
		K.plate(up, K.trap(0.18, 0.24, l1 * 0.80, 0.03), 0.09, M_LEG, Vector3(0, -l1 * 0.48, 0.06), Vector3.ZERO, 0.02)
		K.piston(fm, Vector3(0, -0.10, 0.12), Vector3(0, 0.14, 0.58), 0.024)

		# 膝节转鼓 + 胫节枢轴双钢管与橡胶防滑圆足
		K.actuator(fm, KN, 0.115, 0.24)
		var kj := K.node(fm, KN, Vector3.ZERO, "Knee")
		var lo := K.bone(kj, Vector3.ZERO, FT - KN)
		var l2 := KN.distance_to(FT)
		for bx in [-0.055, 0.055]:
			K.cy(lo, 0.030, l2 * 0.92, M_FRAME, Vector3(bx, -l2 * 0.48, 0.0), Vector3.ZERO, -1.0, 10)
		for rt in [0.32, 0.68]:
			K.bb(lo, Vector3(0.15, 0.05, 0.10), M_GUN, Vector3(0, -l2 * rt, 0.0), Vector3.ZERO, 0.01)
		K.plate(lo, K.trap(0.14, 0.22, l2 * 0.72, 0.03), 0.08, M_LEG2, Vector3(0, -l2 * 0.40, 0.07), Vector3.ZERO, 0.018)
		K.piston(kj, Vector3(0, -0.08, -0.08), (FT - KN) * 0.56 + Vector3(0, 0, -0.06), 0.024)

		var aj := K.node(kj, FT - KN, Vector3.ZERO, "Ankle")
		var pad := K.node(aj, Vector3(0, 0.02, 0))
		K.cy(pad, 0.095, 0.08, M_GUN, Vector3(0, 0.05, 0), Vector3.ZERO, 0.12, 12)
		K.cy(pad, 0.145, 0.045, A.rubber(), Vector3(0, -0.035, 0), Vector3.ZERO, 0.16, 14)
		for ca in [-35.0, 35.0]:
			var cl := K.node(pad, Vector3.ZERO, Vector3(0, ca, 0))
			K.bb(cl, Vector3(0.055, 0.04, 0.11), M_DARK, Vector3(0, -0.015, 0.14), Vector3(12, 0, 0), 0.008)
		leg.set_meta("femur", fm)
		leg.set_meta("knee", kj)
		leg.set_meta("ankle", aj)
		leg.set_meta("KN", KN)
		leg.set_meta("AN", FT)
		leg.set_meta("base_yaw", leg.rotation.y)
		leg_parts.append(leg)

	K.socket(root, "core", Vector3(0, hip + 0.54, 0), Vector3.UP)
	root.set_meta("leg_parts", leg_parts)
	root.set_meta("leg_type", "hex")
	return root
