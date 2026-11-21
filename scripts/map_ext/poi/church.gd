extends RefCounted
## 旧港教堂：南北向的中殿，两侧长墙塌出高窗，屋顶只剩五道拱肋横跨在墙头；
## 北面是带尖拱门与圆窗的山墙，南端半圆后殿立着祭坛，东北角一座 15 米钟塔。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/map_ext/poi_kit.gd")

const STONE := Color(0.55, 0.52, 0.46)
const STONE_DARK := Color(0.44, 0.42, 0.37)


static func build(raid, c: Vector3, pid: String) -> void:
	var r = raid.rng
	K.slab(raid, c, Vector2(22, 24), Color(0.42, 0.4, 0.36))
	# 中殿两侧长墙：留出高窗与两处整段塌口
	K.wall_line(raid, c + Vector3(-5.6, 0, 0.0), 18.0, 6.2, 90.0, [[-6.2, -2.6], [1.8, 5.4]], STONE)
	K.wall_line(raid, c + Vector3(5.6, 0, 0.0), 18.0, 6.2, 90.0, [[-4.4, -0.8], [4.4, 8.0]], STONE)
	# 北山墙 + 尖拱门 + 玫瑰圆窗
	K.wall_line(raid, c + Vector3(0, 0, -9.0), 11.6, 7.0, 0.0, [[-1.9, 1.9]], STONE)
	A.add(raid.world, A.prism(PackedVector2Array([Vector2(-2.4, 0), Vector2(0, 2.2), Vector2(2.4, 0)]), 0.7, 0.06), A.concrete(STONE, false), c + Vector3(0, 7.0, -9.0))
	A.add(raid.world, A.bevel_box(Vector3(1.9, 2.6, 0.8), 0.05), A.paint(Color(0.08, 0.08, 0.08), 0.1, 0.9), c + Vector3(0, 1.3, -9.0))
	# 玫瑰圆窗：双层高细分石雕外框 + 12 根辐条 + 彩绘玻璃盘
	A.add(raid.world, A.torus(1.45, 1.92, 36), A.concrete(STONE_DARK, false), c + Vector3(0, 4.9, -9.42), Vector3(90, 0, 0))
	A.add(raid.world, A.torus(0.72, 0.88, 32), A.concrete(STONE_DARK, false), c + Vector3(0, 4.9, -9.42), Vector3(90, 0, 0))
	for i in 6:
		var a := PI * i / 6.0
		A.add(raid.world, A.bevel_box(Vector3(0.11, 3.5, 0.1), 0.01), A.paint(Color(0.1, 0.1, 0.1), 0.2, 0.7), c + Vector3(0, 4.9, -9.4), Vector3(0, 0, rad_to_deg(a)))
	A.add(raid.world, A.cyl(1.45, 0.06, 1.45, 36), A.glass(Color(0.35, 0.45, 0.55)), c + Vector3(0, 4.9, -9.45), Vector3(90, 0, 0), Vector3.ONE, false)
	# 后殿：高密度半圆环墙 + 顶部石拱压檐环 + 祭坛台阶
	A.add(raid.world, A.cyl(5.2, 0.26, 5.4, 40), A.concrete(STONE, false), c + Vector3(0, 0.13, 9.2))
	for i in 9:
		var a := PI * i / 8.0
		var p := c + Vector3(cos(a) * 5.4, 0, 9.0 + sin(a) * 3.5)
		K.wall(raid, p, Vector3(1.85, 5.2, 0.55), rad_to_deg(a) - 90.0, STONE_DARK)
	A.add(raid.world, A.bevel_box(Vector3(4.0, 0.4, 2.6), 0.06), A.concrete(STONE, false), c + Vector3(0, 0.2, 9.4))
	A.add(raid.world, A.bevel_box(Vector3(2.4, 1.0, 1.0), 0.06), A.concrete(STONE.darkened(0.12), false), c + Vector3(0, 0.9, 9.6))
	A.add(raid.world, A.bevel_box(Vector3(2.2, 0.12, 0.9), 0.03), A.paint(Color(0.32, 0.24, 0.18), 0.1, 0.8), c + Vector3(0, 1.46, 9.6))
	# 五道高细分拱肋
	for k in 5:
		var z := -6.4 + k * 3.2
		var pts: Array = []
		for i in 11:
			var t := float(i) / 10.0
			var x := lerpf(-5.6, 5.6, t)
			pts.append(c + Vector3(x, 6.0 + sin(t * PI) * 2.4, z))
		A.add(raid.world, A.tube(pts, 0.22, 10, 4), A.concrete(STONE_DARK, false), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		A.add(raid.world, A.cyl(0.32, 0.3, 0.32, 20), A.concrete(STONE.darkened(0.2), false), c + Vector3(-5.6, 6.0, z), Vector3.ZERO, Vector3.ONE, false)
	# 长椅：四排、中间留走道
	for row in 4:
		for sx in [-1.0, 1.0]:
			K.bench(raid, c + Vector3(sx * 2.9, 0, -4.6 + row * 2.6), 0.0, 3.4)
	# 管风琴：北墙前的一排立管
	for i in 6:
		var h := 2.4 + (i % 3) * 0.8
		A.add(raid.world, A.cyl(0.16, h, 0.16, 20), A.metal(Color(0.42, 0.4, 0.36)), c + Vector3(-3.4 + i * 0.62, h * 0.5, -7.6))
	# 烛台、掉落的环形铜吊灯
	for p in [Vector3(-2.6, 0, 9.0), Vector3(2.6, 0, 9.0), Vector3(0, 0, 6.6)]:
		A.add(raid.world, A.cyl(0.1, 1.4, 0.14, 16), A.metal(Color(0.4, 0.36, 0.28)), c + p + Vector3(0, 0.7, 0))
		for i in 3:
			A.add(raid.world, A.cyl(0.05, 0.34, 0.05, 12), A.emit(Color(1.0, 0.72, 0.35), 1.2), c + p + Vector3(-0.16 + i * 0.16, 1.5, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(raid.world, A.torus(1.6, 1.9, 32), A.metal(Color(0.35, 0.3, 0.22)), c + Vector3(0.8, 0.35, -1.2), Vector3(72, 0, 18))
	for i in 8:
		A.add(raid.world, A.cyl(0.04, 0.5, 0.04, 10), A.metal(Color(0.35, 0.3, 0.22)), c + Vector3(0.8 + cos(TAU * i / 8.0) * 1.68, 0.35, -1.2 + sin(TAU * i / 8.0) * 0.5), Vector3(0, 0, 0))
	# 钟塔：四角阶梯扶壁柱 + 塔身腰线 + 四面百叶钟室 + 锥形板岩塔顶与锻铁十字冠
	var tp := c + Vector3(-8.6, 0, 9.4)
	K.wall(raid, tp, Vector3(4.2, 15.0, 4.2), 0.0, STONE)
	for bx_t in [-1.95, 1.95]:
		for bz_t in [-1.95, 1.95]:
			A.add(raid.world, A.bevel_box(Vector3(0.62, 11.6, 0.62), 0.04), A.concrete(STONE_DARK, false), tp + Vector3(bx_t, 5.8, bz_t))
	for y in [4.0, 8.0, 12.0]:
		A.add(raid.world, A.bevel_box(Vector3(4.52, 0.24, 4.52), 0.03), A.concrete(STONE_DARK, false), tp + Vector3(0, y, 0))
	var M_SLAT := A.paint(Color(0.22, 0.20, 0.18), 0.2, 0.85)
	for face in 4:
		var fa := PI * 0.5 * float(face)
		var fdir := Vector3(sin(fa), 0, cos(fa))
		var sdir := Vector3(cos(fa), 0, -sin(fa))
		for sd: float in [-0.9, 0.9]:
			var wp: Vector3 = tp + fdir * 2.12 + sdir * sd + Vector3(0, 13.4, 0)
			A.add(raid.world, A.bevel_box(Vector3(1.05, 1.95, 0.16), 0.02), A.paint(Color(0.05, 0.05, 0.05), 0.1, 0.9), wp, Vector3(0, rad_to_deg(fa), 0))
			for sl in 4:
				A.add(raid.world, A.bevel_box(Vector3(0.96, 0.08, 0.22), 0.01), M_SLAT, wp + Vector3(0, -0.65 + sl * 0.44, 0) + fdir * 0.04, Vector3(28, rad_to_deg(fa), 0), Vector3.ONE, false)
	A.add(raid.world, A.bevel_box(Vector3(4.56, 0.36, 4.56), 0.05), A.concrete(STONE_DARK, false), tp + Vector3(0, 15.15, 0))
	A.add(raid.world, A.cyl(0.24, 2.4, 2.35, 8), A.paint(Color(0.26, 0.28, 0.30), 0.45, 0.58, {"rust": 0.5}), tp + Vector3(0, 16.5, 0), Vector3(0, 22.5, 0))
	A.add(raid.world, A.cyl(0.09, 2.2, 0.12, 14), A.metal(Color(0.26, 0.25, 0.24)), tp + Vector3(0, 18.2, 0))
	A.add(raid.world, A.bevel_box(Vector3(1.25, 0.14, 0.14), 0.02), A.metal(Color(0.26, 0.25, 0.24)), tp + Vector3(0, 18.75, 0))
	A.add(raid.world, A.torus(0.28, 0.34, 18), A.metal(Color(0.26, 0.25, 0.24)), tp + Vector3(0, 18.75, 0), Vector3(90, 0, 0), Vector3.ONE, false)
	# 钟：塔室里的高细分铜钟斜挂
	A.add(raid.world, A.cyl(0.55, 1.5, 0.95, 28), A.paint(Color(0.36, 0.29, 0.18), 0.7, 0.5, {"rust": 0.4, "wear": 0.4}), tp + Vector3(0.4, 13.0, -0.3), Vector3(12, 0, 9))
	# 倒塌的围墙与墓园（带碑座）
	K.wall_line(raid, c + Vector3(0, 0, 12.6), 20.0, 1.6, 0.0, [[-7.0, -3.0], [1.0, 5.0]], STONE_DARK)
	for i in 5:
		var p := c + Vector3(-8.0 + i * 3.4, 0, 11.0)
		var yaw_g: float = r.randf_range(-20, 20)
		A.add(raid.world, A.bevel_box(Vector3(0.92, 0.20, 0.38), 0.03), A.concrete(STONE_DARK, false), p + Vector3(0, 0.10, 0), Vector3(0, yaw_g, 0))
		A.add(raid.world, A.bevel_box(Vector3(0.70, 1.08, 0.18), 0.03), A.concrete(Color(0.5, 0.49, 0.45), false), p + Vector3(0, 0.68, 0), Vector3(r.randf_range(-6, 6), yaw_g, 0))
	# 容器与环境叙事（祭坛与圣器室保险柜 / 中殿避难医疗箱与补给箱 / 墓园埋藏桶）
	K.crate(raid, c + Vector3(2.4, 0, 7.2), "safe", [], 0.0)
	K.crate(raid, c + Vector3(-3.8, 0, -6.4), "med", [], 180.0)
	K.crate(raid, c + Vector3(4.4, 0, -7.2), "supply", [], 180.0)
	K.fixed(raid, c + Vector3(-4.6, 0, -7.4), ["arch_letter"], "supply", 180.0)
	K.crate(raid, c + Vector3(-8.8, 0, 7.0), "cache", [], 0.0)
	K.crate(raid, c + Vector3(3.2, 0, 4.0), "safe", [], 90.0)
	K.lamp(raid, c + Vector3(-11.4, 0, -2.0), Color(0.7, 0.8, 1.0))
	K.lamp(raid, c + Vector3(9.6, 0, 6.0), Color(1.0, 0.74, 0.4))
	K.rubble(raid, c + Vector3(2.0, 0, -9.6), 1.6)
	K.rubble(raid, c + Vector3(-5.4, 0, 11.4), 1.2)
	K.guard(raid, c + Vector3(0.0, 0, 1.0), "beetle", 3.0)
	K.guard(raid, c + Vector3(-3.0, 0, 6.0), "spitter", 2.4)
	K.guard(raid, c + Vector3(4.0, 0, -3.0), "spitter", 2.4)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 9.5)
	K.tag_boxes(raid, c, pid)
