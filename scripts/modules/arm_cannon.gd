extends RefCounted
## 105mm 臂载加农炮 HC-105：加粗双层法兰 + 三角加强筋、厚炮盾、双后坐筒、长身管 + 抽烟装置、双室制退器、侧挂炮弹架
## 接口：插头 HP-A1 → a1_mount（加强）→ 炮尾；导出 muzzle
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
	K.heavy_gussets(arm, side, M_ARM2)
	var sh := K.node(arm, Vector3(side * 0.3, 0.6, 0.05), Vector3(0, 0, side * -12.0))
	K.plate(sh, K.trap(1.3, 0.9, 0.4, 0.1), 1.0, M_ARM, Vector3.ZERO, Vector3(0, 90, 0), 0.05)
	K.plate(sh, K.crect(0.07, 0.34), 0.82, K.accent(), Vector3(side * 0.18, 0, 0), Vector3(0, 90, 0), 0.006)
	A.emblem(arm, Vector3(side * 0.71, 0.58, 0.08), Vector3(0, side * 90.0, side * -12.0), 0.3)
	var g := K.node(arm, Vector3(side * 0.66, -0.04, 0), Vector3.ZERO, "Gun")
	# 炮尾 + 炮闩 + 摇架
	K.bb(g, Vector3(0.82, 0.96, 1.2), M_STEEL, Vector3(0, 0, 0.05), Vector3.ZERO, 0.14)
	K.bb(g, Vector3(0.6, 0.6, 0.34), A.metal(Color(0.32, 0.32, 0.33)), Vector3(0, 0, 0.78), Vector3.ZERO, 0.03)
	K.cy(g, 0.06, 0.7, A.chrome(), Vector3(0, 0.16, 0.96), Vector3(0, 0, 90), -1.0, 10)
	for sx in [-1.0, 1.0]:
		K.plate(g, K.crect(1.16, 0.82, [0.14, 0.08, 0.08, 0.14]), 0.1, M_ARM, Vector3(sx * 0.46, 0.0, 0.05), Vector3(0, 90, 0), 0.015)
	A.rivets(g, Vector3(side * 0.515, 0.32, -0.42), Vector3(side * 0.515, 0.32, 0.52), 8, 0.02, Vector3(0, 0, 90))
	K.number(g, ctx.get("serial", "00"), Vector3(side * 0.515, -0.1, 0.1), Vector3(0, side * 90.0, 0), 0.005)
	# 双后坐筒（上方两侧）
	for sx in [-1.0, 1.0]:
		K.cy(g, 0.13, 1.0, M_DARK, Vector3(sx * 0.24, 0.52, -0.3), Vector3(90, 0, 0), -1.0, 14)
		K.cy(g, 0.08, 0.26, A.chrome(), Vector3(sx * 0.24, 0.52, -0.92), Vector3(90, 0, 0), -1.0, 10)
	# 厚炮盾
	K.plate(g, K.crect(1.2, 1.12, [0.2, 0.2, 0.24, 0.24]), 0.32, M_ARM, Vector3(0, 0.06, -0.66), Vector3.ZERO, 0.05)
	K.plate(g, K.crect(1.1, 0.09), 0.325, K.accent(), Vector3(0, 0.5, -0.66), Vector3.ZERO, 0.006)
	# 身管 + 抽烟装置 + 制退器
	K.cy(g, 0.26, 0.3, M_DARK, Vector3(0, 0.0, -0.96), Vector3(90, 0, 0), -1.0, 20)
	K.cy(g, 0.23, 1.7, M_STEEL, Vector3(0, 0.0, -1.85), Vector3(90, 0, 0), 0.2, 24)
	K.cy(g, 0.31, 0.5, A.metal(Color(0.24, 0.25, 0.26)), Vector3(0, 0.0, -1.7), Vector3(90, 0, 0), -1.0, 20)
	for zz in [-1.46, -1.94]:
		K.cy(g, 0.32, 0.05, M_DARK, Vector3(0, 0, zz), Vector3(90, 0, 0), -1.0, 20)
	K.bb(g, Vector3(0.68, 0.6, 0.6), M_DARK, Vector3(0, 0.0, -2.96), Vector3.ZERO, 0.03)
	for zz in [-2.84, -3.06]:
		for sx in [-1.0, 1.0]:
			K.bb(g, Vector3(0.02, 0.3, 0.1), A.metal(Color(0.02, 0.02, 0.02)), Vector3(sx * 0.33, 0.0, zz), Vector3.ZERO, 0.003)
	# 侧挂炮弹架（外侧 4 发）
	var BRASS := A.paint(Color(0.72, 0.55, 0.22), 0.8, 0.35, {"wear": 0.2, "panel_scale": 0.0})
	var TIP := A.paint(Color(0.3, 0.33, 0.24), 0.2, 0.6, {"wear": 0.4, "panel_scale": 0.0})
	K.bb(g, Vector3(0.06, 0.5, 0.8), M_DARK, Vector3(side * 0.54, -0.08, 0.05), Vector3.ZERO, 0.012)
	for i in 4:
		var y := -0.24 + (i % 2) * 0.17
		var x := side * (0.63 + (i / 2) * 0.15)
		K.cy(g, 0.065, 0.5, BRASS, Vector3(x, y, 0.15), Vector3(90, 0, 0), -1.0, 12)
		K.cy(g, 0.065, 0.24, TIP, Vector3(x, y, -0.22), Vector3(-90, 0, 0), 0.02, 12)
	for zz in [-0.1, 0.3]:
		K.bb(g, Vector3(0.36, 0.44, 0.04), M_DARK, Vector3(side * 0.7, -0.16, zz), Vector3.ZERO, 0.008)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	g.add_child(muzzle)
	muzzle.position = Vector3(0, 0, -3.3)
	root.set_meta("muzzle", muzzle)
	return root
