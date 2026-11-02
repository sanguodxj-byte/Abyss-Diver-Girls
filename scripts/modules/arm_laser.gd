extends RefCounted
## 聚焦激光：散热片阵列、聚焦线圈、冷却管
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
	K.plate(arm, K.crect(1.25, 0.36, [0.14, 0.0, 0.08, 0.14]), 0.32, M_ARM, Vector3(0, 0, -0.45), Vector3(0, 90, 0), 0.03)
	K.plate(arm, K.trap(0.9, 0.6, 0.12, 0.03), 0.36, M_CORE2, Vector3(0, -0.18, -0.6), Vector3(0, 90, 0), 0.02)
	for i in 10:
		K.bb(arm, Vector3(0.44, 0.44, 0.025), A.metal(Color(0.3, 0.31, 0.33)), Vector3(0, 0, -0.1 - i * 0.075), Vector3.ZERO, 0.005)
	K.bb(arm, Vector3(0.34, 0.05, 0.6), A.emit(am.color, 1.2), Vector3(0, 0.2, -0.85), Vector3.ZERO, 0.01)
	K.cy(arm, 0.055, 0.85, A.chrome(), Vector3(0, 0, -1.45), Vector3(90, 0, 0), -1.0, 12)
	for i in 3:
		A.add(arm, A.torus(0.08, 0.13, 24), A.emit(am.color, 0.9), Vector3(0, 0, -1.2 - i * 0.2), Vector3(90, 0, 0), Vector3.ONE, false)
	K.cy(arm, 0.1, 0.1, A.metal(Color(0.2, 0.2, 0.22)), Vector3(0, 0, -1.9), Vector3(90, 0, 0), -1.0, 16)
	A.add(arm, A.sphere(0.065), A.emit(am.color, 3.0), Vector3(0, 0, -1.95), Vector3.ZERO, Vector3.ONE, false)
	A.hose(arm, Vector3(0, 0.2, 0.05), Vector3(0, 0.12, -0.55), Vector3(0, 0.15, 0), 0.03, A.paint(Color(0.1, 0.1, 0.12), 0.0, 0.7, {"panel_scale": 0.0}))
	muzzle.position = Vector3(0, 0, -2.0)
	root.set_meta("muzzle", muzzle)
	return root
