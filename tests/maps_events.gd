extends "res://tests/lib/test_base.gd"
## 局内动态事件与地图解锁：沙暴周期、空投补给 / 求救信号 / 坠落货柜、中继塔军械箱、档案图鉴。
## godot --headless --path . -- --maps_events

const START := "none"
const RaidScript = preload("res://scripts/raid.gd")

var raid
var seen := {}


func _ready() -> void:
	if not InputMap.has_action("map"):
		InputMap.add_action("map")
	super._ready()


func run() -> void:
	await frames(2)
	Events.any.connect(func(e: String, _a): seen[e] = int(seen.get(e, 0)) + 1)
	# 尘土平原：沙暴换相 + 三种动态事件。直接拨动节点里的计时器，不靠真实等待。
	_begin("dustfield")
	raid.dropping = false
	raid.mech.input_locked = false
	await frames(2)
	var ev = raid.get_node_or_null("ext_events")
	var wt = raid.get_node_or_null("ext_weather")
	if not check(ev != null and wt != null, "缺少动态事件或天气节点"):
		return
	wt._cycle = 41.0
	await frames(2)
	if not check(seen.has("sandstorm"), "沙暴没有开始"):
		return
	wt._cycle = 25.0
	await frames(2)
	for k in 3:
		ev._launch(k)
		await frames(1)
		for f in ev._falling.duplicate():
			ev._land(f)
		ev._falling.clear()
		await frames(1)
	log_line("dustfield events=%s" % [seen])
	for k: String in ["supply_drop", "distress_signal", "cargo_crash"]:
		if not check(seen.has(k), "动态事件 %s 没有发生" % k):
			return
	if not check(int(seen.get("sandstorm", 0)) >= 2, "沙暴没有结束"):
		return
	_stop()
	await frames(4)
	# 铁锈工业带：打开中继塔终端，铅封箱换成真容器
	_begin("ironbelt")
	raid.dropping = false
	raid.mech.input_locked = false
	await frames(2)
	var term = _relay_terminal()
	if not check(term != null, "中继塔没有终端容器"):
		return
	var before := get_tree().get_nodes_in_group("lootboxes").size()
	raid.open_container(term)
	raid.close_box()
	await frames(3)
	var after := get_tree().get_nodes_in_group("lootboxes").size()
	log_line("relay boxes %d -> %d" % [before, after])
	if not check(after == before + 2, "终端没有解锁两只军械箱"):
		return
	# 档案物件：拾取即解锁同名图鉴条目
	Events.item_picked.emit("arch_duty_log", 1)
	await frames(1)
	if not check(Story.is_codex_unlocked("arch_duty_log"), "档案物件没有解锁图鉴"):
		return
	_stop()


func _begin(mid: String) -> void:
	GameData.map_id = mid
	raid = RaidScript.new()
	add_child(raid)
	raid.start(GameData.STARTER.duplicate(), [])


func _stop() -> void:
	if raid != null:
		raid.queue_free()
		raid = null


func _relay_terminal():
	var tp := Vector3.ZERO
	var unlocks: Array = raid.get_meta("poi_unlocks", [])
	if unlocks.is_empty():
		return null
	tp = unlocks[0].terminal
	var best = null
	var bd := 999.0
	for b in get_tree().get_nodes_in_group("lootboxes"):
		if not b.has_meta("poi") or str(b.get_meta("poi")) != "relay_tower":
			continue
		var d: float = b.global_position.distance_to(tp)
		if d < bd:
			bd = d
			best = b
	return best
