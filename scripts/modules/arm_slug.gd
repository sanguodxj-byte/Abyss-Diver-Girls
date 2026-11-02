extends RefCounted
## 独头弹炮 SG-1：大口径单管、通风上导轨、管状弹仓 + 橡胶护木、侧挂弹托（6 发）
## 接口：插头 HP-A1（朝向躯干）→ a1_mount → 机匣；导出 muzzle
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var c: Color = ctx.color
	var side: float = ctx.get("side", 1.0)
	var root := K.module_root(ctx.get("slot", "arm_r"), ctx.id, Vector3(-side, 0, 0))
	var arm := K.node(root, Vector3(side * 0.25, 0, 0), Vector3.ZERO, "Body")
	var M_ARM := K.armor(c, 0.6)
	var M_ARM2 := K.armor(c.darkened(0.22), 0.6)
	var M_STEEL := A.metal(Color(0.14, 0.145, 0.15))
	var M_DARK := K.dark()
	K.a1_mount(arm, side, M_ARM)
	var sh := K.node(arm, Vector3(side * 0.12, 0.36, 0.02), Vector3(0, 0, side * -12.0))
	K.plate(sh, K.trap(0.6, 0.4, 0.2, 0.05), 0.48, M_ARM, Vector3.ZERO, Vector3(0, 90, 0), 0.035)
	K.plate(sh, K.crect(0.05, 0.2), 0.5, K.accent(), Vector3(side * 0.1, 0, 0), Vector3(0, 90, 0), 0.005)
	A.emblem(arm, Vector3(side * 0.36, 0.35, 0.04), Vector3(0, side * 90.0, side * -12.0), 0.2)
	var g := K.node(arm, Vector3(side * 0.36, -0.02, 0), Vector3.ZERO, "Gun")
	# 机匣：抛壳窗在外侧
	K.bb(g, Vector3(0.32, 0.36, 0.72), M_STEEL, Vector3(0, 0, -0.14), Vector3.ZERO, 0.03)
	for sx in [-1.0, 1.0]:
		K.plate(g, K.crect(0.7, 0.32, [0.08, 0.04, 0.04, 0.08]), 0.03, M_ARM, Vector3(sx * 0.175, 0.0, -0.14), Vector3(0, 90, 0), 0.01)
	K.bb(g, Vector3(0.012, 0.1, 0.24), A.metal(Color(0.02, 0.02, 0.02)), Vector3(side * 0.192, 0.07, -0.22), Vector3.ZERO, 0.003)
	K.bb(g, Vector3(0.03, 0.03, 0.06), A.chrome(), Vector3(side * 0.2, 0.07, -0.08), Vector3.ZERO, 0.005)
	# 身管 + 通风上导轨
	K.cy(g, 0.085, 1.15, A.metal(Color(0.2, 0.2, 0.21)), Vector3(0, 0.05, -1.07), Vector3(90, 0, 0), -1.0, 18)
	K.bb(g, Vector3(0.06, 0.025, 1.05), M_DARK, Vector3(0, 0.155, -1.05), Vector3.ZERO, 0.006)
	for i in 8:
		K.bb(g, Vector3(0.03, 0.03, 0.03), M_DARK, Vector3(0, 0.13, -0.6 - i * 0.13), Vector3.ZERO, 0.004)
	# 管状弹仓 + 护木（橡胶防滑环）
	K.cy(g, 0.068, 0.95, M_STEEL, Vector3(0, -0.12, -0.92), Vector3(90, 0, 0), -1.0, 14)
	K.cy(g, 0.075, 0.05, M_DARK, Vector3(0, -0.12, -1.42), Vector3(90, 0, 0), -1.0, 14)
	K.cy(g, 0.11, 0.42, A.rubber(), Vector3(0, -0.1, -0.76), Vector3(90, 0, 0), -1.0, 16)
	for i in 5:
		A.add(g, A.torus(0.1, 0.122, 16), A.rubber(), Vector3(0, -0.1, -0.6 - i * 0.08), Vector3(90, 0, 0), Vector3(1, 0.5, 1), false)
	K.bb(g, Vector3(0.2, 0.28, 0.07), M_ARM2, Vector3(0, -0.03, -1.38), Vector3.ZERO, 0.015)
	# 制退器
	K.cy(g, 0.11, 0.16, M_DARK, Vector3(0, 0.05, -1.72), Vector3(90, 0, 0), -1.0, 16)
	for i in 3:
		for sx in [-1.0, 1.0]:
			K.bb(g, Vector3(0.02, 0.05, 0.025), A.metal(Color(0.02, 0.02, 0.02)), Vector3(sx * 0.1, 0.05, -1.67 - i * 0.045), Vector3.ZERO, 0.003)
	# 侧挂弹托（外侧）
	K.bb(g, Vector3(0.04, 0.2, 0.52), M_DARK, Vector3(side * 0.21, -0.03, -0.16), Vector3.ZERO, 0.01)
	var RED := A.paint(Color(0.55, 0.12, 0.08), 0.05, 0.6, {"wear": 0.3, "panel_scale": 0.0})
	var BRASS := A.paint(Color(0.72, 0.55, 0.22), 0.8, 0.35, {"wear": 0.2, "panel_scale": 0.0})
	for i in 6:
		var z := -0.36 + i * 0.08
		K.cy(g, 0.032, 0.15, RED, Vector3(side * 0.25, -0.01, z), Vector3.ZERO, -1.0, 10)
		K.cy(g, 0.034, 0.04, BRASS, Vector3(side * 0.25, -0.1, z), Vector3.ZERO, -1.0, 10)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	g.add_child(muzzle)
	muzzle.position = Vector3(0, 0.05, -1.82)
	root.set_meta("muzzle", muzzle)
	return root
