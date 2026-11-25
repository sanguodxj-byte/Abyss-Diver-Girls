extends "res://tests/lib/test_base.gd"
## 剩余 48 款扩展模块（10 底盘 + 10 动力炉 + 28 臂部武器）全高清化实机视觉核验脚本

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
			if a.distance_to(b) < 24.0:
				continue
			for t_frac: float in [0.35, 0.60]:
				var mid := a.lerp(b, t_frac)
				if mid.length() > 140.0:
					continue
				var d2 := (b - a).normalized()
				var fwd := Vector3(d2.x, 0.0, d2.y)
				var cand := Vector3(mid.x, 0.3, mid.y)
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


func _shot_hangar_pair(tag: String, ld: Dictionary, front_deg := 30.0, rear_deg := 148.0, cam_dist := 11.8) -> void:
	GameData.loadout = ld.duplicate()
	main.hub.refresh()
	main.hub.drag = true
	var orig_cam_pos: Vector3 = main.hub.preview_cam.position

	main.hub.spin = deg_to_rad(front_deg)
	main.hub.turntable.rotation.y = main.hub.spin
	main.hub.preview_cam.position = Vector3(0.0, 4.25, cam_dist)
	main.hub.preview_cam.look_at(Vector3(0.0, 2.85, 0.0), Vector3.UP)
	await wait_real(0.55)
	await frames(10)
	await shot("hd48_%s_front.png" % tag, main.hub.hangar_vp)

	main.hub.spin = deg_to_rad(rear_deg)
	main.hub.turntable.rotation.y = main.hub.spin
	main.hub.preview_cam.position = Vector3(0.0, 4.75, cam_dist * 0.94)
	main.hub.preview_cam.look_at(Vector3(0.0, 3.05, 0.0), Vector3.UP)
	await wait_real(0.45)
	await frames(8)
	await shot("hd48_%s_rear.png" % tag, main.hub.hangar_vp)

	main.hub.preview_cam.position = orig_cam_pos
	main.hub.preview_cam.look_at(Vector3(0.0, 3.32, 0.0), Vector3.UP)
	main.hub.drag = false


