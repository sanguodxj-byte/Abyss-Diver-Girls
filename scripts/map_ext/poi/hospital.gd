extends RefCounted
## 城南医院：北面是塌了半边的门诊楼，门口悬着褪色的红十字；东翼是敞开的留观病房（病床、药柜），
## 西翼是发电机棚，院子中央支着三防帐篷与几张担架床，救护车横在雨棚下。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/map_ext/poi_kit.gd")

const WALL := Color(0.6, 0.58, 0.53)
const FLOOR := Color(0.56, 0.55, 0.5)


static func build(raid, c: Vector3, pid: String) -> void:
	var r = raid.rng
	K.slab(raid, c, Vector2(26, 22), FLOOR)
	# 门诊楼：实心楼体 + 破损门厅
	K.wall(raid, c + Vector3(0, 0, -8.4), Vector3(13.0, 7.0, 7.0), 0.0, WALL)
	for k in 4:
		var ch = Vector3(r.randf_range(1.0, 2.6), r.randf_range(0.4, 1.2), 0.7)
		A.add(raid.world, A.bevel_box(ch, 0.08), A.concrete(WALL.darkened(0.18)), c + Vector3(r.randf_range(-5.8, 5.8), 7.0 + ch.y * 0.4, -5.2))
	# 窗：两层带钢窗框与十字棂条的深色玻璃窗 + 红十字背板框
	var M_DARK := A.metal(Color(0.18, 0.19, 0.20))
	for y in [2.2, 4.6]:
		for x in [-4.4, -1.5, 1.5, 4.4]:
			A.add(raid.world, A.bevel_box(Vector3(1.72, 1.22, 0.10), 0.02), M_DARK, c + Vector3(x, y, -4.86), Vector3.ZERO, Vector3.ONE, false)
			A.add(raid.world, A.bevel_box(Vector3(1.56, 1.06, 0.12), 0.01), A.paint(Color(0.06, 0.08, 0.09), 0.3, 0.28), c + Vector3(x, y, -4.84), Vector3.ZERO, Vector3.ONE, false)
			A.add(raid.world, A.bevel_box(Vector3(0.05, 1.08, 0.14), 0.005), M_DARK, c + Vector3(x, y, -4.83), Vector3.ZERO, Vector3.ONE, false)
	# 门厅雨棚
	K.canopy(raid, c + Vector3(0, 0, -3.4), Vector2(9.0, 4.2), 3.6, 0.0, Color(0.5, 0.48, 0.45))
	A.add(raid.world, A.bevel_box(Vector3(2.6, 2.8, 0.16), 0.03), A.paint(Color(0.08, 0.1, 0.1), 0.3, 0.4), c + Vector3(0, 1.4, -4.82))
	# 红十字：钢框背板 + 两根发光板
	A.add(raid.world, A.bevel_box(Vector3(2.8, 2.8, 0.10), 0.03), M_DARK, c + Vector3(0, 5.4, -4.86))
	var RED := A.emit(Color(0.85, 0.12, 0.1), 1.2)
	A.add(raid.world, A.bevel_box(Vector3(0.7, 2.4, 0.14), 0.02), RED, c + Vector3(0, 5.4, -4.8), Vector3.ZERO, Vector3.ONE, false)
	A.add(raid.world, A.bevel_box(Vector3(2.4, 0.7, 0.12), 0.02), RED, c + Vector3(0, 5.4, -4.8), Vector3.ZERO, Vector3.ONE, false)
	K.roof_kit(raid, c + Vector3(0, 0, -8.4), Vector2(13.0, 7.0), 7.0, WALL)
	# 东翼留观病房：三面墙，西侧向院子敞开（门洞 >= 3.8m 确保机甲自由进出）
	K.wall_line(raid, c + Vector3(8.6, 0, -3.2), 10.0, 3.6, 0.0, [[-4.8, -1.0]], WALL)
	K.wall_line(raid, c + Vector3(8.6, 0, 6.4), 10.0, 2.8, 0.0, [[0.6, 4.4]], WALL.darkened(0.12))
	K.wall_line(raid, c + Vector3(13.4, 0, 1.6), 9.6, 3.4, 90.0, [[-2.2, 1.6]], WALL)
	# 病床：床架 + 床头床尾钢管护栏 + 枕垫
	var M_BED_F := A.metal(Color(0.45, 0.46, 0.44))
	for i in 3:
		var p := c + Vector3(6.2, 0, -1.4 + i * 2.6)
		A.add(raid.world, A.bevel_box(Vector3(1.1, 0.16, 2.2), 0.03), A.paint(Color(0.62, 0.63, 0.6), 0.1, 0.7, {"wear": 0.5, "dust": 0.6}), p + Vector3(0, 0.62, 0))
		for sz in [-1.06, 1.06]:
			A.add(raid.world, A.bevel_box(Vector3(1.06, 0.05, 0.05), 0.01), M_BED_F, p + Vector3(0, 1.02 if sz < 0.0 else 0.88, sz), Vector3.ZERO, Vector3.ONE, false)
			for sx in [-0.50, 0.50]:
				A.add(raid.world, A.cyl(0.04, 1.02 if sz < 0.0 else 0.88, 0.04, 6), M_BED_F, p + Vector3(sx, 0.51 if sz < 0.0 else 0.44, sz), Vector3.ZERO, Vector3.ONE, false)
		A.add(raid.world, A.bevel_box(Vector3(1.02, 0.18, 0.55), 0.03), A.paint(Color(0.72, 0.72, 0.68), 0.0, 0.85, {"dust": 0.5}), p + Vector3(0, 0.76, -0.72))
		A.add(raid.world, A.bevel_box(Vector3(1.14, 0.14, 1.15), 0.02), A.paint(Color(0.32, 0.38, 0.36), 0.0, 0.9, {"wear": 0.6, "dust": 0.6}), p + Vector3(0, 0.74, 0.35))
		raid.blocks.append(raid._rect_for(p, Vector3(1.4, 1, 2.4)))
	K.shelf(raid, c + Vector3(12.2, 0, -1.8), 90.0, 2.2, 2.2)
	# 西翼发电机棚
	K.wall(raid, c + Vector3(-9.4, 0, 4.4), Vector3(6.2, 3.0, 5.0), 0.0, Color(0.44, 0.42, 0.38))
	A.add(raid.world, A.bevel_box(Vector3(1.6, 1.4, 2.4), 0.06), A.paint(Color(0.36, 0.38, 0.3), 0.4, 0.6, {"wear": 0.5, "rust": 0.8, "panel_scale": 0.0}), c + Vector3(-9.2, 0.7, 3.0))
	A.add(raid.world, A.cyl(0.35, 2.6, 0.35, 10), A.metal(Color(0.24, 0.24, 0.22)), c + Vector3(-9.2, 2.4, 3.0))
	for i in 3:
		A.add(raid.world, A.cyl(0.4, 1.2, 0.4, 12), A.paint(Color(0.35, 0.24, 0.14), 0.5, 0.6, {"rust": 0.9, "panel_scale": 0.0}), c + Vector3(-12.0 + i * 1.1, 0.6, 6.6))
	raid.blocks.append(raid._rect_for(c + Vector3(-12.0, 0, 6.6), Vector3(3.4, 1, 2.0)))
	# 军用三防医疗帐篷：双坡人字屋脊帆布 + 侧围布墙 + 钢支撑杆与拉绳（消除悬浮斜板）
	var TENT := A.paint(Color(0.38, 0.41, 0.32), 0.0, 0.92, {"wear": 0.5, "dust": 0.65, "panel_scale": 0.0})
	var tp_m := c + Vector3(2.4, 0, 5.4)
	A.add(raid.world, A.prism(PackedVector2Array([Vector2(-2.4, 0), Vector2(0, 1.05), Vector2(2.4, 0)]), 3.8, 0.04), TENT, tp_m + Vector3(0, 1.75, 0))
	A.add(raid.world, A.cyl(0.045, 3.95, 0.045, 8), M_BED_F, tp_m + Vector3(0, 2.78, 0), Vector3(90, 0, 0))
	for sx in [-1.0, 1.0]:
		A.add(raid.world, A.bevel_box(Vector3(0.06, 1.15, 3.65), 0.01), TENT, tp_m + Vector3(sx * 2.28, 1.22, 0))
		for sz in [-1.75, 0.0, 1.75]:
			A.add(raid.world, A.cyl(0.045, 1.82, 0.045, 8), M_DARK, tp_m + Vector3(sx * 2.28, 0.91, sz))
	# 担架床与输液架
	for p in [Vector3(-1.8, 0, 1.2), Vector3(-1.8, 0, 4.6), Vector3(1.4, 0, 8.2)]:
		A.add(raid.world, A.bevel_box(Vector3(0.9, 0.1, 2.0), 0.02), A.paint(Color(0.55, 0.56, 0.52), 0.1, 0.6, {"wear": 0.6, "dust": 0.6}), c + p + Vector3(0, 0.7, 0))
		for sz in [-0.8, 0.8]:
			A.add(raid.world, A.cyl(0.04, 0.7, 0.04, 5), A.metal(Color(0.5, 0.5, 0.48)), c + p + Vector3(0, 0.35, sz), Vector3.ZERO, Vector3.ONE, false)
	for p in [Vector3(0.6, 0, -0.6), Vector3(-3.2, 0, 7.4)]:
		A.add(raid.world, A.cyl(0.035, 1.9, 0.035, 5), A.metal(Color(0.55, 0.56, 0.54)), c + p + Vector3(0, 0.95, 0))
		A.add(raid.world, A.bevel_box(Vector3(0.22, 0.34, 0.08), 0.02), A.glass(Color(0.4, 0.7, 0.5)), c + p + Vector3(0.12, 1.72, 0), Vector3.ZERO, Vector3.ONE, false)
	# 重型方舱救护车：独立驾驶楼 + 医疗方舱 + 红十字腰线 + 对开后门 + 双联警示灯排（Node3D 容器）
	var AMB := A.paint(Color(0.68, 0.68, 0.64), 0.25, 0.58, {"wear": 0.55, "dust": 0.5, "rust": 0.35})
	var M_RED := A.paint(Color(0.58, 0.14, 0.12), 0.2, 0.6, {"wear": 0.5})
	var ab := Node3D.new()
	raid.world.add_child(ab)
	ab.position = c + Vector3(-5.4, 0, 0.4)
	ab.rotation_degrees = Vector3(0, 12, 0)
	A.add(ab, A.bevel_box(Vector3(2.05, 0.42, 4.75), 0.04), M_DARK, Vector3(0, 0.48, 0))
	A.add(ab, A.bevel_box(Vector3(1.96, 1.25, 1.55), 0.08, 0.86), AMB, Vector3(0, 1.18, -1.52))
	A.add(ab, A.bevel_box(Vector3(1.94, 0.38, 0.65), 0.06), AMB, Vector3(0, 0.88, -2.22), Vector3(12, 0, 0))
	A.add(ab, A.bevel_box(Vector3(1.74, 0.52, 0.10), 0.02), A.glass(Color(0.18, 0.30, 0.36)), Vector3(0, 1.36, -2.26), Vector3(14, 0, 0))
	A.add(ab, A.bevel_box(Vector3(2.22, 1.78, 3.18), 0.08, 0.94), AMB, Vector3(0, 1.48, 0.78))
	A.add(ab, A.bevel_box(Vector3(2.26, 0.22, 3.22), 0.02), M_RED, Vector3(0, 1.18, 0.78))
	for sx_a in [-1.13, 1.13]:
		A.add(ab, A.bevel_box(Vector3(0.04, 0.65, 0.18), 0.01), M_RED, Vector3(sx_a, 1.72, 0.78), Vector3.ZERO, Vector3.ONE, false)
		A.add(ab, A.bevel_box(Vector3(0.04, 0.18, 0.65), 0.01), M_RED, Vector3(sx_a, 1.72, 0.78), Vector3.ZERO, Vector3.ONE, false)
	A.add(ab, A.bevel_box(Vector3(0.05, 1.45, 0.06), 0.01), M_DARK, Vector3(0, 1.48, 2.38), Vector3.ZERO, Vector3.ONE, false)
	for dx_a in [-0.52, 0.52]:
		A.add(ab, A.bevel_box(Vector3(0.62, 0.48, 0.06), 0.01), A.glass(Color(0.18, 0.30, 0.36)), Vector3(dx_a, 1.75, 2.38), Vector3.ZERO, Vector3.ONE, false)
	for lx_a in [-0.55, 0.55]:
		A.add(ab, A.bevel_box(Vector3(0.56, 0.15, 0.26), 0.02), A.emit(Color(0.92, 0.18, 0.14), 1.6), Vector3(lx_a, 2.44, -0.58), Vector3.ZERO, Vector3.ONE, false)
	for wz in [-1.55, 1.45]:
		for wx in [-1.04, 1.04]:
			A.add(ab, A.cyl(0.42, 0.28, 0.42, 14), A.rubber(), Vector3(wx, 0.42, wz), Vector3(0, 0, 90))
			A.add(ab, A.cyl(0.22, 0.30, 0.22, 12), M_BED_F, Vector3(wx, 0.42, wz), Vector3(0, 0, 90), Vector3.ONE, false)
	raid.blocks.append(raid._rect_for(c + Vector3(-5.4, 0, 0.4), Vector3(3.2, 1, 5.2)))
	K.blocker(raid, c + Vector3(-5.4, 0, 0.4), Vector3(2.2, 1.9, 4.6), 12.0)
	# 分诊台与散落的病历车
	K.desk(raid, c + Vector3(3.0, 0, -3.2), 0.0, 3.0, Color(0.34, 0.3, 0.24))
	A.add(raid.world, A.bevel_box(Vector3(0.9, 1.1, 0.6), 0.04), A.paint(Color(0.5, 0.5, 0.47), 0.2, 0.7), c + Vector3(9.0, 0.55, -4.4), Vector3(0, 20, 0))
	# 血迹与倒塌的隔帘轨道
	for i in 3:
		A.ground_decal(raid.world, A.cloud_tex(), Color(0.24, 0.05, 0.04, 0.5), r.randf_range(2.0, 4.4), c + Vector3(r.randf_range(-3, 11), 0.138, r.randf_range(-2, 8)))
	A.add(raid.world, A.bevel_box(Vector3(9.0, 0.08, 0.08), 0.01), A.metal(Color(0.4, 0.4, 0.38)), c + Vector3(8.6, 3.1, 1.6), Vector3(0, 0, 3))
	# 容器与环境叙事（药房保险柜 / 帐篷与病房医疗箱 / 发电机棚技术箱 / 分诊台结算终端）
	K.crate(raid, c + Vector3(11.4, 0, 4.6), "safe", [], 90.0)
	K.crate(raid, c + Vector3(1.0, 0, 6.6), "med", [], 180.0)
	K.crate(raid, c + Vector3(3.9, 0, 4.2), "med", [], 180.0)
	K.crate(raid, c + Vector3(-8.8, 0, 7.8), "tech", [], -90.0)
	K.crate(raid, c + Vector3(9.2, 0, -2.4), "register", [], 180.0)
	K.fixed(raid, c + Vector3(2.2, 0, -3.4), ["arch_photo", "water_tab"], "med", 180.0)
	K.lamp(raid, c + Vector3(-12.4, 0, -1.2), Color(1.0, 0.82, 0.55))
	K.lamp(raid, c + Vector3(12.2, 0, 8.4), Color(0.6, 0.82, 1.0))
	K.rubble(raid, c + Vector3(4.8, 0, -5.4), 1.8)
	K.rubble(raid, c + Vector3(-7.2, 0, 8.6), 1.3)
	K.guard(raid, c + Vector3(0.0, 0, 1.0), "beetle", 3.2)
	K.guard(raid, c + Vector3(7.0, 0, 2.0), "spitter", 2.4)
	K.guard(raid, c + Vector3(-4.0, 0, -2.0), "spitter", 2.4)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 8.5)
	K.tag_boxes(raid, c, pid)
