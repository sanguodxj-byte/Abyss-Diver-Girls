extends RefCounted
## 旧港教堂（残破重制）：通过 PrefabLib 接入残破钟楼与半塌中殿，正门朝 +Z 留出开阔前庭广场，
## 保留全部 6 只容器（含档案《未寄出的家书》）、氛围灯光与守卫。

const K = preload("res://scripts/map_ext/poi_kit.gd")
const PrefabLib = preload("res://scripts/buildings/prefab_lib.gd")


static func _block(raid, pos: Vector3, sz: Vector3, rot := 0.0, cyl := false) -> void:
	K.blocker(raid, pos, sz, rot, cyl)
	raid.blocks.append(raid._rect_for(pos, sz))


static func build(raid, c: Vector3, pid: String) -> void:
	# 旋转 180° 并后移 5m，使教堂正面入口朝向 +Z 前庭，保证中心 c 周边 <=3.5m 畅通可达
	PrefabLib.place_at_ground(raid, raid.world, "poi_church_remake", c + Vector3(0.0, 0.0, -5.0), 180.0)
	_block(raid, c + Vector3(0.0, 0.0, -6.5), Vector3(11.0, 8.0, 17.5))
	_block(raid, c + Vector3(-8.0, 0.0, 1.1), Vector3(4.6, 16.0, 4.5))
	# 容器与档案
	K.crate(raid, c + Vector3(2.8, 0.0, 6.4), "safe", [], 0.0)
	K.crate(raid, c + Vector3(-3.6, 0.0, 5.8), "med", [], 0.0)
	K.crate(raid, c + Vector3(8.2, 0.0, -3.5), "supply", [], 90.0)
	K.fixed(raid, c + Vector3(8.2, 0.0, 1.8), ["arch_letter"], "supply", 90.0)
	K.crate(raid, c + Vector3(-8.6, 0.0, 6.4), "cache", [], 0.0)
	K.crate(raid, c + Vector3(4.8, 0.0, 9.2), "safe", [], 90.0)
	# 灯光与守卫
	K.lamp(raid, c + Vector3(-11.4, 0.0, -2.0), Color(0.7, 0.8, 1.0))
	K.lamp(raid, c + Vector3(9.6, 0.0, 6.0), Color(1.0, 0.74, 0.4))
	K.guard(raid, c + Vector3(0.0, 0.0, 5.2), "beetle", 2.6)
	K.guard(raid, c + Vector3(-3.0, 0.0, 8.4), "spitter", 2.4)
	K.guard(raid, c + Vector3(8.0, 0.0, -1.0), "spitter", 2.4)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 9.5)
	K.tag_boxes(raid, c, pid, 16.5)
