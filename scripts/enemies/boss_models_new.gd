extends RefCounted
## 六大战区地标专属首领（Landmark Bosses）的 3D 程序化重工业建模：
##   1. terminus_warden     （总站铁卫·巡道猎杀者）—— 四足装甲铁路清障猎杀机 + 楔形铸钢排障铲 + 双肩六管转轮机炮 + 顶置八联火箭巢
##   2. foundry_dreadnought （转炉铁甲·熔渣无畏舰）—— 八足重装铁水包攻城无畏舰 + 倾动炼钢坩埚主塔 + 双联重型穿甲臼炮
##   3. silo_warhead        （井群猎犬·弹道集群兽）—— 四足重型机动发射车构装兽 + 背负八管冷发射弹道导弹垂发箱 + 旋转相控阵雷达桅
##   4. spillway_leviathan  （闸枢巨鳌·深水破城兽）—— 六足水工重甲破坝巨鳌 + 双臂液压弧形闸门剪钳 + 双联高压压载水柜与火箭发射器
##   5. excavator_titan     （斗轮泰坦·裂岩掘进兽）—— 六足矿山巨型斗轮掘进泰坦 + 双臂旋转十齿斗轮切削盘 + 尾部混凝土配重桁架
##   6. core_overlord       （裂隙主宰·磁暴晶骸王）—— 六足深井超导磁约束反应堆主宰 + 双环感应铜线圈转子 + 双肩重型电磁轨道实弹炮

const ART = preload("res://scripts/art.gd")
const HS = preload("res://scripts/hs.gd")
const Bugs2 = preload("res://scripts/bugs2.gd")
const Models = preload("res://scripts/enemies/models.gd")
const BossGlb = preload("res://scripts/enemies/boss_glb.gd")


static func _core_doors(h, body: Node3D, pos: Vector3, s: float, sh_mat: Material, hz_mat: Material, glow_c: Color) -> void:
	var core: MeshInstance3D = h._p(body, ART.cyl(0.21 * s, 0.34 * s, 0.21 * s, 14), ART.emit(glow_c, 1.45), pos, Vector3(90, 0, 0), Vector3.ONE, false)
	h.core_mi = core
	h._p(body, ART.torus(0.20 * s, 0.25 * s, 16), h._brass(), pos + Vector3(0, 0, -0.14 * s), Vector3(90, 0, 0))
	for sx: float in [-1.0, 1.0]:
		var pl := Node3D.new()
		pl.position = pos + Vector3(sx * 0.24 * s, 0, -0.16 * s)
		pl.set_meta("side", sx)
		body.add_child(pl)
		h._box(pl, sh_mat, Vector3(-sx * 0.11 * s, 0, 0), Vector3(0.24, 0.44, 0.08) * s)
		h._box(pl, hz_mat, Vector3(-sx * 0.02 * s, 0, -0.045 * s), Vector3(0.05, 0.40, 0.02) * s)
		h.plates.append(pl)


