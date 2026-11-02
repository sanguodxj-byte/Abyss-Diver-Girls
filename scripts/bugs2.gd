extends RefCounted
## 第二批虫族（v0.4.10）：8 种常规 + 2 只巨型 Boss。全部沿用铁血式硬表面语言：
## 暗枪灰多色调分板甲壳 + 紫色发光装饰线 + 银色伺服 / 液压，禁止圆润有机形。
## 每个 build_<kind>(b, body, s) 用 bug.gd 实例上的构件函数（_prism/_box/_bar/_panels/_servo/各种腿）搭建，
## 动画挂点沿用 bug.gd：legs（步态）、jaws（剪合）、scythes（举起砸下）、gun/gun_tip/gun_glow（射击）、sac（脉动）。
const A = preload("res://scripts/art.gd")
const HS = preload("res://scripts/hs.gd")

const C_CH := Color(0.22, 0.225, 0.24)
const C_CH2 := Color(0.4, 0.41, 0.44)


static func _sc(pts: Array, s: float) -> Array:
	var o: Array = []
	for q in pts:
		o.append(q * s)
	return o


static func _mats(b) -> Dictionary:
	return {
		"AR": b._vmat_solid(C_CH2), "DK": b._vmat_solid(C_CH),
		"LT": b._vmat_matte(Color(0.55, 0.55, 0.58)), "MD": b._vmat_matte(Color(0.33, 0.33, 0.36)),
		"BL": b._vmat_solid(Color(0.03, 0.03, 0.035)), "ST": b._steel(),
	}


