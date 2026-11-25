extends RefCounted
## 三层远景不透明 HLOD 与连续城市群外围天际线构建器（Tier-1 分块 HLOD + Tier-2 8 扇区外围天际线）
## - Tier-1（地图内及外围 290m 远景带）：按 RenderBatch 48m 分块 1:1 对齐合并静态建筑、预制件、地标与乔木的极简不透明体块，
##   仅在 FPS 模式下且对应分块详细几何流式关闭（ch.on == false）时显示，彻底消除 128m~155m 整栋消失、屋顶悬空与远树发虚。
## - Tier-2（300m~760m 外围城市群）：仅地表地图生成 8 个 45° 扇区网格（VistaOuter_0..7），真实复现相邻战区标志性地标/高大遗迹
##   并按 world_city.gd 的确定性区划/河湖/东湾海岸线生成无缝延伸的城市天际线、工业烟囱与林带。
## - 全部网格共用单一纯不透明 vista_hlod.gdshader（零贴图、零 Alpha 裁切、关闭阴影与 GI、设置 no_outline 避免描边糊成黑团）；
##   TPS 俯视模式下全部隐藏，零 Draw Call、零面数、零 GPU 开销。

const RB = preload("res://scripts/render_batch.gd")
const WC = preload("res://scripts/world_city.gd")
const PrefabLib = preload("res://scripts/buildings/prefab_lib.gd")
const VISTA_SHADER := preload("res://shaders/vista_hlod.gdshader")

const KIND_BLDG := 0
const KIND_IND := 1
const KIND_PINE := 2
const KIND_BROAD := 3

const OUTER_SECTORS := 8
const OUTER_MAX_R := 760.0
const OUTER_LM_MAX_R := 780.0

static var _shared_mat: ShaderMaterial = null

var _boxes: Array = []
var _cyls: Array = []
var _gables: Array = []
var _prefabs: Array = []
var _trees: Array = []

var _hlod_root: Node3D = null
var _outer_root: Node3D = null
var stats := {"hlod_chunks": 0, "outer_sectors": 0, "boxes": 0, "prefabs": 0, "trees": 0, "outer_items": 0}


static func shared_mat() -> ShaderMaterial:
	if _shared_mat == null:
		var m := ShaderMaterial.new()
		m.shader = VISTA_SHADER
		m.set_meta("no_outline", true)
		_shared_mat = m
	return _shared_mat


## 同步当前战区/天气的天际线大气透视雾化色与起止距离，使 Tier-1/2 远景与天空/深度雾无缝衔接
static func set_haze(col: Color, start_d := 155.0, end_d := 740.0, strength := 0.68) -> void:
	var m := shared_mat()
	m.set_shader_parameter("horizon_haze_col", col)
	m.set_shader_parameter("haze_start", start_d)
	m.set_shader_parameter("haze_end", end_d)
	m.set_shader_parameter("haze_strength", clampf(strength, 0.0, 0.92))


static func _track_owner(owner: Node3D) -> int:
	# 仅跟踪 StaticBody3D 的 instance_id（landmarks._clear_aprons 只删除 StaticBody3D）；
	# 用 int ID 彻底规避 Godot 4 中已释放对象 `freed_obj == null` 为真的陷阱，同时 _bake_static 释放普通空 Node3D 容器不会误删 HLOD。
	return owner.get_instance_id() if (owner != null and owner is StaticBody3D) else 0


static func _owner_alive(owner_id: int) -> bool:
	if owner_id == 0:
		return true
	var obj: Object = instance_from_id(owner_id)
	if obj == null or not is_instance_valid(obj):
		return false
	return not (obj as Node).is_queued_for_deletion()


static func _pos_seed(x: float, z: float, salt := 97) -> float:
	return WC.h2(int(floor(x * 0.5)), int(floor(z * 0.5)), salt)


static func _kind_uv_x(kind: int) -> float:
	if kind >= KIND_PINE:
		return 1.0
	if kind == KIND_IND:
		return 0.5
	return 0.0


static func _pack_col(col: Color, seed: float) -> Color:
	return Color(clampf(col.r, 0.02, 1.0), clampf(col.g, 0.02, 1.0), clampf(col.b, 0.02, 1.0), clampf(seed, 0.0, 1.0))


## 注册通用矩形体块（pos 为盒体中心；sz = (w, h, d)；yaw_rad 对应 Godot rotation.y；kind: 0=城区建筑 1=工业/巨构）
func add_box(pos: Vector3, sz: Vector3, yaw_rad: float, col: Color, kind := 0, owner: Node3D = null) -> void:
	if maxf(sz.x, sz.z) < 0.75 or sz.y < 0.75:
		return
	_boxes.append([pos, sz, yaw_rad, col, kind, _track_owner(owner)])


## 注册圆柱/烟囱/储罐/灯塔筒体（pos 为圆柱中心；kind 默认 1 工业）
func add_cyl(pos: Vector3, radius: float, height: float, col: Color, kind := 1, segs := 8, owner: Node3D = null) -> void:
	if radius < 0.35 or height < 0.75:
		return
	_cyls.append([pos, radius, height, col, kind, clampi(segs, 6, 12), _track_owner(owner)])


## 注册人字坡屋顶（pos 为檐口底面中心；sz = (脊长 X, 屋脊高 Y, 跨度 Z)；yaw_rad 对应 Godot rotation.y）
func add_gable(pos: Vector3, sz: Vector3, yaw_rad: float, col: Color, kind := 0, owner: Node3D = null) -> void:
	if sz.x < 1.0 or sz.y < 0.5 or sz.z < 1.0:
		return
	_gables.append([pos, sz, yaw_rad, col, kind, _track_owner(owner)])


## 注册预制建筑/地标/POI（由 PrefabLib 自动调用；finalize 时延迟展开 get_hlod_boxes 并按 owner 裁剪已清场建筑）
func add_prefab(id: String, xf: Transform3D, tint := Color.WHITE, owner: Node3D = null) -> void:
	if id.is_empty():
		return
	_prefabs.append([id, xf, tint, _track_owner(owner)])


## 注册远景乔木（pos 为地面根部 y=0；h 为总高；cr 为冠半径；kind: 2=针叶松杉 3=阔叶/秋叶树）
func add_tree(pos: Vector3, h: float, cr: float, kind := 2, col := Color(0.18, 0.28, 0.14)) -> void:
	if h < 2.2 or cr < 0.8:
		return
	_trees.append([pos, h, cr, kind, col])


