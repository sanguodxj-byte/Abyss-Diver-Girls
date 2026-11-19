extends RefCounted
## 全量物品 3D 程序化模型库（模块复用 mech_visual / modules，消耗品与物资 40 款独立精细 3D 建模）
## 仅用于工作室布光烘焙 gw×gh 多格高清静态 3D 图标，与地面世界保持零运行时负担。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")
const MV = preload("res://scripts/mech_visual.gd")


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
	var M_TIN := A.paint(Color(0.36, 0.39, 0.32), 0.55, 0.42, {"wear": 0.35, "panel_scale": 0.0})
	var M_LBL := A.paint(Color(0.76, 0.64, 0.36), 0.08, 0.68, {"wear": 0.28, "panel_scale": 0.0})
	var M_BAND := A.paint(Color(0.68, 0.22, 0.16), 0.10, 0.62, {"wear": 0.25, "panel_scale": 0.0})
	var M_RIM := A.chrome()
	# 椭圆军用午餐肉罐 + 压筋罐身 + 拉环盖
	K.cy(root, 0.34, 0.52, M_TIN, Vector3.ZERO, Vector3.ZERO, -1.0, 28)
	K.cy(root, 0.346, 0.30, M_LBL, Vector3(0, -0.02, 0), Vector3.ZERO, -1.0, 28)
	K.cy(root, 0.349, 0.065, M_BAND, Vector3(0, 0.07, 0), Vector3.ZERO, -1.0, 28)
	for sy in [-0.26, 0.26]:
		A.add(root, A.torus(0.315, 0.355, 28), M_RIM, Vector3(0, sy, 0), Vector3.ZERO, Vector3(1, 0.65, 1), false)
	for ry in [-0.19, 0.17]:
		A.add(root, A.torus(0.325, 0.352, 24), M_TIN, Vector3(0, ry, 0), Vector3.ZERO, Vector3(1, 0.5, 1), false)
	K.cy(root, 0.32, 0.02, M_RIM, Vector3(0, 0.255, 0), Vector3.ZERO, -1.0, 24)
	# 拉环与铆钉
	K.cy(root, 0.025, 0.025, M_RIM, Vector3(0.06, 0.275, 0.08), Vector3.ZERO, -1.0, 10)
	A.add(root, A.torus(0.042, 0.064, 16), M_RIM, Vector3(0.11, 0.282, 0.13), Vector3(8, 0, 0), Vector3(1, 0.45, 1), false)
	A.stencil(root, "RATION", Vector3(0.0, 0.05, 0.352), Vector3.ZERO, 0.0028, Color(0.14, 0.12, 0.10, 0.92))
	return Vector3(0.60, 0.65, 0.85).normalized()


static func _build_biscuit(root: Node3D) -> Vector3:
	var M_FOIL := A.paint(Color(0.34, 0.38, 0.28), 0.38, 0.48, {"wear": 0.32, "panel_scale": 0.0})
	var M_SEAL := A.paint(Color(0.24, 0.27, 0.21), 0.45, 0.45, {"panel_scale": 0.0})
	var M_YEL := A.paint(Color(0.86, 0.68, 0.16), 0.08, 0.58, {"panel_scale": 0.0})
	var M_CRUMB := A.paint(Color(0.76, 0.60, 0.36), 0.0, 0.90, {"panel_scale": 0.0})
	var wrap := K.node(root, Vector3.ZERO, Vector3(10, -24, 14))
	# 两袋叠放真空压缩口粮包 + 折边压纹 + 一块露出的麦芽压缩饼干
	K.bb(wrap, Vector3(0.76, 0.18, 0.54), M_FOIL, Vector3(0, -0.04, 0), Vector3.ZERO, 0.035)
	for sx in [-0.41, 0.41]:
		K.bb(wrap, Vector3(0.07, 0.025, 0.52), M_SEAL, Vector3(sx, -0.04, 0), Vector3.ZERO, 0.005)
	K.bb(wrap, Vector3(0.56, 0.19, 0.11), M_YEL, Vector3(0.04, -0.036, 0.12), Vector3.ZERO, 0.01)
	K.bb(wrap, Vector3(0.46, 0.12, 0.38), M_CRUMB, Vector3(-0.08, 0.13, -0.06), Vector3(4, 16, -6), 0.025)
	for dx in [-0.20, -0.08, 0.04]:
		for dz in [-0.14, -0.02]:
			K.cy(wrap, 0.014, 0.02, M_SEAL, Vector3(dx, 0.185, dz), Vector3(4, 16, -6), -1.0, 8)
	return Vector3(0.50, 0.85, 0.72).normalized()


static func _build_water_tab(root: Node3D) -> Vector3:
	var M_CARD := A.paint(Color(0.84, 0.86, 0.88), 0.15, 0.42, {"panel_scale": 0.0})
	var M_FOIL := A.chrome()
	var M_BLISTER := A.paint(Color(0.32, 0.78, 0.95), 0.10, 0.16, {"panel_scale": 0.0})
	var M_VIAL := A.glass(Color(0.28, 0.65, 0.88))
	var b := K.node(root, Vector3.ZERO, Vector3(12, -22, 16))
	# 铝箔药板（8粒净水片泡罩）+ 氯消毒小玻璃瓶
	K.bb(b, Vector3(0.76, 0.03, 0.50), M_FOIL, Vector3(-0.05, 0.0, 0.04), Vector3.ZERO, 0.01)
	K.bb(b, Vector3(0.72, 0.02, 0.46), M_CARD, Vector3(-0.05, 0.02, 0.04), Vector3.ZERO, 0.008)
	for ix in 4:
		for iz in 2:
			var px := -0.28 + float(ix) * 0.15
			var pz := -0.06 + float(iz) * 0.20
			A.add(b, A.sphere(0.052, 0.075, 14), M_BLISTER, Vector3(px, 0.045, pz), Vector3.ZERO, Vector3.ONE, false)
	# 侧面立起蓝色净水药瓶 + 白盖
	K.cy(b, 0.13, 0.36, M_VIAL, Vector3(0.26, 0.16, -0.18), Vector3(8, 0, -10), -1.0, 18)
	K.cy(b, 0.10, 0.26, A.emit(Color(0.28, 0.82, 0.98), 0.65), Vector3(0.26, 0.14, -0.18), Vector3(8, 0, -10), -1.0, 16)
	K.cy(b, 0.11, 0.09, M_CARD, Vector3(0.29, 0.36, -0.15), Vector3(8, 0, -10), -1.0, 16)
	return Vector3(0.50, 0.85, 0.72).normalized()


