extends RefCounted
## 垂直发射箱 VLS-8：2×4 垂直发射单元，铰链舱盖、侧面加强肋、尾部燃气排导口
## 接口：插头 HP-B1 → b1_mount（加宽横梁）→ 发射箱；局部 +Y 远离躯干
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var c: Color = ctx.color
	var root := K.module_root("back", ctx.id, Vector3(0, -1, -0.25))
	var M_A := K.armor(c, 0.55)
	var M_A2 := K.armor(c.darkened(0.22), 0.55)
	var M_DARK := K.dark()
	var top := K.b1_mount(root, M_A, 1.5)
	# 箱体
	K.bb(top, Vector3(1.56, 0.9, 1.0), M_A, Vector3(0, 0.45, 0.0), Vector3.ZERO, 0.05)
	K.bb(top, Vector3(1.6, 0.08, 1.04), M_A2, Vector3(0, 0.88, 0.0), Vector3.ZERO, 0.02)
	for sx in [-1.0, 1.0]:
		for i in 4:
			K.bb(top, Vector3(0.05, 0.8, 0.06), M_A2, Vector3(sx * 0.8, 0.45, -0.36 + i * 0.24), Vector3.ZERO, 0.01)
		A.stencil(top, "VLS-8", Vector3(sx * 0.785, 0.55, 0.0), Vector3(0, sx * 90.0, 0), 0.0045, Color(0.95, 0.92, 0.85, 0.8))
		A.stencil(top, "DANGER", Vector3(sx * 0.785, 0.3, 0.0), Vector3(0, sx * 90.0, 0), 0.003, Color(0.95, 0.85, 0.3, 0.85))
	# 2×4 舱盖（铰链在后侧）
	for i in 4:
		for j in 2:
			var p := Vector3(-0.57 + i * 0.38, 0.93, -0.22 + j * 0.44)
			# 舱盖：铰链在后缘（+Z），开火动画绕 X 掀开（Hatch<i><j>）
			K.cy(top, 0.02, 0.3, A.chrome(), p + Vector3(0, 0.02, 0.2), Vector3(0, 0, 90), -1.0, 8)
			var h := K.node(top, p + Vector3(0, 0, 0.2), Vector3.ZERO, "Hatch%d%d" % [i, j])
			K.bb(h, Vector3(0.34, 0.04, 0.4), M_A2, Vector3(0, 0, -0.2), Vector3.ZERO, 0.01)
			K.bb(h, Vector3(0.3, 0.012, 0.36), M_DARK, Vector3(0, 0.022, -0.2), Vector3.ZERO, 0.004)
			K.bb(h, Vector3(0.06, 0.02, 0.04), K.accent(), Vector3(0, 0.03, -0.37), Vector3.ZERO, 0.004)
			# 发射井内导弹（Missile<i><j>），平时藏在箱体内
			var ms := K.node(top, Vector3(p.x, 0.0, p.z), Vector3.ZERO, "Missile%d%d" % [i, j])
			K.cy(ms, 0.1, 0.62, A.metal(Color(0.62, 0.62, 0.6)), Vector3(0, 0.43, 0), Vector3.ZERO, -1.0, 12)
			K.cy(ms, 0.1, 0.16, A.paint(Color(0.8, 0.62, 0.12), 0.2, 0.5, {"wear": 0.4, "panel_scale": 0.0}), Vector3(0, 0.82, 0), Vector3.ZERO, 0.02, 12)
			for f in 4:
				K.bb(ms, Vector3(0.012, 0.14, 0.1), M_DARK, Vector3(cos(f * PI / 2) * 0.1, 0.32, sin(f * PI / 2) * 0.1) + Vector3(0, -0.12, 0), Vector3(0, -f * 90.0, 0), 0.003)
	# 尾部燃气排导口
	for sx in [-0.45, 0.45]:
		K.bb(top, Vector3(0.5, 0.3, 0.1), M_DARK, Vector3(sx, 0.3, 0.52), Vector3.ZERO, 0.02)
		A.vent(top, Vector3(0.42, 0.22, 0.03), Vector3(sx, 0.3, 0.575), Vector3(0, 180, 0), 4)
	return root
