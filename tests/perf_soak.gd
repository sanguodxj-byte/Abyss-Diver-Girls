extends "res://tests/lib/test_base.gd"
## 实际窗口长测；默认六个地表战区各 5 分钟，逐窗落盘、最终返回机库检查旧战区释放。
const TIMEOUT := 3300.0
const Monitor = preload("res://tests/lib/frame_monitor.gd")
const Factions = preload("res://scripts/factions/factions.gd")
const Art = preload("res://scripts/art.gd")
const RB = preload("res://scripts/render_batch.gd")
const MapEvents = preload("res://scripts/map_ext/events.gd")
const Prof = preload("res://scripts/prof.gd")
const LOADOUT := {"core": "core_std", "legs": "legs_biped", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_missile", "gen": "gen_reactor"}
var monitor = Monitor.new()
var report := {"maps": [], "hub": [], "complete": false}
var output := ""
var stream: FileAccess
var shots := 0
var last_window_shots := 0


func arg(name: String, fallback: String) -> String:
	for value in OS.get_cmdline_user_args():
		if value.begins_with("--" + name + "="): return value.get_slice("=", 1)
	return fallback


func run() -> void:
	if not check(not headless(), "长测必须使用真实渲染"): return
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var dimensions := arg("sample-size", "1920x1080").split("x")
	var requested := Vector2i(int(dimensions[0]), int(dimensions[1]))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_position(Vector2i(60, 60))
	get_window().unresizable = true
	DisplayServer.window_set_size(requested)
	await frames(3)
	GameData.quality = 1
	GameData.apply_quality(get_viewport())
	Factions.test_ally_squad = [{"pilot": "rei", "tier": 2}, {"pilot": "kurumi", "tier": 2}]
	output = "res://review/soak_%s.json" % arg("tag", "latest").validate_filename()
	stream = FileAccess.open(output.trim_suffix(".json") + ".jsonl", FileAccess.WRITE)
	if not check(stream != null, "无法打开长测记录"): return
	report.config = {"window": [requested.x, requested.y], "quality": 1, "finite_rounds_timed_reload": true,
		"profiling": arg("profile", "0") == "1",
		"gpu": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"render_px": [get_viewport().size.x, get_viewport().size.y], "scale_3d": get_viewport().scaling_3d_scale,
		"msaa": int(get_viewport().msaa_3d), "vsync": int(DisplayServer.window_get_vsync_mode()),
		"pipeline_order": ["canvas", "mesh", "surface", "draw", "specialization"]}
	var duration := float(arg("duration", "300"))
	var maps := arg("maps", "greyport,ironbelt,dustfield,redlake,canyon,bayport").split(",")
	for id in maps:
		GameData.map_id = id
		GameData.cargo = []
		seed(20261120)
		main.RaidScript.force_async_load = true
		var load_start := Time.get_ticks_msec()
		var raid = await deploy(LOADOUT)
		main.RaidScript.force_async_load = false
		if not check(raid != null, "出击失败：" + id): return
		# Windows 的窗口样式变更/加载界面可能异步调整客户区；采样前固定并确认。
		DisplayServer.window_set_size(requested)
		await frames(3)
		if not check(DisplayServer.window_get_size() == requested,
			"无法固定采样窗口：期望 %s 实际 %s" % [requested, DisplayServer.window_get_size()]): return
		var rid: int = raid.get_instance_id()
		var m = raid.mech
		shots = 0
		last_window_shots = 0
		m.fired.connect(func(_slot): shots += 1)
		m.hp = 1e9; m.max_hp = 1e9; m.energy = 1e9; m.max_energy = 1e9; m.shield_time = 99999
		var home: Vector3 = m.global_position
		var route: Array = [home + Vector3(50, 0.3, -20), home + Vector3(-80, 0.3, -20)]
		raid.factions._enqueue_squad(3, route)
		var map_report := {"id": id, "load_ms": Time.get_ticks_msec() - load_start, "start": state(raid)}
		monitor.begin(get_viewport(), id)
		Prof.on = bool(report.config.profiling)
		Prof.take()
		var started := Time.get_ticks_msec()
		var steer_at := 0
		Input.action_press("fire_left")
		while Time.get_ticks_msec() - started < int(duration * 1000):
			if not check(is_instance_id_valid(rid) and not raid.ended and main.raid == raid, "长测中战区意外结束或切换：" + id): return
			var now := Time.get_ticks_msec()
			if now >= steer_at:
				steer_at = now + 500
				Input.action_press("fire_left")
				var dir: Vector3 = [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD][int((now - started) / 12000) % 4]
				if m.global_position.distance_to(home) > 28 or not raid.in_bounds(m.global_position + dir * 12.0, 18.0):
					dir = (home - m.global_position).normalized()
				for gate: Dictionary in raid.world_link.gates.values():
					if m.global_position.distance_to(gate.center) < 28.0:
						dir = (m.global_position - gate.center).normalized()
				for pair in [["move_right", dir.x > 0.2], ["move_left", dir.x < -0.2], ["move_down", dir.z > 0.2], ["move_up", dir.z < -0.2]]:
					if pair[1]: Input.action_press(pair[0])
					else: Input.action_release(pair[0])
				var enemy = raid.nearest_bug(m.global_position, 45.0, false)
				raid.aim_override = enemy.global_position + Vector3(0, 1.8, 0) if enemy != null else m.global_position + dir * 18 + Vector3(0, 1.8, 0)
			await get_tree().process_frame
			if not check(is_instance_id_valid(rid) and not raid.ended and main.raid == raid,
				"长测中战区意外结束或切换：" + id): return
			if not check(DisplayServer.window_get_size() == requested,
				"窗口尺寸变化：期望 %s 实际 %s" % [requested, DisplayServer.window_get_size()]): return
			if monitor.frame(): record_window(raid)
		for action in ["fire_left", "move_right", "move_left", "move_down", "move_up"]: Input.action_release(action)
		record_window(raid)
		Prof.on = false
		map_report.windows = monitor.windows.duplicate(true)
		map_report.histogram_0_1_ms = Array(monitor.histogram)
		map_report.end = state(raid)
		report.maps.append(map_report)
		if not check(shots > duration, "长测持续开火未达最低覆盖：" + id): return
		if duration >= 290.0:
			if not check(int(map_report.end.events) == 3 and int(map_report.end.event_sites) == 3,
				"长测没有覆盖三轮动态事件：" + id): return
		raid._finish(true, "soak verification")
		await frames(3)
		main.show_hub()
		if not check(await until(func(): return not is_instance_id_valid(rid), 8.0), "旧战区没有释放：" + id): return
		await wait_real(3.0)
		report.hub.append({"after": id, "memory": Monitor.memory(), "caches": caches()})
		save_report()
		log_line("%s complete; hub memory=%s" % [id, report.hub[-1]])
	Factions.test_ally_squad = null
	report.complete = true
	save_report()
	stream.close()


func state(raid) -> Dictionary:
	var event_count := -1
	var event_sites := -1
	for child in raid.get_children():
		if child is MapEvents:
			event_count = child._count
			event_sites = child._used_sites.size()
	var particles := {"active": 0, "idle": 0}
	for child in raid.fx.get_children():
		if child is CPUParticles3D:
			particles["active" if child.emitting else "idle"] += 1
	return {"bugs": get_tree().get_nodes_in_group("bugs").size(), "npcs": get_tree().get_nodes_in_group("npc_mechs").size(),
		"fx": raid.fx.get_child_count(), "loot": get_tree().get_nodes_in_group("lootboxes").size(),
		"corpses": raid._corpses.size(), "pending_spawns": raid.factions._spawn_jobs.size(),
		"caches": caches(), "position": str(raid.mech.global_position), "particles": particles,
		"events": event_count, "event_sites": event_sites, "shots": shots,
		"game_s": raid.time, "kills": raid.kills, "ammo": raid.mech.ammo.duplicate(),
		"energy": raid.mech.energy, "parts": raid.mech.parts.duplicate(), "input_locked": raid.mech.input_locked,
		"fire_pressed": Input.is_action_pressed("fire_left"), "hud_busy": raid.hud.is_touch_busy(),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))}


func caches() -> Dictionary:
	return {"meshes": Art._mesh_cache.size(), "materials": Art._mat_cache.size(), "burst_pools": Art._burst_pool.size(),
		"burst_resources": Art._burst_res.size(), "raw_surfaces": RB._raw_surfs.size(), "tinted": RB._tinted.size()}


func record_window(raid) -> void:
	var record: Dictionary = monitor.flush(state(raid))
	if record.is_empty(): return
	record.shots_in_window = shots - last_window_shots
	last_window_shots = shots
	stream.store_line(JSON.stringify(record))
	stream.flush()
	if record.avg_ms * record.frames > 9000:
		check(int(record.shots_in_window) >= 20, "长测开火被中断：%s %.0fs" % [raid.map_id, record.at_s])
	log_line("%s %.0fs fps=%.1f p99=%.2f max=%.2f >45=%d mem=%.0fMB nodes=%d fx=%d" % [raid.map_id, record.at_s,
		1000.0 / record.avg_ms, record.p99_ms, record.max_ms, record.over45, record.memory.static_mb, record.memory.nodes, record.state.fx])


func save_report() -> void:
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
