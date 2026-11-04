extends Node3D
## 一局行动：空投 → 搜刮 → 在能源耗尽前撤离（固定撤离点 / 呼叫运输机）。

signal raid_ended(result: Dictionary)

const MechScript = preload("res://scripts/mech.gd")
const BugScript = preload("res://scripts/bug.gd")
const NestScript = preload("res://scripts/nest.gd")
const ProjScript = preload("res://scripts/projectile.gd")
const LootScript = preload("res://scripts/loot_box.gd")
const ExtractScript = preload("res://scripts/extract_zone.gd")
const HudScript = preload("res://scripts/hud.gd")
const MV = preload("res://scripts/mech_visual.gd")
const A = preload("res://scripts/art.gd")

const HALF := 180.0
const MAX_BUGS := 170          ## 全场虫数上限（Boss 不占名额）
const INITIAL_BUGS := 150      ## 开局铺虫的上限：给 Boss 召唤与虫潮留出余量
const BUG_DENSITY := 1.3       ## 分布表虫群密度的整体倍率（v0.6 起虫群数量约为原来的 2.5 倍）
const FactionsScript = preload("res://scripts/factions/factions.gd")
const WorldLinkScript = preload("res://scripts/world_link.gd")
const CAM_OFFSET := Vector3(0, 43, 22)  # 2.5D 斜俯视（约 63°）
const ZOOM_MIN := 0.5   ## 滚轮拉到最近（看机甲细节）
const ZOOM_MAX := 1.3   ## 滚轮拉到最远：能看到的地图最多，也是默认视距（玩家视野与敌人视野都按这一档推算）

var rng := RandomNumberGenerator.new()
var mech
var camera: Camera3D
var cam_zoom := ZOOM_MAX  # 鼠标滚轮缩放：默认最远一档（ZOOM_MAX），可滚轮拉近到 ZOOM_MIN
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


func start(lo: Dictionary, carry: Array, transit_state := {}) -> void:
	rng.randomize()
	transit = transit_state
	loadout = lo.duplicate()
	start_cargo = carry.duplicate()
	world = Node3D.new()
	add_child(world)
	fx = Node3D.new()
	add_child(fx)
	map_id = GameData.map_id
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
	_spawn_initial_bugs(drop)
	_tmark("extracts+bugs")
	_bake_static()
	_tmark("bake")
	rebuild_nav()   # 导航网格：所有静态几何体都建好之后栅格化（碰撞后处理改动布局后会再调一次）
	_tmark("nav")
	print("[raid] map build %s: %d ms, world nodes %d, blocks %d" % [map_id, (Time.get_ticks_usec() - t_build) / 1000, _count_nodes(world), blocks.size()])
	print("[raid]   phases: %s" % ", ".join(_tphase.keys().map(func(k): return "%s %d" % [k, _tphase[k]])))

	mech = MechScript.new()
	mech.raid = self
	add_child(mech)
	mech.setup(loadout, carry)
	mech.global_position = drop + Vector3(0, 30, 0)
	mech.input_locked = true
	mech.died.connect(_on_mech_died)
	mech.message.connect(func(t): hud.msg(t))

	camera = Camera3D.new()
	camera.fov = 36.0
	camera.far = 300.0
	add_child(camera)
	camera.current = true
	_apply_style.call_deferred()
	camera.global_position = drop + CAM_OFFSET * cam_zoom
	camera.look_at(drop, Vector3.UP)
	# 3D 音效的收听点：放在机甲上方、朝向与镜头一致（镜头离地 40 多米，直接用镜头收听会让近处的声音太小）
	listener = AudioListener3D.new()
	add_child(listener)
	listener.make_current()

	ash = A.emitter(self, Vector3.ZERO, {"amount": 160, "life": 6.0, "size": 0.08, "box": Vector3(30, 6, 22), "dir": Vector3(1, -0.3, 0.2),
		"spread": 30.0, "vmin": 0.6, "vmax": 1.4, "gravity": Vector3(0.3, -0.2, 0.1), "c0": Color(0.8, 0.78, 0.7, 0.0), "cmid": Color(0.85, 0.82, 0.74, 0.55),
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
	if transit.is_empty():
		visited_maps = [map_id]
		_drop_sequence(drop)
	else:
		world_link.arrive(transit, drop)


## 行动扩展（GameData.RAID_SCRIPTS，来自 data\ext 各文件）。每个脚本可写两部分，都可省略：
##   static func build(raid, drop: Vector3)  地形、遗迹建完之后、撤离点与虫群生成之前调用，用来摆地标与布景
##     （新建的静态网格挂在 raid.world 下，会和其余布景一起合批；可在 raid.blocks 里登记占地 Rect2 让后续摆放避让）
##   继承 Node 的脚本：机甲与 HUD 就绪后实例化为本节点的子节点，有 setup(raid) 时先调用它；
##     行动结束时随行动场景一起释放（天气、动态事件、局内通讯小窗等持续逻辑写在这里）
func _run_ext_build(drop: Vector3) -> void:
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
		var s: Script = load(str(path))
		if s == null or not s.can_instantiate() or not ClassDB.is_parent_class(s.get_instance_base_type(), "Node"):
			continue
		var n: Node = s.new()
		n.name = "ext_" + str(path).get_file().get_basename()
		if n.has_method("setup"):
			n.call("setup", self)
		add_child(n)


## 空投：高空坠落（尾焰 + 拖烟）→ 反推减速（地面扬尘）→ 重落地（冲击波尘环、碎石、弹坑）→ 下蹲缓冲后起身排气
func _drop_sequence(drop: Vector3) -> void:
	mech.global_position = drop + Vector3(0, 30, 0)
	var flames: Array = []
	for x in [-0.55, 0.55]:
		var f := A.emitter(mech, Vector3(x, 0.4, 0.2), {"amount": 36, "life": 0.22, "size": 1.3, "dir": Vector3.DOWN, "spread": 10.0, "vmin": 9.0, "vmax": 14.0,
			"gravity": Vector3.ZERO, "local": true, "c0": Color(1.0, 0.95, 0.8), "cmid": Color(1.0, 0.6, 0.2, 0.9), "c1": Color(0.8, 0.2, 0.05, 0.0), "grow0": 0.5, "grow1": 1.4})
		flames.append(f)
	var trail := A.emitter(mech, Vector3(0, 0.6, 0), {"amount": 40, "life": 1.6, "size": 3.0, "tex": A.smoke_tex(), "additive": false, "spread": 180.0, "vmin": 0.3, "vmax": 1.0,
		"gravity": Vector3(0, 0.8, 0), "c0": Color(0.35, 0.33, 0.31, 0.95), "c1": Color(0.45, 0.43, 0.4, 0.0), "grow0": 0.5, "grow1": 2.2})
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
		var ground_dust := A.emitter(world, Vector3(drop.x, 0.3, drop.z), {"amount": 50, "life": 1.3, "size": 4.5, "tex": A.smoke_tex(), "additive": false,
			"dir": Vector3(1, 0.12, 0), "spread": 180.0, "vmin": 6.0, "vmax": 11.0, "gravity": Vector3(0, 0.6, 0), "box": Vector3(1.5, 0.1, 1.5),
			"c0": Color(0.85, 0.78, 0.66, 0.0), "cmid": Color(0.85, 0.78, 0.66, 0.95), "c1": Color(0.8, 0.74, 0.64, 0.0), "grow0": 0.5, "grow1": 2.0})
		ground_dust.flatness = 0.85
		ground_dust.damping_min = 4.0
		ground_dust.damping_max = 6.0
		hold["dust"] = ground_dust)
	tw.tween_property(mech, "global_position", drop + Vector3(0, 0.2, 0), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
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
	Events.drop_landed.emit(p)
	_flash_light(p + Vector3(0, 1.0, 0), Color(1.0, 0.7, 0.4), 6.0, 14.0, 0.25)
	# 贴地扩散的冲击尘环
	var ring := A.burst(fx, p + Vector3(0, 0.4, 0), {"amount": 48, "life": 2.0, "size": 5.0, "tex": A.smoke_tex(), "additive": false, "dir": Vector3(1, 0, 0), "spread": 180.0,
		"vmin": 12.0, "vmax": 20.0, "gravity": Vector3(0, 0.5, 0), "damp": 9.0, "radius": 1.2, "c0": Color(0.86, 0.8, 0.68, 1.0), "c1": Color(0.8, 0.74, 0.64, 0.0), "grow0": 0.6, "grow1": 2.2})
	ring.flatness = 1.0
	# 冲天的尘柱
	A.burst(fx, p + Vector3(0, 0.8, 0), {"amount": 14, "life": 2.6, "size": 6.0, "tex": A.smoke_tex(), "additive": false, "dir": Vector3.UP, "spread": 35.0,
		"vmin": 2.0, "vmax": 5.5, "gravity": Vector3(0, 0.3, 0), "damp": 1.5, "radius": 1.5, "explosive": 0.8, "c0": Color(0.78, 0.72, 0.62, 0.95), "c1": Color(0.7, 0.65, 0.58, 0.0), "grow0": 0.5, "grow1": 2.0})
	# 飞溅碎石
	A.burst(fx, p + Vector3(0, 0.4, 0), {"amount": 30, "life": 1.2, "size": 0.4, "additive": false, "tex": A.blob_tex(), "dir": Vector3.UP, "spread": 60.0, "vmin": 6.0, "vmax": 13.0,
		"gravity": Vector3(0, -26, 0), "damp": 0.4, "radius": 1.0, "c0": Color(0.32, 0.3, 0.27), "c1": Color(0.3, 0.28, 0.25, 0.9), "grow0": 1.0, "grow1": 1.0})
	# 火星
	A.burst(fx, p + Vector3(0, 0.3, 0), {"amount": 20, "life": 0.5, "size": 0.1, "vmin": 6.0, "vmax": 14.0, "gravity": Vector3(0, -18, 0), "damp": 1.0,
		"c0": Color(1.0, 0.9, 0.6), "c1": Color(1.0, 0.35, 0.0, 0.0), "grow0": 1.0, "grow1": 0.2})
	# 弹坑 + 扩散冲击波
	var crater := A.ground_decal(world, A.blob_tex(), Color(0.06, 0.05, 0.05, 0.75), 7.0, Vector3(p.x, 0.03, p.z))
	crater.rotation.y = randf() * TAU
	var wave := A.ground_decal(fx, A.ring_tex(), Color(1.0, 0.95, 0.85, 0.9), 3.0, Vector3(p.x, 0.06, p.z))
	var wm: StandardMaterial3D = wave.material_override.duplicate()
	wave.material_override = wm
	var tw := create_tween()
	tw.tween_property(wave, "scale", Vector3(8, 1, 8), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(wm, "albedo_color:a", 0.0, 0.45)
	tw.tween_callback(wave.queue_free)
	# 起身时背部排气
	var steam: Array = []
	for x in [-0.5, 0.5]:
		steam.append(A.emitter(mech, Vector3(x, 2.4, 0.6), {"amount": 28, "life": 1.2, "size": 1.6, "tex": A.smoke_tex(), "additive": false, "dir": Vector3(0, 1, 0.4),
			"spread": 15.0, "vmin": 3.0, "vmax": 5.0, "gravity": Vector3(0, 1.0, 0), "c0": Color(0.95, 0.95, 0.95, 0.6), "c1": Color(0.9, 0.9, 0.9, 0.0), "grow0": 0.3, "grow1": 2.0}))
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
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.ambient_light_sky_contribution = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.tonemap_white = 8.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(1, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(5, 0.6)
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.ssil_enabled = false
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.15
	env.fog_enabled = true
	env.fog_light_color = Color(0.52, 0.5, 0.44)
	env.fog_density = 0.004
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = false
	env.volumetric_fog_density = 0.008
	env.volumetric_fog_albedo = Color(0.82, 0.8, 0.74)
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_length = 80.0
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.14
	env.adjustment_saturation = 0.8  # 低饱和战场色调，只让特效跳出来
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 35, 0)
	sun.light_color = Color(1.0, 0.9, 0.76)
	sun.light_energy = 1.9
	sun.light_angular_distance = 0.6  # 软阴影：近实远虚（PCSS）
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.light_volumetric_fog_energy = 1.4
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-50, -140, 0)
	fill.light_color = Color(0.6, 0.62, 0.66)
	fill.light_energy = 0.45
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


func _multimesh(mesh: Mesh, m: Material, xforms: Array, shadow := true) -> void:
	# 按 60m 分块，保证视锥裁剪有效（大地图性能）
	var buckets := {}
	for t: Transform3D in xforms:
		var key := Vector2i(floori(t.origin.x / 60.0), floori(t.origin.z / 60.0))
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(t)
	for key in buckets:
		_multimesh_one(mesh, m, buckets[key], shadow)


func _multimesh_one(mesh: Mesh, m: Material, xforms: Array, shadow := true) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	if not shadow:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mmi)


func _rand_basis(tilt := 25.0) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(rng.randf_range(-tilt, tilt)), rng.randf() * TAU, deg_to_rad(rng.randf_range(-tilt, tilt))))


func _add_flicker(l: OmniLight3D) -> void:
	flicker_lights.append([l, l.light_energy, rng.randf() * 100.0])


func _fire_barrel(p: Vector3) -> void:
	var n := Node3D.new()
	world.add_child(n)
	n.position = p
	A.add(n, A.cyl(0.35, 0.9, 0.35, 14), A.paint(Color(0.35, 0.2, 0.12), 0.4, 0.7), Vector3(0, 0.45, 0))
	A.add(n, A.cyl(0.37, 0.06, 0.37, 14), A.metal(), Vector3(0, 0.25, 0))
	A.add(n, A.cyl(0.37, 0.06, 0.37, 14), A.metal(), Vector3(0, 0.7, 0))
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
	# 地面：一整块带三平面噪声的沙土
	var g := StaticBody3D.new()
	g.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(HALF * 2 + 60, 1.0, HALF * 2 + 60)
	cs.shape = sh
	cs.position.y = -0.5
	g.add_child(cs)
	var pm := PlaneMesh.new()
	pm.size = Vector2(HALF * 2 + 120, HALF * 2 + 120)
	A.add(g, pm, A.ground(), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	world.add_child(g)

	# 焦痕 / 湿痕：柔边贴花
	for i in 360:
		var p := Vector3(rng.randf_range(-HALF, HALF), 0.015 + (i % 60) * 0.0002, rng.randf_range(-HALF, HALF))
		var d := A.ground_decal(world, A.blob_tex(), Color(1, 1, 1, rng.randf_range(0.25, 0.6)), rng.randf_range(3.0, 10.0), p)
		d.rotation.y = rng.randf() * TAU
		d.scale = Vector3(1.0, 1.0, rng.randf_range(0.5, 1.0))

	# 虫族菌毯：几块不规则的暗色生物膜
	for i in 30:
		var c := Vector3(rng.randf_range(-HALF + 5, HALF - 5), 0, rng.randf_range(-HALF + 5, HALF - 5))
		for k in rng.randi_range(3, 6):
			var r := rng.randf_range(1.6, 4.0)
			var p := c + Vector3(rng.randf_range(-4, 4), 0.02 + k * 0.003, rng.randf_range(-4, 4))
			var cd := A.ground_decal(world, A.cloud_tex(), Color(0.16, 0.11, 0.07, 0.32), r * 2.4, p)
			cd.rotation.y = rng.randf() * TAU
			cd.scale = Vector3(1.0, 1.0, rng.randf_range(0.6, 1.0))

	# 碎石、钢筋：MultiMesh 批量绘制
	var rocks: Array = []
	for i in 3200:
		var p := Vector3(rng.randf_range(-HALF, HALF), 0, rng.randf_range(-HALF, HALF))
		if in_wet(Vector2(p.x, p.z), 0.5):
			continue
		var sc := rng.randf_range(0.15, 0.6)
		var t := Transform3D(_rand_basis(35).scaled(Vector3(sc * rng.randf_range(0.7, 1.6), sc * rng.randf_range(0.5, 1.0), sc)), p + Vector3(0, sc * 0.15, 0))
		rocks.append(t)
	_multimesh(A.bevel_box(Vector3.ONE, 0.12), A.concrete(Color(0.55, 0.5, 0.46), false), rocks)
	var rebars: Array = []
	for i in 700:
		var p := Vector3(rng.randf_range(-HALF, HALF), 0.4, rng.randf_range(-HALF, HALF))
		rebars.append(Transform3D(_rand_basis(55).scaled(Vector3(1, rng.randf_range(0.6, 1.6), 1)), p))
	_multimesh(A.cyl(0.03, 1.2, 0.03, 5), A.paint(Color(0.35, 0.18, 0.1), 0.5, 0.8), rebars, false)

	# 枯草丛：成簇分布的细长草叶（MultiMesh，不投影）
	var GRASS := StandardMaterial3D.new()
	GRASS.albedo_color = Color(0.48, 0.46, 0.28)
	GRASS.roughness = 1.0
	GRASS.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tufts: Array = []
	for c in 520:
		var cc := Vector3(rng.randf_range(-HALF, HALF), 0, rng.randf_range(-HALF, HALF))
		var zt := zone_at(cc)
		if zt in ["D", "I", "Y", "H", "K", "S"] or (zt == "R" and rng.randf() < 0.5) or in_wet(Vector2(cc.x, cc.z), 3.0) or on_road(Vector2(cc.x, cc.z)):
			continue
		var cr := rng.randf_range(1.5, 5.0) * (1.6 if zt == "P" or zt == "T" else 1.0)
		for k in rng.randi_range(10, 30):
			var a := rng.randf() * TAU
			var rr := sqrt(rng.randf()) * cr
			var p := cc + Vector3(cos(a) * rr, 0, sin(a) * rr)
			for blade in 5:
				var hgt := rng.randf_range(0.25, 0.6)
				var bs := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-35, 35)))
				tufts.append(Transform3D(bs.scaled(Vector3(1, hgt, 1)), p + Vector3(rng.randf_range(-0.12, 0.12), hgt * 0.5, rng.randf_range(-0.12, 0.12))))
	_multimesh(A.cyl(0.0, 1.0, 0.035, 3), GRASS, tufts, false)
	# 小碎石：大量细碎石子
	var pebbles: Array = []
	for i in 9000:
		var p := Vector3(rng.randf_range(-HALF, HALF), 0, rng.randf_range(-HALF, HALF))
		if in_wet(Vector2(p.x, p.z), 0.5):
			continue
		var sc := rng.randf_range(0.05, 0.16)
		pebbles.append(Transform3D(_rand_basis(60).scaled(Vector3(sc * rng.randf_range(0.8, 1.5), sc * 0.6, sc)), p + Vector3(0, sc * 0.2, 0)))
	_multimesh(A.sphere(0.5, -1, 6), A.concrete(Color(0.5, 0.46, 0.4), false), pebbles, false)

	# 边界：碎裂的高墙与岩柱
	for side in 4:
		var horiz := side < 2
		var sgn := -1.0 if side % 2 == 0 else 1.0
		var x := -HALF - 4.0
		while x < HALF + 4.0:
			var w := rng.randf_range(4.0, 9.0)
			var h := rng.randf_range(7.0, 14.0)
			var d := rng.randf_range(4.0, 7.0)
			var center := x + w * 0.5
			var pos := Vector3(center, h * 0.5, sgn * (HALF + 2 + d * 0.5 - 2)) if horiz else Vector3(sgn * (HALF + 2 + d * 0.5 - 2), h * 0.5, center)
			var size := Vector3(w, h, d) if horiz else Vector3(d, h, w)
			var sb := _static_box(size, pos, Color(0.42, 0.36, 0.34).lerp(Color(0.3, 0.25, 0.26), rng.randf()))
			sb.rotation_degrees.y = rng.randf_range(-4, 4)
			x += w * 0.85


