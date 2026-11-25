extends RefCounted
## 深渊晶簇测绘仪阵列（精修高精版） (Damaged Abyssal Crystal Survey Rig)
## 清单编号：P1-LM-04D | 优先级：P1 | 目标路径：scripts/models/lm_crystal_survey_rig.gd
## 替换原仓未更新旧模：landmarks.gd::_crystal_cluster()
## 标准占地：Vector3(6.4, 4.1, 5.8) | 全曲面已通过 docs/low_poly_model_audit.md 与 building_pack_audit 红线校验
## 特性：多面非对称天然晶柱（带微倒角晶棱、生长台阶、菱面体尖顶与贝壳状断口）+ 专属视差折射压电晶簇着色器
##       + 火山黑曜玄武岩碎裂岩盘 + 护笼遥测控制台、透视晶芯采样罐与偏折激光光谱仪。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")
const CRYSTAL_SHADER = preload("res://shaders/abyss_crystal.gdshader")

static var _crystal_mat_cache: ShaderMaterial = null


static func _crystal_mat() -> ShaderMaterial:
	if _crystal_mat_cache != null:
		return _crystal_mat_cache
	var m := ShaderMaterial.new()
	m.shader = CRYSTAL_SHADER
	m.set_shader_parameter("deep_color", Color(0.010, 0.044, 0.105))
	m.set_shader_parameter("mid_color", Color(0.032, 0.235, 0.340))
	m.set_shader_parameter("tip_color", Color(0.200, 0.760, 0.850))
	m.set_shader_parameter("outer_violet", Color(0.090, 0.100, 0.320))
	m.set_shader_parameter("core_glow_color", Color(0.200, 0.920, 0.980))
	m.set_shader_parameter("edge_glow_color", Color(0.580, 0.990, 1.000))
	m.set_shader_parameter("glow_strength", 1.02)
	_crystal_mat_cache = m
	return m


static func _emit_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, out_hint: Vector3) -> void:
	var fn := -(b - a).cross(c - a)
	if fn.length_squared() < 1e-12:
		return
	if fn.dot(out_hint) < 0.0:
		var tb := b
		b = c
		c = tb
		var tcb := cb
		cb = cc
		cc = tcb
		fn = -fn
	fn = fn.normalized()
	st.set_normal(fn)
	st.set_color(ca)
	st.add_vertex(a)
	st.set_normal(fn)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_normal(fn)
	st.set_color(cc)
	st.add_vertex(c)


static func _emit_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color, out_hint: Vector3) -> void:
	_emit_tri(st, a, b, c, ca, cb, cc, out_hint)
	_emit_tri(st, a, c, d, ca, cc, cd, out_hint)


