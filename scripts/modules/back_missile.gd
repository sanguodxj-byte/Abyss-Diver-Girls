extends RefCounted
## 蜂巢导弹：双联装 6 发发射巢，带挂架与装填门
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
	var M_WARHEAD := A.paint(Color(0.56, 0.30, 0.24), 0.1, 0.5, {"panel_scale": 0.0})
	# 横梁 + 两侧挂架
	K.bb(root, Vector3(1.5, 0.12, 0.22), M_FRAME, Vector3(0, 0.12, 0.1), Vector3.ZERO, 0.03)
	for sx in [-1.0, 1.0]:
		K.piston(root, Vector3(sx * 0.3, 0.1, 0.1), Vector3(sx * 0.68, 0.28, 0.2), 0.03)
		var pod := K.node(root, Vector3(sx * 0.74, 0.42, 0.18), Vector3(-18, 0, 0))
		K.plate(pod, K.crect(0.9, 0.5, [0.18, 0.06, 0.04, 0.04]), 0.62, M_BACK, Vector3.ZERO, Vector3(0, 90, 0), 0.04)
		K.plate(pod, K.crect(0.5, 0.3, [0.06, 0.0, 0.0, 0.06]), 0.66, K.armor(c.darkened(0.25)), Vector3(0, -0.02, 0.18), Vector3(0, 90, 0), 0.02)
		K.bb(pod, Vector3(0.52, 0.42, 0.04), M_FRAME, Vector3(0, 0, -0.46), Vector3.ZERO, 0.01)
		for i in 3:
			for j in 2:
				var mp := Vector3(-0.17 + i * 0.17, 0.1 - j * 0.2, -0.47)
				K.cy(pod, 0.065, 0.04, A.metal(Color(0.08, 0.08, 0.08)), mp, Vector3(90, 0, 0), -1.0, 10)
				A.add(pod, A.cyl(0.04, 0.05, 0.065, 8), M_WARHEAD, mp + Vector3(0, 0, 0.02), Vector3(-90, 0, 0), Vector3.ONE, false)
		K.plate(pod, K.crect(0.5, 0.05), 0.64, K.accent(), Vector3(0, 0.17, 0.1), Vector3(0, 90, 0), 0.005)
		A.rivets(pod, Vector3(sx * 0.32, 0.18, -0.35), Vector3(sx * 0.32, 0.18, 0.35), 5, 0.015, Vector3(0, 0, 90))
		A.vent(pod, Vector3(0.4, 0.2, 0.04), Vector3(0, 0.0, 0.46), Vector3(0, 180, 0), 3)
		A.stencil(pod, "ROCKET", Vector3(sx * 0.315, 0.0, 0.0), Vector3(0, sx * 90.0, 0), 0.003, Color(0.62, 0.56, 0.30, 0.8))
	return root