## 在 raid._bake_static 完成（且 rb.build_all 已执行）后调用：提交 Tier-1 分块 HLOD 与 Tier-2 8 扇区外围天际线
func finalize(raid, rb) -> void:
	var t0 := Time.get_ticks_usec()
	var mat := shared_mat()
	var world_node: Node3D = raid.world

	# ---- Tier-1: 与 RenderBatch 48m 分块 1:1 对齐的静态 HLOD ----
	_hlod_root = Node3D.new()
	_hlod_root.name = "VistaHLOD"
	world_node.add_child(_hlod_root)

	var chunk_sts: Dictionary = {}
	var box_cnt := 0
	var pf_cnt := 0
	var tree_cnt := 0

	for rec_v in _boxes:
		var rec: Array = rec_v as Array
		if not _owner_alive(int(rec[5])):
			continue
		var pos: Vector3 = rec[0]
		var sz: Vector3 = rec[1]
		var yaw: float = float(rec[2])
		var col: Color = rec[3]
		var kind: int = int(rec[4])
		var ck: Vector2i = RB.chunk_of(pos)
		var st := _get_st(chunk_sts, ck)
		var seed := _pos_seed(pos.x, pos.z, 101)
		_emit_box_yaw(st, pos, sz, yaw, _kind_uv_x(kind), _pack_col(col, seed))
		box_cnt += 1

	for rec_v in _cyls:
		var rec: Array = rec_v as Array
		if not _owner_alive(int(rec[6])):
			continue
		var pos: Vector3 = rec[0]
		var rad: float = float(rec[1])
		var h: float = float(rec[2])
		var col: Color = rec[3]
		var kind: int = int(rec[4])
		var segs: int = int(rec[5])
		var ck: Vector2i = RB.chunk_of(pos)
		var st := _get_st(chunk_sts, ck)
		var seed := _pos_seed(pos.x, pos.z, 107)
		_emit_cyl(st, pos, rad, h, _kind_uv_x(kind), _pack_col(col, seed), segs)
		box_cnt += 1

	for rec_v in _gables:
		var rec: Array = rec_v as Array
		if not _owner_alive(int(rec[5])):
			continue
		var pos: Vector3 = rec[0]
		var sz: Vector3 = rec[1]
		var yaw: float = float(rec[2])
		var col: Color = rec[3]
		var kind: int = int(rec[4])
		var ck: Vector2i = RB.chunk_of(pos)
		var st := _get_st(chunk_sts, ck)
		var seed := _pos_seed(pos.x, pos.z, 113)
		_emit_gable(st, pos, sz, yaw, _kind_uv_x(kind), _pack_col(col, seed))
		box_cnt += 1

	for rec_v in _prefabs:
		var rec: Array = rec_v as Array
		if not _owner_alive(int(rec[3])):
			continue
		var id: String = str(rec[0])
		var xf: Transform3D = rec[1]
		var tint: Color = rec[2]
		var boxes: Array = PrefabLib.get_hlod_boxes(id)
		if boxes.is_empty():
			continue
		# 整栋预制件的所有 HLOD 盒统一落入 RB.chunk_of(xf.origin)，与 RenderBatch.add_inst 的分块归属 100% 原子一致
		var ck: Vector2i = RB.chunk_of(xf.origin)
		var st := _get_st(chunk_sts, ck)
		var seed := _pos_seed(xf.origin.x, xf.origin.z, 127)
		var has_tint := not tint.is_equal_approx(Color.WHITE)

		var y_min := INF
		var y_max := -INF
		for b_v in boxes:
			var b: Dictionary = b_v as Dictionary
			var bp: Vector3 = xf * (b["pos"] as Vector3)
			var bsz: Vector3 = b["sz"]
			var ax: Vector3 = xf.basis * Vector3(bsz.x * 0.5, 0.0, 0.0)
			var ay: Vector3 = xf.basis * Vector3(0.0, bsz.y * 0.5, 0.0)
			var az: Vector3 = xf.basis * Vector3(0.0, 0.0, bsz.z * 0.5)
			var ey: float = absf(ax.y) + absf(ay.y) + absf(az.y)
			y_min = minf(y_min, bp.y - ey)
			y_max = maxf(y_max, bp.y + ey)
		var y_inv_h: float = 1.0 / maxf(0.5, y_max - y_min)

		for b_v in boxes:
			var b: Dictionary = b_v as Dictionary
			var bp: Vector3 = xf * (b["pos"] as Vector3)
			var bsz: Vector3 = b["sz"]
			var ax: Vector3 = xf.basis * Vector3(bsz.x * 0.5, 0.0, 0.0)
			var ay: Vector3 = xf.basis * Vector3(0.0, bsz.y * 0.5, 0.0)
			var az: Vector3 = xf.basis * Vector3(0.0, 0.0, bsz.z * 0.5)
			var bcol: Color = tint if (has_tint and bool(b["tintable"])) else (b["col"] as Color)
			_emit_obb(st, bp, ax, ay, az, _kind_uv_x(int(b["kind"])), _pack_col(bcol, seed), y_min, y_inv_h)
		pf_cnt += 1

	for rec_v in _trees:
		var rec: Array = rec_v as Array
		var pos: Vector3 = rec[0]
		var h: float = float(rec[1])
		var cr: float = float(rec[2])
		var kind: int = int(rec[3])
		var col: Color = rec[4]
		var ck: Vector2i = RB.chunk_of(pos)
		var st := _get_st(chunk_sts, ck)
		var seed := _pos_seed(pos.x, pos.z, 139)
		_emit_tree(st, pos, h, cr, kind, _pack_col(col, seed), true)
		tree_cnt += 1

	var hlod_chunks := 0
	for ck_v in chunk_sts:
		var ck: Vector2i = ck_v as Vector2i
		var st: SurfaceTool = chunk_sts[ck] as SurfaceTool
		st.index()
		var am: ArrayMesh = st.commit()
		if am == null or am.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "HLOD_%d_%d" % [ck.x, ck.y]
		mi.mesh = am
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.visible = false
		_hlod_root.add_child(mi)
		if rb != null and rb.has_method("set_chunk_hlod"):
			rb.set_chunk_hlod(ck, mi)
		hlod_chunks += 1

	# 释放暂存数组，避免占用常驻内存
	_boxes.clear()
	_cyls.clear()
	_gables.clear()
	_prefabs.clear()
	_trees.clear()

	# ---- Tier-2: 地表连续城市群 300m~760m 8 扇区外围天际线 ----
	var outer_sectors := 0
	var outer_items := 0
	if bool(raid.get("is_surface_map")):
		var outer_res := _build_outer_skyline(raid, world_node, mat)
		outer_sectors = int(outer_res[0])
		outer_items = int(outer_res[1])

	if rb != null and rb.has_method("set_vista"):
		rb.set_vista(self)

	stats.hlod_chunks = hlod_chunks
	stats.outer_sectors = outer_sectors
	stats.boxes = box_cnt
	stats.prefabs = pf_cnt
	stats.trees = tree_cnt
	stats.outer_items = outer_items
	var dt_ms := int((Time.get_ticks_usec() - t0) / 1000)
	print("[vista] hlod_chunks=%d outer_sectors=%d (boxes=%d prefabs=%d trees=%d outer=%d) in %dms" % [
		hlod_chunks, outer_sectors, box_cnt, pf_cnt, tree_cnt, outer_items, dt_ms
	])


func set_outer_visible(on: bool) -> void:
	if _outer_root != null and is_instance_valid(_outer_root):
		_outer_root.visible = on


# ---------------------------------------------------------------- Tier-2 连续城市群外围天际线（300m~760m）
func _build_outer_skyline(raid, world_node: Node3D, mat: ShaderMaterial) -> Array:
	_outer_root = Node3D.new()
	_outer_root.name = "VistaOuter"
	_outer_root.visible = false
	world_node.add_child(_outer_root)

	var map_id: String = str(raid.get("map_id"))
	var orig: Vector2 = WC.origin(map_id)
	var ext_half: float = float(raid.get("EXT_HALF"))
	var inner_sq: float = ext_half + 10.0

	var sector_sts: Dictionary = {}
	var lm_clear: Array = []
	var item_cnt := 0

	# Pass A：在相邻地表战区真实坐标投放标志性地标与高大遗迹（如铁锈工业带双曲面冷却塔/高炉/龙门吊、北岬灯塔、赤湖观景塔等）
	for nid_v in GameData.map_ids():
		var nid: String = str(nid_v)
		if nid == map_id or not WC.is_surface(nid):
			continue
		var n_orig: Vector2 = WC.origin(nid)
		var n_md: Dictionary = GameData.map_data(nid)
		for lm_v in n_md.get("landmarks", []):
			var lm: Dictionary = lm_v as Dictionary
			var ltype: String = str(lm.get("type", ""))
			if ltype in ["boardwalk", "broken_bridge", "rope_bridge", "helipad_pad", "coolant_channel", "crystal_cluster"]:
				continue
			var wp: Vector2 = n_orig + WC.landmark_spot(nid, lm)
			var lp: Vector2 = wp - orig
			if maxf(absf(lp.x), absf(lp.y)) < inner_sq - 4.0 or lp.length_squared() > OUTER_LM_MAX_R * OUTER_LM_MAX_R:
				continue
			var st := _get_sector_st(sector_sts, lp)
			var yaw := deg_to_rad(float(lm.get("rot", 0.0)))
			var seed := _pos_seed(wp.x, wp.y, 211)
			if _stamp_outer_landmark(st, lp, ltype, yaw, seed):
				lm_clear.append(Vector3(lp.x, lp.y, maxf(22.0, float(lm.get("clear", 9.0)) + 14.0)))
				item_cnt += 1
		for p_v in WC.zone_pois(nid):
			var p: Dictionary = p_v as Dictionary
			var wp: Vector2 = p["c"] as Vector2
			var lp: Vector2 = wp - orig
			if maxf(absf(lp.x), absf(lp.y)) < inner_sq - 4.0 or lp.length_squared() > OUTER_LM_MAX_R * OUTER_LM_MAX_R:
				continue
			var pid: String = str(p.get("id", ""))
			var st := _get_sector_st(sector_sts, lp)
			var seed := _pos_seed(wp.x, wp.y, 223)
			if _stamp_outer_poi(st, lp, pid, seed):
				lm_clear.append(Vector3(lp.x, lp.y, 24.0))
				item_cnt += 1

	# Pass B：世界坐标对齐的两环确定性城区 / 工业 / 林带外围天际线（完全尊重东湾海岸线、河湖与主干道）
	var feat: Dictionary = WC.features()
	var feat_art = feat["art"]
	var rings := [
		[26.0, 0.0, 510.0, 301],
		[38.0, 510.0, OUTER_MAX_R, 401],
	]
	for ring_v in rings:
		var ring: Array = ring_v as Array
		var step: float = float(ring[0])
		var r_lo: float = float(ring[1])
		var r_hi: float = float(ring[2])
		var salt: int = int(ring[3])
		var r_lo_sq: float = r_lo * r_lo
		var r_hi_sq: float = r_hi * r_hi

		var gi0 := floori((orig.x - r_hi) / step)
		var gi1 := ceili((orig.x + r_hi) / step)
		var gj0 := floori((orig.y - r_hi) / step)
		var gj1 := ceili((orig.y + r_hi) / step)

		for gj in range(gj0, gj1 + 1):
			for gi in range(gi0, gi1 + 1):
				var jx := (WC.h2(gi, gj, salt) - 0.5) * step * 0.66
				var jz := (WC.h2(gi, gj, salt + 1) - 0.5) * step * 0.66
				var wx := (float(gi) + 0.5) * step + jx
				var wz := (float(gj) + 0.5) * step + jz
				var lx := wx - orig.x
				var lz := wz - orig.y
				if maxf(absf(lx), absf(lz)) < inner_sq:
					continue
				var d2 := lx * lx + lz * lz
				if d2 < r_lo_sq or d2 > r_hi_sq:
					continue
				# 东湾海域与沙滩保持绝对干净，不生成建筑与林木
				if wx > WC.coast_x(wz) - 18.0:
					continue

				var ci := floori((wx + WC.HALF) / WC.CELL)
				var cj := floori((wz + WC.HALF) / WC.CELL)
				var dch: String = WC.cell_char(ci, cj)
				if dch == "A" or dch == "B" or dch == "K" or dch == "C" or dch == "S":
					continue

				var wp := Vector2(wx, wz)
				if WC.water_dist(wp, true) < 6.0:
					continue
				if feat_art.edge_dist(wp) < 9.5:
					continue

				var blocked := false
				for cl: Vector3 in lm_clear:
					var ddx := lx - cl.x
					var ddz := lz - cl.y
					if ddx * ddx + ddz * ddz < cl.z * cl.z:
						blocked = true
						break
				if blocked:
					continue

				var r0 := WC.h2(gi, gj, salt + 2)
				var r1 := WC.h2(gi, gj, salt + 3)
				var r2 := WC.h2(gi, gj, salt + 4)
				var r3 := WC.h2(gi, gj, salt + 5)
				var lp := Vector2(lx, lz)
				var st := _get_sector_st(sector_sts, lp)
				var far_s := 1.18 if r_lo > 400.0 else 1.0
				if _stamp_outer_cell(st, lp, wp, dch, r0, r1, r2, r3, far_s):
					item_cnt += 1

	var sec_cnt := 0
	for sec_v in sector_sts:
		var sec_idx: int = int(sec_v)
		var st: SurfaceTool = sector_sts[sec_idx] as SurfaceTool
		st.index()
		var am: ArrayMesh = st.commit()
		if am == null or am.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "VistaOuter_%d" % sec_idx
		mi.mesh = am
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		_outer_root.add_child(mi)
		sec_cnt += 1

	return [sec_cnt, item_cnt]


