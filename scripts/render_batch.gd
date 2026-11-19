extends Node3D
## 静态世界的渲染合批 + 分块流式（只管外观；碰撞体、导航网格不经过这里，玩法完全不变）
## - 世界按 CHUNK 米切成方块；每块持有自己的合批网格：
##     · add_mesh：单个静态网格（楼体、路面、墙、道具……）按 材质 + 投影 合并成一个 ArrayMesh（一块一材质一次绘制）
##     · add_inst：重复的小件（窗、碎石、草……）按 网格 + 材质 收成 MultiMesh
## - 写实涂装（mech_paint）只差底色的材质合成同一个「去色」共享材质：底色写进 MultiMesh 实例自定义数据
##   （tint_mode 1）或合并网格的顶点色 gba（tint_mode 2；r 通道仍是倒角边缘遮罩），全图不再每色一份材质
## - 合并网格在烘焙前将每个部件的对象局部米制坐标 (lpos) 与局部法线 (lnrm) 写入 UV / UV2 / CUSTOM0，
##   保证旋转建筑、斜撑钢梁与地标部件合批后三平面砖缝、波纹钢板与窗棂严格对齐，绝不扭曲

const CHUNK := 48.0
const STREAM_R := 70.0
const STREAM_R_FP := 165.0
const STREAM_FWD_FP := 76.0
const HYST := 8.0
const VIS_END := 140.0
const VIS_END_FP_MESH := 280.0
const VIS_END_FP_INST := 165.0
const CAM_DIST_REF := 44.0
const PAINT_PATH := "res://shaders/mech_paint.gdshader"
const PAINT_MOB_PATH := "res://shaders/mech_paint_mobile.gdshader"
const GLASS_PATH := "res://shaders/ind_glass.gdshader"
const FOLIAGE_PATH := "res://shaders/foliage.gdshader"
const FOLIAGE_MOB_PATH := "res://shaders/foliage_mobile.gdshader"
const BUILDS_PER_FRAME := 2
const MM_MIN := 8

static var _tint_mats := {}   ## 去色共享材质：参数（除底色外）+ tint_mode → 材质
static var _tinted := {}      ## 网格 RID|表面|底色 → 带底色顶点色的单表面网格（合并用，按局次缓存）
static var _raw_surfs := {}   ## 网格 RID|表面 → 原始顶点/法线/顶点色/索引数组缓存

var _chunks := {}
var _pending := false
var _fp_vis := false
var _all_shown := false
var stats := {"mesh_parts": 0, "inst": 0, "built": 0}


static func chunk_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))


static func _sp_f(sm: ShaderMaterial, pname: String, def_v: float) -> float:
	var v = sm.get_shader_parameter(pname)
	return float(v) if v != null else def_v


static func _is_paint_shader(m: Material) -> bool:
	if not (m is ShaderMaterial):
		return false
	var sm: ShaderMaterial = m
	if sm.shader == null:
		return false
	var rp: String = sm.shader.resource_path
	return rp == PAINT_PATH or rp == PAINT_MOB_PATH


