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
const Growth = preload("res://scripts/progression/growth.gd")
const BuildingsExt = preload("res://scripts/buildings_ext.gd")

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
var ZOOM_MAX := ZOOM_STD   ## 滚轮拉到最远：在 0.6x 基础上小幅受高射程武器影响

var coop = null
var rng := RandomNumberGenerator.new()
var mech
var camera: Camera3D
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
var transit := {}     ## 从相邻战区转场进来时携带的状态（空 = 正常空投出击）
var visited_maps: Array = []
var drop_points: Array = []   ## 本战区候选空投出生点列表（每局从中随机选取一处）


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
	world_link = WorldLinkScript.new()
	world_link.name = "WorldLink"
	add_child(world_link)
	world_link.setup(self)
	if not transit.is_empty():
		drop = world_link.entry_point(str(transit.get("edge", "")), drop)
	_tlast = Time.get_ticks_usec()
	_build_map_texture()
	world_link.paint_map(map_tex)
	_build_zone_ground()
	_tmark("map_tex+zone_ground")
	_run_ext_build(drop)
	_tmark("ext")
	_spawn_extracts(drop)
	preload("res://scripts/collision_opt.gd").optimize(self)   # 碰撞后处理：小件去碰撞、窄缝合并、防卡死（见脚本说明）
	rebuild_nav()   # 导航网格：所有静态几何体与碰撞后处理就绪后立即栅格化，用于剔除死房刷怪与死房物资箱
	if nav != null:
		nav.set_seed(drop)
	_spawn_initial_bugs(drop)
	_sanitize_spawns_and_loot(drop)
	_tmark("extracts+bugs")
	_bake_static(drop)
	_tmark("bake")
	_tmark("nav")
	print("[raid] map build %s: %d ms, world nodes %d, blocks %d" % [map_id, (Time.get_ticks_usec() - t_build) / 1000, _count_nodes(world), blocks.size()])
	print("[raid]   phases: %s" % ", ".join(_tphase.keys().map(func(k): return "%s %d" % [k, _tphase[k]])))
	_finish_setup(drop)


## 分阶段异步构建战区：每阶段向 LoadingScreen 汇报进度并让出渲染帧，彻底消除进图单帧卡顿
func start_async(lo: Dictionary, carry: Array, transit_state := {}, loader = null) -> void:
	transit = transit_state
	loadout = lo.duplicate()
	start_cargo = carry.duplicate()
	world = Node3D.new()
	add_child(world)
	fx = Node3D.new()
	add_child(fx)
	map_id = GameData.map_id
	if Net.active(): seed(_map_seed(99))
	rng.seed = _map_seed(0)
	var t_build := Time.get_ticks_usec()
	_tphase.clear()
	_tlast = t_build

	if loader != null and is_instance_valid(loader):
		await loader.step(0.08, Loc.t("正在同步信天翁号空投航线与战区遥测数据...", "Syncing Albatross drop vector & sector telemetry..."))
	_load_map()
	_tmark("load_map")
	_build_environment()
	_build_ground()
	_tmark("env+ground")

	if loader != null and is_instance_valid(loader):
		await loader.step(0.20, Loc.t("正在扫描地表路网、水系与铁道脉络...", "Scanning surface roads, waterways & rail networks..."))
	_tlast = Time.get_ticks_usec()
	_shield_spots()
	_tmark("shield_spots")
	_build_roads()
	_build_river()
	_build_lakes()
	_build_rails()
	_build_ridges()
	_tmark("roads+water+rails")

	if loader != null and is_instance_valid(loader):
		await loader.step(0.36, Loc.t("正在重构重点设施与遗迹院落...", "Reconstructing key facilities & ruin compounds..."))
	poi_centers.clear()
	poi_ids.clear()
	for p: Dictionary in layout.pois:
		poi_centers.append(Vector3(p.c.x, 0, p.c.y))
		poi_ids.append(str(p.id))
	var kc := _keep_clear
	_keep_clear = []
	_build_pois()
	_keep_clear = kc
	_tmark("pois")

	if loader != null and is_instance_valid(loader):
		await loader.step(0.50, Loc.t("正在测绘街区建筑群与废墟掩体...", "Mapping urban blocks & ruin cover..."))
	_build_blocks()
	_tmark("blocks")

	if loader != null and is_instance_valid(loader):
		await loader.step(0.62, Loc.t("正在散布地表植被、残骸与边界通道...", "Scattering surface foliage, wrecks & border gates..."))
	_build_fields()
	_scatter()
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
	var drop := _drop_point()
	world_link = WorldLinkScript.new()
	world_link.name = "WorldLink"
	add_child(world_link)
	world_link.setup(self)
	if not transit.is_empty():
		drop = world_link.entry_point(str(transit.get("edge", "")), drop)

	if loader != null and is_instance_valid(loader):
		await loader.step(0.74, Loc.t("正在渲染战术卫星地形图与地标建筑...", "Rendering tactical satellite terrain & landmarks..."))
	_tlast = Time.get_ticks_usec()
	_build_map_texture()
	world_link.paint_map(map_tex)
	_build_zone_ground()
	_tmark("map_tex+zone_ground")
	_run_ext_build(drop)
	_tmark("ext")

	if loader != null and is_instance_valid(loader):
		await loader.step(0.83, Loc.t("正在部署撤离信标与优化战场物理碰撞...", "Deploying extract beacons & optimizing collision..."))
	_spawn_extracts(drop)
	preload("res://scripts/collision_opt.gd").optimize(self)
	rebuild_nav()
	if nav != null:
		nav.set_seed(drop)

	if loader != null and is_instance_valid(loader):
		await loader.step(0.91, Loc.t("正在侦测虫群活跃热区与战区首领信标...", "Scanning swarm hotspots & sector boss signals..."))
	_spawn_initial_bugs(drop)
	_sanitize_spawns_and_loot(drop)
	_tmark("extracts+bugs")

	if loader != null and is_instance_valid(loader):
		await loader.step(0.96, Loc.t("正在合并渲染批次与烘焙战术导航网格...", "Batching static meshes & baking tactical navgrid..."))
	_bake_static(drop)
	_tmark("bake")
	_tmark("nav")
	print("[raid] map build %s (async): %d ms, world nodes %d, blocks %d" % [map_id, (Time.get_ticks_usec() - t_build) / 1000, _count_nodes(world), blocks.size()])
	_finish_setup(drop)


func _finish_setup(drop: Vector3) -> void:
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
	add_child(camera)
	camera.current = true
	_apply_style.call_deferred()
	camera.global_position = drop + CAM_OFFSET * _eff_zoom
	camera.look_at(drop, Vector3.UP)
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
	_add_ext_nodes()

	factions = FactionsScript.new()
	factions.name = "Factions"
	add_child(factions)
	factions.setup(self, drop)
	_sanitize_npcs()
	var zone_name := str(MAP.get("name", map_id))
	if Net.active():
		visited_maps = [map_id]
		mech.position = drop + Vector3(0, 0.3, 0)
		mech.input_locked = false
		dropping = false
		hud.show_zone_banner(zone_name, 0.12)
		return
	if transit.is_empty():
		visited_maps = [map_id]
		_drop_sequence(drop)
		hud.show_zone_banner(zone_name, 0.45 if (not GameData.test_mode or force_async_load) else 0.08)
	else:
		world_link.arrive(transit, drop)
		hud.show_zone_banner(zone_name, 0.25 if (GameData.test_mode and not force_async_load) else 0.45)


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
			return Color(0.32, 0.35, 0.30, 1.0)
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
	camera.global_position = drop + Vector3(0, 6.5, 0) + CAM_OFFSET * cam_zoom
	camera.look_at(drop + Vector3(0, 6.5, 0), Vector3.UP)
	# 地面着陆点激光引导环与垂直制导光束
	var beacon_node := Node3D.new()
	fx.add_child(beacon_node)
	beacon_node.global_position = Vector3(drop.x, 0.115, drop.z)
	A.ground_vfx(beacon_node, A.ring_tex(), Color(1.0, 0.68, 0.2, 0.85), 5.2, Vector3.ZERO, true, 0.44, false, 4)
	A.add(beacon_node, A.cyl(0.05, 32.0, 0.05, 8), A.emit(Color(1.0, 0.72, 0.25), 7.5), Vector3(0, 16.0, 0), Vector3.ZERO, Vector3.ONE, false)
	var flames: Array = []
	for x in [-0.55, 0.55]:
		var f := A.emitter(mech, Vector3(x, 0.4, 0.2), {"amount": 36, "life": 0.22, "size": 1.3, "dir": Vector3.DOWN, "spread": 10.0, "vmin": 9.0, "vmax": 14.0,
			"gravity": Vector3.ZERO, "local": true, "c0": Color(1.0, 0.95, 0.8), "cmid": Color(1.0, 0.6, 0.2, 0.9), "c1": Color(0.8, 0.2, 0.05, 0.0), "grow0": 0.5, "grow1": 1.4})
		flames.append(f)
	var trail := A.emitter(mech, Vector3(0, 0.6, 0), {"amount": 34, "life": 1.1, "size": 1.65, "tex": A.smoke_tex(), "additive": false, "spread": 140.0, "vmin": 0.4, "vmax": 1.2,
		"gravity": Vector3(0, 0.8, 0), "c0": Color(0.32, 0.30, 0.28, 0.0), "cmid": Color(0.38, 0.36, 0.34, 0.52), "cmid_pos": 0.20, "c1": Color(0.42, 0.40, 0.38, 0.0), "grow0": 0.4, "grow1": 1.6, "soft_depth": 0.42})
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
		# 反推点火：火焰拉长变亮，地面开始被吹起尘土
		Audio.play_sfx("drop_retro")
		shake = 0.3
		glow.light_energy = 6.0
		for f in flames:
			f.initial_velocity_min = 16.0
			f.initial_velocity_max = 24.0
			f.lifetime = 0.3
		var dt := ground_dust_tint()
		var ground_dust := A.emitter(world, Vector3(drop.x, 0.35, drop.z), {"amount": 42, "life": 0.95, "size": 2.4, "tex": A.dust_tex(), "additive": false, "flat": 0.88,
			"dir": Vector3(1, 0.14, 0), "spread": 180.0, "vmin": 5.5, "vmax": 10.5, "gravity": Vector3(0, 0.5, 0), "damp": 5.0, "box": Vector3(1.2, 0.12, 1.2),
			"c0": Color(dt.r, dt.g, dt.b, 0.0), "cmid": Color(dt.r, dt.g, dt.b, 0.56), "cmid_pos": 0.22, "c1": Color(dt.r * 0.9, dt.g * 0.9, dt.b * 0.9, 0.0), "grow0": 0.45, "grow_mid": 1.25, "grow1": 1.85, "soft_depth": 0.35})
		ground_dust.flatness = 0.85
		ground_dust.damping_min = 4.0
		ground_dust.damping_max = 6.0
		hold["dust"] = ground_dust)
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
	# 贴地扩散的冲击尘环
	var dt := ground_dust_tint()
	A.burst(fx, p + Vector3(0, 0.35, 0), {"amount": 44, "life": 1.45, "size": 2.5, "tex": A.dust_tex(), "additive": false, "dir": Vector3(1, 0, 0), "spread": 180.0, "flat": 0.92,
		"vmin": 10.0, "vmax": 17.5, "gravity": Vector3(0, 0.45, 0), "damp": 7.5, "radius": 1.1, "c0": Color(dt.r, dt.g, dt.b, 0.0), "cmid": Color(dt.r, dt.g, dt.b, 0.58), "cmid_pos": 0.16, "c1": Color(dt.r * 0.88, dt.g * 0.88, dt.b * 0.88, 0.0), "grow0": 0.45, "grow_mid": 1.35, "grow1": 1.95, "soft_depth": 0.38})
	# 冲天的尘柱
	A.burst(fx, p + Vector3(0, 0.8, 0), {"amount": 14, "life": 1.9, "size": 2.8, "tex": A.smoke_tex(), "additive": false, "dir": Vector3.UP, "spread": 32.0,
		"vmin": 2.5, "vmax": 6.0, "gravity": Vector3(0, 0.4, 0), "damp": 2.0, "radius": 1.2, "explosive": 0.8, "c0": Color(dt.r * 0.82, dt.g * 0.80, dt.b * 0.78, 0.0), "cmid": Color(dt.r * 0.75, dt.g * 0.73, dt.b * 0.70, 0.45), "cmid_pos": 0.22, "c1": Color(dt.r * 0.68, dt.g * 0.66, dt.b * 0.64, 0.0), "grow0": 0.45, "grow1": 1.85, "soft_depth": 0.50})
	# 飞溅碎石（3D 实体混凝土/岩石块）
	A.burst(fx, p + Vector3(0, 0.4, 0), {"amount": 26, "life": 1.05, "mesh": _debris_mesh("rock"), "additive": false, "dir": Vector3.UP, "spread": 58.0, "vmin": 5.5, "vmax": 12.5,
		"gravity": Vector3(0, -25, 0), "damp": 0.4, "radius": 0.9, "smin": 0.75, "smax": 1.65, "c0": dt.darkened(0.25), "c1": dt.darkened(0.45), "grow0": 1.0, "grow1": 0.85})
	# 火星
	A.burst(fx, p + Vector3(0, 0.3, 0), {"amount": 20, "life": 0.5, "size": 0.1, "vmin": 6.0, "vmax": 14.0, "gravity": Vector3(0, -18, 0), "damp": 1.0,
		"c0": Color(1.0, 0.9, 0.6), "c1": Color(1.0, 0.35, 0.0, 0.0), "grow0": 1.0, "grow1": 0.2})
	# 弹坑 + 扩散冲击波
	var crater := A.ground_vfx(world, A.scorch_tex(), Color(0.90, 0.86, 0.82, 0.88), 6.2, Vector3(p.x, 0.094, p.z), false, 0.44, false, 2)
	crater.rotation.y = rng.randf() * TAU
	var wave_c := Color(1.0, 0.95, 0.85, 0.9)
	var wave := A.ground_vfx(fx, A.ring_tex(), wave_c, 3.0, Vector3(p.x, 0.116, p.z), true, 0.44, true, 4)
	var tw := create_tween()
	tw.tween_property(wave, "scale", Vector3(8, 1, 8), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(wave.material_override, "shader_parameter/col", Color(wave_c.r, wave_c.g, wave_c.b, 0.0), 0.45)
	tw.tween_callback(wave.queue_free)
	# 起身时背部排气
	var steam: Array = []
	for x: float in [-0.5, 0.5]:
		var sx: float = -0.35 if x < 0.0 else 0.35
		steam.append(A.emitter(mech, Vector3(x, 2.4, 0.6), {"amount": 22, "life": 0.9, "size": 0.78, "tex": A.smoke_tex(), "additive": false, "dir": Vector3(sx, 1.0, 0.55).normalized(),
			"spread": 14.0, "vmin": 3.0, "vmax": 5.2, "gravity": Vector3(0, 1.0, 0), "c0": Color(0.95, 0.96, 0.98, 0.0), "cmid": Color(0.92, 0.94, 0.96, 0.42), "cmid_pos": 0.20, "c1": Color(0.88, 0.90, 0.92, 0.0), "grow0": 0.25, "grow1": 1.65, "soft_depth": 0.35}))
	var t2 := create_tween()
	t2.tween_interval(1.4)
	t2.tween_callback(func():
		for e in steam:
			if is_instance_valid(e):
				e.emitting = false)
	t2.tween_interval(1.2)
	t2.tween_callback(func():
		for e in steam:
			if is_instance_valid(e):
				e.queue_free())


# ================= 世界生成 =================
var flicker_lights: Array = []   ## [OmniLight3D, base_energy, phase]
var ash: CPUParticles3D
var smoke: CPUParticles3D


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.45, 0.45, 0.42)
	sky_mat.sky_horizon_color = Color(0.68, 0.64, 0.56)
	sky_mat.ground_horizon_color = Color(0.42, 0.4, 0.34)
	sky_mat.ground_bottom_color = Color(0.1, 0.08, 0.09)
	sky_mat.sun_angle_max = 26.0
	sky_mat.sun_curve = 0.14
	sky_mat.sky_cover = A.world_tex("sky_clouds.png")
	sky_mat.sky_cover_modulate = Color(0.92, 0.90, 0.86, 0.58)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.42
	env.ambient_light_sky_contribution = 0.65
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.tonemap_white = 8.0
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 0.24
	env.glow_strength = 0.85
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.35
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.60)
	env.set_glow_level(2, 0.45)
	env.set_glow_level(3, 0.25)
	env.set_glow_level(4, 0.0)
	env.set_glow_level(5, 0.0)
	env.ssao_enabled = true
	env.ssao_radius = 2.1
	env.ssao_intensity = 3.6
	env.ssao_power = 1.48
	env.ssil_enabled = false
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8
	env.ssao_detail = 1.0
	env.ssao_horizon = 0.06
	env.ssao_sharpness = 0.96
	env.ssao_light_affect = 0.72
	env.fog_enabled = true
	env.fog_light_color = Color(0.52, 0.5, 0.44)
	env.fog_density = 0.0009
	env.fog_sky_affect = 0.38
	env.volumetric_fog_enabled = false
	env.volumetric_fog_density = 0.0
	env.volumetric_fog_albedo = Color(0.82, 0.8, 0.74)
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_length = 80.0
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.18
	env.adjustment_saturation = 0.90  # 鲜明冷峻的战场色调
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-37, 52, 0)
	sun.light_color = Color(1.0, 0.91, 0.78)
	sun.light_energy = 2.55
	sun.light_angular_distance = 0.25
	sun.shadow_enabled = true
	sun.shadow_bias = 0.02
	sun.shadow_normal_bias = 0.75
	sun.shadow_blur = 0.55
	sun.directional_shadow_max_distance = 72.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_split_1 = 0.35
	sun.directional_shadow_blend_splits = true
	sun.light_volumetric_fog_energy = 1.4
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-50, -140, 0)
	fill.light_color = Color(0.50, 0.62, 0.78)
	fill.light_energy = 0.16
	fill.shadow_enabled = false
	add_child(fill)
	GameData.apply_env_quality(env, sun)
	# 场景里所有点光/聚光都不参与体积雾（见 _no_fog_light）
	get_tree().node_added.connect(_no_fog_light)


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
	flicker_lights.append([l, l.light_energy, rng.randf() * 100.0])


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
	sh.size = Vector3(HALF * 2.0 + 80.0, 1.0, HALF * 2.0 + 80.0)
	cs.shape = sh
	cs.position.y = -0.5
	g.add_child(cs)
	var pm := PlaneMesh.new()
	pm.size = Vector2(2400.0, 2400.0)
	A.add(g, pm, A.ground(), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	world.add_child(g)

	# 焦痕 / 油污 / 湿痕：有机地面污渍贴花（避开水面与道路）
	for i in 72:
		var p := Vector3(rng.randf_range(-gh, gh), 0.0355, rng.randf_range(-gh, gh))
		if in_wet(Vector2(p.x, p.z), 9.0) or on_road(Vector2(p.x, p.z), 2.5):
			continue
		var d := A.ground_decal(world, A.grime_stain_tex(), Color(1, 1, 1, rng.randf_range(0.18, 0.34)), rng.randf_range(4.0, 9.5), p)
		d.rotation.y = rng.randf() * TAU
		d.scale = Vector3(rng.randf_range(0.75, 1.25), 1.0, rng.randf_range(0.65, 1.15))

	# 虫族菌毯：几块不规则的暗色生物膜（仅限战区内部）
	for i in 24:
		var c := Vector3(rng.randf_range(-HALF + 8.0, HALF - 8.0), 0, rng.randf_range(-HALF + 8.0, HALF - 8.0))
		if not in_bounds(c, 8.0) or zone_at(c) in ["D", "R", "I", "H", "Y", "P"]:
			continue
		for k in rng.randi_range(3, 5):
			var r := rng.randf_range(1.6, 3.8)
			var p := c + Vector3(rng.randf_range(-4, 4), 0.037 + k * 0.0005, rng.randf_range(-4, 4))
			if in_wet(Vector2(p.x, p.z), r + 5.0) or on_road(Vector2(p.x, p.z), r + 1.5):
				continue
			var cd := A.ground_decal(world, A.cloud_tex(), Color(0.16, 0.11, 0.07, 0.32), r * 2.4, p)
			cd.rotation.y = rng.randf() * TAU
			cd.scale = Vector3(1.0, 1.0, rng.randf_range(0.6, 1.0))

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
				# 地下超深竖井：参差黑曜岩绝壁 + 外侧深渊岩肩封顶（彻底消除方形外框）
				var h_obs := rng.randf_range(16.0, 26.0)
				var p_obs := mid + outw * rng.randf_range(2.2, 4.5)
				var r_bs := Basis(Vector3.UP, yaw + rng.randf_range(-0.35, 0.35)) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-7, 7)))
				dark_rock_tfs.append(Transform3D(r_bs.scaled_local(Vector3(sub_w * 0.78, h_obs * 0.62, rng.randf_range(4.5, 7.2))), Vector3(p_obs.x, h_obs * 0.42, p_obs.y)))
				var p_sh := mid + outw * rng.randf_range(12.0, 26.0)
				var h_sh := rng.randf_range(19.0, 30.0)
				dark_rock_tfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(sub_w * 1.35, h_sh * 0.65, rng.randf_range(11.0, 18.0))), Vector3(p_sh.x, h_sh * 0.46, p_sh.y)))
				if k % 2 == 0:
					var sh_p := mid + outw * 0.6
					beam_tfs.append(Transform3D((Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(8.0))).scaled_local(Vector3(0.32, 9.5, 0.36)), Vector3(sh_p.x, 4.6, sh_p.y)))
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
				# 跨河/湖封控：航道防撞H型钢群桩 + 锈蚀浮箱拦河桁架 + 黄黑警示横梁（不遮挡河道延伸视线）
				for px_s in [-sub_w * 0.36, 0.0, sub_w * 0.36]:
					A.add(seg_node, A.cyl(0.24, 4.2, 0.28, 10), M_RUST, Vector3(px_s, 1.5, 0.0))
					A.add(seg_node, A.bevel_box(Vector3(0.52, 0.22, 0.52), 0.02), M_DARK, Vector3(px_s, 3.55, 0.0))
				A.add(seg_node, A.bevel_box(Vector3(sub_w + 0.3, 0.42, 0.56), 0.03), M_STEEL, Vector3(0.0, 2.55, 0.0))
				A.add(seg_node, A.bevel_box(Vector3(sub_w * 0.88, 0.16, 0.60), 0.01), M_HAZ, Vector3(0.0, 2.84, 0.0), Vector3.ZERO, Vector3.ONE, false)
				A.add(seg_node, A.cyl(0.42, sub_w * 0.82, 0.42, 12), M_RUST, Vector3(0.0, 0.22, 0.42), Vector3(0, 0, 90))
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
				if (i + k) % 5 == 0:
					A.stencil(seg_node, "SECTOR-%02d" % ((i * 3 + k) % 18 + 1), Vector3(0.0, 2.35, 0.44), Vector3.ZERO, 0.024, Color(0.86, 0.80, 0.64, 0.62))
			elif zt in ["K", "C", "S"]:
				# 悬崖/弹坑/裂隙：层叠风化玄武岩断崖与崩塌岩堆
				var rh := rng.randf_range(6.8, 12.6)
				var rp := mid + outw * rng.randf_range(1.6, 3.2)
				var rbs := Basis(Vector3.UP, yaw + rng.randf_range(-0.4, 0.4)) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-6, 6)))
				rock_tfs.append(Transform3D(rbs.scaled_local(Vector3(sub_w * 0.72, rh * 0.58, rng.randf_range(3.6, 5.8))), Vector3(rp.x, rh * 0.38, rp.y)))
				var tp := mid + inw * 0.35
				rock_tfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(sub_w * 0.46, rh * 0.24, 2.2)), Vector3(tp.x, rh * 0.14, tp.y)))
			else:
				# 郊野/农田/林地/湿地周界：反装甲混凝土龙牙墩阵 + 土石防洪堤埂 + 黄黑封锁横梁（保持外环高速与远郊视野开阔）
				A.add(seg_node, A.bevel_box(Vector3(sub_w + 0.4, 1.35, 2.6), 0.28, 0.72), M_ROCK_SURF, Vector3(0.0, 0.55, -0.3))
				for dx_s in [-sub_w * 0.32, 0.0, sub_w * 0.32]:
					A.add(seg_node, A.cyl(0.32, 1.65, 0.78, 4), M_CON, Vector3(dx_s, 1.15, 0.25), Vector3(0, 45, 0))
				A.add(seg_node, A.bevel_box(Vector3(sub_w + 0.1, 0.18, 0.34), 0.01), M_HAZ, Vector3(0.0, 1.92, -0.25), Vector3.ZERO, Vector3.ONE, false)
				if zt == "T" and rng.randf() < 0.55:
					var rp2 := mid + outw * 2.2
					rock_tfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(sub_w * 0.52, rng.randf_range(2.2, 4.2), 2.6)), Vector3(rp2.x, 1.4, rp2.y)))

	if not is_surface_map:
		# 地下竖井外围高台岩层（覆盖广角俯拍全视野，使深渊井呈现自然塌陷岩洞而非方形盒子）
		var r_step := 22.0
		var r_ext := 460.0
		var rx := -r_ext
		while rx <= r_ext:
			var rz := -r_ext
			while rz <= r_ext:
				var q := Vector2(rx + rng.randf_range(-6.0, 6.0), rz + rng.randf_range(-6.0, 6.0))
				var sd := border_dist(q)
				if sd < -10.0:
					var h_mass := rng.randf_range(20.0, 34.0)
					var w_mass := rng.randf_range(19.0, 29.0)
					var cliff_fac := clampf((-sd - 10.0) / 55.0, 0.0, 1.0)
					var h_scaled := h_mass * (1.0 + cliff_fac * 1.15)
					dark_rock_tfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(w_mass * (1.0 + cliff_fac * 0.25), h_scaled * 0.64, w_mass * rng.randf_range(0.85, 1.18))), Vector3(q.x, h_scaled * 0.46, q.y)))
				rz += r_step
			rx += r_step

	_multimesh(A.rock_mesh(4), M_ROCK_SURF if is_surface_map else M_ROCK_DARK, rock_tfs)
	_multimesh(A.rock_mesh(7), M_OBSID, dark_rock_tfs)
	_multimesh(A.bevel_box(Vector3.ONE, 0.03), M_STEEL, beam_tfs)
	_enforce_zone_bounds = prev_enf


