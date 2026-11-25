extends Node
## 全局数据：物品库、机甲模块库、仓库、装配、存档；启动时把 data\ext 下各团队的扩展数据并入核心表。

signal show_fps_changed(enabled: bool)

const MapsData = preload("res://scripts/maps.gd")
const Growth = preload("res://scripts/progression/growth.gd")
const AudioReg = preload("res://scripts/audio/audio_registry.gd")
const GridPack = preload("res://scripts/grid_pack.gd")
const MechPaint = preload("res://scripts/mech_paint.gd")

const CARGO_COLS := 6

const SAVE_FILE := "salvage_save.json"
## 存档位数：每个位一个独立 JSON，主菜单选位进入；行动中的自动存档只写当前位。
const SAVE_SLOT_COUNT := 3
## 当前存档位（1 起）。主菜单选位/载入时切换，跨启动保留在 SLOT_CFG。
const SLOT_CFG := "user://active_slot.txt"
## 跨存档保留的全局界面配置（与 Loc 共用）。
const UI_CFG_PATH := "user://menu.cfg"
## 需要迁移存档的旧数据目录名（与当前数据目录同在 app_userdata 下）。
## 正常启动时当前目录没有存档而旧目录有，就复制一份过来，旧文件保留。
const LEGACY_DATA_DIRS := ["潜渊少女 Abyss Diver Girls", "残骸打捞团 Salvage Crew"]
## 带任何测试参数运行时改用这里的按进程号命名的临时存档，退出时删除，真实存档不被读写。
const TEST_SAVE_DIR := "user://test_saves"
## 异常退出残留的临时存档超过这个时长（秒）就在下一次测试启动时删除；并行运行的测试互不影响。
const TEST_SAVE_STALE := 6 * 3600

var save_path := "user://" + SAVE_FILE
var slot := 1
var test_mode := false
var _closing := false

const SLOTS := ["core", "legs", "arm_l", "arm_r", "back", "gen"]
const _ZH_SLOT_NAMES := {"core": "躯干", "legs": "底盘", "arm_l": "左臂武装", "arm_r": "右臂武装", "back": "背部挂载", "gen": "动力炉"}
var SLOT_NAMES := _ZH_SLOT_NAMES.duplicate()
const STD_RANGE := 10.0
const RANGE_M_SCALE := 3.0
const RARITY_COLORS := [Color(0.68, 0.70, 0.72), Color(0.52, 0.73, 0.48), Color(0.46, 0.66, 0.82), Color(0.86, 0.58, 0.22), Color(0.74, 0.44, 0.92)]
const _ZH_RARITY_NAMES := ["普通", "优良", "稀有", "传说", "原型"]
var RARITY_NAMES := _ZH_RARITY_NAMES.duplicate()
const _ZH_CAT_NAMES := {"food": "食物", "misc": "杂物", "use": "消耗品", "money": "货币", "module": "机甲模块"}
var CAT_NAMES := _ZH_CAT_NAMES.duplicate()

## 普通物品。w = 重量(kg)，v = 价值(信用点)，rar = 稀有度
var ITEMS := {}

## 武器类型（现实枪械分类）与射击资源：
##   mode = ammo  —— 实弹武器：消耗当前装填量，打空自动装填，不耗库存物品与射击能量
##   mode = energy—— 激光/轨道：不占弹匣，每发直接消耗能量
##   mode = melee —— 近战工程臂：不占弹匣，每击消耗少量能量（液压/燃气伺服）
## fire_loop = true 的武器按住扳机时播放持续循环的 wpn_<weapon>_loop，而不是每发一次 wpn_<weapon>_fire
## sfx = 每发开火音效（缺省按 weapon 命名约定）；tex = HUD 子弹贴图
var AMMO := {
	"mg": {"mode": "ammo", "mag": 36, "reload": 1.8, "tex": "ammo_mg", "sfx": "wpn_mg_fire"},
	"autocannon": {"mode": "ammo", "mag": 36, "reload": 1.8, "tex": "ammo_mg", "sfx": "wpn_mg_fire"},
	"cannon": {"mode": "ammo", "mag": 6, "reload": 2.2, "tex": "ammo_shell", "sfx": "wpn_shotgun_fire"},
	"shotgun": {"mode": "ammo", "mag": 6, "reload": 2.2, "tex": "ammo_shell", "sfx": "wpn_shotgun_fire"},
	"sniper": {"mode": "ammo", "mag": 5, "reload": 2.4, "tex": "ammo_mg", "sfx": "wpn_railgun_fire"},
	"launcher": {"mode": "ammo", "mag": 10, "reload": 2.6, "tex": "ammo_shell", "sfx": "wpn_shotgun_fire"},
	"flamer": {"mode": "ammo", "mag": 60, "reload": 2.4, "tex": "ammo_fuel", "fire_loop": true},
	"laser": {"mode": "energy", "mag": 0, "reload": 0.0, "tex": "ammo_cell", "sfx": "wpn_laser_fire"},
	"melee": {"mode": "melee", "mag": 0, "reload": 0.0, "tex": "ammo_mg", "sfx": "wpn_drill_ignite"},
}

## 兼容误加实体弹匣的旧存档：移除物品时按原价格返还信用点。
## 这些 id 不注册为物品，也不会出现在商店或战利品中。
const LEGACY_MAG_REFUND := {
	"mag_mg": 216, "mag_ac": 900, "mag_cannon": 1080,
	"mag_shotgun": 240, "mag_sniper": 1500, "mag_launcher": 5000, "mag_fuel": 300,
}


## 武器的射击资源模式：ammo（有限装填量）/ energy（激光耗能）/ melee（近战少量耗能）
func weapon_mode(weapon: String) -> String:
	return str(AMMO.get(weapon, {}).get("mode", "ammo"))


func weapon_uses_ammo(weapon: String) -> bool:
	return weapon_mode(weapon) == "ammo"


## 距离衰减：near = 满伤距离（米），far = 衰减到 min 的距离，min = 最低伤害倍率。
## 弹丸不再按射程消失，只在超出 near 后线性衰减；狙击最缓，霰弹最陡。
const WEAPON_FALLOFF := {
	"sniper": {"near": 1.20, "far": 3.20, "min": 0.88},
	"laser": {"near": 1.00, "far": 2.60, "min": 0.82},
	"cannon": {"near": 0.80, "far": 2.60, "min": 0.70},
	"launcher": {"near": 0.80, "far": 2.60, "min": 0.78},
	"autocannon": {"near": 0.60, "far": 2.20, "min": 0.55},
	"mg": {"near": 0.50, "far": 2.00, "min": 0.50},
	"flamer": {"near": 0.40, "far": 1.30, "min": 0.18},
	"shotgun": {"near": 0.35, "far": 1.00, "min": 0.10},
	"melee": {"near": 1.00, "far": 1.20, "min": 1.00},
}


