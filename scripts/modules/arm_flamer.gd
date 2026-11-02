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
	K.bb(arm, Vector3(0.3, 0.3, 0.7), M_FRAME, Vector3(0, -0.02, -0.25), Vector3.ZERO, 0.03)
	K.plate(arm, K.crect(0.62, 0.22, [0.0, 0.1, 0.0, 0.0]), 0.34, M_CORE2, Vector3(-side * 0.02, 0.14, -0.62), Vector3(0, 90, 0), 0.02)
	for oy in [0.12, -0.16]:
		var M_TANK := A.paint(c, 0.2, 0.5, {"panel_scale": 0.0, "wear": 0.5})
		K.cy(arm, 0.15, 0.62, M_TANK, Vector3(side * 0.18, oy, -0.15), Vector3(90, 0, 0), -1.0, 18)
		A.add(arm, A.sphere(0.15, -1, 14), M_TANK, Vector3(side * 0.18, oy, 0.16), Vector3.ZERO, Vector3(1, 1, 0.4))
		A.add(arm, A.sphere(0.15, -1, 14), M_TANK, Vector3(side * 0.18, oy, -0.46), Vector3.ZERO, Vector3(1, 1, 0.4))
		for z in [-0.3, 0.0]:
			K.cy(arm, 0.158, 0.04, A.paint(Color(0.12, 0.12, 0.1), 0.0, 0.85, {"panel_scale": 0.0}), Vector3(side * 0.18, oy, z), Vector3(90, 0, 0), -1.0, 18)
	A.stencil(arm, "FLAMMABLE", Vector3(side * 0.34, 0.12, -0.15), Vector3(0, side * 90.0, 0), 0.0025, Color(0.95, 0.85, 0.3, 0.85))
	A.hose(arm, Vector3(side * 0.18, -0.16, -0.55), Vector3(0, -0.06, -0.8), Vector3(0, -0.1, -0.05), 0.035)
	K.cy(arm, 0.09, 0.7, M_DARK, Vector3(0, -0.05, -0.95), Vector3(90, 0, 0), 0.13, 14)
	K.plate(arm, K.trap(0.6, 0.36, 0.2, 0.04), 0.3, M_ARM, Vector3(0, 0.1, -0.98), Vector3(0, 90, 0), 0.025)
	K.plate(arm, K.crect(0.36, 0.04), 0.31, M_ACC, Vector3(0, 0.15, -0.98), Vector3(0, 90, 0), 0.004)
	K.cy(arm, 0.1, 0.1, A.metal(Color(0.35, 0.3, 0.25)), Vector3(0, -0.05, -1.3), Vector3(90, 0, 0), -1.0, 14)
	A.add(arm, A.sphere(0.045), A.emit(Color(0.4, 0.6, 1.0), 6.0), Vector3(0, -0.16, -1.33), Vector3.ZERO, Vector3.ONE, false)
	muzzle.position = Vector3(0, -0.05, -1.45)
	root.set_meta("muzzle", muzzle)
	return root
