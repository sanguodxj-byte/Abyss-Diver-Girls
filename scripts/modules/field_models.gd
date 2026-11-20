extends RefCounted
## 战区环境件高精建模库（low_poly_model_audit.md P1-ENV / 战区灰盒返工批次 9）。
## 空投伞与空投舱、求救信标台、撤离信标塔与频闪桩、发烟罐、枯树残枝、河滩卵石、坦克/装甲车残骸零件。
## 规范同 device_models.gd：圆形件 ≥16 段（中型 ≥24），禁裸 BoxMesh / PrismMesh，硬表面带倒角；
## 本库只负责「长什么样」，逻辑脚本（events.gd / extract_zone.gd / raid.gd）只调用 build_* / *_mesh。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")
const DM = preload("res://scripts/modules/device_models.gd")

static var _cache := {}


# ---------------------------------------------------------------- 内部：双面三角
## 写一个双面三角形：两面各自按 Godot 顺时针正面规则配上朝外法线
static func _tri2(st: SurfaceTool, p: Array, nrm: Array, uv: Array) -> void:
	var face := -((p[1] as Vector3) - (p[0] as Vector3)).cross((p[2] as Vector3) - (p[0] as Vector3))
	for order in [[0, 1, 2], [0, 2, 1]]:
		var f := face if order[1] == 1 else -face
		for k in order:
			var nn: Vector3 = nrm[k]
			st.set_normal(nn if nn.dot(f) >= 0.0 else -nn)
			st.set_uv(uv[k])
			st.add_vertex(p[k])


# ======================================================================
# 空投减速伞
# ======================================================================
## 伞衣上一点：gore 幅序号 + 幅内横向 u(0..1) + 自伞顶通气孔到伞裙的纵向 v(0..1)
static func _canopy_pt(R: float, depth: float, gores: int, g: int, u: float, v: float) -> Vector3:
	var th := TAU * (float(g) + u) / float(gores)
	var phi := lerpf(0.13, 1.30, v)
	var billow := 1.0 + 0.085 * sin(PI * u) * (0.25 + 0.75 * v)
	var skirt_in := 1.0 - 0.07 * smoothstep(0.82, 1.0, v)
	var rr := sin(phi) * R * billow * skirt_in
	var y := (cos(phi) - cos(1.30)) * depth / (1.0 - cos(1.30)) + 0.06 * sin(PI * u) * v
	return Vector3(cos(th) * rr, y, sin(th) * rr)


## 伞衣网格（只含 parity 奇偶对应的伞幅，两色交替；伞顶留通气孔，幅间鼓包，伞裙内收）
static func canopy_mesh(R: float, depth: float, gores := 16, parity := 0) -> ArrayMesh:
	var key := "canopy%.2f|%.2f|%d|%d" % [R, depth, gores, parity]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 6
	var nv := 12
	var e := 0.002
	for g in gores:
		if g % 2 != parity:
			continue
		var P := []
		var N := []
		for iu in nu + 1:
			var row_p := []
			var row_n := []
			for iv in nv + 1:
				var u := float(iu) / nu
				var v := float(iv) / nv
				var p0 := _canopy_pt(R, depth, gores, g, u, v)
				var du := _canopy_pt(R, depth, gores, g, minf(u + e, 1.0), v) - _canopy_pt(R, depth, gores, g, maxf(u - e, 0.0), v)
				var dv := _canopy_pt(R, depth, gores, g, u, minf(v + e, 1.0)) - _canopy_pt(R, depth, gores, g, u, maxf(v - e, 0.0))
				var nn := du.cross(dv).normalized()
				if nn.dot(p0 - Vector3(0, -depth, 0)) < 0.0:
					nn = -nn
				row_p.append(p0)
				row_n.append(nn)
			P.append(row_p)
			N.append(row_n)
		for iu in nu:
			for iv in nv:
				var q := [[iu, iv], [iu + 1, iv], [iu + 1, iv + 1], [iu, iv + 1]]
				var pp := []
				var nn2 := []
				var uu := []
				for c in q:
					pp.append(P[c[0]][c[1]])
					nn2.append(N[c[0]][c[1]])
					uu.append(Vector2(float(c[0]) / nu, float(c[1]) / nv))
				_tri2(st, [pp[0], pp[1], pp[2]], [nn2[0], nn2[1], nn2[2]], [uu[0], uu[1], uu[2]])
				_tri2(st, [pp[0], pp[2], pp[3]], [nn2[0], nn2[2], nn2[3]], [uu[0], uu[2], uu[3]])
	st.generate_tangents()
	var m := st.commit()
	_cache[key] = m
	return m


