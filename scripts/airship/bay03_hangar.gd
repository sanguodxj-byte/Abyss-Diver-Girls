extends RefCounted
## 潜渊·信天翁号（157.0m 母舰级，1.80x 同步放大）重型泰坦整备甲板（BAY 03）场景构造器。
## 尺度规范：
##   - 舱体主跨度、11.7m 回转台、10.1m×7.1m 泰坦气密闸门、重型排架柱、10.08m 双梁天车按 1.80x 放大；
##   - 人机工程部件（4.65m 登舱走廊与 8.35m 天车走廊的 1.05m 护栏、1.24m 工具柜、0.96m 油桶、0.82m 配电桩）严格保持 1:1 真人尺寸！
## 同时完整支持 fit_airship 切换：
##   - fit_airship = false（默认，hub.gd 实时机库视角）：纵深舒展（后壁 Z=-16.8m，宽 38m）。
##   - fit_airship = true（157.0m 信天翁号整艇外景/右舷剖视装配）：后壁与天车收束至舱室边界 X[-16.6..+16.6], Z[-12.4..+12.4]，零穿壳零 Z-fighting。

const A = preload("res://scripts/art.gd")
const MechScript = preload("res://scripts/mech.gd")
const S := 1.80
const BACKWALL_FIT_Z := 4.45   # 后舱壁从 Z=-16.8 收束至 Z=-12.35，紧贴 157m 母舰左舷装甲内侧
const CRANE_FIT_Z := 3.20      # 双梁天车从 Z=-10.05 前移至 Z=-6.85，避开收束后的双层栈桥


