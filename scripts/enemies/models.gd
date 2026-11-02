extends RefCounted
## 新虫种的程序化建模。每个函数在 host（scripts\enemies\enemy.gd 的实例）上调用基础类的建模基元：
##   _ell/_prism/_box 基本体与倒角棱柱、_panels 面板分缝、_servo 伺服关节、_sweep 扫掠管、_jag 锯齿刃。
## 造型语言沿用虫族既有的一套：暗甲壳 + 面板分缝 + 骨白刃尖 + 紫/琥珀发光组织，并给每只一个能远远认出的主轮廓
## （竖高的猎手、圆鼓的爆巢、宽扁的晶壳、前尖的钻头、方硬的改装体、十字的飞虫、伞形的支援体、斜炮的炮手、横向的重甲）。
## 每个种类只往 host 的动画部件表里登记（legs / wings / sacs / crystals / plates / jaws / scythes / abdomen / crown / turret / core_mi）。

const ART = preload("res://scripts/art.gd")
const Bugs2 = preload("res://scripts/bugs2.gd")
const BONE := Color(0.66, 0.67, 0.7)
const C_CH := Color(0.34, 0.35, 0.38)     ## 主甲壳（提亮到在战场上不糊成黑块）
const C_CH2 := Color(0.5, 0.51, 0.55)     ## 亮一档甲壳
const C_GLOW := Color(0.62, 0.22, 1.0)    ## 发光


## 影子贴片的尺寸：按每只的外廓给，飞行种小一些
static func decal_size(kind: String) -> float:
	match kind:
		"mantis": return 2.4
		"bomber": return 2.6
		"crystal_bug": return 3.8
		"burrower": return 2.8
		"mech_beetle": return 3.6
		"wasp": return 1.8
		"shielder": return 2.4
		"mortar": return 3.0
		"ironjaw": return 4.0
		"aegis": return 3.4
		"lancer": return 2.0
		"overseer": return 2.8
		"ripper": return 2.4
		"brood": return 5.2
		"colossus": return 6.4
		_: return 2.8


static func build(h, body: Node3D, kind: String, s: float) -> void:
	match kind:
		"mantis": _mantis(h, body, s)
		"bomber": _bomber(h, body, s)
		"crystal_bug": _crystal(h, body, s)
		"burrower": _burrower(h, body, s)
		"mech_beetle": _mech_beetle(h, body, s)
		"wasp": _wasp(h, body, s)
		"shielder": _shielder(h, body, s)
		"mortar": _mortar(h, body, s)
		"ironjaw": _ironjaw(h, body, s)
		"aegis": Bugs2.build_aegis(h, body, s)
		"lancer": Bugs2.build_lancer(h, body, s)
		"overseer": Bugs2.build_overseer(h, body, s)
		"ripper": Bugs2.build_ripper(h, body, s)
		"brood": Bugs2.build_brood(h, body, s)
		"colossus": Bugs2.build_colossus(h, body, s)
		_: _mantis(h, body, s)


# ---------------------------------------------------------------- 共用件
static var _bm: StandardMaterial3D
## 骨白刃面：高光、微金属，专门给颚、镰、足尖用，深色甲壳上的亮色读数全靠它
static func _bone() -> StandardMaterial3D:
	if _bm == null:
		_bm = StandardMaterial3D.new()
		_bm.albedo_color = BONE
		_bm.metallic = 0.55
		_bm.roughness = 0.24
		_bm.clearcoat_enabled = true
		_bm.clearcoat = 0.9
		_bm.clearcoat_roughness = 0.12
		_bm.rim_enabled = true
		_bm.rim = 0.35
	return _bm


## 扫掠管：本文件的构件统一用材质上色，c0/c1 走封装的默认色，材质由 m 参数指定
static func _tube(h, parent: Node3D, pts: Array, radii: Array, m, rx := 1.0, ry := 1.0, up := Vector3.UP, steps := 5, rad := 10, hard := false) -> MeshInstance3D:
	return h._sweep(parent, pts, radii, C_CH, BONE, rx, ry, up, steps, rad, m, 0.55, hard)


## 复眼：暗色镜框 + 发光透镜
static func _eye(h, parent: Node3D, pos: Vector3, r: float, c: Color) -> void:
	h._p(parent, ART.cyl(r, r * 0.55, r, 12), h._vmat_solid(Color(0.04, 0.04, 0.05)), pos, Vector3(90, 0, 0), Vector3.ONE, false)
	h._p(parent, ART.cyl(r * 0.72, r * 0.2, r * 0.72, 12), ART.emit(c, 2.6), pos + Vector3(0, 0, -r * 0.36), Vector3(90, 0, 0), Vector3.ONE, false)


## 晶体：根部一块暗色基座 + 一根有棱的晶柱，五面以上才有晶体感
static func _shard(h, parent: Node3D, base: Vector3, dir: Vector3, length: float, r: float, c: Color, glow := 1.3) -> MeshInstance3D:
	var d := dir.normalized()
	var mi: MeshInstance3D = h._p(parent, ART.cyl(0.0, length, r, 6), ART.emit(c, glow), base + d * length * 0.5, Vector3.ZERO)
	var y := d
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x, y, z), base + d * length * 0.5)
	mi.set_meta("base_scale", Vector3.ONE)
	h._p(parent, ART.cyl(r * 1.15, r * 0.5, r * 1.3, 6), h._vmat_solid(Color(0.12, 0.09, 0.16)), base + d * r * 0.2, Vector3.ZERO, Vector3.ONE, false)
	return mi


## 一群晶体：中间高、四周矮，方向略向外张
static func _cluster(h, parent: Node3D, center: Vector3, scale: float, c: Color, n := 7, k := 1.0) -> Array:
	var out: Array = []
	var seeds := [[0.0, 0.0, 1.0], [0.5, -0.3, 0.66], [-0.5, -0.24, 0.62], [0.46, 0.38, 0.5], [-0.44, 0.4, 0.54], [0.06, -0.56, 0.44], [-0.04, 0.58, 0.4]]
	for i in mini(n, seeds.size()):
		var q: Array = seeds[i]
		var base: Vector3 = center + Vector3(q[0], 0.0, q[1]) * scale
		var mi := _shard(h, parent, base, Vector3(float(q[0]) * 0.5, 1.0, float(q[1]) * 0.45), float(q[2]) * scale * k, 0.16 * scale, c, 1.3)
		out.append(mi)
	return out


