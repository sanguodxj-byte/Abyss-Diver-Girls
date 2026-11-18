extends RefCounted
## 模块建模公共库：材质、细节件、作动器，以及「标准接口」的插座 / 插头外观。
##
## 接口规范（所有模块共享，任何同类模块都能互换）：
##   HP-C1  腰部回转座圈   底盘 → 躯干      插座：底盘顶部（向上）
##   HP-A1  臂部挂点法兰   躯干 → 左右臂    插座：躯干两侧（向 ±X）
##   HP-B1  背部双导轨     躯干 → 背部挂载  插座：躯干背面上部（向 +Z）
##   HP-G1  动力舱         躯干 → 动力炉    插座：躯干背面下部（向 +Z）
##
## 约定：
##   · 插座是 Marker3D，meta: iface / out（拆卸方向，父节点坐标）/ side（臂：-1 左 / +1 右）
##   · 模块根节点的原点 = 插头接合面中心，挂到插座下 position=0 即装配完成
##   · 模块根节点 meta: slot / id / iface；底盘另有 leg_parts / leg_type；臂另有 muzzle
##   · 朝向：-Z 为机体正前方

const A = preload("res://scripts/art.gd")

const DARK := Color(0.15, 0.155, 0.17)
const FRAME := Color(0.10, 0.105, 0.115)
const GUNMETAL := Color(0.21, 0.22, 0.24)
const BRASS := Color(0.54, 0.43, 0.22)
const COPPER := Color(0.56, 0.33, 0.20)
const ACCENT := Color(0.64, 0.52, 0.19)   # 警示条与接口标注用的低饱和工业琥珀黄
const VISOR := Color(0.22, 0.42, 0.38)
const IFACE_COLOR := Color(0.62, 0.51, 0.20)

const IFACES := {
	"core": "HP-C1", "arm_l": "HP-A1", "arm_r": "HP-A1", "back": "HP-B1", "gen": "HP-G1",
}

const SLOT_CN := {"core": "躯干座圈", "arm_l": "左臂挂点", "arm_r": "右臂挂点", "back": "背部导轨", "gen": "动力舱"}

## 真实重工业与军用涂装色（按模块 id）：降低粉白感，强化冷轧钢/橄榄褐/舰灰/沙褐工业层次
const REAL := {
	"core_scout": Color(0.46, 0.45, 0.40), "core_std": Color(0.39, 0.42, 0.44), "core_heavy": Color(0.33, 0.36, 0.29),
	"legs_tread_light": Color(0.40, 0.39, 0.31), "legs_tread": Color(0.32, 0.34, 0.28), "legs_tread_heavy": Color(0.29, 0.33, 0.30), "legs_tread_siege": Color(0.41, 0.37, 0.30),
	"legs_biped_scout": Color(0.45, 0.43, 0.37), "legs_biped": Color(0.42, 0.44, 0.45), "legs_biped_assault": Color(0.34, 0.37, 0.41), "legs_titan": Color(0.34, 0.36, 0.32),
	"legs_quad_hound": Color(0.43, 0.38, 0.31), "legs_quad": Color(0.36, 0.38, 0.40), "legs_quad_crab": Color(0.40, 0.34, 0.28), "legs_quad_mammoth": Color(0.39, 0.39, 0.33),
	"legs_hex_ant": Color(0.36, 0.39, 0.33), "legs_hex": Color(0.34, 0.37, 0.39), "legs_hex_beetle": Color(0.35, 0.34, 0.28), "legs_hex_colossus": Color(0.30, 0.32, 0.33),
	"arm_mg": Color(0.35, 0.37, 0.38), "arm_shotgun": Color(0.41, 0.39, 0.35), "arm_flamer": Color(0.40, 0.33, 0.27), "arm_laser": Color(0.34, 0.37, 0.39),
	"back_cargo": Color(0.39, 0.39, 0.34), "back_missile": Color(0.34, 0.37, 0.32), "back_shield": Color(0.36, 0.39, 0.42),
	"gen_cell": Color(0.33, 0.35, 0.35), "gen_reactor": Color(0.31, 0.34, 0.36), "gen_crystal": Color(0.30, 0.32, 0.34),
	"core_assault": Color(0.42, 0.36, 0.29), "core_command": Color(0.33, 0.37, 0.41), "core_fortress": Color(0.38, 0.40, 0.35),
	"back_rack": Color(0.39, 0.38, 0.33), "back_rocket": Color(0.35, 0.38, 0.31), "back_vls": Color(0.32, 0.35, 0.37),
	"gen_diesel": Color(0.38, 0.35, 0.29), "gen_hfc": Color(0.34, 0.38, 0.40), "gen_turbine": Color(0.35, 0.36, 0.33),
	"arm_hmg": Color(0.36, 0.38, 0.39), "arm_gatling": Color(0.33, 0.35, 0.37), "arm_ac30": Color(0.36, 0.38, 0.35),
	"arm_slug": Color(0.35, 0.33, 0.29), "arm_cannon": Color(0.42, 0.39, 0.31), "arm_rail": Color(0.33, 0.35, 0.38),
}


