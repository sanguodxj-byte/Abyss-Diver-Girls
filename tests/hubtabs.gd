extends "res://tests/lib/test_base.gd"
## 机库各页签截图：godot --path . -- --hubtabs （环境变量 SHOT_PREFIX=before/after）
## → review/hubtab_<prefix>_<页签>.png
const START := "hub"
const TIMEOUT := 220.0


func run() -> void:
	var prefix := OS.get_environment("SHOT_PREFIX")
	if prefix == "":
		prefix = "after"
	await wait(1.5)
	var hub = main.hub
	## SHOT_SET=a 只截各页签，b 只截「有资源存档」与悬停浮窗，空 = 全部（全部截完约 2 分钟）
	var shot_set := OS.get_environment("SHOT_SET")
	var tabs: Array = ["maintenance", "trade", "deploy", "stash", "codex"]
	if shot_set == "b":
		tabs = []
	if hub.views.has("skills"):
		tabs.insert(3, "skills")
	for t in tabs:
		hub._switch_tab(t)
		await wait(0.6)
		if t == "trade":
			if hub.has_method("_trade_show"):
				await shot("hubtab_%s_trade_list.png" % prefix)
			hub._select_merchant("xiaoman")
			await wait(0.4)
		if t == "stash" and not hub.stash_ids.is_empty():
			hub.stash_list.select(0)
			hub._on_stash_selected(0)
			await wait(0.3)
		await shot("hubtab_%s_%s.png" % [prefix, t])
		if t == "deploy" and hub.has_method("_deploy_show"):
			hub._deploy_show(2)
			await wait(0.4)
			await shot("hubtab_%s_deploy2.png" % prefix)
	if shot_set != "b" and hub.views.has("skills") and hub.has_method("_skills_show"):
		for sub in ["pilot", "pods"]:
			hub._switch_tab("skills")
			hub._skills_show(sub)
			await wait(0.5)
			await shot("hubtab_%s_skills_%s.png" % [prefix, sub])
	# 有资源的存档：购置部署仓、强化能力后再截技能与降落页
	if shot_set != "a" and hub.views.has("skills"):
		var G = load("res://scripts/progression/growth.gd")
		GameData.money = 40000
		for id in ["bolts", "wire", "circuit", "chitin", "bug_crystal", "hdd", "can_food", "water_tab", "coffee"]:
			for i in 12:
				GameData.stash.append(id)
		G.buy_pod("rei")
		G.buy_pod("rei")
		G.buy_pod("kurumi")
		G.upgrade_ability("ab_frame")
		G.upgrade_ability("ab_frame")
		G.upgrade_ability("ab_reactor")
		G.upgrade_facility("hangar")
		G.upgrade_facility("hangar")
		G.upgrade_facility("lab")
		G.add_pilot_xp("nao", 300)
		G.set_player_name("白鹭")
		for sub in ["airship", "pilot", "pods"]:
			hub._switch_tab("skills")
			hub._skills_show(sub)
			await wait(0.5)
			await shot("hubtab_%s_owned_skills_%s.png" % [prefix, sub])
		hub._switch_tab("deploy")
		await wait(0.5)
		await shot("hubtab_%s_owned_deploy.png" % prefix)
		if hub.has_method("_deploy_show"):
			hub._deploy_show(2)
			await wait(0.4)
			await shot("hubtab_%s_owned_deploy2.png" % prefix)
		hub._switch_tab("stash")
		await wait(0.4)
		hub._on_stash_selected(0)
		await wait(0.3)
		await shot("hubtab_%s_owned_stash.png" % prefix)
		hub._switch_tab("trade")
		hub._select_merchant("gin")
		await wait(0.4)
		if hub.has_method("_trade_pick_sell") and not hub.stash_ids.is_empty():
			hub._trade_pick_sell(hub.stash_ids[0])
			await wait(0.2)
		await shot("hubtab_%s_owned_trade.png" % prefix)
		# 悬停浮窗：把鼠标移到仓库页第一格上
		if hub.get("stash_list") is Control and hub.stash_list.has_method("index_at"):
			hub._switch_tab("stash")
			await wait(0.4)
			var g: Control = hub.stash_list
			var p := g.get_global_rect().position + Vector2(g.get("_ox") + 28 + 56 * 3, 28)
			Input.warp_mouse(p * get_viewport().get_screen_transform().get_scale())
			var mm := InputEventMouseMotion.new()
			mm.position = p
			mm.global_position = p
			get_viewport().push_input(mm)
			await wait(1.6)
			await shot("hubtab_%s_owned_tooltip.png" % prefix)
		hub._switch_tab("maintenance")
		await wait(0.6)
		await shot("hubtab_%s_owned_maintenance.png" % prefix)
	hub._switch_tab("maintenance")
	await wait(0.3)