# ---------------------------------------------------------------- 1. 总站铁卫·巡道猎杀者 (terminus_warden)
static func build_terminus_warden(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.23, 0.28, 0.32))
	var SH2: Material = h._vmat_solid(Color(0.36, 0.40, 0.44))
	var DK: Material = h._vmat_solid(Color(0.10, 0.11, 0.13))
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.04))
	var ST: Material = h._steel()
	var BR: Material = h._brass()
	var RS: Material = h._rust_plate()
	var HZ: Material = h._hazard_yel()
	var CYAN := Color(0.28, 0.86, 0.96)
	var by := 1.05 * s
	# 内燃机车式铆接装甲车体 + 顶部散热百叶格栅
	h._loft(body, HS.crect(1.0, 1.0, 0.22), [
		[-0.95 * s, Vector2(0.96, 0.56) * s, Vector2.ZERO],
		[-0.25 * s, Vector2(1.18, 0.68) * s, Vector2(0, 0.05 * s)],
		[0.65 * s, Vector2(1.12, 0.64) * s, Vector2(0, 0.04 * s)],
		[1.25 * s, Vector2(0.84, 0.48) * s, Vector2.ZERO],
	], SH, Vector3(0, by, 0))
	h._panels(body, Vector3(0, by + 0.38 * s, 0.10 * s), Vector3(-90, 0, 0), 0.96 * s, 1.65 * s, 701, 6)
	for sx: float in [-1.0, 1.0]:
		h._box(body, HZ, Vector3(sx * 0.60 * s, by + 0.04 * s, 0.12 * s), Vector3(0.05, 0.14, 1.68) * s)
		# 机车柴油机排烟短管（深黑烟膛）
		var ep := Vector3(sx * 0.36 * s, by + 0.58 * s, 0.72 * s)
		h._p(body, ART.cyl(0.08 * s, 0.38 * s, 0.095 * s, 10), DK, ep, Vector3(-12, 0, 0))
		h._p(body, ART.cyl(0.065 * s, 0.05 * s, 0.065 * s, 10), BL, ep + Vector3(0, 0.19 * s, 0.04 * s), Vector3(-12, 0, 0), Vector3.ONE, false)
	# 首部重型机车楔形铸钢排障铲（cowcatcher）+ 装甲防弹车头 + 核心防爆门
	var prow := Node3D.new()
	prow.position = Vector3(0, by - 0.18 * s, -1.06 * s)
	body.add_child(prow)
	h._prism(prow, [Vector2(-0.68, 0.26) * s, Vector2(0.68, 0.26) * s, Vector2(0.56, -0.30) * s, Vector2(0, -0.44) * s, Vector2(-0.56, -0.30) * s],
		0.42 * s, 0.06, RS, Vector3(0, -0.06 * s, -0.10 * s), Vector3(24, 0, 0))
	for k in 5:
		var rx := (k - 2) * 0.24 * s
		h._box(prow, HZ if k % 2 == 0 else ST, Vector3(rx, -0.12 * s, -0.28 * s), Vector3(0.06, 0.46, 0.08) * s, Vector3(28, 0, 0))
	for sx: float in [-1.0, 1.0]:
		Models._eye(h, prow, Vector3(sx * 0.32 * s, 0.42 * s, 0.06 * s), 0.075 * s, CYAN)
		var j := Node3D.new()
		j.position = Vector3(sx * 0.46 * s, -0.08 * s, -0.12 * s)
		prow.add_child(j)
		h._jag(j, 0.16 * s, 0.48 * s, 0.065 * s, ST, Vector3.ZERO, Vector3(-72, sx * -14.0, 0), 3, -1.0, 0.0)
		h.jaws.append(j)
	_core_doors(h, body, Vector3(0, by + 0.14 * s, -0.84 * s), s, SH2, HZ, CYAN)
	# 双肩转轮机炮吊舱（spinners 实时旋转六联钢制枪管）+ 顶置八联尾翼火箭发射箱
	for sx: float in [-1.0, 1.0]:
		var pod := Node3D.new()
		pod.position = Vector3(sx * 0.72 * s, by + 0.36 * s, -0.26 * s)
		body.add_child(pod)
		h._box(pod, SH2, Vector3.ZERO, Vector3(0.32, 0.30, 0.56) * s)
		var rot_brl := Node3D.new()
		rot_brl.position = Vector3(0, 0, -0.32 * s)
		pod.add_child(rot_brl)
		h._p(rot_brl, ART.cyl(0.11 * s, 0.12 * s, 0.11 * s, 12), BR, Vector3.ZERO, Vector3(90, 0, 0))
		for bi in 6:
			var ba := TAU * float(bi) / 6.0
			h._p(rot_brl, ART.cyl(0.024 * s, 0.68 * s, 0.026 * s, 8), ST,
				Vector3(cos(ba) * 0.075 * s, sin(ba) * 0.075 * s, -0.32 * s), Vector3(90, 0, 0))
		h.spinners.append([rot_brl, Vector3.FORWARD, 3.0 * sx, 22.0 * sx])
	var rbox := Node3D.new()
	rbox.position = Vector3(0, by + 0.66 * s, 0.14 * s)
	rbox.rotation_degrees.x = 14.0
	body.add_child(rbox)
	h._box(rbox, DK, Vector3.ZERO, Vector3(0.86, 0.36, 0.62) * s)
	h._box(rbox, HZ, Vector3(0, 0.19 * s, 0), Vector3(0.88, 0.04, 0.64) * s)
	for rx_i in 4:
		for ry_i in 2:
			var tx := (-0.285 + rx_i * 0.19) * s
			var ty := (-0.075 + ry_i * 0.15) * s
			h._p(rbox, ART.cyl(0.068 * s, 0.08 * s, 0.068 * s, 10), ST, Vector3(tx, ty, -0.31 * s), Vector3(90, 0, 0))
			h._p(rbox, ART.cyl(0.052 * s, 0.06 * s, 0.052 * s, 10), BL, Vector3(tx, ty, -0.33 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	# 四条重装机车液压步足
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			h._mleg(body, Vector3(sx * 0.54 * s, by - 0.10 * s, (-0.36 + i * 0.82) * s), sx * (-24.0 + i * 48.0), sx,
				1.38 * s, by, 0.115 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), i == 1)


# ---------------------------------------------------------------- 2. 转炉铁甲·熔渣无畏舰 (foundry_dreadnought)
static func build_foundry_dreadnought(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.28, 0.22, 0.19))
	var SH2: Material = h._vmat_solid(Color(0.38, 0.35, 0.32))
	var DK: Material = h._vmat_solid(Color(0.10, 0.10, 0.11))
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.035))
	var ST: Material = h._steel()
	var BR: Material = h._brass()
	var RS: Material = h._rust_plate()
	var HZ: Material = h._hazard_yel()
	var SLAG := Color(1.0, 0.44, 0.12)
	var by := 1.06 * s
	# 超重型八角铸钢高炉底盘
	h._loft(body, HS.crect(1.0, 1.0, 0.28), [
		[-1.08 * s, Vector2(1.24, 0.50) * s, Vector2.ZERO],
		[-0.36 * s, Vector2(1.58, 0.62) * s, Vector2(0, 0.04 * s)],
		[0.58 * s, Vector2(1.52, 0.60) * s, Vector2(0, 0.04 * s)],
		[1.26 * s, Vector2(1.12, 0.46) * s, Vector2.ZERO],
	], DK, Vector3(0, by, 0))
	Models._shell_layer(h, body, Vector3(0, by + 0.30 * s, 0.10 * s), Vector3(1.42, 0.36, 1.72) * s, SH, 0.0)
	# 背负倾动式钢包转炉坩埚主塔 + 耳轴支架 + 双联重型穿甲臼炮
	var lad := Node3D.new()
	lad.position = Vector3(0, by + 0.88 * s, 0.16 * s)
	lad.rotation_degrees.x = 16.0
	body.add_child(lad)
	h._p(lad, ART.torus(0.56 * s, 0.68 * s, 20), ST, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.25, 1))
	h._p(lad, ART.cyl(0.54 * s, 0.78 * s, 0.44 * s, 20), RS, Vector3(0, -0.18 * s, 0))
	h._p(lad, ART.cyl(0.36 * s, 0.44 * s, 0.54 * s, 20), SH, Vector3(0, 0.42 * s, 0))
	h._p(lad, ART.cyl(0.30 * s, 0.08 * s, 0.32 * s, 16), ART.emit(SLAG, 1.55), Vector3(0, 0.62 * s, 0), Vector3.ZERO, Vector3.ONE, false)
	for sx: float in [-1.0, 1.0]:
		h._box(body, SH2, Vector3(sx * 0.68 * s, by + 0.62 * s, 0.16 * s), Vector3(0.20, 0.64, 0.38) * s)
		# 双肩重型制退穿甲火炮
		var gun := Node3D.new()
		gun.position = Vector3(sx * 0.74 * s, by + 0.48 * s, -0.44 * s)
		gun.rotation_degrees.x = 8.0
		body.add_child(gun)
		h._box(gun, SH2, Vector3.ZERO, Vector3(0.32, 0.30, 0.54) * s)
		h._p(gun, ART.cyl(0.11 * s, 0.88 * s, 0.13 * s, 14), ST, Vector3(0, 0.02 * s, -0.58 * s), Vector3(90, 0, 0))
		h._p(gun, ART.cyl(0.14 * s, 0.18 * s, 0.14 * s, 14), BR, Vector3(0, 0.02 * s, -0.32 * s), Vector3(90, 0, 0))
		h._p(gun, ART.cyl(0.085 * s, 0.08 * s, 0.085 * s, 12), BL, Vector3(0, 0.02 * s, -1.01 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	# 首部重装耐火砖冲撞盾、液压破渣钳臂与熔炉核心门
	_core_doors(h, body, Vector3(0, by + 0.18 * s, -0.96 * s), s * 1.12, RS, HZ, SLAG)
	for sx: float in [-1.0, 1.0]:
		Models._eye(h, body, Vector3(sx * 0.42 * s, by + 0.42 * s, -0.98 * s), 0.075 * s, SLAG)
		var sc := Node3D.new()
		sc.position = Vector3(sx * 0.72 * s, by + 0.06 * s, -0.82 * s)
		sc.rotation_degrees.y = sx * 16.0
		body.add_child(sc)
		h._servo(sc, Vector3.ZERO, 0.16 * s)
		var el := Vector3(sx * 0.28, -0.18, -0.54) * s
		h._limb(sc, Vector3.ZERO, el, 0.18 * s, 0.20 * s, SH2, 0.8, 1.2)
		h._hydraulic(sc, Vector3(0, 0.14 * s, 0), el + Vector3(0, 0.10 * s, 0.05 * s), 0.042 * s, DK)
		h._jag(sc, 0.28 * s, 0.88 * s, 0.085 * s, ST, el, Vector3(-66, sx * 8.0, 0), 4, -1.0, sx * 0.08 * s)
		h.scythes.append(sc)
	# 八条攻城重甲支腿
	for i in 4:
		for sx: float in [-1.0, 1.0]:
			h._mleg(body, Vector3(sx * 0.68 * s, by - 0.12 * s, (-0.68 + i * 0.48) * s), sx * (-30.0 + i * 20.0), sx,
				1.34 * s, by, 0.11 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), i >= 2)


# ---------------------------------------------------------------- 3. 井群猎犬·弹道集群兽 (silo_warhead)
static func build_silo_warhead(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.32, 0.31, 0.24))
	var SH2: Material = h._vmat_solid(Color(0.42, 0.39, 0.31))
	var DK: Material = h._vmat_solid(Color(0.11, 0.11, 0.12))
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.04))
	var ST: Material = h._steel()
	var BR: Material = h._brass()
	var RS: Material = h._rust_plate()
	var HZ: Material = h._hazard_yel()
	var AMBER := Color(1.0, 0.62, 0.18)
	var by := 1.08 * s
	# 军工橄榄褐重型机动导弹发射车（TEL）折角装甲底盘
	h._loft(body, HS.crect(1.0, 1.0, 0.20), [
		[-1.02 * s, Vector2(1.06, 0.50) * s, Vector2.ZERO],
		[-0.28 * s, Vector2(1.26, 0.58) * s, Vector2(0, 0.04 * s)],
		[0.72 * s, Vector2(1.22, 0.56) * s, Vector2(0, 0.04 * s)],
		[1.36 * s, Vector2(0.92, 0.44) * s, Vector2.ZERO],
	], SH, Vector3(0, by, 0))
	# 背部昂起的双联四管（共八管）冷发射战略导弹储运发射筒组 + 液压起竖臂
	var vls := Node3D.new()
	vls.position = Vector3(0, by + 0.64 * s, 0.24 * s)
	vls.rotation_degrees.x = 28.0
	body.add_child(vls)
	h._box(vls, DK, Vector3(0, 0, 0.08 * s), Vector3(1.14, 0.56, 1.46) * s)
	for cx in 4:
		for cy in 2:
			var tx := (-0.39 + cx * 0.26) * s
			var ty := (-0.13 + cy * 0.26) * s
			h._p(vls, ART.cyl(0.115 * s, 1.52 * s, 0.115 * s, 12), SH2, Vector3(tx, ty, 0.06 * s), Vector3(90, 0, 0))
			h._p(vls, ART.cyl(0.122 * s, 0.08 * s, 0.122 * s, 12), HZ, Vector3(tx, ty, -0.62 * s), Vector3(90, 0, 0))
			h._p(vls, ART.cyl(0.092 * s, 0.06 * s, 0.092 * s, 10), BL, Vector3(tx, ty, -0.71 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	for sx: float in [-1.0, 1.0]:
		h._hydraulic(body, Vector3(sx * 0.44 * s, by + 0.18 * s, -0.20 * s), Vector3(sx * 0.44 * s, by + 0.72 * s, 0.05 * s), 0.048 * s, ST)
	# 顶部旋转战术制导相控阵雷达桅杆（spinners）
	var radar := Node3D.new()
	radar.position = Vector3(0, by + 1.18 * s, -0.46 * s)
	body.add_child(radar)
	h._p(radar, ART.cyl(0.08 * s, 0.26 * s, 0.11 * s, 10), BR, Vector3.ZERO)
	h._box(radar, SH2, Vector3(0, 0.18 * s, 0), Vector3(0.76, 0.22, 0.10) * s, Vector3(-10, 0, 0))
	h._box(radar, HZ, Vector3(0, 0.30 * s, 0), Vector3(0.78, 0.04, 0.11) * s)
	h.spinners.append([radar, Vector3.UP, 2.2, 7.5])
	# 前端防核爆斜面驾驶战斗室 + 平射机炮管 + 核心舱门
	var cab := Node3D.new()
	cab.position = Vector3(0, by + 0.12 * s, -0.96 * s)
	body.add_child(cab)
	h._prism(cab, [Vector2(-0.54, 0.24) * s, Vector2(0.54, 0.24) * s, Vector2(0.46, -0.22) * s, Vector2(-0.46, -0.22) * s],
		0.40 * s, 0.06, RS, Vector3.ZERO)
	for sx: float in [-1.0, 1.0]:
		Models._eye(h, cab, Vector3(sx * 0.28 * s, 0.10 * s, -0.18 * s), 0.07 * s, AMBER)
		h._p(cab, ART.cyl(0.045 * s, 0.62 * s, 0.055 * s, 10), ST, Vector3(sx * 0.48 * s, -0.04 * s, -0.36 * s), Vector3(90, 0, 0))
		var j := Node3D.new()
		j.position = Vector3(sx * 0.36 * s, -0.18 * s, -0.16 * s)
		cab.add_child(j)
		h._jag(j, 0.15 * s, 0.50 * s, 0.065 * s, ST, Vector3.ZERO, Vector3(-70, 0, sx * 16.0), 3, -1.0, 0.0)
		h.jaws.append(j)
	_core_doors(h, body, Vector3(0, by - 0.02 * s, -0.82 * s), s, SH2, HZ, AMBER)
	# 四条高机动重型驻锄机械步足
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			h._mleg(body, Vector3(sx * 0.56 * s, by - 0.10 * s, (-0.38 + i * 0.88) * s), sx * (-22.0 + i * 46.0), sx,
				1.44 * s, by, 0.115 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), i == 1)


# ---------------------------------------------------------------- 4. 闸枢巨鳌·深水破城兽 (spillway_leviathan)
static func build_spillway_leviathan(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.20, 0.31, 0.35))
	var SH2: Material = h._vmat_solid(Color(0.33, 0.42, 0.45))
	var DK: Material = h._vmat_solid(Color(0.09, 0.11, 0.13))
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.04))
	var ST: Material = h._steel()
	var BR: Material = h._brass()
	var RS: Material = h._rust_plate()
	var HZ: Material = h._hazard_yel()
	var AQUA := Color(0.24, 0.86, 0.94)
	var by := 1.02 * s
	# 宽扁水工沉箱式重甲蟹形躯壳 + 双联高压钢箍压载水柜 + 鱼雷火箭发射巢
	h._loft(body, HS.crect(1.0, 1.0, 0.30), [
		[-0.86 * s, Vector2(1.38, 0.52) * s, Vector2.ZERO],
		[-0.12 * s, Vector2(1.76, 0.64) * s, Vector2(0, 0.04 * s)],
		[0.64 * s, Vector2(1.56, 0.58) * s, Vector2(0, 0.03 * s)],
		[1.18 * s, Vector2(1.04, 0.42) * s, Vector2.ZERO],
	], SH, Vector3(0, by, 0))
	h._panels(body, Vector3(0, by + 0.36 * s, 0.04 * s), Vector3(-90, 0, 0), 1.38 * s, 1.36 * s, 704, 6)
	for sx: float in [-1.0, 1.0]:
		var tk := Vector3(sx * 0.56 * s, by + 0.56 * s, 0.32 * s)
		h._p(body, ART.cyl(0.26 * s, 1.08 * s, 0.26 * s, 16), RS, tk, Vector3(82, sx * -8.0, 0))
		for bi in [-0.28, 0.28]:
			h._p(body, ART.torus(0.25 * s, 0.29 * s, 16), BR, tk + Vector3(0, 0.04 * s, bi * s), Vector3(82, sx * -8.0, 0))
		h._p(body, ART.cyl(0.20 * s, 0.08 * s, 0.20 * s, 14), BL, tk + Vector3(sx * -0.06 * s, 0.08 * s, -0.53 * s), Vector3(82, sx * -8.0, 0), Vector3.ONE, false)
	# 首部深潜耐压观察窗 + 核心水密防爆门
	for sx: float in [-1.0, 1.0]:
		Models._eye(h, body, Vector3(sx * 0.38 * s, by + 0.34 * s, -0.84 * s), 0.08 * s, AQUA)
	_core_doors(h, body, Vector3(0, by + 0.10 * s, -0.82 * s), s * 1.08, SH2, HZ, AQUA)
	# 双臂巨型液压弧形闸门破城剪钳（scythes）
	for sx: float in [-1.0, 1.0]:
		var claw := Node3D.new()
		claw.position = Vector3(sx * 0.84 * s, by + 0.12 * s, -0.62 * s)
		claw.rotation_degrees.y = sx * 22.0
		body.add_child(claw)
		h._servo(claw, Vector3.ZERO, 0.18 * s)
		var el := Vector3(sx * 0.36, -0.10, -0.62) * s
		h._limb(claw, Vector3.ZERO, el, 0.22 * s, 0.25 * s, SH2, 0.78, 1.24)
		h._hydraulic(claw, Vector3(0, 0.16 * s, 0), el + Vector3(0, 0.14 * s, 0.06 * s), 0.048 * s, ST)
		# 重型铆接钢闸钳掌 + 上下咬合钨钢剪齿
		h._box(claw, RS, el + Vector3(0, 0, -0.28 * s), Vector3(0.32, 0.38, 0.52) * s)
		h._box(claw, HZ, el + Vector3(sx * 0.165 * s, 0, -0.28 * s), Vector3(0.03, 0.34, 0.46) * s)
		h._jag(claw, 0.24 * s, 0.78 * s, 0.085 * s, ST, el + Vector3(0, 0.12 * s, -0.44 * s), Vector3(-78, sx * -10.0, 0), 4, -1.0, 0.0)
		h._jag(claw, 0.22 * s, 0.72 * s, 0.080 * s, Models._bone(), el + Vector3(0, -0.12 * s, -0.44 * s), Vector3(-62, sx * -10.0, 180), 3, -1.0, 0.0)
		h.scythes.append(claw)
	# 六条横向撑开的螃蟹式水工桩腿
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			h._mleg(body, Vector3(sx * 0.74 * s, by - 0.10 * s, (-0.44 + i * 0.52) * s), sx * (-26.0 + i * 26.0), sx,
				1.40 * s, by, 0.115 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), i == 2)


