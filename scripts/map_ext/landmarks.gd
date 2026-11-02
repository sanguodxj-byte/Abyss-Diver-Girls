extends RefCounted
## 战区地标：读取当前战区条目里的 landmarks（[{"type", "x", "z", "rot", "water"}]），
## 在遗迹与街区建完之后、撤离点与虫群生成之前摆放，占地登记进 raid.blocks（撤离点与后续布景会避让）。
## 地标只提供体量与剪影，不刷怪、不放战利品；"water": true 的条目允许压在水面上（断桥、栈桥）。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/map_ext/poi_kit.gd")

const STEEL := Color(0.32, 0.32, 0.3)
const CONCRETE := Color(0.48, 0.46, 0.42)


static func build(raid, _drop: Vector3) -> void:
	_clear_aprons(raid)
	var made: Array = []
	for e in raid.MAP.get("landmarks", []):
		var t := str(e.get("type", ""))
		var p := Vector3(float(e.get("x", 0)), 0, float(e.get("z", 0)))
		var rot := float(e.get("rot", 0))
		var clear := float(e.get("clear", 7.0))
		if not bool(e.get("water", false)) and raid._blocked(p, clear, false):
			p = _nudge(raid, p, clear)
		if p.x == INF:
			continue
		_build_one(raid, t, p, rot)
		made.append({"type": t, "x": p.x, "z": p.z})
	raid.set_meta("ext_landmarks", made)


## 被既有楼体占住时向外找空地，找不到就跳过（不硬塞，避免和街区叠在一起）
static func _nudge(raid, p: Vector3, clear: float) -> Vector3:
	for relax in [1.0, 0.62]:
		var c: float = clear * float(relax)
		var best := Vector3(INF, 0, 0)
		var bd := INF
		for dz in range(-44, 45, 4):
			for dx in range(-44, 45, 4):
				var d := float(dx * dx + dz * dz)
				if d >= bd:
					continue
				var q := p + Vector3(dx, 0, dz)
				if absf(q.x) > 166.0 or absf(q.z) > 166.0:
					continue
				if not raid._blocked(q, c, false):
					bd = d
					best = q
		if best.x != INF:
			return best
	return Vector3(INF, 0, 0)


static func _build_one(raid, t: String, p: Vector3, rot: float) -> void:
	match t:
		"broken_bridge": _broken_bridge(raid, p, rot)
		"radio_mast": _radio_mast(raid, p, rot)
		"elevated_road": _elevated_road(raid, p, rot)
		"gantry": _gantry(raid, p, rot)
		"blast_furnace": _blast_furnace(raid, p, rot)
		"gas_holder": _gas_holder(raid, p, rot)
		"windmill": _windmill(raid, p, rot)
		"pylon_row": _pylon_row(raid, p, rot)
		"silo": _silo(raid, p, rot)
		"boardwalk": _boardwalk(raid, p, rot)
		"observation_tower": _observation_tower(raid, p, rot)
		"cable_tower": _cable_tower(raid, p, rot)
		"ore_silos": _ore_silos(raid, p, rot)
		"rope_bridge": _rope_bridge(raid, p, rot)
		"crystal_cluster": _crystal_cluster(raid, p, rot)
		"drill_derrick": _drill_derrick(raid, p, rot)
		"coolant_channel": _coolant_channel(raid, p, rot)


