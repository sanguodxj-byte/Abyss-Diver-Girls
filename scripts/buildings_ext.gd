extends RefCounted
## 扩展写实重工与城市建筑样式库（13 种新增建筑类型 + 远景 MultiMesh 轮廓同步）
## 全部接入 scripts/buildings/prefab_lib.gd 精修硬表面建筑资产（压顶女儿墙、真内凹窗洞、出屋面机房、高勒脚散水与多面体雷达罩），
## 统一走 raid._bldg_body / _imesh，既走 48m 分块合批与 MultiMesh，又支持地标清场自动剥离。
## 严格限制任何外挑构件 <= 0.85m，配合 world_city 全局 4.15m OBB 间距，实现 100% 零穿模重叠。

const A = preload("res://scripts/art.gd")
const PrefabLib = preload("res://scripts/buildings/prefab_lib.gd")


const BRICK_COLS := [Color(0.38, 0.28, 0.24), Color(0.34, 0.26, 0.23), Color(0.40, 0.31, 0.27)]
const STONE_COLS := [Color(0.53, 0.52, 0.49), Color(0.47, 0.47, 0.45), Color(0.57, 0.55, 0.51)]
const CONC_COLS := [Color(0.43, 0.44, 0.45), Color(0.37, 0.39, 0.40), Color(0.47, 0.46, 0.44)]


