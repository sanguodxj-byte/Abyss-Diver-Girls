extends RefCounted
## 重装躯干 HV-3（B.o.T 式）：双层楔形胸甲、低矮装甲头、肩堡、方形排气管
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
	# 重装型（B.o.T 式）：宽厚楔形胸甲叠两层、低矮装甲头、肩顶双排气管、厚重肩堡
	K.bb(torso, Vector3(1.6, 1.0, 1.4), M_FRAME, Vector3(0, 0.15, 0.05), Vector3.ZERO, 0.06)
	K.plate(torso, K.crect(2.0, 0.86, [0.24, 0.24, 0.12, 0.12]), 1.5, M_CORE2, Vector3(0, 0.34, 0.12), Vector3.ZERO, 0.06)
	K.plate(torso, K.trap(1.9, 1.3, 0.4, 0.08), 1.25, M_CORE, Vector3(0, 0.95, 0.18), Vector3.ZERO, 0.05)
	# 前胸：大楔形主甲 + 叠加副甲 + 下颚
	K.plate(torso, K.trap(1.3, 1.7, 0.74, 0.12), 0.18, M_CORE, Vector3(0, 0.3, -0.7), Vector3(-12, 0, 0), 0.05)
	K.plate(torso, K.trap(0.8, 1.1, 0.46, 0.08), 0.1, M_CORE2, Vector3(0, 0.32, -0.82), Vector3(-12, 0, 0), 0.03)
	K.holes(torso, Vector3(0, 0.22, -0.88), Vector3(-12, 0, 0), 6, 2, 0.08, 0.022)
	K.plate(torso, K.trap(1.5, 1.0, 0.36, 0.08), 0.16, M_CORE2, Vector3(0, -0.2, -0.66), Vector3(26, 0, 0), 0.04)
	for sx in [-1.0, 1.0]:
		K.plate(torso, K.crect(0.07, 0.5), 0.19, M_ACC, Vector3(sx * 0.6, 0.32, -0.71), Vector3(-12, 0, sx * -8.0), 0.008)
		# 肩堡：厚切角块盖住臂挂点上方
		var sb := K.node(torso, Vector3(sx * 0.95, 0.92, 0.05), Vector3(0, 0, -sx * 10.0))
		K.plate(sb, K.crect(0.9, 0.34, [0.14, 0.14, 0.0, 0.0]), 0.62, M_CORE, Vector3.ZERO, Vector3(0, 90, 0), 0.05)
		K.plate(sb, K.crect(0.07, 0.36), 0.64, M_ACC, Vector3(0, 0.0, -0.3), Vector3(0, 90, 0), 0.006)
		# 排气管：方形管身 + 斜切管口
		K.plate(torso, K.crect(0.22, 0.8, [0.06, 0.06, 0.06, 0.06]), 0.22, M_DARK, Vector3(sx * 0.55, 1.35, 0.66), Vector3.ZERO, 0.02)
		A.add(torso, A.cyl(0.07, 0.04), A.emit(Color(0.72, 0.44, 0.26), 1.8), Vector3(sx * 0.55, 1.76, 0.66), Vector3.ZERO, Vector3.ONE, false)
		A.vent(torso, Vector3(0.5, 0.3, 0.05), Vector3(sx * 1.0, 0.3, 0.3), Vector3(0, sx * 90.0, 0), 5)
	# 低矮装甲头：嵌在上胸前沿，观察缝 + 双侧传感器
	var hd := K.node(torso, Vector3(0, 0.98, -0.5))
	K.plate(hd, K.trap(0.8, 0.56, 0.3, 0.06), 0.46, M_CORE, Vector3.ZERO, Vector3.ZERO, 0.04)
	K.plate(hd, K.trap(0.66, 0.46, 0.14, 0.03), 0.1, M_CORE2, Vector3(0, -0.02, -0.25), Vector3(-25, 0, 0), 0.02)
	K.bb(hd, Vector3(0.44, 0.03, 0.02), A.emit(K.VISOR, 3.0), Vector3(0, 0.04, -0.24), Vector3.ZERO, 0.004)
	for sx in [-0.3, 0.3]:
		A.lens(hd, Vector3(sx, -0.06, -0.24), Vector3(-90, 0, 0), 0.035, Color(0.80, 0.74, 0.52), 1.6)
	var spot_m := K.node(torso, Vector3(0.62, 1.22, -0.25))
	K.plate(spot_m, K.crect(0.26, 0.18, [0.05, 0.05, 0.0, 0.0]), 0.24, M_DARK, Vector3.ZERO, Vector3.ZERO, 0.02)
	A.lens(spot_m, Vector3(0, 0, -0.13), Vector3(-90, 0, 0), 0.07, Color(1.0, 0.95, 0.8), 4.0)
	K.number(torso, serial, Vector3(-0.45, 0.42, -0.83), Vector3(-12, 180, 0), 0.004)
	A.stencil(torso, "DANGER  HIGH VOLTAGE", Vector3(-0.3, 1.155, 0.4), Vector3(-90, 0, 0), 0.0028, Color(0.62, 0.56, 0.30, 0.8))
	shoulder_x = 1.3
	head_z = -0.86
	head_y = 0.66
	for sx in [-0.3, 0.3]:
		A.add(torso, A.cyl(0.025, 0.03), A.emit(Color(1.0, 0.95, 0.8), 6.0), Vector3(sx, -0.32, -0.8), Vector3(90, 0, 0), Vector3.ONE, false)
	if lights:
		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.93, 0.78)
		spot.light_energy = 3.5
		spot.spot_range = 16.0
		spot.spot_angle = 28.0
		spot.spot_attenuation = 0.6
		spot.shadow_enabled = false
		spot.position = Vector3(0, -0.3, -0.85)
		spot.rotation_degrees = Vector3(-20, 0, 0)
		torso.add_child(spot)

	# ---- 标准接口插座 ----
	K.socket(root, "arm_l", Vector3(-1.03, 0.3, 0.0), Vector3.LEFT, -1.0)
	K.socket(root, "arm_r", Vector3(1.03, 0.3, 0.0), Vector3.RIGHT, 1.0)
	K.socket(root, "back", Vector3(0, 1.14, 0.855 - 0.32), Vector3(0, 1, 0.25))
	K.socket(root, "gen", Vector3(0, 0.12, 0.855), Vector3.BACK)
	return root
