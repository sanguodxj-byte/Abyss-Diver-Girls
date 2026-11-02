extends RefCounted
## 北区发电站：西侧是拱顶汽轮机房，东侧两座冷却塔冒着白汽，南面是变压器场与格构电塔，
## 电塔之间拉着下垂的母线，地面铺着碎石与电缆沟盖板。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/map_ext/poi_kit.gd")

const WALL := Color(0.44, 0.44, 0.41)
const FLOOR := Color(0.4, 0.39, 0.36)


static func build(raid, c: Vector3, pid: String) -> void:
	var r = raid.rng
	K.slab(raid, c, Vector2(28, 24), FLOOR)
	# 汽轮机房：实心厂房 + 压扁的半圆拱顶 + 墙肋
	var hall := K.wall(raid, c + Vector3(-4.5, 0, -7.2), Vector3(15.0, 7.2, 9.0), 0.0, WALL)
	A.add(hall, A.cyl(3.2, 15.6, 3.2, 20), A.paint(WALL.darkened(0.14), 0.5, 0.55, {"wear": 0.4, "rust": 0.8, "dust": 0.5, "panel_scale": 1.2}),
		Vector3(0, 3.6, 0), Vector3(0, 0, 90), Vector3.ONE)
	for i in 6:
		A.add(hall, A.bevel_box(Vector3(0.2, 7.2, 0.14), 0.02), A.metal(Color(0.28, 0.28, 0.26)), Vector3(-7.0 + i * 2.8, 0, 4.55), Vector3.ZERO, Vector3.ONE, false)
	A.add(hall, A.bevel_box(Vector3(4.0, 4.2, 0.14), 0.02), A.metal(Color(0.22, 0.22, 0.21)), Vector3(2.0, -1.5, 4.55), Vector3.ZERO, Vector3.ONE, false)
	A.stencil(hall, "TURBINE HALL 2", Vector3(-4.0, 1.4, 4.56), Vector3.ZERO, 0.02, Color(0.8, 0.78, 0.7, 0.55), 44)
	# 两座冷却塔：上窄下宽的剪影 + 顶部白汽
	for p in [Vector3(9.0, 0, -3.0), Vector3(9.4, 0, 8.0)]:
		K.tower(raid, c + p, 4.6, 13.0, 3.2, Color(0.43, 0.42, 0.4))
		A.add(raid.world, A.cyl(3.0, 0.2, 3.0, 22), A.paint(Color(0.06, 0.06, 0.06), 0.1, 0.9), c + p + Vector3(0, 13.0, 0), Vector3.ZERO, Vector3.ONE, false)
		A.emitter(raid.world, c + p + Vector3(0, 13.4, 0), {"amount": 26, "life": 6.5, "size": 5.0, "tex": A.smoke_tex(), "additive": false, "spread": 22.0,
			"vmin": 1.2, "vmax": 2.4, "gravity": Vector3(0.4, 0.9, 0.2), "c0": Color(0.78, 0.77, 0.73, 0.35), "c1": Color(0.6, 0.6, 0.58, 0.0), "grow0": 0.6, "grow1": 3.4})
	# 冷却水渠：两条深色沟槽与盖板
	for i in 2:
		var z := -0.6 + i * 1.8
		A.add(raid.world, A.bevel_box(Vector3(9.0, 0.18, 0.9), 0.03), A.concrete(Color(0.18, 0.19, 0.2), false), c + Vector3(4.0, 0.09, z), Vector3.ZERO, Vector3.ONE, false)
		for k in 4:
			A.add(raid.world, A.bevel_box(Vector3(0.7, 0.06, 1.0), 0.01), A.concrete(Color(0.34, 0.33, 0.31), false), c + Vector3(-0.4 + k * 2.2, 0.2, z), Vector3.ZERO, Vector3.ONE, false)
	# 变压器场：两台箱式变压器 + 瓷瓶 + 围栏
	for i in 2:
		var p := c + Vector3(-11.5 + i * 4.2, 0, 5.0)
		var tb := A.add(raid.world, A.bevel_box(Vector3(2.6, 2.4, 2.0), 0.08), A.paint(Color(0.36, 0.38, 0.34), 0.45, 0.55, {"wear": 0.5, "rust": 0.7, "dust": 0.5}), p + Vector3(0, 1.2, 0))
		A.add(tb, A.bevel_box(Vector3(2.2, 0.2, 1.8), 0.03), A.metal(Color(0.24, 0.24, 0.23)), Vector3(0, 1.25, 0))
		for k in 3:
			A.add(tb, A.cyl(0.1, 0.7, 0.1, 8), A.paint(Color(0.7, 0.68, 0.6), 0.0, 0.5), Vector3(-0.7 + k * 0.7, 1.6, 0))
		raid.blocks.append(raid._rect_for(p, Vector3(3.0, 1, 2.4)))
		K.blocker(raid, p, Vector3(2.6, 2.4, 2.0))
	# 格构电塔：四根脚 + 交叉斜撑 + 横担
	for i in 2:
		var p := c + Vector3(-9.0 + i * 8.0, 0, 9.6)
		K.lattice(raid, p, 11.0, 1.9)
	K.cable(raid, c + Vector3(-9.0, 10.2, 9.6), c + Vector3(-1.0, 10.2, 9.6), 1.4, 0.05)
	K.cable(raid, c + Vector3(-1.0, 10.2, 9.6), c + Vector3(7.0, 10.2, 9.6), 1.4, 0.05)
	K.cable(raid, c + Vector3(-9.0, 9.4, 9.6), c + Vector3(-1.0, 9.4, 9.6), 1.2, 0.04)
	# 控制室：一间矮墙小屋，门朝东，里面一排机柜
	K.wall_line(raid, c + Vector3(1.0, 0, 3.0), 6.0, 3.0, 0.0, [[-0.6, 1.2]], WALL.darkened(0.08))
	K.wall_line(raid, c + Vector3(-2.0, 0, 5.6), 5.2, 3.0, 90.0, [], WALL.darkened(0.08))
	K.wall_line(raid, c + Vector3(4.0, 0, 5.6), 5.2, 3.0, 90.0, [[0.4, 2.2]], WALL.darkened(0.08))
	for i in 3:
		A.add(raid.world, A.bevel_box(Vector3(0.9, 2.0, 0.7), 0.03), A.paint(Color(0.3, 0.34, 0.33), 0.4, 0.5, {"wear": 0.4, "rust": 0.4, "panel_scale": 0.5}), c + Vector3(0.0 + i * 1.3, 1.0, 4.2))
	for i in 2:
		A.add(raid.world, A.bevel_box(Vector3(0.4, 0.3, 0.05), 0.01), A.emit(Color(0.3, 0.8, 0.6), 0.9), c + Vector3(0.1 + i * 1.3, 1.4, 4.56), Vector3(0, 180, 0), Vector3.ONE, false)
	K.desk(raid, c + Vector3(1.2, 0, 7.0), 180.0, 2.2, Color(0.3, 0.31, 0.28))
	# 散落器材与电缆盘
	for p in [Vector3(-1.2, 0, 2.4), Vector3(3.2, 0, 6.0)]:
		A.add(raid.world, A.cyl(0.9, 0.7, 0.9, 16), A.paint(Color(0.3, 0.25, 0.18), 0.3, 0.8, {"rust": 0.7, "wear": 0.5}), c + p + Vector3(0, 0.35, 0))
	A.add(raid.world, A.bevel_box(Vector3(3.0, 0.12, 1.0), 0.02), A.metal(Color(0.26, 0.26, 0.25)), c + Vector3(0.6, 0.06, -2.0), Vector3(0, 18, 0))
	# 容器与环境叙事
	K.crate(raid, c + Vector3(-14.2, 0, -1.6), "tool")
	K.crate(raid, c + Vector3(-8.4, 0, 2.2), "tool")
	K.crate(raid, c + Vector3(-13.2, 0, 6.8), "military")
	K.crate(raid, c + Vector3(3.2, 0, 7.4), "safe")
	K.fixed(raid, c + Vector3(2.4, 0, 4.6), ["arch_blueprint", "circuit"], "tool")
	K.crate(raid, c + Vector3(7.5, 0, -12.0), "military")
	K.lamp(raid, c + Vector3(-14.0, 0, -9.4), Color(1.0, 0.76, 0.42))
	K.lamp(raid, c + Vector3(14.0, 0, 0.0), Color(0.72, 0.86, 1.0))
	K.rubble(raid, c + Vector3(1.2, 0, -10.4), 2.0)
	K.rubble(raid, c + Vector3(-6.0, 0, 10.8), 1.5, Color(0.3, 0.29, 0.27))
	K.guard(raid, c + Vector3(-4.0, 0, 1.0), "beetle", 3.0)
	K.guard(raid, c + Vector3(6.0, 0, 3.0), "beetle", 3.0)
	K.guard(raid, c + Vector3(10.0, 0, -6.0), "spitter", 2.2)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 9.0)
	K.tag_boxes(raid, c, pid)

