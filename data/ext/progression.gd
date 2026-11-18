extends RefCounted
## 局外成长团队的扩展数据：启动时由 GameData 并入核心表（规则见 scripts\game_data.gd 的「内容注册」一节）。
## 运行逻辑在 scripts\progression\growth.gd，界面在 scripts\progression\growth_panel.gd。
##
## FACILITIES  飞空艇设施：{"name", "max", "cost": [第 1..max 级的升级费用 {"money", "items"}]、
##             "stat": 每级叠加的机体数值、 "effect": [每级效果文字（与 stat 的数值一致）]}。
## RESEARCH    研究节点：{"name", "lab": 需要的研究室等级, "needs": [前置研究 id], "cost": {"money", "items"},
##             "stat": 完成后叠加的机体数值, "shop": [完成后上架的物品 id], "effect": 效果文字}。
## PILOTS      驾驶员：{"name", "level_stat": 每升一级叠加的机体数值}。
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
			"gift_wrench": {"name": "钨钢扳手", "cat": "misc", "w": 0.8, "v": 180, "rar": 1, "gift": {"char": "mia", "points": 2}},
		"gift_cocoa": {"name": "旧世界可可粉", "cat": "misc", "w": 0.4, "v": 220, "rar": 1, "gift": {"char": "ajin", "points": 2}},
		"gift_chart": {"name": "航线图册", "cat": "misc", "w": 0.6, "v": 260, "rar": 2, "gift": {"char": "xiaoman", "points": 2}},
		"gift_flask": {"name": "银质酒壶", "cat": "misc", "w": 0.5, "v": 300, "rar": 2},
	}
const SHOP := ["arm_flamer", "arm_laser", "legs_quad", "legs_quad_crab", "back_shield", "back_missile", "legs_hex", "legs_hex_beetle", "core_heavy", "gen_crystal"]
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
	"res_lens": {"name": "多级电磁加速线圈", "lab": 2, "needs": [], "cost": {"money": 1700, "items": {"circuit": 3, "bug_crystal": 1}},
		"stat": {}, "shop": ["arm_laser"], "effect": "商店上架：电磁线圈步枪"},
	"res_flame": {"name": "增压铝热弹投射机构", "lab": 2, "needs": [], "cost": {"money": 1300, "items": {"wire": 2, "bolts": 3}},
		"stat": {}, "shop": ["arm_flamer"], "effect": "商店上架：燃烧弹投射器"},
	"res_quad": {"name": "多足步态控制", "lab": 2, "needs": [], "cost": {"money": 1600, "items": {"circuit": 3, "chitin": 2}},
		"stat": {"speed": 0.2, "load": 2.0}, "shop": ["legs_quad", "legs_quad_crab"], "effect": "速度 +0.2 · 承重 +2 · 商店上架：多地形四足 / 堡垒四足"},
	"res_missile": {"name": "蜂巢弹巢", "lab": 3, "needs": [], "cost": {"money": 2300, "items": {"circuit": 4, "wire": 3}},
		"stat": {}, "shop": ["back_missile"], "effect": "商店上架：蜂巢导弹"},
	"res_hex": {"name": "六足步态协同", "lab": 3, "needs": [], "cost": {"money": 2800, "items": {"bug_crystal": 2, "hdd": 1}},
		"stat": {"load": 6.0, "speed": 0.2}, "shop": ["legs_hex", "legs_hex_beetle"], "effect": "承重 +6 · 速度 +0.2 · 商店上架：六足巡航 / 甲虫六足"},
	"res_core": {"name": "重装躯干试制", "lab": 3, "needs": [], "cost": {"money": 2600, "items": {"chitin": 6, "circuit": 4}},
		"stat": {"hp": 10.0}, "shop": ["core_heavy"], "effect": "结构 +10 · 商店上架：重型框架"},
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
	},
	"rei": {
		"name": "零",
		"level_stat": {"energy": 5.0, "drain": -0.003},
	},
	"kurumi": {
		"name": "胡桃",
		"level_stat": {"hp": 7.0, "armor": 0.008},
	},
}

