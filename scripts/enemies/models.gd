extends RefCounted
## 扩展敌对机械构装体的程序化建模库（9 种独立机型 + 复用 Bugs2 的 6 种重装机型）。
## 保持纯粹写实重工业军工/矿山工程风格：轧制装甲钢、防锈底漆红、军工橄榄绿、工程警示黄、黄铜密封法兰、镀铬液压杆与内凹光学观瞄窗；
## 彻底淘汰有机椭球囊泡、裸露刺眼光球与悬浮光圈。
## 严格保留全部动画挂点（legs / wings / sacs / crystals / plates / jaws / scythes / spinners / abdomen / crown / turret / core_mi / sac）与静态辅助接口供 boss_models 调用。

const ART = preload("res://scripts/art.gd")
const HS = preload("res://scripts/hs.gd")
const Bugs2 = preload("res://scripts/bugs2.gd")
const BugBase = preload("res://scripts/bug.gd")

const BONE := Color(0.64, 0.66, 0.69)
const C_CH := Color(0.20, 0.21, 0.23)
const C_CH2 := Color(0.38, 0.40, 0.42)
const C_GLOW := Color(1.0, 0.40, 0.10)


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


# ---------------------------------------------------------------- 工业共用构件（同时供 boss_models 调用）
static func _bone() -> Material:
	return BugBase._vmat_solid(BONE)


static func _tube(h, parent: Node3D, pts: Array, radii: Array, m, rx := 1.0, ry := 1.0, up := Vector3.UP, steps := 8, rad := 18, hard := true) -> MeshInstance3D:
	var c0 := C_CH
	var c1 := BONE
	if m is Material and m.has_meta("_vc_tint"):
		c0 = m.get_meta("_vc_tint")
		c1 = c0
	return h._sweep(parent, pts, radii, c0, c1, rx, ry, up, steps, rad, m, 0.55, hard)


## 装甲光学传感镜盒（取代仿生凸眼：铸钢遮光筒 + 顶置防弹遮阳檐 + 深黑镜腔 + 内凹低眩光光学狭缝）
static func _eye(h, parent: Node3D, pos: Vector3, r: float, c: Color) -> void:
	var DK: Material = h._vmat_solid(Color(0.12, 0.13, 0.15))
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.035))
	h._box(parent, DK, pos, Vector3(r * 2.3, r * 1.55, r * 1.35))
	h._box(parent, h._steel(), pos + Vector3(0, r * 0.78, -r * 0.35), Vector3(r * 2.45, r * 0.28, r * 1.1), Vector3(12, 0, 0))
	h._box(parent, BL, pos + Vector3(0, -r * 0.05, -r * 0.66), Vector3(r * 1.8, r * 0.78, r * 0.16))
	h._box(parent, ART.emit(c, 1.45), pos + Vector3(0, -r * 0.05, -r * 0.72), Vector3(r * 1.42, r * 0.34, r * 0.08))


## 深烟熏矿物/电极辉光材质：低反照率防阳光叠加泛白，保持深邃重工业受控辉光
static func _mineral_glow(c: Color, e := 0.52) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r * 0.16 + 0.03, c.g * 0.16 + 0.03, c.b * 0.16 + 0.04)
	m.metallic = 0.34
	m.roughness = 0.24
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m


