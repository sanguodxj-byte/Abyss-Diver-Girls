extends "res://tests/lib/test_base.gd"
const START := "none"

func run() -> void:
	for id: String in GameData.ITEMS:
		if not check(not id.begins_with("mag_"), "不得存在实体弹匣物品: " + id): return
	for weapon in ["mg", "autocannon", "cannon", "shotgun", "sniper", "launcher", "flamer"]:
		var spec: Dictionary = GameData.AMMO[weapon]
		if not check(GameData.weapon_uses_ammo(weapon) and spec.mag > 0 and spec.reload > 0.0, "必须保留有限连续发数和装填时间: " + weapon): return
	for id: String in GameData.SHOP:
		if not check(not id.begins_with("mag_"), "商店不应出售实体弹匣"): return
	for entry: Dictionary in GameData.LOOT_TABLES.values():
		for id: String in entry.pool:
			if not check(not id.begins_with("mag_"), "战利品不应生成实体弹匣"): return
	# 真正读写隔离存档，验证已购旧弹匣退款且不重复补偿。
	var d: Dictionary = GameData._payload()
	d.money = 1000
	d.stash = ["mag_sniper", "repair_kit"]
	d.cargo = ["mag_mg", "mag_mg", "fuel_cell"]
	GameData._write_payload(GameData.save_path, d)
	if not check(GameData.load_game(), "迁移存档载入失败"): return
	if not check(GameData.money == 2932 and GameData.stash == ["repair_kit"] and GameData.cargo == ["fuel_cell"], "旧弹匣应等值返还信用点并移除"): return
	GameData.save_game()
	GameData.load_game()
	check(GameData.money == 2932, "重复载入不得重复退款")
