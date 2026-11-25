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
	# 加粗回转座圈 + 齿圈 + 加强筋 + 下腹承重托架
	K.cy(root, 0.41, 0.24, M_DARK, Vector3(0, 0.115, 0), Vector3.ZERO, 0.36, 32)
	A.add(root, A.torus(0.365, 0.42, 40), A.metal(Color(0.3, 0.3, 0.32)), Vector3(0, 0.15, 0), Vector3.ZERO, Vector3(1, 0.5, 1), false)
	K.bb(root, Vector3(1.52, 0.26, 1.64), M_FRAME, Vector3(0, 0.18, 0.10), Vector3.ZERO, 0.05)
	for i in 8:
		var a := TAU * i / 8.0
		K.bb(root, Vector3(0.05, 0.14, 0.16), M_DARK, Vector3(cos(a) * 0.41, 0.26, sin(a) * 0.41), Vector3(0, -rad_to_deg(a), 0), 0.01)
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
	K.number(gl, ctx.get("serial", "00"), Vector3(-0.53, -0.06, -0.335), Vector3(0, 180, 0), 0.005)
	K.plate(root, K.trap(1.3, 1.76, 0.5, 0.08), 0.2, M_A, Vector3(0, 0.4, -0.94), Vector3(-30, 0, 0), 0.04)
	# 首灯（带重型防撞护笼）+ 铸造牵引耳环
	for sx in [-0.7, 0.7]:
		K.bb(root, Vector3(0.22, 0.11, 0.11), M_DARK, Vector3(sx * 0.9, 0.62, -1.08), Vector3.ZERO, 0.015)
		A.lens(root, Vector3(sx * 0.9, 0.62, -1.135), Vector3(-90, 0, 0), 0.034, Color(1.0, 0.94, 0.80), 2.4)
		K.bb(root, Vector3(0.24, 0.018, 0.06), K.gunmetal(), Vector3(sx * 0.9, 0.68, -1.13), Vector3.ZERO, 0.004)
		A.add(root, A.torus(0.042, 0.078, 12), K.gunmetal(), Vector3(sx * 0.5, 0.30, -1.10), Vector3(0, 0, 90), Vector3.ONE, false)
	# 宽侧短舱（HP-A1 母座在外侧）+ 外挂反应甲 + 顶部护甲 + 侧后防破甲弹栅格装甲
	for sx in [-1.0, 1.0]:
		K.bb(root, Vector3(0.3, 1.0, 1.3), M_A2, Vector3(sx * 0.97, 0.85, 0.05), Vector3.ZERO, 0.04)
		K.era_block(root, Vector3(0.07, 0.24, 0.32), M_A, Vector3(sx * 1.13, 1.02, -0.36), Vector3.ZERO)
		K.era_block(root, Vector3(0.07, 0.24, 0.32), M_A, Vector3(sx * 1.13, 0.72, -0.36), Vector3.ZERO)
		K.plate(root, K.trap(1.4, 1.0, 0.3, 0.08), 0.44, M_A, Vector3(sx * 0.95, 1.42, 0.04), Vector3(0, 90, sx * -8.0), 0.04)
		K.plate(root, K.crect(0.06, 0.2), 0.45, M_ACC, Vector3(sx * 0.95, 1.42, -0.38), Vector3(0, 90, sx * -8.0), 0.005)
		K.grab_iron(root, 0.26, 0.045, Vector3(sx * 0.95, 1.56, 0.08), Vector3(-90, 90, 0))
		A.vent(root, Vector3(0.5, 0.2, 0.04), Vector3(sx * 0.95, 0.55, 0.72), Vector3(0, 180, 0), 5)
		for i in 7:
			K.bb(root, Vector3(0.03, 0.8, 0.03), M_BAR, Vector3(sx * 1.16, 0.85, 0.5 + i * 0.085), Vector3.ZERO, 0.005)
		for yy in [0.48, 1.22]:
			K.bb(root, Vector3(0.038, 0.03, 0.52), M_BAR, Vector3(sx * 1.16, yy, 0.755), Vector3.ZERO, 0.005)
			K.bb(root, Vector3(0.08, 0.035, 0.035), M_BAR, Vector3(sx * 1.12, yy, 0.5), Vector3.ZERO, 0.005)
			K.bb(root, Vector3(0.08, 0.035, 0.035), M_BAR, Vector3(sx * 1.12, yy, 1.01), Vector3.ZERO, 0.005)
		for i in 4:
			K.cy(root, 0.055, 0.24, M_DARK, Vector3(sx * (0.5 + i * 0.1), 1.8, -0.6), Vector3(70, 0, sx * -20.0), -1.0, 10)
			K.cy(root, 0.058, 0.02, K.gunmetal(), Vector3(sx * (0.5 + i * 0.1), 1.84, -0.71), Vector3(70, 0, sx * -20.0), -1.0, 10)
	# 驾驶装甲舱（左前）+ 防弹眉檐观察窗
	var dr := K.node(root, Vector3(-0.42, 1.82, -0.4))
	K.plate(dr, K.crect(0.62, 0.24, [0.08, 0.02, 0.0, 0.06]), 0.52, M_A, Vector3.ZERO, Vector3.ZERO, 0.035)
	K.bb(dr, Vector3(0.50, 0.028, 0.10), K.gunmetal(), Vector3(0, 0.065, -0.24), Vector3(8, 0, 0), 0.005)
	K.bb(dr, Vector3(0.44, 0.055, 0.022), K.canopy(K.VISOR, 0.38), Vector3(0, 0.02, -0.262), Vector3.ZERO, 0.005)
	# 车长指挥塔（右）：装甲圆座 + 周视潜望镜环 + 重型舱盖 + 遥控观瞄转塔
	K.cy(root, 0.36, 0.22, M_A, Vector3(0.4, 1.85, -0.05), Vector3.ZERO, 0.38, 24)
	for i in 8:
		var a := TAU * i / 8.0
		var p := Vector3(0.4 + cos(a) * 0.33, 1.97, -0.05 + sin(a) * 0.33)
		K.periscope(root, 0.11, 0.065, p, Vector3(0, -rad_to_deg(a) - 90.0, 0))
	K.cy(root, 0.28, 0.05, M_A2, Vector3(0.4, 2.01, -0.05), Vector3.ZERO, -1.0, 22)
	K.grab_iron(root, 0.22, 0.045, Vector3(0.4, 2.04, -0.05), Vector3(-90, 0, 0))
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
		K.bb(root, Vector3(0.09, 0.75, 0.1), M_DARK, Vector3(sx * 0.5, 0.75, 1.12), Vector3.ZERO, 0.012)
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
	K.socket(root, "arm_l", Vector3(-1.10, 0.85, 0.0), Vector3.LEFT, -1.0)
	K.socket(root, "arm_r", Vector3(1.10, 0.85, 0.0), Vector3.RIGHT, 1.0)
	K.socket(root, "back", Vector3(0, 1.72, 0.56), Vector3(0, 1, 0.25))
	K.socket(root, "gen", Vector3(0, 0.75, 1.08), Vector3.BACK)
	return root
