extends "res://tests/lib/test_base.gd"
## 性能剖析：24 只虫子交战时，分别关掉 虫子逻辑 / 粒子 / 机甲开火 / HUD，看每一项占多少帧时间。
## godot --headless --path . -- --perfprof
const TIMEOUT := 900.0
const KINDS := ["ling", "ling", "spitter", "beetle", "ling", "bomber"]

func run() -> void:
	Engine.max_fps = 0
	await wait(0.3)
	var raid = await deploy({"core": "core_std", "legs": "legs_biped", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_missile", "gen": "gen_reactor"})
	var m = raid.mech
	m.shield_time = 99999
	m.hp = 1e9
	m.max_hp = 1e9
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 24:
		var a := rng.randf() * TAU
		var d := rng.randf_range(9.0, 22.0)
		raid.spawn_bug(KINDS[i % KINDS.size()], m.global_position + Vector3(cos(a) * d, 0.5, sin(a) * d))
	raid.aim_override = m.global_position + Vector3(6, 1.8, -6)
	Input.action_press("fire_left")
	Input.action_press("fire_right")
	await frames(60)
	print("[perfprof] full        %.2f ms" % await _avg())
	var bugs := get_tree().get_nodes_in_group("bugs")
	for b in bugs: b.set_physics_process(false)
	print("[perfprof] no-bug-ai   %.2f ms" % await _avg())
	for b in bugs: b.set_physics_process(true)
	# 单只虫子逻辑耗时（手动调用）
	var per := {}
	for b in bugs:
		if not is_instance_valid(b): continue
		b.set_physics_process(false)
	for k in 30:
		for b in bugs:
			if not is_instance_valid(b): continue
			var t0 := Time.get_ticks_usec()
			b._physics_process(1.0 / 60.0)
			var kind: String = str(b.get("kind")) if b.get("kind") != null else b.get_script().resource_path.get_file()
			per[kind] = per.get(kind, 0.0) + (Time.get_ticks_usec() - t0) / 1000.0
		await get_tree().physics_frame
	for k in per: print("[perfprof] bug %s  %.3f ms/frame total" % [k, per[k] / 30.0])
	for b in bugs:
		if is_instance_valid(b): b.set_physics_process(true)
	var parts := 0
	for n in raid.find_children("*", "CPUParticles3D", true, false):
		parts += 1
	print("[perfprof] cpu particles nodes=%d fx children=%d" % [parts, raid.fx.get_child_count()])
	Input.action_release("fire_left")
	Input.action_release("fire_right")
	await frames(60)
	print("[perfprof] not-firing  %.2f ms" % await _avg())
	raid.hud.visible = false
	raid.hud.process_mode = Node.PROCESS_MODE_DISABLED
	print("[perfprof] no-hud      %.2f ms" % await _avg())
	for n in raid.find_children("*", "CPUParticles3D", true, false):
		n.emitting = false
		n.process_mode = Node.PROCESS_MODE_DISABLED
	print("[perfprof] no-particles %.2f ms" % await _avg())
	for b in get_tree().get_nodes_in_group("bugs"): b.queue_free()
	await frames(10)
	print("[perfprof] no-bugs     %.2f ms" % await _avg())
	m.set_physics_process(false)
	print("[perfprof] no-mech     %.2f ms" % await _avg())
	raid.set_process(false)
	print("[perfprof] no-raid     %.2f ms" % await _avg())

func _avg() -> float:
	var last := Time.get_ticks_usec()
	var s := 0.0
	for i in 120:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		s += (now - last) / 1000.0
		last = now
	return s / 120.0
