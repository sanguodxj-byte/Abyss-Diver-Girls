extends RefCounted
## 技能 / 战术部署装置与首领弹幕的高精建模库（low_poly_model_audit.md 批次 1 整改）。
## 规范：所有可见圆形构件 seg ≥ 16（中型 ≥ 24），圆环自建 TorusMesh（管截面 ≥ 16），
## 扫描管 seg ≥ 12 / sub ≥ 10，禁止裸 BoxMesh / PrismMesh；硬表面一律带倒角。
## 这里只负责「长什么样」：逻辑脚本调用对应 build_* 把模型挂到自己身上，返回需要动画的节点。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")

static var _cache := {}


# ---------------------------------------------------------------- 基础件
## 高细分圆环（绕局部 Y 轴，躺在 XZ 面）。inner/outer 为到环管内外缘的半径。
static func torus(inner: float, outer: float, rings := 32, ring_segs := 16) -> TorusMesh:
	var mob := A.is_mobile_perf()
	var r := maxi(rings, 18 if mob else 24)
	var rs := maxi(ring_segs, 12 if mob else 16)
	var key := "dt%.3f|%.3f|%d|%d" % [inner, outer, r, rs]
	if _cache.has(key):
		return _cache[key]
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = r
	t.ring_segments = rs
	_cache[key] = t
	return t


## 高细分圆柱 / 圆台（直接构建，不经 art.cyl 的上限钳制），轴沿局部 Y
static func cyl(r: float, h: float, r2 := -1.0, seg := 24, rings := 1) -> CylinderMesh:
	var s := maxi(seg, 12 if A.is_mobile_perf() else 16)
	if A.is_mobile_perf():
		s = maxi(12, int(s * 0.75))
	var key := "dc%.4f|%.4f|%.4f|%d|%d" % [r, h, r2, s, rings]
	if _cache.has(key):
		return _cache[key]
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r if r2 < 0.0 else r2
	c.height = h
	c.radial_segments = s
	c.rings = rings
	_cache[key] = c
	return c


static func sphere(r: float, seg := 24, hgt := -1.0) -> SphereMesh:
	var s := maxi(seg, 20 if r < 0.15 else 32)
	if A.is_mobile_perf():
		s = maxi(16, int(s * 0.75))
	var key := "ds%.4f|%.4f|%d" % [r, hgt, s]
	if _cache.has(key):
		return _cache[key]
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0 if hgt < 0.0 else hgt
	m.radial_segments = s
	m.rings = maxi(10, s / 2)
	_cache[key] = m
	return m


## 车削体：profile 为 (半径, 高度) 自下而上的折线，绕 Y 轴旋转 seg 段，平滑法线（导弹头锥、喇叭口、喷管）
static func lathe(profile: PackedVector2Array, seg := 32, cap_bottom := true, cap_top := true) -> ArrayMesh:
	var s := seg if not A.is_mobile_perf() else maxi(16, int(seg * 0.75))
	var key := "dl%s|%d|%s|%s" % [profile, s, cap_bottom, cap_top]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := profile.size()
	# 每个剖面点的二维法线（沿剖面切线的垂直方向，取相邻段平均）
	var nrm2: Array = []
	for i in n:
		var p0 := profile[maxi(i - 1, 0)]
		var p1 := profile[mini(i + 1, n - 1)]
		var t := (p1 - p0).normalized()
		nrm2.append(Vector2(t.y, -t.x))
	var vlen := 0.0
	var vcoord: Array = [0.0]
	for i in range(1, n):
		vlen += profile[i].distance_to(profile[i - 1])
		vcoord.append(vlen)
	for i in n - 1:
		for j in s:
			var a0 := TAU * float(j) / s
			var a1 := TAU * float(j + 1) / s
			var quad := [[i, a0, j], [i, a1, j + 1], [i + 1, a1, j + 1], [i + 1, a0, j]]
			var verts: Array = []
			for q in quad:
				var pi: int = q[0]
				var ang: float = q[1]
				var pr: Vector2 = profile[pi]
				var nn: Vector2 = nrm2[pi]
				verts.append([Vector3(cos(ang) * pr.x, pr.y, sin(ang) * pr.x), Vector3(cos(ang) * nn.x, nn.y, sin(ang) * nn.x).normalized(),
					Vector2(float(q[2]) / s, float(vcoord[pi]) / maxf(vlen, 0.001))])
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(verts[k][1])
				st.set_uv(verts[k][2])
				st.add_vertex(verts[k][0])
	for e in [[cap_bottom, 0, -1.0], [cap_top, n - 1, 1.0]]:
		if not e[0]:
			continue
		var pr2: Vector2 = profile[e[1]]
		if pr2.x < 0.0005:
			continue
		var dn: float = e[2]
		for j in s:
			var a0 := TAU * float(j) / s
			var a1 := TAU * float(j + 1) / s
			var c := Vector3(0, pr2.y, 0)
			var v0 := Vector3(cos(a0) * pr2.x, pr2.y, sin(a0) * pr2.x)
			var v1 := Vector3(cos(a1) * pr2.x, pr2.y, sin(a1) * pr2.x)
			var tri := [c, v0, v1] if dn < 0.0 else [c, v1, v0]
			for v in tri:
				st.set_normal(Vector3(0, dn, 0))
				st.set_uv(Vector2((v as Vector3).x, (v as Vector3).z) * 0.5 + Vector2(0.5, 0.5))
				st.add_vertex(v)
	st.generate_tangents()
	var m := st.commit()
	_cache[key] = m
	return m


