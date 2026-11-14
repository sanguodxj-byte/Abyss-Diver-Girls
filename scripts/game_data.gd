extends Node
## 全局数据：物品库、机甲模块库、仓库、装配、存档；启动时把 data\ext 下各团队的扩展数据并入核心表。

const MapsData = preload("res://scripts/maps.gd")
const Growth = preload("res://scripts/progression/growth.gd")
const AudioReg = preload("res://scripts/audio/audio_registry.gd")
const GridPack = preload("res://scripts/grid_pack.gd")

const CARGO_COLS := 6

const SAVE_FILE := "salvage_save.json"
## 需要迁移存档的旧数据目录名（与当前数据目录同在 app_userdata 下）。
## 正常启动时当前目录没有存档而旧目录有，就复制一份过来，旧文件保留。
const LEGACY_DATA_DIRS := ["潜渊少女 Abyss Diver Girls", "残骸打捞团 Salvage Crew"]
## 带任何测试参数运行时改用这里的按进程号命名的临时存档，退出时删除，真实存档不被读写。
const TEST_SAVE_DIR := "user://test_saves"
## 异常退出残留的临时存档超过这个时长（秒）就在下一次测试启动时删除；并行运行的测试互不影响。
const TEST_SAVE_STALE := 6 * 3600

var save_path := "user://" + SAVE_FILE
var test_mode := false
var _closing := false

const SLOTS := ["core", "legs", "arm_l", "arm_r", "back", "gen"]
const _ZH_SLOT_NAMES := {"core": "躯干", "legs": "底盘", "arm_l": "左臂武装", "arm_r": "右臂武装", "back": "背部挂载", "gen": "动力炉"}
var SLOT_NAMES := _ZH_SLOT_NAMES.duplicate()
const STD_RANGE := 10.0
const RANGE_M_SCALE := 3.0
const RARITY_COLORS := [Color(0.68, 0.70, 0.72), Color(0.52, 0.73, 0.48), Color(0.46, 0.66, 0.82), Color(0.86, 0.58, 0.22)]
const _ZH_RARITY_NAMES := ["普通", "优良", "稀有", "传说"]
var RARITY_NAMES := _ZH_RARITY_NAMES.duplicate()
const _ZH_CAT_NAMES := {"food": "食物", "misc": "杂物", "use": "消耗品", "money": "货币", "module": "机甲模块"}
var CAT_NAMES := _ZH_CAT_NAMES.duplicate()

## 普通物品。w = 重量(kg)，v = 价值(信用点)，rar = 稀有度
var ITEMS := {}

## 弹匣：每种武器的弹容量 / 换弹时间 / HUD 子弹贴图。
## fire_loop = true 的武器按住扳机时播放持续循环的 wpn_<weapon>_loop，而不是每发一次 wpn_<weapon>_fire
var AMMO := {
	"mg": {"mag": 36, "reload": 1.8, "tex": "ammo_mg"},
	"shotgun": {"mag": 6, "reload": 2.2, "tex": "ammo_shell"},
	"flamer": {"mag": 60, "reload": 2.4, "tex": "ammo_fuel", "fire_loop": true},
	"laser": {"mag": 6, "reload": 2.0, "tex": "ammo_cell"},
	"sniper": {"mag": 5, "reload": 2.4, "tex": "ammo_mg"},
}

## 技能：Space=底盘机动，F=背部挂载。icon 对应 assets/ui/ic_<icon>.png
var SKILLS := {
	"biped": {"name": "矢量推进规避", "icon": "dash", "cd": 0.9, "cost": 4.0, "desc": "点火髋部固体矢量推进器，朝移动方向短距高速规避机动。"},
	"tread": {"name": "全扭矩碾压冲锋", "icon": "ram", "cd": 4.0, "cost": 8.0, "dmg": 28.0, "r": 3.2, "desc": "解除变速箱限速器全扭矩冲撞，碾退路径目标并造成 28 点钝击伤害。"},
	"quad": {"name": "液压蓄能跃障", "icon": "leap", "cd": 3.0, "cost": 6.0, "dmg": 22.0, "r": 3.4, "desc": "四足液压蓄能弹射跃起，在起跳点抛洒高粘滞阻拦网并在落点造成 22 点震击。"},
	"hex": {"name": "多足重装震踏", "icon": "quake", "cd": 4.4, "cost": 8.0, "dmg": 34.0, "r": 4.8, "desc": "六足液压同步蓄能前扑重踏，着地释放环形机械冲击波，对 4.8m 内目标造成 34 点震击伤害。"},
	"missile": {"name": "制导多联齐射", "icon": "missile", "desc": "开启背部发射巢齐射制导火箭/微弹，自动索敌覆盖视野内目标。"},
	"shield": {"name": "主动防御拦截", "icon": "shield", "desc": "激发车载电磁偏转幕拦截来袭攻击，并向受损部位注入损管密封胶。"},
	"none": {"name": "无主动机能", "icon": "lock", "desc": "外挂货箱专注于扩容携行，未配置主动火控或防御分系统。"},
}

## 机甲模块：既是装备，也决定外观（纸娃娃）。
var MODULES := {}

var LOOT_TABLES := {
	"supply": {"name": "补给箱", "rolls": [2, 4], "pool": {"can_food": 30, "biscuit": 30, "water_tab": 25, "coffee": 4, "fuel_cell": 12, "repair_kit": 6}},
	"tool": {"name": "工具箱", "rolls": [2, 4], "pool": {"circuit": 20, "wire": 25, "bolts": 30, "hdd": 5, "toy": 8, "fuel_cell": 8}},
	"military": {"name": "军用储物箱", "rolls": [1, 3], "pool": {"@module": 45, "fuel_cell": 18, "repair_kit": 14, "beacon": 5, "credit_s": 10}},
	"safe": {"name": "保险柜", "rolls": [1, 3], "pool": {"credit_s": 40, "credit_l": 15, "gold": 4, "hdd": 10, "coffee": 6}},
	"bug": {"name": "虫尸", "rolls": [1, 1], "pool": {"chitin": 85, "bug_crystal": 12, "fuel_cell": 6}},
	"nest": {"name": "巢穴残骸", "rolls": [2, 3], "pool": {"bug_crystal": 45, "chitin": 50, "gen_crystal": 3, "legs_hex_beetle": 2}},
}

var SHOP := ["fuel_cell", "repair_kit", "beacon", "arm_mg", "arm_shotgun", "back_cargo", "core_std", "legs_biped_scout", "legs_tread_light", "legs_tread", "gen_reactor"]

