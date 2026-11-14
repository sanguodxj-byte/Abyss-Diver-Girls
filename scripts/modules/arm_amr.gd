extends RefCounted
## NTW-20 反器材炮：液压双后坐复进筒、重型机匣与侧置 20mm 弹匣、测距狙击光学舱、超长凹槽重管与宽体冲击制退器
## 接口：插头 HP-A1 → a1_mount → 炮架本体；导出 muzzle
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var c: Color = ctx.color
	var side: float = ctx.get("side", 1.0)
	var root := K.module_root(ctx.get("slot", "arm_r"), ctx.id, Vector3(-side, 0, 0))
	var arm := K.node(root, Vector3(side * 0.25, 0, 0), Vector3.ZERO, "Body")
	var M_ARM := K.armor(c, 0.55)
	var M_ARM2 := K.armor(c.darkened(0.22), 0.55)
	var M_STEEL := A.metal(Color(0.14, 0.15, 0.16))
	var M_DARK := K.dark()
	var M_OPTIC := K.canopy(Color(0.95, 0.62, 0.22), 0.80)
	var M_LASER := K.canopy(Color(0.28, 0.90, 0.96), 0.72)

	K.a1_mount(arm, side, M_ARM)
	# 重型肩部防盾与加强筋
	var sh := K.node(arm, Vector3(side * 0.15, 0.42, 0.04), Vector3(0, 0, side * -14.0))
	K.plate(sh, K.trap(0.78, 0.48, 0.24, 0.06), 0.56, M_ARM, Vector3.ZERO, Vector3(0, 90, 0), 0.04)
	K.plate(sh, K.crect(0.06, 0.28), 0.58, K.accent(), Vector3(side * 0.12, 0, 0), Vector3(0, 90, 0), 0.005)
	A.emblem(arm, Vector3(side * 0.44, 0.40, 0.06), Vector3(0, side * 90.0, side * -14.0), 0.22)

	var g := K.node(arm, Vector3(side * 0.38, -0.02, 0), Vector3.ZERO, "Gun")
	# 重型炮尾机匣 + 双侧液压反后坐缓冲缸 + 侧插 20mm 弹匣
	K.bb(g, Vector3(0.36, 0.36, 1.18), M_ARM2, Vector3(0, 0.0, -0.06), Vector3.ZERO, 0.032)
	K.bb(g, Vector3(0.30, 0.12, 0.62), M_DARK, Vector3(0, 0.24, -0.04), Vector3.ZERO, 0.018)
	for sy in [-1.0, 1.0]:
		K.cy(g, 0.056, 0.88, M_STEEL, Vector3(sy * 0.195, -0.02, -0.34), Vector3(90, 0, 0), -1.0, 14)
	K.bb(g, Vector3(0.22, 0.16, 0.40), M_DARK, Vector3(-side * 0.28, -0.04, -0.10), Vector3(0, 0, side * -12.0), 0.02)
	A.stencil(g, "20MM", Vector3(side * 0.185, 0.0, -0.10), Vector3(0, side * 90.0, 0), 0.0026, Color(0.92, 0.82, 0.46, 0.88))

	# 全尺寸高倍狙击光学瞄准舱 + 旁挂激光测距模块
	K.bb(g, Vector3(0.14, 0.09, 0.72), M_DARK, Vector3(0, 0.34, -0.26), Vector3.ZERO, 0.012)
	K.cy(g, 0.064, 0.74, M_STEEL, Vector3(0, 0.42, -0.30), Vector3(90, 0, 0), -1.0, 16)
	K.cy(g, 0.088, 0.22, M_DARK, Vector3(0, 0.42, -0.72), Vector3(90, 0, 0), -1.0, 16)
	K.cy(g, 0.074, 0.015, M_OPTIC, Vector3(0, 0.42, -0.832), Vector3(90, 0, 0), -1.0, 16)
	K.bb(g, Vector3(0.11, 0.11, 0.34), M_ARM, Vector3(side * 0.13, 0.39, -0.28), Vector3.ZERO, 0.012)
	K.cy(g, 0.032, 0.015, M_LASER, Vector3(side * 0.13, 0.39, -0.455), Vector3(90, 0, 0), -1.0, 12)

	# 炮盾 + 重型护管摇篮 + 20mm 超长精密身管 + 三室宽体平板制退器
	K.plate(g, K.crect(0.46, 0.44, [0.08, 0.08, 0.12, 0.12]), 0.11, M_ARM, Vector3(0, -0.02, -0.70), Vector3.ZERO, 0.025)
	K.cy(g, 0.105, 0.56, M_DARK, Vector3(0, -0.01, -1.02), Vector3(90, 0, 0), -1.0, 18)
	K.cy(g, 0.048, 1.98, M_STEEL, Vector3(0, -0.01, -2.18), Vector3(90, 0, 0), -1.0, 16)
	for rg in [-1.55, -2.05, -2.55]:
		K.cy(g, 0.062, 0.036, M_DARK, Vector3(0, -0.01, rg), Vector3(90, 0, 0), -1.0, 16)
	K.muzzle_brake(g, 0.105, 0.34, M_DARK, Vector3(0, -0.01, -3.28), 3)

	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	g.add_child(muzzle)
	muzzle.position = Vector3(0, -0.01, -3.48)
	root.set_meta("muzzle", muzzle)
	return root
