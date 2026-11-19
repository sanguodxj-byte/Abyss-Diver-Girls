extends RefCounted
## 30 项精修建筑、重型载具残骸、野战工事与微地貌预制件缓存合批库
## 每个预制脚本仅在首次使用时构建一次原型树，按解析后的共享世界材质预合并为 ArrayMesh（完整保留倒角边缘顶点色与法线），
## 随后通过 raid._imesh 注册到 48m 静态分块合批 / MultiMesh 管线，兼顾高细节硬表面结构、地标清场剥离与低 Draw Call。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")
const RB = preload("res://scripts/render_batch.gd")

const SPECS := {
	"bldg_house": {"path": "res://scripts/buildings/bldg_house.gd", "base": Vector3(9.6, 4.2, 7.6)},
	"bldg_warehouse": {"path": "res://scripts/buildings/bldg_warehouse.gd", "base": Vector3(13.6, 5.4, 9.2)},
	"bldg_apartment": {"path": "res://scripts/buildings/bldg_apartment.gd", "base": Vector3(14.4, 10.2, 8.6)},
	"bldg_factory_shed": {"path": "res://scripts/buildings/bldg_factory_shed.gd", "base": Vector3(14.2, 6.0, 9.6)},
	"bldg_barrack": {"path": "res://scripts/buildings/bldg_barrack.gd", "base": Vector3(13.2, 4.4, 7.8)},
	"bldg_arcade_shop": {"path": "res://scripts/buildings/bldg_arcade_shop.gd", "base": Vector3(13.8, 8.8, 8.6)},
	"bldg_stepped_tower": {"path": "res://scripts/buildings/bldg_stepped_tower.gd", "base": Vector3(14.8, 13.5, 9.6)},
	"bldg_courtyard_blk": {"path": "res://scripts/buildings/bldg_courtyard_blk.gd", "base": Vector3(15.2, 8.4, 11.4)},
	"bldg_terrace": {"path": "res://scripts/buildings/bldg_terrace.gd", "base": Vector3(14.6, 6.2, 7.8)},
	"bldg_tenement": {"path": "res://scripts/buildings/bldg_tenement.gd", "base": Vector3(15.0, 11.2, 8.4)},
	"bldg_substation": {"path": "res://scripts/buildings/bldg_substation.gd", "base": Vector3(13.4, 6.4, 9.2)},
	"bldg_foundry": {"path": "res://scripts/buildings/bldg_foundry.gd", "base": Vector3(15.4, 7.2, 10.6)},
	"bldg_chem_plant": {"path": "res://scripts/buildings/bldg_chem_plant.gd", "base": Vector3(14.6, 8.6, 10.0)},
	"bldg_loco_shed": {"path": "res://scripts/buildings/bldg_loco_shed.gd", "base": Vector3(15.6, 6.8, 10.4)},
	"bldg_command_bunker": {"path": "res://scripts/buildings/bldg_command_bunker.gd", "base": Vector3(13.0, 5.6, 9.4)},
	"veh_dump_truck": {"path": "res://scripts/buildings/veh_dump_truck.gd", "base": Vector3(2.9, 3.35, 7.2)},
	"veh_apc_wreck": {"path": "res://scripts/buildings/veh_apc_wreck.gd", "base": Vector3(2.82, 2.65, 7.35)},
	"veh_fuel_tanker": {"path": "res://scripts/buildings/veh_fuel_tanker.gd", "base": Vector3(2.65, 3.15, 7.5)},
	"veh_armored_dozer": {"path": "res://scripts/buildings/veh_armored_dozer.gd", "base": Vector3(2.85, 3.2, 6.1)},
	"ter_road_shoulder": {"path": "res://scripts/buildings/ter_road_shoulder.gd", "base": Vector3(12.0, 0.65, 6.4)},
	"fort_pillbox_bunker": {"path": "res://scripts/buildings/fort_pillbox_bunker.gd", "base": Vector3(6.8, 3.2, 6.8)},
	"fort_watchtower": {"path": "res://scripts/buildings/fort_watchtower.gd", "base": Vector3(5.4, 9.8, 5.4)},
	"ind_oil_tank_chimney": {"path": "res://scripts/buildings/ind_oil_tank_chimney.gd", "base": Vector3(9.2, 11.5, 8.6)},
	"ter_dragon_teeth_pipe": {"path": "res://scripts/buildings/ter_dragon_teeth_pipe.gd", "base": Vector3(10.4, 2.3, 7.6)},
	"ter_arid_flora_pylon": {"path": "res://scripts/buildings/ter_arid_flora_pylon.gd", "base": Vector3(10.8, 5.4, 8.2)},
	"poi_generic_building": {"path": "res://scripts/buildings/poi_generic_building.gd", "base": Vector3(11.6, 8.6, 9.2)},
	"poi_duplex_coldstore": {"path": "res://scripts/buildings/poi_duplex_coldstore.gd", "base": Vector3(14.0, 6.4, 9.0)},
	"poi_silo_radar": {"path": "res://scripts/buildings/poi_silo_radar.gd", "base": Vector3(14.4, 10.8, 9.6)},
	"poi_gantry_rail": {"path": "res://scripts/buildings/poi_gantry_rail.gd", "base": Vector3(15.8, 12.4, 10.2)},
	"poi_abyss_gate_rig": {"path": "res://scripts/buildings/poi_abyss_gate_rig.gd", "base": Vector3(16.0, 12.8, 16.0)},
}