static func real(id: String, c: Color) -> Color:
	if REAL.has(id):
		return REAL[id]
	var g := (c.r + c.g + c.b) / 3.0
	return c.lerp(Color(g, g, g), 0.55).darkened(0.28)


# ---------------------------------------------------------------- 材质
static func armor(c: Color, wear := 0.44) -> ShaderMaterial:
	return A.paint(c, 0.16, 0.54, {"wear": wear, "panel_scale": 0.0, "takes_damage": 1.0})


static func armor_sub(c: Color, wear := 0.48) -> ShaderMaterial:
	return A.paint(c.darkened(0.20), 0.18, 0.52, {"wear": wear, "panel_scale": 0.0, "takes_damage": 1.0})


static func frame() -> ShaderMaterial:
	return A.metal(FRAME)


static func dark() -> ShaderMaterial:
	return A.metal(DARK)


static func gunmetal() -> ShaderMaterial:
	return A.metal(GUNMETAL)


static func brass() -> ShaderMaterial:
	return A.paint(BRASS, 0.78, 0.38, {"wear": 0.35, "panel_scale": 0.0, "bare_metal": Color(0.76, 0.64, 0.38)})


static func copper() -> ShaderMaterial:
	return A.paint(COPPER, 0.82, 0.36, {"wear": 0.30, "panel_scale": 0.0, "bare_metal": Color(0.78, 0.50, 0.34)})


static func bore_mat() -> ShaderMaterial:
	return A.paint(Color(0.015, 0.015, 0.018), 0.05, 0.96, {"wear": 0.0, "panel_scale": 0.0, "dust": 0.0, "scratches": 0.0})


static func accent() -> ShaderMaterial:
	return A.paint(ACCENT, 0.14, 0.52, {"wear": 0.68, "panel_scale": 0.0})


static func canopy(c := VISOR, energy := 0.18) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.025, 0.04, 0.045)
	m.metallic = 0.85
	m.roughness = 0.06
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.04
	return m


# ---------------------------------------------------------------- 基本件
static func bb(p: Node3D, size: Vector3, m: Material, pos: Vector3, rot := Vector3.ZERO, bevel := 0.04, taper := 1.0) -> MeshInstance3D:
	return A.add(p, A.bevel_box(size, bevel, taper), m, pos, rot)


static func cy(p: Node3D, r: float, h: float, m: Material, pos: Vector3, rot := Vector3.ZERO, r2 := -1.0, seg := 18) -> MeshInstance3D:
	return A.add(p, A.cyl(r, h, r2, seg), m, pos, rot)


## 多边形切角装甲板（outline 在 XY 平面，沿局部 Z 挤出 thick）
static func plate(p: Node3D, outline: Array, thick: float, m: Material, pos: Vector3, rot := Vector3.ZERO, bevel := 0.025) -> MeshInstance3D:
	return A.add(p, A.prism(PackedVector2Array(outline), thick, bevel), m, pos, rot)


## 切角矩形轮廓：w×h，四角切去 c = [左上, 右上, 右下, 左下]
static func crect(w: float, h: float, c := [0.0, 0.0, 0.0, 0.0]) -> Array:
	var x := w * 0.5
	var y := h * 0.5
	var corners := [Vector2(-x, y), Vector2(x, y), Vector2(x, -y), Vector2(-x, -y)]
	var o: Array = []
	for i in 4:
		var cc: float = c[i]
		var p: Vector2 = corners[i]
		if cc <= 0.0:
			o.append(p)
			continue
		var prev: Vector2 = corners[(i + 3) % 4]
		var nxt: Vector2 = corners[(i + 1) % 4]
		o.append(p + (prev - p).normalized() * cc)
		o.append(p + (nxt - p).normalized() * cc)
	return o