## 完整减速伞：两色伞幅 + 伞裙加强边 + 通气孔环 + 16 根伞绳汇到汇流环 + 4 条吊带。
## 原点 = 伞绳汇流环（吊带下端在 -riser_len 处），伞衣在其上方 line_len 处张开。
static func build_parachute(p: Node3D, R := 3.4, depth := 1.9, line_len := 4.4, riser_len := 0.9,
		c_a := Color(0.60, 0.58, 0.48), c_b := Color(0.72, 0.30, 0.12)) -> Node3D:
	var root := K.node(p, Vector3.ZERO, Vector3.ZERO, "Parachute")
	var gores := 16
	var cy := line_len
	var m_a := A.paint(c_a, 0.0, 0.92, {"wear": 0.35, "dust": 0.55, "panel_scale": 0.0})
	var m_b := A.paint(c_b, 0.0, 0.90, {"wear": 0.30, "dust": 0.45, "panel_scale": 0.0})
	DM.add(root, canopy_mesh(R, depth, gores, 0), m_a, Vector3(0, cy, 0))
	DM.add(root, canopy_mesh(R, depth, gores, 1), m_b, Vector3(0, cy, 0))
	var m_tape := A.paint(Color(0.30, 0.29, 0.25), 0.0, 0.9, {"panel_scale": 0.0})
	# 伞裙加强带（沿鼓包的扇贝边）与伞顶通气孔环
	var hem: Array = []
	var vent: Array = []
	for g in gores:
		for k in 4:
			hem.append(_canopy_pt(R, depth, gores, g, float(k) / 4.0, 1.0) + Vector3(0, cy, 0))
			vent.append(_canopy_pt(R, depth, gores, g, float(k) / 4.0, 0.0) + Vector3(0, cy, 0))
	hem.append(hem[0])
	vent.append(vent[0])
	DM.add(root, A.tube(hem, 0.035, 14, 2), m_tape, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	DM.add(root, A.tube(vent, 0.03, 14, 2), m_tape, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	# 伞幅缝线径向加强带 + 伞绳
	var m_line := A.paint(Color(0.82, 0.80, 0.70), 0.0, 0.85, {"panel_scale": 0.0})
	for g in gores:
		var rib: Array = []
		for iv in 7:
			rib.append(_canopy_pt(R, depth, gores, g, 0.0, float(iv) / 6.0) * 1.004 + Vector3(0, cy, 0))
		DM.add(root, A.tube(rib, 0.018, 14, 2), m_tape, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		var skirt: Vector3 = rib[6]
		DM.rod(root, Vector3(0, 0.05, 0), skirt, 0.009, m_line, 16, false)
	# 汇流环 + 四条吊带 + 卸扣
	DM.add(root, DM.torus(0.07, 0.11, 32, 16), K.gunmetal(), Vector3.ZERO, Vector3(90, 0, 0))
	var m_strap := A.paint(Color(0.24, 0.26, 0.20), 0.0, 0.9, {"panel_scale": 0.0})
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		var low := Vector3(cos(a) * 0.55, -riser_len, sin(a) * 0.55)
		var n := DM._aim(root, low, Vector3.ZERO)
		DM.add(n, A.bevel_box(Vector3(0.07, low.length(), 0.012), 0.004), m_strap, Vector3(0, low.length() * 0.5, 0))
		DM.add(root, DM.torus(0.022, 0.045, 24, 16), K.gunmetal(), low, Vector3(0, rad_to_deg(-a), 90), Vector3.ONE, false)
	return root


# ======================================================================
# 补给空投舱
# ======================================================================
## 车削舱体 + 三道加强箍 + 8 条纵向护条 + 侧舱门 + 缓冲压溃底环 + 4 只液压着陆脚 + 4 只制动喷口 + 顶部吊环。
## 原点在舱体中心；返回 {"top": 吊环位置}
static func build_supply_pod(p: Node3D, m_pod: Material) -> Dictionary:
	var root := K.node(p, Vector3.ZERO, Vector3.ZERO, "SupplyPod")
	var m_dark := K.dark()
	var m_st := K.gunmetal()
	var prof := PackedVector2Array([
		Vector2(0.0, -1.05), Vector2(0.55, -1.05), Vector2(0.86, -0.92), Vector2(0.98, -0.72),
		Vector2(0.98, 0.78), Vector2(0.92, 0.96), Vector2(0.62, 1.20), Vector2(0.50, 1.26), Vector2(0.50, 1.40), Vector2(0.0, 1.40)])
	DM.add(root, DM.lathe(prof, 40), m_pod)
	for y in [-0.55, 0.12, 0.70]:
		DM.add(root, DM.cyl(1.015, 0.07, -1.0, 48), m_st, Vector3(0, y, 0))
	# 缓冲压溃环（黄黑警示）+ 蜂窝压溃块
	DM.add(root, DM.cyl(1.12, 0.24, 1.06, 40), A.hazard(), Vector3(0, -0.86, 0))
	DM.add(root, DM.cyl(1.0, 0.10, 0.80, 40), m_dark, Vector3(0, -1.03, 0))
	# 纵向护条
	for i in 8:
		var a := TAU * float(i) / 8.0 + PI / 8.0
		DM.add(root, A.bevel_box(Vector3(0.07, 1.36, 0.04), 0.012), m_dark, Vector3(cos(a) * 0.995, 0.06, sin(a) * 0.995), Vector3(0, rad_to_deg(-a) + 90.0, 0))
	# 侧舱门：内凹门板 + 铰链 + 拉手 + 警示条
	var door := K.node(root, Vector3(0, 0.1, -0.985), Vector3.ZERO, "Hatch")
	DM.add(door, A.bevel_box(Vector3(0.72, 1.02, 0.05), 0.015), m_pod)
	DM.add(door, A.bevel_box(Vector3(0.76, 1.06, 0.03), 0.01), m_dark, Vector3(0, 0, 0.02))
	for hy in [-0.36, 0.36]:
		DM.add(door, DM.cyl(0.035, 0.16, -1.0, 20), m_st, Vector3(0.40, hy, -0.03))
	DM.rod(door, Vector3(-0.22, -0.1, -0.05), Vector3(-0.22, 0.14, -0.05), 0.016, A.chrome(), 16)
	for hy in [-0.1, 0.14]:
		DM.rod(door, Vector3(-0.22, hy, -0.05), Vector3(-0.22, hy, 0.0), 0.012, m_st, 16)
	DM.hazard_band(door, Vector3(0.60, 0.07, 0.012), Vector3(0, 0.44, -0.035))
	# 液压着陆脚：作动筒 + 铰接耳座 + 防沉脚垫
	for k in 4:
		var ka := PI * 0.25 + PI * 0.5 * float(k)
		var d := Vector3(cos(ka), 0, sin(ka))
		DM.add(root, A.bevel_box(Vector3(0.22, 0.26, 0.20), 0.03), m_dark, d * 1.02 + Vector3(0, -0.40, 0), Vector3(0, rad_to_deg(-ka) + 90.0, 0))
		var foot := d * 1.55 + Vector3(0, -1.30, 0)
		DM.piston(root, d * 1.08 + Vector3(0, -0.42, 0), foot, 0.045)
		DM.add(root, DM.cyl(0.20, 0.06, 0.24, 28), m_dark, foot + Vector3(0, -0.04, 0))
		# 舱肩制动喷口
		var nz := K.node(root, d * 0.80 + Vector3(0, 1.02, 0), Vector3(0, 0, 0))
		nz.basis = Basis(d.cross(Vector3.UP).normalized(), deg_to_rad(-35.0))
		DM.add(nz, DM.lathe(PackedVector2Array([Vector2(0.05, 0.0), Vector2(0.07, 0.06), Vector2(0.12, 0.20), Vector2(0.135, 0.22)]), 24, false, false), m_dark, Vector3.ZERO, Vector3(180, 0, 0))
	# 顶部吊环与吊环座
	DM.add(root, DM.cyl(0.18, 0.10, 0.22, 28), m_st, Vector3(0, 1.45, 0))
	DM.add(root, DM.torus(0.10, 0.16, 32, 16), m_st, Vector3(0, 1.62, 0), Vector3(90, 0, 0))
	return {"top": Vector3(0, 1.68, 0)}


# ======================================================================
# 求救信标台
# ======================================================================
## 三脚架 + 伸缩桅杆（锁紧箍）+ 军用信标箱（护角/锁扣/提手/屏幕）+ 太阳能板 + 护笼频闪灯 + 弹簧座鞭状天线。
## 返回 {"lamp": 灯芯 MeshInstance3D, "lamp_pos": 灯位置}
static func build_distress_beacon(p: Node3D, m_case: Material, c: Color) -> Dictionary:
	var root := K.node(p, Vector3.ZERO, Vector3.ZERO, "DistressBeacon")
	var m_st := K.gunmetal()
	var m_dark := K.dark()
	var hub := Vector3(0, 1.18, 0)
	DM.add(root, DM.cyl(0.10, 0.16, -1.0, 28), m_dark, hub)
	for lg in 3:
		var la := TAU * float(lg) / 3.0 + 0.2
		var foot := Vector3(cos(la) * 0.86, 0.04, sin(la) * 0.86)
		var top := hub + Vector3(cos(la) * 0.09, -0.04, sin(la) * 0.09)
		DM.rod(root, top, foot, 0.026, m_st, 20)
		var mid := top.lerp(foot, 0.45)
		DM.add(DM._aim(root, top, foot), DM.cyl(0.038, 0.09, -1.0, 24), m_dark, Vector3(0, top.distance_to(mid), 0))
		DM.add(root, DM.cyl(0.07, 0.035, 0.09, 24), m_dark, foot + Vector3(0, -0.02, 0))
		DM.add(root, DM.cyl(0.0, 0.10, 0.025, 16), m_st, foot + Vector3(0, -0.08, 0))
		DM.rod(root, top.lerp(foot, 0.62), Vector3(0, 0.42, 0), 0.011, m_st, 16)
	DM.add(root, DM.cyl(0.045, 0.06, -1.0, 24), m_dark, Vector3(0, 0.42, 0))
	# 信标箱
	var box := K.node(root, Vector3(0, 1.42, 0), Vector3.ZERO, "Case")
	DM.add(box, A.bevel_box(Vector3(0.74, 0.46, 0.54), 0.045), m_case)
	DM.add(box, A.bevel_box(Vector3(0.76, 0.03, 0.56), 0.01), m_dark, Vector3(0, 0.07, 0))
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				DM.add(box, A.bevel_box(Vector3(0.09, 0.09, 0.09), 0.02), m_dark, Vector3(sx * 0.35, sy * 0.21, sz * 0.25), Vector3.ZERO, Vector3.ONE, false)
	for lx in [-0.2, 0.2]:
		DM.add(box, A.bevel_box(Vector3(0.08, 0.10, 0.03), 0.01), m_st, Vector3(lx, 0.06, -0.285))
	DM.rod(box, Vector3(-0.16, 0.30, 0), Vector3(0.16, 0.30, 0), 0.016, m_st, 16)
	for hx in [-0.16, 0.16]:
		DM.rod(box, Vector3(hx, 0.23, 0), Vector3(hx, 0.30, 0), 0.014, m_st, 16)
	DM.add(box, A.bevel_box(Vector3(0.24, 0.12, 0.012), 0.004), A.emit(Color(0.3, 0.9, 0.5), 1.2), Vector3(0.18, -0.06, -0.272), Vector3.ZERO, Vector3.ONE, false)
	for k in 3:
		DM.add(box, DM.cyl(0.022, 0.03, -1.0, 16), m_dark, Vector3(-0.22 + k * 0.08, -0.08, -0.28), Vector3(90, 0, 0))
	DM.hazard_band(box, Vector3(0.76, 0.06, 0.56), Vector3(0, -0.20, 0))
	# 太阳能板：铝框 + 4×6 电池片 + 铰链 + 撑杆
	var sp := K.node(box, Vector3(0, 0.18, 0.38), Vector3(-36, 0, 0), "Solar")
	DM.add(sp, A.bevel_box(Vector3(0.72, 0.03, 0.52), 0.01), m_st, Vector3(0, 0, 0.26))
	var m_cell := A.paint(Color(0.07, 0.11, 0.20), 0.7, 0.22, {"panel_scale": 0.0})
	for ix in 6:
		for iz in 4:
			DM.add(sp, A.bevel_box(Vector3(0.105, 0.012, 0.115), 0.003), m_cell, Vector3(-0.29 + ix * 0.116, 0.018, 0.06 + iz * 0.127), Vector3.ZERO, Vector3.ONE, false)
	DM.add(sp, DM.cyl(0.018, 0.70, -1.0, 16), m_dark, Vector3(0, 0, 0), Vector3(0, 0, 90))
	DM.rod(box, Vector3(0, -0.18, 0.27), Vector3(0, 0.02, 0.64), 0.01, m_st, 16)
	# 伸缩桅杆
	var segs := [[0.055, 1.62, 0.78], [0.043, 2.30, 0.70], [0.033, 2.96, 0.66]]
	for s in segs:
		var r: float = s[0]
		var y1: float = s[1]
		var L: float = s[2]
		DM.add(root, DM.cyl(r, L, -1.0, 24), m_st, Vector3(0, y1 + L * 0.5 - 0.1, 0))
		DM.add(root, DM.cyl(r * 1.45, 0.07, -1.0, 24), m_dark, Vector3(0, y1 + L - 0.12, 0))
		DM.add(root, A.bevel_box(Vector3(0.05, 0.03, 0.10), 0.008), m_dark, Vector3(r * 1.5, y1 + L - 0.12, 0.04))
	# 护笼频闪灯
	var lamp_pos := Vector3(0, 3.56, 0)
	var lamp := DM.caged_lamp(root, lamp_pos, 0.10, 0.30, c, 3.0)
	# 弹簧座鞭状天线
	var ab := Vector3(0.22, 3.18, 0)
	DM.add(root, A.bevel_box(Vector3(0.24, 0.04, 0.05), 0.01), m_dark, Vector3(0.11, 3.18, 0))
	for k in 5:
		DM.add(root, DM.torus(0.012, 0.024, 20, 16), m_dark, ab + Vector3(0, 0.03 + k * 0.022, 0), Vector3.ZERO, Vector3.ONE, false)
	DM.add(root, DM.cyl(0.006, 1.55, 0.012, 16), m_st, ab + Vector3(0.08, 0.92, 0), Vector3(0, 0, -6), Vector3.ONE, false)
	DM.add(root, DM.sphere(0.018, 20), m_dark, ab + Vector3(0.16, 1.70, 0), Vector3.ZERO, Vector3.ONE, false)
	# 箱体到桅杆的供电线缆
	DM.add(root, A.tube([Vector3(0.30, 1.30, -0.1), Vector3(0.36, 1.05, -0.12), Vector3(0.10, 0.95, -0.06), Vector3(0.05, 1.70, -0.02)], 0.014, 14, 10, 0.2), A.rubber(), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	return {"lamp": lamp, "lamp_pos": lamp_pos}


# ======================================================================
# 撤离区：战术应答信标塔 / 频闪桩 / 发烟罐
# ======================================================================
## 三角格构桅杆信标塔（4.8m）：倒角混凝土锚墩 + 地脚螺栓底板 + 三肢格构桅身（横缀条 + 之字斜缀条）
## + 通信配电箱（百叶/门缝/把手/穿线管）+ 顶部横担偶极天线 + 大号护笼信标灯。返回 {"lamp_mat", "top"}
static func build_extract_tower(p: Node3D, pos: Vector3, c: Color, m_con: Material, m_cab: Material) -> Dictionary:
	var root := K.node(p, pos, Vector3.ZERO, "ExtractTower")
	var m_st := K.gunmetal()
	var m_dark := K.dark()
	DM.add(root, A.bevel_box(Vector3(1.65, 0.30, 1.65), 0.10, 0.88), m_con, Vector3(0, 0.15, 0))
	DM.add(root, A.bevel_box(Vector3(0.98, 0.05, 0.98), 0.012), m_dark, Vector3(0, 0.325, 0))
	for i in 8:
		var a := TAU * float(i) / 8.0
		DM.add(root, A.cyl(0.026, 0.05, 0.03, 6), A.chrome(), Vector3(cos(a) * 0.40, 0.37, sin(a) * 0.40), Vector3.ZERO, Vector3.ONE, false)
	var H := 4.6
	var y0 := 0.35
	var legs: Array = []
	for k in 3:
		var a := TAU * float(k) / 3.0 + PI / 6.0
		legs.append(Vector2(cos(a), sin(a)))
	var rb := 0.34
	var rt := 0.16
	var lv := 8
	var lp := func(k: int, t: float) -> Vector3:
		var rr := lerpf(rb, rt, t)
		var d: Vector2 = legs[k]
		return Vector3(d.x * rr, y0 + H * t, d.y * rr)
	for k in 3:
		DM.rod(root, lp.call(k, 0.0), lp.call(k, 1.0), 0.032, m_st, 20)
		var g: Vector3 = lp.call(k, 0.0)
		DM.add(root, A.bevel_box(Vector3(0.16, 0.18, 0.016), 0.004), m_dark, Vector3(g.x, y0 + 0.09, g.z), Vector3(0, rad_to_deg(atan2(g.x, g.z)), 0))
		DM.add(root, A.bevel_box(Vector3(0.016, 0.18, 0.16), 0.004), m_dark, Vector3(g.x, y0 + 0.09, g.z), Vector3(0, rad_to_deg(atan2(g.x, g.z)), 0))
	for i in lv:
		var t0 := float(i) / lv
		var t1 := float(i + 1) / lv
		for k in 3:
			var k2 := (k + 1) % 3
			DM.rod(root, lp.call(k, t1), lp.call(k2, t1), 0.012, m_st, 16, false)
			DM.rod(root, lp.call(k, t0), lp.call(k2, t1), 0.010, m_st, 16, false)
	# 通信配电箱 + 穿线管
	var cab := K.node(root, Vector3(-0.44, 0.80, 0.42), Vector3(0, 20, 0), "Cabinet")
	DM.add(cab, A.bevel_box(Vector3(0.66, 0.86, 0.46), 0.035), m_cab)
	DM.add(cab, A.bevel_box(Vector3(0.70, 0.05, 0.50), 0.012), m_dark, Vector3(0, 0.455, 0))
	DM.add(cab, A.bevel_box(Vector3(0.006, 0.78, 0.012), 0.002), m_dark, Vector3(0.0, 0.0, 0.232))
	for k in 5:
		DM.add(cab, A.bevel_box(Vector3(0.26, 0.022, 0.03), 0.006), m_dark, Vector3(-0.15, -0.22 + k * 0.05, 0.235), Vector3(-25, 0, 0))
	DM.rod(cab, Vector3(0.14, 0.05, 0.24), Vector3(0.14, 0.20, 0.24), 0.012, A.chrome(), 16)
	DM.hazard_band(cab, Vector3(0.62, 0.06, 0.012), Vector3(0, 0.33, 0.235))
	DM.add(root, A.pipe([Vector3(-0.36, 1.25, 0.36), Vector3(-0.30, 1.42, 0.30), Vector3(-0.08, 1.55, 0.08), Vector3(0, 2.2, 0)], 0.022), m_dark)
	# 顶部横担 + 偶极天线 + 信标灯
	var top_y := y0 + H
	DM.add(root, A.bevel_box(Vector3(0.40, 0.06, 0.40), 0.015), m_dark, Vector3(0, top_y + 0.03, 0))
	DM.add(root, A.bevel_box(Vector3(1.00, 0.06, 0.07), 0.012), m_st, Vector3(0, top_y - 0.35, 0))
	for sx in [-0.46, 0.46]:
		DM.add(root, DM.cyl(0.012, 0.85, 0.02, 16), m_st, Vector3(sx, top_y - 0.35 + 0.46, 0))
		DM.add(root, DM.cyl(0.03, 0.08, -1.0, 16), m_dark, Vector3(sx, top_y - 0.30, 0))
	var lamp := DM.caged_lamp(root, Vector3(0, top_y + 0.06, 0), 0.17, 0.52, c, 2.4)
	return {"lamp_mat": lamp.material_override, "top": pos + Vector3(0, top_y + 0.4, 0)}


## 战术地面频闪桩：喇叭形压载底座 + 地钉 + 警示筒身 + 护笼频闪灯 + 鞭状天线。scale=1 时高约 0.6m。返回频闪材质
static func build_strobe_bollard(p: Node3D, pos: Vector3, ang: float, c: Color, scale := 1.0) -> Material:
	var root := K.node(p, pos, Vector3(0, rad_to_deg(-ang), 0), "StrobeBollard")
	root.scale = Vector3.ONE * scale
	var m_dark := K.dark()
	var m_st := K.gunmetal()
	DM.add(root, DM.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.26, 0.0), Vector2(0.26, 0.03), Vector2(0.16, 0.08), Vector2(0.11, 0.12), Vector2(0.0, 0.12)]), 32), m_dark)
	for k in 3:
		var a := TAU * float(k) / 3.0
		DM.add(root, DM.cyl(0.014, 0.02, -1.0, 16), A.chrome(), Vector3(cos(a) * 0.21, 0.035, sin(a) * 0.21))
	DM.add(root, DM.cyl(0.10, 0.20, -1.0, 28), A.hazard(), Vector3(0, 0.22, 0))
	DM.add(root, DM.torus(0.095, 0.115, 32, 16), m_st, Vector3(0, 0.12, 0))
	DM.add(root, DM.torus(0.095, 0.115, 32, 16), m_st, Vector3(0, 0.32, 0))
	var lamp := DM.caged_lamp(root, Vector3(0, 0.32, 0), 0.075, 0.22, c.darkened(0.18), 1.4)
	DM.add(root, DM.cyl(0.006, 0.42, 0.010, 16), m_st, Vector3(0.09, 0.53, 0), Vector3.ZERO, Vector3.ONE, false)
	DM.add(root, DM.cyl(0.016, 0.03, -1.0, 16), m_dark, Vector3(0.09, 0.33, 0))
	return lamp.material_override


