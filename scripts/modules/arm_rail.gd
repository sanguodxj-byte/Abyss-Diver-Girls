extends RefCounted
## 电磁轨道炮 RG-2：双导轨 + 绝缘夹箍、炮尾电容组、动力电缆、散热片；两轨之间透出电弧光
## 接口：插头 HP-A1（朝向躯干）→ a1_mount → 炮尾；导出 muzzle
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var c: Color = ctx.color
	var side: float = ctx.get("side", 1.0)
	var root := K.module_root(ctx.get("slot", "arm_r"), ctx.id, Vector3(-side, 0, 0))
	var arm := K.node(root, Vector3(side * 0.25, 0, 0), Vector3.ZERO, "Body")
	var M_ARM := K.armor(c, 0.5)
	var M_ARM2 := K.armor(c.darkened(0.22), 0.5)
	var M_STEEL := A.metal(Color(0.14, 0.145, 0.15))
	var M_DARK := K.dark()
	var glow: Color = ctx.info.color
	K.a1_mount(arm, side, M_ARM)
	var sh := K.node(arm, Vector3(side * 0.14, 0.38, 0.06), Vector3(0, 0, side * -12.0))
	K.plate(sh, K.trap(0.7, 0.44, 0.22, 0.06), 0.52, M_ARM, Vector3.ZERO, Vector3(0, 90, 0), 0.04)
	K.plate(sh, K.crect(0.05, 0.24), 0.54, K.accent(), Vector3(side * 0.11, 0, 0), Vector3(0, 90, 0), 0.005)
	A.emblem(arm, Vector3(side * 0.39, 0.36, 0.06), Vector3(0, side * 90.0, side * -12.0), 0.2)
	var g := K.node(arm, Vector3(side * 0.37, -0.02, 0), Vector3.ZERO, "Gun")
	# 炮尾舱 + 散热片
	K.bb(g, Vector3(0.34, 0.42, 0.72), M_ARM2, Vector3(0, 0, 0.0), Vector3.ZERO, 0.035)
	for sx in [-1.0, 1.0]:
		K.plate(g, K.crect(0.68, 0.38, [0.1, 0.0, 0.0, 0.1]), 0.03, M_ARM, Vector3(sx * 0.185, 0, 0.0), Vector3(0, 90, 0), 0.01)
	for i in 6:
		K.bb(g, Vector3(0.3, 0.07, 0.02), A.metal(Color(0.3, 0.31, 0.33)), Vector3(0, 0.245, -0.25 + i * 0.09), Vector3.ZERO, 0.004)
	A.stencil(g, "HIGH VOLTAGE", Vector3(side * 0.205, -0.08, 0.0), Vector3(0, side * 90.0, 0), 0.0022, Color(0.95, 0.85, 0.3, 0.85))
	# 电容组（炮尾下方 2×2）
	var M_CAP := A.paint(Color(0.12, 0.16, 0.22), 0.3, 0.5, {"wear": 0.3, "panel_scale": 0.0})
	for sx in [-0.085, 0.085]:
		for yy in [-0.27, -0.39]:
			K.cy(g, 0.055, 0.56, M_CAP, Vector3(sx, yy, -0.12), Vector3(90, 0, 0), -1.0, 14)
			K.cy(g, 0.04, 0.03, A.chrome(), Vector3(sx, yy, -0.415), Vector3(90, 0, 0), -1.0, 10)
	K.bb(g, Vector3(0.3, 0.04, 0.6), M_STEEL, Vector3(0, -0.215, -0.12), Vector3.ZERO, 0.008)
	# 上下双电磁加速导轨 + 紫铜母排导电面 + 镂空深邃加速膛（彻底移除整条发光霓虹板，仅保留炮尾深处电枢待机微光）
	var COPPER := K.copper()
	for sy in [-1.0, 1.0]:
		K.bb(g, Vector3(0.15, 0.085, 1.78), M_STEEL, Vector3(0, sy * 0.11, -1.20), Vector3.ZERO, 0.016)
		K.bb(g, Vector3(0.18, 0.035, 1.68), M_ARM, Vector3(0, sy * 0.155, -1.16), Vector3.ZERO, 0.010)
		K.bb(g, Vector3(0.085, 0.018, 1.76), COPPER, Vector3(0, sy * 0.062, -1.20), Vector3.ZERO, 0.003)
	K.bb(g, Vector3(0.07, 0.10, 0.22), K.bore_mat(), Vector3(0, 0, -0.44), Vector3.ZERO, 0.005)
	if ctx.get("lights", true):
		K.bb(g, Vector3(0.018, 0.055, 0.16), A.emit(glow, 1.2), Vector3(0, 0, -0.48), Vector3.ZERO, 0.003)
	# 6道抗洛伦兹斥力高强钢预紧夹箍（带陶瓷绝缘衬垫与对拉高强螺栓）
	var M_INS := A.paint(Color(0.26, 0.24, 0.20), 0.0, 0.82, {"wear": 0.28, "panel_scale": 0.0})
	for i in 6:
		var z := -0.48 - i * 0.30
		for sx in [-1.0, 1.0]:
			K.bb(g, Vector3(0.055, 0.34, 0.09), K.gunmetal(), Vector3(sx * 0.10, 0, z), Vector3.ZERO, 0.01)
			K.bb(g, Vector3(0.035, 0.22, 0.07), M_INS, Vector3(sx * 0.068, 0, z), Vector3.ZERO, 0.006)
			for by in [-0.13, 0.13]:
				K.cy(g, 0.016, 0.26, A.chrome(), Vector3(0, by, z), Vector3(0, 0, 90), -1.0, 6)
		K.bb(g, Vector3(0.25, 0.045, 0.09), M_DARK, Vector3(0, 0.18, z), Vector3.ZERO, 0.008)
		K.bb(g, Vector3(0.25, 0.045, 0.09), M_DARK, Vector3(0, -0.18, z), Vector3.ZERO, 0.008)
	# 粗重高压馈电母排软缆：电容组 → 炮尾铜端子
	for sx in [-1.0, 1.0]:
		K.cy(g, 0.028, 0.06, COPPER, Vector3(sx * 0.11, -0.14, -0.54), Vector3(0, 0, 90), -1.0, 8)
		A.hose(g, Vector3(sx * 0.13, -0.30, -0.36), Vector3(sx * 0.11, -0.14, -0.54), Vector3(sx * 0.06, -0.05, 0), 0.026, A.rubber())
	# 炮口：分流消弧制退框 + 真实矩形深黑轨道膛口
	K.bb(g, Vector3(0.28, 0.36, 0.14), M_DARK, Vector3(0, 0, -2.10), Vector3.ZERO, 0.02)
	K.bb(g, Vector3(0.09, 0.11, 0.15), K.bore_mat(), Vector3(0, 0, -2.105), Vector3.ZERO, 0.004)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	g.add_child(muzzle)
	muzzle.position = Vector3(0, 0, -2.18)
	root.set_meta("muzzle", muzzle)
	return root