## 灰港断桥：两截错位的桥面悬在河上，中段整跨塌进水里，只剩扭曲的钢筋与桥墩
static func _broken_bridge(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M := A.concrete(Color(0.44, 0.43, 0.4), true)
	var R := A.paint(Color(0.35, 0.2, 0.12), 0.5, 0.7, {"rust": 0.9, "wear": 0.6})
	for sgn in [-1.0, 1.0]:
		A.add(n, A.bevel_box(Vector3(11.0, 0.8, 9.0), 0.08), M, Vector3(sgn * 10.0, 5.2, 0), Vector3(0, 0, sgn * 3.0))
		A.add(n, A.bevel_box(Vector3(11.0, 0.6, 0.25), 0.04), A.concrete(Color(0.5, 0.49, 0.45), false), Vector3(sgn * 10.0, 5.9, 4.4), Vector3(0, 0, sgn * 3.0))
		# 桥墩
		A.add(n, A.bevel_box(Vector3(3.0, 6.0, 3.4), 0.1), A.concrete(Color(0.4, 0.39, 0.36), false), Vector3(sgn * 8.0, 2.4, 0))
		K.blocker(raid, p + Vector3(sgn * 8.0, 0, 0), Vector3(3.0, 6.0, 3.4), rot)
		# 断口钢筋
		for i in 5:
			A.add(n, A.cyl(0.05, 3.4, 0.05, 5), R, Vector3(sgn * (4.2 + i * 0.35), 5.4, -2.0 + i * 1.0), Vector3(0, 0, sgn * 70))
		# 桥面残存的路灯
		A.add(n, A.cyl(0.08, 5.0, 0.08, 6), A.metal(STEEL), Vector3(sgn * 14.0, 7.8, 4.0))
		A.add(n, A.bevel_box(Vector3(0.9, 0.14, 0.3), 0.02), A.metal(STEEL), Vector3(sgn * 14.4, 10.2, 4.0))
		raid.blocks.append(raid._rect_for(p + Vector3(sgn * 10.0, 0, 0), Vector3(11.0, 1, 9.0)))
	# 塌在水里的中跨
	A.add(n, A.bevel_box(Vector3(10.0, 0.6, 7.0), 0.06), M, Vector3(0.0, 0.45, 0.6), Vector3(4, 12, 2))
	# 桥上的废车与断护栏
	raid._wreck_car(p + Vector3(-13.0, 5.6, 1.0))
	raid._wreck_car(p + Vector3(11.0, 5.6, -1.6))
	for sgn in [-1.0, 1.0]:
		for i in 4:
			A.add(n, A.bevel_box(Vector3(0.18, 1.0, 0.5), 0.03), A.metal(STEEL), Vector3(sgn * 12.6, 6.4, -3.2 + i * 2.2), Vector3(0, 0, sgn * -8))


## 灰港广播塔：三角桁架桅杆 + 拉索 + 锅盖天线，塔顶红灯还在闪
static func _radio_mast(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M := A.metal(Color(0.35, 0.35, 0.33))
	for k in 3:
		var a := TAU * k / 3.0
		A.add(n, A.tube([Vector3(cos(a) * 1.8, 0, sin(a) * 1.8), Vector3(cos(a) * 0.3, 28.0, sin(a) * 0.3)], 0.11, 5, 2), M, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		_wire(n, Vector3(cos(a) * 1.4, 22.0, sin(a) * 1.4), Vector3(cos(a) * 22.0, 0.2, sin(a) * 22.0), 0.8, 0.03, A.metal(STEEL))
	for y in [7.0, 14.0, 21.0]:
		var rr := lerpf(1.7, 0.5, y / 28.0)
		for k in 3:
			var a1 := TAU * k / 3.0
			var a2 := TAU * (k + 1) / 3.0
			A.add(n, A.tube([Vector3(cos(a1) * rr, y, sin(a1) * rr), Vector3(cos(a2) * rr, y, sin(a2) * rr)], 0.05, 4, 2), M, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.cyl(0.08, 6.0, 0.04, 6), M, Vector3(0, 31.0, 0))
	A.add(n, A.sphere(0.22, -1, 10), A.emit(Color(1.0, 0.18, 0.1), 2.4), Vector3(0, 34.2, 0), Vector3.ZERO, Vector3.ONE, false)
	# 设备房与碟形天线
	A.add(n, A.bevel_box(Vector3(5.0, 2.6, 4.0), 0.06), A.paint(Color(0.44, 0.43, 0.39), 0.3, 0.7, {"wear": 0.6, "rust": 0.6}), Vector3(8.0, 1.3, 2.0))
	A.add(n, A.sphere(1.6, -1, 18), A.chrome(), Vector3(-5.6, 3.4, 2.2), Vector3(-40, 30, 0), Vector3(1, 1, 0.3))
	A.add(n, A.cyl(0.12, 2.4, 0.12, 8), A.metal(STEEL), Vector3(-5.6, 1.4, 2.2))
	raid.blocks.append(raid._rect_for(p, Vector3(4.0, 1, 4.0)))
	raid.blocks.append(raid._rect_for(p + Vector3(8.0, 0, 2.0), Vector3(5.4, 1, 4.4)))


## 高架路残段：立柱上的断头高架，护栏挂着，端头钢筋散开
static func _elevated_road(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M := A.concrete(Color(0.42, 0.41, 0.38), true)
	for i in 3:
		var x := -12.0 + i * 12.0
		if i == 2:
			A.add(n, A.bevel_box(Vector3(11.0, 0.9, 10.0), 0.08), M, Vector3(x, 7.4, 0), Vector3(0, 0, -7))
		else:
			A.add(n, A.bevel_box(Vector3(11.6, 0.9, 10.0), 0.08), M, Vector3(x, 7.4, 0))
			A.add(n, A.bevel_box(Vector3(11.6, 0.7, 0.3), 0.04), A.concrete(Color(0.48, 0.47, 0.43), false), Vector3(x, 8.1, 4.8))
		A.add(n, A.bevel_box(Vector3(2.0, 7.0, 2.4), 0.1), A.concrete(Color(0.4, 0.39, 0.36), false), Vector3(x, 3.5, 0))
		K.blocker(raid, p + Vector3(x, 0, 0).rotated(Vector3.UP, deg_to_rad(rot)), Vector3(2.0, 7.0, 2.4), rot)
		raid.blocks.append(raid._rect_for(p + Vector3(x, 0, 0).rotated(Vector3.UP, deg_to_rad(rot)), Vector3(11.8, 1, 10.4)))
	for i in 6:
		A.add(n, A.cyl(0.06, 2.6, 0.06, 5), A.paint(Color(0.35, 0.2, 0.12), 0.5, 0.7, {"rust": 0.9}), Vector3(18.6, 7.2, -3.6 + i * 1.2), Vector3(0, 0, -58))
	raid._wreck_car(p + Vector3(-9.0, 8.0, 0.6).rotated(Vector3.UP, deg_to_rad(rot)))


## 铁锈龙门吊：轨道上的门式起重机，主梁下挂着锈死的吊钩
static func _gantry(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M := A.metal(Color(0.33, 0.33, 0.31))
	for sx in [-10.0, 10.0]:
		A.add(n, A.bevel_box(Vector3(0.6, 0.3, 18.0), 0.04), A.metal(Color(0.42, 0.42, 0.4)), Vector3(sx, 0.15, 0))
		for sz in [-6.5, 6.5]:
			for k in 2:
				var lean := -0.8 if k == 0 else 0.8
				A.add(n, A.tube([Vector3(sx + lean * 3.0, 0, sz), Vector3(sx + lean * 0.4, 15.0, sz)], 0.22, 6, 2), A.paint(Color(0.4, 0.38, 0.32), 0.6, 0.55, {"rust": 0.85, "wear": 0.5}), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			A.add(n, A.bevel_box(Vector3(1.0, 0.7, 1.4), 0.05), A.paint(Color(0.45, 0.4, 0.26), 0.5, 0.6, {"rust": 0.8}), Vector3(sx, 0.35, sz))
			K.blocker(raid, p + Vector3(sx, 0, sz).rotated(Vector3.UP, deg_to_rad(rot)), Vector3(1.2, 15.0, 1.2), rot)
			raid.blocks.append(raid._rect_for(p + Vector3(sx, 0, sz).rotated(Vector3.UP, deg_to_rad(rot)), Vector3(2.6, 1, 2.6)))
	A.add(n, A.bevel_box(Vector3(21.0, 1.4, 1.4), 0.08), A.paint(Color(0.42, 0.39, 0.3), 0.6, 0.55, {"rust": 0.8, "wear": 0.5}), Vector3(0, 15.6, -6.5))
	A.add(n, A.bevel_box(Vector3(21.0, 1.4, 1.4), 0.08), A.paint(Color(0.42, 0.39, 0.3), 0.6, 0.55, {"rust": 0.8, "wear": 0.5}), Vector3(0, 15.6, 6.5))
	A.add(n, A.bevel_box(Vector3(3.4, 1.6, 3.4), 0.08), A.paint(Color(0.5, 0.38, 0.16), 0.4, 0.6, {"rust": 0.6}), Vector3(2.0, 15.0, 0))
	_wire(n, Vector3(2.0, 14.2, 0), Vector3(2.0, 4.0, 0), 0.0, 0.08, A.metal(Color(0.22, 0.21, 0.2)))
	A.add(n, A.bevel_box(Vector3(1.8, 1.0, 0.7), 0.1), A.paint(Color(0.4, 0.32, 0.16), 0.5, 0.6, {"rust": 0.85}), Vector3(2.0, 3.5, 0))
	raid.blocks.append(raid._rect_for(p, Vector3(21.0, 1, 3.0)))


## 一号钢厂高炉：粗筒身 + 收口炉顶 + 环形平台与斜桥，脚下堆着矿渣
static func _blast_furnace(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M := A.paint(Color(0.4, 0.3, 0.24), 0.5, 0.6, {"rust": 0.9, "wear": 0.5, "dust": 0.4, "panel_scale": 1.0})
	A.add(n, A.cyl(5.6, 6.0, 5.0, 22), M, Vector3(0, 3.0, 0))
	A.add(n, A.cyl(5.0, 10.0, 3.6, 22), M, Vector3(0, 11.0, 0))
	A.add(n, A.cyl(3.6, 3.0, 2.4, 18), A.paint(Color(0.34, 0.26, 0.21), 0.5, 0.6, {"rust": 0.9, "wear": 0.5, "dust": 0.4}), Vector3(0, 17.5, 0))
	A.add(n, A.cyl(2.2, 2.0, 1.2, 14), A.metal(Color(0.3, 0.29, 0.27)), Vector3(0, 20.0, 0))
	for y in [6.0, 12.0, 16.0]:
		A.add(n, A.torus(4.7, 5.0, 26), A.metal(STEEL), Vector3(0, y, 0))
	K.pipe(raid, p + Vector3(4.0, 6.0, 0).rotated(Vector3.UP, deg_to_rad(rot)), p + Vector3(18.0, 1.0, 6.0).rotated(Vector3.UP, deg_to_rad(rot)), 0.4)
	# 斜桥
	A.add(n, A.bevel_box(Vector3(3.0, 0.4, 16.0), 0.05), A.paint(Color(0.36, 0.33, 0.28), 0.5, 0.6, {"rust": 0.8}), Vector3(8.0, 8.0, 7.0), Vector3(-38, 22, 0))
	A.add(n, A.bevel_box(Vector3(5.0, 1.2, 5.0), 0.08), A.concrete(Color(0.34, 0.32, 0.29), false), Vector3(0, 0.6, 0))
	# 炉顶烟与矿渣堆
	A.emitter(raid.world, p + Vector3(0, 21.5, 0), {"amount": 10, "life": 7.0, "size": 3.4, "tex": A.smoke_tex(), "additive": false, "spread": 16.0,
		"vmin": 0.8, "vmax": 1.6, "gravity": Vector3(0.5, 0.7, 0.2), "c0": Color(0.16, 0.13, 0.11, 0.4), "c1": Color(0.3, 0.28, 0.25, 0.0), "grow0": 0.7, "grow1": 3.0})
	for i in 4:
		var a := TAU * i / 4.0 + 0.6
		A.add(n, A.cyl(3.0, 1.6, 0.4, 10), A.concrete(Color(0.2, 0.18, 0.16), false), Vector3(cos(a) * 9.0, 0.8, sin(a) * 9.0))
	K.blocker(raid, p, Vector3(10.6, 20.0, 10.6), 0.0, true)
	raid.blocks.append(raid._rect_for(p, Vector3(11.0, 1, 11.0)))


## 煤气罐区：球形储气罐架在钢架上，四周一圈管道与阀门
static func _gas_holder(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			A.add(n, A.cyl(0.16, 7.0, 0.16, 8), A.metal(STEEL), Vector3(sx * 4.0, 3.5, sz * 4.0))
	A.add(n, A.sphere(5.6, -1, 24), A.paint(Color(0.52, 0.5, 0.44), 0.5, 0.55, {"rust": 0.7, "wear": 0.5, "dust": 0.5, "panel_scale": 1.6}), Vector3(0, 10.0, 0))
	for y in [5.0, 10.0, 15.0]:
		A.add(n, A.torus(5.2, 5.7, 26), A.metal(Color(0.34, 0.33, 0.3)), Vector3(0, y, 0))
	K.pipe(raid, p + Vector3(4.0, 1.0, 0).rotated(Vector3.UP, deg_to_rad(rot)), p + Vector3(20.0, 1.0, 5.0).rotated(Vector3.UP, deg_to_rad(rot)), 0.34)
	K.pipe(raid, p + Vector3(0, 5.0, 4.6).rotated(Vector3.UP, deg_to_rad(rot)), p + Vector3(0, 0.4, 12.0).rotated(Vector3.UP, deg_to_rad(rot)), 0.28)
	A.add(n, A.cyl(0.6, 1.2, 0.6, 12), A.paint(Color(0.36, 0.32, 0.24), 0.5, 0.6, {"rust": 0.8}), Vector3(0, 0.6, 11.4))
	A.add(n, A.torus(0.9, 1.1, 12), A.metal(Color(0.55, 0.4, 0.15)), Vector3(0, 1.3, 11.4))
	K.blocker(raid, p, Vector3(9.6, 16.0, 9.6), 0.0, true)
	raid.blocks.append(raid._rect_for(p, Vector3(9.0, 1, 9.0)))


## 平原风车阵：三座三叶风机排成一列，塔身下是变电箱与土路
static func _windmill(raid, p: Vector3, rot: float) -> void:
	var base := p
	for i in 3:
		var q := base + Vector3(-15.0 + i * 15.0, 0, 0).rotated(Vector3.UP, deg_to_rad(rot))
		var n := Node3D.new()
		raid.world.add_child(n)
		n.position = q
		n.rotation_degrees.y = rot
		A.add(n, A.cyl(0.7, 17.0, 0.4, 12), A.paint(Color(0.62, 0.6, 0.54), 0.2, 0.7, {"wear": 0.5, "rust": 0.4, "dust": 0.5}), Vector3(0, 8.5, 0))
		K.blocker(raid, q, Vector3(1.4, 17.0, 1.4), 0.0, true)
		A.add(n, A.bevel_box(Vector3(1.6, 1.0, 3.2), 0.06), A.paint(Color(0.58, 0.56, 0.5), 0.3, 0.6, {"wear": 0.5, "dust": 0.5}), Vector3(0, 17.4, -0.8))
		var rotor := Node3D.new()
		n.add_child(rotor)
		rotor.position = Vector3(0, 17.4, -2.3)
		rotor.rotation_degrees.y = 18.0
		for k in 3:
			A.add(rotor, A.bevel_box(Vector3(0.9, 8.4, 0.22), 0.04), A.paint(Color(0.6, 0.58, 0.52), 0.2, 0.7, {"wear": 0.5, "dust": 0.5}), Vector3(0, 4.2, 0), Vector3(0, 0, 120.0 * k + i * 25.0))
		A.add(rotor, A.cyl(0.55, 1.1, 0.55, 12), A.metal(Color(0.4, 0.4, 0.38)), Vector3.ZERO, Vector3(90, 0, 0))
		raid.blocks.append(raid._rect_for(q, Vector3(2.2, 1, 2.2)))
	A.add(raid.world, A.bevel_box(Vector3(1.6, 1.8, 1.0), 0.05), A.paint(Color(0.4, 0.39, 0.35), 0.4, 0.6, {"rust": 0.6}), base + Vector3(-7.0, 0.9, 3.0).rotated(Vector3.UP, deg_to_rad(rot)))


## 高压电塔列：四座格构塔拉着一路垂下的导线
static func _pylon_row(raid, p: Vector3, rot: float) -> void:
	var prev := Vector3.ZERO
	for i in 4:
		var q := p + Vector3(-15.0 + i * 10.0, 0, 0).rotated(Vector3.UP, deg_to_rad(rot))
		K.lattice(raid, q, 12.0, 2.0)
		if i > 0:
			for off in [-0.9, 0.9]:
				K.cable(raid, prev + Vector3(0, 11.0, off).rotated(Vector3.UP, deg_to_rad(rot)), q + Vector3(0, 11.0, off).rotated(Vector3.UP, deg_to_rad(rot)), 1.6, 0.035)
		prev = q


## 农场筒仓：两座波纹钢筒仓 + 斜输送管 + 倒了一半的围栏
static func _silo(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	for i in 2:
		var q := Vector3(-3.4 + i * 6.8, 0, 0)
		K.tower(raid, p + q.rotated(Vector3.UP, deg_to_rad(rot)), 3.2, 12.0, 3.2, Color(0.56, 0.54, 0.48))
		A.add(n, A.cyl(3.4, 1.0, 1.4, 18), A.paint(Color(0.5, 0.48, 0.42), 0.4, 0.6, {"rust": 0.5, "wear": 0.5}), q + Vector3(0, 12.5, 0))
		for k in 5:
			A.add(n, A.torus(3.22, 3.3, 22), A.metal(Color(0.4, 0.39, 0.35)), q + Vector3(0, 2.0 + k * 2.2, 0))
	A.add(n, A.bevel_box(Vector3(2.0, 0.4, 13.0), 0.05), A.paint(Color(0.36, 0.33, 0.28), 0.5, 0.6, {"rust": 0.7}), Vector3(3.4, 8.0, 7.0), Vector3(-24, 0, 0))
	for i in 2:
		A.add(n, A.bevel_box(Vector3(7.0, 1.2, 0.3), 0.04), A.paint(Color(0.42, 0.39, 0.32), 0.0, 0.9, {"dust": 0.6}), Vector3(-6.0 + i * 12.0, 0.6, 5.0), Vector3(0, 18 + i * 24, 0))
	raid.blocks.append(raid._rect_for(p, Vector3(14.0, 1, 7.0)))


## 赤湖观景栈桥：木栈道伸进湖里，尽头一座塌了半边的观景亭
static func _boardwalk(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var WOOD := A.paint(Color(0.32, 0.26, 0.19), 0.0, 0.9, {"wear": 0.7, "dust": 0.5, "panel_scale": 0.6})
	A.add(n, A.bevel_box(Vector3(5.0, 0.24, 22.0), 0.05), WOOD, Vector3(0, 0.12, 0))
	for k in 11:
		A.add(n, A.bevel_box(Vector3(4.9, 0.03, 0.14), 0.01), A.paint(Color(0.24, 0.2, 0.15), 0.0, 0.9, {"wear": 0.8}), Vector3(0, 0.25, -10.0 + k * 2.0))
	for sx in [-2.3, 2.3]:
		K.railing(raid, p + Vector3(sx, 0, 0).rotated(Vector3.UP, deg_to_rad(rot)), 22.0, rot + 90.0, 1.0)
		for k in 4:
			A.add(n, A.cyl(0.18, 2.6, 0.18, 8), A.paint(Color(0.26, 0.21, 0.15), 0.0, 0.9), Vector3(sx, -1.0, -8.0 + k * 5.4))
	# 观景亭：四柱 + 破顶
	var pav := Vector3(0, 0, -9.0)
	for sx in [-2.0, 2.0]:
		for sz in [-2.0, 2.0]:
			A.add(n, A.cyl(0.12, 3.0, 0.12, 8), A.paint(Color(0.3, 0.24, 0.18), 0.0, 0.9), pav + Vector3(sx, 3.0, sz))
			K.blocker(raid, p + (pav + Vector3(sx, 0, sz)).rotated(Vector3.UP, deg_to_rad(rot)), Vector3(0.3, 3.0, 0.3), 0.0, true)
	A.add(n, A.prism(PackedVector2Array([Vector2(-3.0, 0), Vector2(0, 1.8), Vector2(3.0, 0)]), 5.0, 0.06), A.paint(Color(0.3, 0.24, 0.17), 0.1, 0.85, {"wear": 0.6}), pav + Vector3(0, 4.6, 0), Vector3(4, 8, 0))
	A.add(n, A.bevel_box(Vector3(5.4, 0.22, 5.4), 0.05), A.concrete(Color(0.4, 0.38, 0.34), false), pav + Vector3(0, 3.1, 0))
	K.bench(raid, p + pav.rotated(Vector3.UP, deg_to_rad(rot)) + Vector3(0, 0.2, 1.6).rotated(Vector3.UP, deg_to_rad(rot)), rot)
	K.lamp(raid, p + Vector3(0, 0, -7.0).rotated(Vector3.UP, deg_to_rad(rot)), Color(1.0, 0.75, 0.45))



## 环湖观景塔：四脚钢塔撑起一圈观景平台，楼梯绕着塔心上去
static func _observation_tower(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M := A.metal(Color(0.36, 0.36, 0.34))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			A.add(n, A.tube([Vector3(sx * 3.4, 0, sz * 3.4), Vector3(sx * 1.6, 12.0, sz * 1.6)], 0.16, 6, 2), M, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			var lp: Vector3 = p + Vector3(sx * 3.4, 0, sz * 3.4).rotated(Vector3.UP, deg_to_rad(rot))
			K.blocker(raid, lp, Vector3(0.6, 12.0, 0.6), 0.0, true)
			raid.blocks.append(raid._rect_for(lp, Vector3(1.0, 1, 1.0)))
	A.add(n, A.cyl(4.6, 0.3, 4.6, 20), A.concrete(Color(0.46, 0.45, 0.41), false), Vector3(0, 12.2, 0))
	for i in 10:
		var a := TAU * i / 10.0
		A.add(n, A.cyl(0.05, 1.0, 0.05, 5), M, Vector3(cos(a) * 4.4, 12.9, sin(a) * 4.4))
	A.add(n, A.torus(4.4, 4.5, 24), M, Vector3(0, 13.4, 0))
	A.add(n, A.cyl(1.2, 1.6, 1.2, 12), A.paint(Color(0.5, 0.48, 0.42), 0.3, 0.6, {"wear": 0.5, "dust": 0.5}), Vector3(0, 13.2, 0))
	A.add(n, A.cyl(0.08, 5.0, 0.05, 6), M, Vector3(0, 16.4, 0))
	K.steps(raid, p + Vector3(0.8, 0, 1.8).rotated(Vector3.UP, deg_to_rad(rot)), 26, 0.44, 0.3, 1.2, rot + 180.0)


## 峡谷缆车塔：两座塔架隔谷对望，钢索上吊着一只停摆的缆车厢
static func _cable_tower(raid, p: Vector3, rot: float) -> void:
	var dir := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(rot))
	var a := p - dir * 15.0
	var b := p + dir * 15.0
	K.lattice(raid, a, 16.0, 3.0)
	K.lattice(raid, b, 16.0, 3.0)
	A.add(raid.world, A.bevel_box(Vector3(4.0, 0.5, 1.2), 0.05), A.metal(STEEL), a + Vector3(0, 16.3, 0))
	A.add(raid.world, A.bevel_box(Vector3(4.0, 0.5, 1.2), 0.05), A.metal(STEEL), b + Vector3(0, 16.3, 0))
	var side := dir.cross(Vector3.UP)
	for off in [-1.2, 1.2]:
		K.cable(raid, a + side * off + Vector3(0, 16.2, 0), b + side * off + Vector3(0, 16.2, 0), 2.2, 0.045)
	var cabin := p + Vector3(0, 10.5, 0)
	A.add(raid.world, A.bevel_box(Vector3(2.2, 2.4, 3.4), 0.1, 0.9), A.paint(Color(0.5, 0.42, 0.24), 0.4, 0.6, {"wear": 0.6, "rust": 0.6}), cabin)
	A.add(raid.world, A.bevel_box(Vector3(1.8, 1.0, 0.08), 0.02), A.glass(Color(0.3, 0.45, 0.45)), cabin + Vector3(0, 0.4, 1.72))
	for sx in [-0.7, 0.7]:
		K.cable(raid, cabin + Vector3(sx, 1.2, 0), cabin + Vector3(sx * 1.4, 6.0, 0), 0.0, 0.03)


## 矿场筒仓：三只高筒仓 + 斜皮带廊 + 装车口
static func _ore_silos(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	for i in 3:
		var q := Vector3(-7.0 + i * 7.0, 0, 0)
		K.tower(raid, p + q.rotated(Vector3.UP, deg_to_rad(rot)), 2.8, 14.0, 2.8, Color(0.46, 0.44, 0.4))
		A.add(n, A.cyl(2.9, 2.2, 0.9, 18), A.paint(Color(0.42, 0.4, 0.36), 0.4, 0.6, {"rust": 0.6}), q + Vector3(0, 15.1, 0))
		A.add(n, A.cyl(0.7, 1.4, 0.7, 12), A.metal(STEEL), q + Vector3(0, 16.8, 0))
	A.add(n, A.bevel_box(Vector3(3.0, 0.5, 18.0), 0.06), A.paint(Color(0.34, 0.32, 0.29), 0.5, 0.6, {"rust": 0.8}), Vector3(0.0, 8.0, 9.0), Vector3(-26, 0, 0))
	A.add(n, A.bevel_box(Vector3(4.6, 3.0, 4.0), 0.08), A.paint(Color(0.4, 0.36, 0.28), 0.5, 0.6, {"rust": 0.7}), Vector3(0, 1.5, 5.0))
	raid.blocks.append(raid._rect_for(p + Vector3(0, 0, 5.0).rotated(Vector3.UP, deg_to_rad(rot)), Vector3(5.0, 1, 4.4)))
	raid.blocks.append(raid._rect_for(p, Vector3(20.0, 1, 6.0)))


## 悬崖索桥：两座石砌锚塔之间垂着一条木板吊桥，中间缺了几块板
static func _rope_bridge(raid, p: Vector3, rot: float) -> void:
	var dir := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(rot))
	var a := p - dir * 16.0
	var b := p + dir * 16.0
	for q in [a, b]:
		A.add(raid.world, A.bevel_box(Vector3(3.6, 6.0, 3.6), 0.12), A.concrete(Color(0.42, 0.4, 0.36), true), q + Vector3(0, 3.0, 0))
		K.blocker(raid, q, Vector3(3.6, 6.0, 3.6), rot)
		raid.blocks.append(raid._rect_for(q, Vector3(3.8, 1, 3.8)))
	var side := dir.cross(Vector3.UP)
	for off in [-1.4, 1.4]:
		K.cable(raid, a + side * off + Vector3(0, 6.0, 0), b + side * off + Vector3(0, 6.0, 0), 2.0, 0.05)
	for k in 13:
		var t := float(k) / 12.0
		var q := a.lerp(b, t)
		q.y = 5.4 - sin(t * PI) * 2.4
		if k == 6:
			continue
		A.add(raid.world, A.bevel_box(Vector3(1.4, 0.12, 2.4), 0.03), A.paint(Color(0.34, 0.27, 0.19), 0.0, 0.9, {"wear": 0.8, "dust": 0.5}), q, Vector3(0, rot, 8.0 * (-1.0 if k % 2 == 0 else 1.0)))


## 深渊虫晶簇：从菌毯里顶出来的紫晶柱，周围飘着发光的孢子
static func _crystal_cluster(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	A.ground_decal(raid.world, A.cloud_tex(), Color(0.14, 0.05, 0.18, 0.55), 14.0, p + Vector3(0, 0.03, 0))
	for i in 9:
		var a = raid.rng.randf() * TAU
		var d = raid.rng.randf_range(0.4, 5.0)
		var h = raid.rng.randf_range(1.8, 5.6)
		var q := Vector3(sin(a) * d, h * 0.5, cos(a) * d)
		A.add(n, A.prism(PackedVector2Array([Vector2(-raid.rng.randf_range(0.7, 1.3), 0), Vector2(0, h), Vector2(raid.rng.randf_range(0.7, 1.3), 0)]), raid.rng.randf_range(0.8, 1.7), 0.06),
			A.chitin(Color(0.36, 0.16, 0.52)), q, Vector3(raid.rng.randf_range(-18, 18), raid.rng.randf() * 360, raid.rng.randf_range(-18, 18)), Vector3.ONE, false)
		A.add(n, A.sphere(0.18, -1, 8), A.emit(Color(0.8, 0.45, 1.0), 1.6), q + Vector3(0, h * 0.5, 0), Vector3.ZERO, Vector3.ONE, false)
	A.emitter(raid.world, p + Vector3(0, 1.4, 0), {"amount": 22, "life": 5.0, "size": 0.24, "radius": 5.0, "spread": 80.0, "vmin": 0.15, "vmax": 0.5,
		"gravity": Vector3(0, 0.3, 0), "c0": Color(0.75, 0.42, 1.0, 0.65), "c1": Color(0.3, 0.1, 0.55, 0.0), "grow0": 1.0, "grow1": 0.2})


## 钻井井架：孤立的四脚钻塔，塔脚压着两块混凝土配重
static func _drill_derrick(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M := A.paint(Color(0.34, 0.31, 0.28), 0.6, 0.55, {"rust": 0.85, "wear": 0.5})
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			A.add(n, A.tube([Vector3(sx * 3.2, 0, sz * 3.2), Vector3(sx * 0.9, 19.0, sz * 0.9)], 0.2, 6, 3), M, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			K.blocker(raid, p + Vector3(sx * 3.2, 0, sz * 3.2).rotated(Vector3.UP, deg_to_rad(rot)), Vector3(0.5, 19.0, 0.5), 0.0, true)
	for k in 5:
		var y := 3.4 + k * 3.4
		var w := lerpf(3.2, 0.9, float(k) / 5.0)
		for sd in 4:
			var a1 := PI * 0.5 * sd
			var a2 := PI * 0.5 * (sd + 1)
			A.add(n, A.tube([Vector3(cos(a1) * w * 1.3, y, sin(a1) * w * 1.3), Vector3(cos(a2) * w * 1.3, y, sin(a2) * w * 1.3)], 0.06, 4, 2), A.metal(STEEL), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.bevel_box(Vector3(2.6, 0.8, 2.6), 0.06), A.paint(Color(0.4, 0.34, 0.24), 0.5, 0.6, {"rust": 0.8}), Vector3(0, 19.4, 0))
	for i in 2:
		A.add(n, A.bevel_box(Vector3(3.4, 1.0, 2.2), 0.08), A.concrete(Color(0.36, 0.35, 0.33), false), Vector3(-5.4 + i * 10.8, 0.5, -2.0))
	raid.blocks.append(raid._rect_for(p, Vector3(7.0, 1, 7.0)))
	_wire(n, Vector3(0, 19.0, 0), Vector3(-10.0, 0.2, 7.0), 0.6, 0.03, A.metal(STEEL))
	_wire(n, Vector3(0, 19.0, 0), Vector3(9.0, 0.2, -8.0), 0.6, 0.03, A.metal(STEEL))


## 干涸冷却渠：一条 60 米长的混凝土渠槽横切过场地，渠底开裂、盖板翻倒
static func _coolant_channel(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M := A.concrete(Color(0.34, 0.33, 0.31), true)
	for sx in [-3.4, 3.4]:
		A.add(n, A.bevel_box(Vector3(0.8, 2.4, 60.0), 0.08), M, Vector3(sx, 1.2, 0))
		K.blocker(raid, p + Vector3(sx, 0, 0).rotated(Vector3.UP, deg_to_rad(rot)), Vector3(0.8, 2.4, 60.0), rot)
		raid.blocks.append(raid._rect_for(p + Vector3(sx, 0, 0).rotated(Vector3.UP, deg_to_rad(rot)), Vector3(0.9, 1, 60.0)))
	A.add(n, A.bevel_box(Vector3(6.4, 0.3, 60.0), 0.05), A.concrete(Color(0.28, 0.27, 0.25), false), Vector3(0, 0.15, 0))
	for i in 6:
		A.add(n, A.bevel_box(Vector3(6.6, 0.2, 6.0), 0.04), A.concrete(Color(0.3, 0.29, 0.27), false), Vector3(raid.rng.randf_range(-1.2, 1.2), 1.2, -26.0 + i * 10.0), Vector3(raid.rng.randf_range(-28, 28), raid.rng.randf_range(-6, 6), raid.rng.randf_range(-24, 24)))
	for i in 5:
		A.add(n, A.bevel_box(Vector3(1.0, 1.6, 0.14), 0.02), A.paint(Color(0.3, 0.29, 0.26), 0.5, 0.6, {"rust": 0.7}), Vector3(0, 1.2, -24.0 + i * 12.0), Vector3(0, raid.rng.randf_range(-8, 8), raid.rng.randf_range(-30, 30)))


## 在某个节点下摆一根下垂的线缆（父节点的局部坐标）
static func _wire(parent: Node3D, a: Vector3, b: Vector3, sag: float, r: float, m: Material) -> void:
	var mid := (a + b) * 0.5 + Vector3(0, -sag, 0)
	var pts := [a, a.lerp(mid, 0.6) + Vector3(0, -sag * 0.25, 0), mid, b.lerp(mid, 0.6) + Vector3(0, -sag * 0.25, 0), b]
	A.add(parent, A.tube(pts, r, 5, 5), m, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)

## 程序化街区会在遗迹所在的整块街区里随机盖房，偶尔压进院落。
## 这里在自己摆地标之前，把落在新增遗迹院内的外来静态体清掉，保证院子与门口留得出来；
## 只动 StaticBody3D，容器与虫巢按组跳过，地面大盒体按尺寸跳过。
static func _clear_aprons(raid) -> void:
	var centers: Array = []
	for i in raid.poi_centers.size():
		if GameData.POIS.get(str(raid.poi_ids[i]), {}).has("script"):
			centers.append(raid.poi_centers[i])
	if centers.is_empty():
		return
	var trash: Array = []
	for ch in raid.world.get_children():
		if not (ch is StaticBody3D):
			continue
		if ch.has_meta("poi_built") or ch.is_in_group("lootboxes") or ch.is_in_group("nests") or ch.is_in_group("bugs"):
			continue
		if _huge_body(ch):
			continue
		var p: Vector3 = ch.global_position
		for c: Vector3 in centers:
			if Vector2(p.x, p.z).distance_to(Vector2(c.x, c.z)) < 16.0:
				trash.append(ch)
				break
	for t in trash:
		t.free()


static func _huge_body(body: Node) -> bool:
	for ch in body.get_children():
		if ch is CollisionShape3D and ch.shape is BoxShape3D:
			var s: Vector3 = ch.shape.size
			if s.x > 50.0 or s.z > 50.0:
				return true
		elif ch is CollisionShape3D and ch.shape is CylinderShape3D and ch.shape.radius > 20.0:
			return true
	return false