static func _node(parent: Node3D, pos: Vector3, rot := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = rot
	parent.add_child(n)
	return n


static func _leg_meta(b, hip: Node3D, sx: float, phase: float) -> void:
	hip.set_meta("side", sx)
	hip.set_meta("phase", phase)
	hip.set_meta("base_y", hip.rotation.y)
	b.legs.append(hip)


## 枪口 / 光晕挂点
static func _muzzle(b, g: Node3D, p: Vector3, s: float) -> void:
	var M: Dictionary = _mats(b)
	b._p(g, A.cyl(0.06 * s, 0.01 * s, 0.06 * s, 10), M.BL, p, Vector3(90, 0, 0), Vector3.ONE, false)
	b.gun_glow = b._p(g, A.cyl(0.05 * s, 0.02 * s, 0.05 * s, 10), b._glow(0.0), p + Vector3(0, 0, -0.01 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	var t := Node3D.new()
	t.position = p + Vector3(0, 0, -0.15 * s)
	g.add_child(t)
	b.gun_tip = t


## 沿 a→b 覆一片弧形甲（拱背朝 face 方向，默认朝上），两端收窄
static func _armor_along(b, parent: Node3D, a: Vector3, e: Vector3, r: float, m: Material, face := Vector3.UP) -> void:
	var d := e - a
	var l := d.length()
	var z := d / l
	var y := (face - z * face.dot(z)).normalized()
	if y.length() < 0.1:
		y = Vector3.UP
	var x := y.cross(z).normalized()
	var mesh := HS.shell_mesh(r, r * 0.16, 0.0, l, [[0.0, 0.7, 0.55, r * 0.92], [0.12, 0.95, 0.9, r * 1.08], [0.55, 1.05, 1.0, r * 1.12], [0.9, 0.8, 0.75, r * 0.95], [1.0, 0.6, 0.5, r * 0.8]], 62.0, 5)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.transform = Transform3D(Basis(x, y, z), a)
	parent.add_child(mi)
	b.parts.append(mi)


## 重型柱腿（Boss / 大型怪）：髋伺服 → 上抬箱形股节（双层甲）→ 膝伺服 → 方截面胫柱（前甲 + 液压）→ 宽足垫 + 三爪
static func _hleg(b, body: Node3D, hip_pos: Vector3, yaw: float, sx: float, s: float, by: float, phase: float, reach := 1.0, th := 1.0) -> Node3D:
	var M: Dictionary = _mats(b)
	var hip := _node(body, hip_pos, Vector3(0, yaw, 0))
	var knee := Vector3(sx * 0.62 * reach * s, 0.5 * s, 0)
	var foot := Vector3(sx * 1.0 * reach * s, -by + 0.02, 0)
	var ank := foot + Vector3(0, 0.22 * s, 0)
	b._servo(hip, Vector3.ZERO, 0.17 * s * th)
	b._limb(hip, Vector3.ZERO, knee, 0.3 * s * th, 0.32 * s * th, M.DK, 0.72, 1.22)
	_armor_along(b, hip, Vector3.ZERO, knee, 0.24 * s * th, M.AR)
	b._seg(hip, Vector3(sx * 0.1 * s, -0.16 * s * th, 0), knee + Vector3(-sx * 0.16 * s, -0.12 * s, 0), 0.05 * s * th, 0.04 * s * th, M.ST, 6)
	b._servo(hip, knee, 0.15 * s * th)
	b._limb(hip, knee, ank, 0.28 * s * th, 0.3 * s * th, M.DK, 0.62, 1.18, Vector3.FORWARD)
	_armor_along(b, hip, knee + Vector3(0, -0.04 * s, 0), ank + Vector3(0, 0.12 * s, 0), 0.22 * s * th, M.MD, Vector3(0, 0, -1))
	b._box(hip, b._glow(1.4), knee.lerp(ank, 0.45) + Vector3(sx * 0.125 * s * th, 0, 0), Vector3(0.008, 0.3, 0.02) * s)
	b._seg(hip, knee + Vector3(0, -0.1, 0.13 * th) * s, ank + Vector3(0, 0.1, 0.13 * th) * s, 0.045 * s * th, 0.035 * s * th, M.ST, 6)
	b._p(hip, A.cyl(0.2 * s * th, 0.1 * s, 0.26 * s * th, 6), M.DK, foot + Vector3(0, 0.08 * s, 0))
	b._p(hip, HS.cbox(Vector3(0.62, 0.1, 0.72) * s * th, 0.03 * s), M.AR, foot + Vector3(0, 0.0, -0.04 * s))
	_leg_meta(b, hip, sx, phase)
	return hip


# ============================================================ 常规 ============================================================

## 镰刃虫：直立胸节 + 楔形头 + 两把折叠大镰臂（scythes，攻击时举起砍下），四条细长刃腿，后拖低平腹节
static func build_mantis(b, body: Node3D, s: float) -> void:
	var M: Dictionary = _mats(b)
	var by := 0.85 * s
	# 腹节：后拖的多段方舱
	# 腹节：分节放样（每节前缘收、中段鼓），节间收腰 + 紫缝，顶面覆弧形背甲
	var ab: Array = []
	for k in 4:
		var z0 := (0.15 + k * 0.24) * s
		var f := 1.0 - k * 0.17
		ab.append_array([[z0, Vector2(0.34, 0.2) * s * f, Vector2(0, -k * 0.035 * s)], [z0 + 0.05 * s, Vector2(0.5, 0.3) * s * f, Vector2(0, -k * 0.035 * s + 0.01 * s)],
			[z0 + 0.17 * s, Vector2(0.46, 0.27) * s * f, Vector2(0, -k * 0.035 * s)], [z0 + 0.235 * s, Vector2(0.36, 0.2) * s * f, Vector2(0, -k * 0.035 * s - 0.01 * s)]])
		b._shell(body, M.LT if k % 2 == 0 else M.AR, Vector3(0, by - 0.05 * s, 0), 0.2 * s * f, 0.025 * s, z0 + 0.02 * s, z0 + 0.2 * s,
			[[0.0, 1.0, 0.9, 0.165 * s * f - k * 0.035 * s], [0.5, 1.15, 1.0, 0.19 * s * f - k * 0.035 * s], [1.0, 0.95, 0.85, 0.16 * s * f - k * 0.035 * s]], Vector3.ZERO, 72.0, 6)
		b._box(body, b._glow(1.4), Vector3(0, by - 0.05 * s + 0.1 * s * f - k * 0.035 * s, z0 + 0.235 * s), Vector3(0.3 * f, 0.012, 0.012) * s)
	ab.append([1.14 * s, Vector2(0.12, 0.08) * s, Vector2(0, -0.16 * s)])
	b._loft(body, HS.crect(1.0, 1.0, 0.45), ab, M.DK, Vector3(0, by - 0.05 * s, 0))
	# 胸节：前上斜立
	b._limb(body, Vector3(0, by - 0.02 * s, 0.16 * s), Vector3(0, by + 0.78 * s, -0.32 * s), 0.4 * s, 0.34 * s, M.DK, 0.62, 1.15)
	_armor_along(b, body, Vector3(0, by + 0.02 * s, 0.08 * s), Vector3(0, by + 0.76 * s, -0.36 * s), 0.2 * s, M.LT, Vector3(0, 0.5, -1))
	b._panels(body, Vector3(0, by + 0.42 * s, -0.24 * s), Vector3(-30, 180, 0), 0.32 * s, 0.6 * s, 61, 3)
	# 楔形头
	var head := _node(body, Vector3(0, by + 0.86 * s, -0.4 * s), Vector3(10, 0, 0))
	b._prism(head, _sc([Vector2(0.32, -0.04), Vector2(0.1, 0.14), Vector2(-0.18, 0.12), Vector2(-0.18, -0.08), Vector2(0.1, -0.14)], s), 0.26 * s, 0.05, M.AR, Vector3.ZERO, Vector3(0, 90, 0))
	b._prism(head, _sc([Vector2(0.14, 0.12), Vector2(-0.2, 0.18), Vector2(-0.22, 0.1), Vector2(0.1, 0.08)], s), 0.18 * s, 0.05, M.DK, Vector3.ZERO, Vector3(0, 90, 0))
	# 大镰臂
	for sx: float in [-1.0, 1.0]:
		var sc := _node(body, Vector3(sx * 0.22 * s, by + 0.62 * s, -0.36 * s))
		b._servo(sc, Vector3.ZERO, 0.08 * s)
		var el := Vector3(sx * 0.08, -0.32, -0.36) * s
		b._limb(sc, Vector3.ZERO, el, 0.13 * s, 0.15 * s, M.AR, 0.7, 1.25)
		_armor_along(b, sc, Vector3.ZERO, el, 0.085 * s, M.LT, Vector3(sx, 1, 0))
		b._servo(sc, el, 0.07 * s)
		# 液压刀臂：直刃切角刀板 + 紫色刃线
		var bl := _node(sc, el, Vector3(0, 90, 0))
		b._prism(bl, _sc([Vector2(0.0, -0.05), Vector2(0.14, 0.05), Vector2(0.13, 0.8), Vector2(0.04, 0.95), Vector2(-0.06, 0.88), Vector2(-0.06, 0.05)], s), 0.05 * s, 0.25, M.LT, Vector3.ZERO, Vector3(-28, 0, 0))
		b._prism(bl, _sc([Vector2(0.02, 0.0), Vector2(0.13, 0.25), Vector2(0.1, 0.72), Vector2(0.06, 0.72), Vector2(0.08, 0.26), Vector2(-0.01, 0.06)], s), 0.05 * s, 0.1, M.DK, Vector3.ZERO, Vector3(-28, 0, 0))
		b._box(bl, b._glow(2.0), Vector3(0, 0.38 * s * cos(deg_to_rad(28)), -0.38 * s * sin(deg_to_rad(-28)) * 0.0), Vector3(0.05, 0.6, 0.012) * s, Vector3(-28, 0, 0))
		b.scythes.append(sc)
	# 四条细长刃腿
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			b._mleg(body, Vector3(sx * 0.16 * s, by - 0.02 * s, (0.05 + i * 0.4) * s), sx * (-15.0 + i * 45.0), sx, 1.1 * s, by, 0.05 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), i == 1)


## 爆破虫：横卧的六棱炸药罐（紫色堆芯透窗 + 黄黑警示带），小传感头，六条短腿
static func build_bomber(b, body: Node3D, s: float) -> void:
	var M: Dictionary = _mats(b)
	var by := 0.5 * s
	var hexo: Array = []
	for k in 6:
		var a := TAU * k / 6.0 + PI / 6.0
		hexo.append(Vector2(cos(a), sin(a)) * 0.34 * s)
	b._loft(body, HS.ngon(6, 1.0, PI / 6.0), [[-0.42 * s, Vector2(0.22, 0.22) * s, Vector2.ZERO], [-0.36 * s, Vector2(0.31, 0.31) * s, Vector2.ZERO], [-0.1 * s, Vector2(0.37, 0.37) * s, Vector2.ZERO],
		[0.2 * s, Vector2(0.37, 0.37) * s, Vector2.ZERO], [0.46 * s, Vector2(0.31, 0.31) * s, Vector2.ZERO], [0.52 * s, Vector2(0.2, 0.2) * s, Vector2.ZERO]], M.DK, Vector3(0, by + 0.1 * s, 0.05 * s))
	# 三道箍 + 两段窗
	for z: float in [-0.3, 0.05, 0.4]:
		var ring: Array = []
		for q in hexo:
			ring.append(q * 1.1)
		b._prism(body, ring, 0.08 * s, 0.02, M.AR, Vector3(0, by + 0.1 * s, z * s))
	var core = b._p(body, A.cyl(0.2 * s, 0.7 * s, 0.2 * s, 6), b._glow(2.4), Vector3(0, by + 0.1 * s, 0.05 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	b.sac = core
	b.spinners.append([core, Vector3.UP, 0.8, 10.0])
	for z: float in [-0.12, 0.22]:
		for k in 3:
			var a := TAU * k / 3.0 + PI / 2.0
			b._box(body, M.BL, Vector3(cos(a) * 0.3 * s, by + 0.1 * s + sin(a) * 0.3 * s, z * s), Vector3(0.12, 0.08, 0.2) * s, Vector3(0, 0, rad_to_deg(a) + 90.0))
	# 警示带（前端）
	var HZ = b._vmat_matte(Color(0.75, 0.62, 0.12))
	for k in 5:
		b._box(body, HZ if k % 2 == 0 else M.BL, Vector3((-0.24 + k * 0.12) * s, by + 0.1 * s, -0.42 * s), Vector3(0.11, 0.5, 0.02) * s, Vector3(0, 0, 30))
	# 传感头
	var head := _node(body, Vector3(0, by + 0.42 * s, -0.3 * s))
	b._box(head, M.AR, Vector3.ZERO, Vector3(0.22, 0.1, 0.18) * s)
	b._box(head, b._glow(3.0), Vector3(0, 0, -0.092 * s), Vector3(0.14, 0.025, 0.006) * s)
	b._bar(head, Vector3(0.06, 0.05, 0.05) * s, Vector3(0.1, 0.32, 0.15) * s, 0.015 * s, 0.015 * s, M.ST)
	b._box(head, b._glow(3.0), Vector3(0.1, 0.33, 0.15) * s, Vector3(0.03, 0.03, 0.03) * s)
	# 尾部引信盒
	b._box(body, M.MD, Vector3(0, by + 0.1 * s, 0.56 * s), Vector3(0.28, 0.28, 0.12) * s)
	b._box(body, b._glow(1.6), Vector3(0, by + 0.1 * s, 0.625 * s), Vector3(0.06, 0.06, 0.01) * s)
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			b._dleg(body, Vector3(sx * 0.3 * s, by - 0.12 * s, (-0.25 + i * 0.3) * s), sx * (-30.0 + i * 30.0), sx, s, by - 0.12 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0))


## 盾卫虫：正面一整面与机体等高的折面塔盾（三列分板 + 观察缝），盾后箱形车体，两侧短钳（scythes），四条活塞腿
static func build_aegis(b, body: Node3D, s: float) -> void:
	var M: Dictionary = _mats(b)
	var by := 0.6 * s
	# 车体
	b._loft(body, HS.keel(1.0, 1.0, 0.75, 0.1), [[-0.3 * s, Vector2(0.9, 0.42) * s, Vector2(0, 0.05 * s)], [-0.2 * s, Vector2(1.1, 0.5) * s, Vector2(0, 0.05 * s)], [0.3 * s, Vector2(1.16, 0.56) * s, Vector2(0, 0.08 * s)],
		[0.62 * s, Vector2(1.0, 0.48) * s, Vector2(0, 0.06 * s)], [0.72 * s, Vector2(0.7, 0.3) * s, Vector2(0, 0.02 * s)]], M.DK, Vector3(0, by, 0.0))
	b._shell(body, M.AR, Vector3(0, by - 0.1 * s, 0), 0.6 * s, 0.05 * s, -0.25 * s, 0.68 * s, [[0.0, 0.9, 0.55, 0.38 * s], [0.3, 1.0, 0.7, 0.44 * s], [0.8, 0.95, 0.65, 0.42 * s], [1.0, 0.75, 0.45, 0.3 * s]], Vector3.ZERO, 60.0, 6)
	b._panels(body, Vector3(0, by + 0.3 * s + 0.005, 0.2 * s), Vector3(-90, 0, 0), 0.8 * s, 0.9 * s, 71, 5)
	for sx: float in [-1.0, 1.0]:
		b._panels(body, Vector3(sx * 0.565 * s, by, 0.25 * s), Vector3(0, 90 * sx, 0), 0.8 * s, 0.25 * s, 72 + int(sx), 3)
		b._box(body, b._glow(1.6), Vector3(sx * 0.57 * s, by + 0.12 * s, 0.25 * s), Vector3(0.006, 0.014, 0.8) * s)
	# 塔盾：三片折面（中央前凸），下缘落地尖角
	var sh := _node(body, Vector3(0, by + 0.3 * s, -0.42 * s), Vector3(-8, 0, 0))
	for k in 3:
		var x := (k - 1) * 0.42
		var ang := (1 - k) * -20.0
		var pn := _node(sh, Vector3(x * s, 0, absf(x) * 0.35 * s), Vector3(0, ang, 0))
		# 每片盾板：竖向放样，横截面是向外鼓的浅拱（中间厚边缘薄），上下两端收尖
		var pl := HS.arch(1.0, 0.18, 52.0, 6)
		b._loft(pn, pl, [[0.95 * s, Vector2(0.12, 0.12) * s, Vector2(0, -0.6 * s)], [0.8 * s, Vector2(0.4, 0.5) * s, Vector2(0, -0.5 * s)], [0.55 * s, Vector2(0.44, 0.56) * s, Vector2(0, -0.56 * s)], [-0.3 * s, Vector2(0.46, 0.58) * s, Vector2(0, -0.58 * s)],
			[-0.62 * s, Vector2(0.42, 0.52) * s, Vector2(0, -0.52 * s)], [-0.72 * s, Vector2(0.3, 0.36) * s, Vector2(0, -0.4 * s)]], M.LT if k == 1 else M.AR, Vector3.ZERO, Vector3(90, 180, 0))
		b._panels(pn, Vector3(0, -0.1 * s, -0.075 * s), Vector3(0, 180, 0), 0.36 * s, 1.1 * s, 74 + k, 4)
		b._box(pn, b._glow(1.4), Vector3(0, -0.6 * s, -0.08 * s), Vector3(0.3, 0.012, 0.01) * s)
	# 观察缝（中片上方）
	b._box(sh, M.BL, Vector3(0, 0.48 * s, -0.09 * s), Vector3(0.24, 0.05, 0.02) * s)
	b._box(sh, b._glow(3.0), Vector3(0, 0.48 * s, -0.1 * s), Vector3(0.16, 0.018, 0.01) * s)
	# 盾背支撑臂
	for sx: float in [-1.0, 1.0]:
		b._bar(body, Vector3(sx * 0.32 * s, by + 0.1 * s, -0.25 * s), Vector3(sx * 0.32 * s, by + 0.3 * s, -0.36 * s), 0.1 * s, 0.1 * s, M.ST)
	# 侧钳（从盾两侧伸出）
	for sx: float in [-1.0, 1.0]:
		var sc := _node(body, Vector3(sx * 0.62 * s, by + 0.05 * s, -0.3 * s))
		b._servo(sc, Vector3.ZERO, 0.1 * s)
		var wr := Vector3(sx * 0.12, -0.08, -0.45) * s
		b._bar(sc, Vector3.ZERO, wr, 0.12 * s, 0.14 * s, M.DK)
		for j: float in [-1.0, 1.0]:
			b._prism(sc, _sc([Vector2(0, -0.04), Vector2(0.16, -0.02), Vector2(0.22, 0.04), Vector2(0.14, 0.03), Vector2(0, 0.04)], s), 0.05 * s, 0.2, M.AR, wr + Vector3(j * 0.04 * s, 0, 0), Vector3(0, 90, j * 18.0))
		b.scythes.append(sc)
	# 背部散热格栅 + 脉动核心
	b._box(body, M.MD, Vector3(0, by + 0.4 * s, 0.45 * s), Vector3(0.5, 0.16, 0.4) * s)
	for k in 5:
		b._box(body, M.BL, Vector3((-0.2 + k * 0.1) * s, by + 0.485 * s, 0.45 * s), Vector3(0.04, 0.01, 0.34) * s)
	b.sac = b._box(body, b._glow(1.0), Vector3(0, by + 0.2 * s, 0.705 * s), Vector3(0.2, 0.1, 0.01) * s)
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			b._pleg(body, Vector3(sx * 0.5 * s, by - 0.08 * s, (-0.05 + i * 0.5) * s), sx * (-20.0 + i * 40.0), sx, s, by - 0.08 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0))


## 迫击虫：低宽车体，背上一门 55° 仰角的粗短迫击炮（gun，后坐沿炮身），炮座回转盘 + 侧挂弹匣，六条短刃腿
static func build_mortar(b, body: Node3D, s: float) -> void:
	var M: Dictionary = _mats(b)
	var by := 0.55 * s
	b._loft(body, HS.crect(1.0, 1.0, 0.5), [[-0.66 * s, Vector2(0.6, 0.16) * s, Vector2(0, -0.04 * s)], [-0.55 * s, Vector2(1.0, 0.28) * s, Vector2.ZERO], [0.0, Vector2(1.14, 0.32) * s, Vector2(0, 0.01 * s)],
		[0.5 * s, Vector2(1.08, 0.3) * s, Vector2.ZERO], [0.68 * s, Vector2(0.7, 0.2) * s, Vector2(0, -0.02 * s)]], M.DK, Vector3(0, by, 0))
	b._shell(body, M.AR, Vector3(0, by, 0), 0.62 * s, 0.04 * s, -0.6 * s, 0.62 * s, [[0.0, 0.7, 0.3, 0.14 * s], [0.2, 0.95, 0.42, 0.2 * s], [0.7, 0.95, 0.42, 0.2 * s], [1.0, 0.7, 0.3, 0.14 * s]], Vector3.ZERO, 66.0, 6)
	b._panels(body, Vector3(0, by + 0.15 * s + 0.005, 0.0), Vector3(-90, 0, 0), 0.9 * s, 1.1 * s, 81, 6)
	for sx: float in [-1.0, 1.0]:
		b._box(body, b._glow(1.6), Vector3(sx * 0.565 * s, by, 0.1 * s), Vector3(0.006, 0.014, 0.6) * s)
	# 前部低矮传感头
	var head := _node(body, Vector3(0, by + 0.05 * s, -0.66 * s))
	b._prism(head, _sc([Vector2(-0.22, -0.08), Vector2(0.22, -0.08), Vector2(0.16, 0.1), Vector2(-0.16, 0.1)], s), 0.2 * s, 0.05, M.AR, Vector3.ZERO)
	# 回转炮座
	b._p(body, A.cyl(0.36 * s, 0.12 * s, 0.4 * s, 8), M.MD, Vector3(0, by + 0.21 * s, 0.15 * s))
	var g := _node(body, Vector3.ZERO)
	g.name = "Gun"
	b.gun = g
	var piv := _node(g, Vector3(0, by + 0.42 * s, 0.2 * s), Vector3(38, 0, 0))
	for sx: float in [-1.0, 1.0]:
		b._box(body, M.AR, Vector3(sx * 0.24 * s, by + 0.4 * s, 0.2 * s), Vector3(0.06, 0.34, 0.3) * s)
	b._servo(piv, Vector3.ZERO, 0.1 * s)
	b._p(piv, A.cyl(0.18 * s, 0.4 * s, 0.2 * s, 8), M.DK, Vector3(0, 0, 0.05 * s), Vector3(90, 0, 0))
	b._loft(piv, HS.ngon(8, 1.0, PI / 8.0), [[0.0, Vector2(0.15, 0.15) * s, Vector2.ZERO], [-0.15 * s, Vector2(0.13, 0.13) * s, Vector2.ZERO], [-0.8 * s, Vector2(0.12, 0.12) * s, Vector2.ZERO], [-0.9 * s, Vector2(0.17, 0.17) * s, Vector2.ZERO], [-1.0 * s, Vector2(0.16, 0.16) * s, Vector2.ZERO]], M.AR, Vector3.ZERO, Vector3.ZERO)
	for k in 3:
		b._p(piv, A.cyl(0.15 * s, 0.05 * s, 0.15 * s, 8), M.ST, Vector3(0, 0, (-0.25 - k * 0.25) * s), Vector3(90, 0, 0))
	b._box(piv, b._glow(1.4), Vector3(0, 0.132 * s, -0.5 * s), Vector3(0.02, 0.006, 0.6) * s)
	b._p(piv, A.cyl(0.16 * s, 0.12 * s, 0.14 * s, 8), M.DK, Vector3(0, 0, -0.98 * s), Vector3(90, 0, 0))
	_muzzle(b, piv, Vector3(0, 0, -1.05 * s), s * 1.6)
	# 侧挂弹匣（三枚紫芯弹）
	for k in 3:
		b._p(body, A.cyl(0.07 * s, 0.32 * s, 0.07 * s, 6), M.MD, Vector3(0.44 * s, by + 0.3 * s, (0.1 + k * 0.16) * s))
		b._p(body, A.cyl(0.04 * s, 0.02 * s, 0.04 * s, 6), b._glow(2.0), Vector3(0.44 * s, by + 0.47 * s, (0.1 + k * 0.16) * s), Vector3.ZERO, Vector3.ONE, false)
	b._box(body, M.DK, Vector3(0.44 * s, by + 0.2 * s, 0.26 * s), Vector3(0.2, 0.1, 0.52) * s)
	b.sac = b._box(body, b._glow(0.8), Vector3(-0.3 * s, by + 0.17 * s, 0.5 * s), Vector3(0.14, 0.01, 0.14) * s)
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			b._mleg(body, Vector3(sx * 0.5 * s, by - 0.02 * s, (-0.38 + i * 0.4) * s), sx * (-25.0 + i * 25.0), sx, 0.75 * s, by, 0.05 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), false)


## 狙击虫：高挑细身，四条长蛛腿把身体架高，身下吊一根双轨电磁长矛（紫色线圈环），尾部电容匣
static func build_lancer(b, body: Node3D, s: float) -> void:
	var M: Dictionary = _mats(b)
	var by := 1.25 * s
	b._loft(body, HS.keel(1.0, 1.0, 0.55, 0.35), [[-0.35 * s, Vector2(0.12, 0.08) * s, Vector2(0, -0.02 * s)], [-0.2 * s, Vector2(0.3, 0.2) * s, Vector2.ZERO], [0.15 * s, Vector2(0.38, 0.26) * s, Vector2(0, 0.02 * s)],
		[0.5 * s, Vector2(0.32, 0.22) * s, Vector2.ZERO], [0.66 * s, Vector2(0.18, 0.12) * s, Vector2(0, -0.02 * s)]], M.DK, Vector3(0, by, 0.0))
	b._prism(body, _sc([Vector2(0.3, 0.14), Vector2(-0.3, 0.2), Vector2(-0.42, 0.12), Vector2(0.2, 0.08)], s), 0.4 * s, 0.05, M.LT, Vector3(0, by + 0.04 * s, 0.1 * s), Vector3(0, 90, 0))
	b._panels(body, Vector3(0.185 * s, by, 0.1 * s), Vector3(0, 90, 0), 0.7 * s, 0.2 * s, 91, 3)
	b._panels(body, Vector3(-0.185 * s, by, 0.1 * s), Vector3(0, -90, 0), 0.7 * s, 0.2 * s, 92, 3)
	# 前端楔形装甲鼻锥
	var head := _node(body, Vector3(0, by + 0.04 * s, -0.42 * s))
	b._prism(head, _sc([Vector2(0.3, 0.0), Vector2(0.0, 0.1), Vector2(-0.1, 0.06), Vector2(-0.1, -0.08), Vector2(0.15, -0.06)], s), 0.18 * s, 0.04, M.AR, Vector3.ZERO, Vector3(0, 90, 0))
	# 电磁长矛
	var g := _node(body, Vector3.ZERO)
	g.name = "Gun"
	b.gun = g
	var g0 := Vector3(0, by - 0.24 * s, 0.1 * s)
	b._box(g, M.MD, g0, Vector3(0.22, 0.16, 0.7) * s)
	for sx: float in [-1.0, 1.0]:
		b._box(g, M.AR, g0 + Vector3(sx * 0.07 * s, 0, -1.3 * s), Vector3(0.05, 0.12, 2.2) * s)
	b._box(g, M.BL, g0 + Vector3(0, -0.02 * s, -1.2 * s), Vector3(0.08, 0.06, 2.0) * s)
	for k in 6:
		b._box(g, b._glow(1.8), g0 + Vector3(0, 0, (-0.5 - k * 0.3) * s), Vector3(0.24, 0.17, 0.03) * s)
	_muzzle(b, g, g0 + Vector3(0, 0, -2.42 * s), s)
	b._bar(body, Vector3(0, by - 0.12 * s, -0.1 * s), g0 + Vector3(0, 0.05 * s, -0.25 * s), 0.08 * s, 0.08 * s, M.ST)
	# 尾部电容匣
	b._box(body, M.DK, Vector3(0, by + 0.05 * s, 0.62 * s), Vector3(0.3, 0.26, 0.24) * s)
	for k in 3:
		b._box(body, b._glow(1.4), Vector3((-0.08 + k * 0.08) * s, by + 0.05 * s, 0.745 * s), Vector3(0.03, 0.18, 0.01) * s)
	b.sac = b._box(body, b._glow(0.6), Vector3(0, by + 0.19 * s, 0.62 * s), Vector3(0.18, 0.01, 0.16) * s)
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			b._mleg(body, Vector3(sx * 0.18 * s, by - 0.05 * s, (-0.12 + i * 0.5) * s), sx * (30.0 - i * 70.0), sx, 1.7 * s, by, 0.05 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0))


