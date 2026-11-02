extends RefCounted
## 燃气轮机组 GT-260：加强安装背板、减速齿轮箱、粗壮涡轮机匣（法兰环 + 燃烧室凸台）、顶部进气罩、双排气管 + 打孔隔热罩、下挂发电机
## 接口：插头 HP-G1 → g1_mount → 齿轮箱 → 涡轮；局部 +Z 向后
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var c: Color = ctx.color
	var root := K.module_root("gen", ctx.id, Vector3.FORWARD)
	var M_H := K.armor(c, 0.55)
	var M_DARK := K.dark()
	var b := K.g1_mount(root, M_H, 0.82, 0.66)
	# 加强筋（背板 → 齿轮箱）
	for sx in [-1.0, 1.0]:
		K.plate(b, [Vector2(0, 0), Vector2(0.28, 0), Vector2(0, 0.24)], 0.04, M_H, Vector3(sx * 0.36, 0.1, 0.0), Vector3(0, -90, 0), 0.008)
	# 减速齿轮箱
	K.bb(b, Vector3(0.78, 0.6, 0.3), A.metal(Color(0.22, 0.23, 0.22)), Vector3(0, 0, 0.15), Vector3.ZERO, 0.04)
	# 涡轮机匣
	var M_CASE := A.metal(Color(0.32, 0.31, 0.29))
	K.cy(b, 0.36, 1.0, M_CASE, Vector3(0, 0.0, 0.8), Vector3(90, 0, 0), 0.3, 28)
	for zz in [0.36, 0.62, 0.9, 1.18]:
		K.cy(b, 0.38 - float(zz - 0.36) * 0.07, 0.05, M_DARK, Vector3(0, 0, zz), Vector3(90, 0, 0), -1.0, 28)
		for i in 10:
			var a := TAU * i / 10.0
			var r: float = 0.37 - (zz - 0.36) * 0.07
			K.cy(b, 0.015, 0.06, A.metal(Color(0.45, 0.45, 0.45)), Vector3(cos(a) * r, sin(a) * r, zz), Vector3(90, 0, 0), -1.0, 6)
	for i in 6:
		var a := TAU * i / 6.0 + 0.26
		K.cy(b, 0.05, 0.16, M_DARK, Vector3(cos(a) * 0.36, sin(a) * 0.36, 0.76), Vector3(90, 0, 0), -1.0, 10)
	# 顶部进气罩
	K.bb(b, Vector3(0.6, 0.2, 0.42), M_H, Vector3(0, 0.44, 0.52), Vector3.ZERO, 0.03)
	A.vent(b, Vector3(0.52, 0.14, 0.03), Vector3(0, 0.44, 0.305), Vector3.ZERO, 4)
	# 双排气管 + 打孔隔热罩（发蓝色）
	var M_HOT := A.metal(Color(0.3, 0.26, 0.3))
	for sx in [-1.0, 1.0]:
		K.cy(b, 0.14, 0.24, M_HOT, Vector3(sx * 0.22, 0.0, 1.38), Vector3(90, 0, 0), -1.0, 16)
		K.cy(b, 0.14, 0.7, M_HOT, Vector3(sx * 0.22, 0.38, 1.46), Vector3.ZERO, -1.0, 16)
		K.cy(b, 0.16, 0.42, A.metal(Color(0.4, 0.4, 0.38)), Vector3(sx * 0.22, 0.42, 1.46), Vector3.ZERO, -1.0, 16)
		for k in 4:
			for i in 6:
				var a := TAU * i / 6.0 + 0.5 * (k % 2)
				A.add(b, A.cyl(0.018, 0.02, 0.018, 6), A.metal(Color(0.03, 0.03, 0.03)), Vector3(sx * 0.22 + cos(a) * 0.16, 0.28 + k * 0.09, 1.46 + sin(a) * 0.16), Vector3(0, 0, 0) + Vector3(90, rad_to_deg(-a) + 90.0, 0), Vector3.ONE, false)
	# 下挂发电机
	K.cy(b, 0.16, 0.5, M_DARK, Vector3(0, -0.42, 0.55), Vector3(90, 0, 0), -1.0, 18)
	A.hose(b, Vector3(0.12, -0.36, 0.3), Vector3(0.28, -0.2, 0.08), Vector3(0.05, -0.04, 0), 0.025, A.paint(Color(0.55, 0.3, 0.08), 0.0, 0.7, {"panel_scale": 0.0}))
	A.stencil(b, "GT-260  TURBINE", Vector3(-0.374, 0.0, 0.8), Vector3(0, -90, 0), 0.003, Color(0.95, 0.85, 0.3, 0.85))
	return root