## 写实涂装材质拆成「去色共享材质 + 底色」，完整保留法线贴图、反照率贴图、面板密度与锈蚀做旧参数
static func split_tint(m: Material, mode: int) -> Array:
	if m is StandardMaterial3D:
		return _split_std(m, mode)
	if not _is_paint_shader(m):
		return [m, Color.WHITE]
	var sm: ShaderMaterial = m
	if int(_sp_f(sm, "tint_mode", 0.0)) >= 2:
		return [m, Color.WHITE]
	var col: Color = sm.get_shader_parameter("base_color")
	var mk := "_tint%d" % mode
	if sm.has_meta(mk):
		return [sm.get_meta(mk), col]
	var use_tex := 1.0 if _sp_f(sm, "use_albedo_tex", 0.0) > 0.5 else 0.0
	var atex = sm.get_shader_parameter("albedo_tex") if use_tex > 0.5 else null
	var ntex = sm.get_shader_parameter("normal_tex")
	var ascale := snappedf(_sp_f(sm, "albedo_tex_scale", 0.24), 0.04) if use_tex > 0.5 else 0.0
	var astr := snappedf(_sp_f(sm, "albedo_tex_strength", 0.78), 0.06) if use_tex > 0.5 else 0.0
	var nstr := snappedf(_sp_f(sm, "normal_strength", 0.55), 0.08)
	var mb := snappedf(_sp_f(sm, "metal_base", 0.15), 0.08)
	var rb := snappedf(clampf(_sp_f(sm, "rough_base", 0.60), 0.12, 0.98), 0.06)
	var ps := snappedf(_sp_f(sm, "panel_scale", 0.0), 0.20)
	var wr := snappedf(_sp_f(sm, "wear", 0.45), 0.12)
	var sc := snappedf(_sp_f(sm, "scratches", 0.25), 0.15)
	var ru := snappedf(_sp_f(sm, "rust", 0.25), 0.12)
	var gr := snappedf(_sp_f(sm, "grime", 0.50), 0.15)
	var du := snappedf(_sp_f(sm, "dust", 0.25), 0.15)
	var ds := snappedf(_sp_f(sm, "detail_scale", 1.0), 0.15)
	var ruv := 1.0 if _sp_f(sm, "roof_uv", 0.0) > 0.5 else 0.0
	var stp := 1.0 if _sp_f(sm, "stripes", 0.0) > 0.5 else 0.0
	var tdmg := 1.0 if _sp_f(sm, "takes_damage", 0.0) > 0.5 else 0.0
	var mw := 1.0 if _sp_f(sm, "metal_wear", 1.0) > 0.5 else 0.0
	var key := "%d|%.0f|%d|%d|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.0f|%.0f|%.0f|%.0f" % [
		mode, use_tex,
		atex.get_instance_id() if atex else 0,
		ntex.get_instance_id() if ntex else 0,
		ascale, astr, nstr, mb, rb, ps, wr, sc, ru, gr, du, ds, ruv, stp, tdmg, mw
	]
	var out: ShaderMaterial = _tint_mats.get(key)
	if out == null:
		out = sm.duplicate()
		out.set_shader_parameter("base_color", Color.WHITE)
		out.set_shader_parameter("tint_mode", mode)
		out.set_shader_parameter("metal_base", mb)
		out.set_shader_parameter("rough_base", rb)
		out.set_shader_parameter("panel_scale", ps)
		out.set_shader_parameter("wear", wr)
		out.set_shader_parameter("scratches", sc)
		out.set_shader_parameter("rust", ru)
		out.set_shader_parameter("grime", gr)
		out.set_shader_parameter("dust", du)
		out.set_shader_parameter("normal_strength", nstr)
		_tint_mats[key] = out
	sm.set_meta(mk, out)
	return [out, col]


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
		out.vertex_color_is_srgb = true
		_tint_mats[key] = out
	m.set_meta(mk, out)
	return [out, m.albedo_color]


static func _uses_local_triplanar(m: Material) -> bool:
	if not (m is ShaderMaterial):
		return false
	var sm: ShaderMaterial = m
	if sm.shader == null:
		return false
	var rp: String = sm.shader.resource_path
	return rp == PAINT_PATH or rp == PAINT_MOB_PATH or rp == GLASS_PATH


static func _is_foliage(m: Material) -> bool:
	if not (m is ShaderMaterial):
		return false
	var sm: ShaderMaterial = m
	if sm.shader == null:
		return false
	var rp: String = sm.shader.resource_path
	return rp == FOLIAGE_PATH or rp == FOLIAGE_MOB_PATH


func _chunk(c: Vector2i) -> Dictionary:
	var ch = _chunks.get(c)
	if ch == null:
		ch = {"merge": {}, "inst": {}, "node": null, "on": false}
		_chunks[c] = ch
	return ch


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


func add_mesh(mesh: Mesh, mat: Material, xf: Transform3D, shadow: int) -> void:
	var p: Vector3 = (xf * mesh.get_aabb()).get_center() if mesh else xf.origin
	_add_part(_chunk(chunk_of(p)), mesh, mat, xf, shadow)


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