# ---------------------------------------------------------------- 5. 斗轮泰坦·裂岩掘进兽 (excavator_titan)
static func build_excavator_titan(h, body: Node3D, s: float) -> void:
	if BossGlb.build(h, body, "excavator_titan", s):
		return
	var SH: Material = h._vmat_matte(Color(0.46, 0.35, 0.15))
	var SH2: Material = h._vmat_solid(Color(0.34, 0.34, 0.36))
	var DK: Material = h._vmat_solid(Color(0.11, 0.11, 0.12))
	var ST: Material = h._steel()
	var BR: Material = h._brass()
	var RS: Material = h._rust_plate()
	var HZ: Material = h._hazard_yel()
	var GOLD := Color(1.0, 0.68, 0.18)
	var by := 1.08 * s
	# 工程黄重型矿山回转主机船体 + 后伸钢桁混凝土配重尾梁（abdomen）
	h._loft(body, HS.crect(1.0, 1.0, 0.22), [
		[-0.96 * s, Vector2(1.18, 0.56) * s, Vector2.ZERO],
		[-0.20 * s, Vector2(1.42, 0.68) * s, Vector2(0, 0.04 * s)],
		[0.62 * s, Vector2(1.28, 0.62) * s, Vector2(0, 0.04 * s)],
		[1.18 * s, Vector2(0.92, 0.46) * s, Vector2.ZERO],
	], SH, Vector3(0, by, 0))
	var tail := Node3D.new()
	tail.position = Vector3(0, by + 0.32 * s, 0.96 * s)
	body.add_child(tail)
	h._box(tail, SH2, Vector3(0, 0.12 * s, 0.42 * s), Vector3(0.68, 0.30, 0.92) * s, Vector3(8, 0, 0))
	h._box(tail, DK, Vector3(0, 0.06 * s, 0.96 * s), Vector3(0.96, 0.52, 0.48) * s)
	h._box(tail, HZ, Vector3(0, 0.06 * s, 1.21 * s), Vector3(0.92, 0.14, 0.03) * s)
	h.abdomen = tail
	# 顶部 A 字钢桅拉索塔架 + 矿山防滚架驾驶舱 + 核心防爆门
	for sx: float in [-1.0, 1.0]:
		h._bar(body, Vector3(sx * 0.42 * s, by + 0.34 * s, -0.10 * s), Vector3(sx * 0.16 * s, by + 1.24 * s, 0.08 * s), 0.07 * s, 0.055 * s, ST)
		Models._eye(h, body, Vector3(sx * 0.34 * s, by + 0.46 * s, -0.88 * s), 0.075 * s, GOLD)
	h._box(body, RS, Vector3(0, by + 1.24 * s, 0.08 * s), Vector3(0.52, 0.16, 0.24) * s)
	_core_doors(h, body, Vector3(0, by + 0.12 * s, -0.88 * s), s * 1.10, SH2, HZ, GOLD)
	# 双臂悬挑钢桁架 + 实时高速旋转十斗切削斗轮（scythes + spinners！）
	for sx: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.74 * s, by + 0.26 * s, -0.58 * s)
		arm.rotation_degrees.y = sx * 16.0
		body.add_child(arm)
		h._servo(arm, Vector3.ZERO, 0.17 * s)
		var el := Vector3(sx * 0.24, -0.14, -0.78) * s
		h._bar(arm, Vector3.ZERO, el, 0.20 * s, 0.18 * s, SH)
		h._hydraulic(arm, Vector3(0, 0.18 * s, 0), el + Vector3(0, 0.12 * s, 0.10 * s), 0.045 * s, ST)
		var wheel := Node3D.new()
		wheel.position = el
		arm.add_child(wheel)
		h._p(wheel, ART.torus(0.38 * s, 0.48 * s, 18), RS, Vector3.ZERO, Vector3(0, 0, 90))
		h._p(wheel, ART.cyl(0.16 * s, 0.24 * s, 0.16 * s, 14), BR, Vector3.ZERO, Vector3(0, 0, 90))
		for bi in 8:
			var ba := TAU * float(bi) / 8.0
			var bp := Vector3(0, sin(ba) * 0.49 * s, cos(ba) * 0.49 * s)
			h._box(wheel, SH if bi % 2 == 0 else ST, bp, Vector3(0.20, 0.16, 0.20) * s, Vector3(-rad_to_deg(ba), 0, 0))
		h.spinners.append([wheel, Vector3.RIGHT, 3.2, 16.0])
		h.scythes.append(arm)
	# 六条矿山重装掘进支腿
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			h._mleg(body, Vector3(sx * 0.66 * s, by - 0.12 * s, (-0.48 + i * 0.54) * s), sx * (-26.0 + i * 26.0), sx,
				1.42 * s, by, 0.12 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), i == 2)