static func _get_sector_st(sector_sts: Dictionary, lp: Vector2) -> SurfaceTool:
	var ang := wrapf(atan2(lp.y, lp.x), 0.0, TAU)
	var idx := clampi(int(floor(ang / (TAU / float(OUTER_SECTORS)))), 0, OUTER_SECTORS - 1)
	var existing = sector_sts.get(idx)
	if existing != null:
		return existing as SurfaceTool
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	sector_sts[idx] = st
	return st


static func _stamp_outer_cell(st: SurfaceTool, lp: Vector2, wp: Vector2, dch: String, r0: float, r1: float, r2: float, r3: float, far_s: float) -> bool:
	var yaw := (floorf(r1 * 4.0) * (PI * 0.5)) + (r2 - 0.5) * 0.24
	var base_y := -0.35
	var b_rot := Basis(Vector3.UP, yaw)

	match dch:
		"D":
			if r0 > 0.74:
				return false
			var w := lerpf(11.0, 19.5, r1) * far_s
			var d := lerpf(10.0, 17.0, r2) * far_s
			var h := lerpf(22.0, 44.0, r3)
			if r0 < 0.24:
				h = lerpf(45.0, 68.0, r3)
			# 写实去饱和风化混凝土 / 冷岩灰 / 暗暖灰石材色板（告别旧版亮米黄玩具方块）
			var tone := lerpf(0.28, 0.43, r2)
			var bcol_raw := Color(tone * 0.96, tone * 0.98, tone * 1.03) if r1 > 0.45 else Color(tone * 1.03, tone * 0.98, tone * 0.92)
			var col := _pack_col(bcol_raw, r3)
			# 底层裙楼基座（高于 20m 的写字楼增加外扩裙房，丰富城市天际线体块层次）
			if h > 20.0 and r2 < 0.65:
				var pod_h := lerpf(5.2, 8.2, r1)
				_emit_box_yaw(st, Vector3(lp.x, base_y + pod_h * 0.5, lp.y), Vector3(w * 1.18, pod_h, d * 1.14), yaw, 0.0, _pack_col(bcol_raw.darkened(0.16), r2), base_y, h)
			_emit_box_yaw(st, Vector3(lp.x, base_y + h * 0.5, lp.y), Vector3(w, h, d), yaw, 0.0, col, base_y, h)
			# 非对称高层收分塔冠 + 屋顶机房 / 通讯天线塔尖
			if h > 20.0:
				var pw := w * lerpf(0.46, 0.64, r2)
				var pd := d * lerpf(0.46, 0.64, r1)
				var ph := lerpf(4.2, 9.2, r2)
				var off_xz := b_rot * Vector3((r1 - 0.5) * w * 0.22, 0.0, (r2 - 0.5) * d * 0.22)
				_emit_box_yaw(st, Vector3(lp.x + off_xz.x, base_y + h + ph * 0.5 - 0.2, lp.y + off_xz.z), Vector3(pw, ph, pd), yaw, 0.0, _pack_col(bcol_raw.darkened(0.18), r1), base_y, h + ph)
				# 屋顶冷却塔/机电房与高楼尖顶天线
				if r3 > 0.45:
					var hvac_off := b_rot * Vector3(-off_xz.x * 0.5, 0.0, -off_xz.z * 0.5)
					_emit_box_yaw(st, Vector3(lp.x + hvac_off.x, base_y + h + ph + 1.4, lp.y + hvac_off.z), Vector3(pw * 0.42, 2.8, pd * 0.42), yaw, 0.5, _pack_col(Color(0.24, 0.26, 0.28), r2), base_y, h + ph + 3.0)
				if h > 30.0 and r0 < 0.22:
					var spire_h := lerpf(7.5, 14.0, r1)
					_emit_cyl(st, Vector3(lp.x + off_xz.x, base_y + h + ph + spire_h * 0.5, lp.y + off_xz.z), 0.55, spire_h, 0.5, _pack_col(Color(0.32, 0.34, 0.36), r3), 6, 0.14, true)
			return true

		"R":
			if r0 > 0.66:
				if r0 < 0.84:
					var is_p := r1 < 0.28
					_emit_tree(st, Vector3(lp.x, 0.0, lp.y), lerpf(8.5, 14.0, r2), lerpf(3.4, 5.2, r1), KIND_PINE if is_p else KIND_BROAD, _pack_col(_region_foliage_col(wp, is_p, r3), r3), false)
					return true
				return false
			var w := lerpf(10.5, 18.0, r1) * far_s
			var d := lerpf(8.5, 13.5, r2) * far_s
			var h := lerpf(9.0, 20.5, r3)
			# 写实旧城区建筑色板：风化水泥灰 / 暗红砖 / 灰褐抹灰（压低亮度杜绝“浅黄纸盒感”）
			var base_c: Color
			if r1 < 0.34:
				base_c = Color(lerpf(0.34, 0.42, r2), lerpf(0.25, 0.31, r2), lerpf(0.21, 0.26, r2))
			elif r1 < 0.68:
				var g := lerpf(0.30, 0.42, r2)
				base_c = Color(g * 1.02, g * 0.99, g * 0.94)
			else:
				var g := lerpf(0.28, 0.38, r2)
				base_c = Color(g * 0.94, g * 0.97, g * 1.01)
			var col := _pack_col(base_c, r3)
			_emit_box_yaw(st, Vector3(lp.x, base_y + h * 0.5, lp.y), Vector3(w, h, d), yaw, 0.0, col, base_y, h)
			# 55% 住宅楼增加 L 型副翼或屋顶电梯机房，打破单一火柴盒剪影
			if r2 < 0.34:
				var ww := w * 0.44
				var wd := d * 0.68
				var wh := h * lerpf(0.76, 0.94, r1)
				var woff := b_rot * Vector3(w * 0.38, 0.0, d * 0.46)
				_emit_box_yaw(st, Vector3(lp.x + woff.x, base_y + wh * 0.5, lp.y + woff.z), Vector3(ww, wh, wd), yaw, 0.0, _pack_col(base_c.darkened(0.08), r1), base_y, wh)
			elif r1 < 0.44 and h < 15.0:
				var gh := lerpf(2.2, 3.6, r2)
				_emit_gable(st, Vector3(lp.x, base_y + h - 0.1, lp.y), Vector3(w * 1.03, gh, d * 1.03), yaw, 0.5, _pack_col(Color(0.27, 0.24, 0.23), r1))
			else:
				var eh_off := b_rot * Vector3((r3 - 0.5) * w * 0.35, 0.0, 0.0)
				_emit_box_yaw(st, Vector3(lp.x + eh_off.x, base_y + h + 1.5, lp.y + eh_off.z), Vector3(w * 0.26, 3.0, d * 0.34), yaw, 0.5, _pack_col(base_c.darkened(0.20), r2), base_y, h + 3.0)
			return true

		"I", "Y":
			if r0 > 0.62:
				return false
			var w := lerpf(14.0, 26.0, r1) * far_s
			var d := lerpf(10.0, 18.0, r2) * far_s
			var h := lerpf(8.0, 15.5, r3)
			var base_ic := Color(lerpf(0.27, 0.38, r2), lerpf(0.28, 0.37, r2), lerpf(0.28, 0.36, r1))
			var col := _pack_col(base_ic, r3)
			_emit_box_yaw(st, Vector3(lp.x, base_y + h * 0.5, lp.y), Vector3(w, h, d), yaw, 0.5, col, base_y, h)
			# 厂房顶部采光天窗通长脊屋，大幅丰富工业带天际线剪影
			if r2 > 0.35:
				_emit_box_yaw(st, Vector3(lp.x, base_y + h + 1.4, lp.y), Vector3(w * 0.86, 2.8, d * 0.34), yaw, 0.5, _pack_col(base_ic.darkened(0.16), r1), base_y, h + 2.8)
			if r0 < 0.20:
				var sh := lerpf(25.0, 42.0, r3)
				var sx := lp.x + cos(yaw) * (w * 0.35)
				var sz := lp.y + sin(yaw) * (w * 0.35)
				_emit_cyl(st, Vector3(sx, base_y + sh * 0.5, sz), lerpf(1.4, 2.2, r1), sh, 0.5, _pack_col(Color(0.34, 0.30, 0.28), r2), 7, lerpf(0.85, 1.35, r1), false)
			elif r0 < 0.36:
				var th := lerpf(11.0, 18.0, r2)
				_emit_cyl(st, Vector3(lp.x + d * 0.42, base_y + th * 0.5, lp.y), lerpf(3.4, 5.2, r1), th, 0.5, _pack_col(Color(0.38, 0.39, 0.40), r3), 8)
			return true

		"H":
			if r0 > 0.56:
				return false
			var w := lerpf(14.0, 24.0, r1) * far_s
			var d := lerpf(10.0, 15.5, r2) * far_s
			var h := lerpf(7.5, 13.5, r3)
			var col := _pack_col(Color(0.30, 0.34, 0.38), r2)
			_emit_box_yaw(st, Vector3(lp.x, base_y + h * 0.5, lp.y), Vector3(w, h, d), yaw, 0.5, col, base_y, h)
			if r0 < 0.16:
				var ch := lerpf(21.0, 29.0, r3)
				var ccol := _pack_col(Color(0.48, 0.30, 0.20), r1)
				var cb := Basis(Vector3.UP, yaw)
				var cp := Vector3(lp.x, base_y, lp.y)
				_emit_box_yaw(st, cp + Vector3(0.0, ch * 0.5, 0.0), Vector3(3.0, ch, 3.0), yaw, 0.5, ccol, base_y, ch)
				_emit_box_yaw(st, cp + cb * Vector3(5.2, ch - 1.6, 0.0), Vector3(17.5, 1.8, 2.2), yaw, 0.5, ccol, base_y, ch)
				_emit_box_yaw(st, cp + cb * Vector3(-2.6, ch - 3.0, 0.0), Vector3(4.2, 2.6, 3.4), yaw, 0.5, _pack_col(Color(0.30, 0.32, 0.36), r2), base_y, ch)
			return true

		"M":
			if r0 > 0.48:
				return false
			var w := lerpf(12.0, 20.0, r1) * far_s
			var d := lerpf(9.0, 14.0, r2) * far_s
			var h := lerpf(6.0, 11.5, r3)
			var col := _pack_col(Color(0.32, 0.34, 0.30), r2)
			_emit_box_yaw(st, Vector3(lp.x, base_y + h * 0.5, lp.y), Vector3(w, h, d), yaw, 0.5, col, base_y, h)
			if r0 < 0.12:
				var mh := lerpf(22.0, 30.0, r3)
				_emit_cyl(st, Vector3(lp.x, base_y + mh * 0.5, lp.y), 0.9, mh, 0.5, _pack_col(Color(0.38, 0.39, 0.38), r1), 6, 0.35, true)
			return true

		"T":
			if r0 > 0.88:
				return false
			# 连绵起伏密林团簇：每格 5~6 棵交错高低分团阔叶冠与错落松杉，在 260~760m 形成自然疏密林海天际线
			var tree_s := clampf(far_s, 1.0, 1.12)
			var cnt := 6 if r0 < 0.40 else 5
			for k in cnt:
				var ang := r1 * TAU + float(k) * (TAU / float(cnt)) + sin(float(k) * 2.1 + r2 * 6.0) * 0.42
				var rad := lerpf(1.2, 3.0, r2) if k == 0 else lerpf(4.2, 11.8, fract_f(r2 + float(k) * 0.29))
				var tx := lp.x + cos(ang) * rad
				var tz := lp.y + sin(ang) * rad
				var is_pine := fract_f(r3 + float(k) * 0.37) < 0.44
				var th := (lerpf(10.5, 17.5, fract_f(r2 + float(k) * 0.37)) if is_pine else lerpf(8.5, 14.2, fract_f(r2 + float(k) * 0.37))) * (1.06 if far_s > 1.0 else 1.0)
				var cr := (lerpf(2.2, 3.4, fract_f(r1 + float(k) * 0.41)) if is_pine else lerpf(2.9, 4.3, fract_f(r1 + float(k) * 0.41))) * tree_s
				var tseed := fract_f(r3 + float(k) * 0.33)
				var tcol := _pack_col(_region_foliage_col(wp, is_pine, tseed), tseed)
				_emit_tree(st, Vector3(tx, -0.15, tz), th, cr, KIND_PINE if is_pine else KIND_BROAD, tcol, true)
			return true

		"P":
			if r0 > 0.62:
				return false
			var tree_s := clampf(far_s, 1.0, 1.12)
			var cnt := 3 if r0 < 0.26 else (2 if r0 < 0.48 else 1)
			for k in cnt:
				var ang := r2 * TAU + float(k) * 2.45
				var rad := 0.0 if k == 0 else lerpf(4.8, 8.6, fract_f(r1 + float(k) * 0.31))
				var is_pine := fract_f(r1 + float(k) * 0.35) < 0.36
				var tseed := fract_f(r3 + float(k) * 0.43)
				var tcol := _pack_col(_region_foliage_col(wp, is_pine, tseed), tseed)
				var th := lerpf(9.8, 15.2, fract_f(r2 + float(k) * 0.27)) if is_pine else lerpf(8.0, 13.0, fract_f(r2 + float(k) * 0.27))
				var cr := (lerpf(2.1, 3.1, r1) if is_pine else lerpf(2.8, 4.1, r1)) * tree_s
				_emit_tree(st, Vector3(lp.x + cos(ang) * rad, -0.15, lp.y + sin(ang) * rad), th, cr, KIND_PINE if is_pine else KIND_BROAD, tcol, true)
			return true

		"F":
			if r0 < 0.09:
				var w := lerpf(11.0, 17.0, r1)
				var d := lerpf(8.0, 12.0, r2)
				var h := lerpf(6.5, 9.5, r3)
				_emit_box_yaw(st, Vector3(lp.x, base_y + h * 0.5, lp.y), Vector3(w, h, d), yaw, 0.5, _pack_col(Color(0.38, 0.30, 0.24), r2), base_y, h)
				_emit_gable(st, Vector3(lp.x, base_y + h - 0.1, lp.y), Vector3(w * 1.03, 3.0, d * 1.03), yaw, 0.5, _pack_col(Color(0.28, 0.22, 0.20), r1))
				if r2 > 0.5:
					_emit_cyl(st, Vector3(lp.x + w * 0.55, base_y + 7.5, lp.y), 2.8, 15.0, 0.5, _pack_col(Color(0.45, 0.44, 0.42), r3), 8)
				return true
			if r0 < 0.28:
				var is_pine := r1 < 0.30
				var tcol := _pack_col(_region_foliage_col(wp, is_pine, r3), r3)
				var cr_f := (lerpf(2.0, 3.0, r1) if is_pine else lerpf(2.7, 3.9, r1)) * clampf(far_s, 1.0, 1.12)
				_emit_tree(st, Vector3(lp.x, -0.15, lp.y), lerpf(8.2, 12.8, r2), cr_f, KIND_PINE if is_pine else KIND_BROAD, tcol, true)
				return true
			return false

		"L", "W":
			if r0 < 0.14:
				var is_pine := dch == "L" or r1 < 0.38
				var tcol := _pack_col(_region_foliage_col(wp, is_pine, r3), r3)
				var cr_w := (lerpf(2.0, 2.9, r1) if is_pine else lerpf(2.6, 3.7, r1)) * clampf(far_s, 1.0, 1.12)
				_emit_tree(st, Vector3(lp.x, -0.15, lp.y), lerpf(7.8, 12.2, r2), cr_w, KIND_PINE if is_pine else KIND_BROAD, tcol, true)
				return true
			return false

	return false