## 发烟信号罐：车削罐身 + 卷边 + 标签带 + 拉环与保险销。原点在罐身中心，轴沿 +Y
static func build_smoke_can(p: Node3D, pos: Vector3, rot: Vector3, m_body: Material) -> Node3D:
	var root := K.node(p, pos, rot, "SmokeCan")
	var m_st := K.gunmetal()
	DM.add(root, DM.lathe(PackedVector2Array([Vector2(0.0, -0.18), Vector2(0.092, -0.18), Vector2(0.10, -0.17), Vector2(0.10, 0.15), Vector2(0.092, 0.17),
		Vector2(0.075, 0.18), Vector2(0.075, 0.22), Vector2(0.04, 0.24), Vector2(0.0, 0.24)]), 32), m_body)
	DM.add(root, DM.cyl(0.102, 0.10, -1.0, 32), A.paint(Color(0.78, 0.74, 0.30), 0.1, 0.6, {"panel_scale": 0.0}), Vector3(0, 0.02, 0))
	for y in [-0.17, 0.155]:
		DM.add(root, DM.torus(0.092, 0.106, 32, 16), m_st, Vector3(0, y, 0))
	DM.add(root, DM.torus(0.022, 0.032, 24, 16), m_st, Vector3(0.03, 0.26, 0), Vector3(90, 0, 0))
	DM.rod(root, Vector3(-0.03, 0.235, 0), Vector3(0.0, 0.25, 0), 0.006, m_st, 16)
	return root


# ======================================================================
# 枯树残枝 / 河滩卵石
# ======================================================================
## 枯树残枝冠（单位高度 1，配合 tree_trunk_mesh 的 h 等比缩放）：3~4 根渐细分叉大枝 + 次级枝 + 折断枝桩 + 断顶
static func snag_limbs_mesh(variant := 0) -> ArrayMesh:
	var v := posmod(variant, 6)
	var key := "snag%d" % v
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7717 + v * 131
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_l := 3 + v % 2
	for k in n_l:
		var az := TAU * float(k) / n_l + rng.randf_range(-0.4, 0.4)
		var d := Vector3(cos(az), 0, sin(az))
		var y0 := rng.randf_range(0.45, 0.78)
		var reach := rng.randf_range(0.26, 0.40)
		var rise := rng.randf_range(0.18, 0.36)
		var p0 := Vector3(0, y0, 0)
		var p1 := p0 + d * reach * 0.35 + Vector3(0, rise * 0.25, 0)
		var p2 := p0 + d * reach * 0.70 + Vector3(rng.randf_range(-0.04, 0.04), rise * 0.62, rng.randf_range(-0.04, 0.04))
		var p3 := p0 + d * reach + Vector3(0, rise, 0)
		var r0 := 0.016 * (1.2 - y0 * 0.5)
		A._branch_tube(st, [p0 - d * 0.01, p1, p2, p3], [r0, r0 * 0.72, r0 * 0.45, r0 * 0.12], 16)
		# 次级分叉
		for j in 2:
			var sa := az + (0.7 if j == 0 else -0.6) + rng.randf_range(-0.2, 0.2)
			var sd := Vector3(cos(sa), 0, sin(sa))
			var base := p1.lerp(p2, 0.3 + 0.5 * j)
			var tip := base + sd * reach * 0.38 + Vector3(0, rise * 0.45, 0)
			A._branch_tube(st, [base, base.lerp(tip, 0.5) + Vector3(0, 0.02, 0), tip], [r0 * 0.42, r0 * 0.26, r0 * 0.06], 12)
		# 折断枝桩
		var stub_y := rng.randf_range(0.30, 0.42)
		var sd2 := Vector3(cos(az + 1.4), 0, sin(az + 1.4))
		A._branch_tube(st, [Vector3(0, stub_y, 0), Vector3(0, stub_y + 0.03, 0) + sd2 * 0.07], [0.020, 0.014], 12)
	# 断顶劈裂枝
	A._branch_tube(st, [Vector3(0, 0.90, 0), Vector3(0.02, 1.0, 0.01), Vector3(0.05, 1.08, 0.03)], [0.012, 0.008, 0.002], 12)
	A._branch_tube(st, [Vector3(0, 0.92, 0), Vector3(-0.025, 1.02, 0.0)], [0.010, 0.002], 12)
	st.generate_tangents()
	var m := st.commit()
	_cache[key] = m
	return m


