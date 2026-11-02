extends RefCounted
## 七号检查站：一条横穿院子的柏油路，两端各一座哨亭，中间横着断掉的升降杆与检查雨棚，
## 路口堆着防爆沙袋和混凝土隔离墩，东侧高脚哨塔上挂着探照灯。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/map_ext/poi_kit.gd")

const ASPHALT := Color(0.22, 0.22, 0.21)
const BOOTH := Color(0.5, 0.5, 0.46)


static func build(raid, c: Vector3, pid: String) -> void:
	var r = raid.rng
	K.slab(raid, c, Vector2(28, 14), Color(0.32, 0.31, 0.29))
	A.add(raid.world, A.bevel_box(Vector3(28.0, 0.14, 10.0), 0.04), A.concrete(ASPHALT, false), c + Vector3(0, 0.07, 0.0), Vector3.ZERO, Vector3.ONE, false)
	# 中线与斑马线
	for i in 9:
		A.add(raid.world, A.bevel_box(Vector3(1.4, 0.02, 0.16), 0.005), A.paint(Color(0.62, 0.6, 0.5), 0.0, 0.9, {"wear": 0.8, "dust": 0.6}), c + Vector3(-12.0 + i * 3.0, 0.15, 0.0), Vector3.ZERO, Vector3.ONE, false)
	for i in 6:
		A.add(raid.world, A.bevel_box(Vector3(0.6, 0.02, 3.4), 0.005), A.paint(Color(0.6, 0.58, 0.5), 0.0, 0.9, {"wear": 0.8}), c + Vector3(-3.0 + i * 1.2, 0.15, 3.2), Vector3.ZERO, Vector3.ONE, false)
	# 两座哨亭：三面墙 + 柜台 + 窗
	for sx in [-1.0, 1.0]:
		var bp := c + Vector3(sx * 6.4, 0, -4.8)
		K.wall(raid, bp + Vector3(0, 0, -1.5), Vector3(3.4, 2.9, 0.4), 0.0, BOOTH)
		K.wall(raid, bp + Vector3(-1.6, 0, 0), Vector3(0.4, 2.9, 2.6), 0.0, BOOTH)
		K.wall(raid, bp + Vector3(1.6, 0, 0), Vector3(0.4, 2.9, 2.6), 0.0, BOOTH)
		A.add(raid.world, A.bevel_box(Vector3(3.9, 0.24, 3.4), 0.05), A.concrete(BOOTH.darkened(0.16), false), bp + Vector3(0, 3.0, 0), Vector3.ZERO, Vector3.ONE, false)
		A.add(raid.world, A.bevel_box(Vector3(2.6, 1.0, 0.08), 0.01), A.glass(Color(0.3, 0.42, 0.45)), bp + Vector3(0, 1.9, 1.62), Vector3.ZERO, Vector3.ONE, false)
		K.desk(raid, bp + Vector3(0.2, 0, 0.4), 0.0, 2.0, Color(0.34, 0.31, 0.24))
		A.add(raid.world, A.cyl(0.06, 1.0, 0.06, 6), A.metal(Color(0.5, 0.5, 0.48)), bp + Vector3(-1.1, 1.5, -1.2))
		A.add(raid.world, A.sphere(0.22, -1, 12), A.emit(Color(0.95, 0.72, 0.4), 1.4), bp + Vector3(-1.1, 2.0, -1.2), Vector3.ZERO, Vector3.ONE, false)
	# 升降杆：东侧横着，西侧被撞断倒在地上
	var arm := A.add(raid.world, A.bevel_box(Vector3(5.2, 0.16, 0.16), 0.02), A.hazard(), c + Vector3(2.6, 1.1, 1.2))
	A.add(raid.world, A.bevel_box(Vector3(0.28, 1.3, 0.28), 0.03), A.paint(Color(0.55, 0.45, 0.2), 0.3, 0.6), c + Vector3(0.0, 0.65, 1.2))
	arm.rotation_degrees = Vector3(0, 0, 0)
	A.add(raid.world, A.bevel_box(Vector3(4.6, 0.16, 0.16), 0.02), A.hazard(), c + Vector3(-4.6, 0.22, 2.6), Vector3(0, -24, 4))
	# 检查雨棚
	K.canopy(raid, c + Vector3(0, 0, -1.8), Vector2(10.0, 5.0), 4.0, 0.0, Color(0.4, 0.4, 0.37))
	A.add(raid.world, A.bevel_box(Vector3(10.4, 0.3, 5.4), 0.05), A.paint(Color(0.34, 0.34, 0.31), 0.5, 0.6, {"wear": 0.5, "rust": 0.6, "panel_scale": 1.4}), c + Vector3(0, 4.16, -1.8), Vector3.ZERO, Vector3.ONE, false)
	for sz in [-1.0, 1.0]:
		A.add(raid.world, A.bevel_box(Vector3(10.4, 0.34, 0.36), 0.02), A.hazard(), c + Vector3(0, 4.18, -1.8 + sz * 2.52), Vector3.ZERO, Vector3.ONE, false)
	# 沙袋工事与隔离墩
	for p in [Vector3(-9.2, 0, 4.2), Vector3(8.8, 0, 3.6)]:
		_sandbags(raid, c + p, r.randf_range(-18, 18))
	for i in 5:
		var p := c + Vector3(-8.0 + i * 4.2, 0, 6.6)
		var jb = A.add(raid.world, A.bevel_box(Vector3(3.0, 1.0, 0.7), 0.16, 0.86), A.concrete(Color(0.55, 0.54, 0.5), false), p + Vector3(0, 0.5, 0), Vector3(0, r.randf_range(-6, 6), 0))
		A.add(jb, A.bevel_box(Vector3(2.4, 0.18, 0.1), 0.01), A.hazard(), Vector3(0, 0.32, 0.36), Vector3.ZERO, Vector3.ONE, false)
		raid.blocks.append(raid._rect_for(p, Vector3(3.2, 1, 1.0)))
	# 高脚哨塔 + 探照灯
	var wc: int = raid.world.get_child_count()
	raid._watchtower(c + Vector3(10.4, 0, -7.6))
	if raid.world.get_child_count() > wc:
		var tw = raid.world.get_child(wc)
		if tw is StaticBody3D:
			tw.set_meta("poi_built", true)
	var sl := OmniLight3D.new()
	sl.light_color = Color(1.0, 0.92, 0.75)
	sl.light_energy = 4.0
	sl.omni_range = 26.0
	sl.position = c + Vector3(9.6, 6.6, -6.6)
	raid.world.add_child(sl)
	raid._add_flicker(sl)
	A.add(raid.world, A.bevel_box(Vector3(0.5, 0.4, 0.8), 0.06), A.paint(Color(0.25, 0.26, 0.25), 0.5, 0.5), c + Vector3(9.6, 6.4, -6.6))
	A.add(raid.world, A.bevel_box(Vector3(0.42, 0.3, 0.06), 0.01), A.emit(Color(1.0, 0.95, 0.8), 3.0), c + Vector3(9.6, 6.4, -6.18), Vector3.ZERO, Vector3.ONE, false)
	# 灯杆、告示牌
	K.lamp(raid, c + Vector3(-13.4, 0, -8.2), Color(1.0, 0.78, 0.45))
	K.lamp(raid, c + Vector3(13.4, 0, 7.0), Color(0.7, 0.85, 1.0))
	K.sign(raid, c + Vector3(-11.4, 2.0, -2.0), 90.0, "CHECKPOINT 07", 3.4, 1.0)
	# 废弃车辆与路障残骸
	raid._wreck_car(c + Vector3(-1.6, 0, 8.2))
	raid.blocks.append(raid._rect_for(c + Vector3(-1.6, 0, 8.2), Vector3(3.0, 1, 3.0)))
	A.add(raid.world, A.cyl(0.45, 0.7, 0.5, 10), A.paint(Color(0.55, 0.32, 0.12), 0.3, 0.7, {"rust": 0.7}), c + Vector3(4.6, 0.35, 7.4))
	# 容器与环境叙事
	K.crate(raid, c + Vector3(-6.2, 0, -4.4), "safe")
	K.crate(raid, c + Vector3(-4.2, 0, -1.2), "military")
	K.crate(raid, c + Vector3(3.4, 0, -0.6), "military")
	K.crate(raid, c + Vector3(6.6, 0, -5.6), "tool")
	K.fixed(raid, c + Vector3(5.8, 0, -3.9), ["arch_manifest", "credit_s"], "tool")
	K.crate(raid, c + Vector3(11.8, 0, 4.6), "supply")
	K.rubble(raid, c + Vector3(-2.0, 0, -8.6), 1.4)
	K.guard(raid, c + Vector3(0.0, 0, 1.6), "beetle", 3.0)
	K.guard(raid, c + Vector3(-8.0, 0, -1.0), "ling", 2.4)
	K.guard(raid, c + Vector3(9.0, 0, 0.6), "ling", 2.4)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 7.5)
	K.tag_boxes(raid, c, pid)


## 沙袋工事：三层错缝的袋堆，挡住机甲，袋墙高度低于肩部
static func _sandbags(raid, p: Vector3, rot: float) -> void:
	var M := A.paint(Color(0.48, 0.44, 0.32), 0.0, 1.0, {"panel_scale": 0.0, "dust": 0.65, "wear": 0.3})
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	for row in 3:
		for k in 5:
			A.add(n, A.bevel_box(Vector3(0.82, 0.36, 0.54), 0.14), M, Vector3(-1.64 + k * 0.82 + (0.41 if row % 2 else 0.0), 0.18 + row * 0.34, raid.rng.randf_range(-0.06, 0.06)), Vector3(0, raid.rng.randf_range(-7, 7), 0))
	raid.blocks.append(raid._rect_for(p, Vector3(4.2, 1, 1.4)))
	K.blocker(raid, p, Vector3(4.2, 1.05, 1.4), rot)
