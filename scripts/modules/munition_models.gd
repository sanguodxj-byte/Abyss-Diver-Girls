extends RefCounted
## 弹药 / 导弹 / 弹壳 / 弹托 / 破片 / 信号弹罐的高精程序化网格库（低面数整改 P0-MSL / P0-SKL-10）。
## 约定：弹体轴沿 Z，弹头朝 -Z（与 raid.gd 弹体节点一致）；所有网格按参数缓存，可被粒子与对象池复用。
const A = preload("res://scripts/art.gd")
const DM = preload("res://scripts/modules/device_models.gd")
const K = preload("res://scripts/modules/kit.gd")

static var _cache := {}


# ======================================================================
# 基础网格
# ======================================================================

## 车削体（轴沿 Z）：profile 为 (半径, z) 折线，按顺序旋转；smooth=true 用剖面法线平滑。
static func lathe_z(profile_in: PackedVector2Array, seg := 24, color := Color(1, 1, 1), auto_out := true) -> ArrayMesh:
	# 法线取剖面行进方向的左侧；整体沿 -Z 行进的外表面剖面自动反转，保证朝外
	var profile := profile_in
	if auto_out and profile.size() > 1 and profile[profile.size() - 1].y < profile[0].y:
		profile = PackedVector2Array()
		for i in range(profile_in.size() - 1, -1, -1):
			profile.append(profile_in[i])
	var s := seg if not A.is_mobile_perf() else maxi(16, int(seg * 0.75))
	var key := "lz%s|%d|%s" % [profile, s, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := profile.size()
	var nrm2: Array = []
	for i in n:
		var t := (profile[mini(i + 1, n - 1)] - profile[maxi(i - 1, 0)]).normalized()
		nrm2.append(Vector2(t.y, -t.x))
	for i in n - 1:
		if profile[i].distance_to(profile[i + 1]) < 1e-5:
			continue
		# 剖面线段方向急转时用段法线（硬边），否则用点法线（平滑）
		var seg_t := (profile[i + 1] - profile[i]).normalized()
		var seg_n := Vector2(seg_t.y, -seg_t.x)
		for j in s:
			var a0 := TAU * float(j) / s
			var a1 := TAU * float(j + 1) / s
			var q := [[i, a0], [i + 1, a0], [i + 1, a1], [i, a1]]
			var vs: Array = []
			for e in q:
				var pr: Vector2 = profile[e[0]]
				var nn: Vector2 = nrm2[e[0]]
				if nn.dot(seg_n) < 0.8:
					nn = seg_n
				var ang: float = e[1]
				vs.append([Vector3(cos(ang) * pr.x, sin(ang) * pr.x, pr.y), Vector3(cos(ang) * nn.x, sin(ang) * nn.x, nn.y).normalized(), Vector2(ang / TAU, float(e[0]) / float(n - 1))])
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_color(color)
				st.set_normal(vs[k][1])
				st.set_uv(vs[k][2])
				st.add_vertex(vs[k][0])
	st.generate_tangents()
	var m := st.commit()
	_cache[key] = m
	return m


## 一对对置后掠倒角翼片（取代 _box_cached 裸 BoxMesh）。
## sz.x = 翼厚，sz.y = 两翼总展长（翼根在轴心，向 ±Y 伸出），sz.z = 根弦长。
## 剖面为六边形倒角翼型（前后缘削薄），翼尖弦长 taper×根弦，前缘向 +Z（后方）后掠 sweep×根弦。
static func fin_pair(sz: Vector3, sweep := 0.38, taper := 0.5) -> ArrayMesh:
	var key := "fin%.4f|%.4f|%.4f|%.2f|%.2f" % [sz.x, sz.y, sz.z, sweep, taper]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var half := sz.y * 0.5
	for side in [-1.0, 1.0]:
		var secs: Array = []
		for e in [[0.0, 1.0, 1.0], [1.0, taper, 0.55]]:
			var y: float = side * half * float(e[0])
			var c: float = sz.z * float(e[1])
			var th: float = sz.x * float(e[2])
			var z_le: float = -sz.z * 0.5 + sz.z * sweep * float(e[0])
			var z_te := z_le + c
			secs.append([
				Vector3(0, y, z_le),
				Vector3(th * 0.5, y, z_le + c * 0.22),
				Vector3(th * 0.5, y, z_te - c * 0.30),
				Vector3(0, y, z_te),
				Vector3(-th * 0.5, y, z_te - c * 0.30),
				Vector3(-th * 0.5, y, z_le + c * 0.22),
			])
		var r0: Array = secs[0]
		var r1: Array = secs[1]
		for j in 6:
			var j2 := (j + 1) % 6
			var quad := [r0[j], r0[j2], r1[j2], r1[j]]
			if side < 0.0:
				quad = [r0[j], r1[j], r1[j2], r0[j2]]
			_quad(st, quad)
		# 翼尖封口
		var tip: Array = r1
		for j in range(1, 5):
			if side > 0.0:
				_tri(st, tip[0], tip[j + 1], tip[j])
			else:
				_tri(st, tip[0], tip[j], tip[j + 1])
	st.generate_normals()
	st.generate_tangents()
	var m := st.commit()
	_cache[key] = m
	return m


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for v in [a, b, c]:
		st.set_uv(Vector2(v.z, v.y))
		st.add_vertex(v)


static func _quad(st: SurfaceTool, q: Array) -> void:
	_tri(st, q[0], q[1], q[2])
	_tri(st, q[0], q[2], q[3])


# ======================================================================
# P0-MSL-01 制导导弹 / 火箭弹 / VLS 重弹（轴沿 Z，弹头 -Z）
# ======================================================================
static func build_missile(b: Node3D, kind: String, size: float) -> void:
	var r := size * (0.64 if kind == "vls" else (0.50 if kind == "rocket" else 0.56))
	var seg := 28 if kind == "vls" else 24
	var body_col := Color(0.26, 0.29, 0.31) if kind == "vls" else (Color(0.30, 0.34, 0.24) if kind == "rocket" else Color(0.24, 0.27, 0.25))
	var nose_col := Color(0.76, 0.22, 0.14) if kind != "rocket" else Color(0.68, 0.54, 0.22)
	var m_fuse := A.paint(body_col, 0.55, 0.44, {"panel_scale": 0.0, "wear": 0.25})
	var m_nose := A.paint(nose_col, 0.28, 0.42, {"panel_scale": 0.0, "wear": 0.2})
	var m_band := A.paint(Color(0.92, 0.74, 0.16), 0.3, 0.42, {"panel_scale": 0.0})
	var m_steel := A.metal(Color(0.24, 0.26, 0.28))
	var m_dark := A.metal(Color(0.12, 0.13, 0.15))
	var m_copper := A.paint(Color(0.84, 0.45, 0.24), 0.88, 0.28, {"panel_scale": 0.0, "wear": 0.12})
	var z_body0 := -size * 1.45
	var z_body1 := size * 1.85
	# 弹身：带尾部收口船尾
	_add(b, lathe_z(PackedVector2Array([Vector2(r, z_body0), Vector2(r, z_body1 - size * 0.12), Vector2(r * 0.94, z_body1), Vector2(r * 0.86, z_body1 + size * 0.10)]), seg), m_fuse)
	# 切线卵形整流罩（多段平滑收口）
	var og := PackedVector2Array()
	var L := size * 1.35
	for i in 15:
		var t := float(i) / 14.0
		og.append(Vector2(r * sqrt(maxf(0.0, 1.0 - t * t)) * (1.0 - 0.18 * t) + r * 0.0, z_body0 - t * L))
	og[og.size() - 1] = Vector2(r * 0.16, z_body0 - L)
	if kind == "rocket":
		# 火箭弹：触发引信尖
		_add(b, lathe_z(og, seg), m_nose)
		_add(b, lathe_z(PackedVector2Array([Vector2(r * 0.18, z_body0 - L), Vector2(r * 0.12, z_body0 - L - size * 0.18), Vector2(0.0, z_body0 - L - size * 0.26)]), 20), A.paint(Color(0.88, 0.66, 0.22), 0.9, 0.26, {"panel_scale": 0.0}))
	else:
		# 导弹：钝化卵形罩 + 金属压圈 + 光学导引头半球
		og = PackedVector2Array()
		for i in 13:
			var t2 := float(i) / 12.0
			og.append(Vector2(r * (1.0 - 0.58 * pow(t2, 1.6)), z_body0 - t2 * L * 0.86))
		_add(b, lathe_z(og, seg), m_nose)
		var zr := z_body0 - L * 0.86
		_add(b, lathe_z(PackedVector2Array([Vector2(r * 0.44, zr + size * 0.02), Vector2(r * 0.46, zr - size * 0.02), Vector2(r * 0.40, zr - size * 0.06)]), seg), m_steel)
		var dome := A.sphere(r * 0.40, -1, 24)
		_add(b, dome, A.glass(Color(0.14, 0.2, 0.26)), Vector3(0, 0, zr - size * 0.05))
	# 级间加强环箍（torus）+ 警示色带
	for zz in [z_body0 + size * 0.05, size * 0.55]:
		_add(b, A.torus(r * 0.98, r * 1.06, 32), m_steel, Vector3(0, 0, zz), Vector3(90, 0, 0))
	_add(b, A.cyl(r * 1.01, size * 0.28, r * 1.01, seg), m_band, Vector3(0, 0, -size * 0.9), Vector3(90, 0, 0))
	# 拉瓦尔喷管：收敛 → 喉 → 扩张钟形，外耐火喷环 + 内黑膛 + 铜喉衬
	var zn := z_body1 + size * 0.10
	var bell := PackedVector2Array([Vector2(r * 0.86, zn), Vector2(r * 0.56, zn + size * 0.14), Vector2(r * 0.50, zn + size * 0.20), Vector2(r * 0.66, zn + size * 0.36), Vector2(r * 0.84, zn + size * 0.50)])
	_add(b, lathe_z(bell, seg), m_dark)
	var inner := PackedVector2Array()
	for i in range(bell.size() - 1, -1, -1):
		inner.append(Vector2(bell[i].x * 0.88, bell[i].y))
	_add(b, lathe_z(inner, seg, Color(1, 1, 1), false), K.bore_mat())
	_add(b, A.torus(r * 0.80, r * 0.90, 32), m_copper, Vector3(0, 0, zn + size * 0.50), Vector3(90, 0, 0))
	# 后掠翼型尾翼（带翼根整流座）
	var fin := fin_pair(Vector3(size * 0.08, r * 2.0 + size * 1.0, size * 0.95), 0.42, 0.45)
	for fi in 2:
		_add(b, fin, m_dark, Vector3(0, 0, size * 1.25), Vector3(0, 0, fi * 90.0 + 45.0))
	for fi in 4:
		var a := deg_to_rad(fi * 90.0 + 45.0)
		_add(b, A.bevel_box(Vector3(size * 0.12, size * 0.10, size * 0.9), size * 0.03), m_steel, Vector3(cos(a) * r, sin(a) * r, size * 1.25), Vector3(0, 0, fi * 90.0 + 45.0))
	# 前部鸭翼（火箭弹无）
	if kind != "rocket":
		var can := fin_pair(Vector3(size * 0.06, r * 2.0 + size * 0.62, size * 0.42), 0.35, 0.55)
		for fi in 2:
			_add(b, can, m_steel, Vector3(0, 0, -size * 0.65), Vector3(0, 0, fi * 90.0))


static func _add(p: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	return A.add(p, mesh, m, pos, rot, Vector3.ONE, false)


# ======================================================================
# P0-MSL-02 酸液罐弹 / 燃烧弹 / 液氮弹 / 默认炮弹
# ======================================================================
static func build_canister_round(b: Node3D, kind: String, size: float) -> void:
	var m_steel := A.metal(Color(0.24, 0.26, 0.28))
	var m_dark := A.metal(Color(0.12, 0.13, 0.15))
	var m_brass := A.paint(Color(0.88, 0.66, 0.22), 0.9, 0.26, {"panel_scale": 0.0, "wear": 0.12})
	var m_copper := A.paint(Color(0.84, 0.45, 0.24), 0.88, 0.28, {"panel_scale": 0.0, "wear": 0.12})
	match kind:
		"spit":
			var rs := size * 0.42
			var m_can := A.paint(Color(0.28, 0.35, 0.20), 0.42, 0.48, {"rust": 0.45, "wear": 0.35})
			_add(b, lathe_z(PackedVector2Array([Vector2(rs * 0.9, size * 1.02), Vector2(rs * 1.04, size * 0.94), Vector2(rs, -size * 0.85), Vector2(rs * 0.86, -size * 0.95)]), 24), m_can)
			_add(b, A.cyl(rs * 1.06, size * 0.34, rs * 1.06, 24), A.hazard(), Vector3(0, 0, -size * 0.42), Vector3(90, 0, 0))
			# 压力阀弹头 + 黄铜引信环
			_add(b, lathe_z(PackedVector2Array([Vector2(rs * 0.86, -size * 0.95), Vector2(rs * 0.72, -size * 1.2), Vector2(rs * 0.40, -size * 1.42), Vector2(rs * 0.30, -size * 1.46)]), 24), m_steel)
			_add(b, A.torus(rs * 0.26, rs * 0.42, 24), m_brass, Vector3(0, 0, -size * 1.48), Vector3(90, 0, 0))
			_add(b, lathe_z(PackedVector2Array([Vector2(rs * 0.24, -size * 1.46), Vector2(rs * 0.22, -size * 1.58), Vector2(0.0, -size * 1.64)]), 20), m_brass)
			var fin := fin_pair(Vector3(rs * 0.16, rs * 2.15, size * 0.62), 0.32, 0.6)
			for fi in 2:
				_add(b, fin, m_dark, Vector3(0, 0, size * 0.88), Vector3(0, 0, fi * 90.0))
			_add(b, A.torus(rs * 0.82, rs * 0.96, 24), m_dark, Vector3(0, 0, size * 1.08), Vector3(90, 0, 0))
		"flamer":
			var rf := size * 0.36
			var m_char := A.paint(Color(0.16, 0.14, 0.13), 0.45, 0.68, {"rust": 0.5, "wear": 0.4})
			var m_inc := A.paint(Color(0.84, 0.30, 0.12), 0.32, 0.45, {"panel_scale": 0.0, "wear": 0.25})
			_add(b, A.cyl(rf, size * 1.48, rf, 24), m_char, Vector3(0, 0, size * 0.1), Vector3(90, 0, 0))
			_add(b, lathe_z(PackedVector2Array([Vector2(rf, -size * 0.64), Vector2(rf * 0.86, -size * 0.95), Vector2(rf * 0.52, -size * 1.18), Vector2(rf * 0.30, -size * 1.26)]), 24), m_inc)
			_add(b, A.torus(rf * 0.98, rf * 1.10, 24), m_brass, Vector3(0, 0, size * 0.45), Vector3(90, 0, 0))
			# 尾焰喷口：外环 + 内膛 + 炽热芯
			_add(b, lathe_z(PackedVector2Array([Vector2(rf, size * 0.84), Vector2(rf * 0.92, size * 0.96), Vector2(rf * 0.72, size * 1.0)]), 24), m_dark)
			_add(b, A.cyl(rf * 0.68, size * 0.02, rf * 0.68, 24), A.emit(Color(1.0, 0.44, 0.10), 1.35), Vector3(0, 0, size * 0.99), Vector3(90, 0, 0))
		"cryo":
			var rc := size * 0.38
			var m_n2 := A.paint(Color(0.32, 0.40, 0.46), 0.48, 0.42, {"panel_scale": 0.0, "wear": 0.25})
			_add(b, lathe_z(PackedVector2Array([Vector2(rc * 0.8, size * 0.92), Vector2(rc, size * 0.82), Vector2(rc, -size * 0.66), Vector2(rc * 0.94, -size * 0.72)]), 24), m_n2)
			_add(b, lathe_z(PackedVector2Array([Vector2(rc * 0.94, -size * 0.72), Vector2(rc * 0.66, -size * 1.08), Vector2(rc * 0.30, -size * 1.30)]), 24), m_steel)
			_add(b, A.torus(rc * 0.96, rc * 1.08, 24), m_brass, Vector3(0, 0, size * 0.42), Vector3(90, 0, 0))
			# 安全泄压阀帽
			_add(b, A.cyl(rc * 0.30, size * 0.12, rc * 0.36, 20), m_steel, Vector3(0, 0, size * 0.96), Vector3(90, 0, 0))
			_add(b, A.torus(rc * 0.16, rc * 0.30, 24), m_copper, Vector3(0, 0, size * 1.03), Vector3(90, 0, 0))
		_:
			var rd := maxf(size * 0.42, 0.065)
			var Ld := maxf(size * 2.8, 0.52)
			_add(b, lathe_z(PackedVector2Array([Vector2(rd * 0.86, Ld * 0.36), Vector2(rd, Ld * 0.30), Vector2(rd * 0.94, -Ld * 0.22)]), 24), m_steel)
			var og := PackedVector2Array()
			for i in 11:
				var t := float(i) / 10.0
				og.append(Vector2(rd * 0.94 * sqrt(maxf(0.0, 1.0 - t * t)) + 0.006 * t, -Ld * 0.22 - t * Ld * 0.46))
			_add(b, lathe_z(og, 24), m_copper)
			_add(b, A.torus(rd * 0.98, rd * 1.10, 24), m_brass, Vector3(0, 0, Ld * 0.18), Vector3(90, 0, 0))


# ======================================================================
# P0-MSL-04 弹壳 / 弹托瓣 / 破片（粒子网格，带表面材质）
# ======================================================================

## 3D 弹壳：瓶颈收口 + 抽壳槽 + 底缘 + 空心弹口（16 段车削），轴沿 X（横置，配合粒子翻滚）
static func casing_mesh(heavy := false, red_shell := false) -> ArrayMesh:
	var key := "cas%s%s" % [heavy, red_shell]
	if _cache.has(key):
		return _cache[key]
	var r := 0.018 if heavy else 0.011
	var l := 0.125 if heavy else 0.082
	var x0 := -l * 0.5
	var pr: PackedVector2Array
	if red_shell:
		# 霰弹壳：抽壳槽、黄铜底座肩部、压筋壳身和折叠封口。
		pr = PackedVector2Array([
			Vector2(0.0, x0), Vector2(r * 1.13, x0), Vector2(r * 1.16, x0 + l * 0.04),
			Vector2(r * 0.98, x0 + l * 0.07), Vector2(r * 0.98, x0 + l * 0.10),
			Vector2(r * 1.09, x0 + l * 0.12), Vector2(r * 1.09, x0 + l * 0.22),
			Vector2(r * 1.01, x0 + l * 0.24), Vector2(r, x0 + l * 0.25),
			Vector2(r, x0 + l * 0.51), Vector2(r, x0 + l * 0.52), Vector2(r, x0 + l * 0.59),
			Vector2(r, x0 + l * 0.60), Vector2(r, x0 + l * 0.93), Vector2(r * 0.97, x0 + l * 0.97),
			Vector2(r * 0.82, x0 + l), Vector2(r * 0.45, x0 + l * 0.985), Vector2(0.0, x0 + l * 0.97),
		])
	else:
		pr = PackedVector2Array([Vector2(0.0, x0), Vector2(r * 0.28, x0), Vector2(r * 0.28, x0 + 0.002), Vector2(r * 1.08, x0 + 0.0005), Vector2(r * 1.08, x0 + l * 0.06),
			Vector2(r * 0.86, x0 + l * 0.08), Vector2(r * 0.86, x0 + l * 0.12), Vector2(r, x0 + l * 0.14), Vector2(r * 0.95, x0 + l * 0.68),
			Vector2(r * 0.66, x0 + l * 0.80), Vector2(r * 0.60, x0 + l), Vector2(r * 0.48, x0 + l), Vector2(r * 0.48, x0 + l * 0.78), Vector2(0.0, x0 + l * 0.76)])
	var lz := lathe_z(pr, 16)
	# 旋到 X 轴并挂材质
	var st := SurfaceTool.new()
	st.create_from(lz, 0)
	var arr := st.commit_to_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var cols := PackedColorArray()
	for i in v.size():
		var along := clampf((v[i].z - x0) / l, 0.0, 1.0)
		var turn := uv[i].x
		var edge_wear := 0.5 + 0.5 * sin(TAU * (turn * 13.0 + along * 2.0))
		var tint := Color(0.73, 0.49, 0.22).lerp(Color(0.43, 0.27, 0.13), smoothstep(0.60, 1.0, along) * 0.75)
		if red_shell and along > 0.245:
			tint = Color(0.58, 0.16, 0.10).lerp(Color(0.72, 0.27, 0.16), edge_wear * 0.60)
			if along > 0.515 and along < 0.595:
				tint = Color(0.34, 0.22, 0.15)
		cols.append(tint.darkened(edge_wear * 0.18))
		v[i] = Vector3(v[i].z, v[i].y, -v[i].x)
		nn[i] = Vector3(nn[i].z, nn[i].y, -nn[i].x)
		uv[i].y = along
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nn
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TANGENT] = null
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.albedo_texture = A.world_tex("steel_plate_a.png")
	mat.metallic = 0.29 if red_shell else 0.67
	mat.roughness = 0.59 if red_shell else 0.45
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.surface_set_material(0, mat)
	_cache[key] = m
	return m


## 脱壳穿甲弹弹托瓣：120° 弧形卡瓦（内弧贴弹芯、外弧带两道闭气槽、前端兜风扩口），包围盒约 0.055×0.042×0.19
static func sabot_petal_mesh(thick_k := 1.0) -> ArrayMesh:
	var key := "sabot%.3f" % thick_k
	if _cache.has(key):
		return _cache[key]
	var ri := 0.012
	var stations0 := [[-0.095, 0.034], [-0.085, 0.040], [-0.03, 0.040], [-0.025, 0.036], [-0.018, 0.036], [-0.013, 0.040], [0.02, 0.040], [0.025, 0.036], [0.032, 0.036], [0.037, 0.040], [0.07, 0.040], [0.095, 0.050]]
	# thick_k 只压缩径向壁厚（内径保持贴合弹杆）
	var stations: Array = []
	for s0 in stations0:
		stations.append([s0[0], ri + (float(s0[1]) - ri) * thick_k])
	var span := deg_to_rad(120.0)
	var na := 14
	var mid := (ri + ri + (0.040 - ri) * thick_k) * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var outer: Array = []
	var inner: Array = []
	for s in stations:
		var ro: Array = []
		var rn: Array = []
		for j in na + 1:
			var a := -span * 0.5 + span * float(j) / na + PI * 0.5
			ro.append(Vector3(cos(a) * float(s[1]), sin(a) * float(s[1]) - mid, float(s[0])))
			rn.append(Vector3(cos(a) * ri, sin(a) * ri - mid, float(s[0])))
		outer.append(ro)
		inner.append(rn)
	var ns := stations.size()
	for i in ns - 1:
		for j in na:
			_quad(st, [outer[i][j], outer[i + 1][j], outer[i + 1][j + 1], outer[i][j + 1]])
			_quad(st, [inner[i][j], inner[i][j + 1], inner[i + 1][j + 1], inner[i + 1][j]])
		# 两侧剖切面
		_quad(st, [inner[i][0], inner[i + 1][0], outer[i + 1][0], outer[i][0]])
		_quad(st, [inner[i][na], outer[i][na], outer[i + 1][na], inner[i + 1][na]])
	for j in na:
		_quad(st, [outer[0][j], outer[0][j + 1], inner[0][j + 1], inner[0][j]])
		_quad(st, [outer[ns - 1][j], inner[ns - 1][j], inner[ns - 1][j + 1], outer[ns - 1][j + 1]])
	st.generate_normals()
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.58, 0.60, 0.63)
	mat.metallic = 0.88
	mat.roughness = 0.44
	mat.albedo_texture = A.world_tex("steel_plate_a.png")
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * 15.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.surface_set_material(0, mat)
	_cache[key] = m
	return m