static func _region_foliage_col(wp: Vector2, is_pine: bool, seed: float) -> Color:
	# 严格对齐近景 foliage.gdshader 深沉森林明度与饱和度（杜绝远近切换时突兀亮绿/亮橙气球感）
	var v := clampf(seed, 0.0, 1.0)
	if wp.y < -220.0:
		if not is_pine and v > 0.72:
			return Color(0.24, 0.15, 0.08).lerp(Color(0.29, 0.19, 0.09), (v - 0.72) * 3.5)
		return Color(0.09, 0.15, 0.10).lerp(Color(0.13, 0.18, 0.12), v) if is_pine else Color(0.13, 0.19, 0.10).lerp(Color(0.18, 0.23, 0.12), v)
	if wp.y > 210.0:
		return Color(0.14, 0.18, 0.10).lerp(Color(0.18, 0.21, 0.13), v) if is_pine else Color(0.18, 0.21, 0.11).lerp(Color(0.24, 0.22, 0.13), v)
	if not is_pine and v > 0.88:
		return Color(0.23, 0.15, 0.08)
	if wp.x > 180.0:
		return Color(0.10, 0.16, 0.10).lerp(Color(0.13, 0.19, 0.12), v) if is_pine else Color(0.13, 0.19, 0.10).lerp(Color(0.18, 0.22, 0.12), v)
	return Color(0.10, 0.16, 0.10).lerp(Color(0.13, 0.19, 0.12), v) if is_pine else Color(0.13, 0.20, 0.10).lerp(Color(0.19, 0.24, 0.12), v)


