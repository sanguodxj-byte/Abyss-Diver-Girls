extends "res://tests/lib/test_base.gd"
## 商人任务线：按顺序推进、完成换下一条、链尾换商人、进度随存档往返
const START := "none"
const Growth = preload("res://scripts/progression/growth.gd")


func run() -> void:
	await frames(2)
	GameData.quests = {}
	GameData.new_request()
	if not check(str(GameData.request.get("merchant", "")) == "ajin", "起始委托不是阿堇：%s" % [GameData.request]):
		return
	if not check(int(GameData.request.count) == 3 and str(GameData.request.id) == "can_food", "阿堇首条委托内容不对"):
		return
	log_line("start " + str(GameData.request))
	var money0 := GameData.money
	for i in 5:
		var q: Dictionary = GameData.request
		if q.is_empty():
			break
		for k in int(q.count):
			GameData.stash.append(str(q.id))
		log_line("submit %d %s" % [i, q])
		if not check(GameData.fulfill_request(), "第 %d 条委托提交失败" % (i + 1)):
			return
	if not check(int(GameData.quests.get("ajin", 0)) == 5, "阿堇任务链没有走完：%s" % [GameData.quests]):
		return
	if not check(str(GameData.request.get("merchant", "")) == "xiaoman", "阿堇链尾没有接到小满：%s" % [GameData.request]):
		return
	if not check(GameData.money > money0, "提交委托没有加钱"):
		return
	if not check(Growth.crew_level("ajin") >= 1, "任务完成没有提升好感"):
		return
	log_line("chain done")
	GameData.save_game()
	var m: String = str(GameData.request.merchant)
	var qn: int = int(GameData.request.count)
	GameData.quests = {}
	GameData.request = {}
	log_line("load begin")
	if not check(GameData.load_game(), "读档失败"):
		return
	if not check(int(GameData.quests.get("ajin", 0)) == 5, "任务进度没有随存档保存"):
		return
	if not check(str(GameData.request.get("merchant", "")) == m and int(GameData.request.get("count", 0)) == qn, "读档后当前委托没有恢复"):
		return
	log_line("questline ok")