## 当前武器的距离衰减参数（米 / 倍率）；缺省按机枪
func weapon_falloff(m: Dictionary) -> Dictionary:
	var w := str(m.get("weapon", "mg"))
	var f: Dictionary = WEAPON_FALLOFF.get(w, WEAPON_FALLOFF["mg"])
	var r := maxf(weapon_range_m(m), 1.0)
	return {"near": r * float(f.near), "far": r * float(f.far), "min": float(f.min)}


## 武器类型显示名（现实枪械分类）
func weapon_type_name(weapon: String) -> String:
	match weapon:
		"mg": return Loc.t("机枪", "Machine Gun")
		"autocannon": return Loc.t("自动炮", "Autocannon")
		"cannon": return Loc.t("坦克炮 / 榴弹炮", "Cannon / Artillery")
		"shotgun": return Loc.t("霰弹枪", "Shotgun")
		"sniper": return Loc.t("狙击 / 反器材", "Sniper / AMR")
		"launcher": return Loc.t("火箭 / 导弹", "Rocket / Missile")
		"flamer": return Loc.t("火焰喷射器", "Flamethrower")
		"laser": return Loc.t("激光 / 能量武器", "Laser / Energy")
		"melee": return Loc.t("近战工程臂", "Melee Engineering Arm")
	return weapon


## 实弹通过装填时间限制持续射击；能量武器和近战保留对应能耗
func weapon_energy_cost(weapon: String) -> float:
	return 0.0 if weapon_uses_ammo(weapon) else (1.6 if weapon == "laser" else 0.3)

## 每发开火能耗：实弹为零，能量/近战按模块配置
func shot_energy_cost(m: Dictionary) -> float:
	if weapon_mode(str(m.get("weapon", ""))) == "ammo":
		return 0.0
	return maxf(0.0, float(m.get("cost", 0.3)))

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
	"supply": {"name": "补给箱", "rolls": [2, 4], "pool": {"can_food": 30, "biscuit": 28, "water_tab": 24, "coffee": 5, "toy": 6, "fuel_cell": 10, "repair_kit": 6}},
	"tool": {"name": "工具箱", "rolls": [2, 4], "pool": {"circuit": 20, "wire": 28, "bolts": 34, "hdd": 5, "repair_kit": 8, "fuel_cell": 9}},
	"military": {"name": "军用储物箱", "rolls": [1, 3], "pool": {"@module": 45, "fuel_cell": 18, "repair_kit": 14, "beacon": 5, "credit_s": 10}},
	"safe": {"name": "保险柜", "rolls": [1, 3], "pool": {"credit_s": 40, "credit_l": 15, "gold": 4, "hdd": 10, "coffee": 6}},
	"ammo": {"name": "弹药箱", "rolls": [2, 4], "pool": {"fuel_cell": 30, "energy_rod": 18, "coolant_pack": 14, "surge_cell": 8, "repair_kit": 10, "extract_flare": 7, "sonic_decoy": 6, "extract_barrier": 5, "credit_s": 8}},
	"med": {"name": "医疗箱", "rolls": [2, 3], "pool": {"repair_kit": 34, "coolant_pack": 14, "water_tab": 20, "can_food": 14, "biscuit": 10, "energy_rod": 6}},
	"tech": {"name": "技术物资箱", "rolls": [2, 3], "pool": {"circuit": 28, "wire": 16, "hdd": 14, "energy_rod": 12, "surge_cell": 8, "coolant_pack": 8, "sonic_decoy": 6}},
	"register": {"name": "结算终端", "rolls": [1, 3], "pool": {"credit_s": 52, "credit_l": 16, "hdd": 10, "gold": 5, "coffee": 6}},
	"weapon": {"name": "武器柜", "rolls": [2, 4], "pool": {"@module": 40, "fuel_cell": 20, "energy_rod": 14, "repair_kit": 12, "surge_cell": 6, "credit_s": 8}},
	"car_wreck": {"name": "车辆残骸", "rolls": [2, 3], "pool": {"wire": 20, "bolts": 20, "circuit": 10, "toy": 10, "can_food": 10, "water_tab": 8, "repair_kit": 6, "credit_s": 10, "fuel_cell": 10}},
	"container": {"name": "集装箱", "rolls": [3, 5], "pool": {"@module": 32, "fuel_cell": 18, "repair_kit": 14, "credit_s": 12, "wire": 12, "bolts": 10, "circuit": 10, "can_food": 8}},
	"cache": {"name": "埋藏桶", "rolls": [1, 2], "pool": {"bug_crystal": 24, "gen_crystal": 10, "credit_l": 12, "hdd": 10, "energy_rod": 8, "repair_kit": 8}},
	"bug": {"name": "虫尸", "rolls": [1, 1], "pool": {"chitin": 85, "bug_crystal": 12, "fuel_cell": 6}},
	"nest": {"name": "巢穴残骸", "rolls": [2, 3], "pool": {"bug_crystal": 45, "chitin": 50, "gen_crystal": 3, "legs_hex_beetle": 2}},
}

## 容器品质分档：由所在区块的「高价值容器占比」决定（military + safe 权重占比）
## ≥55% → 3 档（军事区/要塞），≥30% → 2 档（工业区/综合区），其余 → 1 档。
## 档位同时改变：出货件数、@module 权重倍率、模块稀有度权重、箱子名称与搜刮耗时。
## rar 权重按「单件概率」反推（已剔除 5 件初始装配，r0 实际池为 3 件）。
## 目标是修掉「单件 r3 比 r4 还稀有」的倒挂，同时贴近原收益，避免一次性通胀。
##   1 档单件 ≈ 7.7% / 5.1% / 0.51% / 0.263% / 0.230%
##   2 档单件 ≈ 6.6% / 5.5% / 0.69% / 0.331% / 0.298%
##   3 档单件 ≈ 3.9% / 3.9% / 0.86% / 0.463% / 0.453%
const LOOT_TIER := {
	1: {"rolls": 0, "module": 1.0, "rar": [2.5, 5.0, 2.0, 1.2, 0.15]},
	2: {"rolls": 0, "module": 1.15, "rar": [2.0, 5.0, 2.5, 1.4, 0.18]},
	3: {"rolls": 1, "module": 1.40, "rar": [1.5, 5.0, 4.0, 2.5, 0.35]},
}

