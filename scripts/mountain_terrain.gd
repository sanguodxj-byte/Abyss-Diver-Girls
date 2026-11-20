extends RefCounted
## 写实扫描级连续山体地形生成器 V3：
## 1) 采用精确向内 Chamfer 距离场（绝不外扩侵入道路/建筑/索桥/水体，绝不产生垂直一刀切）；
## 2) 融合脊状多重分形主脉 + 细胞 Voronoi 岩脊 + 水力侵蚀冲沟 + 沉积岩台地；
## 3) 绑定 1024x1024 扫描级无缝 PBR 贴图（mtn_cliff / mtn_obsidian / mtn_scree 的 Albedo + 多尺度 Normal + Roughness/AO/Glass）；
## 4) 在陡崖面与深渊井壁无缝嵌合共享世界空间三平面材质的 3D 棱角岩壁扶壁 / 六棱柱状黑曜岩丛（单 MultiMesh Draw Call），打破纯高度场单薄感。

const A = preload("res://scripts/art.gd")
const WC = preload("res://scripts/world_city.gd")
const WorldLinkScript = preload("res://scripts/world_link.gd")

static var _mtn_shader: Shader
static var _obs_shader: Shader
static var _obs_col_mesh: ArrayMesh
static var _cliff_slab_mesh: ArrayMesh


static func _push_tri(verts: PackedVector3Array, nrms: PackedVector3Array, cols: PackedColorArray, uvs: PackedVector2Array, a: Vector3, b: Vector3, c: Vector3, nrm: Vector3, col: Color) -> void:
	# Godot 4 正面为顺时针绕序：使 (c - a) x (b - a) 与外法线同向，100% 杜绝反面翻转
	var bb := b
	var cc := c
	if (cc - a).cross(bb - a).dot(nrm) < 0.0:
		bb = c
		cc = b
	verts.append(a)
	verts.append(bb)
	verts.append(cc)
	nrms.append(nrm)
	nrms.append(nrm)
	nrms.append(nrm)
	cols.append(col)
	cols.append(col)
	cols.append(col)
	uvs.append(Vector2(a.x, a.y))
	uvs.append(Vector2(bb.x, bb.y))
	uvs.append(Vector2(cc.x, cc.y))


## 3D 六棱/五棱柱状玄武黑曜岩丛（冰岛柱状玄武黑曜岩斜切顶面 + 锐利柱棱，共享世界空间黑曜岩着色器）
static func _obsidian_column_cluster_mesh() -> ArrayMesh:
	if _obs_col_mesh != null:
		return _obs_col_mesh
	var verts := PackedVector3Array()
	var nrms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()

	# 4 根错落融合的斜切棱柱（[偏移x, 偏移z, 半径, 高度, 边数, 顶面斜切倾角x, 倾角z, 偏转角]）
	var specs := [
		[0.0, 0.0, 1.05, 4.6, 6, 0.42, -0.22, 0.2],
		[1.15, 0.42, 0.88, 3.5, 6, -0.36, 0.30, 0.85],
		[-0.95, 0.62, 0.82, 3.9, 5, 0.28, 0.44, 1.4],
		[0.18, -1.05, 0.78, 2.8, 6, -0.45, -0.28, 2.1],
	]
	var col_side := Color(0.84, 0.45, 0.05, 0.6)
	var col_top := Color(0.95, 0.72, 0.02, 0.8)
	for sp: Array in specs:
		var ox: float = sp[0]
		var oz: float = sp[1]
		var rad: float = sp[2]
		var h: float = sp[3]
		var sides: int = int(sp[4])
		var tx: float = sp[5]
		var tz: float = sp[6]
		var rot0: float = sp[7]
		var bot: Array[Vector3] = []
		var top: Array[Vector3] = []
		var top_c := Vector3(ox, h, oz)
		for k in sides:
			var a := rot0 + TAU * float(k) / float(sides)
			var r_k := rad * (0.90 + 0.18 * sin(float(k) * 2.3 + rot0))
			var px := ox + cos(a) * r_k
			var pz := oz + sin(a) * r_k
			var py_top := h + (px - ox) * tx + (pz - oz) * tz
			bot.append(Vector3(px, -0.9, pz))
			top.append(Vector3(px, py_top, pz))
		# 棱柱侧面（硬边平面法线，呈现真实柱状玄武黑曜岩刀削棱角）
		for k in sides:
			var kn := (k + 1) % sides
			var p0: Vector3 = bot[k]
			var p1: Vector3 = bot[kn]
			var p2: Vector3 = top[kn]
			var p3: Vector3 = top[k]
			var mid_out := Vector3((p0.x + p1.x) * 0.5 - ox, 0.0, (p0.z + p1.z) * 0.5 - oz).normalized()
			_push_tri(verts, nrms, cols, uvs, p0, p1, p2, mid_out, col_side)
			_push_tri(verts, nrms, cols, uvs, p0, p2, p3, mid_out, col_side)
		# 斜切顶面（微凹或锋利斜断面）
		var top_n := Vector3(-tx, 1.0, -tz).normalized()
		for k in sides:
			var kn := (k + 1) % sides
			_push_tri(verts, nrms, cols, uvs, top_c, top[k], top[kn], top_n, col_top)

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	_obs_col_mesh = ArrayMesh.new()
	_obs_col_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return _obs_col_mesh