## 高精平滑管（Catmull-Rom），截面 ≥ 14 边、路径 ≥ 10 段
static func tube(pts: Array, r: float, seg := 16, sub := 10) -> ArrayMesh:
	var mob := A.is_mobile_perf()
	return A.tube(pts, r, maxi(seg, 10 if mob else 14), maxi(sub, 6 if mob else 10))


static func add(p: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE, shadow := true) -> MeshInstance3D:
	return A.add(p, mesh, m, pos, rot, scl, shadow)


## 把节点的局部 +Y 对准 a→b 方向，原点放在 a
static func _aim(p: Node3D, a: Vector3, b: Vector3) -> Node3D:
	var n := Node3D.new()
	p.add_child(n)
	n.position = a
	var y := (b - a).normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	n.basis = Basis(x, y, z)
	return n


## 两点之间的高细分圆杆（沿 a→b）
static func rod(p: Node3D, a: Vector3, b: Vector3, r: float, m: Material, seg := 20, shadow := true) -> MeshInstance3D:
	var n := _aim(p, a, b)
	return add(n, cyl(r, a.distance_to(b), -1.0, seg), m, Vector3(0, a.distance_to(b) * 0.5, 0), Vector3.ZERO, Vector3.ONE, shadow)


## 液压作动筒：缸筒 + 端盖 + 镀铬活塞杆 + 两端耳环（全部 ≥ 20 段）
static func piston(p: Node3D, a: Vector3, b: Vector3, r := 0.03) -> void:
	var n := _aim(p, a, b)
	var L := a.distance_to(b)
	add(n, cyl(r * 1.7, L * 0.55, -1.0, 24), K.gunmetal(), Vector3(0, L * 0.30, 0))
	add(n, cyl(r * 1.95, L * 0.05, -1.0, 24), K.dark(), Vector3(0, L * 0.05, 0))
	add(n, cyl(r * 1.95, L * 0.04, -1.0, 24), K.brass(), Vector3(0, L * 0.57, 0))
	add(n, cyl(r, L * 0.45, -1.0, 20), A.chrome(), Vector3(0, L * 0.78, 0))
	for y in [0.0, L]:
		add(n, torus(r * 0.5, r * 1.25, 24, 16), K.dark(), Vector3(0, y, 0), Vector3(0, 0, 90))


## 环形螺栓圈（六角螺母 r≤0.03 属白名单，保留 seg=6 的真实六角头）
static func bolts(p: Node3D, ring_r: float, n: int, y: float, bolt_r := 0.014) -> void:
	var mesh := A.cyl(bolt_r, bolt_r * 1.3, bolt_r * 1.1, 6, true)
	for i in n:
		var a := TAU * float(i) / n
		add(p, mesh, A.chrome(), Vector3(cos(a) * ring_r, y, sin(a) * ring_r), Vector3.ZERO, Vector3.ONE, false)


## 护笼频闪灯：底座 + 发光灯芯 + 玻璃罩 + 竖向护笼条 + 上下护环。返回灯芯（供脉冲缩放）
static func caged_lamp(p: Node3D, pos: Vector3, r: float, h: float, c: Color, energy := 2.6) -> MeshInstance3D:
	var g := K.node(p, pos)
	add(g, cyl(r * 1.35, h * 0.16, r * 1.5, 28), K.dark(), Vector3(0, h * 0.08, 0))
	var lamp := add(g, cyl(r * 0.62, h * 0.62, -1.0, 24), A.emit(c, energy), Vector3(0, h * 0.48, 0), Vector3.ZERO, Vector3.ONE, false)
	add(g, sphere(r * 0.62, 24), A.emit(c, energy), Vector3(0, h * 0.79, 0), Vector3.ZERO, Vector3.ONE, false)
	add(g, cyl(r * 0.92, h * 0.66, -1.0, 28), A.glass(Color(c.r, c.g, c.b, 0.22)), Vector3(0, h * 0.49, 0), Vector3.ZERO, Vector3.ONE, false)
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		add(g, cyl(r * 0.09, h * 0.84, -1.0, 16), K.gunmetal(), Vector3(cos(a) * r * 1.12, h * 0.56, sin(a) * r * 1.12), Vector3.ZERO, Vector3.ONE, false)
	for y in [h * 0.22, h * 0.97]:
		add(g, torus(r * 1.04, r * 1.22, 32, 16), K.gunmetal(), Vector3(0, y, 0), Vector3.ZERO, Vector3.ONE, false)
	add(g, cyl(r * 0.5, h * 0.06, r * 1.24, 28), K.dark(), Vector3(0, h * 1.0, 0))
	return lamp


