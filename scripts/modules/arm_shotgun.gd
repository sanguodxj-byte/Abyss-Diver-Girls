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
	# 双联重型破门霰弹机匣 + 抛壳窗 + 下置箱式弹鼓与液压复进器
	K.plate(arm, K.crect(0.96, 0.46, [0.16, 0.02, 0.10, 0.12]), 0.52, M_ARM, Vector3(0, 0, -0.32), Vector3(0, 90, 0), 0.038)
	K.plate(arm, K.crect(0.62, 0.30, [0.08, 0.0, 0.0, 0.08]), 0.56, M_CORE2, Vector3(0, 0.02, -0.40), Vector3(0, 90, 0), 0.02)
	K.bb(arm, Vector3(0.02, 0.09, 0.24), K.bore_mat(), Vector3(side * 0.285, 0.08, -0.38), Vector3.ZERO, 0.003)
	K.bb(arm, Vector3(0.46, 0.22, 0.48), K.gunmetal(), Vector3(0, -0.26, -0.24), Vector3.ZERO, 0.025)
	A.stencil(arm, "40MM BUCK", Vector3(side * 0.235, -0.26, -0.24), Vector3(0, side * 90.0, 0), 0.0024, Color(0.92, 0.86, 0.52, 0.85))
	# 上置散热瞄准导轨 + 前护木夹箍
	K.plate(arm, K.trap(0.56, 0.38, 0.12, 0.03), 0.44, M_ARM, Vector3(0, 0.16, -1.04), Vector3(0, 90, 0), 0.02)
	K.bb(arm, Vector3(0.46, 0.22, 0.12), M_DARK, Vector3(0, 0.02, -1.28), Vector3.ZERO, 0.018)
	# 双联大口径身管 + 打孔散热护套 + 战术破门齿冠制退喉缩 + 真实深黑大膛孔（彻底修复实心灰柱！）
	for ox in [-0.115, 0.115]:
		K.cy(arm, 0.092, 0.84, M_DARK, Vector3(ox, 0.04, -1.14), Vector3(90, 0, 0), -1.0, 16)
		K.cy(arm, 0.115, 0.52, K.gunmetal(), Vector3(ox, 0.04, -0.98), Vector3(90, 0, 0), -1.0, 14)
		for hk in 4:
			A.add(arm, A.cyl(0.020, 0.025, 0.020, 8), K.bore_mat(), Vector3(ox, 0.152, -0.80 - hk * 0.11), Vector3.ZERO, Vector3.ONE, false)
		K.cy(arm, 0.106, 0.11, K.gunmetal(), Vector3(ox, 0.04, -1.52), Vector3(90, 0, 0), 0.102, 16)
		K.barrel_bore(arm, 0.106, 0.078, Vector3(ox, 0.04, -1.575), 0.09)
	# 管下液压缓冲筒 + 外侧备用铜底红壳霰弹排（4发）
	K.cy(arm, 0.055, 0.62, A.chrome(), Vector3(0, -0.09, -1.04), Vector3(90, 0, 0), -1.0, 12)
	K.cy(arm, 0.072, 0.28, M_DARK, Vector3(0, -0.09, -0.86), Vector3(90, 0, 0), -1.0, 12)
	var M_SHELL := A.paint(Color(0.50, 0.13, 0.09), 0.08, 0.56, {"wear": 0.35, "panel_scale": 0.0})
	for si in 4:
		var sz := -0.54 + si * 0.09
		K.cy(arm, 0.028, 0.13, M_SHELL, Vector3(side * 0.30, -0.04, sz), Vector3.ZERO, -1.0, 10)
		K.cy(arm, 0.030, 0.035, K.brass(), Vector3(side * 0.30, -0.11, sz), Vector3.ZERO, -1.0, 10)
	K.holes(arm, Vector3(-side * 0.275, 0.0, -0.30), Vector3(0, -side * 90.0, 0), 4, 2, 0.07, 0.02)
	K.plate(arm, K.crect(0.50, 0.05), 0.54, M_ACC, Vector3(0, 0.20, -0.40), Vector3(0, 90, 0), 0.005)
	A.rivets(arm, Vector3(-0.18, 0.235, -0.15), Vector3(0.18, 0.235, -0.15), 4, 0.014, Vector3.ZERO)
	muzzle.position = Vector3(0, 0.04, -1.62)
	root.set_meta("muzzle", muzzle)
	return root
