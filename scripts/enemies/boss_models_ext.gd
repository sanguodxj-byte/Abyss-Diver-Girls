extends RefCounted
## 区域副 Boss 的专属 3D 程序化重工业建模（共 6 只）：
##   - harbor_reaper（灰港猎潮镰王）：四臂船坞拆解液压剪舰机 + 导管喷水推进尾舱 + 金属框架声呐帆
##   - slag_colossus（熔渣巨炮皇虫）：八足重装高炉攻城炮台 + 双联制退榴弹炮塔 + 双肩六管箍架转轮炮
##   - dune_devourer（荒原噬沙钻皇）：五节液压顶进盾构机（TBM） + 双级滚刀破岩刀盘 + 排渣导流尾管
##   - prism_archon（赤湖棱镜主宰）：高能激光干涉仪四足平台 + 钢桁架同步加速环 + 金属框衍射散热翼
##   - gorge_tyrant（裂谷碎岩暴君）：六足露天矿山破岩泰坦 + 双臂半罩警示黄十二齿钨钢圆盘岩锯
##   - abyss_harbinger（深渊先驱魔像）：六足深潜托卡马克重装机兵 + 双轴钢铜陀螺约束环 + 双肩电磁轨道炮

const ART = preload("res://scripts/art.gd")
const HS = preload("res://scripts/hs.gd")
const Bugs2 = preload("res://scripts/bugs2.gd")
const Models = preload("res://scripts/enemies/models.gd")


# ---------------------------------------------------------------- 灰港猎潮镰王 (harbor_reaper)
static func build_harbor_reaper(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.20, 0.30, 0.34))
	var SH2: Material = h._vmat_solid(Color(0.35, 0.43, 0.46))
	var DK: Material = h._vmat_solid(Color(0.09, 0.11, 0.13))
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.035))
	var ST: Material = h._steel()
	var BR: Material = h._brass()
	var RS: Material = h._rust_plate()
	var HZ: Material = h._hazard_yel()
	var CYAN := Color(0.22, 0.88, 0.84)
	var by := 1.04 * s
	# 1. 折角舰船龙骨推进尾舱 + 铆接甲板护壳 + 双联导管喷水推进器（深黑喷膛）
	h._loft(body, HS.crect(1.0, 1.0, 0.28), [
		[-0.18 * s, Vector2(0.70, 0.44) * s, Vector2.ZERO],
		[0.25 * s, Vector2(0.86, 0.52) * s, Vector2(0, 0.04 * s)],
		[0.78 * s, Vector2(0.72, 0.44) * s, Vector2(0, 0.08 * s)],
		[1.28 * s, Vector2(0.46, 0.30) * s, Vector2(0, 0.14 * s)],
		[1.60 * s, Vector2(0.24, 0.18) * s, Vector2(0, 0.18 * s)],
	], DK, Vector3(0, by - 0.08 * s, 0))
	for k in 3:
		var z0 := (-0.02 + k * 0.40) * s
		var f := 1.0 - k * 0.15
		h._shell(body, SH2 if k % 2 == 0 else SH, Vector3(0, by - 0.04 * s, 0), 0.37 * s * f, 0.045 * s, z0, z0 + 0.36 * s,
			[[0.0, 0.96, 0.84, 0.26 * s * f], [0.5, 1.14, 0.98, 0.31 * s * f], [1.0, 0.92, 0.80, 0.24 * s * f]], Vector3.ZERO, 70.0, 7)
		# 船用防腐锌块与高强螺栓
		for sx: float in [-1.0, 1.0]:
			h._box(body, HZ if k == 0 else BR, Vector3(sx * 0.34 * s * f, by + 0.14 * s * f, z0 + 0.18 * s), Vector3(0.04, 0.04, 0.14) * s)
	for sx: float in [-1.0, 1.0]:
		var jp := Vector3(sx * 0.35 * s, by + 0.04 * s, 1.20 * s)
		var jr := Vector3(78, sx * 12.0, 0)
		h._p(body, ART.cyl(0.16 * s, 0.52 * s, 0.22 * s, 14), SH, jp, jr)
		h._p(body, ART.cyl(0.18 * s, 0.10 * s, 0.18 * s, 14), BR, jp + Vector3(0, 0.01 * s, -0.14 * s), jr)
		h._p(body, ART.cyl(0.15 * s, 0.16 * s, 0.17 * s, 14), ST, jp + Vector3(sx * 0.03 * s, -0.04 * s, 0.22 * s), jr)
		h._p(body, ART.cyl(0.125 * s, 0.18 * s, 0.125 * s, 12), BL, jp + Vector3(sx * 0.035 * s, -0.045 * s, 0.24 * s), jr, Vector3.ONE, false)
	# 2. 高耸前倾的船坞起重立柱胸腔 + 双开防爆胸甲门（plates）+ 笼式电浆核心（core_mi）
	var thorax := Node3D.new()
	thorax.position = Vector3(0, by + 0.08 * s, -0.12 * s)
	body.add_child(thorax)
	h._limb(thorax, Vector3.ZERO, Vector3(0, 1.28 * s, -0.46 * s), 0.64 * s, 0.54 * s, DK, 0.74, 1.16)
	Bugs2._armor_along(h, thorax, Vector3(0, 0.08 * s, 0.08 * s), Vector3(0, 1.24 * s, -0.38 * s), 0.39 * s, SH, Vector3(0, 0.4, 1))
	h._panels(thorax, Vector3(0, 0.68 * s, -0.02 * s), Vector3(-68, 0, 0), 0.56 * s, 0.92 * s, 401, 5)
	for sx: float in [-1.0, 1.0]:
		h._hydraulic(thorax, Vector3(sx * 0.26 * s, 0.06 * s, -0.08 * s), Vector3(sx * 0.22 * s, 1.08 * s, -0.42 * s), 0.045 * s, DK)
	var core: MeshInstance3D = h._p(thorax, ART.sphere(0.19 * s, -1, 16), ART.emit(CYAN, 1.45), Vector3(0, 0.68 * s, -0.42 * s), Vector3.ZERO, Vector3(0.9, 1.2, 0.78), false)
	h.core_mi = core
	for k in 3:
		h._box(thorax, BR, Vector3(0, (0.50 + k * 0.18) * s, -0.54 * s), Vector3(0.36, 0.03, 0.04) * s)
	for sx: float in [-1.0, 1.0]:
		var pl := Node3D.new()
		pl.position = Vector3(sx * 0.24 * s, by + 0.76 * s, -0.48 * s)
		pl.rotation_degrees = Vector3(16, sx * 14.0, 0)
		pl.set_meta("side", sx)
		body.add_child(pl)
		h._prism(pl, [Vector2(0.22, 0.42) * s, Vector2(0.20, -0.38) * s, Vector2(-0.18, -0.42) * s, Vector2(-0.22, 0.36) * s],
			0.09 * s, 0.08, SH2, Vector3(sx * 0.14 * s, 0, 0))
		h._box(pl, HZ, Vector3(sx * 0.02 * s, 0, -0.05 * s), Vector3(0.05, 0.72, 0.03) * s)
		h._box(pl, RS, Vector3(sx * 0.18 * s, 0.12 * s, -0.05 * s), Vector3(0.18, 0.22, 0.025) * s)
		h.plates.append(pl)
	# 背部两片钢桁框高频声呐帆（wings：金属梁框 + 窄缝波导条，取代整块发光板）
	for sx: float in [-1.0, 1.0]:
		var fin := Node3D.new()
		fin.position = Vector3(sx * 0.28 * s, by + 1.08 * s, -0.16 * s)
		fin.set_meta("side", sx)
		fin.rotation_degrees = Vector3(0, sx * 24.0, 0)
		body.add_child(fin)
		h._servo(fin, Vector3.ZERO, 0.09 * s)
		h._prism(fin, [Vector2(0, 0), Vector2(0.24 * s, 0.48 * s), Vector2(0.08 * s, 1.18 * s), Vector2(-0.22 * s, 0.66 * s)],
			0.065 * s, 0.05, SH, Vector3.ZERO, Vector3(-22, sx * 90.0, 0))
		h._bar(fin, Vector3.ZERO, Vector3(0, 1.06 * s, 0.44 * s), 0.07 * s, 0.08 * s, ST)
		for k in 3:
			var fy := (0.30 + k * 0.26) * s
			h._box(fin, ART.emit(CYAN, 1.1), Vector3(0, fy, (0.08 + k * 0.08) * s), Vector3(0.075, 0.028, 0.26) * s, Vector3(-22, 0, 0))
		h.wings.append(fin)
	# 3. 锤头舰桥火控舱 + 海事雷达横桁（crown）+ 液压剪缆颚（jaws）
	var head := Node3D.new()
	head.position = Vector3(0, by + 1.46 * s, -0.62 * s)
	body.add_child(head)
	h._prism(head, [Vector2(-0.46, 0.16) * s, Vector2(0.46, 0.16) * s, Vector2(0.34, -0.22) * s, Vector2(0, -0.34) * s, Vector2(-0.34, -0.22) * s],
		0.36 * s, 0.06, SH2, Vector3.ZERO)
	h._box(head, DK, Vector3(0, 0.12 * s, -0.06 * s), Vector3(0.76, 0.08, 0.34) * s)
	for sx: float in [-1.0, 1.0]:
		Models._eye(h, head, Vector3(sx * 0.28 * s, 0.04 * s, -0.18 * s), 0.075 * s, CYAN)
		Models._eye(h, head, Vector3(sx * 0.14 * s, -0.06 * s, -0.20 * s), 0.055 * s, CYAN)
		var j := Node3D.new()
		j.position = Vector3(sx * 0.15 * s, -0.18 * s, -0.18 * s)
		head.add_child(j)
		h._box(j, DK, Vector3(0, 0, -0.08 * s), Vector3(0.10, 0.10, 0.20) * s)
		h._jag(j, 0.14 * s, 0.44 * s, 0.055 * s, Models._bone(), Vector3.ZERO, Vector3(-68, 0, sx * 18.0), 3, -1.0, 0.0)
		h.jaws.append(j)
	var crown := Node3D.new()
	crown.position = Vector3(0, 0.18 * s, -0.02 * s)
	head.add_child(crown)
	h._box(crown, ST, Vector3(0, 0.14 * s, 0.04 * s), Vector3(0.68, 0.06, 0.10) * s)
	h._bar(crown, Vector3.ZERO, Vector3(0, 0.38 * s, 0.12 * s), 0.08 * s, 0.10 * s, DK)
	for sx: float in [-1.0, 1.0]:
		h._box(crown, HZ, Vector3(sx * 0.34 * s, 0.14 * s, 0.04 * s), Vector3(0.08, 0.10, 0.14) * s)
		Models._shard(h, crown, Vector3(sx * 0.24 * s, 0.14 * s, 0.04 * s), Vector3(sx * 0.35, 1.0, 0.25), 0.44 * s, 0.045 * s, CYAN, 1.35)
	h.crown = crown
	# 4. 四臂重型拆船液压大剪镰（scythes：双液压缸 + 锻造钨钢刃背 + 极窄等离子割缝）
	for tier in 2:
		for sx: float in [-1.0, 1.0]:
			var sc := Node3D.new()
			var y_off := (1.16 if tier == 0 else 0.68) * s
			var x_off := (0.38 if tier == 0 else 0.32) * s
			sc.position = Vector3(sx * x_off, by + y_off, -0.44 * s)
			sc.rotation_degrees = Vector3(0, sx * (18.0 + tier * 10.0), 0)
			body.add_child(sc)
			h._servo(sc, Vector3.ZERO, (0.16 - tier * 0.03) * s)
			var el := Vector3(sx * (0.32 - tier * 0.06), -0.34, -0.52) * s
			h._limb(sc, Vector3.ZERO, el, (0.20 - tier * 0.03) * s, (0.22 - tier * 0.03) * s, SH, 0.75, 1.22)
			Bugs2._armor_along(h, sc, Vector3.ZERO, el, (0.16 - tier * 0.02) * s, RS if tier == 1 else SH2)
			h._hydraulic(sc, Vector3(0, 0.14 * s, 0), el + Vector3(0, 0.10 * s, 0.06 * s), (0.038 - tier * 0.006) * s, DK)
			h._servo(sc, el, (0.14 - tier * 0.02) * s)
			var bl_len := (1.40 if tier == 0 else 1.04) * s
			# 锻造刀背夹具 + 钨钢剪刃
			h._bar(sc, el, el + Vector3(sx * 0.06 * s, -0.48 * s, -bl_len * 0.56), 0.09 * s, 0.13 * s, DK)
			h._jag(sc, (0.35 - tier * 0.07) * s, bl_len, 0.085 * s, Models._bone(), el + Vector3(sx * 0.04 * s, -0.04 * s, -0.06 * s),
				Vector3(-62 + tier * 12.0, sx * 8.0, 0), 5 - tier, -1.0, sx * 0.12 * s)
			h._box(sc, ART.emit(CYAN, 1.5), el + Vector3(sx * 0.05 * s, -0.28 * s, -0.44 * s), Vector3(0.016 * s, 0.028 * s, bl_len * 0.55), Vector3(-28, 0, 0))
			h.scythes.append(sc)
	# 5. 四条重型反关节船坞步足
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			h._mleg(body, Vector3(sx * 0.38 * s, by - 0.08 * s, (-0.12 + i * 0.56) * s), sx * (-22.0 + i * 48.0), sx,
				(1.42 - i * 0.08) * s, by, 0.105 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), i == 1)


