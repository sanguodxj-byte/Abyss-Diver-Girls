extends RefCounted
## 虫晶反应炉：约束笼 + 悬浮虫晶 + 抑制线圈
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
	K.plate(root, K.crect(0.62, 0.5, [0.1, 0.1, 0.1, 0.1]), 0.08, M_H, Vector3(0, -0.25, 0.36), Vector3(90, 0, 0), 0.02)
	K.plate(root, K.crect(0.62, 0.5, [0.1, 0.1, 0.1, 0.1]), 0.08, M_H, Vector3(0, 0.25, 0.36), Vector3(90, 0, 0), 0.02)
	for p in [Vector2(-0.26, 0.16), Vector2(0.26, 0.16), Vector2(-0.26, 0.56), Vector2(0.26, 0.56)]:
		K.cy(root, 0.025, 0.46, A.chrome(), Vector3(p.x, 0, p.y))
	for y in [-0.1, 0.1]:
		A.add(root, A.torus(0.2, 0.235, 24), A.metal(Color(0.5, 0.42, 0.25)), Vector3(0, y, 0.36), Vector3.ZERO, Vector3.ONE, false)
	# 虫晶：双锥
	var cm := A.emit(gc, 2.2)
	A.add(root, A.cyl(0.0, 0.2, 0.09, 6), cm, Vector3(0, 0.1, 0.36), Vector3(0, 15, 0), Vector3.ONE, false)
	A.add(root, A.cyl(0.09, 0.2, 0.0, 6), cm, Vector3(0, -0.1, 0.36), Vector3(0, 15, 0), Vector3.ONE, false)
	A.stencil(root, "BIOHAZARD", Vector3(0.0, 0.295, 0.36), Vector3(-90, 0, 0), 0.0025, Color(0.95, 0.85, 0.3, 0.8))
	if lights:
		K.light(root, gc, Vector3(0, 0, 0.6), 0.35, 1.8)
	return root
