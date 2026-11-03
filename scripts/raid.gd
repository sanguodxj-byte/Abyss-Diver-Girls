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

var rng := RandomNumberGenerator.new()
var mech
var camera: Camera3D
var cam_zoom := 0.9  # 鼠标滚轮缩放（0.5 近景看机甲细节 ~ 1.3 远景）
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
	_load_map()
	_build_environment()
	_build_ground()
	var drop := _build_map()
	world_link = WorldLinkScript.new()
	world_link.name = "WorldLink"
	add_child(world_link)
	world_link.setup(self)
	if not transit.is_empty():
		drop = world_link.entry_point(str(transit.get("edge", "")), drop)
	_build_map_texture()
	world_link.paint_map(map_tex)
	_build_zone_ground()
	_run_ext_build(drop)
	_spawn_extracts(drop)
	_spawn_initial_bugs(drop)
	_bake_static()

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
	camera.global_position = drop + CAM_OFFSET
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
		var s: Script = load(str(path))
		if s == null:
			push_error("行动扩展脚本无法加载：%s" % path)
			continue
		for m in s.get_script_method_list():
			if m.name == "build":
				s.call("build", self, drop)
				break


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


func _blocked(p: Vector3, r: float, terrain := true) -> bool:
	var probe := Rect2(p.x - r, p.z - r, r * 2, r * 2)
	for b in blocks:
		if b.intersects(probe):
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


func _building(p: Vector3, size: Vector3) -> void:
	# 废弃城区楼房：暖灰混凝土外墙 + 深色勒脚 + 转角壁柱 + 窗框窗台 + 带女儿墙的沥青屋顶 + 屋顶设备
	var c := Color(0.5, 0.46, 0.4).lerp(Color(0.42, 0.38, 0.33), rng.randf())
	if rng.randf() < 0.3:
		c = Color(0.46, 0.4, 0.33)  # 少数砖黄色楼
	var sb := _static_box(size, p + Vector3(0, size.y * 0.5, 0), c, null, A.concrete(c))
	var hy := size.y * 0.5
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var M_DARK := A.concrete(c.darkened(0.35), false)
	var M_TRIM := A.concrete(c.lightened(0.08), false)
	# 勒脚
	A.add(sb, A.bevel_box(Vector3(size.x + 0.12, 0.55, size.z + 0.12), 0.03), M_DARK, Vector3(0, -hy + 0.27, 0))
	# 转角壁柱
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			A.add(sb, A.bevel_box(Vector3(0.34, size.y + 0.02, 0.34), 0.04), M_TRIM, Vector3(sx * (hx - 0.1), 0.01, sz * (hz - 0.1)))
	# 楼层分隔带
	var floors := int(size.y / 1.6)
	for f in range(1, floors + 1):
		var y := -hy + f * 1.6 - 0.1
		if y > hy - 0.3:
			break
		A.add(sb, A.bevel_box(Vector3(size.x + 0.08, 0.12, size.z + 0.08), 0.03), M_DARK, Vector3(0, y, 0))
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
						A.add(sb, A.bevel_box(Vector3(0.82, 0.86, 0.05), 0.01), M_TRIM, pos + (Vector3(0, 0, sd * 0.01) if axis == 0 else Vector3(sd * 0.01, 0, 0)), rot, Vector3.ONE, false)
						A.add(sb, A.bevel_box(Vector3(0.66, 0.7, 0.06), 0.01), wm, pos + (Vector3(0, 0, sd * 0.03) if axis == 0 else Vector3(sd * 0.03, 0, 0)), rot, Vector3.ONE, false)
						A.add(sb, A.bevel_box(Vector3(0.9, 0.07, 0.16), 0.01), M_TRIM, pos + Vector3(0, -0.45, 0) + (Vector3(0, 0, sd * 0.07) if axis == 0 else Vector3(sd * 0.07, 0, 0)), rot, Vector3.ONE, false)
		# 一层卷帘门
		var dz := (hz + 0.02) * (1 if rng.randf() < 0.5 else -1)
		A.add(sb, A.bevel_box(Vector3(min(2.2, size.x * 0.4), 1.25, 0.08), 0.02), A.metal(Color(0.3, 0.31, 0.3)), Vector3(rng.randf_range(-hx, hx) * 0.4, -hy + 0.75, dz), Vector3.ZERO, Vector3.ONE, false)
	# 屋顶：深色沥青屋面 + 女儿墙（随机残缺）
	A.add(sb, A.bevel_box(Vector3(size.x - 0.3, 0.06, size.z - 0.3), 0.02), A.concrete(Color(0.2, 0.19, 0.18), false), Vector3(0, hy + 0.02, 0), Vector3.ZERO, Vector3.ONE, false)
	var ph := 0.45
	for sd: float in [-1.0, 1.0]:
		var segs := 3
		for k in segs:
			if rng.randf() < 0.18:
				continue
			var len_x := size.x / segs
			var hh := ph * rng.randf_range(0.55, 1.0)
			A.add(sb, A.bevel_box(Vector3(len_x, hh, 0.22), 0.03), M_TRIM, Vector3(-hx + (k + 0.5) * len_x, hy + hh * 0.5, sd * (hz - 0.11)))
			var len_z := size.z / segs
			hh = ph * rng.randf_range(0.55, 1.0)
			A.add(sb, A.bevel_box(Vector3(0.22, hh, len_z), 0.03), M_TRIM, Vector3(sd * (hx - 0.11), hy + hh * 0.5, -hz + (k + 0.5) * len_z))
	# 屋顶设备：空调外机、通风管、水箱、检修口
	var M_UNIT := A.paint(Color(0.55, 0.56, 0.54), 0.4, 0.55, {"wear": 0.5, "rust": 0.5, "dust": 0.4})
	for k in rng.randi_range(1, 3):
		var up := Vector3(rng.randf_range(-hx, hx) * 0.55, hy + 0.32, rng.randf_range(-hz, hz) * 0.55)
		A.add(sb, A.bevel_box(Vector3(0.95, 0.6, 0.75), 0.05), M_UNIT, up, Vector3(0, rng.randf() * 90.0, 0))
		A.add(sb, A.cyl(0.26, 0.04, 0.26, 12), A.metal(Color(0.08, 0.08, 0.08)), up + Vector3(0, 0.31, 0), Vector3.ZERO, Vector3.ONE, false)
	for k in rng.randi_range(1, 3):
		var vp := Vector3(rng.randf_range(-hx, hx) * 0.65, hy + 0.35, rng.randf_range(-hz, hz) * 0.65)
		A.add(sb, A.cyl(0.12, 0.7, 0.12, 8), A.metal(Color(0.4, 0.4, 0.4)), vp)
		A.add(sb, A.cyl(0.18, 0.08, 0.18, 8), A.metal(Color(0.25, 0.25, 0.25)), vp + Vector3(0, 0.38, 0), Vector3.ZERO, Vector3.ONE, false)
	if size.x * size.z > 30.0 and rng.randf() < 0.6:
		var tp := Vector3(rng.randf_range(-hx, hx) * 0.45, hy, rng.randf_range(-hz, hz) * 0.45)
		for lx in [-0.5, 0.5]:
			for lz in [-0.5, 0.5]:
				A.add(sb, A.cyl(0.05, 0.8, 0.05, 5), A.metal(Color(0.2, 0.2, 0.2)), tp + Vector3(lx, 0.4, lz))
		A.add(sb, A.cyl(0.75, 1.1, 0.75, 16), A.paint(Color(0.5, 0.42, 0.32), 0.5, 0.6, {"rust": 0.8, "wear": 0.6}), tp + Vector3(0, 1.35, 0))
		A.add(sb, A.cyl(0.05, 0.25, 0.78, 16), A.metal(Color(0.3, 0.27, 0.24)), tp + Vector3(0, 2.02, 0))
	else:
		A.add(sb, A.bevel_box(Vector3(0.8, 0.25, 0.8), 0.04), M_DARK, Vector3(rng.randf_range(-hx, hx) * 0.5, hy + 0.14, rng.randf_range(-hz, hz) * 0.5))
	# 战损：屋顶塌洞 + 钢筋
	if rng.randf() < 0.45:
		var hp := Vector3(rng.randf_range(-hx, hx) * 0.4, hy + 0.06, rng.randf_range(-hz, hz) * 0.4)
		A.add(sb, A.cyl(rng.randf_range(0.6, 1.1), 0.02, 0.9, 7), A.paint(Color(0.02, 0.02, 0.02), 0.0, 1.0), hp, Vector3(0, rng.randf() * 60.0, 0), Vector3(1, 1, rng.randf_range(0.6, 1.0)), false)
		for k in rng.randi_range(3, 6):
			A.add(sb, A.cyl(0.03, rng.randf_range(0.5, 1.2), 0.03, 5), A.paint(Color(0.35, 0.18, 0.1), 0.5, 0.8),
				hp + Vector3(rng.randf_range(-0.8, 0.8), 0.3, rng.randf_range(-0.8, 0.8)), Vector3(rng.randf_range(-40, 40), 0, rng.randf_range(-40, 40)))
	# 楼脚碎石堆
	for k in rng.randi_range(2, 4):
		var side := Vector3(rng.randf_range(-1, 1) * hx, -hy + 0.2, (1 if rng.randf() < 0.5 else -1) * (hz + 0.5))
		A.add(sb, A.bevel_box(Vector3(rng.randf_range(0.6, 1.4), rng.randf_range(0.3, 0.7), rng.randf_range(0.5, 1.0)), 0.1), A.concrete(c.darkened(0.15)), side, Vector3(rng.randf_range(-15, 15), rng.randf() * 90.0, rng.randf_range(-15, 15)))
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
			cam_zoom = clampf(cam_zoom - 0.06, 0.5, 1.3)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_zoom = clampf(cam_zoom + 0.06, 0.5, 1.3)


