extends RefCounted
## 深井选矿装车终端（残破重制）：通过 PrefabLib 接入波次 4 残破龙门吊、三联选矿筒仓与高架控制室，
## 紧贴矿车、三座筒仓与控制室设碰撞，中心装车通道保持敞开，保留全部 6 只容器与《值班交接日志》。

const K = preload("res://scripts/map_ext/poi_kit.gd")
const PrefabLib = preload("res://scripts/buildings/prefab_lib.gd")


static func _block(raid, pos: Vector3, sz: Vector3, rot := 0.0, cyl := false) -> void:
	K.blocker(raid, pos, sz, rot, cyl)
	raid.blocks.append(raid._rect_for(pos, sz))


static func build(raid, c: Vector3, pid: String) -> void:
	PrefabLib.place_at_ground(raid, raid.world, "poi_mining_terminal_remake", c, 0.0)
	# 紧贴矿车、三座选矿筒仓与控制室，中央装车线 c=(0,0) 保持畅通
	_block(raid, c + Vector3(-5.4, 0.0, 2.6), Vector3(2.4, 2.1, 4.0))
	_block(raid, c + Vector3(3.9, 0.0, -2.2), Vector3(3.6, 11.0, 3.6), 0.0, true)
	_block(raid, c + Vector3(7.7, 0.0, -2.2), Vector3(3.6, 11.0, 3.6), 0.0, true)
	_block(raid, c + Vector3(5.8, 0.0, 2.4), Vector3(3.6, 10.0, 3.6), 0.0, true)
	_block(raid, c + Vector3(0.3, 0.0, 3.5), Vector3(5.6, 6.5, 4.8))
	# 容器与档案
	K.crate(raid, c + Vector3(11.4, 0.0, 0.2), "safe", [], 90.0)
	K.crate(raid, c + Vector3(0.4, 0.0, -6.4), "tool", [], 180.0)
	K.crate(raid, c + Vector3(-3.8, 0.0, -6.6), "tech", [], 180.0)
	K.crate(raid, c + Vector3(-8.4, 0.0, 6.4), "military", [], 0.0)
	K.fixed(raid, c + Vector3(-9.6, 0.0, -1.8), ["bug_crystal", "chitin"], "cache", -90.0)
	K.fixed(raid, c + Vector3(1.2, 0.0, 8.2), ["arch_shift_log", "circuit"], "tech", 0.0)
	# 灯光与守卫
	K.lamp(raid, c + Vector3(-12.6, 0.0, 8.6), Color(1.0, 0.74, 0.42))
	K.lamp(raid, c + Vector3(12.4, 0.0, -8.6), Color(0.7, 0.86, 1.0))
	K.guard(raid, c + Vector3(-1.0, 0.0, -2.4), "beetle", 2.4)
	K.guard(raid, c + Vector3(-9.2, 0.0, 2.0), "beetle", 2.6)
	K.guard(raid, c + Vector3(6.4, 0.0, 7.2), "ling", 2.2)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 12.0)
	K.tag_boxes(raid, c, pid, 16.5)
