extends RefCounted
## 侦察躯干 SC-1（B.o.T 式）：楔形机首夹出观察缝、侧挂传感舱、轻薄切角甲
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
	# 侦察型（B.o.T 式）：前突楔形机首 + 窄长观察缝 + 侧挂传感舱，整体轻薄
	K.bb(torso, Vector3(1.0, 0.7, 1.0), M_FRAME, Vector3(0, 0.05, 0.1), Vector3.ZERO, 0.06)
	K.plate(torso, K.crect(1.22, 0.58, [0.16, 0.16, 0.08, 0.08]), 1.1, M_CORE2, Vector3(0, 0.26, 0.18), Vector3.ZERO, 0.05)
	K.plate(torso, K.trap(1.1, 0.8, 0.2, 0.05), 0.9, M_CORE, Vector3(0, 0.62, 0.2), Vector3(0, 0, 0), 0.04)
	# 机首：上下两片楔形甲板夹出观察缝
	var nose := K.node(torso, Vector3(0, 0.26, -0.5))
	K.plate(nose, [Vector2(-0.46, 0.0), Vector2(0.46, 0.0), Vector2(0.3, 0.36), Vector2(-0.3, 0.36)], 0.5, M_CORE, Vector3(0, 0.02, -0.08), Vector3(-90, 0, 0), 0.04)
	K.plate(nose, K.trap(0.86, 0.5, 0.32, 0.05), 0.12, M_CORE, Vector3(0, 0.12, -0.2), Vector3(-38, 0, 0), 0.035)
	K.plate(nose, K.trap(0.5, 0.86, 0.36, 0.05), 0.12, M_CORE2, Vector3(0, -0.2, -0.22), Vector3(28, 0, 0), 0.035)
	K.bb(nose, Vector3(0.5, 0.035, 0.02), A.emit(K.VISOR, 3.0), Vector3(0, -0.04, -0.33), Vector3.ZERO, 0.004)
	K.plate(nose, K.crect(0.05, 0.3), 0.13, M_ACC, Vector3(-0.2, 0.13, -0.21), Vector3(-38, 0, 0), 0.006)
	K.holes(torso, Vector3(0, -0.06, -0.75), Vector3(28, 0, 0), 5, 1, 0.08, 0.02)
	for sx in [-1.0, 1.0]:
		var pod := K.node(torso, Vector3(sx * 0.66, 0.56, -0.2))
		K.plate(pod, K.crect(0.16, 0.18, [0.05, 0.05, 0.0, 0.0]), 0.5, M_CORE2, Vector3.ZERO, Vector3.ZERO, 0.025)
		A.lens(pod, Vector3(0, 0.0, -0.26), Vector3(-90, 0, 0), 0.045, Color(0.80, 0.74, 0.52), 1.6)
		K.plate(torso, K.trap(0.8, 0.6, 0.46, 0.06), 0.1, M_CORE, Vector3(sx * 0.63, 0.22, 0.2), Vector3(0, sx * 90.0, sx * 4.0), 0.03)
		A.vent(torso, Vector3(0.3, 0.18, 0.05), Vector3(sx * 0.69, 0.18, 0.34), Vector3(0, sx * 90.0, 0), 4)
	A.vent(torso, Vector3(0.5, 0.26, 0.05), Vector3(0, 0.725, 0.3), Vector3(-90, 0, 0), 5)
	K.number(torso, serial, Vector3(-0.69, 0.32, 0.12), Vector3(0, -90, 0), 0.003)
	K.cy(torso, 0.012, 1.1, M_DARK, Vector3(0.32, 1.35, 0.45))
	A.add(torso, A.sphere(0.03), A.emit(Color(0.66, 0.26, 0.22), 3.0), Vector3(0.32, 1.9, 0.45), Vector3.ZERO, Vector3.ONE, false)
	shoulder_x = 0.98
	head_z = -0.72
	head_y = 0.36
	for sx in [-0.18, 0.18]:
		A.add(torso, A.cyl(0.022, 0.03), A.emit(Color(1.0, 0.95, 0.8), 6.0), Vector3(sx, -0.08, -0.84), Vector3(90, 0, 0), Vector3.ONE, false)
	if lights:
		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.93, 0.78)
		spot.light_energy = 3.5
		spot.spot_range = 16.0
		spot.spot_angle = 28.0
		spot.spot_attenuation = 0.6
		spot.shadow_enabled = false
		spot.position = Vector3(0, -0.05, -0.8)
		spot.rotation_degrees = Vector3(-20, 0, 0)
		torso.add_child(spot)

	# ---- 标准接口插座 ----
	K.socket(root, "arm_l", Vector3(-0.66, 0.3, 0.0), Vector3.LEFT, -1.0)
	K.socket(root, "arm_r", Vector3(0.66, 0.3, 0.0), Vector3.RIGHT, 1.0)
	K.socket(root, "back", Vector3(0, 0.56, 0.725 - 0.32), Vector3(0, 1, 0.25))
	K.socket(root, "gen", Vector3(0, 0.12, 0.725), Vector3.BACK)
	return root
