extends RefCounted
## 2.65m 宽半挂重型油罐拖车残骸（B4-18 · 对应 scripts/raid.gd & poi/fuel_depot.gd）
## 优化清单：P0-M2.1 | 标准占地：Vector3(2.65, 3.15, 7.5) | 外挑预算 <= 0.25m
## 2.65m 宽 × 7.50m 长平头重卡牵引车 + 24 段工业成品油储运罐体车残骸：
## 前部平头驾驶室（内凹前风挡、左右侧窗与车门缝、后视镜支架、登车踏板、进气格栅、保险杠大灯、车顶示廓灯与双立式排气管）；
## 后部 24 段风化锈蚀罐体（与车头共享主涂装投票）、凸出加劲箍环与鞍座托架、双侧警示条纹与防撞护栏、后轮挡泥瓦、
## 罐顶防溢护栏与检修走道、三联呼吸人孔盖、侧面输油阀门管汇箱与尾部攀爬钢梯。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")
const HS = preload("res://scripts/hs.gd")


static func _add_wheel_pair(parent: Node3D, z_pos: float, half_x: float, tire_w: float, m_hub: Material, m_lug: Material) -> void:
	K.cy(parent, 0.10, half_x * 2.0 + 0.10, K.dark(), Vector3(0.0, 0.50, z_pos), Vector3(0.0, 0.0, 90.0), 0.10, 10)
	for sgn: float in [-1.0, 1.0]:
		var wn := K.node(parent, Vector3(sgn * half_x, 0.496, z_pos), Vector3.ZERO, "HeavyWheel")
		K.cy(wn, 0.50, tire_w, A.rubber(), Vector3.ZERO, Vector3(0.0, 0.0, 90.0), 0.50, 24)
		# 外侧胎肩防滑筋圈与重型轮毂螺栓圈
		K.cy(wn, 0.46, tire_w + 0.015, A.rubber(), Vector3.ZERO, Vector3(0.0, 0.0, 90.0), 0.46, 16)
		K.cy(wn, 0.28, tire_w + 0.03, m_hub, Vector3.ZERO, Vector3(0.0, 0.0, 90.0), 0.28, 16)
		K.cy(wn, 0.13, tire_w + 0.06, K.dark(), Vector3.ZERO, Vector3(0.0, 0.0, 90.0), 0.13, 10)
		for bi in 6:
			var ang := float(bi) * TAU / 6.0
			K.cy(wn, 0.025, 0.03, m_lug, Vector3(sgn * (tire_w * 0.5 + 0.022), sin(ang) * 0.19, cos(ang) * 0.19), Vector3(0.0, 0.0, 90.0), 0.025, 6)
	for sx: float in [-0.48, 0.48]:
		K.bb(parent, Vector3(0.13, 0.38, 0.26), K.dark(), Vector3(sx, 0.66, z_pos), Vector3.ZERO, 0.006)


