extends RefCounted
## 30mm 链式炮 AC-30：链传动机匣 + 侧置电机、装甲防盾、后坐套筒、长身管与双室制退器、腹下弹舱双供弹
## 接口：插头 HP-A1（朝向躯干）→ a1_mount → 机匣；导出 muzzle
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var c: Color = ctx.color
	var side: float = ctx.get("side", 1.0)
	var root := K.module_root(ctx.get("slot", "arm_r"), ctx.id, Vector3(-side, 0, 0))
	var arm := K.node(root, Vector3(side * 0.25, 0, 0), Vector3.ZERO, "Body")
	var M_ARM := K.armor(c, 0.55)
	var M_ARM2 := K.armor(c.darkened(0.22), 0.55)
	var M_STEEL := A.metal(Color(0.14, 0.145, 0.15))
	var M_DARK := K.dark()
	K.a1_mount(arm, side, M_ARM)
	var sh := K.node(arm, Vector3(side * 0.14, 0.4, 0.04), Vector3(0, 0, side * -14.0))
	K.plate(sh, K.trap(0.74, 0.46, 0.24, 0.06), 0.56, M_ARM, Vector3.ZERO, Vector3(0, 90, 0), 0.04)
	K.plate(sh, K.crect(0.05, 0.26), 0.58, K.accent(), Vector3(side * 0.12, 0, 0), Vector3(0, 90, 0), 0.005)
	A.emblem(arm, Vector3(side * 0.43, 0.38, 0.06), Vector3(0, side * 90.0, side * -14.0), 0.22)
	var g := K.node(arm, Vector3(side * 0.38, -0.02, 0), Vector3.ZERO, "Gun")
	# 机匣 + 链传动罩 + 电机
	K.bb(g, Vector3(0.36, 0.4, 0.82), M_STEEL, Vector3(0, 0, -0.1), Vector3.ZERO, 0.035)
	K.bb(g, Vector3(0.3, 0.1, 0.52), M_DARK, Vector3(0, 0.25, -0.08), Vector3.ZERO, 0.02)
	K.cy(g, 0.08, 0.22, M_DARK, Vector3(side * 0.26, 0.17, 0.12), Vector3(0, 0, 90), -1.0, 16)
	K.cy(g, 0.085, 0.03, A.metal(Color(0.4, 0.4, 0.4)), Vector3(side * 0.37, 0.17, 0.12), Vector3(0, 0, 90), -1.0, 16)
	A.hose(g, Vector3(side * 0.3, 0.1, 0.12), Vector3(side * 0.19, -0.1, 0.2), Vector3(side * 0.06, -0.05, 0), 0.018)
	for sx in [-1.0, 1.0]:
		K.plate(g, K.crect(0.78, 0.34, [0.0, 0.1, 0.06, 0.0]), 0.035, M_ARM2, Vector3(sx * 0.195, -0.02, -0.1), Vector3(0, 90, 0), 0.012)
	A.vent(g, Vector3(0.36, 0.18, 0.03), Vector3(side * 0.215, 0.0, 0.1), Vector3(0, side * 90.0, 0), 4)
	# 装甲防盾（正面多边形板）
	K.plate(g, K.crect(0.52, 0.5, [0.1, 0.1, 0.14, 0.14]), 0.12, M_ARM, Vector3(0, -0.02, -0.57), Vector3.ZERO, 0.03)
	K.plate(g, K.crect(0.48, 0.05), 0.125, K.accent(), Vector3(0, 0.17, -0.57), Vector3.ZERO, 0.005)
	# 后坐套筒 + 身管 + 制退器
	K.cy(g, 0.1, 0.32, M_DARK, Vector3(0, -0.02, -0.8), Vector3(90, 0, 0), -1.0, 18)
	for zz in [-0.68, -0.92]:
		K.cy(g, 0.11, 0.03, A.metal(Color(0.35, 0.35, 0.36)), Vector3(0, -0.02, zz), Vector3(90, 0, 0), -1.0, 18)
	K.cy(g, 0.055, 1.5, M_STEEL, Vector3(0, -0.02, -1.7), Vector3(90, 0, 0), -1.0, 14)
	K.bb(g, Vector3(0.16, 0.02, 0.55), A.metal(Color(0.24, 0.25, 0.26)), Vector3(0, 0.05, -1.2), Vector3.ZERO, 0.006)
	K.bb(g, Vector3(0.2, 0.15, 0.24), M_DARK, Vector3(0, -0.02, -2.55), Vector3.ZERO, 0.02)
	for zz in [-2.5, -2.6]:
		for sx in [-1.0, 1.0]:
			K.bb(g, Vector3(0.012, 0.09, 0.04), A.metal(Color(0.02, 0.02, 0.02)), Vector3(sx * 0.1, -0.02, zz), Vector3.ZERO, 0.002)
	# 腹下弹舱 + 双供弹槽
	K.bb(g, Vector3(0.32, 0.28, 0.5), M_ARM2, Vector3(0, -0.36, 0.05), Vector3.ZERO, 0.03)
	A.stencil(g, "30x113", Vector3(side * 0.165, -0.36, 0.05), Vector3(0, side * 90.0, 0), 0.0026, Color(0.9, 0.85, 0.5, 0.85))
	for sx in [-1.0, 1.0]:
		A.hose(g, Vector3(sx * 0.12, -0.22, -0.15), Vector3(sx * 0.17, 0.0, -0.3), Vector3(sx * 0.06, -0.04, 0), 0.04, M_DARK)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	g.add_child(muzzle)
	muzzle.position = Vector3(0, -0.02, -2.7)
	root.set_meta("muzzle", muzzle)
	return root
