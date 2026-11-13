extends "res://tests/coop_smoke.gd"
## Independent socket checks for rejected handshakes, authority, upgrades,
## personal settlement before host loss, reconnect and participant death.

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.substr(7)
		if arg.begins_with("--port="): port = int(arg.substr(7))
	GameData.quality = 0
	Net.notice.connect(func(t):
		if t.begins_with("TEST:"): phase = t.substr(5))
	if role == "host": await _resilient_host()
	else: await _resilient_client()

func _prepare() -> void:
	GameData.loadout = GameData.STARTER.duplicate()
	GameData.cargo = ["beacon", "repair_kit", "sonic_decoy", "extract_barrier", "extract_flare"]

func _quiet(r) -> void:
	r.factions.set_physics_process(false)
	for n in get_tree().get_nodes_in_group("bugs") + get_tree().get_nodes_in_group("nests") + get_tree().get_nodes_in_group("npc_mechs"):
		n.set_physics_process(false)
	for m in r.coop.units.values(): m.shield_time = 999

func _resilient_host() -> void:
	_prepare()
	if not check(Net.host("房主", port, "coop-test") == OK, "创建房间失败"): return
	if not await _wait_for(func(): return Net.players.size() == 2, "握手验证后未加入", 25): return
	Net.ready_up(true)
	if not await _wait_for(func(): return Net.can_launch(), "准备失败"): return
	Net.launch()
	if not await _wait_for(func(): return Net.state == "raid", "出击失败", 90): return
	var r = main.raid
	_quiet(r)
	for id in r.coop.units:
		if id != 1: remote = id
	var m = r.coop.units[remote]
	if not check(absf(m.max_hp - r.mech.max_hp - 25.0) < 0.01, "客户端机库升级未独立计算"): return
	log_line("remote progression derived by host: +25 HP")
	var original_hp: float = r.mech.hp
	_stage("authority")
	await wait_real(1.2)
	if not check(r.mech.hp == original_hp and r.coop.contexts[remote].result.is_empty(), "客户端伪造改变了主机状态"): return
	# A real client menu must not freeze the world, including the local host menu.
	var before: float = r.time
	r.hud.toggle_pause()
	await wait_real(0.6)
	if not check(not get_tree().paused and r.time > before, "房主菜单冻结世界"): return
	r.hud.toggle_pause()
	# Real projectiles from a remote player hit a server-owned enemy and count one kill.
	var combat_pos := Vector3(700, 0.2, 700)
	r._static_box(Vector3(40, 1, 40), combat_pos - Vector3(0, 0.7, 0), Color.GRAY)
	m.position = combat_pos
	m.velocity = Vector3.ZERO
	var enemy = r.spawn_bug("beetle", combat_pos + Vector3(0, 0.5, -7.0), 10000)
	enemy.hp = 30
	enemy.set_physics_process(false)
	var kills_before: int = r.kills
	r.coop._sync_entities()
	_stage("combat")
	await wait_real(2.0)
	log_line("combat hp=%.1f ammo=%d locked=%s fire=%d aim=%s" % [enemy.hp if is_instance_valid(enemy) else 0, m.ammo.arm_l, m.input_locked, m.net_fire, m.aim_point])
	if not await _wait_for(func(): return r.kills > kills_before, "远端真实子弹没有造成击杀", 12): return
	if not check(r.kills == kills_before + 1, "击杀重复计数"): return
	log_line("remote projectile damage and shared kill passed")
	_stage("stop_fire")
	await wait_real(0.3)
	# Real client equipment swap and consumable request.
	var pos: Vector3 = m.position
	var box = r._place_box("military", Vector3(pos.x + 2, 0, pos.z), ["arm_shotgun", "energy_rod"])
	box.revealed = 2
	m.energy = m.max_energy * 0.5
	r.coop._sync_entities()
	_stage("equipment")
	if not await _wait_for(func(): return m.loadout.arm_r == "arm_shotgun", "战地换装未同步", 12): return
	if not check(r.mech.loadout.arm_r == "arm_mg", "队员换装改变了房主装备"): return
	if not await _wait_for(func(): return not box.items.has("energy_rod"), "容器道具未由房主消耗", 12): return
	if not check(m.energy > m.max_energy * 0.5, "使用道具未恢复能源"): return
	_stage("devices")
	if not await _wait_for(func(): return not m.cargo.has("sonic_decoy") and not m.cargo.has("extract_barrier"), "远端部署道具未消耗", 10): return
	await wait_real(0.5)
	_stage("transport")
	if not await _wait_for(func(): return r.transport_state == "incoming", "客户端信标请求失败", 10): return
	if not check(not m.cargo.has("beacon") and r.mech.cargo.has("beacon"), "信标扣除归属错误"): return
	# Remote-only extraction is durably saved while the host keeps playing.
	m.position = r.extracts[0].position + Vector3(0, 0.3, 0)
	m.velocity = Vector3.ZERO
	_stage("solo_extract")
	if not await _wait_for(func(): return r.extracts[0].need < 8.0, "队员烟幕没有作用于自己的撤离区", 6): return
	if not await _wait_for(func(): return not r.coop.contexts[remote].result.is_empty(), "队员独立撤离失败", 15): return
	if not check(Net.state == "raid" and not r.ended and r.coop.contexts[1].result.is_empty(), "队员撤离提前结束全队"): return
	await wait_real(1.2)
	Net.leave("测试房主离线")
	if not check(main.result_layer != null and GameData.extracts_ok == 0, "未撤离房主错误获利"): return
	main.show_hub()
	_prepare()
	if not check(Net.host("房主重建", port, "coop-test") == OK, "不能重建房间"): return
	if not await _wait_for(func(): return Net.players.size() == 2, "队员重连失败", 25): return
	Net.ready_up(true)
	if not await _wait_for(func(): return Net.can_launch(), "重建后准备失败"): return
	Net.launch()
	if not await _wait_for(func(): return Net.state == "raid", "第二次出击失败", 90): return
	r = main.raid
	_quiet(r)
	r.mech.shield_time = 0
	r.mech.take_damage(999999)
	if not check(Net.state == "raid" and not r.ended, "房主死亡冻结存活队员"): return
	_stage("host_dead")
	if not await _wait_for(func(): return Net.players.size() == 1 and main.result_layer != null, "最后队员离开后不结算", 15): return
	Net.leave()
	log_line("handshake, authority, inventory, independent settlement, reconnect and death passed")

