extends RefCounted
## 东区停车楼：三层开敞式停车楼，楼板只在北侧与东侧成 L 形铺开，西南角整片塌空露出底层；
## 柱网、坡道、护墙与层层叠叠的报废车构成很硬的城市剪影。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/map_ext/poi_kit.gd")

const CONCRETE := Color(0.52, 0.51, 0.47)


static func build(raid, c: Vector3, pid: String) -> void:
	var r = raid.rng
	K.slab(raid, c, Vector2(24, 20), Color(0.4, 0.39, 0.37))
	# 楼板：北条 + 东条（只在 3.4 与 6.8 米两层，网格本身无碰撞，柱子挡子弹）
	for lv in [3.4, 6.8]:
		A.add(raid.world, A.bevel_box(Vector3(23.0, 0.3, 7.0), 0.06), A.concrete(CONCRETE, true), c + Vector3(0, lv, -5.0))
		A.add(raid.world, A.bevel_box(Vector3(7.0, 0.3, 7.0), 0.06), A.concrete(CONCRETE, true), c + Vector3(8.0, lv, -5.0))
		# 护墙
		for seg in [[Vector3(0, 0.55, -8.4), Vector3(23.0, 1.1, 0.3)], [Vector3(11.4, 0.55, -5.0), Vector3(0.3, 1.1, 7.0)]]:
			A.add(raid.world, A.bevel_box(seg[1], 0.04), A.concrete(CONCRETE.darkened(0.12), false), c + seg[0] + Vector3(0, lv, 0))
	# 顶层车位线与通风机组
	for k in 7:
		A.add(raid.world, A.bevel_box(Vector3(0.12, 0.02, 5.2), 0.004), A.paint(Color(0.62, 0.6, 0.53), 0.0, 0.9, {"wear": 0.8, "dust": 0.5}), c + Vector3(-9.0 + k * 3.0, 6.97, -5.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(raid.world, A.bevel_box(Vector3(2.4, 1.4, 1.8), 0.06), A.paint(Color(0.46, 0.47, 0.44), 0.45, 0.6, {"wear": 0.5, "rust": 0.6, "panel_scale": 0.8}), c + Vector3(8.4, 7.6, -6.8))
	A.add(raid.world, A.cyl(0.5, 0.06, 0.5, 14), A.metal(Color(0.22, 0.22, 0.21)), c + Vector3(8.4, 8.34, -6.8), Vector3.ZERO, Vector3.ONE, false)
	A.add(raid.world, A.bevel_box(Vector3(3.0, 2.6, 3.6), 0.08), A.paint(Color(0.5, 0.49, 0.45), 0.3, 0.6, {"wear": 0.5, "rust": 0.5}), c + Vector3(-9.0, 8.1, -5.0))
	# 柱网：只保留能站人的底层碰撞
	for gx in [-9.0, -4.5, 0.0, 4.5, 9.0]:
		for gz in [-8.0, -3.0, 2.0, 7.0]:
			if gz > 0.0 and gx < 4.0:
				continue
			K.pillar(raid, c + Vector3(gx, 0, gz), 0.55, 7.2, CONCRETE.darkened(0.06))
	# 坡道：从西南地面盘上北侧二层
	A.add(raid.world, A.bevel_box(Vector3(5.0, 0.28, 13.0), 0.05), A.concrete(CONCRETE, true), c + Vector3(-9.4, 1.8, 2.4), Vector3(16, 0, 0))
	A.add(raid.world, A.bevel_box(Vector3(5.2, 0.5, 0.24), 0.03), A.concrete(CONCRETE.darkened(0.15), false), c + Vector3(-9.4, 2.6, -3.6), Vector3(16, 0, 0))
	# 底层：报废车、油渍、被撬开的后备箱
	for p in [Vector3(-5.6, 0, 5.4), Vector3(-2.0, 0, 7.0), Vector3(4.6, 0, 6.2), Vector3(9.6, 0, 4.6)]:
		raid._wreck_car(c + p)
		raid.blocks.append(raid._rect_for(c + p, Vector3(3.0, 1, 3.0)))
	for i in 5:
		A.ground_decal(raid.world, A.cloud_tex(), Color(0.05, 0.05, 0.05, 0.55), r.randf_range(2.0, 4.2), c + Vector3(r.randf_range(-9, 9), 0.02, r.randf_range(-6, 8)))
	# 一辆被掀开后备箱的车，箱子旁边散着工具
	var trunk := c + Vector3(1.0, 0, 5.0)
	A.add(raid.world, A.bevel_box(Vector3(1.8, 0.9, 2.4), 0.06, 0.9), A.paint(Color(0.32, 0.28, 0.24), 0.4, 0.6, {"wear": 0.7, "rust": 0.8}), trunk + Vector3(0, 0.55, 0))
	A.add(raid.world, A.bevel_box(Vector3(1.5, 0.12, 1.2), 0.02), A.paint(Color(0.2, 0.19, 0.18), 0.3, 0.7), trunk + Vector3(0, 1.34, 1.4), Vector3(-58, 0, 0))
	raid.blocks.append(raid._rect_for(trunk, Vector3(2.4, 1, 3.0)))
	# 二层上的烧毁车与掉落的楼板碎块
	for p in [Vector3(-4.0, 3.55, -6.0), Vector3(3.6, 3.55, -4.6), Vector3(8.4, 3.55, 2.0)]:
		A.add(raid.world, A.bevel_box(Vector3(1.8, 0.8, 3.6), 0.08, 0.9), A.paint(Color(0.14, 0.13, 0.12), 0.3, 0.8, {"wear": 0.9, "rust": 0.9}), c + p, Vector3(r.randf_range(-8, 8), r.randf_range(-40, 40), 0))
	for i in 4:
		A.add(raid.world, A.bevel_box(Vector3(r.randf_range(0.8, 2.4), 0.4, r.randf_range(0.8, 2.0)), 0.05), A.concrete(CONCRETE.darkened(0.2), false), c + Vector3(r.randf_range(-10, 10), 0.2, r.randf_range(0, 8)), Vector3(r.randf_range(-20, 20), r.randf_range(0, 360), r.randf_range(-20, 20)))
	# 楼梯核心筒：小房间，门朝西
	K.wall_line(raid, c + Vector3(6.4, 0, -1.0), 5.0, 3.2, 0.0, [[-1.0, 1.0]], CONCRETE.darkened(0.1))
	K.wall_line(raid, c + Vector3(4.0, 0, 1.2), 4.4, 3.2, 90.0, [], CONCRETE.darkened(0.1))
	K.wall_line(raid, c + Vector3(8.8, 0, 1.2), 4.4, 3.2, 90.0, [[0.2, 1.8]], CONCRETE.darkened(0.1))
	K.steps(raid, c + Vector3(6.4, 0, 1.6), 8, 0.24, 0.34, 2.2, 0.0)
	# 缴费亭与限高杆
	A.add(raid.world, A.bevel_box(Vector3(3.0, 2.6, 2.4), 0.06), A.paint(Color(0.45, 0.42, 0.34), 0.2, 0.7, {"wear": 0.6, "rust": 0.5}), c + Vector3(-7.0, 1.3, -8.4))
	A.add(raid.world, A.bevel_box(Vector3(2.0, 1.0, 0.1), 0.01), A.glass(Color(0.3, 0.45, 0.45)), c + Vector3(-7.0, 1.9, -7.18))
	raid.blocks.append(raid._rect_for(c + Vector3(-7.0, 0, -8.4), Vector3(3.4, 1, 2.8)))
	K.blocker(raid, c + Vector3(-7.0, 0, -8.4), Vector3(3.0, 2.6, 2.4))
	A.add(raid.world, A.bevel_box(Vector3(8.0, 0.18, 0.18), 0.02), A.hazard(), c + Vector3(-2.6, 2.4, -8.4))
	for sx in [-6.6, 1.4]:
		A.add(raid.world, A.cyl(0.09, 2.4, 0.09, 6), A.metal(Color(0.35, 0.35, 0.34)), c + Vector3(sx, 1.2, -8.4))
	# 容器与环境叙事
	K.crate(raid, c + Vector3(-1.0, 0, 8.0), "military")
	K.crate(raid, c + Vector3(2.8, 0, 8.2), "military")
	K.crate(raid, c + Vector3(-8.6, 0, 3.0), "tool")
	K.crate(raid, c + Vector3(7.4, 0, -1.0), "safe")
	K.fixed(raid, c + Vector3(-3.2, 0, 6.2), ["arch_tape"], "tool")
	K.crate(raid, c + Vector3(9.0, 0, 4.2), "supply")
	K.lamp(raid, c + Vector3(-11.4, 0, -6.6), Color(1.0, 0.78, 0.45))
	K.lamp(raid, c + Vector3(11.6, 0, 8.6), Color(0.75, 0.85, 1.0))
	K.rubble(raid, c + Vector3(-6.0, 0, -3.0), 2.0, CONCRETE.darkened(0.18))
	K.guard(raid, c + Vector3(1.0, 0, 4.0), "beetle", 3.0)
	K.guard(raid, c + Vector3(-6.0, 0, 6.0), "ling", 2.2)
	K.guard(raid, c + Vector3(6.0, 0, 4.0), "ling", 2.2)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 8.5)
	K.tag_boxes(raid, c, pid)
