extends RefCounted
## 沉没水质观测所（残破重制）：通过 PrefabLib 接入波次 4 残破穹顶站与北向断栈桥，
## 以圆柱实体包覆观测穹顶主体，保留前坪与两侧通道、全部 6 只补给容器与档案《观测记录》。

const K = preload("res://scripts/map_ext/poi_kit.gd")
const PrefabLib = preload("res://scripts/buildings/prefab_lib.gd")


static func _block(raid, pos: Vector3, sz: Vector3, rot := 0.0, cyl := false) -> void:
	K.blocker(raid, pos, sz, rot, cyl)
	raid.blocks.append(raid._rect_for(pos, sz))


static func build(raid, c: Vector3, pid: String) -> void:
	var dome_c := c + Vector3(0.0, 0.0, -3.5)
	PrefabLib.place_at_ground(raid, raid.world, "poi_hydro_lab_remake", dome_c, 0.0)
	# 穹顶主舱圆柱碰撞（半径 6.0m），前坪 z>=3.8 距中心 c 仅 3.8m
	_block(raid, dome_c, Vector3(12.0, 9.0, 12.0), 0.0, true)
	# 容器与档案
	K.crate(raid, c + Vector3(7.6, 0.0, -1.8), "safe", [], 90.0)
	K.crate(raid, c + Vector3(-7.6, 0.0, -1.4), "tech", [], -90.0)
	K.fixed(raid, c + Vector3(-2.6, 0.0, 4.6), ["arch_observation", "hdd"], "tech", 180.0)
	K.fixed(raid, c + Vector3(2.8, 0.0, 4.8), ["water_tab", "water_tab"], "med", 0.0)
	K.crate(raid, c + Vector3(-6.8, 0.0, 4.6), "cache", [], 0.0)
	K.crate(raid, c + Vector3(7.0, 0.0, 4.4), "military", [], 0.0)
	# 灯光与守卫
	K.lamp(raid, c + Vector3(8.2, 0.0, 5.4), Color(0.55, 0.85, 0.8))
	K.lamp(raid, c + Vector3(-8.8, 0.0, -7.4), Color(1.0, 0.72, 0.42))
	K.guard(raid, c + Vector3(-2.0, 0.0, 6.2), "spitter", 2.4)
	K.guard(raid, c + Vector3(3.0, 0.0, 6.4), "spitter", 2.4)
	K.guard(raid, c + Vector3(0.0, 0.0, 8.2), "ling", 2.2)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 9.0)
	K.tag_boxes(raid, c, pid, 16.5)
