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


# ---------------------------------------------------------------- 1. 灰港市：中央穹顶总站 (central_terminus)
static func _central_terminus(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M_CON := A.concrete(CONCRETE, true)
	var M_CDK := A.concrete(CONC_DARK, false)
	var M_BRK := A.brick(Color(0.44, 0.30, 0.24), 0.28)
	var M_ST := A.paint(Color(0.24, 0.27, 0.29), 0.62, 0.52, {"rust": 0.68, "wear": 0.55, "panel_scale": 1.3})
	var M_RST := A.corrugated(Color(0.36, 0.22, 0.15), 0.76, 0.30)
	var M_GL := A.glass(Color(0.24, 0.32, 0.38))
	var M_WIN := A.window_mat(0.24, Vector2(0.46, 0.90))
	var M_BALLAST := A.gravel_mat(Color(0.30, 0.29, 0.27))
	var M_HAZ := A.hazard()
	# 站坪花岗岩基台与双线沉降道床（平齐地面，不卡机甲步足）
	A.add(n, A.bevel_box(Vector3(23.6, 0.12, 26.4), 0.04), M_CDK, Vector3(0, 0.06, 0), Vector3.ZERO, Vector3.ONE, false)
	for sx: float in [-1.0, 1.0]:
		A.add(n, A.bevel_box(Vector3(3.2, 0.16, 24.4), 0.03), M_CON, Vector3(sx * 8.4, 0.10, 0.6), Vector3.ZERO, Vector3.ONE, false)
		A.add(n, A.bevel_box(Vector3(0.22, 0.04, 24.0), 0.01), M_HAZ, Vector3(sx * 6.9, 0.19, 0.6), Vector3.ZERO, Vector3.ONE, false)
		# 双股铁轨与碎石道砟枕木
		var tx := sx * 3.1
		A.add(n, A.bevel_box(Vector3(2.2, 0.06, 23.8), 0.02), M_BALLAST, Vector3(tx, 0.09, 0.6), Vector3.ZERO, Vector3.ONE, false)
		for rx: float in [-0.58, 0.58]:
			A.add(n, A.bevel_box(Vector3(0.09, 0.08, 23.6), 0.01), A.metal(STEEL), Vector3(tx + rx, 0.14, 0.6), Vector3.ZERO, Vector3.ONE, false)
		for si in 14:
			var sz := -10.4 + si * 1.68
			A.add(n, A.bevel_box(Vector3(1.65, 0.05, 0.22), 0.01), M_CDK, Vector3(tx, 0.11, sz), Vector3.ZERO, Vector3.ONE, false)
	# 两侧各 5 根铆接箱型钢立柱 + 大跨度三铰钢桁拱肋（净高 13.6m，跨度 20.8m）
	for zi in 5:
		var zc := -9.6 + zi * 5.0
		for sx: float in [-1.0, 1.0]:
			var px := sx * 10.4
			A.add(n, A.bevel_box(Vector3(1.25, 0.65, 1.35), 0.05), M_CDK, Vector3(px, 0.32, zc))
			A.add(n, A.bevel_box(Vector3(0.76, 7.6, 0.88), 0.04), M_ST, Vector3(px, 4.2, zc))
			A.add(n, A.bevel_box(Vector3(0.92, 0.28, 1.04), 0.03), M_RST, Vector3(px, 7.9, zc))
			_add_pillar_block(raid, p, Vector3(px, 0, zc), Vector3(1.3, 8.0, 1.4), rot)
		# 分段折线钢拱肋（7 段拼合半圆钢桁拱）
		var arch_segs := 8
		for ai in arch_segs:
			var a0 := PI * float(ai) / float(arch_segs)
			var a1 := PI * float(ai + 1) / float(arch_segs)
			var p0 := Vector3(-cos(a0) * 10.4, 7.8 + sin(a0) * 5.8, zc)
			var p1 := Vector3(-cos(a1) * 10.4, 7.8 + sin(a1) * 5.8, zc)
			var mid := (p0 + p1) * 0.5
			var seg_len := p0.distance_to(p1)
			var ang_z := rad_to_deg(atan2(p1.y - p0.y, p1.x - p0.x))
			A.add(n, A.bevel_box(Vector3(seg_len + 0.12, 0.52, 0.46), 0.03), M_ST, mid, Vector3(0, 0, ang_z))
			A.add(n, A.bevel_box(Vector3(seg_len + 0.08, 0.14, 0.58), 0.02), M_RST, mid + Vector3(0, 0.22, 0), Vector3(0, 0, ang_z), Vector3.ONE, false)
	# 纵向联系钢檩条、天窗采光带与破损残缺压型钢板顶棚（中段局部坍塌透光）
	for ai in [1, 2, 3, 5, 6, 7]:
		var ang := PI * (float(ai) + 0.5) / 8.0
		var rx := -cos(ang) * 10.55
		var ry := 7.8 + sin(ang) * 5.95
		var tilt := rad_to_deg(ang - PI * 0.5)
		A.add(n, A.bevel_box(Vector3(0.24, 0.26, 21.2), 0.02), M_ST, Vector3(rx, ry, 0.4), Vector3(0, 0, -tilt), Vector3.ONE, false)
		for bay in 4:
			if bay == 2 and (ai == 3 or ai == 5):
				continue
			var bz := -7.1 + bay * 5.0
			var mat_r: Material = M_GL if (ai == 3 or ai == 5) else M_RST
			A.add(n, A.bevel_box(Vector3(2.85, 0.09, 4.72), 0.02), mat_r, Vector3(rx, ry + 0.12, bz), Vector3(0, 0, -tilt), Vector3.ONE, false)
	# 拱顶中央通风天窗脊梁
	A.add(n, A.bevel_box(Vector3(2.6, 0.75, 19.6), 0.04), M_ST, Vector3(0, 14.0, 0.4), Vector3.ZERO, Vector3.ONE, false)
	# 北端新古典工业红砖石材门廊 + 中央钟塔（留出宽 8.8m 的中央凯旋拱门供通行）
	for sx: float in [-1.0, 1.0]:
		var wx := sx * 7.6
		A.add(n, A.bevel_box(Vector3(6.2, 9.4, 2.2), 0.08), M_BRK, Vector3(wx, 4.7, -12.0))
		A.add(n, A.bevel_box(Vector3(6.5, 0.85, 2.5), 0.05), M_CON, Vector3(wx, 0.42, -12.0))
		A.add(n, A.bevel_box(Vector3(6.5, 0.30, 2.42), 0.04), M_CON, Vector3(wx, 4.8, -12.0))
		A.add(n, A.bevel_box(Vector3(6.5, 0.52, 2.5), 0.05), M_CON, Vector3(wx, 9.55, -12.0))
		for px_c: float in [-2.85, 0.0, 2.85]:
			A.add(n, A.bevel_box(Vector3(0.46, 9.2, 2.42), 0.03), M_CON, Vector3(wx + px_c, 4.7, -12.0))
		for wi in 2:
			var wox := wx + (wi - 0.5) * 2.8
			A.add(n, A.bevel_box(Vector3(1.38, 3.8, 2.32), 0.03), M_WIN, Vector3(wox, 5.3, -12.0), Vector3.ZERO, Vector3.ONE, false)
		_add_pillar_block(raid, p, Vector3(wx, 0, -12.0), Vector3(6.3, 9.6, 2.3), rot)
	# 门廊横楣与 19.2m 车站钟塔
	A.add(n, A.bevel_box(Vector3(9.4, 2.6, 2.3), 0.07), M_CON, Vector3(0, 8.3, -12.0))
	A.add(n, A.bevel_box(Vector3(5.2, 7.4, 3.2), 0.08), M_BRK, Vector3(0, 13.2, -12.0))
	for cx_p: float in [-2.42, 2.42]:
		for cz_p: float in [-1.42, 1.42]:
			A.add(n, A.bevel_box(Vector3(0.48, 7.4, 0.48), 0.03), M_CON, Vector3(cx_p, 13.2, -12.0 + cz_p))
	A.add(n, A.bevel_box(Vector3(5.6, 0.55, 3.6), 0.05), M_CON, Vector3(0, 17.0, -12.0))
	A.add(n, A.cyl(0.35, 2.6, 2.5, 4), A.roof_mat(Color(0.24, 0.27, 0.29), 0.48, true), Vector3(0, 18.5, -12.0), Vector3(0, 45, 0))
	# 四面工业车站大钟面与钢指针
	for cz_s: float in [-1.66, 1.66]:
		A.add(n, A.cyl(1.28, 0.10, 1.28, 24), A.concrete(Color(0.76, 0.74, 0.68), false), Vector3(0, 14.2, -12.0 + cz_s), Vector3(90, 0, 0), Vector3.ONE, false)
		A.add(n, A.torus(1.20, 1.34, 24), M_ST, Vector3(0, 14.2, -12.0 + cz_s * 1.03), Vector3(90, 0, 0), Vector3.ONE, false)
		A.add(n, A.bevel_box(Vector3(0.10, 0.92, 0.06), 0.01), A.metal(DARK_STEEL), Vector3(0.15, 14.5, -12.0 + cz_s * 1.06), Vector3(0, 0, -28), Vector3.ONE, false)
		A.add(n, A.bevel_box(Vector3(0.12, 0.64, 0.06), 0.01), A.metal(DARK_STEEL), Vector3(-0.22, 14.1, -12.0 + cz_s * 1.06), Vector3(0, 0, 64), Vector3.ONE, false)


# ---------------------------------------------------------------- 2. 铁锈工业带：二号转炉钢厂 (converter_foundry)
static func _converter_foundry(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M_CON := A.concrete(Color(0.34, 0.32, 0.30), true)
	var M_ST := A.paint(Color(0.29, 0.31, 0.34), 0.70, 0.44, {"rust": 0.65, "wear": 0.58, "panel_scale": 1.35})
	var M_RST := A.paint(Color(0.38, 0.22, 0.14), 0.55, 0.64, {"rust": 0.92, "wear": 0.65, "panel_scale": 1.2})
	var M_CLAD := A.corrugated(Color(0.36, 0.22, 0.15), 0.78, 0.28)
	var M_YEL := A.paint(Color(0.68, 0.48, 0.14), 0.42, 0.56, {"rust": 0.62, "wear": 0.68, "panel_scale": 1.4})
	var M_DARK := A.metal(DARK_STEEL)
	var M_WIN := A.window_mat(0.32, Vector2(0.72, 0.52))
	var M_GLOW := A.emit(Color(1.0, 0.48, 0.12), 2.8)
	var M_CORE := A.emit(Color(1.0, 0.82, 0.42), 4.2)
	# 铸锭跨重型耐火砖与防滑花纹钢板地坪（前场完全敞开作首领战场地）
	A.add(n, A.bevel_box(Vector3(24.0, 0.14, 25.0), 0.04), M_CON, Vector3(0, 0.07, 0.5), Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.bevel_box(Vector3(17.6, 0.06, 15.2), 0.02), A.concrete(Color(0.28, 0.27, 0.26), false), Vector3(0, 0.15, 4.2), Vector3.ZERO, Vector3.ONE, false)
	for di in 5:
		var dz := -1.8 + float(di) * 3.0
		A.add(n, A.bevel_box(Vector3(16.4, 0.04, 1.1), 0.015), M_ST, Vector3(0, 0.185, dz), Vector3.ZERO, Vector3.ONE, false)
	# 后部转炉跨四根巨型箱型钢框架柱 + 耳轴混凝土地墩
	for sx: float in [-1.0, 1.0]:
		for zc: float in [-12.6, -6.8]:
			var px := sx * 9.4
			A.add(n, A.bevel_box(Vector3(1.6, 15.6, 1.6), 0.06), M_ST, Vector3(px, 7.8, zc))
			A.add(n, A.bevel_box(Vector3(2.2, 0.9, 2.2), 0.06), M_CON, Vector3(px, 0.45, zc))
			_add_pillar_block(raid, p, Vector3(px, 0, zc), Vector3(1.8, 15.6, 1.8), rot)
		# 转炉承重耳轴巨墩（x = ±5.0, z = -9.6）
		var tx := sx * 5.0
		A.add(n, A.bevel_box(Vector3(2.2, 6.8, 3.4), 0.08), M_CON, Vector3(tx, 3.4, -9.6))
		A.add(n, A.cyl(1.05, 1.4, 1.05, 20), M_YEL, Vector3(tx, 6.8, -9.6), Vector3(0, 0, 90))
		_add_pillar_block(raid, p, Vector3(tx, 0, -9.6), Vector3(2.3, 7.2, 3.5), rot)
		# 前跨天车轨道立柱（x = ±10.2, z = +7.2，远离中央竞技区）
		A.add(n, A.bevel_box(Vector3(1.3, 12.8, 1.3), 0.05), M_ST, Vector3(sx * 10.2, 6.4, 7.2))
		A.add(n, A.bevel_box(Vector3(1.4, 0.9, 21.8), 0.04), M_RST, Vector3(sx * 9.8, 12.2, -2.6))
		_add_pillar_block(raid, p, Vector3(sx * 10.2, 0, 7.2), Vector3(1.5, 12.8, 1.5), rot)
	# 后部高跨顶棚梁架与压型钢板余热锅炉房 + 高侧散热采光窗带
	A.add(n, A.bevel_box(Vector3(20.6, 1.2, 7.2), 0.06), M_ST, Vector3(0, 15.4, -9.7))
	A.add(n, A.bevel_box(Vector3(14.8, 4.2, 5.6), 0.06), M_CLAD, Vector3(0, 17.8, -10.2))
	A.add(n, A.bevel_box(Vector3(13.2, 1.25, 5.74), 0.02), M_WIN, Vector3(0, 18.2, -10.2), Vector3.ZERO, Vector3.ONE, false)
	for rx_b: float in [-5.8, -2.9, 0.0, 2.9, 5.8]:
		A.add(n, A.bevel_box(Vector3(0.32, 4.3, 5.82), 0.02), M_ST, Vector3(rx_b, 17.8, -10.2), Vector3.ZERO, Vector3.ONE, false)
	# 梨形氧气顶吹转炉本体（微前倾 18°，炉口透出暗红炽热钢渣余晖）+ 托圈耳轴
	var conv := Node3D.new()
	n.add_child(conv)
	conv.position = Vector3(0, 6.8, -9.6)
	conv.rotation_degrees.x = 18.0
	A.add(conv, A.torus(2.85, 3.45, 28), M_ST, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.35, 1.0))
	A.add(conv, A.cyl(2.85, 3.8, 2.35, 28), M_RST, Vector3(0, -1.5, 0))
	A.add(conv, A.sphere(2.36, 1.5, 24), M_DARK, Vector3(0, -3.2, 0))
	A.add(conv, A.cyl(1.68, 2.9, 2.85, 28), M_RST, Vector3(0, 1.85, 0))
	A.add(conv, A.torus(1.42, 1.72, 24), M_DARK, Vector3(0, 3.24, 0), Vector3.ZERO, Vector3(1, 0.55, 1), false)
	A.add(conv, A.cyl(1.40, 0.28, 1.54, 24), M_GLOW, Vector3(0, 3.22, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(conv, A.cyl(0.92, 0.34, 1.02, 20), M_CORE, Vector3(0, 3.26, 0), Vector3.ZERO, Vector3.ONE, false)
	var ml := OmniLight3D.new()
	ml.light_color = Color(1.0, 0.48, 0.14)
	ml.light_energy = 6.5
	ml.omni_range = 24.0
	ml.shadow_enabled = false
	ml.position = Vector3(0, 3.8, 0.6)
	conv.add_child(ml)
	# 水冷集烟罩 + 22m 高耸放散烟囱（深黑内膛）
	A.add(n, A.cyl(1.45, 5.4, 2.45, 24), M_DARK, Vector3(0, 13.0, -9.1), Vector3(-8, 0, 0))
	A.add(n, A.cyl(0.92, 6.8, 1.18, 24), M_ST, Vector3(2.8, 20.6, -10.6))
	A.add(n, A.torus(0.95, 1.15, 22), A.hazard(), Vector3(2.8, 22.8, -10.6), Vector3.ZERO, Vector3(1, 0.6, 1), false)
	A.add(n, A.cyl(0.76, 0.25, 0.76, 20), A.metal(Color(0.03, 0.03, 0.04)), Vector3(2.8, 23.95, -10.6), Vector3.ZERO, Vector3.ONE, false)
	# 横跨前场高空 12.6m 的重型铸造桥式起重机（双箱梁加劲肋 + 小车 + 吊钩钢包横担，净空 > 9.2m）
	for bz: float in [0.4, 2.2]:
		A.add(n, A.bevel_box(Vector3(20.4, 0.95, 0.68), 0.04), M_YEL, Vector3(0, 12.85, bz))
		for stiff_i in 9:
			var sx_st := -8.8 + stiff_i * 2.2
			A.add(n, A.bevel_box(Vector3(0.14, 1.02, 0.78), 0.02), M_DARK, Vector3(sx_st, 12.85, bz), Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.bevel_box(Vector3(3.8, 1.1, 2.8), 0.04), M_ST, Vector3(-2.2, 13.75, 1.3))
	for sx: float in [-0.9, 0.9]:
		A.add(n, A.cyl(0.055, 3.2, 0.055, 8), M_DARK, Vector3(-2.2 + sx, 11.6, 1.3), Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.bevel_box(Vector3(2.6, 0.42, 0.65), 0.03), A.hazard(), Vector3(-2.2, 9.95, 1.3), Vector3.ZERO, Vector3.ONE, false)


# ---------------------------------------------------------------- 3. 尘土平原：洲际发射井阵地 (missile_silo)
static func _missile_silo(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M_CON := A.concrete(Color(0.49, 0.46, 0.40), true)
	var M_CDK := A.concrete(Color(0.34, 0.32, 0.29), false)
	var M_ST := A.paint(Color(0.27, 0.29, 0.26), 0.58, 0.52, {"rust": 0.55, "wear": 0.52, "panel_scale": 1.35})
	var M_RST := A.paint(Color(0.38, 0.25, 0.16), 0.50, 0.65, {"rust": 0.85, "wear": 0.6, "panel_scale": 1.2})
	var M_HAZ := A.hazard()
	var M_CHR := A.chrome()
	var M_PIT := A.metal(Color(0.05, 0.05, 0.06))
	# 硬化抗核爆钢筋混凝土发射坪 + 柏油抗烧蚀导流区
	A.add(n, A.bevel_box(Vector3(24.4, 0.16, 25.6), 0.05), M_CON, Vector3(0, 0.08, 0.4), Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.bevel_box(Vector3(16.8, 0.05, 14.0), 0.02), A.asphalt(Color(0.22, 0.22, 0.23)), Vector3(0, 0.17, 4.4), Vector3.ZERO, Vector3.ONE, false)
	A.stencil(n, "SILO-04", Vector3(0, 0.20, 8.8), Vector3(-90, 0, 0), 0.045, Color(0.86, 0.80, 0.58, 0.58))
	# 发射井口圆环装甲座圈（置于 z = -7.4m，前场 z = -1..+12m 完全敞开）
	var sc := Vector3(0, 0.0, -7.4)
	A.add(n, A.cyl(5.2, 0.56, 5.8, 16), M_CDK, sc + Vector3(0, 0.28, 0))
	A.add(n, A.torus(4.35, 5.05, 24), M_HAZ, sc + Vector3(0, 0.54, 0), Vector3.ZERO, Vector3(1, 0.42, 1), false)
	A.add(n, A.cyl(4.15, 0.24, 4.15, 24), M_PIT, sc + Vector3(0, 0.48, 0), Vector3.ZERO, Vector3.ONE, false)
	# 井口半露出的重型洲际弹道导弹整流罩尖端与冷发射适配器环
	A.add(n, A.cyl(1.48, 1.6, 1.56, 24), M_ST, sc + Vector3(0, 0.95, 0))
	A.add(n, A.cyl(0.18, 2.2, 1.48, 24), A.paint(Color(0.22, 0.24, 0.22), 0.45, 0.50, {"wear": 0.45}), sc + Vector3(0, 2.85, 0))
	A.add(n, A.torus(1.52, 1.68, 24), M_HAZ, sc + Vector3(0, 1.55, 0), Vector3.ZERO, Vector3(1, 0.5, 1), false)
	_add_pillar_block(raid, p, sc, Vector3(8.6, 3.8, 8.6), rot, true)
	# 左右两扇 90 吨级厚重楔形装甲发射井盖（液压油缸顶起呈 62° 敞开）
	for sx: float in [-1.0, 1.0]:
		var door := Node3D.new()
		n.add_child(door)
		door.position = sc + Vector3(sx * 4.7, 0.55, 0)
		door.rotation_degrees.z = sx * -62.0
		A.add(door, A.bevel_box(Vector3(4.6, 0.92, 8.2), 0.08), M_ST, Vector3(-sx * 2.1, 0.46, 0))
		A.add(door, A.bevel_box(Vector3(4.2, 0.24, 7.6), 0.04), M_RST, Vector3(-sx * 2.1, 0.98, 0))
		for ri in 3:
			var rz := -2.6 + ri * 2.6
			A.add(door, A.bevel_box(Vector3(4.3, 0.34, 0.42), 0.03), M_CDK, Vector3(-sx * 2.1, 1.06, rz))
		A.add(door, A.bevel_box(Vector3(0.45, 0.96, 8.0), 0.03), M_HAZ, Vector3(-sx * 4.15, 0.48, 0))
		# 双联巨型镀铬液压作动筒
		for hz: float in [-2.4, 2.4]:
			A.add(n, A.cyl(0.26, 2.8, 0.30, 12), M_RST, sc + Vector3(sx * 6.4, 1.35, hz), Vector3(0, 0, sx * 24.0))
			A.add(n, A.cyl(0.16, 2.6, 0.16, 12), M_CHR, sc + Vector3(sx * 5.6, 3.10, hz), Vector3(0, 0, sx * 24.0))
		_add_pillar_block(raid, p, sc + Vector3(sx * 6.0, 0, 0), Vector3(2.8, 5.5, 7.8), rot)
	# 勤务脐带塔架（立于左后角 x = -8.6, z = -10.8）与防雷避雷塔针 + 地下指挥排风碉堡（右后角）
	K.lattice(raid, p + Vector3(-8.6, 0, -10.8).rotated(Vector3.UP, deg_to_rad(rot)), 16.5, 3.0)
	A.add(n, A.bevel_box(Vector3(5.2, 0.65, 0.72), 0.03), M_RST, Vector3(-5.6, 11.4, -9.2), Vector3(0, -22, 0))
	var bnk := Vector3(8.4, 0.0, -10.2)
	A.add(n, A.bevel_box(Vector3(5.6, 3.4, 4.8), 0.10), M_CDK, bnk + Vector3(0, 1.7, 0))
	A.add(n, A.bevel_box(Vector3(6.0, 0.55, 5.2), 0.06), M_CON, bnk + Vector3(0, 3.55, 0))
	A.add(n, A.cyl(0.65, 2.4, 0.78, 16), M_ST, bnk + Vector3(0.8, 4.8, 0))
	_add_pillar_block(raid, p, bnk, Vector3(5.8, 4.2, 5.0), rot)


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
		A.add(gate, A.bevel_box(Vector3(6.6, 0.42, 0.56), 0.02), M_HAZ, Vector3(0, 2.65, 0.05))
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
	A.stencil(n, "BWE-288", hse + Vector3(-3.88, -1.15, 1.2), Vector3(0, -90, 0), 0.032, Color(0.14, 0.13, 0.12, 0.82))
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
	var M_COP := A.paint(Color(0.68, 0.42, 0.22), 0.85, 0.30, {"wear": 0.35, "panel_scale": 1.1})
	var M_DARK := A.metal(Color(0.11, 0.12, 0.14))
	var M_DECK := A.concrete(Color(0.27, 0.28, 0.32), false)
	var M_HAZ := A.hazard()
	var M_CORE := A.emit(Color(0.95, 0.38, 0.14), 1.9)
	# 深井防辐射重型六角钢格栅前场平台（前场 z = -1..+12m 敞开）
	A.add(n, A.bevel_box(Vector3(23.6, 0.16, 25.0), 0.05), M_CON, Vector3(0, 0.08, 0.6), Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.cyl(9.2, 0.08, 9.6, 12), M_DECK, Vector3(0, 0.16, 4.4), Vector3.ZERO, Vector3.ONE, false)
	for ri in 6:
		A.add(n, A.bevel_box(Vector3(0.32, 0.03, 17.6), 0.01), M_ST, Vector3(0, 0.205, 4.4), Vector3(0, ri * 30.0, 0), Vector3.ONE, false)
	A.add(n, A.torus(8.6, 9.1, 24), M_HAZ, Vector3(0, 0.19, 4.4), Vector3.ZERO, Vector3(1, 0.35, 1), false)
	# 后部主反应堆压力安全壳穹顶（置于 z = -8.0m，直径 11.2m，高 13.8m）
	var vc := Vector3(0, 0, -8.0)
	A.add(n, A.cyl(5.6, 6.8, 6.2, 16), M_CON, vc + Vector3(0, 3.4, 0))
	A.add(n, A.sphere(5.55, 4.8, 24), M_ST, vc + Vector3(0, 6.8, 0))
	# 磁约束超导铜线圈环箍 + 8 道外露重型钢肋扶壁 + 窄缝耐压泄温窗
	for k in 3:
		var ry := 2.2 + k * 2.1
		var rr := 5.95 - k * 0.18
		A.add(n, A.torus(rr - 0.16, rr + 0.24, 28), M_COP if k == 1 else M_ST, vc + Vector3(0, ry, 0), Vector3.ZERO, Vector3(1, 0.65, 1))
	for i in 8:
		var a := TAU * float(i) / 8.0
		var dir := Vector3(sin(a), 0, cos(a))
		A.add(n, A.bevel_box(Vector3(0.68, 9.6, 1.35), 0.04), M_DARK, vc + dir * 5.8 + Vector3(0, 4.8, 0), Vector3(-10, rad_to_deg(a), 0))
		if i in [0, 1, 7]:
			A.add(n, A.bevel_box(Vector3(0.95, 0.22, 0.18), 0.02), M_CORE, vc + dir * 5.62 + Vector3(0, 5.4, 0), Vector3(0, rad_to_deg(a), 0), Vector3.ONE, false)
	# 穹顶顶部高压主蒸汽集箱冠环
	A.add(n, A.cyl(1.85, 2.2, 2.35, 16), M_DARK, vc + Vector3(0, 12.2, 0))
	A.add(n, A.torus(1.9, 2.25, 20), M_HAZ, vc + Vector3(0, 13.1, 0), Vector3.ZERO, Vector3(1, 0.5, 1), false)
	_add_pillar_block(raid, p, vc, Vector3(11.8, 13.5, 11.8), rot, true)
	var gl := OmniLight3D.new()
	gl.light_color = Color(0.98, 0.44, 0.16)
	gl.light_energy = 4.2
	gl.omni_range = 20.0
	gl.shadow_enabled = false
	gl.position = vc + Vector3(0, 5.2, 6.4)
	n.add_child(gl)
	# 左右两侧双联地热冷凝换热高塔（x = ±9.6m, z = -4.6m）与跨顶高压蒸汽弯管拱廊
	for sx: float in [-1.0, 1.0]:
		var tc := Vector3(sx * 9.6, 0, -4.6)
		K.tower(raid, p + tc.rotated(Vector3.UP, deg_to_rad(rot)), 2.1, 14.2, 1.65, Color(0.36, 0.35, 0.38))
		var pipe_pts := [
			vc + Vector3(sx * 2.0, 12.6, 0.6),
			vc + Vector3(sx * 5.8, 14.2, 1.8),
			tc + Vector3(0, 11.8, 0),
		]
		A.add(n, A.tube(pipe_pts, 0.48, 12, 4), M_ST, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		A.add(n, A.torus(0.52, 0.68, 14), M_COP, vc + Vector3(sx * 4.2, 13.6, 1.3), Vector3(0, 0, sx * 72.0), Vector3.ONE, false)


# ---------------------------------------------------------------- 7. 东湾船坞港：巨型潜艇干船坞 (submarine_drydock)
static func _submarine_drydock(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M_CON := A.concrete(CONCRETE, true)
	var M_CDK := A.concrete(CONC_DARK, false)
	var M_HULL := A.paint(Color(0.16, 0.19, 0.22), 0.56, 0.48, {"rust": 0.45, "wear": 0.52, "panel_scale": 1.3})
	var M_KEEL := A.paint(Color(0.38, 0.16, 0.14), 0.46, 0.58, {"rust": 0.72, "wear": 0.60, "panel_scale": 1.2})
	var M_ORG := A.paint(Color(0.68, 0.34, 0.14), 0.58, 0.52, {"rust": 0.75, "wear": 0.62, "panel_scale": 1.4})
	var M_ST := A.paint(Color(0.28, 0.31, 0.34), 0.68, 0.46, {"rust": 0.58, "wear": 0.50})
	var M_DARK := A.metal(Color(0.11, 0.12, 0.14))
	var M_RST := A.corrugated(Color(0.34, 0.22, 0.16), 0.72, 0.36)
	var M_GL := A.glass(Color(0.24, 0.34, 0.40))
	var M_HAZ := A.hazard()
	var M_LAMP := A.emit(Color(1.0, 0.80, 0.46), 1.85)
	var M_WELD := A.emit(Color(0.34, 0.86, 1.0), 1.75)

	# 1. 干船坞重型钢筋混凝土坞底坪与前场龙门轨道道床（平齐地面不阻挡走位，z ∈ [-0.5, 11.5] 为敞开首领竞技台）
	A.add(n, A.bevel_box(Vector3(24.8, 0.12, 26.8), 0.04), M_CON, Vector3(0, 0.06, 0.2), Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.bevel_box(Vector3(16.8, 0.05, 16.0), 0.02), M_CDK, Vector3(0, 0.125, -4.4), Vector3.ZERO, Vector3.ONE, false)
	for sx: float in [-10.4, 10.4]:
		A.add(n, A.bevel_box(Vector3(1.15, 0.07, 25.2), 0.02), M_DARK, Vector3(sx, 0.13, 0.2), Vector3.ZERO, Vector3.ONE, false)
		A.add(n, A.bevel_box(Vector3(0.24, 0.06, 25.0), 0.01), M_ST, Vector3(sx - 0.24, 0.175, 0.2), Vector3.ZERO, Vector3.ONE, false)
		A.add(n, A.bevel_box(Vector3(0.24, 0.06, 25.0), 0.01), M_ST, Vector3(sx + 0.24, 0.175, 0.2), Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.bevel_box(Vector3(13.6, 0.03, 0.42), 0.01), M_HAZ, Vector3(0, 0.135, 9.6), Vector3.ZERO, Vector3.ONE, false)

	# 2. 坐墩龙骨上的未完工重型潜艇耐压壳体（置于后场 z = -6.8m，沿 X 轴横陈 12.6m，高 8.4m）
	var sub_c := Vector3(0, 0, -6.8)
	for kx in [-4.2, -1.8, 0.6, 3.0, 5.0]:
		A.add(n, A.bevel_box(Vector3(0.85, 1.05, 3.2), 0.04), M_CDK, sub_c + Vector3(kx, 0.56, 0))
		A.add(n, A.bevel_box(Vector3(0.92, 0.22, 3.26), 0.02), M_HAZ, sub_c + Vector3(kx, 1.02, 0))
	# 耐压潜艇主艇体（暗海军灰上壳 + 防污红底船底）与分段肋环
	A.add(n, A.cyl(2.15, 9.8, 2.15, 20), M_HULL, sub_c + Vector3(0.2, 2.75, 0), Vector3(0, 0, 90))
	A.add(n, A.bevel_box(Vector3(9.4, 1.15, 3.65), 0.14), M_KEEL, sub_c + Vector3(0.2, 1.65, 0))
	A.add(n, A.cyl(1.45, 2.6, 2.15, 18), M_HULL, sub_c + Vector3(-5.8, 2.75, 0), Vector3(0, 0, 90))
	A.add(n, A.cyl(2.15, 2.2, 1.10, 18), M_RST, sub_c + Vector3(6.2, 2.75, 0), Vector3(0, 0, 90))
	for rx in [-3.4, -1.2, 1.0, 3.2]:
		A.add(n, A.torus(2.08, 2.26, 22), M_ST, sub_c + Vector3(rx, 2.75, 0), Vector3(0, 0, 90))
	# 潜艇指挥室围壳（帆罩）与双潜望镜桅
	A.add(n, A.bevel_box(Vector3(3.4, 2.9, 1.32), 0.10), M_HULL, sub_c + Vector3(-0.6, 5.6, 0))
	A.add(n, A.bevel_box(Vector3(1.1, 0.24, 3.4), 0.04), M_ST, sub_c + Vector3(-0.4, 5.8, 0))
	for mx in [-1.1, -0.2, 0.5]:
		A.add(n, A.cyl(0.09, 2.1, 0.11, 10), M_DARK, sub_c + Vector3(mx, 7.6, 0), Vector3.ZERO, Vector3.ONE, false)
	# 船台脚手架施工栈桥
	for sz: float in [-2.6, 2.6]:
		A.add(n, A.bevel_box(Vector3(10.8, 0.24, 1.1), 0.02), M_RST, sub_c + Vector3(0, 2.9, sz))
		for px in [-4.8, 0.0, 4.8]:
			A.add(n, A.bevel_box(Vector3(0.26, 3.1, 0.26), 0.02), M_ST, sub_c + Vector3(px, 1.55, sz))
	_add_pillar_block(raid, p, sub_c + Vector3(0, 0, 0), Vector3(13.2, 7.2, 5.8), rot, false)

	# 3. 双侧造船厂泵房压载机库（后隅两侧，不侵占前场竞技台）
	for sx: float in [-1.0, 1.0]:
		var ph := Vector3(sx * 8.6, 0, -10.8)
		A.add(n, A.bevel_box(Vector3(4.2, 4.4, 3.6), 0.06), M_RST, ph + Vector3(0, 2.2, 0))
		A.add(n, A.bevel_box(Vector3(4.5, 0.42, 3.9), 0.04), M_CON, ph + Vector3(0, 4.45, 0))
		A.add(n, A.bevel_box(Vector3(1.5, 1.6, 0.18), 0.02), M_DARK, ph + Vector3(0, 1.8, 1.82))
		_add_pillar_block(raid, p, ph, Vector3(4.4, 4.8, 3.8), rot, false)

	# 4. 跨度 22.8 米、高 19.6 米重型造船龙门起重机（Goliath Gantry Crane）
	for sx: float in [-1.0, 1.0]:
		var gx := sx * 10.4
		for gz: float in [-7.6, 3.6]:
			A.add(n, A.bevel_box(Vector3(1.55, 1.35, 1.85), 0.05), M_DARK, Vector3(gx, 0.72, gz))
			A.add(n, A.bevel_box(Vector3(1.62, 0.26, 1.92), 0.02), M_HAZ, Vector3(gx, 0.95, gz))
			var leg_tilt := -8.5 if gz < 0.0 else 8.5
			A.add(n, A.bevel_box(Vector3(0.95, 16.4, 1.05), 0.04), M_ORG, Vector3(gx, 9.2, gz + (-1.0 if gz > 0.0 else 1.0)), Vector3(leg_tilt, 0, 0))
			_add_pillar_block(raid, p, Vector3(gx, 0, gz), Vector3(1.85, 16.0, 2.05), rot, false)
		# 侧框联系纵梁 + 梯道平台
		A.add(n, A.bevel_box(Vector3(0.75, 1.15, 11.4), 0.04), M_ORG, Vector3(gx, 16.8, -2.0))
		A.add(n, A.bevel_box(Vector3(0.65, 0.70, 12.0), 0.03), M_ST, Vector3(gx, 1.9, -2.0))
	# 顶部双箱梁主桥架（y = 17.8m，横跨干船坞全宽）+ 行走起重天车 + 下垂钢索吊钩
	for bz in [-3.4, -0.6]:
		A.add(n, A.bevel_box(Vector3(23.2, 2.1, 1.25), 0.05), M_ORG, Vector3(0, 17.9, bz))
		A.add(n, A.bevel_box(Vector3(23.4, 0.26, 1.32), 0.02), M_HAZ, Vector3(0, 16.95, bz))
	var trolley := Vector3(1.6, 19.2, -2.0)
	A.add(n, A.bevel_box(Vector3(4.2, 1.6, 4.4), 0.06), M_ST, trolley)
	A.add(n, A.bevel_box(Vector3(1.9, 1.35, 1.8), 0.04), M_GL, trolley + Vector3(-1.4, -1.2, 2.1), Vector3.ZERO, Vector3.ONE, false)
	for cx in [-0.7, 0.7]:
		A.add(n, A.tube([trolley + Vector3(cx, -1.0, -0.6), Vector3(1.6 + cx, 8.8, -6.2)], 0.08, 6, 3), M_DARK, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	# 起重横吊梁与双钢钩
	A.add(n, A.bevel_box(Vector3(2.8, 0.55, 0.95), 0.04), M_HAZ, Vector3(1.6, 8.8, -6.2), Vector3.ZERO, Vector3.ONE, false)

	# 5. 坞壁探照灯塔与前场照明（柔和补光不遮挡 Boss 战）
	for sx: float in [-1.0, 1.0]:
		A.add(n, A.bevel_box(Vector3(0.42, 0.85, 0.42), 0.03), M_LAMP, Vector3(sx * 9.8, 16.2, 1.4), Vector3(0, 0, sx * 18.0), Vector3.ONE, false)
	A.add(n, A.bevel_box(Vector3(2.6, 0.22, 0.22), 0.02), M_WELD, sub_c + Vector3(0.4, 3.1, 2.7), Vector3.ZERO, Vector3.ONE, false)
	var gl := OmniLight3D.new()
	gl.light_color = Color(0.96, 0.82, 0.58)
	gl.light_energy = 3.8
	gl.omni_range = 24.0
	gl.shadow_enabled = false
	gl.position = Vector3(0, 8.2, 2.2)
	n.add_child(gl)
