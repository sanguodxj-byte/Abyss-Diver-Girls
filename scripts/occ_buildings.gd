extends RefCounted
## 整栋遮挡建筑平滑虚化管理器：
## - 地图构建完成、碰撞合并之前采集所有独立建筑/设施的精确世界 OBB（含预制件真实视觉包围盒，覆盖阳台/消防梯/屋顶设备）。
## - 战斗中视线穿过某栋建筑时，主镜头通道通过全局 OBB 裁切隐藏原合批网格（保留完整太阳阴影与地面），
##   同时按需懒提取该栋建筑的单壳双通道半透明代理（occ_bldg_depth + occ_bldg_ghost），
##   以零噪点、零内部重影的均匀半透明玻璃质感整栋平滑虚化（Forward+ 与 Forward Mobile 完全一致）。

const SH_DEPTH := preload("res://shaders/occ_bldg_depth.gdshader")
const SH_GHOST := preload("res://shaders/occ_bldg_ghost.gdshader")
const GRID_CELL := 24.0
const MAX_SLOTS := 2
const SLOT_POS_NAMES := [&"occ_box0_pos", &"occ_box1_pos"]
const SLOT_EXT_NAMES := [&"occ_box0_ext", &"occ_box1_ext"]

var _buildings: Array = []          ## Array[Dictionary]
var _grid: Dictionary = {}          ## Vector2i -> Array[int]
var _active: Dictionary = {}        ## bldg_idx -> float fade (0..1)
var _emissive_nodes: Array = []     ## 未合批的独立自发光招牌/红十字节点（用于随建筑同步淡出）
var _emissive_ready := false
var _depth_mat: ShaderMaterial = null
var _chunk_surf_cache: Dictionary = {}  ## mesh_rid_id -> Array[Array] 缓存 surface_get_arrays，消除重复回读
var _slot_pos: Array = [Vector4(-1, -1, -1, -1), Vector4(-1, -1, -1, -1)]
var _slot_ext: Array = [Vector4(-1, -1, -1, -1), Vector4(-1, -1, -1, -1)]
var _ghost_busy := false
var _ghost_slice_start := 0


func _set_slot_uniforms(slot: int, pv: Vector4, ev: Vector4) -> void:
	if _slot_pos[slot] != pv:
		_slot_pos[slot] = pv
		RenderingServer.global_shader_parameter_set(SLOT_POS_NAMES[slot], pv)
	if _slot_ext[slot] != ev:
		_slot_ext[slot] = ev
		RenderingServer.global_shader_parameter_set(SLOT_EXT_NAMES[slot], ev)


func clear() -> void:
	reset()
	for b: Dictionary in _buildings:
		var gr = b.get("ghost_root")
		if gr is Node and is_instance_valid(gr):
			(gr as Node).queue_free()
	_buildings.clear()
	_grid.clear()
	_emissive_nodes.clear()
	_emissive_ready = false
	_chunk_surf_cache.clear()


## 地图静态合批结束后立即调用：在加载阶段完成未合批自发光节点采集，避免实战首次建筑遮挡时触发全树扫描卡顿
func prepare(raid: Node3D) -> void:
	_ensure_emissive_cache(raid)


func reset() -> void:
	for slot in MAX_SLOTS:
		_set_slot_uniforms(slot, Vector4.ZERO, Vector4.ZERO)
	for idx in _active:
		if idx >= 0 and idx < _buildings.size():
			_set_bldg_visual(_buildings[idx], 0.0)
	_active.clear()


func active_count() -> int:
	return _active.size()


