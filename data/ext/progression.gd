extends RefCounted
## 局外成长团队的扩展数据：启动时由 GameData 并入核心表（规则见 scripts\game_data.gd 的「内容注册」一节）。
## 运行逻辑在 scripts\progression\growth.gd，界面在 scripts\progression\growth_panel.gd。
##
## FACILITIES  飞空艇设施：{"name", "max", "cost": [第 1..max 级的升级费用 {"money", "items"}]、
##             "stat": 每级叠加的机体数值、 "effect": [每级效果文字（与 stat 的数值一致）]}。
## RESEARCH    研究节点：{"name", "lab": 需要的研究室等级, "needs": [前置研究 id], "cost": {"money", "items"},
##             "stat": 完成后叠加的机体数值, "shop": [完成后上架的物品 id], "effect": 效果文字}。
## PILOTS      驾驶员：{"name", "level_stat": 每升一级叠加的机体数值,
##             "talents": [{"id", "name", "level": 解锁等级, "points": 消耗天赋点, "stat", "effect"}]}。
## CREW        船员：{"name", "stat": 每级好感叠加的机体数值, "levels": [Lv.1..Lv.5 的累计效果文字], "preferred": 偏爱赠礼物品 id}。
## CHAPTERS    主线章节（数组顺序即航程顺序）：{"id", "title", "map", "flag": 完成时写入剧情的 flag,
##             "requires": 前置 flag, "complete_on": extract 撤离成功 / boss 击破指定敌人, "boss": 敌人 id}。
## MEAL        出击食堂：cost 每次烹制消耗的仓库物品，text 按厨房等级的效果文字，ration 追加效果文字，
##             energy / hp / drain 为每级餐点数值，ration_energy / ration_hp 为研究「高热量作战口粮」的追加值。
## WHO_CHAR    既有后勤委托的委托人显示名 → 好感归属角色 id；新委托直接在条目里写 "char"。
## GENERIC_GIFTS 可以作为通用赠礼的既有物品 id → 好感点数（送给任何人都生效；有偏爱归属的赠礼另算）。
## ITEMS / SHOP / REQUEST_POOL / SFX / EXTEND  与 game_data.gd 的同名注册表规则一致。

const REQUEST_POOL := [
	{"id": "fuel_cell", "count": 2, "reward": 430, "who": "调度员莉娜", "char": "lina"},
	{"id": "beacon", "count": 1, "reward": 480, "who": "领航员小满", "char": "xiaoman"},
	{"id": "wire", "count": 2, "reward": 400, "who": "领航员小满", "char": "xiaoman"},
	{"id": "toy", "count": 1, "reward": 430, "who": "厨师阿堇", "char": "ajin"},
]
const ITEMS := {
		"gift_watch": {"name": "铜壳怀表", "cat": "misc", "w": 0.2, "v": 240, "rar": 1, "gift": {"char": "lina", "points": 2}},
		"gift_wrench": {"name": "钨钢扳手", "cat": "misc", "w": 0.8, "v": 180, "rar": 1, "gift": {"char": "laojiao", "points": 2}},
		"gift_cocoa": {"name": "旧世界可可粉", "cat": "misc", "w": 0.4, "v": 220, "rar": 1, "gift": {"char": "ajin", "points": 2}},
		"gift_chart": {"name": "航线图册", "cat": "misc", "w": 0.6, "v": 260, "rar": 2, "gift": {"char": "xiaoman", "points": 2}},
		"gift_flask": {"name": "银质酒壶", "cat": "misc", "w": 0.5, "v": 300, "rar": 2},
	}
const SHOP := ["arm_flamer", "arm_laser", "legs_quad", "back_shield", "back_missile", "legs_hover", "core_heavy", "gen_crystal"]
const SFX := {
	"grow_upgrade": {"files": ["grow_upgrade.wav"], "when": "飞空艇设施升级完成（growth_panel.gd）", "bus": "UI", "d3": false, "pitch": 0.0, "max": 2},
	"grow_research": {"files": ["grow_research.wav"], "when": "研究节点完成（growth_panel.gd）", "bus": "UI", "d3": false, "pitch": 0.0, "max": 2},
	"grow_level": {"files": ["grow_level.wav"], "when": "驾驶员升级或习得天赋（growth_panel.gd）", "bus": "UI", "d3": false, "pitch": 0.0, "max": 2},
	"grow_affinity": {"files": ["grow_affinity.wav"], "when": "船员好感等级提升（growth.gd）", "bus": "UI", "d3": false, "pitch": 0.0, "max": 2},
	"grow_gift": {"files": ["grow_gift.wav"], "when": "向船员赠礼（growth_panel.gd）", "bus": "UI", "d3": false, "pitch": 0.0, "max": 2},
	"grow_meal": {"files": ["grow_meal.wav"], "when": "出击食堂烹制餐点（growth_panel.gd）", "bus": "UI", "d3": false, "pitch": 0.0, "max": 2},
	"grow_recover": {"files": ["grow_recover.wav"], "when": "行动失败后医务室回收一件模块（growth.gd）", "bus": "UI", "d3": false, "pitch": 0.0, "max": 2},
}
const EXTEND := {
	"LOOT_TABLES": {
		"supply": {"pool": {"gift_cocoa": 4}},
		"tool": {"pool": {"gift_wrench": 3}},
		"safe": {"pool": {"gift_watch": 5, "gift_chart": 4, "gift_flask": 4}},
	},
}


