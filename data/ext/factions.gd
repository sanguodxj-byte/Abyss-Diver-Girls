extends RefCounted
## 派系团队的扩展数据：启动时由 GameData 并入核心表（规则见 scripts\game_data.gd 的「内容注册」一节）。
## 流浪者机甲小队与战斗队友的行为在 scripts\factions\，地图边缘转场在 scripts\world_link.gd。
##
## LOOT_TABLES  流浪者机甲残骸的掉落表（身上每件已装备模块各有 15% 概率爆出，见 npc_mech.gd 的 _drop_loot）。

const LOOT_TABLES := {
	"rover": {"name": "流浪者残骸", "rolls": [2, 3], "pool": {"bolts": 22, "wire": 18, "circuit": 18, "fuel_cell": 16, "repair_kit": 10, "credit_s": 10, "hdd": 6}},
}
