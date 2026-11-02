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
	# 北山墙 + 尖拱门 + 圆窗
	K.wall_line(raid, c + Vector3(0, 0, -9.0), 11.6, 7.0, 0.0, [[-1.9, 1.9]], STONE)
	A.add(raid.world, A.prism(PackedVector2Array([Vector2(-2.4, 0), Vector2(0, 2.2), Vector2(2.4, 0)]), 0.7, 0.06), A.concrete(STONE, false), c + Vector3(0, 7.0, -9.0))
	A.add(raid.world, A.bevel_box(Vector3(1.9, 2.6, 0.8), 0.05), A.paint(Color(0.08, 0.08, 0.08), 0.1, 0.9), c + Vector3(0, 1.3, -9.0))
	# 圆窗：石框 + 八根辐条
	A.add(raid.world, A.torus(1.45, 1.9, 24), A.concrete(STONE_DARK, false), c + Vector3(0, 4.9, -9.42), Vector3(90, 0, 0))
	for i in 8:
		var a := TAU * i / 8.0
		A.add(raid.world, A.bevel_box(Vector3(0.12, 3.5, 0.1), 0.01), A.paint(Color(0.1, 0.1, 0.1), 0.2, 0.7), c + Vector3(0, 4.9, -9.4), Vector3(0, 0, rad_to_deg(a)))
	A.add(raid.world, A.cyl(1.4, 0.06, 1.4, 24), A.glass(Color(0.35, 0.45, 0.55)), c + Vector3(0, 4.9, -9.45), Vector3(90, 0, 0), Vector3.ONE, false)
	# 后殿：半圆墙 + 祭坛台阶
	for i in 7:
		var a := PI * i / 6.0
		var p := c + Vector3(cos(a) * 5.4, 0, 9.0 + sin(a) * 3.4)
		K.wall(raid, p, Vector3(2.2, 5.2, 0.5), rad_to_deg(a) - 90.0, STONE_DARK)
	A.add(raid.world, A.bevel_box(Vector3(4.0, 0.4, 2.6), 0.06), A.concrete(STONE, false), c + Vector3(0, 0.2, 9.4))
	A.add(raid.world, A.bevel_box(Vector3(2.4, 1.0, 1.0), 0.06), A.concrete(STONE.darkened(0.12), false), c + Vector3(0, 0.9, 9.6))
	A.add(raid.world, A.bevel_box(Vector3(2.2, 0.12, 0.9), 0.03), A.paint(Color(0.32, 0.24, 0.18), 0.1, 0.8), c + Vector3(0, 1.46, 9.6))
	# 五道拱肋
	for k in 5:
		var z := -6.4 + k * 3.2
		var pts: Array = []
		for i in 9:
			var t := float(i) / 8.0
			var x := lerpf(-5.6, 5.6, t)
			pts.append(c + Vector3(x, 6.0 + sin(t * PI) * 2.4, z))
		A.add(raid.world, A.tube(pts, 0.22, 6, 4), A.concrete(STONE_DARK, false), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		A.add(raid.world, A.cyl(0.3, 0.3, 0.3, 8), A.concrete(STONE.darkened(0.2), false), c + Vector3(-5.6, 6.0, z), Vector3.ZERO, Vector3.ONE, false)
	# 长椅：四排、中间留走道
	for row in 4:
		for sx in [-1.0, 1.0]:
			K.bench(raid, c + Vector3(sx * 2.9, 0, -4.6 + row * 2.6), 0.0, 3.4)
	# 管风琴：北墙前的一排立管
	for i in 6:
		var h := 2.4 + (i % 3) * 0.8
		A.add(raid.world, A.cyl(0.16, h, 0.16, 10), A.metal(Color(0.42, 0.4, 0.36)), c + Vector3(-3.4 + i * 0.62, h * 0.5, -7.6))
	# 烛台、掉落的吊灯
	for p in [Vector3(-2.6, 0, 9.0), Vector3(2.6, 0, 9.0), Vector3(0, 0, 6.6)]:
		A.add(raid.world, A.cyl(0.1, 1.4, 0.1, 6), A.metal(Color(0.4, 0.36, 0.28)), c + p + Vector3(0, 0.7, 0))
		for i in 3:
			A.add(raid.world, A.cyl(0.05, 0.34, 0.05, 6), A.emit(Color(1.0, 0.72, 0.35), 1.2), c + p + Vector3(-0.16 + i * 0.16, 1.5, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(raid.world, A.torus(1.6, 1.9, 20), A.metal(Color(0.35, 0.3, 0.22)), c + Vector3(0.8, 0.35, -1.2), Vector3(72, 0, 18))
	for i in 6:
		A.add(raid.world, A.cyl(0.04, 0.5, 0.04, 5), A.metal(Color(0.35, 0.3, 0.22)), c + Vector3(0.8 + cos(TAU * i / 6.0) * 1.68, 0.35, -1.2 + sin(TAU * i / 6.0) * 0.5), Vector3(0, 0, 0))
	# 钟塔：塔身 + 钟室 + 破铁冠
	var tp := c + Vector3(-8.6, 0, 9.4)
	K.wall(raid, tp, Vector3(4.2, 15.0, 4.2), 0.0, STONE)
	for y in [4.0, 8.0, 12.0]:
		A.add(raid.world, A.bevel_box(Vector3(4.4, 0.24, 4.4), 0.03), A.concrete(STONE_DARK, false), tp + Vector3(0, y, 0))
	for sd in [-1.0, 1.0]:
		A.add(raid.world, A.bevel_box(Vector3(1.2, 2.0, 0.2), 0.03), A.paint(Color(0.05, 0.05, 0.05), 0.1, 0.9), tp + Vector3(sd * 0.9, 13.4, 2.12))
	A.add(raid.world, A.bevel_box(Vector3(2.6, 0.5, 2.6), 0.05), A.concrete(STONE_DARK, false), tp + Vector3(0, 15.3, 0))
	A.add(raid.world, A.cyl(0.16, 3.0, 0.16, 8), A.metal(Color(0.3, 0.28, 0.26)), tp + Vector3(0, 17.0, 0))
	A.add(raid.world, A.bevel_box(Vector3(1.3, 0.16, 0.16), 0.02), A.metal(Color(0.3, 0.28, 0.26)), tp + Vector3(0, 17.8, 0))
	# 钟：塔室里的铜钟斜挂
	A.add(raid.world, A.cyl(0.9, 1.5, 0.55, 16), A.paint(Color(0.36, 0.29, 0.18), 0.7, 0.5, {"rust": 0.4, "wear": 0.4}), tp + Vector3(0.4, 13.0, -0.3), Vector3(12, 0, 9))
	# 倒塌的围墙与墓园
	K.wall_line(raid, c + Vector3(0, 0, 12.6), 20.0, 1.6, 0.0, [[-7.0, -3.0], [1.0, 5.0]], STONE_DARK)
	for i in 5:
		var p := c + Vector3(-8.0 + i * 3.4, 0, 11.0)
		A.add(raid.world, A.bevel_box(Vector3(0.7, 1.1, 0.18), 0.02), A.concrete(Color(0.5, 0.49, 0.45), false), p + Vector3(0, 0.55, 0), Vector3(r.randf_range(-6, 6), r.randf_range(-20, 20), 0))
	# 容器与环境叙事
	K.crate(raid, c + Vector3(2.4, 0, 7.2), "safe")
	K.crate(raid, c + Vector3(-3.8, 0, -6.4), "supply")
	K.crate(raid, c + Vector3(4.4, 0, -7.2), "supply")
	K.fixed(raid, c + Vector3(-4.6, 0, -7.4), ["arch_letter"], "tool")
	K.crate(raid, c + Vector3(-8.8, 0, 7.0), "tool")
	K.crate(raid, c + Vector3(3.2, 0, 4.0), "safe")
	K.lamp(raid, c + Vector3(-11.4, 0, -2.0), Color(0.7, 0.8, 1.0))
	K.lamp(raid, c + Vector3(9.6, 0, 6.0), Color(1.0, 0.74, 0.4))
	K.rubble(raid, c + Vector3(2.0, 0, -9.6), 1.6)
	K.rubble(raid, c + Vector3(-5.4, 0, 11.4), 1.2)
	K.guard(raid, c + Vector3(0.0, 0, 1.0), "beetle", 3.0)
	K.guard(raid, c + Vector3(-3.0, 0, 6.0), "spitter", 2.4)
	K.guard(raid, c + Vector3(4.0, 0, -3.0), "spitter", 2.4)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 9.5)
	K.tag_boxes(raid, c, pid)