func _bug_spire(p: Vector3, h: float) -> void:
	var n := Node3D.new()
	world.add_child(n)
	n.position = p
	n.rotation_degrees = Vector3(rng.randf_range(-10, 10), rng.randf() * 360.0, rng.randf_range(-10, 10))
	var r0 := rng.randf_range(0.5, 1.0)
	var segs := 4
	var y := 0.0
	for i in segs:
		var sh := h / segs
		var ra: float = r0 * (1.0 - float(i) / segs)
		var rb: float = r0 * (1.0 - float(i + 1) / segs)
		A.add(n, A.cyl(rb, sh, ra, 7), A.chitin(Color(0.22, 0.15, 0.1)), Vector3(0, y + sh * 0.5, 0), Vector3(0, i * 20.0, 0))
		if i < segs - 1:
			A.add(n, A.torus(rb * 0.9, rb * 1.15, 10), A.emit(Color(1.0, 0.45, 0.12), 1.2), Vector3(0, y + sh, 0), Vector3.ZERO, Vector3(1, 0.5, 1), false)
		y += sh
	A.ground_decal(n, A.cloud_tex(), Color(0.12, 0.09, 0.05, 0.7), r0 * 3.2, Vector3(0, 0.03, 0))
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
	if terrain:
		var q := Vector2(p.x, p.z)
		if on_road(q, r - 0.5) or in_river(q, r + 2.0):
			return true
	return false


func _free_spot(r: float, margin := 6.0) -> Vector3:
	for i in 200:
		var p := Vector3(rng.randf_range(-HALF + margin, HALF - margin), 0, rng.randf_range(-HALF + margin, HALF - margin))
		if not _blocked(p, r):
			return p
	return Vector3.ZERO


func _poi_lamp(p: Vector3, c := Color(1.0, 0.8, 0.5)) -> void:
	var n := Node3D.new()
	world.add_child(n)
	n.position = p
	A.add(n, A.cyl(0.08, 4.0, 0.12, 8), A.metal(Color(0.25, 0.25, 0.27)), Vector3(0, 2.0, 0))
	A.add(n, A.bevel_box(Vector3(0.9, 0.12, 0.3), 0.03), A.metal(), Vector3(0.35, 4.0, 0))
	A.add(n, A.bevel_box(Vector3(0.5, 0.05, 0.22), 0.01), A.emit(c, 5.0), Vector3(0.5, 3.93, 0), Vector3.ZERO, Vector3.ONE, false)
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 2.2
	l.omni_range = 11.0
	l.position = Vector3(0.5, 3.6, 0)
	n.add_child(l)
	_add_flicker(l)


func _container(p: Vector3, rot: float, c: Color) -> void:
	var sb := _static_box(Vector3(2.4, 2.4, 6.0), p + Vector3(0, 1.2, 0), c, null, A.paint(c, 0.3, 0.7))
	sb.rotation_degrees.y = rot
	for i in 9:
		A.add(sb, A.bevel_box(Vector3(2.46, 2.2, 0.12), 0.03), A.paint(c.darkened(0.15), 0.3, 0.7), Vector3(0, 0, -2.6 + i * 0.65))
	A.add(sb, A.bevel_box(Vector3(2.5, 0.3, 6.04), 0.04), A.hazard(), Vector3(0, -1.0, 0))


## 遗迹 POI：类型来自 GameData.POIS（核心三类 + 扩展）。核心类型与 compound = true 的扩展类型建标准围墙院落；
## 扩展类型的 script 负责中央布景（compound = false 时整个 POI 由它负责）。
func _build_pois() -> void:
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
		# 四面墙，每面留缺口；墙顶参差不齐
		for side in 4:
			for half in [-1, 1]:
				var seg := 3.6
				var off: float = half * (s - seg * 0.5)
				var hgt := rng.randf_range(2.4, 3.6)
				var size: Vector3
				var pos: Vector3
				match side:
					0: size = Vector3(seg * 2, hgt, 0.8); pos = Vector3(off * 0.62, hgt * 0.5, -s)
					1: size = Vector3(seg * 2, hgt, 0.8); pos = Vector3(off * 0.62, hgt * 0.5, s)
					2: size = Vector3(0.8, hgt, seg * 2); pos = Vector3(-s, hgt * 0.5, off * 0.62)
					3: size = Vector3(0.8, hgt, seg * 2); pos = Vector3(s, hgt * 0.5, off * 0.62)
				var wall := _static_box(size, c + pos, wall_c.darkened(rng.randf() * 0.2))
				# 墙头残块
				for k in 2:
					var chunk := Vector3(rng.randf_range(0.8, 2.0), rng.randf_range(0.4, 1.2), 0.82)
					if side >= 2:
						chunk = Vector3(0.82, chunk.y, chunk.x)
					var cp := Vector3(rng.randf_range(-2, 2), hgt * 0.5 + chunk.y * 0.5, 0) if side < 2 else Vector3(0, hgt * 0.5 + chunk.y * 0.5, rng.randf_range(-2, 2))
					A.add(wall, A.bevel_box(chunk, 0.08), A.concrete(wall_c.darkened(0.1)), cp)
				A.add(wall, A.bevel_box(Vector3(size.x + 0.04, 0.25, size.z + 0.04), 0.04), A.concrete(wall_c.darkened(0.35)), Vector3(0, -hgt * 0.5 + 0.4, 0))
				blocks.append(_rect_for(c + pos, size))
		blocks.append(Rect2(c.x - s + 1, c.z - s + 1, s * 2 - 2, s * 2 - 2))
		if pscript != "":
			load(pscript).build(self, c, pid)
		elif pid == "egret_wreck":
			_crashed_ship(c)
		elif pid == "depot7":
			_container(c + Vector3(-3.5, 0, 2.5), 90, Color(0.25, 0.38, 0.5))
			_container(c + Vector3(-3.2, 2.4, 2.4), 84, Color(0.62, 0.3, 0.18))
			blocks.append(Rect2(c.x - 6.5, c.z + 1.2, 6.5, 2.6))
		else:
			# 研究所：破损穹顶 + 天线
			var dome := StaticBody3D.new()
			var dcs := CollisionShape3D.new()
			var dsh := CylinderShape3D.new()
			dsh.radius = 2.6
			dsh.height = 3.0
			dcs.shape = dsh
			dcs.position.y = 1.5
			dome.add_child(dcs)
			world.add_child(dome)
			dome.position = c + Vector3(-3, 0, 3)
			A.add(dome, A.cyl(2.7, 1.4, 2.8, 24), A.concrete(Color(0.5, 0.5, 0.48)), Vector3(0, 0.7, 0))
			A.add(dome, A.sphere(2.6, 2.6, 32), A.paint(Color(0.58, 0.6, 0.6), 0.3, 0.5, {"panel_scale": 0.45, "wear": 0.5, "rust": 0.6, "dust": 0.35}), Vector3(0, 1.4, 0), Vector3(12, 0, 8))
			A.add(dome, A.cyl(0.06, 5.0, 0.1, 6), A.metal(), Vector3(1.2, 4.0, -0.5), Vector3(0, 0, -10))
			A.add(dome, A.sphere(0.12), A.emit(Color(1, 0.2, 0.15), 6.0), Vector3(1.6, 6.4, -0.5), Vector3.ZERO, Vector3.ONE, false)
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
	var hull := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(4.5, 3.0, 10.0)
	cs.shape = sh
	cs.position.y = 1.4
	hull.add_child(cs)
	world.add_child(hull)
	hull.position = c + Vector3(-1, 0, 1)
	hull.rotation_degrees = Vector3(0, 25, 0)
	var body := Node3D.new()
	body.rotation_degrees = Vector3(4, 0, 10)
	body.position.y = 1.2
	hull.add_child(body)
	var M := A.paint(Color(0.82, 0.8, 0.74), 0.35, 0.5)
	A.add(body, A.capsule(1.8, 9.5), M, Vector3.ZERO, Vector3(90, 0, 0), Vector3(1.1, 1.0, 0.85))
	A.add(body, A.bevel_box(Vector3(1.6, 0.6, 1.8), 0.15, 0.7), A.glass(Color(0.3, 0.7, 0.9)), Vector3(0, 1.1, -3.6))
	A.add(body, A.bevel_box(Vector3(9.0, 0.25, 2.4), 0.08, 1.0), A.paint(Color(0.7, 0.68, 0.62), 0.35, 0.55), Vector3(-1.5, -0.2, 0.5), Vector3(0, 0, -14))
	A.add(body, A.bevel_box(Vector3(0.25, 2.6, 2.0), 0.08, 0.6), M, Vector3(0, 1.8, 4.0), Vector3(-20, 0, 0))
	A.add(body, A.bevel_box(Vector3(3.6, 0.35, 0.9), 0.05), A.hazard(), Vector3(0, 1.5, -1.5))
	A.add(body, A.bevel_box(Vector3(2.0, 1.8, 0.2), 0.05), A.metal(Color(0.08, 0.08, 0.08)), Vector3(1.8, 0.2, 1.0), Vector3(0, 90, 0))
	for z in [-1.0, 2.0]:
		A.add(body, A.cyl(0.8, 1.8, 0.7, 14), A.metal(), Vector3(2.6, -0.2, z), Vector3(90, 0, 0))
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
	# 废弃城区楼房：暖灰混凝土外墙 + 深色勒脚 + 转角壁柱 + 窗框窗台 + 带女儿墙的沥青屋顶 + 屋顶设备
	# 外墙色取 4 档（材质能在全图共用，细部零件才合得成少量 MultiMesh）
	var c := Color(0.5, 0.46, 0.4).lerp(Color(0.42, 0.38, 0.33), rng.randi_range(0, 3) / 3.0)
	if rng.randf() < 0.3:
		c = Color(0.46, 0.4, 0.33)  # 少数砖黄色楼
	var sb := _bldg_body(size, p + Vector3(0, size.y * 0.5, 0))
	sb.rotation.y = -yaw
	_ibox(sb, size, 0.01, A.concrete(c))
	var hy := size.y * 0.5
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var M_DARK := A.concrete(c.darkened(0.35), false)
	var M_TRIM := A.concrete(c.lightened(0.08), false)
	# 勒脚
	_ibox(sb, Vector3(size.x + 0.12, 0.55, size.z + 0.12), 0.03, M_DARK, Vector3(0, -hy + 0.27, 0))
	# 转角壁柱
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_ibox(sb, Vector3(0.34, size.y + 0.02, 0.34), 0.04, M_TRIM, Vector3(sx * (hx - 0.1), 0.01, sz * (hz - 0.1)))
	# 楼层分隔带
	var floors := int(size.y / 1.6)
	for f in range(1, floors + 1):
		var y := -hy + f * 1.6 - 0.1
		if y > hy - 0.3:
			break
		_ibox(sb, Vector3(size.x + 0.08, 0.12, size.z + 0.08), 0.03, M_DARK, Vector3(0, y, 0))
	# 窗：窗框 + 窗台 + 玻璃（大多黑洞，少数封板或亮着暖光）
	if size.x > 2.5 and size.z > 2.5:
		var M_WIN := A.paint(Color(0.03, 0.035, 0.04), 0.1, 0.35)
		var M_BOARD := A.paint(Color(0.36, 0.27, 0.18), 0.0, 0.9)
		var M_LIT := A.emit(Color(1.0, 0.7, 0.35), 0.9)
		for f in floors:
			var y := -hy + f * 1.6 + 0.85
			if y > hy - 0.4:
				break
			for axis: int in [0, 1]:
				var length: float = size.x if axis == 0 else size.z
				var depth: float = hz if axis == 0 else hx
				var n := int(length / 1.8)
				for i in n:
					var t := -length * 0.5 + (i + 0.5) * length / n
					for sd: float in [-1.0, 1.0]:
						if rng.randf() > 0.85:
							continue
						var r := rng.randf()
						var wm: Material = M_WIN if r < 0.82 else (M_BOARD if r < 0.94 else M_LIT)
						var o: float = sd * (depth + 0.005)
						var pos := Vector3(t, y, o) if axis == 0 else Vector3(o, y, t)
						var rot := Vector3.ZERO if axis == 0 else Vector3(0, 90, 0)
						_ibox(sb, Vector3(0.82, 0.86, 0.05), 0.01, M_TRIM, pos + (Vector3(0, 0, sd * 0.01) if axis == 0 else Vector3(sd * 0.01, 0, 0)), rot, Vector3.ONE, false)
						_ibox(sb, Vector3(0.66, 0.7, 0.06), 0.01, wm, pos + (Vector3(0, 0, sd * 0.03) if axis == 0 else Vector3(sd * 0.03, 0, 0)), rot, Vector3.ONE, false)
						_ibox(sb, Vector3(0.9, 0.07, 0.16), 0.01, M_TRIM, pos + Vector3(0, -0.45, 0) + (Vector3(0, 0, sd * 0.07) if axis == 0 else Vector3(sd * 0.07, 0, 0)), rot, Vector3.ONE, false)
		# 一层卷帘门
		var dz := (hz + 0.02) * (1 if rng.randf() < 0.5 else -1)
		_ibox(sb, Vector3(min(2.2, size.x * 0.4), 1.25, 0.08), 0.02, A.metal(Color(0.3, 0.31, 0.3)), Vector3(rng.randf_range(-hx, hx) * 0.4, -hy + 0.75, dz), Vector3.ZERO, Vector3.ONE, false)
	# 屋顶：深色沥青屋面 + 女儿墙（随机残缺）
	_ibox(sb, Vector3(size.x - 0.3, 0.06, size.z - 0.3), 0.02, A.concrete(Color(0.2, 0.19, 0.18), false), Vector3(0, hy + 0.02, 0), Vector3.ZERO, Vector3.ONE, false)
	var ph := 0.45
	for sd: float in [-1.0, 1.0]:
		var segs := 3
		for k in segs:
			if rng.randf() < 0.18:
				continue
			var len_x := size.x / segs
			var hh := ph * rng.randf_range(0.55, 1.0)
			_ibox(sb, Vector3(len_x, hh, 0.22), 0.03, M_TRIM, Vector3(-hx + (k + 0.5) * len_x, hy + hh * 0.5, sd * (hz - 0.11)))
			var len_z := size.z / segs
			hh = ph * rng.randf_range(0.55, 1.0)
			_ibox(sb, Vector3(0.22, hh, len_z), 0.03, M_TRIM, Vector3(sd * (hx - 0.11), hy + hh * 0.5, -hz + (k + 0.5) * len_z))
	# 屋顶设备：空调外机、通风管、水箱、检修口
	var M_UNIT := A.paint(Color(0.55, 0.56, 0.54), 0.4, 0.55, {"wear": 0.5, "rust": 0.5, "dust": 0.4})
	for k in rng.randi_range(1, 3):
		var up := Vector3(rng.randf_range(-hx, hx) * 0.55, hy + 0.32, rng.randf_range(-hz, hz) * 0.55)
		_ibox(sb, Vector3(0.95, 0.6, 0.75), 0.05, M_UNIT, up, Vector3(0, rng.randf() * 90.0, 0))
		_imesh(sb, A.cyl(0.26, 0.04, 0.26, 12), A.metal(Color(0.08, 0.08, 0.08)), up + Vector3(0, 0.31, 0), Vector3.ZERO, Vector3.ONE, false)
	for k in rng.randi_range(1, 3):
		var vp := Vector3(rng.randf_range(-hx, hx) * 0.65, hy + 0.35, rng.randf_range(-hz, hz) * 0.65)
		_imesh(sb, A.cyl(0.12, 0.7, 0.12, 8), A.metal(Color(0.4, 0.4, 0.4)), vp)
		_imesh(sb, A.cyl(0.18, 0.08, 0.18, 8), A.metal(Color(0.25, 0.25, 0.25)), vp + Vector3(0, 0.38, 0), Vector3.ZERO, Vector3.ONE, false)
	if size.x * size.z > 30.0 and rng.randf() < 0.6:
		var tp := Vector3(rng.randf_range(-hx, hx) * 0.45, hy, rng.randf_range(-hz, hz) * 0.45)
		for lx in [-0.5, 0.5]:
			for lz in [-0.5, 0.5]:
				_imesh(sb, A.cyl(0.05, 0.8, 0.05, 5), A.metal(Color(0.2, 0.2, 0.2)), tp + Vector3(lx, 0.4, lz))
		_imesh(sb, A.cyl(0.75, 1.1, 0.75, 16), A.paint(Color(0.5, 0.42, 0.32), 0.5, 0.6, {"rust": 0.8, "wear": 0.6}), tp + Vector3(0, 1.35, 0))
		_imesh(sb, A.cyl(0.05, 0.25, 0.78, 16), A.metal(Color(0.3, 0.27, 0.24)), tp + Vector3(0, 2.02, 0))
	else:
		_ibox(sb, Vector3(0.8, 0.25, 0.8), 0.04, M_DARK, Vector3(rng.randf_range(-hx, hx) * 0.5, hy + 0.14, rng.randf_range(-hz, hz) * 0.5))
	# 战损：屋顶塌洞 + 钢筋
	if rng.randf() < 0.45:
		var hp := Vector3(rng.randf_range(-hx, hx) * 0.4, hy + 0.06, rng.randf_range(-hz, hz) * 0.4)
		var hr := rng.randf_range(0.6, 1.1)
		_imesh(sb, A.cyl(1.0, 0.02, 0.9, 7), A.paint(Color(0.02, 0.02, 0.02), 0.0, 1.0), hp, Vector3(0, rng.randf() * 60.0, 0), Vector3(hr, 1, hr * rng.randf_range(0.6, 1.0)), false)
		for k in rng.randi_range(3, 6):
			_imesh(sb, A.cyl(0.03, 1.0, 0.03, 5), A.paint(Color(0.35, 0.18, 0.1), 0.5, 0.8),
				hp + Vector3(rng.randf_range(-0.8, 0.8), 0.3, rng.randf_range(-0.8, 0.8)), Vector3(rng.randf_range(-40, 40), 0, rng.randf_range(-40, 40)), Vector3(1, rng.randf_range(0.5, 1.2), 1))
	# 楼脚碎石堆
	for k in rng.randi_range(2, 4):
		var side := Vector3(rng.randf_range(-1, 1) * hx, -hy + 0.2, (1 if rng.randf() < 0.5 else -1) * (hz + 0.5))
		_ibox(sb, Vector3(rng.randf_range(0.6, 1.4), rng.randf_range(0.3, 0.7), rng.randf_range(0.5, 1.0)), 0.1, A.concrete(c.darkened(0.15)), side, Vector3(rng.randf_range(-15, 15), rng.randf() * 90.0, rng.randf_range(-15, 15)))
	# 少数楼挂着残存的灯牌
	if size.y > 3.0 and rng.randf() < 0.3:
		var nc: Color = [Color(1.0, 0.45, 0.2), Color(0.3, 0.9, 1.0), Color(1.0, 0.75, 0.3)][rng.randi() % 3]
		var sign_n := A.add(sb, A.bevel_box(Vector3(1.4, 0.5, 0.08), 0.02), A.emit(nc, 3.0), Vector3(0, hy - 0.8, hz + 0.12), Vector3.ZERO, Vector3.ONE, false)
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


