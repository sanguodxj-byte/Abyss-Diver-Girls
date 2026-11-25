extends RefCounted
## 全量物品 3D 程序化模型库（模块复用 mech_visual / modules，消耗品与物资 40 款独立精细 3D 建模）
## 仅用于工作室布光烘焙 gw×gh 多格高清静态 3D 图标，与地面世界保持零运行时负担。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")
const MV = preload("res://scripts/mech_visual.gd")
const CrystalRig = preload("res://scripts/models/lm_crystal_survey_rig.gd")
const CRYSTAL_SHADER = preload("res://shaders/abyss_crystal.gdshader")

static var _bug_crystal_mat_cache: ShaderMaterial = null


static func _bug_crystal_mat() -> ShaderMaterial:
	if _bug_crystal_mat_cache != null:
		return _bug_crystal_mat_cache
	var m := ShaderMaterial.new()
	m.shader = CRYSTAL_SHADER
	m.set_shader_parameter("deep_color", Color(0.055, 0.015, 0.135))
	m.set_shader_parameter("mid_color", Color(0.280, 0.075, 0.480))
	m.set_shader_parameter("tip_color", Color(0.420, 0.840, 0.960))
	m.set_shader_parameter("outer_violet", Color(0.460, 0.120, 0.720))
	m.set_shader_parameter("core_glow_color", Color(0.840, 0.340, 0.990))
	m.set_shader_parameter("edge_glow_color", Color(0.620, 0.960, 1.000))
	m.set_shader_parameter("glow_strength", 1.15)
	_bug_crystal_mat_cache = m
	return m


static func _gd() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GameData")


## 构建任意物品/模块的展示 3D 根节点，并在 meta["cam_dir"] 写入最佳拍摄视角（从目标指向相机）
static func build_item_3d(id: String) -> Node3D:
	var gd: Node = _gd()
	var base: String = id
	if gd != null and gd.has_method("base_id"):
		base = str(gd.call("base_id", id))
		if base == "":
			base = id

	# 1. 机甲模块（46 款）：复用真实机甲 3D 模块脚本并设定最佳工业展示机位
	if gd != null and gd.has_method("is_module") and bool(gd.call("is_module", id)):
		var m_info: Dictionary = gd.call("module", id)
		var slot: String = str(m_info.get("slot", "core"))
		var build_slot: String = "arm_r" if slot == "arm" else slot
		var mod: Node3D = MV.build_module(build_slot, id, true, "01")
		if mod != null:
			var cam_dir := Vector3(0.74, 0.50, -0.82).normalized()
			match slot:
				"arm":
					# 手臂武器：侧前方略俯视轮廓，-Z 枪口朝右侧，完整铺满 gw×1 宽格
					cam_dir = Vector3(0.96, 0.24, -0.18).normalized()
				"core":
					cam_dir = Vector3(0.70, 0.44, -0.85).normalized()
				"legs":
					cam_dir = Vector3(0.76, 0.42, -0.82).normalized()
				"back":
					if base == "back_rack":
						cam_dir = Vector3(-0.72, 0.48, 0.78).normalized()
					else:
						cam_dir = Vector3(0.72, 0.48, -0.78).normalized()
				"gen":
					# 动力炉细节面朝 +Z（躯干背面可见仪表、散热翼与反应窗）
					cam_dir = Vector3(0.68, 0.40, 0.86).normalized()
					if base == "gen_cell" or base == "gen_crystal":
						# 1×2 竖格：竖置电芯矩阵 / 晶体约束柱以填满竖向 1×2 比例
						mod.rotation_degrees = Vector3(0.0, 0.0, 90.0 if base == "gen_cell" else 0.0)
			mod.set_meta("cam_dir", cam_dir)
			return mod

	# 2. 非模块物品（40 款独立精细 3D 建模）
	var root := Node3D.new()
	root.name = "Item3D_" + base
	var cam_dir := Vector3(0.68, 0.62, 0.80).normalized()

	match base:
		"can_food":
			cam_dir = _build_can_food(root)
		"biscuit":
			cam_dir = _build_biscuit(root)
		"water_tab":
			cam_dir = _build_water_tab(root)
		"coffee":
			cam_dir = _build_coffee(root)
		"circuit":
			cam_dir = _build_circuit(root)
		"wire":
			cam_dir = _build_wire(root)
		"bolts":
			cam_dir = _build_bolts(root)
		"hdd":
			cam_dir = _build_hdd(root)
		"toy":
			cam_dir = _build_toy(root)
		"chitin":
			cam_dir = _build_chitin(root)
		"bug_crystal":
			cam_dir = _build_bug_crystal(root)
		"fuel_cell":
			cam_dir = _build_fuel_cell(root)
		"repair_kit":
			cam_dir = _build_repair_kit(root)
		"beacon":
			cam_dir = _build_beacon(root)
		"sonic_decoy":
			cam_dir = _build_sonic_decoy(root)
		"extract_flare":
			cam_dir = _build_extract_flare(root)
		"energy_rod":
			cam_dir = _build_energy_rod(root)
		"coolant_pack":
			cam_dir = _build_coolant_pack(root)
		"extract_barrier":
			cam_dir = _build_extract_barrier(root)
		"surge_cell":
			cam_dir = _build_surge_cell(root)
		"credit_s":
			cam_dir = _build_credit_chip(root, false)
		"credit_l":
			cam_dir = _build_credit_chip(root, true)
		"gold":
			cam_dir = _build_gold(root)
		"gift_watch":
			cam_dir = _build_gift_watch(root)
		"gift_wrench":
			cam_dir = _build_gift_wrench(root)
		"gift_cocoa":
			cam_dir = _build_gift_cocoa(root)
		"gift_chart":
			cam_dir = _build_gift_chart(root)
		"gift_flask":
			cam_dir = _build_gift_flask(root)
		"arch_duty_log":
			cam_dir = _build_archive_clipboard(root, Color(0.28, 0.34, 0.25), Color(0.86, 0.72, 0.22), "LOG")
		"arch_shift_log":
			cam_dir = _build_archive_clipboard(root, Color(0.32, 0.29, 0.24), Color(0.76, 0.44, 0.22), "SHIFT")
		"arch_manifest":
			cam_dir = _build_archive_clipboard(root, Color(0.24, 0.31, 0.36), Color(0.32, 0.72, 0.86), "CARGO")
		"arch_research_note":
			cam_dir = _build_archive_binder(root, Color(0.22, 0.32, 0.30), Color(0.34, 0.88, 0.74), true)
		"arch_observation":
			cam_dir = _build_archive_binder(root, Color(0.20, 0.28, 0.38), Color(0.30, 0.74, 0.96), true)
		"arch_deep_record":
			cam_dir = _build_archive_binder(root, Color(0.24, 0.20, 0.28), Color(0.86, 0.44, 0.94), false)
		"arch_flight_log":
			cam_dir = _build_archive_flight_log(root)
		"arch_blueprint":
			cam_dir = _build_archive_blueprint(root)
		"arch_tape":
			cam_dir = _build_archive_tape(root)
		"arch_photo":
			cam_dir = _build_archive_photo(root)
		"arch_letter":
			cam_dir = _build_archive_letter(root)
		"arch_child_drawing":
			cam_dir = _build_archive_drawing(root)
		_:
			# 通用防震物资箱（未知拓展 ID 回退）
			K.bb(root, Vector3(0.8, 0.56, 0.65), K.armor(Color(0.34, 0.38, 0.32)), Vector3.ZERO, Vector3.ZERO, 0.04)
			K.bb(root, Vector3(0.84, 0.12, 0.69), K.gunmetal(), Vector3(0, 0.22, 0), Vector3.ZERO, 0.02)
			K.bb(root, Vector3(0.42, 0.06, 0.71), K.accent(), Vector3(0, 0.08, 0), Vector3.ZERO, 0.01)

	root.set_meta("cam_dir", cam_dir)
	return root


# ================================================================ 食物类
static func _build_can_food(root: Node3D) -> Vector3:
	var M_TIN := A.paint(Color(0.36, 0.40, 0.32), 0.58, 0.40, {"wear": 0.35, "panel_scale": 0.0})
	var M_LBL := A.paint(Color(0.78, 0.66, 0.38), 0.08, 0.66, {"wear": 0.26, "panel_scale": 0.0})
	var M_BAND := A.paint(Color(0.70, 0.20, 0.15), 0.10, 0.58, {"wear": 0.22, "panel_scale": 0.0})
	var M_INK := A.paint(Color(0.16, 0.14, 0.12), 0.05, 0.72, {"panel_scale": 0.0})
	var M_RIM := A.chrome()
	# 32 段军用马口铁口粮罐 + 双压筋防瘪环 + 卷边盖 + 刻痕圈 + 精雕易拉环
	K.cy(root, 0.34, 0.52, M_TIN, Vector3.ZERO, Vector3.ZERO, -1.0, 32)
	K.cy(root, 0.346, 0.31, M_LBL, Vector3(0, -0.015, 0), Vector3.ZERO, -1.0, 32)
	K.cy(root, 0.349, 0.068, M_BAND, Vector3(0, 0.075, 0), Vector3.ZERO, -1.0, 32)
	K.cy(root, 0.348, 0.022, M_INK, Vector3(0, -0.095, 0), Vector3.ZERO, -1.0, 32)
	for sy in [-0.26, 0.26]:
		A.add(root, A.torus(0.312, 0.358, 32), M_RIM, Vector3(0, sy, 0), Vector3.ZERO, Vector3(1, 0.62, 1), false)
	for ry in [-0.195, 0.175]:
		A.add(root, A.torus(0.326, 0.354, 32), M_TIN, Vector3(0, ry, 0), Vector3.ZERO, Vector3(1, 0.48, 1), false)
	# 罐盖同心压纹与易拉环铆钉扣
	K.cy(root, 0.322, 0.02, M_RIM, Vector3(0, 0.256, 0), Vector3.ZERO, -1.0, 32)
	A.add(root, A.torus(0.245, 0.262, 28), M_TIN, Vector3(0, 0.267, 0), Vector3.ZERO, Vector3(1, 0.35, 1), false)
	A.add(root, A.torus(0.145, 0.160, 24), M_TIN, Vector3(0, 0.267, 0), Vector3.ZERO, Vector3(1, 0.35, 1), false)
	K.cy(root, 0.026, 0.028, M_RIM, Vector3(0.06, 0.278, 0.08), Vector3.ZERO, -1.0, 20)
	A.add(root, A.torus(0.044, 0.068, 24), M_RIM, Vector3(0.115, 0.285, 0.135), Vector3(10, 0, -6), Vector3(1, 0.42, 1), false)
	A.stencil(root, "RATION", Vector3(0.145, 0.055, 0.322), Vector3(0, 24, 0), 0.0024, Color(0.14, 0.12, 0.10, 0.94))
	return Vector3(0.60, 0.65, 0.85).normalized()


