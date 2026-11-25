extends StaticBody3D
## 地下自动铸造破土孵化井：玩家靠近时不断投送机械体，摧毁后留下高价值残骸。

const Prof = preload("res://scripts/prof.gd")
const MechScript = preload("res://scripts/mech.gd")

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")

var hp := 260.0
var raid
var spawn_t := 4.0
var children_alive: Array = []
var pulse: MeshInstance3D
var t := 0.0
var flash_t := 0.0
var _hit_meshes: Array = []
var _hit_flash_q := 0
var _check_acc := 0.25
var _pulse_acc := 0.0
var _near := false


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

	var M_SLAG := A.rock_mat(Color(0.26, 0.20, 0.16))
	var M_CONC := A.rock_mat(Color(0.33, 0.29, 0.25))
	var M_IRON := A.metal(Color(0.20, 0.21, 0.23))
	var M_STEEL := A.metal(Color(0.34, 0.36, 0.38))
	var M_RUST := A.paint(Color(0.42, 0.22, 0.15), 0.35, 0.72, {"rust": 0.65, "wear": 0.55})
	var M_BRASS := A.metal(Color(0.60, 0.47, 0.24))
	var M_CHROME := A.chrome()
	var M_BORE := A.rubber()
	var M_HAZ := A.hazard()
	var M_GLOW := A.emit(Color(1.0, 0.40, 0.11), 1.35)

	# 破土边缘由不等高的断岩包住收分的铸铁井圈。
	A.ground_vfx(self, A.grime_stain_tex(), Color(0.15, 0.11, 0.08, 0.80), 10.5, Vector3(0, 0.026, 0))
	A.add(self, A.cyl(1.98, 0.68, 2.28, 32), M_IRON, Vector3(0, 0.34, 0))
	A.add(self, A.torus(1.61, 1.93, 32), M_BRASS, Vector3(0, 0.70, 0), Vector3.ZERO, Vector3(1, 0.55, 1))
	A.add(self, A.cyl(1.30, 2.05, 1.54, 28), M_RUST, Vector3(0, 1.05, 0))
	A.add(self, A.cyl(1.20, 2.12, 1.33, 28), M_BORE, Vector3(0, 1.08, 0), Vector3.ZERO, Vector3.ONE, false)
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
		var rc := 2.37 + float(i % 3) * 0.32
		var rock_scale := Vector3(1.12 + float(i % 3) * 0.19, 0.36 + float(i % 4) * 0.12, 0.76)
		A.add(self, A.rock_mesh(i + 3), M_SLAG if i % 3 != 1 else M_CONC,
			Vector3(ca * rc, 0.17, sa * rc), Vector3(-12.0, yaw + float(i % 4) * 17.0, float(i % 3 - 1) * 12.0), rock_scale)
		A.add(self, A.rock_mesh(i + 6), M_CONC if i % 3 != 1 else M_SLAG,
			Vector3(ca * (rc + 1.05), 0.08, sa * (rc + 0.76)), Vector3(0, yaw + 32.0, 0), Vector3(0.42, 0.23, 0.34), false)
		A.add(self, A.cyl(0.024, 0.68, 0.022, 6), M_RUST,
			Vector3(ca * (rc - 0.15), 0.42, sa * (rc - 0.15)), Vector3(-34.0, yaw + 12.0, 0), Vector3.ONE, false)
		# 地锚驻锄底座 + 警示黄端头
		A.add(self, A.bevel_box(Vector3(0.50, 0.30, 0.86), 0.04, 0.90), M_IRON,
			Vector3(ca * 2.18, 0.16, sa * 2.18), Vector3(0, yaw, 0))
		if i % 2 == 0:
			A.add(self, A.bevel_box(Vector3(0.46, 0.10, 0.24), 0.02), M_HAZ,
				Vector3(ca * 2.48, 0.32, sa * 2.48), Vector3(0, yaw, 0))
		# 外翻液压防爆花瓣舱门 + 镀铬顶杆
		var notch := 0.46 if i % 3 == 0 else 0.80
		var panel := [Vector2(-0.39, -0.78), Vector2(0.38, -0.78), Vector2(0.44, 0.22),
			Vector2(0.23, notch), Vector2(-0.19, 0.83), Vector2(-0.36, 0.45)]
		var door_rot := Vector3(-24.0 - float(i % 3) * 9.0, yaw, float(i % 3 - 1) * 10.0)
		var door_pos := Vector3(ca * 1.79, 1.44, sa * 1.79)
		K.plate(self, panel, 0.16, M_STEEL if i % 2 == 0 else M_RUST, door_pos, door_rot, 0.025)
		A.add(self, A.bevel_box(Vector3(0.12, 0.91, 0.10), 0.022), M_IRON,
			door_pos + Vector3(ca * 0.10, -0.06, sa * 0.10), door_rot, Vector3.ONE, false)
		A.add(self, A.cyl(0.065, 0.76, 0.075, 8), M_IRON,
			Vector3(ca * 2.02, 0.68, sa * 2.02), Vector3(24.0, yaw, 0))
		A.add(self, A.cyl(0.038, 0.68, 0.038, 8), M_CHROME,
			Vector3(ca * 1.90, 1.12, sa * 1.90), Vector3(24.0, yaw, 0))
		# 内收拱形高炉防撞钢梁肋 + 底部炉口百叶视窗
		A.add(self, A.bevel_box(Vector3(0.16, 1.48, 0.22), 0.025, 0.82), M_IRON,
			Vector3(ca * 1.18, 2.38, sa * 1.18), Vector3(22.0, yaw, 0))
		A.add(self, A.bevel_box(Vector3(0.28, 0.14, 0.08), 0.015), M_GLOW,
			Vector3(ca * 1.44, 0.92, sa * 1.44), Vector3(0, yaw, 0), Vector3.ONE, false)
		if i % 2 == 0:
			var hose_path := [Vector3(ca * 1.10, 2.64, sa * 1.10), Vector3(ca * 1.58, 2.38, sa * 1.58),
				Vector3(ca * 1.98, 0.73, sa * 1.98), Vector3(ca * 2.35, 0.53, sa * 2.35)]
			A.add(self, A.tube(hose_path, 0.079, 16, 8), M_BORE, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)

	# 3. 井膛中央感应熔炼炉芯（保留 pulse 呼吸缩放与受击脉动）
	pulse = A.add(self, A.cyl(0.54, 0.96, 0.64, 10), M_GLOW, Vector3(0, 2.18, 0), Vector3.ZERO, Vector3.ONE, false)
	set_meta("_pulse", pulse)
	MechScript._batch_visual(self)
	for ch in get_children():
		if ch is GeometryInstance3D:
			ch.visibility_range_end = 70.0
			ch.visibility_range_end_margin = 4.0
	_hit_meshes.clear()
	for ch in find_children("*", "MeshInstance3D", true, false):
		if ch is MeshInstance3D:
			_hit_meshes.append(ch)
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
	if flash_t > 0.0:
		flash_t = maxf(0.0, flash_t - delta)
		_update_flash()
	if _near:
		_pulse_acc += delta
		if _pulse_acc >= 0.05:
			_pulse_acc = 0.0
			pulse.scale = Vector3.ONE * (1.0 + sin(t * 3.0) * 0.15)
	_check_acc += delta
	if _check_acc < 0.25:
		return
	var step_dt := _check_acc
	_check_acc = 0.0
	for i in range(children_alive.size() - 1, -1, -1):
		var b = children_alive[i]
		if not is_instance_valid(b) or b.dying:
			children_alive.remove_at(i)
	if raid == null or raid.mech == null or raid.mech.dead:
		_near = false
		return
	var d := global_position.distance_to(raid.mech.global_position)
	_near = d <= 52.0
	var lk := "nest_%d" % get_instance_id()
	if d > 42.0:
		if Audio.has_loop(lk):
			Audio.loop_stop(lk, 0.8)
		return
	if not Audio.has_loop(lk):
		Audio.loop_start(lk, "nest_loop", self)
	spawn_t -= step_dt
	if spawn_t <= 0.0 and children_alive.size() < 5:
		spawn_t = randf_range(5.0, 8.0)
		var k := "ling" if randf() < 0.75 else "spitter"
		var b = raid.spawn_bug(k, global_position + Vector3(randf_range(-2, 2), 0.5, randf_range(-2, 2)))
		if b:
			b.state = "chase"
			b.spawn_t = 0.7
			children_alive.append(b)
			Audio.play_sfx("nest_spawn", global_position + Vector3(0, 1.5, 0))


func _update_flash() -> void:
	var q := clampi(int(ceil(clampf(flash_t / 0.13, 0.0, 1.0) * 5.0)), 0, 5) if flash_t > 0.0 else 0
	if q == _hit_flash_q:
		return
	_hit_flash_q = q
	var mat: Material = A.hit_flash_overlay(float(q) / 5.0) if q > 0 else null
	for ch in _hit_meshes:
		if is_instance_valid(ch):
			ch.material_overlay = mat


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	var prev_hp := hp
	hp -= amount
	if raid != null and raid.hud != null and raid.hud.has_method("notify_enemy_hit"):
		raid.hud.notify_enemy_hit(self, prev_hp, hp, 260.0)
	pulse.scale = Vector3.ONE * 1.4
	flash_t = 0.13
	_update_flash()
	if hp <= 0.0:
		flash_t = 0.0
		_update_flash()
		Audio.play_sfx("nest_destroyed", global_position + Vector3(0, 1.5, 0))
		raid.on_nest_destroyed(self)
		queue_free()
	else:
		Audio.play_sfx("nest_hurt", global_position + Vector3(0, 1.5, 0))