func _ibox(owner: Node3D, size: Vector3, bevel: float, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE, shadow := true) -> void:
	_imesh(owner, A.bevel_box(Vector3.ONE, clampf(snappedf(bevel, 0.01), 0.01, 0.1)), m, pos, rot, size * scl, shadow)


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


func _wreck_car(p: Vector3) -> void:
	var c: Color = [Color(0.5, 0.22, 0.14), Color(0.25, 0.32, 0.38), Color(0.55, 0.5, 0.35), Color(0.3, 0.3, 0.3)][rng.randi() % 4]
	var sb := _static_box(Vector3(2.0, 0.8, 4.0), p + Vector3(0, 0.6, 0), c, null, A.paint(c, 0.4, 0.75))
	sb.rotation_degrees.y = rng.randf_range(0, 180)
	A.add(sb, A.bevel_box(Vector3(1.8, 0.65, 2.0), 0.15, 0.75), A.paint(c.darkened(0.1), 0.4, 0.75), Vector3(0, 0.7, 0.2))
	A.add(sb, A.bevel_box(Vector3(1.65, 0.45, 1.85), 0.1, 0.75), A.paint(Color(0.05, 0.06, 0.07), 0.2, 0.2), Vector3(0, 0.72, 0.2))
	for wx in [-0.95, 0.95]:
		for wz in [-1.3, 1.3]:
			A.add(sb, A.cyl(0.36, 0.25, 0.36, 12), A.rubber(), Vector3(wx, -0.3, wz), Vector3(0, 0, 90))
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
	if mech == null:
		return
	# 镜头跟随 + 鼠标前探
	var mp := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mp)
	var dir := camera.project_ray_normal(mp)
	var hit = Plane(Vector3.UP, 1.8).intersects_ray(from, dir)
	if aim_override != null:
		mech.aim_point = aim_override
	elif hit != null:
		mech.aim_point = hit
	var look: Vector3 = mech.global_position + (mech.aim_point - mech.global_position).limit_length(12.0) * 0.25
	look.y = 0.0
	var want: Vector3 = look + CAM_OFFSET * cam_zoom
	camera.global_position = camera.global_position.lerp(want, clamp(6.0 * delta, 0.0, 1.0))
	if shake > 0.0:
		shake = max(0.0, shake - delta)
		camera.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.6
	camera.look_at(camera.global_position - CAM_OFFSET * cam_zoom, Vector3.UP)
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

	time += delta
	var dn := district_at(mech.global_position)
	if dn != cur_district:
		if cur_district != "":
			hud.msg("进入区域：" + dn)
			Events.district_entered.emit(dn)
		cur_district = dn
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.25
		_threat_scan(0.25)
	_update_transport(delta)
	_update_extract(delta)
	_update_loot(delta)
	if Input.is_action_just_pressed("call_transport"):
		call_transport()
	if Input.is_action_just_pressed("map"):
		hud.toggle_map()
	if Input.is_action_just_pressed("pause") and Engine.get_process_frames() - hud.last_toggle_frame > 2:
		if hud.map_open():
			hud.toggle_map()
		elif open_box:
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
			Events.enemy_seen.emit(b.kind, GameData.mark_enemy_seen(b.kind), b.global_position)
	if near_chase < 28.0:
		_combat_quiet = 0.0
		if not in_combat:
			in_combat = true
			Events.combat_changed.emit(true)
	elif in_combat:
		_combat_quiet = _combat_quiet + dt if near_chase > 40.0 else 0.0
		if _combat_quiet >= 6.0:
			in_combat = false
			Events.combat_changed.emit(false)
	for i in poi_centers.size():
		if _found_pois.has(i):
			continue
		var c: Vector3 = poi_centers[i]
		if Vector2(c.x - mp.x, c.z - mp.z).length() < 16.0:
			_found_pois[i] = true
			var pid: String = poi_ids[i]
			Events.poi_discovered.emit(pid, str(GameData.POIS.get(pid, {}).get("name", pid)), c)


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
			Events.extract_cancelled.emit(extract_target.title)
		extract_progress = 0.0
		extract_target = inside
		if inside:
			Audio.play_sfx("extract_start")
			Events.extract_started.emit(inside.title, inside.need, inside.is_transport)
	if inside:
		extract_progress += delta
		if extract_progress >= inside.need:
			Audio.play_sfx("extract_success")
			Events.extract_completed.emit(inside.title, inside.is_transport)
			_finish(true, "成功撤离（%s）" % inside.title)
	else:
		extract_progress = 0.0


func call_transport() -> void:
	if transport_state != "none":
		hud.msg("运输机已在降落航线上，无需重复呼叫")
		Audio.play_sfx("use_denied")
		return
	if not mech.cargo.has("beacon"):
		hud.msg("货舱内未携带呼叫信标")
		Audio.play_sfx("use_denied")
		return
	mech.cargo.erase("beacon")
	mech.check_overload()
	transport_state = "incoming"
	transport_t = 40.0
	transport_zone = ExtractScript.new()
	world.add_child(transport_zone)
	transport_zone.position = Vector3(mech.global_position.x, 0, mech.global_position.z)
	transport_zone.setup("运输机降落区", Color(1.0, 0.75, 0.2), 3.0, true)
	hud.msg("脉冲信标升空，「信天翁-2」40 秒后切入降落航线；信标蜂鸣正把附近的虫群引过来。")
	Audio.play_sfx("use_beacon")
	Events.item_used.emit("beacon")
	Events.transport_called.emit(transport_zone.position, transport_t)
	alert_noise(mech.global_position, 40.0)


func _update_transport(delta: float) -> void:
	if transport_state == "incoming":
		transport_t -= delta
		if transport_t <= 0.0:
			transport_state = "landed"
			transport_t = 25.0
			_spawn_transport_ship()
			hud.msg("「信天翁-2」强行着陆，舱门悬停开启 25 秒；引擎轰鸣正把周围的虫群引向降落点。")
			Events.transport_landed.emit(transport_zone.position, transport_t)
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
			hud.msg("「信天翁-2」悬停超时拉起返航，这趟只能走地面固定撤离点了。")
			Events.transport_departed.emit()


func _spawn_transport_ship() -> void:
	transport_ship = Node3D.new()
	world.add_child(transport_ship)
	transport_ship.position = transport_zone.position + Vector3(0, 50, 0)
	var M := A.paint(Color(0.78, 0.74, 0.64), 0.3, 0.5)
	var M2 := A.paint(Color(0.55, 0.52, 0.46), 0.3, 0.55)
	A.add(transport_ship, A.capsule(1.6, 9.0), M, Vector3.ZERO, Vector3(90, 0, 0), Vector3(1.15, 0.9, 1.0))
	A.add(transport_ship, A.bevel_box(Vector3(1.8, 0.7, 2.0), 0.2, 0.7), A.glass(Color(0.4, 0.8, 1.0)), Vector3(0, 0.95, -3.0))
	A.add(transport_ship, A.bevel_box(Vector3(12.5, 0.3, 2.4), 0.1), M2, Vector3(0, 0.6, 0.6))
	A.add(transport_ship, A.bevel_box(Vector3(3.8, 0.3, 1.0), 0.05), A.hazard(), Vector3(0, 1.3, -1.5))
	A.add(transport_ship, A.bevel_box(Vector3(0.25, 2.2, 1.8), 0.08, 0.6), M2, Vector3(0, 1.6, 4.0), Vector3(-15, 0, 0))
	for sx in [-5.6, 5.6]:
		A.add(transport_ship, A.cyl(0.8, 1.8, 0.85, 16), A.metal(), Vector3(sx, 0.6, 0.6))
		A.add(transport_ship, A.cyl(0.62, 0.15, 0.62, 16), A.emit(Color(0.4, 0.8, 1.0), 5.0), Vector3(sx, -0.35, 0.6), Vector3.ZERO, Vector3.ONE, false)
		var l := OmniLight3D.new()
		l.light_color = Color(0.4, 0.8, 1.0)
		l.light_energy = 3.0
		l.omni_range = 8.0
		l.position = Vector3(sx, -1.0, 0.6)
		transport_ship.add_child(l)
	for sx in [-6.2, 6.2]:
		A.add(transport_ship, A.sphere(0.12), A.emit(Color(1, 0.2, 0.2) if sx < 0 else Color(0.2, 1, 0.3), 6.0), Vector3(sx, 0.6, 0.6), Vector3.ZERO, Vector3.ONE, false)
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
func nearest_box(maxd: float):
	var best = null
	var bd := maxd
	for b in get_tree().get_nodes_in_group("lootboxes"):
		var d: float = b.global_position.distance_to(mech.global_position)
		if d < bd:
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
			if open_box.reveal_t >= 0.55:
				open_box.reveal_t = 0.0
				open_box.revealed += 1
				var rid: String = open_box.items[open_box.revealed - 1]
				var rar := int(GameData.item(rid).rar)
				Audio.play_sfx(["loot_reveal_rare", "loot_reveal"] if rar >= 2 else "loot_reveal")
				Events.item_revealed.emit(rid, rar)
				hud.refresh_loot()
		if Input.is_action_just_pressed("interact"):
			close_box()
		return
	var b = nearest_box(3.6)
	for o in get_tree().get_nodes_in_group("lootboxes"):
		o.set_near(o == b)
	hud.set_prompt(b.title if b else "")
	if b and Input.is_action_just_pressed("interact"):
		open_container(b)


## 打开容器：锁定移动、打开搜刮面板，物品随后逐个显现
func open_container(b) -> void:
	open_box = b
	mech.input_locked = true
	hud.open_loot(b)
	hud.set_prompt("")   # 面板开着时不显示「搜索」提示；关上面板后下一帧按附近的容器重新给出
	Audio.play_sfx(["loot_open_" + str(b.kind), "loot_open"])
	Events.box_opened.emit(str(b.kind), b.global_position)


func close_box() -> void:
	if open_box and is_instance_valid(open_box):
		Audio.play_sfx("loot_close")
		open_box.refresh_glow()
		if (open_box.kind == "bug" or open_box.kind == "nest") and open_box.items.is_empty():
			open_box.queue_free()
	open_box = null
	mech.input_locked = false
	hud.close_loot()


func take_from_box(index: int) -> void:
	if open_box == null or index >= open_box.revealed or index >= open_box.items.size():
		return
	var id: String = open_box.items[index]
	if mech.cargo_weight() + float(GameData.item(id).w) > mech.cargo_cap() + 0.001:
		hud.msg("货舱承重已满（%.1f/%.0f kg），装不下这件物资了" % [mech.cargo_weight(), mech.cargo_cap()])
		Audio.play_sfx("cargo_full")
		Events.cargo_full.emit(id)
		return
	open_box.items.remove_at(index)
	open_box.revealed -= 1
	mech.cargo.append(id)
	Audio.play_sfx("loot_take")
	Events.item_picked.emit(id, int(GameData.item(id).rar))
	mech.check_overload()
	hud.refresh_loot()


func put_into_box(index: int) -> void:
	if open_box == null or index >= mech.cargo.size():
		return
	var id: String = mech.cargo[index]
	mech.cargo.remove_at(index)
	open_box.items.insert(0, id)
	open_box.revealed += 1
	Audio.play_sfx("loot_put")
	mech.check_overload()
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
	world.add_child(b)
	b.position = pos
	b.home = pos
	b.setup(kind, self, mech)
	return b