## 工业夹持高压谐振电极/棱晶棒（六棱枪铁护套占 62% 长度 + 黄铜压紧法兰 + 烟熏晶芯 + 镀铬放电端帽，杜绝发白圆锥！）
static func _shard(h, parent: Node3D, base: Vector3, dir: Vector3, length: float, r: float, c: Color, glow := 0.55) -> MeshInstance3D:
	var d := dir.normalized()
	var y := d
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var b_xform := Basis(x, y, z)
	var core_r := r * 0.68
	var mi: MeshInstance3D = h._p(parent, ART.cyl(core_r * 0.42, length * 0.92, core_r, 6, true), _mineral_glow(c, minf(glow, 0.58)), Vector3.ZERO, Vector3.ZERO)
	mi.transform = Transform3D(b_xform, base + d * (length * 0.48))
	mi.set_meta("base_scale", Vector3.ONE)
	# 下半段重钢绝缘护套 + 黄铜锁紧压环 + 顶部镀铬电极端头
	var sl_len := length * 0.56
	var col_mi: MeshInstance3D = h._p(parent, ART.cyl(r * 0.94, sl_len, r * 1.24, 6, true), h._vmat_solid(Color(0.16, 0.17, 0.19)), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	col_mi.transform = Transform3D(b_xform, base + d * (sl_len * 0.5))
	var ring_mi: MeshInstance3D = h._p(parent, ART.cyl(r * 1.04, r * 0.18, r * 1.08, 6, true), h._brass(), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	ring_mi.transform = Transform3D(b_xform, base + d * (sl_len + r * 0.06))
	var tip_mi: MeshInstance3D = h._p(parent, ART.cyl(core_r * 0.14, length * 0.14, core_r * 0.48, 6, true), h._chrome(), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	tip_mi.transform = Transform3D(b_xform, base + d * (length * 0.95))
	return mi


static func _cluster(h, parent: Node3D, center: Vector3, scale: float, c: Color, n := 7, k := 1.0) -> Array:
	var out: Array = []
	var seeds := [[0.0, 0.0, 0.88], [0.5, -0.3, 0.62], [-0.5, -0.24, 0.58], [0.46, 0.38, 0.48], [-0.44, 0.4, 0.50], [0.06, -0.56, 0.42], [-0.04, 0.58, 0.38]]
	for i in mini(n, seeds.size()):
		var q: Array = seeds[i]
		var base: Vector3 = center + Vector3(q[0], 0.0, q[1]) * scale
		var mi := _shard(h, parent, base, Vector3(float(q[0]) * 0.42, 1.0, float(q[1]) * 0.38), float(q[2]) * scale * k, 0.155 * scale, c, 0.52)
		out.append(mi)
	return out


## 工业高压反应釜/加压储罐（上下厚重防锈钢封头包覆 75% 表面，仅中部内凹窄缝视液窗受控发光 + 六向钢制防爆护笼 + 黄铜泄压阀）
static func _sac(h, parent: Node3D, pos: Vector3, r: float, c: Color) -> MeshInstance3D:
	var DK: Material = h._vmat_solid(Color(0.15, 0.16, 0.18))
	var RS: Material = h._rust_plate()
	# 内层受控视液芯（仅在中部窄视窗露出，随呼吸微脉动）
	var mi: MeshInstance3D = h._p(parent, ART.cyl(r * 0.80, r * 0.58, r * 0.80, 12), _mineral_glow(c, 0.78), pos)
	# 下半段防锈底漆重钢罐体 + 底座法兰
	h._p(parent, ART.cyl(r * 0.94, r * 0.56, r * 0.98, 12), RS, pos - Vector3(0, r * 0.48, 0))
	h._p(parent, ART.cyl(r * 1.02, r * 0.12, r * 1.04, 12), DK, pos - Vector3(0, r * 0.72, 0))
	# 上半段枪灰拱顶封头 + 警示黄环带 + 顶置黄铜安全泄压阀
	h._p(parent, ART.cyl(r * 0.84, r * 0.52, r * 0.94, 12), DK, pos + Vector3(0, r * 0.46, 0))
	h._p(parent, ART.cyl(r * 0.95, r * 0.08, r * 0.95, 12), h._hazard_yel(), pos + Vector3(0, r * 0.25, 0))
	h._p(parent, ART.cyl(r * 0.58, r * 0.14, r * 0.80, 12), RS, pos + Vector3(0, r * 0.76, 0))
	h._p(parent, ART.cyl(r * 0.32, r * 0.20, r * 0.38, 10), h._brass(), pos + Vector3(0, r * 0.90, 0))
	# 六根外包防爆钢肋笼杆夹持中部视窗
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		h._box(parent, h._steel(), pos + Vector3(cos(a) * r * 0.92, 0, sin(a) * r * 0.92), Vector3(r * 0.11, r * 1.44, r * 0.12), Vector3(0, -rad_to_deg(a), 0))
	return mi


## 倒角轧制叠层装甲板（取代椭圆蛋壳）
static func _shell_layer(h, parent: Node3D, pos: Vector3, size: Vector3, m, tilt := 0.0) -> MeshInstance3D:
	var bev := minf(minf(size.x, size.y), size.z) * 0.22
	var mi: MeshInstance3D = h._p(parent, HS.cbox(size, bev), m, pos, Vector3(tilt, 0, 0))
	mi.set_meta("shell", true)
	return mi


static var _membrane: StandardMaterial3D
static func _wing_mat() -> StandardMaterial3D:
	if _membrane == null:
		_membrane = StandardMaterial3D.new()
		_membrane.albedo_color = Color(0.58, 0.64, 0.66, 0.42)
		_membrane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_membrane.cull_mode = BaseMaterial3D.CULL_DISABLED
		_membrane.roughness = 0.28
		_membrane.metallic = 0.35
		_membrane.rim_enabled = true
		_membrane.rim = 0.35
	return _membrane


# ---------------------------------------------------------------- 1. 高机动侦察斩击机 (mantis)
static func _mantis(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.42, 0.38, 0.26))
	var SH2: Material = h._vmat_solid(Color(0.54, 0.50, 0.36))
	var DK: Material = h._vmat_solid(Color(0.16, 0.17, 0.18))
	var by := 0.9 * s
	# 窄长箭头形倾角机舱
	h._prism(body, [Vector2(0.26, 0.36) * s, Vector2(0.35, 0.0) * s, Vector2(0.26, -0.42) * s, Vector2(-0.26, -0.42) * s, Vector2(-0.35, 0.0) * s, Vector2(-0.26, 0.36) * s],
		0.32 * s, 0.06, DK, Vector3(0, by, 0.0), Vector3(90, 0, 0))
	h._prism(body, [Vector2(0.20, 0.32) * s, Vector2(0.26, 0.0) * s, Vector2(0.20, -0.35) * s, Vector2(-0.20, -0.35) * s, Vector2(-0.26, 0.0) * s, Vector2(-0.20, 0.32) * s],
		0.15 * s, 0.1, SH, Vector3(0, by + 0.2 * s, 0.0), Vector3(90, 0, 0))
	h._panels(body, Vector3(0, by + 0.28 * s, 0.0), Vector3(-90, 0, 0), 0.46 * s, 0.66 * s, 61, 5)
	# 背脊散热百叶鳍与双排烟尾口（取代仿生尖刺）
	for i in 3:
		h._box(body, h._steel(), Vector3(0, by + 0.31 * s, (0.16 - i * 0.18) * s), Vector3(0.06, 0.12, 0.12) * s, Vector3(-18, 0, 0))
	for sx: float in [-1.0, 1.0]:
		h._p(body, ART.cyl(0.038 * s, 0.18 * s, 0.044 * s, 8), DK, Vector3(sx * 0.12 * s, by + 0.08 * s, 0.44 * s), Vector3(-72, 0, 0))
	# 铰接机械颈 + 楔形激光测距头 + 双鞭状通讯天线
	var head := Node3D.new()
	head.position = Vector3(0, by + 0.14 * s, -0.44 * s)
	body.add_child(head)
	h._bar(head, Vector3.ZERO, Vector3(0, 0.14 * s, -0.32 * s), 0.14 * s, 0.15 * s, DK)
	h._hydraulic(head, Vector3(0, -0.08 * s, -0.02 * s), Vector3(0, 0.06 * s, -0.28 * s), 0.028 * s, SH)
	h._prism(head, [Vector2(0.18, 0.09) * s, Vector2(0.13, -0.17) * s, Vector2(-0.13, -0.17) * s, Vector2(-0.18, 0.09) * s], 0.28 * s, 0.08, SH2, Vector3(0, 0.16 * s, -0.36 * s), Vector3(-14, 0, 0))
	for sx: float in [-1.0, 1.0]:
		_eye(h, head, Vector3(sx * 0.095 * s, 0.18 * s, -0.46 * s), 0.052 * s, Color(1.0, 0.45, 0.12))
		h._p(head, ART.cyl(0.02 * s, 0.04 * s, 0.024 * s, 8), h._brass(), Vector3(sx * 0.11 * s, 0.25 * s, -0.28 * s))
		h._bar(head, Vector3(sx * 0.11, 0.26, -0.28) * s, Vector3(sx * 0.24, 0.72, -0.02) * s, 0.012 * s, 0.012 * s, h._steel())
	# 双折式高频液压工业剪刃臂（scythes）
	for sx: float in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(sx * 0.30 * s, by + 0.06 * s, -0.16 * s)
		sh.rotation_degrees = Vector3(0, sx * 16.0, 0)
		body.add_child(sh)
		h._servo(sh, Vector3.ZERO, 0.11 * s)
		var el := Vector3(sx * 0.24, 0.10, -0.34) * s
		var wr := Vector3(sx * 0.32, 0.18, -0.70) * s
		h._bar(sh, Vector3.ZERO, el, 0.11 * s, 0.14 * s, DK)
		h._hydraulic(sh, Vector3(0, -0.09 * s, -0.02 * s), el + Vector3(0, -0.07 * s, 0.04 * s), 0.028 * s, SH)
		h._servo(sh, el, 0.085 * s)
		h._bar(sh, el, wr, 0.09 * s, 0.11 * s, SH2)
		h._box(sh, h._hazard_yel(), el.lerp(wr, 0.5) + Vector3(sx * 0.048 * s, 0, 0), Vector3(0.008, 0.045, 0.18) * s)
		h._jag(sh, 0.20 * s, 1.08 * s, 0.045 * s, h._chrome(), Vector3(sx * 0.32, 0.20, -0.76) * s, Vector3(-58, sx * 12.0, 0), 5, -1.0, sx * 0.08 * s)
		h._bar(sh, wr, wr + Vector3(sx * 0.04, -0.52, -0.38) * s, 0.052 * s, 0.065 * s, DK)
		h.scythes.append(sh)
	# 四足反关节高速机械腿（加粗承力截面）
	for sx: float in [-1.0, 1.0]:
		h._zleg(body, Vector3(sx * 0.25 * s, by - 0.16 * s, -0.22 * s), sx * -28.0, sx, 0.84 * s, by * 1.15, 0.095 * s, PI if sx > 0 else 0.0, true)
		h._zleg(body, Vector3(sx * 0.27 * s, by - 0.16 * s, 0.26 * s), sx * 30.0, sx, 0.72 * s, by * 1.05, 0.085 * s, 0.0 if sx > 0 else PI, false)


# ---------------------------------------------------------------- 2. 重装高压危化品自爆工兵车 (bomber)
static func _bomber(h, body: Node3D, s: float) -> void:
	var OL: Material = h._vmat_matte(Color(0.32, 0.34, 0.25))
	var RS: Material = h._rust_plate()
	var DK: Material = h._vmat_solid(Color(0.16, 0.17, 0.19))
	var HZ: Material = h._hazard_yel()
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.035))
	var by := 0.54 * s
	# 1. 重型八角铆接托盘底盘 + 两侧防撞黄黑裙板
	h._prism(body, [Vector2(-0.42, -0.52) * s, Vector2(0.42, -0.52) * s, Vector2(0.54, 0.0) * s, Vector2(0.44, 0.58) * s, Vector2(-0.44, 0.58) * s, Vector2(-0.54, 0.0) * s],
		0.28 * s, 0.06, DK, Vector3(0, by - 0.04 * s, 0.04 * s), Vector3(90, 0, 0))
	for sx: float in [-1.0, 1.0]:
		h._box(body, OL, Vector3(sx * 0.50 * s, by + 0.04 * s, 0.04 * s), Vector3(0.06, 0.22, 0.84) * s)
		for k in 4:
			h._box(body, HZ if k % 2 == 0 else BL, Vector3(sx * 0.532 * s, by + 0.04 * s, (-0.26 + k * 0.18) * s), Vector3(0.01, 0.12, 0.15) * s)
		# 外包钢制防滚保护笼肋梁
		for rz: float in [-0.14, 0.12, 0.36]:
			h._bar(body, Vector3(sx * 0.46, by + 0.10, rz) * s, Vector3(sx * 0.44, by + 0.62, rz) * s, 0.045 * s, 0.045 * s, h._steel())
			h._bar(body, Vector3(sx * 0.44, by + 0.62, rz) * s, Vector3(sx * 0.20, by + 0.92, rz) * s, 0.042 * s, 0.042 * s, h._steel())
	# 2. 背负三联工业危化燃料高压罐组（登记到 sacs 保留充压膨胀动画，绝无有机脓疱！）
	var main_pos := Vector3(0, by + 0.52 * s, 0.10 * s)
	var main_tank: MeshInstance3D = h._p(body, ART.cyl(0.36 * s, 0.78 * s, 0.36 * s, 14), RS, main_pos, Vector3(90, 0, 0))
	h.sacs.append(main_tank)
	for bz: float in [-0.20, 0.10, 0.38]:
		h._p(body, ART.cyl(0.38 * s, 0.045 * s, 0.38 * s, 14), DK, Vector3(0, by + 0.52 * s, bz * s), Vector3(90, 0, 0))
	# 两侧副储气钢瓶（同样随充压脉动）
	for sx: float in [-1.0, 1.0]:
		var sp := Vector3(sx * 0.34 * s, by + 0.36 * s, 0.12 * s)
		var sub_tank: MeshInstance3D = h._p(body, ART.cyl(0.16 * s, 0.66 * s, 0.16 * s, 12), HZ, sp, Vector3(90, 0, 0))
		h.sacs.append(sub_tank)
		h._p(body, ART.cyl(0.11 * s, 0.05 * s, 0.11 * s, 10), h._brass(), sp + Vector3(0, 0, -0.34 * s), Vector3(90, 0, 0))
		# 受护框包裹的窄缝琥珀液位计
		h._box(body, BL, sp + Vector3(sx * 0.155 * s, 0.02 * s, 0), Vector3(0.02, 0.06, 0.36) * s)
		h._box(body, ART.emit(Color(1.0, 0.45, 0.10), 1.5), sp + Vector3(sx * 0.164 * s, 0.02 * s, 0), Vector3(0.008, 0.024, 0.30) * s)
	# 罐顶高压泄压法兰阀座与压力红灯芯
	var v_pos := main_pos + Vector3(0, 0.38 * s, 0.0)
	h._p(body, ART.cyl(0.16 * s, 0.08 * s, 0.19 * s, 12), DK, v_pos)
	h._p(body, ART.cyl(0.11 * s, 0.06 * s, 0.11 * s, 10), h._brass(), v_pos + Vector3(0, 0.06 * s, 0))
	var fuse_core: MeshInstance3D = h._p(body, ART.cyl(0.085 * s, 0.04 * s, 0.085 * s, 10), ART.emit(Color(1.0, 0.42, 0.10), 1.6), v_pos + Vector3(0, 0.10 * s, 0), Vector3.ZERO, Vector3.ONE, false)
	h.sacs.append(fuse_core)
	# 后端法兰端盖 + 黄铜管道接口
	h._p(body, ART.cyl(0.28 * s, 0.06 * s, 0.32 * s, 14), h._steel(), main_pos + Vector3(0, 0, 0.41 * s), Vector3(90, 0, 0))
	# 3. 前端防爆起爆头舱 + 液压破障碰发钳（jaws）
	var head := Node3D.new()
	head.position = Vector3(0, by + 0.02 * s, -0.50 * s)
	body.add_child(head)
	h._prism(head, [Vector2(0.28, 0.16) * s, Vector2(0.24, -0.14) * s, Vector2(-0.24, -0.14) * s, Vector2(-0.28, 0.16) * s], 0.24 * s, 0.06, DK, Vector3.ZERO, Vector3(-10, 0, 0))
	h._box(head, HZ, Vector3(0, 0.12 * s, -0.122 * s), Vector3(0.46, 0.055, 0.016) * s)
	for sx: float in [-1.0, 1.0]:
		_eye(h, head, Vector3(sx * 0.14 * s, 0.04 * s, -0.13 * s), 0.046 * s, Color(1.0, 0.42, 0.10))
		var j := Node3D.new()
		j.position = Vector3(sx * 0.16 * s, -0.06 * s, -0.10 * s)
		head.add_child(j)
		h._bar(j, Vector3.ZERO, Vector3(sx * 0.04, -0.02, -0.18) * s, 0.07 * s, 0.08 * s, OL)
		h._jag(j, 0.10 * s, 0.26 * s, 0.05 * s, h._steel(), Vector3(sx * 0.03 * s, -0.01 * s, -0.10 * s), Vector3(0, sx * -10.0, sx * 22.0), 3, -1.0, 0.0)
		h.jaws.append(j)
	# 4. 六条铰接工程步足
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			h._zleg(body, Vector3(sx * 0.38 * s, by - 0.14 * s, (-0.28 + i * 0.28) * s), sx * (-28.0 + i * 28.0), sx, 0.58 * s, by, 0.072 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), i == 0)


