extends RefCounted
## 轻型猎犬四足底盘 HD-4：仿生军用机械犬窄体纵梁脊柱、前置激光雷达观瞄头与防撞笼、内收式高速液压奔袭四肢
## 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var id: String = ctx.id
	var c: Color = ctx.color
	var serial: String = ctx.get("serial", "04")
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var M_GUN := K.gunmetal()
	var M_ACC := K.accent()
	var root := K.module_root("legs", id, Vector3.ZERO)
	var legs := root
	var M_LEG := K.armor(c, 0.42)
	var M_LEG2 := K.armor_sub(c, 0.46)
	var leg_parts: Array = []
	var hip := 1.32

	# ---- 窄长仿生机械犬脊柱车架 + 顶部回转鞍座（顶接 hip+0.54 = 1.86） ----
	K.bb(legs, Vector3(0.76, 0.38, 1.66), M_FRAME, Vector3(0, hip, 0.0), Vector3.ZERO, 0.045)
	K.plate(legs, K.crect(0.88, 1.74, [0.22, 0.22, 0.20, 0.20]), 0.20, M_LEG, Vector3(0, hip + 0.14, 0.0), Vector3(90, 0, 0), 0.035)
	K.plate(legs, K.crect(0.70, 1.48, [0.16, 0.16, 0.16, 0.16]), 0.16, M_LEG2, Vector3(0, hip - 0.14, 0.0), Vector3(90, 0, 0), 0.03)
	# 侧肋散热栅与黄色警示条
	for sx in [-0.42, 0.42]:
		var side_s: float = sign(sx)
		K.plate(legs, K.crect(0.92, 0.24, [0.08, 0.08, 0.04, 0.04]), 0.08, M_LEG2, Vector3(sx, hip + 0.02, 0.0), Vector3(0, 90, 0), 0.02)
		K.plate(legs, K.crect(0.42, 0.05), 0.09, M_ACC, Vector3(sx + side_s * 0.01, hip + 0.08, -0.18), Vector3(0, 90, 0), 0.005)
		A.vent(legs, Vector3(0.46, 0.14, 0.03), Vector3(sx + side_s * 0.04, hip + 0.0, 0.16), Vector3(0, side_s * -90.0, 0), 4)
	# 中央鞍座回转柱
	K.cy(legs, 0.48, 0.30, M_LEG2, Vector3(0, hip + 0.32, 0.0), Vector3.ZERO, 0.56, 24)
	K.cy(legs, 0.50, 0.10, M_DARK, Vector3(0, hip + 0.48, 0.0), Vector3.ZERO, 0.52, 24)

	# 前探式立体双目光学/激光雷达犬首传感器舱 + 钢管防撞护笼
	var head := K.node(legs, Vector3(0, hip + 0.04, -0.98), Vector3(8, 0, 0))
	K.plate(head, K.trap(0.54, 0.42, 0.30, 0.05), 0.36, M_LEG, Vector3(0, 0, 0), Vector3(90, 0, 0), 0.03)
	K.periscope(head, 0.30, 0.09, Vector3(0, 0.03, -0.18), Vector3.ZERO)
	K.cy(head, 0.08, 0.09, M_DARK, Vector3(0, 0.15, -0.06), Vector3.ZERO, -1.0, 14)
	K.cy(head, 0.075, 0.04, K.canopy(K.VISOR, 0.35), Vector3(0, 0.17, -0.06), Vector3.ZERO, -1.0, 14)
	K.grab_iron(head, 0.48, 0.08, Vector3(0, -0.04, -0.18), Vector3.ZERO, 0.014)
	for sx in [-0.20, 0.20]:
		A.lens(head, Vector3(sx, -0.04, -0.19), Vector3(-90, 0, 0), 0.024, Color(1.0, 0.92, 0.76), 2.0)
	A.stencil(head, "HD-" + serial, Vector3(0, 0.13, -0.16), Vector3(-68, 180, 0), 0.0024, Color(0.95, 0.93, 0.86, 0.86))

	# 尾部蓄能电容包 + 拖车钩
	K.bb(legs, Vector3(0.64, 0.28, 0.28), M_LEG2, Vector3(0, hip + 0.04, 0.94), Vector3.ZERO, 0.03)
	A.vent(legs, Vector3(0.48, 0.18, 0.04), Vector3(0, hip + 0.04, 1.09), Vector3(0, 180, 0), 4)
	A.add(legs, A.torus(0.028, 0.052, 12), M_GUN, Vector3(0, hip - 0.08, 1.09), Vector3(0, 0, 90), Vector3.ONE, false)

	# ---- 四条内收式哺乳动物仿生液压奔袭腿（前肘后膝感、修长流线） ----
	for p in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var leg := Node3D.new()
		leg.position = Vector3(p.x * 0.46, hip - 0.04, p.y * 0.64)
		# 猎犬站姿更偏前后纵向（约 ±27° 外展），迥异于蜘蛛外张八字腿
		leg.rotation.y = atan2(p.x * 0.52, p.y)
		legs.add_child(leg)
		var H := Vector3.ZERO
		var KN := Vector3(0, -0.46, 0.52)
		var FT := Vector3(0, -(hip - 0.04) + 0.04, 0.82)

		# 紧凑球柱肩髋电机鼓
		K.actuator(leg, Vector3(0, 0, 0.04), 0.16, 0.28)
		K.cy(leg, 0.15, 0.18, M_LEG, Vector3(0, 0.02, 0.12), Vector3(90, 0, 0), -1.0, 16)

		# 大腿枢轴（斜向下伸展）：工字高强铝合金梁 + 弧切护甲 + 黄铜油封液压缸
		var fm := K.node(leg, H, Vector3.ZERO, "Femur")
		var up := K.bone(fm, H, KN)
		var l1 := H.distance_to(KN)
		K.bb(up, Vector3(0.14, l1 * 0.94, 0.18), M_FRAME, Vector3(0, -l1 * 0.5, 0.0), Vector3.ZERO, 0.022)
		K.plate(up, K.trap(0.18, 0.26, l1 * 0.84, 0.04), 0.12, M_LEG, Vector3(0, -l1 * 0.48, 0.08), Vector3.ZERO, 0.025)
		K.piston(fm, Vector3(0, 0.12, 0.08), KN + Vector3(0, 0.14, -0.06), 0.028)

		# 膝关节转轴 + 轻型护盖
		K.actuator(fm, KN, 0.12, 0.24)
		K.plate(fm, K.trap(0.20, 0.15, 0.22, 0.03), 0.10, M_LEG2, KN + Vector3(0, 0.04, 0.08), Vector3(-22, 0, 0), 0.02)

		# 小腿枢轴（纤细弹性碳钢双连杆 + 缓冲胶垫双趾猎犬爪掌）
		var kj := K.node(fm, KN, Vector3.ZERO, "Knee")
		var lo := K.bone(kj, Vector3.ZERO, FT - KN)
		var l2 := KN.distance_to(FT)
		for sx_b in [-0.055, 0.055]:
			K.cy(lo, 0.034, l2 * 0.94, M_FRAME, Vector3(sx_b, -l2 * 0.48, 0.0), Vector3.ZERO, -1.0, 10)
		K.plate(lo, K.trap(0.13, 0.20, l2 * 0.72, 0.03), 0.09, M_LEG, Vector3(0, -l2 * 0.40, 0.06), Vector3.ZERO, 0.02)
		K.piston(kj, Vector3(0, -0.08, -0.08), (FT - KN) * 0.58 + Vector3(0, 0, -0.06), 0.024)
		A.hose(kj, Vector3(0.09, 0.36, -0.34), Vector3(0.09, -0.18, 0.04), Vector3(0.05, 0, 0.08), 0.018)

		# 踝枢轴与球形橡胶缓冲肉垫 + 双前抓地钢趾
		var aj := K.node(kj, FT - KN, Vector3.ZERO, "Ankle")
		var pad := K.node(aj, Vector3(0, 0.02, 0))
		K.cy(pad, 0.10, 0.08, M_GUN, Vector3(0, 0.05, 0), Vector3.ZERO, 0.12, 12)
		K.cy(pad, 0.135, 0.05, A.rubber(), Vector3(0, -0.035, 0.01), Vector3.ZERO, 0.15, 14)
		for ca in [-22.0, 22.0]:
			var cl := K.node(pad, Vector3.ZERO, Vector3(0, ca, 0))
			K.bb(cl, Vector3(0.06, 0.05, 0.13), M_DARK, Vector3(0, -0.01, 0.13), Vector3(14, 0, 0), 0.01)
			K.bb(cl, Vector3(0.065, 0.028, 0.12), A.rubber(), Vector3(0, -0.045, 0.13), Vector3.ZERO, 0.006)
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
