extends RefCounted
## 区域主 Boss 的程序化建模（6 只主 Boss + 委托 boss_models_ext 的 6 只副 Boss，共 12 只）。
## 统一遵循市面级写实重工业军工/矿山工程美学：铆接铸钢、防锈红底漆、军工橄榄灰、工程警示黄、黄铜法兰、双级镀铬液压油缸、
## 穿孔防烫烟囱（深黑烟膛）与内凹光学观瞄窗；彻底杜绝悬浮发光呼啦圈、裸露刺眼光球与有机脓泡。

const ART = preload("res://scripts/art.gd")
const HS = preload("res://scripts/hs.gd")
const Bugs2 = preload("res://scripts/bugs2.gd")
const Models = preload("res://scripts/enemies/models.gd")
const Ext = preload("res://scripts/enemies/boss_models_ext.gd")
const NewLM = preload("res://scripts/enemies/boss_models_new.gd")
const ModularGlb = preload("res://scripts/enemies/boss_modular_glb.gd")
const BONE := Color(0.66, 0.68, 0.71)


static func decal_size(kind: String) -> float:
	match kind:
		"broodmother": return 7.6
		"grey_brood": return 8.0
		"dust_matriarch": return 8.2
		"king_beetle": return 9.0
		"iron_warden": return 9.2
		"abyss_queen": return 8.4
		"harbor_reaper": return 7.4
		"slag_colossus": return 9.4
		"dune_devourer": return 9.2
		"prism_archon": return 8.2
		"gorge_tyrant": return 9.0
		"abyss_harbinger": return 8.8
		"terminus_warden": return 8.0
		"foundry_dreadnought": return 9.4
		"silo_warhead": return 8.6
		"spillway_leviathan": return 8.8
		"excavator_titan": return 9.2
		"core_overlord": return 9.4
		"drydock_behemoth": return 9.2
		"citadel_behemoth": return 6.8
		"sky_carrier": return 4.4
		_: return 7.8


static func build(h, body: Node3D, kind: String, s: float) -> void:
	match kind:
		"broodmother": _brood(h, body, s)
		"grey_brood": _grey_brood(h, body, s)
		"dust_matriarch": _dust_matriarch(h, body, s)
		"king_beetle": _king(h, body, s)
		"iron_warden": _iron_warden(h, body, s)
		"abyss_queen": _queen(h, body, s)
		"harbor_reaper": Ext.build_harbor_reaper(h, body, s)
		"slag_colossus": Ext.build_slag_colossus(h, body, s)
		"dune_devourer": Ext.build_dune_devourer(h, body, s)
		"prism_archon": Ext.build_prism_archon(h, body, s)
		"gorge_tyrant": Ext.build_gorge_tyrant(h, body, s)
		"abyss_harbinger": Ext.build_abyss_harbinger(h, body, s)
		"terminus_warden": NewLM.build_terminus_warden(h, body, s)
		"foundry_dreadnought": NewLM.build_foundry_dreadnought(h, body, s)
		"silo_warhead": NewLM.build_silo_warhead(h, body, s)
		"spillway_leviathan": NewLM.build_spillway_leviathan(h, body, s)
		"excavator_titan": NewLM.build_excavator_titan(h, body, s)
		"core_overlord": NewLM.build_core_overlord(h, body, s)
		"drydock_behemoth": NewLM.build_drydock_behemoth(h, body, s)
		"citadel_behemoth": ModularGlb.build_citadel_behemoth(h, body, s)
		"sky_carrier": ModularGlb.build_sky_carrier(h, body, s)
		_: _brood(h, body, s)


# ---------------------------------------------------------------- 1. 赤湖移动化工炼制母舰 (broodmother)
static func _brood(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.42, 0.24, 0.22))
	var SH2: Material = h._vmat_solid(Color(0.34, 0.35, 0.37))
	var DK: Material = h._vmat_solid(Color(0.14, 0.15, 0.17))
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.035))
	var EGG := Color(0.95, 0.34, 0.16)
	var CRYS := Color(0.92, 0.48, 0.22)
	var by := 1.02 * s
	# 宽扁八角重装化工平台船体（取代有机圆蛋壳）
	h._loft(body, HS.crect(1.0, 1.0, 0.32), [
		[-0.55 * s, Vector2(1.45, 0.56) * s, Vector2.ZERO],
		[0.10 * s, Vector2(1.95, 0.72) * s, Vector2(0, 0.04 * s)],
		[0.85 * s, Vector2(1.82, 0.68) * s, Vector2(0, 0.04 * s)],
		[1.42 * s, Vector2(1.20, 0.46) * s, Vector2.ZERO],
	], DK, Vector3(0, by, 0))
	Models._shell_layer(h, body, Vector3(0, by + 0.34 * s, 0.32 * s), Vector3(1.68, 0.42, 1.78) * s, SH, -3.0)
	Models._shell_layer(h, body, Vector3(0, by + 0.44 * s, 0.78 * s), Vector3(1.22, 0.34, 1.05) * s, SH2, 5.0)
	h._panels(body, Vector3(0, by + 0.56 * s, 0.24 * s), Vector3(-90, 0, 0), 1.45 * s, 1.50 * s, 201, 7)
	# 前段楔形重甲首部 + 工程黄警示防撞梁
	h._prism(body, [Vector2(0.52, 0.34) * s, Vector2(0.68, -0.12) * s, Vector2(0.36, -0.62) * s, Vector2(-0.36, -0.62) * s, Vector2(-0.68, -0.12) * s, Vector2(-0.52, 0.34) * s],
		0.52 * s, 0.06, SH2, Vector3(0, by + 0.04 * s, -0.62 * s), Vector3(90, 0, 0))
	h._panels(body, Vector3(0, by + 0.32 * s, -0.62 * s), Vector3(-90, 0, 0), 0.96 * s, 0.86 * s, 202, 6)
	# 背部三座带钢箍的高压化工反应釜（sacs）+ 跨接黄铜输液管廊（移除原版 21 颗粉红脓泡球！）
	var sacs_pos := [Vector3(0, by + 0.72 * s, 0.30 * s), Vector3(0.74 * s, by + 0.54 * s, 0.82 * s), Vector3(-0.74 * s, by + 0.54 * s, 0.82 * s)]
	var radii := [0.40, 0.27, 0.27]
	for i in 3:
		var mi: MeshInstance3D = Models._sac(h, body, sacs_pos[i], radii[i] * s, EGG)
		h.sacs.append(mi)
	for sx: float in [-1.0, 1.0]:
		h._bar(body, sacs_pos[0] + Vector3(sx * 0.28 * s, 0.12 * s, 0.10 * s), sacs_pos[1 if sx > 0 else 2] + Vector3(0, 0.12 * s, 0), 0.065 * s, 0.065 * s, h._brass())
		var st_p := Vector3(sx * 0.62 * s, by + 0.58 * s, -0.10 * s)
		h._p(body, ART.cyl(0.075 * s, 0.52 * s, 0.09 * s, 10), DK, st_p + Vector3(0, 0.22 * s, 0), Vector3(14, 0, sx * -8.0))
		h._p(body, ART.cyl(0.095 * s, 0.28 * s, 0.095 * s, 10), h._rust_plate(), st_p + Vector3(0, 0.14 * s, 0), Vector3(14, 0, sx * -8.0))
		h._p(body, ART.cyl(0.06 * s, 0.025 * s, 0.06 * s, 10), BL, st_p + Vector3(-sx * 0.035 * s, 0.47 * s, 0.06 * s), Vector3(14, 0, sx * -8.0), Vector3.ONE, false)
	# 装甲指挥潜望塔（取代圆球虫头与发光球眼）
	var head := Node3D.new()
	head.position = Vector3(0, by + 0.22 * s, -1.02 * s)
	body.add_child(head)
	h._prism(head, [Vector2(-0.34, 0.22) * s, Vector2(0.34, 0.22) * s, Vector2(0.42, -0.16) * s, Vector2(-0.42, -0.16) * s], 0.38 * s, 0.06, DK, Vector3.ZERO)
	h._box(head, h._hazard_yel(), Vector3(0, 0.18 * s, -0.195 * s), Vector3(0.56, 0.05, 0.016) * s)
	for sx: float in [-1.0, 1.0]:
		Models._eye(h, head, Vector3(sx * 0.18 * s, 0.05 * s, -0.20 * s), 0.075 * s, EGG)
		var j := Node3D.new()
		j.position = Vector3(sx * 0.16 * s, -0.12 * s, -0.18 * s)
		head.add_child(j)
		h._jag(j, 0.15 * s, 0.42 * s, 0.06 * s, h._steel(), Vector3.ZERO, Vector3(-68, 0, sx * 18.0), 3, -1.0, 0.0)
		h.jaws.append(j)
	# 顶置五联通讯传感器天线排
	for k in 3:
		var ax := (k - 1) * 0.18
		h._p(head, ART.cyl(0.025 * s, 0.06 * s, 0.03 * s, 8), h._brass(), Vector3(ax * s, 0.24 * s, -0.02 * s))
		h._bar(head, Vector3(ax * s, 0.26 * s, -0.02 * s), Vector3(ax * 1.2 * s, 0.66 * s, 0.12 * s), 0.018 * s, 0.018 * s, h._steel())
	# 前置双液压起重破拆抓钩臂（scythes）
	for sx: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.62 * s, by + 0.12 * s, -0.84 * s)
		arm.rotation_degrees = Vector3(0, sx * 20.0, 0)
		body.add_child(arm)
		h._servo(arm, Vector3.ZERO, 0.18 * s)
		var el := Vector3(sx * 0.34, 0.18, -0.56) * s
		h._bar(arm, Vector3.ZERO, el, 0.20 * s, 0.23 * s, SH2)
		h._hydraulic(arm, Vector3(0, -0.14 * s, 0), el + Vector3(0, -0.12 * s, 0.06 * s), 0.045 * s, DK)
		h._servo(arm, el, 0.15 * s)
		h._jag(arm, 0.32 * s, 1.26 * s, 0.11 * s, h._chrome(), Vector3(sx * 0.38, 0.18, -0.62) * s, Vector3(-74, sx * 10.0, 0), 4, -1.0, sx * 0.12 * s)
		h.scythes.append(arm)
	# 八条重型铰接外扩蜘蛛支腿
	var hips := [[0.46, -0.60, -34.0], [0.54, -0.20, -12.0], [0.54, 0.24, 14.0], [0.44, 0.68, 34.0]]
	for i in 4:
		for sx: float in [-1.0, 1.0]:
			h._zleg(body, Vector3(sx * float(hips[i][0]) * s, by - 0.1 * s, float(hips[i][1]) * s), sx * float(hips[i][2]), sx,
				(1.32 - i * 0.06) * s, by * 1.02, (0.14 - i * 0.01) * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), i < 2)
	# 侧舷法兰矿物谐振簇（crystals）
	for sx: float in [-1.0, 1.0]:
		var edge := Node3D.new()
		edge.position = Vector3(sx * 0.96 * s, by + 0.18 * s, 0.22 * s)
		body.add_child(edge)
		for mi in Models._cluster(h, edge, Vector3.ZERO, 0.28 * s, CRYS, 5, 0.9):
			h.crystals.append(mi)