# ---------------------------------------------------------------- 熔渣巨炮皇虫 (slag_colossus)
static func build_slag_colossus(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.30, 0.24, 0.21))
	var SH2: Material = h._vmat_solid(Color(0.42, 0.38, 0.35))
	var DK: Material = h._vmat_solid(Color(0.10, 0.10, 0.11))
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.035))
	var ST: Material = h._steel()
	var BR: Material = h._brass()
	var RS: Material = h._rust_plate()
	var HZ: Material = h._hazard_yel()
	var MAGMA := Color(1.0, 0.42, 0.12)
	var GOLD := Color(0.96, 0.62, 0.18)
	var by := 1.06 * s
	# 1. 超宽八棱重装高炉攻城底盘 + 侧舷走道翼板
	h._loft(body, HS.crect(1.0, 1.0, 0.26), [
		[-1.04 * s, Vector2(1.28, 0.46) * s, Vector2.ZERO],
		[-0.48 * s, Vector2(1.68, 0.58) * s, Vector2(0, 0.04 * s)],
		[0.36 * s, Vector2(1.74, 0.60) * s, Vector2(0, 0.04 * s)],
		[1.10 * s, Vector2(1.38, 0.48) * s, Vector2.ZERO],
	], DK, Vector3(0, by, 0.06 * s))
	h._p(body, HS.cbox(Vector3(1.50, 0.34, 1.70) * s, 0.05 * s), SH, Vector3(0, by + 0.36 * s, 0.06 * s))
	h._panels(body, Vector3(0, by + 0.54 * s, 0.06 * s), Vector3(-90, 0, 0), 1.32 * s, 1.50 * s, 410, 8)
	for sx: float in [-1.0, 1.0]:
		h._box(body, RS, Vector3(sx * 0.80 * s, by + 0.24 * s, 0.06 * s), Vector3(0.12, 0.22, 1.48) * s)
		h._box(body, HZ, Vector3(sx * 0.865 * s, by + 0.20 * s, -0.46 * s), Vector3(0.02, 0.08, 0.38) * s)
	# 2. 背部中央双联 240mm 制退榴弹炮塔（turret：开槽制退器 + 深黑炮膛 + 镀铬复进机）
	var tur := Node3D.new()
	tur.position = Vector3(0, by + 0.62 * s, 0.12 * s)
	body.add_child(tur)
	h._p(tur, ART.cyl(0.58 * s, 0.22 * s, 0.66 * s, 16), DK, Vector3(0, 0.08 * s, 0))
	h._p(tur, HS.cbox(Vector3(0.96, 0.46, 1.02) * s, 0.05 * s), SH2, Vector3(0, 0.33 * s, 0.06 * s))
	h._p(tur, HS.cbox(Vector3(0.36, 0.18, 0.38) * s, 0.03 * s), SH, Vector3(0.24 * s, 0.62 * s, 0.14 * s))
	Models._eye(h, tur, Vector3(0.24 * s, 0.62 * s, -0.06 * s), 0.055 * s, MAGMA)
	for sx: float in [-1.0, 1.0]:
		var bx := sx * 0.25 * s
		var gun := Node3D.new()
		gun.position = Vector3(bx, 0.34 * s, -0.22 * s)
		gun.rotation_degrees = Vector3(-18, 0, 0)
		tur.add_child(gun)
		# 炮尾护套 + 主身管 + 上下驻退/复进液气压筒
		h._p(gun, HS.cbox(Vector3(0.28, 0.28, 0.54) * s, 0.03 * s), SH, Vector3(0, 0, -0.08 * s))
		h._p(gun, ART.cyl(0.115 * s, 1.38 * s, 0.145 * s, 14), ST, Vector3(0, 0, -0.76 * s), Vector3(90, 0, 0))
		h._p(gun, ART.cyl(0.14 * s, 0.12 * s, 0.14 * s, 14), BR, Vector3(0, 0, -0.56 * s), Vector3(90, 0, 0))
		h._hydraulic(gun, Vector3(0, 0.16 * s, 0.10 * s), Vector3(0, 0.15 * s, -0.68 * s), 0.042 * s, DK)
		# 双室开槽炮口制退器 + 深黑炮膛（彻底移除悬浮橙色光环）
		h._p(gun, HS.cbox(Vector3(0.28, 0.22, 0.30) * s, 0.025 * s), DK, Vector3(0, 0, -1.48 * s))
		for slot_i in 2:
			h._box(gun, BL, Vector3(0, 0, (-1.42 - slot_i * 0.11) * s), Vector3(0.30, 0.09, 0.055) * s, Vector3.ZERO)
		h._p(gun, ART.cyl(0.09 * s, 0.22 * s, 0.09 * s, 12), BL, Vector3(0, 0, -1.55 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	h.turret = tur
	# 双肩旋转六管迫击转轮（spinners：钢制身管箍盘 + 警示黄环 + 六孔深黑炮膛）
	for sx: float in [-1.0, 1.0]:
		var pod := Node3D.new()
		pod.position = Vector3(sx * 0.84 * s, by + 0.58 * s, -0.18 * s)
		pod.rotation_degrees = Vector3(26, sx * -10.0, 0)
		body.add_child(pod)
		h._p(pod, ART.cyl(0.30 * s, 0.34 * s, 0.32 * s, 14), DK, Vector3(0, 0, 0.10 * s), Vector3(90, 0, 0))
		h._p(pod, ART.cyl(0.29 * s, 0.08 * s, 0.29 * s, 16), BR, Vector3(0, 0, -0.08 * s), Vector3(90, 0, 0))
		h._p(pod, ART.cyl(0.28 * s, 0.07 * s, 0.28 * s, 16), SH2, Vector3(0, 0, -0.30 * s), Vector3(90, 0, 0))
		h._p(pod, ART.cyl(0.285 * s, 0.04 * s, 0.285 * s, 16), HZ, Vector3(0, 0, -0.22 * s), Vector3(90, 0, 0))
		for k in 6:
			var a := TAU * k / 6.0
			var bx := cos(a) * 0.175 * s
			var by2 := sin(a) * 0.175 * s
			h._p(pod, ART.cyl(0.062 * s, 0.62 * s, 0.062 * s, 10), ST, Vector3(bx, by2, -0.06 * s), Vector3(90, 0, 0))
			h._p(pod, ART.cyl(0.046 * s, 0.12 * s, 0.046 * s, 8), BL, Vector3(bx, by2, -0.33 * s), Vector3(90, 0, 0), Vector3.ONE, false)
		h.spinners.append([pod, Vector3.FORWARD, 1.4 * sx, 9.0 * sx])
	# 3. 前胸双开高炉防爆装甲门（plates）+ 炉芯（core_mi）
	var core: MeshInstance3D = h._p(body, ART.sphere(0.24 * s, -1, 16), ART.emit(MAGMA, 1.5), Vector3(0, by + 0.34 * s, -0.82 * s), Vector3.ZERO, Vector3(1.05, 0.85, 0.85), false)
	h.core_mi = core
	for sx: float in [-1.0, 1.0]:
		var pl := Node3D.new()
		pl.position = Vector3(sx * 0.36 * s, by + 0.36 * s, -0.86 * s)
		pl.set_meta("side", sx)
		body.add_child(pl)
		h._p(pl, HS.cbox(Vector3(0.42, 0.44, 0.14) * s, 0.03 * s), SH2, Vector3(sx * 0.16 * s, 0, 0), Vector3(0, sx * 16.0, 0))
		h._box(pl, HZ, Vector3(sx * 0.02 * s, 0, -0.08 * s), Vector3(0.06, 0.38, 0.03) * s)
		h._box(pl, RS, Vector3(sx * 0.22 * s, 0, -0.08 * s), Vector3(0.22, 0.28, 0.025) * s)
		h.plates.append(pl)
	# 后部四枚钢箍加压燃料罐（sacs）与尾座（abdomen）
	var abd := Node3D.new()
	abd.position = Vector3(0, by + 0.24 * s, 0.94 * s)
	body.add_child(abd)
	h._p(abd, HS.cbox(Vector3(1.16, 0.28, 0.56) * s, 0.04 * s), DK, Vector3(0, 0.04 * s, 0.16 * s))
	for sx: float in [-1.0, 1.0]:
		h.sacs.append(Models._sac(h, abd, Vector3(sx * 0.54 * s, 0.12 * s, 0.0), 0.27 * s, MAGMA))
		h.sacs.append(Models._sac(h, abd, Vector3(sx * 0.32 * s, 0.18 * s, 0.42 * s), 0.23 * s, GOLD))
	h.abdomen = abd
	# 4. 宽扁推土装甲头 + 液压清渣铲臂（jaws + scythes）
	var head := Node3D.new()
	head.position = Vector3(0, by + 0.08 * s, -1.04 * s)
	body.add_child(head)
	h._p(head, HS.cbox(Vector3(0.90, 0.34, 0.44) * s, 0.04 * s), DK, Vector3.ZERO)
	h._box(head, HZ, Vector3(0, -0.10 * s, -0.23 * s), Vector3(0.76, 0.07, 0.03) * s)
	for sx: float in [-1.0, 1.0]:
		Models._eye(h, head, Vector3(sx * 0.28 * s, 0.06 * s, -0.22 * s), 0.075 * s, MAGMA)
		var j := Node3D.new()
		j.position = Vector3(sx * 0.26 * s, -0.12 * s, -0.20 * s)
		head.add_child(j)
		h._jag(j, 0.22 * s, 0.56 * s, 0.08 * s, ST, Vector3.ZERO, Vector3(-80, 0, sx * 18.0), 3, -1.0, 0.0)
		h.jaws.append(j)
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.68 * s, by + 0.04 * s, -0.88 * s)
		body.add_child(arm)
		h._servo(arm, Vector3.ZERO, 0.15 * s)
		h._p(arm, HS.cbox(Vector3(0.36, 0.28, 0.56) * s, 0.03 * s), SH2, Vector3(0, 0, -0.22 * s))
		h._hydraulic(arm, Vector3(0, 0.18 * s, 0.04 * s), Vector3(0, 0.08 * s, -0.44 * s), 0.04 * s, DK)
		h._jag(arm, 0.26 * s, 0.70 * s, 0.09 * s, Models._bone(), Vector3(0, -0.06 * s, -0.46 * s), Vector3(-84, sx * 10.0, 0), 3, -1.0, 0.0)
		h.scythes.append(arm)
	# 5. 八条重装液压炮架柱腿
	var z_list := [-0.66, -0.20, 0.26, 0.72]
	for i in 4:
		for sx: float in [-1.0, 1.0]:
			Bugs2._hleg(h, body, Vector3(sx * 0.78 * s, by - 0.12 * s, float(z_list[i]) * s), sx * (-24.0 + i * 16.0), sx,
				s * 0.92, by - 0.10 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), 1.04, 1.0)


