extends "res://tests/lib/test_base.gd"
## 空投与开火特效截图：godot --path . -- --fx → review\fx_drop_*.png / fx_after_drop.png / fx_fire1.png / fx_fire2.png

func run() -> void:
	await wait(0.3)
	main.hub.deploy_requested.emit()
	await get_tree().process_frame
	var raid = main.raid
	if not check(raid != null, "出击失败"):
		return
	Engine.time_scale = 0.12
	var shots := [[0.7, "drop_fall"], [1.25, "drop_retro"], [1.68, "drop_impact"], [2.2, "drop_dust"], [3.0, "drop_rise"]]
	var t0 := Time.get_ticks_msec()
	var gt := 0.0
	for s in shots:
		while gt < s[0]:
			await get_tree().process_frame
			gt += get_process_delta_time()
		await shot("fx_%s.png" % s[1])
		log_line("%s y=%.2f gt=%.2f" % [s[1], raid.mech.global_position.y, gt])
	Engine.time_scale = 1.0
	while raid.mech.input_locked:
		await wait(0.2)
	await wait(6.0)
	var n := 0
	var em := 0
	for c in raid.find_children("*", "CPUParticles3D", true, false):
		n += 1
		if c.emitting: em += 1
	log_line("particles after 6s: %d emitting=%d" % [n, em])
	await shot("fx_after_drop.png")
	for b in get_tree().get_nodes_in_group("bugs"): b.queue_free()
	raid.mech.shield_time = 0.0
	var m = raid.mech
	raid.aim_override = m.global_position + Vector3(9, 1.8, -6)
	await wait(1.5)
	raid.aim_override = m.global_position + Vector3(-8, 1.8, -7)
	Input.action_press("fire_left")
	Input.action_press("fire_right")
	Engine.time_scale = 0.15
	await frames(3)
	await shot("fx_fire1.png")
	await frames(3)
	await shot("fx_fire2.png")
	Input.action_release("fire_left")
	Input.action_release("fire_right")
	Engine.time_scale = 1.0
