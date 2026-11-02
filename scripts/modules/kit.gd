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

const DARK := Color(0.16, 0.165, 0.18)
const FRAME := Color(0.11, 0.115, 0.125)
const ACCENT := Color(0.58, 0.52, 0.28)   # 警示条与接口标注用的低饱和战术黄
const VISOR := Color(0.30, 0.44, 0.42)
const IFACE_COLOR := Color(0.60, 0.53, 0.27)

const IFACES := {
	"core": "HP-C1", "arm_l": "HP-A1", "arm_r": "HP-A1", "back": "HP-B1", "gen": "HP-G1",
}

const SLOT_CN := {"core": "躯干座圈", "arm_l": "左臂挂点", "arm_r": "右臂挂点", "back": "背部导轨", "gen": "动力舱"}

## 真实军用涂装色（按模块 id）
const REAL := {
	"core_scout": Color(0.56, 0.55, 0.5), "core_std": Color(0.46, 0.48, 0.5), "core_heavy": Color(0.36, 0.38, 0.3),
	"legs_biped": Color(0.5, 0.51, 0.52), "legs_tread": Color(0.34, 0.36, 0.3), "legs_quad": Color(0.4, 0.41, 0.43), "legs_hover": Color(0.55, 0.56, 0.56),
	"arm_mg": Color(0.42, 0.43, 0.44), "arm_shotgun": Color(0.46, 0.44, 0.4), "arm_flamer": Color(0.44, 0.36, 0.3), "arm_laser": Color(0.36, 0.4, 0.44),
	"back_cargo": Color(0.42, 0.42, 0.38), "back_missile": Color(0.36, 0.39, 0.34), "back_shield": Color(0.4, 0.43, 0.47),
	"gen_cell": Color(0.36, 0.37, 0.37), "gen_reactor": Color(0.34, 0.36, 0.38), "gen_crystal": Color(0.32, 0.32, 0.35),
	"core_assault": Color(0.44, 0.38, 0.32), "core_command": Color(0.36, 0.40, 0.44), "core_fortress": Color(0.42, 0.43, 0.39),
	"legs_titan": Color(0.36, 0.38, 0.34),
	"back_rack": Color(0.42, 0.41, 0.36), "back_rocket": Color(0.38, 0.40, 0.34), "back_vls": Color(0.34, 0.36, 0.38),
	"gen_diesel": Color(0.40, 0.37, 0.31), "gen_hfc": Color(0.36, 0.40, 0.42), "gen_turbine": Color(0.38, 0.39, 0.36),
	"arm_hmg": Color(0.42, 0.43, 0.43), "arm_gatling": Color(0.38, 0.40, 0.42), "arm_ac30": Color(0.40, 0.41, 0.39),
	"arm_slug": Color(0.38, 0.36, 0.32), "arm_cannon": Color(0.45, 0.42, 0.34), "arm_rail": Color(0.36, 0.38, 0.40),
}


static func real(id: String, c: Color) -> Color:
	if REAL.has(id):
		return REAL[id]
	var g := (c.r + c.g + c.b) / 3.0
	return c.lerp(Color(g, g, g), 0.55).darkened(0.25)


# ---------------------------------------------------------------- 材质
static func armor(c: Color, wear := 0.4) -> ShaderMaterial:
	return A.paint(c, 0.05, 0.74, {"wear": wear, "panel_scale": 0.62, "takes_damage": 1.0})


static func frame() -> ShaderMaterial:
	return A.metal(FRAME)


static func dark() -> ShaderMaterial:
	return A.metal(DARK)


static func accent() -> ShaderMaterial:
	return A.paint(ACCENT, 0.1, 0.55, {"wear": 0.7, "panel_scale": 0.0})


static func canopy() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.05, 0.06)
	m.metallic = 0.8
	m.roughness = 0.06
	m.emission_enabled = true
	m.emission = VISOR
	m.emission_energy_multiplier = 0.1
	m.clearcoat_enabled = true
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


## 武器臂通用肩部：作动器 + 多面切角肩甲 + 警示条 + 徽记
static func shoulder(arm: Node3D, side: float, M: Material) -> void:
	actuator(arm, Vector3(-side * 0.08, 0.05, 0.05), 0.24, 0.3)
	var sh := node(arm, Vector3(side * 0.06, 0.34, 0.02), Vector3(0, 0, side * -12.0))
	plate(sh, trap(0.7, 0.46, 0.24, 0.06), 0.56, M, Vector3.ZERO, Vector3(0, 90, 0), 0.04)
	plate(sh, crect(0.05, 0.26), 0.58, accent(), Vector3(side * 0.12, 0.0, 0.0), Vector3(0, 90, 0), 0.005)
	A.emblem(arm, Vector3(side * 0.31, 0.2, 0.08), Vector3(0, side * 90.0, side * -6.0), 0.22)


