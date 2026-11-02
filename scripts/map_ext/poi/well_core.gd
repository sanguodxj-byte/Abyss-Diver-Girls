extends RefCounted
## 零号钻井核心台：环形混凝土平台围着一口黑下去的竖井，井口立着 20 米高的钻塔，
## 塔索垂进井里；平台外缘全是紫光虫晶簇与菌毯，控制台还亮着余电。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/map_ext/poi_kit.gd")

const ROCK := Color(0.16, 0.13, 0.18)
const PLATE := Color(0.3, 0.29, 0.32)


static func build(raid, c: Vector3, pid: String) -> void:
	var r = raid.rng
	# 环形平台：八段弧形甲板
	for i in 8:
		var a := TAU * i / 8.0
		var seg := A.add(raid.world, A.bevel_box(Vector3(7.2, 0.36, 4.2), 0.06), A.concrete(PLATE, true),
			c + Vector3(sin(a) * 9.0, 0.18, cos(a) * 9.0), Vector3(0, -rad_to_deg(a), 0))
		A.add(seg, A.bevel_box(Vector3(7.24, 0.06, 0.4), 0.02), A.metal(Color(0.28, 0.27, 0.3)), Vector3(0, 0.18, 1.9), Vector3.ZERO, Vector3.ONE, false)
		A.add(seg, A.bevel_box(Vector3(7.24, 0.05, 0.18), 0.01), A.emit(Color(0.45, 0.75, 0.85), 0.6), Vector3(0, 0.19, -1.94), Vector3.ZERO, Vector3.ONE, false)
	# 井口：黑下去的岩壁 + 紫光核心
	A.add(raid.world, A.cyl(6.4, 0.12, 6.4, 32), A.paint(Color(0.02, 0.01, 0.03), 0.0, 1.0, {"wear": 0.0, "dust": 0.0, "rust": 0.0, "panel_scale": 0.0}), c + Vector3(0, 0.02, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(raid.world, A.cyl(4.6, 0.1, 4.6, 28), A.paint(Color(0.05, 0.02, 0.07), 0.0, 1.0, {"wear": 0.0, "dust": 0.0, "rust": 0.0, "panel_scale": 0.0}), c + Vector3(0, -0.4, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(raid.world, A.sphere(2.2, -1, 22), A.emit(Color(0.55, 0.2, 0.95), 1.4), c + Vector3(0, -1.6, 0), Vector3.ZERO, Vector3.ONE, false)
	for i in 10:
		var a := TAU * i / 10.0
		var p := c + Vector3(sin(a) * 6.2, 0, cos(a) * 6.2)
		A.add(raid.world, A.prism(PackedVector2Array([Vector2(-0.6, 0), Vector2(0, 1.1), Vector2(0.6, 0)]), 0.9, 0.05), A.chitin(ROCK), p, Vector3(r.randf_range(-8, 8), rad_to_deg(a), 0))
	# 井口护栏：一圈断掉的格栅
	for i in 12:
		var a := TAU * i / 12.0
		if i % 5 == 4:
			continue
		A.add(raid.world, A.cyl(0.06, 1.2, 0.06, 6), A.metal(Color(0.32, 0.31, 0.33)), c + Vector3(sin(a) * 6.8, 0.6, cos(a) * 6.8))
	A.add(raid.world, A.torus(6.8, 7.0, 36), A.metal(Color(0.3, 0.29, 0.31)), c + Vector3(0, 1.2, 0))
	# 钻塔：四根收分主材 + 横撑 + 天车
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var a := c + Vector3(sx * 3.4, 0, sz * 3.4)
			var b := c + Vector3(sx * 1.0, 20.0, sz * 1.0)
			A.add(raid.world, A.tube([a, b], 0.2, 6, 3), A.paint(Color(0.36, 0.34, 0.3), 0.6, 0.5, {"rust": 0.8, "wear": 0.5}), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		raid.blocks.append(raid._rect_for(c + Vector3(sx * 3.4, 0, 0), Vector3(1.2, 1, 7.2)))
	for k in 5:
		var y := 3.0 + k * 3.6
		var w := lerpf(3.4, 1.0, float(k) / 5.0)
		for sd in 4:
			var a := PI * 0.5 * sd
			var b := PI * 0.5 * (sd + 1)
			A.add(raid.world, A.tube([c + Vector3(cos(a) * w * 1.4, y, sin(a) * w * 1.4), c + Vector3(cos(b) * w * 1.4, y, sin(b) * w * 1.4)], 0.07, 4, 2), A.metal(Color(0.3, 0.29, 0.27)), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(raid.world, A.bevel_box(Vector3(3.0, 0.9, 3.0), 0.08), A.paint(Color(0.38, 0.34, 0.26), 0.5, 0.55, {"rust": 0.8}), c + Vector3(0, 20.4, 0))
	for i in 3:
		var a := TAU * i / 3.0
		K.cable(raid, c + Vector3(cos(a) * 2.4, 20.2, sin(a) * 2.4), c + Vector3(cos(a) * 2.6, 0.2, sin(a) * 2.6), 0.0, 0.07, Color(0.22, 0.21, 0.2))
	# 控制台：三组机柜围在平台北侧
	for i in 3:
		var a := -0.5 + i * 0.5
		var p := c + Vector3(sin(a) * 11.2, 0, cos(a) * 11.2)
		A.add(raid.world, A.bevel_box(Vector3(2.6, 1.5, 1.0), 0.05), A.paint(Color(0.24, 0.27, 0.28), 0.4, 0.5, {"wear": 0.5, "rust": 0.5}), p + Vector3(0, 1.1, 0), Vector3(0, -rad_to_deg(a), 0))
		A.add(raid.world, A.bevel_box(Vector3(2.0, 0.6, 0.1), 0.01), A.emit(Color(0.4, 0.9, 0.75), 0.8), p + Vector3(0, 1.5, -0.52), Vector3(-18, -rad_to_deg(a), 0), Vector3.ONE, false)
		raid.blocks.append(raid._rect_for(p, Vector3(2.8, 1, 1.4)))
	# 虫晶簇：平台外缘的高晶与孢子
	for i in 8:
		var a := TAU * i / 8.0 + 0.3
		var d = r.randf_range(13.0, 15.5)
		var p := c + Vector3(sin(a) * d, 0, cos(a) * d)
		for k in 3:
			var h = r.randf_range(2.0, 5.2)
			var w = r.randf_range(0.8, 1.4)
			A.add(raid.world, A.prism(PackedVector2Array([Vector2(-w, 0), Vector2(0, h), Vector2(w, 0)]), r.randf_range(1.0, 1.9), 0.08),
				A.chitin(Color(0.3, 0.13, 0.46)), p + Vector3(r.randf_range(-1.0, 1.0), h * 0.5, r.randf_range(-1.0, 1.0)), Vector3(r.randf_range(-9, 9), r.randf() * 360, r.randf_range(-9, 9)), Vector3.ONE, false)
			A.add(raid.world, A.sphere(0.16, -1, 8), A.emit(Color(0.8, 0.45, 1.0), 2.0), p + Vector3(r.randf_range(-1.0, 1.0), h * 0.92, r.randf_range(-1.0, 1.0)), Vector3.ZERO, Vector3.ONE, false)
		A.add(raid.world, A.sphere(0.3, -1, 10), A.emit(Color(0.75, 0.4, 1.0), 1.8), p + Vector3(0, 1.2, 0), Vector3.ZERO, Vector3.ONE, false)
		A.emitter(raid.world, p + Vector3(0, 1.0, 0), {"amount": 14, "life": 4.5, "size": 0.22, "spread": 60.0, "vmin": 0.2, "vmax": 0.7,
			"gravity": Vector3(0, 0.35, 0), "c0": Color(0.7, 0.4, 1.0, 0.7), "c1": Color(0.3, 0.1, 0.55, 0.0), "grow0": 1.0, "grow1": 0.2})
	# 菌毯与散落的钻头、管道
	for i in 6:
		var a = r.randf() * TAU
		var d = r.randf_range(8.0, 14.0)
		A.ground_decal(raid.world, A.cloud_tex(), Color(0.12, 0.05, 0.16, 0.5), r.randf_range(3.0, 6.0), c + Vector3(sin(a) * d, 0.03, cos(a) * d))
	for i in 4:
		A.add(raid.world, A.cyl(0.5, 0.9, 0.5, 12), A.paint(Color(0.28, 0.27, 0.26), 0.6, 0.5, {"rust": 0.7}), c + Vector3(r.randf_range(-12, 12), 0.45, r.randf_range(-12, 12)), Vector3(r.randf_range(-20, 20), r.randf() * 360, r.randf_range(-20, 20)))
	K.pipe(raid, c + Vector3(-10.4, 0.9, -6.0), c + Vector3(-10.4, 0.9, 6.0), 0.3, Color(0.3, 0.28, 0.3))
	# 容器与环境叙事
	K.crate(raid, c + Vector3(12.6, 0, 0.6), "safe")
	K.crate(raid, c + Vector3(-1.0, 0, 12.6), "safe")
	K.crate(raid, c + Vector3(-12.4, 0, -1.2), "military")
	K.crate(raid, c + Vector3(8.6, 0, -10.4), "military")
	K.fixed(raid, c + Vector3(10.8, 0, -8.0), ["arch_deep_record", "bug_crystal"], "tool")
	K.fixed(raid, c + Vector3(-9.0, 0, 9.4), ["bug_crystal", "chitin", "chitin"], "tool")
	K.lamp(raid, c + Vector3(14.6, 0, 9.4), Color(0.7, 0.45, 1.0))
	K.lamp(raid, c + Vector3(-14.6, 0, -9.4), Color(0.5, 0.85, 0.9))
	K.guard(raid, c + Vector3(0.0, 0, 11.0), "beetle", 3.0)
	K.guard(raid, c + Vector3(-10.0, 0, 0.0), "beetle", 3.4)
	K.guard(raid, c + Vector3(7.0, 0, 8.0), "spitter", 2.6)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 13.0)
	K.tag_boxes(raid, c, pid)
