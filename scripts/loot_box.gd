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
		_build_wreck(sz)
	else:
		collision_layer = 1
		collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = sz
		cs.shape = sh
		cs.position.y = sz.y * 0.5 - sink
		add_child(cs)
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
	_batch_loot_meshes()


func _rel_xf(n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != self:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


func _batch_loot_meshes() -> void:
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
	var ckey := kind if (kind != "bug" and kind != "nest") else ""
	_meshes = _merge_mesh_group(_meshes, ckey)
	_merge_mesh_group(other_list, "")
	for b in bodies:
		if is_instance_valid(b) and b.get_child_count() == 0:
			if b.get_parent():
				b.get_parent().remove_child(b)
			b.free()


func _merge_mesh_group(list: Array, cache_key: String) -> Array:
	if cache_key != "" and _hl_mesh_cache.has(cache_key):
		for mi in list:
			if is_instance_valid(mi):
				if mi.get_parent():
					mi.get_parent().remove_child(mi)
				mi.free()
		var cached_mi := MeshInstance3D.new()
		cached_mi.mesh = _hl_mesh_cache[cache_key]
		cached_mi.visibility_range_end = 65.0
		cached_mi.visibility_range_end_margin = 4.0
		add_child(cached_mi)
		return [cached_mi]
	var by_sh := {}
	for mi in list:
		if not is_instance_valid(mi) or mi.mesh == null:
			continue
		var sk := int(mi.cast_shadow)
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
			single.visibility_range_end = 65.0
			single.visibility_range_end_margin = 4.0
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
			if mi.get_parent():
				mi.get_parent().remove_child(mi)
			mi.free()
		if buckets.is_empty():
			continue
		var am := ArrayMesh.new()
		for key in buckets:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for item in buckets[key]:
				st.append_from(RB._tinted_surface(item[0], item[1], item[3], item[4]), 0, item[2])
			st.commit(am)
			if mats[key] != null:
				am.surface_set_material(am.get_surface_count() - 1, mats[key])
		if cache_key != "":
			_hl_mesh_cache[cache_key] = am
		var merged := MeshInstance3D.new()
		merged.mesh = am
		merged.cast_shadow = sk as GeometryInstance3D.ShadowCastingSetting
		merged.visibility_range_end = 65.0
		merged.visibility_range_end_margin = 4.0
		add_child(merged)
		result.append(merged)
	return result


## 底部柔和接地阴影枕垫 + 克制小碎石（让每只物资箱稳稳压在地面上，低画质与移动端均具备扎实落地感）
func _sand_and_rubble(sz: Vector3) -> void:
	var sh := MeshInstance3D.new()
	sh.mesh = A.quad(sz.x * 1.56, sz.z * 1.56)
	sh.material_override = A.contact_shadow_mat(0.54)
	sh.position = Vector3(0.0, 0.024, 0.0)
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sh.visibility_range_end = 56.0
	sh.visibility_range_end_margin = 4.0
	sh.set_meta("keep_unmerged", true)
	add_child(sh)
	var C := A.concrete(Color(0.56, 0.53, 0.48), false)
	for i in 3:
		var a := _rng.randf() * TAU
		var d: float = _rng.randf_range(0.68, 1.05) * max(sz.x, sz.z) * 0.56
		var s := _rng.randf_range(0.07, 0.14)
		_m(A.bevel_box(Vector3(s * 1.35, s * 0.85, s * 1.1), s * 0.22), C, Vector3(cos(a) * d, s * 0.30, sin(a) * d), Vector3(_rng.randf() * 35, _rng.randf() * 360, _rng.randf() * 35), Vector3.ONE, false)


## 补给箱：防腐垫木叉车托盘底座 + 两只叠放的军规加强筋塑钢周转箱 + 折叠旧油布 + 棘轮紧固捆扎带（无光圈/无状态灯）
func _build_supply(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.42, 0.41, 0.34), 0.0, 0.1)
	var M2 := _worn(Color(0.36, 0.33, 0.27), 0.0, 0.1)
	var MD := _worn(Color(0.18, 0.18, 0.17), 0.55, 0.45)
	var MPAL := _worn(Color(0.35, 0.26, 0.17), 0.0, 0.05)
	var pal_h := 0.11
	for px_s in [-0.42, 0.0, 0.42]:
		_m(A.bevel_box(Vector3(0.12, 0.075, sz.z + 0.08), 0.01), MPAL, Vector3(px_s * sz.x, 0.04 - sink * 0.5, 0))
	for pz_s in [-0.38, -0.13, 0.13, 0.38]:
		_m(A.bevel_box(Vector3(sz.x + 0.08, 0.032, 0.16), 0.008), MPAL, Vector3(0, 0.09 - sink * 0.5, pz_s * sz.z))
	var h1 := sz.y * 0.52
	var y0 := pal_h - sink
	_m(A.bevel_box(Vector3(sz.x, h1, sz.z), 0.045), M, Vector3(0, y0 + h1 * 0.5, 0))
	_m(A.bevel_box(Vector3(sz.x + 0.04, 0.055, sz.z + 0.04), 0.012), M2, Vector3(0, y0 + h1 * 0.88, 0))
	for sx_c in [-1.0, 1.0]:
		for sz_c in [-1.0, 1.0]:
			_m(A.bevel_box(Vector3(0.11, h1 * 0.94, 0.11), 0.012), MD, Vector3(sx_c * (sz.x * 0.5 - 0.03), y0 + h1 * 0.5, sz_c * (sz.z * 0.5 - 0.03)))
	for rx in [-0.28, 0.0, 0.28]:
		_m(A.bevel_box(Vector3(0.04, h1 * 0.68, sz.z + 0.03), 0.008), M2, Vector3(rx * sz.x, y0 + h1 * 0.46, 0))
	for sx in [-1.0, 1.0]:
		_m(A.bevel_box(Vector3(0.05, h1 * 0.5, sz.z * 0.68), 0.01), M2, Vector3(sx * sz.x * 0.5, y0 + h1 * 0.55, 0))
		_m(A.bevel_box(Vector3(0.06, 0.06, 0.24), 0.008), MD, Vector3(sx * (sz.x * 0.5 + 0.025), y0 + h1 * 0.72, 0))
	var h2 := sz.y * 0.40
	_m(A.bevel_box(Vector3(sz.x * 0.72, h2, sz.z * 0.85), 0.045), M2, Vector3(-sz.x * 0.1, y0 + h1 + h2 * 0.5, 0.04), Vector3(0, 8, 0))
	_m(A.bevel_box(Vector3(sz.x * 0.75, 0.045, sz.z * 0.88), 0.01), MD, Vector3(-sz.x * 0.1, y0 + h1 + h2 * 0.86, 0.04), Vector3(0, 8, 0))
	# 防水布：多折面旧帆布搭在箱角 + 压边褶皱
	var T := _worn(Color(0.32, 0.30, 0.24), 0.0, 0.0)
	_m(A.bevel_box(Vector3(sz.x * 0.82, 0.035, sz.z * 0.96), 0.012), T, Vector3(-sz.x * 0.07, y0 + h1 + h2 + 0.02, 0.0), Vector3(0, 8, -4))
	_m(A.bevel_box(Vector3(0.035, h2 * 1.42, sz.z * 0.92), 0.012), T, Vector3(sz.x * 0.29, y0 + h1 + h2 * 0.34, 0.0), Vector3(0, 8, -12))
	_m(A.bevel_box(Vector3(sz.x * 0.76, h2 * 0.75, 0.032), 0.01), T, Vector3(-sz.x * 0.06, y0 + h1 + h2 * 0.62, sz.z * 0.46), Vector3(10, 8, 0))
	var S := _worn(Color(0.19, 0.18, 0.16), 0.35, 0.3)
	var B := _worn(Color(0.46, 0.38, 0.22), 0.65, 0.35)
	for sx in [-0.3, 0.25]:
		_m(A.bevel_box(Vector3(0.052, sz.y + 0.06, sz.z + 0.055), 0.005), S, Vector3(sx * sz.x, (sz.y + pal_h) * 0.5 - sink, 0))
		_m(A.bevel_box(Vector3(0.085, 0.10, 0.05), 0.008), B, Vector3(sx * sz.x, y0 + h1 * 0.68, -sz.z * 0.5 - 0.025))