# ================= 大地图：道路 + 区块 =================
const Maps = preload("res://scripts/maps.gd")
const CELL := 40.0
const DISTRICT_NAMES := Maps.ZONE_NAMES
var map_id := "greyport"
var MAP: Dictionary = {}
var zones: Array = []
var roads: Array = []          ## {v, c, a, b, w, dirt}
var river_pts := PackedVector2Array()
var river_w := 0.0
var river_dry := true
var ridge_pts: Array = []      ## Vector2：山脊巨石
var curves: Array = []         ## {pts: PackedVector2Array, d: 加密点, w, dirt}
var lakes: Array = []          ## Vector3(x, z, r)
var rail_lines: Array = []     ## [Vector2, Vector2]
var map_labels: Array = []
var poi_centers: Array = []
var poi_ids: Array = []        ## 与 poi_centers 一一对应的 POI 类型 id
var cur_district := ""


func _e(k: int) -> float:
	return -HALF + CELL * k


func _load_map() -> void:
	MAP = GameData.map_data(map_id)
	zones = MAP.zones
	roads.clear()
	for r: Array in MAP.roads:
		var a: float = _e(r[2]) - 6.0 if r[2] > 0 else -HALF - 8.0
		var b: float = _e(r[3]) + 6.0 if r[3] < 9 else HALF + 8.0
		roads.append({"v": r[0], "c": _e(r[1]), "a": a, "b": b, "w": r[4], "dirt": r[5]})
	river_pts = PackedVector2Array()
	for q: Array in MAP.river.pts:
		river_pts.append(Vector2(q[0], q[1]))
	river_w = MAP.river.w
	river_dry = MAP.river.dry
	curves.clear()
	for cv: Array in MAP.get("curves", []):
		var pp := PackedVector2Array()
		for q: Array in cv[2]:
			pp.append(Vector2(q[0], q[1]))
		curves.append({"pts": pp, "d": _dense(pp, 2.0), "w": cv[0], "dirt": cv[1]})
	lakes.clear()
	for l: Array in MAP.get("lakes", []):
		lakes.append(Vector3(l[0], l[1], l[2]))
	rail_lines.clear()
	for line: Array in MAP.rails:
		for k in line.size() - 1:
			rail_lines.append([Vector2(line[k][0], line[k][1]), Vector2(line[k + 1][0], line[k + 1][1])])
	map_labels = MAP.labels


func zone_at(p: Vector3) -> String:
	var i := clampi(int((p.x + HALF) / CELL), 0, 8)
	var j := clampi(int((p.z + HALF) / CELL), 0, 8)
	return zones[j][i]


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


func _road_rect(r: Dictionary, pad := 0.0) -> Rect2:
	var hw: float = r.w * 0.5 + pad
	if r.v:
		return Rect2(r.c - hw, r.a, hw * 2.0, r.b - r.a)
	return Rect2(r.a, r.c - hw, r.b - r.a, hw * 2.0)


func on_road(p: Vector2, pad := 0.0) -> bool:
	for r: Dictionary in roads:
		if _road_rect(r, pad).has_point(p):
			return true
	return on_curve(p, pad)


func on_curve(p: Vector2, pad := 0.0) -> bool:
	for cv: Dictionary in curves:
		if _pdist(cv.pts, p) < cv.w * 0.5 + pad:
			return true
	return false


func _pdist(pts: PackedVector2Array, p: Vector2) -> float:
	var best := INF
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


func river_dist(p: Vector2) -> float:
	return _pdist(river_pts, p)


func in_lake(p: Vector2, pad := 0.0) -> bool:
	for l: Vector3 in lakes:
		if p.distance_to(Vector2(l.x, l.y)) < l.z + pad:
			return true
	return false


## 河道（含干河床）或湖：不摆建筑
func in_river(p: Vector2, pad := 0.0) -> bool:
	return (river_pts.size() > 1 and river_dist(p) < river_w * 0.5 + pad) or in_lake(p, pad)


## 真有水的地方
func in_wet(p: Vector2, pad := 0.0) -> bool:
	return (not river_dry and river_pts.size() > 1 and river_dist(p) < river_w * 0.5 + pad) or in_lake(p, pad)


## 边线内缩：有道路就让出半个路宽 + 人行道，否则 2m（地图外缘 8m）
func _inset(vert: bool, k: int, s0: float, s1: float) -> float:
	if k == 0 or k == 9:
		return 8.0
	var line := _e(k)
	for r: Dictionary in roads:
		if r.v == vert and absf(r.c - line) < 0.1 and r.a < s1 - 1.0 and r.b > s0 + 1.0:
			return r.w * 0.5 + 1.2
	return 2.0


func _cell_rect(i: int, j: int) -> Rect2:
	var x0 := _e(i)
	var x1 := _e(i + 1)
	var z0 := _e(j)
	var z1 := _e(j + 1)
	var l := _inset(true, i, z0, z1)
	var rr := _inset(true, i + 1, z0, z1)
	var t := _inset(false, j, x0, x1)
	var b := _inset(false, j + 1, x0, x1)
	return Rect2(x0 + l, z0 + t, (x1 - rr) - (x0 + l), (z1 - b) - (z0 + t))


## 同类型且中间没有道路的相邻格子合成一个街区
func _group(i0: int, j0: int, seen: Dictionary) -> Array:
	var t: String = zones[j0][i0]
	var out: Array = []
	var stack: Array = [Vector2i(i0, j0)]
	seen[Vector2i(i0, j0)] = true
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		out.append(c)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if n.x < 0 or n.y < 0 or n.x > 8 or n.y > 8 or seen.has(n) or zones[n.y][n.x] != t:
				continue
			var road := false
			if d.x != 0:
				road = _inset(true, maxi(c.x, n.x), _e(c.y), _e(c.y + 1)) > 2.5
			else:
				road = _inset(false, maxi(c.y, n.y), _e(c.x), _e(c.x + 1)) > 2.5
			if road:
				continue
			seen[n] = true
			stack.append(n)
	return out


func _spot_in(r: Rect2, rad: float, tries := 40) -> Vector3:
	for t in tries:
		var p := Vector3(rng.randf_range(r.position.x + rad, r.end.x - rad), 0, rng.randf_range(r.position.y + rad, r.end.y - rad))
		if not _blocked(p, rad):
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


func _fill(t: String, r: Rect2) -> void:
	if r.size.x < 8.0 or r.size.y < 8.0:
		return
	match t:
		"D": _fill_downtown(r)
		"R": _fill_residential(r)
		"I": _fill_industrial(r)
		"M": _fill_military(r)
		"W": _fill_wasteland(r)
		"F": _fill_farm(r)
		"P": _fill_park(r)
		"H": _fill_harbor(r)
		"Y": _fill_railyard(r)
		"T": _fill_forest(r)
		"C": _fill_craters(r)
		"S": _fill_hive(r)
		"K": _fill_cliff(r)


func _build_map() -> Vector3:
	_build_roads()
	_build_curves()
	_build_river()
	_build_lakes()
	_build_rails()
	_build_ridges()
	poi_centers.clear()
	poi_ids.clear()
	var auto := 0
	for c: Array in MAP.pois:
		var r := _cell_rect(c[0], c[1])
		poi_centers.append(Vector3(r.get_center().x, 0, r.get_center().y))
		if c.size() > 2:
			poi_ids.append(str(c[2]))
		else:
			poi_ids.append(Maps.POI_ORDER[auto % Maps.POI_ORDER.size()])
			auto += 1
	_build_pois()
	var seen := {}
	for j in 9:
		for i in 9:
			if seen.has(Vector2i(i, j)):
				continue
			var t: String = zones[j][i]
			var grp := _group(i, j, seen)
			var mn := Vector2i(9, 9)
			var mx := Vector2i(-1, -1)
			for c: Vector2i in grp:
				mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
				mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
			if grp.size() == (mx.x - mn.x + 1) * (mx.y - mn.y + 1) and grp.size() <= 6:
				_fill(t, _cell_rect(mn.x, mn.y).merge(_cell_rect(mx.x, mx.y)))
			else:
				for c: Vector2i in grp:
					_fill(t, _cell_rect(c.x, c.y))
	# 道路上的废弃车辆 / 火桶
	for k in 96:
		var p := _road_point(2.5)
		if not _blocked(p, 2.2, false) and not in_river(Vector2(p.x, p.z), 4.0) and absf(p.x) < HALF - 8 and absf(p.z) < HALF - 8:
			_wreck_car(p)
	for k in 16:
		var p := _road_point(1.5)
		if not _blocked(p, 1.5, false) and not in_river(Vector2(p.x, p.z), 3.0) and absf(p.x) < HALF - 8 and absf(p.z) < HALF - 8:
			_fire_barrel(p)
	return _drop_point()


func _road_point(edge: float) -> Vector3:
	var n := roads.size() + curves.size()
	var i := rng.randi() % n
	if i < roads.size():
		var r: Dictionary = roads[i]
		var along := clampf(rng.randf_range(r.a, r.b), -HALF + 10, HALF - 10)
		var off := rng.randf_range(-1.0, 1.0) * maxf(0.0, r.w * 0.5 - edge)
		return Vector3(r.c + off, 0, along) if r.v else Vector3(along, 0, r.c + off)
	var cv: Dictionary = curves[i - roads.size()]
	var d: PackedVector2Array = cv.d
	var j := rng.randi_range(1, d.size() - 2)
	var t := (d[j + 1] - d[j - 1]).normalized()
	var q := d[j] + Vector2(-t.y, t.x) * rng.randf_range(-1.0, 1.0) * maxf(0.0, cv.w * 0.5 - edge)
	return Vector3(q.x, 0, q.y)