## 不规则切角破片 / 碎石 / 甲壳碎屑：扰动低纬度球 + 随机切面 + 平直硬边（每类 3 个变体，按 variant 取）
static func debris_mesh(kind := "metal", variant := 0) -> ArrayMesh:
	var key := "deb%s%d" % [kind, variant % 3]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind) + variant % 3 * 977
	var sz := Vector3(0.085, 0.052, 0.068) if kind != "rock" else Vector3(0.105, 0.072, 0.088)
	var nu := 9
	var nv := 5
	var planes: Array = []
	for k in 5:
		planes.append([Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.30, 0.42)])
	var pts: Array = []
	for iv in nv + 1:
		var th := PI * float(iv) / nv
		var row: Array = []
		for iu in nu:
			var ph := TAU * float(iu) / nu + (0.3 if iv % 2 == 1 else 0.0)
			var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			var p := d * rng.randf_range(0.42, 0.52)
			for pl in planes:
				var over: float = p.dot(pl[0]) - float(pl[1])
				if over > 0.0:
					p -= (pl[0] as Vector3) * over
			if kind == "metal":
				p.y = p.y * 0.32 + p.x * p.x * 0.6  # 翘起的薄装甲断片
			elif kind == "chitin":
				p.y = p.y * 0.35 + (p.x * p.x + p.z * p.z) * 0.6  # 弯曲甲壳片
			row.append(p * sz * 1.05)
		pts.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for iv in nv:
		for iu in nu:
			var u1 := (iu + 1) % nu
			var c := Color.from_hsv(0.0, 0.0, rng.randf_range(0.78, 1.0))
			st.set_color(c)
			var a: Vector3 = pts[iv][iu]
			var b2: Vector3 = pts[iv][u1]
			var c2: Vector3 = pts[iv + 1][u1]
			var d2: Vector3 = pts[iv + 1][iu]
			_tri(st, a, b2, c2)
			_tri(st, a, c2, d2)
	st.generate_normals()
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * 20.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if kind == "metal":
		mat.albedo_color = Color(0.68, 0.70, 0.74)
		mat.albedo_texture = A.world_tex("steel_plate_a.png")
		mat.metallic = 0.48
		mat.roughness = 0.34
	elif kind == "chitin":
		mat.albedo_color = Color(0.42, 0.45, 0.30)
		mat.albedo_texture = A._bug_tex("chitin_gray.png")
		mat.metallic = 0.22
		mat.roughness = 0.36
		mat.clearcoat_enabled = true
		mat.clearcoat = 0.8
	else:
		mat.albedo_color = Color(0.58, 0.54, 0.48)
		mat.albedo_texture = A.world_tex("rock_strata_a.png")
		mat.metallic = 0.05
		mat.roughness = 0.88
	m.surface_set_material(0, mat)
	_cache[key] = m
	return m


