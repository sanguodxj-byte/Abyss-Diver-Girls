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
	# 围栏：四面墙留出两处通道
	K.wall_line(raid, c + Vector3(0, 0, -9.6), 19.0, 2.2, 0.0, [[-3.2, 0.4]], STEEL)
	K.wall_line(raid, c + Vector3(0, 0, 9.6), 19.0, 2.2, 0.0, [[1.8, 5.2]], STEEL)
	K.wall_line(raid, c + Vector3(-9.6, 0, 0), 19.0, 2.2, 90.0, [[3.6, 7.2]], STEEL)
	K.wall_line(raid, c + Vector3(9.6, 0, 0), 19.0, 2.2, 90.0, [[-6.4, -2.8]], STEEL)
	# 格构塔：收分主材 + 交叉斜撑 + 平台与顶部天线
	var tp := c + Vector3(0, 0, 0.5)
	_mast(raid, tp, 24.0, 6.0)
	for y in [6.0, 12.0, 18.0]:
		A.add(raid.world, A.cyl(1.3 - y * 0.03, 0.16, 1.3 - y * 0.03, 12), A.metal(Color(0.3, 0.3, 0.28)), tp + Vector3(0, y, 0))
	A.add(raid.world, A.cyl(0.12, 7.0, 0.05, 8), A.metal(Color(0.4, 0.4, 0.38)), tp + Vector3(0, 27.0, 0))
	A.add(raid.world, A.sphere(0.22, -1, 10), A.emit(Color(1.0, 0.18, 0.12), 2.2), tp + Vector3(0, 30.4, 0), Vector3.ZERO, Vector3.ONE, false)
	for i in 3:
		var a := TAU * i / 3.0
		K.cable(raid, tp + Vector3(cos(a) * 2.2, 18.0, sin(a) * 2.2), tp + Vector3(cos(a) * 8.0, 0.2, sin(a) * 8.0), 0.2, 0.035)
	# 设备棚：三面墙，门朝院子
	var sp := c + Vector3(-6.2, 0, 6.0)
	K.wall_line(raid, sp + Vector3(0, 0, -2.6), 6.4, 3.0, 0.0, [], Color(0.42, 0.42, 0.39))
	K.wall_line(raid, sp + Vector3(-3.1, 0, 0), 5.2, 3.0, 90.0, [], Color(0.42, 0.42, 0.39))
	K.wall_line(raid, sp + Vector3(3.1, 0, 0), 5.2, 3.0, 90.0, [[0.2, 2.8]], Color(0.42, 0.42, 0.39))
	A.add(raid.world, A.bevel_box(Vector3(6.8, 0.2, 5.6), 0.04), A.paint(Color(0.35, 0.36, 0.33), 0.4, 0.6, {"rust": 0.7, "wear": 0.5}), sp + Vector3(0, 3.1, 0))
	K.roof_kit(raid, sp, Vector2(6.8, 5.6), 3.2, Color(0.42, 0.42, 0.39))
	A.add(raid.world, A.bevel_box(Vector3(1.2, 1.8, 0.8), 0.04), A.paint(Color(0.28, 0.3, 0.28), 0.4, 0.6, {"rust": 0.6}), sp + Vector3(-1.6, 0.9, 1.2))
	# 碟形天线：压扁的球面 + 支架
	for i in 2:
		var ap := c + Vector3(7.2, 0, -5.2 + i * 3.0)
		A.add(raid.world, A.cyl(0.18, 2.4, 0.18, 8), A.metal(Color(0.36, 0.36, 0.34)), ap + Vector3(0, 1.2, 0))
		var dish := A.add(raid.world, A.cyl(1.8, 0.7, 0.35, 24), A.paint(Color(0.55, 0.55, 0.53), 0.7, 0.35, {"wear": 0.4, "rust": 0.5, "panel_scale": 0.0}), ap + Vector3(0, 3.2, 0), Vector3(-42, 24 + i * 40, 0))
		A.add(dish, A.cyl(1.55, 0.1, 1.55, 24), A.metal(Color(0.24, 0.24, 0.23)), Vector3(0, 0.34, 0))
		A.add(raid.world, A.cyl(0.06, 1.8, 0.06, 5), A.metal(Color(0.5, 0.5, 0.48)), ap + Vector3(0, 4.1, 0), Vector3(-12, 0, 0))
		raid.blocks.append(raid._rect_for(ap, Vector3(2.0, 1, 2.0)))
	# 线缆盘、配电箱、散落的线缆
	for p in [Vector3(-3.2, 0, -6.4), Vector3(-4.6, 0, -4.0)]:
		A.add(raid.world, A.cyl(1.0, 0.75, 1.0, 16), A.paint(Color(0.3, 0.25, 0.18), 0.25, 0.85, {"rust": 0.8, "wear": 0.5}), c + p + Vector3(0, 0.38, 0))
		A.add(raid.world, A.cyl(0.3, 0.8, 0.3, 8), A.metal(Color(0.2, 0.2, 0.19)), c + p + Vector3(0, 0.4, 0), Vector3(0, 0, 90))
	for i in 3:
		var a = r.randf() * TAU
		A.add(raid.world, A.tube([c + Vector3(cos(a) * 2.0, 0.08, sin(a) * 2.0), c + Vector3(cos(a) * 6.0, 0.08, sin(a) * 5.0), c + Vector3(cos(a) * 8.0, 0.1, sin(a) * 7.0)], 0.05, 4, 3), A.rubber(), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	# 终端机：桌面 + 亮着的屏幕
	var term := c + Vector3(4.0, 0, -6.2)
	K.desk(raid, term, 180.0, 2.6, Color(0.3, 0.32, 0.3))
	A.add(raid.world, A.bevel_box(Vector3(0.9, 0.7, 0.1), 0.02), A.paint(Color(0.15, 0.16, 0.15), 0.3, 0.5), term + Vector3(0, 1.25, -0.1), Vector3(-14, 0, 0))
	A.add(raid.world, A.bevel_box(Vector3(0.78, 0.52, 0.04), 0.01), A.emit(Color(0.3, 0.8, 0.55), 1.1), term + Vector3(0, 1.26, -0.17), Vector3(-14, 0, 0), Vector3.ONE, false)
	A.add(raid.world, A.bevel_box(Vector3(1.0, 0.08, 0.5), 0.01), A.paint(Color(0.2, 0.22, 0.2), 0.3, 0.6), term + Vector3(0, 1.0, 0.6))
	# 铅封军用箱：终端解锁后由行动扩展脚本换成真容器
	var sealed: Array = []
	for p in [Vector3(-2.6, 0, -8.0), Vector3(-0.9, 0, -8.2)]:
		var b := A.add(raid.world, A.bevel_box(Vector3(1.9, 0.9, 1.0), 0.07), A.paint(Color(0.3, 0.32, 0.24), 0.15, 0.75, {"wear": 0.6, "rust": 0.5, "dust": 0.6}), c + p + Vector3(0, 0.4, 0))
		A.add(b, A.bevel_box(Vector3(1.95, 0.12, 1.02), 0.02), A.hazard(), Vector3(0, 0.3, 0))
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
			A.add(raid.world, A.tube([p + Vector3(sx * base * 0.5, 0, sz * base * 0.5), p + Vector3(sx * top * 0.5, hgt, sz * top * 0.5)], 0.13, 6, 2), M, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
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
			A.add(raid.world, A.tube([c1, c2], 0.05, 4, 2), M2, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			A.add(raid.world, A.tube([c1, d2], 0.045, 4, 2), M2, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			A.add(raid.world, A.tube([c2, d1], 0.045, 4, 2), M2, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	raid.blocks.append(raid._rect_for(p, Vector3(base, 1, base)))
