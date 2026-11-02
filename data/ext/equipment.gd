extends RefCounted
## 装备扩展数据：启动时由 GameData 并入核心表（规则见 scripts\game_data.gd 的「内容注册」一节）。
##
## MODULES  模块，字段与 GameData.MODULES 相同：name / slot（core legs arm back gen）/ w / v / rar（0..3）/ color，
##          以及按槽位的数值字段（躯干 hp cargo drain；底盘 speed load drain type；武器 weapon dmg rate cost spread speed range；
##          背部 ability cd cost；动力炉 energy eff）。建模脚本放 scripts\modules\<模块 id>.gd。
## ITEMS    消耗品或普通物品：name / cat（food misc use money）/ w / v / rar / desc；
##          消耗品加 script = 路径，脚本写 static func use(mech, id) -> bool（返回 true 时扣除一件，音效 use_<物品 id>）。
## AMMO     武器类型的弹匣：mag / reload / tex（assets\ui 下的子弹贴图名），持续喷射类加 fire_loop = true；
##          新弹道加 script = 路径，脚本写 static func fire(mech, slot, origin, dir, m)，负责弹道、炮口火光与 mech.raid.alert_noise。
## SKILLS   新技能：name / icon（assets\ui\ic_<icon>.png，音效 skill_<icon>）/ cd / cost 及效果参数；
##          底盘位移的键为底盘 type，躯干与动力炉技能的键为模块 id，背部技能的键为模块的 ability；
##          效果写在 script = 路径，脚本写 static func use(mech, key, sk, m)（冷却、扣能、音效与 skill_used 事件已由 mech.gd 处理）。
## LOOT_TABLES  新掉落表；SHOP 追加上架的物品 id。
## SFX      新音效的登记（格式同 scripts\audio\audio_registry.gd 的 SFX）；不登记也能按命名约定播放，登记后列入音频清单。
## RAID_SCRIPTS  行动扩展脚本路径（规则见 scripts\raid.gd 的 _run_ext_build），如新消耗品的按键处理。
## EXTEND   给已有条目补字段，如 {"LOOT_TABLES": {"military": {"pool": {"新物品 id": 权重}}}}。
## static func register(gd)  可选：登记 gd.add_item_resolver（品质词条变体）、gd.add_loot_hook、gd.add_stat_hook、InputMap 新动作。

const Affix = preload("res://scripts/modules/affix.gd")

