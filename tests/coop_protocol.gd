extends "res://tests/lib/test_base.gd"
const START := "none"
const P = preload("res://scripts/net/protocol.gd")

func run() -> void:
	for path in ["res://scripts/net/session.gd", "res://scripts/net/coop_raid.gd", "res://scripts/net/lobby.gd"]:
		var script = load(path)
		if not check(script != null and script.can_instantiate(), "脚本无法实例化：" + path): return
	if not check(P.equipment_error(GameData.STARTER, [], GameData) == "", "基础机架被拒绝"): return
	var bad: Dictionary = GameData.STARTER.duplicate()
	bad.core = "arm_mg"
	if not check(P.equipment_error(bad, [], GameData) != "", "跨槽位伪造装备未被拒绝"): return
	if not check(P.equipment_error(GameData.STARTER, ["unknown_item"], GameData) != "", "未知物品未被拒绝"): return
	if not check(not P.valid_input(Vector2(NAN, 0), Vector3.ZERO), "NaN 输入未被拒绝"): return
	if not check(not P.valid_input(Vector2.ZERO, Vector3(INF, 0, 0)), "无穷瞄准未被拒绝"): return
	if not check(P.player_name(" [队员]\n") == "队员", "昵称清理失败"): return
	var growth := P.growth_profile({"facilities": {"hangar": 9000}, "active_pilot": "missing", "research": ["unknown"], "pilots": {"nao": {"level": 99}}})
	if not check(growth.facilities.hangar == 5 and growth.active_pilot == "nao" and growth.research.is_empty() and growth.pilots.nao.level == 12, "成长数据边界失效"): return
	if not check(Net.host("测试", 0) == ERR_INVALID_PARAMETER and not Net.active(), "无效端口改变会话"): return
	if not check(Net.join("测试", "", 27847) == ERR_INVALID_PARAMETER, "空地址未被拒绝"): return
	Net.last_error = ""
	main.show_hub()
	main.show_lobby()
	await frames(3)
	if not check(main.get_node_or_null("CoopLobby") != null, "机库联机入口失效"): return
	await shot("coop_lobby.png")
	log_line("protocol validation and lobby passed")
