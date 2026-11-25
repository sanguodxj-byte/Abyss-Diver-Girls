extends StaticBody3D
## 可搜索容器。打开时逐件“摸”出物品（塔科夫式搜索延迟）。
## 外观与废墟同一套材质：褪色漆面、锈蚀、沙尘、半埋进沙土，周围有碎石。
## 不再有地面光圈和状态灯——只有机甲靠近时才出现一圈细微的橙色描边提示。

const A = preload("res://scripts/art.gd")
const RB = preload("res://scripts/render_batch.gd")

const STYLE := {
	"supply": {"size": Vector3(1.5, 0.95, 1.1)},
	"tool": {"size": Vector3(1.3, 0.8, 0.75)},
	"military": {"size": Vector3(1.9, 0.9, 1.0)},
	"safe": {"size": Vector3(1.0, 1.25, 1.0)},
	"bug": {"size": Vector3(1.6, 0.6, 1.6)},
	"nest": {"size": Vector3(1.6, 0.6, 1.6)},
	"ammo": {"size": Vector3(1.0, 0.55, 0.7)},
	"med": {"size": Vector3(1.1, 0.62, 0.8)},
	"tech": {"size": Vector3(1.4, 0.75, 0.85)},
	"register": {"size": Vector3(0.7, 1.05, 0.6)},
	"weapon": {"size": Vector3(1.8, 0.7, 0.5)},
	"car_wreck": {"size": Vector3(2.6, 1.0, 1.35)},
	"container": {"size": Vector3(3.4, 1.5, 1.5)},
	"cache": {"size": Vector3(0.7, 0.55, 0.7)},
}

var kind := "supply"
var tier := 1
var title := ""
var items: Array = []
var revealed := 0
var reveal_t := 0.0
var near := false
var _meshes: Array = []
var _rng := RandomNumberGenerator.new()
static var _hl_mat: ShaderMaterial
static var _hl_mesh_cache := {}
static var _worn_cache := {}


## 环境同款的做旧漆面
static func _worn(c: Color, metal := 0.1, rust := 0.25) -> ShaderMaterial:
	var key := "%s|%.2f|%.2f" % [c.to_html(false), metal, rust]
	var m: ShaderMaterial = _worn_cache.get(key)
	if m == null:
		m = A.paint(c, metal, 0.82, {"wear": 0.65, "dust": 0.55, "dust_color": Color(0.45, 0.4, 0.33), "grime": 0.75,
			"rust": rust, "rust_color": Color(0.27, 0.15, 0.08), "scratches": 0.35, "bare_metal": c.lightened(0.35), "panel_scale": 0.0})
		_worn_cache[key] = m
	return m


func _m(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, hl := true) -> MeshInstance3D:
	var mi := A.add(self, mesh, mat, pos, rot, scl)
	if hl:
		_meshes.append(mi)
	return mi


func setup(k: String, loot: Array, tier := 1) -> void:
	kind = k
	self.tier = tier
	title = GameData.loot_title(k, tier)
	items = loot
	add_to_group("lootboxes")
	_rng.seed = hash(str(position) + k)
	var sz: Vector3 = STYLE[k].size
	var sink := 0.12   # 半埋进沙土
	if k == "bug" or k == "nest":
		collision_layer = 0
		collision_mask = 0
		var wv: int = _rng.randi() % 3
		var wkey := "_wreck_%d" % wv
		var rot_y := _rng.randf() * TAU
		var blob := A.ground_vfx(self, A.blob_tex(), Color(0.04, 0.04, 0.045, 0.82), sz.x * 1.85, Vector3(0, 0.036, 0), false, 0.34, false, 1)
		blob.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		blob.visibility_range_end = 56.0
		blob.visibility_range_end_margin = 4.0
		blob.set_meta("keep_unmerged", true)
		if _hl_mesh_cache.has(wkey):
			var cached_w := MeshInstance3D.new()
			cached_w.mesh = _hl_mesh_cache[wkey]
			cached_w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cached_w.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			cached_w.visibility_range_end = 100.0 if A.is_mobile_perf() else 165.0
			cached_w.visibility_range_end_margin = 8.0
			cached_w.rotation.y = rot_y
			add_child(cached_w)
			_meshes = [cached_w]
			batch_ready = true
			return
		_rng.seed = 4099 + wv * 977
		_build_wreck(sz)
		_batch_loot_meshes(null, wkey, "", rot_y)
		return
	collision_layer = 1
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = sz
	cs.shape = sh
	cs.position.y = sz.y * 0.5 - sink
	add_child(cs)
	var rkey := "_rubble_%s_%d" % [k, _rng.randi() % 3]
	if _hl_mesh_cache.has(k) and _hl_mesh_cache.has(rkey):
		_add_contact_shadow(sz)
		var cached_mi := MeshInstance3D.new()
		cached_mi.mesh = _hl_mesh_cache[k]
		cached_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cached_mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		cached_mi.visibility_range_end = 100.0 if A.is_mobile_perf() else 165.0
		cached_mi.visibility_range_end_margin = 8.0
		add_child(cached_mi)
		_meshes = [cached_mi]
		var rub_mesh: Mesh = _hl_mesh_cache[rkey]
		if rub_mesh != null:
			var rub_mi := MeshInstance3D.new()
			rub_mi.mesh = rub_mesh
			rub_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			rub_mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			rub_mi.visibility_range_end = 56.0
			rub_mi.visibility_range_end_margin = 4.0
			add_child(rub_mi)
		batch_ready = true
		return
	match k:
		"supply": _build_supply(sz, sink)
		"tool": _build_tool(sz, sink)
		"military": _build_military(sz, sink)
		"safe": _build_safe(sz, sink)
		"ammo": _build_ammo(sz, sink)
		"med": _build_med(sz, sink)
		"tech": _build_tech(sz, sink)
		"register": _build_register(sz, sink)
		"weapon": _build_weapon(sz, sink)
		"car_wreck": _build_car(sz, sink)
		"container": _build_container(sz, sink)
		"cache": _build_cache(sz, sink)
	_sand_and_rubble(sz)
	_batch_loot_meshes(null, k, rkey)


