extends RefCounted
## 外挂货架 R-14：管焊框架 + 网格底板，捆着弹药木箱、两只油桶、帆布卷，橙色棘轮绑带
## 接口：插头 HP-B1 → b1_mount → 货架；局部 +Y 远离躯干
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var c: Color = ctx.color
	var root := K.module_root("back", ctx.id, Vector3(0, -1, -0.25))
	var M_A := K.armor(c, 0.6)
	var M_DARK := K.dark()
	var top := K.b1_mount(root, M_A, 1.2)
	var M_TUBE := A.metal(Color(0.2, 0.2, 0.21))
	# 底板 + 管焊框架
	K.bb(top, Vector3(1.18, 0.04, 0.6), K.frame(), Vector3(0, 0.02, 0), Vector3.ZERO, 0.01)
	for sx in [-0.57, 0.57]:
		for sz in [-0.27, 0.27]:
			K.cy(top, 0.028, 0.66, M_TUBE, Vector3(sx, 0.35, sz), Vector3.ZERO, -1.0, 8)
		K.cy(top, 0.028, 0.56, M_TUBE, Vector3(sx, 0.68, 0), Vector3(90, 0, 0), -1.0, 8)
	for sz in [-0.27, 0.27]:
		K.cy(top, 0.028, 1.16, M_TUBE, Vector3(0, 0.68, sz), Vector3(0, 0, 90), -1.0, 8)
	# 弹药木箱（军绿）
	var M_CRATE := A.paint(Color(0.3, 0.32, 0.22), 0.0, 0.8, {"wear": 0.7, "panel_scale": 0.0})
	K.bb(top, Vector3(0.5, 0.36, 0.46), M_CRATE, Vector3(-0.28, 0.22, 0), Vector3.ZERO, 0.02)
	for sz in [-0.18, 0.18]:
		K.bb(top, Vector3(0.52, 0.38, 0.03), A.metal(Color(0.25, 0.25, 0.24)), Vector3(-0.28, 0.22, sz), Vector3.ZERO, 0.005)
	A.stencil(top, "AMMO 30MM", Vector3(-0.28, 0.25, -0.235), Vector3(0, 180, 0), 0.0026, Color(0.92, 0.88, 0.6, 0.85))
	# 两只油桶
	var M_CAN := A.paint(Color(0.42, 0.14, 0.08), 0.1, 0.6, {"wear": 0.6, "panel_scale": 0.0})
	for i in 2:
		var p := Vector3(0.14 + i * 0.2, 0.2, 0.1)
		K.bb(top, Vector3(0.16, 0.34, 0.26), M_CAN, p, Vector3.ZERO, 0.02)
		K.bb(top, Vector3(0.17, 0.02, 0.24), M_CAN, p + Vector3(0, 0.06, 0), Vector3(30, 0, 0), 0.004)
		K.bb(top, Vector3(0.17, 0.02, 0.24), M_CAN, p + Vector3(0, 0.06, 0), Vector3(-30, 0, 0), 0.004)
		K.bb(top, Vector3(0.04, 0.06, 0.14), M_DARK, p + Vector3(0, 0.2, 0.03), Vector3.ZERO, 0.008)
		K.cy(top, 0.025, 0.05, A.metal(Color(0.5, 0.5, 0.48)), p + Vector3(0, 0.19, -0.08), Vector3.ZERO, -1.0, 8)
	# 帆布卷
	var M_CANVAS := A.paint(Color(0.45, 0.42, 0.33), 0.0, 0.95, {"wear": 0.0, "panel_scale": 0.0})
	K.cy(top, 0.13, 0.5, M_CANVAS, Vector3(0.24, 0.5, -0.12), Vector3(0, 0, 90), -1.0, 16)
	# 棘轮绑带（橙）
	var M_STRAP := A.paint(Color(0.9, 0.48, 0.1), 0.0, 0.8, {"wear": 0.3, "panel_scale": 0.0})
	for sx in [-0.4, -0.16, 0.24]:
		K.bb(top, Vector3(0.04, 0.012, 0.6), M_STRAP, Vector3(sx, 0.67, 0), Vector3.ZERO, 0.002)
		for sz in [-0.3, 0.3]:
			K.bb(top, Vector3(0.04, 0.64, 0.012), M_STRAP, Vector3(sx, 0.35, sz), Vector3.ZERO, 0.002)
	K.bb(top, Vector3(0.07, 0.05, 0.03), A.metal(Color(0.5, 0.5, 0.5)), Vector3(-0.16, 0.4, -0.31), Vector3.ZERO, 0.006)
	return root
