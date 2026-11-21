extends Node3D
## 一局行动：空投 → 搜刮 → 在能源耗尽前撤离（固定撤离点 / 呼叫运输机）。

signal raid_ended(result: Dictionary)

const Prof = preload("res://scripts/prof.gd")
const MechScript = preload("res://scripts/mech.gd")
const BugScript = preload("res://scripts/bug.gd")
const NestScript = preload("res://scripts/nest.gd")
const ProjScript = preload("res://scripts/projectile.gd")
const LootScript = preload("res://scripts/loot_box.gd")
const ExtractScript = preload("res://scripts/extract_zone.gd")
const HudScript = preload("res://scripts/hud.gd")
const MV = preload("res://scripts/mech_visual.gd")
const A = preload("res://scripts/art.gd")
const FM = preload("res://scripts/modules/field_models.gd")
const DM = preload("res://scripts/modules/device_models.gd")
const MM = preload("res://scripts/modules/munition_models.gd")
const Growth = preload("res://scripts/progression/growth.gd")
const BuildingsExt = preload("res://scripts/buildings_ext.gd")
const PrefabLib = preload("res://scripts/buildings/prefab_lib.gd")
const OccBuildings = preload("res://scripts/occ_buildings.gd")
const MountainTerrain = preload("res://scripts/mountain_terrain.gd")

const HALF := 230.0            ## 不规则战区多边形的本地包围半宽（与 world_city.gd ZONE_HALF 一致）
var EXT_HALF := 290.0          ## 地表战区外围连续城市群远景半宽（地下竖井战区收回到 HALF）
const MAX_BUGS := 170          ## 全场虫数上限（Boss 不占名额）
const INITIAL_BUGS := 150      ## 开局铺虫的上限：给 Boss 召唤与虫潮留出余量
const BUG_DENSITY := 1.3       ## 分布表虫群密度的整体倍率（v0.6 起虫群数量约为原来的 2.5 倍）
const FactionsScript = preload("res://scripts/factions/factions.gd")
const WorldLinkScript = preload("res://scripts/world_link.gd")
const CAM_OFFSET := Vector3(0, 31, 22.5)  # 2.5D 斜俯视（约 54°）
const ZOOM_MIN := 0.30   ## 滚轮拉到最近（看机甲细节）
const ZOOM_STD := 0.69   ## 最大腰射视距收缩至原 1.15 的 0.6 倍（远距离侦察与开镜由右键瞄准接管）
const AI_VIEW_ZOOM_REF := 1.15   ## 敌人视野感知沿用的基准镜头高度倍率
const AI_VIEW_FOV_REF := 40.0    ## 敌人视野感知沿用的固定竖直参考视角，与渲染相机实时 FOV 解耦
const FP_CAM_OFFSET := Vector3(0.0, 0.58, -0.52)  ## 第一人称机舱视点局部坐标（穿透机体并完整保留左右武器可见）
const FP_FOV_STD := 74.0
const FP_FOV_AIM := 58.0
const FP_FOV_SCOPE := 28.0
const FP_PITCH_MIN := deg_to_rad(-58.0)
const FP_PITCH_MAX := deg_to_rad(62.0)
const RaidSkyShader = preload("res://shaders/raid_sky.gdshader")
var ZOOM_MAX := ZOOM_STD   ## 滚轮拉到最远：在 0.6x 基础上小幅受高射程武器影响

var coop = null
var rng := RandomNumberGenerator.new()
var mech
var camera: Camera3D
var _sun_light: DirectionalLight3D
var view_mode := 0               ## 0 = 第三人称斜俯视，1 = 第一人称机舱视角
var fp_yaw := 0.0                ## 第一人称水平偏航角（弧度，0 朝向 -Z）
var fp_pitch := 0.0              ## 第一人称垂直俯仰角（弧度，正值仰视）
var _fp_fov := FP_FOV_STD
var _window_focused := true
var force_mouse_capture := false ## 测试显式验证指针捕获与解锁时置为 true
var cam_zoom := ZOOM_STD  # 鼠标滚轮缩放：默认最远一档（ZOOM_MAX），可滚轮拉近到 ZOOM_MIN
var _eff_zoom := ZOOM_STD
var _aim_pan := Vector3.ZERO
var cam_focus := Vector3.ZERO
var hud
var world: Node3D
var fx: Node3D
var blocks: Array = []          ## Rect2（XZ 平面）用于摆放时避让
var extracts: Array = []
var transport_zone
var transport_ship: Node3D
var transport_state := "none"   ## none / incoming / landed / gone
var transport_t := 0.0
var extract_progress := 0.0
var extract_target
var time := 0.0
var kills := 0
var ended := false
var dropping := true
var open_box
var shake := 0.0
var loadout := {}
var start_cargo: Array = []
var aim_override = null   ## 测试用
var listener: AudioListener3D
var _joy_aim_active := false
var _last_joy_aim := Vector3.FORWARD
var _last_mouse_pos := Vector2.ZERO
var _fp_look_touch_id := -1
var _pinch_pts := {}
var _pinch_dist := 0.0
## 交战与遭遇：每 0.25 秒扫描一次附近的虫子
var in_combat := false
var _combat_quiet := 0.0
var _scan_t := 0.0
var _seen_kinds := {}
var _found_pois := {}
var factions          ## 流浪者小队与战斗队友（scripts/factions/factions.gd）
var world_link        ## 地图边缘转场（scripts/world_link.gd）
var server_drop := Vector3.ZERO

class ServerHud extends RefCounted:
	var radar = null
	var pause_panel = null
	var settings_panel = null
	var loot_panel = null
	var joy_left = null
	var joy_right = null
	var last_toggle_frame := -100
	var _touch_revealed := false
	func msg(t: String) -> void: print("[server] ", t)
	func show_zone_banner(_t: String, _d := 0.0, _sub := "") -> void: pass
	func refresh() -> void: pass
	func refresh_loot() -> void: pass
	func open_loot(_b) -> void: pass
	func close_loot() -> void: pass
	func set_prompt(_t: String) -> void: pass
	func on_loadout_changed() -> void: pass
	func hurt() -> void: pass
	func notify_hit() -> void: pass
	func notify_enemy_hit(_n: Node3D, _prev: float, _cur: float, _mx: float) -> void: pass
	func set_coop_status(_t: String, _warn := false) -> void: pass
	func inv_open() -> bool: return false
	func map_open() -> bool: return false
	func is_touch_busy() -> bool: return false
	func is_touch_aiming() -> bool: return false
	func is_touch_firing() -> bool: return false
	func clear_touch_aim() -> void: pass
	func sync_view_mode_ui() -> void: pass
var transit := {}     ## 从相邻战区转场进来时携带的状态（空 = 正常空投出击）
var visited_maps: Array = []
var drop_points: Array = []   ## 本战区候选空投出生点列表（[0] 为固定主降落点）
var primary_drop := Vector3.ZERO   ## 本战区固定主空投点（锚定撤离点、首领与虫群分布，确保全图固定化）
var _loot_anchors: Array = []      ## 情境化固定物资箱候选锚点（来自建筑门廊、装卸台、掩体、集装箱、地标与残骸）
var _cam_attr: CameraAttributesPractical
var _contact_shadows: Array = []   ## 全图静态物件（集装箱/载具/暗堡/货车/油罐/雕塑）单批次接地软阴影变换队列
var _curb_car_pts: Array[Vector2] = []   ## 路边已停放载具坐标（防止单条公路上连串堵车）
var _last_wreck_id := ""
var _last_wreck_col := -1
var _occ_bldg_str := 0.0           ## 非盒体结构（大型桥梁/岩崖）兜底局部虚化强度 (0..1)
var _occ_bldgs = null              ## 整栋遮挡建筑平滑半透明虚化管理器（scripts/occ_buildings.gd）
var _occ_faded_enemies := {}       ## 当前遮挡机甲而处于半透明虚化中的大型敌人/首领（iid -> [Node, fade]）
var _occ_probes: Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _occ_ray_q: PhysicsRayQueryParameters3D = null
var _occ_ray_cam := Vector3(1e9, 1e9, 1e9)
var _occ_ray_mp := Vector3(1e9, 1e9, 1e9)
var _occ_phys_cached := false
var _occ_sent_cam := Vector3(1e9, 1e9, 1e9)
var _occ_sent_mech := Vector3(1e9, 1e9, 1e9)
var _occ_sent_params := Vector4(-1.0, -1.0, -1.0, -1.0)
var _near_box = null
var _box_ray_q: PhysicsRayQueryParameters3D = null


const MAP_SEEDS := {
	"greyport": 101,
	"ironbelt": 202,
	"dustfield": 303,
	"redlake": 404,
	"canyon": 505,
	"abyss_maw": 606,
	"bayport": 707,
}


static var force_async_load := false   ## 测试或正式运行强制启用分阶段异步加载界面

## 战区固定种子（分阶段偏移，各阶段互不串扰，每局地图完全固化不随机）
func _map_seed(stage := 0) -> int:
	return int(MAP_SEEDS.get(map_id, (map_id.hash() & 0x3fffffff) + 1)) + stage * 10007


func start(lo: Dictionary, carry: Array, transit_state := {}) -> void:
	transit = transit_state
	loadout = lo.duplicate()
	start_cargo = carry.duplicate()
	world = Node3D.new()
	add_child(world)
	fx = Node3D.new()
	add_child(fx)
	map_id = GameData.map_id
	_loot_anchors.clear()
	_contact_shadows.clear()
	_curb_car_pts.clear()
	_last_wreck_id = ""
	_last_wreck_col = -1
	if Net.active(): seed(_map_seed(99))
	rng.seed = _map_seed(0)
	var t_build := Time.get_ticks_usec()
	_tphase.clear()
	_tlast = t_build
	_load_map()
	_tmark("load_map")
	_build_environment()
	_build_ground()
	_tmark("env+ground")
	var drop := _build_map()
	primary_drop = drop
	world_link = WorldLinkScript.new()
	world_link.name = "WorldLink"
	add_child(world_link)
	world_link.setup(self)
	if not transit.is_empty():
		drop = world_link.entry_point(str(transit.get("edge", "")), drop)
	_tlast = Time.get_ticks_usec()
	if Net.is_dedicated_server():
		_inst.clear()
	else:
		_build_map_texture()
		world_link.paint_map(map_tex)
		_build_zone_ground()
	_tmark("map_tex+zone_ground")
	_run_ext_build(primary_drop)
	_place_contextual_loot()
	_tmark("ext")
	_spawn_extracts(primary_drop)
	if not Net.is_dedicated_server():
		_occ_bldgs = OccBuildings.new()
		_occ_bldgs.collect(self)
	preload("res://scripts/collision_opt.gd").optimize(self)   # 碰撞后处理：小件去碰撞、窄缝合并、防卡死（见脚本说明）
	rebuild_nav()   # 导航网格：所有静态几何体与碰撞后处理就绪后立即栅格化，用于剔除死房刷怪与死房物资箱
	if nav != null:
		nav.set_seed(drop)
	_spawn_initial_bugs(primary_drop)
	if not transit.is_empty():
		_clear_transit_spawn_bugs(drop)
	_sanitize_spawns_and_loot(drop)
	_tmark("extracts+bugs")
	if not Net.is_dedicated_server():
		_bake_static(drop)
	else:
		_inst.clear()
	_tmark("bake")
	_tmark("nav")
	print("[raid] map build %s: %d ms, world nodes %d, blocks %d" % [map_id, (Time.get_ticks_usec() - t_build) / 1000, _count_nodes(world), blocks.size()])
	print("[raid]   phases: %s" % ", ".join(_tphase.keys().map(func(k): return "%s %d" % [k, _tphase[k]])))
	_finish_setup(drop)


## 分阶段异步构建战区：每阶段向 LoadingScreen 汇报进度并让出渲染帧，彻底消除进图单帧卡顿
func start_async(lo: Dictionary, carry: Array, transit_state := {}, loader = null) -> void:
	var web_sliced := OS.has_feature("web")
	_load_slice_deadline = Time.get_ticks_usec() + 8000
	transit = transit_state
	loadout = lo.duplicate()
	start_cargo = carry.duplicate()
	world = Node3D.new()
	add_child(world)
	fx = Node3D.new()
	add_child(fx)
	map_id = GameData.map_id
	_loot_anchors.clear()
	_contact_shadows.clear()
	_curb_car_pts.clear()
	_last_wreck_id = ""
	_last_wreck_col = -1
	if Net.active(): seed(_map_seed(99))
	rng.seed = _map_seed(0)
	var t_build := Time.get_ticks_usec()
	_tphase.clear()
	_tlast = t_build

	if loader != null and is_instance_valid(loader):
		await loader.step(0.08, Loc.t("正在同步信天翁号空投航线与战区遥测数据...", "Syncing Albatross drop vector & sector telemetry..."))
	elif Net.is_dedicated_server():
		await get_tree().process_frame
	await _load_map(web_sliced)
	_tmark("load_map")
	_build_environment()
	_build_ground()
	_tmark("env+ground")

	if loader != null and is_instance_valid(loader):
		await loader.step(0.20, Loc.t("正在扫描地表路网、水系与铁道脉络...", "Scanning surface roads, waterways & rail networks..."))
	elif Net.is_dedicated_server():
		await get_tree().process_frame
	_tlast = Time.get_ticks_usec()
	_shield_spots()
	_tmark("shield_spots")
	_build_river()
	if web_sliced: await _yield_load_slice()
	_build_lakes()
	await _build_roads(web_sliced)
	if web_sliced: await _yield_load_slice()
	_build_rails()
	if web_sliced: await _yield_load_slice()
	_build_ridges()
	_tmark("roads+water+rails")

	if loader != null and is_instance_valid(loader):
		await loader.step(0.36, Loc.t("正在重构重点设施与遗迹院落...", "Reconstructing key facilities & ruin compounds..."))
	elif Net.is_dedicated_server():
		await get_tree().process_frame
	poi_centers.clear()
	poi_ids.clear()
	for p: Dictionary in layout.pois:
		poi_centers.append(Vector3(p.c.x, 0, p.c.y))
		poi_ids.append(str(p.id))
	var kc := _keep_clear
	_keep_clear = []
	await _build_pois(web_sliced)
	_keep_clear = kc
	_tmark("pois")

	if loader != null and is_instance_valid(loader):
		await loader.step(0.50, Loc.t("正在测绘街区建筑群与废墟掩体...", "Mapping urban blocks & ruin cover..."))
	elif Net.is_dedicated_server():
		await get_tree().process_frame
	await _build_blocks(web_sliced)
	_tmark("blocks")

	if loader != null and is_instance_valid(loader):
		await loader.step(0.62, Loc.t("正在散布地表植被、残骸与边界通道...", "Scattering surface foliage, wrecks & border gates..."))
	elif Net.is_dedicated_server():
		await get_tree().process_frame
	await _build_fields(web_sliced)
	await _scatter(web_sliced)
	_tmark("fields+scatter")
	rng.seed = _map_seed(11)
	for k in 32:
		var sp := _curb_car_spot()
		if not sp.is_empty():
			_wreck_car(sp[0], float(sp[1]))
	for k in 10:
		var p := _roadside_spot()
		if p != Vector3.INF:
			_fire_barrel(p)
	if web_sliced: await _yield_load_slice()
	_scatter_road_shoulders()
	_register_roadside_car_loot()
	var drop := _drop_point()
	primary_drop = drop
	world_link = WorldLinkScript.new()
	world_link.name = "WorldLink"
	add_child(world_link)
	world_link.setup(self)
	if not transit.is_empty():
		drop = world_link.entry_point(str(transit.get("edge", "")), drop)

	if loader != null and is_instance_valid(loader):
		await loader.step(0.74, Loc.t("正在渲染战术卫星地形图与地标建筑...", "Rendering tactical satellite terrain & landmarks..."))
	elif Net.is_dedicated_server():
		await get_tree().process_frame
	_tlast = Time.get_ticks_usec()
	if Net.is_dedicated_server():
		_inst.clear()
	else:
		await _build_map_texture(web_sliced)
		world_link.paint_map(map_tex)
		if web_sliced: await _yield_load_slice()
	_build_zone_ground()
	_tmark("map_tex+zone_ground")
	_run_ext_build(primary_drop)
	_place_contextual_loot()
	_tmark("ext")

	if loader != null and is_instance_valid(loader):
		await loader.step(0.83, Loc.t("正在部署撤离信标与优化战场物理碰撞...", "Deploying extract beacons & optimizing collision..."))
	elif Net.is_dedicated_server():
		await get_tree().process_frame
	_spawn_extracts(primary_drop)
	if not Net.is_dedicated_server():
		_occ_bldgs = OccBuildings.new()
		_occ_bldgs.collect(self)
	preload("res://scripts/collision_opt.gd").optimize(self)
	rebuild_nav()
	if nav != null:
		nav.set_seed(drop)

	if loader != null and is_instance_valid(loader):
		await loader.step(0.91, Loc.t("正在侦测虫群活跃热区与战区首领信标...", "Scanning swarm hotspots & sector boss signals..."))
	elif Net.is_dedicated_server():
		await get_tree().process_frame
	_spawn_initial_bugs(primary_drop)
	if not transit.is_empty():
		_clear_transit_spawn_bugs(drop)
	_sanitize_spawns_and_loot(drop)
	_tmark("extracts+bugs")

	if loader != null and is_instance_valid(loader):
		await loader.step(0.96, Loc.t("正在合并渲染批次与烘焙战术导航网格...", "Batching static meshes & baking tactical navgrid..."))
	elif Net.is_dedicated_server():
		await get_tree().process_frame
	if not Net.is_dedicated_server():
		_bake_static(drop)
	else:
		_inst.clear()
	_tmark("bake")
	_tmark("nav")
	print("[raid] map build %s (async): %d ms, world nodes %d, blocks %d" % [map_id, (Time.get_ticks_usec() - t_build) / 1000, _count_nodes(world), blocks.size()])
	_finish_setup(drop)


func _finish_setup(drop: Vector3) -> void:
	if Net.is_dedicated_server():
		server_drop = drop
		hud = ServerHud.new()
		_add_ext_nodes()
		factions = FactionsScript.new()
		factions.name = "Factions"
		add_child(factions)
		factions.setup(self, drop)
		_sanitize_npcs()
		visited_maps = [map_id]
		dropping = false
		return
	mech = MechScript.new()
	mech.net_peer = Net.local_id()
	mech.raid = self
	add_child(mech)
	mech.setup(loadout, carry_copy())
	update_view_zoom(true)
	_eff_zoom = cam_zoom
	cam_focus = drop
	_aim_pan = Vector3.ZERO
	mech.global_position = drop + Vector3(0, 30, 0)
	mech.input_locked = true
	mech.died.connect(_on_mech_died)
	mech.message.connect(func(t): hud.msg(t))
	for b in get_tree().get_nodes_in_group("bugs"):
		if b.target == null:
			b.target = mech

	camera = Camera3D.new()
	camera.fov = 40.0
	camera.near = 1.0
	camera.far = 340.0
	_cam_attr = CameraAttributesPractical.new()
	_cam_attr.dof_blur_far_enabled = false
	_cam_attr.dof_blur_near_enabled = false
	camera.attributes = _cam_attr
	add_child(camera)
	camera.current = true
	_apply_style.call_deferred()
	camera.global_position = drop + CAM_OFFSET * _eff_zoom
	camera.look_at(drop, Vector3.UP)
	_update_cam_dof(false)
	# 3D 音效的收听点：放在机甲上方、朝向与镜头一致（镜头离地 40 多米，直接用镜头收听会让近处的声音太小）
	listener = AudioListener3D.new()
	add_child(listener)
	listener.make_current()

	ash = A.emitter(self, Vector3.ZERO, {"amount": 160, "life": 6.0, "size": 0.055, "box": Vector3(30, 6, 22), "dir": Vector3(1, -0.3, 0.2),
		"spread": 30.0, "vmin": 0.6, "vmax": 1.4, "gravity": Vector3(0.3, -0.2, 0.1), "c0": Color(0.8, 0.78, 0.7, 0.0), "cmid": Color(0.85, 0.82, 0.74, 0.36),
		"c1": Color(0.7, 0.68, 0.6, 0.0), "grow0": 1.0, "grow1": 1.0, "additive": false})
	hud = HudScript.new()
	add_child(hud)
	hud.setup(self)
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	if GameData.view_mode == 1:
		set_view_mode(1, false)
	_add_ext_nodes()

	factions = FactionsScript.new()
	factions.name = "Factions"
	add_child(factions)
	factions.setup(self, drop)
	_sanitize_npcs()
	if Audio.has_method("warm_combat_sfx"):
		Audio.warm_combat_sfx()
	_warm_combat_fx()
	for enemy in get_tree().get_nodes_in_group("occ_fade_bugs"):
		enemy.set_occ_fade(0.01)
		enemy.set_occ_fade(0.0)
	_build_subregions()
	if Net.active():
		visited_maps = [map_id]
		mech.position = drop + Vector3(0, 0.3, 0)
		mech.input_locked = false
		dropping = false
		_init_subregion(drop, 0.12)
		return
	if transit.is_empty():
		visited_maps = [map_id]
		_drop_sequence(drop)
		_init_subregion(drop, 0.45 if (not GameData.test_mode or force_async_load) else 0.08)
	else:
		world_link.arrive(transit, drop)
		_init_subregion(drop, 0.25 if (GameData.test_mode and not force_async_load) else 0.45)


func ground_dust_tint() -> Color:
	match map_id:
		"dustfield":
			return Color(0.66, 0.55, 0.37, 1.0)
		"ironbelt":
			return Color(0.55, 0.47, 0.36, 1.0)
		"redlake":
			return Color(0.48, 0.40, 0.34, 1.0)
		"canyon":
			return Color(0.60, 0.49, 0.35, 1.0)
		"bayport":
			return Color(0.43, 0.44, 0.41, 1.0)
		"abyss_maw":
			return Color(0.27, 0.22, 0.35, 1.0)
		_:
			return Color(0.42, 0.43, 0.40, 1.0)


func carry_copy() -> Array:
	return start_cargo.duplicate()


## 行动扩展（GameData.RAID_SCRIPTS，来自 data\ext 各文件）。每个脚本可写两部分，都可省略：
##   static func build(raid, drop: Vector3)  地形、遗迹建完之后、撤离点与虫群生成之前调用，用来摆地标与布景
##     （新建的静态网格挂在 raid.world 下，会和其余布景一起合批；可在 raid.blocks 里登记占地 Rect2 让后续摆放避让）
##   继承 Node 的脚本：机甲与 HUD 就绪后实例化为本节点的子节点，有 setup(raid) 时先调用它；
##     行动结束时随行动场景一起释放（天气、动态事件、局内通讯小窗等持续逻辑写在这里）
func _run_ext_build(drop: Vector3) -> void:
	rng.seed = _map_seed(13)
	for path in GameData.RAID_SCRIPTS:
		if str(path).ends_with("/landmarks.gd"):
			_keep_clear.clear()   # 地标原位一直留空到地标脚本自己落位
		var s: Script = load(str(path))
		if s == null:
			push_error("行动扩展脚本无法加载：%s" % path)
			continue
		for m in s.get_script_method_list():
			if m.name == "build":
				s.call("build", self, drop)
				break
	_keep_clear.clear()


func _add_ext_nodes() -> void:
	for path in GameData.RAID_SCRIPTS:
		if Net.is_client() and str(path).ends_with("/map_ext/events.gd"):
			continue
		var s: Script = load(str(path))
		if s == null or not s.can_instantiate() or not ClassDB.is_parent_class(s.get_instance_base_type(), "Node"):
			continue
		var n: Node = s.new()
		n.name = "ext_" + str(path).get_file().get_basename()
		if n.has_method("setup"):
			n.call("setup", self)
		add_child(n)


## 空投：高空坠落（尾焰 + 拖烟 + 地面引导光束）→ 反推减速（地面扬尘）→ 重落地（冲击波尘环、碎石、弹坑）→ 下蹲缓冲后起身排气
func _drop_sequence(drop: Vector3) -> void:
	mech.global_position = drop + Vector3(0, 30, 0)
	if view_mode == 0:
		camera.global_position = drop + Vector3(0, 6.5, 0) + CAM_OFFSET * cam_zoom
		camera.look_at(drop + Vector3(0, 6.5, 0), Vector3.UP)
	else:
		sync_fp_camera()
	# 地面着陆点战术角标与信号烟雾信标（取代32m实心光柱）
	var beacon_node := Node3D.new()
	fx.add_child(beacon_node)
	beacon_node.global_position = Vector3(drop.x, 0.115, drop.z)
	A.add(beacon_node, A.quad(5.4, 5.4), A.extract_pad_mat(Color(0.95, 0.58, 0.18, 0.82), 0.44, 4), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.emitter(beacon_node, Vector3.ZERO, {"tex": A.smoke_tex(), "additive": false, "soft_depth": 0.45, "amount": 10, "life": 1.6, "size": 0.78,
		"dir": Vector3(0.25, 1.0, 0.1).normalized(), "spread": 18.0, "vmin": 0.9, "vmax": 1.8, "gravity": Vector3(0, 0.3, 0),
		"c0": Color(0.88, 0.54, 0.22, 0.36), "c1": Color(0.35, 0.26, 0.20, 0.0), "grow0": 0.4, "grow1": 1.9})
	var flames: Array = []
	for x in [-0.55, 0.55]:
		var f := A.emitter(mech, Vector3(x, 0.4, 0.2), {"amount": 36, "life": 0.22, "size": 1.3, "dir": Vector3.DOWN, "spread": 10.0, "vmin": 9.0, "vmax": 14.0,
			"gravity": Vector3.ZERO, "local": true, "c0": Color(1.0, 0.95, 0.8), "cmid": Color(1.0, 0.6, 0.2, 0.9), "c1": Color(0.8, 0.2, 0.05, 0.0), "grow0": 0.5, "grow1": 1.4})
		flames.append(f)
	var trail := A.emitter(mech, Vector3(0, 0.6, 0), {"amount": 24, "life": 0.65, "size": 1.15, "tex": A.smoke_tex(), "additive": false, "spread": 42.0, "vmin": 0.4, "vmax": 1.1,
		"gravity": Vector3(0, 0.6, 0), "c0": Color(0.38, 0.34, 0.30, 0.0), "cmid": Color(0.32, 0.30, 0.28, 0.34), "cmid_pos": 0.22, "c1": Color(0.36, 0.34, 0.32, 0.0), "grow0": 0.38, "grow1": 1.45, "soft_depth": 0.85})
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.6, 0.25)
	glow.light_energy = 3.0
	glow.omni_range = 9.0
	mech.add_child(glow)
	glow.position = Vector3(0, -0.5, 0)
	var hold := {}   # lambda 按值捕获局部变量，用字典在回调间共享引用
	Audio.play_sfx("drop_fall")
	var tw := create_tween()
	tw.tween_property(mech, "global_position", drop + Vector3(0, 9, 0), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		# 反推点火：火焰拉长变亮，地面吹起连续 3D 体积外涌尘浪 + 细沙碎屑
		Audio.play_sfx("drop_retro")
		shake = 0.3
		glow.light_energy = 6.0
		for f in flames:
			f.initial_velocity_min = 16.0
			f.initial_velocity_max = 24.0
			f.lifetime = 0.3
		var dt := ground_dust_tint()
		A.spawn_dust_wave(fx, Vector3(drop.x, 0.0, drop.z), {
			"color": dt, "r0": 0.65, "r1": 4.4, "height": 1.20, "width": 1.40,
			"density": 2.45, "hot": 0.95, "dur": 0.88, "priority": 3,
		})
		var grit_c := dt.darkened(0.32)
		var ground_grit := A.emitter(world, Vector3(drop.x, 0.20, drop.z), {"amount": 32, "life": 0.55, "size": 0.14, "tex": A.soft_dot(), "additive": false,
			"ring_r": 0.85, "ring_h": 0.08, "ring_push": 28.0, "ring_pulse": 0.40, "dir": Vector3.UP, "spread": 35.0, "vmin": 1.8, "vmax": 4.2,
			"gravity": Vector3(0, -16.0, 0), "damp": 1.2, "smin": 0.6, "smax": 1.3,
			"c0": Color(grit_c.r, grit_c.g, grit_c.b, 0.88), "c1": Color(grit_c.r * 0.7, grit_c.g * 0.7, grit_c.b * 0.7, 0.0),
			"grow0": 1.0, "grow1": 0.35})
		hold["dust"] = ground_grit)
	tw.tween_property(mech, "global_position", drop + Vector3(0, 0.2, 0), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if is_instance_valid(beacon_node):
			beacon_node.queue_free()
		_drop_impact(drop)
		for f in flames:
			f.emitting = false
		trail.emitting = false
		glow.queue_free()
		if hold.has("dust") and is_instance_valid(hold.dust):
			hold.dust.emitting = false)
	tw.tween_interval(0.55)
	tw.tween_callback(func():
		dropping = false
		mech.input_locked = false)
	tw.tween_interval(2.5)
	tw.tween_callback(func():
		for f in flames:
			f.queue_free()
		trail.queue_free()
		if hold.has("dust") and is_instance_valid(hold.dust):
			hold.dust.queue_free())


func _drop_impact(drop: Vector3) -> void:
	var p := Vector3(drop.x, 0.15, drop.z)
	shake = 0.9
	mech.slam = 1.0
	mech.kick_v += Vector3(-3.0, 0, 0)
	alert_noise(p, 30.0)
	Audio.play_sfx("drop_impact")
	Audio.play_sfx("mech_vent", p + Vector3(0, 2.4, 0))
	_event("drop_landed", [p])
	_flash_light(p + Vector3(0, 1.0, 0), Color(1.0, 0.7, 0.4), 6.0, 14.0, 0.25)
	var dt := ground_dust_tint()
	# 真正 3D 体积光线步进落地尘浪（Schneider 体积云雕刻 + 双步 Beer-Lambert 太阳自阴影 + 深度精确包裹机甲）
	A.spawn_dust_wave(fx, Vector3(p.x, 0.0, p.z), {
		"color": dt, "r0": 0.90, "r1": 6.8, "height": 2.15, "width": 1.80,
		"density": 3.25, "hot": 0.85, "dur": 1.65, "priority": 4,
	})
	# 细碎泥土沙粒喷溅（深色微粒提供高速冲击质感）
	var grit_c := dt.darkened(0.36)
	A.burst(fx, p + Vector3(0, 0.25, 0), {"amount": 44, "life": 0.72, "size": 0.16, "tex": A.soft_dot(), "additive": false, "explosive": 0.96,
		"ring_r": 0.9, "ring_h": 0.12, "ring_push": 34.0, "ring_pulse": 0.28, "dir": Vector3.UP, "spread": 48.0, "vmin": 3.5, "vmax": 7.5,
		"gravity": Vector3(0, -20.0, 0), "damp": 0.8, "smin": 0.6, "smax": 1.4,
		"c0": Color(grit_c.r, grit_c.g, grit_c.b, 0.92), "c1": Color(grit_c.r * 0.65, grit_c.g * 0.65, grit_c.b * 0.65, 0.0),
		"grow0": 1.0, "grow1": 0.35})
	# 飞溅碎石（3D 实体混凝土/岩石块）
	A.burst(fx, p + Vector3(0, 0.4, 0), {"amount": 34, "life": 1.15, "mesh": _debris_mesh("rock"), "additive": false, "dir": Vector3.UP, "spread": 60.0, "vmin": 5.5, "vmax": 13.0,
		"gravity": Vector3(0, -25, 0), "damp": 0.4, "radius": 0.95, "smin": 0.75, "smax": 1.75, "c0": dt.darkened(0.28), "c1": dt.darkened(0.48), "grow0": 1.0, "grow1": 0.85})
	# 火星
	A.burst(fx, p + Vector3(0, 0.3, 0), {"amount": 26, "life": 0.55, "size": 0.11, "vmin": 6.5, "vmax": 15.0, "gravity": Vector3(0, -18, 0), "damp": 1.0,
		"c0": Color(1.0, 0.9, 0.6), "c1": Color(1.0, 0.35, 0.0, 0.0), "grow0": 1.0, "grow1": 0.2})
	# 弹坑 + 扩散冲击波
	var crater := A.ground_vfx(world, A.scorch_tex(), Color(0.95, 0.90, 0.84, 0.94), 6.8, Vector3(p.x, 0.094, p.z), false, 0.44, false, 2)
	crater.rotation.y = rng.randf() * TAU
	var wave_c := Color(dt.r * 1.15, dt.g * 1.12, dt.b * 1.06, 0.62)
	var wave := A.ground_vfx(fx, A.shockwave_tex(), wave_c, 4.0, Vector3(p.x, 0.116, p.z), false, 0.44, true, 4)
	var tw := create_tween()
	tw.tween_property(wave, "scale", Vector3(6.2, 1, 6.2), 0.38).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(wave.material_override, "shader_parameter/col", Color(wave_c.r, wave_c.g, wave_c.b, 0.0), 0.36)
	tw.tween_callback(wave.queue_free)
	# 起身时背部短促泄压细汽（体积极小、迅速散清）
	var steam: Array = []
	for x: float in [-0.52, 0.52]:
		var sx: float = -1.15 if x < 0.0 else 1.15
		var em := A.emitter(mech, Vector3(x, 2.35, 0.68), {"amount": 6, "life": 0.36, "size": 0.28, "tex": A.smoke_tex(), "additive": false,
			"dir": Vector3(sx, 0.40, 0.95).normalized(), "spread": 10.0, "vmin": 4.8, "vmax": 7.0, "damp": 3.8, "gravity": Vector3(0, 0.5, 0),
			"c0": Color(0.76, 0.74, 0.70, 0.0), "cmid": Color(0.72, 0.70, 0.66, 0.14), "cmid_pos": 0.18, "c1": Color(0.66, 0.64, 0.60, 0.0),
			"grow0": 0.20, "grow1": 1.10, "soft_depth": 0.55})
		if is_first_person():
			em.layers = MechScript.FP_HIDE_LAYER
		steam.append(em)
	var t2 := create_tween()
	t2.tween_interval(0.42)
	t2.tween_callback(func():
		for e in steam:
			if is_instance_valid(e):
				e.emitting = false)
	t2.tween_interval(0.6)
	t2.tween_callback(func():
		for e in steam:
			if is_instance_valid(e):
				e.queue_free())


# ================= 世界生成 =================
var flicker_lights: Array = []   ## [OmniLight3D, base_energy, phase]
var ash: CPUParticles3D
var smoke: CPUParticles3D


func _build_environment() -> void:
	if Net.is_dedicated_server():
		return
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = RaidSkyShader
	sky_mat.set_shader_parameter("cloud_pano", A.world_tex("skybox_clouds_pano.png"))
	sky_mat.set_shader_parameter("horizon_pano", A.world_tex("skybox_horizon_pano.png"))
	sky_mat.set_shader_parameter("sky_top", Color(0.45, 0.45, 0.42))
	sky_mat.set_shader_parameter("sky_horizon", Color(0.68, 0.64, 0.56))
	sky_mat.set_shader_parameter("sky_ground", Color(0.42, 0.4, 0.34))
	sky_mat.set_shader_parameter("sky_bottom", Color(0.1, 0.08, 0.09))
	sky_mat.set_shader_parameter("cloud_tint", Color(0.92, 0.90, 0.86, 0.58))
	sky_mat.set_shader_parameter("sun_tint", Color(1.0, 0.91, 0.78))
	sky_mat.set_shader_parameter("fog_tint", Color(0.52, 0.5, 0.44))
	sky_mat.set_shader_parameter("urban_horizon", 0.72 if map_id in ["greyport", "ironbelt", "bayport"] else 0.16)
	sky_mat.set_shader_parameter("cavern_mode", 1.0 if map_id == "abyss_maw" else 0.0)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.44, 0.48, 0.54)
	env.ambient_light_energy = 0.36
	env.ambient_light_sky_contribution = 0.58
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 0.99
	env.tonemap_white = 7.4
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 0.28
	env.glow_strength = 0.88
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.22
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.14)
	env.set_glow_level(1, 0.64)
	env.set_glow_level(2, 0.50)
	env.set_glow_level(3, 0.30)
	env.set_glow_level(4, 0.12)
	env.set_glow_level(5, 0.0)
	env.ssr_fade_in = 0.045
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.45
	env.ssao_enabled = (not OS.has_feature("mobile")) and (RenderingServer.get_current_rendering_method() != "mobile") and (RenderingServer.get_current_rendering_method() != "gl_compatibility")
	env.ssao_radius = 2.35
	env.ssao_intensity = 2.05
	env.ssao_power = 1.45
	env.ssil_enabled = false
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8
	env.ssao_detail = 0.65
	env.ssao_horizon = 0.08
	env.ssao_sharpness = 0.88
	env.ssao_light_affect = 0.26
	env.fog_enabled = true
	env.fog_light_color = Color(0.52, 0.54, 0.58)
	env.fog_density = 0.00072
	env.fog_aerial_perspective = 0.42
	env.fog_sun_scatter = 0.22
	env.fog_height = 2.4
	env.fog_height_density = 0.042
	env.fog_sky_affect = 0.34
	env.volumetric_fog_enabled = false
	env.volumetric_fog_density = 0.0
	env.volumetric_fog_albedo = Color(0.82, 0.8, 0.74)
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_length = 80.0
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 0.86
	# 16^3 3D LUT 仅 1 次贴图查询，几乎零开销，低画质与移动端同样保留统一末世写实胶片调色
	env.adjustment_color_correction = A.cinematic_lut()
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, 52, 0)
	sun.light_color = Color(1.0, 0.90, 0.74)
	sun.light_energy = 2.66
	sun.light_angular_distance = 0.34
	sun.shadow_enabled = true
	sun.shadow_bias = 0.045
	sun.shadow_normal_bias = 1.40
	sun.shadow_blur = 1.55
	sun.directional_shadow_max_distance = 84.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_split_1 = 0.16
	sun.directional_shadow_split_2 = 0.36
	sun.directional_shadow_split_3 = 0.62
	sun.directional_shadow_blend_splits = true
	sun.light_volumetric_fog_energy = 1.4
	add_child(sun)
	_sun_light = sun
	RenderingServer.global_shader_parameter_set("sun_dir_world", sun.transform.basis.z.normalized())
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-52, -128, 0)
	fill.light_color = Color(0.46, 0.60, 0.90)
	fill.light_energy = 0.28
	fill.shadow_enabled = false
	add_child(fill)
	GameData.apply_env_quality(env, sun)
	# 场景里所有点光/聚光都不参与体积雾（见 _no_fog_light）
	get_tree().node_added.connect(_no_fog_light)


## 写实长焦微景深：关闭“微缩模型感”近景虚化，仅在极远视野边缘施以极轻微空气景深，维持 1:1 重工写实质感
func _update_cam_dof(scoping := false) -> void:
	if _cam_attr == null or camera == null:
		return
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	var mob := OS.has_feature("mobile") or RenderingServer.get_current_rendering_method() == "mobile"
	var want_dof := (not is_first_person()) and (not scoping) and (not compat) and (not mob) and GameData.quality >= 1
	if not want_dof:
		_cam_attr.dof_blur_far_enabled = false
		_cam_attr.dof_blur_near_enabled = false
		return
	var d_focus := (CAM_OFFSET * _eff_zoom).length()
	_cam_attr.dof_blur_far_enabled = true
	_cam_attr.dof_blur_near_enabled = false
	_cam_attr.dof_blur_far_distance = d_focus + 18.0 * _eff_zoom
	_cam_attr.dof_blur_far_transition = 16.0 * _eff_zoom
	_cam_attr.dof_blur_amount = 0.020


## 登记一个静态物件的地面柔和接触阴影，由 _bake_static 合并为单次 Draw Call 的 MultiMesh
func add_contact_shadow(pos: Vector3, sx: float, sz: float, yaw_deg := 0.0) -> void:
	var bs := Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled_local(Vector3(sx, 1.0, sz))
	_contact_shadows.append(Transform3D(bs, Vector3(pos.x, 0.025, pos.z)))


func _static_box(size: Vector3, pos: Vector3, c: Color, parent: Node3D = null, m: Material = null) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	# 墙体 / 废墟的碰撞体向上延伸到 5m：子弹从机甲肩部高度射出也会被挡住（俯视角下“看起来挡住就是挡住”）
	if size.y >= 1.1 and size.y < 5.0:
		sh.size.y = 5.0
		cs.position.y = (5.0 - size.y) * 0.5
	cs.shape = sh
	sb.add_child(cs)
	A.add(sb, A.bevel_box(size, min(0.12, min(size.x, min(size.y, size.z)) * 0.2)), m if m else A.concrete(c))
	(parent if parent else world).add_child(sb)
	sb.position = pos
	return sb


## 楼体：只有碰撞体（外观由 _ibox 合进 MultiMesh）；碰撞高度规则同 _static_box
func _bldg_body(size: Vector3, pos: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	if size.y >= 1.1 and size.y < 5.0:
		sh.size.y = 5.0
		cs.position.y = (5.0 - size.y) * 0.5
	cs.shape = sh
	sb.add_child(cs)
	world.add_child(sb)
	sb.position = pos
	return sb


## 重复小件交给分块合批（render_batch.gd：按分块 + 网格 + 去色材质收成 MultiMesh，外观懒构建）
func _multimesh(mesh: Mesh, m: Material, xforms: Array, shadow := true) -> void:
	_rb().add_inst(mesh, m, xforms, shadow)


var _rbatch: Node3D = null


func _rb() -> Node3D:
	if _rbatch == null or not is_instance_valid(_rbatch):
		_rbatch = preload("res://scripts/render_batch.gd").new()
		_rbatch.name = "RenderChunks"
		world.add_child(_rbatch)
	return _rbatch


func _rand_basis(tilt := 25.0) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(rng.randf_range(-tilt, tilt)), rng.randf() * TAU, deg_to_rad(rng.randf_range(-tilt, tilt))))


func _add_flicker(l: OmniLight3D) -> void:
	var ph := rng.randf() * 100.0
	if A.is_mobile_perf() and GameData.quality == 0:
		l.queue_free()
		return
	if A.is_mobile_perf():
		l.distance_fade_enabled = true
		l.distance_fade_begin = 32.0
		l.distance_fade_length = 8.0
	else:
		l.distance_fade_enabled = true
		l.distance_fade_begin = 58.0
		l.distance_fade_length = 16.0
	flicker_lights.append([l, l.light_energy, ph])


func _fire_barrel(p: Vector3) -> void:
	var n := Node3D.new()
	world.add_child(n)
	n.position = p
	var M_RUST := A.paint(Color(0.32, 0.19, 0.12), 0.45, 0.78, {"wear": 0.65, "rust": 0.85, "grime": 0.8, "panel_scale": 0.0})
	var M_HOOP := A.metal(Color(0.16, 0.16, 0.17))
	A.ground_decal(n, A.blob_tex(), Color(0.05, 0.04, 0.04, 0.72), 2.1, Vector3(0, 0.038, 0))
	A.add(n, A.cyl(0.34, 0.90, 0.34, 16), M_RUST, Vector3(0, 0.45, 0))
	A.add(n, A.cyl(0.31, 0.06, 0.31, 14), A.emit(Color(1.0, 0.38, 0.08), 2.2), Vector3(0, 0.86, 0), Vector3.ZERO, Vector3.ONE, false)
	for hy in [0.06, 0.32, 0.62, 0.88]:
		A.add(n, A.torus(0.325, 0.365, 16), M_HOOP, Vector3(0, hy, 0), Vector3.ZERO, Vector3(1, 0.45, 1), false)
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.3
		A.add(n, A.bevel_box(Vector3(0.09, 0.05, 0.03), 0.005), A.emit(Color(1.0, 0.42, 0.10), 1.8),
			Vector3(cos(a) * 0.342, 0.20, sin(a) * 0.342), Vector3(0, -rad_to_deg(a) + 90.0, 0), Vector3.ONE, false)
	for k in 2:
		A.add(n, A.bevel_box(Vector3(0.08, 0.48, 0.07), 0.01), A.paint(Color(0.18, 0.13, 0.10), 0.0, 0.95),
			Vector3(-0.08 + k * 0.16, 0.88, -0.05 + k * 0.10), Vector3(18 - k * 32, k * 55, -14 + k * 24), Vector3.ONE, false)
	if not (A.is_mobile_perf() and GameData.quality == 0):
		A.emitter(n, Vector3(0, 0.95, 0), {"amount": 22, "life": 0.7, "size": 0.55, "vmin": 0.8, "vmax": 1.8, "gravity": Vector3(0, 2.5, 0),
			"radius": 0.2, "c0": Color(1.0, 0.75, 0.3), "cmid": Color(1.0, 0.35, 0.08), "c1": Color(0.4, 0.05, 0.0, 0.0), "grow0": 1.0, "grow1": 0.2})
		A.emitter(n, Vector3(0, 1.6, 0), {"amount": 10, "life": 3.0, "size": 1.4, "tex": A.smoke_tex(), "additive": false, "vmin": 0.6, "vmax": 1.2,
			"gravity": Vector3(0.4, 0.6, 0.2), "c0": Color(0.15, 0.12, 0.12, 0.5), "c1": Color(0.25, 0.22, 0.22, 0.0), "grow0": 0.6, "grow1": 2.2})
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 2.5
	l.omni_range = 9.0
	l.position = Vector3(0, 1.4, 0)
	n.add_child(l)
	_add_flicker(l)
	blocks.append(Rect2(p.x - 0.6, p.z - 0.6, 1.2, 1.2))


func _build_ground() -> void:
	rng.seed = _map_seed(1)
	var gh := EXT_HALF
	# 地面：物理碰撞覆盖战区包围盒，视觉网格覆盖整个外围连续城市群远景窗口（消除方形地面切边）
	var g := StaticBody3D.new()
	g.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(EXT_HALF * 2.0 + 80.0, 1.0, EXT_HALF * 2.0 + 80.0)
	cs.shape = sh
	cs.position.y = -0.5
	g.add_child(cs)
	var pm := PlaneMesh.new()
	pm.size = Vector2(2400.0, 2400.0)
	A.add(g, pm, A.ground(), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	world.add_child(g)

	# 焦痕 / 油污 / 湿痕：有机地面污渍贴花（仅分布于工业/荒原/废墟带，避免中心城区与住宅广场浮现脏黑糊斑）
	var grime_xfs: Array = []
	for i in 72:
		var p := Vector3(rng.randf_range(-gh, gh), 0.0355, rng.randf_range(-gh, gh))
		if in_wet(Vector2(p.x, p.z), 9.0) or on_road(Vector2(p.x, p.z), 2.5) or zone_at(p) in ["D", "R"]:
			continue
		var sz_g := rng.randf_range(4.0, 9.5)
		var bs_g := Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(sz_g * rng.randf_range(0.75, 1.25), 1.0, sz_g * rng.randf_range(0.65, 1.15)))
		grime_xfs.append(Transform3D(bs_g, p))
	if not grime_xfs.is_empty():
		var grime_c := ground_dust_tint().darkened(0.68)
		_multimesh(A.quad(1.0, 1.0), A.decal_mat(A.grime_stain_tex(), Color(grime_c.r, grime_c.g, grime_c.b, 0.34)), grime_xfs, false)

	# 虫族菌毯：几块不规则的暗色生物膜（仅限战区内部，合批绘制）
	var creep_xfs: Array = []
	for i in 24:
		var c := Vector3(rng.randf_range(-HALF + 8.0, HALF - 8.0), 0, rng.randf_range(-HALF + 8.0, HALF - 8.0))
		if not in_bounds(c, 8.0) or zone_at(c) in ["D", "R", "I", "H", "Y", "P"]:
			continue
		for k in rng.randi_range(3, 5):
			var r := rng.randf_range(1.6, 3.8)
			var p := c + Vector3(rng.randf_range(-4, 4), 0.037 + k * 0.0005, rng.randf_range(-4, 4))
			if in_wet(Vector2(p.x, p.z), r + 5.0) or on_road(Vector2(p.x, p.z), r + 1.5):
				continue
			var sz_c := r * 2.4
			var bs_c := Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(sz_c, 1.0, sz_c * rng.randf_range(0.6, 1.0)))
			creep_xfs.append(Transform3D(bs_c, p))
	if not creep_xfs.is_empty():
		var creep_c := Color(0.14, 0.08, 0.18, 0.38) if map_id == "abyss_maw" else Color(0.16, 0.11, 0.07, 0.32)
		_multimesh(A.quad(1.0, 1.0), A.decal_mat(A.cloud_tex(), creep_c), creep_xfs, false)

	# 碎石、钢筋：MultiMesh 批量绘制（避开道路与硬质铺装街区，只分布在荒地 / 弹坑 / 废墟带）
	var rocks: Array = []
	for i in 1900:
		var p := Vector3(rng.randf_range(-gh, gh), 0, rng.randf_range(-gh, gh))
		var q := Vector2(p.x, p.z)
		if in_wet(q, 4.0) or on_road(q, 2.2) or (zone_at(p) in ["D", "R", "I", "H", "Y", "A"] and rng.randf() > 0.05):
			continue
		var sc := rng.randf_range(0.10, 0.32)
		var t := Transform3D(_rand_basis(30).scaled_local(Vector3(sc * rng.randf_range(0.7, 1.5), sc * rng.randf_range(0.5, 0.9), sc)), p + Vector3(0, sc * 0.05, 0))
		rocks.append(t)
	_multimesh(A.rock_mesh(0), A.concrete(Color(0.55, 0.5, 0.46), false), rocks)
	var rebars: Array = []
	for i in 240:
		var p := Vector3(rng.randf_range(-HALF, HALF), 0.16, rng.randf_range(-HALF, HALF))
		var q := Vector2(p.x, p.z)
		if not in_bounds_xz(q, 2.0) or in_wet(q, 4.0) or on_road(q, 2.8) or not (zone_at(p) in ["C", "W", "S", "K"]):
			continue
		rebars.append(Transform3D(_rand_basis(50).scaled_local(Vector3(1, rng.randf_range(0.6, 1.4), 1)), p))
	_multimesh(A.cyl(0.03, 1.2, 0.03, 8), A.paint(Color(0.35, 0.18, 0.1), 0.5, 0.8), rebars, false)

	# 荒地草丛：带透贴草叶与草穗的三维交叉草簇（MultiMesh，不投影）
	var GRASS := A.foliage_mat("grass")
	var tufts: Array = []
	for c in 680:
		var cc := Vector3(rng.randf_range(-gh, gh), 0, rng.randf_range(-gh, gh))
		var zt := zone_at(cc)
		if zt in ["D", "I", "Y", "H", "K", "S", "A"] or (zt == "R" and rng.randf() < 0.5) or in_wet(Vector2(cc.x, cc.z), 5.0) or on_road(Vector2(cc.x, cc.z), 1.5):
			continue
		var cr := rng.randf_range(1.5, 5.0) * (1.6 if zt == "P" or zt == "T" else 1.0)
		for k in rng.randi_range(8, 20):
			var a := rng.randf() * TAU
			var rr := sqrt(rng.randf()) * cr
			var p := cc + Vector3(cos(a) * rr, 0, sin(a) * rr)
			if in_wet(Vector2(p.x, p.z), 3.5) or on_road(Vector2(p.x, p.z), 1.2):
				continue
			var hgt := rng.randf_range(0.32, 0.68)
			var w_sc := hgt * rng.randf_range(1.12, 1.48)
			var bs := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-6, 6)))
			tufts.append(Transform3D(bs.scaled_local(Vector3(w_sc, hgt, w_sc)), p))
	_multimesh(A.grass_clump_mesh(), GRASS, tufts, false)
	# 小碎石：细碎石子（避开道路与城区铺装）
	var pebbles: Array = []
	for i in 5200:
		var p := Vector3(rng.randf_range(-gh, gh), 0, rng.randf_range(-gh, gh))
		var q := Vector2(p.x, p.z)
		if in_wet(q, 4.0) or on_road(q, 2.0) or (zone_at(p) in ["D", "R", "I", "H", "Y", "A"] and rng.randf() > 0.10):
			continue
		var sc := rng.randf_range(0.05, 0.15)
		pebbles.append(Transform3D(_rand_basis(60).scaled_local(Vector3(sc * rng.randf_range(0.8, 1.5), sc * 0.6, sc)), p + Vector3(0, sc * 0.2, 0)))
	_multimesh(A.rock_mesh(2), A.rock_mat(Color(0.46, 0.42, 0.36)), pebbles, false)

	# 不规则战区封控周界（取代旧版四面方形围岩：依道路/水系/城区/断崖地貌构建重工业防爆隔离墙、公路拒马封锁卡口、航道防撞钢桩与自然断崖；地下竖井构建不规则黑曜岩洞窟壁）
	_build_perimeter()


func _build_perimeter() -> void:
	if is_surface_map:
		# 地表战区不再生成战区封锁围栏：仅在无建模外沿处布置不可见空气墙，避免机甲走出已建图范围
		var air_wall := StaticBody3D.new()
		air_wall.name = "MapEdgeAirWall"
		air_wall.collision_layer = 1
		air_wall.set_meta("water_bank", true)
		var edge_d := EXT_HALF - 2.0
		var span_l := EXT_HALF * 2.0 + 8.0
		for sd: float in [-1.0, 1.0]:
			var cs_z := CollisionShape3D.new()
			var sh_z := BoxShape3D.new()
			sh_z.size = Vector3(span_l, 18.0, 4.0)
			cs_z.shape = sh_z
			cs_z.position = Vector3(0.0, 8.0, sd * edge_d)
			air_wall.add_child(cs_z)
			var cs_x := CollisionShape3D.new()
			var sh_x := BoxShape3D.new()
			sh_x.size = Vector3(4.0, 18.0, span_l)
			cs_x.shape = sh_x
			cs_x.position = Vector3(sd * edge_d, 8.0, 0.0)
			air_wall.add_child(cs_x)
		world.add_child(air_wall)
		return
	if zone_poly.size() < 3:
		return
	var prev_enf := _enforce_zone_bounds
	_enforce_zone_bounds = false
	var gate_list: Array = []
	for edge_key: String in WorldLinkScript.LINKS.get(map_id, {}):
		gate_list.append(WC.gate_info(map_id, edge_key))
	var M_CON := A.concrete(Color(0.45, 0.43, 0.40), false)
	var M_CON_DRK := A.concrete(Color(0.32, 0.30, 0.28), false)
	var M_STEEL := A.paint(Color(0.22, 0.23, 0.25), 0.62, 0.56, {"rust": 0.68, "wear": 0.58, "panel_scale": 1.1})
	var M_RUST := A.paint(Color(0.34, 0.21, 0.15), 0.48, 0.68, {"rust": 0.86, "wear": 0.62, "panel_scale": 0.9})
	var M_DARK := A.metal(Color(0.14, 0.15, 0.16))
	var M_HAZ := A.hazard()
	var M_ROCK_SURF := A.rock_mat(Color(0.38, 0.33, 0.28))
	var M_ROCK_DARK := A.rock_mat(Color(0.22, 0.19, 0.21))
	var M_OBSID := A.rock_mat(Color(0.14, 0.13, 0.16))
	var poly_ccw := WC.poly_area_signed(zone_poly) > 0.0
	var m := zone_poly.size()
	var rock_tfs: Array = []
	var dark_rock_tfs: Array = []
	var beam_tfs: Array = []
	for i in m:
		var a := zone_poly[i]
		var b := zone_poly[(i + 1) % m]
		var seg_len := a.distance_to(b)
		if seg_len < 1.0:
			continue
		var dir := (b - a) / seg_len
		var inw := Vector2(-dir.y, dir.x) if poly_ccw else Vector2(dir.y, -dir.x)
		var outw := -inw
		var yaw := atan2(inw.x, inw.y)   # 本地 +z 朝战区内侧，本地 +x 沿边界切向
		# 物理阻挡：按连续无转场口区间合并成单段长盒碰撞体，坐标落在周界上并打上保护标记
		var spans: Array = [[0.0, seg_len]]
		for gi: Dictionary in gate_list:
			var gp_rel: Vector2 = (gi.pos as Vector2) - a
			var perp_d := absf(gp_rel.dot(inw))
			if perp_d < 8.0 and absf(dir.dot(gi.tangent as Vector2)) > 0.85:
				var gs := gp_rel.dot(dir)
				var gh := WorldLinkScript.HALF_SPAN + 2.8
				var nxt_sp: Array = []
				for sp: Array in spans:
					var s0: float = sp[0]
					var s1: float = sp[1]
					if gs + gh <= s0 or gs - gh >= s1:
						nxt_sp.append(sp)
					else:
						if gs - gh > s0 + 0.5:
							nxt_sp.append([s0, gs - gh])
						if s1 > gs + gh + 0.5:
							nxt_sp.append([gs + gh, s1])
				spans = nxt_sp
		for sp: Array in spans:
			var sp_len: float = float(sp[1]) - float(sp[0])
			if sp_len < 0.4:
				continue
			var sp_mid: Vector2 = a + dir * ((float(sp[0]) + float(sp[1])) * 0.5) + outw * 1.6
			var eb := StaticBody3D.new()
			eb.collision_layer = 1
			eb.set_meta("water_bank", true)
			eb.position = Vector3(sp_mid.x, 7.0, sp_mid.y)
			eb.rotation.y = yaw
			var csh := CollisionShape3D.new()
			var bsh := BoxShape3D.new()
			bsh.size = Vector3(sp_len + 1.0, 14.0, 3.4)
			csh.shape = bsh
			eb.add_child(csh)
			world.add_child(eb)
			_obb_blocks(sp_mid, atan2(dir.y, dir.x), sp_len + 0.8, 3.2)

		var step := 7.6 if is_surface_map else 8.5
		var n_sub := maxi(1, int(roundf(seg_len / step)))
		var sub_w := seg_len / float(n_sub)
		for k in n_sub:
			var s_mid := (float(k) + 0.5) * sub_w
			var mid := a + dir * s_mid
			var in_gate := false
			for gi: Dictionary in gate_list:
				var rel: Vector2 = mid - (gi.pos as Vector2)
				if absf(rel.dot(gi.inward as Vector2)) < 8.0 and absf(rel.dot(gi.tangent as Vector2)) < WorldLinkScript.HALF_SPAN + 2.8:
					in_gate = true
					break
			if in_gate:
				continue

			if not is_surface_map:
				# 地下超深竖井：外围黑曜岩绝壁与深渊火山口岩墙由 MountainTerrain 连续雕刻
				continue

			# 地表战区：按所跨地貌生成写实重工业封控设施或自然地貌屏障
			var zt := zone_at(Vector3(mid.x, 0.0, mid.y))
			var wet_here := in_wet(mid, 1.2)
			var road_here := on_road(mid, 2.8)
			var rail_here := false
			for rl: PackedVector2Array in rail_polys:
				if WC.poly_dist(rl, mid) < 3.5:
					rail_here = true
					break
			var seg_node := Node3D.new()
			world.add_child(seg_node)
			seg_node.position = Vector3(mid.x + outw.x * 1.1, 0.0, mid.y + outw.y * 1.1)
			seg_node.rotation.y = yaw
			if wet_here:
				# 跨河/湖封控：战损版河防浮箱闸垒与岗哨灯塔（env_perimeter_pontoon）
				PrefabLib.place_at_ground(self, seg_node, "env_perimeter_pontoon", Vector3(0.0, -0.35, 0.0), 0.0, Vector3(sub_w + 0.8, 7.2, 5.0), false, null, false)
			elif road_here or rail_here:
				# 跨主干道/街巷/铁路封控卡口：预制防爆T型混凝土矮墩 + 重型工字钢反机甲拒马 + 横置封路集装箱/残骸（保留远景街道通透视线！）
				for bx_s in [-sub_w * 0.34, sub_w * 0.34]:
					A.add(seg_node, A.bevel_box(Vector3(sub_w * 0.44, 2.35, 0.72), 0.04), M_CON, Vector3(bx_s, 1.18, -0.35))
					A.add(seg_node, A.bevel_box(Vector3(sub_w * 0.46, 0.42, 1.25), 0.03), M_CON_DRK, Vector3(bx_s, 0.21, -0.35))
					A.add(seg_node, A.bevel_box(Vector3(sub_w * 0.40, 0.18, 0.76), 0.01), M_HAZ, Vector3(bx_s, 1.95, -0.35), Vector3.ZERO, Vector3.ONE, false)
				# 中央交错工字钢反装甲拒马（Czech Hedgehog）
				for hx_s in [-1.15, 1.15]:
					var hg := Node3D.new()
					seg_node.add_child(hg)
					hg.position = Vector3(hx_s, 0.92, 0.75)
					hg.rotation_degrees = Vector3(0, rng.randf_range(-18, 18), 0)
					A.add(hg, A.bevel_box(Vector3(0.18, 2.35, 0.18), 0.02), M_RUST, Vector3(-0.025, 0, 0), Vector3(38, 0, 35))
					A.add(hg, A.bevel_box(Vector3(0.18, 2.35, 0.18), 0.02), M_RUST, Vector3(0.025, 0, 0), Vector3(-38, 0, 35))
					A.add(hg, A.bevel_box(Vector3(0.18, 2.35, 0.18), 0.02), M_STEEL, Vector3(0, 0, 0.025), Vector3(0, 42, -52))
				if rng.randf() < 0.45 and sub_w >= 6.4:
					_container(Vector3(mid.x + outw.x * 2.8, 0.0, mid.y + outw.y * 2.8), rad_to_deg(yaw) + rng.randf_range(-14.0, 14.0), Color(0.36, 0.26, 0.20))
			elif zt in ["D", "R", "I", "H", "Y", "M"]:
				# 城区/工业带隔离墙：4.8~6.0m 预制钢筋混凝土防爆封控墙 + 斜撑肋柱 + 局部战损缺口碎石堆（背后紧邻外围城区高楼群）
				var wh := rng.randf_range(4.6, 5.8)
				A.add(seg_node, A.bevel_box(Vector3(sub_w + 0.12, 0.65, 1.48), 0.04), M_CON_DRK, Vector3(0.0, 0.325, 0.0))
				if rng.randf() < 0.22:
					# 炮击坍塌段：半截残墙 + 外露钢筋 + 大堆混凝土碎块封堵
					A.add(seg_node, A.bevel_box(Vector3(sub_w * 0.96, wh * 0.52, 0.86), 0.05), M_CON, Vector3(0.0, wh * 0.26 + 0.4, 0.0))
					var r_sc := sub_w * 0.44
					rock_tfs.append(Transform3D((Basis(Vector3.UP, yaw + 0.4)).scaled_local(Vector3(r_sc, wh * 0.38, 2.2)), Vector3(mid.x + outw.x * 0.8, wh * 0.22, mid.y + outw.y * 0.8)))
				else:
					A.add(seg_node, A.bevel_box(Vector3(sub_w - 0.08, wh, 0.82), 0.04), M_CON, Vector3(0.0, wh * 0.5 + 0.35, 0.0))
					A.add(seg_node, A.bevel_box(Vector3(sub_w + 0.06, 0.24, 1.06), 0.02), M_CON_DRK, Vector3(0.0, wh + 0.42, 0.0))
					A.add(seg_node, A.bevel_box(Vector3(sub_w - 0.06, 0.14, 0.58), 0.01), M_HAZ, Vector3(0.0, wh + 0.56, 0.0), Vector3.ZERO, Vector3.ONE, false)
				for rx_s in [-sub_w * 0.48, sub_w * 0.48]:
					A.add(seg_node, A.bevel_box(Vector3(0.36, wh + 0.35, 1.32), 0.03), M_STEEL, Vector3(rx_s, (wh + 0.35) * 0.5, 0.08))
			elif zt == "K":
				# K 区断崖由连续山体地形 MountainTerrain 统一雕刻，这里不再堆叠旧球形岩块
				pass
			elif zt in ["C", "S"]:
				# 弹坑/裂隙周界：层叠崩塌矿渣岩堆
				var rh := rng.randf_range(4.2, 7.6)
				var rp := mid + outw * rng.randf_range(1.6, 3.2)
				var rbs := Basis(Vector3.UP, yaw + rng.randf_range(-0.4, 0.4)) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-6, 6)))
				rock_tfs.append(Transform3D(rbs.scaled_local(Vector3(sub_w * 0.62, rh * 0.48, rng.randf_range(3.0, 4.8))), Vector3(rp.x, rh * 0.24, rp.y)))
			else:
				# 郊野/农田/林地/湿地周界：反装甲混凝土龙牙墩阵 + 土石防洪堤埂 + 黄黑封锁横梁（保持外环高速与远郊视野开阔）
				A.add(seg_node, A.bevel_box(Vector3(sub_w + 0.4, 1.35, 2.6), 0.28, 0.72), M_ROCK_SURF, Vector3(0.0, 0.55, -0.3))
				for dx_s in [-sub_w * 0.32, 0.0, sub_w * 0.32]:
					A.add(seg_node, A.cyl(0.32, 1.65, 0.78, 4, true), M_CON, Vector3(dx_s, 1.15, 0.25), Vector3(0, 45, 0))
				A.add(seg_node, A.bevel_box(Vector3(sub_w + 0.1, 0.18, 0.34), 0.01), M_HAZ, Vector3(0.0, 1.92, -0.25), Vector3.ZERO, Vector3.ONE, false)
				if zt == "T" and rng.randf() < 0.55:
					var rp2 := mid + outw * 2.2
					rock_tfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(sub_w * 0.52, rng.randf_range(2.2, 4.2), 2.6)), Vector3(rp2.x, 1.4, rp2.y)))

	# 地下竖井外围高台岩层已移交 MountainTerrain 连续火山口岩壁地形统一雕刻
	_multimesh(A.rock_mesh(4), M_ROCK_SURF if is_surface_map else M_ROCK_DARK, rock_tfs)
	_multimesh(A.rock_mesh(7), M_OBSID, dark_rock_tfs)
	_multimesh(A.bevel_box(Vector3.ONE, 0.03), M_STEEL, beam_tfs)
	_enforce_zone_bounds = prev_enf


func _bug_spire(p: Vector3, h: float) -> void:
	# 地下自动化熔铸区废土排烟导热桩：玄武矿渣乱石丘 + 倾斜铸铁烟管（高细分圆筒 + 弯折旁通管）+ 暗沉余烬百叶孔 + 淡煤烟
	var n := Node3D.new()
	world.add_child(n)
	n.position = p
	n.rotation_degrees = Vector3(rng.randf_range(-5, 5), rng.randf() * 360.0, rng.randf_range(-5, 5))
	var r0 := rng.randf_range(0.56, 0.96)
	var M_SLAG := A.rock_mat(Color(0.19, 0.16, 0.14))
	var M_IRON := A.paint(Color(0.20, 0.21, 0.22), 0.66, 0.58, {"rust": 0.74, "wear": 0.60, "grime": 0.88, "panel_scale": 0.9})
	var M_RUST := A.paint(Color(0.32, 0.19, 0.12), 0.50, 0.70, {"rust": 0.88, "wear": 0.64, "grime": 0.84})
	var M_DARK := A.metal(Color(0.11, 0.12, 0.13))
	var m_ember := A.emit(Color(0.78, 0.30, 0.07), 0.85)
	m_ember.albedo_color = Color(0.24, 0.08, 0.02)
	# 玄武矿渣乱石基底群，取代规整八边形锥台
	for k in 4:
		var a := TAU * float(k) / 4.0 + rng.randf_range(-0.25, 0.25)
		var sc := r0 * rng.randf_range(0.68, 0.95)
		A.add(n, A.rock_mesh((k * 5 + 2) % 12), M_SLAG,
			Vector3(cos(a) * r0 * 0.62, sc * 0.28, sin(a) * r0 * 0.62),
			Vector3(rng.randf_range(-10, 10), k * 78.0, rng.randf_range(-10, 10)),
			Vector3(sc * 1.15, sc * 0.65, sc * 0.95))
	# 微倾多段圆滑铸铁排烟管与螺栓法兰箍（18段细分无机械八棱折角）
	var stack := Node3D.new()
	stack.rotation_degrees = Vector3(rng.randf_range(5.0, 11.0), 0.0, rng.randf_range(-6.0, 6.0))
	n.add_child(stack)
	var pipe_r := r0 * 0.54
	var rem_h := maxf(2.0, h - 0.15)
	var y := 0.20
	var segs := 3
	for i in segs:
		var sh := rem_h / float(segs)
		var ra := pipe_r * (1.0 - float(i) * 0.14)
		var rb := pipe_r * (1.0 - float(i + 1) * 0.15)
		A.add(stack, A.cyl(rb, sh, ra, 18), M_IRON if i % 2 == 0 else M_RUST, Vector3(0, y + sh * 0.5, 0))
		A.add(stack, A.cyl(rb * 1.10, 0.09, rb * 1.10, 18), M_DARK, Vector3(0, y + sh - 0.03, 0))
		y += sh
	# 顶部斜切铸铁防雨排烟帽 + 暗黑烟道内膛
	A.add(stack, A.cyl(pipe_r * 0.44, 0.16, pipe_r * 0.48, 16), A.paint(Color(0.03, 0.03, 0.03), 0.0, 0.95), Vector3(0, y - 0.02, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(stack, A.cyl(pipe_r * 0.72, 0.07, pipe_r * 0.78, 16), M_DARK, Vector3(0.06, y + 0.18, 0), Vector3(0, 0, -14.0))
	# 内嵌格栅微光余烬缝（深暗琥珀点，无突出橙色方块）
	for s_i in 3:
		var sa := TAU * float(s_i) / 3.0 + 0.5
		var slot_r := pipe_r * 0.94
		var slp := Vector3(cos(sa) * slot_r, 0.62 + float(s_i % 2) * 0.34, sin(sa) * slot_r)
		var syaw := -rad_to_deg(sa) + 90.0
		A.add(stack, A.cyl(0.055, 0.04, 0.055, 10), m_ember, slp, Vector3(90.0, syaw, 0.0), Vector3.ONE, false)
		A.add(stack, A.cyl(0.09, 0.06, 0.09, 10), M_DARK, slp * 0.98, Vector3(90.0, syaw, 0.0))
	# 弯曲旁通泄压铁管
	var bypass := [Vector3(r0 * 0.85, 0.25, 0.18), Vector3(r0 * 0.88, minf(rem_h * 0.45, 1.4), 0.22), Vector3(pipe_r * 0.78, minf(rem_h * 0.62, 1.85), 0.08)]
	A.add(stack, A.pipe(bypass, 0.075, 10, 6), M_RUST)
	A.ground_decal(n, A.grime_stain_tex(), Color(0.07, 0.06, 0.05, 0.68), r0 * 3.4, Vector3(0, 0.036, 0))
	if h >= 4.2:
		A.emitter(stack, Vector3(0, y + 0.06, 0), {"tex": A.smoke_tex(), "additive": false, "soft_depth": 0.45, "amount": 5, "life": 2.6, "size": 0.95,
			"dir": Vector3(0.22, 1.0, 0.14).normalized(), "spread": 16.0, "vmin": 0.5, "vmax": 1.1, "gravity": Vector3(0.1, 0.2, 0.05),
			"c0": Color(0.16, 0.15, 0.14, 0.22), "c1": Color(0.20, 0.19, 0.18, 0.0), "grow0": 0.4, "grow1": 2.1, "radius": 0.12})
	blocks.append(Rect2(p.x - r0, p.z - r0, r0 * 2, r0 * 2))


func _rect_for(center: Vector3, size: Vector3) -> Rect2:
	return Rect2(center.x - size.x * 0.5, center.z - size.z * 0.5, size.x, size.z)


## 占地查询：blocks 按 12 米格子分桶（外部脚本直接往 blocks 里追加也会在下次查询时补进索引）
const _BK := 12.0
var _bk := {}
var _bk_n := 0


func _bk_sync() -> void:
	if blocks.size() < _bk_n:
		_bk.clear()
		_bk_n = 0
	while _bk_n < blocks.size():
		var b: Rect2 = blocks[_bk_n]
		for gx in range(floori(b.position.x / _BK), floori(b.end.x / _BK) + 1):
			for gz in range(floori(b.position.y / _BK), floori(b.end.y / _BK) + 1):
				var key := Vector2i(gx, gz)
				if _bk.has(key):
					_bk[key].append(_bk_n)
				else:
					_bk[key] = PackedInt32Array([_bk_n])
		_bk_n += 1


## 地图生成摆杂物期间要留空的区域：转场口通道、地标原位（Rect2 / Vector3(x, z, r)）
var _keep_clear: Array = []


## 是否压到留空区（只查 _keep_clear，不查已有占地）。线状杂物（院墙、围栏、防爆墙）按整段长度查，
## 免得只查中心点时长墙的一端伸进地标原位
func _in_keep_clear(p: Vector3, r: float) -> bool:
	if _keep_clear.is_empty():
		return false
	var pr := Rect2(p.x - r, p.z - r, r * 2, r * 2)
	for kc in _keep_clear:
		if kc is Rect2:
			if (kc as Rect2).intersects(pr):
				return true
		elif Vector2(p.x, p.z).distance_to(Vector2(kc.x, kc.y)) < kc.z + r:
			return true
	return false


func _blocked(p: Vector3, r: float, terrain := true) -> bool:
	if _enforce_zone_bounds and not in_bounds(p, r + 3.0):
		return true
	_bk_sync()
	if _in_keep_clear(p, r):
		return true
	var probe := Rect2(p.x - r, p.z - r, r * 2, r * 2)
	for gx in range(floori(probe.position.x / _BK), floori(probe.end.x / _BK) + 1):
		for gz in range(floori(probe.position.y / _BK), floori(probe.end.y / _BK) + 1):
			var lst = _bk.get(Vector2i(gx, gz))
			if lst == null:
				continue
			for i: int in lst:
				if blocks[i].intersects(probe):
					return true
	var q := Vector2(p.x, p.z)
	# 有水的河湖（含护堤）任何时候都不能摆东西；terrain = false 只是允许压在路面上
	if in_wet(q, r + 1.0):
		return true
	if terrain:
		if on_road(q, r - 0.5) or in_river(q, r + 2.0):
			return true
	return false


func _free_spot(r: float, margin := 6.0) -> Vector3:
	for i in 260:
		var p := Vector3(rng.randf_range(-HALF + margin, HALF - margin), 0, rng.randf_range(-HALF + margin, HALF - margin))
		if in_bounds(p, margin) and not _blocked(p, r):
			return p
	return Vector3.ZERO


func _poi_lamp(p: Vector3, c := Color(1.0, 0.8, 0.5)) -> void:
	var n := Node3D.new()
	world.add_child(n)
	n.position = p
	var M_POLE := A.paint(Color(0.24, 0.26, 0.27), 0.55, 0.58, {"wear": 0.5, "rust": 0.55, "panel_scale": 0.0})
	var M_DARK := A.metal(Color(0.14, 0.15, 0.16))
	A.add(n, A.bevel_box(Vector3(0.56, 0.32, 0.56), 0.04), A.concrete(Color(0.46, 0.44, 0.41), false), Vector3(0, 0.16, 0))
	A.add(n, A.cyl(0.16, 0.12, 0.20, 20), M_DARK, Vector3(0, 0.36, 0))
	A.add(n, A.cyl(0.065, 4.1, 0.115, 20), M_POLE, Vector3(0, 2.38, 0))
	A.add(n, A.bevel_box(Vector3(0.22, 0.38, 0.18), 0.02), M_DARK, Vector3(-0.10, 1.25, 0))
	A.add(n, A.bevel_box(Vector3(1.05, 0.08, 0.10), 0.015), M_POLE, Vector3(0.46, 4.36, 0), Vector3(0, 0, -6))
	A.add(n, A.bevel_box(Vector3(0.72, 0.05, 0.06), 0.01), M_DARK, Vector3(0.32, 4.02, 0), Vector3(0, 0, 34))
	A.add(n, A.bevel_box(Vector3(0.62, 0.14, 0.36), 0.03), M_DARK, Vector3(0.82, 4.30, 0), Vector3(0, 0, -8))
	A.add(n, A.bevel_box(Vector3(0.50, 0.045, 0.26), 0.008), A.emit(c, 4.6), Vector3(0.83, 4.22, 0), Vector3(0, 0, -8), Vector3.ONE, false)
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 2.2
	l.omni_range = 11.0
	l.position = Vector3(0.8, 3.85, 0)
	n.add_child(l)
	_add_flicker(l)


func _container(p: Vector3, rot: float, c: Color) -> void:
	var M_BODY := A.corrugated(c, 0.52, 0.38)
	var M_RIB := A.corrugated(c.darkened(0.22), 0.55, 0.38)
	var M_FRM := A.metal(Color(0.18, 0.19, 0.20))
	var M_SEAL := A.paint(Color(0.05, 0.05, 0.055), 0.05, 0.9)
	var sb := _static_box(Vector3(2.4, 2.4, 6.0), p + Vector3(0, 1.2, 0), c, null, M_BODY)
	sb.rotation_degrees.y = rot
	# 侧面波纹加强肋 + 顶板横向加强筋
	for i in 8:
		var zf := -2.45 + i * 0.70
		_ibox(sb, Vector3(2.48, 2.12, 0.13), 0.02, M_RIB, Vector3(0, 0, zf), Vector3.ZERO, Vector3.ONE, false)
		_ibox(sb, Vector3(2.26, 0.06, 0.13), 0.01, M_RIB, Vector3(0, 1.21, zf), Vector3.ZERO, Vector3.ONE, false)
	# 上下框架边梁、四角立柱 + 8 颗标准 ISO 角件铸块 + 底部叉车插槽
	for sy in [-1.14, 1.14]:
		_ibox(sb, Vector3(2.50, 0.14, 6.06), 0.02, M_FRM, Vector3(0, sy, 0), Vector3.ZERO, Vector3.ONE, false)
	for sx_c in [-1.17, 1.17]:
		for sz_c in [-2.96, 2.96]:
			_ibox(sb, Vector3(0.16, 2.04, 0.16), 0.01, M_FRM, Vector3(sx_c, 0.0, sz_c), Vector3.ZERO, Vector3.ONE, false)
			for sy_c in [-1.14, 1.14]:
				_ibox(sb, Vector3(0.23, 0.22, 0.23), 0.015, M_FRM, Vector3(sx_c, sy_c, sz_c), Vector3.ZERO, Vector3.ONE, false)
	for fz in [-0.95, 0.95]:
		_ibox(sb, Vector3(2.52, 0.11, 0.34), 0.01, M_SEAL, Vector3(0, -1.13, fz), Vector3.ZERO, Vector3.ONE, false)
	# 尾门双扇胶条密封门板 + 四道镀铬门闩锁杆、凸轮锁座与把手 + 前壁百叶通风窗
	_ibox(sb, Vector3(2.22, 2.16, 0.04), 0.01, M_SEAL, Vector3(0, 0.0, 3.00), Vector3.ZERO, Vector3.ONE, false)
	for sx in [-0.55, 0.55]:
		_ibox(sb, Vector3(1.02, 2.06, 0.06), 0.02, M_RIB, Vector3(sx, 0.0, 3.02), Vector3.ZERO, Vector3.ONE, false)
	for lx in [-0.82, -0.28, 0.28, 0.82]:
		_imesh(sb, A.cyl(0.022, 2.10, 0.022, 6), A.chrome(), Vector3(lx, 0.0, 3.065), Vector3.ZERO, Vector3.ONE, false)
		for ky in [-0.96, 0.96]:
			_ibox(sb, Vector3(0.08, 0.10, 0.07), 0.01, M_FRM, Vector3(lx, ky, 3.06), Vector3.ZERO, Vector3.ONE, false)
		_ibox(sb, Vector3(0.16, 0.05, 0.06), 0.008, M_FRM, Vector3(lx + 0.06, -0.18, 3.08), Vector3.ZERO, Vector3.ONE, false)
	for vx in [-0.72, 0.72]:
		_ibox(sb, Vector3(0.32, 0.42, 0.06), 0.01, M_FRM, Vector3(vx, 0.62, -3.02), Vector3.ZERO, Vector3.ONE, false)
	_ibox(sb, Vector3(2.49, 0.18, 1.40), 0.02, A.hazard(), Vector3(0, -0.96, 2.28), Vector3.ZERO, Vector3.ONE, false)
	if p.y < 0.5:
		add_contact_shadow(p, 3.6, 7.2, rot)


## 遗迹 POI：类型来自 GameData.POIS（核心三类 + 扩展）。核心类型与 compound = true 的扩展类型建标准围墙院落；
## 扩展类型的 script 负责中央布景（compound = false 时整个 POI 由它负责）。
func _build_pois(sliced := false) -> void:
	rng.seed = _map_seed(7)
	for idx in poi_centers.size():
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		var pid: String = poi_ids[idx]
		var pinfo: Dictionary = GameData.POIS.get(pid, {})
		var n: String = str(pinfo.get("name", pid))
		var c: Vector3 = poi_centers[idx]
		var pscript: String = str(pinfo.get("script", ""))
		if pscript != "" and not bool(pinfo.get("compound", false)):
			load(pscript).build(self, c, pid)
			continue
		var s := 9.0
		var wall_c := Color(0.6, 0.57, 0.52)
		# 地坪
		A.add(world, A.bevel_box(Vector3(s * 2 - 0.5, 0.12, s * 2 - 0.5), 0.05), A.concrete(Color(0.48, 0.46, 0.44)), c + Vector3(0, 0.06, 0), Vector3.ZERO, Vector3.ONE, false)
		# 四面墙，每面留缺口；墙顶参差不齐 + 外部扶壁柱与断口锈蚀钢筋
		var M_REBAR := A.paint(Color(0.30, 0.16, 0.09), 0.55, 0.72, {"rust": 0.92, "wear": 0.6})
		for side in 4:
			for half in [-1, 1]:
				var seg := 3.4
				var off: float = half * (s - seg)
				var hgt := rng.randf_range(2.4, 3.6)
				var size: Vector3
				var pos: Vector3
				match side:
					0: size = Vector3(seg * 2, hgt, 0.8); pos = Vector3(off, hgt * 0.5, -s)
					1: size = Vector3(seg * 2, hgt, 0.8); pos = Vector3(off, hgt * 0.5, s)
					2: size = Vector3(0.8, hgt, seg * 2); pos = Vector3(-s, hgt * 0.5, off)
					3: size = Vector3(0.8, hgt, seg * 2); pos = Vector3(s, hgt * 0.5, off)
				var wc_d := wall_c.darkened(rng.randf() * 0.2)
				var wall := _static_box(size, c + pos, wc_d)
				# 墙头残块 + 断口外露钢筋 + 扶壁柱与勒脚
				for k in 2:
					var chunk := Vector3(rng.randf_range(0.8, 2.0), rng.randf_range(0.4, 1.1), 0.82)
					if side >= 2:
						chunk = Vector3(0.82, chunk.y, chunk.x)
					var cp := Vector3(rng.randf_range(-2, 2), hgt * 0.5 + chunk.y * 0.5, 0) if side < 2 else Vector3(0, hgt * 0.5 + chunk.y * 0.5, rng.randf_range(-2, 2))
					_ibox(wall, chunk, 0.06, A.concrete(wall_c.darkened(0.1)), cp)
				for rb_i in 3:
					var ro := rng.randf_range(-2.2, 2.2)
					var rpos := Vector3(ro, hgt * 0.5 + 0.22, rng.randf_range(-0.14, 0.14)) if side < 2 else Vector3(rng.randf_range(-0.14, 0.14), hgt * 0.5 + 0.22, ro)
					_imesh(wall, A.cyl(0.022, rng.randf_range(0.38, 0.68), 0.022, 6), M_REBAR, rpos, Vector3(rng.randf_range(-22, 22), 0, rng.randf_range(-22, 22)), Vector3.ONE, false)
				for pr in [-1.8, 1.8]:
					var p_sz := Vector3(0.42, hgt * 0.92, 1.06) if side < 2 else Vector3(1.06, hgt * 0.92, 0.42)
					var p_ps := Vector3(pr, -hgt * 0.04, 0) if side < 2 else Vector3(0, -hgt * 0.04, pr)
					_ibox(wall, p_sz, 0.03, A.concrete(wc_d.darkened(0.12), false), p_ps)
				_ibox(wall, Vector3(size.x + 0.10, 0.30, size.z + 0.10), 0.04, A.concrete(wall_c.darkened(0.35), false), Vector3(0, -hgt * 0.5 + 0.15, 0))
				blocks.append(_rect_for(c + pos, size))
		blocks.append(Rect2(c.x - s + 1, c.z - s + 1, s * 2 - 2, s * 2 - 2))
		if pscript != "":
			load(pscript).build(self, c, pid)
		elif pid == "egret_wreck":
			_crashed_ship(c)
		elif pid == "depot7":
			_container(c + Vector3(-3.5, 0, 2.5), 90, Color(0.25, 0.38, 0.5))
			_container(c + Vector3(-3.2, 2.48, 2.4), 84, Color(0.62, 0.3, 0.18))
			blocks.append(Rect2(c.x - 6.5, c.z + 1.2, 6.5, 2.6))
		else:
			# 研究所：高精度圆形穹顶建筑（阶梯混凝土环基 + 圆柱裙墙 + 金属分格主穹顶 + 经纬向钢结构拱肋 + 侧翼气闸舱门 + 顶部雷达桅杆）
			var dome := StaticBody3D.new()
			var dcs := CollisionShape3D.new()
			var dsh := CylinderShape3D.new()
			dsh.radius = 2.8
			dsh.height = 3.4
			dcs.shape = dsh
			dcs.position.y = 1.7
			dome.add_child(dcs)
			world.add_child(dome)
			dome.position = c + Vector3(-3, 0, 3)
			var M_CONC := A.concrete(Color(0.5, 0.5, 0.48))
			var M_RIB := A.metal(Color(0.32, 0.34, 0.36))
			var M_DOME := A.paint(Color(0.58, 0.6, 0.62), 0.35, 0.48, {"panel_scale": 0.45, "wear": 0.45, "rust": 0.5, "dust": 0.3})
			A.add(dome, A.cyl(3.15, 0.28, 3.3, 42), A.concrete(Color(0.42, 0.42, 0.4)), Vector3(0, 0.14, 0))
			A.add(dome, A.cyl(2.75, 1.45, 2.88, 42), M_CONC, Vector3(0, 0.82, 0))
			A.add(dome, A.torus(2.68, 2.94, 42), M_RIB, Vector3(0, 1.48, 0), Vector3.ZERO, Vector3(1, 0.55, 1))
			A.add(dome, A.sphere(2.65, 2.7, 42), M_DOME, Vector3(0, 1.45, 0), Vector3(8, 0, 5))
			# 经向与纬向外部钢结构拱肋 + 环壁观察窗与扶壁柱
			for k in 4:
				A.add(dome, A.torus(2.58, 2.72, 40), M_RIB, Vector3(0, 1.45, 0), Vector3(90, k * 45.0, 0), Vector3(1, 1, 0.55), false)
			for k in 8:
				var da := TAU * k / 8.0
				A.add(dome, A.bevel_box(Vector3(0.28, 1.38, 0.32), 0.03), M_RIB, Vector3(cos(da) * 2.78, 0.8, sin(da) * 2.78), Vector3(0, rad_to_deg(-da), 0))
			# 正侧装甲气闸门厅
			A.add(dome, A.bevel_box(Vector3(1.5, 1.55, 1.2), 0.05), M_CONC, Vector3(0, 0.78, 2.75))
			A.add(dome, A.bevel_box(Vector3(0.95, 1.25, 0.12), 0.02), M_RIB, Vector3(0, 0.65, 3.32))
			# 穹顶天窗冠座与通讯天线阵
			A.add(dome, A.cyl(0.85, 0.26, 1.05, 32), M_RIB, Vector3(0.15, 3.88, -0.08))
			A.add(dome, A.cyl(0.62, 0.12, 0.62, 28), A.glass(Color(0.32, 0.52, 0.62)), Vector3(0.15, 4.02, -0.08))
			A.add(dome, A.cyl(0.06, 5.0, 0.11, 16), A.metal(), Vector3(1.2, 4.0, -0.5), Vector3(0, 0, -10))
			A.add(dome, A.sphere(0.14, -1, 20), A.emit(Color(1, 0.2, 0.15), 6.0), Vector3(1.6, 6.4, -0.5), Vector3.ZERO, Vector3.ONE, false)
			blocks.append(Rect2(c.x - 6, c.z, 6, 6))
		_poi_lamp(c + Vector3(s - 1.6, 0, -s + 1.6), Color(1.0, 0.75, 0.45))
		_poi_lamp(c + Vector3(-s + 1.6, 0, s - 1.6), Color(0.6, 0.85, 1.0))
		_fire_barrel(c + Vector3(1.5, 0, 1.0))
		var poi_kinds: Array = ["military", "tool", "safe", "supply"]
		match pid:
			"institute":
				poi_kinds = ["tech", "tech", "safe", "med"]
			"depot7":
				poi_kinds = ["supply", "military", "ammo", "tool"]
			"egret_wreck":
				poi_kinds = ["military", "weapon", "tech", "med"]
		_place_box(str(poi_kinds[0]), c + Vector3(3.5, 0, -3.5), [], 180.0)
		_place_box(str(poi_kinds[1]), c + Vector3(-4.5, 0, -4.0), [], -90.0)
		_place_box(str(poi_kinds[2]), c + Vector3(4.5, 0, 4.5), [], 0.0)
		_place_box(str(poi_kinds[3]), c + Vector3(-1.0, 0, 5.5), [], 0.0)
		# 遗迹不再在地图上悬挂 3D 漂浮文字，进入区域时由顶部横幅提示
		spawn_bug("beetle", c + Vector3(0, 0.5, 0))


func _crashed_ship(c: Vector3) -> void:
	# 坠毁重型战术运输艇「白鹭号」(EGRET-04)：犁地撞击焦痕 + 军绿灰多切面加强肋机身 + 装甲框架驾驶舱 + 撕裂舱腹与散落涡扇引擎
	var imp := A.ground_decal(world, A.cloud_tex(), Color(0.06, 0.055, 0.05, 0.72), 11.5, c + Vector3(-0.6, 0.092, 1.0))
	imp.rotation.y = 0.44
	var hull := StaticBody3D.new()
	hull.collision_layer = 1
	hull.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(4.5, 3.4, 10.0)
	cs.shape = sh
	cs.position.y = 1.7
	hull.add_child(cs)
	world.add_child(hull)
	hull.position = c + Vector3(-1.0, 0, 1.0)
	hull.rotation_degrees = Vector3(0, 25, 0)
	var body := Node3D.new()
	body.rotation_degrees = Vector3(5, 0, 11)
	body.position.y = 1.12
	hull.add_child(body)
	var M_HULL := A.paint(Color(0.42, 0.45, 0.42), 0.38, 0.62, {"wear": 0.74, "rust": 0.52, "grime": 0.80, "panel_scale": 1.35})
	var M_DARK := A.metal(Color(0.14, 0.15, 0.16))
	var M_CHAR := A.paint(Color(0.08, 0.08, 0.085), 0.18, 0.92, {"wear": 0.85, "rust": 0.65, "grime": 0.95, "panel_scale": 0.0})
	var M_GLASS := A.glass(Color(0.18, 0.28, 0.32))
	var M_DIRT := A.rock_mat(Color(0.32, 0.28, 0.24))
	# 主货舱切面机身 + 底部防擦龙骨装甲 + 背部航电脊梁 + 外露环形隔框肋
	A.add(body, A.bevel_box(Vector3(3.15, 2.25, 7.6), 0.38, 0.88), M_HULL, Vector3(0, 0.12, 0.35))
	A.add(body, A.bevel_box(Vector3(2.85, 0.56, 8.2), 0.16), M_DARK, Vector3(0, -0.92, 0.10))
	A.add(body, A.bevel_box(Vector3(1.42, 0.46, 6.2), 0.12, 0.82), M_HULL, Vector3(0, 1.34, 0.45))
	for rz in [-2.6, -1.2, 0.2, 1.6, 3.0]:
		A.add(body, A.bevel_box(Vector3(3.32, 2.38, 0.16), 0.04, 0.88), M_DARK, Vector3(0, 0.12, rz))
	# 收分前机鼻 + 气象雷达罩 + 多窗格防弹风挡框
	A.add(body, A.bevel_box(Vector3(2.55, 1.72, 2.45), 0.26, 0.78), M_HULL, Vector3(0, -0.08, -4.15), Vector3(8, 0, 0))
	A.add(body, A.cyl(0.42, 0.95, 0.82, 16), M_CHAR, Vector3(0, -0.28, -5.55), Vector3(-82, 0, 0))
	A.add(body, A.bevel_box(Vector3(1.96, 0.68, 1.55), 0.10, 0.76), M_DARK, Vector3(0, 0.72, -3.72), Vector3(-16, 0, 0))
	A.add(body, A.bevel_box(Vector3(1.78, 0.50, 1.36), 0.04, 0.78), M_GLASS, Vector3(0, 0.76, -3.76), Vector3(-16, 0, 0))
	for mx in [-0.46, 0.0, 0.46]:
		A.add(body, A.bevel_box(Vector3(0.06, 0.58, 1.44), 0.01), M_DARK, Vector3(mx, 0.76, -3.76), Vector3(-16, 0, 0), Vector3.ONE, false)
	# 右舷爆炸撕裂破口与扭曲肋骨（对应火焰浓烟源点）
	A.add(body, A.bevel_box(Vector3(0.36, 1.55, 2.55), 0.04), M_CHAR, Vector3(1.52, 0.22, 0.95), Vector3(0, 4, -6))
	for bz in [0.1, 0.95, 1.8]:
		A.add(body, A.bevel_box(Vector3(0.45, 1.42, 0.10), 0.02), M_DARK, Vector3(1.58, 0.24, bz), Vector3(12, 0, -18), Vector3.ONE, false)
	# 左翼完整重型短翼与倾转涡扇短舱；右翼齐根折断外露翼梁 + 地面散落焦黑引擎
	A.add(body, A.bevel_box(Vector3(4.6, 0.30, 2.25), 0.07, 0.85), M_HULL, Vector3(-3.35, 0.42, 0.15), Vector3(2, 8, -11))
	A.add(body, A.bevel_box(Vector3(0.85, 0.16, 0.52), 0.02), A.hazard(), Vector3(-2.45, 0.62, -0.55), Vector3(2, 8, -11))
	A.add(body, A.cyl(0.68, 2.35, 0.62, 18), M_HULL, Vector3(-5.15, 0.05, 0.25), Vector3(86, 6, -10))
	A.add(body, A.torus(0.56, 0.70, 18), M_DARK, Vector3(-5.05, 0.10, -0.92), Vector3(86, 6, -10), Vector3.ONE, false)
	A.add(body, A.cyl(0.54, 0.55, 0.44, 16), M_CHAR, Vector3(-5.25, -0.02, 1.52), Vector3(86, 6, -10))
	# 右翼断茬与散落在地面的涡扇发动机残骸
	A.add(body, A.bevel_box(Vector3(1.65, 0.28, 1.95), 0.05), M_CHAR, Vector3(2.15, 0.45, 0.15), Vector3(-4, -6, 14))
	for sp_z in [-0.45, 0.35]:
		A.add(body, A.bevel_box(Vector3(1.35, 0.12, 0.14), 0.01), M_DARK, Vector3(2.95, 0.32, sp_z), Vector3(0, -10, 18), Vector3.ONE, false)
	A.add(hull, A.cyl(0.64, 2.15, 0.58, 18), M_CHAR, Vector3(2.85, 0.46, 1.85), Vector3(82, -28, 14))
	A.add(hull, A.torus(0.52, 0.66, 18), M_DARK, Vector3(2.38, 0.52, 0.92), Vector3(82, -28, 14), Vector3.ONE, false)
	# 尾部上翘货舱跳板与外倾双垂尾安定面 + 机鼻撞击推土堆
	A.add(body, A.bevel_box(Vector3(2.65, 1.65, 1.85), 0.18, 0.76), M_HULL, Vector3(0, 0.36, 4.65), Vector3(12, 0, 0))
	A.add(body, A.bevel_box(Vector3(2.15, 0.16, 1.95), 0.04), M_DARK, Vector3(0, -0.52, 4.95), Vector3(24, 0, 0))
	for sx_t in [-1.0, 1.0]:
		var tail_x: float = sx_t * 1.18
		A.add(body, A.bevel_box(Vector3(0.20, 2.25, 1.65), 0.05, 0.62), M_HULL, Vector3(tail_x, 1.72, 4.55), Vector3(-18, 0, sx_t * -16.0))
	for k_d in 4:
		A.add(hull, A.rock_mesh((k_d * 3 + 2) % 12), M_DIRT, Vector3(-1.4 + k_d * 0.95, 0.16, -4.5 + (k_d % 2) * 0.45), Vector3(0, k_d * 52.0, 0), Vector3(0.85, 0.34, 0.72))
	A.emitter(world, c + Vector3(0.5, 2.5, 2.0), {"amount": 18, "life": 6.0, "size": 2.4, "tex": A.smoke_tex(), "additive": false, "vmin": 0.8, "vmax": 1.6,
		"gravity": Vector3(0.6, 0.8, 0.3), "radius": 0.6, "c0": Color(0.1, 0.09, 0.09, 0.6), "c1": Color(0.3, 0.27, 0.27, 0.0), "grow0": 0.5, "grow1": 3.0})
	A.emitter(world, c + Vector3(0.8, 1.5, 1.8), {"amount": 26, "life": 0.8, "size": 0.8, "vmin": 1.0, "vmax": 2.5, "gravity": Vector3(0, 2, 0), "radius": 0.5,
		"c0": Color(1.0, 0.75, 0.3), "cmid": Color(1.0, 0.35, 0.08), "c1": Color(0.4, 0.05, 0.0, 0.0), "grow0": 1.0, "grow1": 0.2})
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.2)
	l.light_energy = 3.0
	l.omni_range = 10.0
	l.position = c + Vector3(0.8, 2.2, 1.8)
	world.add_child(l)
	_add_flicker(l)


func _building(p: Vector3, size: Vector3, yaw := 0.0) -> void:
	# 城区通用街角楼与高层母版：按地块体量与层高自动匹配精修硬表面建筑预制件，并先约束高宽比防拉伸畸变
	var is_brick := rng.randf() < 0.36
	var c := Color(0.62, 0.59, 0.53).lerp(Color(0.50, 0.48, 0.44), rng.randi_range(0, 3) / 3.0)
	if is_brick:
		c = Color(0.54, 0.35, 0.25).lerp(Color(0.45, 0.29, 0.22), rng.randi_range(0, 2) / 2.0)
	var M_WALL: ShaderMaterial = A.brick(c) if is_brick else A.concrete(c)
	var M_METAL_D := A.metal(Color(0.15, 0.155, 0.165))
	if size.x < 4.2 or size.z < 4.2:
		var sb0 := _bldg_body(size, p + Vector3(0, size.y * 0.5, 0))
		sb0.rotation.y = -yaw
		var hy0 := size.y * 0.5
		var M_DARK := A.concrete(Color(0.30, 0.29, 0.27) if is_brick else c.darkened(0.36), false)
		var M_TRIM := A.concrete(Color(0.52, 0.49, 0.44) if is_brick else c.lightened(0.14), false)
		_ibox(sb0, size, 0.02, M_WALL)
		_ibox(sb0, Vector3(size.x + 0.22, 0.32, size.z + 0.22), 0.02, M_DARK, Vector3(0, -hy0 + 0.16, 0))
		_ibox(sb0, Vector3(size.x + 0.16, 0.14, size.z + 0.16), 0.02, M_TRIM, Vector3(0, hy0 - 0.04, 0))
		return

	var pf_id := "poi_generic_building"
	var rr := rng.randf()
	var min_fp := minf(size.x, size.z)
	var max_fp := maxf(size.x, size.z)
	if max_fp >= 16.5 and min_fp >= 11.0:
		pf_id = "bldg_civic_block" if rr < 0.45 else "bldg_midrise_office"
	elif max_fp >= 14.5 and min_fp >= 8.5:
		pf_id = "bldg_rowblock" if rr < 0.50 else "bldg_midrise_office"
	elif size.y >= 11.8 and min_fp >= 8.5:
		pf_id = "bldg_stepped_tower" if rr < 0.42 else "bldg_tenement"
	elif size.y >= 9.0 and min_fp >= 7.2:
		if rr < 0.45:
			pf_id = "poi_generic_building"
		elif rr < 0.78:
			pf_id = "bldg_apartment"
		else:
			pf_id = "bldg_arcade_shop"
	elif min_fp >= 6.0:
		pf_id = "poi_generic_building" if rr < 0.72 else "bldg_terrace"
	else:
		pf_id = "poi_generic_building"

	var safe_sz := PrefabLib.clamp_building_height(pf_id, size)
	var sb := _bldg_body(safe_sz, p + Vector3(0, safe_sz.y * 0.5, 0))
	sb.rotation.y = -yaw
	var hy := safe_sz.y * 0.5
	var hz := safe_sz.z * 0.5
	var use_wall: Material = null if pf_id == "bldg_rowblock" else M_WALL
	PrefabLib.place_on_body(self, sb, pf_id, safe_sz, true, use_wall, -999.0, rng.randf() < 0.18)

	# 少数高层街角楼挂着带金属灯箱外框与支架的残存工业招牌
	if size.y > 4.8 and rng.randf() < 0.22:
		var nc: Color = [Color(1.0, 0.48, 0.18), Color(0.32, 0.82, 0.96), Color(0.96, 0.72, 0.26)][rng.randi() % 3]
		var sp := Vector3(0, hy - 0.9, hz + 0.22)
		_ibox(sb, Vector3(1.56, 0.62, 0.12), 0.02, M_METAL_D, sp - Vector3(0, 0, 0.03), Vector3.ZERO, Vector3.ONE, false)
		for bx_s in [-0.55, 0.55]:
			_ibox(sb, Vector3(0.06, 0.08, 0.18), 0.01, M_METAL_D, sp + Vector3(bx_s, 0.22, -0.09), Vector3.ZERO, Vector3.ONE, false)
		var m_sign := A.emit(nc, 1.8)
		m_sign.albedo_color = nc.darkened(0.35)
		var sign_n := A.add(sb, A.bevel_box(Vector3(1.38, 0.44, 0.06), 0.015), m_sign, sp + Vector3(0, 0, 0.02), Vector3.ZERO, Vector3.ONE, false)
		var l := OmniLight3D.new()
		l.light_color = nc
		l.light_energy = 1.4
		l.omni_range = 6.0
		l.position = sign_n.position + Vector3(0, 0, 0.8)
		sb.add_child(l)
		_add_flicker(l)


## 建筑细部（窗、腰线、女儿墙、屋顶设备、碎石……）不建节点：按 网格 + 材质 收集变换，_bake_static 时一次性
## 生成 MultiMesh（60 米分块）。尺寸各异的方块统一用单位倒角盒按尺寸缩放，全图共用一个网格。
## 记下所属楼体：扩展脚本在烘焙前删掉的楼（见 landmarks.gd _clear_aprons），它的细部一并丢弃。
var _inst := {}


func _imesh(owner: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE, shadow := true) -> void:
	var key := "%d|%d|%d" % [mesh.get_rid().get_id(), m.get_rid().get_id(), 1 if shadow else 0]
	var e = _inst.get(key)
	if e == null:
		e = {"mesh": mesh, "mat": m, "shadow": shadow, "xf": [], "own": []}
		_inst[key] = e
	var bs := Basis.from_euler(rot * (PI / 180.0)) * Basis.from_scale(scl)
	e.xf.append(owner.transform * Transform3D(bs, pos))
	e.own.append(owner)


func _ibox(owner: Node3D, size: Vector3, _bevel: float, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE, shadow := true) -> void:
	_imesh(owner, A.bevel_box(Vector3.ONE, 0.03), m, pos, rot, size * scl, shadow)


func _flush_inst() -> void:
	for key in _inst:
		var e: Dictionary = _inst[key]
		var xs: Array = []
		for i in e.xf.size():
			if is_instance_valid(e.own[i]) and not e.own[i].is_queued_for_deletion():
				xs.append(e.xf[i])
		if not xs.is_empty():
			_multimesh(e.mesh, e.mat, xs, e.shadow)
	_inst.clear()


func _wreck_car(p: Vector3, yaw_deg := INF, compact_scale := 1.0) -> void:
	# 四种按 4m 机甲真实参照尺度（2.65m~2.90m 宽 × 6.1m~7.5m 长）重制的废弃军工重型载具残骸（P0-M2.1）：
	# 矿山自卸重卡 / 八轮装甲运兵车 / 半挂重型油罐车 / 装甲工程推土机
	var zc := zone_at(p)
	var pf_id := "veh_dump_truck"
	var rr := rng.randf()
	if compact_scale < 0.92:
		# 室内低净空车库（如停车楼 3.24m 层高）优先使用低矮宽体八轮装甲车与工程推土机
		pf_id = "veh_apc_wreck" if rr < 0.65 else "veh_armored_dozer"
	elif zc in ["M", "C"]:
		pf_id = "veh_apc_wreck" if rr < 0.65 else "veh_armored_dozer"
	elif zc in ["I", "H", "Y"]:
		if rr < 0.36:
			pf_id = "veh_dump_truck"
		elif rr < 0.72:
			pf_id = "veh_fuel_tanker"
		else:
			pf_id = "veh_armored_dozer"
	else:
		if rr < 0.32:
			pf_id = "veh_dump_truck"
		elif rr < 0.62:
			pf_id = "veh_apc_wreck"
		elif rr < 0.82:
			pf_id = "veh_fuel_tanker"
		else:
			pf_id = "veh_armored_dozer"

	var cols := [
		Color(0.46, 0.42, 0.31),
		Color(0.33, 0.37, 0.30),
		Color(0.54, 0.41, 0.24),
		Color(0.38, 0.43, 0.46),
		Color(0.50, 0.30, 0.22),
	]
	var ci := rng.randi() % cols.size()
	if pf_id == _last_wreck_id and ci == _last_wreck_col:
		ci = (ci + 1 + (rng.randi() % (cols.size() - 1))) % cols.size()
	_last_wreck_id = pf_id
	_last_wreck_col = ci
	var c: Color = cols[ci]
	var M_BODY := A.paint(c, 0.28, 0.66, {"wear": 0.52, "rust": 0.48, "grime": 0.62, "panel_scale": 0.0})
	var bsz := PrefabLib.base_size(pf_id) * compact_scale
	var col_sz := Vector3(bsz.x * 0.94, maxf(1.6, bsz.y * 0.88), bsz.z * 0.94)
	var sb := _bldg_body(col_sz, p + Vector3(0, col_sz.y * 0.5, 0))
	var use_yaw := yaw_deg if yaw_deg < INF else rng.randf_range(0.0, 360.0)
	sb.rotation_degrees.y = use_yaw
	PrefabLib.place_on_body(self, sb, pf_id, bsz, false, M_BODY, -col_sz.y * 0.5, rng.randf() < 0.30)
	if p.y < 0.5:
		add_contact_shadow(p, bsz.x * 1.48, bsz.z * 1.28, use_yaw)
	var yr := deg_to_rad(use_yaw)
	var ex := absf(cos(yr)) * bsz.x + absf(sin(yr)) * bsz.z
	var ez := absf(sin(yr)) * bsz.x + absf(cos(yr)) * bsz.z
	blocks.append(_rect_for(p, Vector3(ex + 0.4, 1.0, ez + 0.4)))


func _build_ruins() -> void:
	for i in 60:
		var size := Vector3(rng.randf_range(3, 12), rng.randf_range(1.5, 5.5), rng.randf_range(3, 12))
		var wall_only := rng.randf() < 0.3
		if wall_only:
			size = Vector3(rng.randf_range(6, 14), rng.randf_range(1.2, 2.6), 0.8) if rng.randf() < 0.5 else Vector3(0.8, rng.randf_range(1.2, 2.6), rng.randf_range(6, 14))
		var p := _free_spot(max(size.x, size.z) * 0.5 + 2.5)
		if p == Vector3.ZERO:
			continue
		if wall_only:
			var sb := _static_box(size, p + Vector3(0, size.y * 0.5, 0), Color(0.52, 0.48, 0.44))
			for k in 3:
				var ch := Vector3(min(size.x, rng.randf_range(0.6, 2.0)), rng.randf_range(0.3, 1.0), min(size.z, rng.randf_range(0.6, 2.0)))
				A.add(sb, A.bevel_box(ch, 0.06), A.concrete(Color(0.5, 0.46, 0.42)), Vector3(rng.randf_range(-size.x, size.x) * 0.35, size.y * 0.5 + ch.y * 0.5, rng.randf_range(-size.z, size.z) * 0.35))
		else:
			_building(p, size)
		blocks.append(_rect_for(p, size))
	for i in 18:
		var p := _free_spot(2.5)
		if p != Vector3.ZERO:
			_wreck_car(p)
	for i in 30:
		var p := _free_spot(1.2)
		var size := Vector3(rng.randf_range(0.6, 1.6), rng.randf_range(0.4, 1.0), rng.randf_range(0.6, 1.6))
		var sb := _static_box(size, p + Vector3(0, size.y * 0.5, 0), Color(0.45, 0.4, 0.36))
		sb.rotation_degrees.y = rng.randf_range(0, 180)
		blocks.append(_rect_for(p, Vector3(size.z, 1, size.z)))
	for i in 6:
		var p := _free_spot(1.5)
		if p != Vector3.ZERO:
			_fire_barrel(p)


func _place_box(kind: String, pos: Vector3, loot: Array = [], yaw_deg := INF):
	# 容器品质由所在区块的危险度决定：军事区/要塞出精英箱，野外补给出常规箱；位置与朝向、内容按箱体坐标固定化
	var zw: Dictionary = LOOT_W.get(zone_at(pos), LOOT_W["W"]) as Dictionary
	var tier: int = GameData.zone_tier(zw)
	var b = LootScript.new()
	world.add_child(b)
	b.position = pos
	b.rotation_degrees.y = yaw_deg if yaw_deg < INF else 0.0
	var items: Array = loot
	if items.is_empty():
		var lrng := RandomNumberGenerator.new()
		lrng.seed = _map_seed(500) ^ (hash("%s|%.1f|%.1f" % [kind, pos.x, pos.z]) & 0x7fffffff)
		items = GameData.roll_loot(kind, lrng, tier)
	b.setup(kind, items, tier)
	return b


## 根据外法线计算容器朝向（loot_box.gd 容器正面均在本地 -Z，长轴沿本地 X；朝外法线可使面板/柜门/车体自然贴墙或顺路停放）
func _face_outward_yaw(out_v: Vector3) -> float:
	if out_v.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(atan2(-out_v.x, -out_v.z))


## 登记一个贴靠建筑/掩体/集装箱/地标/残骸的情境化固定物资箱锚点
func register_loot_anchor(pos: Vector3, yaw_deg: float, kind: String, priority: int, tag := "", outward := Vector3.ZERO, host_pos := Vector3.INF) -> void:
	_loot_anchors.append({
		"pos": Vector3(pos.x, 0.0, pos.z),
		"yaw": yaw_deg,
		"kind": kind,
		"priority": priority,
		"tag": tag,
		"outward": Vector3(outward.x, 0.0, outward.z),
		"host_pos": host_pos,
		"order": hash("%s|%s|%d|%d|%s" % [map_id, tag, roundi(pos.x * 2.0), roundi(pos.z * 2.0), kind]) & 0x7fffffff,
	})


func _near_scripted_poi(p: Vector3, rad: float) -> bool:
	var p2 := Vector2(p.x, p.z)
	for i in poi_centers.size():
		if not GameData.POIS.get(str(poi_ids[i]), {}).has("script"):
			continue
		var c: Vector3 = poi_centers[i]
		if p2.distance_to(Vector2(c.x, c.z)) < rad:
			return true
	return false


## 严格按建筑/设施语义解析容器类型：不再把任意补给箱随机变成轿车/埋藏桶、或把军堡保险柜变成收银机
func _resolve_anchor_kind(base: String, tag: String, pos: Vector3, order_seed: int) -> String:
	if GameData.LOOT_TABLES.get(base) == null:
		return "supply"
	var pick := posmod(order_seed, 100)
	var zone := zone_at(pos)
	match base:
		"register", "med", "tech", "ammo", "weapon", "car_wreck", "container", "cache":
			return base
		"military":
			if tag in ["sandbags", "tank_wreck"]:
				return "ammo" if pick < 45 else "military"
			if tag in ["bunker", "military_bldg:command_bunker", "military_bldg:barrack"]:
				if pick < 22:
					return "ammo"
				if pick < 40 and zone in ["M", "C", "S"]:
					return "weapon"
			return "military"
		"tool":
			if tag in ["bldg:substation", "bldg:chem_plant", "bldg:loco_shed", "bldg:shed", "landmark:radio_mast", "landmark:drill_derrick", "landmark:coolant_channel"]:
				return "tech" if pick < 38 else "tool"
			return "tool"
		"safe":
			if tag in ["bldg:arcade_shop", "bldg:stepped_tower"]:
				return "register" if pick < 30 else "safe"
			return "safe"
		"supply":
			if tag in ["bldg:apt", "bldg:tenement", "bldg:terrace", "bldg:duplex", "bldg:house", "bldg:courtyard_blk", "park_statue"]:
				return "med" if pick < 25 else "supply"
			return "supply"
	return base


## 按容器真实三维尺寸校验中心与长轴两端是否无穿墙、无落水、无占路
func _loot_spot_clear(p: Vector3, yaw_deg: float, sz: Vector3, road_pad: float) -> bool:
	var q := Vector2(p.x, p.z)
	if not in_bounds(p, 5.0) or in_wet(q, 2.0) or on_road(q, road_pad):
		return false
	var center_rad := clampf(sz.z * 0.5 + 0.16, 0.62, 1.05)
	if _blocked(p, center_rad, false):
		return false
	if sz.x > 1.45:
		var yr := deg_to_rad(yaw_deg)
		var ax_x := Vector3(cos(yr), 0.0, -sin(yr))
		var half_span := maxf(0.35, sz.x * 0.5 - 0.35)
		var end_rad := clampf(sz.z * 0.5 + 0.08, 0.48, 0.90)
		var end_road_pad := maxf(0.15, road_pad - 0.35)
		for sgn: float in [-1.0, 1.0]:
			var ep: Vector3 = p + ax_x * (sgn * half_span)
			var eq := Vector2(ep.x, ep.z)
			if not in_bounds(ep, 4.0) or in_wet(eq, 1.6) or on_road(eq, end_road_pad) or _blocked(ep, end_rad, false):
				return false
	return true


## 统一落位全图情境化固定物资箱：按建筑/设施功能匹配容器类型、正面朝外贴墙/顺路摆放、按真实箱体尺寸校验净空并均衡分布
func _place_contextual_loot() -> void:
	if _loot_anchors.is_empty():
		return
	var existing: Array = []
	for bx in get_tree().get_nodes_in_group("lootboxes"):
		if is_instance_valid(bx):
			existing.append(Vector2(bx.global_position.x, bx.global_position.z))
	var sorted := _loot_anchors.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.priority) != int(b.priority):
			return int(a.priority) > int(b.priority)
		return int(a.order) < int(b.order))
	var placed := 0
	var placed_pts: Array = []
	var cell_cnt := {}
	var host_cnt := {}
	var used_idx := {}
	var max_total := 60 if is_surface_map else 34
	# 两轮落位：第 1 轮每个 44m 网格先配 1 只最匹配的高优箱，保证住宅/商铺/郊野/路边不会被工业/军营挤空；第 2 轮再补足高价值密集区配额
	for pass_idx in 2:
		if placed >= max_total:
			break
		for ai in sorted.size():
			if placed >= max_total:
				break
			if used_idx.has(ai):
				continue
			var a: Dictionary = sorted[ai]
			var base_p: Vector3 = a.pos
			var prio: int = int(a.priority)
			var tag := str(a.tag)
			var is_bldg := tag == "bldg" or tag == "military_bldg" or tag.begins_with("bldg:") or tag.begins_with("military_bldg:")
			var is_lm := tag == "landmark" or tag.begins_with("landmark:")
			var is_curb := tag == "curb_car"
			var is_free_prop := tag in ["curb_car", "parking_car", "wild_cache", "hive_cache"]
			var road_pad := 0.22 if is_curb else 0.85
			if _in_keep_clear(base_p, 0.5) and not is_lm:
				used_idx[ai] = true
				continue
			if is_bldg:
				var hp: Vector3 = a.host_pos
				if hp != Vector3.INF and _near_scripted_poi(hp, 17.5):
					used_idx[ai] = true
					continue
				if _near_scripted_poi(base_p, 16.5):
					used_idx[ai] = true
					continue
				if hp != Vector3.INF:
					var hkey := Vector2i(roundi(hp.x * 2.0), roundi(hp.z * 2.0))
					var hcap := 2 if (tag.begins_with("military_bldg") or tag in ["bldg:arcade_shop", "bldg:stepped_tower", "bldg:wh", "bldg:cold_store", "bldg:chem_plant", "bldg:foundry", "bldg:loco_shed"]) else 1
					if int(host_cnt.get(hkey, 0)) >= hcap:
						used_idx[ai] = true
						continue
			var kind: String = _resolve_anchor_kind(str(a.kind), tag, base_p, int(a.order))
			var yaw_deg: float = float(a.yaw)
			var out_v: Vector3 = a.outward
			var onrm := out_v.normalized() if out_v.length_squared() > 0.01 else Vector3.ZERO
			var sz: Vector3 = (LootScript.STYLE.get(kind, {"size": Vector3(1.5, 0.9, 1.0)}) as Dictionary).size
			var extra_out := maxf(0.0, sz.z * 0.5 - 0.48) if (onrm != Vector3.ZERO and not is_free_prop) else 0.0
			var p := base_p + onrm * extra_out
			if not _loot_spot_clear(p, yaw_deg, sz, road_pad):
				# 3.4m 集装箱在窄巷放不下时回退为同场景工业工具箱或补给箱，避免浪费货场锚点
				if kind == "container":
					kind = "tool" if tag in ["ind_container", "gantry", "wagon"] else "supply"
					sz = (LootScript.STYLE[kind] as Dictionary).size
					extra_out = maxf(0.0, sz.z * 0.5 - 0.48) if (onrm != Vector3.ZERO and not is_free_prop) else 0.0
					p = base_p + onrm * extra_out
					if not _loot_spot_clear(p, yaw_deg, sz, road_pad):
						used_idx[ai] = true
						continue
				else:
					used_idx[ai] = true
					continue
			if onrm != Vector3.ZERO:
				# 斜俯视视角从 +Z 看向 -Z：建筑北侧窄缝容易被南侧高楼遮挡，优先摆在可见南/东/西临街面或开阔院坪
				if is_bldg and onrm.z < -0.45 and _blocked(p + Vector3(0.0, 0.0, -3.2), 1.0, false):
					used_idx[ai] = true
					continue
				var stand_dist := maxf(1.55, sz.z * 0.5 + 1.15)
				var stand := p + onrm * stand_dist
				var sq := Vector2(stand.x, stand.z)
				if not in_bounds(stand, 3.0) or in_wet(sq, 1.5) or _blocked(stand, 0.70, false):
					used_idx[ai] = true
					continue
				if is_bldg:
					var open_fg := p + onrm * (stand_dist + 1.35)
					if _blocked(open_fg, 0.85, false) or _blocked(p + Vector3(0.0, 0.0, 3.6), 1.1, false):
						used_idx[ai] = true
						continue
			var q := Vector2(p.x, p.z)
			# 避免贴着 POI 既有箱子堆叠
			var near_exist := false
			for ep: Vector2 in existing:
				if ep.distance_to(q) < 4.5:
					near_exist = true
					break
			if near_exist:
				used_idx[ai] = true
				continue
			# 控制同片区箱子间距与 44m 网格均衡配额
			var min_sep := 3.4 if prio >= 95 else (6.5 if prio >= 80 else 9.5)
			if kind in ["container", "car_wreck"]:
				min_sep = maxf(min_sep, 7.5)
			var too_close := false
			for pp: Vector2 in placed_pts:
				if pp.distance_to(q) < min_sep:
					too_close = true
					break
			if too_close:
				used_idx[ai] = true
				continue
			var cell := Vector2i(floori(p.x / 44.0), floori(p.z / 44.0))
			var cur_c := int(cell_cnt.get(cell, 0))
			var cell_cap := 1 if pass_idx == 0 else (3 if prio >= 92 else 2)
			if cur_c >= cell_cap:
				continue
			var b = _place_box(kind, p, [], yaw_deg)
			b.set_meta("contextual_loot", tag)
			_obb_blocks(q, -deg_to_rad(yaw_deg), sz.x + 0.25, sz.z + 0.25)
			placed_pts.append(q)
			cell_cnt[cell] = cur_c + 1
			used_idx[ai] = true
			if is_bldg and a.host_pos != Vector3.INF:
				var hkey2 := Vector2i(roundi(a.host_pos.x * 2.0), roundi(a.host_pos.z * 2.0))
				host_cnt[hkey2] = int(host_cnt.get(hkey2, 0)) + 1
			placed += 1
	print("[raid] placed %d contextual loot boxes from %d anchors" % [placed, _loot_anchors.size()])


func _scatter_loot() -> void:
	var weights := {"supply": 45, "tool": 35, "military": 12, "safe": 8}
	for i in 38:
		var p := _free_spot(1.6)
		var k := GameData._weighted(weights, rng)
		_place_box(k, p)
		blocks.append(Rect2(p.x - 1, p.z - 1, 2, 2))


func _spawn_nests() -> void:
	for i in 3:
		var p := _free_spot(3.0)
		var n = NestScript.new()
		world.add_child(n)
		n.position = p
		n.setup(self)
		blocks.append(Rect2(p.x - 2, p.z - 2, 4, 4))


# ================= 运行 =================
func _process(delta: float) -> void:
	var _pt := Prof.t0()
	_process_impl(delta)
	Prof.add("proc.raid", _pt)


func is_first_person() -> bool:
	if view_mode != 1:
		return false
	if coop != null and mech != null and (mech.net_done or mech.dead):
		return false
	return true


func fp_forward_xz() -> Vector3:
	if camera != null and is_first_person():
		var f := -camera.global_transform.basis.z
		f.y = 0.0
		if f.length_squared() > 0.0001:
			return f.normalized()
	return Vector3(-sin(fp_yaw), 0.0, -cos(fp_yaw)).normalized()


func should_capture_mouse() -> bool:
	if not is_first_person() or dropping or ended or not _window_focused:
		return false
	if mech == null or not is_instance_valid(mech) or mech.dead or mech.net_done:
		return false
	if Story.get("flow") != null and Story.flow.is_playing():
		return false
	if hud != null:
		if hud._touch_revealed:
			return false
		if hud.pause_panel.visible or (hud.settings_panel != null and hud.settings_panel.visible):
			return false
		if hud.loot_panel.visible or hud.map_open() or hud.is_touch_busy():
			return false
	if (GameData.test_mode or DisplayServer.get_name() == "headless") and not force_mouse_capture:
		return false
	return true


func set_view_mode(mode: int, save := false) -> void:
	var next := clampi(mode, 0, 1)
	var prev := view_mode
	view_mode = next
	_fp_look_touch_id = -1
	GameData.view_mode = next
	if save:
		GameData.save_game()
	if mech != null and is_instance_valid(mech) and mech.has_method("set_fp_passthrough"):
		mech.set_fp_passthrough(next == 1)
	if camera != null:
		if next == 1:
			camera.cull_mask = 0xFFFFF & ~(1 << 19)
			if prev != 1 and mech != null and is_instance_valid(mech) and mech.torso != null:
				var tf: Vector3 = -(mech.torso as Node3D).global_transform.basis.z
				fp_yaw = atan2(-tf.x, -tf.z)
				fp_pitch = deg_to_rad(-2.0)
			_fp_fov = FP_FOV_STD
			camera.near = 0.08
			camera.far = 420.0
			camera.fov = _fp_fov
			if _sun_light != null and is_instance_valid(_sun_light):
				if A.is_mobile_perf():
					_sun_light.directional_shadow_blend_splits = GameData.quality >= 1
					_sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
					_sun_light.directional_shadow_split_1 = 0.24
					_sun_light.directional_shadow_max_distance = 56.0 if GameData.quality == 0 else (66.0 if GameData.quality == 1 else 78.0)
				elif GameData.quality > 0:
					_sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
					_sun_light.directional_shadow_split_1 = 0.08
					_sun_light.directional_shadow_split_2 = 0.22
					_sun_light.directional_shadow_split_3 = 0.48
					_sun_light.directional_shadow_max_distance = 120.0
				else:
					_sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
					_sun_light.directional_shadow_split_1 = 0.10
					_sun_light.directional_shadow_split_2 = 0.26
					_sun_light.directional_shadow_split_3 = 0.54
					_sun_light.directional_shadow_max_distance = 86.0
				_sun_light.shadow_bias = 0.055 if A.is_mobile_perf() else 0.035
				_sun_light.shadow_normal_bias = 2.00 if A.is_mobile_perf() else 1.45
			sync_fp_camera()
		else:
			camera.cull_mask = 0xFFFFF
			camera.fov = 40.0
			camera.near = 1.0
			camera.far = 340.0
			if _sun_light != null and is_instance_valid(_sun_light):
				if A.is_mobile_perf():
					_sun_light.directional_shadow_blend_splits = GameData.quality >= 1
					_sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
					_sun_light.directional_shadow_split_1 = 0.48
					_sun_light.directional_shadow_max_distance = 52.0 if GameData.quality == 0 else (62.0 if GameData.quality == 1 else 74.0)
				elif GameData.quality >= 2:
					_sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
					_sun_light.directional_shadow_split_1 = 0.14
					_sun_light.directional_shadow_split_2 = 0.34
					_sun_light.directional_shadow_split_3 = 0.60
					_sun_light.directional_shadow_max_distance = 112.0
				else:
					_sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
					_sun_light.directional_shadow_split_1 = 0.36 if GameData.quality == 1 else 0.38
					_sun_light.directional_shadow_max_distance = 98.0 if GameData.quality == 1 else 74.0
				_sun_light.shadow_bias = (0.06 if GameData.quality == 0 else 0.05) if A.is_mobile_perf() else (0.04 if GameData.quality >= 2 else 0.042)
				_sun_light.shadow_normal_bias = (2.25 if GameData.quality == 0 else 1.95) if A.is_mobile_perf() else (1.55 if GameData.quality == 1 else 1.50)
			if mech != null and is_instance_valid(mech):
				cam_focus = Vector3(mech.global_position.x, 0.0, mech.global_position.z)
				_aim_pan = Vector3.ZERO
				camera.global_position = cam_focus + CAM_OFFSET * _eff_zoom
				camera.look_at(cam_focus, Vector3.UP)
		_update_cam_dof(false)
	if hud != null:
		if hud.has_method("sync_view_mode_ui"):
			hud.sync_view_mode_ui()
		hud._update_cursor()


func toggle_view_mode() -> void:
	set_view_mode(1 - view_mode, true)
	Audio.play_ui("ui_tab")


func sync_fp_camera() -> void:
	if not is_first_person() or camera == null or mech == null or not is_instance_valid(mech) or mech.torso == null:
		return
	var gt: Transform3D = mech.torso.global_transform
	var torso_yaw := atan2(gt.basis.z.x, gt.basis.z.z)
	var body_pitch := asin(clampf(-gt.basis.z.y, -0.5, 0.5)) * 0.36
	var body_roll := asin(clampf(gt.basis.x.y, -0.4, 0.4)) * 0.36
	var cam_pos: Vector3 = gt.origin + gt.basis * FP_CAM_OFFSET
	if aim_override != null:
		var to_ov: Vector3 = aim_override - cam_pos
		var hz := Vector2(to_ov.x, to_ov.z).length()
		if hz > 0.04 or absf(to_ov.y) > 0.04:
			fp_yaw = atan2(-to_ov.x, -to_ov.z)
			fp_pitch = clampf(atan2(to_ov.y, maxf(hz, 0.001)), FP_PITCH_MIN, FP_PITCH_MAX)
	# 机身穿透、左右双臂武器保留可见：偏航相对于躯干限幅在正负 32 度内并沿前弧微移，保证双臂武器始终位于画面两侧且不穿入枪机后座
	var yaw_lead := clampf(angle_difference(torso_yaw, fp_yaw), deg_to_rad(-32.0), deg_to_rad(32.0))
	var eff_yaw := torso_yaw + yaw_lead
	var eff_pitch := clampf(fp_pitch + body_pitch, FP_PITCH_MIN, FP_PITCH_MAX)
	if absf(yaw_lead) > 0.005:
		var neck_local := Vector3(0.0, FP_CAM_OFFSET.y, 0.0)
		var visor_arm := Vector3(0.0, 0.0, FP_CAM_OFFSET.z).rotated(Vector3.UP, yaw_lead)
		cam_pos = gt.origin + gt.basis * (neck_local + visor_arm)
	var cam_basis := Basis.from_euler(Vector3(eff_pitch, eff_yaw, body_roll))
	if shake > 0.0:
		cam_pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.14
	camera.global_transform = Transform3D(cam_basis, cam_pos)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_window_focused = false
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_window_focused = true
		if hud != null:
			hud._update_cursor()


func _exit_tree() -> void:
	_reset_occluder_fade()
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _set_occ_params(pv: Vector4) -> void:
	if _occ_sent_params != pv:
		_occ_sent_params = pv
		RenderingServer.global_shader_parameter_set(&"occ_params", pv)


func _reset_occluder_fade() -> void:
	_occ_bldg_str = 0.0
	_occ_phys_cached = false
	_occ_ray_cam = Vector3(1e9, 1e9, 1e9)
	_set_occ_params(Vector4(0.0, 2.10, 3.95, 0.0))
	if _occ_bldgs != null:
		_occ_bldgs.reset()
	for eid in _occ_faded_enemies:
		var rec: Array = _occ_faded_enemies[eid]
		if is_instance_valid(rec[0]) and rec[0].has_method("set_occ_fade"):
			rec[0].set_occ_fade(0.0)
	_occ_faded_enemies.clear()


func _raycast_occ_fallback(cam_p: Vector3, mp: Vector3) -> bool:
	if cam_p.distance_squared_to(_occ_ray_cam) <= 0.0025 and mp.distance_squared_to(_occ_ray_mp) <= 0.0025:
		return _occ_phys_cached
	_occ_ray_cam = cam_p
	_occ_ray_mp = mp
	var w3d := get_world_3d()
	if w3d == null or w3d.direct_space_state == null:
		_occ_phys_cached = false
		return false
	if _occ_ray_q == null:
		_occ_ray_q = PhysicsRayQueryParameters3D.new()
		_occ_ray_q.collision_mask = 1
	_occ_ray_q.exclude = [mech.get_rid()]
	_occ_ray_q.from = cam_p
	var space := w3d.direct_space_state
	var hit_ok := false
	for i in 5:
		var tp: Vector3 = _occ_probes[i]
		var seg_v := tp - cam_p
		var seg_l := seg_v.length()
		if seg_l <= 0.8:
			continue
		_occ_ray_q.to = tp - (seg_v / seg_l) * 0.45
		var hit := space.intersect_ray(_occ_ray_q)
		if not hit.is_empty() and (hit.position as Vector3).y > mp.y + 0.35:
			hit_ok = true
			break
	_occ_phys_cached = hit_ok
	return hit_ok


## 更新前景建筑/树冠/大型敌人遮挡机甲时的虚化穿透效果（实心机甲保持清晰，整栋遮挡建筑与大型敌人平滑虚化）
func _update_occluder_fade(delta: float) -> void:
	if camera == null or not is_instance_valid(camera) or mech == null or not is_instance_valid(mech) \
		or mech.dead or is_first_person() or dropping or ended:
		if _occ_bldg_str > 0.001 or not _occ_faded_enemies.is_empty() or (_occ_bldgs != null and _occ_bldgs.active_count() > 0):
			_reset_occluder_fade()
		else:
			_set_occ_params(Vector4(0.0, 2.10, 3.95, 0.0))
		return

	var cam_p: Vector3 = camera.global_position
	var mp: Vector3 = mech.global_position
	var mech_c: Vector3 = mp + Vector3(0.0, 1.75, 0.0)
	_occ_probes[0] = mech_c
	_occ_probes[1] = mp + Vector3(0.0, 3.20, 0.0)
	_occ_probes[2] = mp + Vector3(0.0, 0.65, 0.0)
	_occ_probes[3] = mp + Vector3(-1.15, 1.85, 0.0)
	_occ_probes[4] = mp + Vector3(1.15, 1.85, 0.0)

	var need_phys := true
	if _occ_bldgs != null:
		need_phys = _occ_bldgs.update(self, delta, cam_p, mp, _occ_probes)
	var fallback_hit := _raycast_occ_fallback(cam_p, mp) if need_phys else false

	var b_spd := 12.0 if fallback_hit else 7.0
	_occ_bldg_str = lerpf(_occ_bldg_str, 1.0 if fallback_hit else 0.0, clampf(delta * b_spd, 0.0, 1.0))
	if _occ_bldg_str < 0.004:
		_occ_bldg_str = 0.0
	if cam_p.distance_squared_to(_occ_sent_cam) > 0.0001:
		_occ_sent_cam = cam_p
		RenderingServer.global_shader_parameter_set(&"occ_cam_pos", cam_p)
	if mech_c.distance_squared_to(_occ_sent_mech) > 0.0001:
		_occ_sent_mech = mech_c
		RenderingServer.global_shader_parameter_set(&"occ_mech_pos", mech_c)
	_set_occ_params(Vector4(_occ_bldg_str, 2.10, 3.95, 1.0))

	# 大型敌人与首领视线遮挡检测：仅遍历登记在 occ_fade_bugs 组的大型敌人与首领
	var sight := mech_c - cam_p
	var sight_len := sight.length()
	if sight_len < 1.0:
		return
	var sight_dir := sight / sight_len
	var hit_eids := {}
	for e in get_tree().get_nodes_in_group("occ_fade_bugs"):
		if not is_instance_valid(e) or not (e is Node3D):
			continue
		var ed: Dictionary = e.data
		var sc: float = float(ed.get("scale", 1.0))
		var ep: Vector3 = (e as Node3D).global_position
		var max_d := 22.0 + sc * 5.0
		if ep.distance_squared_to(mp) > max_d * max_d:
			continue
		var is_boss: bool = bool(ed.get("boss", false)) or e.is_in_group("boss")
		var vis_node = e.visual
		var vis_y: float = (vis_node as Node3D).position.y if (vis_node is Node3D and is_instance_valid(vis_node)) else 0.0
		var e_kind: String = e.kind
		var e_rad: float
		var e_bot_y: float = ep.y + (0.20 if vis_y < 0.5 else vis_y - 0.55 * sc)
		var e_top_y: float
		if e_kind == "citadel_behemoth":
			e_rad = sc * 2.55
			e_top_y = ep.y + sc * 3.05
		elif e_kind == "sky_carrier":
			e_rad = sc * 2.15
			e_top_y = ep.y + vis_y + sc * 1.15
		elif is_boss:
			e_rad = maxf(float(ed.get("radius", sc * 1.1)), sc * 1.45)
			e_top_y = ep.y + vis_y + sc * 2.55
		else:
			e_rad = maxf(float(ed.get("radius", sc * 0.9)), sc * 1.15)
			e_top_y = ep.y + vis_y + sc * 2.15
		var e_a := Vector3(ep.x, e_bot_y, ep.z)
		var e_h := maxf(e_top_y - e_bot_y, 1.0)
		var w0 := e_a - cam_p
		var denom := maxf(e_h * (1.0 - sight_dir.y * sight_dir.y), 0.0001)
		var t_e := clampf((sight_dir.y * w0.dot(sight_dir) - w0.y) / denom, 0.0, 1.0)
		var p_e := e_a + Vector3(0.0, t_e * e_h, 0.0)
		var s_e := (p_e - cam_p).dot(sight_dir)
		if s_e > 0.8 and s_e < sight_len - 0.25:
			var d_perp_sq := (cam_p + sight_dir * s_e).distance_squared_to(p_e)
			var r_lim := e_rad + 1.35
			if d_perp_sq < r_lim * r_lim:
				var iid := e.get_instance_id()
				hit_eids[iid] = e
				if not _occ_faded_enemies.has(iid):
					_occ_faded_enemies[iid] = [e, 0.0]

	var to_erase: Array = []
	for eid in _occ_faded_enemies:
		var rec: Array = _occ_faded_enemies[eid]
		var ent = rec[0]
		if not is_instance_valid(ent):
			to_erase.append(eid)
			continue
		var want := 1.0 if hit_eids.has(eid) else 0.0
		var spd_e := 10.5 if want > 0.0 else 7.0
		var cur := lerpf(float(rec[1]), want, clampf(delta * spd_e, 0.0, 1.0))
		if cur < 0.004 and want == 0.0:
			cur = 0.0
			to_erase.append(eid)
		rec[1] = cur
		ent.set_occ_fade(cur, cam_p, mech_c)
	for eid in to_erase:
		_occ_faded_enemies.erase(eid)


func _process_impl(delta: float) -> void:
	if Net.is_dedicated_server():
		if ended or dropping:
			return
		time += delta
		_update_transport(delta)
		return
	if mech == null:
		return
	var ui_block: bool = hud != null and (hud.pause_panel.visible or (hud.settings_panel != null and hud.settings_panel.visible) or hud.loot_panel.visible or hud.map_open())
	var story_block: bool = Story.get("flow") != null and Story.flow.is_playing()
	if hud != null and hud.joy_left != null and hud.joy_right != null:
		if dropping or ended or ui_block or story_block or mech.input_locked:
			if hud.joy_left.is_active():
				hud.joy_left.release()
			if hud.joy_right.is_active():
				hud.joy_right.release()
			if hud.joy_fire != null and hud.joy_fire.is_held():
				hud.joy_fire.release()
			mech.joy_move = Vector2.ZERO
			mech.joy_aim = Vector2.ZERO
		else:
			mech.joy_move = hud.joy_left.value if hud.joy_left.is_active() else Vector2.ZERO
			mech.joy_aim = hud.joy_right.value if hud.joy_right.is_active() else Vector2.ZERO
	var aiming: bool = mech.is_aiming and not dropping and not ended and not ui_block and not story_block
	var scoping: bool = aiming and mech.is_scoping()
	var recon_pts := 0.0
	if mech.get("stats") != null:
		recon_pts = float(mech.stats.get("recon", 0.0)) + (1.0 if bool(mech.stats.get("recon_tag", false)) else 0.0)
	var ray_max := 160.0 if mech.is_scoping() else (110.0 if mech.is_aiming else 80.0)

	if is_first_person():
		if hud != null and hud.joy_right != null and hud.joy_right.is_active() and not ui_block and not story_block:
			var jd: Vector2 = hud.joy_right.consume_drag_delta()
			if jd.length_squared() > 0.0001:
				_apply_fp_look_delta(jd, 1.35)
		var fov_want := FP_FOV_SCOPE if scoping else (FP_FOV_AIM if aiming else FP_FOV_STD)
		_fp_fov = lerpf(_fp_fov, fov_want, clampf(delta * 10.0, 0.0, 1.0))
		camera.fov = _fp_fov
		if shake > 0.0:
			shake = maxf(0.0, shake - delta)
		sync_fp_camera()
		if aim_override != null:
			mech.aim_point = aim_override
		else:
			var look_dir := Vector3(-sin(fp_yaw) * cos(fp_pitch), sin(fp_pitch), -cos(fp_yaw) * cos(fp_pitch)).normalized()
			var ray_from := camera.global_position
			var ray_to := ray_from + look_dir * ray_max
			var rq := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1 | 4 | 16, [mech.get_rid()])
			var rhit := get_world_3d().direct_space_state.intersect_ray(rq)
			if not rhit.is_empty():
				var hp: Vector3 = rhit.position
				if hp.distance_to(ray_from) < 2.2:
					hp = ray_from + look_dir * 2.2
				mech.aim_point = hp
			else:
				mech.aim_point = ray_to
		cam_focus = mech.global_position
	else:
		# 镜头跟随 + 双摇杆瞄准 / 鼠标前探
		var vp_sz := get_viewport().get_visible_rect().size
		var mp := get_viewport().get_mouse_position().clamp(Vector2.ZERO, vp_sz)
		var from := camera.project_ray_origin(mp)
		var dir := camera.project_ray_normal(mp)
		var hit = Plane(Vector3.UP, 1.8).intersects_ray(from, dir) if dir.y < -0.05 else null
		if hit != null:
			var hd: Vector3 = hit - mech.global_position
			hd.y = 0.0
			if hd.length() > ray_max:
				hit = mech.global_position + hd.normalized() * ray_max
				hit.y = 1.8
		if aim_override != null:
			mech.aim_point = aim_override
		elif hud != null and hud.joy_right != null and hud.joy_right.is_active() and hud.joy_right.value.length() > 0.12:
			_joy_aim_active = true
			var jv: Vector2 = hud.joy_right.value
			_last_joy_aim = Vector3(jv.x, 0.0, jv.y).normalized()
			mech.aim_point = mech.global_position + _last_joy_aim * (6.0 + jv.length() * 12.0)
			_last_mouse_pos = mp
		elif _joy_aim_active:
			if mp.distance_to(_last_mouse_pos) > 6.0 and (hud == null or not hud.is_touch_busy()):
				_joy_aim_active = false
				if hit != null:
					mech.aim_point = hit
			else:
				mech.aim_point = mech.global_position + _last_joy_aim * 10.0
		elif hit != null and (hud == null or not hud.is_touch_busy()):
			mech.aim_point = hit
			_last_mouse_pos = mp
		var pan_cap := 4.5
		var zoom_want := cam_zoom
		var lerp_spd := 10.0 if dropping else 6.0
		if scoping:
			pan_cap = 70.0 + clampf(recon_pts, 0.0, 8.0) * 5.0
			lerp_spd = 7.5
		elif aiming:
			pan_cap = 45.0 + clampf(recon_pts, 0.0, 8.0) * 3.5
			lerp_spd = 7.0
		# 瞄准只改变地面观察中心，不改变滚轮设定的高度和俯角；允许机体离屏。
		_eff_zoom = lerpf(_eff_zoom, zoom_want, clampf(delta * 7.5, 0.0, 1.0))
		var pan_want := Vector3.ZERO
		if coop != null and (mech.net_done or mech.dead):
			pan_want = Vector3.ZERO
		elif aiming:
			if aim_override != null or _joy_aim_active or (hud != null and hud.is_touch_busy()):
				var av := Vector3(mech.aim_point.x - mech.global_position.x, 0.0, mech.aim_point.z - mech.global_position.z)
				pan_want = av.limit_length(pan_cap)
			else:
				var sc_nx := (mp.x - vp_sz.x * 0.5) / maxf(vp_sz.x * 0.45, 1.0)
				var sc_ny := (mp.y - vp_sz.y * 0.5) / maxf(vp_sz.y * 0.45, 1.0)
				var asp := _view_aspect_now()
				var sv := Vector2(sc_nx * clampf(asp * 0.72, 0.9, 1.4), sc_ny)
				if sv.length() > 0.05:
					pan_want = Vector3(sv.x, 0.0, sv.y).limit_length(1.0) * pan_cap
		else:
			pan_want = Vector3(mech.aim_point.x - mech.global_position.x, 0.0, mech.aim_point.z - mech.global_position.z).limit_length(12.0) * 0.25
		_aim_pan = _aim_pan.lerp(pan_want, clampf(delta * lerp_spd, 0.0, 1.0))
		var base_pos: Vector3 = coop.view_position() if (coop != null and (mech.net_done or mech.dead)) else mech.global_position
		var look: Vector3 = base_pos + _aim_pan
		look.y = clampf((mech.global_position.y - 0.2) * 0.22, 0.0, 6.5) if dropping else 0.0
		cam_focus = look
		var want: Vector3 = look + CAM_OFFSET * _eff_zoom
		camera.global_position = camera.global_position.lerp(want, clampf(lerp_spd * delta, 0.0, 1.0))
		if shake > 0.0:
			shake = max(0.0, shake - delta)
			camera.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.6
		camera.look_at(camera.global_position - CAM_OFFSET * _eff_zoom, Vector3.UP)
		_update_cam_dof(scoping)
	var stage_t := Prof.t0()
	_update_occluder_fade(delta)
	Prof.add("raid.occlusion", stage_t)

	var tt := Time.get_ticks_msec() * 0.001
	var fl_ref: Vector3 = cam_focus if cam_focus != Vector3.ZERO else (mech.global_position as Vector3)
	for f in flicker_lights:
		var fl_node: Light3D = f[0]
		if is_instance_valid(fl_node):
			if fl_node.global_position.distance_squared_to(fl_ref) > 68.0 * 68.0:
				continue
			var k: float = 0.82 + 0.12 * sin(tt * 13.0 + f[2]) + 0.08 * sin(tt * 31.0 + f[2] * 2.0)
			if fmod(tt + f[2], 7.0) < 0.12:
				k *= 0.3
			fl_node.light_energy = f[1] * k
	if is_first_person():
		var f_xz := fp_forward_xz()
		var r_xz := Vector3(-f_xz.z, 0.0, f_xz.x)
		if smoke:
			smoke.global_position = mech.global_position + f_xz * 14.0 - r_xz * 6.0 + Vector3(0.0, 4.0, 0.0)
		if ash:
			ash.global_position = mech.global_position + f_xz * 12.0 + Vector3(0.0, 5.5, 0.0)
		if listener:
			listener.global_transform = camera.global_transform
	else:
		if smoke:
			smoke.global_position = Vector3(camera.global_position.x - 10.0, 4.0, camera.global_position.z - 21.0)
		if ash:
			ash.global_position = Vector3(camera.global_position.x, 6.0, camera.global_position.z - 21.0)
		if listener:
			var lp: Vector3 = mech.global_position + Vector3(0, 6.0, 0)
			listener.global_transform = Transform3D(Basis.IDENTITY, lp).looking_at(lp - CAM_OFFSET, Vector3.UP)
	if ended or dropping:
		hud.refresh()
		return

	if coop == null or Net.is_host():
		time += delta
	stage_t = Prof.t0()
	_update_subregion(mech.global_position)
	Prof.add("raid.subregion", stage_t)
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.25
		stage_t = Prof.t0()
		_threat_scan(0.25)
		Prof.add("raid.threat", stage_t)
	if coop == null:
		_update_transport(delta)
		_update_extract(delta)
		_update_loot(delta)
	else:
		if Net.is_host(): _update_transport(delta)
		_coop_loot_input()
	if Input.is_action_just_pressed("call_transport"):
		call_transport()
	if Input.is_action_just_pressed("inventory") and Engine.get_process_frames() - hud.last_toggle_frame > 2:
		hud.toggle_inventory()
	if Input.is_action_just_pressed("map"):
		hud.toggle_map()
	if Input.is_action_just_pressed("pause") and Engine.get_process_frames() - hud.last_toggle_frame > 2:
		if hud.map_open():
			hud.toggle_map()
		elif open_box or hud.inv_open():
			close_box()
		else:
			hud.toggle_pause()
	hud.refresh()


## 已搜容器数：HUD 要用，但遍历全部容器很贵，0.5 秒缓存一次
var _sc_cache := Vector2i.ZERO
var _sc_ms := -100000
func searched_count() -> Vector2i:
	var now := Time.get_ticks_msec()
	if now - _sc_ms < 500:
		return _sc_cache
	_sc_ms = now
	_sc_cache = _searched_count()
	return _sc_cache


func _searched_count() -> Vector2i:
	var done := 0
	var all := 0
	for b in get_tree().get_nodes_in_group("lootboxes"):
		if b.kind == "bug" or b.kind == "nest":
			continue
		all += 1
		if b.items.is_empty():
			done += 1
	return Vector2i(done, all)


## 交战状态（28 米内有追击中的虫子即进入；40 米内没有追击者满 6 秒才脱离）、本次行动首次遇到的敌人种类、发现 POI
func _threat_scan(dt: float) -> void:
	var mp: Vector3 = mech.global_position
	var near_chase_sq := INF
	for b in get_tree().get_nodes_in_group("bugs"):
		var d2: float = b.global_position.distance_squared_to(mp)
		if b.state == "chase" and d2 < near_chase_sq:
			near_chase_sq = d2
		if d2 < 26.0 * 26.0 and not _seen_kinds.has(b.kind) and not bool(b.data.get("boss", false)):
			_seen_kinds[b.kind] = true
			_event("enemy_seen", [b.kind, GameData.mark_enemy_seen(b.kind), b.global_position])
	if near_chase_sq < 28.0 * 28.0:
		_combat_quiet = 0.0
		if not in_combat:
			in_combat = true
			_event("combat_changed", [true])
	elif in_combat:
		_combat_quiet = _combat_quiet + dt if near_chase_sq > 40.0 * 40.0 else 0.0
		if _combat_quiet >= 6.0:
			in_combat = false
			_event("combat_changed", [false])
	for i in poi_centers.size():
		if _found_pois.has(i):
			continue
		var c: Vector3 = poi_centers[i]
		if Vector2(c.x - mp.x, c.z - mp.z).length() < 16.0:
			_found_pois[i] = true
			var pid: String = poi_ids[i]
			_event("poi_discovered", [pid, str(GameData.POIS.get(pid, {}).get("name", pid)), c])


func _update_extract(delta: float) -> void:
	var inside = null
	for z in extracts:
		if z.contains(mech.global_position):
			inside = z
	if transport_zone and transport_state == "landed" and transport_zone.contains(mech.global_position):
		inside = transport_zone
	if inside != extract_target:
		if extract_target and is_instance_valid(extract_target):
			Audio.play_sfx("extract_cancel")
			_event("extract_cancelled", [extract_target.title])
		extract_progress = 0.0
		extract_target = inside
		if inside:
			Audio.play_sfx("extract_start")
			_event("extract_started", [inside.title, inside.need, inside.is_transport])
	if inside:
		var covert_mul := 1.0 / maxf(0.76, 1.0 - 0.02 * float(Growth.ability_level("ab_covert")))
		extract_progress += delta * covert_mul
		if extract_progress >= inside.need:
			Audio.play_sfx("extract_success")
			_event("extract_completed", [inside.title, inside.is_transport])
			_finish(true, Loc.t("成功撤离（%s）" % inside.title, "Extracted (%s)" % inside.title))
	else:
		extract_progress = 0.0


func call_transport() -> void:
	if coop != null and coop.route("transport", []):
		return
	if transport_state != "none":
		hud.msg(Loc.t("运输机已在降落航线上，无需重复呼叫", "Transport already inbound on approach vector"))
		Audio.play_sfx("use_denied")
		return
	if not mech.cargo.has("beacon"):
		hud.msg(Loc.t("货舱内未携带呼叫信标", "No recall beacon in cargo"))
		Audio.play_sfx("use_denied")
		return
	mech.cargo.erase("beacon")
	mech.check_overload()
	transport_state = "incoming"
	transport_t = 40.0
	transport_zone = ExtractScript.new()
	world.add_child(transport_zone)
	transport_zone.position = Vector3(mech.global_position.x, 0, mech.global_position.z)
	transport_zone.setup(Loc.t("运输机降落区", "Dropship LZ"), Color(1.0, 0.75, 0.2), 3.0, true)
	hud.msg(Loc.t("脉冲信标升空，「信天翁-2」40 秒后切入降落航线；信标蜂鸣正把附近的虫群引过来。", "Pulse beacon launched — Albatross-02 inbound in 40s; beacon pings are drawing nearby bugs."))
	Audio.play_sfx("use_beacon")
	_event("item_used", ["beacon"])
	_event("transport_called", [transport_zone.position, transport_t])
	alert_noise(mech.global_position, 40.0)


func _update_transport(delta: float) -> void:
	if transport_state == "incoming":
		transport_t -= delta
		if transport_t <= 0.0:
			transport_state = "landed"
			transport_t = 25.0
			_spawn_transport_ship()
			hud.msg(Loc.t("「信天翁-2」强行着陆，舱门悬停开启 25 秒；引擎轰鸣正把周围的虫群引向降落点。", "Albatross-02 touching down — ramp open for 25s; thruster roar is drawing nearby bugs to the LZ."))
			_event("transport_landed", [transport_zone.position, transport_t])
			alert_noise(transport_zone.global_position, 45.0)
	elif transport_state == "landed":
		transport_t -= delta
		if transport_t <= 0.0:
			transport_state = "gone"
			transport_zone.set_active(false)
			Audio.loop_stop("transport_idle", 1.0)
			if transport_ship:
				Audio.play_sfx("transport_depart", transport_ship.global_position)
				var tw := create_tween()
				tw.tween_property(transport_ship, "position:y", 60.0, 2.5)
				tw.tween_callback(transport_ship.queue_free)
			hud.msg(Loc.t("「信天翁-2」悬停超时拉起返航，这趟只能走地面固定撤离点了。", "Albatross-02 aborting hover and ascending — use ground extraction points."))
			_event("transport_departed", [])


func _spawn_transport_ship() -> void:
	# 重型四发矢量撤离运输机「信天翁-2」(ALBATROSS-02)：预合并高精硬表面机身 + 四发倾转喷口补光 + 探照灯 + 落地扬尘
	transport_ship = Node3D.new()
	world.add_child(transport_ship)
	transport_ship.position = transport_zone.position + Vector3(0, 50, 0)
	var vtol := PrefabLib.build_merged("veh_transport_vtol")
	vtol.position = Vector3(0.0, -1.6, 0.0)
	transport_ship.add_child(vtol)
	for sx in [-5.18, 5.18]:
		var l := OmniLight3D.new()
		l.light_color = Color(0.4, 0.8, 1.0)
		l.light_energy = 3.0
		l.omni_range = 9.0
		l.position = Vector3(sx, -0.35, 0.45)
		transport_ship.add_child(l)
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.95, 0.85)
	spot.light_energy = 6.0
	spot.spot_range = 32.0
	spot.spot_angle = 30.0
	spot.position = Vector3(0, -0.7, -5.2)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	transport_ship.add_child(spot)
	var dust := A.emitter(transport_ship, Vector3(0, -4.4, 0), {"amount": 40, "life": 1.2, "size": 2.0, "tex": A.smoke_tex(), "additive": false,
		"dir": Vector3(0, 0.1, 0), "spread": 180.0, "vmin": 6.0, "vmax": 10.0, "gravity": Vector3.ZERO, "radius": 2.0,
		"c0": Color(0.6, 0.52, 0.45, 0.5), "c1": Color(0.5, 0.45, 0.4, 0.0), "grow0": 0.6, "grow1": 2.0})
	dust.emitting = false
	Audio.play_sfx("transport_arrive", transport_zone.global_position + Vector3(0, 8, 0))
	var tw := create_tween()
	tw.tween_property(transport_ship, "position:y", transport_zone.position.y + 4.6, 2.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(func():
		dust.emitting = true
		if transport_state == "landed":
			Audio.loop_start("transport_idle", "transport_idle_loop", transport_ship))


# ================= 容器 / 搜刮 =================
func _box_los_ok(b) -> bool:
	if mech == null or b == null:
		return false
	var w3 := get_world_3d()
	if w3 == null or w3.direct_space_state == null:
		return true
	if _box_ray_q == null:
		_box_ray_q = PhysicsRayQueryParameters3D.new()
		_box_ray_q.collision_mask = 1
	_box_ray_q.from = mech.global_position + Vector3(0, 1.1, 0)
	_box_ray_q.to = b.global_position + Vector3(0, 0.65, 0)
	var ex: Array = []
	if mech is CollisionObject3D:
		ex.append(mech.get_rid())
	if b is CollisionObject3D:
		ex.append(b.get_rid())
	_box_ray_q.exclude = ex
	return w3.direct_space_state.intersect_ray(_box_ray_q).is_empty()


func nearest_box(maxd: float):
	var best = null
	var bd2 := maxd * maxd
	var mp: Vector3 = mech.global_position
	for b in get_tree().get_nodes_in_group("lootboxes"):
		var d2: float = b.global_position.distance_squared_to(mp)
		if d2 < bd2 and _box_los_ok(b):
			bd2 = d2
			best = b
	return best


func _update_loot(delta: float) -> void:
	if open_box:
		if not is_instance_valid(open_box) or open_box.global_position.distance_squared_to(mech.global_position) > 4.5 * 4.5:
			close_box()
			return
		if open_box.revealed < open_box.items.size():
			open_box.reveal_t += delta
			var base_t: float = float(GameData.LOOT_TIER_TIME.get(int(open_box.tier), 0.55))
			var skill_f := maxf(0.5, 1.0 - 0.04 * float(Growth.ability_level("ab_search")))
			# 破拆能力看底盘承重：重型底盘有液压支撑，拆装甲锁具更快；轻型要一点点撬
			var rig_f := clampf(1.60 - 0.70 * clampf(float(mech.stats.get("load", 48.0)) / 120.0, 0.0, 1.0), 0.90, 1.35)
			var reveal_step := base_t * skill_f * rig_f
			if open_box.reveal_t >= reveal_step:
				open_box.reveal_t = 0.0
				open_box.revealed += 1
				var rid: String = open_box.items[open_box.revealed - 1]
				var rar := int(GameData.item(rid).rar)
				Audio.play_sfx(["loot_reveal_rare", "loot_reveal"] if rar >= 2 else "loot_reveal")
				_event("item_revealed", [rid, rar])
				hud.refresh_loot()
		if Input.is_action_just_pressed("interact"):
			close_box()
		return
	var b = nearest_box(3.6)
	if b != _near_box:
		if is_instance_valid(_near_box):
			_near_box.set_near(false)
		_near_box = b
	if is_instance_valid(_near_box):
		_near_box.set_near(true)
	if hud.inv_open():
		hud.set_prompt("")
		if b and Input.is_action_just_pressed("interact"):
			open_container(b)
		return
	hud.set_prompt(b.title if b else "")
	if b and Input.is_action_just_pressed("interact"):
		open_container(b)


func interact_nearest() -> void:
	if open_box:
		close_box()
		return
	var b = nearest_box(3.6)
	if b:
		open_container(b)


## 打开容器：锁定移动、打开搜刮面板，物品随后逐个显现
func open_container(b) -> void:
	if coop != null and coop.route("open", [int(b.get_meta("net_id", 0))]):
		return
	open_box = b
	mech.input_locked = true
	if Growth.ability_elite("ab_search") and b.revealed == 0 and not b.items.is_empty():
		b.revealed = 1
		var rid0: String = b.items[0]
		_event("item_revealed", [rid0, int(GameData.item(rid0).rar)])
	hud.open_loot(b)
	hud.set_prompt("")   # 面板开着时不显示「搜索」提示；关上面板后下一帧按附近的容器重新给出
	Audio.play_sfx(["loot_open_" + str(b.kind), "loot_open"])
	_event("box_opened", [str(b.kind), b.global_position])


func close_box() -> void:
	if coop != null and coop.route("close", []):
		return
	if open_box and is_instance_valid(open_box):
		Audio.play_sfx("loot_close")
		open_box.refresh_glow()
		if (open_box.kind == "bug" or open_box.kind == "nest") and open_box.items.is_empty():
			open_box.queue_free()
	open_box = null
	mech.input_locked = false
	hud.close_loot()


func take_from_box(index: int) -> void:
	if coop != null and coop.route("take", [index]):
		return
	if open_box == null or index < 0 or index >= open_box.revealed or index >= open_box.items.size():
		return
	var id: String = open_box.items[index]
	if mech.cargo_weight() + float(GameData.item(id).w) > mech.cargo_cap() + 0.001:
		hud.msg(Loc.t("货舱承重已满（%.1f/%.0f kg），装不下这件物资了" % [mech.cargo_weight(), mech.cargo_cap()], "Cargo load full (%.1f/%.0f kg) — cannot fit item" % [mech.cargo_weight(), mech.cargo_cap()]))
		Audio.play_sfx("cargo_full")
		_event("cargo_full", [id])
		return
	var next_c: Array = mech.cargo.duplicate()
	next_c.append(id)
	if not GameData.can_pack_cargo(next_c, mech.cargo_cap()):
		var gsz: Vector2i = GameData.item_grid_size(id)
		hud.msg(Loc.t("货舱格位不足，无法放入 %d×%d 物资" % [gsz.x, gsz.y], "Insufficient cargo grid space for %d×%d item" % [gsz.x, gsz.y]))
		Audio.play_sfx("cargo_full")
		_event("cargo_full", [id])
		return
	open_box.items.remove_at(index)
	open_box.revealed -= 1
	mech.cargo.append(id)
	GameData.pack_cargo_inplace(mech.cargo, mech.cargo_cap())
	Audio.play_sfx("loot_take")
	_event("item_picked", [id, int(GameData.item(id).rar)])
	mech.check_overload()
	hud.refresh_loot()


func take_all_from_box() -> int:
	if coop != null and coop.route("take_all", []):
		return 0
	if open_box == null:
		return 0
	var count := 0
	var i := 0
	while i < open_box.revealed and i < open_box.items.size():
		var id: String = open_box.items[i]
		if mech.can_fit_cargo_item(id):
			open_box.items.remove_at(i)
			open_box.revealed -= 1
			mech.cargo.append(id)
			GameData.pack_cargo_inplace(mech.cargo, mech.cargo_cap())
			_event("item_picked", [id, int(GameData.item(id).rar)])
			count += 1
		else:
			i += 1
	if count > 0:
		Audio.play_sfx("loot_take")
		mech.check_overload()
		hud.refresh_loot()
	elif open_box.revealed > 0:
		hud.msg(Loc.t("货舱剩余承重或格位不足，无法继续装载", "Insufficient cargo weight or grid space"))
		Audio.play_sfx("cargo_full")
	return count


func put_into_box(index: int) -> void:
	if coop != null and coop.route("put", [index]):
		return
	if open_box == null or index < 0 or index >= mech.cargo.size():
		return
	var id: String = mech.cargo[index]
	mech.cargo.remove_at(index)
	open_box.items.insert(0, id)
	open_box.revealed += 1
	Audio.play_sfx("loot_put")
	mech.check_overload()
	hud.refresh_loot()


func discard_from_cargo(index: int) -> void:
	if coop != null and coop.route("discard", [index]):
		return
	if index < 0 or index >= mech.cargo.size():
		return
	if open_box != null:
		put_into_box(index)
		return
	var id: String = mech.cargo[index]
	var it := GameData.item(id)
	mech.cargo.remove_at(index)
	var nb = nearest_box(3.6)
	if nb != null and is_instance_valid(nb):
		nb.items.insert(0, id)
		nb.revealed += 1
		nb.refresh_glow()
		hud.msg(Loc.t("已将 %s 弃置到附近容器 [%s]" % [str(it.name), str(nb.title)], "Dropped %s into nearby [%s]" % [str(it.name), str(nb.title)]))
	else:
		hud.msg(Loc.t("已丢弃物资：%s (%.1fkg)" % [str(it.name), float(it.w)], "Jettisoned: %s (%.1fkg)" % [str(it.name), float(it.w)]))
	Audio.play_sfx("loot_put")
	mech.check_overload()
	hud.refresh_loot()


func equip_from_cargo(cargo_idx: int, target_slot: String = "") -> bool:
	if coop != null and coop.route("equip_cargo", [cargo_idx, target_slot]):
		return false
	if cargo_idx < 0 or cargo_idx >= mech.cargo.size():
		return false
	var id: String = mech.cargo[cargo_idx]
	if not GameData.is_module(id):
		return false
	var it := GameData.item(id)
	var m_slot := str(it.get("slot", ""))
	var slot := target_slot
	if slot == "":
		slot = "arm_l" if m_slot == "arm" else m_slot
	if not GameData.slot_accepts(slot, id):
		hud.msg(Loc.t("槽位不匹配：该模块无法安装至 [%s]" % str(GameData.SLOT_NAMES.get(slot, slot)), "Slot mismatch: cannot mount in [%s]" % str(GameData.SLOT_NAMES.get(slot, slot))))
		Audio.play_sfx("ui_Click_Deny")
		return false
	var cur_id: String = str(mech.loadout.get(slot, ""))
	var next_lo: Dictionary = mech.loadout.duplicate()
	next_lo[slot] = id
	var next_cap: float = float(GameData.compute_stats(next_lo).cargo)
	var next_cargo: Array = mech.cargo.duplicate()
	if cur_id != "":
		next_cargo[cargo_idx] = cur_id
	else:
		next_cargo.remove_at(cargo_idx)
	if not GameData.can_pack_cargo(next_cargo, next_cap):
		hud.msg(Loc.t("货舱格位不足，卸下的模块无法放入货舱", "Cargo grid lacks space for the unequipped module"))
		Audio.play_sfx("cargo_full")
		return false
	var old_id: String = mech.equip_module_in_raid(slot, id)
	if old_id != "":
		mech.cargo[cargo_idx] = old_id
	else:
		mech.cargo.remove_at(cargo_idx)
	GameData.pack_cargo_inplace(mech.cargo, mech.cargo_cap())
	Audio.play_sfx("loot_take")
	hud.msg(Loc.t("战地换装完成：[%s] %s" % [str(GameData.SLOT_NAMES.get(slot, slot)), str(it.name)], "Field swap complete: [%s] %s" % [str(GameData.SLOT_NAMES.get(slot, slot)), str(it.name)]))
	mech.check_overload()
	hud.refresh_loot()
	return true


func equip_from_box(box_idx: int, target_slot: String = "") -> bool:
	if coop != null and coop.route("equip_box", [box_idx, target_slot]):
		return false
	if open_box == null or box_idx < 0 or box_idx >= open_box.revealed or box_idx >= open_box.items.size():
		return false
	var id: String = open_box.items[box_idx]
	if not GameData.is_module(id):
		return false
	var it := GameData.item(id)
	var m_slot := str(it.get("slot", ""))
	var slot := target_slot
	if slot == "":
		slot = "arm_l" if m_slot == "arm" else m_slot
	if not GameData.slot_accepts(slot, id):
		hud.msg(Loc.t("槽位不匹配：该模块无法安装至 [%s]" % str(GameData.SLOT_NAMES.get(slot, slot)), "Slot mismatch: cannot mount in [%s]" % str(GameData.SLOT_NAMES.get(slot, slot))))
		Audio.play_sfx("ui_Click_Deny")
		return false
	var next_lo: Dictionary = mech.loadout.duplicate()
	next_lo[slot] = id
	var next_cap: float = float(GameData.compute_stats(next_lo).cargo)
	if next_cap < float(mech.cargo_cap()) - 0.01 and not GameData.can_pack_cargo(mech.cargo, next_cap):
		hud.msg(Loc.t("更换该模块后货舱格位将不足，请先清理部分物资", "Insufficient cargo grid space after module swap"))
		Audio.play_sfx("cargo_full")
		return false
	var old_id: String = mech.equip_module_in_raid(slot, id)
	if old_id != "":
		open_box.items[box_idx] = old_id
	else:
		open_box.items.remove_at(box_idx)
		open_box.revealed -= 1
	GameData.pack_cargo_inplace(mech.cargo, mech.cargo_cap())
	Audio.play_sfx("loot_take")
	_event("item_picked", [id, int(it.rar)])
	hud.msg(Loc.t("战地直接换装：[%s] %s" % [str(GameData.SLOT_NAMES.get(slot, slot)), str(it.name)], "Field direct swap: [%s] %s" % [str(GameData.SLOT_NAMES.get(slot, slot)), str(it.name)]))
	mech.check_overload()
	hud.refresh_loot()
	return true


func use_from_box(box_idx: int) -> bool:
	if coop != null and coop.route("use_box", [box_idx]):
		return false
	if open_box == null or box_idx < 0 or box_idx >= open_box.revealed or box_idx >= open_box.items.size():
		return false
	var id: String = open_box.items[box_idx]
	if not mech.can_use_item(id):
		return false
	if not mech.use_item_effect(id):
		return false
	open_box.items.remove_at(box_idx)
	open_box.revealed -= 1
	hud.refresh_loot()
	return true


func sort_cargo() -> void:
	if coop != null and coop.route("sort", []):
		return
	var cat_order := {"module": 0, "use": 1, "food": 1, "money": 2, "misc": 3}
	mech.cargo.sort_custom(func(a: String, b: String) -> bool:
		var sa: Vector2i = GameData.item_grid_size(a)
		var sb: Vector2i = GameData.item_grid_size(b)
		var area_a: int = sa.x * sa.y
		var area_b: int = sb.x * sb.y
		if area_a != area_b:
			return area_a > area_b
		var max_a: int = maxi(sa.x, sa.y)
		var max_b: int = maxi(sb.x, sb.y)
		if max_a != max_b:
			return max_a > max_b
		var ia := GameData.item(a)
		var ib := GameData.item(b)
		var ca: int = int(cat_order.get(str(ia.get("cat", "misc")), 4))
		var cb: int = int(cat_order.get(str(ib.get("cat", "misc")), 4))
		if ca != cb:
			return ca < cb
		var ra: int = int(ia.get("rar", 0))
		var rb: int = int(ib.get("rar", 0))
		if ra != rb:
			return ra > rb
		var va: int = int(ia.get("v", 0))
		var vb: int = int(ib.get("v", 0))
		if va != vb:
			return va > vb
		return a < b
	)
	GameData.pack_cargo_inplace(mech.cargo, mech.cargo_cap())
	Audio.play_sfx("ui_Click_Confirm")
	hud.refresh_loot()


# ================= 战斗 =================
## 生成一只敌人。种类数值来自 GameData.ENEMIES；条目带 script 时用它实例化（继承 bug.gd 的新种类与 Boss）
func spawn_bug(kind: String, pos: Vector3, cap := MAX_BUGS):
	var info: Dictionary = GameData.ENEMIES.get(kind, {})
	if info.is_empty():
		push_warning("未登记的敌人种类：%s" % kind)
		return null
	if not bool(info.get("boss", false)) and get_tree().get_nodes_in_group("bugs").size() >= cap:
		return null
	var b = load(str(info.script)).new() if info.has("script") else BugScript.new()
	pos = dry_spot(pos, 1.5)
	if nav != null and not bool(info.get("boss", false)) and not nav.is_reachable(pos, false, 0.0):
		var rp: Vector3 = nav.nearest_reachable(pos, false, 20.0)
		if rp != Vector3.INF:
			pos = Vector3(rp.x, pos.y, rp.z)
	world.add_child(b)
	b.position = pos
	b.home = pos
	b.setup(kind, self, mech)
	return b


func nearest_bug(p: Vector3, maxd: float, include_boss := true):
	var best = null
	var bd2 := maxd * maxd
	for b in get_tree().get_nodes_in_group("bugs"):
		if b.is_in_group("boss"):
			if not include_boss or not b.awake:
				continue
		var d2: float = b.global_position.distance_squared_to(p)
		if d2 < bd2:
			bd2 = d2
			best = b
	return best


func alert_noise(p: Vector3, radius: float) -> void:
	var r2 := radius * radius
	for b in get_tree().get_nodes_in_group("bugs"):
		if b.global_position.distance_squared_to(p) < r2:
			b.alert(p)


# ================= AI：视野 / 导航 =================
## 玩家视野：镜头在默认（最远）一档 ZOOM_MAX 时，把视锥四条屏幕边投到地面（y = 0），得到机甲周围的可见梯形。
##   斜俯视下梯形不对称：机甲到屏幕下边最近（约 19.6 米），到上边约 27.4 米，到左右边约 36 米（1280x720，FOV 36°）。
##   player_view_range() 取「上边与左右边里较近的那条」= 机甲正前方到屏幕上边的距离，作为玩家视野的标量（约 27.4 米）。
## 敌人视野：vision_range() = VISION_FACTOR × 玩家视野（约 24.7 米），是所有敌人察觉距离的上限；
##   看的对象是玩家机甲时再按方向收紧到 VISION_FACTOR × 该方向的屏幕边距离（vision_toward）——
##   站在机甲下方（屏幕下边只有 19.6 米）的虫最多 17.6 米就能看到，保证「敌人看到你之前你一定先在屏幕上看到它」。
## 受击锁定：被打的敌人锁定攻击者一路追，直到距离超过 lose_range() = LOSE_FACTOR × vision_range()（约 37 米）才丢失。
const VISION_FACTOR := 0.9
const LOSE_FACTOR := 1.5
const AGGRO_REF := 20.0     ## 数据表里的察觉距离按「20 米 = 满视野」换算：aggro × vision / 20，再封顶到 vision（保留各虫种远近的差别）
const EYE_H := 1.5          ## 视线射线的高度（胸口）
var nav                     ## 导航网格（scripts/nav_grid.gd），rebuild_nav() 生成
var _view_poly := PackedVector2Array()   ## 可见梯形（相对机甲的 XZ 偏移）
var _view_aspect := -1.0
var _view_range := 0.0


## 镜头宽高比：有窗口时取实际视口，无界面运行时按项目设置的 1280x720
func _view_aspect_now() -> float:
	var sz := Vector2(1280, 720)
	if DisplayServer.get_name() != "headless" and is_inside_tree():
		var r := get_viewport().get_visible_rect().size
		if r.x > 1.0 and r.y > 1.0:
			sz = r
	else:
		sz = Vector2(float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)), float(ProjectSettings.get_setting("display/window/size/viewport_height", 720)))
	return sz.x / sz.y


var _view_frame := -1
func update_view_zoom(snap_to_max := false) -> void:
	var vr := GameData.STD_RANGE
	if mech != null and mech.get("stats") != null:
		vr = float(mech.stats.get("view_range", GameData.STD_RANGE))
	var vr_hip := clampf(vr, GameData.STD_RANGE, 14.0)
	var old_max := ZOOM_MAX
	ZOOM_MAX = ZOOM_STD * (vr_hip / GameData.STD_RANGE)
	if snap_to_max or is_equal_approx(cam_zoom, old_max) or cam_zoom > ZOOM_MAX:
		cam_zoom = ZOOM_MAX
	else:
		cam_zoom = clampf(cam_zoom, ZOOM_MIN, ZOOM_MAX)
	if snap_to_max:
		_eff_zoom = cam_zoom


func _update_view() -> void:
	# 宽高比每个渲染帧最多查一次（感知里会被频繁调用）
	var fr := Engine.get_process_frames()
	if fr == _view_frame and not _view_poly.is_empty():
		return
	_view_frame = fr
	var asp := _view_aspect_now()
	if absf(asp - _view_aspect) < 0.001 and not _view_poly.is_empty():
		return
	_view_aspect = asp
	var fov: float = AI_VIEW_FOV_REF
	var off: Vector3 = CAM_OFFSET * AI_VIEW_ZOOM_REF
	var f := -off.normalized()
	var right := f.cross(Vector3.UP).normalized()
	var up := right.cross(f)
	var tv := tan(deg_to_rad(fov * 0.5))   # Camera3D 默认 KEEP_HEIGHT：fov 是竖直视角
	var th := tv * asp
	_view_poly = PackedVector2Array()
	for c in [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1)]:   # 左上、右上、右下、左下
		var d: Vector3 = f + right * c.x * th + up * c.y * tv
		var t := -off.y / minf(d.y, -0.01)
		var g: Vector3 = off + d * t
		_view_poly.append(Vector2(g.x, g.z))
	_view_range = minf(_view_extent(Vector2(0, -1)), minf(_view_extent(Vector2(1, 0)), _view_extent(Vector2(-1, 0))))


## 从机甲沿 XZ 方向 dir 走到屏幕边的距离
func _view_extent(dir: Vector2) -> float:
	var best := INF
	for i in 4:
		var a: Vector2 = _view_poly[i]
		var b: Vector2 = _view_poly[(i + 1) % 4]
		var e := b - a
		var den := dir.x * e.y - dir.y * e.x
		if absf(den) < 1e-6:
			continue
		var t := (a.x * e.y - a.y * e.x) / den
		var s := (a.x * dir.y - a.y * dir.x) / den
		if t > 0.0 and s >= -1e-4 and s <= 1.0001:
			best = minf(best, t)
	return best if best < INF else 0.0


## 玩家视野（米）：默认最远镜头下，机甲到屏幕上边 / 左右边中较近者
func player_view_range() -> float:
	_update_view()
	return _view_range


## 敌人视野上限（米）
func vision_range() -> float:
	return player_view_range() * VISION_FACTOR


## 锁定目标的丢失距离（米）
func lose_range() -> float:
	return vision_range() * LOSE_FACTOR


## 站在 p 的敌人最远多少米能看到玩家机甲：按方向收紧到该方向屏幕边距离 × VISION_FACTOR，再封顶 vision_range()
func vision_toward_player(p: Vector3) -> float:
	_update_view()
	if mech == null:
		return vision_range()
	var d := Vector2(p.x - mech.global_position.x, p.z - mech.global_position.z)
	if d.length_squared() < 0.01:
		return vision_range()
	return minf(vision_range(), _view_extent(d.normalized()) * VISION_FACTOR)


## 数据表里的察觉距离换算成实际察觉距离（见 AGGRO_REF）；<= 0 的（不主动索敌）保持不变
func scaled_aggro(raw: float) -> float:
	if raw <= 0.0:
		return raw
	var v := vision_range()
	return minf(raw * v / AGGRO_REF, v)


## 视线：两点胸口高度之间有没有静态地形（碰撞层 1）挡着
func has_los(a: Vector3, b: Vector3) -> bool:
	var _pt := Prof.t0()
	var q := PhysicsRayQueryParameters3D.create(a + Vector3(0, EYE_H, 0), b + Vector3(0, EYE_H, 0), 1)
	var r := get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	Prof.add("raid.has_los", _pt)
	return r


## 重新栅格化导航网格。地图建完时调用一次；碰撞后处理（合并 / 删除碰撞体）之后也应调用它
func rebuild_nav() -> void:
	nav = preload("res://scripts/nav_grid.gd").new()
	nav.build(self, HALF)
	print("[raid] nav grid %dx%d (%.1fm) from %d shapes in %.0f ms" % [nav.n, nav.n, nav.CELL, nav.shape_count, nav.build_ms])


## 跨区转场入口防贴脸：只清除站在转场口 24 米内的普通小虫，不扰动全局固定首领与分布
func _clear_transit_spawn_bugs(entry: Vector3) -> void:
	for b in get_tree().get_nodes_in_group("bugs"):
		if not is_instance_valid(b) or bool(b.data.get("boss", false)):
			continue
		if Vector2(b.global_position.x - entry.x, b.global_position.z - entry.z).length() < 24.0:
			b.queue_free()


## 剔除或重定位落在死胡同/封闭房间内的敌人、虫巢与物资箱
func _sanitize_spawns_and_loot(_drop: Vector3) -> void:
	if nav == null:
		return
	for b in get_tree().get_nodes_in_group("bugs"):
		if not is_instance_valid(b) or bool(b.data.get("boss", false)):
			continue
		if not nav.is_reachable(b.global_position, false, 0.0):
			var np: Vector3 = nav.nearest_reachable(b.global_position, false, 18.0)
			if np != Vector3.INF and in_bounds(np, 3.0):
				b.position = Vector3(np.x, b.position.y, np.z)
				b.home = b.position
			else:
				b.queue_free()
	for n in get_tree().get_nodes_in_group("nests"):
		if not is_instance_valid(n):
			continue
		if not nav.is_reachable(n.global_position, false, 0.0):
			var np: Vector3 = nav.nearest_reachable(n.global_position, false, 20.0)
			if np != Vector3.INF and in_bounds(np, 3.0):
				n.position = Vector3(np.x, n.position.y, np.z)
			else:
				n.queue_free()
	var kept_pos: Array = []
	for bx in get_tree().get_nodes_in_group("lootboxes"):
		if not is_instance_valid(bx):
			continue
		var p: Vector3 = bx.global_position
		if nav.is_reachable(p, true, 3.2):
			kept_pos.append(p)
			continue
		# 情境化贴墙箱只允许极小幅微调（≤2.8m），避免被硬挪到空地或马路正中；POI/档案箱保留较大容错
		var is_ctx := bx.has_meta("contextual_loot") and not bx.has_meta("poi")
		var max_nudge := 2.8 if is_ctx else 16.0
		var np: Vector3 = nav.nearest_reachable(p, true, max_nudge)
		if np != Vector3.INF and in_bounds(np, 3.0) and not in_wet(Vector2(np.x, np.z), 1.5) and (not is_ctx or not on_road(Vector2(np.x, np.z), 0.9)):
			var dup := false
			for kp: Vector3 in kept_pos:
				if Vector2(kp.x - np.x, kp.z - np.z).length() < 1.5:
					dup = true
					break
			if not dup:
				bx.position = Vector3(np.x, bx.position.y, np.z)
				kept_pos.append(bx.position)
				continue
		bx.queue_free()


func _sanitize_npcs() -> void:
	if nav == null:
		return
	for g in ["rovers", "allies"]:
		for n in get_tree().get_nodes_in_group(g):
			if not is_instance_valid(n):
				continue
			if not nav.is_reachable(n.global_position, true, 0.0):
				var np: Vector3 = nav.nearest_reachable(n.global_position, true, 24.0)
				if np != Vector3.INF and in_bounds(np, 3.0):
					n.position = Vector3(np.x, n.position.y, np.z)
					if "home" in n:
						n.home = n.position


## 能否站在 p（半径 r）：有导航网格时按网格（真实碰撞体），否则按建筑占地矩形
func ai_free(p: Vector3, r: float, is_mech := false) -> bool:
	if nav != null:
		if not nav.is_free(p, is_mech):
			return false
		# 比网格通行间隙更胖的单位：再查四个方向上多出来的那一截，免得直接平移时半个身子嵌进墙里
		var extra: float = r - (nav.R_MECH if is_mech else nav.R_BUG)
		if extra > 0.05:
			for o in [Vector3(extra, 0, 0), Vector3(-extra, 0, 0), Vector3(0, 0, extra), Vector3(0, 0, -extra)]:
				if not nav.is_free(p + o, is_mech):
					return false
		return true
	return patrol_free(p, r)


## 巡逻路点：优先挑从 from 直线走得到的空地，其次挑网格上可站的空地（巡逻时再沿 A* 走过去）
func ai_patrol_point(home: Vector3, radius: float, from: Vector3) -> Vector3:
	if nav == null:
		return patrol_point(home, radius, from)
	var fallback := Vector3.INF
	for t in 8:
		var p := patrol_point(home, radius, from)
		if not nav.is_free(p):
			continue
		if nav.line_clear(from, p):
			return p
		if fallback == Vector3.INF:
			fallback = p
	if fallback != Vector3.INF:
		return fallback
	return Vector3(home.x, 0, home.z)


## 局部避让用的空间哈希：每个物理帧最多建一次（只放追击中的近处虫），按 4 米格子分桶
const _SEP := 4.0
var _sep_frame := -1
var _sep := {}
func bug_neighbors(p: Vector3) -> Array:
	var f := Engine.get_physics_frames()
	if f != _sep_frame:
		_sep_frame = f
		_sep.clear()
		for b in get_tree().get_nodes_in_group("bugs"):
			if b.state == "chase" and b.lod == 0:
				var k := Vector2i(floori(b.global_position.x / _SEP), floori(b.global_position.z / _SEP))
				if _sep.has(k):
					_sep[k].append(b)
				else:
					_sep[k] = [b]
	var out: Array = []
	var cx := floori(p.x / _SEP)
	var cz := floori(p.z / _SEP)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var a = _sep.get(Vector2i(cx + dx, cz + dz))
			if a != null:
				out.append_array(a)
	return out


func _build_or_reuse_body(body: Node3D, cache_key: String, build_fn: Callable) -> void:
	if _bullet_meshes.has(cache_key):
		for entry: Array in _bullet_meshes[cache_key]:
			var mi := MeshInstance3D.new()
			mi.mesh = entry[0]
			mi.material_override = entry[1]
			mi.transform = entry[2]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			body.add_child(mi)
		return
	build_fn.call(body)
	if body.get_child_count() > 1:
		MechScript._batch_visual(body)
	var cached: Array = []
	for ch in body.get_children():
		if ch is MeshInstance3D:
			var cmi := ch as MeshInstance3D
			cached.append([cmi.mesh, cmi.material_override, cmi.transform])
	_bullet_meshes[cache_key] = cached


func _populate_proj_body(b_node: Node3D, kind: String, size: float) -> void:
	# 低面数整改 P0-MSL-01/02：弹体统一由高精弹药库生成（24~28 段车削弹身、后掠翼型弹翼、拉瓦尔喷管）
	match kind:
		"missile", "rocket", "vls":
			MM.build_missile(b_node, kind, size)
		_:
			MM.build_canister_round(b_node, kind, size)


func _proj(pos: Vector3, vel: Vector3, dmg: float, life: float, mask: int, c: Color, size: float, _glow := false, kind := "shell"):
	if coop != null and not _warming_fx: coop.emit_effect("shot", [pos, vel, life, c, size, kind])
	var p = ProjScript.new()
	p.raid = self
	p.vel = vel
	p.dmg = dmg
	p.life = life
	p.mask = mask
	p.color = c
	var body := Node3D.new()
	p.add_child(body)
	p.body_node = body
	match kind:
		"missile", "rocket", "vls":
			p.spin_spd = 14.0 if kind != "rocket" else 22.0
		"spit", "cryo":
			p.spin_spd = 18.0
		"flamer":
			p.spin_spd = 24.0
		_:
			p.spin_spd = 32.0
	var bkey := "pbody|%s|%.3f|%s" % [kind, size, c.to_html()]
	_build_or_reuse_body(body, bkey, _populate_proj_body.bind(kind, size))
	fx.add_child(p)
	p.global_position = pos
	if vel.length() > 0.1:
		p.look_at(pos + vel, Vector3.UP if abs(vel.normalized().y) < 0.95 else Vector3.FORWARD)
	return p


## 实体弹头与气动硝烟尾迹对象池：机甲小队齐射时每秒几十发，复用已批处理的实体金属弹头与非发光拉烟带
const TRACER_POOL_MAX := 64
var _tracer_pool := {}


func recycle_projectile(p) -> bool:
	var key: String = p.pool_key
	if key == "" or not is_instance_valid(fx) or p.get_parent() != fx:
		return false
	var pool: Array = _tracer_pool.get(key, [])
	if pool.size() >= TRACER_POOL_MAX:
		return false
	p.visible = false
	p.set_physics_process(false)
	pool.append(p)
	_tracer_pool[key] = pool
	return true


func _populate_tracer_body(b_node: Node3D, caliber: String, br: float, bl: float, c: Color) -> void:
	# 弹体建模在 munition_models（沿 +Y），此处把 +Y 转到飞行方向 -Z
	var holder := Node3D.new()
	b_node.add_child(holder)
	holder.rotation_degrees = Vector3(-90, 0, 0)
	MM.build_tracer_round(holder, caliber, br, bl, c)
	# 展平到 b_node 直接子节点（_build_or_reuse_body 只缓存直接子 MeshInstance3D）
	var stack: Array = [[holder, holder.transform]]
	var flat: Array = []
	while not stack.is_empty():
		var e: Array = stack.pop_back()
		var nd: Node3D = e[0]
		var xf: Transform3D = e[1]
		for ch in nd.get_children():
			var c3 := ch as Node3D
			if c3 == null:
				continue
			var cx: Transform3D = xf * c3.transform
			if c3 is MeshInstance3D:
				flat.append([c3, cx])
			stack.append([c3, cx])
	for f in flat:
		var mi: MeshInstance3D = f[0]
		mi.get_parent().remove_child(mi)
		for gc in mi.get_children():
			mi.remove_child(gc)
			gc.queue_free()
		b_node.add_child(mi)
		mi.transform = f[1]
	holder.queue_free()
	b_node.remove_child(holder)


func _tracer(pos: Vector3, vel: Vector3, dmg: float, life: float, c: Color, w: float, core: float, caliber := "mg"):
	if coop != null and not _warming_fx: coop.emit_effect("shot", [pos, vel, life, c, w, "tracer:" + caliber])
	var key := "%s|%s|%s|%s" % [c.to_html(), w, core, caliber]
	var br := clampf(core * 0.34, 0.020, 0.028)
	var bl := clampf(core * 3.2, 0.22, 0.30)
	var wake_w := 0.056
	var wake_len := 1.35
	match caliber:
		"apfsds":
			br = 0.026; bl = 0.48; wake_w = 0.118; wake_len = 3.80
		"sniper_ap":
			br = 0.028; bl = 0.48; wake_w = 0.124; wake_len = 4.20
		"sniper":
			br = 0.024; bl = 0.40; wake_w = 0.106; wake_len = 3.50
		"coil":
			br = 0.022; bl = 0.38; wake_w = 0.098; wake_len = 2.75
		"cannon":
			br = 0.048; bl = 0.46; wake_w = 0.155; wake_len = 1.95
		"ac30":
			br = 0.032; bl = 0.36; wake_w = 0.116; wake_len = 2.35
		"hmg":
			br = 0.024; bl = 0.28; wake_w = 0.096; wake_len = 1.75
		"slug":
			br = 0.028; bl = 0.28; wake_w = 0.108; wake_len = 1.60
		"pellet":
			br = 0.016; bl = 0.19; wake_w = 0.072; wake_len = 1.05
		_:
			br = 0.021; bl = 0.25; wake_w = 0.086; wake_len = 1.50
	var is_hi_vel := caliber in ["apfsds", "sniper", "sniper_ap", "coil"]
	var t_off := bl * 0.36
	var spin_v := 18.0 if (is_hi_vel or caliber == "cannon") else 38.0
	var up_ref := Vector3.UP if (vel.length_squared() < 0.01 or absf(vel.normalized().y) < 0.95) else Vector3.FORWARD
	var pool: Array = _tracer_pool.get(key, [])
	while not pool.is_empty():
		var q = pool.pop_back()
		if not is_instance_valid(q):
			continue
		q.reset_state()
		q.raid = self
		q.vel = vel
		q.dmg = dmg
		q.life = life
		q.mask = 1 | 4 | 16
		q.source = mech
		q.color = c
		q.spin_spd = spin_v
		q.tail.visible = false
		q.tail.scale = Vector3(1, 1, 0.01)
		q.tail.position = Vector3(0, 0, t_off)
		q.tail_offset = t_off
		q.tail_len = wake_len
		q.global_position = pos
		if vel.length_squared() > 0.01:
			q.look_at(pos + vel, up_ref)
		q.visible = true
		q.set_physics_process(true)
		return q
	var p = ProjScript.new()
	p.pool_key = key
	p.raid = self
	p.vel = vel
	p.dmg = dmg
	p.life = life
	p.mask = 1 | 4 | 16       ## 玩家子弹：地形 + 虫群 + 流浪者（打不到队友）
	p.source = mech
	p.color = c
	p.spin_spd = spin_v
	# 3D 写实重工业实体金属弹药 + 高对比暗钢弹体 + 炽热曳光药柱底火 + 锐利弹尖反光
	var body := Node3D.new()
	p.add_child(body)
	p.body_node = body
	var bkey := "tbody|%s|%.4f|%.4f|%s" % [caliber, br, bl, c.to_html()]
	_build_or_reuse_body(body, bkey, _populate_tracer_body.bind(caliber, br, bl, c))
	# 与子弹口径严密对齐的双交叉炽热针状曳光带
	var t := Node3D.new()
	t.visible = false
	t.scale = Vector3(1, 1, 0.01)
	t.position = Vector3(0, 0, t_off)
	p.add_child(t)
	var rib_mesh := _ribbon_cached(wake_w)
	var rib_mat := _tracer_mat(c)
	var t1 := MeshInstance3D.new()
	t1.mesh = rib_mesh
	t1.material_override = rib_mat
	t1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.add_child(t1)
	var t2 := MeshInstance3D.new()
	t2.mesh = rib_mesh
	t2.rotation_degrees = Vector3(0, 0, 90)
	t2.material_override = rib_mat
	t2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.add_child(t2)
	p.tail = t
	p.tail_offset = t_off
	p.tail_len = wake_len
	fx.add_child(p)
	p.global_position = pos
	if vel.length_squared() > 0.01:
		p.look_at(pos + vel, up_ref)
	return p


## 子弹网格按尺寸缓存：每发子弹都新建网格资源很贵（v0.6 机甲小队同时开火时尤其明显）
static var _bullet_meshes := {}
func _ribbon_cached(w: float) -> PlaneMesh:
	var k := "rib%.4f" % w
	if not _bullet_meshes.has(k):
		var pm := PlaneMesh.new()
		pm.size = Vector2(maxf(0.012, w), 1.0)
		_bullet_meshes[k] = pm
	return _bullet_meshes[k]


func _quad_cached(sz: float) -> QuadMesh:
	var k := "q%.3f" % sz
	if not _bullet_meshes.has(k):
		var qm := QuadMesh.new()
		qm.size = Vector2.ONE * sz
		_bullet_meshes[k] = qm
	return _bullet_meshes[k]


## 3D 实体黄铜/红壳弹壳粒子网格：瓶颈收口 + 抽壳槽 + 空心弹口（高精弹药库，16 段车削，轴沿 X 供粒子翻滚）
func _casing_mesh(heavy := false, red_shell := false) -> Mesh:
	return MM.casing_mesh(heavy, red_shell)


## 3D 实体碎屑网格（装甲碎片 / 混凝土碎块 / 虫族甲壳残片）：不规则切角多面体，每类 3 个变体随机取用
func _debris_mesh(kind := "metal") -> Mesh:
	return MM.debris_mesh(kind, randi() % 3)


## 3D 实体脱壳穿甲弹铝合金弹托瓣：120° 弧形卡瓦（带闭气槽与兜风扩口）
func _sabot_petal_mesh() -> Mesh:
	return MM.sabot_petal_mesh()


var _mach_cache := {}
func _mach_cone_mat(c: Color) -> StandardMaterial3D:
	var k := "mc_" + c.to_html()
	if not _mach_cache.has(k):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(0.68, 0.67, 0.64, 0.22)
		_mach_cache[k] = m
	return _mach_cache[k]


const TRACER_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color;
void fragment() {
	float tc = clamp(UV.y, 0.0, 1.0);
	float half_w = mix(1.0, 0.16, pow(clamp(tc, 1e-4, 1.0), 0.75));
	float rn = clamp(abs(UV.x - 0.5) * 2.0, 0.0, 2.0) / max(half_w, 0.01);
	if (rn > 1.0 || tc > 0.992) discard;
	float core_w = smoothstep(0.52, 0.08, rn);
	float body_w = smoothstep(0.88, 0.42, rn);
	float edge_mask = 1.0 - smoothstep(0.82, 1.0, rn);
	float len_fade = pow(clamp(1.0 - tc, 1e-4, 1.0), 1.08) * smoothstep(0.992, 0.90, tc);
	float tip_hot = smoothstep(0.48, 0.0, tc);
	vec3 sat_col = pow(clamp(col.rgb, vec3(0.02), vec3(1.0)), vec3(1.25));
	vec3 hot_core = sat_col * 2.6 + vec3(1.15) * mix(0.45, 0.95, tip_hot);
	vec3 mid_col = sat_col * mix(2.5, 1.35, tc);
	vec3 rim_dark = mix(vec3(0.06, 0.05, 0.05), sat_col * 0.25, 0.25);
	vec3 c_out = mix(rim_dark, mid_col, body_w);
	c_out = clamp(mix(c_out, hot_core, core_w), vec3(0.0), vec3(8.0));
	float alpha_out = clamp(edge_mask * len_fade * mix(0.42, 0.98, body_w), 0.0, 1.0);
	if (alpha_out < 0.005) discard;
	ALBEDO = c_out;
	ALPHA = alpha_out;
}
"""
static var _tracer_shader: Shader = null
static var _tracer_cache := {}
func _tracer_mat(c: Color) -> ShaderMaterial:
	var k := c.to_html()
	if not _tracer_cache.has(k):
		if _tracer_shader == null:
			_tracer_shader = Shader.new()
			_tracer_shader.code = TRACER_SHADER
		var mm := ShaderMaterial.new()
		mm.shader = _tracer_shader
		mm.set_shader_parameter("col", c)
		_tracer_cache[k] = mm
	return _tracer_cache[k]


const MUZZLE_JET_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color;
void fragment() {
	float tc = clamp(1.0 - UV.y, 0.0, 1.0);
	float tip_t = clamp((tc - 0.20) / 0.80, 0.0, 1.0);
	float half_w = mix(0.32, 1.0, smoothstep(0.0, 0.22, tc)) * pow(clamp(1.0 - tip_t, 1e-4, 1.0), 1.25);
	float rn = clamp(abs(UV.x - 0.5) * 2.0, 0.0, 2.0) / max(half_w, 0.01);
	if (rn > 1.0 || tc > 0.992) discard;
	float core_w = smoothstep(0.52, 0.08, rn);
	float body_w = smoothstep(0.88, 0.36, rn);
	float edge_mask = 1.0 - smoothstep(0.80, 1.0, rn);
	float len_fade = pow(clamp(1.0 - tc * 0.88, 1e-4, 1.0), 0.85) * smoothstep(0.992, 0.90, tc);
	vec3 sat_col = pow(clamp(col.rgb, vec3(0.02), vec3(1.0)), vec3(1.25));
	vec3 hot_core = sat_col * 2.5 + vec3(1.10) * smoothstep(0.75, 0.0, tc);
	vec3 flame_col = sat_col * mix(2.4, 1.25, tc);
	vec3 c_out = mix(sat_col * 0.40, flame_col, body_w);
	c_out = clamp(mix(c_out, hot_core, core_w), vec3(0.0), vec3(8.0));
	float alpha_out = clamp(edge_mask * len_fade * mix(0.35, 0.96, body_w), 0.0, 1.0);
	if (alpha_out < 0.005) discard;
	ALBEDO = c_out;
	ALPHA = alpha_out;
}
"""
static var _muzzle_shader: Shader = null
static var _muzzle_mat_cache := {}
var _warming_fx := false
func _muzzle_mat(c: Color) -> ShaderMaterial:
	var k := c.to_html()
	if not _muzzle_mat_cache.has(k):
		if _muzzle_shader == null:
			_muzzle_shader = Shader.new()
			_muzzle_shader.code = MUZZLE_JET_SHADER
		var mm := ShaderMaterial.new()
		mm.shader = _muzzle_shader
		mm.set_shader_parameter("col", c)
		_muzzle_mat_cache[k] = mm
	return _muzzle_mat_cache[k]


func _warm_combat_fx() -> void:
	_tracer_mat(Color(1.0, 0.68, 0.20))
	_muzzle_mat(Color(1.0, 0.62, 0.16))
	_debris_mesh("metal")
	_debris_mesh("rock")
	A.particle_mat(A.soft_dot(), true, -1.0)
	A.particle_mat(A.dust_tex(), false, 0.20)
	A.particle_mat(A.smoke_tex(), false, 0.22)
	# 预建所有碎片变体、首次爆炸/击杀贴图，避免第一发命中时生成贴图或网格。
	for kind: String in ["metal", "rock", "chitin"]:
		for variant in 3: MM.debris_mesh(kind, variant)
	A.shockwave_tex()
	A.scorch_tex()
	A.grime_stain_tex()
	for level in range(1, 6): A.hit_flash_overlay(float(level) / 5.0)
	BugScript._get_dead_eye_mat()
	preload("res://scripts/enemies/hazards.gd").warm_visuals()
	PrefabLib.get_prefab("veh_transport_vtol")
	# 支援脉冲一次覆盖多种体型，护盾曲面不能在首次施放时逐个冷生成。
	for enemy_data: Dictionary in GameData.ENEMIES.values():
		A.aegis_shield_mesh(maxf(0.55, float(enemy_data.get("radius", 0.6)) * 1.25), maxf(0.85, float(enemy_data.get("scale", 1.0)) * 1.15), 5, 28)
	for heavy in [false, true]:
		for red in [false, true]: _casing_mesh(heavy, red)
	_sabot_petal_mesh()
	# 复用真实发射分支准备弹体。此处尚未开始行动，不推进物理、不发网络效果，
	# 也不消耗全局随机数；曳光弹回池，其他临时弹体立即释放。
	_warming_fx = true
	var npc := FactionsScript.Npc.new()
	npc.raid = self
	for id: String in GameData.MODULES:
		var m: Dictionary = GameData.MODULES[id]
		if str(m.get("slot", "")) != "arm" or str(m.get("weapon", "")) == "melee": continue
		var first := fx.get_child_count()
		spawn_projectile(Vector3.ZERO, Vector3.FORWARD, m, true)
		for fac: String in ["rover", "ally"]:
			npc.faction = fac
			npc._shot(m, Vector3.ZERO, Vector3.FORWARD)
		for i in range(first, fx.get_child_count()):
			var p = fx.get_child(i)
			if p is ProjScript:
				if p.pool_key != "":
					recycle_projectile(p)
				else:
					p.set_physics_process(false)
					p.visible = false
					p.queue_free()
	# 回池复用的子弹不增加 child_count，也要恢复为休眠状态。
	for p in fx.get_children():
		if p is ProjScript and not p.is_queued_for_deletion() and p.is_physics_processing(): recycle_projectile(p)
	npc.free()
	for kind: String in ["missile", "rocket", "vls"]:
		var p = _proj(Vector3.ZERO, Vector3.FORWARD, 0, 1, 0, Color(0.82, 0.52, 0.28), 0.28, false, kind)
		p.free()
	var spit = _proj(Vector3.ZERO, Vector3.FORWARD, 0, 1, 0, Color(0.46, 0.58, 0.24), 0.40, false, "spit")
	spit.free()
	_warming_fx = false


func fx_random_range(from: float, to: float) -> float:
	return (from + to) * 0.5 if _warming_fx else randf_range(from, to)


var _glow_cache := {}
func _glow_mat(c: Color) -> StandardMaterial3D:
	var k := c.to_html()
	if not _glow_cache.has(k):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_texture = A.soft_dot()
		m.albedo_color = Color(c.r, c.g, c.b, 0.7)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.no_depth_test = false
		_glow_cache[k] = m
	return _glow_cache[k]


func spawn_projectile(origin: Vector3, dir: Vector3, m: Dictionary, _friendly: bool) -> void:
	var dmg: float = float(m.get("dmg", 10.0))
	var ap := clampf((float(m.get("pen", 25.0)) - 15.0) / 62.0, 0.0, 0.85)
	var proj = null
	match str(m.get("weapon", "mg")):
		"laser":
			var is_rail := dmg >= 75.0
			var spd_l: float = float(m.get("speed", 135.0 if is_rail else 96.0))
			var life_l: float = clampf(GameData.weapon_range_m(m) / maxf(spd_l, 20.0) * 6.0, 2.5, 6.0)
			var col_l := Color(0.30, 0.86, 1.0) if is_rail else Color(0.18, 0.74, 1.0)
			proj = _tracer(origin, dir * spd_l, dmg, life_l, col_l, 0.14 if is_rail else 0.10, 0.095 if is_rail else 0.072, "apfsds" if is_rail else "coil")
		"sniper":
			var spd_s: float = float(m.get("speed", 145.0))
			var life_s: float = clampf(GameData.weapon_range_m(m) / maxf(spd_s, 30.0) * 6.0, 2.5, 6.0)
			var is_amr := dmg >= 100.0
			var cal_s := "sniper_ap" if is_amr else "sniper"
			var col_s := Color(1.0, 0.28, 0.14) if is_amr else Color(1.0, 0.76, 0.24)
			proj = _tracer(origin, dir * spd_s, dmg, life_s, col_s, 0.12, 0.065, cal_s)
		"flamer":
			var spd_f: float = float(m.get("speed", 16.0))
			var life_f: float = clampf(GameData.weapon_range_m(m) / maxf(spd_f, 8.0) * 6.0, 2.5, 6.0)
			var p = _proj(origin, dir * spd_f * fx_random_range(0.86, 1.12), dmg, life_f, 1 | 4 | 16, Color(1.0, 0.44, 0.12), 0.34, false, "flamer")
			p.source = mech
			p.pierce = true
			p.grow = 0.0
			p.hit_sfx = "-"
			A.emitter(p, Vector3(0, 0, 0.16), {"amount": 7, "life": 0.20, "size": 0.26, "tex": A.smoke_tex(), "additive": false, "spread": 32.0, "vmin": 0.2, "vmax": 0.6,
				"gravity": Vector3(0, 1.2, 0), "c0": Color(1.0, 0.52, 0.12, 0.82), "c1": Color(0.22, 0.16, 0.14, 0.0), "grow0": 0.65, "grow1": 1.35})
			proj = p
		"melee":
			melee_strike(origin, dir, m)
			return
		"shotgun", "cannon", "launcher":
			var speed: float = float(m.get("speed", 40.0))
			var life: float = clampf(GameData.weapon_range_m(m) / maxf(speed, 20.0) * 6.0, 2.5, 6.0)
			var pellets: int = int(m.get("pellets", 7))
			if dmg >= 55.0:
				proj = _tracer(origin, dir * speed, dmg, life, Color(1.0, 0.34, 0.10), 0.19, 0.11, "cannon")
			elif pellets == 1:
				proj = _tracer(origin, dir * speed * fx_random_range(0.96, 1.04), dmg, life, Color(1.0, 0.56, 0.16), 0.15, 0.085, "slug")
			else:
				proj = _tracer(origin, dir * speed * fx_random_range(0.9, 1.1), dmg, life, Color(1.0, 0.62, 0.20), 0.095, 0.052, "pellet")
		_:
			var speed: float = float(m.get("speed", 40.0))
			var life: float = clampf(GameData.weapon_range_m(m) / maxf(speed, 20.0) * 6.0, 2.5, 6.0)
			if dmg >= 20.0:
				proj = _tracer(origin, dir * speed, dmg, life, Color(1.0, 0.40, 0.12), 0.16, 0.09, "ac30")
			elif dmg >= 12.0:
				proj = _tracer(origin, dir * speed, dmg, life, Color(1.0, 0.54, 0.15), 0.13, 0.072, "hmg")
			else:
				proj = _tracer(origin, dir * speed, dmg, life, Color(1.0, 0.68, 0.20), 0.12, 0.065, "mg")
	if proj != null:
		proj.ap = ap
		proj.apply_falloff(GameData.weapon_falloff(m))


func melee_strike(origin: Vector3, dir: Vector3, m: Dictionary) -> void:
	var reach: float = maxf(float(m.get("reach_m", 3.0)), 1.0)
	var dmg: float = float(m.get("dmg", 20.0))
	var ap: float = clampf((float(m.get("pen", 20.0)) - 15.0) / 62.0, 0.0, 0.85)
	var flat := Vector3(dir.x, 0.0, dir.z)
	var c := origin
	if mech != null and is_instance_valid(mech):
		c = Vector3(mech.global_position.x, origin.y, mech.global_position.z)
		var aimv: Vector3 = mech.aim_point
		var a := Vector3(aimv.x - c.x, 0.0, aimv.z - c.z)
		if a.length_squared() > 0.01:
			flat = a.normalized()
	if flat.length_squared() < 0.0001:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	var hit_any := false
	for grp in ["bugs", "nests", "rovers"]:
		for b in get_tree().get_nodes_in_group(grp):
			if not is_instance_valid(b) or not (b is Node3D):
				continue
			var bp: Vector3 = (b as Node3D).global_position
			var to: Vector3 = bp - c
			to.y = 0.0
			var d := to.length()
			if d > reach + 1.0:
				continue
			if d > 0.05 and flat.dot(to / d) < 0.45:
				continue
			if not b.has_method("take_damage"):
				continue
			if grp == "bugs":
				b.take_damage(dmg, origin, ap)
			else:
				b.take_damage(dmg)
			hit_any = true
			spark(bp + Vector3(0.0, 1.0, 0.0), Color(1.0, 0.72, 0.3), 8)
	if hit_any:
		shake = maxf(shake, clampf(dmg / 220.0, 0.04, 0.22))
	A.burst(fx, origin + flat * minf(reach, 3.0) * 0.55 + Vector3(0.0, 1.2, 0.0), {
		"amount": 10, "life": 0.22, "size": 0.17, "dir": flat, "spread": 52.0,
		"vmin": 4.0, "vmax": 9.0, "gravity": Vector3(0, -12, 0), "damp": 2.0,
		"c0": Color(1.0, 0.86, 0.55), "c1": Color(1.0, 0.3, 0.1, 0.0), "grow0": 1.0, "grow1": 0.2})


func spawn_spit(origin: Vector3, dir: Vector3, dmg: float) -> void:
	var p = _proj(origin, dir * 18.0, dmg, 1.4, 1 | 2 | 16 | 32, Color(0.46, 0.58, 0.24), 0.40, false, "spit")
	p.hit_sfx = "hit_spit"
	A.emitter(p, Vector3(0, 0, 0.25), {"amount": 10, "life": 0.42, "size": 0.36, "tex": A.smoke_tex(), "additive": false, "spread": 75.0, "vmin": 0.2, "vmax": 0.7, "gravity": Vector3(0, -1.2, 0),
		"c0": Color(0.44, 0.48, 0.34, 0.52), "c1": Color(0.28, 0.30, 0.24, 0.0), "grow0": 0.7, "grow1": 1.6})


func launch_missiles(origin: Vector3, m: Dictionary) -> void:
	var cnt := int(m.get("count", 6))
	var m_kind := "vls" if cnt >= 10 else ("rocket" if cnt == 8 else "missile")
	for i in cnt:
		var a := TAU * i / float(cnt)
		var v := Vector3(cos(a) * 6.0, 9.0, sin(a) * 6.0)
		var p = _proj(origin, v, m.dmg, 6.0, 1 | 4 | 16, Color(0.82, 0.52, 0.28), 0.28, false, m_kind)
		p.homing = true
		p.aoe = 3.2
		p.apply_falloff(GameData.weapon_falloff({"weapon": "launcher", "reach_m": 60.0}))
		# 固体燃料推进剂灰白浓烟柱（非发光实体烟雾）
		A.emitter(p, Vector3(0, 0, 0.62), {"amount": 38, "life": 1.05, "size": 0.68, "tex": A.smoke_tex(), "additive": false, "spread": 140.0, "vmin": 0.15, "vmax": 0.48,
			"gravity": Vector3(0, 0.7, 0), "c0": Color(0.76, 0.74, 0.70, 0.58), "c1": Color(0.45, 0.43, 0.40, 0.0), "grow0": 0.45, "grow1": 2.15})
	# 发射井激波冷气浪与固体燃气烟团
	A.burst(fx, origin, {"amount": 18, "life": 0.48, "size": 1.15, "tex": A.smoke_tex(), "additive": false, "spread": 180.0, "vmin": 2.5, "vmax": 6.0,
		"gravity": Vector3(0, 1.5, 0), "damp": 4.0, "c0": Color(0.78, 0.75, 0.70, 0.62), "c1": Color(0.48, 0.46, 0.44, 0.0), "grow0": 0.6, "grow1": 2.1})
	alert_noise(origin, 30.0)


func fire_laser(origin: Vector3, dir: Vector3, m: Dictionary) -> void:
	spawn_projectile(origin, dir, m, true)


func laser_visual(origin: Vector3, end: Vector3, _color: Color, is_rail: bool) -> void:
	var span := origin.distance_to(end)
	if span < 0.2:
		return
	var dir := (end - origin) / span
	var spd := 135.0 if is_rail else 96.0
	var col_l := Color(0.30, 0.86, 1.0) if is_rail else Color(0.18, 0.74, 1.0)
	var p = _tracer(origin, dir * spd, 0.0, clampf(span / spd, 0.04, 0.6), col_l, 0.14 if is_rail else 0.10, 0.095 if is_rail else 0.072, "apfsds" if is_rail else "coil")
	p.set_meta("net_visual", true)
	p.pool_key = ""


var _beam_cache := {}
func _beam_mat(c: Color) -> StandardMaterial3D:
	var k := c.to_html()
	if not _beam_cache.has(k):
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mm.albedo_color = Color(c.r, c.g, c.b, 0.6)
		mm.emission_enabled = true
		mm.emission = c
		mm.emission_energy_multiplier = 3.0
		_beam_cache[k] = mm
	return _beam_cache[k]


## 点光/聚光不照亮体积雾。体积雾是 64×64 的 froxel 网格，在 ~48m 的镜头距离上每格约 20 像素，
## 灯光（尤其是战斗中频繁闪烁的炮口火光、爆炸、闪烁的火桶）把一格格照亮后就成了大片半透明方格。
## 阳光仍然进雾，大气感保留。
func _no_fog_light(n: Node) -> void:
	if n is OmniLight3D or n is SpotLight3D:
		var lt := n as Light3D
		lt.light_volumetric_fog_energy = 0.0
		if n.get_parent() != fx and not lt.distance_fade_enabled:
			if A.is_mobile_perf():
				lt.distance_fade_enabled = true
				lt.distance_fade_begin = 34.0
				lt.distance_fade_length = 8.0
			elif not (n is OmniLight3D and (n as OmniLight3D).omni_range > 22.0):
				lt.distance_fade_enabled = true
				lt.distance_fade_begin = 58.0
				lt.distance_fade_length = 18.0


## 短暂的点光源闪烁（炮口火光、爆炸、道具闪光）——全部走这个池，不再每发子弹 new 一盏灯
const LIGHT_POOL_MAX := 10
var _light_pool: Array = []
func _flash_light(p: Vector3, c: Color, energy: float, rng_m: float, dur := 0.08) -> void:
	if A.is_mobile_perf() and GameData.quality == 0:
		return
	var pool_cap := 3 if A.is_mobile_perf() else LIGHT_POOL_MAX
	var l: OmniLight3D = null
	for x in _light_pool:
		if not x.visible:
			l = x
			break
	if l == null:
		if _light_pool.size() >= pool_cap:
			return
		l = OmniLight3D.new()
		l.shadow_enabled = false
		# 不参与体积雾：体积雾的 froxel 网格在镜头距离上每格约 20 像素，
		# 炮口火光/爆炸照亮它会在战斗中出现一片片半透明方格
		l.light_volumetric_fog_energy = 0.0
		fx.add_child(l)
		_light_pool.append(l)
	l.visible = true
	l.global_position = p
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng_m
	var old: Tween = l.get_meta("tw") if l.has_meta("tw") else null
	if old != null and old.is_valid():
		old.kill()
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur)
	tw.tween_callback(func(): l.visible = false)
	l.set_meta("tw", tw)


func explode(p: Vector3, radius: float, dmg: float, sfx := "explosion", notify_hit := false) -> void:
	var hit_any := false
	var r2 := (radius + 0.8) * (radius + 0.8)
	for grp in ["bugs", "nests", "rovers"]:
		for b in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(b) and b.global_position.distance_squared_to(p) < r2:
				b.take_damage(dmg)
				hit_any = true
	if notify_hit and hit_any and hud != null and hud.has_method("notify_hit"):
		hud.notify_hit()
	explode_fx(p, radius, Color(1.0, 0.55, 0.2))
	Audio.play_sfx(sfx, p + Vector3(0, 1.0, 0))
	shake = max(shake, 0.25)


func explode_fx(p: Vector3, radius: float, c: Color) -> void:
	if coop != null: coop.emit_effect("explosion", [p, radius, c])
	# 3D 膨胀爆轰球壳 + 快速闪光（不遮挡体积火球与黑烟）
	# 瞬时冲击波贴花 + 热核闪焰（取代光滑半透明几何球壳）
	var sw_c := Color(c.r * 0.7 + 0.3, c.g * 0.7 + 0.25, c.b * 0.7 + 0.2, 0.65)
	var sw := A.ground_vfx(fx, A.shockwave_tex(), sw_c, radius * 1.1, Vector3(p.x, 0.11, p.z), false, 0.44, true, 4)
	var dtw := sw.create_tween()
	dtw.tween_property(sw, "scale", Vector3.ONE * 2.5, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	dtw.parallel().tween_property(sw.material_override, "shader_parameter/col", Color(sw_c.r, sw_c.g, sw_c.b, 0.0), 0.24)
	dtw.tween_callback(sw.queue_free)
	A.burst(fx, p + Vector3(0, 0.35, 0), {"amount": 5, "life": 0.16, "size": radius * 0.82, "tex": A.smoke_tex(), "additive": true,
		"vmin": 0.4, "vmax": radius * 0.8, "gravity": Vector3.ZERO, "c0": Color(1.0, 0.88, 0.62, 0.85),
		"c1": Color(c.r, c.g * 0.6, 0.1, 0.0), "grow0": 0.45, "grow1": 1.35, "soft_depth": 0.30})
	# 火球
	A.burst(fx, p + Vector3(0, 0.55, 0), {"amount": 18, "life": 0.56, "size": radius * 0.86, "tex": A.smoke_tex(), "vmin": radius * 1.1, "vmax": radius * 2.5,
		"gravity": Vector3(0, 3.0, 0), "damp": 5.2, "radius": 0.30, "c0": Color(1.0, 0.90, 0.56, 0.95), "cmid": Color(c.r, c.g * 0.52, 0.12, 0.88), "cmid_pos": 0.32,
		"c1": Color(0.28, 0.05, 0.02, 0.0), "grow0": 0.45, "grow_mid": 1.28, "grow_mid_pos": 0.28, "grow1": 0.85, "soft_depth": 0.32})
	# 黑烟
	A.burst(fx, p + Vector3(0, 0.78, 0), {"amount": 18, "life": 1.85, "size": radius * 0.98, "tex": A.smoke_tex(), "additive": false, "vmin": radius * 0.45, "vmax": radius * 1.25,
		"gravity": Vector3(0, 2.1, 0), "damp": 2.4, "radius": radius * 0.32, "explosive": 0.85, "c0": Color(0.22, 0.16, 0.12, 0.0),
		"cmid": Color(0.14, 0.12, 0.11, 0.78), "cmid_pos": 0.16, "c1": Color(0.24, 0.22, 0.20, 0.0), "grow0": 0.48, "grow1": 1.85, "soft_depth": 0.45})
	# 贴地扬尘冲击环
	var dt := ground_dust_tint()
	A.burst(fx, p + Vector3(0, 0.28, 0), {"amount": 16, "life": 0.95, "size": radius * 0.72, "tex": A.dust_tex(), "additive": false, "flat": 0.92,
		"dir": Vector3(1, 0, 0), "spread": 180.0, "vmin": radius * 1.6, "vmax": radius * 3.0, "gravity": Vector3(0, 0.3, 0), "damp": 6.5, "radius": 0.35,
		"c0": Color(dt.r, dt.g, dt.b, 0.0), "cmid": Color(dt.r, dt.g, dt.b, 0.46), "cmid_pos": 0.18, "c1": Color(dt.r * 0.9, dt.g * 0.9, dt.b * 0.9, 0.0),
		"grow0": 0.45, "grow1": 1.80, "soft_depth": 0.28})
	# 火星 + 3D 实体金属破片/碎石飞溅
	A.burst(fx, p + Vector3(0, 0.5, 0), {"amount": 26, "life": 0.72, "size": 0.16, "vmin": 6.5, "vmax": 15.0, "gravity": Vector3(0, -15, 0), "damp": 1.0,
		"c0": Color(1.0, 0.88, 0.55), "c1": Color(1.0, 0.3, 0.0, 0.0), "grow0": 1.0, "grow1": 0.25})
	A.burst(fx, p + Vector3(0, 0.45, 0), {"amount": 14, "life": 0.85, "mesh": _debris_mesh("metal"), "additive": false, "vmin": 5.5, "vmax": 13.5,
		"gravity": Vector3(0, -22, 0), "damp": 0.6, "smin": 0.8, "smax": 1.6, "c0": Color(1.0, 0.72, 0.35), "c1": Color(0.25, 0.24, 0.22, 0.0), "grow0": 1.0, "grow1": 0.7})
	_flash_light(p + Vector3(0, 1.5, 0), Color(1.0, 0.6, 0.25), 8.5, radius * 4.2, 0.35)
	var scorch := A.ground_vfx(fx, A.scorch_tex(), Color(1, 1, 1, 0.88), radius * 2.25, Vector3(p.x, 0.093, p.z), false, 0.44, true, 2)
	scorch.rotation.y = randf() * TAU
	var tw := create_tween()
	tw.tween_interval(9.0)
	tw.tween_property(scorch.material_override, "shader_parameter/col", Color(1.0, 1.0, 1.0, 0.0), 3.0)
	tw.tween_callback(scorch.queue_free)


func _fx_in_range(p: Vector3, r: float) -> bool:
	if mech == null or not is_instance_valid(mech):
		return true
	var d2 := p.distance_squared_to(mech.global_position)
	if cam_focus != Vector3.ZERO:
		d2 = minf(d2, p.distance_squared_to(cam_focus))
	return d2 <= r * r


func spark(p: Vector3, c: Color, n := 8) -> void:
	if not _fx_in_range(p, 55.0):
		return
	if n >= 8:
		_flash_light(p + Vector3(0, 0.25, 0), c.lightened(0.28), 1.35, 3.2, 0.045)
	A.burst(fx, p, {"amount": n, "life": 0.3, "size": 0.13, "vmin": 3.5, "vmax": 9.5, "gravity": Vector3(0, -12, 0), "damp": 2.0,
		"c0": c.lightened(0.55), "c1": Color(c.r, c.g * 0.5, 0.0, 0.0), "grow0": 1.0, "grow1": 0.2})
	A.burst(fx, p, {"amount": maxi(3, n / 3), "life": 0.42, "mesh": _debris_mesh("metal"), "additive": false, "vmin": 2.5, "vmax": 6.8,
		"gravity": Vector3(0, -19, 0), "damp": 0.8, "smin": 0.45, "smax": 0.9, "c0": c.lightened(0.35), "c1": Color(0.2, 0.2, 0.22, 0.0), "grow0": 1.0, "grow1": 0.5})


const MUZZLE_POOL_MAX := 18
var _muzzle_pool := {}

func _spawn_muzzle_jet(p: Vector3, dir: Vector3, c: Color, weapon: String, dmg: float) -> void:
	var is_heavy := weapon in ["shotgun", "cannon", "railgun", "sniper", "mortar", "grenade", "flak"] or dmg >= 50.0
	var is_med := (not is_heavy) and (weapon in ["laser", "slug"] or dmg >= 12.0)
	var jet_len := 1.85 if is_heavy else (1.32 if is_med else 0.92)
	var jet_w := 0.56 if is_heavy else (0.42 if is_med else 0.30)
	var k := "%s|%.2f|%.2f" % [c.to_html(), jet_w, jet_len]
	var arr: Array = _muzzle_pool.get(k, [])
	var root: Node3D = null
	for i in range(arr.size() - 1, -1, -1):
		var n = arr[i]
		if not is_instance_valid(n):
			arr.remove_at(i)
		elif not n.visible:
			root = n
			break
	if root == null:
		if arr.size() >= MUZZLE_POOL_MAX:
			return
		root = Node3D.new()
		var mat := _muzzle_mat(c)
		var rib := _ribbon_cached(1.0)
		for ang in [0.0, 90.0]:
			var piv := Node3D.new()
			piv.rotation_degrees = Vector3(0, 0, ang)
			var mi := MeshInstance3D.new()
			mi.mesh = rib
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3(0, 0, -jet_len * 0.5)
			mi.scale = Vector3(jet_w, 1.0, jet_len)
			piv.add_child(mi)
			root.add_child(piv)
		var v_scale_z := jet_len * (0.58 if (is_heavy or is_med) else 0.42)
		var v_scale_x := jet_w * (0.76 if (is_heavy or is_med) else 0.62)
		for sx in [-54.0, 54.0]:
			var vpiv := Node3D.new()
			vpiv.rotation_degrees = Vector3(0, sx, 0)
			var vmi := MeshInstance3D.new()
			vmi.mesh = rib
			vmi.material_override = mat
			vmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			vmi.position = Vector3(0, 0, -v_scale_z * 0.5)
			vmi.scale = Vector3(v_scale_x, 1.0, v_scale_z)
			vpiv.add_child(vmi)
			root.add_child(vpiv)
		fx.add_child(root)
		arr.append(root)
		_muzzle_pool[k] = arr
	root.visible = true
	root.global_position = p
	root.scale = Vector3.ONE
	var d := dir.normalized()
	var up_ref := Vector3.UP if absf(d.y) < 0.95 else Vector3.FORWARD
	root.look_at(p + d, up_ref)
	root.rotate_object_local(Vector3.FORWARD, deg_to_rad(randf_range(-6.0, 6.0)))
	var old: Tween = root.get_meta("tw") if root.has_meta("tw") else null
	if old != null and old.is_valid():
		old.kill()
	var dur := 0.080 if is_heavy else (0.066 if is_med else 0.056)
	var tw := create_tween()
	tw.tween_property(root, "scale", Vector3(0.30, 0.30, 0.18), dur).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(root):
			root.visible = false)
	root.set_meta("tw", tw)


func muzzle_flash(p: Vector3, c: Color, dir := Vector3.ZERO, weapon := "", dmg := 10.0) -> void:
	if coop != null: coop.emit_effect("muzzle", [p, c, dir, weapon, dmg])
	if not _fx_in_range(p, 95.0):
		return
	var is_sabot := weapon in ["laser", "railgun", "arc"]
	var heavy := weapon in ["shotgun", "cannon", "railgun", "sniper", "mortar", "grenade", "flak"] or dmg >= 50.0
	var is_rover_red := (not is_sabot) and c.r > 0.85 and c.g < 0.32
	var jet_col := Color(0.26, 0.82, 1.0) if is_sabot else (Color(1.0, 0.26, 0.14) if is_rover_red else (Color(1.0, 0.42, 0.12) if heavy else Color(1.0, 0.62, 0.16)))
	_flash_light(p + Vector3(0, 0.55, 0), jet_col, 2.35 if heavy else 1.60, 5.2 if heavy else 4.2, 0.048)
	if dir == Vector3.ZERO:
		return
	# 锐利立体膛口矛状喷焰 + 制退器侧向 V 型射流（取代圆形叠加雾团）
	if weapon not in ["cryo", "flamer"]:
		_spawn_muzzle_jet(p + dir * 0.12, dir, jet_col, weapon, dmg)
		var m_tag := "mz_%d_%s" % [1 if heavy else 0, jet_col.to_html(false)]
		A.burst(fx, p + dir * 0.18, {"pool": m_tag, "amount": 5 if heavy else 3, "life": 0.055, "size": 0.048, "dir": dir, "spread": 16.0, "vmin": 9.0, "vmax": 18.0,
			"gravity": Vector3.ZERO, "damp": 18.0, "c0": jet_col.lightened(0.22), "c1": Color(jet_col.r, jet_col.g * 0.45, jet_col.b * 0.2, 0.0), "grow0": 1.0, "grow1": 0.2})
	# 克制发射药黑灰硝烟（重武器每发少量，连射轻武器抽样排放，防止连射堆出白灰雾团）
	if weapon == "cryo" or heavy:
		A.burst(fx, p + dir * 0.34, {"pool": "mz_smk_h", "amount": 2, "life": 0.36, "size": 0.34, "tex": A.dust_tex(), "additive": false, "dir": dir, "spread": 18.0,
			"vmin": 1.5, "vmax": 3.4, "gravity": Vector3(0, 0.60, 0), "damp": 4.2,
			"c0": Color(0.30, 0.29, 0.27, 0.0), "cmid": Color(0.26, 0.25, 0.23, 0.18), "cmid_pos": 0.18, "c1": Color(0.22, 0.21, 0.20, 0.0), "grow0": 0.45, "grow1": 1.30, "soft_depth": 0.20})
	elif randf() < 0.28:
		A.burst(fx, p + dir * 0.28, {"pool": "mz_smk_l", "amount": 1, "life": 0.22, "size": 0.20, "tex": A.dust_tex(), "additive": false, "dir": dir, "spread": 16.0,
			"vmin": 1.2, "vmax": 2.4, "gravity": Vector3(0, 0.50, 0), "damp": 4.8,
			"c0": Color(0.32, 0.30, 0.28, 0.0), "cmid": Color(0.28, 0.27, 0.25, 0.10), "cmid_pos": 0.20, "c1": Color(0.24, 0.23, 0.21, 0.0), "grow0": 0.45, "grow1": 1.15, "soft_depth": 0.18})
	if weapon in ["flamer", "cryo"]:
		return
	var side := dir.cross(Vector3.UP).normalized()
	var mob_perf := A.is_mobile_perf()
	if mob_perf and GameData.quality == 0 and not heavy and not is_sabot:
		return
	if mob_perf and not heavy and not is_sabot and randf() < 0.55:
		return
		if is_sabot:
			# 电磁轨道炮 / 线圈步枪：膛口抛离三瓣铝合金脱壳弹托瓣（APFSDS Sabot Petals）向两侧前方翻滚散落
			A.burst(fx, p + dir * 0.55, {"amount": 3, "life": 0.52, "mesh": _sabot_petal_mesh(), "additive": false,
				"dir": (dir * 0.65 + Vector3(0, 0.25, 0)).normalized(), "spread": 42.0, "vmin": 6.5, "vmax": 11.5, "gravity": Vector3(0, -22, 0), "damp": 0.8,
				"smin": 0.65, "smax": 0.95, "c0": Color(1, 1, 1, 1), "c1": Color(0.85, 0.85, 0.85, 0.95), "grow0": 1.0, "grow1": 0.85})
		else:
			# 3D 实体黄铜/红塑霰弹弹壳从外侧抛壳窗翻滚弹出（向外侧偏移避免遮挡第一人称镜头）
			var is_fp := view_mode == 1
			var eject_pos := p - dir * 0.22 + side * (0.26 if is_fp else 0.16) - Vector3(0, 0.08 if is_fp else 0.02, 0)
			A.burst(fx, eject_pos, {"amount": 2 if heavy else 1, "life": 0.65, "mesh": _casing_mesh(heavy, weapon == "shotgun" and dmg < 50.0), "additive": false,
				"dir": (side * 1.15 + Vector3(0, 0.72, 0)).normalized(), "spread": 16.0, "vmin": 3.6, "vmax": 5.8, "gravity": Vector3(0, -22, 0), "damp": 0.4,
				"smin": 0.65, "smax": 0.90, "c0": Color(1, 1, 1, 1), "c1": Color(0.85, 0.85, 0.85, 0.95), "grow0": 1.0, "grow1": 0.85})


## 命中：打在单位上 → 金属火星 + 3D 实体甲壳/装甲碎块；打在墙/地上 → 火花 + 尘烟 + 3D 混凝土碎石块 + 实体跳弹钢芯
var _last_heavy_impact_usec := 0
func impact(p: Vector3, n: Vector3, c: Color, unit: bool, vel: Vector3, organic := false) -> void:
	if coop != null: coop.emit_effect("impact", [p, n, c, unit, vel, organic])
	if not _fx_in_range(p, 95.0):
		return
	var nrm := n if n != Vector3.ZERO else Vector3.UP
	var refl := vel.normalized().bounce(nrm) if vel.length_squared() > 0.01 else Vector3.UP
	var spk_c := c if (c.b > c.r or c.r > 0.85) else Color(1.0, 0.68, 0.22)
	var now_u := Time.get_ticks_usec()
	var mob_perf := A.is_mobile_perf()
	var allow_heavy := now_u - _last_heavy_impact_usec >= (42000 if mob_perf else 18000)
	if allow_heavy:
		_last_heavy_impact_usec = now_u
	var spk_hex := spk_c.to_html(false)
	if allow_heavy and not organic and randf() < 0.45:
		# 实体变形弹芯跳弹飞散（取代纯发光环）
		A.burst(fx, p, {"pool": "imp_ric_" + spk_hex, "amount": 2, "life": 0.36, "mesh": _debris_mesh("metal"), "additive": false, "dir": refl, "spread": 18.0, "vmin": 11.0, "vmax": 18.0,
			"gravity": Vector3(0, -18, 0), "smin": 0.45, "smax": 0.75, "c0": spk_c.lightened(0.25), "c1": Color(0.45, 0.44, 0.42, 0.9), "grow0": 1.0, "grow1": 0.8})
	# 锐利金属撞击火星（按弹药色系着色）
	A.burst(fx, p, {"pool": "imp_spk_" + spk_hex, "amount": 9, "life": 0.22, "size": 0.075, "dir": (refl + nrm).normalized(), "spread": 38.0, "vmin": 6.0, "vmax": 13.0, "gravity": Vector3(0, -15, 0), "damp": 2.4,
		"c0": spk_c.lightened(0.20), "c1": Color(spk_c.r * 0.8, spk_c.g * 0.45, spk_c.b * 0.2, 0.0), "grow0": 1.0, "grow1": 0.18})
	if not allow_heavy:
		return
	if unit:
		# 3D 实体机械装甲 / 焦黑机械残片与机油雾（全部敌机与机械虫均走硬工业受击反馈）
		var d_kind := "metal"
		var c_start := Color(0.34, 0.31, 0.27) if organic else Color(0.68, 0.72, 0.78)
		A.burst(fx, p, {"pool": "imp_deb_o" if organic else "imp_deb_m", "amount": 8, "life": 0.52, "mesh": _debris_mesh(d_kind), "additive": false, "dir": nrm, "spread": 65.0, "vmin": 3.2, "vmax": 7.6, "gravity": Vector3(0, -19, 0),
			"smin": 0.65, "smax": 1.25, "c0": c_start, "c1": Color(0.14, 0.13, 0.12, 0.0), "grow0": 1.0, "grow1": 0.55})
		if organic:
			if randf() < 0.4:
				A.burst(fx, p, {"pool": "imp_org_ric", "amount": 2, "life": 0.34, "mesh": _debris_mesh("metal"), "additive": false, "dir": refl, "spread": 22.0, "vmin": 9.0, "vmax": 15.0,
					"gravity": Vector3(0, -18, 0), "smin": 0.45, "smax": 0.75, "c0": Color(0.95, 0.78, 0.48), "c1": Color(0.35, 0.34, 0.32, 0.9), "grow0": 1.0, "grow1": 0.8})
			A.burst(fx, p, {"pool": "imp_org_smk", "amount": 3, "life": 0.42, "size": 0.42, "tex": A.smoke_tex(), "additive": false, "dir": nrm, "spread": 50.0, "vmin": 1.2, "vmax": 3.0,
				"gravity": Vector3(0, 0.4, 0), "damp": 3.5, "c0": Color(0.14, 0.13, 0.12, 0.0), "cmid": Color(0.16, 0.15, 0.14, 0.48), "cmid_pos": 0.18, "c1": Color(0.20, 0.18, 0.17, 0.0), "grow0": 0.45, "grow1": 1.35, "soft_depth": 0.22})
	else:
		var dt := ground_dust_tint()
		A.burst(fx, p + nrm * 0.16, {"pool": "imp_dst_" + dt.to_html(false), "amount": 4, "life": 0.65, "size": 0.58, "tex": A.dust_tex(), "additive": false, "dir": nrm, "spread": 48.0, "vmin": 0.9, "vmax": 2.4,
			"gravity": Vector3(0, 0.2, 0), "damp": 3.5, "c0": Color(dt.r, dt.g, dt.b, 0.0), "cmid": Color(dt.r, dt.g, dt.b, 0.46), "cmid_pos": 0.15, "c1": Color(dt.r * 0.9, dt.g * 0.9, dt.b * 0.9, 0.0), "grow0": 0.4, "grow1": 1.55, "soft_depth": 0.22})
		# 3D 实体混凝土/岩石碎块蹦跳
		A.burst(fx, p, {"pool": "imp_rck", "amount": 6, "life": 0.58, "mesh": _debris_mesh("rock"), "additive": false, "dir": nrm, "spread": 55.0, "vmin": 2.5, "vmax": 6.2, "gravity": Vector3(0, -21, 0),
			"smin": 0.6, "smax": 1.2, "c0": Color(0.62, 0.58, 0.52), "c1": Color(0.4, 0.38, 0.35, 0.85), "grow0": 1.0, "grow1": 0.8})


func on_player_hurt(amount: float) -> void:
	shake = max(shake, clamp(amount / 40.0, 0.08, 0.4))
	hud.hurt()


var _corpses: Array = []
func _register_corpse(b) -> void:
	if b == null or not is_instance_valid(b) or bool(b.data.get("boss", false)):
		return
	_corpses.append(b)
	var cap := (8 if GameData.quality == 0 else 12) if A.is_mobile_perf() else 18
	while _corpses.size() > cap:
		var old = _corpses.pop_front()
		if is_instance_valid(old):
			old.visible = false
			if "vis_anchor" in old and old.vis_anchor != null and is_instance_valid(old.vis_anchor):
				old.vis_anchor.visible = false
			old.queue_free()


func on_bug_killed(b) -> void:
	var death_t := Prof.t0()
	var p: Vector3 = b.global_position
	_register_corpse(b)
	# 流浪者打死的虫不算玩家的击杀（不计数、不广播）；队友的击杀算进小队战绩
	var by = b.get("aggressor")
	if not (is_instance_valid(by) and by.is_in_group("rovers")):
		kills += 1
		_event("enemy_killed", [str(b.kind), p])
	Prof.add("death.event", death_t)
	death_t = Prof.t0()
	# 机械虫：油污 + 金属碎片（不是血）
	var sc: float = b.data.scale
	var oil := A.ground_vfx(world, A.grime_stain_tex(), Color(0.14, 0.13, 0.12, 0.82), 2.5 * sc, Vector3(p.x, 0.091, p.z), false, 0.44, false, 2)
	oil.rotation.y = rng.randf() * TAU
	_kill_decal(oil)
	Prof.add("death.decal", death_t)
	death_t = Prof.t0()
	# 画面外的死亡（流浪者 / 队友在远处打死的虫）不放粒子
	if mech != null and is_instance_valid(mech) and p.distance_squared_to(mech.global_position) > 60.0 * 60.0:
		if rng.randf() < float(b.data.drop):
			_place_box("bug", Vector3(p.x, 0, p.z))
		return
	A.burst(fx, p + Vector3(0, 0.8, 0), {"amount": 14, "life": 0.7, "size": 0.12 * sc, "additive": false, "vmin": 3.0, "vmax": 7.0, "gravity": Vector3(0, -18, 0), "damp": 0.6,
		"c0": Color(0.3, 0.3, 0.33), "c1": Color(0.18, 0.18, 0.2, 0.0), "grow0": 1.0, "grow1": 0.8})
	A.burst(fx, p + Vector3(0, 0.6, 0), {"amount": 8, "life": 0.5, "size": 0.25 * sc, "additive": false, "vmin": 1.5, "vmax": 3.5, "gravity": Vector3(0, -10, 0),
		"c0": Color(0.04, 0.04, 0.05, 0.9), "c1": Color(0.04, 0.04, 0.05, 0.0), "grow0": 1.0, "grow1": 0.4})
	if rng.randf() < float(b.data.drop):
		_place_box("bug", Vector3(p.x, 0, p.z))
	Prof.add("death.effects_loot", death_t)


## 尸体清理：虫子的油污 / 血迹贴花最多保留 MAX_KILL_DECALS 张，超出时淡掉最早的（v0.6 虫量翻倍后长局会堆上几百张）
const MAX_KILL_DECALS := 90
var _kill_decals: Array = []
func _kill_decal(d: Node3D) -> void:
	if d == null:
		return
	_kill_decals.append(d)
	while _kill_decals.size() > MAX_KILL_DECALS:
		var old = _kill_decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()


func on_nest_destroyed(n) -> void:
	var p: Vector3 = n.global_position
	explode(p, 5.0, 40.0)
	shake = 0.6
	_place_box("nest", Vector3(p.x, 0, p.z))
	hud.msg(Loc.t("虫巢核心坍塌，焦黑的残骸里渗出几点紫光虫晶。", "Nest core collapsed — violet bio-crystals seep from the charred wreck."))
	_event("nest_destroyed", [p])


# ================= 结束 =================
func _on_mech_died(reason: String) -> void:
	_finish(false, reason)


func _finish(success: bool, reason: String) -> void:
	if coop != null:
		coop.finish_player(Net.local_id(), success, reason)
		return
	if ended:
		return
	ended = true
	if open_box:
		close_box()
	mech.input_locked = true
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	var result := {
		"success": success,
		"reason": reason,
		"cargo": mech.cargo.duplicate(),
		"loadout": loadout.duplicate(),
		"start_cargo": start_cargo,
		"kills": kills,
		"time": time,
		"map_id": map_id,
	}
	await get_tree().create_timer(1.2).timeout
	raid_ended.emit(result)


func abandon() -> void:
	if coop != null and coop.route("abandon", []):
		return
	get_tree().paused = false
	_finish(false, Loc.t("驾驶员紧急弃机逃生，机甲与满舱物资遗弃在沦陷地表", "Pilot emergency ejection — mech and full cargo abandoned on the fallen surface"))



func _apply_fp_look_delta(rel: Vector2, sens_mult := 1.0) -> void:
	var fov_scale := clampf(_fp_fov / FP_FOV_STD, 0.32, 1.0)
	var rad_per_px := 0.0026 * GameData.mouse_sens * fov_scale * sens_mult
	fp_yaw = wrapf(fp_yaw - rel.x * rad_per_px, -PI, PI)
	fp_pitch = clampf(fp_pitch - rel.y * rad_per_px * 0.88, FP_PITCH_MIN, FP_PITCH_MAX)


func _unhandled_input(event: InputEvent) -> void:
	if Net.is_dedicated_server():
		return
	if is_first_person() and aim_override == null:
		var ui_open_m: bool = hud != null and (hud.pause_panel.visible or (hud.settings_panel != null and hud.settings_panel.visible) or hud.loot_panel.visible or hud.map_open())
		var story_m: bool = Story.get("flow") != null and Story.flow.is_playing()
		var can_look: bool = not dropping and not ended and not ui_open_m and not story_m
		if not can_look:
			_fp_look_touch_id = -1
		elif event is InputEventScreenTouch:
			if event.pressed:
				if _fp_look_touch_id == -1:
					_fp_look_touch_id = event.index
			elif event.index == _fp_look_touch_id:
				_fp_look_touch_id = -1
			return
		elif event is InputEventScreenDrag and event.index == _fp_look_touch_id:
			_apply_fp_look_delta(event.relative, 1.35)
			sync_fp_camera()
			return
		elif event is InputEventMouseMotion and (hud == null or not hud._touch_revealed) and not (hud != null and hud.is_touch_busy()):
			_apply_fp_look_delta(event.relative, 1.0)
			sync_fp_camera()
			return
		return
	_fp_look_touch_id = -1
	if is_first_person():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_zoom = clampf(cam_zoom - 0.06, ZOOM_MIN, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_zoom = clampf(cam_zoom + 0.06, ZOOM_MIN, ZOOM_MAX)
	elif event is InputEventMagnifyGesture:
		cam_zoom = clampf(cam_zoom / clampf(event.factor, 0.8, 1.25), ZOOM_MIN, ZOOM_MAX)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_pinch_pts[event.index] = event.position
			if _pinch_pts.size() == 2:
				var ks := _pinch_pts.keys()
				_pinch_dist = (_pinch_pts[ks[0]] as Vector2).distance_to(_pinch_pts[ks[1]])
		else:
			_pinch_pts.erase(event.index)
			if _pinch_pts.size() < 2:
				_pinch_dist = 0.0
	elif event is InputEventScreenDrag and _pinch_pts.has(event.index):
		_pinch_pts[event.index] = event.position
		if _pinch_pts.size() == 2 and (hud == null or not hud.is_touch_busy()):
			var ks := _pinch_pts.keys()
			var d := (_pinch_pts[ks[0]] as Vector2).distance_to(_pinch_pts[ks[1]])
			if _pinch_dist > 10.0 and d > 10.0:
				cam_zoom = clampf(cam_zoom * (_pinch_dist / d), ZOOM_MIN, ZOOM_MAX)
			_pinch_dist = d


# ================= 大地图：道路 + 区块 =================
const Maps = preload("res://scripts/maps.gd")
const WC = preload("res://scripts/world_city.gd")
const CELL := 40.0
const DISTRICT_NAMES := Maps.ZONE_NAMES
var map_id := "greyport"
var MAP: Dictionary = {}
var zones: Array = []            ## 9×9 区块字符表（数据原样；实际区块边界见 zone_at，是不规则的）
var layout: Dictionary = {}      ## 当前战区窗口的城市群布局（scripts/world_city.gd zone_layout，战区本地坐标）
var roads: Array = []            ## 旧版轴对齐网格路（v0.8 起不再使用，保留为空表）
var curves: Array = []           ## 全部道路（折线）：{pts: 加密点, d: 同 pts, w, dirt, kind, bridge}
var rivers: Array = []           ## 河道：{pts, w, dry}
var river_pts := PackedVector2Array()   ## 兼容：最宽的一条河
var river_w := 0.0
var river_dry := true
var ridge_pts: Array = []        ## Vector2：山脊巨石
var lakes: Array = []            ## Vector3(x, z, r)
var rail_lines: Array = []       ## [Vector2, Vector2]
var rail_polys: Array = []       ## 铁路折线 PackedVector2Array
var map_labels: Array = []
var poi_centers: Array = []
var poi_ids: Array = []          ## 与 poi_centers 一一对应的 POI 类型 id
var bldg_polys: Array = []       ## [PackedVector2Array, 区块字符]：这一局战区内实际建起来的建筑轮廓（地形图用）
var backdrop_bldg_polys: Array = []  ## [PackedVector2Array, 区块字符]：战区周界外连续城市群建筑轮廓（地形图用）
var zone_poly := PackedVector2Array() ## 当前战区的不规则多边形轮廓（本地坐标）
var is_surface_map := true
var _enforce_zone_bounds := true
var _zone_sdf := PackedFloat32Array() ## 4 米网格双线性插值有符号边界距离场（内部为正，外部为负）
var _sdf_o := Vector2.ZERO
var _sdf_n := 0
const _SDF_STEP := 4.0
var cur_district := ""
var _districts: Array = []          ## 战区细分地区分片（Voronoi 分区，覆盖全图）
var _sites: Array = []              ## 局部具名点位（遗迹 / 地标 / 撤离区 / 边界口）
var _cur_district_id := ""
var _cur_site_id := ""
var _shown_regions := {}            ## region_id -> 上次触发横幅时的局内时间（防边界抖动）
var _rg: WC.SegGrid              ## 道路线段索引
var _wg: WC.SegGrid              ## 河道线段索引
var _road_len := PackedFloat32Array()   ## 道路累计长度（随机取路面点用）


func _e(k: int) -> float:
	return -WC.HALF + CELL * k


## 查询点 q 到不规则战区多边形边界的有符号距离（米，内部为正，外部为负；O(1) 栅格双线性插值）
func border_dist(q: Vector2) -> float:
	if _sdf_n < 2 or _zone_sdf.is_empty():
		return WC.poly_signed_dist(zone_poly, q) if zone_poly.size() >= 3 else (HALF - maxf(absf(q.x), absf(q.y)))
	var fx := clampf((q.x - _sdf_o.x) / _SDF_STEP - 0.5, 0.0, float(_sdf_n - 1) - 0.0001)
	var fy := clampf((q.y - _sdf_o.y) / _SDF_STEP - 0.5, 0.0, float(_sdf_n - 1) - 0.0001)
	var ix := int(fx)
	var iy := int(fy)
	var tx := fx - float(ix)
	var ty := fy - float(iy)
	var v00 := _zone_sdf[iy * _sdf_n + ix]
	var v10 := _zone_sdf[iy * _sdf_n + ix + 1]
	var v01 := _zone_sdf[(iy + 1) * _sdf_n + ix]
	var v11 := _zone_sdf[(iy + 1) * _sdf_n + ix + 1]
	return lerpf(lerpf(v00, v10, tx), lerpf(v01, v11, tx), ty)


func in_bounds_xz(q: Vector2, margin := 0.0) -> bool:
	return border_dist(q) >= margin


func in_bounds(p: Vector3, margin := 0.0) -> bool:
	return border_dist(Vector2(p.x, p.z)) >= margin


## 将超出战区多边形（或不足 margin）的点推回多边形内侧
func clamp_to_zone(p: Vector3, margin := 6.0) -> Vector3:
	var q := Vector2(p.x, p.z)
	if in_bounds_xz(q, margin) or zone_poly.size() < 3:
		return p
	var m := zone_poly.size()
	var best_d := INF
	var best_cp := zone_poly[0]
	var best_inw := Vector2.ZERO
	var ccw := WC.poly_area_signed(zone_poly) > 0.0
	for i in m:
		var a := zone_poly[i]
		var b := zone_poly[(i + 1) % m]
		var ab := b - a
		var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var cp := a + ab * t
		var d := q.distance_to(cp)
		if d < best_d:
			best_d = d
			best_cp = cp
			var ed := ab.normalized()
			best_inw = Vector2(-ed.y, ed.x) if ccw else Vector2(ed.y, -ed.x)
	var nq := best_cp + best_inw * (margin + 0.5)
	if not in_bounds_xz(nq, margin * 0.6):
		nq = nq.lerp(WC.centroid(zone_poly), 0.25)
	return Vector3(nq.x, p.y, nq.y)


func _load_map(sliced := false) -> void:
	rng.seed = _map_seed(0)
	MAP = GameData.map_data(map_id)
	zones = MAP.zones
	layout = WC.zone_layout(map_id)
	zone_poly = layout.get("poly", WC.zone_poly(map_id))
	is_surface_map = bool(layout.get("surface", WC.is_surface(map_id)))
	EXT_HALF = float(layout.get("ext_half", WC.BACKDROP_HALF if is_surface_map else HALF))
	var sdf_half := EXT_HALF + 20.0
	_sdf_o = Vector2(-sdf_half, -sdf_half)
	_sdf_n = int(roundf(sdf_half * 2.0 / _SDF_STEP))
	_zone_sdf.resize(_sdf_n * _sdf_n)
	for sy in _sdf_n:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		var qz := _sdf_o.y + (float(sy) + 0.5) * _SDF_STEP
		for sx in _sdf_n:
			var qx := _sdf_o.x + (float(sx) + 0.5) * _SDF_STEP
			_zone_sdf[sy * _sdf_n + sx] = WC.poly_signed_dist(zone_poly, Vector2(qx, qz))
	bldg_polys.clear()
	backdrop_bldg_polys.clear()
	roads.clear()
	curves.clear()
	_rg = WC.SegGrid.new()
	_rg.cell = 12.0
	_rg.reach = 12.0
	_road_len = PackedFloat32Array()
	var acc := 0.0
	for r: Dictionary in layout.roads:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		var pts: PackedVector2Array = r.pts
		var w_def := float(r.w)
		curves.append({"pts": pts, "d": pts, "w": w_def, "w0": float(r.get("w0", w_def)), "w1": float(r.get("w1", w_def)), "dirt": bool(r.dirt), "kind": str(r.kind), "bridge": bool(r.bridge), "caps": r.get("caps", [false, false]), "tangent_mates": PackedInt32Array(), "mate_ends": [false, false], "mate_dirs": [Vector2.ZERO, Vector2.ZERO]})
		_rg.add_poly(pts, w_def * 0.5, curves.size() - 1)
		for k in pts.size() - 1:
			acc += pts[k].distance_to(pts[k + 1])
		_road_len.append(acc)
	for ci in curves.size():
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		var pi_pts: PackedVector2Array = curves[ci].d
		if pi_pts.size() < 2 or bool(curves[ci].dirt):
			continue
		for cj in range(ci + 1, curves.size()):
			var pj_pts: PackedVector2Array = curves[cj].d
			if pj_pts.size() < 2 or bool(curves[cj].dirt):
				continue
			for ei in 2:
				var pei := pi_pts[0] if ei == 0 else pi_pts[pi_pts.size() - 1]
				var toi := (pi_pts[0] - pi_pts[1]).normalized() if ei == 0 else (pi_pts[pi_pts.size() - 1] - pi_pts[pi_pts.size() - 2]).normalized()
				for ej in 2:
					var pej := pj_pts[0] if ej == 0 else pj_pts[pj_pts.size() - 1]
					if pei.distance_to(pej) > 0.85:
						continue
					var toj := (pj_pts[0] - pj_pts[1]).normalized() if ej == 0 else (pj_pts[pj_pts.size() - 1] - pj_pts[pj_pts.size() - 2]).normalized()
					if toi != Vector2.ZERO and toj != Vector2.ZERO and toi.dot(toj) < -0.90:
						var mi: PackedInt32Array = curves[ci].tangent_mates
						mi.append(cj)
						curves[ci].tangent_mates = mi
						var mj: PackedInt32Array = curves[cj].tangent_mates
						mj.append(ci)
						curves[cj].tangent_mates = mj
						curves[ci].mate_ends[ei] = true
						curves[cj].mate_ends[ej] = true
						var bis := (toi - toj).normalized()
						if bis != Vector2.ZERO:
							curves[ci].mate_dirs[ei] = bis
							curves[cj].mate_dirs[ej] = -bis
	for ci in curves.size():
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		curves[ci].d = _bezier_refine_road(curves[ci])
	rivers.clear()
	_wg = WC.SegGrid.new()
	_wg.cell = 16.0
	_wg.reach = 16.0
	river_pts = PackedVector2Array()
	river_w = 0.0
	river_dry = true
	for r: Dictionary in layout.rivers:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		var pts: PackedVector2Array = r.pts
		if pts.size() < 2:
			continue
		rivers.append({"pts": pts, "w": float(r.w), "dry": bool(r.dry)})
		_wg.add_poly(pts, float(r.w) * 0.5, rivers.size() - 1)
		if float(r.w) > river_w or (river_dry and not r.dry):
			river_pts = pts
			river_w = float(r.w)
			river_dry = bool(r.dry)
	lakes = (layout.lakes as Array).duplicate()
	rail_lines.clear()
	rail_polys.clear()
	for line: PackedVector2Array in layout.rails:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		rail_polys.append(line)
		for k in line.size() - 1:
			rail_lines.append([line[k], line[k + 1]])
	map_labels = MAP.labels


## 区块字符：城市群布局的区块栅格（2 米），边界是不规则的
func zone_at(p: Vector3) -> String:
	var n: int = layout.r_n
	var o: Vector2 = layout.r_o
	var x := clampi(floori((p.x - o.x) / WC.RAST), 0, n - 1)
	var y := clampi(floori((p.z - o.y) / WC.RAST), 0, n - 1)
	return char(layout.rast[y * n + x])


const _LM_ZH_NAMES := {
	"broken_bridge": "灰港断桥", "radio_mast": "旧城广播塔", "elevated_road": "高架残段", "central_terminus": "中央穹顶总站",
	"gantry": "运河龙门吊", "blast_furnace": "一号钢厂高炉", "gas_holder": "煤气罐区", "converter_foundry": "二号转炉钢厂",
	"windmill": "风车阵", "pylon_row": "高压电塔列", "silo": "农场筒仓", "missile_silo": "洲际发射井阵地",
	"boardwalk": "赤湖观景栈桥", "observation_tower": "环湖观景塔", "spillway_dam": "赤湖溢洪闸枢",
	"submarine_drydock": "巨型潜艇干船坞",
	"cable_tower": "峡谷缆车塔", "ore_silos": "矿场筒仓", "rope_bridge": "悬崖索桥", "bucket_excavator": "斗轮挖掘机平台",
	"coolant_channel": "冷却渠", "crystal_cluster": "晶脉簇", "drill_derrick": "钻井残台", "geothermal_vault": "地热磁约束腔",
}


## 将当前战区细分为「局部具名点位（遗迹 / 地标 / 撤离区 / 边界口）」与「全图连续地区分片（Voronoi 分区）」
func _build_subregions() -> void:
	_districts.clear()
	_sites.clear()
	var zone_name := str(MAP.get("name", map_id))
	var exclude_names := {"虫巢": true, "Swarm Hive": true, "Hive": true}

	# 1. 重点遗迹 POI（包含核心 3 处与全部扩展遗迹）
	for i in poi_centers.size():
		var pc: Vector3 = poi_centers[i]
		var pid: String = str(poi_ids[i]) if i < poi_ids.size() else str(i)
		var pname := str(GameData.POIS.get(pid, {}).get("name", pid))
		exclude_names[pname] = true
		_sites.append({
			"id": "poi:%s_%d" % [pid, i],
			"kind": "poi",
			"raw_name": pname,
			"title": pname,
			"sub": Loc.t("%s · 遗迹" % zone_name, "%s · RUIN" % zone_name),
			"pos": Vector2(pc.x, pc.z),
			"r_in": 22.0,
			"r_out": 28.0,
		})

	# 2. 重要地标建筑
	var lms: Array = get_meta("ext_landmarks", [])
	for i in lms.size():
		var lm: Dictionary = lms[i]
		var ltype := str(lm.get("type", ""))
		var zh_n := str(_LM_ZH_NAMES.get(ltype, ltype))
		var lname := Loc.landmark_name(ltype, zh_n)
		exclude_names[zh_n] = true
		exclude_names[lname] = true
		var clr := float(lm.get("clear", 8.0))
		var r_in := maxf(18.0, clr + 8.0)
		_sites.append({
			"id": "lm:%s_%d" % [ltype, i],
			"kind": "landmark",
			"raw_name": zh_n,
			"title": lname,
			"sub": Loc.t("%s · 地标" % zone_name, "%s · LANDMARK" % zone_name),
			"pos": Vector2(float(lm.get("x", 0.0)), float(lm.get("z", 0.0))),
			"r_in": r_in,
			"r_out": r_in + 6.0,
		})

	# 3. 撤离点
	for i in extracts.size():
		var z = extracts[i]
		if z == null or not is_instance_valid(z):
			continue
		var r_in: float = float(z.radius) + 7.5
		_sites.append({
			"id": "ext:%d" % i,
			"kind": "extract",
			"raw_name": str(z.title),
			"title": str(z.title),
			"sub": Loc.t("%s · 撤离区" % zone_name, "%s · EXTRACTION" % zone_name),
			"pos": Vector2(z.global_position.x, z.global_position.z),
			"r_in": r_in,
			"r_out": r_in + 5.0,
		})

	# 4. 战区边界转场口与隐藏深井升降台
	if world_link != null and is_instance_valid(world_link):
		if "gates" in world_link:
			for edge_k in world_link.gates:
				var g: Dictionary = world_link.gates[edge_k]
				var gp: Vector2 = g.pos as Vector2
				var gtitle := Loc.t("通往 %s" % g.name, "To %s" % g.name) if bool(g.get("open", false)) else Loc.t("%s · 尚未开放" % g.name, "%s · LOCKED" % g.name)
				_sites.append({
					"id": "gate:%s" % str(edge_k),
					"kind": "gate",
					"raw_name": gtitle,
					"title": gtitle,
					"sub": Loc.t("%s · 战区边界" % zone_name, "%s · BORDER" % zone_name),
					"pos": gp,
					"r_in": 15.0,
					"r_out": 21.0,
				})
		if "shaft" in world_link and not (world_link.shaft as Dictionary).is_empty():
			var sh: Dictionary = world_link.shaft
			var sh_title := Loc.t("深井升降台 · %s" % sh.name, "Shaft Lift · %s" % sh.name)
			_sites.append({
				"id": "shaft:abyss_maw",
				"kind": "gate",
				"raw_name": sh_title,
				"title": sh_title,
				"sub": Loc.t("%s · 战区边界" % zone_name, "%s · BORDER" % zone_name),
				"pos": sh.pos as Vector2,
				"r_in": 11.0,
				"r_out": 16.0,
			})

	# 5. 全图连续细分地区（从 map_labels 剔除 POI / 地标同名项，构成全战区 Voronoi 地区分片）
	var seen_dist := {}
	for l: Array in map_labels:
		var raw_n := str(l[0])
		var loc_n := Loc.map_label(raw_n)
		if exclude_names.has(raw_n) or exclude_names.has(loc_n) or seen_dist.has(raw_n):
			continue
		seen_dist[raw_n] = true
		_districts.append({
			"id": "dist:%s" % raw_n,
			"raw_name": raw_n,
			"title": loc_n,
			"sub": Loc.t("进入地区 · %s" % zone_name, "ENTERING DISTRICT · %s" % zone_name),
			"pos": Vector2(float(l[1]), float(l[2])),
		})


func _find_site_entry(q: Vector2, cur_id: String) -> Dictionary:
	var best := {}
	var best_d := INF
	var cur_site := {}
	var all_sites: Array = _sites
	for s: Dictionary in all_sites:
		var d := q.distance_to(s.pos as Vector2)
		if str(s.id) == cur_id and d <= float(s.r_out):
			cur_site = s
		if d <= float(s.r_in) and d < best_d:
			best_d = d
			best = s
	if transport_zone != null and is_instance_valid(transport_zone) and transport_zone.active:
		var tzp := Vector2(transport_zone.global_position.x, transport_zone.global_position.z)
		var td := q.distance_to(tzp)
		var tr_in := float(transport_zone.radius) + 7.5
		var zone_name := str(MAP.get("name", map_id))
		var t_entry := {
			"id": "ext:transport",
			"kind": "extract",
			"raw_name": str(transport_zone.title),
			"title": str(transport_zone.title),
			"sub": Loc.t("%s · 撤离区" % zone_name, "%s · EXTRACTION" % zone_name),
			"pos": tzp,
			"r_in": tr_in,
			"r_out": tr_in + 5.0,
		}
		if cur_id == "ext:transport" and td <= tr_in + 5.0:
			cur_site = t_entry
		if td <= tr_in and td < best_d:
			best_d = td
			best = t_entry
	if not best.is_empty():
		return best
	return cur_site


func _find_district_entry(q: Vector2, cur_id: String) -> Dictionary:
	if _districts.is_empty():
		return {}
	var best := {}
	var best_d := INF
	var cur_entry := {}
	var cur_d := INF
	for d_item: Dictionary in _districts:
		var dist := q.distance_to(d_item.pos as Vector2)
		if str(d_item.id) == cur_id:
			cur_entry = d_item
			cur_d = dist
		if dist < best_d:
			best_d = dist
			best = d_item
	# 8m 边界滞回：在两片地区交界处行进时不反复抖动切换
	if not cur_entry.is_empty() and str(best.id) != cur_id and best_d + 8.0 >= cur_d:
		return cur_entry
	return best


func _init_subregion(at: Vector3, delay: float) -> void:
	var zone_name := str(MAP.get("name", map_id))
	var q := Vector2(at.x, at.z)
	var dist := _find_district_entry(q, "")
	var site := _find_site_entry(q, "")
	_cur_district_id = str(dist.get("id", ""))
	_cur_site_id = str(site.get("id", ""))
	cur_district = str(site.get("raw_name", dist.get("raw_name", "")))
	_shown_regions.clear()
	if _cur_district_id != "":
		_shown_regions[_cur_district_id] = time
	if _cur_site_id != "":
		_shown_regions[_cur_site_id] = time
	var title := str(site.get("title", dist.get("title", "")))
	if title != "":
		hud.show_zone_banner(title, delay, Loc.t("进入战区 · %s" % zone_name, "ENTERING SECTOR · %s" % zone_name))
	else:
		hud.show_zone_banner(zone_name, delay, Loc.t("进入战区", "ENTERING SECTOR"))


## 实时检测玩家进入细分地区 / 遗迹 / 地标 / 撤离区：每次进入新分片时在顶部显示一次提示，停留期间不重复
func _update_subregion(mp: Vector3) -> void:
	var q := Vector2(mp.x, mp.z)
	var site := _find_site_entry(q, _cur_site_id)
	var dist := _find_district_entry(q, _cur_district_id)
	var new_site_id := str(site.get("id", ""))
	var new_dist_id := str(dist.get("id", ""))

	var entered_site := new_site_id != "" and new_site_id != _cur_site_id
	var entered_dist := new_dist_id != "" and new_dist_id != _cur_district_id
	_cur_site_id = new_site_id
	_cur_district_id = new_dist_id

	var active_raw := str(site.get("raw_name", dist.get("raw_name", "")))
	if active_raw != "" and active_raw != cur_district:
		if cur_district != "":
			_event("district_entered", [active_raw])
		cur_district = active_raw

	const COOLDOWN := 10.0
	if entered_site:
		if time - float(_shown_regions.get(new_site_id, -999.0)) >= COOLDOWN:
			_shown_regions[new_site_id] = time
			hud.show_zone_banner(str(site.title), 0.04, str(site.sub))
	elif entered_dist and _cur_site_id == "":
		if time - float(_shown_regions.get(new_dist_id, -999.0)) >= COOLDOWN:
			_shown_regions[new_dist_id] = time
			hud.show_zone_banner(str(dist.title), 0.04, str(dist.sub))


## 当前所在地名：优先返回精确进入的遗迹/地标名，否则返回所属细分地区分片名
func district_at(p: Vector3) -> String:
	var q := Vector2(p.x, p.z)
	if not _sites.is_empty():
		var best_s := ""
		var sd := INF
		for s: Dictionary in _sites:
			var k := str(s.get("kind", ""))
			if k != "poi" and k != "landmark":
				continue
			var d := q.distance_to(s.pos as Vector2)
			if d <= float(s.r_in) and d < sd:
				sd = d
				best_s = str(s.raw_name)
		if best_s != "":
			return best_s
	if not _districts.is_empty():
		var best_d := ""
		var bd := INF
		for d_item: Dictionary in _districts:
			var dist2 := q.distance_squared_to(d_item.pos as Vector2)
			if dist2 < bd:
				bd = dist2
				best_d = str(d_item.raw_name)
		if best_d != "":
			return best_d
	var best := ""
	var bd2 := INF
	for l: Array in map_labels:
		var d := q.distance_squared_to(Vector2(l[1], l[2]))
		if d < bd2:
			bd2 = d
			best = l[0]
	return best


## 是否在路面上（pad > 0 外扩，< 0 内缩）
func _rg_edge_dist_ignore(g: WC.SegGrid, p: Vector2, skip: int, mates: PackedInt32Array) -> float:
	if mates.is_empty():
		return g.edge_dist(p, skip)
	var lst = g.grid.get(Vector2i(floori(p.x / g.cell), floori(p.y / g.cell)))
	if lst == null:
		return INF
	var best := INF
	for i: int in lst:
		var tg := g.tag[i]
		if tg == skip or (tg in mates):
			continue
		var ab: Vector2 = g.b[i] - g.a[i]
		var t := clampf((p - g.a[i]).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d := p.distance_to(g.a[i] + ab * t) - g.hw[i]
		if d < best:
			best = d
	return best


func on_road(p: Vector2, pad := 0.0) -> bool:
	return _rg != null and _rg.edge_dist(p) < pad


func on_curve(p: Vector2, pad := 0.0) -> bool:
	return on_road(p, pad)


func _pdist(pts: PackedVector2Array, p: Vector2) -> float:
	return WC.poly_dist(pts, p)


## 到最近河道中心线的距离
func river_dist(p: Vector2) -> float:
	var best := INF
	if _wg == null:
		return best
	var lst = _wg.grid.get(Vector2i(floori(p.x / _wg.cell), floori(p.y / _wg.cell)))
	if lst != null:
		for i: int in lst:
			best = minf(best, WC.seg_dist(p, _wg.a[i], _wg.b[i]))
	return best


func in_lake(p: Vector2, pad := 0.0) -> bool:
	for l: Vector3 in lakes:
		if WC.lake_dist(l, p) < pad:
			return true
	return false


## 河道（含干河床）或湖：不摆建筑
func in_river(p: Vector2, pad := 0.0) -> bool:
	return (_wg != null and _wg.edge_dist(p) < pad) or in_lake(p, pad)


## 真有水的地方
func in_wet(p: Vector2, pad := 0.0) -> bool:
	if in_lake(p, pad):
		return true
	if _wg == null:
		return false
	var lst = _wg.grid.get(Vector2i(floori(p.x / _wg.cell), floori(p.y / _wg.cell)))
	if lst == null:
		return false
	for i: int in lst:
		if not rivers[_wg.tag[i]].dry and WC.seg_dist(p, _wg.a[i], _wg.b[i]) - _wg.hw[i] < pad:
			return true
	return false


## 落在有水的河湖里（或贴着护堤）的点挪到最近的岸上；桥面上的点不动。找不到就原样返回
func dry_spot(p: Vector3, pad := 1.5) -> Vector3:
	var q := Vector2(p.x, p.z)
	if not in_wet(q, pad) or _on_bridge(q, -0.5):
		return p
	var r := 2.0
	while r <= 40.0:
		var n := maxi(12, int(TAU * r / 2.0))
		var a0 := fposmod(q.x * 0.37 + q.y * 0.11, TAU)
		for k in n:
			var a := a0 + TAU * k / n
			var c := q + Vector2(cos(a), sin(a)) * r
			if in_bounds_xz(c, 4.5) and not in_wet(c, pad):
				return Vector3(c.x, p.y, c.y)
		r += 2.0
	return p


## 导航网格用（scripts/nav_grid.gd）：n×n 格（原点 o、边长 cell）里格心落在有水的河湖里的格子记 1，桥面上的格子记 0
func water_cells(o: Vector2, n: int, cell: float) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(n * n)
	var cr := func(x0: float, z0: float, x1: float, z1: float) -> Rect2i:
		var i0 := clampi(floori((x0 - o.x) / cell), 0, n - 1)
		var j0 := clampi(floori((z0 - o.y) / cell), 0, n - 1)
		var i1 := clampi(floori((x1 - o.x) / cell), 0, n - 1)
		var j1 := clampi(floori((z1 - o.y) / cell), 0, n - 1)
		return Rect2i(i0, j0, i1 - i0 + 1, j1 - j0 + 1)
	for l: Vector3 in lakes:
		var lr_max := l.z * 1.45
		var r: Rect2i = cr.call(l.x - lr_max, l.y - lr_max, l.x + lr_max, l.y + lr_max)
		for j in range(r.position.y, r.end.y):
			for i in range(r.position.x, r.end.x):
				var c := o + Vector2((i + 0.5) * cell, (j + 0.5) * cell)
				if WC.lake_dist(l, c) < 0.0:
					out[j * n + i] = 1
	for rv: Dictionary in rivers:
		if rv.dry:
			continue
		var pts: PackedVector2Array = rv.pts
		var hw: float = float(rv.w) * 0.5
		for k in pts.size() - 1:
			var a := pts[k]
			var b := pts[k + 1]
			var r: Rect2i = cr.call(minf(a.x, b.x) - hw, minf(a.y, b.y) - hw, maxf(a.x, b.x) + hw, maxf(a.y, b.y) + hw)
			for j in range(r.position.y, r.end.y):
				for i in range(r.position.x, r.end.x):
					var c := o + Vector2((i + 0.5) * cell, (j + 0.5) * cell)
					if WC.seg_dist(c, a, b) < hw:
						out[j * n + i] = 1
	for br: Array in bridges:
		var a: Vector2 = br[0]
		var b: Vector2 = br[1]
		var hw := float(br[2]) * 0.5
		var r: Rect2i = cr.call(minf(a.x, b.x) - hw, minf(a.y, b.y) - hw, maxf(a.x, b.x) + hw, maxf(a.y, b.y) + hw)
		for j in range(r.position.y, r.end.y):
			for i in range(r.position.x, r.end.x):
				var c := o + Vector2((i + 0.5) * cell, (j + 0.5) * cell)
				if WC.seg_dist(c, a, b) < hw:
					out[j * n + i] = 0
	return out


## 9×9 数据格子的范围（虫群分布表、空投点等按格子统计的逻辑仍用它；格子里实际的区块见 zone_at）
func _cell_rect(i: int, j: int) -> Rect2:
	return Rect2(_e(i) + 2.0, _e(j) + 2.0, CELL - 4.0, CELL - 4.0)


func _spot_in(r: Rect2, rad: float, tries := 40) -> Vector3:
	for t in tries:
		var p := Vector3(rng.randf_range(r.position.x + rad, r.end.x - rad), 0, rng.randf_range(r.position.y + rad, r.end.y - rad))
		if not _blocked(p, rad):
			return p
	return Vector3.INF


## 凸多边形里的随机空地
func _spot_in_poly(poly: PackedVector2Array, rad: float, tries := 30) -> Vector3:
	var r := WC._poly_rect(poly)
	for t in tries:
		var q := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
		if not WC.in_convex(poly, q):
			continue
		var p := Vector3(q.x, 0, q.y)
		if in_bounds(p, rad + 3.5) and not _blocked(p, rad):
			return p
	return Vector3.INF


func _loot_in(r: Rect2, n: int, weights: Dictionary) -> void:
	var cnt := maxi(1, roundi(n * r.get_area() / 4900.0))
	for i in cnt:
		var p := _spot_in(r, 1.4)
		if p == Vector3.INF:
			continue
		_place_box(GameData._weighted(weights, rng), p)
		blocks.append(Rect2(p.x - 1, p.z - 1, 2, 2))


## 旋转矩形登记占地：轴对齐时一块，斜放时切成约 4 米的小块（每块取外接矩形），避免整个外接矩形把街道也占掉
func _obb_blocks(c: Vector2, ang: float, sx: float, sz: float) -> void:
	var s2 := absf(sin(ang * 2.0))
	if s2 < 0.17:
		var q := fposmod(ang + PI * 0.25, PI)
		if q > PI * 0.5:
			blocks.append(Rect2(c.x - sz * 0.5, c.y - sx * 0.5, sz, sx))
		else:
			blocks.append(Rect2(c.x - sx * 0.5, c.y - sz * 0.5, sx, sz))
		return
	var u := Vector2(cos(ang), sin(ang))
	var v := Vector2(-sin(ang), cos(ang))
	var nx := maxi(1, ceili(sx / 4.5))
	var nz := maxi(1, ceili(sz / 4.5))
	var cx := sx / nx
	var cz := sz / nz
	var ex := (absf(u.x) * cx + absf(v.x) * cz) * 0.5 * 0.92
	var ez := (absf(u.y) * cx + absf(v.y) * cz) * 0.5 * 0.92
	for i in nx:
		for j in nz:
			var q: Vector2 = c + u * (-sx * 0.5 + (i + 0.5) * cx) + v * (-sz * 0.5 + (j + 0.5) * cz)
			blocks.append(Rect2(q.x - ex, q.y - ez, ex * 2.0, ez * 2.0))


func _build_map() -> Vector3:
	_tlast = Time.get_ticks_usec()
	_shield_spots()
	_tmark("shield_spots")
	_build_river()
	_build_lakes()
	_build_roads()
	_build_rails()
	_build_ridges()
	_tmark("roads+water+rails")
	poi_centers.clear()
	poi_ids.clear()
	for p: Dictionary in layout.pois:
		poi_centers.append(Vector3(p.c.x, 0, p.c.y))
		poi_ids.append(str(p.id))
	# 遗迹院落自己的摆放不受留空区约束
	var kc := _keep_clear
	_keep_clear = []
	_build_pois()
	_keep_clear = kc
	_tmark("pois")
	_build_blocks()
	_tmark("blocks")
	_build_fields()
	_scatter()
	_tmark("fields+scatter")
	rng.seed = _map_seed(11)
	# 道路两侧路沿石旁顺向停靠的废弃车辆 / 人行道边火桶（避开路口、桥面、平交道口与河道）
	for k in 32:
		var sp := _curb_car_spot()
		if not sp.is_empty():
			_wreck_car(sp[0], float(sp[1]))
	for k in 10:
		var p := _roadside_spot()
		if p != Vector3.INF:
			_fire_barrel(p)
	_scatter_road_shoulders()
	_register_roadside_car_loot()
	return _drop_point()   # _keep_clear 保留到扩展脚本里的地标落位前（_run_ext_build）


## 转场口通道与地标原位：这一段生成杂物时避开（转场口位置是确定的，见 world_city.gd gate_along）
func _shield_spots() -> void:
	_keep_clear.clear()
	for edge: String in WorldLinkScript.LINKS.get(map_id, {}):
		var info := WC.gate_info(map_id, edge)
		var gp: Vector2 = info.pos
		var inw: Vector2 = info.inward
		var hs: float = WorldLinkScript.HALF_SPAN + 4.0
		for d_step: float in [0.0, 12.0, 24.0]:
			var qc := gp + inw * d_step
			_keep_clear.append(Vector3(qc.x, qc.y, hs))
	# 地标：用方形留空（地标脚本按方形探测占地），再多留 4 米，盖住杂物占地矩形超出其探测半径的部分（如 12 米长的断墙）
	for e in MAP.get("landmarks", []):
		if not bool(e.get("water", false)):
			var ls := WC.landmark_spot(map_id, e)
			var h := float(e.get("clear", 7.0)) + 4.0
			_keep_clear.append(Rect2(ls.x - h, ls.y - h, h * 2.0, h * 2.0))
	# 撤离候选点停机坪留空 9.5 米，防止集装箱、巨石等碰撞杂物压住撤离圈中心
	for ex: Array in MAP.get("extracts", []):
		_keep_clear.append(Vector3(float(ex[1]), float(ex[2]), 9.5))


## 随机路面点（按道路长度加权）
func _road_point(edge: float) -> Vector3:
	if curves.is_empty():
		return _free_spot(2.0)
	for t in 8:
		var total: float = _road_len[_road_len.size() - 1]
		var x := rng.randf() * total
		var i := _road_len.bsearch(x)
		i = clampi(i, 0, curves.size() - 1)
		var cv: Dictionary = curves[i]
		var d: PackedVector2Array = cv.d
		if d.size() < 3:
			continue
		var j := rng.randi_range(1, d.size() - 2)
		var tg := (d[j + 1] - d[j - 1]).normalized()
		var q := d[j] + Vector2(-tg.y, tg.x) * rng.randf_range(-1.0, 1.0) * maxf(0.0, cv.w * 0.5 - edge)
		if in_bounds_xz(q, 6.0):
			return Vector3(q.x, 0, q.y)
	return _free_spot(2.0)


## 紧贴道路外侧路沿顺向停放的车位：[Vector3 pos, float yaw_deg]，避开交叉路口、桥面、铁轨与转角
func _curb_car_spot() -> Array:
	if curves.is_empty():
		return []
	for t in 16:
		var total: float = _road_len[_road_len.size() - 1]
		var x := rng.randf() * total
		var i := clampi(_road_len.bsearch(x), 0, curves.size() - 1)
		var cv: Dictionary = curves[i]
		if cv.dirt or float(cv.w) < 7.0:
			continue
		var d: PackedVector2Array = cv.d
		if d.size() < 4:
			continue
		var j := rng.randi_range(1, d.size() - 2)
		var a := d[j - 1]
		var b := d[j + 1]
		if (d[j] - a).normalized().dot((b - d[j]).normalized()) < 0.96:
			continue
		var tg := (b - a).normalized()
		var nrm := Vector2(-tg.y, tg.x)
		var sd := 1.0 if rng.randf() < 0.5 else -1.0
		var off := maxf(1.45, float(cv.w) * 0.5 - WALK_W - 0.85)
		var q := d[j] + nrm * sd * off
		if not in_bounds_xz(q, 10.0):
			continue
		if _rg_edge_dist_ignore(_rg, q, i, cv.get("tangent_mates", PackedInt32Array())) < 8.5 or _on_bridge(q, 5.0) or in_river(q, 4.5):
			continue
		var on_rail := false
		for rl: PackedVector2Array in rail_polys:
			if WC.poly_dist(rl, q) < 4.8:
				on_rail = true
				break
		if on_rail:
			continue
		var p := Vector3(q.x, 0, q.y)
		if _blocked(p, 4.3, false):
			continue
		var too_close := false
		for prev_q: Vector2 in _curb_car_pts:
			if prev_q.distance_squared_to(q) < 15.0 * 15.0:
				too_close = true
				break
		if too_close:
			continue
		_curb_car_pts.append(q)
		var yaw := rad_to_deg(atan2(tg.x, tg.y)) + (0.0 if sd > 0.0 else 180.0) + rng.randf_range(-4.0, 4.0)
		return [p, yaw]
	return []


## 公路与荒原/农田交界处的碎裂路缘石与风沙掩埋过渡段（P0-M2.2 ter_road_shoulder），打破路面直线硬切边
func _scatter_road_shoulders() -> void:
	if curves.is_empty() or _road_len.is_empty():
		return
	var saved_seed := rng.seed
	rng.seed = _map_seed(21)
	var placed_pts: Array = []
	var total: float = _road_len[_road_len.size() - 1]
	for attempt in 96:
		if placed_pts.size() >= 34:
			break
		var x := rng.randf() * total
		var ci := clampi(_road_len.bsearch(x), 0, curves.size() - 1)
		var cv: Dictionary = curves[ci]
		if bool(cv.get("dirt", false)) or float(cv.w) < 7.0:
			continue
		var d: PackedVector2Array = cv.d
		if d.size() < 5:
			continue
		var j := rng.randi_range(2, d.size() - 3)
		var a := d[j - 1]
		var b := d[j + 1]
		if (d[j] - a).normalized().dot((b - d[j]).normalized()) < 0.985:
			continue
		var tg := (b - a).normalized()
		var sd := 1.0 if rng.randf() < 0.5 else -1.0
		var out_n := Vector2(-tg.y, tg.x) * sd
		var q_out := d[j] + out_n * (float(cv.w) * 0.5 + 2.6)
		if not in_bounds_xz(q_out, 8.0):
			continue
		var zc := zone_at(Vector3(q_out.x, 0.0, q_out.y))
		if not (zc in ["W", "F", "C"]):
			continue
		if _rg_edge_dist_ignore(_rg, d[j], ci, cv.get("tangent_mates", PackedInt32Array())) < 10.5 or _on_bridge(d[j], 6.0) or in_wet(q_out, 4.0):
			continue
		var p_out := Vector3(q_out.x, 0.0, q_out.y)
		if _blocked(p_out, 4.2, false):
			continue
		var q_seg := d[j] + out_n * (float(cv.w) * 0.5 - 0.35)
		var too_close := false
		for prev: Vector2 in placed_pts:
			if prev.distance_squared_to(q_seg) < 185.0:
				too_close = true
				break
		if too_close:
			continue
		placed_pts.append(q_seg)
		var yaw_deg := rad_to_deg(atan2(out_n.x, out_n.y))
		PrefabLib.place_at_ground(self, world, "ter_road_shoulder", Vector3(q_seg.x, -0.145, q_seg.y), yaw_deg, Vector3(11.6, 0.58, 6.0))
	rng.seed = saved_seed


## 沿公路外侧路肩/停车带登记可搜刮的抛锚轿车（car_wreck）锚点：车体顺路停靠，不占主车道、不堵路口
func _register_roadside_car_loot() -> void:
	if curves.is_empty() or _road_len.is_empty():
		return
	var crng := RandomNumberGenerator.new()
	crng.seed = _map_seed(22)
	var total: float = _road_len[_road_len.size() - 1]
	var added: Array = []
	for attempt in 96:
		if added.size() >= 18:
			break
		var x := crng.randf() * total
		var ci := clampi(_road_len.bsearch(x), 0, curves.size() - 1)
		var cv: Dictionary = curves[ci]
		if bool(cv.get("dirt", false)) or float(cv.w) < 7.0:
			continue
		var d: PackedVector2Array = cv.d
		if d.size() < 5:
			continue
		var j := crng.randi_range(2, d.size() - 3)
		var a := d[j - 1]
		var b := d[j + 1]
		if (d[j] - a).normalized().dot((b - d[j]).normalized()) < 0.97:
			continue
		var tg := (b - a).normalized()
		var sd := 1.0 if crng.randf() < 0.5 else -1.0
		var out_n := Vector2(-tg.y, tg.x) * sd
		var q := d[j] + out_n * (float(cv.w) * 0.5 + 1.05)
		if not in_bounds_xz(q, 10.0) or in_wet(q, 3.0) or _on_bridge(d[j], 5.5):
			continue
		if _rg_edge_dist_ignore(_rg, d[j], ci, cv.get("tangent_mates", PackedInt32Array())) < 9.0:
			continue
		var on_rail := false
		for rl: PackedVector2Array in rail_polys:
			if WC.poly_dist(rl, q) < 5.0:
				on_rail = true
				break
		if on_rail:
			continue
		var p := Vector3(q.x, 0.0, q.y)
		var zc := zone_at(p)
		if not (zc in ["D", "R", "I", "H", "W", "C"]):
			continue
		if _blocked(p, 1.5, false):
			continue
		var too_close := false
		for prev_q: Vector2 in added:
			if prev_q.distance_squared_to(q) < 28.0 * 28.0:
				too_close = true
				break
		if too_close:
			continue
		for car_q: Vector2 in _curb_car_pts:
			if car_q.distance_squared_to(q) < 6.0 * 6.0:
				too_close = true
				break
		if too_close:
			continue
		added.append(q)
		var out_v := Vector3(out_n.x, 0.0, out_n.y)
		# out_v 垂直于路面，_face_outward_yaw 让 car_wreck 长轴(X)顺道路方向平行停放，侧面朝向道路
		register_loot_anchor(p, _face_outward_yaw(-out_v), "car_wreck", 78, "curb_car", -out_v)


func _roadside_spot() -> Vector3:
	if curves.is_empty():
		return Vector3.INF
	for t in 12:
		var total: float = _road_len[_road_len.size() - 1]
		var x := rng.randf() * total
		var i := clampi(_road_len.bsearch(x), 0, curves.size() - 1)
		var cv: Dictionary = curves[i]
		if cv.dirt or float(cv.w) < 6.0:
			continue
		var d: PackedVector2Array = cv.d
		if d.size() < 4:
			continue
		var j := rng.randi_range(1, d.size() - 2)
		var tg := (d[j + 1] - d[j - 1]).normalized()
		var sd := 1.0 if rng.randf() < 0.5 else -1.0
		var q := d[j] + Vector2(-tg.y, tg.x) * sd * maxf(1.0, float(cv.w) * 0.5 - WALK_W * 0.5)
		if not in_bounds_xz(q, 9.0):
			continue
		if _rg_edge_dist_ignore(_rg, q, i, cv.get("tangent_mates", PackedInt32Array())) < 7.5 or _on_bridge(q, 4.0) or in_river(q, 4.0):
			continue
		var p := Vector3(q.x, 0, q.y)
		if not _blocked(p, 2.5, false):
			return p
	return Vector3.INF


func _drop_point() -> Vector3:
	rng.seed = _map_seed(12)
	# 空投点：沿不规则战区周界内侧（距边界 14~56 米）较安全的街区生成固定候选列表，并固定取首号主空投点
	drop_points.clear()
	for min_sep: float in [72.0, 46.0, 26.0]:
		for t in 140:
			if drop_points.size() >= 6:
				break
			var p := Vector3(rng.randf_range(-HALF + 14.0, HALF - 14.0), 0.0, rng.randf_range(-HALF + 14.0, HALF - 14.0))
			var bd := border_dist(Vector2(p.x, p.z))
			if bd < 14.0 or bd > 58.0:
				continue
			var zt := zone_at(p)
			if zt in ["K", "S", "A"]:
				continue
			if min_sep > 45.0 and not (zt in ["R", "W", "F", "P", "T", "M"]):
				continue
			if _blocked(p, 4.0):
				continue
			var too_close := false
			for dp: Vector3 in drop_points:
				if p.distance_to(dp) < min_sep:
					too_close = true
					break
			if not too_close:
				for pc: Vector3 in poi_centers:
					if p.distance_to(pc) < 38.0:
						too_close = true
						break
			if not too_close:
				drop_points.append(p)
		if drop_points.size() >= 5:
			break
	if drop_points.is_empty():
		drop_points.append(_free_spot(4.0, 12.0))
	drop_points.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return atan2(a.z, a.x) < atan2(b.z, b.x))
	return drop_points[0]


# ---------- 地形图（小地图 / 大地图共用） ----------
const MAP_PX := 720
const ZONE_TINT := {"W": Color(0.33, 0.3, 0.23), "F": Color(0.4, 0.35, 0.2), "R": Color(0.36, 0.33, 0.3), "D": Color(0.27, 0.28, 0.31),
	"I": Color(0.33, 0.29, 0.24), "H": Color(0.25, 0.29, 0.31), "Y": Color(0.3, 0.27, 0.25), "M": Color(0.27, 0.31, 0.22), "P": Color(0.23, 0.32, 0.19),
	"T": Color(0.17, 0.24, 0.15), "C": Color(0.25, 0.22, 0.19), "S": Color(0.27, 0.19, 0.28), "K": Color(0.2, 0.17, 0.15), "L": Color(0.21, 0.27, 0.23),
	"A": Color(0.12, 0.2, 0.28), "B": Color(0.5, 0.45, 0.36)}
var map_tex: ImageTexture


func _img_flat_seg(img: Image, a: Vector2, b: Vector2, w: float, c: Color) -> void:
	var len := a.distance_to(b)
	if len <= 0.05:
		_img_disc(img, a, w * 0.5, c)
		return
	var d := (b - a) / len
	var nrm := Vector2(-d.y, d.x) * (w * 0.5)
	_img_poly(img, PackedVector2Array([a + nrm, b + nrm, b - nrm, a - nrm]), c)


func _img_line(img: Image, a: Vector2, b: Vector2, w: float, c: Color, step := 1.0) -> void:
	var k := MAP_PX / (HALF * 2.0)
	if w * k <= 2.5:
		var n := maxi(1, int(a.distance_to(b) / minf(step, 0.5)))
		var s := maxi(1, roundi(w * k))
		for i in n + 1:
			var p := a.lerp(b, float(i) / n)
			var q := Vector2i(int((p.x + HALF) * k) - s / 2, int((p.y + HALF) * k) - s / 2)
			img.fill_rect(Rect2i(q, Vector2i(s, s)), c)
		return
	_img_disc(img, a, w * 0.5, c)
	if a.distance_to(b) > 0.05:
		_img_flat_seg(img, a, b, w, c)
		_img_disc(img, b, w * 0.5, c)


func _img_disc(img: Image, c: Vector2, rad: float, col: Color) -> void:
	var k := MAP_PX / (HALF * 2.0)
	var cx := (c.x + HALF) * k
	var cy := (c.y + HALF) * k
	var rr := rad * k
	for y in range(maxi(0, floori(cy - rr)), mini(MAP_PX - 1, ceili(cy + rr)) + 1):
		var dy := (y + 0.5) - cy
		var hw := sqrt(maxf(0.0, rr * rr - dy * dy))
		var xa := clampi(roundi(cx - hw), 0, MAP_PX)
		var xb := clampi(roundi(cx + hw), 0, MAP_PX)
		if xb > xa:
			img.fill_rect(Rect2i(xa, y, xb - xa, 1), col)


## 凸多边形填色（世界坐标）
func _img_poly(img: Image, poly: PackedVector2Array, col: Color) -> void:
	var k := MAP_PX / (HALF * 2.0)
	var pp := PackedVector2Array()
	for q in poly:
		pp.append(Vector2((q.x + HALF) * k, (q.y + HALF) * k))
	var r := WC._poly_rect(pp)
	var m := pp.size()
	for y in range(maxi(0, int(r.position.y)), mini(MAP_PX - 1, int(r.end.y)) + 1):
		var yc := y + 0.5
		var x0 := INF
		var x1 := -INF
		for i in m:
			var a := pp[i]
			var b := pp[(i + 1) % m]
			if (a.y <= yc) != (b.y <= yc):
				var x := a.x + (yc - a.y) / (b.y - a.y) * (b.x - a.x)
				x0 = minf(x0, x)
				x1 = maxf(x1, x)
		if x1 >= x0:
			var xa := clampi(roundi(x0), 0, MAP_PX)
			var xb := clampi(roundi(x1), 0, MAP_PX)
			if xb > xa:
				img.fill_rect(Rect2i(xa, y, xb - xa, 1), col)


func _img_poly_line(img: Image, pts: PackedVector2Array, w: float, c: Color) -> void:
	if pts.is_empty():
		return
	var r := w * 0.5
	_img_disc(img, pts[0], r, c)
	for i in pts.size() - 1:
		if pts[i].distance_to(pts[i + 1]) > 0.05:
			_img_flat_seg(img, pts[i], pts[i + 1], w, c)
		_img_disc(img, pts[i + 1], r, c)


func _build_map_texture(sliced := false) -> void:
	var img := Image.create(MAP_PX, MAP_PX, false, Image.FORMAT_RGBA8)
	var k := MAP_PX / (HALF * 2.0)
	# 区块底色：2 米栅格放大，对远离道路/建筑的硬质区块做荒野过渡，并叠加地貌微理与等高线
	var n: int = layout.r_n
	var pad := int(roundf(-(layout.r_o.x + HALF) / WC.RAST))
	var m := int(HALF * 2.0 / WC.RAST)
	var bldg_rects: Array = []
	for e: Array in bldg_polys + backdrop_bldg_polys:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		bldg_rects.append(WC._poly_rect(e[0]).grow(22.0))
	for pp: Vector3 in poi_centers:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		bldg_rects.append(Rect2(pp.x - 28.0, pp.z - 28.0, 56.0, 56.0))
	var base := Image.create(m, m, false, Image.FORMAT_RGBA8)
	for y in m:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		for x in m:
			var zt := char(layout.rast[(y + pad) * n + x + pad])
			var c: Color = ZONE_TINT.get(zt, ZONE_TINT.W)
			var q := Vector2(-HALF + (x + 0.5) * WC.RAST, -HALF + (y + 0.5) * WC.RAST)
			if zt in ["D", "I", "H", "Y", "M", "C"] and not on_road(q, 24.0):
				var near_built := false
				for br: Rect2 in bldg_rects:
					if br.has_point(q):
						near_built = true
						break
				if not near_built:
					c = c.lerp(ZONE_TINT.W, 0.72 if zt != "C" else 0.45)
			var h := sin(q.x * 0.055 + q.y * 0.038) * 0.5 + cos(q.x * 0.029 - q.y * 0.062) * 0.5
			var contour := 1.0 - smoothstep(0.0, 0.08, absf(fposmod(h * 3.2, 1.0) - 0.5))
			c = c.darkened(contour * 0.045)
			base.set_pixel(x, y, c)
	base.resize(MAP_PX, MAP_PX, Image.INTERPOLATE_BILINEAR)
	img.blit_rect(base, Rect2i(0, 0, MAP_PX, MAP_PX), Vector2i.ZERO)
	# 农田垄线（顺着田块朝向）
	for fd: Dictionary in layout.fields:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		var poly: PackedVector2Array = fd.poly
		if poly.size() < 3:
			continue
		var u := Vector2(cos(fd.ang), sin(fd.ang))
		var v := Vector2(-sin(fd.ang), cos(fd.ang))
		var lo := INF
		var hi := -INF
		for q in poly:
			lo = minf(lo, q.dot(v))
			hi = maxf(hi, q.dot(v))
		var t := lo + 2.0
		while t < hi:
			var seg := _line_in_poly(poly, v * t, u)
			if seg.size() == 2 and zone_at(Vector3((seg[0].x + seg[1].x) * 0.5, 0, (seg[0].y + seg[1].y) * 0.5)) == "F":
				_img_line(img, seg[0], seg[1], 0.6, Color(0.33, 0.28, 0.16), 2.0)
			t += 4.4
	# 河流与湖泊（外岸护坡 → 自然分湾水体 → 内侧深水层次）
	for r: Dictionary in rivers:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		_img_poly_line(img, r.pts, r.w + 4.0, Color(0.22, 0.2, 0.17) if not r.dry else Color(0.33, 0.29, 0.23))
	for l: Vector3 in lakes:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		_img_poly(img, WC.lake_poly(l, 56, 2.4), Color(0.22, 0.2, 0.17))
	for r: Dictionary in rivers:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		_img_poly_line(img, r.pts, r.w, Color(0.17, 0.3, 0.37) if not r.dry else Color(0.43, 0.38, 0.30))
	for l: Vector3 in lakes:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		_img_poly(img, WC.lake_poly(l, 56, 0.0), Color(0.17, 0.3, 0.37))
	for r: Dictionary in rivers:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		if not r.dry and r.w >= 10.0:
			_img_poly_line(img, r.pts, r.w * 0.52, Color(0.14, 0.25, 0.32))
	for l: Vector3 in lakes:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		if l.z >= 10.0:
			_img_poly(img, WC.lake_poly(l, 48, -l.z * 0.36), Color(0.14, 0.25, 0.32))
	# 道路：分层绘制（土路护肩 → 土路路面 → 铺装路深色外沿 → 铺装路缘 → 支路沥青 → 主干道沥青 → 主干道分道虚线），交叉口自然融接
	for cv: Dictionary in curves:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		if cv.dirt:
			_img_poly_line(img, cv.pts, cv.w + 1.0, Color(0.32, 0.27, 0.20))
	for cv: Dictionary in curves:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		if cv.dirt:
			_img_poly_line(img, cv.pts, maxf(1.6, cv.w - 0.8), Color(0.47, 0.41, 0.31))
	for cv: Dictionary in curves:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		if not cv.dirt:
			_img_poly_line(img, cv.pts, cv.w + 1.0, Color(0.16, 0.16, 0.18))
	for cv: Dictionary in curves:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		if not cv.dirt:
			_img_poly_line(img, cv.pts, maxf(2.0, cv.w - 0.4), Color(0.52, 0.50, 0.46))
	for cv: Dictionary in curves:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		if not cv.dirt and cv.w < 11.0:
			_img_poly_line(img, cv.pts, maxf(1.5, cv.w - 2.4), Color(0.34, 0.33, 0.31))
	for cv: Dictionary in curves:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		if not cv.dirt and cv.w >= 11.0:
			_img_poly_line(img, cv.pts, maxf(1.5, cv.w - 2.4), Color(0.38, 0.37, 0.35))
	for cv: Dictionary in curves:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		if not cv.dirt and cv.w >= 11.0:
			var pts: PackedVector2Array = cv.pts
			for i in pts.size() - 1:
				var a := pts[i]
				var b := pts[i + 1]
				var seg_l := a.distance_to(b)
				if seg_l < 14.0:
					continue
				var dir := (b - a) / seg_l
				var d := 6.0
				while d + 4.0 < seg_l - 4.0:
					var p0 := a + dir * d
					var p1 := a + dir * (d + 3.2)
					if not in_wet((p0 + p1) * 0.5, 1.0):
						_img_line(img, p0, p1, 0.55, Color(0.66, 0.56, 0.32), 0.4)
					d += 8.0
	# 桥（按桥梁真实朝向画平头矩形护栏与桥面，避免斜桥出现八角形方块）
	for b: Array in bridges:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		_img_flat_seg(img, b[0], b[1], b[2] + 2.2, Color(0.11, 0.11, 0.13))
		_img_flat_seg(img, b[0], b[1], b[2] + 0.6, Color(0.58, 0.56, 0.52))
		_img_flat_seg(img, b[0], b[1], maxf(2.0, b[2] - 1.6), Color(0.41, 0.40, 0.38))
	# 铁轨
	for l: Array in rail_lines:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		_img_flat_seg(img, l[0], l[1], 3.0, Color(0.2, 0.18, 0.17))
	for l: Array in rail_lines:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		_img_line(img, l[0], l[1], 0.9, Color(0.52, 0.47, 0.42), 0.4)
	# 山脊与断崖岩带
	for p: Vector2 in ridge_pts:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		_img_disc(img, p, 2.8, Color(0.18, 0.15, 0.12))
		_img_disc(img, p + Vector2(-0.6, -0.6), 1.7, Color(0.42, 0.37, 0.3))
	# 重点遗迹院落围墙（只画院落墙段与中型掩体，过滤零散小树/石块噪点）
	for r: Rect2 in blocks:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		var ar := r.get_area()
		if ar >= 2.2 and ar <= 10.0 and (r.size.x >= 2.5 or r.size.y >= 2.5):
			img.fill_rect(Rect2i(int((r.position.x + HALF) * k), int((r.position.y + HALF) * k), maxi(2, int(r.size.x * k)), maxi(2, int(r.size.y * k))), Color(0.22, 0.21, 0.20))
	# 建筑：投影 + 轮廓描边 + 屋顶与内层女儿墙（含外围邻接城区建筑，斜放的楼按真实朝向画）
	var all_bldgs: Array = backdrop_bldg_polys + bldg_polys
	var sh_off := PackedVector2Array()
	for e: Array in all_bldgs:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		var p0: PackedVector2Array = e[0]
		sh_off.resize(p0.size())
		for i in p0.size():
			sh_off[i] = p0[i] + Vector2(1.1, 1.2)
		_img_poly(img, sh_off, Color(0.06, 0.06, 0.07))
	for e: Array in all_bldgs:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		_img_poly(img, e[0], Color(0.10, 0.10, 0.11))
	for e: Array in all_bldgs:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		_img_poly(img, WC.inset(e[0], 0.85), Color(0.58, 0.56, 0.52))
		var inner := WC.inset(e[0], 2.2)
		if inner.size() >= 3:
			_img_poly(img, inner, Color(0.51, 0.49, 0.45))
	# 不规则战区周界以外：地下竖井涂成深渊黑曜岩体与暗紫边界线；地表战区保留全幅连续地形（无战区封锁边框）
	if not is_surface_map and zone_poly.size() >= 3:
		var inv_k := 1.0 / k
		for py in MAP_PX:
			var wz := -HALF + (float(py) + 0.5) * inv_k
			for px in MAP_PX:
				var wx := -HALF + (float(px) + 0.5) * inv_k
				var sd := border_dist(Vector2(wx, wz))
				if sd < 0.0:
					if not is_surface_map:
						var n_rock := 0.06 + 0.02 * sin(wx * 0.09 + wz * 0.07)
						img.set_pixel(px, py, Color(n_rock, n_rock * 0.94, n_rock * 1.12, 1.0))
					else:
						var oc := img.get_pixel(px, py)
						var luma := oc.r * 0.3 + oc.g * 0.59 + oc.b * 0.11
						var muted := Color(lerpf(oc.r, luma, 0.45), lerpf(oc.g, luma, 0.45), lerpf(oc.b, luma, 0.40), 1.0) * 0.44
						if (px + py) % 12 < 2:
							muted = muted * 0.82
						img.set_pixel(px, py, muted)
		# 绘制清晰的不规则战区战术封控边界线（深色底衬 + 工业琥珀钢分界线）
		var zloop := zone_poly.duplicate()
		zloop.append(zone_poly[0])
		_img_poly_line(img, zloop, 3.4, Color(0.07, 0.07, 0.08))
		_img_poly_line(img, zloop, 1.35, Color(0.88, 0.68, 0.32) if is_surface_map else Color(0.62, 0.46, 0.78))
	for e in [Rect2i(0, 0, MAP_PX, 3), Rect2i(0, MAP_PX - 3, MAP_PX, 3), Rect2i(0, 0, 3, MAP_PX), Rect2i(MAP_PX - 3, 0, 3, MAP_PX)]:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		img.fill_rect(e, Color(0.05, 0.05, 0.05))
	map_tex = ImageTexture.create_from_image(img)


## 直线 o + d·t 与凸多边形的交段（两个端点；不相交返回空）
func _line_in_poly(poly: PackedVector2Array, o: Vector2, d: Vector2) -> PackedVector2Array:
	var t0 := -INF
	var t1 := INF
	var m := poly.size()
	var ccw := WC.poly_area_signed(poly) > 0.0
	for i in m:
		var p := poly[i]
		var e := poly[(i + 1) % m] - p
		var nn := Vector2(-e.y, e.x) if ccw else Vector2(e.y, -e.x)
		var num := (o - p).dot(nn)
		var den := d.dot(nn)
		if absf(den) < 1e-6:
			if num < 0.0:
				return PackedVector2Array()
			continue
		var t := -num / den
		if den > 0.0:
			t0 = maxf(t0, t)
		else:
			t1 = minf(t1, t)
	if t0 >= t1 or t0 == -INF:
		return PackedVector2Array()
	return PackedVector2Array([o + d * t0, o + d * t1])


## 地表分区贴图：R 铺装 / G 草地 / B 耕地 / A 碎石工业地坪，地面着色器按世界坐标采样后混合
const ZONE_GROUND := {"D": Color(1, 0, 0, 0.0), "R": Color(0.52, 0.30, 0, 0), "I": Color(0.15, 0, 0, 1), "H": Color(0.35, 0, 0, 0.85),
	"Y": Color(0, 0.05, 0, 1), "M": Color(0.35, 0.05, 0, 0.7), "P": Color(0, 1, 0, 0), "F": Color(0, 0.12, 1, 0), "W": Color(0, 0.14, 0, 0),
	"T": Color(0, 0.85, 0.15, 0), "C": Color(0, 0, 0.25, 0.55), "S": Color(0, 0.1, 0, 0.25), "K": Color(0, 0, 0, 0.45), "L": Color(0, 0.55, 0.2, 0),
	"A": Color(0, 0.1, 0.15, 0), "B": Color(0, 0, 0.3, 0.2)}
func _build_zone_ground() -> void:
	var zh := EXT_HALF
	var n := 220
	var step := (zh * 2.0) / float(n)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var bldg_rects: Array = []
	for e: Array in bldg_polys + backdrop_bldg_polys:
		bldg_rects.append(WC._poly_rect(e[0]).grow(14.0))
	for pp: Vector3 in poi_centers:
		bldg_rects.append(Rect2(pp.x - 24.0, pp.z - 24.0, 48.0, 48.0))
	for y in n:
		for x in n:
			var wp := Vector3(-zh + (x + 0.5) * step, 0, -zh + (y + 0.5) * step)
			var q := Vector2(wp.x, wp.z)
			var zt := zone_at(wp)
			var c: Color = ZONE_GROUND.get(zt, ZONE_GROUND.W)
			# 硬质铺装/工业碎石只紧贴道路、建筑群与据点展开；地表中心城（D）保持连续硬质街区基底
			if zt in ["I", "H", "Y", "M", "C"] and not on_road(q, 16.0):
				var near_built := false
				for r: Rect2 in bldg_rects:
					if r.has_point(q):
						near_built = true
						break
				if not near_built:
					c = c.lerp(ZONE_GROUND.W, 0.86)
			if not is_surface_map and border_dist(q) < -4.0:
				c = Color(0, 0, 0, 0)
			elif in_wet(q, 6.0):
				c = Color(0, 0.1, 0.15, 0)
			elif in_river(q, 6.0):
				c = Color(0, 0, 0, 0.2)
			img.set_pixel(x, y, c)
	img.resize(112, 112, Image.INTERPOLATE_BILINEAR)
	img.resize(256, 256, Image.INTERPOLATE_CUBIC)
	var t := ImageTexture.create_from_image(img)
	var s_img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rail_rects: Array = []
	for rp: PackedVector2Array in rail_polys:
		rail_rects.append(WC._poly_rect(rp).grow(4.2))
	var bldg_ao_list: Array = []
	var bgrid: Dictionary = {}
	for e: Array in bldg_polys + backdrop_bldg_polys:
		var pts: PackedVector2Array = e[0]
		if pts.size() < 3:
			continue
		var br: Rect2 = WC._poly_rect(pts).grow(4.6)
		var bidx: int = bldg_ao_list.size()
		bldg_ao_list.append([pts, br])
		var x0: int = floori(br.position.x / 24.0)
		var x1: int = floori(br.end.x / 24.0)
		var y0: int = floori(br.position.y / 24.0)
		var y1: int = floori(br.end.y / 24.0)
		for cy in range(y0, y1 + 1):
			for cx in range(x0, x1 + 1):
				var ck := Vector2i(cx, cy)
				if not bgrid.has(ck):
					bgrid[ck] = []
				(bgrid[ck] as Array).append(bidx)
	for y in n:
		for x in n:
			var q := Vector2(-zh + (x + 0.5) * step, -zh + (y + 0.5) * step)
			var r_sec: float = 1.0 if is_surface_map else clampf(0.5 + border_dist(q) / 24.0, 0.0, 1.0)
			var rv: float = 0.0
			if _rg != null:
				var ed: float = _rg.edge_dist(q)
				if ed < 4.5:
					rv = clampf(1.0 - maxf(ed, 0.0) / 4.5, 0.0, 1.0)
			for ri: int in rail_polys.size():
				var rr: Rect2 = rail_rects[ri]
				if rr.has_point(q):
					var rp: PackedVector2Array = rail_polys[ri]
					var rd: float = INF
					for k in rp.size() - 1:
						rd = minf(rd, WC.seg_dist(q, rp[k], rp[k + 1]))
					if rd < 3.8:
						rv = maxf(rv, clampf(1.0 - maxf(rd, 0.0) / 3.8, 0.0, 1.0))
			if in_wet(q, 2.0):
				rv = 0.0
			var bao: float = 0.0
			var cand = bgrid.get(Vector2i(floori(q.x / 24.0), floori(q.y / 24.0)))
			if cand != null:
				for bi: int in (cand as Array):
					var entry: Array = bldg_ao_list[bi]
					var br: Rect2 = entry[1]
					if br.has_point(q):
						var pts: PackedVector2Array = entry[0]
						var psz: int = pts.size()
						var bd: float = INF
						for k in psz:
							bd = minf(bd, WC.seg_dist(q, pts[k], pts[(k + 1) % psz]))
						if bd < 4.4:
							var t_ao := clampf(1.0 - bd / 4.4, 0.0, 1.0)
							bao = maxf(bao, t_ao * t_ao * (3.0 - 2.0 * t_ao))
			s_img.set_pixel(x, y, Color(r_sec, rv, bao, 1.0))
	s_img.resize(160, 160, Image.INTERPOLATE_BILINEAR)
	s_img.resize(256, 256, Image.INTERPOLATE_CUBIC)
	var s_tex := ImageTexture.create_from_image(s_img)
	var gm: ShaderMaterial = A.ground()
	gm.set_shader_parameter("zone_tex", t)
	gm.set_shader_parameter("sector_tex", s_tex)
	gm.set_shader_parameter("zone_half", zh)
	gm.set_shader_parameter("zone_on", 1.0)
	gm.set_shader_parameter("sector_on", 1.0 if is_surface_map else -1.0)


# ---------- 道路（全部折线，合并成少数几个网格） ----------
## 把一组条带加进 SurfaceTool（pts 中心线，w 宽，off 横向偏移，y 高度）
func _st_strip(st: SurfaceTool, pts: PackedVector2Array, w: float, off: float, y: float, thick := 0.0) -> void:
	if pts.size() < 2:
		return
	var L := PackedVector3Array()
	var R := PackedVector3Array()
	var N := PackedVector2Array()
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var nn := Vector2(-t.y, t.x)
		var c := pts[i] + nn * off
		L.append(Vector3(c.x + nn.x * w * 0.5, y, c.y + nn.y * w * 0.5))
		R.append(Vector3(c.x - nn.x * w * 0.5, y, c.y - nn.y * w * 0.5))
		N.append(nn)
	for i in pts.size() - 1:
		for v in [L[i], R[i], L[i + 1], R[i], R[i + 1], L[i + 1]]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x, v.z) * 0.1)
			st.add_vertex(v)
		if thick > 0.001:
			var yb := y - thick
			var nl := Vector3(N[i].x, 0.0, N[i].y)
			var lb0 := Vector3(L[i].x, yb, L[i].z)
			var lb1 := Vector3(L[i + 1].x, yb, L[i + 1].z)
			for v in [L[i], lb0, L[i + 1], lb0, lb1, L[i + 1]]:
				st.set_normal(nl)
				st.set_uv(Vector2(v.x, v.z) * 0.1)
				st.add_vertex(v)
			var rb0 := Vector3(R[i].x, yb, R[i].z)
			var rb1 := Vector3(R[i + 1].x, yb, R[i + 1].z)
			for v in [R[i], R[i + 1], rb0, rb0, R[i + 1], rb1]:
				st.set_normal(-nl)
				st.set_uv(Vector2(v.x, v.z) * 0.1)
				st.add_vertex(v)


func _st_commit(st: SurfaceTool, m: Material, count: int) -> void:
	if count == 0:
		return
	st.index()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)


static var _feather_terrain_shader: Shader
func _terrain_feather_mat(c: Color, tex_scale := 0.30, rough_v := 0.90, spec_v := 0.14, priority := -8) -> ShaderMaterial:
	if _feather_terrain_shader == null:
		_feather_terrain_shader = Shader.new()
		_feather_terrain_shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 tint : source_color = vec4(0.32, 0.28, 0.22, 1.0);
uniform float tex_scale = 0.30;
uniform float rough_v = 0.90;
uniform float spec_v = 0.14;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 uv = wp.xz * tex_scale;
	vec3 tex_a = texture(albedo_tex, uv).rgb;
	vec3 tex_n = texture(normal_tex, uv).rgb;
	float macro_n = texture(noise_tex, wp.xz * 0.055).r;
	float micro_n = texture(noise_tex, wp.xz * 0.28).r;
	float n_mod = macro_n * 0.68 + micro_n * 0.32;
	ALBEDO = tint.rgb * mix(0.76, 1.24, tex_a.r) * (0.86 + 0.28 * macro_n);
	NORMAL_MAP = tex_n;
	NORMAL_MAP_DEPTH = 0.85;
	ROUGHNESS = clamp(rough_v + (tex_a.r - 0.5) * 0.14, 0.35, 0.98);
	SPECULAR = spec_v;
	float a_in = COLOR.a;
	float edge = smoothstep(0.02, 0.92, clamp(a_in + (n_mod - 0.5) * 0.62 * sin(a_in * 3.14159), 0.0, 1.0));
	float patch_mod = mix(0.68 + 0.32 * n_mod, 1.0, step(0.98, tint.a));
	ALPHA = edge * tint.a * patch_mod;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _feather_terrain_shader
	m.render_priority = priority
	m.set_shader_parameter("tint", c)
	m.set_shader_parameter("tex_scale", tex_scale)
	m.set_shader_parameter("rough_v", rough_v)
	m.set_shader_parameter("spec_v", spec_v)
	m.set_shader_parameter("albedo_tex", A.world_tex("ground_gravel_a.png"))
	m.set_shader_parameter("normal_tex", A.world_tex("ground_gravel_n.png"))
	m.set_shader_parameter("noise_tex", A.noise_tex("grime_raw", 512))
	m.set_meta("no_outline", true)
	return m


## 折线 Chaikin 圆角细分，保持首尾端点不变，消除河道/土路刚性折线拐角
func _smooth_pts(pts: PackedVector2Array, passes := 2) -> PackedVector2Array:
	if pts.size() < 3:
		return pts.duplicate()
	var cur := pts.duplicate()
	for _p in passes:
		var nxt := PackedVector2Array()
		nxt.append(cur[0])
		for i in cur.size() - 1:
			var a := cur[i]
			var b := cur[i + 1]
			nxt.append(a.lerp(b, 0.25))
			nxt.append(a.lerp(b, 0.75))
		nxt.append(cur[cur.size() - 1])
		cur = nxt
	return cur


func _append_bezier_span(out: PackedVector2Array, p0: Vector2, p3: Vector2, chord: float, u_dir: Vector2, t0: Vector2, t1: Vector2, fine_step: float, gentle_step: float, max_deg: float, sag_tol := 0.0020) -> void:
	if chord < 0.06:
		out.append(p3)
		return
	var a0 := acos(clampf(u_dir.dot(t0), -1.0, 1.0))
	var a1 := acos(clampf(u_dir.dot(t1), -1.0, 1.0))
	var a01 := acos(clampf(t0.dot(t1), -1.0, 1.0))
	var span_ang := maxf(a01, a0 + a1)
	if span_ang < deg_to_rad(0.25) and chord * span_ang < 0.004:
		out.append(p3)
		return
	var dot01 := maxf(0.5, t0.dot(t1))
	var h := (chord / 3.0) * minf(1.15, 2.0 / (1.0 + dot01))
	var p1 := p0 + t0 * h
	var p2 := p3 - t1 * h
	var m_ang := ceili(span_ang / deg_to_rad(max_deg))
	var m_sag := ceili(sqrt(maxf(0.0, chord * span_ang) / (8.0 * sag_tol)))
	var m_len := ceili(chord / (fine_step if span_ang >= deg_to_rad(2.5) else gentle_step))
	var m_seg := clampi(maxi(2, maxi(m_ang, maxi(m_sag, m_len))), 2, 24)
	for k in range(1, m_seg + 1):
		var u := float(k) / float(m_seg)
		var v := 1.0 - u
		out.append((v * v * v) * p0 + (3.0 * v * v * u) * p1 + (3.0 * v * u * u) * p2 + (u * u * u) * p3)


## 自适应 C1 三次贝塞尔样条细分：直道零细分保直防鼓包，缓弯/急弯按弦高与转角自适应加密消除实机放大折线痕迹
func _bezier_refine_polyline(pts: PackedVector2Array, pin_t0 := Vector2.ZERO, pin_t1 := Vector2.ZERO, fine_step := 0.24, gentle_step := 0.38, max_deg := 0.65, sag_tol := 0.0020, near_rect := Rect2()) -> PackedVector2Array:
	if pts.size() < 2:
		return pts.duplicate()
	var clean := PackedVector2Array([pts[0]])
	for i in range(1, pts.size()):
		if clean[clean.size() - 1].distance_to(pts[i]) >= 0.03:
			clean.append(pts[i])
	if clean.size() < 2:
		return pts.duplicate()
	var closed := pts.size() > 8 and pts[0].distance_to(pts[pts.size() - 1]) < 0.5 and pin_t0 == Vector2.ZERO and pin_t1 == Vector2.ZERO
	if closed:
		if clean.size() >= 3 and clean[0].distance_to(clean[clean.size() - 1]) < 0.06:
			clean.remove_at(clean.size() - 1)
		var m := clean.size()
		if m < 3:
			return pts.duplicate()
		var lens := PackedFloat32Array()
		var us: Array[Vector2] = []
		lens.resize(m)
		us.resize(m)
		for i in m:
			var seg_v := clean[(i + 1) % m] - clean[i]
			var l := seg_v.length()
			lens[i] = l
			us[i] = seg_v / maxf(l, 1e-5)
		var v_ang := PackedFloat32Array()
		v_ang.resize(m)
		for i in m:
			v_ang[i] = acos(clampf(us[(i - 1 + m) % m].dot(us[i]), -1.0, 1.0))
		var ts: Array[Vector2] = []
		ts.resize(m)
		for i in m:
			var ip := (i - 1 + m) % m
			var in_st := (v_ang[ip] < deg_to_rad(0.20) and lens[ip] > 1.5)
			var out_st := (v_ang[(i + 1) % m] < deg_to_rad(0.20) and lens[i] > 1.5)
			if v_ang[i] < deg_to_rad(0.15):
				ts[i] = us[i]
			elif in_st and not out_st and lens[ip] > 1.6 * lens[i]:
				ts[i] = us[ip]
			elif out_st and not in_st and lens[i] > 1.6 * lens[ip]:
				ts[i] = us[i]
			else:
				var tv := lens[i] * us[ip] + lens[ip] * us[i]
				ts[i] = tv.normalized() if tv.length_squared() > 1e-8 else us[i]
		var out := PackedVector2Array([clean[0]])
		for i in m:
			var pa := clean[i]
			var pb := clean[(i + 1) % m]
			var far := near_rect.has_area() and not near_rect.has_point((pa + pb) * 0.5)
			if far:
				_append_bezier_span(out, pa, pb, lens[i], us[i], ts[i], ts[(i + 1) % m], fine_step * 2.5, gentle_step * 2.5, max_deg * 2.5, sag_tol * 4.0)
			else:
				_append_bezier_span(out, pa, pb, lens[i], us[i], ts[i], ts[(i + 1) % m], fine_step, gentle_step, max_deg, sag_tol)
		if out.size() >= 2 and out[out.size() - 1].distance_to(out[0]) > 0.02:
			out.append(out[0])
		elif not out.is_empty():
			out[out.size() - 1] = out[0]
		return out
	var n := clean.size()
	if n == 2:
		if pin_t0 == Vector2.ZERO and pin_t1 == Vector2.ZERO:
			return clean
		var d01 := clean[1] - clean[0]
		var l01 := d01.length()
		if l01 < 0.06:
			return clean
		var u01 := d01 / l01
		var t0 := pin_t0.normalized() if pin_t0 != Vector2.ZERO else u01
		var t1 := pin_t1.normalized() if pin_t1 != Vector2.ZERO else u01
		var out2 := PackedVector2Array([clean[0]])
		var far2 := near_rect.has_area() and not near_rect.has_point((clean[0] + clean[1]) * 0.5)
		if far2:
			_append_bezier_span(out2, clean[0], clean[1], l01, u01, t0, t1, fine_step * 2.5, gentle_step * 2.5, max_deg * 2.5, sag_tol * 4.0)
		else:
			_append_bezier_span(out2, clean[0], clean[1], l01, u01, t0, t1, fine_step, gentle_step, max_deg, sag_tol)
		return out2
	var lens := PackedFloat32Array()
	var us: Array[Vector2] = []
	lens.resize(n - 1)
	us.resize(n - 1)
	for i in n - 1:
		var seg_v := clean[i + 1] - clean[i]
		var l := seg_v.length()
		lens[i] = l
		us[i] = seg_v / maxf(l, 1e-5)
	var v_ang := PackedFloat32Array()
	v_ang.resize(n)
	for i in range(1, n - 1):
		v_ang[i] = acos(clampf(us[i - 1].dot(us[i]), -1.0, 1.0))
	var ts: Array[Vector2] = []
	ts.resize(n)
	for i in range(1, n - 1):
		var in_straight := (i >= 2 and v_ang[i - 1] < deg_to_rad(0.20)) or (i == 1 and lens[0] > 4.2 and v_ang[1] >= deg_to_rad(0.45))
		var out_straight := (i <= n - 3 and v_ang[i + 1] < deg_to_rad(0.20)) or (i == n - 2 and lens[n - 2] > 4.2 and v_ang[n - 2] >= deg_to_rad(0.45))
		if v_ang[i] < deg_to_rad(0.15):
			ts[i] = us[i]
		elif in_straight and not out_straight and lens[i - 1] > 1.6 * lens[i]:
			ts[i] = us[i - 1]
		elif out_straight and not in_straight and lens[i] > 1.6 * lens[i - 1]:
			ts[i] = us[i]
		else:
			var tv := lens[i] * us[i - 1] + lens[i - 1] * us[i]
			ts[i] = tv.normalized() if tv.length_squared() > 1e-8 else us[i]
	if pin_t0 != Vector2.ZERO:
		ts[0] = pin_t0.normalized()
	elif v_ang[1] < deg_to_rad(0.20):
		ts[0] = us[0]
	else:
		var tv0 := 2.0 * us[0] - ts[1]
		ts[0] = tv0.normalized() if (tv0.length_squared() > 1e-8 and tv0.normalized().dot(us[0]) >= us[0].dot(ts[1]) - 0.02) else us[0]
	if pin_t1 != Vector2.ZERO:
		ts[n - 1] = pin_t1.normalized()
	elif v_ang[n - 2] < deg_to_rad(0.20):
		ts[n - 1] = us[n - 2]
	else:
		var tv1 := 2.0 * us[n - 2] - ts[n - 2]
		ts[n - 1] = tv1.normalized() if (tv1.length_squared() > 1e-8 and tv1.normalized().dot(us[n - 2]) >= us[n - 2].dot(ts[n - 2]) - 0.02) else us[n - 2]
	var out := PackedVector2Array([clean[0]])
	for i in n - 1:
		var pa := clean[i]
		var pb := clean[i + 1]
		var far := near_rect.has_area() and not near_rect.has_point((pa + pb) * 0.5)
		if far:
			_append_bezier_span(out, pa, pb, lens[i], us[i], ts[i], ts[i + 1], fine_step * 2.5, gentle_step * 2.5, max_deg * 2.5, sag_tol * 4.0)
		else:
			_append_bezier_span(out, pa, pb, lens[i], us[i], ts[i], ts[i + 1], fine_step, gentle_step, max_deg, sag_tol)
	return out


func _bezier_refine_road(cv: Dictionary) -> PackedVector2Array:
	var pts: PackedVector2Array = cv.pts
	var mate_ends: Array = cv.get("mate_ends", [false, false])
	var mate_dirs: Array = cv.get("mate_dirs", [Vector2.ZERO, Vector2.ZERO])
	var pin_t0 := -(mate_dirs[0] as Vector2) if bool(mate_ends[0]) else Vector2.ZERO
	var pin_t1 := (mate_dirs[1] as Vector2) if bool(mate_ends[1]) else Vector2.ZERO
	var near_r := Rect2(-215.0, -215.0, 430.0, 430.0)
	if bool(cv.dirt):
		return _bezier_refine_polyline(pts, Vector2.ZERO, Vector2.ZERO, 0.55, 0.90, 1.4, 0.0030, near_r)
	return _bezier_refine_polyline(pts, pin_t0, pin_t1, 0.36, 0.65, 1.00, 0.0018, near_r)


func _st_tri_alpha(st: SurfaceTool, a: Vector3, aa: float, b: Vector3, ab: float, c: Vector3, ac: float) -> void:
	if (b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x) < 0.0:
		var tmp := b; b = c; c = tmp
		var ta := ab; ab = ac; ac = ta
	var pts := [a, b, c]
	var alps := [aa, ab, ac]
	for idx in 3:
		var v: Vector3 = pts[idx]
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(v.x, v.z) * 0.1)
		st.set_color(Color(1.0, 1.0, 1.0, float(alps[idx])))
		st.add_vertex(v)


func _poly_seg_grid(poly: PackedVector2Array, cell := 16.0) -> Dictionary:
	var grid := {}
	var m := poly.size()
	for i in m:
		var a := poly[i]
		var b := poly[(i + 1) % m]
		var seg := [a, b, minf(a.x, b.x), maxf(a.x, b.x), minf(a.y, b.y), maxf(a.y, b.y)]
		var x0 := int(floor(float(seg[2]) / cell)) - 1
		var x1 := int(floor(float(seg[3]) / cell)) + 1
		var y0 := int(floor(float(seg[4]) / cell)) - 1
		var y1 := int(floor(float(seg[5]) / cell)) + 1
		for gx in range(x0, x1 + 1):
			for gy in range(y0, y1 + 1):
				var key := Vector2i(gx, gy)
				if not grid.has(key):
					grid[key] = []
				(grid[key] as Array).append(seg)
	return grid


func _segs_dist_grid(p: Vector2, grid: Dictionary, fallback: float, cell := 16.0) -> float:
	var key := Vector2i(int(floor(p.x / cell)), int(floor(p.y / cell)))
	var bucket = grid.get(key, null)
	if bucket == null:
		return fallback
	var best := fallback
	for s: Array in bucket:
		if p.x < float(s[2]) - fallback or p.x > float(s[3]) + fallback or p.y < float(s[4]) - fallback or p.y > float(s[5]) + fallback:
			continue
		var d := WC.seg_dist(p, s[0], s[1])
		if d < best:
			best = d
	return best


func _slice_rect_poly(pr: Rect2) -> PackedVector2Array:
	return PackedVector2Array([pr.position, Vector2(pr.end.x, pr.position.y), pr.end, Vector2(pr.position.x, pr.end.y)])


func _subtract_holes_linear(piece: PackedVector2Array, holes: Array, depth := 0) -> Array:
	if holes.is_empty() or piece.size() < 3:
		return [piece] if piece.size() >= 3 else []
	var pr: Rect2 = WC._poly_rect(piece)
	var rel: Array = []
	for h: PackedVector2Array in holes:
		if pr.intersects(WC._poly_rect(h)):
			rel.append(h)
	if rel.is_empty():
		return [piece]
	# Try subtracting relevant holes directly; if none leave a hole ring we are done in 1 pass
	var cur_pieces: Array = [piece]
	var trapped: Array = []
	for h: PackedVector2Array in rel:
		var nxt: Array = []
		var any_trapped := false
		for cp: PackedVector2Array in cur_pieces:
			if not WC._poly_rect(cp).intersects(WC._poly_rect(h)):
				nxt.append(cp)
				continue
			var clipped := Geometry2D.clip_polygons(cp, h)
			var out_subs := _outers(clipped)
			if out_subs.size() < clipped.size():
				nxt.append(cp)
				any_trapped = true
			else:
				nxt.append_array(out_subs)
		cur_pieces = nxt
		if any_trapped:
			trapped.append(h)
	if trapped.is_empty() or depth >= 4:
		return cur_pieces
	# Split along hole centers on one axis so holes become open bays in O(K) slabs
	var horiz := (depth % 2) == 1
	var cuts := PackedFloat32Array()
	for h: PackedVector2Array in trapped:
		var hr: Rect2 = WC._poly_rect(h)
		cuts.append((hr.position.y + hr.size.y * 0.5) if horiz else (hr.position.x + hr.size.x * 0.5))
	cuts.sort()
	var filtered_cuts := PackedFloat32Array()
	var lo := (pr.position.y if horiz else pr.position.x)
	var hi := (pr.end.y if horiz else pr.end.x)
	for cv: float in cuts:
		if cv > lo + 0.15 and cv < hi - 0.15:
			if filtered_cuts.is_empty() or cv - filtered_cuts[filtered_cuts.size() - 1] > 0.25:
				filtered_cuts.append(cv)
	if filtered_cuts.is_empty():
		return cur_pieces
	var edges := PackedFloat32Array([lo - 2.0])
	edges.append_array(filtered_cuts)
	edges.append(hi + 2.0)
	var final_out: Array = []
	for cp: PackedVector2Array in cur_pieces:
		var cpr: Rect2 = WC._poly_rect(cp)
		var still_trapped := false
		for h: PackedVector2Array in trapped:
			if cpr.intersects(WC._poly_rect(h)):
				still_trapped = true
				break
		if not still_trapped:
			final_out.append(cp)
			continue
		for si in edges.size() - 1:
			var a0 := edges[si]
			var a1 := edges[si + 1]
			var slab_r := Rect2(cpr.position.x - 2.0, a0, cpr.size.x + 4.0, a1 - a0) if horiz else Rect2(a0, cpr.position.y - 2.0, a1 - a0, cpr.size.y + 4.0)
			if not cpr.intersects(slab_r):
				continue
			for sub: PackedVector2Array in _outers(Geometry2D.intersect_polygons(cp, _slice_rect_poly(slab_r))):
				final_out.append_array(_subtract_holes_linear(sub, trapped, depth + 1))
	return final_out


func _st_strip_soft(st: SurfaceTool, pts: PackedVector2Array, half_w: float, feather_w: float, off: float, y: float) -> int:
	if pts.size() < 2:
		return 0
	var fw := clampf(feather_w, 0.05, half_w * 0.92)
	var hw_i := maxf(0.02, half_w - fw)
	var O_L := PackedVector3Array()
	var I_L := PackedVector3Array()
	var I_R := PackedVector3Array()
	var O_R := PackedVector3Array()
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var nn := Vector2(-t.y, t.x)
		var c := pts[i] + nn * off
		O_L.append(Vector3(c.x + nn.x * half_w, y, c.y + nn.y * half_w))
		I_L.append(Vector3(c.x + nn.x * hw_i, y, c.y + nn.y * hw_i))
		I_R.append(Vector3(c.x - nn.x * hw_i, y, c.y - nn.y * hw_i))
		O_R.append(Vector3(c.x - nn.x * half_w, y, c.y - nn.y * half_w))
	for i in pts.size() - 1:
		var al := 0.0 if (i == 0) else 1.0
		var ar := 0.0 if (i + 1 == pts.size() - 1) else 1.0
		_st_tri_alpha(st, O_L[i], 0.0, I_L[i], al, O_L[i + 1], 0.0)
		_st_tri_alpha(st, I_L[i], al, I_L[i + 1], ar, O_L[i + 1], 0.0)
		_st_tri_alpha(st, I_L[i], al, I_R[i], al, I_L[i + 1], ar)
		_st_tri_alpha(st, I_R[i], al, I_R[i + 1], ar, I_L[i + 1], ar)
		_st_tri_alpha(st, I_R[i], al, O_R[i], 0.0, I_R[i + 1], ar)
		_st_tri_alpha(st, O_R[i], 0.0, O_R[i + 1], 0.0, I_R[i + 1], ar)
	return 1


func _dice_large_poly(poly: PackedVector2Array, max_verts := 180, step := 72.0, axis_pass := 0) -> Array:
	if poly.size() < 3:
		return []
	if poly.size() <= max_verts or axis_pass >= 2:
		return [poly]
	var pr: Rect2 = WC._poly_rect(poly)
	var horiz := (pr.size.y >= pr.size.x) if axis_pass == 0 else (pr.size.x > pr.size.y)
	var span := pr.size.y if horiz else pr.size.x
	var n_slabs := maxi(2, ceili(maxf(span / step, float(poly.size()) / float(max_verts))))
	if span < 12.0 or n_slabs <= 1:
		return [poly]
	var s_len := span / float(n_slabs)
	var lo := pr.position.y if horiz else pr.position.x
	var out: Array = []
	for si in n_slabs:
		var a0 := (lo - 1.0) if si == 0 else (lo + float(si) * s_len)
		var a1 := (lo + span + 1.0) if si == n_slabs - 1 else (lo + float(si + 1) * s_len)
		var slab_r := Rect2(pr.position.x - 2.0, a0, pr.size.x + 4.0, a1 - a0) if horiz else Rect2(a0, pr.position.y - 2.0, a1 - a0, pr.size.y + 4.0)
		for sub: PackedVector2Array in _outers(Geometry2D.intersect_polygons(poly, _slice_rect_poly(slab_r))):
			if sub.size() > max_verts and axis_pass == 0:
				out.append_array(_dice_large_poly(sub, max_verts, step, 1))
			elif sub.size() >= 3:
				out.append(sub)
	return out


func _emit_soft_polys(st: SurfaceTool, polys: Array, feather_w: float, y: float) -> int:
	var count := 0
	for poly: PackedVector2Array in polys:
		if poly.size() < 3:
			continue
		var fw := maxf(feather_w, 0.1)
		var grid := _poly_seg_grid(poly, maxf(14.0, fw * 4.0))
		var cell := maxf(14.0, fw * 4.0)
		var inners := _outers(Geometry2D.offset_polygon(poly, -fw, Geometry2D.JOIN_ROUND))
		if inners.is_empty():
			fw = feather_w * 0.42
			inners = _outers(Geometry2D.offset_polygon(poly, -fw, Geometry2D.JOIN_ROUND))
		if inners.is_empty():
			for fp: PackedVector2Array in _dice_large_poly(poly):
				var idx_f := Geometry2D.triangulate_polygon(fp)
				for k in range(0, idx_f.size(), 3):
					var p0 := fp[idx_f[k]]
					var p1 := fp[idx_f[k + 1]]
					var p2 := fp[idx_f[k + 2]]
					_st_tri_alpha(st, Vector3(p0.x, y, p0.y), clampf(_segs_dist_grid(p0, grid, fw, cell) / maxf(fw, 0.12), 0.12, 0.9),
						Vector3(p1.x, y, p1.y), clampf(_segs_dist_grid(p1, grid, fw, cell) / maxf(fw, 0.12), 0.12, 0.9),
						Vector3(p2.x, y, p2.y), clampf(_segs_dist_grid(p2, grid, fw, cell) / maxf(fw, 0.12), 0.12, 0.9))
				if not idx_f.is_empty():
					count += 1
			continue
		for inner_raw: PackedVector2Array in inners:
			for inner: PackedVector2Array in _dice_large_poly(inner_raw):
				var idx_c := Geometry2D.triangulate_polygon(inner)
				for k in range(0, idx_c.size(), 3):
					var ca := inner[idx_c[k]]
					var cb := inner[idx_c[k + 1]]
					var cc := inner[idx_c[k + 2]]
					_st_tri_alpha(st, Vector3(ca.x, y, ca.y), 1.0, Vector3(cb.x, y, cb.y), 1.0, Vector3(cc.x, y, cc.y), 1.0)
				if not idx_c.is_empty():
					count += 1
		for skirt_raw: PackedVector2Array in _subtract_holes_linear(poly, inners):
			for skirt: PackedVector2Array in _dice_large_poly(skirt_raw):
				var idx_s := Geometry2D.triangulate_polygon(skirt)
				for k in range(0, idx_s.size(), 3):
					var sa := skirt[idx_s[k]]
					var sb := skirt[idx_s[k + 1]]
					var sc := skirt[idx_s[k + 2]]
					_st_tri_alpha(st, Vector3(sa.x, y, sa.y), clampf(_segs_dist_grid(sa, grid, fw, cell) / fw, 0.0, 1.0),
						Vector3(sb.x, y, sb.y), clampf(_segs_dist_grid(sb, grid, fw, cell) / fw, 0.0, 1.0),
						Vector3(sc.x, y, sc.y), clampf(_segs_dist_grid(sc, grid, fw, cell) / fw, 0.0, 1.0))
				if not idx_s.is_empty():
					count += 1
	return count


## 水平三角形（顶面）：统一成从上往下看的正面朝向
func _st_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	if (b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x) < 0.0:
		var tmp := b
		b = c
		c = tmp
	for v in [a, b, c]:
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(v.x, v.z) * 0.1)
		st.add_vertex(v)


## 断头路的圆头：在折线两端（caps[0] 起点 / caps[1] 终点）各补一个半圆
func _st_caps(st: SurfaceTool, d: PackedVector2Array, r: float, y: float, caps: Array) -> void:
	if d.size() < 2:
		return
	for e in 2:
		if not bool(caps[e]):
			continue
		var p: Vector2 = d[0] if e == 0 else d[d.size() - 1]
		var q: Vector2 = d[1] if e == 0 else d[d.size() - 2]
		var t := (p - q).normalized()
		var nn := Vector2(-t.y, t.x)
		var seg := 24
		var prev := p + nn * r
		for k in range(1, seg + 1):
			var a := PI * k / seg
			var cur := p + (nn * cos(a) + t * sin(a)) * r
			_st_tri(st, Vector3(p.x, y, p.y), Vector3(prev.x, y, prev.y), Vector3(cur.x, y, cur.y))
			prev = cur


# ---------- 人行道 / 路沿石 ----------
## 人行道 = 每条铺装路外缘往里 WALK_W 米的带子，减去所有道路的车道（铺装路：路宽减人行道；土路：全宽）与铁轨。
## 这样两条路相交时，彼此的人行道在路口被对方的车道切开、转角处自然连成 L 形；断头路的人行道绕圆头一圈。
## 折线按 WALK_CHUNK 个点分段（段间重叠两个点，弯道外侧不留楔形缝），每段用 Clipper（Geometry2D）做偏移与相减。
const WALK_W := 1.25          ## 人行道宽（含路沿石）
const CURB_W := 0.24          ## 路沿石宽（人行道靠车道一侧）
const WALK_CHUNK := 18
const _CUT_CELL := 24.0


func _prepare_chunk_poly(d: PackedVector2Array, wrap_len := 10.5) -> PackedVector2Array:
	if d.size() > 8 and d[0].distance_to(d[d.size() - 1]) < 1.0 and WC._poly_len(d) > wrap_len + 4.0:
		var work := d.duplicate()
		var acc := 0.0
		for i in range(1, d.size()):
			acc += d[i - 1].distance_to(d[i])
			work.append(d[i])
			if acc >= wrap_len and i >= 2:
				break
		return work
	return d


func _chunk_ranges(d: PackedVector2Array, chunk_len := 64.0, overlap_len := 10.5, max_pts := 160) -> Array:
	var n := d.size()
	if n <= 2:
		return [[0, n]]
	var s_arr := WC._poly_s_arr(d)
	var total := s_arr[n - 1]
	if n <= max_pts and total <= chunk_len + overlap_len:
		return [[0, n]]
	var out: Array = []
	var s := 0
	while s < n - 1:
		var e := s + 2
		while e < n and (e - s) < max_pts and (s_arr[e - 1] - s_arr[s]) < chunk_len:
			e += 1
		if e >= n or (total - s_arr[e - 1]) < overlap_len + 4.0:
			out.append([s, n])
			break
		out.append([s, e])
		var target_s := maxf(s_arr[s] + 1.0, s_arr[e - 1] - overlap_len)
		var ns := e - 2
		while ns > s + 1 and s_arr[ns] > target_s:
			ns -= 1
		s = maxi(s + 1, ns)
	return out


func _chunks(d: PackedVector2Array) -> Array:
	var work := _prepare_chunk_poly(d, 10.5)
	var out: Array = []
	for rg: Array in _chunk_ranges(work, 64.0, 10.5, 160):
		out.append(work.slice(int(rg[0]), int(rg[1])))
	return out


## 折线两端各顺延 e 米（车道切口比人行道段略长，相减后不留共边的细缝）
func _ext_line(d: PackedVector2Array, e: float) -> PackedVector2Array:
	var out := d.duplicate()
	var n := out.size()
	if n < 2:
		return out
	out[0] = d[0] + (d[0] - d[1]).normalized() * e
	out[n - 1] = d[n - 1] + (d[n - 1] - d[n - 2]).normalized() * e
	return out


## 折线向两侧各偏移 r 的条带（32 倍局部缩放：将 Clipper 圆角容差压低至 0.0078m，彻底消除弯道与拐角外扩折线），只取外轮廓
func _offset_line(d: PackedVector2Array, r: float, end_type := Geometry2D.END_BUTT, scale := 16.0) -> Array:
	if d.size() < 2 or r <= 0.05:
		return []
	var s := maxf(1.0, scale)
	var inv_s := 1.0 / s
	var ref := d[0]
	var sd := PackedVector2Array()
	sd.resize(d.size())
	for i in d.size():
		sd[i] = (d[i] - ref) * s
	var out: Array = []
	for poly: PackedVector2Array in _outers(Geometry2D.offset_polyline(sd, r * s, Geometry2D.JOIN_ROUND, end_type)):
		var up := PackedVector2Array()
		up.resize(poly.size())
		for i in poly.size():
			up[i] = poly[i] * inv_s + ref
		if WC.poly_area_signed(up) < 0.0:
			up.reverse()
		out.append(up)
	return out


## Clipper 结果里去掉洞（仅当环面积符号与外环相反且在面积更大的外环内时才是真正的洞，防止相邻同向外轮廓在共享顶点处被误删）
func _outers(res: Array) -> Array:
	if res.size() <= 1:
		if res.size() == 1 and (res[0] as PackedVector2Array).size() >= 3:
			return res
		return []
	var areas := PackedFloat32Array()
	areas.resize(res.size())
	for i in res.size():
		var p: PackedVector2Array = res[i]
		areas[i] = WC.poly_area_signed(p) if p.size() >= 3 else 0.0
	var out: Array = []
	for i in res.size():
		var pi: PackedVector2Array = res[i]
		var ai := areas[i]
		if pi.size() < 3 or absf(ai) < 1e-4:
			continue
		var hole := false
		for j in res.size():
			if j == i:
				continue
			var aj := areas[j]
			if ai * aj < 0.0 and absf(ai) < absf(aj):
				var pj: PackedVector2Array = res[j]
				if Geometry2D.is_point_in_polygon(pi[0], pj) or Geometry2D.is_point_in_polygon(pi[pi.size() / 2], pj):
					hole = true
					break
		if not hole:
			out.append(pi)
	return out


## 断头路外的半圆环（内半径 r0、外半径 r1），朝 t 方向
func _half_ring(p: Vector2, t: Vector2, r0: float, r1: float, seg := 48) -> PackedVector2Array:
	var nn := Vector2(-t.y, t.x)
	var poly := PackedVector2Array()
	for k in seg + 1:
		var a := PI * k / seg
		poly.append(p + (nn * cos(a) + t * sin(a)) * r1)
	for k in range(seg, -1, -1):
		var a := PI * k / seg
		poly.append(p + (nn * cos(a) + t * sin(a)) * r0)
	return poly


func _circle_poly(c: Vector2, r: float, seg := 80) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in seg:
		var a := TAU * i / seg
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


## 把一组可能相交的多边形求并，消除同层重叠面的深度闪烁
func _merge_polys(polys: Array) -> Array:
	var acc: Array = []
	for p: PackedVector2Array in polys:
		if p.size() >= 3:
			acc.append(p)
	var changed := true
	while changed:
		changed = false
		for i in acc.size():
			for j in range(i + 1, acc.size()):
				if not WC._poly_rect(acc[i]).intersects(WC._poly_rect(acc[j])):
					continue
				var m := _outers(Geometry2D.merge_polygons(acc[i], acc[j]))
				if m.size() == 1:
					acc[i] = m[0]
					acc.remove_at(j)
					changed = true
					break
			if changed:
				break
	return acc


func _shift_line(pts: PackedVector2Array, off: float) -> PackedVector2Array:
	if pts.size() < 2 or absf(off) < 1e-4:
		return pts
	var n := pts.size()
	var closed := n > 8 and pts[0].distance_to(pts[n - 1]) < 0.15
	var out := PackedVector2Array()
	out.resize(n)
	for i in n:
		var t := Vector2.ZERO
		if i == 0:
			t = ((pts[1] - pts[0]).normalized() + (pts[n - 1] - pts[n - 2]).normalized()).normalized() if closed else (pts[1] - pts[0]).normalized()
		elif i == n - 1:
			t = ((pts[1] - pts[0]).normalized() + (pts[n - 1] - pts[n - 2]).normalized()).normalized() if closed else (pts[n - 1] - pts[n - 2]).normalized()
		else:
			var v0 := pts[i] - pts[i - 1]
			var v1 := pts[i + 1] - pts[i]
			var l0 := v0.length()
			var l1 := v1.length()
			if l0 > 1e-5 and l1 > 1e-5:
				t = (l1 * (v0 / l0) + l0 * (v1 / l1)).normalized()
			elif l1 > 1e-5:
				t = v1 / l1
			elif l0 > 1e-5:
				t = v0 / l0
		if t.length_squared() < 1e-8:
			t = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		out[i] = pts[i] + Vector2(-t.y, t.x) * off
	return out


func _cap_polys(d: PackedVector2Array, r: float, caps: Array) -> Array:
	return _cap_polys_ends(d, r, r, caps)


func _cap_polys_ends(d: PackedVector2Array, r0: float, r1: float, caps: Array) -> Array:
	var out: Array = []
	if d.size() < 2:
		return out
	for e in 2:
		if not bool(caps[e]):
			continue
		var r := r0 if e == 0 else r1
		if r <= 0.05:
			continue
		var p: Vector2 = d[0] if e == 0 else d[d.size() - 1]
		var q: Vector2 = d[1] if e == 0 else d[d.size() - 2]
		var t := (p - q).normalized()
		if t.length_squared() < 1e-6:
			continue
		var nn := Vector2(-t.y, t.x)
		var seg := 48
		var poly := PackedVector2Array()
		for k in seg + 1:
			var a := PI * float(k) / float(seg)
			poly.append(p + (nn * cos(a) + t * sin(a)) * r)
		out.append(poly)
	return out


func _curve_band_polys(cv: Dictionary, inset: float, ext_e: float, lim := Rect2(), extend_mates := false) -> Array:
	var d: PackedVector2Array = cv.d
	if d.size() < 2:
		return []
	var w := float(cv.w)
	var w0 := float(cv.get("w0", w))
	var w1 := float(cv.get("w1", w))
	var out: Array = []
	if absf(w0 - w) < 0.05 and absf(w1 - w) < 0.05:
		var r := w * 0.5 - inset
		if r <= 0.05:
			return out
		var chunks := _chunks(d)
		var mate_ends: Array = cv.get("mate_ends", [false, false])
		var mate_dirs: Array = cv.get("mate_dirs", [Vector2.ZERO, Vector2.ZERO])
		for idx in chunks.size():
			var ch: PackedVector2Array = chunks[idx]
			if lim.has_area() and not lim.intersects(WC._poly_rect(ch).grow(r + 2.0)):
				continue
			var line := ch.duplicate()
			if ch.size() >= 2:
				if idx == 0 and bool(mate_ends[0]) and (mate_dirs[0] as Vector2) != Vector2.ZERO and (ext_e > 0.001 or extend_mates):
					var mlen := maxf(ext_e, 0.32) if ext_e > 0.001 else 0.22
					line.insert(0, ch[0] + (mate_dirs[0] as Vector2) * mlen)
				elif ext_e > 0.001:
					line[0] = ch[0] + (ch[0] - ch[1]).normalized() * ext_e
				if idx == chunks.size() - 1 and bool(mate_ends[1]) and (mate_dirs[1] as Vector2) != Vector2.ZERO and (ext_e > 0.001 or extend_mates):
					var mlen := maxf(ext_e, 0.32) if ext_e > 0.001 else 0.22
					line.append(ch[ch.size() - 1] + (mate_dirs[1] as Vector2) * mlen)
				elif ext_e > 0.001:
					line[line.size() - 1] = ch[ch.size() - 1] + (ch[ch.size() - 1] - ch[ch.size() - 2]).normalized() * ext_e
			out.append_array(_offset_line(line, r))
		return out
	var s_arr := WC._poly_s_arr(d)
	var total := s_arr[d.size() - 1]
	if total < 0.2:
		return out
	var taper_l := minf(10.0, total * 0.48)
	var r_arr := PackedFloat32Array()
	r_arr.resize(d.size())
	for k in d.size():
		var s := s_arr[k]
		var hw_k := w * 0.5
		if absf(w0 - w) >= 0.05 and s < taper_l:
			hw_k = lerpf(w0 * 0.5, w * 0.5, smoothstep(0.0, taper_l, s))
		if absf(w1 - w) >= 0.05 and (total - s) < taper_l:
			hw_k = lerpf(w1 * 0.5, hw_k, smoothstep(0.0, taper_l, total - s))
		r_arr[k] = maxf(0.15, hw_k - inset)
	var n := d.size()
	var mate_ends2: Array = cv.get("mate_ends", [false, false])
	var mate_dirs2: Array = cv.get("mate_dirs", [Vector2.ZERO, Vector2.ZERO])
	var ranges := _chunk_ranges(d, 64.0, 10.5, 160)
	for r_idx in ranges.size():
		var s_idx: int = ranges[r_idx][0]
		var e_idx: int = ranges[r_idx][1]
		var c_pts := d.slice(s_idx, e_idx)
		var c_r := r_arr.slice(s_idx, e_idx)
		if not lim.has_area() or lim.intersects(WC._poly_rect(c_pts).grow(w * 0.5 + 2.0)):
			if c_pts.size() >= 2:
				if r_idx == 0 and bool(mate_ends2[0]) and (mate_dirs2[0] as Vector2) != Vector2.ZERO and (ext_e > 0.001 or extend_mates):
					var mlen := maxf(ext_e, 0.32) if ext_e > 0.001 else 0.22
					c_pts.insert(0, c_pts[0] + (mate_dirs2[0] as Vector2) * mlen)
					c_r.insert(0, c_r[0])
				elif ext_e > 0.001:
					c_pts[0] = c_pts[0] + (c_pts[0] - c_pts[1]).normalized() * ext_e
				if (r_idx == ranges.size() - 1 or e_idx >= n) and bool(mate_ends2[1]) and (mate_dirs2[1] as Vector2) != Vector2.ZERO and (ext_e > 0.001 or extend_mates):
					var mlen := maxf(ext_e, 0.32) if ext_e > 0.001 else 0.22
					c_pts.append(c_pts[c_pts.size() - 1] + (mate_dirs2[1] as Vector2) * mlen)
					c_r.append(c_r[c_r.size() - 1])
				elif ext_e > 0.001:
					var ml := c_pts.size()
					c_pts[ml - 1] = c_pts[ml - 1] + (c_pts[ml - 1] - c_pts[ml - 2]).normalized() * ext_e
				var m := c_pts.size()
				var left_side := PackedVector2Array()
				var right_side := PackedVector2Array()
				for k in m:
					var t_k := Vector2.ZERO
					var ref_d := Vector2.ZERO
					if k == 0:
						t_k = (c_pts[1] - c_pts[0]).normalized()
						ref_d = t_k
					elif k == m - 1:
						t_k = (c_pts[m - 1] - c_pts[m - 2]).normalized()
						ref_d = t_k
					else:
						var d0 := (c_pts[k] - c_pts[k - 1]).normalized()
						var d1 := (c_pts[k + 1] - c_pts[k]).normalized()
						t_k = (d0 + d1).normalized()
						if t_k.length_squared() < 1e-4:
							t_k = (c_pts[k + 1] - c_pts[k - 1]).normalized()
						ref_d = d0
					var miter := clampf(1.0 / maxf(0.6, absf(t_k.dot(ref_d))), 1.0, 1.35)
					var nn := Vector2(-t_k.y, t_k.x) * (c_r[k] * miter)
					left_side.append(c_pts[k] - nn)
					right_side.append(c_pts[k] + nn)
				right_side.reverse()
				var rib := left_side
				rib.append_array(right_side)
				if WC.poly_area_signed(rib) < 0.0:
					rib.reverse()
				for u: PackedVector2Array in _offset_poly_smooth(rib, 0.02, c_pts[0]):
					out.append_array(_offset_poly_smooth(u, -0.02, c_pts[0]))
	return out


func _emit_dedup_polys(st: SurfaceTool, polys: Array, y: float, thick := 0.0) -> int:
	var cuts: Array = []
	var cgrid := {}
	var n := 0
	for raw: PackedVector2Array in polys:
		if raw.size() < 3:
			continue
		for raw_piece: PackedVector2Array in _subtract_cuts(raw, cuts, cgrid, []):
			var piece := _sanitize_poly(raw_piece, 0.15)
			if piece.is_empty():
				continue
			_emit_poly(st, piece, y, thick)
			_add_cut(cuts, cgrid, piece)
			n += 1
	return n


## 多边形清理：顺序剔除微短边、严格共线冗余点（弦高 < 1.5mm）及 180° 细针尖刺，绝不抽稀平滑弯道
func _sanitize_poly(poly: PackedVector2Array, min_area := 0.20) -> PackedVector2Array:
	var pts := poly.duplicate()
	if pts.size() < 3:
		return PackedVector2Array()
	for _pass in 3:
		var dedup := PackedVector2Array()
		for q in pts:
			if dedup.is_empty() or dedup[dedup.size() - 1].distance_to(q) >= 0.012:
				dedup.append(q)
		while dedup.size() >= 3 and dedup[dedup.size() - 1].distance_to(dedup[0]) < 0.012:
			dedup.remove_at(dedup.size() - 1)
		if dedup.size() < 3:
			return PackedVector2Array()
		var m := dedup.size()
		var nxt := PackedVector2Array()
		var changed := dedup.size() != pts.size()
		for i in m:
			var a: Vector2 = nxt[nxt.size() - 1] if not nxt.is_empty() else dedup[m - 1]
			var b := dedup[i]
			var c := dedup[(i + 1) % m]
			var la := a.distance_to(b)
			var lc := b.distance_to(c)
			if la < 0.008 or lc < 0.008:
				nxt.append(b)
				continue
			var dp := ((b - a) / la).dot((c - b) / lc)
			if dp < -0.955:
				changed = true
				continue
			if dp > 0.999995 and WC.seg_dist(b, a, c) < 0.0002:
				changed = true
				continue
			nxt.append(b)
		if nxt.size() < 3:
			return PackedVector2Array()
		while nxt.size() >= 3 and nxt[nxt.size() - 1].distance_to(nxt[0]) < 0.012:
			nxt.remove_at(nxt.size() - 1)
			changed = true
		if nxt.size() < 3:
			return PackedVector2Array()
		pts = nxt
		if not changed:
			break
	if pts.size() < 3 or WC.poly_area(pts) < min_area:
		return PackedVector2Array()
	return pts


## 对人行道/路沿石裁剪后的外凸锐角尖刺（< 47°）做平头倒角削尖，并按层面积阈值丢弃碎渣片
func _clean_walk_piece(poly: PackedVector2Array, min_area := 0.24) -> PackedVector2Array:
	var pts := _sanitize_poly(poly, min_area * 0.8)
	if pts.is_empty():
		return PackedVector2Array()
	var ccw := WC.poly_area_signed(pts) > 0.0
	var out := PackedVector2Array()
	var m := pts.size()
	for i in m:
		var a := pts[(i - 1 + m) % m]
		var b := pts[i]
		var c := pts[(i + 1) % m]
		var d_in := b - a
		var d_out := c - b
		var la := d_in.length()
		var lc := d_out.length()
		if la < 0.04 or lc < 0.04:
			out.append(b)
			continue
		var in_dir := d_in / la
		var out_dir := d_out / lc
		var cr := in_dir.cross(out_dir)
		var is_convex := (cr > 0.015) if ccw else (cr < -0.015)
		if is_convex and in_dir.dot(out_dir) < -0.68:
			var bev := minf(0.45, minf(la, lc) * 0.30)
			out.append(b - in_dir * bev)
			out.append(b + out_dir * bev)
		else:
			out.append(b)
	return _sanitize_poly(out, min_area)


## 16 倍局部缩放圆角偏移：将 Clipper 默认 0.25m 弦高容差压低至 0.0156m，使交叉口喇叭口圆弧细腻顺滑
func _offset_poly_smooth(poly: PackedVector2Array, delta: float, ref: Vector2) -> Array:
	if poly.size() < 3:
		return []
	if absf(delta) < 0.0005:
		var cp := poly.duplicate()
		if WC.poly_area_signed(cp) < 0.0:
			cp.reverse()
		return [cp]
	const S := 20.0
	const INV_S := 1.0 / 20.0
	var sp := PackedVector2Array()
	sp.resize(poly.size())
	for i in poly.size():
		sp[i] = (poly[i] - ref) * S
	if WC.poly_area_signed(sp) < 0.0:
		sp.reverse()
	var out: Array = []
	for r: PackedVector2Array in _outers(Geometry2D.offset_polygon(sp, delta * S, Geometry2D.JOIN_ROUND)):
		if r.size() < 3:
			continue
		var up := PackedVector2Array()
		up.resize(r.size())
		for i in r.size():
			up[i] = r[i] * INV_S + ref
		if WC.poly_area_signed(up) < 0.0:
			up.reverse()
		out.append(up)
	return out


func _sample_poly_at_s(pts: PackedVector2Array, s_arr: PackedFloat32Array, target_s: float) -> Vector2:
	if pts.is_empty():
		return Vector2.ZERO
	var n := pts.size()
	if n == 1 or target_s <= 0.0:
		return pts[0]
	if target_s >= s_arr[n - 1]:
		return pts[n - 1]
	for k in n - 1:
		var s0 := s_arr[k]
		var s1 := s_arr[k + 1]
		if target_s <= s1:
			var t := (target_s - s0) / maxf(0.0001, s1 - s0)
			return pts[k].lerp(pts[k + 1], t)
	return pts[n - 1]


func _compute_junction_bellmouths(lim: Rect2) -> Array:
	var raw_pts: Array = []
	for ci in curves.size():
		var cvi: Dictionary = curves[ci]
		if cvi.dirt:
			continue
		var di: PackedVector2Array = cvi.d
		if di.size() < 2:
			continue
		var mates_i: PackedInt32Array = cvi.get("tangent_mates", PackedInt32Array())
		for e in 2:
			var pe: Vector2 = di[0] if e == 0 else di[di.size() - 1]
			if not lim.has_point(pe):
				continue
			var te := (di[1] - di[0]).normalized() if e == 0 else (di[di.size() - 1] - di[di.size() - 2]).normalized()
			var lst = _rg.grid.get(Vector2i(floori(pe.x / _rg.cell), floori(pe.y / _rg.cell)))
			if lst != null:
				for si: int in lst:
					var cj: int = _rg.tag[si]
					if cj == ci or (cj in mates_i) or curves[cj].dirt:
						continue
					var seg_dir := (_rg.b[si] - _rg.a[si]).normalized()
					if absf(te.dot(seg_dir)) < 0.93 and WC.seg_dist(pe, _rg.a[si], _rg.b[si]) <= _rg.hw[si] + 1.5:
						raw_pts.append(pe)
		var ri := WC._poly_rect(di).grow(2.0)
		if not lim.intersects(ri):
			continue
		var pi_seg: PackedVector2Array = cvi.pts
		var ri_seg := WC._poly_rect(pi_seg).grow(2.5)
		for cj in range(ci + 1, curves.size()):
			var cvj: Dictionary = curves[cj]
			if cvj.dirt or (cj in mates_i):
				continue
			var pj_seg: PackedVector2Array = cvj.pts
			if pj_seg.size() < 2 or not ri_seg.intersects(WC._poly_rect(pj_seg).grow(2.5)):
				continue
			for ka in pi_seg.size() - 1:
				var a0 := pi_seg[ka]
				var a1 := pi_seg[ka + 1]
				var da := (a1 - a0).normalized()
				var ra := Rect2(a0, Vector2.ZERO).expand(a1)
				for kb in pj_seg.size() - 1:
					var b0 := pj_seg[kb]
					var b1 := pj_seg[kb + 1]
					if not ra.intersects(Rect2(b0, Vector2.ZERO).expand(b1)):
						continue
					var xing = Geometry2D.segment_intersects_segment(a0, a1, b0, b1)
					if xing != null:
						var db := (b1 - b0).normalized()
						if absf(da.dot(db)) < 0.93:
							raw_pts.append(xing)
	raw_pts.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		var sx_a := snappedf(a.x, 0.1)
		var sx_b := snappedf(b.x, 0.1)
		if sx_a != sx_b:
			return sx_a < sx_b
		return snappedf(a.y, 0.1) < snappedf(b.y, 0.1)
	)
	var clusters: Array = []
	for pt: Vector2 in raw_pts:
		if not lim.has_point(pt) or in_wet(pt, 1.8) or _on_bridge(pt, 1.8):
			continue
		var merged := false
		for cl: Array in clusters:
			var cur_c: Vector2 = cl[0] / float(cl[1])
			if pt.distance_to(cur_c) < 7.5:
				cl[0] += pt
				cl[1] += 1
				merged = true
				break
		if not merged:
			clusters.append([pt, 1])
	var all_bldgs: Array = []
	for b: Dictionary in layout.get("bldgs", []) + layout.get("backdrop_bldgs", []):
		var bp: PackedVector2Array = WC.obb_corners(b.c, float(b.ang), float(b.sx), float(b.sz))
		if bp.size() >= 3:
			all_bldgs.append([bp, WC._poly_rect(bp).grow(WALK_W + 2.0)])
	var out: Array = []
	for cl: Array in clusters:
		var jp: Vector2 = cl[0] / float(cl[1])
		if not lim.has_point(jp) or in_wet(jp, 1.8) or _on_bridge(jp, 1.8):
			continue
		var min_w := INF
		var max_hw := 0.0
		var all_wide := true
		var part: Array = []
		for ci in curves.size():
			var cv: Dictionary = curves[ci]
			if cv.dirt:
				continue
			var hw := float(cv.w) * 0.5
			if WC.poly_dist(cv.d, jp) <= hw + 7.5:
				part.append(cv)
				min_w = minf(min_w, float(cv.w))
				max_hw = maxf(max_hw, hw)
				if float(cv.w) < 10.0:
					all_wide = false
		if part.size() < 2:
			continue
		var arm_dirs: Array = []
		for cv: Dictionary in part:
			var d_cv: PackedVector2Array = cv.d
			if d_cv.size() < 2:
				continue
			var s_arr := WC._poly_s_arr(d_cv)
			var total_s := s_arr[d_cv.size() - 1]
			var best_d2 := INF
			var s_hit := 0.0
			for k in d_cv.size() - 1:
				var pa := d_cv[k]
				var pb := d_cv[k + 1]
				var ab := pb - pa
				var ab2 := ab.length_squared()
				var t := clampf((jp - pa).dot(ab) / ab2, 0.0, 1.0) if ab2 > 1e-6 else 0.0
				var proj := pa + ab * t
				var d2 := jp.distance_squared_to(proj)
				if d2 < best_d2:
					best_d2 = d2
					s_hit = lerpf(s_arr[k], s_arr[k + 1], t)
			if s_hit >= 5.5:
				var p_back := _sample_poly_at_s(d_cv, s_arr, maxf(0.0, s_hit - 9.0))
				var v_back := p_back - jp
				if v_back.length_squared() > 1e-4:
					v_back = v_back.normalized()
					var dup := false
					for u: Vector2 in arm_dirs:
						if u.dot(v_back) > 0.945:
							dup = true
							break
					if not dup:
						arm_dirs.append(v_back)
			if total_s - s_hit >= 5.5:
				var p_fwd := _sample_poly_at_s(d_cv, s_arr, minf(total_s, s_hit + 9.0))
				var v_fwd := p_fwd - jp
				if v_fwd.length_squared() > 1e-4:
					v_fwd = v_fwd.normalized()
					var dup := false
					for u: Vector2 in arm_dirs:
						if u.dot(v_fwd) > 0.945:
							dup = true
							break
					if not dup:
						arm_dirs.append(v_fwd)
		var max_acute_cos := -0.35
		for i in arm_dirs.size():
			for j in range(i + 1, arm_dirs.size()):
				max_acute_cos = maxf(max_acute_cos, (arm_dirs[i] as Vector2).dot(arm_dirs[j] as Vector2))
		var rf_base := 5.0 if min_w < 8.5 else (6.2 if min_w < 11.5 else 7.4)
		var rf := minf(rf_base, 4.6) if max_acute_cos > 0.55 else rf_base
		var sin_half := sqrt(maxf(0.08, 0.5 * (1.0 - max_acute_cos)))
		var cos_half := sqrt(maxf(0.0, 1.0 - sin_half * sin_half))
		var x_tan := (maxf(1.5, max_hw - WALK_W) + rf) * (cos_half / sin_half)
		var tan_reach := sqrt(x_tan * x_tan + max_hw * max_hw)
		var r_clip := clampf(tan_reach + 2.8, 12.0, 34.0)
		var r_loc := r_clip + rf + WALK_W + 6.0
		var loc_box := Rect2(jp - Vector2(r_loc, r_loc), Vector2(r_loc * 2.0, r_loc * 2.0))
		var cw_polys: Array = []
		for cv: Dictionary in part:
			cw_polys.append_array(_curve_band_polys(cv, WALK_W, 0.25, loc_box, true))
			var d_cv: PackedVector2Array = cv.d
			var caps_cv: Array = cv.get("caps", [false, false])
			var cw0 := maxf(0.5, float(cv.get("w0", cv.w)) * 0.5 - WALK_W)
			var cw1 := maxf(0.5, float(cv.get("w1", cv.w)) * 0.5 - WALK_W)
			for cp_cap: PackedVector2Array in _cap_polys_ends(d_cv, cw0, cw1, caps_cv):
				if loc_box.intersects(WC._poly_rect(cp_cap)):
					cw_polys.append(cp_cap)
		var u_polys := _merge_polys(cw_polys)
		if u_polys.is_empty():
			continue
		for ui in u_polys.size():
			if WC.poly_area_signed(u_polys[ui]) < 0.0:
				(u_polys[ui] as PackedVector2Array).reverse()
		var dilated: Array = []
		for u: PackedVector2Array in u_polys:
			dilated.append_array(_offset_poly_smooth(u, rf, jp))
		var d_merged := _merge_polys(dilated)
		var eroded: Array = []
		for dp: PackedVector2Array in d_merged:
			eroded.append_array(_offset_poly_smooth(dp, -rf, jp))
		var closed_polys := _merge_polys(eroded)
		if closed_polys.is_empty():
			continue
		var b_box := Rect2(jp - Vector2(r_clip + WALK_W + 3.0, r_clip + WALK_W + 3.0), Vector2(r_clip + WALK_W + 3.0, r_clip + WALK_W + 3.0) * 2.0)
		var obs_polys: Array = []
		for be: Array in all_bldgs:
			if (be[1] as Rect2).intersects(b_box):
				var bc_pos: PackedVector2Array = be[0]
				if WC.poly_area_signed(bc_pos) < 0.0:
					bc_pos = bc_pos.duplicate()
					bc_pos.reverse()
				obs_polys.append_array(_outers(Geometry2D.offset_polygon(bc_pos, WALK_W + 0.35, Geometry2D.JOIN_MITER)))
		for line: PackedVector2Array in rail_polys:
			for ch: PackedVector2Array in _chunks(line):
				if b_box.intersects(WC._poly_rect(ch).grow(WALK_W + 3.0)):
					obs_polys.append_array(_offset_line(_ext_line(ch, 0.2), WALK_W + 2.45))
		for br: Array in bridges:
			var b0: Vector2 = br[0]
			var b1: Vector2 = br[1]
			var bln := b0.distance_to(b1)
			if bln < 0.1:
				continue
			var br_r := Rect2(b0, Vector2.ZERO).expand(b1).grow(float(br[2]) * 0.5 + WALK_W + 1.0)
			if b_box.intersects(br_r):
				var bdir := (b1 - b0) / bln
				obs_polys.append_array(_offset_line(PackedVector2Array([b0 - bdir * 0.2, b1 + bdir * 0.2]), float(br[2]) * 0.5 + WALK_W + 0.35))
		for rv: Dictionary in rivers:
			if bool(rv.dry):
				continue
			var rhw := float(rv.w) * 0.5 + WALK_W + 1.2
			for ch: PackedVector2Array in _chunks(rv.pts):
				if b_box.intersects(WC._poly_rect(ch).grow(rhw + 1.0)):
					obs_polys.append_array(_offset_line(ch, rhw))
		for l: Vector3 in lakes:
			if jp.distance_to(Vector2(l.x, l.y)) < l.z * 1.45 + r_clip + WALK_W + 4.0:
				obs_polys.append(WC.lake_poly(l, 56, WALK_W + 2.2))
		for oi in obs_polys.size():
			if WC.poly_area_signed(obs_polys[oi]) < 0.0:
				(obs_polys[oi] as PackedVector2Array).reverse()
		var safe_closed: Array = closed_polys
		if not obs_polys.is_empty():
			var flares: Array = closed_polys.duplicate()
			for u: PackedVector2Array in u_polys:
				for u_in: PackedVector2Array in _offset_poly_smooth(u, -0.05, jp):
					var nxt_f: Array = []
					for fp: PackedVector2Array in flares:
						nxt_f.append_array(_outers(Geometry2D.clip_polygons(fp, u_in)))
					flares = nxt_f
					if flares.is_empty():
						break
				if flares.is_empty():
					break
			for ob: PackedVector2Array in obs_polys:
				if flares.is_empty():
					break
				var nxt_f: Array = []
				for fp: PackedVector2Array in flares:
					nxt_f.append_array(_outers(Geometry2D.clip_polygons(fp, ob)))
				flares = nxt_f
			var comb: Array = []
			comb.append_array(u_polys)
			comb.append_array(flares)
			safe_closed = _merge_polys(comb)
		for si in safe_closed.size():
			if WC.poly_area_signed(safe_closed[si]) < 0.0:
				(safe_closed[si] as PackedVector2Array).reverse()
		var disk := _circle_poly(jp, r_clip, 80)
		if WC.poly_area_signed(disk) < 0.0:
			disk.reverse()
		var disk_band := _circle_poly(jp, maxf(2.0, r_clip - 0.005), 80)
		if WC.poly_area_signed(disk_band) < 0.0:
			disk_band.reverse()
		var disk_bcut := _circle_poly(jp, r_clip + 0.25, 80)
		if WC.poly_area_signed(disk_bcut) < 0.0:
			disk_bcut.reverse()
		var inner_clip: Array = []
		for cp: PackedVector2Array in safe_closed:
			for bp_c: PackedVector2Array in _outers(Geometry2D.intersect_polygons(cp, disk)):
				var sb := _sanitize_poly(bp_c, 0.5)
				if sb.size() >= 3:
					if WC.poly_area_signed(sb) < 0.0:
						sb.reverse()
					inner_clip.append(sb)
		if inner_clip.is_empty():
			continue
		var b_cuts: Array = []
		for cp: PackedVector2Array in safe_closed:
			for zp: PackedVector2Array in _offset_poly_smooth(cp, 0.006, jp):
				for zc: PackedVector2Array in _outers(Geometry2D.intersect_polygons(zp, disk_bcut)):
					var szc := _sanitize_poly(zc, 0.25)
					if szc.size() >= 3:
						if WC.poly_area_signed(szc) < 0.0:
							szc.reverse()
						b_cuts.append(szc)
		var band_cuts: Array = []
		for cp: PackedVector2Array in safe_closed:
			for zp: PackedVector2Array in _offset_poly_smooth(cp, WALK_W + 0.45, jp):
				for zc: PackedVector2Array in _outers(Geometry2D.intersect_polygons(zp, disk_band)):
					var szc := _sanitize_poly(zc, 0.25)
					if szc.size() >= 3:
						if WC.poly_area_signed(szc) < 0.0:
							szc.reverse()
						band_cuts.append(szc)
		out.append({"cp": safe_closed, "inner_clip": inner_clip, "b_cuts": b_cuts, "band_cuts": band_cuts, "disk": disk, "jp": jp, "wide": all_wide})
	return out


func _has_crossing_paved(pg: WC.SegGrid, p: Vector2, skip: int, mates: PackedInt32Array, dir: Vector2, min_d: float, max_d: float) -> bool:
	var lst = pg.grid.get(Vector2i(floori(p.x / pg.cell), floori(p.y / pg.cell)))
	if lst == null:
		return false
	var best := INF
	for i: int in lst:
		var tg := pg.tag[i]
		if tg == skip or (tg in mates):
			continue
		var sd := (pg.b[i] - pg.a[i]).normalized()
		if absf(dir.dot(sd)) >= 0.85:
			continue
		var ab: Vector2 = pg.b[i] - pg.a[i]
		var u := clampf((p - pg.a[i]).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d := p.distance_to(pg.a[i] + ab * u) - pg.hw[i]
		if d < best:
			best = d
	return best > min_d and best < max_d


func _build_walks(st_w: SurfaceTool, st_c: SurfaceTool, bellmouths: Array) -> int:
	var lim := Rect2(-EXT_HALF - 56.0, -EXT_HALF - 56.0, EXT_HALF * 2.0 + 112.0, EXT_HALF * 2.0 + 112.0)
	var cuts: Array = []          ## [多边形, 外接矩形]
	var cgrid := {}
	var bands: Array = []         ## [曲线索引, 各自车道切口序号列表]
	var ends: Array = []          ## [端点, 朝外方向, 端半宽]
	for ci in curves.size():
		var cv: Dictionary = curves[ci]
		if cv.dirt:
			continue
		var d: PackedVector2Array = cv.d
		if d.size() < 2:
			continue
		var hw: float = float(cv.w) * 0.5
		var all_own: Array = []
		for poly: PackedVector2Array in _curve_band_polys(cv, WALK_W, 0.05, lim):
			all_own.append(_add_cut(cuts, cgrid, poly))
		bands.append([cv, all_own])
		var caps: Array = cv.get("caps", [false, false])
		var hw0 := float(cv.get("w0", cv.w)) * 0.5
		var hw1 := float(cv.get("w1", cv.w)) * 0.5
		for e in 2:
			if bool(caps[e]):
				var p: Vector2 = d[0] if e == 0 else d[d.size() - 1]
				var q: Vector2 = d[1] if e == 0 else d[d.size() - 2]
				if lim.has_point(p):
					ends.append([p, (p - q).normalized(), hw0 if e == 0 else hw1])
	for line: PackedVector2Array in rail_polys:
		for ch: PackedVector2Array in _chunks(line):
			if lim.intersects(WC._poly_rect(ch).grow(3.0)):
				for poly: PackedVector2Array in _offset_line(_ext_line(ch, 0.05), 2.35):
					_add_cut(cuts, cgrid, poly)
	for br: Array in bridges:
		var b0: Vector2 = br[0]
		var b1: Vector2 = br[1]
		var bln := b0.distance_to(b1)
		if bln < 0.1:
			continue
		var bdir := (b1 - b0) / bln
		for poly: PackedVector2Array in _offset_line(PackedVector2Array([b0 - bdir * 0.18, b1 + bdir * 0.18]), float(br[2]) * 0.5 + 0.25):
			_add_cut(cuts, cgrid, poly)
	var n := 0
	# 两层：人行道面（0.18 米高）与靠车道一侧的路沿石（0.215 米高）；喇叭口与沿线带分用独立切口表（喇叭口用 b_cuts，沿线带仅用一次性的 band_cuts），避免 r_clip 接缝三重阶梯切割
	for layer in [[st_w, 0.0, 0.18, 0.14, 0.24], [st_c, WALK_W - CURB_W, 0.215, 0.035, 0.055]]:
		var st: SurfaceTool = layer[0]
		var inset: float = layer[1]
		var min_a: float = layer[4]
		var bell_lcuts := cuts.duplicate()
		var bell_lcgrid := cgrid.duplicate(true)
		var bell_items: Array = []
		for bm: Dictionary in bellmouths:
			var b_own: Array = []
			for bc_poly: PackedVector2Array in bm.b_cuts:
				b_own.append(_add_cut(bell_lcuts, bell_lcgrid, bc_poly))
			bell_items.append([bm, b_own])
		var band_lcuts := cuts.duplicate()
		var band_lcgrid := cgrid.duplicate(true)
		for bi: Array in bell_items:
			var bm: Dictionary = bi[0]
			var b_own: Array = bi[1]
			for c_poly: PackedVector2Array in bm.cp:
				for expanded: PackedVector2Array in _offset_poly_smooth(c_poly, WALK_W - inset, bm.jp):
					for outer: PackedVector2Array in _outers(Geometry2D.intersect_polygons(expanded, bm.disk)):
						for raw_piece: PackedVector2Array in _subtract_cuts(outer, bell_lcuts, bell_lcgrid, b_own):
							var piece := _clean_walk_piece(raw_piece, min_a)
							if piece.is_empty():
								continue
							_emit_poly(st, piece, layer[2], layer[3])
							_add_cut(bell_lcuts, bell_lcgrid, piece)
							n += 1
		for e: Array in ends:
			var hw: float = e[2]
			var ring := _half_ring(e[0], e[1], hw - WALK_W, hw - inset)
			for raw_piece: PackedVector2Array in _subtract_cuts(ring, bell_lcuts, bell_lcgrid, []):
				var piece := _clean_walk_piece(raw_piece, min_a)
				if piece.is_empty():
					continue
				_emit_poly(st, piece, layer[2], layer[3])
				_add_cut(bell_lcuts, bell_lcgrid, piece)
				_add_cut(band_lcuts, band_lcgrid, piece)
				n += 1
		for bm: Dictionary in bellmouths:
			for bc_poly: PackedVector2Array in bm.band_cuts:
				_add_cut(band_lcuts, band_lcgrid, bc_poly)
		for b: Array in bands:
			for outer: PackedVector2Array in _curve_band_polys(b[0], inset, 0.0, lim, true):
				for raw_piece: PackedVector2Array in _subtract_cuts(outer, band_lcuts, band_lcgrid, b[1]):
					var piece := _clean_walk_piece(raw_piece, min_a)
					if piece.is_empty():
						continue
					_emit_poly(st, piece, layer[2], layer[3])
					_add_cut(band_lcuts, band_lcgrid, piece)
					n += 1
	return n


func _add_cut(cuts: Array, cgrid: Dictionary, poly: PackedVector2Array) -> int:
	var r := WC._poly_rect(poly)
	var i := cuts.size()
	cuts.append([poly, r])
	for gz in range(floori(r.position.y / _CUT_CELL), floori(r.end.y / _CUT_CELL) + 1):
		for gx in range(floori(r.position.x / _CUT_CELL), floori(r.end.x / _CUT_CELL) + 1):
			var key := Vector2i(gx, gz)
			if cgrid.has(key):
				cgrid[key].append(i)
			else:
				cgrid[key] = PackedInt32Array([i])
	return i


## poly 减去所有和它相交的切口（first 里的先减：本段自己的车道先把条带切成两侧的细带，之后不会再出现洞）
func _subtract_cuts(poly: PackedVector2Array, cuts: Array, cgrid: Dictionary, first: Array) -> Array:
	var r := WC._poly_rect(poly)
	var order: Array = first.duplicate()
	var seen := {}
	for i in first:
		seen[i] = true
	for gz in range(floori(r.position.y / _CUT_CELL), floori(r.end.y / _CUT_CELL) + 1):
		for gx in range(floori(r.position.x / _CUT_CELL), floori(r.end.x / _CUT_CELL) + 1):
			var lst = cgrid.get(Vector2i(gx, gz))
			if lst == null:
				continue
			for i: int in lst:
				if not seen.has(i):
					seen[i] = true
					if (cuts[i][1] as Rect2).intersects(r):
						order.append(i)
	var pieces: Array = [poly]
	for i: int in order:
		var c: PackedVector2Array = cuts[i][0]
		var cr: Rect2 = cuts[i][1]
		var nxt: Array = []
		for pp: PackedVector2Array in pieces:
			if not cr.intersects(WC._poly_rect(pp)):
				nxt.append(pp)
				continue
			nxt.append_array(_outers(Geometry2D.clip_polygons(pp, c)))
		pieces = nxt
		if pieces.is_empty():
			break
	var out: Array = []
	for pp: PackedVector2Array in pieces:
		if pp.size() >= 3 and absf(WC.poly_area_signed(pp)) > 0.05:
			out.append(pp)
	return out


## 多边形顶面（高 y）+ 一圈向下 thick 的侧壁；耳切退化时用形态学开运算自愈兜底，绝不静默丢弃整段路面/路沿
func _emit_poly(st: SurfaceTool, poly: PackedVector2Array, y: float, thick: float, allow_heal := true) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	if idx.is_empty():
		if allow_heal:
			for shrunk: PackedVector2Array in _outers(Geometry2D.offset_polygon(poly, -0.05, Geometry2D.JOIN_MITER)):
				for healed: PackedVector2Array in _outers(Geometry2D.offset_polygon(shrunk, 0.05, Geometry2D.JOIN_ROUND)):
					var sp := _sanitize_poly(healed, 0.10)
					if sp.size() >= 3 and not Geometry2D.triangulate_polygon(sp).is_empty():
						_emit_poly(st, sp, y, thick, false)
		return
	for k in range(0, idx.size(), 3):
		var a := poly[idx[k]]
		var b := poly[idx[k + 1]]
		var c := poly[idx[k + 2]]
		_st_tri(st, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y))
	if thick <= 0.001:
		return
	var ccw := WC.poly_area_signed(poly) > 0.0
	var yb := y - thick
	var m := poly.size()
	for i in m:
		var p := poly[i]
		var q := poly[(i + 1) % m]
		var e := q - p
		if e.length_squared() < 1e-6:
			continue
		# 外法线；面朝外时三角形顺时针（与顶面同一约定）
		var nrm := Vector2(e.y, -e.x).normalized() if ccw else Vector2(-e.y, e.x).normalized()
		if Vector2(-e.y, e.x).dot(nrm) < 0.0:
			var tmp := p
			p = q
			q = tmp
		var n3 := Vector3(nrm.x, 0.0, nrm.y)
		var pt := Vector3(p.x, y, p.y)
		var qt := Vector3(q.x, y, q.y)
		var pb := Vector3(p.x, yb, p.y)
		var qb := Vector3(q.x, yb, q.y)
		for v in [pt, qt, pb, qt, qb, pb]:
			st.set_normal(n3)
			st.set_uv(Vector2(v.x + v.z, v.y) * 0.1)
			st.add_vertex(v)


func _rail_dist(p: Vector2) -> float:
	var best := INF
	for line: PackedVector2Array in rail_polys:
		best = minf(best, WC.poly_dist(line, p))
	return best


func _paved_seg_grid() -> WC.SegGrid:
	var pg := WC.SegGrid.new()
	pg.cell = 16.0
	pg.reach = 14.0
	for ci in curves.size():
		var cv: Dictionary = curves[ci]
		if not cv.dirt:
			pg.add_poly(cv.pts, float(cv.w) * 0.5, ci)
	return pg


func _build_roads(sliced := false) -> void:
	rng.seed = _map_seed(2)
	var ASPH: ShaderMaterial = A.asphalt(Color(0.20, 0.205, 0.215)).duplicate()
	var ASPH2: ShaderMaterial = A.asphalt(Color(0.23, 0.235, 0.245)).duplicate()
	var ARUT: ShaderMaterial = A.asphalt(Color(0.15, 0.155, 0.162)).duplicate()
	var dt_road := ground_dust_tint()
	var dirt_c := dt_road.darkened(0.32)
	var rut_c := dt_road.darkened(0.46)
	var DIRT: ShaderMaterial = _terrain_feather_mat(Color(dirt_c.r, dirt_c.g, dirt_c.b, 0.72), 0.34, 0.93, 0.10, -9)
	var RUT: ShaderMaterial = _terrain_feather_mat(Color(rut_c.r, rut_c.g, rut_c.b, 0.46), 0.42, 0.95, 0.08, -8)
	for m in [ASPH, ASPH2, ARUT]:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		m.set_meta("no_outline", true)
	var WALK := A.concrete(Color(0.56, 0.54, 0.50), false)
	var CURB := A.concrete(Color(0.65, 0.63, 0.59), false)
	var LINE := A.paint(Color(0.82, 0.72, 0.42), 0.0, 0.85, {
		"wear": 0.65, "metal_wear": 0.0, "bare_metal": Color(0.20, 0.205, 0.215), "scratches": 0.12,
		"dust": 0.22, "panel_scale": 0.0, "use_albedo_tex": 1.0, "albedo_tex": A.world_tex("asphalt_a.png"),
		"albedo_tex_scale": 0.38, "albedo_tex_strength": 0.42, "normal_tex": A.world_tex("asphalt_n.png"), "normal_strength": 0.72,
	})
	var XWALK := A.paint(Color(0.74, 0.74, 0.71), 0.0, 0.88, {
		"wear": 0.72, "metal_wear": 0.0, "bare_metal": Color(0.20, 0.205, 0.215), "scratches": 0.15,
		"dust": 0.26, "panel_scale": 0.0, "use_albedo_tex": 1.0, "albedo_tex": A.world_tex("asphalt_a.png"),
		"albedo_tex_scale": 0.38, "albedo_tex_strength": 0.45, "normal_tex": A.world_tex("asphalt_n.png"), "normal_strength": 0.72,
	})
	var st_a := SurfaceTool.new()
	var st_b := SurfaceTool.new()
	var st_ar := SurfaceTool.new()
	var st_d := SurfaceTool.new()
	var st_r := SurfaceTool.new()
	var st_w := SurfaceTool.new()
	var st_c := SurfaceTool.new()
	for st in [st_a, st_b, st_ar, st_d, st_r, st_w, st_c]:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lim_r := Rect2(-EXT_HALF - 40.0, -EXT_HALF - 40.0, EXT_HALF * 2.0 + 80.0, EXT_HALF * 2.0 + 80.0)
	var bellmouths := _compute_junction_bellmouths(lim_r)
	var pg := _paved_seg_grid()
	var polys_a: Array = []
	var polys_b: Array = []
	var polys_ar: Array = []
	var polys_d: Array = []
	var dashes: Array = []
	var xwalks: Array = []
	var nr := 0
	for ci in curves.size():
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		var cv: Dictionary = curves[ci]
		var d: PackedVector2Array = cv.d
		var w: float = cv.w
		var hw0: float = float(cv.get("w0", w)) * 0.5
		var hw1: float = float(cv.get("w1", w)) * 0.5
		var caps: Array = cv.get("caps", [false, false])
		var mates: PackedInt32Array = cv.get("tangent_mates", PackedInt32Array())
		if cv.dirt:
			var sd_pts := _dense(d, 1.4)
			for ch: PackedVector2Array in _chunks(sd_pts):
				if lim_r.intersects(WC._poly_rect(ch).grow(w * 0.5 + 2.0)):
					polys_d.append_array(_offset_line(_ext_line(ch, 0.25), w * 0.5))
			polys_d.append_array(_cap_polys_ends(sd_pts, hw0, hw1, caps))
			var rut_pts := PackedVector2Array()
			for k in sd_pts.size():
				var rp_pt := sd_pts[k]
				if pg.edge_dist(rp_pt) >= -0.45 and _rail_dist(rp_pt) >= 2.6:
					rut_pts.append(rp_pt)
				else:
					if rut_pts.size() >= 2:
						for sd in [-1.3, 1.3]:
							nr += _st_strip_soft(st_r, rut_pts, 0.56, 0.50, sd, 0.062)
					rut_pts = PackedVector2Array()
			if rut_pts.size() >= 2:
				for sd in [-1.3, 1.3]:
					nr += _st_strip_soft(st_r, rut_pts, 0.56, 0.50, sd, 0.062)
			continue
		# 宽路（主干道）略高一层，路口处压住支路；断头画带路沿半圆头（按分段偏移+逐层去重，交叉口/弯道绝不双层闪烁）
		if w >= 10.0:
			polys_a.append_array(_curve_band_polys(cv, 0.0, 0.04, lim_r, true))
			polys_a.append_array(_cap_polys_ends(d, hw0, hw1, caps))
			for sd_r: float in [-2.1, 2.1]:
				for ch_r: PackedVector2Array in _chunks(_shift_line(d, sd_r)):
					if lim_r.intersects(WC._poly_rect(ch_r).grow(1.5)):
						polys_ar.append_array(_offset_line(ch_r, 0.675))
		else:
			polys_b.append_array(_curve_band_polys(cv, 0.0, 0.04, lim_r, true))
			polys_b.append_array(_cap_polys_ends(d, hw0, hw1, caps))
		# 道路中线虚线：按精确弧长等距插值，不随机缺段；主干道与次干道（w >= 6.5）统一标线，斑马线仅画于铺装路口且避开桥面与平交道口
		if w >= 6.5:
			var dash_step := 5.2 if w >= 10.0 else 6.0
			var next_s := 3.5
			var last_xw := -999.0
			var cur_s := 0.0
			var total_s := WC._poly_len(d)
			for i in d.size() - 1:
				var a := d[i]
				var b := d[i + 1]
				var seg := a.distance_to(b)
				if seg < 0.01:
					continue
				var t := (b - a) / seg
				var perp := Vector2(-t.y, t.x)
				while cur_s + seg >= next_s and next_s <= total_s - 3.5:
					var p := a.lerp(b, (next_s - cur_s) / seg)
					if absf(p.x) < EXT_HALF - 1.0 and absf(p.y) < EXT_HALF - 1.0 and not in_wet(p, 2.0) and not _on_bridge(p, 1.4) and _rail_dist(p) >= 3.4:
						var ed_all := _rg_edge_dist_ignore(_rg, p, ci, mates)
						var do_xw := w >= 8.5 and (next_s - last_xw) > 20.0 and _has_crossing_paved(pg, p, ci, mates, t, 4.4, 7.8)
						if do_xw:
							var n_stripes := int((w - 2.4) / 1.15)
							var half_span := float(n_stripes - 1) * 0.5 * 1.15
							for si in n_stripes:
								var off := -half_span + float(si) * 1.15
								var xp := p + perp * off
								xwalks.append(Transform3D(Basis(Vector3.UP, atan2(t.x, t.y)).scaled_local(Vector3(0.46, 0.016, 2.4)), Vector3(xp.x, 0.100, xp.y)))
							last_xw = next_s
						elif ed_all > 2.6:
							dashes.append(Transform3D(Basis(Vector3.UP, atan2(t.x, t.y)).scaled_local(Vector3(0.22, 0.016, 2.2)), Vector3(p.x, 0.100, p.y)))
					next_s += dash_step
				cur_s += seg
	for bm: Dictionary in bellmouths:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		for ic: PackedVector2Array in bm.inner_clip:
			var asph_ext := _offset_poly_smooth(ic, 0.35, bm.jp)
			if bool(bm.wide):
				polys_a.append_array(asph_ext)
			else:
				polys_b.append_array(asph_ext)
	# 人行道（带立体侧壁）+ 浅色路沿石：沿所有路面并集的边缘走，路口转角自动连成一圈，断头路绕成 U 形
	var clean_d: Array = []
	if not polys_d.is_empty():
		var dirt_r := WC._poly_rect(polys_d[0])
		for di_p in range(1, polys_d.size()):
			dirt_r = dirt_r.merge(WC._poly_rect(polys_d[di_p]))
		dirt_r = dirt_r.grow(2.5)
		var paved_cuts: Array = []
		var paved_cgrid := {}
		for ci in curves.size():
			var cv_p: Dictionary = curves[ci]
			if cv_p.dirt:
				continue
			var d_p: PackedVector2Array = cv_p.d
			if not dirt_r.intersects(WC._poly_rect(d_p).grow(float(cv_p.w) * 0.5 + 2.0)):
				continue
			var caps_p: Array = cv_p.get("caps", [false, false])
			for cp_poly: PackedVector2Array in _curve_band_polys(cv_p, WALK_W + 0.35, 0.05, dirt_r):
				_add_cut(paved_cuts, paved_cgrid, cp_poly)
			var cw0: float = maxf(1.0, float(cv_p.get("w0", cv_p.w)) * 0.5 - WALK_W - 0.35)
			var cw1: float = maxf(1.0, float(cv_p.get("w1", cv_p.w)) * 0.5 - WALK_W - 0.35)
			for cp_cap: PackedVector2Array in _cap_polys_ends(d_p, cw0, cw1, caps_p):
				if dirt_r.intersects(WC._poly_rect(cp_cap)):
					_add_cut(paved_cuts, paved_cgrid, cp_cap)
		for bm: Dictionary in bellmouths:
			if not dirt_r.intersects(Rect2(bm.jp, Vector2.ZERO).grow(24.0)):
				continue
			for ic: PackedVector2Array in bm.inner_clip:
				if not dirt_r.intersects(WC._poly_rect(ic)):
					continue
				for bc_cut: PackedVector2Array in _offset_poly_smooth(ic, -0.25, bm.jp):
					_add_cut(paved_cuts, paved_cgrid, bc_cut)
		for dp: PackedVector2Array in _merge_polys(polys_d):
			clean_d.append_array(_subtract_cuts(dp, paved_cuts, paved_cgrid, []))
	var na := _emit_dedup_polys(st_a, polys_a, 0.079, 0.0)
	var nb := _emit_dedup_polys(st_b, polys_b, 0.072, 0.0)
	var nar := _emit_dedup_polys(st_ar, polys_ar, 0.086, 0.0)
	var nd := _emit_soft_polys(st_d, clean_d, 1.35, 0.058)
	var nw := _build_walks(st_w, st_c, bellmouths)
	_st_commit(st_a, ASPH, na)
	_st_commit(st_b, ASPH2, nb)
	_st_commit(st_ar, ARUT, nar)
	_st_commit(st_d, DIRT, nd)
	_st_commit(st_r, RUT, nr)
	_st_commit(st_w, WALK, nw)
	_st_commit(st_c, CURB, nw)
	_multimesh(A.bevel_box(Vector3.ONE, 0.0), LINE, dashes, false)
	_multimesh(A.bevel_box(Vector3.ONE, 0.0), XWALK, xwalks, false)
	# 路面油渍（分块 MultiMesh 合批绘制，克制尺度与透明度，保持城市主干道整洁可读）
	var oil_xfs: Array = []
	for k in (24 if not curves.is_empty() else 0):
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		var p := _road_point(1.5)
		if in_wet(Vector2(p.x, p.z), 4.0) or zone_at(p) == "D":
			continue
		var sz_o := rng.randf_range(1.1, 2.1)
		var bs_o := Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(sz_o * rng.randf_range(0.8, 1.3), 1.0, sz_o * rng.randf_range(0.7, 1.2)))
		oil_xfs.append(Transform3D(bs_o, Vector3(p.x, 0.090, p.z)))
	if not oil_xfs.is_empty():
		_multimesh(A.quad(1.0, 1.0), A.decal_mat(A.grime_stain_tex(), Color(0.24, 0.235, 0.23, 0.14)), oil_xfs, false)


# ---------- 河流 / 干河床 / 桥 ----------
var bridges: Array = []   ## [Vector2 a, Vector2 b, width]


func _dense(pts: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var n := maxi(1, int(a.distance_to(b) / step))
		for i in n:
			out.append(a.lerp(b, float(i) / n))
	out.append(pts[pts.size() - 1])
	return out

func _strip_mesh(pts: PackedVector2Array, w: float, y: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for poly: PackedVector2Array in _offset_line(pts, w * 0.5, Geometry2D.END_ROUND):
		_emit_poly(st, poly, y, 0.0)
	st.index()
	st.generate_tangents()
	return st.commit()


func _strip_mesh_soft(pts: PackedVector2Array, w: float, y: float, feather_w: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var polys := _offset_line(pts, w * 0.5, Geometry2D.END_ROUND, 8.0)
	_emit_soft_polys(st, polys, feather_w, y)
	st.index()
	st.generate_tangents()
	return st.commit()

## 落在已建桥面上（河堤留口用）
func _on_bridge(p: Vector2, pad: float) -> bool:
	for b: Array in bridges:
		if WC.seg_dist(p, b[0], b[1]) < float(b[2]) * 0.5 + pad:
			return true
	return false


func _build_river() -> void:
	rng.seed = _map_seed(3)
	bridges.clear()
	for r: Dictionary in rivers:
		_build_one_river(r)


func _build_one_river(r: Dictionary) -> void:
	var rw: float = r.w
	var rp: PackedVector2Array = _smooth_pts(r.pts, 1) if r.dry else _smooth_pts(_river_in_lake_pts(r.pts, rw * 0.5), 2)
	var pts := _dense(rp, 2.0)
	if r.dry:
		# 干河床：三层柔边冲积砂砾过渡（外沿风化淤泥砾石带 → 砂砾二级阶地 → 粗砂卵石主河槽）+ 道路过河漫水混凝土桥涵
		var rp_vis := _bezier_refine_polyline(r.pts, Vector2.ZERO, Vector2.ZERO, 0.75, 1.25, 1.8, 0.004, Rect2(-215.0, -215.0, 430.0, 430.0))
		var m_outer: ShaderMaterial = _terrain_feather_mat(Color(0.28, 0.24, 0.19), 0.28, 0.94, 0.10, -12)
		var mi0 := MeshInstance3D.new()
		mi0.mesh = _strip_mesh_soft(rp_vis, rw + 10.5, 0.008, 3.2)
		mi0.material_override = m_outer
		mi0.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(mi0)
		var m_bank: ShaderMaterial = _terrain_feather_mat(Color(0.34, 0.29, 0.23), 0.30, 0.92, 0.12, -11)
		var mi := MeshInstance3D.new()
		mi.mesh = _strip_mesh_soft(rp_vis, rw + 4.6, 0.020, 1.8)
		mi.material_override = m_bank
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(mi)
		var m_bed: ShaderMaterial = _terrain_feather_mat(Color(0.43, 0.38, 0.30), 0.34, 0.90, 0.14, -10)
		var bed := MeshInstance3D.new()
		bed.mesh = _strip_mesh_soft(rp_vis, maxf(3.2, rw * 0.88), 0.032, 1.2)
		bed.material_override = m_bed
		bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(bed)
		# 铺装路跨越干河床处：在路面下方筑混凝土护基并在路肩外侧设低矮防撞墩与侧排涵管口（土路直接柔边融合，不盖混凝土块）
		var ford_hits: Array = []
		var M_FORD := A.concrete(Color(0.42, 0.40, 0.37), true)
		var M_CULV := A.metal(Color(0.18, 0.19, 0.21))
		for cv: Dictionary in curves:
			if cv.dirt:
				continue
			var cp: PackedVector2Array = cv.pts
			for ci in cp.size() - 1:
				for ki in rp.size() - 1:
					var hit = Geometry2D.segment_intersects_segment(cp[ci], cp[ci + 1], rp[ki], rp[ki + 1])
					if hit == null or absf(hit.x) > EXT_HALF + 48.0 or absf(hit.y) > EXT_HALF + 48.0:
						continue
					var dup_f := false
					for fh: Vector2 in ford_hits:
						if fh.distance_to(hit) < 16.0:
							dup_f = true
							break
					if dup_f:
						continue
					var cdir := (cp[ci + 1] - cp[ci]).normalized()
					var rdir := (rp[ki + 1] - rp[ki]).normalized()
					var sin_f := absf(cdir.cross(rdir))
					if sin_f < 0.42:
						continue
					ford_hits.append(hit)
					var fspan := clampf((rw + 3.0) / sin_f, 8.0, 24.0)
					var fn := Node3D.new()
					world.add_child(fn)
					fn.position = Vector3(hit.x, 0.0, hit.y)
					fn.rotation.y = atan2(cdir.x, cdir.y)
					var fw := float(cv.w) + 1.1
					A.add(fn, A.bevel_box(Vector3(fw, 0.10, fspan), 0.03), M_FORD, Vector3(0, 0.010, 0), Vector3.ZERO, Vector3.ONE, false)
					for sd_f in [-1.0, 1.0]:
						for bz_f in [-fspan * 0.34, fspan * 0.34]:
							A.add(fn, A.bevel_box(Vector3(0.28, 0.40, 0.34), 0.03), M_FORD, Vector3(sd_f * (fw * 0.5 - 0.14), 0.20, bz_f))
						for cz_f in [-1.1, 1.1]:
							A.add(fn, A.cyl(0.14, 0.55, 0.14, 12), M_CULV, Vector3(sd_f * (fw * 0.5 + 0.06), 0.02, cz_f), Vector3(0, 0, 90))
		var stones: Array = []
		for i in pts.size():
			if absf(pts[i].x) > EXT_HALF + 48.0 or absf(pts[i].y) > EXT_HALF + 48.0 or (is_surface_map and pts[i].x + WC.origin(map_id).x > WC.coast_x(pts[i].y + WC.origin(map_id).y) - 3.0):
				continue
			for k in 3:
				var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
				var p := pts[i] + Vector2(-t.y, t.x) * rng.randf_range(-0.62, 0.62) * rw
				if on_road(p, 1.2):
					continue
				var sc := rng.randf_range(0.15, 0.52)
				stones.append(Transform3D(_rand_basis(30).scaled_local(Vector3(sc * 1.3, sc * 0.5, sc)), Vector3(p.x, sc * 0.1, p.y)))
		var stone_m := A.rock_mat(Color(0.46, 0.42, 0.36))
		for pv in 3:
			var part: Array = []
			for si in range(pv, stones.size(), 3):
				part.append(stones[si])
			_multimesh(FM.pebble_mesh(pv), stone_m, part, false)
		for k in 18:
			var i := rng.randi_range(4, maxi(4, pts.size() - 5))
			if i >= pts.size():
				break
			var p := pts[i]
			var q := Vector3(p.x + rng.randf_range(-4, 4), 0, p.y + rng.randf_range(-4, 4))
			if in_bounds(q, 3.0) and not on_road(Vector2(q.x, q.z), 3.0) and not _blocked(q, 2.0, false):
				_boulder(q, rng.randf_range(1.2, 2.4))
		return
	# 桥：允许架桥的道路与铁路跨过湿河道处
	var segs: Array = []
	for cv: Dictionary in curves:
		if not cv.bridge:
			continue
		var pp: PackedVector2Array = cv.pts
		for i in pp.size() - 1:
			segs.append([pp[i], pp[i + 1], cv.w])
	for line: PackedVector2Array in rail_polys:
		for i in line.size() - 1:
			segs.append([line[i], line[i + 1], 4.6])
	for sg: Array in segs:
		for k in rp.size() - 1:
			var hit = Geometry2D.segment_intersects_segment(sg[0], sg[1], rp[k], rp[k + 1])
			if hit == null or absf(hit.x) > EXT_HALF + 48.0 or absf(hit.y) > EXT_HALF + 48.0:
				continue
			var dup := false
			for eb: Array in bridges:
				if ((eb[0] + eb[1]) * 0.5).distance_to(hit) < 14.0:
					dup = true
					break
			if dup:
				continue
			var rd := (rp[k + 1] - rp[k]).normalized()
			var dir: Vector2 = (sg[1] - sg[0]).normalized()
			var span := (rw + 6.0) / maxf(absf(dir.cross(rd)), 0.35) + 4.0
			_bridge(hit, dir, sg[2], span)
	# 河岸碰撞体（视觉上的泥岸、水面与连续混凝土护堤在 _build_lakes 里与湖泊统一合并生成，不留重叠接缝）
	var bank := StaticBody3D.new()
	bank.collision_layer = 8   # 河岸护堤：挡机甲与地面虫子（飞行种不挡）
	bank.collision_mask = 0
	bank.set_meta("water_bank", true)
	world.add_child(bank)
	var cpts := _dense(rp, 4.0)
	for sd in [-1.0, 1.0]:
		# 护堤碰撞沿岸线走，过桥处按桥面护栏的位置精确截断（护堤与护栏首尾相接，机甲挤不进水里）
		for i in cpts.size() - 1:
			var t0 := (cpts[mini(i + 1, cpts.size() - 1)] - cpts[maxi(i - 1, 0)]).normalized()
			var t1 := (cpts[mini(i + 2, cpts.size() - 1)] - cpts[i]).normalized()
			var a: Vector2 = cpts[i] + Vector2(-t0.y, t0.x) * sd * (rw * 0.5 + 0.4)
			var b: Vector2 = cpts[i + 1] + Vector2(-t1.y, t1.x) * sd * (rw * 0.5 + 0.4)
			var m := (a + b) * 0.5
			if (absf(m.x) > EXT_HALF + 8.0 or absf(m.y) > EXT_HALF + 8.0) if is_surface_map else (border_dist(m) < -8.0):
				continue
			for piece: Array in _bank_pieces(a, b):
				var pa: Vector2 = piece[0]
				var pb: Vector2 = piece[1]
				var pm := (pa + pb) * 0.5
				if in_lake(pm, 0.5):
					continue
				var ln := pa.distance_to(pb)
				if ln < 0.05:
					continue
				var tt := (pb - pa) / ln
				var bs := Basis(Vector3.UP, atan2(tt.x, tt.y))
				var cs := CollisionShape3D.new()
				var sh := BoxShape3D.new()
				sh.size = Vector3(1.0, 3.0, ln + 0.3)
				cs.shape = sh
				cs.transform = Transform3D(bs, Vector3(pm.x, 1.5, pm.y))
				bank.add_child(cs)
	# 河道在战区里断开（源头 / 尽头不在湖里、不在入海口、也不在地图外）：横着封一道护堤
	for e in 2:
		var p: Vector2 = rp[0] if e == 0 else rp[rp.size() - 1]
		var q: Vector2 = rp[1] if e == 0 else rp[rp.size() - 2]
		if (not is_surface_map and border_dist(p) < -4.0) or absf(p.x) > EXT_HALF + 40.0 or absf(p.y) > EXT_HALF + 40.0 or in_lake(p, 1.0) or zone_at(Vector3(p.x, 0, p.y)) in ["A", "B"]:
			continue
		var t := (p - q).normalized()
		var bs := Basis(Vector3.UP, atan2(-t.y, t.x))
		var c := p + t * 0.4
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(1.0, 3.0, rw + 1.8)
		cs.shape = sh
		cs.transform = Transform3D(bs, Vector3(c.x, 1.5, c.y))
		bank.add_child(cs)
	# 湿河道河防浮箱闸垒与岗哨灯塔（env_perimeter_pontoon）：避开桥梁与湖区，最多布设 2 处河道拦截点
	var pontoon_pts: Array = []
	for pi in range(6, cpts.size() - 6, 8):
		if pontoon_pts.size() >= 2:
			break
		var qp: Vector2 = cpts[pi]
		if not in_bounds_xz(qp, 24.0) or in_lake(qp, rw * 0.6 + 6.0):
			continue
		var near_br := false
		for eb: Array in bridges:
			if ((eb[0] + eb[1]) * 0.5).distance_to(qp) < 26.0:
				near_br = true
				break
		if near_br:
			continue
		var near_pt := false
		for op: Vector2 in pontoon_pts:
			if op.distance_to(qp) < 72.0:
				near_pt = true
				break
		if near_pt:
			continue
		var rt := (cpts[mini(pi + 1, cpts.size() - 1)] - cpts[maxi(pi - 1, 0)]).normalized()
		var pyaw := rad_to_deg(atan2(rt.x, rt.y))
		var pw := clampf(rw * 0.96, 8.6, 13.5)
		PrefabLib.place_at_ground(self, world, "env_perimeter_pontoon", Vector3(qp.x, -0.38, qp.y), pyaw, Vector3(pw, 7.6, 5.2), false, null, false)
		pontoon_pts.append(qp)


## 护堤线段 a→b 去掉落在桥面（到两侧护栏为止）里的部分，返回剩下的 [起点, 终点] 列表
func _bank_pieces(a: Vector2, b: Vector2) -> Array:
	var keep: Array = [Vector2(0.0, 1.0)]
	var d := b - a
	for br: Array in bridges:
		var s0: Vector2 = br[0]
		var s1: Vector2 = br[1]
		var ln := s0.distance_to(s1)
		if ln < 0.01:
			continue
		var u := (s1 - s0) / ln
		var v := Vector2(-u.y, u.x)
		var hw := float(br[2]) * 0.5 + 0.2
		var au := (a - s0).dot(u)
		var av := (a - s0).dot(v)
		var du := d.dot(u)
		var dv := d.dot(v)
		# Liang–Barsky：0 ≤ 沿桥 ≤ ln，|横向| ≤ hw
		var t0 := 0.0
		var t1 := 1.0
		var hit := true
		for c: Vector2 in [Vector2(-du, au), Vector2(du, ln - au), Vector2(-dv, av + hw), Vector2(dv, hw - av)]:
			if absf(c.x) < 1e-9:
				if c.y < 0.0:
					hit = false
					break
				continue
			var t := c.y / c.x
			if c.x < 0.0:
				t0 = maxf(t0, t)
			else:
				t1 = minf(t1, t)
		if not hit or t0 >= t1:
			continue
		var nxt: Array = []
		for iv: Vector2 in keep:
			if t1 <= iv.x or t0 >= iv.y:
				nxt.append(iv)
				continue
			if t0 > iv.x:
				nxt.append(Vector2(iv.x, t0))
			if t1 < iv.y:
				nxt.append(Vector2(t1, iv.y))
		keep = nxt
	var out: Array = []
	for iv: Vector2 in keep:
		out.append([a + d * iv.x, a + d * iv.y])
	return out


func _bridge(hp: Vector2, dir: Vector2, w: float, span: float) -> void:
	var DECK := A.concrete(Color(0.42, 0.40, 0.38), true)
	var ASPH: ShaderMaterial = A.asphalt(Color(0.20, 0.205, 0.215)).duplicate()
	var LINE := A.paint(Color(0.82, 0.72, 0.42), 0.0, 0.85, {"wear": 0.65, "dust": 0.35, "panel_scale": 0.0})
	var CURB := A.concrete(Color(0.54, 0.52, 0.48), false)
	var GIRDER := A.metal(Color(0.18, 0.19, 0.20))
	var RAIL := A.paint(Color(0.36, 0.34, 0.30), 0.62, 0.55, {"rust": 0.65, "wear": 0.48, "panel_scale": 0.0})
	bridges.append([hp - dir * span * 0.5, hp + dir * span * 0.5, w])
	var is_rail := w < 5.2
	var ang := atan2(dir.x, dir.y)
	var root := Node3D.new()
	world.add_child(root)
	root.position = Vector3(hp.x, 0, hp.y)
	root.rotation.y = ang
	# 混凝土主桥面板 + 两端缓坡桥头搭板（公路桥铺沥青与标线；铁路桥改为钢混道槽桥面板）
	A.add(root, A.bevel_box(Vector3(w + 0.9, 0.34, span + 0.4), 0.06), DECK, Vector3(0, 0.09, 0))
	for end_s in [-1.0, 1.0]:
		A.add(root, A.bevel_box(Vector3(w + 0.85, 0.18, 2.2), 0.03), DECK, Vector3(0, 0.08, end_s * (span * 0.5 + 0.95)), Vector3(end_s * 5.8, 0, 0), Vector3.ONE, false)
	if is_rail:
		A.add(root, A.bevel_box(Vector3(maxf(2.8, w - 0.9), 0.04, span + 0.3), 0.01), GIRDER, Vector3(0, 0.265, 0), Vector3.ZERO, Vector3.ONE, false)
	else:
		A.add(root, A.bevel_box(Vector3(maxf(2.0, w - 0.7), 0.05, span + 0.4), 0.01), ASPH, Vector3(0, 0.27, 0), Vector3.ZERO, Vector3.ONE, false)
		for end_s in [-1.0, 1.0]:
			A.add(root, A.bevel_box(Vector3(maxf(2.0, w - 0.65), 0.05, 2.3), 0.01), ASPH, Vector3(0, 0.165, end_s * (span * 0.5 + 1.02)), Vector3(end_s * 5.8, 0, 0), Vector3.ONE, false)
		if w >= 6.5:
			var d_step := 5.2 if w >= 10.0 else 6.0
			var nd_br := maxi(1, int((span - 2.0) / d_step))
			for di in nd_br:
				var dz := -span * 0.5 + 1.8 + (float(di) + 0.5) * (span - 3.6) / float(nd_br)
				A.add(root, A.bevel_box(Vector3(0.22, 0.02, 2.2), 0.0), LINE, Vector3(0, 0.302, dz), Vector3.ZERO, Vector3.ONE, false)
	for sd_g in [-1.0, 1.0]:
		A.add(root, A.bevel_box(Vector3(0.42, 0.16, span + 0.3), 0.03), CURB, Vector3(sd_g * (w * 0.5 - 0.05), 0.33, 0))
		A.add(root, A.bevel_box(Vector3(0.32, 0.56, span - 0.4), 0.02), GIRDER, Vector3(sd_g * (w * 0.5 + 0.18), -0.28, 0))
	if span > 9.5:
		var n_piers := maxi(1, int(span / 10.5))
		for pi in n_piers:
			var pz := -span * 0.5 + span * float(pi + 1) / float(n_piers + 1)
			A.add(root, A.bevel_box(Vector3(w + 1.3, 0.38, 1.15), 0.05), DECK, Vector3(0, -0.42, pz))
			for px_s in [-1.0, 1.0]:
				A.add(root, A.cyl(0.48, 2.2, 0.56, 14), CURB, Vector3(px_s * (w * 0.36), -1.45, pz))
	for sd in [-1.0, 1.0]:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.28, 1.15, span)
		cs.shape = sh
		sb.add_child(cs)
		root.add_child(sb)
		sb.position = Vector3(sd * (w * 0.5 + 0.24), 0.78, 0)
		A.add(sb, A.bevel_box(Vector3(0.26, 0.13, span), 0.02), RAIL, Vector3(0, 0.52, 0))
		A.add(sb, A.bevel_box(Vector3(0.22, 0.11, span), 0.02), RAIL, Vector3(0, 0.08, 0))
		for ez in [-span * 0.5 + 0.28, span * 0.5 - 0.28]:
			A.add(sb, A.bevel_box(Vector3(0.48, 1.28, 0.56), 0.04), CURB, Vector3(0, 0.06, ez))
			A.add(sb, A.bevel_box(Vector3(0.50, 0.18, 0.58), 0.02), A.hazard(), Vector3(0, 0.42, ez))
		var n := maxi(2, int(span / 2.0))
		for q in n + 1:
			A.add(sb, A.bevel_box(Vector3(0.15, 1.12, 0.15), 0.02), RAIL, Vector3(0, 0, -span * 0.5 + q * span / n))
		var side: Vector2 = Vector2(dir.y, -dir.x) * sd * (w * 0.5 + 0.24)
		for q in 5:
			var pp: Vector2 = hp + side + dir * (-span * 0.5 + span * (q + 0.5) / 5.0)
			blocks.append(Rect2(pp.x - 0.6, pp.y - 0.6, 1.2, 1.2))


static var _water_shader: Shader
func _water_mat() -> ShaderMaterial:
	if _water_shader == null:
		_water_shader = Shader.new()
		_water_shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;
	uniform sampler2D n_low : filter_linear_mipmap, repeat_enable;
	uniform sampler2D n_hi : filter_linear_mipmap, repeat_enable;
	uniform sampler2D n_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
	global uniform float weather_rain;
	global uniform vec3 sun_dir_world;
	varying vec3 wp;
	void vertex() {
		wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	}
	void fragment() {
		vec2 p = wp.xz;
		float t = TIME * 0.18;
		float gust = smoothstep(0.26, 0.74, texture(n_low, p * 0.0052 + vec2(t * 0.028, -t * 0.019)).r);
		float w1 = texture(n_low, p * 0.016 + vec2(t * 0.07, t * 0.04)).r;
		float w2 = texture(n_low, p * 0.038 - vec2(t * 0.05, -t * 0.06) + 0.37).r;
		float w3 = texture(n_hi, p * 0.085 + vec2(t * 0.09, -t * 0.07)).r;
		float wave = w1 * 0.45 + w2 * 0.35 + w3 * 0.2;
		// 线性空间写实浑浊工业江水：深航道暗青灰 -> 浅滩橄榄淤泥青，避免粉蓝油漆感
		vec3 deep = vec3(0.010, 0.024, 0.030);
		vec3 mid = vec3(0.020, 0.044, 0.048);
		vec3 shallow = vec3(0.036, 0.052, 0.042);
		vec3 crest = vec3(0.055, 0.088, 0.094);
		vec3 foam_col = vec3(0.28, 0.33, 0.35);
		float fw = length(fwidth(p));
		float fade = clamp(1.0 - fw * 1.6, 0.0, 1.0);
		float ripple = smoothstep(0.54, 0.76, w2 * 0.55 + w3 * 0.45) * (0.45 + 0.55 * gust) * fade;
		float foam = smoothstep(0.76, 0.88, w2 * 0.5 + w3 * 0.5) * gust * fade;
		float depth_m = smoothstep(0.04, 0.78, clamp(COLOR.a + (w1 - 0.5) * 0.22 * sin(COLOR.a * 3.14159), 0.0, 1.0));
		float shore = smoothstep(0.02, 0.32, clamp(COLOR.a + (w1 - 0.5) * 0.28 * sin(COLOR.a * 3.14159), 0.0, 1.0));
		float shore_foam = (1.0 - smoothstep(0.06, 0.52, shore)) * smoothstep(0.36, 0.80, w2 * 0.6 + w3 * 0.4);
		vec3 col = mix(shallow, mix(deep, mid, smoothstep(0.26, 0.74, wave)), depth_m) * mix(0.88, 1.08, gust);
		col = mix(col, crest, ripple * 0.36);
		col = mix(col, foam_col, clamp(foam * 0.24 + shore_foam * 0.26, 0.0, 0.55));
		vec3 n1 = texture(n_nrm, p * 0.09 + vec2(t * 0.11, t * 0.07)).rgb;
		vec3 n2 = texture(n_nrm, p * 0.21 - vec2(t * 0.08, -t * 0.09) + 0.41).rgb;
		float rain_chop = clamp(weather_rain, 0.0, 1.0) * (texture(n_hi, p * 1.35 + vec2(TIME * 0.7, -TIME * 0.55)).r - 0.5) * 0.35 * fade;
		vec3 wn = normalize(vec3((n1.x + n2.x - 1.0) * 0.35 + rain_chop, 1.0, (n1.y + n2.y - 1.0) * 0.35 - rain_chop));
		float fres = 0.02 + 0.98 * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.5);
		vec3 eye_dir = normalize(wp - INV_VIEW_MATRIX[3].xyz);
		vec3 sun_d = length(sun_dir_world) > 1e-3 ? normalize(sun_dir_world) : normalize(vec3(0.45, 0.62, 0.64));
		float sun_glint = pow(max(dot(reflect(eye_dir, wn), sun_d), 0.0), 36.0);
		col = mix(col, vec3(0.09, 0.13, 0.16), fres * 0.58);
		col += vec3(0.26, 0.24, 0.20) * sun_glint * (0.45 + 0.55 * fade);
		ALBEDO = col;
		ALPHA = clamp(mix(0.72, 0.96, depth_m) * shore, 0.0, 0.97);
		NORMAL_MAP = normalize(mix(n1, n2, 0.5) * 2.0 - 1.0 + vec3(rain_chop, -rain_chop, mix(2.2, 1.35, gust))) * 0.5 + 0.5;
		NORMAL_MAP_DEPTH = (0.52 + gust * 0.44 + ripple * 0.45) * fade;
		ROUGHNESS = clamp(mix(0.08, 0.22, gust * 0.65 + ripple * 0.35) + foam * 0.36 + (1.0 - fade) * 0.16, 0.075, 0.78);
		METALLIC = 0.04;
		SPECULAR = 0.68;
		CLEARCOAT = (1.0 - foam) * 0.46;
		CLEARCOAT_ROUGHNESS = mix(0.08, 0.20, gust);
	}
"""
	var m := ShaderMaterial.new()
	m.shader = _water_shader
	m.render_priority = -6
	m.set_shader_parameter("n_low", A.noise_tex("grime_raw", 512))
	m.set_shader_parameter("n_hi", A.noise_tex("hi_raw", 512))
	m.set_shader_parameter("n_nrm", A.noise_tex("ground_n", 512))
	m.set_meta("no_outline", true)
	return m


# ---------- 湖与河湖统一水面 / 护堤 ----------
## 河道端点若落在自然湖泊里，顺延到湖心以内 lr - hw - 2.2 米处，保证河道全宽与两侧护堤都完全收进自然分湾湖面内，不留侧面露头接缝
func _river_in_lake_pts(pts: PackedVector2Array, hw: float) -> PackedVector2Array:
	var rp := pts.duplicate()
	for e in 2:
		var idx := 0 if e == 0 else rp.size() - 1
		var p: Vector2 = rp[idx]
		for l: Vector3 in lakes:
			var lc := Vector2(l.x, l.y)
			var d := p.distance_to(lc)
			var lr := WC.lake_radius(l, atan2(p.y - lc.y, p.x - lc.x)) if d > 0.01 else l.z
			if d < lr + 4.5 and d > 0.01:
				var keep_r := maxf(0.0, lr - hw - 2.2)
				if d > keep_r:
					rp[idx] = lc + (p - lc) / d * keep_r
				break
	return rp


## 按分湾湖泊轮廓生成两半闭合岸带环（避免带洞多边形，直接走 Clipper 布尔裁剪）
func _lake_ring_halves(l: Vector3, w_bank: float, segs := 56) -> Array:
	var inner := WC.lake_poly(l, segs, -0.02)
	var outer := WC.lake_poly(l, segs, w_bank)
	var m := inner.size()
	var mid := m / 2
	var out: Array = []
	for half in 2:
		var i0 := 0 if half == 0 else mid
		var i1 := mid if half == 0 else m
		var ring := PackedVector2Array()
		for i in range(i0, i1 + 1):
			ring.append(outer[i % m])
		for i in range(i1, i0 - 1, -1):
			ring.append(inner[i % m])
		out.append(ring)
	return out


func _build_wet_surfaces() -> void:
	var wet_rivers: Array = []
	for r: Dictionary in rivers:
		if not r.dry and (r.pts as PackedVector2Array).size() >= 2:
			wet_rivers.append(r)
	if wet_rivers.is_empty() and lakes.is_empty():
		return
	var mud_polys: Array = []
	var shingle_polys: Array = []
	var water_polys: Array = []
	var near_w := Rect2(-215.0, -215.0, 430.0, 430.0)
	for r: Dictionary in wet_rivers:
		var hw := float(r.w) * 0.5
		var rp_soft := _bezier_refine_polyline(_river_in_lake_pts(r.pts, hw), Vector2.ZERO, Vector2.ZERO, 0.75, 1.25, 1.8, 0.004, near_w)
		shingle_polys.append_array(_offset_line(rp_soft, hw + 5.6, Geometry2D.END_ROUND, 8.0))
		mud_polys.append_array(_offset_line(rp_soft, hw + 2.9, Geometry2D.END_ROUND, 8.0))
		water_polys.append_array(_offset_line(rp_soft, hw + 0.35, Geometry2D.END_ROUND, 8.0))
	for l: Vector3 in lakes:
		shingle_polys.append(WC.lake_poly(l, 180, 5.8))
		mud_polys.append(WC.lake_poly(l, 180, 3.0))
		water_polys.append(WC.lake_poly(l, 180, 0.35))
	var st_shingle := SurfaceTool.new()
	var st_mud := SurfaceTool.new()
	var st_water := SurfaceTool.new()
	var st_bank := SurfaceTool.new()
	var st_lip := SurfaceTool.new()
	for st in [st_shingle, st_mud, st_water, st_bank, st_lip]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ns := _emit_soft_polys(st_shingle, _merge_polys(shingle_polys), 2.6, 0.015)
	var nm := _emit_soft_polys(st_mud, _merge_polys(mud_polys), 1.6, 0.028)
	var nw := _emit_soft_polys(st_water, _merge_polys(water_polys), 0.95, 0.052)
	# 岸线区分硬化城区驳岸与自然生态缓坡岸：城区/港区/工业区（D/R/I/H/Y/M）砌筑连续混凝土防洪堤；郊野/林地/湿地/湖湾保持自然砂砾卵石缓坡，彻底消除荒野水体套水泥圈的生硬感
	var lim := Rect2(-EXT_HALF - 56.0, -EXT_HALF - 56.0, EXT_HALF * 2.0 + 112.0, EXT_HALF * 2.0 + 112.0)
	var cuts: Array = []
	var cgrid := {}
	var r_bands: Array = []
	var r_ends: Array = []
	for r: Dictionary in wet_rivers:
		var hw := float(r.w) * 0.5
		var rp := _bezier_refine_polyline(_river_in_lake_pts(r.pts, hw), Vector2.ZERO, Vector2.ZERO, 0.45, 0.75, 1.15, 0.0022, near_w)
		for ch: PackedVector2Array in _chunks(rp):
			if not lim.intersects(WC._poly_rect(ch).grow(hw + 2.0)):
				continue
			var own: Array = []
			for poly: PackedVector2Array in _offset_line(_ext_line(ch, 0.08), hw):
				own.append(_add_cut(cuts, cgrid, poly))
			r_bands.append([ch, hw, own])
		var orig: PackedVector2Array = r.pts
		for e in 2:
			var p: Vector2 = orig[0] if e == 0 else orig[orig.size() - 1]
			var q: Vector2 = orig[1] if e == 0 else orig[orig.size() - 2]
			if absf(p.x) <= EXT_HALF + 40.0 and absf(p.y) <= EXT_HALF + 40.0 and not in_lake(p, 4.0) and not (zone_at(Vector3(p.x, 0, p.y)) in ["A", "B"]):
				r_ends.append([p, (p - q).normalized(), hw])
	for l: Vector3 in lakes:
		_add_cut(cuts, cgrid, WC.lake_poly(l, 180, -0.03))
	for br: Array in bridges:
		for poly: PackedVector2Array in _offset_line(_ext_line(PackedVector2Array([br[0], br[1]]), 0.1), float(br[2]) * 0.5 + 0.2):
			_add_cut(cuts, cgrid, poly)
	var nb := 0
	var urban_zones := ["D", "R", "I", "H", "Y", "M"]
	for layer in [[st_bank, 0.85, 0.26, 0.26], [st_lip, 0.26, 0.305, 0.045]]:
		var st: SurfaceTool = layer[0]
		var w_bank: float = layer[1]
		var lcuts := cuts.duplicate()
		var lcgrid := cgrid.duplicate(true)
		for b: Array in r_bands:
			var hw: float = b[1]
			for outer: PackedVector2Array in _offset_line(b[0], hw + w_bank):
				for piece: PackedVector2Array in _subtract_cuts(outer, lcuts, lcgrid, b[2]):
					var pc := WC.centroid(piece)
					if zone_at(Vector3(pc.x, 0, pc.y)) in urban_zones:
						_emit_poly(st, piece, layer[2], layer[3])
						_add_cut(lcuts, lcgrid, piece)
						nb += 1
		for e: Array in r_ends:
			var hw: float = e[2]
			var ring := _half_ring(e[0], e[1], hw, hw + w_bank, 32)
			for piece: PackedVector2Array in _subtract_cuts(ring, lcuts, lcgrid, []):
				var pc := WC.centroid(piece)
				if zone_at(Vector3(pc.x, 0, pc.y)) in urban_zones:
					_emit_poly(st, piece, layer[2], layer[3])
					_add_cut(lcuts, lcgrid, piece)
					nb += 1
		for l: Vector3 in lakes:
			for ring: PackedVector2Array in _lake_ring_halves(l, w_bank, 180):
				for piece: PackedVector2Array in _subtract_cuts(ring, lcuts, lcgrid, []):
					var pc := WC.centroid(piece)
					if zone_at(Vector3(pc.x, 0, pc.y)) in urban_zones:
						_emit_poly(st, piece, layer[2], layer[3])
						_add_cut(lcuts, lcgrid, piece)
						nb += 1
	var SHINGLE: ShaderMaterial = _terrain_feather_mat(Color(0.28, 0.25, 0.21), 0.30, 0.90, 0.14, -8)
	var MUD: ShaderMaterial = _terrain_feather_mat(Color(0.17, 0.16, 0.14), 0.36, 0.62, 0.32, -7)
	var BANK := A.concrete(Color(0.46, 0.44, 0.41), true)
	var LIP := A.concrete(Color(0.55, 0.53, 0.48), false)
	_st_commit(st_shingle, SHINGLE, ns)
	_st_commit(st_mud, MUD, nm)
	_st_commit(st_water, _water_mat(), nw)
	_st_commit(st_bank, BANK, nb)
	_st_commit(st_lip, LIP, nb)


func _build_lakes() -> void:
	rng.seed = _map_seed(4)
	_build_wet_surfaces()
	# 自然河湖岸线散置抛石护岸块石（非城区段压接水面与砂砾岸线接缝）
	var shore_rocks: Array = []
	var urban_zones := ["D", "R", "I", "H", "Y", "M"]
	for r: Dictionary in rivers:
		if r.dry:
			continue
		var rpts := _dense(_river_in_lake_pts(r.pts, float(r.w) * 0.5), 3.5)
		var hw := float(r.w) * 0.5
		for i in rpts.size():
			var t := (rpts[mini(i + 1, rpts.size() - 1)] - rpts[maxi(i - 1, 0)]).normalized()
			var nn := Vector2(-t.y, t.x)
			for sd: float in [-1.0, 1.0]:
				if rng.randf() > 0.48:
					continue
				var sp: Vector2 = rpts[i] + nn * sd * (hw + rng.randf_range(0.15, 1.35))
				if absf(sp.x) > EXT_HALF or absf(sp.y) > EXT_HALF or on_road(sp, 1.8) or _on_bridge(sp, 1.5):
					continue
				if not (zone_at(Vector3(sp.x, 0, sp.y)) in urban_zones):
					var sc := rng.randf_range(0.35, 0.95)
					shore_rocks.append(Transform3D(_rand_basis(22).scaled_local(Vector3(sc * 1.35, sc * 0.52, sc)), Vector3(sp.x, sc * 0.14, sp.y)))
	if lakes.is_empty():
		_multimesh(A.rock_mesh(3), A.rock_mat(Color(0.34, 0.31, 0.27)), shore_rocks)
		return
	var bank := StaticBody3D.new()
	bank.collision_layer = 8
	bank.collision_mask = 0
	bank.set_meta("water_bank", true)   # 河湖整体（原点在世界中心）：遗迹清场（landmarks._clear_aprons）不能把它当杂物删掉
	world.add_child(bank)
	# 自然分湾湖岸碰撞：沿 WC.lake_poly 精确围合封闭多边形岸墙（加湖心圆柱兜底），机甲可贴近不规则湖湾且 0 漏水
	for l: Vector3 in lakes:
		if (absf(l.x) > EXT_HALF + l.z + 12.0 or absf(l.y) > EXT_HALF + l.z + 12.0) if is_surface_map else (border_dist(Vector2(l.x, l.y)) < -l.z * 1.4 - 12.0):
			continue
		var cs_core := CollisionShape3D.new()
		var sh_core := CylinderShape3D.new()
		sh_core.radius = maxf(2.0, l.z * 0.68)
		sh_core.height = 3.0
		cs_core.shape = sh_core
		cs_core.position = Vector3(l.x, 1.5, l.y)
		bank.add_child(cs_core)
		var lpoly := WC.lake_poly(l, 160, 0.45)
		var m := lpoly.size()
		for i in m:
			var pa := lpoly[i]
			var pb := lpoly[(i + 1) % m]
			var pm := (pa + pb) * 0.5
			if ((absf(pm.x) > EXT_HALF + 8.0 or absf(pm.y) > EXT_HALF + 8.0) if is_surface_map else (border_dist(pm) < -10.0)) or _on_bridge(pm, -0.1):
				continue
			var ln := pa.distance_to(pb)
			if ln < 0.05:
				continue
			var tt := (pb - pa) / ln
			var bs := Basis(Vector3.UP, atan2(tt.x, tt.y))
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = Vector3(1.15, 3.0, ln + 0.42)
			cs.shape = sh
			cs.transform = Transform3D(bs, Vector3(pm.x, 1.5, pm.y))
			bank.add_child(cs)
	var reeds: Array = []
	for li in lakes.size():
		var l: Vector3 = lakes[li]
		var n := maxi(12, int(TAU * l.z / 3.2))
		for i in n:
			var a := TAU * (i + 0.5) / n
			var d := Vector2(cos(a), sin(a))
			var lr := WC.lake_radius(l, a)
			var p := Vector2(l.x, l.y) + d * (lr + 0.85)
			if not (zone_at(Vector3(p.x, 0, p.y)) in urban_zones) and rng.randf() < 0.45 and not on_road(p, 1.5):
				var sc_r := rng.randf_range(0.42, 1.10)
				var rp_r := Vector2(l.x, l.y) + d * (lr + rng.randf_range(-0.1, 1.2))
				shore_rocks.append(Transform3D(_rand_basis(20).scaled_local(Vector3(sc_r * 1.35, sc_r * 0.50, sc_r)), Vector3(rp_r.x, sc_r * 0.14, rp_r.y)))
			var t := Vector2(-d.y, d.x)
			for k in 3:
				if rng.randf() < 0.5:
					var rp := p + d * rng.randf_range(0.5, 2.5) + t * rng.randf_range(-1.5, 1.5)
					if in_wet(rp, 1.0) or on_road(rp, 0.5):
						continue
					var hh := rng.randf_range(0.52, 1.15)
					reeds.append(Transform3D(_rand_basis(8).scaled_local(Vector3(hh * 0.85, hh, hh * 0.85)), Vector3(rp.x, 0.0, rp.y)))
	_multimesh(A.rock_mesh(3), A.rock_mat(Color(0.34, 0.31, 0.27)), shore_rocks)
	_multimesh(A.grass_clump_mesh(), A.foliage_mat("grass"), reeds, false)

func _strip_off(pts: PackedVector2Array, w: float, off: float, y: float) -> ArrayMesh:
	var q := PackedVector2Array()
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		q.append(pts[i] + Vector2(-t.y, t.x) * off)
	return _strip_mesh(q, w, y)

func _rail_bridge_lift(p: Vector2) -> float:
	var best := 0.0
	for br: Array in bridges:
		var b0: Vector2 = br[0]
		var b1: Vector2 = br[1]
		var span := b0.distance_to(b1)
		if span < 0.2:
			continue
		var hw := float(br[2]) * 0.5 + 0.6
		var u := (b1 - b0) / span
		var v := Vector2(-u.y, u.x)
		var q := p - (b0 + b1) * 0.5
		if absf(q.dot(v)) > hw:
			continue
		var au := absf(q.dot(u))
		var half := span * 0.5
		if au <= half:
			best = maxf(best, 0.175)
		elif au < half + 2.2:
			best = maxf(best, 0.175 * (1.0 - (au - half) / 2.2))
	return best


# ---------- 铁轨 ----------
func _build_rails() -> void:
	rng.seed = _map_seed(5)
	if rail_polys.is_empty():
		return
	var lim_rail := Rect2(-EXT_HALF - 48.0, -EXT_HALF - 48.0, EXT_HALF * 2.0 + 96.0, EXT_HALF * 2.0 + 96.0)
	var near_rail := Rect2(-215.0, -215.0, 430.0, 430.0)
	var rail_rs: Array[Rect2] = []
	for rl: PackedVector2Array in rail_polys:
		var rr := WC._poly_rect(rl).grow(4.0)
		if lim_rail.intersects(rr):
			rail_rs.append(rr.intersection(lim_rail))
	if rail_rs.is_empty():
		return
	var touches_rail := func(rc: Rect2) -> bool:
		for rr: Rect2 in rail_rs:
			if rc.intersects(rr):
				return true
		return false
	var pg := _paved_seg_grid()
	var cut_polys: Array = []
	var cut_cgrid := {}
	for cv: Dictionary in curves:
		if cv.dirt:
			continue
		var cw := float(cv.w) * 0.5 + 0.15
		if not touches_rail.call(WC._poly_rect(cv.pts).grow(cw + 1.0)):
			continue
		var cd: PackedVector2Array = cv.d
		for ch: PackedVector2Array in _chunks(cd):
			if not touches_rail.call(WC._poly_rect(ch).grow(cw + 0.5)):
				continue
			for cp_poly: PackedVector2Array in _offset_line(_ext_line(ch, 0.05), cw, Geometry2D.END_BUTT, 8.0):
				_add_cut(cut_polys, cut_cgrid, cp_poly)
		for cp_cap: PackedVector2Array in _cap_polys(cd, cw, cv.get("caps", [false, false])):
			if touches_rail.call(WC._poly_rect(cp_cap)):
				_add_cut(cut_polys, cut_cgrid, cp_cap)
	for br: Array in bridges:
		var b0: Vector2 = br[0]
		var b1: Vector2 = br[1]
		var bln := b0.distance_to(b1)
		if bln < 0.1:
			continue
		var bw := float(br[2]) * 0.5 + 0.5
		if not touches_rail.call(Rect2(b0, Vector2.ZERO).expand(b1).grow(bw + 0.5)):
			continue
		var bdir := (b1 - b0) / bln
		for bp_poly: PackedVector2Array in _offset_line(PackedVector2Array([b0 - bdir * 0.4, b1 + bdir * 0.4]), bw, Geometry2D.END_BUTT, 8.0):
			_add_cut(cut_polys, cut_cgrid, bp_poly)
	var ties: Array = []
	var rails: Array = []
	var x_slabs: Array = []
	var x_guards: Array = []
	var x_haz: Array = []
	var raw_ballast: Array = []
	var tie_grid := {}
	const T_CELL := 2.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for raw_line: PackedVector2Array in rail_polys:
		if not lim_rail.intersects(WC._poly_rect(raw_line).grow(4.0)):
			continue
		var smooth_rail := _bezier_refine_polyline(raw_line, Vector2.ZERO, Vector2.ZERO, 0.50, 0.85, 1.2, 0.0025, near_rail)
		for ch: PackedVector2Array in _chunks(smooth_rail):
			if lim_rail.intersects(WC._poly_rect(ch).grow(2.5)):
				raw_ballast.append_array(_offset_line(_ext_line(ch, 0.05), 1.8, Geometry2D.END_BUTT, 8.0))
		var line := _dense(smooth_rail, 1.2)
		var cur_ts := 0.0
		var next_ts := 0.45
		for k in line.size() - 1:
			var a := line[k]
			var b := line[k + 1]
			var seg := a.distance_to(b)
			if seg < 0.05:
				continue
			var t := (b - a) / seg
			var nrm := Vector2(-t.y, t.x)
			var ang := atan2(t.x, t.y)
			var m := (a + b) * 0.5
			if not lim_rail.has_point(m):
				cur_ts += seg
				while next_ts <= cur_ts:
					next_ts += 0.90
				continue
			var on_paved := pg.edge_dist(m) < 0.35
			var lift_a := _rail_bridge_lift(a)
			var lift_b := _rail_bridge_lift(b)
			var lift_m := (lift_a + lift_b) * 0.5
			var d3 := Vector3(b.x, lift_b, b.y) - Vector3(a.x, lift_a, a.y)
			var len3 := maxf(0.05, d3.length())
			var z_ax := d3 / len3
			var x_ax := Vector3.UP.cross(z_ax).normalized()
			if x_ax.length_squared() < 1e-4:
				x_ax = Vector3(nrm.x, 0.0, nrm.y)
			var y_ax := z_ax.cross(x_ax).normalized()
			var bs3 := Basis(x_ax, y_ax, z_ax)
			while next_ts <= cur_ts + seg:
				var p := a.lerp(b, (next_ts - cur_ts) / seg)
				next_ts += 0.90
				if on_paved or pg.edge_dist(p) < 0.2:
					continue
				var gx := floori(p.x / T_CELL)
				var gz := floori(p.y / T_CELL)
				var dup_t := false
				for dx in range(-1, 2):
					for dz in range(-1, 2):
						var bucket = tie_grid.get(Vector2i(gx + dx, gz + dz))
						if bucket != null:
							for tp: Vector2 in bucket:
								if tp.distance_squared_to(p) < 0.75 * 0.75:
									dup_t = true
									break
						if dup_t:
							break
					if dup_t:
						break
				if not dup_t:
					var cell_k := Vector2i(gx, gz)
					if tie_grid.has(cell_k):
						tie_grid[cell_k].append(p)
					else:
						tie_grid[cell_k] = [p]
					var plift := _rail_bridge_lift(p)
					ties.append(Transform3D(Basis(Vector3.UP, ang).scaled_local(Vector3(2.6, 0.12, 0.28)), Vector3(p.x, 0.135 + plift, p.y)))
			cur_ts += seg
			for sd in [-0.72, 0.72]:
				var q: Vector2 = m + nrm * sd
				if on_paved and lift_m < 0.01:
					rails.append(Transform3D(bs3.scaled_local(Vector3(0.08, 0.036, maxf(0.1, len3 - 0.01))), Vector3(q.x, 0.086, q.y)))
				else:
					rails.append(Transform3D(bs3.scaled_local(Vector3(0.1, 0.12, maxf(0.1, len3 - 0.01))), Vector3(q.x, 0.225 + lift_m, q.y)))
	var ballast_polys: Array = []
	for bp: PackedVector2Array in raw_ballast:
		ballast_polys.append_array(_subtract_cuts(bp, cut_polys, cut_cgrid, []))
	# 公路与铁路平交道口：铺设预制重工混凝土道口铺面板、钢制护轮轨与迎车警示护边
	var crossing_hits: Array = []
	for cv: Dictionary in curves:
		if cv.dirt:
			continue
		var cp: PackedVector2Array = cv.pts
		for line: PackedVector2Array in rail_polys:
			for ci in cp.size() - 1:
				for ri in line.size() - 1:
					var hit = Geometry2D.segment_intersects_segment(cp[ci], cp[ci + 1], line[ri], line[ri + 1])
					if hit == null or absf(hit.x) > EXT_HALF + 48.0 or absf(hit.y) > EXT_HALF + 48.0:
						continue
					if in_wet(hit, 2.0) or _on_bridge(hit, 1.0):
						continue
					var dup_x := false
					for eh: Vector2 in crossing_hits:
						if eh.distance_to(hit) < 9.0:
							dup_x = true
							break
					if dup_x:
						continue
					crossing_hits.append(hit)
					var cdir := (cp[ci + 1] - cp[ci]).normalized()
					var rdir := (line[ri + 1] - line[ri]).normalized()
					var rperp := Vector2(-rdir.y, rdir.x)
					var sin_a := clampf(absf(rdir.cross(cdir)), 0.45, 1.0)
					var pad_len := clampf((float(cv.w) - 1.6) / sin_a, maxf(2.4, float(cv.w) - 1.6), float(cv.w) + 5.0)
					var xbs := Basis(Vector3.UP, atan2(rdir.x, rdir.y))
					x_slabs.append(Transform3D(xbs.scaled_local(Vector3(1.18, 0.026, pad_len)), Vector3(hit.x, 0.077, hit.y)))
					for sd_x in [-1.20, 1.20]:
						var ox: Vector2 = hit + rperp * sd_x
						x_slabs.append(Transform3D(xbs.scaled_local(Vector3(0.80, 0.026, pad_len)), Vector3(ox.x, 0.077, ox.y)))
					for sd_g in [-0.56, 0.56]:
						var gx: Vector2 = hit + rperp * sd_g
						x_guards.append(Transform3D(xbs.scaled_local(Vector3(0.07, 0.036, pad_len)), Vector3(gx.x, 0.085, gx.y)))
					for sd_h in [-1.56, 1.56]:
						var hx: Vector2 = hit + rperp * sd_h
						x_haz.append(Transform3D(xbs.scaled_local(Vector3(0.14, 0.028, pad_len)), Vector3(hx.x, 0.077, hx.y)))
	var BALLAST: ShaderMaterial = _terrain_feather_mat(Color(0.35, 0.33, 0.31, 0.88), 0.44, 0.94, 0.10, -7)
	var nb := _emit_soft_polys(st, ballast_polys, 0.62, 0.086)
	_st_commit(st, BALLAST, nb)
	_multimesh(A.bevel_box(Vector3.ONE, 0.02), A.paint(Color(0.3, 0.24, 0.18), 0.0, 0.9, {"wear": 0.4, "dust": 0.6, "panel_scale": 0.0}), ties, false)
	_multimesh(A.bevel_box(Vector3.ONE, 0.0), A.metal(Color(0.42, 0.38, 0.34)), rails, false)
	_multimesh(A.bevel_box(Vector3.ONE, 0.008), A.concrete(Color(0.37, 0.37, 0.36), true), x_slabs, false)
	_multimesh(A.bevel_box(Vector3.ONE, 0.0), A.metal(Color(0.28, 0.28, 0.29)), x_guards, false)
	_multimesh(A.bevel_box(Vector3.ONE, 0.004), A.hazard(), x_haz, false)


func _wagon(p: Vector3, horiz: bool) -> void:
	# 三类写实铁路货车：0 精修高细波纹钢棚车（veh_rail_wagon）、1 重工卧式化工罐车、2 高边敞车/重型帆布设备平车
	var wtype := rng.randi() % 3
	var c: Color = [Color(0.42, 0.22, 0.15), Color(0.25, 0.30, 0.34), Color(0.36, 0.34, 0.26), Color(0.28, 0.33, 0.27)][rng.randi() % 4]
	var fp := Vector3(12.0, 3.2, 2.9) if horiz else Vector3(2.9, 3.2, 12.0)
	if wtype == 0:
		var sb := _bldg_body(Vector3(3.0, 3.6, 11.6), p + Vector3(0, 1.8, 0))
		sb.rotation_degrees.y = 90.0 if horiz else 0.0
		PrefabLib.place_on_body(self, sb, "veh_rail_wagon", Vector3(3.04, 4.02, 11.4), false, null, -1.8)
		blocks.append(_rect_for(p, fp + Vector3(1, 0, 1)))
		add_contact_shadow(p, 4.2, 13.4, 90.0 if horiz else 0.0)
		return
	var sb := _bldg_body(Vector3(2.9, 3.2, 12.0), p + Vector3(0, 2.0, 0))
	sb.rotation_degrees.y = 90.0 if horiz else 0.0
	var M_BODY := A.corrugated(c, 0.68, 0.34)
	var M_DARK := A.metal(Color(0.14, 0.145, 0.155))
	var M_STEEL := A.metal(Color(0.28, 0.28, 0.29))
	# 底架贯通中梁 + 两端车钩缓冲器 + 双轴转向架与四组 24 段钢轮
	_ibox(sb, Vector3(2.82, 0.28, 12.05), 0.03, M_DARK, Vector3(0, -1.08, 0))
	for ez in [-6.22, 6.22]:
		_ibox(sb, Vector3(0.42, 0.22, 0.46), 0.02, M_STEEL, Vector3(0, -1.08, ez), Vector3.ZERO, Vector3.ONE, false)
	for bz in [-4.05, 4.05]:
		_ibox(sb, Vector3(1.88, 0.26, 0.52), 0.02, M_DARK, Vector3(0, -1.34, bz), Vector3.ZERO, Vector3.ONE, false)
		for sx in [-0.82, 0.82]:
			_ibox(sb, Vector3(0.16, 0.34, 1.98), 0.02, M_STEEL, Vector3(sx, -1.46, bz), Vector3.ZERO, Vector3.ONE, false)
			for wz_off in [-0.58, 0.58]:
				_imesh(sb, A.cyl(0.42, 0.13, 0.42, 24), M_DARK, Vector3(sx * 0.88, -1.46, bz + wz_off), Vector3(0, 0, 90), Vector3.ONE, false)
	if wtype == 1:
		# 卧式加压工业罐车：鞍座支承架 + 圆筒钢罐体 + 箍带 + 顶部人孔阀台与侧爬梯
		var M_TANK := A.paint(Color(0.38, 0.39, 0.38) if rng.randf() < 0.55 else c.lightened(0.08), 0.55, 0.52, {"rust": 0.65, "wear": 0.5, "panel_scale": 0.6})
		for sz_c in [-3.9, 0.0, 3.9]:
			_ibox(sb, Vector3(2.45, 0.55, 0.38), 0.02, M_DARK, Vector3(0, -0.72, sz_c))
		_imesh(sb, A.cyl(1.34, 11.2, 1.34, 22), M_TANK, Vector3(0, 0.38, 0), Vector3(90, 0, 0))
		for ez in [-5.6, 5.6]:
			_imesh(sb, A.sphere(1.33, 0.44, 16), M_TANK, Vector3(0, 0.38, ez), Vector3(90, 0, 0))
		for bz in [-3.8, -1.3, 1.3, 3.8]:
			_imesh(sb, A.cyl(1.37, 0.10, 1.37, 22), M_DARK, Vector3(0, 0.38, bz), Vector3(90, 0, 0), Vector3.ONE, false)
		_imesh(sb, A.cyl(0.50, 0.38, 0.54, 14), M_DARK, Vector3(0, 1.78, 0))
		_ibox(sb, Vector3(1.56, 0.06, 2.2), 0.01, M_STEEL, Vector3(0, 1.76, 0), Vector3.ZERO, Vector3.ONE, false)
		_ibox(sb, Vector3(0.08, 2.45, 0.44), 0.01, M_DARK, Vector3(1.38, 0.48, 0.0), Vector3.ZERO, Vector3.ONE, false)
	else:
		# 重型高边敞车与帆布捆扎重机设备箱：钢板矮帮 + 侧立柱 + 双联油布机械货箱
		var M_TARP := A.paint(Color(0.32, 0.34, 0.27), 0.05, 0.88, {"wear": 0.5, "dust": 0.55, "panel_scale": 0.0})
		for sx in [-1.38, 1.38]:
			_ibox(sb, Vector3(0.14, 1.05, 11.85), 0.02, M_BODY, Vector3(sx, -0.42, 0))
			for ri in 6:
				_ibox(sb, Vector3(0.20, 1.12, 0.14), 0.01, M_DARK, Vector3(sx * 1.03, -0.40, -4.5 + ri * 1.8), Vector3.ZERO, Vector3.ONE, false)
		for ez in [-5.86, 5.86]:
			_ibox(sb, Vector3(2.86, 1.08, 0.16), 0.02, M_BODY, Vector3(0, -0.40, ez))
		for cz in [-2.75, 2.75]:
			_ibox(sb, Vector3(2.42, 1.95, 4.85), 0.06, M_TARP, Vector3(0, 0.58, cz))
			for sz_s in [-1.4, 1.4]:
				_ibox(sb, Vector3(2.48, 2.00, 0.09), 0.01, M_DARK, Vector3(0, 0.58, cz + sz_s), Vector3.ZERO, Vector3.ONE, false)
	blocks.append(_rect_for(p, fp + Vector3(1, 0, 1)))
	add_contact_shadow(p, 4.2, 13.4, 90.0 if horiz else 0.0)

# ---------- 山脊 ----------
func _build_ridges() -> void:
	rng.seed = _map_seed(6)
	ridge_pts.clear()
	# 山脊 3D 连续岩脊与碰撞体由 MountainTerrain 统一雕刻，这里仅记录战术小地图用的山脊采样点
	for line: PackedVector2Array in layout.ridges:
		for p: Vector2 in line:
			if on_road(p, 4.0) or in_wet(p, 3.0):
				continue
			ridge_pts.append(p)


# ---------- 城区：街块与建筑 ----------
## 固定布局：建筑、院墙、工业区储罐与集装箱、港口堆场、军营围墙均按固定种子生成，轮廓与大地图一致
func _build_blocks(sliced := false) -> void:
	rng.seed = _map_seed(8)
	_urban_plaza_pads.clear()
	# 建筑（轮廓来自城市群布局，与大地图一致）
	for b: Dictionary in layout.bldgs:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		_layout_building(b)
	# 外围连续城市群远景建筑群、林带、海岸与断崖（MultiMesh 合批 + 4 象限轻量静态碰撞与东湾水岸阻挡）
	await _build_backdrop(sliced)
	# 街块里的杂物与围合（仅限不规则战区内部）
	for blk: Dictionary in layout.blocks:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		var poly: PackedVector2Array = blk.poly
		var c := WC.centroid(poly)
		if border_dist(c) < -24.0:
			continue
		match str(blk.ch):
			"D": _block_downtown(blk)
			"R": _block_residential(blk)
			"I": _block_industrial(blk)
			"H": _block_harbor(blk)
			"Y": _block_railyard(blk)
			"M": _block_military(blk)
	_fill_urban_open_plazas()
	_build_urban_street_trees()


func _build_backdrop(sliced := false) -> void:
	if not is_surface_map:
		return
	var brng := RandomNumberGenerator.new()
	brng.seed = _map_seed(801)
	var bd_bodies: Array[StaticBody3D] = []
	for qi in 4:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		var sb := StaticBody3D.new()
		sb.name = "BackdropStatic_%d" % qi
		sb.collision_layer = 1
		sb.collision_mask = 0
		sb.set_meta("backdrop_static", true)
		world.add_child(sb)
		bd_bodies.append(sb)
	var add_bd_col := func(pos_2d: Vector2, shape: Shape3D, xf: Transform3D) -> void:
		var qidx := (1 if pos_2d.x >= 0.0 else 0) + (2 if pos_2d.y >= 0.0 else 0)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = xf
		bd_bodies[qidx].add_child(cs)
	var gate_pts: Array = []
	for e_key: String in WorldLinkScript.LINKS.get(map_id, {}):
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		gate_pts.append(WC.gate_info(map_id, e_key).pos)
	var near_any_gate := func(pos_2d: Vector2, rad: float) -> bool:
		for gp: Vector2 in gate_pts:
			if pos_2d.distance_to(gp) < rad:
				return true
		return false
	var hull_con0: Array = []
	var hull_con1: Array = []
	var hull_brick: Array = []
	var hull_wh: Array = []
	var hull_mil: Array = []
	var trim_dark: Array = []
	var roof_dark: Array = []
	var win_dark: Array = []
	var gable_slate: Array = []
	var gable_rust: Array = []
	var barrel_wh: Array = []
	var saw_shed: Array = []
	var tank_cyls: Array = []
	var cont_blue: Array = []
	var cont_rust: Array = []

	var bd_polys_only: Array = []
	for b: Dictionary in layout.get("backdrop_bldgs", []):
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		var c: Vector2 = b.c
		var ang: float = float(b.ang)
		var sx: float = float(b.sx)
		var sz: float = float(b.sz)
		var h: float = float(b.h)
		var kind := str(b.kind)
		var obb := WC.obb_corners(c, ang, sx, sz)
		backdrop_bldg_polys.append([obb, str(b.ch)])
		bd_polys_only.append(WC.obb_corners(c, ang, sx + 2.4, sz + 2.4))
		var bs := Basis(Vector3.UP, -ang)
		var p0 := Vector3(c.x, 0.0, c.y)
		var b_sh := BoxShape3D.new()
		b_sh.size = Vector3(sx, h, sz)
		add_bd_col.call(c, b_sh, Transform3D(bs, p0 + Vector3(0.0, h * 0.5, 0.0)))
		trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx + 0.24, 0.64, sz + 0.24)), p0 + Vector3(0.0, 0.32, 0.0)))
		if BuildingsExt.add_backdrop(kind, bs, p0, sx, sz, h, brng, hull_con0, hull_con1, hull_brick, hull_wh, hull_mil,
				trim_dark, roof_dark, win_dark, gable_slate, gable_rust, barrel_wh, saw_shed, tank_cyls):
			continue
		match kind:
			"house", "farm":
				if brng.randf() < 0.38:
					hull_brick.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
				else:
					hull_con0.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
				win_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.62, 0.85, sz + 0.08)), p0 + Vector3(0.0, h * 0.56, 0.0)))
				var rh := minf(sx, sz) * 0.36
				var g_tf := Transform3D(bs.scaled_local(Vector3(sx + 0.62, rh, sz + 0.52)), p0 + Vector3(0.0, h, 0.0))
				if brng.randf() < 0.5:
					gable_slate.append(g_tf)
				else:
					gable_rust.append(g_tf)
			"wh", "barn":
				if kind == "barn" or brng.randf() < 0.35:
					hull_brick.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
				else:
					hull_wh.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
				var arch_h := sz * 0.14
				var b_bs := bs * Basis(Vector3.FORWARD, PI * 0.5)
				barrel_wh.append(Transform3D(b_bs.scaled_local(Vector3(arch_h, sx + 0.32, sz * 0.5)), p0 + Vector3(0.0, h, 0.0)))
				trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.72, 0.44, sz * 0.22)), p0 + Vector3(0.0, h + arch_h + 0.12, 0.0)))
			"shed":
				hull_wh.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
				var mon_h := clampf(sz * 0.18, 0.72, 1.15)
				var s_bs := bs * Basis(Vector3.UP, PI * 0.5)
				saw_shed.append(Transform3D(s_bs.scaled_local(Vector3(sz + 0.28, mon_h, sx + 0.24)), p0 + Vector3(0.0, h, 0.0)))
			"barrack":
				hull_mil.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
				var arch_b := minf(1.25, sz * 0.20)
				var m_bs := bs * Basis(Vector3.FORWARD, PI * 0.5)
				barrel_wh.append(Transform3D(m_bs.scaled_local(Vector3(arch_b, sx + 0.22, sz * 0.5)), p0 + Vector3(0.0, h, 0.0)))
			_:
				var vr := brng.randi() % 3
				if vr == 0:
					hull_con0.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
				elif vr == 1:
					hull_con1.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
				else:
					hull_brick.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
				roof_dark.append(Transform3D(bs.scaled_local(Vector3(maxf(0.8, sx - 0.36), 0.14, maxf(0.8, sz - 0.36))), p0 + Vector3(0.0, h + 0.18, 0.0)))
				trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx + 0.26, 0.28, sz + 0.26)), p0 + Vector3(0.0, h + 0.06, 0.0)))
				var floors := maxi(1, int(h / 2.2))
				for f in floors:
					var fy := 1.15 + float(f) * ((h - 0.8) / float(floors))
					if fy < h - 0.45:
						win_dark.append(Transform3D(bs.scaled_local(Vector3(sx + 0.06, 0.62, sz + 0.06)), p0 + Vector3(0.0, fy, 0.0)))
				# 立面中段竖向壁柱打断通长窗带，形成真实网格窗格，同时屋顶设电梯机房/空调箱
				if sx > 5.0:
					hull_con1.append(Transform3D(bs.scaled_local(Vector3(0.55, h - 0.2, sz + 0.12)), p0 + Vector3(0.0, h * 0.5, 0.0)))
				if sz > 5.0:
					hull_con1.append(Transform3D(bs.scaled_local(Vector3(sx + 0.12, h - 0.26, 0.55)), p0 + Vector3(0.0, h * 0.5, 0.0)))
				if sx * sz > 28.0:
					var bh_p := bs * Vector3(sx * 0.22, h + 0.68, -sz * 0.18)
					trim_dark.append(Transform3D(bs.scaled_local(Vector3(minf(2.6, sx * 0.34), 1.35, minf(2.4, sz * 0.34))), p0 + bh_p))

	# 外围工业区储罐与港区堆场集装箱（严格避让 backdrop 建筑多边形与转场口，确保 0 重叠穿模）
	for blk: Dictionary in layout.blocks:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		var poly: PackedVector2Array = blk.poly
		var bc := WC.centroid(poly)
		if border_dist(bc) > -8.0:
			continue
		var ch_b := str(blk.ch)
		if ch_b == "I" and brng.randf() < 0.65:
			var rad := brng.randf_range(2.6, 3.8)
			var th := brng.randf_range(5.2, 8.6)
			var t_obb := WC.obb_corners(bc, 0.0, rad * 2.4, rad * 2.4)
			if not near_any_gate.call(bc, rad + 14.0) and not on_road(bc, rad + 1.5) and not in_river(bc, rad + 2.0) and not WC._hits(bd_polys_only, t_obb, 1.2):
				tank_cyls.append(Transform3D(Basis.IDENTITY.scaled(Vector3(rad * 2.0, th, rad * 2.0)), Vector3(bc.x, th * 0.5, bc.y)))
				bd_polys_only.append(t_obb)
				var t_sh := CylinderShape3D.new()
				t_sh.radius = rad
				t_sh.height = th
				add_bd_col.call(bc, t_sh, Transform3D(Basis.IDENTITY, Vector3(bc.x, th * 0.5, bc.y)))
		elif ch_b == "H" and brng.randf() < 0.8:
			var c_bs := Basis(Vector3.UP, -float(blk.ang) + PI * 0.5)
			for ci in 2:
				var cq := bc + Vector2(cos(float(blk.ang)), sin(float(blk.ang))) * (float(ci) - 0.5) * 7.2
				var c_obb := WC.obb_corners(cq, float(blk.ang) - PI * 0.5, 3.0, 6.8)
				if border_dist(cq) < -7.0 and not near_any_gate.call(cq, 16.0) and not on_road(cq, 3.5) and not in_river(cq, 3.5) and not WC._hits(bd_polys_only, c_obb, 1.2):
					var c_tf := Transform3D(c_bs.scaled_local(Vector3(2.4, 2.4, 6.0)), Vector3(cq.x, 1.2, cq.y))
					if brng.randf() < 0.5:
						cont_blue.append(c_tf)
					else:
						cont_rust.append(c_tf)
					bd_polys_only.append(c_obb)
					var c_sh := BoxShape3D.new()
					c_sh.size = Vector3(2.4, 2.4, 6.0)
					add_bd_col.call(cq, c_sh, Transform3D(c_bs, Vector3(cq.x, 1.2, cq.y)))

	# 外围林带、公园树木与远景断崖岩层
	var bd_trunks: Array = []
	var bd_pines: Array = []
	var bd_broads: Array = []
	var bd_autumn: Array = []
	var bd_cliffs: Array = []
	var gz := -EXT_HALF + 4.0
	while gz <= EXT_HALF - 4.0:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		var gx := -EXT_HALF + 4.0
		while gx <= EXT_HALF - 4.0:
			var q := Vector2(gx + brng.randf_range(-2.2, 2.2), gz + brng.randf_range(-2.2, 2.2))
			gx += 6.5
			if border_dist(q) > -6.5 or on_road(q, 2.8) or in_wet(q, 2.8):
				continue
			var zt := zone_at(Vector3(q.x, 0.0, q.y))
			if (zt == "T" and brng.randf() < 0.52) or (zt == "P" and brng.randf() < 0.22):
				var th := brng.randf_range(5.6, 10.4)
				var cr := th * brng.randf_range(0.22, 0.29)
				var tb := Basis(Vector3.UP, brng.randf() * TAU)
				bd_trunks.append(Transform3D(tb.scaled_local(Vector3(th * 0.17, th * 0.78, th * 0.17)), Vector3(q.x, 0.0, q.y)))
				var t_roll := brng.randf()
				if t_roll < 0.52:
					bd_pines.append(Transform3D(tb.scaled_local(Vector3(cr * 1.25, th * 0.80, cr * 1.25)), Vector3(q.x, th * 0.22, q.y)))
				elif t_roll < 0.84:
					bd_broads.append(Transform3D(tb.scaled_local(Vector3(cr * 1.48, th * 0.74, cr * 1.48)), Vector3(q.x, th * 0.28, q.y)))
				else:
					bd_autumn.append(Transform3D(tb.scaled_local(Vector3(cr * 1.44, th * 0.72, cr * 1.44)), Vector3(q.x, th * 0.28, q.y)))
			# 外围 K 区山脉由 MountainTerrain 连续高程场统一生成，避免球形岩块离散拼接
		gz += 6.5

	# 东湾连续自然海岸线与潮间带滩涂（2.5 米高密平滑采样，彻底消除 12 米锯齿台阶海岸接缝，配潮湿砂滩、砾石滩与防浪块石）
	var orig := WC.origin(map_id)
	var coast_line := PackedVector2Array()
	var has_coast := false
	var x_far := EXT_HALF + 120.0
	var z_lo := -EXT_HALF - 60.0
	var z_hi := EXT_HALF + 60.0
	var z_s := z_lo
	while z_s <= z_hi + 0.01:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		var lcx := WC.coast_x(orig.y + z_s) - orig.x
		if lcx < EXT_HALF + 85.0:
			has_coast = true
		coast_line.append(Vector2(clampf(lcx, -EXT_HALF - 50.0, x_far - 4.0), z_s))
		z_s += 2.5
	if has_coast and coast_line.size() >= 2:
		var coast_bank := StaticBody3D.new()
		coast_bank.name = "CoastWaterBank"
		coast_bank.collision_layer = 8
		coast_bank.collision_mask = 0
		coast_bank.set_meta("water_bank", true)
		world.add_child(coast_bank)
		for ci_b in coast_line.size() - 1:
			var ca := coast_line[ci_b] + Vector2(0.8, 0.0)
			var cb := coast_line[ci_b + 1] + Vector2(0.8, 0.0)
			var cm := (ca + cb) * 0.5
			if absf(cm.x) > EXT_HALF + 8.0 or absf(cm.y) > EXT_HALF + 8.0:
				continue
			for piece: Array in _bank_pieces(ca, cb):
				var pa: Vector2 = piece[0]
				var pb: Vector2 = piece[1]
				var pm := (pa + pb) * 0.5
				var ln := pa.distance_to(pb)
				if ln < 0.05:
					continue
				var tt := (pb - pa) / ln
				var cbs := Basis(Vector3.UP, atan2(tt.x, tt.y))
				var cs_cb := CollisionShape3D.new()
				var sh_cb := BoxShape3D.new()
				sh_cb.size = Vector3(1.0, 3.0, ln + 0.3)
				cs_cb.shape = sh_cb
				cs_cb.transform = Transform3D(cbs, Vector3(pm.x, 1.5, pm.y))
				coast_bank.add_child(cs_cb)
		var bay_poly := PackedVector2Array()
		for cp_pt: Vector2 in coast_line:
			bay_poly.append(Vector2(cp_pt.x + 1.2, cp_pt.y))
		bay_poly.append(Vector2(x_far, z_hi))
		bay_poly.append(Vector2(x_far, z_lo))
		var st_foreshore := SurfaceTool.new()
		var st_wet_sand := SurfaceTool.new()
		var st_bay := SurfaceTool.new()
		for st_c in [st_foreshore, st_wet_sand, st_bay]:
			st_c.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n_fs := 0
		for fp: PackedVector2Array in _outers(Geometry2D.offset_polyline(coast_line, 9.5, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)):
			_emit_poly(st_foreshore, fp, 0.012, 0.0)
			n_fs += 1
		var n_ws := 0
		for wp_c: PackedVector2Array in _outers(Geometry2D.offset_polyline(coast_line, 4.2, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)):
			_emit_poly(st_wet_sand, wp_c, 0.024, 0.0)
			n_ws += 1
		_emit_poly(st_bay, bay_poly, 0.048, 0.0)
		var M_FORESHORE: ShaderMaterial = A.gravel_mat(Color(0.35, 0.31, 0.25)).duplicate()
		M_FORESHORE.set_meta("no_outline", true)
		var M_WETSAND: ShaderMaterial = A.gravel_mat(Color(0.21, 0.19, 0.16)).duplicate()
		M_WETSAND.set_meta("no_outline", true)
		_st_commit(st_foreshore, M_FORESHORE, n_fs)
		_st_commit(st_wet_sand, M_WETSAND, n_ws)
		_st_commit(st_bay, _water_mat(), 1)
		for ci_pt in range(0, coast_line.size(), 2):
			var cp_r: Vector2 = coast_line[ci_pt]
			if cp_r.x < EXT_HALF + 40.0 and not in_wet(cp_r, 1.5) and brng.randf() < 0.62:
				var rsc := brng.randf_range(0.65, 1.85)
				bd_cliffs.append(Transform3D(Basis(Vector3.UP, brng.randf() * TAU).scaled_local(Vector3(rsc * 1.4, rsc * 0.55, rsc)),
					Vector3(cp_r.x + brng.randf_range(-2.2, 1.2), rsc * 0.18, cp_r.y)))

	var box_m := A.bevel_box(Vector3.ONE, 0.03)
	var gable_m := A.prism(PackedVector2Array([Vector2(-0.5, 0.0), Vector2(0.0, 1.0), Vector2(0.5, 0.0)]), 1.0, 0.01)
	var saw_m := A.prism(PackedVector2Array([Vector2(-0.5, 0.0), Vector2(-0.18, 1.0), Vector2(0.5, 0.0)]), 1.0, 0.01)
	var cyl_m := A.cyl(1.0, 1.0, 1.0, 18)
	_multimesh(box_m, A.concrete(Color(0.46, 0.44, 0.40)), hull_con0)
	_multimesh(box_m, A.concrete(Color(0.38, 0.37, 0.36)), hull_con1)
	_multimesh(box_m, A.brick(Color(0.48, 0.33, 0.26)), hull_brick)
	_multimesh(box_m, A.corrugated(Color(0.36, 0.40, 0.43), 0.48, 0.32), hull_wh)
	_multimesh(box_m, A.corrugated(Color(0.29, 0.32, 0.26), 0.40, 0.32), hull_mil)
	_multimesh(box_m, A.concrete(Color(0.29, 0.28, 0.27), false), trim_dark)
	_multimesh(box_m, A.tar_roof(Color(0.24, 0.25, 0.27)), roof_dark, false)
	_multimesh(box_m, A.window_mat(0.14, Vector2(0.85, 0.55)), win_dark, false)
	_multimesh(gable_m, A.roof_mat(Color(0.27, 0.31, 0.35), 0.32, true), gable_slate)
	_multimesh(gable_m, A.roof_mat(Color(0.40, 0.26, 0.20), 0.46, true), gable_rust)
	_multimesh(cyl_m, A.corrugated(Color(0.33, 0.36, 0.38), 0.50, 0.32), barrel_wh)
	_multimesh(saw_m, A.roof_mat(Color(0.35, 0.26, 0.21), 0.55, true), saw_shed)
	_multimesh(A.cyl(0.5, 1.0, 0.5, 20), A.paint(Color(0.54, 0.53, 0.49), 0.5, 0.56, {"rust": 0.62}), tank_cyls)
	_multimesh(box_m, A.corrugated(Color(0.24, 0.37, 0.49), 0.48, 0.38), cont_blue)
	_multimesh(box_m, A.corrugated(Color(0.54, 0.29, 0.19), 0.55, 0.38), cont_rust)
	_multimesh(A.tree_trunk_mesh(1), A.bark_mat(), bd_trunks, false)
	_multimesh(A.pine_crown_mesh(1), A.foliage_mat("pine"), bd_pines)
	_multimesh(A.broad_crown_mesh(1), A.foliage_mat("broad"), bd_broads)
	_multimesh(A.broad_crown_mesh(2), A.foliage_mat("autumn"), bd_autumn)
	_multimesh(A.rock_mesh(4), A.rock_mat(Color(0.39, 0.34, 0.28)), bd_cliffs)


## 按布局记录实例化一栋建筑（门脸朝向临街面，支持全部 20 种写实工业与城区建筑样式）
func _layout_building(b: Dictionary) -> void:
	var c: Vector2 = b.c
	var p := Vector3(c.x, 0, c.y)
	var ang: float = b.ang
	var sx: float = b.sx
	var sz: float = b.sz
	var h: float = b.h
	var kind := str(b.kind)
	if BuildingsExt.build(self, kind, p, Vector3(sx, h, sz), ang):
		_obb_blocks(c, ang, sx + 0.6, sz + 0.6)
	else:
		match kind:
			"house", "farm":
				_house(p, Vector3(sx, h, sz), ang)
				_obb_blocks(c, ang, sx + 0.8, sz + 0.8)
			"apt":
				_apartment(p, Vector3(sx, h, sz), ang)
				_obb_blocks(c, ang, sx + 0.5, sz + 0.5)
			"wh":
				_warehouse(p, Vector3(sx, h, sz), Color(-1, 0, 0), ang)
				_obb_blocks(c, ang, sx + 0.9, sz + 0.9)
			"barn":
				_warehouse(p, Vector3(sx, h, sz), Color(0.42, 0.24, 0.17), ang)
				_obb_blocks(c, ang, sx + 0.9, sz + 0.9)
			"shed":
				_factory_shed(p, Vector3(sx, h, sz), ang)
				_obb_blocks(c, ang, sx + 0.5, sz + 0.5)
			"barrack":
				_barrack(p, Vector3(sx, h, sz), ang)
				_obb_blocks(c, ang, sx + 0.5, sz + 0.5)
			_:
				_building(p, Vector3(sx, h, sz), ang)
				_obb_blocks(c, ang, sx + 0.5, sz + 0.5)
	bldg_polys.append([WC.obb_corners(c, ang, sx, sz), str(b.ch)])
	_register_building_loot(c, ang, sx, sz, kind, str(b.ch))


## 为每栋实体建筑按建筑功能在门廊/装卸台/侧巷/后院登记严格匹配的固定物资箱候选点（正面朝外贴墙）
func _register_building_loot(c: Vector2, ang: float, sx: float, sz: float, kind: String, ch: String) -> void:
	var host := Vector3(c.x, 0.0, c.y)
	if not in_bounds(host, 6.0):
		return
	# u 沿门脸宽度（本地 +x），v 指向临街正面（本地 +z，预制体 flip_front=true 后门脸/装卸台均在此侧）
	var u := Vector3(cos(ang), 0.0, sin(ang))
	var v := Vector3(-sin(ang), 0.0, cos(ang))
	var yaw_front := _face_outward_yaw(v)
	var yaw_back := _face_outward_yaw(-v)
	var yaw_side := _face_outward_yaw(u)
	var yaw_side2 := _face_outward_yaw(-u)
	var off_f := sz * 0.5 + 1.35
	var off_s := sx * 0.5 + 1.35
	var shift_x := clampf(sx * 0.28, 0.9, 2.4)
	var p_front := host + v * off_f + u * shift_x
	var p_front2 := host + v * off_f - u * shift_x
	var p_side := host + u * off_s + v * clampf(sz * 0.16, 0.0, 1.4)
	var p_side2 := host - u * off_s + v * clampf(sz * 0.16, 0.0, 1.4)
	var p_back := host - v * off_f + u * (shift_x * 0.6)
	var vis_f := 4 if v.z >= 0.15 else 0
	var vis_b := 4 if (-v.z) >= 0.15 else 0
	var vis_s := 3 if u.z >= 0.15 else 0
	var vis_s2 := 3 if (-u.z) >= 0.15 else 0
	var btag := "bldg:" + kind
	var mtag := "military_bldg:" + kind
	match kind:
		"command_bunker":
			register_loot_anchor(p_front, yaw_front, "weapon", 97 + vis_f, mtag, v, host)
			register_loot_anchor(p_back, yaw_back, "safe", 95 + vis_b, mtag, -v, host)
			register_loot_anchor(p_side, yaw_side, "military", 93 + vis_s, mtag, u, host)
			register_loot_anchor(p_side2, yaw_side2, "ammo", 89 + vis_s2, mtag, -u, host)
		"barrack":
			register_loot_anchor(p_front, yaw_front, "military", 91 + vis_f, mtag, v, host)
			register_loot_anchor(p_side, yaw_side, "ammo", 88 + vis_s, mtag, u, host)
			register_loot_anchor(p_side2, yaw_side2, "med", 83 + vis_s2, mtag, -u, host)
			register_loot_anchor(p_back, yaw_back, "weapon", 86 + vis_b, mtag, -v, host)
		"arcade_shop":
			register_loot_anchor(p_front, yaw_front, "register", 86 + vis_f, btag, v, host)
			register_loot_anchor(p_front2, yaw_front, "supply", 78 + vis_f, btag, v, host)
			register_loot_anchor(p_side, yaw_side, "safe", 80 + vis_s, btag, u, host)
		"stepped_tower":
			register_loot_anchor(p_front, yaw_front, "register", 80 + vis_f, btag, v, host)
			register_loot_anchor(p_side, yaw_side, "safe", 84 + vis_s, btag, u, host)
			register_loot_anchor(p_back, yaw_back, "tech", 82 + vis_b, btag, -v, host)
		"courtyard_blk":
			register_loot_anchor(p_front, yaw_front, "med", 77 + vis_f, btag, v, host)
			register_loot_anchor(p_side, yaw_side, "safe", 82 + vis_s, btag, u, host)
			register_loot_anchor(p_back, yaw_back, "supply", 74 + vis_b, btag, -v, host)
		"substation":
			register_loot_anchor(p_front, yaw_front, "tech", 89 + vis_f, btag, v, host)
			register_loot_anchor(p_side, yaw_side, "tool", 83 + vis_s, btag, u, host)
		"chem_plant":
			register_loot_anchor(p_front, yaw_front, "tech", 88 + vis_f, btag, v, host)
			register_loot_anchor(p_side, yaw_side, "tool", 82 + vis_s, btag, u, host)
			register_loot_anchor(p_back, yaw_back, "med", 79 + vis_b, btag, -v, host)
		"foundry":
			register_loot_anchor(p_front, yaw_front, "tool", 86 + vis_f, btag, v, host)
			register_loot_anchor(p_side, yaw_side, "tool", 80 + vis_s, btag, u, host)
			register_loot_anchor(p_back, yaw_back, "safe", 78 + vis_b, btag, -v, host)
		"loco_shed":
			register_loot_anchor(p_front, yaw_front, "tool", 87 + vis_f, btag, v, host)
			register_loot_anchor(p_front2, yaw_front, "supply", 78 + vis_f, btag, v, host)
			register_loot_anchor(p_side, yaw_side, "tech", 82 + vis_s, btag, u, host)
		"wh":
			register_loot_anchor(p_front, yaw_front, "supply", 84 + vis_f, btag, v, host)
			register_loot_anchor(p_front2, yaw_front, "tool", 80 + vis_f, btag, v, host)
			if ch in ["H", "I", "Y"]:
				var p_wh_yard := host + u * (sx * 0.5 + 1.85) + v * clampf(sz * 0.12, 0.0, 1.2)
				register_loot_anchor(p_wh_yard, yaw_side, "container", 82 + vis_s, btag, u, host)
			else:
				register_loot_anchor(p_side, yaw_side, "supply", 76 + vis_s, btag, u, host)
		"cold_store":
			# 左翼为冷库货运月台（-u），右翼为后勤办公/冷链室（+u）
			register_loot_anchor(p_front2, yaw_front, "supply", 86 + vis_f, btag, v, host)
			register_loot_anchor(p_front, yaw_front, "med", 82 + vis_f, btag, v, host)
			register_loot_anchor(p_side, yaw_side, "tool", 76 + vis_s, btag, u, host)
		"shed":
			register_loot_anchor(p_front, yaw_front, "tool", 84 + vis_f, btag, v, host)
			register_loot_anchor(p_front2, yaw_front, "tech", 79 + vis_f, btag, v, host)
			register_loot_anchor(p_side, yaw_side, "supply", 75 + vis_s, btag, u, host)
		"barn", "silo_barn":
			register_loot_anchor(p_front, yaw_front, "supply", 84 + vis_f, btag, v, host)
			register_loot_anchor(p_side, yaw_side, "tool", 80 + vis_s, btag, u, host)
			register_loot_anchor(p_back, yaw_back, "cache", 74 + vis_b, btag, -v, host)
		"farm":
			register_loot_anchor(p_front, yaw_front, "supply", 82 + vis_f, btag, v, host)
			register_loot_anchor(p_side, yaw_side, "tool", 76 + vis_s, btag, u, host)
			register_loot_anchor(p_back, yaw_back, "cache", 72 + vis_b, btag, -v, host)
		"apt", "tenement":
			register_loot_anchor(p_front, yaw_front, "supply", 72 + vis_f, btag, v, host)
			register_loot_anchor(p_side, yaw_side, "med", 70 + vis_s, btag, u, host)
			register_loot_anchor(p_back, yaw_back, "tool", 62 + vis_b, btag, -v, host)
		"terrace", "duplex", "house":
			register_loot_anchor(p_front, yaw_front, "supply", 70 + vis_f, btag, v, host)
			register_loot_anchor(p_side, yaw_side, "med", 66 + vis_s, btag, u, host)
			register_loot_anchor(p_back, yaw_back, "tool", 60 + vis_b, btag, -v, host)
		_:
			match ch:
				"M":
					register_loot_anchor(p_front, yaw_front, "military", 84 + vis_f, mtag, v, host)
					register_loot_anchor(p_side, yaw_side, "ammo", 80 + vis_s, mtag, u, host)
				"D":
					register_loot_anchor(p_front, yaw_front, "register", 78 + vis_f, btag, v, host)
					register_loot_anchor(p_side, yaw_side, "safe", 76 + vis_s, btag, u, host)
				"I", "Y":
					register_loot_anchor(p_front, yaw_front, "tool", 78 + vis_f, btag, v, host)
					register_loot_anchor(p_side, yaw_side, "tech", 74 + vis_s, btag, u, host)
				"H":
					register_loot_anchor(p_front, yaw_front, "supply", 78 + vis_f, btag, v, host)
					register_loot_anchor(p_side, yaw_side, "tool", 74 + vis_s, btag, u, host)
				"R":
					register_loot_anchor(p_front, yaw_front, "supply", 68 + vis_f, btag, v, host)
					register_loot_anchor(p_side, yaw_side, "med", 66 + vis_s, btag, u, host)
				_:
					register_loot_anchor(p_front, yaw_front, "supply", 72 + vis_f, btag, v, host)
					register_loot_anchor(p_back, yaw_back, "cache", 70 + vis_b, btag, -v, host)


func _barrack(p: Vector3, sz: Vector3, rot := 0.0) -> void:
	# 战区加固防爆拱肋军营（B1-05 bldg_barrack）：钢筋混凝土防爆墙裙扶壁 + 北约军绿装甲墙身 + 7 道铆接拱肋 + 深凹防弹观察孔 + 核生化新风机组
	var sb := _bldg_body(sz, p + Vector3(0, sz.y * 0.5, 0))
	sb.rotation.y = -rot
	var c: Color = [Color(0.36, 0.42, 0.30), Color(0.35, 0.39, 0.34), Color(0.42, 0.40, 0.31)][rng.randi() % 3]
	PrefabLib.place_on_body(self, sb, "bldg_barrack", sz, true, A.corrugated(c, 0.36, 0.24), -999.0, rng.randf() < 0.55, "SEC-%02d" % rng.randi_range(1, 19))


func _factory_shed(p: Vector3, sz: Vector3, rot := 0.0) -> void:
	# 锯齿天窗工矿机务检修库（B1-04 bldg_factory_shed）；过窄地块自动改用单跨库房/配电所，避免三跨天窗被压成微缩模型
	var c: Color = [Color(0.48, 0.32, 0.24), Color(0.35, 0.42, 0.47), Color(0.46, 0.43, 0.34)][rng.randi() % 3]
	var pf_id := "bldg_factory_shed"
	if minf(sz.x, sz.z) < 7.6:
		pf_id = "bldg_substation" if rng.randf() < 0.45 else "bldg_warehouse"
	var safe_sz := PrefabLib.clamp_building_height(pf_id, sz)
	var sb := _bldg_body(safe_sz, p + Vector3(0, safe_sz.y * 0.5, 0))
	sb.rotation.y = -rot
	PrefabLib.place_on_body(self, sb, pf_id, safe_sz, true, A.corrugated(c, 0.42, 0.24), -999.0, rng.randf() < 0.45)


func _apartment(p: Vector3, sz: Vector3, rot := 0.0) -> void:
	# 预制板多层职工公寓楼（B1-03 bldg_apartment）：四层柱网真内凹窗格 + 中轴楼梯采光核 + 半挑铁栏阳台空调笼 + 女儿墙高架水箱与风冷机组
	var is_brk := rng.randf() < 0.42
	var c: Color = Color(0.54, 0.36, 0.26) if is_brk else [Color(0.60, 0.56, 0.50), Color(0.54, 0.52, 0.49), Color(0.58, 0.49, 0.41)][rng.randi() % 3]
	var M_WALL: ShaderMaterial = A.brick(c) if is_brk else A.concrete(c)
	var safe_sz := PrefabLib.clamp_building_height("bldg_apartment", sz)
	var sb := _bldg_body(safe_sz, p + Vector3(0, safe_sz.y * 0.5, 0))
	sb.rotation.y = -rot
	PrefabLib.place_on_body(self, sb, "bldg_apartment", safe_sz, true, M_WALL, -999.0, rng.randf() < 0.28)


var _urban_plaza_pads: Array = []


func _spawn_urban_plaza_pad(pad_c: Vector2, pad_w: float, pad_d: float, pad_ang: float, want_park: bool) -> void:
	_urban_plaza_pads.append(WC.obb_corners(pad_c, pad_ang, pad_w, pad_d))
	var u := Vector2(cos(pad_ang), sin(pad_ang))
	var v := Vector2(-sin(pad_ang), cos(pad_ang))
	var yaw0 := rad_to_deg(-pad_ang)
	var holder := Node3D.new()
	holder.position = Vector3(pad_c.x, 0.0, pad_c.y)
	holder.rotation.y = -pad_ang
	world.add_child(holder)
	var M_CURB_P := A.concrete(Color(0.60, 0.58, 0.54), false)
	if want_park:
		# 华盛顿式街心口袋公园：浅石缘石围框 + 城市草坪 + 十字步砖 + 中央纪念花坛 + 2~4 棵阔叶树（平面无阻挡，机甲可畅行）
		var M_LAWN := A.paint(Color(0.20, 0.31, 0.16), 0.0, 0.95, {"wear": 0.22, "panel_scale": 0.0, "dust": 0.14, "grime": 0.28})
		var M_PATH := A.concrete(Color(0.55, 0.53, 0.49), false)
		_ibox(holder, Vector3(pad_w, 0.09, pad_d), 0.02, M_CURB_P, Vector3(0.0, 0.045, 0.0), Vector3.ZERO, Vector3.ONE, false)
		_ibox(holder, Vector3(pad_w - 0.56, 0.05, pad_d - 0.56), 0.01, M_LAWN, Vector3(0.0, 0.085, 0.0), Vector3.ZERO, Vector3.ONE, false)
		_ibox(holder, Vector3(pad_w - 0.44, 0.06, 1.55), 0.01, M_PATH, Vector3(0.0, 0.092, 0.0), Vector3.ZERO, Vector3.ONE, false)
		_ibox(holder, Vector3(1.55, 0.06, pad_d - 0.44), 0.01, M_PATH, Vector3(0.0, 0.092, 0.0), Vector3.ZERO, Vector3.ONE, false)
		_ibox(holder, Vector3(2.2, 0.14, 2.2), 0.02, M_CURB_P, Vector3(0.0, 0.12, 0.0), Vector3.ZERO, Vector3.ONE, false)
		var M_BK := A.bark_mat(Color(0.28, 0.24, 0.20))
		var M_CR := A.foliage_mat("broad")
		var tx_off := pad_w * 0.32
		var tz_off := pad_d * 0.30
		for ti: Vector2 in [Vector2(-tx_off, -tz_off), Vector2(tx_off, tz_off), Vector2(-tx_off, tz_off), Vector2(tx_off, -tz_off)]:
			var t_world: Vector2 = pad_c + u * ti.x + v * ti.y
			if rng.randf() < 0.78 and not _in_keep_clear(Vector3(t_world.x, 0.0, t_world.y), 1.2):
				var th := rng.randf_range(5.0, 6.8)
				var tr := th * 0.26
				var tp := Vector3(ti.x, 0.08, ti.y)
				_imesh(holder, A.tree_trunk_mesh(0), M_BK, tp, Vector3(0.0, rng.randf() * 360.0, 0.0), Vector3(th * 0.16, th * 0.72, th * 0.16), true)
				_imesh(holder, A.broad_crown_mesh(rng.randi() % 2), M_CR, tp + Vector3(0.0, th * 0.46, 0.0), Vector3(0.0, rng.randf() * 360.0, 0.0), Vector3(tr * 1.45, th * 0.58, tr * 1.45), true)
	else:
		# 纽约式划线地面停车场：深色风化沥青坪 + 白色停车位标线 + 沿车位整齐平行停放的残骸车
		var M_LOT := A.asphalt(Color(0.21, 0.215, 0.225))
		var M_STRIPE := A.paint(Color(0.76, 0.76, 0.72), 0.0, 0.88, {"wear": 0.45, "panel_scale": 0.0})
		_ibox(holder, Vector3(pad_w, 0.06, pad_d), 0.015, M_CURB_P, Vector3(0.0, 0.03, 0.0), Vector3.ZERO, Vector3.ONE, false)
		_ibox(holder, Vector3(pad_w - 0.32, 0.04, pad_d - 0.32), 0.01, M_LOT, Vector3(0.0, 0.055, 0.0), Vector3.ZERO, Vector3.ONE, false)
		var n_stalls := 4 if pad_w >= 12.0 else (3 if pad_w >= 9.5 else 2)
		var sp_x := 3.0
		var x0 := -0.5 * float(n_stalls - 1) * sp_x
		var st_len := minf(4.4, pad_d * 0.46)
		for si in n_stalls + 1:
			var sx_line := x0 - sp_x * 0.5 + float(si) * sp_x
			_ibox(holder, Vector3(0.12, 0.02, st_len), 0.005, M_STRIPE, Vector3(sx_line, 0.08, -pad_d * 0.20), Vector3.ZERO, Vector3.ONE, false)
		_ibox(holder, Vector3(float(n_stalls) * sp_x, 0.02, 0.12), 0.005, M_STRIPE, Vector3(0.0, 0.08, -pad_d * 0.20 - st_len * 0.5), Vector3.ZERO, Vector3.ONE, false)
		var slot_x := x0 if rng.randf() < 0.5 else (x0 + float(n_stalls - 1) * sp_x)
		var car_q := pad_c + u * slot_x - v * (pad_d * 0.18)
		var car_p := Vector3(car_q.x, 0.0, car_q.y)
		if not _blocked(car_p, 2.8, false) and not on_road(car_q, 1.8) and not _in_keep_clear(car_p, 2.5):
			_wreck_car(car_p, yaw0 + 90.0, 0.84)


func _plaza_pad_ok(cq: Vector2, test_ang: float, tw: float, td: float) -> bool:
	var p3 := Vector3(cq.x, 0.0, cq.y)
	if not in_bounds(p3, 8.0) or on_road(cq, 1.4) or in_wet(cq, 3.0):
		return false
	for ex: Array in MAP.get("extracts", []):
		if cq.distance_to(Vector2(float(ex[1]), float(ex[2]))) < 12.5:
			return false
	for pp: Vector3 in poi_centers:
		if cq.distance_to(Vector2(pp.x, pp.z)) < 16.5:
			return false
	var cs := WC.obb_corners(cq, test_ang, tw, td)
	for prev_cs: PackedVector2Array in _urban_plaza_pads:
		if WC.convex_overlap(prev_cs, cs, 2.6):
			return false
	var u := Vector2(cos(test_ang), sin(test_ang))
	var v := Vector2(-sin(test_ang), cos(test_ang))
	for ck: Vector2 in [cq, cq + u * (tw * 0.44) + v * (td * 0.40), cq - u * (tw * 0.44) + v * (td * 0.40), cq + u * (tw * 0.44) - v * (td * 0.40), cq - u * (tw * 0.44) - v * (td * 0.40)]:
		if _blocked(Vector3(ck.x, 0.0, ck.y), 1.45, false) or on_road(ck, 1.0) or _in_keep_clear(Vector3(ck.x, 0.0, ck.y), 1.2):
			return false
	return true


func _decorate_urban_open_lot(blk: Dictionary) -> bool:
	# 城区/住宅街块剩余空地：改为华盛顿式街心绿地公园或纽约式划线地面停车场，彻底消灭空白水泥广场
	var poly: PackedVector2Array = blk.poly
	var area := WC.poly_area(poly)
	var max_pads := 2 if area >= 1150.0 else 1
	var base_ang := float(blk.ang)
	var u0 := Vector2(cos(base_ang), sin(base_ang))
	var v0 := Vector2(-sin(base_ang), cos(base_ang))
	var cand_pts: Array[Vector2] = [WC.centroid(poly)]
	var fit := WC._fit_obb(poly, base_ang, 0.8)
	if not fit.is_empty():
		var fc: Vector2 = fit.c
		cand_pts.append(fc)
		for sx: float in [-0.36, -0.18, 0.0, 0.18, 0.36]:
			for sz: float in [-0.34, -0.16, 0.0, 0.16, 0.34]:
				if sx != 0.0 or sz != 0.0:
					cand_pts.append(fc + u0 * (float(fit.sx) * sx) + v0 * (float(fit.sz) * sz))
	for _ri in 10:
		var sp3 := _spot_in_poly(poly, 4.6)
		if sp3 != Vector3.INF:
			cand_pts.append(Vector2(sp3.x, sp3.z))
	var count := 0
	for _pi in max_pads:
		var pad_c := Vector2.INF
		var pad_w := 14.0
		var pad_d := 10.0
		var pad_ang := base_ang
		for dims: Array in [[14.0, 10.0], [11.0, 8.0], [8.6, 6.4]]:
			var tw: float = float(dims[0])
			var td: float = float(dims[1])
			for rot_off: float in [0.0, PI * 0.5]:
				var test_ang := base_ang + rot_off
				for cq: Vector2 in cand_pts:
					var cs := WC.obb_corners(cq, test_ang, tw, td)
					if not WC._all_in(poly, cs, 0.25):
						continue
					if _plaza_pad_ok(cq, test_ang, tw, td):
						pad_c = cq
						pad_w = tw
						pad_d = td
						pad_ang = test_ang
						break
				if pad_c != Vector2.INF:
					break
			if pad_c != Vector2.INF:
				break
		if pad_c == Vector2.INF:
			break
		count += 1
		var want_park := (rng.randf() < 0.60) if count == 1 else (rng.randf() < 0.44)
		_spawn_urban_plaza_pad(pad_c, pad_w, pad_d, pad_ang, want_park)
	return count > 0


## 兜底巡检街块多边形之外仍残余的城区开阔空地（如道路交叉缝、呼吸口袋），自动升级为街心口袋公园或划线停车场
func _fill_urban_open_plazas() -> void:
	if not is_surface_map or _rg == null:
		return
	var lim := HALF - 16.0
	var step := 13.0
	var gz := -lim
	while gz <= lim:
		var gx := -lim
		while gx <= lim:
			var cq := Vector2(gx, gz)
			var p3 := Vector3(cq.x, 0.0, cq.y)
			if in_bounds(p3, 10.0) and zone_at(p3) in ["D", "R"] and not on_road(cq, 3.5) and not in_wet(cq, 4.0) and not _blocked(p3, 3.2, false):
				var si: int = _rg.nearest(cq, 48.0)
				var base_ang := 0.0
				if si >= 0:
					var sd_v: Vector2 = (_rg.b[si] - _rg.a[si]).normalized()
					base_ang = atan2(sd_v.y, sd_v.x)
				for dims: Array in [[14.5, 10.2], [11.5, 8.2], [9.0, 6.8]]:
					var tw: float = float(dims[0])
					var td: float = float(dims[1])
					var placed := false
					for rot_off: float in [0.0, PI * 0.5]:
						var tang := base_ang + rot_off
						if _plaza_pad_ok(cq, tang, tw, td):
							_spawn_urban_plaza_pad(cq, tw, td, tang, rng.randf() < 0.62)
							placed = true
							break
					if placed:
						break
			gx += step
		gz += step


func _block_downtown(blk: Dictionary) -> void:
	var ang := float(blk.ang)
	var yaw0 := rad_to_deg(-ang)
	if not _decorate_urban_open_lot(blk):
		if rng.randf() < 0.40:
			var p := _spot_in_poly(blk.poly, 3.4)
			if p != Vector3.INF and not on_road(Vector2(p.x, p.z), 2.5):
				_wreck_car(p, yaw0 + (0.0 if rng.randf() < 0.5 else 90.0), 0.86)
	var pc := WC.centroid(blk.poly)
	var lot_p := Vector3(pc.x, 0.0, pc.y)
	if in_bounds(lot_p, 8.0) and not on_road(pc, 2.5) and not _blocked(lot_p, 1.8, false):
		var out_v := Vector3(-sin(ang), 0.0, cos(ang))
		register_loot_anchor(lot_p, _face_outward_yaw(out_v), "car_wreck", 76, "parking_car", out_v)


## 城区道路沿街行道树与树池（纽约/华盛顿林荫大道视觉核心，全量 MultiMesh 合批、不加多余阻挡碰撞）
func _build_urban_street_trees() -> void:
	if not is_surface_map or curves.is_empty():
		return
	var trunks: Array = []
	var crowns0: Array = []
	var crowns1: Array = []
	var pits: Array = []
	var soils: Array = []
	var placed_pts: Array[Vector2] = []
	var step := 17.0
	for cv: Dictionary in curves:
		if bool(cv.get("dirt", false)):
			continue
		var d: PackedVector2Array = cv.d
		if d.size() < 3:
			continue
		var hw := float(cv.w) * 0.5
		var off := hw + 1.15
		var acc := rng.randf_range(5.0, 11.0)
		for i in range(1, d.size()):
			var a := d[i - 1]
			var b := d[i]
			var sl := a.distance_to(b)
			if sl < 0.2:
				continue
			var dir := (b - a) / sl
			var nrm := Vector2(-dir.y, dir.x)
			var pos_s := 0.0
			while acc <= sl:
				pos_s = acc
				var bp := a + dir * pos_s
				var yaw_r := atan2(dir.y, dir.x)
				for sd: float in [-1.0, 1.0]:
					var q := bp + nrm * (sd * off)
					var p3 := Vector3(q.x, 0.0, q.y)
					if not in_bounds(p3, 10.0):
						continue
					var zc := zone_at(p3)
					if not (zc in ["D", "R"]):
						continue
					if on_road(q, 0.85) or in_wet(q, 3.0) or _blocked(p3, 2.35, false) or _in_keep_clear(p3, 3.4):
						continue
					# 避开十字路口与斑马线转角（前后 7m 处若不在同一条路沿外侧则说明紧邻交叉口）
					if on_road(q + dir * 7.0, 0.35) or on_road(q - dir * 7.0, 0.35):
						continue
					var too_near := false
					for prev_q: Vector2 in placed_pts:
						if prev_q.distance_squared_to(q) < 121.0: # >= 11m 株距
							too_near = true
							break
					if too_near:
						continue
					placed_pts.append(q)
					var pit_bs := Basis(Vector3.UP, -yaw_r)
					pits.append(Transform3D(pit_bs.scaled_local(Vector3(1.55, 0.12, 1.55)), Vector3(q.x, 0.06, q.y)))
					soils.append(Transform3D(pit_bs.scaled_local(Vector3(1.24, 0.08, 1.24)), Vector3(q.x, 0.09, q.y)))
					var h := rng.randf_range(5.0, 6.8)
					var cr := h * rng.randf_range(0.26, 0.31)
					var tb := Basis(Vector3.UP, rng.randf() * TAU)
					trunks.append(Transform3D(tb.scaled_local(Vector3(h * 0.15, h * 0.70, h * 0.15)), p3))
					var c_xf := Transform3D(tb.scaled_local(Vector3(cr * 1.48, h * 0.58, cr * 1.48)), p3 + Vector3(0.0, h * 0.44, 0.0))
					if (placed_pts.size() & 1) == 0:
						crowns0.append(c_xf)
					else:
						crowns1.append(c_xf)
				acc += step
			acc -= sl
	if trunks.is_empty():
		return
	var M_PIT := A.concrete(Color(0.58, 0.56, 0.52), false)
	var M_SOIL := A.paint(Color(0.22, 0.19, 0.15), 0.0, 0.96, {"panel_scale": 0.0, "wear": 0.25})
	_multimesh(A.bevel_box(Vector3.ONE, 0.04), M_PIT, pits, false)
	_multimesh(A.bevel_box(Vector3.ONE, 0.02), M_SOIL, soils, false)
	_multimesh(A.tree_trunk_mesh(0), A.bark_mat(Color(0.28, 0.24, 0.20)), trunks, true)
	_multimesh(A.broad_crown_mesh(0), A.foliage_mat("broad"), crowns0, true)
	_multimesh(A.broad_crown_mesh(1), A.foliage_mat("broad"), crowns1, true)


func _block_residential(blk: Dictionary) -> void:
	# 独栋小楼的院墙（不完整，顺着楼的朝向，带压顶石与端头砖柱）
	var poly: PackedVector2Array = blk.poly
	var M := A.concrete(Color(0.54, 0.51, 0.46), false)
	var M_CAP := A.concrete(Color(0.42, 0.40, 0.37), false)
	var inner := WC.inset(poly, 0.6)
	if inner.size() < 3:
		return
	var m := inner.size()
	for i in m:
		if rng.randf() < 0.45:
			continue
		var a := inner[i]
		var b := inner[(i + 1) % m]
		var L := a.distance_to(b)
		if L < 4.0:
			continue
		var seg_len := L * rng.randf_range(0.3, 0.7)
		var t0 := rng.randf_range(0.0, L - seg_len)
		var dir := (b - a) / L
		var mid := a + dir * (t0 + seg_len * 0.5)
		var p := Vector3(mid.x, 0.62, mid.y)
		if _blocked(p, 0.8, false) or on_road(mid, 0.5) or _in_keep_clear(p, seg_len * 0.5 + 0.4):
			continue
		var wl := _static_box(Vector3(seg_len, 1.25, 0.35), p, Color.WHITE, null, M)
		wl.rotation.y = -atan2(dir.y, dir.x)
		_ibox(wl, Vector3(seg_len + 0.12, 0.11, 0.46), 0.02, M_CAP, Vector3(0, 0.64, 0))
		_ibox(wl, Vector3(seg_len + 0.08, 0.22, 0.42), 0.02, M_CAP, Vector3(0, -0.51, 0))
		for ex_s in [-1.0, 1.0]:
			_ibox(wl, Vector3(0.46, 1.38, 0.50), 0.03, M_CAP, Vector3(ex_s * (seg_len * 0.5 - 0.16), 0.04, 0))
		_obb_blocks(mid, atan2(dir.y, dir.x), seg_len, 0.6)
	if not _decorate_urban_open_lot(blk) and rng.randf() < 0.25:
		var p := _spot_in_poly(poly, 3.2)
		if p != Vector3.INF and not on_road(Vector2(p.x, p.z), 2.5):
			_wreck_car(p, rad_to_deg(-float(blk.ang)) + (0.0 if rng.randf() < 0.5 else 90.0), 0.86)
	var r_pc := WC.centroid(poly)
	var r_lot := Vector3(r_pc.x, 0.0, r_pc.y)
	if in_bounds(r_lot, 8.0) and not on_road(r_pc, 2.5) and not _blocked(r_lot, 1.8, false):
		var r_out := Vector3(-sin(float(blk.ang)), 0.0, cos(float(blk.ang)))
		register_loot_anchor(r_lot, _face_outward_yaw(r_out), "car_wreck", 72, "parking_car", r_out)


func _block_industrial(blk: Dictionary) -> void:
	var poly: PackedVector2Array = blk.poly
	var ang: float = blk.ang
	for k in rng.randi_range(1, 3):
		var p := _spot_in_poly(poly, 4.2)
		if p != Vector3.INF:
			_tank(p, rng.randf_range(2.6, 4.0), rng.randf_range(5.0, 9.0))
	for k in rng.randi_range(1, 3):
		var p := _spot_in_poly(poly, 3.6)
		if p != Vector3.INF:
			var rot := rad_to_deg(-ang) + (0.0 if rng.randf() < 0.6 else 90.0)
			_container(p, rot, [Color(0.28, 0.46, 0.62), Color(0.74, 0.36, 0.20), Color(0.40, 0.52, 0.34), Color(0.68, 0.58, 0.34), Color(0.70, 0.68, 0.62)][rng.randi() % 5])
			_obb_blocks(Vector2(p.x, p.z), deg_to_rad(-rot) + PI * 0.5, 6.4, 2.8)
			var door_dir := Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, deg_to_rad(rot))
			var flank_dir := Vector3(1.0, 0.0, 0.0).rotated(Vector3.UP, deg_to_rad(rot))
			register_loot_anchor(p + door_dir * 4.35, _face_outward_yaw(door_dir), "tool", 82, "ind_container", door_dir)
			register_loot_anchor(p + flank_dir * 2.85, _face_outward_yaw(flank_dir), "container", 81, "ind_container", flank_dir)
	if rng.randf() < 0.55:
		var p := _spot_in_poly(poly, 5.0)
		if p != Vector3.INF:
			_chimney(p)
	_fence_poly(poly, 2.4, 0.35)


func _block_harbor(blk: Dictionary) -> void:
	var poly: PackedVector2Array = blk.poly
	var ang: float = blk.ang
	var cols := [Color(0.28, 0.46, 0.62), Color(0.74, 0.36, 0.20), Color(0.40, 0.52, 0.34), Color(0.72, 0.58, 0.28), Color(0.66, 0.26, 0.22), Color(0.72, 0.70, 0.64)]
	# 集装箱堆场：顺着街块朝向按网格成排摆放、两层对齐
	var core := WC.inset(poly, 3.2)
	if core.size() >= 3:
		var u := Vector2(cos(ang), sin(ang))
		var v := Vector2(-sin(ang), cos(ang))
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for q in core:
			lo = Vector2(minf(lo.x, q.dot(u)), minf(lo.y, q.dot(v)))
			hi = Vector2(maxf(hi.x, q.dot(u)), maxf(hi.y, q.dot(v)))
		var rot := rad_to_deg(-ang) + 90.0
		var max_c := roundi(WC.poly_area(poly) / 200.0)
		var put := 0
		var tv := lo.y + 2.2
		while tv < hi.y - 1.8 and put < max_c:
			var tu := lo.x + 3.6
			while tu < hi.x - 3.2 and put < max_c:
				var q := u * tu + v * tv
				var p := Vector3(q.x, 0, q.y)
				if WC.in_convex(core, q) and in_bounds(p, 6.0) and not _blocked(p, 3.4) and rng.randf() < 0.72:
					_container(p, rot, cols[rng.randi() % cols.size()])
					if rng.randf() < 0.45:
						_container(p + Vector3(0, 2.48, 0), rot, cols[rng.randi() % cols.size()])
					_obb_blocks(q, deg_to_rad(-rot) + PI * 0.5, 6.4, 2.8)
					var door_dir := Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, deg_to_rad(rot))
					var flank_dir := Vector3(1.0, 0.0, 0.0).rotated(Vector3.UP, deg_to_rad(rot))
					var c_kind := "military" if (put % 5 == 0) else ("container" if (put % 3 == 0) else ("tool" if (put % 2 == 0) else "supply"))
					register_loot_anchor(p + door_dir * 4.35, _face_outward_yaw(door_dir), c_kind, 85, "harbor_container", door_dir)
					register_loot_anchor(p - door_dir * 4.35, _face_outward_yaw(-door_dir), "supply" if c_kind == "container" else c_kind, 84, "harbor_container", -door_dir)
					register_loot_anchor(p + flank_dir * 2.65, _face_outward_yaw(flank_dir), "container" if (put % 2 == 0) else "tool", 83, "harbor_container", flank_dir)
					register_loot_anchor(p - flank_dir * 2.65, _face_outward_yaw(-flank_dir), "supply", 83, "harbor_container", -flank_dir)
					put += 1
				tu += 7.4
			tv += 4.2
	# 重型集装箱龙门吊与钢轨堆场（B6-29 poi_gantry_rail）
	if rng.randf() < 0.45:
		var p := _spot_in_poly(poly, 6.6, 20)
		if p != Vector3.INF:
			PrefabLib.place_at_ground(self, world, "poi_gantry_rail", p + Vector3(0.0, -0.04, 0.0), rad_to_deg(-ang), Vector3(15.8, 12.4, 10.2), false, null, true)
			var u_g := Vector3(cos(ang), 0.0, sin(ang))
			for lx_g in [-6.8, 6.8]:
				var leg_sb := _bldg_body(Vector3(1.5, 11.6, 4.2), p + u_g * lx_g + Vector3(0.0, 5.8, 0.0))
				leg_sb.rotation.y = -ang
			blocks.append(Rect2(p.x - 6.8, p.z - 5.2, 13.6, 10.4))
			var v_g := Vector3(-sin(ang), 0.0, cos(ang))
			register_loot_anchor(p + u_g * 4.4 + v_g * 6.4, _face_outward_yaw(v_g), "container", 88, "gantry", v_g)
			register_loot_anchor(p - u_g * 4.4 - v_g * 6.4, _face_outward_yaw(-v_g), "tool", 85, "gantry", -v_g)


func _block_railyard(blk: Dictionary) -> void:
	# 停在编组站铁轨上的车厢
	var poly: PackedVector2Array = blk.poly
	for l: Array in rail_lines:
		var a: Vector2 = l[0]
		var b: Vector2 = l[1]
		var m := (a + b) * 0.5
		if not WC.in_convex(WC.inset(poly, -6.0), m) or rng.randf() > 0.45:
			continue
		var t := (b - a).normalized()
		var p := Vector3(m.x, 0, m.y)
		if _blocked(p, 1.0, false):
			continue
		var horiz := absf(t.x) > absf(t.y)
		_wagon(p, horiz)
		var side_v := Vector3(0.0, 0.0, 1.0) if horiz else Vector3(1.0, 0.0, 0.0)
		register_loot_anchor(p + side_v * 3.10, _face_outward_yaw(side_v), "tool", 86, "wagon", side_v)
		register_loot_anchor(p - side_v * 3.10, _face_outward_yaw(-side_v), "supply", 82, "wagon", -side_v)
	var q := _spot_in_poly(poly, 3.0, 20)
	if q != Vector3.INF and rng.randf() < 0.5:
		_watchtower(q)


func _block_military(blk: Dictionary) -> void:
	var M_HESCO := A.paint(Color(0.55, 0.5, 0.38), 0.0, 0.95, {"wear": 0.3, "dust": 0.7, "grime": 0.6, "panel_scale": 0.85})
	var M_HFRAME := A.metal(Color(0.28, 0.30, 0.29))
	var M_HFILL := A.rock_mat(Color(0.34, 0.30, 0.24))
	var poly: PackedVector2Array = WC.inset(blk.poly, 1.5)
	if poly.size() < 3 or WC.poly_area(poly) < 300.0:
		return
	var m := poly.size()
	# 防爆墙围栏：沿街块边，每条边留一个门（HESCO 金属网笼肋条 + 顶部填砂砾石层）
	for i in m:
		var a := poly[i]
		var b := poly[(i + 1) % m]
		var L := a.distance_to(b)
		if L < 4.0:
			continue
		var dir := (b - a) / L
		var seg := 2.2
		var n := int(L / seg)
		var gate := rng.randi_range(int(n * 0.3), int(n * 0.7))
		for k in n:
			if absi(k - gate) <= 1 or rng.randf() < 0.06:
				continue
			var q := a + dir * ((k + 0.5) * L / n)
			var pos := Vector3(q.x, 1.2, q.y)
			if on_road(q, 0.3) or _blocked(pos, 0.4, false) or _in_keep_clear(pos, L / n * 0.5 + 0.7):
				continue
			var hw_seg := L / n - 0.1
			var sb := _static_box(Vector3(hw_seg, 2.4, 1.2), pos, Color.WHITE, null, M_HESCO)
			sb.rotation.y = -atan2(dir.y, dir.x)
			_ibox(sb, Vector3(hw_seg - 0.14, 0.10, 1.04), 0.02, M_HFILL, Vector3(0, 1.18, 0), Vector3.ZERO, Vector3.ONE, false)
			_ibox(sb, Vector3(hw_seg + 0.04, 0.07, 1.26), 0.01, M_HFRAME, Vector3(0, 0.0, 0), Vector3.ZERO, Vector3.ONE, false)
			for rx_h in [-hw_seg * 0.46, 0.0, hw_seg * 0.46]:
				_ibox(sb, Vector3(0.06, 2.42, 1.26), 0.01, M_HFRAME, Vector3(rx_h, 0.0, 0), Vector3.ZERO, Vector3.ONE, false)
			_obb_blocks(q, atan2(dir.y, dir.x), L / n, 1.4)
	var core := WC.inset(poly, 5.0)
	if core.size() < 3:
		return
	# 废弃军用机甲整备龙门架（hub_mech_docking_bay，BAY-01 战损整备台）：大块军事基地中心优先布设 1 座
	var bay_p := _spot_in_poly(core, 5.8, 16)
	if bay_p != Vector3.INF:
		var bay_yaw := float(rng.randi_range(0, 3)) * 90.0
		var bay_rad := deg_to_rad(bay_yaw)
		PrefabLib.place_at_ground(self, world, "hub_mech_docking_bay", bay_p + Vector3(0.0, -0.04, 0.0), bay_yaw, Vector3(9.0, 8.8, 7.2), false, null, false)
		for sx_g: float in [-3.55, 3.55]:
			var gp := bay_p + Vector3(sx_g, 0.0, -0.75).rotated(Vector3.UP, bay_rad)
			var gsb := _bldg_body(Vector3(1.4, 7.6, 2.2), gp + Vector3(0.0, 3.8, 0.0))
			gsb.rotation.y = bay_rad
		blocks.append(_rect_for(bay_p, Vector3(10.0, 1.0, 8.2)))
		add_contact_shadow(bay_p, 10.6, 8.6, bay_yaw)
		var bay_fwd := Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, bay_rad)
		register_loot_anchor(bay_p + bay_fwd * 4.9, _face_outward_yaw(bay_fwd), "military", 97, "mech_docking_bay", bay_fwd)
	for k in 2:
		var p := _spot_in_poly(core, 4.0)
		if p != Vector3.INF:
			_bunker(p)
	for i in [0, m / 2]:
		var cp: Vector2 = poly[i].lerp(WC.centroid(poly), 0.12)
		if not _blocked(Vector3(cp.x, 0, cp.y), 1.5, false):
			_watchtower(Vector3(cp.x, 0, cp.y))
	for k in rng.randi_range(2, 4):
		var p := _spot_in_poly(core, 2.5)
		if p != Vector3.INF:
			_sandbags(p, rng.randf() * 180.0)
	var lc := WC.centroid(core)
	spawn_bug("beetle", Vector3(lc.x, 0.5, lc.y))


## 沿凸多边形边的重工钢栅栏围栏（混凝土矮基座 + 工字钢立柱 + 镂空竖向方钢栅条 + 顶部外倾防攀爬横梁，随机留缺口）
func _fence_poly(poly: PackedVector2Array, hgt: float, gap_chance: float) -> void:
	var inner := WC.inset(poly, 1.0)
	var m := inner.size()
	if m < 3:
		return
	var M_CURB := A.concrete(Color(0.42, 0.40, 0.37), false)
	var MP := A.paint(Color(0.24, 0.25, 0.26), 0.62, 0.56, {"rust": 0.62, "wear": 0.45, "panel_scale": 0.0})
	var MR := A.metal(Color(0.16, 0.17, 0.18))
	for i in m:
		var a := inner[i]
		var b := inner[(i + 1) % m]
		var L := a.distance_to(b)
		var n := int(L / 4.0)
		if n < 1:
			continue
		var dir := (b - a) / L
		var seg_w := L / float(n)
		var prev_seg_k := -2
		var forced_gate := (n / 2) if (n >= 2 and gap_chance > 0.0) else -1
		for k in n:
			if k == forced_gate or rng.randf() < gap_chance:
				continue
			var q := a + dir * ((k + 0.5) * seg_w)
			var pos := Vector3(q.x, hgt * 0.5, q.y)
			if not in_bounds_xz(q, 3.5) or _blocked(pos, 0.6) or _in_keep_clear(pos, seg_w * 0.5 + 0.2):
				continue
			var sb := _bldg_body(Vector3(seg_w, hgt, 0.16), pos)
			sb.rotation.y = -atan2(dir.y, dir.x)
			_ibox(sb, Vector3(seg_w - 0.02, 0.28, 0.26), 0.02, M_CURB, Vector3(0, -hgt * 0.5 + 0.14, 0))
			for px_s in ([-0.5, 0.5] if k != prev_seg_k + 1 else [0.5]):
				_ibox(sb, Vector3(0.14, hgt + 0.24, 0.16), 0.015, MP, Vector3(px_s * seg_w, 0.10, 0))
			for ry_f in [-hgt * 0.22, hgt * 0.34]:
				_ibox(sb, Vector3(seg_w - 0.02, 0.07, 0.09), 0.01, MR, Vector3(0, ry_f, 0), Vector3.ZERO, Vector3.ONE, false)
			var n_pk := maxi(3, int(seg_w / 0.44))
			for pk in n_pk:
				if pk == 0:
					continue
				var kx := -seg_w * 0.5 + pk * seg_w / float(n_pk)
				_ibox(sb, Vector3(0.045, hgt - 0.18, 0.045), 0.005, MP, Vector3(kx, 0.06, 0), Vector3.ZERO, Vector3.ONE, false)
			_ibox(sb, Vector3(seg_w - 0.02, 0.05, 0.24), 0.008, MR, Vector3(0, hgt * 0.5 + 0.14, 0.08), Vector3(-32, 0, 0), Vector3.ONE, false)
			_obb_blocks(q, atan2(dir.y, dir.x), seg_w, 0.4)
			prev_seg_k = k


# ---------- 农田 ----------
func _build_fields(sliced := false) -> void:
	rng.seed = _map_seed(9)
	var stalks: Array = []
	var st_berm := SurfaceTool.new()
	st_berm.begin(Mesh.PRIMITIVE_TRIANGLES)
	var berm_polys: Array = []
	for fd: Dictionary in layout.fields:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		var poly: PackedVector2Array = fd.poly
		if poly.size() < 3:
			continue
		# 田块四周压实田埂护边（收束农田与荒地/土路交界，消除突兀多边形切边；去重发射免转角叠闪）
		for ei in poly.size():
			var ea := poly[ei]
			var eb := poly[(ei + 1) % poly.size()]
			var em := (ea + eb) * 0.5
			if absf(em.x) < EXT_HALF and absf(em.y) < EXT_HALF and zone_at(Vector3(em.x, 0, em.y)) == "F" and not on_road(em, 1.5) and not in_river(em, 2.0):
				berm_polys.append_array(_outers(Geometry2D.offset_polyline(PackedVector2Array([ea, eb]), 0.675, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)))
		var u := Vector2(cos(fd.ang), sin(fd.ang))
		var v := Vector2(-sin(fd.ang), cos(fd.ang))
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for q in poly:
			lo = Vector2(minf(lo.x, q.dot(u)), minf(lo.y, q.dot(v)))
			hi = Vector2(maxf(hi.x, q.dot(u)), maxf(hi.y, q.dot(v)))
		var t := lo.y + 1.8
		var ph_x := rng.randf() * TAU
		var ph_z := rng.randf() * TAU
		while t < hi.y:
			var seg := _line_in_poly(poly, v * t, u)
			if seg.size() == 2:
				var L := seg[0].distance_to(seg[1])
				var n := int(L / 0.85)
				for i in n:
					var q0 := seg[0].lerp(seg[1], (i + 0.5) / n)
					var q := q0 + u * rng.randf_range(-0.48, 0.48) + v * rng.randf_range(-0.68, 0.68)
					var patch := 0.52 + 0.34 * sin(q.x * 0.11 + ph_x) * cos(q.y * 0.09 + ph_z) + 0.18 * sin((q.x - q.y) * 0.045)
					if rng.randf() > patch:
						continue
					if absf(q.x) > EXT_HALF or absf(q.y) > EXT_HALF:
						continue
					if zone_at(Vector3(q.x, 0, q.y)) != "F" or in_river(q, 1.0) or in_wet(q, 2.0) or on_road(q, 0.7):
						continue
					var hh := rng.randf_range(0.42, 1.12) * lerpf(0.82, 1.18, clampf(patch, 0.0, 1.0))
					var hw := hh * rng.randf_range(0.78, 1.14)
					stalks.append(Transform3D(_rand_basis(14).scaled_local(Vector3(hw, hh, hw)), Vector3(q.x, 0.0, q.y)))
			t += rng.randf_range(2.05, 3.15)
		# 田块边缘荒原枯木与耐旱沙棘生态群落（B5-25 ter_arid_flora_pylon）
		if WC.poly_area(poly) > 420.0 and rng.randf() < 0.38:
			var fp := _spot_in_poly(poly, 5.2)
			if fp != Vector3.INF and zone_at(fp) == "F" and not on_road(Vector2(fp.x, fp.z), 4.5):
				PrefabLib.place_at_ground(self, world, "ter_arid_flora_pylon", fp + Vector3(0.0, -0.10, 0.0), rng.randf() * 360.0, Vector3(8.4, 4.2, 6.4), false)
				_bldg_body(Vector3(2.0, 2.2, 2.0), fp + Vector3(0.0, 1.1, 0.0))
				blocks.append(Rect2(fp.x - 3.6, fp.z - 3.0, 7.2, 6.0))
		# 圆柱捆扎干草垛（取代黄色直角方块：机械打捆圆草卷 + 深色捆绳箍 + 双捆堆叠变体）
		var M_BALE := A.paint(Color(0.52, 0.44, 0.26), 0.0, 1.0, {"wear": 0.15, "dust": 0.55, "grime": 0.65, "panel_scale": 0.0})
		var M_TWINE := A.paint(Color(0.18, 0.15, 0.12), 0.0, 0.95, {"panel_scale": 0.0})
		for k in rng.randi_range(2, 5):
			var p := _spot_in_poly(poly, 1.6)
			if p != Vector3.INF and zone_at(p) == "F":
				var stacked := rng.randf() < 0.45
				var hs := _bldg_body(Vector3(2.2 if stacked else 1.5, 1.9 if stacked else 1.3, 1.6), p + Vector3(0, 0.95 if stacked else 0.65, 0))
				hs.rotation_degrees.y = rng.randf() * 180.0
				var hy_b := 0.95 if stacked else 0.65
				if stacked:
					for bx_o in [-0.62, 0.62]:
						_imesh(hs, A.cyl(0.62, 1.45, 0.62, 16), M_BALE, Vector3(bx_o, -hy_b + 0.58, 0), Vector3(90, 0, 0))
						for tz_o in [-0.38, 0.38]:
							_imesh(hs, A.cyl(0.635, 0.05, 0.635, 16), M_TWINE, Vector3(bx_o, -hy_b + 0.58, tz_o), Vector3(90, 0, 0), Vector3.ONE, false)
					_imesh(hs, A.cyl(0.58, 1.42, 0.58, 16), M_BALE, Vector3(0, -hy_b + 1.52, 0), Vector3(90, 4, 0))
				else:
					_imesh(hs, A.cyl(0.66, 1.55, 0.66, 16), M_BALE, Vector3(0, -hy_b + 0.62, 0), Vector3(90, 0, 0))
					for tz_o in [-0.42, 0.42]:
						_imesh(hs, A.cyl(0.675, 0.05, 0.675, 16), M_TWINE, Vector3(0, -hy_b + 0.62, tz_o), Vector3(90, 0, 0), Vector3.ONE, false)
				blocks.append(_rect_for(p, Vector3(2.4, 1, 2.4)))
	var n_berm := _emit_soft_polys(st_berm, _merge_polys(berm_polys), 0.72, 0.044)
	var berm_c := ground_dust_tint().darkened(0.28)
	var M_BERM: ShaderMaterial = _terrain_feather_mat(Color(berm_c.r, berm_c.g, berm_c.b, 0.56), 0.38, 0.95, 0.08, -9)
	_st_commit(st_berm, M_BERM, n_berm)
	_multimesh(A.grass_clump_mesh(), A.foliage_mat("grass"), stalks, false)


# ---------- 自然地表与散布物：按 3 米抖动格点逐点看区块字符决定摆什么 ----------
## 区块危险度权重（供 _place_box 判定容器品质档位；物资箱不再在 3m 空地网格随机撒落，统一由 _place_contextual_loot 贴靠合理建筑/掩体/地标固定落位）
const LOOT_RATE := {"D": 0, "R": 0, "I": 0, "H": 0, "Y": 0, "M": 0, "W": 0, "F": 0, "P": 0, "T": 0, "C": 0, "S": 0, "K": 0, "L": 0}
const LOOT_W := {"D": {"supply": 30, "tool": 30, "military": 22, "safe": 18}, "R": {"supply": 50, "tool": 35, "military": 5, "safe": 10},
	"I": {"supply": 15, "tool": 55, "military": 20, "safe": 10}, "H": {"supply": 30, "tool": 45, "military": 15, "safe": 10},
	"Y": {"supply": 25, "tool": 50, "military": 15, "safe": 10}, "M": {"supply": 10, "tool": 15, "military": 55, "safe": 20},
	"W": {"supply": 40, "tool": 40, "military": 12, "safe": 8},
	"F": {"supply": 60, "tool": 30, "military": 4, "safe": 6}, "P": {"supply": 55, "tool": 25, "military": 8, "safe": 12},
	"T": {"supply": 50, "tool": 30, "military": 10, "safe": 10}, "C": {"supply": 15, "tool": 25, "military": 50, "safe": 10},
	"S": {"supply": 20, "tool": 20, "military": 35, "safe": 25}, "L": {"supply": 45, "tool": 35, "military": 10, "safe": 10}}


func _scatter(sliced := false) -> void:
	rng.seed = _map_seed(10)
	var trunks_0: Array = []
	var trunks_1: Array = []
	var pines_0: Array = []
	var pines_1: Array = []
	var broads_0: Array = []
	var broads_1: Array = []
	var autumns: Array = []
	var tree_buckets: Array = [trunks_0, trunks_1, pines_0, pines_1, broads_0, broads_1, autumns]
	var rims: Array = []
	var pods: Array = []
	var reeds: Array = []
	var tree_body := StaticBody3D.new()
	tree_body.collision_layer = 1
	tree_body.set_meta("water_bank", true)
	world.add_child(tree_body)
	var BARK := A.bark_mat()
	var M_SHRUB := A.foliage_mat("shrub")
	var BENCH := A.paint(Color(0.32, 0.25, 0.18), 0.0, 0.9, {"wear": 0.5, "dust": 0.5, "panel_scale": 0.0})
	# 悬崖岩体：5.5 米格点上层叠大岩块（不可通行），K 区边缘的岩块矮一些、稀一些
	_scatter_cliffs()
	# 公园中心：雕像基座 + 环形步道
	for c2: Vector2 in layout.parks:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		var c := Vector3(c2.x, 0, c2.y)
		if in_bounds(c, 12.0) and zone_at(c) == "P" and not _blocked(c, 8.0):
			_park_statue(c)
	# 虫巢：每片菌毯区一座虫巢（按数据格子分组）
	_hive_nests()
	var step := 3.0
	var gz := -HALF + 1.5
	while gz < HALF - 1.0:
		if sliced and Time.get_ticks_usec() >= _load_slice_deadline:
			await _yield_load_slice()
		var gx := -HALF + 1.5
		while gx < HALF - 1.0:
			var p := Vector3(gx + rng.randf_range(-1.2, 1.2), 0, gz + rng.randf_range(-1.2, 1.2))
			gx += step
			if not in_bounds(p, 3.5):
				continue
			var ch := zone_at(p)
			var _skip_loot_roll := rng.randf()
			var roll := rng.randf()
			match ch:
				"T":
					if roll < 0.36 and not _blocked(p, 1.1):
						if rng.randf() < 0.12:
							_dead_tree(p)
							blocks.append(Rect2(p.x - 0.5, p.z - 0.5, 1, 1))
						else:
							_tree(p, tree_buckets, tree_body)
					elif roll < 0.38 and not _blocked(p, 2.5):
						var L := rng.randf_range(3.0, 6.0)
						var sb := _bldg_body(Vector3(0.66, 0.62, L), p + Vector3(0, 0.31, 0))
						sb.rotation_degrees.y = rng.randf() * 180.0
						var M_CUT := A.paint(Color(0.44, 0.34, 0.22), 0.0, 0.95, {"panel_scale": 0.0, "dust": 0.35})
						_imesh(sb, A.cyl(0.26, L, 0.31, 12), BARK, Vector3(0, -0.02, 0), Vector3(90, 0, 0))
						_imesh(sb, A.cyl(0.23, 0.03, 0.23, 12), M_CUT, Vector3(0, -0.02, L * 0.5 + 0.01), Vector3(90, 0, 0), Vector3.ONE, false)
						_imesh(sb, A.cyl(0.28, 0.03, 0.28, 12), M_CUT, Vector3(0, -0.02, -L * 0.5 - 0.01), Vector3(90, 0, 0), Vector3.ONE, false)
						_imesh(sb, A.cyl(0.07, 0.68, 0.11, 8), BARK, Vector3(0.22, 0.18, rng.randf_range(-0.6, 0.6)), Vector3(12, 0, -48), Vector3.ONE, false)
						blocks.append(_rect_for(p, Vector3(L, 1, L) * 0.7))
				"P":
					if roll < 0.12 and not _blocked(p, 1.0):
						if rng.randf() < 0.28:
							_dead_tree(p)
							blocks.append(Rect2(p.x - 0.5, p.z - 0.5, 1, 1))
						else:
							_tree(p, tree_buckets, tree_body)
					elif roll < 0.145 and not _blocked(p, 1.2):
						var n := Node3D.new()
						world.add_child(n)
						n.position = p
						n.rotation.y = rng.randi_range(0, 3) * PI * 0.5
						A.add(n, A.bevel_box(Vector3(1.85, 0.08, 0.48), 0.02), BENCH, Vector3(0, 0.45, 0))
						A.add(n, A.bevel_box(Vector3(1.85, 0.38, 0.06), 0.02), BENCH, Vector3(0, 0.70, -0.24), Vector3(-10, 0, 0))
						for sx in [-0.82, 0.82]:
							A.add(n, A.bevel_box(Vector3(0.08, 0.45, 0.46), 0.01), A.metal(), Vector3(sx, 0.22, 0))
							A.add(n, A.bevel_box(Vector3(0.07, 0.05, 0.48), 0.01), A.metal(), Vector3(sx, 0.60, -0.02))
					elif roll < 0.163 and not _blocked(p, 3.0):
						var horiz_h := rng.randf() < 0.5
						var len_h := rng.randf_range(4.2, 7.6)
						var size := Vector3(len_h, 0.9, 1.1) if horiz_h else Vector3(1.1, 0.9, len_h)
						var n := Node3D.new()
						world.add_child(n)
						n.position = p
						var M_CURB_P := A.concrete(Color(0.46, 0.44, 0.40), false)
						var M_SOIL_P := A.gravel_mat(Color(0.24, 0.20, 0.16))
						A.add(n, A.bevel_box(Vector3(size.x + 0.36, 0.38, size.z + 0.36), 0.04), M_CURB_P, Vector3(0, 0.19, 0))
						A.add(n, A.bevel_box(Vector3(size.x + 0.06, 0.08, size.z + 0.06), 0.02), M_SOIL_P, Vector3(0, 0.36, 0), Vector3.ZERO, Vector3.ONE, false)
						var n_bush := maxi(3, int(len_h / 1.10))
						for bi in n_bush:
							var bt := -len_h * 0.42 + (float(bi) + 0.5) * (len_h * 0.84) / float(n_bush)
							var bpos := Vector3(bt, 0.38, rng.randf_range(-0.12, 0.12)) if horiz_h else Vector3(rng.randf_range(-0.12, 0.12), 0.38, bt)
							var bsc := rng.randf_range(0.72, 1.02)
							_imesh(n, A.shrub_mesh(bi % 4), M_SHRUB, bpos,
								Vector3(0.0, rng.randf() * 360.0, 0.0),
								Vector3(bsc * 1.10, bsc * 0.95, bsc * 1.10))
						blocks.append(_rect_for(p, size))
				"W":
					if roll < 0.025 and not _blocked(p, 3.0):
						var r2 := rng.randf()
						if r2 < 0.32:
							_boulder(p, rng.randf_range(1.5, 4.5))
						elif r2 < 0.52:
							var horiz_w := rng.randf() < 0.5
							var size := Vector3(rng.randf_range(6, 12), rng.randf_range(1.4, 3.0), 0.8) if horiz_w else Vector3(0.8, rng.randf_range(1.4, 3.0), rng.randf_range(6, 12))
							var wsb := _static_box(size, p + Vector3(0, size.y * 0.5, 0), Color(0.50, 0.46, 0.42))
							_ibox(wsb, Vector3(size.x + 0.18, 0.30, size.z + 0.18), 0.03, A.concrete(Color(0.36, 0.34, 0.31), false), Vector3(0, -size.y * 0.5 + 0.15, 0))
							for wp_s in [-0.36, 0.36]:
								var p_sz := Vector3(0.44, size.y * 0.92, 1.08) if horiz_w else Vector3(1.08, size.y * 0.92, 0.44)
								var p_ps := Vector3(wp_s * size.x, -size.y * 0.04, 0) if horiz_w else Vector3(0, -size.y * 0.04, wp_s * size.z)
								_ibox(wsb, p_sz, 0.03, A.concrete(Color(0.42, 0.39, 0.36), false), p_ps)
							blocks.append(_rect_for(p, size))
						elif r2 < 0.68 and not _blocked(p, 5.4) and not on_road(Vector2(p.x, p.z), 4.5):
							var yaw_fl := rng.randf() * 360.0
							var sc_fl := rng.randf_range(0.85, 1.10)
							PrefabLib.place_at_ground(self, world, "ter_arid_flora_pylon", p + Vector3(0.0, -0.11, 0.0), yaw_fl, Vector3(10.8, 5.4, 8.2) * sc_fl, false)
							var py_sb := _bldg_body(Vector3(2.4, 2.6, 2.4), p + Vector3(0.0, 1.3, 0.0))
							py_sb.rotation_degrees.y = yaw_fl
							blocks.append(Rect2(p.x - 4.4 * sc_fl, p.z - 3.6 * sc_fl, 8.8 * sc_fl, 7.2 * sc_fl))
							var fl_out := Vector3(1.0, 0.0, 0.0).rotated(Vector3.UP, deg_to_rad(yaw_fl))
							register_loot_anchor(p + fl_out * (4.8 * sc_fl), _face_outward_yaw(fl_out), "cache", 76, "wild_cache", fl_out)
						elif r2 < 0.77 and not _blocked(p, 5.4) and not on_road(Vector2(p.x, p.z), 4.5):
							var yaw_dt := rng.randf() * 360.0
							PrefabLib.place_at_ground(self, world, "ter_dragon_teeth_pipe", p + Vector3(0.0, -0.10, 0.0), yaw_dt, Vector3(10.4, 2.3, 7.6), false)
							var dt_sb := _bldg_body(Vector3(8.6, 1.5, 3.0), p + Vector3(0.0, 0.75, 0.0))
							dt_sb.rotation_degrees.y = yaw_dt
							blocks.append(Rect2(p.x - 4.8, p.z - 3.8, 9.6, 7.6))
							var dt_out := Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, deg_to_rad(yaw_dt))
							register_loot_anchor(p + dt_out * 4.9, _face_outward_yaw(dt_out), "ammo", 82, "sandbags", dt_out)
						elif r2 < 0.84:
							_dead_tree(p)
						elif r2 < 0.92:
							_wreck_car(p)
						else:
							var sz := Vector3(rng.randf_range(5, 8.5), rng.randf_range(2.2, 4.0), rng.randf_range(5, 8.5))
							if not _blocked(p, maxf(sz.x, sz.z) * 0.65 + 2.6):
								_building(p, sz)
								blocks.append(_rect_for(p, sz + Vector3(1.6, 0, 1.6)))
								register_loot_anchor(p + Vector3(0.0, 0.0, sz.z * 0.5 + 1.45), _face_outward_yaw(Vector3(0, 0, 1)), "supply", 76, "bldg:ruin", Vector3(0, 0, 1), p)
								register_loot_anchor(p + Vector3(0.0, 0.0, -sz.z * 0.5 - 1.45), _face_outward_yaw(Vector3(0, 0, -1)), "cache", 78, "wild_cache", Vector3(0, 0, -1), p)
				"C":
					if roll < 0.04 and not _blocked(p, 3.0):
						_crater(p, rims)
					elif roll < 0.05 and not _blocked(p, 3.5):
						_tank_wreck(p)
					elif roll < 0.052 and not _blocked(p, 1.5):
						_fire_barrel(p)
					elif roll < 0.058 and not _blocked(p, 5.4) and not on_road(Vector2(p.x, p.z), 4.5):
						var yaw_dtc := rng.randf() * 360.0
						PrefabLib.place_at_ground(self, world, "ter_dragon_teeth_pipe", p + Vector3(0.0, -0.10, 0.0), yaw_dtc, Vector3(10.4, 2.3, 7.6), false)
						var dtc_sb := _bldg_body(Vector3(8.6, 1.5, 3.0), p + Vector3(0.0, 0.75, 0.0))
						dtc_sb.rotation_degrees.y = yaw_dtc
						blocks.append(Rect2(p.x - 4.8, p.z - 3.8, 9.6, 7.6))
						var dtc_out := Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, deg_to_rad(yaw_dtc))
						register_loot_anchor(p + dtc_out * 4.9, _face_outward_yaw(dtc_out), "ammo", 84, "sandbags", dtc_out)
				"S":
					if roll < 0.15 and not in_wet(Vector2(p.x, p.z), 6.0):
						var d := A.ground_decal(world, A.cloud_tex(), Color(0.13, 0.08, 0.15, rng.randf_range(0.45, 0.75)), rng.randf_range(4.0, 9.0), p + Vector3(0, 0.036 + rng.randf() * 0.003, 0))
						d.rotation.y = rng.randf() * TAU
					if rng.randf() < 0.064 and not _blocked(p, 1.2):
						_bug_spire(p, rng.randf_range(2.5, 7.0))
					for k in 3:
						if rng.randf() < 0.12:
							var q := p + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5))
							if not on_road(Vector2(q.x, q.z)) and not in_wet(Vector2(q.x, q.z), 2.0):
								var s := rng.randf_range(0.15, 0.45)
								pods.append(Transform3D(Basis.IDENTITY.scaled(Vector3(s, s * 0.7, s)), q + Vector3(0, s * 0.25, 0)))
				"L":
					if roll < 0.3 and not in_wet(Vector2(p.x, p.z), 1.5) and not on_road(Vector2(p.x, p.z), 0.5):
						for k in rng.randi_range(2, 5):
							var q := p + Vector3(rng.randf_range(-1.4, 1.4), 0, rng.randf_range(-1.4, 1.4))
							if in_wet(Vector2(q.x, q.z), 1.2) or on_road(Vector2(q.x, q.z), 0.5):
								continue
							var hh := rng.randf_range(0.55, 1.25)
							reeds.append(Transform3D(_rand_basis(8).scaled_local(Vector3(hh * 0.85, hh, hh * 0.85)), Vector3(q.x, 0.0, q.z)))
					elif roll < 0.33 and not _blocked(p, 1.0):
						_dead_tree(p)
					elif roll < 0.36 and not in_wet(Vector2(p.x, p.z), 5.0):
						var d := A.ground_decal(world, A.blob_tex(), Color(0.06, 0.08, 0.07, 0.55), rng.randf_range(2.5, 6.0), p + Vector3(0, 0.035, 0))
						d.rotation.y = rng.randf() * TAU
				"D", "R", "I", "H", "Y":
					if roll < 0.004 and not _blocked(p, 2.0):
						_rubble_pile(p, 2.0)
						blocks.append(Rect2(p.x - 1.5, p.z - 1.5, 3, 3))
		gz += step
	var SLAG_POD := A.paint(Color(0.18, 0.16, 0.19), 0.55, 0.68, {"panel_scale": 0.0, "rust": 0.78, "grime": 0.88})
	_multimesh(A.tree_trunk_mesh(0), BARK, trunks_0)
	_multimesh(A.tree_trunk_mesh(1), BARK, trunks_1)
	_multimesh(A.pine_crown_mesh(0), A.foliage_mat("pine"), pines_0)
	_multimesh(A.pine_crown_mesh(1), A.foliage_mat("pine"), pines_1)
	_multimesh(A.broad_crown_mesh(0), A.foliage_mat("broad"), broads_0)
	_multimesh(A.broad_crown_mesh(1), A.foliage_mat("broad"), broads_1)
	_multimesh(A.broad_crown_mesh(2), A.foliage_mat("autumn"), autumns)
	_multimesh(A.rock_mesh(1), A.rock_mat(Color(0.36, 0.32, 0.28)), rims)
	_multimesh(A.rock_mesh(3), SLAG_POD, pods, false)
	_multimesh(A.grass_clump_mesh(), A.foliage_mat("grass"), reeds, false)


func _tree(p: Vector3, buckets: Array, body: StaticBody3D) -> void:
	# 写实三维荒原乔木：沟裂树皮板根分叉主干 + 多层垂枝松柏针叶冠 / 分叉阔叶乔木树冠 / 黄褐秋叶树冠
	var h := rng.randf_range(5.6, 10.6)
	var cr := h * rng.randf_range(0.22, 0.29)
	var lean_a := rng.randf() * TAU
	var lean_deg := rng.randf_range(0.0, 2.8)
	var tb := Basis(Vector3.UP, lean_a) * Basis(Vector3.RIGHT, deg_to_rad(lean_deg))
	var v_idx := rng.randi() % 2
	var species := rng.randf()
	if species < 0.54:
		# 冷杉 / 油松针叶乔木
		(buckets[v_idx] as Array).append(Transform3D(tb.scaled_local(Vector3(h * 0.16, h * 0.80, h * 0.16)), p))
		var cb := tb * Basis(Vector3.UP, rng.randf_range(-0.4, 0.4))
		(buckets[2 + v_idx] as Array).append(Transform3D(cb.scaled_local(Vector3(cr * 1.26, h * 0.80, cr * 1.26)), p + tb * Vector3(0.0, h * 0.22, 0.0)))
	elif species < 0.86:
		# 荒原白桦 / 杨树阔叶乔木
		(buckets[v_idx] as Array).append(Transform3D(tb.scaled_local(Vector3(h * 0.18, h * 0.76, h * 0.18)), p))
		var cb := tb * Basis(Vector3.UP, rng.randf_range(-0.5, 0.5))
		(buckets[4 + v_idx] as Array).append(Transform3D(cb.scaled_local(Vector3(cr * 1.48, h * 0.74, cr * 1.48)), p + tb * Vector3(0.0, h * 0.28, 0.0)))
	else:
		# 半枯黄褐阔叶树
		(buckets[v_idx] as Array).append(Transform3D(tb.scaled_local(Vector3(h * 0.18, h * 0.75, h * 0.18)), p))
		var cb := tb * Basis(Vector3.UP, rng.randf_range(-0.5, 0.5))
		(buckets[6] as Array).append(Transform3D(cb.scaled_local(Vector3(cr * 1.42, h * 0.72, cr * 1.42)), p + tb * Vector3(0.0, h * 0.28, 0.0)))
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.45
	sh.height = 5.0
	cs.shape = sh
	cs.position = p + Vector3(0, 2.5, 0)
	body.add_child(cs)
	blocks.append(Rect2(p.x - 0.8, p.z - 0.8, 1.6, 1.6))


func _crater(p: Vector3, rims: Array) -> void:
	var rad := rng.randf_range(2.5, 6.5)
	var d0 := A.ground_decal(world, A.scorch_tex(), Color(0.76, 0.72, 0.86, 0.88) if map_id == "abyss_maw" else Color(0.88, 0.85, 0.80, 0.90), rad * 2.55, p + Vector3(0, 0.036, 0))
	d0.rotation.y = rng.randf() * TAU
	var crater_soil := ground_dust_tint().darkened(0.62)
	var d1 := A.ground_decal(world, A.grime_stain_tex(), Color(crater_soil.r, crater_soil.g, crater_soil.b, 0.70), rad * 1.45, p + Vector3(0, 0.039, 0))
	d1.rotation.y = rng.randf() * TAU
	var blast_dir := rng.randf() * TAU
	var n := int(rad * 3.8)
	for i in n:
		if rng.randf() < 0.30:
			continue
		var a := TAU * float(i) / float(maxi(n, 1)) + rng.randf_range(-0.42, 0.42)
		var lobe := 0.5 + 0.5 * cos((a - blast_dir) * 2.0)
		var rr := rad * rng.randf_range(0.74, 1.24 + lobe * 0.36)
		var sc := rng.randf_range(0.18, 0.68) * rad * 0.32 * (1.12 - 0.30 * maxf(0.0, rr / rad - 1.0))
		rims.append(Transform3D(_rand_basis(42).scaled_local(Vector3(sc * rng.randf_range(1.05, 1.65), sc * rng.randf_range(0.38, 0.68), sc * rng.randf_range(0.85, 1.25))), p + Vector3(cos(a) * rr, sc * 0.10, sin(a) * rr)))
	if rad >= 4.2:
		var ch_h := hash("%d|%d|crater" % [roundi(p.x), roundi(p.z)]) & 0x7fffffff
		var ca := float(ch_h % 360) * (PI / 180.0)
		var c_out := Vector3(cos(ca), 0.0, sin(ca))
		var ck := "cache" if (ch_h % 3 != 0) else "ammo"
		register_loot_anchor(p + c_out * (rad + 1.4), _face_outward_yaw(c_out), ck, 79, "wild_cache" if ck == "cache" else "sandbags", c_out)


func _tank_wreck(p: Vector3) -> void:
	# 写实重装甲残骸：55% 击毁主战坦克（倾斜首上+履带负重轮+扭转炮塔+穿孔主炮），45% 6×6 重型装甲运兵车残骸
	var M := A.paint(Color(0.22, 0.23, 0.19), 0.42, 0.78, {"rust": 0.82, "wear": 0.72, "grime": 0.95})
	var M2 := A.paint(Color(0.17, 0.18, 0.15), 0.48, 0.76, {"rust": 0.85, "wear": 0.75, "grime": 1.0})
	var M_TRK := A.metal(Color(0.11, 0.11, 0.12))
	var M_BORE := A.paint(Color(0.02, 0.02, 0.02), 0.0, 0.95)
	A.ground_decal(world, A.blob_tex(), Color(0.04, 0.04, 0.04, 0.72), 6.8, p + Vector3(0, 0.039, 0))
	if rng.randf() < 0.55:
		var sb := _bldg_body(Vector3(3.6, 2.5, 6.8), p + Vector3(0, 1.25, 0))
		sb.rotation_degrees.y = rng.randf() * 360.0
		PrefabLib.place_on_body(self, sb, "veh_mbt_tank_wreck", Vector3(3.62, 2.75, 8.65), false, null, -1.25)
		blocks.append(_rect_for(p, Vector3(6.2, 1, 6.2)))
		add_contact_shadow(p, 5.4, 8.2, sb.rotation_degrees.y)
		var flank := Vector3(1.0, 0.0, 0.0).rotated(Vector3.UP, deg_to_rad(sb.rotation_degrees.y))
		register_loot_anchor(p + flank * 4.4, _face_outward_yaw(flank), "military", 92, "tank_wreck", flank)
	else:
		# 6×6 重型装甲运兵车（APC）残骸：防雷V型底壳 + 倾斜观察窗驾驶舱 + 六轮越野胎 + 顶置遥控武器站残架
		var sb := _bldg_body(Vector3(2.85, 2.15, 6.2), p + Vector3(0, 1.08, 0))
		sb.rotation_degrees.y = rng.randf() * 360.0
		FM.build_apc_wreck(sb, M, M2, M_TRK, M_BORE)
		for wx in [-1.32, 1.32]:
			for wz in [-2.05, 0.05, 2.05]:
				var wp := Vector3(wx, -0.52, wz)
				var wrot := Vector3(0, 0, 90) if wx > 0.0 else Vector3(0, 0, -90)
				_imesh(sb, FM.offroad_tire_mesh(0.54, 0.40), A.rubber(), wp, wrot)
				_imesh(sb, FM.offroad_rim_mesh(0.54, 0.40), M_TRK, wp, wrot, Vector3.ONE, false)
				for li in 18:
					var la := TAU * float(li) / 18.0
					var lpos := wp + Vector3(0, cos(la) * 0.545, sin(la) * 0.545)
					_imesh(sb, FM.tire_lug_mesh(), A.rubber(), lpos, (Basis(Vector3.RIGHT, la)).get_euler() * (180.0 / PI), Vector3(0.32, 0.035, 0.11), false)
		blocks.append(_rect_for(p, Vector3(5.8, 1, 5.8)))
		add_contact_shadow(p, 4.8, 7.8, sb.rotation_degrees.y)
		var flank := Vector3(1.0, 0.0, 0.0).rotated(Vector3.UP, deg_to_rad(sb.rotation_degrees.y))
		register_loot_anchor(p + flank * 4.2, _face_outward_yaw(flank), "ammo", 92, "tank_wreck", flank)


func _park_statue(c: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 2.4
	sh.height = 5.4
	cs.shape = sh
	cs.position.y = 2.7
	sb.add_child(cs)
	world.add_child(sb)
	sb.position = c
	var M_STN := A.concrete(Color(0.46, 0.44, 0.41))
	var M_DRK := A.concrete(Color(0.32, 0.31, 0.29), false)
	var M_BRZ := A.paint(Color(0.26, 0.35, 0.30), 0.75, 0.40, {"rust": 0.40, "wear": 0.48, "panel_scale": 0.0})
	# 八角倒角花岗岩纪念碑台基 + 重工青铜齿轮方尖碑（取代刺眼的 15 米白色同心靶心圆盘）
	A.add(sb, A.cyl(4.5, 0.16, 4.7, 8), M_DRK, Vector3(0, 0.08, 0), Vector3(0, 22.5, 0))
	A.add(sb, A.cyl(3.8, 0.18, 4.0, 8), M_STN, Vector3(0, 0.22, 0), Vector3(0, 22.5, 0))
	A.add(sb, A.bevel_box(Vector3(2.35, 0.52, 2.35), 0.08), M_DRK, Vector3(0, 0.56, 0))
	A.add(sb, A.bevel_box(Vector3(1.52, 2.15, 1.52), 0.08), M_STN, Vector3(0, 1.88, 0))
	A.add(sb, A.bevel_box(Vector3(1.72, 0.22, 1.72), 0.04), M_DRK, Vector3(0, 3.02, 0))
	A.add(sb, A.bevel_box(Vector3(0.72, 2.10, 0.56), 0.08, 0.68), M_BRZ, Vector3(0, 4.12, 0), Vector3(0, 0, 8))
	A.add(sb, A.bevel_box(Vector3(1.18, 0.28, 0.28), 0.04), M_BRZ, Vector3(0.06, 4.35, 0), Vector3(0, 25, -24))
	blocks.append(Rect2(c.x - 4.8, c.z - 4.8, 9.6, 9.6))
	add_contact_shadow(c, 11.4, 11.4, 0.0)
	_poi_lamp(c + Vector3(5.2, 0, 5.2), Color(1.0, 0.8, 0.55))
	register_loot_anchor(c + Vector3(-6.0, 0.0, 1.8), _face_outward_yaw(Vector3(-1, 0, 0)), "supply", 86, "park_statue", Vector3(-1, 0, 0))
	register_loot_anchor(c + Vector3(6.0, 0.0, -1.8), _face_outward_yaw(Vector3(1, 0, 0)), "med", 84, "park_statue", Vector3(1, 0, 0))


## 菌毯区：数据格子里相连的 S 格各放一座虫巢
func _hive_nests() -> void:
	var seen := {}
	for j in 9:
		for i in 9:
			if zones[j][i] != "S" or seen.has(Vector2i(i, j)):
				continue
			var grp: Array = []
			var stack: Array = [Vector2i(i, j)]
			seen[Vector2i(i, j)] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				grp.append(c)
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nn := c + d
					if nn.x >= 0 and nn.y >= 0 and nn.x <= 8 and nn.y <= 8 and not seen.has(nn) and zones[nn.y][nn.x] == "S":
						seen[nn] = true
						stack.append(nn)
			var c0: Vector2i = grp[rng.randi() % grp.size()]
			for t in 12:
				var p := _spot_in(_cell_rect(c0.x, c0.y), 3.0, 8)
				if p != Vector3.INF and zone_at(p) == "S":
					var nest = NestScript.new()
					world.add_child(nest)
					nest.position = p
					nest.setup(self)
					blocks.append(Rect2(p.x - 2, p.z - 2, 4, 4))
					register_loot_anchor(p + Vector3(4.2, 0.0, 1.6), _face_outward_yaw(Vector3(1, 0, 0)), "cache", 94, "hive_cache", Vector3(1, 0, 0))
					register_loot_anchor(p + Vector3(-4.2, 0.0, -1.6), _face_outward_yaw(Vector3(-1, 0, 0)), "military", 92, "hive_cache", Vector3(-1, 0, 0))
					break


## 悬崖山体：统一调用 MountainTerrain 雕刻连续高程场山脉、断崖台地、冲沟与行合并碰撞体
func _scatter_cliffs() -> void:
	MountainTerrain.build(self)


# ---------- 建筑部件 ----------
func _house(p: Vector3, sz: Vector3, rot := 0.0) -> void:
	var is_brk := rng.randf() < 0.45
	var c: Color = Color(0.55, 0.36, 0.25) if is_brk else [Color(0.64, 0.59, 0.52), Color(0.58, 0.54, 0.49), Color(0.61, 0.60, 0.55)][rng.randi() % 3]
	var M_WALL: Material = A.brick(c) if is_brk else A.concrete(c)
	var safe_sz := PrefabLib.clamp_building_height("bldg_house", sz)
	var sb := _bldg_body(safe_sz, p + Vector3(0.0, safe_sz.y * 0.5, 0.0))
	sb.rotation.y = -rot
	PrefabLib.place_on_body(self, sb, "bldg_house", safe_sz, true, M_WALL)

func _warehouse(p: Vector3, sz: Vector3, col := Color(-1, 0, 0), rot := 0.0) -> void:
	var c: Color = col if col.r >= 0.0 else [Color(0.49, 0.53, 0.50), Color(0.60, 0.53, 0.41), Color(0.42, 0.50, 0.58)][rng.randi() % 3]
	var M: Material = A.corrugated(c, 0.36, 0.22)
	var sb := _bldg_body(sz, p + Vector3(0.0, sz.y * 0.5, 0.0))
	sb.rotation.y = -rot
	PrefabLib.place_on_body(self, sb, "bldg_warehouse", sz, true, M, -999.0, rng.randf() < 0.45, "BLD-%02d" % rng.randi_range(1, 40))

func _tank(p: Vector3, rad: float, h: float) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = rad
	sh.height = max(h, 5.0)
	cs.shape = sh
	cs.position.y = sh.height * 0.5
	sb.add_child(cs)
	world.add_child(sb)
	sb.position = p
	var c: Color = [Color(0.6, 0.58, 0.52), Color(0.45, 0.47, 0.45), Color(0.55, 0.42, 0.3)][rng.randi() % 3]
	var M_TANK := A.paint(c, 0.5, 0.55, {"wear": 0.45, "rust": 0.65, "dust": 0.35, "panel_scale": 0.8})
	var M_ROOF := A.paint(c.darkened(0.15), 0.5, 0.55, {"rust": 0.75})
	var M_RING := A.metal(Color(0.25, 0.25, 0.24))
	# 钢筋混凝土环形基座 + 42 段高细分圆筒罐身 + 锥形拱顶 + 顶盖呼吸阀与检修人孔 + 顶缘环形护栏 + 外挂护笼爬梯与侧面阀门法兰管汇
	A.add(sb, A.cyl(rad + 0.32, 0.36, rad + 0.44, 42), A.concrete(Color(0.44, 0.43, 0.4), false), Vector3(0, 0.18, 0))
	A.add(sb, A.cyl(rad, h, rad, 42), M_TANK, Vector3(0, h * 0.5, 0))
	A.add(sb, A.cyl(rad * 0.14, rad * 0.36, rad + 0.04, 42), M_ROOF, Vector3(0, h + rad * 0.18, 0))
	A.add(sb, A.cyl(rad * 0.22, 0.42, rad * 0.24, 24), M_RING, Vector3(0, h + rad * 0.4, 0))
	A.add(sb, A.cyl(rad * 0.3, 0.1, rad * 0.3, 24), M_ROOF, Vector3(0, h + rad * 0.62, 0))
	for k in 4:
		var ry := h * (0.18 + k * 0.24)
		A.add(sb, A.torus(rad - 0.02, rad + 0.08, 42), M_RING, Vector3(0, ry, 0), Vector3.ZERO, Vector3(1, 0.55, 1), false)
	# 罐顶周圈安全护栏
	A.add(sb, A.torus(rad - 0.06, rad + 0.02, 42), M_RING, Vector3(0, h + 0.62, 0), Vector3.ZERO, Vector3(1, 0.45, 1), false)
	for k in 8:
		var pa := TAU * k / 8.0
		A.add(sb, A.cyl(0.035, 0.65, 0.035, 10), M_RING, Vector3(cos(pa) * (rad - 0.02), h + 0.32, sin(pa) * (rad - 0.02)), Vector3.ZERO, Vector3.ONE, false)
	# 爬梯与侧面排污阀箱
	A.add(sb, A.bevel_box(Vector3(0.48, h + 0.5, 0.12), 0.01), A.metal(Color(0.2, 0.2, 0.2)), Vector3(0, h * 0.5 + 0.25, rad + 0.1))
	A.add(sb, A.cyl(0.24, 0.45, 0.24, 20), M_RING, Vector3(rad + 0.15, 0.85, 0), Vector3(0, 0, 90))
	A.add(sb, A.torus(0.22, 0.32, 20), A.paint(Color(0.68, 0.22, 0.16), 0.4, 0.5), Vector3(rad + 0.38, 0.85, 0), Vector3(0, 0, 90), Vector3.ONE, false)
	blocks.append(Rect2(p.x - rad - 1, p.z - rad - 1, rad * 2 + 2, rad * 2 + 2))
	add_contact_shadow(p, rad * 2.7, rad * 2.7, 0.0)
	register_loot_anchor(p + Vector3(rad + 2.15, 0.0, 0.6), _face_outward_yaw(Vector3(1, 0, 0)), "tool", 81, "oil_tank", Vector3(1, 0, 0))

func _chimney(p: Vector3) -> void:
	# 盘梯立式储油罐与高炉烟囱围堰组（B5-23 ind_oil_tank_chimney）
	var sb := _bldg_body(Vector3(8.6, 8.5, 8.0), p + Vector3(0.0, 4.25, 0.0))
	sb.rotation_degrees.y = float(rng.randi_range(0, 3)) * 90.0
	PrefabLib.place_on_body(self, sb, "ind_oil_tank_chimney", Vector3(9.2, 11.5, 8.6), false, null, -4.25, rng.randf() < 0.50)
	A.emitter(sb, Vector3(2.55, 7.30, 0.35), {"amount": 8, "life": 6.0, "size": 2.4, "tex": A.smoke_tex(), "additive": false, "vmin": 0.6, "vmax": 1.2,
		"gravity": Vector3(0.6, 0.4, 0.2), "c0": Color(0.15, 0.13, 0.12, 0.45), "c1": Color(0.3, 0.28, 0.26, 0.0), "grow0": 0.6, "grow1": 3.0})
	blocks.append(Rect2(p.x - 4.6, p.z - 4.4, 9.2, 8.8))
	add_contact_shadow(p, 11.4, 10.6, sb.rotation_degrees.y)
	var ch_out := Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, deg_to_rad(sb.rotation_degrees.y))
	register_loot_anchor(p + ch_out * 5.8, _face_outward_yaw(ch_out), "tool", 83, "chimney", ch_out)

func _bunker(p: Vector3) -> void:
	# 永备钢筋混凝土防弹机枪暗堡（B5-21 fort_pillbox_bunker）
	var sz := Vector3(6.8, 3.2, 6.8)
	var sb := _bldg_body(Vector3(6.2, 3.0, 6.2), p + Vector3(0.0, 1.5, 0.0))
	sb.rotation_degrees.y = rng.randf_range(-18.0, 18.0)
	PrefabLib.place_on_body(self, sb, "fort_pillbox_bunker", sz, false, null, -1.5, rng.randf() < 0.45)
	blocks.append(_rect_for(p, sz + Vector3(1.6, 0.0, 1.6)))
	add_contact_shadow(p, 8.8, 8.8, sb.rotation_degrees.y)
	var byaw := sb.rotation_degrees.y
	var b_rear := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, deg_to_rad(byaw))
	var b_side := Vector3(1.0, 0.0, 0.0).rotated(Vector3.UP, deg_to_rad(byaw))
	register_loot_anchor(p + b_rear * 5.4, _face_outward_yaw(b_rear), "weapon", 98, "bunker", b_rear)
	register_loot_anchor(p + b_side * 5.4, _face_outward_yaw(b_side), "ammo", 96, "bunker", b_side)
	register_loot_anchor(p - b_side * 5.4, _face_outward_yaw(-b_side), "safe", 94, "bunker", -b_side)

func _watchtower(p: Vector3) -> void:
	# 重工角钢桁架高空哨戒瞭望塔（B5-22 fort_watchtower）
	var sb := _bldg_body(Vector3(3.4, 5.2, 3.4), p + Vector3(0.0, 2.6, 0.0))
	PrefabLib.place_on_body(self, sb, "fort_watchtower", Vector3(5.4, 9.8, 5.4), false, null, -2.6, rng.randf() < 0.40)
	blocks.append(Rect2(p.x - 2.4, p.z - 2.4, 4.8, 4.8))
	add_contact_shadow(p, 5.6, 5.6, 0.0)
	var wt_kind := "ammo" if zone_at(p) in ["M", "C"] else "tool"
	register_loot_anchor(p + Vector3(3.6, 0.0, 0.4), _face_outward_yaw(Vector3(1, 0, 0)), wt_kind, 89, "watchtower", Vector3(1, 0, 0))

func _sandbags(p: Vector3, rot: float) -> void:
	var M := A.paint(Color(0.5, 0.45, 0.32), 0.0, 1.0, {"panel_scale": 0.0, "dust": 0.6, "wear": 0.2})
	var sb := _static_box(Vector3(4.0, 1.2, 0.9), p + Vector3(0, 0.6, 0), Color.WHITE, null, M)
	sb.rotation_degrees.y = rot
	for row in 3:
		for k in 5:
			A.add(sb, A.bevel_box(Vector3(0.85, 0.36, 0.55), 0.15), M, Vector3(-1.7 + k * 0.85 + (0.42 if row % 2 else 0.0), -0.42 + row * 0.38, rng.randf_range(-0.08, 0.08)), Vector3(0, rng.randf_range(-6, 6), 0))
	blocks.append(_rect_for(p, Vector3(4.4, 1, 4.4)))
	add_contact_shadow(p, 5.0, 2.2, rot)
	var sb_back := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, deg_to_rad(rot))
	register_loot_anchor(p + sb_back * 3.3, _face_outward_yaw(sb_back), "ammo", 93, "sandbags", sb_back)

func _boulder(p: Vector3, s: float) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = s * 0.6
	sh.height = 5.0
	cs.shape = sh
	cs.position.y = 2.5
	sb.add_child(cs)
	world.add_child(sb)
	sb.position = p
	var M := A.rock_mat(Color(0.44, 0.39, 0.34))
	var M2 := A.rock_mat(Color(0.36, 0.32, 0.27))
	for k in 3:
		var ss := s * rng.randf_range(0.52, 0.92)
		_imesh(sb, A.rock_mesh(rng.randi() % 12), M if k != 2 else M2,
			Vector3(rng.randf_range(-0.28, 0.28) * s, ss * 0.15, rng.randf_range(-0.28, 0.28) * s),
			Vector3(rng.randf_range(-14, 14), rng.randf() * 360.0, rng.randf_range(-14, 14)),
			Vector3(ss * 0.76, ss * 0.46, ss * 0.66))
	blocks.append(Rect2(p.x - s * 0.7, p.z - s * 0.7, s * 1.4, s * 1.4))
	if s >= 3.0 and zone_at(p) in ["W", "C", "T", "L"]:
		var bh := hash("%d|%d|boulder" % [roundi(p.x), roundi(p.z)]) & 0x7fffffff
		var ba := float(bh % 360) * (PI / 180.0)
		var b_out := Vector3(cos(ba), 0.0, sin(ba))
		register_loot_anchor(p + b_out * (s * 0.75 + 1.2), _face_outward_yaw(b_out), "cache", 74, "wild_cache", b_out)

func _dead_tree(p: Vector3) -> void:
	var n := Node3D.new()
	world.add_child(n)
	n.position = p
	var M := A.bark_mat(Color(0.28, 0.24, 0.19))
	var h := rng.randf_range(3.8, 6.2)
	var v_t := rng.randi() % 3
	A.add(n, A.tree_trunk_mesh(v_t, true), M, Vector3.ZERO, Vector3(rng.randf_range(-3.0, 3.0), rng.randf() * 360.0, rng.randf_range(-3.0, 3.0)), Vector3(h * 0.24, h, h * 0.24))
	A.add(n, FM.snag_limbs_mesh(rng.randi() % 6), M, Vector3.ZERO, Vector3(0, rng.randf() * 360.0, 0), Vector3.ONE * h)

func _rubble_pile(p: Vector3, s: float) -> void:
	var M := A.rock_mat(Color(0.48, 0.45, 0.41))
	var n := Node3D.new()
	world.add_child(n)
	n.position = p
	for k in 7:
		var ss := rng.randf_range(0.3, 0.9) * s * 0.5
		_imesh(n, A.rock_mesh(rng.randi() % 12), M,
			Vector3(rng.randf_range(-s, s) * 0.6, ss * 0.10, rng.randf_range(-s, s) * 0.6),
			Vector3(rng.randf_range(-25, 25), rng.randf() * 360, rng.randf_range(-25, 25)),
			Vector3(ss * 0.78, ss * 0.36, ss * 0.58))



func _spawn_extracts(drop: Vector3) -> void:
	rng.seed = _map_seed(14)
	var cands: Array = []
	for i in MAP.extracts.size():
		var e: Array = MAP.extracts[i]
		cands.append([e[0], Vector3(e[1], 0, e[2]), i])
	cands.sort_custom(func(a, b): return a[1].distance_to(drop) > b[1].distance_to(drop))
	var letters := ["A", "B"]
	for k in 2:
		var c: Array = cands[0]
		if k == 1:
			for cc: Array in cands.slice(1):
				if cc[1].distance_to(cands[0][1]) > 200.0:
					c = cc
					break
		var z = ExtractScript.new()
		world.add_child(z)
		z.position = c[1]
		z.set_meta("ext_letter", letters[k])
		z.set_meta("ext_idx", int(c[2]))
		z.setup(Loc.t("撤离点 %s · %s" % [letters[k], c[0]], "Extract %s · %s" % [letters[k], c[0]]), Color(0.3, 1.0, 0.5), 8.0)
		extracts.append(z)


## 初始虫群：战区在 GameData.SPAWNS 里登记了分布时按登记的生成（script 可接管整个布置），否则用下面的默认分布
func _spawn_initial_bugs(drop: Vector3) -> void:
	rng.seed = _map_seed(15)
	var sp: Dictionary = GameData.SPAWNS.get(map_id, {})
	if sp.has("script"):
		load(str(sp.script)).spawn(self, drop)
	elif sp.has("kinds"):
		_spawn_table_bugs(drop, sp)
	else:
		spawn_default_bugs(drop)


## 按分布表生成：packs = 区块字符 -> 每 4900 平方米的虫群数，kinds = 种类 -> 权重，pack_size = [最少, 最多]
## 整体密度乘 BUG_DENSITY；先把全图的虫群计划排好再打乱生成，铺到 INITIAL_BUGS 上限时不会只剩地图一角有虫
func _spawn_table_bugs(drop: Vector3, sp: Dictionary) -> void:
	var packs: Dictionary = sp.get("packs", {})
	var ps: Array = sp.get("pack_size", [2, 5])
	var plan: Array = []
	for j in range(-1, 10):
		for i in range(-1, 10):
			var r := _cell_rect(i, j)
			var rc := r.get_center()
			if border_dist(rc) < -28.0:
				continue
			var t: String = str(zones[j][i]) if (i >= 0 and i <= 8 and j >= 0 and j <= 8) else zone_at(Vector3(rc.x, 0.0, rc.y))
			var ex: float = float(packs.get(t, 0.0)) * CELL * CELL / 4900.0 * BUG_DENSITY
			var cnt := int(ex) + (1 if rng.randf() < ex - int(ex) else 0)
			for k in cnt:
				var c := _spot_in(r, 2.0)
				if c == Vector3.INF or c.distance_to(drop) < 40.0:
					continue
				var kinds: Array = []
				for m in rng.randi_range(int(ps[0]), int(ps[1]) + 1):
					kinds.append(GameData._weighted(sp.kinds, rng))
				plan.append([c, kinds])
	_spawn_plan(plan)


func spawn_default_bugs(drop: Vector3) -> void:
	var packs := {"D": 2.0, "R": 1.0, "I": 2.0, "H": 2.0, "Y": 1.6, "M": 3.0, "W": 0.9, "F": 0.9, "P": 1.2, "T": 1.0, "C": 1.4, "S": 3.0, "K": 0.0}
	var plan: Array = []
	for j in range(-1, 10):
		for i in range(-1, 10):
			var r := _cell_rect(i, j)
			var rc := r.get_center()
			if border_dist(rc) < -28.0:
				continue
			var t: String = str(zones[j][i]) if (i >= 0 and i <= 8 and j >= 0 and j <= 8) else zone_at(Vector3(rc.x, 0.0, rc.y))
			var ex: float = float(packs.get(t, 0.0)) * CELL * CELL / 4900.0 * BUG_DENSITY
			var cnt := int(ex) + (1 if rng.randf() < ex - int(ex) else 0)
			for k in cnt:
				var c := _spot_in(r, 2.0)
				if c == Vector3.INF or c.distance_to(drop) < 40.0:
					continue
				var kinds: Array = []
				for m in rng.randi_range(2, 5):
					var kind := "ling"
					var rr := rng.randf()
					if rr < 0.22:
						kind = "spitter"
					elif rr < (0.32 if t == "M" or t == "D" else 0.26):
						kind = "beetle"
					kinds.append(kind)
				plan.append([c, kinds])
	_spawn_plan(plan)


## 按计划铺虫群：每群第一只是群首（自己巡逻），其余成员跟在群首身后的站位上；约五分之一的虫群是领地很大的游荡群
func _spawn_plan(plan: Array) -> void:
	for i in range(plan.size() - 1, 0, -1):
		var k := rng.randi_range(0, i)
		var tmp = plan[i]
		plan[i] = plan[k]
		plan[k] = tmp
	for e: Array in plan:
		var c: Vector3 = e[0]
		var lead = null
		var roam := rng.randf() < 0.22
		var slow := INF
		for kind: String in e[1]:
			var b = spawn_bug(kind, c + Vector3(rng.randf_range(-3, 3), 0.5, rng.randf_range(-3, 3)), INITIAL_BUGS)
			if b == null:
				return
			b.home = Vector3(c.x, 0, c.z)
			slow = minf(slow, float(b.data.speed))
			if lead == null:
				lead = b
				b.territory = rng.randf_range(60.0, 85.0) if roam else rng.randf_range(24.0, 40.0)
			else:
				b.pack_leader = lead
				lead.pack.append(b)
				var n: int = lead.pack.size()
				var a := PI + (0.5 + 0.35 * n) * (1.0 if n % 2 == 0 else -1.0)
				b.follow_off = Vector3(sin(a), 0, -cos(a)) * (2.6 + 0.9 * n)
		if lead != null:
			# 群首按全群最慢成员的步速巡逻，免得慢的掉队
			lead.patrol_speed = clampf(slow * 0.42 / maxf(float(lead.data.speed), 0.1), 0.22, 0.6)


# ---------- 派系与巡逻的公共查询 ----------
## 虫群眼里的敌人：玩家机甲 + 战斗队友 + 流浪者（每个物理帧缓存一次）
var _foes_frame := -1
var _foes: Array = []
func bug_foes() -> Array:
	var f := Engine.get_physics_frames()
	if f == _foes_frame:
		return _foes
	_foes_frame = f
	_foes.clear()
	for player in player_mechs():
		if not player.dead and not player.net_done:
			_foes.append(player)
	for n in get_tree().get_nodes_in_group("npc_mechs"):
		if is_instance_valid(n) and not n.dead:
			_foes.append(n)
	return _foes


## 巡逻路点：home 周围 radius 米内一处空地（避开建筑占地、地图边缘与湖面）。占地矩形按 16 米格子分桶，查询很便宜
const _PG := 16.0
var _pgrid := {}
func patrol_point(home: Vector3, radius: float, from: Vector3) -> Vector3:
	if _pgrid.is_empty():
		for b: Rect2 in blocks:
			for gx in range(floori(b.position.x / _PG), floori(b.end.x / _PG) + 1):
				for gz in range(floori(b.position.y / _PG), floori(b.end.y / _PG) + 1):
					var key := Vector2i(gx, gz)
					if not _pgrid.has(key):
						_pgrid[key] = []
					_pgrid[key].append(b)
		_pgrid[Vector2i(99999, 99999)] = []
	for t in 6:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * radius
		var p := home + Vector3(cos(a) * d, 0, sin(a) * d)
		if not in_bounds(p, 8.0):
			continue
		if in_wet(Vector2(p.x, p.z), 2.0) or not _patrol_free(p, 1.6):
			continue
		if t < 3 and p.distance_to(from) < 6.0:
			continue
		return Vector3(p.x, 0, p.z)
	return Vector3(home.x, 0, home.z)


func patrol_free(p: Vector3, r: float) -> bool:
	if _pgrid.is_empty():
		patrol_point(p, 0.0, p)
	return _patrol_free(p, r)


func _patrol_free(p: Vector3, r: float) -> bool:
	var probe := Rect2(p.x - r, p.z - r, r * 2, r * 2)
	for b: Rect2 in _pgrid.get(Vector2i(floori(p.x / _PG), floori(p.z / _PG)), []):
		if b.intersects(probe):
			return false
	return true


# ---------- 性能：静态装饰合批 ----------
## 静态外观全部交给分块合批：world 下（只经过无脚本、无分组、自动命名的 Node3D / StaticBody3D）的静态网格
## 从节点树摘掉，按 分块 + 材质 合成 ArrayMesh；碰撞体留在原处不动。开局只建视野内的分块，其余懒构建。
func _strip_world_labels(root: Node) -> int:
	if root == null:
		return 0
	var stack: Array = [root]
	var stripped := 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			if ch is Label3D:
				n.remove_child(ch)
				ch.free()
				stripped += 1
			else:
				stack.append(ch)
	return stripped


func _bake_static(drop: Vector3) -> void:
	_flush_inst()
	_strip_world_labels(world)
	var rb := _rb()
	var stack: Array = [world]
	var empty_dirs: Array = []
	var removed := 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			if ch == rb or ch.get_script() != null or not ch.get_groups().is_empty():
				continue
			if ch is MeshInstance3D:
				var mi: MeshInstance3D = ch
				var mo: Material = mi.material_override
				if not mi.visible or mi.material_overlay != null or mi.transparency > 0.0 or mi.visibility_range_end > 0.0 \
						or (mo is BaseMaterial3D and ((mo as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or (mo as BaseMaterial3D).emission_enabled)) \
						or mi.get_child_count() > 0 or not rb.mergeable(mi.mesh) or _has_surface_override(mi):
					continue
				var wab: AABB = mi.global_transform * mi.mesh.get_aabb()
				if maxf(wab.size.x, wab.size.z) > rb.CHUNK:
					continue
				rb.add_mesh(mi.mesh, mi.material_override, mi.global_transform, mi.cast_shadow)
				mi.get_parent().remove_child(mi)
				mi.free()
				removed += 1
			elif (ch.get_class() == "Node3D" or ch.get_class() == "StaticBody3D") and ch.visible:
				if ch.get_class() == "Node3D":
					empty_dirs.append(ch)
				stack.append(ch)
	for i in range(empty_dirs.size() - 1, -1, -1):
		var d: Node3D = empty_dirs[i]
		if is_instance_valid(d) and d.get_child_count() == 0:
			if d.get_parent():
				d.get_parent().remove_child(d)
			d.free()
	var f: Vector3 = mech.global_position if mech and is_instance_valid(mech) else drop
	rb.build_all(f, rb.STREAM_R)
	PrefabLib._surf_cache.clear()
	_flush_contact_shadows()
	if _occ_bldgs != null:
		_occ_bldgs.prepare(self)
	print("[raid] batched %d static meshes + %d instances into %d chunks (%d built)" % [removed, rb.stats.inst, rb._chunks.size(), rb.stats.built])


func _flush_contact_shadows() -> void:
	if _contact_shadows.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = A.quad(1.0, 1.0)
	mm.instance_count = _contact_shadows.size()
	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	for i in _contact_shadows.size():
		var xf: Transform3D = _contact_shadows[i]
		mm.set_instance_transform(i, xf)
		var p := xf.origin
		var r := maxf(xf.basis.x.length(), xf.basis.z.length()) * 0.72
		mn.x = minf(mn.x, p.x - r)
		mn.y = minf(mn.y, p.y - 0.1)
		mn.z = minf(mn.z, p.z - r)
		mx.x = maxf(mx.x, p.x + r)
		mx.y = maxf(mx.y, p.y + 0.1)
		mx.z = maxf(mx.z, p.z + r)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "ContactShadows"
	mmi.multimesh = mm
	mmi.material_override = A.contact_shadow_mat(0.50)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(mn, mx - mn)
	world.add_child(mmi)
	_contact_shadows.clear()


func _has_surface_override(mi: MeshInstance3D) -> bool:
	for i in mi.get_surface_override_material_count():
		if mi.get_surface_override_material(i) != null:
			return true
	return false


## 地图生成分段耗时（毫秒，按阶段累计；打印在 map build 日志下一行）
var _tphase := {}
var _tlast := 0


func _tmark(name: String) -> void:
	var now := Time.get_ticks_usec()
	_tphase[name] = int(_tphase.get(name, 0)) + (now - _tlast) / 1000
	_tlast = now


## 统计子树节点数（地图生成性能日志用；queue_free 待删的不算）
func _count_nodes(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		if not ch.is_queued_for_deletion():
			c += _count_nodes(ch)
	return c


func _apply_style() -> void:
	var we: WorldEnvironment = null
	for c in get_children():
		if c is WorldEnvironment:
			we = c
	preload("res://scripts/toon.gd").attach(self, we.environment if we else null, camera, GameData.render_style == 1)


## All combat systems use this list for area damage and player targeting.
func player_mechs() -> Array:
	return coop.units.values().filter(func(m): return is_instance_valid(m) and not m.net_done) if coop != null else ([mech] if is_instance_valid(mech) else [])

func nearest_player(pos: Vector3):
	var best = mech
	var distance := INF
	for m in player_mechs():
		if m.dead: continue
		var d: float = m.global_position.distance_squared_to(pos)
		if d < distance:
			distance = d
			best = m
	return best

func _event(event: String, args: Array) -> void:
	if coop != null and event not in coop.SHARED_EVENTS and is_instance_valid(mech):
		Net.player_event(mech.net_peer, event, args)
	else:
		Events.callv("emit_signal", [event] + args)

func _coop_loot_input() -> void:
	if mech.net_done or mech.dead or hud.pause_panel.visible or hud.settings_panel.visible:
		return
	if is_instance_valid(open_box):
		if Input.is_action_just_pressed("interact"): close_box()
		return
	var b = nearest_box(3.6)
	for o in get_tree().get_nodes_in_group("lootboxes"):
		o.set_near(o == b)
	hud.set_prompt(b.title if b and not hud.inv_open() else "")
	if b and Input.is_action_just_pressed("interact"): open_container(b)


func refresh_lang() -> void:
	MAP = GameData.map_data(map_id)
	map_labels = MAP.labels
	var ext_arr: Array = MAP.get("extracts", [])
	for z in extracts:
		if not is_instance_valid(z):
			continue
		var idx := int(z.get_meta("ext_idx", -1))
		var letter := str(z.get_meta("ext_letter", "A"))
		if idx >= 0 and idx < ext_arr.size():
			var row: Array = ext_arr[idx]
			z.set_title(Loc.t("撤离点 %s · %s" % [letter, row[0]], "Extract %s · %s" % [letter, row[0]]))
	if transport_zone != null and is_instance_valid(transport_zone):
		transport_zone.set_title(Loc.t("运输机降落区", "Dropship LZ"))
	if world_link != null and is_instance_valid(world_link) and world_link.has_method("refresh_lang"):
		world_link.refresh_lang()
	_build_subregions()
	for b in get_tree().get_nodes_in_group("lootboxes"):
		if not is_instance_valid(b):
			continue
		if b.has_meta("rover_wreck"):
			b.title = Loc.t("流浪者残骸", "Rover Wreck")
		elif b.kind != "" and GameData.LOOT_TABLES.has(b.kind):
			b.title = str(GameData.LOOT_TABLES[b.kind].name)
	for grp in ["rovers", "allies"]:
		for nm in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(nm) and nm.has_method("refresh_lang"):
				nm.refresh_lang()


var _load_slice_deadline := 0


## Web 单线程加载按时间预算让出事件循环，浏览器能持续显示进度并处理输入。
func _yield_load_slice() -> void:
	await get_tree().process_frame
	_load_slice_deadline = Time.get_ticks_usec() + 8000
