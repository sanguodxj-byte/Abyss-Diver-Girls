extends RefCounted
## 废弃通讯中继塔：围栏院里一座 24 米高的格构塔，塔脚散着线缆盘与设备箱，
## 东侧天线基座上支着两面碟形天线；塔下的终端机还亮着，连着两只铅封的军用箱。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/map_ext/poi_kit.gd")

const STEEL := Color(0.34, 0.34, 0.32)
const FLOOR := Color(0.4, 0.4, 0.37)


static func build(raid, c: Vector3, pid: String) -> void:
	var r = raid.rng
	K.slab(raid, c, Vector2(21, 21), FLOOR)
	# 围栏：四面墙留出宽敞通道（>= 4m）
	K.wall_line(raid, c + Vector3(0, 0, -9.6), 19.0, 2.2, 0.0, [[-3.4, 0.6]], STEEL)
	K.wall_line(raid, c + Vector3(0, 0, 9.6), 19.0, 2.2, 0.0, [[1.6, 5.6]], STEEL)
	K.wall_line(raid, c + Vector3(-9.6, 0, 0), 19.0, 2.2, 90.0, [[3.4, 7.4]], STEEL)
	K.wall_line(raid, c + Vector3(9.6, 0, 0), 19.0, 2.2, 90.0, [[-6.6, -2.6]], STEEL)
	# 格构塔：收分主材 + 交叉斜撑 + 高细分圆形检修平台与护栏 + 顶部天线
	var tp := c + Vector3(0, 0, 0.5)
	_mast(raid, tp, 24.0, 6.0)
	var M_PLAT := A.metal(Color(0.3, 0.3, 0.28))
	for y in [6.0, 12.0, 18.0]:
		var rp: float = 1.45 - y * 0.03
		A.add(raid.world, A.cyl(rp, 0.16, rp, 32), M_PLAT, tp + Vector3(0, y, 0))
		A.add(raid.world, A.torus(rp - 0.04, rp + 0.04, 32), M_PLAT, tp + Vector3(0, y + 0.5, 0), Vector3.ZERO, Vector3(1, 0.45, 1), false)
	A.add(raid.world, A.cyl(0.12, 7.0, 0.05, 16), A.metal(Color(0.4, 0.4, 0.38)), tp + Vector3(0, 27.0, 0))
	A.add(raid.world, A.sphere(0.22, -1, 20), A.emit(Color(1.0, 0.18, 0.12), 2.2), tp + Vector3(0, 30.4, 0), Vector3.ZERO, Vector3.ONE, false)
	for i in 3:
		var a := TAU * i / 3.0
		K.cable(raid, tp + Vector3(cos(a) * 2.2, 18.0, sin(a) * 2.2), tp + Vector3(cos(a) * 8.0, 0.2, sin(a) * 8.0), 0.2, 0.035)
	# 设备棚：三面墙，门朝院子
	var sp := c + Vector3(-6.2, 0, 6.0)
	K.wall_line(raid, sp + Vector3(0, 0, -2.6), 6.4, 3.0, 0.0, [], Color(0.42, 0.42, 0.39))
	K.wall_line(raid, sp + Vector3(-3.1, 0, 0), 5.2, 3.0, 90.0, [], Color(0.42, 0.42, 0.39))
	K.wall_line(raid, sp + Vector3(3.1, 0, 0), 5.2, 3.0, 90.0, [[-1.2, 2.8]], Color(0.42, 0.42, 0.39))
	A.add(raid.world, A.bevel_box(Vector3(6.8, 0.2, 5.6), 0.04), A.paint(Color(0.35, 0.36, 0.33), 0.4, 0.6, {"rust": 0.7, "wear": 0.5}), sp + Vector3(0, 3.1, 0))
	K.roof_kit(raid, sp, Vector2(6.8, 5.6), 3.2, Color(0.42, 0.42, 0.39))
	A.add(raid.world, A.bevel_box(Vector3(1.2, 1.8, 0.8), 0.04), A.paint(Color(0.28, 0.3, 0.28), 0.4, 0.6, {"rust": 0.6}), sp + Vector3(-1.6, 0.9, 1.2))
	# 高精度抛物面碟形天线：独立 Node3D 承载 36 段碟面 + 外缘加强圈 + 三脚馈源斜撑杆与高频头
	for i in 2:
		var ap := c + Vector3(7.2, 0, -5.2 + i * 3.0)
		A.add(raid.world, A.cyl(0.65, 0.3, 0.75, 28), A.concrete(Color(0.44, 0.43, 0.4), false), ap + Vector3(0, 0.15, 0))
		A.add(raid.world, A.cyl(0.18, 2.4, 0.22, 20), A.metal(Color(0.36, 0.36, 0.34)), ap + Vector3(0, 1.2, 0))
		var dish := Node3D.new()
		raid.world.add_child(dish)
		dish.position = ap + Vector3(0, 3.2, 0)
		dish.rotation_degrees = Vector3(-42, 24 + i * 40, 0)
		A.add(dish, A.cyl(1.8, 0.7, 0.35, 36), A.paint(Color(0.55, 0.55, 0.53), 0.7, 0.35, {"wear": 0.4, "rust": 0.5, "panel_scale": 0.0}), Vector3.ZERO)
		A.add(dish, A.cyl(1.58, 0.1, 1.58, 36), A.metal(Color(0.24, 0.24, 0.23)), Vector3(0, 0.34, 0))
		A.add(dish, A.torus(1.72, 1.84, 36), M_PLAT, Vector3(0, 0.35, 0), Vector3.ZERO, Vector3(1, 0.45, 1), false)
		for st_i in 3:
			var sa := TAU * float(st_i) / 3.0
			A.add(dish, A.tube([Vector3(cos(sa) * 1.55, 0.35, sin(sa) * 1.55), Vector3(0, 1.38, 0)], 0.028, 6, 2), M_PLAT, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		A.add(dish, A.cyl(0.14, 0.34, 0.18, 16), A.metal(Color(0.48, 0.48, 0.46)), Vector3(0, 1.38, 0))
		raid.blocks.append(raid._rect_for(ap, Vector3(2.0, 1, 2.0)))
	# 线缆盘、配电箱、散落的线缆
	for p in [Vector3(-3.2, 0, -6.4), Vector3(-4.6, 0, -4.0)]:
		A.add(raid.world, A.cyl(1.0, 0.75, 1.0, 28), A.paint(Color(0.3, 0.25, 0.18), 0.25, 0.85, {"rust": 0.8, "wear": 0.5}), c + p + Vector3(0, 0.38, 0))
		A.add(raid.world, A.cyl(0.3, 0.8, 0.3, 18), A.metal(Color(0.2, 0.2, 0.19)), c + p + Vector3(0, 0.4, 0), Vector3(0, 0, 90))
	for i in 3:
		var a = r.randf() * TAU
		A.add(raid.world, A.tube([c + Vector3(cos(a) * 2.0, 0.08, sin(a) * 2.0), c + Vector3(cos(a) * 6.0, 0.08, sin(a) * 5.0), c + Vector3(cos(a) * 8.0, 0.1, sin(a) * 7.0)], 0.05, 8, 3), A.rubber(), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	# 终端机：桌面 + 亮着的屏幕
	var term := c + Vector3(4.0, 0, -6.2)
	K.desk(raid, term, 180.0, 2.6, Color(0.3, 0.32, 0.3))
	A.add(raid.world, A.bevel_box(Vector3(0.9, 0.7, 0.1), 0.02), A.paint(Color(0.15, 0.16, 0.15), 0.3, 0.5), term + Vector3(0, 1.25, -0.1), Vector3(-14, 0, 0))
	A.add(raid.world, A.bevel_box(Vector3(0.78, 0.52, 0.04), 0.01), A.emit(Color(0.3, 0.8, 0.55), 1.1), term + Vector3(0, 1.26, -0.17), Vector3(-14, 0, 0), Vector3.ONE, false)
	A.add(raid.world, A.bevel_box(Vector3(1.0, 0.08, 0.5), 0.01), A.paint(Color(0.2, 0.22, 0.2), 0.3, 0.6), term + Vector3(0, 1.0, 0.6))
	# 铅封军用箱：独立 Node3D 节点（钢箍铅封条 + 警示封带 + 机械锁扣），终端解锁后整节点替换为真容器
	var sealed: Array = []
	var M_STRAP := A.metal(Color(0.18, 0.19, 0.20))
	for p in [Vector3(-2.6, 0, -8.0), Vector3(-0.9, 0, -8.2)]:
		var b := Node3D.new()
		raid.world.add_child(b)
		b.position = c + p
		A.add(b, A.bevel_box(Vector3(1.65, 0.82, 0.98), 0.06), A.paint(Color(0.28, 0.32, 0.23), 0.32, 0.65, {"wear": 0.6, "rust": 0.5, "dust": 0.5}), Vector3(0, 0.41, 0))
		A.add(b, A.bevel_box(Vector3(1.70, 0.12, 1.02), 0.02), A.hazard(), Vector3(0, 0.68, 0))
		for sx_s in [-0.48, 0.48]:
			A.add(b, A.bevel_box(Vector3(0.08, 0.86, 1.04), 0.01), M_STRAP, Vector3(sx_s, 0.42, 0))
		A.add(b, A.bevel_box(Vector3(0.16, 0.20, 0.08), 0.01), A.paint(Color(0.72, 0.18, 0.14), 0.3, 0.5), Vector3(0, 0.58, 0.52))
		sealed.append({"pos": c + p, "node": b})
	# 容器与环境叙事
	K.crate(raid, term + Vector3(0.2, 0, 1.4), "tool")
	K.fixed(raid, c + Vector3(4.6, 0, -8.2), ["arch_research_note", "hdd"], "tool")
	K.crate(raid, sp + Vector3(0.6, 0, -0.6), "safe")
	K.crate(raid, c + Vector3(-4.5, 0, -6.0), "supply")
	K.crate(raid, c + Vector3(7.4, 0, 6.8), "military")
	K.lamp(raid, c + Vector3(-8.2, 0, -8.4), Color(0.7, 0.9, 1.0))
	K.lamp(raid, c + Vector3(8.4, 0, 2.0), Color(1.0, 0.7, 0.4))
	K.rubble(raid, c + Vector3(3.0, 0, 4.0), 1.4)
	K.guard(raid, c + Vector3(1.6, 0, 3.0), "beetle", 3.0)
	K.guard(raid, c + Vector3(-5.0, 0, -2.0), "spitter", 2.6)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 9.0)
	K.tag_boxes(raid, c, pid)
	# 解锁关系交给行动扩展脚本：终端被打开后，铅封箱换成真正的军用储物箱
	var unlocks: Array = raid.get_meta("poi_unlocks", [])
	unlocks.append({"terminal": term + Vector3(0, 0, 1.4), "caches": sealed})
	raid.set_meta("poi_unlocks", unlocks)


## 格构主塔：四根收分主材、每层横撑与斜撑
static func _mast(raid, p: Vector3, hgt: float, base: float) -> void:
	var M := A.metal(STEEL)
	var top := 1.1
	var M2 := A.metal(Color(0.26, 0.26, 0.25))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			A.add(raid.world, A.tube([p + Vector3(sx * base * 0.5, 0, sz * base * 0.5), p + Vector3(sx * top * 0.5, hgt, sz * top * 0.5)], 0.13, 8, 2), M, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	for k in 6:
		var t := float(k) / 6.0
		var t2 := float(k + 1) / 6.0
		var r1 := lerpf(base, top, t) * 0.5
		var r2 := lerpf(base, top, t2) * 0.5
		var y1 := hgt * t
		var y2 := hgt * t2
		for sd in 4:
			var a1 := PI * 0.5 * sd
			var a2 := PI * 0.5 * (sd + 1)
			var c1 := p + Vector3(cos(a1) * r1 * 1.41, y1, sin(a1) * r1 * 1.41)
			var c2 := p + Vector3(cos(a2) * r1 * 1.41, y1, sin(a2) * r1 * 1.41)
			var d1 := p + Vector3(cos(a1) * r2 * 1.41, y2, sin(a1) * r2 * 1.41)
			var d2 := p + Vector3(cos(a2) * r2 * 1.41, y2, sin(a2) * r2 * 1.41)
			A.add(raid.world, A.tube([c1, c2], 0.05, 6, 2), M2, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			A.add(raid.world, A.tube([c1, d2], 0.045, 6, 2), M2, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			A.add(raid.world, A.tube([c2, d1], 0.045, 6, 2), M2, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	raid.blocks.append(raid._rect_for(p, Vector3(base, 1, base)))