static func _build_coffee(root: Node3D) -> Vector3:
	var M_BAG := A.paint(Color(0.28, 0.19, 0.13), 0.12, 0.64, {"wear": 0.25, "panel_scale": 0.0})
	var M_FOIL := K.brass()
	var M_LBL := A.paint(Color(0.86, 0.78, 0.62), 0.04, 0.74, {"panel_scale": 0.0})
	var M_BEAN := A.paint(Color(0.18, 0.10, 0.06), 0.08, 0.42, {"panel_scale": 0.0})
	# 真空铝箔咖啡砖 + 卷折封口 + 铜夹 + 前散落三粒烘焙咖啡豆
	K.bb(root, Vector3(0.56, 0.68, 0.32), M_BAG, Vector3(-0.04, 0.02, 0), Vector3(0, 12, 0), 0.04, 0.92)
	K.bb(root, Vector3(0.54, 0.10, 0.10), M_FOIL, Vector3(-0.04, 0.38, 0), Vector3(0, 12, 0), 0.015)
	K.bb(root, Vector3(0.42, 0.34, 0.335), M_LBL, Vector3(-0.04, 0.0, 0), Vector3(0, 12, 0), 0.012)
	K.cy(root, 0.10, 0.34, M_FOIL, Vector3(-0.04, 0.03, 0), Vector3(90, 12, 0), -1.0, 18)
	for bp in [Vector3(0.26, -0.26, 0.24), Vector3(0.36, -0.27, 0.12), Vector3(0.16, -0.27, 0.32)]:
		A.add(root, A.sphere(0.065, 0.09, 12), M_BEAN, bp, Vector3(20, 40, 15), Vector3(1.2, 0.72, 0.92), false)
	return Vector3(0.56, 0.56, 0.85).normalized()


# ================================================================ 杂物材料类
static func _build_circuit(root: Node3D) -> Vector3:
	var M_PCB := A.paint(Color(0.10, 0.36, 0.22), 0.12, 0.36, {"panel_scale": 0.0})
	var M_IC := A.metal(Color(0.09, 0.10, 0.11))
	var M_GOLD := K.brass()
	var M_ALU := A.chrome()
	var M_COP := K.copper()
	var b := K.node(root, Vector3.ZERO, Vector3(24, -22, 16))
	# 多层印制电路板 + 金手指 + QFP 主控芯片 + 电解电容 + 铜电感
	K.bb(b, Vector3(0.86, 0.05, 0.68), M_PCB, Vector3.ZERO, Vector3.ZERO, 0.012)
	for i in 10:
		K.bb(b, Vector3(0.045, 0.058, 0.09), M_GOLD, Vector3(-0.32 + float(i) * 0.07, 0.0, 0.33), Vector3.ZERO, 0.004)
	K.bb(b, Vector3(0.26, 0.07, 0.26), M_IC, Vector3(-0.08, 0.055, -0.04), Vector3.ZERO, 0.01)
	K.bb(b, Vector3(0.14, 0.08, 0.18), M_IC, Vector3(0.24, 0.06, -0.12), Vector3.ZERO, 0.01)
	K.bb(b, Vector3(0.52, 0.02, 0.025), M_GOLD, Vector3(-0.02, 0.032, 0.18), Vector3.ZERO, 0.004)
	K.bb(b, Vector3(0.025, 0.02, 0.38), M_GOLD, Vector3(0.12, 0.032, 0.0), Vector3.ZERO, 0.004)
	for cx in [-0.30, -0.20, -0.30]:
		var cz := 0.06 if cx == -0.20 else -0.18
		K.cy(b, 0.048, 0.14, M_ALU, Vector3(cx, 0.09, cz), Vector3.ZERO, -1.0, 14)
		K.cy(b, 0.046, 0.02, M_IC, Vector3(cx, 0.16, cz), Vector3.ZERO, -1.0, 14)
	A.add(b, A.torus(0.045, 0.095, 16), M_COP, Vector3(0.24, 0.08, 0.12), Vector3.ZERO, Vector3(1, 0.7, 1), false)
	return Vector3(0.35, 0.86, 0.56).normalized()


static func _build_wire(root: Node3D) -> Vector3:
	var M_FLANGE := K.gunmetal()
	var M_COP := K.copper()
	var M_DARK := K.dark()
	var s := K.node(root, Vector3.ZERO, Vector3(18, -28, 22))
	# 工字绕线盘 + 密集铜线匝环 + 翘出铜线尾
	K.cy(s, 0.42, 0.05, M_FLANGE, Vector3(0, 0.25, 0), Vector3.ZERO, -1.0, 24)
	K.cy(s, 0.42, 0.05, M_FLANGE, Vector3(0, -0.25, 0), Vector3.ZERO, -1.0, 24)
	K.cy(s, 0.15, 0.52, M_DARK, Vector3.ZERO, Vector3.ZERO, -1.0, 16)
	for wi in 7:
		var wy := -0.18 + float(wi) * 0.06
		A.add(s, A.torus(0.19, 0.35, 24), M_COP, Vector3(0, wy, 0), Vector3.ZERO, Vector3(1, 0.42, 1), false)
	A.add(s, A.cyl(0.032, 0.46, 0.032, 10), M_COP, Vector3(0.28, 0.05, 0.34), Vector3(54, 24, -40), Vector3.ONE, false)
	return Vector3(0.62, 0.62, 0.80).normalized()


static func _build_bolts(root: Node3D) -> Vector3:
	var M_ST := A.chrome()
	var M_DK := K.gunmetal()
	var M_BR := K.brass()
	# 三颗错落重型六角螺栓 + 两枚六角螺母
	var b1 := K.node(root, Vector3(-0.14, 0.06, 0.04), Vector3(18, 24, -36))
	K.cy(b1, 0.16, 0.10, M_ST, Vector3(0, 0.24, 0), Vector3.ZERO, -1.0, 6)
	K.cy(b1, 0.088, 0.46, M_DK, Vector3(0, -0.02, 0), Vector3.ZERO, -1.0, 14)
	for r_i in 5:
		A.add(b1, A.torus(0.075, 0.098, 12), M_ST, Vector3(0, -0.18 + float(r_i) * 0.06, 0), Vector3.ZERO, Vector3(1, 0.35, 1), false)
	var b2 := K.node(root, Vector3(0.20, -0.05, -0.10), Vector3(72, -16, 48))
	K.cy(b2, 0.15, 0.09, M_BR, Vector3(0, 0.22, 0), Vector3.ZERO, -1.0, 6)
	K.cy(b2, 0.082, 0.40, M_DK, Vector3(0, -0.01, 0), Vector3.ZERO, -1.0, 14)
	# 六角螺母
	for np in [[Vector3(0.22, -0.18, 0.24), Vector3(24, 18, 12)], [Vector3(-0.24, -0.22, -0.18), Vector3(84, -24, 30)]]:
		K.cy(root, 0.135, 0.085, M_ST, np[0], np[1], -1.0, 6)
		K.cy(root, 0.068, 0.092, K.bore_mat(), np[0], np[1], -1.0, 12)
	return Vector3(0.58, 0.72, 0.78).normalized()


