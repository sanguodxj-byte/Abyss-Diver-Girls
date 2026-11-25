extends RefCounted
## 固定世界连续山体地形生成器 V5：
## 1) 全世界统一采用全局坐标 (WC.origin(map_id) + local_xz) 与单一地质种子，彻底抛弃 40×40 区块分块孤岛，
##    所有地表战区共享同一套跨越战区边界并延展至地平线的连续宏大山脉（WORLD_RANGES + 柔和 K 区山体域）；
## 2) 物理走廊（道路、铁路、含干河的全量河湖、建筑、POI、地标、索桥、转场口）统一平滑切槽；
##    山缘撤离点自动向开阔谷地切出自然山坳口（绝不形成死坑），外围泛洪连通性检查彻底消灭任何山腹内封闭“火山口”空洞；
## 3) 基于真实向内距离场 d_in 的金字塔-主脊剖面 + 贯穿坡脚的深水力冲沟与放射状岩肋（彻底告别“垂直壁平顶蛋糕/布丁块”）；
## 4) 不等宽冲积扇碎石裙边（5–14.5m 动态延展）+ 1024×1024 扫描级无缝 PBR 贴图 + 深渊柱状玄武黑曜岩环壁。

const A = preload("res://scripts/art.gd")
const WC = preload("res://scripts/world_city.gd")
const WorldLinkScript = preload("res://scripts/world_link.gd")

const WORLD_SEED := 13370
const ABYSS_SEED := 88060

## 固定大世界连续山脉骨架（全局世界坐标，彻底取代细长等宽毛毛虫折线与孤立分块土包）：
## 每项：[折线点数组, 基准半宽(米), 峰高权重]
## 经精确核对：绝不压盖或合围尘原 depot7(160,240)、东部山口(142,320)、裂谷东北台地(506,248)、东部缆车站(534,350)。
const WORLD_RANGES := [
	# 1. 尘原-裂谷大分水岭北翼（位于 depot7 东侧、东部山口北侧，衔接裂谷西北断崖群）
	[[Vector2(194.0, 192.0), Vector2(226.0, 224.0), Vector2(262.0, 210.0)], 28.0, 0.94],
	# 2. 尘原-裂谷大分水岭南翼（位于东部山口南侧，构成自然南北夹峙山口）
	[[Vector2(114.0, 362.0), Vector2(134.0, 396.0), Vector2(150.0, 428.0)], 24.0, 0.88],
	# 3. 裂谷大绝壁东脉（位于东北台地与东部缆车站以东，巍峨合围大峡谷东壁且绝不封闭撤离台地）
	[[Vector2(548.0, 168.0), Vector2(582.0, 248.0), Vector2(600.0, 352.0), Vector2(590.0, 456.0), Vector2(554.0, 548.0)], 46.0, 1.06],
	# 4. 东南玄武岩高地外围主脉（在裂谷东壁之后层层拔高，直抵东湾海岸前缘，奠定远景群山层次）
	[[Vector2(616.0, 220.0), Vector2(624.0, 348.0), Vector2(612.0, 492.0), Vector2(568.0, 610.0)], 48.0, 1.16],
	# 5. 裂谷南缘荒漠大断崖（地平线南界连绵山岭，消除方形地图南边界）
	[[Vector2(236.0, 598.0), Vector2(335.0, 618.0), Vector2(455.0, 610.0), Vector2(552.0, 578.0)], 44.0, 1.04],
	# 6. 尘原南麓风蚀残山（宽体非对称荒漠岩脊，向东柔延补齐裂谷西南方向远景轮廓，避开尘原南缘、外环高速与南北大道）
	[[Vector2(-235.0, 514.0), Vector2(-168.0, 504.0), Vector2(-108.0, 536.0), Vector2(-58.0, 566.0)], 27.0, 0.88],
	# 7. 尘原远西荒漠山脉（外环高速以西远景群峰，消除尘原西侧平板地平线）
	[[Vector2(-425.0, 215.0), Vector2(-396.0, 360.0), Vector2(-412.0, 515.0), Vector2(-355.0, 645.0)], 56.0, 1.10],
	# 8. 尘原-裂谷远南荒漠山岭（外环高速以南连续远景群峰，向东衔接裂谷南缘大断崖，消除西南/正南地平线缺口）
	[[Vector2(-335.0, 695.0), Vector2(-190.0, 718.0), Vector2(-50.0, 712.0), Vector2(115.0, 692.0), Vector2(220.0, 686.0), Vector2(335.0, 692.0)], 50.0, 1.06],
	# 9. 灰港/赤湖远西丘陵山脉（西部地平线连绵远山）
	[[Vector2(-435.0, -340.0), Vector2(-415.0, -140.0), Vector2(-430.0, 60.0)], 54.0, 1.06],
	# 10. 赤湖/湾港远北地平线山脊（位于外环高速与北郊林带以北，在 far=850m 内自然收束北部远景）
	[[Vector2(-265.0, -768.0), Vector2(-135.0, -786.0), Vector2(20.0, -794.0), Vector2(195.0, -780.0), Vector2(395.0, -756.0)], 46.0, 1.04],
]

static var _mtn_shader: Shader
static var _obs_shader: Shader
static var _skirt_shader: Shader
static var _obs_col_mesh: ArrayMesh


static func _push_tri(verts: PackedVector3Array, nrms: PackedVector3Array, cols: PackedColorArray, uvs: PackedVector2Array, a: Vector3, b: Vector3, c: Vector3, nrm: Vector3, col: Color) -> void:
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


## 3D 六棱/五棱柱状玄武黑曜岩丛（斜切顶面 + 硬边柱棱，共享世界空间黑曜岩着色器）
static func _obsidian_column_cluster_mesh() -> ArrayMesh:
	if _obs_col_mesh != null:
		return _obs_col_mesh
	var verts := PackedVector3Array()
	var nrms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()

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
		for k in sides:
			var kn := (k + 1) % sides
			var p0: Vector3 = bot[k]
			var p1: Vector3 = bot[kn]
			var p2: Vector3 = top[kn]
			var p3: Vector3 = top[k]
			var mid_out := Vector3((p0.x + p1.x) * 0.5 - ox, 0.0, (p0.z + p1.z) * 0.5 - oz).normalized()
			_push_tri(verts, nrms, cols, uvs, p0, p1, p2, mid_out, col_side)
			_push_tri(verts, nrms, cols, uvs, p0, p2, p3, mid_out, col_side)
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