func add_inst(mesh: Mesh, mat: Material, xforms: Array, shadow := true) -> void:
	var mob := OS.has_feature("mobile") or RenderingServer.get_current_rendering_method() == "mobile"
	var use_sh := shadow
	var step_n := 1
	if mob:
		if _is_foliage(mat):
			if not shadow:
				step_n = 2
			# 保留乔木树冠投影，防止低画质下林木与地面脱离发飘
		elif GameData.quality == 0 and mesh != null:
			var ms := mesh.get_aabb().size
			if maxf(ms.x, maxf(ms.y, ms.z)) < 0.55:
				use_sh = false
	var st := split_tint(mat, 1)
	var tinted: bool = st[0] != mat
	for idx in range(0, xforms.size(), step_n):
		var t: Transform3D = xforms[idx]
		var ch := _chunk(chunk_of(t.origin))
		var key := "%d|%d|%d" % [mesh.get_rid().get_id(), st[0].get_rid().get_id() if st[0] else 0, 1 if use_sh else 0]
		var g = ch.inst.get(key)
		if g == null:
			g = {"mesh": mesh, "src": [], "mat": st[0], "shadow": use_sh, "tinted": tinted, "std": st[0] is StandardMaterial3D, "xf": [], "col": []}
			ch.inst[key] = g
		g.src.append(mat)
		g.xf.append(t)
		g.col.append(st[1])
		stats.inst += 1


static func _get_raw_surf(mesh: Mesh, si: int) -> Array:
	var key := "%d|%d" % [mesh.get_rid().get_id(), si]
	var cached = _raw_surfs.get(key)
	if cached != null:
		return cached
	var a: Array = mesh.surface_get_arrays(si)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n := v.size()
	var nrm: PackedVector3Array
	if a[Mesh.ARRAY_NORMAL] != null and a[Mesh.ARRAY_NORMAL].size() == n:
		nrm = a[Mesh.ARRAY_NORMAL]
	else:
		nrm = PackedVector3Array()
		nrm.resize(n)
		nrm.fill(Vector3.UP)
	var col: PackedColorArray
	if a[Mesh.ARRAY_COLOR] != null and a[Mesh.ARRAY_COLOR].size() == n:
		col = a[Mesh.ARRAY_COLOR]
	else:
		col = PackedColorArray()
		col.resize(n)
		col.fill(Color.WHITE)
	var idx: PackedInt32Array
	if a[Mesh.ARRAY_INDEX] != null and a[Mesh.ARRAY_INDEX].size() > 0:
		idx = a[Mesh.ARRAY_INDEX]
	else:
		idx = PackedInt32Array()
		idx.resize(n)
		for i in n:
			idx[i] = i
	cached = [v, nrm, col, idx]
	_raw_surfs[key] = cached
	return cached