func _resilient_client() -> void:
	_prepare()
	Progress.state.facilities["hangar"] = 5
	await wait_real(0.6)
	Net.join("队员", "127.0.0.1", port, "wrong")
	if not await _wait_for(func(): return Net.state == "offline", "错误口令未拒绝", 10): return
	if not check(Net.last_error.contains("口令"), "没有口令错误提示"): return
	await wait_real(0.5)
	var build := Net.fingerprint()
	Net._fingerprint = "incompatible"
	Net.join("队员", "127.0.0.1", port, "coop-test")
	if not await _wait_for(func(): return Net.state == "offline", "不兼容版本未拒绝", 10): return
	if not check(Net.last_error.contains("版本"), "没有版本错误提示"): return
	Net._fingerprint = build
	await wait_real(0.5)
	Net.join("队员", "127.0.0.1", port, "coop-test")
	if not await _wait_for(func(): return Net.state == "lobby", "正确握手失败"): return
	Net.ready_up(true)
	if not await _wait_for(func(): return Net.state == "raid", "出击失败", 90): return
	if not await _wait_for(func(): return phase == "authority", "缺少权限检查阶段"): return
	var r = main.raid
	# Non-finite intent, unknown command, stale epoch, and negative index are rejected.
	Net._receive_input.rpc_id(1, Net.mission, 1000000, Vector2(NAN, 0), Vector3.ZERO, 3, false)
	Net._command.rpc_id(1, Net.mission, {"action": "take_damage", "args": [999999]})
	await wait_real(0.06)
	Net._command.rpc_id(1, Net.mission - 1, {"action": "abandon", "args": []})
	await wait_real(0.06)
	Net._command.rpc_id(1, Net.mission, {"action": "discard", "args": [-1]})
	var start: float = r.time
	r.hud.toggle_pause()
	await wait_real(0.5)
	if not check(not get_tree().paused and r.time > start, "客户端菜单冻结同步"): return
	r.hud.toggle_pause()
	r.hud.toggle_inventory()
	r.hud.toggle_inventory()
	await wait_real(0.1)
	if not check(not r.hud.inv_open() and not r.mech.input_locked, "无容器背包不能关闭"): return
	if not await _wait_for(func(): return phase == "combat", "缺少实弹阶段"): return
	if not await _wait_for(func(): return r.mech.position.x > 690, "战斗位置未同步"): return
	r.aim_override = r.mech.position + Vector3(0, 1.8, -12.0)
	Input.action_press("fire_left")
	if not await _wait_for(func(): return phase == "stop_fire", "客户端击杀未确认", 12): return
	Input.action_release("fire_left")
	if not await _wait_for(func(): return phase == "equipment", "缺少装备阶段"): return
	await wait_real(0.4)
	r.open_container(r.nearest_box(3.6))
	if not await _wait_for(func(): return r.open_box != null and r.open_box.items.has("arm_shotgun"), "未获取装备箱"): return
	r.equip_from_box(r.open_box.items.find("arm_shotgun"), "arm_r")
	if not await _wait_for(func(): return r.mech.loadout.arm_r == "arm_shotgun", "客户端换装外观不同步"): return
	await wait_real(0.1)
	r.use_from_box(r.open_box.items.find("energy_rod"))
	if not await _wait_for(func(): return phase == "devices", "缺少道具阶段"): return
	r.close_box()
	await wait_real(0.1)
	r.mech.use_item("sonic_decoy")
	r.mech.use_item("extract_barrier")
	if not await _wait_for(func(): return r.coop.descriptors.values().any(func(d): return d.get("kind", "") == "decoy") and r.coop.descriptors.values().any(func(d): return d.get("kind", "") == "barrier"), "部署道具未复制", 8): return
	if not await _wait_for(func(): return phase == "transport", "缺少运输阶段"): return
	r.close_box()
	await wait_real(0.1)
	r.call_transport()
	if not await _wait_for(func(): return phase == "solo_extract" and r.extract_target != null, "撤离区状态未同步", 8): return
	r.mech.use_item("extract_flare")
	if not await _wait_for(func(): return not Net.local_result.is_empty(), "个人撤离未结算", 20): return
	if not check(GameData.extracts_ok == 1 and GameData.loadout.arm_r == "arm_shotgun", "撤离没有即时保存新装备"): return
	if not await _wait_for(func(): return Net.state == "offline" and main.result_layer != null, "房主断开未回到结算", 20): return
	if not check(GameData.extracts_ok == 1 and GameData.loadout.arm_r == "arm_shotgun", "房主掉线覆盖了已成功结算"): return
	main.show_hub()
	_prepare()
	await wait_real(0.8)
	Net.join("队员重连", "127.0.0.1", port, "coop-test")
	if not await _wait_for(func(): return Net.state == "lobby", "重连失败", 15): return
	Net.ready_up(true)
	if not await _wait_for(func(): return Net.state == "raid", "重连后出击失败", 90): return
	if not await _wait_for(func(): return phase == "host_dead", "缺少房主死亡阶段"): return
	await wait_real(0.3)
	if not check(not main.raid.ended and not main.raid.mech.dead, "房主死亡结束客户端模拟"): return
	Net.leave("测试队员掉线")
	if not check(main.result_layer != null and GameData.loadout.is_empty() and GameData.extracts_ok == 1, "未撤离队员掉线没有失败结算"): return
	log_line("password/version rejection, RPC checks, reconnect and durable personal loot passed")
