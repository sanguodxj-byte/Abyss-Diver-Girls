extends RefCounted
## 曼哈顿战前红砖/砂岩中层商住写字楼（22×18.5×14m · 5层 + 8×5 密集窗列 + 底层商业门廊 + 纽约标志屋顶木水塔）
## 参考纽约曼哈顿下城街块斜俯拍比例：宽厚立面、密集真内凹窗洞、浅灰沥青碎石平屋顶与经典水塔剪影。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")

static func build(target_sz := Vector3(22.0, 18.5, 14.0)) -> Node3D:
	var root := Node3D.new()
	root.name = "Building_MidriseOffice"
	var base_sz := Vector3(22.0, 18.5, 14.0)
	root.scale = Vector3(target_sz.x / base_sz.x, target_sz.y / base_sz.y, target_sz.z / base_sz.z)

	# 暖砂岩/浅砖主墙（主墙支持外部换色：暖砂岩/红砖/灰石）、深铁灰底层商铺、浅石灰岩腰线与窗台、浅灰平屋面
	var M_WALL := A.paint(Color("#8c7c69"), 0.04, 0.86, {"wear": 0.40, "panel_scale": 0.0})
	var M_BASE := A.paint(Color("#47494b"), 0.08, 0.84, {"wear": 0.42, "panel_scale": 0.0})
	var M_STONE := A.paint(Color("#7f776a"), 0.04, 0.88, {"wear": 0.36, "panel_scale": 0.0})
	var M_ROOF := A.paint(Color("#777570"), 0.04, 0.90, {"wear": 0.46, "panel_scale": 0.0})
	var M_WOOD := A.paint(Color("#6b523b"), 0.04, 0.90, {"wear": 0.48, "panel_scale": 0.0})
	var M_GLASS := K.canopy(Color("#1c262e"), 0.05)
	var M_FRAME := K.dark()
	var M_STEEL := K.gunmetal()
	var M_EQUIP := A.paint(Color("#666c70"), 0.36, 0.60, {"wear": 0.38, "panel_scale": 0.0})
	var M_CAV := K.bore_mat()

	var W := 22.0
	var D := 14.0
	var hw := W * 0.5
	var hd := D * 0.5

	# 1. 基座散水
	var n_found := K.node(root, Vector3.ZERO, Vector3.ZERO, "OfficeFoundation")
	K.bb(n_found, Vector3(W + 0.44, 0.22, D + 0.44), M_BASE, Vector3(0.0, 0.11, 0.0), Vector3.ZERO, 0.018)

	# 2. 内缩暗腔 + 退进反光窗玻芯
	var n_body := K.node(root, Vector3.ZERO, Vector3.ZERO, "OfficeBody")
	var n_cav := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "CavityCore")
	K.bb(n_cav, Vector3(W - 0.68, 16.0, D - 0.68), M_CAV, Vector3(0.0, 8.20, 0.0), Vector3.ZERO, 0.02)
	var n_win := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "RecessedWindow")
	K.bb(n_win, Vector3(W - 0.50, 15.2, D - 0.50), M_GLASS, Vector3(0.0, 8.10, 0.0), Vector3.ZERO, 0.01)

	# 3. 底层商业裙房门脸（y = 0..3.65m）与二层石质腰线
	var n_plinth := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "PlinthWall")
	K.bb(n_plinth, Vector3(W + 0.08, 0.52, D + 0.08), M_BASE, Vector3(0.0, 0.44, 0.0), Vector3.ZERO, 0.012)
	K.bb(n_plinth, Vector3(W + 0.24, 0.38, D + 0.24), M_STONE, Vector3(0.0, 3.68, 0.0), Vector3.ZERO, 0.015)
	# 正面商铺遮阳雨棚挑檐
	K.bb(n_plinth, Vector3(W - 1.4, 0.14, 0.58), M_FRAME, Vector3(0.0, 3.22, hd + 0.26), Vector3.ZERO, 0.008)

	# 4. 上四层主墙体水平腰带（每层 3.1m，共 4 层：y = 3.9..16.3m）
	var n_wall := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "StructWall")
	var floor_ys := [4.02, 7.05, 10.08, 13.11, 16.05]
	var band_hs := [0.64, 1.05, 1.05, 1.05, 0.86]
	for fi in floor_ys.size():
		var fy: float = floor_ys[fi]
		var bh: float = band_hs[fi]
		K.bb(n_wall, Vector3(W, bh, 0.34), M_WALL, Vector3(0.0, fy, hd - 0.17), Vector3.ZERO, 0.012)
		K.bb(n_wall, Vector3(W, bh, 0.34), M_WALL, Vector3(0.0, fy, -hd + 0.17), Vector3.ZERO, 0.012)
		K.bb(n_wall, Vector3(0.34, bh, D - 0.60), M_WALL, Vector3(-hw + 0.17, fy, 0.0), Vector3.ZERO, 0.012)
		K.bb(n_wall, Vector3(0.34, bh, D - 0.60), M_WALL, Vector3(hw - 0.17, fy, 0.0), Vector3.ZERO, 0.012)
	# 顶层装饰线脚
	K.bb(n_wall, Vector3(W + 0.18, 0.22, D + 0.18), M_STONE, Vector3(0.0, 13.38, 0.0), Vector3.ZERO, 0.01)

	# 四角实心砖石转角柱
	var n_cor := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "CornerPilaster")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			K.bb(n_cor, Vector3(1.06, 16.25, 1.06), M_WALL, Vector3(sx * (hw - 0.50), 8.34, sz * (hd - 0.50)), Vector3.ZERO, 0.015)

	# 5. 正背面 8 开间 × 左右侧 5 开间 紧密立面壁柱与石窗台
	var n_pier := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "StructPier")
	var n_muntin := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "WindowMuntin")
	var nx := 8
	var span_x := W - 2.0
	var step_x := span_x / float(nx)
	for i in range(1, nx):
		var px := -span_x * 0.5 + float(i) * step_x
		var pw := 0.78 if (i == 4) else 0.58
		for sz: float in [-1.0, 1.0]:
			K.bb(n_plinth, Vector3(pw + 0.08, 3.05, 0.38), M_BASE, Vector3(px, 2.02, sz * (hd - 0.18)), Vector3.ZERO, 0.01)
			K.bb(n_pier, Vector3(pw, 12.25, 0.34), M_WALL, Vector3(px, 10.05, sz * (hd - 0.16)), Vector3.ZERO, 0.01)
	for i in nx:
		var cx := -span_x * 0.5 + (float(i) + 0.5) * step_x
		for sz: float in [-1.0, 1.0]:
			K.bb(n_muntin, Vector3(0.06, 11.95, 0.07), M_FRAME, Vector3(cx, 10.05, sz * (hd - 0.24)), Vector3.ZERO, 0.004)
			for fy2: float in [5.52, 8.55, 11.58, 14.61]:
				K.bb(n_muntin, Vector3(step_x - 0.52, 0.10, 0.16), M_STONE, Vector3(cx, fy2 - 0.94, sz * (hd - 0.13)), Vector3.ZERO, 0.005)

	var nz := 5
	var span_z := D - 2.0
	var step_z := span_z / float(nz)
	for j in range(1, nz):
		var pz := -span_z * 0.5 + float(j) * step_z
		for sx: float in [-1.0, 1.0]:
			K.bb(n_plinth, Vector3(0.38, 3.05, 0.64), M_BASE, Vector3(sx * (hw - 0.18), 2.02, pz), Vector3.ZERO, 0.01)
			K.bb(n_pier, Vector3(0.34, 12.25, 0.58), M_WALL, Vector3(sx * (hw - 0.16), 10.05, pz), Vector3.ZERO, 0.01)
	for j in nz:
		var cz := -span_z * 0.5 + (float(j) + 0.5) * step_z
		for sx: float in [-1.0, 1.0]:
			K.bb(n_muntin, Vector3(0.07, 11.95, 0.06), M_FRAME, Vector3(sx * (hw - 0.24), 10.05, cz), Vector3.ZERO, 0.004)
			for fy3: float in [5.52, 8.55, 11.58, 14.61]:
				K.bb(n_muntin, Vector3(0.16, 0.10, step_z - 0.52), M_STONE, Vector3(sx * (hw - 0.13), fy3 - 0.94, cz), Vector3.ZERO, 0.005)

	# 6. 顶檐女儿墙与经典曼哈顿平屋顶（浅灰碎石屋面 + 电梯机房 + 标志性木质水塔）
	var n_roof := K.node(root, Vector3.ZERO, Vector3.ZERO, "OfficeRoof")
	K.bb(n_roof, Vector3(W + 0.44, 0.30, D + 0.44), M_STONE, Vector3(0.0, 16.52, 0.0), Vector3.ZERO, 0.018)
	K.bb(n_roof, Vector3(W - 0.48, 0.18, D - 0.48), M_ROOF, Vector3(0.0, 16.56, 0.0), Vector3.ZERO, 0.015)
	for sz: float in [-1.0, 1.0]:
		K.bb(n_roof, Vector3(W + 0.04, 0.82, 0.36), M_WALL, Vector3(0.0, 17.04, sz * (hd - 0.16)), Vector3.ZERO, 0.012)
		K.bb(n_roof, Vector3(W + 0.14, 0.12, 0.44), M_STONE, Vector3(0.0, 17.48, sz * (hd - 0.16)), Vector3.ZERO, 0.01)
	for sx: float in [-1.0, 1.0]:
		K.bb(n_roof, Vector3(0.36, 0.82, D - 0.68), M_WALL, Vector3(sx * (hw - 0.16), 17.04, 0.0), Vector3.ZERO, 0.012)
		K.bb(n_roof, Vector3(0.44, 0.12, D - 0.60), M_STONE, Vector3(sx * (hw - 0.16), 17.48, 0.0), Vector3.ZERO, 0.01)

	# 屋顶设备间 + 纽约木水塔 + 采光天窗 + HVAC 机组
	var n_eq := K.node(n_roof, Vector3.ZERO, Vector3.ZERO, "RoofEquipment")
	# 砖石电梯机房
	K.bb(n_eq, Vector3(4.6, 2.25, 3.8), M_WALL, Vector3(-5.8, 17.72, -1.8), Vector3.ZERO, 0.018)
	K.bb(n_eq, Vector3(4.84, 0.16, 4.04), M_STONE, Vector3(-5.8, 18.88, -1.8), Vector3.ZERO, 0.012)
	# 纽约经典屋顶木水塔（四钢柱支架 + 木桶 + 镀锌铁锥顶）
	var wt_p := Vector3(5.8, 16.65, -2.2)
	for lx: float in [-0.88, 0.88]:
		for lz: float in [-0.88, 0.88]:
			K.bb(n_eq, Vector3(0.14, 1.85, 0.14), M_STEEL, wt_p + Vector3(lx, 0.92, lz), Vector3.ZERO, 0.008)
	K.bb(n_eq, Vector3(2.35, 0.14, 2.35), M_STEEL, wt_p + Vector3(0.0, 1.86, 0.0), Vector3.ZERO, 0.01)
	K.cy(n_eq, 1.15, 2.25, M_WOOD, wt_p + Vector3(0.0, 3.04, 0.0), Vector3.ZERO, 1.15, 16)
	K.cy(n_eq, 0.08, 0.88, M_EQUIP, wt_p + Vector3(0.0, 4.58, 0.0), Vector3.ZERO, 1.30, 16)
	# 中央采光天窗 + 空调机组
	K.bb(n_eq, Vector3(4.4, 0.36, 2.5), M_FRAME, Vector3(0.2, 16.82, 1.8), Vector3.ZERO, 0.01)
	K.bb(n_eq, Vector3(4.1, 0.40, 2.2), M_GLASS, Vector3(0.2, 16.84, 1.8), Vector3.ZERO, 0.008)
	K.bb(n_eq, Vector3(2.1, 0.96, 1.8), M_EQUIP, Vector3(-0.6, 17.12, -3.4), Vector3.ZERO, 0.015)
	K.bb(n_eq, Vector3(2.1, 0.96, 1.8), M_EQUIP, Vector3(1.8, 17.12, -3.4), Vector3.ZERO, 0.015)
	K.bb(n_eq, Vector3(1.1, 1.55, 1.1), M_WALL, Vector3(-8.8, 17.40, 4.2), Vector3.ZERO, 0.012)

	return root