static func _build_hdd(root: Node3D) -> Vector3:
	var M_CASE := K.gunmetal()
	var M_DK := K.dark()
	var M_PLAT := A.chrome()
	var M_GOLD := K.brass()
	var b := K.node(root, Vector3.ZERO, Vector3(22, -24, 12))
	# 工业级铸铝硬盘壳 + 镜面高速磁盘 + 中央马达轴 + 音圈磁头读写臂
	K.bb(b, Vector3(0.64, 0.14, 0.88), M_CASE, Vector3.ZERO, Vector3.ZERO, 0.024)
	K.bb(b, Vector3(0.56, 0.04, 0.78), M_DK, Vector3(0, 0.06, 0), Vector3.ZERO, 0.015)
	K.cy(b, 0.25, 0.03, M_PLAT, Vector3(0, 0.085, -0.10), Vector3.ZERO, -1.0, 28)
	K.cy(b, 0.07, 0.045, M_CASE, Vector3(0, 0.095, -0.10), Vector3.ZERO, -1.0, 16)
	K.cy(b, 0.08, 0.05, M_GOLD, Vector3(0.18, 0.095, 0.24), Vector3.ZERO, -1.0, 14)
	K.bb(b, Vector3(0.06, 0.02, 0.34), M_PLAT, Vector3(0.08, 0.115, 0.08), Vector3(0, 28, 0), 0.004)
	K.bb(b, Vector3(0.36, 0.03, 0.08), M_GOLD, Vector3(-0.04, 0.02, 0.44), Vector3.ZERO, 0.005)
	return Vector3(0.45, 0.85, 0.62).normalized()


static func _build_toy(root: Node3D) -> Vector3:
	var M_GRN := A.paint(Color(0.24, 0.62, 0.26), 0.25, 0.34, {"wear": 0.25, "panel_scale": 0.0})
	var M_YEL := A.paint(Color(0.92, 0.78, 0.22), 0.15, 0.38, {"panel_scale": 0.0})
	var M_WHT := A.paint(Color(0.94, 0.94, 0.92), 0.05, 0.30, {"panel_scale": 0.0})
	var M_BR := K.brass()
	var M_BLK := K.bore_mat()
	var f := K.node(root, Vector3.ZERO, Vector3(0, 24, 0))
	# 复古发条铁皮小青蛙：绿铁壳身 + 鹅黄肚皮 + 大鼓眼 + 黄铜侧发条钥匙
	A.add(f, A.sphere(0.28, 0.42, 20), M_GRN, Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1.15, 0.78, 1.32), false)
	A.add(f, A.sphere(0.24, 0.30, 16), M_YEL, Vector3(0, -0.07, 0.06), Vector3.ZERO, Vector3(1.05, 0.65, 1.15), false)
	for sx in [-1.0, 1.0]:
		A.add(f, A.sphere(0.10, 0.20, 14), M_GRN, Vector3(sx * 0.17, 0.18, 0.20), Vector3.ZERO, Vector3.ONE, false)
		A.add(f, A.sphere(0.072, 0.14, 12), M_WHT, Vector3(sx * 0.17, 0.19, 0.24), Vector3.ZERO, Vector3.ONE, false)
		A.add(f, A.sphere(0.036, 0.07, 10), M_BLK, Vector3(sx * 0.17, 0.195, 0.285), Vector3.ZERO, Vector3.ONE, false)
		K.bb(f, Vector3(0.12, 0.08, 0.28), M_GRN, Vector3(sx * 0.28, -0.10, -0.10), Vector3(0, sx * 16.0, 0), 0.025)
	# 右侧突出大黄铜蝴蝶发条钥匙
	K.cy(f, 0.030, 0.20, M_BR, Vector3(0.32, 0.04, -0.02), Vector3(0, 0, 90), -1.0, 10)
	for ky in [-0.075, 0.075]:
		A.add(f, A.torus(0.042, 0.085, 14), M_BR, Vector3(0.45, 0.04 + ky, -0.02), Vector3(0, 0, 90), Vector3(1, 0.45, 1), false)
	return Vector3(0.68, 0.56, 0.80).normalized()


static func _build_chitin(root: Node3D) -> Vector3:
	var M_SH := A.chitin(Color(0.34, 0.22, 0.30))
	var M_EDGE := A.chitin(Color(0.22, 0.14, 0.20))
	var c := K.node(root, Vector3.ZERO, Vector3(12, -20, 8))
	# 分节弧形几丁质甲壳片（3片叠瓦式生物甲壳）
	for i in 3:
		var z := -0.18 + float(i) * 0.18
		var y := -float(i) * 0.04
		var sc := 1.0 - float(i) * 0.14
		K.plate(c, K.trap(0.56 * sc, 0.72 * sc, 0.30 * sc, 0.06), 0.10, M_SH if i % 2 == 0 else M_EDGE,
			Vector3(0, y, z), Vector3(-62.0 + float(i) * 8.0, 0, 0), 0.03)
	K.bb(c, Vector3(0.11, 0.12, 0.62), M_EDGE, Vector3(0, 0.08, 0.0), Vector3(-10, 0, 0), 0.03)
	return Vector3(0.68, 0.72, 0.66).normalized()


static func _build_bug_crystal(root: Node3D) -> Vector3:
	var M_ROCK := A.rock_mat(Color(0.16, 0.14, 0.18))
	var M_CRY := A.emit(Color(0.76, 0.26, 0.98), 1.85)
	var M_CRY2 := K.canopy(Color(0.48, 0.88, 0.98), 1.45)
	A.add(root, A.rock_mesh(2, 16), M_ROCK, Vector3(0, -0.22, 0), Vector3.ZERO, Vector3(0.42, 0.20, 0.38))
	# 五簇六棱晶柱
	var specs := [
		[Vector3(0.0, 0.16, 0.0), Vector3(6, 12, -4), 0.13, 0.52, M_CRY],
		[Vector3(-0.18, 0.08, 0.08), Vector3(14, -18, 22), 0.09, 0.38, M_CRY2],
		[Vector3(0.18, 0.10, -0.06), Vector3(-16, 25, -20), 0.10, 0.42, M_CRY],
		[Vector3(-0.08, 0.04, -0.16), Vector3(-24, 0, 12), 0.08, 0.32, M_CRY],
		[Vector3(0.12, 0.02, 0.16), Vector3(22, 10, -14), 0.075, 0.30, M_CRY2],
	]
	for sp in specs:
		var n := K.node(root, sp[0], sp[1])
		var r: float = sp[2]
		var h: float = sp[3]
		K.cy(n, r, h, sp[4], Vector3.ZERO, Vector3.ZERO, r * 0.88, 6)
		K.cy(n, 0.005, r * 1.4, sp[4], Vector3(0, h * 0.5 + r * 0.7, 0), Vector3.ZERO, r * 0.88, 6)
	return Vector3(0.65, 0.48, 0.82).normalized()


