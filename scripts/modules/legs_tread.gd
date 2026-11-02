extends RefCounted
## 履带底盘 Mole：分节履带板、负重轮、侧裙甲、斜装甲车体
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
	hip = 1.05
	# 车体：切角底盘 + 楔形前装甲 + 上甲板
	K.bb(legs, Vector3(1.1, 0.5, 1.7), M_FRAME, Vector3(0, 0.75, 0), Vector3.ZERO, 0.06)
	K.plate(legs, K.crect(1.9, 0.28, [0.3, 0.1, 0.0, 0.0]), 1.2, M_LEG, Vector3(0, 1.0, 0.05), Vector3(0, 90, 0), 0.04)
	K.plate(legs, K.trap(1.0, 1.2, 0.46, 0.08), 0.14, M_LEG2, Vector3(0, 0.8, -0.98), Vector3(-38, 0, 0), 0.04)
	K.plate(legs, K.crect(0.07, 0.36), 0.15, M_ACC, Vector3(-0.38, 0.82, -0.99), Vector3(-38, 0, 0), 0.006)
	K.holes(legs, Vector3(0, 0.78, -1.06), Vector3(-38, 0, 0), 6, 1, 0.09, 0.022)
	A.vent(legs, Vector3(0.6, 0.3, 0.04), Vector3(0, 1.0, 1.0), Vector3(0, 180, 0), 5)
	for sx in [-0.3, 0.3]:
		K.bb(legs, Vector3(0.18, 0.1, 0.1), M_DARK, Vector3(sx, 0.92, -1.06), Vector3.ZERO, 0.02)
		A.add(legs, A.cyl(0.035, 0.03), A.emit(Color(1.0, 0.85, 0.6), 4.0), Vector3(sx, 0.92, -1.12), Vector3(90, 0, 0), Vector3.ONE, false)
	for sx in [-0.88, 0.88]:
		var side: float = sign(sx)
		var tr := Node3D.new()
		tr.position = Vector3(sx, 0, 0)
		legs.add_child(tr)
		# 履带：分节履带板绕一圈
		var links := 26
		for i in links:
			var t := float(i) / links
			var per := 2.0 * 2.0 + 2.0 * PI * 0.32
			var d := t * per
			var pos: Vector3
			var ang := 0.0
			if d < 2.0:
				pos = Vector3(0, 0.72, -1.0 + d); ang = 0.0
			elif d < 2.0 + PI * 0.32:
				var a := (d - 2.0) / 0.32
				pos = Vector3(0, 0.4 + cos(a) * 0.32, 1.0 + sin(a) * 0.32); ang = -rad_to_deg(a)
			elif d < 4.0 + PI * 0.32:
				pos = Vector3(0, 0.08, 1.0 - (d - 2.0 - PI * 0.32)); ang = 180.0
			else:
				var a := (d - 4.0 - PI * 0.32) / 0.32
				pos = Vector3(0, 0.4 - cos(a) * 0.32, -1.0 - sin(a) * 0.32); ang = 180.0 - rad_to_deg(a)
			K.bb(tr, Vector3(0.6, 0.06, 0.2), A.metal(Color(0.2, 0.19, 0.18)), pos, Vector3(ang, 0, 0), 0.015)
		# 负重轮 + 主动轮
		for wz in [-0.95, -0.48, 0.0, 0.48, 0.95]:
			K.cy(tr, 0.26 if abs(wz) > 0.9 else 0.22, 0.42, M_DARK, Vector3(0, 0.4 if abs(wz) > 0.9 else 0.32, wz), Vector3(0, 0, 90), -1.0, 18)
			K.cy(tr, 0.1, 0.46, A.chrome(), Vector3(0, 0.4 if abs(wz) > 0.9 else 0.32, wz), Vector3(0, 0, 90), -1.0, 10)
		# 侧裙甲：分段切角大板 + 上挡泥板
		for k in 3:
			var z := -0.72 + k * 0.72
			K.plate(tr, K.crect(0.7, 0.44, [0.0, 0.0, 0.1, 0.1] if k != 0 else [0.18, 0.0, 0.1, 0.1]), 0.1, M_LEG if k != 1 else M_LEG2, Vector3(side * 0.37, 0.58, z), Vector3(0, 90, 0), 0.03)
		K.plate(tr, K.crect(2.3, 0.08, [0.0, 0.0, 0.0, 0.0]), 0.7, M_LEG2, Vector3(side * 0.04, 0.83, 0), Vector3(0, 90, 0), 0.02)
		K.plate(tr, K.crect(0.6, 0.06), 0.11, M_ACC, Vector3(side * 0.43, 0.7, -0.72), Vector3(0, 90, 0), 0.006)
		A.stencil(tr, serial, Vector3(side * 0.42, 0.55, 0.5), Vector3(0, side * 90.0, 0), 0.0032, Color(0.95, 0.93, 0.88, 0.6), 64)
		leg_parts.append(tr)
	# 腰部回转轴（底盘自带，顶端是 HP-C1 母座）
	K.cy(legs, 0.3, 0.8, M_FRAME, Vector3(0, hip + 0.12, 0), Vector3.ZERO, 0.36, 20)
	K.cy(legs, 0.44, 0.1, M_DARK, Vector3(0, hip + 0.2, 0), Vector3.ZERO, 0.46, 24)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		A.hose(legs, Vector3(cos(a) * 0.32, hip + 0.24, sin(a) * 0.32), Vector3(cos(a) * 0.27, hip + 0.48, sin(a) * 0.27), Vector3(cos(a) * 0.08, 0, sin(a) * 0.08), 0.018)
	K.socket(root, "core", Vector3(0, hip + 0.55, 0), Vector3.UP)
	root.set_meta("leg_parts", leg_parts)
	root.set_meta("leg_type", "tread")
	return root
