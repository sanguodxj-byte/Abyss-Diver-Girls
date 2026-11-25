extends RefCounted
## 六大战区新增地标级重工业建筑（与专属地标首领配套，预留完整可通行的前场/中庭首领战竞技台）：
##   - central_terminus  灰港市 · 中央穹顶总站（大跨度铆接钢桁拱顶列车棚 + 钟楼门廊立面 + 双线沉降站台）
##   - converter_foundry 铁锈工业带 · 二号转炉钢厂（重型氧气顶吹转炉耳轴倾动台 + 21m 烟罩排气塔 + 跨庭铸锭天车梁）
##   - missile_silo      尘土平原 · 洲际发射井阵地（硬化混凝土发射坪 + 双扇液压开启八角防爆井盖 + 冷发射脐带塔）
##   - spillway_dam      赤湖新区 · 赤湖溢洪闸枢（阶梯扶壁混凝土重力坝 + 双孔弧形钢制溢洪闸门 + 坝顶启闭机廊桥）
##   - bucket_excavator  裂谷矿区 · 斗轮挖掘机平台（双履带巨型斗轮采掘机主机 + 配重桁臂 + 悬挑十斗切削轮）
##   - geothermal_vault  零号深渊井 · 地热磁约束腔（八角加劲钢肋压力安全壳 + 裂隙泄压穹顶 + 双联地热冷凝换热塔）

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/map_ext/poi_kit.gd")
const PrefabLib = preload("res://scripts/buildings/prefab_lib.gd")

const STEEL := Color(0.30, 0.31, 0.32)
const DARK_STEEL := Color(0.18, 0.19, 0.21)
const CONCRETE := Color(0.47, 0.45, 0.41)
const CONC_DARK := Color(0.35, 0.34, 0.31)


static func is_boss_landmark(t: String) -> bool:
	return t in [
		"central_terminus", "converter_foundry", "missile_silo",
		"spillway_dam", "bucket_excavator", "geothermal_vault", "submarine_drydock",
	]


## 返回该地标的首领竞技台中心（世界 XZ 平面坐标 Vector3）
static func arena_pos(t: String, p: Vector3, rot: float) -> Vector3:
	var local := Vector3(0.0, 0.0, 4.2)
	if t == "central_terminus":
		local = Vector3(0.0, 0.0, 1.5)
	elif t == "bucket_excavator":
		local = Vector3(0.0, 0.0, 5.2)
	elif t == "submarine_drydock":
		local = Vector3(0.0, 0.0, 4.8)
	return p + local.rotated(Vector3.UP, deg_to_rad(rot))


static func build(raid, t: String, p: Vector3, rot: float) -> bool:
	match t:
		"central_terminus":
			_central_terminus(raid, p, rot)
			return true
		"converter_foundry":
			_converter_foundry(raid, p, rot)
			return true
		"missile_silo":
			_missile_silo(raid, p, rot)
			return true
		"spillway_dam":
			_spillway_dam(raid, p, rot)
			return true
		"bucket_excavator":
			_bucket_excavator(raid, p, rot)
			return true
		"geothermal_vault":
			_geothermal_vault(raid, p, rot)
			return true
		"submarine_drydock":
			_submarine_drydock(raid, p, rot)
			return true
	return false


static func _add_pillar_block(raid, p: Vector3, local_pos: Vector3, size: Vector3, rot: float, cyl := false) -> void:
	var rad := deg_to_rad(rot)
	var wp := p + local_pos.rotated(Vector3.UP, rad)
	K.blocker(raid, wp, size, rot, cyl)
	var fp := size
	if not cyl and absf(fmod(absf(rot), 180.0) - 90.0) < 45.0:
		fp = Vector3(size.z, size.y, size.x)
	raid.blocks.append(raid._rect_for(wp, Vector3(fp.x, 1.0, fp.z)))


static func _place_world_prefab(raid, p: Vector3, rot: float, id: String, local_pos: Vector3, local_yaw: float, sz: Vector3) -> void:
	var wp := p + local_pos.rotated(Vector3.UP, deg_to_rad(rot))
	PrefabLib.place_at_ground(raid, raid.world, id, wp, rot + local_yaw, sz, false, null, false)