## 按档位给箱子换写实名字（不用「精良/精英」这种 RPG 标签）
const LOOT_NAMES := {
	"supply": ["补给箱", "军需补给箱", "野战补给栈"],
	"tool": ["工具箱", "维修工具箱", "工兵器材柜"],
	"military": ["军用储物箱", "军械箱", "指挥所军械柜"],
	"safe": ["保险柜", "加固保险柜", "加密保管柜"],
	"ammo": ["弹药箱", "军需弹药箱", "装甲弹药柜"],
	"med": ["医疗箱", "野战医疗箱", "医疗储备柜"],
	"tech": ["技术箱", "技术物资箱", "研究器材柜"],
	"register": ["收银机", "加密收银机", "加密结算终端"],
	"weapon": ["武器架", "军械武器架", "指挥所武器柜"],
	"car_wreck": ["废弃轿车", "塞满杂物的轿车", "满载轿车残骸"],
	"container": ["废弃集装箱", "军用集装箱", "武装集装箱"],
	"cache": ["埋藏桶", "加固埋藏桶", "密封埋藏桶"],
	"bug": ["虫尸", "虫尸", "虫尸"],
	"nest": ["巢穴残骸", "巢穴残骸", "巢穴残骸"],
}
const LOOT_NAMES_EN := {
	"supply": ["Supply Crate", "Military Supply Crate", "Field Supply Cache"],
	"tool": ["Toolbox", "Maintenance Chest", "Engineer Locker"],
	"military": ["Military Crate", "Arms Crate", "Command Armory Locker"],
	"safe": ["Safe", "Reinforced Safe", "Encrypted Storage Locker"],
	"ammo": ["Ammo Box", "Military Ammo Crate", "Armored Ammo Locker"],
	"med": ["Medkit Crate", "Field Medbag", "Medical Reserve Locker"],
	"tech": ["Tech Crate", "Technical Supply Crate", "Research Locker"],
	"register": ["Cash Register", "Encrypted Register", "Encrypted Settlement Terminal"],
	"weapon": ["Weapon Rack", "Arms Rack", "Command Weapon Locker"],
	"car_wreck": ["Abandoned Car", "Cluttered Car", "Loaded Car Wreck"],
	"container": ["Abandoned Container", "Military Container", "Armed Container"],
	"cache": ["Buried Barrel", "Reinforced Barrel", "Sealed Cache"],
	"bug": ["Bug Carcass", "Bug Carcass", "Bug Carcass"],
	"nest": ["Nest Remains", "Nest Remains", "Nest Remains"],
}


## 每件物资的基础搜刮耗时（秒）：高档箱要拆装甲锁具，站桩时间明显更长
## 实际耗时 = 基础 × 精英专精 ab_search 系数 × 底盘承重破拆系数
const LOOT_TIER_TIME := {1: 0.55, 2: 1.00, 3: 2.00}

## 稀有产出层：每件物资有小概率改从稀有池抽取，让低级箱也有开出高价值物品的惊喜。
## 稀有池平均价值约 ¥570（3 档约 ¥660），单箱期望 +¥57~+¥344。
## 抽中「@module」时按当前档位抽模块——补给箱/医疗箱也可能开出军械。
const RARE_POOL := {
	"credit_l": 30, "hdd": 20, "energy_rod": 12, "surge_cell": 10,
	"coffee": 8, "@module": 14,
}
const RARE_CHANCE := 0.05
const RARE_TIER_MUL := {1: 1.0, 2: 1.6, 3: 2.6}


func rare_chance(tier: int) -> float:
	return RARE_CHANCE * float(RARE_TIER_MUL.get(clampi(tier, 1, 3), 1.0))


## 箱子显示名：按所在区块档位取对应写实名称（bug/nest 等无档位的保持原名）
func loot_title(kind: String, tier: int) -> String:
	var zh: Array = LOOT_NAMES.get(kind, [])
	var en: Array = LOOT_NAMES_EN.get(kind, [])
	if zh.is_empty():
		return str(LOOT_TABLES.get(kind, {}).get("name", kind))
	var i := clampi(tier - 1, 0, zh.size() - 1)
	return Loc.t(str(zh[i]), str(en[mini(i, en.size() - 1)]))

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
var mech_paint: Dictionary = MechPaint.default_config()
var raids := 0
## 画质：0 流畅 / 1 高 / 2 极致（新存档默认“高”：极致档 1.5 倍超采样 + MSAA4x + TAA + SSIL，中端显卡压力过大）
const _ZH_QUALITY_NAMES := ["流畅", "高", "极致"]
var QUALITY_NAMES := _ZH_QUALITY_NAMES.duplicate()
var quality := 1
var render_style := 0  # 0 写实 1 三渲二
var view_mode := 2     # 0 斜俯视 1 第一人称 2 第三人称越肩 (B.o.T)
var mouse_sens := 1.0  # 鼠标视角灵敏度倍率（0.2 ~ 2.5）
var show_fps := false  # 右上角显示实时 FPS
var _has_global_show_fps := false
var render_scale_mode := 0  # 0 自动（4K+高分屏FSR优化）/ 1 100%原生 / 2 85% / 3 75% / 4 67%
var _has_global_render_scale := false
var _cfg_save_t: Timer
var map_id := "greyport"  ## 出击战区
var extracts_ok := 0
## 遭遇过的敌人种类（跨行动累计，随存档保存）
var seen_enemies: Array = []
## 玩家在出击前地区侦察图上自定义打点与手写备注（随存档保存，进图后同步显示在战区战术图与雷达上）
const MAP_MARKER_MAX := 60
const MAP_MARKER_COLORS := {
	"amber": Color("f0b95a"),
	"red": Color("ef5a5a"),
	"cyan": Color("58d1e8"),
	"green": Color("6fe39c"),
	"purple": Color("c988ff"),
}
var map_markers: Array = []
var _marker_seq := 0

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
	_load_global_ui_prefs()
	_cfg_save_t = Timer.new()
	_cfg_save_t.one_shot = true
	_cfg_save_t.wait_time = 0.35
	_cfg_save_t.timeout.connect(save_game)
	add_child(_cfg_save_t)
	_merge_content()
	for id in MODULES:
		var mod: Dictionary = MODULES[id]
		if str(mod.get("slot", "")) == "arm":
			mod["cost"] = shot_energy_cost(mod)
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
	call_deferred("_bind_viewport_resize")