## 为三平面涂装与窗格着色器合批网格，并在 UV / UV2 / CUSTOM0 中保留每个部件独立的对象局部米制坐标与法线
static func _merge_local_triplanar(parts: Array, tint: int) -> ArrayMesh:
	var total_v := 0
	var total_i := 0
	for p: Array in parts:
		var raw := _get_raw_surf(p[0], p[1])
		total_v += (raw[0] as PackedVector3Array).size()
		total_i += (raw[3] as PackedInt32Array).size()
	if total_v == 0 or total_i == 0:
		return null
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_uv := PackedVector2Array()
	var out_uv2 := PackedVector2Array()
	var out_c0 := PackedFloat32Array()
	var out_c1 := PackedFloat32Array()
	var out_col := PackedColorArray()
	var out_idx := PackedInt32Array()
	out_v.resize(total_v)
	out_n.resize(total_v)
	out_uv.resize(total_v)
	out_uv2.resize(total_v)
	out_c0.resize(total_v * 4)
	out_c1.resize(total_v * 4)
	out_col.resize(total_v)
	out_idx.resize(total_i)

	var vo := 0
	var io := 0
	for p: Array in parts:
		var raw := _get_raw_surf(p[0], p[1])
		var sv: PackedVector3Array = raw[0]
		var sn: PackedVector3Array = raw[1]
		var sc: PackedColorArray = raw[2]
		var si_arr: PackedInt32Array = raw[3]
		var xf: Transform3D = p[2]
		var col: Color = p[3]
		var bx := xf.basis.x
		var by := xf.basis.y
		var bz := xf.basis.z
		var sx := maxf(bx.length(), 1e-4)
		var sy := maxf(by.length(), 1e-4)
		var sz := maxf(bz.length(), 1e-4)
		var inv_t := xf.basis.inverse().transposed()
		var flip := xf.basis.determinant() < 0.0
		var flip_s := -1.0 if flip else 1.0
		var q := Basis((bx / sx).normalized(), (by / sy).normalized(), ((bz / sz) * flip_s).normalized()).orthonormalized().get_rotation_quaternion()
		var c0_w := 2.0 if flip else 1.0
		var box_ext := maxf(sx, sz) * 0.5
		var nv := sv.size()
		for i in nv:
			var vi := vo + i
			var v := sv[i]
			var n := sn[i]
			out_v[vi] = xf * v
			out_n[vi] = (inv_t * n).normalized()
			var lpos := Vector3(v.x * sx, v.y * sy, v.z * sz)
			var lnrm := Vector3(n.x / sx, n.y / sy, n.z / sz).normalized()
			out_uv[vi] = Vector2(lpos.x, lpos.y)
			out_uv2[vi] = Vector2(lpos.z, box_ext)
			var c4 := vi * 4
			out_c0[c4] = lnrm.x
			out_c0[c4 + 1] = lnrm.y
			out_c0[c4 + 2] = lnrm.z
			out_c0[c4 + 3] = c0_w
			out_c1[c4] = q.x
			out_c1[c4 + 1] = q.y
			out_c1[c4 + 2] = q.z
			out_c1[c4 + 3] = q.w
			if tint == 1:
				out_col[vi] = Color(sc[i].r, col.r, col.g, col.b)
			elif tint == 2:
				out_col[vi] = col
			else:
				out_col[vi] = sc[i]
		var ni := si_arr.size()
		if flip:
			var k := 0
			while k + 2 < ni:
				out_idx[io + k] = vo + si_arr[k]
				out_idx[io + k + 1] = vo + si_arr[k + 2]
				out_idx[io + k + 2] = vo + si_arr[k + 1]
				k += 3
		else:
			for k in ni:
				out_idx[io + k] = vo + si_arr[k]
		vo += nv
		io += ni

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = out_v
	arr[Mesh.ARRAY_NORMAL] = out_n
	arr[Mesh.ARRAY_TEX_UV] = out_uv
	arr[Mesh.ARRAY_TEX_UV2] = out_uv2
	arr[Mesh.ARRAY_CUSTOM0] = out_c0
	arr[Mesh.ARRAY_CUSTOM1] = out_c1
	arr[Mesh.ARRAY_COLOR] = out_col
	arr[Mesh.ARRAY_INDEX] = out_idx
	var am := ArrayMesh.new()
	var fmt := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, fmt)
	return am


static func _tinted_surface(mesh: Mesh, si: int, col: Color, tint: int) -> ArrayMesh:
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
		tg.resize(n * 4)
		for i in n:
			tg[i * 4] = 1.0
			tg[i * 4 + 3] = 1.0
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
		if has_c:
			for i in n:
				cc[i] = Color(src_c[i].r, col.r, col.g, col.b)
		else:
			cc.fill(Color(1.0, col.r, col.g, col.b))
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


static func _vis_end_mesh(fp: bool) -> float:
	var mob := OS.has_feature("mobile") or RenderingServer.get_current_rendering_method() == "mobile"
	if mob:
		if fp:
			return 185.0 if GameData.quality == 0 else 220.0
		return 125.0 if GameData.quality == 0 else 135.0
	return VIS_END_FP_MESH if fp else VIS_END


static func _vis_end_inst(fp: bool) -> float:
	var mob := OS.has_feature("mobile") or RenderingServer.get_current_rendering_method() == "mobile"
	if mob:
		if fp:
			return 110.0 if GameData.quality == 0 else 135.0
		return 96.0 if GameData.quality == 0 else 112.0
	return VIS_END_FP_INST if fp else VIS_END