static func build(raid, kind: String, p: Vector3, sz: Vector3, rot: float) -> bool:
	match kind:
		"highrise_office":
			_place_ext(raid, "bldg_highrise_office", p, sz, rot, _pick_facade(raid, 0.12, 0.42))
		"brutalist_slab":
			_place_ext(raid, "bldg_brutalist_slab", p, sz, rot, _pick_facade(raid, 0.16, 0.26))
		"civic_block":
			_place_ext(raid, "bldg_civic_block", p, sz, rot, _pick_facade(raid, 0.0, 0.72))
		"midrise_office":
			_place_ext(raid, "bldg_midrise_office", p, sz, rot, _pick_facade(raid, 0.25, 0.42))
		"rowblock":
			_place_ext(raid, "bldg_rowblock", p, sz, rot, null)
		"arcade_shop":
			_place_ext(raid, "bldg_arcade_shop", p, sz, rot, _pick_facade(raid, 0.28, 0.35))
		"stepped_tower":
			_place_ext(raid, "bldg_stepped_tower", p, sz, rot, _pick_facade(raid, 0.0, 0.50))
		"courtyard_blk":
			_place_ext(raid, "bldg_courtyard_blk", p, sz, rot, _pick_facade(raid, 0.32, 0.30))
		"substation":
			_place_ext(raid, "bldg_substation", p, sz, rot, null, raid.rng.randf() < 0.55, "HV-110KV")
		"terrace":
			_place_ext(raid, "bldg_terrace", p, sz, rot, _pick_facade(raid, 0.38, 0.28))
		"duplex":
			_place_ext(raid, "poi_duplex_coldstore", p, sz, rot, _pick_facade(raid, 0.28, 0.32))
		"tenement":
			_place_ext(raid, "bldg_tenement", p, sz, rot, _pick_facade(raid, 0.30, 0.30))
		"foundry":
			var f_brick := [Color(0.44, 0.28, 0.22), Color(0.39, 0.26, 0.21)]
			var f_conc := [Color(0.40, 0.39, 0.37), Color(0.36, 0.38, 0.40)]
			_place_ext(raid, "bldg_foundry", p, sz, rot, _pick_facade(raid, 0.65, 0.0, f_brick, STONE_COLS, f_conc), raid.rng.randf() < 0.45)
		"chem_plant":
			_place_ext(raid, "bldg_chem_plant", p, sz, rot, null, raid.rng.randf() < 0.45)
		"cold_store":
			var cc: Color = [Color(0.50, 0.55, 0.57), Color(0.45, 0.50, 0.54), Color(0.54, 0.54, 0.51)][raid.rng.randi() % 3]
			_place_ext(raid, "poi_duplex_coldstore", p, sz, rot, A.corrugated(cc, 0.34, 0.28), raid.rng.randf() < 0.55, "COLD-04")
		"loco_shed":
			var use_br: bool = raid.rng.randi() % 2 == 0
			var lc := Color(0.44, 0.29, 0.22) if use_br else Color(0.36, 0.38, 0.40)
			var lmat: Material = A.brick(lc) if use_br else A.corrugated(lc, 0.46, 0.28)
			_place_ext(raid, "bldg_loco_shed", p, sz, rot, lmat, raid.rng.randf() < 0.45)
		"command_bunker":
			_place_ext(raid, "bldg_command_bunker", p, sz, rot, null, true, "CMD-HQ")
		"silo_barn":
			_place_ext(raid, "poi_silo_radar", p, sz, rot, null, raid.rng.randf() < 0.45)
		"city_bakery":
			_place_ext(raid, "poi_city_bakery_remake", p, sz, rot, null)
		"post_office":
			_place_ext(raid, "poi_post_office_remake", p, sz, rot, null)
		"police_precinct":
			_place_ext(raid, "poi_police_precinct_remake", p, sz, rot, null)
		"fire_station":
			var fs_id := "poi_fire_station_remake" if maxf(sz.x, sz.z) >= 15.0 else "b6_fire_station"
			_place_ext(raid, fs_id, p, sz, rot, null)
		"b6_fire_station":
			_place_ext(raid, "b6_fire_station", p, sz, rot, null)
		"cooling_tower":
			_place_ext(raid, "bldg_cooling_tower_unit_remake", p, sz, rot, null)
		"fuel_tank_farm":
			_place_ext(raid, "bldg_fuel_tank_farm_remake", p, sz, rot, null)
		"salvage_foundry":
			_place_ext(raid, "bldg_salvage_foundry_remake", p, sz, rot, null)
		"water_tower_pump":
			_place_ext(raid, "bldg_water_tower_pump_remake", p, sz, rot, null)
		"factory_smelter":
			_place_ext(raid, "poi_factory_smelter_remake", p, sz, rot, null)
		"b6_foundry_kiln":
			_place_ext(raid, "b6_foundry_kiln", p, sz, rot, null)
		"bldg_water_tower":
			_place_ext(raid, "bldg_water_tower", p, sz, rot, null)
		"port_warehouse":
			_place_ext(raid, "poi_port_warehouse_remake", p, sz, rot, null)
		"cold_storage":
			_place_ext(raid, "poi_cold_storage_remake", p, sz, rot, null)
		"ferry_terminal":
			_place_ext(raid, "poi_ferry_terminal_remake", p, sz, rot, null)
		"dockside_gantry":
			_place_ext(raid, "bldg_dockside_gantry_remake", p, sz, rot, null)
		"drydock_crane":
			_place_ext(raid, "poi_drydock_crane_remake", p, sz, rot, null)
		"drawbridge_gatehouse":
			_place_ext(raid, "bldg_drawbridge_gatehouse_remake", p, sz, rot, null)
		"b6_drydock_yard":
			_place_ext(raid, "b6_drydock_yard", p, sz, rot, null)
		"b6_lighthouse":
			_place_ext(raid, "b6_lighthouse", p, sz, rot, null)
		"locomotive_roundhouse":
			_place_ext(raid, "bldg_locomotive_roundhouse_remake", p, sz, rot, null)
		"train_depot":
			_place_ext(raid, "poi_train_depot_remake", p, sz, rot, null)
		"ore_crusher_tipple":
			_place_ext(raid, "bldg_ore_crusher_tipple_remake", p, sz, rot, null)
		"b6_rail_depot":
			_place_ext(raid, "b6_rail_depot", p, sz, rot, null)
		"hangar_quonset":
			_place_ext(raid, "bldg_hangar_quonset_remake", p, sz, rot, null)
		"radar_array":
			_place_ext(raid, "poi_radar_array_remake", p, sz, rot, null)
		"b6_helipad":
			_place_ext(raid, "b6_helipad", p, sz, rot, null)
		"b6_artillery_nest":
			_place_ext(raid, "b6_artillery_nest", p, sz, rot, null)
		"fort_pillbox_bunker_ruined":
			_place_ext(raid, "fort_pillbox_bunker_ruined", p, sz, rot, null)
		"grain_silo_elevator":
			_place_ext(raid, "bldg_grain_silo_elevator_remake", p, sz, rot, null)
		"grain_silo":
			var gs_id := "poi_grain_silo_remake" if maxf(sz.x, sz.z) >= 14.5 else "bldg_grain_silo"
			_place_ext(raid, gs_id, p, sz, rot, null)
		"bldg_grain_silo":
			_place_ext(raid, "bldg_grain_silo", p, sz, rot, null)
		"fuel_depot":
			_place_ext(raid, "poi_fuel_depot_remake", p, sz, rot, null)
		"b6_gas_station":
			_place_ext(raid, "b6_gas_station", p, sz, rot, null)
		"water_tower":
			_place_ext(raid, "poi_water_tower_remake", p, sz, rot, null)
		_:
			return false
	return true


