extends RefCounted
## 悬浮底盘 Skimmer：分段裙甲、进气格栅、推力环
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
	hip = 1.2
	# 气垫船体：分段裙甲 + 进气格栅 + 推力环
	K.cy(legs, 0.85, 0.55, M_LEG, Vector3(0, 0.78, 0), Vector3.ZERO, 1.05, 16)
	K.cy(legs, 1.12, 0.14, M_DARK, Vector3(0, 0.48, 0), Vector3.ZERO, 1.14, 32)
	K.cy(legs, 1.16, 0.2, A.rubber(), Vector3(0, 0.34, 0), Vector3.ZERO, 1.08, 32)
	A.add(legs, A.torus(0.92, 1.02, 48), A.emit(Color(0.3, 0.85, 1.0), 2.2), Vector3(0, 0.25, 0), Vector3.ZERO, Vector3(1, 0.4, 1), false)
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		var sk := Node3D.new()
		sk.position = Vector3(cos(a) * 1.0, 0.72, sin(a) * 1.0)
		sk.rotation.y = -a + PI / 2.0
		legs.add_child(sk)
		K.plate(sk, K.trap(0.82, 0.6, 0.46, 0.06), 0.1, M_LEG2 if i % 2 else M_LEG, Vector3.ZERO, Vector3(-14, 0, 0), 0.03)
		if i % 2 == 0:
			K.holes(sk, Vector3(0, 0.0, -0.06), Vector3(-14, 0, 0), 4, 1, 0.09, 0.022)
		else:
			K.plate(sk, K.crect(0.06, 0.3), 0.11, M_ACC, Vector3(0.24, 0.0, 0.0), Vector3(-14, 0, 0), 0.006)
	K.plate(legs, K.crect(1.5, 1.5, [0.44, 0.44, 0.44, 0.44]), 0.25, M_FRAME, Vector3(0, 1.15, 0), Vector3(90, 0, 0), 0.05)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		K.cy(legs, 0.2, 0.25, M_DARK, Vector3(cos(a) * 0.6, 0.4, sin(a) * 0.6), Vector3.ZERO, 0.26)
		A.add(legs, A.cyl(0.15, 0.05), A.emit(Color(0.4, 0.9, 1.0), 4.0), Vector3(cos(a) * 0.6, 0.27, sin(a) * 0.6), Vector3.ZERO, Vector3.ONE, false)
	if lights:
		K.light(legs, Color(0.3, 0.8, 1.0), Vector3(0, 0.15, 0), 0.8, 2.5)
		A.emitter(legs, Vector3(0, 0.1, 0), {"amount": 14, "life": 0.6, "size": 0.9, "tex": A.smoke_tex(), "additive": false,
			"dir": Vector3(0, 0, 0), "spread": 180.0, "vmin": 2.0, "vmax": 3.5, "gravity": Vector3.ZERO, "radius": 0.7,
			"c0": Color(0.7, 0.68, 0.62, 0.35), "c1": Color(0.6, 0.55, 0.5, 0.0), "grow0": 0.5, "grow1": 1.6})
	leg_parts.append(legs)

	# 腰部回转轴（底盘自带，顶端是 HP-C1 母座）
	K.cy(legs, 0.3, 0.8, M_FRAME, Vector3(0, hip + 0.12, 0), Vector3.ZERO, 0.36, 20)
	K.cy(legs, 0.44, 0.1, M_DARK, Vector3(0, hip + 0.2, 0), Vector3.ZERO, 0.46, 24)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		A.hose(legs, Vector3(cos(a) * 0.32, hip + 0.24, sin(a) * 0.32), Vector3(cos(a) * 0.27, hip + 0.48, sin(a) * 0.27), Vector3(cos(a) * 0.08, 0, sin(a) * 0.08), 0.018)
	K.socket(root, "core", Vector3(0, hip + 0.55, 0), Vector3.UP)
	root.set_meta("leg_parts", leg_parts)
	root.set_meta("leg_type", "hover")
	return root
