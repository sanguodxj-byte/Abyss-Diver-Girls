extends RefCounted
## 七号重装公路检查站（残破重制）：通过 PrefabLib 接入波次 4 残破检查站模型，保留原版通行车道、
## 实体碰撞、全部 6 只补给箱（含档案《转运清单》）、灯光与守卫配置。

const K = preload("res://scripts/map_ext/poi_kit.gd")
const PrefabLib = preload("res://scripts/buildings/prefab_lib.gd")


static func _block(raid, pos: Vector3, sz: Vector3, rot := 0.0, cyl := false) -> void:
	K.blocker(raid, pos, sz, rot, cyl)
	raid.blocks.append(raid._rect_for(pos, sz))


static func build(raid, c: Vector3, pid: String) -> void:
	PrefabLib.place_at_ground(raid, raid.world, "poi_checkpoint_remake", c, 0.0)
	# 紧贴南北装甲哨亭与东侧瞭望塔，中央检查车道（z: -2.2..+2.2）保持畅通
	_block(raid, c + Vector3(0.0, 0.0, -4.0), Vector3(4.4, 3.8, 3.6))
	_block(raid, c + Vector3(0.0, 0.0, 4.0), Vector3(4.4, 3.8, 3.6))
	_block(raid, c + Vector3(7.3, 0.0, -3.0), Vector3(4.4, 8.6, 4.4))
	# 容器与档案（全部远离碰撞盒且处于 15m 归属半径内）
	K.crate(raid, c + Vector3(-4.2, 0.0, -4.2), "safe", [], 180.0)
	K.crate(raid, c + Vector3(-5.6, 0.0, 1.2), "ammo", [], 180.0)
	K.crate(raid, c + Vector3(4.2, 0.0, 1.4), "military", [], 180.0)
	K.crate(raid, c + Vector3(-4.2, 0.0, 4.2), "register", [], 0.0)
	K.fixed(raid, c + Vector3(4.2, 0.0, 4.2), ["arch_manifest", "credit_s"], "register", 0.0)
	K.crate(raid, c + Vector3(11.0, 0.0, 3.2), "supply", [], 90.0)
	# 灯光与守卫
	K.lamp(raid, c + Vector3(-11.4, 0.0, -6.2), Color(1.0, 0.78, 0.45))
	K.lamp(raid, c + Vector3(11.4, 0.0, 6.2), Color(0.7, 0.85, 1.0))
	K.guard(raid, c + Vector3(0.0, 0.0, 0.4), "beetle", 2.2)
	K.guard(raid, c + Vector3(-8.0, 0.0, -1.0), "ling", 2.4)
	K.guard(raid, c + Vector3(9.0, 0.0, 2.0), "ling", 2.4)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 7.5)
	K.tag_boxes(raid, c, pid, 16.5)
