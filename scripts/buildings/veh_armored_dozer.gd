extends RefCounted
## 2.85m 宽装甲工程推土机残骸（B4-19 · 对应远端 scripts/map_ext/poi/quarry.gd (M2.1)）
## 优化清单：P0-M2.1 | 标准占地：Vector3(2.85, 3.2, 6.1) | 外挑预算 <= 0.25m
## 参考 D9R 军用装甲破障推土机比例（2.85m 宽 × 6.10m 长 × 3.20m 高）重制：高驱动轮三角重型履带行走架、前部双大口径液压油缸支撑的弧折面重型破障推土铲、带遮阳防弹风挡的高耸防滚装甲驾驶室、斜百叶动力罩与尾部单齿液压破岩松土器。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")
const HS = preload("res://scripts/hs.gd")

static func build(target_sz := Vector3(2.85, 3.2, 6.1)) -> Node3D:
	var root := Node3D.new()
	root.name = "Vehicle_ArmoredDozer"
	var base_sz := Vector3(2.85, 3.2, 6.1)
	root.scale = Vector3(target_sz.x / base_sz.x, target_sz.y / base_sz.y, target_sz.z / base_sz.z)
	var M_BODY := A.paint(Color("#4f4c3c"), 0.26, 0.74, {
		"wear": 0.68, "rust": 0.72, "grime": 0.84, "dust": 0.45,
		"scratches": 0.48, "panel_scale": 0.85, "albedo_tex_strength": 0.78, "normal_strength": 0.72,
	})
	var M_BLADE := A.paint(Color("#3b3228"), 0.52, 0.66, {
		"wear": 0.86, "rust": 0.88, "grime": 0.86, "dust": 0.50,
		"scratches": 0.76, "panel_scale": 0.0, "albedo_tex_strength": 0.74, "normal_strength": 0.75,
	})
	var M_RUST := A.paint(Color("#3a271c"), 0.36, 0.84, {
		"wear": 0.76, "rust": 0.92, "grime": 0.88, "dust": 0.52,
		"scratches": 0.46, "panel_scale": 0.0, "albedo_tex_strength": 0.70, "normal_strength": 0.68,
	})
	var M_HAZ := A.hazard()
	var M_DK := K.dark()
	var M_GM := K.gunmetal()
	var M_RUB := A.rubber()
	var n_1 := K.node(root, Vector3(0, 0, 0.15), Vector3.ZERO, "HighDriveTracks")
	for sx_t: float in [-1.0, 1.0]:
		var tx := sx_t * 1.05
		K.bb(n_1, Vector3(0.56, 0.12, 3.44), M_DK, Vector3(tx, 0.06, 0), Vector3.ZERO, 0.008)
		K.plate(n_1, [Vector2(-1.68, 0.08), Vector2(1.68, 0.08), Vector2(1.82, 0.46), Vector2(0.52, 1.38), Vector2(-0.22, 1.38), Vector2(-1.82, 0.46)], 0.54, M_RUB, Vector3(tx, 0, 0), Vector3(0, 90, 0), 0.012)
		K.cy(n_1, 0.36, 0.6, M_RUST, Vector3(tx, 1.16, 0.18), Vector3(0, 0, 90), 0.36, 14)
		K.cy(n_1, 0.34, 0.58, M_GM, Vector3(tx, 0.44, -1.48), Vector3(0, 0, 90), 0.34, 14)
		K.cy(n_1, 0.34, 0.58, M_GM, Vector3(tx, 0.44, 1.48), Vector3(0, 0, 90), 0.34, 14)
		# 履带支重轮 + 侧向装甲履带防泥裙板 + 钢质履带抓地齿（消除纯黑平板履带感）
		for rz_b: float in [-0.95, -0.32, 0.32, 0.95]:
			K.cy(n_1, 0.19, 0.56, M_DK, Vector3(tx, 0.28, rz_b), Vector3(0, 0, 90), 0.19, 10)
		K.bb(n_1, Vector3(0.46, 0.34, 2.98), M_RUST, Vector3(tx, 0.46, 0), Vector3.ZERO, 0.01)
		for gz_b: float in [-1.52, -1.04, -0.56, -0.08, 0.40, 0.88, 1.36]:
			K.bb(n_1, Vector3(0.60, 0.055, 0.14), M_GM, Vector3(tx, 0.06, gz_b), Vector3.ZERO, 0.004)
		for gi in 4:
			var t_f := float(gi) / 3.0
			K.bb(n_1, Vector3(0.60, 0.055, 0.13), M_GM, Vector3(tx, lerpf(0.56, 1.34, t_f), lerpf(-1.66, -0.26, t_f)), Vector3(-30.0, 0.0, 0.0), 0.004)
			K.bb(n_1, Vector3(0.60, 0.055, 0.13), M_GM, Vector3(tx, lerpf(0.56, 1.34, t_f), lerpf(1.68, 0.54, t_f)), Vector3(34.0, 0.0, 0.0), 0.004)
	var n_hull := K.node(root, Vector3.ZERO, Vector3.ZERO, "DozerHull")
	K.bb(n_hull, Vector3(1.62, 0.78, 3.25), M_BODY, Vector3(0, 0.86, 0.15), Vector3.ZERO, 0.014)
	K.bb(n_hull, Vector3(1.68, 0.18, 0.10), M_HAZ, Vector3(0, 1.02, 1.79), Vector3.ZERO, 0.004)
	var n_2 := K.node(root, Vector3(0, 1.24, -0.8), Vector3.ZERO, "ArmoredEngineHood")
	K.bb(n_2, Vector3(1.46, 0.9, 1.72), M_BODY, Vector3(0, 0.45, 0), Vector3.ZERO, 0.014)
	K.bb(n_2, Vector3(1.50, 0.08, 1.76), M_RUST, Vector3(0, 0.92, 0), Vector3.ZERO, 0.008)
	# 发动机罩两侧防弹散热百叶格栅 + 顶面检修盖板
	for sx_v: float in [-1.0, 1.0]:
		K.bb(n_2, Vector3(0.06, 0.56, 1.18), M_DK, Vector3(sx_v * 0.74, 0.48, -0.06), Vector3.ZERO, 0.004)
		for lv in 4:
			K.bb(n_2, Vector3(0.09, 0.05, 1.08), M_GM, Vector3(sx_v * 0.75, 0.28 + float(lv) * 0.13, -0.06), Vector3(0, 0, sx_v * 20.0), 0.003)
	var n_3 := K.node(n_2, Vector3(0, 0.46, -0.865), Vector3.ZERO, "Vent")
	K.bb(n_3, Vector3(1.108, 0.648, 0.034), M_DK, Vector3(0, 0, -0.005), Vector3.ZERO, 0.006)
	K.bb(n_3, Vector3(1.015, 0.583, 0.022), K.bore_mat(), Vector3(0, 0, -0.026), Vector3.ZERO, 0.005)
	K.bb(n_3, Vector3(0.972, 0.037, 0.029), M_GM, Vector3(0, -0.258, -0.038), Vector3(-28, 0, 0), 0.004)
	K.bb(n_3, Vector3(0.972, 0.037, 0.029), M_GM, Vector3(0, -0.155, -0.038), Vector3(-28, 0, 0), 0.004)
	K.bb(n_3, Vector3(0.972, 0.037, 0.029), M_GM, Vector3(0, -0.052, -0.038), Vector3(-28, 0, 0), 0.004)
	K.bb(n_3, Vector3(0.972, 0.037, 0.029), M_GM, Vector3(0, 0.052, -0.038), Vector3(-28, 0, 0), 0.004)
	K.bb(n_3, Vector3(0.972, 0.037, 0.029), M_GM, Vector3(0, 0.155, -0.038), Vector3(-28, 0, 0), 0.004)
	K.bb(n_3, Vector3(0.972, 0.037, 0.029), M_GM, Vector3(0, 0.258, -0.038), Vector3(-28, 0, 0), 0.004)
	K.cy(n_2, 0.085, 0.95, M_RUST, Vector3(-0.42, 1.32, -0.25), Vector3.ZERO, 0.085, 10)
	K.cy(n_2, 0.085, 0.95, M_RUST, Vector3(0.42, 1.32, -0.25), Vector3.ZERO, 0.085, 10)
	var n_4 := K.node(root, Vector3(0, 1.24, 0.9), Vector3.ZERO, "ArmoredDozerCab")
	var n_5 := K.node(n_4, Vector3.ZERO, Vector3.ZERO, "CavityCore")
	K.bb(n_5, Vector3(1.26, 1.86, 1.32), K.bore_mat(), Vector3(0, 0.9, 0), Vector3.ZERO, 0.022)
	var n_6 := K.node(n_4, Vector3.ZERO, Vector3.ZERO, "StructWall")
	K.bb(n_6, Vector3(1.16, 1.04, 0.18), M_BODY, Vector3(0, 0.52, -0.71), Vector3.ZERO, 0.01)
	K.bb(n_6, Vector3(1.16, 0.14, 0.18), M_BODY, Vector3(0, 1.75, -0.71), Vector3.ZERO, 0.01)
	var n_7 := K.node(n_4, Vector3.ZERO, Vector3.ZERO, "StructPier")
	K.bb(n_7, Vector3(0.2, 1.82, 0.204), M_DK, Vector3(-0.68, 0.91, -0.718), Vector3.ZERO, 0.01)
	K.bb(n_7, Vector3(0.2, 1.82, 0.204), M_DK, Vector3(0.68, 0.91, -0.718), Vector3.ZERO, 0.01)
	var n_8 := K.node(n_4, Vector3(0, 1.36, -0.8), Vector3.ZERO, "RecessedWindow")
	K.bb(n_8, Vector3(1.16, 0.056, 0.15), M_RUST, Vector3(0, -0.292, 0.03), Vector3.ZERO, 0.006)
	K.bb(n_8, Vector3(1.16, 0.05, 0.13), M_RUST, Vector3(0, 0.295, 0.03), Vector3.ZERO, 0.006)
	K.bb(n_8, Vector3(1.16, 0.044, 0.056), M_DK, Vector3(0, 0.248, 0.072), Vector3.ZERO, 0.005)
	K.bb(n_8, Vector3(1.16, 0.044, 0.056), M_DK, Vector3(0, -0.242, 0.072), Vector3.ZERO, 0.005)
	K.bb(n_8, Vector3(0.044, 0.448, 0.056), M_DK, Vector3(-0.558, 0.003, 0.072), Vector3.ZERO, 0.005)
	K.bb(n_8, Vector3(0.044, 0.448, 0.056), M_DK, Vector3(0.558, 0.003, 0.072), Vector3.ZERO, 0.005)
	K.bb(n_8, Vector3(1.076, 0.45, 0.022), K.canopy(Color("#2a3632"), 0.04), Vector3(0, 0.003, 0.11), Vector3.ZERO, 0.003)
	var n_9 := K.node(n_8, Vector3(0, 0.003, 0), Vector3.ZERO, "WindowMuntin")
	K.bb(n_9, Vector3(0.026, 0.455, 0.024), M_GM, Vector3(0, 0, 0.088), Vector3.ZERO, 0.004)
	var n_10 := K.node(n_8, Vector3(0, 0.003, 0), Vector3.ZERO, "SecurityBar")
	K.cy(n_10, 0.011, 0.514, M_DK, Vector3(-0.441, 0, 0.048), Vector3.ZERO, 0.011, 8)
	K.cy(n_10, 0.011, 0.514, M_DK, Vector3(-0.22, 0, 0.048), Vector3.ZERO, 0.011, 8)
	K.cy(n_10, 0.011, 0.514, M_DK, Vector3(0, 0, 0.048), Vector3.ZERO, 0.011, 8)
	K.cy(n_10, 0.011, 0.514, M_DK, Vector3(0.22, 0, 0.048), Vector3.ZERO, 0.011, 8)
	K.cy(n_10, 0.011, 0.514, M_DK, Vector3(0.441, 0, 0.048), Vector3.ZERO, 0.011, 8)
	K.bb(n_10, Vector3(1.13, 0.022, 0.022), M_DK, Vector3(0, 0, 0.046), Vector3.ZERO, 0.003)
	var n_11 := K.node(n_4, Vector3.ZERO, Vector3.ZERO, "StructPier")
	K.bb(n_11, Vector3(1.56, 1.82, 0.204), M_DK, Vector3(0, 0.91, 0.718), Vector3.ZERO, 0.01)
	var n_12 := K.node(n_4, Vector3.ZERO, Vector3.ZERO, "StructPier")
	K.bb(n_12, Vector3(0.204, 1.82, 1.26), M_DK, Vector3(-0.698, 0.91, 0), Vector3.ZERO, 0.01)
	var n_13 := K.node(n_4, Vector3.ZERO, Vector3.ZERO, "StructPier")
	K.bb(n_13, Vector3(0.204, 1.82, 1.26), M_DK, Vector3(0.698, 0.91, 0), Vector3.ZERO, 0.01)
	K.bb(n_4, Vector3(1.68, 0.14, 1.76), M_BODY, Vector3(0, 1.88, 0), Vector3.ZERO, 0.012)
	# 驾驶室侧扶手、顶部装甲空调箱与警示灯护笼
	for sx_c: float in [-1.0, 1.0]:
		K.bb(n_4, Vector3(0.06, 0.84, 0.06), M_GM, Vector3(sx_c * 0.84, 1.04, -0.46), Vector3.ZERO, 0.004)
	K.bb(n_4, Vector3(0.92, 0.24, 0.68), M_RUST, Vector3(0, 2.06, 0.24), Vector3.ZERO, 0.008)
	K.bb(n_4, Vector3(0.32, 0.18, 0.28), M_DK, Vector3(0, 2.02, -0.52), Vector3.ZERO, 0.006)
	var n_14 := K.node(root, Vector3(0, 0, -2.58), Vector3.ZERO, "BulldozerBlade")
	K.plate(n_14, [Vector2(-0.22, 0.04), Vector2(0.14, 0.04), Vector2(0.24, 0.68), Vector2(0.08, 1.42), Vector2(-0.14, 1.48), Vector2(-0.02, 0.68)], 2.84, M_BLADE, Vector3.ZERO, Vector3(0, 90, 0), 0.016)
	K.bb(n_14, Vector3(2.86, 0.16, 0.12), M_GM, Vector3(0, 0.1, -0.18), Vector3.ZERO, 0.006)
	# 破障推土铲背加强筋板 + 顶部防溢石格栅栏 + 双侧端翼板
	for bx_r: float in [-1.18, -0.46, 0.46, 1.18]:
		K.bb(n_14, Vector3(0.12, 1.24, 0.22), M_RUST, Vector3(bx_r, 0.72, 0.18), Vector3(-6, 0, 0), 0.008)
	K.bb(n_14, Vector3(2.82, 0.07, 0.09), M_DK, Vector3(0, 1.66, -0.08), Vector3.ZERO, 0.004)
	for gx_b: float in [-1.20, -0.60, 0.0, 0.60, 1.20]:
		K.bb(n_14, Vector3(0.06, 0.24, 0.06), M_GM, Vector3(gx_b, 1.54, -0.08), Vector3.ZERO, 0.003)
	K.bb(root, Vector3(0.14, 0.22, 2.48), M_BLADE, Vector3(-1.39, 0.44, -1.35), Vector3.ZERO, 0.01)
	var n_15 := K.node(root, Vector3(-0.58, 1.55, -2.05), Vector3(-42.225, 7.275, 0), "Piston")
	K.cy(n_15, 0.119, 0.704, M_GM, Vector3(0, 0, 0.256), Vector3(90, 0, 0), 0.119, 14)
	K.cy(n_15, 0.135, 0.085, K.brass(), Vector3(0, 0, -0.096), Vector3(90, 0, 0), 0.135, 14)
	K.cy(n_15, 0.068, 1.203, A.chrome(), Vector3(0, 0, -0.026), Vector3(90, 0, 0), 0.068, 12)
	K.bb(n_15, Vector3(0.197, 0.15, 0.17), M_DK, Vector3(0, 0, -0.614), Vector3.ZERO, 0.006)
	K.bb(n_15, Vector3(0.197, 0.15, 0.17), M_DK, Vector3(0, 0, 0.614), Vector3.ZERO, 0.006)
	K.bb(root, Vector3(0.14, 0.22, 2.48), M_BLADE, Vector3(1.39, 0.44, -1.35), Vector3.ZERO, 0.01)
	var n_16 := K.node(root, Vector3(0.58, 1.55, -2.05), Vector3(-42.225, -7.275, 0), "Piston")
	K.cy(n_16, 0.119, 0.704, M_GM, Vector3(0, 0, 0.256), Vector3(90, 0, 0), 0.119, 14)
	K.cy(n_16, 0.135, 0.085, K.brass(), Vector3(0, 0, -0.096), Vector3(90, 0, 0), 0.135, 14)
	K.cy(n_16, 0.068, 1.203, A.chrome(), Vector3(0, 0, -0.026), Vector3(90, 0, 0), 0.068, 12)
	K.bb(n_16, Vector3(0.197, 0.15, 0.17), M_DK, Vector3(0, 0, -0.614), Vector3.ZERO, 0.006)
	K.bb(n_16, Vector3(0.197, 0.15, 0.17), M_DK, Vector3(0, 0, 0.614), Vector3.ZERO, 0.006)
	var n_17 := K.node(root, Vector3(0, 0.72, 2.25), Vector3.ZERO, "RearRockRipper")
	K.bb(n_17, Vector3(1.68, 0.24, 0.78), M_DK, Vector3.ZERO, Vector3.ZERO, 0.01)
	K.bb(n_17, Vector3(1.82, 0.26, 0.26), M_BLADE, Vector3(0, -0.06, 0.48), Vector3.ZERO, 0.01)
	K.bb(n_17, Vector3(0.1, 0.78, 0.22), M_GM, Vector3(-0.66, -0.32, 0.56), Vector3(16, 0, 0), 0.008)
	K.bb(n_17, Vector3(0.1, 0.78, 0.22), M_GM, Vector3(0, -0.32, 0.56), Vector3(16, 0, 0), 0.008)
	K.bb(n_17, Vector3(0.1, 0.78, 0.22), M_GM, Vector3(0.66, -0.32, 0.56), Vector3(16, 0, 0), 0.008)
	var n_18 := K.node(root, Vector3(0, 1.1, 2.23), Vector3(-31.891, -180, 0), "Piston")
	K.cy(n_18, 0.126, 0.583, M_GM, Vector3(0, 0, 0.212), Vector3(90, 0, 0), 0.126, 14)
	K.cy(n_18, 0.143, 0.09, K.brass(), Vector3(0, 0, -0.08), Vector3(90, 0, 0), 0.143, 14)
	K.cy(n_18, 0.072, 0.996, A.chrome(), Vector3(0, 0, -0.021), Vector3(90, 0, 0), 0.072, 12)
	K.bb(n_18, Vector3(0.209, 0.158, 0.18), M_DK, Vector3(0, 0, -0.509), Vector3.ZERO, 0.006)
	K.bb(n_18, Vector3(0.209, 0.158, 0.18), M_DK, Vector3(0, 0, 0.509), Vector3.ZERO, 0.006)
	return root
