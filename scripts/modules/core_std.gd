extends RefCounted
## 标准躯干 MK-II（B.o.T 式）：多面切角胸甲、偏置三目传感头、肩部护甲
## 接口：插头 HP-C1（向下）；插座 HP-A1×2、HP-B1、HP-G1
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
	var root := K.module_root("core", id, Vector3.DOWN)
	var torso := root
	var M_CORE := K.armor(c)
	var M_CORE2 := K.armor(c.darkened(0.2))
	var M_GLASS := K.canopy()
	var shoulder_x := 1.05
	var head_z := -0.7
	var head_y := 0.4
	# 标准型（B.o.T 式泰坦胸舱）：机械内胆 + 多面切角胸甲 + 偏置传感头 + 肩部护甲
	K.bb(torso, Vector3(1.3, 0.9, 1.1), M_FRAME, Vector3(0, 0.15, 0.05), Vector3.ZERO, 0.06)
	K.plate(torso, K.crect(1.5, 0.66, [0.18, 0.18, 0.1, 0.1]), 1.12, M_CORE2, Vector3(0, 0.36, 0.1), Vector3.ZERO, 0.05)
	# 胸甲：中央六边形主板 + 两翼斜板 + 下腹甲
	K.plate(torso, K.crect(0.74, 0.62, [0.14, 0.14, 0.2, 0.2]), 0.14, M_CORE, Vector3(0, 0.3, -0.56), Vector3(-10, 0, 0), 0.04)
	K.plate(torso, K.crect(0.44, 0.34, [0.08, 0.08, 0.12, 0.12]), 0.06, M_CORE2, Vector3(0, 0.3, -0.64), Vector3(-10, 0, 0), 0.02)
	K.holes(torso, Vector3(0, 0.26, -0.68), Vector3(-10, 0, 0), 4, 2, 0.07, 0.02)
	for sx in [-1.0, 1.0]:
		K.plate(torso, K.trap(0.5, 0.42, 0.6, 0.06), 0.12, M_CORE, Vector3(sx * 0.52, 0.32, -0.46), Vector3(-8, sx * 28.0, 0), 0.035)
		K.plate(torso, K.crect(0.06, 0.4), 0.13, M_ACC, Vector3(sx * 0.66, 0.34, -0.39), Vector3(-8, sx * 28.0, 0), 0.008)
		# 肩部护甲（悬在臂挂点上方）
		var sp := K.node(torso, Vector3(sx * 0.72, 0.78, 0.02), Vector3(0, 0, -sx * 14.0))
		K.plate(sp, K.trap(0.62, 0.42, 0.22, 0.05), 0.9, M_CORE, Vector3.ZERO, Vector3(0, 90, 0), 0.04)
		K.plate(sp, K.crect(0.06, 0.24), 0.92, M_ACC, Vector3(0, 0.0, 0.0), Vector3(0, 90, 0), 0.005)
		A.vent(torso, Vector3(0.36, 0.24, 0.05), Vector3(sx * 0.77, 0.24, 0.3), Vector3(0, sx * 90.0, 0), 5)
	K.plate(torso, K.trap(0.66, 1.0, 0.28, 0.06), 0.14, M_CORE2, Vector3(0, -0.12, -0.5), Vector3(22, 0, 0), 0.035)
	# 背部散热格栅与天线
	A.vent(torso, Vector3(0.7, 0.3, 0.05), Vector3(0, 0.71, 0.32), Vector3(-90, 0, 0), 6)
	K.cy(torso, 0.012, 1.0, M_DARK, Vector3(-0.5, 1.2, 0.45))
	K.number(torso, serial, Vector3(-0.22, 0.4, -0.665), Vector3(-10, 180, 0), 0.0034)
	A.stencil(torso, "NO STEP", Vector3(0.35, 0.695, 0.3), Vector3(-90, 0, 0), 0.0028, Color(0.95, 0.92, 0.85, 0.75))
	# 偏置传感头：切角头壳 + 细长观察缝 + 三目传感器
	var hd := K.node(torso, Vector3(0.22, 0.84, -0.28))
	K.plate(hd, K.crect(0.44, 0.3, [0.1, 0.04, 0.0, 0.08]), 0.5, M_CORE, Vector3.ZERO, Vector3(0, 0, 0), 0.04)
	K.plate(hd, K.trap(0.4, 0.3, 0.12, 0.02), 0.1, M_CORE2, Vector3(0, 0.0, -0.27), Vector3(-30, 0, 0), 0.02)
	K.bb(hd, Vector3(0.3, 0.03, 0.02), A.emit(K.VISOR, 3.0), Vector3(0, 0.07, -0.252), Vector3.ZERO, 0.004)
	for i in 3:
		A.lens(hd, Vector3(-0.1 + i * 0.1, -0.06, -0.26), Vector3(-90, 0, 0), 0.03 if i != 1 else 0.042, Color(1.0, 0.85, 0.2), 2.0)
	shoulder_x = 1.1
	head_z = -0.7
	head_y = 0.4
	# 胸下探照灯（小型灯组，不做「两只眼」）
	for sx in [-0.2, 0.2]:
		K.bb(torso, Vector3(0.12, 0.06, 0.06), M_DARK, Vector3(sx, head_y - 0.42, head_z + 0.08), Vector3.ZERO, 0.012)
		A.add(torso, A.cyl(0.022, 0.03), A.emit(Color(1.0, 0.95, 0.8), 6.0), Vector3(sx, head_y - 0.42, head_z + 0.04), Vector3(90, 0, 0), Vector3.ONE, false)
	if lights:
		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.93, 0.78)
		spot.light_energy = 3.5
		spot.spot_range = 16.0
		spot.spot_angle = 28.0
		spot.spot_attenuation = 0.6
		spot.shadow_enabled = false
		spot.position = Vector3(0, head_y - 0.38, head_z)
		spot.rotation_degrees = Vector3(-24, 0, 0)
		torso.add_child(spot)

	# ---- 标准接口插座 ----
	K.socket(root, "arm_l", Vector3(-0.8, 0.3, 0.0), Vector3.LEFT, -1.0)
	K.socket(root, "arm_r", Vector3(0.8, 0.3, 0.0), Vector3.RIGHT, 1.0)
	K.socket(root, "back", Vector3(0, 0.74, 0.68 - 0.32), Vector3(0, 1, 0.25))
	K.socket(root, "gen", Vector3(0, 0.12, 0.68), Vector3.BACK)
	return root