func nearest_bug(p: Vector3, maxd: float):
	var best = null
	var bd := maxd
	for b in get_tree().get_nodes_in_group("bugs"):
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
	var fov: float = camera.fov if camera else 36.0
	var off: Vector3 = CAM_OFFSET * ZOOM_MAX
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
	var q := PhysicsRayQueryParameters3D.create(a + Vector3(0, EYE_H, 0), b + Vector3(0, EYE_H, 0), 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## 重新栅格化导航网格。地图建完时调用一次；碰撞后处理（合并 / 删除碰撞体）之后也应调用它
func rebuild_nav() -> void:
	nav = preload("res://scripts/nav_grid.gd").new()
	nav.build(self, HALF)
	print("[raid] nav grid %dx%d (%.1fm) from %d shapes in %.0f ms" % [nav.n, nav.n, nav.CELL, nav.shape_count, nav.build_ms])


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


func _proj(pos: Vector3, vel: Vector3, dmg: float, life: float, mask: int, c: Color, size: float, glow := true):
	var p = ProjScript.new()
	p.raid = self
	p.vel = vel
	p.dmg = dmg
	p.life = life
	p.mask = mask
	p.color = c
	var m := MeshInstance3D.new()
	m.mesh = A.capsule(size * 0.5, size * 4.0)
	m.rotation_degrees.x = 90
	m.material_override = A.emit(c.lightened(0.3), 6.0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(m)
	if glow:
		var g := MeshInstance3D.new()
		g.mesh = _quad_cached(size * 5.0)
		g.material_override = _glow_mat(c)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.add_child(g)
	fx.add_child(p)
	p.global_position = pos
	return p


## 曳光弹：白热弹芯 + 由白到橙渐隐的长尾（随飞行距离拉长，带拖曳感）
func _tracer(pos: Vector3, vel: Vector3, dmg: float, life: float, c: Color, w: float, core: float):
	var p = ProjScript.new()
	p.raid = self
	p.vel = vel
	p.dmg = dmg
	p.life = life
	p.mask = 1 | 4 | 16       ## 玩家子弹：地形 + 虫群 + 流浪者（打不到队友）
	p.source = mech
	p.color = c
	var cm := MeshInstance3D.new()
	cm.mesh = _box_cached(Vector3(core, core, core * 7.0))
	cm.material_override = A.emit(Color(1.0, 0.95, 0.85), 9.0)
	cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(cm)
	var t := MeshInstance3D.new()
	t.mesh = _box_cached(Vector3(w, w, 1.0))
	t.material_override = _tracer_mat(c)
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.scale = Vector3(1, 1, 0.01)
	p.add_child(t)
	p.tail = t
	p.tail_len = clampf(vel.length() * 0.065, 1.5, 5.5)
	var g := MeshInstance3D.new()
	g.mesh = _quad_cached(w * 4.0)
	g.material_override = _glow_mat(c)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(g)
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


func _quad_cached(sz: float) -> QuadMesh:
	var k := "q%.3f" % sz
	if not _bullet_meshes.has(k):
		var qm := QuadMesh.new()
		qm.size = Vector2.ONE * sz
		_bullet_meshes[k] = qm
	return _bullet_meshes[k]


const TRACER_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color;
varying float t;
void vertex() { t = clamp(VERTEX.z + 0.5, 0.0, 1.0); }
void fragment() {
	float a = pow(1.0 - t, 1.7);
	vec3 c = mix(vec3(1.0, 0.97, 0.9), col.rgb, smoothstep(0.0, 0.3, t));
	ALBEDO = c * 2.6 * a;
	ALPHA = a;
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


func spawn_projectile(origin: Vector3, dir: Vector3, m: Dictionary, friendly: bool) -> void:
	var speed: float = m.get("speed", 40.0)
	var life: float = float(m.range) / speed
	match m.weapon:
		"flamer":
			var p = _proj(origin, dir * speed * randf_range(0.8, 1.1), m.dmg, life, 1 | 4 | 16, Color(1.0, randf_range(0.35, 0.6), 0.1), 0.35)
			p.source = mech
			p.pierce = true
			p.grow = 3.0
			p.hit_sfx = "-"
		"shotgun":
			_tracer(origin, dir * speed * randf_range(0.9, 1.1), m.dmg, life, Color(1.0, 0.55, 0.18), 0.09, 0.05)
		_:
			_tracer(origin, dir * speed, m.dmg, life, Color(1.0, 0.62, 0.22), 0.12, 0.065)


func spawn_spit(origin: Vector3, dir: Vector3, dmg: float) -> void:
	var p = _proj(origin, dir * 16.0, dmg, 1.4, 1 | 2 | 16 | 32, Color(0.55, 1.0, 0.15), 0.4)
	p.hit_sfx = "hit_spit"
	A.emitter(p, Vector3.ZERO, {"amount": 12, "life": 0.35, "size": 0.35, "spread": 180.0, "vmin": 0.2, "vmax": 0.6, "gravity": Vector3(0, -3, 0),
		"c0": Color(0.6, 1.0, 0.2, 0.8), "c1": Color(0.2, 0.5, 0.0, 0.0), "grow0": 1.0, "grow1": 0.2})


func launch_missiles(origin: Vector3, m: Dictionary) -> void:
	for i in int(m.count):
		var a := TAU * i / float(m.count)
		var v := Vector3(cos(a) * 6.0, 9.0, sin(a) * 6.0)
		var p = _proj(origin, v, m.dmg, 3.0, 1 | 4 | 16, Color(1.0, 0.4, 0.2), 0.25)
		p.homing = true
		p.aoe = 3.2
		# 导弹拖烟
		A.emitter(p, Vector3.ZERO, {"amount": 40, "life": 1.1, "size": 0.7, "tex": A.smoke_tex(), "additive": false, "spread": 180.0, "vmin": 0.1, "vmax": 0.4,
			"gravity": Vector3(0, 0.6, 0), "c0": Color(0.75, 0.72, 0.68, 0.55), "c1": Color(0.5, 0.48, 0.45, 0.0), "grow0": 0.4, "grow1": 2.2})
		A.emitter(p, Vector3.ZERO, {"amount": 16, "life": 0.12, "size": 0.45, "spread": 10.0, "vmin": 0.0, "vmax": 0.2, "gravity": Vector3.ZERO,
			"c0": Color(1.0, 0.9, 0.6), "c1": Color(1.0, 0.3, 0.05, 0.0), "grow0": 1.0, "grow1": 0.3})
	alert_noise(origin, 30.0)


func fire_laser(origin: Vector3, dir: Vector3, m: Dictionary) -> void:
	var to := origin + dir * float(m.range)
	var q := PhysicsRayQueryParameters3D.create(origin, to, 1 | 4 | 16)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	var end := to
	if not r.is_empty():
		end = r.position
		var organic: bool = r.collider.is_in_group("bugs") or r.collider.is_in_group("nests")
		if "aggressor" in r.collider:
			r.collider.aggressor = mech
		if r.collider.has_method("take_damage"):
			r.collider.take_damage(m.dmg)
		spark(end, m.color, 18)
		Audio.play_sfx("hit_chitin" if organic else "hit_metal", end)
	var len := origin.distance_to(end)
	var beam := Node3D.new()
	fx.add_child(beam)
	beam.global_position = (origin + end) * 0.5
	beam.look_at(end, Vector3.UP)
	A.add(beam, A.cyl(0.05, len, 0.05, 8), A.emit(Color(1, 1, 1), 8.0), Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, false)
	var outer := A.add(beam, A.cyl(0.16, len, 0.16, 10), _beam_mat(m.color), Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, false)
	_flash_light(origin, m.color, 4.0, 6.0)
	var tw := create_tween()
	tw.tween_property(beam, "scale", Vector3(0.05, 0.05, 1.0), 0.18).set_ease(Tween.EASE_IN)
	tw.tween_callback(beam.queue_free)


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
	# 火球
	A.burst(fx, p + Vector3(0, 0.6, 0), {"amount": 18, "life": 0.55, "size": radius * 0.9, "tex": A.smoke_tex(), "vmin": radius * 1.2, "vmax": radius * 2.5,
		"gravity": Vector3(0, 3, 0), "damp": 6.0, "radius": 0.3, "c0": Color(1.0, 0.85, 0.5), "c1": Color(c.r * 0.6, c.g * 0.2, 0.0, 0.0), "grow0": 0.6, "grow1": 1.4})
	# 黑烟
	A.burst(fx, p + Vector3(0, 0.8, 0), {"amount": 10, "life": 1.6, "size": radius * 1.0, "tex": A.smoke_tex(), "additive": false, "vmin": radius * 0.5, "vmax": radius * 1.2,
		"gravity": Vector3(0, 2.0, 0), "damp": 3.0, "radius": radius * 0.3, "explosive": 0.8, "c0": Color(0.12, 0.1, 0.09, 0.7), "c1": Color(0.25, 0.22, 0.2, 0.0), "grow0": 0.5, "grow1": 1.8})
	# 火星
	A.burst(fx, p + Vector3(0, 0.5, 0), {"amount": 24, "life": 0.7, "size": 0.15, "vmin": 6.0, "vmax": 14.0, "gravity": Vector3(0, -15, 0), "damp": 1.0,
		"c0": Color(1.0, 0.85, 0.5), "c1": Color(1.0, 0.3, 0.0, 0.0), "grow0": 1.0, "grow1": 0.3})
	_flash_light(p + Vector3(0, 1.5, 0), Color(1.0, 0.6, 0.25), 8.0, radius * 4.0, 0.35)
	var scorch := A.ground_decal(fx, A.blob_tex(), Color(1, 1, 1, 0.8), radius * 2.2, Vector3(p.x, 0.04, p.z))
	scorch.rotation.y = randf() * TAU
	var tw := create_tween()
	tw.tween_interval(12.0)
	tw.tween_callback(scorch.queue_free)


func spark(p: Vector3, c: Color, n := 8) -> void:
	A.burst(fx, p, {"amount": n, "life": 0.3, "size": 0.12, "vmin": 3.0, "vmax": 9.0, "gravity": Vector3(0, -12, 0), "damp": 2.0,
		"c0": c.lightened(0.5), "c1": Color(c.r, c.g * 0.5, 0.0, 0.0), "grow0": 1.0, "grow1": 0.2})


func muzzle_flash(p: Vector3, c: Color, dir := Vector3.ZERO, weapon := "") -> void:
	A.burst(fx, p, {"amount": 3, "life": 0.05, "size": 0.8, "vmin": 0.0, "vmax": 0.5, "gravity": Vector3.ZERO, "c0": c.lightened(0.6), "c1": Color(c.r, c.g * 0.6, 0.0, 0.0), "grow0": 1.0, "grow1": 0.4})
	_flash_light(p, c, 2.5, 5.0, 0.05)
	if dir == Vector3.ZERO or weapon in ["laser", "flamer"]:
		return
	var heavy := weapon == "shotgun"
	# 前向锥形火舌
	A.burst(fx, p + dir * 0.3, {"amount": 6 if heavy else 4, "life": 0.06, "size": 0.55 if heavy else 0.4, "dir": dir, "spread": 14.0, "vmin": 8.0, "vmax": 16.0,
		"gravity": Vector3.ZERO, "damp": 30.0, "c0": Color(1.0, 0.92, 0.7), "c1": Color(1.0, 0.45, 0.1, 0.0), "grow0": 1.0, "grow1": 0.5})
	# 硝烟
	A.burst(fx, p + dir * 0.4, {"amount": 3 if heavy else 1, "life": 0.9, "size": 0.9, "tex": A.smoke_tex(), "additive": false, "dir": dir, "spread": 30.0, "vmin": 1.0, "vmax": 2.5,
		"gravity": Vector3(0, 0.8, 0), "damp": 3.0, "c0": Color(0.7, 0.68, 0.64, 0.35), "c1": Color(0.6, 0.58, 0.55, 0.0), "grow0": 0.5, "grow1": 2.0})
	# 抛壳（铜色弹壳从右侧弹出）
	var side := dir.cross(Vector3.UP).normalized()
	A.burst(fx, p - dir * 0.6, {"amount": 2 if heavy else 1, "life": 0.7, "size": 0.09, "additive": false, "dir": (side + Vector3(0, 0.9, 0)).normalized(), "spread": 20.0,
		"vmin": 3.0, "vmax": 5.0, "gravity": Vector3(0, -22, 0), "damp": 0.5, "c0": Color(0.95, 0.72, 0.3), "c1": Color(0.7, 0.5, 0.2, 0.9), "grow0": 1.0, "grow1": 1.0,
		"tex": A.blob_tex()})


## 命中：打在单位上 → 火花 + 金属碎屑；打在墙/地上 → 火花 + 尘土 + 碎石
func impact(p: Vector3, n: Vector3, c: Color, unit: bool, vel: Vector3) -> void:
	var refl := vel.normalized().bounce(n) if n != Vector3.ZERO else Vector3.UP
	A.burst(fx, p, {"amount": 10, "life": 0.28, "size": 0.09, "dir": (refl + n).normalized(), "spread": 40.0, "vmin": 5.0, "vmax": 12.0, "gravity": Vector3(0, -14, 0), "damp": 2.0,
		"c0": Color(1.0, 0.95, 0.75), "c1": Color(c.r, c.g * 0.4, 0.0, 0.0), "grow0": 1.0, "grow1": 0.2})
	if unit:
		A.burst(fx, p, {"amount": 5, "life": 0.45, "size": 0.1, "additive": false, "dir": n, "spread": 60.0, "vmin": 2.0, "vmax": 5.0, "gravity": Vector3(0, -18, 0),
			"c0": Color(0.25, 0.25, 0.28), "c1": Color(0.15, 0.15, 0.17, 0.0), "grow0": 1.0, "grow1": 0.6})
	else:
		A.burst(fx, p, {"amount": 4, "life": 0.8, "size": 0.7, "tex": A.smoke_tex(), "additive": false, "dir": n, "spread": 50.0, "vmin": 0.8, "vmax": 2.2,
			"gravity": Vector3(0, -0.5, 0), "damp": 3.0, "c0": Color(0.6, 0.55, 0.48, 0.5), "c1": Color(0.55, 0.5, 0.45, 0.0), "grow0": 0.4, "grow1": 1.6})
		A.burst(fx, p, {"amount": 4, "life": 0.5, "size": 0.07, "additive": false, "dir": n, "spread": 55.0, "vmin": 2.0, "vmax": 5.0, "gravity": Vector3(0, -20, 0),
			"c0": Color(0.42, 0.4, 0.37), "c1": Color(0.4, 0.38, 0.35, 0.8), "grow0": 1.0, "grow1": 1.0})


func on_player_hurt(amount: float) -> void:
	shake = max(shake, clamp(amount / 40.0, 0.08, 0.4))
	hud.hurt()


func on_bug_killed(b) -> void:
	var p: Vector3 = b.global_position
	# 流浪者打死的虫不算玩家的击杀（不计数、不广播）；队友的击杀算进小队战绩
	var by = b.get("aggressor")
	if not (is_instance_valid(by) and by.is_in_group("rovers")):
		kills += 1
		Events.enemy_killed.emit(str(b.kind), p)
	# 机械虫：油污 + 金属碎片（不是血）
	var sc: float = b.data.scale
	_kill_decal(A.ground_decal(world, A.blob_tex(), Color(0.05, 0.05, 0.06, 0.85), 2.6 * sc, Vector3(p.x, 0.028, p.z)))
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
	hud.msg("虫巢核心坍塌，焦黑的残骸里渗出几点紫光虫晶。")
	Events.nest_destroyed.emit(p)


# ================= 结束 =================
func _on_mech_died(reason: String) -> void:
	_finish(false, reason)


func _finish(success: bool, reason: String) -> void:
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
	get_tree().paused = false
	_finish(false, "驾驶员紧急弃机逃生，机甲与满舱物资遗弃在沦陷地表")



func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_zoom = clampf(cam_zoom - 0.06, ZOOM_MIN, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_zoom = clampf(cam_zoom + 0.06, ZOOM_MIN, ZOOM_MAX)


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
var bldg_polys: Array = []       ## [PackedVector2Array, 区块字符]：这一局实际建起来的建筑轮廓（地形图用）
var cur_district := ""
var _rg: WC.SegGrid              ## 道路线段索引
var _wg: WC.SegGrid              ## 河道线段索引
var _road_len := PackedFloat32Array()   ## 道路累计长度（随机取路面点用）


func _e(k: int) -> float:
	return -HALF + CELL * k


func _load_map() -> void:
	MAP = GameData.map_data(map_id)
	zones = MAP.zones
	layout = WC.zone_layout(map_id)
	roads.clear()
	curves.clear()
	_rg = WC.SegGrid.new()
	_rg.cell = 12.0
	_rg.reach = 12.0
	_road_len = PackedFloat32Array()
	var acc := 0.0
	for r: Dictionary in layout.roads:
		var pts: PackedVector2Array = r.pts
		curves.append({"pts": pts, "d": pts, "w": float(r.w), "dirt": bool(r.dirt), "kind": str(r.kind), "bridge": bool(r.bridge)})
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
		if p.distance_to(Vector2(l.x, l.y)) < l.z + pad:
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
		if absf(p.x) < HALF - 4.0 and absf(p.z) < HALF - 4.0 and not _blocked(p, rad):
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
	# 道路上的废弃车辆 / 火桶
	for k in 96:
		var p := _road_point(2.5)
		if not _blocked(p, 2.2, false) and not in_river(Vector2(p.x, p.z), 4.0) and absf(p.x) < HALF - 8 and absf(p.z) < HALF - 8:
			_wreck_car(p)
	for k in 16:
		var p := _road_point(1.5)
		if not _blocked(p, 1.5, false) and not in_river(Vector2(p.x, p.z), 3.0) and absf(p.x) < HALF - 8 and absf(p.z) < HALF - 8:
			_fire_barrel(p)
	return _drop_point()   # _keep_clear 保留到扩展脚本里的地标落位前（_run_ext_build）


## 转场口通道与地标原位：这一段生成杂物时避开（转场口位置是确定的，见 world_city.gd gate_along）
func _shield_spots() -> void:
	_keep_clear.clear()
	for edge: String in WorldLinkScript.LINKS.get(map_id, {}):
		var al := WC.gate_along(map_id, edge)
		var hs: float = WorldLinkScript.HALF_SPAN + 2.0
		match edge:
			"N": _keep_clear.append(Rect2(al - hs, -HALF - 4.0, hs * 2.0, 40.0))
			"S": _keep_clear.append(Rect2(al - hs, HALF - 36.0, hs * 2.0, 40.0))
			"W": _keep_clear.append(Rect2(-HALF - 4.0, al - hs, 40.0, hs * 2.0))
			_: _keep_clear.append(Rect2(HALF - 36.0, al - hs, 40.0, hs * 2.0))
	# 地标：用方形留空（地标脚本按方形探测占地），再多留 4 米，盖住杂物占地矩形超出其探测半径的部分（如 12 米长的断墙）
	for e in MAP.get("landmarks", []):
		if not bool(e.get("water", false)):
			var ls := WC.landmark_spot(map_id, e)
			var h := float(e.get("clear", 7.0)) + 4.0
			_keep_clear.append(Rect2(ls.x - h, ls.y - h, h * 2.0, h * 2.0))


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
		if absf(q.x) < HALF - 6.0 and absf(q.y) < HALF - 6.0:
			return Vector3(q.x, 0, q.y)
	return _free_spot(2.0)


func _drop_point() -> Vector3:
	# 空投点：外围较安全的区块里找空地
	var safe_cells: Array = []
	for j in 9:
		for i in 9:
			if zones[j][i] in ["R", "W", "F", "P", "T"] and (i <= 1 or j <= 1 or i >= 7 or j >= 7):
				safe_cells.append(Vector2i(i, j))
	for t in 40:
		if safe_cells.is_empty():
			break
		var c: Vector2i = safe_cells[rng.randi() % safe_cells.size()]
		var p := _spot_in(_cell_rect(c.x, c.y), 4.0)
		if p != Vector3.INF and not (zone_at(p) in ["K", "S"]):
			return p
	return _free_spot(4.0)


# ---------- 地形图（小地图 / 大地图共用） ----------
const MAP_PX := 720
const ZONE_TINT := {"W": Color(0.33, 0.3, 0.23), "F": Color(0.4, 0.35, 0.2), "R": Color(0.36, 0.33, 0.3), "D": Color(0.27, 0.28, 0.31),
	"I": Color(0.33, 0.29, 0.24), "H": Color(0.25, 0.29, 0.31), "Y": Color(0.3, 0.27, 0.25), "M": Color(0.27, 0.31, 0.22), "P": Color(0.23, 0.32, 0.19),
	"T": Color(0.17, 0.24, 0.15), "C": Color(0.25, 0.22, 0.19), "S": Color(0.27, 0.19, 0.28), "K": Color(0.2, 0.17, 0.15), "L": Color(0.21, 0.27, 0.23),
	"A": Color(0.12, 0.2, 0.28), "B": Color(0.5, 0.45, 0.36)}
var map_tex: ImageTexture


func _img_line(img: Image, a: Vector2, b: Vector2, w: float, c: Color, step := 1.0) -> void:
	var k := MAP_PX / (HALF * 2.0)
	var n := maxi(1, int(a.distance_to(b) / step))
	var s := maxi(1, int(w * k))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		var q := Vector2i(int((p.x + HALF) * k) - s / 2, int((p.y + HALF) * k) - s / 2)
		img.fill_rect(Rect2i(q, Vector2i(s, s)), c)

func _img_disc(img: Image, c: Vector2, rad: float, col: Color) -> void:
	var k := MAP_PX / (HALF * 2.0)
	var cx := (c.x + HALF) * k
	var cy := (c.y + HALF) * k
	var rr := rad * k
	for y in range(int(cy - rr), int(cy + rr) + 1):
		var hw := sqrt(maxf(0.0, rr * rr - (y - cy) * (y - cy)))
		if y >= 0 and y < MAP_PX:
			img.fill_rect(Rect2i(int(cx - hw), y, int(hw * 2.0) + 1, 1), col)

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
	for i in pts.size() - 1:
		_img_line(img, pts[i], pts[i + 1], w, c)


func _build_map_texture() -> void:
	var img := Image.create(MAP_PX, MAP_PX, false, Image.FORMAT_RGBA8)
	var k := MAP_PX / (HALF * 2.0)
	# 区块底色：2 米栅格放大
	var n: int = layout.r_n
	var pad := int(roundf(-(layout.r_o.x + HALF) / WC.RAST))
	var m := int(HALF * 2.0 / WC.RAST)
	var base := Image.create(m, m, false, Image.FORMAT_RGBA8)
	for y in m:
		for x in m:
			base.set_pixel(x, y, ZONE_TINT.get(char(layout.rast[(y + pad) * n + x + pad]), ZONE_TINT.W))
	base.resize(MAP_PX, MAP_PX, Image.INTERPOLATE_NEAREST)
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
	# 河流
	for r: Dictionary in rivers:
		_img_poly_line(img, r.pts, r.w + 4.0, Color(0.22, 0.2, 0.17) if not r.dry else Color(0.36, 0.32, 0.25))
	for r: Dictionary in rivers:
		_img_poly_line(img, r.pts, r.w, Color(0.17, 0.3, 0.37) if not r.dry else Color(0.5, 0.45, 0.35))
	# 湖
	for l: Vector3 in lakes:
		_img_disc(img, Vector2(l.x, l.y), l.z + 2.0, Color(0.22, 0.2, 0.17))
	for l: Vector3 in lakes:
		_img_disc(img, Vector2(l.x, l.y), l.z, Color(0.17, 0.3, 0.37))
	# 道路：先画路缘，再画路面
	for cv: Dictionary in curves:
		_img_poly_line(img, cv.pts, cv.w, Color(0.47, 0.41, 0.31) if cv.dirt else Color(0.53, 0.51, 0.47))
	for cv: Dictionary in curves:
		if not cv.dirt:
			_img_poly_line(img, cv.pts, cv.w - 2.4, Color(0.42, 0.405, 0.38) if cv.w >= 11.0 else Color(0.38, 0.37, 0.35))
	# 桥
	for b: Array in bridges:
		_img_line(img, b[0], b[1], b[2] + 1.5, Color(0.12, 0.12, 0.13))
		_img_line(img, b[0], b[1], b[2] - 1.0, Color(0.5, 0.48, 0.45))
	# 铁轨
	for l: Array in rail_lines:
		_img_line(img, l[0], l[1], 3.0, Color(0.2, 0.18, 0.17))
	for l: Array in rail_lines:
		_img_line(img, l[0], l[1], 1.0, Color(0.5, 0.45, 0.4))
	# 山脊
	for p: Vector2 in ridge_pts:
		_img_line(img, p, p, 5.0, Color(0.18, 0.15, 0.12))
		_img_line(img, p + Vector2(-0.6, -0.6), p + Vector2(-0.6, -0.6), 3.0, Color(0.42, 0.37, 0.3))
	# 小型障碍（占地矩形）
	for r: Rect2 in blocks:
		if r.get_area() <= 10.0:
			img.fill_rect(Rect2i(int((r.position.x + HALF) * k), int((r.position.y + HALF) * k), maxi(2, int(r.size.x * k)), maxi(2, int(r.size.y * k))), Color(0.16, 0.155, 0.15))
	# 建筑：实际轮廓（斜放的楼按真实朝向画）
	for e: Array in bldg_polys:
		_img_poly(img, e[0], Color(0.09, 0.09, 0.1))
	for e: Array in bldg_polys:
		_img_poly(img, WC.inset(e[0], 0.9), Color(0.6, 0.58, 0.54))
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
	var n := 90
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var wp := Vector3(-HALF + (x + 0.5) * 4.0, 0, -HALF + (y + 0.5) * 4.0)
			var c: Color = ZONE_GROUND.get(zone_at(wp), ZONE_GROUND.W)
			if in_wet(Vector2(wp.x, wp.z), 6.0):
				c = Color(0, 0.1, 0.15, 0)
			elif in_river(Vector2(wp.x, wp.z), 6.0):
				c = Color(0, 0, 0, 0.2)
			img.set_pixel(x, y, c)
	img.resize(180, 180, Image.INTERPOLATE_BILINEAR)
	var t := ImageTexture.create_from_image(img)
	var gm: ShaderMaterial = A.ground()
	gm.set_shader_parameter("zone_tex", t)
	gm.set_shader_parameter("zone_half", HALF)
	gm.set_shader_parameter("zone_on", 1.0)


# ---------- 道路（全部折线，合并成少数几个网格） ----------
## 把一组条带加进 SurfaceTool（pts 中心线，w 宽，off 横向偏移，y 高度）
func _st_strip(st: SurfaceTool, pts: PackedVector2Array, w: float, off: float, y: float) -> void:
	if pts.size() < 2:
		return
	var L := PackedVector3Array()
	var R := PackedVector3Array()
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var nn := Vector2(-t.y, t.x)
		var c := pts[i] + nn * off
		L.append(Vector3(c.x + nn.x * w * 0.5, y, c.y + nn.y * w * 0.5))
		R.append(Vector3(c.x - nn.x * w * 0.5, y, c.y - nn.y * w * 0.5))
	for i in pts.size() - 1:
		for v in [L[i], R[i], L[i + 1], R[i], R[i + 1], L[i + 1]]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x, v.z) * 0.1)
			st.add_vertex(v)


func _st_commit(st: SurfaceTool, m: Material, count: int) -> void:
	if count == 0:
		return
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)


func _build_roads() -> void:
	var ASPH := A.concrete(Color(0.24, 0.23, 0.22), false)
	var ASPH2 := A.concrete(Color(0.28, 0.27, 0.26), false)
	var DIRT := A.concrete(Color(0.42, 0.36, 0.27), false)
	var RUT := A.concrete(Color(0.3, 0.25, 0.19), false)
	var WALK := A.concrete(Color(0.5, 0.48, 0.45), true)
	var LINE := A.paint(Color(0.72, 0.66, 0.45), 0.0, 0.9, {"wear": 0.85, "dust": 0.6, "panel_scale": 0.0})
	var st_a := SurfaceTool.new()
	var st_b := SurfaceTool.new()
	var st_d := SurfaceTool.new()
	var st_r := SurfaceTool.new()
	var st_w := SurfaceTool.new()
	for st in [st_a, st_b, st_d, st_r, st_w]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var na := 0
	var nb := 0
	var nd := 0
	var nw := 0
	var dashes: Array = []
	for ci in curves.size():
		var cv: Dictionary = curves[ci]
		var d: PackedVector2Array = cv.d
		var w: float = cv.w
		if cv.dirt:
			_st_strip(st_d, d, w, 0.0, 0.05 + (0.004 if w >= 8.0 else 0.0))
			for sd in [-1.3, 1.3]:
				_st_strip(st_r, d, 0.5, sd, 0.058)
			nd += 1
			continue
		# 宽路（主干道）略高一层，路口处压住支路
		if w >= 10.0:
			_st_strip(st_a, d, w, 0.0, 0.068)
			na += 1
		else:
			_st_strip(st_b, d, w, 0.0, 0.064)
			nb += 1
		# 人行道：跨过其他道路处断开
		for sd in [-1.0, 1.0]:
			var off: float = sd * (w * 0.5 - 0.55)
			var run := PackedVector2Array()
			for i in d.size():
				var t := (d[mini(i + 1, d.size() - 1)] - d[maxi(i - 1, 0)]).normalized()
				var sp: Vector2 = d[i] + Vector2(-t.y, t.x) * off
				var ok := _rg.edge_dist(sp, ci) > -0.3 and absf(sp.x) < HALF + 10.0 and absf(sp.y) < HALF + 10.0
				if ok:
					run.append(d[i])
				if (not ok or i == d.size() - 1) and run.size() >= 2:
					_st_strip(st_w, run, 1.1, off, 0.15)
					nw += 1
				if not ok:
					run = PackedVector2Array()
		if w >= 10.0:
			var acc := 0.0
			for i in d.size() - 1:
				acc += d[i].distance_to(d[i + 1])
				if acc >= 5.0:
					acc = 0.0
					var t := (d[i + 1] - d[i]).normalized()
					if _rg.edge_dist(d[i], ci) > 1.0 and rng.randf() < 0.85:
						dashes.append(Transform3D(Basis(Vector3.UP, atan2(t.x, t.y)).scaled(Vector3(0.22, 0.02, 2.2)), Vector3(d[i].x, 0.08, d[i].y)))
	_st_commit(st_a, ASPH, na)
	_st_commit(st_b, ASPH2, nb)
	_st_commit(st_d, DIRT, nd)
	_st_commit(st_r, RUT, nd)
	_st_commit(st_w, WALK, nw)
	_multimesh(A.bevel_box(Vector3.ONE, 0.0), LINE, dashes, false)
	# 路面坑洼 / 油渍
	for k in (160 if not curves.is_empty() else 0):
		var p := _road_point(1.0)
		var dd := A.ground_decal(world, A.blob_tex(), Color(0.05, 0.05, 0.05, rng.randf_range(0.3, 0.6)), rng.randf_range(1.0, 3.0), Vector3(p.x, 0.075, p.z))
		dd.rotation.y = rng.randf() * TAU


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
	var L := PackedVector3Array()
	var R := PackedVector3Array()
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var n := Vector2(-t.y, t.x) * w * 0.5
		L.append(Vector3(pts[i].x + n.x, y, pts[i].y + n.y))
		R.append(Vector3(pts[i].x - n.x, y, pts[i].y - n.y))
	for i in pts.size() - 1:
		for v in [L[i], R[i], L[i + 1], R[i], R[i + 1], L[i + 1]]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x, v.z) * 0.1)
			st.add_vertex(v)
	st.generate_tangents()
	return st.commit()