# ---------------------------------------------------------------- 3. 棱镜偏折重装采矿车 (crystal_bug)
static func _crystal(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_solid(Color(0.26, 0.28, 0.34))
	var SH2: Material = h._vmat_matte(Color(0.38, 0.40, 0.46))
	var DK: Material = h._vmat_solid(Color(0.13, 0.14, 0.17))
	var CR := Color(0.56, 0.76, 1.0)
	var by := 0.56 * s
	# 宽扁八角重装底盘（取代圆蛋壳）
	h._prism(body, [Vector2(-0.52, -0.62) * s, Vector2(0.52, -0.62) * s, Vector2(0.68, 0.0) * s, Vector2(0.54, 0.68) * s, Vector2(-0.54, 0.68) * s, Vector2(-0.68, 0.0) * s],
		0.34 * s, 0.06, DK, Vector3(0, by + 0.04 * s, 0.04 * s), Vector3(90, 0, 0))
	h._prism(body, [Vector2(-0.40, -0.46) * s, Vector2(0.40, -0.46) * s, Vector2(0.52, 0.0) * s, Vector2(0.42, 0.52) * s, Vector2(-0.42, 0.52) * s, Vector2(-0.52, 0.0) * s],
		0.18 * s, 0.08, SH, Vector3(0, by + 0.26 * s, 0.04 * s), Vector3(90, 0, 0))
	h._panels(body, Vector3(0, by + 0.36 * s, 0.04 * s), Vector3(-90, 0, 0), 0.78 * s, 0.86 * s, 81, 6)
	for sx: float in [-1.0, 1.0]:
		for k in 2:
			h._prism(body, [Vector2(-0.28, 0.16) * s, Vector2(0.28, 0.14) * s, Vector2(0.24, -0.18) * s, Vector2(-0.26, -0.16) * s],
				0.07 * s, 0.1, SH2, Vector3(sx * 0.65 * s, by + 0.04 * s, (-0.24 + k * 0.50) * s), Vector3(0, 90 * sx, sx * -8.0))
			h._box(body, h._hazard_yel(), Vector3(sx * 0.69 * s, by - 0.04 * s, (-0.24 + k * 0.50) * s), Vector3(0.012, 0.055, 0.34) * s)
	# 背部法兰夹持高折射率石英棱晶阵列（crystals）
	var cluster := Node3D.new()
	cluster.position = Vector3(0, by + 0.36 * s, 0.04 * s)
	body.add_child(cluster)
	h._p(cluster, ART.cyl(0.42 * s, 0.08 * s, 0.46 * s, 8), DK, Vector3(0, 0.02 * s, 0))
	for mi in _cluster(h, cluster, Vector3(0, 0.04 * s, 0), 0.36 * s, CR, 7, 1.0):
		h.crystals.append(mi)
	# 正面重型钢框六角偏折光学防盾（四角钢卡钳固定）
	var front := Node3D.new()
	front.position = Vector3(0, by + 0.14 * s, -0.62 * s)
	front.rotation_degrees = Vector3(-22, 0, 0)
	body.add_child(front)
	h._prism(front, [Vector2(0.34, 0.24) * s, Vector2(0.42, 0.0) * s, Vector2(0.30, -0.26) * s, Vector2(-0.30, -0.26) * s, Vector2(-0.42, 0.0) * s, Vector2(-0.34, 0.24) * s],
		0.10 * s, 0.08, DK, Vector3.ZERO)
	h._prism(front, [Vector2(0.26, 0.18) * s, Vector2(0.33, 0.0) * s, Vector2(0.22, -0.19) * s, Vector2(-0.22, -0.19) * s, Vector2(-0.33, 0.0) * s, Vector2(-0.26, 0.18) * s],
		0.08 * s, 0.14, _mineral_glow(CR, 0.62), Vector3(0, 0, -0.03 * s))
	for q: Vector2 in [Vector2(-0.30, 0.20), Vector2(0.30, 0.20), Vector2(-0.28, -0.22), Vector2(0.28, -0.22)]:
		h._box(front, h._steel(), Vector3(q.x * s, q.y * s, -0.055 * s), Vector3(0.08, 0.06, 0.05) * s)
	for sx: float in [-1.0, 1.0]:
		_eye(h, body, Vector3(sx * 0.24 * s, by + 0.12 * s, -0.64 * s), 0.048 * s, CR)
	# 四条重型液压活塞腿
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			h._pleg(body, Vector3(sx * 0.60 * s, by - 0.06 * s, (-0.34 + i * 0.62) * s), sx * (-22.0 + i * 26.0), sx, s, by - 0.02 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0))


