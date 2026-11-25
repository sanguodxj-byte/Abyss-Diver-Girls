extends RefCounted
## 突击躯干 AS-3：楔形倾斜首上装甲、两侧挂臂短舱、潜望镜组、顶部舱盖、后倾发动机甲板
## 接口：插头 HP-C1（向下，经回转座圈接底盘）；插座 HP-A1×2（短舱外侧）、HP-B1（后倾甲板）、HP-G1（尾部动力舱框）
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var c: Color = ctx.color
	var lights: bool = ctx.get("lights", true)
	var root := K.module_root("core", ctx.id, Vector3.DOWN)
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var M_ACC := K.accent()
	var M_A := K.armor(c, 0.5)
	var M_A2 := K.armor(c.darkened(0.22), 0.5)
	# 回转座圈（压在 HP-C1 插头上，紧致包覆接口）+ 齿圈 + 下腹装甲托盘
	K.cy(root, 0.365, 0.22, M_DARK, Vector3(0, 0.105, 0), Vector3.ZERO, 0.36, 28)
	A.add(root, A.torus(0.335, 0.375, 36), A.metal(Color(0.3, 0.3, 0.32)), Vector3(0, 0.10, 0), Vector3.ZERO, Vector3(1, 0.5, 1), false)
	K.bb(root, Vector3(1.12, 0.24, 1.04), M_FRAME, Vector3(0, 0.18, 0.04), Vector3.ZERO, 0.04)
	# 车体内胆
	K.bb(root, Vector3(1.3, 0.86, 1.2), M_FRAME, Vector3(0, 0.66, 0.08), Vector3.ZERO, 0.05)
	# 首上倾斜装甲 + 爆炸反应装甲块 + 首下防弹板
	K.plate(root, K.trap(1.34, 1.02, 0.78, 0.08), 0.12, M_A, Vector3(0, 0.72, -0.62), Vector3(35, 0, 0), 0.04)
	for ex in [-0.32, 0.0]:
		K.era_block(root, Vector3(0.28, 0.22, 0.055), M_A2, Vector3(ex, 0.76, -0.67), Vector3(35, 0, 0))
	K.plate(root, K.trap(1.0, 1.32, 0.36, 0.06), 0.1, M_A2, Vector3(0, 0.3, -0.6), Vector3(-30, 0, 0), 0.03)
	K.plate(root, K.crect(1.0, 0.05), 0.125, M_ACC, Vector3(0, 0.98, -0.45), Vector3(35, 0, 0), 0.005)
	A.rivets(root, Vector3(-0.5, 0.48, -0.78), Vector3(0.5, 0.48, -0.78), 9, 0.016, Vector3(-55, 0, 0))
	K.number(root, ctx.get("serial", "00"), Vector3(0.34, 0.66, -0.80), Vector3(-35, 180, 0), 0.0034)
	# 带防撞护框的首灯 + 锻造牵引钩 + 攀爬抓手
	for sx in [-0.42, 0.42]:
		K.bb(root, Vector3(0.15, 0.09, 0.09), M_DARK, Vector3(sx, 0.42, -0.74), Vector3.ZERO, 0.012)
		A.lens(root, Vector3(sx, 0.42, -0.785), Vector3(-90, 0, 0), 0.026, Color(1.0, 0.94, 0.80), 2.2)
		K.bb(root, Vector3(0.17, 0.016, 0.05), K.gunmetal(), Vector3(sx, 0.47, -0.78), Vector3.ZERO, 0.004)
		A.add(root, A.torus(0.03, 0.055, 12), K.gunmetal(), Vector3(sx * 0.5, 0.18, -0.74), Vector3(0, 0, 90), Vector3.ONE, false)
	K.grab_iron(root, 0.28, 0.045, Vector3(-0.18, 0.96, -0.48), Vector3(35, 0, 0))
	# 两侧挂臂短舱（HP-A1 母座装在外侧面）
	for sx in [-1.0, 1.0]:
		K.bb(root, Vector3(0.2, 0.56, 0.74), M_A2, Vector3(sx * 0.72, 0.45, 0.05), Vector3.ZERO, 0.03)
		K.plate(root, K.trap(0.8, 0.6, 0.2, 0.05), 0.32, M_A, Vector3(sx * 0.7, 0.81, 0.04), Vector3(0, 90, sx * -8.0), 0.03)
		K.plate(root, K.crect(0.05, 0.16), 0.33, M_ACC, Vector3(sx * 0.7, 0.81, -0.2), Vector3(0, 90, sx * -8.0), 0.004)
		K.grab_iron(root, 0.22, 0.04, Vector3(sx * 0.70, 0.92, 0.10), Vector3(-90, 90, 0))
		A.vent(root, Vector3(0.36, 0.16, 0.04), Vector3(sx * 0.66, 0.36, 0.5), Vector3(0, 180, 0), 4)
	# 装甲潜望镜组 + 顶部铰链舱盖 + 稳定观瞄头
	for i in 3:
		var px := -0.26 + i * 0.26
		K.periscope(root, 0.16, 0.09, Vector3(px, 1.13, -0.36), Vector3(0, (i - 1) * -18.0, 0))
	K.cy(root, 0.24, 0.06, M_A, Vector3(0.24, 1.12, 0.08), Vector3.ZERO, -1.0, 22)
	K.cy(root, 0.2, 0.03, M_A2, Vector3(0.24, 1.16, 0.08), Vector3.ZERO, -1.0, 20)
	K.grab_iron(root, 0.18, 0.04, Vector3(0.24, 1.18, 0.08), Vector3(-90, 0, 0))
	var hd := K.node(root, Vector3(-0.36, 1.17, -0.18))
	K.plate(hd, K.crect(0.32, 0.19, [0.06, 0.02, 0.02, 0.04]), 0.30, M_A, Vector3.ZERO, Vector3.ZERO, 0.03)
	K.bb(hd, Vector3(0.34, 0.024, 0.10), K.gunmetal(), Vector3(0, 0.08, -0.13), Vector3(8, 0, 0), 0.005)
	for i in 2:
		A.lens(hd, Vector3(-0.065 + i * 0.13, -0.01, -0.155), Vector3(-90, 0, 0), 0.03, Color(0.95, 0.78, 0.22), 1.6)
	# 后倾发动机甲板（HP-B1 母座在其上）+ 两侧格栅
	K.plate(root, K.crect(1.16, 0.62, [0.08, 0.08, 0.08, 0.08]), 0.08, M_A2, Vector3(0, 1.07, 0.42), Vector3(104, 0, 0), 0.02)
	for sx in [-1.0, 1.0]:
		A.vent(root, Vector3(0.2, 0.5, 0.04), Vector3(sx * 0.5, 1.115, 0.43), Vector3(-76, 0, 0), 5)
	A.stencil(root, "NO STEP", Vector3(-0.42, 1.12, 0.02), Vector3(-90, 0, 0), 0.0026, Color(0.95, 0.92, 0.85, 0.75))
	# 尾部动力舱框（HP-G1 母座在框内）
	for sy in [-1.0, 1.0]:
		K.bb(root, Vector3(0.96, 0.06, 0.08), M_DARK, Vector3(0, 0.55 + sy * 0.39, 0.66), Vector3.ZERO, 0.01)
	for sx in [-1.0, 1.0]:
		K.bb(root, Vector3(0.06, 0.72, 0.08), M_DARK, Vector3(sx * 0.46, 0.55, 0.66), Vector3.ZERO, 0.01)
	K.cy(root, 0.012, 0.9, M_DARK, Vector3(-0.55, 1.5, 0.55))
	if lights:
		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.93, 0.78)
		spot.light_energy = 3.5
		spot.spot_range = 16.0
		spot.spot_angle = 28.0
		spot.shadow_enabled = false
		spot.position = Vector3(0, 0.45, -0.8)
		spot.rotation_degrees = Vector3(-22, 0, 0)
		root.add_child(spot)
	# ---- 标准接口插座 ----
	K.socket(root, "arm_l", Vector3(-0.80, 0.45, 0.0), Vector3.LEFT, -1.0)
	K.socket(root, "arm_r", Vector3(0.80, 0.45, 0.0), Vector3.RIGHT, 1.0)
	K.socket(root, "back", Vector3(0, 1.06, 0.40), Vector3(0, 1, 0.25))
	K.socket(root, "gen", Vector3(0, 0.55, 0.68), Vector3.BACK)
	return root
