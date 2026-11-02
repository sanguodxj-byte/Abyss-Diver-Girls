extends RefCounted
## 重机枪 HMG-12：长方形机匣 + 铰接顶盖、带散热孔的枪管护套、锥形消焰器、外挂弹药箱与弹链
## 接口：插头 HP-A1（朝向躯干）→ a1_mount（法兰 / 回转轴承 / 立轴）→ 机匣；导出 muzzle
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
	# 肩部护甲（压在轴承上方）
	var sh := K.node(arm, Vector3(side * 0.12, 0.36, 0.0), Vector3(0, 0, side * -10.0))
	K.plate(sh, K.trap(0.66, 0.42, 0.2, 0.05), 0.5, M_ARM, Vector3.ZERO, Vector3(0, 90, 0), 0.035)
	K.plate(sh, K.crect(0.05, 0.22), 0.52, K.accent(), Vector3(side * 0.1, 0, 0), Vector3(0, 90, 0), 0.005)
	A.emblem(arm, Vector3(side * 0.37, 0.36, 0.02), Vector3(0, side * 90.0, side * -10.0), 0.2)
	# 枪身：贴在立轴外侧
	var g := K.node(arm, Vector3(side * 0.35, -0.02, 0), Vector3.ZERO, "Gun")
	K.bb(g, Vector3(0.3, 0.34, 0.9), M_STEEL, Vector3(0, 0, -0.15), Vector3.ZERO, 0.03)
	K.bb(g, Vector3(0.32, 0.05, 0.62), M_ARM2, Vector3(0, 0.195, -0.24), Vector3.ZERO, 0.015)
	K.cy(g, 0.03, 0.34, A.chrome(), Vector3(0, 0.2, 0.08), Vector3(0, 0, 90), -1.0, 10)
	for sx in [-1.0, 1.0]:
		K.plate(g, K.crect(0.86, 0.3, [0.1, 0.0, 0.05, 0.08]), 0.035, M_ARM, Vector3(sx * 0.17, -0.01, -0.16), Vector3(0, 90, 0), 0.012)
	A.rivets(g, Vector3(side * 0.19, 0.11, -0.5), Vector3(side * 0.19, 0.11, 0.18), 6, 0.014, Vector3(0, 0, 90))
	K.number(g, ctx.get("serial", "00"), Vector3(side * 0.19, -0.04, -0.2), Vector3(0, side * 90.0, 0), 0.0026)
	K.cy(g, 0.1, 0.16, M_DARK, Vector3(0, 0, 0.36), Vector3(90, 0, 0), -1.0, 16)
	# 枪管座 + 散热护套（打孔）+ 枪管 + 消焰器
	K.bb(g, Vector3(0.24, 0.24, 0.18), M_STEEL, Vector3(0, -0.02, -0.68), Vector3.ZERO, 0.02)
	K.cy(g, 0.09, 0.9, A.metal(Color(0.26, 0.27, 0.28)), Vector3(0, -0.02, -1.22), Vector3(90, 0, 0), -1.0, 18)
	var HOLE := A.metal(Color(0.03, 0.03, 0.035))
	for k in 6:
		for a_deg in [-60.0, 0.0, 60.0, 120.0, 180.0, 240.0]:
			var a := deg_to_rad(a_deg + 30.0 * (k % 2))
			A.add(g, A.cyl(0.02, 0.02, 0.02, 8), HOLE, Vector3(cos(a) * 0.088, -0.02 + sin(a) * 0.088, -0.9 - k * 0.12), Vector3(0, 0, rad_to_deg(a) - 90.0), Vector3.ONE, false)
	K.cy(g, 0.045, 0.5, M_STEEL, Vector3(0, -0.02, -1.9), Vector3(90, 0, 0), -1.0, 12)
	K.cy(g, 0.05, 0.18, M_DARK, Vector3(0, -0.02, -2.22), Vector3(90, 0, 0), 0.075, 12)
	# 提把
	K.bb(g, Vector3(0.04, 0.04, 0.3), M_DARK, Vector3(0, 0.17, -1.05), Vector3.ZERO, 0.01)
	for zz in [-0.92, -1.18]:
		K.bb(g, Vector3(0.035, 0.08, 0.035), M_DARK, Vector3(0, 0.11, zz), Vector3.ZERO, 0.008)
	# 外挂弹药箱 + 弹链
	var M_BOX := A.paint(Color(0.3, 0.33, 0.24), 0.1, 0.7, {"wear": 0.6, "panel_scale": 0.0})
	K.bb(g, Vector3(0.24, 0.32, 0.46), M_BOX, Vector3(side * 0.28, -0.1, -0.08), Vector3.ZERO, 0.02)
	K.bb(g, Vector3(0.26, 0.04, 0.48), M_BOX, Vector3(side * 0.28, 0.08, -0.08), Vector3.ZERO, 0.01)
	K.bb(g, Vector3(0.05, 0.06, 0.03), K.accent(), Vector3(side * 0.41, 0.0, -0.08), Vector3.ZERO, 0.006)
	A.stencil(g, "12.7", Vector3(side * 0.405, -0.12, -0.08), Vector3(0, side * 90.0, 0), 0.0028, Color(0.9, 0.85, 0.5, 0.85))
	var BRASS := A.paint(Color(0.72, 0.55, 0.22), 0.8, 0.35, {"wear": 0.2, "panel_scale": 0.0})
	for i in 5:
		var t := float(i) / 4.0
		var p := Vector3(side * lerpf(0.26, 0.16, t), lerpf(0.13, 0.09, t) + sin(t * PI) * 0.06, -0.12 - t * 0.12)
		K.cy(g, 0.022, 0.12, BRASS, p, Vector3(0, 0, 90), -1.0, 8)
		K.bb(g, Vector3(0.06, 0.02, 0.05), M_DARK, p + Vector3(0, -0.02, 0), Vector3.ZERO, 0.004)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	g.add_child(muzzle)
	muzzle.position = Vector3(0, -0.02, -2.32)
	root.set_meta("muzzle", muzzle)
	return root
