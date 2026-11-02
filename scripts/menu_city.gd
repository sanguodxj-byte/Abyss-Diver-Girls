extends Node3D
## 主菜单云下城市：真实 3D 楼体 + 战区地图俯拍地面 + 3D 云海层。
## 楼体的位置 / 尺寸来自战区地图生成时记录的每一栋楼（tests/groundbake.gd 导出 assets/ground_<map>.json），
## 与地面俯拍贴图一一对应。每 360m 一格，按格随机选图、旋转、镜像；格子沿 x 方向以 PERIOD 为周期，
## 地面向船尾流动时按列回收 / 重建楼体。

const MAPS := ["greyport", "ironbelt", "redlake"]
const TILE := 360.0
const PERIOD := 16
const ROW0 := -10
const ROWS := 11
const ALT := 260.0          ## 离地高度（米）
const CLOUD_Y := -80.0      ## 云海层高度
const H_SCALE := 1.0        ## 楼高按战区原比例（与俯拍贴图里的楼影一致）
const SPEED := 6.0          ## 地面流速（米/秒）
const VIEW_X := 2900.0      ## 楼体生成的 x 半宽
const VIEW_ZMIN := -2700.0

var layouts: Array = []     ## 每张图的楼房列表
var cells: Array = []       ## [i][j] -> {map, k, mirror, urban}
var ground_mat: ShaderMaterial
var bldg_mat: ShaderMaterial
var box_mesh: ArrayMesh
var city: Node3D
var cols := {}              ## 世界列号 -> MultiMeshInstance3D
var offset := 0.0


func setup(sky_mat: ShaderMaterial, sun_dir: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261102
	var texs: Array = []
	for m in MAPS.size():
		var gen := _gen_tile(1000 + m * 77, m == 0)
		layouts.append(gen[0])
		texs.append(gen[1])
	# 城区成片：低频噪声决定哪些格是城市
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.16
	var data := Image.create(PERIOD, ROWS, false, Image.FORMAT_RGBA8)
	for i in PERIOD:
		cells.append([])
		for j in ROWS:
			var nv := noise.get_noise_2d(cos(TAU * i / PERIOD) * 3.0, sin(TAU * i / PERIOD) * 3.0 + j * 0.9)
			var c := {"map": rng.randi() % 3, "k": rng.randi() % 4, "mirror": rng.randf() < 0.5, "urban": nv > -0.25}
			cells[i].append(c)
			data.set_pixel(i, j, Color(c.map / 2.0, c.k / 3.0, 1.0 if c.mirror else 0.0, 1.0 if c.urban else 0.0))
	var common := {}
	for p in ["sun_col", "haze_col", "horizon", "cloud_lit", "cloud_shade", "cloud_cover", "exposure", "drift"]:
		common[p] = sky_mat.get_shader_parameter(p)
	common["sun_dir"] = sun_dir
	common["cloud_y"] = CLOUD_Y
	# 地面
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = load("res://shaders/menu_ground.gdshader")
	for p in common:
		if common[p] != null:
			ground_mat.set_shader_parameter(p, common[p])
	for i in 3:
		ground_mat.set_shader_parameter("map%d" % i, texs[i])
	ground_mat.set_shader_parameter("cells", ImageTexture.create_from_image(data))
	ground_mat.set_shader_parameter("period", PERIOD)
	ground_mat.set_shader_parameter("row0", ROW0)
	ground_mat.set_shader_parameter("rows", ROWS)
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60000, 60000)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	gm.mesh = pm
	gm.material_override = ground_mat
	gm.position = Vector3(0, -ALT, 0)
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gm)
	# 楼体
	bldg_mat = ShaderMaterial.new()
	bldg_mat.shader = load("res://shaders/menu_bldg.gdshader")
	for p in common:
		if common[p] != null:
			bldg_mat.set_shader_parameter(p, common[p])
	var st := SurfaceTool.new()
	st.create_from(BoxMesh.new(), 0)
	var arr := st.commit_to_arrays()
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for vi in vs.size():
		vs[vi].y += 0.5
	arr[Mesh.ARRAY_VERTEX] = vs
	box_mesh = ArrayMesh.new()
	box_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	city = Node3D.new()
	city.position = Vector3(0, -ALT, 0)
	add_child(city)
	# 云海层
	var cm := ShaderMaterial.new()
	cm.shader = load("res://shaders/menu_cloudsea.gdshader")
	for p in common:
		if common[p] != null:
			cm.set_shader_parameter(p, common[p])
	var cl := MeshInstance3D.new()
	var cp := PlaneMesh.new()
	cp.size = Vector2(14000, 14000)
	cl.mesh = cp
	cl.material_override = cm
	cl.position = Vector3(0, -50.0, 0)
	cl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cl)
	_update_cols()