static func node(p: Node3D, pos := Vector3.ZERO, rot := Vector3.ZERO, name := "") -> Node3D:
	var n := Node3D.new()
	if name != "":
		n.name = name
	n.position = pos
	n.rotation_degrees = rot
	p.add_child(n)
	return n


## 作动器：外壳圆柱 + 两端法兰 + 轴盖 + 螺栓，轴沿 X
static func actuator(p: Node3D, pos: Vector3, r: float, w: float) -> void:
	cy(p, r, w, dark(), pos, Vector3(0, 0, 90), -1.0, 20)
	for sx in [-1.0, 1.0]:
		cy(p, r * 1.08, w * 0.12, A.metal(Color(0.24, 0.24, 0.26)), pos + Vector3(sx * w * 0.5, 0, 0), Vector3(0, 0, 90), -1.0, 20)
		cy(p, r * 0.45, w * 0.14, A.chrome(), pos + Vector3(sx * (w * 0.5 + 0.03), 0, 0), Vector3(0, 0, 90), -1.0, 12)
		for i in 6:
			var a := TAU * i / 6.0
			A.add(p, A.cyl(0.018, 0.03, 0.02, 6), A.metal(Color(0.4, 0.4, 0.4)), pos + Vector3(sx * (w * 0.5 + 0.035), cos(a) * r * 0.75, sin(a) * r * 0.75), Vector3(0, 0, 90), Vector3.ONE, false)


## 液压活塞：缸体 + 镀铬活塞杆 + 两端球铰
static func piston(p: Node3D, from: Vector3, to: Vector3, r := 0.04) -> void:
	var mid := (from + to) * 0.5
	var len := from.distance_to(to)
	var holder := Node3D.new()
	p.add_child(holder)
	holder.position = mid
	if len > 0.01:
		holder.look_at_from_position(mid, to, Vector3.UP if abs((to - from).normalized().y) < 0.95 else Vector3.FORWARD)
	A.add(holder, A.cyl(r * 1.7, len * 0.55, r * 1.7, 12), A.metal(Color(0.2, 0.2, 0.22)), Vector3(0, 0, len * 0.2), Vector3(90, 0, 0))
	A.add(holder, A.cyl(r * 1.9, 0.04, r * 1.9, 12), A.metal(Color(0.3, 0.3, 0.32)), Vector3(0, 0, len * 0.47), Vector3(90, 0, 0))
	A.add(holder, A.cyl(r, len * 0.95, r, 10), A.chrome(), Vector3(0, 0, -len * 0.02), Vector3(90, 0, 0))
	for e in [-1.0, 1.0]:
		A.add(holder, A.sphere(r * 1.6, -1, 10), A.metal(Color(0.25, 0.25, 0.27)), Vector3(0, 0, e * len * 0.5))


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
	var M_R := A.metal(Color(0.2, 0.2, 0.22))
	var M_Y := A.paint(IFACE_COLOR, 0.1, 0.55, {"wear": 0.8, "panel_scale": 0.0})
	match iface:
		"HP-C1":
			cy(v, 0.46, 0.1, M_R, Vector3(0, 0, 0.05), Vector3(90, 0, 0), -1.0, 28)
			A.add(v, A.torus(0.4, 0.47, 32), M_Y, Vector3(0, 0, 0.0), Vector3(90, 0, 0), Vector3(1, 0.35, 1), false)
			for i in 12:
				var a := TAU * i / 12.0
				A.add(v, A.cyl(0.02, 0.04, 0.024, 6), A.metal(Color(0.45, 0.45, 0.45)), Vector3(cos(a) * 0.43, sin(a) * 0.43, -0.01), Vector3(90, 0, 0), Vector3.ONE, false)
		"HP-A1":
			bb(v, Vector3(0.46, 0.46, 0.06), M_R, Vector3(0, 0, 0.03), Vector3.ZERO, 0.02)
			A.add(v, A.torus(0.15, 0.2, 24), M_Y, Vector3(0, 0, -0.005), Vector3(90, 0, 0), Vector3(1, 0.4, 1), false)
			for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				A.add(v, A.cyl(0.025, 0.04, 0.03, 6), A.metal(Color(0.45, 0.45, 0.45)), Vector3(c.x * 0.17, c.y * 0.17, -0.01), Vector3(90, 0, 0), Vector3.ONE, false)
		"HP-B1":
			for sx in [-0.3, 0.3]:
				bb(v, Vector3(0.1, 0.62, 0.06), M_R, Vector3(sx, 0, 0.02), Vector3.ZERO, 0.015)
				bb(v, Vector3(0.04, 0.6, 0.04), M_Y, Vector3(sx, 0, -0.02), Vector3.ZERO, 0.01)
		"HP-G1":
			bb(v, Vector3(0.8, 0.7, 0.05), M_R, Vector3(0, 0, 0.02), Vector3.ZERO, 0.02)
			bb(v, Vector3(0.84, 0.05, 0.06), M_Y, Vector3(0, 0.36, 0.0), Vector3.ZERO, 0.01)
			bb(v, Vector3(0.84, 0.05, 0.06), M_Y, Vector3(0, -0.36, 0.0), Vector3.ZERO, 0.01)
			for i in 4:
				A.add(v, A.cyl(0.02, 0.05, 0.02, 8), A.chrome(), Vector3(-0.15 + i * 0.1, -0.2, -0.02), Vector3(90, 0, 0), Vector3.ONE, false)