func run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	GameData.quality = 2
	GameData.apply_quality(get_viewport())
	Story.set_process(false)
	Story.data = {}
	get_tree().paused = false
	WorldLink.force_open = true

	if main.hub == null:
		main.show_hub()
	GameData.apply_quality(main.hub.hangar_vp)

	# 构型 A：Obj-279 四履带重装攻城核防 + MK15 密集阵 CIWS + TOS-220 温压火箭炮 + MHD 等离子体磁流体炉
	var cfg_siege := {
		"core": "core_t90m_proryv",
		"legs": "legs_tread_siege",
		"arm_l": "arm_phalanx",
		"arm_r": "arm_tos220",
		"back": "back_vls",
		"gen": "gen_mhd_plasma_gen",
	}
	await _shot_hangar_pair("01_tread_siege_ciws_tos", cfg_siege, 32.0, 146.0, 12.2)

	# 构型 B：独角仙重甲六足 + CS-88 重装链锯 + PB-09 火药打桩机 + SVBR-10 铅铋快中子堆
	var cfg_melee := {
		"core": "core_abv_shredder",
		"legs": "legs_hex_beetle",
		"arm_l": "arm_cs88",
		"arm_r": "arm_pb09",
		"back": "back_shield",
		"gen": "gen_lfr_lead_bismuth",
	}
	await _shot_hangar_pair("02_hex_beetle_chainsaw_bunker", cfg_melee, 30.0, 150.0, 12.4)

	# 构型 C：重装四足蟹式底盘 + 2A46 125mm 滑膛炮 + M299 地狱火四联导轨 + MTU V12 双涡轮柴油机
	var cfg_crab := {
		"core": "core_m1a2_sepv3",
		"legs": "legs_quad_crab",
		"arm_l": "arm_m299",
		"arm_r": "arm_2a46",
		"back": "back_rack",
		"gen": "gen_mtu_mb873_v12",
	}
	await _shot_hangar_pair("03_quad_crab_2a46_hellfire", cfg_crab, 32.0, 148.0, 12.4)

	# 构型 D：轻型鸟足高机动侦察底盘 + M82 巴雷特反器材狙击炮 + L70 博福斯 40mm 弹夹炮 + AGT1500 燃气轮机
	var cfg_scout := {
		"core": "core_fennek_recon",
		"legs": "legs_biped_scout",
		"arm_l": "arm_bofors40",
		"arm_r": "arm_m82",
		"back": "back_missile",
		"gen": "gen_agt1500_turbine",
	}
	await _shot_hangar_pair("04_biped_scout_m82_bofors", cfg_scout, 28.0, 152.0, 11.4)

	# 构型 E：猛犸液压柱式四足 + HC-40 液压鹰嘴剪 + TH-60 重型液压破碎锤 + LFR 铅铋快堆
	var cfg_demo := {
		"core": "core_pionier_dach",
		"legs": "legs_quad_mammoth",
		"arm_l": "arm_hc40",
		"arm_r": "arm_th60",
		"back": "back_cargo",
		"gen": "gen_lfr_lead_bismuth",
	}
	await _shot_hangar_pair("05_quad_mammoth_shear_hammer", cfg_demo, 30.0, 148.0, 12.2)

	# 构型 F：重装双履带坦克底盘 + LAU-61 九头蛇 19 管蜂巢火箭巢 + M58 MICLIC 火箭排雷索 + 单极脉冲飞轮电源
	var cfg_ord := {
		"core": "core_bradley_busk",
		"legs": "legs_tread_heavy",
		"arm_l": "arm_lau61",
		"arm_r": "arm_miclic",
		"back": "back_rocket",
		"gen": "gen_homopolar_pulse",
	}
	await _shot_hangar_pair("06_tread_heavy_lau61_miclic", cfg_ord, 32.0, 146.0, 12.0)

	# 构型 G：主力 ST-8 标准双足 & SAXX-1 主战双履带加粗/精修对比机位
	var cfg_std_biped := {
		"core": "core_std",
		"legs": "legs_biped",
		"arm_l": "arm_mg",
		"arm_r": "arm_ac30",
		"back": "back_missile",
		"gen": "gen_reactor",
	}
	await _shot_hangar_pair("09_std_biped_upgraded", cfg_std_biped, 28.0, 152.0, 11.2)

	# 裂谷荒漠战区实机日光出击核验（展示 Obj-279 四履带 + 密集阵 CIWS + TOS-220 温压炮 + 友军高清 NPC 机甲！）
	Factions.rovers_enabled = false
	Factions.test_ally_squad = [{"pilot": "rei", "tier": 2}, {"pilot": "kurumi", "tier": 3}]
	GameData.view_mode = 0
	GameData.map_id = "canyon"
	var raid = await deploy(cfg_siege)
	if not check(raid != null and raid.mech != null, "canyon 出击失败"):
		return
	Story.set_process(false)
	get_tree().paused = false
	raid.mech.max_hp = 1e7
	raid.mech.hp = 1e7
	await wait_real(0.8)

	var rd := _find_open_vantage_road(raid)
	var p_can: Vector3 = rd[0]
	var d_can: Vector3 = rd[1]
	var yaw_can := atan2(-d_can.x, -d_can.z)
	for b in get_tree().get_nodes_in_group("bugs"):
		if is_instance_valid(b) and not b.is_in_group("boss") and b.global_position.distance_to(p_can) < 70.0:
			b.queue_free()
	await frames(2)

	var m = raid.mech
	m.global_position = raid.factions._free_near(p_can)
	m.velocity = Vector3.ZERO
	if m.get("vis_anchor") != null and m.vis_anchor != null:
		m.vis_anchor.global_transform = m.global_transform
	if m.get("torso") != null and m.torso != null:
		m.torso.global_rotation = Vector3(0.0, yaw_can, 0.0)
	if m.get("legs") != null and m.legs != null:
		m.legs.global_rotation = Vector3(0.0, yaw_can + 0.14, 0.0)
	for ai in raid.factions.allies.size():
		var al = raid.factions.allies[ai]
		if is_instance_valid(al):
			var side_s := -1.0 if ai == 0 else 1.0
			al.global_position = raid.factions._free_near(m.global_position + d_can * (16.0 + ai * 7.0) + d_can.cross(Vector3.UP) * (side_s * 6.5))
	await wait_real(0.6)
	await frames(10)

	var hud_vis := true
	if raid.hud != null and ("visible" in raid.hud):
		hud_vis = raid.hud.visible
		raid.hud.visible = false
	var fwd := Vector3(-sin(yaw_can), 0.0, -cos(yaw_can))
	var rgt := fwd.cross(Vector3.UP).normalized()
	var c := Camera3D.new()
	c.fov = 52.0
	c.near = 0.25
	c.far = 850.0
	raid.add_child(c)
	c.global_position = m.global_position + fwd * 11.5 + rgt * 5.8 + Vector3(0.0, 4.6, 0.0)
	c.look_at(m.global_position + Vector3(0.0, 2.5, 0.0), Vector3.UP)
	c.make_current()
	await wait_real(0.45)
	await frames(8)
	await shot("hd48_07_canyon_hero_3q.png")
	c.global_position = m.global_position - fwd * 15.5 - rgt * 2.4 + Vector3(0.0, 6.8, 0.0)
	c.look_at(m.global_position + fwd * 15.0 + Vector3(0.0, 2.4, 0.0), Vector3.UP)
	await wait_real(0.35)
	await frames(8)
	await shot("hd48_08_canyon_squad_ots.png")
	raid.camera.make_current()
	c.queue_free()
	if raid.hud != null and ("visible" in raid.hud):
		raid.hud.visible = hud_vis

	done()
