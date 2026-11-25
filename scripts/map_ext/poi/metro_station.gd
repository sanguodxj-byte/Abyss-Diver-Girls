extends RefCounted
## 三号线半塌地下铁站厅（残破重制）：通过 PrefabLib 接入波次 4 残破拱顶站厅，
## 东西向站厅通道直穿中心 c，紧贴背墙、售票亭、夹层扶梯与前护墙设碰撞，保留《值班日志》与全部容器。

const K = preload("res://scripts/map_ext/poi_kit.gd")
const PrefabLib = preload("res://scripts/buildings/prefab_lib.gd")


static func _block(raid, pos: Vector3, sz: Vector3, rot := 0.0, cyl := false) -> void:
	K.blocker(raid, pos, sz, rot, cyl)
	raid.blocks.append(raid._rect_for(pos, sz))


static func build(raid, c: Vector3, pid: String) -> void:
	PrefabLib.place_at_ground(raid, raid.world, "poi_metro_station_remake", c, 0.0)
	# 背墙 + 售票亭 + 夹层停运扶梯 + 南护墙，东西两端各留 6.5m 宽通道直通站厅中心 c
	_block(raid, c + Vector3(0.0, 0.0, -5.4), Vector3(18.8, 3.8, 0.9))
	_block(raid, c + Vector3(-6.5, 0.0, -3.5), Vector3(3.6, 3.0, 2.6))
	_block(raid, c + Vector3(7.0, 0.0, -3.6), Vector3(5.6, 3.6, 3.0))
	_block(raid, c + Vector3(0.0, 0.0, 5.6), Vector3(19.2, 2.4, 0.7))
	# 容器与档案
	K.fixed(raid, c + Vector3(-11.2, 0.0, 0.4), ["arch_duty_log", "circuit"], "tech", -90.0)
	K.crate(raid, c + Vector3(-5.8, 0.0, -0.4), "register", [], 0.0)
	K.crate(raid, c + Vector3(-3.2, 0.0, 3.2), "tool", [], 0.0)
	K.crate(raid, c + Vector3(11.4, 0.0, 0.8), "weapon", [], 90.0)
	K.crate(raid, c + Vector3(11.2, 0.0, 3.2), "ammo", [], 90.0)
	K.crate(raid, c + Vector3(3.2, 0.0, 2.4), "supply", [], 180.0)
	# 灯光与守卫
	K.lamp(raid, c + Vector3(-12.2, 0.0, 5.6), Color(1.0, 0.78, 0.45))
	K.lamp(raid, c + Vector3(12.2, 0.0, -5.6), Color(0.65, 0.86, 1.0))
	K.guard(raid, c + Vector3(0.0, 0.0, 1.2), "beetle", 2.4)
	K.guard(raid, c + Vector3(-9.0, 0.0, 1.8), "ling", 2.2)
	K.guard(raid, c + Vector3(9.0, 0.0, 1.8), "ling", 2.2)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 8.0)
	K.tag_boxes(raid, c, pid, 16.5)