# ---------------------------------------------------------------- 荒原噬沙钻皇 (dune_devourer)
static func build_dune_devourer(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.54, 0.43, 0.27))
	var SH2: Material = h._vmat_solid(Color(0.42, 0.36, 0.28))
	var DK: Material = h._vmat_solid(Color(0.13, 0.12, 0.10))
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.035))
	var ST: Material = h._steel()
	var BR: Material = h._brass()
	var RS: Material = h._rust_plate()
	var HZ: Material = h._hazard_yel()
	var AMBER := Color(1.0, 0.52, 0.14)
	var by := 0.94 * s
	# 1. 五节重型盾构机（TBM）钢护盾筒体 + 环向钢铜法兰圈 + 节间液压推进千斤顶（彻底移除 5 道发光呼啦圈）
	var seg_z := [-0.82, -0.34, 0.16, 0.66, 1.14]
	var seg_r := [0.64, 0.76, 0.74, 0.64, 0.48]
	var loft_pts: Array = []
	for i in 5:
		var zc := float(seg_z[i]) * s
		var r := float(seg_r[i]) * s
		var y_off := sin(float(i) * 0.65) * 0.10 * s
		loft_pts.append([zc - 0.20 * s, Vector2(r * 0.88, r * 0.76), Vector2(0, y_off)])
		loft_pts.append([zc, Vector2(r * 1.04, r * 0.90), Vector2(0, y_off + 0.02 * s)])
		loft_pts.append([zc + 0.20 * s, Vector2(r * 0.88, r * 0.76), Vector2(0, y_off)])
		h._shell(body, SH if i % 2 == 0 else SH2, Vector3(0, by + y_off, 0), r * 0.94, 0.055 * s, zc - 0.19 * s, zc + 0.19 * s,
			[[0.0, 0.94, 0.84, r * 0.76], [0.5, 1.10, 0.98, r * 0.86], [1.0, 0.94, 0.84, r * 0.76]], Vector3.ZERO, 78.0, 10)
		# 重型铆接盾构环向钢法兰箍（取代发光圆环）
		h._p(body, ART.torus(r * 0.86, r * 0.95, 18), BR if i % 2 == 0 else ST, Vector3(0, by + y_off, zc + 0.20 * s), Vector3(90, 0, 0), Vector3(1.04, 1.0, 0.45))
		if i < 4:
			var zn := float(seg_z[i + 1]) * s
			var rn := float(seg_r[i + 1]) * s
			var yn := sin(float(i + 1) * 0.65) * 0.10 * s
			for sx: float in [-1.0, 1.0]:
				h._hydraulic(body, Vector3(sx * r * 0.72, by + y_off + r * 0.34, zc + 0.10 * s),
					Vector3(sx * rn * 0.72, by + yn + rn * 0.34, zn - 0.10 * s), 0.038 * s, DK)
	h._loft(body, HS.ngon(12, 1.0), loft_pts, DK, Vector3(0, by, 0))
	# 背部双开防爆检修门（plates）+ 聚变热核（core_mi）+ 压电探测杆簇（crystals）
	var core: MeshInstance3D = h._p(body, ART.sphere(0.23 * s, -1, 16), ART.emit(AMBER, 1.45), Vector3(0, by + 0.62 * s, -0.08 * s), Vector3.ZERO, Vector3(0.95, 0.82, 1.2), false)
	h.core_mi = core
	for sx: float in [-1.0, 1.0]:
		var pl := Node3D.new()
		pl.position = Vector3(sx * 0.34 * s, by + 0.68 * s, -0.08 * s)
		pl.set_meta("side", sx)
		body.add_child(pl)
		h._prism(pl, [Vector2(0.30, 0.44) * s, Vector2(0.32, -0.44) * s, Vector2(-0.24, -0.46) * s, Vector2(-0.26, 0.40) * s],
			0.11 * s, 0.06, SH2, Vector3(sx * 0.20 * s, 0, 0), Vector3(-82, 0, sx * 18.0))
		h._box(pl, HZ, Vector3(sx * 0.04 * s, 0.04 * s, 0), Vector3(0.06, 0.04, 0.72) * s)
		h.plates.append(pl)
		var cl := Node3D.new()
		cl.position = Vector3(sx * 0.58 * s, by + 0.42 * s, 0.42 * s)
		body.add_child(cl)
		for mi in Models._cluster(h, cl, Vector3.ZERO, 0.24 * s, AMBER, 4, 0.85):
			h.crystals.append(mi)
	# 2. 前端双级反转钨钢盾构刀盘（spinners：中心滚刀锥头 + 外圈硬质合金扩孔盘，零发光圆环）
	var prow := Node3D.new()
	prow.position = Vector3(0, by - 0.02 * s, -1.04 * s)
	body.add_child(prow)
	h._p(prow, ART.cyl(0.62 * s, 0.20 * s, 0.66 * s, 16), DK, Vector3(0, 0, 0.04 * s), Vector3(90, 0, 0))
	h._p(prow, ART.cyl(0.65 * s, 0.06 * s, 0.65 * s, 16), HZ, Vector3(0, 0, -0.03 * s), Vector3(90, 0, 0))
	var drill_in := Node3D.new()
	prow.add_child(drill_in)
	h._p(drill_in, ART.cyl(0.06 * s, 0.94 * s, 0.42 * s, 10), ST, Vector3(0, 0, -0.46 * s), Vector3(-90, 0, 0))
	h._p(drill_in, ART.cyl(0.24 * s, 0.12 * s, 0.24 * s, 12), BR, Vector3(0, 0, -0.14 * s), Vector3(90, 0, 0))
	for k in 6:
		var a := TAU * k / 6.0
		h._jag(drill_in, 0.16 * s, 0.84 * s, 0.065 * s, Models._bone(), Vector3(cos(a) * 0.26 * s, sin(a) * 0.26 * s, -0.06 * s),
			Vector3(-82, 0, rad_to_deg(a) + 90.0), 4, -1.0, 0.0)
	h.spinners.append([drill_in, Vector3.FORWARD, 4.2, 18.0])
	var drill_out := Node3D.new()
	prow.add_child(drill_out)
	h._p(drill_out, ART.torus(0.47 * s, 0.58 * s, 18), SH2, Vector3(0, 0, -0.09 * s), Vector3.ZERO, Vector3(1, 1, 0.65))
	for k in 8:
		var a := TAU * k / 8.0
		var rx := cos(a) * 0.52 * s
		var ry := sin(a) * 0.52 * s
		h._box(drill_out, RS, Vector3(rx, ry, -0.10 * s), Vector3(0.14, 0.14, 0.16) * s, Vector3(0, 0, rad_to_deg(a)))
		h._jag(drill_out, 0.18 * s, 0.52 * s, 0.07 * s, ST, Vector3(rx, ry, -0.10 * s),
			Vector3(-76, 0, rad_to_deg(a) + 90.0), 3, -1.0, 0.0)
	h.spinners.append([drill_out, Vector3.FORWARD, -2.6, -12.0])
	# 左右液压碎岩颚（jaws）与下置清碴铲臂（scythes）
	for sx: float in [-1.0, 1.0]:
		Models._eye(h, prow, Vector3(sx * 0.44 * s, 0.36 * s, -0.04 * s), 0.065 * s, AMBER)
		var j := Node3D.new()
		j.position = Vector3(sx * 0.54 * s, 0, -0.04 * s)
		prow.add_child(j)
		h._hydraulic(j, Vector3(0, 0.12 * s, 0.16 * s), Vector3(-sx * 0.08 * s, 0.04 * s, -0.34 * s), 0.036 * s, DK)
		h._jag(j, 0.25 * s, 0.84 * s, 0.09 * s, Models._bone(), Vector3.ZERO, Vector3(-74, sx * -16.0, sx * 18.0), 4, -1.0, -sx * 0.10 * s)
		h.jaws.append(j)
		var sc := Node3D.new()
		sc.position = Vector3(sx * 0.42 * s, -0.34 * s, 0.06 * s)
		prow.add_child(sc)
		h._jag(sc, 0.28 * s, 0.88 * s, 0.10 * s, SH, Vector3.ZERO, Vector3(-68, sx * 12.0, 0), 4, -1.0, sx * 0.08 * s)
		h.scythes.append(sc)
	# 3. 尾部高昂螺旋排渣烟管（abdomen：法兰防烫罩 + 深黑排渣口，移除发光圆环）
	var tail := Node3D.new()
	tail.position = Vector3(0, by + 0.06 * s, 1.32 * s)
	body.add_child(tail)
	Models._tube(h, tail, [Vector3.ZERO, Vector3(0, 0.36 * s, 0.42 * s), Vector3(0, 0.82 * s, 0.64 * s)],
		[0.40 * s, 0.31 * s, 0.23 * s], SH2, 1.0, 1.0, Vector3.UP, 4, 12, true)
	h._p(tail, ART.cyl(0.26 * s, 0.24 * s, 0.26 * s, 14), RS, Vector3(0, 0.76 * s, 0.60 * s), Vector3(-54, 0, 0))
	h._p(tail, ART.cyl(0.25 * s, 0.06 * s, 0.25 * s, 14), BR, Vector3(0, 0.85 * s, 0.66 * s), Vector3(-54, 0, 0))
	h._p(tail, ART.cyl(0.18 * s, 0.16 * s, 0.18 * s, 12), BL, Vector3(0, 0.87 * s, 0.67 * s), Vector3(-54, 0, 0), Vector3.ONE, false)
	h.abdomen = tail
	# 4. 八条重型掘进铲足
	for i in 4:
		for sx: float in [-1.0, 1.0]:
			h._pleg(body, Vector3(sx * float(seg_r[i]) * 0.88 * s, by - 0.18 * s, float(seg_z[i]) * s), sx * (-20.0 + i * 14.0), sx,
				s * 0.84, by - 0.16 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0))