## 工具箱：倾倒的重型车间钢制工具柜，带防滑胶垫围边、推车圆管扶手、多层导轨抽屉与散落撬棍套筒盒
func _build_tool(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.42, 0.24, 0.15), 0.52, 0.72)
	var MD := _worn(Color(0.14, 0.145, 0.155), 0.68, 0.52)
	var MC := _worn(Color(0.50, 0.50, 0.48), 0.82, 0.28)
	var body := Node3D.new()
	add_child(body)
	body.rotation_degrees = Vector3(0, 0, -6)
	_meshes.append(A.add(body, A.bevel_box(sz, 0.032), M, Vector3(0, sz.y * 0.5 - sink, 0)))
	for sx in [-1.0, 1.0]:
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.04, sz.y * 0.98, 0.065), 0.008), MD, Vector3(sx * (sz.x * 0.5 - 0.01), sz.y * 0.5 - sink, -sz.z * 0.46)))
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.04, sz.y * 0.98, 0.065), 0.008), MD, Vector3(sx * (sz.x * 0.5 - 0.01), sz.y * 0.5 - sink, sz.z * 0.46)))
		for bracket_z in [-0.24, 0.24]:
			_meshes.append(A.add(body, A.bevel_box(Vector3(0.09, 0.035, 0.04), 0.006), MD, Vector3(sx * (sz.x * 0.5 + 0.04), sz.y * 0.76 - sink, bracket_z * sz.z)))
		_meshes.append(A.add(body, A.cyl(0.018, sz.z * 0.62, 0.018, 8), MC, Vector3(sx * (sz.x * 0.5 + 0.08), sz.y * 0.76 - sink, 0), Vector3(90, 0, 0)))
	for i in 3:
		var y := sz.y * (0.22 + i * 0.26) - sink
		var out := 0.16 if i == 1 else 0.0
		_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.88, sz.y * 0.20, 0.055), 0.01), M, Vector3(0, y, -sz.z * 0.5 - 0.02 - out)))
		_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.68, 0.028, 0.042), 0.006), MC, Vector3(0, y + 0.022, -sz.z * 0.5 - 0.055 - out)))
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.18, 0.045, 0.015), 0.003), MD, Vector3(sz.x * 0.26, y - 0.025, -sz.z * 0.5 - 0.048 - out)))
	if sz.y > 0.4:
		_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.84, 0.06, 0.18), 0.008), MD, Vector3(0, sz.y * 0.46 - sink, -sz.z * 0.5 - 0.08)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x + 0.04, 0.055, sz.z + 0.04), 0.012), MD, Vector3(0, sz.y - sink, 0)))
	for edge_x in [-1.0, 1.0]:
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.035, 0.045, sz.z + 0.04), 0.006), M, Vector3(edge_x * sz.x * 0.5, sz.y + 0.03 - sink, 0)))
	# 散落的扳手、撬棍与铁皮套筒工具盒
	_m(A.bevel_box(Vector3(0.42, 0.028, 0.052), 0.008), MC, Vector3(sz.x * 0.72, 0.02, -sz.z * 0.38), Vector3(0, 35, 0), Vector3.ONE, false)
	_m(A.bevel_box(Vector3(0.56, 0.026, 0.034), 0.006), M, Vector3(-sz.x * 0.66, 0.022, sz.z * 0.34), Vector3(0, -24, 0), Vector3.ONE, false)
	_m(A.bevel_box(Vector3(0.32, 0.08, 0.20), 0.015), MD, Vector3(sz.x * 0.58, 0.04, sz.z * 0.32), Vector3(0, 18, 0), Vector3.ONE, false)


