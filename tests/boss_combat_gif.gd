extends "res://tests/lib/test_base.gd"
## Boss 实战战斗动图录制：在裂谷矿区（canyon）录制三幕连贯战斗（2.5D 接敌 -> 第一人称破核 -> 击破倒地掉宝），
## 输出 170 帧 800x450 PNG 序列至 scratch\gif_frames\ 供 ffmpeg 合成 GIF/MP4。
## godot --fixed-fps 20 --disable-vsync --resolution 1280x720 --path . -- --boss_combat_gif

const TIMEOUT := 600.0
const Factions = preload("res://scripts/factions/factions.gd")
const FRAMES_DIR := "C:/Users/Administrator/.gemini/antigravity/brain/c256213f-bc02-45a0-90b2-70b2657c52a2/scratch/gif_frames"
const OUT_SIZE := Vector2i(800, 450)

var _frame_idx := 0


func run() -> void:
	if headless():
		log_line("headless mode: skipping viewport GIF capture")
		return

	_prepare_frames_dir()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Story.set_process(false)
	Story.data = {}
	get_tree().paused = false
	Factions.rovers_enabled = false
	Factions.test_ally_squad = [{"pilot": "rei", "tier": 2}, {"pilot": "kurumi", "tier": 3}]
	GameData.view_mode = 0
	GameData.map_id = "canyon"
	await wait(0.35)

	var raid = await deploy({
		"core": "core_heavy",
		"legs": "legs_biped",
		"arm_l": "arm_mg",
		"arm_r": "arm_ac30",
		"back": "back_missile",
		"gen": "gen_crystal",
	})
	if not check(raid != null and raid.mech != null, "裂谷矿区出击失败"):
		return
	Story.set_process(false)
	Story.data = {}
	get_tree().paused = false

	var m = raid.mech
	var fac = raid.factions
	_hold_mech(m)
	await until(func(): return fac.allies.size() == 2, 5.0)

	var stand := _find_open_arena(raid)
	_clear_actors(raid, stand)
	await frames(2)

	m.global_position = stand
	m.velocity = Vector3.ZERO
	for i in fac.allies.size():
		var a = fac.allies[i]
		a.global_position = fac._free_near(stand + [Vector3(-5.8, 0.3, 2.2), Vector3(5.8, 0.3, 2.2)][i])
		a.max_hp = 1e6
		a.hp = 1e6

	var boss_pos := stand + Vector3(0.0, 0.3, -10.5)
	var boss = raid.spawn_bug("excavator_titan", boss_pos)
	if not check(boss != null, "excavator_titan 生成失败"):
		return
	boss.data["hp"] = 18000.0
	boss.hp = 18000.0
	boss.activation = 120.0
	boss.target = m
	if is_instance_valid(boss.visual):
		boss.visual.rotation.y = PI

	# 侧方点缀陪衬虫群，烘托真实战场交火
	var flank_offsets := [
		Vector3(-9.5, 0.3, -7.5),
		Vector3(9.5, 0.3, -7.0),
		Vector3(-11.0, 0.3, -12.5),
		Vector3(10.5, 0.3, -12.0),
	]
	var flank_kinds := ["mantis", "ironjaw", "spitter", "ling"]
	for k in flank_offsets.size():
		var fb = raid.spawn_bug(flank_kinds[k], stand + flank_offsets[k])
		if fb:
			fb.hp = float(fb.hp) * 18.0
			fb.state = "chase"
			fb.target = m

	raid.set_view_mode(0, false)
	raid.cam_zoom = 0.88
	raid._eff_zoom = 0.88
	raid.cam_focus = stand + Vector3(0.0, 0.0, -3.0)
	raid.aim_override = boss.global_position + Vector3(0.0, 2.4, 0.0)
	if raid.camera:
		raid.camera.global_position = raid.cam_focus + raid.CAM_OFFSET * 0.88
		raid.camera.look_at(raid.cam_focus, Vector3.UP)
	await frames(12)

	# ── 第一幕（0..59 帧，3.0s）：2.5D 斜俯视近景战术接敌 ──
	await _capture_frames(60, func(i: int) -> void:
		_hold_mech(m)
		get_tree().paused = false
		if is_instance_valid(boss) and not boss.dying:
			raid.aim_override = boss.global_position + Vector3(0.0, 2.6, 0.0)
			if i == 0:
				boss._awaken()
				boss.guard_t = 0.0
				boss.atk_cd = 0.25
			elif i == 2:
				boss.guard_t = 0.0
		if i == 0:
			Input.action_press("fire_left")
			Input.action_press("fire_right")
		if i == 12:
			m.ability_cd = 0.0
			m.try_ability()
		if i == 15:
			Input.action_press("move_right")
		elif i == 22:
			Input.action_press("dash")
		elif i == 24:
			Input.action_release("dash")
		elif i == 38:
			Input.action_release("move_right")
			Input.action_press("move_left")
		elif i == 58:
			Input.action_release("move_left")
	)

	# ── 第二幕（60..119 帧，3.0s）：第一人称机舱仰视激战 + 三阶段破甲开核 ──
	await _capture_frames(60, func(i: int) -> void:
		_hold_mech(m)
		get_tree().paused = false
		if i == 0:
			Input.action_release("move_left")
			Input.action_release("move_right")
			if is_instance_valid(boss):
				var anchor := stand + Vector3(0.0, 0.2, 0.0)
				if m.global_position.distance_to(boss.global_position) > 16.0 or m.global_position.distance_to(boss.global_position) < 8.5:
					m.global_position = anchor
					m.velocity = Vector3.ZERO
				var aim_t: Vector3 = boss.global_position + Vector3(0.0, 3.1, 0.0)
				raid.aim_override = aim_t
				var to_b: Vector3 = aim_t - m.global_position
				var yaw := atan2(-to_b.x, -to_b.z)
				if m.get("torso"):
					m.torso.global_rotation = Vector3(0.0, yaw, 0.0)
				if m.get("legs"):
					m.legs.global_rotation = Vector3(0.0, yaw, 0.0)
			raid.set_view_mode(1, false)
		if is_instance_valid(boss) and not boss.dying:
			raid.aim_override = boss.global_position + Vector3(0.0, 3.1, 0.0)
			if i == 8:
				boss.hp = minf(boss.hp, float(boss.data.hp) * 0.55)
			elif i == 10:
				boss.guard_t = 0.0
				boss.atk_cd = 0.2
			elif i == 24:
				boss.hp = minf(boss.hp, float(boss.data.hp) * 0.22)
			elif i == 26:
				boss.guard_t = 0.0
				boss.open_core(12.0)
				boss.atk_cd = 0.2
		if i == 15:
			Input.action_press("move_right")
		elif i == 32:
			Input.action_release("move_right")
			Input.action_press("move_left")
		elif i == 40:
			m.ability_cd = 0.0
			m.try_ability()
		elif i == 54:
			Input.action_release("move_left")
	)

	# ── 第三幕（120..174 帧，2.75s）：切回俯视击破、连环殉爆与首领秘藏掉落 ──
	await _capture_frames(55, func(i: int) -> void:
		_hold_mech(m)
		get_tree().paused = false
		if i == 0:
			Input.action_release("move_left")
			Input.action_release("move_right")
			raid.set_view_mode(0, false)
			raid.cam_zoom = 0.80
			raid._eff_zoom = 0.80
			if is_instance_valid(boss):
				var want_m: Vector3 = boss.global_position + Vector3(0.0, 0.2, 10.5)
				if m.global_position.distance_to(want_m) > 4.0:
					m.global_position = fac._free_near(want_m)
					m.velocity = Vector3.ZERO
				raid.cam_focus = boss.global_position.lerp(m.global_position, 0.35)
				if raid.camera:
					raid.camera.global_position = raid.cam_focus + raid.CAM_OFFSET * 0.80
					raid.camera.look_at(raid.cam_focus, Vector3.UP)
		if is_instance_valid(boss):
			raid.aim_override = boss.global_position + Vector3(0.0, 2.4, 0.0)
			if i == 3 and not boss.dying:
				Input.action_release("fire_left")
				Input.action_release("fire_right")
				boss.guard_t = 0.0
				boss.take_damage(999999.0, m.global_position)
	)

	Input.action_release("fire_left")
	Input.action_release("fire_right")
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("dash")
	raid.aim_override = null
	Factions.test_ally_squad = null
	Factions.rovers_enabled = true
	log_line("captured %d frames to %s" % [_frame_idx, FRAMES_DIR])


