extends RefCounted
## 派系团队的扩展数据：启动时由 GameData 并入核心表（规则见 scripts\game_data.gd 的「内容注册」一节）。
## 流浪者机甲小队与战斗队友的行为在 scripts\factions\，地图边缘转场在 scripts\world_link.gd。
##
## LOOT_TABLES  流浪者机甲残骸的掉落表（另有一半概率直接拆下它身上的一件模块，见 npc_mech.gd 的 _drop_loot）。

const LOOT_TABLES := {
	"rover": {"name": "流浪者残骸", "rolls": [2, 3], "pool": {"bolts": 18, "wire": 16, "circuit": 16, "fuel_cell": 14, "repair_kit": 10, "@module": 12, "credit_s": 9, "hdd": 5}},
}