func _drop_point() -> Vector3:
	# 空投点：外围较安全的区块里找空地
	var safe_cells: Array = []
	for j in 9:
		for i in 9:
			if zones[j][i] in ["R", "W", "F", "P", "T"] and (i <= 1 or j <= 1 or i >= 7 or j >= 7):
				safe_cells.append(Vector2i(i, j))
	for t in 40:
		var c: Vector2i = safe_cells[rng.randi() % safe_cells.size()]
		var p := _spot_in(_cell_rect(c.x, c.y), 4.0)
		if p != Vector3.INF:
			return p
	return _free_spot(4.0)


# ---------- 地形图（小地图 / 大地图共用） ----------
const MAP_PX := 720
const ZONE_TINT := {"W": Color(0.33, 0.3, 0.23), "F": Color(0.4, 0.35, 0.2), "R": Color(0.36, 0.33, 0.3), "D": Color(0.27, 0.28, 0.31),
	"I": Color(0.33, 0.29, 0.24), "H": Color(0.25, 0.29, 0.31), "Y": Color(0.3, 0.27, 0.25), "M": Color(0.27, 0.31, 0.22), "P": Color(0.23, 0.32, 0.19),
	"T": Color(0.17, 0.24, 0.15), "C": Color(0.25, 0.22, 0.19), "S": Color(0.27, 0.19, 0.28), "K": Color(0.2, 0.17, 0.15)}
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


func _build_map_texture() -> void:
	var img := Image.create(MAP_PX, MAP_PX, false, Image.FORMAT_RGBA8)
	var k := MAP_PX / (HALF * 2.0)
	for j in 9:
		for i in 9:
			var c: Color = ZONE_TINT[zones[j][i]]
			img.fill_rect(Rect2i(int((_e(i) + HALF) * k), int((_e(j) + HALF) * k), int(CELL * k) + 1, int(CELL * k) + 1), c)
	# 农田垄线 / 公园树点
	for j in 9:
		for i in 9:
			var r := _cell_rect(i, j)
			if zones[j][i] == "F":
				var z := r.position.y + 2.0
				while z < r.end.y:
					_img_line(img, Vector2(r.position.x + 2, z), Vector2(r.end.x - 2, z), 0.6, Color(0.33, 0.28, 0.16), 2.0)
					z += 4.4
	# 河流
	if river_pts.size() > 1:
		for i in river_pts.size() - 1:
			_img_line(img, river_pts[i], river_pts[i + 1], river_w + 4.0, Color(0.22, 0.2, 0.17) if not river_dry else Color(0.36, 0.32, 0.25))
		for i in river_pts.size() - 1:
			_img_line(img, river_pts[i], river_pts[i + 1], river_w, Color(0.17, 0.3, 0.37) if not river_dry else Color(0.5, 0.45, 0.35))
	# 湖
	for l: Vector3 in lakes:
		_img_disc(img, Vector2(l.x, l.y), l.z + 2.0, Color(0.22, 0.2, 0.17))
	for l: Vector3 in lakes:
		_img_disc(img, Vector2(l.x, l.y), l.z, Color(0.17, 0.3, 0.37))
	# 道路
	for cv: Dictionary in curves:
		var pp: PackedVector2Array = cv.pts
		for i in pp.size() - 1:
			_img_line(img, pp[i], pp[i + 1], cv.w, Color(0.47, 0.41, 0.31) if cv.dirt else Color(0.53, 0.51, 0.47))
	for cv: Dictionary in curves:
		if cv.dirt:
			continue
		var pp: PackedVector2Array = cv.pts
		for i in pp.size() - 1:
			_img_line(img, pp[i], pp[i + 1], cv.w - 2.4, Color(0.42, 0.405, 0.38) if cv.w >= 11.0 else Color(0.38, 0.37, 0.35))
	for r: Dictionary in roads:
		var rr := _road_rect(r)
		var ir := Rect2i(int((rr.position.x + HALF) * k), int((rr.position.y + HALF) * k), int(rr.size.x * k), int(rr.size.y * k))
		if r.dirt:
			img.fill_rect(ir, Color(0.47, 0.41, 0.31))
		else:
			img.fill_rect(ir, Color(0.53, 0.51, 0.47))
			img.fill_rect(ir.grow(-int(1.2 * k)), Color(0.42, 0.405, 0.38) if r.w >= 11.0 else Color(0.38, 0.37, 0.35))
	# 桥
	for b: Array in bridges:
		_img_line(img, b[0], b[1], b[2] + 1.5, Color(0.12, 0.12, 0.13))
		_img_line(img, b[0], b[1], b[2] - 1.0, Color(0.5, 0.48, 0.45))
	# 铁轨
	for l: Array in rail_lines:
		_img_line(img, l[0], l[1], 3.0, Color(0.2, 0.18, 0.17))
		_img_line(img, l[0], l[1], 1.0, Color(0.5, 0.45, 0.4))
	# 山脊
	for p: Vector2 in ridge_pts:
		_img_line(img, p, p, 5.0, Color(0.18, 0.15, 0.12))
		_img_line(img, p + Vector2(-0.6, -0.6), p + Vector2(-0.6, -0.6), 3.0, Color(0.42, 0.37, 0.3))
	# 建筑 / 障碍
	var big: Array = []
	var small: Array = []
	for r: Rect2 in blocks:
		(big if r.get_area() > 10.0 else small).append(r)
	for r: Rect2 in small:
		img.fill_rect(Rect2i(int((r.position.x + HALF) * k), int((r.position.y + HALF) * k), maxi(2, int(r.size.x * k)), maxi(2, int(r.size.y * k))), Color(0.16, 0.155, 0.15))
	for r: Rect2 in big:
		var rr := Rect2i(int((r.position.x + HALF) * k), int((r.position.y + HALF) * k), maxi(3, int(r.size.x * k)), maxi(3, int(r.size.y * k)))
		img.fill_rect(rr, Color(0.09, 0.09, 0.1))
		img.fill_rect(rr.grow(-1), Color(0.6, 0.58, 0.54))
	for e in [Rect2i(0, 0, MAP_PX, 3), Rect2i(0, MAP_PX - 3, MAP_PX, 3), Rect2i(0, 0, 3, MAP_PX), Rect2i(MAP_PX - 3, 0, 3, MAP_PX)]:
		img.fill_rect(e, Color(0.05, 0.05, 0.05))
	map_tex = ImageTexture.create_from_image(img)


## 地表分区贴图：R 铺装 / G 草地 / B 耕地 / A 碎石工业地坪，地面着色器按世界坐标采样后混合
const ZONE_GROUND := {"D": Color(1, 0, 0, 0.25), "R": Color(0.45, 0.35, 0, 0), "I": Color(0.15, 0, 0, 1), "H": Color(0.35, 0, 0, 0.85),
	"Y": Color(0, 0.05, 0, 1), "M": Color(0.35, 0.05, 0, 0.7), "P": Color(0, 1, 0, 0), "F": Color(0, 0.12, 1, 0), "W": Color(0, 0.14, 0, 0),
	"T": Color(0, 0.85, 0.15, 0), "C": Color(0, 0, 0.25, 0.55), "S": Color(0, 0.1, 0, 0.25), "K": Color(0, 0, 0, 0.45)}
func _build_zone_ground() -> void:
	var n := 90
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var wp := Vector3(-HALF + (x + 0.5) * 4.0, 0, -HALF + (y + 0.5) * 4.0)
			var c: Color = ZONE_GROUND[zone_at(wp)]
			if in_wet(Vector2(wp.x, wp.z), 6.0):
				c = Color(0, 0.1, 0.15, 0)
			elif river_pts.size() > 1 and in_river(Vector2(wp.x, wp.z), 6.0):
				c = Color(0, 0, 0, 0.2)
			img.set_pixel(x, y, c)
	img.resize(180, 180, Image.INTERPOLATE_BILINEAR)
	var t := ImageTexture.create_from_image(img)
	var gm: ShaderMaterial = A.ground()
	gm.set_shader_parameter("zone_tex", t)
	gm.set_shader_parameter("zone_half", HALF)
	gm.set_shader_parameter("zone_on", 1.0)


func _runs(a: float, b: float, gaps: Array) -> Array:
	gaps.sort_custom(func(x, y): return x.x < y.x)
	var out: Array = []
	var s := a
	for g: Vector2 in gaps:
		if g.y <= s or g.x >= b:
			continue
		if g.x > s:
			out.append(Vector2(s, g.x))
		s = maxf(s, g.y)
	if s < b:
		out.append(Vector2(s, b))
	return out


