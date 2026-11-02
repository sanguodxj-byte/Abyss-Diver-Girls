extends RefCounted
## 电池组 B-40：6 节电芯阵列 + 电量指示条
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
	for i in 3:
		for j in 2:
			var p := Vector3(-0.23 + i * 0.23, 0.13 - j * 0.26, 0.3)
			K.cy(root, 0.1, 0.34, M_H, p, Vector3(90, 0, 0), -1.0, 16)
			K.cy(root, 0.07, 0.03, A.emit(gc, 1.6), p + Vector3(0, 0, 0.18), Vector3(90, 0, 0), -1.0, 12)
			K.cy(root, 0.106, 0.03, M_DARK, p + Vector3(0, 0, 0.08), Vector3(90, 0, 0), -1.0, 16)
	for sx in [-1.0, 1.0]:
		K.plate(root, K.crect(0.44, 0.62, [0.0, 0.1, 0.1, 0.0]), 0.06, M_H, Vector3(sx * 0.39, 0, 0.3), Vector3(0, 90, 0), 0.015)
	K.bb(root, Vector3(0.7, 0.04, 0.4), M_FRAME, Vector3(0, 0.0, 0.3), Vector3.ZERO, 0.01)
	A.hose(root, Vector3(-0.36, -0.28, 0.12), Vector3(-0.2, -0.32, 0.45), Vector3(0, -0.08, 0), 0.025, A.paint(Color(0.46, 0.22, 0.18), 0.0, 0.6))
	A.hose(root, Vector3(0.36, -0.28, 0.12), Vector3(0.2, -0.32, 0.45), Vector3(0, -0.08, 0), 0.025)
	A.stencil(root, "B-40  48V", Vector3(0.417, 0.0, 0.3), Vector3(0, 90, 0), 0.0028, Color(0.92, 0.9, 0.85, 0.75))
	if lights:
		K.light(root, gc, Vector3(0, 0, 0.7), 0.25, 1.6)
	return root
