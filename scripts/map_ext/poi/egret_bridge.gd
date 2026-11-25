extends RefCounted
## 白鹭号坠毁装甲舰桥舱（残破重制）：通过 PrefabLib 接入波次 5 坠毁舰桥模型，
## 保留紧贴舰体与断桅的实体碰撞、黑匣子档案《飞行日志》与全部 6 只补给容器、灯光与守卫。

const K = preload("res://scripts/map_ext/poi_kit.gd")
const PrefabLib = preload("res://scripts/buildings/prefab_lib.gd")


static func _block(raid, pos: Vector3, sz: Vector3, rot := 0.0, cyl := false) -> void:
	K.blocker(raid, pos, sz, rot, cyl)
	raid.blocks.append(raid._rect_for(pos, sz))


static func build(raid, c: Vector3, pid: String) -> void:
	var origin := c + Vector3(0.0, 0.0, -2.0)
	PrefabLib.place_at_ground(raid, raid.world, "poi_egret_bridge_remake", origin, 0.0)
	# 紧贴坠毁舰桥主舱与北侧折断桅杆，+Z 坠落前缘空地距中心 c 仅 3.2m
	_block(raid, origin + Vector3(0.3, 0.0, 0.0), Vector3(12.6, 6.0, 8.0))
	_block(raid, origin + Vector3(3.1, 0.0, -5.5), Vector3(3.4, 5.5, 2.2))
	# 黑匣子与残骸周边补给箱
	K.fixed(raid, c + Vector3(3.2, 0.0, 4.6), ["arch_flight_log", "hdd", "bug_crystal"], "tech", 180.0)
	K.crate(raid, c + Vector3(-4.8, 0.0, 4.8), "weapon", [], 0.0)
	K.crate(raid, c + Vector3(-7.6, 0.0, 5.2), "ammo", [], 0.0)
	K.crate(raid, c + Vector3(8.6, 0.0, 2.8), "tech", [], 90.0)
	K.crate(raid, c + Vector3(-9.2, 0.0, -4.8), "med", [], -90.0)
	K.crate(raid, c + Vector3(8.8, 0.0, -5.2), "supply", [], 90.0)
	# 氛围灯与守卫
	K.lamp(raid, c + Vector3(-9.6, 0.0, -8.4), Color(1.0, 0.72, 0.4))
	K.lamp(raid, c + Vector3(10.0, 0.0, 3.0), Color(0.62, 0.85, 1.0))
	K.guard(raid, c + Vector3(1.0, 0.0, 5.2), "beetle", 2.8)
	K.guard(raid, c + Vector3(-4.0, 0.0, 5.6), "beetle", 2.8)
	K.guard(raid, c + Vector3(8.0, 0.0, 0.0), "ling", 2.2)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 9.5)
	K.tag_boxes(raid, c, pid, 16.5)
