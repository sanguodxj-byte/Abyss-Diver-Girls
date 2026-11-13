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
	var sh := K.node(arm, Vector3(side * 0.24, 0.52, 0.05), Vector3(0, 0, side * -12.0))
	K.plate(sh, K.trap(1.10, 0.78, 0.34, 0.08), 0.84, M_ARM, Vector3.ZERO, Vector3(0, 90, 0), 0.045)
	K.plate(sh, K.crect(0.065, 0.30), 0.78, K.accent(), Vector3(side * 0.16, 0, 0), Vector3(0, 90, 0), 0.006)
	K.grab_iron(sh, 0.26, 0.045, Vector3(0, 0.18, 0), Vector3(-90, 90, 0))
	A.emblem(arm, Vector3(side * 0.56, 0.50, 0.08), Vector3(0, side * 90.0, side * -12.0), 0.26)
	var g := K.node(arm, Vector3(side * 0.54, -0.04, 0), Vector3.ZERO, "Gun")
	# 炮尾 + 楔形炮闩 + 重型摇架（收敛过度肥大尺寸，强化105mm坦克炮修长工业威慑感）
	K.bb(g, Vector3(0.68, 0.80, 1.16), M_STEEL, Vector3(0, 0, 0.05), Vector3.ZERO, 0.10)
	K.bb(g, Vector3(0.52, 0.52, 0.34), K.gunmetal(), Vector3(0, 0, 0.76), Vector3.ZERO, 0.03)
	K.cy(g, 0.05, 0.62, A.chrome(), Vector3(0, 0.14, 0.94), Vector3(0, 0, 90), -1.0, 10)
	for sx in [-1.0, 1.0]:
		K.plate(g, K.crect(1.12, 0.70, [0.12, 0.08, 0.08, 0.12]), 0.08, M_ARM, Vector3(sx * 0.38, 0.0, 0.05), Vector3(0, 90, 0), 0.015)
	A.rivets(g, Vector3(side * 0.425, 0.26, -0.40), Vector3(side * 0.425, 0.26, 0.50), 8, 0.018, Vector3(0, 0, 90))
	K.number(g, ctx.get("serial", "00"), Vector3(side * 0.425, -0.08, 0.10), Vector3(0, side * 90.0, 0), 0.0044)
	# 上置双液压驻退复进机 + 炮盾顶置激光测距仪箱
	for sx in [-1.0, 1.0]:
		K.cy(g, 0.105, 0.96, M_DARK, Vector3(sx * 0.20, 0.44, -0.28), Vector3(90, 0, 0), -1.0, 14)
		K.cy(g, 0.068, 0.24, A.chrome(), Vector3(sx * 0.20, 0.44, -0.88), Vector3(90, 0, 0), -1.0, 10)
	K.bb(g, Vector3(0.28, 0.16, 0.30), M_ARM2, Vector3(0, 0.56, -0.52), Vector3.ZERO, 0.02)
	A.lens(g, Vector3(-0.05, 0.56, -0.675), Vector3(-90, 0, 0), 0.032, Color(0.28, 0.85, 0.62), 1.4)
	A.lens(g, Vector3(0.06, 0.56, -0.675), Vector3(-90, 0, 0), 0.022, Color(0.95, 0.72, 0.20), 1.2)
	# 铸造楔形炮盾
	K.plate(g, K.crect(1.02, 0.94, [0.18, 0.18, 0.22, 0.22]), 0.28, M_ARM, Vector3(0, 0.04, -0.64), Vector3.ZERO, 0.045)
	K.plate(g, K.crect(0.92, 0.075), 0.29, K.accent(), Vector3(0, 0.42, -0.64), Vector3.ZERO, 0.006)
	# 105mm 热护套长身管 + 箍带 + 偏心抽烟装置 + 双室冲击式炮口制退器与深膛孔
	K.cy(g, 0.21, 0.30, M_DARK, Vector3(0, 0.0, -0.92), Vector3(90, 0, 0), -1.0, 20)
	K.cy(g, 0.145, 1.92, M_ARM2, Vector3(0, 0.0, -1.92), Vector3(90, 0, 0), 0.125, 22)
	for strap_z in [-1.20, -2.28, -2.62]:
		K.cy(g, 0.148, 0.035, M_DARK, Vector3(0, 0.0, strap_z), Vector3(90, 0, 0), -1.0, 20)
	# 抽烟装置（Bore Evacuator）
	K.cy(g, 0.21, 0.48, M_ARM, Vector3(0, 0.015, -1.72), Vector3(90, 0, 0), -1.0, 20)
	for zz in [-1.48, -1.96]:
		K.cy(g, 0.22, 0.045, M_DARK, Vector3(0, 0.015, zz), Vector3(90, 0, 0), -1.0, 20)
	# 精工双室T型炮口制退器 + 膛口基准镜 + 105mm深黑线膛孔
	K.muzzle_brake(g, 0.19, 0.48, M_DARK, Vector3(0, 0.0, -3.04), 2)
	K.bb(g, Vector3(0.04, 0.08, 0.05), K.gunmetal(), Vector3(0, 0.17, -2.84), Vector3.ZERO, 0.005)
	# 侧挂备弹架（外侧 4 发黄铜药筒穿甲弹）
	var BRASS := K.brass()
	var TIP := A.paint(Color(0.28, 0.31, 0.23), 0.2, 0.56, {"wear": 0.4, "panel_scale": 0.0})
	K.bb(g, Vector3(0.06, 0.46, 0.78), M_DARK, Vector3(side * 0.45, -0.08, 0.05), Vector3.ZERO, 0.012)
	for i in 4:
		var y := -0.22 + (i % 2) * 0.16
		var x := side * (0.53 + (i / 2) * 0.14)
		K.cy(g, 0.058, 0.48, BRASS, Vector3(x, y, 0.15), Vector3(90, 0, 0), -1.0, 12)
		K.cy(g, 0.058, 0.22, TIP, Vector3(x, y, -0.20), Vector3(-90, 0, 0), 0.018, 12)
	for zz in [-0.08, 0.30]:
		K.bb(g, Vector3(0.32, 0.40, 0.035), M_DARK, Vector3(side * 0.59, -0.14, zz), Vector3.ZERO, 0.008)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	g.add_child(muzzle)
	muzzle.position = Vector3(0, 0, -3.3)
	root.set_meta("muzzle", muzzle)
	return root
