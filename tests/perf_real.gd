extends "res://tests/lib/test_base.gd"
## 全真桌面实机性能基准：按真实显示器最大化分辨率运行（非 720p、非无头），覆盖主菜单 / 机库 / 战斗实战。
## 同步统计 SubViewport + 主视口 GPU 耗时、渲染 CPU、帧均 FPS / p50 / p95 / 1% Low、VSync 开/关与物理渲染像素尺寸。
## 用法：godot --path . -- --perf_real [--snap=before] [--outdir=...]

const START := "menu"
const TIMEOUT := 300.0


func _arg(name: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.split("=", true, 1)[1]
	return def


func _snap(tag: String, out_dir: String, name: String) -> void:
	if tag == "":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("%s/perf_%s_%s.png" % [out_dir, tag, name])


func _sample(label: String, vp: Viewport, root_vp: Viewport, n_frames := 120, warmup := 20) -> Dictionary:
	var vp_rid := vp.get_viewport_rid()
	var root_rid := root_vp.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	if root_rid != vp_rid:
		RenderingServer.viewport_set_measure_render_time(root_rid, true)
	await frames(warmup)
	var fts: Array[float] = []
	var gpu_sum := 0.0
	var root_gpu_sum := 0.0
	var rcpu_sum := 0.0
	var dc_max := 0
	var obj_max := 0
	var prim_max := 0
	var last := Time.get_ticks_usec()
	for _i in n_frames:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		fts.append((now - last) / 1000.0)
		last = now
		gpu_sum += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
		if root_rid != vp_rid:
			root_gpu_sum += RenderingServer.viewport_get_measured_render_time_gpu(root_rid)
		rcpu_sum += RenderingServer.viewport_get_measured_render_time_cpu(vp_rid) + RenderingServer.get_frame_setup_time_cpu()
		dc_max = maxi(dc_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		obj_max = maxi(obj_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		prim_max = maxi(prim_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	var ft_sum := 0.0
	for v in fts:
		ft_sum += v
	fts.sort()
	var avg_ms := ft_sum / float(fts.size())
	var p50_ms := fts[fts.size() / 2]
	var p95_ms := fts[int(fts.size() * 0.95)]
	var p99_ms := fts[mini(fts.size() - 1, int(fts.size() * 0.99))]
	var avg_fps := 1000.0 / maxf(avg_ms, 0.01)
	var low1_fps := 1000.0 / maxf(p99_ms, 0.01)
	var rt_w := int(round(vp.size.x * vp.scaling_3d_scale))
	var rt_h := int(round(vp.size.y * vp.scaling_3d_scale))
	var gpu_ms := (gpu_sum + root_gpu_sum) / float(n_frames)
	var rcpu_ms := rcpu_sum / float(n_frames)
	print("[perf_real] %-26s rt=%4dx%-4d scale=%.2f msaa=%d | fps=%5.1f low1=%5.1f eng=%3d | ft=%5.2f p50=%5.2f p95=%5.2f | gpu=%5.2f rcpu=%4.2f | dc=%4d objs=%4d prims=%d" % [
		label, rt_w, rt_h, vp.scaling_3d_scale, int(vp.msaa_3d),
		avg_fps, low1_fps, int(Engine.get_frames_per_second()),
		avg_ms, p50_ms, p95_ms, gpu_ms, rcpu_ms, dc_max, obj_max, prim_max])
	return {
		"label": label, "rt": [rt_w, rt_h], "scale": vp.scaling_3d_scale, "msaa": int(vp.msaa_3d),
		"fps": avg_fps, "low1_fps": low1_fps, "avg_ms": avg_ms, "p50_ms": p50_ms, "p95_ms": p95_ms,
		"gpu_ms": gpu_ms, "rcpu_ms": rcpu_ms, "dc": dc_max, "objs": obj_max, "prims": prim_max,
	}


func run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if not headless():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	await frames(20)
	var snap_tag := _arg("snap", "")
	var out_dir := _arg("outdir", ProjectSettings.globalize_path(REVIEW_DIR))
	var root_vp := get_viewport()
	print("[perf_real] env: screen=%s win=%s renderer=%s" % [
		str(DisplayServer.screen_get_size()), str(DisplayServer.window_get_size()), RenderingServer.get_current_rendering_method()])

	# 1. 主菜单 (Q1, 原生 4K)
	GameData.quality = 1
	GameData.apply_quality(root_vp)
	var m = main.menu
	var m_sv: SubViewport = m._sv
	GameData.apply_quality(m_sv, false)
	await _sample("Menu Q1", m_sv, root_vp, 120, 25)
	await _snap(snap_tag, out_dir, "menu")

	# 2. 机库 BAY 03 (Q1, 原生 4K)
	main.show_hub()
	await wait(1.5)
	var h = main.hub
	var h_sv: SubViewport = h.hangar_vp
	GameData.apply_quality(h_sv, false)
	await _sample("Hub Q1", h_sv, root_vp, 120, 25)
	await _snap(snap_tag, out_dir, "hub")

	# 3. 战斗实战（含队友 + 流浪者 + 移动 + 持续开火）
	var F = load("res://scripts/factions/factions.gd") if ResourceLoader.exists("res://scripts/factions/factions.gd") else null
	if F:
		F.rovers_enabled = true
		F.test_ally_squad = [{"pilot": "rei", "tier": 2}, {"pilot": "kurumi", "tier": 2}]
	GameData.map_id = _arg("map", "greyport")
	var raid = await deploy({"core": "core_std", "legs": "legs_biped", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_missile", "gen": "gen_reactor"})
	if not check(raid != null, "出击失败"):
		return
	var mech = raid.mech
	mech.shield_time = 99999; mech.hp = 1e9; mech.max_hp = 1e9; mech.energy = 1e9; mech.max_energy = 1e9
	if F and raid.factions:
		var p0: Vector3 = mech.global_position
		raid.factions.spawn_squad(3, [p0 + Vector3(50, 0.3, -20), p0 + Vector3(-80, 0.3, -20)])
	await wait(1.5)
	var r_we: WorldEnvironment = null
	for c in raid.get_children():
		if c is WorldEnvironment:
			r_we = c
			break
	var env: Environment = r_we.environment if r_we else null
	var sun: DirectionalLight3D = raid._sun_light

	# Combat Q1 active movement + firing
	GameData.quality = 1
	GameData.apply_quality(root_vp)
	if env: GameData.apply_env_quality(env, sun)
	Input.action_press("move_right")
	Input.action_press("fire_left")
	raid.aim_override = mech.global_position + Vector3(6, 1.8, -6)
	await _sample("Combat Q1 move+fire", root_vp, root_vp, 150, 20)
	await _snap(snap_tag, out_dir, "combat_q1")

	# Combat Q1 VSync=ON (实机默认)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	await _sample("Combat Q1 VSync=ON", root_vp, root_vp, 120, 15)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	# Combat Q1 Native 4K (100% 原生，验证纯着色器/阴影优化收益)
	var prev_rs := GameData.render_scale_mode
	GameData.render_scale_mode = 1
	GameData.apply_quality(root_vp)
	await _sample("Combat Q1 Native 4K", root_vp, root_vp, 120, 15)
	GameData.render_scale_mode = prev_rs

	# Combat Q2 move+fire
	GameData.quality = 2
	GameData.apply_quality(root_vp)
	if env: GameData.apply_env_quality(env, sun)
	await _sample("Combat Q2 move+fire", root_vp, root_vp, 120, 15)

	# Combat Q0 move+fire
	GameData.quality = 0
	GameData.apply_quality(root_vp)
	if env: GameData.apply_env_quality(env, sun)
	await _sample("Combat Q0 move+fire", root_vp, root_vp, 120, 15)

	Input.action_release("fire_left")
	Input.action_release("move_right")
	if F:
		F.test_ally_squad = null
