extends RefCounted
## 相位护盾：发生器箱、桅杆、环形发射器
## 接口：插头 HP-B1（朝下，贴躯干顶部后方导轨）；局部 +Y 向上，+Z 向后
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var id: String = ctx.id
	var c: Color = ctx.color
	var lights: bool = ctx.get("lights", true)
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var root := K.module_root("back", id, Vector3(0, -1, -0.25))
	var M_BACK := K.armor(c, 0.6)
	var ec := Color(0.4, 0.75, 1.0)
	K.plate(root, K.crect(0.6, 0.5, [0.14, 0.1, 0.04, 0.04]), 0.8, M_BACK, Vector3(0, 0.3, 0.15), Vector3(0, 90, 0), 0.04)
	K.plate(root, K.crect(0.06, 0.3), 0.82, K.accent(), Vector3(0, 0.34, -0.05), Vector3(0, 90, 0), 0.005)
	A.vent(root, Vector3(0.5, 0.26, 0.04), Vector3(0, 0.3, 0.46), Vector3(0, 180, 0), 4)
	for sx in [-1.0, 1.0]:
		K.cy(root, 0.09, 0.42, M_DARK, Vector3(sx * 0.46, 0.3, 0.15), Vector3(90, 0, 0), -1.0, 14)
		A.add(root, A.cyl(0.05, 0.43), A.emit(ec, 1.0), Vector3(sx * 0.46, 0.3, 0.15), Vector3(90, 0, 0), Vector3.ONE, false)
	K.cy(root, 0.07, 0.7, M_DARK, Vector3(0, 0.85, 0.3))
	A.hose(root, Vector3(0.2, 0.5, 0.3), Vector3(0.08, 1.05, 0.35), Vector3(0.12, 0, 0.05), 0.022)
	var dish := K.node(root, Vector3(0, 1.22, 0.32), Vector3(-70, 0, 0))
	K.cy(dish, 0.48, 0.06, A.metal(Color(0.3, 0.3, 0.34)), Vector3.ZERO, Vector3.ZERO, 0.38, 24)
	A.add(dish, A.torus(0.3, 0.4, 32), A.emit(ec, 0.8), Vector3(0, 0.04, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(dish, A.sphere(0.1), A.emit(Color(0.7, 0.9, 1.0), 1.2), Vector3(0, 0.08, 0), Vector3.ZERO, Vector3.ONE, false)
	for i in 3:
		var a := TAU * i / 3.0
		K.cy(dish, 0.015, 0.36, M_DARK, Vector3(cos(a) * 0.2, 0.18, sin(a) * 0.2), Vector3(cos(a) * -30.0, 0, sin(a) * 30.0))
	return root