## 梯形轮廓：底宽 wb、顶宽 wt、高 h，可选四角切角 cut
static func trap(wb: float, wt: float, h: float, cut := 0.0) -> Array:
	var corners := [Vector2(-wt * 0.5, h * 0.5), Vector2(wt * 0.5, h * 0.5), Vector2(wb * 0.5, -h * 0.5), Vector2(-wb * 0.5, -h * 0.5)]
	if cut <= 0.0:
		return corners
	var o: Array = []
	for i in 4:
		var p: Vector2 = corners[i]
		var prev: Vector2 = corners[(i + 3) % 4]
		var nxt: Vector2 = corners[(i + 1) % 4]
		o.append(p + (prev - p).normalized() * cut)
		o.append(p + (nxt - p).normalized() * cut)
	return o


## 沿线段 a→b 建立骨节点：原点在 a，局部 -Y 指向 b（零件向下建模即可沿骨骼排布）
static func bone(p: Node3D, a: Vector3, b: Vector3) -> Node3D:
	var n := Node3D.new()
	p.add_child(n)
	n.position = a
	var y := (a - b).normalized()
	var x := Vector3.RIGHT
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	n.basis = Basis(x, y, z)
	return n


## 散热孔格栅：一排深色圆孔（贴在 -Z 朝外的面上）
static func holes(p: Node3D, pos: Vector3, rot: Vector3, cols: int, rows: int, pitch := 0.06, r := 0.018) -> void:
	var g := node(p, pos, rot)
	var M := A.metal(Color(0.03, 0.03, 0.035))
	for i in cols:
		for j in rows:
			A.add(g, A.cyl(r, 0.02, r, 8), M, Vector3((i - (cols - 1) * 0.5) * pitch, (j - (rows - 1) * 0.5) * pitch, 0), Vector3(90, 0, 0), Vector3.ONE, false)


## 机体编号贴花（大号白字）
static func number(p: Node3D, txt: String, pos: Vector3, rot: Vector3, px := 0.004) -> void:
	A.stencil(p, txt, pos, rot, px, Color(0.94, 0.94, 0.9, 0.9), 64)


## 武器臂通用肩部：承力叉架 + 作动器 + 双层多面切角肩甲 + 吊装环 + 警示条 + 徽记
static func shoulder(arm: Node3D, side: float, M: Material) -> void:
	actuator(arm, Vector3(-side * 0.08, 0.05, 0.05), 0.24, 0.30)
	bb(arm, Vector3(0.24, 0.28, 0.30), frame(), Vector3(side * 0.04, 0.20, 0.02), Vector3(0, 0, side * -8.0), 0.02)
	var sh := node(arm, Vector3(side * 0.06, 0.34, 0.02), Vector3(0, 0, side * -12.0))
	plate(sh, trap(0.72, 0.48, 0.25, 0.06), 0.58, M, Vector3.ZERO, Vector3(0, 90, 0), 0.038)
	# 外侧附加装甲护翼与顶部维修提手
	plate(sh, trap(0.56, 0.38, 0.18, 0.04), 0.12, gunmetal(), Vector3(side * 0.27, -0.02, 0.0), Vector3(0, 90, 0), 0.02)
	plate(sh, crect(0.05, 0.26), 0.60, accent(), Vector3(side * 0.14, 0.01, 0.0), Vector3(0, 90, 0), 0.005)
	grab_iron(sh, 0.20, 0.045, Vector3(0.0, 0.13, 0.0), Vector3(-90, 90, 0))
	for sz in [-0.22, 0.22]:
		cy(sh, 0.022, 0.03, A.chrome(), Vector3(side * 0.31, 0.04, sz), Vector3(0, 0, 90), -1.0, 6)
	A.emblem(arm, Vector3(side * 0.33, 0.20, 0.08), Vector3(0, side * 90.0, side * -6.0), 0.22)


static func node(p: Node3D, pos := Vector3.ZERO, rot := Vector3.ZERO, name := "") -> Node3D:
	var n := Node3D.new()
	if name != "":
		n.name = name
	n.position = pos
	n.rotation_degrees = rot
	p.add_child(n)
	return n


