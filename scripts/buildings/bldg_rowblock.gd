extends RefCounted
## 美式连续联排褐石/红砖街墙组（24×10.5×11.5m · 4 栋 6m 宽联排楼无缝合体，零缝隙卡机甲风险）
## 参考纽约布鲁克林/华盛顿国会山连排街墙：4 户错落女儿墙高度 + 4 种差异砖石色 + 12 扇紧凑街面窗 + 平屋顶烟囱天窗。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")

static func build(target_sz := Vector3(24.0, 10.5, 11.5)) -> Node3D:
	var root := Node3D.new()
	root.name = "Building_Rowblock"
	var base_sz := Vector3(24.0, 10.5, 11.5)
	root.scale = Vector3(target_sz.x / base_sz.x, target_sz.y / base_sz.y, target_sz.z / base_sz.z)

	# 4 户各自独立的真实砖石立面材质（暖褐石、风化陶红砖、暖米石灰岩、深烟灰砖）
	var unit_mats := [
		A.paint(Color("#7c5947"), 0.04, 0.88, {"wear": 0.42, "panel_scale": 0.0}),
		A.paint(Color("#884e3d"), 0.04, 0.88, {"wear": 0.44, "panel_scale": 0.0}),
		A.paint(Color("#998e7c"), 0.04, 0.86, {"wear": 0.36, "panel_scale": 0.0}),
		A.paint(Color("#675c54"), 0.04, 0.88, {"wear": 0.42, "panel_scale": 0.0}),
	]
	var unit_hs := [9.4, 10.4, 9.8, 10.6]
	var M_PLINTH := A.paint(Color("#54524d"), 0.06, 0.88, {"wear": 0.42, "panel_scale": 0.0})
	var M_TRIM := A.paint(Color("#aba293"), 0.04, 0.84, {"wear": 0.32, "panel_scale": 0.0})
	var M_ROOF_A := A.paint(Color("#74726d"), 0.04, 0.90, {"wear": 0.46, "panel_scale": 0.0})
	var M_ROOF_B := A.paint(Color("#5d5955"), 0.06, 0.88, {"wear": 0.44, "panel_scale": 0.0})
	var M_GLASS := K.canopy(Color("#1f2a30"), 0.05)
	var M_FRAME := K.dark()
	var M_AWNING := A.paint(Color("#384a45"), 0.06, 0.84, {"wear": 0.40, "panel_scale": 0.0})
	var M_EQUIP := A.paint(Color("#696f73"), 0.34, 0.62, {"wear": 0.38, "panel_scale": 0.0})
	var M_CAV := K.bore_mat()

	var W := 24.0
	var D := 11.5
	var uw := 6.0
	var hd := D * 0.5

	# 1. 连续散水台基
	var n_found := K.node(root, Vector3.ZERO, Vector3.ZERO, "RowblockFoundation")
	K.bb(n_found, Vector3(W + 0.36, 0.20, D + 0.36), M_PLINTH, Vector3(0.0, 0.10, 0.0), Vector3.ZERO, 0.016)

	var n_body := K.node(root, Vector3.ZERO, Vector3.ZERO, "RowblockBody")
	var n_cav := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "CavityCore")
	var n_win := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "RecessedWindow")
	var n_wall := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "MasonryWall")
	var n_muntin := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "WindowMuntin")
	var n_roof := K.node(root, Vector3.ZERO, Vector3.ZERO, "RowblockRoof")
	var n_eq := K.node(n_roof, Vector3.ZERO, Vector3.ZERO, "RoofEquipment")

	# 逐户构建 4 栋无缝紧邻联排楼（各自错落屋檐、门廊、窗台与防火墙）
	for ui in 4:
		var ux := -9.0 + float(ui) * uw
		var uh: float = unit_hs[ui]
		var wm: Material = unit_mats[ui]
		var r_mat: Material = M_ROOF_A if (ui % 2 == 0) else M_ROOF_B

		# 内缩暗腔 + 退进玻璃芯
		K.bb(n_cav, Vector3(uw - 0.52, uh - 0.65, D - 0.64), M_CAV, Vector3(ux, (uh - 0.65) * 0.5 + 0.22, 0.0), Vector3.ZERO, 0.015)
		K.bb(n_win, Vector3(uw - 0.42, uh - 1.15, D - 0.48), M_GLASS, Vector3(ux, (uh - 1.15) * 0.5 + 0.45, 0.0), Vector3.ZERO, 0.01)

		# 底层石基 + 前后水平楼板带（3 层：底层商铺/门廊 3.2m + 2 层住宅各 2.95m）
		K.bb(n_wall, Vector3(uw + 0.02, 0.56, D + 0.04), M_PLINTH, Vector3(ux, 0.42, 0.0), Vector3.ZERO, 0.01)
		var f_ys := [3.15, 6.08, uh - 0.62]
		var b_hs := [0.72, 1.02, 1.08]
		for fi in f_ys.size():
			for sz: float in [-1.0, 1.0]:
				K.bb(n_wall, Vector3(uw + 0.02, b_hs[fi], 0.30), wm, Vector3(ux, f_ys[fi], sz * (hd - 0.15)), Vector3.ZERO, 0.01)

		# 两侧实心砖山墙/分户防火墙（仅外侧端头开两列侧窗，内侧无缝咬合）
		for side_x: float in [-1.0, 1.0]:
			var wx := ux + side_x * (uw * 0.5 - 0.16)
			K.bb(n_wall, Vector3(0.32, uh + 0.22, D - 0.10), wm, Vector3(wx, (uh + 0.22) * 0.5, 0.0), Vector3.ZERO, 0.012)

		# 每户正面 & 背面 3 扇紧凑窗（全楼正面 12 扇/层！）
		var bay_xs := [-2.0, 0.0, 2.0]
		var pier_xs := [-2.78, -1.0, 1.0, 2.78]
		for sz: float in [-1.0, 1.0]:
			for px_off: float in pier_xs:
				var pw := 0.46 if absf(px_off) > 2.0 else 0.52
				K.bb(n_wall, Vector3(pw, uh - 0.60, 0.32), wm, Vector3(ux + px_off, (uh - 0.60) * 0.5 + 0.25, sz * (hd - 0.15)), Vector3.ZERO, 0.01)
			for bx_off: float in bay_xs:
				var wx_c := ux + bx_off
				K.bb(n_muntin, Vector3(0.055, uh - 1.40, 0.06), M_FRAME, Vector3(wx_c, uh * 0.5 + 0.15, sz * (hd - 0.22)), Vector3.ZERO, 0.004)
				for wy: float in [4.58, 7.50]:
					K.bb(n_muntin, Vector3(1.52, 0.09, 0.15), M_TRIM, Vector3(wx_c, wy - 0.86, sz * (hd - 0.12)), Vector3.ZERO, 0.005)
					K.bb(n_muntin, Vector3(1.56, 0.12, 0.14), M_TRIM, Vector3(wx_c, wy + 0.84, sz * (hd - 0.12)), Vector3.ZERO, 0.005)

		# 底层街面差异化：奇数户带褐石入户石阶雨棚，偶数户带底层商铺遮阳棚
		if ui % 2 == 0:
			K.bb(n_wall, Vector3(5.2, 0.14, 0.52), M_AWNING, Vector3(ux, 3.05, hd + 0.24), Vector3(12.0, 0.0, 0.0), 0.008)
		else:
			K.bb(n_found, Vector3(1.85, 0.34, 0.62), M_TRIM, Vector3(ux - 1.9, 0.17, hd + 0.30), Vector3.ZERO, 0.01)
			K.bb(n_wall, Vector3(2.05, 0.16, 0.44), M_TRIM, Vector3(ux - 1.9, 2.92, hd + 0.20), Vector3.ZERO, 0.008)

		# 屋檐线脚、平屋面与分户女儿墙压顶
		K.bb(n_roof, Vector3(uw + 0.16, 0.24, 0.44), M_TRIM, Vector3(ux, uh - 0.14, hd - 0.04), Vector3.ZERO, 0.012)
		K.bb(n_roof, Vector3(uw + 0.08, 0.20, 0.36), M_TRIM, Vector3(ux, uh - 0.14, -hd + 0.06), Vector3.ZERO, 0.01)
		K.bb(n_roof, Vector3(uw - 0.44, 0.16, D - 0.52), r_mat, Vector3(ux, uh - 0.26, 0.0), Vector3.ZERO, 0.012)
		for sz: float in [-1.0, 1.0]:
			K.bb(n_roof, Vector3(uw + 0.04, 0.56, 0.30), wm, Vector3(ux, uh + 0.22, sz * (hd - 0.15)), Vector3.ZERO, 0.01)
			K.bb(n_roof, Vector3(uw + 0.10, 0.09, 0.36), M_TRIM, Vector3(ux, uh + 0.52, sz * (hd - 0.15)), Vector3.ZERO, 0.008)

		# 屋顶砖烟囱、天窗与紧凑空调外机
		K.bb(n_eq, Vector3(0.72, 1.15, 0.72), wm, Vector3(ux + 2.35, uh + 0.32, -2.6 + float(ui % 2) * 1.4), Vector3.ZERO, 0.01)
		K.bb(n_eq, Vector3(1.55, 0.26, 1.25), M_FRAME, Vector3(ux - 0.4, uh - 0.08, 1.1), Vector3.ZERO, 0.008)
		K.bb(n_eq, Vector3(1.36, 0.30, 1.06), M_GLASS, Vector3(ux - 0.4, uh - 0.06, 1.1), Vector3.ZERO, 0.006)
		if ui % 2 == 1:
			K.bb(n_eq, Vector3(1.15, 0.68, 0.95), M_EQUIP, Vector3(ux - 1.4, uh + 0.14, -2.2), Vector3.ZERO, 0.01)

	return root