# ---------------------------------------------------------------- 4. 硬岩盾构潜地掘进机 (burrower)
static func _burrower(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.44, 0.35, 0.22))
	var SH2: Material = h._vmat_solid(Color(0.32, 0.33, 0.35))
	var DK: Material = h._vmat_solid(Color(0.15, 0.16, 0.18))
	var ST: Material = h._steel()
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.035))
	var by := 0.55 * s
	# 三节八棱铰接盾构机身（取代椭圆球）
	for seg_i in 3:
		var sc_f := 1.0 - seg_i * 0.18
		var sz_z := (0.08 + seg_i * 0.30) * s
		h._p(body, ART.cyl(0.40 * sc_f * s, 0.30 * s, 0.44 * sc_f * s, 8), SH if seg_i % 2 == 0 else SH2, Vector3(0, by + (0.02 - seg_i * 0.02) * s, sz_z), Vector3(90, 0, 0))
		h._p(body, ART.cyl(0.45 * sc_f * s, 0.04 * s, 0.45 * sc_f * s, 8), DK, Vector3(0, by + (0.02 - seg_i * 0.02) * s, sz_z - 0.13 * s), Vector3(90, 0, 0))
	h._panels(body, Vector3(0, by + 0.38 * s, 0.14 * s), Vector3(-90, 0, 0), 0.46 * s, 0.48 * s, 91, 5)
	# 旋转碳化钨螺旋盾构刀盘（登记到 spinners 实时旋转！）+ 工程黄护盾法兰环
	h._p(body, ART.cyl(0.43 * s, 0.10 * s, 0.45 * s, 12), DK, Vector3(0, by, -0.14 * s), Vector3(90, 0, 0))
	h._p(body, ART.cyl(0.455 * s, 0.038 * s, 0.455 * s, 12), h._hazard_yel(), Vector3(0, by, -0.16 * s), Vector3(90, 0, 0))
	var drill := Node3D.new()
	drill.position = Vector3(0, by, -0.22 * s)
	body.add_child(drill)
	h._p(drill, ART.cyl(0.24 * s, 0.24 * s, 0.38 * s, 12), DK, Vector3(0, 0, -0.12 * s), Vector3(-90, 0, 0))
	h._p(drill, ART.cyl(0.11 * s, 0.24 * s, 0.24 * s, 12), ST, Vector3(0, 0, -0.34 * s), Vector3(-90, 0, 0))
	h._p(drill, ART.cyl(0.0, 0.22 * s, 0.11 * s, 10), h._chrome(), Vector3(0, 0, -0.55 * s), Vector3(-90, 0, 0))
	for k in 3:
		for i in 10:
			var u := float(i) / 9.0
			var a := k * TAU / 3.0 + u * 2.2
			var r: float = (0.36 - u * 0.27) * s
			h._box(drill, h._chrome(), Vector3(cos(a) * r, sin(a) * r, (-0.04 - u * 0.44) * s), Vector3(0.095, 0.042, 0.065) * s, Vector3(0, 0, rad_to_deg(a)))
	for rc_i in 4:
		var ra := TAU * rc_i / 4.0 + 0.4
		var cp := Vector3(cos(ra) * 0.31, sin(ra) * 0.31, -0.18) * s
		h._p(drill, ART.cyl(0.075 * s, 0.036 * s, 0.075 * s, 10), h._brass(), cp, Vector3(0, 0, rad_to_deg(ra)))
	h.spinners.append([drill, Vector3.BACK, 1.8, 28.0])
	# 顶部潜望测距盒
	_eye(h, body, Vector3(0, by + 0.44 * s, -0.08 * s), 0.055 * s, Color(1.0, 0.45, 0.12))
	# 尾部双排渣钢筒（深黑排砂膛口）+ 液压尾锚驻锄
	for sx: float in [-1.0, 1.0]:
		var ep := Vector3(sx * 0.18 * s, by + 0.04 * s, 0.80 * s)
		h._p(body, ART.cyl(0.085 * s, 0.26 * s, 0.105 * s, 12), DK, ep, Vector3(-76, 0, 0))
		h._p(body, ART.cyl(0.068 * s, 0.02 * s, 0.068 * s, 12), BL, ep + Vector3(0, 0.03 * s, 0.132 * s), Vector3(-76, 0, 0), Vector3.ONE, false)
	h._box(body, ST, Vector3(0, by - 0.08 * s, 0.84 * s), Vector3(0.24, 0.08, 0.18) * s, Vector3(22, 0, 0))
	# 六条液压挖掘铲斗腿（精确对齐地面高度，铲爪对称朝外）
	var hip_y := by - 0.12 * s
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			var hip := Node3D.new()
			hip.position = Vector3(sx * 0.36 * s, hip_y, (-0.18 + i * 0.32) * s)
			hip.rotation_degrees = Vector3(0, sx * (-24.0 + i * 24.0), 0)
			body.add_child(hip)
			var knee := Vector3(sx * 0.22 * s, 0.08 * s, 0)
			var foot := Vector3(sx * 0.38 * s, -hip_y + 0.03 * s, 0.02 * s)
			h._servo(hip, Vector3.ZERO, 0.075 * s)
			h._bar(hip, Vector3.ZERO, knee, 0.12 * s, 0.14 * s, SH2)
			h._hydraulic(hip, Vector3(0, -0.07 * s, 0), knee + Vector3(-sx * 0.04 * s, -0.05 * s, 0), 0.024 * s, DK)
			h._servo(hip, knee, 0.065 * s)
			h._bar(hip, knee, foot, 0.10 * s, 0.10 * s, SH)
			h._foot_pad(hip, foot, 0.16 * s)
			h._box(hip, ST, foot + Vector3(sx * 0.08 * s, 0.04 * s, 0), Vector3(0.10, 0.05, 0.14) * s, Vector3(0, 0, sx * -22.0))
			hip.set_meta("side", sx)
			hip.set_meta("phase", float(i % 2) * PI + (PI if sx > 0 else 0.0))
			hip.set_meta("base_y", hip.rotation.y)
			h.legs.append(hip)