func _capture_frames(count: int, step_fn: Callable) -> void:
	for i in count:
		step_fn.call(i)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if not check(img != null, "第 %d 帧抓取视口图像失败" % _frame_idx):
			return
		img.resize(OUT_SIZE.x, OUT_SIZE.y, Image.INTERPOLATE_BILINEAR)
		var out_path := FRAMES_DIR.path_join("frame_%04d.png" % _frame_idx)
		var err := img.save_png(out_path)
		if not check(err == OK, "保存帧失败 (%d): %s" % [err, out_path]):
			return
		_frame_idx += 1


func _hold_mech(m) -> void:
	m.shield_time = 99999.0
	m.max_hp = 1e6
	m.hp = 1e6
	m.max_energy = 1e6
	m.energy = 1e6
	m.ammo["arm_l"] = 999
	m.ammo["arm_r"] = 999


func _clear_actors(raid: Node, center: Vector3) -> void:
	for b in get_tree().get_nodes_in_group("bugs"):
		if is_instance_valid(b):
			if b.is_in_group("boss") or b.global_position.distance_to(center) < 85.0:
				b.queue_free()
	for n in get_tree().get_nodes_in_group("nests"):
		if is_instance_valid(n):
			n.queue_free()


func _find_open_arena(raid: Node) -> Vector3:
	var sp: PhysicsDirectSpaceState3D = (raid as Node3D).get_world_3d().direct_space_state
	var cam_off: Vector3 = raid.CAM_OFFSET * 0.88
	var best := Vector3.ZERO
	var best_score := -1.0
	for gx in range(-140, 141, 20):
		for gz in range(-140, 141, 20):
			var p := Vector3(float(gx), 0.3, float(gz))
			if raid.has_method("in_water") and raid.in_water(p):
				continue
			# 检查地面平坦度与开阔度
			var ghit := sp.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 12, 0), p + Vector3(0, -3, 0), 1))
			if ghit.is_empty() or absf(ghit.position.y) > 0.7:
				continue
			var bhit := sp.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 12, -11), p + Vector3(0, -3, -11), 1))
			if bhit.is_empty() or absf(bhit.position.y) > 0.7:
				continue
			var clear := true
			for h_y: float in [1.8, 4.8]:
				var rays := [
					Vector3(0, 0, -24),
					Vector3(0, 0, 22),
					Vector3(-14, 0, 0),
					Vector3(14, 0, 0),
					Vector3(-12, 0, -14),
					Vector3(12, 0, -14),
				]
				for off: Vector3 in rays:
					var from := p + Vector3(0, h_y, 0)
					if not sp.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + off, 1)).is_empty():
						clear = false
						break
				if not clear:
					break
			if not clear:
				continue
			# 校验 2.5D 相机到 Boss 及机甲视线完全无山体/建筑遮挡
			var cam_p := p + Vector3(0, 0, -3.0) + cam_off
			if not sp.intersect_ray(PhysicsRayQueryParameters3D.create(cam_p, p + Vector3(0, 2.5, -10.5), 1)).is_empty():
				continue
			if not sp.intersect_ray(PhysicsRayQueryParameters3D.create(cam_p, p + Vector3(0, 1.5, 0.0), 1)).is_empty():
				continue
			var score := 200.0 - Vector2(float(gx), float(gz)).length() * 0.25
			if score > best_score:
				best_score = score
				best = Vector3(float(gx), ghit.position.y + 0.2, float(gz))
	if best_score > 0.0:
		log_line("selected canyon open arena at %s" % best)
		return best
	var arena := Vector3(760.0, 0.0, 760.0)
	raid._static_box(Vector3(140, 1, 140), arena - Vector3(0, 0.5, 0), Color(0.38, 0.30, 0.24))
	log_line("fallback open arena at %s" % arena)
	return arena + Vector3(0.0, 0.2, 0.0)


func _prepare_frames_dir() -> void:
	DirAccess.make_dir_recursive_absolute(FRAMES_DIR)
	var da := DirAccess.open(FRAMES_DIR)
	if da == null:
		return
	da.list_dir_begin()
	var fn := da.get_next()
	while fn != "":
		if not da.current_is_dir() and fn.ends_with(".png"):
			da.remove(fn)
		fn = da.get_next()
	da.list_dir_end()
