extends RefCounted
## 重型转管炮 GAU-H：加强法兰 + 加强筋、厚机匣 + 驱动电机、外侧超大弹鼓 + 节段供弹槽、七管转管 + 三道管箍
## 接口：插头 HP-A1 → a1_mount（加强）→ 机匣；导出 muzzle
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
	var sh := K.node(arm, Vector3(side * 0.3, 0.58, 0.05), Vector3(0, 0, side * -12.0))
	K.plate(sh, K.trap(1.3, 0.9, 0.4, 0.1), 1.0, M_ARM, Vector3.ZERO, Vector3(0, 90, 0), 0.05)
	K.plate(sh, K.crect(0.07, 0.32), 0.78, K.accent(), Vector3(side * 0.17, 0, 0), Vector3(0, 90, 0), 0.006)
	A.emblem(arm, Vector3(side * 0.68, 0.56, 0.08), Vector3(0, side * 90.0, side * -12.0), 0.28)
	var g := K.node(arm, Vector3(side * 0.66, -0.04, 0), Vector3.ZERO, "Gun")
	# 机匣 + 驱动电机
	K.bb(g, Vector3(0.82, 0.94, 1.1), M_STEEL, Vector3(0, 0, 0.0), Vector3.ZERO, 0.05)
	for sx in [-1.0, 1.0]:
		K.plate(g, K.crect(1.06, 0.8, [0.0, 0.16, 0.1, 0.0]), 0.1, M_ARM2, Vector3(sx * 0.46, 0.0, 0.0), Vector3(0, 90, 0), 0.015)
	K.cy(g, 0.2, 0.44, M_DARK, Vector3(0, 0.52, 0.2), Vector3(90, 0, 0), -1.0, 18)
	K.cy(g, 0.205, 0.05, A.metal(Color(0.4, 0.4, 0.4)), Vector3(0, 0.52, 0.44), Vector3(90, 0, 0), -1.0, 18)
	A.vent(g, Vector3(0.5, 0.24, 0.04), Vector3(-side * 0.515, 0.0, 0.1), Vector3(0, -side * 90.0, 0), 5)
	K.number(g, ctx.get("serial", "00"), Vector3(0, 0.425, -0.25), Vector3(-90, 0, 0), 0.005)
	# 外侧超大弹鼓 + 节段供弹槽
	var M_DRUM := A.paint(Color(0.72, 0.32, 0.1), 0.1, 0.6, {"wear": 0.55, "panel_scale": 0.0})
	K.cy(g, 0.56, 0.54, M_DRUM, Vector3(side * 0.82, -0.12, 0.25), Vector3(0, 0, 90), -1.0, 32)
	for dx in [0.56, 1.08]:
		K.cy(g, 0.575, 0.04, M_DARK, Vector3(side * dx, -0.12, 0.25), Vector3(0, 0, 90), -1.0, 32)
	K.cy(g, 0.15, 0.57, M_DARK, Vector3(side * 0.82, -0.12, 0.25), Vector3(0, 0, 90), -1.0, 16)
	for i in 8:
		var a := TAU * i / 8.0
		K.bb(g, Vector3(0.56, 0.05, 0.05), M_DARK, Vector3(side * 0.82, -0.12 + sin(a) * 0.38, 0.25 + cos(a) * 0.38), Vector3(rad_to_deg(a), 0, 0), 0.008)
	for i in 5:
		var t := float(i) / 4.0
		K.bb(g, Vector3(0.28, 0.2, 0.14), M_STEEL, Vector3(side * lerpf(0.66, 0.44, t), lerpf(-0.62, -0.3, t) - sin(t * PI) * 0.06, lerpf(0.0, -0.3, t)), Vector3(0, 0, side * -20.0), 0.02)
	# 转管：前端转子 + 七管 + 管箍
	K.cy(g, 0.44, 0.34, M_DARK, Vector3(0, 0, -0.68), Vector3(90, 0, 0), -1.0, 24)
	for i in 7:
		var a := TAU * i / 7.0
		K.cy(g, 0.085, 1.4, A.metal(Color(0.1, 0.1, 0.11)), Vector3(cos(a) * 0.26, sin(a) * 0.26, -1.5), Vector3(90, 0, 0), -1.0, 10)
		K.cy(g, 0.05, 0.02, A.metal(Color(0.01, 0.01, 0.01)), Vector3(cos(a) * 0.26, sin(a) * 0.26, -2.21), Vector3(90, 0, 0), -1.0, 8)
	K.cy(g, 0.1, 1.4, M_STEEL, Vector3(0, 0, -1.5), Vector3(90, 0, 0), -1.0, 10)
	for zz in [-1.0, -1.55, -2.1]:
		K.cy(g, 0.38, 0.12, M_DARK, Vector3(0, 0, zz), Vector3(90, 0, 0), -1.0, 24)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	g.add_child(muzzle)
	muzzle.position = Vector3(0, 0, -2.25)
	root.set_meta("muzzle", muzzle)
	return root