static func _pick_facade(raid, p_brick: float, p_stone: float, brick_cols: Array = BRICK_COLS, stone_cols: Array = STONE_COLS, conc_cols: Array = CONC_COLS) -> Material:
	var r: float = raid.rng.randf()
	if r < p_brick:
		return A.brick(brick_cols[raid.rng.randi() % brick_cols.size()])
	if r < p_brick + p_stone:
		return A.limestone(stone_cols[raid.rng.randi() % stone_cols.size()])
	return A.concrete(conc_cols[raid.rng.randi() % conc_cols.size()], false)


static func _safe_prefab_sz(prefab_id: String, sz: Vector3) -> Vector3:
	var safe_sz := PrefabLib.clamp_building_height(prefab_id, sz)
	if not prefab_id.begins_with("bldg_") and prefab_id != "poi_generic_building":
		var bsz := PrefabLib.base_size(prefab_id)
		if bsz.x > 0.1 and bsz.y > 0.1 and bsz.z > 0.1:
			var h_ref := clampf((safe_sz.x / bsz.x + safe_sz.z / bsz.z) * 0.5, 0.58, 1.45)
			var min_sy := maxf(0.72, h_ref * 0.80)
			var max_sy := minf(1.28, h_ref * 1.22)
			safe_sz = Vector3(safe_sz.x, clampf(safe_sz.y, bsz.y * min_sy, bsz.y * max_sy), safe_sz.z)
	return safe_sz


static func _place_ext(raid, prefab_id: String, p: Vector3, sz: Vector3, rot: float, tint_mat: Material = null, with_stencil := false, stencil_text := "") -> void:
	var safe_sz := _safe_prefab_sz(prefab_id, sz)
	var sb: StaticBody3D = raid._bldg_body(safe_sz, p + Vector3(0, safe_sz.y * 0.5, 0))
	sb.rotation.y = -rot
	PrefabLib.place_on_body(raid, sb, prefab_id, safe_sz, true, tint_mat, -999.0, with_stencil, stencil_text)


static func _add_backdrop_win_bands(
		win_dark: Array,
		pier_bucket: Array,
		bs: Basis,
		p0: Vector3,
		w: float,
		d: float,
		y_lo: float,
		y_hi: float,
		floor_h: float,
		both_axes := false) -> void:
	var span := y_hi - y_lo
	if span < 0.85:
		return
	var floors := maxi(1, int(floor(span / maxf(floor_h, 2.0))))
	var step := span / float(floors)
	var bh := clampf(step * 0.42, 0.68, 1.12)
	var wx := maxf(1.2, w - maxf(1.2, w * 0.14))
	var wz := maxf(1.2, d - maxf(1.2, d * 0.14))
	for fi in floors:
		var fy := y_lo + (float(fi) + 0.5) * step
		win_dark.append(Transform3D(bs.scaled_local(Vector3(wx, bh, d + 0.14)), p0 + Vector3(0.0, fy, 0.0)))
		if both_axes and d > 4.2:
			win_dark.append(Transform3D(bs.scaled_local(Vector3(w + 0.14, bh, wz)), p0 + Vector3(0.0, fy, 0.0)))
	# 中段竖向砖石壁柱打断通长窗带，形成真实建筑立面开间，杜绝整墙黑玻璃块
	if w > 6.8:
		var pier_h := span + 0.25
		var pier_y := (y_lo + y_hi) * 0.5
		var n_piers := 2 if w > 12.5 else 1
		for pi in n_piers:
			var px := 0.0 if n_piers == 1 else (float(pi) - 0.5) * w * 0.34
			pier_bucket.append(Transform3D(bs.scaled_local(Vector3(0.62, pier_h, d + 0.20)), p0 + bs * Vector3(px, pier_y, 0.0)))