func _rel_xf(n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != self:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


var batch_ready := false


func _batch_loot_meshes(tree: SceneTree = null, ckey_override := "", rkey_override := "", main_rot_y := 0.0) -> void:
	var hl_set := {}
	for mi in _meshes:
		if is_instance_valid(mi):
			hl_set[mi.get_instance_id()] = true
	var other_list: Array = []
	var bodies: Array = []
	for n in find_children("*", "", true, false):
		if n is MeshInstance3D:
			if n.has_meta("keep_unmerged"):
				continue
			if not hl_set.has(n.get_instance_id()):
				other_list.append(n)
		elif n is Label3D:
			var lxf := _rel_xf(n)
			if n.get_parent() != self:
				n.get_parent().remove_child(n)
				add_child(n)
				n.transform = lxf
			n.visibility_range_end = 45.0
			n.visibility_range_end_margin = 4.0
		elif n is Node3D and n.get_class() == "Node3D":
			bodies.append(n)
	var ckey := ckey_override if ckey_override != "" else (kind if (kind != "bug" and kind != "nest") else "")
	_meshes = await _merge_mesh_group(_meshes, ckey, tree, false, main_rot_y)
	var rkey := rkey_override if rkey_override != "" else (("_rubble_%s_%d" % [kind, _rng.randi() % 3]) if (ckey != "" and kind != "bug" and kind != "nest") else "")
	await _merge_mesh_group(other_list, rkey, tree, true, 0.0)
	for b in bodies:
		if is_instance_valid(b) and b.get_child_count() == 0:
			if b.get_parent():
				b.get_parent().remove_child(b)
			b.free()
	batch_ready = true
	if near:
		near = false
		set_near(true)


func _casts_box_shadow() -> bool:
	return false


func _merge_mesh_group(list: Array, cache_key: String, tree: SceneTree = null, force_no_shadow := false, rot_y := 0.0) -> Array:
	var mob_lb := A.is_mobile_perf()
	var vis_end := (50.0 if mob_lb else 68.0) if force_no_shadow else (100.0 if mob_lb else 165.0)
	var vis_margin := 4.0 if force_no_shadow else 8.0
	var deadline := Time.get_ticks_usec() + 1000
	if cache_key != "" and _hl_mesh_cache.has(cache_key):
		for mi in list:
			if is_instance_valid(mi):
				if mi.get_parent():
					mi.get_parent().remove_child(mi)
				mi.free()
		var cached_mesh: Mesh = _hl_mesh_cache[cache_key]
		if cached_mesh == null:
			return []
		var cached_mi := MeshInstance3D.new()
		cached_mi.mesh = cached_mesh
		cached_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cached_mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		cached_mi.visibility_range_end = vis_end
		cached_mi.visibility_range_end_margin = vis_margin
		if rot_y != 0.0:
			cached_mi.rotation.y = rot_y
		add_child(cached_mi)
		return [cached_mi]
	var by_sh := {}
	for mi in list:
		if not is_instance_valid(mi) or mi.mesh == null:
			continue
		var sk := int(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		if not by_sh.has(sk):
			by_sh[sk] = []
		by_sh[sk].append(mi)
	var result: Array = []
	for sk in by_sh:
		var grp: Array = by_sh[sk]
		if grp.size() == 1 and cache_key == "":
			var single: MeshInstance3D = grp[0]
			if single.get_parent() != self:
				var sxf := _rel_xf(single)
				single.get_parent().remove_child(single)
				add_child(single)
				single.transform = sxf
			single.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			single.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			single.visibility_range_end = vis_end
			single.visibility_range_end_margin = vis_margin
			result.append(single)
			continue
		var buckets := {}
		var mats := {}
		for mi: MeshInstance3D in grp:
			var xf := _rel_xf(mi)
			var m: Mesh = mi.mesh
			for s in m.get_surface_count():
				var raw_mat: Material = mi.get_surface_override_material(s)
				if raw_mat == null:
					raw_mat = mi.material_override
				if raw_mat == null:
					raw_mat = m.surface_get_material(s)
				var sp := RB.split_tint(raw_mat, 3)
				var mat: Material = sp[0]
				var tint_col: Color = sp[1]
				var tint_mode := 0 if mat == raw_mat else (2 if mat is StandardMaterial3D else 1)
				var key := mat.get_instance_id() if mat != null else 0
				if not buckets.has(key):
					buckets[key] = []
					mats[key] = mat
				buckets[key].append([m, s, xf, tint_col, tint_mode])
		if buckets.is_empty():
			continue
		var am := ArrayMesh.new()
		for key in buckets:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for item in buckets[key]:
				st.append_from(RB._tinted_surface(item[0], item[1], item[3], item[4]), 0, item[2])
				if tree != null and Time.get_ticks_usec() >= deadline:
					await tree.process_frame
					deadline = Time.get_ticks_usec() + 1000
			st.index()
			st.commit(am)
			if mats[key] != null:
				am.surface_set_material(am.get_surface_count() - 1, mats[key])
		if cache_key != "":
			_hl_mesh_cache[cache_key] = am
		var merged := MeshInstance3D.new()
		merged.mesh = am
		merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		merged.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		merged.visibility_range_end = vis_end
		merged.visibility_range_end_margin = vis_margin
		if rot_y != 0.0:
			merged.rotation.y = rot_y
		add_child(merged)
		result.append(merged)
		# 原外观保持可见、可搜刮，完整合批后在同一帧替换，不延迟掉落物出现。
		for mi: MeshInstance3D in grp:
			if mi.get_parent(): mi.get_parent().remove_child(mi)
			mi.free()
	if result.is_empty() and cache_key != "" and not _hl_mesh_cache.has(cache_key):
		_hl_mesh_cache[cache_key] = null
	return result


func _add_contact_shadow(sz: Vector3) -> void:
	var sh := MeshInstance3D.new()
	sh.mesh = A.quad(sz.x * 1.58, sz.z * 1.58)
	sh.material_override = A.contact_shadow_mat(0.56)
	sh.position = Vector3(0.0, 0.024, 0.0)
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	sh.visibility_range_end = 56.0
	sh.visibility_range_end_margin = 4.0
	sh.set_meta("keep_unmerged", true)
	add_child(sh)


## 底部柔和接地阴影枕垫 + 雕塑碎岩砾石（让每只物资箱稳稳压在地面上，告别旧版方砖碎石）
func _sand_and_rubble(sz: Vector3) -> void:
	_add_contact_shadow(sz)
	var R1 := A.rock_mat(Color(0.46, 0.43, 0.39))
	var R2 := A.rock_mat(Color(0.34, 0.32, 0.30))
	for i in 4:
		var a := _rng.randf() * TAU
		var d: float = _rng.randf_range(0.66, 1.04) * max(sz.x, sz.z) * 0.56
		var s := _rng.randf_range(0.09, 0.17)
		_m(A.rock_mesh_low(_rng.randi() % 12), R1 if i % 2 == 0 else R2,
			Vector3(cos(a) * d, s * 0.18, sin(a) * d),
			Vector3(_rng.randf_range(-18.0, 18.0), _rng.randf() * 360.0, _rng.randf_range(-18.0, 18.0)),
			Vector3(s * 1.35, s * 0.58, s * 1.12), false)


## 补给箱：防腐垫木叉车托盘底座 + 两只叠放的军规加强筋塑钢周转箱 + 金属搭扣/角护件 + 折叠帆布 + 棘轮捆扎带
func _build_supply(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.42, 0.41, 0.34), 0.04, 0.14)
	var M2 := _worn(Color(0.34, 0.32, 0.26), 0.08, 0.18)
	var MD := _worn(Color(0.17, 0.18, 0.18), 0.62, 0.48)
	var MB := _worn(Color(0.54, 0.44, 0.22), 0.78, 0.34)
	var MPAL := _worn(Color(0.35, 0.26, 0.17), 0.0, 0.05)
	var pal_h := 0.11
	for px_s in [-0.42, 0.0, 0.42]:
		_m(A.bevel_box(Vector3(0.12, 0.075, sz.z + 0.08), 0.012), MPAL, Vector3(px_s * sz.x, 0.04 - sink * 0.5, 0))
	for pz_s in [-0.38, -0.13, 0.13, 0.38]:
		_m(A.bevel_box(Vector3(sz.x + 0.08, 0.032, 0.16), 0.008), MPAL, Vector3(0, 0.09 - sink * 0.5, pz_s * sz.z))
	var h1 := sz.y * 0.52
	var y0 := pal_h - sink
	_m(A.bevel_box(Vector3(sz.x, h1, sz.z), 0.045), M, Vector3(0, y0 + h1 * 0.5, 0))
	_m(A.bevel_box(Vector3(sz.x + 0.05, 0.065, sz.z + 0.05), 0.014), M2, Vector3(0, y0 + h1 * 0.88, 0))
	# 四角包钢防撞角件 + 侧面压筋与钢丝折叠提把
	for sx_c in [-1.0, 1.0]:
		for sz_c in [-1.0, 1.0]:
			_m(A.bevel_box(Vector3(0.12, h1 * 0.96, 0.12), 0.014), MD, Vector3(sx_c * (sz.x * 0.5 - 0.03), y0 + h1 * 0.5, sz_c * (sz.z * 0.5 - 0.03)))
	for rx in [-0.28, 0.0, 0.28]:
		_m(A.bevel_box(Vector3(0.042, h1 * 0.72, sz.z + 0.032), 0.008), M2, Vector3(rx * sz.x, y0 + h1 * 0.46, 0))
	for sx in [-1.0, 1.0]:
		_m(A.bevel_box(Vector3(0.055, h1 * 0.52, sz.z * 0.68), 0.01), M2, Vector3(sx * sz.x * 0.5, y0 + h1 * 0.55, 0))
		_m(A.bevel_box(Vector3(0.06, 0.08, 0.28), 0.008), MD, Vector3(sx * (sz.x * 0.5 + 0.025), y0 + h1 * 0.72, 0))
		_m(A.tube([Vector3(sx * (sz.x * 0.5 + 0.03), y0 + h1 * 0.72, -0.11), Vector3(sx * (sz.x * 0.5 + 0.08), y0 + h1 * 0.66, -0.11),
			Vector3(sx * (sz.x * 0.5 + 0.08), y0 + h1 * 0.66, 0.11), Vector3(sx * (sz.x * 0.5 + 0.03), y0 + h1 * 0.72, 0.11)], 0.013, 14, 6), MD, Vector3.ZERO)
	# 上层副箱 + 金属搭扣 + 警示编码带
	var h2 := sz.y * 0.40
	var top_b := Node3D.new()
	add_child(top_b)
	top_b.position = Vector3(-sz.x * 0.1, y0 + h1 + h2 * 0.5, 0.04)
	top_b.rotation_degrees = Vector3(0, 8, 0)
	_meshes.append(A.add(top_b, A.bevel_box(Vector3(sz.x * 0.72, h2, sz.z * 0.85), 0.042), M2, Vector3.ZERO))
	_meshes.append(A.add(top_b, A.bevel_box(Vector3(sz.x * 0.76, 0.05, sz.z * 0.89), 0.012), MD, Vector3(0, h2 * 0.36, 0)))
	for lx in [-0.22, 0.22]:
		_meshes.append(A.add(top_b, A.bevel_box(Vector3(0.065, 0.11, 0.038), 0.006), MB, Vector3(lx * sz.x, h2 * 0.24, -sz.z * 0.44)))
	# 折叠旧帆布（多层褶皱压角）
	var T := _worn(Color(0.30, 0.29, 0.23), 0.0, 0.0)
	_m(A.bevel_box(Vector3(sz.x * 0.84, 0.038, sz.z * 0.96), 0.014), T, Vector3(-sz.x * 0.07, y0 + h1 + h2 + 0.022, 0.0), Vector3(0, 8, -4))
	_m(A.bevel_box(Vector3(0.038, h2 * 1.45, sz.z * 0.92), 0.012), T, Vector3(sz.x * 0.29, y0 + h1 + h2 * 0.34, 0.0), Vector3(0, 8, -12))
	_m(A.bevel_box(Vector3(sz.x * 0.76, h2 * 0.76, 0.034), 0.012), T, Vector3(-sz.x * 0.06, y0 + h1 + h2 * 0.62, sz.z * 0.46), Vector3(10, 8, 0))
	# 双道棘轮紧固捆扎带 + 黄铜棘轮扣
	var S := _worn(Color(0.18, 0.18, 0.16), 0.35, 0.3)
	for sx in [-0.30, 0.25]:
		_m(A.bevel_box(Vector3(0.055, sz.y + 0.07, sz.z + 0.06), 0.006), S, Vector3(sx * sz.x, (sz.y + pal_h) * 0.5 - sink, 0))
		_m(A.bevel_box(Vector3(0.095, 0.12, 0.058), 0.01), MB, Vector3(sx * sz.x, y0 + h1 * 0.68, -sz.z * 0.5 - 0.028))
		_m(A.cyl(0.016, 0.09, 0.016, 16), MD, Vector3(sx * sz.x, y0 + h1 * 0.68, -sz.z * 0.5 - 0.052), Vector3(0, 0, 90))


## 工具箱：倾倒的重型车间滚轮钢制工具柜，带万向脚轮、防滑围边托盘、圆管推手、滑轨抽屉与成型撬棍/扳手/套筒盒
func _build_tool(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.44, 0.22, 0.14), 0.54, 0.70)
	var MD := _worn(Color(0.14, 0.145, 0.155), 0.70, 0.50)
	var MC := _worn(Color(0.56, 0.57, 0.55), 0.86, 0.24)
	var body := Node3D.new()
	add_child(body)
	body.rotation_degrees = Vector3(0, 0, -6)
	var by := sz.y * 0.5 - sink + 0.05
	_meshes.append(A.add(body, A.bevel_box(sz, 0.032), M, Vector3(0, by, 0)))
	# 底部四只工业万向轮与轮叉
	for wx in [-0.40, 0.40]:
		for wz in [-0.36, 0.36]:
			var wp := Vector3(wx * sz.x, 0.06 - sink, wz * sz.z)
			_meshes.append(A.add(body, A.bevel_box(Vector3(0.09, 0.06, 0.09), 0.008), MD, wp + Vector3(0, 0.04, 0)))
			_meshes.append(A.add(body, A.cyl(0.058, 0.042, 0.058, 18), MD, wp, Vector3(90, 0, 0)))
			_meshes.append(A.add(body, A.cyl(0.028, 0.048, 0.028, 16), MC, wp, Vector3(90, 0, 0)))
	for sx: float in [-1.0, 1.0]:
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.042, sz.y * 0.98, 0.068), 0.008), MD, Vector3(sx * (sz.x * 0.5 - 0.01), by, -sz.z * 0.46)))
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.042, sz.y * 0.98, 0.068), 0.008), MD, Vector3(sx * (sz.x * 0.5 - 0.01), by, sz.z * 0.46)))
		# 一体弯管推车扶手（高分段无折棱）
		var hx := sx * (sz.x * 0.5 + 0.02)
		var hy := sz.y * 0.78 - sink + 0.05
		_meshes.append(A.add(body, A.tube([Vector3(hx, hy, -sz.z * 0.30), Vector3(hx + sx * 0.08, hy, -sz.z * 0.30),
			Vector3(hx + sx * 0.08, hy, sz.z * 0.30), Vector3(hx, hy, sz.z * 0.30)], 0.020, 16, 8), MC, Vector3.ZERO))
	# 三层滑轨抽屉（中层半拉出，露出抽屉内隔槽与镀铬拉条、钥匙锁芯）
	for i in 3:
		var y := sz.y * (0.24 + i * 0.25) - sink + 0.05
		var out := 0.20 if i == 1 else 0.0
		_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.88, sz.y * 0.20, 0.055), 0.010), M, Vector3(0, y, -sz.z * 0.5 - 0.02 - out)))
		_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.72, 0.032, 0.046), 0.007), MC, Vector3(0, y + 0.026, -sz.z * 0.5 - 0.055 - out)))
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.20, 0.048, 0.016), 0.003), MD, Vector3(sz.x * 0.26, y - 0.028, -sz.z * 0.5 - 0.048 - out)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.84, 0.09, 0.22), 0.008), MD, Vector3(0, sz.y * 0.48 - sink + 0.05, -sz.z * 0.5 - 0.10)))
	_meshes.append(A.add(body, A.cyl(0.022, 0.03, 0.022, 16), MC, Vector3(0.0, sz.y * 0.90 - sink + 0.05, -sz.z * 0.5 - 0.018), Vector3(90, 0, 0)))
	# 顶部防滑橡胶垫 + 三面挡边
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x + 0.04, 0.055, sz.z + 0.04), 0.012), MD, Vector3(0, sz.y - sink + 0.05, 0)))
	for edge_x in [-1.0, 1.0]:
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.038, 0.055, sz.z + 0.04), 0.006), M, Vector3(edge_x * sz.x * 0.5, sz.y + 0.038 - sink + 0.05, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x + 0.04, 0.055, 0.038), 0.006), M, Vector3(0, sz.y + 0.038 - sink + 0.05, sz.z * 0.5)))
	# 地上散落的成型梅花开口扳手、弯头撬棍与打开的套筒工具盒
	var wr := Node3D.new()
	add_child(wr)
	wr.position = Vector3(sz.x * 0.72, 0.022, -sz.z * 0.36)
	wr.rotation_degrees = Vector3(0, 35, 0)
	A.add(wr, A.bevel_box(Vector3(0.36, 0.020, 0.044), 0.006), MC, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(wr, A.torus(0.024, 0.052, 16), MC, Vector3(-0.19, 0, 0), Vector3.ZERO, Vector3(1, 0.55, 1), false)
	A.add(wr, A.torus(0.028, 0.056, 16), MC, Vector3(0.19, 0, 0), Vector3.ZERO, Vector3(1, 0.55, 1), false)
	_m(A.tube([Vector3(-0.28, 0.02, 0.0), Vector3(0.18, 0.02, 0.0), Vector3(0.28, 0.05, 0.06), Vector3(0.33, 0.03, 0.12)], 0.014, 14, 8), M, Vector3(-sz.x * 0.66, 0.01, sz.z * 0.36), Vector3(0, -24, 0), Vector3.ONE, false)
	_m(A.bevel_box(Vector3(0.34, 0.085, 0.22), 0.016), MD, Vector3(sz.x * 0.58, 0.042, sz.z * 0.32), Vector3(0, 18, 0), Vector3.ONE, false)
	_m(A.bevel_box(Vector3(0.32, 0.022, 0.20), 0.006), M, Vector3(sz.x * 0.58, 0.10, sz.z * 0.44), Vector3(58, 18, 0), Vector3.ONE, false)


## 军用储物箱：冲压加强肋橄榄绿重型军械箱，包角铸件、黄铜泄压阀、管状弹簧提把、挂锁搭扣与警示带
func _build_military(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.27, 0.31, 0.22), 0.24, 0.36)
	var MD := _worn(Color(0.13, 0.14, 0.13), 0.70, 0.52)
	var MB := _worn(Color(0.54, 0.44, 0.22), 0.80, 0.32)
	var body := Node3D.new()
	add_child(body)
	body.rotation_degrees = Vector3(4, 0, 3)
	var by := sz.y * 0.5 - sink - 0.05
	_meshes.append(A.add(body, A.bevel_box(sz, 0.05), M, Vector3(0, by, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x + 0.05, 0.12, sz.z + 0.05), 0.022), MD, Vector3(0, sz.y * 0.74 - sink - 0.05, 0)))
	for ri in 5:
		var rx := (-0.38 + ri * 0.19) * sz.x
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.062, 0.036, sz.z * 0.88), 0.008), MD if ri % 2 == 1 else M, Vector3(rx, sz.y - sink - 0.032, 0)))
		for sz_f in [-1.0, 1.0]:
			_meshes.append(A.add(body, A.bevel_box(Vector3(0.058, sz.y * 0.58, 0.030), 0.007), M, Vector3(rx, by - 0.04, sz_f * (sz.z * 0.5 + 0.014))))
	for sx in [-1.0, 1.0]:
		for szz in [-1.0, 1.0]:
			_meshes.append(A.add(body, A.bevel_box(Vector3(0.16, 0.16, 0.16), 0.018), MD, Vector3(sx * (sz.x * 0.5 - 0.035), sz.y - sink - 0.085, szz * (sz.z * 0.5 - 0.035))))
			_meshes.append(A.add(body, A.bevel_box(Vector3(0.15, 0.15, 0.15), 0.016), MD, Vector3(sx * (sz.x * 0.5 - 0.035), 0.08 - sink, szz * (sz.z * 0.5 - 0.035))))
	# 前面三联重型锁扣 + 居中黄铜挂锁环
	for sx in [-0.58, 0.0, 0.58]:
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.12, 0.20, 0.058), 0.012), MD, Vector3(sx, sz.y * 0.70 - sink - 0.05, -sz.z * 0.5 - 0.03)))
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.075, 0.11, 0.038), 0.007), MB, Vector3(sx, sz.y * 0.68 - sink - 0.05, -sz.z * 0.5 - 0.056)))
	_meshes.append(A.add(body, A.torus(0.024, 0.044, 18), MB, Vector3(0.0, sz.y * 0.58 - sink - 0.05, -sz.z * 0.5 - 0.056), Vector3(90, 0, 0)))
	# 黄铜气压泄压阀与压力表
	_meshes.append(A.add(body, A.cyl(0.044, 0.045, 0.048, 20), MD, Vector3(0.32, by + 0.02, -sz.z * 0.5 - 0.020), Vector3(90, 0, 0)))
	_meshes.append(A.add(body, A.cyl(0.032, 0.052, 0.032, 18), MB, Vector3(0.32, by + 0.02, -sz.z * 0.5 - 0.028), Vector3(90, 0, 0)))
	# 两侧管状弹簧提把（A.tube 平滑弯管）
	for sx: float in [-1.0, 1.0]:
		var hx := sx * (sz.x * 0.5 + 0.032)
		var hy := sz.y * 0.46 - sink - 0.05
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.065, 0.20, 0.42), 0.014), MD, Vector3(hx, hy, 0)))
		_meshes.append(A.add(body, A.tube([Vector3(hx, hy + 0.03, -0.15), Vector3(hx + sx * 0.065, hy - 0.04, -0.15),
			Vector3(hx + sx * 0.065, hy - 0.04, 0.15), Vector3(hx, hy + 0.03, 0.15)], 0.017, 16, 8), MB, Vector3.ZERO))
	_meshes.append(A.add(body, A.bevel_box(Vector3(0.26, 0.018, sz.z * 0.96), 0.004), _worn(Color(0.66, 0.50, 0.16), 0.0, 0.18), Vector3(sz.x * 0.32, sz.y - sink - 0.038, 0)))