func _bug_spire(p: Vector3, h: float) -> void:
	# 地下自动化熔铸区裂隙排烟导热桩（取代有机甲壳虫塔与悬浮发光圆环：玄武矿渣底座 + 多棱锈蚀铸铁导热烟囱 + 铆接法兰箍 + 窄缝暗琥珀余烬窗）
	var n := Node3D.new()
	world.add_child(n)
	n.position = p
	n.rotation_degrees = Vector3(rng.randf_range(-7, 7), rng.randf() * 360.0, rng.randf_range(-7, 7))
	var r0 := rng.randf_range(0.58, 1.02)
	var M_SLAG := A.rock_mat(Color(0.20, 0.17, 0.15))
	var M_IRON := A.paint(Color(0.20, 0.21, 0.23), 0.68, 0.56, {"rust": 0.72, "wear": 0.62, "grime": 0.85, "panel_scale": 0.9})
	var M_RUST := A.paint(Color(0.34, 0.20, 0.13), 0.52, 0.68, {"rust": 0.88, "wear": 0.65, "grime": 0.82})
	var M_DARK := A.metal(Color(0.12, 0.13, 0.14))
	var m_ember := A.emit(Color(1.0, 0.44, 0.10), 1.4)
	m_ember.albedo_color = Color(0.32, 0.12, 0.03)
	A.add(n, A.cyl(r0 * 1.12, 0.34, r0 * 1.38, 8), M_SLAG, Vector3(0, 0.17, 0))
	var segs := 4
	var y := 0.26
	var rem_h := maxf(1.8, h - 0.26)
	for i in segs:
		var sh := rem_h / float(segs)
		var ra: float = r0 * (1.0 - float(i) / float(segs) * 0.48)
		var rb: float = r0 * (1.0 - float(i + 1) / float(segs) * 0.52)
		A.add(n, A.cyl(rb, sh, ra, 8), M_IRON if i % 2 == 0 else M_RUST, Vector3(0, y + sh * 0.5, 0), Vector3(0, i * 22.5, 0))
		A.add(n, A.cyl(rb * 1.10, 0.10, rb * 1.10, 8), M_DARK, Vector3(0, y + sh - 0.04, 0), Vector3(0, i * 22.5, 0))
		if i < segs - 1:
			for s_i in 4:
				var sa := TAU * float(s_i) / 4.0 + float(i) * 0.4
				A.add(n, A.bevel_box(Vector3(rb * 0.42, 0.07, 0.04), 0.008), m_ember,
					Vector3(cos(sa) * rb * 0.98, y + sh * 0.72, sin(sa) * rb * 0.98), Vector3(0, -rad_to_deg(sa) + 90.0, 0), Vector3.ONE, false)
		y += sh
	A.add(n, A.cyl(r0 * 0.36, 0.12, r0 * 0.40, 8), A.paint(Color(0.03, 0.03, 0.03), 0.0, 0.95), Vector3(0, y + 0.02, 0), Vector3.ZERO, Vector3.ONE, false)
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.35
		A.add(n, A.bevel_box(Vector3(0.12, h * 0.38, r0 * 0.52), 0.02), M_DARK,
			Vector3(cos(a) * r0 * 0.86, h * 0.19, sin(a) * r0 * 0.86), Vector3(0, -rad_to_deg(a) + 90.0, 14.0))
		A.add(n, A.rock_mesh((k * 3 + 1) % 12), M_SLAG,
			Vector3(cos(a + 0.4) * r0 * 1.05, 0.14, sin(a + 0.4) * r0 * 1.05), Vector3(0, k * 67.0, 0), Vector3(r0 * 0.52, 0.28, r0 * 0.44))
	A.ground_decal(n, A.cloud_tex(), Color(0.08, 0.07, 0.06, 0.72), r0 * 3.2, Vector3(0, 0.036, 0))
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
	A.add(n, A.cyl(0.16, 0.12, 0.20, 10), M_DARK, Vector3(0, 0.36, 0))
	A.add(n, A.cyl(0.065, 4.1, 0.115, 10), M_POLE, Vector3(0, 2.38, 0))
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