const STARTER := {"core": "core_scout", "legs": "legs_biped", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_cargo", "gen": "gen_cell"}

var DISPATCH_LINES: Array = []

var REQUEST_POOL := [
	{"id": "can_food", "count": 3, "reward": 450, "who": "厨师阿堇", "char": "ajin"},
	{"id": "water_tab", "count": 4, "reward": 420, "who": "厨师阿堇", "char": "ajin"},
		{"id": "circuit", "count": 2, "reward": 500, "who": "机械师米娅", "char": "mia"},
		{"id": "chitin", "count": 3, "reward": 520, "who": "装甲工坊", "char": "mia"},
		{"id": "wire", "count": 2, "reward": 380, "who": "机械师米娅", "char": "mia"},
	{"id": "toy", "count": 1, "reward": 400, "who": "艇上的孩子们"},
	{"id": "bug_crystal", "count": 1, "reward": 900, "who": "轮机长"},
]

## 商人任务线：按顺序逐条推进，完成当前条目后同一商人的下一条接上；全部走完再换下一位商人
const QUEST_ORDER := ["ajin", "xiaoman", "shiori", "karasu", "nihong", "gin"]
const _ZH_QUEST_NAMES := {"ajin": "阿堇", "xiaoman": "小满", "shiori": "诗织", "karasu": "鸦", "nihong": "霓虹", "gin": "银"}
var QUEST_NAMES := _ZH_QUEST_NAMES.duplicate()
const _ZH_QUEST_CHAINS := {
	"ajin": [
		{"name": "罐头补给", "type": "item", "id": "can_food", "count": 3, "reward": 300, "aff": 1},
		{"name": "清理货道", "type": "kill", "target": "ling", "count": 6, "reward": 380, "aff": 1},
		{"name": "净水配给", "type": "item", "id": "water_tab", "count": 3, "reward": 450, "aff": 2},
		{"name": "赤湖踩点", "type": "visit", "target": "redlake", "count": 1, "reward": 620, "aff": 2},
		{"name": "罐头囤积", "type": "item", "id": "can_food", "count": 6, "reward": 820, "aff": 3},
	],
	"xiaoman": [
		{"name": "线圈补货", "type": "item", "id": "wire", "count": 4, "reward": 350, "aff": 1},
		{"name": "甲壳回收", "type": "kill", "target": "beetle", "count": 5, "reward": 430, "aff": 1},
		{"name": "转管订单", "type": "item", "id": "arm_mg", "count": 1, "reward": 700, "aff": 2},
		{"name": "工业带撤收", "type": "extract", "target": "ironbelt", "count": 2, "reward": 900, "aff": 3},
	],
	"shiori": [
		{"name": "壳质样本", "type": "item", "id": "chitin", "count": 5, "reward": 400, "aff": 1},
		{"name": "喷吐取样", "type": "kill", "target": "spitter", "count": 4, "reward": 620, "aff": 2},
		{"name": "冷却剂递送", "type": "item", "id": "coolant_pack", "count": 1, "reward": 720, "aff": 2},
		{"name": "巢母解剖", "type": "boss", "target": "broodmother", "count": 1, "reward": 1150, "aff": 3},
	],
	"karasu": [
		{"name": "螺栓清点", "type": "item", "id": "bolts", "count": 10, "reward": 460, "aff": 1},
		{"name": "破盾作业", "type": "kill", "target": "aegis", "count": 2, "reward": 540, "aff": 1},
		{"name": "盾板交付", "type": "item", "id": "back_shield", "count": 1, "reward": 1000, "aff": 2},
		{"name": "王虫猎杀", "type": "boss", "target": "king_beetle", "count": 1, "reward": 1650, "aff": 3},
	],
	"nihong": [
		{"name": "电路订货", "type": "item", "id": "circuit", "count": 3, "reward": 430, "aff": 1},
		{"name": "灰港撤收", "type": "extract", "target": "greyport", "count": 2, "reward": 660, "aff": 2},
		{"name": "诱饵交付", "type": "item", "id": "sonic_decoy", "count": 1, "reward": 720, "aff": 2},
		{"name": "指挥链切断", "type": "kill", "target": "overseer", "count": 1, "reward": 980, "aff": 3},
	],
	"gin": [
		{"name": "小额信用", "type": "item", "id": "credit_s", "count": 2, "reward": 520, "aff": 1},
		{"name": "清场作业", "type": "kill", "target": "any", "count": 10, "reward": 900, "aff": 2},
		{"name": "大额信用", "type": "item", "id": "credit_l", "count": 2, "reward": 1250, "aff": 2},
		{"name": "裂谷撤收", "type": "extract", "target": "canyon", "count": 2, "reward": 1900, "aff": 3},
	],
}
var QUEST_CHAINS := _ZH_QUEST_CHAINS.duplicate(true)
## 各商人已完成的任务条数（旧存档兼容与统计）
var quests := {}
## 商人委托状态："商人:序号" -> 1 已接取 / 2 已完成；缺省为可接取
var quest_state := {}
## 委托进度："商人:序号" -> 已完成的目标计数；物品类委托不记
var quest_progress := {}

var money := 1500
var stash: Array = []
var cargo: Array = []      ## 下一次出击要带的东西
var loadout := {}
var raids := 0
## 画质：0 流畅 / 1 高 / 2 极致（新存档默认“高”：极致档 1.5 倍超采样 + MSAA4x + TAA + SSIL，中端显卡压力过大）
const _ZH_QUALITY_NAMES := ["流畅", "高", "极致"]
var QUALITY_NAMES := _ZH_QUALITY_NAMES.duplicate()
var quality := 1
var render_style := 0  # 0 写实 1 三渲二
var map_id := "greyport"  ## 出击战区
var extracts_ok := 0
## 遭遇过的敌人种类（跨行动累计，随存档保存）
var seen_enemies: Array = []

## 合并后的注册表：敌人种类（核心表在 scripts\bug.gd 的 KINDS）、战区（scripts\maps.gd 的 MAPS）、
## 遗迹 POI 类型（scripts\maps.gd 的 POIS）、各战区的虫群分布（只来自扩展数据，没有登记的战区按 raid.gd 的默认分布）
var ENEMIES := {}
var MAPS := {}
var POIS := {}
var SPAWNS := {}
## 音效与音乐槽（核心表在 scripts\audio\audio_registry.gd 的 SFX / MUSIC），AudioManager 读这两张合并后的表
var SFX := {}
var MUSIC := {}
## 行动扩展脚本路径（只来自扩展数据）：raid.gd 在每次行动里调用，规则见 scripts\raid.gd 的 _run_ext_build / _add_ext_nodes
var RAID_SCRIPTS: Array = []


var _zh_base := {}

func _ready() -> void:
	_init_save_path()
	_merge_content()
	for id in MODULES:
		_module_item(id)
	_setup_input()
	_run_ext_register()
	_capture_zh_base()
	var loc := get_node_or_null("/root/Loc")
	if loc != null:
		apply_lang(str(loc.get("lang")))
	if not load_game():
		new_game()
	call_deferred("_bind_quest_events")


func _capture_zh_base() -> void:
	_zh_base = {
		"MODULES": MODULES.duplicate(true),
		"ITEMS": ITEMS.duplicate(true),
		"SKILLS": SKILLS.duplicate(true),
		"LOOT_TABLES": LOOT_TABLES.duplicate(true),
		"ENEMIES": ENEMIES.duplicate(true),
		"MAPS": MAPS.duplicate(true),
		"POIS": POIS.duplicate(true),
		"REQUEST_POOL": REQUEST_POOL.duplicate(true),
		"DISPATCH_LINES": DISPATCH_LINES.duplicate(true),
	}


func apply_lang(_lang_code: String) -> void:
	if _zh_base.is_empty():
		_capture_zh_base()
	MODULES = (_zh_base["MODULES"] as Dictionary).duplicate(true)
	ITEMS = (_zh_base["ITEMS"] as Dictionary).duplicate(true)
	SKILLS = (_zh_base["SKILLS"] as Dictionary).duplicate(true)
	LOOT_TABLES = (_zh_base["LOOT_TABLES"] as Dictionary).duplicate(true)
	ENEMIES = (_zh_base["ENEMIES"] as Dictionary).duplicate(true)
	MAPS = (_zh_base["MAPS"] as Dictionary).duplicate(true)
	POIS = (_zh_base["POIS"] as Dictionary).duplicate(true)
	REQUEST_POOL = (_zh_base["REQUEST_POOL"] as Array).duplicate(true)
	DISPATCH_LINES = (_zh_base["DISPATCH_LINES"] as Array).duplicate(true)
	QUEST_CHAINS = _ZH_QUEST_CHAINS.duplicate(true)
	_variant_cache.clear()
	var loc := get_node_or_null("/root/Loc")
	if loc != null and loc.has_method("apply_game_data"):
		loc.call("apply_game_data", self)


## 模块同时登记为物品（类别 module）
func _module_item(id: String) -> void:
	var m: Dictionary = MODULES[id].duplicate()
	m["cat"] = "module"
	if not m.has("desc"):
		m["desc"] = "机甲模块 · " + SLOT_NAMES.get(m.slot, "手臂")
	ITEMS[id] = m


func _setup_input() -> void:
	_key("move_up", [KEY_W, KEY_UP])
	_key("move_down", [KEY_S, KEY_DOWN])
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("dash", [KEY_SPACE, KEY_SHIFT])      # Space：位移技能（由底盘决定）
	_key("ability", [KEY_F])                  # F：背部挂载技能
	_key("reload", [KEY_R])                   # R：双臂手动重装填
	_key("interact", [KEY_G])
	_key("inventory", [KEY_TAB, KEY_I])       # Tab / I：战地整备与货舱终端
	_key("use_fuel", [KEY_1])
	_key("use_repair", [KEY_2])
	_key("call_transport", [KEY_T])
	_key("pause", [KEY_ESCAPE])
	_mouse("fire_left", MOUSE_BUTTON_LEFT)
	_mouse("fire_right", MOUSE_BUTTON_RIGHT)


func _key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _mouse(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


# ---------- 物品查询 ----------
## 物品 id 可以带「#」后缀表示同一物品的变体（例如带品质词条的模块 arm_mg#xxx）。
## 变体的数值由 add_item_resolver 登记的解析函数在基础条目的副本上计算；没有解析函数时变体等同于基础物品。
var _item_resolvers: Array = []
var _variant_cache := {}

func base_id(id: String) -> String:
	var k := id.find("#")
	return id if k < 0 else id.substr(0, k)

## f(id: String, base: Dictionary) -> Dictionary：收到基础条目的副本，返回变体条目
func add_item_resolver(f: Callable) -> void:
	_item_resolvers.append(f)
	_variant_cache.clear()

func item(id: String) -> Dictionary:
	if ITEMS.has(id):
		return ITEMS[id]
	if _variant_cache.has(id):
		return _variant_cache[id]
	var b := base_id(id)
	if b != id and ITEMS.has(b):
		var d: Dictionary = ITEMS[b].duplicate(true)
		for f: Callable in _item_resolvers:
			d = f.call(id, d)
		_variant_cache[id] = d
		return d
	return {"name": id, "cat": "misc", "w": 1.0, "v": 1, "rar": 0, "desc": ""}

func is_module(id: String) -> bool:
	return id != "" and MODULES.has(base_id(id))

## 模块数值（变体经过解析函数）；不是模块时返回空字典
func module(id: String) -> Dictionary:
	if MODULES.has(id):
		return MODULES[id]
	if not is_module(id):
		return {}
	return item(id)

func item_name(id: String) -> String:
	return item(id).name

func weight_of(list: Array) -> float:
	var t := 0.0
	for id in list:
		t += float(item(id).w)
	return t

func value_of(list: Array) -> int:
	var t := 0
	for id in list:
		t += int(item(id).v)
	return t

func item_grid_size(id: String) -> Vector2i:
	var it: Dictionary = item(id)
	if it.is_empty():
		return Vector2i(1, 1)
	var cat: String = str(it.get("cat", "misc"))
	if cat == "misc" or cat == "food" or cat == "use":
		return Vector2i(1, 1)
	if it.has("gw") and it.has("gh"):
		return Vector2i(maxi(1, int(it.gw)), maxi(1, int(it.gh)))
	if base_id(id) == "gold":
		return Vector2i(2, 1)
	if cat == "module":
		var s: String = str(it.get("slot", "arm"))
		var w: float = float(it.get("w", 5.0))
		match s:
			"core":
				if w >= 19.0:
					return Vector2i(3, 3)
				return Vector2i(2, 2) if w <= 9.0 else Vector2i(2, 3)
			"legs":
				var lt: String = str(it.get("type", "biped"))
				if lt == "biped":
					return Vector2i(2, 2) if w <= 10.0 else Vector2i(2, 3)
				return Vector2i(3, 3) if w >= 18.0 else Vector2i(3, 2)
			"arm":
				if bool(it.get("scope", false)) or float(it.get("range", 10.0)) >= 16.0:
					return Vector2i(4, 1)
				return Vector2i(2, 1) if w <= 7.5 else Vector2i(3, 1)
			"back":
				return Vector2i(2, 3) if str(it.get("ability", "none")) == "missile" else Vector2i(2, 2)
			"gen":
				return Vector2i(1, 2) if w <= 8.5 else Vector2i(2, 2)
	return Vector2i(1, 1)

func cargo_grid_rows(cargo_cap: float) -> int:
	return maxi(3, ceili(maxf(1.0, cargo_cap) / 4.0))

func cargo_grid_cap(cargo_cap: float) -> int:
	return CARGO_COLS * cargo_grid_rows(cargo_cap)

func cargo_cells_used(list: Array) -> int:
	var total: int = 0
	for id in list:
		var sz: Vector2i = item_grid_size(str(id))
		total += sz.x * sz.y
	return total

func cargo_sizes(list: Array) -> Array:
	var out: Array = []
	for id in list:
		out.append(item_grid_size(str(id)))
	return out

func can_pack_cargo(list: Array, cargo_cap: float) -> bool:
	return GridPack.can_fit(cargo_sizes(list), CARGO_COLS, cargo_grid_rows(cargo_cap))

func pack_cargo_inplace(list: Array, cargo_cap: float) -> bool:
	var order: PackedInt32Array = GridPack.find_packing_order(cargo_sizes(list), CARGO_COLS, cargo_grid_rows(cargo_cap))
	if order.is_empty():
		return false
	var changed: bool = false
	for i: int in order.size():
		if order[i] != i:
			changed = true
			break
	if changed:
		var orig: Array = list.duplicate()
		for i: int in order.size():
			list[i] = orig[order[i]]
	return true

func slot_accepts(slot: String, id: String) -> bool:
	if not is_module(id):
		return false
	var s: String = module(id).slot
	if slot == "arm_l" or slot == "arm_r":
		return s == "arm"
	return s == slot


## 穿甲深度（mm RHA）换算为 1~6 级穿甲等级（对标防弹插板 Class 1~6）
func pen_class(pen: float) -> int:
	return clampi(int(round(pen / 11.0)), 1, 6)


## 武器射程数值（标准射程 10）换算为实际弹头/光束物理飞行距离（米）
func weapon_range_m(m: Dictionary) -> float:
	if m.has("reach_m"):
		return float(m.get("reach_m", 30.0))
	return float(m.get("range", STD_RANGE)) * RANGE_M_SCALE


## 判断躯干模块是否带有 [侦察] / [Recon] 标签
func has_recon_tag(m: Dictionary) -> bool:
	if float(m.get("recon", 0.0)) > 0.0:
		return true
	var tags: Array = m.get("tags", [])
	return tags.has("侦察") or tags.has("Recon")


## 查询模块绑定的车载子系统信息（含按键、冷却、能耗、效果说明）；仅底盘（SPACE/空格）与背部挂载（F）具备主动子系统，其余模块返回空字典
func module_skill_info(id: String) -> Dictionary:
	if not is_module(id):
		return {}
	var m: Dictionary = module(id)
	var slot := str(m.get("slot", ""))
	var en := Loc.is_en()
	match slot:
		"legs":
			var t := str(m.get("type", "biped"))
			var sk: Dictionary = SKILLS.get(t, {})
			return {"key": Loc.space_key(), "slot_label": Loc.t("底盘机动", "Chassis Skill"), "id": t, "name": str(sk.get("name", Loc.t("无"))), "icon": str(sk.get("icon", "dash")), "cd": float(sk.get("cd", 1.0)), "cost": float(sk.get("cost", 0.0)), "desc": str(sk.get("desc", ""))}
		"back":
			var ab := str(m.get("ability", "none"))
			var sk: Dictionary = SKILLS.get(ab, {})
			var desc := str(sk.get("desc", ""))
			if ab == "missile":
				desc = ("Launches %d × %s, %.0f frag/HEAT dmg per hit." % [int(m.get("count", 6)), str(m.get("caliber", "guided micromissile")), float(m.get("dmg", 28.0))]) if en else ("齐射 %d 枚 %s，单发造成 %.0f 点破片/聚能伤害。" % [int(m.get("count", 6)), str(m.get("caliber", "制导微弹")), float(m.get("dmg", 28.0))])
			elif ab == "shield":
				desc = ("Activates a %.1fs Active Defense screen and injects sealant to repair 35%% limb damage." % float(m.get("dur", 3.5))) if en else ("启动 %.1f 秒主动防御拦截幕偏转来袭攻击，并注入损管密封胶修复 35%% 受损部位。" % float(m.get("dur", 3.5)))
			return {"key": "F", "slot_label": Loc.t("背部挂载", "Back Mount"), "id": ab, "name": str(sk.get("name", Loc.t("无主动机能", "No Active System"))), "icon": str(sk.get("icon", "lock")), "cd": float(m.get("cd", 0.0)), "cost": float(m.get("cost", 0.0)), "desc": desc}
	return {}


# ---------- 机甲数值 ----------
## f(stats: Dictionary, loadout: Dictionary) -> void：在 compute_stats 算完模块数值后原地修改结果（驾驶员天赋、设施加成等）
var _stat_hooks: Array = []

func add_stat_hook(f: Callable) -> void:
	_stat_hooks.append(f)

func compute_stats(lo: Dictionary) -> Dictionary:
	var s := {"hp": 0.0, "cargo": 0.0, "energy": 0.0, "drain": 0.0, "speed": 0.0, "load": 1.0, "mass": 0.0, "armor": 0.0, "armor_class": 2, "core_armor_class": 2, "legs_armor_class": 2, "ergo": 60.0, "weapon_range": 0.0, "recon": 0.0, "recon_tag": false, "view_range": STD_RANGE}
	var ergo_sum := 0.0
	var ergo_cnt := 0
	for slot in SLOTS:
		var id: String = lo.get(slot, "")
		if not is_module(id):
			continue
		var m: Dictionary = module(id)
		s["mass"] += float(m.get("w", 0))
		s["hp"] += float(m.get("hp", 0))
		s["cargo"] += float(m.get("cargo", 0))
		s["energy"] += float(m.get("energy", 0))
		s["drain"] += float(m.get("drain", 0))
		s["armor"] += float(m.get("armor", 0))
		if slot == "core":
			s["core_armor_class"] = int(m.get("armor_class", 2))
		elif slot == "legs":
			s["speed"] = float(m.speed)
			s["load"] = float(m.load)
			s["legs_armor_class"] = int(m.get("armor_class", 2))
		elif slot == "arm_l" or slot == "arm_r":
			s["weapon_range"] = maxf(float(s["weapon_range"]), float(m.get("range", STD_RANGE)))
		s["recon"] = float(s["recon"]) + float(m.get("recon", 0.0))
		if has_recon_tag(m):
			s["recon_tag"] = true
		if m.has("ergo"):
			ergo_sum += float(m.get("ergo", 60.0))
			ergo_cnt += 1
	if float(s["weapon_range"]) <= 0.0:
		s["weapon_range"] = STD_RANGE
	s["view_range"] = maxf(STD_RANGE, float(s["weapon_range"])) + float(s["recon"])
	s["armor_class"] = maxi(int(s["core_armor_class"]), int(s["legs_armor_class"]))
	var base_ergo := (ergo_sum / float(ergo_cnt)) if ergo_cnt > 0 else 60.0
	var back_w := float(module(lo.get("back", "")).get("w", 0.0)) if is_module(lo.get("back", "")) else 0.0
	s["ergo"] = clampf(roundf(base_ergo - maxf(0.0, back_w - 4.0) * 1.2), 15.0, 95.0)
	var eff := 1.0
	if is_module(lo.get("gen", "")):
		eff = float(module(lo.gen).eff)
	s["drain"] = (s["drain"] + 0.04) * eff   # 0.04 = 维生系统基础耗能
	s["eff"] = eff
	for f: Callable in _stat_hooks:
		f.call(s, lo)
	s["view_range"] = maxf(STD_RANGE, float(s["weapon_range"])) + float(s["recon"])
	return s

## 超载减速：总质量（模块+货物）超过底盘承重时速度下降（负重肌力精英专精减轻 30% 超载减速惩罚）
func speed_factor(stats: Dictionary, cargo_w: float) -> float:
	var total: float = stats.mass + cargo_w
	var over: float = max(0.0, total - stats.load)
	var pen_scale := 1.05 if Growth.ability_elite("ab_rack") else 1.5
	return clamp(1.0 - over / max(1.0, stats.load) * pen_scale, 0.4, 1.0)

func can_deploy(lo: Dictionary) -> String:
	for s in ["core", "legs", "gen"]:
		if lo.get(s, "") == "":
			return ("Missing " + SLOT_NAMES[s]) if Loc.is_en() else ("缺少" + SLOT_NAMES[s])
	if lo.get("arm_l", "") == "" and lo.get("arm_r", "") == "":
		return Loc.t("至少需要一件手臂武装", "Requires at least 1 Arm Weapon")
	var st := compute_stats(lo)
	if weight_of(cargo) > st.cargo:
		return Loc.t("出击货舱超出容量", "Cargo Exceeds Capacity")
	if not can_pack_cargo(cargo, float(st.cargo)):
		return Loc.t("出击货舱格位不足", "Cargo Grid Full")
	return ""


# ---------- 战利品 ----------
## f(id: String, table: String, rng: RandomNumberGenerator) -> String：每件掉落抽出后经过它，可返回变体 id（如带词条的模块）
var _loot_hooks: Array = []

func add_loot_hook(f: Callable) -> void:
	_loot_hooks.append(f)

func roll_loot(table: String, rng: RandomNumberGenerator) -> Array:
	var t: Dictionary = LOOT_TABLES[table]
	var n := rng.randi_range(t.rolls[0], t.rolls[1])
	var out: Array = []
	for i in n:
		var id := _weighted(t.pool, rng)
		if id == "@module":
			id = _random_module(rng)
		for f: Callable in _loot_hooks:
			id = f.call(id, table, rng)
		out.append(id)
	return out

func _weighted(pool: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in pool:
		total += float(pool[k])
	var r := rng.randf() * total
	for k in pool:
		r -= float(pool[k])
		if r <= 0.0:
			return k
	return pool.keys()[0]

func _random_module(rng: RandomNumberGenerator) -> String:
	var weights := {}
	var rw := [10.0, 5.0, 2.0, 0.6]
	for id in MODULES:
		weights[id] = rw[int(MODULES[id].rar)]
	return _weighted(weights, rng)


# ---------- 商店与战区的可用性 ----------
## f(id: String) -> bool：返回 false 时该商品不上架 / 该战区不可出击（研究解锁、章节进度）
var _shop_filters: Array = []
var _map_filters: Array = []

func add_shop_filter(f: Callable) -> void:
	_shop_filters.append(f)

func add_map_filter(f: Callable) -> void:
	_map_filters.append(f)

## 当前上架的商品 id（按 SHOP 顺序）
func shop_items() -> Array:
	var out: Array = []
	for id in SHOP:
		var ok := true
		for f: Callable in _shop_filters:
			if not f.call(id):
				ok = false
				break
		if ok:
			out.append(id)
	return out

## 全部战区 id（核心战区在前，扩展战区按登记顺序在后）
func map_ids() -> Array:
	return MAPS.keys()

func map_available(id: String) -> bool:
	if not MAPS.has(id):
		return false
	for f: Callable in _map_filters:
		if not f.call(id):
			return false
	return true

func map_data(id: String) -> Dictionary:
	return MAPS.get(id, MAPS.get("greyport", {}))


# ---------- 商人委托 ----------
func quest_key(m: String, i: int) -> String:
	return "%s:%d" % [m, i]


## 0 可接取 / 1 已接取 / 2 已完成
func quest_status(m: String, i: int) -> int:
	return int(quest_state.get(quest_key(m, i), 0))


func quest_entry(m: String, i: int) -> Dictionary:
	var chain: Array = QUEST_CHAINS.get(m, [])
	if i < 0 or i >= chain.size():
		return {}
	var q: Dictionary = chain[i].duplicate()
	q["who"] = QUEST_NAMES.get(m, m)
	q["merchant"] = m
	q["char"] = m
	q["index"] = i
	q["status"] = quest_status(m, i)
	return q


## 某商人全部委托（含状态），供交易页逐条展示与接取
func merchant_quests(m: String) -> Array:
	var out: Array = []
	for i in (QUEST_CHAINS.get(m, []) as Array).size():
		out.append(quest_entry(m, i))
	return out


func accept_quest(m: String, i: int) -> bool:
	if quest_entry(m, i).is_empty() or quest_status(m, i) != 0:
		return false
	quest_state[quest_key(m, i)] = 1
	save_game()
	return true


## 委托目标类型：item 交付物品 / kill 击杀 / boss 击杀首领 / extract 撤离 / visit 前往战区
func quest_type(q: Dictionary) -> String:
	return str(q.get("type", "item"))


func quest_progress_of(m: String, i: int) -> int:
	return int(quest_progress.get(quest_key(m, i), 0))


func quest_target_name(q: Dictionary) -> String:
	var t := quest_type(q)
	var tgt := str(q.get("target", ""))
	if t == "kill" or t == "boss":
		if tgt == "any":
			return Loc.t("异体", "Hostiles")
		return str((ENEMIES.get(tgt, {}) as Dictionary).get("name", tgt))
	if t == "extract" or t == "visit":
		return str(map_data(tgt).get("name", tgt))
	return str(item_name(str(q.get("id", ""))))


func quest_name(q: Dictionary) -> String:
	return str(q.get("name", quest_objective(q)))


func quest_objective(q: Dictionary) -> String:
	var t := quest_type(q)
	match t:
		"kill", "boss":
			return Loc.t("击杀 %s", "Eliminate %s") % quest_target_name(q)
		"extract":
			return Loc.t("从 %s 撤离", "Extract from %s") % quest_target_name(q)
		"visit":
			return Loc.t("前往 %s", "Deploy to %s") % quest_target_name(q)
		_:
			return Loc.t("交付 %s", "Deliver %s") % quest_target_name(q)


func quest_ready(m: String, i: int) -> bool:
	if quest_status(m, i) != 1:
		return false
	var q := quest_entry(m, i)
	if q.is_empty():
		return false
	if quest_type(q) == "item":
		return count_in_stash(str(q.get("id", ""))) >= int(q.count)
	return quest_progress_of(m, i) >= int(q.count)


func fulfill_quest(m: String, i: int) -> bool:
	if not quest_ready(m, i):
		return false
	var q := quest_entry(m, i)
	if quest_type(q) == "item":
		for _k in int(q.count):
			stash.erase(str(q.get("id", "")))
	money += int(q.reward)
	if int(q.get("aff", 0)) > 0:
		Growth.grant_affinity(m, int(q.aff))
	quest_state[quest_key(m, i)] = 2
	quest_progress[quest_key(m, i)] = int(q.count)
	quests[m] = int(quests.get(m, 0)) + 1
	Events.request_fulfilled.emit(q)
	save_game()
	return true


## 已接取的交付类委托所需物品，出售杂物时跳过
func accepted_ids() -> Array:
	var out: Array = []
	for m: String in QUEST_CHAINS:
		for i in (QUEST_CHAINS[m] as Array).size():
			if quest_status(m, i) != 1:
				continue
			var q := quest_entry(m, i)
			if quest_type(q) != "item":
				continue
			var id := str(q.get("id", ""))
			if id != "" and not out.has(id):
				out.append(id)
	return out


func _bind_quest_events() -> void:
	if not Events.enemy_killed.is_connected(_on_enemy_killed):
		Events.enemy_killed.connect(_on_enemy_killed)
	if not Events.extract_completed.is_connected(_on_extract_completed):
		Events.extract_completed.connect(_on_extract_completed)
	if not Events.deployed.is_connected(_on_deployed):
		Events.deployed.connect(_on_deployed)


func _on_enemy_killed(kind: String, _pos: Vector3) -> void:
	_bump_quests(["kill", "boss"], kind)


func _on_extract_completed(_title: String, _is_transport: bool) -> void:
	var tree := get_tree()
	var sc = tree.current_scene if tree else null
	var active_mid := str(sc.raid.map_id) if sc != null and "raid" in sc and is_instance_valid(sc.raid) and "map_id" in sc.raid else map_id
	_bump_quests(["extract"], active_mid)


func _on_deployed(id: String, _loadout: Dictionary) -> void:
	_bump_quests(["visit"], id)


## 事件推进：只累加已接取且未完成的对应目标
func _bump_quests(types: Array, target_value: String) -> void:
	for m: String in QUEST_CHAINS:
		for i in (QUEST_CHAINS[m] as Array).size():
			if quest_status(m, i) != 1:
				continue
			var q := quest_entry(m, i)
			if not types.has(quest_type(q)):
				continue
			var tgt := str(q.get("target", ""))
			if tgt != "any" and tgt != target_value:
				if not (tgt == "broodmother" and target_value in ["grey_brood", "dust_matriarch", "harbor_reaper", "dune_devourer", "prism_archon", "terminus_warden", "silo_warhead", "spillway_leviathan"]) and not (tgt == "king_beetle" and target_value in ["iron_warden", "slag_colossus", "gorge_tyrant", "foundry_dreadnought", "excavator_titan", "drydock_behemoth"]) and not (tgt == "abyss_queen" and target_value in ["abyss_harbinger", "core_overlord"]):
					continue
			var cur := quest_progress_of(m, i)
			if cur >= int(q.count):
				continue
			quest_progress[quest_key(m, i)] = cur + 1


func count_in_stash(id: String) -> int:
	return stash.count(id)


## 记一次敌人遭遇；返回 true 表示这个种类此前从未遇到过
func mark_enemy_seen(kind: String) -> bool:
	if seen_enemies.has(kind):
		return false
	seen_enemies.append(kind)
	return true


# ---------- 存档 ----------
func new_game() -> void:
	money = 1500
	loadout = STARTER.duplicate()
	stash = ["fuel_cell", "fuel_cell", "repair_kit", "beacon", "arm_shotgun", "can_food"]
	cargo = ["fuel_cell", "repair_kit", "beacon"]
	raids = 0
	extracts_ok = 0
	seen_enemies = []
	quests = {}
	quest_state = {}
	quest_progress = {}
	_sections_data = {}
	for k in _sections:
		_sections[k][1].call({})
	save_game()

func save_game() -> void:
	if _closing:
		return
	var sec: Dictionary = _sections_data.duplicate()
	for k in _sections:
		sec[k] = _sections[k][0].call()
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"money": money, "stash": stash, "cargo": cargo, "loadout": loadout,
		"raids": raids, "extracts_ok": extracts_ok, "quest_state": quest_state, "quest_progress": quest_progress, "quests": quests, "quality": quality, "render_style": render_style, "map_id": map_id,
		"seen_enemies": seen_enemies, "sections": sec}))

