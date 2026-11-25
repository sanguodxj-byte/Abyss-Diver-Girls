extends RefCounted
## 东区多层立体停车楼（残破重制）：通过 PrefabLib 接入波次 4 塌角立体车库，
## 首层停车厅敞开直通中心 c，紧贴电梯核心筒、岗亭与坡道设碰撞，保留全部 7 只容器与《磁带》。

const K = preload("res://scripts/map_ext/poi_kit.gd")
const PrefabLib = preload("res://scripts/buildings/prefab_lib.gd")


static func _block(raid, pos: Vector3, sz: Vector3, rot := 0.0, cyl := false) -> void:
	K.blocker(raid, pos, sz, rot, cyl)
	raid.blocks.append(raid._rect_for(pos, sz))


static func build(raid, c: Vector3, pid: String) -> void:
	PrefabLib.place_at_ground(raid, raid.world, "poi_parking_garage_remake", c, 0.0)
	# 首层停车甲板保持通透，仅实体化东北电梯核心筒、西南收费岗亭与首层实心坡道
	_block(raid, c + Vector3(7.5, 0.0, -5.2), Vector3(3.6, 12.6, 3.4))
	_block(raid, c + Vector3(-7.4, 0.0, 4.9), Vector3(3.4, 2.8, 4.0))
	_block(raid, c + Vector3(-1.1, 0.0, 4.2), Vector3(7.4, 3.8, 2.8))
	# 容器与档案
	K.crate(raid, c + Vector3(-1.0, 0.0, 8.4), "military", [], 0.0)
	K.crate(raid, c + Vector3(2.8, 0.0, 8.4), "ammo", [], 0.0)
	K.crate(raid, c + Vector3(-8.8, 0.0, 0.2), "tool", [], -90.0)
	K.crate(raid, c + Vector3(7.2, 0.0, 0.4), "safe", [], 90.0)
	K.crate(raid, c + Vector3(-6.4, 0.0, -5.2), "register", [], 180.0)
	K.fixed(raid, c + Vector3(0.4, 0.0, -4.6), ["arch_tape"], "tool", 180.0)
	K.crate(raid, c + Vector3(9.4, 0.0, 4.4), "supply", [], 90.0)
	# 灯光与守卫
	K.lamp(raid, c + Vector3(-11.4, 0.0, -6.6), Color(1.0, 0.78, 0.45))
	K.lamp(raid, c + Vector3(11.6, 0.0, 8.6), Color(0.75, 0.85, 1.0))
	K.guard(raid, c + Vector3(1.0, 0.0, -0.8), "beetle", 2.4)
	K.guard(raid, c + Vector3(-6.0, 0.0, -1.6), "ling", 2.2)
	K.guard(raid, c + Vector3(6.0, 0.0, 4.4), "ling", 2.2)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 8.5)
	K.tag_boxes(raid, c, pid, 16.5)