# ---------------------------------------------------------------- 6. 裂隙主宰·磁暴晶骸王 (core_overlord)
static func build_core_overlord(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.20, 0.22, 0.26))
	var SH2: Material = h._vmat_solid(Color(0.32, 0.34, 0.38))
	var DK: Material = h._vmat_solid(Color(0.09, 0.10, 0.12))
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.04))
	var ST: Material = h._steel()
	var COP: Material = h._vmat_solid(Color(0.72, 0.44, 0.20))
	var HZ: Material = h._hazard_yel()
	var MAGMA := Color(1.0, 0.42, 0.16)
	var by := 1.10 * s
	# 深井重装六角超导涡轮底盘
	h._loft(body, HS.crect(1.0, 1.0, 0.26), [
		[-1.02 * s, Vector2(1.20, 0.54) * s, Vector2.ZERO],
		[-0.24 * s, Vector2(1.52, 0.66) * s, Vector2(0, 0.05 * s)],
		[0.58 * s, Vector2(1.44, 0.62) * s, Vector2(0, 0.04 * s)],
		[1.22 * s, Vector2(1.02, 0.46) * s, Vector2.ZERO],
	], DK, Vector3(0, by, 0))
	Models._shell_layer(h, body, Vector3(0, by + 0.30 * s, 0.08 * s), Vector3(1.36, 0.36, 1.62) * s, SH, 0.0)
	# 背部重型超导紫铜感应磁约束转子塔（spinners 刚性连接于轴承座，绝无悬浮零件）
	var mount := Node3D.new()
	mount.position = Vector3(0, by + 0.56 * s, 0.12 * s)
	body.add_child(mount)
	h._p(mount, ART.cyl(0.36 * s, 0.42 * s, 0.44 * s, 16), SH2, Vector3(0, 0.16 * s, 0))
	var rotor := Node3D.new()
	rotor.position = Vector3(0, 0.54 * s, 0)
	mount.add_child(rotor)
	h._p(rotor, ART.cyl(0.18 * s, 0.68 * s, 0.18 * s, 14), ST, Vector3.ZERO)
	h._p(rotor, ART.torus(0.54 * s, 0.66 * s, 20), COP, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.75, 1))
	for k in 4:
		var a := TAU * float(k) / 4.0
		h._box(rotor, ST, Vector3(sin(a) * 0.36 * s, 0, cos(a) * 0.36 * s), Vector3(0.12, 0.16, 0.42) * s, Vector3(0, rad_to_deg(a), 0))
		h._box(rotor, HZ, Vector3(sin(a) * 0.62 * s, 0, cos(a) * 0.62 * s), Vector3(0.16, 0.24, 0.14) * s, Vector3(0, rad_to_deg(a), 0))
	h.spinners.append([rotor, Vector3.UP, 2.8, 14.0])
	# 双肩长身管电磁轨道钨芯穿甲炮（实弹导轨炮管 + 铜励磁箍 + 黑膛口）
	for sx: float in [-1.0, 1.0]:
		var rail := Node3D.new()
		rail.position = Vector3(sx * 0.76 * s, by + 0.52 * s, -0.32 * s)
		rail.rotation_degrees.x = 4.0
		body.add_child(rail)
		h._box(rail, SH2, Vector3.ZERO, Vector3(0.34, 0.32, 0.64) * s)
		for ry_s: float in [-0.07, 0.07]:
			h._box(rail, ST, Vector3(0, ry_s * s, -0.68 * s), Vector3(0.14, 0.055, 0.96) * s)
		for ci in 3:
			h._box(rail, COP, Vector3(0, 0, (-0.42 - ci * 0.26) * s), Vector3(0.20, 0.20, 0.07) * s)
		h._box(rail, BL, Vector3(0, 0, -1.14 * s), Vector3(0.09, 0.09, 0.06) * s, Vector3.ZERO)
		Models._eye(h, body, Vector3(sx * 0.38 * s, by + 0.42 * s, -0.94 * s), 0.08 * s, MAGMA)
		var j := Node3D.new()
		j.position = Vector3(sx * 0.48 * s, by - 0.04 * s, -0.88 * s)
		body.add_child(j)
		h._jag(j, 0.20 * s, 0.64 * s, 0.075 * s, ST, Vector3.ZERO, Vector3(-68, sx * -12.0, 0), 4, -1.0, 0.0)
		h.jaws.append(j)
	_core_doors(h, body, Vector3(0, by + 0.14 * s, -0.92 * s), s * 1.15, SH2, HZ, MAGMA)
	# 六条重装绝缘耐压机械步足
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			h._mleg(body, Vector3(sx * 0.68 * s, by - 0.12 * s, (-0.50 + i * 0.54) * s), sx * (-28.0 + i * 28.0), sx,
				1.46 * s, by, 0.12 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), i == 2)


