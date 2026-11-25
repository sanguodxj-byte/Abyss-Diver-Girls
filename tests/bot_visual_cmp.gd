extends "res://tests/lib/test_base.gd"
## 《B.o.T》(Battle of Titans) 视觉还原与同场景对比实机采样脚本（带碰撞视线保障）

const TIMEOUT := 420.0
const Factions = preload("res://scripts/factions/factions.gd")
const WorldLink = preload("res://scripts/world_link.gd")


func _find_open_vantage_road(raid: Node) -> Array:
	var sp: PhysicsDirectSpaceState3D = (raid as Node3D).get_world_3d().direct_space_state
	var best_score := -1e9
	var best_p := Vector3(0.0, 0.3, 24.0)
	var best_dir := Vector3(0.0, 0.0, -1.0)
	for cv: Dictionary in raid.curves:
		var w := float(cv.get("w", 6.0))
		var pts: PackedVector2Array = cv.get("pts", PackedVector2Array())
		if pts.size() < 2:
			continue
		for k in pts.size() - 1:
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[k + 1]
			var seg_len := a.distance_to(b)
			if seg_len < 24.0:
				continue
			for t_frac: float in [0.30, 0.55, 0.75]:
				var mid := a.lerp(b, t_frac)
				if mid.length() > 140.0:
					continue
				var d2 := (b - a).normalized()
				var fwd := Vector3(d2.x, 0.0, d2.y)
				var cand := Vector3(mid.x, 0.3, mid.y)
				# Raycast behind & ahead along the road so both camera and horizon vista are 100% unobstructed!
				var eye := cand + Vector3(0.0, 4.2, 0.0)
				var rq_back := PhysicsRayQueryParameters3D.create(eye, eye - fwd * 22.0 + Vector3(0.0, 4.5, 0.0), 1)
				var rq_fwd := PhysicsRayQueryParameters3D.create(eye, eye + fwd * 45.0, 1)
				var h_back := sp.intersect_ray(rq_back)
				var h_fwd := sp.intersect_ray(rq_fwd)
				var clear_b := 24.0 if h_back.is_empty() else eye.distance_to(h_back.position)
				var clear_f := 45.0 if h_fwd.is_empty() else eye.distance_to(h_fwd.position)
				var score := clear_b * 3.0 + clear_f * 1.6 + w * 6.0 - mid.length() * 0.12
				if not bool(cv.get("dirt", false)):
					score += 12.0
				if score > best_score:
					best_score = score
					best_p = cand
					best_dir = fwd
	return [best_p, best_dir]


func _clear_bugs_near(center: Vector3, radius: float) -> void:
	for b in get_tree().get_nodes_in_group("bugs"):
		if is_instance_valid(b) and not b.is_in_group("boss") and b.global_position.distance_to(center) < radius:
			b.queue_free()
	await frames(2)


func _place_and_orient(raid: Node, pos: Vector3, yaw: float) -> void:
	var m = raid.mech
	var safe_p: Vector3 = raid.factions._free_near(pos)
	m.global_position = safe_p
	m.velocity = Vector3.ZERO
	m.slam = 0.0
	m.land_t = 0.0
	if m.get("vis_anchor") != null and m.vis_anchor != null:
		m.vis_anchor.global_transform = m.global_transform
	if m.get("torso") != null and m.torso != null:
		m.torso.global_rotation = Vector3(0.0, yaw, 0.0)
	if m.get("legs") != null and m.legs != null:
		m.legs.global_rotation = Vector3(0.0, yaw + 0.12, 0.0)
	m.aim_point = m.global_position + Vector3(-sin(yaw), 0.0, -cos(yaw)) * 45.0 + Vector3(0.0, 2.2, 0.0)
	raid.cam_focus = Vector3(m.global_position.x, 0.0, m.global_position.z)
	raid._aim_pan = Vector3.ZERO
	raid.cam_zoom = raid.ZOOM_STD * 0.85
	raid._eff_zoom = raid.cam_zoom
	raid.camera.global_position = raid.cam_focus + raid.CAM_OFFSET * raid._eff_zoom
	raid.camera.look_at(raid.cam_focus, Vector3.UP)


func _shot_safe_bot_cam(raid: Node, anchor: Vector3, candidates: Array, look_target: Vector3, fov_deg: float, filename: String) -> void:
	var sp: PhysicsDirectSpaceState3D = (raid as Node3D).get_world_3d().direct_space_state
	var best_cam: Vector3 = candidates[0]
	var best_d := -1.0
	var origin := anchor + Vector3(0.0, 3.6, 0.0)
	for cand: Vector3 in candidates:
		var rq := PhysicsRayQueryParameters3D.create(origin, cand, 1)
		var hit := sp.intersect_ray(rq)
		if hit.is_empty():
			best_cam = cand
			best_d = 999.0
			break
		var d := origin.distance_to(hit.position)
		if d > best_d:
			best_d = d
			best_cam = origin.lerp(hit.position, 0.86)

	var hud_vis := true
	if raid.hud != null and ("visible" in raid.hud):
		hud_vis = raid.hud.visible
		raid.hud.visible = false
	var c := Camera3D.new()
	c.fov = fov_deg
	c.near = 0.25
	c.far = 850.0
	raid.add_child(c)
	c.global_position = best_cam
	c.look_at(look_target, Vector3.UP)
	c.make_current()
	await wait_real(0.45)
	await frames(8)
	await shot(filename)
	raid.camera.make_current()
	c.queue_free()
	if raid.hud != null and ("visible" in raid.hud):
		raid.hud.visible = hud_vis
	await frames(3)