## 保险柜：厚钢板铆接重型金库保险柜侧倒在碎混凝土里，外露双轴重铰链、带外环三辐舵轮密码锁与锚固法兰
func _build_safe(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.24, 0.25, 0.27), 0.64, 0.62)
	var MD := _worn(Color(0.14, 0.145, 0.155), 0.76, 0.50)
	var MB := _worn(Color(0.60, 0.48, 0.24), 0.84, 0.30)
	var body := Node3D.new()
	add_child(body)
	body.rotation_degrees = Vector3(-8, 0, 5)
	var cy_p := sz.y * 0.5 - sink - 0.08
	_meshes.append(A.add(body, A.bevel_box(sz, 0.05), M, Vector3(0, cy_p, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x + 0.04, 0.08, sz.z + 0.04), 0.016), MD, Vector3(0, sz.y - sink - 0.11, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x + 0.06, 0.08, sz.z + 0.06), 0.016), MD, Vector3(0, 0.04 - sink, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x - 0.12, sz.y - 0.14, 0.045), 0.016), MD, Vector3(0, cy_p, -sz.z * 0.5 - 0.015)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x - 0.20, sz.y - 0.22, 0.060), 0.022), M, Vector3(0, cy_p, -sz.z * 0.5 - 0.040)))
	# 门框铆钉与重型双轴铰链（20 段细分）
	for hy in [-0.28, 0.28]:
		_meshes.append(A.add(body, A.cyl(0.044, 0.22, 0.044, 20), MD, Vector3(sz.x * 0.5 - 0.06, cy_p + hy * sz.y, -sz.z * 0.5 - 0.058)))
		_meshes.append(A.add(body, A.cyl(0.054, 0.045, 0.054, 20), MB, Vector3(sz.x * 0.5 - 0.06, cy_p + hy * sz.y, -sz.z * 0.5 - 0.058)))
	# 金库三辐舵轮转盘密码锁（完整外轮环 + 24 段黄铜表盘）
	var dial_p := Vector3(0.12, cy_p + 0.06, -sz.z * 0.5 - 0.072)
	_meshes.append(A.add(body, A.cyl(0.14, 0.048, 0.15, 24), MD, dial_p, Vector3(90, 0, 0)))
	_meshes.append(A.add(body, A.cyl(0.088, 0.060, 0.095, 24), MB, dial_p + Vector3(0, 0, -0.022), Vector3(90, 0, 0)))
	_meshes.append(A.add(body, A.torus(0.115, 0.145, 24), MB, dial_p + Vector3(0, 0, -0.050), Vector3(90, 0, 0)))
	for sp_i in 3:
		var sa := sp_i * 120.0 + 18.0
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.024, 0.25, 0.024), 0.005), MB, dial_p + Vector3(0, 0, -0.048), Vector3(0, 0, sa)))
	# 门闩执手与铭牌
	_meshes.append(A.add(body, A.bevel_box(Vector3(0.055, 0.30, 0.065), 0.012), MB, Vector3(-0.22, cy_p, -sz.z * 0.5 - 0.078)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(0.26, 0.095, 0.022), 0.005), MD, Vector3(0.12, cy_p - 0.23, -sz.z * 0.5 - 0.070)))
	# 周边碎裂混凝土残块（低调接地，不遮挡金库门细节）
	var C := A.rock_mat(Color(0.46, 0.44, 0.40))
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.55
		_m(A.rock_mesh_low((i * 3 + 1) % 12), C, Vector3(cos(a) * 0.68, 0.04, sin(a) * 0.68),
			Vector3(_rng.randf_range(-12, 12), _rng.randf() * 360.0, _rng.randf_range(-12, 12)),
			Vector3(0.22, 0.10, 0.18), false)