func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return false
	quests = Dictionary(d.get("quests", {}))
	quest_state = Dictionary(d.get("quest_state", {}))
	quest_progress = Dictionary(d.get("quest_progress", {}))
	if quest_state.is_empty() and not quests.is_empty():
		# 旧存档只有已完成条数：按顺序补成已完成状态
		for m: String in quests:
			var n := mini(int(quests[m]), (QUEST_CHAINS.get(m, []) as Array).size())
			for i in n:
				quest_state[quest_key(m, i)] = 2
	else:
		quests = {}
		for key: String in quest_state:
			if int(quest_state[key]) == 2:
				var m := key.get_slice(":", 0)
				quests[m] = int(quests.get(m, 0)) + 1
	money = int(d.get("money", 1500))
	stash = _migrate_item_list(Array(d.get("stash", [])))
	cargo = _migrate_item_list(Array(d.get("cargo", [])))
	loadout = Dictionary(d.get("loadout", STARTER.duplicate()))
	for slot_k: String in STARTER:
		var cur_id := _migrate_item_id(str(loadout.get(slot_k, STARTER[slot_k])))
		loadout[slot_k] = cur_id if MODULES.has(cur_id) else STARTER[slot_k]
	raids = int(d.get("raids", 0))
	quality = int(d.get("quality", 1))
	render_style = int(d.get("render_style", 0))
	map_id = str(d.get("map_id", "greyport"))
	extracts_ok = int(d.get("extracts_ok", 0))
	seen_enemies = Array(d.get("seen_enemies", []))
	var sec = d.get("sections", {})
	_sections_data = sec if typeof(sec) == TYPE_DICTIONARY else {}
	if _sections_data.has("progress") and typeof(_sections_data["progress"]) == TYPE_DICTIONARY:
		var prog: Dictionary = _sections_data["progress"]
		if typeof(prog.get("research")) == TYPE_ARRAY:
			var rlist: Array = prog["research"]
			for ri in rlist.size():
				if str(rlist[ri]) == "res_hover":
					rlist[ri] = "res_hex"
	for k in _sections:
		_sections[k][1].call(_section_in(k))
	return true