# ---------------------------------------------------------------- 5. 废土改装电子干扰甲虫车 (mech_beetle)
static func _mech_beetle(h, body: Node3D, s: float) -> void:
	var OL: Material = h._vmat_matte(Color(0.29, 0.33, 0.25))
	var RS: Material = h._rust_plate()
	var DK: Material = h._vmat_solid(Color(0.15, 0.16, 0.18))
	var PL: Material = h._vmat_matte(Color(0.48, 0.50, 0.52))
	var HZ: Material = h._hazard_yel()
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.035))
	var by := 0.66 * s
	# 重型铆接六角装甲车体 + 军工橄榄绿/防锈红拼焊上甲板
	h._prism(body, [Vector2(-0.52, -0.62) * s, Vector2(0.52, -0.62) * s, Vector2(0.68, 0.0) * s, Vector2(0.54, 0.72) * s, Vector2(-0.54, 0.72) * s, Vector2(-0.68, 0.0) * s],
		0.36 * s, 0.06, DK, Vector3(0, by, 0), Vector3(90, 0, 0))
	h._prism(body, [Vector2(-0.40, -0.44) * s, Vector2(0.40, -0.44) * s, Vector2(0.52, 0.04) * s, Vector2(0.42, 0.60) * s, Vector2(-0.42, 0.60) * s, Vector2(-0.52, 0.04) * s],
		0.20 * s, 0.08, OL, Vector3(0, by + 0.26 * s, 0), Vector3(90, 0, 0))
	h._panels(body, Vector3(0, by + 0.365 * s, 0.02 * s), Vector3(-90, 0, 0), 0.68 * s, 0.76 * s, 101, 6,
		[DK, OL, RS, PL])
	# 正面拼焊推土防弹首上板 + 双拖车钩环 + 装甲观瞄镜盒
	var front := Node3D.new()
	front.position = Vector3(0, by + 0.04 * s, -0.58 * s)
	front.rotation_degrees = Vector3(-20, 0, 0)
	body.add_child(front)
	h._prism(front, [Vector2(0.38, 0.22) * s, Vector2(0.34, -0.20) * s, Vector2(0, -0.26) * s, Vector2(-0.34, -0.20) * s, Vector2(-0.38, 0.22) * s],
		0.10 * s, 0.07, PL, Vector3.ZERO)
	h._prism(front, [Vector2(0.28, 0.14) * s, Vector2(0.24, -0.13) * s, Vector2(0, -0.18) * s, Vector2(-0.24, -0.13) * s, Vector2(-0.28, 0.14) * s],
		0.11 * s, 0.08, RS, Vector3(0, -0.02 * s, -0.04 * s))
	for k in 4:
		h._box(front, h._steel(), Vector3((-0.27 + k * 0.18) * s, 0.16 * s, -0.07 * s), Vector3(0.035, 0.035, 0.024) * s)
	for sx: float in [-1.0, 1.0]:
		_eye(h, front, Vector3(sx * 0.20 * s, 0.10 * s, -0.10 * s), 0.046 * s, Color(1.0, 0.45, 0.12))
		h._p(front, ART.torus(0.032 * s, 0.048 * s, 10), h._steel(), Vector3(sx * 0.24 * s, -0.14 * s, -0.08 * s), Vector3(0, 90, 0))
	# 尾部外挂柴油发电机箱 + 百叶排风窗 + 单侧排烟管
	var gen := Vector3(0, by + 0.24 * s, 0.56 * s)
	h._box(body, DK, gen, Vector3(0.58, 0.28, 0.30) * s)
	for lv in 4:
		h._box(body, BL, gen + Vector3(0, (-0.06 + lv * 0.045) * s, 0.152 * s), Vector3(0.42, 0.025, 0.012) * s)
	h._p(body, ART.cyl(0.042 * s, 0.38 * s, 0.048 * s, 10), RS, gen + Vector3(0.24 * s, 0.24 * s, 0.04 * s), Vector3(14, 0, 0))
	h._p(body, ART.cyl(0.034 * s, 0.02 * s, 0.034 * s, 10), BL, gen + Vector3(0.24 * s, 0.425 * s, 0.088 * s), Vector3(14, 0, 0), Vector3.ONE, false)
	# 背部角钢桁架天线塔 + 固定前倾角底座（解决 enemy.gd 重置 turret.rotation.x 为 0 的问题！）+ 四脚馈源抛物面干扰天线盘（彻底移除发光紫呼啦圈！）
	var mast := Node3D.new()
	mast.position = Vector3(0, by + 0.38 * s, 0.10 * s)
	body.add_child(mast)
	h._box(mast, DK, Vector3(0, 0.05 * s, 0), Vector3(0.28, 0.10, 0.28) * s)
	for mx: float in [-0.08, 0.08]:
		for mz: float in [-0.08, 0.08]:
			h._bar(mast, Vector3(mx, 0.06, mz) * s, Vector3(mx * 0.55, 0.46, mz * 0.55) * s, 0.028 * s, 0.028 * s, h._steel())
	var dish_mount := Node3D.new()
	dish_mount.position = Vector3(0, 0.50 * s, -0.02 * s)
	dish_mount.rotation_degrees = Vector3(-52, 0, 0)
	mast.add_child(dish_mount)
	var dish := Node3D.new()
	dish_mount.add_child(dish)
	h._p(dish, ART.cyl(0.14 * s, 0.10 * s, 0.16 * s, 12), DK, Vector3(0, -0.04 * s, 0))
	# 多棱金属抛物反射盘（外圈钢质卷边 + 内部辐射加强筋 + 四脚馈源支架 + 黄铜波导馈源头）
	h._p(dish, ART.cyl(0.38 * s, 0.09 * s, 0.14 * s, 16), PL, Vector3(0, 0.03 * s, 0))
	h._p(dish, ART.cyl(0.35 * s, 0.03 * s, 0.12 * s, 16), DK, Vector3(0, 0.068 * s, 0))
	h._p(dish, ART.torus(0.365 * s, 0.395 * s, 16), HZ, Vector3(0, 0.075 * s, 0))
	for di in 4:
		var da := TAU * di / 4.0 + PI * 0.25
		h._bar(dish, Vector3(cos(da) * 0.34, 0.07, sin(da) * 0.34) * s, Vector3(0, 0.32, 0) * s, 0.018 * s, 0.018 * s, h._steel())
	h._p(dish, ART.cyl(0.052 * s, 0.09 * s, 0.065 * s, 10), h._brass(), Vector3(0, 0.32 * s, 0))
	h._p(dish, ART.cyl(0.032 * s, 0.025 * s, 0.032 * s, 10), ART.emit(Color(1.0, 0.45, 0.12), 1.6), Vector3(0, 0.37 * s, 0), Vector3.ZERO, Vector3.ONE, false)
	h.turret = dish
	# 侧腹黄黑工程警示条 + 铜质高压母排管 + 铆钉排
	for sx: float in [-1.0, 1.0]:
		for k in 5:
			h._box(body, HZ if k % 2 == 0 else BL, Vector3(sx * 0.645 * s, by - 0.02 * s, (-0.22 + k * 0.11) * s), Vector3(0.014, 0.11, 0.105) * s)
		h._p(body, ART.cyl(0.018 * s, 0.44 * s, 0.018 * s, 8), h._brass(), Vector3(sx * 0.655 * s, by + 0.12 * s, 0.18 * s), Vector3(90, 0, 0))
		for k in 3:
			h._box(body, h._steel(), Vector3(sx * 0.64 * s, by + 0.20 * s, (-0.12 + k * 0.16) * s), Vector3(0.016, 0.032, 0.032) * s)
	# 四条加固机械步足
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			h._mleg(body, Vector3(sx * 0.56 * s, by - 0.08 * s, (-0.28 + i * 0.5) * s), sx * (-20.0 + i * 40.0), sx, 1.15 * s, by * 1.25, 0.13 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0))