# ---------------------------------------------------------------- 2. 灰港两栖重工打捞巨蟹舰 (grey_brood)
static func _grey_brood(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.22, 0.33, 0.34))
	var SH2: Material = h._vmat_solid(Color(0.34, 0.44, 0.45))
	var DK: Material = h._vmat_solid(Color(0.11, 0.15, 0.16))
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.035))
	var ST: Material = h._steel()
	var ACID := Color(0.38, 0.90, 0.48)
	var CYAN := Color(0.28, 0.88, 0.78)
	var by := 0.98 * s
	# 1. 超宽六棱破浪装甲船体
	h._loft(body, HS.crect(1.0, 1.0, 0.35), [
		[-0.95 * s, Vector2(0.95, 0.28) * s, Vector2(0, -0.04 * s)],
		[-0.55 * s, Vector2(1.55, 0.46) * s, Vector2(0, 0.02 * s)],
		[0.05 * s, Vector2(1.82, 0.56) * s, Vector2(0, 0.06 * s)],
		[0.65 * s, Vector2(1.58, 0.48) * s, Vector2(0, 0.03 * s)],
		[1.12 * s, Vector2(0.98, 0.30) * s, Vector2(0, -0.04 * s)],
	], DK, Vector3(0, by, 0.1 * s))
	h._shell(body, SH, Vector3(0, by + 0.06 * s, 0.1 * s), 0.56 * s, 0.055 * s, -0.82 * s, 0.98 * s,
		[[0.0, 1.15, 0.72, 0.38 * s], [0.35, 1.62, 1.0, 0.52 * s], [0.7, 1.54, 0.95, 0.5 * s], [1.0, 0.95, 0.68, 0.34 * s]], Vector3.ZERO, 76.0, 10)
	h._panels(body, Vector3(0, by + 0.58 * s, 0.08 * s), Vector3(-90, 0, 0), 1.65 * s, 1.45 * s, 301, 7)
	# 船舷防撞轮胎护舷与排水百叶格栅
	for sx: float in [-1.0, 1.0]:
		h._prism(body, [Vector2(0.0, 0.18) * s, Vector2(0.46 * s, 0.04 * s), Vector2(0.38 * s, -0.22 * s), Vector2(-0.08 * s, -0.14 * s)],
			1.28 * s, 0.06, SH2, Vector3(sx * 0.92 * s, by + 0.12 * s, 0.12 * s), Vector3(0, 0, sx * -12.0 if sx > 0 else 192.0))
		for k in 3:
			var zk := (-0.36 + k * 0.42) * s
			h._box(body, BL, Vector3(sx * 1.18 * s, by + 0.12 * s, zk), Vector3(0.03, 0.09, 0.24) * s)
			h._box(body, h._hazard_yel(), Vector3(sx * 1.17 * s, by + 0.20 * s, zk), Vector3(0.025, 0.035, 0.22) * s)
	# 2. 背部双开重型液压舱口盖（plates）+ 钢笼防护反应釜核（core_mi）
	var core: MeshInstance3D = h._p(body, ART.cyl(0.24 * s, 0.36 * s, 0.24 * s, 12), ART.emit(ACID, 1.15), Vector3(0, by + 0.52 * s, 0.08 * s))
	h.core_mi = core
	h._p(body, ART.cyl(0.27 * s, 0.05 * s, 0.27 * s, 12), h._brass(), Vector3(0, by + 0.70 * s, 0.08 * s))
	for sx: float in [-1.0, 1.0]:
		var pl := Node3D.new()
		pl.position = Vector3(sx * 0.38 * s, by + 0.56 * s, 0.08 * s)
		pl.set_meta("side", sx)
		body.add_child(pl)
		h._prism(pl, [Vector2(0.34, 0.42) * s, Vector2(0.38, -0.42) * s, Vector2(-0.28, -0.46) * s, Vector2(-0.3, 0.38) * s],
			0.12 * s, 0.08, SH2, Vector3(sx * 0.24 * s, 0, 0), Vector3(-84, 0, sx * 16.0))
		h._box(pl, h._hazard_yel(), Vector3(sx * 0.44 * s, 0.06 * s, 0), Vector3(0.08, 0.04, 0.64) * s)
		h.plates.append(pl)
	# 3. 六座海事洗涤排烟囱（黄铜法兰箍 + 防烫锈套 + 深黑烟口，移除顶部绿光圈！）+ 四座高压储液罐（sacs）
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			var ch := Node3D.new()
			ch.position = Vector3(sx * (0.58 + i * 0.14) * s, by + 0.44 * s, (-0.28 + i * 0.42) * s)
			ch.rotation_degrees = Vector3(-12.0 + i * 10.0, 0, sx * -20.0)
			body.add_child(ch)
			var h_c := (0.54 - i * 0.06) * s
			h._p(ch, ART.cyl(0.10 * s, h_c, 0.14 * s, 10), DK, Vector3(0, h_c * 0.5, 0))
			h._p(ch, ART.cyl(0.13 * s, h_c * 0.55, 0.15 * s, 10), h._rust_plate(), Vector3(0, h_c * 0.32, 0))
			h._p(ch, ART.cyl(0.12 * s, 0.035 * s, 0.12 * s, 10), h._brass(), Vector3(0, h_c * 0.88, 0))
			h._p(ch, ART.cyl(0.082 * s, 0.02 * s, 0.082 * s, 10), BL, Vector3(0, h_c + 0.005 * s, 0), Vector3.ZERO, Vector3.ONE, false)
	var sac_offsets := [
		Vector3(0.82 * s, by + 0.32 * s, 0.62 * s), Vector3(-0.82 * s, by + 0.32 * s, 0.62 * s),
		Vector3(0.46 * s, by + 0.36 * s, 0.96 * s), Vector3(-0.46 * s, by + 0.36 * s, 0.96 * s),
	]
	for sp in sac_offsets:
		h.sacs.append(Models._sac(h, body, sp, 0.26 * s, ACID))
	for sx: float in [-1.0, 1.0]:
		var cl := Node3D.new()
		cl.position = Vector3(sx * 1.05 * s, by + 0.24 * s, -0.18 * s)
		body.add_child(cl)
		for mi in Models._cluster(h, cl, Vector3.ZERO, 0.26 * s, CYAN, 5, 0.9):
			h.crystals.append(mi)
	# 4. 宽幅舰桥横梁 + 潜望测距塔 + 切割剪颚（jaws）
	var head := Node3D.new()
	head.position = Vector3(0, by + 0.16 * s, -0.96 * s)
	body.add_child(head)
	h._prism(head, [Vector2(-0.56, 0.18) * s, Vector2(0.56, 0.18) * s, Vector2(0.68, -0.14) * s, Vector2(-0.68, -0.14) * s],
		0.36 * s, 0.06, SH2, Vector3.ZERO)
	for sx: float in [-1.0, 1.0]:
		h._bar(head, Vector3(sx * 0.32 * s, 0.1 * s, -0.08 * s), Vector3(sx * 0.48 * s, 0.36 * s, -0.22 * s), 0.075 * s, 0.075 * s, DK)
		Models._eye(h, head, Vector3(sx * 0.48 * s, 0.38 * s, -0.26 * s), 0.10 * s, CYAN)
		var j := Node3D.new()
		j.position = Vector3(sx * 0.22 * s, -0.1 * s, -0.18 * s)
		head.add_child(j)
		h._jag(j, 0.18 * s, 0.48 * s, 0.06 * s, ST, Vector3.ZERO, Vector3(-70, 0, sx * 22.0), 3, -1.0, sx * 0.06 * s)
		h.jaws.append(j)
	# 5. 双臂重型港湾液压打捞巨螯（scythes）
	for sx: float in [-1.0, 1.0]:
		var claw := Node3D.new()
		claw.position = Vector3(sx * 0.78 * s, by + 0.06 * s, -0.78 * s)
		claw.rotation_degrees = Vector3(0, sx * 16.0, 0)
		body.add_child(claw)
		h._servo(claw, Vector3.ZERO, 0.20 * s)
		var el := Vector3(sx * 0.42, 0.08, -0.52) * s
		h._limb(claw, Vector3.ZERO, el, 0.24 * s, 0.28 * s, DK, 0.75, 1.2)
		Bugs2._armor_along(h, claw, Vector3.ZERO, el, 0.22 * s, SH2)
		h._hydraulic(claw, Vector3(0, -0.16 * s, 0), el + Vector3(0, -0.14 * s, 0.06 * s), 0.05 * s, DK)
		h._servo(claw, el, 0.18 * s)
		var palm := el + Vector3(sx * 0.08, -0.04, -0.38) * s
		h._limb(claw, el, palm, 0.34 * s, 0.28 * s, SH, 0.8, 1.25)
		h._hydraulic(claw, el + Vector3(0, 0.16 * s, 0), palm + Vector3(0, 0.14 * s, 0.04 * s), 0.048 * s, DK)
		h._box(claw, h._hazard_yel(), palm + Vector3(0, 0.16 * s, 0.08 * s), Vector3(0.22, 0.04, 0.24) * s)
		h._jag(claw, 0.32 * s, 1.05 * s, 0.12 * s, h._chrome(), palm + Vector3(sx * 0.08 * s, 0.06 * s, -0.06 * s), Vector3(-82, sx * 14.0, 0), 4, -1.0, -sx * 0.14 * s)
		h._jag(claw, 0.24 * s, 0.86 * s, 0.09 * s, ST, palm + Vector3(-sx * 0.08 * s, -0.08 * s, -0.06 * s), Vector3(-76, -sx * 8.0, 180.0), 3, -1.0, sx * 0.1 * s)
		h.scythes.append(claw)
	# 6. 八条横展港机支腿
	var hips := [[0.62, -0.52, -32.0], [0.72, -0.12, -10.0], [0.72, 0.30, 14.0], [0.58, 0.72, 36.0]]
	for i in 4:
		for sx: float in [-1.0, 1.0]:
			h._zleg(body, Vector3(sx * float(hips[i][0]) * s, by - 0.08 * s, float(hips[i][1]) * s), sx * float(hips[i][2]), sx,
				(1.38 - i * 0.06) * s, by * 1.0, (0.15 - i * 0.01) * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), i < 2)