func _build_roads() -> void:
	var ASPH := A.concrete(Color(0.24, 0.23, 0.22), false)
	var ASPH2 := A.concrete(Color(0.28, 0.27, 0.26), false)
	var DIRT := A.concrete(Color(0.42, 0.36, 0.27), false)
	var WALK := A.concrete(Color(0.5, 0.48, 0.45), true)
	var LINE := A.paint(Color(0.72, 0.66, 0.45), 0.0, 0.9, {"wear": 0.85, "dust": 0.6, "panel_scale": 0.0})
	var dashes: Array = []
	var walks: Array = []
	for ri in roads.size():
		var r: Dictionary = roads[ri]
		var v: bool = r.v
		var c: float = r.c
		var w: float = r.w
		var L: float = r.b - r.a
		var mid: float = (r.a + r.b) * 0.5
		var yy := (0.034 if v else 0.03) - (0.008 if r.dirt else 0.0) + (0.0 if w >= 11.0 else 0.002)
		var inner := w - (0.0 if r.dirt else 2.4)
		var size := Vector3(inner, 0.06, L) if v else Vector3(L, 0.06, inner)
		var pos := Vector3(c, yy, mid) if v else Vector3(mid, yy, c)
		A.add(world, A.bevel_box(size, 0.01), DIRT if r.dirt else (ASPH if w >= 11.0 else ASPH2), pos, Vector3.ZERO, Vector3.ONE, false)
		if r.dirt:
			# 车辙
			for sd in [-1.0, 1.0]:
				var rs := Vector3(0.5, 0.02, L) if v else Vector3(L, 0.02, 0.5)
				var rp := Vector3(c + sd * 1.3, yy + 0.035, mid) if v else Vector3(mid, yy + 0.035, c + sd * 1.3)
				A.add(world, A.bevel_box(rs, 0.0), A.concrete(Color(0.3, 0.25, 0.19), false), rp, Vector3.ZERO, Vector3.ONE, false)
			continue
		var gaps: Array = []
		for o: Dictionary in roads:
			if o == r or o.v == v or o.dirt:
				continue
			if o.a <= c + w * 0.5 and c - w * 0.5 <= o.b:
				gaps.append(Vector2(o.c - o.w * 0.5, o.c + o.w * 0.5))
		for sd in [-1.0, 1.0]:
			for run: Vector2 in _runs(r.a, r.b, gaps.duplicate()):
				var ln := run.y - run.x
				if ln < 0.5:
					continue
				var off: float = c + sd * (w * 0.5 - 0.6)
				var nch := maxi(1, int(ln / 4.0))
				var cl := ln / nch
				for ci in nch:
					var m := run.x + (ci + 0.5) * cl
					var mp := Vector2(off, m) if v else Vector2(m, off)
					if on_curve(mp, 0.2):
						continue
					walks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.1, 0.16, cl + 0.02) if v else Vector3(cl + 0.02, 0.16, 1.1)), Vector3(off, 0.08, m) if v else Vector3(m, 0.08, off)))
		if w >= 11.0:
			var x: float = r.a + 2.0
			while x < r.b - 2.0:
				var near := false
				for g: Vector2 in gaps:
					if x > g.x - 3.0 and x < g.y + 3.0:
						near = true
				if not near and rng.randf() < 0.85 and not on_curve(Vector2(c, x) if v else Vector2(x, c), 0.0):
					dashes.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.22, 0.02, 2.2) if v else Vector3(2.2, 0.02, 0.22)), Vector3(c, 0.07, x) if v else Vector3(x, 0.07, c)))
				x += 5.0
	_multimesh(A.bevel_box(Vector3.ONE, 0.0), LINE, dashes, false)
	_multimesh(A.bevel_box(Vector3.ONE, 0.0), WALK, walks, false)
	# 路面坑洼 / 油渍
	for k in (160 if roads.size() > 0 else 0):
		var r: Dictionary = roads[rng.randi() % roads.size()]
		var along := rng.randf_range(maxf(r.a, -HALF), minf(r.b, HALF))
		var off: float = rng.randf_range(-0.35, 0.35) * r.w
		var p := Vector3(r.c + off, 0.075, along) if r.v else Vector3(along, 0.075, r.c + off)
		var d := A.ground_decal(world, A.blob_tex(), Color(0.05, 0.05, 0.05, rng.randf_range(0.3, 0.6)), rng.randf_range(1.0, 3.0), p)
		d.rotation.y = rng.randf() * TAU


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


## 道路中心线与河道的交点（用于架桥 / 河堤留口）
func _road_on(p: Vector2, pad: float) -> Dictionary:
	for r: Dictionary in roads:
		if r.dirt and river_dry:
			continue
		if _road_rect(r, pad).has_point(p):
			return r
	for cv: Dictionary in curves:
		if _pdist(cv.pts, p) < cv.w * 0.5 + pad:
			return cv
	return {}


func _build_river() -> void:
	bridges.clear()
	if river_pts.size() < 2:
		return
	var pts := _dense(river_pts, 2.0)
	if river_dry:
		# 干河床：浅色沙砾河底 + 深色河岸带 + 卵石
		var mi := MeshInstance3D.new()
		mi.mesh = _strip_mesh(pts, river_w + 5.0, 0.012)
		mi.material_override = A.concrete(Color(0.36, 0.31, 0.24), false)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(mi)
		var bed := MeshInstance3D.new()
		bed.mesh = _strip_mesh(pts, river_w, 0.02)
		bed.material_override = A.concrete(Color(0.6, 0.55, 0.44), false)
		bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(bed)
		var stones: Array = []
		for i in pts.size():
			for k in 3:
				var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
				var p := pts[i] + Vector2(-t.y, t.x) * rng.randf_range(-0.5, 0.5) * river_w
				var sc := rng.randf_range(0.15, 0.55)
				stones.append(Transform3D(_rand_basis(30).scaled(Vector3(sc * 1.3, sc * 0.5, sc)), Vector3(p.x, sc * 0.1, p.y)))
		_multimesh(A.sphere(0.5, -1, 8), A.concrete(Color(0.58, 0.54, 0.48), false), stones, false)
		for k in 18:
			var i := rng.randi_range(4, pts.size() - 5)
			var p := pts[i]
			var q := Vector3(p.x + rng.randf_range(-4, 4), 0, p.y + rng.randf_range(-4, 4))
			if not on_road(Vector2(q.x, q.z), 3.0) and not _blocked(q, 2.0, false):
				_boulder(q, rng.randf_range(1.2, 2.4))
		return
	# 湿河道：泥岸 → 水面 → 混凝土护堤（两侧，过桥处留口）
	var mud := MeshInstance3D.new()
	mud.mesh = _strip_mesh(pts, river_w + 6.0, 0.014)
	mud.material_override = A.concrete(Color(0.22, 0.2, 0.17), false)
	mud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mud)
	var water := MeshInstance3D.new()
	water.mesh = _strip_mesh(pts, river_w, 0.05)
	water.material_override = _water_mat()
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(water)
	var bank := StaticBody3D.new()
	bank.collision_layer = 8   # 只挡机甲（虫子能涉水）
	bank.collision_mask = 0
	world.add_child(bank)
	var curbs: Array = []
	var seg := 4.0
	var cpts := _dense(river_pts, seg)
	for i in cpts.size() - 1:
		var a := cpts[i]
		var b := cpts[i + 1]
		var m := (a + b) * 0.5
		var t := (b - a).normalized()
		var ang := atan2(t.x, t.y)
		for sd in [-1.0, 1.0]:
			var p: Vector2 = m + Vector2(-t.y, t.x) * sd * (river_w * 0.5 + 0.4)
			if not _road_on(p, 1.5).is_empty():
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
	# 桥：道路中心线与河道相交处（网格路 + 自由路）
	var segs: Array = []
	for r: Dictionary in roads:
		segs.append([Vector2(r.c, r.a) if r.v else Vector2(r.a, r.c), Vector2(r.c, r.b) if r.v else Vector2(r.b, r.c), r.w])
	for cv: Dictionary in curves:
		var pp: PackedVector2Array = cv.pts
		for i in pp.size() - 1:
			segs.append([pp[i], pp[i + 1], cv.w])
	for sg: Array in segs:
		for k in river_pts.size() - 1:
			var hit = Geometry2D.segment_intersects_segment(sg[0], sg[1], river_pts[k], river_pts[k + 1])
			if hit == null:
				continue
			var rd := (river_pts[k + 1] - river_pts[k]).normalized()
			var dir: Vector2 = (sg[1] - sg[0]).normalized()
			var span := (river_w + 6.0) / maxf(absf(dir.cross(rd)), 0.35) + 4.0
			_bridge(hit, dir, sg[2], span)
	# 河面漂浮物 / 沉船
	for k in 6:
		var i := rng.randi_range(3, pts.size() - 4)
		var p := pts[i]
		if _road_on(p, 6.0).is_empty():
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


# ---------- 自由走向道路 ----------
func _strip_off(pts: PackedVector2Array, w: float, off: float, y: float) -> ArrayMesh:
	var q := PackedVector2Array()
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		q.append(pts[i] + Vector2(-t.y, t.x) * off)
	return _strip_mesh(q, w, y)


func _in_grid_road(p: Vector2, pad := 0.0) -> bool:
	for r: Dictionary in roads:
		if _road_rect(r, pad).has_point(p):
			return true
	return false


func _build_curves() -> void:
	if curves.is_empty():
		return
	var ASPH := A.concrete(Color(0.25, 0.24, 0.23), false)
	var DIRT := A.concrete(Color(0.42, 0.36, 0.27), false)
	var RUT := A.concrete(Color(0.3, 0.25, 0.19), false)
	var WALK := A.concrete(Color(0.5, 0.48, 0.45), true)
	var LINE := A.paint(Color(0.72, 0.66, 0.45), 0.0, 0.9, {"wear": 0.85, "dust": 0.6, "panel_scale": 0.0})
	var dashes: Array = []
	for cv: Dictionary in curves:
		var d: PackedVector2Array = cv.d
		var w: float = cv.w
		var mi := MeshInstance3D.new()
		mi.mesh = _strip_mesh(d, w if cv.dirt else w - 2.4, 0.066 if not cv.dirt else 0.05)
		mi.material_override = DIRT if cv.dirt else ASPH
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(mi)
		if cv.dirt:
			for sd in [-1.3, 1.3]:
				var rm := MeshInstance3D.new()
				rm.mesh = _strip_off(d, 0.5, sd, 0.056)
				rm.material_override = RUT
				rm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				world.add_child(rm)
			continue
		# 人行道：跨过网格路口处断开
		for sd in [-1.0, 1.0]:
			var run := PackedVector2Array()
			for i in d.size():
				var t := (d[mini(i + 1, d.size() - 1)] - d[maxi(i - 1, 0)]).normalized()
				var sp: Vector2 = d[i] + Vector2(-t.y, t.x) * sd * (w * 0.5 - 0.6)
				var ok := not _in_grid_road(sp, -0.5)
				if ok:
					run.append(d[i])
				if (not ok or i == d.size() - 1) and run.size() >= 2:
					var wm := MeshInstance3D.new()
					wm.mesh = _strip_off(run, 1.1, sd * (w * 0.5 - 0.6), 0.15)
					wm.material_override = WALK
					wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					world.add_child(wm)
				if not ok:
					run = PackedVector2Array()
		if w >= 10.0:
			var acc := 0.0
			for i in d.size() - 1:
				acc += d[i].distance_to(d[i + 1])
				if acc >= 5.0:
					acc = 0.0
					var t := (d[i + 1] - d[i]).normalized()
					if not _in_grid_road(d[i], 1.0) and rng.randf() < 0.85:
						dashes.append(Transform3D(Basis(Vector3.UP, atan2(t.x, t.y)).scaled(Vector3(0.22, 0.02, 2.2)), Vector3(d[i].x, 0.08, d[i].y)))
	_multimesh(A.bevel_box(Vector3.ONE, 0.0), LINE, dashes, false)