## 公插头外观（局部 -Z 指向父模块；接合面在 z=0，插头本体在 +Z 侧即模块内部）
static func _plug(v: Node3D, iface: String) -> void:
	var M_P := A.metal(Color(0.26, 0.26, 0.28))
	var M_Y := A.paint(IFACE_COLOR, 0.1, 0.55, {"wear": 0.8, "panel_scale": 0.0})
	match iface:
		"HP-C1":
			cy(v, 0.39, 0.12, M_P, Vector3(0, 0, 0.06), Vector3(90, 0, 0), -1.0, 28)
			cy(v, 0.33, 0.06, A.chrome(), Vector3(0, 0, -0.01), Vector3(90, 0, 0), -1.0, 28)
			A.add(v, A.torus(0.36, 0.4, 32), M_Y, Vector3(0, 0, 0.1), Vector3(90, 0, 0), Vector3(1, 0.4, 1), false)
		"HP-A1":
			bb(v, Vector3(0.4, 0.4, 0.06), M_P, Vector3(0, 0, 0.03), Vector3.ZERO, 0.02)
			cy(v, 0.13, 0.08, A.chrome(), Vector3(0, 0, -0.02), Vector3(90, 0, 0), -1.0, 18)
			bb(v, Vector3(0.42, 0.04, 0.07), M_Y, Vector3(0, 0.19, 0.03), Vector3.ZERO, 0.01)
		"HP-B1":
			for sx in [-0.3, 0.3]:
				bb(v, Vector3(0.18, 0.2, 0.12), M_P, Vector3(sx, 0.18, 0.06), Vector3.ZERO, 0.02)
				bb(v, Vector3(0.18, 0.2, 0.12), M_P, Vector3(sx, -0.18, 0.06), Vector3.ZERO, 0.02)
				bb(v, Vector3(0.19, 0.04, 0.13), M_Y, Vector3(sx, 0.0, 0.06), Vector3.ZERO, 0.01)
		"HP-G1":
			bb(v, Vector3(0.74, 0.64, 0.06), M_P, Vector3(0, 0, 0.03), Vector3.ZERO, 0.02)
			bb(v, Vector3(0.5, 0.1, 0.06), A.metal(Color(0.1, 0.1, 0.1)), Vector3(0, -0.2, -0.01), Vector3.ZERO, 0.01)
			bb(v, Vector3(0.76, 0.04, 0.07), M_Y, Vector3(0, 0.3, 0.03), Vector3.ZERO, 0.01)


# ================================================================ 接头转接件（v0.4.9 新模块用）
## HP-A1 臂部转接：方形法兰（4 枚螺栓）→ 回转轴承 → 叉架立轴。
## 在臂 Body 坐标里建（Body 原点在接口外 0.25m），返回叉架节点（原点 = 立轴中心，x=side*0.13）。武器机匣贴在立轴外侧。
static func a1_mount(arm: Node3D, side: float, M: Material) -> Node3D:
	var M_B := A.metal(Color(0.24, 0.24, 0.26))
	var bolt := A.metal(Color(0.5, 0.5, 0.5))
	# 法兰：贴在插头背面（接口外 0.06m 处）
	bb(arm, Vector3(0.05, 0.42, 0.42), M_B, Vector3(-side * 0.165, 0, 0), Vector3.ZERO, 0.012)
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		cy(arm, 0.024, 0.03, bolt, Vector3(-side * 0.13, c.y * 0.16, c.x * 0.16), Vector3(0, 0, 90), -1.0, 6)
	# 回转轴承：外圈 + 镀铬滚道 + 内圈
	cy(arm, 0.2, 0.08, dark(), Vector3(-side * 0.1, 0, 0), Vector3(0, 0, 90), -1.0, 24)
	cy(arm, 0.205, 0.016, A.chrome(), Vector3(-side * 0.06, 0, 0), Vector3(0, 0, 90), -1.0, 24)
	cy(arm, 0.17, 0.08, M_B, Vector3(-side * 0.02, 0, 0), Vector3(0, 0, 90), -1.0, 20)
	# 俯仰叉架：两片侧耳 + 耳轴
	var yoke := node(arm, Vector3(side * 0.12, 0, 0), Vector3.ZERO, "Yoke")
	bb(arm, Vector3(0.12, 0.2, 0.3), M, Vector3(side * 0.02, 0, 0), Vector3.ZERO, 0.02)
	for sy in [-1.0, 1.0]:
		bb(arm, Vector3(0.3, 0.05, 0.34), M, Vector3(side * 0.13, sy * 0.2, 0), Vector3.ZERO, 0.015)
	cy(arm, 0.07, 0.48, dark(), Vector3(side * 0.13, 0, 0), Vector3.ZERO, -1.0, 14)
	for sy in [-1.0, 1.0]:
		cy(arm, 0.085, 0.03, A.chrome(), Vector3(side * 0.13, sy * 0.245, 0), Vector3.ZERO, -1.0, 14)
	return yoke