# ---------------------------------------------------------------- 7. 船坞巨兽·深水龙门王 (drydock_behemoth)
static func build_drydock_behemoth(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.20, 0.28, 0.34))
	var SH2: Material = h._vmat_solid(Color(0.32, 0.38, 0.42))
	var DK: Material = h._vmat_solid(Color(0.10, 0.12, 0.14))
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.04))
	var ST: Material = h._steel()
	var BR: Material = h._brass()
	var RS: Material = h._rust_plate()
	var HZ: Material = h._hazard_yel()
	var TEAL := Color(0.28, 0.82, 0.96)
	var by := 1.06 * s
	# 潜艇耐压壳式重装甲底盘 + 红锈防污下腹 + 分段肋骨钢箍
	h._loft(body, HS.crect(1.0, 1.0, 0.28), [
		[-0.98 * s, Vector2(1.08, 0.52) * s, Vector2.ZERO],
		[-0.20 * s, Vector2(1.42, 0.66) * s, Vector2(0, 0.05 * s)],
		[0.62 * s, Vector2(1.36, 0.62) * s, Vector2(0, 0.04 * s)],
		[1.24 * s, Vector2(0.96, 0.46) * s, Vector2.ZERO],
	], SH, Vector3(0, by, 0))
	h._box(body, RS, Vector3(0, by - 0.24 * s, 0.10 * s), Vector3(1.16, 0.22, 1.88) * s)
	h._panels(body, Vector3(0, by + 0.36 * s, 0.08 * s), Vector3(-90, 0, 0), 1.24 * s, 1.68 * s, 771, 7)
	# 背部指挥塔帆罩与旋转声呐雷达桅（spinners）
	var sail := Node3D.new()
	sail.position = Vector3(0, by + 0.62 * s, 0.16 * s)
	body.add_child(sail)
	h._box(sail, SH2, Vector3.ZERO, Vector3(0.76, 0.56, 1.05) * s)
	h._box(sail, HZ, Vector3(0, 0.20 * s, -0.53 * s), Vector3(0.78, 0.09, 0.02) * s)
	var mast := Node3D.new()
	mast.position = Vector3(0, 0.36 * s, 0.18 * s)
	sail.add_child(mast)
	h._p(mast, ART.cyl(0.08 * s, 0.38 * s, 0.09 * s, 10), ST, Vector3(0, 0.18 * s, 0))
	h._box(mast, SH2, Vector3(0, 0.40 * s, 0), Vector3(0.78, 0.14, 0.18) * s)
	h.spinners.append([mast, Vector3.UP, 2.6, 12.0])
	# 舰首破冰艏柱、光学潜望观瞄窗与防爆核心门
	Models._shell_layer(h, body, Vector3(0, by + 0.14 * s, -0.78 * s), Vector3(1.12, 0.42, 0.72) * s, SH2, 8.0)
	for sx: float in [-1.0, 1.0]:
		Models._eye(h, body, Vector3(sx * 0.36 * s, by + 0.32 * s, -0.96 * s), 0.08 * s, TEAL)
		# 双联海军发射筒罐（背部两侧斜置）
		var pod := Node3D.new()
		pod.position = Vector3(sx * 0.78 * s, by + 0.48 * s, 0.20 * s)
		pod.rotation_degrees = Vector3(16.0, 0, sx * -10.0)
		body.add_child(pod)
		h._p(pod, ART.cyl(0.18 * s, 0.92 * s, 0.20 * s, 14), DK, Vector3.ZERO, Vector3(90, 0, 0))
		h._p(pod, ART.torus(0.17 * s, 0.22 * s, 14), BR, Vector3(0, 0, -0.34 * s), Vector3(90, 0, 0))
		h._p(pod, ART.cyl(0.14 * s, 0.05 * s, 0.14 * s, 12), BL, Vector3(0, 0, -0.46 * s), Vector3(90, 0, 0), Vector3.ONE, false)
		# 龙门重型液压破拆剪钳臂（scythes & jaws）
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.84 * s, by + 0.02 * s, -0.64 * s)
		arm.rotation_degrees.y = sx * 16.0
		body.add_child(arm)
		h._servo(arm, Vector3.ZERO, 0.18 * s)
		var el := Vector3(sx * 0.28, -0.10, -0.72) * s
		h._bar(arm, Vector3.ZERO, el, 0.20 * s, 0.18 * s, SH2)
		h._hydraulic(arm, Vector3(0, 0.16 * s, 0), el + Vector3(0, 0.12 * s, 0.10 * s), 0.048 * s, ST)
		h._box(arm, HZ, el + Vector3(0, 0, -0.26 * s), Vector3(0.24, 0.26, 0.42) * s)
		h._jag(arm, 0.24 * s, 0.78 * s, 0.095 * s, ST, el + Vector3(0, 0, -0.46 * s), Vector3(-76, sx * -10.0, 0), 3, -1.0, 0.0)
		h.scythes.append(arm)
	_core_doors(h, body, Vector3(0, by + 0.12 * s, -0.92 * s), s * 1.12, SH2, HZ, TEAL)
	# 六条造船龙门液压机械步足
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			h._mleg(body, Vector3(sx * 0.66 * s, by - 0.12 * s, (-0.48 + i * 0.54) * s), sx * (-26.0 + i * 26.0), sx,
				1.44 * s, by, 0.12 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), i == 2)
