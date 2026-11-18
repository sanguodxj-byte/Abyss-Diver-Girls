extends "res://tests/lib/test_base.gd"
## 双新首领（六足要塞·陆地巡洋舰 citadel_behemoth + 苍穹铁砧·重工浮空母舰 sky_carrier）体型校验、高清截图与实战 GIF 录制：
##   1) 精确测量主角机甲与 citadel_behemoth 实测渲染网格高度比（断言 >= 4.0 倍）；
##   2) 输出高清比例对比图 review\boss_citadel_scale.png 与浮空母舰特写 review\boss_sky_carrier.png；
##   3) 录制 170 帧（8.5s @ 20FPS，800x450）双首领独立多炮台实战帧序列至 scratch\two_bosses_frames\。
## godot --fixed-fps 20 --disable-vsync --resolution 1280x720 --path . -- --two_bosses_showcase

const TIMEOUT := 600.0
const Factions = preload("res://scripts/factions/factions.gd")
const FRAMES_DIR := "C:/Users/Administrator/.gemini/antigravity/brain/c256213f-bc02-45a0-90b2-70b2657c52a2/scratch/two_bosses_frames"
const OUT_SIZE := Vector2i(800, 450)

var _frame_idx := 0


func run() -> void:
	if headless():
		log_line("headless mode: skipping viewport showcase capture")
		return

	_prepare_frames_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://review"))
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Story.set_process(false)
	Story.data = {}
	get_tree().paused = false
	Factions.rovers_enabled = false
	Factions.test_ally_squad = [{"pilot": "rei", "tier": 2}, {"pilot": "kurumi", "tier": 3}]
	GameData.view_mode = 0
	GameData.map_id = "dustfield"
	await wait(0.35)

	var raid = await deploy({
		"core": "core_heavy",
		"legs": "legs_biped",
		"arm_l": "arm_mg",
		"arm_r": "arm_ac30",
		"back": "back_missile",
		"gen": "gen_crystal",
	})
	if not check(raid != null and raid.mech != null, "尘土平原出击失败"):
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
	await frames(3)

	# 暂时移开友军避免对特写镜头中的首领触发受击白闪
	for a in fac.allies:
		a.set_physics_process(false)
		a.global_position = stand + Vector3(85.0, 0.3, 85.0)

	# ── 阶段 A：体型 4 倍以上与宽体比例（宽 > 高 * 1.6）硬指标实测 + 比例对比高清截图 ──
	m.global_position = stand + Vector3(-13.5, 0.0, 9.5)
	m.velocity = Vector3.ZERO
	if m.get("torso"):
		m.torso.global_rotation = Vector3(0.0, deg_to_rad(28.0), 0.0)
	if m.get("legs"):
		m.legs.global_rotation = Vector3(0.0, deg_to_rad(28.0), 0.0)

	var citadel = raid.spawn_bug("citadel_behemoth", stand + Vector3(2.5, 0.0, -5.5))
	if not check(citadel != null, "citadel_behemoth 生成失败"):
		return
	citadel.data["hp"] = 36000.0
	citadel.hp = 36000.0
	citadel.target = m
	citadel._awaken()
	citadel.guard_t = 99.0
	if is_instance_valid(citadel.visual):
		citadel.visual.rotation.y = deg_to_rad(-22.0)
	await frames(6)

	var mech_box := _world_mesh_aabb(m)
	var cit_box := _world_mesh_aabb(citadel)
	var mech_h: float = mech_box.size.y
	var cit_h: float = cit_box.size.y
	var cit_w: float = maxf(cit_box.size.x, cit_box.size.z)
	var ratio: float = cit_h / maxf(mech_h, 0.1)
	var wh_ratio: float = cit_w / maxf(cit_h, 0.1)
	log_line("SCALE CHECK: mech_h=%.2fm  citadel_aabb=%s (h=%.2fm, w=%.2fm, l=%.2fm)  height_ratio=%.2fx  width_to_height=%.2fx" % [
		mech_h, cit_box.size, cit_h, cit_box.size.x, cit_box.size.z, ratio, wh_ratio
	])
	if not check(ratio >= 4.0, "citadel_behemoth 高度未达主角机甲 4 倍以上：%.2fx (%.2fm vs %.2fm)" % [ratio, cit_h, mech_h]):
		return
	if not check(wh_ratio >= 1.65, "citadel_behemoth 宽高比不足（过窄像塔）：宽 %.2fm / 高 %.2fm = %.2fx" % [cit_w, cit_h, wh_ratio]):
		return

	# 使用独立展示相机拍摄无遮挡低仰角全身宽体比例对比图
	var show_cam := Camera3D.new()
	show_cam.fov = 56.0
	raid.add_child(show_cam)
	show_cam.current = true
	show_cam.global_position = stand + Vector3(-5.5, 6.8, 32.5)
	show_cam.look_at(stand + Vector3(0.8, 7.2, -5.5), Vector3.UP)
	if raid.hud:
		raid.hud.visible = false
	await frames(4)
	await RenderingServer.frame_post_draw
	var scale_img := get_viewport().get_texture().get_image()
	scale_img.save_png(ProjectSettings.globalize_path("res://review/boss_citadel_scale.png"))

	# ── 阶段 B：第一幕实战 GIF（0..94 帧）：宽体六足陆地巡洋舰行进 + 7 座炮台多向独立射击 ──
	if raid.hud:
		raid.hud.visible = true
	if raid.camera:
		raid.camera.current = true
	show_cam.queue_free()

	m.global_position = stand + Vector3(0.0, 0.2, 13.5)
	m.velocity = Vector3.ZERO
	var ally_offs := [Vector3(-15.5, 0.3, 4.5), Vector3(15.5, 0.3, 3.5)]
	for i in fac.allies.size():
		var a = fac.allies[i]
		a.set_physics_process(true)
		a.global_position = stand + ally_offs[i]
		a.max_hp = 1e6
		a.hp = 1e6

	citadel.global_position = stand + Vector3(0.0, 0.0, -11.5)
	if is_instance_valid(citadel.visual):
		citadel.visual.rotation.y = PI
	citadel.guard_t = 0.0
	citadel.atk_cd = 0.4
	if citadel.has_meta("turret_mounts"):
		var tms: Array = citadel.get_meta("turret_mounts")
		for ti in tms.size():
			tms[ti]["cd"] = 0.12 + float(ti) * 0.18
			if str(tms[ti].get("role", "")) == "sub":
				tms[ti]["part_hp"] = 260.0

	raid.set_view_mode(0, false)
	raid.cam_zoom = 1.82
	raid._eff_zoom = 1.82
	raid.cam_focus = stand + Vector3(0.0, 2.5, -2.0)
	if raid.camera:
		raid.camera.global_position = raid.cam_focus + raid.CAM_OFFSET * 1.82
		raid.camera.look_at(raid.cam_focus, Vector3.UP)
	await frames(5)

	await _capture_frames(95, func(i: int) -> void:
		_hold_mech(m)
		get_tree().paused = false
		if is_instance_valid(citadel) and not citadel.dying:
			var aim_pt: Vector3 = citadel.global_position + Vector3(0.0, 7.6, 0.0)
			if citadel.has_meta("turret_mounts"):
				for tur in citadel.get_meta("turret_mounts"):
					if str(tur.get("role", "")) == "sub" and not bool(tur.get("destroyed", false)):
						var yn: Node3D = tur.get("yaw_node")
						if is_instance_valid(yn):
							aim_pt = yn.global_position + Vector3(0.0, 0.8, 0.0)
							break
			raid.aim_override = aim_pt
			raid.cam_zoom = 1.82
			raid._eff_zoom = 1.82
			if i == 36:
				citadel.hp = minf(citadel.hp, float(citadel.data.hp) * 0.58)
			elif i == 38:
				citadel.guard_t = 0.0
			elif i == 66:
				citadel.hp = minf(citadel.hp, float(citadel.data.hp) * 0.24)
			elif i == 68:
				citadel.guard_t = 0.0
				citadel.open_core(12.0)
		if i == 0:
			Input.action_press("fire_left")
			Input.action_press("fire_right")
			Input.action_press("move_right")
		elif i == 28:
			m.ability_cd = 0.0
			m.try_ability()
		elif i == 42:
			Input.action_release("move_right")
			Input.action_press("move_left")
		elif i == 88:
			Input.action_release("move_left")
	)

	var broken_n := 0
	if is_instance_valid(citadel) and citadel.has_meta("turret_mounts"):
		for tur in citadel.get_meta("turret_mounts"):
			if bool(tur.get("destroyed", false)):
				broken_n += 1
	log_line("citadel_behemoth destroyed sub-turrets in combat: %d" % broken_n)
	if not check(broken_n >= 1, "实战集火期间未能打爆任何独立副炮塔"):
		return

	if is_instance_valid(citadel):
		citadel.queue_free()
	_clear_actors(raid, stand)
	await frames(4)

	# ── 阶段 C：苍穹铁砧·重工浮空母舰高清特写 + 第二幕实战 GIF（95..169 帧） ──
	Input.action_release("fire_left")
	Input.action_release("fire_right")
	for a in fac.allies:
		a.set_physics_process(false)
		a.global_position = stand + Vector3(85.0, 0.3, 85.0)

	var carrier = raid.spawn_bug("sky_carrier", stand + Vector3(0.0, 0.3, -8.0))
	if not check(carrier != null, "sky_carrier 生成失败"):
		return
	carrier.data["hp"] = 29500.0
	carrier.hp = 29500.0
	carrier.target = m
	carrier._awaken()
	carrier.guard_t = 99.0
	carrier.atk_cd = 2.0
	if is_instance_valid(carrier.visual):
		carrier.visual.position.y = carrier.hover
		carrier.visual.rotation.y = deg_to_rad(148.0)
	await frames(4)
	carrier.flash_t = 0.0
	carrier._update_flash()

	var sky_cam := Camera3D.new()
	sky_cam.fov = 50.0
	raid.add_child(sky_cam)
	sky_cam.current = true
	sky_cam.global_position = stand + Vector3(-9.5, 3.6, 8.0)
	sky_cam.look_at(stand + Vector3(0.0, 5.8, -8.0), Vector3.UP)
	if raid.hud:
		raid.hud.visible = false
	await frames(2)
	await RenderingServer.frame_post_draw
	var sky_img := get_viewport().get_texture().get_image()
	sky_img.save_png(ProjectSettings.globalize_path("res://review/boss_sky_carrier.png"))

	if raid.hud:
		raid.hud.visible = true
	if raid.camera:
		raid.camera.current = true
	sky_cam.queue_free()

	carrier.guard_t = 0.0
	carrier.atk_cd = 0.25
	if carrier.has_meta("turret_mounts"):
		var cms: Array = carrier.get_meta("turret_mounts")
		for ci in cms.size():
			cms[ci]["cd"] = 0.12 + float(ci) * 0.24
	Input.action_press("fire_left")
	Input.action_press("fire_right")
	m.global_position = stand + Vector3(-2.0, 0.2, 6.5)
	m.velocity = Vector3.ZERO
	for i in fac.allies.size():
		var a = fac.allies[i]
		a.set_physics_process(true)
		a.global_position = stand + [Vector3(-9.0, 0.3, 2.0), Vector3(8.5, 0.3, 2.5)][i]
		a.hp = 1e6

	raid.cam_zoom = 1.22
	raid._eff_zoom = 1.22
	raid.cam_focus = stand + Vector3(0.0, 1.8, -2.5)
	if raid.camera:
		raid.camera.global_position = raid.cam_focus + raid.CAM_OFFSET * 1.22
		raid.camera.look_at(raid.cam_focus, Vector3.UP)
	await frames(3)

	await _capture_frames(75, func(i: int) -> void:
		_hold_mech(m)
		get_tree().paused = false
		if is_instance_valid(carrier) and not carrier.dying:
			raid.aim_override = carrier.global_position + Vector3(0.0, carrier.hover, 0.0)
			raid.cam_zoom = 1.22
			raid._eff_zoom = 1.22
			if i == 30:
				carrier.hp = minf(carrier.hp, float(carrier.data.hp) * 0.56)
			elif i == 32:
				carrier.guard_t = 0.0
		if i == 0:
			Input.action_press("move_right")
		elif i == 20:
			m.ability_cd = 0.0
			m.try_ability()
		elif i == 38:
			Input.action_release("move_right")
			Input.action_press("move_left")
		elif i == 70:
			Input.action_release("move_left")
	)

	Input.action_release("fire_left")
	Input.action_release("fire_right")
	Input.action_release("move_left")
	Input.action_release("move_right")
	raid.aim_override = null
	Factions.test_ally_squad = null
	Factions.rovers_enabled = true
	log_line("captured %d showcase frames to %s" % [_frame_idx, FRAMES_DIR])


