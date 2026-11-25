extends RefCounted
## 113 项精修建筑、遗迹 POI、首领地标、重型载具残骸、野战工事与微地貌预制件缓存合批库
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
	"bldg_civic_block": {"path": "res://scripts/buildings/bldg_civic_block.gd", "base": Vector3(24.0, 14.5, 16.0)},
	"bldg_midrise_office": {"path": "res://scripts/buildings/bldg_midrise_office.gd", "base": Vector3(22.0, 18.5, 14.0)},
	"bldg_highrise_office": {"path": "res://scripts/buildings/bldg_highrise_office.gd", "base": Vector3(23.0, 33.5, 14.8)},
	"bldg_brutalist_slab": {"path": "res://scripts/buildings/bldg_brutalist_slab.gd", "base": Vector3(22.0, 25.5, 12.6)},
	"bldg_rowblock": {"path": "res://scripts/buildings/bldg_rowblock.gd", "base": Vector3(24.0, 10.5, 11.5)},
	"bldg_substation": {"path": "res://scripts/buildings/bldg_substation_remake.gd", "base": Vector3(15.2, 8.4, 10.6)},
	"bldg_foundry": {"path": "res://scripts/buildings/bldg_foundry.gd", "base": Vector3(15.4, 7.2, 10.6)},
	"bldg_chem_plant": {"path": "res://scripts/buildings/bldg_chem_plant_remake.gd", "base": Vector3(16.0, 11.2, 11.0)},
	"bldg_loco_shed": {"path": "res://scripts/buildings/bldg_loco_shed.gd", "base": Vector3(15.6, 6.8, 10.4)},
	"bldg_command_bunker": {"path": "res://scripts/buildings/bldg_command_bunker_remake.gd", "base": Vector3(14.6, 8.8, 11.0)},
	"veh_civil_sedan": {"path": "res://scripts/buildings/veh_civil_sedan.gd", "base": Vector3(1.82, 1.44, 4.56)},
	"veh_dump_truck": {"path": "res://scripts/buildings/veh_dump_truck.gd", "base": Vector3(2.9, 3.35, 7.2)},
	"veh_apc_wreck": {"path": "res://scripts/buildings/veh_apc_wreck.gd", "base": Vector3(2.82, 2.65, 7.35)},
	"veh_fuel_tanker": {"path": "res://scripts/buildings/veh_fuel_tanker.gd", "base": Vector3(2.65, 3.15, 7.5)},
	"veh_armored_dozer": {"path": "res://scripts/buildings/veh_armored_dozer.gd", "base": Vector3(2.85, 3.2, 6.1)},
	"ter_road_shoulder": {"path": "res://scripts/buildings/ter_road_shoulder.gd", "base": Vector3(12.0, 0.65, 6.4)},
	"fort_pillbox_bunker": {"path": "res://scripts/buildings/fort_pillbox_bunker.gd", "base": Vector3(6.8, 3.2, 6.8)},
	"fort_pillbox_bunker_ruined": {"path": "res://scripts/buildings/fort_pillbox_bunker_ruined.gd", "base": Vector3(7.2, 4.4, 7.2)},
	"fort_watchtower": {"path": "res://scripts/buildings/fort_watchtower.gd", "base": Vector3(5.4, 9.8, 5.4)},
	"ind_oil_tank_chimney": {"path": "res://scripts/buildings/bldg_oil_tank_chimney_remake.gd", "base": Vector3(13.6, 12.6, 10.6)},
	"ter_dragon_teeth_pipe": {"path": "res://scripts/buildings/ter_dragon_teeth_pipe.gd", "base": Vector3(10.4, 2.3, 7.6)},
	"ter_arid_flora_pylon": {"path": "res://scripts/buildings/ter_arid_flora_pylon.gd", "base": Vector3(10.8, 5.4, 8.2)},
	"poi_generic_building": {"path": "res://scripts/buildings/poi_generic_building.gd", "base": Vector3(11.6, 8.6, 9.2)},
	"poi_duplex_coldstore": {"path": "res://scripts/buildings/poi_duplex_coldstore.gd", "base": Vector3(14.0, 6.4, 9.0)},
	"poi_silo_radar": {"path": "res://scripts/buildings/poi_silo_radar.gd", "base": Vector3(14.4, 10.8, 9.6)},
	"poi_gantry_rail": {"path": "res://scripts/buildings/poi_gantry_rail.gd", "base": Vector3(15.8, 12.4, 10.2)},
	"poi_abyss_gate_rig": {"path": "res://scripts/buildings/bldg_abyss_gate_rig_remake.gd", "base": Vector3(16.0, 13.4, 16.0)},
	"veh_mbt_tank_wreck": {"path": "res://scripts/buildings/veh_mbt_tank_wreck.gd", "base": Vector3(3.62, 2.75, 8.65)},
	"veh_rail_wagon": {"path": "res://scripts/buildings/veh_rail_wagon.gd", "base": Vector3(3.04, 4.02, 11.4)},
	"veh_submarine_hull": {"path": "res://scripts/buildings/veh_submarine_hull.gd", "base": Vector3(4.65, 6.85, 14.9)},
	"veh_transport_vtol": {"path": "res://scripts/buildings/veh_transport_vtol.gd", "base": Vector3(12.6, 4.56, 15.8)},
	"supply_airdrop_pod": {"path": "res://scripts/buildings/supply_airdrop_pod.gd", "base": Vector3(4.35, 5.75, 4.35)},
	"distress_beacon": {"path": "res://scripts/buildings/distress_beacon.gd", "base": Vector3(1.62, 4.18, 1.62)},
	"bld_central_terminus": {"path": "res://scripts/models/bld_central_terminus.gd", "base": Vector3(11.6, 7.1, 13.2)},
	"bld_converter_foundry": {"path": "res://scripts/models/bld_converter_foundry.gd", "base": Vector3(10.8, 9.4, 9.2)},
	"lm_radio_mast": {"path": "res://scripts/models/lm_radio_mast.gd", "base": Vector3(8.6, 15.6, 8.6)},
	"lm_observation_tower": {"path": "res://scripts/models/lm_observation_tower.gd", "base": Vector3(6.2, 11.6, 6.2)},
	"lm_wind_turbine": {"path": "res://scripts/models/lm_wind_turbine.gd", "base": Vector3(10.8, 16.6, 6.8)},
	"lm_crystal_survey_rig": {"path": "res://scripts/models/lm_crystal_survey_rig.gd", "base": Vector3(6.4, 4.1, 5.8)},
	"env_extract_beacon_tower": {"path": "res://scripts/models/env_extract_beacon_tower.gd", "base": Vector3(7.2, 9.5, 7.2)},
	"env_world_portal_gate": {"path": "res://scripts/models/env_world_portal_gate.gd", "base": Vector3(9.8, 8.6, 5.2)},
	"env_perimeter_pontoon": {"path": "res://scripts/models/env_perimeter_pontoon.gd", "base": Vector3(10.0, 7.6, 5.2)},
	"hub_mech_docking_bay": {"path": "res://scripts/models/hub_mech_docking_bay.gd", "base": Vector3(9.0, 8.8, 7.2)},
	# Wave4 窄地块建筑 + Batch6 中型废土设施
	"bldg_guard_kiosk": {"path": "res://scripts/buildings/bldg_guard_kiosk.gd", "base": Vector3(4.8, 5.4, 4.6)},
	"bldg_grain_silo": {"path": "res://scripts/buildings/bldg_grain_silo.gd", "base": Vector3(11.8, 9.6, 8.0)},
	"bldg_water_tower": {"path": "res://scripts/buildings/bldg_water_tower.gd", "base": Vector3(11.4, 9.8, 7.8)},
	"b6_artillery_nest": {"path": "res://scripts/map_ext/poi/artillery_nest.gd", "base": Vector3(11.8, 4.8, 8.4)},
	"b6_drydock_yard": {"path": "res://scripts/map_ext/poi/drydock_yard.gd", "base": Vector3(12.0, 7.2, 8.4)},
	"b6_fire_station": {"path": "res://scripts/map_ext/poi/fire_station.gd", "base": Vector3(11.8, 8.8, 8.2)},
	"b6_foundry_kiln": {"path": "res://scripts/map_ext/poi/foundry_kiln.gd", "base": Vector3(12.0, 9.6, 8.2)},
	"b6_gas_station": {"path": "res://scripts/map_ext/poi/gas_station.gd", "base": Vector3(12.0, 5.8, 8.6)},
	"b6_helipad": {"path": "res://scripts/map_ext/poi/helipad.gd", "base": Vector3(11.8, 6.2, 8.6)},
	"b6_lighthouse": {"path": "res://scripts/map_ext/poi/lighthouse.gd", "base": Vector3(11.6, 10.6, 8.2)},
	"b6_rail_depot": {"path": "res://scripts/map_ext/poi/rail_depot.gd", "base": Vector3(12.0, 6.8, 8.2)},
	# Wave5 首领地标残破重制 (4)
	"lm_central_terminus_remake": {"path": "res://scripts/map_ext/landmarks/lm_central_terminus_remake.gd", "base": Vector3(23.0, 13.8, 17.0)},
	"lm_geothermal_vault_remake": {"path": "res://scripts/map_ext/landmarks/lm_geothermal_vault_remake.gd", "base": Vector3(22.0, 15.6, 20.0)},
	"lm_missile_silo_remake": {"path": "res://scripts/map_ext/landmarks/lm_missile_silo_remake.gd", "base": Vector3(19.0, 11.4, 19.0)},
	"lm_submarine_drydock_remake": {"path": "res://scripts/map_ext/landmarks/lm_submarine_drydock_remake.gd", "base": Vector3(24.0, 14.2, 16.0)},
	# Wave6 + Wave7 重工建筑残破重制 (10)
	"bldg_cooling_tower_unit_remake": {"path": "res://scripts/buildings/bldg_cooling_tower_unit_remake.gd", "base": Vector3(17.6, 16.4, 16.0)},
	"bldg_dockside_gantry_remake": {"path": "res://scripts/buildings/bldg_dockside_gantry_remake.gd", "base": Vector3(21.0, 15.2, 13.6)},
	"bldg_grain_silo_elevator_remake": {"path": "res://scripts/buildings/bldg_grain_silo_elevator_remake.gd", "base": Vector3(18.0, 15.6, 12.6)},
	"bldg_hangar_quonset_remake": {"path": "res://scripts/buildings/bldg_hangar_quonset_remake.gd", "base": Vector3(19.6, 9.4, 15.4)},
	"bldg_water_tower_pump_remake": {"path": "res://scripts/buildings/bldg_water_tower_pump_remake.gd", "base": Vector3(14.8, 15.8, 12.4)},
	"bldg_drawbridge_gatehouse_remake": {"path": "res://scripts/buildings/bldg_drawbridge_gatehouse_remake.gd", "base": Vector3(20.6, 13.0, 12.6)},
	"bldg_fuel_tank_farm_remake": {"path": "res://scripts/buildings/bldg_fuel_tank_farm_remake.gd", "base": Vector3(19.4, 11.4, 14.2)},
	"bldg_locomotive_roundhouse_remake": {"path": "res://scripts/buildings/bldg_locomotive_roundhouse_remake.gd", "base": Vector3(20.4, 11.8, 15.6)},
	"bldg_ore_crusher_tipple_remake": {"path": "res://scripts/buildings/bldg_ore_crusher_tipple_remake.gd", "base": Vector3(20.6, 14.4, 12.4)},
	"bldg_salvage_foundry_remake": {"path": "res://scripts/buildings/bldg_salvage_foundry_remake.gd", "base": Vector3(20.0, 14.2, 13.6)},
	# Wave4 + Wave5 + Wave6 + Wave7 遗迹 POI 残破重制 (38)
	"poi_abyss_lighthouse_remake": {"path": "res://scripts/map_ext/poi/abyss_lighthouse_remake.gd", "base": Vector3(14.0, 16.8, 12.0)},
	"poi_airship_mooring_mast_remake": {"path": "res://scripts/map_ext/poi/airship_mooring_mast_remake.gd", "base": Vector3(16.0, 17.2, 14.0)},
	"poi_astronomical_observatory_remake": {"path": "res://scripts/map_ext/poi/astronomical_observatory_remake.gd", "base": Vector3(16.8, 13.8, 13.4)},
	"poi_bathysphere_dock_remake": {"path": "res://scripts/map_ext/poi/bathysphere_dock_remake.gd", "base": Vector3(18.4, 12.4, 13.8)},
	"poi_checkpoint_fortress_remake": {"path": "res://scripts/map_ext/poi/checkpoint_fortress_remake.gd", "base": Vector3(20.0, 9.6, 12.0)},
	"poi_checkpoint_remake": {"path": "res://scripts/map_ext/poi/checkpoint_remake.gd", "base": Vector3(21.6, 8.8, 12.8)},
	"poi_church_remake": {"path": "res://scripts/map_ext/poi/church_remake.gd", "base": Vector3(17.6, 18.4, 20.4)},
	"poi_city_bakery_remake": {"path": "res://scripts/map_ext/poi/city_bakery_remake.gd", "base": Vector3(15.4, 11.8, 12.6)},
	"poi_coastal_artillery_remake": {"path": "res://scripts/map_ext/poi/coastal_artillery_remake.gd", "base": Vector3(18.0, 10.6, 15.0)},
	"poi_cold_storage_remake": {"path": "res://scripts/map_ext/poi/cold_storage_remake.gd", "base": Vector3(20.4, 10.2, 15.6)},
	"poi_comms_dish_station_remake": {"path": "res://scripts/map_ext/poi/comms_dish_station_remake.gd", "base": Vector3(17.6, 15.2, 13.8)},
	"poi_drydock_crane_remake": {"path": "res://scripts/map_ext/poi/drydock_crane_remake.gd", "base": Vector3(20.2, 16.4, 15.6)},
	"poi_egret_bridge_remake": {"path": "res://scripts/map_ext/poi/egret_bridge_remake.gd", "base": Vector3(20.0, 9.8, 16.0)},
	"poi_factory_smelter_remake": {"path": "res://scripts/map_ext/poi/factory_smelter_remake.gd", "base": Vector3(21.6, 16.8, 16.4)},
	"poi_ferry_terminal_remake": {"path": "res://scripts/map_ext/poi/ferry_terminal_remake.gd", "base": Vector3(21.6, 11.4, 16.8)},
	"poi_fire_station_remake": {"path": "res://scripts/map_ext/poi/fire_station_remake.gd", "base": Vector3(20.0, 13.8, 14.6)},
	"poi_fuel_depot_remake": {"path": "res://scripts/map_ext/poi/fuel_depot_remake.gd", "base": Vector3(21.4, 8.2, 15.6)},
	"poi_geothermal_wellhead_remake": {"path": "res://scripts/map_ext/poi/geothermal_wellhead_remake.gd", "base": Vector3(17.6, 15.6, 13.0)},
	"poi_grain_silo_remake": {"path": "res://scripts/map_ext/poi/grain_silo_remake.gd", "base": Vector3(19.8, 17.6, 14.8)},
	"poi_hospital_remake": {"path": "res://scripts/map_ext/poi/hospital_remake.gd", "base": Vector3(20.4, 12.8, 16.2)},
	"poi_hydro_lab_remake": {"path": "res://scripts/map_ext/poi/hydro_lab_remake.gd", "base": Vector3(16.2, 12.2, 21.0)},
	"poi_hydroponic_biodome_remake": {"path": "res://scripts/map_ext/poi/hydroponic_biodome_remake.gd", "base": Vector3(18.6, 11.4, 14.4)},
	"poi_lighthouse_remake": {"path": "res://scripts/map_ext/poi/lighthouse_remake.gd", "base": Vector3(16.8, 21.8, 14.2)},
	"poi_metro_station_remake": {"path": "res://scripts/map_ext/poi/metro_station_remake.gd", "base": Vector3(20.8, 7.6, 12.8)},
	"poi_mining_terminal_remake": {"path": "res://scripts/map_ext/poi/mining_terminal_remake.gd", "base": Vector3(21.6, 14.2, 15.6)},
	"poi_observatory_remake": {"path": "res://scripts/map_ext/poi/observatory_remake.gd", "base": Vector3(20.6, 14.4, 14.4)},
	"poi_parking_garage_remake": {"path": "res://scripts/map_ext/poi/parking_garage_remake.gd", "base": Vector3(20.6, 11.4, 15.6)},
	"poi_police_precinct_remake": {"path": "res://scripts/map_ext/poi/police_precinct_remake.gd", "base": Vector3(20.6, 11.4, 15.2)},
	"poi_port_warehouse_remake": {"path": "res://scripts/map_ext/poi/port_warehouse_remake.gd", "base": Vector3(22.4, 10.4, 18.2)},
	"poi_post_office_remake": {"path": "res://scripts/map_ext/poi/post_office_remake.gd", "base": Vector3(18.6, 11.2, 15.0)},
	"poi_power_station_remake": {"path": "res://scripts/map_ext/poi/power_station_remake.gd", "base": Vector3(22.8, 14.4, 17.8)},
	"poi_radar_array_remake": {"path": "res://scripts/map_ext/poi/radar_array_remake.gd", "base": Vector3(18.4, 15.8, 15.4)},
	"poi_radar_array_tower_remake": {"path": "res://scripts/map_ext/poi/radar_array_tower_remake.gd", "base": Vector3(14.6, 15.4, 12.4)},
	"poi_relay_tower_remake": {"path": "res://scripts/map_ext/poi/relay_tower_remake.gd", "base": Vector3(18.6, 22.8, 15.8)},
	"poi_school_remake": {"path": "res://scripts/map_ext/poi/school_remake.gd", "base": Vector3(22.0, 10.6, 17.6)},
	"poi_train_depot_remake": {"path": "res://scripts/map_ext/poi/train_depot_remake.gd", "base": Vector3(21.4, 10.6, 17.6)},
	"poi_water_tower_remake": {"path": "res://scripts/map_ext/poi/water_tower_remake.gd", "base": Vector3(15.6, 20.6, 15.6)},
	"poi_well_core_remake": {"path": "res://scripts/map_ext/poi/well_core_remake.gd", "base": Vector3(18.6, 22.0, 18.6)},
}

