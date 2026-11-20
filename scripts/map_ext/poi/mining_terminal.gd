extends RefCounted
## 深井选矿终端：龙门吊跨在窄轨上，皮带输送机斜插进三座筒仓，矿车停在装车线，
## 高架控制室里还亮着几块指示屏，地上堆着虫晶与矿石。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/map_ext/poi_kit.gd")

const STEEL := Color(0.34, 0.34, 0.31)
const ORE := Color(0.2, 0.18, 0.2)


static func build(raid, c: Vector3, pid: String) -> void:
	var r = raid.rng
	K.slab(raid, c, Vector2(26, 20), Color(0.36, 0.35, 0.33))
	# 龙门吊：地面轨道 + 两副 A 形支腿 + 主梁
	for sx in [-9.0, 9.0]:
		A.add(raid.world, A.bevel_box(Vector3(0.5, 0.22, 17.0), 0.04), A.metal(Color(0.4, 0.4, 0.38)), c + Vector3(sx, 0.12, 0))
		for sz in [-6.0, 6.0]:
			var leg := c + Vector3(sx, 0, sz)
			for k in 2:
				var lean := -0.55 if k == 0 else 0.55
				A.add(raid.world, A.tube([leg + Vector3(lean * 2.6, 0, 0), leg + Vector3(lean * 0.4, 12.0, 0)], 0.18, 10, 2), A.metal(STEEL), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			A.add(raid.world, A.bevel_box(Vector3(0.7, 0.6, 1.2), 0.05), A.paint(Color(0.36, 0.37, 0.33), 0.4, 0.6, {"rust": 0.7}), leg + Vector3(0, 0.3, 0))
			raid.blocks.append(raid._rect_for(leg, Vector3(2.4, 1, 2.4)))
	A.add(raid.world, A.bevel_box(Vector3(19.4, 0.8, 1.0), 0.06), A.paint(Color(0.4, 0.4, 0.36), 0.5, 0.55, {"rust": 0.7, "wear": 0.5}), c + Vector3(0, 12.4, -6.0))
	A.add(raid.world, A.bevel_box(Vector3(19.4, 0.8, 1.0), 0.06), A.paint(Color(0.4, 0.4, 0.36), 0.5, 0.55, {"rust": 0.7, "wear": 0.5}), c + Vector3(0, 12.4, 6.0))
	for i in 9:
		A.add(raid.world, A.bevel_box(Vector3(0.24, 0.24, 12.4), 0.02), A.metal(STEEL), c + Vector3(-8.8 + i * 2.2, 12.9, 0), Vector3.ZERO, Vector3.ONE, false)
	# 吊车小车与吊钩
	var trolley := c + Vector3(2.0, 11.6, 0)
	A.add(raid.world, A.bevel_box(Vector3(3.0, 1.0, 3.0), 0.06), A.paint(Color(0.5, 0.42, 0.2), 0.4, 0.6, {"wear": 0.6, "rust": 0.7}), trolley)
	K.cable(raid, trolley + Vector3(0, -0.4, 0), trolley + Vector3(0, -7.0, 0), 0.0, 0.06, Color(0.25, 0.25, 0.24))
	A.add(raid.world, A.bevel_box(Vector3(1.6, 0.8, 0.5), 0.08), A.paint(Color(0.45, 0.36, 0.18), 0.5, 0.6, {"rust": 0.8}), trolley + Vector3(0, -7.4, 0))
	# 皮带输送机栈桥：两侧倾斜槽钢主梁 + 连续黑橡胶矿石皮带 + 下置托辊组 + 上半段波纹防尘罩与卸料漏斗
	var belt := Node3D.new()
	raid.world.add_child(belt)
	belt.position = c + Vector3(-4.6, 0, 2.0)
	belt.rotation_degrees = Vector3(16, -14, 0)
	var M_BELT_FR := A.paint(Color(0.28, 0.27, 0.24), 0.52, 0.62, {"rust": 0.78, "wear": 0.55})
	var M_HOOD := A.paint(Color(0.36, 0.38, 0.35), 0.45, 0.58, {"rust": 0.65, "wear": 0.5, "panel_scale": 1.4})
	A.add(belt, A.bevel_box(Vector3(2.42, 0.14, 15.8), 0.02), A.rubber(), Vector3(0, 2.52, 0))
	for sx_b in [-1.32, 1.32]:
		A.add(belt, A.bevel_box(Vector3(0.22, 0.52, 16.2), 0.03), M_BELT_FR, Vector3(sx_b, 2.42, 0))
	A.add(belt, A.bevel_box(Vector3(0.55, 0.08, 16.0), 0.01), A.metal(STEEL), Vector3(1.72, 2.50, 0), Vector3.ZERO, Vector3.ONE, false)
	for k in 9:
		A.add(belt, A.cyl(0.09, 2.58, 0.09, 12), A.metal(Color(0.22, 0.22, 0.23)), Vector3(0, 2.34, -7.2 + k * 1.8), Vector3(0, 0, 90), Vector3.ONE, false)
	A.add(belt, A.cyl(1.38, 6.8, 1.38, 16), M_HOOD, Vector3(0, 2.68, -4.4), Vector3(90, 0, 0), Vector3(1.0, 1.0, 0.62))
	A.add(belt, A.bevel_box(Vector3(2.86, 1.15, 1.45), 0.05), M_BELT_FR, Vector3(0, 2.55, -8.05))
	for sx in [-1.32, 1.32]:
		for k in 4:
			var zl := -6.0 + k * 4.0
			var lh := maxf(0.6, 2.35 * cos(deg_to_rad(16.0)) - zl * sin(deg_to_rad(16.0)))
			var lp := belt.position + Vector3(sx, 0, zl * cos(deg_to_rad(16.0))).rotated(Vector3.UP, deg_to_rad(-14.0))
			A.add(raid.world, A.cyl(0.12, lh, 0.12, 12), A.metal(STEEL), lp + Vector3(0, lh * 0.5, 0))
	# 三座高精度选矿筒仓：四根立柱 + 锥底漏斗 + 圆筒仓身 + 锥顶集尘帽 + 仓顶贯通连廊
	var M_CAP := A.paint(Color(0.35, 0.35, 0.32), 0.4, 0.6, {"rust": 0.7})
	for i in 3:
		var p := c + Vector3(-12.0 + i * 4.6, 0, -7.6)
		for ka in 4:
			var ca := PI * 0.25 + PI * 0.5 * ka
			A.add(raid.world, A.cyl(0.22, 3.2, 0.26, 16), A.metal(STEEL), p + Vector3(cos(ca) * 1.95, 1.6, sin(ca) * 1.95))
		A.add(raid.world, A.cyl(2.42, 3.0, 0.72, 40), A.concrete(Color(0.46, 0.44, 0.4), false), p + Vector3(0, 1.5, 0))
		K.tower(raid, p + Vector3(0, 3.0, 0), 2.4, 8.0, 2.4, Color(0.5, 0.48, 0.43))
		A.add(raid.world, A.cyl(0.85, 0.9, 2.52, 40), M_CAP, p + Vector3(0, 11.4, 0))
		A.add(raid.world, A.cyl(0.55, 0.65, 0.6, 28), A.metal(STEEL), p + Vector3(0, 12.1, 0))
	A.add(raid.world, A.bevel_box(Vector3(10.8, 0.3, 1.2), 0.03), A.metal(STEEL), c + Vector3(-7.4, 11.3, -7.6))
	# 窄轨与矿车
	for sx in [-2.6, 2.6]:
		A.add(raid.world, A.bevel_box(Vector3(0.12, 0.16, 18.0), 0.02), A.metal(Color(0.42, 0.4, 0.36)), c + Vector3(sx, 0.16, 0.0), Vector3.ZERO, Vector3.ONE, false)
	for i in 4:
		A.add(raid.world, A.bevel_box(Vector3(5.6, 0.1, 0.5), 0.01), A.paint(Color(0.22, 0.19, 0.16), 0.0, 0.9), c + Vector3(0, 0.1, -7.0 + i * 4.6), Vector3.ZERO, Vector3.ONE, false)
	for k in 3:
		var p := c + Vector3(0, 0, -5.0 + k * 5.6)
		var cart := Node3D.new()
		raid.world.add_child(cart)
		cart.position = p
		cart.rotation_degrees.y = r.randf_range(-4, 4)
		A.add(cart, A.bevel_box(Vector3(2.4, 1.4, 3.2), 0.06, 0.82), A.paint(Color(0.42, 0.35, 0.24), 0.5, 0.6, {"rust": 0.8, "wear": 0.6}), Vector3(0, 1.0, 0))
		for rz_c in [-1.0, 0.0, 1.0]:
			A.add(cart, A.bevel_box(Vector3(2.50, 1.28, 0.10), 0.02), A.metal(STEEL), Vector3(0, 1.02, rz_c))
		A.add(cart, A.bevel_box(Vector3(2.0, 0.2, 2.6), 0.02), A.paint(ORE, 0.35, 0.82), Vector3(0, 1.66, 0))
		for ok in 3:
			A.add(cart, A.rock_mesh((k * 3 + ok) % 12), A.rock_mat(Color(0.22, 0.20, 0.22)), Vector3(-0.45 + ok * 0.45, 1.82, -0.55 + (ok % 2) * 0.95), Vector3(0, ok * 68.0, 0), Vector3(0.55, 0.32, 0.52))
		for sx in [-0.9, 0.9]:
			for sz in [-1.2, 1.2]:
				A.add(cart, A.cyl(0.34, 0.16, 0.34, 20), A.metal(Color(0.25, 0.25, 0.24)), Vector3(sx, 0.34, sz), Vector3(0, 0, 90))
		raid.blocks.append(raid._rect_for(p, Vector3(2.8, 1, 3.6)))
		K.blocker(raid, p, Vector3(2.4, 1.4, 3.2), cart.rotation_degrees.y)
	# 矿石堆与深层结晶矿脉采样点（暗金属多棱矿柱 + 勘探取芯钢标桩，零悬浮发光球）
	for i in 4:
		var p = c + Vector3(r.randf_range(-10, 10), 0, r.randf_range(2, 8))
		A.add(raid.world, A.cyl(0.3, 1.4, 1.8, 22), A.paint(Color(0.26, 0.24, 0.22), 0.2, 0.95, {"wear": 0.4, "dust": 0.7}), p + Vector3(0, 0.7, 0))
	var M_SEAM := A.paint(Color(0.18, 0.14, 0.24), 0.70, 0.28, {"wear": 0.35, "panel_scale": 0.0})
	var m_vein := A.emit(Color(0.55, 0.34, 0.85), 0.95)
	m_vein.albedo_color = Color(0.14, 0.08, 0.22)
	for i in 3:
		var p = c + Vector3(r.randf_range(-8, 8), 0, r.randf_range(-8, -2))
		A.add(raid.world, A.rock_mesh((i * 4 + 2) % 12), A.rock_mat(Color(0.20, 0.18, 0.19)), p + Vector3(0, 0.18, 0), Vector3(0, i * 74.0, 0), Vector3(1.15, 0.38, 1.05))
		for mk in 2:
			var mh := 1.25 + mk * 0.55
			var mpos: Vector3 = p + Vector3(-0.22 + mk * 0.44, mh * 0.42, (mk - 0.5) * 0.25)
			var mrot := Vector3(r.randf_range(-12, 12), r.randf() * 360.0, r.randf_range(-12, 12))
			A.add(raid.world, A.cyl(0.10, mh, 0.32, 6, true), M_SEAM, mpos, mrot, Vector3.ONE, false)
			A.add(raid.world, A.bevel_box(Vector3(0.05, mh * 0.45, 0.36), 0.008), m_vein, mpos, mrot, Vector3.ONE, false)
		A.add(raid.world, A.cyl(0.035, 1.15, 0.035, 8), A.metal(STEEL), p + Vector3(0.68, 0.58, 0.15))
		A.add(raid.world, A.bevel_box(Vector3(0.26, 0.16, 0.04), 0.008), A.hazard(), p + Vector3(0.68, 1.08, 0.15))
	# 高架控制室：四根立柱 + 钢格栅检修走道护栏 + 独立 Node3D 控制舱 + 空调外机 + 楼梯
	var cp := c + Vector3(8.4, 0, 6.0)
	for sx in [-1.8, 1.8]:
		for sz in [-1.6, 1.6]:
			A.add(raid.world, A.cyl(0.16, 4.3, 0.16, 16), A.metal(STEEL), cp + Vector3(sx, 2.15, sz))
	A.add(raid.world, A.tube([cp + Vector3(-1.8, 0.3, -1.6), cp + Vector3(1.8, 4.1, -1.6)], 0.05, 6, 2), A.metal(STEEL), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(raid.world, A.tube([cp + Vector3(1.8, 0.3, -1.6), cp + Vector3(-1.8, 4.1, -1.6)], 0.05, 6, 2), A.metal(STEEL), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	raid.blocks.append(raid._rect_for(cp, Vector3(4.0, 1, 3.6)))
	var cab := Node3D.new()
	raid.world.add_child(cab)
	cab.position = cp + Vector3(0, 5.5, 0)
	var M_DARK := A.metal(Color(0.18, 0.19, 0.20))
	A.add(cab, A.bevel_box(Vector3(4.8, 0.16, 4.4), 0.03), M_DARK, Vector3(0, -1.34, 0.25))
	A.add(cab, A.bevel_box(Vector3(4.2, 2.6, 3.6), 0.08), A.paint(Color(0.44, 0.42, 0.36), 0.35, 0.6, {"wear": 0.5, "rust": 0.5}), Vector3.ZERO)
	A.add(cab, A.bevel_box(Vector3(3.2, 1.1, 0.1), 0.01), A.glass(Color(0.26, 0.48, 0.46)), Vector3(0, 0.3, -1.82), Vector3.ZERO, Vector3.ONE, false)
	for mx_c in [-1.05, 0.0, 1.05]:
		A.add(cab, A.bevel_box(Vector3(0.06, 1.14, 0.12), 0.01), M_DARK, Vector3(mx_c, 0.3, -1.82), Vector3.ZERO, Vector3.ONE, false)
	A.add(cab, A.bevel_box(Vector3(4.55, 0.22, 4.05), 0.03), A.metal(STEEL), Vector3(0, 1.4, 0))
	A.add(cab, A.bevel_box(Vector3(0.95, 0.72, 0.42), 0.03), A.paint(Color(0.48, 0.50, 0.47), 0.4, 0.6, {"rust": 0.5}), Vector3(2.28, 0.15, 0.4))
	K.steps(raid, cp + Vector3(0.0, 0, 5.6), 12, 0.35, 0.34, 1.4, 180.0)
	# 容器与环境叙事
	K.crate(raid, c + Vector3(10.8, 0, -2.0), "safe")
	K.crate(raid, c + Vector3(5.6, 0, -8.2), "tool")
	K.crate(raid, c + Vector3(4.0, 0, -8.4), "tool")
	K.crate(raid, c + Vector3(-8.4, 0, 8.2), "military")
	K.fixed(raid, c + Vector3(-7.0, 0, 7.4), ["bug_crystal", "chitin"], "tool")
	K.fixed(raid, c + Vector3(9.4, 0, 4.4), ["arch_shift_log", "circuit"], "tool")
	K.lamp(raid, c + Vector3(-12.6, 0, 8.6), Color(1.0, 0.74, 0.42))
	K.lamp(raid, c + Vector3(12.4, 0, -8.6), Color(0.7, 0.86, 1.0))
	K.rubble(raid, c + Vector3(-2.0, 0, 9.0), 1.6, Color(0.3, 0.29, 0.27))
	K.guard(raid, c + Vector3(0.0, 0, 4.0), "beetle", 3.0)
	K.guard(raid, c + Vector3(-8.0, 0, -2.0), "beetle", 3.2)
	K.guard(raid, c + Vector3(7.0, 0, 0.0), "ling", 2.2)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 12.0)
	K.tag_boxes(raid, c, pid)
