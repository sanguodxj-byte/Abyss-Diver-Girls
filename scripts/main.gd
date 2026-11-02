extends Node
## 流程：主菜单 → 机库 → 行动 → 结算 → 机库。
## 命令行带 --<名字>（不含 =）时加载 tests\<名字>.gd 作为测试节点，约定见 tests\lib\test_base.gd；
## 测试脚本的常量 START 决定先进入哪个界面："hub"（默认）、"menu"、"none"。

const HubScript = preload("res://scripts/hub.gd")
const MenuScript = preload("res://scripts/menu.gd")
const RaidScript = preload("res://scripts/raid.gd")
const ResultScript = preload("res://scripts/result_screen.gd")
const TEST_DIR := "res://tests"

var hub
var raid
var result_layer


func _ready() -> void:
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
	for p: String in tests:
		var c: Dictionary = (load(p) as Script).get_script_constant_map()
		if c.has("START"):
			start = str(c.START)
			break
	match start:
		"menu":
			show_menu()
		"none":
			pass
		_:
			show_hub()
	for p: String in tests:
		add_child(load(p).new())


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
	var after_raid: bool = result_layer != null or raid != null
	if result_layer:
		result_layer.queue_free()
		result_layer = null
	if raid:
		raid.queue_free()
		raid = null
	if hub and is_instance_valid(hub):
		hub.queue_free()
	hub = HubScript.new()
	add_child(hub)
	hub.deploy_requested.connect(start_raid)
	Events.returned_to_hub.emit(after_raid)


func start_raid() -> void:
	if GameData.can_deploy(GameData.loadout) != "":
		Audio.play_ui("ui_denied")
		return
	var carry: Array = GameData.cargo.duplicate()
	GameData.cargo.clear()
	GameData.raids += 1
	GameData.save_game()   # 出击即存档：中途退出游戏 = 失去机甲（防 SL）
	var lo: Dictionary = GameData.loadout.duplicate()
	GameData.loadout = {}
	GameData.save_game()
	hub.queue_free()
	hub = null
	raid = RaidScript.new()
	add_child(raid)
	raid.raid_ended.connect(_on_raid_ended)
	raid.start(lo, carry)
	Events.deployed.emit(raid.map_id, lo)


## 结算记账：成功带回货物与机甲（货币直接入账），失败全部失去；广播 raid_finished 后存档，再显示结算界面
func _on_raid_ended(r: Dictionary) -> void:
	get_tree().paused = false
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
	result_layer = ResultScript.new()
	add_child(result_layer)
	result_layer.setup(r)
	result_layer.back_requested.connect(show_hub)