## 军用储物箱：冲压加强肋橄榄绿重型军械箱，包角铸件、黄铜泄压阀、弹簧搭扣与提把，斜插进沙土
func _build_military(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.27, 0.31, 0.22), 0.22, 0.38)
	var MD := _worn(Color(0.13, 0.14, 0.13), 0.68, 0.55)
	var MB := _worn(Color(0.52, 0.42, 0.22), 0.78, 0.36)
	var body := Node3D.new()
	add_child(body)
	body.rotation_degrees = Vector3(4, 0, 3)
	var by := sz.y * 0.5 - sink - 0.05
	_meshes.append(A.add(body, A.bevel_box(sz, 0.05), M, Vector3(0, by, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x + 0.045, 0.12, sz.z + 0.045), 0.02), MD, Vector3(0, sz.y * 0.74 - sink - 0.05, 0)))
	for ri in 5:
		var rx := (-0.38 + ri * 0.19) * sz.x
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.06, 0.032, sz.z * 0.88), 0.008), MD if ri % 2 == 1 else M, Vector3(rx, sz.y - sink - 0.035, 0)))
		for sz_f in [-1.0, 1.0]:
			_meshes.append(A.add(body, A.bevel_box(Vector3(0.055, sz.y * 0.58, 0.028), 0.006), M, Vector3(rx, by - 0.04, sz_f * (sz.z * 0.5 + 0.012))))
	for sx in [-1.0, 1.0]:
		for szz in [-1.0, 1.0]:
			_meshes.append(A.add(body, A.bevel_box(Vector3(0.15, 0.15, 0.15), 0.016), MD, Vector3(sx * (sz.x * 0.5 - 0.035), sz.y - sink - 0.085, szz * (sz.z * 0.5 - 0.035))))
			_meshes.append(A.add(body, A.bevel_box(Vector3(0.14, 0.14, 0.14), 0.015), MD, Vector3(sx * (sz.x * 0.5 - 0.035), 0.08 - sink, szz * (sz.z * 0.5 - 0.035))))
	for sx in [-0.58, 0.0, 0.58]:
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.12, 0.19, 0.055), 0.012), MD, Vector3(sx, sz.y * 0.70 - sink - 0.05, -sz.z * 0.5 - 0.03)))
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.075, 0.11, 0.035), 0.006), MB, Vector3(sx, sz.y * 0.68 - sink - 0.05, -sz.z * 0.5 - 0.055)))
	_meshes.append(A.add(body, A.cyl(0.038, 0.04, 0.038, 10), MB, Vector3(0.32, by + 0.02, -sz.z * 0.5 - 0.022), Vector3(90, 0, 0)))
	for sx in [-1.0, 1.0]:
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.065, 0.20, 0.40), 0.014), MD, Vector3(sx * (sz.x * 0.5 + 0.032), sz.y * 0.46 - sink - 0.05, 0)))
		_meshes.append(A.add(body, A.cyl(0.016, 0.30, 0.016, 8), MB, Vector3(sx * (sz.x * 0.5 + 0.065), sz.y * 0.42 - sink - 0.05, 0), Vector3(90, 0, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(0.26, 0.016, sz.z * 0.96), 0.003), _worn(Color(0.62, 0.48, 0.16), 0.0, 0.2), Vector3(sz.x * 0.32, sz.y - sink - 0.04, 0)))


