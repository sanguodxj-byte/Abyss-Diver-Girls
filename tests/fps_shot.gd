extends "res://tests/lib/test_base.gd"
## 第一人称与第三人称切换、全向移动瞄准射击、无条件指针解锁、流式视距及多战区 360 度天空盒实机测试。

const TIMEOUT := 600.0
const Factions = preload("res://scripts/factions/factions.gd")
const WorldLink = preload("res://scripts/world_link.gd")


## 在当前战区道路网中寻找最宽阔笔直的主干道段落，返回 [起点3D, 朝向单位向量3D]
func _find_boulevard(raid: Node) -> Array:
	var best_score := -1.0
	var best_p := Vector3(0.0, 0.3, 40.0)
	var best_dir := Vector3(0.0, 0.0, -1.0)
	for cv: Dictionary in raid.curves:
		if bool(cv.get("dirt", false)):
			continue
		var w := float(cv.get("w", 6.0))
		var pts: PackedVector2Array = cv.get("pts", PackedVector2Array())
		if pts.size() < 2:
			continue
		for k in pts.size() - 1:
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[k + 1]
			var seg_len := a.distance_to(b)
			if seg_len < 28.0:
				continue
			var mid := a.lerp(b, 0.25)
			if mid.length() > 125.0:
				continue
			var score := w * 12.0 + minf(seg_len, 110.0) - mid.length() * 0.18
			if bool(cv.get("bridge", false)):
				score += 18.0
			if score > best_score:
				best_score = score
				var d2 := (b - a).normalized()
				best_p = Vector3(mid.x, 0.3, mid.y)
				best_dir = Vector3(d2.x, 0.0, d2.y)
	return [best_p, best_dir]