# ---------------------------------------------------------------- 3. 荒原重装钻探巨蝎母舰 (dust_matriarch)
static func _dust_matriarch(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.50, 0.39, 0.24))
	var SH2: Material = h._vmat_solid(Color(0.60, 0.48, 0.30))
	var DK: Material = h._vmat_solid(Color(0.16, 0.15, 0.14))
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.035))
	var AMBER := Color(1.0, 0.48, 0.12)
	var GOLD := Color(0.95, 0.72, 0.22)
	var by := 1.0 * s
	# 1. 分节防沙装甲车体
	h._loft(body, HS.crect(1.0, 1.0, 0.38), [
		[-0.98 * s, Vector2(0.72, 0.30) * s, Vector2(0, -0.02 * s)],
		[-0.45 * s, Vector2(1.18, 0.44) * s, Vector2(0, 0.04 * s)],
		[0.18 * s, Vector2(1.36, 0.50) * s, Vector2(0, 0.06 * s)],
		[0.78 * s, Vector2(1.12, 0.42) * s, Vector2(0, 0.04 * s)],
		[1.22 * s, Vector2(0.66, 0.28) * s, Vector2(0, 0.02 * s)],
	], DK, Vector3(0, by, 0.08 * s))
	for k in 4:
		var z0 := (-0.78 + k * 0.44) * s
		var wf := 1.0 + (0.18 if k == 1 or k == 2 else -0.06)
		h._shell(body, SH2 if k % 2 == 0 else SH, Vector3(0, by + 0.08 * s, 0), 0.46 * s * wf, 0.048 * s, z0, z0 + 0.40 * s,
			[[0.0, 0.92, 0.82, 0.38 * s], [0.5, 1.18, 1.0, 0.46 * s], [1.0, 0.96, 0.86, 0.38 * s]], Vector3.ZERO, 72.0, 8)
	h._panels(body, Vector3(0, by + 0.54 * s, 0.06 * s), Vector3(-90, 0, 0), 1.15 * s, 1.45 * s, 305, 7)
	# 背部双开百叶散热门（plates）+ 涡轮炉芯（core_mi）
	var core: MeshInstance3D = h._p(body, ART.cyl(0.22 * s, 0.32 * s, 0.22 * s, 12), ART.emit(AMBER, 1.25), Vector3(0, by + 0.50 * s, -0.04 * s))
	h.core_mi = core
	for sx: float in [-1.0, 1.0]:
		var pl := Node3D.new()
		pl.position = Vector3(sx * 0.32 * s, by + 0.54 * s, -0.04 * s)
		pl.set_meta("side", sx)
		body.add_child(pl)
		h._prism(pl, [Vector2(0.28, 0.38) * s, Vector2(0.32, -0.38) * s, Vector2(-0.24, -0.42) * s, Vector2(-0.26, 0.34) * s],
			0.1 * s, 0.08, SH2, Vector3(sx * 0.2 * s, 0, 0), Vector3(-82, 0, sx * 18.0))
		h.plates.append(pl)
	# 2. 五座高压储油钢罐（sacs）与晶簇（crystals）
	var sac_pts := [
		Vector3(0, by + 0.56 * s, 0.46 * s),
		Vector3(0.76 * s, by + 0.34 * s, 0.18 * s), Vector3(-0.76 * s, by + 0.34 * s, 0.18 * s),
		Vector3(0.68 * s, by + 0.32 * s, 0.72 * s), Vector3(-0.68 * s, by + 0.32 * s, 0.72 * s),
	]
	for i in sac_pts.size():
		var r_s := (0.32 if i == 0 else 0.24) * s
		h.sacs.append(Models._sac(h, body, sac_pts[i], r_s, AMBER))
	for sx: float in [-1.0, 1.0]:
		var cl := Node3D.new()
		cl.position = Vector3(sx * 0.86 * s, by + 0.24 * s, -0.26 * s)
		body.add_child(cl)
		for mi in Models._cluster(h, cl, Vector3.ZERO, 0.25 * s, GOLD, 5, 0.9):
			h.crystals.append(mi)
	# 3. 过顶五节重型液压工程曲臂尾炮（abdomen：段间配液压油缸，末端装甲炮箱 + 钨钢冲击矛 + 双联深黑膛口臼炮，移除发光圆球与光圈！）
	var tail := Node3D.new()
	tail.position = Vector3(0, by + 0.18 * s, 1.02 * s)
	body.add_child(tail)
	var t_pts := [
		Vector3(0, 0, 0),
		Vector3(0, 0.55 * s, 0.48 * s),
		Vector3(0, 1.28 * s, 0.58 * s),
		Vector3(0, 1.92 * s, 0.18 * s),
		Vector3(0, 2.18 * s, -0.48 * s),
		Vector3(0, 2.04 * s, -1.06 * s),
	]
	for i in 5:
		var p0: Vector3 = t_pts[i]
		var p1: Vector3 = t_pts[i + 1]
		var bw := (0.34 - i * 0.03) * s
		h._bar(tail, p0, p1, bw, bw * 1.05, DK)
		Bugs2._armor_along(h, tail, p0, p1, (0.28 - i * 0.025) * s, SH2 if i % 2 == 0 else SH)
		if i < 4:
			h._hydraulic(tail, p0.lerp(p1, 0.25) + Vector3(0, -0.14 * s, -0.10 * s), t_pts[i + 1].lerp(t_pts[i + 2], 0.35) + Vector3(0, -0.12 * s, -0.08 * s), 0.042 * s, SH)
		h._servo(tail, p1, (0.18 - i * 0.015) * s)
	var tip: Vector3 = t_pts[5]
	h._p(tail, HS.cbox(Vector3(0.56, 0.44, 0.62) * s, 0.04 * s), DK, tip + Vector3(0, 0.04 * s, 0.04 * s))
	h._box(tail, h._hazard_yel(), tip + Vector3(0, 0.27 * s, 0.04 * s), Vector3(0.48, 0.03, 0.46) * s)
	h._p(tail, ART.cyl(0.0, 0.86 * s, 0.12 * s, 8), h._chrome(), tip + Vector3(0, -0.12 * s, -0.52 * s), Vector3(-108, 0, 0))
	for sx: float in [-1.0, 1.0]:
		var mp := tip + Vector3(sx * 0.26 * s, 0.10 * s, -0.14 * s)
		h._p(tail, ART.cyl(0.11 * s, 0.48 * s, 0.13 * s, 12), h._steel(), mp, Vector3(72, sx * 6.0, 0))
		h._p(tail, ART.cyl(0.125 * s, 0.08 * s, 0.125 * s, 12), DK, mp + Vector3(sx * 0.02 * s, -0.06 * s, -0.20 * s), Vector3(72, sx * 6.0, 0))
		h._p(tail, ART.cyl(0.085 * s, 0.025 * s, 0.085 * s, 12), BL, mp + Vector3(sx * 0.025 * s, -0.075 * s, -0.245 * s), Vector3(72, sx * 6.0, 0), Vector3.ONE, false)
	h.abdomen = tail
	# 4. 破沙推土头座 + 装甲观瞄窗 + 碎石颚（jaws）
	var head := Node3D.new()
	head.position = Vector3(0, by + 0.18 * s, -0.98 * s)
	body.add_child(head)
	h._prism(head, [Vector2(-0.42, 0.20) * s, Vector2(0.42, 0.20) * s, Vector2(0.52, -0.14) * s, Vector2(0, -0.28) * s, Vector2(-0.52, -0.14) * s],
		0.38 * s, 0.06, SH, Vector3.ZERO)
	for sx: float in [-1.0, 1.0]:
		Models._eye(h, head, Vector3(sx * 0.20 * s, 0.08 * s, -0.19 * s), 0.082 * s, AMBER)
		var j := Node3D.new()
		j.position = Vector3(sx * 0.16 * s, -0.12 * s, -0.18 * s)
		head.add_child(j)
		h._jag(j, 0.16 * s, 0.46 * s, 0.06 * s, h._steel(), Vector3.ZERO, Vector3(-68, 0, sx * 20.0), 3, -1.0, 0.0)
		h.jaws.append(j)
	# 5. 双柄液压夹钳臂（scythes）
	for sx: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.56 * s, by + 0.08 * s, -0.82 * s)
		arm.rotation_degrees = Vector3(0, sx * 18.0, 0)
		body.add_child(arm)
		h._servo(arm, Vector3.ZERO, 0.17 * s)
		var el := Vector3(sx * 0.36, 0.12, -0.58) * s
		h._limb(arm, Vector3.ZERO, el, 0.20 * s, 0.22 * s, SH, 0.75, 1.2)
		Bugs2._armor_along(h, arm, Vector3.ZERO, el, 0.18 * s, SH2)
		h._hydraulic(arm, Vector3(0, -0.14 * s, 0), el + Vector3(0, -0.12 * s, 0.04 * s), 0.044 * s, DK)
		h._servo(arm, el, 0.15 * s)
		h._jag(arm, 0.32 * s, 1.26 * s, 0.10 * s, h._chrome(), el + Vector3(sx * 0.06 * s, 0.04 * s, -0.08 * s), Vector3(-78, sx * 12.0, 0), 5, -1.0, -sx * 0.14 * s)
		h._jag(arm, 0.20 * s, 0.82 * s, 0.08 * s, h._steel(), el + Vector3(-sx * 0.06 * s, -0.06 * s, -0.08 * s), Vector3(-72, -sx * 10.0, 180.0), 3, -1.0, sx * 0.08 * s)
		h.scythes.append(arm)
	# 6. 八条荒原防陷支腿
	var hips := [[0.48, -0.58, -34.0], [0.56, -0.18, -12.0], [0.56, 0.26, 14.0], [0.46, 0.68, 36.0]]
	for i in 4:
		for sx: float in [-1.0, 1.0]:
			h._zleg(body, Vector3(sx * float(hips[i][0]) * s, by - 0.08 * s, float(hips[i][1]) * s), sx * float(hips[i][2]), sx,
				(1.36 - i * 0.06) * s, by * 1.02, (0.14 - i * 0.01) * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), i < 2)