# ================================================================ 消耗品/战术道具类
static func _build_fuel_cell(root: Node3D) -> Vector3:
	var M_BODY := A.paint(Color(0.84, 0.58, 0.12), 0.25, 0.46, {"wear": 0.42, "panel_scale": 0.0})
	var M_CAP := K.gunmetal()
	var M_BR := K.brass()
	var M_GLOW := A.emit(Color(0.24, 0.88, 0.98), 1.65)
	# 军规黄黑工业能源卡匣：护框 + 双黄铜端子 + 发光电量条窗
	K.bb(root, Vector3(0.54, 0.66, 0.38), M_BODY, Vector3.ZERO, Vector3.ZERO, 0.035)
	K.bb(root, Vector3(0.58, 0.14, 0.42), M_CAP, Vector3(0, -0.27, 0), Vector3.ZERO, 0.02)
	K.bb(root, Vector3(0.58, 0.12, 0.42), M_CAP, Vector3(0, 0.28, 0), Vector3.ZERO, 0.02)
	for sx in [-0.14, 0.14]:
		K.cy(root, 0.055, 0.10, M_BR, Vector3(sx, 0.37, 0), Vector3.ZERO, -1.0, 12)
	K.bb(root, Vector3(0.14, 0.38, 0.03), K.bore_mat(), Vector3(0.12, 0, 0.19), Vector3.ZERO, 0.005)
	for gi in 4:
		K.bb(root, Vector3(0.09, 0.06, 0.02), M_GLOW, Vector3(0.12, -0.12 + float(gi) * 0.08, 0.20), Vector3.ZERO, 0.003)
	K.bb(root, Vector3(0.20, 0.06, 0.02), K.dark(), Vector3(-0.10, 0.10, 0.195), Vector3.ZERO, 0.004)
	return Vector3(0.68, 0.45, 0.82).normalized()


static func _build_repair_kit(root: Node3D) -> Vector3:
	var M_BOX := A.paint(Color(0.26, 0.34, 0.25), 0.18, 0.56, {"wear": 0.40, "panel_scale": 0.0})
	var M_LID := A.paint(Color(0.84, 0.86, 0.84), 0.12, 0.42, {"panel_scale": 0.0})
	var M_RED := A.paint(Color(0.82, 0.18, 0.16), 0.08, 0.48, {"panel_scale": 0.0})
	var M_DK := K.dark()
	# 装甲野战维修医疗盒 + 红十字标识 + 顶部提手 + 纳米凝胶喷嘴瓶
	K.bb(root, Vector3(0.74, 0.52, 0.44), M_BOX, Vector3(-0.04, -0.02, 0), Vector3.ZERO, 0.04)
	K.bb(root, Vector3(0.56, 0.34, 0.04), M_LID, Vector3(-0.04, 0.0, 0.22), Vector3.ZERO, 0.012)
	K.bb(root, Vector3(0.22, 0.07, 0.02), M_RED, Vector3(-0.04, 0.0, 0.242), Vector3.ZERO, 0.004)
	K.bb(root, Vector3(0.07, 0.22, 0.02), M_RED, Vector3(-0.04, 0.0, 0.242), Vector3.ZERO, 0.004)
	K.grab_iron(root, 0.28, 0.065, Vector3(-0.04, 0.25, 0), Vector3(-90, 0, 0), 0.022)
	for lx in [-0.26, 0.18]:
		K.bb(root, Vector3(0.06, 0.10, 0.04), A.chrome(), Vector3(lx, 0.16, 0.22), Vector3.ZERO, 0.006)
	K.cy(root, 0.08, 0.26, M_DK, Vector3(0.36, -0.10, 0.16), Vector3.ZERO, -1.0, 14)
	return Vector3(0.56, 0.50, 0.88).normalized()


static func _build_beacon(root: Node3D) -> Vector3:
	var M_BODY := K.armor(Color(0.28, 0.31, 0.35))
	var M_YEL := K.accent()
	var M_GLOW := A.emit(Color(0.30, 0.92, 0.96), 2.1)
	var M_ANT := A.chrome()
	# 军规高频撤离呼叫信标：折叠三角底座 + 高亮频闪信标灯 + 鞭状天线
	K.cy(root, 0.24, 0.14, M_BODY, Vector3(0, -0.14, 0), Vector3.ZERO, 0.28, 16)
	K.cy(root, 0.18, 0.20, M_YEL, Vector3(0, 0.02, 0), Vector3.ZERO, 0.16, 16)
	A.add(root, A.sphere(0.11, 0.16, 16), M_GLOW, Vector3(0, 0.16, 0), Vector3.ZERO, Vector3.ONE, false)
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.4
		K.bb(root, Vector3(0.06, 0.26, 0.08), K.gunmetal(), Vector3(cos(a) * 0.26, -0.24, sin(a) * 0.26), Vector3(sin(a) * 28.0, -rad_to_deg(a), 0), 0.01)
	K.cy(root, 0.016, 0.46, M_ANT, Vector3(0.14, 0.24, -0.06), Vector3(0, 0, -6), -1.0, 8)
	return Vector3(0.62, 0.48, 0.85).normalized()


static func _build_sonic_decoy(root: Node3D) -> Vector3:
	var M_MET := K.gunmetal()
	var M_HORN := A.metal(Color(0.32, 0.35, 0.32))
	var M_LURE := A.emit(Color(1.0, 0.72, 0.22), 2.1)
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.5
		K.bb(root, Vector3(0.055, 0.44, 0.055), M_MET, Vector3(cos(a) * 0.16, -0.16, sin(a) * 0.16), Vector3(sin(a) * 20.0, 0, -cos(a) * 20.0), 0.012)
	K.cy(root, 0.13, 0.16, M_MET, Vector3(0, 0.06, 0), Vector3.ZERO, 0.18, 16)
	K.cy(root, 0.26, 0.09, M_HORN, Vector3(0, 0.18, 0), Vector3.ZERO, 0.22, 18)
	K.cy(root, 0.016, 0.36, M_MET, Vector3(0.13, 0.34, 0), Vector3.ZERO, -1.0, 8)
	A.add(root, A.sphere(0.058, 0.116, 12), M_LURE, Vector3(0.13, 0.52, 0), Vector3.ZERO, Vector3.ONE, false)
	return Vector3(0.65, 0.48, 0.82).normalized()


static func _build_extract_flare(root: Node3D) -> Vector3:
	var M_CAN := A.paint(Color(0.28, 0.34, 0.24), 0.22, 0.50, {"wear": 0.38, "panel_scale": 0.0})
	var M_BAND := A.paint(Color(0.92, 0.36, 0.10), 0.12, 0.45, {"panel_scale": 0.0})
	var M_SPOON := K.gunmetal()
	var M_TOP := A.emit(Color(1.0, 0.42, 0.12), 1.65)
	var f := K.node(root, Vector3.ZERO, Vector3(12, 18, -18))
	# 高压烟幕手雷罐：桶身 + 橙色标志环 + 保险握把 + 拉环
	K.cy(f, 0.21, 0.58, M_CAN, Vector3.ZERO, Vector3.ZERO, -1.0, 20)
	K.cy(f, 0.216, 0.16, M_BAND, Vector3(0, 0.08, 0), Vector3.ZERO, -1.0, 20)
	K.cy(f, 0.14, 0.10, M_SPOON, Vector3(0, 0.33, 0), Vector3.ZERO, -1.0, 16)
	K.cy(f, 0.07, 0.04, M_TOP, Vector3(0, 0.38, 0), Vector3.ZERO, -1.0, 14)
	K.bb(f, Vector3(0.06, 0.38, 0.09), M_SPOON, Vector3(0.22, 0.12, 0), Vector3(0, 0, -8), 0.01)
	A.add(f, A.torus(0.055, 0.082, 16), A.chrome(), Vector3(-0.14, 0.34, 0.06), Vector3(25, 0, 25), Vector3(1, 0.4, 1), false)
	return Vector3(0.55, 0.45, 0.85).normalized()