## 弹药箱：军绿钢制翻盖弹链箱，折叠顶部提手、铰链翻扣、冲压加强肋与箱旁散落的数枚黄铜口径弹药
func _build_ammo(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.28, 0.32, 0.22), 0.30, 0.40)
	var MD := _worn(Color(0.13, 0.14, 0.13), 0.72, 0.48)
	var MB := _worn(Color(0.62, 0.50, 0.22), 0.84, 0.26)
	var MCOP := _worn(Color(0.66, 0.34, 0.18), 0.82, 0.22)
	var body := Node3D.new()
	add_child(body)
	body.rotation_degrees = Vector3(2, 0, 4)
	_meshes.append(A.add(body, A.bevel_box(sz, 0.036), M, Vector3(0, sz.y * 0.5 - sink, 0)))
	# 翻盖与防潮胶条边沿 + 冲压顶肋
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x + 0.04, 0.085, sz.z + 0.04), 0.014), M, Vector3(0, sz.y * 0.88 - sink, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x + 0.045, 0.032, sz.z + 0.045), 0.008), MD, Vector3(0, sz.y * 0.78 - sink, 0)))
	for rx in [-0.28, 0.0, 0.28]:
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.048, sz.y * 0.56, sz.z + 0.025), 0.007), MD, Vector3(rx * sz.x, sz.y * 0.42 - sink, 0)))
	# 顶部折叠钢丝提把 + 前置压杆翻扣 + 后端双铰链
	_meshes.append(A.add(body, A.tube([Vector3(-0.18, sz.y - sink + 0.01, 0), Vector3(-0.18, sz.y - sink + 0.075, 0),
		Vector3(0.18, sz.y - sink + 0.075, 0), Vector3(0.18, sz.y - sink + 0.01, 0)], 0.014, 14, 6), MD, Vector3.ZERO))
	for sx in [-0.30, 0.30]:
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.10, 0.20, 0.055), 0.010), MB, Vector3(sx * sz.x, sz.y * 0.66 - sink, -sz.z * 0.5 - 0.028)))
		_meshes.append(A.add(body, A.cyl(0.018, 0.09, 0.018, 16), MD, Vector3(sx * sz.x, sz.y * 0.80 - sink, sz.z * 0.5 + 0.02), Vector3(0, 0, 90)))
	# 散落在箱顶与箱侧的三发高精黄铜重机枪弹（16 段弹壳 + 尖锥紫铜弹头）
	for c_spec in [
		[Vector3(0.24, sz.y - sink + 0.035, -0.14), Vector3(0, 28, 90)],
		[Vector3(0.14, sz.y - sink + 0.035, -0.10), Vector3(0, 52, 90)],
		[Vector3(-0.56, 0.025, -sz.z * 0.48), Vector3(0, -34, 90)],
	]:
		var cn := Node3D.new()
		add_child(cn)
		cn.position = c_spec[0]
		cn.rotation_degrees = c_spec[1]
		A.add(cn, A.cyl(0.022, 0.11, 0.024, 16), MB, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		A.add(cn, A.cyl(0.002, 0.065, 0.020, 16), MCOP, Vector3(0, 0.085, 0), Vector3.ZERO, Vector3.ONE, false)


## 医疗箱：白漆硬壳野战急救箱 + 四角防撞护胶 + 不锈钢弹簧扣 + 弯曲提手 + 立体红十字框 + 倾倒血清药瓶
func _build_med(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.74, 0.75, 0.73), 0.12, 0.14)
	var MD := _worn(Color(0.15, 0.16, 0.17), 0.66, 0.42)
	var MC := _worn(Color(0.68, 0.70, 0.72), 0.85, 0.18)
	var MR := _worn(Color(0.66, 0.15, 0.14), 0.08, 0.10)
	var body := Node3D.new()
	add_child(body)
	body.rotation_degrees = Vector3(0, 0, -5)
	_meshes.append(A.add(body, A.bevel_box(sz, 0.045), M, Vector3(0, sz.y * 0.5 - sink, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x + 0.035, 0.055, sz.z + 0.035), 0.012), MD, Vector3(0, sz.y * 0.76 - sink, 0)))
	# 四角护胶 + 顶盖立体红十字徽标与正面红十字
	for sx in [-1.0, 1.0]:
		for sz_c in [-1.0, 1.0]:
			_meshes.append(A.add(body, A.bevel_box(Vector3(0.11, sz.y * 0.94, 0.11), 0.016), MD, Vector3(sx * (sz.x * 0.5 - 0.02), sz.y * 0.5 - sink, sz_c * (sz.z * 0.5 - 0.02))))
	_meshes.append(A.add(body, A.bevel_box(Vector3(0.14, sz.y * 0.36, 0.026), 0.005), MR, Vector3(0, sz.y * 0.46 - sink, -sz.z * 0.5 - 0.014)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.32, 0.14, 0.026), 0.005), MR, Vector3(0, sz.y * 0.46 - sink, -sz.z * 0.5 - 0.014)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(0.36, 0.025, 0.13), 0.005), MR, Vector3(0, sz.y - sink + 0.01, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(0.13, 0.025, 0.36), 0.005), MR, Vector3(0, sz.y - sink + 0.01, 0)))
	# 双不锈钢搭扣 + 弯曲顶盖提手
	for sx in [-0.30, 0.30]:
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.08, 0.15, 0.045), 0.008), MC, Vector3(sx * sz.x, sz.y * 0.72 - sink, -sz.z * 0.5 - 0.025)))
	_meshes.append(A.add(body, A.tube([Vector3(-0.22, sz.y - sink + 0.01, -0.02), Vector3(-0.22, sz.y - sink + 0.09, -0.02),
		Vector3(0.22, sz.y - sink + 0.09, -0.02), Vector3(0.22, sz.y - sink + 0.01, -0.02)], 0.018, 16, 8), MD, Vector3.ZERO))
	# 倾倒在箱边的应急血清瓶（高分段玻璃筒 + 柔和微光药液）
	var vn := Node3D.new()
	add_child(vn)
	vn.position = Vector3(sz.x * 0.56, 0.065, -sz.z * 0.32)
	vn.rotation_degrees = Vector3(0, 24, 86)
	A.add(vn, A.cyl(0.055, 0.22, 0.055, 18), A.glass(Color(0.32, 0.78, 0.88)), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(vn, A.cyl(0.040, 0.14, 0.040, 16), A.emit(Color(0.26, 0.90, 0.68), 1.1), Vector3(0, -0.01, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(vn, A.cyl(0.048, 0.055, 0.048, 16), MD, Vector3(0, 0.13, 0), Vector3.ZERO, Vector3.ONE, false)


## 技术物资箱：军规防震遥测仪器箱（Pelican 风格加强肋顶盖、气压平衡阀、多路同轴端口、弹簧天线与精密 PCB）
func _build_tech(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.22, 0.29, 0.38), 0.42, 0.30)
	var MD := _worn(Color(0.13, 0.14, 0.15), 0.72, 0.45)
	var MC := _worn(Color(0.18, 0.42, 0.26), 0.12, 0.15)
	var MB := _worn(Color(0.64, 0.52, 0.22), 0.85, 0.20)
	var body := Node3D.new()
	add_child(body)
	body.rotation_degrees = Vector3(0, 12, 2)
	_meshes.append(A.add(body, A.bevel_box(sz, 0.038), M, Vector3(0, sz.y * 0.5 - sink, 0)))
	# 顶盖五道防震加强肋 + 中央气压平衡阀
	for ri in 5:
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.07, 0.032, sz.z * 0.88), 0.008), MD if ri == 2 else M, Vector3((-0.34 + ri * 0.17) * sz.x, sz.y - sink + 0.01, 0)))
	_meshes.append(A.add(body, A.cyl(0.042, 0.04, 0.046, 18), MD, Vector3(-sz.x * 0.30, sz.y * 0.38 - sink, -sz.z * 0.5 - 0.02), Vector3(90, 0, 0)))
	# 前置仪表面板 + 3 组圆形同轴接口 + 指示灯
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.78, sz.y * 0.46, 0.028), 0.008), MD, Vector3(0.04, sz.y * 0.46 - sink, -sz.z * 0.5 - 0.014)))
	for i in 3:
		_meshes.append(A.add(body, A.cyl(0.032, 0.035, 0.032, 16), MB, Vector3(-0.20 + i * 0.16, sz.y * 0.44 - sink, -sz.z * 0.5 - 0.032), Vector3(90, 0, 0)))
	_meshes.append(A.add(body, A.sphere(0.022, -1.0, 14), A.emit(Color(0.25, 0.90, 0.96), 1.4), Vector3(0.34, sz.y * 0.54 - sink, -sz.z * 0.5 - 0.032), Vector3.ZERO, Vector3.ONE, false))
	# 弹簧座折叠遥测天线（16 段）
	for k in 3:
		_meshes.append(A.add(body, A.torus(0.014, 0.028, 16), MD, Vector3(sz.x * 0.34, sz.y - sink + 0.02 + k * 0.024, sz.z * 0.32), Vector3.ZERO))
	_meshes.append(A.add(body, A.cyl(0.012, 0.36, 0.016, 16), MD, Vector3(sz.x * 0.38, sz.y - sink + 0.24, sz.z * 0.35), Vector3(16, 0, -14)))
	# 箱外散落的精细 PCB 电路板（带黑色主控 IC 与金手指）
	var pcb := Node3D.new()
	add_child(pcb)
	pcb.position = Vector3(-sz.x * 0.44, 0.016, sz.z * 0.48)
	pcb.rotation_degrees = Vector3(0, 38, 0)
	A.add(pcb, A.bevel_box(Vector3(0.28, 0.016, 0.20), 0.003), MC, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(pcb, A.bevel_box(Vector3(0.09, 0.022, 0.09), 0.004), MD, Vector3(-0.03, 0.014, -0.02), Vector3.ZERO, Vector3.ONE, false)
	A.add(pcb, A.bevel_box(Vector3(0.20, 0.018, 0.03), 0.002), MB, Vector3(0.0, 0.004, 0.09), Vector3.ZERO, Vector3.ONE, false)


## 结算终端：复古工业收款机柜，遮光罩倾角 CRT 屏、阶梯键盘台、半开分格钱箱与顶部打印纸卷
func _build_register(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.32, 0.34, 0.37), 0.46, 0.42)
	var MD := _worn(Color(0.13, 0.14, 0.15), 0.74, 0.48)
	var MG := A.glass(Color(0.16, 0.38, 0.44))
	var MP := _worn(Color(0.86, 0.84, 0.76), 0.0, 0.05)
	_meshes.append(A.add(self, A.bevel_box(Vector3(sz.x, sz.y * 0.56, sz.z), 0.032), M, Vector3(0, sz.y * 0.28 - sink, 0)))
	# 上部后收式遮光屏罩 + 内凹玻璃屏
	_meshes.append(A.add(self, A.bevel_box(Vector3(sz.x * 0.92, sz.y * 0.44, sz.z * 0.76), 0.03), M, Vector3(0, sz.y * 0.74 - sink, sz.z * 0.08)))
	_meshes.append(A.add(self, A.bevel_box(Vector3(sz.x * 0.76, sz.y * 0.30, 0.035), 0.008), MG, Vector3(0, sz.y * 0.74 - sink, -sz.z * 0.30), Vector3(-14, 0, 0)))
	# 倾角按键面板与实体键帽矩阵
	_meshes.append(A.add(self, A.bevel_box(Vector3(sz.x * 0.86, 0.06, sz.z * 0.38), 0.010), MD, Vector3(0, sz.y * 0.48 - sink, -sz.z * 0.28), Vector3(26, 0, 0)))
	for iy in 3:
		for ix in 4:
			_meshes.append(A.add(self, A.bevel_box(Vector3(0.052, 0.025, 0.044), 0.004), M, Vector3(-sz.x * 0.24 + ix * 0.11, sz.y * 0.53 - sink - iy * 0.032, -sz.z * 0.22 - iy * 0.062), Vector3(26, 0, 0)))
	# 半弹出钱箱抽屉与钞票格挡板
	_meshes.append(A.add(self, A.bevel_box(Vector3(sz.x * 0.84, sz.y * 0.18, sz.z * 0.56), 0.012), MD, Vector3(0, sz.y * 0.16 - sink, -sz.z * 0.46)))
	for dx in [-0.14, 0.0, 0.14]:
		_meshes.append(A.add(self, A.bevel_box(Vector3(0.02, sz.y * 0.12, sz.z * 0.38), 0.004), M, Vector3(dx, sz.y * 0.20 - sink, -sz.z * 0.52)))
	# 顶部热敏凭条卷筒（18 段圆柱 + 探出的残破小票纸带）
	_meshes.append(A.add(self, A.cyl(0.058, 0.14, 0.058, 18), MP, Vector3(sz.x * 0.24, sz.y * 0.96 - sink, sz.z * 0.06), Vector3(0, 0, 90)))
	_meshes.append(A.add(self, A.bevel_box(Vector3(0.11, 0.16, 0.012), 0.002), MP, Vector3(sz.x * 0.24, sz.y * 1.03 - sink, -0.02), Vector3(-28, 0, 0)))