# ======================================================================
# P0-SKL-10 撤离引导信号弹罐（落地实体）
# ======================================================================
## 斜躺在地上的金属信号弹罐：24 段罐体 + 卷边端盖 + 排烟孔口（发光）+ 拉环拉栓 + 警示标签带 + 焦黑地痕。
## 返回排烟口的局部位置，供烟雾发射器挂载。
static func build_flare_canister(p: Node3D, glow: Color) -> Vector3:
	var root := Node3D.new()
	p.add_child(root)
	root.rotation_degrees = Vector3(0, 0, 86)
	root.position = Vector3(0, 0.068, 0)
	var shell := A.paint(Color(0.30, 0.32, 0.26), 0.55, 0.42, {"panel_scale": 0.0, "wear": 0.4, "rust": 0.2})
	var steel := A.metal(Color(0.42, 0.43, 0.42))
	var R := 0.062
	var H := 0.30
	_add(root, A.cyl(R, H, R, 24), shell, Vector3.ZERO)
	_add(root, A.cyl(R * 1.01, H * 0.22, R * 1.01, 24), A.paint(Color(0.92, 0.48, 0.14), 0.3, 0.5, {"panel_scale": 0.0, "wear": 0.3}), Vector3(0, H * 0.08, 0))
	# 卷边端盖
	for e in [-1.0, 1.0]:
		_add(root, A.torus(R * 0.94, R * 1.06, 32), steel, Vector3(0, e * H * 0.5, 0))
	_add(root, A.cyl(R * 0.96, 0.008, R * 0.96, 24), steel, Vector3(0, -H * 0.5 - 0.004, 0))
	# 顶部排烟盖：中心喷口 + 6 个侧排烟孔（发光）
	_add(root, A.cyl(R * 0.62, 0.04, R * 0.9, 24), steel, Vector3(0, H * 0.5 + 0.02, 0))
	var hot := A.emit(glow, 2.6)
	_add(root, A.cyl(R * 0.34, 0.006, R * 0.34, 20), hot, Vector3(0, H * 0.5 + 0.041, 0))
	for i in 6:
		var a := TAU * float(i) / 6.0
		_add(root, A.cyl(0.008, 0.012, 0.008, 16), hot, Vector3(cos(a) * R * 0.55, H * 0.5 + 0.03, sin(a) * R * 0.55), Vector3(cos(a) * 90.0, 0, -sin(a) * 90.0))
	# 拉环 + 拉栓（已拔出，挂在罐侧）
	_add(root, A.cyl(0.006, 0.05, 0.006, 16), steel, Vector3(R * 0.7, H * 0.5 + 0.03, 0), Vector3(0, 0, 90))
	_add(root, A.torus(0.016, 0.024, 24), steel, Vector3(R * 1.25, H * 0.42, 0), Vector3(0, 0, 0))
	# 焦黑地痕
	A.ground_decal(p, A.scorch_tex(), Color(0.05, 0.04, 0.03, 0.85), 1.1, Vector3(0.18, 0.02, 0))
	return root.transform * Vector3(0, H * 0.5 + 0.05, 0)