## 合并完成后登记成长系统的数值钩子、商品与战区解锁筛选，并接上行动结算事件。
static func register(_gd) -> void:
	var s: Script = load("res://scripts/progression/growth.gd")
	if s != null:
		s.call("install")

const FACILITIES := {
	"hangar": {
		"name": "机库",
		"max": 5,
		"cost": [
			{"money": 700, "items": {"bolts": 2, "wire": 1}},
			{"money": 1200, "items": {"bolts": 4, "circuit": 1}},
			{"money": 1900, "items": {"circuit": 2, "chitin": 2}},
			{"money": 2800, "items": {"chitin": 4, "bug_crystal": 1}},
			{"money": 4000, "items": {"bug_crystal": 2, "hdd": 1}},
		],
		"stat": {"hp": 5.0, "cargo": 1.0},
		"effect": ["结构 +5 · 货舱 +1", "结构 +10 · 货舱 +2", "结构 +15 · 货舱 +3", "结构 +20 · 货舱 +4", "结构 +25 · 货舱 +5"],
	},
	"workshop": {
		"name": "工坊",
		"max": 5,
		"cost": [
			{"money": 800, "items": {"chitin": 2, "bolts": 1}},
			{"money": 1300, "items": {"chitin": 3, "circuit": 1}},
			{"money": 2100, "items": {"chitin": 5, "wire": 2}},
			{"money": 3000, "items": {"bug_crystal": 1, "circuit": 3}},
			{"money": 4200, "items": {"bug_crystal": 2, "hdd": 1}},
		],
		"stat": {"armor": 0.02, "load": 2.0},
		"effect": ["护甲 +2% · 承重 +2", "护甲 +4% · 承重 +4", "护甲 +6% · 承重 +6", "护甲 +8% · 承重 +8", "护甲 +10% · 承重 +10"],
	},
	"infirmary": {
		"name": "医务室",
		"max": 5,
		"cost": [
			{"money": 700, "items": {"water_tab": 2, "wire": 1}},
			{"money": 1200, "items": {"water_tab": 3, "circuit": 1}},
			{"money": 1800, "items": {"can_food": 3, "circuit": 2}},
			{"money": 2600, "items": {"bug_crystal": 1, "water_tab": 4}},
			{"money": 3800, "items": {"bug_crystal": 2, "hdd": 1}},
		],
		"stat": {"drain": -0.004},
		"effect": ["耗能 -0.004 · 失败回收 20%", "耗能 -0.008 · 失败回收 40%", "耗能 -0.012 · 失败回收 60%",
			"耗能 -0.016 · 失败回收 80%", "耗能 -0.020 · 失败回收 100%"],
	},
	"lab": {
		"name": "研究室",
		"max": 5,
		"cost": [
			{"money": 900, "items": {"circuit": 2, "wire": 1}},
			{"money": 1500, "items": {"circuit": 3, "wire": 2}},
			{"money": 2400, "items": {"bug_crystal": 1, "circuit": 3}},
			{"money": 3400, "items": {"bug_crystal": 2, "hdd": 1}},
			{"money": 4600, "items": {"bug_crystal": 3, "hdd": 2}},
		],
		"stat": {"energy": 5.0},
		"effect": ["能源上限 +5 · 研究等级 1", "能源上限 +10 · 研究等级 2", "能源上限 +15 · 研究等级 3",
			"能源上限 +20 · 研究等级 4", "能源上限 +25 · 研究等级 5"],
	},
	"kitchen": {
		"name": "厨房",
		"max": 5,
		"cost": [
			{"money": 600, "items": {"can_food": 2, "water_tab": 2}},
			{"money": 1100, "items": {"can_food": 3, "water_tab": 3}},
			{"money": 1800, "items": {"can_food": 4, "coffee": 1}},
			{"money": 2600, "items": {"can_food": 5, "bug_crystal": 1}},
			{"money": 3600, "items": {"coffee": 2, "bug_crystal": 2}},
		],
		"stat": {},
		"effect": ["餐点：能量 +12 · 结构 +3", "餐点：能量 +16 · 结构 +6", "餐点：能量 +20 · 结构 +9",
			"餐点：能量 +24 · 结构 +12", "餐点：能量 +28 · 结构 +15"],
	},
}