static func _build_biscuit(root: Node3D) -> Vector3:
	var M_FOIL := A.paint(Color(0.34, 0.39, 0.28), 0.42, 0.46, {"wear": 0.30, "panel_scale": 0.0})
	var M_SEAL := A.paint(Color(0.23, 0.26, 0.20), 0.48, 0.44, {"panel_scale": 0.0})
	var M_YEL := A.paint(Color(0.88, 0.68, 0.16), 0.08, 0.56, {"panel_scale": 0.0})
	var M_CRUMB := A.paint(Color(0.78, 0.61, 0.36), 0.0, 0.88, {"panel_scale": 0.0})
	var M_BAKE := A.paint(Color(0.60, 0.42, 0.22), 0.0, 0.90, {"panel_scale": 0.0})
	var wrap := K.node(root, Vector3.ZERO, Vector3(10, -24, 14))
	# 真空军用铝箔口粮袋（带压齿热封折边 + 撕口 + 警示标签带）+ 露出两块麦芽压花压缩饼干
	K.bb(wrap, Vector3(0.76, 0.18, 0.54), M_FOIL, Vector3(0, -0.05, 0), Vector3.ZERO, 0.038)
	for sx in [-0.415, 0.415]:
		K.bb(wrap, Vector3(0.08, 0.024, 0.52), M_SEAL, Vector3(sx, -0.05, 0), Vector3.ZERO, 0.005)
		for ri in 6:
			K.bb(wrap, Vector3(0.065, 0.032, 0.024), M_FOIL, Vector3(sx, -0.05, -0.20 + float(ri) * 0.08), Vector3.ZERO, 0.003)
	K.bb(wrap, Vector3(0.58, 0.192, 0.115), M_YEL, Vector3(0.04, -0.045, 0.12), Vector3.ZERO, 0.012)
	K.bb(wrap, Vector3(0.42, 0.194, 0.035), M_SEAL, Vector3(0.04, -0.045, 0.12), Vector3.ZERO, 0.004)
	# 上层叠放露出的烤色压孔压缩饼干（两块错叠）
	var bis1 := K.node(wrap, Vector3(-0.08, 0.12, -0.06), Vector3(4, 16, -6))
	K.bb(bis1, Vector3(0.46, 0.11, 0.38), M_CRUMB, Vector3.ZERO, Vector3.ZERO, 0.026)
	K.bb(bis1, Vector3(0.42, 0.016, 0.018), M_BAKE, Vector3(0, 0.055, 0), Vector3.ZERO, 0.003)
	K.bb(bis1, Vector3(0.018, 0.016, 0.34), M_BAKE, Vector3(0, 0.055, 0), Vector3.ZERO, 0.003)
	for dx in [-0.14, 0.0, 0.14]:
		for dz in [-0.10, 0.0, 0.10]:
			K.cy(bis1, 0.014, 0.022, M_BAKE, Vector3(dx, 0.052, dz), Vector3.ZERO, -1.0, 16)
	K.bb(wrap, Vector3(0.38, 0.085, 0.30), M_BAKE, Vector3(0.18, 0.08, 0.14), Vector3(-5, -18, 8), 0.022)
	return Vector3(0.50, 0.85, 0.72).normalized()


static func _build_water_tab(root: Node3D) -> Vector3:
	var M_CARD := A.paint(Color(0.86, 0.88, 0.90), 0.14, 0.40, {"panel_scale": 0.0})
	var M_BLUE := A.paint(Color(0.16, 0.54, 0.82), 0.12, 0.42, {"panel_scale": 0.0})
	var M_FOIL := A.chrome()
	var M_BLISTER := A.paint(Color(0.32, 0.80, 0.96), 0.12, 0.14, {"panel_scale": 0.0})
	var M_VIAL := A.glass(Color(0.28, 0.68, 0.92))
	var b := K.node(root, Vector3.ZERO, Vector3(12, -22, 16))
	# 铝箔药板（8 粒 22 段净水片泡罩 + 撕痕中线 + 医疗蓝边条）
	K.bb(b, Vector3(0.76, 0.028, 0.50), M_FOIL, Vector3(-0.05, 0.0, 0.04), Vector3.ZERO, 0.01)
	K.bb(b, Vector3(0.72, 0.020, 0.46), M_CARD, Vector3(-0.05, 0.020, 0.04), Vector3.ZERO, 0.008)
	K.bb(b, Vector3(0.70, 0.022, 0.045), M_BLUE, Vector3(-0.05, 0.024, 0.22), Vector3.ZERO, 0.004)
	K.bb(b, Vector3(0.014, 0.024, 0.44), M_FOIL, Vector3(-0.05, 0.024, 0.04), Vector3.ZERO, 0.002)
	for ix in 4:
		for iz in 2:
			var px := -0.28 + float(ix) * 0.15
			var pz := -0.07 + float(iz) * 0.19
			A.add(b, A.torus(0.046, 0.058, 20), M_FOIL, Vector3(px, 0.032, pz), Vector3.ZERO, Vector3(1, 0.45, 1), false)
			A.add(b, A.sphere(0.050, 0.076, 22), M_BLISTER, Vector3(px, 0.048, pz), Vector3.ZERO, Vector3.ONE, false)
	# 侧面立起玻璃净水滴剂瓶（带防滑竖纹瓶盖 + 液面刻度条）
	var v := K.node(b, Vector3(0.26, 0.16, -0.18), Vector3(8, 0, -10))
	K.cy(v, 0.132, 0.36, M_VIAL, Vector3.ZERO, Vector3.ZERO, -1.0, 24)
	K.cy(v, 0.102, 0.25, A.emit(Color(0.28, 0.84, 0.99), 0.72), Vector3(0, -0.025, 0), Vector3.ZERO, -1.0, 24)
	K.cy(v, 0.135, 0.10, M_BLUE, Vector3(0, -0.04, 0), Vector3.ZERO, -1.0, 24)
	K.cy(v, 0.088, 0.06, M_VIAL, Vector3(0, 0.19, 0), Vector3.ZERO, 0.115, 24)
	K.cy(v, 0.112, 0.095, M_CARD, Vector3(0, 0.24, 0), Vector3.ZERO, -1.0, 24)
	for gi in 8:
		var ga := TAU * float(gi) / 8.0
		K.bb(v, Vector3(0.016, 0.082, 0.016), M_BLUE, Vector3(cos(ga) * 0.112, 0.24, sin(ga) * 0.112), Vector3(0, -rad_to_deg(ga), 0), 0.003)
	return Vector3(0.50, 0.85, 0.72).normalized()


static func _build_coffee(root: Node3D) -> Vector3:
	var M_BAG := A.paint(Color(0.28, 0.18, 0.12), 0.14, 0.62, {"wear": 0.24, "panel_scale": 0.0})
	var M_GUS := A.paint(Color(0.20, 0.13, 0.08), 0.10, 0.68, {"panel_scale": 0.0})
	var M_FOIL := K.brass()
	var M_LBL := A.paint(Color(0.88, 0.80, 0.64), 0.04, 0.72, {"panel_scale": 0.0})
	var M_BEAN := A.paint(Color(0.17, 0.09, 0.05), 0.10, 0.38, {"panel_scale": 0.0})
	var M_CLEFT := A.paint(Color(0.06, 0.03, 0.02), 0.0, 0.85, {"panel_scale": 0.0})
	# 真空铝箔折角咖啡豆袋 + 顶部卷口与铜封条 + 单向排气阀 + 徽标贴纸 + 三粒带中缝烘焙咖啡豆
	var bag := K.node(root, Vector3(-0.04, 0.02, 0), Vector3(0, 12, 0))
	K.bb(bag, Vector3(0.56, 0.68, 0.32), M_BAG, Vector3.ZERO, Vector3.ZERO, 0.045, 0.90)
	for sx in [-0.275, 0.275]:
		K.bb(bag, Vector3(0.03, 0.62, 0.22), M_GUS, Vector3(sx, -0.02, 0), Vector3.ZERO, 0.01)
	K.bb(bag, Vector3(0.54, 0.095, 0.11), M_FOIL, Vector3(0, 0.365, 0), Vector3.ZERO, 0.018)
	K.bb(bag, Vector3(0.60, 0.032, 0.125), K.copper(), Vector3(0, 0.365, 0), Vector3.ZERO, 0.008)
	K.bb(bag, Vector3(0.42, 0.34, 0.336), M_LBL, Vector3(0, -0.02, 0), Vector3.ZERO, 0.012)
	K.cy(bag, 0.105, 0.346, M_FOIL, Vector3(0, 0.02, 0), Vector3(90, 0, 0), -1.0, 24)
	K.cy(bag, 0.072, 0.352, M_BAG, Vector3(0, 0.02, 0), Vector3(90, 0, 0), -1.0, 24)
	# 单向透气阀圆纽
	K.cy(bag, 0.032, 0.025, K.brass(), Vector3(0.14, 0.22, 0.165), Vector3(90, 0, 0), -1.0, 18)
	# 散落烘焙咖啡豆（20 段椭圆豆体 + 深色中缝）
	for b_spec in [
		[Vector3(0.26, -0.26, 0.24), Vector3(16, 42, 12)],
		[Vector3(0.37, -0.27, 0.11), Vector3(12, -28, 18)],
		[Vector3(0.16, -0.27, 0.33), Vector3(22, 74, -10)],
	]:
		var bn := K.node(root, b_spec[0], b_spec[1])
		A.add(bn, A.sphere(0.064, 0.088, 20), M_BEAN, Vector3.ZERO, Vector3.ZERO, Vector3(1.22, 0.72, 0.92), false)
		K.bb(bn, Vector3(0.135, 0.014, 0.014), M_CLEFT, Vector3(0, 0.032, 0), Vector3.ZERO, 0.003)
	return Vector3(0.56, 0.56, 0.85).normalized()


# ================================================================ 杂物材料类
static func _build_circuit(root: Node3D) -> Vector3:
	var M_PCB := A.paint(Color(0.09, 0.37, 0.22), 0.14, 0.34, {"panel_scale": 0.0})
	var M_IC := A.metal(Color(0.09, 0.10, 0.11))
	var M_GOLD := K.brass()
	var M_ALU := A.chrome()
	var M_COP := K.copper()
	var M_LED := A.emit(Color(0.26, 0.95, 0.45), 1.8)
	var b := K.node(root, Vector3.ZERO, Vector3(24, -22, 16))
	# 多层印制电路板 + 金手指 + 四角安装铜环 + 带引脚 QFP 主控芯片 + 3 颗电解电容 + 环形铜电感 + LED
	K.bb(b, Vector3(0.86, 0.052, 0.68), M_PCB, Vector3.ZERO, Vector3.ZERO, 0.012)
	for cx_h in [-0.37, 0.37]:
		for cz_h in [-0.28, 0.22]:
			A.add(b, A.torus(0.018, 0.036, 18), M_GOLD, Vector3(cx_h, 0.026, cz_h), Vector3.ZERO, Vector3(1, 0.5, 1), false)
	for i in 10:
		K.bb(b, Vector3(0.044, 0.058, 0.092), M_GOLD, Vector3(-0.315 + float(i) * 0.07, 0.0, 0.33), Vector3.ZERO, 0.004)
	# 主控 IC 与四周镀锡引脚
	K.bb(b, Vector3(0.26, 0.072, 0.26), M_IC, Vector3(-0.06, 0.055, -0.04), Vector3.ZERO, 0.01)
	for pi in 5:
		var po := -0.09 + float(pi) * 0.045
		K.bb(b, Vector3(0.016, 0.025, 0.31), M_ALU, Vector3(-0.06 + po, 0.036, -0.04), Vector3.ZERO, 0.002)
		K.bb(b, Vector3(0.31, 0.025, 0.016), M_ALU, Vector3(-0.06, 0.036, -0.04 + po), Vector3.ZERO, 0.002)
	K.bb(b, Vector3(0.14, 0.08, 0.18), M_IC, Vector3(0.25, 0.06, -0.14), Vector3.ZERO, 0.01)
	# 金色铜箔走线 + 贴片电阻排
	K.bb(b, Vector3(0.54, 0.018, 0.024), M_GOLD, Vector3(-0.02, 0.032, 0.18), Vector3.ZERO, 0.003)
	K.bb(b, Vector3(0.024, 0.018, 0.38), M_GOLD, Vector3(0.13, 0.032, -0.02), Vector3.ZERO, 0.003)
	for ri in 3:
		K.bb(b, Vector3(0.055, 0.024, 0.028), M_COP, Vector3(-0.18 + float(ri) * 0.09, 0.038, 0.14), Vector3.ZERO, 0.004)
	# 三颗 20 段立式铝壳电解电容 + 24 段铜线环形电感 + 绿光诊断灯
	for c_pos in [Vector3(-0.30, 0.095, -0.18), Vector3(-0.30, 0.095, -0.04), Vector3(-0.22, 0.085, 0.08)]:
		K.cy(b, 0.048, 0.14, M_ALU, c_pos, Vector3.ZERO, -1.0, 20)
		K.cy(b, 0.046, 0.022, M_IC, c_pos + Vector3(0, 0.072, 0), Vector3.ZERO, -1.0, 20)
	A.add(b, A.torus(0.046, 0.098, 24), M_COP, Vector3(0.25, 0.082, 0.11), Vector3.ZERO, Vector3(1, 0.72, 1), false)
	A.add(b, A.sphere(0.028, 0.05, 18), M_LED, Vector3(0.32, 0.05, -0.24), Vector3.ZERO, Vector3.ONE, false)
	return Vector3(0.35, 0.86, 0.56).normalized()


