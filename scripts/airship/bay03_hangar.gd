extends RefCounted
## 信天翁号重型机甲整备甲板（BAY 03）可复用场景构造器。
## 完整保留 hub.gd 原有 BAY 03 的全部几何、材质、铭牌、天车、转盘与灯光，零视觉修改；
## 同时支持 fit_airship 切换：
##   - fit_airship = false（默认，hub.gd 实时机库视角）：100% 原坐标、原景深、原宽度，像素级保留既有视觉。
##   - fit_airship = true（87.2m 信天翁号整艇外景/剖视装配）：后壁与天车收束至舱室边界 X[-9.35..+9.35], Z[-7.05..+7.05]，无穿壳无 Z-fighting。

const A = preload("res://scripts/art.gd")
const MechScript = preload("res://scripts/mech.gd")
const BACKWALL_FIT_Z := 2.68   # 后舱壁从 Z=-9.6 收束至 Z=-6.92，紧贴左舷装甲内侧（Z=-7.2）
const CRANE_FIT_Z := 1.90      # 双梁天车从 Z=-6.0 前移至 Z=-4.10，避开收束后的二层廊道栏杆


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

	# 原版材质（与 hub.gd 完全一致）
	var M_FLOOR := A.paint(Color(0.16, 0.17, 0.19), 0.72, 0.58, {"wear": 0.48, "rust": 0.25, "dust": 0.22, "panel_scale": 0.85})
	var M_DARK := A.metal(Color(0.09, 0.095, 0.105))
	var M_GUN := A.metal(Color(0.20, 0.21, 0.23))
	var M_ST := A.metal(Color(0.32, 0.33, 0.35))
	var M_CRANE := A.paint(Color(0.74, 0.48, 0.14), 0.35, 0.52, {"wear": 0.52, "rust": 0.38, "panel_scale": 0.5})
	var M_OLIVE := A.paint(Color(0.28, 0.33, 0.25), 0.22, 0.65, {"wear": 0.45, "rust": 0.32, "panel_scale": 0.4})
	var M_CAB := A.paint(Color(0.46, 0.20, 0.16), 0.35, 0.55, {"wear": 0.45, "rust": 0.35, "panel_scale": 0.0})

	# 甲板防滑钢板（中心块共用，外围块仅 legacy 可见，整艇模式用贴合边界板补齐）
	for x in range(-4, 5):
		for z in range(-4, 3):
			var in_cabin := absi(x) <= 2 and z >= -1 and z <= 1
			var dst: Node3D = floor_core if in_cabin else legacy_wings
			A.add(dst, A.bevel_box(Vector3(2.94, 0.20, 2.94), 0.03), M_FLOOR, Vector3(x * 3.0, -0.10, z * 3.0))
			if absi(x) >= 2 and z >= -2 and z <= 1:
				var ring_dst: Node3D = floor_core if in_cabin else legacy_wings
				A.add(ring_dst, A.torus(0.05, 0.09, 12), M_GUN, Vector3(x * 3.0 + 1.2, 0.01, z * 3.0 + 1.2), Vector3.ZERO, Vector3(1, 0.4, 1), false)
	# 整艇贴合边界甲板（严控在 X[-9.32..+9.32], Z[-6.98..+6.98]，抬高 +0.014 防与底板 Z-fighting）
	for sx in [-1.0, 1.0]:
		A.add(airship_trim, A.bevel_box(Vector3(1.80, 0.16, 8.94), 0.02), M_FLOOR, Vector3(sx * 8.40, -0.066, 0.0))
	for sz in [-1.0, 1.0]:
		A.add(airship_trim, A.bevel_box(Vector3(18.60, 0.16, 2.46), 0.02), M_FLOOR, Vector3(0.0, -0.066, sz * 5.74))

	# 两侧纵向排水钢格栅沟槽 + 前沿安全黄黑警戒带
	for sx in [-3.95, 3.95]:
		A.add(legacy_wings, A.bevel_box(Vector3(0.46, 0.04, 18.0), 0.008), M_DARK, Vector3(sx, -0.015, -2.5))
		A.add(airship_trim, A.bevel_box(Vector3(0.46, 0.04, 13.4), 0.008), M_DARK, Vector3(sx, 0.002, 0.0))
		for gi in 26:
			var gz := -10.8 + gi * 0.65
			var gdst: Node3D = floor_core if (gz >= -6.6 and gz <= 6.6) else legacy_wings
			A.add(gdst, A.bevel_box(Vector3(0.40, 0.02, 0.10), 0.004), M_GUN, Vector3(sx, 0.016, gz), Vector3.ZERO, Vector3.ONE, false)
	A.add(legacy_wings, A.bevel_box(Vector3(27, 0.028, 0.42), 0.008), A.hazard(), Vector3(0, 0.008, 4.9))
	A.add(airship_trim, A.bevel_box(Vector3(18.5, 0.028, 0.42), 0.008), A.hazard(), Vector3(0, 0.020, 4.9))

	# 沉降式重工机械回转台（与 MechPad_Anchor(0, 1.56, 0) 精确重合）
	var turntable := Node3D.new()
	turntable.name = "Bay03_Turntable"
	root.add_child(turntable)
	A.add(core, A.cyl(3.26, 0.11, 3.38, 48), M_GUN, Vector3(0, 0.045, 0))
	A.add(core, A.cyl(3.04, 0.13, 3.06, 48), M_DARK, Vector3(0, 0.05, 0))
	A.add(core, A.cyl(2.88, 0.14, 2.94, 48), A.paint(Color(0.22, 0.23, 0.25), 0.65, 0.52, {"wear": 0.55, "panel_scale": 0.9}), Vector3(0, 0.075, 0))
	A.add(core, A.cyl(2.32, 0.035, 2.36, 44), M_DARK, Vector3(0, 0.15, 0))
	for bi in 24:
		var ba := TAU * float(bi) / 24.0
		A.add(core, A.cyl(0.028, 0.03, 0.032, 6), M_ST, Vector3(cos(ba) * 2.66, 0.152, sin(ba) * 2.66), Vector3.ZERO, Vector3.ONE, false)
		if bi % 3 == 0:
			A.add(core, A.bevel_box(Vector3(0.46, 0.035, 0.18), 0.008), A.hazard(), Vector3(cos(ba) * 3.18, 0.105, sin(ba) * 3.18), Vector3(0, -rad_to_deg(ba) + 90.0, 0), Vector3.ONE, false)
	for ci in 4:
		var ca := TAU * float(ci) / 4.0 + PI * 0.25
		A.add(core, A.bevel_box(Vector3(0.36, 0.16, 0.44), 0.02), M_CRANE, Vector3(cos(ca) * 3.14, 0.09, sin(ca) * 3.14), Vector3(0, -rad_to_deg(ca), 0))
		A.add(core, A.bevel_box(Vector3(0.08, 0.03, 0.14), 0.005), A.emit(Color(1.0, 0.62, 0.16), 1.4), Vector3(cos(ca) * 3.30, 0.16, sin(ca) * 3.30), Vector3(0, -rad_to_deg(ca), 0), Vector3.ONE, false)
	# 右侧地面液压配电桩与脐带软管束接入转盘井
	A.add(core, A.bevel_box(Vector3(0.58, 0.68, 0.46), 0.03), M_GUN, Vector3(3.55, 0.34, -1.65))
	A.hose(core, Vector3(3.32, 0.22, -1.55), Vector3(2.85, 0.06, -1.25), Vector3(0.0, -0.10, 0.12), 0.038)
	A.hose(core, Vector3(3.32, 0.16, -1.75), Vector3(2.78, 0.05, -1.50), Vector3(0.0, -0.08, -0.10), 0.030)

	# 后舱壁重型防爆整备闸门 + H型钢立柱 + 二层检修钢走廊 + 两侧百叶采光灯阵
	var M_WALL := A.paint(Color(0.22, 0.24, 0.27), 0.38, 0.62, {"wear": 0.42, "rust": 0.28, "panel_scale": 0.6})
	var M_DOOR := A.paint(Color(0.18, 0.195, 0.22), 0.52, 0.56, {"wear": 0.48, "panel_scale": 0.75})
	for x in range(-5, 6):
		var panel_dst: Node3D = back_wall if absi(x) <= 2 else legacy_wings
		A.add(panel_dst, A.bevel_box(Vector3(2.85, 8.2, 0.40), 0.06), M_WALL, Vector3(x * 3.0, 4.1, -9.6))
		var rib_x := x * 3.0 + 1.5
		var rib_dst: Node3D = back_wall if absf(rib_x) <= 8.0 else legacy_wings
		A.add(rib_dst, A.bevel_box(Vector3(0.32, 8.3, 0.65), 0.03), M_DARK, Vector3(rib_x, 4.15, -9.35))
	# 整艇贴合模式后壁左右补边板（X[-9.32..-7.50] 与 [+7.50..+9.32]）
	for sx in [-1.0, 1.0]:
		A.add(back_wall_trim, A.bevel_box(Vector3(1.82, 8.2, 0.36), 0.04), M_WALL, Vector3(sx * 8.42, 4.1, -9.6))
	# 中央重装甲对开气密闸门（BAY 03 背景框景）
	A.add(back_wall, A.bevel_box(Vector3(5.6, 3.95, 0.34), 0.05), M_DARK, Vector3(0, 1.98, -9.32))
	for sx in [-1.32, 1.32]:
		A.add(back_wall, A.bevel_box(Vector3(2.54, 3.68, 0.22), 0.04), M_DOOR, Vector3(sx, 1.88, -9.16))
		for ri in 4:
			A.add(back_wall, A.bevel_box(Vector3(2.36, 0.10, 0.08), 0.015), M_GUN, Vector3(sx, 0.58 + ri * 0.86, -9.03))
		A.add(back_wall, A.bevel_box(Vector3(0.28, 0.76, 0.10), 0.015), M_ST, Vector3(sx * 0.18, 1.85, -9.02))
	A.add(back_wall, A.bevel_box(Vector3(5.8, 0.22, 0.42), 0.03), A.hazard(), Vector3(0, 3.84, -9.15))

	# 二层横向检修走廊与安全栏杆（宽度 18.6m 恰好落在 ±9.3m 舱壁内）
	A.add(back_wall, A.bevel_box(Vector3(18.6, 0.18, 1.35), 0.03), M_GUN, Vector3(0, 4.02, -8.65))
	for rx in range(-9, 10, 2):
		A.add(back_wall, A.bevel_box(Vector3(0.06, 0.92, 0.06), 0.01), M_ST, Vector3(float(rx), 4.52, -8.02))
		A.add(back_wall, A.bevel_box(Vector3(0.14, 0.65, 1.15), 0.02), M_DARK, Vector3(float(rx), 3.62, -8.75), Vector3(26, 0, 0))
	A.add(back_wall, A.bevel_box(Vector3(18.64, 0.07, 0.08), 0.01), M_CRANE, Vector3(0, 4.98, -8.02))
	A.add(back_wall, A.bevel_box(Vector3(18.6, 0.04, 0.04), 0.01), M_ST, Vector3(0, 4.52, -8.02))

	# 两侧百叶采光天窗
	for x in [-4.8, 4.8]:
		A.add(back_wall, A.bevel_box(Vector3(2.9, 1.15, 0.12), 0.03), A.emit(Color(0.95, 0.64, 0.36), 0.58), Vector3(x, 5.28, -9.28), Vector3.ZERO, Vector3.ONE, false)
		A.add(back_wall, A.bevel_box(Vector3(3.15, 0.15, 0.30), 0.02), M_DARK, Vector3(x, 5.90, -9.20))
		A.add(back_wall, A.bevel_box(Vector3(3.15, 0.15, 0.30), 0.02), M_DARK, Vector3(x, 4.66, -9.20))
		for lv in 3:
			A.add(back_wall, A.bevel_box(Vector3(2.95, 0.05, 0.22), 0.008), M_GUN, Vector3(x, 4.94 + lv * 0.34, -9.18), Vector3(18, 0, 0))
		if include_lights and not mob and not mob_ren:
			var wl := OmniLight3D.new()
			wl.light_color = Color(1.0, 0.68, 0.40)
			wl.light_energy = 1.25
			wl.omni_range = 9.5
			wl.position = Vector3(x, 5.2, -7.6)
			back_wall.add_child(wl)

	# 后舱门楣工业铭牌横匾（BAY 03）
	A.add(back_wall, A.bevel_box(Vector3(4.2, 0.88, 0.18), 0.03), M_DARK, Vector3(0, 5.28, -9.12))
	var bay := Label3D.new()
	bay.text = "BAY 03"
	bay.font_size = 112
	bay.pixel_size = 0.0072
	bay.modulate = Color(0.92, 0.68, 0.28, 0.82)
	bay.outline_size = 6
	bay.outline_modulate = Color(0.05, 0.05, 0.06, 0.85)
	bay.shaded = false
	bay.position = Vector3(0, 5.42, -9.00)
	back_wall.add_child(bay)
	A.stencil(back_wall, "ALBATROSS · HEAVY MECH DECK", Vector3(0, 4.98, -9.00), Vector3.ZERO, 0.0032, Color(0.76, 0.78, 0.76, 0.68))

	# 两侧重型 H 钢承重排架柱 + 纵向天车轨道梁 + 侧翼工位整备道具
	for sx in [-1.0, 1.0]:
		for cz in [-8.6, -4.4, 0.6]:
			var cdst: Node3D = back_wall if cz < -7.0 else core
			A.add(cdst, A.bevel_box(Vector3(0.54, 7.6, 0.54), 0.04), M_DARK, Vector3(sx * 6.8, 3.8, cz))
			A.add(cdst, A.bevel_box(Vector3(0.22, 7.56, 0.66), 0.02), M_GUN, Vector3(sx * 6.8, 3.8, cz))
			A.add(cdst, A.bevel_box(Vector3(0.68, 0.32, 0.70), 0.03), A.hazard(), Vector3(sx * 6.8, 0.85, cz))
			A.add(cdst, A.bevel_box(Vector3(1.35, 0.22, 0.26), 0.02), M_GUN, Vector3(sx * 6.22, 5.22, cz), Vector3(0, 0, sx * 36.0))
		A.add(legacy_wings, A.bevel_box(Vector3(0.40, 0.46, 15.6), 0.03), M_CRANE, Vector3(sx * 6.38, 5.38, -3.8))
		A.add(airship_trim, A.bevel_box(Vector3(0.40, 0.46, 13.4), 0.03), M_CRANE, Vector3(sx * 6.38, 5.38, -0.1))
		# 左右工位整备道具（均在 X=±4.7..±6.4, Z=-5.4..+1.0，100% 落在 BAY 03 舱内）
		A.add(core, A.bevel_box(Vector3(1.55, 0.14, 1.25), 0.02), M_DARK, Vector3(sx * 5.4, 0.065, -5.4))
		A.add(core, A.bevel_box(Vector3(1.42, 0.98, 1.08), 0.05), M_OLIVE, Vector3(sx * 5.4, 0.610, -5.4))
		A.add(core, A.bevel_box(Vector3(1.50, 0.10, 1.16), 0.02), M_DARK, Vector3(sx * 5.4, 1.140, -5.4))
		A.add(core, A.bevel_box(Vector3(1.06, 0.72, 0.88), 0.04), M_CRANE, Vector3(sx * 5.55, 1.545, -5.3), Vector3(0, sx * 14.0, 0))
		A.add(core, A.bevel_box(Vector3(0.86, 1.24, 1.48), 0.04), M_CAB, Vector3(sx * 5.15, 0.66, -1.8), Vector3(0, sx * -12.0, 0))
		A.add(core, A.bevel_box(Vector3(0.90, 0.06, 1.52), 0.015), M_DARK, Vector3(sx * 5.15, 1.30, -1.8), Vector3(0, sx * -12.0, 0))
		for dy in [0.34, 0.62, 0.90, 1.12]:
			A.add(core, A.bevel_box(Vector3(0.05, 0.03, 1.12), 0.006), M_ST, Vector3(sx * 4.70, dy, -1.8), Vector3(0, sx * -12.0, 0))
		A.add(core, A.cyl(0.32, 0.96, 0.32, 18), M_OLIVE if sx < 0.0 else M_GUN, Vector3(sx * 6.05, 0.48, 1.0))
		A.add(core, A.torus(0.30, 0.34, 18), M_DARK, Vector3(sx * 6.05, 0.68, 1.0), Vector3.ZERO, Vector3(1, 0.4, 1), false)

	# 顶部横跨双梁工业天车 + 起重滑车与锻钢吊钩
	for gz in [-6.32, -5.68]:
		A.add(crane_node, A.bevel_box(Vector3(13.2, 0.42, 0.28), 0.03), M_CRANE, Vector3(0, 5.56, gz))
	A.add(crane_node, A.bevel_box(Vector3(1.28, 0.34, 1.04), 0.03), M_DARK, Vector3(2.25, 5.76, -6.00))
	for cx_off in [-0.20, 0.20]:
		A.add(crane_node, A.cyl(0.018, 1.48, 0.018, 8), M_ST, Vector3(2.25 + cx_off, 4.92, -6.00))
	A.add(crane_node, A.bevel_box(Vector3(0.58, 0.36, 0.28), 0.03), A.hazard(), Vector3(2.25, 4.12, -6.00))
	A.add(crane_node, A.torus(0.10, 0.16, 14), M_GUN, Vector3(2.25, 3.80, -6.00), Vector3(0, 90, 0), Vector3.ONE, false)
	for tz in [-8.6, -4.4, 0.6]:
		var tdst: Node3D = back_wall if tz < -7.0 else core
		A.add(tdst, A.bevel_box(Vector3(14.0, 0.32, 0.28), 0.02), M_DARK, Vector3(0, 6.22, tz))

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
	# 整艇模式中略微抬升共享中心甲板 +1.4cm，完全避免与信天翁号底层总甲板 Y=1.40 产生 Z-fighting
	floor_core.position = Vector3(0.0, 0.014, 0.0) if fitted else Vector3.ZERO