const CREW := {
	"lina": {"name": "莉娜", "stat": {"energy": 2.0}, "preferred": "gift_watch",
		"levels": ["能源上限 +2", "能源上限 +4", "能源上限 +6", "能源上限 +8", "能源上限 +10"]},
		"mia": {"name": "米娅", "stat": {"armor": 0.01}, "preferred": "gift_wrench",
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

const WHO_CHAR := {"厨师阿堇": "ajin", "机械师米娅": "mia", "装甲工坊": "mia"}
const GENERIC_GIFTS := {"coffee": 1, "toy": 1}

## ---------------------------------------------------------------- 机库「技能」页签（v0.6）
## MATERIALS   技能页显示的打捞杂物（升级材料）顺序；数量从仓库实时统计，花费时从仓库扣除。
const MATERIALS := ["bolts", "wire", "circuit", "chitin", "bug_crystal", "hdd", "can_food", "water_tab", "coffee"]

## ABILITIES   塔科夫式实战熟练度技能（Use-Based Proficiency Skills）：
##             不消耗任何信用点或打捞物资，仅在战区实战执行对应动作（移动、负重行军、抗伤损管、装甲卸力、
##             实弹射击、炉心耗能、搜刮检视、战术撤离）时自动累积熟练度点数并升级；单局初段享精力充沛加成，
##             同局过度重复同一动作触发疲劳递减，新出击重置精力状态。达到满级 Lv.10 额外激活「精英专精」。
const ABILITIES := {
	"ab_servo": {
		"name": "机动耐力", "en": "ENDURANCE", "cat": "机动", "icon": "legs_biped_scout", "max": 10,
		"stat": {"speed": 0.08, "drain": -0.0012},
		"effect": "移速 +0.08 · 耗能 -0.0012",
		"elite": "底盘推进机动冷却 -15%",
		"how": "战区行进移动 · 施展底盘推进机动",
	},
	"ab_rack": {
		"name": "负重肌力", "en": "STRENGTH", "cat": "体能", "icon": "back_rack", "max": 10,
		"stat": {"cargo": 1.0, "load": 1.5},
		"effect": "货舱 +1.0 · 承重 +1.5",
		"elite": "超载减速惩罚减轻 30%",
		"how": "高负载/超载负重行军 · 携重物资撤离",
	},
	"ab_frame": {
		"name": "抗损损管", "en": "VITALITY", "cat": "生存", "icon": "repair_kit", "max": 10,
		"stat": {"hp": 5.0},
		"effect": "结构上限 +5",
		"elite": "战地维修包结构与部位修复量 +25%",
		"how": "承受实战火力冲击 · 战地抢修受损机体",
	},
	"ab_plating": {
		"name": "重装卸力", "en": "HEAVY ARMOR", "cat": "重装", "icon": "core_heavy", "max": 10,
		"stat": {"armor": 0.008},
		"effect": "护甲减伤 +0.8%",
		"elite": "部位受损耐久折损减轻 20%",
		"how": "机体装甲减伤吸收 · 护盾拦截 · 击毁重甲目标",
	},
	"ab_firearm": {
		"name": "实弹火控", "en": "FIREARMS", "cat": "战斗", "icon": "arm_ac30", "max": 10,
		"stat": {"ergo": 2.2},
		"effect": "人机工效 +2.2（压散布 / 快换弹）",
		"elite": "双臂装填速度额外 +15%",
		"how": "实弹开火射击 · 有效命中与击毁 · 战术换弹",
	},
	"ab_reactor": {
		"name": "炉心代谢", "en": "METABOLISM", "cat": "能源", "icon": "gen_reactor", "max": 10,
		"stat": {"energy": 5.0},
		"effect": "能源上限 +5",
		"elite": "电池与口粮补给回能 +20%",
		"how": "消耗反应堆电力 · 释放背部武装 · 使用能源饮食补给",
	},
	"ab_search": {
		"name": "搜刮感知", "en": "ATTENTION", "cat": "搜刮", "icon": "hdd", "max": 10,
		"stat": {"cargo": 0.5, "recon": 0.25},
		"effect": "搜刮检视 +4% · 视野 +0.25 · 货舱 +0.5",
		"elite": "开启容器瞬间立即显现首件战利品",
		"how": "开启物资容器 · 逐格检视显现 · 拾取高稀有物资",
	},
	"ab_covert": {
		"name": "战术撤收", "en": "RAID OPS", "cat": "战术", "icon": "extract_flare", "max": 10,
		"stat": {"speed": 0.04, "ergo": 1.0},
		"effect": "撤离读秒 -2% · 移速 +0.04 · 工效 +1.0",
		"elite": "实弹开火警觉噪音半径 -15%",
		"how": "发现战区地标 · 投放战术器材 · 成功撤离与讨伐首领",
	},
}

## PODS        部署仓（战斗队友）：每个仓装一名 AI 驾驶员，tier 1 = 购买，2..3 = 升级；tier 影响队友机甲强度。
##             {"name", "pilot", "role", "cost": [tier 1..3 的费用], "tiers": [每级效果文字]}
##             状态存 Progress.state.pods = {"rei": {"tier": 0..3, "on": 是否随行}}；战斗侧读 Growth.ally_squad()。
const PODS := {
	"rei": {"name": "部署仓 A · 零", "pilot": "rei", "role": "远程狙击 · 电磁穿甲支援",
		"cost": [
			{"money": 1500, "items": {"bolts": 2, "wire": 2, "circuit": 1}},
			{"money": 3200, "items": {"circuit": 3, "bug_crystal": 1}},
			{"money": 5600, "items": {"bug_crystal": 3, "hdd": 2}},
		],
		"tiers": ["标准机体 · 电磁线圈步枪", "强化机体 · 结构/穿甲提升", "王牌机体 · 全面强化"]},
	"kurumi": {"name": "部署仓 B · 胡桃", "pilot": "kurumi", "role": "近战突击 · 前排抗伤",
		"cost": [
			{"money": 1200, "items": {"bolts": 3, "chitin": 2}},
			{"money": 2900, "items": {"chitin": 4, "circuit": 2}},
			{"money": 5200, "items": {"bug_crystal": 2, "chitin": 6, "hdd": 1}},
		],
		"tiers": ["标准机体 · 霰弹突击", "强化机体 · 结构/火力提升", "王牌机体 · 全面强化"]},
}