## 河滩卵石：噪声起伏的扁椭球，底面压平，单位直径 1
static func pebble_mesh(variant := 0) -> ArrayMesh:
	var v := posmod(variant, 4)
	var key := "pebble%d" % v
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4409 + v * 97
	var ph := []
	for i in 6:
		ph.append(Vector3(rng.randf_range(0, TAU), rng.randf_range(0, TAU), rng.randf_range(0.04, 0.10)))
	var seg := 28
	var rings := 14
	var grid := []
	for iy in rings + 1:
		var row := []
		var t := float(iy) / rings
		var phi := PI * t
		for ix in seg + 1:
			var th := TAU * float(ix) / seg
			var dir := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var r := 0.5
			for k in 3:
				var q: Vector3 = ph[k]
				r *= 1.0 + q.z * sin(th * float(k + 1) + q.x) * sin(phi * float(k + 1) + q.y)
			var pt := dir * r
			pt.y = maxf(pt.y, -0.30)
			row.append(pt)
		grid.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iy in rings:
		for ix in seg:
			var a: Vector3 = grid[iy][ix]
			var b: Vector3 = grid[iy][ix + 1]
			var c: Vector3 = grid[iy + 1][ix + 1]
			var d: Vector3 = grid[iy + 1][ix]
			for tri in [[a, c, b], [a, d, c]]:
				for pt in tri:
					st.set_uv(Vector2((pt as Vector3).x + 0.5, (pt as Vector3).z + 0.5))
					st.add_vertex(pt)
	st.index()
	st.generate_normals()
	st.generate_tangents()
	var m := st.commit()
	_cache[key] = m
	return m


# ======================================================================
# 坦克 / 装甲车残骸零件（供 raid._imesh 批量实例化）
# ======================================================================
## 负重轮轮毂（沿 Y 轴，宽 w）：轮缘 + 碟形辐板 + 中心轮毂盖（金属）
static func road_wheel_hub_mesh(r: float, w: float) -> ArrayMesh:
	var h := w * 0.5
	return DM.lathe(PackedVector2Array([
		Vector2(0.0, -h * 0.4), Vector2(r * 0.18, -h * 0.4), Vector2(r * 0.22, -h * 0.6), Vector2(r * 0.30, -h * 0.6), Vector2(r * 0.36, -h * 0.85),
		Vector2(r * 0.78, -h * 0.85), Vector2(r * 0.80, -h), Vector2(r * 0.84, -h), Vector2(r * 0.84, h), Vector2(r * 0.80, h), Vector2(r * 0.78, h * 0.85),
		Vector2(r * 0.36, h * 0.85), Vector2(r * 0.30, h * 0.6), Vector2(r * 0.22, h * 0.6), Vector2(r * 0.18, h * 0.4), Vector2(0.0, h * 0.4)]), 40)


## 负重轮胶圈（沿 Y 轴）：两半轮之间带中缝
static func road_wheel_tyre_mesh(r: float, w: float) -> ArrayMesh:
	var h := w * 0.5
	return DM.lathe(PackedVector2Array([
		Vector2(r * 0.84, -h), Vector2(r * 0.97, -h), Vector2(r, -h * 0.8), Vector2(r, -h * 0.12), Vector2(r * 0.93, -h * 0.06),
		Vector2(r * 0.93, h * 0.06), Vector2(r, h * 0.12), Vector2(r, h * 0.8), Vector2(r * 0.97, h), Vector2(r * 0.84, h)]), 40, false, false)


## 履带板（单节，沿 Z 排布）：带两道防滑筋和中央诱导齿
static func track_link_mesh() -> ArrayMesh:
	var key := "trklink"
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts := [
		[Vector3(0.60, 0.05, 0.15), Vector3(0, 0, 0)],
		[Vector3(0.58, 0.035, 0.03), Vector3(0, -0.04, -0.045)],
		[Vector3(0.58, 0.035, 0.03), Vector3(0, -0.04, 0.045)],
		[Vector3(0.07, 0.09, 0.08), Vector3(0, 0.07, 0)],
	]
	for pt in parts:
		st.append_from(A.bevel_box(pt[0], 0.012), 0, Transform3D(Basis.IDENTITY, pt[1]))
	st.generate_tangents()
	var m := st.commit()
	_cache[key] = m
	return m


## 主动轮（齿轮外廓挤出，沿 Z 厚度，侧装时绕 Y 转 90°）
static func sprocket_mesh(r: float, teeth := 12, thick := 0.10) -> ArrayMesh:
	var pts := PackedVector2Array()
	for i in teeth * 4:
		var a := TAU * float(i) / (teeth * 4)
		var rr := r if (i % 4 == 1 or i % 4 == 2) else r * 0.84
		pts.append(Vector2(cos(a) * rr, sin(a) * rr))
	return A.prism(pts, thick, 0.012)


## 坦克主炮炮管（沿 Y，长 L，底部为 0）：炮根加粗段 + 热护套箍 + 抽烟装置鼓包 + 炮口
static func gun_barrel_mesh(L: float, r: float) -> ArrayMesh:
	return DM.lathe(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(r * 1.55, 0.0), Vector2(r * 1.55, L * 0.10), Vector2(r * 1.25, L * 0.13), Vector2(r * 1.18, L * 0.30),
		Vector2(r * 1.28, L * 0.31), Vector2(r * 1.28, L * 0.335), Vector2(r * 1.15, L * 0.345), Vector2(r * 1.10, L * 0.44),
		Vector2(r * 1.62, L * 0.47), Vector2(r * 1.70, L * 0.53), Vector2(r * 1.62, L * 0.59), Vector2(r * 1.05, L * 0.62),
		Vector2(r * 1.0, L * 0.80), Vector2(r * 1.10, L * 0.81), Vector2(r * 1.10, L * 0.83), Vector2(r * 0.98, L * 0.84),
		Vector2(r * 0.96, L * 0.985), Vector2(r * 1.08, L), Vector2(r * 0.62, L), Vector2(r * 0.62, L * 0.97), Vector2(0.0, L * 0.97)]), 32)


## 越野轮胎（沿 Y 轴）：圆胎肩 + 胎侧鼓包，胎面花纹块另由 tire_lug_mesh 实例化
static func offroad_tire_mesh(r: float, w: float) -> ArrayMesh:
	var h := w * 0.5
	return DM.lathe(PackedVector2Array([
		Vector2(r * 0.56, -h * 0.92), Vector2(r * 0.80, -h * 1.02), Vector2(r * 0.92, -h * 0.96), Vector2(r * 0.985, -h * 0.72),
		Vector2(r, -h * 0.30), Vector2(r, h * 0.30), Vector2(r * 0.985, h * 0.72), Vector2(r * 0.92, h * 0.96), Vector2(r * 0.80, h * 1.02),
		Vector2(r * 0.56, h * 0.92)]), 40, false, false)


## 越野轮辋（沿 Y 轴）：深凹轮辋 + 轮毂凸台 + 中央盖
static func offroad_rim_mesh(r: float, w: float) -> ArrayMesh:
	var h := w * 0.5
	return DM.lathe(PackedVector2Array([
		Vector2(0.0, -h * 0.55), Vector2(r * 0.16, -h * 0.55), Vector2(r * 0.20, -h * 0.75), Vector2(r * 0.44, -h * 0.80),
		Vector2(r * 0.50, -h * 0.94), Vector2(r * 0.58, -h * 0.94), Vector2(r * 0.58, h * 0.94), Vector2(r * 0.50, h * 0.94),
		Vector2(r * 0.44, h * 0.62), Vector2(r * 0.20, h * 0.58), Vector2(r * 0.16, h * 0.40), Vector2(0.0, h * 0.40)]), 40)


## 胎面花纹块（V 形），单位尺寸，由调用方缩放
static func tire_lug_mesh() -> ArrayMesh:
	var key := "tirelug"
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in [-1.0, 1.0]:
		st.append_from(A.bevel_box(Vector3(0.5, 1.0, 0.32), 0.08), 0, Transform3D(Basis(Vector3.UP, deg_to_rad(28.0 * s)), Vector3(s * 0.24, 0, 0)))
	st.generate_tangents()
	var m := st.commit()
	_cache[key] = m
	return m