## 生成单根天然多面石英/深渊压电晶柱（带微倒角晶棱、可选生长台阶、非对称尖顶或斜断裂面，保证 100% 外向平直面法线）
static func _crystal_shard_mesh(
	rad: float,
	height: float,
	sides: int,
	energy: float,
	seed_id: int,
	fractured := false,
	stepped := false
) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_id * 9781 + 1337
	var phase := rng.randf()
	var en := clampf(energy, 0.0, 1.0)

	# 天然非等边晶面轮廓：交错宽窄面 + 轻微角偏移
	var base_pts: Array[Vector2] = []
	for i in sides:
		var ang := TAU * float(i) / float(sides) + rng.randf_range(-0.085, 0.085)
		var alt := 1.08 if (i % 2 == 0) else 0.92
		var rr := rad * alt * rng.randf_range(0.88, 1.12)
		base_pts.append(Vector2(cos(ang) * rr, sin(ang) * rr))

	# 每个晶棱拆出左右一对微倒角点（宽晶面 edge=0.0，窄棱边倒角 edge=1.0）
	var prof_xy: Array[Vector2] = []
	var prof_edge: Array[float] = []
	var bevel := 0.095
	for i in sides:
		var p_prev := base_pts[(i + sides - 1) % sides]
		var p_cur := base_pts[i]
		var p_next := base_pts[(i + 1) % sides]
		prof_xy.append(p_cur.lerp(p_prev, bevel))
		prof_edge.append(1.0)
		prof_xy.append(p_cur.lerp(p_next, bevel))
		prof_edge.append(1.0)
	var m := prof_xy.size()

	# 逐层高度截面（y = 0 埋入岩根，y = height 为晶尖）
	var ring_defs: Array = []
	ring_defs.append([0.0, 1.10, 0.0, 0.0])
	ring_defs.append([height * 0.22, 1.00, 0.22, 0.0])
	if stepped and not fractured:
		ring_defs.append([height * 0.54, 0.96, 0.54, 0.0])
		ring_defs.append([height * 0.585, 0.80, 0.585, 0.02])
		ring_defs.append([height * 0.76, 0.77, 0.76, 0.045])
	elif not fractured:
		var sh_h := rng.randf_range(0.68, 0.77)
		var sh_s := rng.randf_range(0.80, 0.92)
		ring_defs.append([height * sh_h, sh_s, sh_h, 0.05])
	else:
		# 断口晶柱：斜切破裂肩线
		ring_defs.append([height * 0.84, 0.90, 0.84, 0.14])

	var tilt_vec := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
	var rings: Array = []
	var ring_hfracs: Array[float] = []
	for rd in ring_defs:
		var y0: float = float(rd[0])
		var scl: float = float(rd[1])
		var hf: float = float(rd[2])
		var jitter_h: float = float(rd[3])
		var pts: Array[Vector3] = []
		for j in m:
			var p2 := prof_xy[j] * scl
			var dy := 0.0
			if jitter_h > 0.0:
				var dir_f := (p2 / maxf(rad, 0.01)).dot(tilt_vec)
				if fractured:
					dy = dir_f * height * jitter_h + (0.04 * height if (j % 4 == 0) else -0.02 * height)
				else:
					dy = dir_f * height * jitter_h
			pts.append(Vector3(p2.x, maxf(0.01, y0 + dy), p2.y))
		rings.append(pts)
		ring_hfracs.append(hf)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 侧面晶柱与微倒角棱边：偶数索引对 (2k, 2k+1) 为棱边倒角条，奇数索引对 (2k+1, 2k+2) 为宽主晶面
	for ri in rings.size() - 1:
		var r0: Array = rings[ri]
		var r1: Array = rings[ri + 1]
		var h0 := ring_hfracs[ri]
		var h1 := ring_hfracs[ri + 1]
		for j in m:
			var j2 := (j + 1) % m
			var is_bevel := (j % 2 == 0)
			var e_mask := 1.0 if is_bevel else 0.0
			var a: Vector3 = r0[j]
			var b: Vector3 = r0[j2]
			var c: Vector3 = r1[j2]
			var d: Vector3 = r1[j]
			var mid_xz := Vector3((a.x + b.x + c.x + d.x) * 0.25, 0.0, (a.z + b.z + c.z + d.z) * 0.25)
			var out_h := mid_xz.normalized() if mid_xz.length_squared() > 1e-6 else Vector3.RIGHT
			if stepped and ri == 2:
				out_h = (out_h * 0.45 + Vector3.UP * 0.88).normalized()
			var c_bot := Color(h0, e_mask, en, phase)
			var c_top := Color(h1, e_mask, en, phase)
			_emit_quad(st, a, b, c, d, c_bot, c_bot, c_top, c_top, out_h)

	var top_ring: Array = rings[rings.size() - 1]
	var top_hf := ring_hfracs[ring_hfracs.size() - 1]

	if not fractured:
		# 菱面体尖顶过渡环 + 非对称晶尖（形成锐利宝石多面切冠）
		var apex_ox := rng.randf_range(-rad * 0.16, rad * 0.16)
		var apex_oz := rng.randf_range(-rad * 0.16, rad * 0.16)
		var crown_y := height * 0.945
		var apex := Vector3(apex_ox, height, apex_oz)
		var crown_ring: Array[Vector3] = []
		for j in m:
			var tp: Vector3 = top_ring[j]
			var cp := tp.lerp(apex, 0.84)
			cp.y = maxf(tp.y + 0.02, crown_y + (tp.y - height * top_hf) * 0.18)
			crown_ring.append(cp)

		for j in m:
			var j2 := (j + 1) % m
			var is_bevel := (j % 2 == 0)
			var e_mask := 1.0 if is_bevel else 0.08
			var a: Vector3 = top_ring[j]
			var b: Vector3 = top_ring[j2]
			var c: Vector3 = crown_ring[j2]
			var d: Vector3 = crown_ring[j]
			var out_h := (Vector3((a.x + b.x) * 0.5, 0.0, (a.z + b.z) * 0.5).normalized() * 0.72 + Vector3.UP * 0.70).normalized()
			var c0 := Color(top_hf, e_mask, en, phase)
			var c1 := Color(0.95, 0.88 if is_bevel else 0.22, en, phase)
			_emit_quad(st, a, b, c, d, c0, c0, c1, c1, out_h)
			# 顶部收尖三角面
			var ca_tip := Color(1.0, 0.92, en, phase)
			_emit_tri(st, d, c, apex, c1, c1, ca_tip, (out_h * 0.45 + Vector3.UP * 0.89).normalized())
	else:
		# 贝壳状斜裂断口：微凸折脊断芯 + 高亮断裂棱边
		var c_sum := Vector3.ZERO
		for p: Vector3 in top_ring:
			c_sum += p
		var f_ctr := c_sum / float(m) + Vector3(tilt_vec.x * rad * 0.14, height * 0.06, tilt_vec.y * rad * 0.14)
		var c_edge := Color(0.90, 0.78, minf(1.0, en + 0.15), phase)
		var c_core := Color(0.96, 0.45, minf(1.0, en + 0.22), phase)
		for j in m:
			var j2 := (j + 1) % m
			var a: Vector3 = top_ring[j]
			var b: Vector3 = top_ring[j2]
			_emit_tri(st, a, b, f_ctr, c_edge, c_edge, c_core, Vector3.UP)

	# 底面封口（防止任何穿帮漏底）
	var bot_ring: Array = rings[0]
	var bot_ctr := Vector3(0.0, 0.0, 0.0)
	var c_root := Color(0.0, 0.0, en, phase)
	for j in m:
		var j2 := (j + 1) % m
		_emit_tri(st, bot_ring[j2], bot_ring[j], bot_ctr, c_root, c_root, c_root, Vector3.DOWN)

	return st.commit()


