extends RefCounted
## 重工业机械敌群构造库（8 种常规构装体 + 2 种巨型攻城母舰）。
## 统一采用写实重工业军工/矿山工程美学：轧制钢灰、铸铁深灰、军工橄榄绿、氧化防锈红、黄铜法兰、镀铬液压杆与工程黄黑警示涂装；
## 严禁廉价发光霓虹贴片、塑料光圈或实心色块枪口。
## 动画挂点严格保持兼容：legs（步态）、jaws（剪合）、scythes（举砸）、spinners（旋转）、plates（舱门/盾牌开合）、gun/gun_tip/gun_glow（射击）、sac（炉芯脉动）。
const A = preload("res://scripts/art.gd")
const HS = preload("res://scripts/hs.gd")

const C_CH := Color(0.18, 0.19, 0.21)
const C_CH2 := Color(0.35, 0.37, 0.39)


static func _sc(pts: Array, s: float) -> Array:
	var o: Array = []
	for q in pts:
		o.append(q * s)
	return o


static func _mats(b) -> Dictionary:
	return {
		"AR": b._vmat_solid(C_CH2),
		"DK": b._vmat_solid(C_CH),
		"LT": b._vmat_matte(Color(0.50, 0.52, 0.53)),
		"MD": b._vmat_matte(Color(0.29, 0.31, 0.33)),
		"OL": b._vmat_matte(Color(0.28, 0.31, 0.24)),
		"RS": b._rust_plate(),
		"HZ": b._hazard_yel(),
		"BR": b._brass(),
		"CH": b._chrome(),
		"BL": b._vmat_solid(Color(0.03, 0.03, 0.035)),
		"ST": b._steel(),
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


static func _reg_plate(b, n: Node3D, sx: float) -> void:
	n.set_meta("side", sx)
	if b.get("plates") is Array:
		b.plates.append(n)


## 工业开槽制退器 + 深黑膛口 + 隐藏炮口焰挂点（平时绝不发光糊成色块）
static func _muzzle(b, g: Node3D, p: Vector3, s: float) -> void:
	var M: Dictionary = _mats(b)
	b._box(g, M.DK, p + Vector3(0, 0, 0.06 * s), Vector3(0.16, 0.14, 0.16) * s)
	b._box(g, M.ST, p + Vector3(0, 0, -0.01 * s), Vector3(0.17, 0.15, 0.03) * s)
	for sx: float in [-1.0, 1.0]:
		b._box(g, M.BL, p + Vector3(sx * 0.082 * s, 0, 0.06 * s), Vector3(0.01, 0.08, 0.08) * s)
	b._p(g, A.cyl(0.055 * s, 0.02 * s, 0.055 * s, 14), M.BL, p + Vector3(0, 0, -0.025 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	b.gun_glow = b._p(g, A.cyl(0.048 * s, 0.02 * s, 0.048 * s, 14), b._glow(0.0), p + Vector3(0, 0, -0.03 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	var t := Node3D.new()
	t.position = p + Vector3(0, 0, -0.16 * s)
	g.add_child(t)
	b.gun_tip = t


## 沿 a→b 覆一片弧形轧制装甲（拱背朝 face 方向，默认朝上），两端收窄
static func _armor_along(b, parent: Node3D, a: Vector3, e: Vector3, r: float, m: Material, face := Vector3.UP) -> void:
	var d := e - a
	var l := d.length()
	var z := d / l
	var y := (face - z * face.dot(z)).normalized()
	if y.length() < 0.1:
		y = Vector3.UP
	var x := y.cross(z).normalized()
	var mesh := HS.shell_mesh(r, r * 0.16, 0.0, l, [[0.0, 0.7, 0.55, r * 0.92], [0.12, 0.95, 0.9, r * 1.08], [0.55, 1.05, 1.0, r * 1.12], [0.9, 0.8, 0.75, r * 0.95], [1.0, 0.6, 0.5, r * 0.8]], 62.0, 10)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.transform = Transform3D(Basis(x, y, z), a)
	parent.add_child(mi)
	b.parts.append(mi)


## 重型矿山柱腿（Boss / 超重型构装体）：铸钢髋关节 → 覆甲箱形股节 + 下置双级液压缸 → 膝关节 → 护板胫柱 + 后置液压缸 → 宽驻锄足靴
static func _hleg(b, body: Node3D, hip_pos: Vector3, yaw: float, sx: float, s: float, by: float, phase: float, reach := 1.0, th := 1.0) -> Node3D:
	var M: Dictionary = _mats(b)
	var hip := _node(body, hip_pos, Vector3(0, yaw, 0))
	var knee := Vector3(sx * 0.62 * reach * s, 0.5 * s, 0)
	var foot := Vector3(sx * 1.0 * reach * s, -by + 0.02, 0)
	var ank := foot + Vector3(0, 0.22 * s, 0)
	b._servo(hip, Vector3.ZERO, 0.17 * s * th)
	b._limb(hip, Vector3.ZERO, knee, 0.3 * s * th, 0.32 * s * th, M.DK, 0.72, 1.22)
	_armor_along(b, hip, Vector3.ZERO, knee, 0.24 * s * th, M.AR)
	b._hydraulic(hip, Vector3(sx * 0.1 * s, -0.16 * s * th, 0), knee + Vector3(-sx * 0.16 * s, -0.12 * s, 0), 0.052 * s * th, M.DK)
	var kj := _node(hip, knee)
	kj.name = "Knee"
	var ank_rel := ank - knee
	var foot_rel := foot - knee
	b._servo(kj, Vector3.ZERO, 0.15 * s * th)
	b._limb(kj, Vector3.ZERO, ank_rel, 0.28 * s * th, 0.3 * s * th, M.DK, 0.62, 1.18, Vector3.FORWARD)
	_armor_along(b, kj, Vector3(0, -0.04 * s, 0), ank_rel + Vector3(0, 0.12 * s, 0), 0.22 * s * th, M.OL, Vector3(0, 0, -1))
	b._box(kj, M.HZ, ank_rel * 0.45 + Vector3(sx * 0.132 * s * th, 0, 0), Vector3(0.012, 0.22, 0.065) * s * th)
	b._hydraulic(kj, Vector3(0, -0.1, 0.13 * th) * s, ank_rel + Vector3(0, 0.1, 0.13 * th) * s, 0.046 * s * th, M.MD)
	b._p(kj, A.cyl(0.21 * s * th, 0.11 * s, 0.27 * s * th, 12), M.DK, foot_rel + Vector3(0, 0.08 * s, 0))
	b._p(kj, HS.cbox(Vector3(0.64, 0.11, 0.74) * s * th, 0.03 * s), M.AR, foot_rel + Vector3(0, 0.0, -0.04 * s))
	for cz: float in [-0.28, 0.0, 0.24]:
		b._box(kj, M.ST, foot_rel + Vector3(0, -0.035 * s * th, cz * s * th), Vector3(0.66, 0.035, 0.08) * s * th)
	hip.set_meta("knee", kj)
	_leg_meta(b, hip, sx, phase)
	return hip


# ============================================================ 常规构装体 ============================================================

## 镰刃突击机（mantis）：斜立液压躯干 + 装甲测距头 + 双高碳钢工业剪刃臂（scythes）+ 分段配重尾舱 + 四条支撑腿
static func build_mantis(b, body: Node3D, s: float) -> void:
	var M: Dictionary = _mats(b)
	var by := 0.85 * s
	var ab: Array = []
	for k in 4:
		var z0 := (0.15 + k * 0.24) * s
		var f := 1.0 - k * 0.17
		ab.append_array([[z0, Vector2(0.34, 0.2) * s * f, Vector2(0, -k * 0.035 * s)], [z0 + 0.05 * s, Vector2(0.5, 0.3) * s * f, Vector2(0, -k * 0.035 * s + 0.01 * s)],
			[z0 + 0.17 * s, Vector2(0.46, 0.27) * s * f, Vector2(0, -k * 0.035 * s)], [z0 + 0.235 * s, Vector2(0.36, 0.2) * s * f, Vector2(0, -k * 0.035 * s - 0.01 * s)]])
		b._shell(body, M.OL if k % 2 == 0 else M.AR, Vector3(0, by - 0.05 * s, 0), 0.2 * s * f, 0.025 * s, z0 + 0.02 * s, z0 + 0.2 * s,
			[[0.0, 1.0, 0.9, 0.165 * s * f - k * 0.035 * s], [0.5, 1.15, 1.0, 0.19 * s * f - k * 0.035 * s], [1.0, 0.95, 0.85, 0.16 * s * f - k * 0.035 * s]], Vector3.ZERO, 72.0, 6)
		b._box(body, M.BR, Vector3(0, by - 0.05 * s + 0.1 * s * f - k * 0.035 * s, z0 + 0.22 * s), Vector3(0.24 * f, 0.018, 0.024) * s)
	ab.append([1.14 * s, Vector2(0.12, 0.08) * s, Vector2(0, -0.16 * s)])
	b._loft(body, HS.crect(1.0, 1.0, 0.45), ab, M.DK, Vector3(0, by - 0.05 * s, 0))
	# 斜立胸节 + 背部液压主顶杆
	b._limb(body, Vector3(0, by - 0.02 * s, 0.16 * s), Vector3(0, by + 0.78 * s, -0.32 * s), 0.4 * s, 0.34 * s, M.DK, 0.62, 1.15)
	_armor_along(b, body, Vector3(0, by + 0.02 * s, 0.08 * s), Vector3(0, by + 0.76 * s, -0.36 * s), 0.2 * s, M.AR, Vector3(0, 0.5, -1))
	b._hydraulic(body, Vector3(0, by + 0.08 * s, 0.24 * s), Vector3(0, by + 0.68 * s, -0.18 * s), 0.042 * s, M.MD)
	b._panels(body, Vector3(0, by + 0.42 * s, -0.24 * s), Vector3(-30, 180, 0), 0.32 * s, 0.6 * s, 61, 3)
	# 楔形观瞄头壳 + 窄幅琥珀测距窗
	var head := _node(body, Vector3(0, by + 0.86 * s, -0.4 * s), Vector3(10, 0, 0))
	b._prism(head, _sc([Vector2(0.32, -0.04), Vector2(0.1, 0.14), Vector2(-0.18, 0.12), Vector2(-0.18, -0.08), Vector2(0.1, -0.14)], s), 0.28 * s, 0.05, M.AR, Vector3.ZERO, Vector3(0, 90, 0))
	b._prism(head, _sc([Vector2(0.14, 0.12), Vector2(-0.2, 0.18), Vector2(-0.22, 0.1), Vector2(0.1, 0.08)], s), 0.20 * s, 0.05, M.OL, Vector3.ZERO, Vector3(0, 90, 0))
	b._box(head, M.BL, Vector3(0, 0.01 * s, -0.26 * s), Vector3(0.22, 0.042, 0.02) * s)
	b._box(head, b._glow(1.5), Vector3(0, 0.01 * s, -0.27 * s), Vector3(0.17, 0.018, 0.008) * s)
	# 双液压重型冲剪镰臂
	for sx: float in [-1.0, 1.0]:
		var sc := _node(body, Vector3(sx * 0.23 * s, by + 0.62 * s, -0.36 * s))
		b._servo(sc, Vector3.ZERO, 0.085 * s)
		var el := Vector3(sx * 0.08, -0.32, -0.36) * s
		b._limb(sc, Vector3.ZERO, el, 0.13 * s, 0.15 * s, M.AR, 0.7, 1.25)
		b._hydraulic(sc, Vector3(sx * 0.05 * s, 0.06 * s, 0.02 * s), el + Vector3(sx * 0.04 * s, 0.08 * s, 0.04 * s), 0.024 * s, M.DK)
		b._servo(sc, el, 0.075 * s)
		var bl := _node(sc, el, Vector3(0, 90, 0))
		b._prism(bl, _sc([Vector2(0.0, -0.05), Vector2(0.15, 0.05), Vector2(0.14, 0.82), Vector2(0.04, 0.96), Vector2(-0.06, 0.88), Vector2(-0.06, 0.05)], s), 0.046 * s, 0.22, M.CH, Vector3.ZERO, Vector3(-28, 0, 0))
		b._prism(bl, _sc([Vector2(0.01, 0.0), Vector2(0.12, 0.24), Vector2(0.09, 0.74), Vector2(-0.05, 0.82), Vector2(-0.05, 0.06)], s), 0.054 * s, 0.12, M.DK, Vector3.ZERO, Vector3(-28, 0, 0))
		b._box(bl, M.HZ, Vector3(-0.02 * s, 0.22 * s, 0.08 * s), Vector3(0.058, 0.14, 0.04) * s, Vector3(-28, 0, 0))
		b.scythes.append(sc)
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			b._mleg(body, Vector3(sx * 0.17 * s, by - 0.02 * s, (0.05 + i * 0.4) * s), sx * (-15.0 + i * 45.0), sx, 1.1 * s, by, 0.058 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), i == 1)


## 爆破工兵机（bomber）：十六棱防锈红高压燃料储罐 + 四道钢制法兰抱箍 + 黄铜泄压阀 + 黄黑防撞推板 + 内凹琥珀液位视窗
static func build_bomber(b, body: Node3D, s: float) -> void:
	var M: Dictionary = _mats(b)
	var by := 0.52 * s
	var seg_n := 16
	var drum_poly: Array = []
	for k in seg_n:
		var a := TAU * k / float(seg_n) + PI / float(seg_n)
		drum_poly.append(Vector2(cos(a), sin(a)) * 0.35 * s)
	b._loft(body, HS.ngon(seg_n, 1.0, PI / float(seg_n)), [
		[-0.46 * s, Vector2(0.21, 0.21) * s, Vector2.ZERO],
		[-0.40 * s, Vector2(0.32, 0.31) * s, Vector2.ZERO],
		[-0.24 * s, Vector2(0.38, 0.37) * s, Vector2(0, 0.01 * s)],
		[0.05 * s, Vector2(0.41, 0.39) * s, Vector2(0, 0.02 * s)],
		[0.32 * s, Vector2(0.38, 0.37) * s, Vector2(0, 0.01 * s)],
		[0.48 * s, Vector2(0.31, 0.30) * s, Vector2.ZERO],
		[0.55 * s, Vector2(0.20, 0.20) * s, Vector2.ZERO]
	], M.RS, Vector3(0, by + 0.1 * s, 0.04 * s))
	b._shell(body, M.OL, Vector3(0, by + 0.1 * s, 0.04 * s), 0.42 * s, 0.038 * s, -0.34 * s, 0.38 * s,
		[[0.0, 0.86, 0.82, 0.35 * s], [0.35, 1.02, 1.0, 0.41 * s], [0.7, 1.02, 1.0, 0.41 * s], [1.0, 0.86, 0.82, 0.35 * s]], Vector3.ZERO, 64.0, 12)
	b._panels(body, Vector3(0, by + 0.515 * s, 0.04 * s), Vector3(-90, 0, 0), 0.42 * s, 0.62 * s, 68, 5)
	for z: float in [-0.34, -0.08, 0.18, 0.42]:
		var ring: Array = []
		for q in drum_poly:
			ring.append(q * 1.14)
		b._prism(body, ring, 0.065 * s, 0.018, M.DK, Vector3(0, by + 0.1 * s, z * s))
		for sx: float in [-1.0, 1.0]:
			b._box(body, M.ST, Vector3(sx * 0.41 * s, by + 0.1 * s, z * s), Vector3(0.045, 0.095, 0.085) * s)
			b._p(body, A.cyl(0.016 * s, 0.11 * s, 0.016 * s, 6), M.BR, Vector3(sx * 0.43 * s, by + 0.1 * s, z * s))
	# 受保护的内凹液位观察窗（摒弃刺眼外凸光球）
	var core = b._p(body, A.cyl(0.20 * s, 0.72 * s, 0.20 * s, 16), b._glow(1.4), Vector3(0, by + 0.1 * s, 0.04 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	b.sac = core
	for z_win: float in [-0.21, 0.05, 0.30]:
		for sx: float in [-1.0, 1.0]:
			var wpos := Vector3(sx * 0.385 * s, by + 0.12 * s, z_win * s)
			b._box(body, M.DK, wpos, Vector3(0.05, 0.14, 0.16) * s)
			b._box(body, M.BL, wpos + Vector3(sx * 0.022 * s, 0, 0), Vector3(0.014, 0.09, 0.11) * s)
			b._box(body, b._glow(1.8), wpos + Vector3(sx * 0.026 * s, 0, 0), Vector3(0.008, 0.045, 0.08) * s)
	# 顶部黄铜安全泄压阀与压力表盘
	for z_v: float in [-0.12, 0.20]:
		var vpos := Vector3(0, by + 0.50 * s, z_v * s)
		b._p(body, A.cyl(0.075 * s, 0.07 * s, 0.095 * s, 12), M.DK, vpos)
		b._p(body, A.cyl(0.045 * s, 0.055 * s, 0.045 * s, 10), M.BR, vpos + Vector3(0, 0.055 * s, 0))
		b._p(body, A.torus(0.05 * s, 0.068 * s, 12), M.HZ, vpos + Vector3(0, 0.09 * s, 0))
	# 前端黄黑工程防撞爆破盾
	var front_sh := _node(body, Vector3(0, by + 0.08 * s, -0.44 * s), Vector3(-12, 0, 0))
	b._prism(front_sh, _sc([Vector2(-0.28, -0.22), Vector2(0.28, -0.22), Vector2(0.32, 0.08), Vector2(0.22, 0.24), Vector2(-0.22, 0.24), Vector2(-0.32, 0.08)], s), 0.065 * s, 0.03, M.DK, Vector3.ZERO)
	for k in 6:
		b._box(front_sh, M.HZ if k % 2 == 0 else M.BL, Vector3((-0.25 + k * 0.10) * s, 0.0, -0.034 * s), Vector3(0.085, 0.40, 0.016) * s, Vector3(0, 0, 26))
	# 引信测距头 + 弹簧鞭状天线
	var head := _node(body, Vector3(0, by + 0.42 * s, -0.32 * s))
	b._prism(head, _sc([Vector2(-0.15, -0.06), Vector2(0.15, -0.06), Vector2(0.18, 0.04), Vector2(0.12, 0.11), Vector2(-0.12, 0.11), Vector2(-0.18, 0.04)], s), 0.22 * s, 0.03, M.AR, Vector3.ZERO)
	b._box(head, M.BL, Vector3(0, 0.02 * s, -0.112 * s), Vector3(0.24, 0.05, 0.014) * s)
	b._box(head, b._glow(1.6), Vector3(0, 0.02 * s, -0.118 * s), Vector3(0.18, 0.02, 0.008) * s)
	for sx: float in [-1.0, 1.0]:
		b._p(head, A.cyl(0.022 * s, 0.04 * s, 0.026 * s, 8), M.BR, Vector3(sx * 0.09 * s, 0.10 * s, 0.02 * s))
		b._bar(head, Vector3(sx * 0.09, 0.11, 0.02) * s, Vector3(sx * 0.14, 0.34, 0.12) * s, 0.012 * s, 0.012 * s, M.ST)
	# 尾部法兰闷盖 + 排烟口
	var tail := _node(body, Vector3(0, by + 0.1 * s, 0.56 * s))
	b._prism(tail, _sc([Vector2(-0.18, -0.16), Vector2(0.18, -0.16), Vector2(0.22, 0.0), Vector2(0.16, 0.18), Vector2(-0.16, 0.18), Vector2(-0.22, 0.0)], s), 0.14 * s, 0.03, M.DK, Vector3.ZERO)
	b._p(tail, A.cyl(0.085 * s, 0.06 * s, 0.095 * s, 12), M.ST, Vector3(0, 0, 0.085 * s), Vector3(90, 0, 0))
	b._p(tail, A.cyl(0.06 * s, 0.02 * s, 0.06 * s, 12), M.BL, Vector3(0, 0, 0.118 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			b._dleg(body, Vector3(sx * 0.33 * s, by - 0.11 * s, (-0.27 + i * 0.30) * s), sx * (-30.0 + i * 30.0), sx, s * 1.05, by - 0.11 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0))


## 盾卫移动堡垒（aegis）：正面三折式反应装甲攻城塔盾（ERA 叠块 + 防弹观察窗 + 底部推土驻锄）+ 液压撑杆 + 两侧破障钳 + 四条重型活塞支腿
static func build_aegis(b, body: Node3D, s: float) -> void:
	var M: Dictionary = _mats(b)
	var by := 0.62 * s
	# 装甲底盘车体
	b._loft(body, HS.keel(1.0, 1.0, 0.75, 0.1), [[-0.3 * s, Vector2(0.9, 0.42) * s, Vector2(0, 0.05 * s)], [-0.2 * s, Vector2(1.1, 0.5) * s, Vector2(0, 0.05 * s)], [0.3 * s, Vector2(1.16, 0.56) * s, Vector2(0, 0.08 * s)],
		[0.62 * s, Vector2(1.0, 0.48) * s, Vector2(0, 0.06 * s)], [0.74 * s, Vector2(0.74, 0.32) * s, Vector2(0, 0.02 * s)]], M.DK, Vector3(0, by, 0.0))
	b._shell(body, M.OL, Vector3(0, by - 0.1 * s, 0), 0.6 * s, 0.05 * s, -0.25 * s, 0.68 * s, [[0.0, 0.9, 0.55, 0.38 * s], [0.3, 1.0, 0.7, 0.44 * s], [0.8, 0.95, 0.65, 0.42 * s], [1.0, 0.75, 0.45, 0.3 * s]], Vector3.ZERO, 60.0, 6)
	b._panels(body, Vector3(0, by + 0.31 * s, 0.2 * s), Vector3(-90, 0, 0), 0.82 * s, 0.9 * s, 71, 5)
	for sx: float in [-1.0, 1.0]:
		b._panels(body, Vector3(sx * 0.565 * s, by, 0.25 * s), Vector3(0, 90 * sx, 0), 0.8 * s, 0.26 * s, 72 + int(sx), 3)
		b._box(body, M.ST, Vector3(sx * 0.575 * s, by + 0.12 * s, 0.25 * s), Vector3(0.022, 0.045, 0.78) * s)
	# 顶部指挥潜望塔
	var cup := _node(body, Vector3(0, by + 0.48 * s, -0.05 * s))
	b._p(cup, A.cyl(0.22 * s, 0.14 * s, 0.26 * s, 8), M.DK, Vector3.ZERO)
	b._p(cup, A.cyl(0.24 * s, 0.03 * s, 0.24 * s, 8), M.ST, Vector3(0, 0.08 * s, 0))
	b._box(cup, M.BL, Vector3(0, 0.02 * s, -0.22 * s), Vector3(0.22, 0.045, 0.03) * s)
	b._box(cup, b._glow(1.4), Vector3(0, 0.02 * s, -0.232 * s), Vector3(0.16, 0.018, 0.01) * s)
	# 正面三折式重装防爆塔盾（左右翼板登记到 plates，支持开合动画）
	var sh := _node(body, Vector3(0, by + 0.28 * s, -0.44 * s), Vector3(-7, 0, 0))
	for k in 3:
		var x := (k - 1) * 0.44
		var sx_p := float(k - 1)
		var ang := (1 - k) * -22.0
		var pn := _node(sh, Vector3(x * s, 0, absf(x) * 0.34 * s), Vector3(0, ang, 0))
		if k != 1:
			_reg_plate(b, pn, sx_p)
		var pl := HS.arch(1.0, 0.20, 48.0, 6)
		b._loft(pn, pl, [[0.96 * s, Vector2(0.16, 0.14) * s, Vector2(0, -0.58 * s)], [0.80 * s, Vector2(0.42, 0.52) * s, Vector2(0, -0.50 * s)], [0.55 * s, Vector2(0.45, 0.56) * s, Vector2(0, -0.56 * s)], [-0.32 * s, Vector2(0.46, 0.58) * s, Vector2(0, -0.58 * s)],
			[-0.64 * s, Vector2(0.43, 0.52) * s, Vector2(0, -0.52 * s)], [-0.76 * s, Vector2(0.36, 0.40) * s, Vector2(0, -0.42 * s)]], M.AR if k == 1 else M.DK, Vector3.ZERO, Vector3(90, 180, 0))
		# 盾面外挂 ERA 反应装甲块 + 螺栓 + 底部黄黑驻锄铲唇
		for er in 3:
			var ey := (0.28 - er * 0.30) * s
			b._box(pn, M.OL if (er + k) % 2 == 0 else M.MD, Vector3(0, ey, -0.095 * s), Vector3(0.36, 0.24, 0.045) * s, Vector3(4, 0, 0))
			for bx_s: float in [-0.14, 0.14]:
				b._box(pn, M.ST, Vector3(bx_s * s, ey + 0.08 * s, -0.12 * s), Vector3(0.025, 0.025, 0.018) * s)
		b._box(pn, M.HZ, Vector3(0, -0.60 * s, -0.095 * s), Vector3(0.35, 0.065, 0.028) * s)
		b._box(pn, M.ST, Vector3(0, -0.71 * s, -0.09 * s), Vector3(0.38, 0.055, 0.05) * s, Vector3(18, 0, 0))
		b._box(pn, M.ST, Vector3(0, 0.78 * s, -0.05 * s), Vector3(0.05, 0.14, 0.06) * s)
	# 中盾防弹装甲观察窗（带厚钢防弹眉檐）
	b._box(sh, M.ST, Vector3(0, 0.56 * s, -0.125 * s), Vector3(0.34, 0.04, 0.07) * s, Vector3(14, 0, 0))
	b._box(sh, M.BL, Vector3(0, 0.50 * s, -0.105 * s), Vector3(0.28, 0.058, 0.03) * s)
	b._box(sh, b._glow(1.6), Vector3(0, 0.50 * s, -0.118 * s), Vector3(0.20, 0.02, 0.01) * s)
	# 盾背双级液压顶撑油缸
	for sx: float in [-1.0, 1.0]:
		b._hydraulic(body, Vector3(sx * 0.34 * s, by + 0.08 * s, -0.12 * s), Vector3(sx * 0.36 * s, by + 0.28 * s, -0.40 * s), 0.048 * s, M.DK)
		b._bar(body, Vector3(sx * 0.30 * s, by - 0.05 * s, -0.18 * s), Vector3(sx * 0.32 * s, by + 0.04 * s, -0.42 * s), 0.09 * s, 0.09 * s, M.AR)
	# 两侧液压破障钳（scythes）
	for sx: float in [-1.0, 1.0]:
		var sc := _node(body, Vector3(sx * 0.62 * s, by + 0.05 * s, -0.28 * s))
		b._servo(sc, Vector3.ZERO, 0.10 * s)
		var wr := Vector3(sx * 0.14, -0.06, -0.46) * s
		b._bar(sc, Vector3.ZERO, wr, 0.13 * s, 0.15 * s, M.DK)
		b._hydraulic(sc, Vector3(0, 0.10 * s, 0.02 * s), wr + Vector3(0, 0.09 * s, 0.06 * s), 0.03 * s, M.AR)
		b._box(sc, M.BR, wr, Vector3(0.18, 0.16, 0.10) * s)
		for j: float in [-1.0, 1.0]:
			b._prism(sc, _sc([Vector2(0, -0.045), Vector2(0.17, -0.025), Vector2(0.24, 0.04), Vector2(0.15, 0.03), Vector2(0, 0.045)], s), 0.055 * s, 0.18, M.ST, wr + Vector3(j * 0.045 * s, 0, 0), Vector3(0, 90, j * 18.0))
		b.scythes.append(sc)
	# 尾部柴油动力舱百叶与双排烟短管
	b._box(body, M.MD, Vector3(0, by + 0.38 * s, 0.46 * s), Vector3(0.56, 0.18, 0.42) * s)
	for k in 5:
		b._box(body, M.BL, Vector3((-0.2 + k * 0.1) * s, by + 0.475 * s, 0.46 * s), Vector3(0.045, 0.015, 0.34) * s)
	for sx: float in [-1.0, 1.0]:
		var ex := Vector3(sx * 0.22 * s, by + 0.48 * s, 0.66 * s)
		b._p(body, A.cyl(0.045 * s, 0.22 * s, 0.05 * s, 10), M.DK, ex, Vector3(-28, 0, 0))
		b._p(body, A.cyl(0.035 * s, 0.016 * s, 0.035 * s, 10), M.BL, ex + Vector3(0, 0.095 * s, 0.052 * s), Vector3(-28, 0, 0), Vector3.ONE, false)
	b.sac = b._box(body, b._glow(1.1), Vector3(0, by + 0.20 * s, 0.72 * s), Vector3(0.22, 0.07, 0.012) * s)
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			b._pleg(body, Vector3(sx * 0.5 * s, by - 0.08 * s, (-0.05 + i * 0.5) * s), sx * (-20.0 + i * 40.0), sx, s, by - 0.08 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0))


## 自行迫击炮车（mortar）：重装履带风六足底盘 + 液压驻退大口径臼炮 + 橄榄绿高爆弹药架
static func build_mortar(b, body: Node3D, s: float) -> void:
	var M: Dictionary = _mats(b)
	var by := 0.55 * s
	b._loft(body, HS.crect(1.0, 1.0, 0.5), [[-0.66 * s, Vector2(0.6, 0.16) * s, Vector2(0, -0.04 * s)], [-0.55 * s, Vector2(1.0, 0.28) * s, Vector2.ZERO], [0.0, Vector2(1.14, 0.32) * s, Vector2(0, 0.01 * s)],
		[0.5 * s, Vector2(1.08, 0.3) * s, Vector2.ZERO], [0.68 * s, Vector2(0.7, 0.2) * s, Vector2(0, -0.02 * s)]], M.DK, Vector3(0, by, 0))
	b._shell(body, M.OL, Vector3(0, by, 0), 0.62 * s, 0.04 * s, -0.6 * s, 0.62 * s, [[0.0, 0.7, 0.3, 0.14 * s], [0.2, 0.95, 0.42, 0.2 * s], [0.7, 0.95, 0.42, 0.2 * s], [1.0, 0.7, 0.3, 0.14 * s]], Vector3.ZERO, 66.0, 6)
	b._panels(body, Vector3(0, by + 0.155 * s, 0.0), Vector3(-90, 0, 0), 0.9 * s, 1.1 * s, 81, 6)
	for sx: float in [-1.0, 1.0]:
		b._box(body, M.HZ, Vector3(sx * 0.57 * s, by + 0.02 * s, -0.22 * s), Vector3(0.016, 0.045, 0.28) * s)
	var head := _node(body, Vector3(0, by + 0.05 * s, -0.66 * s))
	b._prism(head, _sc([Vector2(-0.22, -0.08), Vector2(0.22, -0.08), Vector2(0.16, 0.1), Vector2(-0.16, 0.1)], s), 0.2 * s, 0.05, M.AR, Vector3.ZERO)
	b._box(head, M.BL, Vector3(0, 0.02 * s, -0.105 * s), Vector3(0.24, 0.045, 0.015) * s)
	b._box(head, b._glow(1.4), Vector3(0, 0.02 * s, -0.112 * s), Vector3(0.16, 0.018, 0.008) * s)
	# 回转座圈与耳轴炮架
	b._p(body, A.cyl(0.38 * s, 0.12 * s, 0.42 * s, 16), M.MD, Vector3(0, by + 0.21 * s, 0.15 * s))
	var g := _node(body, Vector3.ZERO)
	g.name = "Gun"
	b.gun = g
	var piv := _node(g, Vector3(0, by + 0.42 * s, 0.2 * s), Vector3(38, 0, 0))
	for sx: float in [-1.0, 1.0]:
		b._box(body, M.AR, Vector3(sx * 0.25 * s, by + 0.4 * s, 0.2 * s), Vector3(0.07, 0.36, 0.32) * s)
		b._hydraulic(body, Vector3(sx * 0.22 * s, by + 0.24 * s, -0.08 * s), Vector3(sx * 0.20 * s, by + 0.52 * s, 0.04 * s), 0.036 * s, M.DK)
	b._servo(piv, Vector3.ZERO, 0.11 * s)
	b._p(piv, A.cyl(0.19 * s, 0.42 * s, 0.21 * s, 16), M.DK, Vector3(0, 0, 0.05 * s), Vector3(90, 0, 0))
	b._loft(piv, HS.ngon(14, 1.0, PI / 14.0), [[0.0, Vector2(0.155, 0.155) * s, Vector2.ZERO], [-0.15 * s, Vector2(0.135, 0.135) * s, Vector2.ZERO], [-0.8 * s, Vector2(0.125, 0.125) * s, Vector2.ZERO], [-0.92 * s, Vector2(0.165, 0.165) * s, Vector2.ZERO], [-1.02 * s, Vector2(0.16, 0.16) * s, Vector2.ZERO]], M.AR, Vector3.ZERO, Vector3.ZERO)
	# 双侧驻退复进机筒
	for sx: float in [-1.0, 1.0]:
		b._p(piv, A.cyl(0.045 * s, 0.62 * s, 0.045 * s, 10), M.CH, Vector3(sx * 0.165 * s, -0.04 * s, -0.32 * s), Vector3(90, 0, 0))
		b._p(piv, A.cyl(0.055 * s, 0.16 * s, 0.055 * s, 10), M.BR, Vector3(sx * 0.165 * s, -0.04 * s, -0.06 * s), Vector3(90, 0, 0))
	for k in 3:
		b._p(piv, A.cyl(0.155 * s, 0.05 * s, 0.155 * s, 16), M.ST, Vector3(0, 0, (-0.25 - k * 0.25) * s), Vector3(90, 0, 0))
	b._p(piv, A.cyl(0.125 * s, 0.03 * s, 0.125 * s, 16), M.BL, Vector3(0, 0, -1.025 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	b.gun_glow = b._p(piv, A.cyl(0.09 * s, 0.02 * s, 0.09 * s, 14), b._glow(0.0), Vector3(0, 0, -1.03 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	var tip := Node3D.new()
	tip.position = Vector3(0, 0, -1.16 * s)
	piv.add_child(tip)
	b.gun_tip = tip
	# 右舷军工橄榄绿炮弹储运架（黄铜引信头 + 黄条标示）
	b._box(body, M.DK, Vector3(0.44 * s, by + 0.2 * s, 0.26 * s), Vector3(0.22, 0.12, 0.54) * s)
	for k in 3:
		var sp := Vector3(0.44 * s, by + 0.32 * s, (0.08 + k * 0.17) * s)
		b._p(body, A.cyl(0.068 * s, 0.30 * s, 0.068 * s, 12), M.OL, sp)
		b._p(body, A.cyl(0.071 * s, 0.035 * s, 0.071 * s, 12), M.HZ, sp + Vector3(0, 0.08 * s, 0))
		b._p(body, A.cyl(0.025 * s, 0.07 * s, 0.058 * s, 10), M.BR, sp + Vector3(0, 0.18 * s, 0))
	b.sac = b._box(body, b._glow(0.9), Vector3(-0.32 * s, by + 0.18 * s, 0.5 * s), Vector3(0.14, 0.02, 0.14) * s)
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			b._mleg(body, Vector3(sx * 0.5 * s, by - 0.02 * s, (-0.38 + i * 0.4) * s), sx * (-25.0 + i * 25.0), sx, 0.75 * s, by, 0.058 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), false)


## 高脚电磁狙击平台（lancer）：加固桁架四足高架底盘 + 激光光学观瞄仪 + 腹下双轨铜线圈电磁反器材长炮 + 散热鳍片高压电容箱
static func build_lancer(b, body: Node3D, s: float) -> void:
	var M: Dictionary = _mats(b)
	var by := 1.22 * s
	# 紧凑型楔形机匣主体
	b._loft(body, HS.keel(1.0, 1.0, 0.55, 0.35), [[-0.38 * s, Vector2(0.16, 0.11) * s, Vector2(0, -0.02 * s)], [-0.2 * s, Vector2(0.36, 0.24) * s, Vector2.ZERO], [0.15 * s, Vector2(0.44, 0.30) * s, Vector2(0, 0.02 * s)],
		[0.52 * s, Vector2(0.38, 0.25) * s, Vector2.ZERO], [0.68 * s, Vector2(0.24, 0.16) * s, Vector2(0, -0.02 * s)]], M.DK, Vector3(0, by, 0.0))
	b._prism(body, _sc([Vector2(0.34, 0.16), Vector2(-0.32, 0.22), Vector2(-0.46, 0.14), Vector2(0.22, 0.09)], s), 0.46 * s, 0.05, M.OL, Vector3(0, by + 0.05 * s, 0.1 * s), Vector3(0, 90, 0))
	b._panels(body, Vector3(0.21 * s, by, 0.1 * s), Vector3(0, 90, 0), 0.72 * s, 0.22 * s, 91, 3)
	b._panels(body, Vector3(-0.21 * s, by, 0.1 * s), Vector3(0, -90, 0), 0.72 * s, 0.22 * s, 92, 3)
	# 精密双筒光学测距与火控炮塔头（带遮光筒）
	var head := _node(body, Vector3(0, by + 0.14 * s, -0.36 * s))
	b._prism(head, _sc([Vector2(-0.18, -0.08), Vector2(0.18, -0.08), Vector2(0.15, 0.11), Vector2(-0.15, 0.11)], s), 0.28 * s, 0.04, M.AR, Vector3.ZERO)
	b._box(head, M.ST, Vector3(0, 0.115 * s, -0.12 * s), Vector3(0.32, 0.022, 0.10) * s, Vector3(10, 0, 0))
	b._p(head, A.cyl(0.065 * s, 0.16 * s, 0.072 * s, 12), M.DK, Vector3(-0.075 * s, 0.02 * s, -0.18 * s), Vector3(90, 0, 0))
	b._p(head, A.cyl(0.048 * s, 0.02 * s, 0.048 * s, 12), b._glow(1.8), Vector3(-0.075 * s, 0.02 * s, -0.262 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	b._p(head, A.cyl(0.042 * s, 0.14 * s, 0.046 * s, 10), M.ST, Vector3(0.085 * s, 0.02 * s, -0.17 * s), Vector3(90, 0, 0))
	b._p(head, A.cyl(0.028 * s, 0.02 * s, 0.028 * s, 10), M.BL, Vector3(0.085 * s, 0.02 * s, -0.242 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	# 腹下重型双轨电磁长矛（机加工导轨 + 6 组黄铜励磁线圈箍 + 桁架吊臂 + 开槽制退器）
	var g := _node(body, Vector3.ZERO)
	g.name = "Gun"
	b.gun = g
	var g0 := Vector3(0, by - 0.26 * s, 0.12 * s)
	b._box(g, M.DK, g0, Vector3(0.28, 0.22, 0.78) * s)
	b._box(g, M.HZ, g0 + Vector3(0, 0.05 * s, 0.12 * s), Vector3(0.29, 0.045, 0.34) * s)
	for sx: float in [-1.0, 1.0]:
		# 左右重型加速导轨
		b._box(g, M.ST, g0 + Vector3(sx * 0.082 * s, 0.02 * s, -1.32 * s), Vector3(0.055, 0.085, 2.24) * s)
		b._box(g, M.DK, g0 + Vector3(sx * 0.082 * s, -0.045 * s, -1.22 * s), Vector3(0.068, 0.045, 2.04) * s)
	# 导轨间内凹电枢槽（细窄琥珀导能母线，绝不外溢）
	b._box(g, M.BL, g0 + Vector3(0, 0.0, -1.25 * s), Vector3(0.09, 0.055, 2.1) * s)
	b._box(g, b._glow(1.5), g0 + Vector3(0, 0.0, -1.25 * s), Vector3(0.026, 0.018, 1.95) * s)
	for k in 6:
		var cz := (-0.48 - k * 0.31) * s
		b._box(g, M.MD, g0 + Vector3(0, 0, cz), Vector3(0.26, 0.19, 0.075) * s)
		b._box(g, M.BR, g0 + Vector3(0, 0, cz), Vector3(0.275, 0.15, 0.042) * s)
	_muzzle(b, g, g0 + Vector3(0, 0, -2.48 * s), s * 1.15)
	for zz: float in [-0.18, 0.22]:
		b._bar(body, Vector3(0, by - 0.08 * s, zz * s), g0 + Vector3(0, 0.09 * s, (zz - 0.12) * s), 0.10 * s, 0.10 * s, M.AR)
	b._hydraulic(body, Vector3(0, by - 0.10 * s, -0.30 * s), g0 + Vector3(0, 0.10 * s, -0.58 * s), 0.036 * s, M.DK)
	# 尾部高压脉冲电容器组 + 散热铝鳍片 + 黄铜母排
	var cap := Vector3(0, by + 0.08 * s, 0.64 * s)
	b._box(body, M.DK, cap, Vector3(0.42, 0.30, 0.34) * s)
	for sx: float in [-1.0, 1.0]:
		b._p(body, A.cyl(0.085 * s, 0.32 * s, 0.085 * s, 12), M.RS, cap + Vector3(sx * 0.12 * s, 0.16 * s, 0), Vector3(90, 0, 0))
		b._p(body, A.cyl(0.05 * s, 0.05 * s, 0.05 * s, 10), M.BR, cap + Vector3(sx * 0.12 * s, 0.16 * s, 0.17 * s), Vector3(90, 0, 0))
	for k in 5:
		b._box(body, M.ST, cap + Vector3((-0.14 + k * 0.07) * s, -0.02 * s, 0.18 * s), Vector3(0.022, 0.22, 0.05) * s)
	b.sac = b._box(body, b._glow(1.1), cap + Vector3(0, 0.14 * s, 0.175 * s), Vector3(0.16, 0.035, 0.012) * s)
	# 四条加固桁架驻锄高脚腿（加粗股胫截面，消除牙签感）
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			b._mleg(body, Vector3(sx * 0.22 * s, by - 0.04 * s, (-0.14 + i * 0.52) * s), sx * (32.0 - i * 72.0), sx, 1.62 * s, by, 0.078 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0))


## 隧道掘进机虫（burrower）：TBM 硬岩滚刀盘（旋转）+ 黄黑防坍塌护盾环 + 五节铰接矿山车厢 + 八条铲土短腿
static func build_burrower(b, body: Node3D, s: float) -> void:
	var M: Dictionary = _mats(b)
	var by := 0.55 * s
	var dr := _node(body, Vector3(0, by + 0.1 * s, -0.56 * s))
	var star: Array = []
	for k in 16:
		var a := TAU * k / 16.0
		star.append(Vector2(cos(a), sin(a)) * (1.0 if k % 2 == 0 else 0.76))
	var dsec: Array = []
	for k in 9:
		var t := float(k) / 8.0
		var rr := lerpf(0.46, 0.05, pow(t, 0.88))
		var rot: Array = []
		for q in star:
			rot.append(q.rotated(t * 2.2))
		dsec.append([-t * 0.92 * s, Vector2(rr, rr) * s, Vector2.ZERO, rot])
	b._loft(dr, star, dsec, M.DK, Vector3(0, 0, 0.05 * s))
	for k in 4:
		var a := TAU * k / 4.0
		b._bar(dr, Vector3(cos(a) * 0.44, sin(a) * 0.44, 0.02) * s, Vector3(cos(a + 1.1) * 0.12, sin(a + 1.1) * 0.12, -0.76) * s, 0.05 * s, 0.11 * s, M.CH)
		# 碳化钨盘形滚刀 + 黄铜轴承盖
		var cp := Vector3(cos(a + 0.4) * 0.30, sin(a + 0.4) * 0.30, -0.34) * s
		b._p(dr, A.cyl(0.09 * s, 0.045 * s, 0.09 * s, 12), M.ST, cp, Vector3(0, 0, rad_to_deg(a)))
		b._p(dr, A.cyl(0.04 * s, 0.06 * s, 0.04 * s, 8), M.BR, cp, Vector3(0, 0, rad_to_deg(a)))
	b.spinners.append([dr, Vector3.BACK, 1.5, 30.0])
	# 护盾法兰环 + 工程警示条（取代原紫色发光圆盘）
	b._p(body, A.cyl(0.49 * s, 0.14 * s, 0.51 * s, 12), M.AR, Vector3(0, by + 0.1 * s, -0.44 * s), Vector3(90, 0, 0))
	b._p(body, A.cyl(0.515 * s, 0.045 * s, 0.515 * s, 12), M.HZ, Vector3(0, by + 0.1 * s, -0.46 * s), Vector3(90, 0, 0))
	for k in 5:
		var w := 0.56 - k * 0.06
		var h := 0.36 - k * 0.03
		var z := (-0.2 + k * 0.42) * s
		var y := by + (0.1 - k * 0.04) * s
		b._loft(body, HS.crect(1.0, 1.0, 0.5), [[-0.2 * s, Vector2(w * 1.5, h * 1.2) * s, Vector2.ZERO], [-0.14 * s, Vector2(w * 2.0, h * 1.5) * s, Vector2(0, 0.02 * s)], [0.12 * s, Vector2(w * 2.0, h * 1.5) * s, Vector2(0, 0.02 * s)], [0.2 * s, Vector2(w * 1.6, h * 1.2) * s, Vector2.ZERO]], M.DK if k % 2 == 0 else M.MD, Vector3(0, y, z))
		b._shell(body, M.OL if k % 2 == 1 else M.AR, Vector3(0, y, z), w * 1.08 * s, 0.04 * s, -0.22 * s, 0.24 * s, [[0.0, 0.92, 0.8, h * 1.0 * s], [0.35, 1.0, 1.0, h * 1.22 * s], [1.0, 0.95, 0.85, h * 1.08 * s]], Vector3.ZERO, 78.0, 7)
		for sx: float in [-1.0, 1.0]:
			b._box(body, M.ST, Vector3(sx * (w + 0.06) * s, y, z), Vector3(0.028, 0.06, 0.08) * s)
			if k < 4:
				b._hydraulic(body, Vector3(sx * w * 0.72 * s, y + 0.04 * s, z + 0.14 * s), Vector3(sx * (w - 0.06) * 0.72 * s, y + 0.0 * s, z + 0.30 * s), 0.024 * s, M.DK)
		if k < 4:
			for sx: float in [-1.0, 1.0]:
				b._dleg(body, Vector3(sx * w * s, y - h * 0.5 * s, z), sx * (-10.0 + k * 8.0), sx, s * 1.1, y - h * 0.5 * s, float(k % 2) * PI + (PI if sx > 0 else 0.0))
	b.sac = b._box(body, b._glow(1.0), Vector3(0, by - 0.02 * s, 1.87 * s), Vector3(0.22, 0.08, 0.012) * s)


## 战场电子战指挥机（overseer）：装甲通讯方舱车体 + 桁架雷达桅杆 + 相控阵雷达板 + 旋转开槽波导雷达天线（spinners）+ 腹下双联机炮
static func build_overseer(b, body: Node3D, s: float) -> void:
	var M: Dictionary = _mats(b)
	var by := 0.85 * s
	b._loft(body, HS.crect(1.0, 1.0, 0.45), [[-0.52 * s, Vector2(0.38, 0.20) * s, Vector2(0, -0.02 * s)], [-0.38 * s, Vector2(0.60, 0.38) * s, Vector2(0, 0.02 * s)], [0.1 * s, Vector2(0.66, 0.45) * s, Vector2(0, 0.04 * s)],
		[0.46 * s, Vector2(0.58, 0.39) * s, Vector2(0, 0.02 * s)], [0.62 * s, Vector2(0.38, 0.22) * s, Vector2.ZERO]], M.DK, Vector3(0, by, 0.0))
	b._prism(body, _sc([Vector2(0.36, 0.23), Vector2(-0.42, 0.27), Vector2(-0.47, 0.18), Vector2(0.32, 0.14)], s), 0.72 * s, 0.05, M.OL, Vector3(0, by + 0.04 * s, 0.05 * s), Vector3(0, 90, 0))
	for sx: float in [-1.0, 1.0]:
		b._panels(body, Vector3(sx * 0.33 * s, by + 0.02 * s, 0.05 * s), Vector3(0, 90 * sx, 0), 0.8 * s, 0.3 * s, 101 + int(sx), 4)
		# 外挂军用电子对抗机柜 + 散热百叶 + 警示标
		b._box(body, M.MD, Vector3(sx * 0.37 * s, by + 0.08 * s, 0.22 * s), Vector3(0.10, 0.22, 0.36) * s)
		b._box(body, M.HZ, Vector3(sx * 0.422 * s, by + 0.14 * s, 0.22 * s), Vector3(0.008, 0.04, 0.26) * s)
	# 装甲观测鼻舱
	var head := _node(body, Vector3(0, by + 0.03 * s, -0.52 * s))
	b._prism(head, _sc([Vector2(-0.25, -0.1), Vector2(0.25, -0.1), Vector2(0.21, 0.13), Vector2(-0.21, 0.13)], s), 0.20 * s, 0.05, M.AR, Vector3.ZERO)
	b._box(head, M.ST, Vector3(0, 0.11 * s, -0.09 * s), Vector3(0.42, 0.024, 0.07) * s, Vector3(12, 0, 0))
	b._box(head, M.BL, Vector3(0, 0.03 * s, -0.102 * s), Vector3(0.34, 0.052, 0.018) * s)
	b._box(head, b._glow(1.5), Vector3(0, 0.03 * s, -0.11 * s), Vector3(0.26, 0.02, 0.008) * s)
	# 背部钢结构桁架桅杆 + 倾角六角 AESA 相控阵板 + 旋转开槽波导航海/战场雷达
	var mast_base := Vector3(0, by + 0.30 * s, 0.12 * s)
	b._box(body, M.DK, mast_base, Vector3(0.30, 0.12, 0.30) * s)
	for mx: float in [-0.07, 0.07]:
		for mz: float in [-0.07, 0.07]:
			b._bar(body, mast_base + Vector3(mx, 0, mz) * s, mast_base + Vector3(mx * 0.65, 0.92, mz * 0.65) * s, 0.028 * s, 0.028 * s, M.ST)
	for lv in 3:
		var ly := (0.24 + lv * 0.28) * s
		b._box(body, M.MD, mast_base + Vector3(0, ly, 0), Vector3(0.15, 0.024, 0.15) * s)
	var hexo: Array = []
	for k in 6:
		var a := TAU * k / 6.0
		hexo.append(Vector2(cos(a), sin(a)) * 0.30)
	b._prism(body, _sc(hexo, s), 0.06 * s, 0.02, M.AR, mast_base + Vector3(0, 0.56 * s, -0.11 * s), Vector3(-16, 0, 0))
	b._panels(body, mast_base + Vector3(0, 0.56 * s, -0.145 * s), Vector3(-16, 180, 0), 0.36 * s, 0.36 * s, 105, 4)
	# 顶部旋转雷达：电机座 + 开槽波导长横梁 + 后置配重块与抛物副反射器
	var rad := _node(body, mast_base + Vector3(0, 0.96 * s, 0))
	b._p(rad, A.cyl(0.08 * s, 0.10 * s, 0.09 * s, 10), M.DK, Vector3(0, -0.03 * s, 0))
	b._box(rad, M.LT, Vector3(0, 0.03 * s, -0.02 * s), Vector3(0.76, 0.075, 0.095) * s)
	b._box(rad, M.HZ, Vector3(-0.34 * s, 0.03 * s, -0.02 * s), Vector3(0.06, 0.08, 0.10) * s)
	b._box(rad, M.HZ, Vector3(0.34 * s, 0.03 * s, -0.02 * s), Vector3(0.06, 0.08, 0.10) * s)
	for sl in 7:
		b._box(rad, M.BL, Vector3((-0.24 + sl * 0.08) * s, 0.03 * s, -0.07 * s), Vector3(0.045, 0.035, 0.01) * s)
	b._box(rad, M.MD, Vector3(0, 0.02 * s, 0.11 * s), Vector3(0.18, 0.06, 0.14) * s)
	b.spinners.append([rad, Vector3.UP, 1.5, 8.0])
	# 后部三根军用弹簧底座鞭状通讯天线
	for k in 3:
		var p := mast_base + Vector3((-0.11 + k * 0.11) * s, -0.02 * s, 0.28 * s)
		b._p(body, A.cyl(0.022 * s, 0.05 * s, 0.026 * s, 8), M.BR, p)
		var top_p := p + Vector3((k - 1) * 0.05 * s, (0.52 + k * 0.18) * s, 0.08 * s)
		b._bar(body, p, top_p, 0.012 * s, 0.012 * s, M.ST)
		if k == 1:
			b._p(body, A.cyl(0.018 * s, 0.03 * s, 0.018 * s, 8), b._glow(1.8), top_p, Vector3.ZERO, Vector3.ONE, false)
	# 腹下双联 20mm 机炮吊舱
	var g := _node(body, Vector3.ZERO)
	g.name = "Gun"
	b.gun = g
	var g0 := Vector3(0, by - 0.28 * s, -0.24 * s)
	b._box(g, M.DK, g0, Vector3(0.34, 0.16, 0.44) * s)
	b._box(g, M.OL, g0 + Vector3(0, 0.02 * s, 0.06 * s), Vector3(0.36, 0.12, 0.26) * s)
	for sx: float in [-1.0, 1.0]:
		b._p(g, A.cyl(0.048 * s, 0.22 * s, 0.048 * s, 10), M.MD, g0 + Vector3(sx * 0.095 * s, 0, -0.28 * s), Vector3(90, 0, 0))
		b._p(g, A.cyl(0.034 * s, 0.58 * s, 0.034 * s, 10), M.ST, g0 + Vector3(sx * 0.095 * s, 0, -0.48 * s), Vector3(90, 0, 0))
		b._p(g, A.cyl(0.042 * s, 0.08 * s, 0.042 * s, 10), M.DK, g0 + Vector3(sx * 0.095 * s, 0, -0.75 * s), Vector3(90, 0, 0))
		b._p(g, A.cyl(0.026 * s, 0.02 * s, 0.026 * s, 10), M.BL, g0 + Vector3(sx * 0.095 * s, 0, -0.792 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	_muzzle(b, g, g0 + Vector3(0, 0, -0.80 * s), s * 0.85)
	b.sac = b._box(body, b._glow(1.0), Vector3(0, by - 0.10 * s, 0.56 * s), Vector3(0.24, 0.06, 0.012) * s)
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			b._zleg(body, Vector3(sx * 0.28 * s, by - 0.05 * s, (-0.2 + i * 0.5) * s), sx * (30.0 - i * 70.0), sx, 1.25 * s, by, 0.065 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), false)


## 伐木/破拆链锯机（ripper）：防滚架驼背柴油机舱 + 双穿孔防烫排烟囱 + 双液压采伐链锯大臂（scythes）+ 六条反关节抓地腿
static func build_ripper(b, body: Node3D, s: float) -> void:
	var M: Dictionary = _mats(b)
	var by := 0.8 * s
	b._loft(body, HS.keel(1.0, 1.0, 0.7, 0.15), [[-0.42 * s, Vector2(0.5, 0.3) * s, Vector2(0, 0.05 * s)], [-0.3 * s, Vector2(0.72, 0.52) * s, Vector2(0, 0.14 * s)], [0.0, Vector2(0.78, 0.62) * s, Vector2(0, 0.2 * s)],
		[0.35 * s, Vector2(0.72, 0.5) * s, Vector2(0, 0.12 * s)], [0.62 * s, Vector2(0.46, 0.32) * s, Vector2(0, 0.02 * s)]], M.DK, Vector3(0, by, 0.0))
	for k in 3:
		b._shell(body, M.OL if k == 1 else M.AR, Vector3(0, by, 0), 0.42 * s, 0.045 * s, (-0.32 + k * 0.28) * s, (-0.04 + k * 0.28) * s,
			[[0.0, 0.85, 0.8, (0.5 - absf(k - 0.6) * 0.07) * s], [0.5, 1.0, 1.0, (0.56 - absf(k - 0.6) * 0.07) * s], [1.0, 0.9, 0.85, (0.5 - absf(k - 0.6) * 0.07) * s]], Vector3.ZERO, 74.0, 6)
	# 工程机械黄色钢管防滚护笼（包覆前胸与机舱顶）
	for sx: float in [-1.0, 1.0]:
		b._panels(body, Vector3(sx * 0.37 * s, by + 0.12 * s, 0.1 * s), Vector3(0, 90 * sx, 0), 0.8 * s, 0.4 * s, 111 + int(sx), 5)
		var r0 := Vector3(sx * 0.28 * s, by + 0.22 * s, -0.40 * s)
		var r1 := Vector3(sx * 0.30 * s, by + 0.62 * s, -0.18 * s)
		var r2 := Vector3(sx * 0.28 * s, by + 0.58 * s, 0.28 * s)
		b._bar(body, r0, r1, 0.032 * s, 0.032 * s, M.HZ)
		b._bar(body, r1, r2, 0.032 * s, 0.032 * s, M.HZ)
	b._bar(body, Vector3(-0.30 * s, by + 0.62 * s, -0.18 * s), Vector3(0.30 * s, by + 0.62 * s, -0.18 * s), 0.032 * s, 0.032 * s, M.HZ)
	b._bar(body, Vector3(-0.28 * s, by + 0.58 * s, 0.28 * s), Vector3(0.28 * s, by + 0.58 * s, 0.28 * s), 0.032 * s, 0.032 * s, M.ST)
	# 防护网观瞄头壳
	var head := _node(body, Vector3(0, by + 0.14 * s, -0.50 * s))
	b._prism(head, _sc([Vector2(-0.19, -0.1), Vector2(0.19, -0.1), Vector2(0.15, 0.11), Vector2(0.0, 0.16), Vector2(-0.15, 0.11)], s), 0.22 * s, 0.05, M.AR, Vector3.ZERO)
	b._box(head, M.BL, Vector3(0, 0.03 * s, -0.112 * s), Vector3(0.24, 0.05, 0.015) * s)
	b._box(head, b._glow(1.5), Vector3(0, 0.03 * s, -0.118 * s), Vector3(0.18, 0.02, 0.008) * s)
	# 双柴油重型排烟管（带铁锈防烫护套与深黑烟口）
	for sx: float in [-1.0, 1.0]:
		var p := Vector3(sx * 0.20 * s, by + 0.48 * s, 0.38 * s)
		b._p(body, A.cyl(0.052 * s, 0.44 * s, 0.058 * s, 10), M.DK, p + Vector3(0, 0.16 * s, 0.05 * s), Vector3(16, 0, 0))
		b._p(body, A.cyl(0.068 * s, 0.26 * s, 0.068 * s, 10), M.RS, p + Vector3(0, 0.11 * s, 0.035 * s), Vector3(16, 0, 0))
		b._p(body, A.cyl(0.042 * s, 0.018 * s, 0.042 * s, 10), M.BL, p + Vector3(0, 0.375 * s, 0.112 * s), Vector3(16, 0, 0), Vector3.ONE, false)
	# 双液压重型采伐链锯大臂（消除扁尺子+粉条感：油马达驱动箱 + 护手挡板 + 导板导槽 + 高亮钨钢链齿环绕）
	for sx: float in [-1.0, 1.0]:
		var sc := _node(body, Vector3(sx * 0.43 * s, by + 0.25 * s, -0.28 * s))
		b._servo(sc, Vector3.ZERO, 0.115 * s)
		var el := Vector3(sx * 0.12, -0.20, -0.30) * s
		b._limb(sc, Vector3.ZERO, el, 0.17 * s, 0.19 * s, M.AR, 0.75, 1.25)
		b._hydraulic(sc, Vector3(sx * 0.04 * s, 0.12 * s, 0.04 * s), el + Vector3(sx * 0.03 * s, 0.11 * s, 0.02 * s), 0.034 * s, M.DK)
		b._servo(sc, el, 0.095 * s)
		var mo := el + Vector3(0, -0.04, -0.13) * s
		# 液压链轮驱动马达箱 + 黄色护板 + 黄铜离合器鼓
		b._box(sc, M.OL, mo, Vector3(0.20, 0.23, 0.26) * s)
		b._box(sc, M.HZ, mo + Vector3(0, 0.13 * s, -0.04 * s), Vector3(0.22, 0.045, 0.18) * s, Vector3(15, 0, 0))
		b._p(sc, A.cyl(0.075 * s, 0.22 * s, 0.075 * s, 10), M.BR, mo + Vector3(0, -0.01 * s, 0.02 * s), Vector3(0, 0, 90))
		var bar0 := mo + Vector3(0, -0.02 * s, -0.12 * s)
		var bar1 := bar0 + Vector3(0, -0.05 * s, -0.86 * s)
		b._bar(sc, bar0, bar1, 0.038 * s, 0.19 * s, M.MD)
		b._bar(sc, bar0.lerp(bar1, 0.12), bar0.lerp(bar1, 0.88), 0.044 * s, 0.085 * s, M.DK)
		# 前端导向星轮圆头
		b._p(sc, A.cyl(0.095 * s, 0.038 * s, 0.095 * s, 12), M.ST, bar1, Vector3(0, 0, 90))
		for k in 11:
			var t := float(k) / 10.0
			var q := bar0.lerp(bar1, t)
			b._box(sc, M.CH, q + Vector3(0, 0.108 * s, 0), Vector3(0.044, 0.042, 0.048) * s, Vector3(28, 0, 0))
			b._box(sc, M.CH, q + Vector3(0, -0.108 * s, 0), Vector3(0.044, 0.042, 0.048) * s, Vector3(-28, 0, 0))
		for ta in [-50.0, 0.0, 50.0]:
			var rad_a := deg_to_rad(ta)
			b._box(sc, M.CH, bar1 + Vector3(0, sin(rad_a) * 0.105 * s, -cos(rad_a) * 0.105 * s), Vector3(0.044, 0.042, 0.042) * s, Vector3(ta, 0, 0))
		b.scythes.append(sc)
	b.sac = b._box(body, b._glow(1.0), Vector3(0, by + 0.12 * s, 0.65 * s), Vector3(0.22, 0.08, 0.012) * s)
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			b._zleg(body, Vector3(sx * 0.34 * s, by - 0.08 * s, (-0.25 + i * 0.35) * s), sx * (-25.0 + i * 25.0), sx, 1.02 * s, by, 0.065 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), i == 2)


# ============================================================ 巨型攻城母舰 / 重装平台 ============================================================

## 机动无人机铸造母舰（brood）：八足重装陆地航母。多层叠甲舰体 + 舰桥指挥塔 + 颌下双联 30mm 机炮（深黑膛口）+
## 背部龙门吊架与排烟囱 + 后部铸造机库（六扇黄黑警示机库门 + 内凹琥珀熔炉装配舱）。
static func build_brood(b, body: Node3D, s: float) -> void:
	var M: Dictionary = _mats(b)
	var by := 0.95 * s
	# 十棱重装舰首主船体
	b._loft(body, HS.ngon(10, 1.0, 0.0), [[-0.74 * s, Vector2(0.38, 0.16) * s, Vector2.ZERO], [-0.6 * s, Vector2(0.58, 0.24) * s, Vector2(0, 0.02 * s)], [-0.1 * s, Vector2(0.68, 0.28) * s, Vector2(0, 0.04 * s)],
		[0.45 * s, Vector2(0.60, 0.24) * s, Vector2(0, 0.02 * s)], [0.62 * s, Vector2(0.42, 0.16) * s, Vector2.ZERO]], M.DK, Vector3(0, by, 0))
	for k in 4:
		var z0 := (-0.66 + k * 0.32) * s
		var hk := 0.30 - absf(k - 1.4) * 0.04
		b._shell(body, [M.AR, M.OL, M.AR, M.MD][k], Vector3(0, by, 0), 0.66 * s, 0.05 * s, z0, z0 + 0.4 * s,
			[[0.0, 0.85, 0.75, hk * s * 0.9], [0.3, 1.0, 1.0, hk * s * 1.05], [0.75, 1.0, 1.0, hk * s * 1.08], [1.0, 0.92, 0.9, hk * s]], Vector3.ZERO, 80.0, 8)
		b._box(body, M.ST, Vector3(0, by + hk * s * 1.02, z0 + 0.39 * s), Vector3(0.66, 0.022, 0.032) * s)
	for k in 6:
		var a := TAU * k / 6.0
		b._panels(body, Vector3(cos(a) * 0.55 * s, by, -0.05 * s + sin(a) * 0.63 * s), Vector3(0, -rad_to_deg(a) + 90.0, 0), 0.5 * s, 0.12 * s, 122 + k, 3)
	# 前端装甲舰桥指挥室（防弹眉檐 + 内凹宽幅琥珀指挥窗）
	var head := _node(body, Vector3(0, by + 0.08 * s, -0.78 * s))
	b._prism(head, _sc([Vector2(-0.32, -0.12), Vector2(0.32, -0.12), Vector2(0.38, 0.06), Vector2(0.22, 0.19), Vector2(-0.22, 0.19), Vector2(-0.38, 0.06)], s), 0.32 * s, 0.04, M.DK, Vector3.ZERO)
	b._prism(head, _sc([Vector2(-0.26, 0.11), Vector2(0.26, 0.11), Vector2(0.18, 0.24), Vector2(-0.18, 0.24)], s), 0.36 * s, 0.03, M.OL, Vector3(0, 0, -0.02 * s))
	b._box(head, M.ST, Vector3(0, 0.16 * s, -0.175 * s), Vector3(0.46, 0.026, 0.08) * s, Vector3(12, 0, 0))
	b._box(head, M.BL, Vector3(0, 0.09 * s, -0.162 * s), Vector3(0.40, 0.055, 0.02) * s)
	for vx: float in [-0.12, 0.0, 0.12]:
		b._box(head, b._glow(1.5), Vector3(vx * s, 0.09 * s, -0.172 * s), Vector3(0.09, 0.02, 0.008) * s)
	for sx: float in [-1.0, 1.0]:
		var jw := _node(head, Vector3(sx * 0.22 * s, -0.08 * s, -0.12 * s))
		b._servo(jw, Vector3.ZERO, 0.045 * s)
		b._box(jw, M.ST, Vector3(0, 0, -0.08 * s), Vector3(0.06, 0.05, 0.14) * s)
		b.jaws.append(jw)
	# 颌下双联 30mm 机炮炮廓（穿孔散热套筒 + 开槽制退器 + 深黑炮口，彻底消除粉红圆片）
	var g := _node(body, Vector3.ZERO)
	g.name = "Gun"
	b.gun = g
	var g0 := Vector3(0, by - 0.16 * s, -0.74 * s)
	b._box(g, M.DK, g0, Vector3(0.42, 0.15, 0.34) * s)
	b._box(g, M.HZ, g0 + Vector3(0, 0.05 * s, -0.05 * s), Vector3(0.43, 0.035, 0.18) * s)
	for sx: float in [-1.0, 1.0]:
		b._p(g, A.cyl(0.062 * s, 0.26 * s, 0.062 * s, 10), M.MD, g0 + Vector3(sx * 0.12 * s, 0, -0.24 * s), Vector3(90, 0, 0))
		b._p(g, A.cyl(0.042 * s, 0.54 * s, 0.042 * s, 10), M.ST, g0 + Vector3(sx * 0.12 * s, 0, -0.42 * s), Vector3(90, 0, 0))
		for k in 3:
			b._p(g, A.cyl(0.052 * s, 0.025 * s, 0.052 * s, 10), M.DK, g0 + Vector3(sx * 0.12 * s, 0, (-0.36 - k * 0.11) * s), Vector3(90, 0, 0))
		b._box(g, M.DK, g0 + Vector3(sx * 0.12 * s, 0, -0.68 * s), Vector3(0.095, 0.085, 0.11) * s)
		b._p(g, A.cyl(0.034 * s, 0.02 * s, 0.034 * s, 10), M.BL, g0 + Vector3(sx * 0.12 * s, 0, -0.738 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	_muzzle(b, g, g0 + Vector3(0, 0, -0.70 * s), s * 0.72)
	# 后部无人机铸造机库舱（脊背黄色龙门起重桁架 + 双排烟囱 + 六扇铰链装甲机库门）
	var ab := Vector3(0, by + 0.06 * s, 0.86 * s)
	b._loft(body, HS.ngon(12, 1.0, 0.0), [[-0.42 * s, Vector2(0.38, 0.28) * s, Vector2(0, 0.04 * s)], [-0.25 * s, Vector2(0.52, 0.38) * s, Vector2(0, 0.06 * s)], [0.05 * s, Vector2(0.58, 0.43) * s, Vector2(0, 0.08 * s)],
		[0.32 * s, Vector2(0.52, 0.39) * s, Vector2(0, 0.06 * s)], [0.46 * s, Vector2(0.34, 0.26) * s, Vector2(0, 0.02 * s)]], M.DK, ab)
	for k in 3:
		var z0 := (-0.34 + k * 0.24) * s
		b._shell(body, M.AR if k % 2 == 0 else M.OL, ab, 0.52 * s, 0.045 * s, z0, z0 + 0.28 * s, [[0.0, 0.9, 0.85, 0.42 * s], [0.5, 1.08, 1.0, 0.5 * s], [1.0, 0.95, 0.9, 0.44 * s]], Vector3.ZERO, 70.0, 7)
	# 背部龙门吊架与双排烟管
	b._bar(body, Vector3(0, by + 0.46 * s, -0.10 * s), ab + Vector3(0, 0.56 * s, 0.28 * s), 0.14 * s, 0.08 * s, M.HZ)
	for sx: float in [-1.0, 1.0]:
		var st_p := Vector3(sx * 0.32 * s, by + 0.38 * s, 0.34 * s)
		b._p(body, A.cyl(0.055 * s, 0.38 * s, 0.062 * s, 10), M.DK, st_p + Vector3(0, 0.15 * s, 0.04 * s), Vector3(16, 0, 0))
		b._p(body, A.cyl(0.07 * s, 0.22 * s, 0.07 * s, 10), M.RS, st_p + Vector3(0, 0.10 * s, 0.025 * s), Vector3(16, 0, 0))
		b._p(body, A.cyl(0.044 * s, 0.018 * s, 0.044 * s, 10), M.BL, st_p + Vector3(0, 0.335 * s, 0.092 * s), Vector3(16, 0, 0), Vector3.ONE, false)
	for sx: float in [-1.0, 1.0]:
		for k in 3:
			var dz := (-0.22 + k * 0.22) * s
			# 内凹暗腔 + 铸造炉琥珀工位灯 + 外推导轨
			b._box(body, M.BL, ab + Vector3(sx * 0.48 * s, 0.04 * s, dz), Vector3(0.05, 0.16, 0.16) * s)
			b._box(body, b._glow(1.4), ab + Vector3(sx * 0.495 * s, 0.08 * s, dz), Vector3(0.012, 0.045, 0.12) * s)
			b._box(body, M.ST, ab + Vector3(sx * 0.51 * s, -0.03 * s, dz), Vector3(0.08, 0.022, 0.13) * s)
			var door := _node(body, ab + Vector3(sx * 0.50 * s, 0.15 * s, dz), Vector3(0, 0, sx * -42.0))
			b._box(door, M.AR, Vector3(0, -0.08 * s, 0), Vector3(0.032, 0.19, 0.175) * s)
			b._box(door, M.HZ, Vector3(sx * 0.018 * s, -0.14 * s, 0), Vector3(0.008, 0.045, 0.16) * s)
			_reg_plate(b, door, sx)
	b._box(body, M.MD, ab + Vector3(0, 0.02 * s, 0.44 * s), Vector3(0.58, 0.30, 0.06) * s)
	for lv in 4:
		b._box(body, M.BL, ab + Vector3(0, (-0.07 + lv * 0.06) * s, 0.472 * s), Vector3(0.44, 0.03, 0.012) * s)
	b.sac = b._box(body, b._glow(1.1), ab + Vector3(0, 0.02 * s, 0.476 * s), Vector3(0.26, 0.05, 0.01) * s)
	# 八条重型矿山支腿
	for i in 4:
		for sx: float in [-1.0, 1.0]:
			_hleg(b, body, Vector3(sx * 0.48 * s, by - 0.02 * s, (-0.45 + i * 0.32) * s), sx * (-45.0 + i * 30.0), sx, s * 0.95, by, float(i % 2) * PI + (PI if sx > 0 else 0.0), 1.15, 0.45)


## 破城高炉巨像（colossus）：超重型六足移动高炉攻城平台。
## 阶梯式铆接重甲船体 + V 型液压破障推土铲 + 装甲舰桥 + 双液压重型破拆大钳（scythes）+
## 背负双高炉动力冷却塔（百叶格栅内凹炉火 + 跨接蒸汽管廊 + 四根防烫网高烟囱，彻底取代原黑方盒贴粉块）。
static func build_colossus(b, body: Node3D, s: float) -> void:
	var M: Dictionary = _mats(b)
	var by := 1.3 * s
	# 三层阶梯重甲船体
	b._loft(body, HS.keel(1.0, 1.0, 0.82, 0.2), [[-0.72 * s, Vector2(0.92, 0.25) * s, Vector2.ZERO], [-0.55 * s, Vector2(1.38, 0.42) * s, Vector2(0, 0.04 * s)], [0.1 * s, Vector2(1.52, 0.48) * s, Vector2(0, 0.06 * s)],
		[0.6 * s, Vector2(1.38, 0.43) * s, Vector2(0, 0.04 * s)], [0.76 * s, Vector2(0.94, 0.28) * s, Vector2.ZERO]], M.DK, Vector3(0, by, 0))
	for k in 3:
		var z0 := (-0.52 + k * 0.4) * s
		b._shell(body, M.AR if k != 1 else M.OL, Vector3(0, by, 0), 0.64 * s, 0.055 * s, z0, z0 + 0.46 * s, [[0.0, 0.92, 0.6, 0.32 * s], [0.4, 1.0, 0.72, 0.38 * s], [1.0, 0.95, 0.65, 0.34 * s]], Vector3.ZERO, 74.0, 7)
	b._prism(body, _sc([Vector2(-0.34, -0.32), Vector2(0.34, -0.32), Vector2(0.40, 0.1), Vector2(0.34, 0.32), Vector2(-0.34, 0.32), Vector2(-0.40, 0.1)], s), 0.14 * s, 0.03, M.MD, Vector3(0, by + 0.43 * s, -0.05 * s), Vector3(90, 0, 0))
	b._panels(body, Vector3(0, by + 0.185 * s, 0.0), Vector3(-90, 0, 0), 1.1 * s, 1.0 * s, 141, 7)
	b._panels(body, Vector3(0, by + 0.365 * s, 0.1 * s), Vector3(-90, 0, 0), 0.8 * s, 0.6 * s, 142, 5)
	for sx: float in [-1.0, 1.0]:
		b._panels(body, Vector3(sx * 0.71 * s, by, 0.3 * s), Vector3(0, 90 * sx, 0), 0.7 * s, 0.3 * s, 143 + int(sx), 4)
		b._box(body, M.ST, Vector3(sx * 0.75 * s, by + 0.10 * s, 0.1 * s), Vector3(0.03, 0.06, 1.04) * s)
		b._box(body, M.HZ, Vector3(sx * 0.755 * s, by + 0.10 * s, -0.22 * s), Vector3(0.032, 0.048, 0.32) * s)
		for k in 6:
			b._box(body, M.BR, Vector3(sx * 0.725 * s, by - 0.12 * s, (-0.3 + k * 0.15) * s), Vector3(0.016, 0.032, 0.032) * s)
	# V 型多层破障推土铲 + 液压举升缸
	var ram := _node(body, Vector3(0, by - 0.10 * s, -0.72 * s), Vector3(-28, 0, 0))
	for r in 4:
		var w := 0.74 - r * 0.12
		b._prism(ram, _sc([Vector2(-w, 0.06), Vector2(-w, -0.04), Vector2(0, -0.2), Vector2(w, -0.04), Vector2(w, 0.06), Vector2(0, -0.1)], s), 0.22 * s, 0.08, M.LT if r % 2 == 0 else M.AR, Vector3(0, r * 0.16 * s, 0))
		for sx: float in [-1.0, 1.0]:
			var em: Material = M.HZ if r == 0 else M.ST
			b._box(ram, em, Vector3(sx * w * 0.52 * s, (r * 0.16 - 0.06) * s, -0.114 * s), Vector3(w * 0.56, 0.05, 0.018) * s, Vector3(0, 0, sx * 11.0))
	for sx: float in [-1.0, 1.0]:
		b._hydraulic(body, Vector3(sx * 0.38 * s, by + 0.18 * s, -0.38 * s), Vector3(sx * 0.42 * s, by - 0.02 * s, -0.74 * s), 0.052 * s, M.DK)
	# 装甲指挥舰桥（防弹钢檐 + 五联内凹琥珀观察窗）
	var head := _node(body, Vector3(0, by + 0.54 * s, -0.38 * s))
	b._prism(head, _sc([Vector2(-0.26, 0), Vector2(0.26, 0), Vector2(0.20, 0.16), Vector2(-0.20, 0.16)], s), 0.34 * s, 0.05, M.DK, Vector3.ZERO)
	b._box(head, M.ST, Vector3(0, 0.155 * s, -0.15 * s), Vector3(0.46, 0.028, 0.10) * s, Vector3(12, 0, 0))
	b._box(head, M.BL, Vector3(0, 0.075 * s, -0.172 * s), Vector3(0.38, 0.062, 0.018) * s)
	for k in 5:
		b._box(head, b._glow(1.6), Vector3((k - 2) * 0.07 * s, 0.075 * s, -0.18 * s), Vector3(0.045, 0.022, 0.008) * s)
	# 双巨型液压工程破碎大钳（scythes）
	for sx: float in [-1.0, 1.0]:
		var sc := _node(body, Vector3(sx * 0.68 * s, by + 0.12 * s, -0.42 * s))
		b._servo(sc, Vector3.ZERO, 0.15 * s)
		var el := Vector3(sx * 0.24, 0.1, -0.42) * s
		b._bar(sc, Vector3.ZERO, el, 0.21 * s, 0.25 * s, M.AR)
		b._bar(sc, Vector3(0, 0.15 * s, 0), el + Vector3(0, 0.15 * s, 0), 0.25 * s, 0.055 * s, M.OL)
		b._hydraulic(sc, Vector3(0, -0.15 * s, 0.04 * s), el + Vector3(0, -0.13 * s, 0.02 * s), 0.048 * s, M.DK)
		b._servo(sc, el, 0.13 * s)
		var wr := el + Vector3(-sx * 0.04, -0.2, -0.34) * s
		b._bar(sc, el, wr, 0.19 * s, 0.21 * s, M.DK)
		b._hydraulic(sc, el + Vector3(sx * 0.08 * s, 0.08 * s, 0), wr + Vector3(sx * 0.08 * s, 0.08 * s, 0.06 * s), 0.038 * s, M.MD)
		b._box(sc, M.MD, wr + Vector3(0, 0, 0.08 * s), Vector3(0.30, 0.27, 0.18) * s)
		b._box(sc, M.HZ, wr + Vector3(sx * 0.152 * s, 0, 0.08 * s), Vector3(0.01, 0.18, 0.14) * s)
		b._p(sc, A.cyl(0.058 * s, 0.29 * s, 0.058 * s, 10), M.BR, wr + Vector3(0, 0, 0.04 * s))
		for j: float in [-1.0, 1.0]:
			b._prism(sc, _sc([Vector2(0, -0.085), Vector2(0.27, -0.05), Vector2(0.40, 0.06), Vector2(0.24, 0.045), Vector2(0, 0.085)], s), 0.095 * s, 0.18, M.ST, wr + Vector3(j * 0.085 * s, 0, 0), Vector3(0, 90, j * 20.0))
			b._box(sc, M.DK, wr + Vector3(j * 0.085 * s, 0.04 * s, -0.16 * s), Vector3(0.10, 0.05, 0.22) * s, Vector3(0, j * 20.0, 0))
		b.scythes.append(sc)
	# 背负双高炉动力塔（八棱锥台铸铁炉体 + 百叶格栅遮罩琥珀炉膛 + 跨接法兰蒸汽管 + 双联防烫护网烟囱）
	for sx: float in [-1.0, 1.0]:
		var rc := Vector3(sx * 0.34 * s, by + 0.44 * s, 0.36 * s)
		b._prism(body, _sc([Vector2(-0.22, 0.0), Vector2(0.22, 0.0), Vector2(0.18, 0.62), Vector2(-0.18, 0.62)], s), 0.38 * s, 0.05, M.DK, rc)
		b._box(body, M.AR, rc + Vector3(0, 0.64 * s, 0), Vector3(0.40, 0.06, 0.42) * s)
		b._panels(body, rc + Vector3(sx * 0.205 * s, 0.30 * s, 0), Vector3(0, 90 * sx, 0), 0.32 * s, 0.50 * s, 151 + int(sx), 4)
		# 后向散热竖鳍
		for k in 4:
			b._box(body, M.MD, rc + Vector3((-0.12 + k * 0.08) * s, 0.30 * s, 0.21 * s), Vector3(0.028, 0.50, 0.07) * s)
		# 正面内凹百叶散热窗（格栅条遮挡深处微光炉火，绝非外贴发光色块）
		b._box(body, M.BL, rc + Vector3(0, 0.32 * s, -0.192 * s), Vector3(0.24, 0.40, 0.024) * s)
		b._box(body, b._glow(1.5), rc + Vector3(0, 0.32 * s, -0.188 * s), Vector3(0.18, 0.32, 0.008) * s)
		for lv in 6:
			b._box(body, M.ST, rc + Vector3(0, (0.15 + lv * 0.068) * s, -0.202 * s), Vector3(0.25, 0.024, 0.028) * s, Vector3(22, 0, 0))
		# 塔顶前后双联高炉排烟管 + 铁锈防烫套筒 + 法兰箍 + 深黑烟口
		for ez: float in [-0.08, 0.10]:
			var ep := rc + Vector3(0, 0.67 * s, ez * s)
			b._p(body, A.cyl(0.055 * s, 0.46 * s, 0.065 * s, 10), M.DK, ep + Vector3(0, 0.20 * s, 0.05 * s), Vector3(14, 0, 0))
			b._p(body, A.cyl(0.072 * s, 0.26 * s, 0.072 * s, 10), M.RS, ep + Vector3(0, 0.13 * s, 0.032 * s), Vector3(14, 0, 0))
			b._p(body, A.cyl(0.076 * s, 0.03 * s, 0.076 * s, 10), M.BR, ep + Vector3(0, 0.26 * s, 0.065 * s), Vector3(14, 0, 0))
			b._p(body, A.cyl(0.044 * s, 0.02 * s, 0.044 * s, 10), M.BL, ep + Vector3(0, 0.425 * s, 0.106 * s), Vector3(14, 0, 0), Vector3.ONE, false)
	# 双塔间跨接高压蒸汽管廊 + 中央安全阀炉芯（保留 sac 引用）
	b._p(body, A.cyl(0.055 * s, 0.64 * s, 0.055 * s, 10), M.RS, Vector3(0, by + 0.88 * s, 0.34 * s), Vector3(0, 0, 90))
	for fx: float in [-0.16, 0.0, 0.16]:
		b._p(body, A.cyl(0.072 * s, 0.035 * s, 0.072 * s, 10), M.BR, Vector3(fx * s, by + 0.88 * s, 0.34 * s), Vector3(0, 0, 90))
	b.sac = b._p(body, A.cyl(0.095 * s, 0.28 * s, 0.095 * s, 10), b._glow(1.3), Vector3(0, by + 0.60 * s, 0.38 * s))
	b._p(body, A.cyl(0.115 * s, 0.045 * s, 0.115 * s, 10), M.BR, Vector3(0, by + 0.75 * s, 0.38 * s))
	# 六条超重型驻锄柱腿
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			_hleg(b, body, Vector3(sx * 0.66 * s, by - 0.05 * s, (-0.4 + i * 0.45) * s), sx * (-30.0 + i * 30.0), sx, s, by - 0.05 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), 1.05, 0.6)