# ======================================================================
# P0-MSL-06 迫击炮弹（轴沿 Y，弹头 +Y）：泪滴形车削弹体 + 闭气环 + 带导气孔尾管 + 后掠尾翼
# ======================================================================
static func build_lob_shell(body: Node3D, c: Color) -> void:
	var m_shell := A.metal(Color(0.22, 0.25, 0.26))
	var m_rust := A.paint(Color(0.36, 0.24, 0.16), 0.48, 0.58, {"rust": 0.65})
	var m_band := A.paint(c.darkened(0.30), 0.38, 0.48, {"rust": 0.35, "wear": 0.3})
	var m_brass := A.paint(Color(0.86, 0.65, 0.22), 0.88, 0.28, {"panel_scale": 0.0, "wear": 0.15})
	# 泪滴弹体（尾锥 → 最大径 → 卵形头），32 段平滑车削
	var prof := PackedVector2Array()
	for i in 21:
		var t := float(i) / 20.0
		var y := lerpf(-0.26, 0.40, t)
		var r := 0.205 * pow(sin(clampf(t * 1.08, 0.0, 1.0) * PI * 0.5 + 0.0), 0.5) if t < 0.45 else 0.205 * sqrt(maxf(0.0, 1.0 - pow((t - 0.45) / 0.55, 2.0))) * 0.98 + 0.012 * (t - 0.45) / 0.55
		prof.append(Vector2(maxf(r, 0.05), y))
	_add(body, DM.lathe(prof, 32, true, false), m_shell)
	# 风帽 + 黄铜碰炸引信（车削）
	_add(body, DM.lathe(PackedVector2Array([Vector2(0.075, 0.38), Vector2(0.068, 0.47), Vector2(0.050, 0.50)]), 28, false, true), m_rust)
	_add(body, DM.lathe(PackedVector2Array([Vector2(0.046, 0.50), Vector2(0.040, 0.56), Vector2(0.026, 0.60), Vector2(0.0, 0.625)]), 24, true, false), m_brass)
	_add(body, A.torus(0.040, 0.054, 24), m_brass, Vector3(0, 0.505, 0))
	# 识别色带 + 黄黑高危环 + 闭气环
	_add(body, A.cyl(0.207, 0.08, 0.207, 36), A.hazard(), Vector3(0, 0.12, 0))
	_add(body, A.cyl(0.199, 0.10, 0.206, 36), m_band, Vector3(0, -0.02, 0))
	for y in [0.055, 0.075]:
		_add(body, A.torus(0.200, 0.214, 36), m_shell, Vector3(0, y, 0))
	# 尾管：带 2×6 导气孔 + 末端法兰
	_add(body, A.cyl(0.048, 0.28, 0.052, 24), m_shell, Vector3(0, -0.38, 0))
	for k in 2:
		for i in 6:
			var a := TAU * float(i) / 6.0 + k * 0.5
			_add(body, A.cyl(0.011, 0.012, 0.011, 16), K.bore_mat(), Vector3(cos(a) * 0.05, -0.33 - k * 0.07, sin(a) * 0.05), Vector3(0, -rad_to_deg(a), 90))
	_add(body, A.torus(0.044, 0.062, 24), m_shell, Vector3(0, -0.515, 0))
	# 4 片后掠倒角尾翼（两对对置翼，翼根贴尾管）
	var fin := fin_pair(Vector3(0.024, 0.40, 0.26), 0.28, 0.66)
	for k in 2:
		var n := Node3D.new()
		body.add_child(n)
		n.position = Vector3(0, -0.40, 0)
		n.rotation_degrees = Vector3(0, 45.0 + k * 90.0, 0)
		_add(n, fin, m_shell, Vector3.ZERO, Vector3(90, 0, 0))