# ---------------------------------------------------------------- 4. 裂谷双柱打桩重甲堡垒 (king_beetle)
static func _king(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.32, 0.31, 0.28))
	var SH2: Material = h._vmat_solid(Color(0.44, 0.42, 0.38))
	var DK: Material = h._vmat_solid(Color(0.13, 0.14, 0.16))
	var PL: Material = h._vmat_matte(Color(0.50, 0.49, 0.46))
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.035))
	var CORE := Color(1.0, 0.46, 0.12)
	var by := 1.1 * s
	# 躯干：低宽六棱铆接铸铁底盘 + 上层叠甲
	h._prism(body, [Vector2(-0.72, -0.78) * s, Vector2(0.72, -0.78) * s, Vector2(0.90, 0.0) * s, Vector2(0.74, 0.88) * s, Vector2(-0.74, 0.88) * s, Vector2(-0.90, 0.0) * s],
		0.56 * s, 0.06, DK, Vector3(0, by, 0), Vector3(90, 0, 0))
	h._prism(body, [Vector2(-0.56, -0.60) * s, Vector2(0.56, -0.60) * s, Vector2(0.70, 0.02) * s, Vector2(0.58, 0.72) * s, Vector2(-0.58, 0.72) * s, Vector2(-0.70, 0.02) * s],
		0.24 * s, 0.08, SH, Vector3(0, by + 0.34 * s, 0), Vector3(90, 0, 0))
	h._panels(body, Vector3(0, by + 0.50 * s, -0.06 * s), Vector3(-90, 0, 0), 1.1 * s, 1.0 * s, 211, 8)
	# 背甲：双开重型液压防爆仓盖（plates）+ 钢制法兰保护反应堆芯（core_mi，移除悬浮光圈！）
	for sx: float in [-1.0, 1.0]:
		var pl := Node3D.new()
		pl.position = Vector3(sx * 0.34 * s, by + 0.56 * s, 0.24 * s)
		pl.set_meta("side", sx)
		body.add_child(pl)
		h._prism(pl, [Vector2(0.30, 0.26) * s, Vector2(0.34, -0.32) * s, Vector2(-0.30, -0.36) * s, Vector2(-0.32, 0.22) * s],
			0.14 * s, 0.1, SH2, Vector3(sx * 0.34 * s, 0, 0), Vector3(-22, 0, sx * 22.0))
		h._box(pl, h._hazard_yel(), Vector3(sx * 0.54 * s, 0.04 * s, 0), Vector3(0.08, 0.04, 0.48) * s)
		h._box(pl, h._steel(), Vector3(sx * 0.32 * s, 0.08 * s, -0.03 * s), Vector3(0.06, 0.08, 0.08) * s)
		h.plates.append(pl)
	var core: MeshInstance3D = h._p(body, ART.cyl(0.24 * s, 0.34 * s, 0.24 * s, 14), ART.emit(CORE, 1.2), Vector3(0, by + 0.54 * s, 0.24 * s))
	h.core_mi = core
	h._p(body, ART.cyl(0.28 * s, 0.05 * s, 0.28 * s, 14), h._brass(), Vector3(0, by + 0.72 * s, 0.24 * s))
	for ci in 4:
		var ca := TAU * ci / 4.0 + PI * 0.25
		h._box(body, h._steel(), Vector3(cos(ca) * 0.27 * s, by + 0.54 * s, 0.24 * s + sin(ca) * 0.27 * s), Vector3(0.04, 0.36, 0.04) * s)
	# 攻城破障首楼（彻底移除原版脸上三颗刺眼橙色大光球！改用铆接破城撞梁 + 双侧破岩齿 + 防弹眉檐指挥窄缝）
	var head := Node3D.new()
	head.position = Vector3(0, by + 0.24 * s, -0.90 * s)
	body.add_child(head)
	h._prism(head, [Vector2(0.52, 0.28) * s, Vector2(0.44, -0.26) * s, Vector2(0, -0.38) * s, Vector2(-0.44, -0.26) * s, Vector2(-0.52, 0.28) * s],
		0.34 * s, 0.08, DK, Vector3.ZERO)
	h._prism(head, [Vector2(0.40, 0.34) * s, Vector2(0.34, -0.08) * s, Vector2(-0.34, -0.08) * s, Vector2(-0.40, 0.34) * s],
		0.36 * s, 0.1, SH2, Vector3(0, 0.06 * s, -0.04 * s))
	# 防弹钢制遮光眉檐 + 三联内凹光学窄缝
	h._box(head, h._steel(), Vector3(0, 0.26 * s, -0.22 * s), Vector3(0.68, 0.04, 0.14) * s, Vector3(12, 0, 0))
	h._box(head, BL, Vector3(0, 0.18 * s, -0.225 * s), Vector3(0.58, 0.075, 0.03) * s)
	for vx: float in [-0.18, 0.0, 0.18]:
		h._box(head, ART.emit(CORE, 1.5), Vector3(vx * s, 0.18 * s, -0.238 * s), Vector3(0.12, 0.026, 0.01) * s)
	# 中央工字钢桁架破城撞角 + 两侧副破障齿
	h._jag(head, 0.28 * s, 1.04 * s, 0.15 * s, h._chrome(), Vector3(0, -0.02 * s, -0.24 * s), Vector3(-104, 0, 0), 4, -1.0, 0.0)
	h._box(head, h._hazard_yel(), Vector3(0, -0.10 * s, -0.28 * s), Vector3(0.34, 0.06, 0.14) * s)
	for sx: float in [-1.0, 1.0]:
		h._jag(head, 0.20 * s, 0.76 * s, 0.11 * s, h._steel(), Vector3(sx * 0.34 * s, -0.02 * s, -0.18 * s), Vector3(-96, sx * -26.0, 0), 3, -1.0, sx * 0.06 * s)
	# 肩部铆接防撞耳台 + 尾部双排烟筒
	for sx: float in [-1.0, 1.0]:
		h._p(body, HS.cbox(Vector3(0.28, 0.28, 0.48) * s, 0.04 * s), SH2, Vector3(sx * 0.76 * s, by + 0.30 * s, -0.34 * s), Vector3(0, sx * -16.0, 0))
		h._box(body, h._hazard_yel(), Vector3(sx * 0.84 * s, by + 0.12 * s, 0.20 * s), Vector3(0.02, 0.07, 0.54) * s)
		h._box(body, PL, Vector3(sx * 0.76 * s, by + 0.26 * s, 0.44 * s), Vector3(0.05, 0.32, 0.50) * s, Vector3(0, 0, sx * 6.0))
		var ep := Vector3(sx * 0.46 * s, by + 0.52 * s, 0.74 * s)
		h._p(body, ART.cyl(0.075 * s, 0.48 * s, 0.09 * s, 10), DK, ep + Vector3(0, 0.20 * s, 0.05 * s), Vector3(16, 0, 0))
		h._p(body, ART.cyl(0.095 * s, 0.26 * s, 0.095 * s, 10), h._rust_plate(), ep + Vector3(0, 0.12 * s, 0.03 * s), Vector3(16, 0, 0))
		h._p(body, ART.cyl(0.06 * s, 0.025 * s, 0.06 * s, 10), BL, ep + Vector3(0, 0.435 * s, 0.115 * s), Vector3(16, 0, 0), Vector3.ONE, false)
	# 前置双柱液压打桩机巨足（双镀铬液压缸 + 重型六角打桩锤底靴，移除脚底悬浮光圈！）
	for sx: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(sx * 0.62 * s, by - 0.18 * s, -0.50 * s)
		hip.rotation_degrees = Vector3(0, sx * -12.0, 0)
		body.add_child(hip)
		h._servo(hip, Vector3.ZERO, 0.28 * s)
		var knee := Vector3(sx * 0.32 * s, 0.32 * s, 0)
		var foot := Vector3(sx * 0.48 * s, -by + 0.02, -0.08 * s)
		h._bar(hip, Vector3.ZERO, knee, 0.38 * s, 0.44 * s, SH2)
		h._bar(hip, Vector3(0, 0.22 * s, 0), knee + Vector3(0, 0.22 * s, 0), 0.48 * s, 0.10 * s, PL)
		h._hydraulic(hip, Vector3(0, -0.22 * s, 0), knee + Vector3(-sx * 0.06 * s, -0.16 * s, 0), 0.075 * s, DK)
		h._servo(hip, knee, 0.24 * s)
		h._bar(hip, knee, foot + Vector3(0, 0.36 * s, 0), 0.38 * s, 0.40 * s, DK)
		# 打桩锤下段镀铬巨型冲击柱 + 黄黑警示箍 + 防滑驻锄钢靴
		h._p(hip, ART.cyl(0.18 * s, 0.42 * s, 0.18 * s, 12), h._chrome(), foot + Vector3(0, 0.28 * s, 0))
		h._p(hip, ART.cyl(0.22 * s, 0.08 * s, 0.22 * s, 12), h._brass(), foot + Vector3(0, 0.44 * s, 0))
		h._box(hip, h._hazard_yel(), knee.lerp(foot, 0.42) + Vector3(sx * 0.195 * s, 0, 0), Vector3(0.018, 0.28, 0.24) * s)
		h._p(hip, ART.cyl(0.36 * s, 0.18 * s, 0.46 * s, 8), DK, foot + Vector3(0, 0.09 * s, 0))
		for cz: float in [-0.26, 0.0, 0.26]:
			h._box(hip, h._steel(), foot + Vector3(0, 0.025 * s, cz * s), Vector3(0.72, 0.05, 0.10) * s)
		hip.set_meta("side", sx)
		hip.set_meta("phase", 0.0 if sx > 0 else PI)
		hip.set_meta("base_y", hip.rotation.y)
		h.legs.append(hip)
	# 后四条重型液压活塞腿
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			h._pleg(body, Vector3(sx * 0.68 * s, by - 0.14 * s, (0.2 + i * 0.46) * s), sx * (18.0 + i * 14.0), sx, s * 0.92, by - 0.12 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0))