# ======================================================================
# 放样硬表面（装甲车体用）
# ======================================================================
## 截面放样：stations = [[z, PackedVector2Array 截面(XY)], ...]，各截面点数相同、首尾不闭合传入（函数自动闭合）。
## 硬边法线（每面独立），两端用扇形封口。用于 V 型防雷车体、倾斜驾驶舱这类非原语装甲壳。
static func loft_mesh(stations: Array, cap_front := true, cap_back := true) -> ArrayMesh:
	var key := "loft%s|%s|%s" % [str(stations).md5_text(), cap_front, cap_back]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ns := stations.size()
	var nv: int = (stations[0][1] as PackedVector2Array).size()
	var rings: Array = []
	var cents: Array = []
	for s in stations:
		var poly: PackedVector2Array = s[1]
		var ring: Array = []
		var c := Vector3.ZERO
		for q in poly:
			var v := Vector3(q.x, q.y, float(s[0]))
			ring.append(v)
			c += v
		rings.append(ring)
		cents.append(c / float(nv))
	for i in ns - 1:
		var axis_c: Vector3 = ((cents[i] as Vector3) + (cents[i + 1] as Vector3)) * 0.5
		for j in nv:
			var j2 := (j + 1) % nv
			var a: Vector3 = rings[i][j]
			var b: Vector3 = rings[i][j2]
			var c: Vector3 = rings[i + 1][j2]
			var d: Vector3 = rings[i + 1][j]
			var mid := (a + b + c + d) * 0.25
			var out := mid - Vector3(axis_c.x, axis_c.y, mid.z)
			for tri in [[a, b, c], [a, c, d]]:
				_tri_out(st, tri[0], tri[1], tri[2], out)
	for e in [[cap_front, 0, -1.0], [cap_back, ns - 1, 1.0]]:
		if not e[0]:
			continue
		var ring: Array = rings[e[1]]
		var cc: Vector3 = cents[e[1]]
		for j in nv:
			_tri_out(st, cc, ring[j], ring[(j + 1) % nv], Vector3(0, 0, e[2]))
	st.generate_tangents()
	var m := st.commit()
	_cache[key] = m
	return m


## 单面三角：按 out 方向定朝向（本项目约定 cross(b-a, c-a) 指向内侧为正面），硬边面法线
static func _tri_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-12:
		return
	if cr.dot(out) > 0.0:
		var t := b
		b = c
		c = t
		cr = -cr
	var n := -cr.normalized()
	for v in [a, b, c]:
		st.set_normal(n)
		st.set_uv(Vector2((v as Vector3).z * 0.5 + (v as Vector3).x * 0.3, (v as Vector3).y * 0.5))
		st.add_vertex(v)


## 镜像对称截面：half 为 x≥0 一侧自下（龙骨）而上（顶面）的点，自动镜像出完整闭合截面
static func _sym(half: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in half:
		out.append(q)
	for i in range(half.size() - 1, -1, -1):
		var q: Vector2 = half[i]
		if q.x > 0.0005:
			out.append(Vector2(-q.x, q.y))
	return out


## 车体截面（V 型龙骨 + 收窄的下车体 + 轮上翼子板舷台 + 顶面倒角），s 缩放宽度，k 缩放深度
static func _apc_sec(kz: float, wl: float, sp: float, sp_lo: float, sp_hi: float, wt: float, yt: float) -> PackedVector2Array:
	return _sym([Vector2(0.0, kz), Vector2(0.52, kz * 0.62), Vector2(wl, -0.05), Vector2(sp, sp_lo), Vector2(sp, sp_hi), Vector2(wt, yt)])


# ======================================================================
# 6×6 装甲运兵车残骸车体（车轮由调用方合批）
# ======================================================================
## p 的原点为车体中心（地面上 1.08m），车头朝 -Z。V 型防雷车体 + 倾斜风挡驾驶舱 + 翼子板 + 后舱门 + 车灯护笼
## + 发动机百叶 + 储物篮/油桶 + 遥控武器站 + 舱盖 + 天线 + 后视镜 + 备胎 + 拖钩 + 排气管。
static func build_apc_wreck(p: Node3D, m_hull: Material, m_sub: Material, m_dark: Material, m_bore: Material) -> void:
	var root := K.node(p, Vector3.ZERO, Vector3.ZERO, "APCHull")
	var m_st := K.gunmetal()
	var m_glass := A.glass(Color(0.10, 0.13, 0.14, 0.85))
	# 下车体
	var hull := loft_mesh([
		[-3.05, _apc_sec(-0.16, 0.78, 0.98, 0.0, 0.12, 0.84, 0.22)],
		[-2.65, _apc_sec(-0.46, 0.98, 1.30, 0.08, 0.38, 1.06, 0.56)],
		[-2.20, _apc_sec(-0.62, 1.02, 1.36, 0.10, 0.42, 1.12, 0.66)],
		[2.70, _apc_sec(-0.62, 1.02, 1.36, 0.10, 0.42, 1.12, 0.66)],
		[2.95, _apc_sec(-0.46, 0.98, 1.28, 0.10, 0.40, 1.04, 0.60)],
	])
	DM.add(root, hull, m_hull)
	# 驾驶/载员舱上层建筑（倾斜风挡）
	var cab_full := _sym([Vector2(1.06, 0.62), Vector2(1.00, 0.92), Vector2(0.84, 1.28)])
	var cab_low := _sym([Vector2(1.06, 0.62), Vector2(1.02, 0.66), Vector2(0.92, 0.69)])
	var cab_rear := _sym([Vector2(0.98, 0.62), Vector2(0.92, 0.90), Vector2(0.78, 1.20)])
	DM.add(root, loft_mesh([[-2.20, cab_low], [-1.15, cab_full], [2.62, cab_full], [2.80, cab_rear]]), m_sub)
	# 风挡（两块防弹玻璃 + 中立柱 + 外框）
	var sl := deg_to_rad(-28.9)
	var nrm := Vector3(0, 0.88, -0.48) * 0.012
	for gx in [-0.42, 0.42]:
		DM.add(root, A.bevel_box(Vector3(0.70, 0.02, 0.92), 0.008), m_glass, Vector3(gx, 0.985, -1.675) + nrm, Vector3(rad_to_deg(sl), 0, 0), Vector3.ONE, false)
		DM.add(root, A.bevel_box(Vector3(0.78, 0.03, 1.0), 0.01), m_dark, Vector3(gx, 0.985, -1.675), Vector3(rad_to_deg(sl), 0, 0))
	DM.add(root, A.bevel_box(Vector3(0.07, 0.05, 1.02), 0.012), m_sub, Vector3(0, 0.99, -1.675) + nrm, Vector3(rad_to_deg(sl), 0, 0))
	# 舱侧观察窗（每侧 3 块）+ 射击孔
	for sx in [-1.0, 1.0]:
		for k in 3:
			var wz := -0.75 + k * 1.05
			var win := K.node(root, Vector3(sx * 0.945, 1.05, wz), Vector3(0, 0, sx * -23.0))
			DM.add(win, A.bevel_box(Vector3(0.04, 0.24, 0.42), 0.01), m_dark)
			DM.add(win, A.bevel_box(Vector3(0.02, 0.18, 0.34), 0.006), m_glass, Vector3(sx * 0.012, 0, 0), Vector3.ZERO, Vector3.ONE, false)
			DM.add(root, DM.cyl(0.035, 0.05, -1.0, 20), m_bore, Vector3(sx * 1.035, 0.78, wz + 0.42), Vector3(0, 0, 90))
	# 翼子板（轮拱弧板）+ 挡泥皮
	for sx in [-1.0, 1.0]:
		for wz in [-2.05, 0.05, 2.05]:
			DM.add(root, fender_mesh(0.66, 0.08, 0.46), m_sub, Vector3(sx * 1.32, -0.52, wz), Vector3(0, 90, 0))
		DM.add(root, A.bevel_box(Vector3(0.40, 0.42, 0.025), 0.008), A.rubber(), Vector3(sx * 1.32, -0.62, 2.68))
	# 后舱门：门板 + 外框 + 铰链 + 把手 + 观察块 + 备胎
	var door := K.node(root, Vector3(0, 0.62, 2.81), Vector3.ZERO, "RearDoor")
	DM.add(door, A.bevel_box(Vector3(0.92, 1.08, 0.06), 0.02), m_hull, Vector3(0, 0.02, 0.0))
	DM.add(door, A.bevel_box(Vector3(1.00, 1.16, 0.03), 0.01), m_dark, Vector3(0, 0.02, -0.03))
	for hy in [-0.32, 0.38]:
		DM.add(door, DM.cyl(0.04, 0.16, -1.0, 20), m_st, Vector3(0.50, hy, 0.03))
	DM.rod(door, Vector3(-0.30, -0.05, 0.05), Vector3(-0.30, 0.18, 0.05), 0.018, A.chrome(), 16)
	for hy in [-0.05, 0.18]:
		DM.rod(door, Vector3(-0.30, hy, 0.03), Vector3(-0.30, hy, 0.06), 0.013, m_st, 16)
	DM.add(door, A.bevel_box(Vector3(0.22, 0.10, 0.05), 0.01), m_glass, Vector3(0, 0.38, 0.04), Vector3.ZERO, Vector3.ONE, false)
	var spare := K.node(root, Vector3(0.72, 0.68, 3.08), Vector3(90, 0, 0), "Spare")
	DM.add(spare, offroad_tire_mesh(0.46, 0.32), A.rubber())
	DM.add(spare, offroad_rim_mesh(0.46, 0.32), m_dark)
	DM.add(root, A.bevel_box(Vector3(0.10, 0.50, 0.24), 0.02), m_st, Vector3(0.72, 0.68, 2.92))
	# 车头：发动机百叶 + 车灯护笼 + 拖钩 + 防撞杠
	for k in 7:
		DM.add(root, A.bevel_box(Vector3(0.62, 0.025, 0.05), 0.006), m_dark, Vector3(0.42, 0.50 + k * 0.012, -2.95 + k * 0.08), Vector3(-30, 0, 0))
	DM.add(root, A.bevel_box(Vector3(0.68, 0.04, 0.62), 0.01), m_st, Vector3(0.42, 0.49, -2.72), Vector3(-30, 0, 0))
	for sx in [-1.0, 1.0]:
		var hl := K.node(root, Vector3(sx * 0.78, 0.10, -3.0), Vector3(-90, 0, 0))
		DM.add(hl, DM.lathe(PackedVector2Array([Vector2(0.0, -0.06), Vector2(0.09, -0.06), Vector2(0.10, 0.02), Vector2(0.085, 0.04), Vector2(0.0, 0.04)]), 24), m_dark)
		DM.add(hl, DM.cyl(0.075, 0.012, -1.0, 24), A.glass(Color(0.85, 0.8, 0.6, 0.6)), Vector3(0, 0.045, 0), Vector3.ZERO, Vector3.ONE, false)
		for gk in 3:
			DM.rod(root, Vector3(sx * 0.78 + (gk - 1) * 0.06, 0.20, -3.02), Vector3(sx * 0.78 + (gk - 1) * 0.06, 0.0, -3.12), 0.008, m_st, 16, false)
		DM.add(root, DM.torus(0.035, 0.07, 24, 16), m_st, Vector3(sx * 0.42, -0.14, -3.10), Vector3(0, 0, 90))
	DM.rod(root, Vector3(-0.95, -0.02, -3.12), Vector3(0.95, -0.02, -3.12), 0.045, m_dark, 24)
	for sx in [-0.62, 0.62]:
		DM.rod(root, Vector3(sx, -0.02, -3.12), Vector3(sx, -0.02, -2.98), 0.035, m_dark, 20)
	# 排气管（隔热罩 + 弯管）
	DM.add(root, A.pipe([Vector3(1.38, 0.20, -2.40), Vector3(1.46, 0.30, -2.30), Vector3(1.46, 1.05, -2.25), Vector3(1.40, 1.20, -2.20)], 0.045), m_dark)
	DM.add(root, A.bevel_box(Vector3(0.03, 0.55, 0.16), 0.01), m_st, Vector3(1.52, 0.72, -2.27))
	# 舷台储物篮 + 油桶
	for sx in [-1.0, 1.0]:
		for rz in [-1.0, 1.4]:
			DM.rod(root, Vector3(sx * 1.36, 0.55, rz - 0.55), Vector3(sx * 1.36, 0.55, rz + 0.55), 0.014, m_st, 16)
			for pk in 4:
				var pz: float = rz - 0.55 + pk * 0.366
				DM.rod(root, Vector3(sx * 1.36, 0.42, pz), Vector3(sx * 1.36, 0.55, pz), 0.012, m_st, 16, false)
	for k in 2:
		var jc := K.node(root, Vector3(-1.24, 0.62, 0.55 + k * 0.30), Vector3.ZERO)
		DM.add(jc, A.bevel_box(Vector3(0.16, 0.44, 0.26), 0.03), A.paint(Color(0.24, 0.27, 0.20), 0.3, 0.7, {"rust": 0.6}))
		DM.add(jc, A.bevel_box(Vector3(0.17, 0.30, 0.03), 0.01), m_dark, Vector3(0, -0.02, 0))
		DM.add(jc, DM.cyl(0.03, 0.05, -1.0, 16), m_dark, Vector3(0, 0.24, 0.07))
	# 遥控武器站（RWS）：座圈 + 托架 + 机枪 + 弹箱 + 光电球 + 烟幕弹
	var rws := K.node(root, Vector3(0.0, 1.28, 0.40), Vector3(0, 28, 6), "RWS")
	DM.add(rws, DM.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.46, 0.0), Vector2(0.46, 0.06), Vector2(0.40, 0.10), Vector2(0.30, 0.12), Vector2(0.0, 0.12)]), 40), m_dark)
	DM.bolts(rws, 0.42, 16, 0.065)
	var cradle := PackedVector2Array([Vector2(-0.30, 0.0), Vector2(0.34, 0.0), Vector2(0.34, 0.18), Vector2(0.18, 0.40), Vector2(-0.12, 0.40), Vector2(-0.30, 0.22)])
	for sx in [-0.18, 0.18]:
		DM.add(rws, A.prism(cradle, 0.05, 0.012), m_sub, Vector3(sx, 0.12, 0), Vector3(0, 90, 0))
	DM.add(rws, DM.cyl(0.07, 0.40, -1.0, 24), m_st, Vector3(0, 0.40, 0), Vector3(0, 0, 90))
	DM.add(rws, A.bevel_box(Vector3(0.20, 0.18, 0.62), 0.03), m_dark, Vector3(0, 0.42, -0.05), Vector3(4, 0, 0))
	DM.add(rws, gun_barrel_mesh(1.05, 0.022), m_dark, Vector3(0, 0.44, -0.30), Vector3(-94, 0, 0))
	DM.add(rws, A.bevel_box(Vector3(0.16, 0.20, 0.30), 0.025), A.paint(Color(0.28, 0.30, 0.22), 0.3, 0.7), Vector3(0.24, 0.36, 0.06))
	DM.add(rws, A.bevel_box(Vector3(0.18, 0.20, 0.22), 0.04), m_dark, Vector3(-0.32, 0.56, -0.02))
	for gy in [0.52, 0.60]:
		DM.add(rws, DM.cyl(0.035, 0.02, -1.0, 20), m_glass, Vector3(-0.32, gy, -0.13), Vector3(90, 0, 0), Vector3.ONE, false)
	for gk in 3:
		DM.add(rws, DM.cyl(0.04, 0.20, -1.0, 20), m_sub, Vector3(0.30, 0.20 + gk * 0.09, 0.22), Vector3(-55, 0, 25))
	# 舱盖（一开一关）+ 天线 + 后视镜
	DM.add(root, DM.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.36, 0.0), Vector2(0.34, 0.06), Vector2(0.0, 0.07)]), 32), m_hull, Vector3(0.0, 1.28, 1.70))
	var hatch := K.node(root, Vector3(-0.30, 1.28, -0.70), Vector3(0, 0, -105))
	DM.add(hatch, DM.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.28, 0.0), Vector2(0.26, 0.05), Vector2(0.0, 0.06)]), 32), m_hull, Vector3(0.28, 0, 0))
	DM.add(root, DM.torus(0.26, 0.30, 32, 16), m_dark, Vector3(-0.30, 1.29, -0.70))
	for ax in [-0.82, 0.82]:
		var ab := Vector3(ax, 1.20, 2.55)
		DM.add(root, DM.cyl(0.05, 0.10, 0.06, 20), m_dark, ab)
		for k in 4:
			DM.add(root, DM.torus(0.014, 0.03, 20, 16), m_dark, ab + Vector3(0, 0.07 + k * 0.024, 0), Vector3.ZERO, Vector3.ONE, false)
		DM.add(root, DM.cyl(0.006, 2.1, 0.014, 16), m_st, ab + Vector3(0, 1.18, 0.12), Vector3(6, 0, 0), Vector3.ONE, false)
	for sx in [-1.0, 1.0]:
		var m0 := Vector3(sx * 1.00, 0.86, -1.95)
		DM.rod(root, m0, m0 + Vector3(sx * 0.32, 0.18, -0.06), 0.014, m_st, 16)
		DM.add(root, A.bevel_box(Vector3(0.05, 0.26, 0.17), 0.02), m_dark, m0 + Vector3(sx * 0.34, 0.24, -0.07), Vector3(0, sx * 15.0, 0))