static func _build_energy_rod(root: Node3D) -> Vector3:
	var M_DK := K.dark()
	var M_COP := K.copper()
	var M_GLOW := A.emit(Color(0.25, 0.88, 1.0), 1.85)
	var r := K.node(root, Vector3.ZERO, Vector3(18, -22, 34))
	# 超导高压电容棒：发亮等离子芯 + 铜绕圈 + 两端六角封头
	K.cy(r, 0.13, 0.68, M_GLOW, Vector3.ZERO, Vector3.ZERO, -1.0, 18)
	for cy_y in [-0.36, 0.36]:
		K.cy(r, 0.20, 0.12, M_DK, Vector3(0, cy_y, 0), Vector3.ZERO, -1.0, 6)
		K.cy(r, 0.14, 0.05, K.brass(), Vector3(0, cy_y + signf(cy_y) * 0.07, 0), Vector3.ZERO, -1.0, 12)
	for ci in [-0.18, 0.0, 0.18]:
		A.add(r, A.torus(0.13, 0.175, 18), M_COP, Vector3(0, ci, 0), Vector3.ZERO, Vector3(1, 0.55, 1), false)
	for ai in 3:
		var a := TAU * float(ai) / 3.0
		K.bb(r, Vector3(0.032, 0.66, 0.032), K.gunmetal(), Vector3(cos(a) * 0.165, 0, sin(a) * 0.165), Vector3.ZERO, 0.006)
	return Vector3(0.42, 0.38, 0.90).normalized()


static func _build_coolant_pack(root: Node3D) -> Vector3:
	var M_TANK := A.paint(Color(0.22, 0.46, 0.64), 0.38, 0.36, {"wear": 0.32, "panel_scale": 0.0})
	var M_FROST := A.paint(Color(0.76, 0.90, 0.98), 0.10, 0.45, {"panel_scale": 0.0})
	var M_CAP := K.gunmetal()
	var M_BR := K.brass()
	# 液氮冷却剂罐：蓝银压力钢瓶 + 阀门保护笼 + 黄铜压力表 + 冰蓝视窗
	K.cy(root, 0.24, 0.60, M_TANK, Vector3(0, -0.04, 0), Vector3.ZERO, -1.0, 22)
	A.add(root, A.sphere(0.24, 0.22, 20), M_FROST, Vector3(0, 0.24, 0), Vector3.ZERO, Vector3(1, 0.55, 1), false)
	for sy in [-0.22, 0.14]:
		A.add(root, A.torus(0.22, 0.255, 22), M_CAP, Vector3(0, sy, 0), Vector3.ZERO, Vector3(1, 0.5, 1), false)
	K.cy(root, 0.055, 0.14, M_BR, Vector3(0, 0.38, 0), Vector3.ZERO, -1.0, 12)
	K.cy(root, 0.095, 0.04, M_BR, Vector3(0.14, 0.36, 0.10), Vector3(90, 0, -24), -1.0, 14)
	K.bb(root, Vector3(0.055, 0.28, 0.03), A.emit(Color(0.40, 0.90, 1.0), 1.4), Vector3(0, -0.04, 0.24), Vector3.ZERO, 0.005)
	return Vector3(0.62, 0.48, 0.85).normalized()


static func _build_extract_barrier(root: Node3D) -> Vector3:
	var M_BASE := K.gunmetal()
	var M_DK := K.dark()
	var M_FLD := A.emit(Color(0.32, 0.95, 0.80), 1.85)
	# 便携力场发射器盘座 + 四向展翼支柱 + 悬浮发光偏转环
	K.cy(root, 0.36, 0.14, M_DK, Vector3(0, -0.14, 0), Vector3.ZERO, 0.42, 8)
	K.cy(root, 0.24, 0.12, M_BASE, Vector3(0, -0.02, 0), Vector3.ZERO, -1.0, 16)
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		K.bb(root, Vector3(0.075, 0.38, 0.075), M_BASE, Vector3(cos(a) * 0.26, 0.06, sin(a) * 0.26), Vector3(sin(a) * 14.0, -rad_to_deg(a), -cos(a) * 14.0), 0.012)
	A.add(root, A.torus(0.24, 0.31, 24), M_FLD, Vector3(0, 0.24, 0), Vector3.ZERO, Vector3(1, 0.55, 1), false)
	A.add(root, A.sphere(0.11, 0.22, 16), M_FLD, Vector3(0, 0.10, 0), Vector3.ZERO, Vector3.ONE, false)
	return Vector3(0.66, 0.62, 0.78).normalized()


static func _build_surge_cell(root: Node3D) -> Vector3:
	var M_FR := K.dark()
	var M_CAP := A.emit(Color(0.95, 0.32, 0.88), 1.75)
	var M_COP := K.copper()
	var M_HAZ := K.accent()
	# 三联过载脉冲电容模组 + 铜汇流条 + 警告框
	K.bb(root, Vector3(0.68, 0.22, 0.46), M_FR, Vector3(0, -0.22, 0), Vector3.ZERO, 0.025)
	K.bb(root, Vector3(0.68, 0.10, 0.46), M_HAZ, Vector3(0, 0.24, 0), Vector3.ZERO, 0.02)
	for ix in [-0.20, 0.0, 0.20]:
		K.cy(root, 0.088, 0.42, M_CAP, Vector3(ix, 0.02, 0), Vector3.ZERO, -1.0, 14)
		K.cy(root, 0.092, 0.05, K.gunmetal(), Vector3(ix, 0.14, 0), Vector3.ZERO, -1.0, 14)
	K.bb(root, Vector3(0.56, 0.04, 0.08), M_COP, Vector3(0, 0.30, 0.08), Vector3.ZERO, 0.005)
	K.bb(root, Vector3(0.56, 0.04, 0.08), M_COP, Vector3(0, 0.30, -0.08), Vector3.ZERO, 0.005)
	return Vector3(0.62, 0.46, 0.84).normalized()


# ================================================================ 货币/贵重品类
static func _build_credit_chip(root: Node3D, large: bool) -> Vector3:
	var M_CARD := A.metal(Color(0.16, 0.18, 0.22) if large else Color(0.24, 0.28, 0.34))
	var M_GOLD := K.brass()
	var M_GLOW := A.emit(Color(0.98, 0.78, 0.18) if large else Color(0.26, 0.84, 0.98), 1.6)
	var n := K.node(root, Vector3.ZERO, Vector3(24, -22, 16))
	# 加密信用芯片卡（大额叠放两张+金框+多条光条）
	var count := 2 if large else 1
	for ci in count:
		var yo := float(ci) * 0.09
		K.bb(n, Vector3(0.84, 0.06, 0.54), M_GOLD if (large and ci == 0) else M_CARD, Vector3(float(ci) * 0.04, yo, float(ci) * -0.04), Vector3.ZERO, 0.015)
	var top_y := float(count - 1) * 0.09 + 0.032
	K.bb(n, Vector3(0.22, 0.016, 0.18), M_GOLD, Vector3(-0.22, top_y, 0.05), Vector3.ZERO, 0.004)
	K.bb(n, Vector3(0.46, 0.016, 0.07), M_GLOW, Vector3(0.10, top_y, -0.10), Vector3.ZERO, 0.004)
	if large:
		K.bb(n, Vector3(0.32, 0.016, 0.05), M_GLOW, Vector3(0.16, top_y, 0.08), Vector3.ZERO, 0.004)
	return Vector3(0.40, 0.82, 0.58).normalized()