## 钻地虫：五节下行车体，前端八棱阶梯钻头（螺旋刃 + 紫色冷却缝），每节一对短腿
static func build_burrower(b, body: Node3D, s: float) -> void:
	var M: Dictionary = _mats(b)
	var by := 0.55 * s
	var oct: Array = []
	for k in 8:
		var a := TAU * k / 8.0 + PI / 8.0
		oct.append(Vector2(cos(a), sin(a)))
	# 钻头：后粗前尖的四级八棱台 + 螺旋刃
	var dr := _node(body, Vector3(0, by + 0.1 * s, -0.55 * s))
	# 扭转放样：每个截面八棱星形转一个角度，形成螺旋刃面
	var star: Array = []
	for k in 16:
		var a := TAU * k / 16.0
		star.append(Vector2(cos(a), sin(a)) * (1.0 if k % 2 == 0 else 0.72))
	var dsec: Array = []
	for k in 9:
		var t := float(k) / 8.0
		var rr := lerpf(0.44, 0.03, pow(t, 0.9))
		var rot: Array = []
		for q in star:
			rot.append(q.rotated(t * 2.4))
		dsec.append([-t * 0.95 * s, Vector2(rr, rr) * s, Vector2.ZERO, rot])
	b._loft(dr, star, dsec, M.ST, Vector3(0, 0, 0.05 * s))
	for k in 4:
		var a := TAU * k / 4.0
		b._bar(dr, Vector3(cos(a) * 0.44, sin(a) * 0.44, 0.05) * s, Vector3(cos(a + 1.2) * 0.1, sin(a + 1.2) * 0.1, -0.78) * s, 0.04 * s, 0.1 * s, M.LT)
	b._p(dr, A.cyl(0.46 * s, 0.08 * s, 0.46 * s, 8), b._glow(1.2), Vector3(0, 0, 0.12 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	b.spinners.append([dr, Vector3.BACK, 0.0, 30.0])
	# 五节车体（从前到后逐节变窄变低）
	for k in 5:
		var w := 0.56 - k * 0.06
		var h := 0.36 - k * 0.03
		var z := (-0.2 + k * 0.42) * s
		var y := by + (0.1 - k * 0.04) * s
		b._loft(body, HS.crect(1.0, 1.0, 0.5), [[-0.2 * s, Vector2(w * 1.5, h * 1.2) * s, Vector2.ZERO], [-0.14 * s, Vector2(w * 2.0, h * 1.5) * s, Vector2(0, 0.02 * s)], [0.12 * s, Vector2(w * 2.0, h * 1.5) * s, Vector2(0, 0.02 * s)], [0.2 * s, Vector2(w * 1.6, h * 1.2) * s, Vector2.ZERO]], M.DK if k % 2 == 0 else M.MD, Vector3(0, y, z))
		b._shell(body, M.AR, Vector3(0, y, z), w * 1.08 * s, 0.04 * s, -0.22 * s, 0.24 * s, [[0.0, 0.92, 0.8, h * 1.0 * s], [0.35, 1.0, 1.0, h * 1.22 * s], [1.0, 0.95, 0.85, h * 1.08 * s]], Vector3.ZERO, 78.0, 7)
		b._box(body, b._glow(1.5), Vector3(0, y + h * s * 0.4, z + 0.195 * s), Vector3(w * 1.6, 0.012, 0.01) * s)
		for sx: float in [-1.0, 1.0]:
			b._box(body, M.ST, Vector3(sx * (w + 0.06) * s, y, z), Vector3(0.02, 0.05, 0.05) * s)
		if k < 4:
			for sx: float in [-1.0, 1.0]:
				b._dleg(body, Vector3(sx * w * s, y - h * 0.5 * s, z), sx * (-10.0 + k * 8.0), sx, s * 1.1, y - h * 0.5 * s, float(k % 2) * PI + (PI if sx > 0 else 0.0))
	b.sac = b._box(body, b._glow(0.9), Vector3(0, by - 0.02 * s, 1.68 * s + 0.19 * s), Vector3(0.24, 0.12, 0.01) * s)


## 指挥虫：中型车体，背上高立传感桅杆（三根天线 + 六角相控阵板 + 旋转雷达框），腹下双联短炮，四条反关节腿
static func build_overseer(b, body: Node3D, s: float) -> void:
	var M: Dictionary = _mats(b)
	var by := 0.85 * s
	b._loft(body, HS.crect(1.0, 1.0, 0.45), [[-0.5 * s, Vector2(0.36, 0.18) * s, Vector2(0, -0.02 * s)], [-0.38 * s, Vector2(0.58, 0.36) * s, Vector2(0, 0.02 * s)], [0.1 * s, Vector2(0.64, 0.44) * s, Vector2(0, 0.04 * s)],
		[0.45 * s, Vector2(0.56, 0.38) * s, Vector2(0, 0.02 * s)], [0.6 * s, Vector2(0.34, 0.2) * s, Vector2.ZERO]], M.DK, Vector3(0, by, 0.0))
	b._prism(body, _sc([Vector2(0.35, 0.22), Vector2(-0.4, 0.26), Vector2(-0.45, 0.18), Vector2(0.3, 0.14)], s), 0.7 * s, 0.05, M.LT, Vector3(0, by + 0.04 * s, 0.05 * s), Vector3(0, 90, 0))
	for sx: float in [-1.0, 1.0]:
		b._panels(body, Vector3(sx * 0.315 * s, by + 0.02 * s, 0.05 * s), Vector3(0, 90 * sx, 0), 0.8 * s, 0.3 * s, 101 + int(sx), 4)
		b._box(body, b._glow(1.6), Vector3(sx * 0.32 * s, by + 0.15 * s, 0.05 * s), Vector3(0.006, 0.012, 0.75) * s)
	var head := _node(body, Vector3(0, by + 0.02 * s, -0.5 * s))
	b._prism(head, _sc([Vector2(-0.24, -0.1), Vector2(0.24, -0.1), Vector2(0.2, 0.12), Vector2(-0.2, 0.12)], s), 0.18 * s, 0.05, M.AR, Vector3.ZERO)
	# 桅杆 + 相控阵 + 雷达框
	var mast_base := Vector3(0, by + 0.3 * s, 0.15 * s)
	b._box(body, M.MD, mast_base, Vector3(0.24, 0.12, 0.24) * s)
	b._bar(body, mast_base, mast_base + Vector3(0, 0.9 * s, 0), 0.1 * s, 0.1 * s, M.DK, Vector3.FORWARD)
	var hexo: Array = []
	for k in 6:
		var a := TAU * k / 6.0
		hexo.append(Vector2(cos(a), sin(a)) * 0.3)
	b._prism(body, _sc(hexo, s), 0.05 * s, 0.02, M.AR, mast_base + Vector3(0, 0.62 * s, -0.08 * s), Vector3(-15, 0, 0))
	b._panels(body, mast_base + Vector3(0, 0.62 * s, -0.11 * s), Vector3(-15, 180, 0), 0.36 * s, 0.36 * s, 105, 4)
	var rad := _node(body, mast_base + Vector3(0, 0.95 * s, 0))
	b._box(rad, M.LT, Vector3.ZERO, Vector3(0.6, 0.04, 0.08) * s)
	b._box(rad, b._glow(1.6), Vector3(0, 0, -0.045 * s), Vector3(0.5, 0.012, 0.006) * s)
	b.spinners.append([rad, Vector3.UP, 1.2, 8.0])
	for k in 3:
		var p := mast_base + Vector3((-0.08 + k * 0.08) * s, 0.06 * s, 0.1 * s)
		b._bar(body, p, p + Vector3((k - 1) * 0.05 * s, (0.5 + k * 0.2) * s, 0.08 * s), 0.012 * s, 0.012 * s, M.ST)
		b._box(body, b._glow(3.0), p + Vector3((k - 1) * 0.05 * s, (0.5 + k * 0.2) * s, 0.08 * s), Vector3(0.025, 0.025, 0.025) * s)
	# 腹下双联短炮
	var g := _node(body, Vector3.ZERO)
	g.name = "Gun"
	b.gun = g
	var g0 := Vector3(0, by - 0.28 * s, -0.25 * s)
	b._box(g, M.MD, g0, Vector3(0.3, 0.14, 0.4) * s)
	for sx: float in [-1.0, 1.0]:
		b._p(g, A.cyl(0.04 * s, 0.6 * s, 0.04 * s, 8), M.ST, g0 + Vector3(sx * 0.08 * s, 0, -0.45 * s), Vector3(90, 0, 0))
		b._box(g, M.DK, g0 + Vector3(sx * 0.08 * s, 0, -0.74 * s), Vector3(0.08, 0.08, 0.08) * s)
	_muzzle(b, g, g0 + Vector3(0, 0, -0.8 * s), s)
	b.sac = b._box(body, b._glow(0.8), Vector3(0, by - 0.12 * s, 0.45 * s), Vector3(0.26, 0.1, 0.01) * s)
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			b._zleg(body, Vector3(sx * 0.28 * s, by - 0.05 * s, (-0.2 + i * 0.5) * s), sx * (30.0 - i * 70.0), sx, 1.25 * s, by, 0.06 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), false)


## 链锯虫：前倾驼背车体，两条粗臂末端是带锯齿链的长锯板（scythes），背上双排气管，六条反关节腿
static func build_ripper(b, body: Node3D, s: float) -> void:
	var M: Dictionary = _mats(b)
	var by := 0.8 * s
	b._loft(body, HS.keel(1.0, 1.0, 0.7, 0.15), [[-0.42 * s, Vector2(0.5, 0.3) * s, Vector2(0, 0.05 * s)], [-0.3 * s, Vector2(0.7, 0.5) * s, Vector2(0, 0.14 * s)], [0.0, Vector2(0.76, 0.62) * s, Vector2(0, 0.2 * s)],
		[0.35 * s, Vector2(0.7, 0.5) * s, Vector2(0, 0.12 * s)], [0.62 * s, Vector2(0.44, 0.3) * s, Vector2(0, 0.02 * s)]], M.DK, Vector3(0, by, 0.0))
	for k in 3:
		b._shell(body, M.AR if k % 2 == 0 else M.LT, Vector3(0, by, 0), 0.42 * s, 0.045 * s, (-0.32 + k * 0.28) * s, (-0.04 + k * 0.28) * s,
			[[0.0, 0.85, 0.8, (0.5 - absf(k - 0.6) * 0.07) * s], [0.5, 1.0, 1.0, (0.56 - absf(k - 0.6) * 0.07) * s], [1.0, 0.9, 0.85, (0.5 - absf(k - 0.6) * 0.07) * s]], Vector3.ZERO, 74.0, 6)
	for sx: float in [-1.0, 1.0]:
		b._panels(body, Vector3(sx * 0.365 * s, by + 0.12 * s, 0.1 * s), Vector3(0, 90 * sx, 0), 0.8 * s, 0.4 * s, 111 + int(sx), 5)
		b._box(body, b._glow(1.6), Vector3(sx * 0.37 * s, by + 0.3 * s, 0.05 * s), Vector3(0.006, 0.014, 0.6) * s)
	var head := _node(body, Vector3(0, by + 0.15 * s, -0.5 * s))
	b._prism(head, _sc([Vector2(-0.18, -0.1), Vector2(0.18, -0.1), Vector2(0.14, 0.1), Vector2(0.0, 0.16), Vector2(-0.14, 0.1)], s), 0.2 * s, 0.05, M.AR, Vector3.ZERO)
	for sx: float in [-1.0, 1.0]:
		var p := Vector3(sx * 0.18 * s, by + 0.5 * s, 0.4 * s)
		b._p(body, A.cyl(0.06 * s, 0.4 * s, 0.07 * s, 6), M.MD, p + Vector3(0, 0.15 * s, 0.05 * s), Vector3(15, 0, 0))
		b._p(body, A.cyl(0.045 * s, 0.01 * s, 0.045 * s, 6), M.BL, p + Vector3(0, 0.35 * s, 0.1 * s), Vector3(15, 0, 0), Vector3.ONE, false)
	# 链锯臂
	for sx: float in [-1.0, 1.0]:
		var sc := _node(body, Vector3(sx * 0.42 * s, by + 0.25 * s, -0.3 * s))
		b._servo(sc, Vector3.ZERO, 0.11 * s)
		var el := Vector3(sx * 0.12, -0.2, -0.3) * s
		b._limb(sc, Vector3.ZERO, el, 0.17 * s, 0.19 * s, M.AR, 0.75, 1.25)
		b._servo(sc, el, 0.09 * s)
		var mo := el + Vector3(0, -0.04, -0.12) * s
		b._box(sc, M.DK, mo, Vector3(0.18, 0.2, 0.22) * s)
		var bar0 := mo + Vector3(0, -0.02 * s, -0.1 * s)
		var bar1 := bar0 + Vector3(0, -0.05 * s, -0.85 * s)
		b._bar(sc, bar0, bar1, 0.04 * s, 0.16 * s, M.ST)
		b._bar(sc, bar0 + Vector3(0, 0.0, 0), bar1, 0.045 * s, 0.1 * s, M.LT)
		for k in 10:
			var t := float(k) / 9.0
			var q := bar0.lerp(bar1, t)
			b._box(sc, M.BL, q + Vector3(0, 0.09 * s, 0), Vector3(0.03, 0.04, 0.04) * s, Vector3(30, 0, 0))
			b._box(sc, M.BL, q + Vector3(0, -0.09 * s, 0), Vector3(0.03, 0.04, 0.04) * s, Vector3(-30, 0, 0))
		b._box(sc, b._glow(2.0), bar0.lerp(bar1, 0.5) + Vector3(sx * 0.025 * s, 0, 0), Vector3(0.006, 0.03, 0.7) * s)
		b.scythes.append(sc)
	b.sac = b._box(body, b._glow(0.8), Vector3(0, by + 0.1 * s, 0.66 * s), Vector3(0.22, 0.16, 0.01) * s)
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			b._zleg(body, Vector3(sx * 0.33 * s, by - 0.08 * s, (-0.25 + i * 0.35) * s), sx * (-25.0 + i * 25.0), sx, 1.0 * s, by, 0.06 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), i == 2)