## 作动器：外壳圆柱 + 散热筋环 + 两端重型法兰 + 镀铬轴盖 + 螺栓圈，轴沿 X
static func actuator(p: Node3D, pos: Vector3, r: float, w: float) -> void:
	cy(p, r, w, dark(), pos, Vector3(0, 0, 90), -1.0, 20)
	cy(p, r * 1.04, w * 0.36, gunmetal(), pos, Vector3(0, 0, 90), -1.0, 20)
	for sx in [-1.0, 1.0]:
		cy(p, r * 1.10, w * 0.13, gunmetal(), pos + Vector3(sx * w * 0.48, 0, 0), Vector3(0, 0, 90), -1.0, 20)
		cy(p, r * 0.46, w * 0.15, A.chrome(), pos + Vector3(sx * (w * 0.50 + 0.03), 0, 0), Vector3(0, 0, 90), -1.0, 12)
		for i in 8:
			var a := TAU * i / 8.0
			A.add(p, A.cyl(0.017, 0.03, 0.02, 6), A.chrome(), pos + Vector3(sx * (w * 0.50 + 0.032), cos(a) * r * 0.78, sin(a) * r * 0.78), Vector3(0, 0, 90), Vector3.ONE, false)


## 液压活塞：重型油缸 + 防尘密封黄铜油封 + 镀铬活塞杆 + 两端耳轴叉头
static func piston(p: Node3D, from: Vector3, to: Vector3, r := 0.04) -> void:
	var mid := (from + to) * 0.5
	var len := from.distance_to(to)
	var holder := Node3D.new()
	p.add_child(holder)
	holder.position = mid
	if len > 0.01:
		holder.look_at_from_position(mid, to, Vector3.UP if abs((to - from).normalized().y) < 0.95 else Vector3.FORWARD)
	A.add(holder, A.cyl(r * 1.75, len * 0.56, r * 1.75, 12), gunmetal(), Vector3(0, 0, len * 0.20), Vector3(90, 0, 0))
	A.add(holder, A.cyl(r * 1.98, 0.045, r * 1.98, 12), brass(), Vector3(0, 0, -len * 0.08), Vector3(90, 0, 0))
	A.add(holder, A.cyl(r * 1.95, 0.045, r * 1.95, 12), dark(), Vector3(0, 0, len * 0.46), Vector3(90, 0, 0))
	A.add(holder, A.cyl(r, len * 0.95, r, 10), A.chrome(), Vector3(0, 0, -len * 0.02), Vector3(90, 0, 0))
	for e in [-1.0, 1.0]:
		A.add(holder, A.bevel_box(Vector3(r * 3.1, r * 2.4, r * 2.8), 0.008), dark(), Vector3(0, 0, e * len * 0.49))
		A.add(holder, A.cyl(r * 0.75, r * 3.6, r * 0.75, 8), A.chrome(), Vector3(0, 0, e * len * 0.50), Vector3(0, 0, 90), Vector3.ONE, false)


## 枪炮膛口：车削膛口冠 + 内倒角 + 深黑枪膛（彻底消除实心灰柱封死感；局部 -Z 朝前）
static func barrel_bore(p: Node3D, r_outer: float, r_inner: float, pos: Vector3, depth := 0.06, rot := Vector3(90, 0, 0)) -> void:
	var dir := Basis.from_euler(rot * PI / 180.0)
	A.add(p, A.torus(r_inner * 0.92, r_outer * 1.02, 18), gunmetal(), pos, rot, Vector3(1, 0.36, 1), false)
	A.add(p, A.cyl(r_inner, depth, r_inner, 14), bore_mat(), pos - dir * Vector3(0, depth * 0.45, 0), rot, Vector3.ONE, false)


## 制退器（轴沿 -Z，pos 为制退器中心）：侧开泄气槽 + 锁紧箍 + 真实深膛孔
static func muzzle_brake(p: Node3D, r: float, len: float, m: Material, pos: Vector3, slots := 2) -> void:
	bb(p, Vector3(r * 2.35, r * 2.15, len), m, pos, Vector3.ZERO, minf(0.022, r * 0.35))
	cy(p, r * 1.12, len * 0.22, dark(), pos + Vector3(0, 0, len * 0.44), Vector3(90, 0, 0), -1.0, 16)
	for i in slots:
		var z := pos.z + len * 0.22 - float(i) * (len * 0.56 / maxf(1.0, float(slots)))
		bb(p, Vector3(r * 2.45, r * 0.85, len * 0.18), bore_mat(), Vector3(pos.x, pos.y, z), Vector3.ZERO, 0.005)
	barrel_bore(p, r * 0.96, r * 0.68, pos + Vector3(0, 0, -len * 0.50), minf(0.08, len * 0.45))