func _build_chunk(c: Vector2i) -> void:
	var ch: Dictionary = _chunks[c]
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [c.x, c.y]
	add_child(root)
	ch.node = root
	# 实例很少的组直接并进同材质的合并网格（植物材质保留在 MultiMesh 以维持统一摆风尺度与独立世界原点）
	for key in ch.inst.keys():
		var g: Dictionary = ch.inst[key]
		if g.xf.size() <= MM_MIN and not _is_foliage(g.mat) and not (g.mesh != null and g.mesh.has_meta("prefab_inst")) and mergeable(g.mesh) and g.mesh.get_surface_count() == 1:
			var sh := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if g.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for i in g.xf.size():
				_add_part(ch, g.mesh, g.src[i], g.xf[i], sh)
			ch.inst.erase(key)
	for key in ch.merge:
		var g: Dictionary = ch.merge[key]
		var am: ArrayMesh = null
		if _uses_local_triplanar(g.mat):
			am = _merge_local_triplanar(g.parts, g.tint)
		else:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for p: Array in g.parts:
				st.append_from(_tinted_surface(p[0], p[1], p[3], g.tint), 0, p[2])
			am = st.commit()
		if am == null or am.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.material_override = g.mat
		mi.cast_shadow = g.shadow
		mi.visibility_range_end = 0.0 if _all_shown else _vis_end_mesh(_fp_vis)
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
		mmi.custom_aabb = ab
		mmi.visibility_range_end = 0.0 if _all_shown else _vis_end_inst(_fp_vis)
		if not g.shadow:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	ch.merge = {}
	ch.inst = {}
	stats.built += 1


func build_all(f: Vector3, r: float) -> void:
	for c: Vector2i in _chunks:
		var ch: Dictionary = _chunks[c]
		if ch.node == null:
			_build_chunk(c)
		var vis := _rect_dist(c, f) <= r
		ch.node.visible = vis
		ch.on = vis
	_tinted.clear()
	_raw_surfs.clear()


static func _rect_dist(c: Vector2i, f: Vector3) -> float:
	var x0 := c.x * CHUNK
	var z0 := c.y * CHUNK
	var dx := maxf(0.0, maxf(x0 - f.x, f.x - (x0 + CHUNK)))
	var dz := maxf(0.0, maxf(z0 - f.z, f.z - (z0 + CHUNK)))
	return sqrt(dx * dx + dz * dz)


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
	if built > 0:
		_tinted.clear()
		_raw_surfs.clear()


func show_all() -> void:
	_all_shown = true
	update_focus(Vector3.ZERO, 1e9, -1)
	for c: Vector2i in _chunks:
		var n: Node3D = _chunks[c].node
		if n:
			for ch in n.get_children():
				if ch is GeometryInstance3D:
					ch.visibility_range_end = 0.0


func _apply_vis_mode(fp: bool) -> void:
	if _fp_vis == fp:
		return
	_fp_vis = fp
	if _all_shown:
		return
	for c: Vector2i in _chunks:
		var n: Node3D = _chunks[c].node
		if n == null:
			continue
		for ch in n.get_children():
			if ch is MultiMeshInstance3D:
				ch.visibility_range_end = _vis_end_inst(fp)
			elif ch is GeometryInstance3D:
				ch.visibility_range_end = _vis_end_mesh(fp)


var _last_f := Vector3(INF, 0, INF)
var _last_r := 0.0


func _process(_d: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var f := p
	var r := STREAM_R
	var mob := OS.has_feature("mobile") or RenderingServer.get_current_rendering_method() == "mobile"
	var horiz_view := fwd.y >= -0.25 and cam.projection != Camera3D.PROJECTION_ORTHOGONAL
	_apply_vis_mode(horiz_view)
	if horiz_view:
		var f_xz := Vector3(fwd.x, 0.0, fwd.z)
		f_xz = f_xz.normalized() if f_xz.length_squared() > 0.001 else Vector3.FORWARD
		var mob_s := (0.78 if GameData.quality == 0 else 0.88) if mob else 1.0
		f = p + f_xz * (STREAM_FWD_FP * mob_s)
		r = STREAM_R_FP * mob_s
	else:
		if fwd.y < -0.05:
			f = p + fwd * (-p.y / fwd.y)
		var mob_s := (0.94 if GameData.quality == 0 else 1.0) if mob else 1.0
		r = STREAM_R * mob_s * maxf(1.0, p.distance_to(f) / CAM_DIST_REF)
		if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
			r = maxf(r, cam.size * 0.75)
	if _pending or f.distance_squared_to(_last_f) > 4.0 or absf(r - _last_r) > 1.0:
		_last_f = f
		_last_r = r
		update_focus(f, r)