# ---------------------------------------------------------------- 6. 扑翼俯冲猎杀无人机 (wasp)
static func _wasp(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.48, 0.39, 0.20))
	var SH2: Material = h._vmat_solid(Color(0.32, 0.34, 0.36))
	var DK: Material = h._vmat_solid(Color(0.15, 0.16, 0.18))
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.035))
	var by := 0.72 * s
	# 切面涡轮核心机身（取代椭球虫胸）
	h._prism(body, [Vector2(-0.20, -0.24) * s, Vector2(0.20, -0.24) * s, Vector2(0.26, 0.0) * s, Vector2(0.20, 0.26) * s, Vector2(-0.20, 0.26) * s, Vector2(-0.26, 0.0) * s],
		0.44 * s, 0.06, DK, Vector3(0, by, -0.06 * s), Vector3(90, 0, 0))
	h._panels(body, Vector3(0, by + 0.225 * s, -0.06 * s), Vector3(-90, 0, 0), 0.34 * s, 0.36 * s, 111, 3)
	for sx: float in [-1.0, 1.0]:
		# 两侧涡轮进气道口
		h._p(body, ART.cyl(0.085 * s, 0.26 * s, 0.075 * s, 10), SH2, Vector3(sx * 0.24 * s, by + 0.04 * s, -0.08 * s), Vector3(90, 0, 0))
		h._p(body, ART.cyl(0.065 * s, 0.02 * s, 0.065 * s, 10), BL, Vector3(sx * 0.24 * s, by + 0.04 * s, -0.212 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	# 铰接矢量尾梁 + 碳化钨动能穿甲尾刺（abdomen）
	var abd := Node3D.new()
	abd.position = Vector3(0, by - 0.02 * s, 0.18 * s)
	body.add_child(abd)
	h._p(abd, ART.cyl(0.16 * s, 0.36 * s, 0.21 * s, 8), SH, Vector3(0, 0, 0.16 * s), Vector3(-90, 0, 0))
	h._p(abd, ART.cyl(0.09 * s, 0.26 * s, 0.15 * s, 8), DK, Vector3(0, -0.02 * s, 0.44 * s), Vector3(-90, 0, 0))
	h._box(abd, h._hazard_yel(), Vector3(0, 0.14 * s, 0.22 * s), Vector3(0.24, 0.03, 0.09) * s)
	h._p(abd, ART.cyl(0.0, 0.42 * s, 0.068 * s, 6), h._chrome(), Vector3(0, -0.04 * s, 0.74 * s), Vector3(-96, 0, 0))
	h.sac = h._box(abd, ART.emit(Color(1.0, 0.45, 0.12), 1.3), Vector3(0, 0.09 * s, 0.46 * s), Vector3(0.10, 0.03, 0.08) * s)
	h.abdomen = abd
	# 光电转塔机鼻 + 颌下液压微切钳（jaws）
	var head := Node3D.new()
	head.position = Vector3(0, by + 0.02 * s, -0.34 * s)
	body.add_child(head)
	h._prism(head, [Vector2(0.18, 0.13) * s, Vector2(0.14, -0.14) * s, Vector2(-0.14, -0.14) * s, Vector2(-0.18, 0.13) * s], 0.24 * s, 0.06, SH, Vector3(0, 0, -0.04 * s))
	_eye(h, head, Vector3(0, 0.03 * s, -0.16 * s), 0.068 * s, Color(1.0, 0.45, 0.12))
	for sx: float in [-1.0, 1.0]:
		var j := Node3D.new()
		j.position = Vector3(sx * 0.09 * s, -0.09 * s, -0.14 * s)
		head.add_child(j)
		h._jag(j, 0.065 * s, 0.20 * s, 0.024 * s, h._steel(), Vector3.ZERO, Vector3(0, 0, 60 * sx), 2, -1.0, 0.0)
		h.jaws.append(j)
	# 两对钛合金前缘梁扑翼叶片（wings）
	for sx: float in [-1.0, 1.0]:
		for pair in 2:
			var w := Node3D.new()
			w.position = Vector3(sx * 0.18 * s, by + 0.20 * s, (-0.16 + pair * 0.20) * s)
			w.rotation_degrees = Vector3(-90, sx * (26.0 + pair * 16.0), 0)
			w.set_meta("side", sx)
			body.add_child(w)
			var wlen: float = (0.94 - pair * 0.24) * s
			var wid: float = (0.28 - pair * 0.06) * s
			h._servo(w, Vector3.ZERO, 0.042 * s)
			h._bar(w, Vector3.ZERO, Vector3(0, wlen * 0.94, 0.04 * s), 0.026 * s, 0.032 * s, h._steel())
			h._prism(w, [Vector2(0.0, 0.0), Vector2(wid * 0.5, wlen * 0.4), Vector2(wid * 0.18, wlen), Vector2(-wid * 0.36, wlen * 0.62), Vector2(-wid * 0.5, 0.1)],
				0.016 * s, 0.02, _wing_mat(), Vector3.ZERO, Vector3(0, sx * 90.0, 0))
			h.wings.append(w)
	# 六条折叠伺服起落驻爪（legs：髋伺服 + 装甲股臂 + 膝伺服 + 锻钢抓地钩爪）
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			var hip := Node3D.new()
			hip.position = Vector3(sx * 0.15 * s, by - 0.18 * s, (-0.17 + i * 0.17) * s)
			hip.rotation_degrees = Vector3(0, sx * (-16.0 + i * 16.0), 0)
			body.add_child(hip)
			var knee := Vector3(sx * 0.14 * s, -0.05 * s, 0)
			var tip := Vector3(sx * 0.23 * s, -0.25 * s, 0.08 * s)
			h._servo(hip, Vector3.ZERO, 0.038 * s)
			h._limb(hip, Vector3.ZERO, knee, 0.064 * s, 0.072 * s, DK, 0.82, 1.16)
			h._servo(hip, knee, 0.032 * s)
			h._limb(hip, knee, tip, 0.048 * s, 0.055 * s, SH2, 0.65, 1.10)
			h._box(hip, h._steel(), tip + Vector3(sx * 0.02 * s, -0.02 * s, -0.02 * s), Vector3(0.036, 0.052, 0.085) * s, Vector3(24, 0, sx * -18.0))
			hip.set_meta("side", sx)
			hip.set_meta("phase", float(i % 2) * PI + (PI if sx > 0 else 0.0))
			hip.set_meta("base_y", hip.rotation.y)
			h.legs.append(hip)


# ---------------------------------------------------------------- 7. 机动电磁护盾发生器平台 (shielder)
static func _shielder(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.26, 0.36, 0.33))
	var SH2: Material = h._vmat_solid(Color(0.38, 0.46, 0.44))
	var DK: Material = h._vmat_solid(Color(0.14, 0.16, 0.17))
	var GR := Color(0.24, 0.88, 0.68)
	var by := 0.62 * s
	# 八棱工业发生器底舱（取代圆球）
	h._p(body, ART.cyl(0.34 * s, 0.38 * s, 0.38 * s, 8), DK, Vector3(0, by, 0))
	h._panels(body, Vector3(0, by + 0.195 * s, 0), Vector3(-90, 0, 0), 0.42 * s, 0.42 * s, 121, 4)
	# 顶部八瓣可展开电磁辐射叶片伞盖（crown：金属散热瓣 + 黄铜汇流母线 + 内嵌窄缝青绿场发射条，移除悬浮光环与光球）
	var crown := Node3D.new()
	crown.position = Vector3(0, by + 0.22 * s, 0)
	body.add_child(crown)
	h._p(crown, ART.cyl(0.16 * s, 0.09 * s, 0.20 * s, 8), h._brass(), Vector3.ZERO)
	for k in 8:
		var a := TAU * k / 8.0
		var petal := Node3D.new()
		petal.rotation_degrees = Vector3(0, rad_to_deg(a), 0)
		crown.add_child(petal)
		h._bar(petal, Vector3(0.14, 0.02, 0) * s, Vector3(0.56, 0.08, 0) * s, 0.045 * s, 0.035 * s, h._steel())
		h._prism(petal, [Vector2(0, 0) * s, Vector2(0.16, 0.30) * s, Vector2(0.09, 0.46) * s, Vector2(-0.09, 0.46) * s, Vector2(-0.16, 0.30) * s],
			0.045 * s, 0.10, SH2 if k % 2 == 0 else SH, Vector3(0.30 * s, 0.02 * s, 0), Vector3(-72, 0, 0))
		h._box(petal, h._brass(), Vector3(0.56 * s, 0.08 * s, 0), Vector3(0.06, 0.05, 0.12) * s)
		h._box(petal, ART.emit(GR, 1.35), Vector3(0.38 * s, 0.04 * s, 0), Vector3(0.26, 0.016, 0.028) * s, Vector3(0, 0, 12))
	h.crown = crown
	# 舱前笼罩式磁场励磁核（core_mi 装在双钢制万向环框架内，取代裸露悬浮光圈）
	var cpos := Vector3(0, by - 0.02 * s, -0.18 * s)
	var core: MeshInstance3D = h._p(body, ART.cyl(0.14 * s, 0.24 * s, 0.14 * s, 12), ART.emit(GR, 1.25), cpos)
	h.core_mi = core
	for k in 2:
		h._p(body, ART.torus(0.20 * s, 0.23 * s, 16), h._steel(), cpos, Vector3(90 * k, 45, 0))
	h._p(body, ART.cyl(0.17 * s, 0.04 * s, 0.17 * s, 10), h._brass(), cpos + Vector3(0, 0.13 * s, 0))
	h._p(body, ART.cyl(0.17 * s, 0.04 * s, 0.17 * s, 10), h._brass(), cpos + Vector3(0, -0.13 * s, 0))
	for sx: float in [-1.0, 1.0]:
		_eye(h, body, Vector3(sx * 0.20 * s, by + 0.08 * s, -0.30 * s), 0.044 * s, GR)
	# 四条外扩支腿
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			h._mleg(body, Vector3(sx * 0.28 * s, by - 0.14 * s, (-0.2 + i * 0.4) * s), sx * (-24.0 + i * 48.0), sx, 0.78 * s, by, 0.075 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0))