# ---------- 铁轨 ----------
func _build_rails() -> void:
	if rail_lines.is_empty():
		return
	var ties: Array = []
	var rails: Array = []
	for l: Array in rail_lines:
		var a: Vector2 = l[0]
		var b: Vector2 = l[1]
		var t := (b - a).normalized()
		var ang := atan2(t.x, t.y)
		var bs := Basis(Vector3.UP, ang)
		var n := int(a.distance_to(b) / 0.9)
		for i in n:
			var p := a.lerp(b, (i + 0.5) / n)
			ties.append(Transform3D(bs.scaled(Vector3(2.6, 0.12, 0.28)), Vector3(p.x, 0.07, p.y)))
		var m := (a + b) * 0.5
		for sd in [-0.72, 0.72]:
			var q: Vector2 = m + Vector2(-t.y, t.x) * sd
			rails.append(Transform3D(bs.scaled(Vector3(0.1, 0.14, a.distance_to(b))), Vector3(q.x, 0.18, q.y)))
		# 道砟
		var ballast := A.bevel_box(Vector3(3.6, 0.08, a.distance_to(b)), 0.02)
		A.add(world, ballast, A.concrete(Color(0.36, 0.34, 0.32), false), Vector3(m.x, 0.03, m.y), Vector3(0, rad_to_deg(ang), 0), Vector3.ONE, false)
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
	for line: Array in MAP.ridges:
		var pp := PackedVector2Array()
		for q: Array in line:
			pp.append(Vector2(q[0], q[1]))
		for p: Vector2 in _dense(pp, 3.2):
			if on_road(p, 4.0):
				continue
			var q := Vector3(p.x + rng.randf_range(-1.5, 1.5), 0, p.y + rng.randf_range(-1.5, 1.5))
			_boulder(q, rng.randf_range(2.8, 5.0))
			ridge_pts.append(Vector2(q.x, q.z))
			if rng.randf() < 0.5:
				var q2 := q + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
				if not on_road(Vector2(q2.x, q2.z), 3.0):
					_boulder(q2, rng.randf_range(1.5, 3.0))
					ridge_pts.append(Vector2(q2.x, q2.z))


## 把区块切成 n x n 地块（中间留巷道）
## 按目标地块尺寸切分，跳过压到道路 / 河道的地块
func _lots(r: Rect2, lot: float, gap: float) -> Array:
	var out: Array = []
	var nx := maxi(1, roundi((r.size.x + gap) / (lot + gap)))
	var ny := maxi(1, roundi((r.size.y + gap) / (lot + gap)))
	var w := (r.size.x - gap * (nx - 1)) / nx
	var h := (r.size.y - gap * (ny - 1)) / ny
	for a in nx:
		for b in ny:
			var l := Rect2(r.position.x + a * (w + gap), r.position.y + b * (h + gap), w, h)
			var bad := false
			var lc := l.get_center()
			for q in [lc, l.position, l.end, Vector2(l.position.x, l.end.y), Vector2(l.end.x, l.position.y),
					Vector2(lc.x, l.position.y), Vector2(lc.x, l.end.y), Vector2(l.position.x, lc.y), Vector2(l.end.x, lc.y)]:
				if in_river(q, 1.5) or on_road(q, 0.5):
					bad = true
			if not bad:
				out.append(l)
	return out


func _is_poi_cell(r: Rect2) -> bool:
	for c: Vector3 in poi_centers:
		if r.has_point(Vector2(c.x, c.z)):
			return true
	return false


func _fill_downtown(r: Rect2) -> void:
	var poi := _is_poi_cell(r)
	for lot: Rect2 in _lots(r, 17.0, 6.0):
		if poi and lot.has_point(r.get_center()):
			continue
		var roll := rng.randf()
		if poi and roll < 0.5:
			continue
		if roll < 0.72:
			# 一到两栋高楼
			if rng.randf() < 0.5:
				var sz := Vector3(lot.size.x - rng.randf_range(1.5, 4.0), rng.randf_range(9.0, 22.0), lot.size.y - rng.randf_range(1.5, 4.0))
				var p := Vector3(lot.get_center().x, 0, lot.get_center().y)
				_building(p, sz)
				blocks.append(_rect_for(p, sz))
			else:
				for half in [-1.0, 1.0]:
					var sz := Vector3(lot.size.x * 0.5 - 1.6, rng.randf_range(7.0, 16.0), lot.size.y - rng.randf_range(2.0, 4.0))
					var p := Vector3(lot.get_center().x + half * lot.size.x * 0.25, 0, lot.get_center().y)
					_building(p, sz)
					blocks.append(_rect_for(p, sz))
		elif roll < 0.86:
			# 坍塌的楼：矮残体 + 碎块堆
			var sz := Vector3(lot.size.x * rng.randf_range(0.5, 0.8), rng.randf_range(2.5, 4.5), lot.size.y * rng.randf_range(0.5, 0.8))
			var p := Vector3(lot.get_center().x, 0, lot.get_center().y)
			_building(p, sz)
			blocks.append(_rect_for(p, sz))
			_rubble_pile(p + Vector3(sz.x * 0.5 + 1.5, 0, 0), 2.5)
		else:
			# 停车场 / 广场
			for k in rng.randi_range(2, 5):
				var p := _spot_in(lot, 2.5)
				if p != Vector3.INF:
					_wreck_car(p)
	_loot_in(r, 7, {"supply": 30, "tool": 30, "military": 22, "safe": 18})


func _fill_residential(r: Rect2) -> void:
	var poi := _is_poi_cell(r)
	for lot: Rect2 in _lots(r, 15.0, 4.0):
		if poi and lot.get_center().distance_to(r.get_center()) < 22.0:
			continue
		var roll := rng.randf()
		var p := Vector3(lot.get_center().x + rng.randf_range(-1.5, 1.5), 0, lot.get_center().y + rng.randf_range(-1.5, 1.5))
		if roll < 0.7:
			var sz := Vector3(min(lot.size.x - 4.0, rng.randf_range(6.0, 9.0)), rng.randf_range(3.2, 6.4), min(lot.size.y - 4.0, rng.randf_range(6.0, 9.0)))
			_house(p, sz)
			blocks.append(_rect_for(p, sz + Vector3(1, 0, 1)))
			# 院墙（不完整）
			_yard_walls(lot)
		elif roll < 0.85:
			_yard_walls(lot)
			_rubble_pile(p, 2.0)
		else:
			_wreck_car(p)
	_loot_in(r, 7, {"supply": 50, "tool": 35, "military": 5, "safe": 10})


func _fill_industrial(r: Rect2) -> void:
	var poi := _is_poi_cell(r)
	var halves := [Rect2(r.position, Vector2(r.size.x, r.size.y * 0.5 - 3.0)), Rect2(r.position + Vector2(0, r.size.y * 0.5 + 3.0), Vector2(r.size.x, r.size.y * 0.5 - 3.0))]
	if r.size.y < 56.0:
		halves = [r]
	for hi in halves.size():
		var h: Rect2 = halves[hi]
		if poi and h.grow(-2).has_point(r.get_center() + Vector2(0, -6 if hi == 0 else 6)):
			continue
		if rng.randf() < 0.75:
			var sz := Vector3(h.size.x * rng.randf_range(0.45, 0.62), rng.randf_range(7.0, 10.0), h.size.y * rng.randf_range(0.6, 0.85))
			var p := Vector3(h.position.x + sz.x * 0.5 + 3.0, 0, h.get_center().y)
			if _blocked(p, minf(sz.x, sz.z) * 0.45):
				continue
			_warehouse(p, sz)
			blocks.append(_rect_for(p, sz + Vector3(2, 0, 2)))
		for k in rng.randi_range(1, 3):
			var p := _spot_in(Rect2(h.position.x + h.size.x * 0.55, h.position.y, h.size.x * 0.45, h.size.y), 4.0)
			if p != Vector3.INF:
				_tank(p, rng.randf_range(2.6, 4.0), rng.randf_range(5.0, 9.0))
		for k in rng.randi_range(1, 3):
			var p := _spot_in(h, 3.5)
			if p != Vector3.INF:
				_container(p, rng.randf_range(0, 180), [Color(0.25, 0.38, 0.5), Color(0.62, 0.3, 0.18), Color(0.35, 0.45, 0.3), Color(0.55, 0.5, 0.35)][rng.randi() % 4])
				blocks.append(Rect2(p.x - 3.5, p.z - 3.5, 7, 7))
	if rng.randf() < 0.7:
		var p := _spot_in(r, 2.5)
		if p != Vector3.INF:
			_chimney(p)
	_fence_ring(r, 2.4, 0.35)
	_loot_in(r, 6, {"supply": 15, "tool": 55, "military": 20, "safe": 10})


