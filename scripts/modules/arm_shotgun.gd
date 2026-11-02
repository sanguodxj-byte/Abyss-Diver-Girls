extends RefCounted
## 霰弹臂：双管散热护套、侧格栅
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
	K.plate(arm, K.crect(0.95, 0.46, [0.16, 0.0, 0.1, 0.12]), 0.5, M_ARM, Vector3(0, 0, -0.32), Vector3(0, 90, 0), 0.04)
	K.plate(arm, K.crect(0.6, 0.3, [0.08, 0.0, 0.0, 0.08]), 0.54, M_CORE2, Vector3(0, 0.02, -0.4), Vector3(0, 90, 0), 0.02)
	K.plate(arm, K.trap(0.5, 0.34, 0.12, 0.03), 0.4, M_ARM, Vector3(0, 0.15, -1.05), Vector3(0, 90, 0), 0.02)
	K.bb(arm, Vector3(0.52, 0.12, 0.5), M_FRAME, Vector3(0, -0.24, -0.25), Vector3.ZERO, 0.02)
	for ox in [-0.11, 0.11]:
		K.cy(arm, 0.1, 0.8, A.metal(Color(0.1, 0.1, 0.11)), Vector3(ox, 0.04, -1.15), Vector3(90, 0, 0), -1.0, 14)
		K.cy(arm, 0.125, 0.5, A.metal(Color(0.22, 0.22, 0.24)), Vector3(ox, 0.04, -1.0), Vector3(90, 0, 0), -1.0, 10)
		K.cy(arm, 0.13, 0.08, A.metal(Color(0.28, 0.28, 0.3)), Vector3(ox, 0.04, -1.52), Vector3(90, 0, 0), -1.0, 14)
	K.holes(arm, Vector3(side * 0.275, 0.0, -0.3), Vector3(0, side * 90.0, 0), 4, 2, 0.07, 0.02)
	K.plate(arm, K.crect(0.5, 0.05), 0.52, M_ACC, Vector3(0, 0.2, -0.4), Vector3(0, 90, 0), 0.005)
	A.rivets(arm, Vector3(-0.18, 0.235, -0.15), Vector3(0.18, 0.235, -0.15), 4, 0.014, Vector3.ZERO)
	muzzle.position = Vector3(0, 0, -1.62)
	root.set_meta("muzzle", muzzle)
	return root
