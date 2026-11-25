extends RefCounted
## 2.9m 宽重型矿山自卸卡车残骸（B4-16 · 对应远端 scripts/raid.gd :: _wreck_car (M2.1 重制)）
## 优化清单：P0-M2.1 | 标准占地：Vector3(2.9, 3.35, 7.2) | 外挑预算 <= 0.25m
## 严格按 M2.1 机甲真实参照尺度（2.9m 宽 × 7.2m 长 × 3.35m 高）重制的重型矿山自卸工程卡车残骸：重型梯形大梁、6 条 1.32m 直径宽幅深花纹矿山巨胎、左偏置防滚驾驶室（含内凹防弹窗与前登车梯）及带外露加强筋与护顶檐的微倾矿石翻斗。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")
const HS = preload("res://scripts/hs.gd")

static func _add_heavy_wheel(parent: Node3D, pos: Vector3, width: float, m_rub: Material, m_gm: Material, m_dk: Material) -> void:
	var wn := K.node(parent, pos, Vector3.ZERO, "HeavyWheel")
	K.cy(wn, 0.66, width, m_rub, Vector3.ZERO, Vector3(0, 0, 90), 0.66, 24)
	# 深花纹矿山胎面防滑块（10 组环向胎齿，消除光滑塑料圆柱感）
	for ti in 10:
		var ang := float(ti) * 36.0
		var rad := deg_to_rad(ang)
		K.bb(wn, Vector3(width * 0.90, 0.055, 0.13), m_rub, Vector3(0.0, cos(rad) * 0.652, sin(rad) * 0.652), Vector3(ang, 0.0, 0.0), 0.008)
	K.cy(wn, 0.37, width + 0.03, m_gm, Vector3.ZERO, Vector3(0, 0, 90), 0.37, 16)
	K.cy(wn, 0.158, width + 0.06, m_dk, Vector3.ZERO, Vector3(0, 0, 90), 0.158, 10)
	# 轮毂紧固螺栓圈（外侧 6 颗）
	var sx_out: float = -1.0 if pos.x < 0.0 else 1.0
	for bi in 6:
		var ba := TAU * float(bi) / 6.0
		K.cy(wn, 0.026, 0.04, m_dk, Vector3(sx_out * (width * 0.5 + 0.022), cos(ba) * 0.255, sin(ba) * 0.255), Vector3(0, 0, 90), 0.026, 6)