# ======================================================================
# P0-MSL-07 首领重型动能穿甲弹（轴沿 Y，弹头 +Y）
# ======================================================================
static func build_kinetic_slug(body: Node3D, m_tracer: Material) -> void:
	var m_tung := A.metal(Color(0.24, 0.26, 0.28))
	var m_brass := A.paint(Color(0.86, 0.65, 0.22), 0.88, 0.28, {"panel_scale": 0.0, "wear": 0.15})
	# 钨合金穿杆（微锥）+ 弹道风帽 + 钨芯尖
	_add(body, DM.lathe(PackedVector2Array([Vector2(0.105, -0.43), Vector2(0.098, 0.20), Vector2(0.085, 0.43)]), 24, true, false), m_tung)
	var og := PackedVector2Array()
	for i in 11:
		var t := float(i) / 10.0
		og.append(Vector2(0.085 * sqrt(maxf(0.0, 1.0 - t * t)) * (1.0 - 0.6 * t) + 0.012 * t, 0.43 + t * 0.30))
	_add(body, DM.lathe(og, 24, false, false), m_tracer)
	_add(body, DM.lathe(PackedVector2Array([Vector2(0.016, 0.73), Vector2(0.008, 0.77), Vector2(0.0, 0.79)]), 20, false, false), A.chrome())
	# 闭气弹带（双环）
	_add(body, A.cyl(0.128, 0.09, 0.128, 28), m_brass, Vector3(0, 0.12, 0))
	for y in [0.07, 0.17]:
		_add(body, A.torus(0.118, 0.136, 28), m_brass, Vector3(0, y, 0))
	# 曳光尾杯
	_add(body, DM.lathe(PackedVector2Array([Vector2(0.066, -0.57), Vector2(0.084, -0.52), Vector2(0.10, -0.43)]), 24, true, false), m_tracer)
	# 4 片后掠穿甲稳定尾翼
	var fin := fin_pair(Vector3(0.020, 0.34, 0.24), 0.45, 0.45)
	for k in 2:
		var n := Node3D.new()
		body.add_child(n)
		n.position = Vector3(0, -0.30, 0)
		n.rotation_degrees = Vector3(0, k * 90.0, 0)
		_add(n, fin, m_tung, Vector3.ZERO, Vector3(90, 0, 0))


