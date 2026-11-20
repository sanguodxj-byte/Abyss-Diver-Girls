extends RefCounted
## 零号钻井核心台：环形混凝土平台围着一口黑下去的竖井，井口立着 20 米高的钻塔，
## 塔索垂进井里；平台外缘全是紫光虫晶簇与菌毯，控制台还亮着余电。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/map_ext/poi_kit.gd")

const ROCK := Color(0.16, 0.13, 0.18)
const PLATE := Color(0.3, 0.29, 0.32)


static func build(raid, c: Vector3, pid: String) -> void:
	var r = raid.rng
	# 环形平台：连续高细分混凝土圆环底板 + 八段重型放射状装甲甲板（独立 Node3D 节点保证静态合并）
	A.add(raid.world, A.torus(6.8, 11.2, 48), A.concrete(PLATE.darkened(0.12), false), c + Vector3(0, 0.14, 0), Vector3.ZERO, Vector3(1, 0.18, 1), false)
	for i in 8:
		var a := TAU * i / 8.0
		var seg := Node3D.new()
		raid.world.add_child(seg)
		seg.position = c + Vector3(sin(a) * 9.0, 0.18 + (0.014 if (i % 2) == 1 else 0.0), cos(a) * 9.0)
		seg.rotation_degrees = Vector3(0, -rad_to_deg(a), 0)
		A.add(seg, A.bevel_box(Vector3(7.2, 0.36, 4.2), 0.06), A.concrete(PLATE, true), Vector3.ZERO)
		A.add(seg, A.bevel_box(Vector3(7.24, 0.06, 0.4), 0.02), A.metal(Color(0.28, 0.27, 0.3)), Vector3(0, 0.18, 1.9), Vector3.ZERO, Vector3.ONE, false)
		A.add(seg, A.bevel_box(Vector3(7.24, 0.05, 0.18), 0.01), A.emit(Color(0.45, 0.75, 0.85), 0.6), Vector3(0, 0.19, -1.94), Vector3.ZERO, Vector3.ONE, false)
		A.add(seg, A.bevel_box(Vector3(6.8, 0.10, 0.22), 0.01), A.hazard(), Vector3(0, 0.16, -1.62), Vector3.ZERO, Vector3.ONE, false)
	# 井口：高细分铸铁防喷井圈钢套管 + 径向液压锁紧卡瓦 + 深井地热余烬导流环（取代紫色悬浮大球与甲壳刺）
	var M_COLLAR := A.metal(Color(0.22, 0.23, 0.25))
	var M_CLAMP := A.paint(Color(0.32, 0.28, 0.22), 0.55, 0.58, {"rust": 0.78, "wear": 0.6})
	var m_core := A.emit(Color(0.95, 0.46, 0.14), 1.35)
	m_core.albedo_color = Color(0.28, 0.10, 0.04)
	var m_void := StandardMaterial3D.new()
	m_void.albedo_color = Color(0.012, 0.012, 0.016)
	m_void.roughness = 1.0
	A.add(raid.world, A.torus(6.15, 6.75, 48), M_COLLAR, c + Vector3(0, 0.28, 0), Vector3.ZERO, Vector3(1, 0.65, 1))
	A.add(raid.world, A.torus(5.1, 5.65, 48), M_COLLAR, c + Vector3(0, -0.15, 0), Vector3.ZERO, Vector3(1, 0.65, 1), false)
	A.add(raid.world, A.cyl(6.2, 0.12, 6.2, 48), m_void, c + Vector3(0, -0.02, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(raid.world, A.torus(4.15, 4.55, 44), M_COLLAR, c + Vector3(0, 0.06, 0), Vector3.ZERO, Vector3(1, 0.55, 1), false)
	A.add(raid.world, A.torus(2.85, 3.22, 36), m_core, c + Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1, 0.35, 1), false)
	for i in 12:
		var a := TAU * i / 12.0
		var p := c + Vector3(sin(a) * 6.25, 0.36, cos(a) * 6.25)
		A.add(raid.world, A.bevel_box(Vector3(0.62, 0.58, 1.18), 0.05, 0.80), M_CLAMP, p, Vector3(-14, -rad_to_deg(a), 0))
		A.add(raid.world, A.cyl(0.09, 0.72, 0.09, 10), A.chrome(), p + Vector3(-sin(a) * 0.42, -0.05, -cos(a) * 0.42), Vector3(76, -rad_to_deg(a), 0))
	# 井口护栏：高细分环形护栏与立柱
	for i in 16:
		var a := TAU * i / 16.0
		if i % 5 == 4:
			continue
		A.add(raid.world, A.cyl(0.06, 1.2, 0.06, 12), A.metal(Color(0.32, 0.31, 0.33)), c + Vector3(sin(a) * 6.8, 0.6, cos(a) * 6.8))
	A.add(raid.world, A.torus(6.78, 6.98, 48), A.metal(Color(0.3, 0.29, 0.31)), c + Vector3(0, 1.2, 0))
	A.add(raid.world, A.torus(6.78, 6.94, 48), A.metal(Color(0.3, 0.29, 0.31)), c + Vector3(0, 0.68, 0), Vector3.ZERO, Vector3(1, 0.5, 1), false)
	# 钻塔：四根收分主材 + 对齐主腿的五层横撑与十字斜撑 + 重工钢构天车滑轮组与悬吊游车
	var M_DER := A.paint(Color(0.36, 0.34, 0.30), 0.6, 0.52, {"rust": 0.8, "wear": 0.5})
	var M_DST := A.metal(Color(0.24, 0.24, 0.25))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var a := c + Vector3(sx * 3.4, 0, sz * 3.4)
			var b := c + Vector3(sx * 1.0, 20.0, sz * 1.0)
			A.add(raid.world, A.tube([a, b], 0.2, 10, 3), M_DER, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		raid.blocks.append(raid._rect_for(c + Vector3(sx * 3.4, 0, 0), Vector3(1.2, 1, 7.2)))
	for k in 5:
		var u0 := float(k + 1) / 6.0
		var u1 := float(k) / 6.0
		var y0 := lerpf(0.8, 19.6, u0)
		var y1 := lerpf(0.8, 19.6, u1)
		var w0 := lerpf(3.3, 1.05, u0)
		var w1 := lerpf(3.3, 1.05, u1)
		for sd in 4:
			var p00 := c + Vector3(-w0, y0, -w0).rotated(Vector3.UP, PI * 0.5 * float(sd))
			var p01 := c + Vector3(w0, y0, -w0).rotated(Vector3.UP, PI * 0.5 * float(sd))
			var p10 := c + Vector3(-w1, y1, -w1).rotated(Vector3.UP, PI * 0.5 * float(sd))
			var p11 := c + Vector3(w1, y1, -w1).rotated(Vector3.UP, PI * 0.5 * float(sd))
			A.add(raid.world, A.tube([p00, p01], 0.075, 6, 2), M_DER, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			A.add(raid.world, A.tube([p10, p01], 0.048, 6, 2), M_DST, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			A.add(raid.world, A.tube([p11, p00], 0.048, 6, 2), M_DST, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(raid.world, A.bevel_box(Vector3(2.55, 0.34, 2.55), 0.04), M_DST, c + Vector3(0, 20.15, 0))
	for sx_cr in [-0.68, 0.68]:
		A.add(raid.world, A.bevel_box(Vector3(0.24, 0.85, 2.35), 0.03), M_DER, c + Vector3(sx_cr, 20.68, 0))
	A.add(raid.world, A.cyl(0.56, 1.15, 0.56, 20), M_DST, c + Vector3(0, 20.72, 0), Vector3(0, 0, 90))
	A.add(raid.world, A.torus(1.22, 1.30, 28), M_DST, c + Vector3(0, 20.75, 0), Vector3.ZERO, Vector3(1, 0.45, 1), false)
	A.add(raid.world, A.cyl(0.035, 1.65, 0.035, 8), M_DST, c + Vector3(0.95, 21.35, 0.95))
	A.add(raid.world, A.cyl(0.11, 0.22, 0.11, 12), A.emit(Color(1.0, 0.32, 0.12), 1.4), c + Vector3(-0.95, 20.92, -0.95), Vector3.ZERO, Vector3.ONE, false)
	A.add(raid.world, A.bevel_box(Vector3(0.95, 1.35, 0.68), 0.06), A.hazard(), c + Vector3(0, 8.8, 0))
	A.add(raid.world, A.cyl(0.14, 19.8, 0.14, 14), M_DST, c + Vector3(0, 10.0, 0))
	for i in 3:
		var a := TAU * i / 3.0
		K.cable(raid, c + Vector3(cos(a) * 2.4, 20.2, sin(a) * 2.4), c + Vector3(cos(a) * 2.6, 0.2, sin(a) * 2.6), 0.0, 0.07, Color(0.22, 0.21, 0.2))
	# 控制台：三组机柜围在平台北侧
	for i in 3:
		var a := -0.5 + i * 0.5
		var p := c + Vector3(sin(a) * 11.2, 0, cos(a) * 11.2)
		A.add(raid.world, A.bevel_box(Vector3(2.6, 1.5, 1.0), 0.05), A.paint(Color(0.24, 0.27, 0.28), 0.4, 0.5, {"wear": 0.5, "rust": 0.5}), p + Vector3(0, 1.1, 0), Vector3(0, -rad_to_deg(a), 0))
		A.add(raid.world, A.bevel_box(Vector3(2.0, 0.6, 0.1), 0.01), A.emit(Color(0.4, 0.9, 0.75), 0.8), p + Vector3(0, 1.5, -0.52), Vector3(-18, -rad_to_deg(a), 0), Vector3.ONE, false)
		raid.blocks.append(raid._rect_for(p, Vector3(2.8, 1, 1.4)))
	# 深层高压结晶矿脉露头：平台外缘玄武矿渣壳与多切面烟晶矿柱（零悬浮发光圆球）
	var M_ORE := A.paint(Color(0.17, 0.14, 0.23), 0.72, 0.26, {"wear": 0.35, "panel_scale": 0.0})
	var m_vein := A.emit(Color(0.56, 0.34, 0.86), 0.95)
	m_vein.albedo_color = Color(0.14, 0.08, 0.22)
	for i in 8:
		var a := TAU * i / 8.0 + 0.3
		var d = r.randf_range(13.0, 15.5)
		var p := c + Vector3(sin(a) * d, 0, cos(a) * d)
		A.add(raid.world, A.rock_mesh((i * 5 + 3) % 12), A.rock_mat(Color(0.19, 0.17, 0.18)), p + Vector3(0, 0.22, 0), Vector3(0, i * 47.0, 0), Vector3(1.65, 0.45, 1.45))
		for k in 3:
			var h = r.randf_range(1.9, 4.8)
			var w = r.randf_range(0.42, 0.82)
			var q_m: Vector3 = p + Vector3(r.randf_range(-0.9, 0.9), h * 0.40, r.randf_range(-0.9, 0.9))
			var rot_m := Vector3(r.randf_range(-14, 14), r.randf() * 360.0, r.randf_range(-14, 14))
			A.add(raid.world, A.cyl(w * 0.28, h, w * 0.82, 6, true), M_ORE, q_m, rot_m, Vector3(1.0, 1.0, 0.78), false)
			if k == 0:
				A.add(raid.world, A.bevel_box(Vector3(0.07, h * 0.48, w * 0.92), 0.01), m_vein, q_m + Vector3(0, -h * 0.08, 0), rot_m, Vector3.ONE, false)
	# 矿渣沉降痕与散落的钻头、管道
	for i in 6:
		var a = r.randf() * TAU
		var d = r.randf_range(8.0, 14.0)
		A.ground_decal(raid.world, A.cloud_tex(), Color(0.08, 0.07, 0.10, 0.55), r.randf_range(3.0, 6.0), c + Vector3(sin(a) * d, 0.03, cos(a) * d))
	for i in 4:
		A.add(raid.world, A.cyl(0.5, 0.9, 0.5, 22), A.paint(Color(0.28, 0.27, 0.26), 0.6, 0.5, {"rust": 0.7}), c + Vector3(r.randf_range(-12, 12), 0.45, r.randf_range(-12, 12)), Vector3(r.randf_range(-20, 20), r.randf() * 360, r.randf_range(-20, 20)))
	K.pipe(raid, c + Vector3(-10.4, 0.9, -6.0), c + Vector3(-10.4, 0.9, 6.0), 0.3, Color(0.3, 0.28, 0.3))
	# 容器与环境叙事
	K.crate(raid, c + Vector3(12.6, 0, 0.6), "safe")
	K.crate(raid, c + Vector3(-1.0, 0, 12.6), "safe")
	K.crate(raid, c + Vector3(-12.4, 0, -1.2), "military")
	K.crate(raid, c + Vector3(8.6, 0, -10.4), "military")
	K.fixed(raid, c + Vector3(10.8, 0, -8.0), ["arch_deep_record", "bug_crystal"], "tool")
	K.fixed(raid, c + Vector3(-9.0, 0, 9.4), ["bug_crystal", "chitin", "chitin"], "tool")
	K.lamp(raid, c + Vector3(14.6, 0, 9.4), Color(1.0, 0.74, 0.42))
	K.lamp(raid, c + Vector3(-14.6, 0, -9.4), Color(0.5, 0.85, 0.9))
	K.guard(raid, c + Vector3(0.0, 0, 11.0), "beetle", 3.0)
	K.guard(raid, c + Vector3(-10.0, 0, 0.0), "beetle", 3.4)
	K.guard(raid, c + Vector3(7.0, 0, 8.0), "spitter", 2.6)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 13.0)
	K.tag_boxes(raid, c, pid)
