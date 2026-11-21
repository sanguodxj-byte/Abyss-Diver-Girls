extends "res://tests/lib/test_base.gd"
const START := "none"
const TIMEOUT := 240.0
const Monitor = preload("res://tests/lib/frame_monitor.gd")
var shots := 0
var reloads := 0

func run() -> void:
	if not check(not headless(), "需要真实全屏渲染"): return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	GameData.quality = 1
	GameData.render_scale_mode = 0
	GameData.apply_quality()
	GameData.cargo = []
	var r = await deploy()
	if not check(r != null, "出击失败"): return
	var m = r.mech
	m.shield_time = 99999
	m.energy = 99999
	m.max_energy = 99999
	m.fired.connect(func(_slot): shots += 1)
	m.reloaded.connect(func(_slot): reloads += 1)
	await wait_real(5.0)
	var monitor := Monitor.new()
	monitor.begin(get_viewport(), "fullscreen_combat")
	var started := Time.get_ticks_msec()
	Input.action_press("fire_left")
	while Time.get_ticks_msec() - started < 45000:
		var t := float(Time.get_ticks_msec() - started) / 1000.0
		var dir := Vector3(cos(t * 0.6), 0, sin(t * 0.6))
		for pair in [["move_right", dir.x > 0.2], ["move_left", dir.x < -0.2], ["move_down", dir.z > 0.2], ["move_up", dir.z < -0.2]]:
			if pair[1]: Input.action_press(pair[0])
			else: Input.action_release(pair[0])
		r.aim_override = m.global_position + dir * 45.0 + Vector3(0, 1.8, 0)
		if int(t) % 12 >= 6: Input.action_press("fire_right")
		else: Input.action_release("fire_right")
		await get_tree().process_frame
		monitor.frame()
	for action in ["fire_left", "fire_right", "move_right", "move_left", "move_up", "move_down"]: Input.action_release(action)
	var result := {"window": str(DisplayServer.window_get_size()), "scale": get_viewport().scaling_3d_scale,
		"quality": GameData.quality, "shots": shots, "reloads": reloads, "finite_rounds_timed_reload": true,
		"histogram_0_1_ms": Array(monitor.histogram), "last_frames": Array(monitor.samples), "slow": monitor.slow}
	var file := FileAccess.open("res://review/fullscreen_combat.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	check(shots > 100 and reloads > 2, "持续射击和真实换弹覆盖不足")
	log_line("shots=%d reloads=%d window=%s scale=%.3f" % [shots, reloads, result.window, result.scale])
