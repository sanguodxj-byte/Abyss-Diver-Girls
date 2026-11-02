extends "res://tests/lib/test_base.gd"
## 步态与冲刺截图：godot --path . -- --walk → review\walk_<帧>.png / walk_dash_<帧>.png

func gwait(t: float) -> void:
	var g := 0.0
	while g < t:
		await get_tree().process_frame
		g += get_process_delta_time()

func run() -> void:
	await wait(0.3)
	var raid = await deploy()
	if not check(raid != null, "出击失败"):
		return
	for b in get_tree().get_nodes_in_group("bugs"): b.queue_free()
	var m = raid.mech
	m.shield_time = 0.0
	raid.cam_zoom = 0.4
	raid.aim_override = m.global_position + Vector3(0, 1.8, -12)
	await get_tree().create_timer(1.0).timeout
	Input.action_press("move_right")
	await get_tree().create_timer(1.5).timeout
	Engine.time_scale = 0.08
	var cam := Camera3D.new()
	raid.add_child(cam)
	cam.fov = 40
	cam.current = true
	raid.hud.visible = false
	for i in 8:
		await gwait(0.075)
		raid.aim_override = m.global_position + Vector3(0, 1.8, -12)
		cam.global_position = m.global_position + Vector3(0, 2.0, 8.5)
		cam.look_at(m.global_position + Vector3(0, 1.4, 0), Vector3.UP)
		await shot("walk_%d.png" % i)
	cam.current = false
	raid.hud.visible = true
	print("[walk] speed=", Vector2(m.velocity.x, m.velocity.z).length(), " phase=", m.gait_phase)
	Engine.time_scale = 1.0
	Input.action_release("move_right")
	await get_tree().create_timer(1.2).timeout
	Input.action_press("move_up")
	await get_tree().create_timer(0.3).timeout
	Engine.time_scale = 0.08
	cam.current = true
	raid.hud.visible = false
	m.try_dash(Vector3(0, 0, -1))
	for i in 6:
		cam.global_position = m.global_position + Vector3(9, 2.5, 0)
		cam.look_at(m.global_position + Vector3(0, 1.6, 0), Vector3.UP)
		await gwait(0.11)
		await shot("walk_dash_%d.png" % i)
		print("[walk] dash y=", m.visual.position.y, " v=", Vector2(m.velocity.x, m.velocity.z).length())
	Engine.time_scale = 1.0
	Input.action_release("move_up")
