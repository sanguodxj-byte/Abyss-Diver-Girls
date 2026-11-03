extends Node
## 全局数据：物品库、机甲模块库、仓库、装配、存档；启动时把 data\ext 下各团队的扩展数据并入核心表。

const MapsData = preload("res://scripts/maps.gd")
const AudioReg = preload("res://scripts/audio/audio_registry.gd")

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
const SLOT_NAMES := {"core": "躯干", "legs": "底盘", "arm_l": "左臂武装", "arm_r": "右臂武装", "back": "背部挂载", "gen": "动力炉"}
const RARITY_COLORS := [Color(0.82, 0.82, 0.82), Color(0.45, 0.88, 0.45), Color(0.4, 0.65, 1.0), Color(0.88, 0.52, 1.0)]
const RARITY_NAMES := ["普通", "优良", "稀有", "传说"]
const CAT_NAMES := {"food": "食物", "misc": "杂物", "use": "消耗品", "money": "货币", "module": "机甲模块"}

## 普通物品。w = 重量(kg)，v = 价值(信用点)，rar = 稀有度
var ITEMS := {}

## 弹匣：每种武器的弹容量 / 换弹时间 / HUD 子弹贴图。
## fire_loop = true 的武器按住扳机时播放持续循环的 wpn_<weapon>_loop，而不是每发一次 wpn_<weapon>_fire
var AMMO := {
	"mg": {"mag": 36, "reload": 1.8, "tex": "ammo_mg"},
	"shotgun": {"mag": 6, "reload": 2.2, "tex": "ammo_shell"},
	"flamer": {"mag": 60, "reload": 2.4, "tex": "ammo_fuel", "fire_loop": true},
	"laser": {"mag": 6, "reload": 2.0, "tex": "ammo_cell"},
}

## 技能：Space=底盘位移，F=背部，E=躯干，R=动力炉。icon 对应 assets/ui/ic_<icon>.png
var SKILLS := {
	"biped": {"name": "推进冲刺", "icon": "dash", "cd": 0.9, "cost": 4.0},
	"tread": {"name": "履带冲撞", "icon": "ram", "cd": 4.0, "cost": 8.0, "dmg": 28.0, "r": 3.2},
	"quad": {"name": "蛛足跃击", "icon": "leap", "cd": 3.0, "cost": 6.0, "dmg": 22.0, "r": 3.4},
	"hover": {"name": "相位闪移", "icon": "blink", "cd": 2.2, "cost": 5.0, "dist": 9.0},
	"missile": {"name": "蜂巢导弹", "icon": "missile"},
	"shield": {"name": "相位护盾", "icon": "shield"},
	"none": {"name": "无主动技能", "icon": "lock"},
	"core_scout": {"name": "诱饵无人机", "icon": "decoy", "cd": 10.0, "cost": 6.0, "dmg": 34.0, "r": 3.6},
	"core_std": {"name": "火力过载", "icon": "overdrive", "cd": 14.0, "cost": 8.0, "dur": 4.0},
	"core_heavy": {"name": "震地冲击", "icon": "quake", "cd": 9.0, "cost": 10.0, "dmg": 36.0, "r": 6.0},
	"gen_cell": {"name": "应急充能", "icon": "charge", "cd": 25.0, "cost": 0.0, "amt": 30.0},
	"gen_reactor": {"name": "过热排放", "icon": "vent", "cd": 11.0, "cost": 6.0, "dmg": 26.0, "r": 5.0},
	"gen_crystal": {"name": "纳米修复", "icon": "repair", "cd": 20.0, "cost": 12.0, "amt": 40.0, "dur": 4.0},
}

## 机甲模块：既是装备，也决定外观（纸娃娃）。
var MODULES := {}