## 翼子板弧板：沿 Z 厚 w 的半环（轮心在原点，内半径 r，板厚 t），从水平前方翻到后方（180°）
static func fender_mesh(r: float, t: float, w: float) -> ArrayMesh:
	var key := "fender2%.3f|%.3f|%.3f" % [r, t, w]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 24
	var h := w * 0.5
	var lip := t * 0.6
	for i in n:
		var a0 := PI * float(i) / n
		var a1 := PI * float(i + 1) / n
		var d0 := Vector3(cos(a0), sin(a0), 0)
		var d1 := Vector3(cos(a1), sin(a1), 0)
		var dm := (d0 + d1).normalized()
		var ro := r + t
		# 外弧面 / 内弧面
		for q in [[ro, dm], [r, -dm]]:
			var rr: float = q[0]
			var o: Vector3 = q[1]
			var p00 := d0 * rr + Vector3(0, 0, -h)
			var p10 := d1 * rr + Vector3(0, 0, -h)
			var p11 := d1 * rr + Vector3(0, 0, h)
			var p01 := d0 * rr + Vector3(0, 0, h)
			_tri_out(st, p00, p10, p11, o)
			_tri_out(st, p00, p11, p01, o)
		# 两侧板边 + 外沿卷边
		for sz in [-1.0, 1.0]:
			var z: float = sz * h
			var o2 := Vector3(0, 0, float(sz))
			_tri_out(st, d0 * r + Vector3(0, 0, z), d1 * r + Vector3(0, 0, z), d1 * (ro + lip) + Vector3(0, 0, z), o2)
			_tri_out(st, d0 * r + Vector3(0, 0, z), d1 * (ro + lip) + Vector3(0, 0, z), d0 * (ro + lip) + Vector3(0, 0, z), o2)
			var zi: float = z - sz * t
			_tri_out(st, d0 * ro + Vector3(0, 0, zi), d1 * ro + Vector3(0, 0, zi), d1 * (ro + lip) + Vector3(0, 0, zi), -o2)
			_tri_out(st, d0 * ro + Vector3(0, 0, zi), d1 * (ro + lip) + Vector3(0, 0, zi), d0 * (ro + lip) + Vector3(0, 0, zi), -o2)
			_tri_out(st, d0 * (ro + lip) + Vector3(0, 0, z), d1 * (ro + lip) + Vector3(0, 0, z), d1 * (ro + lip) + Vector3(0, 0, zi), dm)
			_tri_out(st, d0 * (ro + lip) + Vector3(0, 0, z), d1 * (ro + lip) + Vector3(0, 0, zi), d0 * (ro + lip) + Vector3(0, 0, zi), dm)
	# 两端截面
	for e in [[0.0, Vector3(0, -1, 0)], [PI, Vector3(0, -1, 0)]]:
		var d := Vector3(cos(float(e[0])), sin(float(e[0])), 0)
		var o3: Vector3 = e[1]
		_tri_out(st, d * r + Vector3(0, 0, -h), d * (r + t) + Vector3(0, 0, -h), d * (r + t) + Vector3(0, 0, h), o3)
		_tri_out(st, d * r + Vector3(0, 0, -h), d * (r + t) + Vector3(0, 0, h), d * r + Vector3(0, 0, h), o3)
	st.generate_tangents()
	var m := st.commit()
	_cache[key] = m
	return m