## 武器架：重型钢木混合军械枪架，带枪托橡胶卡槽、链锁钢缆与残余受损步枪机匣/弹匣
func _build_weapon(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.36, 0.26, 0.16), 0.08, 0.35)
	var MD := _worn(Color(0.14, 0.15, 0.16), 0.74, 0.48)
	var MS := _worn(Color(0.30, 0.32, 0.33), 0.68, 0.42)
	var body := Node3D.new()
	add_child(body)
	body.rotation_degrees = Vector3(-12, 0, 0)
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x, sz.y * 0.14, sz.z), 0.02), MD, Vector3(0, 0.08 - sink, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.96, sz.y * 0.92, 0.08), 0.02), M, Vector3(0, sz.y * 0.52 - sink, sz.z * 0.38)))
	for sx in [-1.0, 1.0]:
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.08, sz.y * 0.98, sz.z * 0.90), 0.014), MD, Vector3(sx * (sz.x * 0.5 - 0.04), sz.y * 0.52 - sink, 0)))
	# 中上枪管卡槽横梁与 4 组 U 型枪托槽
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.94, 0.065, 0.14), 0.01), MD, Vector3(0, sz.y * 0.78 - sink, -sz.z * 0.12)))
	for i in 4:
		var rx := -sz.x * 0.34 + float(i) * (sz.x * 0.225)
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.05, sz.y * 0.84, 0.06), 0.008), MD, Vector3(rx, sz.y * 0.50 - sink, sz.z * 0.22)))
	# 贯穿前部的防盗锁链钢缆（A.tube 平滑圆管）
	_meshes.append(A.add(body, A.tube([Vector3(-sz.x * 0.46, sz.y * 0.56 - sink, -sz.z * 0.24),
		Vector3(0.0, sz.y * 0.46 - sink, -sz.z * 0.30), Vector3(sz.x * 0.46, sz.y * 0.56 - sink, -sz.z * 0.24)], 0.016, 14, 8), MS, Vector3.ZERO))
	# 架内残留的一支旧步枪骨架（枪管 16 段 + 机匣 + 弯弹匣）
	var rfl := Node3D.new()
	body.add_child(rfl)
	rfl.position = Vector3(-0.22, sz.y * 0.48 - sink, 0.02)
	rfl.rotation_degrees = Vector3(0, 0, -6)
	_meshes.append(A.add(rfl, A.bevel_box(Vector3(0.09, 0.34, 0.12), 0.012), MS, Vector3(0, 0, 0)))
	_meshes.append(A.add(rfl, A.cyl(0.018, 0.44, 0.018, 16), MD, Vector3(0, 0.34, 0)))
	_meshes.append(A.add(rfl, A.bevel_box(Vector3(0.06, 0.22, 0.08), 0.010), M, Vector3(0, -0.24, 0.02)))
	_meshes.append(A.add(rfl, A.bevel_box(Vector3(0.04, 0.14, 0.14), 0.008), MD, Vector3(0, 0.02, -0.10), Vector3(-22, 0, 0)))