## 保险柜：厚钢板铆接重型金库保险柜侧倒在碎混凝土里，外露双轴重铰链、三辐转盘密码锁与门闩执手
func _build_safe(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.24, 0.25, 0.27), 0.62, 0.64)
	var MD := _worn(Color(0.14, 0.145, 0.155), 0.74, 0.52)
	var MB := _worn(Color(0.58, 0.46, 0.24), 0.82, 0.34)
	var body := Node3D.new()
	add_child(body)
	body.rotation_degrees = Vector3(-8, 0, 5)
	var cy_p := sz.y * 0.5 - sink - 0.08
	_meshes.append(A.add(body, A.bevel_box(sz, 0.05), M, Vector3(0, cy_p, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x + 0.035, 0.075, sz.z + 0.035), 0.014), MD, Vector3(0, sz.y - sink - 0.11, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x + 0.035, 0.075, sz.z + 0.035), 0.014), MD, Vector3(0, 0.04 - sink, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x - 0.12, sz.y - 0.14, 0.04), 0.015), MD, Vector3(0, cy_p, -sz.z * 0.5 - 0.015)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x - 0.20, sz.y - 0.22, 0.055), 0.02), M, Vector3(0, cy_p, -sz.z * 0.5 - 0.038)))
	for hy in [-0.28, 0.28]:
		_meshes.append(A.add(body, A.cyl(0.042, 0.20, 0.042, 12), MD, Vector3(sz.x * 0.5 - 0.06, cy_p + hy * sz.y, -sz.z * 0.5 - 0.055)))
		_meshes.append(A.add(body, A.cyl(0.052, 0.04, 0.052, 12), MB, Vector3(sz.x * 0.5 - 0.06, cy_p + hy * sz.y, -sz.z * 0.5 - 0.055)))
	var dial_p := Vector3(0.14, cy_p + 0.06, -sz.z * 0.5 - 0.07)
	_meshes.append(A.add(body, A.cyl(0.13, 0.045, 0.14, 18), MD, dial_p, Vector3(90, 0, 0)))
	_meshes.append(A.add(body, A.cyl(0.088, 0.055, 0.095, 16), MB, dial_p + Vector3(0, 0, -0.02), Vector3(90, 0, 0)))
	for sp_i in 3:
		var sa := sp_i * 120.0 + 18.0
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.022, 0.22, 0.022), 0.004), MB, dial_p + Vector3(0, 0, -0.042), Vector3(0, 0, sa)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(0.055, 0.28, 0.06), 0.01), MB, Vector3(-0.22, cy_p, -sz.z * 0.5 - 0.075)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(0.24, 0.09, 0.02), 0.004), MD, Vector3(0.14, cy_p - 0.22, -sz.z * 0.5 - 0.068)))
	var C := A.concrete(Color(0.58, 0.55, 0.5), false)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		_m(A.bevel_box(Vector3(0.5, 0.22, 0.4), 0.06), C, Vector3(cos(a) * 0.75, 0.08, sin(a) * 0.75), Vector3(_rng.randf() * 20, _rng.randf() * 360, _rng.randf() * 25), Vector3.ONE, false)


