extends RefCounted
## 氢燃料电池堆 HFC-180：两只卧式高压储氢罐（箍带 + 阀门）、层叠电堆（端板 + 拉杆）、冷却液管
## 接口：插头 HP-G1（朝前插入动力舱）→ g1_mount → 罐组与电堆；局部 +Z 向后
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var c: Color = ctx.color
	var lights: bool = ctx.get("lights", true)
	var root := K.module_root("gen", ctx.id, Vector3.FORWARD)
	var M_H := K.armor(c, 0.45)
	var M_DARK := K.dark()
	var b := K.g1_mount(root, M_H, 0.82, 0.66)
	# 罐座
	K.bb(b, Vector3(0.7, 0.56, 0.06), K.frame(), Vector3(0, 0, 0.03), Vector3.ZERO, 0.015)
	var M_TANK := A.paint(Color(0.62, 0.64, 0.62), 0.3, 0.45, {"wear": 0.35, "panel_scale": 0.0})
	for sy in [-1.0, 1.0]:
		var y: float = sy * 0.15
		K.cy(b, 0.13, 0.5, M_TANK, Vector3(0, y, 0.2), Vector3(0, 0, 90), -1.0, 20)
		for sx in [-1.0, 1.0]:
			A.add(b, A.sphere(0.13, 0.26, 16), M_TANK, Vector3(sx * 0.25, y, 0.2), Vector3.ZERO, Vector3(0.5, 1, 1))
		for sx in [-0.15, 0.15]:
			K.cy(b, 0.137, 0.04, M_DARK, Vector3(sx, y, 0.2), Vector3(0, 0, 90), -1.0, 20)
			K.bb(b, Vector3(0.04, 0.03, 0.17), M_DARK, Vector3(sx, y, 0.1), Vector3.ZERO, 0.005)
		K.cy(b, 0.03, 0.08, A.chrome(), Vector3(0.38, y, 0.2), Vector3(0, 0, 90), -1.0, 10)
		K.cy(b, 0.04, 0.02, A.paint(Color(0.15, 0.35, 0.6), 0.1, 0.6, {"panel_scale": 0.0}), Vector3(0.42, y, 0.2), Vector3(0, 0, 90), -1.0, 10)
	A.stencil(b, "H2  700 BAR", Vector3(0, 0.15, 0.333), Vector3(0, 0, 0), 0.0024, Color(0.12, 0.2, 0.45, 0.9))
	A.stencil(b, "FLAMMABLE", Vector3(0, -0.15, 0.333), Vector3(0, 0, 0), 0.0024, Color(0.75, 0.15, 0.08, 0.9))
	# 层叠电堆（罐组后方）：端板 + 薄片 + 拉杆
	var M_PLATE_A := A.metal(Color(0.24, 0.25, 0.27))
	var M_PLATE_B := A.paint(Color(0.12, 0.13, 0.14), 0.2, 0.6, {"panel_scale": 0.0})
	K.bb(b, Vector3(0.52, 0.5, 0.05), M_H, Vector3(0, 0, 0.38), Vector3.ZERO, 0.01)
	for i in 14:
		K.bb(b, Vector3(0.46, 0.44, 0.012), M_PLATE_A if i % 2 == 0 else M_PLATE_B, Vector3(0, 0, 0.415 + i * 0.016), Vector3.ZERO, 0.002)
	K.bb(b, Vector3(0.52, 0.5, 0.05), M_H, Vector3(0, 0, 0.66), Vector3.ZERO, 0.01)
	for cx in [-0.22, 0.22]:
		for cy_ in [-0.21, 0.21]:
			K.cy(b, 0.014, 0.34, A.chrome(), Vector3(cx, cy_, 0.52), Vector3(90, 0, 0), -1.0, 8)
	K.bb(b, Vector3(0.46, 0.04, 0.24), K.accent(), Vector3(0, 0.25, 0.52), Vector3.ZERO, 0.005)
	# 冷却液管
	var M_COOL := A.paint(Color(0.14, 0.3, 0.45), 0.1, 0.6, {"panel_scale": 0.0})
	for sx in [-1.0, 1.0]:
		A.hose(b, Vector3(sx * 0.26, -0.18, 0.66), Vector3(sx * 0.33, -0.25, 0.08), Vector3(sx * 0.06, -0.04, 0), 0.022, M_COOL)
	K.bb(b, Vector3(0.04, 0.02, 0.01), A.emit(Color(0.4, 1.0, 0.5), 2.0), Vector3(0.18, -0.18, 0.69), Vector3.ZERO, 0.003)
	return root