func _fill_military(r: Rect2) -> void:
	var M_HESCO := A.paint(Color(0.55, 0.5, 0.38), 0.0, 0.95, {"wear": 0.3, "dust": 0.7, "grime": 0.6, "panel_scale": 0.4})
	# 防爆墙围栏，四面留门
	var inner := r.grow(-3.0)
	for side in 4:
		var horiz := side < 2
		var length: float = inner.size.x if horiz else inner.size.y
		var seg := 2.2
		var n := int(length / seg)
		var gate := rng.randi_range(int(n * 0.3), int(n * 0.7))
		for k in n:
			if absi(k - gate) <= 1 or rng.randf() < 0.06:
				continue
			var t := -length * 0.5 + (k + 0.5) * seg
			var pos: Vector3
			if horiz:
				pos = Vector3(inner.get_center().x + t, 1.2, inner.position.y if side == 0 else inner.end.y)
			else:
				pos = Vector3(inner.position.x if side == 2 else inner.end.x, 1.2, inner.get_center().y + t)
			var sb := _static_box(Vector3(seg - 0.1, 2.4, 1.2) if horiz else Vector3(1.2, 2.4, seg - 0.1), pos, Color.WHITE, null, M_HESCO)
			blocks.append(_rect_for(pos, Vector3(seg, 1, 1.4) if horiz else Vector3(1.4, 1, seg)))
			sb.rotation_degrees.y = rng.randf_range(-2, 2)
	var core := inner.grow(-5.0)
	# 营房 + 掩体 + 瞭望塔
	for k in 2:
		var p := _spot_in(core, 9.0)
		if p == Vector3.INF:
			continue
		var sz := Vector3(rng.randf_range(14, 20), 3.6, 6.5) if rng.randf() < 0.5 else Vector3(6.5, 3.6, rng.randf_range(14, 20))
		_building(p, sz)
		blocks.append(_rect_for(p, sz + Vector3(2, 0, 2)))
	for k in 2:
		var p := _spot_in(core, 4.0)
		if p != Vector3.INF:
			_bunker(p)
	for corner in [inner.position, inner.end]:
		_watchtower(Vector3(corner.x + (4 if corner == inner.position else -4), 0, corner.y + (4 if corner == inner.position else -4)))
	for k in rng.randi_range(2, 4):
		var p := _spot_in(core, 2.5)
		if p != Vector3.INF:
			_sandbags(p, rng.randf() * 180.0)
	_loot_in(core, 6, {"supply": 10, "tool": 15, "military": 60, "safe": 15})
	var b = spawn_bug("beetle", Vector3(core.get_center().x, 0.5, core.get_center().y))


func _fill_wasteland(r: Rect2) -> void:
	var poi := _is_poi_cell(r)
	for k in roundi(rng.randi_range(8, 14) * r.get_area() / 4900.0):
		var p := _spot_in(r, 3.0)
		if p == Vector3.INF or (poi and Vector2(p.x, p.z).distance_to(r.get_center()) < 20.0):
			continue
		var roll := rng.randf()
		if roll < 0.4:
			_boulder(p, rng.randf_range(1.5, 4.5))
		elif roll < 0.65:
			var size := Vector3(rng.randf_range(6, 12), rng.randf_range(1.4, 3.0), 0.8) if rng.randf() < 0.5 else Vector3(0.8, rng.randf_range(1.4, 3.0), rng.randf_range(6, 12))
			var sb := _static_box(size, p + Vector3(0, size.y * 0.5, 0), Color(0.52, 0.48, 0.44))
			blocks.append(_rect_for(p, size))
		elif roll < 0.8:
			_dead_tree(p)
		elif roll < 0.9:
			_wreck_car(p)
		else:
			var sz := Vector3(rng.randf_range(5, 9), rng.randf_range(2.0, 4.0), rng.randf_range(5, 9))
			_building(p, sz)
			blocks.append(_rect_for(p, sz))
	_loot_in(r, 3, {"supply": 40, "tool": 40, "military": 12, "safe": 8})


func _fill_farm(r: Rect2) -> void:
	# 枯死作物垄
	var stalks: Array = []
	var field := r.grow(-6.0)
	var fz := field.position.y
	while fz < field.end.y:
		var fx := field.position.x
		while fx < field.end.x:
			if rng.randf() < 0.8:
				var hh := rng.randf_range(0.5, 1.1)
				if not in_river(Vector2(fx, fz), 1.0):
					stalks.append(Transform3D(_rand_basis(18).scaled(Vector3(1, hh, 1)), Vector3(fx + rng.randf_range(-0.2, 0.2), hh * 0.5, fz)))
			fx += 0.7
		fz += 2.2
	var STALK := StandardMaterial3D.new()
	STALK.albedo_color = Color(0.5, 0.44, 0.27)
	STALK.roughness = 1.0
	STALK.cull_mode = BaseMaterial3D.CULL_DISABLED
	_multimesh(A.cyl(0.0, 1.0, 0.05, 3), STALK, stalks, false)
	# 农舍 + 谷仓 + 草垛
	var p := _spot_in(r, 7.0)
	if p != Vector3.INF:
		var sz := Vector3(8, 4.5, 7)
		_house(p, sz)
		blocks.append(_rect_for(p, sz + Vector3(2, 0, 2)))
	p = _spot_in(r, 9.0)
	if p != Vector3.INF:
		var sz := Vector3(12, 6.5, 9)
		_warehouse(p, sz, Color(0.42, 0.24, 0.17))
		blocks.append(_rect_for(p, sz + Vector3(2, 0, 2)))
	for k in rng.randi_range(3, 6):
		var q := _spot_in(r, 1.6)
		if q != Vector3.INF:
			var hs := _static_box(Vector3(1.6, 1.3, 2.4), q + Vector3(0, 0.6, 0), Color.WHITE, null, A.paint(Color(0.58, 0.5, 0.3), 0.0, 1.0, {"wear": 0.0, "dust": 0.5, "panel_scale": 0.0}))
			hs.rotation_degrees.y = rng.randf() * 180
			blocks.append(_rect_for(q, Vector3(2.4, 1, 2.4)))
	_fence_ring(r, 1.2, 0.5)
	_loot_in(r, 4, {"supply": 60, "tool": 30, "military": 4, "safe": 6})


# ---------- 建筑部件 ----------
func _house(p: Vector3, sz: Vector3) -> void:
	var c: Color = [Color(0.55, 0.5, 0.43), Color(0.5, 0.46, 0.42), Color(0.46, 0.38, 0.3), Color(0.52, 0.52, 0.48)][rng.randi() % 4]
	var sb := _static_box(sz, p + Vector3(0, sz.y * 0.5, 0), c, null, A.concrete(c))
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var hy := sz.y * 0.5
	var M_DARK := A.concrete(c.darkened(0.35), false)
	A.add(sb, A.bevel_box(Vector3(sz.x + 0.1, 0.45, sz.z + 0.1), 0.03), M_DARK, Vector3(0, -hy + 0.22, 0))
	var M_WIN := A.paint(Color(0.06, 0.07, 0.08), 0.3, 0.25)
	var M_FR := A.concrete(c.lightened(0.12), false)
	for sd in [-1.0, 1.0]:
		for k in 2:
			var x := (k - 0.5) * hx
			A.add(sb, A.bevel_box(Vector3(1.1, 1.1, 0.08), 0.01), M_FR, Vector3(x, 0.2, sd * (hz + 0.02)))
			A.add(sb, A.bevel_box(Vector3(0.9, 0.9, 0.1), 0.01), M_WIN, Vector3(x, 0.2, sd * (hz + 0.03)))
	A.add(sb, A.bevel_box(Vector3(1.1, 2.0, 0.1), 0.01), A.paint(Color(0.3, 0.22, 0.16), 0.0, 0.8, {"wear": 0.6, "dust": 0.4}), Vector3(hx * 0.5, -hy + 1.0, hz + 0.04))
	# 双坡屋顶
	var roof_c: Color = [Color(0.35, 0.18, 0.14), Color(0.25, 0.26, 0.28), Color(0.4, 0.3, 0.22)][rng.randi() % 3]
	var rh: float = min(sz.x, sz.z) * 0.32
	if rng.randf() < 0.25:
		# 塌了一半的屋顶：只剩平顶
		A.add(sb, A.bevel_box(Vector3(sz.x * 0.6, 0.12, sz.z + 0.2), 0.02), A.concrete(roof_c, false), Vector3(-hx * 0.35, hy + 0.06, 0), Vector3(0, 0, 6))
	else:
		var outline := PackedVector2Array([Vector2(-hx - 0.35, 0), Vector2(0, rh), Vector2(hx + 0.35, 0)])
		A.add(sb, A.prism(outline, sz.z + 0.5, 0.04), A.paint(roof_c, 0.1, 0.85, {"wear": 0.4, "dust": 0.5, "rust": 0.3, "panel_scale": 0.6}), Vector3(0, hy, 0))
		if rng.randf() < 0.6:
			A.add(sb, A.bevel_box(Vector3(0.6, 1.2, 0.6), 0.04), M_DARK, Vector3(hx * 0.45, hy + rh * 0.6, hz * 0.3))


func _yard_walls(lot: Rect2) -> void:
	var M := A.concrete(Color(0.56, 0.53, 0.48), false)
	for side in 4:
		if rng.randf() < 0.35:
			continue
		var horiz := side < 2
		var length: float = (lot.size.x if horiz else lot.size.y) * rng.randf_range(0.35, 0.8)
		var t := rng.randf_range(-0.2, 0.2) * (lot.size.x if horiz else lot.size.y)
		var pos: Vector3
		var size: Vector3
		var hgt := 1.25
		if horiz:
			size = Vector3(length, hgt, 0.35)
			pos = Vector3(lot.get_center().x + t, hgt * 0.5, lot.position.y + 0.3 if side == 0 else lot.end.y - 0.3)
		else:
			size = Vector3(0.35, hgt, length)
			pos = Vector3(lot.position.x + 0.3 if side == 2 else lot.end.x - 0.3, hgt * 0.5, lot.get_center().y + t)
		_static_box(size, pos, Color.WHITE, null, M)
		blocks.append(_rect_for(pos, size))