## 弹药箱：军绿小型弹链箱，顶盖弹壳压条与双卡扣，两枚引信头露在侧袋
func _build_ammo(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.30, 0.32, 0.23), 0.26, 0.42)
	var MD := _worn(Color(0.13, 0.14, 0.13), 0.68, 0.5)
	var MB := _worn(Color(0.55, 0.44, 0.20), 0.78, 0.35)
	var body := Node3D.new()
	add_child(body)
	body.rotation_degrees = Vector3(2, 0, 4)
	_meshes.append(A.add(body, A.bevel_box(sz, 0.04), M, Vector3(0, sz.y * 0.5 - sink, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x + 0.03, 0.06, sz.z + 0.03), 0.01), MD, Vector3(0, sz.y * 0.62 - sink, 0)))
	for rx in [-0.30, 0.0, 0.30]:
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.05, sz.y * 0.5, sz.z * 0.92), 0.006), MD, Vector3(rx * sz.x, sz.y * 0.42 - sink, 0)))
	for sx in [-1.0, 1.0]:
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.10, 0.16, 0.05), 0.008), MB, Vector3(sx * (sz.x * 0.5 - 0.02), sz.y * 0.58 - sink, -sz.z * 0.5 - 0.02)))
	_meshes.append(A.add(body, A.cyl(0.03, 0.06, 0.03, 8), MB, Vector3(0.24, sz.y - sink - 0.02, -sz.z * 0.28), Vector3(90, 0, 0)))
	_m(A.cyl(0.016, 0.09, 0.016, 6), MB, Vector3(-0.18, sz.y * 0.68 - sink, -sz.z * 0.42), Vector3(20, 0, 70), Vector3.ONE, false)


## 医疗箱：白漆钢箱 + 红十字条带 + 上掀盖铰链，一角被压瘪
func _build_med(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.72, 0.72, 0.70), 0.10, 0.18)
	var MD := _worn(Color(0.14, 0.145, 0.155), 0.6, 0.45)
	var MR := _worn(Color(0.62, 0.16, 0.14), 0.08, 0.12)
	var body := Node3D.new()
	add_child(body)
	body.rotation_degrees = Vector3(0, 0, -5)
	_meshes.append(A.add(body, A.bevel_box(sz, 0.04), M, Vector3(0, sz.y * 0.5 - sink, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x + 0.03, 0.05, sz.z + 0.03), 0.01), MD, Vector3(0, sz.y - sink - 0.02, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(0.16, sz.y * 0.34, 0.02), 0.004), MR, Vector3(0, sz.y * 0.58 - sink, -sz.z * 0.5 - 0.012)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.34, 0.16, 0.02), 0.004), MR, Vector3(0, sz.y * 0.58 - sink, -sz.z * 0.5 - 0.012)))
	for sx in [-1.0, 1.0]:
		_meshes.append(A.add(body, A.cyl(0.02, 0.14, 0.02, 8), MD, Vector3(sx * (sz.x * 0.5 - 0.02), sz.y - sink - 0.06, -sz.z * 0.5 - 0.02)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.30, 0.14, sz.z * 0.30), 0.02), MD, Vector3(sz.x * 0.22, sz.y * 0.30 - sink, sz.z * 0.30), Vector3(0, 14, 6)))