## 尾翼稳定脱壳穿甲箭弹（APFSDS）：沿局部 +Y 为弹头方向。
## 钨杆（微锥 + 尖锐钨芯）+ 锯齿闭气槽 8 圈 + 6 片后掠尾翼 + 曳光尾杯 + 尾焰辉光，
## 三瓣铝合金弹托卡在中段；返回三瓣弹托节点（调用方可在出膛后令其散开）。
static func build_apfsds_dart(p: Node3D, r: float, L: float, tracer_c := Color(1.0, 0.72, 0.36), with_sabot := true) -> Array:
	var m_tung := A.metal(Color(0.22, 0.24, 0.26))
	var m_sabot := A.paint(Color(0.62, 0.64, 0.66), 0.82, 0.34, {"panel_scale": 0.0, "wear": 0.2})
	var m_tr := A.emit(tracer_c, 5.0)
	# 钨杆 + 弹尖
	var prof := PackedVector2Array([Vector2(r * 0.86, -L * 0.50), Vector2(r * 0.92, -L * 0.30), Vector2(r, L * 0.22)])
	for i in 9:
		var t := float(i + 1) / 9.0
		prof.append(Vector2(r * (1.0 - t) * (1.0 - 0.35 * t) + r * 0.08 * t, L * 0.22 + t * L * 0.26))
	prof.append(Vector2(0.0, L * 0.50))
	_add(p, DM.lathe(prof, 20, true, false), m_tung)
	_add(p, DM.lathe(PackedVector2Array([Vector2(r * 0.22, L * 0.45), Vector2(0.0, L * 0.50)]), 16, false, false), A.chrome())
	# 锯齿闭气槽（弹托咬合段）
	for gi in 8:
		_add(p, A.cyl(r * 1.10, L * 0.016, r * 1.16, 20), m_tung, Vector3(0, -L * 0.10 + gi * L * 0.035, 0))
	# 6 片后掠尾翼
	var fin := fin_pair(Vector3(r * 0.22, r * 5.6, L * 0.17), 0.55, 0.40)
	for k in 3:
		var n := Node3D.new()
		p.add_child(n)
		n.position = Vector3(0, -L * 0.41, 0)
		n.rotation_degrees = Vector3(0, k * 60.0, 0)
		_add(n, fin, m_tung, Vector3.ZERO, Vector3(90, 0, 0))
	# 曳光尾杯 + 尾焰辉光
	_add(p, DM.lathe(PackedVector2Array([Vector2(r * 0.55, -L * 0.54), Vector2(r * 0.86, -L * 0.50)]), 16, true, false), m_tr)
	var glow := _add(p, A.cyl(r * 0.05, L * 0.9, r * 0.7, 16), m_tr, Vector3(0, -L * 0.98, 0))
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not with_sabot:
		return []
	# 三瓣弹托（内径贴合弹杆，壁厚压到 0.4，外径约为杆径 2 倍，长约 1/4 杆长）
	var tk := 0.4
	var sab := sabot_petal_mesh(tk)
	var sc_r := r * 1.06 / 0.012
	var sc_z := L * 0.24 / 0.19
	var mid := (0.012 + 0.012 + (0.040 - 0.012) * tk) * 0.5
	var petals: Array = []
	for k in 3:
		var holder := Node3D.new()
		p.add_child(holder)
		holder.position = Vector3(0, L * 0.02, 0)
		holder.rotation_degrees = Vector3(0, k * 120.0, 0)
		var mi := _add(holder, sab, m_sabot, Vector3(0, 0, -mid * sc_r), Vector3(-90, 0, 0))
		mi.scale = Vector3(sc_r, sc_r, sc_z)
		petals.append(holder)
	return petals