# ---------------------------------------------------------------- 5. 铁带高炉重装推土巨卫 (iron_warden)
static func _iron_warden(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.40, 0.26, 0.20))
	var SH2: Material = h._vmat_solid(Color(0.48, 0.35, 0.28))
	var DK: Material = h._vmat_solid(Color(0.13, 0.14, 0.16))
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.035))
	var ST: Material = h._steel()
	var CORE := Color(0.28, 0.84, 1.0)
	var HEAT := Color(1.0, 0.46, 0.14)
	var by := 1.08 * s
	# 1. 八棱工业装甲主车体 + 阶梯式顶甲
	h._loft(body, HS.crect(1.0, 1.0, 0.28), [
		[-0.92 * s, Vector2(1.18, 0.46) * s, Vector2.ZERO],
		[-0.42 * s, Vector2(1.48, 0.56) * s, Vector2(0, 0.04 * s)],
		[0.32 * s, Vector2(1.52, 0.58) * s, Vector2(0, 0.04 * s)],
		[0.96 * s, Vector2(1.24, 0.48) * s, Vector2.ZERO],
	], DK, Vector3(0, by, 0.06 * s))
	h._p(body, HS.cbox(Vector3(1.28, 0.32, 1.46) * s, 0.06 * s), SH, Vector3(0, by + 0.34 * s, 0.08 * s))
	h._panels(body, Vector3(0, by + 0.51 * s, 0.08 * s), Vector3(-90, 0, 0), 1.16 * s, 1.32 * s, 312, 8)
	# 两侧反应装甲块与深黑百叶排热窗
	for sx: float in [-1.0, 1.0]:
		for k in 3:
			var zk := (-0.42 + k * 0.48) * s
			h._p(body, HS.cbox(Vector3(0.14, 0.36, 0.38) * s, 0.025 * s), SH2, Vector3(sx * 0.78 * s, by + 0.08 * s, zk))
			h._box(body, BL, Vector3(sx * 0.855 * s, by + 0.08 * s, zk), Vector3(0.02, 0.18, 0.28) * s)
			h._box(body, ART.emit(HEAT, 1.35), Vector3(sx * 0.862 * s, by + 0.08 * s, zk), Vector3(0.008, 0.045, 0.22) * s)
	# 2. 背部双开防爆装甲门（plates）与钢环涡轮电弧堆芯（core_mi + spinners）
	var core: MeshInstance3D = h._p(body, ART.cyl(0.25 * s, 0.32 * s, 0.25 * s, 14), ART.emit(CORE, 1.25), Vector3(0, by + 0.56 * s, 0.06 * s))
	h.core_mi = core
	var rotor := Node3D.new()
	rotor.position = Vector3(0, by + 0.56 * s, 0.06 * s)
	body.add_child(rotor)
	h._p(rotor, ART.torus(0.38 * s, 0.44 * s, 18), ST, Vector3.ZERO, Vector3(90, 0, 0), Vector3(1, 1, 0.45), false)
	for k in 4:
		var a := TAU * k / 4.0
		h._box(rotor, h._brass(), Vector3(cos(a) * 0.41 * s, 0, sin(a) * 0.41 * s), Vector3(0.09, 0.14, 0.09) * s, Vector3(0, -rad_to_deg(a), 0))
	h.spinners.append([rotor, Vector3.UP, 1.6, 8.5])
	for sx: float in [-1.0, 1.0]:
		var pl := Node3D.new()
		pl.position = Vector3(sx * 0.38 * s, by + 0.58 * s, 0.06 * s)
		pl.set_meta("side", sx)
		body.add_child(pl)
		h._p(pl, HS.cbox(Vector3(0.46, 0.12, 0.72) * s, 0.03 * s), SH2, Vector3(sx * 0.22 * s, 0, 0), Vector3(0, 0, sx * -16.0))
		h._box(pl, h._hazard_yel(), Vector3(sx * 0.40 * s, 0.065 * s, 0), Vector3(0.08, 0.02, 0.62) * s, Vector3(0, 0, sx * -16.0))
		h.plates.append(pl)
	# 3. 后部四座高炉排烟塔（防烫护网 + 黄铜箍 + 深黑烟膛，移除顶部橙光圈！）
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			var st_pos := Vector3(sx * (0.42 + i * 0.22) * s, by + 0.46 * s, (0.52 + i * 0.28) * s)
			var h_st := (0.70 - i * 0.12) * s
			var st_n := Node3D.new()
			st_n.position = st_pos
			st_n.rotation_degrees = Vector3(-14, 0, sx * -8.0)
			body.add_child(st_n)
			h._p(st_n, ART.cyl(0.11 * s, h_st, 0.15 * s, 12), DK, Vector3(0, h_st * 0.5, 0))
			h._p(st_n, ART.cyl(0.145 * s, h_st * 0.55, 0.165 * s, 12), h._rust_plate(), Vector3(0, h_st * 0.32, 0))
			h._p(st_n, ART.cyl(0.13 * s, 0.04 * s, 0.13 * s, 12), h._brass(), Vector3(0, h_st * 0.86, 0))
			h._p(st_n, ART.cyl(0.088 * s, 0.025 * s, 0.088 * s, 12), BL, Vector3(0, h_st + 0.005 * s, 0), Vector3.ZERO, Vector3.ONE, false)
	# 4. 前端 V 型重装破障推土铲（带双级液压油缸与黄黑工程警示条）+ 双联碎石颚（jaws）
	var prow := Node3D.new()
	prow.position = Vector3(0, by - 0.10 * s, -0.96 * s)
	body.add_child(prow)
	for sx: float in [-1.0, 1.0]:
		var blade := Node3D.new()
		blade.position = Vector3(sx * 0.44 * s, 0.0, -0.14 * s)
		blade.rotation_degrees = Vector3(12, sx * -22.0, 0)
		prow.add_child(blade)
		h._p(blade, HS.cbox(Vector3(0.92, 0.64, 0.14) * s, 0.03 * s), SH2, Vector3.ZERO)
		h._p(blade, HS.cbox(Vector3(0.88, 0.14, 0.16) * s, 0.02 * s), ST, Vector3(0, -0.26 * s, -0.02 * s))
		for hk in 4:
			h._box(blade, h._hazard_yel() if hk % 2 == 0 else BL, Vector3((-0.30 + hk * 0.20) * s, 0.18 * s, -0.075 * s), Vector3(0.16, 0.10, 0.018) * s)
		h._hydraulic(prow, Vector3(sx * 0.44 * s, 0.22 * s, 0.26 * s), Vector3(sx * 0.48 * s, 0.02 * s, -0.10 * s), 0.068 * s, DK)
		var j := Node3D.new()
		j.position = Vector3(sx * 0.24 * s, -0.06 * s, -0.28 * s)
		prow.add_child(j)
		h._jag(j, 0.22 * s, 0.56 * s, 0.08 * s, h._chrome(), Vector3.ZERO, Vector3(-84, 0, sx * 16.0), 3, -1.0, 0.0)
		h.jaws.append(j)
	# 装甲观测舰桥（防弹遮檐 + 内凹光学窗）
	var head := Node3D.new()
	head.position = Vector3(0, by + 0.42 * s, -0.78 * s)
	body.add_child(head)
	h._p(head, HS.cbox(Vector3(0.74, 0.34, 0.48) * s, 0.04 * s), DK, Vector3.ZERO)
	h._box(head, ST, Vector3(0, 0.14 * s, -0.26 * s), Vector3(0.68, 0.035, 0.10) * s, Vector3(12, 0, 0))
	h._box(head, BL, Vector3(0, 0.04 * s, -0.245 * s), Vector3(0.56, 0.08, 0.02) * s)
	h._box(head, ART.emit(CORE, 1.55), Vector3(0, 0.04 * s, -0.255 * s), Vector3(0.46, 0.03, 0.01) * s)
	# 5. 双肩旋转圆盘破拆锯臂（scythes + spinners：加装工程黄半圆护罩 + 液压驱动臂，移除锯盘外发光光环！）
	for sx: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.78 * s, by + 0.34 * s, -0.52 * s)
		arm.rotation_degrees = Vector3(0, sx * 12.0, 0)
		body.add_child(arm)
		h._servo(arm, Vector3.ZERO, 0.20 * s)
		var wrist := Vector3(sx * 0.28, -0.12, -0.68) * s
		h._limb(arm, Vector3.ZERO, wrist, 0.22 * s, 0.24 * s, SH, 0.8, 1.2)
		Bugs2._armor_along(h, arm, Vector3.ZERO, wrist, 0.20 * s, SH2)
		h._hydraulic(arm, Vector3(0, 0.18 * s, 0.04 * s), wrist + Vector3(0, 0.18 * s, 0.14 * s), 0.052 * s, DK)
		# 半包式工程黄护罩（固定在锯臂前端，不随锯片转）
		h._p(arm, ART.cyl(0.50 * s, 0.13 * s, 0.50 * s, 14), h._hazard_yel(), wrist + Vector3(0, 0.12 * s, 0.12 * s), Vector3(0, 0, 90), Vector3(0.55, 1.0, 0.55))
		var saw := Node3D.new()
		saw.position = wrist
		arm.add_child(saw)
		h._p(saw, ART.cyl(0.46 * s, 0.065 * s, 0.46 * s, 20), ST, Vector3.ZERO, Vector3(0, 0, 90))
		h._p(saw, ART.cyl(0.18 * s, 0.12 * s, 0.18 * s, 12), h._brass(), Vector3.ZERO, Vector3(0, 0, 90))
		for k in 10:
			var a := TAU * k / 10.0
			h._prism(saw, [Vector2(-0.05, 0.0) * s, Vector2(0.05, 0.0) * s, Vector2(0.01, 0.16) * s],
				0.065 * s, 0.01, h._chrome(), Vector3(0, sin(a) * 0.44 * s, cos(a) * 0.44 * s), Vector3(rad_to_deg(a), 90, 0))
		h.spinners.append([saw, Vector3.RIGHT, 3.5 * sx, 16.0 * sx])
		h.scythes.append(arm)
	# 6. 六条重型液压柱腿
	var z_legs := [-0.54, 0.06, 0.66]
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			Bugs2._hleg(h, body, Vector3(sx * 0.72 * s, by - 0.12 * s, float(z_legs[i]) * s), sx * (-18.0 + i * 18.0), sx,
				s * 0.96, by - 0.10 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), 1.05, 1.08)