## ---- 程序化城区：一格 360m，四周半条主干道，内部再切街区 → 地块 → 楼 ----
## 返回 [楼体列表, 地面贴图]。楼体条目：[x, z, 宽, 高, 深, yaw, 底y, r, g, b, 类型]
## 类型（写进 INSTANCE_CUSTOM.a）：1 = 有窗楼体，0.5 = 烧空的残楼，0 = 屋顶设备 / 无窗
const TEX := 1024
const FLOOR := 3.3

func _gen_tile(sd: int, downtown: bool) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var img := Image.create(TEX, TEX, false, Image.FORMAT_RGB8)
	img.fill(Color(0.17, 0.165, 0.16))               # 沥青
	var out: Array = []
	# 内部街道切分
	var xs := [-180.0 + 11.0]
	var zs := [-180.0 + 11.0]
	var nx := rng.randi_range(1, 2)
	var nz := rng.randi_range(1, 2)
	for i in nx:
		var c := -180.0 + 360.0 * (i + 1) / (nx + 1) + rng.randf_range(-25, 25)
		xs.append(c - 7.0); xs.append(c + 7.0)
	for i in nz:
		var c := -180.0 + 360.0 * (i + 1) / (nz + 1) + rng.randf_range(-25, 25)
		zs.append(c - 7.0); zs.append(c + 7.0)
	xs.append(180.0 - 11.0)
	zs.append(180.0 - 11.0)
	# 车道虚线
	for i in range(1, xs.size() - 1, 2):
		var cx: float = (xs[i] + xs[i + 1]) * 0.5
		for zz in range(-180, 180, 9):
			_rect(img, cx - 0.12, zz, 0.24, 4.0, Color(0.42, 0.4, 0.34))
	for i in range(1, zs.size() - 1, 2):
		var cz: float = (zs[i] + zs[i + 1]) * 0.5
		for xx in range(-180, 180, 9):
			_rect(img, xx, cz - 0.12, 4.0, 0.24, Color(0.42, 0.4, 0.34))
	for bi in range(0, xs.size(), 2):
		for bj in range(0, zs.size(), 2):
			var x0: float = xs[bi]; var x1: float = xs[bi + 1]
			var z0: float = zs[bj]; var z1: float = zs[bj + 1]
			_rect(img, x0, z0, x1 - x0, z1 - z0, Color(0.31, 0.3, 0.28))   # 人行道
			x0 += 3.0; x1 -= 3.0; z0 += 3.0; z1 -= 3.0
			var lots: Array = []
			_split(rng, Rect2(x0, z0, x1 - x0, z1 - z0), lots)
			for lot in lots:
				_lot(rng, lot, downtown, img, out)
	var tex := ImageTexture.create_from_image(img)
	img.generate_mipmaps()
	tex = ImageTexture.create_from_image(img)
	return [out, tex]


func _split(rng: RandomNumberGenerator, r: Rect2, lots: Array) -> void:
	var lim := rng.randf_range(26.0, 52.0)
	if r.size.x <= lim and r.size.y <= lim:
		lots.append(r)
		return
	if r.size.x >= r.size.y:
		var c := r.size.x * rng.randf_range(0.38, 0.62)
		_split(rng, Rect2(r.position, Vector2(c, r.size.y)), lots)
		_split(rng, Rect2(r.position + Vector2(c, 0), Vector2(r.size.x - c, r.size.y)), lots)
	else:
		var c := r.size.y * rng.randf_range(0.38, 0.62)
		_split(rng, Rect2(r.position, Vector2(r.size.x, c)), lots)
		_split(rng, Rect2(r.position + Vector2(0, c), Vector2(r.size.x, r.size.y - c)), lots)