## HP-B1 背部转接：两只导轨卡箍（压在插头导轨块上）+ 横梁。在背部模块根坐标建；
## up = 远离躯干的方向（与插座 out 相同）。返回横梁上表面的安装节点（+Y 为 up）。
static func b1_mount(root: Node3D, M: Material, width := 1.2) -> Node3D:
	var up := Vector3(0, 1, 0.25).normalized()
	var base := Node3D.new()
	base.name = "B1Mount"
	root.add_child(base)
	base.basis = Basis(Vector3.RIGHT, up, Vector3.RIGHT.cross(up))
	var M_B := A.metal(Color(0.24, 0.24, 0.26))
	for sx in [-0.3, 0.3]:
		# 卡箍：U 形压块 + 两颗快拆销
		bb(base, Vector3(0.24, 0.08, 0.5), M_B, Vector3(sx, 0.16, 0), Vector3.ZERO, 0.015)
		for sz in [-0.18, 0.18]:
			cy(base, 0.025, 0.3, A.chrome(), Vector3(sx, 0.15, sz), Vector3(0, 0, 90), -1.0, 8)
			cy(base, 0.04, 0.02, accent(), Vector3(sx + 0.15, 0.15, sz), Vector3(0, 0, 90), -1.0, 8)
	bb(base, Vector3(width, 0.12, 0.3), frame(), Vector3(0, 0.26, 0), Vector3.ZERO, 0.025)
	var top := node(base, Vector3(0, 0.32, 0), Vector3.ZERO, "Top")
	return top


## HP-G1 动力舱转接：安装背板（四角锁销）。在动力模块根坐标建，返回背板后表面节点（+Z 向后）。
static func g1_mount(root: Node3D, M: Material, w := 0.82, h := 0.66) -> Node3D:
	plate(root, crect(w, h, [0.1, 0.1, 0.1, 0.1]), 0.08, frame(), Vector3(0, 0, 0.1), Vector3.ZERO, 0.02)
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		cy(root, 0.035, 0.06, A.chrome(), Vector3(c.x * (w * 0.5 - 0.08), c.y * (h * 0.5 - 0.08), 0.15), Vector3(90, 0, 0), -1.0, 10)
		cy(root, 0.05, 0.015, accent(), Vector3(c.x * (w * 0.5 - 0.08), c.y * (h * 0.5 - 0.08), 0.185), Vector3(90, 0, 0), -1.0, 10)
	return node(root, Vector3(0, 0, 0.14), Vector3.ZERO, "Back")


## 重型臂的加强件：在 a1_mount 法兰后面加第二圈法兰 + 上下三角加强筋（同一 HP-A1 接口，只是更粗）
static func heavy_gussets(arm: Node3D, side: float, M: Material) -> void:
	bb(arm, Vector3(0.06, 0.5, 0.5), A.metal(Color(0.22, 0.22, 0.24)), Vector3(-side * 0.115, 0, 0), Vector3.ZERO, 0.015)
	for i in 8:
		var a := TAU * i / 8.0
		cy(arm, 0.02, 0.03, A.metal(Color(0.5, 0.5, 0.5)), Vector3(-side * 0.08, sin(a) * 0.21, cos(a) * 0.21), Vector3(0, 0, 90), -1.0, 6)
	for sy in [-1.0, 1.0]:
		for sz in [-0.13, 0.13]:
			bb(arm, Vector3(0.42, 0.1, 0.04), M, Vector3(side * 0.08, sy * 0.3, sz), Vector3(0, 0, side * sy * -28.0), 0.01)
