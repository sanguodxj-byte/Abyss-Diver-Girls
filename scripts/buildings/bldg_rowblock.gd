extends RefCounted
## 美式连续联排褐石/红砖街墙组（24×10.5×11.5m · 4 栋 6m 宽联排楼无缝合体，四向全立面开窗与工业细节）
## 正背面 12 开间真内凹钢窗 + 底层商铺遮阳棚与褐石门廊；左右外端山墙设双列三层内凹窗、外凸烟道砖垛、美式钢制消防逃生阳台梯、镀锌落水管与空调外机；屋顶配沥青油毡卷材、楼梯机房与陶土烟囱帽。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")

static func build(target_sz := Vector3(24.0, 10.5, 11.5)) -> Node3D:
	var root := Node3D.new()
	root.name = "Building_Rowblock"
	var base_sz := Vector3(24.0, 10.5, 11.5)
	root.scale = Vector3(target_sz.x / base_sz.x, target_sz.y / base_sz.y, target_sz.z / base_sz.z)

	# 4 户各自独立的真实战后旧化砖石/清水混凝土 PBR 材质（压低红砖饱和度，转向冷灰石材/烟熏褐砖/风化水泥工业色调）
	var unit_mats := [
		A.brick(Color("#4c3a33"), 0.21),
		A.concrete(Color("#555758"), true),
		A.limestone(Color("#6d6a62"), 0.185),
		A.brick(Color("#423935"), 0.21),
	]
	var unit_hs := [9.8, 10.6, 10.0, 10.8]
	var M_PLINTH := A.concrete(Color("#323436"), true)
	var M_TRIM := A.limestone(Color("#77746c"), 0.20)
	var M_ROOF_A := A.tar_roof(Color("#343638"), 0.24)
	var M_ROOF_B := A.tar_roof(Color("#2b2d2f"), 0.28)
	var M_GLASS := A.window_mat(0.18, Vector2(0.92, 1.15), Color("#101820"), Color("#d89848"), 0.44)
	var M_FRAME := K.dark()
	var M_STEEL := K.gunmetal()
	var M_RUST := A.rusted_steel(Color("#3a332d"), 0.46)
	var M_AWNING_A := A.fabric_mat(Color("#2d423c"), 1.35)
	var M_AWNING_B := A.fabric_mat(Color("#54322b"), 1.35)
	var M_WOOD := A.wood_mat(Color("#584636"), 0.38)
	var M_EQUIP := A.paint(Color("#5d6368"), 0.36, 0.58, {"wear": 0.44, "rust": 0.32, "panel_scale": 0.0})
	var M_CAV := K.bore_mat()

	var W := 24.0
	var D := 11.5
	var uw := 6.0
	var hw := W * 0.5
	var hd := D * 0.5

	# 1. 连续花岗岩散水台基与门阶
	var n_found := K.node(root, Vector3.ZERO, Vector3.ZERO, "GroundedApron")
	K.bb(n_found, Vector3(W + 0.52, 0.18, D + 0.52), M_PLINTH, Vector3(0.0, 0.09, 0.0), Vector3.ZERO, 0.018)

	var n_body := K.node(root, Vector3.ZERO, Vector3.ZERO, "RowblockBody")
	var n_cav := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "CavityCore")
	var n_win := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "RecessedWindow")
	var n_wall := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "StructWall")
	var n_pier := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "StructPier")
	var n_muntin := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "WindowMuntin")
	var n_roof := K.node(root, Vector3.ZERO, Vector3.ZERO, "RowblockRoof")
	var n_eq := K.node(n_roof, Vector3.ZERO, Vector3.ZERO, "RoofEquipment")

	# 逐户构建 4 栋联排单元
	for ui in 4:
		var ux := -9.0 + float(ui) * uw
		var uh: float = unit_hs[ui]
		var wm: Material = unit_mats[ui]
		var r_mat: Material = M_ROOF_A if (ui % 2 == 0) else M_ROOF_B

		# 内缩暗腔 + 四向退进反光窗玻芯（外端单元玻璃停在 ±11.76m，相对 ±12.00m 砖墙真退进 24cm，绝不吞没窗台与钢窗棂！）
		var cav_w := uw - 0.56
		K.bb(n_cav, Vector3(cav_w - 0.10, uh - 0.62, D - 0.68), M_CAV, Vector3(ux, (uh - 0.62) * 0.5 + 0.24, 0.0), Vector3.ZERO, 0.015)
		K.bb(n_win, Vector3(cav_w + 0.08, uh - 1.10, D - 0.52), M_GLASS, Vector3(ux, (uh - 1.10) * 0.5 + 0.46, 0.0), Vector3.ZERO, 0.01)

		# 底层厚重勒脚 + 一二层通长石质挑出腰线 + 2~3 层窗间水平墙带
		K.bb(n_wall, Vector3(uw + 0.04, 0.64, D + 0.08), M_PLINTH, Vector3(ux, 0.46, 0.0), Vector3.ZERO, 0.012)
		K.bb(n_wall, Vector3(uw + 0.14, 0.22, D + 0.16), M_TRIM, Vector3(ux, 3.18, 0.0), Vector3.ZERO, 0.012)
		var f_ys := [3.16, 6.08, uh - 0.58]
		var b_hs := [0.68, 1.00, 1.04]
		for fi in f_ys.size():
			for sz: float in [-1.0, 1.0]:
				K.bb(n_wall, Vector3(uw + 0.02, b_hs[fi], 0.34), wm, Vector3(ux, f_ys[fi], sz * (hd - 0.16)), Vector3.ZERO, 0.01)

		# 内部 3 道分户防火墙（高出屋面 0.32m 带石质压顶，仅在户间分割，绝不在左右外端封死盲墙！）
		if ui > 0:
			var fw_x := ux - uw * 0.5
			var fw_h := maxf(uh, float(unit_hs[ui - 1])) + 0.34
			K.bb(n_wall, Vector3(0.30, fw_h, D - 0.08), wm, Vector3(fw_x, fw_h * 0.5, 0.0), Vector3.ZERO, 0.01)
			K.bb(n_roof, Vector3(0.38, 0.10, D + 0.02), M_TRIM, Vector3(fw_x, fw_h + 0.04, 0.0), Vector3.ZERO, 0.008)

		# 正背面每户 3 开间贯通砖壁柱 + 石质窗台/过梁 + 钢制十字窗棂
		var bay_xs := [-2.0, 0.0, 2.0]
		var pier_xs := [-2.76, -1.0, 1.0, 2.76]
		for sz: float in [-1.0, 1.0]:
			for px_off: float in pier_xs:
				var pw := 0.48 if absf(px_off) > 2.0 else 0.54
				K.bb(n_pier, Vector3(pw, uh - 0.56, 0.36), wm, Vector3(ux + px_off, (uh - 0.56) * 0.5 + 0.26, sz * (hd - 0.16)), Vector3.ZERO, 0.01)
			for bx_off: float in bay_xs:
				var wx_c := ux + bx_off
				K.bb(n_muntin, Vector3(0.055, uh - 1.35, 0.06), M_FRAME, Vector3(wx_c, uh * 0.5 + 0.16, sz * (hd - 0.24)), Vector3.ZERO, 0.004)
				for wy: float in [1.82, 4.58, 7.50]:
					if wy == 1.82 and sz > 0.0 and bx_off < -1.5 and (ui % 2 == 1):
						continue
					K.bb(n_muntin, Vector3(1.52, 0.09, 0.18), M_TRIM, Vector3(wx_c, wy - 0.86, sz * (hd - 0.12)), Vector3.ZERO, 0.005)
					K.bb(n_muntin, Vector3(1.56, 0.13, 0.16), M_TRIM, Vector3(wx_c, wy + 0.84, sz * (hd - 0.12)), Vector3.ZERO, 0.005)
					K.bb(n_muntin, Vector3(1.44, 0.045, 0.05), M_FRAME, Vector3(wx_c, wy + 0.08, sz * (hd - 0.23)), Vector3.ZERO, 0.004)

		# 底层街面商铺遮阳棚、褐石门廊与钢制卷帘门箱
		if ui % 2 == 0:
			var aw_m: Material = M_AWNING_A if ui == 0 else M_AWNING_B
			K.bb(n_wall, Vector3(5.3, 0.16, 0.62), aw_m, Vector3(ux, 3.00, hd + 0.28), Vector3(14.0, 0.0, 0.0), 0.01)
			K.bb(n_wall, Vector3(5.3, 0.18, 0.06), aw_m, Vector3(ux, 2.86, hd + 0.58), Vector3.ZERO, 0.006)
			K.bb(n_wall, Vector3(1.62, 2.25, 0.10), M_FRAME, Vector3(ux, 1.72, hd - 0.18), Vector3.ZERO, 0.008)
		else:
			K.bb(n_found, Vector3(1.92, 0.36, 0.68), M_TRIM, Vector3(ux - 2.0, 0.18, hd + 0.32), Vector3.ZERO, 0.012)
			K.bb(n_wall, Vector3(2.12, 0.18, 0.52), M_TRIM, Vector3(ux - 2.0, 2.94, hd + 0.22), Vector3.ZERO, 0.01)
			for dx_p: float in [-0.88, 0.88]:
				K.bb(n_wall, Vector3(0.18, 2.42, 0.24), M_TRIM, Vector3(ux - 2.0 + dx_p, 1.68, hd + 0.04), Vector3.ZERO, 0.008)

		# 屋檐齿饰挑檐、沥青油毡平屋面与前后女儿墙石压顶
		K.bb(n_roof, Vector3(uw + 0.18, 0.26, 0.48), M_TRIM, Vector3(ux, uh - 0.14, hd - 0.02), Vector3.ZERO, 0.012)
		K.bb(n_roof, Vector3(uw + 0.10, 0.22, 0.38), M_TRIM, Vector3(ux, uh - 0.14, -hd + 0.06), Vector3.ZERO, 0.01)
		K.bb(n_roof, Vector3(uw - 0.34, 0.16, D - 0.56), r_mat, Vector3(ux, uh - 0.26, 0.0), Vector3.ZERO, 0.012)
		for sz: float in [-1.0, 1.0]:
			K.bb(n_roof, Vector3(uw + 0.04, 0.58, 0.32), wm, Vector3(ux, uh + 0.22, sz * (hd - 0.15)), Vector3.ZERO, 0.01)
			K.bb(n_roof, Vector3(uw + 0.12, 0.10, 0.40), M_TRIM, Vector3(ux, uh + 0.54, sz * (hd - 0.15)), Vector3.ZERO, 0.008)

		# 屋顶砖烟囱（带石帽与双联陶土烟管）、采光天窗与暖通空调外机
		var ch_p := Vector3(ux + (2.25 if ui % 2 == 0 else -2.25), uh + 0.48, -2.5 + float(ui % 2) * 1.6)
		K.bb(n_eq, Vector3(0.78, 1.32, 0.78), wm, ch_p, Vector3.ZERO, 0.012)
		K.bb(n_eq, Vector3(0.90, 0.11, 0.90), M_TRIM, ch_p + Vector3(0.0, 0.70, 0.0), Vector3.ZERO, 0.008)
		for fp_x: float in [-0.18, 0.18]:
			K.cy(n_eq, 0.11, 0.34, M_RUST, ch_p + Vector3(fp_x, 0.90, 0.0), Vector3.ZERO, 0.11, 10)
		K.bb(n_eq, Vector3(1.68, 0.28, 1.36), M_FRAME, Vector3(ux - 0.35, uh - 0.06, 1.25), Vector3.ZERO, 0.008)
		K.bb(n_eq, Vector3(1.48, 0.32, 1.16), M_GLASS, Vector3(ux - 0.35, uh - 0.04, 1.25), Vector3.ZERO, 0.006)
		if ui == 1:
			# 屋顶楼梯出口砖机房 + 钢门
			K.bb(n_eq, Vector3(2.55, 2.15, 2.85), wm, Vector3(ux + 0.6, uh + 0.85, -1.5), Vector3.ZERO, 0.015)
			K.bb(n_eq, Vector3(2.72, 0.14, 3.02), M_TRIM, Vector3(ux + 0.6, uh + 1.98, -1.5), Vector3.ZERO, 0.01)
			K.bb(n_eq, Vector3(0.86, 1.72, 0.08), M_EQUIP, Vector3(ux + 0.6, uh + 0.70, -0.05), Vector3.ZERO, 0.006)
		else:
			K.bb(n_eq, Vector3(1.24, 0.76, 1.02), M_EQUIP, Vector3(ux + 1.1, uh + 0.16, -2.1), Vector3.ZERO, 0.012)
			K.cy(n_eq, 0.38, 0.12, M_FRAME, Vector3(ux + 1.1, uh + 0.58, -2.1), Vector3.ZERO, 0.38, 12)

	# 2. 左右两侧外山墙全细节重构（彻底终结 11.5m×10.5m 空白砖墙块！）
	for side_i in 2:
		var sx_g := -1.0 if side_i == 0 else 1.0
		var u_idx := 0 if side_i == 0 else 3
		var uh_g: float = unit_hs[u_idx]
		var wm_g: Material = unit_mats[u_idx]
		var gx := sx_g * (hw - 0.17)

		# 山墙水平窗间墙带（首层窗下墙 + 1-2层腰带 + 2-3层腰带 + 顶檐带 + 山墙女儿墙压顶）
		K.bb(n_wall, Vector3(0.34, 0.62, D - 0.12), wm_g, Vector3(gx, 1.02, 0.0), Vector3.ZERO, 0.01)
		for fi_g in 3:
			var fy_g: float = [3.16, 6.08, uh_g - 0.58][fi_g]
			var bh_g: float = [0.72, 1.02, 1.06][fi_g]
			K.bb(n_wall, Vector3(0.34, bh_g, D - 0.12), wm_g, Vector3(gx, fy_g, 0.0), Vector3.ZERO, 0.01)
		K.bb(n_roof, Vector3(0.34, 0.58, D - 0.12), wm_g, Vector3(gx, uh_g + 0.22, 0.0), Vector3.ZERO, 0.01)
		K.bb(n_roof, Vector3(0.44, 0.11, D + 0.06), M_TRIM, Vector3(gx, uh_g + 0.55, 0.0), Vector3.ZERO, 0.008)
		K.bb(n_roof, Vector3(0.46, 0.22, D + 0.08), M_TRIM, Vector3(sx_g * (hw + 0.02), uh_g - 0.14, 0.0), Vector3.ZERO, 0.01)

		# 山墙三道宽幅承重砖垛 + 中央外凸壁炉烟道砖垛（精准四边严密围合南北两列 1.82m 宽立式内凹窗洞，零漏缝！）
		var g_piers := [[-4.96, 1.58], [0.0, 4.68], [4.96, 1.58]]
		for gp: Array in g_piers:
			K.bb(n_pier, Vector3(0.36, uh_g - 0.52, float(gp[1])), wm_g, Vector3(gx, (uh_g - 0.52) * 0.5 + 0.28, float(gp[0])), Vector3.ZERO, 0.012)
		# 外凸烟道砖垛（突出山墙外 0.22m，顶接壁炉双烟囱）
		var chim_h := uh_g + 1.25
		K.bb(n_pier, Vector3(0.26, chim_h, 1.16), wm_g, Vector3(sx_g * (hw + 0.09), chim_h * 0.5, 0.0), Vector3.ZERO, 0.014)
		K.bb(n_roof, Vector3(0.36, 0.12, 1.30), M_TRIM, Vector3(sx_g * (hw + 0.10), chim_h + 0.05, 0.0), Vector3.ZERO, 0.008)
		K.cy(n_eq, 0.11, 0.32, M_RUST, Vector3(sx_g * (hw + 0.09), chim_h + 0.26, -0.26), Vector3.ZERO, 0.11, 10)
		K.cy(n_eq, 0.11, 0.32, M_RUST, Vector3(sx_g * (hw + 0.09), chim_h + 0.26, 0.26), Vector3.ZERO, 0.11, 10)

		# 山墙南北双列 × 3 层真内凹钢窗（窗玻在 ±11.76m，钢窗棂在 ±11.79m，外挑石灰岩窗台/过梁探出至 ±12.06m！）
		for wz_g: float in [-3.24, 3.24]:
			K.bb(n_muntin, Vector3(0.055, uh_g - 1.35, 0.055), M_FRAME, Vector3(sx_g * (hw - 0.21), uh_g * 0.5 + 0.16, wz_g), Vector3.ZERO, 0.004)
			for wy_g: float in [1.96, 4.58, 7.50]:
				K.bb(n_muntin, Vector3(0.22, 0.10, 1.96), M_TRIM, Vector3(sx_g * (hw - 0.05), wy_g - 0.84, wz_g), Vector3.ZERO, 0.005)
				K.bb(n_muntin, Vector3(0.20, 0.14, 2.02), M_TRIM, Vector3(sx_g * (hw - 0.06), wy_g + 0.82, wz_g), Vector3.ZERO, 0.005)
				K.bb(n_muntin, Vector3(0.05, 0.045, 1.80), M_FRAME, Vector3(sx_g * (hw - 0.20), wy_g + 0.08, wz_g), Vector3.ZERO, 0.004)
			# 首层侧窗加装斜钉封窗木板或外挂空调外机，打破绝对对称
			if wz_g < 0.0:
				K.bb(n_muntin, Vector3(0.04, 0.20, 1.84), M_WOOD, Vector3(sx_g * (hw - 0.14), 2.12, wz_g), Vector3(4.5, 0.0, 0.0), 0.004)
				K.bb(n_muntin, Vector3(0.04, 0.20, 1.84), M_WOOD, Vector3(sx_g * (hw - 0.13), 1.72, wz_g), Vector3(-5.0, 0.0, 0.0), 0.004)
			else:
				K.bb(n_muntin, Vector3(0.32, 0.48, 0.68), M_EQUIP, Vector3(sx_g * (hw + 0.15), 3.92, wz_g + 0.35), Vector3.ZERO, 0.01)

		# 镀锌雨水落水管 + 集水漏斗 + 墙面配电箱（两侧山墙标配）
		var dp_z := -hd + 0.92
		K.cy(n_muntin, 0.048, uh_g - 0.25, M_STEEL, Vector3(sx_g * (hw + 0.055), (uh_g - 0.25) * 0.5 + 0.12, dp_z), Vector3.ZERO, 0.048, 10)
		K.bb(n_muntin, Vector3(0.18, 0.24, 0.22), M_STEEL, Vector3(sx_g * (hw + 0.07), uh_g - 0.32, dp_z), Vector3.ZERO, 0.006)
		K.bb(n_muntin, Vector3(0.18, 0.62, 0.46), M_EQUIP, Vector3(sx_g * (hw + 0.08), 1.58, hd - 0.92), Vector3.ZERO, 0.008)

		# 左端山墙（-X）加装经典美式二三层外挂钢结构消防逃生阳台与斜梯（外挑 0.68m <= 0.80m 安全碰撞包络）
		if side_i == 0:
			var n_fe := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "BalconyRailing")
			var fx_out := -hw - 0.34
			for fl_y: float in [3.32, 6.24]:
				# 阳台钢梁平台与三角斜撑支架
				K.bb(n_fe, Vector3(0.68, 0.08, 3.35), M_FRAME, Vector3(fx_out, fl_y, 2.55), Vector3.ZERO, 0.006)
				for bz_s: float in [1.10, 3.95]:
					K.bb(n_fe, Vector3(0.66, 0.06, 0.06), M_FRAME, Vector3(fx_out, fl_y - 0.26, bz_s), Vector3(0.0, 0.0, -24.0), 0.004)
				# 栏杆顶扶手与立柱
				K.bb(n_fe, Vector3(0.045, 0.045, 3.35), M_RUST, Vector3(fx_out - 0.31, fl_y + 0.88, 2.55), Vector3.ZERO, 0.004)
				for rz_s: float in [0.92, 4.18]:
					K.bb(n_fe, Vector3(0.66, 0.045, 0.045), M_RUST, Vector3(fx_out, fl_y + 0.88, rz_s), Vector3.ZERO, 0.004)
				for pi_r in 7:
					var rz_p := 0.95 + float(pi_r) * 0.53
					K.bb(n_fe, Vector3(0.032, 0.88, 0.032), M_FRAME, Vector3(fx_out - 0.31, fl_y + 0.44, rz_p), Vector3.ZERO, 0.003)
			# 二至三层外挂斜钢梯 + 直通屋顶鹅颈爬梯
			K.bb(n_fe, Vector3(0.05, 3.45, 0.12), M_RUST, Vector3(fx_out - 0.16, 4.78, 2.45), Vector3(32.0, 0.0, 0.0), 0.004)
			for lr_x: float in [-0.20, 0.20]:
				K.bb(n_fe, Vector3(0.035, uh_g - 5.6, 0.035), M_FRAME, Vector3(fx_out - 0.22, (uh_g + 6.24) * 0.5 + 0.2, 3.85 + lr_x), Vector3.ZERO, 0.003)
		else:
			# 右端山墙（+X）喷涂褪色工业编号标识 + 双层通风百叶窗
			K.bb(n_muntin, Vector3(0.12, 0.58, 0.92), M_RUST, Vector3(hw + 0.04, 5.95, -2.68), Vector3.ZERO, 0.008)
			A.stencil(n_body, "BLK-04", Vector3(hw + 0.22, 8.65, 0.0), Vector3(0.0, 90.0, 0.0), 0.022, Color("#cfc6b4"))

	return root
