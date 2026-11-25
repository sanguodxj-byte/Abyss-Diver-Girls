extends RefCounted
## 战后粗野主义混凝土高层公寓/综合板楼（22×25.5×12.6m · 8 层标准 3.02m 人类层高 + 内凹阳台廊道 + 贯通楼梯采光井 + 24 台外挂空调机群 + 屋顶水箱）
## 专为消除“低矮干净积木感”设计：冷灰预制混凝土墙板、深凹阳台阴影、高密度 0.84m 人类尺度空调外机、侧翼外挂钢制消防爬梯与战损剥落露筋转角。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")

static func build(target_sz := Vector3(22.0, 25.5, 12.6)) -> Node3D:
	var root := Node3D.new()
	root.name = "Building_BrutalistSlab"
	var base_sz := Vector3(22.0, 25.5, 12.6)
	root.scale = Vector3(target_sz.x / base_sz.x, target_sz.y / base_sz.y, target_sz.z / base_sz.z)

	var M_WALL := A.concrete(Color("#5d5f60"), true)
	var M_CORE := A.brick(Color("#473933"), 0.21)
	var M_BASE := A.concrete(Color("#36383a"), false)
	var M_TRIM := A.concrete(Color("#6d6e6a"), false)
	var M_CHAR := A.paint(Color("#1d1e20"), 0.08, 0.94, {"wear": 0.80, "grime": 0.92, "panel_scale": 0.0})
	var M_ROOF := A.tar_roof(Color("#292b2d"), 0.28)
	var M_GLASS := A.window_mat(0.18, Vector2(1.02, 1.32), Color("#0e161d"), Color("#cf944e"), 0.44)
	var M_FRAME := K.dark()
	var M_STEEL := K.gunmetal()
	var M_RUST := A.rusted_steel(Color("#39322c"), 0.56)
	var M_EQUIP := A.paint(Color("#52585c"), 0.32, 0.64, {"wear": 0.50, "rust": 0.40, "grime": 0.68, "panel_scale": 0.0})
	var M_CAV := K.bore_mat()

	var W := 22.0
	var D := 12.6
	var H := 24.8
	var hw := W * 0.5
	var hd := D * 0.5

	# 1. 基座与底层架空骑楼/车库卷帘门（y = 0..3.45m）
	var n_found := K.node(root, Vector3.ZERO, Vector3.ZERO, "GroundedApron")
	K.bb(n_found, Vector3(W + 0.48, 0.20, D + 0.48), M_BASE, Vector3(0.0, 0.10, 0.0), Vector3.ZERO, 0.015)

	var n_body := K.node(root, Vector3.ZERO, Vector3.ZERO, "SlabBody")
	var n_cav := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "CavityCore")
	var n_win := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "RecessedWindow")
	var n_wall := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "StructWall")
	var n_pier := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "StructPier")
	var n_muntin := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "WindowMuntin")
	var n_rail := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "BalconyRailing")

	# 全楼退进暗腔与反光窗玻芯（预留 0.55m 深内凹阳台阴影视差）
	K.bb(n_cav, Vector3(W - 0.96, H - 0.60, D - 1.16), M_CAV, Vector3(0.0, H * 0.5, 0.0), Vector3.ZERO, 0.015)
	K.bb(n_win, Vector3(W - 0.78, H - 0.90, D - 0.98), M_GLASS, Vector3(0.0, H * 0.5, 0.0), Vector3.ZERO, 0.01)

	# 底层厚混凝土基墙与门厅挑檐
	K.bb(n_wall, Vector3(W + 0.06, 0.58, D + 0.06), M_BASE, Vector3(0.0, 0.44, 0.0), Vector3.ZERO, 0.01)
	K.bb(n_wall, Vector3(W + 0.20, 0.34, D + 0.20), M_TRIM, Vector3(0.0, 3.42, 0.0), Vector3.ZERO, 0.012)
	K.bb(n_muntin, Vector3(4.2, 0.16, 0.76), M_RUST, Vector3(0.0, 2.95, hd + 0.34), Vector3.ZERO, 0.008)
	# 中央外凸暗砖电梯楼梯核（x = -1.95..+1.95m，高出主屋顶 2.6m，打破板楼水平单调感！）
	K.bb(n_wall, Vector3(3.90, H + 2.35, 0.46), M_CORE, Vector3(0.0, (H + 2.35) * 0.5, hd - 0.06), Vector3.ZERO, 0.012)
	K.bb(n_wall, Vector3(3.90, H + 2.35, 0.46), M_CORE, Vector3(0.0, (H + 2.35) * 0.5, -hd + 0.06), Vector3.ZERO, 0.012)
	K.bb(n_win, Vector3(1.45, H - 2.2, 0.52), M_GLASS, Vector3(0.0, H * 0.5 + 1.1, hd - 0.04), Vector3.ZERO, 0.008)

	# 2. 二至八层（共 7 个标准居住层 × 3.02m）：深凹阳台挑板 + 混凝土隔墙翼板 + 1.06m 铁艺栏杆
	for fl in 7:
		var fy := 3.46 + float(fl) * 3.02
		# 楼板前沿（出挑至 ±hd）与窗下实墙带
		for sz_s: float in [-1.0, 1.0]:
			K.bb(n_wall, Vector3(W + 0.06, 0.24, 0.64), M_TRIM, Vector3(0.0, fy, sz_s * (hd - 0.28)), Vector3.ZERO, 0.008)
			# 左右两侧各留一跨深凹开敞阳台，其余跨做预制混凝土窗下实墙，形成丰富虚实咬合！
			for seg_x: Array in [[-8.2, 4.8], [8.2, 4.8]]:
				K.bb(n_wall, Vector3(float(seg_x[1]), 0.96, 0.36), M_WALL, Vector3(float(seg_x[0]), fy + 0.58, sz_s * (hd - 0.18)), Vector3.ZERO, 0.01)
			# 中侧两跨（x = ±4.0m）作为真内凹 0.55m 阳台：装设深铁灰横竖护栏与晾衣/遮阳板
			for bal_x: float in [-4.05, 4.05]:
				K.bb(n_rail, Vector3(3.35, 0.05, 0.05), M_RUST, Vector3(bal_x, fy + 1.08, sz_s * (hd - 0.06)), Vector3.ZERO, 0.004)
				K.bb(n_rail, Vector3(3.35, 0.42, 0.04), M_BASE, Vector3(bal_x, fy + 0.32, sz_s * (hd - 0.06)), Vector3.ZERO, 0.004)
				for bp_i in 5:
					var bpx := bal_x - 1.36 + float(bp_i) * 0.68
					K.bb(n_rail, Vector3(0.035, 1.04, 0.035), M_FRAME, Vector3(bpx, fy + 0.56, sz_s * (hd - 0.06)), Vector3.ZERO, 0.003)
		for sx_s: float in [-1.0, 1.0]:
			K.bb(n_wall, Vector3(0.38, 0.98, D - 0.48), M_WALL, Vector3(sx_s * (hw - 0.18), fy + 0.56, 0.0), Vector3.ZERO, 0.01)

	# 竖向承重剪力墙翼片（正背 7 道 + 左右山墙 4 道，围合双列山墙真内凹窗洞）
	for px_w: float in [-10.65, -5.80, -2.15, 2.15, 5.80, 10.65]:
		for sz_s: float in [-1.0, 1.0]:
			var ph := (H - 3.2) if (px_w < -9.0 and sz_s > 0.0) else H
			K.bb(n_pier, Vector3(0.62, ph, 0.62), M_WALL, Vector3(px_w, ph * 0.5, sz_s * (hd - 0.28)), Vector3.ZERO, 0.01)
	for pz_w: float in [-5.85, -1.95, 1.95, 5.85]:
		for sx_s: float in [-1.0, 1.0]:
			K.bb(n_pier, Vector3(0.56, H, 0.88), M_WALL, Vector3(sx_s * (hw - 0.24), H * 0.5, pz_w), Vector3.ZERO, 0.01)
	# 左上角战损崩裂缺口与外露锈蚀钢筋
	var dmg_p := Vector3(-hw + 1.25, H - 1.35, hd - 1.05)
	K.bb(n_wall, Vector3(2.5, 2.6, 2.0), M_CHAR, dmg_p, Vector3(-5.0, 6.0, -7.0), 0.02)
	for rbi in 3:
		K.bb(n_muntin, Vector3(0.10, 2.3, 0.10), M_RUST, dmg_p + Vector3(-0.6 + float(rbi) * 0.62, 0.25, 0.52), Vector3.ZERO, 0.004)

	# 3. 密集非对称人类尺度分体空调外机群（0.82×0.54×0.34m）与竖向落水管
	for k in 18:
		var fl_k := k % 7
		var col_x: float = [-9.2, -7.1, 7.1, 9.2][k % 4]
		var sz_k := 1.0 if ((k + fl_k) % 2 == 0) else -1.0
		var ay := 4.18 + float(fl_k) * 3.02
		K.bb(n_muntin, Vector3(0.82, 0.54, 0.34), M_EQUIP, Vector3(col_x, ay, sz_k * (hd + 0.12)), Vector3.ZERO, 0.008)
	for dp_x: float in [-6.2, 6.2]:
		K.cy(n_muntin, 0.05, H - 0.4, M_STEEL, Vector3(dp_x, H * 0.5, hd + 0.05), Vector3.ZERO, 0.05, 8)

	# 左端山墙（-X）贯通钢制消防逃生阳台与斜梯（外挑 0.66m <= 0.80m 安全包络）
	var fx_out := -hw - 0.33
	for f_step in range(1, 7, 2):
		var by := 3.48 + float(f_step) * 3.02
		K.bb(n_rail, Vector3(0.66, 0.08, 3.60), M_FRAME, Vector3(fx_out, by, 0.0), Vector3.ZERO, 0.006)
		K.bb(n_rail, Vector3(0.045, 0.045, 3.60), M_RUST, Vector3(fx_out - 0.29, by + 0.96, 0.0), Vector3.ZERO, 0.004)
		K.bb(n_rail, Vector3(0.05, 5.8, 0.14), M_RUST, Vector3(fx_out - 0.14, by + 2.8, 0.2), Vector3(28.0, 0.0, 0.0), 0.004)

	# 4. 屋顶女儿墙、混凝土电梯机房与高架镀锌生活水箱
	var n_roof := K.node(root, Vector3.ZERO, Vector3.ZERO, "SlabRoof")
	K.bb(n_roof, Vector3(W - 0.44, 0.20, D - 0.44), M_ROOF, Vector3(0.0, H - 0.05, 0.0), Vector3.ZERO, 0.012)
	K.bb(n_roof, Vector3(W + 0.22, 0.58, D + 0.22), M_TRIM, Vector3(0.0, H + 0.26, 0.0), Vector3.ZERO, 0.01)
	var n_eq := K.node(n_roof, Vector3.ZERO, Vector3.ZERO, "RoofEquipment")
	K.bb(n_eq, Vector3(4.1, 2.35, 4.6), M_CORE, Vector3(0.0, H + 1.20, 0.0), Vector3.ZERO, 0.014)
	K.bb(n_eq, Vector3(4.35, 0.15, 4.85), M_TRIM, Vector3(0.0, H + 2.42, 0.0), Vector3.ZERO, 0.01)
	# 右侧高架圆形储水塔（+3.2m）
	var wt := Vector3(6.4, H + 0.30, -1.8)
	for lx: float in [-0.75, 0.75]:
		for lz: float in [-0.75, 0.75]:
			K.bb(n_eq, Vector3(0.12, 1.55, 0.12), M_RUST, wt + Vector3(lx, 0.75, lz), Vector3.ZERO, 0.004)
	K.cy(n_eq, 1.18, 2.10, M_EQUIP, wt + Vector3(0.0, 2.45, 0.0), Vector3.ZERO, 1.18, 16)
	K.cy(n_eq, 0.06, 2.80, M_STEEL, Vector3(-6.8, H + 1.65, 1.6), Vector3.ZERO, 0.06, 8)

	return root