func _warehouse(p: Vector3, sz: Vector3, col := Color(-1, 0, 0)) -> void:
	var c: Color = col if col.r >= 0.0 else [Color(0.42, 0.44, 0.42), Color(0.5, 0.45, 0.36), Color(0.36, 0.4, 0.44)][rng.randi() % 3]
	var M := A.paint(c, 0.45, 0.6, {"wear": 0.45, "rust": 0.6, "dust": 0.4, "panel_scale": 1.6, "grime": 0.6})
	var sb := _static_box(sz, p + Vector3(0, sz.y * 0.5, 0), c, null, M)
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var hy := sz.y * 0.5
	# 波纹墙肋
	var MR := A.paint(c.darkened(0.2), 0.5, 0.6, {"wear": 0.4, "rust": 0.7, "dust": 0.3, "panel_scale": 0.0})
	var n := int(sz.x / 2.0)
	for k in n + 1:
		for sd in [-1.0, 1.0]:
			A.add(sb, A.bevel_box(Vector3(0.18, sz.y, 0.12), 0.02), MR, Vector3(-hx + k * sz.x / n, 0, sd * (hz + 0.05)), Vector3.ZERO, Vector3.ONE, false)
	# 拱形屋顶（压扁的圆柱）
	A.add(sb, A.cyl(1.0, sz.x + 0.3, 1.0, 20), A.paint(c.darkened(0.12), 0.5, 0.55, {"wear": 0.4, "rust": 0.8, "dust": 0.5, "panel_scale": 1.2}),
		Vector3(0, hy, 0), Vector3(0, 0, 90), Vector3(sz.z * 0.12, 1, sz.z * 0.5))
	# 大门 + 装卸台
	A.add(sb, A.bevel_box(Vector3(sz.x * 0.3, sz.y * 0.6, 0.12), 0.02), A.metal(Color(0.28, 0.29, 0.28)), Vector3(0, -hy + sz.y * 0.3, hz + 0.1), Vector3.ZERO, Vector3.ONE, false)
	A.add(sb, A.bevel_box(Vector3(sz.x * 0.4, 0.9, 1.6), 0.05), A.concrete(Color(0.5, 0.48, 0.45), false), Vector3(0, -hy + 0.45, hz + 0.8))
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


func _fence_ring(r: Rect2, hgt: float, gap_chance: float) -> void:
	var M := A.metal(Color(0.3, 0.29, 0.27))
	var inner := r.grow(-1.0)
	for side in 4:
		var horiz := side < 2
		var length: float = inner.size.x if horiz else inner.size.y
		var seg := 4.0
		var n := int(length / seg)
		for k in n:
			if rng.randf() < gap_chance:
				continue
			var t := -length * 0.5 + (k + 0.5) * seg
			var pos := Vector3(inner.get_center().x + t, hgt * 0.5, inner.position.y if side == 0 else inner.end.y) if horiz else Vector3(inner.position.x if side == 2 else inner.end.x, hgt * 0.5, inner.get_center().y + t)
			if _blocked(pos, 0.6):
				continue
			var size := Vector3(seg, hgt, 0.12) if horiz else Vector3(0.12, hgt, seg)
			if hgt < 1.5:
				# 矮木栅栏：不挡子弹（只是装饰性矮栏）
				var n2 := Node3D.new()
				world.add_child(n2)
				n2.position = pos
				A.add(n2, A.bevel_box(Vector3(seg, 0.1, 0.06) if horiz else Vector3(0.06, 0.1, seg), 0.01), A.paint(Color(0.36, 0.28, 0.2), 0.0, 0.9, {"wear": 0.5, "dust": 0.5}), Vector3(0, 0.2, 0))
				A.add(n2, A.bevel_box(Vector3(seg, 0.1, 0.06) if horiz else Vector3(0.06, 0.1, seg), 0.01), A.paint(Color(0.36, 0.28, 0.2), 0.0, 0.9, {"wear": 0.5, "dust": 0.5}), Vector3(0, -0.2, 0))
				A.add(n2, A.bevel_box(Vector3(0.12, hgt, 0.12), 0.01), A.paint(Color(0.3, 0.24, 0.18), 0.0, 0.9), Vector3(-seg * 0.5 if horiz else 0, 0, 0 if horiz else -seg * 0.5))
			else:
				# 铁丝网围栏：立柱 + 网（挡子弹）
				var sb := _static_box(size, pos, Color.WHITE, null, A.paint(Color(0.32, 0.31, 0.29), 0.6, 0.6, {"panel_scale": 3.0, "rust": 0.6, "wear": 0.3}))
				A.add(sb, A.cyl(0.07, hgt + 0.4, 0.07, 6), M, Vector3(-seg * 0.5 if horiz else 0, 0.2, 0 if horiz else -seg * 0.5))
				blocks.append(_rect_for(pos, size))


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


# ---------- 撤离点 / 虫群 ----------
func _fill_park(r: Rect2) -> void:
	var poi := _is_poi_cell(r)
	# 环形步道 + 中央雕像基座 + 树阵 + 长椅 + 矮绿篱
	var c := Vector3(r.get_center().x, 0, r.get_center().y)
	if not poi and not _blocked(c, 3.0):
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
		var ring := A.cyl(7.5, 0.03, 7.5, 32)
		A.add(world, ring, A.concrete(Color(0.5, 0.48, 0.44), true), c + Vector3(0, 0.02, 0), Vector3.ZERO, Vector3.ONE, false)
		A.add(world, A.cyl(5.5, 0.05, 5.5, 32), A.ground(), c + Vector3(0, 0.03, 0), Vector3.ZERO, Vector3.ONE, false)
	for k in roundi(r.get_area() / 70.0):
		var p := _spot_in(r, 1.0, 10)
		if p != Vector3.INF and p.distance_to(c) > 8.0:
			_dead_tree(p)
			blocks.append(Rect2(p.x - 0.5, p.z - 0.5, 1, 1))
	var BENCH := A.paint(Color(0.32, 0.25, 0.18), 0.0, 0.9, {"wear": 0.5, "dust": 0.5, "panel_scale": 0.0})
	for k in roundi(r.get_area() / 350.0):
		var p := _spot_in(r, 1.2, 10)
		if p != Vector3.INF:
			var n := Node3D.new()
			world.add_child(n)
			n.position = p
			n.rotation.y = rng.randi_range(0, 3) * PI * 0.5
			A.add(n, A.bevel_box(Vector3(1.8, 0.08, 0.5), 0.02), BENCH, Vector3(0, 0.45, 0))
			A.add(n, A.bevel_box(Vector3(1.8, 0.4, 0.06), 0.02), BENCH, Vector3(0, 0.7, -0.25))
			for sx in [-0.8, 0.8]:
				A.add(n, A.bevel_box(Vector3(0.08, 0.45, 0.45), 0.01), A.metal(), Vector3(sx, 0.22, 0))
	var HEDGE := A.paint(Color(0.22, 0.24, 0.14), 0.0, 1.0, {"wear": 0.0, "dust": 0.4, "panel_scale": 0.0, "grime": 0.8})
	for k in roundi(r.get_area() / 500.0):
		var p := _spot_in(r, 3.0, 10)
		if p != Vector3.INF and p.distance_to(c) > 9.0:
			var size := Vector3(rng.randf_range(4, 8), 0.9, 1.0) if rng.randf() < 0.5 else Vector3(1.0, 0.9, rng.randf_range(4, 8))
			var n := Node3D.new()
			world.add_child(n)
			A.add(n, A.bevel_box(size, 0.3, 0.85), HEDGE, p + Vector3(0, 0.45, 0))
			blocks.append(_rect_for(p, size))
	if not poi:
		_poi_lamp(Vector3(r.position.x + 3, 0, r.position.y + 3), Color(1.0, 0.8, 0.55))
	_loot_in(r, 3, {"supply": 55, "tool": 25, "military": 8, "safe": 12})


func _fill_harbor(r: Rect2) -> void:
	var poi := _is_poi_cell(r)
	var cols := [Color(0.25, 0.38, 0.5), Color(0.62, 0.3, 0.18), Color(0.35, 0.45, 0.3), Color(0.55, 0.5, 0.35), Color(0.5, 0.2, 0.2)]
	# 集装箱堆场：成排、两层
	for k in roundi(r.get_area() / 180.0):
		var p := _spot_in(r, 3.6, 12)
		if p == Vector3.INF or (poi and Vector2(p.x, p.z).distance_to(r.get_center()) < 13.0):
			continue
		var rot := 0.0 if rng.randf() < 0.5 else 90.0
		_container(p, rot, cols[rng.randi() % cols.size()])
		if rng.randf() < 0.45:
			_container(p + Vector3(0, 2.4, 0), rot + rng.randf_range(-4, 4), cols[rng.randi() % cols.size()])
		blocks.append(Rect2(p.x - 3.5, p.z - 3.5, 7, 7))
	# 岸桥吊机
	if not poi and rng.randf() < 0.8:
		var p := _spot_in(r, 5.0, 20)
		if p != Vector3.INF:
			var M := A.paint(Color(0.75, 0.45, 0.12), 0.5, 0.55, {"rust": 0.8, "wear": 0.6, "panel_scale": 0.8})
			for lx in [-3.5, 3.5]:
				for lz in [-3.5, 3.5]:
					_static_box(Vector3(0.7, 14.0, 0.7), p + Vector3(lx, 7.0, lz), Color.WHITE, null, M)
			A.add(world, A.bevel_box(Vector3(8.0, 1.2, 26.0), 0.1), M, p + Vector3(0, 14.4, 4.0))
			A.add(world, A.bevel_box(Vector3(3.0, 2.2, 3.0), 0.1), A.paint(Color(0.3, 0.3, 0.32), 0.4, 0.6), p + Vector3(0, 13.0, 9.0))
			blocks.append(Rect2(p.x - 4.2, p.z - 4.2, 8.4, 8.4))
	if r.get_area() > 900.0 and rng.randf() < 0.6:
		var sz := Vector3(minf(r.size.x * 0.5, 18.0), 7.0, minf(r.size.y * 0.4, 12.0))
		var p := _spot_in(r, maxf(sz.x, sz.z) * 0.55, 15)
		if p != Vector3.INF:
			_warehouse(p, sz)
			blocks.append(_rect_for(p, sz + Vector3(2, 0, 2)))
	_loot_in(r, 6, {"supply": 30, "tool": 45, "military": 15, "safe": 10})


