extends "res://tests/lib/test_base.gd"
## 局外成长：默认值、设施升级、研究解锁与商店筛选、驾驶员经验与天赋、船员好感与赠礼、后勤委托、
## 出击食堂、行动结算与章节推进、失败模块回收、存档再读档、旧存档补默认值、成长面板构建。
## godot --headless --path . -- --progress
const START := "none"
const Growth = preload("res://scripts/progression/growth.gd")
const PanelScript = preload("res://scripts/progression/growth_panel.gd")


func run() -> void:
	await frames(2)
	if not check(Story != null, "Story autoload 未加载，无法验证章节与好感事件"):
		return
	# 清空本测试进程的成长状态，从新档默认值开始
	Progress.state = {}
	GameData.money = 60000
	GameData.stash = []
	for id in ["bolts", "wire", "circuit", "chitin", "water_tab", "can_food", "coffee"]:
		_stock(id, 24)
	_stock("bug_crystal", 12)
	_stock("hdd", 6)
	GameData.loadout = GameData.STARTER.duplicate()

	var s := Growth.ensure_defaults()
	log_line("defaults: facilities=%d research=%d pilots=%d crew=%d" % [s.facilities.size(), (s.research as Array).size(), s.pilots.size(), s.crew.size()])
	if not check(Growth.facility_level("hangar") == 0 and Growth.pilot_level("nao") == 1 and Growth.crew_level("lina") == 0, "新档默认值不正确"):
		return
		if not check(Growth.facility_ids().size() == 5 and Growth.pilot_ids().size() == 3 and Growth.crew_ids().size() == 4, "设施 / 驾驶员 / 船员数量不正确"):
			return
		Growth.set_player_name("测试名")
		if not check(Growth.player_name() == "测试名" and str(Growth.pilot_data("nao").get("name", "")) == "测试名", "主角自定义姓名未生效"):
			return
		if not check(Growth.subst("{player_name}姐") == "测试名姐", "自定义姓名文本替换未生效"):
			return
		Growth.set_player_name(Growth.DEFAULT_PLAYER_NAME)
	if not check(GameData.map_available("greyport") and not GameData.map_available("ironbelt"), "初始战区准入不对：灰港市应开放、铁锈工业带应锁定"):
		return
	if not check(not GameData.map_available("abyss_maw"), "初始零号深渊井应锁定"):
		return
	if not check(GameData.ITEMS.has("gift_watch") and GameData.LOOT_TABLES.supply.pool.has("gift_cocoa"), "赠礼物品或掉落池没有并入扩展数据"):
		return
	var has_char_request := false
	for r in GameData.REQUEST_POOL:
		if str(r.get("char", "")) == "xiaoman":
			has_char_request = true
	if not check(has_char_request, "新后勤委托没有登记好感归属"):
		return
	for rid in Growth.research_ids():
		for mid in Growth.research_data(rid).get("shop", []):
			if not check(GameData.MODULES.has(str(mid)), "研究 %s 上架了不存在的模块 %s" % [rid, mid]):
				return
	for cid in Growth.crew_ids():
		var pref := str(Growth.crew_data(cid).get("preferred", ""))
		if not check(GameData.ITEMS.has(pref), "船员 %s 的偏爱赠礼 %s 不存在" % [cid, pref]):
			return

	# ---- 设施：机库 1 级带来结构 +5、货舱 +1 ----
	var base := GameData.compute_stats(GameData.STARTER)
	if not check(Growth.upgrade_facility("hangar"), "机库升级失败：%s" % Growth.can_upgrade("hangar")):
		return
	var after := GameData.compute_stats(GameData.STARTER)
	if not check(is_equal_approx(after.hp, base.hp + 5.0) and is_equal_approx(after.cargo, base.cargo + 1.0), "机库 1 级的机体加成不对：hp %.0f→%.0f cargo %.0f→%.0f" % [base.hp, after.hp, base.cargo, after.cargo]):
		return
	# ---- 研究室 2 级：能源 +10，且研究节点按研究室等级解锁 ----
	if not check(Growth.upgrade_facility("lab") and Growth.upgrade_facility("lab"), "研究室升级失败"):
		return
	if not check(Growth.facility_level("lab") == 2, "研究室等级没有到 2"):
		return
	var after_lab := GameData.compute_stats(GameData.STARTER)
	if not check(is_equal_approx(after_lab.energy, after.energy + 10.0), "研究室 2 级没有加 10 能源"):
		return

	# ---- 研究：虫晶燃料电池组 +12 能源；聚焦透镜阵列上架聚焦激光 ----
	if not check(Growth.can_research("res_lens") == "", "研究室 2 级时聚焦透镜阵列应可研究：%s" % Growth.can_research("res_lens")):
		return
	if not check(Growth.can_research("res_hover") == "研究室 Lv3", "研究室 2 级时反重力悬浮环应被研究室等级挡住"):
		return
	if not check(not Growth.shop_allowed("arm_laser"), "未研究时聚焦激光不应上架"):
		return
	if not check(not GameData.shop_items().has("arm_laser"), "未研究时商店里出现了聚焦激光"):
		return
	if not check(Growth.do_research("res_cell"), "虫晶燃料电池组研究失败：%s" % Growth.can_research("res_cell")):
		return
	var after_res := GameData.compute_stats(GameData.STARTER)
	if not check(is_equal_approx(after_res.energy, after_lab.energy + 12.0), "研究完成后能源上限没有 +12"):
		return
	if not check(Growth.do_research("res_lens"), "聚焦透镜阵列研究失败：%s" % Growth.can_research("res_lens")):
		return
	if not check(Growth.shop_allowed("arm_laser") and GameData.shop_items().has("arm_laser"), "研究完成后聚焦激光没有上架"):
		return

	# ---- 驾驶员：经验升级、天赋点、天赋生效、切换出击机体 ----
	var xp := Growth.add_pilot_xp("nao", 500)
	log_line("nao xp: levels=%d level=%d points=%d" % [int(xp.get("levels", 0)), int(xp.get("level", 1)), int(xp.get("points", 0))])
	if not check(int(xp.get("levels", 0)) >= 3 and Growth.pilot_level("nao") >= 4, "500 经验没有把奈绪升到 4 级"):
		return
	var pre_talent := GameData.compute_stats(GameData.STARTER)
	if not check(Growth.learn_talent("nao", "t_nao_rig"), "载重桁架习得失败：%s" % Growth.can_learn_talent("nao", "t_nao_rig")):
		return
	var after_talent := GameData.compute_stats(GameData.STARTER)
	if not check(is_equal_approx(after_talent.load, pre_talent.load + 8.0), "载重桁架没有加 8 承重（%.1f→%.1f）" % [pre_talent.load, after_talent.load]):
		return
	if not check(Growth.set_active_pilot("rei") and Growth.active_pilot() == "rei", "切换出击机体失败"):
		return
	var rei_before := GameData.compute_stats(GameData.STARTER)
	Growth.add_pilot_xp("rei", 90)
	var rei_after := GameData.compute_stats(GameData.STARTER)
	if not check(is_equal_approx(rei_after.energy, rei_before.energy + 5.0), "零升到 2 级后的能源加成没有生效"):
		return
	if not check(Growth.set_active_pilot("nao"), "切回奈绪失败"):
		return

	# ---- 船员：好感升级广播、赠礼消耗与双倍好感 ----
	var affinity: Array = []
	var cap_affinity := func(e: String, a: Dictionary):
		if e == "affinity_changed":
			affinity.append(a)
	Events.any.connect(cap_affinity)
	Growth.grant_affinity("lina", 1)
	Events.any.disconnect(cap_affinity)
	if not check(Growth.crew_level("lina") == 1, "莉娜好感没有升到 1 级"):
		return
	if not check(affinity.size() == 1 and str(affinity[0].char) == "lina" and int(affinity[0].level) == 1, "affinity_changed 事件参数不对：%s" % [affinity]):
		return
	GameData.stash.append("gift_watch")
	if not check(Growth.give_gift("lina", "gift_watch"), "赠礼失败"):
		return
	if not check(Growth.crew_level("lina") == 2 and not GameData.stash.has("gift_watch"), "铜壳怀表没有把莉娜送到 2 级或没有扣除赠礼"):
		return

	# ---- 后勤委托：提交后按委托人加好感 ----
	GameData.request = {"id": "can_food", "count": 1, "reward": 10, "who": "厨师阿堇"}
	GameData.stash.append("can_food")
	if not check(GameData.fulfill_request(), "提交后勤委托失败"):
		return
	if not check(Growth.crew_level("ajin") == 1, "阿堇的委托没有加好感"):
		return

	# ---- 出击食堂：烹制餐点 +12 能源 / +3 结构，行动结束后清空 ----
	if not check(Growth.upgrade_facility("kitchen"), "厨房升级失败"):
		return
	var before_meal := GameData.compute_stats(GameData.STARTER)
	if not check(Growth.serve_meal(), "烹制餐点失败"):
		return
	var after_meal := GameData.compute_stats(GameData.STARTER)
	if not check(is_equal_approx(after_meal.energy, before_meal.energy + 12.0) and is_equal_approx(after_meal.hp, before_meal.hp + 3.0), "出击餐点的加成不对"):
		return
	if not check(Growth.meal_text() != "", "出击餐点没有状态文字"):
		return

	# ---- 行动结算：成功撤离推进第一章、切到第二章、解锁铁锈工业带 ----
	var reports: Array = []
	var cap_report := func(e: String, a: Dictionary):
		if e == "growth_report":
			reports.append(a)
	Events.any.connect(cap_report)
	Events.raid_finished.emit(true, {"success": true, "map_id": "greyport", "kills": 5,
		"cargo": ["bug_crystal", "circuit"], "loadout": GameData.STARTER.duplicate(), "time": 120.0})
	await frames(1)
	Events.any.disconnect(cap_report)
	if not check(Story.has_flag("ch1_done"), "撤离成功后没有写入 ch1_done"):
		return
	if not check(Story.chapter == "ch2", "撤离成功后当前章节不是 ch2：%s" % Story.chapter):
		return
	if not check(GameData.map_available("ironbelt"), "ch1_done 后铁锈工业带仍不可出击"):
		return
	if not check(Growth.meal_ready() == 0, "行动结束后出击餐点没有清空"):
		return
	if not check(reports.size() == 1 and int(reports[0].xp) > 0, "行动结束没有广播成长报告"):
		return

	# ---- Boss 章节：先满足第五章，再击破裂谷铁甲王虫完成第六章 ----
	Story.set_flag("ch5_done", true)
	Growth.ensure_defaults()
	Events.boss_defeated.emit("king_beetle")
	await frames(1)
	if not check(Story.has_flag("ch6_done"), "击破裂谷铁甲王虫后没有写入 ch6_done"):
		return
	if GameData.MAPS.has("abyss_maw"):
		if not check(GameData.map_available("abyss_maw"), "ch6_done 后零号深渊井仍不可出击"):
			return

	# ---- 医务室 5 级：行动失败必定回收一件遗失模块 ----
	for i in 5:
		if not check(Growth.upgrade_facility("infirmary"), "医务室第 %d 级升级失败：%s" % [i + 1, Growth.can_upgrade("infirmary")]):
			return
	var mods := ["core_scout", "legs_biped", "arm_mg", "back_cargo", "gen_cell"]
	var before_mods := {}
	for id in mods:
		before_mods[id] = GameData.stash.count(id)
	Events.raid_finished.emit(false, {"success": false, "map_id": "greyport", "kills": 2,
		"cargo": [], "loadout": GameData.STARTER.duplicate(), "time": 60.0})
	await frames(1)
	var recovered := 0
	for id in mods:
		recovered += GameData.stash.count(id) - int(before_mods[id])
	if not check(recovered == 1, "医务室 5 级没有回收一件模块（回收 %d 件）" % recovered):
		return

	# ---- 存档再读档：设施、研究、驾驶员、好感、章节全部还原 ----
	var fac_save := Growth.facility_level("hangar")
	var lab_save := Growth.facility_level("lab")
	var pilot_save := Growth.pilot_level("nao")
	var crew_save := Growth.crew_level("lina")
	var chapter_save: Array = (Progress.state.get("chapters", []) as Array).duplicate()
	GameData.save_game()
	Progress.state = {}
	Growth.ensure_defaults()
	if not check(Growth.facility_level("hangar") == 0, "清空状态后机库等级没有归零"):
		return
	if not check(GameData.load_game(), "读档失败"):
		return
	Growth.ensure_defaults()
	if not check(Growth.facility_level("hangar") == fac_save and Growth.facility_level("lab") == lab_save, "设施等级没有随存档还原"):
		return
	if not check(Growth.pilot_level("nao") == pilot_save and Growth.crew_level("lina") == crew_save, "驾驶员 / 好感没有随存档还原"):
		return
	if not check((Progress.state.get("chapters", []) as Array) == chapter_save, "章节进度没有随存档还原"):
		return
	if not check(Growth.research_done("res_cell") and Growth.research_done("res_lens"), "研究进度没有随存档还原"):
		return

	# ---- 旧存档：只有设施字段，其余补默认值 ----
	Progress.state = {"facilities": {"hangar": 3}, "active_pilot": "zzz"}
	Growth.ensure_defaults()
	if not check(Growth.facility_level("hangar") == 3, "旧存档的机库等级被覆盖"):
		return
	if not check(Growth.active_pilot() == "nao", "旧存档的无效驾驶员没有回落到奈绪"):
		return
	if not check(Growth.pilot_level("nao") == 1 and Growth.crew_level("ajin") == 0 and Growth.meal_ready() == 0, "旧存档没有补齐驾驶员 / 好感 / 食堂默认值"):
		return

	# ---- 成长面板：五个分页都能构建，Esc 之外的关闭按钮存在 ----
	var panel = PanelScript.new()
	add_child(panel)
	panel.open()
	await frames(2)
	if not check(panel.visible, "成长面板没有打开"):
		return
	for tab in ["facilities", "research", "pilots", "crew", "voyage"]:
		panel.show_tab(tab)
		await frames(1)
	var esc := InputEventAction.new()
	esc.action = "pause"
	esc.pressed = true
	panel._input(esc)
	if not check(not panel.visible, "Esc 没有关闭成长面板"):
		return
	panel.open()
	await frames(1)
	panel.close()
	if not check(not panel.visible, "成长面板没有关闭"):
		return
	panel.queue_free()
	await frames(2)
	log_line("panel ok, final money=%d stash=%d" % [GameData.money, GameData.stash.size()])


func _stock(id: String, n: int) -> void:
	for i in n:
		GameData.stash.append(id)
