extends Node3D
## 静态世界的渲染合批 + 分块流式（只管外观；碰撞体、导航网格不经过这里，玩法完全不变）
## - 世界按 CHUNK 米切成方块；每块持有自己的合批网格：
##     · add_mesh：单个静态网格（楼体、路面、墙、道具……）按 材质 + 投影 合并成一个 ArrayMesh（一块一材质一次绘制）
##     · add_inst：重复的小件（窗、碎石、草……）按 网格 + 材质 收成 MultiMesh
## - 写实涂装（mech_paint）只差底色的材质合成同一个「去色」共享材质：底色写进 MultiMesh 实例自定义数据
##   （tint_mode 1）或合并网格的顶点色 gba（tint_mode 2；r 通道仍是倒角边缘遮罩），全图不再每色一份材质
## - 分块外观懒构建：焦点（相机视线落地点）到分块矩形 ≤ stream_r 才建、才显示，离开 stream_r + HYST 隐藏；
##   每个几何体另设 visibility_range_end 兜底（按相机到可见地面最远角的距离 + 分块半对角线算出，见 VIS_END）

const CHUNK := 48.0
const STREAM_R := 70.0   ## 俯视相机最远档（ZOOM_MAX）16:9 时可见地面约 ±43.5 米（横）/ ±27.5 米（纵），超宽屏 ±59 米，留余量取 70
const HYST := 8.0
## 相机到可见地面最远角约 90 米（16:9）/ 99 米（21:9），加分块半对角线（含楼高）约 40 米
const VIS_END := 140.0
const CAM_DIST_REF := 62.8   ## ZOOM_MAX 时相机到焦点的距离；拉远的相机（截图等）按比例放大 stream_r
const PAINT_PATH := "res://shaders/mech_paint.gdshader"
const BUILDS_PER_FRAME := 2
const MM_MIN := 32   ## 同块同网格不超过这么多个实例时并进合并网格，不单开 MultiMesh

static var _tint_mats := {}   ## 去色共享材质：参数（除底色外）+ tint_mode → 材质

var _chunks := {}   ## Vector2i → {"merge": {key: 组}, "inst": {key: 组}, "node": Node3D, "on": bool}
var _tinted := {}   ## 网格 RID|表面|底色 → 带底色顶点色的单表面网格（合并用，按局次缓存）
var _pending := false
var stats := {"mesh_parts": 0, "inst": 0, "built": 0}


static func chunk_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))


## 写实涂装材质拆成「去色共享材质 + 底色」；其他材质原样返回、底色为白
static func split_tint(m: Material, mode: int) -> Array:
	if m is StandardMaterial3D:
		return _split_std(m, mode)
	if not (m is ShaderMaterial) or m.shader == null or m.shader.resource_path != PAINT_PATH:
		return [m, Color.WHITE]
	var sm: ShaderMaterial = m
	var col: Color = sm.get_shader_parameter("base_color")
	var mk := "_tint%d" % mode
	if sm.has_meta(mk):
		return [sm.get_meta(mk), col]
	var parts := PackedStringArray([str(mode)])
	var bare = sm.get_shader_parameter("bare_metal")
	if bare is Color:
		# 裸金属色（只在掉漆棱边露出）多随底色变：量化成 0.1 一档的同亮度灰，否则每色一份材质、合不了批
		var l := snappedf(bare.get_luminance(), 0.1)
		bare = Color(l, l, l, 1.0)
	for u in sm.shader.get_shader_uniform_list():
		if u.name == "bare_metal":
			parts.append(str(bare))
		elif u.name != "base_color" and u.name != "tint_mode":
			parts.append(str(sm.get_shader_parameter(u.name)))
	var key := "|".join(parts)
	var out: ShaderMaterial = _tint_mats.get(key)
	if out == null:
		out = sm.duplicate()
		out.set_shader_parameter("base_color", Color.WHITE)
		out.set_shader_parameter("tint_mode", mode)
		if bare is Color:
			out.set_shader_parameter("bare_metal", bare)
		_tint_mats[key] = out
	sm.set_meta(mk, out)
	return [out, col]


## 标准材质（贴花、灯片……常按实例改透明度/颜色复制出很多份）：去掉反照率色，改用顶点色 / MultiMesh 实例色
## （vertex_color_use_as_albedo）。本来就用顶点色的不动。
static func _split_std(m: StandardMaterial3D, mode: int) -> Array:
	if m.vertex_color_use_as_albedo or m.next_pass != null:
		return [m, Color.WHITE]
	var mk := "_tint%d" % mode
	if m.has_meta(mk):
		return [m.get_meta(mk), m.albedo_color]
	var parts := PackedStringArray(["std", str(mode)])
	for pr in m.get_property_list():
		if (pr.usage & PROPERTY_USAGE_STORAGE) and pr.name != "albedo_color" and pr.name != "resource_name" and pr.name != "resource_local_to_scene":
			parts.append(str(m.get(pr.name)))
	var key := "|".join(parts)
	var out: StandardMaterial3D = _tint_mats.get(key)
	if out == null:
		out = m.duplicate()
		out.albedo_color = Color.WHITE
		out.vertex_color_use_as_albedo = true
		_tint_mats[key] = out
	m.set_meta(mk, out)
	return [out, m.albedo_color]


