extends RefCounted
## 1:1 真实人类尺度废弃四门民用小轿车（1.82m 宽 × 1.44m 高 × 4.56m 长）
## 专为衬托 5.65m 泰坦巨物感打造：车顶仅及泰坦膝盖上方（1.44m），四轮轿车三厢比例、倾斜前后风挡、A/B/C 柱、前后保险杠、进气格栅与车灯一应俱全。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")

static func build(target_sz := Vector3(1.82, 1.44, 4.56)) -> Node3D:
	var root := Node3D.new()
	root.name = "Vehicle_CivilSedan_Wreck"
	var base_sz := Vector3(1.82, 1.44, 4.56)
	root.scale = Vector3(target_sz.x / base_sz.x, target_sz.y / base_sz.y, target_sz.z / base_sz.z)

	# 主车身漆面（由 PrefabLib 自动识别为 primary 支持多车色换色，低饱和旧化车漆）
	var M_HULL := A.paint(Color("#4c5258"), 0.42, 0.56, {"wear": 0.58, "rust": 0.46, "grime": 0.74, "dust": 0.30, "panel_scale": 0.0})
	var M_DARK := K.dark()
	var M_RUBBER := A.rubber()
	var M_RIM := K.gunmetal()
	var M_GLASS := K.canopy(Color("#121a21"), 0.08)
	var M_LAMP_F := A.paint(Color("#9aa09c"), 0.25, 0.36, {"wear": 0.40, "panel_scale": 0.0})
	var M_LAMP_R := A.paint(Color("#5e221e"), 0.20, 0.42, {"wear": 0.45, "panel_scale": 0.0})

	# 1. 四轮与底盘悬挂（轮径 0.64m · 半径 0.32m，标准紧凑型家用轿车车轮尺度）
	var n_gear := K.node(root, Vector3.ZERO, Vector3.ZERO, "SedanWheels")
	K.bb(n_gear, Vector3(1.48, 0.16, 3.85), M_DARK, Vector3(0.0, 0.28, 0.0), Vector3.ZERO, 0.02)
	for wz: float in [-1.36, 1.34]:
		K.cy(n_gear, 0.055, 1.56, M_DARK, Vector3(0.0, 0.32, wz), Vector3(0.0, 0.0, 90.0), 0.055, 8)
		for sx_w: float in [-1.0, 1.0]:
			var wp := K.node(n_gear, Vector3(sx_w * 0.79, 0.315, wz), Vector3.ZERO, "CarWheel")
			K.cy(wp, 0.32, 0.21, M_RUBBER, Vector3.ZERO, Vector3(0.0, 0.0, 90.0), 0.32, 18)
			K.cy(wp, 0.19, 0.225, M_RIM, Vector3.ZERO, Vector3(0.0, 0.0, 90.0), 0.19, 12)

	# 2. 三厢下车体（引擎舱 + 乘员下舱 + 后备箱 + 前后塑料保险杠）
	var n_hull := K.node(root, Vector3.ZERO, Vector3.ZERO, "SedanBody")
	K.bb(n_hull, Vector3(1.76, 0.50, 4.32), M_HULL, Vector3(0.0, 0.58, 0.0), Vector3.ZERO, 0.06)
	# 微倾前引擎盖与后备箱盖高差
	K.bb(n_hull, Vector3(1.68, 0.16, 1.28), M_HULL, Vector3(0.0, 0.82, -1.46), Vector3(4.5, 0.0, 0.0), 0.04)
	K.bb(n_hull, Vector3(1.68, 0.16, 0.92), M_HULL, Vector3(0.0, 0.85, 1.62), Vector3(-2.5, 0.0, 0.0), 0.04)
	# 前后防撞保险杠与进气中网、车灯
	K.bb(n_hull, Vector3(1.80, 0.26, 0.24), M_DARK, Vector3(0.0, 0.40, -2.18), Vector3.ZERO, 0.04)
	K.bb(n_hull, Vector3(1.80, 0.28, 0.24), M_DARK, Vector3(0.0, 0.42, 2.18), Vector3.ZERO, 0.04)
	K.bb(n_hull, Vector3(0.86, 0.18, 0.08), M_DARK, Vector3(0.0, 0.62, -2.24), Vector3.ZERO, 0.01)
	for sx_l: float in [-1.0, 1.0]:
		K.bb(n_hull, Vector3(0.34, 0.14, 0.08), M_LAMP_F, Vector3(sx_l * 0.64, 0.66, -2.23), Vector3.ZERO, 0.01)
		K.bb(n_hull, Vector3(0.38, 0.15, 0.08), M_LAMP_R, Vector3(sx_l * 0.62, 0.70, 2.23), Vector3.ZERO, 0.01)

	# 3. 乘员舱车顶与倾斜前后风挡玻璃、A/B/C 柱（顶高精准锁在 1.43m）
	K.bb(n_hull, Vector3(1.48, 0.52, 1.98), M_GLASS, Vector3(0.0, 1.09, 0.10), Vector3.ZERO, 0.04)
	K.bb(n_hull, Vector3(1.44, 0.10, 1.64), M_HULL, Vector3(0.0, 1.38, 0.14), Vector3.ZERO, 0.03)
	# 倾斜前风挡玻璃与后风挡玻璃
	K.bb(n_hull, Vector3(1.46, 0.08, 0.84), M_GLASS, Vector3(0.0, 1.11, -0.92), Vector3(36.0, 0.0, 0.0), 0.02)
	K.bb(n_hull, Vector3(1.44, 0.08, 0.78), M_GLASS, Vector3(0.0, 1.12, 1.12), Vector3(-34.0, 0.0, 0.0), 0.02)
	for sx_p: float in [-1.0, 1.0]:
		# A 柱 / B 柱 / C 柱与外后视镜
		K.bb(n_hull, Vector3(0.07, 0.08, 0.86), M_HULL, Vector3(sx_p * 0.72, 1.12, -0.91), Vector3(36.0, 0.0, 0.0), 0.01)
		K.bb(n_hull, Vector3(0.06, 0.54, 0.10), M_DARK, Vector3(sx_p * 0.74, 1.10, 0.08), Vector3.ZERO, 0.008)
		K.bb(n_hull, Vector3(0.09, 0.10, 0.80), M_HULL, Vector3(sx_p * 0.71, 1.13, 1.12), Vector3(-34.0, 0.0, 0.0), 0.01)
		K.bb(n_hull, Vector3(0.16, 0.10, 0.12), M_DARK, Vector3(sx_p * 0.90, 0.92, -0.68), Vector3.ZERO, 0.01)

	return root