const _LEGACY_ID_MAP := {
	"legs_hover": "legs_hex",
	"legs_reverse": "legs_biped_scout",
	"legs_wraith": "legs_biped_scout",
	"legs_spring": "legs_biped_scout",
	"legs_wheel": "legs_tread_light",
}

func _migrate_item_id(id: String) -> String:
	var b := base_id(id)
	if _LEGACY_ID_MAP.has(b):
		return str(_LEGACY_ID_MAP[b]) + id.substr(b.length())
	return id

func _migrate_item_list(arr: Array) -> Array:
	var out: Array = []
	for raw in arr:
		out.append(_migrate_item_id(str(raw)))
	return out


# ---------- 存档分区 ----------
## 其他系统（音量、剧情进度、局外成长……）把自己的状态存进存档的 sections[name]。
## getter() -> Dictionary 在保存时调用；setter(d: Dictionary) 在载入、新游戏时调用（新游戏与旧存档收到空字典，自行补默认值）。
## 登记时如果存档已经载入，立即用存档里的数据调用一次 setter。
var _sections := {}
var _sections_data := {}

func register_section(name: String, getter: Callable, setter: Callable) -> void:
	_sections[name] = [getter, setter]
	setter.call(_section_in(name))

func _section_in(name: String) -> Dictionary:
	var v = _sections_data.get(name, {})
	return v if typeof(v) == TYPE_DICTIONARY else {}