static func _build_wire(root: Node3D) -> Vector3:
	var M_FLANGE := K.gunmetal()
	var M_COP := K.copper()
	var M_DARK := K.dark()
	var M_BR := K.brass()
	var s := K.node(root, Vector3.ZERO, Vector3(18, -28, 22))
	# 32 段工字钢绕线盘 + 轴孔铜衬套 + 9 圈紧密紫铜线匝 + 平滑弯曲引出铜线尾
	K.cy(s, 0.42, 0.052, M_FLANGE, Vector3(0, 0.25, 0), Vector3.ZERO, -1.0, 32)
	K.cy(s, 0.42, 0.052, M_FLANGE, Vector3(0, -0.25, 0), Vector3.ZERO, -1.0, 32)
	K.cy(s, 0.16, 0.54, M_DARK, Vector3.ZERO, Vector3.ZERO, -1.0, 24)
	K.cy(s, 0.095, 0.56, K.bore_mat(), Vector3.ZERO, Vector3.ZERO, -1.0, 20)
	A.add(s, A.torus(0.11, 0.155, 24), M_BR, Vector3(0, 0.278, 0), Vector3.ZERO, Vector3(1, 0.5, 1), false)
	for wi in 9:
		var wy := -0.20 + float(wi) * 0.05
		A.add(s, A.torus(0.19, 0.355, 28), M_COP, Vector3(0, wy, 0), Vector3.ZERO, Vector3(1, 0.38, 1), false)
	# 弯曲弹出的紫铜线尾（A.tube 平滑样条管）
	A.add(s, A.tube([
		Vector3(0.33, 0.08, 0.04),
		Vector3(0.42, 0.06, 0.22),
		Vector3(0.34, 0.12, 0.42),
		Vector3(0.16, 0.04, 0.52),
	], 0.026, 16, 10), M_COP, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	return Vector3(0.62, 0.62, 0.80).normalized()


static func _build_bolts(root: Node3D) -> Vector3:
	var M_ST := A.chrome()
	var M_DK := K.gunmetal()
	var M_BR := K.brass()
	# 两颗重型工业六角螺栓（显式 allow_poly=true 保持硬朗六角头）+ 垫圈 + 精细螺纹 + 两枚六角螺母
	var b1 := K.node(root, Vector3(-0.14, 0.06, 0.04), Vector3(18, 24, -36))
	A.add(b1, A.cyl(0.165, 0.105, 0.165, 6, true), M_ST, Vector3(0, 0.24, 0))
	K.cy(b1, 0.185, 0.024, M_BR, Vector3(0, 0.175, 0), Vector3.ZERO, -1.0, 24)
	K.cy(b1, 0.088, 0.46, M_DK, Vector3(0, -0.02, 0), Vector3.ZERO, -1.0, 22)
	for r_i in 6:
		A.add(b1, A.torus(0.076, 0.098, 22), M_ST, Vector3(0, -0.20 + float(r_i) * 0.052, 0), Vector3.ZERO, Vector3(1, 0.35, 1), false)
	var b2 := K.node(root, Vector3(0.20, -0.05, -0.10), Vector3(72, -16, 48))
	A.add(b2, A.cyl(0.155, 0.095, 0.155, 6, true), M_BR, Vector3(0, 0.22, 0))
	K.cy(b2, 0.172, 0.022, M_ST, Vector3(0, 0.162, 0), Vector3.ZERO, -1.0, 24)
	K.cy(b2, 0.082, 0.40, M_DK, Vector3(0, -0.01, 0), Vector3.ZERO, -1.0, 22)
	for r_j in 5:
		A.add(b2, A.torus(0.070, 0.092, 22), M_BR, Vector3(0, -0.16 + float(r_j) * 0.052, 0), Vector3.ZERO, Vector3(1, 0.35, 1), false)
	# 两枚硬朗六角螺母 + 20 段内螺纹通孔
	for np in [[Vector3(0.22, -0.18, 0.24), Vector3(24, 18, 12)], [Vector3(-0.24, -0.22, -0.18), Vector3(84, -24, 30)]]:
		A.add(root, A.cyl(0.138, 0.088, 0.138, 6, true), M_ST, np[0], np[1])
		K.cy(root, 0.068, 0.096, K.bore_mat(), np[0], np[1], -1.0, 20)
	return Vector3(0.58, 0.72, 0.78).normalized()


static func _build_hdd(root: Node3D) -> Vector3:
	var M_CASE := K.gunmetal()
	var M_DK := K.dark()
	var M_PLAT := A.chrome()
	var M_GOLD := K.brass()
	var M_COP := K.copper()
	var b := K.node(root, Vector3.ZERO, Vector3(22, -24, 12))
	# 工业级铸铝硬盘壳 + 6 颗梅花螺钉 + 36 段镜面双碟片 + 马达主轴 + 音圈磁铁与读写悬臂
	K.bb(b, Vector3(0.64, 0.14, 0.88), M_CASE, Vector3.ZERO, Vector3.ZERO, 0.024)
	K.bb(b, Vector3(0.56, 0.04, 0.78), M_DK, Vector3(0, 0.062, 0), Vector3.ZERO, 0.015)
	for sx in [-0.28, 0.28]:
		for sz in [-0.38, 0.0, 0.38]:
			K.cy(b, 0.020, 0.025, M_PLAT, Vector3(sx, 0.072, sz), Vector3.ZERO, -1.0, 16)
	# 双层镜面磁盘与主轴压盖
	K.cy(b, 0.255, 0.026, M_PLAT, Vector3(0, 0.086, -0.10), Vector3.ZERO, -1.0, 36)
	A.add(b, A.torus(0.240, 0.256, 36), M_GOLD, Vector3(0, 0.086, -0.10), Vector3.ZERO, Vector3(1, 0.45, 1), false)
	K.cy(b, 0.076, 0.046, M_CASE, Vector3(0, 0.098, -0.10), Vector3.ZERO, -1.0, 24)
	K.cy(b, 0.032, 0.052, M_PLAT, Vector3(0, 0.102, -0.10), Vector3.ZERO, -1.0, 20)
	# 音圈马达轴承 + 铜绕组 + 锥形磁头读写臂 + SATA 金手指接口
	K.cy(b, 0.082, 0.055, M_GOLD, Vector3(0.18, 0.098, 0.24), Vector3.ZERO, -1.0, 24)
	K.bb(b, Vector3(0.14, 0.042, 0.12), M_COP, Vector3(0.22, 0.092, 0.33), Vector3(0, -18, 0), 0.01)
	K.bb(b, Vector3(0.058, 0.022, 0.34), M_PLAT, Vector3(0.08, 0.118, 0.08), Vector3(0, 28, 0), 0.004, 0.45)
	K.bb(b, Vector3(0.36, 0.032, 0.08), M_GOLD, Vector3(-0.04, 0.02, 0.44), Vector3.ZERO, 0.005)
	return Vector3(0.45, 0.85, 0.62).normalized()


static func _build_toy(root: Node3D) -> Vector3:
	var M_GRN := A.paint(Color(0.22, 0.62, 0.25), 0.28, 0.32, {"wear": 0.22, "panel_scale": 0.0})
	var M_YEL := A.paint(Color(0.94, 0.78, 0.22), 0.16, 0.36, {"panel_scale": 0.0})
	var M_RED := A.paint(Color(0.84, 0.20, 0.16), 0.18, 0.36, {"panel_scale": 0.0})
	var M_WHT := A.paint(Color(0.95, 0.95, 0.93), 0.05, 0.26, {"panel_scale": 0.0})
	var M_BR := K.brass()
	var M_BLK := K.bore_mat()
	var f := K.node(root, Vector3.ZERO, Vector3(0, 24, 0))
	# 32 段复古铁皮发条小青蛙：烤漆铁皮背脊 + 鹅黄肚皮 + 红唇 + 大鼓眼（带高光点）+ 蹼足 + 黄铜蝴蝶发条
	A.add(f, A.sphere(0.28, 0.42, 32), M_GRN, Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1.15, 0.78, 1.32), false)
	A.add(f, A.sphere(0.24, 0.30, 24), M_YEL, Vector3(0, -0.075, 0.06), Vector3.ZERO, Vector3(1.06, 0.66, 1.15), false)
	A.add(f, A.torus(0.14, 0.165, 24), M_RED, Vector3(0, -0.03, 0.24), Vector3(14, 0, 0), Vector3(1.0, 0.38, 0.75), false)
	for sx in [-1.0, 1.0]:
		A.add(f, A.sphere(0.102, 0.20, 24), M_GRN, Vector3(sx * 0.17, 0.18, 0.20), Vector3.ZERO, Vector3.ONE, false)
		A.add(f, A.sphere(0.074, 0.145, 20), M_WHT, Vector3(sx * 0.17, 0.19, 0.24), Vector3.ZERO, Vector3.ONE, false)
		A.add(f, A.sphere(0.038, 0.074, 18), M_BLK, Vector3(sx * 0.17, 0.195, 0.285), Vector3.ZERO, Vector3.ONE, false)
		A.add(f, A.sphere(0.012, 0.024, 16), M_WHT, Vector3(sx * 0.155, 0.215, 0.312), Vector3.ZERO, Vector3.ONE, false)
		# 铁皮折叠后腿 + 橘红脚蹼
		K.bb(f, Vector3(0.11, 0.10, 0.28), M_GRN, Vector3(sx * 0.27, -0.08, -0.10), Vector3(0, sx * 16.0, 0), 0.028)
		K.bb(f, Vector3(0.14, 0.035, 0.16), M_RED, Vector3(sx * 0.31, -0.14, 0.06), Vector3(0, sx * 24.0, 0), 0.012)
	# 右侧高精黄铜蝴蝶发条钥匙
	K.cy(f, 0.032, 0.22, M_BR, Vector3(0.32, 0.04, -0.02), Vector3(0, 0, 90), -1.0, 20)
	K.cy(f, 0.056, 0.024, M_BR, Vector3(0.28, 0.04, -0.02), Vector3(0, 0, 90), -1.0, 20)
	for ky in [-0.078, 0.078]:
		A.add(f, A.torus(0.042, 0.088, 24), M_BR, Vector3(0.45, 0.04 + ky, -0.02), Vector3(0, 0, 90), Vector3(1, 0.44, 1), false)
	return Vector3(0.68, 0.56, 0.80).normalized()


static func _build_chitin(root: Node3D) -> Vector3:
	var M_SH := A.chitin(Color(0.35, 0.21, 0.31))
	var M_EDGE := A.chitin(Color(0.21, 0.13, 0.20))
	var M_MEM := A.paint(Color(0.48, 0.30, 0.34), 0.22, 0.42, {"panel_scale": 0.0})
	var c := K.node(root, Vector3.ZERO, Vector3(12, -20, 8))
	# 三层叠瓦式弧形几丁质甲壳 + 锯齿背棘 + 甲缘骨刺 + 内侧角质膜边
	for i in 3:
		var z := -0.19 + float(i) * 0.19
		var y := -float(i) * 0.038
		var sc := 1.0 - float(i) * 0.13
		K.plate(c, K.trap(0.58 * sc, 0.74 * sc, 0.32 * sc, 0.06), 0.105, M_SH if i % 2 == 0 else M_EDGE,
			Vector3(0, y, z), Vector3(-62.0 + float(i) * 7.0, 0, 0), 0.032)
		K.bb(c, Vector3(0.075 * sc, 0.11 * sc, 0.14 * sc), M_EDGE, Vector3(0, y + 0.11, z - 0.02), Vector3(-28, 0, 0), 0.018, 0.45)
		for sx in [-1.0, 1.0]:
			K.bb(c, Vector3(0.06 * sc, 0.04 * sc, 0.14 * sc), M_MEM, Vector3(sx * 0.33 * sc, y + 0.01, z + 0.04), Vector3(0, sx * 22.0, -sx * 16.0), 0.012, 0.4)
	K.bb(c, Vector3(0.11, 0.11, 0.62), M_EDGE, Vector3(0, 0.07, 0.0), Vector3(-10, 0, 0), 0.032)
	return Vector3(0.68, 0.72, 0.66).normalized()