static func _profile(map_id: String, is_surface: bool) -> Dictionary:
	if not is_surface:
		return {
			"max_h": 38.0, "outer_boost": 1.38, "strata_str": 0.24, "strata_h": 7.2,
			"crag_w": 0.44, "normal_str": 0.86,
			"rock_tint": Color(1.06, 1.08, 1.22), "strata_tint": Color(0.95, 0.98, 1.12),
			"scree_tint": Color(0.23, 0.21, 0.30), "moss_col": Color(0.24, 0.14, 0.34),
			"moss_amt": 0.0, "strata_freq": 0.0, "dip_vec": Vector2(0.028, -0.022),
			"add_veg": false, "veg_density": 0.0,
		}
	match map_id:
		"canyon":
			return {
				"max_h": 28.0, "outer_boost": 1.32, "strata_str": 0.62, "strata_h": 4.2,
				"crag_w": 0.42, "normal_str": 1.20,
				"rock_tint": Color(1.04, 0.92, 0.78), "strata_tint": Color(0.62, 0.49, 0.39),
				"scree_tint": Color(0.82, 0.73, 0.62), "moss_col": Color(0.29, 0.33, 0.21),
				"moss_amt": 0.11, "strata_freq": 0.56, "dip_vec": Vector2(0.032, 0.020),
				"add_veg": true, "veg_density": 0.022,
			}
		"dustfield":
			return {
				"max_h": 25.0, "outer_boost": 1.30, "strata_str": 0.64, "strata_h": 3.9,
				"crag_w": 0.40, "normal_str": 1.18,
				"rock_tint": Color(1.06, 0.95, 0.80), "strata_tint": Color(0.66, 0.54, 0.42),
				"scree_tint": Color(0.86, 0.77, 0.65), "moss_col": Color(0.31, 0.33, 0.21),
				"moss_amt": 0.08, "strata_freq": 0.60, "dip_vec": Vector2(0.036, -0.016),
				"add_veg": true, "veg_density": 0.018,
			}
		_:
			return {
				"max_h": 25.5, "outer_boost": 1.32, "strata_str": 0.48, "strata_h": 4.2,
				"crag_w": 0.44, "normal_str": 1.24,
				"rock_tint": Color(0.76, 0.79, 0.84), "strata_tint": Color(0.42, 0.41, 0.39),
				"scree_tint": Color(0.58, 0.56, 0.51), "moss_col": Color(0.17, 0.24, 0.13),
				"moss_amt": 0.44, "strata_freq": 0.62, "dip_vec": Vector2(0.028, 0.019),
				"add_veg": true, "veg_density": 0.048,
			}


static func _make_mat(prof: Dictionary, is_surf: bool, world_orig: Vector2) -> ShaderMaterial:
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
		m.set_shader_parameter("world_offset", world_orig)
		m.set_shader_parameter("rock_tint", prof["rock_tint"])
		m.set_shader_parameter("scree_tint", prof["scree_tint"])
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
	m.set_shader_parameter("world_offset", world_orig)
	m.set_shader_parameter("rock_tint", prof["rock_tint"])
	m.set_shader_parameter("strata_tint", prof["strata_tint"])
	m.set_shader_parameter("scree_tint", prof["scree_tint"])
	m.set_shader_parameter("moss_col", prof["moss_col"])
	m.set_shader_parameter("moss_amt", float(prof["moss_amt"]))
	m.set_shader_parameter("strata_freq", float(prof["strata_freq"]))
	m.set_shader_parameter("dip_vec", prof["dip_vec"])
	m.set_shader_parameter("normal_str", float(prof["normal_str"]))
	m.set_meta("no_outline", true)
	return m