var _managed_vps: Array[WeakRef] = []
var _resize_recheck_pending := false


func _bind_viewport_resize() -> void:
	var root_vp := get_tree().root if get_tree() else null
	if root_vp != null and not root_vp.size_changed.is_connected(_on_root_viewport_resized):
		root_vp.size_changed.connect(_on_root_viewport_resized)


func _on_root_viewport_resized() -> void:
	call_deferred("_reapply_all_viewports")
	if not _resize_recheck_pending and get_tree() != null:
		_resize_recheck_pending = true
		get_tree().create_timer(0.12).timeout.connect(_on_resize_recheck_timeout)


func _on_resize_recheck_timeout() -> void:
	_resize_recheck_pending = false
	_reapply_all_viewports()


func _register_managed_vp(vp: Viewport) -> void:
	if not (vp is SubViewport):
		return
	var id := vp.get_instance_id()
	var alive: Array[WeakRef] = []
	var found := false
	for r: WeakRef in _managed_vps:
		var obj = r.get_ref()
		if obj != null and is_instance_valid(obj):
			alive.append(r)
			if obj.get_instance_id() == id:
				found = true
	if not found:
		alive.append(weakref(vp))
	_managed_vps = alive


func _reapply_all_viewports() -> void:
	if get_tree() == null:
		return
	apply_quality(get_tree().root)
	var alive: Array[WeakRef] = []
	for r: WeakRef in _managed_vps:
		var obj = r.get_ref()
		if obj != null and is_instance_valid(obj) and obj is SubViewport:
			alive.append(r)
			var sv := obj as SubViewport
			if sv.has_meta("_hires_owner"):
				var owner_ref: Variant = sv.get_meta("_hires_owner")
				var owner = owner_ref.get_ref() if owner_ref is WeakRef else null
				if owner != null and is_instance_valid(owner) and owner.has_method("_fit"):
					owner._fit()
					continue
			apply_quality(sv)
	_managed_vps = alive


func refresh_all_viewports() -> void:
	_reapply_all_viewports()


## 统一切换全屏/窗口：切全屏前在同一帧预先配置目标分辨率的缩放与 MSAA，
## 避免 Vulkan/VMA 先按原生 4K 分配超大渲染目标、下一帧再二次分配导致 1.5~2GB 显存滞留触发 WDDM 换页卡顿。
func set_fullscreen(on: bool) -> void:
	if on:
		var scr_idx := DisplayServer.window_get_current_screen()
		var target_sz := DisplayServer.screen_get_size(scr_idx)
		if target_sz.x > 0 and target_sz.y > 0 and get_tree() != null:
			apply_quality(get_tree().root, true, target_sz)
			for r: WeakRef in _managed_vps:
				var obj = r.get_ref()
				if obj != null and is_instance_valid(obj) and obj is SubViewport:
					var sv := obj as SubViewport
					if sv.has_meta("_hires_owner"):
						var owner_ref: Variant = sv.get_meta("_hires_owner")
						var owner = owner_ref.get_ref() if owner_ref is WeakRef else null
						if owner != null and is_instance_valid(owner) and owner.has_method("prepare_for_window_size"):
							owner.prepare_for_window_size(target_sz)
							continue
					apply_quality(sv, true, target_sz)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		call_deferred("_reapply_all_viewports")


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
	_key("toggle_view", [KEY_F5])
	_key("swap_shoulder", [KEY_Q])            # Q：越肩视角切换左右肩位
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
## f(stats: Dictionary, loadout: Dictionary) -> void：在 compute_stats 算完模块数值后原地修改结果（驾驶员等级、设施加成等）
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

## 区块危险度分档：按该区容器权重里 military + safe 的占比判定（与 LOOT_W 同源）
func zone_tier(weights: Dictionary) -> int:
	var total := 0.0
	var rich := 0.0
	for k in weights:
		var w := float(weights[k])
		total += w
		if str(k) == "military" or str(k) == "safe":
			rich += w
	if total <= 0.0:
		return 1
	var share := rich / total
	if share >= 0.55:
		return 3
	if share >= 0.30:
		return 2
	return 1


func roll_loot(table: String, rng: RandomNumberGenerator, tier := 1) -> Array:
	var t: Dictionary = LOOT_TABLES[table]
	var tr: Dictionary = LOOT_TIER.get(clampi(tier, 1, 3), LOOT_TIER[1]) as Dictionary
	var n := rng.randi_range(int(t.rolls[0]) + int(tr.rolls), int(t.rolls[1]) + int(tr.rolls))
	var pool: Dictionary = (t.pool as Dictionary).duplicate()
	if pool.has("@module"):
		pool["@module"] = float(pool["@module"]) * float(tr.module)
	var out: Array = []
	for i in n:
		var id: String
		if rng.randf() < rare_chance(tier):
			# 稀有产出层：普通箱小概率开出高价值物品（信用芯片/硬盘/能量棒/反应炉/模块）
			id = _weighted(RARE_POOL, rng)
		else:
			id = _weighted(pool, rng)
		if id == "@module":
			id = _random_module(rng, tier)
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

func _random_module(rng: RandomNumberGenerator, tier := 1) -> String:
	var weights := {}
	var tr: Dictionary = LOOT_TIER.get(clampi(tier, 1, 3), LOOT_TIER[1]) as Dictionary
	var rw: Array = tr.rar
	# 初始装配不出现在战利品池里，避免开局反复掉到已经在穿的东西
	var skip := {}
	for k in STARTER.values():
		skip[str(k)] = true
	for id in MODULES:
		if skip.has(str(id)):
			continue
		weights[str(id)] = rw[int(MODULES[id].rar)]
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
				if not (tgt == "broodmother" and target_value in ["grey_brood", "dust_matriarch", "harbor_reaper", "dune_devourer", "prism_archon", "terminus_warden", "silo_warhead", "spillway_leviathan"]) and not (tgt == "king_beetle" and target_value in ["iron_warden", "slag_colossus", "gorge_tyrant", "foundry_dreadnought", "excavator_titan", "drydock_behemoth", "citadel_behemoth", "sky_carrier"]) and not (tgt == "abyss_queen" and target_value in ["abyss_harbinger", "core_overlord", "citadel_behemoth", "sky_carrier"]):
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