static func _build_bug_crystal(root: Node3D) -> Vector3:
	# 精修天然多面深渊压电晶簇：复刻 lm_crystal_survey_rig 微倒角多面晶柱 + 紫青折射着色器 + 玄武岩母岩
	var M_ROCK := A.rock_mat(Color(0.14, 0.13, 0.17))
	var M_CRY := _bug_crystal_mat()
	A.add(root, A.rock_mesh(2, 24), M_ROCK, Vector3(0, -0.24, 0), Vector3.ZERO, Vector3(0.44, 0.21, 0.40))
	A.add(root, A.rock_mesh(6, 20), M_ROCK, Vector3(-0.14, -0.22, 0.14), Vector3(8, 42, -10), Vector3(0.24, 0.16, 0.22))
	var specs := [
		# [pos, rot_deg, rad, height, sides, energy, seed, fractured, stepped]
		[Vector3(0.00, -0.20, 0.00), Vector3(5, 14, -4), 0.135, 0.68, 6, 0.96, 101, false, true],
		[Vector3(-0.17, -0.20, 0.08), Vector3(16, -24, 24), 0.095, 0.50, 6, 0.85, 202, false, false],
		[Vector3(0.17, -0.20, -0.05), Vector3(-14, 32, -22), 0.105, 0.56, 7, 0.92, 303, false, true],
		[Vector3(-0.08, -0.21, -0.15), Vector3(-24, 6, 14), 0.088, 0.44, 6, 0.78, 404, true, false],
		[Vector3(0.12, -0.21, 0.15), Vector3(24, 18, -16), 0.080, 0.42, 5, 0.82, 505, false, false],
		[Vector3(-0.22, -0.22, -0.08), Vector3(-18, -40, 32), 0.068, 0.34, 6, 0.70, 606, true, false],
		[Vector3(0.04, -0.22, 0.21), Vector3(32, -8, -8), 0.062, 0.30, 5, 0.75, 707, false, false],
	]
	for sp in specs:
		var mesh: ArrayMesh = CrystalRig._crystal_shard_mesh(sp[2], sp[3], sp[4], sp[5], sp[6], sp[7], sp[8])
		A.add(root, mesh, M_CRY, sp[0], sp[1])
	return Vector3(0.65, 0.46, 0.82).normalized()