static func _stamp_outer_landmark(st: SurfaceTool, lp: Vector2, ltype: String, yaw: float, seed: float) -> bool:
	var c_conc := _pack_col(Color(0.50, 0.49, 0.46), seed)
	var c_steel := _pack_col(Color(0.36, 0.38, 0.40), seed)
	var c_rust := _pack_col(Color(0.52, 0.33, 0.23), seed)
	var c_warn := _pack_col(Color(0.62, 0.30, 0.22), seed)
	var p0 := Vector3(lp.x, 0.0, lp.y)

	match ltype:
		"cooling_tower":
			# 铁锈工业带双曲面冷却塔（双层收口锥筒 + 邻接副塔）
			_emit_cyl(st, p0 + Vector3(0.0, 14.0, 0.0), 11.5, 28.0, 0.5, c_conc, 10, 7.6, false)
			_emit_cyl(st, p0 + Vector3(0.0, 32.0, 0.0), 7.6, 8.5, 0.5, c_conc, 10, 8.8, false)
			_emit_cyl(st, p0 + Vector3(22.0, 11.5, -8.0), 9.2, 23.0, 0.5, c_conc, 10, 6.4, false)
			return true

		"blast_furnace":
			# 一号钢厂高炉群 + 热风炉 + 烟囱
			_emit_cyl(st, p0 + Vector3(0.0, 17.0, 0.0), 7.4, 34.0, 0.5, c_steel, 8, 5.2, true)
			_emit_cyl(st, p0 + Vector3(11.0, 13.0, 4.0), 4.2, 26.0, 0.5, c_rust, 8, 4.0, true)
			_emit_cyl(st, p0 + Vector3(-10.0, 21.0, -5.0), 2.0, 42.0, 0.5, c_rust, 7, 1.2, false)
			_emit_box_yaw(st, p0 + Vector3(0.0, 6.0, 0.0), Vector3(22.0, 12.0, 16.0), yaw, 0.5, c_steel, 0.0, 12.0)
			return true

		"gantry":
			# 港湾/运河重型龙门吊
			var b := Basis(Vector3.UP, yaw)
			var l1 := p0 + b * Vector3(-11.0, 13.0, 0.0)
			var l2 := p0 + b * Vector3(11.0, 13.0, 0.0)
			_emit_box_yaw(st, l1, Vector3(3.4, 26.0, 8.0), yaw, 0.5, c_rust, 0.0, 26.0)
			_emit_box_yaw(st, l2, Vector3(3.4, 26.0, 8.0), yaw, 0.5, c_rust, 0.0, 26.0)
			_emit_box_yaw(st, p0 + Vector3(0.0, 25.5, 0.0), Vector3(32.0, 3.8, 5.2), yaw, 0.5, c_warn, 0.0, 28.0)
			return true

		"gas_holder":
			_emit_cyl(st, p0 + Vector3(0.0, 12.0, 0.0), 11.5, 24.0, 0.5, c_steel, 10)
			_emit_cyl(st, p0 + Vector3(19.0, 8.0, 6.0), 7.2, 16.0, 0.5, c_rust, 8)
			return true

		"converter_foundry":
			_emit_box_yaw(st, p0 + Vector3(0.0, 10.5, 0.0), Vector3(28.0, 21.0, 20.0), yaw, 0.5, c_steel, 0.0, 21.0)
			_emit_cyl(st, p0 + Vector3(-9.0, 19.0, -5.0), 2.1, 38.0, 0.5, c_rust, 7, 1.4, false)
			_emit_cyl(st, p0 + Vector3(9.0, 17.5, -5.0), 1.9, 35.0, 0.5, c_rust, 7, 1.3, false)
			return true

		"radio_mast":
			_emit_cyl(st, p0 + Vector3(0.0, 24.0, 0.0), 3.4, 48.0, 0.5, c_warn, 6, 0.65, true)
			_emit_box_yaw(st, p0 + Vector3(0.0, 3.5, 0.0), Vector3(11.0, 7.0, 10.0), yaw, 0.5, c_conc, 0.0, 7.0)
			return true

		"observation_tower":
			_emit_cyl(st, p0 + Vector3(0.0, 18.0, 0.0), 3.4, 36.0, 0.5, c_conc, 8, 2.4, true)
			_emit_cyl(st, p0 + Vector3(0.0, 31.0, 0.0), 7.8, 5.2, 0.0, c_steel, 8, 6.8, true)
			return true

		"central_terminus":
			_emit_box_yaw(st, p0 + Vector3(0.0, 9.5, 0.0), Vector3(32.0, 19.0, 22.0), yaw, 0.0, c_conc, 0.0, 26.0)
			_emit_cyl(st, p0 + Vector3(0.0, 22.5, 0.0), 9.0, 7.5, 0.5, c_steel, 8, 4.5, true)
			return true

		"drawbridge_gate":
			var b := Basis(Vector3.UP, yaw)
			_emit_box_yaw(st, p0 + b * Vector3(-9.0, 12.5, 0.0), Vector3(6.0, 25.0, 7.0), yaw, 0.5, c_conc, 0.0, 25.0)
			_emit_box_yaw(st, p0 + b * Vector3(9.0, 12.5, 0.0), Vector3(6.0, 25.0, 7.0), yaw, 0.5, c_conc, 0.0, 25.0)
			_emit_box_yaw(st, p0 + Vector3(0.0, 22.0, 0.0), Vector3(22.0, 3.6, 5.0), yaw, 0.5, c_steel, 0.0, 25.0)
			return true

		"windmill":
			# 三座错落风力发电机：细锥塔筒 + 机舱 + 桨盘平面内 0°/120°/240° 三叶薄桨
			for k in 3:
				var off := Vector3(float(k - 1) * 16.0, 0.0, float(k - 1) * 7.0)
				var tyaw := yaw + float(k) * 0.35
				var tb := Basis(Vector3.UP, tyaw)
				var base_p := p0 + off
				_emit_cyl(st, base_p + Vector3(0.0, 16.0, 0.0), 1.35, 32.0, 0.5, c_conc, 6, 0.62, true)
				_emit_box_yaw(st, base_p + Vector3(0.0, 32.2, 0.0), Vector3(2.0, 1.9, 4.8), tyaw, 0.5, c_steel, 0.0, 42.0)
				var hub := base_p + tb * Vector3(0.0, 32.2, 2.7)
				var phase := seed * TAU + float(k) * 0.85
				for bi in 3:
					var ba := phase + float(bi) * (TAU / 3.0)
					var dir := (tb.x * cos(ba) + Vector3.UP * sin(ba)).normalized()
					var perp := (-tb.x * sin(ba) + Vector3.UP * cos(ba)).normalized()
					var b_len := 10.4
					_emit_obb(st, hub + dir * (b_len * 0.5), perp * 0.44, dir * (b_len * 0.5), tb.z * 0.24, 0.5, c_conc, 0.0, 1.0 / 44.0)
			return true

		"silo", "ore_silos":
			for k in 3:
				_emit_cyl(st, p0 + Vector3(float(k - 1) * 8.2, 11.5, 0.0), 3.8, 23.0, 0.5, c_conc, 8)
			_emit_box_yaw(st, p0 + Vector3(0.0, 24.5, 0.0), Vector3(24.0, 4.0, 6.5), yaw, 0.5, c_steel, 0.0, 26.5)
			return true

		"cable_tower", "pylon_row":
			# 高压输电铁塔 / 索道塔：双斜腿 A 字塔架 + 塔腰横梁 + 双层上窄下宽细横担（杜绝单杆十字架剪影）
			var pb := Basis(Vector3.UP, yaw)
			var h_tot := 25.0
			for side in [-1.0, 1.0]:
				var bot := p0 + pb * Vector3(side * 4.2, 0.0, 0.0)
				var top := p0 + pb * Vector3(side * 0.75, h_tot, 0.0)
				var mid := (bot + top) * 0.5
				var leg_ay := (top - bot) * 0.5
				var leg_ax := leg_ay.cross(pb.z).normalized() * 0.55
				_emit_obb(st, mid, leg_ax, leg_ay, pb.z * 0.62, 0.5, c_rust, 0.0, 1.0 / h_tot)
			_emit_box_yaw(st, p0 + Vector3(0.0, 11.0, 0.0), Vector3(5.6, 0.85, 1.1), yaw, 0.5, c_steel, 0.0, h_tot)
			_emit_box_yaw(st, p0 + Vector3(0.0, 17.5, 0.0), Vector3(13.2, 0.95, 1.05), yaw, 0.5, c_steel, 0.0, h_tot)
			_emit_box_yaw(st, p0 + Vector3(0.0, 22.8, 0.0), Vector3(9.0, 0.85, 0.95), yaw, 0.5, c_steel, 0.0, h_tot)
			_emit_box_yaw(st, p0 + Vector3(0.0, 25.4, 0.0), Vector3(2.0, 1.2, 1.1), yaw, 0.5, c_rust, 0.0, h_tot + 1.2)
			return true

		"bucket_excavator":
			_emit_box_yaw(st, p0 + Vector3(0.0, 8.5, 0.0), Vector3(18.0, 17.0, 14.0), yaw, 0.5, c_rust, 0.0, 24.0)
			var b := Basis(Vector3.UP, yaw)
			_emit_box_yaw(st, p0 + b * Vector3(14.0, 15.0, 0.0), Vector3(24.0, 3.5, 4.0), yaw, 0.5, c_warn, 0.0, 24.0)
			return true

		"submarine_drydock":
			_emit_box_yaw(st, p0 + Vector3(0.0, 10.0, 0.0), Vector3(36.0, 20.0, 18.0), yaw, 0.5, c_steel, 0.0, 24.0)
			_emit_box_yaw(st, p0 + Vector3(0.0, 22.5, 0.0), Vector3(14.0, 5.5, 16.0), yaw, 0.5, c_rust, 0.0, 26.0)
			return true

		"spillway_dam":
			_emit_box_yaw(st, p0 + Vector3(0.0, 8.0, 0.0), Vector3(34.0, 16.0, 10.0), yaw, 0.5, c_conc, 0.0, 16.0)
			return true

		"missile_silo":
			_emit_box_yaw(st, p0 + Vector3(0.0, 4.5, 0.0), Vector3(24.0, 9.0, 20.0), yaw, 0.5, c_conc, 0.0, 18.0)
			_emit_cyl(st, p0 + Vector3(8.0, 11.0, -5.0), 4.6, 12.0, 0.5, c_steel, 8, 2.4, true)
			return true

		"elevated_road":
			_emit_box_yaw(st, p0 + Vector3(0.0, 9.5, 0.0), Vector3(34.0, 3.2, 11.0), yaw, 0.5, c_conc, 0.0, 11.0)
			return true

	return false


