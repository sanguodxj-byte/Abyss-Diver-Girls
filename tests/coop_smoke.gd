extends "res://tests/lib/test_base.gd"
## Real ENet sockets and separate processes. Host test code arranges fixtures;
## client input, inventory transactions, snapshots and result delivery use production RPCs.
const START := "none"
const TIMEOUT := 180
var role := "host"
var port := 28847
var count := 2
var phase := ""
var remote := 0

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.substr(7)
		if arg.begins_with("--port="): port = int(arg.substr(7))
		if arg.begins_with("--count="): count = int(arg.substr(8))
	GameData.quality = 0
	GameData.loadout = GameData.STARTER.duplicate()
	GameData.cargo = ["repair_kit", "beacon", "arm_shotgun"]
	Net.notice.connect(func(t):
		if t.begins_with("TEST:"): phase = t.substr(5))
	if role == "host": await _host_run()
	else: await _client_run()

func _wait_for(cond: Callable, description: String, seconds := 45.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while not cond.call() and Time.get_ticks_msec() < end:
		await get_tree().process_frame
	return check(cond.call(), description + "（state=%s phase=%s）" % [Net.state, phase])

func _stage(value: String) -> void:
	phase = value
	log_line("stage " + value)
	for id in Net.players:
		if id != 1: _test_stage.rpc_id(id, value)

@rpc("authority", "call_remote", "reliable")
func _test_stage(value: String) -> void:
	phase = value

func _host_run() -> void:
	if not check(Net.host("房主", port, "coop-test") == OK, "建房失败"): return
	if not await _wait_for(func(): return Net.players.size() == count, "队员未加入"): return
	Net.ready_up(true)
	if not await _wait_for(func(): return Net.can_launch(), "准备同步失败"): return
	Net.launch()
	if not await _wait_for(func(): return Net.state == "raid" and main.raid != null, "同步加载失败", 90): return
	var r = main.raid
	var c = r.coop
	if not check(c.units.size() == count, "房主玩家数量错误"): return
	for id in c.units:
		if id != 1: remote = id
	# Disable random danger only in this deterministic test, preserving actual collision/movement.
	r.factions.set_physics_process(false)
	for n in get_tree().get_nodes_in_group("bugs") + get_tree().get_nodes_in_group("nests") + get_tree().get_nodes_in_group("npc_mechs"):
		n.set_physics_process(false)
	await wait_real(1.0)
	var m = c.units[remote]
	var start: Vector3 = m.position
	var shots := [0]
	m.fired.connect(func(_s: String): shots[0] += 1)
	_stage("move")
	if not await _wait_for(func(): return m.position.distance_to(start) > 0.5 and shots[0] > 0, "客户端移动/开火未由房主执行", 12): return
	log_line("remote moved %.2fm, shots=%d energy=%.1f" % [m.position.distance_to(start), shots[0], m.energy])
	await wait_real(1.0)
	_stage("idle")
	await wait_real(0.5)
	# A shared crate. Every client opens it and submits two identical requests.
	var box = r._place_box("supply", Vector3(start.x + 2, 0, start.z), ["circuit"])
	box.revealed = 1
	for id in c.units:
		c.units[id].position = start + Vector3(-1.2 if id == 1 else 1.2, 0, 0)
		c.units[id].velocity = Vector3.ZERO
		c.units[id].shield_time = 999
	c._sync_entities()
	_stage("loot")
	if not await _wait_for(func(): return box.items.is_empty(), "搜刮请求未提交", 15): return
	await wait_real(0.6)
	var total := 0
	for unit in c.units.values(): total += unit.cargo.count("circuit")
	if not check(total == 1, "重复/并发领取复制了物品"): return
	log_line("shared crate conservation passed; exactly one circuit")
	await shot("coop_battle_host.png")
	_stage("close")
	if not await _wait_for(func(): return m.loadout.arm_r == "arm_shotgun", "队员未完成跨区前换装", 8): return
	# Nearby remote has to take actual damage and receive personal authoritative HP.
	m.shield_time = 0
	var before: float = m.hp
	m.take_damage(20)
	if not check(m.hp < before, "队员不能受伤"): return
	_stage("health")
	await wait_real(0.8)
	# All surviving humans must regroup before a map transition.
	var edge: String = r.world_link.gates.keys()[0]
	var next_map: String = r.world_link.gates[edge].to
	for unit in c.units.values():
		unit.position = r.world_link.gates[edge].center + r.world_link._inward(edge) * 4
		unit.velocity = Vector3.ZERO
	var hp_saved: float = m.hp
	_stage("transit")
	if not await _wait_for(func(): return Net.state == "raid" and main.raid.map_id == next_map, "全队跨区失败", 90): return
	r = main.raid
	c = r.coop
	m = c.units[remote]
	if not check(absf(m.hp - hp_saved) < 0.01, "跨区生命值丢失"): return
	if not check(m.loadout.arm_r == "arm_shotgun", "跨区丢失队员战地换装"): return
	for n in get_tree().get_nodes_in_group("bugs") + get_tree().get_nodes_in_group("nests") + get_tree().get_nodes_in_group("npc_mechs"):
		n.set_physics_process(false)
	r.factions.set_physics_process(false)
	_stage("extract")
	for id in c.units:
		var unit = c.units[id]
		unit.shield_time = 999
		unit.position = r.extracts[0].position + Vector3(0, 0.3, 0)
		unit.velocity = Vector3.ZERO
	if not await _wait_for(func(): return main.result_layer != null, "独立撤离结算未完成", 20): return
	if not check(GameData.extracts_ok == 1 and not GameData.loadout.is_empty(), "房主撤离装备未保存"): return
	main.show_hub()
	if not await _wait_for(func(): return Net.state == "lobby", "结算后不能再次组队", 15): return
	_stage("done")
	await wait_real(0.5)
	Net.leave()
	log_line("real %d-process co-op passed" % count)

func _client_run() -> void:
	await wait_real(0.6)
	if not check(Net.join("队员" + role, "127.0.0.1", port, "coop-test") == OK, "创建连接失败"): return
	if not await _wait_for(func(): return Net.state == "lobby" and Net.players.size() == count, "加入房间失败"): return
	# Roster changes invalidate readiness. Wait for final roster before readying.
	Net.ready_up(true)
	if not await _wait_for(func(): return Net.state == "raid" and main.raid != null, "同步加载失败", 90): return
	if not check(GameData.loadout.is_empty() and GameData.cargo.is_empty(), "出击物资没有锁定"): return
	if not await _wait_for(func(): return phase == "move", "缺少移动阶段"): return
	var r = main.raid
	if not check(r.coop.units.size() == count, "玩家数量不同步"): return
	if not await _wait_for(func(): return r.coop._received > 0 and r.coop.entities.size() > 100, "实体或快照未复制"): return
	Input.action_press("move_up")
	Input.action_press("fire_left")
	await wait_real(0.8)
	Input.action_release("move_up")
	Input.action_release("fire_left")
	if not await _wait_for(func(): return phase == "loot", "缺少搜刮阶段"): return
	await wait_real(0.4)
	var box = r.nearest_box(3.6)
	if not check(box != null, "共享容器未复制"): return
	r.open_container(box)
	if not await _wait_for(func(): return r.open_box != null and r.open_box.revealed > 0, "容器内容未复制", 8): return
	var request: Dictionary = r.coop.make_command("take", [0])
	Net._command.rpc_id(1, Net.mission, request)
	await wait_real(0.04)
	Net._command.rpc_id(1, Net.mission, request)
	if not await _wait_for(func(): return phase == "close", "服务器未确认货物守恒", 10): return
	r.close_box()
	await _wait_for(func(): return not r.hud.inv_open(), "搜刮面板未关闭", 5)
	r.equip_from_cargo(r.mech.cargo.find("arm_shotgun"), "arm_r")
	if not await _wait_for(func(): return r.mech.loadout.arm_r == "arm_shotgun", "客户端换装未同步", 8): return
	await frames(4)
	await shot("coop_battle_client.png")
	if not await _wait_for(func(): return phase == "health", "未测试伤害", 8): return
	await wait_real(0.3)
	if not check(r.mech.hp <= r.mech.max_hp, "生命值状态异常"): return
	var old_map: String = r.map_id
	if not await _wait_for(func(): return Net.state == "raid" and main.raid.map_id != old_map, "客户端跨区失败", 90): return
	if not await _wait_for(func(): return main.result_layer != null, "客户端未收到结算", 25): return
	if not check(GameData.extracts_ok == 1 and not GameData.loadout.is_empty(), "客户端撤离装备未保存"): return
	var funds: int = GameData.money
	# Reliable duplicate delivery must not credit inventory or money twice.
	Net._deliver_result(Net.mission, {"success": true})
	if not check(GameData.money == funds and GameData.extracts_ok == 1, "结算重复入账"): return
	main.show_hub()
	if not await _wait_for(func(): return phase == "done", "未完成房间返回", 15): return
	Net.leave()
	log_line("client movement, loot, transition, settlement passed")
