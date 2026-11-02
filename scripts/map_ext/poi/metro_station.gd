extends RefCounted
## 三号线站台：半塌的地铁站厅。北侧是断续的站厅墙、南侧月台沿轨道展开，
## 月台柱列 + 轨道床 + 售票亭 + 停运的自动扶梯构成一条明显的长轴轮廓。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/map_ext/poi_kit.gd")

const CONCRETE := Color(0.46, 0.46, 0.44)
const TILE := Color(0.52, 0.51, 0.47)


static func build(raid, c: Vector3, pid: String) -> void:
	var r = raid.rng
	K.slab(raid, c, Vector2(28, 18), Color(0.42, 0.42, 0.4))
	# 站厅地面：磨掉一半的浅色瓷砖
	K.slab(raid, c + Vector3(0, 0.02, -2.5), Vector2(23, 9), TILE)
	# 北墙：保留大段，中间塌出两处缺口
	K.wall_line(raid, c + Vector3(0, 0, -7.2), 24.0, 4.4, 0.0, [[-9.5, -6.5], [2.5, 7.5]], CONCRETE)
	# 南墙：只剩两截残墙
	K.wall_line(raid, c + Vector3(0, 0, 7.4), 26.0, 2.8, 0.0, [[-9.0, 9.0]], CONCRETE.darkened(0.1))
	# 月台边沿（矮沿，不挡子弹）
	A.add(raid.world, A.bevel_box(Vector3(24.0, 0.3, 0.55), 0.04), A.concrete(Color(0.6, 0.57, 0.5), false), c + Vector3(0, 0.15, 2.6))
	A.add(raid.world, A.bevel_box(Vector3(24.0, 0.06, 0.3), 0.01), A.hazard(), c + Vector3(0, 0.31, 2.6), Vector3.ZERO, Vector3.ONE, false)
	# 轨道床 + 钢轨 + 枕木
	A.add(raid.world, A.bevel_box(Vector3(28.0, 0.1, 5.0), 0.04), A.concrete(Color(0.2, 0.19, 0.18), false), c + Vector3(0, 0.05, 5.4), Vector3.ZERO, Vector3.ONE, false)
	for z in [3.9, 6.9]:
		A.add(raid.world, A.bevel_box(Vector3(28.0, 0.16, 0.14), 0.02), A.metal(Color(0.35, 0.34, 0.32)), c + Vector3(0, 0.18, z), Vector3.ZERO, Vector3.ONE, false)
	for i in 14:
		var x := -13.0 + i * 2.0
		A.add(raid.world, A.bevel_box(Vector3(0.42, 0.1, 3.4), 0.01), A.paint(Color(0.26, 0.2, 0.15), 0.0, 0.9, {"wear": 0.6, "dust": 0.6}), c + Vector3(x, 0.12, 5.4), Vector3.ZERO, Vector3.ONE, false)
	# 月台柱列
	for i in 5:
		K.pillar(raid, c + Vector3(-9.0 + i * 4.5, 0, -1.6), 0.52, 4.3, CONCRETE.darkened(0.06))
	# 售票亭：三面墙 + 柜台，门朝月台
	K.wall_line(raid, c + Vector3(-9.6, 0, -6.0), 6.4, 3.4, 0.0, [], CONCRETE.darkened(0.05))
	K.wall_line(raid, c + Vector3(-12.8, 0, -3.2), 6.2, 3.4, 90.0, [], CONCRETE.darkened(0.05))
	K.wall_line(raid, c + Vector3(-9.6, 0, -0.2), 6.4, 3.2, 0.0, [[0.8, 3.2]], CONCRETE.darkened(0.05))
	K.desk(raid, c + Vector3(-10.6, 0, -3.6), 0.0, 2.6, Color(0.3, 0.26, 0.2))
	# 售票窗口后面的铁皮柜
	K.shelf(raid, c + Vector3(-12.0, 0, -5.4), 90.0, 2.0, 1.8)
	# 停运的自动扶梯：台阶爬向东侧出口
	K.steps(raid, c + Vector3(10.8, 0, 2.0), 8, 0.34, 0.62, 3.0, 0.0)
	for sx in [-1.6, 1.6]:
		A.add(raid.world, A.bevel_box(Vector3(0.12, 0.9, 5.4), 0.02), A.metal(Color(0.3, 0.3, 0.29)), c + Vector3(10.8 + sx, 1.9, 4.4), Vector3(-24, 0, 0), Vector3.ONE, false)
	# 售票亭东侧的自动售货机：一台立着，一台倒在地上
	var VM := A.paint(Color(0.3, 0.38, 0.4), 0.25, 0.5, {"wear": 0.6, "rust": 0.5, "dust": 0.5, "panel_scale": 0.0})
	var v1 := A.add(raid.world, A.bevel_box(Vector3(1.0, 2.0, 0.75), 0.05), VM, c + Vector3(-4.2, 1.0, -6.4))
	A.add(v1, A.bevel_box(Vector3(0.66, 1.10, 0.05), 0.02), A.emit(Color(0.25, 0.5, 0.55), 0.35), Vector3(0, 0.34, 0.39), Vector3.ZERO, Vector3.ONE, false)
	A.stencil(v1, "DRINK", Vector3(0, -0.62, 0.39), Vector3.ZERO, 0.02, Color(0.8, 0.8, 0.75, 0.5), 32)
	K.blocker(raid, c + Vector3(-4.2, 0, -6.4), Vector3(1.0, 2.0, 0.75))
	var v2 := A.add(raid.world, A.bevel_box(Vector3(1.0, 1.9, 0.75), 0.05), VM, c + Vector3(1.6, 0.42, -4.8), Vector3(0, 22, 88))
	v2.rotation_degrees = Vector3(0, 22, 88)
	raid.blocks.append(raid._rect_for(c + Vector3(1.6, 0, -4.8), Vector3(2.2, 1, 1.4)))
	# 长椅与地上的行李箱
	K.bench(raid, c + Vector3(-4.4, 0, 0.4), 0.0)
	K.bench(raid, c + Vector3(0.6, 0, 0.4), 0.0)
	K.bench(raid, c + Vector3(5.6, 0, 0.4), 0.0)
	for p in [Vector3(-2.2, 0.3, -0.9), Vector3(3.4, 0.3, -1.2), Vector3(-11.6, 0.3, 1.1)]:
		A.add(raid.world, A.bevel_box(Vector3(0.9, 0.6, 0.45), 0.05), A.paint(Color(0.4, 0.32, 0.22), 0.1, 0.8, {"wear": 0.6, "dust": 0.5}), c + p, Vector3(0, r.randf() * 90, 0))
	# 线路牌与站名牌
	K.sign(raid, c + Vector3(7.6, 2.2, -6.8), 0.0, "LINE 3", 4.4, 1.3)
	A.stencil(raid.world, "STA-03  PLATFORM 2", c + Vector3(-6.0, 2.6, -6.85), Vector3.ZERO, 0.02, Color(0.85, 0.83, 0.76, 0.7), 48)
	# 检票闸机：两排立柱
	for i in 3:
		for z in [-3.4, -2.4]:
			A.add(raid.world, A.bevel_box(Vector3(0.28, 1.15, 0.7), 0.03), A.metal(Color(0.28, 0.29, 0.3)), c + Vector3(-6.6 + i * 1.4, 0.58, z))
	# 容器
	K.fixed(raid, c + Vector3(-11.4, 0, -1.3), ["arch_duty_log", "circuit"], "tool")
	K.crate(raid, c + Vector3(-11.9, 0, -3.9), "safe")
	K.crate(raid, c + Vector3(-5.2, 0, 6.2), "tool")
	K.crate(raid, c + Vector3(11.8, 0, -4.6), "military")
	K.crate(raid, c + Vector3(12.4, 0, -1.6), "military")
	K.crate(raid, c + Vector3(7.8, 0, 1.2), "supply")
	# 照明、积水、守卫
	K.lamp(raid, c + Vector3(-13.2, 0, 5.6), Color(0.62, 0.82, 0.95))
	K.lamp(raid, c + Vector3(13.0, 0, -6.0), Color(1.0, 0.72, 0.42))
	for i in 4:
		var p = c + Vector3(r.randf_range(-12, 12), 0.02, r.randf_range(-6, 2))
		A.ground_decal(raid.world, A.cloud_tex(), Color(0.04, 0.06, 0.08, 0.4), r.randf_range(2.2, 4.6), p)
	K.rubble(raid, c + Vector3(-8.4, 0, 8.2), 1.6)
	K.rubble(raid, c + Vector3(4.6, 0, -7.6), 1.4)
	K.guard(raid, c + Vector3(1.0, 0, 3.6), "beetle", 3.0)
	K.guard(raid, c + Vector3(-6.0, 0, -2.0), "ling", 2.0)
	K.guard(raid, c + Vector3(8.0, 0, 0.6), "ling", 2.0)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 8.0)
	K.tag_boxes(raid, c, pid)