func _box(out: Array, cx: float, cz: float, w: float, h: float, d: float, y0: float, col: Color, kind: float) -> void:
	out.append([cx, cz, w, h, d, 0.0, y0, col.r, col.g, col.b, kind])


func _lot(rng: RandomNumberGenerator, r: Rect2, downtown: bool, img: Image, out: Array) -> void:
	var ground := Color(0.25, 0.23, 0.2).lerp(Color(0.2, 0.19, 0.18), rng.randf())
	_rect(img, r.position.x, r.position.y, r.size.x, r.size.y, ground)
	var roll := rng.randf()
	if roll < 0.08:
		# 空地 / 瓦砾堆
		_rubble(rng, img, r, 0.9)
		return
	var inset := rng.randf_range(0.5, 2.5)
	var w := r.size.x - inset * 2.0
	var d := r.size.y - inset * 2.0
	if w < 6.0 or d < 6.0:
		return
	var c := r.get_center()
	var floors: int
	if downtown:
		floors = int(clamp(rng.randfn(11.0, 6.0), 3, 27))
	else:
		floors = int(clamp(rng.randfn(5.0, 2.5), 2, 12))
	var h := floors * FLOOR
	var col := Color(0.5, 0.48, 0.45).lerp(Color(0.33, 0.32, 0.31), rng.randf())
	var cr := rng.randf()
	if cr < 0.18: col = Color(0.47, 0.36, 0.29)       # 砖
	elif cr < 0.28: col = Color(0.55, 0.53, 0.49)    # 浅色石材
	var ruin := rng.randf() < 0.32
	_rect(img, c.x - w * 0.5 - 0.8, c.y - d * 0.5 - 0.8, w + 1.6, d + 1.6, ground.darkened(0.35))   # 墙根阴影
	if ruin:
		# 残楼：只剩下半截 + 一两根残柱 / 残墙，旁边一摊瓦砾
		var keep := maxi(1, int(floors * rng.randf_range(0.15, 0.5)))
		_box(out, c.x, c.y, w, keep * FLOOR, d, 0.0, col.darkened(0.15), 0.5)
		for _i in rng.randi_range(1, 3):
			var fw := w * rng.randf_range(0.15, 0.45)
			var fd := d * rng.randf_range(0.15, 0.45)
			var px := c.x + (w - fw) * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0)
			var pz := c.y + (d - fd) * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0)
			var ph := FLOOR * int(rng.randf_range(keep + 1, max(keep + 2, floors * 0.9)))
			_box(out, px, pz, fw, ph, fd, 0.0, col.darkened(0.2), 0.5)
		var rr := Rect2(r.position - Vector2(2, 2), r.size + Vector2(4, 4))
		_rubble(rng, img, rr, 0.5)
		return
	# 完整楼：高楼有退台塔楼
	if floors >= 12 and rng.randf() < 0.75:
		var base_f := int(floors * rng.randf_range(0.25, 0.45))
		_box(out, c.x, c.y, w, base_f * FLOOR, d, 0.0, col, 1.0)
		var tw := w * rng.randf_range(0.55, 0.8)
		var td := d * rng.randf_range(0.55, 0.8)
		var tx := c.x + (w - tw) * 0.5 * rng.randf_range(-0.8, 0.8)
		var tz := c.y + (d - td) * 0.5 * rng.randf_range(-0.8, 0.8)
		_box(out, tx, tz, tw, (floors - base_f) * FLOOR, td, base_f * FLOOR, col.lightened(0.04), 1.0)
		_roof(rng, out, tx, tz, tw, td, floors * FLOOR)
	elif w > 24.0 and d > 24.0 and rng.randf() < 0.4:
		# 回字 / L 形：两翼
		var wing := rng.randf_range(0.35, 0.5)
		_box(out, c.x - w * (1.0 - wing) * 0.5, c.y, w * wing, h, d, 0.0, col, 1.0)
		var h2 := h * rng.randf_range(0.6, 1.0)
		_box(out, c.x + w * wing * 0.5, c.y - d * (1.0 - wing) * 0.5, w * (1.0 - wing), h2, d * wing, 0.0, col.darkened(0.04), 1.0)
		_roof(rng, out, c.x - w * (1.0 - wing) * 0.5, c.y, w * wing, d, h)
	else:
		_box(out, c.x, c.y, w, h, d, 0.0, col, 1.0)
		_roof(rng, out, c.x, c.y, w, d, h)