## 环形法兰螺栓圈（默认轴沿 Z，贴在 XY 面）
static func bolt_ring(p: Node3D, r: float, n_bolts: int, bolt_r := 0.018, pos := Vector3.ZERO, rot := Vector3(90, 0, 0)) -> void:
	var dir := Basis.from_euler(rot * PI / 180.0)
	var bm := A.chrome()
	var mesh := A.cyl(bolt_r, bolt_r * 1.4, bolt_r * 1.15, 6)
	for i in n_bolts:
		var a := TAU * float(i) / float(n_bolts)
		var off := dir * Vector3(cos(a) * r, 0, sin(a) * r)
		A.add(p, mesh, bm, pos + off, rot, Vector3.ONE, false)


## 弯折钢制维修抓手 / 攀爬踏棍（局部 -Z 朝外伸出 d，宽 w）
static func grab_iron(p: Node3D, w: float, d: float, pos: Vector3, rot := Vector3.ZERO, r := 0.014) -> void:
	var g := node(p, pos, rot)
	var m := gunmetal()
	cy(g, r, w, m, Vector3(0, 0, -d), Vector3(0, 0, 90), -1.0, 8)
	for sx in [-w * 0.5 + r, w * 0.5 - r]:
		cy(g, r, d, m, Vector3(sx, 0, -d * 0.5), Vector3(90, 0, 0), -1.0, 8)
		cy(g, r * 1.55, 0.014, dark(), Vector3(sx, 0, -0.006), Vector3(90, 0, 0), -1.0, 8)


## 装甲潜望镜 / 光学观察窗（局部 -Z 朝前：遮光防弹眉檐 + 深凹镜框 + 镀膜玻璃）
static func periscope(p: Node3D, w: float, h: float, pos: Vector3, rot := Vector3.ZERO, c := VISOR, energy := 0.35) -> void:
	var g := node(p, pos, rot)
	bb(g, Vector3(w, h, 0.09), dark(), Vector3(0, 0, 0.02), Vector3.ZERO, 0.012)
	bb(g, Vector3(w * 1.06, 0.028, 0.12), gunmetal(), Vector3(0, h * 0.46, -0.01), Vector3(8, 0, 0), 0.006)
	bb(g, Vector3(w * 0.84, h * 0.56, 0.03), bore_mat(), Vector3(0, -0.005, -0.018), Vector3.ZERO, 0.004)
	bb(g, Vector3(w * 0.78, h * 0.46, 0.022), canopy(c, energy), Vector3(0, -0.005, -0.024), Vector3.ZERO, 0.003)


## 爆炸反应装甲块（ERA）：切角钢盒 + 四角紧固螺栓（局部 -Z 朝外）
static func era_block(p: Node3D, size: Vector3, m: Material, pos: Vector3, rot := Vector3.ZERO) -> void:
	var g := node(p, pos, rot)
	bb(g, size, m, Vector3.ZERO, Vector3.ZERO, minf(0.018, size.z * 0.3))
	var bm := A.chrome()
	var bx := size.x * 0.5 - 0.032
	var by := size.y * 0.5 - 0.032
	for sx in [-bx, bx]:
		for sy in [-by, by]:
			A.add(g, A.cyl(0.013, 0.018, 0.015, 6), bm, Vector3(sx, sy, -size.z * 0.5 - 0.004), Vector3(90, 0, 0), Vector3.ONE, false)


