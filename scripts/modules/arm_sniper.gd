extends RefCounted
## M99 精确狙击步枪：肩部稳压护盾、长机匣与直插五发弹匣、高架长焦光学瞄准镜（发光物镜/目镜）、重型浮置精密枪管、双室平板制退器与折叠两脚架
## 接口：插头 HP-A1 → a1_mount → 狙击步枪机匣；导出 muzzle
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var c: Color = ctx.color
	var side: float = ctx.get("side", 1.0)
	var root := K.module_root(ctx.get("slot", "arm_r"), ctx.id, Vector3(-side, 0, 0))
	var arm := K.node(root, Vector3(side * 0.25, 0, 0), Vector3.ZERO, "Body")
	var M_ARM := K.armor(c, 0.55)
	var M_ARM2 := K.armor(c.darkened(0.22), 0.55)
	var M_STEEL := A.metal(Color(0.16, 0.17, 0.165))
	var M_DARK := K.dark()
	var M_OPTIC := K.canopy(Color(0.24, 0.92, 0.85), 0.72)

	K.a1_mount(arm, side, M_ARM)
	# 肩部装甲折板与后坐缓冲块
	var sh := K.node(arm, Vector3(side * 0.14, 0.36, 0.05), Vector3(0, 0, side * -12.0))
	K.plate(sh, K.trap(0.68, 0.42, 0.20, 0.05), 0.48, M_ARM, Vector3.ZERO, Vector3(0, 90, 0), 0.03)
	K.plate(sh, K.crect(0.05, 0.22), 0.50, K.accent(), Vector3(side * 0.10, 0, 0), Vector3(0, 90, 0), 0.005)
	A.emblem(arm, Vector3(side * 0.40, 0.34, 0.07), Vector3(0, side * 90.0, side * -12.0), 0.20)

	var g := K.node(arm, Vector3(side * 0.35, -0.02, 0), Vector3.ZERO, "Gun")
	# 狙击机匣 + 贴腮垫 + 枪机拉柄 + 下挂 5 发直弹匣
	K.bb(g, Vector3(0.26, 0.28, 1.02), M_ARM2, Vector3(0, 0.0, -0.06), Vector3.ZERO, 0.025)
	K.bb(g, Vector3(0.20, 0.08, 0.42), M_DARK, Vector3(0, 0.16, 0.18), Vector3.ZERO, 0.015)
	K.cy(g, 0.024, 0.11, M_STEEL, Vector3(side * 0.17, 0.04, 0.08), Vector3(0, 0, 90), -1.0, 12)
	K.bb(g, Vector3(0.14, 0.24, 0.28), M_DARK, Vector3(0, -0.25, -0.08), Vector3(8, 0, 0), 0.015)
	A.stencil(g, "12.7", Vector3(side * 0.138, 0.0, -0.10), Vector3(0, side * 90.0, 0), 0.0024, Color(0.88, 0.84, 0.52, 0.85))

	# 顶部导轨与高倍长焦光学狙击镜
	K.bb(g, Vector3(0.10, 0.045, 0.86), M_DARK, Vector3(0, 0.168, -0.26), Vector3.ZERO, 0.006)
	for rz in [-0.14, -0.44]:
		K.bb(g, Vector3(0.11, 0.08, 0.07), M_DARK, Vector3(0, 0.23, rz), Vector3.ZERO, 0.008)
	K.cy(g, 0.052, 0.62, M_STEEL, Vector3(0, 0.30, -0.32), Vector3(90, 0, 0), -1.0, 16)
	K.cy(g, 0.072, 0.18, M_DARK, Vector3(0, 0.30, -0.66), Vector3(90, 0, 0), -1.0, 16)
	K.cy(g, 0.062, 0.015, M_OPTIC, Vector3(0, 0.30, -0.752), Vector3(90, 0, 0), -1.0, 16)
	K.cy(g, 0.062, 0.12, M_DARK, Vector3(0, 0.30, 0.02), Vector3(90, 0, 0), -1.0, 16)

	# 浮置开槽前护木 + 折叠两脚架
	K.bb(g, Vector3(0.18, 0.18, 0.82), M_ARM, Vector3(0, 0.01, -0.98), Vector3.ZERO, 0.02)
	A.vent(g, Vector3(0.56, 0.09, 0.025), Vector3(side * 0.096, 0.02, -0.98), Vector3(0, side * 90.0, 0), 5)
	for sx in [-1.0, 1.0]:
		K.cy(g, 0.018, 0.42, M_DARK, Vector3(sx * 0.08, -0.10, -1.16), Vector3(84, 0, 0), -1.0, 10)

	# 重型浮置长枪管 + 双室平板制退器
	K.cy(g, 0.042, 0.44, M_DARK, Vector3(0, 0.02, -1.52), Vector3(90, 0, 0), -1.0, 16)
	K.cy(g, 0.032, 1.56, M_STEEL, Vector3(0, 0.02, -2.08), Vector3(90, 0, 0), -1.0, 16)
	K.bb(g, Vector3(0.16, 0.10, 0.24), M_DARK, Vector3(0, 0.02, -2.92), Vector3.ZERO, 0.014)
	for bz in [-2.85, -2.97]:
		K.bb(g, Vector3(0.19, 0.12, 0.035), M_STEEL, Vector3(0, 0.02, bz), Vector3.ZERO, 0.008)

	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	g.add_child(muzzle)
	muzzle.position = Vector3(0, 0.02, -3.08)
	root.set_meta("muzzle", muzzle)
	return root
