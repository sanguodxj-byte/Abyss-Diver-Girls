extends RefCounted
## 华盛顿/纽约经典石灰岩市政写字大楼（24×14.5×16m · 4层宽厚体量 + 9×6 密集真内凹窗列 + 退台顶层机房）
## 专为高视角城市俯视尺度设计：真实 3.2m 层高、厚重花岗岩基座、浅灰平屋顶机电设备群，彻底消除玩具比例感。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")

static func build(target_sz := Vector3(24.0, 14.5, 16.0)) -> Node3D:
	var root := Node3D.new()
	root.name = "Building_CivicBlock"
	var base_sz := Vector3(24.0, 14.5, 16.0)
	root.scale = Vector3(target_sz.x / base_sz.x, target_sz.y / base_sz.y, target_sz.z / base_sz.z)

	# 主材质：浅暖石灰岩（主墙体，支持 BuildingsExt 局部色偏替换）、花岗岩基座、檐口压顶、浅灰屋面、深蓝灰反光窗玻
	var M_WALL := A.paint(Color("#9e9789"), 0.04, 0.85, {"wear": 0.36, "panel_scale": 0.0})
	var M_PLINTH := A.paint(Color("#7a756c"), 0.05, 0.88, {"wear": 0.42, "panel_scale": 0.0})
	var M_TRIM := A.paint(Color("#9d9688"), 0.04, 0.85, {"wear": 0.32, "panel_scale": 0.0})
	var M_ROOF := A.paint(Color("#807e78"), 0.04, 0.90, {"wear": 0.44, "panel_scale": 0.0})
	var M_ROOF_DARK := A.paint(Color("#555654"), 0.08, 0.84, {"wear": 0.40, "panel_scale": 0.0})
	var M_GLASS := K.canopy(Color("#1f2b33"), 0.05)
	var M_FRAME := K.dark()
	var M_EQUIP := A.paint(Color("#6b7074"), 0.38, 0.58, {"wear": 0.36, "panel_scale": 0.0})
	var M_CAV := K.bore_mat()

	var W := 24.0
	var D := 16.0
	var hw := W * 0.5
	var hd := D * 0.5

	# 1. 基座散水与入口石阶
	var n_found := K.node(root, Vector3.ZERO, Vector3.ZERO, "CivicFoundation")
	K.bb(n_found, Vector3(W + 0.50, 0.26, D + 0.50), M_PLINTH, Vector3(0.0, 0.13, 0.0), Vector3.ZERO, 0.02)
	K.bb(n_found, Vector3(7.6, 0.32, 0.72), M_TRIM, Vector3(0.0, 0.16, hd + 0.36), Vector3.ZERO, 0.015)

	# 2. 内缩暗腔核心（让每一扇窗都呈现真实深度阴影）
	var n_body := K.node(root, Vector3.ZERO, Vector3.ZERO, "CivicBody")
	var n_cav := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "CavityCore")
	K.bb(n_cav, Vector3(W - 0.72, 12.6, D - 0.72), M_CAV, Vector3(0.0, 6.55, 0.0), Vector3.ZERO, 0.02)

	# 玻璃幕芯（内缩 0.28m，位于窗洞后方）
	var n_win := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "RecessedWindow")
	K.bb(n_win, Vector3(W - 0.56, 11.8, D - 0.56), M_GLASS, Vector3(0.0, 6.45, 0.0), Vector3.ZERO, 0.01)

	# 3. 墙体层间水平腰带（StructWall：主立面结构）
	var n_wall := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "StructWall")
	# 底层基座上下压条
	var n_plinth := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "PlinthWall")
	K.bb(n_plinth, Vector3(W + 0.08, 0.78, D + 0.08), M_PLINTH, Vector3(0.0, 0.64, 0.0), Vector3.ZERO, 0.015)
	K.bb(n_plinth, Vector3(W + 0.22, 0.42, D + 0.22), M_TRIM, Vector3(0.0, 3.68, 0.0), Vector3.ZERO, 0.015)

	# 2~4 层窗间水平楼板带（y = 3.9..12.8，每层高 3.0m，窗高 1.85m，窗间墙高 1.15m）
	var floor_ys := [3.95, 6.90, 9.85, 12.68]
	var band_hs := [0.68, 1.08, 1.08, 0.76]
	for fi in floor_ys.size():
		var fy: float = floor_ys[fi]
		var bh: float = band_hs[fi]
		K.bb(n_wall, Vector3(W, bh, 0.34), M_WALL, Vector3(0.0, fy, hd - 0.17), Vector3.ZERO, 0.012)
		K.bb(n_wall, Vector3(W, bh, 0.34), M_WALL, Vector3(0.0, fy, -hd + 0.17), Vector3.ZERO, 0.012)
		K.bb(n_wall, Vector3(0.34, bh, D - 0.60), M_WALL, Vector3(-hw + 0.17, fy, 0.0), Vector3.ZERO, 0.012)
		K.bb(n_wall, Vector3(0.34, bh, D - 0.60), M_WALL, Vector3(hw - 0.17, fy, 0.0), Vector3.ZERO, 0.012)

	# 四角厚实转角石柱（CornerPilaster）
	var n_cor := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "CornerPilaster")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			K.bb(n_cor, Vector3(1.18, 12.85, 1.18), M_WALL, Vector3(sx * (hw - 0.56), 6.68, sz * (hd - 0.56)), Vector3.ZERO, 0.018)

	# 4. 密集规整立面柱墩与窗棂（正面/背面 9 开间，左右侧面 6 开间，一眼建立真实大楼比例）
	var n_pier := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "StructPier")
	var n_muntin := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "WindowMuntin")
	var nx := 9
	var span_x := W - 2.2
	var step_x := span_x / float(nx)
	for i in range(1, nx):
		var px := -span_x * 0.5 + float(i) * step_x
		var pw := 0.88 if (i == 3 or i == 6) else 0.64
		for sz: float in [-1.0, 1.0]:
			# 底层柱墩（正面中三跨做成入口柱廊）
			var is_portico := (sz > 0.0 and i >= 3 and i <= 6)
			if not is_portico:
				K.bb(n_plinth, Vector3(pw + 0.12, 2.95, 0.42), M_PLINTH, Vector3(px, 2.20, sz * (hd - 0.19)), Vector3.ZERO, 0.012)
			# 上三层贯通立面壁柱
			K.bb(n_pier, Vector3(pw, 8.85, 0.36), M_WALL, Vector3(px, 8.32, sz * (hd - 0.16)), Vector3.ZERO, 0.012)
	# 每开间中竖窗棂（极低开销、无投影）
	for i in nx:
		var cx := -span_x * 0.5 + (float(i) + 0.5) * step_x
		for sz: float in [-1.0, 1.0]:
			K.bb(n_muntin, Vector3(0.07, 8.65, 0.08), M_FRAME, Vector3(cx, 8.30, sz * (hd - 0.25)), Vector3.ZERO, 0.004)
			for fy2: float in [5.40, 8.35, 11.30]:
				K.bb(n_muntin, Vector3(step_x - 0.58, 0.09, 0.16), M_TRIM, Vector3(cx, fy2 - 0.94, sz * (hd - 0.14)), Vector3.ZERO, 0.005)

	# 左右侧面 6 开间
	var nz := 6
	var span_z := D - 2.2
	var step_z := span_z / float(nz)
	for j in range(1, nz):
		var pz := -span_z * 0.5 + float(j) * step_z
		var pwz := 0.84 if j == 3 else 0.62
		for sx: float in [-1.0, 1.0]:
			K.bb(n_plinth, Vector3(0.42, 2.95, pwz + 0.12), M_PLINTH, Vector3(sx * (hw - 0.19), 2.20, pz), Vector3.ZERO, 0.012)
			K.bb(n_pier, Vector3(0.36, 8.85, pwz), M_WALL, Vector3(sx * (hw - 0.16), 8.32, pz), Vector3.ZERO, 0.012)
	for j in nz:
		var cz := -span_z * 0.5 + (float(j) + 0.5) * step_z
		for sx: float in [-1.0, 1.0]:
			K.bb(n_muntin, Vector3(0.08, 8.65, 0.07), M_FRAME, Vector3(sx * (hw - 0.25), 8.30, cz), Vector3.ZERO, 0.004)
			for fy3: float in [5.40, 8.35, 11.30]:
				K.bb(n_muntin, Vector3(0.16, 0.09, step_z - 0.56), M_TRIM, Vector3(sx * (hw - 0.14), fy3 - 0.94, cz), Vector3.ZERO, 0.005)

	# 正面宏伟柱廊门厅（4 根花岗岩圆柱 + 门额压梁）
	for ci in 4:
		var col_x := -3.3 + float(ci) * 2.2
		K.cy(n_plinth, 0.26, 3.15, M_TRIM, Vector3(col_x, 1.88, hd + 0.08), Vector3.ZERO, 0.26, 12)
	K.bb(n_plinth, Vector3(7.9, 0.44, 0.78), M_TRIM, Vector3(0.0, 3.66, hd + 0.12), Vector3.ZERO, 0.018)

	# 5. 顶层挑檐、环形女儿墙与浅灰平屋面（高空俯视核心观感）
	var n_roof := K.node(root, Vector3.ZERO, Vector3.ZERO, "CivicRoof")
	K.bb(n_roof, Vector3(W + 0.52, 0.34, D + 0.52), M_TRIM, Vector3(0.0, 13.02, 0.0), Vector3.ZERO, 0.02)
	K.bb(n_roof, Vector3(W - 0.52, 0.20, D - 0.52), M_ROOF, Vector3(0.0, 13.06, 0.0), Vector3.ZERO, 0.015)
	# 四周女儿墙 + 石质压顶
	for sz: float in [-1.0, 1.0]:
		K.bb(n_roof, Vector3(W + 0.06, 0.68, 0.40), M_WALL, Vector3(0.0, 13.48, sz * (hd - 0.18)), Vector3.ZERO, 0.012)
		K.bb(n_roof, Vector3(W + 0.16, 0.12, 0.48), M_TRIM, Vector3(0.0, 13.86, sz * (hd - 0.18)), Vector3.ZERO, 0.01)
	for sx: float in [-1.0, 1.0]:
		K.bb(n_roof, Vector3(0.40, 0.68, D - 0.74), M_WALL, Vector3(sx * (hw - 0.18), 13.48, 0.0), Vector3.ZERO, 0.012)
		K.bb(n_roof, Vector3(0.48, 0.12, D - 0.66), M_TRIM, Vector3(sx * (hw - 0.18), 13.86, 0.0), Vector3.ZERO, 0.01)

	# 退台屋顶设备间 + 中央采光井 + 双联冷却机组
	var n_eq := K.node(n_roof, Vector3.ZERO, Vector3.ZERO, "RoofEquipment")
	K.bb(n_eq, Vector3(13.2, 1.38, 7.2), M_WALL, Vector3(-1.2, 13.82, -0.4), Vector3.ZERO, 0.02)
	K.bb(n_eq, Vector3(13.46, 0.16, 7.46), M_TRIM, Vector3(-1.2, 14.54, -0.4), Vector3.ZERO, 0.015)
	K.bb(n_eq, Vector3(12.2, 0.12, 6.2), M_ROOF_DARK, Vector3(-1.2, 14.62, -0.4), Vector3.ZERO, 0.012)
	# 天窗与两台暖通空调机组
	K.bb(n_eq, Vector3(4.2, 0.34, 2.4), M_FRAME, Vector3(6.8, 13.30, 2.6), Vector3.ZERO, 0.01)
	K.bb(n_eq, Vector3(3.9, 0.38, 2.1), M_GLASS, Vector3(6.8, 13.32, 2.6), Vector3.ZERO, 0.008)
	for hi in 2:
		var hx := 6.6 + float(hi) * 2.4
		K.bb(n_eq, Vector3(1.85, 0.98, 2.35), M_EQUIP, Vector3(hx, 13.62, -2.6), Vector3.ZERO, 0.015)
		K.cy(n_eq, 0.56, 0.18, M_FRAME, Vector3(hx, 14.16, -2.6), Vector3.ZERO, 0.56, 12)
	# 屋面风机排风道
	K.bb(n_eq, Vector3(5.6, 0.42, 0.52), M_EQUIP, Vector3(-8.2, 13.36, 4.4), Vector3.ZERO, 0.01)
	K.bb(n_eq, Vector3(1.6, 0.92, 1.6), M_ROOF_DARK, Vector3(-9.2, 13.60, -4.2), Vector3.ZERO, 0.012)

	return root
