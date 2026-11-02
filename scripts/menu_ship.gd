extends RefCounted
## 主菜单场景：飞空艇"潜渊号"舰桥侧舷观景窗，向外望出——黄昏的云海与云缝下依稀可见的废土。
## 只建窗户周围一小段舱室：外倾的三联观景窗（I 型竖梃 + 横档 + 铆接窗框 + 收起的装甲百叶）、
## 窗台仪表台、肋骨梁、顶部管线、吊灯；窗外：右舷发动机吊舱（螺旋桨旋转）、近景云团、远处护航艇。
## build(root) 返回动画需要的节点引用。
const A = preload("res://scripts/art.gd")
const HS = preload("res://scripts/hs.gd")

const WIN_C := Vector3(1.0, 0.0, 0.0)     # 观景窗中心（x）
const PANES := [1.05, 2.5, 1.05]     # 中央整块大玻璃，两侧窄窗
const PANE_H := 2.55
const SILL_Y := 0.8
const LEAN := -14.0                         # 窗墙上沿外倾


static func _hull() -> ShaderMaterial:
	return A.paint(Color(0.2, 0.215, 0.235), 0.3, 0.5, {"panel_scale": 0.55, "wear": 0.45, "dust": 0.2, "scratches": 0.35, "rust": 0.05})


static func _hull2() -> ShaderMaterial:
	return A.paint(Color(0.29, 0.3, 0.32), 0.35, 0.45, {"panel_scale": 0.0, "wear": 0.5, "scratches": 0.4, "rust": 0.04})


static func _frame() -> ShaderMaterial:
	return A.paint(Color(0.12, 0.125, 0.135), 0.4, 0.42, {"panel_scale": 0.0, "wear": 0.6, "scratches": 0.5, "bare_metal": Color(0.5, 0.5, 0.52)})


static func _accent() -> ShaderMaterial:
	return A.paint(Color(0.96, 0.6, 0.1), 0.2, 0.5, {"panel_scale": 0.0, "wear": 0.55, "scratches": 0.4})


static func _brass() -> ShaderMaterial:
	return A.paint(Color(0.72, 0.52, 0.24), 0.9, 0.32, {"panel_scale": 0.0, "wear": 0.2, "scratches": 0.3, "grime": 0.3})


