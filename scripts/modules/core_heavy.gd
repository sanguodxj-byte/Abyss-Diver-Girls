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
	var M_GUN := K.gunmetal()
	var M_ACC := K.accent()
	var root := K.module_root("core", id, Vector3.DOWN)
	var torso := root
	var M_CORE := K.armor(c, 0.48)
	var M_CORE2 := K.armor_sub(c, 0.52)

	# 重型腰部齿圈轴承 + 铸钢胸舱骨架
	K.cy(torso, 0.39, 0.18, M_DARK, Vector3(0, 0.085, 0.0), Vector3.ZERO, 0.36, 30)
	A.add(torso, A.torus(0.355, 0.405, 32), M_GUN, Vector3(0, 0.10, 0.0), Vector3.ZERO, Vector3(1, 0.48, 1), false)
	K.bb(torso, Vector3(1.62, 0.80, 1.42), M_FRAME, Vector3(0, 0.37, 0.06), Vector3.ZERO, 0.055)
	K.plate(torso, K.crect(2.02, 0.88, [0.24, 0.24, 0.12, 0.12]), 1.50, M_CORE2, Vector3(0, 0.36, 0.12), Vector3.ZERO, 0.055)
	K.plate(torso, K.trap(1.92, 1.32, 0.42, 0.08), 1.26, M_CORE, Vector3(0, 0.96, 0.18), Vector3.ZERO, 0.048)

	# 前胸：大倾角重型主甲 + 反应装甲砖阵列 + 下腹防破片铲板
	K.plate(torso, K.trap(1.34, 1.72, 0.76, 0.12), 0.18, M_CORE, Vector3(0, 0.34, -0.70), Vector3(-12, 0, 0), 0.048)
	K.plate(torso, K.trap(0.84, 1.12, 0.46, 0.08), 0.10, M_CORE2, Vector3(0, 0.36, -0.82), Vector3(-12, 0, 0), 0.028)
	K.holes(torso, Vector3(0, 0.22, -0.88), Vector3(-12, 0, 0), 6, 2, 0.08, 0.020)
	K.plate(torso, K.trap(1.52, 1.04, 0.36, 0.08), 0.16, M_CORE2, Vector3(0, -0.14, -0.66), Vector3(26, 0, 0), 0.038)
	# 编号置于副甲正中上方平整区（Ry(180)*Rx(+12) 严格平行于 Rx(-12) 副胸甲，零裁切！）
	K.number(torso, serial, Vector3(-0.24, 0.43, -0.896), Vector3(12, 180, 0), 0.0038)

	for sx in [-1.0, 1.0]:
		K.era_block(torso, Vector3(0.24, 0.18, 0.06), M_CORE2, Vector3(sx * 0.62, 0.46, -0.79), Vector3(-12, 0, 0))
		K.era_block(torso, Vector3(0.24, 0.18, 0.06), M_CORE2, Vector3(sx * 0.62, 0.24, -0.75), Vector3(-12, 0, 0))
		K.plate(torso, K.crect(0.065, 0.50), 0.19, M_ACC, Vector3(sx * 0.80, 0.36, -0.70), Vector3(-12, 0, sx * -8.0), 0.006)
		# 厚重肩堡：外挂反应甲 + 吊装环 + 三联烟幕发射器
		var sb := K.node(torso, Vector3(sx * 0.95, 0.94, 0.05), Vector3(0, 0, -sx * 10.0))
		K.plate(sb, K.crect(0.92, 0.35, [0.14, 0.14, 0.0, 0.0]), 0.64, M_CORE, Vector3.ZERO, Vector3(0, 90, 0), 0.045)
		K.plate(sb, K.crect(0.065, 0.36), 0.66, M_ACC, Vector3(0, 0.0, -0.30), Vector3(0, 90, 0), 0.006)
		K.grab_iron(sb, 0.26, 0.045, Vector3(0, 0.18, 0.0), Vector3(-90, 90, 0))
		for k in 3:
			K.cy(sb, 0.040, 0.18, M_DARK, Vector3(sx * (0.10 + k * 0.08), 0.16, -0.38), Vector3(68, 0, sx * -14.0), -1.0, 10)
		# 重型工业排气管：冲孔隔热护罩 + 双联熏黑斜切排烟管 + 活门防雨盖
		var ex := K.node(torso, Vector3(sx * 0.58, 1.36, 0.68), Vector3(8, 0, sx * -4.0))
		K.bb(ex, Vector3(0.26, 0.72, 0.24), M_GUN, Vector3(0, 0, 0), Vector3.ZERO, 0.025)
		K.holes(ex, Vector3(0, 0.02, 0.125), Vector3(0, 180, 0), 2, 5, 0.09, 0.020)
		for px in [-0.055, 0.055]:
			K.cy(ex, 0.046, 0.88, M_DARK, Vector3(px, 0.06, 0), Vector3.ZERO, -1.0, 14)
			K.barrel_bore(ex, 0.046, 0.036, Vector3(px, 0.50, 0), 0.06, Vector3(0, 0, 0))
			K.bb(ex, Vector3(0.10, 0.015, 0.11), M_GUN, Vector3(px, 0.535, 0.02), Vector3(-22, 0, 0), 0.004)
		A.vent(torso, Vector3(0.52, 0.32, 0.05), Vector3(sx * 1.01, 0.34, 0.30), Vector3(0, sx * 90.0, 0), 5)
		# 下部带护笼前照灯 + 重型锻钢牵引U型钩
		K.bb(torso, Vector3(0.18, 0.10, 0.10), M_DARK, Vector3(sx * 0.42, -0.18, -0.78), Vector3.ZERO, 0.014)
		A.lens(torso, Vector3(sx * 0.42, -0.18, -0.83), Vector3(-90, 0, 0), 0.032, Color(1.0, 0.94, 0.80), 2.4)
		K.bb(torso, Vector3(0.20, 0.018, 0.06), M_GUN, Vector3(sx * 0.42, -0.12, -0.83), Vector3.ZERO, 0.004)
		A.add(torso, A.torus(0.038, 0.070, 12), M_GUN, Vector3(sx * 0.22, -0.20, -0.80), Vector3(0, 0, 90), Vector3.ONE, false)

	# 嵌入式重装甲指挥头：防弹眉檐 + 镀膜观察缝 + 双侧热成像镜
	var hd := K.node(torso, Vector3(0, 1.00, -0.50))
	K.plate(hd, K.trap(0.82, 0.58, 0.32, 0.06), 0.48, M_CORE, Vector3.ZERO, Vector3.ZERO, 0.04)
	K.bb(hd, Vector3(0.64, 0.034, 0.14), M_GUN, Vector3(0, 0.09, -0.24), Vector3(8, 0, 0), 0.006)
	K.plate(hd, K.trap(0.68, 0.48, 0.14, 0.03), 0.10, M_CORE2, Vector3(0, -0.03, -0.25), Vector3(-25, 0, 0), 0.02)
	K.bb(hd, Vector3(0.46, 0.045, 0.024), K.canopy(K.VISOR, 0.40), Vector3(0, 0.045, -0.246), Vector3.ZERO, 0.004)
	for sx in [-0.30, 0.30]:
		A.lens(hd, Vector3(sx, -0.055, -0.245), Vector3(-90, 0, 0), 0.032, Color(0.95, 0.75, 0.22), 1.5)

	# 右肩散热翼片大功率装甲探照灯箱（带防弹百叶护栅与遮光檐）
	var spot_m := K.node(torso, Vector3(0.62, 1.24, -0.25))
	K.bb(spot_m, Vector3(0.28, 0.20, 0.26), M_DARK, Vector3.ZERO, Vector3.ZERO, 0.02)
	K.bb(spot_m, Vector3(0.30, 0.022, 0.08), M_GUN, Vector3(0, 0.095, -0.125), Vector3(10, 0, 0), 0.004)
	for fi in 4:
		K.bb(spot_m, Vector3(0.30, 0.015, 0.20), M_GUN, Vector3(0, -0.06 + fi * 0.04, 0.02), Vector3.ZERO, 0.003)
	A.add(spot_m, A.torus(0.058, 0.082, 18), M_GUN, Vector3(0, 0, -0.140), Vector3(90, 0, 0), Vector3(1, 0.55, 1), false)
	A.lens(spot_m, Vector3(0, 0, -0.122), Vector3(-90, 0, 0), 0.056, Color(1.0, 0.93, 0.78), 1.5)
	for sy in [-0.036, 0.0, 0.036]:
		K.bb(spot_m, Vector3(0.150, 0.013, 0.030), M_DARK, Vector3(0, sy, -0.160), Vector3(12, 0, 0), 0.002)
	A.stencil(torso, "DANGER  HIGH VOLTAGE", Vector3(-0.32, 1.175, 0.40), Vector3(-90, 0, 0), 0.0028, Color(0.95, 0.85, 0.30, 0.82))

	if lights:
		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.93, 0.78)
		spot.light_energy = 3.5
		spot.spot_range = 16.0
		spot.spot_angle = 28.0
		spot.spot_attenuation = 0.6
		spot.shadow_enabled = false
		spot.position = Vector3(0, -0.18, -0.88)
		spot.rotation_degrees = Vector3(-20, 0, 0)
		torso.add_child(spot)

	# ---- 标准接口插座 ----
	K.socket(root, "arm_l", Vector3(-1.01, 0.3, 0.0), Vector3.LEFT, -1.0)
	K.socket(root, "arm_r", Vector3(1.01, 0.3, 0.0), Vector3.RIGHT, 1.0)
	K.socket(root, "back", Vector3(0, 1.06, 0.855 - 0.32), Vector3(0, 1, 0.25))
	K.socket(root, "gen", Vector3(0, 0.12, 0.835), Vector3.BACK)
	return root
