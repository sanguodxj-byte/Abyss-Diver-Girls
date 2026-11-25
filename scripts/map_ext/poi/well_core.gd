extends RefCounted
## 零号深渊钻井核心（残破重制）：通过 PrefabLib 接入波次 4 战损井台、钻塔与绞车，
## 以圆柱核心包覆中央钻塔并紧贴绞车/控制台设碰撞，环形井台通道畅通，保留《深井记录》与全部容器。

const K = preload("res://scripts/map_ext/poi_kit.gd")
const PrefabLib = preload("res://scripts/buildings/prefab_lib.gd")


static func _block(raid, pos: Vector3, sz: Vector3, rot := 0.0, cyl := false) -> void:
	K.blocker(raid, pos, sz, rot, cyl)
	raid.blocks.append(raid._rect_for(pos, sz))


static func build(raid, c: Vector3, pid: String) -> void:
	PrefabLib.place_at_ground(raid, raid.world, "poi_well_core_remake", c, 0.0)
	# 中央钻塔核心圆柱碰撞（r=3.3m，外围 r>=4.4m 均可行走）+ 西侧绞车 + 南侧控制台
	_block(raid, c, Vector3(6.6, 21.6, 6.6), 0.0, true)
	_block(raid, c + Vector3(-6.3, 0.0, 0.0), Vector3(2.2, 2.0, 3.0))
	_block(raid, c + Vector3(2.6, 0.0, 5.7), Vector3(2.4, 1.6, 1.6))
	# 容器与档案
	K.crate(raid, c + Vector3(10.6, 0.0, 0.6), "safe", [], 90.0)
	K.crate(raid, c + Vector3(-1.4, 0.0, 10.8), "tech", [], 0.0)
	K.crate(raid, c + Vector3(-10.8, 0.0, -1.2), "weapon", [], -90.0)
	K.crate(raid, c + Vector3(8.2, 0.0, -8.8), "military", [], 180.0)
	K.fixed(raid, c + Vector3(9.4, 0.0, -5.8), ["arch_deep_record", "bug_crystal"], "tech", 180.0)
	K.fixed(raid, c + Vector3(-8.4, 0.0, 8.4), ["bug_crystal", "chitin", "chitin"], "cache", 0.0)
	# 灯光与守卫
	K.lamp(raid, c + Vector3(13.6, 0.0, 9.4), Color(1.0, 0.74, 0.42))
	K.lamp(raid, c + Vector3(-13.6, 0.0, -9.4), Color(0.5, 0.85, 0.9))
	K.guard(raid, c + Vector3(0.0, 0.0, 9.6), "beetle", 2.6)
	K.guard(raid, c + Vector3(-9.6, 0.0, 2.4), "beetle", 2.6)
	K.guard(raid, c + Vector3(6.8, 0.0, 7.6), "spitter", 2.4)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 13.0)
	K.tag_boxes(raid, c, pid, 16.5)