# ============================================================ Boss ============================================================

## 巢母（Boss）：巨型多层六角甲壳，前端冠状装甲 + 双联重炮（gun），
## 后部巨大孵化腹（两侧三扇半开舱门露出紫色孵化槽），八条重型柱腿。
static func build_brood(b, body: Node3D, s: float) -> void:
	var M: Dictionary = _mats(b)
	var by := 0.95 * s
	# 主甲壳：三层六角板叠起
	# 胸甲：底部放样腹舱 + 四片前后搭接的穹形覆甲（每片后缘一道紫缝），像分节甲壳
	b._loft(body, HS.ngon(10, 1.0, 0.0), [[-0.72 * s, Vector2(0.36, 0.14) * s, Vector2.ZERO], [-0.6 * s, Vector2(0.56, 0.22) * s, Vector2(0, 0.02 * s)], [-0.1 * s, Vector2(0.66, 0.26) * s, Vector2(0, 0.04 * s)],
		[0.45 * s, Vector2(0.58, 0.22) * s, Vector2(0, 0.02 * s)], [0.6 * s, Vector2(0.4, 0.14) * s, Vector2.ZERO]], M.DK, Vector3(0, by, 0))
	for k in 4:
		var z0 := (-0.66 + k * 0.32) * s
		var hk := 0.3 - absf(k - 1.4) * 0.04
		b._shell(body, [M.AR, M.LT, M.AR, M.MD][k], Vector3(0, by, 0), 0.66 * s, 0.05 * s, z0, z0 + 0.4 * s,
			[[0.0, 0.85, 0.75, hk * s * 0.9], [0.3, 1.0, 1.0, hk * s * 1.05], [0.75, 1.0, 1.0, hk * s * 1.08], [1.0, 0.92, 0.9, hk * s]], Vector3.ZERO, 80.0, 8)
		b._box(body, b._glow(1.6), Vector3(0, by + hk * s * 1.0, z0 + 0.4 * s), Vector3(0.7, 0.012, 0.012) * s)
	for k in 6:
		var a := TAU * k / 6.0
		b._panels(body, Vector3(cos(a) * 0.55 * s, by, -0.05 * s + sin(a) * 0.63 * s), Vector3(0, -rad_to_deg(a) + 90.0, 0), 0.5 * s, 0.1 * s, 122 + k, 3)
	# 前端装甲头舱
	var head := _node(body, Vector3(0, by + 0.05 * s, -0.78 * s))
	b._prism(head, _sc([Vector2(-0.3, -0.12), Vector2(0.3, -0.12), Vector2(0.36, 0.06), Vector2(0.2, 0.18), Vector2(-0.2, 0.18), Vector2(-0.36, 0.06)], s), 0.3 * s, 0.04, M.DK, Vector3.ZERO)
	b._prism(head, _sc([Vector2(-0.26, 0.1), Vector2(0.26, 0.1), Vector2(0.16, 0.22), Vector2(-0.16, 0.22)], s), 0.34 * s, 0.03, M.AR, Vector3(0, 0, -0.02 * s))
	for sx: float in [-1.0, 1.0]:
		var jw := _node(head, Vector3(sx * 0.2 * s, -0.08 * s, -0.12 * s))
		b._servo(jw, Vector3.ZERO, 0.04 * s)
		b.jaws.append(jw)
	# 前下双联重炮
	var g := _node(body, Vector3.ZERO)
	g.name = "Gun"
	b.gun = g
	var g0 := Vector3(0, by - 0.16 * s, -0.75 * s)
	b._box(g, M.MD, g0, Vector3(0.36, 0.12, 0.3) * s)
	for sx: float in [-1.0, 1.0]:
		b._p(g, A.cyl(0.05 * s, 0.5 * s, 0.05 * s, 8), M.ST, g0 + Vector3(sx * 0.1 * s, 0, -0.38 * s), Vector3(90, 0, 0))
		for k in 3:
			b._p(g, A.cyl(0.06 * s, 0.02 * s, 0.06 * s, 8), M.DK, g0 + Vector3(sx * 0.1 * s, 0, (-0.25 - k * 0.1) * s), Vector3(90, 0, 0))
	_muzzle(b, g, g0 + Vector3(0, 0, -0.64 * s), s * 0.8)
	# 孵化腹：后部大舱 + 两侧三扇半开舱门 + 发光孵化槽
	var ab := Vector3(0, by + 0.05 * s, 0.85 * s)
	b._loft(body, HS.ngon(12, 1.0, 0.0), [[-0.4 * s, Vector2(0.36, 0.26) * s, Vector2(0, 0.04 * s)], [-0.25 * s, Vector2(0.5, 0.36) * s, Vector2(0, 0.06 * s)], [0.05 * s, Vector2(0.56, 0.42) * s, Vector2(0, 0.08 * s)],
		[0.3 * s, Vector2(0.5, 0.38) * s, Vector2(0, 0.06 * s)], [0.42 * s, Vector2(0.3, 0.24) * s, Vector2(0, 0.02 * s)]], M.DK, ab)
	for k in 3:
		var z0 := (-0.34 + k * 0.24) * s
		b._shell(body, M.AR if k % 2 == 0 else M.LT, ab, 0.5 * s, 0.04 * s, z0, z0 + 0.28 * s, [[0.0, 0.9, 0.85, 0.42 * s], [0.5, 1.08, 1.0, 0.5 * s], [1.0, 0.95, 0.9, 0.44 * s]], Vector3.ZERO, 70.0, 7)
	for sx: float in [-1.0, 1.0]:
		for k in 3:
			var dz := (-0.22 + k * 0.22) * s
			b._box(body, b._glow(2.2), ab + Vector3(sx * 0.49 * s, 0.05 * s, dz), Vector3(0.01, 0.14, 0.14) * s)
			var door := _node(body, ab + Vector3(sx * 0.5 * s, 0.14 * s, dz), Vector3(0, 0, sx * -40.0))
			b._box(door, M.AR, Vector3(sx * 0.0, -0.08 * s, 0), Vector3(0.02, 0.18, 0.17) * s)
	b._box(body, M.MD, ab + Vector3(0, 0.0, 0.36 * s), Vector3(0.6, 0.3, 0.04) * s)
	b.sac = b._box(body, b._glow(1.0), ab + Vector3(0, 0.0, 0.385 * s), Vector3(0.3, 0.14, 0.01) * s)
	# 八条重型腿
	for i in 4:
		for sx: float in [-1.0, 1.0]:
			_hleg(b, body, Vector3(sx * 0.48 * s, by - 0.02 * s, (-0.45 + i * 0.32) * s), sx * (-45.0 + i * 30.0), sx, s * 0.95, by, float(i % 2) * PI + (PI if sx > 0 else 0.0), 1.15, 0.45)