# ================================================================ 消耗品/战术道具类
static func _build_fuel_cell(root: Node3D) -> Vector3:
	var M_BODY := A.paint(Color(0.84, 0.58, 0.12), 0.26, 0.44, {"wear": 0.40, "panel_scale": 0.0})
	var M_CAP := K.gunmetal()
	var M_BR := K.brass()
	var M_GLOW := A.emit(Color(0.24, 0.90, 0.99), 1.70)
	# 军规黄黑工业能源卡匣：护框 + 散热肋条 + 双黄铜端子胶套 + 提手 + 5 格等离子电量窗
	K.bb(root, Vector3(0.54, 0.64, 0.38), M_BODY, Vector3.ZERO, Vector3.ZERO, 0.035)
	K.bb(root, Vector3(0.58, 0.13, 0.42), M_CAP, Vector3(0, -0.27, 0), Vector3.ZERO, 0.02)
	K.bb(root, Vector3(0.58, 0.12, 0.42), M_CAP, Vector3(0, 0.27, 0), Vector3.ZERO, 0.02)
	for fi in 4:
		K.bb(root, Vector3(0.57, 0.024, 0.32), M_CAP, Vector3(0, -0.14 + float(fi) * 0.09, 0), Vector3.ZERO, 0.005)
	for sx in [-0.14, 0.14]:
		K.cy(root, 0.054, 0.105, M_BR, Vector3(sx, 0.37, 0), Vector3.ZERO, -1.0, 22)
		A.add(root, A.torus(0.050, 0.068, 20), K.dark(), Vector3(sx, 0.335, 0), Vector3.ZERO, Vector3(1, 0.5, 1), false)
	A.add(root, A.tube([Vector3(-0.18, 0.32, -0.12), Vector3(-0.18, 0.44, -0.12), Vector3(0.18, 0.44, -0.12), Vector3(0.18, 0.32, -0.12)], 0.020, 14, 6), M_CAP, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	K.bb(root, Vector3(0.15, 0.40, 0.032), K.bore_mat(), Vector3(0.12, 0, 0.19), Vector3.ZERO, 0.005)
	for gi in 5:
		K.bb(root, Vector3(0.095, 0.052, 0.022), M_GLOW, Vector3(0.12, -0.14 + float(gi) * 0.07, 0.202), Vector3.ZERO, 0.003)
	K.bb(root, Vector3(0.20, 0.065, 0.02), K.dark(), Vector3(-0.10, 0.11, 0.195), Vector3.ZERO, 0.004)
	A.stencil(root, "CELL", Vector3(-0.075, -0.055, 0.198), Vector3.ZERO, 0.0020, Color(0.14, 0.12, 0.10, 0.92))
	return Vector3(0.68, 0.45, 0.82).normalized()


static func _build_repair_kit(root: Node3D) -> Vector3:
	var M_BOX := A.paint(Color(0.26, 0.35, 0.25), 0.18, 0.54, {"wear": 0.38, "panel_scale": 0.0})
	var M_LID := A.paint(Color(0.86, 0.88, 0.86), 0.12, 0.40, {"panel_scale": 0.0})
	var M_RED := A.paint(Color(0.84, 0.18, 0.16), 0.08, 0.46, {"panel_scale": 0.0})
	var M_DK := K.dark()
	var M_BR := K.brass()
	# 装甲野战维修急救盒 + 四角橡胶防撞护角 + 铬钢搭扣 + 提手 + 纳米焊胶喷雾罐
	K.bb(root, Vector3(0.74, 0.52, 0.44), M_BOX, Vector3(-0.04, -0.02, 0), Vector3.ZERO, 0.04)
	for sx in [-0.39, 0.31]:
		for sy in [-0.26, 0.22]:
			K.bb(root, Vector3(0.08, 0.09, 0.47), M_DK, Vector3(sx, sy, 0), Vector3.ZERO, 0.015)
	K.bb(root, Vector3(0.56, 0.34, 0.04), M_LID, Vector3(-0.04, 0.0, 0.22), Vector3.ZERO, 0.012)
	K.bb(root, Vector3(0.22, 0.07, 0.022), M_RED, Vector3(-0.04, 0.0, 0.242), Vector3.ZERO, 0.004)
	K.bb(root, Vector3(0.07, 0.22, 0.022), M_RED, Vector3(-0.04, 0.0, 0.242), Vector3.ZERO, 0.004)
	K.grab_iron(root, 0.28, 0.068, Vector3(-0.04, 0.25, 0), Vector3(-90, 0, 0), 0.022)
	for lx in [-0.24, 0.16]:
		K.bb(root, Vector3(0.065, 0.11, 0.045), A.chrome(), Vector3(lx, 0.17, 0.22), Vector3.ZERO, 0.006)
	# 24 段压力纳米修复喷罐 + 黄铜阀头 + 细喷嘴
	K.cy(root, 0.082, 0.25, M_DK, Vector3(0.37, -0.11, 0.16), Vector3.ZERO, -1.0, 24)
	K.cy(root, 0.084, 0.065, M_RED, Vector3(0.37, -0.10, 0.16), Vector3.ZERO, -1.0, 24)
	K.cy(root, 0.055, 0.055, M_BR, Vector3(0.37, 0.04, 0.16), Vector3.ZERO, 0.080, 20)
	K.cy(root, 0.026, 0.048, A.chrome(), Vector3(0.37, 0.085, 0.16), Vector3.ZERO, -1.0, 18)
	return Vector3(0.56, 0.50, 0.88).normalized()


static func _build_beacon(root: Node3D) -> Vector3:
	var M_BODY := K.armor(Color(0.28, 0.31, 0.35))
	var M_YEL := K.accent()
	var M_GLOW := A.emit(Color(0.30, 0.94, 0.98), 2.1)
	var M_ANT := A.chrome()
	# 军规高频撤离呼叫信标：24 段阶梯底座 + 折叠三脚架 + 护笼高亮频闪灯 + 弹簧座鞭状天线
	K.cy(root, 0.24, 0.14, M_BODY, Vector3(0, -0.14, 0), Vector3.ZERO, 0.28, 24)
	K.cy(root, 0.18, 0.20, M_YEL, Vector3(0, 0.02, 0), Vector3.ZERO, 0.16, 24)
	A.add(root, A.torus(0.16, 0.195, 24), K.dark(), Vector3(0, 0.11, 0), Vector3.ZERO, Vector3(1, 0.55, 1), false)
	A.add(root, A.sphere(0.112, 0.17, 24), M_GLOW, Vector3(0, 0.17, 0), Vector3.ZERO, Vector3.ONE, false)
	# 灯罩三根防撞钢护弓 + 折叠三脚支腿
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.4
		var ca := cos(a)
		var sa := sin(a)
		K.bb(root, Vector3(0.06, 0.28, 0.08), K.gunmetal(), Vector3(ca * 0.26, -0.24, sa * 0.26), Vector3(sa * 28.0, -rad_to_deg(a), 0), 0.012)
		A.add(root, A.tube([
			Vector3(ca * 0.15, 0.11, sa * 0.15),
			Vector3(ca * 0.13, 0.27, sa * 0.13),
			Vector3(0.0, 0.30, 0.0),
		], 0.014, 14, 6), K.gunmetal(), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	# 弹簧基座 + 16 段鞭状天线与顶珠
	K.cy(root, 0.032, 0.055, K.dark(), Vector3(0.14, 0.04, -0.06), Vector3(0, 0, -6), -1.0, 16)
	K.cy(root, 0.015, 0.46, M_ANT, Vector3(0.16, 0.26, -0.06), Vector3(0, 0, -6), 0.018, 16)
	A.add(root, A.sphere(0.026, 0.052, 16), M_YEL, Vector3(0.185, 0.49, -0.06), Vector3.ZERO, Vector3.ONE, false)
	return Vector3(0.62, 0.48, 0.85).normalized()


static func _build_sonic_decoy(root: Node3D) -> Vector3:
	var M_MET := K.gunmetal()
	var M_HORN := A.metal(Color(0.32, 0.36, 0.33))
	var M_LURE := A.emit(Color(1.0, 0.72, 0.22), 2.1)
	var M_COP := K.copper()
	# 三脚声波诱饵发射器 + 28 段多阶扩散号筒 + 发光声波导波环 + 诱饵脉冲球天线
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.5
		K.bb(root, Vector3(0.055, 0.44, 0.055), M_MET, Vector3(cos(a) * 0.16, -0.16, sin(a) * 0.16), Vector3(sin(a) * 20.0, 0, -cos(a) * 20.0), 0.012)
	K.cy(root, 0.11, 0.14, K.dark(), Vector3(0, -0.06, 0), Vector3.ZERO, -1.0, 22)
	K.cy(root, 0.135, 0.16, M_MET, Vector3(0, 0.06, 0), Vector3.ZERO, 0.18, 24)
	K.cy(root, 0.27, 0.095, M_HORN, Vector3(0, 0.18, 0), Vector3.ZERO, 0.21, 28)
	A.add(root, A.torus(0.15, 0.19, 24), M_LURE, Vector3(0, 0.23, 0), Vector3.ZERO, Vector3(1, 0.45, 1), false)
	K.cy(root, 0.075, 0.09, M_COP, Vector3(0, 0.22, 0), Vector3.ZERO, 0.11, 20)
	K.cy(root, 0.016, 0.36, M_MET, Vector3(0.14, 0.34, 0), Vector3.ZERO, -1.0, 16)
	A.add(root, A.sphere(0.058, 0.116, 22), M_LURE, Vector3(0.14, 0.52, 0), Vector3.ZERO, Vector3.ONE, false)
	return Vector3(0.65, 0.48, 0.82).normalized()


static func _build_extract_flare(root: Node3D) -> Vector3:
	var M_CAN := A.paint(Color(0.28, 0.35, 0.24), 0.24, 0.48, {"wear": 0.36, "panel_scale": 0.0})
	var M_BAND := A.paint(Color(0.94, 0.36, 0.10), 0.12, 0.44, {"panel_scale": 0.0})
	var M_SPOON := K.gunmetal()
	var M_TOP := A.emit(Color(1.0, 0.44, 0.12), 1.75)
	var f := K.node(root, Vector3.ZERO, Vector3(12, 18, -18))
	# 32 段军用发烟信号手雷罐 + 防滑压筋 + 橙色识别带 + 撞针引信 + 弯曲保险握片 + 铬钢拉环
	K.cy(f, 0.21, 0.58, M_CAN, Vector3.ZERO, Vector3.ZERO, -1.0, 32)
	K.cy(f, 0.216, 0.16, M_BAND, Vector3(0, 0.08, 0), Vector3.ZERO, -1.0, 32)
	for gy in [-0.20, -0.10, 0.22]:
		A.add(f, A.torus(0.195, 0.222, 28), M_CAN, Vector3(0, gy, 0), Vector3.ZERO, Vector3(1, 0.45, 1), false)
	K.cy(f, 0.14, 0.105, M_SPOON, Vector3(0, 0.335, 0), Vector3.ZERO, 0.165, 24)
	K.cy(f, 0.072, 0.042, M_TOP, Vector3(0, 0.39, 0), Vector3.ZERO, -1.0, 20)
	# 弯曲保险握柄（A.tube + 铰接轴）+ 24 段拉环
	A.add(f, A.tube([
		Vector3(0.11, 0.36, 0),
		Vector3(0.24, 0.34, 0),
		Vector3(0.25, 0.14, 0),
		Vector3(0.27, -0.06, 0),
	], 0.028, 14, 8), M_SPOON, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	K.cy(f, 0.022, 0.09, K.brass(), Vector3(-0.08, 0.35, 0), Vector3(0, 0, 90), -1.0, 16)
	A.add(f, A.torus(0.056, 0.084, 24), A.chrome(), Vector3(-0.16, 0.34, 0.05), Vector3(25, 0, 25), Vector3(1, 0.38, 1), false)
	A.stencil(f, "SMOKE", Vector3(0.068, 0.08, 0.210), Vector3(0, 18, 0), 0.0019, Color(0.12, 0.10, 0.08, 0.92))
	return Vector3(0.55, 0.45, 0.85).normalized()


static func _build_energy_rod(root: Node3D) -> Vector3:
	var M_DK := K.dark()
	var M_COP := K.copper()
	var M_GLOW := A.emit(Color(0.24, 0.88, 1.0), 1.85)
	var M_GLS := A.glass(Color(0.35, 0.85, 0.98))
	var r := K.node(root, Vector3.ZERO, Vector3(18, -22, 34))
	# 超导高压电容棒：发光等离子芯 + 透视玻璃约束管 + 5 匝紫铜线圈 + 三向保护钢肋 + 显式六角封头
	K.cy(r, 0.115, 0.68, M_GLOW, Vector3.ZERO, Vector3.ZERO, -1.0, 28)
	K.cy(r, 0.145, 0.64, M_GLS, Vector3.ZERO, Vector3.ZERO, -1.0, 28)
	for cy_y in [-0.36, 0.36]:
		A.add(r, A.cyl(0.205, 0.125, 0.205, 6, true), M_DK, Vector3(0, cy_y, 0))
		K.cy(r, 0.142, 0.055, K.brass(), Vector3(0, cy_y + signf(cy_y) * 0.075, 0), Vector3.ZERO, -1.0, 22)
		K.cy(r, 0.062, 0.065, A.chrome(), Vector3(0, cy_y + signf(cy_y) * 0.115, 0), Vector3.ZERO, -1.0, 20)
	for ci in [-0.20, -0.10, 0.0, 0.10, 0.20]:
		A.add(r, A.torus(0.142, 0.178, 28), M_COP, Vector3(0, ci, 0), Vector3.ZERO, Vector3(1, 0.48, 1), false)
	for ai in 3:
		var a := TAU * float(ai) / 3.0
		K.bb(r, Vector3(0.032, 0.66, 0.032), K.gunmetal(), Vector3(cos(a) * 0.175, 0, sin(a) * 0.175), Vector3.ZERO, 0.006)
	return Vector3(0.42, 0.38, 0.90).normalized()


static func _build_coolant_pack(root: Node3D) -> Vector3:
	var M_TANK := A.paint(Color(0.20, 0.46, 0.66), 0.40, 0.34, {"wear": 0.30, "panel_scale": 0.0})
	var M_FROST := A.paint(Color(0.78, 0.91, 0.98), 0.10, 0.42, {"panel_scale": 0.0})
	var M_CAP := K.gunmetal()
	var M_BR := K.brass()
	var M_DIAL := A.paint(Color(0.94, 0.95, 0.92), 0.04, 0.32, {"panel_scale": 0.0})
	# 32 段液氮超冷压力钢瓶 + 结霜圆顶 + 阀门保护拱架 + 黄铜带指针压力表 + 冰蓝液位视窗
	K.cy(root, 0.24, 0.58, M_TANK, Vector3(0, -0.05, 0), Vector3.ZERO, -1.0, 32)
	A.add(root, A.sphere(0.24, 0.24, 28), M_FROST, Vector3(0, 0.23, 0), Vector3.ZERO, Vector3(1, 0.58, 1), false)
	for sy in [-0.24, 0.14]:
		A.add(root, A.torus(0.222, 0.258, 32), M_CAP, Vector3(0, sy, 0), Vector3.ZERO, Vector3(1, 0.50, 1), false)
	# 顶部阀门护笼 + 黄铜主阀与侧压表（带白表盘+红指针）
	A.add(root, A.tube([Vector3(-0.14, 0.28, 0), Vector3(-0.15, 0.46, 0), Vector3(0.15, 0.46, 0), Vector3(0.14, 0.28, 0)], 0.020, 14, 8), M_CAP, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	K.cy(root, 0.055, 0.14, M_BR, Vector3(0, 0.38, 0), Vector3.ZERO, -1.0, 22)
	A.add(root, A.torus(0.042, 0.072, 20), M_CAP, Vector3(0, 0.44, 0), Vector3.ZERO, Vector3(1, 0.45, 1), false)
	var gm := K.node(root, Vector3(0.14, 0.36, 0.11), Vector3(90, 0, -24))
	K.cy(gm, 0.092, 0.042, M_BR, Vector3.ZERO, Vector3.ZERO, -1.0, 24)
	K.cy(gm, 0.072, 0.048, M_DIAL, Vector3.ZERO, Vector3.ZERO, -1.0, 24)
	K.bb(gm, Vector3(0.012, 0.054, 0.055), A.paint(Color(0.84, 0.18, 0.16), 0.1, 0.4), Vector3(0.012, 0.0, -0.018), Vector3(0, 32, 0), 0.002)
	# 冰蓝液位视窗 + 刻度框
	K.bb(root, Vector3(0.078, 0.31, 0.032), M_CAP, Vector3(0, -0.04, 0.235), Vector3.ZERO, 0.006)
	K.bb(root, Vector3(0.050, 0.27, 0.032), A.emit(Color(0.38, 0.92, 1.0), 1.45), Vector3(0, -0.04, 0.244), Vector3.ZERO, 0.004)
	return Vector3(0.62, 0.48, 0.85).normalized()


static func _build_extract_barrier(root: Node3D) -> Vector3:
	var M_BASE := K.gunmetal()
	var M_DK := K.dark()
	var M_COP := K.copper()
	var M_FLD := A.emit(Color(0.30, 0.96, 0.82), 1.90)
	# 便携力场发生器：八角装甲盘座（allow_poly=true）+ 24 段中央核心 + 4 支铜尖发射翼 + 双悬浮偏转光环
	A.add(root, A.cyl(0.36, 0.14, 0.42, 8, true), M_DK, Vector3(0, -0.14, 0))
	K.cy(root, 0.24, 0.12, M_BASE, Vector3(0, -0.02, 0), Vector3.ZERO, -1.0, 24)
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		var ca := cos(a)
		var sa := sin(a)
		K.bb(root, Vector3(0.078, 0.38, 0.078), M_BASE, Vector3(ca * 0.26, 0.06, sa * 0.26), Vector3(sa * 14.0, -rad_to_deg(a), -ca * 14.0), 0.012)
		K.cy(root, 0.032, 0.08, M_COP, Vector3(ca * 0.24, 0.24, sa * 0.24), Vector3(sa * 14.0, 0, -ca * 14.0), 0.045, 18)
	A.add(root, A.torus(0.24, 0.31, 36), M_FLD, Vector3(0, 0.25, 0), Vector3.ZERO, Vector3(1, 0.52, 1), false)
	A.add(root, A.torus(0.14, 0.175, 28), M_FLD, Vector3(0, 0.16, 0), Vector3(16, 0, -14), Vector3(1, 0.45, 1), false)
	A.add(root, A.sphere(0.105, 0.21, 28), M_FLD, Vector3(0, 0.10, 0), Vector3.ZERO, Vector3.ONE, false)
	return Vector3(0.66, 0.62, 0.78).normalized()


static func _build_surge_cell(root: Node3D) -> Vector3:
	var M_FR := K.dark()
	var M_CAP := A.emit(Color(0.95, 0.30, 0.88), 1.80)
	var M_GLS := A.glass(Color(0.92, 0.48, 0.96))
	var M_COP := K.copper()
	var M_HAZ := K.accent()
	# 三联过载脉冲电容模组：底座 + 24 段玻璃护套脉冲管 + 紫铜汇流母排 + 螺母夹紧件 + 状态灯
	K.bb(root, Vector3(0.68, 0.22, 0.46), M_FR, Vector3(0, -0.22, 0), Vector3.ZERO, 0.025)
	K.bb(root, Vector3(0.68, 0.10, 0.46), M_HAZ, Vector3(0, 0.24, 0), Vector3.ZERO, 0.02)
	for ix in [-0.20, 0.0, 0.20]:
		K.cy(root, 0.072, 0.42, M_CAP, Vector3(ix, 0.02, 0), Vector3.ZERO, -1.0, 24)
		K.cy(root, 0.092, 0.38, M_GLS, Vector3(ix, 0.02, 0), Vector3.ZERO, -1.0, 24)
		A.add(root, A.torus(0.086, 0.106, 24), K.gunmetal(), Vector3(ix, 0.12, 0), Vector3.ZERO, Vector3(1, 0.48, 1), false)
		A.add(root, A.torus(0.086, 0.106, 24), K.gunmetal(), Vector3(ix, -0.08, 0), Vector3.ZERO, Vector3(1, 0.48, 1), false)
		A.add(root, A.cyl(0.036, 0.055, 0.036, 6, true), A.chrome(), Vector3(ix, 0.33, 0))
	K.bb(root, Vector3(0.56, 0.04, 0.08), M_COP, Vector3(0, 0.30, 0.09), Vector3.ZERO, 0.005)
	K.bb(root, Vector3(0.56, 0.04, 0.08), M_COP, Vector3(0, 0.30, -0.09), Vector3.ZERO, 0.005)
	for lx in [-0.18, -0.06, 0.06]:
		K.bb(root, Vector3(0.048, 0.036, 0.02), M_CAP, Vector3(lx, -0.22, 0.235), Vector3.ZERO, 0.003)
	return Vector3(0.62, 0.46, 0.84).normalized()


# ================================================================ 货币/贵重品类
static func _build_credit_chip(root: Node3D, large: bool) -> Vector3:
	var M_CARD := A.metal(Color(0.15, 0.17, 0.22) if large else Color(0.24, 0.28, 0.35))
	var M_GOLD := K.brass()
	var M_GLOW := A.emit(Color(0.99, 0.78, 0.18) if large else Color(0.26, 0.86, 0.99), 1.65)
	var n := K.node(root, Vector3.ZERO, Vector3(24, -22, 16))
	# 加密钛合金信用芯片卡（大额叠放两张 + 金框 + 6 触点芯片矩阵 + 全息防伪徽章）
	var count := 2 if large else 1
	for ci in count:
		var yo := float(ci) * 0.09
		K.bb(n, Vector3(0.84, 0.062, 0.54), M_GOLD if (large and ci == 0) else M_CARD, Vector3(float(ci) * 0.04, yo, float(ci) * -0.04), Vector3.ZERO, 0.016)
	var top_y := float(count - 1) * 0.09 + 0.032
	# 智能金触点阵列
	K.bb(n, Vector3(0.23, 0.014, 0.19), K.dark(), Vector3(-0.22, top_y, 0.04), Vector3.ZERO, 0.003)
	for cx in [-0.28, -0.22, -0.16]:
		for cz in [-0.005, 0.085]:
			K.bb(n, Vector3(0.048, 0.018, 0.068), M_GOLD, Vector3(cx, top_y + 0.002, cz), Vector3.ZERO, 0.002)
	# 发光加密磁条与圆形全息章
	K.bb(n, Vector3(0.46, 0.016, 0.065), M_GLOW, Vector3(0.10, top_y, -0.11), Vector3.ZERO, 0.004)
	K.cy(n, 0.072, 0.016, M_GOLD, Vector3(0.26, top_y, 0.12), Vector3.ZERO, -1.0, 22)
	if large:
		K.bb(n, Vector3(0.24, 0.016, 0.048), M_GLOW, Vector3(0.06, top_y, 0.09), Vector3.ZERO, 0.004)
	return Vector3(0.40, 0.82, 0.58).normalized()


static func _build_gold(root: Node3D) -> Vector3:
	# 2×1 横向纪念金条：梯形铸造金锭 + 凹印边界框 + 圆形造币厂徽印 + AU 999.9 钢印
	var M_AU := A.paint(Color(0.96, 0.78, 0.22), 0.94, 0.18, {"wear": 0.05, "panel_scale": 0.0})
	var M_STAMP := A.paint(Color(0.76, 0.56, 0.12), 0.88, 0.26, {"wear": 0.04, "panel_scale": 0.0})
	K.bb(root, Vector3(1.52, 0.32, 0.62), M_AU, Vector3.ZERO, Vector3.ZERO, 0.048, 0.78)
	K.bb(root, Vector3(1.06, 0.022, 0.38), M_STAMP, Vector3(0, 0.160, 0), Vector3.ZERO, 0.008)
	K.bb(root, Vector3(0.98, 0.026, 0.31), M_AU, Vector3(0, 0.164, 0), Vector3.ZERO, 0.006)
	K.cy(root, 0.115, 0.026, M_STAMP, Vector3(-0.34, 0.172, 0), Vector3.ZERO, -1.0, 24)
	K.cy(root, 0.085, 0.030, M_AU, Vector3(-0.34, 0.174, 0), Vector3.ZERO, -1.0, 24)
	A.stencil(root, "AU 999.9", Vector3(0.10, 0.188, 0.0), Vector3(-90, 0, 0), 0.0028, Color(0.55, 0.36, 0.06, 0.96))
	return Vector3(0.24, 0.82, 0.65).normalized()


# ================================================================ 赠礼道具类（5 款）
static func _build_gift_watch(root: Node3D) -> Vector3:
	var M_BR := K.brass()
	var M_DIAL := A.paint(Color(0.95, 0.93, 0.85), 0.04, 0.34, {"panel_scale": 0.0})
	var M_HAND := K.dark()
	var w := K.node(root, Vector3.ZERO, Vector3(58, -18, 12))
	# 36 段黄铜古董怀表 + 12 刻度点表盘 + 指针 + 铰链半开表盖 + 滚花表冠与盘绕铜链
	K.cy(w, 0.34, 0.10, M_BR, Vector3.ZERO, Vector3.ZERO, -1.0, 36)
	A.add(w, A.torus(0.295, 0.348, 36), M_BR, Vector3(0, 0.048, 0), Vector3.ZERO, Vector3(1, 0.45, 1), false)
	K.cy(w, 0.285, 0.022, M_DIAL, Vector3(0, 0.052, 0), Vector3.ZERO, -1.0, 32)
	for hi in 12:
		var ha := TAU * float(hi) / 12.0
		var r_pip := 0.235
		K.bb(w, Vector3(0.014 if hi % 3 != 0 else 0.022, 0.014, 0.032 if hi % 3 != 0 else 0.048), M_HAND,
			Vector3(sin(ha) * r_pip, 0.064, -cos(ha) * r_pip), Vector3(0, -rad_to_deg(ha), 0), 0.002)
	K.bb(w, Vector3(0.022, 0.016, 0.18), M_HAND, Vector3(0.03, 0.068, -0.05), Vector3(0, -28, 0), 0.003)
	K.bb(w, Vector3(0.018, 0.016, 0.13), M_HAND, Vector3(-0.04, 0.070, -0.02), Vector3(0, 52, 0), 0.003)
	K.cy(w, 0.024, 0.024, M_BR, Vector3(0, 0.070, 0), Vector3.ZERO, -1.0, 18)
	# 顶部表冠、表环与铰链半开表盖
	K.cy(w, 0.055, 0.095, M_BR, Vector3(0, 0.0, -0.375), Vector3(90, 0, 0), -1.0, 22)
	A.add(w, A.torus(0.075, 0.106, 24), M_BR, Vector3(0, 0.0, -0.455), Vector3.ZERO, Vector3(1, 0.40, 1), false)
	K.cy(w, 0.028, 0.12, M_BR, Vector3(-0.34, 0.04, 0.0), Vector3(90, 0, 0), -1.0, 18)
	K.cy(w, 0.33, 0.034, M_BR, Vector3(-0.35, 0.22, 0.0), Vector3(0, 0, 62), -1.0, 32)
	A.add(w, A.tube([Vector3(0.04, -0.01, -0.52), Vector3(0.24, -0.02, -0.56), Vector3(0.42, -0.02, -0.38), Vector3(0.45, -0.02, -0.14)], 0.016, 14, 10), M_BR, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	return Vector3(0.32, 0.56, 0.86).normalized()


static func _build_gift_wrench(root: Node3D) -> Vector3:
	var M_ST := A.chrome()
	var M_DK := K.gunmetal()
	var w := K.node(root, Vector3.ZERO, Vector3(0, 0, 38))
	# 锻造铬钒钢双头呆梅扳手：工字凹槽柄身 + 28 段梅花闭口端 + 真正分体 C 型开口钳爪
	K.bb(w, Vector3(0.76, 0.115, 0.068), M_ST, Vector3.ZERO, Vector3.ZERO, 0.022)
	K.bb(w, Vector3(0.58, 0.056, 0.078), M_DK, Vector3.ZERO, Vector3.ZERO, 0.008)
	# 左侧梅花闭口端（28 段外圈 + 24 段内齿孔）
	K.cy(w, 0.152, 0.082, M_ST, Vector3(-0.39, 0.0, 0.0), Vector3(90, 0, 0), -1.0, 28)
	K.cy(w, 0.082, 0.092, K.bore_mat(), Vector3(-0.39, 0.0, 0.0), Vector3(90, 0, 0), -1.0, 24)
	# 右侧真实分体锻造 C 型开口钳头（颈部过渡 + 上下双厚钳爪）
	K.bb(w, Vector3(0.14, 0.22, 0.084), M_ST, Vector3(0.36, 0.0, 0.0), Vector3.ZERO, 0.024)
	K.bb(w, Vector3(0.22, 0.092, 0.084), M_ST, Vector3(0.47, 0.108, 0.0), Vector3(0, 0, -14), 0.022)
	K.bb(w, Vector3(0.22, 0.092, 0.084), M_ST, Vector3(0.47, -0.108, 0.0), Vector3(0, 0, 14), 0.022)
	return Vector3(0.22, 0.36, 0.92).normalized()


static func _build_gift_cocoa(root: Node3D) -> Vector3:
	var M_TIN := A.paint(Color(0.54, 0.16, 0.18), 0.30, 0.42, {"wear": 0.22, "panel_scale": 0.0})
	var M_LBL := A.paint(Color(0.92, 0.86, 0.72), 0.06, 0.54, {"panel_scale": 0.0})
	var M_CHOC := A.paint(Color(0.26, 0.13, 0.09), 0.08, 0.58, {"panel_scale": 0.0})
	var M_BR := K.brass()
	# 精装倒角铁皮可可粉罐 + 卷边底圈 + 复古黄铜顶盖与球钮 + 烫金徽标
	K.bb(root, Vector3(0.52, 0.64, 0.42), M_TIN, Vector3(0, -0.02, 0), Vector3.ZERO, 0.05)
	K.bb(root, Vector3(0.55, 0.055, 0.45), M_BR, Vector3(0, -0.32, 0), Vector3.ZERO, 0.018)
	K.bb(root, Vector3(0.55, 0.105, 0.45), M_BR, Vector3(0, 0.295, 0), Vector3.ZERO, 0.028)
	K.bb(root, Vector3(0.534, 0.30, 0.434), M_LBL, Vector3(0, -0.01, 0), Vector3.ZERO, 0.016)
	K.bb(root, Vector3(0.54, 0.045, 0.44), M_CHOC, Vector3(0, -0.15, 0), Vector3.ZERO, 0.008)
	K.bb(root, Vector3(0.54, 0.045, 0.44), M_CHOC, Vector3(0, 0.13, 0), Vector3.ZERO, 0.008)
	K.cy(root, 0.085, 0.042, M_BR, Vector3(0, 0.365, 0), Vector3.ZERO, 0.105, 24)
	A.add(root, A.sphere(0.052, 0.09, 20), M_BR, Vector3(0, 0.405, 0), Vector3.ZERO, Vector3.ONE, false)
	A.stencil(root, "COCOA", Vector3(0, -0.01, 0.222), Vector3.ZERO, 0.0028, Color(0.42, 0.14, 0.12, 0.95))
	return Vector3(0.65, 0.52, 0.80).normalized()


static func _build_gift_chart(root: Node3D) -> Vector3:
	var M_COV := A.paint(Color(0.15, 0.24, 0.40), 0.14, 0.64, {"wear": 0.22, "panel_scale": 0.0})
	var M_PAGE := A.paint(Color(0.92, 0.87, 0.76), 0.0, 0.84, {"panel_scale": 0.0})
	var M_BR := K.brass()
	var M_COP := K.copper()
	var n := K.node(root, Vector3.ZERO, Vector3(28, -22, 12))
	# 海军蓝精装硬壳航线图册（四角包铜 + 书脊筋条 + 罗盘徽章）+ 旁配黄铜航图卷筒（露羊皮纸卷）
	K.bb(n, Vector3(0.62, 0.115, 0.78), M_COV, Vector3(-0.08, 0, 0), Vector3.ZERO, 0.022)
	K.bb(n, Vector3(0.57, 0.082, 0.72), M_PAGE, Vector3(-0.06, 0, 0), Vector3.ZERO, 0.008)
	for sz in [-0.36, 0.36]:
		K.bb(n, Vector3(0.10, 0.125, 0.10), M_BR, Vector3(0.19, 0, sz), Vector3.ZERO, 0.012)
	for sy in [-0.24, 0.0, 0.24]:
		K.bb(n, Vector3(0.055, 0.128, 0.045), M_BR, Vector3(-0.37, 0, sy), Vector3.ZERO, 0.008)
	# 烫金罗盘徽章（28 段外圈 + 十字指针）
	K.cy(n, 0.145, 0.018, M_BR, Vector3(-0.08, 0.060, 0), Vector3.ZERO, -1.0, 28)
	K.cy(n, 0.112, 0.022, M_COV, Vector3(-0.08, 0.062, 0), Vector3.ZERO, -1.0, 24)
	K.bb(n, Vector3(0.22, 0.024, 0.024), M_BR, Vector3(-0.08, 0.064, 0), Vector3.ZERO, 0.003)
	K.bb(n, Vector3(0.024, 0.024, 0.22), M_BR, Vector3(-0.08, 0.064, 0), Vector3.ZERO, 0.003)
	# 24 段黄铜航图筒 + 露出的一端海图卷纸
	K.cy(n, 0.095, 0.70, M_BR, Vector3(0.32, 0.08, 0.0), Vector3(90, 0, 0), -1.0, 24)
	K.cy(n, 0.072, 0.16, M_PAGE, Vector3(0.32, 0.08, 0.36), Vector3(90, 0, 0), -1.0, 22)
	for ez in [-0.32, 0.28]:
		K.cy(n, 0.106, 0.075, M_COP, Vector3(0.32, 0.08, ez), Vector3(90, 0, 0), -1.0, 24)
	return Vector3(0.44, 0.82, 0.60).normalized()


static func _build_gift_flask(root: Node3D) -> Vector3:
	var M_SIL := A.chrome()
	var M_CAP := K.brass()
	var M_BND := A.paint(Color(0.38, 0.22, 0.13), 0.06, 0.76, {"panel_scale": 0.0})
	var f := K.node(root, Vector3.ZERO, Vector3(8, 22, -8))
	# 拉丝银扁酒壶 + 皮革缝线裹腰 + 铜铆钉 + 24 段旋钮黄铜盖 + 铰接防丢卡臂
	K.bb(f, Vector3(0.50, 0.62, 0.22), M_SIL, Vector3(0, -0.04, 0), Vector3.ZERO, 0.058)
	K.bb(f, Vector3(0.518, 0.28, 0.238), M_BND, Vector3(0, -0.04, 0), Vector3.ZERO, 0.032)
	for sy in [-0.15, 0.07]:
		K.bb(f, Vector3(0.526, 0.018, 0.244), M_CAP, Vector3(0, sy, 0), Vector3.ZERO, 0.005)
	K.cy(f, 0.066, 0.14, M_SIL, Vector3(0.08, 0.30, 0), Vector3.ZERO, -1.0, 24)
	K.cy(f, 0.084, 0.085, M_CAP, Vector3(0.08, 0.375, 0), Vector3.ZERO, -1.0, 24)
	A.add(f, A.tube([Vector3(0.08, 0.39, 0), Vector3(0.20, 0.39, 0), Vector3(0.20, 0.28, 0), Vector3(0.14, 0.27, 0)], 0.016, 14, 6), M_SIL, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	return Vector3(0.58, 0.45, 0.85).normalized()


# ================================================================ 档案/文献类（12 款差异化模型）
static func _build_archive_clipboard(root: Node3D, board_c: Color, stripe_c: Color, code: String) -> Vector3:
	var M_BD := A.paint(board_c, 0.22, 0.60, {"panel_scale": 0.0})
	var M_PG := A.paint(Color(0.92, 0.89, 0.81), 0.0, 0.84, {"panel_scale": 0.0})
	var M_LINE := A.paint(Color(0.28, 0.30, 0.34), 0.0, 0.85, {"panel_scale": 0.0})
	var M_STR := A.paint(stripe_c, 0.10, 0.52, {"panel_scale": 0.0})
	var M_PEN := A.paint(Color(0.86, 0.66, 0.16), 0.10, 0.56, {"panel_scale": 0.0})
	var n := K.node(root, Vector3.ZERO, Vector3(26, -16, 10))
	K.bb(n, Vector3(0.64, 0.045, 0.86), M_BD, Vector3.ZERO, Vector3.ZERO, 0.015)
	K.bb(n, Vector3(0.54, 0.025, 0.72), M_PG, Vector3(0, 0.03, 0.03), Vector3.ZERO, 0.006)
	# 铬钢弹簧夹板 + 弯曲压丝线环
	K.bb(n, Vector3(0.25, 0.055, 0.10), A.chrome(), Vector3(0, 0.055, -0.37), Vector3.ZERO, 0.012)
	A.add(n, A.tube([Vector3(-0.08, 0.075, -0.38), Vector3(-0.08, 0.125, -0.42), Vector3(0.08, 0.125, -0.42), Vector3(0.08, 0.075, -0.38)], 0.012, 14, 6), A.chrome(), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	K.bb(n, Vector3(0.46, 0.012, 0.055), M_STR, Vector3(0, 0.046, -0.22), Vector3.ZERO, 0.002)
	for li in 4:
		var lw := 0.42 if li < 3 else 0.28
		K.bb(n, Vector3(lw, 0.010, 0.026), M_LINE, Vector3(-0.21 + lw * 0.5, 0.046, -0.06 + float(li) * 0.085), Vector3.ZERO, 0.002)
	# 夹在板侧的一支六棱铅笔
	var pn := K.node(n, Vector3(0.35, 0.045, 0.06), Vector3(90, 0, -4))
	A.add(pn, A.cyl(0.026, 0.52, 0.026, 6, true), M_PEN, Vector3.ZERO)
	A.add(pn, A.cyl(0.004, 0.09, 0.025, 16), M_LINE, Vector3(0, 0.30, 0))
	K.cy(pn, 0.026, 0.05, A.paint(Color(0.84, 0.36, 0.36), 0.0, 0.72), Vector3(0, -0.28, 0), Vector3.ZERO, -1.0, 16)
	A.stencil(n, code, Vector3(0.0, 0.052, 0.30), Vector3(-90, 0, 0), 0.0022, Color(0.18, 0.20, 0.24, 0.9))
	return Vector3(0.32, 0.84, 0.58).normalized()


static func _build_archive_binder(root: Node3D, cov_c: Color, badge_c: Color, has_vial: bool) -> Vector3:
	var M_COV := A.paint(cov_c, 0.16, 0.56, {"panel_scale": 0.0})
	var M_PG := A.paint(Color(0.92, 0.90, 0.82), 0.0, 0.84, {"panel_scale": 0.0})
	var M_BADGE := A.paint(badge_c, 0.18, 0.40, {"panel_scale": 0.0})
	var n := K.node(root, Vector3.ZERO, Vector3(24, -22, 12))
	K.bb(n, Vector3(0.64, 0.12, 0.80), M_COV, Vector3(-0.04, 0, 0), Vector3.ZERO, 0.02)
	K.bb(n, Vector3(0.58, 0.09, 0.74), M_PG, Vector3(-0.02, 0, 0), Vector3.ZERO, 0.008)
	K.bb(n, Vector3(0.10, 0.135, 0.81), K.dark(), Vector3(-0.31, 0, 0), Vector3.ZERO, 0.014)
	for ri in 4:
		A.add(n, A.torus(0.026, 0.046, 20), A.chrome(), Vector3(-0.32, 0.042, -0.24 + float(ri) * 0.16), Vector3(0, 90, 0), Vector3(1, 0.5, 1), false)
	K.bb(n, Vector3(0.32, 0.016, 0.14), M_BADGE, Vector3(0.02, 0.068, -0.14), Vector3.ZERO, 0.004)
	K.bb(n, Vector3(0.24, 0.012, 0.03), M_PG, Vector3(0.02, 0.072, 0.08), Vector3.ZERO, 0.002)
	if has_vial:
		# 24 段玻璃样品试管 + 发光试剂 + 铝封口与橡胶塞
		var vn := K.node(n, Vector3(0.32, 0.08, 0.04), Vector3(90, 0, -14))
		K.cy(vn, 0.076, 0.44, A.glass(badge_c), Vector3.ZERO, Vector3.ZERO, -1.0, 24)
		K.cy(vn, 0.056, 0.28, A.emit(badge_c, 0.95), Vector3(0, -0.02, 0), Vector3.ZERO, -1.0, 20)
		K.cy(vn, 0.062, 0.06, K.dark(), Vector3(0, 0.24, 0), Vector3.ZERO, -1.0, 20)
		K.cy(vn, 0.078, 0.04, A.chrome(), Vector3(0, 0.21, 0), Vector3.ZERO, -1.0, 20)
	return Vector3(0.42, 0.82, 0.62).normalized()


static func _build_archive_flight_log(root: Node3D) -> Vector3:
	var M_ORANGE := A.paint(Color(0.90, 0.36, 0.10), 0.30, 0.44, {"wear": 0.38, "panel_scale": 0.0})
	var M_PG := A.paint(Color(0.92, 0.88, 0.78), 0.0, 0.84, {"panel_scale": 0.0})
	var M_INK := A.paint(Color(0.22, 0.24, 0.28), 0.0, 0.82, {"panel_scale": 0.0})
	# 黑匣子抗毁飞行记录仪（带水下声学信标柱 + 提手 + 警示条）+ 折角航行日志页
	var box := K.node(root, Vector3(-0.08, 0.04, -0.06), Vector3(8, 22, -6))
	K.bb(box, Vector3(0.56, 0.34, 0.56), M_ORANGE, Vector3.ZERO, Vector3.ZERO, 0.032)
	K.bb(box, Vector3(0.48, 0.045, 0.48), K.gunmetal(), Vector3(0, 0.18, 0), Vector3.ZERO, 0.01)
	K.bb(box, Vector3(0.58, 0.06, 0.12), A.hazard(), Vector3(0, -0.10, 0.24), Vector3.ZERO, 0.008)
	K.cy(box, 0.062, 0.24, A.chrome(), Vector3(0.0, 0.02, 0.32), Vector3(0, 0, 90), -1.0, 22)
	A.add(box, A.tube([Vector3(-0.16, 0.19, -0.14), Vector3(-0.16, 0.29, -0.14), Vector3(0.16, 0.29, -0.14), Vector3(0.16, 0.19, -0.14)], 0.018, 14, 6), K.gunmetal(), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	var pg := K.node(root, Vector3(0.16, -0.14, 0.20), Vector3(14, -18, 6))
	K.bb(pg, Vector3(0.56, 0.025, 0.44), M_PG, Vector3.ZERO, Vector3.ZERO, 0.005)
	for li in 3:
		K.bb(pg, Vector3(0.38, 0.010, 0.022), M_INK, Vector3(0, 0.016, -0.10 + float(li) * 0.09), Vector3.ZERO, 0.002)
	return Vector3(0.54, 0.68, 0.78).normalized()


static func _build_archive_blueprint(root: Node3D) -> Vector3:
	var M_BLUE := A.paint(Color(0.09, 0.32, 0.70), 0.08, 0.74, {"panel_scale": 0.0})
	var M_LINE := A.paint(Color(0.88, 0.95, 1.0), 0.0, 0.48, {"panel_scale": 0.0})
	var b := K.node(root, Vector3.ZERO, Vector3(22, -20, 10))
	# 半展开工程蓝图：白线机械结构视图（含圆环齿轮图）+ 28 段卷筒 + 黄铜分规
	K.bb(b, Vector3(0.76, 0.022, 0.60), M_BLUE, Vector3(-0.06, 0, 0), Vector3.ZERO, 0.005)
	K.bb(b, Vector3(0.58, 0.008, 0.018), M_LINE, Vector3(-0.08, 0.015, -0.18), Vector3.ZERO, 0.001)
	K.bb(b, Vector3(0.58, 0.008, 0.018), M_LINE, Vector3(-0.08, 0.015, 0.18), Vector3.ZERO, 0.001)
	K.bb(b, Vector3(0.018, 0.008, 0.36), M_LINE, Vector3(-0.36, 0.015, 0), Vector3.ZERO, 0.001)
	A.add(b, A.torus(0.085, 0.105, 24), M_LINE, Vector3(-0.12, 0.015, -0.01), Vector3.ZERO, Vector3(1, 0.25, 1), false)
	K.bb(b, Vector3(0.24, 0.008, 0.014), M_LINE, Vector3(-0.12, 0.016, -0.01), Vector3.ZERO, 0.001)
	K.bb(b, Vector3(0.014, 0.008, 0.24), M_LINE, Vector3(-0.12, 0.016, -0.01), Vector3.ZERO, 0.001)
	# 右侧 28 段卷边蓝图卷筒
	K.cy(b, 0.088, 0.62, M_BLUE, Vector3(0.32, 0.078, 0), Vector3(90, 0, 0), -1.0, 28)
	K.cy(b, 0.062, 0.632, K.dark(), Vector3(0.32, 0.078, 0), Vector3(90, 0, 0), -1.0, 24)
	# 压在图角的一把小黄铜圆规
	K.cy(b, 0.022, 0.025, K.brass(), Vector3(-0.26, 0.032, 0.12), Vector3.ZERO, -1.0, 16)
	K.bb(b, Vector3(0.018, 0.018, 0.26), K.brass(), Vector3(-0.22, 0.028, 0.22), Vector3(0, -18, 0), 0.003)
	K.bb(b, Vector3(0.018, 0.018, 0.26), K.brass(), Vector3(-0.30, 0.028, 0.22), Vector3(0, 18, 0), 0.003)
	return Vector3(0.38, 0.85, 0.60).normalized()


static func _build_archive_tape(root: Node3D) -> Vector3:
	var M_SH := A.paint(Color(0.14, 0.15, 0.17), 0.16, 0.40, {"panel_scale": 0.0})
	var M_LBL := A.paint(Color(0.92, 0.64, 0.22), 0.04, 0.66, {"panel_scale": 0.0})
	var M_STRIPE := A.paint(Color(0.76, 0.24, 0.16), 0.04, 0.62, {"panel_scale": 0.0})
	var M_REEL := A.paint(Color(0.90, 0.90, 0.88), 0.04, 0.48, {"panel_scale": 0.0})
	var M_TAPE := A.paint(Color(0.22, 0.14, 0.09), 0.10, 0.45, {"panel_scale": 0.0})
	var t := K.node(root, Vector3.ZERO, Vector3(32, -16, 12))
	# 老式盒式录音磁带：暗色壳体 + 四角小螺钉 + 双色标签 + 24 段带齿双卷轴 + 中间观察窗
	K.bb(t, Vector3(0.84, 0.14, 0.54), M_SH, Vector3.ZERO, Vector3.ZERO, 0.018)
	K.bb(t, Vector3(0.72, 0.016, 0.34), M_LBL, Vector3(0, 0.072, -0.04), Vector3.ZERO, 0.005)
	K.bb(t, Vector3(0.72, 0.018, 0.065), M_STRIPE, Vector3(0, 0.073, -0.15), Vector3.ZERO, 0.003)
	K.bb(t, Vector3(0.28, 0.022, 0.14), M_TAPE, Vector3(0, 0.074, -0.02), Vector3.ZERO, 0.004)
	for rx in [-0.19, 0.19]:
		K.cy(t, 0.092, 0.040, M_REEL, Vector3(rx, 0.076, -0.02), Vector3.ZERO, -1.0, 24)
		K.cy(t, 0.044, 0.052, K.dark(), Vector3(rx, 0.076, -0.02), Vector3.ZERO, -1.0, 18)
	for sx in [-0.36, 0.36]:
		for sz in [-0.21, 0.21]:
			K.cy(t, 0.016, 0.02, A.chrome(), Vector3(sx, 0.068, sz), Vector3.ZERO, -1.0, 16)
	K.bb(t, Vector3(0.56, 0.065, 0.085), K.gunmetal(), Vector3(0, 0.06, 0.24), Vector3.ZERO, 0.006)
	return Vector3(0.30, 0.82, 0.62).normalized()


static func _build_archive_photo(root: Node3D) -> Vector3:
	var M_FRM := A.paint(Color(0.93, 0.91, 0.83), 0.0, 0.72, {"panel_scale": 0.0})
	var M_PIC := A.paint(Color(0.44, 0.36, 0.26), 0.05, 0.65, {"panel_scale": 0.0})
	var M_SKY := A.paint(Color(0.70, 0.63, 0.50), 0.05, 0.65, {"panel_scale": 0.0})
	var M_SUN := A.paint(Color(0.90, 0.74, 0.42), 0.05, 0.55, {"panel_scale": 0.0})
	var M_SIL := A.paint(Color(0.24, 0.20, 0.16), 0.05, 0.70, {"panel_scale": 0.0})
	# 两张错叠的拍立得泛黄风景照片 + 银色回形针
	for i in 2:
		var p := K.node(root, Vector3(0.10 if i == 0 else -0.08, 0.032 * float(i), 0.04 if i == 0 else -0.04), Vector3(24, -18 + float(i) * 24.0, 8 - float(i) * 18.0))
		K.bb(p, Vector3(0.56, 0.022, 0.68), M_FRM, Vector3.ZERO, Vector3.ZERO, 0.006)
		K.bb(p, Vector3(0.46, 0.012, 0.44), M_SKY, Vector3(0, 0.012, -0.05), Vector3.ZERO, 0.002)
		K.bb(p, Vector3(0.46, 0.014, 0.20), M_PIC, Vector3(0, 0.013, 0.07), Vector3.ZERO, 0.002)
		K.cy(p, 0.052, 0.016, M_SUN, Vector3(0.11, 0.014, -0.14), Vector3.ZERO, -1.0, 20)
		K.bb(p, Vector3(0.10, 0.016, 0.14), M_SIL, Vector3(-0.08, 0.014, -0.02), Vector3.ZERO, 0.002)
		if i == 1:
			A.add(p, A.tube([Vector3(-0.18, 0.022, -0.20), Vector3(-0.18, 0.022, -0.35), Vector3(-0.11, 0.022, -0.35), Vector3(-0.11, 0.022, -0.22)], 0.011, 14, 6), A.chrome(), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	return Vector3(0.34, 0.85, 0.56).normalized()


static func _build_archive_letter(root: Node3D) -> Vector3:
	var M_ENV := A.paint(Color(0.88, 0.82, 0.68), 0.0, 0.82, {"panel_scale": 0.0})
	var M_FLAP := A.paint(Color(0.80, 0.73, 0.58), 0.0, 0.84, {"panel_scale": 0.0})
	var M_PAPER := A.paint(Color(0.96, 0.95, 0.91), 0.0, 0.84, {"panel_scale": 0.0})
	var M_WAX := A.paint(Color(0.74, 0.14, 0.14), 0.12, 0.34, {"panel_scale": 0.0})
	var M_STAMP := A.paint(Color(0.24, 0.42, 0.68), 0.04, 0.72, {"panel_scale": 0.0})
	var M_INK := A.paint(Color(0.24, 0.22, 0.20), 0.0, 0.84, {"panel_scale": 0.0})
	var l := K.node(root, Vector3.ZERO, Vector3(26, -18, 10))
	K.bb(l, Vector3(0.82, 0.045, 0.54), M_ENV, Vector3.ZERO, Vector3.ZERO, 0.012)
	# V 形信封折痕边 + 邮票 + 抽出半截的书写信纸 + 28 段浮雕火漆印章
	K.bb(l, Vector3(0.54, 0.010, 0.016), M_FLAP, Vector3(-0.16, 0.026, -0.10), Vector3(0, -30, 0), 0.002)
	K.bb(l, Vector3(0.54, 0.010, 0.016), M_FLAP, Vector3(0.16, 0.026, -0.10), Vector3(0, 30, 0), 0.002)
	K.bb(l, Vector3(0.11, 0.012, 0.13), M_STAMP, Vector3(0.29, 0.026, 0.14), Vector3.ZERO, 0.002)
	var pg := K.node(l, Vector3(0.06, 0.032, -0.15), Vector3(0, 12, 0))
	K.bb(pg, Vector3(0.68, 0.024, 0.46), M_PAPER, Vector3.ZERO, Vector3.ZERO, 0.005)
	for li in 3:
		K.bb(pg, Vector3(0.46, 0.008, 0.018), M_INK, Vector3(0, 0.015, -0.10 + float(li) * 0.075), Vector3.ZERO, 0.001)
	K.cy(l, 0.095, 0.032, M_WAX, Vector3(-0.08, 0.036, 0.04), Vector3.ZERO, -1.0, 28)
	A.add(l, A.torus(0.068, 0.096, 24), M_WAX, Vector3(-0.08, 0.052, 0.04), Vector3.ZERO, Vector3(1, 0.45, 1), false)
	return Vector3(0.36, 0.86, 0.58).normalized()


static func _build_archive_drawing(root: Node3D) -> Vector3:
	var M_PG := A.paint(Color(0.88, 0.86, 0.78), 0.0, 0.88, {"panel_scale": 0.0})
	var M_CR1 := A.paint(Color(0.90, 0.24, 0.20), 0.0, 0.62, {"panel_scale": 0.0})
	var M_CR2 := A.paint(Color(0.94, 0.78, 0.18), 0.0, 0.62, {"panel_scale": 0.0})
	var M_CR3 := A.paint(Color(0.24, 0.62, 0.88), 0.0, 0.62, {"panel_scale": 0.0})
	var M_CR4 := A.paint(Color(0.26, 0.68, 0.30), 0.0, 0.62, {"panel_scale": 0.0})
	var M_WRP := A.paint(Color(0.18, 0.18, 0.20), 0.0, 0.78, {"panel_scale": 0.0})
	var n := K.node(root, Vector3.ZERO, Vector3(24, -18, 12))
	K.bb(n, Vector3(0.76, 0.024, 0.62), M_PG, Vector3.ZERO, Vector3.ZERO, 0.006)
	# 蜡笔画：24 段大太阳 + 光芒 + 蓝房子红屋顶 + 绿草小树 + 两支带纸套与圆锥尖头的彩色蜡笔
	K.cy(n, 0.088, 0.012, M_CR2, Vector3(0.18, 0.016, -0.15), Vector3.ZERO, -1.0, 24)
	for ri in 6:
		var ra := TAU * float(ri) / 6.0
		K.bb(n, Vector3(0.016, 0.010, 0.055), M_CR2, Vector3(0.18 + sin(ra) * 0.125, 0.016, -0.15 + cos(ra) * 0.125), Vector3(0, rad_to_deg(ra), 0), 0.002)
	K.bb(n, Vector3(0.20, 0.012, 0.18), M_CR3, Vector3(-0.14, 0.016, 0.06), Vector3.ZERO, 0.002)
	K.bb(n, Vector3(0.24, 0.014, 0.10), M_CR1, Vector3(-0.14, 0.016, -0.07), Vector3.ZERO, 0.002)
	K.cy(n, 0.065, 0.012, M_CR4, Vector3(-0.30, 0.016, 0.02), Vector3.ZERO, -1.0, 20)
	K.bb(n, Vector3(0.64, 0.010, 0.045), M_CR4, Vector3(-0.02, 0.015, 0.20), Vector3.ZERO, 0.002)
	for c_spec in [
		[Vector3(0.24, 0.050, 0.13), Vector3(90, 32, 0), M_CR1],
		[Vector3(0.32, 0.048, 0.01), Vector3(90, -18, 0), M_CR3],
	]:
		var cn := K.node(n, c_spec[0], c_spec[1])
		K.cy(cn, 0.036, 0.30, c_spec[2], Vector3.ZERO, Vector3.ZERO, -1.0, 18)
		K.cy(cn, 0.038, 0.14, M_WRP, Vector3(0, -0.02, 0), Vector3.ZERO, -1.0, 18)
		A.add(cn, A.cyl(0.005, 0.085, 0.035, 18), c_spec[2], Vector3(0, 0.19, 0))
	return Vector3(0.34, 0.86, 0.56).normalized()