## 遗迹 POI：类型来自 GameData.POIS（核心三类 + 扩展）。核心类型与 compound = true 的扩展类型建标准围墙院落；
## 扩展类型的 script 负责中央布景（compound = false 时整个 POI 由它负责）。
func _build_pois() -> void:
	rng.seed = _map_seed(7)
	for idx in poi_centers.size():
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
		_place_box("military", c + Vector3(3.5, 0, -3.5))
		_place_box("military", c + Vector3(-4.5, 0, -4))
		_place_box("safe", c + Vector3(4.5, 0, 4.5))
		_place_box("tool", c + Vector3(-1, 0, 5.5))
		var lbl := Label3D.new()
		lbl.text = n
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.font_size = 64
		lbl.pixel_size = 0.02
		lbl.modulate = Color(1.0, 0.85, 0.6)
		lbl.outline_size = 10
		lbl.outline_modulate = Color(0.05, 0.03, 0.02, 0.9)
		lbl.position = c + Vector3(0, 7.0, 0)
		world.add_child(lbl)
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
	A.stencil(body, "EGRET-04", Vector3(-1.60, 0.38, -1.65), Vector3(0, -90, 0), 0.016, Color(0.84, 0.82, 0.74, 0.62))
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
	# 废弃城区楼房：预制模板混凝土 / 工业红砖砌体外墙 + 台阶基座 + 立面壁柱 + 钢框蒙尘玻璃窗 + 压顶女儿墙 + 楼梯间机房与屋顶设备
	var is_brick := rng.randf() < 0.36
	var c := Color(0.52, 0.48, 0.42).lerp(Color(0.41, 0.38, 0.34), rng.randi_range(0, 3) / 3.0)
	if is_brick:
		c = Color(0.46, 0.32, 0.25).lerp(Color(0.38, 0.26, 0.21), rng.randi_range(0, 2) / 2.0)
	var M_WALL: ShaderMaterial = A.brick(c) if is_brick else A.concrete(c)
	var sb := _bldg_body(size, p + Vector3(0, size.y * 0.5, 0))
	sb.rotation.y = -yaw
	_ibox(sb, size, 0.01, M_WALL)
	var hy := size.y * 0.5
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var M_DARK := A.concrete(Color(0.30, 0.29, 0.27) if is_brick else c.darkened(0.36), false)
	var M_TRIM := A.concrete(Color(0.52, 0.49, 0.44) if is_brick else c.lightened(0.14), false)
	var M_ROOF := A.tar_roof(Color(0.24, 0.25, 0.27))
	# 底层散水台基 + 深色勒脚 + 四角壁柱
	_ibox(sb, Vector3(size.x + 0.5, 0.14, size.z + 0.5), 0.02, M_TRIM, Vector3(0, -hy + 0.07, 0), Vector3.ZERO, Vector3.ONE, false)
	_ibox(sb, Vector3(size.x + 0.16, 0.62, size.z + 0.16), 0.03, M_DARK, Vector3(0, -hy + 0.31, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_ibox(sb, Vector3(0.4, size.y + 0.06, 0.4), 0.02, M_TRIM, Vector3(sx * (hx - 0.08), 0.02, sz * (hz - 0.08)))
	# 楼层腰线与顶部挑檐
	var floors := maxi(1, int(size.y / 1.65))
	for f in range(1, floors + 1):
		var y := -hy + f * 1.65 - 0.08
		if y > hy - 0.25:
			break
		_ibox(sb, Vector3(size.x + 0.2, 0.16, size.z + 0.2), 0.02, M_DARK, Vector3(0, y, 0))
	_ibox(sb, Vector3(size.x + 0.32, 0.18, size.z + 0.32), 0.02, M_TRIM, Vector3(0, hy - 0.06, 0))
	# 窗：钢框分格反光蒙尘工业窗（内含微弱残存钠灯窗格）+ 少量木板封窗
	var M_UNIT := A.paint(Color(0.55, 0.56, 0.54), 0.4, 0.6, {"wear": 0.6, "rust": 0.5})
	if size.x > 2.5 and size.z > 2.5:
		var M_WIN := A.window_mat(0.18, Vector2(0.42, 0.46))
		var M_BOARD := A.paint(Color(0.34, 0.25, 0.17), 0.0, 0.92, {"wear": 0.55, "dust": 0.45})
		for f in floors:
			var y := -hy + f * 1.65 + 0.88
			if y > hy - 0.42:
				break
			for axis: int in [0, 1]:
				var length: float = size.x if axis == 0 else size.z
				var depth: float = hz if axis == 0 else hx
				var n := int(length / 1.85)
				for i in n:
					var t := -length * 0.5 + (i + 0.5) * length / n
					for sd: float in [-1.0, 1.0]:
						if rng.randf() > 0.86:
							continue
						var wm: Material = M_WIN if rng.randf() < 0.90 else M_BOARD
						var o: float = sd * (depth + 0.02)
						var pos := Vector3(t, y, o) if axis == 0 else Vector3(o, y, t)
						var rot := Vector3.ZERO if axis == 0 else Vector3(0, 90, 0)
						_ibox(sb, Vector3(0.84, 0.92, 0.08), 0.01, wm, pos, rot, Vector3.ONE, false)
						var sill_p := Vector3(t, y - 0.49, sd * (depth + 0.05)) if axis == 0 else Vector3(sd * (depth + 0.05), y - 0.49, t)
						_ibox(sb, Vector3(0.96, 0.08, 0.14), 0.01, M_TRIM, sill_p, rot, Vector3.ONE, false)
		# 一层门厅雨棚与卷帘装甲门 + 侧墙双轨钢制护笼检修爬梯与立管
		var d_sd := 1.0 if rng.randf() < 0.65 else -1.0
		var dz := (hz + 0.03) * d_sd
		var dw := minf(2.5, size.x * 0.42)
		var dx := rng.randf_range(-hx, hx) * 0.3
		var M_SHUT := A.corrugated(Color(0.20, 0.22, 0.24), 0.45, 0.42)
		_ibox(sb, Vector3(dw, 1.48, 0.10), 0.02, M_DARK, Vector3(dx, -hy + 0.78, dz), Vector3.ZERO, Vector3.ONE, false)
		for sl_i in 4:
			_ibox(sb, Vector3(dw - 0.16, 0.26, 0.07), 0.01, M_SHUT, Vector3(dx, -hy + 0.28 + sl_i * 0.31, dz + d_sd * 0.04), Vector3.ZERO, Vector3.ONE, false)
		_ibox(sb, Vector3(dw + 0.65, 0.16, 0.82), 0.02, M_TRIM, Vector3(dx, -hy + 1.62, dz + d_sd * 0.36))
		if size.y > 4.0:
			var M_LAD := A.metal(Color(0.18, 0.19, 0.20))
			var lx_s := -1.0 if dx > 0.0 else 1.0
			var lad_h := size.y - 0.5
			var lx_p := lx_s * (hx + 0.09)
			for lz_r in [-0.21, 0.21]:
				_ibox(sb, Vector3(0.05, lad_h, 0.06), 0.008, M_LAD, Vector3(lx_p, 0.15, lz_r), Vector3.ZERO, Vector3.ONE, false)
			var n_rungs := int(lad_h / 0.46)
			for ri in n_rungs:
				var ry := 0.15 - lad_h * 0.5 + 0.24 + ri * 0.46
				_ibox(sb, Vector3(0.04, 0.04, 0.42), 0.005, M_LAD, Vector3(lx_p, ry, 0.0), Vector3.ZERO, Vector3.ONE, false)
				if ri >= 4 and ri % 3 == 1:
					_ibox(sb, Vector3(0.32, 0.05, 0.54), 0.01, M_LAD, Vector3(lx_p + lx_s * 0.16, ry, 0.0), Vector3.ZERO, Vector3.ONE, false)
			_imesh(sb, A.cyl(0.05, size.y - 0.2, 0.05, 6), M_LAD, Vector3(-lx_s * (hx - 0.32), 0.0, -d_sd * (hz + 0.06)), Vector3.ZERO, Vector3.ONE, false)
	# 屋顶：深色防水屋面 + 带浅色压顶石的四周女儿墙
	_ibox(sb, Vector3(size.x - 0.24, 0.1, size.z - 0.24), 0.02, M_ROOF, Vector3(0, hy + 0.04, 0), Vector3.ZERO, Vector3.ONE, false)
	var ph := 0.52
	for sd: float in [-1.0, 1.0]:
		var segs := 3
		for k in segs:
			if rng.randf() < 0.12:
				continue
			var len_x := size.x / segs
			var hh := ph * rng.randf_range(0.78, 1.0)
			var px := -hx + (k + 0.5) * len_x
			var pz := sd * (hz - 0.14)
			_ibox(sb, Vector3(len_x, hh, 0.28), 0.02, M_DARK, Vector3(px, hy + hh * 0.5, pz))
			_ibox(sb, Vector3(len_x + 0.08, 0.09, 0.34), 0.02, M_TRIM, Vector3(px, hy + hh + 0.04, pz), Vector3.ZERO, Vector3.ONE, false)
			var span_z := maxf(0.8, size.z - 0.60)
			var len_z := span_z / segs
			hh = ph * rng.randf_range(0.78, 1.0)
			var qx := sd * (hx - 0.14)
			var qz := -span_z * 0.5 + (k + 0.5) * len_z
			_ibox(sb, Vector3(0.28, hh, len_z), 0.02, M_DARK, Vector3(qx, hy + hh * 0.5, qz))
			_ibox(sb, Vector3(0.34, 0.09, len_z + 0.04), 0.02, M_TRIM, Vector3(qx, hy + hh + 0.04, qz), Vector3.ZERO, Vector3.ONE, false)
	# 屋顶楼梯间机房（带铁门与镀锌铁皮排风管道，63°俯视角最具立体感的核心构件）
	var M_METAL_D := A.metal(Color(0.15, 0.155, 0.165))
	var M_DUCT := A.corrugated(Color(0.50, 0.52, 0.51), 0.35, 0.42)
	if size.x >= 5.2 and size.z >= 5.2:
		var pw := clampf(size.x * 0.32, 1.8, 2.8)
		var pd := clampf(size.z * 0.32, 1.6, 2.4)
		var p_h := rng.randf_range(1.6, 2.2)
		var sx_p := 1.0 if rng.randf() < 0.5 else -1.0
		var sz_p := 1.0 if rng.randf() < 0.5 else -1.0
		var pp := Vector3((hx - pw * 0.5 - 0.65) * sx_p, hy + p_h * 0.5, (hz - pd * 0.5 - 0.65) * sz_p)
		_ibox(sb, Vector3(pw, p_h, pd), 0.02, M_WALL, pp)
		_ibox(sb, Vector3(pw + 0.26, 0.16, pd + 0.26), 0.02, M_DARK, pp + Vector3(0, p_h * 0.5 + 0.08, 0))
		_ibox(sb, Vector3(0.76, minf(1.35, p_h * 0.78), 0.08), 0.01, M_METAL_D, pp + Vector3(0, -p_h * 0.1, -sz_p * (pd * 0.5 + 0.03)), Vector3.ZERO, Vector3.ONE, false)
		var duct_l := clampf(size.x * 0.44, 1.8, 4.4)
		_ibox(sb, Vector3(duct_l, 0.34, 0.38), 0.02, M_DUCT, Vector3(-sx_p * hx * 0.15, hy + 0.28, -sz_p * hz * 0.22), Vector3.ZERO, Vector3.ONE, false)
	# 屋顶设备：带深色风扇井的工业空调外机、带风帽通风管、高架锈蚀水箱
	for k in rng.randi_range(1, 3):
		var up := Vector3(rng.randf_range(-hx, hx) * 0.5, hy + 0.38, rng.randf_range(-hz, hz) * 0.5)
		var u_yaw := rng.randi_range(0, 3) * 90.0
		_ibox(sb, Vector3(1.18, 0.72, 0.84), 0.04, M_UNIT, up, Vector3(0, u_yaw, 0))
		_imesh(sb, A.cyl(0.30, 0.08, 0.30, 12), M_METAL_D, up + Vector3(0, 0.36, 0), Vector3.ZERO, Vector3.ONE, false)
	for k in rng.randi_range(1, 3):
		var vp := Vector3(rng.randf_range(-hx, hx) * 0.62, hy + 0.38, rng.randf_range(-hz, hz) * 0.62)
		_imesh(sb, A.cyl(0.13, 0.75, 0.13, 8), A.metal(Color(0.38, 0.39, 0.4)), vp)
		_imesh(sb, A.cyl(0.20, 0.09, 0.10, 8), M_DUCT, vp + Vector3(0, 0.40, 0), Vector3.ZERO, Vector3.ONE, false)
	if size.x * size.z > 30.0 and rng.randf() < 0.6:
		var tp := Vector3(rng.randf_range(-hx, hx) * 0.42, hy, rng.randf_range(-hz, hz) * 0.42)
		for lx in [-0.5, 0.5]:
			for lz in [-0.5, 0.5]:
				_imesh(sb, A.cyl(0.05, 0.8, 0.05, 6), A.metal(Color(0.2, 0.2, 0.2)), tp + Vector3(lx, 0.4, lz))
		_imesh(sb, A.cyl(0.78, 1.15, 0.78, 16), A.paint(Color(0.5, 0.42, 0.32), 0.5, 0.6, {"rust": 0.8, "wear": 0.6}), tp + Vector3(0, 1.38, 0))
		_imesh(sb, A.cyl(0.05, 0.25, 0.82, 16), A.metal(Color(0.3, 0.27, 0.24)), tp + Vector3(0, 2.06, 0))
	else:
		_ibox(sb, Vector3(0.95, 0.3, 0.95), 0.03, M_DARK, Vector3(rng.randf_range(-hx, hx) * 0.45, hy + 0.16, rng.randf_range(-hz, hz) * 0.45))
	# 少数楼挂着带金属灯箱外框与支架的残存工业招牌
	if size.y > 3.0 and rng.randf() < 0.3:
		var nc: Color = [Color(1.0, 0.48, 0.18), Color(0.32, 0.82, 0.96), Color(0.96, 0.72, 0.26)][rng.randi() % 3]
		var sp := Vector3(0, hy - 0.8, hz + 0.16)
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


func _wreck_car(p: Vector3, yaw_deg := INF) -> void:
	# 三种写实废弃机动车轮廓：0 三厢轿车、1 工程皮卡（开放货斗+防滚架）、2 厢式工具面包车
	var vtype := rng.randi() % 3
	var c: Color = [Color(0.46, 0.22, 0.16), Color(0.24, 0.32, 0.38), Color(0.50, 0.44, 0.30), Color(0.32, 0.34, 0.35), Color(0.27, 0.35, 0.27)][rng.randi() % 5]
	var M_BODY := A.paint(c, 0.42, 0.62, {"wear": 0.62, "rust": 0.55})
	var M_ROOF := A.paint(c.lightened(0.06), 0.42, 0.60, {"wear": 0.58, "rust": 0.52})
	var M_GLASS := A.glass(Color(0.16, 0.22, 0.26))
	var M_TRIM := A.metal(Color(0.15, 0.16, 0.17))
	var M_DARK := A.paint(Color(0.06, 0.06, 0.07), 0.1, 0.85)
	var sb := _bldg_body(Vector3(1.96, 1.35, 4.35), p + Vector3(0, 0.68, 0))
	sb.rotation_degrees.y = yaw_deg if yaw_deg < INF else rng.randf_range(0, 180)
	# 下车体底盘 + 前后防撞保险杠 + 散热中网与暗灯碗
	_ibox(sb, Vector3(1.92, 0.62, 4.28), 0.04, M_BODY, Vector3(0, -0.08, 0))
	_ibox(sb, Vector3(2.02, 0.22, 0.26), 0.03, M_TRIM, Vector3(0, -0.26, -2.14), Vector3.ZERO, Vector3.ONE, false)
	_ibox(sb, Vector3(2.02, 0.22, 0.26), 0.03, M_TRIM, Vector3(0, -0.26, 2.14), Vector3.ZERO, Vector3.ONE, false)
	_ibox(sb, Vector3(1.12, 0.28, 0.08), 0.01, M_DARK, Vector3(0, -0.04, -2.15), Vector3.ZERO, Vector3.ONE, false)
	for lx in [-0.72, 0.72]:
		_ibox(sb, Vector3(0.30, 0.16, 0.08), 0.01, M_GLASS, Vector3(lx, 0.02, -2.15), Vector3.ZERO, Vector3.ONE, false)
		_ibox(sb, Vector3(0.32, 0.15, 0.08), 0.01, A.paint(Color(0.28, 0.08, 0.06), 0.1, 0.5), Vector3(lx, 0.02, 2.15), Vector3.ZERO, Vector3.ONE, false)
	if vtype == 0:
		# 三厢轿车：微倾引擎盖 + 梯形乘员舱 + 后备箱盖
		_ibox(sb, Vector3(1.74, 0.12, 1.24), 0.03, M_ROOF, Vector3(0, 0.26, -1.42), Vector3(4, 0, 0), Vector3.ONE, false)
		_ibox(sb, Vector3(1.72, 0.09, 0.88), 0.02, M_ROOF, Vector3(0, 0.24, 1.62), Vector3(-3, 0, 0), Vector3.ONE, false)
		A.add(sb, A.bevel_box(Vector3(1.72, 0.58, 2.05), 0.10, 0.82), M_ROOF, Vector3(0, 0.50, 0.08))
		_ibox(sb, Vector3(1.54, 0.40, 2.10), 0.03, M_GLASS, Vector3(0, 0.48, 0.08), Vector3.ZERO, Vector3.ONE, false)
		_ibox(sb, Vector3(1.76, 0.38, 1.66), 0.03, M_GLASS, Vector3(0, 0.48, 0.08), Vector3.ZERO, Vector3.ONE, false)
		_ibox(sb, Vector3(1.78, 0.42, 0.13), 0.02, M_BODY, Vector3(0, 0.48, 0.12), Vector3.ZERO, Vector3.ONE, false)
	elif vtype == 1:
		# 工业工程皮卡：高车头 + 短驾驶楼 + 防滚龙门架 + 凹陷敞口货箱
		_ibox(sb, Vector3(1.82, 0.18, 1.32), 0.03, M_ROOF, Vector3(0, 0.30, -1.42), Vector3(3, 0, 0), Vector3.ONE, false)
		A.add(sb, A.bevel_box(Vector3(1.78, 0.66, 1.38), 0.08, 0.88), M_ROOF, Vector3(0, 0.54, -0.22))
		_ibox(sb, Vector3(1.60, 0.44, 1.42), 0.02, M_GLASS, Vector3(0, 0.54, -0.22), Vector3.ZERO, Vector3.ONE, false)
		_ibox(sb, Vector3(1.82, 0.42, 0.96), 0.02, M_GLASS, Vector3(0, 0.54, -0.22), Vector3.ZERO, Vector3.ONE, false)
		_ibox(sb, Vector3(1.66, 0.08, 1.56), 0.01, M_DARK, Vector3(0, 0.18, 1.28), Vector3.ZERO, Vector3.ONE, false)
		for bx in [-0.88, 0.88]:
			_ibox(sb, Vector3(0.14, 0.34, 1.64), 0.02, M_BODY, Vector3(bx, 0.34, 1.28))
		_ibox(sb, Vector3(1.74, 0.58, 0.09), 0.02, M_TRIM, Vector3(0, 0.56, 0.54), Vector3.ZERO, Vector3.ONE, false)
	else:
		# 厢式勤务工具车：短鼻前脸 + 贯通高顶金属货厢 + 车顶行李钢架
		_ibox(sb, Vector3(1.82, 0.22, 0.72), 0.03, M_ROOF, Vector3(0, 0.30, -1.74), Vector3(12, 0, 0), Vector3.ONE, false)
		A.add(sb, A.bevel_box(Vector3(1.86, 0.84, 3.36), 0.08, 0.94), M_ROOF, Vector3(0, 0.62, 0.38))
		_ibox(sb, Vector3(1.66, 0.46, 0.12), 0.02, M_GLASS, Vector3(0, 0.64, -1.28), Vector3(14, 0, 0), Vector3.ONE, false)
		_ibox(sb, Vector3(1.90, 0.42, 0.86), 0.02, M_GLASS, Vector3(0, 0.64, -0.72), Vector3.ZERO, Vector3.ONE, false)
		for rz in [-0.2, 0.8, 1.6]:
			_ibox(sb, Vector3(1.68, 0.07, 0.09), 0.01, M_TRIM, Vector3(0, 1.07, rz), Vector3.ZERO, Vector3.ONE, false)
	# 四轮暗色轮拱衬套 + 橡胶轮胎 + 钢制轮毂
	for wx in [-0.94, 0.94]:
		for wz in [-1.32, 1.32]:
			_ibox(sb, Vector3(0.18, 0.48, 0.84), 0.02, M_DARK, Vector3(wx * 0.92, -0.22, wz), Vector3.ZERO, Vector3.ONE, false)
			_imesh(sb, A.cyl(0.38, 0.26, 0.38, 12), A.rubber(), Vector3(wx, -0.30, wz), Vector3(0, 0, 90))
			_imesh(sb, A.cyl(0.20, 0.28, 0.20, 10), M_TRIM, Vector3(wx, -0.30, wz), Vector3(0, 0, 90), Vector3.ONE, false)
	blocks.append(_rect_for(p, Vector3(4, 1, 4)))


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


func _place_box(kind: String, pos: Vector3, loot: Array = []):
	var b = LootScript.new()
	world.add_child(b)
	b.position = pos
	b.rotation_degrees.y = rng.randf_range(-20, 20)
	b.setup(kind, loot if not loot.is_empty() else GameData.roll_loot(kind, rng))
	return b


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


func _process_impl(delta: float) -> void:
	if mech == null:
		return
	if hud != null and hud.joy_left != null and hud.joy_right != null:
		mech.joy_move = hud.joy_left.value
		mech.joy_aim = hud.joy_right.value
	# 镜头跟随 + 双摇杆瞄准 / 鼠标前探
	var vp_sz := get_viewport().get_visible_rect().size
	var mp := get_viewport().get_mouse_position().clamp(Vector2.ZERO, vp_sz)
	var from := camera.project_ray_origin(mp)
	var dir := camera.project_ray_normal(mp)
	var hit = Plane(Vector3.UP, 1.8).intersects_ray(from, dir) if dir.y < -0.05 else null
	var ray_max := 160.0 if mech.is_scoping() else (110.0 if mech.is_aiming else 80.0)
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
	var ui_block: bool = hud != null and (hud.pause_panel.visible or (hud.settings_panel != null and hud.settings_panel.visible) or hud.loot_panel.visible or hud.map_open())
	var aiming: bool = mech.is_aiming and not dropping and not ended and not ui_block
	var scoping: bool = aiming and mech.is_scoping()
	var recon_pts := 0.0
	if mech.get("stats") != null:
		recon_pts = float(mech.stats.get("recon", 0.0)) + (1.0 if bool(mech.stats.get("recon_tag", false)) else 0.0)
	var pan_cap := 4.5
	var zoom_want := cam_zoom
	var lerp_spd := 10.0 if dropping else 6.0
	if scoping:
		pan_cap = 42.0 + clampf(recon_pts, 0.0, 8.0) * 5.0
		zoom_want = maxf(cam_zoom, ZOOM_STD * (2.25 + clampf(recon_pts, 0.0, 8.0) * 0.14))
		lerp_spd = 7.5
	elif aiming:
		pan_cap = 10.0 + clampf(recon_pts, 0.0, 8.0) * 3.5
		zoom_want = maxf(cam_zoom, ZOOM_STD * (1.28 + clampf(recon_pts, 0.0, 8.0) * 0.12))
		lerp_spd = 7.0
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
	var tt := Time.get_ticks_msec() * 0.001
	for f in flicker_lights:
		if is_instance_valid(f[0]):
			var k: float = 0.82 + 0.12 * sin(tt * 13.0 + f[2]) + 0.08 * sin(tt * 31.0 + f[2] * 2.0)
			if fmod(tt + f[2], 7.0) < 0.12:
				k *= 0.3
			f[0].light_energy = f[1] * k
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
	var dn := district_at(mech.global_position)
	if dn != cur_district:
		if cur_district != "":
			_event("district_entered", [dn])
		cur_district = dn
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.25
		_threat_scan(0.25)
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
	var near_chase := INF
	for b in get_tree().get_nodes_in_group("bugs"):
		var d: float = b.global_position.distance_to(mp)
		if b.state == "chase":
			near_chase = minf(near_chase, d)
		if d < 26.0 and not _seen_kinds.has(b.kind) and not bool(b.data.get("boss", false)):
			_seen_kinds[b.kind] = true
			_event("enemy_seen", [b.kind, GameData.mark_enemy_seen(b.kind), b.global_position])
	if near_chase < 28.0:
		_combat_quiet = 0.0
		if not in_combat:
			in_combat = true
			_event("combat_changed", [true])
	elif in_combat:
		_combat_quiet = _combat_quiet + dt if near_chase > 40.0 else 0.0
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
	# 重工战术倾转涡扇撤离艇「信天翁-2」(ALBATROSS-02)：多折面装甲机身 + 防擦龙骨与起落滑橇 + 框架防弹风挡 + 短翼倾转涡扇短舱 + 尾跳板
	transport_ship = Node3D.new()
	world.add_child(transport_ship)
	transport_ship.position = transport_zone.position + Vector3(0, 50, 0)
	var M_HULL := A.paint(Color(0.56, 0.54, 0.45), 0.36, 0.54, {"wear": 0.48, "rust": 0.35, "grime": 0.55, "panel_scale": 1.3})
	var M_SUB := A.paint(Color(0.38, 0.39, 0.35), 0.42, 0.56, {"wear": 0.52, "rust": 0.4})
	var M_DARK := A.metal(Color(0.14, 0.15, 0.16))
	var M_CHR := A.chrome()
	var M_GLASS := A.glass(Color(0.24, 0.52, 0.62))
	# 主货舱折面机身 + 背脊航电整流罩 + 腹部龙骨装甲 + 环形加强隔框 + 两侧起落架滑橇
	A.add(transport_ship, A.bevel_box(Vector3(3.30, 2.15, 7.80), 0.36, 0.88), M_HULL, Vector3(0, 0.10, 0.25))
	A.add(transport_ship, A.bevel_box(Vector3(2.90, 0.52, 8.30), 0.15), M_DARK, Vector3(0, -0.92, 0.05))
	A.add(transport_ship, A.bevel_box(Vector3(1.48, 0.48, 6.10), 0.12, 0.82), M_SUB, Vector3(0, 1.32, 0.35))
	A.add(transport_ship, A.bevel_box(Vector3(3.42, 0.24, 1.65), 0.04), A.hazard(), Vector3(0, 0.22, -1.45))
	for rz in [-2.6, -1.1, 0.4, 1.9, 3.3]:
		A.add(transport_ship, A.bevel_box(Vector3(3.44, 2.26, 0.15), 0.04, 0.88), M_DARK, Vector3(0, 0.10, rz))
	for sx_sk in [-1.42, 1.42]:
		A.add(transport_ship, A.bevel_box(Vector3(0.18, 0.12, 5.20), 0.02), M_DARK, Vector3(sx_sk, -1.52, 0.15))
		for sz_st in [-1.65, 1.85]:
			A.add(transport_ship, A.cyl(0.06, 0.62, 0.06, 8), M_CHR, Vector3(sx_sk * 0.92, -1.22, sz_st), Vector3(0, 0, sx_sk * 10.0))
	# 收分前机鼻、气象雷达罩与多窗格防弹驾驶舱罩
	A.add(transport_ship, A.bevel_box(Vector3(2.62, 1.65, 2.40), 0.24, 0.78), M_HULL, Vector3(0, -0.10, -4.25), Vector3(7, 0, 0))
	A.add(transport_ship, A.cyl(0.40, 0.92, 0.80, 14), M_DARK, Vector3(0, -0.28, -5.62), Vector3(-84, 0, 0))
	A.add(transport_ship, A.bevel_box(Vector3(2.04, 0.68, 1.60), 0.10, 0.76), M_DARK, Vector3(0, 0.72, -3.82), Vector3(-16, 0, 0))
	A.add(transport_ship, A.bevel_box(Vector3(1.86, 0.50, 1.42), 0.04, 0.78), M_GLASS, Vector3(0, 0.76, -3.86), Vector3(-16, 0, 0))
	for mx in [-0.48, 0.0, 0.48]:
		A.add(transport_ship, A.bevel_box(Vector3(0.06, 0.58, 1.48), 0.01), M_DARK, Vector3(mx, 0.76, -3.86), Vector3(-16, 0, 0), Vector3.ONE, false)
	# 上单翼主翼盒 + 翼尖垂直悬停倾转涡扇引擎短舱 + 双外倾 V 尾与尾部微开跳板舱门
	A.add(transport_ship, A.bevel_box(Vector3(11.6, 0.34, 2.35), 0.08, 0.86), M_SUB, Vector3(0, 0.86, 0.45))
	A.add(transport_ship, A.bevel_box(Vector3(11.4, 0.10, 0.42), 0.02), M_DARK, Vector3(0, 0.86, 1.52))
	A.add(transport_ship, A.bevel_box(Vector3(2.70, 1.62, 1.85), 0.18, 0.76), M_HULL, Vector3(0, 0.34, 4.55), Vector3(12, 0, 0))
	A.add(transport_ship, A.bevel_box(Vector3(2.18, 0.16, 2.05), 0.04), M_DARK, Vector3(0, -0.58, 4.95), Vector3(22, 0, 0))
	for sx_t in [-1.0, 1.0]:
		A.add(transport_ship, A.bevel_box(Vector3(0.20, 2.30, 1.65), 0.05, 0.62), M_SUB, Vector3(sx_t * 1.22, 1.72, 4.45), Vector3(-18, 0, sx_t * -16.0))
	for sx in [-5.6, 5.6]:
		A.add(transport_ship, A.bevel_box(Vector3(0.72, 0.68, 1.15), 0.06), M_DARK, Vector3(sx * 0.88, 0.82, 0.45))
		A.add(transport_ship, A.cyl(0.84, 2.15, 0.90, 18), M_HULL, Vector3(sx, 0.56, 0.45))
		A.add(transport_ship, A.torus(0.76, 0.92, 18), M_DARK, Vector3(sx, 1.62, 0.45), Vector3.ZERO, Vector3(1, 0.6, 1), false)
		A.add(transport_ship, A.cyl(0.92, 0.18, 0.92, 18), A.hazard(), Vector3(sx, 0.95, 0.45))
		A.add(transport_ship, A.cyl(0.72, 0.32, 0.86, 18), M_DARK, Vector3(sx, -0.52, 0.45))
		var m_thr := A.emit(Color(0.38, 0.78, 1.0), 3.6)
		m_thr.albedo_color = Color(0.10, 0.24, 0.36)
		A.add(transport_ship, A.cyl(0.62, 0.12, 0.62, 16), m_thr, Vector3(sx, -0.62, 0.45), Vector3.ZERO, Vector3.ONE, false)
		var l := OmniLight3D.new()
		l.light_color = Color(0.4, 0.8, 1.0)
		l.light_energy = 3.0
		l.omni_range = 8.0
		l.position = Vector3(sx, -1.0, 0.45)
		transport_ship.add_child(l)
	for sx in [-6.45, 6.45]:
		A.add(transport_ship, A.bevel_box(Vector3(0.16, 0.16, 0.32), 0.03), A.emit(Color(1, 0.2, 0.2) if sx < 0 else Color(0.2, 1, 0.3), 4.5), Vector3(sx, 0.62, 0.45), Vector3.ZERO, Vector3.ONE, false)
	A.stencil(transport_ship, "ALBATROSS-02", Vector3(-1.68, 0.36, -0.85), Vector3(0, -90, 0), 0.016, Color(0.90, 0.88, 0.78, 0.72))
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.95, 0.85)
	spot.light_energy = 6.0
	spot.spot_range = 30.0
	spot.spot_angle = 30.0
	spot.position = Vector3(0, -1.2, -2.0)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	transport_ship.add_child(spot)
	var dust := A.emitter(transport_ship, Vector3(0, -4.8, 0), {"amount": 40, "life": 1.2, "size": 2.0, "tex": A.smoke_tex(), "additive": false,
		"dir": Vector3(0, 0.1, 0), "spread": 180.0, "vmin": 6.0, "vmax": 10.0, "gravity": Vector3.ZERO, "radius": 2.0,
		"c0": Color(0.6, 0.52, 0.45, 0.5), "c1": Color(0.5, 0.45, 0.4, 0.0), "grow0": 0.6, "grow1": 2.0})
	dust.emitting = false
	Audio.play_sfx("transport_arrive", transport_zone.global_position + Vector3(0, 8, 0))
	var tw := create_tween()
	tw.tween_property(transport_ship, "position:y", transport_zone.position.y + 5.0, 2.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
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
	var from: Vector3 = mech.global_position + Vector3(0, 1.1, 0)
	var to: Vector3 = b.global_position + Vector3(0, 0.65, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var ex: Array = []
	if mech is CollisionObject3D:
		ex.append(mech.get_rid())
	if b is CollisionObject3D:
		ex.append(b.get_rid())
	q.exclude = ex
	return w3.direct_space_state.intersect_ray(q).is_empty()


func nearest_box(maxd: float):
	var best = null
	var bd := maxd
	for b in get_tree().get_nodes_in_group("lootboxes"):
		var d: float = b.global_position.distance_to(mech.global_position)
		if d < bd and _box_los_ok(b):
			bd = d
			best = b
	return best


func _update_loot(delta: float) -> void:
	if open_box:
		if not is_instance_valid(open_box) or open_box.global_position.distance_to(mech.global_position) > 4.5:
			close_box()
			return
		if open_box.revealed < open_box.items.size():
			open_box.reveal_t += delta
			var reveal_step := 0.55 * maxf(0.5, 1.0 - 0.04 * float(Growth.ability_level("ab_search")))
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
	for o in get_tree().get_nodes_in_group("lootboxes"):
		o.set_near(o == b)
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
	var bd := maxd
	for b in get_tree().get_nodes_in_group("bugs"):
		if b.is_in_group("boss"):
			if not include_boss or not b.awake:
				continue
		var d: float = b.global_position.distance_to(p)
		if d < bd:
			bd = d
			best = b
	return best


func alert_noise(p: Vector3, radius: float) -> void:
	for b in get_tree().get_nodes_in_group("bugs"):
		if b.global_position.distance_to(p) < radius:
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
	var fov: float = camera.fov if camera else 40.0
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
		var np: Vector3 = nav.nearest_reachable(p, true, 16.0)
		if np != Vector3.INF and in_bounds(np, 3.0) and not in_wet(Vector2(np.x, np.z), 1.5):
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


func _proj(pos: Vector3, vel: Vector3, dmg: float, life: float, mask: int, c: Color, size: float, _glow := false, kind := "shell"):
	if coop != null: coop.emit_effect("shot", [pos, vel, life, c, size, kind])
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
	var m_steel := A.metal(Color(0.24, 0.26, 0.28))
	var m_dark := A.metal(Color(0.12, 0.13, 0.15))
	var m_brass := A.paint(Color(0.88, 0.66, 0.22), 0.9, 0.26, {"panel_scale": 0.0, "wear": 0.12})
	var m_copper := A.paint(Color(0.84, 0.45, 0.24), 0.88, 0.28, {"panel_scale": 0.0, "wear": 0.12})
	match kind:
		"missile", "rocket", "vls":
			p.spin_spd = 14.0 if kind != "rocket" else 22.0
			var r := size * (0.64 if kind == "vls" else (0.50 if kind == "rocket" else 0.56))
			var body_col := Color(0.26, 0.29, 0.31) if kind == "vls" else (Color(0.30, 0.34, 0.24) if kind == "rocket" else Color(0.24, 0.27, 0.25))
			var nose_col := Color(0.76, 0.22, 0.14) if kind != "rocket" else Color(0.68, 0.54, 0.22)
			var m_fuse := A.paint(body_col, 0.55, 0.44, {"panel_scale": 0.0, "wear": 0.25})
			var m_nose := A.paint(nose_col, 0.28, 0.42, {"panel_scale": 0.0, "wear": 0.2})
			var m_band := A.paint(Color(0.92, 0.74, 0.16), 0.3, 0.42, {"panel_scale": 0.0})
			# 实体军工火箭/导弹弹体：车削钢制发动机管 + 战斗部风帽 + 黄铜碰炸引信探针 + 黄黑识别环 + 十字钢制安定翼 + 文丘里金属喷管
			A.add(body, A.cyl(r, size * 3.3, r, 14), m_fuse, Vector3(0, 0, size * 0.2), Vector3(90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(r * 0.22, size * 1.38, r, 14), m_nose, Vector3(0, 0, -size * 2.12), Vector3(-90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(0.014, size * 0.36, r * 0.22, 10), m_brass, Vector3(0, 0, -size * 2.95), Vector3(-90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(r * 1.04, size * 0.28, r * 1.04, 14), m_band, Vector3(0, 0, -size * 0.9), Vector3(90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(r * 0.68, size * 0.48, r * 0.92, 12), m_dark, Vector3(0, 0, size * 2.02), Vector3(90, 0, 0), Vector3.ONE, false)
			for fi in 4:
				var fa := fi * 90.0
				A.add(body, _box_cached(Vector3(size * 0.09, size * 1.48, size * 0.95)), m_dark, Vector3(0, 0, size * 1.25), Vector3(0, 0, fa), Vector3.ONE, false)
				if kind != "rocket":
					A.add(body, _box_cached(Vector3(size * 0.07, size * 0.82, size * 0.42)), m_steel, Vector3(0, 0, -size * 0.65), Vector3(0, 0, fa + 45.0), Vector3.ONE, false)
			# 文丘里扩张钢喷管内腔与石墨喷口衬环（纯实体重工金属结构，零发光球体）
			A.add(body, A.cyl(r * 0.42, size * 0.22, r * 0.66, 10), m_copper, Vector3(0, 0, size * 2.18), Vector3(90, 0, 0), Vector3.ONE, false)
		"spit":
			p.spin_spd = 18.0
			var rs := size * 0.42
			var m_can := A.paint(Color(0.28, 0.35, 0.20), 0.42, 0.48, {"rust": 0.45, "wear": 0.35})
			var m_haz := A.hazard()
			# 重工业强酸破片钢瓶弹：加厚钢壳瓶身 + 橄榄绿防腐涂层罐 + 黄黑高危环 + 黄铜撞击引信头 + 十字钢尾翼（彻底取代发光有机毒球）
			A.add(body, A.cyl(rs, size * 1.95, rs * 1.04, 12), m_can, Vector3(0, 0, 0.05 * size), Vector3(90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(rs * 1.08, size * 0.34, rs * 1.08, 12), m_haz, Vector3(0, 0, -size * 0.42), Vector3(90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(rs * 0.38, size * 0.56, rs, 12), m_steel, Vector3(0, 0, -size * 1.18), Vector3(-90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(rs * 0.22, size * 0.22, rs * 0.38, 10), m_brass, Vector3(0, 0, -size * 1.54), Vector3(-90, 0, 0), Vector3.ONE, false)
			for fi in 4:
				A.add(body, _box_cached(Vector3(rs * 0.18, rs * 2.15, size * 0.62)), m_dark, Vector3(0, 0, size * 0.88), Vector3(0, 0, fi * 90.0), Vector3.ONE, false)
		"flamer":
			p.spin_spd = 24.0
			var rf := size * 0.38
			var m_char := A.paint(Color(0.16, 0.14, 0.13), 0.45, 0.68, {"rust": 0.5, "wear": 0.4})
			var m_inc := A.paint(Color(0.84, 0.30, 0.12), 0.32, 0.45, {"panel_scale": 0.0, "wear": 0.25})
			# 40mm 实体增压铝热凝固汽油钢壳燃烧弹：熏黑穿孔钢壳弹筒 + 橘红燃烧弹识别风帽 + 黄铜闭气弹带（彻底取代纯光球）
			A.add(body, A.cyl(rf, size * 1.55, rf, 10), m_char, Vector3(0, 0, size * 0.1), Vector3(90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(rf * 0.32, size * 0.68, rf, 10), m_inc, Vector3(0, 0, -size * 0.98), Vector3(-90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(rf * 1.07, size * 0.18, rf * 1.07, 10), m_brass, Vector3(0, 0, size * 0.45), Vector3(90, 0, 0), Vector3.ONE, false)
		"cryo":
			p.spin_spd = 18.0
			var rc := size * 0.38
			var m_n2 := A.paint(Color(0.32, 0.40, 0.46), 0.48, 0.42, {"panel_scale": 0.0, "wear": 0.25})
			A.add(body, A.cyl(rc, size * 1.65, rc, 10), m_n2, Vector3(0, 0, size * 0.08), Vector3(90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(rc * 0.30, size * 0.62, rc, 10), m_steel, Vector3(0, 0, -size * 1.02), Vector3(-90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(rc * 1.06, size * 0.16, rc * 1.06, 10), m_brass, Vector3(0, 0, size * 0.42), Vector3(90, 0, 0), Vector3.ONE, false)
		_:
			p.spin_spd = 32.0
			var rd := maxf(size * 0.42, 0.065)
			var Ld := maxf(size * 2.8, 0.52)
			A.add(body, A.cyl(rd * 0.9, Ld * 0.56, rd, 10), m_steel, Vector3(0, 0, Ld * 0.06), Vector3(90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(0.01, Ld * 0.48, rd * 0.9, 10), m_copper, Vector3(0, 0, -Ld * 0.46), Vector3(-90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(rd * 1.07, Ld * 0.10, rd * 1.07, 10), m_brass, Vector3(0, 0, Ld * 0.18), Vector3(90, 0, 0), Vector3.ONE, false)
	if body.get_child_count() > 1:
		MechScript._batch_visual(body)
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


func _tracer(pos: Vector3, vel: Vector3, dmg: float, life: float, c: Color, w: float, core: float, caliber := "mg"):
	if coop != null: coop.emit_effect("shot", [pos, vel, life, c, w, "tracer:" + caliber])
	var key := "%s|%s|%s|%s" % [c, w, core, caliber]
	var br := clampf(core * 0.34, 0.016, 0.028)
	var bl := clampf(core * 3.0, 0.18, 0.28)
	match caliber:
		"apfsds": br = 0.022; bl = 0.42
		"sniper_ap": br = 0.022; bl = 0.40
		"sniper": br = 0.019; bl = 0.34
		"coil": br = 0.018; bl = 0.32
		"cannon": br = 0.048; bl = 0.40
		"ac30": br = 0.030; bl = 0.28
		"slug": br = 0.026; bl = 0.22
		"pellet": br = 0.014; bl = 0.16
	var is_hi_vel := caliber in ["apfsds", "sniper", "sniper_ap", "coil"]
	var wake_w := br * 2.0
	var wake_len := bl * (2.35 if is_hi_vel else (1.85 if caliber == "cannon" else 1.70))
	var t_off := bl * 0.45
	var spin_v := 18.0 if (is_hi_vel or caliber == "cannon") else 38.0
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
		q.look_at(pos + vel, Vector3.UP)
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
	# 3D 写实重工业实体金属弹药（按真实口径比例缩放）
	var body := Node3D.new()
	p.add_child(body)
	p.body_node = body
	var m_steel := A.metal(Color(0.24, 0.26, 0.28))
	var m_dark := A.metal(Color(0.13, 0.14, 0.16))
	var m_tung := A.metal(Color(0.42, 0.44, 0.47))
	var m_brass := A.paint(Color(0.88, 0.66, 0.22), 0.9, 0.25, {"panel_scale": 0.0, "wear": 0.1})
	var m_copper := A.paint(Color(0.84, 0.45, 0.24), 0.88, 0.28, {"panel_scale": 0.0, "wear": 0.1})
	match caliber:
		"apfsds":
			A.add(body, A.cyl(br * 0.56, bl * 0.72, br * 0.64, 10), m_tung, Vector3(0, 0, 0.05 * bl), Vector3(90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(0.004, bl * 0.34, br * 0.56, 10), A.chrome(), Vector3(0, 0, -bl * 0.48), Vector3(-90, 0, 0), Vector3.ONE, false)
			for gi in 3:
				A.add(body, A.cyl(br * 0.92, bl * 0.038, br * 0.92, 10), m_brass, Vector3(0, 0, (-0.08 + gi * 0.075) * bl), Vector3(90, 0, 0), Vector3.ONE, false)
			for fi in 3:
				A.add(body, _box_cached(Vector3(br * 0.18, br * 2.6, bl * 0.26)), m_dark, Vector3(0, 0, bl * 0.31), Vector3(0, 0, fi * 60.0), Vector3.ONE, false)
		"sniper", "sniper_ap":
			var m_tip := A.chrome() if caliber == "sniper_ap" else m_copper
			A.add(body, A.cyl(br * 0.86, bl * 0.58, br, 10), m_steel, Vector3(0, 0, 0.03 * bl), Vector3(90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(0.004, bl * 0.44, br * 0.86, 10), m_tip, Vector3(0, 0, -bl * 0.47), Vector3(-90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(br * 1.05, bl * 0.08, br * 1.05, 10), m_brass, Vector3(0, 0, bl * 0.18), Vector3(90, 0, 0), Vector3.ONE, false)
		"coil":
			A.add(body, A.cyl(br * 0.64, bl * 0.66, br * 0.70, 10), m_steel, Vector3(0, 0, 0.04 * bl), Vector3(90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(0.004, bl * 0.38, br * 0.64, 10), m_tung, Vector3(0, 0, -bl * 0.48), Vector3(-90, 0, 0), Vector3.ONE, false)
			for bz in [-bl * 0.06, bl * 0.08]:
				A.add(body, A.cyl(br * 0.96, bl * 0.052, br * 0.96, 10), m_copper, Vector3(0, 0, bz), Vector3(90, 0, 0), Vector3.ONE, false)
			for fi in 2:
				A.add(body, _box_cached(Vector3(br * 0.18, br * 2.4, bl * 0.26)), m_dark, Vector3(0, 0, bl * 0.28), Vector3(0, 0, fi * 90.0), Vector3.ONE, false)
		"cannon":
			var m_olive := A.paint(Color(0.28, 0.32, 0.22), 0.45, 0.45, {"panel_scale": 0.0, "wear": 0.25})
			A.add(body, A.cyl(br * 0.92, bl * 0.56, br, 12), m_olive, Vector3(0, 0, 0.02 * bl), Vector3(90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(br * 0.24, bl * 0.36, br * 0.92, 12), m_dark, Vector3(0, 0, -bl * 0.44), Vector3(-90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(0.008, bl * 0.24, br * 0.16, 8), m_brass, Vector3(0, 0, -bl * 0.72), Vector3(-90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(br * 1.08, bl * 0.09, br * 1.08, 12), m_copper, Vector3(0, 0, bl * 0.16), Vector3(90, 0, 0), Vector3.ONE, false)
			for fi in 4:
				A.add(body, _box_cached(Vector3(br * 0.16, br * 2.0, bl * 0.28)), m_steel, Vector3(0, 0, bl * 0.28), Vector3(0, 0, fi * 90.0), Vector3.ONE, false)
		"ac30":
			var m_he := A.paint(Color(0.84, 0.26, 0.12), 0.35, 0.40, {"panel_scale": 0.0})
			A.add(body, A.cyl(br * 0.92, bl * 0.58, br, 10), m_steel, Vector3(0, 0, 0.02 * bl), Vector3(90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(0.005, bl * 0.44, br * 0.92, 10), m_he, Vector3(0, 0, -bl * 0.49), Vector3(-90, 0, 0), Vector3.ONE, false)
			for bz in [bl * 0.08, bl * 0.20]:
				A.add(body, A.cyl(br * 1.07, bl * 0.055, br * 1.07, 10), m_copper, Vector3(0, 0, bz), Vector3(90, 0, 0), Vector3.ONE, false)
		"slug":
			A.add(body, A.cyl(br * 0.86, bl * 0.58, br, 10), A.chrome(), Vector3(0, 0, -bl * 0.10), Vector3(-90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(br * 1.04, bl * 0.32, br * 0.95, 10), m_brass, Vector3(0, 0, bl * 0.28), Vector3(90, 0, 0), Vector3.ONE, false)
		"pellet":
			A.add(body, A.cyl(0.004, bl * 0.56, br, 8), A.chrome(), Vector3(0, 0, -bl * 0.26), Vector3(-90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(br * 0.74, bl * 0.44, br * 0.74, 8), m_copper, Vector3(0, 0, bl * 0.18), Vector3(90, 0, 0), Vector3.ONE, false)
			for fi in 2:
				A.add(body, _box_cached(Vector3(br * 0.18, br * 1.9, bl * 0.34)), m_steel, Vector3(0, 0, bl * 0.26), Vector3(0, 0, fi * 90.0), Vector3.ONE, false)
		_:
			A.add(body, A.cyl(br * 0.88, bl * 0.56, br, 8), m_steel, Vector3(0, 0, 0.04 * bl), Vector3(90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(0.004, bl * 0.48, br * 0.88, 8), m_copper, Vector3(0, 0, -bl * 0.48), Vector3(-90, 0, 0), Vector3.ONE, false)
			A.add(body, A.cyl(br * 1.07, bl * 0.085, br * 1.07, 8), m_brass, Vector3(0, 0, bl * 0.17), Vector3(90, 0, 0), Vector3.ONE, false)
	MechScript._batch_visual(body)
	# 与子弹口径/弹长严密对齐的双交叉窄带曳光尾迹
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
	p.look_at(pos + vel, Vector3.UP)
	return p


## 子弹网格按尺寸缓存：每发子弹都新建网格资源很贵（v0.6 机甲小队同时开火时尤其明显）
var _bullet_meshes := {}
func _box_cached(sz: Vector3) -> BoxMesh:
	var k := "b%.3f|%.3f|%.3f" % [sz.x, sz.y, sz.z]
	if not _bullet_meshes.has(k):
		var bm := BoxMesh.new()
		bm.size = sz
		_bullet_meshes[k] = bm
	return _bullet_meshes[k]


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


## 3D 实体黄铜/红壳弹壳粒子网格（抛壳时旋转弹跳）
func _casing_mesh(heavy := false, red_shell := false) -> CylinderMesh:
	var k := "cas_%s_%s" % [heavy, red_shell]
	if not _bullet_meshes.has(k):
		var cm := CylinderMesh.new()
		cm.top_radius = 0.045 if heavy else 0.028
		cm.bottom_radius = 0.048 if heavy else 0.03
		cm.height = 0.22 if heavy else 0.14
		cm.radial_segments = 8
		cm.rings = 1
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.76, 0.16, 0.11) if red_shell else Color(0.95, 0.74, 0.26)
		m.metallic = 0.35 if red_shell else 0.92
		m.roughness = 0.42 if red_shell else 0.22
		m.emission_enabled = true
		m.emission = Color(0.45, 0.12, 0.05) if red_shell else Color(0.55, 0.38, 0.1)
		m.emission_energy_multiplier = 0.45
		cm.material = m
		_bullet_meshes[k] = cm
	return _bullet_meshes[k]


## 3D 实体碎屑网格（装甲碎片 / 混凝土碎块 / 虫族甲壳残片）
func _debris_mesh(kind := "metal") -> PrismMesh:
	var k := "deb_" + kind
	if not _bullet_meshes.has(k):
		var pm := PrismMesh.new()
		pm.size = Vector3(0.14, 0.18, 0.08) if kind != "rock" else Vector3(0.18, 0.16, 0.14)
		pm.left_to_right = 0.32
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		if kind == "metal":
			m.albedo_color = Color(0.52, 0.54, 0.58)
			m.metallic = 0.85
			m.roughness = 0.28
		elif kind == "chitin":
			m.albedo_color = Color(0.32, 0.35, 0.22)
			m.metallic = 0.25
			m.roughness = 0.32
			m.clearcoat_enabled = true
			m.clearcoat = 0.8
		else:
			m.albedo_color = Color(0.56, 0.52, 0.46)
			m.metallic = 0.05
			m.roughness = 0.88
		pm.material = m
		_bullet_meshes[k] = pm
	return _bullet_meshes[k]


## 3D 实体脱壳穿甲弹铝合金弹托瓣（APFSDS 离膛瞬间向四周剥离翻滚抛飞）
func _sabot_petal_mesh() -> BoxMesh:
	var k := "sabot_petal"
	if not _bullet_meshes.has(k):
		var bm := BoxMesh.new()
		bm.size = Vector3(0.055, 0.042, 0.19)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.58, 0.60, 0.63)
		m.metallic = 0.88
		m.roughness = 0.30
		bm.material = m
		_bullet_meshes[k] = bm
	return _bullet_meshes[k]


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
varying float t;
void vertex() { t = clamp(UV.y, 0.0, 1.0); }
void fragment() {
	float fade = pow(1.0 - t, 1.85);
	float core_rib = smoothstep(0.5, 0.08, abs(UV.x - 0.5));
	float hot = smoothstep(0.28, 0.0, t) * smoothstep(0.32, 0.0, abs(UV.x - 0.5));
	vec3 smoke = mix(vec3(0.86, 0.80, 0.70), vec3(0.60, 0.59, 0.57), smoothstep(0.0, 0.35, t));
	ALBEDO = mix(smoke, mix(col.rgb, vec3(1.0, 0.94, 0.78), hot * 0.78), (1.0 - t) * 0.45);
	ALPHA = fade * core_rib * 0.52;
}
"""
var _tracer_cache := {}
func _tracer_mat(c: Color) -> ShaderMaterial:
	var k := c.to_html()
	if not _tracer_cache.has(k):
		var sh := Shader.new()
		sh.code = TRACER_SHADER
		var mm := ShaderMaterial.new()
		mm.shader = sh
		mm.set_shader_parameter("col", c)
		_tracer_cache[k] = mm
	return _tracer_cache[k]


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
			var life_l: float = GameData.weapon_range_m(m) / maxf(spd_l, 20.0)
			proj = _tracer(origin, dir * spd_l, dmg, life_l, Color(0.76, 0.74, 0.70), 0.14 if is_rail else 0.10, 0.095 if is_rail else 0.072, "apfsds" if is_rail else "coil")
		"sniper":
			var spd_s: float = float(m.get("speed", 145.0))
			var life_s: float = GameData.weapon_range_m(m) / maxf(spd_s, 30.0)
			var cal_s := "sniper_ap" if dmg >= 100.0 else "sniper"
			proj = _tracer(origin, dir * spd_s, dmg, life_s, Color(0.84, 0.78, 0.68), 0.12, 0.065, cal_s)
		"flamer":
			var spd_f: float = float(m.get("speed", 16.0))
			var life_f: float = GameData.weapon_range_m(m) / maxf(spd_f, 8.0)
			var p = _proj(origin, dir * spd_f * randf_range(0.86, 1.12), dmg, life_f, 1 | 4 | 16, Color(0.86, 0.42, 0.16), 0.34, false, "flamer")
			p.source = mech
			p.pierce = true
			p.grow = 0.0
			p.hit_sfx = "-"
			A.emitter(p, Vector3(0, 0, 0.16), {"amount": 8, "life": 0.34, "size": 0.42, "tex": A.smoke_tex(), "additive": false, "spread": 55.0, "vmin": 0.2, "vmax": 0.8,
				"gravity": Vector3(0, 1.4, 0), "c0": Color(0.16, 0.14, 0.13, 0.55), "c1": Color(0.22, 0.20, 0.18, 0.0), "grow0": 0.65, "grow1": 1.65})
			proj = p
		"shotgun":
			var speed: float = float(m.get("speed", 40.0))
			var life: float = GameData.weapon_range_m(m) / speed
			var pellets: int = int(m.get("pellets", 7))
			if dmg >= 55.0:
				proj = _tracer(origin, dir * speed, dmg, life, Color(0.82, 0.76, 0.68), 0.19, 0.11, "cannon")
			elif pellets == 1:
				proj = _tracer(origin, dir * speed * randf_range(0.96, 1.04), dmg, life, Color(0.80, 0.76, 0.70), 0.15, 0.085, "slug")
			else:
				proj = _tracer(origin, dir * speed * randf_range(0.9, 1.1), dmg, life, Color(0.78, 0.74, 0.68), 0.095, 0.052, "pellet")
		_:
			var speed: float = float(m.get("speed", 40.0))
			var life: float = GameData.weapon_range_m(m) / speed
			if dmg >= 20.0:
				proj = _tracer(origin, dir * speed, dmg, life, Color(0.80, 0.75, 0.68), 0.16, 0.09, "ac30")
			else:
				proj = _tracer(origin, dir * speed, dmg, life, Color(0.78, 0.75, 0.70), 0.12, 0.065, "mg")
	if proj != null:
		proj.ap = ap


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
		var p = _proj(origin, v, m.dmg, 3.0, 1 | 4 | 16, Color(0.82, 0.52, 0.28), 0.28, false, m_kind)
		p.homing = true
		p.aoe = 3.2
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
	var p = _tracer(origin, dir * spd, 0.0, clampf(span / spd, 0.04, 0.6), Color(0.76, 0.74, 0.70), 0.14 if is_rail else 0.10, 0.095 if is_rail else 0.072, "apfsds" if is_rail else "coil")
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
		(n as Light3D).light_volumetric_fog_energy = 0.0


## 短暂的点光源闪烁（炮口火光、爆炸、道具闪光）——全部走这个池，不再每发子弹 new 一盏灯
const LIGHT_POOL_MAX := 10
var _light_pool: Array = []
func _flash_light(p: Vector3, c: Color, energy: float, rng_m: float, dur := 0.08) -> void:
	var l: OmniLight3D = null
	for x in _light_pool:
		if not x.visible:
			l = x
			break
	if l == null:
		if _light_pool.size() >= LIGHT_POOL_MAX:
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


func explode(p: Vector3, radius: float, dmg: float, sfx := "explosion") -> void:
	for b in get_tree().get_nodes_in_group("bugs") + get_tree().get_nodes_in_group("nests") + get_tree().get_nodes_in_group("rovers"):
		if is_instance_valid(b) and b.global_position.distance_to(p) < radius + 0.8:
			b.take_damage(dmg)
	explode_fx(p, radius, Color(1.0, 0.55, 0.2))
	Audio.play_sfx(sfx, p + Vector3(0, 1.0, 0))
	shake = max(shake, 0.25)


func explode_fx(p: Vector3, radius: float, c: Color) -> void:
	if coop != null: coop.emit_effect("explosion", [p, radius, c])
	# 3D 膨胀爆轰球壳 + 快速闪光（不遮挡体积火球与黑烟）
	var dome := Node3D.new()
	fx.add_child(dome)
	dome.global_position = p + Vector3(0, 0.35, 0)
	dome.scale = Vector3.ONE * 0.25
	var dm_core := A.add(dome, A.sphere(radius * 0.36, -1, 14), A.emit(Color(1.0, 0.90, 0.68), 6.5), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	var dm_shell := A.add(dome, A.sphere(radius * 0.85, -1, 18), _mach_cone_mat(c.lightened(0.15)), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.55, 1.0), false)
	var dtw := dome.create_tween()
	dtw.tween_property(dome, "scale", Vector3(1.38, 0.95, 1.38), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	dtw.parallel().tween_property(dm_core, "scale", Vector3.ONE * 0.04, 0.15).set_ease(Tween.EASE_IN)
	dtw.parallel().tween_property(dm_shell, "scale", Vector3(1.45, 0.10, 1.45), 0.18)
	dtw.tween_callback(dome.queue_free)
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
	A.burst(fx, p, {"amount": n, "life": 0.3, "size": 0.13, "vmin": 3.5, "vmax": 9.5, "gravity": Vector3(0, -12, 0), "damp": 2.0,
		"c0": c.lightened(0.55), "c1": Color(c.r, c.g * 0.5, 0.0, 0.0), "grow0": 1.0, "grow1": 0.2})
	A.burst(fx, p, {"amount": maxi(3, n / 3), "life": 0.42, "mesh": _debris_mesh("metal"), "additive": false, "vmin": 2.5, "vmax": 6.8,
		"gravity": Vector3(0, -19, 0), "damp": 0.8, "smin": 0.45, "smax": 0.9, "c0": c.lightened(0.35), "c1": Color(0.2, 0.2, 0.22, 0.0), "grow0": 1.0, "grow1": 0.5})


func muzzle_flash(p: Vector3, c: Color, dir := Vector3.ZERO, weapon := "", dmg := 10.0) -> void:
	if coop != null: coop.emit_effect("muzzle", [p, c, dir, weapon, dmg])
	if not _fx_in_range(p, 95.0):
		return
	var flash_c := Color(1.0, 0.76, 0.42)
	_flash_light(p, flash_c, 2.2, 4.8, 0.045)
	if dir == Vector3.ZERO:
		return
	var is_sabot := weapon in ["laser", "railgun"]
	var heavy := weapon in ["shotgun", "cannon", "railgun", "sniper", "mortar", "grenade", "flak"] or dmg >= 50.0
	# 写实短促膛口燃气火舌（去除霓虹光环）
	if weapon not in ["cryo"]:
		A.burst(fx, p + dir * 0.28, {"amount": 5 if heavy else 3, "life": 0.05, "size": 0.48 if heavy else 0.34, "dir": dir, "spread": 14.0, "vmin": 7.0, "vmax": 14.0,
			"gravity": Vector3.ZERO, "damp": 32.0, "c0": Color(1.0, 0.88, 0.62), "c1": Color(0.95, 0.42, 0.10, 0.0), "grow0": 0.9, "grow1": 0.35})
	# 写实轻薄发射药硝烟 / 高压冷气烟丝（随口径缩放，明度贴合环境光避免发白）
	A.burst(fx, p + dir * 0.38, {"amount": 3 if heavy else 1, "life": 0.52 if heavy else 0.32, "size": 0.46 if heavy else 0.25, "tex": A.dust_tex(), "additive": false, "dir": dir, "spread": 22.0,
		"vmin": 1.6 if heavy else 1.2, "vmax": 3.8 if heavy else 2.5, "gravity": Vector3(0, 0.65, 0), "damp": 3.8,
		"c0": Color(0.55, 0.53, 0.50, 0.0), "cmid": Color(0.48, 0.46, 0.43, 0.24 if heavy else 0.16), "cmid_pos": 0.16, "c1": Color(0.38, 0.36, 0.34, 0.0), "grow0": 0.4, "grow1": 1.45, "soft_depth": 0.20})
	if weapon in ["flamer", "cryo"]:
		return
	var side := dir.cross(Vector3.UP).normalized()
	if is_sabot:
		# 电磁轨道炮 / 线圈步枪：膛口抛离三瓣铝合金脱壳弹托瓣（APFSDS Sabot Petals）向两侧前方翻滚散落
		A.burst(fx, p + dir * 0.55, {"amount": 3, "life": 0.68, "mesh": _sabot_petal_mesh(), "additive": false,
			"dir": (dir * 0.65 + Vector3(0, 0.25, 0)).normalized(), "spread": 42.0, "vmin": 6.5, "vmax": 11.5, "gravity": Vector3(0, -22, 0), "damp": 0.8,
			"smin": 0.85, "smax": 1.2, "c0": Color(1, 1, 1, 1), "c1": Color(0.85, 0.85, 0.85, 0.95), "grow0": 1.0, "grow1": 1.0})
	else:
		# 3D 实体黄铜/红塑霰弹弹壳从抛壳窗翻滚弹出
		A.burst(fx, p - dir * 0.55, {"amount": 2 if heavy else 1, "life": 0.82, "mesh": _casing_mesh(heavy, weapon == "shotgun" and dmg < 50.0), "additive": false,
			"dir": (side + Vector3(0, 0.95, 0)).normalized(), "spread": 18.0, "vmin": 3.4, "vmax": 5.6, "gravity": Vector3(0, -21, 0), "damp": 0.4,
			"smin": 0.9, "smax": 1.15, "c0": Color(1, 1, 1, 1), "c1": Color(0.85, 0.85, 0.85, 0.95), "grow0": 1.0, "grow1": 1.0})


## 命中：打在单位上 → 金属火星 + 3D 实体甲壳/装甲碎块；打在墙/地上 → 火花 + 尘烟 + 3D 混凝土碎石块 + 实体跳弹钢芯
func impact(p: Vector3, n: Vector3, c: Color, unit: bool, vel: Vector3, organic := false) -> void:
	if coop != null: coop.emit_effect("impact", [p, n, c, unit, vel, organic])
	if not _fx_in_range(p, 95.0):
		return
	var nrm := n if n != Vector3.ZERO else Vector3.UP
	var refl := vel.normalized().bounce(nrm) if vel.length_squared() > 0.01 else Vector3.UP
	if not organic and randf() < 0.45:
		# 实体变形弹芯跳弹飞散（取代纯发光环）
		A.burst(fx, p, {"amount": 2, "life": 0.36, "mesh": _debris_mesh("metal"), "additive": false, "dir": refl, "spread": 18.0, "vmin": 11.0, "vmax": 18.0,
			"gravity": Vector3(0, -18, 0), "smin": 0.45, "smax": 0.75, "c0": Color(0.95, 0.82, 0.58), "c1": Color(0.45, 0.44, 0.42, 0.9), "grow0": 1.0, "grow1": 0.8})
	# 硬质金属撞击火星
	A.burst(fx, p, {"amount": 9, "life": 0.24, "size": 0.09, "dir": (refl + nrm).normalized(), "spread": 40.0, "vmin": 5.5, "vmax": 12.0, "gravity": Vector3(0, -15, 0), "damp": 2.2,
		"c0": Color(1.0, 0.88, 0.58), "c1": Color(0.95, 0.42, 0.08, 0.0), "grow0": 1.0, "grow1": 0.2})
	if unit:
		# 3D 实体机械装甲 / 焦黑机械残片与机油雾（全部敌机与机械虫均走硬工业受击反馈）
		var d_kind := "metal"
		var c_start := Color(0.34, 0.31, 0.27) if organic else Color(0.68, 0.72, 0.78)
		A.burst(fx, p, {"amount": 8, "life": 0.52, "mesh": _debris_mesh(d_kind), "additive": false, "dir": nrm, "spread": 65.0, "vmin": 3.2, "vmax": 7.6, "gravity": Vector3(0, -19, 0),
			"smin": 0.65, "smax": 1.25, "c0": c_start, "c1": Color(0.14, 0.13, 0.12, 0.0), "grow0": 1.0, "grow1": 0.55})
		if organic:
			if randf() < 0.4:
				A.burst(fx, p, {"amount": 2, "life": 0.34, "mesh": _debris_mesh("metal"), "additive": false, "dir": refl, "spread": 22.0, "vmin": 9.0, "vmax": 15.0,
					"gravity": Vector3(0, -18, 0), "smin": 0.45, "smax": 0.75, "c0": Color(0.95, 0.78, 0.48), "c1": Color(0.35, 0.34, 0.32, 0.9), "grow0": 1.0, "grow1": 0.8})
			A.burst(fx, p, {"amount": 3, "life": 0.42, "size": 0.42, "tex": A.smoke_tex(), "additive": false, "dir": nrm, "spread": 50.0, "vmin": 1.2, "vmax": 3.0,
				"gravity": Vector3(0, 0.4, 0), "damp": 3.5, "c0": Color(0.14, 0.13, 0.12, 0.0), "cmid": Color(0.16, 0.15, 0.14, 0.48), "cmid_pos": 0.18, "c1": Color(0.20, 0.18, 0.17, 0.0), "grow0": 0.45, "grow1": 1.35, "soft_depth": 0.22})
	else:
		var dt := ground_dust_tint()
		A.burst(fx, p + nrm * 0.16, {"amount": 4, "life": 0.65, "size": 0.58, "tex": A.dust_tex(), "additive": false, "dir": nrm, "spread": 48.0, "vmin": 0.9, "vmax": 2.4,
			"gravity": Vector3(0, 0.2, 0), "damp": 3.5, "c0": Color(dt.r, dt.g, dt.b, 0.0), "cmid": Color(dt.r, dt.g, dt.b, 0.46), "cmid_pos": 0.15, "c1": Color(dt.r * 0.9, dt.g * 0.9, dt.b * 0.9, 0.0), "grow0": 0.4, "grow1": 1.55, "soft_depth": 0.22})
		# 3D 实体混凝土/岩石碎块蹦跳
		A.burst(fx, p, {"amount": 6, "life": 0.58, "mesh": _debris_mesh("rock"), "additive": false, "dir": nrm, "spread": 55.0, "vmin": 2.5, "vmax": 6.2, "gravity": Vector3(0, -21, 0),
			"smin": 0.6, "smax": 1.2, "c0": Color(0.62, 0.58, 0.52), "c1": Color(0.4, 0.38, 0.35, 0.85), "grow0": 1.0, "grow1": 0.8})


func on_player_hurt(amount: float) -> void:
	shake = max(shake, clamp(amount / 40.0, 0.08, 0.4))
	hud.hurt()


func on_bug_killed(b) -> void:
	var p: Vector3 = b.global_position
	# 流浪者打死的虫不算玩家的击杀（不计数、不广播）；队友的击杀算进小队战绩
	var by = b.get("aggressor")
	if not (is_instance_valid(by) and by.is_in_group("rovers")):
		kills += 1
		_event("enemy_killed", [str(b.kind), p])
	# 机械虫：油污 + 金属碎片（不是血）
	var sc: float = b.data.scale
	var oil := A.ground_vfx(world, A.grime_stain_tex(), Color(0.14, 0.13, 0.12, 0.82), 2.5 * sc, Vector3(p.x, 0.091, p.z), false, 0.44, false, 2)
	oil.rotation.y = rng.randf() * TAU
	_kill_decal(oil)
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



func _unhandled_input(event: InputEvent) -> void:
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


func _load_map() -> void:
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
		var pts: PackedVector2Array = r.pts
		curves.append({"pts": pts, "d": pts, "w": float(r.w), "dirt": bool(r.dirt), "kind": str(r.kind), "bridge": bool(r.bridge), "caps": r.get("caps", [false, false])})
		_rg.add_poly(pts, float(r.w) * 0.5, curves.size() - 1)
		for k in pts.size() - 1:
			acc += pts[k].distance_to(pts[k + 1])
		_road_len.append(acc)
	rivers.clear()
	_wg = WC.SegGrid.new()
	_wg.cell = 16.0
	_wg.reach = 16.0
	river_pts = PackedVector2Array()
	river_w = 0.0
	river_dry = true
	for r: Dictionary in layout.rivers:
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


## 当前所在地名：最近的地图标注
func district_at(p: Vector3) -> String:
	var best := ""
	var bd := INF
	for l: Array in map_labels:
		var d := Vector2(p.x, p.z).distance_squared_to(Vector2(l[1], l[2]))
		if d < bd:
			bd = d
			best = l[0]
	return best


## 是否在路面上（pad > 0 外扩，< 0 内缩）
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
	_build_roads()
	_build_river()
	_build_lakes()
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
		var off := maxf(1.2, float(cv.w) * 0.5 - WALK_W - 1.15)
		var q := d[j] + nrm * sd * off
		if not in_bounds_xz(q, 10.0):
			continue
		if _rg.edge_dist(q, i) < 4.5 or _on_bridge(q, 5.0) or in_river(q, 4.5):
			continue
		var on_rail := false
		for rl: PackedVector2Array in rail_polys:
			if WC.poly_dist(rl, q) < 4.5:
				on_rail = true
				break
		if on_rail:
			continue
		var p := Vector3(q.x, 0, q.y)
		if _blocked(p, 3.6, false):
			continue
		var yaw := rad_to_deg(atan2(tg.x, tg.y)) + (0.0 if sd > 0.0 else 180.0) + rng.randf_range(-4.0, 4.0)
		return [p, yaw]
	return []


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
		if _rg.edge_dist(q, i) < 4.0 or _on_bridge(q, 4.0) or in_river(q, 4.0):
			continue
		var p := Vector3(q.x, 0, q.y)
		if not _blocked(p, 2.5, false):
			return p
	return Vector3.INF


func _drop_point() -> Vector3:
	rng.seed = _map_seed(12)
	# 空投点：沿不规则战区周界内侧（距边界 14~56 米）较安全的街区生成多个分散候选出生点，每局随机挑选一处
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
	var pick_rng := RandomNumberGenerator.new()
	if Net.active(): pick_rng.seed = Net.world_seed + _map_seed(98)
	else: pick_rng.randomize()
	return drop_points[pick_rng.randi() % drop_points.size()]


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


func _build_map_texture() -> void:
	var img := Image.create(MAP_PX, MAP_PX, false, Image.FORMAT_RGBA8)
	var k := MAP_PX / (HALF * 2.0)
	# 区块底色：2 米栅格放大，对远离道路/建筑的硬质区块做荒野过渡，并叠加地貌微理与等高线
	var n: int = layout.r_n
	var pad := int(roundf(-(layout.r_o.x + HALF) / WC.RAST))
	var m := int(HALF * 2.0 / WC.RAST)
	var bldg_rects: Array = []
	for e: Array in bldg_polys + backdrop_bldg_polys:
		bldg_rects.append(WC._poly_rect(e[0]).grow(22.0))
	for pp: Vector3 in poi_centers:
		bldg_rects.append(Rect2(pp.x - 28.0, pp.z - 28.0, 56.0, 56.0))
	var base := Image.create(m, m, false, Image.FORMAT_RGBA8)
	for y in m:
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
		_img_poly_line(img, r.pts, r.w + 4.0, Color(0.22, 0.2, 0.17) if not r.dry else Color(0.33, 0.29, 0.23))
	for l: Vector3 in lakes:
		_img_poly(img, WC.lake_poly(l, 56, 2.4), Color(0.22, 0.2, 0.17))
	for r: Dictionary in rivers:
		_img_poly_line(img, r.pts, r.w, Color(0.17, 0.3, 0.37) if not r.dry else Color(0.43, 0.38, 0.30))
	for l: Vector3 in lakes:
		_img_poly(img, WC.lake_poly(l, 56, 0.0), Color(0.17, 0.3, 0.37))
	for r: Dictionary in rivers:
		if not r.dry and r.w >= 10.0:
			_img_poly_line(img, r.pts, r.w * 0.52, Color(0.14, 0.25, 0.32))
	for l: Vector3 in lakes:
		if l.z >= 10.0:
			_img_poly(img, WC.lake_poly(l, 48, -l.z * 0.36), Color(0.14, 0.25, 0.32))
	# 道路：分层绘制（土路护肩 → 土路路面 → 铺装路深色外沿 → 铺装路缘 → 支路沥青 → 主干道沥青 → 主干道分道虚线），交叉口自然融接
	for cv: Dictionary in curves:
		if cv.dirt:
			_img_poly_line(img, cv.pts, cv.w + 1.0, Color(0.32, 0.27, 0.20))
	for cv: Dictionary in curves:
		if cv.dirt:
			_img_poly_line(img, cv.pts, maxf(1.6, cv.w - 0.8), Color(0.47, 0.41, 0.31))
	for cv: Dictionary in curves:
		if not cv.dirt:
			_img_poly_line(img, cv.pts, cv.w + 1.0, Color(0.16, 0.16, 0.18))
	for cv: Dictionary in curves:
		if not cv.dirt:
			_img_poly_line(img, cv.pts, maxf(2.0, cv.w - 0.4), Color(0.52, 0.50, 0.46))
	for cv: Dictionary in curves:
		if not cv.dirt and cv.w < 11.0:
			_img_poly_line(img, cv.pts, maxf(1.5, cv.w - 2.4), Color(0.34, 0.33, 0.31))
	for cv: Dictionary in curves:
		if not cv.dirt and cv.w >= 11.0:
			_img_poly_line(img, cv.pts, maxf(1.5, cv.w - 2.4), Color(0.38, 0.37, 0.35))
	for cv: Dictionary in curves:
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
		_img_flat_seg(img, b[0], b[1], b[2] + 2.2, Color(0.11, 0.11, 0.13))
		_img_flat_seg(img, b[0], b[1], b[2] + 0.6, Color(0.58, 0.56, 0.52))
		_img_flat_seg(img, b[0], b[1], maxf(2.0, b[2] - 1.6), Color(0.41, 0.40, 0.38))
	# 铁轨
	for l: Array in rail_lines:
		_img_flat_seg(img, l[0], l[1], 3.0, Color(0.2, 0.18, 0.17))
	for l: Array in rail_lines:
		_img_line(img, l[0], l[1], 0.9, Color(0.52, 0.47, 0.42), 0.4)
	# 山脊与断崖岩带
	for p: Vector2 in ridge_pts:
		_img_disc(img, p, 2.8, Color(0.18, 0.15, 0.12))
		_img_disc(img, p + Vector2(-0.6, -0.6), 1.7, Color(0.42, 0.37, 0.3))
	# 重点遗迹院落围墙（只画院落墙段与中型掩体，过滤零散小树/石块噪点）
	for r: Rect2 in blocks:
		var ar := r.get_area()
		if ar >= 2.2 and ar <= 10.0 and (r.size.x >= 2.5 or r.size.y >= 2.5):
			img.fill_rect(Rect2i(int((r.position.x + HALF) * k), int((r.position.y + HALF) * k), maxi(2, int(r.size.x * k)), maxi(2, int(r.size.y * k))), Color(0.22, 0.21, 0.20))
	# 建筑：投影 + 轮廓描边 + 屋顶与内层女儿墙（含外围邻接城区建筑，斜放的楼按真实朝向画）
	var all_bldgs: Array = backdrop_bldg_polys + bldg_polys
	var sh_off := PackedVector2Array()
	for e: Array in all_bldgs:
		var p0: PackedVector2Array = e[0]
		sh_off.resize(p0.size())
		for i in p0.size():
			sh_off[i] = p0[i] + Vector2(1.1, 1.2)
		_img_poly(img, sh_off, Color(0.06, 0.06, 0.07))
	for e: Array in all_bldgs:
		_img_poly(img, e[0], Color(0.10, 0.10, 0.11))
	for e: Array in all_bldgs:
		_img_poly(img, WC.inset(e[0], 0.85), Color(0.58, 0.56, 0.52))
		var inner := WC.inset(e[0], 2.2)
		if inner.size() >= 3:
			_img_poly(img, inner, Color(0.51, 0.49, 0.45))
	# 不规则战区周界以外：地表战区保留压暗降饱和的城市群侦察底图与斜纹封控阴影；地下竖井涂成深渊黑曜岩体
	if zone_poly.size() >= 3:
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
const ZONE_GROUND := {"D": Color(1, 0, 0, 0.25), "R": Color(0.45, 0.35, 0, 0), "I": Color(0.15, 0, 0, 1), "H": Color(0.35, 0, 0, 0.85),
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
			# 硬质铺装/工业碎石只紧贴道路、建筑群与据点展开，避免荒原或地底空旷处出现大块多边形色斑
			if zt in ["D", "I", "H", "Y", "M", "C"] and not on_road(q, 16.0):
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
	img.resize(55, 55, Image.INTERPOLATE_BILINEAR)
	img.resize(165, 165, Image.INTERPOLATE_CUBIC)
	img.resize(360, 360, Image.INTERPOLATE_CUBIC)
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
		var br: Rect2 = WC._poly_rect(pts).grow(3.8)
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
			var r_sec: float = clampf(0.5 + border_dist(q) / 24.0, 0.0, 1.0)
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
						if bd < 3.6:
							bao = maxf(bao, clampf(1.0 - bd / 3.6, 0.0, 1.0))
			s_img.set_pixel(x, y, Color(r_sec, rv, bao, 1.0))
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
const WALK_W := 1.15          ## 人行道宽（含路沿石）
const CURB_W := 0.22          ## 路沿石宽（人行道靠车道一侧）
const WALK_CHUNK := 16
const _CUT_CELL := 24.0


func _chunks(d: PackedVector2Array) -> Array:
	var n := d.size()
	if n <= WALK_CHUNK + 1:
		return [d]
	var out: Array = []
	var s := 0
	while s < n - 1:
		var e := mini(n, s + WALK_CHUNK + 1)
		out.append(d.slice(s, e))
		if e >= n:
			break
		s = e - 3
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


## 折线向两侧各偏移 r 的条带（圆角拐弯、平头端），只取外轮廓
func _offset_line(d: PackedVector2Array, r: float) -> Array:
	if d.size() < 2 or r <= 0.05:
		return []
	return _outers(Geometry2D.offset_polyline(d, r, Geometry2D.JOIN_ROUND, Geometry2D.END_BUTT))


## Clipper 结果里去掉洞（洞会被包含在别的结果多边形里）
func _outers(res: Array) -> Array:
	if res.size() <= 1:
		return res
	var out: Array = []
	for i in res.size():
		var hole := false
		var pi: PackedVector2Array = res[i]
		if pi.size() < 3:
			continue
		for j in res.size():
			if j != i and (res[j] as PackedVector2Array).size() >= 3 and Geometry2D.is_point_in_polygon(pi[0], res[j]):
				hole = true
				break
		if not hole:
			out.append(pi)
	return out


## 断头路外的半圆环（内半径 r0、外半径 r1），朝 t 方向
func _half_ring(p: Vector2, t: Vector2, r0: float, r1: float, seg := 24) -> PackedVector2Array:
	var nn := Vector2(-t.y, t.x)
	var poly := PackedVector2Array()
	for k in seg + 1:
		var a := PI * k / seg
		poly.append(p + (nn * cos(a) + t * sin(a)) * r1)
	for k in range(seg, -1, -1):
		var a := PI * k / seg
		poly.append(p + (nn * cos(a) + t * sin(a)) * r0)
	return poly


func _circle_poly(c: Vector2, r: float, seg := 64) -> PackedVector2Array:
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
	var out := PackedVector2Array()
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var nn := Vector2(-t.y, t.x)
		out.append(pts[i] + nn * off)
	return out


func _cap_polys(d: PackedVector2Array, r: float, caps: Array) -> Array:
	var out: Array = []
	if d.size() < 2:
		return out
	for e in 2:
		if not bool(caps[e]):
			continue
		var p: Vector2 = d[0] if e == 0 else d[d.size() - 1]
		var q: Vector2 = d[1] if e == 0 else d[d.size() - 2]
		var t := (p - q).normalized()
		if t.length_squared() < 1e-6:
			continue
		var nn := Vector2(-t.y, t.x)
		var seg := 24
		var poly := PackedVector2Array()
		for k in seg + 1:
			var a := PI * float(k) / float(seg)
			poly.append(p + (nn * cos(a) + t * sin(a)) * r)
		out.append(poly)
	return out


func _emit_dedup_polys(st: SurfaceTool, polys: Array, y: float, thick := 0.0) -> int:
	var cuts: Array = []
	var cgrid := {}
	var n := 0
	for raw: PackedVector2Array in polys:
		if raw.size() < 3:
			continue
		for piece: PackedVector2Array in _subtract_cuts(raw, cuts, cgrid, []):
			_emit_poly(st, piece, y, thick)
			_add_cut(cuts, cgrid, piece)
			n += 1
	return n


func _build_walks(st_w: SurfaceTool, st_c: SurfaceTool) -> int:
	var lim := Rect2(-EXT_HALF - 12.0, -EXT_HALF - 12.0, EXT_HALF * 2.0 + 24.0, EXT_HALF * 2.0 + 24.0)
	var cuts: Array = []          ## [多边形, 外接矩形]
	var cgrid := {}
	var bands: Array = []         ## [折线段, 半宽, 本段车道切口序号列表]
	var ends: Array = []          ## [端点, 朝外方向, 半宽]
	for cv: Dictionary in curves:
		var d: PackedVector2Array = cv.d
		if d.size() < 2:
			continue
		var hw: float = float(cv.w) * 0.5
		var cw: float = hw if cv.dirt else hw - WALK_W
		for ch: PackedVector2Array in _chunks(d):
			if not lim.intersects(WC._poly_rect(ch).grow(hw)):
				continue
			var own: Array = []
			for poly: PackedVector2Array in _offset_line(_ext_line(ch, 0.05), cw):
				own.append(_add_cut(cuts, cgrid, poly))
			if not cv.dirt:
				bands.append([ch, hw, own])
		if not cv.dirt:
			var caps: Array = cv.get("caps", [false, false])
			for e in 2:
				if bool(caps[e]):
					var p: Vector2 = d[0] if e == 0 else d[d.size() - 1]
					var q: Vector2 = d[1] if e == 0 else d[d.size() - 2]
					if lim.has_point(p):
						ends.append([p, (p - q).normalized(), hw])
	for line: PackedVector2Array in rail_polys:
		for ch: PackedVector2Array in _chunks(line):
			if lim.intersects(WC._poly_rect(ch).grow(3.0)):
				for poly: PackedVector2Array in _offset_line(_ext_line(ch, 0.05), 2.0):
					_add_cut(cuts, cgrid, poly)
	var n := 0
	# 两层：人行道面（0.18 米高）与靠车道一侧的路沿石（0.215 米高）；已发出的多边形记入本层切口，转角与分段重叠处不叠两层
	for layer in [[st_w, 0.0, 0.18, 0.14], [st_c, WALK_W - CURB_W, 0.215, 0.035]]:
		var st: SurfaceTool = layer[0]
		var inset: float = layer[1]
		var lcuts := cuts.duplicate()
		var lcgrid := cgrid.duplicate(true)
		for b: Array in bands:
			var hw: float = b[1]
			for outer: PackedVector2Array in _offset_line(b[0], hw - inset):
				for piece: PackedVector2Array in _subtract_cuts(outer, lcuts, lcgrid, b[2]):
					_emit_poly(st, piece, layer[2], layer[3])
					_add_cut(lcuts, lcgrid, piece)
					n += 1
		for e: Array in ends:
			var hw: float = e[2]
			var ring := _half_ring(e[0], e[1], hw - WALK_W, hw - inset)
			for piece: PackedVector2Array in _subtract_cuts(ring, lcuts, lcgrid, []):
				_emit_poly(st, piece, layer[2], layer[3])
				_add_cut(lcuts, lcgrid, piece)
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


## 多边形顶面（高 y）+ 一圈向下 thick 的侧壁
func _emit_poly(st: SurfaceTool, poly: PackedVector2Array, y: float, thick: float) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	if idx.is_empty():
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


func _build_roads() -> void:
	rng.seed = _map_seed(2)
	var ASPH: ShaderMaterial = A.asphalt(Color(0.26, 0.265, 0.275)).duplicate()
	var ASPH2: ShaderMaterial = A.asphalt(Color(0.29, 0.295, 0.305)).duplicate()
	var ARUT: ShaderMaterial = A.asphalt(Color(0.20, 0.205, 0.215)).duplicate()
	var DIRT: ShaderMaterial = A.gravel_mat(Color(0.42, 0.36, 0.27)).duplicate()
	var RUT: ShaderMaterial = A.gravel_mat(Color(0.30, 0.25, 0.19)).duplicate()
	for m in [ASPH, ASPH2, ARUT, DIRT, RUT]:
		m.set_meta("no_outline", true)
	var WALK := A.concrete(Color(0.49, 0.47, 0.43), true)
	var CURB := A.concrete(Color(0.6, 0.58, 0.53), false)
	var LINE := A.paint(Color(0.82, 0.72, 0.42), 0.0, 0.85, {"wear": 0.65, "dust": 0.35, "panel_scale": 0.0})
	var XWALK := A.paint(Color(0.74, 0.74, 0.71), 0.0, 0.88, {"wear": 0.72, "dust": 0.42, "panel_scale": 0.0})
	var st_a := SurfaceTool.new()
	var st_b := SurfaceTool.new()
	var st_ar := SurfaceTool.new()
	var st_d := SurfaceTool.new()
	var st_r := SurfaceTool.new()
	var st_w := SurfaceTool.new()
	var st_c := SurfaceTool.new()
	for st in [st_a, st_b, st_ar, st_d, st_r, st_w, st_c]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var polys_a: Array = []
	var polys_b: Array = []
	var polys_ar: Array = []
	var polys_d: Array = []
	var polys_r: Array = []
	var dashes: Array = []
	var xwalks: Array = []
	for ci in curves.size():
		var cv: Dictionary = curves[ci]
		var d: PackedVector2Array = cv.d
		var w: float = cv.w
		var caps: Array = cv.get("caps", [false, false])
		if cv.dirt:
			for ch: PackedVector2Array in _chunks(d):
				polys_d.append_array(_offset_line(_ext_line(ch, 0.25), w * 0.5))
			polys_d.append_array(_cap_polys(d, w * 0.5, caps))
			# 土路与铺装路交汇处铺设碎石压实搭接过渡坪，消除土路端头断茬接缝
			for e_idx in [0, d.size() - 1]:
				if d.size() >= 2:
					var ep: Vector2 = d[e_idx]
					var en: Vector2 = d[1] if e_idx == 0 else d[d.size() - 2]
					if _rg.edge_dist(ep, ci) < 2.2:
						var ap_pts := PackedVector2Array([ep.lerp(en, minf(1.0, 2.8 / maxf(0.2, ep.distance_to(en)))), ep])
						polys_b.append_array(_offset_line(ap_pts, w * 0.54))
			for ch: PackedVector2Array in _chunks(d):
				for sd in [-1.3, 1.3]:
					polys_r.append_array(_offset_line(_shift_line(ch, sd), 0.25))
			continue
		# 宽路（主干道）略高一层，路口处压住支路；断头处画圆头（按分段偏移+逐层去重，交叉口/弯道绝不双层闪烁）
		if w >= 10.0:
			for ch: PackedVector2Array in _chunks(d):
				polys_a.append_array(_offset_line(_ext_line(ch, 0.04), w * 0.5))
			polys_a.append_array(_cap_polys(d, w * 0.5, caps))
			for ch: PackedVector2Array in _chunks(d):
				for sd_r: float in [-2.1, 2.1]:
					polys_ar.append_array(_offset_line(_shift_line(ch, sd_r), 0.675))
		else:
			for ch: PackedVector2Array in _chunks(d):
				polys_b.append_array(_offset_line(_ext_line(ch, 0.04), w * 0.5))
			polys_b.append_array(_cap_polys(d, w * 0.5, caps))
		# 道路中线虚线：按精确弧长等距插值，不随机缺段；主干道与次干道（w >= 6.5）统一标线，斑马线与虚线互斥
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
					if absf(p.x) < EXT_HALF - 1.0 and absf(p.y) < EXT_HALF - 1.0 and not in_wet(p, 2.0):
						var ed := _rg.edge_dist(p, ci)
						var do_xw := w >= 8.5 and ed > 3.6 and ed < 6.4 and (next_s - last_xw) > 20.0
						if do_xw:
							var n_stripes := int((w - 2.4) / 1.15)
							var half_span := float(n_stripes - 1) * 0.5 * 1.15
							for si in n_stripes:
								var off := -half_span + float(si) * 1.15
								var xp := p + perp * off
								xwalks.append(Transform3D(Basis(Vector3.UP, atan2(t.x, t.y)).scaled_local(Vector3(0.46, 0.016, 2.4)), Vector3(xp.x, 0.100, xp.y)))
							last_xw = next_s
						elif ed > 1.8:
							dashes.append(Transform3D(Basis(Vector3.UP, atan2(t.x, t.y)).scaled_local(Vector3(0.22, 0.016, 2.2)), Vector3(p.x, 0.100, p.y)))
					next_s += dash_step
				cur_s += seg
	# 人行道（带立体侧壁）+ 浅色路沿石：沿所有路面并集的边缘走，路口转角自动连成一圈，断头路绕成 U 形
	var na := _emit_dedup_polys(st_a, polys_a, 0.079, 0.0)
	var nb := _emit_dedup_polys(st_b, polys_b, 0.072, 0.0)
	var nar := _emit_dedup_polys(st_ar, polys_ar, 0.086, 0.0)
	var nd := _emit_dedup_polys(st_d, polys_d, 0.058, 0.0)
	var nr := _emit_dedup_polys(st_r, polys_r, 0.065, 0.0)
	var nw := _build_walks(st_w, st_c)
	_st_commit(st_a, ASPH, na)
	_st_commit(st_b, ASPH2, nb)
	_st_commit(st_ar, ARUT, nar)
	_st_commit(st_d, DIRT, nd)
	_st_commit(st_r, RUT, nr)
	_st_commit(st_w, WALK, nw)
	_st_commit(st_c, CURB, nw)
	_multimesh(A.bevel_box(Vector3.ONE, 0.0), LINE, dashes, false)
	_multimesh(A.bevel_box(Vector3.ONE, 0.0), XWALK, xwalks, false)
	# 路面油渍（降低密度与对比度，保持路面干净清晰）
	for k in (48 if not curves.is_empty() else 0):
		var p := _road_point(1.5)
		if in_wet(Vector2(p.x, p.z), 4.0):
			continue
		var dd := A.ground_decal(world, A.grime_stain_tex(), Color(0.28, 0.27, 0.26, rng.randf_range(0.20, 0.36)), rng.randf_range(1.6, 3.2), Vector3(p.x, 0.090, p.z))
		dd.rotation.y = rng.randf() * TAU
		dd.scale = Vector3(rng.randf_range(0.8, 1.3), 1.0, rng.randf_range(0.7, 1.2))


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
	for poly: PackedVector2Array in _outers(Geometry2D.offset_polyline(pts, w * 0.5, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)):
		_emit_poly(st, poly, y, 0.0)
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
	var rp: PackedVector2Array = r.pts if r.dry else _river_in_lake_pts(r.pts, rw * 0.5)
	var pts := _dense(rp, 2.0)
	if r.dry:
		# 干河床：三层自然冲积砂砾过渡（外沿风化淤泥砾石带 → 砂砾二级阶地 → 粗砂卵石主河槽）+ 道路过河漫水混凝土桥涵
		var m_outer: ShaderMaterial = A.gravel_mat(Color(0.29, 0.25, 0.20)).duplicate()
		m_outer.set_meta("no_outline", true)
		var mi0 := MeshInstance3D.new()
		mi0.mesh = _strip_mesh(rp, rw + 9.5, 0.008)
		mi0.material_override = m_outer
		mi0.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(mi0)
		var m_bank: ShaderMaterial = A.gravel_mat(Color(0.35, 0.30, 0.24)).duplicate()
		m_bank.set_meta("no_outline", true)
		var mi := MeshInstance3D.new()
		mi.mesh = _strip_mesh(rp, rw + 4.2, 0.020)
		mi.material_override = m_bank
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(mi)
		var m_bed: ShaderMaterial = A.gravel_mat(Color(0.45, 0.40, 0.32)).duplicate()
		m_bed.set_meta("no_outline", true)
		var bed := MeshInstance3D.new()
		bed.mesh = _strip_mesh(rp, maxf(3.0, rw * 0.84), 0.032)
		bed.material_override = m_bed
		bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(bed)
		# 道路跨越干河床处：铺设带泄洪波纹钢涵管与防撞路缘墩的工业漫水混凝土硬化路面，消除干河床与道路十字穿插缝
		var ford_hits: Array = []
		var M_FORD := A.concrete(Color(0.42, 0.40, 0.37), true)
		var M_CULV := A.metal(Color(0.18, 0.19, 0.21))
		for cv: Dictionary in curves:
			var cp: PackedVector2Array = cv.pts
			for ci in cp.size() - 1:
				for ki in rp.size() - 1:
					var hit = Geometry2D.segment_intersects_segment(cp[ci], cp[ci + 1], rp[ki], rp[ki + 1])
					if hit == null or absf(hit.x) > EXT_HALF - 4.0 or absf(hit.y) > EXT_HALF - 4.0:
						continue
					var dup_f := false
					for fh: Vector2 in ford_hits:
						if fh.distance_to(hit) < 16.0:
							dup_f = true
							break
					if dup_f:
						continue
					ford_hits.append(hit)
					var cdir := (cp[ci + 1] - cp[ci]).normalized()
					var rdir := (rp[ki + 1] - rp[ki]).normalized()
					var fspan := (rw + 5.5) / maxf(absf(cdir.cross(rdir)), 0.42)
					var fn := Node3D.new()
					world.add_child(fn)
					fn.position = Vector3(hit.x, 0.0, hit.y)
					fn.rotation.y = atan2(cdir.x, cdir.y)
					var fw := float(cv.w) + 1.2
					A.add(fn, A.bevel_box(Vector3(fw, 0.12, fspan), 0.03), M_FORD, Vector3(0, 0.055, 0), Vector3.ZERO, Vector3.ONE, false)
					for sd_f in [-1.0, 1.0]:
						for b_i in 3:
							var bz_f := (float(b_i) - 1.0) * (fspan * 0.34)
							A.add(fn, A.bevel_box(Vector3(0.32, 0.46, 0.38), 0.03), A.hazard() if b_i == 1 else M_FORD, Vector3(sd_f * (fw * 0.5 - 0.12), 0.24, bz_f))
					for cz_f in [-1.1, 1.1]:
						A.add(fn, A.cyl(0.28, fw + 0.8, 0.28, 12), M_CULV, Vector3(0, 0.12, cz_f), Vector3(0, 0, 90))
		var stones: Array = []
		for i in pts.size():
			if absf(pts[i].x) > EXT_HALF + 4.0 or absf(pts[i].y) > EXT_HALF + 4.0:
				continue
			for k in 3:
				var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
				var p := pts[i] + Vector2(-t.y, t.x) * rng.randf_range(-0.62, 0.62) * rw
				if on_road(p, 1.2):
					continue
				var sc := rng.randf_range(0.15, 0.52)
				stones.append(Transform3D(_rand_basis(30).scaled_local(Vector3(sc * 1.3, sc * 0.5, sc)), Vector3(p.x, sc * 0.1, p.y)))
		_multimesh(A.sphere(0.5, -1, 8), A.concrete(Color(0.46, 0.42, 0.36), false), stones, false)
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
			if hit == null or absf(hit.x) > EXT_HALF + 6.0 or absf(hit.y) > EXT_HALF + 6.0:
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
			if border_dist(m) < -8.0:
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
		if border_dist(p) < -4.0 or absf(p.x) > EXT_HALF - 4.0 or absf(p.y) > EXT_HALF - 4.0 or in_lake(p, 1.0) or zone_at(Vector3(p.x, 0, p.y)) in ["A", "B"]:
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
	var ang := atan2(dir.x, dir.y)
	var root := Node3D.new()
	world.add_child(root)
	root.position = Vector3(hp.x, 0, hp.y)
	root.rotation.y = ang
	# 混凝土主桥面板 + 两端缓坡桥头搭板与沥青斜坡顺接（消除桥头 20cm 垂直硬台阶接缝）+ 双侧马路牙子 + 桥底纵梁与桥墩
	A.add(root, A.bevel_box(Vector3(w + 0.9, 0.34, span + 0.4), 0.06), DECK, Vector3(0, 0.09, 0))
	A.add(root, A.bevel_box(Vector3(maxf(2.0, w - 0.7), 0.05, span + 0.4), 0.01), ASPH, Vector3(0, 0.27, 0), Vector3.ZERO, Vector3.ONE, false)
	for end_s in [-1.0, 1.0]:
		A.add(root, A.bevel_box(Vector3(w + 0.85, 0.18, 2.2), 0.03), DECK, Vector3(0, 0.08, end_s * (span * 0.5 + 0.95)), Vector3(end_s * 5.8, 0, 0), Vector3.ONE, false)
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
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D n_low : filter_linear_mipmap, repeat_enable;
uniform sampler2D n_hi : filter_linear_mipmap, repeat_enable;
uniform sampler2D n_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = wp.xz;
	float t = TIME * 0.18;
	float w1 = texture(n_low, p * 0.016 + vec2(t * 0.07, t * 0.04)).r;
	float w2 = texture(n_low, p * 0.038 - vec2(t * 0.05, -t * 0.06) + 0.37).r;
	float w3 = texture(n_hi, p * 0.085 + vec2(t * 0.09, -t * 0.07)).r;
	float wave = w1 * 0.45 + w2 * 0.35 + w3 * 0.2;
	vec3 deep = vec3(0.04, 0.085, 0.105);
	vec3 mid = vec3(0.075, 0.145, 0.165);
	vec3 crest = vec3(0.18, 0.255, 0.27);
	vec3 foam_col = vec3(0.52, 0.60, 0.62);
	vec3 col = mix(deep, mid, smoothstep(0.28, 0.70, wave));
	float fw = length(fwidth(p));
	float fade = clamp(1.0 - fw * 1.6, 0.0, 1.0);
	float ripple = smoothstep(0.56, 0.76, w2 * 0.55 + w3 * 0.45) * fade;
	float foam = smoothstep(0.72, 0.85, w2 * 0.5 + w3 * 0.5) * fade;
	col = mix(col, crest, ripple * 0.52);
	col = mix(col, foam_col, foam * 0.35);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	col = mix(col, vec3(0.22, 0.29, 0.32), fres * 0.38);
	ALBEDO = col;
	vec3 n1 = texture(n_nrm, p * 0.09 + vec2(t * 0.11, t * 0.07)).rgb;
	vec3 n2 = texture(n_nrm, p * 0.21 - vec2(t * 0.08, -t * 0.09) + 0.41).rgb;
	NORMAL_MAP = normalize(mix(n1, n2, 0.5) * 2.0 - 1.0 + vec3(0.0, 0.0, 1.6)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = (0.72 + ripple * 0.58) * fade;
	ROUGHNESS = clamp(mix(0.22, 0.36, ripple) + foam * 0.35 + (1.0 - fade) * 0.22, 0.18, 0.85);
	METALLIC = 0.04;
	SPECULAR = 0.62;
	CLEARCOAT = (1.0 - foam) * 0.32;
	CLEARCOAT_ROUGHNESS = 0.24;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _water_shader
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
	for r: Dictionary in wet_rivers:
		var hw := float(r.w) * 0.5
		var rp := _river_in_lake_pts(r.pts, hw)
		shingle_polys.append_array(_outers(Geometry2D.offset_polyline(rp, hw + 5.2, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)))
		mud_polys.append_array(_outers(Geometry2D.offset_polyline(rp, hw + 2.8, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)))
		water_polys.append_array(_outers(Geometry2D.offset_polyline(rp, hw, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)))
	for l: Vector3 in lakes:
		shingle_polys.append(WC.lake_poly(l, 64, 5.6))
		mud_polys.append(WC.lake_poly(l, 64, 3.0))
		water_polys.append(WC.lake_poly(l, 64, 0.0))
	var st_shingle := SurfaceTool.new()
	var st_mud := SurfaceTool.new()
	var st_water := SurfaceTool.new()
	var st_bank := SurfaceTool.new()
	var st_lip := SurfaceTool.new()
	for st in [st_shingle, st_mud, st_water, st_bank, st_lip]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ns := 0
	for poly: PackedVector2Array in _merge_polys(shingle_polys):
		_emit_poly(st_shingle, poly, 0.015, 0.0)
		ns += 1
	var nm := 0
	for poly: PackedVector2Array in _merge_polys(mud_polys):
		_emit_poly(st_mud, poly, 0.028, 0.0)
		nm += 1
	var nw := 0
	for poly: PackedVector2Array in _merge_polys(water_polys):
		_emit_poly(st_water, poly, 0.052, 0.0)
		nw += 1
	# 岸线区分硬化城区驳岸与自然生态缓坡岸：城区/港区/工业区（D/R/I/H/Y/M）砌筑连续混凝土防洪堤；郊野/林地/湿地/湖湾保持自然砂砾卵石缓坡，彻底消除荒野水体套水泥圈的生硬感
	var lim := Rect2(-EXT_HALF - 16.0, -EXT_HALF - 16.0, EXT_HALF * 2.0 + 32.0, EXT_HALF * 2.0 + 32.0)
	var cuts: Array = []
	var cgrid := {}
	var r_bands: Array = []
	var r_ends: Array = []
	for r: Dictionary in wet_rivers:
		var hw := float(r.w) * 0.5
		var rp := _river_in_lake_pts(r.pts, hw)
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
			if absf(p.x) <= EXT_HALF - 4.0 and absf(p.y) <= EXT_HALF - 4.0 and not in_lake(p, 4.0) and not (zone_at(Vector3(p.x, 0, p.y)) in ["A", "B"]):
				r_ends.append([p, (p - q).normalized(), hw])
	for l: Vector3 in lakes:
		_add_cut(cuts, cgrid, WC.lake_poly(l, 64, -0.03))
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
			var ring := _half_ring(e[0], e[1], hw, hw + w_bank, 16)
			for piece: PackedVector2Array in _subtract_cuts(ring, lcuts, lcgrid, []):
				var pc := WC.centroid(piece)
				if zone_at(Vector3(pc.x, 0, pc.y)) in urban_zones:
					_emit_poly(st, piece, layer[2], layer[3])
					_add_cut(lcuts, lcgrid, piece)
					nb += 1
		for l: Vector3 in lakes:
			for ring: PackedVector2Array in _lake_ring_halves(l, w_bank, 56):
				for piece: PackedVector2Array in _subtract_cuts(ring, lcuts, lcgrid, []):
					var pc := WC.centroid(piece)
					if zone_at(Vector3(pc.x, 0, pc.y)) in urban_zones:
						_emit_poly(st, piece, layer[2], layer[3])
						_add_cut(lcuts, lcgrid, piece)
						nb += 1
	var SHINGLE: ShaderMaterial = A.concrete(Color(0.28, 0.26, 0.22), false).duplicate()
	SHINGLE.set_meta("no_outline", true)
	var MUD: ShaderMaterial = A.concrete(Color(0.18, 0.17, 0.15), false).duplicate()
	MUD.set_meta("no_outline", true)
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
		if border_dist(Vector2(l.x, l.y)) < -l.z * 1.4 - 12.0:
			continue
		var cs_core := CollisionShape3D.new()
		var sh_core := CylinderShape3D.new()
		sh_core.radius = maxf(2.0, l.z * 0.68)
		sh_core.height = 3.0
		cs_core.shape = sh_core
		cs_core.position = Vector3(l.x, 1.5, l.y)
		bank.add_child(cs_core)
		var lpoly := WC.lake_poly(l, 64, 0.45)
		var m := lpoly.size()
		for i in m:
			var pa := lpoly[i]
			var pb := lpoly[(i + 1) % m]
			var pm := (pa + pb) * 0.5
			if border_dist(pm) < -10.0 or _on_bridge(pm, -0.1):
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

# ---------- 铁轨 ----------
func _build_rails() -> void:
	rng.seed = _map_seed(5)
	if rail_polys.is_empty():
		return
	var ties: Array = []
	var rails: Array = []
	var ballast_polys: Array = []
	var tie_pts: Array = []
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for line: PackedVector2Array in rail_polys:
		for ch: PackedVector2Array in _chunks(line):
			ballast_polys.append_array(_offset_line(_ext_line(ch, 0.05), 1.8))
		for k in line.size() - 1:
			var a := line[k]
			var b := line[k + 1]
			var seg := a.distance_to(b)
			if seg < 0.05:
				continue
			var t := (b - a) / seg
			var ang := atan2(t.x, t.y)
			var bs := Basis(Vector3.UP, ang)
			var n := maxi(1, int(seg / 0.9))
			for i in n:
				var p := a.lerp(b, (i + 0.5) / n)
				var dup_t := false
				for tp: Vector2 in tie_pts:
					if tp.distance_squared_to(p) < 0.75 * 0.75:
						dup_t = true
						break
				if not dup_t:
					tie_pts.append(p)
					ties.append(Transform3D(bs.scaled_local(Vector3(2.6, 0.12, 0.28)), Vector3(p.x, 0.135, p.y)))
			var m := (a + b) * 0.5
			for sd in [-0.72, 0.72]:
				var q: Vector2 = m + Vector2(-t.y, t.x) * sd
				rails.append(Transform3D(bs.scaled_local(Vector3(0.1, 0.12, maxf(0.1, seg - 0.01))), Vector3(q.x, 0.225, q.y)))
	var BALLAST: ShaderMaterial = A.gravel_mat(Color(0.36, 0.34, 0.32)).duplicate()
	BALLAST.set_meta("no_outline", true)
	var nb := _emit_dedup_polys(st, ballast_polys, 0.110, 0.05)
	_st_commit(st, BALLAST, nb)
	_multimesh(A.bevel_box(Vector3.ONE, 0.02), A.paint(Color(0.3, 0.24, 0.18), 0.0, 0.9, {"wear": 0.4, "dust": 0.6, "panel_scale": 0.0}), ties, false)
	_multimesh(A.bevel_box(Vector3.ONE, 0.0), A.metal(Color(0.42, 0.38, 0.34)), rails, false)


func _wagon(p: Vector3, horiz: bool) -> void:
	# 三类写实铁路货车：0 波纹钢棚车（推拉门+车顶走道）、1 重工卧式化工罐车、2 高边敞车/重型帆布设备平车
	var wtype := rng.randi() % 3
	var c: Color = [Color(0.42, 0.22, 0.15), Color(0.25, 0.30, 0.34), Color(0.36, 0.34, 0.26), Color(0.28, 0.33, 0.27)][rng.randi() % 4]
	var fp := Vector3(12.0, 3.2, 2.9) if horiz else Vector3(2.9, 3.2, 12.0)
	var sb := _bldg_body(Vector3(2.9, 3.2, 12.0), p + Vector3(0, 2.0, 0))
	sb.rotation_degrees.y = 90.0 if horiz else 0.0
	var M_BODY := A.corrugated(c, 0.68, 0.34)
	var M_SUB := A.corrugated(c.darkened(0.22), 0.72, 0.34)
	var M_DARK := A.metal(Color(0.14, 0.145, 0.155))
	var M_STEEL := A.metal(Color(0.28, 0.28, 0.29))
	# 底架贯通中梁 + 两端车钩缓冲器 + 双轴转向架与四组钢轮
	_ibox(sb, Vector3(2.82, 0.28, 12.05), 0.03, M_DARK, Vector3(0, -1.08, 0))
	for ez in [-6.22, 6.22]:
		_ibox(sb, Vector3(0.42, 0.22, 0.46), 0.02, M_STEEL, Vector3(0, -1.08, ez), Vector3.ZERO, Vector3.ONE, false)
	for bz in [-4.05, 4.05]:
		_ibox(sb, Vector3(1.88, 0.26, 0.52), 0.02, M_DARK, Vector3(0, -1.34, bz), Vector3.ZERO, Vector3.ONE, false)
		for sx in [-0.82, 0.82]:
			_ibox(sb, Vector3(0.16, 0.34, 1.98), 0.02, M_STEEL, Vector3(sx, -1.46, bz), Vector3.ZERO, Vector3.ONE, false)
			for wz_off in [-0.58, 0.58]:
				_imesh(sb, A.cyl(0.42, 0.13, 0.42, 12), M_DARK, Vector3(sx * 0.88, -1.46, bz + wz_off), Vector3(0, 0, 90), Vector3.ONE, false)
	if wtype == 0:
		# 波纹钢铁路棚车：主车厢 + 外露立柱肋 + 中央推拉货门 + 车顶防滑巡检走道
		_ibox(sb, Vector3(2.88, 2.66, 11.86), 0.05, M_BODY, Vector3(0, 0.36, 0))
		_ibox(sb, Vector3(2.94, 0.12, 11.96), 0.02, M_SUB, Vector3(0, 1.66, 0), Vector3.ZERO, Vector3.ONE, false)
		_ibox(sb, Vector3(0.64, 0.07, 11.70), 0.01, M_STEEL, Vector3(0, 1.73, 0), Vector3.ZERO, Vector3.ONE, false)
		for ri in 7:
			var rz := -4.8 + ri * 1.6
			if absf(rz) > 1.2:
				_ibox(sb, Vector3(2.96, 2.52, 0.12), 0.01, M_SUB, Vector3(0, 0.34, rz), Vector3.ZERO, Vector3.ONE, false)
		for sx in [-1.46, 1.46]:
			_ibox(sb, Vector3(0.08, 2.28, 2.15), 0.02, M_SUB, Vector3(sx, 0.32, 0.0), Vector3.ZERO, Vector3.ONE, false)
			_ibox(sb, Vector3(0.10, 0.08, 2.55), 0.01, M_DARK, Vector3(sx * 1.02, 1.50, 0.0), Vector3.ZERO, Vector3.ONE, false)
	elif wtype == 1:
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

# ---------- 山脊 ----------
func _build_ridges() -> void:
	rng.seed = _map_seed(6)
	ridge_pts.clear()
	for line: PackedVector2Array in layout.ridges:
		for p: Vector2 in line:
			if on_road(p, 4.0):
				continue
			var q := Vector3(p.x + rng.randf_range(-1.5, 1.5), 0, p.y + rng.randf_range(-1.5, 1.5))
			if _blocked(q, 3.0, false):
				continue
			_boulder(q, rng.randf_range(2.8, 5.0))
			ridge_pts.append(Vector2(q.x, q.z))
			if rng.randf() < 0.5:
				var q2 := q + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
				if not on_road(Vector2(q2.x, q2.z), 3.0) and not _blocked(q2, 2.0, false):
					_boulder(q2, rng.randf_range(1.5, 3.0))
					ridge_pts.append(Vector2(q2.x, q2.z))


# ---------- 城区：街块与建筑 ----------
## 固定布局：建筑、院墙、工业区储罐与集装箱、港口堆场、军营围墙均按固定种子生成，轮廓与大地图一致
func _build_blocks() -> void:
	rng.seed = _map_seed(8)
	# 建筑（轮廓来自城市群布局，与大地图一致）
	for b: Dictionary in layout.bldgs:
		_layout_building(b)
	# 外围连续城市群远景建筑群、林带、海岸与断崖（纯视觉 MultiMesh 合批，无物理碰撞，呈现从城市群大地图截取的不规则战区实感）
	_build_backdrop()
	# 街块里的杂物与围合（仅限不规则战区内部）
	for blk: Dictionary in layout.blocks:
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


func _build_backdrop() -> void:
	if not is_surface_map:
		return
	var brng := RandomNumberGenerator.new()
	brng.seed = _map_seed(801)
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

	# 外围工业区储罐与港区堆场集装箱（严格避让 backdrop 建筑多边形，确保 0 重叠穿模）
	for blk: Dictionary in layout.blocks:
		var poly: PackedVector2Array = blk.poly
		var bc := WC.centroid(poly)
		if border_dist(bc) > -8.0:
			continue
		var ch_b := str(blk.ch)
		if ch_b == "I" and brng.randf() < 0.65:
			var rad := brng.randf_range(2.6, 3.8)
			var th := brng.randf_range(5.2, 8.6)
			var t_obb := WC.obb_corners(bc, 0.0, rad * 2.4, rad * 2.4)
			if not on_road(bc, rad + 1.5) and not in_river(bc, rad + 2.0) and not WC._hits(bd_polys_only, t_obb, 1.2):
				tank_cyls.append(Transform3D(Basis.IDENTITY.scaled(Vector3(rad * 2.0, th, rad * 2.0)), Vector3(bc.x, th * 0.5, bc.y)))
				bd_polys_only.append(t_obb)
		elif ch_b == "H" and brng.randf() < 0.8:
			var c_bs := Basis(Vector3.UP, -float(blk.ang) + PI * 0.5)
			for ci in 2:
				var cq := bc + Vector2(cos(float(blk.ang)), sin(float(blk.ang))) * (float(ci) - 0.5) * 7.2
				var c_obb := WC.obb_corners(cq, float(blk.ang) - PI * 0.5, 3.0, 6.8)
				if border_dist(cq) < -7.0 and not on_road(cq, 3.5) and not in_river(cq, 3.5) and not WC._hits(bd_polys_only, c_obb, 1.2):
					var c_tf := Transform3D(c_bs.scaled_local(Vector3(2.4, 2.4, 6.0)), Vector3(cq.x, 1.2, cq.y))
					if brng.randf() < 0.5:
						cont_blue.append(c_tf)
					else:
						cont_rust.append(c_tf)
					bd_polys_only.append(c_obb)

	# 外围林带、公园树木与远景断崖岩层
	var bd_trunks: Array = []
	var bd_pines: Array = []
	var bd_broads: Array = []
	var bd_autumn: Array = []
	var bd_cliffs: Array = []
	var gz := -EXT_HALF + 4.0
	while gz <= EXT_HALF - 4.0:
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
			elif zt == "K" and brng.randf() < 0.45:
				var kh := brng.randf_range(6.5, 13.5)
				var kw := brng.randf_range(6.2, 9.4)
				var kbs := Basis(Vector3.UP, brng.randf() * TAU)
				bd_cliffs.append(Transform3D(kbs.scaled_local(Vector3(kw * 0.86, kh * 0.58, kw * 0.82)), Vector3(q.x, kh * 0.36, q.y)))
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
		var lcx := WC.coast_x(orig.y + z_s) - orig.x
		if lcx < EXT_HALF + 85.0:
			has_coast = true
		coast_line.append(Vector2(clampf(lcx, -EXT_HALF - 50.0, x_far - 4.0), z_s))
		z_s += 2.5
	if has_coast and coast_line.size() >= 2:
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


func _barrack(p: Vector3, sz: Vector3, rot := 0.0) -> void:
	# 军事区加固营房：钢筋混凝土防爆墙裙与斜扶壁 + 军绿压型钢板墙身 + 外露拱肋波纹装甲顶 + 窄射孔观察窗 + 双扇防爆铁门 + 过滤新风机组
	var sb := _bldg_body(sz, p + Vector3(0, sz.y * 0.5, 0))
	sb.rotation.y = -rot
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var hy := sz.y * 0.5
	var M_WALL := A.corrugated(Color(0.30, 0.34, 0.25), 0.42, 0.32)
	var M_RIB := A.paint(Color(0.20, 0.23, 0.18), 0.48, 0.60, {"wear": 0.55, "rust": 0.48})
	var M_CON := A.concrete(Color(0.44, 0.43, 0.40), false)
	var M_DARK := A.metal(Color(0.14, 0.15, 0.16))
	var M_WIN := A.window_mat(0.14, Vector2(0.58, 0.44))
	_ibox(sb, sz, 0.02, M_WALL)
	_ibox(sb, Vector3(sz.x + 0.28, 1.15, sz.z + 0.28), 0.04, M_CON, Vector3(0, -hy + 0.575, 0))
	var arch_h := minf(1.25, sz.z * 0.20)
	_imesh(sb, A.cyl(1.0, 1.0, 1.0, 28), M_WALL, Vector3(0, hy, 0), Vector3(0, 0, 90), Vector3(arch_h, sz.x + 0.24, hz + 0.06))
	var n_bays := maxi(3, int(sz.x / 2.4))
	for k in n_bays + 1:
		var rx := -hx + k * sz.x / float(n_bays)
		_imesh(sb, A.cyl(1.03, 0.16, 1.03, 24), M_RIB, Vector3(rx, hy, 0), Vector3(0, 0, 90), Vector3(arch_h, 1.0, hz + 0.09), false)
		for sd in [-1.0, 1.0]:
			_ibox(sb, Vector3(0.22, sz.y, 0.18), 0.02, M_RIB, Vector3(rx, 0.0, sd * (hz + 0.05)))
			if absf(rx) > 1.6:
				_ibox(sb, Vector3(0.28, 1.05, 0.34), 0.03, M_CON, Vector3(rx, -hy + 0.52, sd * (hz + 0.18)), Vector3(sd * -10.0, 0, 0))
	for k in n_bays:
		var wx := -hx + (float(k) + 0.5) * sz.x / float(n_bays)
		for sd in [-1.0, 1.0]:
			if sd > 0.0 and absf(wx) < 1.8:
				continue
			_ibox(sb, Vector3(1.18, 0.44, 0.08), 0.01, M_WIN, Vector3(wx, 0.38, sd * (hz + 0.03)), Vector3.ZERO, Vector3.ONE, false)
			_ibox(sb, Vector3(1.32, 0.10, 0.22), 0.015, M_DARK, Vector3(wx, 0.64, sd * (hz + 0.09)), Vector3.ZERO, Vector3.ONE, false)
	# 正门装甲气闸门框 + 黄黑警戒门槛 + 三防核生化过滤新风机组 + 通讯鞭状天线
	_ibox(sb, Vector3(2.20, 2.35, 0.20), 0.03, M_CON, Vector3(0, -hy + 1.18, hz + 0.08))
	for dx_s in [-0.46, 0.46]:
		_ibox(sb, Vector3(0.86, 2.02, 0.08), 0.015, M_DARK, Vector3(dx_s, -hy + 1.04, hz + 0.16), Vector3.ZERO, Vector3.ONE, false)
	_ibox(sb, Vector3(2.15, 0.14, 0.24), 0.01, A.hazard(), Vector3(0, -hy + 0.08, hz + 0.16), Vector3.ZERO, Vector3.ONE, false)
	_ibox(sb, Vector3(2.55, 0.14, 0.72), 0.02, M_RIB, Vector3(0, -hy + 2.42, hz + 0.32), Vector3(6, 0, 0))
	_ibox(sb, Vector3(1.65, 0.85, 1.25), 0.03, M_DARK, Vector3(-hx * 0.48, hy + arch_h * 0.72, 0))
	_imesh(sb, A.cyl(0.035, 2.6, 0.055, 8), M_DARK, Vector3(hx * 0.62, hy + arch_h + 1.1, 0), Vector3.ZERO, Vector3.ONE, false)
	A.stencil(sb, "SEC-%02d" % rng.randi_range(1, 19), Vector3(-hx * 0.56, 0.36, hz + 0.16), Vector3.ZERO, 0.018, Color(0.86, 0.84, 0.70, 0.62))


func _factory_shed(p: Vector3, sz: Vector3, rot := 0.0) -> void:
	# 编组站/工矿机务段检修车库：红褐锈蚀工字钢立柱 + 压型钢板墙身 + 锯齿高侧天窗屋面 + 贯通卷帘机车检修门 + 悬挑工字钢行车梁与排烟管
	var c: Color = [Color(0.38, 0.25, 0.19), Color(0.28, 0.32, 0.35), Color(0.36, 0.34, 0.28)][rng.randi() % 3]
	var M_WALL := A.corrugated(c, 0.62, 0.30)
	var M_STEEL := A.metal(Color(0.17, 0.18, 0.19))
	var M_CON := A.concrete(Color(0.38, 0.37, 0.35), false)
	var M_SHUT := A.corrugated(Color(0.22, 0.24, 0.26), 0.45, 0.44)
	var M_GLS := A.glass(Color(0.26, 0.38, 0.44))
	var sb := _bldg_body(sz, p + Vector3(0, sz.y * 0.5, 0))
	sb.rotation.y = -rot
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var hy := sz.y * 0.5
	_ibox(sb, sz, 0.02, M_WALL)
	_ibox(sb, Vector3(sz.x + 0.20, 0.68, sz.z + 0.20), 0.03, M_CON, Vector3(0, -hy + 0.34, 0))
	var n_col := maxi(2, int(sz.x / 2.5))
	for k in n_col + 1:
		var cx := -hx + k * sz.x / float(n_col)
		for sd in [-1.0, 1.0]:
			_ibox(sb, Vector3(0.20, sz.y + 0.08, 0.22), 0.015, M_STEEL, Vector3(cx, 0.02, sd * (hz + 0.06)))
	# 锯齿采光天窗气楼屋顶 + 排风烟囱
	var mon_h := clampf(sz.z * 0.18, 0.72, 1.15)
	var outline := PackedVector2Array([Vector2(-0.5, 0.0), Vector2(-0.18, 1.0), Vector2(0.5, 0.0)])
	_imesh(sb, A.prism(outline, 1.0, 0.01), A.roof_mat(c.darkened(0.18), 0.65, true),
		Vector3(0, hy, 0), Vector3(0, 90, 0), Vector3(sz.z + 0.32, mon_h, sz.x + 0.28))
	_ibox(sb, Vector3(sz.x * 0.84, mon_h * 0.56, 0.10), 0.01, M_GLS, Vector3(0, hy + mon_h * 0.42, -hz * 0.16), Vector3(-16, 0, 0), Vector3.ONE, false)
	_imesh(sb, A.cyl(0.18, 1.35, 0.20, 10), M_STEEL, Vector3(hx * 0.52, hy + mon_h * 0.5 + 0.55, -hz * 0.24))
	_imesh(sb, A.cyl(0.28, 0.12, 0.16, 10), M_STEEL, Vector3(hx * 0.52, hy + mon_h * 0.5 + 1.26, -hz * 0.24), Vector3.ZERO, Vector3.ONE, false)
	# 正脸宽幅检修卷帘门 + 门头悬挑单轨电葫芦工字钢梁 + 侧墙百叶散热窗
	var bw := minf(sz.x * 0.58, 4.6)
	var bh := sz.y * 0.76
	_ibox(sb, Vector3(bw + 0.28, bh + 0.16, 0.16), 0.02, M_STEEL, Vector3(0, -hy + bh * 0.5, hz + 0.05))
	for sl in 5:
		_ibox(sb, Vector3(bw - 0.12, bh * 0.165, 0.08), 0.01, M_SHUT, Vector3(0, -hy + bh * (0.12 + sl * 0.185), hz + 0.11), Vector3.ZERO, Vector3.ONE, false)
	_ibox(sb, Vector3(0.18, 0.24, 0.92), 0.015, A.hazard(), Vector3(0, -hy + bh + 0.18, hz + 0.38))
	for sx_v in [-1.0, 1.0]:
		_ibox(sb, Vector3(0.10, 0.85, minf(1.8, sz.z * 0.38)), 0.01, M_STEEL, Vector3(sx_v * (hx + 0.03), 0.28, 0.0), Vector3.ZERO, Vector3.ONE, false)


func _apartment(p: Vector3, sz: Vector3, rot := 0.0) -> void:
	# 工业区职工公寓楼：预制混凝土板缝 / 红砖砌体墙面 + 凸出楼梯间采光核 + 半凹陷铁栏阳台与空调外机 + 屋顶水箱架
	var is_brk := rng.randf() < 0.40
	var c: Color = Color(0.45, 0.32, 0.26) if is_brk else [Color(0.53, 0.50, 0.45), Color(0.47, 0.46, 0.43), Color(0.50, 0.43, 0.37)][rng.randi() % 3]
	var sb := _bldg_body(sz, p + Vector3(0, sz.y * 0.5, 0))
	sb.rotation.y = -rot
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var hy := sz.y * 0.5
	var M_WALL: ShaderMaterial = A.brick(c) if is_brk else A.concrete(c)
	var M_DARK := A.concrete(Color(0.30, 0.29, 0.27) if is_brk else c.darkened(0.34), false)
	var M_TRIM := A.concrete(Color(0.52, 0.49, 0.44) if is_brk else c.lightened(0.12), false)
	var M_STEEL := A.metal(Color(0.17, 0.18, 0.19))
	var M_WIN := A.window_mat(0.20, Vector2(0.56, 0.52))
	var M_AC := A.paint(Color(0.54, 0.54, 0.51), 0.35, 0.62, {"wear": 0.62, "rust": 0.55})
	_ibox(sb, sz, 0.02, M_WALL)
	_ibox(sb, Vector3(sz.x + 0.30, 0.65, sz.z + 0.30), 0.03, M_DARK, Vector3(0, -hy + 0.325, 0))
	_ibox(sb, Vector3(sz.x + 0.26, 0.22, sz.z + 0.26), 0.02, M_TRIM, Vector3(0, hy + 0.08, 0))
	_ibox(sb, Vector3(sz.x - 0.32, 0.10, sz.z - 0.32), 0.02, A.tar_roof(Color(0.25, 0.26, 0.28)), Vector3(0, hy + 0.16, 0), Vector3.ZERO, Vector3.ONE, false)
	# 中央楼梯间竖向采光核与单元防盗门雨棚
	_ibox(sb, Vector3(2.35, sz.y + 1.35, 0.42), 0.03, M_TRIM, Vector3(0, 0.65, hz + 0.16))
	var sw_y0 := -hy + 2.28
	var sw_y1 := hy + 1.05
	if sw_y1 > sw_y0 + 0.4:
		_ibox(sb, Vector3(0.76, sw_y1 - sw_y0, 0.08), 0.01, M_WIN, Vector3(0, (sw_y0 + sw_y1) * 0.5, hz + 0.38), Vector3.ZERO, Vector3.ONE, false)
	_ibox(sb, Vector3(1.45, 1.95, 0.10), 0.015, M_STEEL, Vector3(0, -hy + 0.98, hz + 0.38), Vector3.ZERO, Vector3.ONE, false)
	_ibox(sb, Vector3(2.45, 0.14, 0.78), 0.02, M_DARK, Vector3(0, -hy + 2.08, hz + 0.52))
	var floors := maxi(2, int(sz.y / 2.35))
	var n_cols := maxi(2, int((sz.x - 3.0) / 3.2))
	for f in floors:
		var fy := -hy + 0.75 + f * ((sz.y - 1.0) / float(floors))
		if fy > hy - 0.8:
			break
		_ibox(sb, Vector3(sz.x + 0.14, 0.12, sz.z + 0.14), 0.015, M_DARK, Vector3(0, fy - 0.42, 0), Vector3.ZERO, Vector3.ONE, false)
		for side_x in [-1.0, 1.0]:
			for ci: int in maxi(1, int(n_cols / 2)):
				var bx: float = side_x * (2.05 + float(ci) * 2.55)
				if absf(bx) > hx - 1.25:
					continue
				# 正面外挑小阳台 + 铁艺护栏 + 空调外机；背面窗洞
				if f >= 1:
					_ibox(sb, Vector3(1.92, 0.12, 0.44), 0.02, M_TRIM, Vector3(bx, fy - 0.38, hz + 0.20))
					_ibox(sb, Vector3(1.90, 0.52, 0.06), 0.01, M_STEEL, Vector3(bx, fy - 0.08, hz + 0.39), Vector3.ZERO, Vector3.ONE, false)
				_ibox(sb, Vector3(1.16, 1.05, 0.08), 0.01, M_WIN, Vector3(bx, fy + 0.18, hz + 0.03), Vector3.ZERO, Vector3.ONE, false)
				_ibox(sb, Vector3(1.02, 0.92, 0.08), 0.01, M_WIN, Vector3(bx, fy + 0.18, -hz - 0.03), Vector3.ZERO, Vector3.ONE, false)
				if (f + ci) % 2 == 0:
					_ibox(sb, Vector3(0.68, 0.48, 0.28), 0.02, M_AC, Vector3(bx + side_x * 0.82, fy + 0.12, -hz - 0.15))
	# 屋顶女儿墙与热水器/水箱支架
	for sd_p in [-1.0, 1.0]:
		_ibox(sb, Vector3(sz.x, 0.46, 0.24), 0.02, M_DARK, Vector3(0, hy + 0.32, sd_p * (hz - 0.12)))
		_ibox(sb, Vector3(0.24, 0.46, maxf(0.8, sz.z - 0.52)), 0.02, M_DARK, Vector3(sd_p * (hx - 0.12), hy + 0.32, 0))
	_imesh(sb, A.cyl(0.56, 1.45, 0.56, 14), M_AC, Vector3(-hx * 0.45, hy + 0.72, -hz * 0.25), Vector3(0, 0, 90))
	for lx_t in [-0.52, 0.52]:
		_ibox(sb, Vector3(0.08, 0.65, 0.82), 0.01, M_STEEL, Vector3(-hx * 0.45 + lx_t, hy + 0.38, -hz * 0.25), Vector3.ZERO, Vector3.ONE, false)


func _block_downtown(blk: Dictionary) -> void:
	# 内院 / 空地块：顺着街块朝向规整停放的车辆
	var yaw0 := rad_to_deg(-float(blk.ang))
	for k in rng.randi_range(0, 2):
		var p := _spot_in_poly(blk.poly, 3.2)
		if p != Vector3.INF and not on_road(Vector2(p.x, p.z), 2.5):
			_wreck_car(p, yaw0 + (0.0 if rng.randf() < 0.5 else 90.0))


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
	if rng.randf() < 0.25:
		var p := _spot_in_poly(poly, 3.2)
		if p != Vector3.INF and not on_road(Vector2(p.x, p.z), 2.5):
			_wreck_car(p, rad_to_deg(-float(blk.ang)) + (0.0 if rng.randf() < 0.5 else 90.0))


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
			_container(p, rot, [Color(0.25, 0.38, 0.5), Color(0.62, 0.3, 0.18), Color(0.35, 0.45, 0.3), Color(0.55, 0.5, 0.35)][rng.randi() % 4])
			_obb_blocks(Vector2(p.x, p.z), deg_to_rad(-rot) + PI * 0.5, 6.4, 2.8)
	if rng.randf() < 0.45:
		var p := _spot_in_poly(poly, 2.5)
		if p != Vector3.INF:
			_chimney(p)
	_fence_poly(poly, 2.4, 0.35)


func _block_harbor(blk: Dictionary) -> void:
	var poly: PackedVector2Array = blk.poly
	var ang: float = blk.ang
	var cols := [Color(0.25, 0.38, 0.5), Color(0.62, 0.3, 0.18), Color(0.35, 0.45, 0.3), Color(0.55, 0.5, 0.35), Color(0.5, 0.2, 0.2)]
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
					put += 1
				tu += 7.4
			tv += 4.2
	# 岸桥集装箱龙门吊机：四柱门架 + 横梁斜撑桁架 + A字拉索塔顶 + 司机室与悬吊集装箱吊具
	if rng.randf() < 0.4:
		var p := _spot_in_poly(poly, 5.0, 20)
		if p != Vector3.INF:
			var M := A.paint(Color(0.74, 0.45, 0.13), 0.5, 0.55, {"rust": 0.78, "wear": 0.6, "panel_scale": 0.8})
			var M_DARK := A.metal(Color(0.16, 0.17, 0.18))
			var M_CAB := A.paint(Color(0.30, 0.32, 0.34), 0.4, 0.58, {"wear": 0.5, "rust": 0.45})
			var root := Node3D.new()
			world.add_child(root)
			root.position = p
			root.rotation.y = -ang
			for lx in [-3.5, 3.5]:
				A.add(root, A.bevel_box(Vector3(1.1, 0.65, 8.6), 0.04), M_DARK, Vector3(lx, 0.32, 0))
				for lz in [-3.5, 3.5]:
					_static_box(Vector3(0.72, 14.0, 0.72), Vector3(lx, 7.0, lz), Color.WHITE, root, M)
				for by in [4.6, 9.4, 13.6]:
					A.add(root, A.bevel_box(Vector3(0.45, 0.42, 7.2), 0.02), M, Vector3(lx, by, 0))
				A.add(root, A.tube([Vector3(lx, 0.8, -3.4), Vector3(lx, 9.2, 3.4)], 0.11, 6, 2), M_DARK, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
				A.add(root, A.tube([Vector3(lx, 0.8, 3.4), Vector3(lx, 9.2, -3.4)], 0.11, 6, 2), M_DARK, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			for lz in [-3.5, 3.5]:
				A.add(root, A.bevel_box(Vector3(7.6, 0.55, 0.55), 0.03), M, Vector3(0, 13.7, lz))
			for bx in [-2.6, 2.6]:
				A.add(root, A.bevel_box(Vector3(0.75, 1.25, 26.5), 0.05), M, Vector3(bx, 14.45, 4.0))
				A.add(root, A.tube([Vector3(bx, 15.0, -3.2), Vector3(bx * 0.4, 19.2, -1.0)], 0.14, 6, 2), M, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
				A.add(root, A.tube([Vector3(bx * 0.4, 19.2, -1.0), Vector3(bx, 14.9, 15.2)], 0.06, 6, 2), M_DARK, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
				A.add(root, A.tube([Vector3(bx * 0.4, 19.2, -1.0), Vector3(bx, 14.9, -8.5)], 0.06, 6, 2), M_DARK, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			A.add(root, A.bevel_box(Vector3(3.4, 2.1, 3.4), 0.08), M_CAB, Vector3(0, 13.1, -5.2))
			A.add(root, A.bevel_box(Vector3(4.8, 0.75, 2.8), 0.05), M_DARK, Vector3(0, 13.8, 8.8))
			A.add(root, A.bevel_box(Vector3(2.2, 1.65, 2.4), 0.06), M_CAB, Vector3(-1.4, 12.6, 8.8))
			A.add(root, A.bevel_box(Vector3(1.8, 0.85, 2.46), 0.02), A.glass(Color(0.20, 0.30, 0.35)), Vector3(-1.4, 12.5, 8.8), Vector3.ZERO, Vector3.ONE, false)
			# 悬吊钢索与集装箱锁具吊架
			for cx_s in [-1.1, 1.1]:
				for cz_s in [-2.4, 2.4]:
					A.add(root, A.cyl(0.025, 6.2, 0.025, 6), M_DARK, Vector3(cx_s, 10.3, 8.8 + cz_s), Vector3.ZERO, Vector3.ONE, false)
			A.add(root, A.bevel_box(Vector3(2.5, 0.38, 5.8), 0.03), A.hazard(), Vector3(0, 7.1, 8.8))
			blocks.append(Rect2(p.x - 5.0, p.z - 5.0, 10.0, 10.0))


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
func _build_fields() -> void:
	rng.seed = _map_seed(9)
	var stalks: Array = []
	var st_berm := SurfaceTool.new()
	st_berm.begin(Mesh.PRIMITIVE_TRIANGLES)
	var berm_polys: Array = []
	for fd: Dictionary in layout.fields:
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
		var t := lo.y + 2.0
		while t < hi.y:
			var seg := _line_in_poly(poly, v * t, u)
			if seg.size() == 2:
				var L := seg[0].distance_to(seg[1])
				var n := int(L / 0.7)
				for i in n:
					if rng.randf() > 0.8:
						continue
					var q := seg[0].lerp(seg[1], (i + 0.5) / n)
					if absf(q.x) > EXT_HALF or absf(q.y) > EXT_HALF:
						continue
					if zone_at(Vector3(q.x, 0, q.y)) != "F" or in_river(q, 1.0) or in_wet(q, 2.0) or on_road(q, 0.5):
						continue
					var hh := rng.randf_range(0.48, 0.96)
					stalks.append(Transform3D(_rand_basis(10).scaled_local(Vector3(hh * 0.9, hh, hh * 0.9)), Vector3(q.x, 0.0, q.y)))
			t += 2.6
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
	var n_berm := _emit_dedup_polys(st_berm, berm_polys, 0.044, 0.044)
	var M_BERM: ShaderMaterial = A.gravel_mat(Color(0.30, 0.25, 0.18)).duplicate()
	M_BERM.set_meta("no_outline", true)
	_st_commit(st_berm, M_BERM, n_berm)
	_multimesh(A.grass_clump_mesh(), A.foliage_mat("grass"), stalks, false)


# ---------- 自然地表与散布物：按 3 米抖动格点逐点看区块字符决定摆什么 ----------
## 每平方米的战利品容器密度（与旧版按格子 n / 4900 一致）
const LOOT_RATE := {"D": 7, "R": 7, "I": 6, "H": 6, "Y": 5, "M": 0, "W": 3, "F": 4, "P": 3, "T": 3, "C": 4, "S": 3, "K": 0, "L": 2}
const LOOT_W := {"D": {"supply": 30, "tool": 30, "military": 22, "safe": 18}, "R": {"supply": 50, "tool": 35, "military": 5, "safe": 10},
	"I": {"supply": 15, "tool": 55, "military": 20, "safe": 10}, "H": {"supply": 30, "tool": 45, "military": 15, "safe": 10},
	"Y": {"supply": 25, "tool": 50, "military": 15, "safe": 10}, "W": {"supply": 40, "tool": 40, "military": 12, "safe": 8},
	"F": {"supply": 60, "tool": 30, "military": 4, "safe": 6}, "P": {"supply": 55, "tool": 25, "military": 8, "safe": 12},
	"T": {"supply": 50, "tool": 30, "military": 10, "safe": 10}, "C": {"supply": 15, "tool": 25, "military": 50, "safe": 10},
	"S": {"supply": 20, "tool": 20, "military": 35, "safe": 25}, "L": {"supply": 45, "tool": 35, "military": 10, "safe": 10}}


func _scatter() -> void:
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
		var c := Vector3(c2.x, 0, c2.y)
		if in_bounds(c, 12.0) and zone_at(c) == "P" and not _blocked(c, 8.0):
			_park_statue(c)
	# 虫巢：每片菌毯区一座虫巢（按数据格子分组）
	_hive_nests()
	var step := 3.0
	var gz := -HALF + 1.5
	while gz < HALF - 1.0:
		var gx := -HALF + 1.5
		while gx < HALF - 1.0:
			var p := Vector3(gx + rng.randf_range(-1.2, 1.2), 0, gz + rng.randf_range(-1.2, 1.2))
			gx += step
			if not in_bounds(p, 3.5):
				continue
			var ch := zone_at(p)
			var roll := rng.randf()
			# 战利品
			var lr: float = float(LOOT_RATE.get(ch, 0)) / 4900.0 * step * step
			if roll < lr:
				if not _blocked(p, 1.4):
					_place_box(GameData._weighted(LOOT_W.get(ch, LOOT_W.W), rng), p)
					blocks.append(Rect2(p.x - 1, p.z - 1, 2, 2))
				continue
			roll = rng.randf()
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
					if roll < 0.022 and not _blocked(p, 3.0):
						var r2 := rng.randf()
						if r2 < 0.4:
							_boulder(p, rng.randf_range(1.5, 4.5))
						elif r2 < 0.65:
							var horiz_w := rng.randf() < 0.5
							var size := Vector3(rng.randf_range(6, 12), rng.randf_range(1.4, 3.0), 0.8) if horiz_w else Vector3(0.8, rng.randf_range(1.4, 3.0), rng.randf_range(6, 12))
							var wsb := _static_box(size, p + Vector3(0, size.y * 0.5, 0), Color(0.50, 0.46, 0.42))
							_ibox(wsb, Vector3(size.x + 0.18, 0.30, size.z + 0.18), 0.03, A.concrete(Color(0.36, 0.34, 0.31), false), Vector3(0, -size.y * 0.5 + 0.15, 0))
							for wp_s in [-0.36, 0.36]:
								var p_sz := Vector3(0.44, size.y * 0.92, 1.08) if horiz_w else Vector3(1.08, size.y * 0.92, 0.44)
								var p_ps := Vector3(wp_s * size.x, -size.y * 0.04, 0) if horiz_w else Vector3(0, -size.y * 0.04, wp_s * size.z)
								_ibox(wsb, p_sz, 0.03, A.concrete(Color(0.42, 0.39, 0.36), false), p_ps)
							blocks.append(_rect_for(p, size))
						elif r2 < 0.8:
							_dead_tree(p)
						elif r2 < 0.9:
							_wreck_car(p)
						else:
							var sz := Vector3(rng.randf_range(5, 8.5), rng.randf_range(2.2, 4.0), rng.randf_range(5, 8.5))
							if not _blocked(p, maxf(sz.x, sz.z) * 0.65 + 2.6):
								_building(p, sz)
								blocks.append(_rect_for(p, sz + Vector3(1.6, 0, 1.6)))
				"C":
					if roll < 0.04 and not _blocked(p, 3.0):
						_crater(p, rims)
					elif roll < 0.05 and not _blocked(p, 3.5):
						_tank_wreck(p)
					elif roll < 0.052 and not _blocked(p, 1.5):
						_fire_barrel(p)
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
	var d0 := A.ground_decal(world, A.scorch_tex(), Color(0.88, 0.85, 0.80, 0.90), rad * 2.55, p + Vector3(0, 0.036, 0))
	d0.rotation.y = rng.randf() * TAU
	var d1 := A.ground_decal(world, A.grime_stain_tex(), Color(0.22, 0.18, 0.15, 0.72), rad * 1.45, p + Vector3(0, 0.039, 0))
	d1.rotation.y = rng.randf() * TAU
	var n := int(rad * 4.2)
	for i in n:
		var a := TAU * i / n + rng.randf_range(-0.16, 0.16)
		var rr := rad * rng.randf_range(0.82, 1.18)
		var sc := rng.randf_range(0.26, 0.72) * rad * 0.34
		rims.append(Transform3D(_rand_basis(38).scaled_local(Vector3(sc * 1.45, sc * 0.58, sc)), p + Vector3(cos(a) * rr, sc * 0.14, sin(a) * rr)))


func _tank_wreck(p: Vector3) -> void:
	# 写实重装甲残骸：55% 击毁主战坦克（倾斜首上+履带负重轮+扭转炮塔+穿孔主炮），45% 6×6 重型装甲运兵车残骸
	var M := A.paint(Color(0.22, 0.23, 0.19), 0.42, 0.78, {"rust": 0.82, "wear": 0.72, "grime": 0.95})
	var M2 := A.paint(Color(0.17, 0.18, 0.15), 0.48, 0.76, {"rust": 0.85, "wear": 0.75, "grime": 1.0})
	var M_TRK := A.metal(Color(0.11, 0.11, 0.12))
	var M_BORE := A.paint(Color(0.02, 0.02, 0.02), 0.0, 0.95)
	A.ground_decal(world, A.blob_tex(), Color(0.04, 0.04, 0.04, 0.72), 6.8, p + Vector3(0, 0.039, 0))
	if rng.randf() < 0.55:
		var sb := _bldg_body(Vector3(3.5, 2.2, 6.4), p + Vector3(0, 1.1, 0))
		sb.rotation_degrees.y = rng.randf() * 360.0
		# 坦克车体 + 大倾角首上装甲 + 尾部百叶动力舱与排烟筒
		_ibox(sb, Vector3(2.36, 1.02, 5.95), 0.06, M, Vector3(0, -0.22, 0.05))
		_ibox(sb, Vector3(2.32, 0.24, 1.65), 0.04, M, Vector3(0, 0.18, -2.35), Vector3(22, 0, 0))
		_ibox(sb, Vector3(2.10, 0.12, 1.85), 0.02, M_TRK, Vector3(0, 0.32, 1.85), Vector3.ZERO, Vector3.ONE, false)
		for sx in [-1.42, 1.42]:
			# 两侧履带总成 + 撕裂侧裙板 + 6 对负重轮
			_ibox(sb, Vector3(0.58, 0.88, 6.15), 0.06, M_TRK, Vector3(sx, -0.58, 0))
			_ibox(sb, Vector3(0.14, 0.48, 4.85), 0.02, M2, Vector3(sx * 1.18, -0.26, -0.2), Vector3(0, 0, sx * -4.0))
			for wi in 6:
				_imesh(sb, A.cyl(0.34, 0.62, 0.34, 10), M2, Vector3(sx, -0.66, -2.25 + wi * 0.90), Vector3(0, 0, 90), Vector3.ONE, false)
		# 歪斜击毁的多面焊接炮塔 + 防盾 + 抽气装置 120mm 主炮 + 炸开的顶舱盖
		var tyaw := rng.randf_range(-42.0, 42.0)
		var tur := Node3D.new()
		sb.add_child(tur)
		tur.position = Vector3(0.08, 0.64, -0.25)
		tur.rotation_degrees = Vector3(rng.randf_range(-5, 4), tyaw, rng.randf_range(-8, 8))
		A.add(tur, A.bevel_box(Vector3(2.38, 0.78, 2.85), 0.16, 0.84), M, Vector3.ZERO)
		A.add(tur, A.bevel_box(Vector3(1.85, 0.48, 0.95), 0.04), M2, Vector3(0, 0.06, 1.75))
		A.add(tur, A.bevel_box(Vector3(0.68, 0.52, 0.56), 0.05), M2, Vector3(0, 0.02, -1.52))
		A.add(tur, A.cyl(0.11, 3.85, 0.13, 12), M2, Vector3(0, 0.04, -3.42), Vector3(84, 0, 0))
		A.add(tur, A.cyl(0.16, 0.58, 0.16, 12), M, Vector3(0, 0.09, -2.85), Vector3(84, 0, 0))
		A.add(tur, A.cyl(0.085, 0.06, 0.085, 10), M_BORE, Vector3(0, 0.24, -5.33), Vector3(84, 0, 0), Vector3.ONE, false)
		A.add(tur, A.cyl(0.42, 0.18, 0.44, 12), M2, Vector3(-0.52, 0.46, 0.15))
		A.add(tur, A.cyl(0.38, 0.06, 0.38, 12), M, Vector3(-0.78, 0.72, 0.15), Vector3(0, 0, 62))
		blocks.append(_rect_for(p, Vector3(6.2, 1, 6.2)))
	else:
		# 6×6 重型装甲运兵车（APC）残骸：防雷V型底壳 + 倾斜观察窗驾驶舱 + 六轮越野胎 + 顶置遥控武器站残架
		var sb := _bldg_body(Vector3(2.85, 2.15, 6.2), p + Vector3(0, 1.08, 0))
		sb.rotation_degrees.y = rng.randf() * 360.0
		_ibox(sb, Vector3(2.56, 1.08, 5.96), 0.10, M, Vector3(0, 0.08, 0.05))
		_ibox(sb, Vector3(2.38, 0.52, 5.40), 0.06, M2, Vector3(0, 0.68, 0.22))
		_ibox(sb, Vector3(2.26, 0.46, 1.15), 0.05, M, Vector3(0, 0.62, -2.35), Vector3(28, 0, 0))
		for sx in [-0.56, 0.56]:
			_ibox(sb, Vector3(0.76, 0.28, 0.08), 0.01, M_BORE, Vector3(sx, 0.72, -2.82), Vector3(28, 0, 0), Vector3.ONE, false)
		for wx in [-1.32, 1.32]:
			for wz in [-2.05, 0.05, 2.05]:
				_imesh(sb, A.cyl(0.54, 0.38, 0.54, 12), A.rubber(), Vector3(wx, -0.52, wz), Vector3(0, 0, 90))
				_imesh(sb, A.cyl(0.28, 0.41, 0.28, 10), M_TRK, Vector3(wx, -0.52, wz), Vector3(0, 0, 90), Vector3.ONE, false)
		_imesh(sb, A.cyl(0.58, 0.34, 0.64, 12), M2, Vector3(0, 1.10, -0.35))
		_imesh(sb, A.cyl(0.06, 1.65, 0.07, 8), M_TRK, Vector3(0, 1.20, -1.25), Vector3(82, 0, 0))
		blocks.append(_rect_for(p, Vector3(5.8, 1, 5.8)))


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
	_poi_lamp(c + Vector3(5.2, 0, 5.2), Color(1.0, 0.8, 0.55))


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
					break


## 悬崖岩体：层叠咬合的沉积岩台地与碎石坡脚（不可通行），外缘参差错落
func _scatter_cliffs() -> void:
	var ROCK := A.rock_mat(Color(0.41, 0.35, 0.28))
	var ROCK2 := A.rock_mat(Color(0.32, 0.27, 0.22))
	var ROCK_TALUS := A.rock_mat(Color(0.36, 0.31, 0.25))
	var step := 5.5
	var x := -HALF + step * 0.5
	while x < HALF:
		var z := -HALF + step * 0.5
		while z < HALF:
			var p := Vector3(x + rng.randf_range(-1.5, 1.5), 0, z + rng.randf_range(-1.5, 1.5))
			z += step
			var q2 := Vector2(p.x, p.z)
			if not in_bounds_xz(q2, 3.0) or zone_at(p) != "K" or on_road(q2, 6.0) or in_wet(q2, 4.0):
				continue
			var edge := false
			for o in [Vector3(step, 0, 0), Vector3(-step, 0, 0), Vector3(0, 0, step), Vector3(0, 0, -step)]:
				if zone_at(p + o) != "K":
					edge = true
			if (edge and rng.randf() < 0.35) or _blocked(p, 2.5):
				continue
			var hgt := rng.randf_range(6.0, 13.0) * (0.62 if edge else 1.0)
			var sz := Vector3(rng.randf_range(5.8, 8.4), hgt, rng.randf_range(5.8, 8.4))
			var sb := _bldg_body(sz, p + Vector3(0, hgt * 0.5, 0))
			sb.rotation_degrees = Vector3(rng.randf_range(-3, 3), rng.randf() * 90.0, rng.randf_range(-3, 3))
			_imesh(sb, A.rock_mesh(rng.randi() % 12), ROCK_TALUS,
				Vector3(rng.randf_range(-0.4, 0.4), -hgt * 0.34, rng.randf_range(-0.4, 0.4)),
				Vector3(rng.randf_range(-5, 5), rng.randf() * 360.0, rng.randf_range(-5, 5)),
				Vector3(sz.x * 1.02, hgt * 0.34, sz.z * 1.02))
			_imesh(sb, A.rock_mesh(rng.randi() % 12), ROCK,
				Vector3(0, -hgt * 0.08, 0),
				Vector3(rng.randf_range(-6, 6), rng.randf() * 360.0, rng.randf_range(-6, 6)),
				Vector3(sz.x * 0.84, hgt * 0.56, sz.z * 0.84))
			_imesh(sb, A.rock_mesh(rng.randi() % 12), ROCK2,
				Vector3(rng.randf_range(-0.75, 0.75), hgt * 0.19, rng.randf_range(-0.75, 0.75)),
				Vector3(rng.randf_range(-8, 8), rng.randf() * 360.0, rng.randf_range(-8, 8)),
				Vector3(sz.x * 0.62, hgt * 0.32, sz.z * 0.64))
			blocks.append(_rect_for(p, sz * 0.92))
			if rng.randf() < 0.16:
				var q := p + Vector3(rng.randf_range(-4.2, 4.2), 0, rng.randf_range(-4.2, 4.2))
				if not _blocked(q, 2.0):
					_boulder(q, rng.randf_range(1.2, 2.6))
		x += step


# ---------- 建筑部件 ----------
func _house(p: Vector3, sz: Vector3, rot := 0.0) -> void:
	var is_brk := rng.randf() < 0.45
	var c: Color = Color(0.47, 0.33, 0.25) if is_brk else [Color(0.58, 0.53, 0.46), Color(0.52, 0.48, 0.43), Color(0.55, 0.54, 0.5)][rng.randi() % 3]
	var sb := _bldg_body(sz, p + Vector3(0, sz.y * 0.5, 0))
	sb.rotation.y = -rot
	_ibox(sb, sz, 0.01, A.brick(c) if is_brk else A.concrete(c))
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var hy := sz.y * 0.5
	var M_DARK := A.concrete(Color(0.30, 0.29, 0.27) if is_brk else c.darkened(0.36), false)
	var M_FR := A.concrete(Color(0.54, 0.51, 0.46) if is_brk else c.lightened(0.14), false)
	var M_WOOD := A.paint(Color(0.32, 0.22, 0.15), 0.0, 0.9)
	var M_WIN := A.window_mat(0.18, Vector2(0.44, 0.44))
	# 台基 + 四角壁柱 + 檐下腰线
	_ibox(sb, Vector3(sz.x + 0.45, 0.14, sz.z + 0.45), 0.02, M_FR, Vector3(0, -hy + 0.07, 0), Vector3.ZERO, Vector3.ONE, false)
	_ibox(sb, Vector3(sz.x + 0.16, 0.52, sz.z + 0.16), 0.03, M_DARK, Vector3(0, -hy + 0.26, 0))
	_ibox(sb, Vector3(sz.x + 0.22, 0.16, sz.z + 0.22), 0.02, M_FR, Vector3(0, hy - 0.06, 0))
	for sx in [-1.0, 1.0]:
		for szz in [-1.0, 1.0]:
			_ibox(sb, Vector3(0.32, sz.y + 0.04, 0.32), 0.02, M_FR, Vector3(sx * (hx - 0.06), 0.01, szz * (hz - 0.06)))
	# 前后与山墙窗框 + 窗台石 + 落水雨水管
	for sd in [-1.0, 1.0]:
		for k in 2:
			var x := (k - 0.5) * hx * 0.95
			_ibox(sb, Vector3(1.12, 1.12, 0.08), 0.01, M_FR, Vector3(x, 0.22, sd * (hz + 0.02)), Vector3.ZERO, Vector3.ONE, false)
			_ibox(sb, Vector3(0.88, 0.88, 0.10), 0.01, M_WIN, Vector3(x, 0.22, sd * (hz + 0.035)), Vector3.ZERO, Vector3.ONE, false)
			_ibox(sb, Vector3(1.24, 0.09, 0.16), 0.01, M_DARK, Vector3(x, -0.36, sd * (hz + 0.05)), Vector3.ZERO, Vector3.ONE, false)
		_ibox(sb, Vector3(0.10, 0.90, 0.90), 0.01, M_WIN, Vector3(sd * (hx + 0.03), 0.22, 0.0), Vector3.ZERO, Vector3.ONE, false)
	_imesh(sb, A.cyl(0.045, sz.y - 0.1, 0.045, 6), A.metal(Color(0.26, 0.27, 0.28)), Vector3(-hx + 0.18, 0.0, hz + 0.06), Vector3.ZERO, Vector3.ONE, false)
	# 入户门 + 门廊混凝土台阶 + 双立柱支撑门廊雨棚（外挑严格收在 <= 0.82m 以内，杜绝窄巷重叠）
	var dx := hx * 0.42
	_ibox(sb, Vector3(1.15, 2.05, 0.12), 0.01, M_WOOD, Vector3(dx, -hy + 1.02, hz + 0.04), Vector3.ZERO, Vector3.ONE, false)
	_ibox(sb, Vector3(1.82, 0.24, 0.82), 0.02, M_DARK, Vector3(dx, -hy + 0.12, hz + 0.40))
	_ibox(sb, Vector3(1.88, 0.14, 0.84), 0.02, M_WOOD, Vector3(dx, -hy + 2.18, hz + 0.40), Vector3(8, 0, 0))
	for px_p in [-0.78, 0.78]:
		_ibox(sb, Vector3(0.11, 1.92, 0.11), 0.01, M_FR, Vector3(dx + px_p, -hy + 1.14, hz + 0.74), Vector3.ZERO, Vector3.ONE, false)
	# 双坡工业旧民居屋顶：压型扣合板岩灰 / 锈暗铁皮 / 陈旧陶土色 + 屋脊盖瓦 + 檐口天沟 + 老虎窗 + 砖砌烟囱
	var roof_c: Color = [Color(0.36, 0.22, 0.17), Color(0.23, 0.26, 0.29), Color(0.34, 0.29, 0.23), Color(0.28, 0.30, 0.27)][rng.randi() % 4]
	var M_ROOF := A.roof_mat(roof_c, 0.36, true)
	var M_RIDGE := A.roof_mat(roof_c.darkened(0.25), 0.36, false)
	var rh: float = minf(sz.x, sz.z) * 0.36
	var rw := sz.x + 0.46
	var rd := sz.z + 0.40
	var outline := PackedVector2Array([Vector2(-0.5, 0), Vector2(0, 1), Vector2(0.5, 0)])
	_imesh(sb, A.prism(outline, 1.0, 0.01), M_ROOF, Vector3(0, hy, 0), Vector3.ZERO, Vector3(rw, rh, rd))
	_ibox(sb, Vector3(0.32, 0.2, rd + 0.12), 0.02, M_RIDGE, Vector3(0, hy + rh - 0.02, 0))
	for sx in [-1.0, 1.0]:
		_ibox(sb, Vector3(0.18, 0.22, rd + 0.08), 0.02, M_FR, Vector3(sx * (rw * 0.5 - 0.06), hy + 0.06, 0))
	_ibox(sb, Vector3(1.15, 0.75, 1.25), 0.02, M_FR, Vector3(-hx * 0.42, hy + rh * 0.42, 0.0))
	_ibox(sb, Vector3(1.3, 0.14, 1.4), 0.02, M_RIDGE, Vector3(-hx * 0.42, hy + rh * 0.42 + 0.42, 0.0))
	_ibox(sb, Vector3(0.68, 1.35, 0.68), 0.03, A.brick(Color(0.42, 0.28, 0.22)), Vector3(hx * 0.45, hy + rh * 0.62, hz * 0.28))
	_ibox(sb, Vector3(0.82, 0.14, 0.82), 0.02, M_FR, Vector3(hx * 0.45, hy + rh * 0.62 + 0.72, hz * 0.28))

func _warehouse(p: Vector3, sz: Vector3, col := Color(-1, 0, 0), rot := 0.0) -> void:
	var c: Color = col if col.r >= 0.0 else [Color(0.42, 0.45, 0.43), Color(0.52, 0.46, 0.37), Color(0.36, 0.42, 0.47)][rng.randi() % 3]
	var M := A.corrugated(c, 0.48, 0.28)
	var sb := _bldg_body(sz, p + Vector3(0, sz.y * 0.5, 0))
	sb.rotation.y = -rot
	_ibox(sb, sz, 0.01, M)
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var hy := sz.y * 0.5
	var M_BASE := A.concrete(Color(0.38, 0.37, 0.35), false)
	var MR := A.corrugated(c.darkened(0.24), 0.52, 0.28)
	# 混凝土高勒脚墙裙 + 钢结构立柱
	_ibox(sb, Vector3(sz.x + 0.24, 1.05, sz.z + 0.24), 0.03, M_BASE, Vector3(0, -hy + 0.52, 0))
	var n := maxi(2, int(sz.x / 2.2))
	var arch_h := sz.z * 0.14
	for k in n + 1:
		var rx := -hx + k * sz.x / n
		for sd in [-1.0, 1.0]:
			_ibox(sb, Vector3(0.24, sz.y + 0.1, 0.2), 0.02, MR, Vector3(rx, 0.02, sd * (hz + 0.06)))
	# 拱形屋顶 + 屋顶中央通风天窗气楼 + 无动力涡轮排风球（俯视角清晰呈现厂房工业脊线）
	_imesh(sb, A.cyl(1.0, 1.0, 1.0, 38), A.corrugated(c.darkened(0.14), 0.52, 0.28), Vector3(0, hy, 0), Vector3(0, 0, 90), Vector3(arch_h, sz.x + 0.36, sz.z * 0.5 + 0.06))
	_ibox(sb, Vector3(sz.x * 0.76, 0.48, sz.z * 0.22), 0.03, MR, Vector3(0, hy + arch_h + 0.12, 0))
	_ibox(sb, Vector3(sz.x * 0.78, 0.12, sz.z * 0.26), 0.02, M_BASE, Vector3(0, hy + arch_h + 0.4, 0))
	for vx_k in [-0.24, 0.24]:
		_imesh(sb, A.cyl(0.24, 0.28, 0.18, 12), A.metal(Color(0.42, 0.43, 0.44)), Vector3(vx_k * sz.x, hy + arch_h + 0.56, 0), Vector3.ZERO, Vector3.ONE, false)
	# 装卸月台 + 凹陷波纹钢卷帘门 + 悬挑雨棚与斜拉杆 + 防撞黄黑护桩
	var dock_w := sz.x * 0.46
	var M_SHUT := A.corrugated(Color(0.20, 0.22, 0.24), 0.45, 0.42)
	var M_DARK_M := A.metal(Color(0.12, 0.13, 0.14))
	_ibox(sb, Vector3(dock_w * 0.76, sz.y * 0.64, 0.16), 0.02, M_DARK_M, Vector3(0, -hy + sz.y * 0.32, hz + 0.06), Vector3.ZERO, Vector3.ONE, false)
	for sl in 5:
		var sy_sl := -hy + sz.y * (0.12 + sl * 0.105)
		_ibox(sb, Vector3(dock_w * 0.70, sz.y * 0.085, 0.08), 0.01, M_SHUT, Vector3(0, sy_sl, hz + 0.12), Vector3.ZERO, Vector3.ONE, false)
	_ibox(sb, Vector3(dock_w, 0.88, 0.86), 0.04, A.concrete(Color(0.5, 0.48, 0.45), false), Vector3(0, -hy + 0.44, hz + 0.43))
	for bx_d in [-dock_w * 0.42, dock_w * 0.42]:
		_imesh(sb, A.cyl(0.10, 1.02, 0.10, 10), A.hazard(), Vector3(bx_d, -hy + 0.51, hz + 0.90), Vector3.ZERO, Vector3.ONE, false)
	_ibox(sb, Vector3(dock_w + 0.40, 0.16, 0.88), 0.02, MR, Vector3(0, -hy + sz.y * 0.68, hz + 0.42), Vector3(6, 0, 0))
	A.stencil(sb, "BLD-%02d" % rng.randi_range(1, 40), Vector3(-hx * 0.6, hy * 0.5, hz + 0.14), Vector3.ZERO, 0.02, Color(0.85, 0.82, 0.72, 0.6))

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

func _chimney(p: Vector3) -> void:
	var sb := _static_box(Vector3(3.2, 1.4, 3.2), p + Vector3(0, 0.7, 0), Color(0.45, 0.42, 0.4))
	var M := A.brick(Color(0.48, 0.31, 0.23), 0.26)
	var M_RING := A.metal(Color(0.26, 0.25, 0.24))
	A.add(sb, A.cyl(1.38, 1.8, 1.56, 36), A.concrete(Color(0.4, 0.38, 0.35), false), Vector3(0, 1.2, 0))
	A.add(sb, A.cyl(0.88, 22.0, 1.32, 36), M, Vector3(0, 11.2, 0))
	A.add(sb, A.cyl(1.02, 0.55, 0.92, 36), M_RING, Vector3(0, 22.1, 0))
	for k in 5:
		var y_band := 4.5 + k * 3.8
		var r_band := lerpf(1.32, 0.88, y_band / 22.0)
		A.add(sb, A.torus(r_band - 0.02, r_band + 0.09, 36), M_RING, Vector3(0, y_band, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	# 高空检修环廊平台
	A.add(sb, A.cyl(1.48, 0.12, 1.48, 36), M_RING, Vector3(0, 16.0, 0))
	A.add(sb, A.torus(1.42, 1.49, 36), M_RING, Vector3(0, 16.65, 0), Vector3.ZERO, Vector3(1, 0.45, 1), false)
	A.emitter(sb, Vector3(0, 22.5, 0), {"amount": 8, "life": 6.0, "size": 2.5, "tex": A.smoke_tex(), "additive": false, "vmin": 0.6, "vmax": 1.2,
		"gravity": Vector3(0.6, 0.4, 0.2), "c0": Color(0.15, 0.13, 0.12, 0.45), "c1": Color(0.3, 0.28, 0.26, 0.0), "grow0": 0.6, "grow1": 3.0})
	blocks.append(Rect2(p.x - 2, p.z - 2, 4, 4))

func _bunker(p: Vector3) -> void:
	# 钢筋混凝土永备机枪暗堡：收分抗弹堡体 + 阶梯式防跳弹射孔 + 重型防爆顶盖 + 蘑菇型装甲换气帽 + 沙袋胸墙
	var sz := Vector3(6.2, 2.7, 5.2)
	var M_CON := A.concrete(Color(0.46, 0.45, 0.41))
	var M_CAP := A.concrete(Color(0.38, 0.37, 0.34), false)
	var M_ST := A.metal(Color(0.16, 0.17, 0.18))
	var M_BAG := A.paint(Color(0.50, 0.45, 0.32), 0.0, 1.0, {"panel_scale": 0.0, "dust": 0.6})
	var sb := _bldg_body(sz, p + Vector3(0, sz.y * 0.5, 0))
	sb.rotation_degrees.y = rng.randf_range(-18.0, 18.0)
	A.add(sb, A.bevel_box(sz, 0.18, 0.90), M_CON, Vector3.ZERO)
	_ibox(sb, Vector3(sz.x + 0.5, 0.42, sz.z + 0.5), 0.05, M_CAP, Vector3(0, -sz.y * 0.5 + 0.21, 0))
	# 正面阶梯内凹射击孔与钢制护檐
	_ibox(sb, Vector3(4.2, 0.62, 0.28), 0.03, M_CAP, Vector3(0, 0.32, sz.z * 0.5 - 0.02))
	_ibox(sb, Vector3(3.6, 0.28, 0.26), 0.01, A.paint(Color(0.02, 0.02, 0.025), 0.0, 1.0), Vector3(0, 0.28, sz.z * 0.5 + 0.04), Vector3.ZERO, Vector3.ONE, false)
	_ibox(sb, Vector3(4.4, 0.14, 0.46), 0.02, M_ST, Vector3(0, 0.62, sz.z * 0.5 + 0.12))
	# 背侧凹陷防爆钢门
	_ibox(sb, Vector3(1.25, 1.85, 0.16), 0.02, M_ST, Vector3(0, -0.35, -sz.z * 0.5 - 0.02), Vector3.ZERO, Vector3.ONE, false)
	# 加厚防弹伞盖顶 + 装甲通风圆顶 + 顶部掩体沙袋群
	_ibox(sb, Vector3(sz.x + 0.68, 0.46, sz.z + 0.68), 0.08, M_CAP, Vector3(0, sz.y * 0.5 + 0.20, 0))
	_imesh(sb, A.cyl(0.46, 0.38, 0.52, 14), M_ST, Vector3(-1.4, sz.y * 0.5 + 0.52, -0.8))
	_imesh(sb, A.cyl(0.62, 0.14, 0.42, 14), M_ST, Vector3(-1.4, sz.y * 0.5 + 0.74, -0.8), Vector3.ZERO, Vector3.ONE, false)
	for k in 4:
		_ibox(sb, Vector3(1.28, 0.38, 0.65), 0.10, M_BAG, Vector3(-1.95 + k * 1.3, sz.y * 0.5 + 0.56, sz.z * 0.5 - 0.35), Vector3(0, rng.randf_range(-5, 5), 0))
	blocks.append(_rect_for(p, sz + Vector3(2, 0, 2)))

func _watchtower(p: Vector3) -> void:
	# 重工钢桁架哨戒瞭望塔：四足混凝土独立基础 + 三层交叉斜撑钢架 + 外挑走道护栏 + 坡顶波纹板岗亭 + 爬梯与探照灯
	var sb := _static_box(Vector3(2.4, 1.2, 2.4), p + Vector3(0, 6.2, 0), Color(0.38, 0.36, 0.31), null, A.corrugated(Color(0.36, 0.35, 0.30), 0.48, 0.34))
	var M := A.metal(Color(0.24, 0.25, 0.25))
	var M_DARK := A.metal(Color(0.14, 0.15, 0.16))
	var M_CON := A.concrete(Color(0.46, 0.44, 0.41), false)
	var M_WIN_WT := A.window_mat(0.24, Vector2(0.65, 0.42))
	# 外挑钢格栅巡逻平台与四周栏杆
	A.add(sb, A.bevel_box(Vector3(3.25, 0.14, 3.25), 0.03), M_DARK, Vector3(0, -0.64, 0))
	for sd_r in [-1.54, 1.54]:
		A.add(sb, A.bevel_box(Vector3(3.16, 0.06, 0.06), 0.01), M, Vector3(0, 0.28, sd_r), Vector3.ZERO, Vector3.ONE, false)
		A.add(sb, A.bevel_box(Vector3(0.06, 0.06, 3.16), 0.01), M, Vector3(sd_r, 0.28, 0), Vector3.ZERO, Vector3.ONE, false)
	# 岗亭四面深凹观察窗带 + 斜坡防雨铁皮顶 + 转角探照灯头
	for f_sd in [-1.0, 1.0]:
		A.add(sb, A.bevel_box(Vector3(1.95, 0.42, 0.08), 0.01), M_WIN_WT, Vector3(0, 0.86, f_sd * 1.18), Vector3.ZERO, Vector3.ONE, false)
		A.add(sb, A.bevel_box(Vector3(0.08, 0.42, 1.95), 0.01), M_WIN_WT, Vector3(f_sd * 1.18, 0.86, 0), Vector3.ZERO, Vector3.ONE, false)
	for lx in [-1.14, 1.14]:
		for lz in [-1.14, 1.14]:
			A.add(sb, A.cyl(0.055, 1.12, 0.055, 8), M, Vector3(lx, 1.08, lz))
	A.add(sb, A.bevel_box(Vector3(3.1, 0.14, 3.1), 0.03), A.roof_mat(Color(0.28, 0.27, 0.24), 0.62, true), Vector3(0, 1.66, 0), Vector3(4, 0, 2))
	A.add(sb, A.cyl(0.16, 0.24, 0.14, 10), M_DARK, Vector3(1.38, 0.56, 1.38), Vector3(24, 45, 0))
	# 下部四根收分角钢主腿 + 混凝土杯口基础 + 三层横撑与十字斜撑 + 侧面检修爬梯
	for lx in [-1.0, 1.0]:
		for lz in [-1.0, 1.0]:
			var b_pt := Vector3(lx * 1.32, -6.2, lz * 1.32)
			var t_pt := Vector3(lx * 1.02, -0.68, lz * 1.02)
			A.add(sb, A.bevel_box(Vector3(0.52, 0.30, 0.52), 0.03), M_CON, b_pt + Vector3(0, 0.15, 0))
			A.add(sb, A.tube([b_pt + Vector3(0, 0.2, 0), t_pt], 0.085, 8, 2), M, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	for tier in 3:
		var u0 := float(tier) / 3.0
		var u1 := float(tier + 1) / 3.0
		var y0 := lerpf(-5.95, -0.72, u0)
		var y1 := lerpf(-5.95, -0.72, u1)
		var r0 := lerpf(1.30, 1.02, u0)
		var r1 := lerpf(1.30, 1.02, u1)
		for sd_i in 4:
			var a0 := Vector3(-r0, y0, -r0).rotated(Vector3.UP, PI * 0.5 * sd_i)
			var b0 := Vector3(r0, y0, -r0).rotated(Vector3.UP, PI * 0.5 * sd_i)
			var a1 := Vector3(-r1, y1, -r1).rotated(Vector3.UP, PI * 0.5 * sd_i)
			var b1 := Vector3(r1, y1, -r1).rotated(Vector3.UP, PI * 0.5 * sd_i)
			A.add(sb, A.tube([a0, b0], 0.048, 6, 2), M, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			A.add(sb, A.tube([a0, b1], 0.040, 6, 2), M_DARK, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			A.add(sb, A.tube([b0, a1], 0.040, 6, 2), M_DARK, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(sb, A.bevel_box(Vector3(0.46, 5.75, 0.10), 0.01), M_DARK, Vector3(0, -3.3, -1.24), Vector3(-3, 0, 0))
	# 立柱碰撞
	var col := StaticBody3D.new()
	col.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.2, 5.0, 2.2)
	cs.shape = sh
	cs.position.y = 2.5
	col.add_child(cs)
	world.add_child(col)
	col.position = p
	blocks.append(Rect2(p.x - 1.5, p.z - 1.5, 3, 3))

func _sandbags(p: Vector3, rot: float) -> void:
	var M := A.paint(Color(0.5, 0.45, 0.32), 0.0, 1.0, {"panel_scale": 0.0, "dust": 0.6, "wear": 0.2})
	var sb := _static_box(Vector3(4.0, 1.2, 0.9), p + Vector3(0, 0.6, 0), Color.WHITE, null, M)
	sb.rotation_degrees.y = rot
	for row in 3:
		for k in 5:
			A.add(sb, A.bevel_box(Vector3(0.85, 0.36, 0.55), 0.15), M, Vector3(-1.7 + k * 0.85 + (0.42 if row % 2 else 0.0), -0.42 + row * 0.38, rng.randf_range(-0.08, 0.08)), Vector3(0, rng.randf_range(-6, 6), 0))
	blocks.append(_rect_for(p, Vector3(4.4, 1, 4.4)))

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

func _dead_tree(p: Vector3) -> void:
	var n := Node3D.new()
	world.add_child(n)
	n.position = p
	var M := A.bark_mat(Color(0.28, 0.24, 0.19))
	var h := rng.randf_range(3.8, 6.2)
	var v_t := rng.randi() % 3
	A.add(n, A.tree_trunk_mesh(v_t, true), M, Vector3.ZERO, Vector3(rng.randf_range(-3.0, 3.0), rng.randf() * 360.0, rng.randf_range(-3.0, 3.0)), Vector3(h * 0.24, h, h * 0.24))
	for k in 3:
		var ba := TAU * float(k) / 3.0 + rng.randf_range(-0.4, 0.4)
		var u_b := rng.randf_range(0.45, 0.78)
		var b0 := Vector3(0, h * u_b, 0)
		var reach := h * rng.randf_range(0.24, 0.38)
		var b_mid := b0 + Vector3(cos(ba) * reach * 0.55, reach * 0.28, sin(ba) * reach * 0.55)
		var b_tip := b0 + Vector3(cos(ba) * reach, reach * rng.randf_range(0.55, 0.85), sin(ba) * reach)
		A.add(n, A.tube([b0, b_mid, b_tip], 0.036, 6, 3), M, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)

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
func _bake_static(drop: Vector3) -> void:
	_flush_inst()
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
						or (mo is BaseMaterial3D and (mo as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED) \
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
	print("[raid] batched %d static meshes + %d instances into %d chunks (%d built)" % [removed, rb.stats.inst, rb._chunks.size(), rb.stats.built])


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