# ======================================================================
# 主战坦克残骸：放样车体 + 放样楔形炮塔（履带/负重轮由调用方合批）
# ======================================================================
## 车体截面：平底 + 收窄下车体 + 履带上方舷台 + 顶面倒角。yb 底面、yt 顶面、ws 舷台半宽
static func _tank_sec(yb: float, yt: float, ws: float) -> PackedVector2Array:
	var ys := minf(0.12, yt - 0.10)
	return _sym([Vector2(0.0, yb), Vector2(0.92, yb), Vector2(1.05, yb + 0.12), Vector2(1.05, ys), Vector2(ws, ys), Vector2(ws, yt - 0.06), Vector2(ws - 0.08, yt), Vector2(0.0, yt)])


## 车体：p 原点为车体中心（地面上 1.1m），车头 -Z。倾斜首上/首下装甲 + 舷台 + 分段侧裙板（一块脱落一块翘起）
## + 首上反应装甲块 + 驾驶员舱盖与潜望镜 + 车灯护笼 + 动力舱百叶 + 尾部油桶 + 拖缆 + 工具 + 拖钩 + 座圈
static func build_tank_hull(p: Node3D, m_hull: Material, m_sub: Material, m_dark: Material, m_bore: Material) -> void:
	var root := K.node(p, Vector3.ZERO, Vector3.ZERO, "TankHull")
	var m_st := K.gunmetal()
	DM.add(root, loft_mesh([
		[-3.25, _tank_sec(-0.32, -0.16, 1.62)],
		[-2.80, _tank_sec(-0.78, 0.02, 1.78)],
		[-1.70, _tank_sec(-0.84, 0.36, 1.80)],
		[2.85, _tank_sec(-0.84, 0.36, 1.80)],
		[3.12, _tank_sec(-0.62, 0.30, 1.74)],
	]), m_hull)
	# 首上反应装甲（3×2 块，带螺栓）
	var gl := K.node(root, Vector3(0, 0.12, -2.45), Vector3(rad_to_deg(atan2(0.52, 1.55)) * -1.0 + 0.0, 0, 0))
	gl.rotation_degrees.x = -rad_to_deg(atan2(0.52, 1.55))
	for ix in 4:
		for iz in 2:
			var bp := Vector3(-0.78 + ix * 0.52, 0.07, -0.30 + iz * 0.62)
			DM.add(gl, A.bevel_box(Vector3(0.48, 0.10, 0.56), 0.02), m_sub, bp)
			for c in [Vector2(-0.18, -0.21), Vector2(0.18, -0.21), Vector2(-0.18, 0.21), Vector2(0.18, 0.21)]:
				DM.add(gl, DM.cyl(0.022, 0.03, -1.0, 6), m_st, bp + Vector3(c.x, 0.06, c.y), Vector3.ZERO, Vector3.ONE, false)
	# 驾驶员舱盖 + 三具潜望镜
	DM.add(root, DM.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.30, 0.0), Vector2(0.29, 0.05), Vector2(0.22, 0.08), Vector2(0.0, 0.08)]), 32), m_sub, Vector3(0.0, 0.36, -1.55))
	for k in 3:
		var pz := K.node(root, Vector3((k - 1) * 0.22, 0.36, -1.86), Vector3(0, (k - 1) * -18.0, 0))
		DM.add(pz, A.bevel_box(Vector3(0.16, 0.10, 0.10), 0.015), m_dark, Vector3(0, 0.05, 0))
		DM.add(pz, A.bevel_box(Vector3(0.12, 0.05, 0.012), 0.004), A.glass(Color(0.2, 0.3, 0.3, 0.7)), Vector3(0, 0.06, -0.052), Vector3.ZERO, Vector3.ONE, false)
	# 车灯（护笼）+ 首下拖钩
	for sx in [-1.0, 1.0]:
		var hl := K.node(root, Vector3(sx * 1.38, 0.0, -3.0), Vector3(-90, 0, 0))
		DM.add(hl, DM.lathe(PackedVector2Array([Vector2(0.0, -0.05), Vector2(0.08, -0.05), Vector2(0.09, 0.03), Vector2(0.075, 0.05), Vector2(0.0, 0.05)]), 24), m_dark)
		DM.add(hl, DM.cyl(0.065, 0.01, -1.0, 24), A.glass(Color(0.85, 0.8, 0.6, 0.6)), Vector3(0, 0.055, 0), Vector3.ZERO, Vector3.ONE, false)
		for gk in 3:
			DM.rod(root, Vector3(sx * 1.38 + (gk - 1) * 0.05, 0.10, -3.0), Vector3(sx * 1.38 + (gk - 1) * 0.05, 0.0, -3.13), 0.008, m_st, 16, false)
		var hk := K.node(root, Vector3(sx * 0.62, -0.40, -3.12), Vector3.ZERO)
		DM.add(hk, A.bevel_box(Vector3(0.16, 0.22, 0.14), 0.03), m_sub)
		DM.add(hk, DM.torus(0.04, 0.08, 24, 16), m_st, Vector3(0, -0.04, -0.10), Vector3(0, 0, 90))
	# 分段侧裙板：每侧 6 块，带上缘铰链和螺栓；左侧第 3 块脱落、右侧最后一块翘起
	for sx in [-1.0, 1.0]:
		DM.rod(root, Vector3(sx * 1.83, 0.14, -2.85), Vector3(sx * 1.83, 0.14, 2.85), 0.025, m_dark, 16)
		for k in 6:
			if sx < 0.0 and k == 2:
				continue
			var kz := -2.42 + k * 0.97
			var tilt := 0.0
			if sx > 0.0 and k == 5:
				tilt = 38.0
			var sk := K.node(root, Vector3(sx * 1.84, 0.12, kz), Vector3(0, 0, sx * tilt))
			DM.add(sk, A.bevel_box(Vector3(0.05, 0.64, 0.94), 0.015), m_hull, Vector3(0, -0.32, 0))
			DM.add(sk, A.bevel_box(Vector3(0.06, 0.06, 0.94), 0.012), m_sub, Vector3(0, -0.64, 0))
			for bz in [-0.36, 0.0, 0.36]:
				DM.add(sk, DM.cyl(0.02, 0.025, -1.0, 6), m_st, Vector3(sx * 0.035, -0.06, bz), Vector3(0, 0, 90), Vector3.ONE, false)
	# 动力舱：两组百叶格栅 + 检修口盖 + 吊环
	for gx in [-0.55, 0.55]:
		DM.add(root, A.bevel_box(Vector3(0.86, 0.03, 1.50), 0.01), m_dark, Vector3(gx, 0.37, 2.0))
		for k in 9:
			DM.add(root, A.bevel_box(Vector3(0.80, 0.03, 0.06), 0.008), m_sub, Vector3(gx, 0.39, 1.33 + k * 0.165), Vector3(-25, 0, 0), Vector3.ONE, false)
	for c in [Vector3(-1.4, 0.37, 0.9), Vector3(1.4, 0.37, 0.9), Vector3(-1.4, 0.37, 2.6), Vector3(1.4, 0.37, 2.6)]:
		DM.add(root, DM.torus(0.035, 0.06, 20, 16), m_st, c + Vector3(0, 0.04, 0), Vector3(90, 0, 0), Vector3.ONE, false)
	# 尾部：排气格栅 + 两个外挂油桶（车削，带加强筋）+ 尾灯
	DM.add(root, A.bevel_box(Vector3(1.6, 0.36, 0.04), 0.01), m_dark, Vector3(0, -0.12, 3.12))
	for k in 6:
		DM.add(root, A.bevel_box(Vector3(1.52, 0.03, 0.05), 0.008), m_sub, Vector3(0, -0.26 + k * 0.056, 3.14), Vector3(30, 0, 0), Vector3.ONE, false)
	var drum := DM.lathe(PackedVector2Array([Vector2(0.0, -0.34), Vector2(0.19, -0.34), Vector2(0.21, -0.32), Vector2(0.21, -0.14), Vector2(0.22, -0.12), Vector2(0.21, -0.10), Vector2(0.21, 0.10), Vector2(0.22, 0.12), Vector2(0.21, 0.14), Vector2(0.21, 0.32), Vector2(0.19, 0.34), Vector2(0.0, 0.34)]), 32)
	for sx in [-1.0, 1.0]:
		DM.add(root, drum, A.paint(Color(0.26, 0.28, 0.20), 0.3, 0.72, {"rust": 0.7}), Vector3(sx * 0.80, 0.58, 3.30), Vector3(0, 0, 90))
		for bx in [-0.24, 0.24]:
			DM.add(root, DM.torus(0.205, 0.225, 32, 12), m_dark, Vector3(sx * 0.80 + bx, 0.58, 3.30), Vector3(0, 0, 90), Vector3.ONE, false)
		DM.add(root, A.bevel_box(Vector3(0.14, 0.08, 0.04), 0.012), A.glass(Color(0.6, 0.08, 0.05, 0.8)), Vector3(sx * 1.55, 0.16, 3.13), Vector3.ZERO, Vector3.ONE, false)
	DM.add(root, A.bevel_box(Vector3(1.8, 0.05, 0.36), 0.01), m_dark, Vector3(0, 0.37, 3.04))
	for sx in [-1.0, 1.0]:
		DM.rod(root, Vector3(sx * 0.80 - 0.34, 0.36, 3.14), Vector3(sx * 0.80 - 0.34, 0.58, 3.52), 0.016, m_dark, 12)
		DM.rod(root, Vector3(sx * 0.80 + 0.34, 0.36, 3.14), Vector3(sx * 0.80 + 0.34, 0.58, 3.52), 0.016, m_dark, 12)
	# 拖缆（左侧舷台，两端钢眼）+ 撬棍/铁锹
	var cab: Array = []
	for k in 9:
		var t := float(k) / 8.0
		cab.append(Vector3(-1.58 + sin(t * 9.0) * 0.03, 0.40, -1.4 + t * 3.6))
	DM.add(root, A.pipe(cab, 0.03), m_dark)
	for e in [cab[0], cab[cab.size() - 1]]:
		DM.add(root, DM.torus(0.04, 0.065, 20, 16), m_st, e + Vector3(0, 0.02, 0), Vector3(90, 0, 0))
	DM.rod(root, Vector3(1.55, 0.40, -1.2), Vector3(1.55, 0.40, 0.4), 0.018, m_st, 16)
	DM.add(root, A.bevel_box(Vector3(0.20, 0.02, 0.26), 0.01), m_st, Vector3(1.55, 0.40, 0.55))
	DM.rod(root, Vector3(1.32, 0.39, -1.0), Vector3(1.32, 0.39, 0.6), 0.02, m_dark, 16)
	# 座圈
	DM.add(root, DM.lathe(PackedVector2Array([Vector2(1.05, 0.0), Vector2(1.18, 0.0), Vector2(1.18, 0.10), Vector2(1.05, 0.10)]), 48), m_dark, Vector3(0.08, 0.34, -0.25))