# ---------- 玩家自定义地图标记 ----------
func marker_color(key: String) -> Color:
	return MAP_MARKER_COLORS.get(key, MAP_MARKER_COLORS["amber"]) as Color


func _sanitize_marker_text(raw: String) -> String:
	var s := raw.replace("\n", " ").replace("\r", " ").strip_edges()
	if s.length() > 32:
		s = s.substr(0, 32)
	return s


func _sanitize_marker_color(key: String) -> String:
	return key if MAP_MARKER_COLORS.has(key) else "amber"


func _next_marker_id() -> String:
	_marker_seq += 1
	return "mk_%d_%d" % [Time.get_ticks_msec(), _marker_seq]


func add_map_marker(sector_id: String, world_pos: Vector2, local_pos: Vector2, text: String, color_key := "amber") -> Dictionary:
	var clean_text := _sanitize_marker_text(text)
	if clean_text.is_empty():
		clean_text = Loc.t("自定义标记", "Custom Pin")
	var entry := {
		"id": _next_marker_id(),
		"map_id": sector_id,
		"wx": snappedf(world_pos.x, 0.1),
		"wz": snappedf(world_pos.y, 0.1),
		"lx": snappedf(local_pos.x, 0.1),
		"lz": snappedf(local_pos.y, 0.1),
		"text": clean_text,
		"color": _sanitize_marker_color(color_key),
	}
	if map_markers.size() >= MAP_MARKER_MAX:
		map_markers.remove_at(0)
	map_markers.append(entry)
	save_game()
	return entry


func update_map_marker(marker_id: String, text: String, color_key: String) -> bool:
	var clean_text := _sanitize_marker_text(text)
	if clean_text.is_empty():
		clean_text = Loc.t("自定义标记", "Custom Pin")
	var col := _sanitize_marker_color(color_key)
	for m in map_markers:
		if typeof(m) == TYPE_DICTIONARY and str(m.get("id", "")) == marker_id:
			m["text"] = clean_text
			m["color"] = col
			save_game()
			return true
	return false


func remove_map_marker(marker_id: String) -> bool:
	for i in range(map_markers.size() - 1, -1, -1):
		var m = map_markers[i]
		if typeof(m) == TYPE_DICTIONARY and str(m.get("id", "")) == marker_id:
			map_markers.remove_at(i)
			save_game()
			return true
	return false


func clear_map_markers(sector_id := "") -> void:
	if sector_id == "":
		map_markers.clear()
	else:
		var kept: Array = []
		for m in map_markers:
			if typeof(m) == TYPE_DICTIONARY and str(m.get("map_id", "")) != sector_id:
				kept.append(m)
		map_markers = kept
	save_game()


func markers_for_map(sector_id: String) -> Array:
	var out: Array = []
	for m in map_markers:
		if typeof(m) == TYPE_DICTIONARY and str(m.get("map_id", "")) == sector_id:
			out.append(m)
	return out


func _sanitize_loaded_markers(raw_list: Array) -> Array:
	var out: Array = []
	for raw in raw_list:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = raw
		var mid := str(d.get("id", ""))
		if mid.is_empty():
			mid = _next_marker_id()
		var txt := _sanitize_marker_text(str(d.get("text", "")))
		if txt.is_empty():
			txt = Loc.t("自定义标记", "Custom Pin")
		out.append({
			"id": mid,
			"map_id": str(d.get("map_id", "")),
			"wx": float(d.get("wx", 0.0)),
			"wz": float(d.get("wz", 0.0)),
			"lx": float(d.get("lx", 0.0)),
			"lz": float(d.get("lz", 0.0)),
			"text": txt,
			"color": _sanitize_marker_color(str(d.get("color", "amber"))),
		})
		if out.size() >= MAP_MARKER_MAX:
			break
	return out


# ---------- 存档 ----------
func new_game() -> void:
	money = 1500
	loadout = STARTER.duplicate()
	mech_paint = MechPaint.default_config()
	stash = ["fuel_cell", "fuel_cell", "repair_kit", "beacon", "arm_shotgun", "can_food"]
	cargo = ["fuel_cell", "repair_kit", "beacon"]
	raids = 0
	extracts_ok = 0
	seen_enemies = []
	map_markers = []
	if OS.has_feature("mobile") or OS.has_feature("web"):
		quality = 0
	quests = {}
	quest_state = {}
	quest_progress = {}
	_sections_data = {}
	for k in _sections:
		_sections[k][1].call({})
	save_game()

## 存档载荷：顶层进度字段 + meta（当前存档位、保存时刻、驾驶员名）+ 各分区
func _payload() -> Dictionary:
	var sec: Dictionary = _sections_data.duplicate()
	for k in _sections:
		sec[k] = _sections[k][0].call()
	var prog: Dictionary = sec.get("progress", {}) if typeof(sec.get("progress", {})) == TYPE_DICTIONARY else {}
	return {"money": money, "stash": stash, "cargo": cargo, "loadout": loadout, "mech_paint": mech_paint,
		"raids": raids, "extracts_ok": extracts_ok, "quest_state": quest_state, "quest_progress": quest_progress, "quests": quests, "quality": quality, "render_style": render_style, "view_mode": view_mode, "mouse_sens": mouse_sens, "show_fps": show_fps, "render_scale_mode": render_scale_mode, "map_id": map_id,
		"seen_enemies": seen_enemies, "map_markers": map_markers, "sections": sec,
		"meta": {"slot": slot, "saved_at": Time.get_unix_time_from_system(), "name": str(prog.get("player_name", ""))}}

func _load_global_ui_prefs() -> void:
	_has_global_show_fps = false
	_has_global_render_scale = false
	if test_mode:
		return
	var cfg := ConfigFile.new()
	if cfg.load(UI_CFG_PATH) == OK:
		if cfg.has_section_key("video", "show_fps"):
			show_fps = bool(cfg.get_value("video", "show_fps", false))
			_has_global_show_fps = true
		if cfg.has_section_key("video", "render_scale_mode"):
			render_scale_mode = clampi(int(cfg.get_value("video", "render_scale_mode", 0)), 0, 4)
			_has_global_render_scale = true

func set_show_fps(on: bool) -> void:
	show_fps = on
	if not test_mode:
		var cfg := ConfigFile.new()
		cfg.load(UI_CFG_PATH)
		cfg.set_value("video", "show_fps", show_fps)
		cfg.save(UI_CFG_PATH)
		_has_global_show_fps = true
	save_game()
	show_fps_changed.emit(show_fps)