# ---------------------------------------------------------------- 8. 重型自行曲射榴弹炮车 (mortar)
static func _mortar(h, body: Node3D, s: float) -> void:
	var OL: Material = h._vmat_matte(Color(0.30, 0.35, 0.24))
	var SH2: Material = h._vmat_solid(Color(0.38, 0.42, 0.34))
	var DK: Material = h._vmat_solid(Color(0.14, 0.16, 0.15))
	var ST: Material = h._steel()
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.035))
	var by := 0.56 * s
	# 低矮切面装甲炮车底盘（取代圆球身躯）
	h._prism(body, [Vector2(-0.44, -0.52) * s, Vector2(0.44, -0.52) * s, Vector2(0.56, 0.0) * s, Vector2(0.48, 0.54) * s, Vector2(-0.48, 0.54) * s, Vector2(-0.56, 0.0) * s],
		0.34 * s, 0.06, DK, Vector3(0, by, -0.04 * s), Vector3(90, 0, 0))
	h._prism(body, [Vector2(-0.34, -0.40) * s, Vector2(0.34, -0.40) * s, Vector2(0.42, 0.10) * s, Vector2(-0.42, 0.10) * s],
		0.16 * s, 0.08, OL, Vector3(0, by + 0.22 * s, -0.10 * s), Vector3(90, 0, 0))
	h._panels(body, Vector3(0, by + 0.305 * s, -0.16 * s), Vector3(-90, 0, 0), 0.54 * s, 0.42 * s, 131, 4)
	# 耳轴炮架底座 + 固定 46° 仰角挂载节点（保证 abdomen 归零时炮管依然呈威猛斜射姿态！）
	for sx: float in [-1.0, 1.0]:
		h._box(body, SH2, Vector3(sx * 0.30 * s, by + 0.26 * s, 0.24 * s), Vector3(0.08, 0.38, 0.36) * s)
		h._hydraulic(body, Vector3(sx * 0.26 * s, by + 0.14 * s, -0.06 * s), Vector3(sx * 0.26 * s, by + 0.44 * s, 0.14 * s), 0.038 * s, DK)
	var mount := Node3D.new()
	mount.position = Vector3(0, by + 0.26 * s, 0.26 * s)
	mount.rotation_degrees = Vector3(-46, 0, 0)
	body.add_child(mount)
	var abd := Node3D.new()
	mount.add_child(abd)
	# 铸钢炮尾摇架（abdomen）
	h._box(abd, DK, Vector3(0, 0.08 * s, 0.06 * s), Vector3(0.50, 0.44, 0.54) * s)
	h._box(abd, OL, Vector3(0, 0.08 * s, 0.06 * s), Vector3(0.54, 0.26, 0.36) * s)
	h.abdomen = abd
	# 重型高膛压榴弹炮身管（turret：彻底移除原版炮口刺眼绿灯泡！改用加固钢箍 + 双液压驻退筒 + 多槽钢制退器 + 深黑膛口）
	var barrel := Node3D.new()
	barrel.position = Vector3(0, 0.24 * s, 0.0)
	abd.add_child(barrel)
	h._p(barrel, ART.cyl(0.25 * s, 0.28 * s, 0.28 * s, 16), DK, Vector3(0, 0.10 * s, 0))
	h._p(barrel, ART.cyl(0.18 * s, 0.96 * s, 0.22 * s, 16), ST, Vector3(0, 0.56 * s, 0))
	for sx: float in [-1.0, 1.0]:
		h._p(barrel, ART.cyl(0.052 * s, 0.64 * s, 0.052 * s, 10), h._chrome(), Vector3(sx * 0.22 * s, 0.38 * s, 0))
		h._p(barrel, ART.cyl(0.064 * s, 0.20 * s, 0.064 * s, 10), h._brass(), Vector3(sx * 0.22 * s, 0.12 * s, 0))
	for k in 3:
		h._p(barrel, ART.cyl(0.235 * s, 0.055 * s, 0.235 * s, 16), DK, Vector3(0, (0.30 + k * 0.28) * s, 0))
	# 重型开槽炮口箍与深黑炮膛
	h._p(barrel, ART.cyl(0.24 * s, 0.18 * s, 0.22 * s, 16), DK, Vector3(0, 1.06 * s, 0))
	h._p(barrel, ART.cyl(0.25 * s, 0.035 * s, 0.25 * s, 16), h._hazard_yel(), Vector3(0, 0.99 * s, 0))
	h._p(barrel, ART.cyl(0.145 * s, 0.03 * s, 0.145 * s, 16), BL, Vector3(0, 1.145 * s, 0), Vector3.ZERO, Vector3.ONE, false)
	h.turret = barrel
	# 前甲板三枚军用酸蚀高爆定装炮弹（钢壳 + 黄铜引信头，取代绿椭圆蛋）
	for k in 3:
		var sp := Vector3((-0.18 + k * 0.18) * s, by + 0.36 * s, -0.06 * s)
		h._p(body, ART.cyl(0.068 * s, 0.26 * s, 0.068 * s, 12), OL, sp)
		h._p(body, ART.cyl(0.072 * s, 0.03 * s, 0.072 * s, 12), h._hazard_yel(), sp + Vector3(0, 0.06 * s, 0))
		h._p(body, ART.cyl(0.022 * s, 0.065 * s, 0.056 * s, 10), h._brass(), sp + Vector3(0, 0.16 * s, 0))
	for sx: float in [-1.0, 1.0]:
		_eye(h, body, Vector3(sx * 0.20 * s, by + 0.10 * s, -0.56 * s), 0.048 * s, Color(0.85, 0.92, 0.28))
		# 前置驻锄防爆挡盾臂
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.42 * s, by + 0.06 * s, -0.38 * s)
		arm.rotation_degrees = Vector3(0, sx * 22.0, 0)
		body.add_child(arm)
		h._servo(arm, Vector3.ZERO, 0.10 * s)
		h._prism(arm, [Vector2(0, 0.26) * s, Vector2(0.24, 0.06) * s, Vector2(0.18, -0.28) * s, Vector2(-0.12, -0.30) * s, Vector2(-0.18, 0.10) * s],
			0.075 * s, 0.1, SH2, Vector3(sx * 0.16 * s, -0.10 * s, -0.06 * s), Vector3(0, 90, 0))
		h._box(arm, h._hazard_yel(), Vector3(sx * 0.20 * s, -0.22 * s, -0.06 * s), Vector3(0.012, 0.055, 0.26) * s)
	# 后两条重型液压驻锄活塞腿 + 前两条铰接支腿
	for sx: float in [-1.0, 1.0]:
		h._pleg(body, Vector3(sx * 0.48 * s, by - 0.08 * s, 0.30 * s), sx * 26.0, sx, s, by - 0.06 * s, PI if sx > 0 else 0.0)
		h._zleg(body, Vector3(sx * 0.36 * s, by - 0.04 * s, -0.34 * s), sx * -30.0, sx, 0.95 * s, by, 0.09 * s, 0.0 if sx > 0 else PI, true)


