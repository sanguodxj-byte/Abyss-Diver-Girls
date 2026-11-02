extends Node
## 事件总线：游戏里发生的事都从这里广播，剧情、通讯、成长、音频各自订阅，发出方不知道谁在听。
## 每个具名信号发出后，会再以 any(event, args) 广播一次（args 是「参数名 -> 值」字典），
## 便于按数据（事件名 + 条件）匹配触发；参数名用 args_of(事件名) 查询。
## 新内容需要的一次性事件不必改本文件：emit_custom("事件名", {参数}) 走 custom 信号，
## 在 any 上以它自己的事件名广播。

# ---- 出击与空投 ----
signal deployed(map_id: String, loadout: Dictionary)            ## 出击：行动场景生成完毕、空投开始
signal drop_landed(pos: Vector3)                                ## 空投着陆冲击
# ---- 搜刮 ----
signal box_opened(kind: String, pos: Vector3)                   ## 打开容器（kind = 掉落表 id）
signal item_revealed(item_id: String, rarity: int)              ## 容器里的物品逐个显现
signal item_picked(item_id: String, rarity: int)                ## 物品放进货舱
signal cargo_full(item_id: String)                              ## 货舱装不下，拾取被拒
signal overload_changed(overloaded: bool, speed_factor: float)  ## 进入 / 解除超载减速
# ---- 战斗 ----
signal enemy_seen(kind: String, first_ever: bool, pos: Vector3) ## 本次行动第一次遇到某种敌人；first_ever = 存档里从未遇到过
signal enemy_killed(kind: String, pos: Vector3)                 ## 击杀
signal nest_destroyed(pos: Vector3)                             ## 摧毁虫巢
signal combat_changed(in_combat: bool)                          ## 进入 / 脱离交战
signal player_damaged(amount: float, hp: float, max_hp: float)  ## 机甲受伤（护盾挡下的不算）
signal part_destroyed(slot: String)                             ## 某个部位完好度归零
signal skill_used(key: String, skill_id: String)                ## 释放技能：key = space / f / e / r
signal item_used(item_id: String)                               ## 使用消耗品（含发射呼叫信标）
# ---- 能源 ----
signal energy_low(seconds_left: float)                          ## 剩余能源低于 45 秒（回到 60 秒以上后可再次触发）
signal emergency_entered()                                      ## 能源耗尽，进入应急模式
signal emergency_exited()                                       ## 应急模式中恢复了能源（瘫痪不算）
# ---- 撤离 ----
signal extract_started(zone_title: String, need: float, is_transport: bool)
signal extract_cancelled(zone_title: String)
signal extract_completed(zone_title: String, is_transport: bool)
signal transport_called(pos: Vector3, eta: float)
signal transport_landed(pos: Vector3, wait: float)
signal transport_departed()                                     ## 运输机等不到人，起飞离开
# ---- 地图 ----
signal poi_discovered(poi_id: String, title: String, pos: Vector3)
signal district_entered(district: String)
# ---- Boss（由敌人系统发出） ----
signal boss_appeared(boss_id: String, title: String)
signal boss_phase_changed(boss_id: String, phase: int)
signal boss_defeated(boss_id: String)
# ---- 结束与局外 ----
signal mech_destroyed(reason: String)                           ## 机甲瘫痪或结构损毁的瞬间
signal raid_finished(success: bool, result: Dictionary)         ## 行动结束，结算数据已写入 GameData、尚未存档
signal returned_to_hub(after_raid: bool)                        ## 进入机库（从主菜单进入时 after_raid = false）
signal request_fulfilled(request: Dictionary)                   ## 提交后勤委托
# ---- 剧情 ----
signal flag_changed(flag: String, value: Variant)
signal codex_unlocked(entry_id: String)
signal chapter_changed(chapter_id: String)
# ---- 通用 ----
signal custom(event: String, data: Dictionary)
signal any(event: String, args: Dictionary)

var _args := {}   ## 信号名 -> 参数名列表


func _ready() -> void:
	for s in get_script().get_script_signal_list():
		var n: String = s.name
		var names: Array = []
		for a in s.args:
			names.append(str(a.name))
		_args[n] = names
		if n == "any":
			continue
		match names.size():
			0: connect(n, _r0.bind(n))
			1: connect(n, _r1.bind(n))
			2: connect(n, _r2.bind(n))
			3: connect(n, _r3.bind(n))
			_: push_error("事件 %s 的参数超过 3 个，any 不会转发它" % n)


func emit_custom(event: String, data := {}) -> void:
	custom.emit(event, data)


## 事件的参数名列表；未知事件返回空数组
func args_of(event: String) -> Array:
	return _args.get(event, [])


func has_event(event: String) -> bool:
	return _args.has(event)


func _r0(n: String) -> void:
	_relay(n, [])

func _r1(a, n: String) -> void:
	_relay(n, [a])

func _r2(a, b, n: String) -> void:
	_relay(n, [a, b])

func _r3(a, b, c, n: String) -> void:
	_relay(n, [a, b, c])


func _relay(n: String, vals: Array) -> void:
	if n == "custom":
		any.emit(str(vals[0]), vals[1] if typeof(vals[1]) == TYPE_DICTIONARY else {})
		return
	var d := {}
	var names: Array = _args[n]
	for i in names.size():
		d[names[i]] = vals[i]
	any.emit(n, d)