const MODULES := {
	# ---- 躯干 ----
	"core_heavy": {"name": "第1装甲师 BW-3 重型 框架", "slot": "core", "w": 20, "v": 2400, "rar": 2, "hp": 220, "cargo": 24, "drain": 0.14, "color": Color(0.78, 0.302, 0.239)},
	"core_scout": {"name": "第82空降师 SC-1 轻型 框架", "slot": "core", "w": 8, "v": 400, "rar": 0, "hp": 90, "cargo": 12, "drain": 0.08, "color": Color(0.922, 0.722, 0.251)},
	"core_std": {"name": "第1步兵师 MK-II 中型 框架", "slot": "core", "w": 12, "v": 1000, "rar": 1, "hp": 140, "cargo": 18, "drain": 0.1, "color": Color(0.302, 0.58, 0.851)},
	# ---- 底盘 ----
	"legs_biped": {"name": "第82空降师 ST-8 轻型 双足底盘", "slot": "legs", "w": 8, "v": 350, "rar": 0, "speed": 6.2, "load": 45, "drain": 0.06, "type": "biped", "color": Color(0.549, 0.549, 0.502)},
	"legs_hover": {"name": "第101空中突击师 SK-9 轻型 悬浮底盘", "slot": "legs", "w": 6, "v": 2600, "rar": 3, "speed": 9.5, "load": 38, "drain": 0.16, "type": "hover", "color": Color(0.851, 0.851, 0.902)},
	"legs_quad": {"name": "近卫第4坦克师 AR-4 重型 四足底盘", "slot": "legs", "w": 14, "v": 1700, "rar": 2, "speed": 6.4, "load": 80, "drain": 0.09, "type": "quad", "color": Color(0.502, 0.42, 0.6)},
	"legs_tread": {"name": "第1装甲师 SAXX-1 重型 履带底盘", "slot": "legs", "w": 16, "v": 1200, "rar": 1, "speed": 6.0, "load": 65, "drain": 0.08, "armor": 0.15, "type": "tread", "color": Color(0.349, 0.38, 0.302)},
	# ---- 背部挂载 ----
	"back_cargo": {"name": "第3步兵师 CG-10 轻型 载货背包", "slot": "back", "w": 4, "v": 300, "rar": 0, "cargo": 10, "ability": "none", "color": Color(0.502, 0.42, 0.302)},
	"back_missile": {"name": "第1装甲师 MS-6 中型 导弹挂架", "slot": "back", "w": 7, "v": 1900, "rar": 2, "ability": "missile", "cd": 7.0, "cost": 8.0, "dmg": 30.0, "count": 6, "color": Color(0.4, 0.451, 0.349)},
	"back_shield": {"name": "冷溪近卫团 SH-3 中型 力场护盾", "slot": "back", "w": 6, "v": 1600, "rar": 2, "ability": "shield", "cd": 12.0, "cost": 10.0, "dur": 3.5, "color": Color(0.349, 0.549, 0.902)},
	# ---- 动力炉 ----
	"gen_cell": {"name": "第3步兵师 B-40 轻型 电池组", "slot": "gen", "w": 5, "v": 300, "rar": 0, "energy": 100.0, "eff": 1.0, "color": Color(1, 0.8, 0.2)},
	"gen_crystal": {"name": "近卫第1坦克集团军 CR-8 试作中型 反应炉", "slot": "gen", "w": 8, "v": 3200, "rar": 3, "energy": 230.0, "eff": 0.8, "color": Color(0.851, 0.302, 1)},
	"gen_reactor": {"name": "第2装甲骑兵团 RT-1 试作中型 动力炉", "slot": "gen", "w": 10, "v": 1500, "rar": 1, "energy": 150.0, "eff": 0.9, "color": Color(0.2, 0.902, 1)},
	# ---- 手臂武装 ----
	"arm_flamer": {"name": "第1装甲师 FT-20 喷火器", "slot": "arm", "w": 7, "v": 1400, "rar": 2, "weapon": "flamer", "dmg": 4.5, "rate": 20.0, "cost": 0.06, "spread": 16.0, "speed": 16.0, "range": 9.0, "color": Color(0.851, 0.349, 0.149)},
	"arm_laser": {"name": "第101空中突击师 LZ-42 聚焦激光器", "slot": "arm", "w": 4, "v": 1800, "rar": 2, "weapon": "laser", "dmg": 42.0, "rate": 1.8, "cost": 1.6, "range": 34.0, "color": Color(0.302, 0.851, 0.949)},
	"arm_mg": {"name": "第82空降师 G-36 转管机炮", "slot": "arm", "w": 5, "v": 300, "rar": 0, "weapon": "mg", "dmg": 9.0, "rate": 9.0, "cost": 0.05, "spread": 5.0, "speed": 48.0, "range": 30.0, "color": Color(0.6, 0.6, 0.549)},
	"arm_shotgun": {"name": "第2装甲骑兵团 SG-7 重型霰弹枪", "slot": "arm", "w": 6, "v": 800, "rar": 1, "weapon": "shotgun", "dmg": 8.0, "pellets": 7, "rate": 1.6, "cost": 0.5, "spread": 20.0, "speed": 40.0, "range": 15.0, "color": Color(0.702, 0.451, 0.251)},
}

const AMMO := {}

const SKILLS := {}