static func _build_gold(root: Node3D) -> Vector3:
	# 2×1 横向纪念金条：斜边梯形金锭 + 凹印旧世界央行钢印（亮泽高金属度）
	var M_AU := A.paint(Color(0.96, 0.78, 0.22), 0.94, 0.20, {"wear": 0.06, "panel_scale": 0.0})
	var M_STAMP := A.paint(Color(0.76, 0.56, 0.12), 0.88, 0.28, {"wear": 0.05, "panel_scale": 0.0})
	K.bb(root, Vector3(1.52, 0.32, 0.62), M_AU, Vector3.ZERO, Vector3.ZERO, 0.045, 0.78)
	K.bb(root, Vector3(0.88, 0.025, 0.34), M_STAMP, Vector3(0, 0.162, 0), Vector3.ZERO, 0.008)
	K.bb(root, Vector3(0.24, 0.032, 0.24), M_AU, Vector3(-0.22, 0.17, 0), Vector3.ZERO, 0.006)
	K.bb(root, Vector3(0.30, 0.032, 0.24), M_AU, Vector3(0.20, 0.17, 0), Vector3.ZERO, 0.006)
	A.stencil(root, "AU 999.9", Vector3(0.0, 0.195, 0.0), Vector3(-90, 0, 0), 0.0030, Color(0.55, 0.36, 0.06, 0.95))
	return Vector3(0.24, 0.82, 0.65).normalized()


# ================================================================ 赠礼道具类（5 款）
static func _build_gift_watch(root: Node3D) -> Vector3:
	var M_BR := K.brass()
	var M_DIAL := A.paint(Color(0.94, 0.92, 0.84), 0.04, 0.35, {"panel_scale": 0.0})
	var M_HAND := K.dark()
	var w := K.node(root, Vector3.ZERO, Vector3(58, -18, 12))
	# 黄铜古董怀表 + 白表盘 + 指针 + 顶部表冠表环 + 半开铜盖
	K.cy(w, 0.34, 0.10, M_BR, Vector3.ZERO, Vector3.ZERO, -1.0, 26)
	K.cy(w, 0.28, 0.02, M_DIAL, Vector3(0, 0.052, 0), Vector3.ZERO, -1.0, 24)
	K.bb(w, Vector3(0.025, 0.015, 0.18), M_HAND, Vector3(0.03, 0.064, -0.05), Vector3(0, -28, 0), 0.003)
	K.bb(w, Vector3(0.020, 0.015, 0.13), M_HAND, Vector3(-0.04, 0.066, -0.02), Vector3(0, 52, 0), 0.003)
	K.cy(w, 0.055, 0.09, M_BR, Vector3(0, 0.0, -0.37), Vector3(90, 0, 0), -1.0, 12)
	A.add(w, A.torus(0.075, 0.105, 16), M_BR, Vector3(0, 0.0, -0.45), Vector3.ZERO, Vector3(1, 0.4, 1), false)
	# 半开翘起的表盖
	K.cy(w, 0.33, 0.035, M_BR, Vector3(-0.34, 0.22, 0.0), Vector3(0, 0, 62), -1.0, 24)
	return Vector3(0.32, 0.56, 0.86).normalized()


static func _build_gift_wrench(root: Node3D) -> Vector3:
	var M_ST := A.chrome()
	var M_DK := K.gunmetal()
	var w := K.node(root, Vector3.ZERO, Vector3(0, 0, 38))
	# 钨钢开口/梅花双头扳手（工业铬钢闪光）
	K.bb(w, Vector3(0.78, 0.12, 0.07), M_DK, Vector3.ZERO, Vector3.ZERO, 0.02)
	K.bb(w, Vector3(0.62, 0.06, 0.085), M_ST, Vector3.ZERO, Vector3.ZERO, 0.008)
	# 左侧梅花头
	K.cy(w, 0.145, 0.08, M_ST, Vector3(-0.39, 0.0, 0.0), Vector3(90, 0, 0), -1.0, 16)
	K.cy(w, 0.075, 0.09, K.bore_mat(), Vector3(-0.39, 0.0, 0.0), Vector3(90, 0, 0), -1.0, 12)
	# 右侧 C 型开口钳头
	K.cy(w, 0.175, 0.08, M_ST, Vector3(0.40, 0.0, 0.0), Vector3(90, 0, 0), -1.0, 16)
	K.bb(w, Vector3(0.20, 0.12, 0.10), K.bore_mat(), Vector3(0.50, 0.0, 0.0), Vector3.ZERO, 0.006)
	return Vector3(0.22, 0.36, 0.92).normalized()


static func _build_gift_cocoa(root: Node3D) -> Vector3:
	var M_TIN := A.paint(Color(0.52, 0.16, 0.18), 0.28, 0.44, {"wear": 0.25, "panel_scale": 0.0})
	var M_LBL := A.paint(Color(0.90, 0.84, 0.70), 0.06, 0.56, {"panel_scale": 0.0})
	var M_BR := K.brass()
	# 精装八角铁皮可可粉铁罐 + 黄铜顶盖 + 金边装饰
	K.bb(root, Vector3(0.52, 0.64, 0.42), M_TIN, Vector3(0, -0.02, 0), Vector3.ZERO, 0.045)
	K.bb(root, Vector3(0.54, 0.10, 0.44), M_BR, Vector3(0, 0.29, 0), Vector3.ZERO, 0.025)
	K.bb(root, Vector3(0.53, 0.28, 0.43), M_LBL, Vector3(0, 0.0, 0), Vector3.ZERO, 0.015)
	K.cy(root, 0.09, 0.04, M_BR, Vector3(0, 0.36, 0), Vector3.ZERO, -1.0, 16)
	A.stencil(root, "COCOA", Vector3(0, 0.0, 0.22), Vector3.ZERO, 0.0028, Color(0.42, 0.14, 0.12, 0.95))
	return Vector3(0.65, 0.52, 0.80).normalized()


static func _build_gift_chart(root: Node3D) -> Vector3:
	var M_COV := A.paint(Color(0.16, 0.24, 0.38), 0.12, 0.68, {"wear": 0.25, "panel_scale": 0.0})
	var M_PAGE := A.paint(Color(0.90, 0.85, 0.74), 0.0, 0.85, {"panel_scale": 0.0})
	var M_BR := K.brass()
	var n := K.node(root, Vector3.ZERO, Vector3(28, -22, 12))
	# 海军蓝精装硬壳航线图册 + 烫金罗盘徽 + 旁配黄铜航图卷筒
	K.bb(n, Vector3(0.62, 0.11, 0.78), M_COV, Vector3(-0.08, 0, 0), Vector3.ZERO, 0.02)
	K.bb(n, Vector3(0.57, 0.08, 0.72), M_PAGE, Vector3(-0.06, 0, 0), Vector3.ZERO, 0.008)
	K.cy(n, 0.14, 0.02, M_BR, Vector3(-0.08, 0.06, 0), Vector3.ZERO, -1.0, 18)
	K.cy(n, 0.095, 0.74, M_BR, Vector3(0.32, 0.08, 0.0), Vector3(90, 0, 0), -1.0, 16)
	for ez in [-0.34, 0.34]:
		K.cy(n, 0.105, 0.08, K.copper(), Vector3(0.32, 0.08, ez), Vector3(90, 0, 0), -1.0, 16)
	return Vector3(0.44, 0.82, 0.60).normalized()