static func _add_shard(
	parent: Node3D,
	mat: Material,
	pos: Vector3,
	rot_deg: Vector3,
	rad: float,
	height: float,
	sides: int,
	energy: float,
	seed_id: int,
	fractured := false,
	stepped := false,
	cast_shadow := true
) -> MeshInstance3D:
	var mesh := _crystal_shard_mesh(rad, height, sides, energy, seed_id, fractured, stepped)
	return A.add(parent, mesh, mat, pos, rot_deg, Vector3.ONE, cast_shadow)


static func build(target_sz := Vector3(6.4, 4.1, 5.8)) -> Node3D:
	var root := Node3D.new()
	root.name = "CrystalSurveyRig"
	var base_sz := Vector3(6.4, 4.1, 5.8)
	root.scale = Vector3(target_sz.x / base_sz.x, target_sz.y / base_sz.y, target_sz.z / base_sz.z)

	var M_BODY := K.armor(Color("#b58528"), 0.76)
	var M_STEEL := K.armor_sub(Color("#474f57"), 0.80)
	var M_ROCK_MAIN := A.rock_mat(Color("#262431"))
	var M_ROCK_DARK := A.rock_mat(Color("#191822"))
	var M_ROCK_CRUST := A.rock_mat(Color("#323040"))
	var M_CHAR := A.paint(Color("#221f1e"), 0.14, 0.94, {"wear": 0.82, "rust": 0.44, "dust": 0.56, "panel_scale": 0.0})
	var M_GUNMETAL := K.gunmetal()
	var M_DARK := K.dark()
	var M_CHROME := A.chrome()
	var M_BRASS := K.brass()
	var M_HAZARD := A.hazard()
	var M_BORE := K.bore_mat()
	var M_CRYSTAL := _crystal_mat()
	var M_LASER := A.emit(Color("#38f2ff"), 2.8)
	var M_SCORCH := A.emit(Color("#ff8e30"), 2.2)
	var M_AMBERGLOW := A.emit(Color("#e09226"), 1.7)
	var M_SCREEN := A.emit(Color("#28d8c8"), 1.6)

	# =========================================================================
	# 1. 火山黑曜玄武岩碎裂岩盘 + 32 根多尺度深渊压电晶簇（天然生长集群 + 断晶残片）
	# =========================================================================
	var n_1 := K.node(root, Vector3.ZERO, Vector3.ZERO, "AbyssalCrystalCluster")

	# 有机火山岩脊与破土碎岩盘（彻底替代原先三层正六边形饼盘）
	var rock_specs := [
		# [variant, pos, rot_deg, scale, mat]
		[0, Vector3(-0.55, 0.24, -0.32), Vector3(4.0, 18.0, -5.0), Vector3(2.35, 0.72, 2.05), M_ROCK_DARK],
		[3, Vector3(-1.35, 0.22, -0.82), Vector3(-8.0, 64.0, 12.0), Vector3(1.55, 0.78, 1.28), M_ROCK_MAIN],
		[5, Vector3(0.42, 0.18, -0.88), Vector3(10.0, -42.0, -9.0), Vector3(1.48, 0.68, 1.32), M_ROCK_MAIN],
		[2, Vector3(-1.42, 0.16, 0.54), Vector3(6.0, 118.0, 14.0), Vector3(1.42, 0.62, 1.18), M_ROCK_CRUST],
		[7, Vector3(0.32, 0.15, 0.42), Vector3(-12.0, -108.0, -8.0), Vector3(1.36, 0.54, 1.15), M_ROCK_MAIN],
		[1, Vector3(-0.52, 0.44, -0.34), Vector3(-5.0, 145.0, 7.0), Vector3(1.42, 0.66, 1.30), M_ROCK_CRUST],
		[4, Vector3(-0.35, 0.12, -1.55), Vector3(14.0, 28.0, -11.0), Vector3(1.25, 0.52, 0.96), M_ROCK_DARK],
		[6, Vector3(-2.08, 0.10, -0.14), Vector3(-6.0, 88.0, 16.0), Vector3(1.05, 0.44, 0.94), M_ROCK_MAIN],
		[8, Vector3(1.02, 0.09, -0.18), Vector3(9.0, -68.0, -14.0), Vector3(0.95, 0.38, 0.88), M_ROCK_DARK],
		[9, Vector3(-0.88, 0.08, 1.12), Vector3(-10.0, 152.0, 8.0), Vector3(1.08, 0.36, 0.84), M_ROCK_MAIN],
		# 周边散落碎石与激光灼烧块
		[10, Vector3(0.18, 0.10, 1.66), Vector3(12.0, 26.0, -14.0), Vector3(0.54, 0.30, 0.46), M_ROCK_CRUST],
		[11, Vector3(-1.82, 0.08, 1.24), Vector3(-8.0, 72.0, 10.0), Vector3(0.48, 0.24, 0.42), M_ROCK_DARK],
		[2, Vector3(0.96, 0.07, 1.05), Vector3(6.0, -34.0, 11.0), Vector3(0.42, 0.20, 0.38), M_ROCK_MAIN],
		[5, Vector3(-0.08, 0.07, -2.18), Vector3(-9.0, 44.0, -6.0), Vector3(0.56, 0.26, 0.48), M_ROCK_DARK],
	]
	for rs in rock_specs:
		A.add(n_1, A.rock_mesh(int(rs[0]), 28), rs[4], rs[1], rs[2], rs[3], true)

	# 岩盘裂缝间渗出的低矮晶化地脉结壳（增强晶根与火山岩共生感）
	_add_shard(n_1, M_CRYSTAL, Vector3(-0.92, 0.28, 0.32), Vector3(58.0, 22.0, 14.0), 0.12, 0.56, 5, 0.72, 101, false, false, false)
	_add_shard(n_1, M_CRYSTAL, Vector3(0.06, 0.26, 0.18), Vector3(54.0, -48.0, -12.0), 0.11, 0.52, 6, 0.80, 102, false, false, false)
	_add_shard(n_1, M_CRYSTAL, Vector3(-0.22, 0.32, -0.98), Vector3(-52.0, 18.0, -16.0), 0.13, 0.62, 5, 0.55, 103, false, false, false)
	_add_shard(n_1, M_CRYSTAL, Vector3(-1.32, 0.25, -0.44), Vector3(-44.0, 82.0, 24.0), 0.12, 0.58, 6, 0.48, 104, false, false, false)

	# 核心主晶塔（带台阶双生伴晶 + 非对称菱面体锐尖）
	_add_shard(n_1, M_CRYSTAL, Vector3(-0.54, 0.24, -0.32), Vector3(4.0, 14.0, -6.5), 0.43, 3.82, 6, 0.96, 201, false, true, true)
	_add_shard(n_1, M_CRYSTAL, Vector3(-0.34, 0.30, -0.52), Vector3(-12.0, -28.0, -14.0), 0.27, 2.74, 6, 0.88, 202, false, true, true)
	_add_shard(n_1, M_CRYSTAL, Vector3(-0.78, 0.32, -0.14), Vector3(13.0, 52.0, 11.0), 0.25, 2.42, 6, 0.74, 203, false, true, true)

	# 中圈 6 根辐射次主晶柱（高能冰青与深渊冷蓝紫交错，形成强烈明暗景深）
	_add_shard(n_1, M_CRYSTAL, Vector3(0.16, 0.26, -0.76), Vector3(-18.0, -36.0, -22.0), 0.30, 2.48, 6, 0.84, 204, false, true, true)
	_add_shard(n_1, M_CRYSTAL, Vector3(-1.16, 0.22, -0.86), Vector3(-22.0, 116.0, -16.0), 0.27, 2.18, 6, 0.38, 205, false, false, true)
	_add_shard(n_1, M_CRYSTAL, Vector3(-1.28, 0.20, 0.22), Vector3(24.0, 62.0, 22.0), 0.28, 1.96, 5, 0.44, 206, false, false, true)
	_add_shard(n_1, M_CRYSTAL, Vector3(-0.18, 0.22, 0.48), Vector3(28.0, -12.0, 14.0), 0.24, 1.88, 6, 0.62, 207, false, false, true)
	_add_shard(n_1, M_CRYSTAL, Vector3(0.46, 0.20, 0.08), Vector3(16.0, -76.0, -28.0), 0.22, 1.72, 6, 0.86, 208, false, false, true)
	_add_shard(n_1, M_CRYSTAL, Vector3(-0.56, 0.24, -1.16), Vector3(-30.0, 8.0, 12.0), 0.23, 1.84, 5, 0.30, 209, false, false, true)

	# 外圈 10 根中小型斜刺晶柱（放射簇生）
	var mid_shards := [
		[Vector3(-1.68, 0.16, -0.26), Vector3(12.0, 86.0, 38.0), 0.18, 1.38, 6, 0.34, 301],
		[Vector3(-1.58, 0.14, 0.74), Vector3(36.0, 44.0, 24.0), 0.17, 1.26, 5, 0.56, 302],
		[Vector3(-0.88, 0.16, 0.82), Vector3(42.0, 14.0, 12.0), 0.16, 1.18, 6, 0.78, 303],
		[Vector3(0.76, 0.16, -0.44), Vector3(-24.0, -68.0, -34.0), 0.18, 1.34, 6, 0.42, 304],
		[Vector3(0.08, 0.18, -1.32), Vector3(-38.0, -24.0, -14.0), 0.17, 1.28, 5, 0.66, 305],
		[Vector3(-1.08, 0.16, -1.34), Vector3(-34.0, 42.0, 26.0), 0.16, 1.22, 6, 0.24, 306],
		[Vector3(-0.02, 0.22, -0.12), Vector3(18.0, -45.0, -18.0), 0.15, 1.48, 6, 0.92, 307],
		[Vector3(-0.98, 0.24, -0.48), Vector3(-16.0, 74.0, 24.0), 0.15, 1.42, 5, 0.72, 308],
		[Vector3(0.62, 0.14, 0.54), Vector3(34.0, -52.0, -24.0), 0.15, 1.08, 6, 0.52, 309],
		[Vector3(-1.46, 0.15, -1.04), Vector3(-28.0, 122.0, 32.0), 0.14, 1.04, 5, 0.28, 310],
	]
	for ms in mid_shards:
		_add_shard(n_1, M_CRYSTAL, ms[0], ms[1], float(ms[2]), float(ms[3]), int(ms[4]), float(ms[5]), int(ms[6]), false, false, true)

	# 边缘 8 根细锐晶针集群（全部深插岩缝，紧贴岩盘边缘爆发，强化俯视近景矿脉层次）
	var micro_shards := [
		[Vector3(-1.58, 0.14, 0.24), Vector3(24.0, 78.0, 42.0), 0.095, 0.78, 5, 0.64, 401],
		[Vector3(-1.02, 0.15, 0.88), Vector3(44.0, 26.0, 16.0), 0.090, 0.72, 6, 0.80, 402],
		[Vector3(0.76, 0.14, 0.22), Vector3(26.0, -82.0, -40.0), 0.095, 0.76, 5, 0.72, 403],
		[Vector3(0.48, 0.15, -1.04), Vector3(-40.0, -46.0, -22.0), 0.092, 0.74, 6, 0.44, 404],
		[Vector3(-0.44, 0.16, -1.46), Vector3(-44.0, 12.0, 14.0), 0.088, 0.70, 5, 0.56, 405],
		[Vector3(-1.58, 0.14, -0.58), Vector3(-30.0, 96.0, 38.0), 0.085, 0.66, 6, 0.34, 406],
		[Vector3(0.18, 0.16, 0.74), Vector3(42.0, -26.0, -16.0), 0.082, 0.64, 5, 0.86, 407],
		[Vector3(-0.36, 0.18, 0.74), Vector3(38.0, 6.0, 20.0), 0.095, 0.76, 6, 0.68, 408],
	]
	for ns in micro_shards:
		_add_shard(n_1, M_CRYSTAL, ns[0], ns[1], float(ns[2]), float(ns[3]), int(ns[4]), float(ns[5]), int(ns[6]), false, false, false)

	# 被激光/冲击崩断的残留断桩 + 滚落地面的折断晶柱与碎晶碴（紧贴碎岩落地）
	_add_shard(n_1, M_CRYSTAL, Vector3(0.24, 0.20, 0.56), Vector3(26.0, -24.0, -18.0), 0.21, 0.66, 6, 0.94, 501, true, false, true)
	_add_shard(n_1, M_CRYSTAL, Vector3(-0.78, 0.12, 1.92), Vector3(84.0, 36.0, -10.0), 0.21, 1.38, 6, 0.90, 502, true, false, true)
	_add_shard(n_1, M_CRYSTAL, Vector3(-0.22, 0.08, 2.24), Vector3(88.0, -52.0, 14.0), 0.12, 0.68, 5, 0.78, 503, true, false, false)
	_add_shard(n_1, M_CRYSTAL, Vector3(-1.12, 0.07, 1.56), Vector3(86.0, 118.0, -6.0), 0.10, 0.52, 6, 0.64, 504, false, false, false)
	A.add(n_1, A.rock_mesh(3, 28), M_ROCK_DARK, Vector3(-1.38, 0.10, 1.18), Vector3(8.0, 42.0, -10.0), Vector3(0.68, 0.28, 0.56), true)
	A.add(n_1, A.rock_mesh(8, 28), M_ROCK_MAIN, Vector3(-0.98, 0.08, 1.72), Vector3(-6.0, -28.0, 8.0), Vector3(0.58, 0.22, 0.48), true)

	# 激光射偏灼烧点（高温焦痕环 + 亮热熔核）
	A.add(n_1, A.cyl(0.24, 0.03, 0.16, 20), M_CHAR, Vector3(0.36, 0.44, 0.58), Vector3(24.0, -24.0, -16.0), Vector3.ONE, false)
	A.add(n_1, A.sphere(0.085, -1.0, 20), M_LASER, Vector3(0.38, 0.47, 0.59), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_1, A.torus(0.095, 0.145, 20), M_SCORCH, Vector3(0.38, 0.45, 0.59), Vector3(24.0, -24.0, -16.0), Vector3.ONE, false)

	# =========================================================================
	# 2. 受损激光光谱仪三脚架（后腿弯折导致光束偏射灼烧晶桩与玄武岩）
	# =========================================================================
	var n_2 := K.node(root, Vector3.ZERO, Vector3.ZERO, "LaserSpectrometerTripod")
	# 中心云台基座 + 防护环
	K.cy(n_2, 0.24, 0.16, M_DARK, Vector3(2.12, 2.04, 1.58), Vector3(12.0, 0.0, -14.0), 0.24, 24)
	A.add(n_2, A.torus(0.21, 0.26, 24), M_GUNMETAL, Vector3(2.12, 2.11, 1.58), Vector3(12.0, 0.0, -14.0), Vector3.ONE, false)
	# 便携蓄电池箱 + 警示盖 + 状态灯
	K.bb(n_2, Vector3(0.50, 0.30, 0.48), M_DARK, Vector3(2.26, 0.15, 1.78), Vector3(0.0, -14.0, 0.0), 0.014)
	A.add(n_2, A.bevel_box(Vector3(0.38, 0.05, 0.36), 0.006), M_HAZARD, Vector3(2.26, 0.32, 1.78), Vector3(0.0, -14.0, 0.0), Vector3.ONE, false)
	A.add(n_2, A.sphere(0.032, -1.0, 14), M_AMBERGLOW, Vector3(2.44, 0.28, 1.94), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_2, A.tube([Vector3(2.33, 0.30, 1.84), Vector3(2.28, 1.15, 1.78), Vector3(2.24, 1.98, 1.66), Vector3(2.34, 2.38, 1.76)], 0.024, 14, 10), M_DARK, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	# 三条工业伸缩支架腿（含锁紧箍 + 抓地圆盘 + 折弯受损后腿）
	A.add(n_2, A.tube([Vector3(2.12, 2.04, 1.58), Vector3(3.18, 0.08, 2.38)], 0.044, 16, 8), M_HAZARD, Vector3.ZERO, Vector3.ZERO)
	K.cy(n_2, 0.068, 0.12, M_GUNMETAL, Vector3(2.65, 1.06, 1.98), Vector3(28.0, -36.0, -16.0), 0.068, 16)
	K.cy(n_2, 0.16, 0.08, M_GUNMETAL, Vector3(3.18, 0.04, 2.38), Vector3.ZERO, 0.18, 24)
	A.add(n_2, A.tube([Vector3(2.69, 0.98, 2.02), Vector3(2.14, 0.90, 1.60)], 0.022, 14, 8), M_CHROME, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)

	A.add(n_2, A.tube([Vector3(2.12, 2.04, 1.58), Vector3(1.42, 0.08, 2.62)], 0.044, 16, 8), M_HAZARD, Vector3.ZERO, Vector3.ZERO)
	K.cy(n_2, 0.068, 0.12, M_GUNMETAL, Vector3(1.77, 1.06, 2.10), Vector3(-24.0, 26.0, 18.0), 0.068, 16)
	K.cy(n_2, 0.16, 0.08, M_GUNMETAL, Vector3(1.42, 0.04, 2.62), Vector3.ZERO, 0.18, 24)
	A.add(n_2, A.tube([Vector3(1.75, 0.98, 2.14), Vector3(2.14, 0.90, 1.60)], 0.022, 14, 8), M_CHROME, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)

	A.add(n_2, A.tube([Vector3(2.12, 2.04, 1.58), Vector3(2.44, 1.22, 1.15), Vector3(2.52, 0.08, 0.78)], 0.044, 16, 8), M_CHAR, Vector3.ZERO, Vector3.ZERO)
	K.cy(n_2, 0.16, 0.08, M_GUNMETAL, Vector3(2.52, 0.04, 0.78), Vector3.ZERO, 0.18, 24)
	K.cy(n_2, 0.06, 1.18, M_GUNMETAL, Vector3(2.16, 1.48, 1.62), Vector3(8.0, 0.0, -10.0), 0.06, 16)

	# 光学光谱仪机头（装甲外框 + 散热肋 + 俯仰舵机 + 顶部全向雷达穹顶）
	K.bb(n_2, Vector3(0.54, 0.40, 0.62), M_BODY, Vector3(2.12, 2.40, 1.58), Vector3(22.0, -52.0, -14.0), 0.016)
	K.bb(n_2, Vector3(0.58, 0.12, 0.42), M_GUNMETAL, Vector3(2.12, 2.24, 1.58), Vector3(22.0, -52.0, -14.0), 0.010)
	K.bb(n_2, Vector3(0.24, 0.26, 0.26), M_CHAR, Vector3(2.38, 2.44, 1.78), Vector3(22.0, -52.0, -14.0), 0.008)
	K.cy(n_2, 0.15, 0.18, M_STEEL, Vector3(2.06, 2.70, 1.54), Vector3(16.0, 0.0, -14.0), 0.15, 24)
	A.add(n_2, A.sphere(0.165, 0.145, 32), M_CHROME, Vector3(2.04, 2.82, 1.52), Vector3(16.0, 0.0, -14.0))
	A.add(n_2, A.torus(0.14, 0.18, 24), M_DARK, Vector3(2.05, 2.76, 1.53), Vector3(16.0, 0.0, -14.0), Vector3.ONE, false)

	# 偏折激光束（极细高能核心）
	A.add(n_2, A.tube([Vector3(1.84, 2.34, 1.36), Vector3(0.38, 0.47, 0.59)], 0.013, 14, 8), M_LASER, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	var n_3 := K.node(n_2, Vector3(1.84, 2.34, 1.36), Vector3(122.0, -52.0, -14.0), "LidarEmitter")
	K.cy(n_3, 0.16, 0.12, M_DARK, Vector3.ZERO, Vector3.ZERO, 0.175, 24)
	A.add(n_3, A.torus(0.105, 0.155, 24), M_GUNMETAL, Vector3(0.0, 0.052, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_3, A.cyl(0.115, 0.025, 0.115, 24), M_BORE, Vector3(0.0, 0.040, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_3, A.sphere(0.095, 0.065, 20), M_LASER, Vector3(0.0, 0.042, 0.0), Vector3.ZERO, Vector3.ONE, false)

	# =========================================================================
	# 3. 岩芯低温采样罐与护笼遥测控制台橇座
	# =========================================================================
	var n_4 := K.node(root, Vector3(-2.42, 0.0, 2.32), Vector3(0.0, 28.0, 0.0), "CoreSamplerAndControlSkid")
	# 重工工字钢底橇 + 四角吊耳 + 黄黑警示沿
	K.bb(n_4, Vector3(2.08, 0.13, 1.28), M_DARK, Vector3(0.0, 0.065, 0.0), Vector3.ZERO, 0.012)
	A.add(n_4, A.bevel_box(Vector3(2.02, 0.035, 0.10), 0.005), M_HAZARD, Vector3(0.0, 0.125, 0.58), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_4, A.bevel_box(Vector3(2.02, 0.035, 0.10), 0.005), M_HAZARD, Vector3(0.0, 0.125, -0.58), Vector3.ZERO, Vector3.ONE, false)
	# 泄漏冷却液与掉落碎晶
	_add_shard(n_4, M_CRYSTAL, Vector3(-0.46, 0.105, 0.42), Vector3(88.0, 22.0, 12.0), 0.13, 0.34, 5, 0.86, 601, false, false, false)

	# 遥测控制主箱 + 钢管防滚护笼（消除素方块感）
	K.bb(n_4, Vector3(0.86, 1.18, 0.78), M_BODY, Vector3(0.48, 0.72, 0.0), Vector3.ZERO, 0.016)
	K.bb(n_4, Vector3(0.92, 0.10, 0.84), M_STEEL, Vector3(0.48, 1.32, 0.0), Vector3.ZERO, 0.012)
	# 护笼管架
	A.add(n_4, A.tube([Vector3(0.02, 0.13, 0.44), Vector3(0.02, 1.44, 0.44), Vector3(0.96, 1.44, 0.44), Vector3(0.96, 0.13, 0.44)], 0.028, 14, 8), M_GUNMETAL, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_4, A.tube([Vector3(0.02, 0.13, -0.44), Vector3(0.02, 1.44, -0.44), Vector3(0.96, 1.44, -0.44), Vector3(0.96, 0.13, -0.44)], 0.028, 14, 8), M_GUNMETAL, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_4, A.tube([Vector3(0.02, 1.44, -0.44), Vector3(0.02, 1.44, 0.44)], 0.026, 14, 8), M_GUNMETAL, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_4, A.tube([Vector3(0.96, 1.44, -0.44), Vector3(0.96, 1.44, 0.44)], 0.026, 14, 8), M_GUNMETAL, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	# 内凹倾角光谱屏幕 + 指示灯
	A.add(n_4, A.bevel_box(Vector3(0.72, 0.48, 0.08), 0.006), M_CHAR, Vector3(0.48, 1.04, 0.39), Vector3(-24.0, 0.0, 0.0), Vector3.ONE, false)
	A.add(n_4, A.bevel_box(Vector3(0.42, 0.22, 0.03), 0.003), M_SCREEN, Vector3(0.38, 1.04, 0.42), Vector3(-24.0, 0.0, 0.0), Vector3.ONE, false)
	A.add(n_4, A.sphere(0.026, -1.0, 14), M_AMBERGLOW, Vector3(0.72, 1.12, 0.42), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_4, A.sphere(0.026, -1.0, 14), M_SCREEN, Vector3(0.72, 1.02, 0.44), Vector3.ZERO, Vector3.ONE, false)
	# 折弯遥测天线与馈源球
	K.cy(n_4, 0.024, 0.98, M_CHROME, Vector3(0.88, 1.68, -0.26), Vector3(12.0, 0.0, -34.0), 0.024, 16)
	A.add(n_4, A.sphere(0.065, -1.0, 20), M_DARK, Vector3(1.16, 2.08, -0.15), Vector3.ZERO, Vector3.ONE, false)
	A.stencil(n_4, "SURVEY-06", Vector3(0.48, 0.46, 0.41), Vector3.ZERO, 0.0065, Color("#1b1f24"))

	# 受损歪斜低温晶芯采样罐（装甲观察窗内可见真实发光微缩晶柱样本）
	var n_5 := K.node(n_4, Vector3(-0.48, 0.13, 0.0), Vector3(7.0, 0.0, -11.0), "DamagedCoreCanister")
	K.cy(n_5, 0.38, 0.34, M_STEEL, Vector3(0.0, 0.18, 0.0), Vector3.ZERO, 0.40, 36)
	K.cy(n_5, 0.38, 0.36, M_STEEL, Vector3(0.0, 1.24, 0.0), Vector3.ZERO, 0.38, 36)
	# 中段 4 根装甲防撞肋 + 内部悬置发光晶芯标本
	for k in 4:
		var ka := float(k) * PI * 0.5 + PI * 0.25
		K.bb(n_5, Vector3(0.11, 0.78, 0.11), M_GUNMETAL, Vector3(cos(ka) * 0.33, 0.72, sin(ka) * 0.33), Vector3(0.0, rad_to_deg(-ka), 0.0), 0.008)
	_add_shard(n_5, M_CRYSTAL, Vector3(0.0, 0.34, 0.0), Vector3(4.0, 24.0, -3.0), 0.21, 0.76, 6, 0.96, 602, false, false, false)
	A.add(n_5, A.torus(0.35, 0.45, 24), M_GUNMETAL, Vector3(0.0, 0.10, 0.0), Vector3.ZERO)
	A.add(n_5, A.torus(0.35, 0.45, 24), M_GUNMETAL, Vector3(0.0, 1.38, 0.0), Vector3.ZERO)
	K.cy(n_5, 0.11, 0.22, M_BRASS, Vector3(0.0, 1.54, 0.0), Vector3.ZERO, 0.11, 24)
	A.add(n_5, A.torus(0.11, 0.165, 24), M_HAZARD, Vector3(0.0, 1.66, 0.0), Vector3.ZERO)
	K.bb(n_5, Vector3(0.18, 0.14, 0.24), M_GUNMETAL, Vector3(0.0, 1.16, -0.36), Vector3.ZERO, 0.006)
	K.bb(n_5, Vector3(0.18, 0.14, 0.24), M_GUNMETAL, Vector3(0.0, 0.28, -0.36), Vector3.ZERO, 0.006)
	var n_6 := K.node(n_5, Vector3(0.0, 1.44, 0.0), Vector3.ZERO, "CanisterTopBolts")
	for bi in 8:
		var ba := TAU * float(bi) / 8.0
		A.add(n_6, A.cyl(0.016, 0.026, 0.018, 6), M_CHROME, Vector3(cos(ba) * 0.34, 0.0, sin(ba) * 0.34), Vector3.ZERO, Vector3.ONE, false)
	var n_7 := K.node(n_5, Vector3(0.0, 0.72, -0.44), Vector3(90.0, 0.0, 0.0), "CanisterLockClamp")
	K.cy(n_7, 0.062, 0.46, M_GUNMETAL, Vector3(0.0, 0.0, 0.17), Vector3(90.0, 0.0, 0.0), 0.062, 16)
	K.cy(n_7, 0.072, 0.045, M_BRASS, Vector3(0.0, 0.0, -0.07), Vector3(90.0, 0.0, 0.0), 0.072, 16)
	K.cy(n_7, 0.035, 0.79, M_CHROME, Vector3(0.0, 0.0, -0.017), Vector3(90.0, 0.0, 0.0), 0.035, 16)
	K.bb(n_7, Vector3(0.10, 0.084, 0.09), M_DARK, Vector3(0.0, 0.0, -0.41), Vector3.ZERO, 0.006)
	K.bb(n_7, Vector3(0.10, 0.084, 0.09), M_DARK, Vector3(0.0, 0.0, 0.41), Vector3.ZERO, 0.006)
	var n_8 := K.node(n_4, Vector3(0.91, 0.70, 0.0), Vector3(0.0, 90.0, 0.0), "ConsoleCooling")
	K.bb(n_8, Vector3(0.56, 0.54, 0.038), M_DARK, Vector3(0.0, 0.0, -0.006), Vector3.ZERO, 0.006)
	A.add(n_8, A.bevel_box(Vector3(0.50, 0.46, 0.024), 0.004), M_BORE, Vector3(0.0, 0.0, -0.024), Vector3.ZERO, Vector3.ONE, false)
	for ly in [-0.15, -0.05, 0.05, 0.15]:
		A.add(n_8, A.bevel_box(Vector3(0.47, 0.035, 0.032), 0.004), M_GUNMETAL, Vector3(0.0, ly, -0.036), Vector3(-28.0, 0.0, 0.0), Vector3.ONE, false)

	# =========================================================================
	# 4. 地面重型电缆与 3 座地震波检波器（1 座倾倒）
	# =========================================================================
	var n_9 := K.node(root, Vector3.ZERO, Vector3.ZERO, "CablesAndSeismicProbes")
	A.add(n_9, A.tube([Vector3(-1.54, 0.14, 2.26), Vector3(0.22, 0.04, 2.66), Vector3(1.42, 0.05, 2.24), Vector3(2.04, 0.14, 1.76)], 0.034, 14, 10), M_DARK, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_9, A.tube([Vector3(-2.48, 0.14, 1.66), Vector3(-2.36, 0.05, 0.56), Vector3(-2.06, 0.05, -0.68), Vector3(-1.95, 0.12, -0.95)], 0.024, 14, 10), M_HAZARD, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_9, A.tube([Vector3(-1.68, 0.12, 2.10), Vector3(-0.62, 0.04, 2.48), Vector3(0.54, 0.05, 2.30)], 0.020, 14, 8), M_GUNMETAL, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	# 检波器 1（西侧完好，带法兰与青色指示灯）
	K.cy(n_9, 0.16, 0.08, M_DARK, Vector3(-1.95, 0.04, -0.95), Vector3.ZERO, 0.19, 20)
	K.cy(n_9, 0.095, 0.50, M_STEEL, Vector3(-1.95, 0.28, -0.95), Vector3.ZERO, 0.095, 24)
	A.add(n_9, A.torus(0.085, 0.125, 20), M_HAZARD, Vector3(-1.95, 0.44, -0.95), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_9, A.sphere(0.06, -1.0, 20), M_SCREEN, Vector3(-1.95, 0.56, -0.95), Vector3.ZERO, Vector3.ONE, false)
	# 检波器 2（北东侧完好，琥珀警示灯）
	K.cy(n_9, 0.16, 0.08, M_DARK, Vector3(1.05, 0.04, -1.95), Vector3.ZERO, 0.19, 20)
	K.cy(n_9, 0.095, 0.50, M_STEEL, Vector3(1.05, 0.28, -1.95), Vector3.ZERO, 0.095, 24)
	A.add(n_9, A.torus(0.085, 0.125, 20), M_HAZARD, Vector3(1.05, 0.44, -1.95), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_9, A.sphere(0.06, -1.0, 20), M_AMBERGLOW, Vector3(1.05, 0.56, -1.95), Vector3.ZERO, Vector3.ONE, false)
	# 检波器 3（南侧倾倒损毁）
	K.cy(n_9, 0.095, 0.50, M_CHAR, Vector3(0.68, 0.10, 2.28), Vector3(0.0, 32.0, 86.0), 0.095, 24)
	A.add(n_9, A.sphere(0.06, -1.0, 20), M_DARK, Vector3(0.40, 0.11, 2.45), Vector3.ZERO, Vector3.ONE, false)

	return root