## 车削实弹弹丸（沿局部 +Y 为弹头方向，长 bl、半径 br）：按口径给出真实外形——
## 被甲弹（船尾 + 压痕槽 + 正切尖拱，穿甲弹黑尖）、榴弹（铜弹带 + 引信头 + 识别色环）、
## 线圈弹（铁芯 + 铜环 + 尾翼）、福斯特独头弹（空心底 + 8 条膛线肋）、箭形霰弹（针杆 + 4 翼），尾部曳光杯发光。
static func build_tracer_round(p: Node3D, caliber: String, br: float, bl: float, c: Color) -> void:
	var m_cu := A.paint(Color(0.80, 0.44, 0.24), 0.9, 0.26, {"panel_scale": 0.0, "wear": 0.1})
	var m_brass := A.paint(Color(0.88, 0.66, 0.22), 0.9, 0.25, {"panel_scale": 0.0, "wear": 0.1})
	var m_steel := A.metal(Color(0.30, 0.32, 0.34))
	var m_lead := A.paint(Color(0.42, 0.43, 0.45), 0.5, 0.55, {"panel_scale": 0.0})
	var m_cup := A.emit(c, 3.2)
	var h := bl * 0.5
	match caliber:
		"apfsds":
			build_apfsds_dart(p, br * 0.62, bl, c, false)
			return
		"cannon", "ac30":
			var body := A.paint(Color(0.24, 0.28, 0.18) if caliber == "cannon" else Color(0.30, 0.31, 0.30), 0.4, 0.45, {"panel_scale": 0.0, "wear": 0.25})
			var pr := PackedVector2Array([Vector2(br * 0.80, -h), Vector2(br * 0.96, -h * 0.80), Vector2(br * 0.96, h * 0.05)])
			for i in 8:
				var t := float(i + 1) / 8.0
				pr.append(Vector2(br * 0.96 * sqrt(maxf(0.0, 1.0 - t * t * 0.85)), h * 0.05 + t * h * 0.55))
			_add(p, DM.lathe(pr, 28, true, true), body)
			# 引信头
			_add(p, DM.lathe(PackedVector2Array([Vector2(br * 0.40, h * 0.58), Vector2(br * 0.36, h * 0.80), Vector2(br * 0.16, h * 0.98), Vector2(0.0, h)]), 24, true, false), m_brass)
			# 铜弹带（凸起双环）+ 识别色环
			_add(p, A.cyl(br * 1.04, bl * 0.06, br * 1.04, 28), m_cu, Vector3(0, -h * 0.58, 0))
			_add(p, A.cyl(br * 1.04, bl * 0.03, br * 1.04, 28), m_cu, Vector3(0, -h * 0.44, 0))
			_add(p, A.cyl(br * 0.975, bl * 0.05, br * 0.975, 28), A.paint(Color(0.86, 0.70, 0.16) if caliber == "cannon" else Color(0.82, 0.22, 0.12), 0.2, 0.45, {"panel_scale": 0.0}), Vector3(0, h * 0.20, 0))
		"coil":
			_add(p, DM.lathe(PackedVector2Array([Vector2(br * 0.70, -h), Vector2(br * 0.70, h * 0.30), Vector2(br * 0.40, h * 0.80), Vector2(0.0, h)]), 24, true, false), m_steel)
			for i in 3:
				_add(p, A.torus(br * 0.66, br * 0.98, 24), m_cu, Vector3(0, -h * 0.30 + i * h * 0.26, 0))
			var fin := fin_pair(Vector3(br * 0.18, br * 2.6, bl * 0.22), 0.5, 0.45)
			for k in 2:
				var n := Node3D.new()
				p.add_child(n)
				n.position = Vector3(0, -h * 0.72, 0)
				n.rotation_degrees = Vector3(0, k * 90.0, 0)
				_add(n, fin, m_steel, Vector3.ZERO, Vector3(90, 0, 0))
		"slug":
			# 福斯特独头弹：圆头 + 空心底 + 8 条斜膛线肋
			var pr := PackedVector2Array([Vector2(br * 0.60, -h), Vector2(br * 0.98, -h * 0.92), Vector2(br, h * 0.20)])
			for i in 7:
				var t := float(i + 1) / 7.0
				pr.append(Vector2(br * sqrt(maxf(0.0, 1.0 - t * t)), h * 0.20 + t * h * 0.80))
			_add(p, DM.lathe(pr, 28, false, false), m_lead)
			_add(p, DM.lathe(PackedVector2Array([Vector2(br * 0.60, -h), Vector2(br * 0.45, -h * 0.30), Vector2(0.0, -h * 0.20)]), 24, false, false), A.metal(Color(0.12, 0.12, 0.13)))
			for i in 8:
				var a := TAU * float(i) / 8.0
				_add(p, A.bevel_box(Vector3(br * 0.14, bl * 0.50, br * 0.14), br * 0.04), m_lead, Vector3(cos(a) * br * 0.96, -h * 0.20, sin(a) * br * 0.96), Vector3(0, -rad_to_deg(a), 0))
			return
		"pellet":
			# 箭形霰弹：钢针杆 + 尖头 + 4 片冲压尾翼
			_add(p, DM.lathe(PackedVector2Array([Vector2(br * 0.30, -h), Vector2(br * 0.30, h * 0.55), Vector2(0.0, h)]), 20, true, false), m_steel)
			var fin2 := fin_pair(Vector3(br * 0.10, br * 2.2, bl * 0.30), 0.55, 0.35)
			for k in 2:
				var n := Node3D.new()
				p.add_child(n)
				n.position = Vector3(0, -h * 0.70, 0)
				n.rotation_degrees = Vector3(0, k * 90.0, 0)
				_add(n, fin2, m_cu, Vector3.ZERO, Vector3(90, 0, 0))
			return
		_:
			# 被甲弹：船尾 + 压痕槽 + 正切尖拱；穿甲狙击弹涂黑尖
			var pr := PackedVector2Array([Vector2(br * 0.74, -h), Vector2(br, -h * 0.62), Vector2(br, -h * 0.22), Vector2(br * 0.93, -h * 0.18), Vector2(br * 0.93, -h * 0.10), Vector2(br, -h * 0.06), Vector2(br, h * 0.02)])
			for i in 10:
				var t := float(i + 1) / 10.0
				pr.append(Vector2(br * (1.0 - t) * (1.0 + 0.55 * t) * 0.95 + br * 0.02 * t, h * 0.02 + t * h * 0.98))
			_add(p, DM.lathe(pr, 28, true, false), m_cu if caliber != "hmg" else m_brass)
			if caliber == "sniper_ap":
				_add(p, DM.lathe(PackedVector2Array([Vector2(br * 0.42, h * 0.70), Vector2(br * 0.20, h * 0.88), Vector2(0.0, h * 1.005)]), 24, false, false), A.metal(Color(0.06, 0.06, 0.07)))
	# 曳光尾杯
	_add(p, DM.lathe(PackedVector2Array([Vector2(br * 0.40, -h - bl * 0.03), Vector2(br * 0.70, -h + 0.0005)]), 20, true, false), m_cup)
