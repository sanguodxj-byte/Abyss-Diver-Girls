extends RefCounted
## 城南战地门诊楼（残破重制）：通过 PrefabLib 接入波次 4 残破医院模型，
## 救护雨棚中庭居中敞开，紧贴门诊主楼、发电机棚与检伤帐篷设置碰撞，保留医疗箱与档案《旧合影》。

const K = preload("res://scripts/map_ext/poi_kit.gd")
const PrefabLib = preload("res://scripts/buildings/prefab_lib.gd")


static func _block(raid, pos: Vector3, sz: Vector3, rot := 0.0, cyl := false) -> void:
	K.blocker(raid, pos, sz, rot, cyl)
	raid.blocks.append(raid._rect_for(pos, sz))


static func build(raid, c: Vector3, pid: String) -> void:
	var origin := c + Vector3(0.0, 0.0, -2.5)
	PrefabLib.place_at_ground(raid, raid.world, "poi_hospital_remake", origin, 0.0)
	# 门诊主楼 + 西南发电机棚 + 东南检伤帐篷，中央救护中庭 c=(0,0) 畅通无阻
	_block(raid, origin + Vector3(0.0, 0.0, -2.4), Vector3(14.6, 8.0, 8.0))
	_block(raid, origin + Vector3(-6.6, 0.0, 5.3), Vector3(4.8, 3.7, 4.0))
	_block(raid, origin + Vector3(5.2, 0.0, 5.5), Vector3(5.2, 3.0, 5.4))
	# 容器与档案
	K.crate(raid, c + Vector3(9.8, 0.0, 1.5), "safe", [], 90.0)
	K.crate(raid, c + Vector3(0.0, 0.0, 3.8), "med", [], 180.0)
	K.crate(raid, c + Vector3(-2.0, 0.0, 6.8), "med", [], 0.0)
	K.crate(raid, c + Vector3(-10.4, 0.0, 3.2), "tech", [], -90.0)
	K.crate(raid, c + Vector3(9.6, 0.0, -4.2), "register", [], 90.0)
	K.fixed(raid, c + Vector3(1.6, 0.0, 7.2), ["arch_photo", "water_tab"], "med", 0.0)
	# 灯光与守卫
	K.lamp(raid, c + Vector3(-12.4, 0.0, -1.2), Color(1.0, 0.82, 0.55))
	K.lamp(raid, c + Vector3(12.2, 0.0, 8.4), Color(0.6, 0.82, 1.0))
	K.guard(raid, c + Vector3(0.0, 0.0, 1.6), "beetle", 2.4)
	K.guard(raid, c + Vector3(9.6, 0.0, 4.2), "spitter", 2.4)
	K.guard(raid, c + Vector3(-10.2, 0.0, -2.0), "spitter", 2.4)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 8.5)
	K.tag_boxes(raid, c, pid, 16.5)