## 警示条：黄黑斜纹倒角薄板
static func hazard_band(p: Node3D, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	add(p, A.bevel_box(size, minf(0.008, size.z * 0.3)), A.hazard(), pos, rot, Vector3.ONE, false)


# ======================================================================
# P0-SKL-01 撤离屏障：重工野战力场桩
# ======================================================================
## 单根力场桩（高约 1.75m）。返回 {"lamps": [...], "emit_top": Vector3}
static func build_barrier_post(p: Node3D, field: Color) -> Dictionary:
	var steel := A.paint(Color(0.30, 0.32, 0.30), 0.42, 0.48, {"wear": 0.42, "rust": 0.16, "dust": 0.22})
	var olive := A.paint(Color(0.29, 0.31, 0.25), 0.22, 0.52, {"wear": 0.38, "dust": 0.25})
	var lamps: Array = []
	# --- 三脚锚定钢爪基座：倒角切角爪板 + 锥形地钉 + 加强肋
	add(p, cyl(0.20, 0.10, 0.25, 36), K.dark(), Vector3(0, 0.05, 0))
	add(p, torus(0.19, 0.235, 36, 16), steel, Vector3(0, 0.10, 0))
	bolts(p, 0.215, 8, 0.115)
	for i in 3:
		var a := TAU * float(i) / 3.0 + PI / 6.0
		var leg := K.node(p, Vector3(cos(a) * 0.17, 0.0, sin(a) * 0.17), Vector3(0, -rad_to_deg(a), 0))
		# 爪板（局部 +X 朝外）：外低内高的切角梯形，沿 Z 挤出
		K.plate(leg, [Vector2(0.0, 0.20), Vector2(0.10, 0.20), Vector2(0.40, 0.04), Vector2(0.42, 0.0), Vector2(0.0, 0.0)], 0.045, steel, Vector3(0, 0.0, 0), Vector3.ZERO, 0.012)
		K.plate(leg, [Vector2(0.0, 0.0), Vector2(0.40, 0.0), Vector2(0.40, 0.025), Vector2(0.0, 0.025)], 0.14, K.dark(), Vector3(0.0, 0.0, 0), Vector3.ZERO, 0.008)
		add(leg, cyl(0.032, 0.06, -1.0, 20), K.dark(), Vector3(0.36, 0.04, 0))
		add(leg, cyl(0.022, 0.20, 0.002, 20), A.chrome(), Vector3(0.36, -0.06, 0))
		add(leg, torus(0.022, 0.042, 24, 16), K.gunmetal(), Vector3(0.36, 0.075, 0))
	# --- 配电箱：倒角机箱 + 散热百叶 + 警示条 + 加强肋 + 电缆接口
	var box := K.node(p, Vector3(0, 0.38, 0))
	K.bb(box, Vector3(0.34, 0.36, 0.26), olive, Vector3.ZERO, Vector3.ZERO, 0.03)
	K.bb(box, Vector3(0.36, 0.035, 0.28), K.dark(), Vector3(0, 0.19, 0), Vector3.ZERO, 0.012)
	K.bb(box, Vector3(0.36, 0.035, 0.28), K.dark(), Vector3(0, -0.19, 0), Vector3.ZERO, 0.012)
	for sx in [-0.175, 0.175]:
		K.bb(box, Vector3(0.025, 0.30, 0.22), K.dark(), Vector3(sx, 0, 0), Vector3.ZERO, 0.008)
	A.vent(box, Vector3(0.22, 0.16, 0.03), Vector3(0, 0.03, -0.135), Vector3.ZERO, 5)
	hazard_band(box, Vector3(0.30, 0.05, 0.012), Vector3(0, -0.12, -0.134))
	A.vent(box, Vector3(0.18, 0.14, 0.03), Vector3(0, 0.03, 0.135), Vector3(0, 180, 0), 5)
	for sx in [-0.09, 0.09]:
		add(box, cyl(0.026, 0.05, -1.0, 20), K.brass(), Vector3(sx, 0.12, 0.14), Vector3(90, 0, 0))
	var led := add(box, sphere(0.014, 20), A.emit(field, 3.0), Vector3(0.11, 0.12, -0.135), Vector3.ZERO, Vector3.ONE, false)
	lamps.append(led)
	# --- 主桅杆 + 高细分圆盘散热器
	add(p, cyl(0.07, 0.06, 0.09, 32), K.dark(), Vector3(0, 0.59, 0))
	add(p, cyl(0.052, 1.02, -1.0, 28), K.gunmetal(), Vector3(0, 1.10, 0))
	for i in 7:
		add(p, cyl(0.12 - i * 0.004, 0.016, -1.0, 36), A.paint(Color(0.40, 0.41, 0.42), 0.8, 0.32, {"wear": 0.1}), Vector3(0, 0.72 + i * 0.045, 0))
	add(p, cyl(0.064, 0.30, -1.0, 28), K.dark(), Vector3(0, 0.855, 0))
	# --- 电磁发射线圈组：铜绕组环 + 绝缘隔环 + 发光导芯
	add(p, cyl(0.034, 0.36, -1.0, 24), A.emit(field.darkened(0.1), 1.8), Vector3(0, 1.30, 0), Vector3.ZERO, Vector3.ONE, false)
	for i in 4:
		var y := 1.16 + i * 0.09
		add(p, torus(0.065, 0.13, 36, 18), K.copper(), Vector3(0, y, 0))
		add(p, torus(0.06, 0.085, 32, 16), K.dark(), Vector3(0, y + 0.045, 0))
	for i in 3:
		var a := TAU * float(i) / 3.0
		rod(p, Vector3(cos(a) * 0.105, 1.08, sin(a) * 0.105), Vector3(cos(a) * 0.105, 1.50, sin(a) * 0.105), 0.012, K.gunmetal(), 16)
	add(p, cyl(0.15, 0.04, 0.12, 36), K.dark(), Vector3(0, 1.08, 0))
	add(p, cyl(0.12, 0.04, 0.15, 36), K.dark(), Vector3(0, 1.52, 0))
	# --- 顶部护笼频闪发射头
	lamps.append(caged_lamp(p, Vector3(0, 1.54, 0), 0.07, 0.20, field, 2.2))
	return {"lamps": lamps, "emit_top": Vector3(0, 1.30, 0)}


## 两桩之间的微弧力场幕（≥ 32 段平滑弧带，底部亮、顶部羽化透明，双面）
static func field_curtain(a: Vector3, b: Vector3, center: Vector3, y0: float, y1: float, bow: float, c: Color, segs := 32) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mid := (a + b) * 0.5
	var out := Vector3(mid.x - center.x, 0, mid.z - center.z).normalized()
	var n := maxi(segs, 24)
	var rows := 6
	var pts: Array = []
	for i in n + 1:
		var t := float(i) / n
		var p := a.lerp(b, t) + out * sin(t * PI) * bow
		pts.append(p)
	for i in n:
		for r in rows:
			var v0 := float(r) / rows
			var v1 := float(r + 1) / rows
			var ya := lerpf(y0, y1, v0)
			var yb := lerpf(y0, y1, v1)
			var edge0 := sin(float(i) / n * PI)
			var edge1 := sin(float(i + 1) / n * PI)
			var p00 := Vector3(pts[i].x, ya, pts[i].z)
			var p10 := Vector3(pts[i + 1].x, ya, pts[i + 1].z)
			var p01 := Vector3(pts[i].x, yb, pts[i].z)
			var p11 := Vector3(pts[i + 1].x, yb, pts[i + 1].z)
			var al := func(v: float, e: float) -> Color:
				return Color(c.r, c.g, c.b, c.a * pow(1.0 - v, 1.6) * (0.35 + 0.65 * e))
			var quad := [[p00, al.call(v0, edge0), Vector2(float(i) / n, v0)], [p10, al.call(v0, edge1), Vector2(float(i + 1) / n, v0)],
				[p11, al.call(v1, edge1), Vector2(float(i + 1) / n, v1)], [p01, al.call(v1, edge0), Vector2(float(i) / n, v1)]]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_color(quad[k][1])
				st.set_uv(quad[k][2])
				st.set_normal(out)
				st.add_vertex(quad[k][0])
	return st.commit()


static func curtain_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1, 1)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.6
	m.no_depth_test = false
	return m