static func _stamp_outer_poi(st: SurfaceTool, lp: Vector2, pid: String, seed: float) -> bool:
	var c_conc := _pack_col(Color(0.52, 0.50, 0.47), seed)
	var c_steel := _pack_col(Color(0.38, 0.40, 0.43), seed)
	var c_rust := _pack_col(Color(0.52, 0.34, 0.24), seed)
	var p0 := Vector3(lp.x, 0.0, lp.y)

	match pid:
		"abyss_lighthouse":
			_emit_cyl(st, p0 + Vector3(0.0, 16.5, 0.0), 4.6, 33.0, 0.5, _pack_col(Color(0.68, 0.66, 0.62), seed), 8, 3.0, true)
			_emit_cyl(st, p0 + Vector3(0.0, 35.0, 0.0), 3.6, 4.5, 0.5, _pack_col(Color(0.60, 0.26, 0.22), seed), 8, 2.0, true)
			return true
		"airship_mooring_mast":
			_emit_cyl(st, p0 + Vector3(0.0, 20.5, 0.0), 3.4, 41.0, 0.5, c_steel, 8, 1.25, true)
			_emit_cyl(st, p0 + Vector3(0.0, 14.0, 0.0), 4.6, 1.6, 0.5, c_conc, 8)
			_emit_cyl(st, p0 + Vector3(0.0, 28.0, 0.0), 4.2, 1.8, 0.5, c_steel, 8)
			_emit_cyl(st, p0 + Vector3(0.0, 35.5, 0.0), 5.6, 3.2, 0.5, c_rust, 8, 5.2, true)
			_emit_cyl(st, p0 + Vector3(0.0, 44.5, 0.0), 0.75, 8.0, 0.5, c_steel, 6, 0.18, true)
			return true
		"radar_array_tower", "relay_tower":
			_emit_cyl(st, p0 + Vector3(0.0, 18.0, 0.0), 3.0, 36.0, 0.5, c_steel, 6, 1.1, true)
			_emit_box_yaw(st, p0 + Vector3(0.0, 33.0, 0.0), Vector3(11.0, 6.5, 3.6), seed * TAU, 0.5, c_conc, 0.0, 37.0)
			return true
		"church":
			_emit_box_yaw(st, p0 + Vector3(0.0, 7.0, 0.0), Vector3(16.0, 14.0, 24.0), 0.0, 0.0, c_conc, 0.0, 30.0)
			_emit_gable(st, p0 + Vector3(0.0, 13.8, 0.0), Vector3(24.0, 5.2, 16.2), PI * 0.5, 0.5, _pack_col(Color(0.32, 0.28, 0.26), seed))
			_emit_cyl(st, p0 + Vector3(0.0, 21.0, -9.0), 3.2, 22.0, 0.5, c_conc, 6, 0.6, true)
			return true
		"hospital", "institute":
			_emit_box_yaw(st, p0 + Vector3(0.0, 11.5, 0.0), Vector3(28.0, 23.0, 18.0), 0.0, 0.0, c_conc, 0.0, 27.0)
			_emit_box_yaw(st, p0 + Vector3(0.0, 24.5, 0.0), Vector3(12.0, 4.5, 10.0), 0.0, 0.0, c_steel, 0.0, 27.0)
			return true
		"power_station", "salvage_foundry", "ore_crusher_tipple":
			_emit_box_yaw(st, p0 + Vector3(0.0, 9.0, 0.0), Vector3(24.0, 18.0, 18.0), 0.0, 0.5, c_steel, 0.0, 18.0)
			_emit_cyl(st, p0 + Vector3(8.0, 17.5, -5.0), 2.0, 35.0, 0.5, c_rust, 7, 1.3, false)
			return true
		"astronomical_observatory", "hydroponic_biodome":
			_emit_cyl(st, p0 + Vector3(0.0, 7.0, 0.0), 11.0, 14.0, 0.5, c_conc, 10)
			_emit_cyl(st, p0 + Vector3(0.0, 17.5, 0.0), 10.5, 7.5, 0.5, c_steel, 10, 3.2, true)
			return true
		"parking_garage", "coastal_artillery", "mining_terminal":
			_emit_box_yaw(st, p0 + Vector3(0.0, 7.5, 0.0), Vector3(24.0, 15.0, 18.0), 0.0, 0.5, c_conc, 0.0, 15.0)
			return true
	return false


static func fract_f(v: float) -> float:
	return v - floor(v)


static func _get_st(dict: Dictionary, ck: Vector2i) -> SurfaceTool:
	var existing = dict.get(ck)
	if existing != null:
		return existing as SurfaceTool
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	dict[ck] = st
	return st


# ---------------------------------------------------------------- 底层 CW 绕序几何发射器
static func _emit_tri(
	st: SurfaceTool,
	a: Vector3, b: Vector3, c: Vector3,
	na: Vector3, nb: Vector3, nc: Vector3,
	uva: Vector2, uvb: Vector2, uvc: Vector2,
	col: Color
) -> void:
	# Godot 4 正面为顺时针：(c - a) × (b - a) 与外法线同向则保留 a, b, c，否则翻转 b, c
	var fn := (c - a).cross(b - a)
	var rn := na + nb + nc
	st.set_color(col)
	st.set_normal(na)
	st.set_uv(uva)
	st.add_vertex(a)
	if fn.dot(rn) >= 0.0:
		st.set_color(col)
		st.set_normal(nb)
		st.set_uv(uvb)
		st.add_vertex(b)
		st.set_color(col)
		st.set_normal(nc)
		st.set_uv(uvc)
		st.add_vertex(c)
	else:
		st.set_color(col)
		st.set_normal(nc)
		st.set_uv(uvc)
		st.add_vertex(c)
		st.set_color(col)
		st.set_normal(nb)
		st.set_uv(uvb)
		st.add_vertex(b)