## 落在已建桥面上（河堤留口用）
func _on_bridge(p: Vector2, pad: float) -> bool:
	for b: Array in bridges:
		if WC.seg_dist(p, b[0], b[1]) < float(b[2]) * 0.5 + pad:
			return true
	return false


func _build_river() -> void:
	bridges.clear()
	for r: Dictionary in rivers:
		_build_one_river(r)


func _build_one_river(r: Dictionary) -> void:
	var rp: PackedVector2Array = r.pts
	var rw: float = r.w
	var pts := _dense(rp, 2.0)
	if r.dry:
		# 干河床：浅色沙砾河底 + 深色河岸带 + 卵石
		var mi := MeshInstance3D.new()
		mi.mesh = _strip_mesh(pts, rw + 5.0, 0.012)
		mi.material_override = A.concrete(Color(0.36, 0.31, 0.24), false)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(mi)
		var bed := MeshInstance3D.new()
		bed.mesh = _strip_mesh(pts, rw, 0.02)
		bed.material_override = A.concrete(Color(0.6, 0.55, 0.44), false)
		bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(bed)
		var stones: Array = []
		for i in pts.size():
			if absf(pts[i].x) > HALF + 4.0 or absf(pts[i].y) > HALF + 4.0:
				continue
			for k in 3:
				var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
				var p := pts[i] + Vector2(-t.y, t.x) * rng.randf_range(-0.5, 0.5) * rw
				var sc := rng.randf_range(0.15, 0.55)
				stones.append(Transform3D(_rand_basis(30).scaled(Vector3(sc * 1.3, sc * 0.5, sc)), Vector3(p.x, sc * 0.1, p.y)))
		_multimesh(A.sphere(0.5, -1, 8), A.concrete(Color(0.58, 0.54, 0.48), false), stones, false)
		for k in 18:
			var i := rng.randi_range(4, maxi(4, pts.size() - 5))
			if i >= pts.size():
				break
			var p := pts[i]
			var q := Vector3(p.x + rng.randf_range(-4, 4), 0, p.y + rng.randf_range(-4, 4))
			if absf(q.x) < HALF - 3.0 and absf(q.z) < HALF - 3.0 and not on_road(Vector2(q.x, q.z), 3.0) and not _blocked(q, 2.0, false):
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
			if hit == null or absf(hit.x) > HALF + 6.0 or absf(hit.y) > HALF + 6.0:
				continue
			var rd := (rp[k + 1] - rp[k]).normalized()
			var dir: Vector2 = (sg[1] - sg[0]).normalized()
			var span := (rw + 6.0) / maxf(absf(dir.cross(rd)), 0.35) + 4.0
			_bridge(hit, dir, sg[2], span)
	# 湿河道：泥岸 → 水面 → 混凝土护堤（两侧，过桥处留口）
	var mud := MeshInstance3D.new()
	mud.mesh = _strip_mesh(pts, rw + 6.0, 0.014)
	mud.material_override = A.concrete(Color(0.22, 0.2, 0.17), false)
	mud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mud)
	var water := MeshInstance3D.new()
	water.mesh = _strip_mesh(pts, rw, 0.05)
	water.material_override = _water_mat()
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(water)
	var bank := StaticBody3D.new()
	bank.collision_layer = 8   # 只挡机甲（虫子能涉水）
	bank.collision_mask = 0
	world.add_child(bank)
	var curbs: Array = []
	var cpts := _dense(rp, 4.0)
	for i in cpts.size() - 1:
		var a := cpts[i]
		var b := cpts[i + 1]
		var m := (a + b) * 0.5
		if absf(m.x) > HALF + 8.0 or absf(m.y) > HALF + 8.0:
			continue
		var t := (b - a).normalized()
		var ang := atan2(t.x, t.y)
		for sd in [-1.0, 1.0]:
			var p: Vector2 = m + Vector2(-t.y, t.x) * sd * (rw * 0.5 + 0.4)
			if _on_bridge(p, 1.5) or in_lake(p, 0.5):
				continue
			var bs := Basis(Vector3.UP, ang)
			curbs.append(Transform3D(bs.scaled(Vector3(0.9, 0.7, a.distance_to(b) + 0.15)), Vector3(p.x, 0.35, p.y)))
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = Vector3(1.0, 3.0, a.distance_to(b) + 0.3)
			cs.shape = sh
			cs.transform = Transform3D(bs, Vector3(p.x, 1.5, p.y))
			bank.add_child(cs)
	_multimesh(A.bevel_box(Vector3.ONE, 0.05), A.concrete(Color(0.5, 0.48, 0.45), true), curbs)
	# 河面漂浮物 / 沉船
	for k in 6:
		var i := rng.randi_range(3, maxi(3, pts.size() - 4))
		if i + 1 >= pts.size():
			break
		var p := pts[i]
		if absf(p.x) < HALF - 4.0 and absf(p.y) < HALF - 4.0 and not _on_bridge(p, 6.0):
			var t := (pts[i + 1] - pts[i - 1]).normalized()
			var hull := Node3D.new()
			world.add_child(hull)
			hull.position = Vector3(p.x, 0.05, p.y)
			hull.rotation.y = atan2(t.x, t.y) + rng.randf_range(-0.4, 0.4)
			A.add(hull, A.bevel_box(Vector3(2.6, 0.9, 7.0), 0.3, 0.8), A.paint(Color(0.32, 0.3, 0.26), 0.5, 0.6, {"rust": 0.9, "wear": 0.5}), Vector3(0, 0.15, 0), Vector3(0, 0, rng.randf_range(-12, 12)))


