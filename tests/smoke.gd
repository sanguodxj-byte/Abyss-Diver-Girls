extends "res://tests/lib/test_base.gd"
## 冒烟测试：出击 → 移动开火 → 技能 → 搜容器 → 呼叫运输机 → 撤离成功 → 再次出击 → 机甲损毁 → 领取应急机架，
## 并校验这一路上的关键事件都经事件总线发出过。godot --headless --path . -- --smoke

const REQUIRED_EVENTS := ["deployed", "drop_landed", "skill_used", "box_opened", "item_revealed", "item_picked", "item_used",
	"transport_called", "extract_started", "extract_completed", "raid_finished", "returned_to_hub", "player_damaged", "mech_destroyed"]

var seen := {}


func run() -> void:
	Events.any.connect(func(e: String, _a): seen[e] = int(seen.get(e, 0)) + 1)
	await wait(0.5)
	log_line("hub ok, money=%d loadout=%s save=%s" % [GameData.money, GameData.loadout, GameData.save_path])
	if not check(GameData.test_mode and GameData.save_path.begins_with(GameData.TEST_SAVE_DIR), "测试运行没有使用临时存档：%s" % GameData.save_path):
		return
	main.hub._starter_frame()
	main.hub.deploy_requested.emit()
	await wait(2.0)
	var raid = main.raid
	if not check(raid != null and raid.mech != null, "出击后没有生成行动场景"):
		return
	raid.mech.shield_time = 999.0
	log_line("raid started, bugs=%d boxes=%d" % [get_tree().get_nodes_in_group("bugs").size(), get_tree().get_nodes_in_group("lootboxes").size()])
	Input.action_press("move_up")
	Input.action_press("fire_left")
	Input.action_press("fire_right")
	await wait(1.5)
	Input.action_release("move_up")
	Input.action_release("fire_left")
	Input.action_release("fire_right")
	raid.mech.try_ability()
	raid.mech.try_dash(Vector3.RIGHT)
	await wait(0.8)
	# 搜容器：在机甲旁边放一只补给箱
	var mp: Vector3 = raid.mech.global_position
	var box = raid._place_box("supply", Vector3(mp.x + 2.5, 0, mp.z))
	await wait(0.3)
	raid.open_container(box)
	await wait(2.5)
	log_line("box %s revealed %d/%d" % [box.title, box.revealed, box.items.size()])
	if not check(box.revealed > 0, "容器里的物品没有逐个显现"):
		return
	while box.revealed > 0 and box.items.size() > 0:
		var before: int = box.items.size()
		raid.take_from_box(0)
		if box.items.size() == before:
			break
	raid.close_box()
	log_line("cargo=%s" % [raid.mech.cargo])
	raid.mech.shield_time = 999.0
	raid.call_transport()
	# 打一会儿
	Input.action_press("fire_left")
	await wait(3.0)
	Input.action_release("fire_left")
	log_line("kills=%d hp=%.1f energy=%.1f" % [raid.kills, raid.mech.hp, raid.mech.energy])
	# 撤离
	var ok_before := GameData.extracts_ok
	raid.mech.shield_time = 999.0
	raid.mech.global_position = raid.extracts[0].global_position + Vector3(0, 0.5, 0)
	await wait(10.5)
	log_line("after extract: result layer=%s stash=%d extracts_ok=%d" % [main.result_layer != null, GameData.stash.size(), GameData.extracts_ok])
	if not check(main.result_layer != null and GameData.extracts_ok == ok_before + 1, "撤离没有成功"):
		return
	if not check(not GameData.loadout.is_empty(), "撤离成功后机甲没有带回"):
		return
	main.show_hub()
	await wait(0.5)
	main.hub.deploy_requested.emit()
	await wait(2.0)
	if not check(main.raid != null and main.raid.mech != null, "第二次出击没有生成行动场景"):
		return
	main.raid.mech.take_damage(99999)
	await wait(2.0)
	log_line("after death: loadout=%s raids=%d" % [GameData.loadout, GameData.raids])
	if not check(main.result_layer != null and GameData.loadout.is_empty(), "机甲损毁后没有进入失败结算或机甲没有失去"):
		return
	main.show_hub()
	await wait(0.3)
	main.hub._starter_frame()
	var err := GameData.can_deploy(GameData.loadout)
	log_line("starter frame -> %s deploy err='%s'" % [GameData.loadout, err])
	if not check(err == "", "领取应急机架后仍不能出击：%s" % err):
		return
	var missing: Array = []
	for e in REQUIRED_EVENTS:
		if not seen.has(e):
			missing.append(e)
	log_line("events=%s" % [seen])
	check(missing.is_empty(), "以下事件没有发出：%s" % [missing])
