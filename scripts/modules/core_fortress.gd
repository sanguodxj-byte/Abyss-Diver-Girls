extends RefCounted
## 堡垒躯干 FT-9：超宽车体、间隙复合装甲首上（主装甲 + 三块披挂板）、宽侧挂臂短舱、
## 车长指挥塔（周视潜望镜环）、驾驶装甲舱、侧后栅格装甲、烟幕发射器
## 接口：插头 HP-C1（向下，加粗回转座圈）；插座 HP-A1×2、HP-B1（后倾甲板）、HP-G1（尾部加强框）
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var c: Color = ctx.color
	var lights: bool = ctx.get("lights", true)
	var root := K.module_root("core", ctx.id, Vector3.DOWN)
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var M_ACC := K.accent()
	var M_A := K.armor(c, 0.55)
	var M_A2 := K.armor(c.darkened(0.22), 0.55)
	var M_BAR := A.metal(Color(0.22, 0.22, 0.23))
	# 加粗回转座圈 + 齿圈 + 加强筋
	K.cy(root, 0.5, 0.14, M_DARK, Vector3(0, 0.19, 0), Vector3.ZERO, 0.56, 32)
	A.add(root, A.torus(0.5, 0.58, 40), A.metal(Color(0.3, 0.3, 0.32)), Vector3(0, 0.24, 0), Vector3.ZERO, Vector3(1, 0.5, 1), false)
	for i in 8:
		var a := TAU * i / 8.0
		K.bb(root, Vector3(0.05, 0.14, 0.18), M_DARK, Vector3(cos(a) * 0.5, 0.32, sin(a) * 0.5), Vector3(0, -rad_to_deg(a), 0), 0.01)
	# 车体
	K.bb(root, Vector3(1.76, 1.5, 1.9), M_FRAME, Vector3(0, 1.0, 0.15), Vector3.ZERO, 0.14)
	# 首上主装甲 + 间隙披挂板（带支撑螺柱）
	K.plate(root, K.trap(1.8, 1.4, 1.3, 0.12), 0.24, M_A2, Vector3(0, 1.1, -0.98), Vector3(24, 0, 0), 0.05)
	var gl := K.node(root, Vector3(0, 1.1, -0.98), Vector3(24, 0, 0))
	for i in 3:
		var px := -0.53 + i * 0.53
		K.plate(gl, K.crect(0.5, 1.1, [0.08, 0.08, 0.04, 0.04]), 0.16, M_A, Vector3(px, 0.0, -0.24), Vector3.ZERO, 0.035)
		for cxy in [Vector2(-0.15, 0.38), Vector2(0.15, 0.38), Vector2(-0.15, -0.38), Vector2(0.15, -0.38)]:
			K.cy(gl, 0.03, 0.12, M_DARK, Vector3(px + cxy.x, cxy.y, -0.1), Vector3(90, 0, 0), -1.0, 8)
			K.cy(gl, 0.04, 0.02, A.metal(Color(0.45, 0.45, 0.45)), Vector3(px + cxy.x, cxy.y, -0.33), Vector3(90, 0, 0), -1.0, 6)
	K.plate(gl, K.crect(1.5, 0.07), 0.17, M_ACC, Vector3(0, 0.6, -0.25), Vector3.ZERO, 0.005)
	K.number(gl, ctx.get("serial", "00"), Vector3(-0.53, -0.1, -0.33), Vector3(0, 180, 0), 0.005)
	K.plate(root, K.trap(1.3, 1.76, 0.5, 0.08), 0.2, M_A, Vector3(0, 0.4, -0.94), Vector3(-30, 0, 0), 0.04)
	# 首灯 + 牵引钩
	for sx in [-0.7, 0.7]:
		K.bb(root, Vector3(0.2, 0.1, 0.1), M_DARK, Vector3(sx * 0.9, 0.62, -1.08), Vector3.ZERO, 0.015)
		A.add(root, A.cyl(0.035, 0.03), A.emit(Color(1.0, 0.95, 0.8), 5.0), Vector3(sx * 0.9, 0.62, -1.14), Vector3(90, 0, 0), Vector3.ONE, false)
		A.add(root, A.torus(0.04, 0.075, 12), M_DARK, Vector3(sx * 0.5, 0.3, -1.1), Vector3(0, 0, 90), Vector3.ONE, false)
	# 宽侧短舱（HP-A1 母座在外侧）+ 顶部护甲 + 栅格装甲
	for sx in [-1.0, 1.0]:
		K.bb(root, Vector3(0.3, 1.0, 1.3), M_A2, Vector3(sx * 0.97, 0.85, 0.05), Vector3.ZERO, 0.04)
		K.plate(root, K.trap(1.4, 1.0, 0.3, 0.08), 0.44, M_A, Vector3(sx * 0.95, 1.42, 0.04), Vector3(0, 90, sx * -8.0), 0.04)
		K.plate(root, K.crect(0.06, 0.2), 0.45, M_ACC, Vector3(sx * 0.95, 1.42, -0.38), Vector3(0, 90, sx * -8.0), 0.005)
		A.vent(root, Vector3(0.5, 0.2, 0.04), Vector3(sx * 0.95, 0.55, 0.72), Vector3(0, 180, 0), 5)
		for i in 7:
			K.bb(root, Vector3(0.03, 0.8, 0.03), M_BAR, Vector3(sx * 1.16, 0.85, 0.5 + i * 0.085), Vector3.ZERO, 0.005)
		for yy in [0.48, 1.22]:
			K.bb(root, Vector3(0.03, 0.03, 0.52), M_BAR, Vector3(sx * 1.16, yy, 0.755), Vector3.ZERO, 0.005)
			K.bb(root, Vector3(0.06, 0.03, 0.03), M_BAR, Vector3(sx * 1.13, yy, 0.5), Vector3.ZERO, 0.005)
		for i in 4:
			K.cy(root, 0.055, 0.24, M_DARK, Vector3(sx * (0.5 + i * 0.1), 1.8, -0.6), Vector3(70, 0, sx * -20.0), -1.0, 10)
	# 驾驶装甲舱（左前）+ 观察窗
	var dr := K.node(root, Vector3(-0.42, 1.82, -0.4))
	K.plate(dr, K.crect(0.62, 0.22, [0.08, 0.0, 0.0, 0.06]), 0.5, M_A, Vector3.ZERO, Vector3.ZERO, 0.035)
	K.bb(dr, Vector3(0.44, 0.05, 0.02), K.canopy(), Vector3(0, 0.02, -0.255), Vector3.ZERO, 0.006)
	# 车长指挥塔（右）：圆座 + 周视潜望镜环 + 舱盖 + 机枪架
	K.cy(root, 0.36, 0.22, M_A, Vector3(0.4, 1.85, -0.05), Vector3.ZERO, 0.36, 24)
	for i in 8:
		var a := TAU * i / 8.0
		var p := Vector3(0.4 + cos(a) * 0.32, 1.97, -0.05 + sin(a) * 0.32)
		K.bb(root, Vector3(0.1, 0.06, 0.06), M_DARK, p, Vector3(0, -rad_to_deg(a), 0), 0.008)
	K.cy(root, 0.28, 0.05, M_A2, Vector3(0.4, 2.0, -0.05), Vector3.ZERO, -1.0, 22)
	K.bb(root, Vector3(0.22, 0.03, 0.03), A.chrome(), Vector3(0.4, 2.04, -0.05), Vector3.ZERO, 0.008)
	if lights:
		A.lens(root, Vector3(0.0, 1.76, -0.5), Vector3(-90, 0, 0), 0.04, Color(1.0, 0.85, 0.2), 1.6)
	# 后倾甲板（HP-B1 母座）+ 两侧格栅
	K.plate(root, K.crect(1.4, 0.7, [0.1, 0.1, 0.1, 0.1]), 0.08, M_A2, Vector3(0, 1.75, 0.6), Vector3(104, 0, 0), 0.02)
	for sx in [-1.0, 1.0]:
		A.vent(root, Vector3(0.24, 0.56, 0.04), Vector3(sx * 0.62, 1.795, 0.6), Vector3(-76, 0, 0), 6)
	A.stencil(root, "NO STEP", Vector3(-0.4, 1.76, 0.3), Vector3(-90, 0, 0), 0.0032, Color(0.95, 0.92, 0.85, 0.75))
	# 尾部动力舱加强框
	for sy in [-1.0, 1.0]:
		K.bb(root, Vector3(1.04, 0.09, 0.1), M_DARK, Vector3(0, 0.75 + sy * 0.42, 1.12), Vector3.ZERO, 0.012)
	for sx in [-1.0, 1.0]:
		K.bb(root, Vector3(0.09, 0.92, 0.1), M_DARK, Vector3(sx * 0.5, 0.75, 1.12), Vector3.ZERO, 0.012)
	K.cy(root, 0.014, 1.2, M_DARK, Vector3(-0.75, 2.3, 0.8))
	if lights:
		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.93, 0.78)
		spot.light_energy = 3.5
		spot.spot_range = 18.0
		spot.spot_angle = 30.0
		spot.shadow_enabled = false
		spot.position = Vector3(0, 0.62, -1.2)
		spot.rotation_degrees = Vector3(-22, 0, 0)
		root.add_child(spot)
	K.socket(root, "arm_l", Vector3(-1.12, 0.85, 0.0), Vector3.LEFT, -1.0)
	K.socket(root, "arm_r", Vector3(1.12, 0.85, 0.0), Vector3.RIGHT, 1.0)
	K.socket(root, "back", Vector3(0, 1.8, 0.6), Vector3(0, 1, 0.25))
	K.socket(root, "gen", Vector3(0, 0.75, 1.1), Vector3.BACK)
	return root