func _bridge(hp: Vector2, dir: Vector2, w: float, span: float) -> void:
	var DECK := A.concrete(Color(0.44, 0.42, 0.4), true)
	var RAIL := A.paint(Color(0.35, 0.34, 0.32), 0.6, 0.55, {"rust": 0.6, "wear": 0.4, "panel_scale": 0.0})
	bridges.append([hp - dir * span * 0.5, hp + dir * span * 0.5, w])
	var ang := atan2(dir.x, dir.y)
	var root := Node3D.new()
	world.add_child(root)
	root.position = Vector3(hp.x, 0, hp.y)
	root.rotation.y = ang
	A.add(root, A.bevel_box(Vector3(w + 0.6, 0.35, span), 0.08), DECK, Vector3(0, 0.1, 0))
	for sd in [-1.0, 1.0]:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.25, 1.1, span)
		cs.shape = sh
		sb.add_child(cs)
		root.add_child(sb)
		sb.position = Vector3(sd * (w * 0.5 + 0.2), 0.75, 0)
		A.add(sb, A.bevel_box(Vector3(0.25, 0.12, span), 0.02), RAIL, Vector3(0, 0.5, 0))
		A.add(sb, A.bevel_box(Vector3(0.25, 0.1, span), 0.02), RAIL, Vector3(0, 0.05, 0))
		var n := int(span / 2.0)
		for q in n + 1:
			A.add(sb, A.bevel_box(Vector3(0.14, 1.1, 0.14), 0.02), RAIL, Vector3(0, 0, -span * 0.5 + q * span / n))
		var side: Vector2 = Vector2(dir.y, -dir.x) * sd * (w * 0.5 + 0.2)
		for q in 5:
			var pp: Vector2 = hp + side + dir * (-span * 0.5 + span * (q + 0.5) / 5.0)
			blocks.append(Rect2(pp.x - 0.6, pp.y - 0.6, 1.2, 1.2))

func _water_mat() -> StandardMaterial3D:
	var WM := StandardMaterial3D.new()
	WM.albedo_color = Color(0.07, 0.1, 0.1)
	WM.roughness = 0.08
	WM.metallic = 0.2
	WM.metallic_specular = 0.8
	WM.normal_enabled = true
	WM.normal_texture = A.noise_tex("hi_raw", 256)
	WM.normal_scale = 0.25
	WM.uv1_scale = Vector3(0.6, 0.6, 0.6)
	WM.uv1_triplanar = true
	WM.uv1_world_triplanar = true
	return WM

# ---------- 湖 ----------
func _build_lakes() -> void:
	if lakes.is_empty():
		return
	var WM := _water_mat()
	var MUD := A.concrete(Color(0.22, 0.2, 0.17), false)
	for l: Vector3 in lakes:
		A.add(world, A.cyl(l.z + 3.0, 0.02, l.z + 3.0, 40), MUD, Vector3(l.x, 0.012, l.y), Vector3.ZERO, Vector3.ONE, false)
	for l: Vector3 in lakes:
		A.add(world, A.cyl(l.z, 0.02, l.z, 40), WM, Vector3(l.x, 0.05, l.y), Vector3.ZERO, Vector3.ONE, false)
	var bank := StaticBody3D.new()
	bank.collision_layer = 8
	bank.collision_mask = 0
	world.add_child(bank)
	var curbs: Array = []
	var reeds: Array = []
	for li in lakes.size():
		var l: Vector3 = lakes[li]
		var n := maxi(8, int(TAU * l.z / 3.5))
		for i in n:
			var a := TAU * (i + 0.5) / n
			var d := Vector2(cos(a), sin(a))
			var p := Vector2(l.x, l.y) + d * (l.z + 0.4)
			var inside := false
			for lj in lakes.size():
				if lj != li and p.distance_to(Vector2(lakes[lj].x, lakes[lj].y)) < lakes[lj].z + 0.2:
					inside = true
			if inside:
				continue
			var t := Vector2(-d.y, d.x)
			var bs := Basis(Vector3.UP, atan2(t.x, t.y))
			var seg := TAU * l.z / n + 0.4
			curbs.append(Transform3D(bs.scaled(Vector3(0.7, 0.35, seg)), Vector3(p.x, 0.12, p.y)))
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = Vector3(1.0, 3.0, seg)
			cs.shape = sh
			cs.transform = Transform3D(bs, Vector3(p.x, 1.5, p.y))
			bank.add_child(cs)
			for k in 3:
				if rng.randf() < 0.5:
					var rp := p + d * rng.randf_range(0.5, 2.5) + t * rng.randf_range(-1.5, 1.5)
					var hh := rng.randf_range(0.5, 1.2)
					reeds.append(Transform3D(_rand_basis(15).scaled(Vector3(1, hh, 1)), Vector3(rp.x, hh * 0.5, rp.y)))
	_multimesh(A.bevel_box(Vector3.ONE, 0.08, 0.8), A.concrete(Color(0.4, 0.37, 0.33), false), curbs)
	var REED := StandardMaterial3D.new()
	REED.albedo_color = Color(0.45, 0.42, 0.26)
	REED.roughness = 1.0
	REED.cull_mode = BaseMaterial3D.CULL_DISABLED
	_multimesh(A.cyl(0.0, 1.0, 0.04, 3), REED, reeds, false)

func _strip_off(pts: PackedVector2Array, w: float, off: float, y: float) -> ArrayMesh:
	var q := PackedVector2Array()
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		q.append(pts[i] + Vector2(-t.y, t.x) * off)
	return _strip_mesh(q, w, y)

# ---------- 铁轨 ----------
func _build_rails() -> void:
	if rail_polys.is_empty():
		return
	var ties: Array = []
	var rails: Array = []
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for line: PackedVector2Array in rail_polys:
		_st_strip(st, line, 3.6, 0.0, 0.07)
		for k in line.size() - 1:
			var a := line[k]
			var b := line[k + 1]
			var t := (b - a).normalized()
			var ang := atan2(t.x, t.y)
			var bs := Basis(Vector3.UP, ang)
			var n := maxi(1, int(a.distance_to(b) / 0.9))
			for i in n:
				var p := a.lerp(b, (i + 0.5) / n)
				ties.append(Transform3D(bs.scaled(Vector3(2.6, 0.12, 0.28)), Vector3(p.x, 0.1, p.y)))
			var m := (a + b) * 0.5
			for sd in [-0.72, 0.72]:
				var q: Vector2 = m + Vector2(-t.y, t.x) * sd
				rails.append(Transform3D(bs.scaled(Vector3(0.1, 0.14, a.distance_to(b) + 0.05)), Vector3(q.x, 0.2, q.y)))
	_st_commit(st, A.concrete(Color(0.36, 0.34, 0.32), false), 1)
	_multimesh(A.bevel_box(Vector3.ONE, 0.02), A.paint(Color(0.3, 0.24, 0.18), 0.0, 0.9, {"wear": 0.4, "dust": 0.6, "panel_scale": 0.0}), ties, false)
	_multimesh(A.bevel_box(Vector3.ONE, 0.0), A.metal(Color(0.42, 0.38, 0.34)), rails, false)


func _wagon(p: Vector3, horiz: bool) -> void:
	var c: Color = [Color(0.42, 0.22, 0.15), Color(0.25, 0.3, 0.33), Color(0.36, 0.34, 0.26)][rng.randi() % 3]
	var size := Vector3(12.0, 3.2, 2.9) if horiz else Vector3(2.9, 3.2, 12.0)
	var sb := _static_box(size, p + Vector3(0, 2.1, 0), c, null, A.paint(c, 0.4, 0.7, {"rust": 0.7, "wear": 0.5, "panel_scale": 1.2}))
	for sd in [-4.0, 4.0]:
		A.add(sb, A.bevel_box(Vector3(2.0, 0.6, 1.6) if horiz else Vector3(1.6, 0.6, 2.0), 0.1), A.metal(), Vector3(sd, -1.75, 0) if horiz else Vector3(0, -1.75, sd))
	blocks.append(_rect_for(p, size + Vector3(1, 0, 1)))

# ---------- 山脊 ----------
func _build_ridges() -> void:
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
## 每局随机的部分：楼的外观细节、少数坍塌成残体、空地块里的车与碎石、院墙、工业区储罐与集装箱、军营围墙
func _build_blocks() -> void:
	# 建筑（轮廓来自城市群布局，与大地图一致）
	for b: Dictionary in layout.bldgs:
		_layout_building(b)
	# 街块里的杂物与围合
	for blk: Dictionary in layout.blocks:
		var poly: PackedVector2Array = blk.poly
		var c := WC.centroid(poly)
		if absf(c.x) > HALF - 4.0 or absf(c.y) > HALF - 4.0:
			continue
		match str(blk.ch):
			"D": _block_downtown(blk)
			"R": _block_residential(blk)
			"I": _block_industrial(blk)
			"H": _block_harbor(blk)
			"Y": _block_railyard(blk)
			"M": _block_military(blk)


## 按布局记录实例化一栋建筑（门脸朝向临街面）
func _layout_building(b: Dictionary) -> void:
	var c: Vector2 = b.c
	var p := Vector3(c.x, 0, c.y)
	var ang: float = b.ang
	var sx: float = b.sx
	var sz: float = b.sz
	var h: float = b.h
	match str(b.kind):
		"house", "farm":
			_house(p, Vector3(sx, h, sz), ang)
			_obb_blocks(c, ang, sx + 1.0, sz + 1.0)
		"wh":
			_warehouse(p, Vector3(sx, h, sz), Color(-1, 0, 0), ang)
			_obb_blocks(c, ang, sx + 2.0, sz + 2.0)
		"barn":
			_warehouse(p, Vector3(sx, h, sz), Color(0.42, 0.24, 0.17), ang)
			_obb_blocks(c, ang, sx + 2.0, sz + 2.0)
		_:
			if b.ch == "D" and rng.randf() < 0.14:
				# 坍塌的楼：矮残体 + 碎块堆
				var s2 := Vector3(sx * rng.randf_range(0.55, 0.8), rng.randf_range(2.5, 4.5), sz * rng.randf_range(0.55, 0.8))
				_building(p, s2, ang)
				_obb_blocks(c, ang, s2.x, s2.z)
				var u := Vector2(cos(ang), sin(ang))
				var rp := c + u * (s2.x * 0.5 + 1.5)
				_rubble_pile(Vector3(rp.x, 0, rp.y), 2.5)
				h = s2.y
			else:
				_building(p, Vector3(sx, h, sz), ang)
				_obb_blocks(c, ang, sx, sz)
	bldg_polys.append([WC.obb_corners(c, ang, sx, sz), str(b.ch)])


func _block_downtown(blk: Dictionary) -> void:
	# 内院 / 空地块：停车场里的废车
	for k in rng.randi_range(0, 2):
		var p := _spot_in_poly(blk.poly, 2.5)
		if p != Vector3.INF:
			_wreck_car(p)
	if rng.randf() < 0.3:
		var p := _spot_in_poly(blk.poly, 2.0)
		if p != Vector3.INF:
			_rubble_pile(p, 2.0)
			blocks.append(Rect2(p.x - 1.5, p.z - 1.5, 3, 3))


func _block_residential(blk: Dictionary) -> void:
	# 独栋小楼的院墙（不完整，顺着楼的朝向）
	var poly: PackedVector2Array = blk.poly
	var M := A.concrete(Color(0.56, 0.53, 0.48), false)
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
		_obb_blocks(mid, atan2(dir.y, dir.x), seg_len, 0.6)
	if rng.randf() < 0.25:
		var p := _spot_in_poly(poly, 2.5)
		if p != Vector3.INF:
			_wreck_car(p)


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
	# 集装箱堆场：顺着街块朝向成排、两层
	for k in roundi(WC.poly_area(poly) / 220.0):
		var p := _spot_in_poly(poly, 3.6, 12)
		if p == Vector3.INF:
			continue
		var rot := rad_to_deg(-ang) + (90.0 if rng.randf() < 0.7 else 0.0)
		_container(p, rot, cols[rng.randi() % cols.size()])
		if rng.randf() < 0.45:
			_container(p + Vector3(0, 2.4, 0), rot + rng.randf_range(-4, 4), cols[rng.randi() % cols.size()])
		_obb_blocks(Vector2(p.x, p.z), deg_to_rad(-rot) + PI * 0.5, 6.4, 2.8)
	# 岸桥吊机
	if rng.randf() < 0.4:
		var p := _spot_in_poly(poly, 5.0, 20)
		if p != Vector3.INF:
			var M := A.paint(Color(0.75, 0.45, 0.12), 0.5, 0.55, {"rust": 0.8, "wear": 0.6, "panel_scale": 0.8})
			var root := Node3D.new()
			world.add_child(root)
			root.position = p
			root.rotation.y = -ang
			for lx in [-3.5, 3.5]:
				for lz in [-3.5, 3.5]:
					_static_box(Vector3(0.7, 14.0, 0.7), Vector3(lx, 7.0, lz), Color.WHITE, root, M)
			A.add(root, A.bevel_box(Vector3(8.0, 1.2, 26.0), 0.1), M, Vector3(0, 14.4, 4.0))
			A.add(root, A.bevel_box(Vector3(3.0, 2.2, 3.0), 0.1), A.paint(Color(0.3, 0.3, 0.32), 0.4, 0.6), Vector3(0, 13.0, 9.0))
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
	var M_HESCO := A.paint(Color(0.55, 0.5, 0.38), 0.0, 0.95, {"wear": 0.3, "dust": 0.7, "grime": 0.6, "panel_scale": 0.4})
	var poly: PackedVector2Array = WC.inset(blk.poly, 1.5)
	if poly.size() < 3 or WC.poly_area(poly) < 300.0:
		return
	var m := poly.size()
	# 防爆墙围栏：沿街块边，每条边留一个门
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
			var sb := _static_box(Vector3(L / n - 0.1, 2.4, 1.2), pos, Color.WHITE, null, M_HESCO)
			sb.rotation.y = -atan2(dir.y, dir.x)
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


