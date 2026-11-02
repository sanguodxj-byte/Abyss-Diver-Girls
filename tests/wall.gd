extends "res://tests/lib/test_base.gd"
## 墙体挡弹测试：1.2 / 2.5 / 4.0 米高的墙挡在机甲与甲虫之间，持续开火后甲虫应毫发无损；拆掉墙后应受伤。
## godot --headless --path . -- --wall

func run() -> void:
	await wait(0.3)
	var raid = await deploy({"core":"core_std","legs":"legs_biped","arm_l":"arm_mg","arm_r":"arm_shotgun","back":"back_missile","gen":"gen_reactor"})
	if not check(raid != null, "出击失败"):
		return
	var m = raid.mech
	for b in get_tree().get_nodes_in_group("bugs"):
		b.queue_free()
	# queue_free 在帧末才生效；等一帧再生成，否则地图上的虫子仍占着 MAX_BUGS 名额，spawn_bug 会返回 null
	await frames(2)
	var P := Vector3(700, 0, 700)
	raid._static_box(Vector3(80, 1, 80), P - Vector3(0, 0.5, 0), Color(0.5, 0.5, 0.5))
	m.global_position = P + Vector3(0, 0.2, 0)
	m.max_hp = 99999.0; m.hp = 99999.0
	var results := {}
	for hgt in [1.2, 2.5, 4.0]:
		var w = raid._static_box(Vector3(0.6, hgt, 6), P + Vector3(-5, hgt * 0.5, 0), Color(0.6, 0.57, 0.52))
		var b = raid.spawn_bug("beetle", P + Vector3(-9, 0.3, 0))
		if not check(b != null, "生成甲虫失败"):
			return
		b.set_physics_process(false)
		raid.aim_override = P + Vector3(-9, 1.8, 0)
		await wait(0.3)
		var hp0: float = b.hp
		Input.action_press("fire_left"); Input.action_press("fire_right")
		await wait(2.0)
		Input.action_release("fire_left"); Input.action_release("fire_right")
		await wait(0.5)
		results[hgt] = [hp0, b.hp]
		w.queue_free()
		b.queue_free()
		await wait(0.2)
	# 对照：没有墙
	var b2 = raid.spawn_bug("beetle", P + Vector3(-9, 0.3, 0))
	b2.set_physics_process(false)
	await wait(0.3)
	var h0: float = b2.hp
	Input.action_press("fire_left")
	await wait(2.0)
	Input.action_release("fire_left")
	var h1: float = b2.hp
	log_line("behind wall (h: [hp0, hp1]) = %s  no wall: %.1f -> %.1f" % [results, h0, h1])
	for hgt in results:
		if not check(is_equal_approx(results[hgt][0], results[hgt][1]), "%.1f 米高的墙没有挡住子弹：%s" % [hgt, results[hgt]]):
			return
	check(h1 < h0, "没有墙时子弹没有打中甲虫")