func run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	GameData.quality = 2
	GameData.apply_quality(get_viewport())
	Story.set_process(false)
	Story.data = {}
	get_tree().paused = false
	WorldLink.force_open = true

	# 1. 机库 BAY 03 实机检验（正面 3/4 + 背面橙黄导弹与弧形绿光散热扇特写）
	var hero_loadout := {
		"core": "core_std",
		"legs": "legs_biped",
		"arm_l": "arm_mg",
		"arm_r": "arm_ac30",
		"back": "back_missile",
		"gen": "gen_reactor",
	}
	GameData.loadout = hero_loadout.duplicate()
	if main.hub == null:
		main.show_hub()
	GameData.apply_quality(main.hub.hangar_vp)
	main.hub.refresh()
	main.hub.drag = true
	main.hub.spin = deg_to_rad(28.0)
	main.hub.turntable.rotation.y = main.hub.spin
	await wait_real(1.2)
	await frames(12)
	await shot("bot_cmp_01_hangar_ui.png")
	await shot("bot_cmp_01_hangar_bay03.png", main.hub.hangar_vp)

	var orig_cam_pos: Vector3 = main.hub.preview_cam.position
	main.hub.spin = deg_to_rad(152.0)
	main.hub.turntable.rotation.y = main.hub.spin
	main.hub.preview_cam.position = Vector3(0.0, 4.85, 11.2)
	main.hub.preview_cam.look_at(Vector3(0.0, 3.45, 0.0), Vector3.UP)
	await wait_real(0.5)
	await frames(8)
	await shot("bot_cmp_01b_hangar_dorsal_closeup.png", main.hub.hangar_vp)
	main.hub.preview_cam.position = orig_cam_pos
	main.hub.preview_cam.look_at(Vector3(0.0, 3.32, 0.0), Vector3.UP)
	main.hub.drag = false

	# 2. 裂谷荒漠战区 canyon（canyon_noon）—— 1:1 对标 B.o.T 荒漠公路机位 bot_ipad_0.jpg
	Factions.rovers_enabled = false
	Factions.test_ally_squad = [{"pilot": "rei", "tier": 2}]
	GameData.view_mode = 0
	GameData.map_id = "canyon"
	var raid = await deploy(hero_loadout)
	if not check(raid != null and raid.mech != null, "canyon 出击失败"):
		return
	Story.set_process(false)
	get_tree().paused = false
	raid.mech.max_hp = 1e7
	raid.mech.hp = 1e7
	await wait_real(0.8)

	var rd_canyon := _find_open_vantage_road(raid)
	var p_can: Vector3 = rd_canyon[0]
	var d_can: Vector3 = rd_canyon[1]
	var yaw_can := atan2(-d_can.x, -d_can.z)
	await _clear_bugs_near(p_can, 70.0)
	_place_and_orient(raid, p_can, yaw_can)
	if raid.factions.allies.size() > 0 and is_instance_valid(raid.factions.allies[0]):
		var al = raid.factions.allies[0]
		al.global_position = raid.factions._free_near(raid.mech.global_position + d_can * 22.0 - d_can.cross(Vector3.UP) * 7.5)
	await wait_real(0.7)
	await frames(10)
	await shot("bot_cmp_03_canyon_tps_live.png")

	var mp: Vector3 = raid.mech.global_position
	var fwd := Vector3(-sin(yaw_can), 0.0, -cos(yaw_can))
	var rgt := fwd.cross(Vector3.UP).normalized()
	await _shot_safe_bot_cam(
		raid, mp,
		[
			mp - fwd * 16.5 - rgt * 2.2 + Vector3(0.0, 6.8, 0.0),
			mp - fwd * 16.5 + rgt * 2.2 + Vector3(0.0, 6.8, 0.0),
			mp - fwd * 14.5 + Vector3(0.0, 7.2, 0.0),
		],
		mp + fwd * 16.0 + Vector3(0.0, 2.5, 0.0),
		53.0,
		"bot_cmp_02_canyon_bot_ots.png"
	)

	# 3. 灰港城区战区 greyport（clear）—— 1:1 对标 B.o.T 城区高视点俯冲构图 bot_ipad_1.jpg
	main.show_hub()
	await wait_real(0.5)
	Factions.test_ally_squad = [{"pilot": "rei", "tier": 2}, {"pilot": "kurumi", "tier": 3}]
	GameData.map_id = "greyport"
	var scout_loadout := {
		"core": "core_scout",
		"legs": "legs_biped",
		"arm_l": "arm_slug",
		"arm_r": "arm_ac30",
		"back": "back_missile",
		"gen": "gen_reactor",
	}
	raid = await deploy(scout_loadout)
	if not check(raid != null and raid.mech != null, "greyport 出击失败"):
		return
	Story.set_process(false)
	get_tree().paused = false
	raid.mech.max_hp = 1e7
	raid.mech.hp = 1e7
	await wait_real(0.8)

	var rd_grey := _find_open_vantage_road(raid)
	var p_grey: Vector3 = rd_grey[0]
	var d_grey: Vector3 = rd_grey[1]
	var yaw_grey := atan2(-d_grey.x, -d_grey.z)
	await _clear_bugs_near(p_grey, 70.0)
	_place_and_orient(raid, p_grey, yaw_grey)
	for ai in raid.factions.allies.size():
		var al2 = raid.factions.allies[ai]
		if is_instance_valid(al2):
			var side_s := -1.0 if ai == 0 else 1.0
			al2.global_position = raid.factions._free_near(raid.mech.global_position + d_grey * (18.0 + ai * 8.0) + d_grey.cross(Vector3.UP) * (side_s * 6.5))
	await wait_real(0.7)
	await frames(10)
	await shot("bot_cmp_05_greyport_tps_live.png")

	var mp2: Vector3 = raid.mech.global_position
	var fwd2 := Vector3(-sin(yaw_grey), 0.0, -cos(yaw_grey))
	var rgt2 := fwd2.cross(Vector3.UP).normalized()
	await _shot_safe_bot_cam(
		raid, mp2,
		[
			mp2 - fwd2 * 15.5 - rgt2 * 3.2 + Vector3(0.0, 9.4, 0.0),
			mp2 - fwd2 * 15.5 + rgt2 * 3.2 + Vector3(0.0, 9.4, 0.0),
			mp2 - fwd2 * 14.0 + Vector3(0.0, 10.2, 0.0),
		],
		mp2 + fwd2 * 14.0 + Vector3(0.0, 2.2, 0.0),
		52.0,
		"bot_cmp_04_greyport_dorsal.png"
	)

	# 4. 铁带重工战区 ironbelt（dusk_gloom）—— 1:1 对标 B.o.T 重装碉堡参考图 bot_ipad_3.jpg
	main.show_hub()
	await wait_real(0.5)
	Factions.test_ally_squad = [{"pilot": "kurumi", "tier": 3}]
	GameData.map_id = "ironbelt"
	var heavy_loadout := {
		"core": "core_heavy",
		"legs": "legs_biped_assault",
		"arm_l": "arm_hmg",
		"arm_r": "arm_gatling",
		"back": "back_shield",
		"gen": "gen_diesel",
	}
	raid = await deploy(heavy_loadout)
	if not check(raid != null and raid.mech != null, "ironbelt 出击失败"):
		return
	Story.set_process(false)
	get_tree().paused = false
	raid.mech.max_hp = 1e7
	raid.mech.hp = 1e7
	await wait_real(0.8)

	var rd_iron := _find_open_vantage_road(raid)
	var p_iron: Vector3 = rd_iron[0]
	var d_iron: Vector3 = rd_iron[1]
	var yaw_iron := atan2(-d_iron.x, -d_iron.z)
	await _clear_bugs_near(p_iron, 70.0)
	_place_and_orient(raid, p_iron, yaw_iron)
	if raid.factions.allies.size() > 0 and is_instance_valid(raid.factions.allies[0]):
		var al3 = raid.factions.allies[0]
		al3.global_position = raid.factions._free_near(raid.mech.global_position + d_iron * 20.0 - d_iron.cross(Vector3.UP) * 7.0)
	await wait_real(0.7)
	await frames(10)
	await shot("bot_cmp_07_ironbelt_tps_live.png")

	var mp3: Vector3 = raid.mech.global_position
	var fwd3 := Vector3(-sin(yaw_iron), 0.0, -cos(yaw_iron))
	var rgt3 := fwd3.cross(Vector3.UP).normalized()
	await _shot_safe_bot_cam(
		raid, mp3,
		[
			mp3 - fwd3 * 15.8 - rgt3 * 3.0 + Vector3(0.0, 6.6, 0.0),
			mp3 - fwd3 * 15.8 + rgt3 * 3.0 + Vector3(0.0, 6.6, 0.0),
			mp3 + fwd3 * 14.5 + rgt3 * 5.2 + Vector3(0.0, 5.8, 0.0),
		],
		mp3 + fwd3 * 14.0 + Vector3(0.0, 2.6, 0.0),
		52.0,
		"bot_cmp_06_ironbelt_heavy.png"
	)

	Factions.test_ally_squad = null
	Factions.rovers_enabled = true
	log_line("All 8 B.o.T visual comparison shots captured successfully!")