## 破城巨像（Boss）：高耸的六足攻城平台。阶梯式重甲车体 + 前端楔形冲角冠，两只巨型破碎钳（scythes），
## 背负双反应塔（竖鳍 + 紫色堆芯 + 后倾排气），六条粗壮重型柱腿。
static func build_colossus(b, body: Node3D, s: float) -> void:
	var M: Dictionary = _mats(b)
	var by := 1.3 * s
	# 三层阶梯车体
	b._loft(body, HS.keel(1.0, 1.0, 0.82, 0.2), [[-0.7 * s, Vector2(0.9, 0.24) * s, Vector2(0, 0.0)], [-0.55 * s, Vector2(1.36, 0.4) * s, Vector2(0, 0.04 * s)], [0.1 * s, Vector2(1.5, 0.46) * s, Vector2(0, 0.06 * s)],
		[0.6 * s, Vector2(1.36, 0.42) * s, Vector2(0, 0.04 * s)], [0.74 * s, Vector2(0.9, 0.26) * s, Vector2.ZERO]], M.DK, Vector3(0, by, 0))
	for k in 3:
		var z0 := (-0.52 + k * 0.4) * s
		b._shell(body, M.AR if k != 1 else M.MD, Vector3(0, by, 0), 0.62 * s, 0.05 * s, z0, z0 + 0.46 * s, [[0.0, 0.92, 0.6, 0.32 * s], [0.4, 1.0, 0.72, 0.38 * s], [1.0, 0.95, 0.65, 0.34 * s]], Vector3.ZERO, 74.0, 7)
	b._prism(body, _sc([Vector2(-0.3, -0.3), Vector2(0.3, -0.3), Vector2(0.36, 0.1), Vector2(0.3, 0.3), Vector2(-0.3, 0.3), Vector2(-0.36, 0.1)], s), 0.12 * s, 0.03, M.LT, Vector3(0, by + 0.42 * s, -0.05 * s), Vector3(90, 0, 0))
	b._panels(body, Vector3(0, by + 0.181 * s, 0.0), Vector3(-90, 0, 0), 1.1 * s, 1.0 * s, 141, 7)
	b._panels(body, Vector3(0, by + 0.361 * s, 0.1 * s), Vector3(-90, 0, 0), 0.8 * s, 0.6 * s, 142, 5)
	for sx: float in [-1.0, 1.0]:
		b._panels(body, Vector3(sx * 0.705 * s, by, 0.3 * s), Vector3(0, 90 * sx, 0), 0.7 * s, 0.3 * s, 143 + int(sx), 4)
		b._box(body, b._glow(1.8), Vector3(sx * 0.74 * s, by + 0.1 * s, 0.1 * s), Vector3(0.006, 0.014, 1.0) * s)
		for k in 6:
			b._box(body, M.ST, Vector3(sx * 0.72 * s, by - 0.12 * s, (-0.3 + k * 0.15) * s), Vector3(0.012, 0.03, 0.03) * s)
	# 楔形冲角冠
	var ram := _node(body, Vector3(0, by - 0.1 * s, -0.7 * s), Vector3(-30, 0, 0))
	for r in 4:
		var w := 0.7 - r * 0.12
		b._prism(ram, _sc([Vector2(-w, 0.06), Vector2(-w, -0.04), Vector2(0, -0.2), Vector2(w, -0.04), Vector2(w, 0.06), Vector2(0, -0.1)], s), 0.2 * s, 0.08, M.LT if r % 2 == 0 else M.AR, Vector3(0, r * 0.16 * s, 0))
		if r < 3:
			b._box(ram, b._glow(1.4), Vector3(0, (r * 0.16 + 0.08) * s, -0.1 * s), Vector3(w * 1.4, 0.01, 0.01) * s)
	var head := _node(body, Vector3(0, by + 0.52 * s, -0.4 * s))
	b._prism(head, _sc([Vector2(-0.22, 0), Vector2(0.22, 0), Vector2(0.16, 0.14), Vector2(-0.16, 0.14)], s), 0.3 * s, 0.05, M.DK, Vector3.ZERO)
	b._box(head, M.BL, Vector3(0, 0.07 * s, -0.152 * s), Vector3(0.34, 0.06, 0.01) * s)
	for k in 5:
		b._box(head, b._glow(3.0), Vector3((k - 2) * 0.065 * s, 0.07 * s, -0.158 * s), Vector3(0.03, 0.022, 0.006) * s)
	# 巨型破碎钳
	for sx: float in [-1.0, 1.0]:
		var sc := _node(body, Vector3(sx * 0.66 * s, by + 0.12 * s, -0.42 * s))
		b._servo(sc, Vector3.ZERO, 0.14 * s)
		var el := Vector3(sx * 0.24, 0.1, -0.42) * s
		b._bar(sc, Vector3.ZERO, el, 0.2 * s, 0.24 * s, M.AR)
		b._bar(sc, Vector3(0, 0.14 * s, 0), el + Vector3(0, 0.14 * s, 0), 0.24 * s, 0.05 * s, M.LT)
		b._seg(sc, Vector3(0, -0.14 * s, 0.04 * s), el + Vector3(0, -0.12 * s, 0), 0.04 * s, 0.035 * s, M.ST, 6)
		b._servo(sc, el, 0.12 * s)
		var wr := el + Vector3(-sx * 0.04, -0.2, -0.32) * s
		b._bar(sc, el, wr, 0.18 * s, 0.2 * s, M.DK)
		b._box(sc, M.LT, wr + Vector3(0, 0, 0.08 * s), Vector3(0.28, 0.26, 0.16) * s)
		for j: float in [-1.0, 1.0]:
			b._prism(sc, _sc([Vector2(0, -0.08), Vector2(0.26, -0.05), Vector2(0.38, 0.06), Vector2(0.22, 0.04), Vector2(0, 0.08)], s), 0.09 * s, 0.2, M.DK, wr + Vector3(j * 0.08 * s, 0, 0), Vector3(0, 90, j * 20.0))
			b._box(sc, b._glow(1.6), wr + Vector3(j * 0.08 * s, 0.0, -0.2 * s), Vector3(0.006, 0.05, 0.2) * s, Vector3(0, j * 20.0, 0))
		b.scythes.append(sc)
	# 双反应塔
	for sx: float in [-1.0, 1.0]:
		var rc := Vector3(sx * 0.3 * s, by + 0.48 * s, 0.4 * s)
		b._prism(body, _sc([Vector2(-0.16, 0.0), Vector2(0.16, 0.0), Vector2(0.13, 0.55), Vector2(-0.13, 0.55)], s), 0.3 * s, 0.04, M.DK, rc)
		for k in 4:
			b._box(body, M.AR, rc + Vector3((-0.1 + k * 0.067) * s, 0.28 * s, 0.17 * s), Vector3(0.025, 0.45, 0.06) * s)
		b._box(body, b._glow(2.0), rc + Vector3(0, 0.3 * s, -0.152 * s), Vector3(0.1, 0.36, 0.01) * s)
		b._p(body, A.cyl(0.045 * s, 0.4 * s, 0.055 * s, 6), M.MD, rc + Vector3(0, 0.7 * s, 0.1 * s), Vector3(20, 0, 0))
		b._p(body, A.cyl(0.035 * s, 0.01 * s, 0.035 * s, 6), M.BL, rc + Vector3(0, 0.89 * s, 0.17 * s), Vector3(20, 0, 0), Vector3.ONE, false)
	b.sac = b._p(body, A.cyl(0.1 * s, 0.24 * s, 0.1 * s, 6), b._glow(1.2), Vector3(0, by + 0.6 * s, 0.4 * s))
	# 六条粗壮重型腿
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			_hleg(b, body, Vector3(sx * 0.66 * s, by - 0.05 * s, (-0.4 + i * 0.45) * s), sx * (-30.0 + i * 30.0), sx, s, by - 0.05 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), 1.05, 0.6)
