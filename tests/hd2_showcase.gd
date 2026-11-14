extends "res://tests/lib/test_base.gd"
## HD2 flat tactical UI & 3D item icon showcase capture:
##   godot --path . --resolution 1920x1080 -- --hd2_showcase
const START := "menu"
const TIMEOUT := 180.0


func run() -> void:
	if headless():
		log_line("skip hd2_showcase in headless")
		return

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	get_window().size = Vector2i(1920, 1080)
	await frames(4)

	# 1. Menu
	await wait(3.5)
	if main.menu != null:
		main.menu.sel = 0
		main.menu.cur_y = 0.0
		if main.menu.hud != null:
			main.menu.hud.queue_redraw()
	await frames(4)
	await shot("hd2_00_menu.png")

	# 2. Enter Hub & seed showcase inventory/progression
	main.menu.start_requested.emit()
	await wait(1.0)

	var GrowthScript = load("res://scripts/progression/growth.gd")
	GameData.money = 48500
	var seed_items := [
		"arm_amr", "arm_sniper", "legs_quad", "core_heavy", "arm_ac30",
		"arm_shotgun", "back_missile", "gen_crystal", "gen_reactor",
		"hdd", "repair_kit", "fuel_cell", "extract_flare",
		"bug_crystal", "chitin", "circuit", "can_food", "coffee", "gold",
	]
	for id: String in seed_items:
		GameData.stash.append(id)
	GrowthScript.upgrade_facility("hangar")
	GrowthScript.upgrade_facility("lab")
	GrowthScript.record_skill_xp("ab_servo", 26.0, true)
	GrowthScript.record_skill_xp("ab_firearm", 68.0, false)
	GrowthScript.record_skill_xp("ab_search", 120.0, false)
	main.show_hub()
	await wait(0.8)

	# 3. Hub Maintenance
	main.hub._switch_tab("maintenance")
	await wait(0.8)
	await shot("hd2_01_hub_maint.png")

	# 4. Hub Stash (select 4x1 sniper rifle)
	main.hub._switch_tab("stash")
	await wait(0.5)
	if not main.hub.stash_ids.is_empty():
		var idx: int = maxi(0, main.hub.stash_ids.find("arm_amr"))
		main.hub.stash_list.select(idx)
		main.hub._on_stash_selected(idx)
	await wait(0.4)
	await shot("hd2_02_hub_stash.png")

	# 5. Hub Trade (Merchant Gin + select item in trade bar)
	main.hub._switch_tab("trade")
	main.hub._select_merchant("gin")
	await wait(0.3)
	if main.hub.has_method("_trade_pick_sell") and not main.hub.stash_ids.is_empty():
		var tid: String = "arm_amr" if "arm_amr" in main.hub.stash_ids else str(main.hub.stash_ids[0])
		main.hub._trade_pick_sell(tid)
	await wait(0.4)
	await shot("hd2_03_hub_trade.png")

	# 6. Hub Skills (Airship Facilities)
	main.hub._switch_tab("skills")
	if main.hub.has_method("_skills_show"):
		main.hub._skills_show("airship")
	await wait(0.5)
	await shot("hd2_04_hub_skills.png")

	# 7. Hub Deploy (World Map & Sortie Setup)
	main.hub._switch_tab("deploy")
	await wait(0.5)
	await shot("hd2_05_hub_deploy.png")

	# 8. English Localization Check (Stash)
	Loc.set_lang("en", false)
	await wait(0.8)
	await frames(4)
	main.hub._switch_tab("stash")
	await wait(0.5)
	await frames(4)
	if not main.hub.stash_ids.is_empty():
		var eidx: int = maxi(0, main.hub.stash_ids.find("arm_amr"))
		main.hub.stash_list.select(eidx)
		main.hub._on_stash_selected(eidx)
	await wait(0.4)
	await frames(4)
	await shot("hd2_08_hub_en.png")
	Loc.set_lang("zh", false)
	await wait(0.6)
	await frames(4)

	# 9. Raid HUD + Radio Window
	var raid = await deploy({
		"core": "core_heavy",
		"legs": "legs_biped_scout",
		"arm_l": "arm_ac30",
		"arm_r": "arm_sniper",
		"back": "back_missile",
		"gen": "gen_reactor",
	})
	if not check(raid != null, "deploy failed"):
		return
	Events.extract_cancelled.emit("撤离点 A")
	await wait(0.8)
	await shot("hd2_06_raid_hud.png")

	# 10. Raid Inventory (Multi-cell cargo + 6-slot cards + Inspector)
	raid.mech.cargo.clear()
	for cid: String in [
		"arm_amr", "legs_quad", "core_heavy", "arm_shotgun", "back_missile",
		"gen_crystal", "fuel_cell", "repair_kit", "hdd", "bug_crystal",
		"gold", "extract_flare",
	]:
		raid.mech.cargo.append(cid)
	raid.hud.open_loot(null)
	await frames(3)
	raid.hud.loot_panel._on_cargo_selected(0)
	await wait(0.4)
	await shot("hd2_07_raid_inv.png")
	raid.hud.close_loot()
	await frames(2)