# ---------- 存档路径：测试隔离与旧目录迁移 ----------
static func is_test_run() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			return true
	return false

func _init_save_path() -> void:
	test_mode = is_test_run()
	if test_mode:
		DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
		_purge_stale_test_saves()
		save_path = "%s/save_%d.json" % [TEST_SAVE_DIR, OS.get_process_id()]
		if FileAccess.file_exists(save_path):
			DirAccess.remove_absolute(save_path)
	else:
		save_path = "user://" + SAVE_FILE
		migrate_legacy_save(OS.get_user_data_dir(), LEGACY_DATA_DIRS)

## 当前数据目录 cur_dir 里没有存档、某个旧目录（与 cur_dir 同级）里有时，复制过来；旧文件保留。返回复制来源，没复制时返回空串。
static func migrate_legacy_save(cur_dir: String, legacy_names: Array) -> String:
	var dst := cur_dir.path_join(SAVE_FILE)
	if FileAccess.file_exists(dst):
		return ""
	var parent := cur_dir.get_base_dir()
	for n: String in legacy_names:
		var src := parent.path_join(n).path_join(SAVE_FILE)
		if src == dst or not FileAccess.file_exists(src):
			continue
		DirAccess.make_dir_recursive_absolute(cur_dir)
		if DirAccess.copy_absolute(src, dst) == OK:
			return src
	return ""

