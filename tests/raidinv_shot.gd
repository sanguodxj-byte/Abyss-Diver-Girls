extends "res://tests/lib/test_base.gd"
## 行动内背包截图：出击后往货舱塞几件物品并打开背包界面 → review/raidinv_bag.png
const START := "hub"


func run() -> void:
	var raid = await deploy({"core": "core_heavy", "legs": "legs_quad", "arm_l": "arm_mg", "arm_r": "arm_laser", "back": "back_cargo", "gen": "gen_crystal"})
	if not check(raid != null, "出击失败"):
		return
	Story.set_process(false)
	Story.data = {}
	get_tree().paused = false
	for id in ["repair_kit", "beacon", "can_food", "water_tab", "coffee", "fuel_cell", "fuel_cell", "arm_shotgun", "SG7_shotgun"]:
		GameData.cargo.append(id)
	raid.hud.toggle_inventory()
	await wait(0.6)
	await shot("raidinv_bag.png")
	raid.hud.toggle_inventory()
	log_line("raidinv_shot ok")
