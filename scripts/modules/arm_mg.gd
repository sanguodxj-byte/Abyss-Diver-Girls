extends RefCounted
## 速射机炮（B.o.T 式）：长冷却套转管、侧挂橙色大弹鼓、切角机匣
## 接口：插头 HP-A1（朝向躯干）；导出 muzzle
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var id: String = ctx.id
	var c: Color = ctx.color
	var lights: bool = ctx.get("lights", true)
	var serial: String = ctx.get("serial", "00")
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var M_ACC := K.accent()
	var side: float = ctx.get("side", 1.0)
	var root := K.module_root(ctx.get("slot", "arm_r"), id, Vector3(-side, 0, 0))
	# 本体：肩关节作动器内侧面正好落在接口面上
	var arm := K.node(root, Vector3(side * 0.25, 0, 0), Vector3.ZERO, "Body")
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	arm.add_child(muzzle)
	var M_ARM := K.armor(c, 0.6)
	var M_CORE := M_ARM
	var M_CORE2 := K.armor(c.darkened(0.2), 0.6)
	var am: Dictionary = ctx.info
	var aid := id
	# 肩关节 + 多面肩甲
	K.actuator(arm, Vector3(-side * 0.08, 0.05, 0.05), 0.24, 0.3)
	var sh := K.node(arm, Vector3(side * 0.06, 0.34, 0.02), Vector3(0, 0, side * -12.0))
	K.plate(sh, K.trap(0.7, 0.46, 0.24, 0.06), 0.56, M_CORE, Vector3.ZERO, Vector3(0, 90, 0), 0.04)
	K.plate(sh, K.crect(0.05, 0.26), 0.58, M_ACC, Vector3(side * 0.12, 0.0, 0.0), Vector3(0, 90, 0), 0.005)
	A.emblem(arm, Vector3(side * 0.31, 0.2, 0.08), Vector3(0, side * 90.0, side * -6.0), 0.22)
	# 炮匣：切角机匣 + 侧板 + 散热孔
	K.bb(arm, Vector3(0.36, 0.4, 0.9), M_FRAME, Vector3(0, -0.05, -0.3), Vector3.ZERO, 0.04)
	K.plate(arm, K.crect(0.82, 0.38, [0.12, 0.0, 0.06, 0.1]), 0.44, M_ARM, Vector3(0, 0.0, -0.28), Vector3(0, 90, 0), 0.035)
	K.holes(arm, Vector3(side * 0.225, 0.02, -0.36), Vector3(0, side * 90.0, 0), 4, 2, 0.07, 0.018)
	K.plate(arm, K.crect(0.6, 0.06), 0.46, M_ACC, Vector3(0, 0.17, -0.3), Vector3(0, 90, 0), 0.005)
	# 侧挂大弹鼓（橙色）+ 供弹槽
	var M_DRUM := A.paint(Color(0.48, 0.36, 0.24), 0.1, 0.6, {"wear": 0.55, "panel_scale": 0.0})
	K.cy(arm, 0.26, 0.24, M_DRUM, Vector3(side * 0.4, -0.12, 0.02), Vector3(0, 0, 90), -1.0, 24)
	K.cy(arm, 0.27, 0.03, M_DARK, Vector3(side * 0.29, -0.12, 0.02), Vector3(0, 0, 90), -1.0, 24)
	K.cy(arm, 0.27, 0.03, M_DARK, Vector3(side * 0.51, -0.12, 0.02), Vector3(0, 0, 90), -1.0, 24)
	K.cy(arm, 0.08, 0.27, M_DARK, Vector3(side * 0.4, -0.12, 0.02), Vector3(0, 0, 90), -1.0, 12)
	K.bb(arm, Vector3(0.14, 0.12, 0.36), M_FRAME, Vector3(side * 0.28, -0.2, -0.28), Vector3(0, side * 20.0, 0), 0.02)
	# 长转管：机匣前环 + 带开孔的冷却套 + 6 管 + 制退器
	K.cy(arm, 0.17, 0.2, M_DARK, Vector3(0, 0, -0.78), Vector3(90, 0, 0), -1.0, 20)
	K.cy(arm, 0.13, 1.0, A.metal(Color(0.3, 0.31, 0.33)), Vector3(0, 0, -1.36), Vector3(90, 0, 0), -1.0, 20)
	for k in 6:
		for i in 6:
			var a := TAU * (i + 0.5 * (k % 2)) / 6.0
			A.add(arm, A.cyl(0.024, 0.03, 0.024, 8), A.metal(Color(0.03, 0.03, 0.035)), Vector3(cos(a) * 0.125, sin(a) * 0.125, -1.0 - k * 0.13), Vector3(0, 0, rad_to_deg(a) - 90.0), Vector3.ONE, false)
	for i in 6:
		var a := TAU * i / 6.0
		K.cy(arm, 0.032, 0.36, A.metal(Color(0.09, 0.09, 0.1)), Vector3(cos(a) * 0.075, sin(a) * 0.075, -1.98), Vector3(90, 0, 0), -1.0, 8)
	for zz in [-0.9, -1.84]:
		K.cy(arm, 0.15, 0.06, M_DARK, Vector3(0, 0, zz), Vector3(90, 0, 0), -1.0, 20)
	A.add(arm, A.torus(0.1, 0.14, 24), A.metal(Color(0.22, 0.2, 0.18)), Vector3(0, 0, -2.16), Vector3(90, 0, 0), Vector3(1, 2.0, 1))
	K.cy(arm, 0.05, 0.3, A.metal(Color(0.12, 0.12, 0.13)), Vector3(0, 0, -2.0), Vector3(90, 0, 0), -1.0, 10)
	muzzle.position = Vector3(0, 0, -2.26)
	root.set_meta("muzzle", muzzle)
	return root
