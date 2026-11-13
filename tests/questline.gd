extends "res://tests/lib/test_base.gd"
## 商人委托：每位商人多条独立委托、可同时接取多条、逐条提交、状态随存档往返
const START := "none"
const Growth = preload("res://scripts/progression/growth.gd")


func run() -> void:
	await frames(2)
	GameData.quests = {}
	GameData.quest_state = {}
	GameData.quest_progress = {}
	# 每位商人都应有多条委托，且互不阻塞
	for m: String in GameData.QUEST_ORDER:
		check((GameData.QUEST_CHAINS[m] as Array).size() >= 4, "%s 的委托少于 4 条" % m)
	if not check(GameData.merchant_quests("ajin").size() == 5, "阿堇委托条数不对"):
		return
	# 同时接取：同一商人 3 条 + 另一位商人 1 条
	if not check(GameData.accept_quest("ajin", 0) and GameData.accept_quest("ajin", 1) and GameData.accept_quest("ajin", 2), "阿堇的多条委托接取失败"):
		return
	if not check(GameData.accept_quest("xiaoman", 0), "小满委托接取失败"):
		return
	if not check(not GameData.accept_quest("ajin", 0), "已接取委托被重复接取"):
		return
	if not check(GameData.quest_status("ajin", 1) == 1 and GameData.quest_status("ajin", 3) == 0, "接取状态不对"):
		return
	log_line("accepted multiple: ajin 3 + xiaoman 1")
	var money0 := GameData.money
	var q0 := GameData.quest_entry("ajin", 0)
	for _k in int(q0.count):
		GameData.stash.append(str(q0.id))
	if not check(GameData.fulfill_quest("ajin", 0), "提交阿堇第 1 条失败"):
		return
	if not check(GameData.quest_status("ajin", 0) == 2, "提交后状态不是已完成"):
		return
	if not check(GameData.quest_status("ajin", 1) == 1 and GameData.quest_status("xiaoman", 0) == 1, "提交一条影响了其他已接取委托"):
		return
	if not check(GameData.money > money0, "提交委托没有加钱"):
		return
	if not check(Growth.crew_level("ajin") >= 1, "任务完成没有提升好感"):
		return
	log_line("independent submit ok")
	# 击杀类：未接取不计，只累加对应目标
	Events.enemy_killed.emit("beetle", Vector3.ZERO)
	if not check(GameData.quest_progress_of("xiaoman", 1) == 0 and GameData.quest_progress_of("ajin", 1) == 0, "未接取或错误目标的击杀被计数"):
		return
	for _k in 6:
		Events.enemy_killed.emit("ling", Vector3.ZERO)
	if not check(GameData.quest_progress_of("ajin", 1) == 6 and GameData.quest_ready("ajin", 1), "击杀委托进度不对"):
		return
	if not check(GameData.fulfill_quest("ajin", 1), "提交击杀委托失败"):
		return
	if not check(GameData.quest_status("ajin", 1) == 2, "击杀委托提交后未完成"):
		return
	# 撤离类：只在目标战区累计
	if not check(GameData.accept_quest("xiaoman", 3), "接取撤离委托失败"):
		return
	GameData.map_id = "ironbelt"
	Events.extract_completed.emit("", false)
	if not check(GameData.quest_progress_of("xiaoman", 3) == 1 and not GameData.quest_ready("xiaoman", 3), "撤离委托首次进度不对"):
		return
	Events.extract_completed.emit("", false)
	if not check(GameData.quest_ready("xiaoman", 3), "撤离委托两次后未达成"):
		return
	if not check(GameData.fulfill_quest("xiaoman", 3), "提交撤离委托失败"):
		return
	# 前往类：目标战区达成
	if not check(GameData.accept_quest("ajin", 3), "接取前往委托失败"):
		return
	Events.deployed.emit("greyport", {})
	if not check(GameData.quest_progress_of("ajin", 3) == 0, "非目标战区的出击被计数"):
		return
	Events.deployed.emit("redlake", {})
	if not check(GameData.quest_ready("ajin", 3) and GameData.fulfill_quest("ajin", 3), "前往委托未达成或提交失败"):
		return
	log_line("kill / extract / visit ok")
	# 未完成进度随存档保存
	if not check(GameData.accept_quest("shiori", 1), "接取诗织击杀委托失败"):
		return
	Events.enemy_killed.emit("spitter", Vector3.ZERO)
	GameData.save_game()
	GameData.quest_state = {}
	GameData.quest_progress = {}
	GameData.quests = {}
	log_line("load begin")
	if not check(GameData.load_game(), "读档失败"):
		return
	if not check(GameData.quest_status("ajin", 0) == 2 and GameData.quest_status("ajin", 1) == 2 and GameData.quest_status("xiaoman", 3) == 2 and GameData.quest_status("ajin", 3) == 2, "已完成状态没有随存档保存"):
		return
	if not check(GameData.quest_status("shiori", 1) == 1 and GameData.quest_progress_of("shiori", 1) == 1, "委托进度没有随存档保存"):
		return
	log_line("questline ok")
