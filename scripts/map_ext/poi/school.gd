extends RefCounted
## 城西学校：北面教学楼横陈，东西两翼围出一个操场，南面是塌了顶的体育馆；
## 操场中央一根旗杆，篮球架歪在边线外，教室里课桌还按行列摆着。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/map_ext/poi_kit.gd")

const BRICK := Color(0.58, 0.5, 0.42)
const FLOOR := Color(0.48, 0.46, 0.42)


static func build(raid, c: Vector3, pid: String) -> void:
	var r = raid.rng
	K.slab(raid, c, Vector2(26, 22), FLOOR)
	# 北教学楼：实心楼体 + 两层窗带 + 断掉的女儿墙
	K.wall(raid, c + Vector3(0, 0, -7.6), Vector3(17.0, 6.4, 5.6), 0.0, BRICK)
	for y in [1.9, 4.4]:
		for x in [-6.8, -4.0, -1.2, 1.6, 4.4, 7.2]:
			A.add(raid.world, A.bevel_box(Vector3(1.5, 1.0, 0.12), 0.02), A.paint(Color(0.07, 0.09, 0.1), 0.3, 0.3), c + Vector3(x, y, -4.74), Vector3.ZERO, Vector3.ONE, false)
	for k in 3:
		A.add(raid.world, A.bevel_box(Vector3(r.randf_range(1.2, 3.0), 0.5, 0.5), 0.05), A.concrete(BRICK.darkened(0.18), false), c + Vector3(-6.0 + k * 6.0, 6.5, -4.9))
	# 正门台阶与门廊
	K.steps(raid, c + Vector3(0, 0, -3.6), 3, 0.3, 0.6, 5.0, 180.0)
	K.canopy(raid, c + Vector3(0, 0, -2.4), Vector2(6.0, 3.0), 3.4, 0.0, Color(0.5, 0.46, 0.4))
	A.stencil(raid.world, "SCHOOL 04", c + Vector3(0, 5.2, -4.72), Vector3.ZERO, 0.022, Color(0.85, 0.82, 0.72, 0.6), 48)
	K.roof_kit(raid, c + Vector3(0, 0, -7.6), Vector2(17.0, 5.6), 6.4, BRICK)
	# 东翼：三面围合的两间教室
	K.wall_line(raid, c + Vector3(9.0, 0, 1.0), 11.0, 3.6, 90.0, [[-3.6, -0.4]], BRICK)
	K.wall_line(raid, c + Vector3(9.0, 0, 6.6), 8.0, 3.4, 0.0, [[-3.2, 0.0]], BRICK.darkened(0.08))
	K.wall_line(raid, c + Vector3(5.2, 0, 6.6), 6.4, 3.4, 0.0, [], BRICK.darkened(0.08))
	K.wall_line(raid, c + Vector3(9.0, 0, -1.6), 8.0, 3.6, 0.0, [[-2.6, 0.6]], BRICK)
	# 西翼：塌了一半的教室，只剩矮墙与讲台
	K.wall_line(raid, c + Vector3(-9.0, 0, 1.0), 11.0, 2.2, 90.0, [[-3.8, -1.4], [1.2, 3.6]], BRICK.darkened(0.14))
	K.wall_line(raid, c + Vector3(-9.0, 0, 6.6), 7.0, 1.8, 0.0, [[-2.4, 0.4]], BRICK.darkened(0.14))
	# 课桌：教室里成排的桌椅
	for room in 3:
		var base: Vector3 = c + [Vector3(6.6, 0, 1.0), Vector3(11.4, 0, 1.0), Vector3(-9.0, 0, 2.0)][room]
		for row in 3:
			for col in 3:
				var p := base + Vector3(-1.4 + col * 1.4, 0, -2.0 + row * 1.7)
				A.add(raid.world, A.bevel_box(Vector3(0.9, 0.07, 0.6), 0.02), A.paint(Color(0.42, 0.34, 0.24), 0.1, 0.85, {"wear": 0.7, "dust": 0.6}), p + Vector3(0, 0.72, 0))
				for sx in [-0.36, 0.36]:
					for sz in [-0.22, 0.22]:
						A.add(raid.world, A.cyl(0.03, 0.7, 0.03, 5), A.metal(Color(0.4, 0.4, 0.38)), p + Vector3(sx, 0.35, sz), Vector3.ZERO, Vector3.ONE, false)
				A.add(raid.world, A.bevel_box(Vector3(0.6, 0.5, 0.05), 0.01), A.paint(Color(0.3, 0.34, 0.3), 0.1, 0.8), p + Vector3(0, 0.95, 0.34))
	A.add(raid.world, A.bevel_box(Vector3(0.5, 1.2, 0.1), 0.02), A.paint(Color(0.1, 0.13, 0.11), 0.1, 0.9), c + Vector3(6.6, 1.6, -1.5))
	# 操场：白线、旗杆、篮球架
	for i in 4:
		A.add(raid.world, A.bevel_box(Vector3(9.0, 0.02, 0.12), 0.004), A.paint(Color(0.62, 0.62, 0.56), 0.0, 0.9, {"wear": 0.8}), c + Vector3(-1.0, 0.16, -1.0 + i * 2.4), Vector3.ZERO, Vector3.ONE, false)
	for i in 2:
		A.add(raid.world, A.bevel_box(Vector3(0.12, 0.02, 7.4), 0.004), A.paint(Color(0.62, 0.62, 0.56), 0.0, 0.9, {"wear": 0.8}), c + Vector3(-5.4 + i * 9.0, 0.16, 1.6), Vector3.ZERO, Vector3.ONE, false)
	A.add(raid.world, A.cyl(0.09, 11.0, 0.09, 8), A.metal(Color(0.55, 0.56, 0.54)), c + Vector3(-1.0, 5.5, -2.2))
	A.add(raid.world, A.bevel_box(Vector3(1.5, 0.9, 0.04), 0.01), A.paint(Color(0.55, 0.2, 0.18), 0.1, 0.85), c + Vector3(-0.25, 9.6, -2.2), Vector3(0, 0, -6))
	raid.blocks.append(raid._rect_for(c + Vector3(-1.0, 0, -2.2), Vector3(0.6, 1, 0.6)))
	var hoop := c + Vector3(8.4, 0, -3.4)
	A.add(raid.world, A.cyl(0.1, 3.2, 0.1, 8), A.metal(Color(0.4, 0.4, 0.38)), hoop + Vector3(0, 1.6, 0), Vector3(0, 0, -8))
	A.add(raid.world, A.bevel_box(Vector3(1.1, 0.7, 0.6), 0.03), A.paint(Color(0.55, 0.53, 0.46), 0.2, 0.7), hoop + Vector3(0.3, 3.1, 0), Vector3(0, 0, -8))
	A.add(raid.world, A.torus(0.28, 0.34, 12), A.metal(Color(0.6, 0.28, 0.15)), hoop + Vector3(0.55, 2.75, 0))
	# 秋千架
	var sw := c + Vector3(-12.0, 0, -6.4)
	for sx in [-2.0, 2.0]:
		A.add(raid.world, A.cyl(0.07, 3.0, 0.07, 6), A.metal(Color(0.36, 0.37, 0.35)), sw + Vector3(sx, 1.5, 0), Vector3(0, 0, sx * 2.5))
	A.add(raid.world, A.cyl(0.07, 4.2, 0.07, 6), A.metal(Color(0.36, 0.37, 0.35)), sw + Vector3(0, 2.9, 0), Vector3(0, 0, 90))
	for sx in [-1.0, 0.6]:
		A.add(raid.world, A.bevel_box(Vector3(0.5, 0.06, 0.3), 0.01), A.paint(Color(0.4, 0.32, 0.22), 0.1, 0.85), sw + Vector3(sx, 1.4, 0))
	raid.blocks.append(raid._rect_for(sw, Vector3(4.6, 1, 0.8)))
	# 体育馆：南面塌顶的大厅
	var gym := c + Vector3(2.0, 0, 9.4)
	K.wall_line(raid, gym + Vector3(-6.0, 0, -2.0), 12.0, 3.2, 0.0, [[-5.0, 5.0]], Color(0.5, 0.48, 0.43))
	K.wall_line(raid, gym + Vector3(0, 0, 3.2), 12.0, 2.6, 0.0, [[0.2, 4.8]], Color(0.5, 0.48, 0.43))
	for k in 3:
		A.add(raid.world, A.tube([gym + Vector3(-6.0, 0, -2.0), gym + Vector3(-6.0, 4.6, 0.6), gym + Vector3(-6.0, 0, 3.2)], 0.14, 5, 4), A.metal(Color(0.35, 0.34, 0.31)), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	for k in 3:
		A.add(raid.world, A.tube([gym + Vector3(-5.0 + k * 4.0, 4.4, -2.0), gym + Vector3(-3.6 + k * 4.2, 0.3, 2.0)], 0.12, 5, 4), A.paint(Color(0.4, 0.32, 0.22), 0.2, 0.8), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	for i in 3:
		A.add(raid.world, A.bevel_box(Vector3(3.0, 0.45, 0.9), 0.05), A.paint(Color(0.38, 0.32, 0.24), 0.1, 0.85, {"wear": 0.6, "dust": 0.6}), gym + Vector3(-4.0 + i * 4.0, 0.45, 1.6 + i * 0.5), Vector3(0, r.randf_range(-20, 20), 0))
	# 散落书包与篮球
	for i in 6:
		var p = c + Vector3(r.randf_range(-11, 11), 0.2, r.randf_range(-2, 8))
		A.add(raid.world, A.bevel_box(Vector3(0.45, 0.32, 0.24), 0.06), A.paint(Color(0.3, 0.32, 0.36), 0.1, 0.9, {"wear": 0.5, "dust": 0.7}), p, Vector3(0, r.randf() * 180, 0))
	for i in 3:
		A.add(raid.world, A.sphere(0.16, -1, 10), A.paint(Color(0.5, 0.28, 0.14), 0.0, 0.8, {"wear": 0.5}), c + Vector3(r.randf_range(-8, 8), 0.16, r.randf_range(0, 6)), Vector3.ZERO, Vector3.ONE, false)
	# 容器与环境叙事
	K.crate(raid, c + Vector3(10.8, 0, 3.0), "safe")
	K.crate(raid, c + Vector3(3.6, 0, 4.0), "supply")
	K.crate(raid, c + Vector3(-9.6, 0, 4.0), "supply")
	K.crate(raid, c + Vector3(-10.4, 0, -1.0), "tool")
	K.crate(raid, c + Vector3(2.0, 0, 7.0), "tool")
	K.fixed(raid, c + Vector3(-8.2, 0, 0.4), ["arch_child_drawing"], "tool")
	K.lamp(raid, c + Vector3(-13.0, 0, 8.4), Color(1.0, 0.8, 0.5))
	K.lamp(raid, c + Vector3(12.0, 0, -5.0), Color(0.7, 0.85, 1.0))
	K.rubble(raid, c + Vector3(4.0, 0, -5.6), 1.5)
	K.rubble(raid, c + Vector3(-6.0, 0, 9.0), 1.8)
	K.guard(raid, c + Vector3(-1.0, 0, 2.0), "spitter", 3.0)
	K.guard(raid, c + Vector3(7.0, 0, 2.0), "ling", 2.2)
	K.guard(raid, c + Vector3(-7.0, 0, 3.0), "ling", 2.2)
	K.guard(raid, c + Vector3(2.0, 0, 8.0), "ling", 2.2)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 8.5)
	K.tag_boxes(raid, c, pid)