# ---------------------------------------------------------------- 9. 重装液压碎岩铁颚破城车 (ironjaw)
static func _ironjaw(h, body: Node3D, s: float) -> void:
	var SH: Material = h._vmat_matte(Color(0.32, 0.31, 0.28))
	var OL: Material = h._vmat_matte(Color(0.28, 0.32, 0.24))
	var DK: Material = h._vmat_solid(Color(0.13, 0.14, 0.16))
	var ST: Material = h._steel()
	var BL: Material = h._vmat_solid(Color(0.03, 0.03, 0.035))
	var by := 0.72 * s
	# 宽六边形重装铆接底盘 + 反应装甲上甲板
	h._prism(body, [Vector2(-0.58, -0.64) * s, Vector2(0.58, -0.64) * s, Vector2(0.74, 0.0) * s, Vector2(0.60, 0.74) * s, Vector2(-0.60, 0.74) * s, Vector2(-0.74, 0.0) * s],
		0.40 * s, 0.06, DK, Vector3(0, by, 0), Vector3(90, 0, 0))
	h._prism(body, [Vector2(-0.46, -0.48) * s, Vector2(0.46, -0.48) * s, Vector2(0.58, 0.02) * s, Vector2(0.48, 0.60) * s, Vector2(-0.48, 0.60) * s, Vector2(-0.58, 0.02) * s],
		0.20 * s, 0.08, OL, Vector3(0, by + 0.30 * s, 0), Vector3(90, 0, 0))
	h._panels(body, Vector3(0, by + 0.41 * s, 0.02 * s), Vector3(-90, 0, 0), 0.80 * s, 0.86 * s, 141, 7)
	# 背部装甲百叶散热罩 + 双后倾防烫排烟囱（取代仿生背脊骨刺）
	h._box(body, DK, Vector3(0, by + 0.46 * s, 0.32 * s), Vector3(0.54, 0.14, 0.42) * s)
	for lv in 5:
		h._box(body, BL, Vector3(0, by + 0.535 * s, (0.16 + lv * 0.08) * s), Vector3(0.42, 0.015, 0.04) * s)
	for sx: float in [-1.0, 1.0]:
		var ep := Vector3(sx * 0.24 * s, by + 0.48 * s, 0.48 * s)
		h._p(body, ART.cyl(0.052 * s, 0.38 * s, 0.058 * s, 10), DK, ep + Vector3(0, 0.15 * s, 0.05 * s), Vector3(18, 0, 0))
		h._p(body, ART.cyl(0.068 * s, 0.22 * s, 0.068 * s, 10), h._rust_plate(), ep + Vector3(0, 0.10 * s, 0.035 * s), Vector3(18, 0, 0))
		h._p(body, ART.cyl(0.042 * s, 0.02 * s, 0.042 * s, 10), BL, ep + Vector3(0, 0.335 * s, 0.11 * s), Vector3(18, 0, 0), Vector3.ONE, false)
	# 正面重型铸钢颚座 + 双级镀铬液压油缸驱动的巨型碎岩液压剪（jaws）
	var jaw_root := Node3D.new()
	jaw_root.position = Vector3(0, by - 0.02 * s, -0.66 * s)
	body.add_child(jaw_root)
	h._prism(jaw_root, [Vector2(0.44, 0.24) * s, Vector2(0.34, -0.18) * s, Vector2(-0.34, -0.18) * s, Vector2(-0.44, 0.24) * s], 0.24 * s, 0.08, DK, Vector3.ZERO)
	h._box(jaw_root, h._hazard_yel(), Vector3(0, 0.21 * s, -0.122 * s), Vector3(0.64, 0.048, 0.016) * s)
	for sx: float in [-1.0, 1.0]:
		var j := Node3D.new()
		j.position = Vector3(sx * 0.26 * s, 0.02 * s, -0.08 * s)
		jaw_root.add_child(j)
		# 黄铜大销轴 + 钢箱颚臂 + 外侧双级液压推杆 + 高强锯齿碎岩刃
		h._p(j, ART.cyl(0.068 * s, 0.24 * s, 0.068 * s, 10), h._brass(), Vector3.ZERO)
		h._bar(j, Vector3.ZERO, Vector3(sx * 0.08, -0.10, -0.44) * s, 0.16 * s, 0.19 * s, SH)
		h._hydraulic(j, Vector3(sx * 0.14 * s, 0.06 * s, 0.08 * s), Vector3(sx * 0.13 * s, -0.04 * s, -0.30 * s), 0.042 * s, DK)
		h._jag(j, 0.22 * s, 0.64 * s, 0.12 * s, h._chrome(), Vector3(sx * 0.08, -0.11, -0.48) * s, Vector3(-78, sx * 6.0, 0), 4, -1.0, sx * 0.03 * s)
		h._box(j, h._hazard_yel(), Vector3(sx * 0.165 * s, -0.05 * s, -0.24 * s), Vector3(0.012, 0.065, 0.22) * s)
		h.jaws.append(j)
		_eye(h, jaw_root, Vector3(sx * 0.30 * s, 0.14 * s, -0.13 * s), 0.052 * s, Color(1.0, 0.42, 0.12))
		# 肩部铆接防撞破障护肩（取代有机角刺）
		h._prism(body, [Vector2(0, 0.14) * s, Vector2(0.28, 0.06) * s, Vector2(0.32, -0.12) * s, Vector2(-0.04, -0.14) * s],
			0.28 * s, 0.08, ST, Vector3(sx * 0.62 * s, by + 0.18 * s, -0.34 * s), Vector3(0, sx * -24.0, 0))
		h._box(body, h._hazard_yel(), Vector3(sx * 0.68 * s, by + 0.08 * s, 0.14 * s), Vector3(0.016, 0.055, 0.42) * s)
	# 六条重型液压活塞支腿
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			h._pleg(body, Vector3(sx * 0.60 * s, by - 0.10 * s, (-0.38 + i * 0.46) * s), sx * (-24.0 + i * 24.0), sx, s, by - 0.10 * s, float(i % 2) * PI + (PI if sx > 0 else 0.0))