func _purge_stale_test_saves() -> void:
	var now := int(Time.get_unix_time_from_system())
	for fn in DirAccess.get_files_at(TEST_SAVE_DIR):
		var p := TEST_SAVE_DIR.path_join(fn)
		if now - int(FileAccess.get_modified_time(p)) > TEST_SAVE_STALE:
			DirAccess.remove_absolute(p)

func _exit_tree() -> void:
	_closing = true
	if test_mode and FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)


# ---------- 内容注册：核心表 + data\ext 扩展数据 ----------
## data\ext 下每个 .gd 文件是一个团队的扩展数据（不加 class_name，只写常量与可选的 static func register(gd)）。
## 与下列注册表同名的常量在启动时并入：
##   字典型：新 id 加入；与已有 id 重名时报错并保留原条目（扩展不覆盖既有内容）。
##   列表型：元素追加到末尾。
## 常量 EXTEND = {注册表名: {已有 id: {字段: 值}}} 给已有条目补字段：没有的字段新增，
##   字典字段递归合并，数组字段追加（如往掉落池加新物品、往战区加新 POI），已有的标量字段不许改（报错并保留原值）。
## static func register(gd) 在全部合并完成后调用，用来登记解析函数、钩子、输入动作等。
## 行为脚本字段 script（值为脚本路径，脚本不加 class_name、只写 static func）：
##   AMMO[武器].script     static func fire(mech, slot, origin, dir, m) 接管该武器的开火（弹道、炮口火光、警觉半径）
##   SKILLS[技能].script   static func use(mech, key, sk, m) 接管该技能的效果；key = space / f，m 为对应槽位的模块数值
##   ITEMS[物品].script    static func use(mech, id) -> bool 接管消耗品的效果，返回 true 时从货舱扣除一件
##   ENEMIES / POIS / SPAWNS 的 script 规则见 data\ext\enemies.gd 与 data\ext\maps.gd
const EXT_DIR := "res://data/ext"
const DICT_REGISTRIES := ["ITEMS", "MODULES", "AMMO", "SKILLS", "LOOT_TABLES", "ENEMIES", "MAPS", "POIS", "SPAWNS", "SFX", "MUSIC"]
const LIST_REGISTRIES := ["SHOP", "DISPATCH_LINES", "REQUEST_POOL", "RAID_SCRIPTS"]
var ext_scripts: Array = []