static func build(target_sz := Vector3(2.9, 3.35, 7.2)) -> Node3D:
	var root := Node3D.new()
	root.name = "Vehicle_MiningDumpTruck"
	var base_sz := Vector3(2.9, 3.35, 7.2)
	root.scale = Vector3(target_sz.x / base_sz.x, target_sz.y / base_sz.y, target_sz.z / base_sz.z)
	var M_BODY := A.paint(Color("#544a38"), 0.24, 0.74, {
		"wear": 0.68, "rust": 0.72, "grime": 0.82, "dust": 0.44,
		"scratches": 0.44, "panel_scale": 0.85, "albedo_tex_strength": 0.78, "normal_strength": 0.72,
	})
	var M_RUST := A.paint(Color("#3a261b"), 0.34, 0.84, {
		"wear": 0.78, "rust": 0.92, "grime": 0.88, "dust": 0.52,
		"scratches": 0.50, "panel_scale": 0.0, "albedo_tex_strength": 0.72, "normal_strength": 0.70,
	})
	var M_ORE := A.rock_mat(Color(0.37, 0.31, 0.24))
	var M_HAZ := A.hazard()
	var M_RUB := A.rubber()
	var M_DK := K.dark()
	var M_GM := K.gunmetal()
	var n_1 := K.node(root, Vector3.ZERO, Vector3.ZERO, "DumpChassis")
	K.cy(n_1, 0.12, 2.36, M_DK, Vector3(0, 0.66, -2.18), Vector3(0, 0, 90), 0.12, 12)
	_add_heavy_wheel(n_1, Vector3(-1.14, 0.656, -2.18), 0.46, M_RUB, M_GM, M_DK)
	_add_heavy_wheel(n_1, Vector3(1.14, 0.656, -2.18), 0.46, M_RUB, M_GM, M_DK)
	K.cy(n_1, 0.15, 2.48, M_DK, Vector3(0, 0.66, 1.82), Vector3(0, 0, 90), 0.15, 12)
	_add_heavy_wheel(n_1, Vector3(-1.22, 0.656, 1.82), 0.36, M_RUB, M_GM, M_DK)
	_add_heavy_wheel(n_1, Vector3(-0.8, 0.656, 1.82), 0.36, M_RUB, M_GM, M_DK)
	_add_heavy_wheel(n_1, Vector3(0.8, 0.656, 1.82), 0.36, M_RUB, M_GM, M_DK)
	_add_heavy_wheel(n_1, Vector3(1.22, 0.656, 1.82), 0.36, M_RUB, M_GM, M_DK)
	K.bb(n_1, Vector3(0.18, 0.44, 6.55), M_DK, Vector3(-0.46, 0.94, -0.15), Vector3.ZERO, 0.01)
	K.bb(n_1, Vector3(0.18, 0.44, 6.55), M_DK, Vector3(0.46, 0.94, -0.15), Vector3.ZERO, 0.01)
	K.bb(n_1, Vector3(2.78, 0.28, 0.36), M_DK, Vector3(0, 0.9, -3.32), Vector3.ZERO, 0.012)
	# 前防撞杠警示条与双牵引挂钩 + 后轮挡泥护板
	K.bb(n_1, Vector3(0.56, 0.16, 0.06), M_HAZ, Vector3(-1.05, 0.72, -3.49), Vector3.ZERO, 0.004)
	K.bb(n_1, Vector3(0.56, 0.16, 0.06), M_HAZ, Vector3(1.05, 0.72, -3.49), Vector3.ZERO, 0.004)
	K.bb(n_1, Vector3(0.14, 0.16, 0.26), M_RUST, Vector3(-0.56, 0.84, -3.54), Vector3.ZERO, 0.006)
	K.bb(n_1, Vector3(0.14, 0.16, 0.26), M_RUST, Vector3(0.56, 0.84, -3.54), Vector3.ZERO, 0.006)
	for sx_f: float in [-1.0, 1.0]:
		K.bb(n_1, Vector3(0.76, 0.08, 1.65), M_RUST, Vector3(sx_f * 1.04, 1.38, 1.82), Vector3.ZERO, 0.008)
		K.bb(n_1, Vector3(0.72, 0.52, 0.05), M_RUB, Vector3(sx_f * 1.04, 0.84, 2.68), Vector3(8, 0, 0), 0.005)
	var n_8 := K.node(n_1, Vector3(-1.05, 0.92, -3.51), Vector3.ZERO, "Headlight")
	K.bb(n_8, Vector3(0.16, 0.095, 0.095), M_DK, Vector3.ZERO, Vector3.ZERO, 0.01)
	var n_9 := K.node(n_8, Vector3(0, 0, -0.048), Vector3(-90, 0, 0), "OpticalLens")
	K.cy(n_9, 0.038, 0.02, M_DK, Vector3.ZERO, Vector3.ZERO, 0.041, 16)
	K.cy(n_9, 0.032, 0.011, M_GM, Vector3(0, 0.01, 0), Vector3.ZERO, 0.038, 16)
	K.cy(n_9, 0.027, 0.01, K.bore_mat(), Vector3(0, 0.015, 0), Vector3.ZERO, 0.027, 16)
	K.cy(n_9, 0.024, 0.01, K.canopy(Color("#b5afa0"), 0.077), Vector3(0, 0.019, 0), Vector3.ZERO, 0.024, 16)
	K.bb(n_8, Vector3(0.18, 0.016, 0.055), M_GM, Vector3(0, 0.052, -0.036), Vector3.ZERO, 0.004)
	K.bb(n_8, Vector3(0.18, 0.012, 0.045), M_GM, Vector3(0, -0.05, -0.032), Vector3.ZERO, 0.003)
	var n_10 := K.node(n_1, Vector3(1.05, 0.92, -3.51), Vector3.ZERO, "Headlight")
	K.bb(n_10, Vector3(0.16, 0.095, 0.095), M_DK, Vector3.ZERO, Vector3.ZERO, 0.01)
	var n_11 := K.node(n_10, Vector3(0, 0, -0.048), Vector3(-90, 0, 0), "OpticalLens")
	K.cy(n_11, 0.038, 0.02, M_DK, Vector3.ZERO, Vector3.ZERO, 0.041, 16)
	K.cy(n_11, 0.032, 0.011, M_GM, Vector3(0, 0.01, 0), Vector3.ZERO, 0.038, 16)
	K.cy(n_11, 0.027, 0.01, K.bore_mat(), Vector3(0, 0.015, 0), Vector3.ZERO, 0.027, 16)
	K.cy(n_11, 0.024, 0.01, K.canopy(Color("#b5afa0"), 0.077), Vector3(0, 0.019, 0), Vector3.ZERO, 0.024, 16)
	K.bb(n_10, Vector3(0.18, 0.016, 0.055), M_GM, Vector3(0, 0.052, -0.036), Vector3.ZERO, 0.004)
	K.bb(n_10, Vector3(0.18, 0.012, 0.045), M_GM, Vector3(0, -0.05, -0.032), Vector3.ZERO, 0.003)
	K.cy(n_1, 0.34, 1.45, M_RUST, Vector3(-0.96, 0.98, -0.35), Vector3(90, 0, 0), 0.34, 14)
	K.bb(n_1, Vector3(0.58, 0.62, 1.32), M_RUST, Vector3(0.98, 1.02, -0.35), Vector3.ZERO, 0.012)
	var n_12 := K.node(root, Vector3(0, 1.12, -2.35), Vector3.ZERO, "EngineAndCabDeck")
	K.bb(n_12, Vector3(2.82, 0.16, 2.24), M_BODY, Vector3(0, 0.06, 0), Vector3.ZERO, 0.01)
	K.bb(n_12, Vector3(1.46, 1.06, 2.08), M_BODY, Vector3(0.56, 0.64, 0.04), Vector3.ZERO, 0.016)
	K.bb(n_12, Vector3(1.50, 0.10, 2.12), M_RUST, Vector3(0.56, 1.18, 0.04), Vector3.ZERO, 0.008)
	var n_13 := K.node(n_12, Vector3(0.56, 0.66, -1.005), Vector3.ZERO, "Vent")
	K.bb(n_13, Vector3(1.208, 0.808, 0.034), M_DK, Vector3(0, 0, -0.005), Vector3.ZERO, 0.006)
	K.bb(n_13, Vector3(1.109, 0.733, 0.022), K.bore_mat(), Vector3(0, 0, -0.026), Vector3.ZERO, 0.005)
	K.bb(n_13, Vector3(1.062, 0.047, 0.029), M_GM, Vector3(0, -0.325, -0.038), Vector3(-28, 0, 0), 0.004)
	K.bb(n_13, Vector3(1.062, 0.047, 0.029), M_GM, Vector3(0, -0.195, -0.038), Vector3(-28, 0, 0), 0.004)
	K.bb(n_13, Vector3(1.062, 0.047, 0.029), M_GM, Vector3(0, -0.065, -0.038), Vector3(-28, 0, 0), 0.004)
	K.bb(n_13, Vector3(1.062, 0.047, 0.029), M_GM, Vector3(0, 0.065, -0.038), Vector3(-28, 0, 0), 0.004)
	K.bb(n_13, Vector3(1.062, 0.047, 0.029), M_GM, Vector3(0, 0.195, -0.038), Vector3(-28, 0, 0), 0.004)
	K.bb(n_13, Vector3(1.062, 0.047, 0.029), M_GM, Vector3(0, 0.325, -0.038), Vector3(-28, 0, 0), 0.004)
	K.cy(n_12, 0.11, 1.25, M_RUST, Vector3(1.22, 1.48, 0.68), Vector3.ZERO, 0.11, 12)
	K.cy(n_12, 0.065, 0.62, M_DK, Vector3(1.22, 2.28, 0.68), Vector3.ZERO, 0.065, 10)
	var n_14 := K.node(n_12, Vector3(-0.15, 0, 0), Vector3.ZERO, "BoardingLadder")
	K.bb(n_14, Vector3(0.5, 0.08, 0.24), M_RUST, Vector3(0, 0.05, -1.16), Vector3.ZERO, 0.006)
	K.bb(n_14, Vector3(0.042, 0.062, 0.86), M_DK, Vector3(-0.19, -0.31, -1.34), Vector3(-72.5, 0, 0), 0.004)
	K.bb(n_14, Vector3(0.03, 0.048, 0.28), M_GM, Vector3(-0.19, -0.22, -1.24), Vector3.ZERO, 0.003)
	K.bb(n_14, Vector3(0.03, 0.46, 0.03), M_GM, Vector3(-0.19, 0.28, -1.22), Vector3.ZERO, 0.003)
	K.bb(n_14, Vector3(0.042, 0.062, 0.86), M_DK, Vector3(0.19, -0.31, -1.34), Vector3(-72.5, 0, 0), 0.004)
	K.bb(n_14, Vector3(0.03, 0.048, 0.28), M_GM, Vector3(0.19, -0.22, -1.24), Vector3.ZERO, 0.003)
	K.bb(n_14, Vector3(0.03, 0.46, 0.03), M_GM, Vector3(0.19, 0.28, -1.22), Vector3.ZERO, 0.003)
	K.bb(n_14, Vector3(0.39, 0.026, 0.068), M_GM, Vector3(0, -0.014, -1.244), Vector3.ZERO, 0.003)
	K.bb(n_14, Vector3(0.39, 0.026, 0.068), M_GM, Vector3(0, -0.162, -1.292), Vector3.ZERO, 0.003)
	K.bb(n_14, Vector3(0.39, 0.026, 0.068), M_GM, Vector3(0, -0.31, -1.34), Vector3.ZERO, 0.003)
	K.bb(n_14, Vector3(0.39, 0.026, 0.068), M_GM, Vector3(0, -0.458, -1.388), Vector3.ZERO, 0.003)
	K.bb(n_14, Vector3(0.39, 0.026, 0.068), M_GM, Vector3(0, -0.606, -1.436), Vector3.ZERO, 0.003)
	var n_15 := K.node(n_12, Vector3(1.34, 0.14, 0), Vector3.ZERO, "BalconyRailing")
	K.bb(n_15, Vector3(0.036, 0.86, 0.036), M_DK, Vector3(0, 0.43, -0.98), Vector3.ZERO, 0.003)
	K.bb(n_15, Vector3(0.036, 0.86, 0.036), M_DK, Vector3(0, 0.43, 0.98), Vector3.ZERO, 0.003)
	K.bb(n_15, Vector3(0.052, 0.048, 2.08), M_GM, Vector3(0, 0.88, 0), Vector3.ZERO, 0.004)
	var n_16 := K.node(n_12, Vector3(-0.74, 0.12, 0.18), Vector3.ZERO, "ROPSCab")
	var n_17 := K.node(n_16, Vector3.ZERO, Vector3.ZERO, "CavityCore")
	K.bb(n_17, Vector3(0.78, 1.46, 1.12), K.bore_mat(), Vector3(0, 0.72, 0), Vector3.ZERO, 0.022)
	var n_18 := K.node(n_16, Vector3.ZERO, Vector3.ZERO, "StructWall")
	K.bb(n_18, Vector3(0.88, 0.68, 0.18), M_BODY, Vector3(0, 0.36, -0.65), Vector3.ZERO, 0.01)
	K.bb(n_18, Vector3(0.88, 0.08, 0.18), M_BODY, Vector3(0, 1.44, -0.65), Vector3.ZERO, 0.01)
	var n_19 := K.node(n_16, Vector3.ZERO, Vector3.ZERO, "StructPier")
	K.bb(n_19, Vector3(0.14, 1.46, 0.204), M_DK, Vector3(-0.51, 0.75, -0.658), Vector3.ZERO, 0.01)
	K.bb(n_19, Vector3(0.14, 1.46, 0.204), M_DK, Vector3(0.51, 0.75, -0.658), Vector3.ZERO, 0.01)
	var n_20 := K.node(n_16, Vector3(0, 1.05, -0.74), Vector3.ZERO, "RecessedWindow")
	K.bb(n_20, Vector3(0.88, 0.056, 0.15), M_RUST, Vector3(0, -0.322, 0.03), Vector3.ZERO, 0.006)
	K.bb(n_20, Vector3(0.88, 0.05, 0.13), M_RUST, Vector3(0, 0.325, 0.03), Vector3.ZERO, 0.006)
	K.bb(n_20, Vector3(0.88, 0.044, 0.056), M_DK, Vector3(0, 0.278, 0.072), Vector3.ZERO, 0.005)
	K.bb(n_20, Vector3(0.88, 0.044, 0.056), M_DK, Vector3(0, -0.272, 0.072), Vector3.ZERO, 0.005)
	K.bb(n_20, Vector3(0.044, 0.508, 0.056), M_DK, Vector3(-0.418, 0.003, 0.072), Vector3.ZERO, 0.005)
	K.bb(n_20, Vector3(0.044, 0.508, 0.056), M_DK, Vector3(0.418, 0.003, 0.072), Vector3.ZERO, 0.005)
	K.bb(n_20, Vector3(0.796, 0.51, 0.022), K.canopy(Color("#2a3632"), 0.04), Vector3(0, 0.003, 0.11), Vector3.ZERO, 0.003)
	var n_21 := K.node(n_16, Vector3.ZERO, Vector3.ZERO, "StructPier")
	K.bb(n_21, Vector3(1.16, 1.46, 0.204), M_DK, Vector3(0, 0.75, 0.658), Vector3.ZERO, 0.01)
	var n_22 := K.node(n_16, Vector3.ZERO, Vector3.ZERO, "StructPier")
	K.bb(n_22, Vector3(0.204, 1.46, 1.16), M_DK, Vector3(-0.498, 0.75, 0), Vector3.ZERO, 0.01)
	var n_23 := K.node(n_16, Vector3.ZERO, Vector3.ZERO, "StructPier")
	K.bb(n_23, Vector3(0.204, 1.46, 1.16), M_DK, Vector3(0.498, 0.75, 0), Vector3.ZERO, 0.01)
	K.bb(n_16, Vector3(1.24, 0.12, 1.6), M_BODY, Vector3(0, 1.53, 0), Vector3.ZERO, 0.01)
	# 驾驶室侧门防撞护杠与车顶防护笼
	K.bb(n_16, Vector3(0.06, 0.08, 1.02), M_GM, Vector3(-0.63, 0.62, -0.04), Vector3.ZERO, 0.004)
	K.bb(n_16, Vector3(0.32, 0.14, 0.32), M_DK, Vector3(0.0, 1.64, -0.38), Vector3.ZERO, 0.006)
	var n_24 := K.node(root, Vector3(0, 1.24, 1.15), Vector3(6, 0, 0), "RibbedDumpBed")
	K.bb(n_24, Vector3(2.76, 0.22, 4.55), M_BODY, Vector3(0, 0.11, 0), Vector3.ZERO, 0.014)
	# 翻斗内膛重锈磨损耐磨衬板（深锈斑驳质感，打破整车单色塑料感）
	K.bb(n_24, Vector3(2.44, 0.08, 4.30), M_RUST, Vector3(0, 0.24, 0.04), Vector3.ZERO, 0.008)
	K.bb(n_24, Vector3(2.8, 1.58, 0.18), M_BODY, Vector3(0, 0.92, -2.18), Vector3(-12, 0, 0), 0.012)
	var n_25 := K.node(n_24, Vector3(0, 1.68, -2.78), Vector3(-6, 0, 0), "DumpCabCanopy")
	K.bb(n_25, Vector3(2.82, 0.12, 1.38), M_BODY, Vector3.ZERO, Vector3.ZERO, 0.01)
	K.bb(n_25, Vector3(2.88, 0.09, 0.16), M_DK, Vector3(0, 0.02, -0.66), Vector3.ZERO, 0.006)
	for sx_b: float in [-1.0, 1.0]:
		K.bb(n_24, Vector3(0.16, 1.42, 4.48), M_BODY, Vector3(sx_b * 1.34, 0.88, 0.02), Vector3.ZERO, 0.012)
		# 斗壁顶部防撞护舷钢帽 + 下沿纵向加强纵梁 + 5 道外露工字加强肋
		K.bb(n_24, Vector3(0.24, 0.13, 4.54), M_DK, Vector3(sx_b * 1.35, 1.60, 0.02), Vector3.ZERO, 0.008)
		K.bb(n_24, Vector3(0.12, 0.18, 4.50), M_RUST, Vector3(sx_b * 1.44, 0.26, 0.02), Vector3.ZERO, 0.008)
		K.bb(n_24, Vector3(0.08, 1.18, 4.24), M_RUST, Vector3(sx_b * 1.24, 0.86, 0.02), Vector3.ZERO, 0.006)
		for rz_r: float in [-1.75, -0.87, 0.01, 0.89, 1.77]:
			K.bb(n_24, Vector3(0.12, 1.38, 0.18), M_GM, Vector3(sx_b * 1.44, 0.88, rz_r), Vector3.ZERO, 0.006)
	# 翻斗尾缘卸矿槽唇 + 黄黑警示尾杠
	K.bb(n_24, Vector3(2.82, 0.22, 0.22), M_RUST, Vector3(0.0, 0.18, 2.28), Vector3(14, 0, 0), 0.008)
	K.bb(n_24, Vector3(2.42, 0.16, 0.08), M_HAZ, Vector3(0.0, 0.14, 2.38), Vector3.ZERO, 0.004)
	# 翻斗内残留半车碎矿石堆（6 块不规则风化岩块，彻底告别空塑料盒剪影）
	var ore_specs: Array = [
		[Vector3(-0.35, 0.66, -0.65), Vector3(14, 32, -8), Vector3(1.18, 0.62, 1.12), 11],
		[Vector3(0.42, 0.62, -0.15), Vector3(-10, 118, 16), Vector3(1.08, 0.58, 1.16), 17],
		[Vector3(-0.18, 0.78, 0.35), Vector3(8, 205, -14), Vector3(1.12, 0.64, 1.05), 23],
		[Vector3(0.46, 0.50, 0.95), Vector3(-16, 64, 10), Vector3(0.92, 0.46, 0.96), 29],
		[Vector3(-0.56, 0.48, 0.88), Vector3(18, 145, -12), Vector3(0.86, 0.44, 0.88), 37],
		[Vector3(0.06, 0.52, -1.28), Vector3(-12, 274, 8), Vector3(1.02, 0.48, 0.78), 43],
	]
	for os: Array in ore_specs:
		A.add(n_24, A.rock_mesh(int(os[3])), M_ORE, os[0], os[1], os[2], false)
	A.stencil(n_24, "HD-16", Vector3(-1.432, 0.96, -0.85), Vector3(0, -90, 0), 0.014, Color("#b5b2a8"))
	var n_26 := K.node(root, Vector3(-0.46, 1.315, -0.2), Vector3(53.267, -180, 0), "Piston")
	K.cy(n_26, 0.131, 0.46, M_GM, Vector3(0, 0, 0.167), Vector3(90, 0, 0), 0.131, 14)
	K.cy(n_26, 0.148, 0.094, K.brass(), Vector3(0, 0, -0.063), Vector3(90, 0, 0), 0.148, 14)
	K.cy(n_26, 0.075, 0.786, A.chrome(), Vector3(0, 0, -0.017), Vector3(90, 0, 0), 0.075, 12)
	K.bb(n_26, Vector3(0.217, 0.165, 0.188), M_DK, Vector3(0, 0, -0.401), Vector3.ZERO, 0.006)
	K.bb(n_26, Vector3(0.217, 0.165, 0.188), M_DK, Vector3(0, 0, 0.401), Vector3.ZERO, 0.006)
	var n_27 := K.node(root, Vector3(0.46, 1.315, -0.2), Vector3(53.267, -180, 0), "Piston")
	K.cy(n_27, 0.131, 0.46, M_GM, Vector3(0, 0, 0.167), Vector3(90, 0, 0), 0.131, 14)
	K.cy(n_27, 0.148, 0.094, K.brass(), Vector3(0, 0, -0.063), Vector3(90, 0, 0), 0.148, 14)
	K.cy(n_27, 0.075, 0.786, A.chrome(), Vector3(0, 0, -0.017), Vector3(90, 0, 0), 0.075, 12)
	K.bb(n_27, Vector3(0.217, 0.165, 0.188), M_DK, Vector3(0, 0, -0.401), Vector3.ZERO, 0.006)
	K.bb(n_27, Vector3(0.217, 0.165, 0.188), M_DK, Vector3(0, 0, 0.401), Vector3.ZERO, 0.006)
	return root
