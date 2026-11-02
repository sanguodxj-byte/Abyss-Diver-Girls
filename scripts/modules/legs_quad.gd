extends RefCounted
## 四足底盘 Arachne：骨架 + 装甲 + 活塞的蜘蛛腿
## 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var id: String = ctx.id
	var c: Color = ctx.color
	var lights: bool = ctx.get("lights", true)
	var serial: String = ctx.get("serial", "00")
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var M_ACC := K.accent()
	var root := K.module_root("legs", id, Vector3.ZERO)
	var legs := root
	var M_LEG := K.armor(c)
	var M_LEG2 := K.armor(c.darkened(0.18))
	var leg_parts: Array = []
	var hip := 1.5
	hip = 1.4
	# 机体：八边形切角底盘
	K.bb(legs, Vector3(1.2, 0.4, 1.2), M_FRAME, Vector3(0, hip, 0), Vector3.ZERO, 0.06)
	K.plate(legs, K.crect(1.4, 1.4, [0.34, 0.34, 0.34, 0.34]), 0.22, M_LEG, Vector3(0, hip + 0.16, 0), Vector3(90, 0, 0), 0.05)
	K.plate(legs, K.crect(1.1, 1.1, [0.26, 0.26, 0.26, 0.26]), 0.2, M_LEG2, Vector3(0, hip - 0.12, 0), Vector3(90, 0, 0), 0.04)
	K.cy(legs, 0.42, 0.14, M_DARK, Vector3(0, hip + 0.3, 0), Vector3.ZERO, 0.46, 24)
	K.number(legs, serial, Vector3(0, hip + 0.1, -0.56), Vector3(0, 180, 0), 0.0032)
	for p in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var leg := Node3D.new()
		leg.position = Vector3(p.x * 0.55, hip, p.y * 0.55)
		leg.rotation.y = atan2(p.x, p.y)
		legs.add_child(leg)
		# 局部 +Z 朝外：髋 → 高耸膝 → 尖足（蜘蛛式）
		var H := Vector3.ZERO
		var KN := Vector3(0, 0.45, 0.95)
		var FT := Vector3(0, -hip + 0.05, 1.35)
		A.add(leg, A.sphere(0.2, -1, 16), M_DARK, Vector3.ZERO)
		var up := K.bone(leg, H, KN)
		var l1 := H.distance_to(KN)
		K.bb(up, Vector3(0.16, l1, 0.16), M_FRAME, Vector3(0, -l1 * 0.5, 0), Vector3.ZERO, 0.03)
		K.plate(up, K.trap(0.24, 0.34, l1 * 0.9, 0.05), 0.3, M_LEG, Vector3(0, -l1 * 0.5, 0.0), Vector3(0, 90, 0), 0.035)
		K.plate(up, K.crect(0.06, l1 * 0.5), 0.32, M_ACC, Vector3(0, -l1 * 0.5, -0.12), Vector3(0, 90, 0), 0.006)
		K.piston(leg, Vector3(0, -0.1, 0.12), Vector3(0, 0.25, 0.8), 0.03)
		K.actuator(leg, KN, 0.14, 0.3)
		var lo := K.bone(leg, KN, FT)
		var l2 := KN.distance_to(FT)
		K.bb(lo, Vector3(0.14, l2 * 0.8, 0.14), M_FRAME, Vector3(0, -l2 * 0.4, 0), Vector3.ZERO, 0.03)
		# 下肢长甲：上宽下尖的五边形
		K.plate(lo, [Vector2(-0.16, 0.05), Vector2(0.16, 0.05), Vector2(0.14, -l2 * 0.6), Vector2(0.0, -l2), Vector2(-0.14, -l2 * 0.6)], 0.22, M_LEG2, Vector3(0, -0.02, 0), Vector3(0, 90, 0), 0.03)
		K.holes(lo, Vector3(0.115, -l2 * 0.25, 0), Vector3(0, -90, 0), 1, 3, 0.07, 0.018)
		A.hose(leg, Vector3(0.1, 0.3, 0.6), KN + Vector3(0.1, -0.5, 0.08), Vector3(0.06, 0, 0.14), 0.022)
		K.piston(leg, KN + Vector3(-0.1, -0.1, -0.05), KN + (FT - KN) * 0.5 + Vector3(-0.1, 0, -0.05), 0.026)
		K.cy(leg, 0.06, 0.12, A.rubber(), FT + Vector3(0, 0.04, 0), Vector3.ZERO, 0.03)
		leg_parts.append(leg)
	# 腰部回转轴（底盘自带，顶端是 HP-C1 母座）
	K.cy(legs, 0.3, 0.8, M_FRAME, Vector3(0, hip + 0.12, 0), Vector3.ZERO, 0.36, 20)
	K.cy(legs, 0.44, 0.1, M_DARK, Vector3(0, hip + 0.2, 0), Vector3.ZERO, 0.46, 24)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		A.hose(legs, Vector3(cos(a) * 0.32, hip + 0.24, sin(a) * 0.32), Vector3(cos(a) * 0.27, hip + 0.48, sin(a) * 0.27), Vector3(cos(a) * 0.08, 0, sin(a) * 0.08), 0.018)
	K.socket(root, "core", Vector3(0, hip + 0.55, 0), Vector3.UP)
	root.set_meta("leg_parts", leg_parts)
	root.set_meta("leg_type", "quad")
	return root
