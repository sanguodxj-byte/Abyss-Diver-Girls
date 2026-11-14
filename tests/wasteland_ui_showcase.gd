extends "res://tests/lib/test_base.gd"
## 废土工业风 UI 实机截图展示（非 headless 下以 1920x1080 截取所有关键界面）

const START := "menu"
const TIMEOUT := 150.0


func run() -> void:
	if headless():
		log_line("skip wasteland_ui_showcase in headless")
		return

	Loc.set_lang("zh")
	await wait_real(1.2)
	await frames(6)
	await shot("wui_00_menu.png")

	# 准备一套标准测试机体与货舱样例以便完整展示所有 UI 组件
	GameData.new_game()
	GameData.money = 128500
	GameData.loadout = {
		"core": "core_std",
		"legs": "legs_biped",
		"arm_l": "arm_hmg",
		"arm_r": "arm_slug",
		"back": "back_shield",
		"gen": "gen_diesel",
	}
	for id: String in ["fuel_cell", "repair_kit", "repair_kit", "beacon", "scrap_alloy", "circuit_old", "arm_sniper", "arm_gatling"]:
		if GameData.ITEMS.has(id) or GameData.MODULES.has(id):
			GameData.stash.append(id)
	for id: String in ["fuel_cell", "repair_kit", "beacon"]:
		if GameData.ITEMS.has(id):
			GameData.cargo.append(id)
	var lo_saved: Dictionary = GameData.loadout.duplicate()

	main.show_hub()
	await wait_real(0.4)
	await frames(6)
	await shot("wui_01_hub_maint.png")

	if main.hub != null and main.hub.has_method("_switch_tab"):
		main.hub._switch_tab("stash")
		await frames(6)
		if main.hub.get("stash_list") != null and not main.hub.stash_ids.is_empty():
			main.hub.stash_list.select(0)
			main.hub._on_stash_selected(0)
			await frames(4)
		await shot("wui_02_hub_stash.png")

		main.hub._switch_tab("trade")
		await frames(6)
		await shot("wui_03_hub_trade.png")

		main.hub._switch_tab("skills")
		await frames(6)
		await shot("wui_04_hub_skills.png")

		main.hub._switch_tab("deploy")
		await frames(6)
		await shot("wui_05_hub_deploy.png")

	var r: Node = await deploy(GameData.loadout)
	if not check(r != null, "deploy failed"):
		return
	await wait_real(1.0)
	await frames(6)
	await shot("wui_06_raid_hud.png")

	if r.hud != null and r.hud.has_method("toggle_inventory"):
		r.hud.toggle_inventory()
		await frames(8)
		await shot("wui_07_raid_inv.png")
		r.hud.toggle_inventory()
		await frames(4)

	GameData.loadout = lo_saved.duplicate()
	Loc.set_lang("en")
	main.show_hub()
	await wait_real(0.3)
	await frames(8)
	await shot("wui_08_hub_en.png")
	Loc.set_lang("zh")