static func build(parent: Node3D, opts := {}) -> Dictionary:
	var mob: bool = bool(opts.get("mob", OS.has_feature("mobile")))
	var mob_ren: bool = bool(opts.get("mob_ren", RenderingServer.get_current_rendering_method() == "mobile"))
	var include_lights: bool = bool(opts.get("include_lights", true))
	var fit_airship: bool = bool(opts.get("fit_airship", false))
	var do_batch: bool = bool(opts.get("batch_static", true))

	var root := Node3D.new()
	root.name = "Bay03_ExistingInterior"
	parent.add_child(root)

	var core := Node3D.new()
	core.name = "Bay03_Core"
	root.add_child(core)

	var floor_core := Node3D.new()
	floor_core.name = "Bay03_FloorCore"
	core.add_child(floor_core)

	var legacy_wings := Node3D.new()
	legacy_wings.name = "Bay03_LegacyWings"
	root.add_child(legacy_wings)

	var airship_trim := Node3D.new()
	airship_trim.name = "Bay03_AirshipTrim"
	root.add_child(airship_trim)

	var back_wall := Node3D.new()
	back_wall.name = "Bay03_BackWall"
	root.add_child(back_wall)

	var back_wall_trim := Node3D.new()
	back_wall_trim.name = "Bay03_BackWallTrim"
	back_wall.add_child(back_wall_trim)

	var crane_node := Node3D.new()
	crane_node.name = "Bay03_Crane"
	root.add_child(crane_node)

	# 重工防滑花纹钢甲板 + 军工枪钢/漆面材质
	var M_FLOOR := A.treadplate(Color(0.18, 0.19, 0.215), 0.72, 0.48, 0.72)
	var M_DARK := A.metal(Color(0.09, 0.095, 0.105))
	var M_GUN := A.metal(Color(0.20, 0.21, 0.23))
	var M_ST := A.metal(Color(0.32, 0.33, 0.35))
	var M_CRANE := A.paint(Color(0.74, 0.48, 0.14), 0.35, 0.52, {"wear": 0.52, "rust": 0.38, "panel_scale": 0.5})
	var M_OLIVE := A.paint(Color(0.28, 0.33, 0.25), 0.22, 0.65, {"wear": 0.45, "rust": 0.32, "panel_scale": 0.4})
	var M_CAB := A.paint(Color(0.46, 0.20, 0.16), 0.35, 0.55, {"wear": 0.45, "rust": 0.35, "panel_scale": 0.0})
	var M_WALL := A.paint(Color(0.22, 0.24, 0.27), 0.38, 0.62, {"wear": 0.42, "rust": 0.28, "panel_scale": 0.6})
	var M_DOOR := A.paint(Color(0.18, 0.195, 0.22), 0.52, 0.56, {"wear": 0.48, "panel_scale": 0.75})

	# 1. 甲板防滑钢板（3m×3m 标准钢板铺满扩展后的 36m×28m 重型整备舱）
	for x in range(-6, 7):
		for z in range(-6, 5):
			var in_cabin := absi(x) <= 4 and z >= -3 and z <= 3
			var dst: Node3D = floor_core if in_cabin else legacy_wings
			A.add(dst, A.bevel_box(Vector3(2.94, 0.22, 2.94), 0.03), M_FLOOR, Vector3(float(x) * 3.0, -0.11, float(z) * 3.0))
			if absi(x) >= 3 and z >= -4 and z <= 2:
				A.add(dst, A.torus(0.06, 0.11, 12), M_GUN, Vector3(float(x) * 3.0 + 1.2, 0.012, float(z) * 3.0 + 1.2), Vector3.ZERO, Vector3(1, 0.4, 1), false)

	# 整艇贴合边界甲板（严控在 X[-16.65..+16.65], Z[-12.40..+12.40]，抬高防 Z-fighting）
	for sx: float in [-1.0, 1.0]:
		A.add(airship_trim, A.bevel_box(Vector3(3.10, 0.18, 21.0), 0.02), M_FLOOR, Vector3(sx * 15.05, -0.065, 0.0))
	for sz: float in [-1.0, 1.0]:
		A.add(airship_trim, A.bevel_box(Vector3(33.2, 0.18, 1.85), 0.02), M_FLOOR, Vector3(0.0, -0.065, sz * 11.45))

	# 两侧纵向排水钢格栅沟槽（外移至 ±7.1m）+ 前沿安全警戒带
	for sx: float in [-7.1, 7.1]:
		A.add(legacy_wings, A.bevel_box(Vector3(0.56, 0.04, 30.0), 0.008), M_DARK, Vector3(sx, -0.015, -3.5))
		A.add(airship_trim, A.bevel_box(Vector3(0.56, 0.04, 23.6), 0.008), M_DARK, Vector3(sx, 0.004, 0.0))
		for gi in 38:
			var gz := -17.5 + float(gi) * 0.78
			var gdst: Node3D = floor_core if (gz >= -11.6 and gz <= 11.6) else legacy_wings
			A.add(gdst, A.bevel_box(Vector3(0.48, 0.02, 0.12), 0.004), M_GUN, Vector3(sx, 0.018, gz), Vector3.ZERO, Vector3.ONE, false)
	A.add(legacy_wings, A.bevel_box(Vector3(38.0, 0.03, 0.52), 0.008), A.hazard(), Vector3(0.0, 0.01, 8.8))
	A.add(airship_trim, A.bevel_box(Vector3(33.0, 0.03, 0.52), 0.008), A.hazard(), Vector3(0.0, 0.024, 8.8))

	# 2. 11.7m 直径重型泰坦回转台（1.80x 半径，承托 5.65m 泰坦双足）
	var turntable := Node3D.new()
	turntable.name = "Bay03_Turntable"
	root.add_child(turntable)
	A.add(core, A.cyl(3.26 * S, 0.16, 3.38 * S, 56), M_GUN, Vector3(0, 0.06, 0))
	A.add(core, A.cyl(3.04 * S, 0.18, 3.06 * S, 56), M_DARK, Vector3(0, 0.07, 0))
	A.add(core, A.cyl(2.88 * S, 0.20, 2.94 * S, 56), A.treadplate(Color(0.24, 0.25, 0.275), 0.68, 0.46, 0.85), Vector3(0, 0.10, 0))
	A.add(core, A.cyl(2.32 * S, 0.05, 2.36 * S, 48), M_DARK, Vector3(0, 0.21, 0))
	for bi in 32:
		var ba := TAU * float(bi) / 32.0
		A.add(core, A.cyl(0.036, 0.04, 0.042, 6), M_ST, Vector3(cos(ba) * 2.66 * S, 0.215, sin(ba) * 2.66 * S), Vector3.ZERO, Vector3.ONE, false)
		if bi % 4 == 0:
			A.add(core, A.bevel_box(Vector3(0.68, 0.045, 0.24), 0.008), A.hazard(), Vector3(cos(ba) * 3.18 * S, 0.145, sin(ba) * 3.18 * S), Vector3(0, -rad_to_deg(ba) + 90.0, 0), Vector3.ONE, false)
	for ci in 4:
		var ca := TAU * float(ci) / 4.0 + PI * 0.25
		A.add(core, A.bevel_box(Vector3(0.52, 0.22, 0.64), 0.025), M_CRANE, Vector3(cos(ca) * 3.14 * S, 0.12, sin(ca) * 3.14 * S), Vector3(0, -rad_to_deg(ca), 0))
		A.add(core, A.bevel_box(Vector3(0.12, 0.04, 0.20), 0.006), A.emit(Color(1.0, 0.62, 0.16), 1.6), Vector3(cos(ca) * 3.30 * S, 0.22, sin(ca) * 3.30 * S), Vector3(0, -rad_to_deg(ca), 0), Vector3.ONE, false)

	# 1:1 真人尺寸地面液压配电桩（0.82m 高）与脐带软管接入转盘边缘
	A.add(core, A.bevel_box(Vector3(0.64, 0.82, 0.52), 0.03), M_GUN, Vector3(6.25, 0.41, -2.65))
	A.hose(core, Vector3(5.96, 0.30, -2.52), Vector3(5.22, 0.08, -2.12), Vector3(0.0, -0.12, 0.16), 0.052)
	A.hose(core, Vector3(5.96, 0.22, -2.78), Vector3(5.12, 0.07, -2.42), Vector3(0.0, -0.10, -0.14), 0.044)

	# 3. 后舱壁（Z = -16.8m，高 13.0m 以严控在 157m 母舰 13.3m 舱顶内）+ 10.1m×7.1m 泰坦气密门
	var bw_z := -16.8
	var wall_h := 13.05
	for x in range(-6, 7):
		var panel_dst: Node3D = back_wall if absi(x) <= 4 else legacy_wings
		A.add(panel_dst, A.bevel_box(Vector3(3.12, wall_h, 0.55), 0.06), M_WALL, Vector3(float(x) * 3.2, wall_h * 0.5, bw_z))
		var rib_x := float(x) * 3.2 + 1.6
		var rib_dst: Node3D = back_wall if absf(rib_x) <= 14.5 else legacy_wings
		A.add(rib_dst, A.bevel_box(Vector3(0.44, wall_h + 0.1, 0.92), 0.035), M_DARK, Vector3(rib_x, wall_h * 0.5 + 0.05, bw_z + 0.32))
	for sx: float in [-1.0, 1.0]:
		A.add(back_wall_trim, A.bevel_box(Vector3(2.35, wall_h, 0.48), 0.04), M_WALL, Vector3(sx * 15.45, wall_h * 0.5, bw_z))

	# 中央 10.1m 宽 × 7.1m 高 泰坦级重装甲对开气密闸门（6m 泰坦可直立正步通过）
	var gate_w := 5.6 * S
	var gate_h := 3.95 * S
	A.add(back_wall, A.bevel_box(Vector3(gate_w, gate_h, 0.52), 0.06), M_DARK, Vector3(0.0, gate_h * 0.5, bw_z + 0.36))
	for sx: float in [-1.0, 1.0]:
		var leaf_w := 2.54 * S
		var leaf_h := 3.68 * S
		var lx := sx * (leaf_w * 0.5 + 0.08)
		A.add(back_wall, A.bevel_box(Vector3(leaf_w, leaf_h, 0.34), 0.05), M_DOOR, Vector3(lx, leaf_h * 0.5 + 0.06, bw_z + 0.56))
		for ri in 6:
			A.add(back_wall, A.bevel_box(Vector3(leaf_w - 0.3, 0.14, 0.12), 0.02), M_GUN, Vector3(lx, 0.72 + float(ri) * 1.08, bw_z + 0.75))
		A.add(back_wall, A.bevel_box(Vector3(0.38, 1.15, 0.14), 0.02), M_ST, Vector3(sx * 0.28, 3.2, bw_z + 0.78))
	A.add(back_wall, A.bevel_box(Vector3(gate_w + 0.4, 0.34, 0.62), 0.03), A.hazard(), Vector3(0.0, gate_h - 0.12, bw_z + 0.58))

	# 4. 双层真人尺度检修走廊（4.65m 胸舱登舰走廊 + 8.35m 天车走廊；护栏严格保持 1.05m 真人高度，立柱每 1.5m 一根！）
	var cw_w := 33.0
	for deck_y: float in [4.65, 8.35]:
		var cw_z := bw_z + 1.35
		A.add(back_wall, A.bevel_box(Vector3(cw_w, 0.20, 1.75), 0.03), M_GUN, Vector3(0.0, deck_y, cw_z))
		A.add(back_wall, A.bevel_box(Vector3(cw_w, 0.14, 0.08), 0.01), M_CRANE, Vector3(0.0, deck_y + 0.08, cw_z + 0.86))
		for bx in range(-15, 16, 3):
			A.add(back_wall, A.bevel_box(Vector3(0.16, 0.85, 1.45), 0.02), M_DARK, Vector3(float(bx), deck_y - 0.48, cw_z - 0.12), Vector3(28, 0, 0))
		var rail_z := cw_z + 0.86
		A.add(back_wall, A.bevel_box(Vector3(cw_w, 0.055, 0.06), 0.01), M_CRANE, Vector3(0.0, deck_y + 1.05, rail_z))
		A.add(back_wall, A.bevel_box(Vector3(cw_w, 0.035, 0.04), 0.008), M_ST, Vector3(0.0, deck_y + 0.55, rail_z))
		var post_x := -16.2
		while post_x <= 16.21:
			A.add(back_wall, A.bevel_box(Vector3(0.05, 1.05, 0.05), 0.008), M_ST, Vector3(post_x, deck_y + 0.525, rail_z))
			post_x += 1.5

	# 二层两侧向前延伸的泰坦肩胸检修栈桥翼廊（带 1.05m 真人护栏）
	for sx: float in [-1.0, 1.0]:
		var wx := sx * 10.6
		var wr_x := wx - sx * 0.88
		A.add(legacy_wings, A.bevel_box(Vector3(1.85, 0.20, 13.6), 0.03), M_GUN, Vector3(wx, 4.65, -8.6))
		A.add(legacy_wings, A.bevel_box(Vector3(0.06, 0.055, 13.6), 0.01), M_CRANE, Vector3(wr_x, 4.65 + 1.05, -8.6))
		A.add(legacy_wings, A.bevel_box(Vector3(0.04, 0.035, 13.6), 0.008), M_ST, Vector3(wr_x, 4.65 + 0.55, -8.6))
		for pz_i in 10:
			var pz := -15.2 + float(pz_i) * 1.48
			A.add(legacy_wings, A.bevel_box(Vector3(0.05, 1.05, 0.05), 0.008), M_ST, Vector3(wr_x, 4.65 + 0.525, pz))

		A.add(airship_trim, A.bevel_box(Vector3(1.85, 0.20, 11.2), 0.03), M_GUN, Vector3(wx, 4.65, -5.4))
		A.add(airship_trim, A.bevel_box(Vector3(0.06, 0.055, 11.2), 0.01), M_CRANE, Vector3(wr_x, 4.65 + 1.05, -5.4))
		A.add(airship_trim, A.bevel_box(Vector3(0.04, 0.035, 11.2), 0.008), M_ST, Vector3(wr_x, 4.65 + 0.55, -5.4))
		for pz_i in 8:
			var pz2 := -10.6 + float(pz_i) * 1.48
			A.add(airship_trim, A.bevel_box(Vector3(0.05, 1.05, 0.05), 0.008), M_ST, Vector3(wr_x, 4.65 + 0.525, pz2))

	# 5. 高窗百叶采光阵列与 BAY 03 巨型门楣铭牌
	for x_s: float in [-8.6, 8.6]:
		A.add(back_wall, A.bevel_box(Vector3(5.2, 2.05, 0.16), 0.03), A.emit(Color(0.95, 0.68, 0.42), 0.40), Vector3(x_s, 10.05, bw_z + 0.42), Vector3.ZERO, Vector3.ONE, false)
		A.add(back_wall, A.bevel_box(Vector3(5.6, 0.22, 0.42), 0.02), M_DARK, Vector3(x_s, 11.15, bw_z + 0.52))
		A.add(back_wall, A.bevel_box(Vector3(5.6, 0.22, 0.42), 0.02), M_DARK, Vector3(x_s, 8.95, bw_z + 0.52))
		for lv in 4:
			A.add(back_wall, A.bevel_box(Vector3(5.3, 0.07, 0.32), 0.01), M_GUN, Vector3(x_s, 9.35 + float(lv) * 0.46, bw_z + 0.56), Vector3(18, 0, 0))
		if include_lights and not mob and not mob_ren:
			var wl := OmniLight3D.new()
			wl.light_color = Color(1.0, 0.72, 0.46)
			wl.light_energy = 1.65
			wl.omni_range = 17.5
			wl.position = Vector3(x_s, 9.8, bw_z + 3.2)
			back_wall.add_child(wl)

	A.add(back_wall, A.bevel_box(Vector3(7.4, 1.52, 0.26), 0.04), M_DARK, Vector3(0.0, 10.15, bw_z + 0.62))
	var bay := Label3D.new()
	bay.text = "BAY 03"
	bay.font_size = 128
	bay.pixel_size = 0.0115
	bay.modulate = Color(0.92, 0.68, 0.28, 0.86)
	bay.outline_size = 8
	bay.outline_modulate = Color(0.05, 0.05, 0.06, 0.88)
	bay.shaded = false
	bay.position = Vector3(0.0, 10.42, bw_z + 0.80)
	back_wall.add_child(bay)
	A.stencil(back_wall, "ALBATROSS-III · TITAN CARRIER DECK", Vector3(0.0, 9.64, bw_z + 0.80), Vector3.ZERO, 0.0052, Color(0.76, 0.78, 0.76, 0.72))

	# 6. 两侧 13.0m 重型 H 钢承重排架柱（X = ±12.2m）+ 9.75m 高天车轨道梁 + 1:1 真人尺寸工位整备道具！
	var col_h := 13.0
	for sx: float in [-1.0, 1.0]:
		for cz: float in [-15.2, -7.8, 1.2]:
			var cdst: Node3D = back_wall if cz < -12.0 else core
			A.add(cdst, A.bevel_box(Vector3(0.92, col_h, 0.92), 0.05), M_DARK, Vector3(sx * 12.2, col_h * 0.5, cz))
			A.add(cdst, A.bevel_box(Vector3(0.38, col_h - 0.1, 1.14), 0.03), M_GUN, Vector3(sx * 12.2, col_h * 0.5, cz))
			A.add(cdst, A.bevel_box(Vector3(1.16, 0.48, 1.18), 0.03), A.hazard(), Vector3(sx * 12.2, 1.15, cz))
			A.add(cdst, A.bevel_box(Vector3(2.2, 0.36, 0.42), 0.025), M_GUN, Vector3(sx * 11.2, 9.45, cz), Vector3(0, 0, sx * 36.0))
		A.add(legacy_wings, A.bevel_box(Vector3(0.68, 0.76, 26.5), 0.04), M_CRANE, Vector3(sx * 11.45, 9.75, -5.8))
		A.add(airship_trim, A.bevel_box(Vector3(0.68, 0.76, 23.4), 0.04), M_CRANE, Vector3(sx * 11.45, 9.75, -0.2))

		# 1:1 真人尺寸工位整备道具（严禁乘 1.8x！1.24m 工具柜 + 0.96m 油桶簇 + 1.12m 补给箱）
		var cab_p := Vector3(sx * 8.45, 0.0, -2.6)
		A.add(core, A.bevel_box(Vector3(0.86, 1.24, 1.48), 0.04), M_CAB, cab_p + Vector3(0, 0.62, 0), Vector3(0, sx * -14.0, 0))
		A.add(core, A.bevel_box(Vector3(0.90, 0.06, 1.52), 0.015), M_DARK, cab_p + Vector3(0, 1.27, 0), Vector3(0, sx * -14.0, 0))
		for dy: float in [0.32, 0.60, 0.88, 1.10]:
			A.add(core, A.bevel_box(Vector3(0.05, 0.03, 1.12), 0.006), M_ST, cab_p + Vector3(-sx * 0.44, dy, 0), Vector3(0, sx * -14.0, 0))

		for di in 2:
			var dp := Vector3(sx * (8.9 + float(di) * 0.76), 0.0, 1.45 + float(di) * 0.42)
			A.add(core, A.cyl(0.32, 0.96, 0.32, 18), M_OLIVE if (di == 0 and sx < 0.0) else M_GUN, dp + Vector3(0, 0.48, 0))
			A.add(core, A.torus(0.30, 0.34, 18), M_DARK, dp + Vector3(0, 0.68, 0), Vector3.ZERO, Vector3(1, 0.4, 1), false)

		var cr_p := Vector3(sx * 9.2, 0.0, -7.8)
		A.add(core, A.bevel_box(Vector3(1.55, 0.14, 1.25), 0.02), M_DARK, cr_p + Vector3(0, 0.07, 0))
		A.add(core, A.bevel_box(Vector3(1.42, 0.98, 1.08), 0.05), M_OLIVE, cr_p + Vector3(0, 0.63, 0))
		A.add(core, A.bevel_box(Vector3(1.06, 0.72, 0.88), 0.04), M_CRANE, cr_p + Vector3(sx * 0.12, 1.48, 0.08), Vector3(0, sx * 14.0, 0))

	# 7. 顶部 10.08m 横跨双梁工业天车 + 吊钩（净空 7.40m，高出 6.15m 泰坦背盾 1.25m）
	for gz: float in [-10.6, -9.5]:
		A.add(crane_node, A.bevel_box(Vector3(23.6, 0.68, 0.46), 0.04), M_CRANE, Vector3(0.0, 10.08, gz))
	A.add(crane_node, A.bevel_box(Vector3(2.15, 0.52, 1.68), 0.04), M_DARK, Vector3(3.8, 10.42, -10.05))
	for cx_off: float in [-0.32, 0.32]:
		A.add(crane_node, A.cyl(0.028, 2.25, 0.028, 8), M_ST, Vector3(3.8 + cx_off, 9.12, -10.05))
	A.add(crane_node, A.bevel_box(Vector3(0.86, 0.52, 0.42), 0.03), A.hazard(), Vector3(3.8, 7.85, -10.05))
	A.add(crane_node, A.torus(0.16, 0.26, 14), M_GUN, Vector3(3.8, 7.40, -10.05), Vector3(0, 90, 0), Vector3.ONE, false)
	for tz: float in [-15.2, -7.8, 1.2]:
		var tdst: Node3D = back_wall if tz < -12.0 else core
		A.add(tdst, A.bevel_box(Vector3(24.8, 0.52, 0.46), 0.03), M_DARK, Vector3(0.0, 11.25, tz))

	root.set_meta("bay03_parts", {
		"core": core,
		"floor_core": floor_core,
		"legacy_wings": legacy_wings,
		"airship_trim": airship_trim,
		"back_wall": back_wall,
		"back_wall_trim": back_wall_trim,
		"crane": crane_node,
		"turntable": turntable,
	})
	if do_batch:
		MechScript._batch_visual(root)
	set_airship_fit(root, fit_airship)
	return {
		"root": root,
		"turntable": turntable,
		"core": core,
		"legacy_wings": legacy_wings,
		"airship_trim": airship_trim,
		"back_wall": back_wall,
		"crane": crane_node,
	}


static func set_airship_fit(bay_root: Node3D, fitted: bool) -> void:
	if bay_root == null or not bay_root.has_meta("bay03_parts"):
		return
	var p: Dictionary = bay_root.get_meta("bay03_parts")
	var legacy_wings: Node3D = p["legacy_wings"]
	var airship_trim: Node3D = p["airship_trim"]
	var back_wall: Node3D = p["back_wall"]
	var back_wall_trim: Node3D = p["back_wall_trim"]
	var crane_node: Node3D = p["crane"]
	var floor_core: Node3D = p["floor_core"]
	legacy_wings.visible = not fitted
	airship_trim.visible = fitted
	back_wall_trim.visible = fitted
	back_wall.position = Vector3(0.0, 0.0, BACKWALL_FIT_Z) if fitted else Vector3.ZERO
	crane_node.position = Vector3(0.0, 0.0, CRANE_FIT_Z) if fitted else Vector3.ZERO
	floor_core.position = Vector3(0.0, 0.024, 0.0) if fitted else Vector3.ZERO
