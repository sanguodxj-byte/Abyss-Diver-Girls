extends RefCounted
## 白鹭号舰桥舱：坠毁友舰的前部舰桥半埋进土里，装甲舷窗朝着天空，断掉的桅杆斜插在残骸旁。
## 舱内还留着海图台与两排指挥席，船体编号与警示条残在侧板上。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/map_ext/poi_kit.gd")

const HULL := Color(0.68, 0.66, 0.59)
const HULL_DARK := Color(0.4, 0.39, 0.35)


static func build(raid, c: Vector3, pid: String) -> void:
	var r = raid.rng
	K.slab(raid, c, Vector2(24, 20), Color(0.38, 0.36, 0.32))
	# 坠毁坑：焦土 + 甩出的舰体碎片
	A.ground_decal(raid.world, A.cloud_tex(), Color(0.08, 0.07, 0.06, 0.7), 22.0, c + Vector3(0, 0.03, 0))
	for i in 10:
		var a = r.randf() * TAU
		var d = r.randf_range(6.0, 11.5)
		A.add(raid.world, A.bevel_box(Vector3(r.randf_range(0.6, 2.4), r.randf_range(0.12, 0.4), r.randf_range(0.5, 1.8)), 0.04),
			A.paint(HULL_DARK, 0.5, 0.6, {"wear": 0.7, "rust": 0.8}), c + Vector3(sin(a) * d, 0.15, cos(a) * d), Vector3(r.randf_range(-25, 25), r.randf() * 360, r.randf_range(-25, 25)))
	# 主舰体：倾斜半埋的楔形舱段
	var hull := Node3D.new()
	raid.world.add_child(hull)
	hull.position = c + Vector3(-1.0, -0.6, 1.0)
	hull.rotation_degrees = Vector3(4, 18, -9)
	A.add(hull, A.bevel_box(Vector3(9.0, 4.2, 13.0), 0.22, 0.92), A.paint(HULL, 0.4, 0.55, {"wear": 0.5, "rust": 0.6, "dust": 0.55, "panel_scale": 1.4}), Vector3(0, 2.4, 0))
	A.add(hull, A.bevel_box(Vector3(7.6, 1.4, 5.0), 0.14, 0.86), A.paint(HULL.lightened(0.06), 0.35, 0.5, {"wear": 0.5, "rust": 0.4, "panel_scale": 1.2}), Vector3(0, 4.9, 1.4))
	# 舷窗：朝天的深色玻璃带与断裂的窗框
	for i in 3:
		A.add(hull, A.bevel_box(Vector3(1.8, 0.2, 1.2), 0.04), A.glass(Color(0.28, 0.55, 0.65)), Vector3(-2.4 + i * 2.2, 5.06, 0.4), Vector3(0, 0, 4))
		A.add(hull, A.bevel_box(Vector3(2.0, 0.26, 1.4), 0.06), A.paint(HULL_DARK, 0.6, 0.5, {"rust": 0.7}), Vector3(-2.4 + i * 2.2, 5.02, 0.4), Vector3(0, 0, 4))
	# 侧板：装甲条、铆钉排、编号喷字、警示条
	for i in 4:
		A.add(hull, A.bevel_box(Vector3(9.2, 0.16, 0.28), 0.03), A.paint(HULL_DARK, 0.6, 0.55, {"rust": 0.8, "wear": 0.5}), Vector3(0, 1.0 + i * 0.9, -6.55))
	A.stencil(hull, "EGRET-01", Vector3(0.2, 2.9, -6.56), Vector3(0, 180, 0), 0.03, Color(0.9, 0.88, 0.8, 0.55), 56)
	A.add(hull, A.bevel_box(Vector3(6.0, 0.34, 0.2), 0.02), A.hazard(), Vector3(-1.0, 4.0, -6.55))
	# 顶面破口：焦黑弹洞、掀起的甲板片、露出的一排肋骨
	A.add(hull, A.bevel_box(Vector3(3.4, 0.18, 2.6), 0.06), A.paint(Color(0.05, 0.05, 0.05), 0.2, 0.9, {"dust": 0.0, "panel_scale": 0.0}), Vector3(0.4, 4.52, -4.2), Vector3(2, 14, 3))
	for k in 4:
		A.add(hull, A.bevel_box(Vector3(1.5, 0.14, 0.9), 0.04), A.paint(HULL.darkened(0.08), 0.4, 0.6, {"rust": 0.85, "wear": 0.7}),
			Vector3(-1.9 + k * 1.3, 4.62, -5.2 + r.randf_range(-0.5, 0.5)), Vector3(r.randf_range(-14, 14), r.randf_range(-25, 25), r.randf_range(-16, 16)))
	for k in 5:
		A.add(hull, A.tube([Vector3(-1.6 + k * 0.8, 4.3, -5.6), Vector3(-1.5 + k * 0.8, 4.62, -1.4)], 0.05, 4, 2), A.metal(Color(0.3, 0.29, 0.26)), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	# 舰桥顶部舷窗带与舱门
	for k in 3:
		A.add(hull, A.bevel_box(Vector3(1.6, 0.12, 1.0), 0.02), A.glass(Color(0.28, 0.5, 0.58)), Vector3(-2.2 + k * 2.2, 5.62, 2.2), Vector3.ZERO, Vector3.ONE, false)
		A.add(hull, A.bevel_box(Vector3(1.8, 0.16, 1.2), 0.04), A.paint(HULL_DARK, 0.6, 0.5, {"rust": 0.7}), Vector3(-2.2 + k * 2.2, 5.56, 2.2), Vector3.ZERO, Vector3.ONE, false)
	A.add(hull, A.bevel_box(Vector3(1.4, 0.12, 1.8), 0.03), A.paint(Color(0.18, 0.19, 0.18), 0.5, 0.6, {"rust": 0.6}), Vector3(2.4, 5.64, 2.4))
	raid.blocks.append(raid._rect_for(c + Vector3(-1.0, 0, 1.0), Vector3(9.6, 1, 13.4)))
	K.blocker(raid, c + Vector3(-1.0, 0, 1.0), Vector3(7.0, 4.2, 10.0), 18.0)
	# 断桅：斜插的杆体 + 缠绕的缆索
	var mast := c + Vector3(7.6, 0, -3.4)
	A.add(raid.world, A.tube([mast + Vector3(0, 0, 0), mast + Vector3(3.2, 9.0, 1.6), mast + Vector3(5.4, 12.0, 3.2)], 0.16, 8, 3), A.paint(HULL_DARK, 0.7, 0.5, {"rust": 0.8}), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	for i in 3:
		K.cable(raid, mast + Vector3(2.6 + i * 0.6, 8.0 + i * 0.4, 1.4), mast + Vector3(-2.0 - i * 2.0, 0.2, 4.0 + i * 2.0), 0.5, 0.035)
	A.add(raid.world, A.sphere(0.16, -1, 8), A.emit(Color(1.0, 0.3, 0.15), 1.8), mast + Vector3(5.4, 12.2, 3.2), Vector3.ZERO, Vector3.ONE, false)
	# 舰桥内部：海图台、指挥席、倾倒的仪器柜
	A.add(raid.world, A.bevel_box(Vector3(3.4, 0.9, 2.4), 0.06), A.paint(Color(0.3, 0.33, 0.32), 0.5, 0.5, {"wear": 0.5, "rust": 0.5}), c + Vector3(-1.6, 1.05, 5.0), Vector3(0, 18, 2))
	A.add(raid.world, A.bevel_box(Vector3(2.6, 0.1, 1.8), 0.02), A.paint(Color(0.24, 0.4, 0.42), 0.3, 0.4), c + Vector3(-1.6, 1.53, 5.0), Vector3(0, 18, 2))
	for i in 2:
		A.add(raid.world, A.bevel_box(Vector3(1.0, 0.5, 1.0), 0.06), A.paint(Color(0.24, 0.24, 0.22), 0.4, 0.6, {"rust": 0.6}), c + Vector3(2.6 + i * 2.2, 0.55, 6.4 + i * 1.2), Vector3(0, r.randf_range(-30, 30), 0))
	for i in 3:
		A.add(raid.world, A.bevel_box(Vector3(0.8, 1.6, 0.6), 0.05), A.paint(Color(0.3, 0.3, 0.28), 0.5, 0.6, {"rust": 0.7}), c + Vector3(-5.4 + i * 0.9, 0.8, 7.4), Vector3(0, 0, 82))
	# 黑匣子：橙色耐撞匣，半埋在舱体前
	var bb := c + Vector3(3.0, 0, 7.6)
	var box := A.add(raid.world, A.bevel_box(Vector3(1.6, 1.2, 1.1), 0.12), A.paint(Color(0.78, 0.32, 0.08), 0.3, 0.5, {"wear": 0.5, "rust": 0.4}), bb + Vector3(0, 0.55, 0), Vector3(0, 24, 0))
	A.add(box, A.bevel_box(Vector3(1.7, 0.14, 1.2), 0.02), A.hazard(), Vector3(0, 0.42, 0))
	A.add(box, A.bevel_box(Vector3(0.9, 0.06, 0.5), 0.01), A.emit(Color(1.0, 0.55, 0.12), 0.7), Vector3(0, 0.62, -0.56), Vector3.ZERO, Vector3.ONE, false)
	# 舱体尾部断裂面：露出的骨架与线束
	for i in 5:
		A.add(raid.world, A.cyl(0.06, 1.6, 0.06, 5), A.metal(Color(0.3, 0.29, 0.26)), c + Vector3(-5.4 + i * 0.7, 1.3, -4.8), Vector3(r.randf_range(-30, 30), r.randf_range(-30, 30), r.randf_range(-30, 30)))
	# 容器与环境叙事
	K.fixed(raid, bb + Vector3(2.4, 0, 0.6), ["arch_flight_log", "hdd", "bug_crystal"], "military")
	K.crate(raid, c + Vector3(-6.4, 0, -7.4), "military")
	K.crate(raid, c + Vector3(-4.8, 0, -7.8), "military")
	K.crate(raid, c + Vector3(8.2, 0, 6.0), "tool")
	K.crate(raid, c + Vector3(-8.6, 0, 6.4), "supply")
	K.crate(raid, c + Vector3(6.4, 0, -8.0), "supply")
	K.lamp(raid, c + Vector3(-9.6, 0, -8.4), Color(1.0, 0.72, 0.4))
	K.lamp(raid, c + Vector3(10.0, 0, 3.0), Color(0.62, 0.85, 1.0))
	K.rubble(raid, c + Vector3(0.0, 0, -8.0), 2.2, HULL_DARK)
	K.guard(raid, c + Vector3(1.0, 0, 4.0), "beetle", 3.0)
	K.guard(raid, c + Vector3(-4.0, 0, 2.0), "beetle", 3.2)
	K.guard(raid, c + Vector3(5.0, 0, 2.0), "ling", 2.2)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 9.5)
	K.tag_boxes(raid, c, pid)