func _chunk(c: Vector2i) -> Dictionary:
	var ch = _chunks.get(c)
	if ch == null:
		ch = {"merge": {}, "inst": {}, "node": null, "on": false}
		_chunks[c] = ch
	return ch


## 能否并进合并网格：三角形、无骨骼/混合形状
static func mergeable(mesh: Mesh) -> bool:
	if mesh == null:
		return false
	if mesh is PrimitiveMesh:
		return true
	if not (mesh is ArrayMesh) or mesh.get_blend_shape_count() > 0:
		return false
	for i in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(i) != Mesh.PRIMITIVE_TRIANGLES or (mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_BONES):
			return false
	return true


## 单个静态网格（xf 为世界变换）；mat 为空时用网格自带的表面材质
func add_mesh(mesh: Mesh, mat: Material, xf: Transform3D, shadow: int) -> void:
	_add_part(_chunk(chunk_of(xf.origin)), mesh, mat, xf, shadow)


func _add_part(ch: Dictionary, mesh: Mesh, mat: Material, xf: Transform3D, shadow: int) -> void:
	for si in mesh.get_surface_count():
		var m: Material = mat if mat else mesh.surface_get_material(si)
		var st := split_tint(m, 2)
		var key := "%d|%d" % [st[0].get_rid().get_id() if st[0] else 0, shadow]
		var g = ch.merge.get(key)
		if g == null:
			g = {"mat": st[0], "shadow": shadow, "tint": 0 if st[0] == m else (2 if st[0] is StandardMaterial3D else 1), "parts": []}
			ch.merge[key] = g
		g.parts.append([mesh, si, xf, st[1]])
		stats.mesh_parts += 1


## 重复小件：一组变换（世界坐标）同网格同材质
func add_inst(mesh: Mesh, mat: Material, xforms: Array, shadow := true) -> void:
	var st := split_tint(mat, 1)
	var tinted: bool = st[0] != mat
	for t: Transform3D in xforms:
		var ch := _chunk(chunk_of(t.origin))
		var key := "%d|%d|%d" % [mesh.get_rid().get_id(), st[0].get_rid().get_id() if st[0] else 0, 1 if shadow else 0]
		var g = ch.inst.get(key)
		if g == null:
			g = {"mesh": mesh, "src": mat, "mat": st[0], "shadow": shadow, "tinted": tinted, "std": st[0] is StandardMaterial3D, "xf": [], "col": []}
			ch.inst[key] = g
		g.xf.append(t)
		g.col.append(st[1])
		stats.inst += 1


## 带底色的单表面副本：补齐 法线/切线/UV/顶点色/索引，保证同组格式一致。
## tint 1（涂装）：顶点色 r 保留边缘遮罩，gba 写底色；tint 2（标准材质）：顶点色整个写反照率色（含透明度）
func _tinted_surface(mesh: Mesh, si: int, col: Color, tint: int) -> ArrayMesh:
	var key := "%d|%d|%d|%s" % [mesh.get_rid().get_id(), si, tint, col.to_html() if tint else "-"]
	var out: ArrayMesh = _tinted.get(key)
	if out:
		return out
	var a: Array = mesh.surface_get_arrays(si)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n := v.size()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	if a[Mesh.ARRAY_NORMAL] != null and a[Mesh.ARRAY_NORMAL].size() == n:
		arr[Mesh.ARRAY_NORMAL] = a[Mesh.ARRAY_NORMAL]
	else:
		var nn := PackedVector3Array()
		nn.resize(n)
		nn.fill(Vector3.UP)
		arr[Mesh.ARRAY_NORMAL] = nn
	if a[Mesh.ARRAY_TANGENT] != null and a[Mesh.ARRAY_TANGENT].size() == n * 4:
		arr[Mesh.ARRAY_TANGENT] = a[Mesh.ARRAY_TANGENT]
	else:
		var tg := PackedFloat32Array()
		for i in n:
			tg.append_array([1.0, 0.0, 0.0, 1.0])
		arr[Mesh.ARRAY_TANGENT] = tg
	if a[Mesh.ARRAY_TEX_UV] != null and a[Mesh.ARRAY_TEX_UV].size() == n:
		arr[Mesh.ARRAY_TEX_UV] = a[Mesh.ARRAY_TEX_UV]
	else:
		var uv := PackedVector2Array()
		uv.resize(n)
		arr[Mesh.ARRAY_TEX_UV] = uv
	var src_c = a[Mesh.ARRAY_COLOR]
	var has_c: bool = src_c != null and src_c.size() == n
	var cc := PackedColorArray()
	if tint == 1:
		cc.resize(n)
		for i in n:
			cc[i] = Color(src_c[i].r if has_c else 1.0, col.r, col.g, col.b)
	elif tint == 2:
		cc.resize(n)
		cc.fill(col)
	elif has_c:
		cc = src_c
	else:
		cc.resize(n)
		cc.fill(Color.WHITE)
	arr[Mesh.ARRAY_COLOR] = cc
	if a[Mesh.ARRAY_INDEX] != null:
		arr[Mesh.ARRAY_INDEX] = a[Mesh.ARRAY_INDEX]
	else:
		var idx := PackedInt32Array()
		idx.resize(n)
		for i in n:
			idx[i] = i
		arr[Mesh.ARRAY_INDEX] = idx
	out = ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_tinted[key] = out
	return out


