extends RefCounted
## 战后写实高层商办退台大厦（23×33.5×14.8m · 双层商业裙房 + 10 层写字楼塔身 + 设备转换层 + 战损缺角钢筋 + 屋顶冷却塔与通讯桁架）
## 对标《War Robots Remastered》（深圳/死城）与《MW5》：真实 3.12m 人类标准层高、裙房+偏心高塔非对称体块（彻底告别单一方盒）、细密内凹玻璃幕墙分格与 1.1m 人类尺度护栏空调机群。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")

static func build(target_sz := Vector3(23.0, 33.5, 14.8)) -> Node3D:
	var root := Node3D.new()
	root.name = "Building_HighriseOffice"
	var base_sz := Vector3(23.0, 33.5, 14.8)
	root.scale = Vector3(target_sz.x / base_sz.x, target_sz.y / base_sz.y, target_sz.z / base_sz.z)

	# 写实低饱和冷灰石材/清水混凝土色板（杜绝鲜艳玩具色）
	var M_WALL := A.limestone(Color("#6b6a66"), 0.19)
	var M_PODIUM := A.concrete(Color("#3d4043"), true)
	var M_TRIM := A.concrete(Color("#585956"), false)
	var M_DARK_CONC := A.concrete(Color("#2a2c2e"), false)
	var M_CHAR := A.paint(Color("#1e1f20"), 0.08, 0.94, {"wear": 0.78, "grime": 0.92, "panel_scale": 0.0})
	var M_ROOF := A.tar_roof(Color("#2a2c2e"), 0.28)
	var M_GLASS := A.window_mat(0.16, Vector2(1.18, 1.48), Color("#0d151c"), Color("#c89252"), 0.42)
	var M_FRAME := K.dark()
	var M_STEEL := K.gunmetal()
	var M_RUST := A.rusted_steel(Color("#38322d"), 0.54)
	var M_EQUIP := A.paint(Color("#4c5256"), 0.34, 0.62, {"wear": 0.48, "rust": 0.38, "grime": 0.65, "panel_scale": 0.0})
	var M_SIGN := A.paint(Color("#293842"), 0.26, 0.58, {"wear": 0.56, "rust": 0.34, "grime": 0.68, "panel_scale": 0.0})
	var M_CAV := K.bore_mat()

	var W := 23.0
	var D := 14.8
	var hw := W * 0.5
	var hd := D * 0.5

	# 1. 散水台基与双层全宽商业裙房（y = 0..6.65m，含 2.35m 人类尺度商铺卷闸门与挑出雨棚）
	var n_found := K.node(root, Vector3.ZERO, Vector3.ZERO, "GroundedApron")
	K.bb(n_found, Vector3(W + 0.56, 0.22, D + 0.56), M_DARK_CONC, Vector3(0.0, 0.11, 0.0), Vector3.ZERO, 0.015)

	var n_body := K.node(root, Vector3.ZERO, Vector3.ZERO, "HighriseBody")
	var n_cav := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "CavityCore")
	var n_win := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "RecessedWindow")
	var n_wall := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "StructWall")
	var n_pier := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "StructPier")
	var n_muntin := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "WindowMuntin")

	# 裙房暗腔与底层橱窗玻璃
	K.bb(n_cav, Vector3(W - 0.72, 6.10, D - 0.72), M_CAV, Vector3(0.0, 3.25, 0.0), Vector3.ZERO, 0.015)
	K.bb(n_win, Vector3(W - 0.54, 5.80, D - 0.54), M_GLASS, Vector3(0.0, 3.25, 0.0), Vector3.ZERO, 0.01)
	K.bb(n_wall, Vector3(W + 0.08, 0.56, D + 0.08), M_DARK_CONC, Vector3(0.0, 0.46, 0.0), Vector3.ZERO, 0.01)
	K.bb(n_wall, Vector3(W + 0.12, 0.72, D + 0.12), M_PODIUM, Vector3(0.0, 3.52, 0.0), Vector3.ZERO, 0.012)
	K.bb(n_wall, Vector3(W + 0.26, 0.42, D + 0.26), M_TRIM, Vector3(0.0, 6.56, 0.0), Vector3.ZERO, 0.014)

	# 裙房立柱列（间距 3.6m）与正面悬挑钢雨棚 + 人类尺度 2.3m 入户旋转门厅与卷帘门
	for i in 7:
		var px := -10.8 + float(i) * 3.6
		for sz_s: float in [-1.0, 1.0]:
			K.bb(n_pier, Vector3(0.68, 6.20, 0.42), M_PODIUM, Vector3(px, 3.30, sz_s * (hd - 0.18)), Vector3.ZERO, 0.01)
	for j in 5:
		var pz := -6.8 + float(j) * 3.4
		for sx_s: float in [-1.0, 1.0]:
			K.bb(n_pier, Vector3(0.42, 6.20, 0.66), M_PODIUM, Vector3(sx_s * (hw - 0.18), 3.30, pz), Vector3.ZERO, 0.01)
	K.bb(n_muntin, Vector3(W - 1.2, 0.14, 0.68), M_FRAME, Vector3(0.0, 3.16, hd + 0.30), Vector3.ZERO, 0.008)
	K.bb(n_wall, Vector3(3.10, 2.55, 0.36), M_FRAME, Vector3(-3.6, 1.48, hd - 0.06), Vector3.ZERO, 0.008)
	K.bb(n_muntin, Vector3(2.85, 0.42, 0.12), M_SIGN, Vector3(3.6, 3.55, hd + 0.10), Vector3.ZERO, 0.006)
	# 街角竖向金属店招灯箱框架（强力人类城市尺度锚点）
	K.bb(n_muntin, Vector3(0.22, 5.40, 0.72), M_SIGN, Vector3(-hw - 0.14, 6.40, hd - 1.25), Vector3.ZERO, 0.008)
	K.bb(n_muntin, Vector3(0.26, 0.10, 0.78), M_RUST, Vector3(-hw - 0.14, 9.15, hd - 1.25), Vector3.ZERO, 0.005)

	# 右翼二层退台露台屋面（x = +7.6..+11.4m）：配 1.1m 标准行人护栏与裙房冷却机组
	var pod_rx := 9.35
	K.bb(n_wall, Vector3(4.10, 0.18, D - 0.40), M_ROOF, Vector3(pod_rx, 6.82, 0.0), Vector3.ZERO, 0.01)
	var n_rail := K.node(n_body, Vector3.ZERO, Vector3.ZERO, "BalconyRailing")
	K.bb(n_rail, Vector3(4.10, 0.05, 0.05), M_RUST, Vector3(pod_rx, 7.88, hd - 0.22), Vector3.ZERO, 0.004)
	K.bb(n_rail, Vector3(4.10, 0.05, 0.05), M_RUST, Vector3(pod_rx, 7.88, -hd + 0.22), Vector3.ZERO, 0.004)
	K.bb(n_rail, Vector3(0.05, 0.05, D - 0.44), M_RUST, Vector3(hw - 0.22, 7.88, 0.0), Vector3.ZERO, 0.004)
	for ri_p in 6:
		var rzp := -hd + 0.8 + float(ri_p) * 2.55
		K.bb(n_rail, Vector3(0.04, 1.08, 0.04), M_FRAME, Vector3(hw - 0.22, 7.35, rzp), Vector3.ZERO, 0.003)
	for hvi in 2:
		var hv_z := -2.6 + float(hvi) * 5.2
		K.bb(n_muntin, Vector3(1.65, 1.18, 1.42), M_EQUIP, Vector3(pod_rx, 7.48, hv_z), Vector3.ZERO, 0.01)
		K.cy(n_muntin, 0.48, 0.14, M_FRAME, Vector3(pod_rx, 8.12, hv_z), Vector3.ZERO, 0.48, 12)

	# 2. 偏心主塔楼（x = -11.4..+7.3m，宽 18.7m × 深 13.4m，y = 6.7..31.8m · 共 8 个标准办公层，每层 3.12m！）
	var tx := -2.05
	var tw := 18.7
	var td := 13.4
	var thw := tw * 0.5
	var thd := td * 0.5
	var t_top := 31.75
	K.bb(n_cav, Vector3(tw - 0.68, t_top - 7.1, td - 0.68), M_CAV, Vector3(tx, (t_top + 6.7) * 0.5, 0.0), Vector3.ZERO, 0.015)
	K.bb(n_win, Vector3(tw - 0.52, t_top - 7.3, td - 0.52), M_GLASS, Vector3(tx, (t_top + 6.7) * 0.5, 0.0), Vector3.ZERO, 0.01)

	# 8 层水平窗下梁带（第 5 层 y=19.2m 设为深色百叶设备转换层，瞬间赋予真实摩天楼工程节奏）
	for fl in 9:
		var fy := 6.82 + float(fl) * 3.10
		var is_mech := (fl == 4)
		var bh := 1.18 if is_mech else 0.88
		var bm: Material = M_DARK_CONC if is_mech else M_WALL
		for sz_t: float in [-1.0, 1.0]:
			K.bb(n_wall, Vector3(tw + 0.04, bh, 0.34), bm, Vector3(tx, fy, sz_t * (thd - 0.16)), Vector3.ZERO, 0.01)
		for sx_t: float in [-1.0, 1.0]:
			K.bb(n_wall, Vector3(0.34, bh, td - 0.56), bm, Vector3(tx + sx_t * (thw - 0.16), fy, 0.0), Vector3.ZERO, 0.01)
		if fl == 4 or fl == 8:
			K.bb(n_wall, Vector3(tw + 0.22, 0.20, td + 0.22), M_TRIM, Vector3(tx, fy + 0.48, 0.0), Vector3.ZERO, 0.01)

	# 主塔四角厚重巨柱 + 正背 7 开间 / 侧面 5 开间 竖向石材肋柱与钢制窗框竖梃
	for sx_c: float in [-1.0, 1.0]:
		for sz_c: float in [-1.0, 1.0]:
			# 右上角制作战损炮击缺角与裸露工字钢梁（打破完美长方体轮廓！）
			var c_h := (t_top - 9.8) if (sx_c > 0.0 and sz_c > 0.0) else (t_top - 6.7)
			K.bb(n_pier, Vector3(1.08, c_h, 1.08), M_WALL, Vector3(tx + sx_c * (thw - 0.50), 6.7 + c_h * 0.5, sz_c * (thd - 0.50)), Vector3.ZERO, 0.012)
	# 战损缺角焦黑断面与裸露钢骨
	var scar_p := Vector3(tx + thw - 1.35, t_top - 1.55, thd - 1.15)
	K.bb(n_wall, Vector3(2.8, 2.9, 2.2), M_CHAR, scar_p, Vector3(4.0, -8.0, 6.0), 0.02)
	for rb_i in 3:
		K.bb(n_muntin, Vector3(0.12, 2.6, 0.12), M_RUST, scar_p + Vector3(-0.7 + float(rb_i) * 0.72, 0.35, 0.55), Vector3(0.0, 0.0, -4.0 + float(rb_i) * 5.0), 0.004)
		K.bb(n_muntin, Vector3(2.4, 0.12, 0.12), M_RUST, scar_p + Vector3(0.1, -0.6 + float(rb_i) * 0.85, 0.58), Vector3.ZERO, 0.004)

	var nx_t := 7
	var step_xt := (tw - 2.0) / float(nx_t)
	for i in range(1, nx_t):
		var px_t := tx - (tw - 2.0) * 0.5 + float(i) * step_xt
		var pw_t := 0.72 if (i == 3 or i == 4) else 0.48
		for sz_t: float in [-1.0, 1.0]:
			var ph_t := (t_top - 9.6) if (sz_t > 0.0 and i == nx_t - 1) else (t_top - 6.8)
			K.bb(n_pier, Vector3(pw_t, ph_t, 0.36), M_WALL, Vector3(px_t, 6.8 + ph_t * 0.5, sz_t * (thd - 0.16)), Vector3.ZERO, 0.01)
	for i in nx_t:
		var wx_t := tx - (tw - 2.0) * 0.5 + (float(i) + 0.5) * step_xt
		for sz_t: float in [-1.0, 1.0]:
			K.bb(n_muntin, Vector3(0.055, t_top - 7.6, 0.06), M_FRAME, Vector3(wx_t, (t_top + 6.8) * 0.5, sz_t * (thd - 0.23)), Vector3.ZERO, 0.004)

	var nz_t := 5
	var step_zt := (td - 2.0) / float(nz_t)
	for j in range(1, nz_t):
		var pz_t := -(td - 2.0) * 0.5 + float(j) * step_zt
		for sx_t: float in [-1.0, 1.0]:
			var ph_z := (t_top - 9.6) if (sx_t > 0.0 and j == nz_t - 1) else (t_top - 6.8)
			K.bb(n_pier, Vector3(0.36, ph_z, 0.50), M_WALL, Vector3(tx + sx_t * (thw - 0.16), 6.8 + ph_z * 0.5, pz_t), Vector3.ZERO, 0.01)
	for j in nz_t:
		var wz_t := -(td - 2.0) * 0.5 + (float(j) + 0.5) * step_zt
		for sx_t: float in [-1.0, 1.0]:
			K.bb(n_muntin, Vector3(0.06, t_top - 7.6, 0.055), M_FRAME, Vector3(tx + sx_t * (thw - 0.23), (t_top + 6.8) * 0.5, wz_t), Vector3.ZERO, 0.004)

	# 外墙零星加挂 0.85m 分体空调外机与竖向通风百叶井（强化人类楼层精细密度）
	for ac_i in 9:
		var fl_ac := 1 + (ac_i * 3) % 7
		var bx_ac := tx - 6.8 + float((ac_i * 2) % 6) * 2.45
		var sz_ac := 1.0 if (ac_i % 2 == 0) else -1.0
		K.bb(n_muntin, Vector3(0.84, 0.56, 0.34), M_EQUIP, Vector3(bx_ac, 7.35 + float(fl_ac) * 3.10, sz_ac * (thd + 0.14)), Vector3.ZERO, 0.008)

	# 3. 顶层女儿墙、电梯机房、双联冷却机组与高耸屋顶通讯钢塔（总视觉天际线冲上 ~38m！）
	var n_roof := K.node(root, Vector3.ZERO, Vector3.ZERO, "HighriseRoof")
	K.bb(n_roof, Vector3(tw - 0.44, 0.22, td - 0.44), M_ROOF, Vector3(tx, t_top - 0.06, 0.0), Vector3.ZERO, 0.012)
	K.bb(n_roof, Vector3(tw + 0.28, 0.26, td + 0.28), M_TRIM, Vector3(tx, t_top + 0.56, 0.0), Vector3.ZERO, 0.01)
	var n_eq := K.node(n_roof, Vector3.ZERO, Vector3.ZERO, "RoofEquipment")
	K.bb(n_eq, Vector3(5.6, 2.85, 4.4), M_PODIUM, Vector3(tx - 3.8, t_top + 1.45, -1.6), Vector3.ZERO, 0.015)
	K.bb(n_eq, Vector3(5.85, 0.16, 4.65), M_TRIM, Vector3(tx - 3.8, t_top + 2.92, -1.6), Vector3.ZERO, 0.01)
	for cti in 2:
		var ctp := Vector3(tx + 3.2, t_top + 0.95, -2.4 + float(cti) * 3.4)
		K.bb(n_eq, Vector3(2.35, 1.65, 2.35), M_EQUIP, ctp, Vector3.ZERO, 0.012)
		K.cy(n_eq, 0.86, 0.24, M_FRAME, ctp + Vector3(0.0, 0.92, 0.0), Vector3.ZERO, 0.86, 14)
	# 6.2m 屋顶钢桁架微波通讯天线桅杆
	var mast_p := Vector3(tx - 4.2, t_top + 2.95, -1.8)
	K.cy(n_eq, 0.14, 5.8, M_STEEL, mast_p + Vector3(0.0, 2.9, 0.0), Vector3.ZERO, 0.14, 10)
	K.cy(n_eq, 0.06, 3.2, M_RUST, mast_p + Vector3(0.0, 6.8, 0.0), Vector3.ZERO, 0.06, 8)
	K.cy(n_eq, 0.58, 0.18, M_EQUIP, mast_p + Vector3(0.32, 3.6, 0.0), Vector3(0.0, 0.0, 88.0), 0.58, 14)

	return root
