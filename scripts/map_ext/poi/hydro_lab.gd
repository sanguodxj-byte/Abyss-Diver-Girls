extends RefCounted
## 沉没的水质观测所：半沉进赤湖的圆顶观测站。环形墙体只剩一圈骨架，八道拱肋收向中央的破损顶环，
## 北面接一条木栈桥，站内积着暗红色的水，水质罐与操作台泡在水线上下。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/map_ext/poi_kit.gd")

const SHELL := Color(0.5, 0.48, 0.44)
const WATER := Color(0.22, 0.08, 0.1)


static func build(raid, c: Vector3, pid: String) -> void:
	var r = raid.rng
	K.slab(raid, c + Vector3(0, 0, 2.0), Vector2(19, 16), Color(0.38, 0.36, 0.34))
	# 圆顶基座与环形墙体：北侧留出三段落水口
	var dome_c := c + Vector3(0, 0, 2.0)
	A.add(raid.world, A.cyl(8.25, 0.5, 8.45, 48), A.concrete(Color(0.34, 0.33, 0.31), false), dome_c + Vector3(0, 0.25, 0))
	A.add(raid.world, A.torus(7.85, 8.32, 48), A.concrete(SHELL.darkened(0.24), false), dome_c + Vector3(0, 0.52, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
	for i in 14:
		var a := TAU * i / 14.0
		if cos(a) > 0.55:
			continue
		var p := dome_c + Vector3(sin(a) * 7.6, 0, cos(a) * 7.6)
		K.wall(raid, p, Vector3(3.4, 4.2, 0.7), rad_to_deg(a), SHELL)
		if i % 2 == 0:
			A.add(raid.world, A.bevel_box(Vector3(0.6, 1.2, 0.9), 0.05), A.concrete(SHELL.darkened(0.2), false), p + Vector3(0, 4.2, 0), Vector3(0, rad_to_deg(a), r.randf_range(-4, 4)))
	# 八道高细分经向拱肋 + 两层纬向环梁 + 顶环
	var M_RIB := A.concrete(SHELL.darkened(0.1), false)
	var M_MET := A.metal(Color(0.34, 0.35, 0.34))
	for i in 8:
		var a := TAU * i / 8.0
		var pts: Array = []
		for k in 9:
			var t := float(k) / 8.0
			var rad := lerpf(7.6, 1.6, t)
			pts.append(dome_c + Vector3(sin(a) * rad, 4.2 + sin(t * PI * 0.5) * 2.8, cos(a) * rad))
		A.add(raid.world, A.tube(pts, 0.2, 12, 4), M_RIB, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	for t_lat in [0.32, 0.66]:
		var r_lat := lerpf(7.6, 1.6, t_lat)
		var y_lat := 4.2 + sin(t_lat * PI * 0.5) * 2.8
		A.add(raid.world, A.torus(r_lat - 0.1, r_lat + 0.12, 44), M_MET, dome_c + Vector3(0, y_lat, 0), Vector3.ZERO, Vector3(1, 0.55, 1), false)
	A.add(raid.world, A.torus(1.48, 1.85, 36), A.concrete(SHELL.darkened(0.2), false), dome_c + Vector3(0, 7.0, 0))
	# 顶上的测风十字横臂天线与护笼航空障碍灯（消除悬浮发光圆球）
	A.add(raid.world, A.cyl(0.08, 3.6, 0.11, 16), M_MET, dome_c + Vector3(0, 8.8, 0))
	A.add(raid.world, A.bevel_box(Vector3(1.15, 0.06, 0.06), 0.01), M_MET, dome_c + Vector3(0, 10.1, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(raid.world, A.bevel_box(Vector3(0.06, 0.05, 1.15), 0.01), M_MET, dome_c + Vector3(0, 10.1, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(raid.world, A.cyl(0.16, 0.14, 0.18, 14), M_MET, dome_c + Vector3(0, 10.62, 0))
	A.add(raid.world, A.cyl(0.10, 0.22, 0.10, 12), A.emit(Color(1.0, 0.28, 0.12), 1.35), dome_c + Vector3(0, 10.80, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(raid.world, A.torus(0.13, 0.16, 14), M_MET, dome_c + Vector3(0, 10.84, 0), Vector3.ZERO, Vector3.ONE, false)
	# 站内积水：暗红色水面与漂浮的样本箱
	A.add(raid.world, A.cyl(6.65, 0.1, 6.65, 44), A.paint(WATER, 0.1, 0.15, {"wear": 0.0, "dust": 0.0, "panel_scale": 0.0}), dome_c + Vector3(0, 0.52, 0), Vector3.ZERO, Vector3.ONE, false)
	for i in 4:
		var a = r.randf() * TAU
		var d = r.randf_range(1.4, 5.2)
		A.add(raid.world, A.bevel_box(Vector3(0.6, 0.3, 0.4), 0.04), A.paint(Color(0.35, 0.4, 0.34), 0.2, 0.7, {"wear": 0.5}), dome_c + Vector3(sin(a) * d, 0.62, cos(a) * d), Vector3(r.randf_range(-8, 8), r.randf() * 180, 0))
	# 操作台与重工高压水质采样封存罐（钢法兰端盖 + 四根外置拉杆 + 烟青色水样液柱 + 顶部手轮阀，零悬浮圆球）
	for i in 3:
		A.add(raid.world, A.bevel_box(Vector3(2.2, 0.9, 0.8), 0.04), A.paint(Color(0.3, 0.33, 0.32), 0.4, 0.5, {"rust": 0.6, "wear": 0.5}), dome_c + Vector3(-3.6 + i * 1.6, 0.95, -3.2))
		A.add(raid.world, A.bevel_box(Vector3(1.4, 0.5, 0.05), 0.01), A.emit(Color(0.3, 0.75, 0.6), 0.7), dome_c + Vector3(-3.6 + i * 1.6, 1.15, -3.62), Vector3(0, 180, 0), Vector3.ONE, false)
	var m_fluid := A.emit(Color(0.24, 0.72, 0.62), 0.85)
	m_fluid.albedo_color = Color(0.08, 0.24, 0.22)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var p := dome_c + Vector3(sin(a) * 4.6, 0, cos(a) * 4.6)
		A.add(raid.world, A.cyl(0.58, 0.22, 0.62, 24), A.metal(Color(0.26, 0.27, 0.26)), p + Vector3(0, 0.11, 0))
		A.add(raid.world, A.cyl(0.45, 2.05, 0.45, 24), A.glass(Color(0.22, 0.46, 0.44)), p + Vector3(0, 1.22, 0), Vector3.ZERO, Vector3.ONE, false)
		A.add(raid.world, A.cyl(0.36, 1.55, 0.36, 20), m_fluid, p + Vector3(0, 1.02, 0), Vector3.ZERO, Vector3.ONE, false)
		A.add(raid.world, A.cyl(0.54, 0.22, 0.56, 24), A.metal(Color(0.32, 0.33, 0.32)), p + Vector3(0, 2.30, 0))
		A.add(raid.world, A.torus(0.18, 0.23, 16), A.paint(Color(0.68, 0.24, 0.16), 0.4, 0.5), p + Vector3(0, 2.52, 0), Vector3.ZERO, Vector3.ONE, false)
		for tr in 4:
			var ta := PI * 0.25 + PI * 0.5 * float(tr)
			A.add(raid.world, A.cyl(0.026, 2.15, 0.026, 8), M_MET, p + Vector3(cos(ta) * 0.50, 1.20, sin(ta) * 0.50), Vector3.ZERO, Vector3.ONE, false)
		A.add(raid.world, A.torus(0.47, 0.53, 24), M_MET, p + Vector3(0, 1.25, 0), Vector3.ZERO, Vector3(1, 0.45, 1), false)
	# 木栈桥：纵梁骨架 + 横向栈道木板，从岸上接到圆顶北口
	var pier := dome_c + Vector3(0, 0.14, 11.4)
	A.add(raid.world, A.bevel_box(Vector3(4.0, 0.22, 9.0), 0.05), A.paint(Color(0.32, 0.26, 0.19), 0.0, 0.9, {"wear": 0.7, "dust": 0.5, "panel_scale": 0.5}), pier)
	for sx_s in [-1.65, 1.65]:
		A.add(raid.world, A.bevel_box(Vector3(0.22, 0.26, 9.1), 0.02), A.metal(Color(0.22, 0.23, 0.22)), pier + Vector3(sx_s, -0.18, 0))
	for k in 5:
		A.add(raid.world, A.bevel_box(Vector3(3.9, 0.04, 0.12), 0.01), A.paint(Color(0.24, 0.2, 0.15), 0.0, 0.9, {"wear": 0.8}), pier + Vector3(0, 0.13, -3.6 + k * 1.8), Vector3.ZERO, Vector3.ONE, false)
	for sx in [-1.9, 1.9]:
		for k in 3:
			A.add(raid.world, A.cyl(0.16, 1.2, 0.16, 16), A.paint(Color(0.28, 0.22, 0.16), 0.0, 0.9, {"wear": 0.6}), pier + Vector3(sx, -0.45, -3.6 + k * 3.6))
	K.railing(raid, dome_c + Vector3(-1.95, 0.14, 11.4), 9.0, 90.0, 1.0)
	K.railing(raid, dome_c + Vector3(1.95, 0.14, 11.4), 9.0, 90.0, 1.0)
	# 水线：一圈深色湿痕与浮萍
	A.ground_decal(raid.world, A.cloud_tex(), Color(0.1, 0.03, 0.05, 0.55), 19.0, dome_c + Vector3(0, 0.138, 0))
	for i in 6:
		var a = r.randf() * TAU
		A.ground_decal(raid.world, A.cloud_tex(), Color(0.14, 0.2, 0.1, 0.4), r.randf_range(2.0, 4.0), dome_c + Vector3(sin(a) * 8.6, 0.140, cos(a) * 8.6))
	# 岸上的观测桩与取样浮标
	for i in 3:
		A.add(raid.world, A.cyl(0.08, 1.4, 0.08, 12), A.metal(Color(0.45, 0.45, 0.42)), c + Vector3(-7.0 + i * 2.2, 0.7, -8.4))
		A.add(raid.world, A.bevel_box(Vector3(0.5, 0.4, 0.05), 0.01), A.paint(Color(0.6, 0.58, 0.5), 0.1, 0.8, {"wear": 0.5}), c + Vector3(-7.0 + i * 2.2, 1.35, -8.4))
	# 容器与环境叙事
	K.crate(raid, dome_c + Vector3(4.6, 0, -1.0), "safe")
	K.crate(raid, dome_c + Vector3(-4.6, 0, 0.6), "tool")
	K.fixed(raid, dome_c + Vector3(-1.8, 0, -3.8), ["arch_observation", "hdd"], "tool")
	K.fixed(raid, dome_c + Vector3(2.6, 0, 4.2), ["water_tab", "water_tab"], "supply")
	K.crate(raid, c + Vector3(-6.6, 0, -9.0), "supply")
	K.crate(raid, c + Vector3(7.0, 0, -7.2), "military")
	K.lamp(raid, dome_c + Vector3(5.4, 0, 4.2), Color(0.55, 0.85, 0.8))
	K.lamp(raid, c + Vector3(-8.2, 0, -7.4), Color(1.0, 0.72, 0.42))
	K.rubble(raid, c + Vector3(6.0, 0, 6.0), 1.6)
	K.guard(raid, dome_c + Vector3(-2.0, 0, 1.0), "spitter", 2.6)
	K.guard(raid, dome_c + Vector3(3.0, 0, 0.0), "spitter", 2.6)
	K.guard(raid, dome_c + Vector3(0.0, 0, 5.0), "ling", 2.2)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 9.0)
	K.tag_boxes(raid, c, pid)