func _build_chunk(c: Vector2i) -> void:
	var ch: Dictionary = _chunks[c]
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [c.x, c.y]
	add_child(root)
	ch.node = root
	# 实例太少的小件组不值得单独一次 MultiMesh 绘制：并进同材质的合并网格
	for key in ch.inst.keys():
		var g: Dictionary = ch.inst[key]
		if g.xf.size() <= MM_MIN and mergeable(g.mesh) and g.mesh.get_surface_count() == 1:
			var sh := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if g.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for t: Transform3D in g.xf:
				_add_part(ch, g.mesh, g.src, t, sh)
			ch.inst.erase(key)
	for key in ch.merge:
		var g: Dictionary = ch.merge[key]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p: Array in g.parts:
			st.append_from(_tinted_surface(p[0], p[1], p[3], g.tint), 0, p[2])
		var am := st.commit()
		if am == null or am.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.material_override = g.mat
		mi.cast_shadow = g.shadow
		mi.visibility_range_end = VIS_END
		root.add_child(mi)
	for key in ch.inst:
		var g: Dictionary = ch.inst[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = g.tinted and not g.std
		mm.use_colors = g.tinted and g.std
		mm.mesh = g.mesh
		mm.instance_count = g.xf.size()
		var ma: AABB = g.mesh.get_aabb()
		var ab := AABB()
		for i in g.xf.size():
			mm.set_instance_transform(i, g.xf[i])
			if g.tinted and g.std:
				mm.set_instance_color(i, g.col[i])
			elif g.tinted:
				mm.set_instance_custom_data(i, g.col[i])
			var a: AABB = g.xf[i] * ma
			ab = a if i == 0 else ab.merge(a)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = g.mat
		mmi.custom_aabb = ab   # 预先给出包围盒，渲染服务器不必逐实例重算（无界面统计也靠它）
		mmi.visibility_range_end = VIS_END
		if not g.shadow:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	ch.merge = {}
	ch.inst = {}
	stats.built += 1


## 焦点到分块矩形的水平距离
static func _rect_dist(c: Vector2i, f: Vector3) -> float:
	var x0 := c.x * CHUNK
	var z0 := c.y * CHUNK
	var dx := maxf(0.0, maxf(x0 - f.x, f.x - (x0 + CHUNK)))
	var dz := maxf(0.0, maxf(z0 - f.z, f.z - (z0 + CHUNK)))
	return sqrt(dx * dx + dz * dz)


## 按焦点建 / 显示 / 隐藏分块；limit < 0 时不限每帧构建数（开局一次性建好视野内的块）
func update_focus(f: Vector3, r: float, limit := BUILDS_PER_FRAME) -> void:
	var built := 0
	_pending = false
	for c: Vector2i in _chunks:
		var ch: Dictionary = _chunks[c]
		var d := _rect_dist(c, f)
		if d <= r:
			if ch.node == null:
				if limit >= 0 and built >= limit:
					_pending = true
					continue
				_build_chunk(c)
				built += 1
			if not ch.on:
				ch.node.visible = true
				ch.on = true
		elif ch.on and d > r + HYST:
			ch.node.visible = false
			ch.on = false


## 全部建好并显示（整图截图等）
func show_all() -> void:
	update_focus(Vector3.ZERO, 1e9, -1)


var _last_f := Vector3(INF, 0, INF)
var _last_r := 0.0


func _process(_d: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var f := p
	if fwd.y < -0.05:
		f = p + fwd * (-p.y / fwd.y)
	var r := STREAM_R * maxf(1.0, p.distance_to(f) / CAM_DIST_REF)
	if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		r = maxf(r, cam.size * 0.75)
	if _pending or f.distance_squared_to(_last_f) > 4.0 or absf(r - _last_r) > 1.0:
		_last_f = f
		_last_r = r
		update_focus(f, r)