# ======================================================================
# P0-SKL-02 声波诱饵信标：战术声波诱饵台
# ======================================================================
## 返回 {"lamp": MeshInstance3D, "horn_mouth": Vector3}
static func build_decoy(p: Node3D, lure: Color) -> Dictionary:
	var olive := A.paint(Color(0.33, 0.32, 0.24), 0.22, 0.5, {"wear": 0.4, "dust": 0.25})
	var steel := A.paint(Color(0.32, 0.33, 0.34), 0.55, 0.40, {"wear": 0.3})
	# --- 可展开三角液压支脚
	add(p, cyl(0.11, 0.10, 0.13, 32), K.dark(), Vector3(0, 0.50, 0))
	add(p, torus(0.11, 0.15, 32, 16), steel, Vector3(0, 0.46, 0))
	for i in 3:
		var a := TAU * float(i) / 3.0 + PI * 0.5
		var dir := Vector3(cos(a), 0, sin(a))
		var hip := dir * 0.12 + Vector3(0, 0.48, 0)
		var foot := dir * 0.56 + Vector3(0, 0.035, 0)
		rod(p, hip, foot, 0.028, steel, 24)
		add(p, torus(0.02, 0.05, 24, 16), K.dark(), hip, Vector3(0, -rad_to_deg(a), 90))
		var knee := hip.lerp(foot, 0.55)
		piston(p, Vector3(0, 0.30, 0) + dir * 0.05, knee + Vector3(0, -0.02, 0), 0.014)
		# 脚垫：橡胶垫 + 钢压盘 + 球铰
		add(p, cyl(0.085, 0.025, 0.095, 32), A.rubber(), foot + Vector3(0, -0.02, 0))
		add(p, cyl(0.065, 0.025, 0.08, 32), steel, foot + Vector3(0, 0.005, 0))
		add(p, sphere(0.032, 24), A.chrome(), foot + Vector3(0, 0.03, 0))
	add(p, cyl(0.04, 0.24, -1.0, 24), A.chrome(), Vector3(0, 0.33, 0))
	# --- 主控防水机箱（带警示条、散热百叶、提手、电池舱）
	var box := K.node(p, Vector3(0, 0.70, 0))
	K.bb(box, Vector3(0.40, 0.30, 0.34), olive, Vector3.ZERO, Vector3.ZERO, 0.035)
	K.bb(box, Vector3(0.42, 0.04, 0.36), K.dark(), Vector3(0, -0.15, 0), Vector3.ZERO, 0.012)
	K.bb(box, Vector3(0.42, 0.03, 0.36), K.dark(), Vector3(0, 0.15, 0), Vector3.ZERO, 0.012)
	A.vent(box, Vector3(0.24, 0.14, 0.03), Vector3(0, 0.02, 0.175), Vector3(0, 180, 0), 6)
	hazard_band(box, Vector3(0.36, 0.045, 0.012), Vector3(0, -0.10, -0.172))
	K.bb(box, Vector3(0.20, 0.10, 0.02), K.dark(), Vector3(-0.05, 0.04, -0.172), Vector3.ZERO, 0.006)
	add(box, sphere(0.012, 20), A.emit(Color(0.3, 1.0, 0.4), 3.0), Vector3(0.12, 0.06, -0.175), Vector3.ZERO, Vector3.ONE, false)
	add(box, sphere(0.012, 20), A.emit(lure, 3.0), Vector3(0.12, 0.02, -0.175), Vector3.ZERO, Vector3.ONE, false)
	for sx in [-0.16, 0.16]:
		rod(box, Vector3(sx, 0.15, -0.08), Vector3(sx, 0.22, -0.08), 0.012, K.gunmetal(), 16)
		rod(box, Vector3(sx, 0.15, 0.08), Vector3(sx, 0.22, 0.08), 0.012, K.gunmetal(), 16)
	rod(box, Vector3(-0.16, 0.22, -0.08), Vector3(-0.16, 0.22, 0.08), 0.012, K.gunmetal(), 16)
	rod(box, Vector3(0.16, 0.22, -0.08), Vector3(0.16, 0.22, 0.08), 0.012, K.gunmetal(), 16)
	for sx in [-0.21, 0.21]:
		K.bb(box, Vector3(0.03, 0.16, 0.08), K.dark(), Vector3(sx, 0.0, 0.08), Vector3.ZERO, 0.008)
	# --- 回转云台 + 俯仰叉臂
	add(p, cyl(0.10, 0.06, 0.12, 32), K.dark(), Vector3(0, 0.88, 0))
	add(p, torus(0.09, 0.125, 32, 16), K.brass(), Vector3(0, 0.915, 0))
	for sx in [-0.17, 0.17]:
		K.plate(p, [Vector2(-0.06, 0.0), Vector2(0.06, 0.0), Vector2(0.045, 0.20), Vector2(-0.045, 0.20)], 0.025, steel, Vector3(sx, 0.92, 0), Vector3(0, 90, 0), 0.008)
		add(p, cyl(0.045, 0.04, -1.0, 28), K.dark(), Vector3(sx, 1.08, 0), Vector3(0, 0, 90))
	# --- 多级扩音号角（车削剖面：喉部 → 指数扩张 → 卷边唇口），朝 -Z 前方上仰 12°
	var horn := K.node(p, Vector3(0, 1.08, 0.02), Vector3(-90 + 12, 0, 0))
	var prof := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		prof.append(Vector2(0.085 + 0.24 * pow(t, 2.4), -0.14 + t * 0.44))
	prof.append(Vector2(0.335, 0.30))
	prof.append(Vector2(0.345, 0.285))
	add(horn, lathe(prof, 48, true, false), A.paint(Color(0.30, 0.31, 0.27), 0.3, 0.45, {"wear": 0.32}))
	# 内壁（深色，反向剖面略缩）
	var inner := PackedVector2Array()
	for q in prof:
		inner.append(Vector2(maxf(q.x - 0.012, 0.01), q.y - 0.004))
	var inner_m := add(horn, lathe(inner, 48, false, false), K.bore_mat())
	inner_m.scale = Vector3(-1, 1, 1)
	add(horn, torus(0.325, 0.36, 48, 18), K.dark(), Vector3(0, 0.30, 0))
	add(horn, cyl(0.105, 0.10, -1.0, 32), K.dark(), Vector3(0, -0.17, 0))
	add(horn, torus(0.10, 0.125, 32, 16), K.brass(), Vector3(0, -0.12, 0))
	# 驱动单元后罩
	add(horn, lathe(PackedVector2Array([Vector2(0.0, -0.36), Vector2(0.07, -0.35), Vector2(0.12, -0.30), Vector2(0.13, -0.22)]), 36, false, false), K.dark())
	bolts(horn, 0.115, 8, -0.22)
	# 防尘音膜网：内凹深色膜 + 同心护网环 + 十字筋
	add(horn, cyl(0.30, 0.01, -1.0, 48), A.paint(Color(0.06, 0.06, 0.065), 0.1, 0.9, {"wear": 0.0}), Vector3(0, 0.22, 0), Vector3.ZERO, Vector3.ONE, false)
	add(horn, cyl(0.07, 0.03, 0.09, 36), K.gunmetal(), Vector3(0, 0.235, 0))
	for rr in [0.13, 0.20, 0.27]:
		add(horn, torus(rr - 0.006, rr + 0.006, 48, 16), K.gunmetal(), Vector3(0, 0.25, 0), Vector3.ZERO, Vector3.ONE, false)
	for k in 4:
		var a := PI * 0.25 + PI * 0.5 * k
		rod(horn, Vector3(cos(a) * 0.07, 0.25, sin(a) * 0.07), Vector3(cos(a) * 0.30, 0.255, sin(a) * 0.30), 0.006, K.gunmetal(), 16, false)
	# --- 鞭状天线：弹簧底座 + 细鞭 + 球头
	var ant := K.node(p, Vector3(0.14, 0.86, 0.13))
	add(ant, cyl(0.03, 0.06, 0.035, 24), K.dark(), Vector3(0, 0.03, 0))
	for i in 5:
		add(ant, torus(0.012, 0.024, 24, 16), A.chrome(), Vector3(0, 0.07 + i * 0.012, 0))
	add(ant, cyl(0.007, 0.78, 0.011, 16), K.dark(), Vector3(0, 0.52, 0))
	add(ant, sphere(0.016, 20), K.dark(), Vector3(0, 0.915, 0))
	# --- 护笼频闪灯
	var lamp := caged_lamp(p, Vector3(-0.14, 0.86, 0.12), 0.06, 0.18, lure, 2.6)
	return {"lamp": lamp, "horn_mouth": Vector3(0, 1.2, -0.25)}