## 3D 层裂崖壁岩肋扶壁（两级阶梯棱角岩石露头，嵌入陡峭崖壁共享世界空间三平面岩壁着色器）
static func _cliff_buttress_mesh() -> ArrayMesh:
	if _cliff_slab_mesh != null:
		return _cliff_slab_mesh
	var verts := PackedVector3Array()
	var nrms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()

	var tiers := [
		[0.0, 0.0, 2.2, 1.5, 2.1, -0.7, 0.14, -0.08, 0.0],
		[0.35, -0.25, 1.55, 1.15, 3.2, 1.1, -0.18, 0.12, 0.5],
	]
	var col_side := Color(0.82, 0.35, 0.12, 0.5)
	var col_top := Color(0.92, 0.55, 0.18, 0.7)
	for t: Array in tiers:
		var ox: float = t[0]
		var oz: float = t[1]
		var rx: float = t[2]
		var rz: float = t[3]
		var y1: float = t[4]
		var y0: float = t[5]
		var tx: float = t[6]
		var tz: float = t[7]
		var rot0: float = t[8]
		var sides := 7
		var bot: Array[Vector3] = []
		var top: Array[Vector3] = []
		var top_c := Vector3(ox, y1 + 0.15, oz)
		for k in sides:
			var a := rot0 + TAU * float(k) / float(sides)
			var jr := 0.84 + 0.28 * sin(float(k) * 3.1 + rot0 * 2.0)
			var bx := ox + cos(a) * rx * jr * 1.15
			var bz := oz + sin(a) * rz * jr * 1.15
			var ux := ox + cos(a) * rx * jr * 0.88
			var uz := oz + sin(a) * rz * jr * 0.88
			var uy := y1 + (ux - ox) * tx + (uz - oz) * tz
			bot.append(Vector3(bx, y0, bz))
			top.append(Vector3(ux, uy, uz))
		for k in sides:
			var kn := (k + 1) % sides
			var p0: Vector3 = bot[k]
			var p1: Vector3 = bot[kn]
			var p2: Vector3 = top[kn]
			var p3: Vector3 = top[k]
			var fn := (p2 - p0).cross(p1 - p0)
			var out_ref := Vector3((p0.x + p1.x) * 0.5 - ox, 0.15, (p0.z + p1.z) * 0.5 - oz)
			if fn.dot(out_ref) < 0.0:
				fn = -fn
			fn = fn.normalized() if fn.length_squared() > 1e-6 else out_ref.normalized()
			_push_tri(verts, nrms, cols, uvs, p0, p1, p2, fn, col_side)
			_push_tri(verts, nrms, cols, uvs, p0, p2, p3, fn, col_side)
		var top_n := Vector3(-tx, 1.0, -tz).normalized()
		for k in sides:
			var kn := (k + 1) % sides
			_push_tri(verts, nrms, cols, uvs, top_c, top[k], top[kn], top_n, col_top)

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	_cliff_slab_mesh = ArrayMesh.new()
	_cliff_slab_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return _cliff_slab_mesh


static func _profile(map_id: String, is_surface: bool) -> Dictionary:
	if not is_surface:
		return {
			"max_h": 35.0, "ridge_h": 11.5, "outer_boost": 1.48, "strata_str": 0.0, "strata_h": 5.0,
			"crag_w": 0.46, "normal_str": 0.88,
			"rock_tint": Color(1.02, 1.04, 1.14), "strata_tint": Color(0.92, 0.94, 1.04),
			"scree_tint": Color(0.28, 0.25, 0.34), "moss_col": Color(0.24, 0.14, 0.34),
			"foot_col": Color(0.145, 0.128, 0.190), "moss_amt": 0.0,
			"strata_freq": 0.0, "dip_vec": Vector2(0.032, -0.024),
			"add_veg": false, "veg_density": 0.0, "boulder_col": Color(0.10, 0.10, 0.13),
		}
	match map_id:
		"canyon":
			return {
				"max_h": 24.0, "ridge_h": 9.2, "outer_boost": 1.32, "strata_str": 0.62, "strata_h": 4.2,
				"crag_w": 0.34, "normal_str": 1.08,
				"rock_tint": Color(1.06, 0.90, 0.74), "strata_tint": Color(0.84, 0.70, 0.58),
				"scree_tint": Color(0.92, 0.80, 0.66), "moss_col": Color(0.27, 0.30, 0.18),
				"foot_col": Color(0.37, 0.32, 0.24), "moss_amt": 0.14,
				"strata_freq": 0.52, "dip_vec": Vector2(0.036, 0.022),
				"add_veg": true, "veg_density": 0.026, "boulder_col": Color(0.35, 0.30, 0.24),
			}
		"dustfield":
			return {
				"max_h": 21.5, "ridge_h": 8.4, "outer_boost": 1.28, "strata_str": 0.66, "strata_h": 3.8,
				"crag_w": 0.32, "normal_str": 1.06,
				"rock_tint": Color(1.18, 1.00, 0.78), "strata_tint": Color(0.95, 0.78, 0.60),
				"scree_tint": Color(1.04, 0.88, 0.68), "moss_col": Color(0.33, 0.32, 0.19),
				"foot_col": Color(0.43, 0.37, 0.27), "moss_amt": 0.08,
				"strata_freq": 0.58, "dip_vec": Vector2(0.040, -0.018),
				"add_veg": true, "veg_density": 0.020, "boulder_col": Color(0.44, 0.36, 0.26),
			}
		_:
			return {
				"max_h": 20.0, "ridge_h": 7.8, "outer_boost": 1.26, "strata_str": 0.30, "strata_h": 4.4,
				"crag_w": 0.38, "normal_str": 1.08,
				"rock_tint": Color(0.84, 0.88, 0.94), "strata_tint": Color(0.70, 0.74, 0.80),
				"scree_tint": Color(0.80, 0.82, 0.82), "moss_col": Color(0.23, 0.30, 0.17),
				"foot_col": Color(0.33, 0.30, 0.24), "moss_amt": 0.32,
				"strata_freq": 0.46, "dip_vec": Vector2(0.028, 0.020),
				"add_veg": true, "veg_density": 0.052, "boulder_col": Color(0.34, 0.32, 0.29),
			}


