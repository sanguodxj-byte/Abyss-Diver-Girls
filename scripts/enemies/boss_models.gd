extends RefCounted
## Boss 的程序化建模。沿用虫族建模基元与配色（暗甲壳 + 骨白刃尖 + 紫/琥珀发光组织），体量放大到机甲的 2~3 倍，
## 并用三种完全不同的主轮廓区分：横铺的巢母、双柱巨足的王虫、直立多臂的母皇。

const ART = preload("res://scripts/art.gd")
const Models = preload("res://scripts/enemies/models.gd")
const BONE := Color(0.66, 0.67, 0.7)


static func decal_size(kind: String) -> float:
	match kind:
		"broodmother": return 7.6
		"king_beetle": return 9.0
		"abyss_queen": return 8.4
		_: return 7.6


static func build(h, body: Node3D, kind: String, s: float) -> void:
	match kind:
		"broodmother": _brood(h, body, s)
		"king_beetle": _king(h, body, s)
		"abyss_queen": _queen(h, body, s)
		_: _brood(h, body, s)


# ---------------------------------------------------------------- 赤湖巢母
## 横铺的巢母：宽大的腹节压在八条反关节蛛腿上，背部三枚胀满的卵囊随呼吸鼓动，
## 前端一对孵化臂，头小眼多，甲壳边缘长着紫晶。重心极低，轮廓像一座会爬的菌丘。
static func _brood(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_solid(Color(0.44, 0.28, 0.36))
	var SH2: Material = h._vmat_solid(Color(0.58, 0.4, 0.47))
	var DK: Material = h._vmat_solid(Color(0.13, 0.08, 0.11))
	var EGG := Color(0.86, 0.2, 0.38)
	var by := 1.02 * s
	# 腹节：扁椭圆 + 两层叠压壳
	h._ell(body, SH, Vector3(0, by, 0.34 * s), Vector3(2.1, 1.3, 2.4) * s)
	Models._shell_layer(h, body, Vector3(0, by + 0.3 * s, 0.3 * s), Vector3(1.7, 0.9, 1.9) * s, SH2, -4.0)
	Models._shell_layer(h, body, Vector3(0, by + 0.34 * s, 0.76 * s), Vector3(1.2, 0.7, 1.1) * s, SH, 8.0)
	h._panels(body, Vector3(0, by + 0.62 * s, 0.24 * s), Vector3(-90, 0, 0), 1.5 * s, 1.6 * s, 201, 7)
	# 胸节：向前的楔形
	h._prism(body, [Vector2(0.5, 0.34) * s, Vector2(0.66, -0.12) * s, Vector2(0.34, -0.6) * s, Vector2(-0.34, -0.6) * s, Vector2(-0.66, -0.12) * s, Vector2(-0.5, 0.34) * s],
		0.5 * s, 0.06, SH2, Vector3(0, by + 0.02 * s, -0.62 * s), Vector3(90, 0, 0))
	h._panels(body, Vector3(0, by + 0.32 * s, -0.62 * s), Vector3(-90, 0, 0), 1.0 * s, 0.9 * s, 202, 6)
	# 背部卵囊：三枚，中间最大；囊壁上一圈凸起的卵粒
	var sacs_pos := [Vector3(0, by + 0.66 * s, 0.34 * s), Vector3(0.78 * s, by + 0.4 * s, 0.86 * s), Vector3(-0.76 * s, by + 0.42 * s, 0.82 * s)]
	var radii := [0.42, 0.28, 0.26]
	for i in 3:
		var mi: MeshInstance3D = Models._sac(h, body, sacs_pos[i], radii[i] * s, EGG)
		h.sacs.append(mi)
		for k in 7:
			var a := TAU * k / 7.0 + i
			var off := Vector3(cos(a) * radii[i] * 0.9, sin(a * 1.3) * radii[i] * 0.45, sin(a) * radii[i] * 0.9) * s
			h._p(body, ART.sphere(radii[i] * 0.22 * s, -1, 8), ART.emit(Color(0.98, 0.5, 0.66), 0.9), sacs_pos[i] + off, Vector3.ZERO, Vector3.ONE, false)
	# 头：小、四只眼、一对颚
	var head := Node3D.new()
	head.position = Vector3(0, by + 0.22 * s, -1.0 * s)
	body.add_child(head)
	h._ell(head, DK, Vector3.ZERO, Vector3(0.42, 0.4, 0.46) * s)
	for sx: float in [-1.0, 1.0]:
		h._p(head, ART.sphere(0.09 * s, -1, 10), ART.emit(Color(1.0, 0.5, 0.2), 2.4), Vector3(sx * 0.12 * s, 0.06 * s, -0.18 * s), Vector3.ZERO, Vector3.ONE, false)
		h._p(head, ART.sphere(0.055 * s, -1, 8), ART.emit(Color(1.0, 0.65, 0.3), 1.6), Vector3(sx * 0.22 * s, 0.13 * s, -0.1 * s), Vector3.ZERO, Vector3.ONE, false)
		var j := Node3D.new()
		j.position = Vector3(sx * 0.1 * s, -0.12 * s, -0.18 * s)
		head.add_child(j)
		h._jag(j, 0.14 * s, 0.4 * s, 0.05 * s, Models._bone(), Vector3.ZERO, Vector3(0, 0, sx * 18.0), 2, -1.0, 0.0)
		h.jaws.append(j)
	# 头冠：一圈向前弯的骨刺
	for k in 5:
		var a := lerpf(-0.9, 0.9, k / 4.0)
		h._spike(head, Vector3(a * 0.2 * s, 0.3 * s, 0.02 * s), Vector3(a * 0.6, 0.85, 0.4), (0.46 - absf(a) * 0.14) * s, 0.05 * s, Vector3(0, 0, 0.06))
	# 前肢孵化臂：两段折臂 + 内弯长钩
	for sx: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.6 * s, by + 0.1 * s, -0.84 * s)
		arm.rotation_degrees = Vector3(0, sx * 20.0, 0)
		body.add_child(arm)
		h._servo(arm, Vector3.ZERO, 0.18 * s)
		h._bar(arm, Vector3.ZERO, Vector3(sx * 0.34, 0.18, -0.56) * s, 0.2 * s, 0.22 * s, SH2)
		h._servo(arm, Vector3(sx * 0.34, 0.18, -0.56) * s, 0.15 * s)
		h._jag(arm, 0.34 * s, 1.3 * s, 0.11 * s, Models._bone(), Vector3(sx * 0.4, 0.18 * s, -0.62 * s), Vector3(-74, sx * 10.0, 0), 4, -1.0, sx * 0.12 * s)
		h._p(arm, ART.sphere(0.05 * s, -1, 8), ART.emit(EGG, 0.8), Vector3(sx * 0.35, 0.24 * s, -0.58 * s), Vector3.ZERO, Vector3.ONE, false)
		h.scythes.append(arm)
	# 八条反关节蛛腿
	var hips := [[0.44, -0.6, -34.0], [0.5, -0.2, -12.0], [0.5, 0.24, 14.0], [0.4, 0.66, 34.0]]
	for i in 4:
		for sx: float in [-1.0, 1.0]:
			h._zleg(body, Vector3(sx * float(hips[i][0]) * s, by - 0.1 * s, float(hips[i][1]) * s), sx * float(hips[i][2]), sx,
				(1.3 - i * 0.07) * s, by * 1.02, (0.14 - i * 0.01) * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), i < 2)
	# 甲壳边缘的紫晶
	for sx: float in [-1.0, 1.0]:
		var edge := Node3D.new()
		edge.position = Vector3(sx * 0.95 * s, by + 0.1 * s, 0.2 * s)
		body.add_child(edge)
		for mi in Models._cluster(h, edge, Vector3.ZERO, 0.3 * s, Color(0.75, 0.45, 1.0), 5, 0.9):
			h.crystals.append(mi)