var LOOT_TABLES := {
	"supply": {"name": "补给箱", "rolls": [2, 4], "pool": {"can_food": 30, "biscuit": 30, "water_tab": 25, "coffee": 4, "fuel_cell": 12, "repair_kit": 6}},
	"tool": {"name": "工具箱", "rolls": [2, 4], "pool": {"circuit": 20, "wire": 25, "bolts": 30, "hdd": 5, "toy": 8, "fuel_cell": 8}},
	"military": {"name": "军用储物箱", "rolls": [1, 3], "pool": {"@module": 45, "fuel_cell": 18, "repair_kit": 14, "beacon": 5, "credit_s": 10}},
	"safe": {"name": "保险柜", "rolls": [1, 3], "pool": {"credit_s": 40, "credit_l": 15, "gold": 4, "hdd": 10, "coffee": 6}},
	"bug": {"name": "虫尸", "rolls": [1, 1], "pool": {"chitin": 85, "bug_crystal": 12, "fuel_cell": 6}},
	"nest": {"name": "巢穴残骸", "rolls": [2, 3], "pool": {"bug_crystal": 45, "chitin": 50, "gen_crystal": 3, "legs_hover": 2}},
}

var SHOP := ["fuel_cell", "repair_kit", "beacon", "arm_mg", "arm_shotgun", "back_cargo", "core_std", "legs_tread", "gen_reactor"]