## 沿凸多边形边的铁丝网围栏（随机留缺口）
func _fence_poly(poly: PackedVector2Array, hgt: float, gap_chance: float) -> void:
	var inner := WC.inset(poly, 1.0)
	var m := inner.size()
	if m < 3:
		return
	var MF := A.paint(Color(0.32, 0.31, 0.29), 0.6, 0.6, {"panel_scale": 3.0, "rust": 0.6, "wear": 0.3})
	var MP := A.metal(Color(0.3, 0.29, 0.27))
	for i in m:
		var a := inner[i]
		var b := inner[(i + 1) % m]
		var L := a.distance_to(b)
		var n := int(L / 4.0)
		if n < 1:
			continue
		var dir := (b - a) / L
		for k in n:
			if rng.randf() < gap_chance:
				continue
			var q := a + dir * ((k + 0.5) * L / n)
			var pos := Vector3(q.x, hgt * 0.5, q.y)
			if _blocked(pos, 0.6) or _in_keep_clear(pos, L / n * 0.5 + 0.2) or absf(q.x) > HALF - 2.0 or absf(q.y) > HALF - 2.0:
				continue
			var sb := _static_box(Vector3(L / n, hgt, 0.12), pos, Color.WHITE, null, MF)
			A.add(sb, A.cyl(0.07, hgt + 0.4, 0.07, 6), MP, Vector3(-L / n * 0.5, 0.2, 0))
			sb.rotation.y = -atan2(dir.y, dir.x)
			_obb_blocks(q, atan2(dir.y, dir.x), L / n, 0.4)


# ---------- 农田 ----------
func _build_fields() -> void:
	var stalks: Array = []
	for fd: Dictionary in layout.fields:
		var poly: PackedVector2Array = fd.poly
		if poly.size() < 3:
			continue
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
					if absf(q.x) > HALF or absf(q.y) > HALF:
						continue
					if zone_at(Vector3(q.x, 0, q.y)) != "F" or in_river(q, 1.0) or on_road(q, 0.5):
						continue
					var hh := rng.randf_range(0.5, 1.1)
					stalks.append(Transform3D(_rand_basis(18).scaled(Vector3(1, hh, 1)), Vector3(q.x, hh * 0.5, q.y)))
			t += 2.2
		# 草垛
		for k in rng.randi_range(2, 5):
			var p := _spot_in_poly(poly, 1.6)
			if p != Vector3.INF and zone_at(p) == "F":
				var hs := _static_box(Vector3(1.6, 1.3, 2.4), p + Vector3(0, 0.6, 0), Color.WHITE, null, A.paint(Color(0.58, 0.5, 0.3), 0.0, 1.0, {"wear": 0.0, "dust": 0.5, "panel_scale": 0.0}))
				hs.rotation_degrees.y = rng.randf() * 180
				blocks.append(_rect_for(p, Vector3(2.4, 1, 2.4)))
	var STALK := StandardMaterial3D.new()
	STALK.albedo_color = Color(0.5, 0.44, 0.27)
	STALK.roughness = 1.0
	STALK.cull_mode = BaseMaterial3D.CULL_DISABLED
	_multimesh(A.cyl(0.0, 1.0, 0.05, 3), STALK, stalks, false)


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
	var trunks: Array = []
	var crowns: Array = []
	var dead_crowns: Array = []
	var rims: Array = []
	var pods: Array = []
	var reeds: Array = []
	var tree_body := StaticBody3D.new()
	tree_body.collision_layer = 1
	world.add_child(tree_body)
	var BARK := A.paint(Color(0.22, 0.17, 0.13), 0.0, 1.0, {"panel_scale": 0.0, "dust": 0.3, "wear": 0.0})
	var HEDGE := A.paint(Color(0.22, 0.24, 0.14), 0.0, 1.0, {"wear": 0.0, "dust": 0.4, "panel_scale": 0.0, "grime": 0.8})
	var BENCH := A.paint(Color(0.32, 0.25, 0.18), 0.0, 0.9, {"wear": 0.5, "dust": 0.5, "panel_scale": 0.0})
	# 悬崖岩体：5.5 米格点上层叠大岩块（不可通行），K 区边缘的岩块矮一些、稀一些
	_scatter_cliffs()
	# 公园中心：雕像基座 + 环形步道
	for c2: Vector2 in layout.parks:
		var c := Vector3(c2.x, 0, c2.y)
		if absf(c.x) < HALF - 12.0 and absf(c.z) < HALF - 12.0 and zone_at(c) == "P" and not _blocked(c, 8.0):
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
			if absf(p.x) > HALF - 3.0 or absf(p.z) > HALF - 3.0:
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
							_tree(p, trunks, crowns, dead_crowns, tree_body)
					elif roll < 0.38 and not _blocked(p, 2.5):
						var L := rng.randf_range(3.0, 6.0)
						var sb := _static_box(Vector3(0.6, 0.6, L), p + Vector3(0, 0.3, 0), Color.WHITE, null, BARK)
						sb.rotation_degrees.y = rng.randf() * 180.0
						blocks.append(_rect_for(p, Vector3(L, 1, L) * 0.7))
				"P":
					if roll < 0.12 and not _blocked(p, 1.0):
						_dead_tree(p)
						blocks.append(Rect2(p.x - 0.5, p.z - 0.5, 1, 1))
					elif roll < 0.145 and not _blocked(p, 1.2):
						var n := Node3D.new()
						world.add_child(n)
						n.position = p
						n.rotation.y = rng.randi_range(0, 3) * PI * 0.5
						A.add(n, A.bevel_box(Vector3(1.8, 0.08, 0.5), 0.02), BENCH, Vector3(0, 0.45, 0))
						A.add(n, A.bevel_box(Vector3(1.8, 0.4, 0.06), 0.02), BENCH, Vector3(0, 0.7, -0.25))
						for sx in [-0.8, 0.8]:
							A.add(n, A.bevel_box(Vector3(0.08, 0.45, 0.45), 0.01), A.metal(), Vector3(sx, 0.22, 0))
					elif roll < 0.163 and not _blocked(p, 3.0):
						var size := Vector3(rng.randf_range(4, 8), 0.9, 1.0) if rng.randf() < 0.5 else Vector3(1.0, 0.9, rng.randf_range(4, 8))
						var n := Node3D.new()
						world.add_child(n)
						A.add(n, A.bevel_box(size, 0.3, 0.85), HEDGE, p + Vector3(0, 0.45, 0))
						blocks.append(_rect_for(p, size))
				"W":
					if roll < 0.022 and not _blocked(p, 3.0):
						var r2 := rng.randf()
						if r2 < 0.4:
							_boulder(p, rng.randf_range(1.5, 4.5))
						elif r2 < 0.65:
							var size := Vector3(rng.randf_range(6, 12), rng.randf_range(1.4, 3.0), 0.8) if rng.randf() < 0.5 else Vector3(0.8, rng.randf_range(1.4, 3.0), rng.randf_range(6, 12))
							_static_box(size, p + Vector3(0, size.y * 0.5, 0), Color(0.52, 0.48, 0.44))
							blocks.append(_rect_for(p, size))
						elif r2 < 0.8:
							_dead_tree(p)
						elif r2 < 0.9:
							_wreck_car(p)
						else:
							var sz := Vector3(rng.randf_range(5, 9), rng.randf_range(2.0, 4.0), rng.randf_range(5, 9))
							_building(p, sz)
							blocks.append(_rect_for(p, sz))
				"C":
					if roll < 0.04 and not _blocked(p, 3.0):
						_crater(p, rims)
					elif roll < 0.05 and not _blocked(p, 3.5):
						_tank_wreck(p)
					elif roll < 0.052 and not _blocked(p, 1.5):
						_fire_barrel(p)
				"S":
					if roll < 0.15:
						var d := A.ground_decal(world, A.cloud_tex(), Color(0.13, 0.08, 0.15, rng.randf_range(0.45, 0.75)), rng.randf_range(4.0, 9.0), p + Vector3(0, 0.02 + rng.randf() * 0.01, 0))
						d.rotation.y = rng.randf() * TAU
					if rng.randf() < 0.064 and not _blocked(p, 1.2):
						_bug_spire(p, rng.randf_range(2.5, 7.0))
					for k in 3:
						if rng.randf() < 0.12:
							var q := p + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5))
							if not on_road(Vector2(q.x, q.z)):
								var s := rng.randf_range(0.15, 0.45)
								pods.append(Transform3D(Basis.IDENTITY.scaled(Vector3(s, s * 0.7, s)), q + Vector3(0, s * 0.25, 0)))
				"L":
					if roll < 0.3 and not in_wet(Vector2(p.x, p.z), 0.0) and not on_road(Vector2(p.x, p.z), 0.5):
						for k in rng.randi_range(3, 7):
							var q := p + Vector3(rng.randf_range(-1.4, 1.4), 0, rng.randf_range(-1.4, 1.4))
							var hh := rng.randf_range(0.5, 1.3)
							reeds.append(Transform3D(_rand_basis(15).scaled(Vector3(1, hh, 1)), Vector3(q.x, hh * 0.5, q.z)))
					elif roll < 0.33 and not _blocked(p, 1.0):
						_dead_tree(p)
					elif roll < 0.36:
						var d := A.ground_decal(world, A.blob_tex(), Color(0.06, 0.08, 0.07, 0.55), rng.randf_range(2.5, 6.0), p + Vector3(0, 0.02, 0))
						d.rotation.y = rng.randf() * TAU
				"D", "R", "I", "H", "Y":
					if roll < 0.004 and not _blocked(p, 2.0):
						_rubble_pile(p, 2.0)
						blocks.append(Rect2(p.x - 1.5, p.z - 1.5, 3, 3))
		gz += step
	var NEEDLE := A.paint(Color(0.15, 0.2, 0.12), 0.0, 1.0, {"panel_scale": 0.0, "dust": 0.45, "wear": 0.0, "grime": 0.7})
	var BROWN := A.paint(Color(0.32, 0.25, 0.15), 0.0, 1.0, {"panel_scale": 0.0, "dust": 0.45, "wear": 0.0, "grime": 0.7})
	_multimesh(A.cyl(0.14, 1.0, 0.24, 6), BARK, trunks)
	_multimesh(A.cyl(0.0, 1.0, 1.0, 7), NEEDLE, crowns)
	_multimesh(A.cyl(0.0, 1.0, 1.0, 7), BROWN, dead_crowns)
	_multimesh(A.bevel_box(Vector3.ONE, 0.15, 0.8), A.concrete(Color(0.36, 0.32, 0.28), false), rims)
	_multimesh(A.sphere(1.0, -1, 8), A.emit(Color(0.65, 0.3, 1.0), 1.6), pods, false)
	var REED := StandardMaterial3D.new()
	REED.albedo_color = Color(0.45, 0.42, 0.26)
	REED.roughness = 1.0
	REED.cull_mode = BaseMaterial3D.CULL_DISABLED
	_multimesh(A.cyl(0.0, 1.0, 0.04, 3), REED, reeds, false)


func _tree(p: Vector3, trunks: Array, crowns: Array, dead_crowns: Array, body: StaticBody3D) -> void:
	var h := rng.randf_range(5.0, 10.0)
	var cr := h * rng.randf_range(0.2, 0.27)
	trunks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1, h * 0.45, 1)), p + Vector3(0, h * 0.225, 0)))
	var dead := rng.randf() < 0.3
	for t in 3:
		var y := h * (0.3 + t * 0.22)
		var s := cr * (1.0 - t * 0.26)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-5, 5)))
		(dead_crowns if dead else crowns).append(Transform3D(b.scaled(Vector3(s, h * 0.34, s)), p + Vector3(0, y + h * 0.17, 0)))
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
	var d := A.ground_decal(world, A.blob_tex(), Color(0.05, 0.045, 0.04, 0.9), rad * 2.4, p + Vector3(0, 0.02, 0))
	d.rotation.y = rng.randf() * TAU
	var d2 := A.ground_decal(world, A.blob_tex(), Color(0.17, 0.14, 0.11, 0.8), rad * 1.3, p + Vector3(0, 0.025, 0))
	d2.rotation.y = rng.randf() * TAU
	var n := int(rad * 4.0)
	for i in n:
		var a := TAU * i / n + rng.randf_range(-0.15, 0.15)
		var rr := rad * rng.randf_range(0.85, 1.15)
		var sc := rng.randf_range(0.25, 0.7) * rad * 0.35
		rims.append(Transform3D(_rand_basis(35).scaled(Vector3(sc * 1.4, sc * 0.6, sc)), p + Vector3(cos(a) * rr, sc * 0.15, sin(a) * rr)))


func _tank_wreck(p: Vector3) -> void:
	if rng.randf() < 0.5:
		var M := A.paint(Color(0.2, 0.2, 0.17), 0.4, 0.8, {"rust": 0.8, "wear": 0.7, "grime": 1.0})
		var sb := _static_box(Vector3(3.4, 1.3, 6.2), p + Vector3(0, 0.9, 0), Color.WHITE, null, M)
		sb.rotation_degrees.y = rng.randf() * 180.0
		A.add(sb, A.bevel_box(Vector3(2.3, 0.9, 2.6), 0.2, 0.8), M, Vector3(0.2, 1.05, -0.4), Vector3(0, rng.randf_range(-40, 40), 8))
		A.add(sb, A.cyl(0.12, 4.0, 0.14, 8), M, Vector3(0.2, 1.3, 1.8), Vector3(rng.randf_range(70, 100), 0, 0))
		blocks.append(_rect_for(p, Vector3(6, 1, 6)))
	else:
		_wreck_car(p)