## 抛锚轿车残骸：精细重构（倾斜引擎盖 + 乘员舱立柱/内凹破窗 + 轮胎轮毂 + 格栅大灯 + 保险杠 + 翘起后备箱与备胎）
func _build_car(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.29, 0.34, 0.32), 0.36, 0.62)
	var MD := _worn(Color(0.13, 0.14, 0.15), 0.72, 0.50)
	var MR := _worn(Color(0.11, 0.11, 0.12), 0.06, 0.15)
	var MC := _worn(Color(0.56, 0.58, 0.56), 0.84, 0.28)
	var MG := A.glass(Color(0.18, 0.26, 0.30))
	var body := Node3D.new()
	add_child(body)
	body.rotation_degrees = Vector3(0, 0, 3)
	var ch_y := 0.36 - sink
	# 下车身底盘与侧裙 + 前后保险杠
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.98, 0.44, sz.z * 0.96), 0.08), M, Vector3(0, ch_y + 0.18, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(0.16, 0.20, sz.z * 1.02), 0.03), MD, Vector3(-sz.x * 0.50, ch_y + 0.04, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(0.16, 0.20, sz.z * 1.02), 0.03), MD, Vector3(sz.x * 0.50, ch_y + 0.04, 0)))
	# 倾斜引擎盖 + 散热格栅 + 双圆头灯
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.34, 0.12, sz.z * 0.86), 0.035), M, Vector3(-sz.x * 0.31, ch_y + 0.42, 0), Vector3(0, 0, 6)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(0.05, 0.18, sz.z * 0.52), 0.008), MD, Vector3(-sz.x * 0.49, ch_y + 0.22, 0)))
	for lz in [-0.34, 0.34]:
		_meshes.append(A.add(body, A.torus(0.055, 0.088, 18), MC, Vector3(-sz.x * 0.49, ch_y + 0.24, lz * sz.z), Vector3(0, 0, 90)))
		_meshes.append(A.add(body, A.cyl(0.062, 0.04, 0.062, 18), MD, Vector3(-sz.x * 0.48, ch_y + 0.24, lz * sz.z), Vector3(0, 0, 90)))
	# 上乘员舱（梯形收腰车顶 + 内凹玻璃 + A/B/C 柱框架）
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.48, 0.44, sz.z * 0.84), 0.055, 0.80), M, Vector3(-sz.x * 0.02, ch_y + 0.58, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.44, 0.28, sz.z * 0.86), 0.025, 0.84), MG, Vector3(-sz.x * 0.02, ch_y + 0.58, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.42, 0.065, sz.z * 0.78), 0.02), M, Vector3(-sz.x * 0.02, ch_y + 0.80, 0)))
	for px in [-0.18, 0.02, 0.18]:
		for pz in [-0.39, 0.39]:
			_meshes.append(A.add(body, A.bevel_box(Vector3(0.055, 0.34, 0.055), 0.008), M, Vector3(px * sz.x, ch_y + 0.58, pz * sz.z)))
	# 四只带胎壁与金属轮毂的车轮（20 段轮胎环 + 轮圈 + 轴头，前轮微偏）
	for ix in [-1.0, 1.0]:
		for iz in [-1.0, 1.0]:
			var wp := Vector3(ix * sz.x * 0.32, 0.24 - sink, iz * (sz.z * 0.5 - 0.04))
			var wyaw := 14.0 if ix < 0.0 else 0.0
			_meshes.append(A.add(body, A.torus(0.145, 0.255, 20), MR, wp, Vector3(90, wyaw, 0)))
			_meshes.append(A.add(body, A.cyl(0.155, 0.14, 0.155, 20), MC, wp, Vector3(90, wyaw, 0)))
			_meshes.append(A.add(body, A.cyl(0.055, 0.17, 0.055, 16), MD, wp, Vector3(90, wyaw, 0)))
	# 半翘起的后备箱盖 + 内凹黑舱 + 露出备胎
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.28, 0.16, sz.z * 0.76), 0.02), MD, Vector3(sz.x * 0.34, ch_y + 0.34, 0)))
	_meshes.append(A.add(body, A.torus(0.11, 0.21, 18), MR, Vector3(sz.x * 0.34, ch_y + 0.42, 0.05), Vector3(12, 0, 18)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.32, 0.055, sz.z * 0.82), 0.015), M, Vector3(sz.x * 0.34, ch_y + 0.62, 0), Vector3(0, 0, 38)))