static func build(target_sz := Vector3(2.65, 3.15, 7.5)) -> Node3D:
	var root := Node3D.new()
	root.name = "Vehicle_SemiFuelTanker"
	var base_sz := Vector3(2.65, 3.15, 7.5)
	root.scale = Vector3(target_sz.x / base_sz.x, target_sz.y / base_sz.y, target_sz.z / base_sz.z)

	# 主车身与主罐体共享同一风化重工涂装，确保 prefab_lib primary_votes 一致重着色
	var M_BODY := A.paint(Color("#545b58"), 0.26, 0.72, {
		"wear": 0.64, "rust": 0.68, "grime": 0.82, "dust": 0.42, "scratches": 0.48, "panel_scale": 0.0,
	})
	# 罐体封头、加劲环、结构件使用高金属度风化冷轧钢（metal_base >= 0.60 不抢主色投票）
	var M_TANK_END := A.paint(Color("#5c6064"), 0.66, 0.58, {
		"wear": 0.56, "rust": 0.62, "grime": 0.74, "dust": 0.36, "scratches": 0.42, "panel_scale": 0.0,
	})
	var M_RING := A.paint(Color("#2a2d30"), 0.64, 0.66, {
		"wear": 0.55, "rust": 0.78, "grime": 0.84, "dust": 0.38, "panel_scale": 0.0,
	})
	var M_VALVE_BOX := A.paint(Color("#5c5340"), 0.62, 0.68, {
		"wear": 0.58, "rust": 0.72, "grime": 0.80, "dust": 0.36, "panel_scale": 0.0,
	})
	var M_TRIM := K.gunmetal()
	var M_DARK := K.dark()
	var M_HAZ := A.hazard()
	var M_GLASS := K.canopy(Color("#232d2b"), 0.03)
	var M_HEADLIGHT := A.paint(Color("#9aa09a"), 0.20, 0.35, {"wear": 0.30, "dust": 0.50, "panel_scale": 0.0})
	var M_TAILLIGHT := A.paint(Color("#6b241d"), 0.15, 0.44, {"wear": 0.35, "grime": 0.55, "panel_scale": 0.0})

	# ==================== 前部平头重卡牵引车 ====================
	var n_1 := K.node(root, Vector3.ZERO, Vector3.ZERO, "HeavyTractorUnit")
	_add_wheel_pair(n_1, -2.92, 1.06, 0.32, M_TRIM, M_TANK_END)
	_add_wheel_pair(n_1, -1.55, 1.06, 0.32, M_TRIM, M_TANK_END)

	# 牵引车大梁、前保险杠（带内凹双大灯）、鞍座第五轮与驾驶室登车踏板
	for sx: float in [-0.44, 0.44]:
		K.bb(n_1, Vector3(0.14, 0.28, 2.70), M_DARK, Vector3(sx, 0.78, -2.35), Vector3.ZERO, 0.008)
		K.bb(n_1, Vector3(0.22, 0.28, 1.15), M_DARK, Vector3(sx, 0.96, -2.86), Vector3.ZERO, 0.008)
	K.bb(n_1, Vector3(2.46, 0.30, 0.28), M_RING, Vector3(0.0, 0.68, -3.60), Vector3.ZERO, 0.012)
	K.bb(n_1, Vector3(2.50, 0.05, 0.30), M_HAZ, Vector3(0.0, 0.55, -3.61), Vector3.ZERO, 0.004)
	for lx: float in [-0.88, 0.88]:
		var hl := K.node(n_1, Vector3(lx, 0.69, -3.73), Vector3.ZERO, "Headlight")
		K.bb(hl, Vector3(0.32, 0.16, 0.05), M_DARK, Vector3.ZERO, Vector3.ZERO, 0.005)
		K.bb(hl, Vector3(0.25, 0.10, 0.03), M_HEADLIGHT, Vector3(0.0, 0.0, -0.02), Vector3.ZERO, 0.004)
	# 左右牵引车副油箱与踏板箱
	for sgn: float in [-1.0, 1.0]:
		K.cy(n_1, 0.24, 0.92, M_TANK_END, Vector3(sgn * 0.90, 0.64, -2.22), Vector3(90.0, 0.0, 0.0), 0.24, 14)
		K.bb(n_1, Vector3(0.16, 0.05, 0.68), M_DARK, Vector3(sgn * 1.14, 0.44, -2.92), Vector3.ZERO, 0.005)
		K.bb(n_1, Vector3(0.16, 0.05, 0.68), M_DARK, Vector3(sgn * 1.14, 0.72, -2.92), Vector3.ZERO, 0.005)
		# 前轮弧形挡泥板
		K.bb(n_1, Vector3(0.38, 0.08, 1.02), M_RING, Vector3(sgn * 1.04, 1.04, -2.92), Vector3.ZERO, 0.01)
		K.bb(n_1, Vector3(0.38, 0.08, 1.02), M_RING, Vector3(sgn * 1.04, 1.04, -1.55), Vector3.ZERO, 0.01)
	K.cy(n_1, 0.48, 0.12, M_TRIM, Vector3(0.0, 0.96, -1.48), Vector3.ZERO, 0.48, 16)

	# 驾驶室主体（前脸进气格栅、内凹前风挡、左右内凹侧车窗与车门、顶置风阻罩与后视镜）
	var n_6 := K.node(n_1, Vector3(0.0, 1.04, -2.86), Vector3.ZERO, "TractorCab")
	K.bb(n_6, Vector3(2.34, 0.12, 1.46), M_DARK, Vector3(0.0, 0.05, 0.0), Vector3.ZERO, 0.008)
	var n_7 := K.node(n_6, Vector3.ZERO, Vector3.ZERO, "CavityCore")
	K.bb(n_7, Vector3(1.88, 1.62, 1.02), K.bore_mat(), Vector3(0.0, 0.92, 0.0), Vector3.ZERO, 0.02)

	# 前脸上下墙板 + 后壁 + 车顶（均使用 M_BODY 主涂装）
	var n_8 := K.node(n_6, Vector3.ZERO, Vector3.ZERO, "StructWall")
	K.bb(n_8, Vector3(2.26, 0.86, 0.18), M_BODY, Vector3(0.0, 0.53, -0.61), Vector3.ZERO, 0.012)
	K.bb(n_8, Vector3(2.26, 0.22, 0.18), M_BODY, Vector3(0.0, 1.67, -0.61), Vector3.ZERO, 0.012)
	K.bb(n_8, Vector3(2.30, 1.68, 0.18), M_BODY, Vector3(0.0, 0.94, 0.62), Vector3.ZERO, 0.012)
	K.bb(n_8, Vector3(2.38, 0.15, 1.50), M_BODY, Vector3(0.0, 1.83, 0.0), Vector3.ZERO, 0.014)
	# 车顶导流板与三联示廓灯
	K.bb(n_8, Vector3(1.86, 0.28, 0.72), M_RING, Vector3(0.0, 2.02, 0.12), Vector3(-14.0, 0.0, 0.0), 0.014)
	for mx: float in [-0.62, 0.0, 0.62]:
		K.bb(n_6, Vector3(0.12, 0.06, 0.08), K.accent(), Vector3(mx, 1.93, -0.68), Vector3.ZERO, 0.004)

	# 四角立柱
	var n_9 := K.node(n_6, Vector3.ZERO, Vector3.ZERO, "StructPier")
	for sx: float in [-1.05, 1.05]:
		K.bb(n_9, Vector3(0.22, 1.68, 0.20), M_BODY, Vector3(sx, 0.94, -0.615), Vector3.ZERO, 0.01)
		K.bb(n_9, Vector3(0.22, 1.68, 0.20), M_BODY, Vector3(sx, 0.94, 0.615), Vector3.ZERO, 0.01)

	# 左右车门下部涂装钢板 + 门缝饰条 + 门把手 + 内凹侧车窗 + 侧视镜支架
	for sgn: float in [-1.0, 1.0]:
		K.bb(n_8, Vector3(0.18, 0.88, 1.08), M_BODY, Vector3(sgn * 1.07, 0.54, 0.0), Vector3.ZERO, 0.01)
		K.bb(n_8, Vector3(0.18, 0.22, 1.08), M_BODY, Vector3(sgn * 1.07, 1.67, 0.0), Vector3.ZERO, 0.01)
		# 车门立柱与防擦护条
		K.bb(n_6, Vector3(0.04, 0.07, 0.98), M_DARK, Vector3(sgn * 1.17, 0.62, 0.0), Vector3.ZERO, 0.004)
		K.bb(n_6, Vector3(0.04, 0.05, 0.16), M_TRIM, Vector3(sgn * 1.18, 0.86, 0.28), Vector3.ZERO, 0.003)
		# 内凹侧车窗（暗钢窗框 + 内凹车窗玻璃）
		var sw := K.node(n_6, Vector3(sgn * 1.14, 1.28, -0.02), Vector3.ZERO, "RecessedWindow")
		K.bb(sw, Vector3(0.06, 0.05, 0.94), M_DARK, Vector3(0.0, 0.29, 0.0), Vector3.ZERO, 0.004)
		K.bb(sw, Vector3(0.06, 0.05, 0.94), M_DARK, Vector3(0.0, -0.29, 0.0), Vector3.ZERO, 0.004)
		K.bb(sw, Vector3(0.06, 0.54, 0.05), M_DARK, Vector3(0.0, 0.0, -0.44), Vector3.ZERO, 0.004)
		K.bb(sw, Vector3(0.06, 0.54, 0.05), M_DARK, Vector3(0.0, 0.0, 0.44), Vector3.ZERO, 0.004)
		K.bb(sw, Vector3(0.025, 0.52, 0.84), M_GLASS, Vector3(-sgn * 0.04, 0.0, 0.0), Vector3.ZERO, 0.003)
		# 外伸重卡后视镜支架与镜壳（外缘 x=±1.27，严守 0.25m 外挑预算）
		K.bb(n_6, Vector3(0.16, 0.025, 0.025), M_DARK, Vector3(sgn * 1.19, 1.48, -0.44), Vector3.ZERO, 0.003)
		K.bb(n_6, Vector3(0.16, 0.025, 0.025), M_DARK, Vector3(sgn * 1.19, 1.06, -0.44), Vector3.ZERO, 0.003)
		K.bb(n_6, Vector3(0.05, 0.42, 0.14), M_DARK, Vector3(sgn * 1.26, 1.27, -0.48), Vector3(0.0, sgn * 12.0, 0.0), 0.006)

	# 前进气百叶格栅
	var n_10 := K.node(n_6, Vector3(0.0, 0.48, -0.71), Vector3.ZERO, "Vent")
	K.bb(n_10, Vector3(1.52, 0.48, 0.036), M_DARK, Vector3(0.0, 0.0, -0.005), Vector3.ZERO, 0.006)
	K.bb(n_10, Vector3(1.40, 0.42, 0.022), K.bore_mat(), Vector3(0.0, 0.0, -0.026), Vector3.ZERO, 0.005)
	for vi in 6:
		var vy := -0.183 + float(vi) * 0.0732
		K.bb(n_10, Vector3(1.34, 0.026, 0.030), M_TRIM, Vector3(0.0, vy, -0.038), Vector3(-28.0, 0.0, 0.0), 0.004)

	# 内凹前风挡 + 中立柱 + 遮阳帽檐
	var n_11 := K.node(n_6, Vector3(0.0, 1.29, -0.70), Vector3.ZERO, "RecessedWindow")
	K.bb(n_11, Vector3(1.86, 0.056, 0.15), M_RING, Vector3(0.0, -0.302, 0.03), Vector3.ZERO, 0.006)
	K.bb(n_11, Vector3(1.86, 0.050, 0.13), M_RING, Vector3(0.0, 0.305, 0.03), Vector3.ZERO, 0.006)
	K.bb(n_11, Vector3(1.86, 0.044, 0.056), M_DARK, Vector3(0.0, 0.258, 0.072), Vector3.ZERO, 0.005)
	K.bb(n_11, Vector3(1.86, 0.044, 0.056), M_DARK, Vector3(0.0, -0.252, 0.072), Vector3.ZERO, 0.005)
	K.bb(n_11, Vector3(0.044, 0.468, 0.056), M_DARK, Vector3(-0.90, 0.003, 0.072), Vector3.ZERO, 0.005)
	K.bb(n_11, Vector3(0.044, 0.468, 0.056), M_DARK, Vector3(0.90, 0.003, 0.072), Vector3.ZERO, 0.005)
	K.bb(n_11, Vector3(1.76, 0.47, 0.022), M_GLASS, Vector3(0.0, 0.003, 0.11), Vector3.ZERO, 0.003)
	var n_12 := K.node(n_11, Vector3(0.0, 0.003, 0.0), Vector3.ZERO, "WindowMuntin")
	K.bb(n_12, Vector3(0.030, 0.475, 0.026), M_TRIM, Vector3(0.0, 0.0, 0.088), Vector3.ZERO, 0.004)
	var n_13 := K.node(n_11, Vector3(0.0, 0.26, 0.0), Vector3.ZERO, "SunHood")
	K.bb(n_13, Vector3(1.86, 0.030, 0.34), M_RING, Vector3(0.0, -0.075, -0.125), Vector3(-28.0, 0.0, 0.0), 0.005)

	# 驾驶室后双立式排气管与隔热护罩
	for sgn: float in [-1.0, 1.0]:
		K.cy(n_1, 0.075, 1.98, M_TANK_END, Vector3(sgn * 1.02, 1.94, -1.98), Vector3.ZERO, 0.075, 12)
		K.cy(n_1, 0.105, 1.05, M_RING, Vector3(sgn * 1.02, 1.88, -1.98), Vector3.ZERO, 0.105, 12)
		K.bb(n_1, Vector3(0.12, 0.07, 0.26), M_DARK, Vector3(sgn * 1.02, 1.44, -2.08), Vector3.ZERO, 0.005)
		K.bb(n_1, Vector3(0.12, 0.07, 0.26), M_DARK, Vector3(sgn * 1.02, 2.34, -2.08), Vector3.ZERO, 0.005)

	# ==================== 后部半挂重型油罐拖车 ====================
	var n_17 := K.node(root, Vector3.ZERO, Vector3.ZERO, "FuelSemiTrailer")
	_add_wheel_pair(n_17, 2.12, 1.08, 0.34, M_TRIM, M_TANK_END)
	_add_wheel_pair(n_17, 3.12, 1.08, 0.34, M_TRIM, M_TANK_END)

	# 拖车前支腿、主副大梁与后保险杠（带尾灯）
	for sx: float in [-0.68, 0.68]:
		K.bb(n_17, Vector3(0.12, 1.12, 0.12), M_DARK, Vector3(sx, 0.57, -0.82), Vector3.ZERO, 0.006)
		K.bb(n_17, Vector3(0.28, 0.05, 0.28), M_DARK, Vector3(sx, 0.025, -0.82), Vector3.ZERO, 0.004)
	K.bb(n_17, Vector3(1.56, 0.24, 5.42), M_DARK, Vector3(0.0, 1.05, 0.96), Vector3.ZERO, 0.01)
	# 后轮通长钢制挡泥瓦 + 双侧防撞护栏
	for sgn: float in [-1.0, 1.0]:
		K.bb(n_17, Vector3(0.42, 0.07, 2.22), M_RING, Vector3(sgn * 1.05, 1.08, 2.62), Vector3.ZERO, 0.01)
		K.bb(n_17, Vector3(0.38, 0.38, 0.05), M_DARK, Vector3(sgn * 1.05, 0.88, 1.50), Vector3.ZERO, 0.005)
		K.bb(n_17, Vector3(0.38, 0.44, 0.05), M_DARK, Vector3(sgn * 1.05, 0.84, 3.72), Vector3.ZERO, 0.005)
		# 侧面双道防钻入护栏
		K.bb(n_17, Vector3(0.05, 0.09, 2.02), M_TANK_END, Vector3(sgn * 1.12, 0.56, 0.34), Vector3.ZERO, 0.004)
		K.bb(n_17, Vector3(0.05, 0.09, 2.02), M_TANK_END, Vector3(sgn * 1.12, 0.82, 0.34), Vector3.ZERO, 0.004)
		for pz: float in [-0.46, 0.34, 1.14]:
			K.bb(n_17, Vector3(0.06, 0.54, 0.06), M_DARK, Vector3(sgn * 1.04, 0.78, pz), Vector3.ZERO, 0.004)
	# 尾部防撞保险杠 + 警示条 + 尾灯
	K.bb(n_17, Vector3(2.38, 0.22, 0.16), M_RING, Vector3(0.0, 0.64, 3.78), Vector3.ZERO, 0.008)
	K.bb(n_17, Vector3(2.34, 0.08, 0.04), M_HAZ, Vector3(0.0, 0.64, 3.87), Vector3.ZERO, 0.003)
	for lx: float in [-0.94, -0.72, 0.72, 0.94]:
		K.bb(n_17, Vector3(0.16, 0.10, 0.04), M_TAILLIGHT, Vector3(lx, 0.82, 3.76), Vector3.ZERO, 0.004)

	# 24 段主卧式油罐本体（与车头共享 M_BODY 主涂装）+ 前后风化钢封头 + 4 道粗壮加劲环与鞍座
	var tank_y := 1.92
	K.cy(n_17, 1.03, 5.36, M_BODY, Vector3(0.0, tank_y, 0.94), Vector3(90.0, 0.0, 0.0), 1.03, 24)
	K.cy(n_17, 0.62, 0.26, M_TANK_END, Vector3(0.0, tank_y, -1.84), Vector3(-90.0, 0.0, 0.0), 1.03, 24)
	K.cy(n_17, 0.62, 0.26, M_TANK_END, Vector3(0.0, tank_y, 3.72), Vector3(90.0, 0.0, 0.0), 1.03, 24)
	for rz: float in [-1.62, -0.72, 0.22, 1.18, 2.12, 3.06, 3.54]:
		var is_end := absf(rz) > 3.2 or rz < -1.4
		var r_out := 1.085 if is_end else 1.11
		var sc_y := 0.55 if is_end else 0.72
		A.add(n_17, A.torus(0.99, r_out, 24), M_RING, Vector3(0.0, tank_y, rz), Vector3(90.0, 0.0, 0.0), Vector3(1.0, sc_y, 1.0), false)
	# 罐底重型钢制鞍座托架（消除圆罐悬空贴在方块上的割裂感）
	for sz_c: float in [-0.72, 0.68, 2.12, 3.12]:
		K.bb(n_17, Vector3(1.74, 0.34, 0.26), M_RING, Vector3(0.0, 1.24, sz_c), Vector3.ZERO, 0.01)

	# 罐体双侧横向黄黑警示腰线 + 标牌底板（FPS 近看层次分明，告别大面积纯色灰管）
	for sgn: float in [-1.0, 1.0]:
		K.bb(n_17, Vector3(0.05, 0.20, 4.96), M_HAZ, Vector3(sgn * 1.045, tank_y - 0.04, 0.94), Vector3.ZERO, 0.004)
		K.bb(n_17, Vector3(0.04, 0.34, 1.42), M_RING, Vector3(sgn * 1.048, tank_y + 0.22, 0.94), Vector3.ZERO, 0.005)
	A.stencil(n_17, "FLAM-18", Vector3(-1.075, tank_y + 0.22, 0.94), Vector3(0.0, -90.0, 0.0), 0.013, Color("#c8c2b2"))
	A.stencil(n_17, "FLAM-18", Vector3(1.075, tank_y + 0.22, 0.94), Vector3(0.0, 90.0, 0.0), 0.013, Color("#c8c2b2"))

	# 罐顶防滑检修走道 + 两侧防溢护栏（保持 y <= 3.16）+ 3 组带螺栓法兰人孔盖
	K.bb(n_17, Vector3(0.78, 0.08, 4.98), M_DARK, Vector3(0.0, 2.95, 0.94), Vector3.ZERO, 0.008)
	for sgn: float in [-1.0, 1.0]:
		K.bb(n_17, Vector3(0.045, 0.16, 4.98), M_RING, Vector3(sgn * 0.40, 3.04, 0.94), Vector3.ZERO, 0.004)
		K.bb(n_17, Vector3(0.035, 0.035, 4.96), M_TANK_END, Vector3(sgn * 0.40, 3.13, 0.94), Vector3.ZERO, 0.003)
		for pz: float in [-1.42, -0.24, 0.94, 2.12, 3.30]:
			K.bb(n_17, Vector3(0.04, 0.18, 0.04), M_RING, Vector3(sgn * 0.40, 3.04, pz), Vector3.ZERO, 0.003)
	for mz: float in [-0.62, 0.94, 2.50]:
		K.cy(n_17, 0.30, 0.08, M_RING, Vector3(0.0, 3.00, mz), Vector3.ZERO, 0.32, 16)
		K.cy(n_17, 0.23, 0.12, K.brass(), Vector3(0.0, 3.07, mz), Vector3.ZERO, 0.23, 14)
		K.bb(n_17, Vector3(0.32, 0.03, 0.06), M_DARK, Vector3(0.0, 3.13, mz), Vector3.ZERO, 0.003)

	# 左侧输油阀门箱 + 三联卸油管汇与黄铜手轮
	K.bb(n_17, Vector3(0.46, 0.46, 1.38), M_VALVE_BOX, Vector3(-0.96, 1.02, 0.65), Vector3.ZERO, 0.01)
	for vz: float in [0.22, 0.65, 1.08]:
		K.cy(n_17, 0.045, 0.24, M_TANK_END, Vector3(-1.14, 0.96, vz), Vector3(0.0, 0.0, 90.0), 0.045, 10)
		K.cy(n_17, 0.075, 0.03, K.brass(), Vector3(-1.24, 0.96, vz), Vector3(0.0, 0.0, 90.0), 0.075, 10)
	A.stencil(n_17, "JP-8", Vector3(-1.202, 1.14, 0.65), Vector3(0.0, -90.0, 0.0), 0.010, Color("#c2bcb0"))

	# 尾部攀爬钢梯（左右立柱 + 7 根防滑踏棍）
	var ladder := K.node(n_17, Vector3(0.0, 0.0, 3.86), Vector3.ZERO, "Ladder")
	for lx: float in [-0.22, 0.22]:
		K.bb(ladder, Vector3(0.04, 2.26, 0.04), M_RING, Vector3(lx, 1.88, 0.0), Vector3.ZERO, 0.004)
	for ri in 7:
		var ry := 0.88 + float(ri) * 0.32
		K.cy(ladder, 0.018, 0.44, M_TANK_END, Vector3(0.0, ry, 0.0), Vector3(0.0, 0.0, 90.0), 0.018, 8)

	return root