static func _build_gift_flask(root: Node3D) -> Vector3:
	var M_SIL := A.chrome()
	var M_CAP := K.brass()
	var M_BND := A.paint(Color(0.36, 0.22, 0.14), 0.05, 0.78, {"panel_scale": 0.0})
	var f := K.node(root, Vector3.ZERO, Vector3(8, 22, -8))
	# 拉丝银扁酒壶 + 皮革裹腰 + 旋钮黄铜盖
	K.bb(f, Vector3(0.50, 0.62, 0.22), M_SIL, Vector3(0, -0.04, 0), Vector3.ZERO, 0.055)
	K.bb(f, Vector3(0.515, 0.26, 0.235), M_BND, Vector3(0, -0.04, 0), Vector3.ZERO, 0.03)
	K.cy(f, 0.068, 0.14, M_SIL, Vector3(0.08, 0.30, 0), Vector3.ZERO, -1.0, 14)
	K.cy(f, 0.082, 0.08, M_CAP, Vector3(0.08, 0.37, 0), Vector3.ZERO, -1.0, 14)
	return Vector3(0.58, 0.45, 0.85).normalized()


# ================================================================ 档案/文献类（12 款差异化模型）
static func _build_archive_clipboard(root: Node3D, board_c: Color, stripe_c: Color, code: String) -> Vector3:
	var M_BD := A.paint(board_c, 0.22, 0.62, {"panel_scale": 0.0})
	var M_PG := A.paint(Color(0.91, 0.88, 0.80), 0.0, 0.85, {"panel_scale": 0.0})
	var M_LINE := A.paint(Color(0.28, 0.30, 0.34), 0.0, 0.85, {"panel_scale": 0.0})
	var M_STR := A.paint(stripe_c, 0.10, 0.55, {"panel_scale": 0.0})
	var n := K.node(root, Vector3.ZERO, Vector3(26, -16, 10))
	K.bb(n, Vector3(0.64, 0.045, 0.86), M_BD, Vector3.ZERO, Vector3.ZERO, 0.015)
	K.bb(n, Vector3(0.54, 0.025, 0.72), M_PG, Vector3(0, 0.03, 0.03), Vector3.ZERO, 0.006)
	K.bb(n, Vector3(0.24, 0.055, 0.10), A.chrome(), Vector3(0, 0.055, -0.37), Vector3.ZERO, 0.012)
	K.bb(n, Vector3(0.46, 0.012, 0.055), M_STR, Vector3(0, 0.046, -0.22), Vector3.ZERO, 0.002)
	for li in 4:
		var lw := 0.42 if li < 3 else 0.28
		K.bb(n, Vector3(lw, 0.010, 0.028), M_LINE, Vector3(-0.21 + lw * 0.5, 0.046, -0.06 + float(li) * 0.085), Vector3.ZERO, 0.002)
	A.stencil(n, code, Vector3(0.0, 0.052, 0.30), Vector3(-90, 0, 0), 0.0022, Color(0.18, 0.20, 0.24, 0.9))
	return Vector3(0.32, 0.84, 0.58).normalized()


static func _build_archive_binder(root: Node3D, cov_c: Color, badge_c: Color, has_vial: bool) -> Vector3:
	var M_COV := A.paint(cov_c, 0.16, 0.58, {"panel_scale": 0.0})
	var M_PG := A.paint(Color(0.92, 0.90, 0.82), 0.0, 0.85, {"panel_scale": 0.0})
	var M_BADGE := A.paint(badge_c, 0.18, 0.42, {"panel_scale": 0.0})
	var n := K.node(root, Vector3.ZERO, Vector3(24, -22, 12))
	K.bb(n, Vector3(0.64, 0.12, 0.80), M_COV, Vector3(-0.04, 0, 0), Vector3.ZERO, 0.02)
	K.bb(n, Vector3(0.58, 0.09, 0.74), M_PG, Vector3(-0.02, 0, 0), Vector3.ZERO, 0.008)
	K.bb(n, Vector3(0.10, 0.135, 0.81), K.dark(), Vector3(-0.31, 0, 0), Vector3.ZERO, 0.014)
	for ri in 4:
		A.add(n, A.torus(0.026, 0.045, 12), A.chrome(), Vector3(-0.32, 0.04, -0.24 + float(ri) * 0.16), Vector3(0, 90, 0), Vector3(1, 0.5, 1), false)
	K.bb(n, Vector3(0.28, 0.015, 0.12), M_BADGE, Vector3(0.02, 0.068, -0.14), Vector3.ZERO, 0.004)
	if has_vial:
		K.cy(n, 0.075, 0.44, A.glass(badge_c), Vector3(0.32, 0.08, 0.04), Vector3(90, 0, -14), -1.0, 14)
		K.cy(n, 0.055, 0.28, A.emit(badge_c, 0.9), Vector3(0.32, 0.08, 0.04), Vector3(90, 0, -14), -1.0, 12)
	return Vector3(0.42, 0.82, 0.62).normalized()


static func _build_archive_flight_log(root: Node3D) -> Vector3:
	var M_ORANGE := A.paint(Color(0.88, 0.36, 0.10), 0.28, 0.46, {"wear": 0.42, "panel_scale": 0.0})
	var M_PG := A.paint(Color(0.90, 0.86, 0.78), 0.0, 0.85, {"panel_scale": 0.0})
	# 黑匣子橙色存储模组 + 残缺航行日志页
	K.bb(root, Vector3(0.56, 0.34, 0.56), M_ORANGE, Vector3(-0.08, 0.04, -0.06), Vector3(8, 22, -6), 0.03)
	K.bb(root, Vector3(0.48, 0.04, 0.48), K.gunmetal(), Vector3(-0.08, 0.22, -0.06), Vector3(8, 22, -6), 0.01)
	K.bb(root, Vector3(0.56, 0.025, 0.44), M_PG, Vector3(0.16, -0.14, 0.20), Vector3(14, -18, 6), 0.005)
	return Vector3(0.54, 0.68, 0.78).normalized()