static func light(p: Node3D, c: Color, pos: Vector3, energy := 1.0, rng := 3.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	l.shadow_enabled = false
	p.add_child(l)
	return l


## 让节点的 -Z 轴（局部「朝外」）指向 dir；用于把接口面板贴到任意朝向的面上
static func face(n: Node3D, dir: Vector3) -> void:
	var d := dir.normalized()
	var up := Vector3.UP if absf(d.y) < 0.95 else Vector3.FORWARD
	n.basis = Basis.looking_at(d, up)


# ================================================================ 标准接口
## 在父模块上创建插座（并画出母座外观）。返回 Marker3D，子模块挂在它下面。
static func socket(parent: Node3D, slot: String, pos: Vector3, out: Vector3, side := 0.0) -> Marker3D:
	var m := Marker3D.new()
	m.name = "Socket_" + slot
	m.position = pos
	m.set_meta("slot", slot)
	m.set_meta("iface", IFACES[slot])
	m.set_meta("out", out.normalized())
	m.set_meta("side", side)
	parent.add_child(m)
	var v := Node3D.new()
	v.name = "Receiver"
	m.add_child(v)
	face(v, out)
	_receiver(v, IFACES[slot])
	# 爆炸视图里显示的接口铭牌
	var tag := Label3D.new()
	tag.name = "Tag"
	tag.text = "%s\n%s" % [IFACES[slot], SLOT_CN.get(slot, slot)]
	tag.font_size = 24
	tag.pixel_size = 0.006
	tag.outline_size = 8
	tag.modulate = IFACE_COLOR
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.fixed_size = false
	tag.position = out.normalized() * 0.55
	tag.visible = false
	m.add_child(tag)
	return m


## 模块根节点 + 插头外观。dir = 插头朝向父模块的方向（与插座 out 相反）
static func module_root(slot: String, id: String, plug_dir: Vector3) -> Node3D:
	var r := Node3D.new()
	r.name = "Module_" + slot
	r.set_meta("slot", slot)
	r.set_meta("id", id)
	if IFACES.has(slot):
		r.set_meta("iface", IFACES[slot])
		var v := Node3D.new()
		v.name = "Plug"
		r.add_child(v)
		face(v, plug_dir)
		_plug(v, IFACES[slot])
	else:
		r.set_meta("iface", "")
	return r


## 母座外观（在局部坐标中：-Z 朝外，接合面在 z=0）
static func _receiver(v: Node3D, iface: String) -> void:
	var M_R := gunmetal()
	var M_Y := A.paint(IFACE_COLOR, 0.14, 0.52, {"wear": 0.72, "panel_scale": 0.0})
	match iface:
		"HP-C1":
			cy(v, 0.475, 0.10, dark(), Vector3(0, 0, 0.06), Vector3(90, 0, 0), -1.0, 28)
			cy(v, 0.435, 0.07, M_R, Vector3(0, 0, 0.045), Vector3(90, 0, 0), -1.0, 28)
			A.add(v, A.torus(0.405, 0.46, 28), M_Y, Vector3(0, 0, 0.012), Vector3(90, 0, 0), Vector3(1, 0.35, 1), false)
			for i in 16:
				var a := TAU * i / 16.0
				A.add(v, A.cyl(0.018, 0.04, 0.022, 6), A.chrome(), Vector3(cos(a) * 0.43, sin(a) * 0.43, 0.005), Vector3(90, 0, 0), Vector3.ONE, false)
		"HP-A1":
			bb(v, Vector3(0.48, 0.48, 0.065), M_R, Vector3(0, 0, 0.042), Vector3.ZERO, 0.02)
			cy(v, 0.21, 0.07, dark(), Vector3(0, 0, 0.04), Vector3(90, 0, 0), -1.0, 20)
			A.add(v, A.torus(0.15, 0.20, 20), M_Y, Vector3(0, 0, 0.004), Vector3(90, 0, 0), Vector3(1, 0.4, 1), false)
			for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				A.add(v, A.cyl(0.024, 0.04, 0.028, 6), A.chrome(), Vector3(c.x * 0.18, c.y * 0.18, 0.0), Vector3(90, 0, 0), Vector3.ONE, false)
		"HP-B1":
			for sx in [-0.3, 0.3]:
				bb(v, Vector3(0.12, 0.64, 0.065), M_R, Vector3(sx, 0, 0.038), Vector3.ZERO, 0.015)
				bb(v, Vector3(0.045, 0.60, 0.036), M_Y, Vector3(sx, 0, -0.006), Vector3.ZERO, 0.008)
				for sy in [-0.24, 0.0, 0.24]:
					A.add(v, A.cyl(0.016, 0.03, 0.018, 6), A.chrome(), Vector3(sx, sy, -0.008), Vector3(90, 0, 0), Vector3.ONE, false)
		"HP-G1":
			bb(v, Vector3(0.84, 0.72, 0.06), M_R, Vector3(0, 0, 0.038), Vector3.ZERO, 0.02)
			bb(v, Vector3(0.86, 0.05, 0.055), M_Y, Vector3(0, 0.36, 0.022), Vector3.ZERO, 0.01)
			bb(v, Vector3(0.86, 0.05, 0.055), M_Y, Vector3(0, -0.36, 0.022), Vector3.ZERO, 0.01)
			for i in 4:
				A.add(v, A.cyl(0.024, 0.05, 0.024, 8), brass(), Vector3(-0.18 + i * 0.12, -0.20, 0.0), Vector3(90, 0, 0), Vector3.ONE, false)


## 公插头外观（局部 -Z 指向父模块；接合面在 z=0，插头本体在 +Z 侧即模块内部）
static func _plug(v: Node3D, iface: String) -> void:
	var M_P := gunmetal()
	var M_Y := A.paint(IFACE_COLOR, 0.14, 0.52, {"wear": 0.72, "panel_scale": 0.0})
	match iface:
		"HP-C1":
			cy(v, 0.39, 0.12, M_P, Vector3(0, 0, 0.075), Vector3(90, 0, 0), -1.0, 28)
			cy(v, 0.33, 0.06, A.chrome(), Vector3(0, 0, -0.005), Vector3(90, 0, 0), -1.0, 28)
			A.add(v, A.torus(0.35, 0.405, 28), M_Y, Vector3(0, 0, 0.095), Vector3(90, 0, 0), Vector3(1, 0.4, 1), false)
		"HP-A1":
			bb(v, Vector3(0.38, 0.38, 0.055), M_P, Vector3(0, 0, 0.032), Vector3.ZERO, 0.02)
			cy(v, 0.13, 0.07, A.chrome(), Vector3(0, 0, -0.015), Vector3(90, 0, 0), -1.0, 18)
			bb(v, Vector3(0.39, 0.042, 0.058), M_Y, Vector3(0, 0.175, 0.032), Vector3.ZERO, 0.01)
		"HP-B1":
			for sx in [-0.3, 0.3]:
				bb(v, Vector3(0.18, 0.21, 0.13), M_P, Vector3(sx, 0.18, 0.06), Vector3.ZERO, 0.02)
				bb(v, Vector3(0.18, 0.21, 0.13), M_P, Vector3(sx, -0.18, 0.06), Vector3.ZERO, 0.02)
				bb(v, Vector3(0.20, 0.045, 0.135), M_Y, Vector3(sx, 0.0, 0.06), Vector3.ZERO, 0.01)
		"HP-G1":
			bb(v, Vector3(0.72, 0.58, 0.06), M_P, Vector3(0, 0, 0.035), Vector3.ZERO, 0.02)
			bb(v, Vector3(0.48, 0.10, 0.05), dark(), Vector3(0, -0.18, -0.01), Vector3.ZERO, 0.01)
			bb(v, Vector3(0.74, 0.042, 0.065), M_Y, Vector3(0, 0.25, 0.035), Vector3.ZERO, 0.01)


# ================================================================ 接头转接件（v0.4.9 新模块用）
## HP-A1 臂部转接：方形法兰（4 枚螺栓）→ 回转轴承 → 叉架立轴 + 上肩甲托架。
## 在臂 Body 坐标里建（Body 原点在接口外 0.25m），返回叉架节点（原点 = 立轴中心，x=side*0.13）。武器机匣与肩甲均牢固连接。
static func a1_mount(arm: Node3D, side: float, M: Material) -> Node3D:
	var M_B := A.metal(Color(0.24, 0.24, 0.26))
	var bolt := A.metal(Color(0.5, 0.5, 0.5))
	# 法兰与加深肩部过渡轴套：从接口平面（x=-side*0.25）无缝延伸至轴承
	bb(arm, Vector3(0.11, 0.44, 0.44), M_B, Vector3(-side * 0.185, 0, 0), Vector3.ZERO, 0.015)
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		cy(arm, 0.024, 0.03, bolt, Vector3(-side * 0.12, c.y * 0.16, c.x * 0.16), Vector3(0, 0, 90), -1.0, 6)
	# 回转轴承：外圈 + 镀铬滚道 + 内圈
	cy(arm, 0.22, 0.10, dark(), Vector3(-side * 0.09, 0, 0), Vector3(0, 0, 90), -1.0, 24)
	cy(arm, 0.225, 0.018, A.chrome(), Vector3(-side * 0.05, 0, 0), Vector3(0, 0, 90), -1.0, 24)
	cy(arm, 0.19, 0.10, M_B, Vector3(-side * 0.01, 0, 0), Vector3(0, 0, 90), -1.0, 20)
	# 俯仰叉架与上肩甲承力支座：向上延伸衔接肩甲 sh，向外延伸衔接机匣 g
	var yoke := node(arm, Vector3(side * 0.12, 0, 0), Vector3.ZERO, "Yoke")
	bb(arm, Vector3(0.32, 0.26, 0.34), M, Vector3(side * 0.12, 0, 0), Vector3.ZERO, 0.02)
	bb(arm, Vector3(0.26, 0.34, 0.30), frame(), Vector3(side * 0.16, 0.26, 0.02), Vector3(0, 0, -side * 8.0), 0.02)
	for sy in [-1.0, 1.0]:
		bb(arm, Vector3(0.36, 0.06, 0.36), M, Vector3(side * 0.16, sy * 0.2, 0), Vector3.ZERO, 0.015)
	cy(arm, 0.08, 0.50, dark(), Vector3(side * 0.13, 0, 0), Vector3.ZERO, -1.0, 14)
	for sy in [-1.0, 1.0]:
		cy(arm, 0.09, 0.03, A.chrome(), Vector3(side * 0.13, sy * 0.245, 0), Vector3.ZERO, -1.0, 14)
	return yoke


## HP-B1 背部转接：两只导轨卡箍（直接贴合躯干背板与导轨）+ 低矮横梁。在背部模块根坐标建；
## up = 远离躯干的方向（与插座 out 相同）。返回横梁上表面的安装节点（+Y 为 up）。
static func b1_mount(root: Node3D, M: Material, width := 1.2) -> Node3D:
	var up := Vector3(0, 1, 0.25).normalized()
	var base := Node3D.new()
	base.name = "B1Mount"
	root.add_child(base)
	base.basis = Basis(Vector3.RIGHT, up, Vector3.RIGHT.cross(up))
	var M_B := A.metal(Color(0.24, 0.24, 0.26))
	for sx in [-0.3, 0.3]:
		# 卡箍：下探至躯干背板内部（y=-0.04..0.11），消除背部悬空缝隙
		bb(base, Vector3(0.26, 0.15, 0.52), M_B, Vector3(sx, 0.035, 0), Vector3.ZERO, 0.015)
		for sz in [-0.18, 0.18]:
			cy(base, 0.025, 0.32, A.chrome(), Vector3(sx, 0.06, sz), Vector3(0, 0, 90), -1.0, 8)
			cy(base, 0.04, 0.02, accent(), Vector3(sx + 0.15, 0.06, sz), Vector3(0, 0, 90), -1.0, 8)
	bb(base, Vector3(width, 0.13, 0.34), frame(), Vector3(0, 0.12, 0), Vector3.ZERO, 0.025)
	var top := node(base, Vector3(0, 0.17, 0), Vector3.ZERO, "Top")
	return top


## HP-G1 动力舱转接：安装背板（四角锁销）。在动力模块根坐标建，返回背板后表面节点（+Z 向后）。
static func g1_mount(root: Node3D, M: Material, w := 0.82, h := 0.66) -> Node3D:
	plate(root, crect(w, h, [0.1, 0.1, 0.1, 0.1]), 0.11, frame(), Vector3(0, 0, 0.058), Vector3.ZERO, 0.02)
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		cy(root, 0.035, 0.06, A.chrome(), Vector3(c.x * (w * 0.5 - 0.08), c.y * (h * 0.5 - 0.08), 0.13), Vector3(90, 0, 0), -1.0, 10)
		cy(root, 0.05, 0.015, accent(), Vector3(c.x * (w * 0.5 - 0.08), c.y * (h * 0.5 - 0.08), 0.165), Vector3(90, 0, 0), -1.0, 10)
	return node(root, Vector3(0, 0, 0.11), Vector3.ZERO, "Back")


## 重型臂的加强件：在 a1_mount 法兰后面加第二圈法兰 + 上下三角加强筋 + 高耸肩甲立柱（同一 HP-A1 接口，只是更粗）
static func heavy_gussets(arm: Node3D, side: float, M: Material) -> void:
	bb(arm, Vector3(0.05, 0.5, 0.5), A.metal(Color(0.22, 0.22, 0.24)), Vector3(-side * 0.16, 0, 0), Vector3.ZERO, 0.015)
	bb(arm, Vector3(0.34, 0.44, 0.36), frame(), Vector3(side * 0.24, 0.38, 0.04), Vector3(0, 0, -side * 10.0), 0.02)
	for i in 8:
		var a := TAU * i / 8.0
		cy(arm, 0.02, 0.03, A.metal(Color(0.5, 0.5, 0.5)), Vector3(-side * 0.08, sin(a) * 0.21, cos(a) * 0.21), Vector3(0, 0, 90), -1.0, 6)
	for sy in [-1.0, 1.0]:
		for sz in [-0.13, 0.13]:
			bb(arm, Vector3(0.42, 0.1, 0.04), M, Vector3(side * 0.08, sy * 0.3, sz), Vector3(0, 0, side * sy * -28.0), 0.01)