func _park_statue(c: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 2.4
	sh.height = 5.0
	cs.shape = sh
	cs.position.y = 2.5
	sb.add_child(cs)
	world.add_child(sb)
	sb.position = c
	A.add(sb, A.cyl(2.6, 0.6, 2.8, 20), A.concrete(Color(0.55, 0.53, 0.5)), Vector3(0, 0.3, 0))
	A.add(sb, A.bevel_box(Vector3(1.4, 2.2, 1.4), 0.08), A.concrete(Color(0.5, 0.48, 0.46)), Vector3(0, 1.7, 0))
	A.add(sb, A.bevel_box(Vector3(0.7, 1.8, 0.5), 0.1, 0.7), A.paint(Color(0.3, 0.38, 0.33), 0.7, 0.45, {"rust": 0.4, "wear": 0.5, "panel_scale": 0.0}), Vector3(0, 3.7, 0), Vector3(0, 0, 14))
	blocks.append(Rect2(c.x - 3, c.z - 3, 6, 6))
	A.add(world, A.cyl(7.5, 0.03, 7.5, 32), A.concrete(Color(0.5, 0.48, 0.44), true), c + Vector3(0, 0.02, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(world, A.cyl(5.5, 0.05, 5.5, 32), A.ground(), c + Vector3(0, 0.03, 0), Vector3.ZERO, Vector3.ONE, false)
	_poi_lamp(c + Vector3(6.5, 0, 6.5), Color(1.0, 0.8, 0.55))


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


## 悬崖岩体：层叠的大岩块（不可通行），外缘参差
func _scatter_cliffs() -> void:
	var ROCK := A.concrete(Color(0.4, 0.34, 0.28), false)
	var ROCK2 := A.concrete(Color(0.33, 0.28, 0.23), false)
	var step := 5.5
	var x := -HALF + step * 0.5
	while x < HALF:
		var z := -HALF + step * 0.5
		while z < HALF:
			var p := Vector3(x + rng.randf_range(-1.5, 1.5), 0, z + rng.randf_range(-1.5, 1.5))
			z += step
			if absf(p.x) > HALF - 2.0 or absf(p.z) > HALF - 2.0 or zone_at(p) != "K":
				continue
			var edge := false
			for o in [Vector3(step, 0, 0), Vector3(-step, 0, 0), Vector3(0, 0, step), Vector3(0, 0, -step)]:
				if zone_at(p + o) != "K":
					edge = true
			if (edge and rng.randf() < 0.35) or _blocked(p, 2.5):
				continue
			var hgt := rng.randf_range(6.0, 13.0) * (0.6 if edge else 1.0)
			var sz := Vector3(rng.randf_range(5.5, 8.0), hgt, rng.randf_range(5.5, 8.0))
			var sb := _static_box(sz, p + Vector3(0, hgt * 0.5, 0), Color.WHITE, null, ROCK)
			sb.rotation_degrees = Vector3(rng.randf_range(-4, 4), rng.randf() * 90.0, rng.randf_range(-4, 4))
			A.add(sb, A.bevel_box(Vector3(sz.x * 0.7, hgt * 0.4, sz.z * 0.8), 0.4, 0.7), ROCK2, Vector3(rng.randf_range(-1, 1), hgt * 0.55, rng.randf_range(-1, 1)), Vector3(0, rng.randf() * 90, rng.randf_range(-8, 8)))
			blocks.append(_rect_for(p, sz * 0.95))
			if rng.randf() < 0.12:
				var q := p + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
				if not _blocked(q, 2.0):
					_boulder(q, rng.randf_range(1.2, 2.5))
		x += step


# ---------- 建筑部件 ----------
func _house(p: Vector3, sz: Vector3, rot := 0.0) -> void:
	var c: Color = [Color(0.55, 0.5, 0.43), Color(0.5, 0.46, 0.42), Color(0.46, 0.38, 0.3), Color(0.52, 0.52, 0.48)][rng.randi() % 4]
	var sb := _bldg_body(sz, p + Vector3(0, sz.y * 0.5, 0))
	sb.rotation.y = -rot
	_ibox(sb, sz, 0.01, A.concrete(c))
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var hy := sz.y * 0.5
	var M_DARK := A.concrete(c.darkened(0.35), false)
	_ibox(sb, Vector3(sz.x + 0.1, 0.45, sz.z + 0.1), 0.03, M_DARK, Vector3(0, -hy + 0.22, 0))
	var M_WIN := A.paint(Color(0.06, 0.07, 0.08), 0.3, 0.25)
	var M_FR := A.concrete(c.lightened(0.12), false)
	for sd in [-1.0, 1.0]:
		for k in 2:
			var x := (k - 0.5) * hx
			_ibox(sb, Vector3(1.1, 1.1, 0.08), 0.01, M_FR, Vector3(x, 0.2, sd * (hz + 0.02)))
			_ibox(sb, Vector3(0.9, 0.9, 0.1), 0.01, M_WIN, Vector3(x, 0.2, sd * (hz + 0.03)))
	_ibox(sb, Vector3(1.1, 2.0, 0.1), 0.01, A.paint(Color(0.3, 0.22, 0.16), 0.0, 0.8, {"wear": 0.6, "dust": 0.4}), Vector3(hx * 0.5, -hy + 1.0, hz + 0.04))
	# 双坡屋顶
	var roof_c: Color = [Color(0.35, 0.18, 0.14), Color(0.25, 0.26, 0.28), Color(0.4, 0.3, 0.22)][rng.randi() % 3]
	var rh: float = min(sz.x, sz.z) * 0.32
	if rng.randf() < 0.25:
		# 塌了一半的屋顶：只剩平顶
		_ibox(sb, Vector3(sz.x * 0.6, 0.12, sz.z + 0.2), 0.02, A.concrete(roof_c, false), Vector3(-hx * 0.35, hy + 0.06, 0), Vector3(0, 0, 6))
	else:
		# 单位三角棱柱按房子尺寸缩放（全图共用一个网格）
		var outline := PackedVector2Array([Vector2(-0.5, 0), Vector2(0, 1), Vector2(0.5, 0)])
		_imesh(sb, A.prism(outline, 1.0, 0.01), A.paint(roof_c, 0.1, 0.85, {"wear": 0.4, "dust": 0.5, "rust": 0.3, "panel_scale": 0.6}), Vector3(0, hy, 0), Vector3.ZERO, Vector3(sz.x + 0.7, rh, sz.z + 0.5))
		if rng.randf() < 0.6:
			_ibox(sb, Vector3(0.6, 1.2, 0.6), 0.04, M_DARK, Vector3(hx * 0.45, hy + rh * 0.6, hz * 0.3))

func _warehouse(p: Vector3, sz: Vector3, col := Color(-1, 0, 0), rot := 0.0) -> void:
	var c: Color = col if col.r >= 0.0 else [Color(0.42, 0.44, 0.42), Color(0.5, 0.45, 0.36), Color(0.36, 0.4, 0.44)][rng.randi() % 3]
	var M := A.paint(c, 0.45, 0.6, {"wear": 0.45, "rust": 0.6, "dust": 0.4, "panel_scale": 1.6, "grime": 0.6})
	var sb := _bldg_body(sz, p + Vector3(0, sz.y * 0.5, 0))
	sb.rotation.y = -rot
	_ibox(sb, sz, 0.01, M)
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var hy := sz.y * 0.5
	# 波纹墙肋
	var MR := A.paint(c.darkened(0.2), 0.5, 0.6, {"wear": 0.4, "rust": 0.7, "dust": 0.3, "panel_scale": 0.0})
	var n := int(sz.x / 2.0)
	for k in n + 1:
		for sd in [-1.0, 1.0]:
			_ibox(sb, Vector3(0.18, sz.y, 0.12), 0.02, MR, Vector3(-hx + k * sz.x / n, 0, sd * (hz + 0.05)), Vector3.ZERO, Vector3.ONE, false)
	# 拱形屋顶（压扁的圆柱）
	_imesh(sb, A.cyl(1.0, 1.0, 1.0, 20), A.paint(c.darkened(0.12), 0.5, 0.55, {"wear": 0.4, "rust": 0.8, "dust": 0.5, "panel_scale": 1.2}),
		Vector3(0, hy, 0), Vector3(0, 0, 90), Vector3(sz.z * 0.12, sz.x + 0.3, sz.z * 0.5))
	# 大门 + 装卸台
	_ibox(sb, Vector3(sz.x * 0.3, sz.y * 0.6, 0.12), 0.02, A.metal(Color(0.28, 0.29, 0.28)), Vector3(0, -hy + sz.y * 0.3, hz + 0.1), Vector3.ZERO, Vector3.ONE, false)
	_ibox(sb, Vector3(sz.x * 0.4, 0.9, 1.6), 0.05, A.concrete(Color(0.5, 0.48, 0.45), false), Vector3(0, -hy + 0.45, hz + 0.8))
	A.stencil(sb, "BLD-%02d" % rng.randi_range(1, 40), Vector3(-hx * 0.6, hy * 0.5, hz + 0.12), Vector3.ZERO, 0.02, Color(0.85, 0.82, 0.72, 0.6))

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
	A.add(sb, A.cyl(rad, h, rad, 28), A.paint(c, 0.5, 0.55, {"wear": 0.5, "rust": 0.7, "dust": 0.4, "panel_scale": 0.8}), Vector3(0, h * 0.5, 0))
	A.add(sb, A.cyl(rad * 0.15, rad * 0.35, rad, 28), A.paint(c.darkened(0.15), 0.5, 0.55, {"rust": 0.8}), Vector3(0, h + rad * 0.17, 0))
	for k in 3:
		A.add(sb, A.cyl(rad + 0.04, 0.12, rad + 0.04, 28), A.metal(Color(0.25, 0.25, 0.24)), Vector3(0, h * (0.25 + k * 0.25), 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(sb, A.bevel_box(Vector3(0.5, h, 0.08), 0.01), A.metal(Color(0.2, 0.2, 0.2)), Vector3(0, h * 0.5, rad + 0.1))
	blocks.append(Rect2(p.x - rad - 1, p.z - rad - 1, rad * 2 + 2, rad * 2 + 2))

func _chimney(p: Vector3) -> void:
	var sb := _static_box(Vector3(3.0, 1.0, 3.0), p + Vector3(0, 0.5, 0), Color(0.45, 0.42, 0.4))
	var M := A.paint(Color(0.48, 0.32, 0.25), 0.0, 0.9, {"wear": 0.3, "grime": 0.9, "dust": 0.3, "panel_scale": 0.5})
	A.add(sb, A.cyl(0.9, 22.0, 1.3, 16), M, Vector3(0, 11.0, 0))
	for k in 3:
		A.add(sb, A.cyl(1.05 - k * 0.08, 0.3, 1.05 - k * 0.08, 16), A.paint(Color(0.6, 0.55, 0.5), 0.0, 0.9, {"panel_scale": 0.0}), Vector3(0, 6 + k * 6, 0))
	A.emitter(sb, Vector3(0, 22.5, 0), {"amount": 8, "life": 6.0, "size": 2.5, "tex": A.smoke_tex(), "additive": false, "vmin": 0.6, "vmax": 1.2,
		"gravity": Vector3(0.6, 0.4, 0.2), "c0": Color(0.15, 0.13, 0.12, 0.45), "c1": Color(0.3, 0.28, 0.26, 0.0), "grow0": 0.6, "grow1": 3.0})
	blocks.append(Rect2(p.x - 2, p.z - 2, 4, 4))

func _bunker(p: Vector3) -> void:
	var sz := Vector3(6.0, 2.6, 5.0)
	var sb := _static_box(sz, p + Vector3(0, sz.y * 0.5, 0), Color(0.48, 0.47, 0.43))
	A.add(sb, A.bevel_box(Vector3(4.0, 0.35, 0.2), 0.02), A.paint(Color(0.03, 0.03, 0.03), 0.0, 1.0), Vector3(0, 0.4, sz.z * 0.5 + 0.02))
	A.add(sb, A.bevel_box(Vector3(sz.x + 0.6, 0.4, sz.z + 0.6), 0.12), A.concrete(Color(0.42, 0.41, 0.38), false), Vector3(0, sz.y * 0.5 + 0.2, 0))
	for k in 3:
		A.add(sb, A.bevel_box(Vector3(1.4, 0.45, 0.7), 0.15), A.paint(Color(0.5, 0.45, 0.32), 0.0, 1.0, {"panel_scale": 0.0, "dust": 0.6}), Vector3(-1.6 + k * 1.6, sz.y * 0.5 + 0.6, sz.z * 0.5 - 0.4))
	blocks.append(_rect_for(p, sz + Vector3(2, 0, 2)))

func _watchtower(p: Vector3) -> void:
	var sb := _static_box(Vector3(2.4, 1.1, 2.4), p + Vector3(0, 6.2, 0), Color(0.4, 0.38, 0.33), null, A.paint(Color(0.38, 0.36, 0.3), 0.2, 0.8, {"wear": 0.6, "rust": 0.4, "dust": 0.5}))
	var M := A.metal(Color(0.25, 0.25, 0.24))
	for lx in [-1.0, 1.0]:
		for lz in [-1.0, 1.0]:
			A.add(sb, A.cyl(0.08, 6.2, 0.1, 6), M, Vector3(lx, -3.1, lz))
	A.add(sb, A.bevel_box(Vector3(2.8, 0.1, 2.8), 0.02), A.paint(Color(0.3, 0.28, 0.24), 0.3, 0.8), Vector3(0, 1.6, 0), Vector3(3, 0, 2))
	for lx in [-1.15, 1.15]:
		for lz in [-1.15, 1.15]:
			A.add(sb, A.cyl(0.05, 1.1, 0.05, 5), M, Vector3(lx, 1.05, lz))
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
	var M := A.concrete(Color(0.46, 0.42, 0.37), false)
	for k in 3:
		var ss := s * rng.randf_range(0.5, 0.9)
		A.add(sb, A.bevel_box(Vector3(ss * 1.2, ss * 0.8, ss), ss * 0.3, 0.7), M, Vector3(rng.randf_range(-0.3, 0.3) * s, ss * 0.3, rng.randf_range(-0.3, 0.3) * s), Vector3(rng.randf_range(-15, 15), rng.randf() * 360, rng.randf_range(-15, 15)))
	blocks.append(Rect2(p.x - s * 0.7, p.z - s * 0.7, s * 1.4, s * 1.4))

func _dead_tree(p: Vector3) -> void:
	var n := Node3D.new()
	world.add_child(n)
	n.position = p
	var M := A.paint(Color(0.24, 0.2, 0.16), 0.0, 1.0, {"panel_scale": 0.0, "dust": 0.3})
	var h := rng.randf_range(3.0, 6.0)
	A.add(n, A.cyl(0.08, h, 0.22, 6), M, Vector3(0, h * 0.5, 0), Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6)))
	for k in rng.randi_range(3, 5):
		var y := h * rng.randf_range(0.5, 0.9)
		var a := rng.randf() * 360.0
		A.add(n, A.cyl(0.02, h * 0.35, 0.06, 5), M, Vector3(0, y, 0), Vector3(rng.randf_range(35, 60), a, 0))

func _rubble_pile(p: Vector3, s: float) -> void:
	var M := A.concrete(Color(0.52, 0.49, 0.45), false)
	var n := Node3D.new()
	world.add_child(n)
	n.position = p
	for k in 7:
		var ss := rng.randf_range(0.3, 0.9) * s * 0.5
		A.add(n, A.bevel_box(Vector3(ss * 1.4, ss * 0.6, ss), 0.06), M, Vector3(rng.randf_range(-s, s) * 0.6, ss * 0.2, rng.randf_range(-s, s) * 0.6), Vector3(rng.randf_range(-25, 25), rng.randf() * 360, rng.randf_range(-25, 25)))



func _spawn_extracts(drop: Vector3) -> void:
	var cands: Array = []
	for e: Array in MAP.extracts:
		cands.append([e[0], Vector3(e[1], 0, e[2])])
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
		z.setup("撤离点 %s · %s" % [letters[k], c[0]], Color(0.3, 1.0, 0.5), 8.0)
		extracts.append(z)


## 初始虫群：战区在 GameData.SPAWNS 里登记了分布时按登记的生成（script 可接管整个布置），否则用下面的默认分布
func _spawn_initial_bugs(drop: Vector3) -> void:
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
	for j in 9:
		for i in 9:
			var t: String = zones[j][i]
			var r := _cell_rect(i, j)
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
	for j in 9:
		for i in 9:
			var t: String = zones[j][i]
			var r := _cell_rect(i, j)
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
	if mech != null and is_instance_valid(mech) and not mech.dead:
		_foes.append(mech)
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
		var a := randf() * TAU
		var d := sqrt(randf()) * radius
		var p := home + Vector3(cos(a) * d, 0, sin(a) * d)
		if absf(p.x) > HALF - 8.0 or absf(p.z) > HALF - 8.0:
			continue
		if in_lake(Vector2(p.x, p.z), 1.0) or not _patrol_free(p, 1.6):
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
## 把挂在静态体上的大量重复小网格（窗户、窗框、墙肋……）合并成分块 MultiMesh，节点数降一个数量级
func _bake_static() -> void:
	_flush_inst()
	var groups := {}
	var stack: Array = [world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			if ch is MeshInstance3D:
				var par: Node = ch.get_parent()
				if not (par == world or (par is StaticBody3D and not par.is_in_group("lootboxes"))):
					continue
				var mi: MeshInstance3D = ch
				if mi.material_overlay != null or mi.mesh == null:
					continue
				var t: Transform3D = mi.global_transform
				var key := [mi.mesh.get_rid(), mi.material_override.get_rid() if mi.material_override else RID(), mi.cast_shadow, floori(t.origin.x / 48.0), floori(t.origin.z / 48.0)]
				var ks := str(key)
				if not groups.has(ks):
					groups[ks] = {"mesh": mi.mesh, "mat": mi.material_override, "shadow": mi.cast_shadow, "items": []}
				groups[ks].items.append([mi, t])
			elif ch is Node3D and not (ch is CPUParticles3D) and not ch.is_in_group("lootboxes") and not ch.is_in_group("bugs"):
				stack.append(ch)
	var removed := 0
	for ks in groups:
		var g: Dictionary = groups[ks]
		if g.items.size() < 4:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = g.mesh
		mm.instance_count = g.items.size()
		for i in g.items.size():
			mm.set_instance_transform(i, g.items[i][1])
			g.items[i][0].queue_free()
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = g.mat
		mmi.cast_shadow = g.shadow
		world.add_child(mmi)
		removed += g.items.size()
	print("[raid] baked %d static meshes into multimeshes" % removed)


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