static func _build_archive_blueprint(root: Node3D) -> Vector3:
	var M_BLUE := A.paint(Color(0.10, 0.32, 0.68), 0.08, 0.76, {"panel_scale": 0.0})
	var M_LINE := A.paint(Color(0.86, 0.94, 1.0), 0.0, 0.50, {"panel_scale": 0.0})
	var b := K.node(root, Vector3.ZERO, Vector3(22, -20, 10))
	# 展开半卷蓝图：亮蓝图纸 + 白色工程线框 + 右侧卷筒
	K.bb(b, Vector3(0.76, 0.022, 0.60), M_BLUE, Vector3(-0.06, 0, 0), Vector3.ZERO, 0.005)
	K.bb(b, Vector3(0.58, 0.008, 0.02), M_LINE, Vector3(-0.08, 0.015, -0.16), Vector3.ZERO, 0.001)
	K.bb(b, Vector3(0.58, 0.008, 0.02), M_LINE, Vector3(-0.08, 0.015, 0.16), Vector3.ZERO, 0.001)
	K.bb(b, Vector3(0.02, 0.008, 0.32), M_LINE, Vector3(-0.36, 0.015, 0), Vector3.ZERO, 0.001)
	K.bb(b, Vector3(0.24, 0.010, 0.18), M_LINE, Vector3(-0.10, 0.016, 0.0), Vector3.ZERO, 0.002)
	K.cy(b, 0.085, 0.62, M_BLUE, Vector3(0.32, 0.075, 0), Vector3(90, 0, 0), -1.0, 18)
	K.cy(b, 0.062, 0.63, K.dark(), Vector3(0.32, 0.075, 0), Vector3(90, 0, 0), -1.0, 14)
	return Vector3(0.38, 0.85, 0.60).normalized()


static func _build_archive_tape(root: Node3D) -> Vector3:
	var M_SH := A.paint(Color(0.14, 0.15, 0.17), 0.15, 0.42, {"panel_scale": 0.0})
	var M_LBL := A.paint(Color(0.92, 0.64, 0.22), 0.04, 0.68, {"panel_scale": 0.0})
	var M_REEL := A.paint(Color(0.88, 0.88, 0.86), 0.04, 0.50, {"panel_scale": 0.0})
	var t := K.node(root, Vector3.ZERO, Vector3(32, -16, 12))
	# 老式盒式录音磁带：暗色透明壳 + 琥珀标签 + 双齿轮带盘
	K.bb(t, Vector3(0.84, 0.14, 0.54), M_SH, Vector3.ZERO, Vector3.ZERO, 0.018)
	K.bb(t, Vector3(0.70, 0.016, 0.32), M_LBL, Vector3(0, 0.072, -0.04), Vector3.ZERO, 0.005)
	for rx in [-0.18, 0.18]:
		K.cy(t, 0.09, 0.04, M_REEL, Vector3(rx, 0.076, -0.02), Vector3.ZERO, -1.0, 14)
		K.cy(t, 0.04, 0.05, K.dark(), Vector3(rx, 0.076, -0.02), Vector3.ZERO, -1.0, 8)
	K.bb(t, Vector3(0.56, 0.06, 0.08), K.gunmetal(), Vector3(0, 0.06, 0.24), Vector3.ZERO, 0.006)
	return Vector3(0.30, 0.82, 0.62).normalized()


static func _build_archive_photo(root: Node3D) -> Vector3:
	var M_FRM := A.paint(Color(0.92, 0.90, 0.82), 0.0, 0.72, {"panel_scale": 0.0})
	var M_PIC := A.paint(Color(0.46, 0.38, 0.28), 0.05, 0.65, {"panel_scale": 0.0})
	var M_SKY := A.paint(Color(0.68, 0.62, 0.50), 0.05, 0.65, {"panel_scale": 0.0})
	# 两张错叠的拍立得泛黄照片
	for i in 2:
		var p := K.node(root, Vector3(0.10 if i == 0 else -0.08, 0.03 * float(i), 0.04 if i == 0 else -0.04), Vector3(24, -18 + float(i) * 24.0, 8 - float(i) * 18.0))
		K.bb(p, Vector3(0.56, 0.022, 0.68), M_FRM, Vector3.ZERO, Vector3.ZERO, 0.006)
		K.bb(p, Vector3(0.46, 0.012, 0.44), M_SKY, Vector3(0, 0.012, -0.05), Vector3.ZERO, 0.002)
		K.bb(p, Vector3(0.46, 0.014, 0.20), M_PIC, Vector3(0, 0.013, 0.07), Vector3.ZERO, 0.002)
	return Vector3(0.34, 0.85, 0.56).normalized()


static func _build_archive_letter(root: Node3D) -> Vector3:
	var M_ENV := A.paint(Color(0.88, 0.82, 0.68), 0.0, 0.82, {"panel_scale": 0.0})
	var M_PAPER := A.paint(Color(0.95, 0.94, 0.90), 0.0, 0.85, {"panel_scale": 0.0})
	var M_WAX := A.paint(Color(0.72, 0.14, 0.14), 0.10, 0.38, {"panel_scale": 0.0})
	var l := K.node(root, Vector3.ZERO, Vector3(26, -18, 10))
	K.bb(l, Vector3(0.82, 0.045, 0.54), M_ENV, Vector3.ZERO, Vector3.ZERO, 0.012)
	K.bb(l, Vector3(0.68, 0.025, 0.46), M_PAPER, Vector3(0.06, 0.032, -0.14), Vector3(0, 12, 0), 0.005)
	K.cy(l, 0.095, 0.035, M_WAX, Vector3(-0.08, 0.036, 0.04), Vector3.ZERO, -1.0, 16)
	return Vector3(0.36, 0.86, 0.58).normalized()


static func _build_archive_drawing(root: Node3D) -> Vector3:
	var M_PG := A.paint(Color(0.96, 0.95, 0.88), 0.0, 0.86, {"panel_scale": 0.0})
	var M_CR1 := A.paint(Color(0.90, 0.24, 0.20), 0.0, 0.62, {"panel_scale": 0.0})
	var M_CR2 := A.paint(Color(0.94, 0.78, 0.18), 0.0, 0.62, {"panel_scale": 0.0})
	var M_CR3 := A.paint(Color(0.24, 0.62, 0.88), 0.0, 0.62, {"panel_scale": 0.0})
	var n := K.node(root, Vector3.ZERO, Vector3(24, -18, 12))
	K.bb(n, Vector3(0.76, 0.024, 0.62), M_PG, Vector3.ZERO, Vector3.ZERO, 0.006)
	# 蜡笔画房子太阳涂鸦 + 两支斜放彩色蜡笔
	K.cy(n, 0.09, 0.012, M_CR2, Vector3(0.18, 0.016, -0.14), Vector3.ZERO, -1.0, 14)
	K.bb(n, Vector3(0.20, 0.012, 0.18), M_CR3, Vector3(-0.14, 0.016, 0.06), Vector3.ZERO, 0.002)
	K.bb(n, Vector3(0.24, 0.014, 0.10), M_CR1, Vector3(-0.14, 0.016, -0.07), Vector3.ZERO, 0.002)
	for c_spec in [[Vector3(0.24, 0.05, 0.12), Vector3(90, 32, 0), M_CR1], [Vector3(0.32, 0.045, 0.02), Vector3(90, -18, 0), M_CR3]]:
		K.cy(n, 0.036, 0.36, c_spec[2], c_spec[0], c_spec[1], -1.0, 10)
	return Vector3(0.34, 0.86, 0.56).normalized()