## 鼓胀的囊：外膜 + 一圈贴合表面的暗色筋 + 顶端爆裂口
static func _sac(h, parent: Node3D, pos: Vector3, r: float, c: Color) -> MeshInstance3D:
	var mi: MeshInstance3D = h._ell(parent, ART.emit(c, 0.85), pos, Vector3(r * 2.0, r * 1.7, r * 2.05))
	for i in 4:
		var a := TAU * i / 4.0 + 0.35
		var ring := Node3D.new()
		ring.position = pos
		ring.rotation_degrees = Vector3(90.0, a * 57.2958, 0)
		parent.add_child(ring)
		h._p(ring, ART.torus(r * 0.86, r * 0.93, 16), h._vmat_matte(Color(c.r * 0.3, c.g * 0.26, c.b * 0.2)), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.35), false)
	return mi


## 拱形甲层：一层压一层的椭圆薄壳，用来堆出甲虫的分段背甲（比 _band 更贴体）
static func _shell_layer(h, parent: Node3D, pos: Vector3, size: Vector3, m, tilt := 0.0) -> MeshInstance3D:
	var mi: MeshInstance3D = h._ell(parent, m, pos, size, Vector3(tilt, 0, 0))
	mi.set_meta("shell", true)
	return mi


# ---------------------------------------------------------------- 镰爪虫
## 竖高的猎手：窄而长的胸甲、前伸双镰、四足反关节、头顶细角刺。
## 轮廓刻意做成「竖」的，和跳虫的扁方舱、酸液虫的楔形胸甲都不撞。
static func _mantis(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_solid(Color(0.36, 0.33, 0.18))
	var SH2: Material = h._vmat_solid(Color(0.52, 0.48, 0.27))
	var DK: Material = h._vmat_solid(Color(0.12, 0.11, 0.08))
	var GL := ART.emit(Color(1.0, 0.62, 0.2), 1.6)
	var by := 0.9 * s
	# 胸：窄长的斜切棱柱（俯视呈箭头）
	h._prism(body, [Vector2(0.26, 0.36) * s, Vector2(0.34, 0.0) * s, Vector2(0.26, -0.4) * s, Vector2(-0.26, -0.4) * s, Vector2(-0.34, 0.0) * s, Vector2(-0.26, 0.36) * s],
		0.32 * s, 0.06, SH, Vector3(0, by, 0.0), Vector3(90, 0, 0))
	h._prism(body, [Vector2(0.19, 0.32) * s, Vector2(0.25, 0.0) * s, Vector2(0.19, -0.34) * s, Vector2(-0.19, -0.34) * s, Vector2(-0.25, 0.0) * s, Vector2(-0.19, 0.32) * s],
		0.14 * s, 0.1, SH2, Vector3(0, by + 0.2 * s, 0.0), Vector3(90, 0, 0))
	h._panels(body, Vector3(0, by + 0.28 * s, 0.0), Vector3(-90, 0, 0), 0.5 * s, 0.7 * s, 61, 5)
	# 颈 + 楔形头
	var head := Node3D.new()
	head.position = Vector3(0, by + 0.14 * s, -0.46 * s)
	body.add_child(head)
	_tube(h, head, [Vector3.ZERO, Vector3(0, 0.1 * s, -0.18 * s), Vector3(0, 0.14 * s, -0.34 * s)], [0.12 * s, 0.1 * s, 0.07 * s], SH2, 1.0, 1.0, Vector3.UP, 4, 8, true)
	h._prism(head, [Vector2(0.17, 0.08) * s, Vector2(0.12, -0.18) * s, Vector2(-0.12, -0.18) * s, Vector2(-0.17, 0.08) * s], 0.26 * s, 0.08, SH2, Vector3(0, 0.16 * s, -0.36 * s), Vector3(-16, 0, 0))
	for sx: float in [-1.0, 1.0]:
		_eye(h, head, Vector3(sx * 0.1 * s, 0.18 * s, -0.45 * s), 0.055 * s, Color(1.0, 0.55, 0.15))
		h._spike(head, Vector3(sx * 0.1 * s, 0.24 * s, -0.3 * s), Vector3(sx * 0.35, 1.0, 0.55), 0.62 * s, 0.04 * s, Vector3(sx * 0.1, 0, 0.18))
	# 双镰：肩轴承 + 三段折臂 + 长刃，折叠时贴在胸前
	for sx: float in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(sx * 0.3 * s, by + 0.06 * s, -0.16 * s)
		sh.rotation_degrees = Vector3(0, sx * 16.0, 0)
		body.add_child(sh)
		h._servo(sh, Vector3.ZERO, 0.11 * s)
		h._bar(sh, Vector3.ZERO, Vector3(sx * 0.24, 0.1, -0.34) * s, 0.11 * s, 0.13 * s, SH)
		h._servo(sh, Vector3(sx * 0.24, 0.1, -0.34) * s, 0.08 * s)
		h._bar(sh, Vector3(sx * 0.24, 0.1, -0.34) * s, Vector3(sx * 0.32, 0.18, -0.7) * s, 0.085 * s, 0.1 * s, SH2)
		h._jag(sh, 0.22 * s, 1.1 * s, 0.05 * s, _bone(), Vector3(sx * 0.32, 0.2 * s, -0.76 * s), Vector3(-58, sx * 12.0, 0), 4, -1.0, sx * 0.1 * s)
		h._p(sh, ART.cyl(0.022 * s, 0.24 * s, 0.022 * s, 6), GL, Vector3(sx * 0.25, 0.12 * s, -0.4 * s), Vector3(52, 0, 0), Vector3.ONE, false)
		h.scythes.append(sh)
	# 背脊细刺
	for i in 3:
		h._spike(body, Vector3(0, by + 0.24 * s, (0.1 - i * 0.2) * s), Vector3(0, 1.0, 0.4), (0.3 - i * 0.06) * s, 0.032 * s)
	# 四足：前腿高抬反关节，后腿撑在后面
	for sx: float in [-1.0, 1.0]:
		h._zleg(body, Vector3(sx * 0.24 * s, by - 0.16 * s, -0.22 * s), sx * -28.0, sx, 0.82 * s, by * 1.15, 0.085 * s, PI if sx > 0 else 0.0, true)
		h._zleg(body, Vector3(sx * 0.26 * s, by - 0.16 * s, 0.26 * s), sx * 30.0, sx, 0.7 * s, by * 1.05, 0.075 * s, 0.0 if sx > 0 else PI, false)


# ---------------------------------------------------------------- 爆浆虫
## 圆鼓的爆巢：低矮桶身上压一枚橙黄毒囊，囊上箍着暗色筋，四条短足、面前一对小颚。
## 轮廓是「一颗会走的囊」，远看就知道别让它贴上来。
static func _bomber(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_solid(Color(0.46, 0.34, 0.15))
	var SH2: Material = h._vmat_solid(Color(0.6, 0.46, 0.21))
	var DK: Material = h._vmat_solid(Color(0.14, 0.1, 0.06))
	var by := 0.52 * s
	# 桶身：两层叠压的椭圆壳
	h._ell(body, SH, Vector3(0, by, 0.02 * s), Vector3(0.98, 0.72, 1.14) * s)
	_shell_layer(h, body, Vector3(0, by + 0.16 * s, -0.02 * s), Vector3(0.86, 0.5, 1.0) * s, SH2)
	h._panels(body, Vector3(0, by + 0.36 * s, 0.0), Vector3(-90, 0, 0), 0.44 * s, 0.5 * s, 71, 3)
	# 毒囊：主囊 + 顶端爆裂口
	var sac := _sac(h, body, Vector3(0, by + 0.58 * s, 0.08 * s), 0.4 * s, Color(1.0, 0.56, 0.12))
	h.sacs.append(sac)
	h._p(body, ART.cyl(0.16 * s, 0.06 * s, 0.22 * s, 12), ART.emit(Color(1.0, 0.82, 0.32), 2.2), Vector3(0, by + 0.94 * s, 0.08 * s), Vector3.ZERO, Vector3.ONE, false)
	# 侧腹的警示腺：两道琥珀色发光缝
	for sx: float in [-1.0, 1.0]:
		h._box(body, ART.emit(Color(1.0, 0.6, 0.15), 1.2), Vector3(sx * 0.49 * s, by + 0.06 * s, 0.0), Vector3(0.01, 0.05, 0.5) * s)
	# 面前的口器：框 + 两片小颚 + 两只小眼
	var head := Node3D.new()
	head.position = Vector3(0, by - 0.06 * s, -0.48 * s)
	body.add_child(head)
	h._prism(head, [Vector2(0.22, 0.14) * s, Vector2(0.18, -0.14) * s, Vector2(-0.18, -0.14) * s, Vector2(-0.22, 0.14) * s], 0.24 * s, 0.1, DK, Vector3.ZERO, Vector3(-12, 0, 0))
	for sx: float in [-1.0, 1.0]:
		var j := Node3D.new()
		j.position = Vector3(sx * 0.1 * s, -0.06 * s, -0.12 * s)
		head.add_child(j)
		h._jag(j, 0.1 * s, 0.24 * s, 0.05 * s, _bone(), Vector3.ZERO, Vector3(0, 0, sx * 22.0), 2, -1.0, 0.0)
		h.jaws.append(j)
		_eye(h, head, Vector3(sx * 0.12 * s, 0.09 * s, -0.13 * s), 0.038 * s, Color(1.0, 0.5, 0.12))
	# 四条短足：够长，能从甲壳下伸出来
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			h._zleg(body, Vector3(sx * 0.34 * s, by - 0.16 * s, (-0.18 + i * 0.4) * s), sx * (-20.0 + i * 40.0), sx, 0.52 * s, by, 0.065 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), false)


# ---------------------------------------------------------------- 晶背虫
## 宽扁的晶壳：一层低矮的椭圆甲，背上插满紫晶簇，正面一块斜置的棱面晶镜（正面硬得能把能量束弹开），四条粗腿。
static func _crystal(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_solid(Color(0.4, 0.3, 0.54))
	var SH2: Material = h._vmat_solid(Color(0.52, 0.42, 0.64))
	var DK: Material = h._vmat_solid(Color(0.12, 0.09, 0.16))
	var CR := Color(0.74, 0.48, 1.0)
	var by := 0.55 * s
	# 主甲：扁椭圆 + 上盖
	h._ell(body, SH, Vector3(0, by + 0.06 * s, 0.04 * s), Vector3(1.36, 0.62, 1.5) * s)
	_shell_layer(h, body, Vector3(0, by + 0.28 * s, 0.06 * s), Vector3(1.06, 0.44, 1.16) * s, SH2)
	h._panels(body, Vector3(0, by + 0.42 * s, 0.02 * s), Vector3(-90, 0, 0), 0.8 * s, 0.9 * s, 81, 6)
	for sx: float in [-1.0, 1.0]:
		for k in 2:
			h._prism(body, [Vector2(-0.3, 0.18) * s, Vector2(0.3, 0.14) * s, Vector2(0.26, -0.2) * s, Vector2(-0.28, -0.16) * s],
				0.06 * s, 0.12, SH, Vector3(sx * 0.62 * s, by + 0.02 * s, (-0.28 + k * 0.52) * s), Vector3(0, 90 * sx, sx * -6.0))
	# 背面晶簇
	var cluster := Node3D.new()
	cluster.position = Vector3(0, by + 0.4 * s, 0.02 * s)
	body.add_child(cluster)
	for mi in _cluster(h, cluster, Vector3.ZERO, 0.36 * s, CR, 7, 1.0):
		h.crystals.append(mi)
	# 正面晶镜：斜置的六边形晶体板，边缘暗框，中心透出紫光
	var front := Node3D.new()
	front.position = Vector3(0, by + 0.14 * s, -0.6 * s)
	front.rotation_degrees = Vector3(-22, 0, 0)
	body.add_child(front)
	h._prism(front, [Vector2(0.3, 0.22) * s, Vector2(0.38, 0.0) * s, Vector2(0.26, -0.26) * s, Vector2(-0.26, -0.26) * s, Vector2(-0.38, 0.0) * s, Vector2(-0.3, 0.22) * s],
		0.06 * s, 0.1, DK, Vector3.ZERO)
	h._prism(front, [Vector2(0.24, 0.17) * s, Vector2(0.31, 0.0) * s, Vector2(0.2, -0.2) * s, Vector2(-0.2, -0.2) * s, Vector2(-0.31, 0.0) * s, Vector2(-0.24, 0.17) * s],
		0.1 * s, 0.16, ART.emit(CR, 0.9), Vector3(0, 0, -0.02 * s))
	for sx: float in [-1.0, 1.0]:
		_eye(h, body, Vector3(sx * 0.19 * s, by + 0.06 * s, -0.66 * s), 0.05 * s, Color(0.85, 0.5, 1.0))
	# 四条活塞粗腿
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			h._pleg(body, Vector3(sx * 0.6 * s, by - 0.06 * s, (-0.34 + i * 0.62) * s), sx * (-22.0 + i * 26.0), sx, s, by - 0.02 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0))


# ---------------------------------------------------------------- 钻地虫
## 前尖的钻头虫：一整根带螺旋棱的钻锥占满前半身，后面接三节覆土甲，六条短挖腿，尾部两个排砂口。
## 钻地时整只沉进土里只留一路扬尘，破土时这根钻头是第一个露出来的东西。
static func _burrower(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_solid(Color(0.4, 0.32, 0.21))
	var SH2: Material = h._vmat_solid(Color(0.52, 0.42, 0.28))
	var DK: Material = h._vmat_solid(Color(0.11, 0.09, 0.06))
	var ST: Material = h._steel()
	var by := 0.55 * s
	# 躯干：三节渐小的甲壳
	h._ell(body, SH, Vector3(0, by, 0.2 * s), Vector3(0.9, 0.74, 0.86) * s)
	_shell_layer(h, body, Vector3(0, by + 0.02 * s, 0.42 * s), Vector3(0.72, 0.58, 0.62) * s, SH2)
	_shell_layer(h, body, Vector3(0, by - 0.02 * s, 0.62 * s), Vector3(0.5, 0.42, 0.46) * s, SH)
	h._panels(body, Vector3(0, by + 0.32 * s, 0.24 * s), Vector3(-90, 0, 0), 0.6 * s, 0.5 * s, 91, 5)
	# 钻锥：三段收尖的锥体，锥面上绕两道螺旋棱
	var drill := Node3D.new()
	drill.position = Vector3(0, by - 0.02 * s, -0.44 * s)
	body.add_child(drill)
	h._p(drill, ART.cyl(0.07 * s, 0.22 * s, 0.34 * s, 12), ST, Vector3(0, 0, -0.11 * s), Vector3(-90, 0, 0))
	h._p(drill, ART.cyl(0.03 * s, 0.2 * s, 0.2 * s, 10), ST, Vector3(0, 0, -0.32 * s), Vector3(-90, 0, 0))
	h._p(drill, ART.cyl(0.0, 0.2 * s, 0.09 * s, 8), _bone(), Vector3(0, 0, -0.5 * s), Vector3(-90, 0, 0))
	for k in 2:
		for i in 12:
			var u := float(i) / 11.0
			var a := k * PI + u * 2.4
			var r: float = (0.33 - u * 0.26) * s
			h._box(drill, _bone(), Vector3(cos(a) * r, sin(a) * r, (-0.03 - u * 0.42) * s), Vector3(0.09, 0.04, 0.07) * s, Vector3(0, 0, rad_to_deg(a)))
	for k in 3:
		var r2: float = (0.3 - k * 0.09) * s
		h._p(drill, ART.torus(r2, r2 * 1.12, 14), DK, Vector3(0, 0, (-0.05 - k * 0.14) * s), Vector3(90, 0, 0), Vector3(1, 1, 0.35), false)
	h._p(drill, ART.torus(0.36 * s, 0.4 * s, 16), ART.emit(Color(1.0, 0.55, 0.2), 1.2), Vector3(0, 0, 0.04 * s), Vector3(90, 0, 0), Vector3(1, 1, 0.3), false)
	# 尾部排砂口 + 尾刺
	for sx: float in [-1.0, 1.0]:
		h._p(body, ART.cyl(0.08 * s, 0.28 * s, 0.11 * s, 8), DK, Vector3(sx * 0.17 * s, by + 0.02 * s, 0.72 * s), Vector3(-72, 0, 0))
		h._p(body, ART.cyl(0.055 * s, 0.02 * s, 0.055 * s, 8), ART.emit(Color(1.0, 0.62, 0.3), 1.2), Vector3(sx * 0.17 * s, by + 0.02 * s, 0.85 * s), Vector3(-72, 0, 0), Vector3.ONE, false)
	h._spike(body, Vector3(0, by + 0.1 * s, 0.66 * s), Vector3(0, 0.5, 1.0), 0.34 * s, 0.06 * s)
	# 六条短挖腿：足端一片扁平的前铲
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			var hip := Node3D.new()
			hip.position = Vector3(sx * 0.34 * s, by - 0.14 * s, (-0.3 + i * 0.32) * s)
			hip.rotation_degrees = Vector3(0, sx * (-24.0 + i * 24.0), 0)
			body.add_child(hip)
			var knee := Vector3(sx * 0.22 * s, 0.08 * s, 0)
			var foot := Vector3(sx * 0.36 * s, -by + 0.02, 0.05 * s)
			h._servo(hip, Vector3.ZERO, 0.075 * s)
			h._bar(hip, Vector3.ZERO, knee, 0.12 * s, 0.14 * s, SH2)
			h._servo(hip, knee, 0.065 * s)
			h._bar(hip, knee, foot, 0.1 * s, 0.09 * s, SH)
			h._prism(hip, [Vector2(0, 0) * s, Vector2(0.18, 0.05) * s, Vector2(0.26, -0.02) * s, Vector2(0.12, -0.16) * s, Vector2(-0.09, -0.13) * s],
				0.05 * s, 0.15, DK, foot + Vector3(0, -0.02, -0.06 * s), Vector3(0, 90, 0))
			hip.set_meta("side", sx)
			hip.set_meta("phase", float(i % 2) * PI + (PI if sx > 0 else 0.0))
			hip.set_meta("base_y", hip.rotation.y)
			h.legs.append(hip)


# ---------------------------------------------------------------- 改装机甲虫
## 方硬的改装体：甲虫底盘上铆了一层旧世界钢板，背面立起干扰天线，侧腹黄黑警示条。
## 一眼能看出「这不是野生的」——形状里混进了人类的金属件。
static func _mech_beetle(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_solid(Color(0.36, 0.36, 0.33))
	var SH2: Material = h._vmat_solid(Color(0.47, 0.47, 0.44))
	var DK: Material = h._vmat_solid(Color(0.11, 0.11, 0.11))
	var PL: Material = h._vmat_matte(Color(0.56, 0.57, 0.6))
	var by := 0.66 * s
	# 底盘 + 上层甲板
	h._prism(body, [Vector2(-0.5, -0.6) * s, Vector2(0.5, -0.6) * s, Vector2(0.66, 0.0) * s, Vector2(0.52, 0.7) * s, Vector2(-0.52, 0.7) * s, Vector2(-0.66, 0.0) * s],
		0.36 * s, 0.06, DK, Vector3(0, by, 0), Vector3(90, 0, 0))
	h._prism(body, [Vector2(-0.38, -0.42) * s, Vector2(0.38, -0.42) * s, Vector2(0.48, 0.04) * s, Vector2(0.4, 0.58) * s, Vector2(-0.4, 0.58) * s, Vector2(-0.48, 0.04) * s],
		0.18 * s, 0.08, SH, Vector3(0, by + 0.26 * s, 0), Vector3(90, 0, 0))
	h._panels(body, Vector3(0, by + 0.36 * s, 0.02 * s), Vector3(-90, 0, 0), 0.66 * s, 0.72 * s, 101, 6,
		[h._vmat_solid(Color(0.2, 0.2, 0.21)), h._vmat_matte(Color(0.44, 0.44, 0.46)), h._vmat_matte(Color(0.56, 0.56, 0.58)), SH])
	# 正面焊上的护板：比底盘小一圈，螺栓四角，中缝一道警示灯
	var front := Node3D.new()
	front.position = Vector3(0, by + 0.04 * s, -0.56 * s)
	front.rotation_degrees = Vector3(-20, 0, 0)
	body.add_child(front)
	h._prism(front, [Vector2(0.34, 0.2) * s, Vector2(0.3, -0.18) * s, Vector2(0, -0.26) * s, Vector2(-0.3, -0.18) * s, Vector2(-0.34, 0.2) * s],
		0.09 * s, 0.07, PL, Vector3.ZERO)
	h._prism(front, [Vector2(0.24, 0.13) * s, Vector2(0.21, -0.12) * s, Vector2(0, -0.18) * s, Vector2(-0.21, -0.12) * s, Vector2(-0.24, 0.13) * s],
		0.11 * s, 0.1, SH2, Vector3(0, 0, -0.03 * s))
	for k in 4:
		h._box(front, h._steel(), Vector3((-0.24 + k * 0.16) * s, 0.15 * s, -0.08 * s), Vector3(0.032, 0.032, 0.02) * s)
	h._box(front, ART.emit(Color(1.0, 0.55, 0.15), 1.4), Vector3(0, -0.02 * s, -0.1 * s), Vector3(0.06, 0.16, 0.012) * s)
	for sx: float in [-1.0, 1.0]:
		_eye(h, front, Vector3(sx * 0.18 * s, 0.1 * s, -0.11 * s), 0.04 * s, Color(1.0, 0.6, 0.2))
	# 背部干扰天线：底座 + 立柱 + 斜置天线盘（从正前方也看得见）
	var mast := Node3D.new()
	mast.position = Vector3(0, by + 0.44 * s, 0.22 * s)
	body.add_child(mast)
	h._p(mast, ART.cyl(0.09 * s, 0.16 * s, 0.12 * s, 8), h._steel(), Vector3(0, 0.08 * s, 0), Vector3.ZERO)
	h._p(mast, ART.cyl(0.05 * s, 0.44 * s, 0.06 * s, 8), PL, Vector3(0, 0.36 * s, 0), Vector3.ZERO)
	var dish := Node3D.new()
	dish.position = Vector3(0, 0.58 * s, 0)
	dish.rotation_degrees = Vector3(-32, 0, 0)
	mast.add_child(dish)
	h._p(dish, ART.cyl(0.3 * s, 0.06 * s, 0.1 * s, 18), PL, Vector3.ZERO)
	h._p(dish, ART.torus(0.23 * s, 0.27 * s, 18), ART.emit(Color(0.8, 0.55, 1.0), 1.8), Vector3(0, 0.03 * s, 0), Vector3.ZERO, Vector3.ONE, false)
	h._p(dish, ART.cyl(0.025 * s, 0.24 * s, 0.02 * s, 6), h._steel(), Vector3(0, 0.1 * s, 0), Vector3.ZERO)
	h.turret = dish
	# 侧腹警示条 + 铆钉排 + 一道紫色电源线
	for sx: float in [-1.0, 1.0]:
		for k in 4:
			h._box(body, h._vmat_matte(Color(0.78, 0.64, 0.15)) if k % 2 == 0 else DK, Vector3(sx * 0.63 * s, by - 0.02 * s, (-0.16 + k * 0.11) * s), Vector3(0.012, 0.1, 0.11) * s)
		h._box(body, ART.emit(Color(0.85, 0.6, 1.0), 1.2), Vector3(sx * 0.65 * s, by + 0.12 * s, 0.22 * s), Vector3(0.008, 0.022, 0.34) * s)
		for k in 3:
			h._box(body, h._steel(), Vector3(sx * 0.64 * s, by + 0.2 * s, (-0.1 + k * 0.16) * s), Vector3(0.012, 0.03, 0.03) * s)
	# 四条机械腿
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			h._mleg(body, Vector3(sx * 0.56 * s, by - 0.08 * s, (-0.28 + i * 0.5) * s), sx * (-20.0 + i * 40.0), sx, 1.15 * s, by * 1.25, 0.13 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0))


# ---------------------------------------------------------------- 啸翅虫
## 十字形飞虫：细腰 + 纺锤腹 + 尾针，两对半透明膜翼，六条细腿收在身下，复眼很大。
## 悬停时翅膀一直在动；俯冲时收拢成一条线，拉升时才重新张开。
static var _membrane: StandardMaterial3D
static func _wing_mat() -> StandardMaterial3D:
	if _membrane == null:
		_membrane = StandardMaterial3D.new()
		_membrane.albedo_color = Color(0.86, 0.88, 0.76, 0.34)
		_membrane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_membrane.cull_mode = BaseMaterial3D.CULL_DISABLED
		_membrane.roughness = 0.22
		_membrane.metallic = 0.12
		_membrane.rim_enabled = true
		_membrane.rim = 0.8
		_membrane.emission_enabled = true
		_membrane.emission = Color(0.55, 0.62, 0.45)
		_membrane.emission_energy_multiplier = 0.25
	return _membrane


static func _wasp(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_solid(Color(0.56, 0.46, 0.2))
	var SH2: Material = h._vmat_solid(Color(0.68, 0.56, 0.26))
	var DK: Material = h._vmat_solid(Color(0.14, 0.11, 0.06))
	var by := 0.72 * s
	# 胸节
	h._ell(body, SH, Vector3(0, by, -0.06 * s), Vector3(0.5, 0.46, 0.56) * s)
	h._panels(body, Vector3(0, by + 0.2 * s, -0.06 * s), Vector3(-90, 0, 0), 0.34 * s, 0.34 * s, 111, 3)
	# 腹节：三节渐细 + 尾针
	var abd := Node3D.new()
	abd.position = Vector3(0, by - 0.02 * s, 0.18 * s)
	body.add_child(abd)
	h._ell(abd, SH2, Vector3(0, 0, 0.16 * s), Vector3(0.4, 0.38, 0.5) * s)
	h._ell(abd, SH, Vector3(0, -0.02 * s, 0.46 * s), Vector3(0.26, 0.24, 0.32) * s)
	h._p(abd, ART.cyl(0.0, 0.4 * s, 0.07 * s, 6), _bone(), Vector3(0, -0.03 * s, 0.72 * s), Vector3(-96, 0, 0))
	h._p(abd, ART.torus(0.1 * s, 0.12 * s, 12), ART.emit(Color(1.0, 0.6, 0.15), 1.2), Vector3(0, 0, 0.32 * s), Vector3(90, 0, 0), Vector3(1, 1, 0.4), false)
	_shell_layer(h, abd, Vector3(0, 0.06 * s, 0.3 * s), Vector3(0.3, 0.2, 0.3) * s, h._vmat_matte(Color(0.2, 0.16, 0.08)))
	h.abdomen = abd
	# 头：一对大复眼 + 上颚
	var head := Node3D.new()
	head.position = Vector3(0, by + 0.05 * s, -0.34 * s)
	body.add_child(head)
	h._ell(head, DK, Vector3(0, 0, -0.04 * s), Vector3(0.34, 0.32, 0.34) * s)
	for sx: float in [-1.0, 1.0]:
		h._ell(head, ART.emit(Color(0.95, 0.6, 0.2), 0.9), Vector3(sx * 0.13 * s, 0.03 * s, -0.1 * s), Vector3(0.2, 0.22, 0.17) * s)
		h._box(head, h._vmat_solid(Color(0.16, 0.05, 0.02)), Vector3(sx * 0.13 * s, 0.03 * s, -0.18 * s), Vector3(0.02, 0.12, 0.06) * s, Vector3(0, 0, sx * 20.0))
		var j := Node3D.new()
		j.position = Vector3(sx * 0.08 * s, -0.09 * s, -0.14 * s)
		head.add_child(j)
		h._jag(j, 0.07 * s, 0.2 * s, 0.02 * s, _bone(), Vector3.ZERO, Vector3(0, 0, 60 * sx), 1, -1.0, 0.0)
		h.jaws.append(j)
	# 两对膜翼
	for sx: float in [-1.0, 1.0]:
		for pair in 2:
			var w := Node3D.new()
			w.position = Vector3(sx * 0.16 * s, by + 0.2 * s, (-0.16 + pair * 0.2) * s)
			w.rotation_degrees = Vector3(-90, sx * (26.0 + pair * 16.0), 0)
			w.set_meta("side", sx)
			body.add_child(w)
			var len: float = (0.92 - pair * 0.24) * s
			var wid: float = (0.3 - pair * 0.07) * s
			h._prism(w, [Vector2(0.0, 0.0), Vector2(wid * 0.5, len * 0.4), Vector2(wid * 0.18, len), Vector2(-wid * 0.36, len * 0.62), Vector2(-wid * 0.5, 0.1)],
				0.018 * s, 0.02, _wing_mat(), Vector3.ZERO, Vector3(0, sx * 90.0, 0))
			h.wings.append(w)
	# 六条细腿，收在身下
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			var hip := Node3D.new()
			hip.position = Vector3(sx * 0.13 * s, by - 0.18 * s, (-0.16 + i * 0.16) * s)
			hip.rotation_degrees = Vector3(0, sx * (-16.0 + i * 16.0), 0)
			body.add_child(hip)
			var knee := Vector3(sx * 0.13 * s, -0.04 * s, 0)
			var tip := Vector3(sx * 0.22 * s, -0.24 * s, 0.08 * s)
			h._bar(hip, Vector3.ZERO, knee, 0.045 * s, 0.05 * s, DK)
			_tube(h, hip, [knee, knee.lerp(tip, 0.6), tip], [0.04 * s, 0.026 * s, 0.0], SH, 0.8, 1.0, Vector3.FORWARD, 1, 4, true)
			hip.set_meta("side", sx)
			hip.set_meta("phase", float(i % 2) * PI + (PI if sx > 0 else 0.0))
			hip.set_meta("base_y", hip.rotation.y)
			h.legs.append(hip)
	h.sac = h._p(abd, ART.sphere(0.13 * s, -1, 10), ART.emit(Color(1.0, 0.55, 0.15), 0.7), Vector3(0, 0.14 * s, 0.44 * s), Vector3.ZERO, Vector3.ONE, false)


# ---------------------------------------------------------------- 盾脉虫
## 伞形支援体：头顶八瓣伞盖（蓄力时张开），伞下悬一枚发光核心，四条细腿。
## 轮廓是「一把撑开的伞」——虫群里最好认的支援位。
static func _shielder(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_solid(Color(0.32, 0.45, 0.38))
	var SH2: Material = h._vmat_solid(Color(0.44, 0.6, 0.5))
	var DK: Material = h._vmat_solid(Color(0.08, 0.12, 0.1))
	var GR := Color(0.28, 0.95, 0.62)
	var by := 0.62 * s
	# 核心舱
	h._ell(body, SH, Vector3(0, by, 0), Vector3(0.56, 0.52, 0.6) * s)
	h._panels(body, Vector3(0, by + 0.03 * s, 0), Vector3(-90, 0, 0), 0.36 * s, 0.38 * s, 121, 3)
	# 伞盖：八片向外撑开的棱瓣 + 伞缘一圈发光脉
	var crown := Node3D.new()
	crown.position = Vector3(0, by + 0.22 * s, 0)
	body.add_child(crown)
	for k in 8:
		var a := TAU * k / 8.0
		var petal := Node3D.new()
		petal.rotation_degrees = Vector3(0, a * 57.2958, 0)
		crown.add_child(petal)
		h._prism(petal, [Vector2(0, 0) * s, Vector2(0.16, 0.3) * s, Vector2(0.07, 0.44) * s, Vector2(-0.09, 0.42) * s, Vector2(-0.17, 0.28) * s],
			0.04 * s, 0.12, SH2, Vector3(0.3 * s, 0, 0), Vector3(-68, 0, 0))
		h._p(petal, ART.sphere(0.05 * s, -1, 8), ART.emit(GR, 1.6), Vector3(0.56 * s, 0.05 * s, 0), Vector3.ZERO, Vector3.ONE, false)
		h._p(petal, ART.cyl(0.012 * s, 0.36 * s, 0.012 * s, 5), ART.emit(GR, 1.0), Vector3(0.28 * s, 0.06 * s, 0), Vector3(0, 0, -68), Vector3.ONE, false)
	h._p(crown, ART.torus(0.58 * s, 0.62 * s, 24), ART.emit(GR, 1.1), Vector3(0, 0.06 * s, 0), Vector3(90, 0, 0), Vector3(1, 1, 0.22), false)
	h.crown = crown
	# 伞下核心：发光球 + 三圈脉环
	var core: MeshInstance3D = h._p(body, ART.sphere(0.19 * s, -1, 16), ART.emit(GR, 1.2), Vector3(0, by - 0.02 * s, -0.16 * s), Vector3.ZERO, Vector3.ONE, false)
	h.core_mi = core
	for k in 3:
		h._p(body, ART.torus((0.26 + k * 0.03) * s, (0.28 + k * 0.03) * s, 20), ART.emit(GR, 0.9), Vector3(0, by - 0.02 * s, -0.16 * s),
			Vector3(72 + k * 22.0, k * 40.0, 0), Vector3(1, 1, 0.22), false)
	for sx: float in [-1.0, 1.0]:
		_eye(h, body, Vector3(sx * 0.17 * s, by + 0.04 * s, -0.26 * s), 0.045 * s, GR)
	# 四条细腿
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			h._mleg(body, Vector3(sx * 0.26 * s, by - 0.16 * s, (-0.2 + i * 0.4) * s), sx * (-24.0 + i * 48.0), sx, 0.78 * s, by, 0.075 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0))


# ---------------------------------------------------------------- 曲炮虫
## 斜炮炮手：前半身低伏、后半身高抬，腹部架一根朝上斜的粗炮管，背部三枚酸壳，前肢两面挡板。
## 轮廓是「前低后高的斜坡」，炮管始终在剪影里。
static func _mortar(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_solid(Color(0.38, 0.44, 0.26))
	var SH2: Material = h._vmat_solid(Color(0.5, 0.57, 0.34))
	var DK: Material = h._vmat_solid(Color(0.1, 0.12, 0.08))
	var ST: Material = h._steel()
	var GL := ART.emit(Color(0.7, 0.95, 0.3), 1.4)
	var by := 0.56 * s
	# 低伏的前半身
	h._ell(body, SH, Vector3(0, by, -0.12 * s), Vector3(0.92, 0.66, 0.96) * s)
	h._panels(body, Vector3(0, by + 0.3 * s, -0.12 * s), Vector3(-90, 0, 0), 0.5 * s, 0.5 * s, 131, 4)
	# 抬起的腹部：炮座
	var abd := Node3D.new()
	abd.position = Vector3(0, by + 0.06 * s, 0.34 * s)
	abd.rotation_degrees = Vector3(-56, 0, 0)
	body.add_child(abd)
	h._ell(abd, SH2, Vector3(0, 0, 0.18 * s), Vector3(0.72, 0.62, 0.84) * s)
	h._panels(abd, Vector3(0, 0.3 * s, 0.18 * s), Vector3(-90, 0, 0), 0.46 * s, 0.48 * s, 132, 4)
	for k in 3:
		h._p(abd, ART.torus((0.3 - k * 0.03) * s, (0.33 - k * 0.03) * s, 14), DK, Vector3(0, 0.06 * s, (0.04 + k * 0.18) * s), Vector3(90, 0, 0), Vector3(1, 1, 0.4), false)
	h.abdomen = abd
	# 炮管：粗、长、口部外扩，一道发光装填线
	var barrel := Node3D.new()
	barrel.position = Vector3(0, 0.26 * s, 0.02 * s)
	abd.add_child(barrel)
	h._p(barrel, ART.cyl(0.19 * s, 1.0 * s, 0.26 * s, 12), ST, Vector3(0, 0.5 * s, 0), Vector3.ZERO)
	h._p(barrel, ART.cyl(0.3 * s, 0.22 * s, 0.32 * s, 10), DK, Vector3(0, 0.06 * s, 0), Vector3.ZERO)
	h._p(barrel, ART.cyl(0.34 * s, 0.18 * s, 0.24 * s, 12), ART.emit(Color(0.7, 0.95, 0.3), 1.2), Vector3(0, 1.02 * s, 0), Vector3.ZERO)
	h._p(barrel, ART.torus(0.24 * s, 0.29 * s, 14), GL, Vector3(0, 0.94 * s, 0), Vector3(90, 0, 0), Vector3.ONE, false)
	for k in 3:
		h._p(barrel, ART.torus(0.25 * s, 0.28 * s, 14), DK, Vector3(0, (0.24 + k * 0.3) * s, 0), Vector3(90, 0, 0), Vector3.ONE, false)
	h._box(barrel, GL, Vector3(0.23 * s, 0.5 * s, 0), Vector3(0.014, 0.62, 0.024) * s)
	h.turret = barrel
	# 背部三枚酸壳
	for k in 3:
		h._ell(body, h._vmat_solid(Color(0.3, 0.36, 0.14)), Vector3((-0.2 + k * 0.2), 0, 0.0) + Vector3(0, by + 0.26 * s, 0.06 * s), Vector3(0.2, 0.24, 0.24) * s, Vector3.ZERO, true)
		h._p(body, ART.cyl(0.03 * s, 0.01 * s, 0.03 * s, 8), ART.emit(Color(0.6, 0.95, 0.25), 1.2), Vector3((-0.2 + k * 0.2), 0, 0.0) + Vector3(0, by + 0.38 * s, 0.06 * s), Vector3.ZERO, Vector3.ONE, false)
	for sx: float in [-1.0, 1.0]:
		_eye(h, body, Vector3(sx * 0.18 * s, by + 0.08 * s, -0.48 * s), 0.05 * s, Color(0.75, 0.95, 0.35))
	# 前肢挡板
	for sx: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.38 * s, by + 0.06 * s, -0.36 * s)
		arm.rotation_degrees = Vector3(0, sx * 22.0, 0)
		body.add_child(arm)
		h._servo(arm, Vector3.ZERO, 0.1 * s)
		h._prism(arm, [Vector2(0, 0.28) * s, Vector2(0.24, 0.06) * s, Vector2(0.18, -0.28) * s, Vector2(-0.12, -0.32) * s, Vector2(-0.18, 0.1) * s],
			0.07 * s, 0.1, SH2, Vector3(sx * 0.18 * s, -0.1 * s, -0.06 * s), Vector3(0, 90, 0))
	# 四条腿：后两条活塞、前两条反关节
	for sx: float in [-1.0, 1.0]:
		h._pleg(body, Vector3(sx * 0.46 * s, by - 0.08 * s, 0.3 * s), sx * 26.0, sx, s, by - 0.06 * s, PI if sx > 0 else 0.0)
		h._zleg(body, Vector3(sx * 0.34 * s, by - 0.04 * s, -0.34 * s), sx * -30.0, sx, 0.95 * s, by, 0.09 * s, 0.0 if sx > 0 else PI, true)


# ---------------------------------------------------------------- 铁颚虫
## 横向重甲精英：比甲虫更宽的两层叠甲，正面一对液压铁颚是全身最显眼的部件，肩部撞角，六条活塞腿。
## 前摇时铁颚张到最大——玩家从颚的角度就能看出下一发冲锋的方向。
static func _ironjaw(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_solid(Color(0.34, 0.31, 0.27))
	var SH2: Material = h._vmat_solid(Color(0.46, 0.42, 0.37))
	var DK: Material = h._vmat_solid(Color(0.08, 0.08, 0.08))
	var ST: Material = h._steel()
	var GL := ART.emit(Color(1.0, 0.45, 0.15), 1.5)
	var by := 0.72 * s
	# 底盘：宽六边形 + 双层甲
	h._prism(body, [Vector2(-0.56, -0.62) * s, Vector2(0.56, -0.62) * s, Vector2(0.72, 0.0) * s, Vector2(0.58, 0.72) * s, Vector2(-0.58, 0.72) * s, Vector2(-0.72, 0.0) * s],
		0.4 * s, 0.06, DK, Vector3(0, by, 0), Vector3(90, 0, 0))
	h._prism(body, [Vector2(-0.46, -0.48) * s, Vector2(0.46, -0.48) * s, Vector2(0.58, 0.02) * s, Vector2(0.48, 0.6) * s, Vector2(-0.48, 0.6) * s, Vector2(-0.58, 0.02) * s],
		0.2 * s, 0.08, SH, Vector3(0, by + 0.3 * s, 0), Vector3(90, 0, 0))
	h._panels(body, Vector3(0, by + 0.42 * s, 0.02 * s), Vector3(-90, 0, 0), 0.8 * s, 0.86 * s, 141, 7,
		[h._vmat_solid(Color(0.2, 0.19, 0.17)), h._vmat_matte(Color(0.4, 0.37, 0.33)), h._vmat_matte(Color(0.54, 0.5, 0.45)), SH])
	# 背脊锯齿脊板
	for i in 4:
		h._jag(body, 0.2 * s, 0.32 * s, 0.06 * s, SH2, Vector3(0, by + 0.5 * s, (0.24 - i * 0.18) * s), Vector3(-96, 0, 0), 2, -1.0, 0.0)
	# 正面铁颚：颚座 + 左右大颚
	var jaw_root := Node3D.new()
	jaw_root.position = Vector3(0, by - 0.02 * s, -0.66 * s)
	body.add_child(jaw_root)
	h._prism(jaw_root, [Vector2(0.4, 0.24) * s, Vector2(0.3, -0.18) * s, Vector2(-0.3, -0.18) * s, Vector2(-0.4, 0.24) * s], 0.22 * s, 0.08, DK, Vector3.ZERO)
	for sx: float in [-1.0, 1.0]:
		var j := Node3D.new()
		j.position = Vector3(sx * 0.24 * s, 0.03 * s, -0.08 * s)
		jaw_root.add_child(j)
		h._bar(j, Vector3.ZERO, Vector3(sx * 0.08, -0.12, -0.42) * s, 0.15 * s, 0.17 * s, SH2)
		h._jag(j, 0.2 * s, 0.62 * s, 0.11 * s, ST, Vector3(sx * 0.08, -0.12 * s, -0.46 * s), Vector3(-78, sx * 6.0, 0), 3, -1.0, sx * 0.03 * s)
		h.jaws.append(j)
		_eye(h, jaw_root, Vector3(sx * 0.3 * s, 0.16 * s, -0.14 * s), 0.05 * s, Color(1.0, 0.5, 0.15))
		h._spike(body, Vector3(sx * 0.56 * s, by + 0.28 * s, -0.22 * s), Vector3(sx * 0.9, 0.45, -0.5), 0.52 * s, 0.1 * s, Vector3(sx * 0.12, 0, 0))
		h._box(body, GL, Vector3(sx * 0.62 * s, by + 0.12 * s, 0.12 * s), Vector3(0.012, 0.035, 0.38) * s)
	# 六条活塞腿
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			h._pleg(body, Vector3(sx * 0.6 * s, by - 0.1 * s, (-0.38 + i * 0.46) * s), sx * (-24.0 + i * 24.0), sx, s, by - 0.1 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0))
