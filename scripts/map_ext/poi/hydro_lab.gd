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
	A.add(raid.world, A.cyl(8.2, 0.5, 8.2, 32), A.concrete(Color(0.34, 0.33, 0.31), false), dome_c + Vector3(0, 0.25, 0))
	for i in 14:
		var a := TAU * i / 14.0
		if cos(a) > 0.55:
			continue
		var p := dome_c + Vector3(sin(a) * 7.6, 0, cos(a) * 7.6)
		K.wall(raid, p, Vector3(3.4, 4.2, 0.7), rad_to_deg(a), SHELL)
		if i % 2 == 0:
			A.add(raid.world, A.bevel_box(Vector3(0.6, 1.2, 0.9), 0.05), A.concrete(SHELL.darkened(0.2), false), p + Vector3(0, 4.3, 0), Vector3(0, rad_to_deg(a), r.randf_range(-6, 6)))
	# 拱肋与顶环
	for i in 8:
		var a := TAU * i / 8.0
		var pts: Array = []
		for k in 7:
			var t := float(k) / 6.0
			var rad := lerpf(7.6, 1.6, t)
			pts.append(dome_c + Vector3(sin(a) * rad, 4.2 + sin(t * PI * 0.5) * 2.8, cos(a) * rad))
		A.add(raid.world, A.tube(pts, 0.18, 6, 4), A.concrete(SHELL.darkened(0.1), false), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(raid.world, A.torus(1.5, 1.8, 20), A.concrete(SHELL.darkened(0.2), false), dome_c + Vector3(0, 7.0, 0))
	# 顶上的天线与警示灯
	A.add(raid.world, A.cyl(0.08, 4.0, 0.05, 6), A.metal(Color(0.4, 0.4, 0.38)), dome_c + Vector3(0, 9.0, 0))
	A.add(raid.world, A.sphere(0.2, -1, 10), A.emit(Color(1.0, 0.2, 0.12), 2.0), dome_c + Vector3(0, 11.0, 0), Vector3.ZERO, Vector3.ONE, false)
	# 站内积水：暗红色水面与漂浮的样本箱
	A.add(raid.world, A.cyl(6.6, 0.1, 6.6, 28), A.paint(WATER, 0.1, 0.15, {"wear": 0.0, "dust": 0.0, "panel_scale": 0.0}), dome_c + Vector3(0, 0.52, 0), Vector3.ZERO, Vector3.ONE, false)
	for i in 4:
		var a = r.randf() * TAU
		var d = r.randf_range(1.4, 5.2)
		A.add(raid.world, A.bevel_box(Vector3(0.6, 0.3, 0.4), 0.04), A.paint(Color(0.35, 0.4, 0.34), 0.2, 0.7, {"wear": 0.5}), dome_c + Vector3(sin(a) * d, 0.62, cos(a) * d), Vector3(r.randf_range(-8, 8), r.randf() * 180, 0))
	# 操作台与水质罐
	for i in 3:
		A.add(raid.world, A.bevel_box(Vector3(2.2, 0.9, 0.8), 0.04), A.paint(Color(0.3, 0.33, 0.32), 0.4, 0.5, {"rust": 0.6, "wear": 0.5}), dome_c + Vector3(-3.6 + i * 1.6, 0.95, -3.2))
		A.add(raid.world, A.bevel_box(Vector3(1.4, 0.5, 0.05), 0.01), A.emit(Color(0.3, 0.75, 0.6), 0.7), dome_c + Vector3(-3.6 + i * 1.6, 1.15, -3.62), Vector3(0, 180, 0), Vector3.ONE, false)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var p := dome_c + Vector3(sin(a) * 4.6, 0, cos(a) * 4.6)
		A.add(raid.world, A.cyl(0.45, 2.2, 0.45, 14), A.glass(Color(0.35, 0.8, 0.55)), p + Vector3(0, 1.1, 0), Vector3.ZERO, Vector3.ONE, false)
		A.add(raid.world, A.cyl(0.5, 0.12, 0.5, 14), A.metal(Color(0.4, 0.4, 0.38)), p + Vector3(0, 2.2, 0))
		A.add(raid.world, A.cyl(0.5, 0.12, 0.5, 14), A.metal(Color(0.4, 0.4, 0.38)), p + Vector3(0, 0.06, 0))
	# 木栈桥：从岸上接到圆顶北口
	var pier := dome_c + Vector3(0, 0, 11.4)
	A.add(raid.world, A.bevel_box(Vector3(4.0, 0.22, 9.0), 0.05), A.paint(Color(0.32, 0.26, 0.19), 0.0, 0.9, {"wear": 0.7, "dust": 0.5, "panel_scale": 0.5}), pier)
	for k in 5:
		A.add(raid.world, A.bevel_box(Vector3(3.9, 0.04, 0.12), 0.01), A.paint(Color(0.24, 0.2, 0.15), 0.0, 0.9, {"wear": 0.8}), pier + Vector3(0, 0.13, -3.6 + k * 1.8), Vector3.ZERO, Vector3.ONE, false)
	for sx in [-1.9, 1.9]:
		for k in 3:
			A.add(raid.world, A.cyl(0.16, 1.6, 0.16, 8), A.paint(Color(0.28, 0.22, 0.16), 0.0, 0.9, {"wear": 0.6}), pier + Vector3(sx, -1.0, -3.6 + k * 3.6))
	K.railing(raid, pier + Vector3(-1.95, 0, 0), 9.0, 90.0, 1.0)
	K.railing(raid, pier + Vector3(1.95, 0, 0), 9.0, 90.0, 1.0)
	# 水线：一圈深色湿痕与浮萍
	A.ground_decal(raid.world, A.cloud_tex(), Color(0.1, 0.03, 0.05, 0.55), 19.0, dome_c + Vector3(0, 0.025, 0))
	for i in 6:
		var a = r.randf() * TAU
		A.ground_decal(raid.world, A.cloud_tex(), Color(0.14, 0.2, 0.1, 0.4), r.randf_range(2.0, 4.0), dome_c + Vector3(sin(a) * 8.6, 0.03, cos(a) * 8.6))
	# 岸上的观测桩与取样浮标
	for i in 3:
		A.add(raid.world, A.cyl(0.08, 1.4, 0.08, 6), A.metal(Color(0.45, 0.45, 0.42)), c + Vector3(-7.0 + i * 2.2, 0.7, -8.4))
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