# ---------------------------------------------------------------- 赤湖棱镜主宰 (prism_archon)
static func build_prism_archon(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.30, 0.34, 0.38))
	var SH2: Material = h._vmat_solid(Color(0.44, 0.47, 0.51))
	var OL: Material = h._vmat_matte(Color(0.33, 0.36, 0.29))
	var DK: Material = h._vmat_solid(Color(0.14, 0.15, 0.18))
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.035))
	var ST: Material = h._steel()
	var BR: Material = h._brass()
	var HZ: Material = h._hazard_yel()
	var PRISM := Color(0.42, 0.66, 1.0)
	var CYAN := Color(0.28, 0.86, 0.96)
	var by := 1.18 * s
	# 1. 八角精密激光采矿平台底盘 + 正面钢压框准直反射镜盾
	var oct: Array = []
	for k in 8:
		var a := TAU * k / 8.0 + PI / 8.0
		oct.append(Vector2(cos(a) * 0.96, sin(a) * 0.96) * s)
	h._prism(body, oct, 0.48 * s, 0.07, DK, Vector3(0, by, 0), Vector3(90, 0, 0))
	var oct2: Array = []
	for q in oct:
		oct2.append(q * 0.82)
	h._prism(body, oct2, 0.28 * s, 0.08, SH, Vector3(0, by + 0.32 * s, 0), Vector3(90, 0, 0))
	h._panels(body, Vector3(0, by + 0.48 * s, 0), Vector3(-90, 0, 0), 1.12 * s, 1.12 * s, 420, 6)
	# 正面六边形装甲光学准直盾（重钢外框 + 黄铜压爪 + 烟熏深色镀膜镜面防泛白）
	var mirror := Node3D.new()
	mirror.position = Vector3(0, by + 0.18 * s, -0.92 * s)
	body.add_child(mirror)
	h._prism(mirror, [Vector2(-0.58, 0.40) * s, Vector2(0.58, 0.40) * s, Vector2(0.78, 0.0) * s, Vector2(0.50, -0.44) * s, Vector2(-0.50, -0.44) * s, Vector2(-0.78, 0.0) * s],
		0.16 * s, 0.05, SH2, Vector3.ZERO)
	h._prism(mirror, [Vector2(-0.40, 0.24) * s, Vector2(0.40, 0.24) * s, Vector2(0.52, 0.0) * s, Vector2(0.34, -0.26) * s, Vector2(-0.34, -0.26) * s, Vector2(-0.52, 0.0) * s],
		0.17 * s, 0.03, Models._mineral_glow(CYAN, 0.68), Vector3(0, 0, -0.01 * s))
	for k in 6:
		var a := TAU * k / 6.0
		h._box(mirror, BR if k % 2 == 0 else HZ, Vector3(cos(a) * 0.56 * s, sin(a) * 0.34 * s, -0.09 * s), Vector3(0.10, 0.08, 0.06) * s, Vector3(0, 0, rad_to_deg(a)))
	for sx: float in [-1.0, 1.0]:
		var j := Node3D.new()
		j.position = Vector3(sx * 0.34 * s, -0.26 * s, -0.10 * s)
		mirror.add_child(j)
		h._box(j, DK, Vector3(0, 0, -0.12 * s), Vector3(0.16, 0.14, 0.28) * s)
		h._p(j, ART.cyl(0.055 * s, 0.34 * s, 0.068 * s, 10), ST, Vector3(0, -0.02 * s, -0.34 * s), Vector3(82, sx * -8.0, 0))
		h._p(j, ART.cyl(0.038 * s, 0.04 * s, 0.038 * s, 10), BL, Vector3(-sx * 0.02 * s, -0.04 * s, -0.51 * s), Vector3(82, sx * -8.0, 0), Vector3.ONE, false)
		h.jaws.append(j)
	# 2. 中央敦实六角激光泵浦塔身 + 双开屏蔽闸门（plates）+ 切伦科夫谐振核（core_mi）
	var spire := Node3D.new()
	spire.position = Vector3(0, by + 0.44 * s, 0.04 * s)
	body.add_child(spire)
	h._loft(spire, HS.ngon(6, 1.0), [
		[0.0, Vector2(0.58, 0.58) * s, Vector2.ZERO],
		[0.54 * s, Vector2(0.48, 0.48) * s, Vector2.ZERO],
		[1.10 * s, Vector2(0.36, 0.36) * s, Vector2.ZERO],
		[1.42 * s, Vector2(0.26, 0.26) * s, Vector2.ZERO],
	], SH2, Vector3.ZERO, Vector3(-90, 0, 0))
	for k in 6:
		var a := TAU * k / 6.0
		h._bar(spire, Vector3(cos(a) * 0.56 * s, 0.04 * s, sin(a) * 0.56 * s), Vector3(cos(a) * 0.28 * s, 1.36 * s, sin(a) * 0.28 * s), 0.065 * s, 0.075 * s, ST)
	var core: MeshInstance3D = h._p(spire, ART.sphere(0.20 * s, -1, 16), ART.emit(CYAN, 1.25), Vector3(0, 0.62 * s, -0.22 * s), Vector3.ZERO, Vector3(0.9, 1.2, 0.9), false)
	h.core_mi = core
	for sx: float in [-1.0, 1.0]:
		var pl := Node3D.new()
		pl.position = Vector3(sx * 0.28 * s, by + 1.04 * s, -0.22 * s)
		pl.set_meta("side", sx)
		body.add_child(pl)
		h._prism(pl, [Vector2(0.22, 0.44) * s, Vector2(0.24, -0.42) * s, Vector2(-0.18, -0.46) * s, Vector2(-0.20, 0.40) * s],
			0.10 * s, 0.06, OL, Vector3(sx * 0.16 * s, 0, 0), Vector3(0, sx * 18.0, 0))
		h._box(pl, HZ, Vector3(sx * 0.04 * s, 0, -0.06 * s), Vector3(0.05, 0.72, 0.03) * s)
		h.plates.append(pl)
	# 顶部工业光学测距转塔（crown：重钢传感器罩 + 黄铜法兰，取代粉紫尖刺花冠！）
	var crown := Node3D.new()
	crown.position = Vector3(0, by + 1.86 * s, 0.04 * s)
	body.add_child(crown)
	h._p(crown, ART.cyl(0.26 * s, 0.12 * s, 0.30 * s, 12), BR, Vector3.ZERO)
	h._p(crown, HS.cbox(Vector3(0.54, 0.24, 0.44) * s, 0.03 * s), DK, Vector3(0, 0.18 * s, 0))
	h._box(crown, HZ, Vector3(0, 0.31 * s, 0), Vector3(0.42, 0.03, 0.32) * s)
	Models._eye(h, crown, Vector3(0, 0.18 * s, -0.22 * s), 0.065 * s, CYAN)
	h.crown = crown
	# 3. 旋转八角重钢桁架电容冷却环（spinners：重钢箱梁圆环 + 8 组黄铜/橄榄灰电容箱，移除外刺尖针！）
	var halo := Node3D.new()
	halo.position = Vector3(0, by + 1.12 * s, 0.04 * s)
	body.add_child(halo)
	h._p(halo, ART.torus(0.86 * s, 0.98 * s, 16), DK, Vector3.ZERO, Vector3(78, 0, 0), Vector3(1, 1, 0.55))
	for k in 8:
		var a := TAU * k / 8.0
		var p_sh := Vector3(cos(a) * 0.92 * s, sin(a) * 0.20 * s, sin(a) * 0.92 * s)
		h._p(halo, HS.cbox(Vector3(0.20, 0.22, 0.18) * s, 0.02 * s), BR if k % 2 == 0 else SH2, p_sh, Vector3(0, -rad_to_deg(a), 0))
		h._box(halo, Models._mineral_glow(CYAN, 0.60), p_sh + Vector3(cos(a) * 0.10 * s, 0, sin(a) * 0.10 * s), Vector3(0.03, 0.12, 0.08) * s, Vector3(0, -rad_to_deg(a), 0))
	h.spinners.append([halo, Vector3.UP, 1.2, 6.5])
	# 四片金属桁框散热翼（wings：枪灰主梁框 + 极窄受控光学散热缝）
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			var w := Node3D.new()
			w.position = Vector3(sx * 0.42 * s, by + (1.18 - i * 0.28) * s, 0.18 * s)
			w.set_meta("side", sx)
			w.rotation_degrees = Vector3(0, sx * (22.0 + i * 20.0), 0)
			body.add_child(w)
			var wl := (1.16 - i * 0.22) * s
			h._servo(w, Vector3.ZERO, 0.09 * s)
			h._prism(w, [Vector2(0, 0), Vector2(0.24 * s, wl * 0.45), Vector2(0.06 * s, wl), Vector2(-0.20 * s, wl * 0.58)],
				0.075 * s, 0.05, SH2 if i == 0 else OL, Vector3.ZERO, Vector3(0, sx * 90.0, 0))
			h._bar(w, Vector3.ZERO, Vector3(sx * wl * 0.85, wl * 0.42, 0), 0.065 * s, 0.075 * s, ST)
			h._box(w, Models._mineral_glow(CYAN, 0.55), Vector3(sx * wl * 0.46, wl * 0.22, 0), Vector3(wl * 0.52, 0.032 * s, 0.082 * s), Vector3(0, 0, sx * 24.0))
			h.wings.append(w)
	# 双侧工业高能激光钻切炮臂（scythes：钢制炮管套筒 + 黄铜调焦箍 + 深黑光学膛口，取代发光冰锥！）与电容簇（crystals）
	for sx: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.68 * s, by + 0.56 * s, -0.36 * s)
		body.add_child(arm)
		h._servo(arm, Vector3.ZERO, 0.16 * s)
		var wrist := Vector3(sx * 0.22, -0.14, -0.48) * s
		h._bar(arm, Vector3.ZERO, wrist, 0.20 * s, 0.20 * s, SH2)
		h._hydraulic(arm, Vector3(0, 0.16 * s, 0.04 * s), wrist + Vector3(0, 0.12 * s, 0.08 * s), 0.038 * s, DK)
		h._p(arm, HS.cbox(Vector3(0.26, 0.26, 0.42) * s, 0.03 * s), DK, wrist + Vector3(0, -0.02 * s, -0.14 * s))
		h._p(arm, ART.cyl(0.10 * s, 0.62 * s, 0.12 * s, 12), ST, wrist + Vector3(0, -0.04 * s, -0.58 * s), Vector3(84, 0, 0))
		h._p(arm, ART.cyl(0.12 * s, 0.08 * s, 0.12 * s, 12), BR, wrist + Vector3(0, -0.03 * s, -0.44 * s), Vector3(84, 0, 0))
		h._p(arm, ART.cyl(0.075 * s, 0.06 * s, 0.075 * s, 12), BL, wrist + Vector3(0, -0.07 * s, -0.88 * s), Vector3(84, 0, 0), Vector3.ONE, false)
		h.scythes.append(arm)
		var cl := Node3D.new()
		cl.position = Vector3(sx * 0.76 * s, by + 0.36 * s, 0.42 * s)
		body.add_child(cl)
		for mi in Models._cluster(h, cl, Vector3.ZERO, 0.24 * s, PRISM, 4, 0.85):
			h.crystals.append(mi)
	# 4. 四条高挑反关节重钢步足
	var hips := [[0.58, -0.52, -36.0], [0.58, 0.54, 36.0]]
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			h._zleg(body, Vector3(sx * float(hips[i][0]) * s, by - 0.08 * s, float(hips[i][1]) * s), sx * float(hips[i][2]), sx,
				1.52 * s, by * 1.02, 0.14 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), i == 0)