## 技术物资箱：蓝灰防静电钢板箱，侧挂接口面板与提手，盖板压着一块裸电路板
func _build_tech(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.24, 0.30, 0.38), 0.40, 0.35)
	var MD := _worn(Color(0.13, 0.14, 0.14), 0.7, 0.5)
	var MC := _worn(Color(0.42, 0.46, 0.30), 0.1, 0.3)
	var body := Node3D.new()
	add_child(body)
	body.rotation_degrees = Vector3(0, 12, 2)
	_meshes.append(A.add(body, A.bevel_box(sz, 0.035), M, Vector3(0, sz.y * 0.5 - sink, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.86, sz.y * 0.44, 0.025), 0.008), MD, Vector3(0, sz.y * 0.44 - sink, -sz.z * 0.5 - 0.012)))
	for i in 4:
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.10, 0.05, 0.02), 0.004), MC, Vector3(-sz.x * 0.24 + i * 0.16, sz.y * 0.44 - sink, -sz.z * 0.5 - 0.024)))
	for sx in [-1.0, 1.0]:
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.05, sz.y * 0.62, 0.10), 0.008), MD, Vector3(sx * (sz.x * 0.5 - 0.02), sz.y * 0.52 - sink, 0)))
	_meshes.append(A.add(body, A.cyl(0.012, 0.22, 0.012, 6), MD, Vector3(sz.x * 0.30, sz.y * 0.62 - sink, sz.z * 0.40), Vector3(24, 0, 14)))
	_m(A.bevel_box(Vector3(0.22, 0.015, 0.16), 0.003), MC, Vector3(-sz.x * 0.4, 0.012, sz.z * 0.44), Vector3(0, 40, 0), Vector3.ONE, false)


## 结算终端：立式旧世界收款机柜，暗屏与按键板，底部储钞格半开
func _build_register(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.30, 0.32, 0.36), 0.45, 0.45)
	var MD := _worn(Color(0.13, 0.14, 0.14), 0.72, 0.5)
	var MG := A.glass(Color(0.18, 0.34, 0.40))
	var MB := _worn(Color(0.20, 0.44, 0.20), 0.05, 0.2)
	_meshes.append(A.add(self, A.bevel_box(sz, 0.03), M, Vector3(0, sz.y * 0.5 - sink, 0)))
	_meshes.append(A.add(self, A.bevel_box(Vector3(sz.x - 0.14, sz.y * 0.36, 0.03), 0.008), MG, Vector3(0, sz.y * 0.68 - sink, -sz.z * 0.5 - 0.014)))
	for iy in 3:
		for ix in 4:
			_meshes.append(A.add(self, A.bevel_box(Vector3(0.05, 0.035, 0.015), 0.003), MD, Vector3(-sz.x * 0.18 + ix * 0.10, sz.y * 0.36 - sink - iy * 0.05, -sz.z * 0.5 - 0.014)))
	_meshes.append(A.add(self, A.bevel_box(Vector3(sz.x * 0.42, sz.y * 0.22, 0.05), 0.01), MD, Vector3(0, sz.y * 0.22 - sink, -sz.z * 0.5 - 0.026)))
	_meshes.append(A.add(self, A.bevel_box(Vector3(0.06, 0.10, 0.02), 0.004), MB, Vector3(sz.x * 0.22, sz.y * 0.22 - sink, -sz.z * 0.5 - 0.05)))
	_meshes.append(A.add(self, A.bevel_box(Vector3(sz.x + 0.03, 0.05, sz.z + 0.03), 0.01), MD, Vector3(0, sz.y - sink, 0)))


## 武器架：斜倚墙面的木制军械架，三条枪槽衬垫与铁丝缠锁
func _build_weapon(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.36, 0.27, 0.16), 0.08, 0.5)
	var MD := _worn(Color(0.14, 0.145, 0.155), 0.7, 0.5)
	var MB := _worn(Color(0.30, 0.30, 0.28), 0.3, 0.4)
	var body := Node3D.new()
	add_child(body)
	body.rotation_degrees = Vector3(-14, 0, 0)
	_meshes.append(A.add(body, A.bevel_box(sz, 0.02), M, Vector3(0, sz.y * 0.5 - sink, 0)))
	for i in 3:
		var rx := -sz.x * 0.32 + i * sz.x * 0.32
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.05, sz.y * 0.86, 0.05), 0.006), MD, Vector3(rx, sz.y * 0.5 - sink, -sz.z * 0.5 - 0.026)))
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.06, sz.y * 0.7, 0.10), 0.008), MD, Vector3(rx, sz.y * 0.46 - sink, -sz.z * 0.5 + 0.06)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.94, 0.05, 0.05), 0.006), MD, Vector3(0, sz.y * 0.8 - sink, -sz.z * 0.5 - 0.026)))
	for i in 4:
		_meshes.append(A.add(body, A.cyl(0.008, sz.z * 0.9, 0.008, 6), MB, Vector3(-sz.x * 0.4 + i * sz.x * 0.26, sz.y * 0.3 - sink, 0), Vector3(0, 90, 12 + i * 5)))