static func _emit_quad(
	st: SurfaceTool,
	a: Vector3, b: Vector3, c: Vector3, d: Vector3,
	nrm: Vector3,
	ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2,
	col: Color
) -> void:
	_emit_tri(st, a, b, c, nrm, nrm, nrm, ua, ub, uc, col)
	_emit_tri(st, a, c, d, nrm, nrm, nrm, ua, uc, ud, col)


static func _emit_obb(
	st: SurfaceTool,
	center: Vector3,
	ax: Vector3, ay: Vector3, az: Vector3,
	uv_x: float,
	col: Color,
	y_min_ref: float,
	y_inv_h: float
) -> void:
	if ay.y < 0.0:
		ay = -ay
	var nx := ax.normalized() if ax.length_squared() > 1e-8 else Vector3.RIGHT
	var ny := ay.normalized() if ay.length_squared() > 1e-8 else Vector3.UP
	var nz := az.normalized() if az.length_squared() > 1e-8 else Vector3.BACK

	var p000 := center - ax - ay - az
	var p100 := center + ax - ay - az
	var p110 := center + ax + ay - az
	var p010 := center - ax + ay - az
	var p001 := center - ax - ay + az
	var p101 := center + ax - ay + az
	var p111 := center + ax + ay + az
	var p011 := center - ax + ay + az

	var u000 := Vector2(uv_x, clampf((p000.y - y_min_ref) * y_inv_h, 0.0, 1.0))
	var u100 := Vector2(uv_x, clampf((p100.y - y_min_ref) * y_inv_h, 0.0, 1.0))
	var u110 := Vector2(uv_x, clampf((p110.y - y_min_ref) * y_inv_h, 0.0, 1.0))
	var u010 := Vector2(uv_x, clampf((p010.y - y_min_ref) * y_inv_h, 0.0, 1.0))
	var u001 := Vector2(uv_x, clampf((p001.y - y_min_ref) * y_inv_h, 0.0, 1.0))
	var u101 := Vector2(uv_x, clampf((p101.y - y_min_ref) * y_inv_h, 0.0, 1.0))
	var u111 := Vector2(uv_x, clampf((p111.y - y_min_ref) * y_inv_h, 0.0, 1.0))
	var u011 := Vector2(uv_x, clampf((p011.y - y_min_ref) * y_inv_h, 0.0, 1.0))

	# 4 侧面 + 顶面（10 三角）；悬空梁体/桥面额外补底面避免仰视穿帮
	_emit_quad(st, p100, p101, p111, p110, nx, u100, u101, u111, u110, col)
	_emit_quad(st, p001, p000, p010, p011, -nx, u001, u000, u010, u011, col)
	_emit_quad(st, p001, p101, p111, p011, nz, u001, u101, u111, u011, col)
	_emit_quad(st, p100, p000, p010, p110, -nz, u100, u000, u010, u110, col)
	_emit_quad(st, p010, p110, p111, p011, ny, u010, u110, u111, u011, col)
	if center.y - ay.length() > 1.5:
		_emit_quad(st, p000, p001, p101, p100, -ny, u000, u001, u101, u100, col)


static func _emit_box_yaw(
	st: SurfaceTool,
	pos: Vector3,
	sz: Vector3,
	yaw_rad: float,
	uv_x: float,
	col: Color,
	y_base := 0.0,
	h_total := -1.0
) -> void:
	var b := Basis(Vector3.UP, yaw_rad)
	var ax := b.x * (sz.x * 0.5)
	var ay := Vector3(0.0, sz.y * 0.5, 0.0)
	var az := b.z * (sz.z * 0.5)
	var ymin := (pos.y - sz.y * 0.5) if h_total <= 0.0 else y_base
	var inv_h := 1.0 / maxf(0.25, sz.y if h_total <= 0.0 else h_total)
	_emit_obb(st, pos, ax, ay, az, uv_x, col, ymin, inv_h)


static func _emit_cyl(
	st: SurfaceTool,
	pos: Vector3,
	radius: float,
	height: float,
	uv_x: float,
	col: Color,
	segs := 8,
	top_r := -1.0,
	cap_top := true
) -> void:
	var n := clampi(segs, 6, 12)
	var r_bot := maxf(0.2, radius)
	var r_top := r_bot if top_r < 0.0 else maxf(0.15, top_r)
	var y0 := pos.y - height * 0.5
	var y1 := pos.y + height * 0.5
	var slope_y := (r_bot - r_top) / maxf(0.5, height)
	var ub := Vector2(uv_x, 0.0)
	var ut := Vector2(uv_x, 1.0)
	var top_c := Vector3(pos.x, y1, pos.z)

	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var c0 := cos(a0)
		var s0 := sin(a0)
		var c1 := cos(a1)
		var s1 := sin(a1)
		var b0 := Vector3(pos.x + c0 * r_bot, y0, pos.z + s0 * r_bot)
		var b1 := Vector3(pos.x + c1 * r_bot, y0, pos.z + s1 * r_bot)
		var t0 := Vector3(pos.x + c0 * r_top, y1, pos.z + s0 * r_top)
		var t1 := Vector3(pos.x + c1 * r_top, y1, pos.z + s1 * r_top)
		var n0 := Vector3(c0, slope_y, s0).normalized()
		var n1 := Vector3(c1, slope_y, s1).normalized()
		_emit_tri(st, b0, b1, t1, n0, n1, n1, ub, ub, ut, col)
		_emit_tri(st, b0, t1, t0, n0, n1, n0, ub, ut, ut, col)
		if cap_top and r_top > 0.25:
			_emit_tri(st, top_c, t0, t1, Vector3.UP, Vector3.UP, Vector3.UP, ut, ut, ut, col)


static func _emit_gable(
	st: SurfaceTool,
	pos: Vector3,
	sz: Vector3,
	yaw_rad: float,
	uv_x: float,
	col: Color
) -> void:
	# pos = 檐口底面中心；屋脊沿本地 X 延伸，跨度沿本地 Z，高度 sz.y
	var b := Basis(Vector3.UP, yaw_rad)
	var hx := b.x * (sz.x * 0.5)
	var hz := b.z * (sz.z * 0.5)
	var hy := Vector3(0.0, sz.y, 0.0)

	var fl := pos - hx + hz
	var fr := pos + hx + hz
	var bl := pos - hx - hz
	var br := pos + hx - hz
	var rl := pos - hx + hy
	var rr := pos + hx + hy

	var n_f := (b.z * sz.y + Vector3.UP * (sz.z * 0.5)).normalized()
	var n_b := (-b.z * sz.y + Vector3.UP * (sz.z * 0.5)).normalized()
	var u0 := Vector2(uv_x, 0.85)
	var u1 := Vector2(uv_x, 1.0)

	# 两坡屋面（4 三角）+ 两端山墙（2 三角）= 6 三角
	_emit_quad(st, fl, fr, rr, rl, n_f, u0, u0, u1, u1, col)
	_emit_quad(st, br, bl, rl, rr, n_b, u0, u0, u1, u1, col)
	_emit_tri(st, bl, fl, rl, -b.x, -b.x, -b.x, u0, u0, u1, col)
	_emit_tri(st, fr, br, rr, b.x, b.x, b.x, u0, u0, u1, col)