func _sample_perf(tag: String, count := 45) -> Dictionary:
	var ft: Array = []
	var dc := 0
	var ob := 0
	var pm := 0
	var last := Time.get_ticks_usec()
	for i in count:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		if i > 2:
			ft.append((now - last) / 1000.0)
		last = now
		dc = maxi(dc, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		ob = maxi(ob, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		pm = maxi(pm, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	ft.sort()
	var avg := 0.0
	for v: float in ft:
		avg += v
	avg /= maxf(1.0, float(ft.size()))
	var p95: float = ft[int(ft.size() * 0.95)] if not ft.is_empty() else 0.0
	var res := {
		"tag": tag,
		"frame_ms": snappedf(avg, 0.01),
		"p95_ms": snappedf(p95, 0.01),
		"fps": int(roundf(1000.0 / maxf(avg, 0.01))),
		"draw_calls": dc,
		"objects": ob,
		"primitives": pm,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	}
	log_line("perf[%s]: avg=%.2fms p95=%.2fms fps=%d draw=%d obj=%d prim=%d nodes=%d" % [
		tag, res.frame_ms, res.p95_ms, res.fps, res.draw_calls, res.objects, res.primitives, res.nodes])
	return res


func _clear_nearby_bugs(center: Vector3, radius: float) -> void:
	for b in get_tree().get_nodes_in_group("bugs"):
		if not b.is_in_group("boss") and b.global_position.distance_to(center) < radius:
			b.queue_free()
	await frames(2)


func _find_open_vantage(raid: Node) -> Vector3:
	var sp: PhysicsDirectSpaceState3D = (raid as Node3D).get_world_3d().direct_space_state
	var best_p: Vector3 = raid.factions._free_near(Vector3(0.0, 0.3, 0.0))
	var best_min_d := -1.0
	var dirs := [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]
	for r in [0.0, 22.0, 44.0, 66.0]:
		var steps := 1 if r == 0.0 else 12
		for k in steps:
			var ang := TAU * float(k) / float(steps)
			var cand: Vector3 = raid.factions._free_near(Vector3(cos(ang) * r, 0.3, sin(ang) * r))
			var from := cand + Vector3(0.0, 2.1, 0.0)
			var min_d := 55.0
			for d: Vector3 in dirs:
				var rq := PhysicsRayQueryParameters3D.create(from, from + d * 55.0, 1)
				var hit: Dictionary = sp.intersect_ray(rq)
				if not hit.is_empty():
					min_d = minf(min_d, from.distance_to(hit.position))
			if min_d > best_min_d:
				best_min_d = min_d
				best_p = cand
				if best_min_d >= 50.0:
					return best_p
	return best_p


func _orient_mech(m: Node3D, yaw: float) -> void:
	if m.get("vis_anchor") != null and m.vis_anchor != null:
		m.vis_anchor.global_transform = m.global_transform
	if m.get("torso") != null:
		m.torso.global_rotation = Vector3(0.0, yaw, 0.0)
	if m.get("legs") != null:
		m.legs.global_rotation = Vector3(0.0, yaw, 0.0)
	m.aim_point = m.global_position + Vector3(-sin(yaw), 0.0, -cos(yaw)) * 40.0 + Vector3(0.0, 1.8, 0.0)


func _press_f5() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F5
	ev.pressed = true
	Input.parse_input_event(ev)


func run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Story.set_process(false)
	Story.data = {}
	get_tree().paused = false
	WorldLink.force_open = true
	Factions.rovers_enabled = false
	Factions.test_ally_squad = [{"pilot": "rei", "tier": 2}, {"pilot": "kurumi", "tier": 3}]
	GameData.view_mode = 0
	GameData.mouse_sens = 1.0
	GameData.map_id = "greyport"
	await wait(0.35)

	var raid = await deploy({
		"core": "core_std",
		"legs": "legs_biped",
		"arm_l": "arm_mg",
		"arm_r": "arm_ac30",
		"back": "back_missile",
		"gen": "gen_reactor",
	})
	if not check(raid != null and raid.mech != null, "灰港出击失败"):
		return
	Story.set_process(false)
	get_tree().paused = false

	var m = raid.mech
	var hud = raid.hud
	var fac = raid.factions
	m.shield_time = 99999.0
	m.max_hp = 1e7
	m.hp = 1e7
	m.max_energy = 1e7
	m.energy = 1e7
	await until(func(): return fac.allies.size() == 2, 5.0)

	# ── 阶段 A：验证 1/3 人称切换（F5 与设置面板）、AI 视野解耦与无条件指针解锁 ──
	if not check(raid.view_mode == 0 and not raid.is_first_person(), "初始应为第三人称俯视模式"):
		return
	var aggro_tp: float = raid.scaled_aggro(30.0)
	var vision_tp: float = raid.vision_range()

	# A1. 设置面板控件与切换验证
	hud.toggle_pause()
	await frames(2)
	hud._open_settings()
	await frames(2)
	for b in hud.settings_panel.find_children("*", "Button", true, false):
		if b is Button and b.text == "常规":
			b.pressed.emit()
			break
	await frames(2)
	var sens_slider: HSlider = null
	if hud._view_opt != null and hud._view_opt.get_parent() != null:
		for ch in hud._view_opt.get_parent().get_children():
			if ch is HSlider:
				sens_slider = ch
				break
	if not check(hud._view_opt != null and sens_slider != null, "设置面板缺少视角模式或鼠标灵敏度控件"):
		return
	hud._view_opt.select(1)
	hud._view_opt.item_selected.emit(1)
	sens_slider.value = 1.35
	await frames(3)
	if not check(raid.is_first_person() and GameData.view_mode == 1 and is_equal_approx(GameData.mouse_sens, 1.35), "设置面板切换第一人称与灵敏度未生效"):
		return
	await shot("fps_13_settings_view_mode.png")
	hud._close_settings()
	hud.toggle_pause()
	await frames(2)

	# A2. F5 快捷键来回切换验证（含自身模型穿透状态切换与恢复断言）
	_press_f5()
	await frames(3)
	var ev_up1 := InputEventKey.new()
	ev_up1.physical_keycode = KEY_F5
	ev_up1.pressed = false
	Input.parse_input_event(ev_up1)
	if not check(not raid.is_first_person() and raid.view_mode == 0 and is_equal_approx(raid.camera.fov, 40.0) and not m._fp_passthrough,
		"按 F5 切回第三人称失败: vm=%s fov=%s pause=%s set=%s" % [raid.view_mode, raid.camera.fov, hud.pause_panel.visible, hud.settings_panel.visible]):
		return
	_press_f5()
	await frames(3)
	var ev_up2 := InputEventKey.new()
	ev_up2.physical_keycode = KEY_F5
	ev_up2.pressed = false
	Input.parse_input_event(ev_up2)
	if not check(raid.is_first_person() and raid.view_mode == 1 and raid.camera.fov > 65.0 and m._fp_passthrough,
		"按 F5 切入第一人称失败: vm=%s fov=%s" % [raid.view_mode, raid.camera.fov]):
		return
	var mods_dict: Dictionary = m.visual.get_meta("modules")
	var arm_l_n: Node = mods_dict.get("arm_l")
	var arm_r_n: Node = mods_dict.get("arm_r")
	var opaque_body_meshes := 0
	var visible_weapon_meshes := 0
	for n in m.visual.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.get_parent() == m.visual and mi.position.y < 0.06:
			continue
		var is_wpn := (arm_l_n != null and (mi == arm_l_n or arm_l_n.is_ancestor_of(mi))) or (arm_r_n != null and (mi == arm_r_n or arm_r_n.is_ancestor_of(mi)))
		var cam_vis: bool = mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and (mi.layers & int(raid.camera.cull_mask)) != 0
		if is_wpn:
			if cam_vis:
				visible_weapon_meshes += 1
		else:
			if cam_vis:
				opaque_body_meshes += 1
	if not check(opaque_body_meshes == 0 and visible_weapon_meshes > 0,
		"第一人称机体穿透与武器保留断言失败: body=%d weapon=%d" % [opaque_body_meshes, visible_weapon_meshes]):
		return

	# A3. AI 索敌视野距离解耦断言（第三人称 40 度 vs 第一人称 74 度）
	var aggro_fp: float = raid.scaled_aggro(30.0)
	var vision_fp: float = raid.vision_range()
	if not check(is_equal_approx(aggro_tp, aggro_fp) and is_equal_approx(vision_tp, vision_fp),
		"AI 视野随相机 FOV 发生了漂移: tp=%s fp=%s" % [aggro_tp, aggro_fp]):
		return

	# A4. 指针捕获与无条件退出路径断言
	raid._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	raid.force_mouse_capture = true
	hud._update_cursor()
	if not check(raid.should_capture_mouse(), "第一人称正常战斗态应允许捕获鼠标"):
		return
	# 逃生路径 1：ESC 暂停立即解锁
	hud.toggle_pause()
	await frames(1)
	if not check(not raid.should_capture_mouse() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "打开暂停面板后鼠标未立即解锁"):
		return
	hud.toggle_pause()
	await frames(1)
	# 逃生路径 2：Tab 货舱立即解锁
	hud.toggle_inventory()
	await frames(1)
	if not check(not raid.should_capture_mouse() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "打开货舱面板后鼠标未立即解锁"):
		return
	hud.toggle_inventory()
	await frames(1)
	# 逃生路径 3：M 大地图立即解锁
	hud.toggle_map()
	await frames(1)
	if not check(not raid.should_capture_mouse() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "打开大地图后鼠标未立即解锁"):
		return
	hud.toggle_map()
	await frames(1)
	# 逃生路径 4：窗口失焦立即解锁
	raid._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	if not check(not raid.should_capture_mouse() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "窗口失焦后鼠标未立即解锁"):
		return
	raid._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	raid.force_mouse_capture = false
	hud._update_cursor()

	# A5. 全向镜头相对移动（WASD 跟随任意水平朝向）断言
	for yaw_deg in [0.0, 90.0, 180.0, -90.0]:
		raid.fp_yaw = deg_to_rad(yaw_deg)
		var expect_fwd: Vector3 = raid.fp_forward_xz()
		var expect_right := Vector3(-expect_fwd.z, 0.0, expect_fwd.x)
		Input.action_press("move_up")
		var mv_f: Vector3 = m.move_vec()
		Input.action_release("move_up")
		if not check(mv_f.distance_to(expect_fwd) < 0.05, "第一人称前向移动未对齐镜头朝向 yaw=%s mv=%s exp=%s" % [yaw_deg, mv_f, expect_fwd]):
			return
		Input.action_press("move_right")
		var mv_r: Vector3 = m.move_vec()
		Input.action_release("move_right")
		if not check(mv_r.distance_to(expect_right) < 0.05, "第一人称右移未对齐镜头右向 yaw=%s mv=%s exp=%s" % [yaw_deg, mv_r, expect_right]):
			return

	# A6. 三维俯仰瞄准方向断言
	var base_yaw := atan2(m.torso.global_transform.basis.z.x, m.torso.global_transform.basis.z.z)
	var f_dir := Vector3(-sin(base_yaw), 0.0, -cos(base_yaw))
	m.aim_point = m.global_position + f_dir * 20.0 + Vector3(0.0, 12.0, 0.0)
	var ad_up: Vector3 = m.aim_dir()
	m.aim_point = m.global_position + f_dir * 20.0 + Vector3(0.0, -8.0, 0.0)
	var ad_dn: Vector3 = m.aim_dir()
	if not check(ad_up.y > 0.35 and ad_dn.y < -0.30, "三维俯仰 aim_dir 未产生上下俯仰分量: up=%s dn=%s" % [ad_up, ad_dn]):
		return
	log_line("functional assertions passed: view toggle, AI vision decoupling, cursor escape, 360 move, 3D pitch aim")

	# ── 阶段 B：灰港主干道第三人称 vs 第一人称同机位对比（含原生前向流式分块验证） ──
	var road_info := _find_boulevard(raid)
	var street_pos: Vector3 = fac._free_near(road_info[0])
	var fwd: Vector3 = road_info[1]
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var street_yaw := atan2(-fwd.x, -fwd.z)
	log_line("boulevard pos=%s fwd=%s" % [street_pos, fwd])

	m.global_position = street_pos
	m.velocity = Vector3.ZERO
	_orient_mech(m, street_yaw)
	await _clear_nearby_bugs(street_pos, 85.0)
	for i in fac.allies.size():
		var a = fac.allies[i]
		a.global_position = fac._free_near(street_pos + fwd * 9.5 + right * (-3.8 if i == 0 else 4.2))
		a.max_hp = 1e6
		a.hp = 1e6
	raid.aim_override = street_pos + fwd * 55.0 + Vector3(0.0, 1.8, 0.0)

	# B1. 第三人称俯视模式
	raid.set_view_mode(0)
	await wait(0.65)
	await _sample_perf("greyport_tp_overview", 35)
	await shot("fps_01_tp_vs_fp_tp.png")

	# B2. 切换第一人称机舱视角（验证 render_batch 自动前向扩展流式视距 + 阴雨天空盒）
	raid.set_view_mode(1)
	m.global_position = street_pos
	m.velocity = Vector3.ZERO
	_orient_mech(m, street_yaw)
	raid.aim_override = street_pos + fwd * 65.0 + Vector3(0.0, 2.2, 0.0)
	await wait(0.55)
	m.global_position = street_pos
	m.velocity = Vector3.ZERO
	_orient_mech(m, street_yaw)
	for i in fac.allies.size():
		var a = fac.allies[i]
		a.global_position = fac._free_near(street_pos + fwd * 12.5 + right * (-4.6 if i == 0 else 4.8))
		a.velocity = Vector3.ZERO
	await frames(2)
	var rb = raid._rb()
	if not check(rb._fp_vis, "第一人称下 render_batch 未自动切入远景流式模式"):
		return
	await _sample_perf("greyport_fp_stream", 35)
	for i in fac.allies.size():
		var a = fac.allies[i]
		a.global_position = fac._free_near(street_pos + fwd * 12.5 + right * (-4.6 if i == 0 else 4.8))
		a.velocity = Vector3.ZERO
	await frames(2)
	await shot("fps_02_tp_vs_fp_fp.png")

	# ── 阶段 C：灰港街头第一人称混合虫潮 + 流浪者 + 队友协同交火 ──
	var kinds := ["ling", "spitter", "mantis", "beetle", "bomber", "wasp", "crystal_bug", "ironjaw", "mech_beetle", "ling"]
	for i in 22:
		var row := int(i / 6)
		var col := i % 6
		var lat := (-7.5 + col * 3.0 + randf_range(-0.5, 0.5))
		var dist := 13.0 + row * 5.2 + randf_range(-0.5, 0.5)
		var b = raid.spawn_bug(kinds[i % kinds.size()], fac._free_near(street_pos + fwd * dist + right * lat) + Vector3(0, 0.3, 0))
		if b:
			b.hp = float(b.hp) * 25.0
			b.state = "chase"
			b.target = m
	var sq: Dictionary = fac.spawn_squad(2, [street_pos + fwd * 28.0 + right * -5.0, street_pos + fwd * 36.0 + right * 5.0])
	for r in sq.get("members", []):
		r.max_hp = 1e5
		r.hp = 1e5
	raid.aim_override = street_pos + fwd * 18.0 + Vector3(0.0, 1.5, 0.0)
	m.ammo["arm_l"] = 999
	m.ammo["arm_r"] = 999
	Input.action_press("fire_left")
	await wait(0.65)
	await _sample_perf("combat_swarm_fp", 30)
	m.global_position = street_pos
	m.velocity = Vector3.ZERO
	_orient_mech(m, street_yaw)
	for i in fac.allies.size():
		fac.allies[i].global_position = fac._free_near(street_pos + fwd * 7.5 + right * (-5.2 if i == 0 else 5.2))
	raid.aim_override = street_pos + fwd * 18.0 + Vector3(0.0, 1.5, 0.0)
	await frames(3)
	await shot("fps_08_combat_swarm_fp.png")
	Input.action_release("fire_left")

	# ── 阶段 D：第一人称仰视区域巨型首领并三维仰角射击 ──
	await _clear_nearby_bugs(street_pos, 95.0)
	var bosses := get_tree().get_nodes_in_group("boss")
	if not bosses.is_empty():
		var boss_node: Node3D = bosses[0]
		var bp: Vector3 = boss_node.global_position
		var stand: Vector3 = fac._free_near(bp + Vector3(0.0, 0.3, 17.5))
		var to_boss := (bp - stand)
		to_boss.y = 0.0
		if to_boss.length() < 8.0:
			stand = fac._free_near(bp + Vector3(17.5, 0.3, 0.0))
			to_boss = bp - stand
			to_boss.y = 0.0
		var boss_dir := to_boss.normalized()
		var boss_right := Vector3(-boss_dir.z, 0.0, boss_dir.x)
		var boss_yaw := atan2(-to_boss.x, -to_boss.z)
		m.global_position = stand
		m.velocity = Vector3.ZERO
		_orient_mech(m, boss_yaw)
		for i in fac.allies.size():
			fac.allies[i].global_position = fac._free_near(stand - boss_dir * 6.0 + boss_right * (-6.0 if i == 0 else 6.0))
		boss_node.hp = 999999.0
		boss_node.target = m
		raid.aim_override = bp + Vector3(0.0, 4.6, 0.0)
		await wait(0.65)
		m.ammo["arm_l"] = 999
		m.ammo["arm_r"] = 999
		Input.action_press("fire_left")
		await wait(0.30)
		await _sample_perf("boss_upward_fp", 30)
		for i in fac.allies.size():
			fac.allies[i].global_position = fac._free_near(stand - boss_dir * 6.0 + boss_right * (-6.0 if i == 0 else 6.0))
		m.global_position = stand
		_orient_mech(m, boss_yaw)
		raid.aim_override = bp + Vector3(0.0, 4.6, 0.0)
		await frames(3)
		await shot("fps_09_boss_upward_aim.png")
		Input.action_release("fire_left")

	# ── 阶段 E：第一人称高倍光学狙击镜（轨道炮 RG-9 + 狙击步枪 M99） ──
	m.global_position = street_pos
	m.velocity = Vector3.ZERO
	_orient_mech(m, street_yaw)
	await _clear_nearby_bugs(street_pos, 95.0)
	m.equip_module_in_raid("arm_l", "arm_rail")
	m.equip_module_in_raid("arm_r", "arm_sniper")
	m.ammo["arm_l"] = 99
	m.ammo["arm_r"] = 99
	for i in 5:
		var fb = raid.spawn_bug(["spitter", "beetle", "ironjaw"][i % 3], fac._free_near(street_pos + fwd * (36.0 + i * 3.5) + right * (-3.5 + i * 1.6)) + Vector3(0, 0.3, 0))
		if fb:
			fb.hp = float(fb.hp) * 30.0
	raid.aim_override = street_pos + fwd * 38.0 + Vector3(0.0, 1.7, 0.0)
	Input.action_press("fire_right")
	await wait(0.75)
	if not check(raid.camera.fov < 34.0, "第一人称狙击开镜 FOV 未收敛: fov=%s" % raid.camera.fov):
		return
	Input.action_press("fire_left")
	await wait(0.10)
	await _sample_perf("sniper_scope_fp", 30)
	await shot("fps_10_sniper_scope_fp.png")
	Input.action_release("fire_left")
	Input.action_release("fire_right")

	# ── 阶段 E2：手机端触控操作闭环（1/3 人称切屏、空屏滑屏转视角、右触控按压开火+拖移压枪、左手开火、开镜切换） ──
	raid.aim_override = null
	var te_on := InputEventScreenTouch.new()
	te_on.index = 9
	te_on.position = Vector2(540, 260)
	te_on.pressed = true
	Input.parse_input_event(te_on)
	var te_off := InputEventScreenTouch.new()
	te_off.index = 9
	te_off.position = Vector2(540, 260)
	te_off.pressed = false
	Input.parse_input_event(te_off)
	await frames(2)
	if not check(hud._touch_revealed and hud.touch_layer.visible and not raid.should_capture_mouse(), "触屏事件后未显现触控层或仍捕获鼠标"):
		return
	raid.set_view_mode(0)
	await frames(3)
	if not check(not hud.joy_right.fp_mode and not hud.joy_fire.visible, "第三人称下触控面板模式未同步"):
		return
	await shot("fps_14_mobile_touch_tp.png")

	hud.touch_view_btn._trigger()
	await frames(3)
	if not check(raid.is_first_person() and hud.joy_right.fp_mode and hud.joy_fire.visible, "触控视角钮切换第一人称或按钮显隐未生效"):
		return

	var yaw_before: float = raid.fp_yaw
	var pitch_before: float = raid.fp_pitch
	var lk_dn := InputEventScreenTouch.new()
	lk_dn.index = 3
	lk_dn.position = Vector2(640, 320)
	lk_dn.pressed = true
	Input.parse_input_event(lk_dn)
	var lk_mv := InputEventScreenDrag.new()
	lk_mv.index = 3
	lk_mv.position = Vector2(780, 260)
	lk_mv.relative = Vector2(140, -60)
	Input.parse_input_event(lk_mv)
	var lk_up := InputEventScreenTouch.new()
	lk_up.index = 3
	lk_up.position = Vector2(780, 260)
	lk_up.pressed = false
	Input.parse_input_event(lk_up)
	await frames(2)
	if not check(absf(wrapf(raid.fp_yaw - yaw_before, -PI, PI)) > 0.08 and absf(raid.fp_pitch - pitch_before) > 0.03,
		"第一人称触屏滑屏未转动视角: dyaw=%s dpitch=%s" % [raid.fp_yaw - yaw_before, raid.fp_pitch - pitch_before]):
		return

	hud.touch_aim_btn._trigger()
	await frames(2)
	if not check(hud.is_touch_aiming() and m.is_aiming, "触控开镜/瞄准按钮未生效"):
		return

	var jr_center: Vector2 = get_viewport().get_screen_transform() * hud.joy_right.get_global_rect().get_center()
	var jr_dn := InputEventScreenTouch.new()
	jr_dn.index = 4
	jr_dn.position = jr_center
	jr_dn.pressed = true
	Input.parse_input_event(jr_dn)
	var jr_mv := InputEventScreenDrag.new()
	jr_mv.index = 4
	jr_mv.position = jr_center + Vector2(-40, 18)
	jr_mv.relative = Vector2(-40, 18)
	Input.parse_input_event(jr_mv)
	await frames(2)
	if not check(hud.is_touch_firing() and hud.joy_right.is_firing(), "第一人称右摇杆按住未触发开火"):
		return
	await shot("fps_15_mobile_touch_fp.png")
	var jr_up := InputEventScreenTouch.new()
	jr_up.index = 4
	jr_up.position = jr_center + Vector2(-40, 18)
	jr_up.pressed = false
	Input.parse_input_event(jr_up)

	var jf_center: Vector2 = get_viewport().get_screen_transform() * hud.joy_fire.get_global_rect().get_center()
	var jf_dn := InputEventScreenTouch.new()
	jf_dn.index = 5
	jf_dn.position = jf_center
	jf_dn.pressed = true
	Input.parse_input_event(jf_dn)
	await frames(2)
	if not check(hud.joy_fire.is_held() and hud.is_touch_firing(), "第一人称左手开火辅钮未生效"):
		return
		var jf_up := InputEventScreenTouch.new()
		jf_up.index = 5
		jf_up.position = jf_center
		jf_up.pressed = false
		Input.parse_input_event(jf_up)

		# 验证左方向摇杆（多指并发 + 拖出边界释放 + 触摸/鼠标混合事件）绝不卡死
		var jl_center: Vector2 = get_viewport().get_screen_transform() * hud.joy_left.get_global_rect().get_center()
		var jl_dn := InputEventScreenTouch.new()
		jl_dn.index = 0
		jl_dn.position = jl_center
		jl_dn.pressed = true
		Input.parse_input_event(jl_dn)
		var jl_mv := InputEventScreenDrag.new()
		jl_mv.index = 0
		jl_mv.position = jl_center + Vector2(95, -80)
		jl_mv.relative = Vector2(95, -80)
		Input.parse_input_event(jl_mv)
		await frames(2)
		if not check(hud.joy_left.is_active() and m.joy_move.length() > 0.5, "左摇杆拖动后未激活移动向量"):
			return
		# 并发按下并释放另一根手指后，再在远端释放左摇杆手指，验证立即归零不卡死
		var jl_up := InputEventScreenTouch.new()
		jl_up.index = 0
		jl_up.position = jl_center + Vector2(360, -240)
		jl_up.pressed = false
		Input.parse_input_event(jl_up)
		await frames(2)
		if not check(not hud.joy_left.is_active() and hud.joy_left.value == Vector2.ZERO and m.joy_move == Vector2.ZERO,
			"左摇杆释放后仍处于卡住状态: active=%s val=%s move=%s" % [hud.joy_left.is_active(), hud.joy_left.value, m.joy_move]):
			return

		hud.clear_touch_aim()
	hud._touch_revealed = false
	hud._update_cursor()
	await frames(2)

	# ── 阶段 F：峡谷战区（canyon_noon 晴空正午）360 度东南西北环视 + 仰望天顶太阳光晕 ──
	Factions.test_ally_squad = null
	main.show_hub()
	await wait(0.45)
	GameData.map_id = "canyon"
	var raid2 = await deploy({
		"core": "core_std",
		"legs": "legs_quad",
		"arm_l": "arm_mg",
		"arm_r": "arm_laser",
		"back": "back_shield",
		"gen": "gen_crystal",
	})
	if not check(raid2 != null and raid2.mech != null, "峡谷出击失败"):
		return
	Story.set_process(false)
	get_tree().paused = false
	var m2 = raid2.mech
	m2.shield_time = 99999.0
	m2.max_hp = 1e7
	m2.hp = 1e7
	raid2.set_view_mode(1)

	var vantage := _find_open_vantage(raid2)
	m2.global_position = vantage
	m2.velocity = Vector3.ZERO
	await _clear_nearby_bugs(vantage, 85.0)
	raid2.aim_override = null

	# 朝北 (yaw = 0, pitch = +8°)
	_orient_mech(m2, 0.0)
	raid2.fp_yaw = 0.0
	raid2.fp_pitch = deg_to_rad(8.0)
	await wait(0.6)
	await _sample_perf("canyon_sky_north", 30)
	await shot("fps_03_skybox_compass_north.png")

	# 朝东 (yaw = -90°, pitch = +8°)
	_orient_mech(m2, -PI * 0.5)
	raid2.fp_yaw = -PI * 0.5
	raid2.fp_pitch = deg_to_rad(8.0)
	await wait(0.5)
	await shot("fps_04_skybox_compass_east.png")

	# 朝南 (yaw = PI, pitch = +8° —— 验证 ±PI 经度跳变处零接缝)
	_orient_mech(m2, PI)
	raid2.fp_yaw = PI
	raid2.fp_pitch = deg_to_rad(8.0)
	await wait(0.5)
	await shot("fps_05_skybox_compass_south.png")

	# 朝西 (yaw = +90°, pitch = +8°)
	_orient_mech(m2, PI * 0.5)
	raid2.fp_yaw = PI * 0.5
	raid2.fp_pitch = deg_to_rad(8.0)
	await wait(0.5)
	await shot("fps_06_skybox_compass_west.png")

	# 抬头仰望天顶与太阳日冕 (对准 DirectionalLight3D 太阳方位与仰角)
	var sun_dir: Vector3 = raid2._sun_light.global_transform.basis.z.normalized() if raid2._sun_light != null else Vector3(0.6, 0.6, 0.5).normalized()
	var sun_yaw := atan2(-sun_dir.x, -sun_dir.z)
	var sun_pitch := clampf(asin(clampf(sun_dir.y, -1.0, 1.0)) + deg_to_rad(4.0), deg_to_rad(28.0), deg_to_rad(56.0))
	_orient_mech(m2, sun_yaw)
	raid2.fp_yaw = sun_yaw
	raid2.fp_pitch = sun_pitch
	await wait(0.45)
	await shot("fps_07_skybox_zenith_sun.png")

	# ── 阶段 G：荒原沙暴战区（dustfield：sandstorm 动态沙暴天空盒 + 全向沙尘粒子） ──
	main.show_hub()
	await wait(0.45)
	GameData.map_id = "dustfield"
	var raid3 = await deploy({
		"core": "core_std",
		"legs": "legs_biped",
		"arm_l": "arm_gatling",
		"arm_r": "arm_ac30",
		"back": "back_missile",
		"gen": "gen_reactor",
	})
	if not check(raid3 != null and raid3.mech != null, "沙海出击失败"):
		return
	Story.set_process(false)
	get_tree().paused = false
	var m3 = raid3.mech
	m3.shield_time = 99999.0
	m3.max_hp = 1e7
	m3.hp = 1e7
	raid3.set_view_mode(1)
	var sand_pos: Vector3 = raid3.factions._free_near(Vector3(12.0, 0.3, 18.0))
	m3.global_position = sand_pos
	m3.velocity = Vector3.ZERO
	await _clear_nearby_bugs(sand_pos, 80.0)
	_orient_mech(m3, deg_to_rad(115.0))
	raid3.fp_yaw = deg_to_rad(115.0)
	raid3.fp_pitch = deg_to_rad(6.0)
	await wait(0.65)
	await _sample_perf("sandstorm_skybox", 30)
	await shot("fps_11_sandstorm_skybox.png")

	# ── 阶段 H：深渊巨口战区（abyss_maw 地下封闭生物发光岩穹天幕） ──
	main.show_hub()
	await wait(0.45)
	GameData.map_id = "abyss_maw"
	var raid4 = await deploy({
		"core": "core_std",
		"legs": "legs_biped",
		"arm_l": "arm_flamer",
		"arm_r": "arm_shotgun",
		"back": "back_shield",
		"gen": "gen_crystal",
	})
	if not check(raid4 != null and raid4.mech != null, "深渊出击失败"):
		return
	Story.set_process(false)
	get_tree().paused = false
	var m4 = raid4.mech
	m4.shield_time = 99999.0
	m4.max_hp = 1e7
	m4.hp = 1e7
	raid4.set_view_mode(1)
	var abyss_pos: Vector3 = raid4.factions._free_near(Vector3(0.0, 0.3, 15.0))
	for bx in get_tree().get_nodes_in_group("lootboxes"):
		if bx.global_position.distance_to(abyss_pos) < 8.0:
			bx.queue_free()
	m4.global_position = abyss_pos
	m4.velocity = Vector3.ZERO
	await _clear_nearby_bugs(abyss_pos, 80.0)
	_orient_mech(m4, deg_to_rad(40.0))
	raid4.fp_yaw = deg_to_rad(40.0)
	raid4.fp_pitch = deg_to_rad(28.0)
	await wait(1.55)
	await _sample_perf("abyss_cavern_skybox", 30)
	await shot("fps_12_abyss_cavern_skybox.png")

	GameData.view_mode = 0
	Factions.rovers_enabled = true
	WorldLink.force_open = false