func _merge_content() -> void:
	ENEMIES = _copy(load("res://scripts/bug.gd").KINDS)
	MAPS = _copy(MapsData.MAPS)
	POIS = _copy(MapsData.POIS)
	SPAWNS = {}
	SFX = _copy(AudioReg.SFX)
	MUSIC = _copy(AudioReg.MUSIC)
	RAID_SCRIPTS = []
	ext_scripts = list_scripts(EXT_DIR)
	var consts := {}
	for p: String in ext_scripts:
		var s: Script = load(p)
		if s == null:
			push_error("扩展数据无法加载：%s" % p)
			continue
		consts[p] = s.get_script_constant_map()
	# 先并入全部新条目，再统一补字段：EXTEND 可以指向任何一个扩展文件新增的条目
	for p: String in consts:
		var c: Dictionary = consts[p]
		for reg: String in DICT_REGISTRIES:
			if c.has(reg):
				_merge_dict(get(reg), c[reg], reg, p)
		for reg: String in LIST_REGISTRIES:
			if c.has(reg):
				var arr: Array = get(reg)
				for x in c[reg]:
					arr.append(_copy(x))
	for p: String in consts:
		var c: Dictionary = consts[p]
		if c.has("EXTEND"):
			for reg: String in c.EXTEND:
				if not (reg in DICT_REGISTRIES):
					push_error("%s：EXTEND 里的 %s 不是字典型注册表" % [p, reg])
					continue
				var target: Dictionary = get(reg)
				for id in c.EXTEND[reg]:
					if not target.has(id):
						push_error("%s：EXTEND 指向不存在的 %s.%s" % [p, reg, id])
						continue
					_extend(target[id], c.EXTEND[reg][id], "%s.%s" % [reg, id], p)