static var _cache: Dictionary = {}
static var _std_dedup: Dictionary = {}


static func base_size(id: String) -> Vector3:
	var sp: Dictionary = SPECS.get(id, {})
	return sp.get("base", Vector3.ONE) as Vector3


static func clear_cache() -> void:
	_cache.clear()
	_std_dedup.clear()


static func get_prefab(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var sp: Dictionary = SPECS.get(id, {})
	if sp.is_empty():
		push_error("[prefab_lib] unknown prefab id: %s" % id)
		return {}
	var bsz: Vector3 = sp["base"]
	var scr: GDScript = load(str(sp["path"]))
	var root: Node3D = scr.build(bsz)
	root.transform = Transform3D.IDENTITY

	var raw_parts: Array = []
	var primary_votes: Dictionary = {}
	var primary_mats: Dictionary = {}
	var stencils: Array = []

	_collect_recursive(id, root, Transform3D.IDENTITY, "", raw_parts, primary_votes, primary_mats, stencils)
	root.free()

	var primary_rid := 0
	var best_v := -1
	for rid_k: int in primary_votes:
		var v_cnt: int = int(primary_votes[rid_k])
		if v_cnt > best_v:
			best_v = v_cnt
			primary_rid = rid_k

	var groups: Dictionary = {}
	for rp: Array in raw_parts:
		var p_mesh: Mesh = rp[0]
		var p_si: int = int(rp[1])
		var p_xf: Transform3D = rp[2]
		var res_m: Material = rp[3]
		var shadow_on: bool = bool(rp[4])
		var m_id: int = res_m.get_rid().get_id() if res_m != null else 0
		var is_prim: bool = (primary_rid != 0 and m_id == primary_rid)
		if is_prim:
			var gk_p := "prim|%d|%d" % [m_id, 1 if shadow_on else 0]
			if not groups.has(gk_p):
				groups[gk_p] = {"mat": res_m, "shadow": shadow_on, "tint": 0, "primary": true, "parts": []}
			(groups[gk_p]["parts"] as Array).append([p_mesh, p_si, p_xf, Color.WHITE])
		else:
			var st: Array = RB.split_tint(res_m, 3)
			var shared_m: Material = st[0]
			var col_t: Color = st[1]
			var tint_kind := 0
			if shared_m != res_m:
				tint_kind = 2 if shared_m is StandardMaterial3D else 1
			var sm_id: int = shared_m.get_rid().get_id() if shared_m != null else 0
			var gk_s := "sh|%d|%d" % [sm_id, 1 if shadow_on else 0]
			if not groups.has(gk_s):
				groups[gk_s] = {"mat": shared_m, "shadow": shadow_on, "tint": tint_kind, "primary": false, "parts": []}
			(groups[gk_s]["parts"] as Array).append([p_mesh, p_si, p_xf, col_t])

	var surfaces: Array = []
	for gk: String in groups:
		var g: Dictionary = groups[gk]
		var am: ArrayMesh = _merge_parts(g["parts"] as Array, int(g["tint"]))
		if am == null or am.get_surface_count() == 0:
			continue
		am.set_meta("prefab_inst", true)
		surfaces.append({
			"mesh": am,
			"mat": g["mat"],
			"shadow": bool(g["shadow"]),
			"primary": bool(g["primary"]),
		})

	var entry := {
		"id": id,
		"base_sz": bsz,
		"surfaces": surfaces,
		"stencils": stencils,
		"primary_mat": primary_mats.get(primary_rid, null),
	}
	_cache[id] = entry
	return entry


static func _collect_recursive(
	id: String,
	node: Node,
	parent_xf: Transform3D,
	anc_path: String,
	raw_parts: Array,
	primary_votes: Dictionary,
	primary_mats: Dictionary,
	stencils: Array
) -> void:
	var cur_xf := parent_xf
	var cur_path := anc_path
	if node is Node3D:
		var n3: Node3D = node as Node3D
		if not n3.visible:
			return
		cur_xf = parent_xf * n3.transform
		var nm := String(n3.name)
		if not nm.begins_with("@"):
			cur_path = nm if anc_path == "" else (anc_path + "/" + nm)

	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh != null:
			var shadow_on: bool = (id != "ter_road_shoulder") and not cur_path.contains("GroundedApron") and not cur_path.contains("Tier3_DryGrassClump")
			for si in mi.mesh.get_surface_count():
				var raw_m: Material = mi.material_override
				if raw_m == null and si < mi.get_surface_override_material_count():
					raw_m = mi.get_surface_override_material(si)
				if raw_m == null:
					raw_m = mi.mesh.surface_get_material(si)
				var res_m: Material = _resolve_material(id, cur_path, raw_m)
				var m_id: int = res_m.get_rid().get_id() if res_m != null else 0
				raw_parts.append([mi.mesh, si, cur_xf, res_m, shadow_on])
				if _is_primary_candidate(id, cur_path, res_m):
					var arrays: Array = mi.mesh.surface_get_arrays(si)
					var v_arr: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					primary_votes[m_id] = int(primary_votes.get(m_id, 0)) + v_arr.size()
					primary_mats[m_id] = res_m
	elif node is Label3D:
		var lbl: Label3D = node as Label3D
		stencils.append({
			"text": lbl.text,
			"xf": cur_xf,
			"px": lbl.pixel_size,
			"col": lbl.modulate,
			"fs": lbl.font_size,
		})

	for ch in node.get_children():
		_collect_recursive(id, ch, cur_xf, cur_path, raw_parts, primary_votes, primary_mats, stencils)


static func _is_primary_candidate(id: String, path: String, mat: Material) -> bool:
	if mat == null or not (mat is ShaderMaterial):
		return false
	if path.contains("Plinth") or path.contains("Foundation") or path.contains("Apron") \
			or path.contains("CavityCore") or path.contains("Window") or path.contains("Door") \
			or path.contains("Wheel") or path.contains("Track") or path.contains("Sandbag") \
			or path.contains("Roof") or path.contains("Ladder") or path.contains("Piston"):
		return false
	if id.begins_with("veh_"):
		return path.contains("Cab") or path.contains("Bed") or path.contains("Hull") \
			or path.contains("Trailer") or path.contains("Hood") or path.contains("Blade")
	return path.contains("Body") or path.contains("StructWall") or path.contains("Hall") \
		or path.contains("Wing") or path.contains("Store") or path.contains("House")


static func _resolve_material(id: String, path: String, mat: Material) -> Material:
	if mat == null:
		return A.concrete(Color(0.46, 0.44, 0.40), false)
	if mat is StandardMaterial3D:
		var sm_std: StandardMaterial3D = mat as StandardMaterial3D
		var is_lens: bool = path.contains("OpticalLens") or path.contains("Headlight") or path.contains("Searchlight") or path.contains("SignalHead")
		if not is_lens and (id.begins_with("bldg_") or id.begins_with("poi_") or id.begins_with("fort_")) and sm_std.albedo_color.v < 0.08:
			return A.window_mat(0.18, Vector2(0.54, 0.60))
		var skey := "std|%s|%.2f|%.2f|%d|%s|%.2f|%d" % [
			sm_std.albedo_color.to_html(), sm_std.metallic, sm_std.roughness,
			1 if sm_std.emission_enabled else 0, sm_std.emission.to_html(),
			sm_std.emission_energy_multiplier, 1 if sm_std.clearcoat_enabled else 0,
		]
		if _std_dedup.has(skey):
			return _std_dedup[skey]
		_std_dedup[skey] = sm_std
		return sm_std

	if not (mat is ShaderMaterial):
		return mat
	var sm: ShaderMaterial = mat as ShaderMaterial
	if sm.shader == null:
		return mat
	var s_path := sm.shader.resource_path
	if not s_path.ends_with("mech_paint.gdshader") and not s_path.ends_with("mech_paint_mobile.gdshader"):
		return mat

	var col_v: Variant = sm.get_shader_parameter("base_color")
	var c: Color = col_v as Color if col_v != null else Color(0.5, 0.5, 0.5)
	var mb_v: Variant = sm.get_shader_parameter("metal_base")
	var mb: float = float(mb_v) if mb_v != null else 0.15
	var rb_v: Variant = sm.get_shader_parameter("rough_base")
	var rb: float = float(rb_v) if rb_v != null else 0.62
	var stp_v: Variant = sm.get_shader_parameter("stripes")
	if stp_v != null and float(stp_v) > 0.5:
		return mat

	var max_rgb := maxf(c.r, maxf(c.g, c.b))
	if max_rgb < 0.085 and mb < 0.10:
		return mat

	# 自然枯木、耐旱沙棘灌丛与荒漠针茅干草（消除金属钢板高光，使用树皮与哑光生态着色）
	if path.contains("Tier1_AridDeadwood"):
		return A.bark_mat(c)
	if path.contains("Tier2_BuckthornShrub") or path.contains("Tier3_DryGrassClump"):
		return A.paint(c, 0.0, 0.88, {
			"use_albedo_tex": 0.0, "metal_wear": 0.0, "wear": 0.18,
			"scratches": 0.0, "rust": 0.0, "dust": 0.34, "panel_scale": 0.0,
		})

	# 道路沥青、风沙堆积棱体与弹坑焦土底盘
	if path.contains("CrackedAsphalt"):
		return A.asphalt(c)
	if path.contains("WindblownSandDrift") or path.contains("ArtilleryShellCrater") \
			or (id.begins_with("ter_") and path.contains("GroundedApron")):
		return A.gravel_mat(c)

	# 战地沙袋、封窗木板、储煤木箱与货物托盘（哑光粗麻/旧木，无金属掉漆）
	if path.contains("SandbagRevetment") or path.contains("BoardPlank") \
			or path.contains("CoalStorageBin") or path.contains("CargoPallet") \
			or (path.contains("RailYardTracks") and mb < 0.08 and c.r > c.b + 0.05):
		return A.paint(c, 0.0, 0.92, {
			"use_albedo_tex": 0.0, "metal_wear": 0.0, "wear": 0.36,
			"scratches": 0.0, "rust": 0.12, "dust": 0.46, "panel_scale": 0.0,
		})

	# 压型波纹钢屋面、卷帘门、粮仓筒体与轻钢厂房墙皮
	if path.contains("RollerDoor") or path.contains("MaintenanceBayDoor") or path.contains("LocoBayDoor") \
			or path.contains("PortalWarehouseBody") or path.contains("ArmoredBarrackBody") \
			or path.contains("AmmoniaColdStore") or path.contains("GrainSilo") \
			or path.contains("RoofSlopeDeck") or path.contains("TerracePitchedRoof") \
			or path.contains("ArmoredQuonsetRoof") or path.contains("StructuredVaultRoof"):
		if mb >= 0.12 or rb <= 0.78:
			return A.corrugated(c, clampf(mb, 0.34, 0.58), 0.34)

	# 低金属高粗糙度建筑墙体、柱础、勒脚、暗堡与烟囱 -> 真实 2K 窑变红砖 / 现浇模板混凝土
	if mb <= 0.10 and rb >= 0.78:
		var warm_masonry: bool = (c.r - c.b) > 0.058 and (
			path.contains("Masonry") or path.contains("Chimney") or path.contains("Terrace")
			or path.contains("Courtyard") or path.contains("Foundry") or path.contains("Arcade")
			or path.contains("StructWall") or path.contains("StructPier") or path.contains("CornerPilaster")
			or path.contains("AtticDormer") or path.contains("DispatchDuplex") or path.contains("CupolaFurnace")
		)
		if warm_masonry:
			return A.brick(c)
		var use_seams: bool = path.contains("StructWall") or path.contains("Body") or path.contains("Casemate") or path.contains("Bunker")
		return A.concrete(c, use_seams)

	return mat


static func _merge_parts(parts: Array, tint_kind := 0) -> ArrayMesh:
	var total_v := 0
	var total_i := 0
	var raw_list: Array = []
	for p: Array in parts:
		var mesh: Mesh = p[0]
		var si: int = int(p[1])
		var xf: Transform3D = p[2]
		var tcol: Color = p[3]
		var a: Array = mesh.surface_get_arrays(si)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nv := v.size()
		if nv == 0:
			continue
		var nrm: PackedVector3Array
		if a[Mesh.ARRAY_NORMAL] != null and (a[Mesh.ARRAY_NORMAL] as PackedVector3Array).size() == nv:
			nrm = a[Mesh.ARRAY_NORMAL]
		else:
			nrm = PackedVector3Array()
			nrm.resize(nv)
			nrm.fill(Vector3.UP)
		var col: PackedColorArray
		if a[Mesh.ARRAY_COLOR] != null and (a[Mesh.ARRAY_COLOR] as PackedColorArray).size() == nv:
			col = a[Mesh.ARRAY_COLOR]
		else:
			col = PackedColorArray()
			col.resize(nv)
			col.fill(Color.WHITE)
		var idx: PackedInt32Array
		if a[Mesh.ARRAY_INDEX] != null and (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() > 0:
			idx = a[Mesh.ARRAY_INDEX]
		else:
			idx = PackedInt32Array()
			idx.resize(nv)
			for k in nv:
				idx[k] = k
		total_v += nv
		total_i += idx.size()
		raw_list.append([v, nrm, col, idx, xf, tcol])

	if total_v == 0 or total_i == 0:
		return null

	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_c := PackedColorArray()
	var out_i := PackedInt32Array()
	out_v.resize(total_v)
	out_n.resize(total_v)
	out_c.resize(total_v)
	out_i.resize(total_i)

	var vo := 0
	var io := 0
	for item: Array in raw_list:
		var sv: PackedVector3Array = item[0]
		var sn: PackedVector3Array = item[1]
		var sc: PackedColorArray = item[2]
		var si_arr: PackedInt32Array = item[3]
		var xf: Transform3D = item[4]
		var tcol: Color = item[5]
		var inv_t := xf.basis.inverse().transposed()
		var flip := xf.basis.determinant() < 0.0
		var nv := sv.size()
		for k in nv:
			var vi := vo + k
			out_v[vi] = xf * sv[k]
			var tn := inv_t * sn[k]
			out_n[vi] = tn.normalized() if tn.length_squared() > 1e-8 else Vector3.UP
			if tint_kind == 1:
				out_c[vi] = Color(sc[k].r, tcol.r, tcol.g, tcol.b)
			elif tint_kind == 2:
				out_c[vi] = tcol
			else:
				out_c[vi] = sc[k]
		var ni := si_arr.size()
		if flip:
			var k := 0
			while k + 2 < ni:
				out_i[io + k] = vo + si_arr[k]
				out_i[io + k + 1] = vo + si_arr[k + 2]
				out_i[io + k + 2] = vo + si_arr[k + 1]
				k += 3
		else:
			for k in ni:
				out_i[io + k] = vo + si_arr[k]
		vo += nv
		io += ni

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = out_v
	arr[Mesh.ARRAY_NORMAL] = out_n
	arr[Mesh.ARRAY_COLOR] = out_c
	arr[Mesh.ARRAY_INDEX] = out_i
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


## 将预制件挂接到中心在 y = target_sz.y * 0.5 的楼体/载具 StaticBody3D 上（走 raid._imesh 合批，支持地标清场自动剥离）
## flip_front = true 时绕 Y 旋转 180°，使预制件 -Z 正门朝向 world_city 约定的 +Z 临街方向。
static func place_on_body(
	raid,
	sb: Node3D,
	id: String,
	target_sz: Vector3,
	flip_front := true,
	tint_mat: Material = null,
	y_off := -999.0,
	with_stencil := false,
	stencil_text := ""
) -> void:
	var pf := get_prefab(id)
	if pf.is_empty():
		return
	var bsz: Vector3 = pf["base_sz"]
	var scl := Vector3(
		maxf(0.15, target_sz.x / maxf(0.1, bsz.x)),
		maxf(0.15, target_sz.y / maxf(0.1, bsz.y)),
		maxf(0.15, target_sz.z / maxf(0.1, bsz.z))
	)
	var pos := Vector3(0.0, (-target_sz.y * 0.5) if y_off <= -900.0 else y_off, 0.0)
	var rot_deg := Vector3(0.0, 180.0, 0.0) if flip_front else Vector3.ZERO
	var surfaces: Array = pf["surfaces"]
	for s_info: Dictionary in surfaces:
		var use_mat: Material = s_info["mat"]
		if tint_mat != null and bool(s_info["primary"]):
			use_mat = tint_mat
		raid._imesh(sb, s_info["mesh"] as Mesh, use_mat, pos, rot_deg, scl, bool(s_info["shadow"]))
	# 地图建筑不再附加 3D Label3D 文字，避免远景或残墙上出现悬浮字样
	var _unused_st := with_stencil or stencil_text != ""


## 在 raid.world 下按地面基准点 y=0 放置无独立刚体（或自定义复合碰撞）的地貌/巨构预制件
static func place_at_ground(
	raid,
	parent: Node3D,
	id: String,
	local_pos: Vector3,
	yaw_deg := 0.0,
	target_sz := Vector3.ZERO,
	flip_front := false,
	tint_mat: Material = null,
	with_stencil := false
) -> Node3D:
	var pf := get_prefab(id)
	if pf.is_empty():
		return null
	var bsz: Vector3 = pf["base_sz"]
	var use_sz := bsz if target_sz == Vector3.ZERO else target_sz
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position = local_pos
	holder.rotation_degrees.y = yaw_deg
	# 若 parent 不是 raid.world（例如地标根节点），把 holder 的全局变换折算后挂入 _imesh
	var scl := Vector3(
		maxf(0.15, use_sz.x / maxf(0.1, bsz.x)),
		maxf(0.15, use_sz.y / maxf(0.1, bsz.y)),
		maxf(0.15, use_sz.z / maxf(0.1, bsz.z))
	)
	var rot_deg := Vector3(0.0, 180.0, 0.0) if flip_front else Vector3.ZERO
	var world_holder: Node3D = holder
	var surfaces: Array = pf["surfaces"]
	if parent == raid.world:
		for s_info: Dictionary in surfaces:
			var use_mat: Material = s_info["mat"]
			if tint_mat != null and bool(s_info["primary"]):
				use_mat = tint_mat
			raid._imesh(world_holder, s_info["mesh"] as Mesh, use_mat, Vector3.ZERO, rot_deg, scl, bool(s_info["shadow"]))
	else:
		# parent 在嵌套子节点下：直接挂合并后的单材质 MeshInstance3D，供 _bake_static 自动按全局变换合批
		var bs := Basis.from_euler(rot_deg * (PI / 180.0)) * Basis.from_scale(scl)
		var l_xf := Transform3D(bs, Vector3.ZERO)
		for s_info: Dictionary in surfaces:
			var use_mat: Material = s_info["mat"]
			if tint_mat != null and bool(s_info["primary"]):
				use_mat = tint_mat
			var mi := MeshInstance3D.new()
			mi.mesh = s_info["mesh"] as Mesh
			mi.material_override = use_mat
			mi.transform = l_xf
			if not bool(s_info["shadow"]):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)
	var _unused_st2 := with_stencil
	return holder
