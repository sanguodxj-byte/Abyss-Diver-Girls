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
	K.shoulder(arm, side, M_CORE)
	# 炮匣：切角钢制机匣 + 抛壳槽 + 散热百叶
	K.bb(arm, Vector3(0.36, 0.40, 0.90), M_FRAME, Vector3(0, -0.05, -0.30), Vector3.ZERO, 0.038)
	K.plate(arm, K.crect(0.84, 0.38, [0.12, 0.0, 0.06, 0.10]), 0.44, M_ARM, Vector3(0, 0.0, -0.28), Vector3(0, 90, 0), 0.032)
	K.holes(arm, Vector3(side * 0.225, 0.02, -0.36), Vector3(0, side * 90.0, 0), 4, 2, 0.07, 0.018)
	K.plate(arm, K.crect(0.58, 0.055), 0.46, M_ACC, Vector3(0, 0.17, -0.30), Vector3(0, 90, 0), 0.005)
	# 侧挂军用橄榄褐弹鼓（告别塑料亮橙）+ 加强压筋 + 黄铜锁扣 + 柔性供弹滑槽
	var M_DRUM := A.paint(Color(0.28, 0.31, 0.24), 0.22, 0.56, {"wear": 0.52, "panel_scale": 0.0})
	K.cy(arm, 0.24, 0.24, M_DRUM, Vector3(side * 0.38, -0.12, 0.02), Vector3(0, 0, 90), -1.0, 24)
	for dx in [0.27, 0.49]:
		K.cy(arm, 0.252, 0.028, M_DARK, Vector3(side * dx, -0.12, 0.02), Vector3(0, 0, 90), -1.0, 24)
	K.cy(arm, 0.246, 0.04, M_ACC, Vector3(side * 0.38, -0.12, 0.02), Vector3(0, 0, 90), -1.0, 24)
	K.cy(arm, 0.08, 0.27, K.gunmetal(), Vector3(side * 0.38, -0.12, 0.02), Vector3(0, 0, 90), -1.0, 12)
	K.bolt_ring(arm, 0.15, 6, 0.013, Vector3(side * 0.505, -0.12, 0.02), Vector3(0, 0, -side * 90.0))
	K.bb(arm, Vector3(0.14, 0.12, 0.36), K.gunmetal(), Vector3(side * 0.27, -0.20, -0.28), Vector3(0, side * 20.0, 0), 0.02)
	# 长转管：机匣前轴承座 + 纵肋穿孔隔热套筒 + 6根独立枪管 + 多道蜘蛛管箍 + 真实深黑膛口
	K.cy(arm, 0.17, 0.20, M_DARK, Vector3(0, 0, -0.78), Vector3(90, 0, 0), -1.0, 20)
	K.cy(arm, 0.135, 0.92, K.gunmetal(), Vector3(0, 0, -1.32), Vector3(90, 0, 0), -1.0, 20)
	# 齐平贴面深黑散热孔（外缘距套筒仅 1mm，杜绝第一人称视角下圆点凸起如铆钉疙瘩）
	for k in 6:
		for i in 6:
			var a := TAU * (i + 0.5 * (k % 2)) / 6.0
			A.add(arm, A.cyl(0.017, 0.012, 0.017, 10), K.bore_mat(), Vector3(cos(a) * 0.130, sin(a) * 0.130, -0.96 - k * 0.13), Vector3(0, 0, rad_to_deg(a) - 90.0), Vector3.ONE, false)
	# 4 条纵向铣削防烫散热筋 + 前中后管箍，提升第一人称近景机械质感
	for ri in 4:
		var ra := TAU * (float(ri) + 0.5) / 4.0
		K.bb(arm, Vector3(0.018, 0.014, 0.86), M_DARK, Vector3(cos(ra) * 0.138, sin(ra) * 0.138, -1.32), Vector3(0, 0, rad_to_deg(ra) - 90.0), 0.004)
	for i in 6:
		var a := TAU * i / 6.0
		var bx := cos(a) * 0.076
		var by := sin(a) * 0.076
		K.cy(arm, 0.030, 0.44, M_DARK, Vector3(bx, by, -1.98), Vector3(90, 0, 0), -1.0, 10)
		K.barrel_bore(arm, 0.030, 0.021, Vector3(bx, by, -2.20), 0.05)
	for zz in [-0.90, -1.34, -1.78, -2.12]:
		K.cy(arm, 0.146 if zz > -1.9 else 0.122, 0.048, M_DARK, Vector3(0, 0, zz), Vector3(90, 0, 0), -1.0, 20)
	K.cy(arm, 0.038, 0.44, K.gunmetal(), Vector3(0, 0, -1.98), Vector3(90, 0, 0), -1.0, 10)
	muzzle.position = Vector3(0, 0, -2.26)
	root.set_meta("muzzle", muzzle)
	return root