## 炮塔：楔形放样（倾斜前脸 + 尾舱）+ 防盾 + 主炮 + 车长指挥塔 + 装填手舱盖与机枪 + 炮长瞄准镜 + 侧风传感器 + 天线 + 烟幕弹 + 尾筐
static func build_tank_turret(tur: Node3D, m_hull: Material, m_sub: Material, m_dark: Material, m_bore: Material) -> void:
	var m_st := K.gunmetal()
	var m_glass := A.glass(Color(0.12, 0.2, 0.22, 0.85))
	var sec := func(yb: float, yt: float, wb: float, wm: float, wt: float) -> PackedVector2Array:
		return _sym([Vector2(0.0, yb), Vector2(wb, yb), Vector2(wm, (yb + yt) * 0.45), Vector2(wt, yt), Vector2(0.0, yt)])
	DM.add(tur, loft_mesh([
		[-1.62, sec.call(-0.30, 0.22, 0.42, 0.46, 0.36)],
		[-0.70, sec.call(-0.36, 0.40, 1.14, 1.22, 1.00)],
		[1.10, sec.call(-0.36, 0.40, 1.14, 1.20, 1.00)],
		[1.55, sec.call(-0.12, 0.38, 1.00, 1.06, 0.90)],
		[2.15, sec.call(-0.04, 0.34, 0.88, 0.92, 0.80)],
	]), m_hull)
	# 防盾（放样圆角块）+ 主炮
	var mk := func(w: float, h: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 16:
			var a := TAU * float(i) / 16.0
			pts.append(Vector2(clampf(cos(a) * 1.4, -1, 1) * w, clampf(sin(a) * 1.4, -1, 1) * h + 0.02))
		return pts
	DM.add(tur, loft_mesh([[-1.86, mk.call(0.24, 0.20)], [-1.70, mk.call(0.30, 0.25)], [-1.45, mk.call(0.32, 0.27)]]), m_sub)
	DM.add(tur, gun_barrel_mesh(4.6, 0.085), m_sub, Vector3(0, 0.02, -1.80), Vector3(-90, 0, 0))
	DM.add(tur, DM.cyl(0.075, 0.03, -1.0, 24), m_bore, Vector3(0, 0.02, -1.80 - 4.6), Vector3(90, 0, 0), Vector3.ONE, false)
	# 并列机枪口 + 炮长瞄准镜（棱柱罩 + 两块镜片）
	DM.add(tur, DM.cyl(0.03, 0.06, -1.0, 16), m_bore, Vector3(0.42, 0.0, -1.32), Vector3(90, 0, 0), Vector3.ONE, false)
	var sight := PackedVector2Array([Vector2(-0.20, 0.0), Vector2(0.22, 0.0), Vector2(0.22, 0.22), Vector2(0.0, 0.34), Vector2(-0.20, 0.26)])
	DM.add(tur, A.prism(sight, 0.34, 0.02), m_sub, Vector3(0.62, 0.40, -0.62), Vector3(0, 90, 0))
	for gx in [0.54, 0.70]:
		DM.add(tur, A.bevel_box(Vector3(0.12, 0.14, 0.012), 0.004), m_glass, Vector3(gx, 0.52, -0.83), Vector3(-10, 0, 0), Vector3.ONE, false)
	# 车长指挥塔（车削）+ 潜望镜 + 炸开的舱盖
	var cup := Vector3(-0.52, 0.40, 0.15)
	DM.add(tur, DM.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.44, 0.0), Vector2(0.42, 0.14), Vector2(0.36, 0.20), Vector2(0.30, 0.20), Vector2(0.30, 0.16), Vector2(0.0, 0.16)]), 36), m_sub, cup)
	for pk in 6:
		var pa := TAU * float(pk) / 6.0
		var pn := K.node(tur, cup + Vector3(cos(pa) * 0.39, 0.10, sin(pa) * 0.39), Vector3(0, rad_to_deg(-pa) + 90.0, 0))
		DM.add(pn, A.bevel_box(Vector3(0.12, 0.08, 0.06), 0.012), m_dark)
		DM.add(pn, A.bevel_box(Vector3(0.09, 0.04, 0.01), 0.003), m_glass, Vector3(0, 0, -0.032), Vector3.ZERO, Vector3.ONE, false)
	var ch := K.node(tur, cup + Vector3(-0.30, 0.20, 0), Vector3(0, 0, 62))
	DM.add(ch, DM.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.30, 0.0), Vector2(0.29, 0.05), Vector2(0.22, 0.08), Vector2(0.0, 0.08)]), 32), m_hull, Vector3(-0.30, 0, 0))
	DM.add(tur, DM.cyl(0.04, 0.10, -1.0, 16), m_st, cup + Vector3(-0.32, 0.18, 0), Vector3(90, 0, 0))
	# 装填手舱盖 + 环形枪架机枪
	var lh := Vector3(0.50, 0.40, 0.35)
	DM.add(tur, DM.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.30, 0.0), Vector2(0.29, 0.06), Vector2(0.20, 0.09), Vector2(0.0, 0.09)]), 32), m_sub, lh)
	DM.add(tur, DM.torus(0.33, 0.36, 36, 12), m_dark, lh + Vector3(0, 0.20, 0))
	for k in 3:
		var a := TAU * float(k) / 3.0 + 0.4
		DM.rod(tur, lh + Vector3(cos(a) * 0.30, 0.04, sin(a) * 0.30), lh + Vector3(cos(a) * 0.345, 0.20, sin(a) * 0.345), 0.012, m_dark, 12, false)
	var mg := K.node(tur, lh + Vector3(0.0, 0.28, -0.30), Vector3(-6, 12, 0))
	DM.add(mg, A.bevel_box(Vector3(0.10, 0.12, 0.42), 0.02), m_dark)
	DM.add(mg, gun_barrel_mesh(0.62, 0.012), m_dark, Vector3(0, 0.01, -0.20), Vector3(-90, 0, 0))
	DM.add(mg, A.bevel_box(Vector3(0.12, 0.12, 0.16), 0.02), A.paint(Color(0.28, 0.30, 0.22), 0.3, 0.7), Vector3(0.11, -0.04, 0.0))
	# 侧风传感器 + 天线
	DM.rod(tur, Vector3(0.0, 0.40, 1.15), Vector3(0.0, 0.85, 1.15), 0.015, m_st, 16)
	DM.add(tur, DM.sphere(0.04, 16), m_dark, Vector3(0.0, 0.88, 1.15))
	for ax in [-0.72, 0.72]:
		var ab := Vector3(ax, 0.36, 1.55)
		DM.add(tur, DM.cyl(0.05, 0.10, 0.06, 20), m_dark, ab + Vector3(0, 0.05, 0))
		DM.add(tur, DM.cyl(0.006, 2.2, 0.014, 16), m_st, ab + Vector3(0, 1.20, 0.10), Vector3(5, 0, 0), Vector3.ONE, false)
	# 烟幕弹发射器组（两侧各 4 管，车削弹筒）
	for sx2 in [-1.0, 1.0]:
		DM.add(tur, A.bevel_box(Vector3(0.10, 0.22, 0.48), 0.02), m_sub, Vector3(sx2 * 1.10, 0.20, -0.62))
		for gi in 4:
			DM.add(tur, DM.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.055, 0.0), Vector2(0.055, 0.20), Vector2(0.045, 0.22), Vector2(0.0, 0.22)]), 20), m_sub, Vector3(sx2 * 1.16, 0.26, -0.80 + gi * 0.12), Vector3(-60, 0, sx2 * -30.0))
	# 尾舱物资筐
	for bx2 in 5:
		DM.rod(tur, Vector3(-0.8 + bx2 * 0.4, 0.34, 2.16), Vector3(-0.8 + bx2 * 0.4, 0.62, 2.40), 0.018, m_dark, 12)
	DM.rod(tur, Vector3(-0.85, 0.62, 2.40), Vector3(0.85, 0.62, 2.40), 0.02, m_dark, 12)
	DM.rod(tur, Vector3(-0.85, 0.44, 2.30), Vector3(0.85, 0.44, 2.30), 0.02, m_dark, 12)
	for c in [-0.85, 0.85]:
		DM.rod(tur, Vector3(c, 0.62, 2.40), Vector3(c * 0.95, 0.40, 1.60), 0.02, m_dark, 12)
	DM.add(tur, A.bevel_box(Vector3(0.62, 0.22, 0.34), 0.05), A.paint(Color(0.30, 0.28, 0.20), 0.2, 0.9), Vector3(-0.35, 0.50, 1.95), Vector3(0, 8, 0))