# ---------------------------------------------------------------- 裂谷铁甲王虫
## 双柱巨足的王虫：两条比机甲还高的柱状前足撑在身前，重甲头冠三根撞角，
## 背甲可以从中间裂开，中间嵌着一枚发光晶核（弱点），肩部两枚撞刺。
static func _king(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_solid(Color(0.34, 0.32, 0.29))
	var SH2: Material = h._vmat_solid(Color(0.46, 0.43, 0.38))
	var DK: Material = h._vmat_solid(Color(0.08, 0.08, 0.08))
	var PL: Material = h._vmat_matte(Color(0.56, 0.54, 0.5))
	var CORE := Color(1.0, 0.6, 0.16)
	var by := 1.1 * s
	# 躯干：低宽六棱底盘 + 三层叠甲
	h._prism(body, [Vector2(-0.7, -0.76) * s, Vector2(0.7, -0.76) * s, Vector2(0.88, 0.0) * s, Vector2(0.72, 0.86) * s, Vector2(-0.72, 0.86) * s, Vector2(-0.88, 0.0) * s],
		0.56 * s, 0.06, DK, Vector3(0, by, 0), Vector3(90, 0, 0))
	h._prism(body, [Vector2(-0.56, -0.6) * s, Vector2(0.56, -0.6) * s, Vector2(0.7, 0.02) * s, Vector2(0.58, 0.72) * s, Vector2(-0.58, 0.72) * s, Vector2(-0.7, 0.02) * s],
		0.24 * s, 0.08, SH, Vector3(0, by + 0.34 * s, 0), Vector3(90, 0, 0))
	h._panels(body, Vector3(0, by + 0.5 * s, -0.06 * s), Vector3(-90, 0, 0), 1.1 * s, 1.0 * s, 211, 8,
		[h._vmat_solid(Color(0.18, 0.17, 0.16)), h._vmat_matte(Color(0.38, 0.36, 0.33)), h._vmat_matte(Color(0.52, 0.49, 0.45)), SH])
	# 背甲：两片可以从中间裂开的仓盖（plates），中间是晶核
	for sx: float in [-1.0, 1.0]:
		var pl := Node3D.new()
		pl.position = Vector3(sx * 0.34 * s, by + 0.56 * s, 0.24 * s)
		pl.set_meta("side", sx)
		body.add_child(pl)
		h._prism(pl, [Vector2(0.3, 0.24) * s, Vector2(0.34, -0.3) * s, Vector2(-0.3, -0.34) * s, Vector2(-0.32, 0.2) * s],
			0.13 * s, 0.1, SH2, Vector3(sx * 0.34 * s, 0, 0), Vector3(-24, 0, sx * 22.0))
		h._box(pl, h._steel(), Vector3(sx * 0.32 * s, 0.08 * s, -0.03 * s), Vector3(0.05, 0.07, 0.07) * s)
		h.plates.append(pl)
	var core: MeshInstance3D = h._p(body, ART.sphere(0.26 * s, -1, 18), ART.emit(CORE, 1.1), Vector3(0, by + 0.56 * s, 0.24 * s), Vector3.ZERO, Vector3(1, 0.8, 1), false)
	h.core_mi = core
	for k in 3:
		h._p(body, ART.torus((0.42 + k * 0.06) * s, (0.45 + k * 0.06) * s, 18), ART.emit(CORE, 0.9), Vector3(0, by + 0.56 * s, 0.24 * s),
			Vector3(70 - k * 20.0, k * 40.0, 0), Vector3(1, 1, 0.25), false)
	# 头冠：厚重前额板 + 三根撞角 + 口部发光
	var head := Node3D.new()
	head.position = Vector3(0, by + 0.26 * s, -0.9 * s)
	body.add_child(head)
	h._prism(head, [Vector2(0.5, 0.26) * s, Vector2(0.4, -0.26) * s, Vector2(0, -0.4) * s, Vector2(-0.4, -0.26) * s, Vector2(-0.5, 0.26) * s],
		0.3 * s, 0.08, DK, Vector3.ZERO)
	h._prism(head, [Vector2(0.38, 0.34) * s, Vector2(0.32, -0.1) * s, Vector2(-0.32, -0.1) * s, Vector2(-0.38, 0.34) * s],
		0.34 * s, 0.1, SH2, Vector3(0, 0.06 * s, -0.04 * s))
	h._spike(head, Vector3(0, 0.04 * s, -0.26 * s), Vector3(0, 0.18, -1.0), 0.96 * s, 0.12 * s, Vector3(0, 0.14, 0))
	for sx: float in [-1.0, 1.0]:
		h._spike(head, Vector3(sx * 0.32 * s, 0.04 * s, -0.18 * s), Vector3(sx * 0.7, 0.3, -0.7), 0.74 * s, 0.09 * s, Vector3(sx * 0.12, 0, 0))
		h._p(head, ART.sphere(0.075 * s, -1, 10), ART.emit(Color(1.0, 0.55, 0.18), 2.6), Vector3(sx * 0.22 * s, 0.1 * s, -0.3 * s), Vector3.ZERO, Vector3.ONE, false)
		h._box(head, ART.emit(Color(1.0, 0.6, 0.2), 1.2), Vector3(sx * 0.13 * s, 0.08 * s, -0.32 * s), Vector3(0.07, 0.035, 0.012) * s)
	h._p(head, ART.cyl(0.13 * s, 0.08 * s, 0.17 * s, 8), ART.emit(Color(1.0, 0.6, 0.2), 1.0), Vector3(0, -0.02 * s, -0.2 * s), Vector3(-90, 0, 0), Vector3.ONE, false)
	# 肩部撞刺 + 侧腹发光缝
	for sx: float in [-1.0, 1.0]:
		h._spike(body, Vector3(sx * 0.68 * s, by + 0.34 * s, -0.36 * s), Vector3(sx * 0.95, 0.35, -0.4), 0.82 * s, 0.14 * s, Vector3(sx * 0.18, 0, 0))
		h._box(body, ART.emit(Color(1.0, 0.6, 0.2), 1.5), Vector3(sx * 0.75 * s, by + 0.12 * s, 0.2 * s), Vector3(0.014, 0.05, 0.5) * s)
		h._box(body, PL, Vector3(sx * 0.74 * s, by + 0.26 * s, 0.44 * s), Vector3(0.03, 0.3, 0.5) * s, Vector3(0, 0, sx * 6.0))
	# 双柱巨足
	for sx: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(sx * 0.6 * s, by - 0.2 * s, -0.5 * s)
		hip.rotation_degrees = Vector3(0, sx * -12.0, 0)
		body.add_child(hip)
		h._servo(hip, Vector3.ZERO, 0.3 * s)
		var knee := Vector3(sx * 0.3 * s, 0.3 * s, 0)
		var foot := Vector3(sx * 0.46 * s, -by + 0.02, -0.08 * s)
		h._bar(hip, Vector3.ZERO, knee, 0.4 * s, 0.46 * s, SH2)
		h._bar(hip, Vector3(0, 0.22 * s, 0), knee + Vector3(0, 0.22 * s, 0), 0.52 * s, 0.1 * s, PL)
		h._servo(hip, knee, 0.26 * s)
		h._bar(hip, knee, foot, 0.38 * s, 0.4 * s, SH)
		h._p(hip, ART.cyl(0.34 * s, 0.2 * s, 0.46 * s, 6), DK, foot + Vector3(0, 0.1 * s, 0))
		h._p(hip, ART.torus(0.3 * s, 0.34 * s, 16), ART.emit(Color(1.0, 0.55, 0.18), 1.2), foot + Vector3(0, 0.16 * s, 0), Vector3(90, 0, 0), Vector3(1, 1, 0.3), false)
		hip.set_meta("side", sx)
		hip.set_meta("phase", 0.0 if sx > 0 else PI)
		hip.set_meta("base_y", hip.rotation.y)
		h.legs.append(hip)
	# 后四足
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			h._pleg(body, Vector3(sx * 0.68 * s, by - 0.14 * s, (0.2 + i * 0.46) * s), sx * (18.0 + i * 14.0), sx, s * 0.92, by - 0.12 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0))