func set_render_scale_mode(mode: int) -> void:
	render_scale_mode = clampi(mode, 0, 4)
	if not test_mode:
		var cfg := ConfigFile.new()
		cfg.load(UI_CFG_PATH)
		cfg.set_value("video", "render_scale_mode", render_scale_mode)
		cfg.save(UI_CFG_PATH)
		_has_global_render_scale = true
	save_game()

func render_scale_options() -> Array:
	return [
		Loc.t("自动（高分屏优化）", "Auto (HiDPI)"),
		Loc.t("100%（原生）", "100% (Native)"),
		"85%",
		"75%",
		"67%",
	]

func schedule_save() -> void:
	if _closing or _cfg_save_t == null:
		return
	_cfg_save_t.start()

func save_game() -> void:
	if _closing:
		return
	_write_payload(save_path, _payload())

## 把当前进度复制写到指定存档位；不改变当前活动位，后续自动存档仍写活动位
func save_to_slot(i: int) -> void:
	if _closing or i < 1 or i > SAVE_SLOT_COUNT:
		return
	_write_payload(slot_path(i), _payload())

func _write_payload(path: String, payload: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(payload))

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
	for old_item in Array(d.get("stash", [])) + Array(d.get("cargo", [])):
		money += int(LEGACY_MAG_REFUND.get(base_id(str(old_item)), 0))
	stash = _migrate_item_list(Array(d.get("stash", [])))
	cargo = _migrate_item_list(Array(d.get("cargo", [])))
	loadout = Dictionary(d.get("loadout", STARTER.duplicate()))
	for slot_k: String in STARTER:
		var cur_id := _migrate_item_id(str(loadout.get(slot_k, STARTER[slot_k])))
		loadout[slot_k] = cur_id if MODULES.has(cur_id) else STARTER[slot_k]
	mech_paint = MechPaint.sanitize(d.get("mech_paint", {}))
	raids = int(d.get("raids", 0))
	quality = int(d.get("quality", 0 if OS.has_feature("mobile") or OS.has_feature("web") else 1))
	render_style = int(d.get("render_style", 0))
	view_mode = clampi(int(d.get("view_mode", 2)), 0, 2)
	mouse_sens = clampf(float(d.get("mouse_sens", 1.0)), 0.2, 2.5)
	if not _has_global_show_fps and d.has("show_fps"):
		show_fps = bool(d.get("show_fps", false))
	if not _has_global_render_scale and d.has("render_scale_mode"):
		render_scale_mode = clampi(int(d.get("render_scale_mode", 0)), 0, 4)
	show_fps_changed.emit(show_fps)
	map_id = str(d.get("map_id", "greyport"))
	extracts_ok = int(d.get("extracts_ok", 0))
	seen_enemies = Array(d.get("seen_enemies", []))
	map_markers = _sanitize_loaded_markers(Array(d.get("map_markers", [])))
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
	"core_ka52_alligator": "core_fennek_recon",
	"core_mi24_hind": "core_assault",
	"core_trieste_bathy": "core_fortress",
	"gen_naval_pwr_s9g": "gen_reactor",
	"gen_stirling_aip": "gen_hfc",
}

func _migrate_item_id(id: String) -> String:
	var b := base_id(id)
	if _LEGACY_ID_MAP.has(b):
		return str(_LEGACY_ID_MAP[b]) + id.substr(b.length())
	return id

func _migrate_item_list(arr: Array) -> Array:
	var out: Array = []
	for raw in arr:
		var id := _migrate_item_id(str(raw))
		if LEGACY_MAG_REFUND.has(base_id(id)):
			continue
		out.append(id)
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
		# 跨启动保留的当前存档位；缺省 1
		slot = clampi(int(FileAccess.get_file_as_string(SLOT_CFG).strip_edges()) if FileAccess.file_exists(SLOT_CFG) else 1, 1, SAVE_SLOT_COUNT)
		# 旧的单文件存档只迁到 1 号位一次：1 号位不存在而单文件存在时复制，旧文件保留
		var legacy := "user://" + SAVE_FILE
		if not FileAccess.file_exists(slot_path(1)) and FileAccess.file_exists(legacy):
			DirAccess.copy_absolute(legacy, slot_path(1))
		migrate_legacy_save(OS.get_user_data_dir(), LEGACY_DATA_DIRS)
		save_path = slot_path(slot)

## 第 i 存档位的存档文件路径；测试运行统一指到按进程号隔离的临时存档，真实存档不被读写
func slot_path(i: int) -> String:
	if test_mode:
		return save_path
	return "user://save_slot_%d.json" % clampi(i, 1, SAVE_SLOT_COUNT)

## 切换当前活动存档位并持久化；活动位接收行动中的全部自动存档
func set_slot(i: int) -> void:
	slot = clampi(i, 1, SAVE_SLOT_COUNT)
	save_path = slot_path(slot)
	if not test_mode:
		var f := FileAccess.open(SLOT_CFG, FileAccess.WRITE)
		if f != null:
			f.store_string(str(slot))

## 读某个存档位的概要（只解析文件，不改内存状态）；位上没有存档时 exists 为 false
func slot_info(i: int) -> Dictionary:
	var p := slot_path(i)
	if not FileAccess.file_exists(p):
		return {"exists": false, "slot": i}
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	if typeof(d) != TYPE_DICTIONARY:
		return {"exists": false, "slot": i}
	var meta: Dictionary = d.get("meta", {}) if typeof(d.get("meta", {})) == TYPE_DICTIONARY else {}
	var prog: Dictionary = (d.get("sections", {}) as Dictionary).get("progress", {}) if typeof((d.get("sections", {}) as Dictionary).get("progress", {})) == TYPE_DICTIONARY else {}
	var at: int = int(meta.get("saved_at", 0)) if int(meta.get("saved_at", 0)) > 0 else int(FileAccess.get_modified_time(p))
	return {"exists": true, "slot": i,
		"name": str(meta.get("name", prog.get("player_name", ""))),
		"money": int(d.get("money", 0)),
		"raids": int(d.get("raids", 0)),
		"extracts_ok": int(d.get("extracts_ok", 0)),
		"saved_at": at}

## 任意存档位上有存档（主菜单「载入游戏」的可用性）
func has_any_save() -> bool:
	for i in range(1, SAVE_SLOT_COUNT + 1):
		if FileAccess.file_exists(slot_path(i)):
			return true
	return false

