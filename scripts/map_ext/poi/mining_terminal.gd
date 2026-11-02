extends RefCounted
## 深井选矿终端：龙门吊跨在窄轨上，皮带输送机斜插进三座筒仓，矿车停在装车线，
## 高架控制室里还亮着几块指示屏，地上堆着虫晶与矿石。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/map_ext/poi_kit.gd")

const STEEL := Color(0.34, 0.34, 0.31)
const ORE := Color(0.2, 0.18, 0.2)


static func build(raid, c: Vector3, pid: String) -> void:
	var r = raid.rng
	K.slab(raid, c, Vector2(26, 20), Color(0.36, 0.35, 0.33))
	# 龙门吊：地面轨道 + 两副 A 形支腿 + 主梁
	for sx in [-9.0, 9.0]:
		A.add(raid.world, A.bevel_box(Vector3(0.5, 0.22, 17.0), 0.04), A.metal(Color(0.4, 0.4, 0.38)), c + Vector3(sx, 0.12, 0))
		for sz in [-6.0, 6.0]:
			var leg := c + Vector3(sx, 0, sz)
			for k in 2:
				var lean := -0.55 if k == 0 else 0.55
				A.add(raid.world, A.tube([leg + Vector3(lean * 2.6, 0, 0), leg + Vector3(lean * 0.4, 12.0, 0)], 0.18, 6, 2), A.metal(STEEL), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			A.add(raid.world, A.bevel_box(Vector3(0.7, 0.6, 1.2), 0.05), A.paint(Color(0.36, 0.37, 0.33), 0.4, 0.6, {"rust": 0.7}), leg + Vector3(0, 0.3, 0))
			raid.blocks.append(raid._rect_for(leg, Vector3(2.4, 1, 2.4)))
	A.add(raid.world, A.bevel_box(Vector3(19.4, 0.8, 1.0), 0.06), A.paint(Color(0.4, 0.4, 0.36), 0.5, 0.55, {"rust": 0.7, "wear": 0.5}), c + Vector3(0, 12.4, -6.0))
	A.add(raid.world, A.bevel_box(Vector3(19.4, 0.8, 1.0), 0.06), A.paint(Color(0.4, 0.4, 0.36), 0.5, 0.55, {"rust": 0.7, "wear": 0.5}), c + Vector3(0, 12.4, 6.0))
	for i in 9:
		A.add(raid.world, A.bevel_box(Vector3(0.24, 0.24, 12.4), 0.02), A.metal(STEEL), c + Vector3(-8.8 + i * 2.2, 12.9, 0), Vector3.ZERO, Vector3.ONE, false)
	# 吊车小车与吊钩
	var trolley := c + Vector3(2.0, 11.6, 0)
	A.add(raid.world, A.bevel_box(Vector3(3.0, 1.0, 3.0), 0.06), A.paint(Color(0.5, 0.42, 0.2), 0.4, 0.6, {"wear": 0.6, "rust": 0.7}), trolley)
	K.cable(raid, trolley + Vector3(0, -0.4, 0), trolley + Vector3(0, -7.0, 0), 0.0, 0.06, Color(0.25, 0.25, 0.24))
	A.add(raid.world, A.bevel_box(Vector3(1.6, 0.8, 0.5), 0.08), A.paint(Color(0.45, 0.36, 0.18), 0.5, 0.6, {"rust": 0.8}), trolley + Vector3(0, -7.4, 0))
	# 皮带输送机：从地面斜上筒仓
	var belt := Node3D.new()
	raid.world.add_child(belt)
	belt.position = c + Vector3(-4.6, 0, 2.0)
	belt.rotation_degrees = Vector3(0, -14, -22)
	A.add(belt, A.bevel_box(Vector3(3.0, 0.5, 16.0), 0.05), A.paint(Color(0.26, 0.25, 0.23), 0.5, 0.7, {"rust": 0.8, "wear": 0.5}), Vector3(0, 2.4, 0))
	for k in 8:
		A.add(belt, A.cyl(0.3, 3.1, 0.3, 10), A.rubber(), Vector3(0, 2.7, -7.0 + k * 2.0), Vector3(0, 0, 90))
	for sx in [-1.6, 1.6]:
		for k in 4:
			A.add(belt, A.cyl(0.1, 3.4, 0.1, 6), A.metal(STEEL), Vector3(sx, 0.9, -6.0 + k * 4.0))
	# 三座筒仓：锥底 + 圆筒 + 顶盖
	for i in 3:
		var p := c + Vector3(-12.0 + i * 4.6, 0, -7.6)
		A.add(raid.world, A.cyl(2.4, 3.0, 0.7, 20), A.concrete(Color(0.46, 0.44, 0.4), false), p + Vector3(0, 1.5, 0))
		K.tower(raid, p + Vector3(0, 3.0, 0), 2.4, 8.0, 2.4, Color(0.5, 0.48, 0.43))
		A.add(raid.world, A.cyl(2.5, 0.5, 2.5, 20), A.paint(Color(0.35, 0.35, 0.32), 0.4, 0.6, {"rust": 0.7}), p + Vector3(0, 11.2, 0))
		A.add(raid.world, A.cyl(0.5, 0.6, 0.5, 12), A.metal(STEEL), p + Vector3(0, 11.7, 0))
	# 窄轨与矿车
	for sx in [-2.6, 2.6]:
		A.add(raid.world, A.bevel_box(Vector3(0.12, 0.16, 18.0), 0.02), A.metal(Color(0.42, 0.4, 0.36)), c + Vector3(sx, 0.16, 0.0), Vector3.ZERO, Vector3.ONE, false)
	for i in 4:
		A.add(raid.world, A.bevel_box(Vector3(5.6, 0.1, 0.5), 0.01), A.paint(Color(0.22, 0.19, 0.16), 0.0, 0.9), c + Vector3(0, 0.1, -7.0 + i * 4.6), Vector3.ZERO, Vector3.ONE, false)
	for k in 3:
		var p := c + Vector3(0, 0, -5.0 + k * 5.6)
		var cart := Node3D.new()
		raid.world.add_child(cart)
		cart.position = p
		cart.rotation_degrees.y = r.randf_range(-4, 4)
		A.add(cart, A.bevel_box(Vector3(2.4, 1.4, 3.2), 0.06, 0.82), A.paint(Color(0.42, 0.35, 0.24), 0.5, 0.6, {"rust": 0.8, "wear": 0.6}), Vector3(0, 1.0, 0))
		A.add(cart, A.bevel_box(Vector3(2.0, 0.2, 2.6), 0.02), A.paint(ORE, 0.2, 0.9), Vector3(0, 1.66, 0))
		for sx in [-0.9, 0.9]:
			for sz in [-1.2, 1.2]:
				A.add(cart, A.cyl(0.34, 0.16, 0.34, 10), A.metal(Color(0.25, 0.25, 0.24)), Vector3(sx, 0.34, sz), Vector3(0, 0, 90))
		raid.blocks.append(raid._rect_for(p, Vector3(2.8, 1, 3.6)))
		K.blocker(raid, p, Vector3(2.4, 1.4, 3.2), cart.rotation_degrees.y)
	# 矿石堆与虫晶露头
	for i in 4:
		var p = c + Vector3(r.randf_range(-10, 10), 0, r.randf_range(2, 8))
		A.add(raid.world, A.cyl(1.8, 1.4, 0.3, 10), A.paint(Color(0.26, 0.24, 0.22), 0.2, 0.95, {"wear": 0.4, "dust": 0.7}), p + Vector3(0, 0.7, 0))
	for i in 3:
		var p = c + Vector3(r.randf_range(-8, 8), 0, r.randf_range(-8, -2))
		var cr = A.add(raid.world, A.prism(PackedVector2Array([Vector2(-0.5, 0), Vector2(0, 1.8), Vector2(0.5, 0)]), 0.5, 0.05), A.chitin(Color(0.42, 0.22, 0.55)), p + Vector3(0, 0.9, 0), Vector3(r.randf_range(-12, 12), r.randf() * 360, 0), Vector3.ONE, false)
		A.add(raid.world, A.sphere(0.25, -1, 10), A.emit(Color(0.75, 0.4, 1.0), 1.4), p + Vector3(0, 1.9, 0), Vector3.ZERO, Vector3.ONE, false)
	# 高架控制室：四根立柱 + 小房间 + 楼梯
	var cp := c + Vector3(8.4, 0, 6.0)
	for sx in [-1.8, 1.8]:
		for sz in [-1.6, 1.6]:
			A.add(raid.world, A.cyl(0.16, 4.2, 0.16, 8), A.metal(STEEL), cp + Vector3(sx, 2.1, sz))
	raid.blocks.append(raid._rect_for(cp, Vector3(4.0, 1, 3.6)))
	var cab := A.add(raid.world, A.bevel_box(Vector3(4.2, 2.6, 3.6), 0.08), A.paint(Color(0.44, 0.42, 0.36), 0.35, 0.6, {"wear": 0.5, "rust": 0.5}), cp + Vector3(0, 5.5, 0))
	A.add(cab, A.bevel_box(Vector3(3.2, 1.1, 0.1), 0.01), A.glass(Color(0.3, 0.55, 0.5)), Vector3(0, 0.3, -1.82), Vector3.ZERO, Vector3.ONE, false)
	A.add(cab, A.bevel_box(Vector3(4.4, 0.2, 3.8), 0.03), A.metal(STEEL), Vector3(0, 1.4, 0))
	K.steps(raid, cp + Vector3(2.6, 0, 2.2), 12, 0.36, 0.34, 1.4, 0.0)
	# 容器与环境叙事
	K.crate(raid, c + Vector3(10.8, 0, -2.0), "safe")
	K.crate(raid, c + Vector3(5.6, 0, -8.2), "tool")
	K.crate(raid, c + Vector3(4.0, 0, -8.4), "tool")
	K.crate(raid, c + Vector3(-8.4, 0, 8.2), "military")
	K.fixed(raid, c + Vector3(-7.0, 0, 7.4), ["bug_crystal", "chitin"], "tool")
	K.fixed(raid, c + Vector3(9.4, 0, 4.4), ["arch_shift_log", "circuit"], "tool")
	K.lamp(raid, c + Vector3(-12.6, 0, 8.6), Color(1.0, 0.74, 0.42))
	K.lamp(raid, c + Vector3(12.4, 0, -8.6), Color(0.7, 0.86, 1.0))
	K.rubble(raid, c + Vector3(-2.0, 0, 9.0), 1.6, Color(0.3, 0.29, 0.27))
	K.guard(raid, c + Vector3(0.0, 0, 4.0), "beetle", 3.0)
	K.guard(raid, c + Vector3(-8.0, 0, -2.0), "beetle", 3.2)
	K.guard(raid, c + Vector3(7.0, 0, 0.0), "ling", 2.2)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 12.0)
	K.tag_boxes(raid, c, pid)