static var _cache: Dictionary = {}
static var _std_dedup: Dictionary = {}
static var _surf_cache: Dictionary = {}
static var _pier_cache: Dictionary = {}
static var _hlod_cache: Dictionary = {}


static func base_size(id: String) -> Vector3:
	var sp: Dictionary = SPECS.get(id, {})
	return sp.get("base", Vector3.ONE) as Vector3


static func clear_cache() -> void:
	_cache.clear()
	_std_dedup.clear()
	_surf_cache.clear()
	_pier_cache.clear()
	_hlod_cache.clear()


static func _pier_variant(tint_mat: Material) -> Material:
	if tint_mat == null:
		return null
	var key := tint_mat.get_rid().get_id()
	if _pier_cache.has(key):
		return _pier_cache[key]
	var out: Material = tint_mat
	if tint_mat is ShaderMaterial:
		var sm: ShaderMaterial = (tint_mat as ShaderMaterial).duplicate()
		var col_v: Variant = sm.get_shader_parameter("base_color")
		if col_v is Color:
			sm.set_shader_parameter("base_color", (col_v as Color).darkened(0.11))
		out = sm
	_pier_cache[key] = out
	return out


static func _mat_is_matte_masonry(mat: Material) -> bool:
	if not (mat is ShaderMaterial):
		return false
	var sm: ShaderMaterial = mat as ShaderMaterial
	var mb_v: Variant = sm.get_shader_parameter("metal_base")
	var rb_v: Variant = sm.get_shader_parameter("rough_base")
	var mb: float = float(mb_v) if mb_v != null else 0.15
	var rb: float = float(rb_v) if rb_v != null else 0.62
	return mb <= 0.12 and rb >= 0.74


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
	var pier_votes: Dictionary = {}
	var stencils: Array = []

	_collect_recursive(id, root, Transform3D.IDENTITY, "", raw_parts, primary_votes, primary_mats, pier_votes, stencils)
	root.free()

	var primary_rid := 0
	var best_v := -1
	for rid_k: int in primary_votes:
		var v_cnt: int = int(primary_votes[rid_k])
		if v_cnt > best_v:
			best_v = v_cnt
			primary_rid = rid_k

	var pier_rid := 0
	var best_pv := -1
	if not id.begins_with("veh_") and id != "bldg_rowblock":
		for rid_k: int in pier_votes:
			if rid_k == primary_rid:
				continue
			var pv_cnt: int = int(pier_votes[rid_k])
			if pv_cnt > best_pv:
				best_pv = pv_cnt
				pier_rid = rid_k

	var groups: Dictionary = {}
	for rp: Array in raw_parts:
		var p_mesh: Mesh = rp[0]
		var p_si: int = int(rp[1])
		var p_xf: Transform3D = rp[2]
		var res_m: Material = rp[3]
		var shadow_on: bool = bool(rp[4])
		var allow_prim: bool = bool(rp[5])
		var p_path: String = str(rp[6])
		var m_id: int = res_m.get_rid().get_id() if res_m != null else 0
		var is_prim: bool = (primary_rid != 0 and m_id == primary_rid and allow_prim)
		var is_pier := false
		if not is_prim and not id.begins_with("veh_") and not id.begins_with("ter_") and not id.begins_with("fort_") and id != "bldg_rowblock" and allow_prim:
			if not p_path.contains("Roof") and not p_path.contains("_Deck") and not p_path.contains("Canopy") and not p_path.contains("Stair"):
				var is_matte: bool = _mat_is_matte_masonry(res_m)
				if pier_rid != 0 and m_id == pier_rid and is_matte:
					is_pier = true
				elif is_matte and (p_path.contains("StructWall") or p_path.contains("StructPier") or p_path.contains("CornerPilaster")):
					var sm_chk: ShaderMaterial = res_m as ShaderMaterial
					var col_chk: Variant = sm_chk.get_shader_parameter("base_color")
					var v_chk: float = (col_chk as Color).v if (col_chk is Color) else 0.5
					if v_chk >= 0.25:
						is_pier = true
		if is_prim:
			var gk_p := "prim|%d|%d" % [m_id, 1 if shadow_on else 0]
			if not groups.has(gk_p):
				groups[gk_p] = {"mat": res_m, "shadow": shadow_on, "tint": 0, "primary": true, "primary_pier": false, "parts": []}
			(groups[gk_p]["parts"] as Array).append([p_mesh, p_si, p_xf, Color.WHITE])
		elif is_pier:
			var gk_pp := "pier|%d" % [1 if shadow_on else 0]
			if not groups.has(gk_pp):
				groups[gk_pp] = {"mat": res_m, "shadow": shadow_on, "tint": 0, "primary": false, "primary_pier": true, "parts": []}
			(groups[gk_pp]["parts"] as Array).append([p_mesh, p_si, p_xf, Color.WHITE])
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
				groups[gk_s] = {"mat": shared_m, "shadow": shadow_on, "tint": tint_kind, "primary": false, "primary_pier": false, "parts": []}
			(groups[gk_s]["parts"] as Array).append([p_mesh, p_si, p_xf, col_t])

	# 若同一材质的 shadow=false 子集面数很小（<400 三角）且已存在对应 shadow=true 组，则合并回原组避免拆分额外 Draw Call；
	# 大体量微细节/内饰/窗棂/残破件（≥400 三角）保持 shadow=false 独立合批以大幅削减阴影 pass 面数
	for gk: String in groups.keys():
		if not gk.ends_with("|0"):
			continue
		var gk_on := gk.substr(0, gk.length() - 2) + "|1"
		if not groups.has(gk_on):
			continue
		var g_off: Dictionary = groups[gk]
		var est_tris := 0
		for pp: Array in (g_off["parts"] as Array):
			var arr_p: Array = _get_cached_arrays(pp[0] as Mesh, int(pp[1]))
			var ix_p = arr_p[Mesh.ARRAY_INDEX]
			est_tris += int(ix_p.size() / 3) if (ix_p != null and ix_p.size() > 0) else int((arr_p[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3)
		if est_tris < 400:
			(groups[gk_on]["parts"] as Array).append_array(g_off["parts"] as Array)
			groups.erase(gk)

	var surfaces: Array = []
	var vis_aabb := AABB()
	var has_ab := false
	for gk: String in groups:
		var g: Dictionary = groups[gk]
		var am: ArrayMesh = _merge_parts(g["parts"] as Array, int(g["tint"]))
		if am == null or am.get_surface_count() == 0:
			continue
		var tri_cnt := int(am.surface_get_array_index_len(0) / 3) if am.surface_get_array_index_len(0) > 0 else int(am.surface_get_array_len(0) / 3)
		# 仅高层遮挡建筑的主体/大面数表面保留独立 prefab_inst 供整栋虚化零拷贝提取；载具/地貌与小装饰表面交给分块合批合并为单 Draw Call
		if bsz.y >= 4.0 and not id.begins_with("veh_") and not id.begins_with("ter_") and (bool(g["primary"]) or tri_cnt >= 2500):
			am.set_meta("prefab_inst", true)
		am.set_meta("prefab_id", id)
		var ab := am.get_aabb()
		vis_aabb = ab if not has_ab else vis_aabb.merge(ab)
		has_ab = true
		surfaces.append({
			"mesh": am,
			"mat": g["mat"],
			"shadow": bool(g["shadow"]),
			"primary": bool(g["primary"]),
			"primary_pier": bool(g.get("primary_pier", false)),
		})

	var pmat: Material = primary_mats.get(primary_rid, null)
	var entry := {
		"id": id,
		"base_sz": bsz,
		"aabb": vis_aabb if has_ab else AABB(-bsz * 0.5, bsz),
		"surfaces": surfaces,
		"stencils": stencils,
		"primary_mat": pmat,
		"primary_is_masonry": _mat_is_matte_masonry(pmat),
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
	pier_votes: Dictionary,
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
			# 按局部缩放后的 OBB 实际尺寸判定细长构件（防止斜置钢筋/拉索/桁架杆因世界轴对齐 AABB 膨胀逃过 thin_cnt 裁切）
			var lsz: Vector3 = mi.mesh.get_aabb().size
			var obb_sz := Vector3(
				lsz.x * cur_xf.basis.x.length(),
				lsz.y * cur_xf.basis.y.length(),
				lsz.z * cur_xf.basis.z.length()
			)
			var max_dim := maxf(obb_sz.x, maxf(obb_sz.y, obb_sz.z))
			var thin_cnt := (1 if obb_sz.x < 0.14 else 0) + (1 if obb_sz.y < 0.14 else 0) + (1 if obb_sz.z < 0.14 else 0)
			# 细小门窗框/窗棂/栏杆/防盗栅/螺栓/灯具/爬梯/通风百叶、隐藏室内家具、残破碎屑钢筋与贴地底板关闭实时阴影，保住建筑主体阴影并削减 55%+ 无效阴影面数
			var micro_no_shadow: bool = (id == "ter_road_shoulder") or cur_path.contains("GroundedApron") \
				or cur_path.contains("FoundationPad") or cur_path.contains("YardPad") or cur_path.contains("Forecourt") \
				or cur_path.contains("Tier3_DryGrassClump") or cur_path.contains("SecurityBar") \
				or cur_path.contains("ShutterLeaf") or cur_path.contains("Headlight") \
				or cur_path.contains("OpticalLens") or cur_path.contains("Searchlight") \
				or cur_path.contains("SignalHead") or cur_path.contains("ACBracket") \
				or cur_path.contains("WindowMuntin") or cur_path.contains("BalconyRailing") \
				or cur_path.contains("RecessedWindow") or cur_path.contains("DoorHardware") \
				or cur_path.contains("RoofVent") or cur_path.contains("Vent") \
				or cur_path.contains("Ladder") or cur_path.contains("Handrail") \
				or cur_path.contains("Railing") or cur_path.contains("Sign") \
				or cur_path.contains("Trim") or cur_path.contains("Rivet") \
				or cur_path.contains("Bolt") or cur_path.contains("Interior") \
				or cur_path.contains("Bed") or cur_path.contains("Desk") \
				or cur_path.contains("Chair") or cur_path.contains("Shelf") \
				or cur_path.contains("Bench") or cur_path.contains("Lamp") \
				or cur_path.contains("Ruined_") or cur_path.contains("Debris") \
				or cur_path.contains("Rubble") or cur_path.contains("Rebar") \
				or cur_path.contains("Cable") or cur_path.contains("Pipe") \
				or cur_path.contains("Conduit") or max_dim < 0.72 or thin_cnt >= 2
			var mi_shadow_ok: bool = mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for si in mi.mesh.get_surface_count():
				var raw_m: Material = mi.material_override
				if raw_m == null and si < mi.get_surface_override_material_count():
					raw_m = mi.get_surface_override_material(si)
				if raw_m == null:
					raw_m = mi.mesh.surface_get_material(si)
				var res_m: Material = _resolve_material(id, cur_path, raw_m)
				var is_glass_m := (res_m is ShaderMaterial) and (res_m as ShaderMaterial).shader != null and (res_m as ShaderMaterial).shader.resource_path.contains("ind_glass")
				var is_emit_m := (res_m is BaseMaterial3D) and (res_m as BaseMaterial3D).emission_enabled
				var shadow_on: bool = mi_shadow_ok and (not micro_no_shadow) and (not is_glass_m) and (not is_emit_m)
				var m_id: int = res_m.get_rid().get_id() if res_m != null else 0
				var allow_prim: bool = _allow_primary_tint(id, cur_path)
				raw_parts.append([mi.mesh, si, cur_xf, res_m, shadow_on, allow_prim, cur_path])
				if _is_primary_candidate(id, cur_path, res_m):
					var arrays: Array = _get_cached_arrays(mi.mesh, si)
					var v_arr: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					primary_votes[m_id] = int(primary_votes.get(m_id, 0)) + v_arr.size()
					primary_mats[m_id] = res_m
				elif not id.begins_with("veh_") and (cur_path.contains("StructPier") or cur_path.contains("CornerPilaster")) and allow_prim and _mat_is_matte_masonry(res_m):
					var arrays_p: Array = _get_cached_arrays(mi.mesh, si)
					var vp_arr: PackedVector3Array = arrays_p[Mesh.ARRAY_VERTEX]
					pier_votes[m_id] = int(pier_votes.get(m_id, 0)) + vp_arr.size()
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
		_collect_recursive(id, ch, cur_xf, cur_path, raw_parts, primary_votes, primary_mats, pier_votes, stencils)


static func _is_equip_or_trim_path(path: String) -> bool:
	return path.contains("Window") or path.contains("Door") or path.contains("SecurityBar") \
		or path.contains("SunHood") or path.contains("ShutterLeaf") or path.contains("Headlight") \
		or path.contains("OpticalLens") or path.contains("Vent") or path.contains("TurbineVent") \
		or path.contains("NBCFiltrationUnit") or path.contains("TacticalCommsMast") \
		or path.contains("CommandCommsArray") or path.contains("LightningMast") \
		or path.contains("RidgeMonitor") or path.contains("WaterTank") or path.contains("CoolingTower") \
		or path.contains("SolarHeater") or path.contains("Chimney") or path.contains("ACBracket") \
		or path.contains("WallACUnit") or path.contains("Balcony") or path.contains("Airlock") \
		or path.contains("CableStayedCanopy") or path.contains("MonorailHoist") \
		or path.contains("CycloneSeparator") or path.contains("AmmoniaCondenserSkid") \
		or path.contains("CargoPallet") or path.contains("Sandbag") or path.contains("Ladder") \
		or path.contains("Piston") or path.contains("Wheel") or path.contains("Track") \
		or path.contains("RunningGear") or path.contains("Ripper") or path.contains("CavityCore")


static func _allow_primary_tint(id: String, path: String) -> bool:
	if _is_equip_or_trim_path(path):
		return false
	if path.contains("Plinth") or path.contains("Foundation") or path.contains("Apron"):
		return false
	if not id.begins_with("veh_") and path.contains("PortalColumn"):
		return false
	return true


static func _is_primary_candidate(id: String, path: String, mat: Material) -> bool:
	if mat == null or not (mat is ShaderMaterial):
		return false
	var sm: ShaderMaterial = mat as ShaderMaterial
	var mb_v: Variant = sm.get_shader_parameter("metal_base")
	var mb: float = float(mb_v) if mb_v != null else 0.15
	# 排除 K.dark / K.gunmetal / K.frame / chrome / brass 等高金属度结构钢与五金配件，防止反客为主劫持主墙/车体材质
	if mb >= 0.60:
		return false
	var col_v: Variant = sm.get_shader_parameter("base_color")
	if col_v is Color:
		var c: Color = col_v as Color
		if maxf(c.r, maxf(c.g, c.b)) < 0.085 and mb < 0.10:
			return false
	if not _allow_primary_tint(id, path):
		return false
	if path.contains("Roof"):
		return false
	if id.begins_with("veh_"):
		if path.contains("Turret"):
			return false
		return path.contains("Cab") or path.contains("Bed") or path.contains("Hull") \
			or path.contains("Trailer") or path.contains("Hood") or path.contains("Blade")
	if path.contains("StructWall"):
		return true
	return path.contains("Body") or path.contains("Hall") \
		or path.contains("Wing") or path.contains("Store") or path.contains("House")


static func _resolve_material(id: String, path: String, mat: Material) -> Material:
	if mat == null:
		return A.concrete(Color(0.46, 0.44, 0.40), false)
	if mat is StandardMaterial3D:
		var sm_std: StandardMaterial3D = mat as StandardMaterial3D
		var is_lens: bool = path.contains("OpticalLens") or path.contains("Headlight") or path.contains("Searchlight") or path.contains("SignalHead")
		if not is_lens and not id.begins_with("veh_") and sm_std.albedo_color.v < 0.08:
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
	if not s_path.get_file() in ["mech_paint.gdshader", "mech_paint_mobile.gdshader", "mech_paint_web.gdshader"]:
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

	# 道路沥青、深色基座铺装、风沙堆积棱体与弹坑焦土底盘
	if path.contains("CrackedAsphalt") \
			or ((path.contains("FoundationPad") or path.contains("Forecourt") or path.contains("YardPad")) and mb <= 0.10 and rb >= 0.88 and c.v < 0.24):
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

	# 压型波纹钢卷帘门（含金属帘片）
	if path.contains("RollerDoor") or path.contains("MaintenanceBayDoor") or path.contains("LocoBayDoor"):
		if mb >= 0.12 and mb < 0.72:
			return A.corrugated(c, clampf(mb, 0.34, 0.58), 0.34)

	# 压型波纹钢屋面、粮仓筒体与轻钢厂房墙皮（排除门窗、机电设备、天线与高金属结构钢柱/拱肋）
	if not _is_equip_or_trim_path(path) and not path.contains("StructPier") \
			and not path.contains("CornerPilaster") and not path.contains("PortalColumn"):
		if path.contains("PortalWarehouseBody") or path.contains("ArmoredBarrackBody") \
				or path.contains("AmmoniaColdStore") or path.contains("GrainSilo") \
				or path.contains("RoofSlopeDeck") or path.contains("TerracePitchedRoof") \
				or path.contains("ArmoredQuonsetRoof") or path.contains("StructuredVaultRoof"):
			if mb >= 0.12 and mb < 0.62:
				return A.corrugated(c, clampf(mb, 0.34, 0.58), 0.34)

	# 平屋面沥青油毡防水卷材（1K 实拍卷材接缝与粗糙度 PBR，彻底替代原先误判混凝土的屋顶底板）
	var is_flat_roof_deck: bool = (path.contains("Roof") or path.contains("_Deck")) \
		and not path.contains("Slope") and not path.contains("Pitched") \
		and not path.contains("Quonset") and not path.contains("Vault") \
		and not path.contains("RoofEquipment") and not path.contains("RoofHVAC") \
		and not path.contains("RoofWater") and not path.contains("RooftopBillboard")
	if is_flat_roof_deck and mb <= 0.12 and rb >= 0.80:
		if c.v < 0.22:
			return A.tar_roof(Color(maxf(c.r, 0.21), maxf(c.g, 0.215), maxf(c.b, 0.225)))
		if absf(c.r - c.b) < 0.034 and (id == "bldg_civic_block" or id == "bldg_midrise_office" or id == "bldg_rowblock"):
			return A.tar_roof(c)

	# 低金属高粗糙度建筑墙体、柱础、勒脚、暗堡与烟囱 -> 精准分流 1K 实拍陶砖 / 切块石灰岩 / 风化混凝土
	if mb <= 0.10 and rb >= 0.78:
		var is_masonry_path: bool = path.contains("Masonry") or path.contains("Chimney") or path.contains("Terrace") \
			or path.contains("Courtyard") or path.contains("Foundry") or path.contains("Arcade") \
			or path.contains("StructWall") or path.contains("StructPier") or path.contains("CornerPilaster") \
			or path.contains("AtticDormer") or path.contains("DispatchDuplex") or path.contains("CupolaFurnace") \
			or path.contains("Rowblock") or path.contains("Office") or path.contains("Civic")
		if is_masonry_path and (c.r - c.b) > 0.125 and (c.r - c.g) > 0.055:
			return A.brick(c)
		if (c.r - c.b) > 0.042 and c.v >= 0.48:
			return A.limestone(c)
		return A.concrete(c, false)

	# 次要无贴图涂装件参数档位规整（保留每个部件的精确原色写入顶点色，将 12~16 个碎片材质合并至 4~6 个共享表面，大幅削减 Draw Call）
	var use_tex_v: Variant = sm.get_shader_parameter("use_albedo_tex")
	if (use_tex_v == null or float(use_tex_v) < 0.5) and not _is_primary_candidate(id, path, mat):
		var q_mb: float = 0.0 if mb < 0.16 else (0.35 if mb < 0.55 else 0.78)
		var q_rb: float = 0.28 if rb < 0.42 else (0.56 if rb < 0.74 else 0.86)
		var q_mw: float = 0.0 if q_mb < 0.1 else 1.0
		return A.paint(c, q_mb, q_rb, {
			"wear": 0.36, "scratches": 0.0 if q_mw < 0.5 else 0.25,
			"rust": 0.25, "grime": 0.45, "dust": 0.24,
			"metal_wear": q_mw, "panel_scale": 0.0, "detail_scale": 1.0,
		})

	return mat


static func _get_cached_arrays(mesh: Mesh, si: int) -> Array:
	var key := "%d|%d" % [mesh.get_rid().get_id(), si]
	var cached = _surf_cache.get(key)
	if cached != null:
		return cached
	var a: Array = mesh.surface_get_arrays(si)
	if _surf_cache.size() > 2048:
		_surf_cache.clear()
	_surf_cache[key] = a
	return a


static func _merge_parts(parts: Array, tint_kind := 0) -> ArrayMesh:
	var total_v := 0
	var total_i := 0
	var raw_list: Array = []
	for p: Array in parts:
		var mesh: Mesh = p[0]
		var si: int = int(p[1])
		var xf: Transform3D = p[2]
		var tcol: Color = p[3]
		var a: Array = _get_cached_arrays(mesh, si)
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
## 约束建筑高度与水平基底比例，彻底杜绝将矮楼竖向拉成铅笔塔或将高楼压扁成蛋糕盒
static func clamp_building_height(id: String, sz: Vector3) -> Vector3:
	if not id.begins_with("bldg_") and id != "poi_generic_building":
		return sz
	var bsz := base_size(id)
	if bsz.x <= 0.1 or bsz.y <= 0.1 or bsz.z <= 0.1:
		return sz
	var h_ref := clampf((sz.x / bsz.x + sz.z / bsz.z) * 0.5, 0.58, 1.55)
	var min_sy := maxf(0.72, h_ref * 0.78)
	var max_sy := minf(1.22, h_ref * 1.18) if id == "bldg_house" else minf(1.36, h_ref * 1.28)
	return Vector3(sz.x, clampf(sz.y, bsz.y * min_sy, bsz.y * max_sy), sz.z)


static func _resolve_tinted_mat(pf: Dictionary, s_info: Dictionary, tint_mat: Material) -> Material:
	var use_mat: Material = s_info["mat"]
	if tint_mat == null:
		return use_mat
	if bool(s_info["primary"]):
		return tint_mat
	if bool(s_info.get("primary_pier", false)):
		var tm_mb := 0.0
		if tint_mat is ShaderMaterial:
			var mb_v: Variant = (tint_mat as ShaderMaterial).get_shader_parameter("metal_base")
			if mb_v != null:
				tm_mb = float(mb_v)
		if tm_mb < 0.18 or bool(pf.get("primary_is_masonry", false)):
			return _pier_variant(tint_mat)
	return use_mat


static func place_on_body(
	raid,
	sb: Node3D,
	id: String,
	target_sz: Vector3,
	flip_front := true,
	tint_mat: Material = null,
	y_off := -999.0,
	with_stencil := false,
	stencil_text := "",
	fit_height := true
) -> void:
	var pf := get_prefab(id)
	if pf.is_empty():
		return
	var bsz: Vector3 = pf["base_sz"]
	var safe_sz := clamp_building_height(id, target_sz) if fit_height else target_sz
	var scl := Vector3(
		maxf(0.15, safe_sz.x / maxf(0.1, bsz.x)),
		maxf(0.15, safe_sz.y / maxf(0.1, bsz.y)),
		maxf(0.15, safe_sz.z / maxf(0.1, bsz.z))
	)
	var pos := Vector3(0.0, (-target_sz.y * 0.5) if y_off <= -900.0 else y_off, 0.0)
	var rot_deg := Vector3(0.0, 180.0, 0.0) if flip_front else Vector3.ZERO
	var pf_ab: AABB = pf.get("aabb", AABB(-bsz * 0.5, bsz))
	var xf_vis := Transform3D(Basis.from_euler(rot_deg * (PI / 180.0)) * Basis.from_scale(scl), pos)
	sb.set_meta("occ_vis_aabb", xf_vis * pf_ab)
	var surfaces: Array = pf["surfaces"]
	for s_info: Dictionary in surfaces:
		var use_mat: Material = _resolve_tinted_mat(pf, s_info, tint_mat)
		raid._imesh(sb, s_info["mesh"] as Mesh, use_mat, pos, rot_deg, scl, bool(s_info["shadow"]))
	var vista_ref: Variant = raid.get("vista")
	if vista_ref != null and vista_ref.has_method("add_prefab"):
		var world_xf: Transform3D = sb.transform * xf_vis
		var t_col: Color = _mat_color(tint_mat, Color.WHITE) if tint_mat != null else Color.WHITE
		vista_ref.add_prefab(id, world_xf, t_col, sb)
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
	var l_bs := Basis.from_euler(rot_deg * (PI / 180.0)) * Basis.from_scale(scl)
	var l_xf := Transform3D(l_bs, Vector3.ZERO)
	var world_holder: Node3D = holder
	var surfaces: Array = pf["surfaces"]
	if parent == raid.world:
		for s_info: Dictionary in surfaces:
			var use_mat: Material = _resolve_tinted_mat(pf, s_info, tint_mat)
			raid._imesh(world_holder, s_info["mesh"] as Mesh, use_mat, Vector3.ZERO, rot_deg, scl, bool(s_info["shadow"]))
	else:
		# parent 在嵌套子节点下：直接挂合并后的单材质 MeshInstance3D，供 _bake_static 自动按全局变换合批
		for s_info: Dictionary in surfaces:
			var use_mat: Material = _resolve_tinted_mat(pf, s_info, tint_mat)
			var mi := MeshInstance3D.new()
			mi.mesh = s_info["mesh"] as Mesh
			mi.material_override = use_mat
			mi.transform = l_xf
			mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			mi.set_meta("vista_covered", true)
			if use_mat is BaseMaterial3D and ((use_mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or (use_mat as BaseMaterial3D).emission_enabled):
				mi.visibility_range_end = RB.VIS_END
				mi.visibility_range_end_margin = 8.0
			if not bool(s_info["shadow"]):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)
	var vista_ref: Variant = raid.get("vista")
	if vista_ref != null and vista_ref.has_method("add_prefab"):
		var h_xf: Transform3D = holder.global_transform if holder.is_inside_tree() else (parent.transform * holder.transform)
		var world_xf: Transform3D = h_xf * l_xf
		var t_col: Color = _mat_color(tint_mat, Color.WHITE) if tint_mat != null else Color.WHITE
		var own: Node3D = parent if (parent != raid.world and parent is StaticBody3D) else null
		vista_ref.add_prefab(id, world_xf, t_col, own)
	var _unused_st2 := with_stencil
	return holder


static func _mat_color(mat: Material, fallback := Color(0.50, 0.48, 0.45)) -> Color:
	if mat is ShaderMaterial:
		var cv: Variant = (mat as ShaderMaterial).get_shader_parameter("base_color")
		if cv is Color:
			return cv as Color
	elif mat is BaseMaterial3D:
		return (mat as BaseMaterial3D).albedo_color
	return fallback


static func _hlod_kind_for(id: String) -> int:
	if id.begins_with("lm_") or id.begins_with("ind_") or id.begins_with("env_") or id.begins_with("hub_") or id.begins_with("fort_"):
		return 1
	for kw: String in [
		"cooling_tower", "gantry", "crane", "fuel_tank", "foundry", "chem_plant", "loco",
		"ore_crusher", "water_tower", "grain_silo", "substation", "command_bunker", "hangar",
		"power_station", "radar", "relay", "drydock", "well_core", "mining", "lighthouse",
		"airship", "smelter", "fuel_depot", "artillery", "helipad", "geothermal", "observatory",
		"biodome", "silo", "comms_dish", "bathysphere", "gas_station", "warehouse", "barrack", "shed",
	]:
		if id.contains(kw):
			return 1
	return 0


static func _is_hlod_skip_mat(mat: Material) -> bool:
	if mat is ShaderMaterial:
		var sm: ShaderMaterial = mat as ShaderMaterial
		if sm.shader != null:
			var rp: String = sm.shader.resource_path
			if rp.contains("ind_glass") or rp.contains("foliage"):
				return true
	elif mat is BaseMaterial3D:
		if (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return true
	return false


## 自动提取预制件的 1~8 个紧凑局部空间 HLOD 剪影盒（pos 中心, sz 尺寸, col 颜色, kind 0=城区/1=工业, tintable 主墙可随立面换色）
static func get_hlod_boxes(id: String) -> Array:
	if _hlod_cache.has(id):
		return _hlod_cache[id] as Array
	var pf := get_prefab(id)
	if pf.is_empty():
		_hlod_cache[id] = []
		return []
	var bsz: Vector3 = pf["base_sz"]
	if id.begins_with("ter_") or id == "distress_beacon" or id == "supply_airdrop_pod":
		_hlod_cache[id] = []
		return []
	if id.begins_with("veh_") and bsz.y < 4.0:
		_hlod_cache[id] = []
		return []
	if bsz.y < 2.8 and maxf(bsz.x, bsz.z) < 6.5:
		_hlod_cache[id] = []
		return []

	var ab: AABB = pf["aabb"]
	var y_floor: float = maxf(0.0, ab.position.y)
	var y_top: float = ab.end.y
	var total_h: float = y_top - y_floor
	if total_h < 1.2:
		_hlod_cache[id] = []
		return []

	var kind: int = _hlod_kind_for(id)
	var prim_col: Color = _mat_color(pf.get("primary_mat") as Material, Color(0.50, 0.48, 0.45))
	var y_cut: float = y_floor + minf(0.45, total_h * 0.08)
	var span_h: float = maxf(0.5, y_top - y_cut)
	var cx: float = ab.position.x + ab.size.x * 0.5
	var cz: float = ab.position.z + ab.size.z * 0.5

	# 3 层高度分带 × (整层 + 2x2 象限)，快速采样顶点构建精确轮廓
	var band_lo := PackedFloat32Array([0.0, 0.44, 0.76])
	var band_hi := PackedFloat32Array([0.44, 0.76, 1.01])
	var strata: Array = []
	for bi in 3:
		var quads: Array = []
		for _qi in 4:
			quads.append({
				"mn": Vector3(INF, INF, INF), "mx": Vector3(-INF, -INF, -INF),
				"n": 0, "cr": 0.0, "cg": 0.0, "cb": 0.0, "pn": 0,
			})
		strata.append({
			"mn": Vector3(INF, INF, INF), "mx": Vector3(-INF, -INF, -INF),
			"n": 0, "cr": 0.0, "cg": 0.0, "cb": 0.0, "pn": 0, "quads": quads,
		})

	var surfaces: Array = pf["surfaces"]
	for s_info: Dictionary in surfaces:
		var s_mat: Material = s_info["mat"] as Material
		if _is_hlod_skip_mat(s_mat):
			continue
		var am: ArrayMesh = s_info["mesh"] as ArrayMesh
		if am == null or am.get_surface_count() == 0:
			continue
		var arr: Array = am.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nv: int = verts.size()
		if nv == 0:
			continue
		var vcols: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var use_vcol_tint := false
		var use_vcol_rgb := false
		if s_mat is ShaderMaterial:
			var tm_v: Variant = (s_mat as ShaderMaterial).get_shader_parameter("tint_mode")
			if tm_v != null and int(tm_v) >= 2:
				use_vcol_tint = true
		elif s_mat is StandardMaterial3D and (s_mat as StandardMaterial3D).vertex_color_use_as_albedo:
			use_vcol_rgb = true
		var base_c: Color = _mat_color(s_mat, prim_col)
		var is_prim: bool = bool(s_info["primary"]) or bool(s_info.get("primary_pier", false))
		var step: int = maxi(1, nv / 320)
		var vi := 0
		while vi < nv:
			var v: Vector3 = verts[vi]
			if v.y >= y_cut:
				var f: float = clampf((v.y - y_cut) / span_h, 0.0, 1.0)
				var bi := 0
				if f >= band_lo[2]:
					bi = 2
				elif f >= band_lo[1]:
					bi = 1
				var vc: Color = base_c
				if use_vcol_tint and vi < vcols.size():
					var cv: Color = vcols[vi]
					vc = Color(cv.g, cv.b, cv.a)
				elif use_vcol_rgb and vi < vcols.size():
					vc = vcols[vi]
				var st_b: Dictionary = strata[bi]
				var smn: Vector3 = st_b["mn"]
				var smx: Vector3 = st_b["mx"]
				st_b["mn"] = Vector3(minf(smn.x, v.x), minf(smn.y, v.y), minf(smn.z, v.z))
				st_b["mx"] = Vector3(maxf(smx.x, v.x), maxf(smx.y, v.y), maxf(smx.z, v.z))
				st_b["n"] = int(st_b["n"]) + 1
				st_b["cr"] = float(st_b["cr"]) + vc.r
				st_b["cg"] = float(st_b["cg"]) + vc.g
				st_b["cb"] = float(st_b["cb"]) + vc.b
				if is_prim:
					st_b["pn"] = int(st_b["pn"]) + 1
				var qi: int = (1 if v.x >= cx else 0) + (2 if v.z >= cz else 0)
				var qd: Dictionary = (st_b["quads"] as Array)[qi]
				var qmn: Vector3 = qd["mn"]
				var qmx: Vector3 = qd["mx"]
				qd["mn"] = Vector3(minf(qmn.x, v.x), minf(qmn.y, v.y), minf(qmn.z, v.z))
				qd["mx"] = Vector3(maxf(qmx.x, v.x), maxf(qmx.y, v.y), maxf(qmx.z, v.z))
				qd["n"] = int(qd["n"]) + 1
				qd["cr"] = float(qd["cr"]) + vc.r
				qd["cg"] = float(qd["cg"]) + vc.g
				qd["cb"] = float(qd["cb"]) + vc.b
				if is_prim:
					qd["pn"] = int(qd["pn"]) + 1
			vi += step

	var split_eligible: bool = maxf(bsz.x, bsz.z) >= 12.0 or id.contains("gantry") or id.contains("crane") or id.contains("gate") or id.contains("terminus") or id.contains("church")
	var raw_boxes: Array = []
	for bi in 3:
		var st_b: Dictionary = strata[bi]
		var n_b: int = int(st_b["n"])
		if n_b < 4:
			continue
		var smn: Vector3 = st_b["mn"]
		var smx: Vector3 = st_b["mx"]
		if bi == 0:
			smn.y = 0.0
		var ssz := smx - smn
		if ssz.y < 0.45:
			continue
		var band_area := maxf(0.1, ssz.x * ssz.z)
		var did_split := false
		if split_eligible and (bi >= 1 or id.contains("gantry") or id.contains("crane") or id.contains("gate")):
			var pop_qs: Array = []
			var sum_q_area := 0.0
			for qd_v in (st_b["quads"] as Array):
				var qd: Dictionary = qd_v as Dictionary
				var qn: int = int(qd["n"])
				if qn < 5:
					continue
				var qmn: Vector3 = qd["mn"]
				var qmx: Vector3 = qd["mx"]
				if bi == 0:
					qmn.y = 0.0
				var qsz := qmx - qmn
				if qsz.y < 0.55 or maxf(qsz.x, qsz.z) < 0.55:
					continue
				sum_q_area += maxf(qsz.x, 0.85) * maxf(qsz.z, 0.85)
				pop_qs.append(qd)
			if pop_qs.size() >= 2 and sum_q_area < band_area * 0.62:
				did_split = true
				for qd_v in pop_qs:
					var qd: Dictionary = qd_v as Dictionary
					var qn: float = float(qd["n"])
					var qmn: Vector3 = qd["mn"]
					var qmx: Vector3 = qd["mx"]
					if bi == 0:
						qmn.y = 0.0
					var qsz := Vector3(maxf(0.85, qmx.x - qmn.x), maxf(0.85, qmx.y - qmn.y), maxf(0.85, qmx.z - qmn.z))
					var qpos := (qmn + qmx) * 0.5
					var qcol := Color(float(qd["cr"]) / qn, float(qd["cg"]) / qn, float(qd["cb"]) / qn)
					raw_boxes.append({
						"pos": qpos, "sz": qsz, "col": qcol, "kind": kind,
						"tintable": float(qd["pn"]) >= qn * 0.42, "band": bi, "single": false,
					})
		if not did_split:
			var fn: float = float(n_b)
			var bsz_out := Vector3(maxf(0.90, ssz.x), maxf(0.85, ssz.y), maxf(0.90, ssz.z))
			var bpos := (smn + smx) * 0.5
			var bcol := Color(float(st_b["cr"]) / fn, float(st_b["cg"]) / fn, float(st_b["cb"]) / fn)
			raw_boxes.append({
				"pos": bpos, "sz": bsz_out, "col": bcol, "kind": kind,
				"tintable": float(st_b["pn"]) >= fn * 0.42, "band": bi, "single": true,
			})

	# 合并高度连续且平面投影近似一致的相邻整层盒体（住宅/仓库收拢为 1~2 盒，塔楼/教堂/龙门吊保留 3~6 盒层级）
	var merged: Array = []
	for bx_v in raw_boxes:
		var bx: Dictionary = bx_v as Dictionary
		if not merged.is_empty():
			var prev: Dictionary = merged[merged.size() - 1]
			if bool(prev["single"]) and bool(bx["single"]):
				var psz: Vector3 = prev["sz"]
				var bsz2: Vector3 = bx["sz"]
				var pp: Vector3 = prev["pos"]
				var bp: Vector3 = bx["pos"]
				var dx_r: float = absf(psz.x - bsz2.x) / maxf(1.0, maxf(psz.x, bsz2.x))
				var dz_r: float = absf(psz.z - bsz2.z) / maxf(1.0, maxf(psz.z, bsz2.z))
				var c_off: float = Vector2(pp.x - bp.x, pp.z - bp.z).length()
				if dx_r < 0.18 and dz_r < 0.18 and c_off < 1.25 and bool(prev["tintable"]) == bool(bx["tintable"]):
					var mn_m := Vector3(
						minf(pp.x - psz.x * 0.5, bp.x - bsz2.x * 0.5),
						minf(pp.y - psz.y * 0.5, bp.y - bsz2.y * 0.5),
						minf(pp.z - psz.z * 0.5, bp.z - bsz2.z * 0.5)
					)
					var mx_m := Vector3(
						maxf(pp.x + psz.x * 0.5, bp.x + bsz2.x * 0.5),
						maxf(pp.y + psz.y * 0.5, bp.y + bsz2.y * 0.5),
						maxf(pp.z + psz.z * 0.5, bp.z + bsz2.z * 0.5)
					)
					var p_col: Color = prev["col"]
					var b_col: Color = bx["col"]
					prev["pos"] = (mn_m + mx_m) * 0.5
					prev["sz"] = mx_m - mn_m
					prev["col"] = p_col.lerp(b_col, 0.35)
					continue
		merged.append(bx)

	var out: Array = []
	if merged.is_empty():
		var fb_sz := Vector3(maxf(1.0, ab.size.x), maxf(1.0, total_h), maxf(1.0, ab.size.z))
		out.append({
			"pos": Vector3(cx, total_h * 0.5, cz),
			"sz": fb_sz, "col": prim_col, "kind": kind, "tintable": true,
		})
	else:
		for i in mini(merged.size(), 8):
			var m_item: Dictionary = merged[i]
			out.append({
				"pos": m_item["pos"],
				"sz": m_item["sz"],
				"col": m_item["col"],
				"kind": int(m_item["kind"]),
				"tintable": bool(m_item["tintable"]),
			})
	_hlod_cache[id] = out
	return out


## 构建预合并的单材质轻量 Node3D 实例（供动态运输机 / 空投舱 / 事件信标等移动或预打包节点使用，显著降低节点与 Draw Call）
static func build_merged(id: String, target_sz := Vector3.ZERO) -> Node3D:
	var root := Node3D.new()
	root.name = id
	var pf := get_prefab(id)
	if pf.is_empty():
		return root
	var bsz: Vector3 = pf["base_sz"]
	var use_sz := bsz if target_sz == Vector3.ZERO else target_sz
	var scl := Vector3(
		maxf(0.15, use_sz.x / maxf(0.1, bsz.x)),
		maxf(0.15, use_sz.y / maxf(0.1, bsz.y)),
		maxf(0.15, use_sz.z / maxf(0.1, bsz.z))
	)
	var xf := Transform3D(Basis.from_scale(scl), Vector3.ZERO)
	for s_info: Dictionary in pf["surfaces"]:
		var mi := MeshInstance3D.new()
		mi.mesh = s_info["mesh"] as Mesh
		mi.material_override = s_info["mat"] as Material
		mi.transform = xf
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		if not bool(s_info["shadow"]):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return root
