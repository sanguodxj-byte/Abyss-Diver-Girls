extends Node
## 局外成长的状态容器（存档分区 "progress"）。设施升级、研究、驾驶员成长、船员好感度、章节解锁由局外成长系统
## 在 scripts\progression 下另写脚本实现：对机甲数值的影响用 GameData.add_stat_hook，商品与战区解锁用
## GameData.add_shop_filter / add_map_filter，结算奖励订阅 Events.raid_finished（此时尚未存档，改动会随结算一起保存）。

var state := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameData.register_section("progress", _save_state, _load_state)


func _save_state() -> Dictionary:
	return state.duplicate(true)


func _load_state(d: Dictionary) -> void:
	state = d.duplicate(true)