## 在 collision_opt 合并相邻静态体之前采集全图建筑精确 OBB
func collect(raid: Node3D) -> void:
	clear()
	if Net.is_dedicated_server() or raid == null or raid.world == null:
		return
	var stack: Array = [raid.world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			if ch is StaticBody3D:
				var sb := ch as StaticBody3D
				if sb.visible and (sb.collision_layer & 1) != 0:
					_try_register_body(sb)
			elif ch is Node3D and (ch as Node3D).visible and ch.get_script() == null and ch.get_groups().is_empty():
				stack.append(ch)


func _try_register_body(sb: StaticBody3D) -> void:
	var col_ab := AABB()
	var has_col := false
	for ch in sb.get_children():
		if ch is CollisionShape3D:
			var cs := ch as CollisionShape3D
			if cs.disabled or cs.shape == null:
				continue
			var sh_ab := _shape_local_aabb(cs.shape)
			if sh_ab.size == Vector3.ZERO:
				continue
			var t_ab: AABB = cs.transform * sh_ab
			col_ab = t_ab if not has_col else col_ab.merge(t_ab)
			has_col = true
	if not has_col:
		return

	var gxf := sb.global_transform
	var sx := gxf.basis.x.length()
	var sy := gxf.basis.y.length()
	var sz := gxf.basis.z.length()
	var c_sz := Vector3(col_ab.size.x * sx, col_ab.size.y * sy, col_ab.size.z * sz)
	var max_xz := maxf(c_sz.x, c_sz.z)
	if c_sz.y < 2.1 or max_xz < 2.2 or max_xz > 40.0:
		return

	var core_center_w: Vector3 = gxf * col_ab.get_center()
	var core_min_y := core_center_w.y - c_sz.y * 0.5
	if core_min_y > 2.8:
		return

	var fx := Vector2(gxf.basis.x.x, gxf.basis.x.z)
	if fx.length_squared() < 1e-6:
		fx = Vector2(1.0, 0.0)
	else:
		fx = fx.normalized()
	var yaw := atan2(-fx.y, fx.x)
	var cy := cos(yaw)
	var sy_a := sin(yaw)

	# 视觉包围盒：预制件建筑直接用精确网格 AABB（含阳台、消防梯、屋顶设备），POI 手搭墙体按屋顶附件适当外扩
	var vis_ab := col_ab
	var has_vis_meta := sb.has_meta("occ_vis_aabb")
	if has_vis_meta:
		var m_ab: AABB = sb.get_meta("occ_vis_aabb")
		vis_ab = vis_ab.merge(m_ab)
		# 预制件网格已自带精确外形，仅留极窄数值容差，绝不误切隔巷邻楼
		vis_ab = vis_ab.grow(0.16)
		vis_ab.size.y += 0.28
	else:
		for ch in sb.get_children():
			if ch is MeshInstance3D:
				var mi := ch as MeshInstance3D
				if mi.mesh != null:
					vis_ab = vis_ab.merge(mi.transform * mi.mesh.get_aabb())
		# POI 门诊楼等直墙结构：涵盖外挂窗框、红十字与屋顶机房（K.roof_kit）
		vis_ab.position.x -= 0.45
		vis_ab.position.z -= 0.45
		vis_ab.size.x += 0.90
		vis_ab.size.z += 0.90
		vis_ab.size.y += 2.80

	var v_sz := Vector3(vis_ab.size.x * sx, vis_ab.size.y * sy, vis_ab.size.z * sz)
	var v_center_w: Vector3 = gxf * vis_ab.get_center()
	var v_min_y := maxf(v_center_w.y - v_sz.y * 0.5, 0.22)
	var v_max_y := v_center_w.y + v_sz.y * 0.5
	if v_max_y <= v_min_y + 0.5:
		return
	var vis_center := Vector3(v_center_w.x, (v_min_y + v_max_y) * 0.5, v_center_w.z)
	var vis_half := Vector3(v_sz.x * 0.5, (v_max_y - v_min_y) * 0.5, v_sz.z * 0.5)

	var core_half := Vector3(c_sz.x * 0.5 + 0.08, c_sz.y * 0.5 + 0.12, c_sz.z * 0.5 + 0.08)
	var wx_ext := absf(cy) * vis_half.x + absf(sy_a) * vis_half.z
	var wz_ext := absf(sy_a) * vis_half.x + absf(cy) * vis_half.z
	var w_aabb := AABB(
		Vector3(vis_center.x - wx_ext, v_min_y, vis_center.z - wz_ext),
		Vector3(wx_ext * 2.0, v_max_y - v_min_y, wz_ext * 2.0)
	)

	var idx := _buildings.size()
	var rec := {
		"idx": idx,
		"center": vis_center,
		"half": vis_half,
		"core_center": core_center_w,
		"core_half": core_half,
		"yaw": yaw,
		"cy": cy,
		"sy": sy_a,
		"world_aabb": w_aabb,
		"ghost_built": false,
		"ghost_root": null,
		"ghost_mats": [],
		"extra_emits": [],
	}
	_buildings.append(rec)

	var gx0 := floori(w_aabb.position.x / GRID_CELL)
	var gx1 := floori(w_aabb.end.x / GRID_CELL)
	var gz0 := floori(w_aabb.position.z / GRID_CELL)
	var gz1 := floori(w_aabb.end.z / GRID_CELL)
	for gz in range(gz0, gz1 + 1):
		for gx in range(gx0, gx1 + 1):
			var key := Vector2i(gx, gz)
			var arr: Array = _grid.get(key, [])
			arr.append(idx)
			_grid[key] = arr


static func _shape_local_aabb(sh: Shape3D) -> AABB:
	if sh is BoxShape3D:
		var sz := (sh as BoxShape3D).size
		return AABB(-sz * 0.5, sz)
	if sh is CylinderShape3D:
		var cs := sh as CylinderShape3D
		var r := cs.radius
		var h := cs.height
		return AABB(Vector3(-r, -h * 0.5, -r), Vector3(r * 2.0, h, r * 2.0))
	return AABB()


static func _point_in_obb(p: Vector3, b: Dictionary) -> bool:
	var c: Vector3 = b["center"]
	var h: Vector3 = b["half"]
	var d := p - c
	if absf(d.y) > h.y:
		return false
	var cy: float = float(b["cy"])
	var sy: float = float(b["sy"])
	var lx := d.x * cy - d.z * sy
	var lz := d.x * sy + d.z * cy
	return absf(lx) <= h.x and absf(lz) <= h.z


## 射线与建筑核心 OBB（未外扩）相交测试，返回命中参数 t in (0, 1)，未命中返回 -1.0
static func _ray_hit_core(ray_from: Vector3, ray_to: Vector3, b: Dictionary) -> float:
	var c: Vector3 = b["core_center"]
	var h: Vector3 = b["core_half"]
	var cy: float = float(b["cy"])
	var sy: float = float(b["sy"])
	var d0 := ray_from - c
	var d1 := ray_to - c
	var p0 := Vector3(d0.x * cy - d0.z * sy, d0.y, d0.x * sy + d0.z * cy)
	var p1 := Vector3(d1.x * cy - d1.z * sy, d1.y, d1.x * sy + d1.z * cy)
	var rv := p1 - p0
	var tmin := 0.0
	var tmax := 1.0
	for axis in 3:
		var o: float = p0[axis]
		var dv: float = rv[axis]
		var ext: float = h[axis]
		if absf(dv) < 1e-6:
			if o < -ext or o > ext:
				return -1.0
		else:
			var inv_d := 1.0 / dv
			var t0 := (-ext - o) * inv_d
			var t1 := (ext - o) * inv_d
			if t0 > t1:
				var tmp := t0
				t0 = t1
				t1 = tmp
			tmin = maxf(tmin, t0)
			tmax = minf(tmax, t1)
			if tmin > tmax:
				return -1.0
	if tmin <= 0.001 or tmin >= 0.98:
		return -1.0
	return tmin


func _find_hit_buildings(cam_p: Vector3, mp: Vector3, probes: Array) -> Array:
	if _buildings.is_empty():
		return []
	var mn_x := minf(cam_p.x, mp.x) - 3.0
	var mx_x := maxf(cam_p.x, mp.x) + 3.0
	var mn_z := minf(cam_p.z, mp.z) - 3.0
	var mx_z := maxf(cam_p.z, mp.z) + 3.0
	var gx0 := floori(mn_x / GRID_CELL)
	var gx1 := floori(mx_x / GRID_CELL)
	var gz0 := floori(mn_z / GRID_CELL)
	var gz1 := floori(mx_z / GRID_CELL)
	var tested := {}
	var hits: Array = [] # [t_best, bldg_idx]
	for gz in range(gz0, gz1 + 1):
		for gx in range(gx0, gx1 + 1):
			var bucket = _grid.get(Vector2i(gx, gz))
			if bucket == null:
				continue
			for idx: int in bucket:
				if tested.has(idx):
					continue
				tested[idx] = true
				var b: Dictionary = _buildings[idx]
				var best_t := 2.0
				for tp: Vector3 in probes:
					var seg := tp - cam_p
					var sl := seg.length()
					if sl <= 0.8:
						continue
					var r_to := tp - (seg / sl) * 0.35
					var th := _ray_hit_core(cam_p, r_to, b)
					if th > 0.0 and th < best_t:
						best_t = th
				if best_t < 1.5:
					hits.append([best_t, idx])
	hits.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: Array = []
	for h in hits:
		out.append(int(h[1]))
		if out.size() >= MAX_SLOTS:
			break
	return out


## 每帧更新整栋遮挡建筑的半透明代理与全局 OBB 裁切参数；返回是否需要执行非盒体结构的物理射线兜底检测
func update(raid: Node3D, delta: float, cam_p: Vector3, mp: Vector3, probes: Array) -> bool:
	var hit_ids := _find_hit_buildings(cam_p, mp, probes)
	var hit_set := {}
	for idx: int in hit_ids:
		hit_set[idx] = true
		if not _active.has(idx):
			if _active.size() >= MAX_SLOTS:
				# 优先替换掉正在淡出且透明度最低的旧槽位
				var drop_id := -1
				var drop_v := 2.0
				for k: int in _active:
					if not hit_set.has(k) and float(_active[k]) < drop_v:
						drop_v = float(_active[k])
						drop_id = k
				if drop_id >= 0:
					_set_bldg_visual(_buildings[drop_id], 0.0)
					_active.erase(drop_id)
				else:
					continue
			_active[idx] = 0.0

	var to_erase: Array = []
	var built_this_frame := false
	for idx: int in _active:
		var want := 1.0 if hit_set.has(idx) else 0.0
		var spd := 11.0 if want > 0.5 else 7.5
		var cur := lerpf(float(_active[idx]), want, clampf(delta * spd, 0.0, 1.0))
		if cur < 0.006 and want == 0.0:
			cur = 0.0
			to_erase.append(idx)
		_active[idx] = cur
		var b: Dictionary = _buildings[idx]
		if cur > 0.005 and not bool(b["ghost_built"]):
			if built_this_frame or _ghost_busy:
				continue
			built_this_frame = true
			_ensure_ghost(raid, b, raid.get_tree())
			if not bool(b["ghost_built"]): continue
		_set_bldg_visual(b, cur)
	for idx: int in to_erase:
		_active.erase(idx)

	# 推送至全局 shader uniform（最多 2 栋建筑同步整栋虚化）
	var active_keys: Array = _active.keys()
	for slot in MAX_SLOTS:
		if slot < active_keys.size():
			var idx: int = int(active_keys[slot])
			var fade: float = float(_active[idx])
			if fade > 0.005 and bool(_buildings[idx]["ghost_built"]):
				var b: Dictionary = _buildings[idx]
				var c: Vector3 = b["center"]
				var h: Vector3 = b["half"]
				_set_slot_uniforms(slot, Vector4(c.x, c.y, c.z, 1.0), Vector4(h.x, h.y, h.z, float(b["yaw"])))
				continue
		_set_slot_uniforms(slot, Vector4.ZERO, Vector4.ZERO)

	return hit_ids.is_empty() and _active.is_empty()


func _set_bldg_visual(b: Dictionary, fade: float) -> void:
	var gr = b.get("ghost_root")
	var show := fade > 0.005
	if gr is Node3D and is_instance_valid(gr):
		(gr as Node3D).visible = show
	if show:
		# fade: 0 -> 1 对应透明度 alpha: 1.0 -> 0.18（轻盈通透整栋玻璃虚化，零跳变）
		var alpha := lerpf(1.0, 0.18, fade)
		for gm in (b["ghost_mats"] as Array):
			if is_instance_valid(gm):
				(gm as ShaderMaterial).set_shader_parameter("ghost_alpha", alpha)
	for em_n in (b["extra_emits"] as Array):
		if is_instance_valid(em_n):
			(em_n as Node3D).visible = not show


func _ensure_emissive_cache(raid: Node3D) -> void:
	if _emissive_ready:
		return
	_emissive_ready = true
	_emissive_nodes.clear()
	if raid == null or raid.world == null:
		return
	var rb = raid._rb() if raid.has_method("_rb") else null
	var stack: Array = [raid.world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			if ch == rb or ch.get_script() != null or not ch.get_groups().is_empty():
				continue
			if ch is MeshInstance3D:
				var mi := ch as MeshInstance3D
				if mi.visible and mi.mesh != null:
					var mo: Material = mi.material_override
					if mo is StandardMaterial3D and (mo as StandardMaterial3D).emission_enabled:
						_emissive_nodes.append(mi)
			elif ch is Node3D and (ch as Node3D).visible:
				stack.append(ch)


func _get_ghost_mat(b: Dictionary, mat_cache: Dictionary, col: Color, t_mode: int) -> ShaderMaterial:
	var key := "%d|%s" % [t_mode, col.to_html(false)]
	var existing: ShaderMaterial = mat_cache.get(key)
	if existing != null:
		return existing
	if _depth_mat == null:
		_depth_mat = ShaderMaterial.new()
		_depth_mat.shader = SH_DEPTH
		_depth_mat.render_priority = 8
	var p1 := ShaderMaterial.new()
	p1.shader = SH_DEPTH
	p1.render_priority = 8
	var p2 := ShaderMaterial.new()
	p2.shader = SH_GHOST
	p2.render_priority = 9
	p2.set_shader_parameter("base_color", Color(col.r, col.g, col.b, 1.0))
	p2.set_shader_parameter("tint_mode", t_mode)
	p2.set_shader_parameter("ghost_alpha", 1.0)
	p1.next_pass = p2
	mat_cache[key] = p1
	(b["ghost_mats"] as Array).append(p2)
	return p1


static func _is_foliage_mat(m: Material) -> bool:
	if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
		return (m as ShaderMaterial).shader.resource_path.contains("foliage")
	return false


static func _mat_color_and_mode(m: Material, is_mm: bool, mm_col: Color, mm_has_tint: bool) -> Array:
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		var rp := sm.shader.resource_path if sm.shader != null else ""
		if rp.contains("ind_glass"):
			return [Color(0.20, 0.25, 0.30), 0]
		if rp.contains("mech_paint"):
			var tm_v = sm.get_shader_parameter("tint_mode")
			var tm := int(tm_v) if tm_v != null else 0
			var bc_v = sm.get_shader_parameter("base_color")
			var bc: Color = bc_v if bc_v is Color else Color(0.50, 0.49, 0.46)
			if is_mm and tm == 1 and mm_has_tint:
				return [Color(mm_col.r, mm_col.g, mm_col.b), 0]
			if tm == 2 or tm == 3:
				return [Color(bc.r, bc.g, bc.b), 1]
			return [Color(bc.r, bc.g, bc.b), 0]
	if m is StandardMaterial3D:
		var std := m as StandardMaterial3D
		if is_mm and mm_has_tint:
			return [Color(mm_col.r, mm_col.g, mm_col.b), 0]
		var c := std.albedo_color
		if std.emission_enabled:
			c = c.lerp(std.emission, 0.55)
		return [Color(c.r, c.g, c.b), 2 if std.vertex_color_use_as_albedo else 0]
	return [Color(0.50, 0.49, 0.46), 0]


## 按需懒提取单栋遮挡建筑的几何代理（MultiMesh 直接零拷贝复用 Mesh，合批 Chunk 按三角形质心裁入轻量 ArrayMesh）
func _ensure_ghost(raid: Node3D, b: Dictionary, tree: SceneTree = null) -> void:
	_ghost_busy = true
	_ghost_slice_start = Time.get_ticks_usec()
	var root := Node3D.new()
	root.name = "OccGhost_%d" % int(b["idx"])
	root.visible = false
	raid.add_child(root)
	b["ghost_root"] = root

	var mat_cache := {}
	var rb = raid._rb() if raid.has_method("_rb") else null
	if rb == null:
		_ghost_busy = false
		return
	var chunks: Dictionary = rb.get("_chunks") if rb.get("_chunks") is Dictionary else {}
	var ch_sz: float = float(rb.CHUNK)
	var wab: AABB = b["world_aabb"]
	var cx0 := floori(wab.position.x / ch_sz)
	var cx1 := floori(wab.end.x / ch_sz)
	var cz0 := floori(wab.position.z / ch_sz)
	var cz1 := floori(wab.end.z / ch_sz)

	for cz in range(cz0, cz1 + 1):
		for cx in range(cx0, cx1 + 1):
			var ch = chunks.get(Vector2i(cx, cz))
			if ch == null:
				continue
			var ch_node: Node = ch.get("node")
			if ch_node == null or not is_instance_valid(ch_node):
				continue
			for ch_item in ch_node.get_children():
				if ch_item is MultiMeshInstance3D:
					await _extract_from_multimesh(ch_item as MultiMeshInstance3D, b, root, mat_cache, tree)
				elif ch_item is MeshInstance3D:
					await _extract_from_chunk_mesh(ch_item as MeshInstance3D, b, root, mat_cache, tree)
				if not is_instance_valid(root):
					_ghost_busy = false
					return
				if tree != null and Time.get_ticks_usec() - _ghost_slice_start >= 1200:
					await tree.process_frame
					if not is_instance_valid(root):
						_ghost_busy = false
						return
					_ghost_slice_start = Time.get_ticks_usec()

	# 同步收录该建筑内未合批的独立自发光招牌/红十字（如城南医院红十字）
	_ensure_emissive_cache(raid)
	for em_mi: MeshInstance3D in _emissive_nodes:
		if not is_instance_valid(em_mi) or em_mi.mesh == null:
			continue
		var em_c := (em_mi.global_transform * em_mi.mesh.get_aabb()).get_center()
		if em_c.y > 0.22 and _point_in_obb(em_c, b):
			(b["extra_emits"] as Array).append(em_mi)
			var cm := _mat_color_and_mode(em_mi.material_override, false, Color.WHITE, false)
			var gmi := MeshInstance3D.new()
			gmi.mesh = em_mi.mesh
			gmi.transform = em_mi.global_transform
			gmi.material_override = _get_ghost_mat(b, mat_cache, cm[0] as Color, int(cm[1]))
			gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(gmi)
	b["ghost_built"] = true
	_ghost_busy = false


func _extract_from_multimesh(mmi: MultiMeshInstance3D, b: Dictionary, root: Node3D, mat_cache: Dictionary, tree: SceneTree = null) -> void:
	var mm := mmi.multimesh
	if mm == null or mm.mesh == null or mm.instance_count <= 0:
		return
	var mat := mmi.material_override
	if _is_foliage_mat(mat):
		return
	var wab: AABB = b["world_aabb"]
	if not (mmi.global_transform * mmi.get_aabb()).intersects(wab):
		return
	var ma := mm.mesh.get_aabb()
	var gxf := mmi.global_transform
	var use_cd := mm.use_custom_data
	var use_col := mm.use_colors
	for i in mm.instance_count:
		if tree != null and i % 32 == 0 and Time.get_ticks_usec() - _ghost_slice_start >= 1200:
			await tree.process_frame
			if not is_instance_valid(root): return
			_ghost_slice_start = Time.get_ticks_usec()
		var ixf := gxf * mm.get_instance_transform(i)
		var ac := (ixf * ma).get_center()
		if ac.y <= 0.22 or not _point_in_obb(ac, b):
			continue
		var inst_col := Color.WHITE
		var has_tint := false
		if use_cd:
			inst_col = mm.get_instance_custom_data(i)
			has_tint = true
		elif use_col:
			inst_col = mm.get_instance_color(i)
			has_tint = true
		var cm := _mat_color_and_mode(mat, true, inst_col, has_tint)
		var gmi := MeshInstance3D.new()
		gmi.mesh = mm.mesh
		gmi.transform = ixf
		gmi.material_override = _get_ghost_mat(b, mat_cache, cm[0] as Color, int(cm[1]))
		gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(gmi)


func _extract_from_chunk_mesh(mi: MeshInstance3D, b: Dictionary, root: Node3D, mat_cache: Dictionary, tree: SceneTree = null) -> void:
	if mi.mesh == null:
		return
	var mat := mi.material_override
	if _is_foliage_mat(mat):
		return
	var wab: AABB = b["world_aabb"]
	var mi_ab := mi.global_transform * mi.mesh.get_aabb()
	if not mi_ab.intersects(wab):
		return
	var gxf := mi.global_transform
	var is_id := gxf.is_equal_approx(Transform3D.IDENTITY)
	var bc: Vector3 = b["center"]
	var bh: Vector3 = b["half"]
	var cy: float = float(b["cy"])
	var sy: float = float(b["sy"])
	var wx0: float = wab.position.x
	var wx1: float = wab.end.x
	var wy1: float = wab.end.y
	var wz0: float = wab.position.z
	var wz1: float = wab.end.z
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_c := PackedColorArray()
	var has_any_c := false

	var mesh_rid := mi.mesh.get_rid().get_id()
	var cached_surfs = _chunk_surf_cache.get(mesh_rid)
	if cached_surfs == null:
		cached_surfs = []
		for si in mi.mesh.get_surface_count():
			cached_surfs.append(mi.mesh.surface_get_arrays(si))
		_chunk_surf_cache[mesh_rid] = cached_surfs

	for arr: Array in cached_surfs:
		if arr.is_empty() or arr[Mesh.ARRAY_VERTEX] == null:
			continue
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var has_n := norms.size() == verts.size()
		var has_c := cols.size() == verts.size()
		var use_idx := idx.size() > 0
		var tri_cnt := (idx.size() / 3) if use_idx else (verts.size() / 3)
		for t in tri_cnt:
			if tree != null and t % 128 == 0 and Time.get_ticks_usec() - _ghost_slice_start >= 1200:
				await tree.process_frame
				if not is_instance_valid(root): return
				_ghost_slice_start = Time.get_ticks_usec()
			var t3 := t * 3
			var i0 := idx[t3] if use_idx else t3
			var i1 := idx[t3 + 1] if use_idx else t3 + 1
			var i2 := idx[t3 + 2] if use_idx else t3 + 2
			var v0 := verts[i0] if is_id else (gxf * verts[i0])
			var v1 := verts[i1] if is_id else (gxf * verts[i1])
			var v2 := verts[i2] if is_id else (gxf * verts[i2])
			var tcx := (v0.x + v1.x + v2.x) * 0.33333334
			if tcx < wx0 or tcx > wx1:
				continue
			var tcz := (v0.z + v1.z + v2.z) * 0.33333334
			if tcz < wz0 or tcz > wz1:
				continue
			var tcy := (v0.y + v1.y + v2.y) * 0.33333334
			if tcy <= 0.22 or tcy > wy1 or absf(tcy - bc.y) > bh.y:
				continue
			var dx := tcx - bc.x
			var dz := tcz - bc.z
			if absf(dx * cy - dz * sy) > bh.x or absf(dx * sy + dz * cy) > bh.z:
				continue
			out_v.append(v0)
			out_v.append(v1)
			out_v.append(v2)
			if has_n:
				out_n.append(norms[i0] if is_id else (gxf.basis * norms[i0]).normalized())
				out_n.append(norms[i1] if is_id else (gxf.basis * norms[i1]).normalized())
				out_n.append(norms[i2] if is_id else (gxf.basis * norms[i2]).normalized())
			else:
				var gn := (v1 - v0).cross(v2 - v0)
				gn = -gn.normalized() if gn.length_squared() > 1e-10 else Vector3.UP
				out_n.append(gn)
				out_n.append(gn)
				out_n.append(gn)
			if has_c:
				has_any_c = true
				out_c.append(cols[i0])
				out_c.append(cols[i1])
				out_c.append(cols[i2])
			else:
				out_c.append(Color.WHITE)
				out_c.append(Color.WHITE)
				out_c.append(Color.WHITE)

	if out_v.is_empty():
		return
	var surf_arr := []
	surf_arr.resize(Mesh.ARRAY_MAX)
	surf_arr[Mesh.ARRAY_VERTEX] = out_v
	surf_arr[Mesh.ARRAY_NORMAL] = out_n
	if has_any_c:
		surf_arr[Mesh.ARRAY_COLOR] = out_c
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surf_arr)
	var cm := _mat_color_and_mode(mat, false, Color.WHITE, false)
	var t_mode := int(cm[1]) if has_any_c else 0
	var gmi := MeshInstance3D.new()
	gmi.mesh = am
	gmi.material_override = _get_ghost_mat(b, mat_cache, cm[0] as Color, t_mode)
	gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(gmi)