static func build(root: Node3D) -> Dictionary:
	var refs := {}
	var HULL := _hull()
	var HULL2 := _hull2()
	var FR := _frame()
	var ACC := _accent()
	var BR := _brass()
	var DARK := A.paint(Color(0.05, 0.05, 0.055), 0.3, 0.7, {"panel_scale": 0.0})

	# ============================================================ 窗墙（外倾）
	var wall := Node3D.new()
	wall.name = "WindowWall"
	wall.position = Vector3(0, SILL_Y, 0)
	wall.rotation_degrees.x = LEAN
	root.add_child(wall)
	var W: float = PANES[0] + PANES[1] + PANES[2] + 0.16 * 2.0
	var x0 := WIN_C.x - W * 0.5
	var x1 := WIN_C.x + W * 0.5
	# 窗框外圈（厚、深、倒角大）
	A.add(wall, HS.cbox(Vector3(W + 0.56, 0.34, 0.46), 0.06), FR, Vector3(WIN_C.x, PANE_H + 0.17, 0.0))
	A.add(wall, HS.cbox(Vector3(W + 0.56, 0.26, 0.5), 0.06), FR, Vector3(WIN_C.x, -0.13, 0.02))
	for sx in [x0 - 0.14, x1 + 0.14]:
		A.add(wall, HS.cbox(Vector3(0.28, PANE_H + 0.6, 0.46), 0.06), FR, Vector3(sx, PANE_H * 0.5, 0.0))
	# 内侧压条（亮一级的金属，形成第二层台阶）
	A.add(wall, HS.cbox(Vector3(W + 0.1, 0.08, 0.12), 0.02), HULL2, Vector3(WIN_C.x, PANE_H - 0.02, 0.2))
	A.add(wall, HS.cbox(Vector3(W + 0.1, 0.08, 0.12), 0.02), HULL2, Vector3(WIN_C.x, 0.02, 0.24))
	# I 型竖梃 ×2
	for i in 2:
		var mx: float = x0 + (PANES[0] if i == 0 else PANES[0] + PANES[1]) + 0.16 * i + 0.08
		A.add(wall, HS.cbox(Vector3(0.07, PANE_H, 0.34), 0.015), FR, Vector3(mx, PANE_H * 0.5, 0.0))
		for fz in [-0.15, 0.15]:
			A.add(wall, HS.cbox(Vector3(0.18, PANE_H, 0.05), 0.012), FR, Vector3(mx, PANE_H * 0.5, fz))
		A.rivets(wall, Vector3(mx, 0.1, 0.18), Vector3(mx, PANE_H - 0.1, 0.18), 14, 0.016, Vector3(90, 0, 0))
		# 竖梃根部检修牌
		A.add(wall, HS.cbox(Vector3(0.14, 0.05, 0.012), 0.004), ACC, Vector3(mx, 0.38, 0.182))
	# 横档（上部 28% 处）
	var ty := PANE_H * 0.86
	A.add(wall, HS.cbox(Vector3(W, 0.08, 0.26), 0.02), FR, Vector3(WIN_C.x, ty, -0.02))
	A.rivets(wall, Vector3(x0 + 0.1, ty, 0.12), Vector3(x1 - 0.1, ty, 0.12), 22, 0.013, Vector3(90, 0, 0))
	# 外框铆钉
	A.rivets(wall, Vector3(x0 - 0.14, 0.0, 0.235), Vector3(x0 - 0.14, PANE_H, 0.235), 16, 0.02, Vector3(90, 0, 0))
	A.rivets(wall, Vector3(x1 + 0.14, 0.0, 0.235), Vector3(x1 + 0.14, PANE_H, 0.235), 16, 0.02, Vector3(90, 0, 0))
	A.rivets(wall, Vector3(x0, PANE_H + 0.17, 0.235), Vector3(x1, PANE_H + 0.17, 0.235), 26, 0.02, Vector3(90, 0, 0))
	# 玻璃
	var gsh := load("res://shaders/menu_glass.gdshader")
	for i in 3:
		var pw: float = PANES[i]
		var cx: float = x0 + 0.16 * i + pw * 0.5 + (0.0 if i == 0 else PANES[0]) + (PANES[1] if i == 2 else 0.0)
		for part in 2:
			var h0 := 0.0 if part == 0 else ty + 0.04
			var h1 := ty - 0.04 if part == 0 else PANE_H
			var q := QuadMesh.new()
			q.size = Vector2(pw, h1 - h0)
			var gm := ShaderMaterial.new()
			gm.shader = gsh
			gm.set_shader_parameter("pane_size", q.size)
			gm.set_shader_parameter("seed", float(i * 2 + part) * 3.7)
			gm.set_shader_parameter("sun_dir", Vector3(0.5, 0.24, -1.0).normalized())
			var g := A.add(wall, q, gm, Vector3(cx, (h0 + h1) * 0.5, -0.06), Vector3.ZERO, Vector3.ONE, false)
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 收起的装甲百叶（窗上方，黄黑警示边）
	var sh := Node3D.new()
	sh.position = Vector3(WIN_C.x, PANE_H + 0.55, 0.12)
	wall.add_child(sh)
	A.add(sh, HS.cbox(Vector3(W + 0.4, 0.42, 0.34), 0.08), HULL2, Vector3.ZERO)
	for k in 5:
		A.add(sh, HS.cbox(Vector3(W + 0.42, 0.025, 0.36), 0.008), FR, Vector3(0, -0.18 + k * 0.09, 0.0))
	A.add(sh, HS.cbox(Vector3(W + 0.44, 0.07, 0.04), 0.01), A.hazard(), Vector3(0, -0.2, 0.17))
	for sx in [-1.0, 1.0]:
		A.add(sh, A.cyl(0.07, 0.2, 0.07, 14), DARK, Vector3(sx * (W * 0.5 + 0.32), 0.0, 0.0), Vector3(0, 0, 90))
		A.add(sh, A.cyl(0.045, 0.22, 0.045, 12), A.chrome(), Vector3(sx * (W * 0.5 + 0.32), 0.0, 0.0), Vector3(0, 0, 90))
	A.stencil(sh, "ARMOR SHUTTER  ·  遮蔽装甲  3-A", Vector3(-W * 0.25, 0.05, 0.172), Vector3.ZERO, 0.0035, Color(0.9, 0.86, 0.75, 0.7))
	# 窗墙其余部分：左右与上方墙板（分格 + 铆钉 + 通风格栅）
	var wall_l := -3.2
	var wall_r := 4.8
	var top := PANE_H + 1.4
	A.add(wall, HS.cbox(Vector3((x0 - 0.28) - wall_l, top + 0.95, 0.2), 0.02), HULL, Vector3((wall_l + x0 - 0.28) * 0.5, top * 0.5 - 0.47, -0.12))
	A.add(wall, HS.cbox(Vector3(wall_r - (x1 + 0.28), top + 0.95, 0.2), 0.02), HULL, Vector3((wall_r + x1 + 0.28) * 0.5, top * 0.5 - 0.47, -0.12))
	A.add(wall, HS.cbox(Vector3(W + 0.6, top - PANE_H - 0.34, 0.2), 0.02), HULL, Vector3(WIN_C.x, (top + PANE_H + 0.34) * 0.5, -0.12))
	A.vent(wall, Vector3(0.9, 0.5, 0.05), Vector3(x1 + 1.05, 2.1, 0.0), Vector3(0, 180, 0), 7)
	A.vent(wall, Vector3(0.6, 0.35, 0.05), Vector3(x0 - 1.0, 0.45, 0.0), Vector3(0, 180, 0), 5)
	A.stencil(wall, "OBS-2  左舷观测窗", Vector3(x1 + 1.05, 2.55, 0.03), Vector3.ZERO, 0.004, Color(0.95, 0.62, 0.15, 0.75))

	# ============================================================ 窗台仪表台
	var sill := Node3D.new()
	sill.position = Vector3(0, SILL_Y, 0)
	root.add_child(sill)
	var sw := W + 0.9
	A.add(sill, HS.cbox(Vector3(sw, 0.09, 0.62), 0.03), HULL2, Vector3(WIN_C.x, -0.02, 0.36))
	A.add(sill, HS.cbox(Vector3(sw, 0.05, 0.05), 0.015), ACC, Vector3(WIN_C.x, 0.0, 0.67))
	A.add(sill, HS.cbox(Vector3(sw - 0.1, SILL_Y - 0.1, 0.5), 0.03), HULL, Vector3(WIN_C.x, -SILL_Y * 0.5 - 0.02, 0.32))
	for k in 6:
		A.add(sill, HS.cbox(Vector3(0.012, SILL_Y - 0.2, 0.02), 0.003), FR, Vector3(x0 - 0.3 + k * (sw / 5.0 - 0.02), -SILL_Y * 0.5, 0.575))
	# 黄铜扶手
	var rail_pts := [Vector3(x0 - 0.35, 0.18, 0.78), Vector3(x1 + 0.35, 0.18, 0.78)]
	A.add(sill, A.tube(rail_pts, 0.028, 10, 2), BR, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, true)
	for i in 5:
		var rx := lerpf(x0 - 0.25, x1 + 0.25, i / 4.0)
		A.add(sill, A.cyl(0.018, 0.2, 0.018, 8), BR, Vector3(rx, 0.08, 0.72), Vector3(-30, 0, 0))
	# 仪表：三联圆表（琥珀色表盘发光）
	var gauges := Node3D.new()
	gauges.position = Vector3(WIN_C.x - 1.25, 0.12, 0.42)
	gauges.rotation_degrees.x = -55
	sill.add_child(gauges)
	A.add(gauges, HS.cbox(Vector3(0.78, 0.3, 0.08), 0.02), FR, Vector3.ZERO)
	for g in 3:
		var gx := -0.25 + g * 0.25
		A.add(gauges, A.cyl(0.095, 0.05, 0.095, 24), BR, Vector3(gx, 0.0, 0.04), Vector3(90, 0, 0))
		A.add(gauges, A.cyl(0.08, 0.01, 0.08, 24), A.emit(Color(1.0, 0.62, 0.22), 0.9), Vector3(gx, 0.0, 0.07), Vector3(90, 0, 0), Vector3.ONE, false)
		var nd := A.add(gauges, HS.cbox(Vector3(0.008, 0.07, 0.004), 0.001), DARK, Vector3(gx, 0.02, 0.078), Vector3(0, 0, -40.0 + g * 55.0), Vector3.ONE, false)
		nd.name = "Needle%d" % g
	refs["needles"] = [gauges.get_node_or_null("Needle0"), gauges.get_node_or_null("Needle1"), gauges.get_node_or_null("Needle2")]
	# 车钟式传令拉杆
	var tel := Node3D.new()
	tel.position = Vector3(x1 - 0.2, 0.05, 0.4)
	sill.add_child(tel)
	A.add(tel, A.cyl(0.13, 0.32, 0.15, 20), BR, Vector3(0, 0.16, 0))
	A.add(tel, A.cyl(0.115, 0.03, 0.115, 20), A.emit(Color(0.95, 0.85, 0.65), 0.5), Vector3(0, 0.33, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(tel, HS.cbox(Vector3(0.03, 0.34, 0.03), 0.008), A.chrome(), Vector3(0.05, 0.45, 0.0), Vector3(0, 0, -18))
	A.add(tel, A.sphere(0.04, -1, 10), ACC, Vector3(0.1, 0.62, 0.0))
	# 航海日志 + 马克杯 + 望远镜
	A.add(sill, HS.cbox(Vector3(0.34, 0.035, 0.24), 0.01), A.paint(Color(0.32, 0.16, 0.1), 0.0, 0.8, {"panel_scale": 0.0, "wear": 0.6}), Vector3(WIN_C.x + 0.15, 0.045, 0.42), Vector3(0, 12, 0))
	A.add(sill, HS.cbox(Vector3(0.3, 0.008, 0.22), 0.003), A.paint(Color(0.85, 0.8, 0.68), 0.0, 0.9, {"panel_scale": 0.0}), Vector3(WIN_C.x + 0.16, 0.066, 0.42), Vector3(0, 12, 0))
	A.add(sill, A.cyl(0.05, 0.11, 0.045, 16), A.paint(Color(0.2, 0.22, 0.2), 0.1, 0.6, {"panel_scale": 0.0, "wear": 0.5}), Vector3(WIN_C.x + 0.62, 0.085, 0.5))
	A.add(sill, A.torus(0.02, 0.035, 12), A.paint(Color(0.2, 0.22, 0.2), 0.1, 0.6, {"panel_scale": 0.0}), Vector3(WIN_C.x + 0.68, 0.09, 0.5), Vector3(90, 0, 0))
	for bx in [-0.045, 0.045]:
		A.add(sill, A.cyl(0.032, 0.2, 0.028, 14), DARK, Vector3(WIN_C.x + 0.95 + bx, 0.06, 0.4), Vector3(90, 25, 0))
	# ============================================================ 舱室：地板、侧墙、肋骨梁、顶部
	var floor_m := A.paint(Color(0.16, 0.16, 0.165), 0.3, 0.6, {"panel_scale": 1.2, "wear": 0.6, "scratches": 0.6, "dust": 0.3})
	A.add(root, HS.cbox(Vector3(8.4, 0.12, 7.0), 0.02), floor_m, Vector3(0.8, -0.06, 3.3))
	A.add(root, HS.cbox(Vector3(W + 0.9, 0.02, 0.9), 0.005), DARK, Vector3(WIN_C.x, 0.005, 1.15))
	for k in 18:
		A.add(root, HS.cbox(Vector3(0.02, 0.025, 0.86), 0.004), FR, Vector3(x0 - 0.4 + k * (W + 0.8) / 17.0, 0.02, 1.15), Vector3.ZERO, Vector3.ONE, false)
	A.add(root, HS.cbox(Vector3(W + 0.9, 0.03, 0.06), 0.008), A.hazard(), Vector3(WIN_C.x, 0.02, 1.62))
	# 肋骨梁：侧墙立柱 → 弯折 → 顶梁（截面 I 型，厚重）
	var ceil_y := 4.4
	for zi in [0.35, 2.6, 4.9]:
		for sx in [-3.1, 4.7]:
			var dir := 1.0 if sx < 0 else -1.0
			A.add(root, HS.cbox(Vector3(0.34, ceil_y - 0.6, 0.2), 0.04), FR, Vector3(sx, (ceil_y - 0.6) * 0.5, zi))
			A.add(root, HS.cbox(Vector3(0.12, ceil_y - 0.6, 0.36), 0.02), FR, Vector3(sx, (ceil_y - 0.6) * 0.5, zi))
			A.add(root, HS.cbox(Vector3(0.95, 0.34, 0.2), 0.04), FR, Vector3(sx + dir * 0.33, ceil_y - 0.45, zi), Vector3(0, 0, dir * 42.0))
		A.add(root, HS.cbox(Vector3(6.4, 0.34, 0.2), 0.04), FR, Vector3(0.8, ceil_y - 0.12, zi))
		A.add(root, HS.cbox(Vector3(6.4, 0.12, 0.36), 0.02), FR, Vector3(0.8, ceil_y - 0.12, zi))
	# 顶板与侧墙板
	A.add(root, HS.cbox(Vector3(8.4, 0.1, 8.0), 0.02), HULL, Vector3(0.8, ceil_y + 0.1, 2.2))
	for sx in [-3.3, 4.9]:
		A.add(root, HS.cbox(Vector3(0.1, ceil_y + 0.4, 8.0), 0.02), HULL, Vector3(sx, ceil_y * 0.5, 2.2))
	# 顶部管线：沿舷向（x）走三根，带法兰与阀门手轮
	var pipe_m := A.paint(Color(0.3, 0.3, 0.29), 0.7, 0.4, {"panel_scale": 0.0, "wear": 0.3, "rust": 0.15})
	var pipe2 := A.paint(Color(0.55, 0.22, 0.1), 0.3, 0.55, {"panel_scale": 0.0, "wear": 0.4, "rust": 0.2})
	for p in [[0.95, 0.09, pipe_m], [1.25, 0.06, pipe2], [1.5, 0.11, pipe_m]]:
		var pz: float = p[0]
		var pr: float = p[1]
		A.add(root, A.tube([Vector3(-3.0, ceil_y - 0.42, pz), Vector3(4.6, ceil_y - 0.42, pz)], pr, 12, 2), p[2], Vector3.ZERO, Vector3.ZERO, Vector3.ONE, true)
		for fx in [-1.8, 0.2, 2.2, 3.9]:
			A.add(root, A.cyl(pr + 0.03, 0.06, pr + 0.03, 14), FR, Vector3(fx + pz * 0.3, ceil_y - 0.42, pz), Vector3(0, 0, 90))
	A.add(root, A.torus(0.1, 0.13, 20), ACC, Vector3(3.0, ceil_y - 0.58, 1.25), Vector3.ZERO)
	A.add(root, A.cyl(0.02, 0.14, 0.02, 8), FR, Vector3(3.0, ceil_y - 0.52, 1.25))
	# 下垂线缆
	A.hose(root, Vector3(-2.9, ceil_y - 0.3, 2.2), Vector3(0.4, ceil_y - 0.28, 2.3), Vector3(0, -0.45, 0), 0.03, DARK)
	A.hose(root, Vector3(-2.9, ceil_y - 0.36, 2.35), Vector3(-0.8, ceil_y - 0.3, 2.45), Vector3(0, -0.3, 0), 0.022, A.paint(Color(0.7, 0.4, 0.08), 0.0, 0.7, {"panel_scale": 0.0}))
	# 吊灯（笼式，暖光，随船体轻摆）
	var lamp := Node3D.new()
	lamp.position = Vector3(-0.2, ceil_y - 0.2, 2.3)
	root.add_child(lamp)
	A.add(lamp, A.cyl(0.012, 0.6, 0.012, 6), DARK, Vector3(0, -0.3, 0))
	A.add(lamp, A.cyl(0.07, 0.12, 0.2, 16), FR, Vector3(0, -0.65, 0))
	A.add(lamp, A.sphere(0.07, -1, 12), A.emit(Color(1.0, 0.72, 0.4), 8.0), Vector3(0, -0.76, 0), Vector3.ZERO, Vector3.ONE, false)
	for k in 4:
		var a := k * PI * 0.5
		A.add(lamp, A.cyl(0.008, 0.2, 0.008, 4), FR, Vector3(cos(a) * 0.12, -0.78, sin(a) * 0.12))
	var ll := OmniLight3D.new()
	ll.light_color = Color(1.0, 0.68, 0.38)
	ll.light_energy = 2.2
	ll.omni_range = 7.5
	ll.shadow_enabled = false
	ll.position = Vector3(0, -0.8, 0)
	lamp.add_child(ll)
	refs["lamp"] = lamp
	# 窗口漫射补光（模拟窗外天光照进舱内）
	var wl := SpotLight3D.new()
	wl.light_color = Color(1.0, 0.78, 0.58)
	wl.light_energy = 4.0
	wl.spot_range = 9.0
	wl.spot_angle = 60.0
	wl.position = Vector3(WIN_C.x, 2.6, -0.3)
	wl.rotation_degrees = Vector3(-35, 0, 0)
	wl.rotate_y(PI)
	root.add_child(wl)
	wl.look_at_from_position(Vector3(WIN_C.x, 2.8, -0.2), Vector3(WIN_C.x - 0.6, 0.0, 4.0))
	# 窗框两侧壁灯（笼罩 + 暖光）
	for sx in [x0 - 0.62, x1 + 0.62]:
		var sc := Node3D.new()
		sc.position = Vector3(sx, SILL_Y + 1.75, 0.35)
		root.add_child(sc)
		A.add(sc, HS.cbox(Vector3(0.22, 0.32, 0.08), 0.02), FR, Vector3(0, 0, -0.1))
		A.add(sc, A.cyl(0.09, 0.2, 0.09, 14), A.emit(Color(1.0, 0.75, 0.45), 6.0), Vector3(0, 0, 0.06), Vector3.ZERO, Vector3.ONE, false)
		for k in 3:
			A.add(sc, HS.cbox(Vector3(0.012, 0.22, 0.012), 0.002), FR, Vector3(-0.09 + k * 0.09, 0, 0.16), Vector3.ZERO, Vector3.ONE, false)
		var so := OmniLight3D.new()
		so.light_color = Color(1.0, 0.7, 0.42)
		so.light_energy = 1.4
		so.omni_range = 4.5
		so.position = Vector3(0, 0, 0.3)
		sc.add_child(so)
	# 扶手下的琥珀色灯带
	A.add(sill, HS.cbox(Vector3(sw - 0.3, 0.015, 0.02), 0.003), A.emit(Color(1.0, 0.6, 0.18), 2.5), Vector3(WIN_C.x, -0.09, 0.665), Vector3.ZERO, Vector3.ONE, false)
	# 舱内补光：仪表台琥珀色
	var gl := OmniLight3D.new()
	gl.light_color = Color(1.0, 0.6, 0.25)
	gl.light_energy = 0.5
	gl.omni_range = 1.4
	gl.position = Vector3(WIN_C.x - 1.25, SILL_Y + 0.35, 0.8)
	root.add_child(gl)

	# ============================================================ 窗外
	var outside := Node3D.new()
	outside.name = "Outside"
	root.add_child(outside)
	# 近景云团（广告牌），缓缓向船尾方向流过
	var clouds: Array = []
	var cm := StandardMaterial3D.new()
	cm.albedo_texture = A.cloud_tex()
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	cm.albedo_color = Color(1.0, 0.85, 0.74, 0.55)
	cm.disable_receive_shadows = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 14:
		var q := QuadMesh.new()
		var s := rng.randf_range(30, 70)
		q.size = Vector2(s * 1.8, s)
		var c := A.add(outside, q, cm, Vector3(rng.randf_range(-260, 260), rng.randf_range(-70, -18), rng.randf_range(-320, -90)), Vector3.ZERO, Vector3.ONE, false)
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		clouds.append(c)
	refs["clouds"] = clouds
	return refs