## 废弃集装箱：波纹钢板迷你标准货运箱，ISO 角件、叉车槽、双开对门与 16 段镀铬竖锁杆/黄铜大挂锁
func _build_container(sz: Vector3, sink: float) -> void:
	var M := A.corrugated(Color(0.24, 0.36, 0.40), 0.52, 0.34)
	var MD := _worn(Color(0.13, 0.14, 0.15), 0.74, 0.52)
	var MC := _worn(Color(0.62, 0.64, 0.66), 0.86, 0.22)
	var MB := _worn(Color(0.56, 0.46, 0.22), 0.82, 0.34)
	var cy := sz.y * 0.5 - sink
	_meshes.append(A.add(self, A.bevel_box(sz, 0.032), M, Vector3(0, cy, 0)))
	# 上下框架边梁 + 8 颗 ISO 铸铁角件
	_meshes.append(A.add(self, A.bevel_box(Vector3(sz.x + 0.05, 0.10, sz.z + 0.05), 0.014), MD, Vector3(0, sz.y - sink - 0.04, 0)))
	_meshes.append(A.add(self, A.bevel_box(Vector3(sz.x + 0.05, 0.10, sz.z + 0.05), 0.014), MD, Vector3(0, 0.05 - sink, 0)))
	for sx in [-1.0, 1.0]:
		for sz_c in [-1.0, 1.0]:
			_meshes.append(A.add(self, A.bevel_box(Vector3(0.14, sz.y * 0.94, 0.14), 0.014), MD, Vector3(sx * (sz.x * 0.5 - 0.04), cy, sz_c * (sz.z * 0.5 - 0.04))))
	# 底部叉车插槽 + 侧壁通风百叶
	for fx in [-0.65, 0.65]:
		_meshes.append(A.add(self, A.bevel_box(Vector3(0.28, 0.11, sz.z + 0.06), 0.008), MD, Vector3(fx, 0.06 - sink, 0)))
	# 前置双扇对开门 + 四根 16 段镀铬锁杆 + 黄铜挂锁环
	for sx in [-0.42, 0.42]:
		_meshes.append(A.add(self, A.bevel_box(Vector3(0.72, sz.y * 0.86, 0.048), 0.012), M, Vector3(sx, cy, -sz.z * 0.5 - 0.02)))
	for lx in [-0.62, -0.22, 0.22, 0.62]:
		_meshes.append(A.add(self, A.cyl(0.018, sz.y * 0.84, 0.018, 16), MC, Vector3(lx, cy, -sz.z * 0.5 - 0.056)))
		_meshes.append(A.add(self, A.bevel_box(Vector3(0.06, 0.07, 0.05), 0.008), MD, Vector3(lx, sz.y * 0.86 - sink, -sz.z * 0.5 - 0.052)))
		_meshes.append(A.add(self, A.bevel_box(Vector3(0.11, 0.04, 0.045), 0.006), MD, Vector3(lx + 0.04, cy - 0.14, -sz.z * 0.5 - 0.068)))
	_meshes.append(A.add(self, A.bevel_box(Vector3(0.14, 0.18, 0.055), 0.012), MB, Vector3(0, cy - 0.12, -sz.z * 0.5 - 0.068)))
	_meshes.append(A.add(self, A.torus(0.036, 0.058, 18), MB, Vector3(0, cy - 0.01, -sz.z * 0.5 - 0.068), Vector3(90, 0, 0)))


