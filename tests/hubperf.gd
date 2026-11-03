extends "res://tests/lib/test_base.gd"
## 机库帧耗时采样 → [hubperf] 行
func run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await wait(2.0)
	var t0 := Time.get_ticks_usec()
	var n := 180
	for i in n:
		await get_tree().process_frame
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
	log_line("hub_frame_ms=%.2f fps=%.0f" % [ms, 1000.0 / ms])