# ---------------------------------------------------------------- 裂谷碎岩暴君 (gorge_tyrant)
static func build_gorge_tyrant(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.60, 0.45, 0.18))
	var SH2: Material = h._vmat_solid(Color(0.34, 0.35, 0.37))
	var DK: Material = h._vmat_solid(Color(0.12, 0.12, 0.13))
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.035))
	var ST: Material = h._steel()
	var BR: Material = h._brass()
	var RS: Material = h._rust_plate()
	var HZ: Material = h._hazard_yel()
	var SPARK := Color(1.0, 0.46, 0.12)
	var by := 1.12 * s
	# 1. 三阶露天矿山重机阶梯式车体 + 尾部穿孔防烫双排烟塔（深黑烟膛，移除发光橙环）
	h._p(body, HS.cbox(Vector3(1.58, 0.48, 1.84) * s, 0.05 * s), DK, Vector3(0, by, 0.08 * s))
	h._p(body, HS.cbox(Vector3(1.34, 0.38, 1.44) * s, 0.045 * s), SH, Vector3(0, by + 0.38 * s, 0.02 * s))
	h._p(body, HS.cbox(Vector3(0.98, 0.28, 0.98) * s, 0.04 * s), SH2, Vector3(0, by + 0.66 * s, -0.06 * s))
	h._panels(body, Vector3(0, by + 0.81 * s, -0.06 * s), Vector3(-90, 0, 0), 0.84 * s, 0.84 * s, 430, 6)
	# 尾部配重块警示条 + 双穿孔防烫烟囱
	h._box(body, HZ, Vector3(0, by + 0.16 * s, 0.99 * s), Vector3(1.24, 0.12, 0.04) * s)
	for sx: float in [-1.0, 1.0]:
		var tw := Vector3(sx * 0.46 * s, by + 0.72 * s, 0.64 * s)
		h._p(body, ART.cyl(0.21 * s, 0.62 * s, 0.25 * s, 14), RS, tw)
		h._p(body, ART.cyl(0.23 * s, 0.07 * s, 0.23 * s, 14), BR, tw + Vector3(0, 0.26 * s, 0))
		h._p(body, ART.cyl(0.16 * s, 0.18 * s, 0.16 * s, 12), BL, tw + Vector3(0, 0.26 * s, 0), Vector3.ZERO, Vector3.ONE, false)
	# 2. 背部双开防爆装甲舱门（plates）+ 聚变裂岩核心（core_mi）
	var core: MeshInstance3D = h._p(body, ART.sphere(0.24 * s, -1, 16), ART.emit(SPARK, 1.45), Vector3(0, by + 0.76 * s, -0.06 * s), Vector3.ZERO, Vector3(1, 0.82, 1), false)
	h.core_mi = core
	for sx: float in [-1.0, 1.0]:
		var pl := Node3D.new()
		pl.position = Vector3(sx * 0.34 * s, by + 0.82 * s, -0.06 * s)
		pl.set_meta("side", sx)
		body.add_child(pl)
		h._p(pl, HS.cbox(Vector3(0.42, 0.14, 0.76) * s, 0.03 * s), SH, Vector3(sx * 0.18 * s, 0, 0), Vector3(0, 0, sx * -18.0))
		h._box(pl, HZ, Vector3(sx * 0.02 * s, 0.07 * s, 0), Vector3(0.06, 0.03, 0.68) * s)
		h.plates.append(pl)
	# 3. 矿用碎岩撞锤头座 + 颚式破碎机（jaws）
	var head := Node3D.new()
	head.position = Vector3(0, by + 0.24 * s, -0.96 * s)
	body.add_child(head)
	h._p(head, HS.cbox(Vector3(0.94, 0.48, 0.56) * s, 0.045 * s), SH2, Vector3.ZERO)
	h._box(head, HZ, Vector3(0, 0.22 * s, -0.26 * s), Vector3(0.76, 0.06, 0.06) * s)
	h._jag(head, 0.26 * s, 0.86 * s, 0.12 * s, ST, Vector3(0, 0.14 * s, -0.24 * s), Vector3(-100, 0, 0), 4, -1.0, 0.0)
	for sx: float in [-1.0, 1.0]:
		Models._eye(h, head, Vector3(sx * 0.28 * s, 0.10 * s, -0.28 * s), 0.08 * s, SPARK)
		h._jag(head, 0.18 * s, 0.64 * s, 0.09 * s, Models._bone(), Vector3(sx * 0.36 * s, 0.08 * s, -0.20 * s), Vector3(-96, sx * -22.0, 0), 3, -1.0, sx * 0.06 * s)
		var j := Node3D.new()
		j.position = Vector3(sx * 0.28 * s, -0.16 * s, -0.24 * s)
		head.add_child(j)
		h._p(j, HS.cbox(Vector3(0.24, 0.22, 0.46) * s, 0.025 * s), DK, Vector3(0, 0, -0.18 * s))
		h._jag(j, 0.20 * s, 0.52 * s, 0.08 * s, Models._bone(), Vector3(0, 0, -0.32 * s), Vector3(-84, 0, sx * 18.0), 3, -1.0, 0.0)
		h.jaws.append(j)
	# 4. 双臂重型挖掘机液压折臂（scythes）+ 半罩警示黄护板 + 十二齿钨钢圆盘岩锯（spinners，零发光圈）
	for sx: float in [-1.0, 1.0]:
		var boom := Node3D.new()
		boom.position = Vector3(sx * 0.82 * s, by + 0.42 * s, -0.46 * s)
		boom.rotation_degrees = Vector3(0, sx * 14.0, 0)
		body.add_child(boom)
		h._servo(boom, Vector3.ZERO, 0.22 * s)
		var el := Vector3(sx * 0.34, 0.26, -0.48) * s
		var wrist := Vector3(sx * 0.28, -0.18, -0.98) * s
		h._limb(boom, Vector3.ZERO, el, 0.26 * s, 0.28 * s, SH, 0.82, 1.22)
		h._hydraulic(boom, Vector3(0, 0.24 * s, 0.06 * s), el + Vector3(0, 0.22 * s, 0.04 * s), 0.052 * s, DK)
		h._servo(boom, el, 0.20 * s)
		h._limb(boom, el, wrist, 0.24 * s, 0.26 * s, SH2, 0.82, 1.18)
		h._hydraulic(boom, el + Vector3(0, 0.20 * s, -0.02 * s), wrist + Vector3(0, 0.22 * s, 0.12 * s), 0.046 * s, DK)
		# 半月形工程警示黄防飞溅锯罩（固定在小臂末端，不随锯片转）
		h._shell(boom, HZ, wrist, 0.64 * s, 0.055 * s, -0.08 * s, 0.08 * s,
			[[0.0, 1.0, 1.0, 0.0], [0.5, 1.04, 1.04, 0.0], [1.0, 1.0, 1.0, 0.0]], Vector3(20, 90, 0), 86.0, 8)
		h._p(boom, ART.cyl(0.20 * s, 0.22 * s, 0.20 * s, 14), BR, wrist, Vector3(0, 0, 90))
		# 十二齿钨钢圆盘岩锯
		var saw := Node3D.new()
		saw.position = wrist
		boom.add_child(saw)
		h._p(saw, ART.cyl(0.58 * s, 0.065 * s, 0.58 * s, 24), ST, Vector3.ZERO, Vector3(0, 0, 90))
		h._p(saw, ART.cyl(0.32 * s, 0.095 * s, 0.32 * s, 16), DK, Vector3.ZERO, Vector3(0, 0, 90))
		for k in 12:
			var a := TAU * k / 12.0
			h._prism(saw, [Vector2(-0.06, 0.0) * s, Vector2(0.06, 0.0) * s, Vector2(0.02, 0.20) * s, Vector2(-0.03, 0.16) * s],
				0.075 * s, 0.01, Models._bone(), Vector3(0, sin(a) * 0.56 * s, cos(a) * 0.56 * s), Vector3(rad_to_deg(a), 90, 0))
		h.spinners.append([saw, Vector3.RIGHT, 4.0 * sx, 18.0 * sx])
		h.scythes.append(boom)
	# 5. 六条矿山重装液压柱腿
	var z_legs := [-0.58, 0.08, 0.74]
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			Bugs2._hleg(h, body, Vector3(sx * 0.78 * s, by - 0.14 * s, float(z_legs[i]) * s), sx * (-20.0 + i * 20.0), sx,
				s * 0.98, by - 0.12 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), 1.06, 1.1)