func _fill_railyard(r: Rect2) -> void:
	# 停在编组站铁轨上的车厢
	for l: Array in rail_lines:
		var a: Vector2 = l[0]
		var b: Vector2 = l[1]
		var horiz := absf(b.x - a.x) > absf(b.y - a.y)
		var x := (r.position.x if horiz else r.position.y) + 7.0
		var end := (r.end.x if horiz else r.end.y) - 7.0
		var line_c := a.y if horiz else a.x
		if horiz and (line_c < r.position.y or line_c > r.end.y):
			continue
		if not horiz and (line_c < r.position.x or line_c > r.end.x):
			continue
		while x < end:
			if rng.randf() < 0.55:
				var p := Vector3(x, 0, line_c) if horiz else Vector3(line_c, 0, x)
				if not _blocked(p, 1.0, false):
					_wagon(p, horiz)
			x += 13.5
	# 信号塔 / 工具棚
	var p := _spot_in(r, 3.0, 20)
	if p != Vector3.INF:
		_watchtower(p)
	for k in roundi(r.get_area() / 900.0):
		var q := _spot_in(r, 4.0, 15)
		if q != Vector3.INF:
			var sz := Vector3(rng.randf_range(5, 8), 3.0, rng.randf_range(4, 6))
			_building(q, sz)
			blocks.append(_rect_for(q, sz))
	_loot_in(r, 5, {"supply": 25, "tool": 50, "military": 15, "safe": 10})


# ---------- 新地形区块 ----------
func _fill_forest(r: Rect2) -> void:
	var poi := _is_poi_cell(r)
	var trunks: Array = []
	var crowns: Array = []
	var dead_crowns: Array = []
	var body := StaticBody3D.new()
	body.collision_layer = 1
	world.add_child(body)
	for k in roundi(r.get_area() / 26.0):
		var p := _spot_in(r, 1.1, 4)
		if p == Vector3.INF or (poi and Vector2(p.x, p.z).distance_to(r.get_center()) < 13.0):
			continue
		if rng.randf() < 0.12:
			_dead_tree(p)
			blocks.append(Rect2(p.x - 0.5, p.z - 0.5, 1, 1))
			continue
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
	var BARK := A.paint(Color(0.22, 0.17, 0.13), 0.0, 1.0, {"panel_scale": 0.0, "dust": 0.3, "wear": 0.0})
	var NEEDLE := A.paint(Color(0.15, 0.2, 0.12), 0.0, 1.0, {"panel_scale": 0.0, "dust": 0.45, "wear": 0.0, "grime": 0.7})
	var BROWN := A.paint(Color(0.32, 0.25, 0.15), 0.0, 1.0, {"panel_scale": 0.0, "dust": 0.45, "wear": 0.0, "grime": 0.7})
	_multimesh(A.cyl(0.14, 1.0, 0.24, 6), BARK, trunks)
	_multimesh(A.cyl(0.0, 1.0, 1.0, 7), NEEDLE, crowns)
	_multimesh(A.cyl(0.0, 1.0, 1.0, 7), BROWN, dead_crowns)
	# 倒木
	for k in roundi(r.get_area() / 400.0):
		var p := _spot_in(r, 2.5, 6)
		if p != Vector3.INF:
			var L := rng.randf_range(3.0, 6.0)
			var sb := _static_box(Vector3(0.6, 0.6, L), p + Vector3(0, 0.3, 0), Color.WHITE, null, BARK)
			sb.rotation_degrees.y = rng.randf() * 180.0
			blocks.append(_rect_for(p, Vector3(L, 1, L) * 0.7))
	_loot_in(r, 3, {"supply": 50, "tool": 30, "military": 10, "safe": 10})


func _fill_craters(r: Rect2) -> void:
	var poi := _is_poi_cell(r)
	var rims: Array = []
	for k in roundi(r.get_area() / 220.0):
		var p := _spot_in(r, 3.0, 8)
		if p == Vector3.INF or (poi and Vector2(p.x, p.z).distance_to(r.get_center()) < 14.0):
			continue
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
	_multimesh(A.bevel_box(Vector3.ONE, 0.15, 0.8), A.concrete(Color(0.36, 0.32, 0.28), false), rims)
	# 被击毁的坦克 / 焦黑的车
	for k in roundi(r.get_area() / 900.0):
		var p := _spot_in(r, 3.5, 10)
		if p == Vector3.INF:
			continue
		if rng.randf() < 0.5:
			var M := A.paint(Color(0.2, 0.2, 0.17), 0.4, 0.8, {"rust": 0.8, "wear": 0.7, "grime": 1.0})
			var sb := _static_box(Vector3(3.4, 1.3, 6.2), p + Vector3(0, 0.9, 0), Color.WHITE, null, M)
			sb.rotation_degrees.y = rng.randf() * 180.0
			A.add(sb, A.bevel_box(Vector3(2.3, 0.9, 2.6), 0.2, 0.8), M, Vector3(0.2, 1.05, -0.4), Vector3(0, rng.randf_range(-40, 40), 8))
			A.add(sb, A.cyl(0.12, 4.0, 0.14, 8), M, Vector3(0.2, 1.3, 1.8), Vector3(rng.randf_range(70, 100), 0, 0))
			blocks.append(_rect_for(p, Vector3(6, 1, 6)))
		else:
			_wreck_car(p)
	for k in 2:
		var p := _spot_in(r, 1.5, 8)
		if p != Vector3.INF and rng.randf() < 0.5:
			_fire_barrel(p)
	_loot_in(r, 4, {"supply": 15, "tool": 25, "military": 50, "safe": 10})


func _fill_hive(r: Rect2) -> void:
	for k in roundi(r.get_area() / 60.0):
		var p := Vector3(rng.randf_range(r.position.x, r.end.x), 0.02 + (k % 40) * 0.0003, rng.randf_range(r.position.y, r.end.y))
		var d := A.ground_decal(world, A.cloud_tex(), Color(0.13, 0.08, 0.15, rng.randf_range(0.45, 0.75)), rng.randf_range(4.0, 9.0), p)
		d.rotation.y = rng.randf() * TAU
	for k in roundi(r.get_area() / 140.0):
		var p := _spot_in(r, 1.2, 6)
		if p != Vector3.INF:
			_bug_spire(p, rng.randf_range(2.5, 7.0))
	var pods: Array = []
	for k in roundi(r.get_area() / 25.0):
		var p := Vector3(rng.randf_range(r.position.x, r.end.x), 0, rng.randf_range(r.position.y, r.end.y))
		if on_road(Vector2(p.x, p.z)):
			continue
		var s := rng.randf_range(0.15, 0.45)
		pods.append(Transform3D(Basis.IDENTITY.scaled(Vector3(s, s * 0.7, s)), p + Vector3(0, s * 0.25, 0)))
	_multimesh(A.sphere(1.0, -1, 8), A.emit(Color(0.65, 0.3, 1.0), 1.6), pods, false)
	if r.get_area() > 700.0:
		var p := _spot_in(r, 3.0, 20)
		if p != Vector3.INF:
			var n = NestScript.new()
			world.add_child(n)
			n.position = p
			n.setup(self)
			blocks.append(Rect2(p.x - 2, p.z - 2, 4, 4))
	_loot_in(r, 3, {"supply": 20, "tool": 20, "military": 35, "safe": 25})


func _fill_cliff(r: Rect2) -> void:
	# 悬崖岩体：层叠的大岩块（不可通行），外缘参差
	var ROCK := A.concrete(Color(0.4, 0.34, 0.28), false)
	var ROCK2 := A.concrete(Color(0.33, 0.28, 0.23), false)
	var step := 5.5
	var x := r.position.x + step * 0.5
	while x < r.end.x:
		var z := r.position.y + step * 0.5
		while z < r.end.y:
			var edge := minf(minf(x - r.position.x, r.end.x - x), minf(z - r.position.y, r.end.y - z))
			var p := Vector3(x + rng.randf_range(-1.5, 1.5), 0, z + rng.randf_range(-1.5, 1.5))
			if (edge < step and rng.randf() < 0.35) or _blocked(p, 2.5):
				z += step
				continue
			var hgt := rng.randf_range(6.0, 13.0) * (0.6 if edge < step else 1.0)
			var sz := Vector3(rng.randf_range(5.5, 8.0), hgt, rng.randf_range(5.5, 8.0))
			var sb := _static_box(sz, p + Vector3(0, hgt * 0.5, 0), Color.WHITE, null, ROCK)
			sb.rotation_degrees = Vector3(rng.randf_range(-4, 4), rng.randf() * 90.0, rng.randf_range(-4, 4))
			A.add(sb, A.bevel_box(Vector3(sz.x * 0.7, hgt * 0.4, sz.z * 0.8), 0.4, 0.7), ROCK2, Vector3(rng.randf_range(-1, 1), hgt * 0.55, rng.randf_range(-1, 1)), Vector3(0, rng.randf() * 90, rng.randf_range(-8, 8)))
			blocks.append(_rect_for(p, sz * 0.95))
			z += step
		x += step
	for k in roundi(r.get_area() / 300.0):
		var p := Vector3(rng.randf_range(r.position.x - 3, r.end.x + 3), 0, rng.randf_range(r.position.y - 3, r.end.y + 3))
		if not _blocked(p, 2.0):
			_boulder(p, rng.randf_range(1.2, 2.5))


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


func _apply_style() -> void:
	var we: WorldEnvironment = null
	for c in get_children():
		if c is WorldEnvironment:
			we = c
	preload("res://scripts/toon.gd").attach(self, we.environment if we else null, camera, GameData.render_style == 1)