func _merge_dict(dst: Dictionary, src: Dictionary, reg: String, from: String) -> void:
	for id in src:
		if dst.has(id):
			push_error("%s：%s 里的 id「%s」已存在，扩展条目被忽略" % [from, reg, id])
			continue
		dst[id] = _copy(src[id])

func _extend(dst: Dictionary, add: Dictionary, where: String, from: String) -> void:
	for k in add:
		if not dst.has(k):
			dst[k] = _copy(add[k])
		elif typeof(dst[k]) == TYPE_DICTIONARY and typeof(add[k]) == TYPE_DICTIONARY:
			_extend(dst[k], add[k], "%s.%s" % [where, k], from)
		elif typeof(dst[k]) == TYPE_ARRAY and typeof(add[k]) == TYPE_ARRAY:
			for x in add[k]:
				dst[k].append(_copy(x))
		else:
			push_error("%s：EXTEND 不能改写已有字段 %s.%s" % [from, where, k])

func _run_ext_register() -> void:
	for p: String in ext_scripts:
		var s: Script = load(p)
		if s == null:
			continue
		for m in s.get_script_method_list():
			if m.name == "register":
				s.call("register", self)
				break

static func _copy(v):
	if typeof(v) == TYPE_DICTIONARY or typeof(v) == TYPE_ARRAY:
		return v.duplicate(true)
	return v

## 列出目录下的 GDScript 路径（编辑器里是 .gd；导出后可能是 .gd.remap / .gdc），按文件名排序
static func list_scripts(dir: String) -> Array:
	var seen := {}
	for fn in DirAccess.get_files_at(dir):
		var n: String = fn
		if n.ends_with(".remap"):
			n = n.trim_suffix(".remap")
		if n.ends_with(".gdc"):
			n = n.trim_suffix(".gdc") + ".gd"
		if n.ends_with(".gd"):
			seen[dir.path_join(n)] = true
	var out: Array = seen.keys()
	out.sort()
	return out


## 按画质档位调整战场环境的重型后处理（GPU 开销大头）。
## 流畅：关体积雾 / SSIL，保留基础 SSAO，阴影 2048、硬阴影；高：体积雾 + SSAO，关 SSIL，阴影 4096；极致：全开，阴影 8192。
func apply_env_quality(env: Environment, sun: DirectionalLight3D = null) -> void:
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	match quality:
		0:
			env.volumetric_fog_enabled = false
			env.ssil_enabled = false
			env.ssao_enabled = not compat
			env.ssao_intensity = 2.0
			env.glow_enabled = true
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			if sun:
				sun.light_angular_distance = 0.0
				sun.directional_shadow_max_distance = 55.0
		1:
			env.ssil_enabled = false
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
		_:
			env.ssil_enabled = not compat
			RenderingServer.directional_shadow_atlas_set_size(8192, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)


## 应用抗锯齿 / 渲染缩放到主视口。
## 流畅：MSAA 2x；高 / 极致：MSAA 4x（禁用全局 FXAA 以免模糊贴图与高频棱角）
func apply_quality(vp: Viewport = null) -> void:
	if vp == null:
		vp = get_tree().root
	# 使用硬件 MSAA 保持贴图与几何锐度，关闭会涂抹地面的 FXAA
	match quality:
		0:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.use_taa = false
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
			vp.anisotropic_filtering_level = Viewport.ANISOTROPY_8X
		1:
			vp.msaa_3d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.use_taa = false
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
			vp.anisotropic_filtering_level = Viewport.ANISOTROPY_16X
		_:
			vp.msaa_3d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.use_taa = false
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
			vp.anisotropic_filtering_level = Viewport.ANISOTROPY_16X