const STARTER := {"core": "core_scout", "legs": "legs_biped", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_cargo", "gen": "gen_cell"}

var DISPATCH_LINES: Array = []

var REQUEST_POOL := [
	{"id": "can_food", "count": 3, "reward": 450, "who": "厨师阿堇"},
	{"id": "water_tab", "count": 4, "reward": 420, "who": "厨师阿堇"},
		{"id": "circuit", "count": 2, "reward": 500, "who": "机械师米娅"},
		{"id": "chitin", "count": 3, "reward": 520, "who": "装甲工坊"},
		{"id": "wire", "count": 2, "reward": 380, "who": "机械师米娅"},
	{"id": "toy", "count": 1, "reward": 400, "who": "艇上的孩子们"},
	{"id": "bug_crystal", "count": 1, "reward": 900, "who": "轮机长"},
]

var money := 1500
var stash: Array = []
var cargo: Array = []      ## 下一次出击要带的东西
var loadout := {}
var raids := 0
## 画质：0 流畅 / 1 高 / 2 极致（新存档默认“高”：极致档 1.5 倍超采样 + MSAA4x + TAA + SSIL，中端显卡压力过大）
const QUALITY_NAMES := ["流畅", "高", "极致"]
var quality := 1
var render_style := 0  # 0 写实 1 三渲二
var map_id := "greyport"  ## 出击战区
var extracts_ok := 0
var request := {}
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


func _ready() -> void:
	_init_save_path()
	_merge_content()
	for id in MODULES:
		_module_item(id)
	_setup_input()
	_run_ext_register()
	if not load_game():
		new_game()


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
	_key("skill_e", [KEY_E])                  # E：躯干技能
	_key("skill_r", [KEY_R])                  # R：动力炉技能
	_key("interact", [KEY_G])
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

func slot_accepts(slot: String, id: String) -> bool:
	if not is_module(id):
		return false
	var s: String = module(id).slot
	if slot == "arm_l" or slot == "arm_r":
		return s == "arm"
	return s == slot


# ---------- 机甲数值 ----------
## f(stats: Dictionary, loadout: Dictionary) -> void：在 compute_stats 算完模块数值后原地修改结果（驾驶员天赋、设施加成等）
var _stat_hooks: Array = []

func add_stat_hook(f: Callable) -> void:
	_stat_hooks.append(f)

func compute_stats(lo: Dictionary) -> Dictionary:
	var s := {"hp": 0.0, "cargo": 0.0, "energy": 0.0, "drain": 0.0, "speed": 0.0, "load": 1.0, "mass": 0.0, "armor": 0.0}
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
		if slot == "legs":
			s["speed"] = float(m.speed)
			s["load"] = float(m.load)
	var eff := 1.0
	if is_module(lo.get("gen", "")):
		eff = float(module(lo.gen).eff)
	s["drain"] = (s["drain"] + 0.04) * eff   # 0.04 = 维生系统基础耗能
	s["eff"] = eff
	for f: Callable in _stat_hooks:
		f.call(s, lo)
	return s

## 超载减速：总质量（模块+货物）超过底盘承重时速度下降
func speed_factor(stats: Dictionary, cargo_w: float) -> float:
	var total: float = stats.mass + cargo_w
	var over: float = max(0.0, total - stats.load)
	return clamp(1.0 - over / max(1.0, stats.load) * 1.5, 0.4, 1.0)

func can_deploy(lo: Dictionary) -> String:
	for s in ["core", "legs", "gen"]:
		if lo.get(s, "") == "":
			return "缺少" + SLOT_NAMES[s]
	if lo.get("arm_l", "") == "" and lo.get("arm_r", "") == "":
		return "至少需要一件手臂武装"
	var st := compute_stats(lo)
	if weight_of(cargo) > st.cargo:
		return "出击货舱超出容量"
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


# ---------- 后勤委托 ----------
func new_request() -> void:
	request = REQUEST_POOL[randi() % REQUEST_POOL.size()].duplicate()

func count_in_stash(id: String) -> int:
	return stash.count(id)

func fulfill_request() -> bool:
	if request.is_empty() or count_in_stash(request.id) < int(request.count):
		return false
	for i in int(request.count):
		stash.erase(request.id)
	money += int(request.reward)
	var done := request.duplicate()
	new_request()
	Events.request_fulfilled.emit(done)
	save_game()
	return true


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
	new_request()
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
		"raids": raids, "extracts_ok": extracts_ok, "request": request, "quality": quality, "render_style": render_style, "map_id": map_id,
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
	money = int(d.get("money", 1500))
	stash = Array(d.get("stash", []))
	cargo = Array(d.get("cargo", []))
	loadout = Dictionary(d.get("loadout", STARTER.duplicate()))
	raids = int(d.get("raids", 0))
	quality = int(d.get("quality", 1))
	render_style = int(d.get("render_style", 0))
	map_id = str(d.get("map_id", "greyport"))
	extracts_ok = int(d.get("extracts_ok", 0))
	request = Dictionary(d.get("request", {}))
	if request.is_empty():
		new_request()
	seen_enemies = Array(d.get("seen_enemies", []))
	var sec = d.get("sections", {})
	_sections_data = sec if typeof(sec) == TYPE_DICTIONARY else {}
	for k in _sections:
		_sections[k][1].call(_section_in(k))
	return true


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
##   SKILLS[技能].script   static func use(mech, key, sk, m) 接管该技能的效果；key = space / f / e / r，m 为对应槽位的模块数值
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
## 流畅：关体积雾 / SSIL，SSAO 降档，阴影 2048、硬阴影；高：体积雾 + SSAO，关 SSIL，阴影 4096；极致：全开，阴影 8192。
func apply_env_quality(env: Environment, sun: DirectionalLight3D = null) -> void:
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	match quality:
		0:
			env.volumetric_fog_enabled = false
			env.ssil_enabled = false
			env.ssao_enabled = false
			env.glow_enabled = true
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			if sun:
				sun.light_angular_distance = 0.0
				sun.directional_shadow_max_distance = 55.0
		1:
			env.ssil_enabled = false
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		_:
			env.ssil_enabled = not compat
			RenderingServer.directional_shadow_atlas_set_size(8192, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)


## 应用抗锯齿 / 渲染缩放到主视口。
## 流畅：MSAA 2x + FXAA；高：MSAA 4x + FXAA + TAA；极致：MSAA 4x + TAA + 1.5 倍超采样
func apply_quality(vp: Viewport = null) -> void:
	if vp == null:
		vp = get_tree().root
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	# 像素风画面不需要超采样与 TAA：三档只在 MSAA 与各向异性上区分，避免 1.5 倍分辨率叠加 4x MSAA
	match quality:
		0:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.use_taa = false
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
			vp.anisotropic_filtering_level = Viewport.ANISOTROPY_4X
		1:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.use_taa = false
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 0.9
			vp.anisotropic_filtering_level = Viewport.ANISOTROPY_8X
		_:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.use_taa = false
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 0.85
			vp.anisotropic_filtering_level = Viewport.ANISOTROPY_8X