func _roof(rng: RandomNumberGenerator, out: Array, cx: float, cz: float, w: float, d: float, h: float) -> void:
	var dark := Color(0.3, 0.3, 0.3)
	# 楼梯间
	if rng.randf() < 0.8:
		var sx := rng.randf_range(3.5, 6.0)
		var sz := rng.randf_range(3.5, 6.0)
		_box(out, cx + rng.randf_range(-0.3, 0.3) * (w - sx), cz + rng.randf_range(-0.3, 0.3) * (d - sz), sx, 3.0, sz, h, Color(0.42, 0.41, 0.39), 0.0)
	# 水箱 / 空调机组
	for _i in rng.randi_range(1, 4):
		var u := rng.randf_range(1.5, 3.5)
		_box(out, cx + rng.randf_range(-0.4, 0.4) * (w - u), cz + rng.randf_range(-0.4, 0.4) * (d - u), u, rng.randf_range(1.2, 3.0), u * rng.randf_range(0.6, 1.4), h, dark.lerp(Color(0.45, 0.4, 0.34), rng.randf()), 0.0)


func _rubble(rng: RandomNumberGenerator, img: Image, r: Rect2, amt: float) -> void:
	var n := int(r.size.x * r.size.y * 0.08 * amt)
	for _i in n:
		var p := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		var s := rng.randf_range(0.4, 2.2)
		var c := Color(0.36, 0.33, 0.29).lerp(Color(0.14, 0.13, 0.12), rng.randf())
		_rect(img, p.x, p.y, s, s * rng.randf_range(0.5, 1.5), c)


func _rect(img: Image, x: float, z: float, w: float, d: float, c: Color) -> void:
	var k := TEX / 360.0
	var px := int((x + 180.0) * k)
	var pz := int((z + 180.0) * k)
	var r := Rect2i(px, pz, maxi(1, int(w * k)), maxi(1, int(d * k))).intersection(Rect2i(0, 0, TEX, TEX))
	if r.size.x > 0 and r.size.y > 0:
		img.fill_rect(r, c)


static func _rot1(q: Vector2) -> Vector2:
	return Vector2(q.y, -q.x)


func _build_col(wi: int) -> MultiMeshInstance3D:
	var ci := posmod(wi, PERIOD)
	var xf: Array = []
	var cus: Array = []
	for j in ROWS:
		var zc := float(ROW0 + j) * TILE
		if zc < VIEW_ZMIN or zc > 200.0:
			continue
		var c: Dictionary = cells[ci][j]
		if not c.urban:
			continue
		for b in layouts[c.map]:
			var s := Vector2(b[0], b[1])
			var sz := Vector2(b[2], b[4])
			var yaw: float = b[5] if b.size() > 5 else 0.0
			if c.mirror:
				s.x = -s.x
				yaw = -yaw
			for _k in c.k:
				s = _rot1(s)
			yaw += c.k * PI * 0.5
			var base := Vector3(s.x, b[6], s.y + zc)
			var bas := Basis(Vector3.UP, yaw)
			xf.append(Transform3D(bas * Basis.from_scale(Vector3(sz.x, b[3] * H_SCALE, sz.y)), base))
			cus.append(Color(b[7], b[8], b[9], b[10]))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = box_mesh
	mm.instance_count = xf.size()
	for n in xf.size():
		mm.set_instance_transform(n, xf[n])
		mm.set_instance_custom_data(n, cus[n])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = bldg_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(wi * TILE, 0, 0)
	city.add_child(mi)
	return mi


func _update_cols() -> void:
	var lo := int(floor((-VIEW_X - offset) / TILE))
	var hi := int(ceil((VIEW_X - offset) / TILE))
	for wi in cols.keys():
		if wi < lo or wi > hi:
			cols[wi].queue_free()
			cols.erase(wi)
	for wi in range(lo, hi + 1):
		if not cols.has(wi):
			cols[wi] = _build_col(wi)


func _process(delta: float) -> void:
	offset += delta * SPEED
	city.position.x = offset
	ground_mat.set_shader_parameter("offset_x", offset)
	_update_cols()