## 抛锚轿车：锈蚀轿车壳体，四轮歪斜、车窗炸裂、后备箱盖半开
func _build_car(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.30, 0.33, 0.30), 0.30, 0.62)
	var MD := _worn(Color(0.14, 0.145, 0.15), 0.7, 0.5)
	var MG := _worn(Color(0.48, 0.54, 0.54), 0.18, 0.08)
	var body := Node3D.new()
	add_child(body)
	body.rotation_degrees = Vector3(0, 0, 3)
	_meshes.append(A.add(body, A.bevel_box(sz, 0.10), M, Vector3(0, sz.y * 0.55 - sink, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.52, sz.y * 0.50, sz.z * 0.86), 0.06), M, Vector3(-sz.x * 0.02, sz.y * 0.92 - sink, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.40, sz.y * 0.28, sz.z * 0.80), 0.03), MD, Vector3(-sz.x * 0.02, sz.y * 1.06 - sink, 0)))
	for sx in [-1.0, 1.0]:
		for pz in [-1.0, 1.0]:
			_meshes.append(A.add(body, A.cyl(0.26, 0.18, 0.26, 12), MD, Vector3(sx * (sz.x * 0.5 - 0.06), 0.26 - sink, pz * sz.z * 0.36), Vector3(0, 0, 90)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.50, 0.05, sz.z * 0.55), 0.01), M, Vector3(sz.x * 0.30, sz.y * 1.16 - sink, 0), Vector3(0, 0, 35)))
	_m(A.bevel_box(Vector3(sz.x * 0.44, 0.30, 0.03), 0.01), MG, Vector3(-sz.x * 0.02, sz.y * 0.98 - sink, -sz.z * 0.5 - 0.01), Vector3.ONE, Vector3.ONE, false)
	_m(A.bevel_box(Vector3(sz.x * 0.30, 0.14, sz.z * 0.44), 0.02), MD, Vector3(sz.x * 0.30, 0.16 - sink, 0), Vector3(0, 22, 0), Vector3.ONE, false)


## 废弃集装箱：波纹钢板大箱体，双开对门缝、铅封挂锁与顶部锈蚀横梁
func _build_container(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.24, 0.36, 0.40), 0.35, 0.58)
	var MD := _worn(Color(0.13, 0.14, 0.14), 0.72, 0.55)
	var MB := _worn(Color(0.52, 0.44, 0.22), 0.80, 0.40)
	_meshes.append(A.add(self, A.bevel_box(sz, 0.03), M, Vector3(0, sz.y * 0.5 - sink, 0)))
	for i in int(sz.x / 0.28):
		var rx := -sz.x * 0.5 + 0.14 + i * 0.28
		_meshes.append(A.add(self, A.bevel_box(Vector3(0.05, sz.y * 0.96, sz.z * 0.98), 0.008), MD, Vector3(rx, sz.y * 0.5 - sink, 0)))
	_meshes.append(A.add(self, A.bevel_box(Vector3(sz.x + 0.04, 0.09, sz.z + 0.04), 0.01), MD, Vector3(0, sz.y - sink, 0)))
	_meshes.append(A.add(self, A.bevel_box(Vector3(0.05, sz.y * 0.90, sz.z + 0.02), 0.01), MD, Vector3(-sz.x * 0.5 - 0.02, sz.y * 0.5 - sink, 0)))
	for sx in [-0.12, 0.12]:
		_meshes.append(A.add(self, A.bevel_box(Vector3(0.10, sz.y * 0.86, 0.06), 0.01), MD, Vector3(sx, sz.y * 0.5 - sink, -sz.z * 0.5 - 0.03)))
	_meshes.append(A.add(self, A.cyl(0.05, 0.16, 0.05, 8), MB, Vector3(0, sz.y * 0.62 - sink, -sz.z * 0.5 - 0.06), Vector3(90, 0, 0)))
	_meshes.append(A.add(self, A.bevel_box(Vector3(0.18, 0.24, 0.05), 0.01), MB, Vector3(0, sz.y * 0.36 - sink, -sz.z * 0.5 - 0.04)))


