extends RefCounted
## 微型反应堆：圆柱压力容器、径向散热片、冷却回路
## 接口：插头 HP-G1（朝前，插入躯干背面动力舱）；局部 +Z 向后
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var id: String = ctx.id
	var c: Color = ctx.color
	var lights: bool = ctx.get("lights", true)
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var root := K.module_root("gen", id, Vector3.FORWARD)
	var gc: Color = ctx.info.color
	var M_H := K.armor(c, 0.5)
	K.plate(root, K.crect(0.78, 0.62, [0.12, 0.12, 0.12, 0.12]), 0.1, M_FRAME, Vector3(0, 0, 0.1), Vector3.ZERO, 0.025)
	K.cy(root, 0.24, 0.42, M_H, Vector3(0, 0, 0.34), Vector3(90, 0, 0), -1.0, 24)
	K.cy(root, 0.26, 0.05, M_DARK, Vector3(0, 0, 0.16), Vector3(90, 0, 0), -1.0, 24)
	K.cy(root, 0.26, 0.05, M_DARK, Vector3(0, 0, 0.53), Vector3(90, 0, 0), -1.0, 24)
	# 视窗环（发光反应核）
	A.add(root, A.torus(0.2, 0.25, 32), A.emit(gc, 2.0), Vector3(0, 0, 0.56), Vector3(90, 0, 0), Vector3(1, 0.4, 1), false)
	K.cy(root, 0.13, 0.02, A.emit(gc, 2.6), Vector3(0, 0, 0.565), Vector3(90, 0, 0), -1.0, 20)
	for i in 10:
		var a := TAU * i / 10.0
		K.bb(root, Vector3(0.02, 0.1, 0.34), A.metal(Color(0.3, 0.31, 0.33)), Vector3(cos(a) * 0.29, sin(a) * 0.29, 0.34), Vector3(0, 0, rad_to_deg(a) + 90.0), 0.005)
	for sx in [-1.0, 1.0]:
		A.hose(root, Vector3(sx * 0.3, 0.22, 0.12), Vector3(sx * 0.22, 0.2, 0.5), Vector3(sx * 0.1, 0.06, 0), 0.026, A.paint(Color(0.14, 0.3, 0.45), 0.1, 0.6))
	A.stencil(root, "RADIATION", Vector3(0, -0.27, 0.3), Vector3(90, 180, 0), 0.0025, Color(0.95, 0.85, 0.3, 0.8))
	if lights:
		K.light(root, gc, Vector3(0, 0, 0.8), 0.3, 1.8)
	return root
