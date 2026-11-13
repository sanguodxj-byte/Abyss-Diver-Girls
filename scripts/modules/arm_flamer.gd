extends RefCounted
## 火焰喷射器：双燃料罐、输油软管、引燃火
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
	K.bb(arm, Vector3(0.32, 0.34, 0.74), M_FRAME, Vector3(0, -0.02, -0.25), Vector3.ZERO, 0.03)
	K.plate(arm, K.crect(0.64, 0.24, [0.0, 0.10, 0.0, 0.0]), 0.36, M_CORE2, Vector3(-side * 0.02, 0.14, -0.62), Vector3(0, 90, 0), 0.02)
	# 双联高压凝固汽油储罐 + 黄铜减压阀 + 钢箍绑带 + 高危警示带
	var M_TANK := A.paint(Color(0.46, 0.35, 0.22), 0.22, 0.48, {"panel_scale": 0.0, "wear": 0.54})
	for oy in [0.13, -0.16]:
		K.cy(arm, 0.145, 0.64, M_TANK, Vector3(side * 0.20, oy, -0.14), Vector3(90, 0, 0), -1.0, 18)
		A.add(arm, A.sphere(0.145, -1, 14), M_TANK, Vector3(side * 0.20, oy, 0.18), Vector3.ZERO, Vector3(1, 1, 0.42))
		A.add(arm, A.sphere(0.145, -1, 14), M_TANK, Vector3(side * 0.20, oy, -0.46), Vector3.ZERO, Vector3(1, 1, 0.42))
		K.cy(arm, 0.036, 0.08, K.brass(), Vector3(side * 0.20, oy, -0.52), Vector3(90, 0, 0), -1.0, 10)
		for z in [-0.30, 0.02]:
			K.cy(arm, 0.153, 0.038, M_DARK, Vector3(side * 0.20, oy, z), Vector3(90, 0, 0), -1.0, 18)
	K.cy(arm, 0.150, 0.06, A.hazard(), Vector3(side * 0.20, 0.13, -0.14), Vector3(90, 0, 0), -1.0, 18)
	# 侧面压力表盘
	K.cy(arm, 0.045, 0.025, K.brass(), Vector3(side * 0.355, 0.0, 0.04), Vector3(0, 0, 90), -1.0, 12)
	A.stencil(arm, "FLAMMABLE", Vector3(side * 0.352, 0.13, -0.14), Vector3(0, side * 90.0, 0), 0.0024, Color(0.95, 0.85, 0.30, 0.85))
	A.hose(arm, Vector3(side * 0.20, -0.16, -0.55), Vector3(0, -0.06, -0.82), Vector3(0, -0.09, -0.04), 0.034)
	A.hose(arm, Vector3(side * 0.20, 0.13, -0.55), Vector3(0, 0.02, -0.78), Vector3(side * 0.04, 0.04, -0.02), 0.026)

	# 喷射身管 + 冲孔防烫冷却笼套 + 熏黑喷嘴深孔 + 下挂压电引燃火炬叉（消除悬浮蓝球）
	K.cy(arm, 0.058, 0.72, K.gunmetal(), Vector3(0, -0.04, -0.96), Vector3(90, 0, 0), -1.0, 14)
	K.cy(arm, 0.105, 0.56, M_DARK, Vector3(0, -0.04, -0.98), Vector3(90, 0, 0), 0.115, 16)
	for hk in 4:
		for ha in 6:
			var a := TAU * float(ha) / 6.0
			A.add(arm, A.cyl(0.018, 0.02, 0.018, 6), K.bore_mat(), Vector3(cos(a) * 0.106, -0.04 + sin(a) * 0.106, -0.78 - hk * 0.12), Vector3(0, 0, rad_to_deg(a) - 90.0), Vector3.ONE, false)
	K.plate(arm, K.trap(0.58, 0.36, 0.18, 0.04), 0.30, M_ARM, Vector3(0, 0.11, -0.96), Vector3(0, 90, 0), 0.025)
	K.plate(arm, K.crect(0.36, 0.04), 0.31, M_ACC, Vector3(0, 0.16, -0.96), Vector3(0, 90, 0), 0.004)
	# 熏黑锥形喷油嘴与深孔
	K.cy(arm, 0.088, 0.14, M_DARK, Vector3(0, -0.04, -1.33), Vector3(90, 0, 0), 0.072, 16)
	K.barrel_bore(arm, 0.088, 0.060, Vector3(0, -0.04, -1.40), 0.08)
	# 下探钢制引燃器支架 + 黄铜喷火嘴 + 微小真实常明火苗核
	K.bb(arm, Vector3(0.035, 0.12, 0.04), M_DARK, Vector3(0, -0.14, -1.24), Vector3(24, 0, 0), 0.006)
	K.cy(arm, 0.018, 0.22, K.brass(), Vector3(0, -0.18, -1.32), Vector3(82, 0, 0), -1.0, 8)
	if lights:
		A.add(arm, A.sphere(0.022, 0.05, 8), A.emit(Color(1.0, 0.58, 0.16), 2.4), Vector3(0, -0.165, -1.43), Vector3.ZERO, Vector3.ONE, false)
	muzzle.position = Vector3(0, -0.04, -1.45)
	root.set_meta("muzzle", muzzle)
	return root