## unix 时间 → 短格式（MM-dd HH:mm）
static func fmt_save_time(unix: int) -> String:
	if unix <= 0:
		return ""
	var s := Time.get_datetime_string_from_unix_time(unix, false)
	return s.substr(5, 11).replace("T", " ") if s.length() >= 16 else s

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


## 按画质档位调整战场环境的重型后处理（保证低画质/移动端也具备清晰柔影、自发光辉光、色彩统一与无锯齿质感）。
## 流畅(0)：柔化中档 4096 阴影（移动端 2048 双分段柔影）+ 保留 SSAO/轻量辉光/LUT；高(1)：+SSR；极致(2)：+SSIL + 8192 阴影。
func apply_env_quality(env: Environment, sun: DirectionalLight3D = null) -> void:
	var mob := OS.has_feature("mobile") or OS.has_feature("web")
	var mobile_renderer := RenderingServer.get_current_rendering_method() == "mobile"
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	if mob or mobile_renderer:
		env.volumetric_fog_enabled = false
		env.ssr_enabled = false
		env.ssil_enabled = false
		env.ssao_enabled = false
		env.glow_enabled = not OS.has_feature("web") or quality >= 1
		env.glow_intensity = 0.20 if quality == 0 else 0.25
		env.set_glow_level(0, 0.0)
		env.set_glow_level(1, 0.58)
		env.set_glow_level(2, 0.40)
		env.set_glow_level(3, 0.0 if quality == 0 else 0.24)
		env.set_glow_level(4, 0.0)
		env.set_glow_level(5, 0.0)
		RenderingServer.directional_shadow_atlas_set_size(2048 if quality <= 1 else 4096, true)
		RenderingServer.directional_soft_shadow_filter_set_quality(
			RenderingServer.SHADOW_QUALITY_SOFT_LOW if quality == 0 else RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
		RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
		if sun:
			sun.shadow_bias = 0.06 if quality == 0 else 0.05
			sun.shadow_normal_bias = 2.20 if quality == 0 else 1.90
			sun.light_angular_distance = 0.20 if quality == 0 else 0.26
			sun.shadow_blur = 0.72 if quality == 0 else 0.80
			sun.directional_shadow_blend_splits = quality >= 1
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_split_1 = 0.48
			sun.directional_shadow_max_distance = 52.0 if quality == 0 else (62.0 if quality == 1 else 74.0)
		RenderingServer.camera_attributes_set_dof_blur_quality(RenderingServer.DOF_BLUR_QUALITY_VERY_LOW, false)
		return
	match quality:
		0:
			env.volumetric_fog_enabled = false
			env.ssr_enabled = false
			env.ssil_enabled = false
			env.ssao_enabled = not compat and not mobile_renderer
			env.ssao_radius = 1.40
			env.ssao_intensity = 1.32
			env.ssao_power = 1.24
			env.ssao_detail = 0.56
			env.ssao_sharpness = 0.90
			env.ssao_light_affect = 0.09
			env.glow_enabled = true
			env.set_glow_level(0, 0.20)
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, true, 0.35, 1, 40.0, 120.0)
			RenderingServer.environment_glow_set_use_bicubic_upscale(false)
			RenderingServer.camera_attributes_set_dof_blur_quality(RenderingServer.DOF_BLUR_QUALITY_LOW, false)
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
			if sun:
				sun.shadow_bias = 0.045
				sun.shadow_normal_bias = 1.45
				sun.light_angular_distance = 0.55
				sun.shadow_blur = 1.30
				sun.directional_shadow_blend_splits = false
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
				sun.directional_shadow_split_1 = 0.38
				sun.directional_shadow_max_distance = 96.0
				sun.directional_shadow_fade_start = 0.86
		1:
			env.volumetric_fog_enabled = false
			env.ssr_enabled = false
			env.ssil_enabled = false
			env.ssao_enabled = not compat and not mobile_renderer
			env.ssao_radius = 1.25
			env.ssao_intensity = 1.72
			env.ssao_power = 1.32
			env.ssao_detail = 0.72
			env.ssao_sharpness = 0.92
			env.ssao_light_affect = 0.24
			env.glow_enabled = true
			env.set_glow_level(0, 0.20)
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW, true, 0.5, 1, 60.0, 180.0)
			RenderingServer.environment_glow_set_use_bicubic_upscale(false)
			RenderingServer.camera_attributes_set_dof_blur_quality(RenderingServer.DOF_BLUR_QUALITY_LOW, false)
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			if sun:
				sun.shadow_bias = 0.022
				sun.shadow_normal_bias = 0.34
				sun.light_angular_distance = 0.46
				sun.shadow_blur = 0.86
				sun.directional_shadow_blend_splits = false
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
				sun.directional_shadow_split_1 = 0.34
				sun.directional_shadow_max_distance = 118.0
				sun.directional_shadow_fade_start = 0.86
		_:
			env.volumetric_fog_enabled = false
			env.ssr_enabled = not compat and not mobile_renderer
			env.ssr_max_steps = 20
			env.ssil_enabled = not compat and not mobile_renderer
			env.ssil_radius = 3.6
			env.ssil_intensity = 0.48
			env.ssil_sharpness = 0.90
			env.ssil_normal_rejection = 1.0
			env.ssao_enabled = not compat and not mobile_renderer
			env.ssao_radius = 1.35
			env.ssao_intensity = 1.85
			env.ssao_power = 1.34
			env.ssao_detail = 0.78
			env.ssao_sharpness = 0.92
			env.ssao_light_affect = 0.28
			env.glow_enabled = true
			env.set_glow_level(0, 0.22)
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 1, 75.0, 220.0)
			RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_LOW, true, 0.5, 2, 50.0, 150.0)
			RenderingServer.environment_glow_set_use_bicubic_upscale(true)
			RenderingServer.camera_attributes_set_dof_blur_quality(RenderingServer.DOF_BLUR_QUALITY_MEDIUM, true)
			RenderingServer.directional_shadow_atlas_set_size(8192, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			if sun:
				sun.shadow_bias = 0.018
				sun.shadow_normal_bias = 0.28
				sun.light_angular_distance = 0.44
				sun.shadow_blur = 0.78
				sun.directional_shadow_blend_splits = true
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
				sun.directional_shadow_split_1 = 0.12
				sun.directional_shadow_split_2 = 0.30
				sun.directional_shadow_split_3 = 0.58
				sun.directional_shadow_max_distance = 145.0
				sun.directional_shadow_fade_start = 0.88


## 计算桌面端 3D 渲染缩放倍率（统一用于主视口与 HiResView 子视口）。
func compute_desktop_scale(pixel_size: Vector2i, allow_auto_scale := true) -> float:
	match render_scale_mode:
		1:
			return 1.0
		2:
			return 0.85
		3:
			return 0.75
		4:
			return 0.67
		_:
			if allow_auto_scale:
				# 以总像素限制自动档，覆盖 4K/超宽屏和菜单、机库的子视口。
				var target_height: float = [960.0, 1080.0, 1260.0][clampi(quality, 0, 2)]
				var pixel_budget := target_height * target_height * (16.0 / 9.0)
				return clampf(sqrt(pixel_budget / maxf(1.0, float(pixel_size.x) * pixel_size.y)), 0.25, 1.0)
			return 1.0


## 应用抗锯齿 / 渲染缩放到主视口或子视口。
## 自动档以 960/1080/1260p 等效像素预算限制 3D，超过预算使用缩放；UI 保持原生分辨率。
## 显式选择 100% 原生时不自动缩放。
func apply_quality(vp: Viewport = null, allow_auto_scale := true, target_pixel_size := Vector2i.ZERO, skip_scale := false) -> void:
	if vp == null:
		vp = get_tree().root
	_register_managed_vp(vp)
	if not skip_scale and vp is SubViewport and vp.has_meta("_hires_owner") and not OS.has_feature("web") and not OS.has_feature("mobile"):
		var owner_ref: Variant = vp.get_meta("_hires_owner")
		var owner = owner_ref.get_ref() if owner_ref is WeakRef else null
		if owner != null and is_instance_valid(owner) and owner.has_method("_fit"):
			owner._fit(allow_auto_scale, target_pixel_size)
			return
	if OS.has_feature("web"):
		Engine.max_fps = 60
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		vp.use_taa = false
		vp.msaa_3d = Viewport.MSAA_DISABLED if quality == 0 else Viewport.MSAA_2X
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		var pixels := DisplayServer.window_get_size()
		var pixel_height := maxi(1, mini(pixels.x, pixels.y))
		var target_height: float = [720.0, 900.0, 1080.0][clampi(quality, 0, 2)]
		vp.scaling_3d_scale = clampf(target_height / pixel_height, 0.25, 1.0)
		vp.anisotropic_filtering_level = Viewport.ANISOTROPY_4X
		return
	if OS.has_feature("mobile"):
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		vp.use_taa = false
		vp.msaa_3d = Viewport.MSAA_2X if quality >= 1 else Viewport.MSAA_DISABLED
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		vp.fsr_sharpness = 0.45
		var win_h := float(maxi(720, DisplayServer.window_get_size().y))
		match quality:
			0:
				vp.scaling_3d_scale = clampf(minf(0.84, 780.0 / win_h), 0.76, 0.84)
				vp.anisotropic_filtering_level = Viewport.ANISOTROPY_4X
			1:
				vp.scaling_3d_scale = clampf(minf(0.92, 920.0 / win_h), 0.84, 0.92)
				vp.anisotropic_filtering_level = Viewport.ANISOTROPY_8X
			_:
				vp.scaling_3d_scale = 1.0
				vp.anisotropic_filtering_level = Viewport.ANISOTROPY_8X
		return
	# 桌面端：先确定实际内部 3D 渲染分辨率，再按像素密度自适应 MSAA；高分屏统一 2x MSAA 避免全屏切换触发 4x/2x VMA 显存池重分配
	if vp.screen_space_aa != Viewport.SCREEN_SPACE_AA_DISABLED:
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	if vp.use_taa:
		vp.use_taa = false
	var pixel_size: Vector2i
	if target_pixel_size.x > 0 and target_pixel_size.y > 0:
		pixel_size = target_pixel_size
	elif vp is SubViewport:
		pixel_size = (vp as SubViewport).size
	else:
		var win_px: Vector2i = DisplayServer.window_get_size()
		var vp_px: Vector2i = (vp as Window).size if vp is Window else Vector2i(vp.get_visible_rect().size)
		pixel_size = win_px if (win_px.x > 0 and win_px.y > 0) else vp_px
		if vp_px.x * vp_px.y > pixel_size.x * pixel_size.y:
			pixel_size = vp_px
	var scale := 1.0 if skip_scale else compute_desktop_scale(pixel_size, allow_auto_scale)
	var rt_h := float(pixel_size.y) * scale
	var scr_h := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen()).y
	var want_msaa: Viewport.MSAA = Viewport.MSAA_2X
	var want_aniso: Viewport.AnisotropicFiltering = Viewport.ANISOTROPY_8X
	match quality:
		0:
			want_msaa = Viewport.MSAA_DISABLED if rt_h >= 1200.0 else Viewport.MSAA_2X
			want_aniso = Viewport.ANISOTROPY_4X
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, true, 0.35, 1, 40.0, 120.0)
			RenderingServer.environment_glow_set_use_bicubic_upscale(false)
		1:
			want_msaa = Viewport.MSAA_2X
			want_aniso = Viewport.ANISOTROPY_8X
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW, true, 0.5, 1, 50.0, 160.0)
			RenderingServer.environment_glow_set_use_bicubic_upscale(false)
		_:
			want_msaa = Viewport.MSAA_4X if (rt_h <= 1120.0 and scr_h <= 1200) else Viewport.MSAA_2X
			want_aniso = Viewport.ANISOTROPY_16X
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 1, 60.0, 180.0)
			RenderingServer.environment_glow_set_use_bicubic_upscale(true)
	if vp.msaa_3d != want_msaa:
		vp.msaa_3d = want_msaa
	if vp.anisotropic_filtering_level != want_aniso:
		vp.anisotropic_filtering_level = want_aniso
	var want_mode: Viewport.Scaling3DMode = Viewport.SCALING_3D_MODE_FSR if scale < 0.995 else Viewport.SCALING_3D_MODE_BILINEAR
	var want_scale := scale if scale < 0.995 else 1.0
	if vp.scaling_3d_mode != want_mode:
		vp.scaling_3d_mode = want_mode
	if want_mode == Viewport.SCALING_3D_MODE_FSR and not is_equal_approx(vp.fsr_sharpness, 0.28):
		vp.fsr_sharpness = 0.28
	if not is_equal_approx(vp.scaling_3d_scale, want_scale):
		vp.scaling_3d_scale = want_scale
