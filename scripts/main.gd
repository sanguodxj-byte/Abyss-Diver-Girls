extends Node
## 流程：主菜单 → 机库 → 行动 → 结算 → 机库。
## 命令行带 --<名字>（不含 =）时加载 tests\<名字>.gd 作为测试节点，约定见 tests\lib\test_base.gd；
## 测试脚本的常量 START 决定先进入哪个界面："hub"（默认）、"menu"、"none"。

const HubScript = preload("res://scripts/hub.gd")
const MenuScript = preload("res://scripts/menu.gd")
const RaidScript = preload("res://scripts/raid.gd")
const ResultScript = preload("res://scripts/result_screen.gd")
const LoadingScreenScript = preload("res://scripts/loading_screen.gd")
const TEST_DIR := "res://tests"

var hub
var raid
var result_layer
var _deploying := false
var _network_committed := false
var _network_result := false
var _accounted_result := {}


func _ready() -> void:
	Net.launch_requested.connect(_start_network_raid)
	Net.session_lost.connect(_network_lost)
	Net.result_received.connect(_network_finished)
	Net.personal_result_received.connect(_network_account)
	Loc.language_changed.connect(_on_language_changed)
	GameData.apply_quality(get_viewport())
	var names := _test_args()
	if names.is_empty():
		show_menu()
		return
	var tests: Array = []
	for n: String in names:
		var p := "%s/%s.gd" % [TEST_DIR, n]
		if ResourceLoader.exists(p):
			tests.append(p)
	if tests.is_empty():
		for n in names:
			print("[%s] FAIL 没有对应的测试脚本 tests/%s.gd" % [n, n])
		get_tree().quit(2)
		return
	var start := "hub"
	var loaded: Array[Script] = []
	for p: String in tests:
		var sc := load(p) as Script
		if sc == null or not sc.can_instantiate():
			print("[%s] FAIL 测试脚本编译失败：%s" % [p.get_file().get_basename(), p])
			get_tree().quit(2)
			return
		loaded.append(sc)
		var c: Dictionary = sc.get_script_constant_map()
		if start == "hub" and c.has("START"):
			start = str(c.START)
	match start:
		"menu":
			show_menu()
		"none":
			pass
		_:
			show_hub()
	for sc: Script in loaded:
		add_child(sc.new())


## 命令行里的 --<名字>；带 = 的是测试自己的选项（如 --view=solo0），不算测试名
func _test_args() -> Array:
	var out: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and not a.contains("="):
			out.append(a.substr(2))
	return out


var menu


func show_menu() -> void:
	menu = MenuScript.new()
	add_child(menu)
	Audio.play_music("menu", 1.5)
	menu.start_requested.connect(func():
		menu.queue_free()
		menu = null
		show_hub())


func show_hub() -> void:
	if Net.state == "results":
		Net.return_to_room()
	var after_raid: bool = result_layer != null or raid != null
	if result_layer:
		result_layer.queue_free()
		result_layer = null
	if raid:
		raid.queue_free()
		raid = null
	if hub and is_instance_valid(hub):
		if hub.get_parent():
			hub.get_parent().remove_child(hub)
		hub.queue_free()
	hub = HubScript.new()
	add_child(hub)
	hub.deploy_requested.connect(start_raid)
	Events.returned_to_hub.emit(after_raid)


func _on_language_changed(_lang: String) -> void:
	if menu != null and is_instance_valid(menu) and str(menu.title_lang) != _lang:
		menu.title_lang = _lang
		var reopen_m: bool = menu.settings_panel != null and menu.settings_panel.visible
		menu.call_deferred("_build_ui", reopen_m, "other")
	if raid != null and is_instance_valid(raid):
		return
	var room = get_node_or_null("CoopLobby")
	var reopen_lobby := false
	if room != null and is_instance_valid(room):
		reopen_lobby = bool(room.visible)
		remove_child(room)
		room.queue_free()
	if hub != null and is_instance_valid(hub):
		var keep_tab: String = str(hub.cur_tab)
		var reopen_settings: bool = hub.has_method("_settings_is_open") and bool(hub._settings_is_open())
		var settings_tab: String = str(hub.get_settings_tab()) if hub.has_method("get_settings_tab") else "other"
		show_hub()
		if keep_tab != "" and hub.has_method("_switch_tab"):
			hub._switch_tab(keep_tab)
		if reopen_settings and hub.has_method("_open_hub_settings"):
			hub._open_hub_settings(settings_tab)
	if reopen_lobby:
		show_lobby()


func start_raid() -> void:
	if Net.active():
		show_lobby()
		return
	if _deploying:
		return
	if GameData.can_deploy(GameData.loadout) != "":
		Audio.play_ui("ui_denied")
		return
	_deploying = true
	var carry: Array = GameData.cargo.duplicate()
	GameData.cargo.clear()
	GameData.raids += 1
	GameData.save_game()   # 出击即存档：中途退出游戏 = 失去机甲（防 SL）
	var lo: Dictionary = GameData.loadout.duplicate()
	GameData.loadout = {}
	GameData.save_game()
	if GameData.test_mode and not RaidScript.force_async_load:
		if hub and is_instance_valid(hub):
			hub.queue_free()
		hub = null
		raid = RaidScript.new()
		add_child(raid)
		raid.raid_ended.connect(_on_raid_ended)
		raid.start(lo, carry)
		Events.deployed.emit(raid.map_id, lo)
		_deploying = false
		return
	var loader = LoadingScreenScript.new()
	add_child(loader)
	loader.setup(GameData.map_id, lo)
	await loader.play_close(0.34)
	if hub and is_instance_valid(hub):
		hub.queue_free()
	hub = null
	raid = RaidScript.new()
	add_child(raid)
	raid.raid_ended.connect(_on_raid_ended)
	await raid.start_async(lo, carry, {}, loader)
	Events.deployed.emit(raid.map_id, lo)
	await loader.play_open(0.52)
	_deploying = false