# ---------------------------------------------------------------- 深渊先驱魔像 (abyss_harbinger)
static func build_abyss_harbinger(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.27, 0.30, 0.35))
	var SH2: Material = h._vmat_solid(Color(0.41, 0.44, 0.48))
	var RS: Material = h._rust_plate()
	var DK: Material = h._vmat_solid(Color(0.13, 0.14, 0.17))
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.035))
	var ST: Material = h._steel()
	var BR: Material = h._brass()
	var HZ: Material = h._hazard_yel()
	var VOID := Color(0.36, 0.72, 1.0)
	var VIOLET := Color(0.48, 0.58, 0.98)
	var by := 1.04 * s
	# 1. 深潜耐压六足反应堆底盘 + 分节装甲动力脐带排热尾管（abdomen：黄铜喷嘴 + 深黑喷膛，移除粉红尖刺！）
	h._loft(body, HS.crect(1.0, 1.0, 0.28), [
		[-0.68 * s, Vector2(0.98, 0.42) * s, Vector2.ZERO],
		[-0.12 * s, Vector2(1.30, 0.52) * s, Vector2(0, 0.04 * s)],
		[0.52 * s, Vector2(1.18, 0.48) * s, Vector2(0, 0.04 * s)],
		[0.98 * s, Vector2(0.74, 0.34) * s, Vector2.ZERO],
	], DK, Vector3(0, by, 0.12 * s))
	Models._shell_layer(h, body, Vector3(0, by + 0.26 * s, 0.16 * s), Vector3(1.18, 0.54, 1.28) * s, SH, 4.0)
	h._panels(body, Vector3(0, by + 0.54 * s, 0.16 * s), Vector3(-90, 0, 0), 0.98 * s, 1.02 * s, 455, 6)
	var abd := Node3D.new()
	abd.position = Vector3(0, by + 0.14 * s, 0.74 * s)
	body.add_child(abd)
	Models._tube(h, abd, [Vector3.ZERO, Vector3(0, 0.32 * s, 0.46 * s), Vector3(0, 0.82 * s, 0.62 * s), Vector3(0, 1.24 * s, 0.46 * s)],
		[0.34 * s, 0.28 * s, 0.22 * s, 0.18 * s], SH2, 1.0, 1.0, Vector3.UP, 5, 12, true)
	h._p(abd, ART.cyl(0.20 * s, 0.22 * s, 0.22 * s, 12), RS, Vector3(0, 1.24 * s, 0.44 * s), Vector3(68, 0, 0))
	h._p(abd, ART.cyl(0.21 * s, 0.06 * s, 0.21 * s, 12), BR, Vector3(0, 1.26 * s, 0.34 * s), Vector3(68, 0, 0))
	h._p(abd, ART.cyl(0.14 * s, 0.06 * s, 0.14 * s, 12), BL, Vector3(0, 1.29 * s, 0.31 * s), Vector3(68, 0, 0), Vector3.ONE, false)
	h.abdomen = abd
	# 2. 敦实托卡马克约束反应塔躯干 + 双轴机加工钢铜陀螺环（spinners）+ 双开屏蔽门（plates）
	var torso := Node3D.new()
	torso.position = Vector3(0, by + 0.38 * s, -0.06 * s)
	body.add_child(torso)
	Models._tube(h, torso, [Vector3.ZERO, Vector3(0, 0.48 * s, -0.05 * s), Vector3(0, 0.98 * s, -0.10 * s), Vector3(0, 1.38 * s, -0.06 * s)],
		[0.56 * s, 0.48 * s, 0.40 * s, 0.32 * s], SH, 1.08, 0.88, Vector3.FORWARD, 5, 12, true)
	for k in 3:
		h._p(torso, ART.torus((0.48 - k * 0.05) * s, (0.55 - k * 0.05) * s, 16), SH2 if k % 2 == 0 else BR, Vector3(0, (0.24 + k * 0.38) * s, -0.06 * s), Vector3(84, 0, 0), Vector3(1.1, 1.0, 0.45))
	var core_pos := Vector3(0, by + 0.96 * s, -0.38 * s)
	var core: MeshInstance3D = h._p(body, ART.sphere(0.18 * s, -1, 16), ART.emit(VOID, 1.25), core_pos, Vector3.ZERO, Vector3.ONE, false)
	h.core_mi = core
	var gyro1 := Node3D.new()
	gyro1.position = core_pos
	body.add_child(gyro1)
	h._p(gyro1, ART.torus(0.28 * s, 0.34 * s, 18), BR, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.55))
	for k in 4:
		var a := TAU * k / 4.0
		h._box(gyro1, ST, Vector3(cos(a) * 0.31 * s, sin(a) * 0.31 * s, 0), Vector3(0.06, 0.06, 0.08) * s)
	h.spinners.append([gyro1, Vector3.UP, 2.2, 9.5])
	var gyro2 := Node3D.new()
	gyro2.position = core_pos
	body.add_child(gyro2)
	h._p(gyro2, ART.torus(0.38 * s, 0.44 * s, 18), ST, Vector3.ZERO, Vector3(0, 90, 0), Vector3(1, 1, 0.55))
	for k in 4:
		var a := TAU * k / 4.0
		h._box(gyro2, BR, Vector3(0, sin(a) * 0.41 * s, cos(a) * 0.41 * s), Vector3(0.07, 0.06, 0.06) * s)
	h.spinners.append([gyro2, Vector3.RIGHT, -1.8, -8.0])
	for sx: float in [-1.0, 1.0]:
		var pl := Node3D.new()
		pl.position = Vector3(sx * 0.28 * s, by + 0.96 * s, -0.32 * s)
		pl.set_meta("side", sx)
		body.add_child(pl)
		h._prism(pl, [Vector2(0.24, 0.40) * s, Vector2(0.20, -0.36) * s, Vector2(-0.20, -0.40) * s, Vector2(-0.24, 0.34) * s],
			0.10 * s, 0.08, SH2, Vector3(sx * 0.16 * s, 0, 0), Vector3(0, sx * 16.0, 0))
		h._box(pl, HZ, Vector3(sx * 0.04 * s, 0, -0.06 * s), Vector3(0.05, 0.64, 0.03) * s)
		h.plates.append(pl)
	# 3. 重型装甲观瞄头座 + 工业高频相控阵横梁（crown：取代粉红刺冠！）+ 双肩电磁轨道炮（turret）
	var head := Node3D.new()
	head.position = Vector3(0, by + 1.80 * s, -0.16 * s)
	body.add_child(head)
	h._prism(head, [Vector2(-0.28, 0.24) * s, Vector2(0.28, 0.24) * s, Vector2(0.34, -0.10) * s, Vector2(0, -0.30) * s, Vector2(-0.34, -0.10) * s],
		0.36 * s, 0.07, SH2, Vector3.ZERO)
	for sx: float in [-1.0, 1.0]:
		Models._eye(h, head, Vector3(sx * 0.15 * s, 0.04 * s, -0.19 * s), 0.062 * s, VOID)
		var j := Node3D.new()
		j.position = Vector3(sx * 0.12 * s, -0.16 * s, -0.16 * s)
		head.add_child(j)
		h._jag(j, 0.12 * s, 0.34 * s, 0.045 * s, Models._bone(), Vector3.ZERO, Vector3(-68, 0, sx * 18.0), 2, -1.0, 0.0)
		h.jaws.append(j)
	var crown := Node3D.new()
	crown.position = Vector3(0, 0.22 * s, 0.02 * s)
	head.add_child(crown)
	h._p(crown, HS.cbox(Vector3(0.68, 0.12, 0.18) * s, 0.02 * s), DK, Vector3(0, 0.08 * s, 0.02 * s))
	h._box(crown, HZ, Vector3(0, 0.15 * s, 0.02 * s), Vector3(0.54, 0.025, 0.12) * s)
	for sx: float in [-1.0, 1.0]:
		h._p(crown, ART.cyl(0.03 * s, 0.36 * s, 0.04 * s, 8), ST, Vector3(sx * 0.26 * s, 0.26 * s, 0.04 * s), Vector3(-10, 0, sx * -8.0))
		h._p(crown, ART.cyl(0.048 * s, 0.06 * s, 0.048 * s, 8), BR, Vector3(sx * 0.24 * s, 0.10 * s, 0.02 * s))
	h.crown = crown
	# 双肩重型电磁轨道炮塔（turret：黄铜加速线圈 + 开槽制退器 + 深黑炮口）
	var tur := Node3D.new()
	tur.position = Vector3(0, by + 1.46 * s, 0.02 * s)
	body.add_child(tur)
	for sx: float in [-1.0, 1.0]:
		var gx := sx * 0.54 * s
		h._p(tur, HS.cbox(Vector3(0.28, 0.28, 0.58) * s, 0.03 * s), SH2, Vector3(gx, 0.12 * s, -0.10 * s))
		h._bar(tur, Vector3(gx, 0.18 * s, -0.20 * s), Vector3(gx, 0.18 * s, -1.02 * s), 0.12 * s, 0.06 * s, ST)
		h._bar(tur, Vector3(gx, 0.08 * s, -0.20 * s), Vector3(gx, 0.08 * s, -1.02 * s), 0.12 * s, 0.06 * s, ST)
		for ck in 4:
			h._box(tur, BR, Vector3(gx, 0.13 * s, (-0.32 - ck * 0.17) * s), Vector3(0.16, 0.17, 0.06) * s)
		h._p(tur, HS.cbox(Vector3(0.18, 0.18, 0.20) * s, 0.02 * s), DK, Vector3(gx, 0.13 * s, -1.08 * s))
		h._p(tur, ART.cyl(0.055 * s, 0.16 * s, 0.055 * s, 10), BL, Vector3(gx, 0.13 * s, -1.12 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	h.turret = tur
	# 4. 六片重钢散热鳍翼（wings：钛灰装甲框 + 防锈底漆衬片 + 极窄受控冷等离子槽，移除刺眼粉红灯条！）
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			var w := Node3D.new()
			w.position = Vector3(sx * 0.34 * s, by + (1.36 - i * 0.26) * s, 0.22 * s)
			w.set_meta("side", sx)
			w.rotation_degrees = Vector3(0, sx * (18.0 + i * 18.0), sx * (12.0 - i * 14.0))
			body.add_child(w)
			var wl := (1.14 - i * 0.18) * s
			h._servo(w, Vector3.ZERO, 0.085 * s)
			h._prism(w, [Vector2(0, 0), Vector2(0.22 * s, wl * 0.44), Vector2(0.06 * s, wl), Vector2(-0.20 * s, wl * 0.58), Vector2(-0.24 * s, 0.14 * s)],
				0.07 * s, 0.05, SH2 if i % 2 == 0 else RS, Vector3.ZERO, Vector3(0, sx * 90.0, 0))
			h._bar(w, Vector3.ZERO, Vector3(sx * wl * 0.86, wl * 0.40, 0), 0.06 * s, 0.075 * s, ST)
			h._box(w, Models._mineral_glow(VOID, 0.52), Vector3(sx * wl * 0.46, wl * 0.20, 0), Vector3(wl * 0.48, 0.028 * s, 0.078 * s), Vector3(0, 0, sx * 22.0))
			h.wings.append(w)
	for sx: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.46 * s, by + 1.16 * s, -0.18 * s)
		arm.rotation_degrees = Vector3(0, sx * 16.0, 0)
		body.add_child(arm)
		h._servo(arm, Vector3.ZERO, 0.16 * s)
		var el := Vector3(sx * 0.34, -0.34, -0.44) * s
		h._limb(arm, Vector3.ZERO, el, 0.18 * s, 0.20 * s, SH2, 0.75, 1.2)
		h._hydraulic(arm, Vector3(0, 0.16 * s, 0), el + Vector3(0, 0.12 * s, 0.06 * s), 0.036 * s, DK)
		h._servo(arm, el, 0.14 * s)
		h._bar(arm, el, el + Vector3(sx * 0.06 * s, -0.46 * s, -0.76 * s), 0.08 * s, 0.12 * s, DK)
		h._jag(arm, 0.34 * s, 1.32 * s, 0.085 * s, Models._bone(), el + Vector3(sx * 0.04 * s, -0.04 * s, -0.06 * s), Vector3(-62, sx * 10.0, 0), 5, -1.0, sx * 0.12 * s)
		h._box(arm, Models._mineral_glow(VOID, 0.65), el + Vector3(sx * 0.05 * s, -0.28 * s, -0.44 * s), Vector3(0.016 * s, 0.028 * s, 0.72 * s), Vector3(-28, 0, 0))
		h.scythes.append(arm)
		var cl := Node3D.new()
		cl.position = Vector3(sx * 0.56 * s, by + 0.48 * s, 0.26 * s)
		body.add_child(cl)
		for mi in Models._cluster(h, cl, Vector3.ZERO, 0.22 * s, VIOLET, 3, 0.82):
			h.crystals.append(mi)
	# 5. 六条深潜重钢步足
	var z_legs := [-0.36, 0.12, 0.60]
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			h._zleg(body, Vector3(sx * 0.48 * s, by - 0.06 * s, float(z_legs[i]) * s), sx * (-28.0 + i * 26.0), sx,
				(1.46 - i * 0.08) * s, by * 1.02, 0.13 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), i < 2)