# ---------------------------------------------------------------- 6. 深渊重装电弧谐振工程母机 (abyss_queen)
static func _queen(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.28, 0.31, 0.36))
	var SH2: Material = h._vmat_solid(Color(0.42, 0.45, 0.49))
	var OL: Material = h._vmat_matte(Color(0.32, 0.35, 0.28))
	var DK: Material = h._vmat_solid(Color(0.14, 0.15, 0.18))
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.035))
	var CORE := Color(0.38, 0.68, 1.0)
	var by := 0.98 * s
	# 宽厚八角铆接重装工程底盘 + 防撞警示条 + 装甲裙板
	h._prism(body, [Vector2(-0.62, -0.62) * s, Vector2(0.62, -0.62) * s, Vector2(0.80, 0.0) * s, Vector2(0.64, 0.72) * s, Vector2(-0.64, 0.72) * s, Vector2(-0.80, 0.0) * s],
		0.56 * s, 0.08, DK, Vector3(0, by, 0.16 * s), Vector3(90, 0, 0))
	Models._shell_layer(h, body, Vector3(0, by + 0.26 * s, 0.16 * s), Vector3(1.18, 0.44, 1.16) * s, SH2, 3.0)
	h._panels(body, Vector3(0, by + 0.50 * s, 0.16 * s), Vector3(-90, 0, 0), 0.96 * s, 0.94 * s, 261, 6)
	for sx: float in [-1.0, 1.0]:
		h._box(body, OL, Vector3(sx * 0.66 * s, by + 0.12 * s, 0.16 * s), Vector3(0.10, 0.26, 0.88) * s)
		h._box(body, h._hazard_yel(), Vector3(sx * 0.72 * s, by + 0.08 * s, -0.14 * s), Vector3(0.02, 0.08, 0.34) * s)
	# 敦实倾斜重工业电弧反应塔身 + 背部双级镀铬液压脊柱撑杆 + 黄铜波导法兰箍
	var up := Node3D.new()
	up.position = Vector3(0, by + 0.36 * s, 0.02 * s)
	body.add_child(up)
	Models._tube(h, up, [Vector3(0, 0, 0), Vector3(0, 0.46 * s, -0.06 * s), Vector3(0, 0.92 * s, -0.12 * s), Vector3(0, 1.28 * s, -0.08 * s)],
		[0.54 * s, 0.46 * s, 0.38 * s, 0.30 * s], SH, 1.08, 0.88, Vector3.FORWARD, 5, 8, true)
	for sx: float in [-1.0, 1.0]:
		h._hydraulic(up, Vector3(sx * 0.32 * s, 0.06 * s, 0.18 * s), Vector3(sx * 0.24 * s, 0.98 * s, 0.08 * s), 0.052 * s, DK)
	for k in 3:
		h._p(up, ART.cyl((0.50 - k * 0.06) * s, 0.08 * s, (0.52 - k * 0.06) * s, 8), h._brass() if k == 1 else SH2, Vector3(0, (0.24 + k * 0.34) * s, -0.06 * s))
	# 胸口铸钢防爆炉膛约束反应核（core_mi）+ 左右液压屏蔽闸门（plates）
	h._prism(up, [Vector2(-0.30, 0.62) * s, Vector2(0.30, 0.62) * s, Vector2(0.36, 0.12) * s, Vector2(0, -0.12) * s, Vector2(-0.36, 0.12) * s],
		0.15 * s, 0.08, DK, Vector3(0, 0.50 * s, -0.34 * s))
	var core: MeshInstance3D = h._p(up, ART.cyl(0.15 * s, 0.26 * s, 0.15 * s, 12), ART.emit(CORE, 1.10), Vector3(0, 0.52 * s, -0.38 * s))
	h.core_mi = core
	h._p(up, ART.torus(0.21 * s, 0.26 * s, 16), h._brass(), Vector3(0, 0.52 * s, -0.38 * s), Vector3(0, 90, 0))
	for sx: float in [-1.0, 1.0]:
		var pl := Node3D.new()
		pl.position = Vector3(sx * 0.26 * s, by + 0.88 * s, -0.28 * s)
		pl.rotation_degrees = Vector3(0, sx * 14.0, sx * 6.0)
		pl.set_meta("side", sx)
		body.add_child(pl)
		h._prism(pl, [Vector2(0.24, 0.34) * s, Vector2(0.20, -0.30) * s, Vector2(-0.20, -0.34) * s, Vector2(-0.24, 0.30) * s],
			0.11 * s, 0.08, SH2, Vector3(sx * 0.15 * s, 0, 0))
		h._box(pl, h._hazard_yel(), Vector3(sx * 0.03 * s, 0, -0.06 * s), Vector3(0.05, 0.52, 0.03) * s)
		h.plates.append(pl)
	# 重装火控指挥舱头 + 横置相控阵雷达波导桁架（crown：取代刺眼紫刺冠！）
	var head := Node3D.new()
	head.position = Vector3(0, by + 1.66 * s, -0.18 * s)
	body.add_child(head)
	h._prism(head, [Vector2(0.28, 0.20) * s, Vector2(0.32, -0.12) * s, Vector2(0.14, -0.26) * s, Vector2(-0.14, -0.26) * s, Vector2(-0.32, -0.12) * s, Vector2(-0.28, 0.20) * s],
		0.36 * s, 0.08, SH2, Vector3.ZERO)
	h._box(head, h._steel(), Vector3(0, 0.14 * s, -0.18 * s), Vector3(0.56, 0.04, 0.12) * s, Vector3(12, 0, 0))
	for sx: float in [-1.0, 1.0]:
		Models._eye(h, head, Vector3(sx * 0.14 * s, 0.02 * s, -0.18 * s), 0.062 * s, CORE)
	var crown := Node3D.new()
	crown.position = Vector3(0, 0.20 * s, 0.02 * s)
	head.add_child(crown)
	h._p(crown, HS.cbox(Vector3(0.76, 0.12, 0.18) * s, 0.025 * s), DK, Vector3(0, 0.10 * s, 0.02 * s))
	for sx: float in [-1.0, 1.0]:
		h._p(crown, HS.cbox(Vector3(0.18, 0.24, 0.22) * s, 0.02 * s), OL, Vector3(sx * 0.34 * s, 0.14 * s, 0.02 * s))
		h._p(crown, ART.cyl(0.032 * s, 0.34 * s, 0.042 * s, 8), h._brass(), Vector3(sx * 0.22 * s, 0.30 * s, 0.04 * s), Vector3(-12, 0, sx * -10.0))
	h._box(crown, BL, Vector3(0, 0.10 * s, -0.075 * s), Vector3(0.46, 0.06, 0.02) * s)
	h._box(crown, Models._mineral_glow(CORE, 0.65), Vector3(0, 0.10 * s, -0.082 * s), Vector3(0.38, 0.028, 0.012) * s)
	h.crown = crown
	# 四片重钢百叶散热翼板（wings：钛灰装甲框 + 钢制横肋 + 深黑散热百叶，取代大面积发光紫翼！）
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			var w := Node3D.new()
			w.position = Vector3(sx * 0.32 * s, by + (1.18 - i * 0.26) * s, 0.24 * s)
			w.set_meta("side", sx)
			w.rotation_degrees = Vector3(0, sx * (22.0 + i * 20.0), 0)
			body.add_child(w)
			var wlen: float = (1.02 - i * 0.20) * s
			h._servo(w, Vector3.ZERO, 0.085 * s)
			h._prism(w, [Vector2(0.0, 0.0), Vector2(0.20 * s, wlen * 0.42), Vector2(0.06 * s, wlen), Vector2(-0.20 * s, wlen * 0.58), Vector2(-0.22 * s, 0.12 * s)],
				0.07 * s, 0.05, SH2 if i == 0 else OL, Vector3.ZERO, Vector3(0, sx * 90.0, 0))
			h._bar(w, Vector3.ZERO, Vector3(sx * wlen * 0.82, wlen * 0.44, 0), 0.065 * s, 0.075 * s, h._steel())
			h._box(w, Models._mineral_glow(CORE, 0.55), Vector3(sx * wlen * 0.44, wlen * 0.22, 0), Vector3(wlen * 0.48, 0.032 * s, 0.078 * s), Vector3(0, 0, sx * 24.0))
			h.wings.append(w)
	# 双臂重型液压等离子焊割镰（scythes）
	for sx: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.44 * s, by + 1.08 * s, -0.14 * s)
		arm.rotation_degrees = Vector3(0, sx * 16.0, 0)
		body.add_child(arm)
		h._servo(arm, Vector3.ZERO, 0.14 * s)
		var el := Vector3(sx * 0.30, -0.32, -0.38) * s
		h._bar(arm, Vector3.ZERO, el, 0.15 * s, 0.17 * s, SH2)
		h._hydraulic(arm, Vector3(0, 0.10 * s, 0), el + Vector3(0, 0.10 * s, 0.04 * s), 0.038 * s, DK)
		h._servo(arm, el, 0.11 * s)
		h._jag(arm, 0.26 * s, 1.08 * s, 0.075 * s, h._chrome(), Vector3(sx * 0.34, -0.36, -0.44) * s, Vector3(-64, sx * 8.0, 0), 4, -1.0, sx * 0.08 * s)
		h.scythes.append(arm)
	# 紧凑型过顶重装电弧焊枪曲臂尾（abdomen：收束于背甲上方，配双液压油缸与深黑电弧喷口）
	var abd := Node3D.new()
	abd.position = Vector3(0, by + 0.22 * s, 0.56 * s)
	body.add_child(abd)
	var b0 := Vector3.ZERO
	var b1 := Vector3(0, 0.58 * s, 0.38 * s)
	var b2 := Vector3(0, 1.18 * s, 0.16 * s)
	h._bar(abd, b0, b1, 0.24 * s, 0.26 * s, DK)
	h._bar(abd, b1, b2, 0.18 * s, 0.20 * s, SH2)
	h._hydraulic(abd, Vector3(0, 0.08 * s, -0.12 * s), b1 + Vector3(0, -0.06 * s, -0.10 * s), 0.042 * s, OL)
	h._servo(abd, b1, 0.14 * s)
	h._p(abd, HS.cbox(Vector3(0.34, 0.28, 0.44) * s, 0.03 * s), DK, b2 + Vector3(0, 0.04 * s, -0.10 * s))
	h._p(abd, ART.cyl(0.10 * s, 0.32 * s, 0.12 * s, 12), h._brass(), b2 + Vector3(0, 0.04 * s, -0.36 * s), Vector3(84, 0, 0))
	h._p(abd, ART.cyl(0.072 * s, 0.04 * s, 0.072 * s, 10), BL, b2 + Vector3(0, 0.02 * s, -0.52 * s), Vector3(84, 0, 0), Vector3.ONE, false)
	h.abdomen = abd
	# 四条重型反关节驻锄支腿 + 双肩高压绝缘套管（crystals）
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			h._zleg(body, Vector3(sx * 0.46 * s, by - 0.04 * s, (-0.18 + i * 0.50) * s), sx * (-24.0 + i * 28.0), sx,
				(1.42 - i * 0.12) * s, by * 1.02, 0.13 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), true)
	for sx: float in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(sx * 0.50 * s, by + 1.18 * s, 0.02 * s)
		body.add_child(shoulder)
		for mi in Models._cluster(h, shoulder, Vector3.ZERO, 0.20 * s, CORE, 3, 0.82):
			h.crystals.append(mi)