static func _make_mat(prof: Dictionary, is_surf: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	if not is_surf:
		if _obs_shader == null:
			_obs_shader = load("res://shaders/obsidian_terrain.gdshader")
		m.shader = _obs_shader
		m.set_shader_parameter("obs_a", A.world_tex("mtn_obsidian_a.png"))
		m.set_shader_parameter("obs_n", A.world_tex("mtn_obsidian_n.png"))
		m.set_shader_parameter("obs_r", A.world_tex("mtn_obsidian_r.png"))
		m.set_shader_parameter("scree_a", A.world_tex("mtn_scree_a.png"))
		m.set_shader_parameter("scree_n", A.world_tex("mtn_scree_n.png"))
		m.set_shader_parameter("n_low", A.noise_tex("grime_raw", 512))
		m.set_shader_parameter("rock_tint", prof["rock_tint"])
		m.set_shader_parameter("foot_col", prof["foot_col"])
		m.set_shader_parameter("normal_str", float(prof["normal_str"]))
		m.set_meta("no_outline", true)
		return m
	if _mtn_shader == null:
		_mtn_shader = load("res://shaders/mountain_terrain.gdshader")
	m.shader = _mtn_shader
	m.set_shader_parameter("cliff_a", A.world_tex("mtn_cliff_a.png"))
	m.set_shader_parameter("cliff_n", A.world_tex("mtn_cliff_n.png"))
	m.set_shader_parameter("cliff_r", A.world_tex("mtn_cliff_r.png"))
	m.set_shader_parameter("scree_a", A.world_tex("mtn_scree_a.png"))
	m.set_shader_parameter("scree_n", A.world_tex("mtn_scree_n.png"))
	m.set_shader_parameter("scree_r", A.world_tex("mtn_scree_r.png"))
	m.set_shader_parameter("n_low", A.noise_tex("grime_raw", 512))
	m.set_shader_parameter("rock_tint", prof["rock_tint"])
	m.set_shader_parameter("strata_tint", prof["strata_tint"])
	m.set_shader_parameter("scree_tint", prof["scree_tint"])
	m.set_shader_parameter("moss_col", prof["moss_col"])
	m.set_shader_parameter("foot_col", prof["foot_col"])
	m.set_shader_parameter("moss_amt", float(prof["moss_amt"]))
	m.set_shader_parameter("strata_freq", float(prof["strata_freq"]))
	m.set_shader_parameter("dip_vec", prof["dip_vec"])
	m.set_shader_parameter("normal_str", float(prof["normal_str"]))
	m.set_meta("no_outline", true)
	return m


static func _raster_disc(grid: PackedByteArray, n: int, min_c: float, cell: float, cx: float, cz: float, rad: float) -> void:
	var r2 := rad * rad
	var ix0 := maxi(0, floori((cx - rad - min_c) / cell))
	var ix1 := mini(n - 1, ceili((cx + rad - min_c) / cell))
	var iz0 := maxi(0, floori((cz - rad - min_c) / cell))
	var iz1 := mini(n - 1, ceili((cz + rad - min_c) / cell))
	for iz in range(iz0, iz1 + 1):
		var dz := (min_c + iz * cell) - cz
		var dz2 := dz * dz
		var row := iz * n
		for ix in range(ix0, ix1 + 1):
			var dx := (min_c + ix * cell) - cx
			if dx * dx + dz2 <= r2:
				grid[row + ix] = 1


static func _raster_rect(grid: PackedByteArray, n: int, min_c: float, cell: float, rect: Rect2, pad: float) -> void:
	var ix0 := maxi(0, floori((rect.position.x - pad - min_c) / cell))
	var ix1 := mini(n - 1, ceili((rect.end.x + pad - min_c) / cell))
	var iz0 := maxi(0, floori((rect.position.y - pad - min_c) / cell))
	var iz1 := mini(n - 1, ceili((rect.end.y + pad - min_c) / cell))
	for iz in range(iz0, iz1 + 1):
		var row := iz * n
		for ix in range(ix0, ix1 + 1):
			grid[row + ix] = 1


static func _raster_capsule_b(grid: PackedByteArray, n: int, min_c: float, cell: float, a: Vector2, b: Vector2, rad: float) -> void:
	var ab := b - a
	var ab2 := maxf(ab.length_squared(), 1e-4)
	var r2 := rad * rad
	var ix0 := maxi(0, floori((minf(a.x, b.x) - rad - min_c) / cell))
	var ix1 := mini(n - 1, ceili((maxf(a.x, b.x) + rad - min_c) / cell))
	var iz0 := maxi(0, floori((minf(a.y, b.y) - rad - min_c) / cell))
	var iz1 := mini(n - 1, ceili((maxf(a.y, b.y) + rad - min_c) / cell))
	for iz in range(iz0, iz1 + 1):
		var wz := min_c + iz * cell
		var row := iz * n
		for ix in range(ix0, ix1 + 1):
			var wx := min_c + ix * cell
			var t := clampf((Vector2(wx, wz) - a).dot(ab) / ab2, 0.0, 1.0)
			var p := a + ab * t
			var dx := wx - p.x
			var dz := wz - p.y
			if dx * dx + dz * dz <= r2:
				grid[row + ix] = 1


static func _raster_capsule_f(grid: PackedFloat32Array, n: int, min_c: float, cell: float, a: Vector2, b: Vector2, rad: float) -> void:
	var ab := b - a
	var ab2 := maxf(ab.length_squared(), 1e-4)
	var ix0 := maxi(0, floori((minf(a.x, b.x) - rad - min_c) / cell))
	var ix1 := mini(n - 1, ceili((maxf(a.x, b.x) + rad - min_c) / cell))
	var iz0 := maxi(0, floori((minf(a.y, b.y) - rad - min_c) / cell))
	var iz1 := mini(n - 1, ceili((maxf(a.y, b.y) + rad - min_c) / cell))
	for iz in range(iz0, iz1 + 1):
		var wz := min_c + iz * cell
		var row := iz * n
		for ix in range(ix0, ix1 + 1):
			var wx := min_c + ix * cell
			var t := clampf((Vector2(wx, wz) - a).dot(ab) / ab2, 0.0, 1.0)
			var d := Vector2(wx, wz).distance_to(a + ab * t)
			if d < rad:
				var v := smoothstep(rad, rad * 0.22, d)
				if v > grid[row + ix]:
					grid[row + ix] = v


## 两遍向内 Chamfer 欧氏近似距离场：valid==0 处严格为 0，valid==1 内给出到最近边界的平滑米制距离
static func _chamfer_inward(valid: PackedByteArray, n: int, cell: float, cap_m: float) -> PackedFloat32Array:
	var total := n * n
	var dist := PackedFloat32Array()
	dist.resize(total)
	for i in total:
		dist[i] = cap_m if valid[i] == 1 else 0.0
	for i in n:
		dist[i] = 0.0
		dist[n + i] = 0.0
		dist[(n - 2) * n + i] = 0.0
		dist[(n - 1) * n + i] = 0.0
		dist[i * n] = 0.0
		dist[i * n + 1] = 0.0
		dist[i * n + (n - 2)] = 0.0
		dist[i * n + (n - 1)] = 0.0

	var c1 := cell
	var c2 := cell * 1.4142135
	for iz in range(1, n - 1):
		var row := iz * n
		var prev := row - n
		for ix in range(1, n - 1):
			var idx := row + ix
			var d := dist[idx]
			if d <= 0.0:
				continue
			var d1 := dist[idx - 1] + c1
			if d1 < d:
				d = d1
			var d2 := dist[prev + ix] + c1
			if d2 < d:
				d = d2
			var d3 := dist[prev + ix - 1] + c2
			if d3 < d:
				d = d3
			var d4 := dist[prev + ix + 1] + c2
			if d4 < d:
				d = d4
			dist[idx] = d
	for iz in range(n - 2, 0, -1):
		var row := iz * n
		var nxt := row + n
		for ix in range(n - 2, 0, -1):
			var idx := row + ix
			var d := dist[idx]
			if d <= 0.0:
				continue
			var d1 := dist[idx + 1] + c1
			if d1 < d:
				d = d1
			var d2 := dist[nxt + ix] + c1
			if d2 < d:
				d = d2
			var d3 := dist[nxt + ix + 1] + c2
			if d3 < d:
				d = d3
			var d4 := dist[nxt + ix - 1] + c2
			if d4 < d:
				d = d4
			dist[idx] = d
	return dist


static func _add_shared_mm(parent: Node3D, mesh: Mesh, mat: Material, xforms: Array, cast_shadow: bool) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


static func build(raid) -> void:
	var t0 := Time.get_ticks_usec()
	var is_surf: bool = raid.is_surface_map
	var ext: float = (raid.EXT_HALF + 36.0) if is_surf else 310.0
	var cell: float = 2.0 if is_surf else 2.5
	var n: int = int(floor((ext * 2.0) / cell)) + 1
	var min_c: float = -ext
	var total: int = n * n

	var prof := _profile(str(raid.map_id), is_surf)
	var seed_base: int = raid._map_seed(660)

	# 1. C++ FastNoiseLite 地质雕刻噪声器
	var n_warp := FastNoiseLite.new()
	n_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_warp.seed = seed_base + 11
	n_warp.frequency = 0.014
	n_warp.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_warp.fractal_octaves = 2

	var n_ridge := FastNoiseLite.new()
	n_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_ridge.seed = seed_base + 23
	n_ridge.frequency = 0.0155
	n_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	n_ridge.fractal_octaves = 4
	n_ridge.fractal_lacunarity = 2.15
	n_ridge.fractal_gain = 0.48

	var n_crag := FastNoiseLite.new()
	n_crag.noise_type = FastNoiseLite.TYPE_CELLULAR
	n_crag.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	n_crag.fractal_type = FastNoiseLite.FRACTAL_NONE
	n_crag.seed = seed_base + 37
	n_crag.frequency = 0.032 if is_surf else 0.020

	var n_spur := FastNoiseLite.new()
	n_spur.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_spur.seed = seed_base + 47
	n_spur.frequency = 0.048
	n_spur.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	n_spur.fractal_octaves = 3
	n_spur.fractal_lacunarity = 2.10
	n_spur.fractal_gain = 0.45

	var n_macro := FastNoiseLite.new()
	n_macro.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_macro.seed = seed_base + 71
	n_macro.frequency = 0.0085
	n_macro.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_macro.fractal_octaves = 3

	# 2. 光栅化全量禁入区（道路、建筑/POI/掩体、地标留空、长跨悬崖索桥峡谷走廊、转场口、撤离点）
	var blocked := PackedByteArray()
	blocked.resize(total)
	for cv: Dictionary in raid.curves:
		var pts: PackedVector2Array = cv.d
		var rw := float(cv.w) * 0.5 + 4.4
		for i in range(pts.size() - 1):
			_raster_capsule_b(blocked, n, min_c, cell, pts[i], pts[i + 1], rw)
	for r_rect: Rect2 in raid.blocks:
		_raster_rect(blocked, n, min_c, cell, r_rect, 2.4)
	for kc in raid._keep_clear:
		if kc is Rect2:
			_raster_rect(blocked, n, min_c, cell, kc, 2.4)
		elif kc is Vector3:
			_raster_disc(blocked, n, min_c, cell, kc.x, kc.y, kc.z + 2.4)
	for e_lm in raid.MAP.get("landmarks", []):
		var lt := str(e_lm.get("type", ""))
		if lt == "rope_bridge":
			var ls: Vector2 = WC.landmark_spot(raid.map_id, e_lm)
			var r_rad := deg_to_rad(float(e_lm.get("rot", 0.0)))
			var dir2 := Vector2(-sin(r_rad), -cos(r_rad))
			_raster_capsule_b(blocked, n, min_c, cell, ls - dir2 * 18.0, ls + dir2 * 18.0, 6.8)
	for e_key: String in WorldLinkScript.LINKS.get(raid.map_id, {}):
		var gp: Vector2 = WC.gate_info(raid.map_id, e_key).pos
		_raster_disc(blocked, n, min_c, cell, gp.x, gp.y, 18.0)

	# 3. 精确判定山体有效域 valid_k（绝不外扩侵入非 K 平地）
	var valid_k := PackedByteArray()
	valid_k.resize(total)
	var bd_cache := PackedFloat32Array()
	bd_cache.resize(total)
	var raw_ridge := PackedFloat32Array()
	var has_ridges: bool = not raid.layout.ridges.is_empty()
	if has_ridges:
		raw_ridge.resize(total)
		for line: PackedVector2Array in raid.layout.ridges:
			for i in range(line.size() - 1):
				_raster_capsule_f(raw_ridge, n, min_c, cell, line[i], line[i + 1], 10.5)

	var any_mtn: bool = has_ridges
	for iz in n:
		var wz := min_c + iz * cell
		var row := iz * n
		for ix in n:
			var idx := row + ix
			if blocked[idx] == 1:
				continue
			var wx := min_c + ix * cell
			var wx_w := wx + n_warp.get_noise_2d(wx, wz) * 3.2
			var wz_w := wz + n_warp.get_noise_2d(wx + 217.0, wz - 143.0) * 3.2
			var is_mtn := false
			if is_surf:
				if raid.zone_at(Vector3(wx_w, 0.0, wz_w)) == "K":
					if not raid.in_wet(Vector2(wx, wz), 3.6):
						is_mtn = true
			else:
				var sd: float = raid.border_dist(Vector2(wx_w, wz_w))
				bd_cache[idx] = sd
				if sd < -1.5 or raid.zone_at(Vector3(wx_w, 0.0, wz_w)) == "K":
					is_mtn = true
			if is_mtn:
				valid_k[idx] = 1
				any_mtn = true

	if not any_mtn:
		return

	var dist_in := _chamfer_inward(valid_k, n, cell, 48.0)
	var ridge_dist := PackedFloat32Array()
	if has_ridges:
		var valid_r := PackedByteArray()
		valid_r.resize(total)
		for iz in n:
			var wz := min_c + iz * cell
			var row := iz * n
			for ix in n:
				var idx := row + ix
				if raw_ridge[idx] > 0.01 and blocked[idx] == 0:
					if not is_surf or not raid.in_wet(Vector2(min_c + ix * cell, wz), 3.6):
						valid_r[idx] = 1
		ridge_dist = _chamfer_inward(valid_r, n, cell, 14.0)

	# 4. 雕刻写实地质高程场 H[idx]
	var H := PackedFloat32Array()
	H.resize(total)
	var gully_arr := PackedFloat32Array()
	gully_arr.resize(total)
	var max_h: float = float(prof["max_h"])
	var ridge_h: float = float(prof["ridge_h"])
	var outer_boost: float = float(prof["outer_boost"])
	var strata_str: float = float(prof["strata_str"])
	var strata_h: float = float(prof["strata_h"])
	var crag_w: float = float(prof["crag_w"])
	var dip_v: Vector2 = prof["dip_vec"]
	var half_f: float = float(raid.HALF)

	for iz in n:
		var wz := min_c + iz * cell
		var row := iz * n
		for ix in n:
			var idx := row + ix
			var d := dist_in[idx]
			var mr := raw_ridge[idx] if has_ridges else 0.0
			var dr := ridge_dist[idx] if has_ridges else 0.0
			if d <= 0.05 and (mr <= 0.02 or dr <= 0.05):
				H[idx] = -0.18
				continue

			var wx := min_c + ix * cell
			var w_x := wx + n_warp.get_noise_2d(wx * 1.25, wz * 1.25) * 14.0
			var w_z := wz + n_warp.get_noise_2d(wx * 1.25 + 91.0, wz * 1.25 - 63.0) * 14.0

			var r_main := pow(clampf(n_ridge.get_noise_2d(w_x, w_z) * 0.5 + 0.5, 0.0, 1.0), 1.45 if is_surf else 1.65)
			var crag := clampf(n_crag.get_noise_2d(w_x, w_z) + 1.0, 0.0, 1.0)
			crag = pow(crag, 0.82 if is_surf else 1.05)
			var r_spur := clampf(n_spur.get_noise_2d(w_x, w_z) * 0.5 + 0.5, 0.0, 1.0)
			var gully := pow(clampf(1.0 - r_spur * 1.12, 0.0, 1.0), 1.35)
			gully_arr[idx] = gully
			var mac := clampf(n_macro.get_noise_2d(wx, wz) * 0.5 + 0.5, 0.0, 1.0)

			var e := 0.0
			if d > 0.05:
				var mo := 0.0
				if is_surf:
					var sd_s: float = raid.border_dist(Vector2(wx, wz))
					bd_cache[idx] = sd_s
					if sd_s < -4.0:
						mo = clampf((-sd_s - 4.0) / 36.0, 0.0, 1.0)
				else:
					var sd_u := bd_cache[idx]
					if sd_u < -1.5:
						mo = clampf((-sd_u - 1.5) / 26.0, 0.0, 1.0)

				var foot := smoothstep(0.0, 4.4, d)
				var body := smoothstep(1.4, 12.8, d)
				var core := smoothstep(9.0, 30.0, d)
				var env := pow(foot, 1.18) * (0.34 + 0.44 * body + 0.22 * core)
				var outer_mul := lerpf(1.0, outer_boost, mo)
				var mac_scale := (0.72 + 0.54 * mac) if is_surf else (0.50 + 0.84 * mac)
				var shape := (0.32 + (0.68 - crag_w) * r_main + crag_w * crag) * mac_scale
				e = max_h * env * shape * outer_mul
				e += (r_spur - 0.42) * 3.8 * body * (0.48 + 0.52 * core)
				e -= gully * 2.6 * body * (1.0 - 0.35 * core)
				if strata_str > 0.01 and e > 1.6:
					var dip := wx * dip_v.x + wz * dip_v.y
					var s_coord := (e + dip) / strata_h
					var s_fl := floorf(s_coord)
					var s_fr := s_coord - s_fl
					var terraced := (s_fl + smoothstep(0.0, 0.32, s_fr) * 0.85 + s_fr * 0.15) * strata_h - dip
					var t_amt := strata_str * smoothstep(1.6, 5.2, e) * (1.0 - gully * 0.42)
					e = lerpf(e, terraced, t_amt)

			if mr > 0.02 and dr > 0.05:
				var rf := pow(smoothstep(0.04, 0.72, mr), 1.45) * smoothstep(0.0, 5.5, dr)
				var er := ridge_h * rf * (0.42 + 0.36 * r_main + 0.22 * crag) * (0.48 + 0.72 * mac) * (0.80 + 0.36 * r_spur)
				e = maxf(e, er)

			H[idx] = e if e > 0.05 else -0.18

	# 5. 面积加权真实三角面法线（连续无折痕，由扫描级 PBR 法线图与 3D 岩柱露头提供锐利棱角）
	var norms := PackedVector3Array()
	norms.resize(total)
	for iz in range(n - 1):
		var r0 := iz * n
		var r1 := r0 + n
		var z0 := min_c + float(iz) * cell
		var z1 := z0 + cell
		for ix in range(n - 1):
			var i00 := r0 + ix
			var i10 := i00 + 1
			var i01 := r1 + ix
			var i11 := i01 + 1
			var h00 := H[i00]
			var h10 := H[i10]
			var h01 := H[i01]
			var h11 := H[i11]
			if h00 <= 0.0 and h10 <= 0.0 and h01 <= 0.0 and h11 <= 0.0:
				continue
			var x0 := min_c + float(ix) * cell
			var x1 := x0 + cell
			var p00 := Vector3(x0, h00, z0)
			var p10 := Vector3(x1, h10, z0)
			var p11 := Vector3(x1, h11, z1)
			var p01 := Vector3(x0, h01, z1)
			if absf(h00 - h11) <= absf(h10 - h01):
				var na := (p11 - p00).cross(p10 - p00)
				var nb := (p01 - p00).cross(p11 - p00)
				norms[i00] += na + nb
				norms[i10] += na
				norms[i11] += na + nb
				norms[i01] += nb
			else:
				var na := (p01 - p00).cross(p10 - p00)
				var nb := (p01 - p10).cross(p11 - p10)
				norms[i00] += na
				norms[i10] += na + nb
				norms[i11] += nb
				norms[i01] += na + nb

	var vcols := PackedColorArray()
	vcols.resize(total)
	for iz in n:
		var row := iz * n
		var izm := maxi(iz - 1, 0) * n
		var izp := mini(iz + 1, n - 1) * n
		for ix in n:
			var idx := row + ix
			var h0 := H[idx]
			if h0 <= 0.0:
				norms[idx] = Vector3.UP
				vcols[idx] = Color(0.92, 0.0, 0.45, 0.0)
				continue
			var nv := norms[idx]
			norms[idx] = nv.normalized() if nv.length_squared() > 1e-6 else Vector3.UP
			var ixm := maxi(ix - 1, 0)
			var ixp := mini(ix + 1, n - 1)
			var avg_nbr := (maxf(0.0, H[row + ixm]) + maxf(0.0, H[row + ixp]) + maxf(0.0, H[izm + ix]) + maxf(0.0, H[izp + ix]) + maxf(0.0, H[izm + ixm]) + maxf(0.0, H[izm + ixp]) + maxf(0.0, H[izp + ixm]) + maxf(0.0, H[izp + ixp])) * 0.125
			var curv := (h0 - avg_nbr) / maxf(cell * 0.55, 0.5)
			var gully := gully_arr[idx]
			var ao := clampf(0.90 + curv * 0.34 - gully * 0.22 - (1.0 - smoothstep(0.0, 2.0, h0)) * 0.10, 0.52, 1.0)
			var ridge_exp := clampf(curv * 0.95 + smoothstep(0.50, 0.92, h0 / max_h) * 0.40, 0.0, 1.0)
			var talus := clampf(gully * 0.72 + (1.0 - smoothstep(0.4, 4.4, h0)) * 0.62 + maxf(0.0, -curv) * 0.60, 0.0, 1.0)
			vcols[idx] = Color(ao, ridge_exp, talus, clampf(h0 / max_h, 0.0, 1.0))

	# 6. 构建 32x32 大分块网格 + 共享世界空间 PBR 材质的 3D 棱角岩体露头
	var chunk_cnt := 0
	var outcrop_cnt := 0
	if not Net.is_dedicated_server():
		var mtn_root := Node3D.new()
		mtn_root.name = "MountainTerrain"
		mtn_root.add_to_group("mountain_terrain")
		raid.world.add_child(mtn_root)
		var mat := _make_mat(prof, is_surf)
		var csz := 32
		var nc := ceili(float(n - 1) / float(csz))
		for cz in nc:
			var z0 := cz * csz
			var z1 := mini(z0 + csz, n - 1)
			for cx in nc:
				var x0 := cx * csz
				var x1 := mini(x0 + csz, n - 1)
				var has_geo := false
				for iz in range(z0, z1 + 1):
					var row := iz * n
					for ix in range(x0, x1 + 1):
						if H[row + ix] > 0.05:
							has_geo = true
							break
					if has_geo:
						break
				if not has_geo:
					continue
				var verts := PackedVector3Array()
				var nrms := PackedVector3Array()
				var cols := PackedColorArray()
				var uvs := PackedVector2Array()
				var indices := PackedInt32Array()
				var w_sub := x1 - x0 + 1
				var h_sub := z1 - z0 + 1
				var vx_map := PackedInt32Array()
				vx_map.resize(w_sub * h_sub)
				vx_map.fill(-1)
				for iz in range(z0, z1):
					var r0 := iz * n
					var r1 := r0 + n
					for ix in range(x0, x1):
						var i00 := r0 + ix
						var i10 := i00 + 1
						var i01 := r1 + ix
						var i11 := i01 + 1
						if H[i00] <= 0.0 and H[i10] <= 0.0 and H[i01] <= 0.0 and H[i11] <= 0.0:
							continue
						var corners := [[ix, iz, i00], [ix + 1, iz, i10], [ix + 1, iz + 1, i11], [ix, iz + 1, i01]]
						var ci := [0, 0, 0, 0]
						for k in 4:
							var lx: int = corners[k][0] - x0
							var lz: int = corners[k][1] - z0
							var slot := lz * w_sub + lx
							var vid := vx_map[slot]
							if vid < 0:
								vid = verts.size()
								vx_map[slot] = vid
								var gidx: int = corners[k][2]
								var wx := min_c + float(corners[k][0]) * cell
								var wz := min_c + float(corners[k][1]) * cell
								verts.append(Vector3(wx, H[gidx], wz))
								nrms.append(norms[gidx])
								cols.append(vcols[gidx])
								uvs.append(Vector2(wx * 0.1, wz * 0.1))
							ci[k] = vid
						if absf(H[i00] - H[i11]) <= absf(H[i10] - H[i01]):
							indices.append_array([ci[0], ci[1], ci[2], ci[0], ci[2], ci[3]])
						else:
							indices.append_array([ci[0], ci[1], ci[3], ci[1], ci[2], ci[3]])
				if indices.is_empty():
					continue
				var arr := []
				arr.resize(Mesh.ARRAY_MAX)
				arr[Mesh.ARRAY_VERTEX] = verts
				arr[Mesh.ARRAY_NORMAL] = nrms
				arr[Mesh.ARRAY_COLOR] = cols
				arr[Mesh.ARRAY_TEX_UV] = uvs
				arr[Mesh.ARRAY_INDEX] = indices
				var mesh := ArrayMesh.new()
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
				var mi := MeshInstance3D.new()
				mi.mesh = mesh
				mi.material_override = mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				mtn_root.add_child(mi)
				chunk_cnt += 1

		# 仅在深渊黑曜岩壁中下部陡崖嵌合斜切六棱柱状玄武黑曜岩丛（地表山体保持纯净扫描级连续地形，零方块露头）
		var prng := RandomNumberGenerator.new()
		prng.seed = seed_base + 999
		var outcrops: Array = []
		var talus_boulders: Array = []
		var ledge_shrubs: Array = []
		var ledge_trunks: Array = []
		var add_veg: bool = bool(prof["add_veg"])
		var veg_d: float = float(prof.get("veg_density", 0.035))
		if not is_surf:
			for iz in range(3, n - 3, 2):
				var wz := min_c + float(iz) * cell
				var row := iz * n
				for ix in range(3, n - 3, 2):
					var idx := row + ix
					var h := H[idx]
					if h < 1.6 or h > 20.0:
						continue
					var nrm := norms[idx]
					if nrm.y < 0.70 and prng.randf() < 0.115:
						var wx := min_c + float(ix) * cell
						var sc := prng.randf_range(1.10, 2.25)
						var yaw := atan2(nrm.x, nrm.z) + prng.randf_range(-0.42, 0.42)
						var tilt_out := deg_to_rad(prng.randf_range(5.0, 15.0))
						var bs := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt_out)
						var sv := Vector3(sc * prng.randf_range(0.92, 1.35), sc * prng.randf_range(1.05, 1.65), sc * prng.randf_range(0.92, 1.35))
						var pos := Vector3(wx - nrm.x * 1.15, h - sv.y * 0.95, wz - nrm.z * 1.15)
						outcrops.append(Transform3D(bs.scaled_local(sv), pos))
			outcrop_cnt = outcrops.size()
			_add_shared_mm(mtn_root, _obsidian_column_cluster_mesh(), mat, outcrops, true)

		# 坡脚半埋崩积岩块 + 绝对平缓台面稀疏灌木/枯木
		for iz in range(2, n - 2, 2):
			var wz := min_c + float(iz) * cell
			var row := iz * n
			for ix in range(2, n - 2, 2):
				var idx := row + ix
				var h := H[idx]
				if h <= 0.15:
					continue
				var wx := min_c + float(ix) * cell
				if absf(wx) > raid.EXT_HALF + 16.0 or absf(wz) > raid.EXT_HALF + 16.0:
					continue
				var nrm := norms[idx]
				if h >= 0.20 and h <= 2.2 and nrm.y < 0.88 and prng.randf() < 0.085:
					var bs := prng.randf_range(0.55, 1.45)
					var b_rot := Basis(Vector3.UP, prng.randf() * TAU) * Basis(Vector3.RIGHT, deg_to_rad(prng.randf_range(-14, 14)))
					var b_sc := Vector3(bs * prng.randf_range(0.9, 1.4), bs * prng.randf_range(0.45, 0.72), bs * prng.randf_range(0.85, 1.3))
					talus_boulders.append(Transform3D(b_rot.scaled_local(b_sc), Vector3(wx + prng.randf_range(-0.9, 0.9), h - b_sc.y * 0.46, wz + prng.randf_range(-0.9, 0.9))))
				elif add_veg and h >= 2.2 and h <= 16.0 and nrm.y >= 0.92:
					var roll := prng.randf()
					if roll < veg_d:
						var ss := prng.randf_range(0.52, 0.96)
						ledge_shrubs.append(Transform3D(Basis(Vector3.UP, prng.randf() * TAU).scaled_local(Vector3(ss * 1.12, ss * 0.82, ss * 1.12)), Vector3(wx, h - 0.24, wz)))
					elif roll < veg_d + 0.006 and absf(wx) < half_f + 30.0 and absf(wz) < half_f + 30.0:
						var th := prng.randf_range(2.8, 4.6)
						ledge_trunks.append(Transform3D(Basis(Vector3.UP, prng.randf() * TAU).scaled_local(Vector3(th * 0.22, th, th * 0.22)), Vector3(wx, h - 0.30, wz)))
		# 坡脚碎岩同样使用共享世界空间 PBR 材质，颜色质感与山体 100% 浑然一体
		_add_shared_mm(mtn_root, A.rock_mesh(2 if is_surf else 7), mat, talus_boulders, false)
		if not ledge_shrubs.is_empty():
			raid._multimesh(A.shrub_mesh(0), A.foliage_mat("shrub"), ledge_shrubs, false)
		if not ledge_trunks.is_empty():
			raid._multimesh(A.tree_trunk_mesh(0, true), A.bark_mat(Color(0.28, 0.24, 0.19)), ledge_trunks, false)

	# 7. 裁剪式行合并 BoxShape3D 碰撞体
	var col_play := StaticBody3D.new()
	col_play.name = "MountainCol_Playable"
	col_play.collision_layer = 1
	col_play.collision_mask = 0
	raid.world.add_child(col_play)

	var col_bd := StaticBody3D.new()
	col_bd.name = "MountainCol_Backdrop"
	col_bd.collision_layer = 1
	col_bd.collision_mask = 0
	col_bd.set_meta("backdrop_static", true)
	raid.world.add_child(col_bd)

	var col_stride := 2
	var col_step := cell * float(col_stride)
	var max_run_cells := 6
	var play_shapes := 0
	var bd_shapes := 0
	for iz in range(0, n, col_stride):
		var wz := min_c + float(iz) * cell
		var ix := 0
		while ix < n:
			var idx := iz * n + ix
			var h0 := H[idx]
			if h0 < 1.15:
				ix += col_stride
				continue
			var wx0 := min_c + float(ix) * cell
			var sd0 := bd_cache[idx]
			if sd0 < -24.0:
				ix += col_stride
				continue
			var in_play: bool = raid.in_bounds_xz(Vector2(wx0, wz), 1.5)
			var run := 1
			var h_max := h0
			while run < max_run_cells and ix + run * col_stride < n:
				var nx_i := ix + run * col_stride
				var nidx := iz * n + nx_i
				var h_nxt := H[nidx]
				if h_nxt < 1.15 or bd_cache[nidx] < -24.0:
					break
				var wx_nxt := min_c + float(nx_i) * cell
				if raid.in_bounds_xz(Vector2(wx_nxt, wz), 1.5) != in_play:
					break
				h_max = maxf(h_max, h_nxt)
				run += 1
			var span_x := float(run) * col_step
			var cx_w := wx0 + (span_x - col_step) * 0.5
			var box_h := maxf(h_max + 0.5, 5.5)
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = Vector3(span_x + 0.2, box_h, col_step + 0.2)
			cs.shape = sh
			cs.position = Vector3(cx_w, box_h * 0.5, wz)
			if in_play:
				col_play.add_child(cs)
				raid.blocks.append(Rect2(cx_w - span_x * 0.5, wz - col_step * 0.5, span_x, col_step))
				play_shapes += 1
			else:
				col_bd.add_child(cs)
				bd_shapes += 1
			ix += run * col_stride

	var dt_ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("[mountain] map=%s chunks=%d outcrops=%d col=(play:%d bd:%d) %.1fms" % [str(raid.map_id), chunk_cnt, outcrop_cnt, play_shapes, bd_shapes, dt_ms])
