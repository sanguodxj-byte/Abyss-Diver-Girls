extends RefCounted
## 货运背包：货架 + 绑带货箱
## 接口：插头 HP-B1（朝下，贴躯干顶部后方导轨）；局部 +Y 向上，+Z 向后
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var id: String = ctx.id
	var c: Color = ctx.color
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var M_GUN := K.gunmetal()
	var root := K.module_root("back", id, Vector3(0, -1, -0.25))
	var M_BACK := K.armor(c, 0.56)
	var M_SUB := K.armor_sub(c, 0.58)
	var M_STRAP := A.paint(Color(0.28, 0.26, 0.18), 0.0, 0.88, {"wear": 0.25, "panel_scale": 0.0})
	# 重型货架底梁 + 双导轨卡箍 + 斜撑三角肋（消除悬空单薄平板感）
	K.bb(root, Vector3(0.86, 0.18, 0.48), M_FRAME, Vector3(0, 0.02, 0.09), Vector3.ZERO, 0.022)
	K.bb(root, Vector3(1.24, 0.09, 1.02), M_FRAME, Vector3(0, 0.08, 0.32), Vector3.ZERO, 0.022)
	for sx in [-0.46, 0.46]:
		K.piston(root, Vector3(sx, -0.10, 0.08), Vector3(sx, 0.06, 0.68), 0.024)
	for sx in [-0.59, 0.59]:
		K.bb(root, Vector3(0.065, 0.58, 0.065), M_GUN, Vector3(sx, 0.37, 0.80), Vector3.ZERO, 0.012)
		K.bb(root, Vector3(0.05, 0.32, 0.05), M_FRAME, Vector3(sx, 0.23, 0.06), Vector3.ZERO, 0.01)
		K.grab_iron(root, 0.22, 0.045, Vector3(sx + signf(sx) * 0.03, 0.10, 0.36), Vector3(0, -signf(sx) * 90.0, 0))
	K.bb(root, Vector3(1.24, 0.06, 0.06), M_GUN, Vector3(0, 0.64, 0.80), Vector3.ZERO, 0.012)
	# 主野战装甲转运箱：加强压筋、四角吊装护角、双搭扣锁闩
	K.plate(root, K.crect(0.80, 0.50, [0.07, 0.07, 0.07, 0.07]), 1.06, M_BACK, Vector3(0, 0.37, 0.35), Vector3(0, 90, 0), 0.03)
	K.bb(root, Vector3(1.08, 0.07, 0.82), M_SUB, Vector3(0, 0.54, 0.35), Vector3.ZERO, 0.016)
	for ix in [-0.36, -0.12, 0.12, 0.36]:
		K.bb(root, Vector3(0.035, 0.36, 0.815), M_SUB, Vector3(ix, 0.34, 0.35), Vector3.ZERO, 0.008)
	for cx in [-0.52, 0.52]:
		for cz in [-0.04, 0.74]:
			K.bb(root, Vector3(0.09, 0.09, 0.09), M_DARK, Vector3(cx, 0.58, cz), Vector3.ZERO, 0.012)
	K.plate(root, K.crect(0.58, 0.05), 1.08, K.accent(), Vector3(0, 0.49, 0.35), Vector3(0, 90, 0), 0.005)
	# 顶部副弹药箱 + 防水卷布包
	var M_OLIVE := A.paint(Color(0.28, 0.31, 0.24), 0.08, 0.72, {"wear": 0.48, "panel_scale": 0.0})
	K.plate(root, K.crect(0.46, 0.22, [0.04, 0.04, 0.02, 0.02]), 0.60, M_OLIVE, Vector3(0.20, 0.72, 0.39), Vector3(0, 95, 0), 0.02)
	for lx in [0.04, 0.36]:
		K.bb(root, Vector3(0.04, 0.09, 0.025), A.chrome(), Vector3(lx, 0.72, 0.625), Vector3.ZERO, 0.004)
	K.plate(root, K.crect(0.30, 0.18, [0.04, 0.04, 0.02, 0.02]), 0.34, M_DARK, Vector3(-0.33, 0.70, 0.44), Vector3(0, 82, 0), 0.015)
	# 军规织带 + 棘轮紧固器
	for sx in [-0.30, 0.30]:
		K.bb(root, Vector3(0.055, 0.54, 0.85), M_STRAP, Vector3(sx, 0.37, 0.35), Vector3.ZERO, 0.008)
		K.bb(root, Vector3(0.09, 0.11, 0.05), M_GUN, Vector3(sx, 0.42, 0.785), Vector3.ZERO, 0.01)
		K.cy(root, 0.022, 0.11, K.brass(), Vector3(sx, 0.42, 0.805), Vector3(0, 0, 90), -1.0, 8)
	A.stencil(root, "CARGO 10T", Vector3(0, 0.31, 0.762), Vector3.ZERO, 0.0032, Color(0.88, 0.86, 0.80, 0.78))
	A.stencil(root, "MAX LOAD", Vector3(0.545, 0.31, 0.35), Vector3(0, 90, 0), 0.0028, Color(0.90, 0.88, 0.82, 0.72))
	return root