static func _make_skirt_mat(prof: Dictionary, world_orig: Vector2) -> ShaderMaterial:
	if _skirt_shader == null:
		_skirt_shader = load("res://shaders/mountain_skirt.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _skirt_shader
	m.set_shader_parameter("scree_a", A.world_tex("mtn_scree_a.png"))
	m.set_shader_parameter("scree_n", A.world_tex("mtn_scree_n.png"))
	m.set_shader_parameter("scree_r", A.world_tex("mtn_scree_r.png"))
	m.set_shader_parameter("n_low", A.noise_tex("grime_raw", 512))
	m.set_shader_parameter("world_offset", world_orig)
	m.set_shader_parameter("scree_tint", prof["scree_tint"])
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


## 域扭曲、变宽、两端自然收尖的固定世界山脉势场光栅化
static func _raster_world_range(pot: PackedFloat32Array, n: int, min_c: float, cell: float, orig: Vector2, pts: Array, base_rad: float, wgt: float, n_warp: FastNoiseLite, n_macro: FastNoiseLite) -> void:
	if pts.size() < 2:
		return
	var max_rad := base_rad * 1.65 + 20.0
	var cum := PackedFloat32Array()
	cum.resize(pts.size())
	cum[0] = 0.0
	for i in range(1, pts.size()):
		cum[i] = cum[i - 1] + (pts[i] as Vector2).distance_to(pts[i - 1] as Vector2)
	var tot_len := maxf(cum[pts.size() - 1], 1.0)

	for i in range(pts.size() - 1):
		var wa: Vector2 = pts[i]
		var wb: Vector2 = pts[i + 1]
		var la := wa - orig
		var lb := wb - orig
		var ix0 := maxi(0, floori((minf(la.x, lb.x) - max_rad - min_c) / cell))
		var ix1 := mini(n - 1, ceili((maxf(la.x, lb.x) + max_rad - min_c) / cell))
		var iz0 := maxi(0, floori((minf(la.y, lb.y) - max_rad - min_c) / cell))
		var iz1 := mini(n - 1, ceili((maxf(la.y, lb.y) + max_rad - min_c) / cell))
		if ix0 > ix1 or iz0 > iz1:
			continue
		var ab := wb - wa
		var ab2 := maxf(ab.length_squared(), 1e-4)
		var seg_l := sqrt(ab2)
		for iz in range(iz0, iz1 + 1):
			var gz := orig.y + min_c + float(iz) * cell
			var row := iz * n
			for ix in range(ix0, ix1 + 1):
				var gx := orig.x + min_c + float(ix) * cell
				var qx := gx + n_warp.get_noise_2d(gx * 0.85, gz * 0.85) * 16.0
				var qz := gz + n_warp.get_noise_2d(gx * 0.85 + 173.0, gz * 0.85 - 119.0) * 16.0
				var t := clampf((Vector2(qx, qz) - wa).dot(ab) / ab2, 0.0, 1.0)
				var s_frac := (cum[i] + t * seg_l) / tot_len
				var end_taper := smoothstep(0.0, 0.14, s_frac) * smoothstep(1.0, 0.86, s_frac)
				var mac := n_macro.get_noise_2d(gx * 1.35, gz * 1.35) * 0.5 + 0.5
				var eff_rad := base_rad * (0.68 + 0.64 * mac) * (0.50 + 0.50 * end_taper)
				var d := Vector2(qx, qz).distance_to(wa + ab * t)
				if d < eff_rad:
					var v := smoothstep(eff_rad, eff_rad * 0.10, d) * wgt * (0.48 + 0.52 * end_taper)
					var idx := row + ix
					if v > pot[idx]:
						pot[idx] = v


## 可分离滑窗平滑
static func _blur_field(src: PackedFloat32Array, n: int, radius: int, passes: int) -> PackedFloat32Array:
	var cur := src.duplicate()
	var tmp := PackedFloat32Array()
	tmp.resize(n * n)
	var inv := 1.0 / float(radius * 2 + 1)
	for _p in passes:
		for iz in n:
			var row := iz * n
			var acc := 0.0
			for k in range(-radius, radius + 1):
				acc += cur[row + clampi(k, 0, n - 1)]
			for ix in n:
				tmp[row + ix] = acc * inv
				acc += cur[row + mini(ix + radius + 1, n - 1)] - cur[row + maxi(ix - radius, 0)]
		for ix in n:
			var acc := 0.0
			for k in range(-radius, radius + 1):
				acc += tmp[clampi(k, 0, n - 1) * n + ix]
			for iz in n:
				cur[iz * n + ix] = acc * inv
				acc += tmp[mini(iz + radius + 1, n - 1) * n + ix] - tmp[maxi(iz - radius, 0) * n + ix]
	return cur


## 两遍向内 Chamfer 欧氏近似距离场
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


## 外部开阔空间 BFS 泛洪：任何完全被山体四面包围、无法连通战场的孤立空洞自动填实为实体山岩，彻底杜绝山腹“火山口/甜甜圈”假坑
static func _fill_enclosed_holes(solid_mtn: PackedByteArray, n: int, min_c: float, cell: float, is_surf: bool, seed_pts: Array) -> void:
	var total := n * n
	var visited := PackedByteArray()
	visited.resize(total)
	var queue := PackedInt32Array()
	queue.resize(total)
	var qh := 0
	var qt := 0

	if is_surf:
		for i in n:
			for bidx in [i, (n - 1) * n + i, i * n, i * n + (n - 1)]:
				if solid_mtn[bidx] == 0 and visited[bidx] == 0:
					visited[bidx] = 1
					queue[qt] = bidx
					qt += 1

	for sp: Vector2 in seed_pts:
		var sx := clampi(roundi((sp.x - min_c) / cell), 1, n - 2)
		var sz := clampi(roundi((sp.y - min_c) / cell), 1, n - 2)
		# 若精确点碰巧在边界，向周边 3×3 找一个开阔点起泛洪
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				var idx := (sz + dz) * n + (sx + dx)
				if solid_mtn[idx] == 0 and visited[idx] == 0:
					visited[idx] = 1
					queue[qt] = idx
					qt += 1

	while qh < qt:
		var cur := queue[qh]
		qh += 1
		var cx := cur % n
		var cz := cur / n
		if cx > 0:
			var ni := cur - 1
			if solid_mtn[ni] == 0 and visited[ni] == 0:
				visited[ni] = 1
				queue[qt] = ni
				qt += 1
		if cx + 1 < n:
			var ni := cur + 1
			if solid_mtn[ni] == 0 and visited[ni] == 0:
				visited[ni] = 1
				queue[qt] = ni
				qt += 1
		if cz > 0:
			var ni := cur - n
			if solid_mtn[ni] == 0 and visited[ni] == 0:
				visited[ni] = 1
				queue[qt] = ni
				qt += 1
		if cz + 1 < n:
			var ni := cur + n
			if solid_mtn[ni] == 0 and visited[ni] == 0:
				visited[ni] = 1
				queue[qt] = ni
				qt += 1

	# 未被外部开阔战场连通到的内部空洞 → 全部实心化为山体
	for i in total:
		if solid_mtn[i] == 0 and visited[i] == 0:
			solid_mtn[i] = 1


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
	var mid_str := str(raid.map_id)
	var orig: Vector2 = WC.origin(mid_str)
	# 地表战区外延至 EXT_HALF + 185m（950m 连续视野），直接衔接固定大世界远景群山（含尘原-裂谷远西南群峰）
	var ext: float = (raid.EXT_HALF + 185.0) if is_surf else 315.0
	var cell: float = 2.5
	var n: int = int(floor((ext * 2.0) / cell)) + 1
	var min_c: float = -ext
	var total: int = n * n

	var prof := _profile(mid_str, is_surf)
	var seed_base: int = WORLD_SEED if is_surf else ABYSS_SEED

	# 1. 全局固定世界 C++ FastNoiseLite 地质雕刻噪声器
	var n_warp := FastNoiseLite.new()
	n_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_warp.seed = seed_base + 11
	n_warp.frequency = 0.0115
	n_warp.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_warp.fractal_octaves = 2

	var n_ridge := FastNoiseLite.new()
	n_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_ridge.seed = seed_base + 23
	n_ridge.frequency = 0.0145
	n_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	n_ridge.fractal_octaves = 4
	n_ridge.fractal_lacunarity = 2.15
	n_ridge.fractal_gain = 0.48

	var n_crag := FastNoiseLite.new()
	n_crag.noise_type = FastNoiseLite.TYPE_CELLULAR
	n_crag.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	n_crag.fractal_type = FastNoiseLite.FRACTAL_NONE
	n_crag.seed = seed_base + 37
	n_crag.frequency = 0.025 if is_surf else 0.019

	var n_spur := FastNoiseLite.new()
	n_spur.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_spur.seed = seed_base + 47
	n_spur.frequency = 0.039
	n_spur.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	n_spur.fractal_octaves = 3
	n_spur.fractal_lacunarity = 2.12
	n_spur.fractal_gain = 0.46

	var n_macro := FastNoiseLite.new()
	n_macro.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_macro.seed = seed_base + 71
	n_macro.frequency = 0.0075
	n_macro.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_macro.fractal_octaves = 3

	var n_fan := FastNoiseLite.new()
	n_fan.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_fan.seed = seed_base + 103
	n_fan.frequency = 0.028
	n_fan.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_fan.fractal_octaves = 2

	# 2. 光栅化全量物理走廊禁入区（道路、铁路、建筑、POI、地标、索桥、转场口）
	var blocked := PackedByteArray()
	blocked.resize(total)
	var no_skirt := PackedByteArray()
	no_skirt.resize(total)
	var bfs_seeds: Array = [Vector2.ZERO]

	for cv: Dictionary in raid.curves:
		var pts: PackedVector2Array = cv.d
		var rw := float(cv.w) * 0.5 + 4.4
		var rw_sk := float(cv.w) * 0.5 + 0.9
		if pts.size() > 0:
			bfs_seeds.append(pts[pts.size() / 2])
		for i in range(pts.size() - 1):
			_raster_capsule_b(blocked, n, min_c, cell, pts[i], pts[i + 1], rw)
			_raster_capsule_b(no_skirt, n, min_c, cell, pts[i], pts[i + 1], rw_sk)
	for rl: PackedVector2Array in raid.rail_polys:
		for i in range(rl.size() - 1):
			_raster_capsule_b(blocked, n, min_c, cell, rl[i], rl[i + 1], 5.4)
			_raster_capsule_b(no_skirt, n, min_c, cell, rl[i], rl[i + 1], 2.2)
	for r_rect: Rect2 in raid.blocks:
		_raster_rect(blocked, n, min_c, cell, r_rect, 2.2)
		_raster_rect(no_skirt, n, min_c, cell, r_rect, 0.6)
	for pc: Vector3 in raid.poi_centers:
		_raster_disc(blocked, n, min_c, cell, pc.x, pc.z, 14.5)
		bfs_seeds.append(Vector2(pc.x, pc.z))
	for kc in raid._keep_clear:
		if kc is Rect2:
			_raster_rect(blocked, n, min_c, cell, kc, 2.4)
		elif kc is Vector3:
			_raster_disc(blocked, n, min_c, cell, kc.x, kc.y, kc.z + 2.4)
	for e_lm in raid.MAP.get("landmarks", []):
		var lt := str(e_lm.get("type", ""))
		if lt == "rope_bridge":
			var ls: Vector2 = WC.landmark_spot(mid_str, e_lm)
			var r_rad := deg_to_rad(float(e_lm.get("rot", 0.0)))
			var dir2 := Vector2(-sin(r_rad), -cos(r_rad))
			_raster_capsule_b(blocked, n, min_c, cell, ls - dir2 * 18.5, ls + dir2 * 18.5, 7.2)
	for e_key: String in WorldLinkScript.LINKS.get(mid_str, {}):
		var gp: Vector2 = WC.gate_info(mid_str, e_key).pos
		_raster_disc(blocked, n, min_c, cell, gp.x, gp.y, 19.0)
		bfs_seeds.append(gp)

	# 3. 合成全局固定世界连续山体势场 raw_m（固定世界连续山脉 + 柔和域扭曲 K 区 + 深渊有机火山口）
	var raw_m := PackedFloat32Array()
	raw_m.resize(total)
	var bd_cache := PackedFloat32Array()
	bd_cache.resize(total)
	var any_mtn: bool = false

	var r_o: Vector2 = raid.layout.r_o
	var r_span: float = float(raid.layout.r_n) * WC.RAST
	var r_x0 := r_o.x + 8.0
	var r_x1 := r_o.x + r_span - 8.0
	var r_z0 := r_o.y + 8.0
	var r_z1 := r_o.y + r_span - 8.0

	if is_surf:
		for sp: Array in WORLD_RANGES:
			_raster_world_range(raw_m, n, min_c, cell, orig, sp[0], float(sp[1]), float(sp[2]), n_warp, n_macro)

	for iz in n:
		var wz := min_c + float(iz) * cell
		var gz := orig.y + wz
		var row := iz * n
		for ix in n:
			var idx := row + ix
			var wx := min_c + float(ix) * cell
			var gx := orig.x + wx
			# 适度 10.5m 地质域扭曲（world_city 栅格本身已做 28m 扭曲，避免过度撕裂出碎泡）
			var wx_w := wx + n_warp.get_noise_2d(gx, gz) * 10.5
			var wz_w := wz + n_warp.get_noise_2d(gx + 217.0, gz - 143.0) * 10.5
			var gx_w := orig.x + wx_w
			var gz_w := orig.y + wz_w

			if is_surf:
				var zt: String
				if wx_w >= r_x0 and wx_w <= r_x1 and wz_w >= r_z0 and wz_w <= r_z1:
					zt = raid.zone_at(Vector3(wx_w, 0.0, wz_w))
				else:
					zt = WC.terrain(Vector2(gx_w, gz_w))
				if zt == "A" or zt == "B":
					# 严禁山体延伸入东湾海域与沙滩
					blocked[idx] = 1
					no_skirt[idx] = 1
					raw_m[idx] = 0.0
				elif zt == "K":
					if raw_m[idx] < 0.96:
						raw_m[idx] = 0.96
					any_mtn = true
				elif raw_m[idx] > 0.01:
					any_mtn = true
			else:
				var sd: float = raid.border_dist(Vector2(wx, wz))
				bd_cache[idx] = sd
				var rad_w := n_warp.get_noise_2d(gx * 1.1, gz * 1.1) * 13.0 + n_spur.get_noise_2d(gx * 0.55, gz * 0.55) * 5.0
				var outer_v := smoothstep(5.0, -18.0, sd + rad_w)
				var inner_v := 0.0
				if wx_w >= r_x0 and wx_w <= r_x1 and wz_w >= r_z0 and wz_w <= r_z1:
					if raid.zone_at(Vector3(wx_w, 0.0, wz_w)) == "K":
						inner_v = 0.92
				var mv := maxf(outer_v, inner_v)
				if mv > 0.01:
					raw_m[idx] = mv
					any_mtn = true

	if not any_mtn:
		return

	# 全量河道（含干河谷 干河！）与湖泊标记进 blocked，让干河自然劈开大峡谷，不再被山体闷盖或挤出假坑
	if is_surf:
		for iz in n:
			var wz := min_c + float(iz) * cell
			var row := iz * n
			for ix in n:
				var idx := row + ix
				if blocked[idx] == 0:
					if raw_m[idx] > 0.01 or (ix > 4 and ix < n - 5 and iz > 4 and iz < n - 5 and (raw_m[idx - 4] > 0.01 or raw_m[idx + 4] > 0.01 or raw_m[idx - 4 * n] > 0.01 or raw_m[idx + 4 * n] > 0.01)):
						var p2 := Vector2(min_c + float(ix) * cell, wz)
						if raid.in_river(p2, 2.8) or raid.in_wet(p2, 3.2):
							blocked[idx] = 1
							no_skirt[idx] = 1

	# 4. 平滑势场并提取实体山脉域 + 山缘撤离点自动开谷口 + 外部泛洪彻底消灭山腹内封闭假坑
	var pot := _blur_field(raw_m, n, 3, 2)

	# 位于山缘的撤离点（如尘原东部山口、裂谷东北台地/东部缆车站）自动向谷地方向切出自然山坳谷口
	if is_surf:
		for ex: Array in raid.MAP.get("extracts", []):
			var ep := Vector2(float(ex[1]), float(ex[2]))
			var eix := clampi(roundi((ep.x - min_c) / cell), 0, n - 1)
			var eiz := clampi(roundi((ep.y - min_c) / cell), 0, n - 1)
			if pot[eiz * n + eix] >= 0.18:
				var dir_in := Vector2(-ep.x * (1.55 if absf(ep.x) > absf(ep.y) else 0.75), -ep.y * (0.75 if absf(ep.x) > absf(ep.y) else 1.55))
				if dir_in.length_squared() < 1e-4:
					dir_in = Vector2(-1.0, 0.0)
				else:
					dir_in = dir_in.normalized()
				_raster_disc(blocked, n, min_c, cell, ep.x, ep.y, 13.0)
				_raster_capsule_b(blocked, n, min_c, cell, ep, ep + dir_in * 44.0, 11.0)
				bfs_seeds.append(ep)

	var solid_mtn := PackedByteArray()
	solid_mtn.resize(total)
	var pot_thresh := 0.34 if is_surf else 0.30
	for i in total:
		solid_mtn[i] = 1 if (pot[i] >= pot_thresh and blocked[i] == 0) else 0

	# 外部开阔空间 BFS 泛洪：把山体内部任何未连通外界的封闭小坑全部填实！
	_fill_enclosed_holes(solid_mtn, n, min_c, cell, is_surf, bfs_seeds)

	# 计算真实向内距离场 d_in（到最近平地/峡谷通道的欧氏近似距离），平滑去棱后作为金字塔-主脊海拔骨架
	var d_in_raw := _chamfer_inward(solid_mtn, n, cell, 88.0)
	var d_in_s := _blur_field(d_in_raw, n, 2, 1)

	# 5. 雕刻全局世界连续地质高程场 H[idx]（真实金字塔主脊 + 凹形冲积山麓 + 贯穿坡脚的放射状冲沟与岩肋）
	var H := PackedFloat32Array()
	H.resize(total)
	var gully_arr := PackedFloat32Array()
	gully_arr.resize(total)
	var max_h: float = float(prof["max_h"])
	var outer_boost: float = float(prof["outer_boost"])
	var strata_str: float = float(prof["strata_str"])
	var strata_h: float = float(prof["strata_h"])
	var crag_w: float = float(prof["crag_w"])
	var dip_v: Vector2 = prof["dip_vec"]
	var half_f: float = float(raid.HALF)

	for iz in n:
		var wz := min_c + float(iz) * cell
		var gz := orig.y + wz
		var row := iz * n
		for ix in n:
			var idx := row + ix
			var dr := d_in_raw[idx]
			if dr <= 0.05:
				H[idx] = -0.10
				continue

			# 边界 5 格柔收，避免远景网格最外框悬空直切
			var edge_f := clampf(minf(minf(float(ix), float(n - 1 - ix)), minf(float(iz), float(n - 1 - iz))) / 5.0, 0.0, 1.0)
			# 用平滑距离场消除 Chamfer 八角折痕，同时在实体边界严格归零
			var d_in := d_in_s[idx] * smoothstep(0.0, 3.2, dr) * edge_f
			if d_in <= 0.08:
				H[idx] = -0.10
				continue

			var wx := min_c + float(ix) * cell
			var gx := orig.x + wx
			var w_x := gx + n_warp.get_noise_2d(gx * 1.15, gz * 1.15) * 15.0
			var w_z := gz + n_warp.get_noise_2d(gx * 1.15 + 91.0, gz * 1.15 - 63.0) * 15.0

			var r_main := pow(clampf(n_ridge.get_noise_2d(w_x, w_z) * 0.5 + 0.5, 0.0, 1.0), 1.44 if is_surf else 1.58)
			var crag := clampf(n_crag.get_noise_2d(w_x, w_z) + 1.0, 0.0, 1.0)
			crag = pow(crag, 0.82 if is_surf else 1.04)
			var r_spur := clampf(n_spur.get_noise_2d(w_x, w_z) * 0.5 + 0.5, 0.0, 1.0)
			var gully := pow(clampf(1.0 - r_spur * 1.16, 0.0, 1.0), 1.35)
			gully_arr[idx] = gully
			var mac := clampf(n_macro.get_noise_2d(gx, gz) * 0.5 + 0.5, 0.0, 1.0)

			var mo := 0.0
			if is_surf:
				var sd_s: float = raid.border_dist(Vector2(wx, wz))
				bd_cache[idx] = sd_s
				if sd_s < -20.0:
					mo = clampf((-sd_s - 20.0) / 85.0, 0.0, 1.0)
			else:
				var sd_u := bd_cache[idx]
				if sd_u < 0.0:
					mo = clampf(-sd_u / 34.0, 0.0, 1.0)

			# 核心：向内距离驱动的自然金字塔/主脊坡面曲线（彻底消灭垂直壁方糕/布丁！）
			# 地表山麓 0..14.5m 呈凹形缓坡过渡到中上部岩峰；深渊火山口 0..10.5m 更显峭壁压迫感
			var apron_w := 14.5 if is_surf else 10.5
			var apron := smoothstep(0.0, apron_w, d_in)
			var core_h := pow(clampf(d_in / (36.0 if is_surf else 32.0), 0.0, 1.42), 0.78)
			var slope_prof := pow(apron, 1.45) * (0.24 + 0.76 * core_h)

			var outer_mul := lerpf(1.0, outer_boost, mo)
			var mac_scale := (0.64 + 0.72 * mac) if is_surf else (0.56 + 0.80 * mac)
			var ridgeness := 0.36 + (0.64 - crag_w * 0.55) * r_main + crag_w * 0.68 * crag
			var e := max_h * slope_prof * ridgeness * mac_scale * outer_mul

			# 放射状副岩肋（在中坡拉出棱角分明的岩石山脊嘴）
			var flank := smoothstep(2.8, 18.0, d_in)
			var mid_core := clampf(d_in / 34.0, 0.0, 1.15)
			e += (r_spur - 0.43) * (5.2 if is_surf else 4.6) * flank * (0.42 + 0.58 * mid_core)
			# 贯穿至山麓的水力侵蚀深冲沟（直接劈入坡脚，彻底打碎圆润饼干轮廓）
			var gully_w := smoothstep(1.2, 15.0, d_in) * (1.0 - 0.32 * smoothstep(28.0, 58.0, d_in))
			e -= gully * (4.4 if is_surf else 3.6) * gully_w

			# 沉积岩 / 深渊火山口宏大阶梯岩台
			if strata_str > 0.01 and e > 2.0:
				var dip := gx * dip_v.x + gz * dip_v.y
				var s_coord := (e + dip) / strata_h
				var s_fl := floorf(s_coord)
				var s_fr := s_coord - s_fl
				var terraced := (s_fl + smoothstep(0.0, 0.36, s_fr) * 0.82 + s_fr * 0.18) * strata_h - dip
				var t_amt := strata_str * smoothstep(2.0, 6.2, e) * (1.0 - gully * 0.45)
				e = lerpf(e, terraced, t_amt)

			H[idx] = e if e > 0.04 else -0.10

	# 6. 面积加权连续法线 + 地质曲率顶点色
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
			var ao := clampf(0.90 + curv * 0.38 - gully * 0.26 - (1.0 - smoothstep(0.0, 2.0, h0)) * 0.08, 0.48, 1.0)
			var ridge_exp := clampf(curv * 1.15 + smoothstep(0.42, 0.88, h0 / max_h) * 0.48, 0.0, 1.0)
			var talus := clampf(gully * 0.76 + (1.0 - smoothstep(0.4, 4.8, h0)) * 0.64 + maxf(0.0, -curv) * 0.62, 0.0, 1.0)
			vcols[idx] = Color(ao, ridge_exp, talus, clampf(h0 / max_h, 0.0, 1.0))

	# 7. 构建 32x32 大分块网格 + 冲沟冲积扇碎石裙边 + 深渊六棱黑曜岩柱
	var chunk_cnt := 0
	var outcrop_cnt := 0
	if not Net.is_dedicated_server():
		var mtn_root := Node3D.new()
		mtn_root.name = "MountainTerrain"
		mtn_root.add_to_group("mountain_terrain")
		raid.world.add_child(mtn_root)
		var mat := _make_mat(prof, is_surf, orig)
		var csz := 32
		var nc := ceili(float(n - 1) / float(csz))
		# 完全位于距地图中心 250m 之外的远景山体分块采用 stride-2（5.0m 单元）降采样，远山三角面削减 4 倍，并在 250m 交界边做无缝缝合
		var chunk_outer := PackedByteArray()
		chunk_outer.resize(nc * nc)
		for cz in nc:
			var ch_z0_o := min_c + float(cz * csz) * cell
			var ch_z1_o := min_c + float(mini(cz * csz + csz, n - 1)) * cell
			var near_z := maxf(0.0, maxf(-ch_z1_o, ch_z0_o))
			for cx in nc:
				var ch_x0_o := min_c + float(cx * csz) * cell
				var ch_x1_o := min_c + float(mini(cx * csz + csz, n - 1)) * cell
				var near_x := maxf(0.0, maxf(-ch_x1_o, ch_x0_o))
				if is_surf and (near_x * near_x + near_z * near_z > 250.0 * 250.0):
					chunk_outer[cz * nc + cx] = 1
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
						if H[row + ix] > 0.04:
							has_geo = true
							break
					if has_geo:
						break
				if not has_geo:
					continue
				var is_outer := chunk_outer[cz * nc + cx] == 1
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
				var get_vid := func(gx: int, gz: int) -> int:
					var slot := (gz - z0) * w_sub + (gx - x0)
					var vid := vx_map[slot]
					if vid < 0:
						vid = verts.size()
						vx_map[slot] = vid
						var gidx := gz * n + gx
						var wx := min_c + float(gx) * cell
						var wz := min_c + float(gz) * cell
						verts.append(Vector3(wx, H[gidx], wz))
						nrms.append(norms[gidx])
						cols.append(vcols[gidx])
						uvs.append(Vector2(wx * 0.1, wz * 0.1))
					return vid
				if not is_outer:
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
							var v00: int = get_vid.call(ix, iz)
							var v10: int = get_vid.call(ix + 1, iz)
							var v11: int = get_vid.call(ix + 1, iz + 1)
							var v01: int = get_vid.call(ix, iz + 1)
							if absf(H[i00] - H[i11]) <= absf(H[i10] - H[i01]):
								indices.append_array([v00, v10, v11, v00, v11, v01])
							else:
								indices.append_array([v00, v10, v01, v10, v11, v01])
				else:
					var st_l: bool = (cx > 0 and chunk_outer[cz * nc + (cx - 1)] == 0)
					var st_r: bool = (cx + 1 < nc and chunk_outer[cz * nc + (cx + 1)] == 0)
					var st_t: bool = (cz > 0 and chunk_outer[(cz - 1) * nc + cx] == 0)
					var st_b: bool = (cz + 1 < nc and chunk_outer[(cz + 1) * nc + cx] == 0)
					var iz := z0
					while iz < z1:
						var iz2 := mini(iz + 2, z1)
						var ix := x0
						while ix < x1:
							var ix2 := mini(ix + 2, x1)
							var need_l := st_l and ix == x0 and (iz2 - iz) == 2
							var need_r := st_r and ix2 == x1 and (iz2 - iz) == 2
							var need_t := st_t and iz == z0 and (ix2 - ix) == 2
							var need_b := st_b and iz2 == z1 and (ix2 - ix) == 2
							var i00 := iz * n + ix
							var i10 := iz * n + ix2
							var i01 := iz2 * n + ix
							var i11 := iz2 * n + ix2
							if not (need_l or need_r or need_t or need_b):
								if H[i00] > 0.0 or H[i10] > 0.0 or H[i01] > 0.0 or H[i11] > 0.0:
									var v00: int = get_vid.call(ix, iz)
									var v10: int = get_vid.call(ix2, iz)
									var v11: int = get_vid.call(ix2, iz2)
									var v01: int = get_vid.call(ix, iz2)
									if absf(H[i00] - H[i11]) <= absf(H[i10] - H[i01]):
										indices.append_array([v00, v10, v11, v00, v11, v01])
									else:
										indices.append_array([v00, v10, v01, v10, v11, v01])
							else:
								var ring: Array[Vector2i] = []
								ring.append(Vector2i(ix, iz))
								if need_t:
									ring.append(Vector2i(ix + 1, iz))
								ring.append(Vector2i(ix2, iz))
								if need_r:
									ring.append(Vector2i(ix2, iz + 1))
								ring.append(Vector2i(ix2, iz2))
								if need_b:
									ring.append(Vector2i(ix + 1, iz2))
								ring.append(Vector2i(ix, iz2))
								if need_l:
									ring.append(Vector2i(ix, iz + 1))
								var cx_m := ix + 1
								var cz_m := iz + 1
								var any_pos := H[cz_m * n + cx_m] > 0.0
								if not any_pos:
									for rp: Vector2i in ring:
										if H[rp.y * n + rp.x] > 0.0:
											any_pos = true
											break
								if any_pos:
									var vc: int = get_vid.call(cx_m, cz_m)
									var rn := ring.size()
									for k in rn:
										var pa := ring[k]
										var pb := ring[(k + 1) % rn]
										indices.append(vc)
										indices.append(get_vid.call(pa.x, pa.y))
										indices.append(get_vid.call(pb.x, pb.y))
							ix = ix2
						iz = iz2
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
				mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
				var ch_x0 := min_c + float(x0) * cell
				var ch_x1 := min_c + float(x1) * cell
				var ch_z0 := min_c + float(z0) * cell
				var ch_z1 := min_c + float(z1) * cell
				var shadow_lim := half_f + 90.0
				var in_sh_range := ch_x1 >= -shadow_lim and ch_x0 <= shadow_lim and ch_z1 >= -shadow_lim and ch_z0 <= shadow_lim
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if in_sh_range else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mtn_root.add_child(mi)
				chunk_cnt += 1

		# 7b. 不等宽冲积扇碎石过渡裙边（5.2–14.8m 动态自然延展；按 32x32 网格分块 + 视距剔除，彻底消除全图 950m 单网格无剔除透明过绘）
		var out_mask := PackedByteArray()
		out_mask.resize(total)
		for i in total:
			out_mask[i] = 0 if H[i] > 0.04 else 1
		var dist_out := _chamfer_inward(out_mask, n, cell, 18.0)
		var skirt_a := PackedFloat32Array()
		skirt_a.resize(total)
		var out_solid := cell * 0.92
		for iz in range(1, n - 1):
			var wz := min_c + float(iz) * cell
			var gz := orig.y + wz
			var row := iz * n
			for ix in range(1, n - 1):
				var idx := row + ix
				var h := H[idx]
				if h > 0.04:
					if h <= 2.6:
						skirt_a[idx] = smoothstep(2.6, 0.30, h)
				else:
					var dout := dist_out[idx]
					if dout > 0.01 and dout < 15.5 and no_skirt[idx] == 0:
						var wx := min_c + float(ix) * cell
						var gx := orig.x + wx
						var fn_v := clampf(n_fan.get_noise_2d(gx, gz) * 0.5 + 0.5, 0.0, 1.0)
						var fan_reach := lerpf(5.2, 14.8, pow(fn_v, 1.32)) if is_surf else lerpf(6.0, 12.5, fn_v)
						if dout < fan_reach:
							if not is_surf or not raid.in_wet(Vector2(wx, wz), 0.9):
								skirt_a[idx] = smoothstep(fan_reach, out_solid, dout)

		var skirt_mat := _make_skirt_mat(prof, orig)
		for cz in nc:
			var z0 := maxi(1, cz * csz)
			var z1 := mini((cz + 1) * csz, n - 2)
			if z0 >= z1:
				continue
			for cx in nc:
				var x0 := maxi(1, cx * csz)
				var x1 := mini((cx + 1) * csz, n - 2)
				if x0 >= x1:
					continue
				var has_sk := false
				for iz in range(z0, z1 + 1):
					var row := iz * n
					for ix in range(x0, x1 + 1):
						if skirt_a[row + ix] > 0.01:
							has_sk = true
							break
					if has_sk:
						break
				if not has_sk:
					continue
				var sk_verts := PackedVector3Array()
				var sk_nrms := PackedVector3Array()
				var sk_cols := PackedColorArray()
				var sk_uvs := PackedVector2Array()
				var sk_idx := PackedInt32Array()
				var w_sub := x1 - x0 + 1
				var h_sub := z1 - z0 + 1
				var sk_map := PackedInt32Array()
				sk_map.resize(w_sub * h_sub)
				sk_map.fill(-1)
				for iz in range(z0, z1):
					var r0 := iz * n
					var r1 := r0 + n
					for ix in range(x0, x1):
						var i00 := r0 + ix
						var i10 := i00 + 1
						var i01 := r1 + ix
						var i11 := i01 + 1
						if skirt_a[i00] <= 0.01 and skirt_a[i10] <= 0.01 and skirt_a[i01] <= 0.01 and skirt_a[i11] <= 0.01:
							continue
						var corners := [[ix, iz, i00], [ix + 1, iz, i10], [ix + 1, iz + 1, i11], [ix, iz + 1, i01]]
						var ci := [0, 0, 0, 0]
						for k in 4:
							var lx: int = corners[k][0] - x0
							var lz: int = corners[k][1] - z0
							var slot := lz * w_sub + lx
							var vid := sk_map[slot]
							if vid < 0:
								vid = sk_verts.size()
								sk_map[slot] = vid
								var gidx: int = corners[k][2]
								var wx := min_c + float(corners[k][0]) * cell
								var wz := min_c + float(corners[k][1]) * cell
								var hv := H[gidx]
								var sy := maxf(0.0, hv) + (0.048 if hv > 0.04 else 0.028)
								var sn := Vector3.UP if hv <= 0.04 else Vector3.UP.lerp(norms[gidx], smoothstep(0.0, 1.6, hv)).normalized()
								sk_verts.append(Vector3(wx, sy, wz))
								sk_nrms.append(sn)
								sk_cols.append(Color(vcols[gidx].r, 1.0, 0.0, skirt_a[gidx]))
								sk_uvs.append(Vector2(wx * 0.1, wz * 0.1))
							ci[k] = vid
						if absf(H[i00] - H[i11]) <= absf(H[i10] - H[i01]):
							sk_idx.append_array([ci[0], ci[1], ci[2], ci[0], ci[2], ci[3]])
						else:
							sk_idx.append_array([ci[0], ci[1], ci[3], ci[1], ci[2], ci[3]])
				if sk_idx.is_empty():
					continue
				var sk_arr := []
				sk_arr.resize(Mesh.ARRAY_MAX)
				sk_arr[Mesh.ARRAY_VERTEX] = sk_verts
				sk_arr[Mesh.ARRAY_NORMAL] = sk_nrms
				sk_arr[Mesh.ARRAY_COLOR] = sk_cols
				sk_arr[Mesh.ARRAY_TEX_UV] = sk_uvs
				sk_arr[Mesh.ARRAY_INDEX] = sk_idx
				var sk_mesh := ArrayMesh.new()
				sk_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sk_arr)
				var sk_mi := MeshInstance3D.new()
				sk_mi.name = "MountainSkirt_%d_%d" % [cx, cz]
				sk_mi.mesh = sk_mesh
				sk_mi.material_override = skirt_mat
				sk_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				sk_mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
				sk_mi.visibility_range_end = 340.0
				sk_mi.visibility_range_end_margin = 14.0
				mtn_root.add_child(sk_mi)

		# 7c. 深渊井斜切六棱黑曜岩柱群 + 坡脚半埋崩积碎岩 + 平顶稀疏灌木
		var prng := RandomNumberGenerator.new()
		prng.seed = seed_base + 999
		var outcrops: Array = []
		var talus_boulders: Array = []
		var ledge_shrubs: Array = []
		var ledge_trunks: Array = []
		var add_veg: bool = bool(prof["add_veg"])
		var veg_d: float = float(prof.get("veg_density", 0.030))
		if not is_surf:
			for iz in range(3, n - 3, 2):
				var wz := min_c + float(iz) * cell
				var row := iz * n
				for ix in range(3, n - 3, 2):
					var idx := row + ix
					var h := H[idx]
					if h < 1.6 or h > 22.0:
						continue
					var nrm := norms[idx]
					if nrm.y < 0.72 and prng.randf() < 0.115:
						var wx := min_c + float(ix) * cell
						var sc := prng.randf_range(1.15, 2.35)
						var yaw := atan2(nrm.x, nrm.z) + prng.randf_range(-0.42, 0.42)
						var tilt_out := deg_to_rad(prng.randf_range(5.0, 15.0))
						var bs := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt_out)
						var sv := Vector3(sc * prng.randf_range(0.92, 1.35), sc * prng.randf_range(1.05, 1.68), sc * prng.randf_range(0.92, 1.35))
						var pos := Vector3(wx - nrm.x * 1.15, h - sv.y * 0.95, wz - nrm.z * 1.15)
						outcrops.append(Transform3D(bs.scaled_local(sv), pos))
			outcrop_cnt = outcrops.size()
			if not outcrops.is_empty():
				raid._multimesh(_obsidian_column_cluster_mesh(), mat, outcrops, true)

		for iz in range(2, n - 2, 2):
			var wz := min_c + float(iz) * cell
			var row := iz * n
			for ix in range(2, n - 2, 2):
				var idx := row + ix
				var h := H[idx]
				var ska := skirt_a[idx]
				if h <= 0.04 and ska < 0.42:
					continue
				var wx := min_c + float(ix) * cell
				if absf(wx) > raid.EXT_HALF + 20.0 or absf(wz) > raid.EXT_HALF + 20.0:
					continue
				var nrm := norms[idx]
				if ska >= 0.42 and h <= 1.8 and prng.randf() < (0.12 if is_surf else 0.14):
					var bs := prng.randf_range(0.45, 1.30)
					var b_rot := Basis(Vector3.UP, prng.randf() * TAU) * Basis(Vector3.RIGHT, deg_to_rad(prng.randf_range(-12, 12)))
					var b_sc := Vector3(bs * prng.randf_range(0.95, 1.55), bs * prng.randf_range(0.32, 0.54), bs * prng.randf_range(0.85, 1.35))
					var by := maxf(0.0, h) - b_sc.y * 0.44
					talus_boulders.append(Transform3D(b_rot.scaled_local(b_sc), Vector3(wx + prng.randf_range(-0.9, 0.9), by, wz + prng.randf_range(-0.9, 0.9))))
				elif add_veg and h >= 2.4 and h <= 16.0 and nrm.y >= 0.92:
					var roll := prng.randf()
					if roll < veg_d:
						var ss := prng.randf_range(0.50, 0.90)
						ledge_shrubs.append(Transform3D(Basis(Vector3.UP, prng.randf() * TAU).scaled_local(Vector3(ss * 1.12, ss * 0.82, ss * 1.12)), Vector3(wx, h - 0.24, wz)))
					elif roll < veg_d + 0.005 and absf(wx) < half_f + 30.0 and absf(wz) < half_f + 30.0:
						var th := prng.randf_range(2.8, 4.6)
						ledge_trunks.append(Transform3D(Basis(Vector3.UP, prng.randf() * TAU).scaled_local(Vector3.ONE * th), Vector3(wx, h - 0.30, wz)))
		if not talus_boulders.is_empty():
			raid._multimesh(A.rock_mesh_low(2 if is_surf else 7), mat, talus_boulders, false)
		if not ledge_shrubs.is_empty():
			raid._multimesh(A.shrub_mesh(0), A.foliage_mat("shrub"), ledge_shrubs, false)
		if not ledge_trunks.is_empty():
			raid._multimesh(A.dead_tree_mesh(0), A.bark_mat(Color(0.28, 0.24, 0.19)), ledge_trunks, false)

	# 8. 贴合山脚轮廓的 2.5m 精度二维矩形合并空气墙碰撞体（空间分桶 StaticBody3D，全覆盖至 MapEdgeAirWall 边界）
	# 必须打上 water_bank 元数据：与 MapEdgeAirWall / 河湖岸墙一致，防止 landmarks._clear_aprons() 误删！
	var play_buckets := {}
	var bd_buckets := {}
	var bucket_sz := 64.0
	var get_bucket := func(buckets: Dictionary, bkey: Vector2i, is_bd: bool) -> StaticBody3D:
		if buckets.has(bkey):
			return buckets[bkey]
		var sb := StaticBody3D.new()
		sb.name = ("MountainWall_B_%d_%d" if is_bd else "MountainWall_P_%d_%d") % [bkey.x, bkey.y]
		sb.collision_layer = 1
		sb.collision_mask = 0
		sb.set_meta("water_bank", true)
		sb.set_meta("mountain_wall", true)
		if is_bd:
			sb.set_meta("backdrop_static", true)
		sb.position = Vector3((float(bkey.x) + 0.5) * bucket_sz, 0.0, (float(bkey.y) + 0.5) * bucket_sz)
		raid.world.add_child(sb)
		buckets[bkey] = sb
		return sb

	var col_lim: float = (raid.EXT_HALF + 10.0) if is_surf else (raid.HALF + 40.0)
	var col_grid := PackedByteArray()
	col_grid.resize(total)
	for iz in n:
		var wz := min_c + float(iz) * cell
		if absf(wz) > col_lim:
			continue
		var row := iz * n
		for ix in n:
			var idx := row + ix
			if H[idx] < 0.45:
				continue
			var wx := min_c + float(ix) * cell
			if absf(wx) > col_lim:
				continue
			col_grid[idx] = 1 if raid.in_bounds_xz(Vector2(wx, wz), 1.5) else 2

	# 贪心 2D 矩形合并（最大 35m×35m）：保留山脚 2.5m 精确外轮廓，同时将山体内部合并为极少数大空气墙盒体
	var max_cells := 14
	var play_shapes := 0
	var bd_shapes := 0
	for iz in n:
		var row0 := iz * n
		for ix in n:
			var tag := col_grid[row0 + ix]
			if tag == 0:
				continue
			var w := 1
			while w < max_cells and ix + w < n and col_grid[row0 + ix + w] == tag:
				w += 1
			var h := 1
			while h < max_cells and iz + h < n:
				var r_chk := (iz + h) * n + ix
				var ok := true
				for dx in w:
					if col_grid[r_chk + dx] != tag:
						ok = false
						break
				if not ok:
					break
				h += 1
			var h_max := 0.0
			for dz in h:
				var rr := (iz + dz) * n + ix
				for dx in w:
					col_grid[rr + dx] = 0
					var hv := H[rr + dx]
					if hv > h_max:
						h_max = hv
			var span_x := float(w) * cell
			var span_z := float(h) * cell
			var cx_w := min_c + (float(ix) + float(w - 1) * 0.5) * cell
			var cz_w := min_c + (float(iz) + float(h - 1) * 0.5) * cell
			# 空气墙最小高度 18.0m（与 MapEdgeAirWall 对齐），杜绝推进跳跃/虫群越墙或穿模进山腹
			var box_h := maxf(h_max + 2.0, 18.0)
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = Vector3(span_x + 0.14, box_h, span_z + 0.14)
			cs.shape = sh
			var in_play := tag == 1
			var bkey := Vector2i(floori(cx_w / bucket_sz), floori(cz_w / bucket_sz))
			var sb: StaticBody3D = get_bucket.call(play_buckets if in_play else bd_buckets, bkey, not in_play)
			cs.position = Vector3(cx_w - sb.position.x, box_h * 0.5, cz_w - sb.position.z)
			sb.add_child(cs)
			if in_play:
				raid.blocks.append(Rect2(cx_w - span_x * 0.5, cz_w - span_z * 0.5, span_x, span_z))
				play_shapes += 1
			else:
				bd_shapes += 1

	var dt_ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("[mountain] map=%s chunks=%d outcrops=%d col=(play:%d/%d bd:%d/%d) %.1fms" % [mid_str, chunk_cnt, outcrop_cnt, play_shapes, play_buckets.size(), bd_shapes, bd_buckets.size(), dt_ms])
