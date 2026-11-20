extends "res://tests/lib/test_base.gd"
## 二维地图实际渲染：持续平移与静止各 240 帧。
const TIMEOUT := 180.0

func run() -> void:
	if not check(not headless(), "此基准必须使用真实渲染"):
		return
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	main.hub._switch_tab("deploy")
	await frames(30)
	var wm = main.hub.world_map
	wm.center_on("greyport")
	await frames(20)
	var report := {"window": str(DisplayServer.window_get_size()), "map_size": str(wm.size),
		"gpu": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"load_ms": wm.build_ms, "resource_bytes": FileAccess.get_file_as_bytes("res://assets/ui/worldmap/region_2d.res").size()}
	for phase in ["pan", "idle"]:
		var times: Array = []
		var last := Time.get_ticks_usec()
		for i in 240:
			if phase == "pan":
				wm.offset = Vector2(sin(i * 0.02) * 60, cos(i * 0.02) * 40)
				wm.request_render()
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			times.append((now - last) / 1000.0)
			last = now
		var total := 0.0
		for ms in times: total += ms
		times.sort()
		report[phase] = {"avg_ms": total / times.size(), "p95_ms": times[int(times.size() * 0.95)],
			"p99_ms": times[int(times.size() * 0.99)], "no_process": not wm.is_processing()}
		log_line("%s %s" % [phase, report[phase]])
	if not check(bool(report.idle.no_process), "二维地图存在持续脚本更新"):
		return
	var file := FileAccess.open("res://review/worldmap_2d_perf.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