## 埋藏桶：半埋进沙土的加固铁桶，双道铁箍与翘开的桶盖，旁边一堆沙
func _build_cache(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.34, 0.40, 0.28), 0.42, 0.6)
	var MD := _worn(Color(0.13, 0.14, 0.13), 0.72, 0.55)
	var C := A.concrete(Color(0.60, 0.55, 0.48), false)
	var cy := sz.y * 0.42 - sink
	_meshes.append(A.add(self, A.cyl(sz.x * 0.5, sz.y, sz.x * 0.5, 14), M, Vector3(0, cy, 0), Vector3(0, 0, 8)))
	for hy in [-0.18, 0.16]:
		_meshes.append(A.add(self, A.cyl(sz.x * 0.52, 0.045, sz.x * 0.52, 14), MD, Vector3(0, cy + hy, 0), Vector3(0, 0, 8)))
	_meshes.append(A.add(self, A.cyl(sz.x * 0.40, 0.06, sz.x * 0.40, 14), MD, Vector3(sz.x * 0.10, cy + sz.y * 0.5 - 0.02, 0), Vector3(0, 0, 14)))
	_m(A.bevel_box(Vector3(0.5, 0.18, 0.42), 0.05), C, Vector3(-sz.x * 0.6, 0.06, sz.z * 0.4), Vector3(0, 30, 0), Vector3.ONE, false)


## 敌对机械体残骸：撕裂的铸铁枪钢装甲壳、氧化锈蚀副板、断裂镀铬液压作动筒、黄铜伺服关节环与余温暗琥珀炉芯（移除旧紫色光条）
func _build_wreck(sz: Vector3) -> void:
	var M_GUN := _worn(Color(0.16, 0.18, 0.20), 0.72, 0.42)
	var M_RUST := _worn(Color(0.36, 0.21, 0.13), 0.52, 0.78)
	var M_BRASS := _worn(Color(0.56, 0.44, 0.22), 0.80, 0.32)
	var M_CHR := _worn(Color(0.62, 0.64, 0.66), 0.88, 0.18)
	var M_HAZ := _worn(Color(0.72, 0.52, 0.14), 0.25, 0.45)
	var m_core := A.emit(Color(0.95, 0.46, 0.12), 0.85)
	m_core.albedo_color = Color(0.28, 0.11, 0.03)
	A.ground_vfx(self, A.blob_tex(), Color(0.04, 0.04, 0.045, 0.82), sz.x * 1.85, Vector3(0, 0.036, 0), false, 0.34, false, 1)
	var yaw0 := _rng.randf() * 360.0
	var hulk := Node3D.new()
	add_child(hulk)
	hulk.rotation_degrees = Vector3(8, yaw0, -12)
	_meshes.append(A.add(hulk, A.bevel_box(Vector3(sz.x * 0.62, 0.28, sz.z * 0.48), 0.05, 0.82), M_GUN, Vector3(0, 0.14, 0)))
	_meshes.append(A.add(hulk, A.bevel_box(Vector3(sz.x * 0.44, 0.12, sz.z * 0.36), 0.03, 0.85), M_RUST, Vector3(-0.06, 0.28, 0.04), Vector3(0, 6, 4)))
	_meshes.append(A.add(hulk, A.bevel_box(Vector3(sz.x * 0.48, 0.06, 0.11), 0.01), M_HAZ, Vector3(0, 0.22, -sz.z * 0.24)))
	_meshes.append(A.add(hulk, A.cyl(0.16, 0.12, 0.18, 10), M_BRASS, Vector3(0.18, 0.26, -0.06), Vector3(14, 0, -18)))
	_meshes.append(A.add(hulk, A.cyl(0.09, 0.08, 0.09, 8), m_core, Vector3(0.18, 0.31, -0.06), Vector3(14, 0, -18)))
	for i in 2:
		var a := yaw0 * (PI / 180.0) + float(i) * 2.35 + _rng.randf_range(-0.3, 0.3)
		var lp := Vector3(cos(a) * 0.56, 0.09, sin(a) * 0.56)
		var lrot := Vector3(_rng.randf_range(-14, 14), rad_to_deg(-a), 14)
		_m(A.bevel_box(Vector3(0.14, 0.13, 0.78), 0.02, 0.85), M_GUN, lp, lrot)
		_m(A.cyl(0.055, 0.14, 0.055, 8), M_BRASS, lp + Vector3(0, 0.02, 0), lrot + Vector3(0, 0, 90))
		_m(A.cyl(0.026, 0.48, 0.026, 8), M_CHR, lp + Vector3(0, 0.06, 0), lrot + Vector3(82, 0, 0))
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