const RESEARCH := {
	"res_cell": {"name": "虫晶燃料电池组", "lab": 1, "needs": [], "cost": {"money": 1100, "items": {"bug_crystal": 1, "wire": 2}},
		"stat": {"energy": 12.0}, "shop": [], "effect": "能源上限 +12"},
	"res_armor": {"name": "复合虫甲装甲", "lab": 1, "needs": [], "cost": {"money": 1200, "items": {"chitin": 4, "circuit": 2}},
		"stat": {"armor": 0.03}, "shop": ["back_shield"], "effect": "护甲 +3% · 商店上架：相位护盾"},
	"res_lens": {"name": "聚焦透镜阵列", "lab": 2, "needs": [], "cost": {"money": 1700, "items": {"circuit": 3, "bug_crystal": 1}},
		"stat": {}, "shop": ["arm_laser"], "effect": "商店上架：聚焦激光"},
	"res_flame": {"name": "高压燃料喷嘴", "lab": 2, "needs": [], "cost": {"money": 1300, "items": {"wire": 2, "bolts": 3}},
		"stat": {}, "shop": ["arm_flamer"], "effect": "商店上架：火焰喷射器"},
	"res_quad": {"name": "多足步态控制", "lab": 2, "needs": [], "cost": {"money": 1600, "items": {"circuit": 3, "chitin": 2}},
		"stat": {"speed": 0.2, "load": 2.0}, "shop": ["legs_quad"], "effect": "速度 +0.2 · 承重 +2 · 商店上架：四足 Arachne"},
	"res_missile": {"name": "蜂巢弹巢", "lab": 3, "needs": [], "cost": {"money": 2300, "items": {"circuit": 4, "wire": 3}},
		"stat": {}, "shop": ["back_missile"], "effect": "商店上架：蜂巢导弹"},
	"res_hover": {"name": "反重力悬浮环", "lab": 3, "needs": [], "cost": {"money": 2800, "items": {"bug_crystal": 2, "hdd": 1}},
		"stat": {"speed": 0.3}, "shop": ["legs_hover"], "effect": "速度 +0.3 · 商店上架：悬浮 Skimmer"},
	"res_core": {"name": "重装躯干试制", "lab": 3, "needs": [], "cost": {"money": 2600, "items": {"chitin": 6, "circuit": 4}},
		"stat": {"hp": 10.0}, "shop": ["core_heavy"], "effect": "结构 +10 · 商店上架：重装躯干 Bulwark"},
	"res_recycle": {"name": "生态循环净水", "lab": 2, "needs": [], "cost": {"money": 1400, "items": {"water_tab": 4, "circuit": 1}},
		"stat": {"drain": -0.006}, "shop": [], "effect": "耗能 -0.006"},
	"res_quiet": {"name": "消音缓冲机架", "lab": 3, "needs": [], "cost": {"money": 2100, "items": {"chitin": 3, "bolts": 4}},
		"stat": {"drain": -0.008}, "shop": [], "effect": "耗能 -0.008"},
	"res_deep": {"name": "深渊耐压座舱", "lab": 4, "needs": ["res_cell", "res_armor"],
		"cost": {"money": 4200, "items": {"bug_crystal": 3, "hdd": 2}},
		"stat": {"hp": 20.0, "energy": 20.0, "armor": 0.02}, "shop": ["gen_crystal"],
		"effect": "结构 +20 · 能源上限 +20 · 护甲 +2% · 商店上架：虫晶反应炉"},
	"res_ration": {"name": "高热量作战口粮", "lab": 3, "needs": ["res_recycle"],
		"cost": {"money": 2000, "items": {"can_food": 4, "water_tab": 4}},
		"stat": {}, "shop": [], "effect": "出击餐点：能量 +8 · 结构 +4"},
}