static func _add_backdrop_silo(
		tank_cyls: Array,
		trim_dark: Array,
		bs: Basis,
		base_pos: Vector3,
		diam: float,
		height: float) -> void:
	tank_cyls.append(Transform3D(Basis.IDENTITY.scaled(Vector3(diam, height, diam)), base_pos + Vector3(0.0, height * 0.5, 0.0)))
	# 顶部检修压环、中央透气阀箱与底部钢筋混凝土基座，告别裸灰圆柱
	trim_dark.append(Transform3D(bs.scaled_local(Vector3(diam * 1.12, 0.42, diam * 1.12)), base_pos + Vector3(0.0, 0.21, 0.0)))
	trim_dark.append(Transform3D(bs.scaled_local(Vector3(diam * 1.08, 0.24, diam * 1.08)), base_pos + Vector3(0.0, height - 0.08, 0.0)))
	trim_dark.append(Transform3D(bs.scaled_local(Vector3(diam * 0.36, 0.58, diam * 0.36)), base_pos + Vector3(0.0, height + 0.28, 0.0)))
	if height >= 5.5:
		trim_dark.append(Transform3D(bs.scaled_local(Vector3(diam * 1.06, 0.16, diam * 1.06)), base_pos + Vector3(0.0, height * 0.52, 0.0)))


