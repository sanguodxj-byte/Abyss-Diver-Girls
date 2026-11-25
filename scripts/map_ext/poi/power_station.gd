extends RefCounted
## 北区汽轮机发电厂（残破重制）：通过 PrefabLib 接入波次 4 战损汽轮机房、双冷却塔与变电区，
## 中央巡检通道直穿中心 c，保留全部 6 只容器（含档案《反应堆蓝图》）、灯光与守卫。

const K = preload("res://scripts/map_ext/poi_kit.gd")
const PrefabLib = preload("res://scripts/buildings/prefab_lib.gd")


static func _block(raid, pos: Vector3, sz: Vector3, rot := 0.0, cyl := false) -> void:
	K.blocker(raid, pos, sz, rot, cyl)
	raid.blocks.append(raid._rect_for(pos, sz))


static func build(raid, c: Vector3, pid: String) -> void:
	PrefabLib.place_at_ground(raid, raid.world, "poi_power_station_remake", c, 0.0)
	# 紧贴汽轮机房、双冷却塔与变电区，留出中央南北巡检廊（x: +0.2..+2.8）直抵中心 c 附近
	_block(raid, c + Vector3(-5.6, 0.0, -2.2), Vector3(9.6, 10.6, 9.2))
	_block(raid, c + Vector3(6.2, 0.0, -4.6), Vector3(6.8, 14.0, 6.8), 0.0, true)
	_block(raid, c + Vector3(6.8, 0.0, 3.4), Vector3(6.0, 11.6, 6.0), 0.0, true)
	_block(raid, c + Vector3(-4.4, 0.0, 5.2), Vector3(9.2, 4.8, 4.2))
	# 容器与档案
	K.crate(raid, c + Vector3(-12.2, 0.0, -2.0), "tool", [], -90.0)
	K.crate(raid, c + Vector3(1.8, 0.0, -1.2), "tech", [], 0.0)
	K.crate(raid, c + Vector3(-11.4, 0.0, 6.2), "military", [], 0.0)
	K.crate(raid, c + Vector3(2.4, 0.0, 9.2), "safe", [], 0.0)
	K.fixed(raid, c + Vector3(-2.0, 0.0, 9.4), ["arch_blueprint", "circuit"], "tech", 0.0)
	K.crate(raid, c + Vector3(6.8, 0.0, -10.2), "ammo", [], 180.0)
	# 灯光与守卫
	K.lamp(raid, c + Vector3(-13.6, 0.0, -9.2), Color(1.0, 0.76, 0.42))
	K.lamp(raid, c + Vector3(13.6, 0.0, 0.0), Color(0.72, 0.86, 1.0))
	K.guard(raid, c + Vector3(1.8, 0.0, 3.0), "beetle", 2.0)
	K.guard(raid, c + Vector3(1.4, 0.0, -8.2), "beetle", 2.4)
	K.guard(raid, c + Vector3(10.8, 0.0, -6.0), "spitter", 2.2)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 9.0)
	K.tag_boxes(raid, c, pid, 16.5)
