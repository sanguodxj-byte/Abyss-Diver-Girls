extends RefCounted
## 货运背包：货架 + 绑带货箱
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
	var M_STRAP := A.paint(Color(0.12, 0.12, 0.1), 0.0, 0.85, {"wear": 0.0})
	# 货架底板 + 立柱
	# 货架：底板向后伸出，货箱主要挂在机背后方，不挡座舱
	K.bb(root, Vector3(1.2, 0.07, 1.0), M_FRAME, Vector3(0, 0.08, 0.3), Vector3.ZERO, 0.02)
	for p in [Vector2(-0.58, 0.78), Vector2(0.58, 0.78)]:
		K.bb(root, Vector3(0.06, 0.55, 0.06), M_FRAME, Vector3(p.x, 0.36, p.y), Vector3.ZERO, 0.01)
	K.bb(root, Vector3(1.22, 0.06, 0.06), M_FRAME, Vector3(0, 0.62, 0.78), Vector3.ZERO, 0.01)
	# 主货箱（切角军用箱）+ 顶部弹药箱
	K.plate(root, K.crect(0.8, 0.5, [0.08, 0.08, 0.08, 0.08]), 1.05, M_BACK, Vector3(0, 0.36, 0.35), Vector3(0, 90, 0), 0.03)
	K.plate(root, K.crect(0.6, 0.06), 1.07, K.accent(), Vector3(0, 0.5, 0.35), Vector3(0, 90, 0), 0.005)
	var M_OLIVE := A.paint(Color(0.3, 0.32, 0.26), 0.05, 0.75, {"wear": 0.45, "panel_scale": 0.0})
	K.plate(root, K.crect(0.48, 0.22, [0.05, 0.05, 0.03, 0.03]), 0.6, M_OLIVE, Vector3(0.18, 0.72, 0.4), Vector3(0, 98, 0), 0.02)
	K.plate(root, K.crect(0.3, 0.18, [0.04, 0.04, 0.02, 0.02]), 0.32, M_DARK, Vector3(-0.32, 0.7, 0.45), Vector3(0, 78, 0), 0.015)
	for sx in [-0.3, 0.3]:
		K.bb(root, Vector3(0.06, 0.52, 0.82), M_STRAP, Vector3(sx, 0.36, 0.35), Vector3.ZERO, 0.01)
		A.add(root, A.bevel_box(Vector3(0.1, 0.08, 0.04), 0.01), A.chrome(), Vector3(sx, 0.42, 0.775), Vector3.ZERO, Vector3.ONE, false)
	A.stencil(root, "CARGO 10KG", Vector3(0, 0.3, 0.765), Vector3.ZERO, 0.0035, Color(0.1, 0.1, 0.1, 0.8))
	A.stencil(root, "MAX LOAD", Vector3(0.53, 0.3, 0.35), Vector3(0, 90, 0), 0.0028, Color(0.92, 0.9, 0.85, 0.7))
	return root