## 埋藏桶：半埋进沙土的 24 段加强军用油桶，双道圆管滚箍、注油螺塞、撬开的桶盖、土堆与斜倚工兵铲
func _build_cache(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.32, 0.39, 0.27), 0.44, 0.58)
	var MD := _worn(Color(0.14, 0.15, 0.14), 0.74, 0.52)
	var MB := _worn(Color(0.56, 0.46, 0.22), 0.82, 0.30)
	var MW := _worn(Color(0.38, 0.27, 0.17), 0.0, 0.06)
	var R := A.rock_mat(Color(0.46, 0.42, 0.36))
	var cy := sz.y * 0.44 - sink
	_meshes.append(A.add(self, A.cyl(sz.x * 0.48, sz.y, sz.x * 0.48, 24), M, Vector3(0, cy, 0), Vector3(0, 0, 8)))
	for hy in [-0.18, 0.16, sz.y * 0.48]:
		_meshes.append(A.add(self, A.torus(sz.x * 0.46, sz.x * 0.52, 24), MD, Vector3(0, cy + hy, 0), Vector3(0, 0, 8), Vector3(1, 0.55, 1)))
	# 桶顶大小注油螺塞 + 撬开的微翘圆桶盖
	_meshes.append(A.add(self, A.cyl(0.048, 0.045, 0.048, 16), MB, Vector3(-0.12, cy + sz.y * 0.50, 0.08), Vector3(0, 0, 8)))
	_meshes.append(A.add(self, A.cyl(sz.x * 0.42, 0.045, sz.x * 0.42, 24), MD, Vector3(sz.x * 0.14, cy + sz.y * 0.52, -0.04), Vector3(10, 0, 18)))
	# 旁侧挖出的土石堆（真实岩块）与斜靠的工兵锹
	_m(A.rock_mesh_low(4), R, Vector3(-sz.x * 0.58, 0.07, sz.z * 0.38), Vector3(0, 32, 0), Vector3(0.46, 0.20, 0.38), false)
	var shv := Node3D.new()
	add_child(shv)
	shv.position = Vector3(sz.x * 0.52, 0.24, sz.z * 0.22)
	shv.rotation_degrees = Vector3(18, -26, -34)
	A.add(shv, A.cyl(0.018, 0.62, 0.018, 16), MW, Vector3(0, 0.14, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(shv, A.bevel_box(Vector3(0.16, 0.22, 0.018), 0.006, 0.72), MD, Vector3(0, -0.22, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(shv, A.tube([Vector3(-0.055, 0.45, 0), Vector3(-0.055, 0.52, 0), Vector3(0.055, 0.52, 0), Vector3(0.055, 0.45, 0)], 0.013, 14, 6), MD, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)


## 敌对机械体残骸：撕裂的铸铁枪钢装甲壳、氧化锈蚀副板、高分段镀铬液压作动筒、黄铜伺服环、护笼余温炉芯与断裂软管
func _build_wreck(sz: Vector3) -> void:
	var M_GUN := _worn(Color(0.16, 0.18, 0.20), 0.74, 0.40)
	var M_RUST := _worn(Color(0.36, 0.21, 0.13), 0.54, 0.76)
	var M_BRASS := _worn(Color(0.58, 0.46, 0.22), 0.82, 0.30)
	var M_CHR := _worn(Color(0.66, 0.68, 0.70), 0.90, 0.16)
	var M_HAZ := _worn(Color(0.72, 0.52, 0.14), 0.25, 0.45)
	var m_core := A.emit(Color(0.96, 0.48, 0.12), 1.05)
	m_core.albedo_color = Color(0.28, 0.11, 0.03)
	var yaw0 := _rng.randf() * 360.0
	var hulk := Node3D.new()
	add_child(hulk)
	hulk.rotation_degrees = Vector3(8, yaw0, -12)
	_meshes.append(A.add(hulk, A.bevel_box(Vector3(sz.x * 0.62, 0.28, sz.z * 0.48), 0.05, 0.82), M_GUN, Vector3(0, 0.14, 0)))
	_meshes.append(A.add(hulk, A.bevel_box(Vector3(sz.x * 0.44, 0.12, sz.z * 0.36), 0.03, 0.85), M_RUST, Vector3(-0.06, 0.28, 0.04), Vector3(0, 6, 4)))
	_meshes.append(A.add(hulk, A.bevel_box(Vector3(sz.x * 0.48, 0.06, 0.11), 0.01), M_HAZ, Vector3(0, 0.22, -sz.z * 0.24)))
	_meshes.append(A.add(hulk, A.cyl(0.16, 0.12, 0.18, 20), M_BRASS, Vector3(0.18, 0.26, -0.06), Vector3(14, 0, -18)))
	_meshes.append(A.add(hulk, A.torus(0.13, 0.175, 20), M_GUN, Vector3(0.18, 0.31, -0.06), Vector3(14, 0, -18)))
	_meshes.append(A.add(hulk, A.cyl(0.095, 0.09, 0.095, 18), m_core, Vector3(0.18, 0.31, -0.06), Vector3(14, 0, -18)))
	# 断裂翻卷的液压软管
	_meshes.append(A.add(hulk, A.tube([Vector3(-0.18, 0.22, -0.10), Vector3(-0.36, 0.34, -0.26), Vector3(-0.56, 0.06, -0.32)], 0.024, 14, 8), M_GUN, Vector3.ZERO))
	for i in 2:
		var a := yaw0 * (PI / 180.0) + float(i) * 2.35 + _rng.randf_range(-0.3, 0.3)
		var lp := Vector3(cos(a) * 0.56, 0.09, sin(a) * 0.56)
		var lrot := Vector3(_rng.randf_range(-14, 14), rad_to_deg(-a), 14)
		_m(A.bevel_box(Vector3(0.14, 0.13, 0.78), 0.02, 0.85), M_GUN, lp, lrot)
		_m(A.cyl(0.058, 0.15, 0.058, 16), M_BRASS, lp + Vector3(0, 0.02, 0), lrot + Vector3(0, 0, 90))
		_m(A.cyl(0.028, 0.50, 0.028, 16), M_CHR, lp + Vector3(0, 0.06, 0), lrot + Vector3(82, 0, 0))
	for i in 4:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(0.35, 0.76) * sz.x
		_m(A.bevel_box(Vector3(_rng.randf_range(0.28, 0.54), 0.055, _rng.randf_range(0.22, 0.44)), 0.015), M_RUST if i % 2 else M_GUN,
			Vector3(cos(a) * d, 0.04 + _rng.randf() * 0.07, sin(a) * d), Vector3(_rng.randf_range(-26, 26), _rng.randf() * 360, _rng.randf_range(-26, 26)))


## 靠近提示：细边橙色描边呼吸（玩家色），搜空后不再提示
func set_near(on: bool) -> void:
	on = on and not items.is_empty()
	if on == near:
		return
	near = on
	if _hl_mat == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float p = 0.55 + 0.45 * sin(TIME * 4.0);
	ALBEDO = vec3(1.0, 0.62, 0.12) * f * p * 1.4;
}"""
		_hl_mat = ShaderMaterial.new()
		_hl_mat.shader = sh
	for mi in _meshes:
		if is_instance_valid(mi):
			mi.material_overlay = _hl_mat if on else null


func refresh_glow() -> void:
	if items.is_empty():
		set_near(false)
