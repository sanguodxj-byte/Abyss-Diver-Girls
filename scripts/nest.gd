extends StaticBody3D
## 地下自动铸造破土孵化井：玩家靠近时不断投送机械体，摧毁后留下高价值残骸。

const Prof = preload("res://scripts/prof.gd")
const MechScript = preload("res://scripts/mech.gd")

const A = preload("res://scripts/art.gd")

var hp := 260.0
var raid
var spawn_t := 4.0
var children_alive: Array = []
var pulse: MeshInstance3D
var t := 0.0


func setup(r) -> void:
	raid = r
	add_to_group("nests")
	collision_layer = 4
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 1.8
	sh.height = 4.0
	cs.shape = sh
	cs.position.y = 2.0
	add_child(cs)

	var M_SLAG := A.concrete(Color(0.15, 0.14, 0.13), false)
	var M_CONC := A.concrete(Color(0.40, 0.39, 0.37), false)
	var M_IRON := A.metal(Color(0.20, 0.21, 0.23))
	var M_STEEL := A.metal(Color(0.34, 0.36, 0.38))
	var M_RUST := A.paint(Color(0.42, 0.22, 0.15), 0.35, 0.72, {"rust": 0.65, "wear": 0.55})
	var M_BRASS := A.metal(Color(0.60, 0.47, 0.24))
	var M_CHROME := A.chrome()
	var M_BORE := A.rubber()
	var M_HAZ := A.hazard()
	var M_GLOW := A.emit(Color(1.0, 0.40, 0.11), 1.35)

	# 1. 破土焦黑矿渣地面裙边 + 八角重铸铁竖井井圈 + 深黑炉膛内壁
	A.add(self, A.cyl(4.4, 0.06, 5.8, 24), M_SLAG, Vector3(0, 0.03, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(self, A.cyl(2.05, 0.68, 2.38, 8), M_IRON, Vector3(0, 0.34, 0))
	A.add(self, A.torus(1.62, 1.94, 16), M_BRASS, Vector3(0, 0.70, 0), Vector3.ZERO, Vector3(1.0, 0.55, 1.0))
	A.add(self, A.cyl(1.46, 2.05, 1.52, 16), M_RUST, Vector3(0, 1.05, 0))
	A.add(self, A.cyl(1.32, 2.12, 1.32, 16), M_BORE, Vector3(0, 1.08, 0), Vector3.ZERO, Vector3.ONE, false)
	# 顶部铸钢排烟吊装冠环
	A.add(self, A.torus(0.76, 1.02, 16), M_IRON, Vector3(0, 3.06, 0), Vector3.ZERO, Vector3(1.0, 0.60, 1.0))
	A.add(self, A.cyl(0.68, 0.16, 0.68, 12), M_BORE, Vector3(0, 3.06, 0), Vector3.ZERO, Vector3.ONE, false)

	# 2. 环向 8 组：翻裂钢筋混凝土块 + 液压驻锄 + 外翻防爆井盖瓣 + 顶部护笼钢肋
	for i in 8:
		var a := TAU * i / 8.0
		var ca := cos(a)
		var sa := sin(a)
		var yaw := rad_to_deg(atan2(ca, sa))
		# 破土翻起的混凝土残块与外露扭曲螺纹钢筋
		var rc := 2.65 + float(i % 3) * 0.22
		A.add(self, A.bevel_box(Vector3(1.05, 0.32, 0.78), 0.05, 0.85), M_CONC,
			Vector3(ca * rc, 0.16, sa * rc), Vector3(-22.0 - float(i % 2) * 8.0, yaw, float(i % 3 - 1) * 7.0))
		A.add(self, A.cyl(0.024, 0.68, 0.022, 6), M_RUST,
			Vector3(ca * (rc - 0.15), 0.42, sa * (rc - 0.15)), Vector3(-34.0, yaw + 12.0, 0), Vector3.ONE, false)
		# 地锚驻锄底座 + 警示黄端头
		A.add(self, A.bevel_box(Vector3(0.50, 0.30, 0.86), 0.04, 0.90), M_IRON,
			Vector3(ca * 2.18, 0.16, sa * 2.18), Vector3(0, yaw, 0))
		if i % 2 == 0:
			A.add(self, A.bevel_box(Vector3(0.46, 0.10, 0.24), 0.02), M_HAZ,
				Vector3(ca * 2.48, 0.32, sa * 2.48), Vector3(0, yaw, 0))
		# 外翻液压防爆花瓣舱门 + 镀铬顶杆
		A.add(self, A.bevel_box(Vector3(0.76, 1.72, 0.15), 0.03, 0.78), M_STEEL if i % 2 == 0 else M_RUST,
			Vector3(ca * 1.78, 1.48, sa * 1.78), Vector3(-28.0, yaw, 0))
		A.add(self, A.cyl(0.065, 0.76, 0.075, 8), M_IRON,
			Vector3(ca * 2.02, 0.68, sa * 2.02), Vector3(24.0, yaw, 0))
		A.add(self, A.cyl(0.038, 0.68, 0.038, 8), M_CHROME,
			Vector3(ca * 1.90, 1.12, sa * 1.90), Vector3(24.0, yaw, 0))
		# 内收拱形高炉防撞钢梁肋 + 底部炉口百叶视窗
		A.add(self, A.bevel_box(Vector3(0.16, 1.48, 0.22), 0.025, 0.82), M_IRON,
			Vector3(ca * 1.18, 2.38, sa * 1.18), Vector3(22.0, yaw, 0))
		A.add(self, A.bevel_box(Vector3(0.28, 0.14, 0.08), 0.015), M_GLOW,
			Vector3(ca * 1.44, 0.92, sa * 1.44), Vector3(0, yaw, 0), Vector3.ONE, false)

	# 3. 井膛中央感应熔炼炉芯（保留 pulse 呼吸缩放与受击脉动）
	pulse = A.add(self, A.cyl(0.54, 0.96, 0.64, 10), M_GLOW, Vector3(0, 2.18, 0), Vector3.ZERO, Vector3.ONE, false)
	set_meta("_pulse", pulse)
	MechScript._batch_visual(self)
	for ch in get_children():
		if ch is GeometryInstance3D:
			ch.visibility_range_end = 70.0
			ch.visibility_range_end_margin = 4.0
	A.emitter(self, Vector3(0, 3.05, 0), {"amount": 12, "life": 2.4, "size": 0.22, "spread": 42.0, "vmin": 0.5, "vmax": 1.2, "gravity": Vector3(0, 0.55, 0),
		"c0": Color(0.28, 0.26, 0.24, 0.62), "c1": Color(0.16, 0.15, 0.15, 0.0), "grow0": 0.9, "grow1": 0.3})
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.46, 0.16)
	l.light_energy = 2.2
	l.omni_range = 9.0
	l.position.y = 2.8
	l.distance_fade_enabled = true
	l.distance_fade_begin = 55.0
	l.distance_fade_length = 10.0
	add_child(l)


func _physics_process(delta: float) -> void:
	var _pt := Prof.t0()
	var local_mech = raid.mech if raid != null else null
	if raid != null and raid.coop != null: raid.mech = raid.nearest_player(global_position)
	_physics_tick(delta)
	if raid != null: raid.mech = local_mech
	Prof.add("phys.nest", _pt)


func _physics_tick(delta: float) -> void:
	t += delta
	pulse.scale = Vector3.ONE * (1.0 + sin(t * 3.0) * 0.15)
	children_alive = children_alive.filter(func(b): return is_instance_valid(b) and not b.dying)
	if raid == null or raid.mech == null or raid.mech.dead:
		return
	var d := global_position.distance_to(raid.mech.global_position)
	var lk := "nest_%d" % get_instance_id()
	if d > 42.0:
		if Audio.has_loop(lk):
			Audio.loop_stop(lk, 0.8)
		return
	if not Audio.has_loop(lk):
		Audio.loop_start(lk, "nest_loop", self)
	spawn_t -= delta
	if spawn_t <= 0.0 and children_alive.size() < 5:
		spawn_t = randf_range(5.0, 8.0)
		var k := "ling" if randf() < 0.75 else "spitter"
		var b = raid.spawn_bug(k, global_position + Vector3(randf_range(-2, 2), 0.5, randf_range(-2, 2)))
		if b:
			b.state = "chase"
			b.spawn_t = 0.7
			children_alive.append(b)
			Audio.play_sfx("nest_spawn", global_position + Vector3(0, 1.5, 0))


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	pulse.scale = Vector3.ONE * 1.4
	if hp <= 0.0:
		Audio.play_sfx("nest_destroyed", global_position + Vector3(0, 1.5, 0))
		raid.on_nest_destroyed(self)
		queue_free()
	else:
		Audio.play_sfx("nest_hurt", global_position + Vector3(0, 1.5, 0))