## 结算记账：成功带回货物与机甲（货币直接入账），失败全部失去；广播 raid_finished 后存档，再显示结算界面
func _on_raid_ended(r: Dictionary) -> void:
	get_tree().paused = false
	_account_result(r)
	_show_result(r)


func _account_result(r: Dictionary) -> void:
	var gained_money := 0
	if r.success:
		GameData.extracts_ok += 1
		GameData.loadout = r.loadout
		for id in r.cargo:
			if GameData.item(id).cat == "money":
				gained_money += int(GameData.item(id).v)
			else:
				GameData.stash.append(id)
		GameData.money += gained_money
	r["gained_money"] = gained_money
	Events.raid_finished.emit(bool(r.success), r)
	GameData.save_game()


func _show_result(r: Dictionary) -> void:
	result_layer = ResultScript.new()
	add_child(result_layer)
	result_layer.setup(r)
	result_layer.back_requested.connect(show_hub)


func show_lobby() -> void:
	if get_node_or_null("CoopLobby") != null:
		get_node("CoopLobby").show_panel()
		return
	var lobby = load("res://scripts/net/lobby.gd").new()
	lobby.name = "CoopLobby"
	add_child(lobby)


func _start_network_raid(config: Dictionary) -> void:
	if _deploying:
		return
	_deploying = true
	var room = get_node_or_null("CoopLobby")
	if room: room.queue_free()
	var fresh: bool = config.transit.is_empty()
	var id := Net.local_id()
	var profile: Dictionary = config.roster[id]
	if fresh:
		# A ready loadout is a reservation. Never launch with stale or changed inventory.
		if GameData.loadout != profile.loadout or GameData.cargo != profile.cargo:
			_deploying = false
			Net.leave(Loc.t("准备后装备发生变化，请重新准备", "Loadout changed after ready—please ready up again"))
			return
		_network_committed = true
		_network_result = false
		_accounted_result = {}
		GameData.raids += 1
		GameData.cargo.clear()
		GameData.loadout = {}
		GameData.save_game()
	var lo: Dictionary = profile.loadout.duplicate()
	var carry: Array = profile.cargo.duplicate()
	var transit_state := {}
	if not fresh:
		var saved: Dictionary = config.transit.players[id]
		lo = saved.loadout.duplicate()
		carry = saved.cargo.duplicate()
		transit_state = {"edge": config.edge, "mech": saved, "time": config.transit.time, "kills": config.transit.kills,
			"start_cargo": saved.start, "visited": config.transit.visited, "seen": {}, "found_pois": {}, "allies": []}
	var loader = LoadingScreenScript.new()
	add_child(loader)
	loader.setup(config.map, lo)
	await loader.play_close(0.2)
	if not Net.active():
		loader.queue_free()
		_deploying = false
		return
	for old in [hub, raid, result_layer]:
		if is_instance_valid(old):
			old.get_parent().remove_child(old)
			old.queue_free()
	hub = null
	result_layer = null
	var keep_map: String = GameData.map_id
	Net.controller = null
	GameData.map_id = config.map
	raid = RaidScript.new()
	add_child(raid)
	# Synchronous construction occurs behind the loading curtain; all peers wait at a barrier.
	raid.start(lo, carry, transit_state)
	GameData.map_id = keep_map
	var coop = load("res://scripts/net/coop_raid.gd").new()
	raid.coop = coop
	raid.add_child(coop)
	coop.setup(raid, config)
	Events.deployed.emit(raid.map_id, lo)
	await loader.play_open(0.25)
	_deploying = false
	if Net.active(): Net.loaded()


func _network_finished(r: Dictionary) -> void:
	if _network_result:
		return
	_network_result = true
	_network_committed = false
	if is_instance_valid(raid):
		raid.ended = true
		raid.process_mode = Node.PROCESS_MODE_DISABLED
	if _accounted_result.is_empty(): _network_account(r)
	_show_result(_accounted_result)


func _network_account(r: Dictionary) -> void:
	if not _accounted_result.is_empty(): return
	_accounted_result = r.duplicate(true)
	_account_result(_accounted_result)


func _network_lost(reason: String) -> void:
	get_tree().paused = false
	if _network_committed and not _network_result:
		if not _accounted_result.is_empty():
			_network_finished(_accounted_result)
			return
		_network_finished({"success": false, "reason": reason if reason != "" else Loc.t("已离开联机，机甲与物资遗失", "Left co-op session; mech and cargo lost"), "cargo": [], "loadout": {}, "start_cargo": [],
			"kills": raid.kills if is_instance_valid(raid) else 0, "time": raid.time if is_instance_valid(raid) else 0, "map_id": raid.map_id if is_instance_valid(raid) else GameData.map_id})