const PILOTS := {
	"nao": {
		"name": "奈绪",
		"level_stat": {"cargo": 1.0, "load": 1.5},
		"talents": [
			{"id": "t_nao_rig", "name": "载重桁架", "level": 2, "points": 1, "stat": {"load": 8.0}, "effect": "承重 +8"},
			{"id": "t_nao_cache", "name": "暗格储物", "level": 3, "points": 1, "stat": {"cargo": 4.0}, "effect": "货舱 +4"},
			{"id": "t_nao_stride", "name": "轻装疾行", "level": 4, "points": 1, "stat": {"speed": 0.35}, "effect": "速度 +0.35"},
			{"id": "t_nao_field", "name": "野战抢修", "level": 6, "points": 2, "stat": {"hp": 18.0, "drain": -0.004}, "effect": "结构 +18 · 耗能 -0.004"},
		],
	},
	"rei": {
		"name": "零",
		"level_stat": {"energy": 5.0, "drain": -0.003},
		"talents": [
			{"id": "t_rei_cap", "name": "激光电容", "level": 2, "points": 1, "stat": {"energy": 15.0}, "effect": "能源上限 +15"},
			{"id": "t_rei_step", "name": "静默步态", "level": 3, "points": 1, "stat": {"speed": 0.3}, "effect": "速度 +0.3"},
			{"id": "t_rei_cool", "name": "低温回路", "level": 4, "points": 1, "stat": {"drain": -0.008}, "effect": "耗能 -0.008"},
			{"id": "t_rei_focus", "name": "长距瞄准", "level": 6, "points": 2, "stat": {"energy": 20.0, "hp": 10.0}, "effect": "能源上限 +20 · 结构 +10"},
		],
	},
	"kurumi": {
		"name": "胡桃",
		"level_stat": {"hp": 7.0, "armor": 0.008},
		"talents": [
			{"id": "t_kur_plate", "name": "重装骨架", "level": 2, "points": 1, "stat": {"hp": 25.0}, "effect": "结构 +25"},
			{"id": "t_kur_heat", "name": "耐热装甲", "level": 3, "points": 1, "stat": {"armor": 0.04}, "effect": "护甲 +4%"},
			{"id": "t_kur_charge", "name": "突破推进", "level": 4, "points": 1, "stat": {"speed": 0.3}, "effect": "速度 +0.3"},
			{"id": "t_kur_hold", "name": "死守", "level": 6, "points": 2, "stat": {"hp": 30.0, "armor": 0.02}, "effect": "结构 +30 · 护甲 +2%"},
		],
	},
}

const CREW := {
	"lina": {"name": "莉娜", "stat": {"energy": 2.0}, "preferred": "gift_watch",
		"levels": ["能源上限 +2", "能源上限 +4", "能源上限 +6", "能源上限 +8", "能源上限 +10"]},
		"laojiao": {"name": "米娅", "stat": {"armor": 0.01}, "preferred": "gift_wrench",
		"levels": ["护甲 +1%", "护甲 +2%", "护甲 +3%", "护甲 +4%", "护甲 +5%"]},
	"ajin": {"name": "阿堇", "stat": {"hp": 3.0}, "preferred": "gift_cocoa",
		"levels": ["结构上限 +3", "结构上限 +6", "结构上限 +9", "结构上限 +12", "结构上限 +15"]},
	"xiaoman": {"name": "小满", "stat": {"speed": 0.1}, "preferred": "gift_chart",
		"levels": ["速度 +0.1", "速度 +0.2", "速度 +0.3", "速度 +0.4", "速度 +0.5"]},
}

const CHAPTERS := [
	{"id": "ch1", "title": "第一章 · 灰港的薄荷糖", "map": "greyport", "flag": "ch1_done", "requires": "", "complete_on": "extract"},
	{"id": "ch2", "title": "第二章 · 铁锈与回音", "map": "ironbelt", "flag": "ch2_done", "requires": "ch1_done", "complete_on": "extract"},
	{"id": "ch3", "title": "第三章 · 风沙中的白鹭", "map": "dustfield", "flag": "ch3_done", "requires": "ch2_done", "complete_on": "extract"},
	{"id": "ch4", "title": "第四章 · 赤湖静默", "map": "redlake", "flag": "ch4_done", "requires": "ch3_done", "complete_on": "extract"},
	{"id": "ch5", "title": "第五章 · 裂谷的幽灵电波", "map": "canyon", "flag": "ch5_done", "requires": "ch4_done", "complete_on": "extract"},
	{"id": "ch6", "title": "第六章 · 折翼者的黑匣子", "map": "canyon", "flag": "ch6_done", "requires": "ch5_done", "complete_on": "boss", "boss": "king_beetle"},
	{"id": "ch7", "title": "终章 · 潜入零号深渊", "map": "abyss_maw", "flag": "ch7_done", "requires": "ch6_done", "complete_on": "boss", "boss": "abyss_queen"},
]

const MEAL := {
	"cost": {"can_food": 1, "water_tab": 1},
	"energy": 4.0,
	"hp": 3.0,
	"drain": -0.002,
	"ration_energy": 8.0,
	"ration_hp": 4.0,
	"text": ["能量 +12 · 结构 +3", "能量 +16 · 结构 +6", "能量 +20 · 结构 +9", "能量 +24 · 结构 +12", "能量 +28 · 结构 +15"],
	"ration": "能量 +8 · 结构 +4",
}

const WHO_CHAR := {"厨师阿堇": "ajin", "机械师米娅": "laojiao", "装甲工坊": "laojiao"}
const GENERIC_GIFTS := {"coffee": 1, "toy": 1}
