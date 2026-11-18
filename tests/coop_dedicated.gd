extends "res://tests/lib/test_base.gd"
## Client verification against a real --server headless dedicated server process.
const START := "none"
const TIMEOUT := 120

var host := "127.0.0.1"
var port := 28947

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--host="):
			host = arg.substr(7)
		elif arg.begins_with("--port="):
			port = int(arg.substr(7))
	GameData.quality = 0
	GameData.loadout = GameData.STARTER.duplicate()
	GameData.cargo = ["repair_kit", "beacon"]
	await wait_real(0.5)
	if not check(Net.join("专服测试员", host, port, "") == OK, "连接专服失败"):
		return
	if not await _wait_for(func(): return Net.state == "lobby" and Net.dedicated, "未能进入专服大厅", 15.0):
		return
	if not check(Net.leader_id() == Net.local_id(), "单人进专服未成为队长"):
		return
	Net.ready_up(true)
	if not await _wait_for(func(): return Net.state == "raid" and main.raid != null, "专服自动出击失败", 60.0):
		return
	var r = main.raid
	if not check(r.coop != null and r.coop.units.size() == 1, "专服单位数错误"):
		return
	if not await _wait_for(func(): return r.coop._received > 0 and r.coop.entities.size() > 50, "专服快照/实体同步失败", 15.0):
		return
	var m = r.mech
	var start_pos: Vector3 = m.position
	var start_ammo: int = m.ammo.arm_l
	Input.action_press("move_up")
	Input.action_press("fire_left")
	await wait_real(0.8)
	Input.action_release("move_up")
	Input.action_release("fire_left")
	if not await _wait_for(func(): return m.position.distance_to(start_pos) > 0.3 and m.ammo.arm_l < start_ammo, "专服未响应移动/开火输入", 10.0):
		return
	log_line("dedicated server client movement=%.2fm ammo=%d->%d" % [m.position.distance_to(start_pos), start_ammo, m.ammo.arm_l])
	Net.leave()
	await wait_real(0.4)
	log_line("dedicated server e2e passed")

func _wait_for(cond: Callable, desc: String, seconds := 30.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while not cond.call() and Time.get_ticks_msec() < end:
		await get_tree().process_frame
	return check(cond.call(), desc + " (state=%s err=%s)" % [Net.state, Net.last_error])