func _world_mesh_aabb(root: Node3D) -> AABB:
	var has_b := false
	var box := AABB()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		if mi.mesh is PlaneMesh or mi.mesh is QuadMesh or mi.has_meta("no_flash"):
			continue
		var wb: AABB = mi.global_transform * mi.get_aabb()
		if not has_b:
			box = wb
			has_b = true
		else:
			box = box.merge(wb)
	if not has_b:
		return AABB(root.global_position, Vector3.ONE)
	box.size = box.end - Vector3(box.position.x, root.global_position.y, box.position.z)
	box.position.y = root.global_position.y
	return box


func _capture_frames(count: int, step_fn: Callable) -> void:
	for i in count:
		step_fn.call(i)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if not check(img != null, "第 %d 帧抓取失败" % _frame_idx):
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
			if b.is_in_group("boss") or b.global_position.distance_to(center) < 110.0:
				b.queue_free()
	for n in get_tree().get_nodes_in_group("nests"):
		if is_instance_valid(n):
			n.queue_free()


func _find_open_arena(raid: Node) -> Vector3:
	var sp: PhysicsDirectSpaceState3D = (raid as Node3D).get_world_3d().direct_space_state
	var best := Vector3.ZERO
	var best_score := -1.0
	for gx in range(-120, 121, 24):
		for gz in range(-120, 121, 24):
			var p := Vector3(float(gx), 0.3, float(gz))
			if raid.has_method("in_water") and raid.in_water(p):
				continue
			var ghit := sp.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 15, 0), p + Vector3(0, -3, 0), 1))
			if ghit.is_empty() or absf(ghit.position.y) > 0.65:
				continue
			var clear := true
			for off: Vector3 in [Vector3(0, 0, -22), Vector3(0, 0, 24), Vector3(-16, 0, 0), Vector3(16, 0, 0), Vector3(-14, 0, -14), Vector3(14, 0, -14)]:
				var from := p + Vector3(0, 2.2, 0)
				if not sp.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + off, 1)).is_empty():
					clear = false
					break
			if not clear:
				continue
			var score := 220.0 - Vector2(float(gx), float(gz)).length() * 0.25
			if score > best_score:
				best_score = score
				best = Vector3(float(gx), ghit.position.y, float(gz))
	if best_score > 0.0:
		log_line("selected dustfield open arena at %s" % best)
		return best
	var arena := Vector3(760.0, 0.0, 760.0)
	raid._static_box(Vector3(180, 1, 180), arena - Vector3(0, 0.5, 0), Color(0.46, 0.39, 0.29))
	return arena


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