# ======================================================================
# P0-SKL-03 四足跃迁阻拦网：战术锚钉阻滞网
# ======================================================================
## 中心抛射母罐 + 周边锚钉 + 平滑悬链钢缆/高粘纤维束 + 粘液节点。rng 用于可复现的随机布局。
static func build_web(p: Node3D, radius: float, c: Color, rng: RandomNumberGenerator) -> void:
	var strand := A.paint(Color(0.42, 0.62, 0.60), 0.35, 0.3, {"wear": 0.0, "use_albedo_tex": 0.0})
	var glow := A.emit(c, 1.25)
	var goo := A.paint(Color(0.30, 0.62, 0.58), 0.05, 0.12, {"wear": 0.0, "use_albedo_tex": 0.0, "dust": 0.0})
	# --- 中心抛射母罐（倒角罐体 + 弹开瓣盖 + 内膛 + 箍环 + 底撬）
	var can := K.node(p, Vector3(0, 0, 0))
	add(can, cyl(0.23, 0.06, 0.26, 40), K.dark(), Vector3(0, 0.03, 0))
	add(can, cyl(0.20, 0.42, -1.0, 40), A.paint(Color(0.30, 0.33, 0.27), 0.3, 0.46, {"wear": 0.45, "dust": 0.3}), Vector3(0, 0.27, 0))
	for y in [0.12, 0.30, 0.46]:
		add(can, torus(0.195, 0.225, 40, 16), K.gunmetal(), Vector3(0, y, 0))
	hazard_band(can, Vector3(0.12, 0.05, 0.01), Vector3(0, 0.38, -0.205))
	add(can, cyl(0.17, 0.02, -1.0, 40), K.bore_mat(), Vector3(0, 0.475, 0), Vector3.ZERO, Vector3.ONE, false)
	add(can, cyl(0.08, 0.06, 0.12, 32), glow, Vector3(0, 0.46, 0), Vector3.ZERO, Vector3.ONE, false)
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		var hinge := K.node(can, Vector3(cos(a) * 0.20, 0.48, sin(a) * 0.20), Vector3(0, -rad_to_deg(a), 0))
		var petal := K.node(hinge, Vector3.ZERO, Vector3(0, 0, -62))
		K.plate(petal, [Vector2(0.0, -0.09), Vector2(0.20, -0.06), Vector2(0.22, 0.0), Vector2(0.20, 0.06), Vector2(0.0, 0.09)], 0.022, K.gunmetal(), Vector3(0, 0, 0), Vector3(90, 0, 0), 0.008)
		add(hinge, cyl(0.016, 0.16, -1.0, 20), A.chrome(), Vector3.ZERO, Vector3(90, 0, 0))
	# --- 周边锚钉与放射钢缆
	var n := 11
	var tips: Array = []
	for i in n:
		var a := TAU * float(i) / n + rng.randf_range(-0.18, 0.18)
		var r_len := radius * rng.randf_range(0.74, 1.0)
		var tip := Vector3(cos(a) * r_len, 0.06, sin(a) * r_len)
		tips.append(tip)
		# 锚钉：埋地锥钉 + 冲击座 + 系缆耳环 + 指示灯
		var anc := K.node(p, Vector3(tip.x, 0, tip.z), Vector3(rng.randf_range(-12, 12), rng.randf_range(0, 360), rng.randf_range(-12, 12)))
		add(anc, cyl(0.055, 0.05, 0.075, 28), K.dark(), Vector3(0, 0.025, 0))
		add(anc, cyl(0.035, 0.10, 0.05, 24), K.gunmetal(), Vector3(0, 0.09, 0))
		add(anc, torus(0.022, 0.04, 24, 16), A.chrome(), Vector3(0, 0.16, 0), Vector3(90, 0, 0))
		add(anc, sphere(0.016, 20), glow, Vector3(0.035, 0.12, 0), Vector3.ZERO, Vector3.ONE, false)
		add(anc, cyl(0.12, 0.012, -1.0, 32), A.paint(Color(0.12, 0.11, 0.10), 0.0, 0.95, {"wear": 0.0}), Vector3(0, 0.004, 0), Vector3.ZERO, Vector3.ONE, false)
		# 钢缆：从罐口沿悬链线落向锚钉（多控制点，平滑）
		var top := Vector3(cos(a) * 0.12, 0.50, sin(a) * 0.12)
		var pts: Array = [top]
		for k in range(1, 6):
			var t := float(k) / 6.0
			var q := top.lerp(tip + Vector3(0, 0.16, 0), t)
			q.y -= sin(t * PI) * 0.16 + t * 0.0
			pts.append(q)
		pts.append(tip + Vector3(0, 0.16, 0))
		add(p, tube(pts, 0.022, 16, 10), strand, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		add(p, tube(pts, 0.009, 14, 10), glow, Vector3(0, 0.012, 0), Vector3.ZERO, Vector3.ONE, false)
	# --- 环向高粘纤维束（两圈，悬垂贴地）+ 节点粘液团
	for ring_k in [0.45, 0.78]:
		for i in n:
			var a_pt: Vector3 = (tips[i] as Vector3) * ring_k
			var b_pt: Vector3 = (tips[(i + 1) % n] as Vector3) * ring_k
			a_pt.y = 0.10 + (1.0 - ring_k) * 0.24
			b_pt.y = a_pt.y
			var m1 := a_pt.lerp(b_pt, 0.33) + Vector3(0, -0.05, 0)
			var m2 := a_pt.lerp(b_pt, 0.66) + Vector3(0, -0.05, 0)
			add(p, tube([a_pt, m1, m2, b_pt], 0.014, 14, 10), strand, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			var blob := add(p, sphere(0.045, 24), goo, a_pt, Vector3.ZERO, Vector3(1.3, 0.7, 1.3), false)
			blob.rotation_degrees.y = rng.randf_range(0, 360)
			if rng.randf() < 0.5:
				add(p, sphere(0.03, 20), goo, a_pt.lerp(b_pt, 0.5) + Vector3(0, -0.06, 0), Vector3.ZERO, Vector3(1.0, 1.4, 1.0), false)


# ======================================================================
# P0-SKL-08 首领破土地刺：多棱破甲地刺簇
# ======================================================================
## h 为主刺高度。返回 Node3D（原点在地面）
static func build_spike(p: Node3D, h: float, c: Color, rng: RandomNumberGenerator) -> Node3D:
	var root := K.node(p)
	var jkt := A.paint(Color(0.36, 0.37, 0.39), 0.45, 0.46, {"wear": 0.55, "rust": 0.18, "scratches": 0.5})
	var dark := A.paint(Color(0.20, 0.20, 0.22), 0.35, 0.5, {"wear": 0.45})
	var hot := A.emit(c, 2.2)
	var rock := A.rock_mat(Color(0.34, 0.31, 0.28))
	# --- 碎石隆起基座：一圈翻起的岩块 + 熔热裂纹环
	for i in 7:
		var a := TAU * float(i) / 7.0 + rng.randf_range(-0.2, 0.2)
		var d := rng.randf_range(0.42, 0.62)
		var s := rng.randf_range(0.20, 0.32)
		add(root, A.rock_mesh(i + int(rng.randi() % 5), 24), rock, Vector3(cos(a) * d, s * 0.25, sin(a) * d),
			Vector3(rng.randf_range(-35, 35), rng.randf_range(0, 360), rng.randf_range(-35, 35)), Vector3(s, s * 0.8, s * 1.2))
	add(root, torus(0.42, 0.52, 40, 16), hot, Vector3(0, 0.07, 0), Vector3.ZERO, Vector3(1, 0.25, 1), false)
	add(root, cyl(0.52, 0.06, 0.62, 40), A.rock_mat(Color(0.22, 0.20, 0.18)), Vector3(0, 0.02, 0))
	# --- 主刺：车削分段甲壳桩 + 三片切削刃 + 加强箍 + 熔芯尖
	_spike_body(root, h, 0.40, jkt, dark, hot)
	# --- 副刺两根，外倾
	for i in 2:
		var a := TAU * (0.3 + i * 0.45) + rng.randf_range(-0.3, 0.3)
		var sub := K.node(root, Vector3(cos(a) * 0.32, 0, sin(a) * 0.32))
		sub.rotation = Vector3(0, -a, 0)
		var tilt := K.node(sub, Vector3.ZERO, Vector3(0, 0, -rng.randf_range(18, 28)))
		_spike_body(tilt, h * rng.randf_range(0.48, 0.6), 0.24, jkt, dark, hot)
	return root


static func _spike_body(p: Node3D, h: float, r: float, jkt: Material, dark: Material, hot: Material) -> void:
	# 车削剖面：粗根 → 收腰 → 甲壳台阶 → 尖锥
	var prof := PackedVector2Array([
		Vector2(r * 1.05, 0.0), Vector2(r * 1.0, h * 0.10), Vector2(r * 0.84, h * 0.14), Vector2(r * 0.80, h * 0.36),
		Vector2(r * 0.66, h * 0.40), Vector2(r * 0.60, h * 0.58), Vector2(r * 0.50, h * 0.62)])
	add(p, lathe(prof, 32, true, true), jkt)
	# 甲壳台阶加强箍
	for k in [[0.12, 0.92], [0.39, 0.74], [0.61, 0.52]]:
		var y: float = h * k[0]
		var rr: float = r * k[1]
		add(p, torus(rr * 0.92, rr * 1.06, 36, 16), dark, Vector3(0, y, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	# 熔芯尖（发光内锥，略突出）
	add(p, lathe(PackedVector2Array([Vector2(r * 0.46, h * 0.60), Vector2(r * 0.36, h * 0.74), Vector2(r * 0.20, h * 0.88), Vector2(0.0, h * 1.02)]), 32, true, false), hot, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	# 三片切削刃（带倒角的长三角刃板，沿径向）
	for i in 3:
		var a := TAU * float(i) / 3.0
		var fin := K.node(p, Vector3.ZERO, Vector3(0, rad_to_deg(a), 0))
		K.plate(fin, [Vector2(r * 0.55, h * 0.08), Vector2(r * 1.30, h * 0.16), Vector2(r * 1.05, h * 0.44), Vector2(r * 0.28, h * 0.86), Vector2(r * 0.25, h * 0.40)],
			r * 0.12, dark, Vector3.ZERO, Vector3.ZERO, r * 0.04)
		# 刃口熔线
		K.plate(fin, [Vector2(r * 1.24, h * 0.17), Vector2(r * 1.32, h * 0.16), Vector2(r * 1.08, h * 0.45), Vector2(r * 1.0, h * 0.44)],
			r * 0.05, hot, Vector3.ZERO, Vector3.ZERO, r * 0.01)


# ======================================================================
# P0-MSL-05 首领齐射火箭弹：弹体沿 +Y，弹头朝 +Y
# ======================================================================
static func build_salvo_rocket(p: Node3D) -> void:
	var olive := A.paint(Color(0.28, 0.31, 0.24), 0.45, 0.52, {"rust": 0.42, "wear": 0.35})
	var steel := A.metal(Color(0.20, 0.22, 0.24))
	var brass := A.paint(Color(0.86, 0.66, 0.22), 0.88, 0.26, {"panel_scale": 0.0})
	var R := 0.11
	# 弹体主筒（含级间法兰）
	add(p, cyl(R, 0.62, -1.0, 32), olive, Vector3(0, 0.0, 0), Vector3.ZERO, Vector3.ONE, false)
	for y in [-0.24, 0.05, 0.28]:
		# 级间法兰：倒角箍带（车削剖面，带上下斜边）+ 环缝
		add(p, lathe(PackedVector2Array([Vector2(R, y - 0.022), Vector2(R * 1.06, y - 0.014), Vector2(R * 1.06, y + 0.014), Vector2(R, y + 0.022)]), 36, false, false), steel, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	add(p, A.bevel_box(Vector3(0.006, 0.08, 0.02), 0.002), steel, Vector3(0, 0.15, -R), Vector3.ZERO, Vector3.ONE, false)
	# 警示色环
	add(p, cyl(R * 1.01, 0.06, -1.0, 32), A.hazard(), Vector3(0, 0.20, 0), Vector3.ZERO, Vector3.ONE, false)
	# 卵形整流罩（车削切线卵形）+ 导引头压圈 + 黄铜引信
	var og := PackedVector2Array()
	var L := 0.36
	for i in 13:
		var t := float(i) / 12.0
		og.append(Vector2(R * sqrt(maxf(0.0, 1.0 - pow(t, 1.8))) * (1.0 - 0.75 * t * t * 0.4), 0.31 + t * L))
	add(p, lathe(og, 36, false, false), steel, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	add(p, lathe(PackedVector2Array([Vector2(0.026, 0.31 + L * 0.92), Vector2(0.020, 0.31 + L * 1.02), Vector2(0.0, 0.31 + L * 1.08)]), 24, false, false), brass, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	# 尾段：收口裙 + 拉瓦尔喷管（收敛—喉—扩张钟形）+ 黑膛 + 焰芯
	add(p, lathe(PackedVector2Array([Vector2(R, -0.31), Vector2(R * 0.92, -0.36), Vector2(R * 0.72, -0.40)]), 32, false, false), steel, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	var bell := PackedVector2Array([Vector2(0.075, -0.40), Vector2(0.045, -0.43), Vector2(0.050, -0.46), Vector2(0.068, -0.50), Vector2(0.088, -0.54)])
	add(p, lathe(bell, 32, false, false), A.paint(Color(0.16, 0.14, 0.13), 0.7, 0.4, {"wear": 0.1, "rust": 0.3}), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	var bell_in := PackedVector2Array()
	for q in bell:
		bell_in.append(Vector2(q.x - 0.006, q.y))
	var bi := add(p, lathe(bell_in, 32, false, false), K.bore_mat(), Vector3.ZERO, Vector3.ZERO, Vector3(-1, 1, 1), false)
	bi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add(p, cyl(0.07, 0.004, -1.0, 32), A.emit(Color(1.0, 0.45, 0.12), 1.2), Vector3(0, -0.47, 0), Vector3.ZERO, Vector3.ONE, false)
	add(p, lathe(PackedVector2Array([Vector2(0.05, -0.45), Vector2(0.03, -0.56), Vector2(0.0, -0.62)]), 24, true, false), A.emit(Color(1.0, 0.62, 0.22), 2.4), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	# 四片后掠翼型尾翼（带翼根整流座）+ 四片前部鸭翼
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		var fin := K.node(p, Vector3.ZERO, Vector3(0, rad_to_deg(a), 0))
		K.plate(fin, [Vector2(R * 0.9, -0.12), Vector2(R + 0.05, -0.20), Vector2(R + 0.13, -0.33), Vector2(R + 0.13, -0.40), Vector2(R * 0.9, -0.39)],
			0.014, steel, Vector3.ZERO, Vector3.ZERO, 0.005)
		K.bb(fin, Vector3(0.03, 0.24, 0.03), steel, Vector3(R * 0.98, -0.26, 0), Vector3.ZERO, 0.01)
		var can := K.node(p, Vector3.ZERO, Vector3(0, rad_to_deg(a + PI * 0.25), 0))
		K.plate(can, [Vector2(R * 0.92, 0.36), Vector2(R + 0.045, 0.33), Vector2(R + 0.045, 0.30), Vector2(R * 0.92, 0.29)], 0.009, steel, Vector3.ZERO, Vector3.ZERO, 0.003)


## 已装填火箭发射管口（管口朝 -Z，pos 为发射面所在位置；全部几何在发射面之前）：
## 倒圆加厚管口唇 + 内壁 + 深黑膛底 + 探出管口的弹头（主体色 + 黄色高爆识别环 + 黄铜引信）。
static func launch_tube(p: Node3D, pos: Vector3, r: float, nose_c := Color(0.30, 0.33, 0.25), lip_m: Material = null, he_band := true) -> Node3D:
	var n := Node3D.new()
	p.add_child(n)
	n.position = pos
	n.rotation_degrees = Vector3(90, 0, 0)
	var m_lip: Material = lip_m if lip_m != null else K.gunmetal()
	add(n, lathe(PackedVector2Array([Vector2(r * 0.96, 0.0), Vector2(r * 0.96, -r * 0.55), Vector2(r * 1.06, -r * 0.65), Vector2(r * 1.24, -r * 0.62), Vector2(r * 1.32, -r * 0.50), Vector2(r * 1.32, 0.0)]), 28, false, false), m_lip, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	add(n, A.cyl(r * 0.97, r * 0.04, r * 0.97, 24), K.bore_mat(), Vector3(0, -r * 0.02, 0), Vector3.ZERO, Vector3.ONE, false)
	var og := PackedVector2Array()
	for i in range(10, -1, -1):
		var t := float(i) / 10.0
		og.append(Vector2(r * 0.80 * pow(maxf(0.0, 1.0 - t * t), 0.7) + r * 0.06 * t, -r * 0.04 - t * r * 0.92))
	add(n, lathe(og, 24, true, false), A.paint(nose_c, 0.25, 0.45, {"panel_scale": 0.0, "wear": 0.3}), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	if he_band:
		add(n, A.cyl(r * 0.83, r * 0.12, r * 0.83, 24), A.paint(Color(0.86, 0.70, 0.16), 0.2, 0.45, {"panel_scale": 0.0}), Vector3(0, -r * 0.14, 0), Vector3.ZERO, Vector3.ONE, false)
	add(n, lathe(PackedVector2Array([Vector2(0.0, -r * 1.10), Vector2(r * 0.10, -r * 1.04), Vector2(r * 0.07, -r * 0.95)]), 16, false, false), K.brass(), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	return n
