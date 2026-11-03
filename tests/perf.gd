extends "res://tests/lib/test_base.gd"
## 性能基准：出击后分三档（0 / 24 / 满员 只虫子）持续开火，统计每帧耗时。
## godot --headless --path . -- --perf          只测 CPU（脚本 / 物理 / 主循环）
## godot --path . -- --perf                     额外统计绘制调用、可见物体、图元数
## 结果打印为 [perf] 行，并写入 review/perf.json

const TIMEOUT := 900.0
const SAMPLE_FRAMES := 240
const TIERS := [0, 24, 60]
const KINDS := ["ling", "ling", "spitter", "beetle", "ling", "bomber"]


func run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await wait(0.3)
	var raid = await deploy({"core": "core_std", "legs": "legs_biped", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_missile", "gen": "gen_reactor"})
	if not check(raid != null, "出击失败"):
		return
	var m = raid.mech
	m.shield_time = 99999
	m.hp = 1e9
	m.max_hp = 1e9
	await frames(30)
	var report := {}
	for n in TIERS:
		for b in get_tree().get_nodes_in_group("bugs"):
			b.queue_free()
		await frames(5)
		var rng := RandomNumberGenerator.new()
		rng.seed = 1234
		for i in n:
			var a := rng.randf() * TAU
			var d := rng.randf_range(9.0, 22.0)
			raid.spawn_bug(KINDS[i % KINDS.size()], m.global_position + Vector3(cos(a) * d, 0.5, sin(a) * d))
		raid.aim_override = m.global_position + Vector3(6, 1.8, -6)
		Input.action_press("fire_left")
		Input.action_press("fire_right")
		await frames(30)
		var r := await _sample()
		Input.action_release("fire_left")
		Input.action_release("fire_right")
		r["bugs"] = get_tree().get_nodes_in_group("bugs").size()
		report["bugs_%d" % n] = r
		print("[perf] tier=%d bugs=%d frame_avg=%.2fms p95=%.2fms max=%.2fms process=%.2fms physics=%.2fms nodes=%d draw=%d objects=%d prims=%d" % [
			n, r.bugs, r.frame_avg, r.frame_p95, r.frame_max, r.process_avg, r.physics_avg, r.nodes, r.draw_calls, r.objects, r.primitives])
	var f := FileAccess.open(REVIEW_DIR.path_join("perf%s.json" % ("_headless" if headless() else "")), FileAccess.WRITE)
	if f == null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_DIR))
		f = FileAccess.open(REVIEW_DIR.path_join("perf%s.json" % ("_headless" if headless() else "")), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()


func _sample() -> Dictionary:
	var ft: Array = []
	var pr := 0.0
	var ph := 0.0
	var dc := 0
	var ob := 0
	var pm := 0
	var last := Time.get_ticks_usec()
	for i in SAMPLE_FRAMES:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		ft.append((now - last) / 1000.0)
		last = now
		pr += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		ph += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		dc = maxi(dc, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		ob = maxi(ob, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		pm = maxi(pm, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	ft.sort()
	var s := 0.0
	for v in ft:
		s += v
	return {
		"frame_avg": s / ft.size(), "frame_p95": ft[int(ft.size() * 0.95)], "frame_max": ft[-1],
		"process_avg": pr / SAMPLE_FRAMES, "physics_avg": ph / SAMPLE_FRAMES,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"draw_calls": dc, "objects": ob, "primitives": pm,
	}