# ---------------------------------------------------------------- 深渊母皇
## 直立的多臂母体：骨盆之上立起一段躯干，胸口嵌晶核（三阶段完全暴露），
## 背后四片晶翼张开，肩后两挺晶刺，前方两把利爪，尾部产卵管向后卷起，四条支撑足。
## 这是全部敌人里唯一的「人形」轮廓，抬头就能认出终章。
static func _queen(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_solid(Color(0.4, 0.26, 0.5))
	var SH2: Material = h._vmat_solid(Color(0.52, 0.36, 0.62))
	var DK: Material = h._vmat_solid(Color(0.1, 0.06, 0.12))
	var CORE := Color(0.7, 0.3, 1.0)
	var by := 0.98 * s
	# 骨盆
	h._ell(body, SH, Vector3(0, by, 0.24 * s), Vector3(1.3, 1.0, 1.4) * s)
	Models._shell_layer(h, body, Vector3(0, by + 0.22 * s, 0.2 * s), Vector3(1.0, 0.62, 1.1) * s, SH2, 6.0)
	# 躯干：从骨盆向上收细的一段
	var up := Node3D.new()
	up.position = Vector3(0, by + 0.36 * s, 0.02 * s)
	body.add_child(up)
	Models._tube(h, up, [Vector3(0, 0, 0), Vector3(0, 0.52 * s, -0.06 * s), Vector3(0, 1.04 * s, -0.14 * s), Vector3(0, 1.5 * s, -0.1 * s)],
		[0.5 * s, 0.42 * s, 0.34 * s, 0.24 * s], SH2, 1.0, 0.82, Vector3.FORWARD, 5, 12, false)
	for k in 3:
		h._p(up, ART.torus((0.42 - k * 0.06) * s, (0.45 - k * 0.06) * s, 16), DK, Vector3(0, (0.24 + k * 0.36) * s, 0), Vector3(90, 0, 0), Vector3(1, 1, 0.5), false)
	# 胸口晶核：嵌在胸甲裂口里
	h._prism(up, [Vector2(-0.26, 0.66) * s, Vector2(0.26, 0.66) * s, Vector2(0.32, 0.12) * s, Vector2(0, -0.12) * s, Vector2(-0.32, 0.12) * s],
		0.12 * s, 0.1, DK, Vector3(0, 0.54 * s, -0.34 * s))
	var core: MeshInstance3D = h._p(up, ART.sphere(0.17 * s, -1, 18), ART.emit(CORE, 0.9), Vector3(0, 0.56 * s, -0.38 * s), Vector3.ZERO, Vector3(1, 1.2, 0.7), false)
	h.core_mi = core
	for k in 2:
		h._p(up, ART.torus((0.3 + k * 0.06) * s, (0.33 + k * 0.06) * s, 18), ART.emit(CORE, 1.0), Vector3(0, 0.56 * s, -0.38 * s),
			Vector3(80, k * 50.0, 0), Vector3(1, 1, 0.25), false)
	# 胸甲：两片向两侧分开的护板
	for sx: float in [-1.0, 1.0]:
		var pl := Node3D.new()
		pl.position = Vector3(sx * 0.22 * s, by + 0.92 * s, -0.26 * s)
		pl.rotation_degrees = Vector3(0, sx * 14.0, sx * 6.0)
		pl.set_meta("side", sx)
		body.add_child(pl)
		h._prism(pl, [Vector2(0.22, 0.34) * s, Vector2(0.18, -0.3) * s, Vector2(-0.2, -0.36) * s, Vector2(-0.22, 0.3) * s],
			0.09 * s, 0.12, SH2, Vector3(sx * 0.14 * s, 0, 0))
		h.plates.append(pl)
	# 头部：窄长面甲 + 四只眼 + 骨冠
	var head := Node3D.new()
	head.position = Vector3(0, by + 1.9 * s, -0.2 * s)
	body.add_child(head)
	h._prism(head, [Vector2(0.18, 0.22) * s, Vector2(0.22, -0.12) * s, Vector2(0.09, -0.3) * s, Vector2(-0.09, -0.3) * s, Vector2(-0.22, -0.12) * s, Vector2(-0.18, 0.22) * s],
		0.3 * s, 0.1, DK, Vector3.ZERO)
	for sx: float in [-1.0, 1.0]:
		h._p(head, ART.sphere(0.05 * s, -1, 10), ART.emit(Color(1.0, 0.35, 0.75), 2.2), Vector3(sx * 0.1 * s, 0.0, -0.16 * s), Vector3.ZERO, Vector3(1, 0.6, 0.6), false)
		h._p(head, ART.sphere(0.035 * s, -1, 8), ART.emit(Color(1.0, 0.55, 0.8), 1.6), Vector3(sx * 0.07 * s, 0.1 * s, -0.14 * s), Vector3.ZERO, Vector3.ONE, false)
	var crown := Node3D.new()
	crown.position = Vector3(0, 0.18 * s, 0.02 * s)
	head.add_child(crown)
	for k in 5:
		var a := lerpf(-1.0, 1.0, k / 4.0)
		h._spike(crown, Vector3(a * 0.12 * s, 0, 0), Vector3(a * 0.8, 1.0, 0.45), (0.62 - absf(a) * 0.22) * s, 0.055 * s, Vector3(0, 0, a * 0.12))
	h.crown = crown
	# 四片晶翼
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			var w := Node3D.new()
			w.position = Vector3(sx * 0.26 * s, by + 1.24 * s, 0.28 * s)
			w.set_meta("side", sx)
			w.rotation_degrees = Vector3(0, sx * (20.0 + i * 22.0), 0)
			body.add_child(w)
			var len: float = (1.15 - i * 0.28) * s
			h._prism(w, [Vector2(0.0, 0.0), Vector2(0.16 * s, len * 0.42), Vector2(0.03 * s, len), Vector2(-0.18 * s, len * 0.58), Vector2(-0.24 * s, 0.12 * s)],
				0.06 * s, 0.05, ART.emit(Color(0.44, 0.2, 0.72), 0.3), Vector3.ZERO, Vector3(0, sx * 90.0, 0))
			h._prism(w, [Vector2(0.02 * s, len * 0.16), Vector2(0.1 * s, len * 0.52), Vector2(-0.04 * s, len * 0.86), Vector2(-0.1 * s, len * 0.5)],
				0.07 * s, 0.08, ART.emit(Color(0.62, 0.34, 0.9), 0.5), Vector3(0, 0, -0.02 * s), Vector3(0, sx * 90.0, 0))
			h.wings.append(w)
	# 肩后晶刺
	for sx: float in [-1.0, 1.0]:
		h._spike(body, Vector3(sx * 0.34 * s, by + 1.34 * s, 0.12 * s), Vector3(sx * 0.45, 1.0, -0.4), 1.3 * s, 0.1 * s, Vector3(sx * 0.14, 0, -0.12))
	# 前爪：两段折臂 + 长刃
	for sx: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.4 * s, by + 1.2 * s, -0.14 * s)
		arm.rotation_degrees = Vector3(0, sx * 16.0, 0)
		body.add_child(arm)
		h._servo(arm, Vector3.ZERO, 0.14 * s)
		h._bar(arm, Vector3.ZERO, Vector3(sx * 0.3, -0.34, -0.38) * s, 0.14 * s, 0.16 * s, SH2)
		h._servo(arm, Vector3(sx * 0.3, -0.34, -0.38) * s, 0.1 * s)
		h._jag(arm, 0.26 * s, 1.1 * s, 0.07 * s, Models._bone(), Vector3(sx * 0.34, -0.38 * s, -0.44 * s), Vector3(-64, sx * 8.0, 0), 4, -1.0, sx * 0.08 * s)
		h.scythes.append(arm)
	# 尾部产卵管
	var abd := Node3D.new()
	abd.position = Vector3(0, by - 0.04 * s, 0.58 * s)
	body.add_child(abd)
	Models._tube(h, abd, [Vector3(0, 0, 0), Vector3(0, 0.2 * s, 0.56 * s), Vector3(0, 0.7 * s, 0.96 * s), Vector3(0, 1.24 * s, 1.02 * s)],
		[0.34 * s, 0.3 * s, 0.2 * s, 0.11 * s], SH2, 1.0, 1.0, Vector3.UP, 5, 10, false)
	h._p(abd, ART.cyl(0.0, 0.56 * s, 0.1 * s, 8), ART.emit(CORE, 1.6), Vector3(0, 1.38 * s, 1.0 * s), Vector3(18, 0, 0))
	h._p(abd, ART.torus(0.18 * s, 0.21 * s, 14), ART.emit(CORE, 1.0), Vector3(0, 0.8 * s, 0.98 * s), Vector3(30, 0, 0), Vector3(1, 1, 0.3), false)
	h.abdomen = abd
	# 四条支撑足
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			h._zleg(body, Vector3(sx * 0.36 * s, by - 0.04 * s, (-0.16 + i * 0.44) * s), sx * (-24.0 + i * 26.0), sx,
				(1.4 - i * 0.14) * s, by * 1.02, 0.12 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), true)
	for sx: float in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(sx * 0.5 * s, by + 1.3 * s, 0.0)
		body.add_child(shoulder)
		for mi in Models._cluster(h, shoulder, Vector3.ZERO, 0.22 * s, Color(0.78, 0.5, 1.0), 4, 0.8):
			h.crystals.append(mi)