## 远景外围城区建筑 MultiMesh 形态映射（使战区边界内外的 23 种建筑轮廓自然贯通）
static func add_backdrop(kind: String, bs: Basis, p0: Vector3, sx: float, sz: float, h: float, brng: RandomNumberGenerator,
		hull_con0: Array, hull_con1: Array, hull_brick: Array, hull_wh: Array, hull_mil: Array,
		trim_dark: Array, roof_dark: Array, win_dark: Array, gable_slate: Array, gable_rust: Array,
		barrel_wh: Array, saw_shed: Array, tank_cyls: Array) -> bool:
	match kind:
		"highrise_office":
			var pod_h := minf(7.2, h * 0.22)
			var tw_h := h - pod_h
			hull_con1.append(Transform3D(bs.scaled_local(Vector3(sx, pod_h, sz)), p0 + Vector3(0.0, pod_h * 0.5, 0.0)))
			hull_con0.append(Transform3D(bs.scaled_local(Vector3(sx * 0.82, tw_h, sz * 0.90)), p0 + bs * Vector3(-sx * 0.08, pod_h + tw_h * 0.5, 0.0)))
			roof_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.78, 0.24, sz * 0.86)), p0 + bs * Vector3(-sx * 0.08, h + 0.12, 0.0)))
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.26, 2.6, sz * 0.30)), p0 + bs * Vector3(-sx * 0.18, h + 1.3, 0.0)))
			_add_backdrop_win_bands(win_dark, hull_con1, bs, p0 + bs * Vector3(-sx * 0.08, 0.0, 0.0), sx * 0.82, sz * 0.90, pod_h + 0.8, h - 0.8, 3.15, true)
		"brutalist_slab":
			hull_con1.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
			hull_brick.append(Transform3D(bs.scaled_local(Vector3(sx * 0.18, h + 2.2, sz * 1.04)), p0 + Vector3(0.0, (h + 2.2) * 0.5, 0.0)))
			roof_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.94, 0.22, sz * 0.92)), p0 + Vector3(0.0, h + 0.11, 0.0)))
			_add_backdrop_win_bands(win_dark, hull_con0, bs, p0, sx, sz, 3.2, h - 0.6, 3.05, true)
		"civic_block":
			var bh := h * 0.90
			hull_con0.append(Transform3D(bs.scaled_local(Vector3(sx, bh, sz)), p0 + Vector3(0.0, bh * 0.5, 0.0)))
			hull_con1.append(Transform3D(bs.scaled_local(Vector3(sx * 0.58, h * 0.14, sz * 0.48)), p0 + Vector3(0.0, h * 0.95, 0.0)))
			_add_backdrop_win_bands(win_dark, hull_con1, bs, p0, sx, sz, 1.45, bh - 0.55, 3.60, true)
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx + 0.26, 0.26, sz + 0.26)), p0 + Vector3(0.0, bh + 0.04, 0.0)))
			roof_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.92, 0.25, sz * 0.92)), p0 + Vector3(0.0, h * 0.91, 0.0)))
		"midrise_office":
			var bh := h * 0.92
			var target_hull := hull_brick if brng.randf() < 0.45 else hull_con0
			target_hull.append(Transform3D(bs.scaled_local(Vector3(sx, bh, sz)), p0 + Vector3(0.0, bh * 0.5, 0.0)))
			_add_backdrop_win_bands(win_dark, hull_con1, bs, p0, sx, sz, 1.40, bh - 0.55, 3.55, true)
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx + 0.24, 0.26, sz + 0.24)), p0 + Vector3(0.0, bh + 0.04, 0.0)))
			roof_dark.append(Transform3D(bs.scaled_local(Vector3(maxf(0.8, sx - 0.36), 0.16, maxf(0.8, sz - 0.36))), p0 + Vector3(0.0, bh + 0.16, 0.0)))
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.22, 1.9, sz * 0.24)), p0 + bs * Vector3(-sx * 0.24, h * 0.96, -sz * 0.12)))
			_add_backdrop_silo(tank_cyls, trim_dark, bs, p0 + bs * Vector3(sx * 0.24, bh, -sz * 0.12), 1.15, 2.4)
		"rowblock":
			hull_brick.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
			_add_backdrop_win_bands(win_dark, hull_brick, bs, p0, sx, sz, 1.35, h - 0.55, 3.50, false)
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx + 0.24, 0.26, sz + 0.24)), p0 + Vector3(0.0, h + 0.05, 0.0)))
			roof_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.94, 0.22, sz * 0.92)), p0 + Vector3(0.0, h + 0.14, 0.0)))
		"terrace", "duplex":
			hull_brick.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
			_add_backdrop_win_bands(win_dark, hull_brick, bs, p0, sx, sz, 1.25, h - 0.45, 3.45, false)
			var rh := minf(sx, sz) * 0.30
			var r_bs := bs * (Basis(Vector3.UP, PI * 0.5) if kind == "terrace" else Basis.IDENTITY)
			var r_sc := Vector3(sz + 0.36, rh, sx + 0.24) if kind == "terrace" else Vector3(sx + 0.36, rh, sz + 0.32)
			(gable_slate if brng.randf() < 0.55 else gable_rust).append(Transform3D(r_bs.scaled_local(r_sc), p0 + Vector3(0.0, h, 0.0)))
		"stepped_tower":
			var podium_h := h * 0.38
			var tower_h := h * 0.62
			hull_con1.append(Transform3D(bs.scaled_local(Vector3(sx, podium_h, sz)), p0 + Vector3(0.0, podium_h * 0.5, 0.0)))
			hull_con0.append(Transform3D(bs.scaled_local(Vector3(sx * 0.78, tower_h, sz * 0.78)), p0 + Vector3(0.0, podium_h + tower_h * 0.5, 0.0)))
			_add_backdrop_win_bands(win_dark, hull_con1, bs, p0, sx * 0.78, sz * 0.78, podium_h + 0.75, h - 0.55, 3.55, true)
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx + 0.22, 0.24, sz + 0.22)), p0 + Vector3(0.0, podium_h + 0.04, 0.0)))
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.78 + 0.22, 0.26, sz * 0.78 + 0.22)), p0 + Vector3(0.0, h + 0.04, 0.0)))
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.36, 1.5, sz * 0.36)), p0 + Vector3(0.0, h + 0.75, 0.0)))
		"courtyard_blk":
			var wd := clampf(minf(sx, sz) * 0.30, 2.0, 3.2)
			for sd_z in [-1.0, 1.0]:
				hull_brick.append(Transform3D(bs.scaled_local(Vector3(sx, h, wd)), p0 + bs * Vector3(0.0, h * 0.5, sd_z * (sz * 0.5 - wd * 0.5))))
			for sd_x in [-1.0, 1.0]:
				hull_brick.append(Transform3D(bs.scaled_local(Vector3(wd, h, maxf(1.0, sz - wd * 2.02))), p0 + bs * Vector3(sd_x * (sx * 0.5 - wd * 0.5), h * 0.5, 0.0)))
		"foundry":
			hull_brick.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
			var s_bs := bs * Basis(Vector3.UP, PI * 0.5)
			for s_i in 2:
				var oz := (float(s_i) - 0.5) * sz * 0.48
				saw_shed.append(Transform3D(s_bs.scaled_local(Vector3(sz * 0.50, 1.05, sx + 0.20)), p0 + bs * Vector3(0.0, h, oz)))
		"chem_plant":
			hull_wh.append(Transform3D(bs.scaled_local(Vector3(sx * 0.56, h * 0.84, sz * 0.86)), p0 + bs * Vector3(-sx * 0.20, h * 0.42, 0.0)))
			var ch_h0 := h + 2.4
			var ch_h1 := h + 1.2
			_add_backdrop_silo(tank_cyls, trim_dark, bs, p0 + bs * Vector3(sx * 0.24, 0.0, -sz * 0.18), 1.5, ch_h0)
			_add_backdrop_silo(tank_cyls, trim_dark, bs, p0 + bs * Vector3(sx * 0.24, 0.0, sz * 0.20), 1.3, ch_h1)
			# 顶部架空管廊连接主厂房与双塔罐
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(0.36, 0.32, sz * 0.42)), p0 + bs * Vector3(sx * 0.24, minf(ch_h0, ch_h1) - 0.55, sz * 0.01)))
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.46, 0.34, 0.38)), p0 + bs * Vector3(0.02, h * 0.72, -sz * 0.16)))
		"cold_store", "loco_shed":
			hull_wh.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.46, 1.0, sz * 0.72)), p0 + Vector3(0.0, h + 0.5, 0.0)))
		"command_bunker", "substation":
			hull_mil.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx + 0.32, 0.48, sz + 0.32)), p0 + Vector3(0.0, h + 0.20, 0.0)))
		"silo_barn":
			hull_brick.append(Transform3D(bs.scaled_local(Vector3(sx * 0.64, h * 0.85, sz * 0.88)), p0 + bs * Vector3(-sx * 0.18, h * 0.42, 0.0)))
			var g_bs := bs
			gable_rust.append(Transform3D(g_bs.scaled_local(Vector3(sx * 0.66, 1.8, sz * 0.90)), p0 + bs * Vector3(-sx * 0.18, h * 0.85, 0.0)))
			var sb_h := h + 2.2
			_add_backdrop_silo(tank_cyls, trim_dark, bs, p0 + bs * Vector3(sx * 0.28, 0.0, -sz * 0.20), 2.6, sb_h)
			_add_backdrop_silo(tank_cyls, trim_dark, bs, p0 + bs * Vector3(sx * 0.28, 0.0, sz * 0.20), 2.6, sb_h)
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(0.48, 0.44, sz * 0.46)), p0 + bs * Vector3(sx * 0.28, sb_h + 0.18, 0.0)))
		"city_bakery", "post_office", "police_precinct", "ferry_terminal":
			var cv_h := h * 0.90
			var cv_hull := hull_brick if kind in ["city_bakery", "post_office"] else hull_con0
			cv_hull.append(Transform3D(bs.scaled_local(Vector3(sx, cv_h, sz)), p0 + Vector3(0.0, cv_h * 0.5, 0.0)))
			_add_backdrop_win_bands(win_dark, hull_con1, bs, p0, sx, sz, 1.40, cv_h - 0.50, 3.55, true)
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx + 0.26, 0.28, sz + 0.26)), p0 + Vector3(0.0, cv_h + 0.05, 0.0)))
			roof_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.92, 0.22, sz * 0.92)), p0 + Vector3(0.0, cv_h + 0.16, 0.0)))
			if kind in ["police_precinct", "ferry_terminal"]:
				hull_con1.append(Transform3D(bs.scaled_local(Vector3(sx * 0.34, h * 0.20, sz * 0.36)), p0 + bs * Vector3(-sx * 0.22, cv_h + h * 0.10, -sz * 0.14)))
		"fire_station", "b6_fire_station", "drawbridge_gatehouse":
			var fs_h := h * 0.72
			var fs_hull := hull_brick if kind != "drawbridge_gatehouse" else hull_con1
			fs_hull.append(Transform3D(bs.scaled_local(Vector3(sx, fs_h, sz)), p0 + Vector3(0.0, fs_h * 0.5, 0.0)))
			_add_backdrop_win_bands(win_dark, hull_con1, bs, p0, sx, sz, 1.45, fs_h - 0.45, 3.50, false)
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx + 0.24, 0.26, sz + 0.24)), p0 + Vector3(0.0, fs_h + 0.04, 0.0)))
			var tw_w := clampf(sx * 0.28, 2.4, 4.6)
			var tw_d := clampf(sz * 0.32, 2.4, 4.4)
			var tw_h := h * 0.42
			fs_hull.append(Transform3D(bs.scaled_local(Vector3(tw_w, tw_h, tw_d)), p0 + bs * Vector3(sx * 0.26, fs_h + tw_h * 0.5, -sz * 0.16)))
			roof_dark.append(Transform3D(bs.scaled_local(Vector3(tw_w + 0.24, 0.26, tw_d + 0.24)), p0 + bs * Vector3(sx * 0.26, fs_h + tw_h + 0.08, -sz * 0.16)))
		"cooling_tower":
			var ct_diam := clampf(minf(sx, sz) * 0.62, 5.2, 9.2)
			_add_backdrop_silo(tank_cyls, trim_dark, bs, p0 + bs * Vector3(-sx * 0.12, 0.0, 0.0), ct_diam, h)
			hull_con1.append(Transform3D(bs.scaled_local(Vector3(sx * 0.30, h * 0.34, sz * 0.56)), p0 + bs * Vector3(sx * 0.32, h * 0.17, 0.0)))
		"fuel_tank_farm", "fuel_depot", "b6_gas_station":
			var ft_h := minf(h * 0.55, 4.8)
			hull_wh.append(Transform3D(bs.scaled_local(Vector3(sx * 0.42, ft_h, sz * 0.66)), p0 + bs * Vector3(-sx * 0.24, ft_h * 0.5, 0.0)))
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.92, 0.36, sz * 0.52)), p0 + bs * Vector3(0.0, ft_h + 0.35, sz * 0.16)))
			var td_diam := clampf(minf(sx, sz) * 0.28, 2.0, 4.2)
			var td_h := clampf(h * 0.78, 3.6, 8.8)
			_add_backdrop_silo(tank_cyls, trim_dark, bs, p0 + bs * Vector3(sx * 0.24, 0.0, -sz * 0.20), td_diam, td_h)
			_add_backdrop_silo(tank_cyls, trim_dark, bs, p0 + bs * Vector3(sx * 0.24, 0.0, sz * 0.18), td_diam * 0.92, td_h * 0.88)
		"salvage_foundry", "factory_smelter", "b6_foundry_kiln", "ore_crusher_tipple":
			var sf_h := h * 0.66
			hull_brick.append(Transform3D(bs.scaled_local(Vector3(sx * 0.78, sf_h, sz * 0.88)), p0 + bs * Vector3(-sx * 0.08, sf_h * 0.5, 0.0)))
			var sf_bs := bs * Basis(Vector3.UP, PI * 0.5)
			for si in 2:
				var sf_oz := (float(si) - 0.5) * sz * 0.42
				saw_shed.append(Transform3D(sf_bs.scaled_local(Vector3(sz * 0.44, 1.35, sx * 0.80)), p0 + bs * Vector3(-sx * 0.08, sf_h, sf_oz)))
			var st_diam := clampf(minf(sx, sz) * 0.18, 1.4, 2.8)
			_add_backdrop_silo(tank_cyls, trim_dark, bs, p0 + bs * Vector3(sx * 0.34, 0.0, -sz * 0.16), st_diam, h)
		"water_tower_pump", "bldg_water_tower", "water_tower", "b6_lighthouse":
			var wt_diam := clampf(minf(sx, sz) * 0.36, 2.4, 5.2)
			var wt_base_h := clampf(h * 0.28, 2.2, 4.6)
			hull_con1.append(Transform3D(bs.scaled_local(Vector3(sx * 0.54, wt_base_h, sz * 0.54)), p0 + Vector3(0.0, wt_base_h * 0.5, 0.0)))
			_add_backdrop_silo(tank_cyls, trim_dark, bs, p0 + Vector3(0.0, 0.0, 0.0), wt_diam, h)
		"port_warehouse", "cold_storage", "train_depot", "b6_rail_depot", "b6_drydock_yard":
			var pw_h := h * 0.78
			var pw_hull := hull_wh if kind != "train_depot" else hull_brick
			pw_hull.append(Transform3D(bs.scaled_local(Vector3(sx, pw_h, sz)), p0 + Vector3(0.0, pw_h * 0.5, 0.0)))
			var pw_rh := clampf(minf(sx, sz) * 0.18, 1.0, 2.4)
			gable_rust.append(Transform3D(bs.scaled_local(Vector3(sx + 0.24, pw_rh, sz + 0.24)), p0 + Vector3(0.0, pw_h, 0.0)))
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.62, 0.62, sz * 0.24)), p0 + Vector3(0.0, pw_h + pw_rh * 0.75, 0.0)))
		"dockside_gantry", "drydock_crane":
			var gp_w := clampf(sx * 0.16, 1.4, 2.8)
			var gp_h := h * 0.76
			for gx_s: float in [-1.0, 1.0]:
				hull_con1.append(Transform3D(bs.scaled_local(Vector3(gp_w, gp_h, sz * 0.74)), p0 + bs * Vector3(gx_s * (sx * 0.34), gp_h * 0.5, 0.0)))
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.96, 1.45, sz * 0.26)), p0 + Vector3(0.0, gp_h + 0.65, 0.0)))
			hull_wh.append(Transform3D(bs.scaled_local(Vector3(sx * 0.28, h * 0.22, sz * 0.34)), p0 + bs * Vector3(sx * 0.10, gp_h + 1.35 + h * 0.11, 0.0)))
		"locomotive_roundhouse", "hangar_quonset":
			var hq_h := h * 0.58
			var hq_hull := hull_mil if kind == "hangar_quonset" else hull_brick
			hq_hull.append(Transform3D(bs.scaled_local(Vector3(sx, hq_h, sz)), p0 + Vector3(0.0, hq_h * 0.5, 0.0)))
			var hq_arch := clampf(sz * 0.22, 1.4, 3.2)
			var hq_bs := bs * Basis(Vector3.FORWARD, PI * 0.5)
			barrel_wh.append(Transform3D(hq_bs.scaled_local(Vector3(hq_arch, sx + 0.26, sz * 0.50)), p0 + Vector3(0.0, hq_h, 0.0)))
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.58, 0.45, sz * 0.22)), p0 + Vector3(0.0, hq_h + hq_arch + 0.14, 0.0)))
		"radar_array":
			var ra_h := h * 0.36
			hull_mil.append(Transform3D(bs.scaled_local(Vector3(sx * 0.78, ra_h, sz * 0.78)), p0 + Vector3(0.0, ra_h * 0.5, 0.0)))
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.22, h * 0.64, sz * 0.22)), p0 + Vector3(0.0, ra_h + h * 0.32, 0.0)))
			_add_backdrop_silo(tank_cyls, trim_dark, bs, p0 + Vector3(0.0, ra_h + h * 0.42, 0.0), clampf(minf(sx, sz) * 0.42, 2.8, 5.4), clampf(h * 0.20, 1.4, 2.8))
		"b6_helipad", "b6_artillery_nest", "fort_pillbox_bunker_ruined":
			var mil_h := h * 0.78
			hull_mil.append(Transform3D(bs.scaled_local(Vector3(sx * 0.90, mil_h, sz * 0.90)), p0 + Vector3(0.0, mil_h * 0.5, 0.0)))
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.96, 0.42, sz * 0.96)), p0 + Vector3(0.0, 0.21, 0.0)))
			if kind == "b6_helipad":
				hull_con1.append(Transform3D(bs.scaled_local(Vector3(sx * 0.28, h * 0.42, sz * 0.32)), p0 + bs * Vector3(-sx * 0.28, mil_h + h * 0.21, -sz * 0.24)))
			else:
				trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.44, 0.75, sz * 0.44)), p0 + Vector3(0.0, mil_h + 0.36, 0.0)))
		"grain_silo_elevator", "grain_silo", "bldg_grain_silo":
			var gs_h := h * 0.86
			hull_con0.append(Transform3D(bs.scaled_local(Vector3(sx * 0.38, h, sz * 0.56)), p0 + bs * Vector3(-sx * 0.24, h * 0.5, 0.0)))
			var gs_diam := clampf(minf(sx, sz) * 0.32, 2.2, 4.4)
			_add_backdrop_silo(tank_cyls, trim_dark, bs, p0 + bs * Vector3(sx * 0.22, 0.0, -sz * 0.20), gs_diam, gs_h)
			_add_backdrop_silo(tank_cyls, trim_dark, bs, p0 + bs * Vector3(sx * 0.22, 0.0, sz * 0.20), gs_diam, gs_h)
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.56, 0.52, sz * 0.46)), p0 + bs * Vector3(0.0, gs_h + 0.24, 0.0)))
		_:
			return false
	return true
