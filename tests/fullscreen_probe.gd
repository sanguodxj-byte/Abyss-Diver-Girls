extends "res://tests/lib/test_base.gd"
const START := "menu"
const TIMEOUT := 300.0
var records: Array = []

func _arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="): return a.get_slice("=", 1)
	return fallback

func run() -> void:
	if not check(not headless(), "需要真实渲染"): return
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	GameData.quality = int(_arg("quality", "1"))
	GameData.render_scale_mode = 0
	print("[fullscreen_probe] screen=", DisplayServer.screen_get_size())
	await _sample("menu_window", main.menu._sv, false)
	await _sample("menu_full", main.menu._sv, true)
	main.show_hub()
	await _sample("hub_full", main.hub.hangar_vp, true)
	await _sample("hub_window", main.hub.hangar_vp, false)
	var f := FileAccess.open("res://review/fullscreen_%s.json" % _arg("tag", "latest"), FileAccess.WRITE)
	f.store_string(JSON.stringify(records, "  "))
	f.close()
	if "--check" in OS.get_cmdline_user_args():
		for row in records:
			if row.window[1] > 1440 and not check(row.scale < 0.99, "高分辨率子视口没有启用自动缩放"): return

func _sample(label: String, vp: Viewport, fullscreen: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not fullscreen: DisplayServer.window_set_size(Vector2i(1920, 1080))
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	await wait_real(3.0)
	var values: Array[float] = []
	var gpu := 0.0
	var last := Time.get_ticks_usec()
	for i in 180:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		values.append((now - last) / 1000.0)
		last = now
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid())
	values.sort()
	var total := 0.0
	for v in values: total += v
	var row := {"scene": label, "window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"vp": [vp.size.x, vp.size.y], "scale": vp.scaling_3d_scale, "fps": 1000.0 * values.size() / total,
		"p99_ms": values[int(values.size() * 0.99)], "max_ms": values[-1], "gpu_ms": gpu / values.size()}
	records.append(row)
	print("[fullscreen_probe] ", JSON.stringify(row))