const ITEMS := {
	# ---- food ----
	"can_food": {"name": "罐头肉", "cat": "food", "w": 1.0, "v": 60, "rar": 0},
	"biscuit": {"name": "压缩饼干", "cat": "food", "w": 0.5, "v": 35, "rar": 0},
	"water_tab": {"name": "净水片", "cat": "food", "w": 0.2, "v": 45, "rar": 0},
	"coffee": {"name": "旧世界咖啡豆", "cat": "food", "w": 0.6, "v": 260, "rar": 2},
	# ---- misc ----
	"circuit": {"name": "电路板", "cat": "misc", "w": 0.5, "v": 90, "rar": 1},
	"wire": {"name": "铜线卷", "cat": "misc", "w": 1.5, "v": 70, "rar": 0},
	"bolts": {"name": "螺栓", "cat": "misc", "w": 0.8, "v": 25, "rar": 0},
	"hdd": {"name": "旧世界硬盘", "cat": "misc", "w": 0.4, "v": 380, "rar": 2},
	"toy": {"name": "发条玩具", "cat": "misc", "w": 0.3, "v": 160, "rar": 1},
	"chitin": {"name": "虫甲壳", "cat": "misc", "w": 1.0, "v": 80, "rar": 0},
	"bug_crystal": {"name": "虫晶", "cat": "misc", "w": 0.3, "v": 450, "rar": 3},
	# ---- use ----
	"fuel_cell": {"name": "燃料电池", "cat": "use", "w": 1.0, "v": 120, "rar": 1},
	"repair_kit": {"name": "维修包", "cat": "use", "w": 1.2, "v": 140, "rar": 1},
	"beacon": {"name": "呼叫信标", "cat": "use", "w": 0.5, "v": 300, "rar": 2},
	# ---- money ----
	"credit_s": {"name": "信用芯片(小)", "cat": "money", "w": 0.05, "v": 100, "rar": 1},
	"credit_l": {"name": "信用芯片(大)", "cat": "money", "w": 0.05, "v": 500, "rar": 2},
	"gold": {"name": "金条", "cat": "money", "w": 1.0, "v": 1200, "rar": 3},
		# ---- 消耗品 ----
		"sonic_decoy": {"name": "声波诱饵信标", "cat": "use", "w": 0.8, "v": 260, "rar": 2, "script": "res://scripts/modules/item_decoy.gd"},
		"extract_flare": {"name": "撤离引导烟幕", "cat": "use", "w": 0.6, "v": 220, "rar": 1, "script": "res://scripts/modules/item_flare.gd"},
		"energy_rod": {"name": "高能电池棒", "cat": "use", "w": 1.4, "v": 380, "rar": 2, "script": "res://scripts/modules/item_battery.gd"},
		"coolant_pack": {"name": "冷却剂罐", "cat": "use", "w": 1.2, "v": 240, "rar": 1, "script": "res://scripts/modules/item_coolant.gd"},
		"extract_barrier": {"name": "撤离屏障", "cat": "use", "w": 2.0, "v": 320, "rar": 2, "script": "res://scripts/modules/item_barrier.gd"},
		"surge_cell": {"name": "超频电芯", "cat": "use", "w": 1.3, "v": 400, "rar": 2, "script": "res://scripts/modules/item_surge.gd"},
}

const LOOT_TABLES := {}

const SHOP := ["sonic_decoy", "extract_flare", "energy_rod", "coolant_pack", "extract_barrier", "surge_cell"]

const SFX := {}

const RAID_SCRIPTS := ["res://scripts/modules/ops_consumables.gd"]

const EXTEND := {
	"LOOT_TABLES": {
		"military": {"pool": {"sonic_decoy": 12, "energy_rod": 10, "coolant_pack": 8, "surge_cell": 6}},
		"supply": {"pool": {"energy_rod": 6, "coolant_pack": 5, "surge_cell": 3}},
		"tool": {"pool": {"sonic_decoy": 5, "extract_flare": 6, "extract_barrier": 4}},
	},
}

## 掉落的模块挂上品质词条的概率（按掉落表，未列出的表用 0.2）
const AFFIX_CHANCE := {"military": 0.42, "nest": 0.30, "safe": 0.26, "tool": 0.18, "supply": 0.16, "bug": 0.10}


## 变体解析、掉落挂词条与新消耗品按键
static func register(gd) -> void:
	gd.add_item_resolver(func(id: String, base: Dictionary) -> Dictionary:
		return Affix.apply(id, base))
	gd.add_loot_hook(func(id: String, table: String, rng: RandomNumberGenerator) -> String:
		if not gd.is_module(id):
			return id
		return Affix.decorate(id, rng, float(AFFIX_CHANCE.get(table, 0.2))))
	gd._key("use_decoy", [KEY_3])
	gd._key("use_flare", [KEY_4])
	gd._key("use_battery", [KEY_5])
	gd._key("use_coolant", [KEY_6])
	gd._key("use_barrier", [KEY_7])
	gd._key("use_surge", [KEY_8])