static func _emit_tree(
	st: SurfaceTool,
	pos: Vector3,
	h: float,
	cr: float,
	kind: int,
	col: Color,
	with_trunk := true
) -> void:
	var seed := col.a
	if with_trunk:
		var tr := clampf(cr * 0.14, 0.15, 0.42)
		var th := h * 0.44
		var bcol := Color(0.24, 0.19, 0.15, seed)
		var ub := Vector2(0.5, 0.0)
		var ut := Vector2(0.5, 0.45)
		for i in 3:
			var a0 := TAU * float(i) / 3.0 + seed * TAU
			var a1 := TAU * float(i + 1) / 3.0 + seed * TAU
			var c0 := cos(a0)
			var s0 := sin(a0)
			var c1 := cos(a1)
			var s1 := sin(a1)
			var p0 := Vector3(pos.x + c0 * tr, pos.y, pos.z + s0 * tr)
			var p1 := Vector3(pos.x + c1 * tr, pos.y, pos.z + s1 * tr)
			var q0 := Vector3(pos.x + c0 * (tr * 0.72), pos.y + th, pos.z + s0 * (tr * 0.72))
			var q1 := Vector3(pos.x + c1 * (tr * 0.72), pos.y + th, pos.z + s1 * (tr * 0.72))
			var n0 := Vector3(c0, 0.08, s0).normalized()
			var n1 := Vector3(c1, 0.08, s1).normalized()
			_emit_tri(st, p0, p1, q1, n0, n1, n1, ub, ub, ut, bcol)
			_emit_tri(st, p0, q1, q0, n0, n1, n0, ub, ut, ut, bcol)

	var a_off := seed * TAU
	if kind == KIND_PINE:
		# 针叶冷杉/云杉：六层平展错落羽状枝轮 + 柔和钝顶（彻底消除尖细铅笔刺与塑料圆锥）
		var tiers := [
			[pos.y + h * 0.18, pos.y + h * 0.34, cr * 1.02, cr * 0.44, 0.06, 0.32],
			[pos.y + h * 0.30, pos.y + h * 0.48, cr * 0.90, cr * 0.38, 0.18, 0.46],
			[pos.y + h * 0.43, pos.y + h * 0.61, cr * 0.78, cr * 0.32, 0.32, 0.60],
			[pos.y + h * 0.56, pos.y + h * 0.74, cr * 0.64, cr * 0.26, 0.48, 0.74],
			[pos.y + h * 0.69, pos.y + h * 0.86, cr * 0.48, cr * 0.18, 0.64, 0.88],
			[pos.y + h * 0.82, pos.y + h * 0.96, cr * 0.32, cr * 0.06, 0.78, 0.98],
		]
		var lean_x := cos(a_off * 1.7) * cr * 0.08
		var lean_z := sin(a_off * 1.7) * cr * 0.08
		for ti in 6:
			var t: Array = tiers[ti]
			var yb: float = t[0]
			var yt: float = t[1]
			var rb: float = t[2]
			var rt: float = t[3]
			var u0 := Vector2(1.0, t[4])
			var u1 := Vector2(1.0, t[5])
			var u_under := Vector2(1.0, maxf(0.02, float(t[4]) - 0.10))
			var rot_t := a_off + float(ti) * 0.83
			var cx_t := pos.x + lean_x * (float(ti) * 0.20)
			var cz_t := pos.z + lean_z * (float(ti) * 0.20)
			var inner_y := yb + (yt - yb) * 0.20
			for i in 8:
				var a0 := rot_t + TAU * float(i) / 8.0
				var a1 := rot_t + TAU * float(i + 1) / 8.0
				var sp0 := 0.70 + 0.46 * absf(sin(float(i) * 2.35 + seed * 13.0 + float(ti) * 2.1))
				var sp1 := 0.70 + 0.46 * absf(sin(float((i + 1) % 8) * 2.35 + seed * 13.0 + float(ti) * 2.1))
				var drp0 := (sp0 - 0.90) * (yt - yb) * 0.24
				var drp1 := (sp1 - 0.90) * (yt - yb) * 0.24
				var c0 := cos(a0)
				var s0 := sin(a0)
				var c1 := cos(a1)
				var s1 := sin(a1)
				var n0 := Vector3(c0, 0.38, s0).normalized()
				var n1 := Vector3(c1, 0.38, s1).normalized()
				var n_dn := Vector3(0.0, -1.0, 0.0)
				var b0 := Vector3(cx_t + c0 * rb * sp0, yb - drp0, cz_t + s0 * rb * sp0)
				var b1 := Vector3(cx_t + c1 * rb * sp1, yb - drp1, cz_t + s1 * rb * sp1)
				var in0 := Vector3(cx_t + c0 * rb * 0.28, inner_y, cz_t + s0 * rb * 0.28)
				var in1 := Vector3(cx_t + c1 * rb * 0.28, inner_y, cz_t + s1 * rb * 0.28)
				_emit_tri(st, b1, b0, in0, n_dn, n_dn, n_dn, u_under, u_under, u_under, col)
				_emit_tri(st, b1, in0, in1, n_dn, n_dn, n_dn, u_under, u_under, u_under, col)
				var m0 := Vector3(cx_t + c0 * rt * (0.80 + sp0 * 0.20), yt, cz_t + s0 * rt * (0.80 + sp0 * 0.20))
				var m1 := Vector3(cx_t + c1 * rt * (0.80 + sp1 * 0.20), yt, cz_t + s1 * rt * (0.80 + sp1 * 0.20))
				_emit_tri(st, b0, b1, m1, n0, n1, n1, u0, u0, u1, col)
				_emit_tri(st, b0, m1, m0, n0, n1, n0, u0, u1, u1, col)
				if ti == 5:
					_emit_tri(st, m0, m1, Vector3(cx_t, yt + h * 0.03, cz_t), n0, n1, Vector3.UP, u1, u1, Vector2(1.0, 1.0), col)
	else:
		# 阔叶/秋叶乔木：六团分离错落中小型叶团簇（模拟真实树枝分叉叶丛凹凸剪影，杜绝巨型浑圆卷心菜球！）
		var puffs := [
			[Vector3(cos(a_off * 0.7) * cr * 0.14, h * 0.70, sin(a_off * 0.7) * cr * 0.14), 0.56, 0.42, 0.48, 1.00],
			[Vector3(cos(a_off) * cr * 0.50, h * 0.54, sin(a_off) * cr * 0.50), 0.52, 0.38, 0.22, 0.86],
			[Vector3(cos(a_off + 1.55) * cr * 0.48, h * 0.60, sin(a_off + 1.55) * cr * 0.48), 0.48, 0.36, 0.28, 0.90],
			[Vector3(cos(a_off + 3.05) * cr * 0.52, h * 0.50, sin(a_off + 3.05) * cr * 0.52), 0.50, 0.36, 0.16, 0.82],
			[Vector3(cos(a_off + 4.55) * cr * 0.46, h * 0.58, sin(a_off + 4.55) * cr * 0.46), 0.47, 0.35, 0.24, 0.88],
			[Vector3(cos(a_off + 2.30) * cr * 0.24, h * 0.42, sin(a_off + 2.30) * cr * 0.24), 0.50, 0.32, 0.08, 0.64],
		]
		for li in 6:
			var pf: Array = puffs[li]
			var pc: Vector3 = pos + (pf[0] as Vector3)
			var rx: float = cr * float(pf[1])
			var ry: float = h * float(pf[2]) * 0.5
			var y_bot := pc.y - ry * 0.76
			var y_eq := pc.y - ry * 0.06
			var y_sh := pc.y + ry * 0.62
			var y_top := pc.y + ry * 0.96
			var dome_top := Vector3(pc.x, y_top, pc.z)
			var u0 := Vector2(1.0, float(pf[3]))
			var u1 := Vector2(1.0, lerpf(float(pf[3]), float(pf[4]), 0.45))
			var u2 := Vector2(1.0, lerpf(float(pf[3]), float(pf[4]), 0.82))
			var u3 := Vector2(1.0, float(pf[4]))
			for i in 7:
				var a0 := a_off + float(li) * 1.15 + TAU * float(i) / 7.0
				var a1 := a_off + float(li) * 1.15 + TAU * float(i + 1) / 7.0
				var w0 := 0.80 + 0.34 * absf(sin(float(i) * 2.5 + seed * 9.0 + float(li) * 2.3))
				var w1 := 0.80 + 0.34 * absf(sin(float((i + 1) % 7) * 2.5 + seed * 9.0 + float(li) * 2.3))
				var c0 := cos(a0)
				var s0 := sin(a0)
				var c1 := cos(a1)
				var s1 := sin(a1)
				var b0 := Vector3(pc.x + c0 * rx * 0.66 * w0, y_bot, pc.z + s0 * rx * 0.66 * w0)
				var b1 := Vector3(pc.x + c1 * rx * 0.66 * w1, y_bot, pc.z + s1 * rx * 0.66 * w1)
				var m0 := Vector3(pc.x + c0 * rx * 1.04 * w0, y_eq, pc.z + s0 * rx * 1.04 * w0)
				var m1 := Vector3(pc.x + c1 * rx * 1.04 * w1, y_eq, pc.z + s1 * rx * 1.04 * w1)
				var s_p0 := Vector3(pc.x + c0 * rx * 0.72 * w0, y_sh, pc.z + s0 * rx * 0.72 * w0)
				var s_p1 := Vector3(pc.x + c1 * rx * 0.72 * w1, y_sh, pc.z + s1 * rx * 0.72 * w1)
				var nb0 := Vector3(c0, -0.52, s0).normalized()
				var nb1 := Vector3(c1, -0.52, s1).normalized()
				var nm0 := Vector3(c0, 0.14, s0).normalized()
				var nm1 := Vector3(c1, 0.14, s1).normalized()
				var ns0 := Vector3(c0, 0.72, s0).normalized()
				var ns1 := Vector3(c1, 0.72, s1).normalized()
				_emit_tri(st, b0, b1, m1, nb0, nb1, nm1, u0, u0, u1, col)
				_emit_tri(st, b0, m1, m0, nb0, nm1, nm0, u0, u1, u1, col)
				_emit_tri(st, m0, m1, s_p1, nm0, nm1, ns1, u1, u1, u2, col)
				_emit_tri(st, m0, s_p1, s_p0, nm0, ns1, ns0, u1, u2, u2, col)
				_emit_tri(st, s_p0, s_p1, dome_top, ns0, ns1, Vector3.UP, u2, u2, u3, col)