# ---------------------------------------------------------------- 1. 灰港市：中央穹顶总站 (central_terminus)
static func _central_terminus(raid, p: Vector3, rot: float) -> void:
	# Wave5 重制：塌顶拱形站厅 + 崩角西主站房 + 歪斜钟楼（lm_central_terminus_remake 23×13.8×17）
	# 保留中央轨道与站台贯通走廊供 arena_pos (0,0,1.5) 首领决战，碰撞体仅包覆西主站房与南北外侧拱廊墙
	var sz := Vector3(23.0, 13.8, 17.0)
	_place_world_prefab(raid, p, rot, "lm_central_terminus_remake", Vector3(0.0, -0.04, 0.0), 0.0, sz)
	_add_pillar_block(raid, p, Vector3(-7.6, 0.0, 0.0), Vector3(5.4, 12.0, 14.2), rot)
	_add_pillar_block(raid, p, Vector3(2.5, 0.0, -7.2), Vector3(14.6, 6.2, 1.0), rot)
	_add_pillar_block(raid, p, Vector3(2.5, 0.0, 7.2), Vector3(14.6, 6.2, 1.0), rot)
	raid.blocks.append(raid._rect_for(p, Vector3(23.2, 1.0, 17.2)))


# ---------------------------------------------------------------- 2. 铁锈工业带：二号转炉钢厂 (converter_foundry)
static func _converter_foundry(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M_CON := A.concrete(Color(0.34, 0.32, 0.30), true)
	var M_ST := A.paint(Color(0.29, 0.31, 0.34), 0.70, 0.44, {"rust": 0.65, "wear": 0.58, "panel_scale": 1.35})
	# 前场敞开铸锭地坪（z ∈ [-1..+12]，与 arena_pos (0,0,4.2) 对齐作首领战场地）
	A.add(n, A.bevel_box(Vector3(22.0, 0.14, 15.0), 0.04), M_CON, Vector3(0, 0.07, 5.0), Vector3.ZERO, Vector3.ONE, false)
	for di in 4:
		var dz := 0.8 + float(di) * 2.8
		A.add(n, A.bevel_box(Vector3(15.6, 0.04, 1.0), 0.015), M_ST, Vector3(0, 0.16, dz), Vector3.ZERO, Vector3.ONE, false)
	# 后场主体重型转炉铸造车间残骸（bld_converter_foundry，倾翻铁水包 + 断缆天车 + 36 段洗涤烟囱）
	var sz := Vector3(17.8, 15.5, 15.2)
	var fz := -7.2
	_place_world_prefab(raid, p, rot, "bld_converter_foundry", Vector3(0.0, -0.05, fz), 0.0, sz)
	var sx_sc := sz.x / 10.8
	var sz_sc := sz.z / 9.2
	# 转炉双耳轴巨墩与四根天车排架柱碰撞（全部位于 z <= 0，不侵占前方首领战场地）
	for sgn: float in [-1.0, 1.0]:
		_add_pillar_block(raid, p, Vector3(sgn * 4.85 * sx_sc, 0.0, fz - 3.95 * sz_sc), Vector3(1.6, 13.0, 1.6), rot)
		_add_pillar_block(raid, p, Vector3(sgn * 4.85 * sx_sc, 0.0, fz + 3.75 * sz_sc), Vector3(1.6, 13.0, 1.6), rot)
		_add_pillar_block(raid, p, Vector3(sgn * 2.65 * sx_sc, 0.0, fz - 1.05 * sz_sc), Vector3(2.4, 8.0, 3.6), rot)
	_add_pillar_block(raid, p, Vector3(0.52 * sx_sc, 0.0, fz + 2.38 * sz_sc), Vector3(3.4, 3.8, 3.4), rot, true)
	var ml := OmniLight3D.new()
	ml.light_color = Color(1.0, 0.48, 0.14)
	ml.light_energy = 6.0
	ml.omni_range = 24.0
	ml.shadow_enabled = false
	ml.position = Vector3(0.0, 6.2, fz + 0.8)
	n.add_child(ml)


# ---------------------------------------------------------------- 3. 尘土平原：洲际发射井阵地 (missile_silo)
static func _missile_silo(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M_CON := A.concrete(Color(0.49, 0.46, 0.40), true)
	var M_CDK := A.concrete(Color(0.34, 0.32, 0.29), false)
	var M_HAZ := A.hazard()
	# 前场硬化发射坪（z ∈ [+0.2..+12.0] 完全敞开，与 arena_pos (0,0,4.2) 对齐作首领竞技台）
	A.add(n, A.bevel_box(Vector3(21.0, 0.14, 13.2), 0.04), M_CON, Vector3(0, 0.07, 5.8), Vector3.ZERO, Vector3.ONE, false)
	for ix in 3:
		var bx := -5.4 + float(ix) * 5.4
		A.add(n, A.bevel_box(Vector3(5.0, 0.04, 8.6), 0.02), M_CDK, Vector3(bx, 0.15, 5.8), Vector3.ZERO, Vector3.ONE, false)
	for sx: float in [-1.0, 1.0]:
		A.add(n, A.bevel_box(Vector3(0.42, 0.03, 11.2), 0.015), M_HAZ, Vector3(sx * 8.4, 0.155, 5.8), Vector3.ZERO, Vector3.ONE, false)
	var blast_decal := A.ground_decal(n, A.scorch_tex(), Color(0.18, 0.16, 0.15, 0.65), 10.8, Vector3(0.0, 0.18, 2.2))
	blast_decal.rotation.y = 0.45
	# Wave5 重制：战略地下导弹发射井爆裂井口 + 半掀双扇防爆巨门 + 崩角发控地堡（lm_missile_silo_remake 19×11.4×19）
	# 后置并旋转 180° 使排焰导流槽居后、井口与控堡位于 z <= -0.5，前场首领竞技台零遮挡
	var sz := Vector3(17.5, 11.2, 16.5)
	var silo_z := -7.8
	_place_world_prefab(raid, p, rot, "lm_missile_silo_remake", Vector3(0.0, -0.04, silo_z), 180.0, sz)
	var sx_sc := sz.x / 19.0
	var sz_sc := sz.z / 19.0
	_add_pillar_block(raid, p, Vector3(-1.4 * sx_sc, 0.0, silo_z + 0.6 * sz_sc), Vector3(8.2, 4.4, 8.2), rot, true)
	_add_pillar_block(raid, p, Vector3(6.35 * sx_sc, 0.0, silo_z + 5.25 * sz_sc), Vector3(4.8, 4.5, 5.2), rot)
	raid.blocks.append(raid._rect_for(p + Vector3(0.0, 0.0, silo_z).rotated(Vector3.UP, deg_to_rad(rot)), Vector3(17.8, 1.0, 16.8)))


# ---------------------------------------------------------------- 4. 赤湖新区：赤湖溢洪闸枢 (spillway_dam)
static func _spillway_dam(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M_CON := A.concrete(Color(0.48, 0.47, 0.44), true)
	var M_WET := A.concrete(Color(0.31, 0.32, 0.30), false)
	var M_ST := A.paint(Color(0.24, 0.30, 0.33), 0.62, 0.50, {"rust": 0.68, "wear": 0.56})
	var M_RST := A.paint(Color(0.36, 0.23, 0.15), 0.52, 0.66, {"rust": 0.88, "wear": 0.60})
	var M_HAZ := A.hazard()
	# 消力池混凝土护坦前场（长宽 24m，平齐可战）+ 导流消力齿墩（低矮倒角不卡步足）
	A.add(n, A.bevel_box(Vector3(24.0, 0.16, 25.0), 0.05), M_WET, Vector3(0, 0.08, 0.6), Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.bevel_box(Vector3(18.6, 0.08, 14.8), 0.03), M_CON, Vector3(0, 0.16, 4.6), Vector3.ZERO, Vector3.ONE, false)
	# 后部重力溢流坝主体墙（z = -9.6m，高 13.8m，宽 25.2m）
	A.add(n, A.bevel_box(Vector3(25.2, 13.2, 4.6), 0.12), M_CON, Vector3(0, 6.6, -10.2))
	A.add(n, A.bevel_box(Vector3(25.6, 3.6, 6.4), 0.10), M_WET, Vector3(0, 1.8, -9.4))
	_add_pillar_block(raid, p, Vector3(0, 0, -9.8), Vector3(25.4, 13.6, 5.8), rot)
	# 三座流线型阶梯扶壁闸墩（x = -9.6, 0.0, +9.6）+ 两侧翼墙
	for px: float in [-9.6, 0.0, 9.6]:
		A.add(n, A.bevel_box(Vector3(2.6, 14.8, 7.6), 0.10), M_CON, Vector3(px, 7.4, -7.8))
		A.add(n, A.bevel_box(Vector3(2.8, 5.4, 3.2), 0.08), M_WET, Vector3(px, 2.7, -3.6), Vector3(18, 0, 0))
		_add_pillar_block(raid, p, Vector3(px, 0, -6.8), Vector3(2.8, 14.8, 8.4), rot)
	for sx: float in [-1.0, 1.0]:
		A.add(n, A.bevel_box(Vector3(1.6, 4.2, 9.4), 0.08), M_WET, Vector3(sx * 11.2, 2.1, -0.8))
		A.add(n, A.bevel_box(Vector3(1.8, 0.36, 9.6), 0.04), M_CON, Vector3(sx * 11.2, 4.3, -0.8))
		_add_pillar_block(raid, p, Vector3(sx * 11.2, 0, -0.8), Vector3(1.8, 4.4, 9.5), rot)
	# 双孔巨型钢制弧形溢洪闸门（Tainter Gate）+ 溢流滑道面 + 支撑斜臂
	for gx: float in [-4.8, 4.8]:
		# 溢流曲面滑槽
		A.add(n, A.bevel_box(Vector3(6.8, 0.65, 6.2), 0.06), M_WET, Vector3(gx, 4.6, -6.8), Vector3(38, 0, 0))
		# 弧形钢闸门面板与横向加劲钢肋
		var gate := Node3D.new()
		n.add_child(gate)
		gate.position = Vector3(gx, 8.4, -7.2)
		gate.rotation_degrees.x = 14.0
		A.add(gate, A.bevel_box(Vector3(6.6, 5.6, 0.48), 0.04), M_ST, Vector3.ZERO)
		for ri in 4:
			var ry := -2.1 + ri * 1.4
			A.add(gate, A.bevel_box(Vector3(6.7, 0.28, 0.72), 0.02), M_RST, Vector3(0, ry, 0.16))
		A.add(gate, A.bevel_box(Vector3(6.52, 0.42, 0.56), 0.02), M_HAZ, Vector3(0, 2.65, 0.05))
		for ax: float in [-2.6, 2.6]:
			A.add(n, A.bevel_box(Vector3(0.36, 0.42, 4.4), 0.02), M_RST, Vector3(gx + ax, 7.6, -9.0), Vector3(-16, 0, 0))
	# 坝顶交通廊桥、压型钢板卷扬启闭机房与混凝土调度控制室（总高 18.6m）
	var M_HOIST := A.corrugated(Color(0.26, 0.31, 0.34), 0.58, 0.30)
	var M_WIN_D := A.window_mat(0.28, Vector2(0.56, 0.46))
	for dy_step: float in [4.2, 8.2, 11.8]:
		A.add(n, A.bevel_box(Vector3(25.5, 0.24, 4.85), 0.03), M_WET, Vector3(0, dy_step, -10.2), Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.bevel_box(Vector3(26.0, 0.85, 4.8), 0.06), M_CON, Vector3(0, 15.1, -7.8))
	for bz: float in [-10.0, -5.6]:
		A.add(n, A.bevel_box(Vector3(25.8, 0.95, 0.24), 0.02), M_ST, Vector3(0, 15.9, bz), Vector3.ZERO, Vector3.ONE, false)
	for gx: float in [-4.8, 4.8]:
		A.add(n, A.bevel_box(Vector3(3.8, 2.6, 3.2), 0.05), M_HOIST, Vector3(gx, 16.8, -7.8))
		A.add(n, A.bevel_box(Vector3(2.8, 0.72, 3.30), 0.02), M_WIN_D, Vector3(gx, 17.0, -7.8), Vector3.ZERO, Vector3.ONE, false)
		A.add(n, A.bevel_box(Vector3(4.05, 0.18, 3.45), 0.03), M_WET, Vector3(gx, 18.15, -7.8))
		A.add(n, A.cyl(0.58, 2.8, 0.58, 16), M_RST, Vector3(gx, 16.4, -6.2), Vector3(0, 0, 90))
	A.add(n, A.bevel_box(Vector3(5.6, 3.6, 3.6), 0.06), M_CON, Vector3(0, 17.2, -7.8))
	A.add(n, A.bevel_box(Vector3(4.8, 0.96, 3.74), 0.02), M_WIN_D, Vector3(0, 17.6, -7.8), Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.bevel_box(Vector3(5.95, 0.24, 3.95), 0.04), M_WET, Vector3(0, 19.1, -7.8))


# ---------------------------------------------------------------- 5. 裂谷矿区：斗轮挖掘机平台 (bucket_excavator)
static func _bucket_excavator(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M_PAD := A.gravel_mat(Color(0.42, 0.37, 0.31))
	var M_YEL_CLAD := A.corrugated(Color(0.68, 0.49, 0.16), 0.64, 0.28)
	var M_YEL := A.paint(Color(0.68, 0.49, 0.16), 0.42, 0.56, {"rust": 0.66, "wear": 0.64, "panel_scale": 1.35})
	var M_ST := A.paint(Color(0.25, 0.26, 0.27), 0.65, 0.50, {"rust": 0.72, "wear": 0.58, "panel_scale": 1.30})
	var M_RST := A.paint(Color(0.39, 0.23, 0.14), 0.52, 0.66, {"rust": 0.90, "wear": 0.65, "panel_scale": 1.25})
	var M_DARK := A.metal(DARK_STEEL)
	var M_CAB_WIN := A.window_mat(0.34, Vector2(0.56, 0.52))
	var M_HAZ := A.hazard()
	# 采掘工作面碎石硬化台阶平台
	A.add(n, A.bevel_box(Vector3(23.0, 0.16, 26.0), 0.05), M_PAD, Vector3(0, 0.08, 1.0), Vector3.ZERO, Vector3.ONE, false)
	# 双巨型履带行走底盘（置于 z = -7.8m，前场 z = -1..+13m 为开阔矿台，斗轮悬于前场上空！）
	var base := Vector3(0, 0, -7.8)
	for sx: float in [-1.0, 1.0]:
		var tx := sx * 4.4
		A.add(n, A.bevel_box(Vector3(2.4, 2.3, 10.6), 0.12), M_DARK, base + Vector3(tx, 1.15, 0))
		A.add(n, A.bevel_box(Vector3(2.55, 0.95, 8.6), 0.06), M_ST, base + Vector3(tx, 1.25, 0))
		for gi in 11:
			var gz := -4.5 + gi * 0.90
			A.add(n, A.bevel_box(Vector3(2.48, 0.14, 0.26), 0.02), M_RST, base + Vector3(tx, 2.32, gz), Vector3.ZERO, Vector3.ONE, false)
		for wi: float in [-4.2, 0.0, 4.2]:
			A.add(n, A.cyl(1.08, 2.52, 1.08, 20), M_RST, base + Vector3(tx, 1.12, wi), Vector3(0, 0, 90))
		_add_pillar_block(raid, p, base + Vector3(tx, 0, 0), Vector3(2.6, 3.2, 10.8), rot)
	A.add(n, A.bevel_box(Vector3(7.2, 1.6, 7.6), 0.08), M_ST, base + Vector3(0, 2.6, 0))
	A.add(n, A.cyl(3.2, 1.1, 3.4, 28), M_RST, base + Vector3(0, 3.8, 0))
	_add_pillar_block(raid, p, base, Vector3(6.8, 8.0, 7.8), rot)
	# 上部压型钢板回转动力机房 + 外露钢柱骨架 + 柴油散热百叶格栅 + 检修走道护栏 + 排烟双筒
	var hse := base + Vector3(0, 6.9, -0.4)
	A.add(n, A.bevel_box(Vector3(7.6, 5.4, 8.8), 0.08), M_YEL_CLAD, hse)
	A.add(n, A.bevel_box(Vector3(7.85, 0.55, 9.05), 0.04), M_HAZ, base + Vector3(0, 4.35, -0.4))
	A.add(n, A.bevel_box(Vector3(7.90, 0.28, 9.10), 0.03), M_ST, base + Vector3(0, 9.65, -0.4))
	for sx_f: float in [-1.0, 1.0]:
		# 两侧外挑巡检走道与栏杆
		A.add(n, A.bevel_box(Vector3(0.72, 0.14, 8.8), 0.02), M_DARK, hse + Vector3(sx_f * 4.12, -2.15, 0))
		A.add(n, A.bevel_box(Vector3(0.08, 0.92, 8.8), 0.01), M_ST, hse + Vector3(sx_f * 4.44, -1.65, 0), Vector3.ZERO, Vector3.ONE, false)
		for fz: float in [-3.8, -1.3, 1.3, 3.8]:
			A.add(n, A.bevel_box(Vector3(0.24, 5.42, 0.26), 0.02), M_ST, hse + Vector3(sx_f * 3.84, 0.0, fz))
		# 巨型柴油机组深色散热百叶窗阵
		for lz_v: float in [-2.55, 0.0, 2.55]:
			A.add(n, A.bevel_box(Vector3(0.14, 1.85, 1.72), 0.02), M_DARK, hse + Vector3(sx_f * 3.82, 0.45, lz_v), Vector3.ZERO, Vector3.ONE, false)
			for lv in 4:
				A.add(n, A.bevel_box(Vector3(0.20, 0.12, 1.62), 0.01), M_ST, hse + Vector3(sx_f * 3.86, -0.22 + lv * 0.44, lz_v), Vector3(0, 0, sx_f * 18.0), Vector3.ONE, false)
	# 机房顶部双排烟消音筒与热交换风箱 + 机身钢印
	A.add(n, A.bevel_box(Vector3(3.4, 1.15, 4.2), 0.05), M_ST, hse + Vector3(-1.2, 3.25, -1.2))
	for ex_z: float in [-2.2, -0.4]:
		A.add(n, A.cyl(0.32, 2.15, 0.36, 12), M_DARK, hse + Vector3(-1.8, 4.45, ex_z))
	# 悬挑多窗格装甲驾驶室与遮阳钢檐
	A.add(n, A.bevel_box(Vector3(2.8, 2.6, 3.2), 0.06), M_YEL_CLAD, base + Vector3(4.6, 8.2, 3.2))
	A.add(n, A.bevel_box(Vector3(2.92, 1.24, 3.32), 0.03), M_CAB_WIN, base + Vector3(4.6, 8.4, 3.2), Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.bevel_box(Vector3(3.15, 0.18, 3.55), 0.03), M_ST, base + Vector3(4.6, 9.56, 3.25), Vector3(4, 0, 0))
	# A 字主钢塔架与后伸配重箱桁臂
	for sx: float in [-1.0, 1.0]:
		A.add(n, A.bevel_box(Vector3(0.58, 9.2, 0.62), 0.03), M_ST, base + Vector3(sx * 2.4, 13.6, -0.2), Vector3(8, 0, sx * 12.0))
	A.add(n, A.bevel_box(Vector3(3.8, 0.9, 1.2), 0.04), M_RST, base + Vector3(0, 17.8, -0.8))
	A.add(n, A.bevel_box(Vector3(4.2, 1.6, 8.6), 0.05), M_ST, base + Vector3(0, 8.4, -7.8), Vector3(-6, 0, 0))
	A.add(n, A.bevel_box(Vector3(5.6, 3.2, 3.4), 0.08), A.concrete(Color(0.38, 0.36, 0.33), true), base + Vector3(0, 7.6, -12.2))
	# 向前上方悬挑的 15.6m 巨型斗轮钢桁臂（离地净空 5.4m..8.8m，机甲与首领可在斗轮下方自由穿行激战！）
	var boom := Node3D.new()
	n.add_child(boom)
	boom.position = base + Vector3(0, 7.4, 3.2)
	boom.rotation_degrees.x = -5.0
	for sx: float in [-1.35, 1.35]:
		A.add(boom, A.bevel_box(Vector3(0.42, 1.55, 13.8), 0.03), M_YEL, Vector3(sx, 0, 6.4))
	A.add(boom, A.bevel_box(Vector3(2.3, 0.36, 13.4), 0.02), M_DARK, Vector3(0, -0.52, 6.4))
	for bi in 6:
		var bz := 1.0 + bi * 2.2
		A.add(boom, A.bevel_box(Vector3(2.8, 0.28, 0.32), 0.02), M_ST, Vector3(0, 0.72, bz))
	# 拉索钢缆从 17.8m 塔顶连至斗轮臂前端与配重端
	for sx: float in [-1.1, 1.1]:
		A.add(n, A.tube([base + Vector3(sx, 17.8, -0.8), base + Vector3(sx, 8.8, 15.2)], 0.075, 6, 3), M_DARK, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		A.add(n, A.tube([base + Vector3(sx, 17.8, -0.8), base + Vector3(sx, 8.6, -11.8)], 0.075, 6, 3), M_DARK, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	# 直径 6.8m 的十斗旋转切削轮（轮心高 y = 8.4m，最低点 y = 4.6m > 机甲头顶，压迫感拉满且绝不挡路）
	var wc := base + Vector3(0.0, 8.4, 16.2)
	A.add(n, A.torus(2.65, 3.25, 28), M_RST, wc, Vector3(0, 0, 90))
	A.add(n, A.cyl(0.95, 1.4, 0.95, 20), M_YEL, wc, Vector3(0, 0, 90))
	for spk in 5:
		var sa := PI * float(spk) / 5.0
		A.add(n, A.bevel_box(Vector3(0.24, 6.1, 0.34), 0.02), M_ST, wc, Vector3(rad_to_deg(sa), 0, 0))
	for bi in 10:
		var ba := TAU * float(bi) / 10.0
		var bp := wc + Vector3(0, sin(ba) * 3.35, cos(ba) * 3.35)
		A.add(n, A.bevel_box(Vector3(1.18, 0.86, 1.05), 0.04), M_YEL if bi % 2 == 0 else M_RST, bp, Vector3(-rad_to_deg(ba), 0, 0))
		A.add(n, A.bevel_box(Vector3(1.24, 0.16, 0.32), 0.02), M_HAZ, bp + Vector3(0, sin(ba) * 0.45, cos(ba) * 0.45), Vector3(-rad_to_deg(ba), 0, 0))


# ---------------------------------------------------------------- 6. 零号深渊井：地热磁约束腔 (geothermal_vault)
static func _geothermal_vault(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M_CON := A.concrete(Color(0.38, 0.37, 0.40), true)
	var M_ST := A.paint(Color(0.28, 0.31, 0.36), 0.72, 0.42, {"rust": 0.58, "wear": 0.54, "panel_scale": 1.45})
	var M_DARK := A.metal(Color(0.11, 0.12, 0.14))
	var M_DECK := A.concrete(Color(0.27, 0.28, 0.32), false)
	var M_HAZ := A.hazard()
	# 深井防辐射重型前场平台（z ∈ [0..+12m] 敞开，与 arena_pos (0,0,4.2) 对齐作首领战场地）
	A.add(n, A.bevel_box(Vector3(21.6, 0.14, 13.6), 0.04), M_CON, Vector3(0, 0.07, 5.6), Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.cyl(7.6, 0.08, 8.0, 24), M_DECK, Vector3(0, 0.15, 5.2), Vector3.ZERO, Vector3.ONE, false)
	for ri in 6:
		A.add(n, A.bevel_box(Vector3(0.28, 0.03, 14.6), 0.01), M_ST, Vector3(0, 0.195 + ri * 0.004, 5.2), Vector3(0, ri * 30.0, 0), Vector3.ONE, false)
	A.add(n, A.cyl(0.80, 0.05, 0.88, 16), M_DARK, Vector3(0, 0.22, 5.2), Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.torus(7.1, 7.55, 28), M_HAZ, Vector3(0, 0.18, 5.2), Vector3.ZERO, Vector3(1, 0.35, 1), false)
	# Wave5 重制：安全壳正面三瓣炸穿露紫铜线圈 + 歪斜蒸汽集箱 + 东侧折断高压蒸汽巨管（lm_geothermal_vault_remake 22×15.6×20）
	# 后置于 z = -8.4m，前场首领竞技台 100% 畅通
	var sz := Vector3(19.0, 14.2, 16.5)
	var vz := -8.4
	_place_world_prefab(raid, p, rot, "lm_geothermal_vault_remake", Vector3(0.0, -0.04, vz), 0.0, sz)
	var sx_sc := sz.x / 22.0
	var sz_sc := sz.z / 20.0
	_add_pillar_block(raid, p, Vector3(0.0, 0.0, vz - 0.8 * sz_sc), Vector3(8.6, 13.5, 8.6), rot, true)
	_add_pillar_block(raid, p, Vector3(0.0, 0.0, vz + 6.45 * sz_sc), Vector3(4.6, 3.2, 2.8), rot)
	for sx: float in [-1.0, 1.0]:
		_add_pillar_block(raid, p, Vector3(sx * 7.6 * sx_sc, 0.0, vz - 0.8 * sz_sc), Vector3(2.2, 10.0, 2.2), rot)
	raid.blocks.append(raid._rect_for(p + Vector3(0.0, 0.0, vz).rotated(Vector3.UP, deg_to_rad(rot)), Vector3(19.2, 1.0, 16.8)))
	var gl := OmniLight3D.new()
	gl.light_color = Color(0.98, 0.44, 0.16)
	gl.light_energy = 4.2
	gl.omni_range = 20.0
	gl.shadow_enabled = false
	gl.position = Vector3(0, 5.2, vz + 5.6)
	n.add_child(gl)


# ---------------------------------------------------------------- 7. 东湾船坞港：巨型潜艇干船坞 (submarine_drydock)
static func _submarine_drydock(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M_CON := A.concrete(CONCRETE, true)
	var M_ST := A.paint(Color(0.28, 0.31, 0.34), 0.68, 0.46, {"rust": 0.58, "wear": 0.50})
	var M_DARK := A.metal(Color(0.11, 0.12, 0.14))
	var M_HAZ := A.hazard()
	# 前场钢筋混凝土坞坪与龙门轨道道床（z ∈ [+0.5..+12.0] 敞开，与 arena_pos (0,0,4.8) 对齐作首领战场地）
	A.add(n, A.bevel_box(Vector3(22.8, 0.12, 12.6), 0.04), M_CON, Vector3(0, 0.06, 6.2), Vector3.ZERO, Vector3.ONE, false)
	for sx: float in [-9.6, 9.6]:
		A.add(n, A.bevel_box(Vector3(1.1, 0.06, 11.8), 0.02), M_DARK, Vector3(sx, 0.125, 6.2), Vector3.ZERO, Vector3.ONE, false)
		A.add(n, A.bevel_box(Vector3(0.22, 0.05, 11.6), 0.01), M_ST, Vector3(sx - 0.22, 0.165, 6.2), Vector3.ZERO, Vector3.ONE, false)
		A.add(n, A.bevel_box(Vector3(0.22, 0.05, 11.6), 0.01), M_ST, Vector3(sx + 0.22, 0.165, 6.2), Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.bevel_box(Vector3(13.6, 0.03, 0.42), 0.01), M_HAZ, Vector3(0, 0.135, 10.6), Vector3.ZERO, Vector3.ONE, false)
	# Wave5 重制：潜艇耐压壳体 + 歪斜指挥塔围壳 + 跨坞龙门吊 + 坍塌阶梯坞壁（lm_submarine_drydock_remake 24×14.2×16）
	# 后置于 z = -7.2m（覆盖 z ∈ [-14.6..+0.2]），前场竞技台 100% 无阻挡
	var sz := Vector3(22.0, 13.8, 14.8)
	var dz := -7.2
	_place_world_prefab(raid, p, rot, "lm_submarine_drydock_remake", Vector3(0.0, -0.04, dz), 0.0, sz)
	_add_pillar_block(raid, p, Vector3(0.0, 0.0, dz), Vector3(21.2, 12.0, 13.6), rot, false)
	raid.blocks.append(raid._rect_for(p + Vector3(0.0, 0.0, dz).rotated(Vector3.UP, deg_to_rad(rot)), Vector3(22.4, 1.0, 15.2)))
	var gl := OmniLight3D.new()
	gl.light_color = Color(0.96, 0.82, 0.58)
	gl.light_energy = 3.8
	gl.omni_range = 24.0
	gl.shadow_enabled = false
	gl.position = Vector3(0, 8.2, 2.2)
	n.add_child(gl)
