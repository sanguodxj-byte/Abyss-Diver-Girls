extends RefCounted
## 燃气轮机组 GT-260：加强安装背板、减速齿轮箱、粗壮涡轮机匣（法兰环 + 燃烧室凸台）、顶部进气罩、双排气管 + 打孔隔热罩、下挂发电机
## 接口：插头 HP-G1 → g1_mount → 齿轮箱 → 涡轮；局部 +Z 向后
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var c: Color = ctx.color
	var root := K.module_root("gen", ctx.id, Vector3.FORWARD)
	var M_H := K.armor(c, 0.55)
	var M_SUB := K.armor_sub(c, 0.58)
	var M_DARK := K.dark()
	var M_GUN := K.gunmetal()
	var b := K.g1_mount(root, M_H, 0.82, 0.66)
	# 背板承力三角肋 → 压铸减速附件齿轮箱
	for sx in [-1.0, 1.0]:
		K.plate(b, [Vector2(0, 0), Vector2(0.28, 0), Vector2(0, 0.24)], 0.045, M_H, Vector3(sx * 0.36, 0.10, 0.0), Vector3(0, -90, 0), 0.008)
	K.bb(b, Vector3(0.78, 0.60, 0.30), A.metal(Color(0.20, 0.21, 0.21)), Vector3(0, 0, 0.15), Vector3.ZERO, 0.038)
	# 轴流燃气涡轮主机匣 + 多级螺栓法兰环 + 环形燃油喷嘴歧管
	var M_CASE := A.metal(Color(0.30, 0.29, 0.27))
	K.cy(b, 0.36, 1.0, M_CASE, Vector3(0, 0.0, 0.80), Vector3(90, 0, 0), 0.30, 28)
	for zz in [0.36, 0.62, 0.90, 1.18]:
		var r_fl: float = 0.382 - (zz - 0.36) * 0.07
		K.cy(b, r_fl, 0.048, M_DARK, Vector3(0, 0, zz), Vector3(90, 0, 0), -1.0, 28)
		K.bolt_ring(b, r_fl - 0.014, 12, 0.013, Vector3(0, 0, zz - 0.026))
	A.add(b, A.torus(0.34, 0.365, 24), K.brass(), Vector3(0, 0, 0.74), Vector3(90, 0, 0), Vector3.ONE, false)
	for i in 6:
		var a := TAU * i / 6.0 + 0.26
		K.cy(b, 0.048, 0.16, M_GUN, Vector3(cos(a) * 0.355, sin(a) * 0.355, 0.76), Vector3(90, 0, 0), -1.0, 10)
	# 顶部防砂过滤进气道（带导流叶片与防异物钢格栅）
	K.bb(b, Vector3(0.62, 0.22, 0.46), M_H, Vector3(0, 0.44, 0.53), Vector3.ZERO, 0.028)
	K.bb(b, Vector3(0.54, 0.15, 0.03), K.bore_mat(), Vector3(0, 0.44, 0.302), Vector3.ZERO, 0.005)
	A.vent(b, Vector3(0.54, 0.15, 0.035), Vector3(0, 0.44, 0.295), Vector3.ZERO, 5)
	K.grab_iron(b, 0.34, 0.045, Vector3(0, 0.555, 0.53), Vector3(-90, 0, 0))
	# 尾部双联高温退火排气管 + 打孔防烫护筒 + 深黑空心排气喉口（修复原实心圆柱封顶）
	var M_HOT := A.paint(Color(0.28, 0.24, 0.27), 0.78, 0.38, {"wear": 0.35, "panel_scale": 0.0})
	K.bb(b, Vector3(0.66, 0.30, 0.16), M_SUB, Vector3(0, 0.0, 1.32), Vector3.ZERO, 0.024)
	for sx in [-1.0, 1.0]:
		K.cy(b, 0.14, 0.26, M_HOT, Vector3(sx * 0.22, 0.02, 1.38), Vector3(78, 0, 0), -1.0, 16)
		K.cy(b, 0.135, 0.72, M_HOT, Vector3(sx * 0.22, 0.39, 1.46), Vector3.ZERO, -1.0, 16)
		K.cy(b, 0.158, 0.44, M_GUN, Vector3(sx * 0.22, 0.41, 1.46), Vector3.ZERO, -1.0, 16)
		for yy in [0.21, 0.61]:
			K.cy(b, 0.165, 0.026, M_DARK, Vector3(sx * 0.22, yy, 1.46), Vector3.ZERO, -1.0, 16)
		for k in 4:
			for i in 6:
				var a := TAU * i / 6.0 + 0.5 * (k % 2)
				A.add(b, A.cyl(0.017, 0.02, 0.017, 6), K.bore_mat(), Vector3(sx * 0.22 + cos(a) * 0.159, 0.27 + k * 0.09, 1.46 + sin(a) * 0.159), Vector3(90, rad_to_deg(-a) + 90.0, 0), Vector3.ONE, false)
		K.barrel_bore(b, 0.136, 0.112, Vector3(sx * 0.22, 0.75, 1.46), 0.16, Vector3.ZERO)
	# 下挂高速起动发电机 + 燃油调速器盒 + 滑油编织管
	K.cy(b, 0.16, 0.52, M_DARK, Vector3(0, -0.42, 0.56), Vector3(90, 0, 0), -1.0, 18)
	K.bb(b, Vector3(0.14, 0.16, 0.22), M_SUB, Vector3(0.36, -0.18, 0.48), Vector3.ZERO, 0.016)
	A.hose(b, Vector3(0.14, -0.36, 0.32), Vector3(0.28, -0.20, 0.08), Vector3(0.05, -0.04, 0), 0.024, A.paint(Color(0.50, 0.30, 0.10), 0.1, 0.65, {"panel_scale": 0.0}))
	A.hose(b, Vector3(0.36, -0.10, 0.48), Vector3(0.32, 0.06, 0.72), Vector3(0.06, 0, 0), 0.016, A.chrome())
	A.stencil(b, "GT-260  TURBINE", Vector3(-0.376, 0.02, 0.80), Vector3(0, -90, 0), 0.003, Color(0.95, 0.85, 0.30, 0.85))
	return root
