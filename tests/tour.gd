extends "res://tests/lib/test_base.gd"
## 全流程截图巡览：主菜单 → 机库 → 拆解视图 → 空投 → 战斗 → 搜刮面板 → 暂停菜单 → 大地图 → 撤离读条 → 结算成功 → 结算失败。
## godot --path . -- --tour → review\tour_01_menu.png … tour_11_result_fail.png；无界面运行时只走流程不截图。
const START := "menu"
const TIMEOUT := 400.0
const SHOTS := ["tour_01_menu.png", "tour_02_hub.png", "tour_03_explode.png", "tour_04_drop.png", "tour_05_combat.png", "tour_06_loot.png",
	"tour_07_pause.png", "tour_08_bigmap.png", "tour_09_extract.png", "tour_10_result_success.png", "tour_11_result_fail.png"]


func run() -> void:
	await wait(3.0)
	await shot(SHOTS[0])
	main.menu.start_requested.emit()
	await wait(1.5)
	if not check(main.hub != null, "主菜单没有进入机库"):
		return
	await shot(SHOTS[1])
	main.hub._toggle_explode()
	await wait(1.2)
	await shot(SHOTS[2])
	main.hub._toggle_explode()
	await wait(0.8)
	# 空投：反推点火之后、着陆之前
	main.hub.deploy_requested.emit()
	if not check(main.raid != null and main.raid.mech != null, "出击失败"):
		return
	var raid = main.raid
	Engine.time_scale = 0.2
	await wait(1.15)
	await shot(SHOTS[3])
	Engine.time_scale = 1.0
	if not check(await until(func(): return not raid.mech.input_locked, 15.0), "空投后机甲一直不能操作"):
		return
	await wait(0.5)
	# 战斗：清掉地图上的虫子（MAX_BUGS 名额），在机甲前方摆一群
	var m = raid.mech
	m.max_hp = 99999.0
	m.hp = 99999.0
	for b in get_tree().get_nodes_in_group("bugs"):
		b.queue_free()
	await frames(2)
	var c: Vector3 = m.global_position
	var spots := [[Vector3(5, 0, -7), "ling"], [Vector3(3, 0, -9), "ling"], [Vector3(-3, 0, -8), "ling"], [Vector3(7, 0, -4), "ling"],
		[Vector3(-1, 0, -10), "ling"], [Vector3(1, 0, -6), "ling"], [Vector3(-6, 0, -5), "spitter"], [Vector3(8, 0, -9), "spitter"], [Vector3(0, 0, -12), "beetle"]]
	for s in spots:
		var bug = raid.spawn_bug(s[1], c + s[0] + Vector3(0, 0.5, 0))
		if bug:
			bug.state = "chase"
	raid.aim_override = c + Vector3(1, 1.8, -8)
	await wait(0.6)
	Input.action_press("fire_left")
	Input.action_press("fire_right")
	await wait(0.35)
	await shot(SHOTS[4])
	Input.action_release("fire_left")
	Input.action_release("fire_right")
	for b in get_tree().get_nodes_in_group("bugs"):
		b.queue_free()
	raid.aim_override = null
	await wait(0.8)
	# 搜刮面板
	var mp: Vector3 = m.global_position
	var box = raid._place_box("military", Vector3(mp.x + 2.5, 0, mp.z))
	await wait(0.3)
	raid.open_container(box)
	await wait(1.9)
	await shot(SHOTS[5])
	raid.close_box()
	await wait(0.5)
	# 暂停菜单（树暂停时测试节点与计时器照常运行）
	raid.hud.toggle_pause()
	await wait(0.4)
	await shot(SHOTS[6])
	raid.hud.toggle_pause()
	await wait(0.3)
	# 大地图
	raid.hud.toggle_map()
	await wait(0.4)
	await shot(SHOTS[7])
	raid.hud.toggle_map()
	await wait(0.3)
	# 撤离读条
	m.shield_time = 999.0
	m.global_position = raid.extracts[0].global_position + Vector3(0, 0.5, 0)
	await wait(4.0)
	if not check(raid.extract_target != null, "站进撤离区后没有开始读条"):
		return
	await shot(SHOTS[8])
	# 结算成功
	if not check(await until(func(): return main.result_layer != null, 12.0), "撤离读条结束后没有出现结算界面"):
		return
	await wait(0.8)
	await shot(SHOTS[9])
	# 结算失败：回机库再出击，机甲损毁
	main.show_hub()
	await wait(1.0)
	main.hub.deploy_requested.emit()
	if not check(main.raid != null and main.raid.mech != null, "第二次出击失败"):
		return
	if not check(await until(func(): return not main.raid.mech.input_locked, 15.0), "第二次空投后机甲一直不能操作"):
		return
	await wait(0.5)
	main.raid.mech.take_damage(99999.0)
	if not check(await until(func(): return main.result_layer != null, 8.0), "机甲损毁后没有出现结算界面"):
		return
	await wait(0.8)
	await shot(SHOTS[10])
