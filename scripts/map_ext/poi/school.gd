extends RefCounted
## 城西学校（残破重制）：通过 PrefabLib 接入波次 4 残破教学楼、钟楼与塌顶体育馆，
## 东南操场开阔可达，紧贴教学楼、钟楼与体育馆设碰撞，保留全部 6 只容器与《儿童涂鸦》。

const K = preload("res://scripts/map_ext/poi_kit.gd")
const PrefabLib = preload("res://scripts/buildings/prefab_lib.gd")


static func _block(raid, pos: Vector3, sz: Vector3, rot := 0.0, cyl := false) -> void:
	K.blocker(raid, pos, sz, rot, cyl)
	raid.blocks.append(raid._rect_for(pos, sz))


static func build(raid, c: Vector3, pid: String) -> void:
	PrefabLib.place_at_ground(raid, raid.world, "poi_school_remake", c, 0.0)
	# 教学主楼 + 正面钟楼 + 西南体育馆，东南操场（z>=1.5, x>=-2）开阔直通中心附近
	_block(raid, c + Vector3(0.0, 0.0, -4.8), Vector3(17.2, 8.0, 6.4))
	_block(raid, c + Vector3(0.0, 0.0, -0.4), Vector3(4.4, 9.6, 2.4))
	_block(raid, c + Vector3(-6.5, 0.0, 4.4), Vector3(6.6, 5.9, 7.5))
	# 容器与档案
	K.crate(raid, c + Vector3(10.8, 0.0, 1.8), "safe", [], 90.0)
	K.crate(raid, c + Vector3(4.2, 0.0, 2.2), "med", [], 180.0)
	K.crate(raid, c + Vector3(2.4, 0.0, 6.8), "supply", [], 0.0)
	K.crate(raid, c + Vector3(-11.4, 0.0, -2.0), "tool", [], -90.0)
	K.crate(raid, c + Vector3(-11.4, 0.0, 4.2), "supply", [], -90.0)
	K.fixed(raid, c + Vector3(6.4, 0.0, 7.6), ["arch_child_drawing"], "supply", 0.0)
	# 灯光与守卫
	K.lamp(raid, c + Vector3(-13.0, 0.0, 8.4), Color(1.0, 0.8, 0.5))
	K.lamp(raid, c + Vector3(12.0, 0.0, -5.0), Color(0.7, 0.85, 1.0))
	K.guard(raid, c + Vector3(2.0, 0.0, 3.6), "spitter", 2.4)
	K.guard(raid, c + Vector3(8.2, 0.0, 3.8), "ling", 2.2)
	K.guard(raid, c + Vector3(-11.0, 0.0, 1.2), "ling", 2.2)
	K.guard(raid, c + Vector3(3.0, 0.0, 9.2), "ling", 2.2)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 8.5)
	K.tag_boxes(raid, c, pid, 16.5)
