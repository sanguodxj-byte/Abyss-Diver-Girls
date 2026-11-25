extends RefCounted
## 废弃通讯中继铁塔（残破重制）：通过 PrefabLib 接入波次 4 残破格构塔、机房与双碟形天线，
## 完整保留终端机交互、两只铅封军用箱解锁（poi_unlocks）、档案《研究笔记》与全部补给容器。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/map_ext/poi_kit.gd")
const PrefabLib = preload("res://scripts/buildings/prefab_lib.gd")


static func _block(raid, pos: Vector3, sz: Vector3, rot := 0.0, cyl := false) -> void:
	K.blocker(raid, pos, sz, rot, cyl)
	raid.blocks.append(raid._rect_for(pos, sz))


static func build(raid, c: Vector3, pid: String) -> void:
	PrefabLib.place_at_ground(raid, raid.world, "poi_relay_tower_remake", c, 0.0)
	# 紧贴中继格构塔、西南设备机房与东侧双碟形天线，中央与西北院坪保持宽阔通道
	_block(raid, c + Vector3(1.8, 0.0, -2.4), Vector3(5.6, 22.0, 5.6))
	_block(raid, c + Vector3(-5.2, 0.0, 4.1), Vector3(6.2, 5.0, 6.0))
	_block(raid, c + Vector3(5.7, 0.0, 3.6), Vector3(3.6, 3.8, 3.6), 0.0, true)
	_block(raid, c + Vector3(6.3, 0.0, -2.0), Vector3(3.2, 3.6, 3.2), 0.0, true)
	# 终端机台：设于院内中南开阔坪，供打开解锁两只铅封军用箱
	var term := c + Vector3(1.0, 0.0, 5.4)
	K.desk(raid, term, 180.0, 2.6, Color(0.3, 0.32, 0.3))
	A.add(raid.world, A.bevel_box(Vector3(0.9, 0.7, 0.1), 0.02), A.paint(Color(0.15, 0.16, 0.15), 0.3, 0.5), term + Vector3(0.0, 1.25, -0.1), Vector3(-14.0, 0.0, 0.0))
	A.add(raid.world, A.bevel_box(Vector3(0.78, 0.52, 0.04), 0.01), A.emit(Color(0.3, 0.8, 0.55), 1.1), term + Vector3(0.0, 1.26, -0.17), Vector3(-14.0, 0.0, 0.0), Vector3.ONE, false)
	# 两只铅封军用箱（置于北侧空地），终端打开后由 events.gd 替换为真军用箱
	var sealed: Array = []
	var M_STRAP := A.metal(Color(0.18, 0.19, 0.20))
	for p: Vector3 in [Vector3(-2.6, 0.0, -7.8), Vector3(-0.6, 0.0, -7.8)]:
		var b := Node3D.new()
		raid.world.add_child(b)
		b.position = c + p
		A.add(b, A.bevel_box(Vector3(1.65, 0.82, 0.98), 0.06), A.paint(Color(0.28, 0.32, 0.23), 0.32, 0.65, {"wear": 0.6, "rust": 0.5, "dust": 0.5}), Vector3(0.0, 0.41, 0.0))
		A.add(b, A.bevel_box(Vector3(1.70, 0.12, 1.02), 0.02), A.hazard(), Vector3(0.0, 0.68, 0.0))
		for sx_s: float in [-0.48, 0.48]:
			A.add(b, A.bevel_box(Vector3(0.08, 0.86, 1.04), 0.01), M_STRAP, Vector3(sx_s, 0.42, 0.0))
		A.add(b, A.bevel_box(Vector3(0.16, 0.20, 0.08), 0.01), A.paint(Color(0.72, 0.18, 0.14), 0.3, 0.5), Vector3(0.0, 0.58, 0.52))
		sealed.append({"pos": c + p, "node": b})
	# 容器与档案
	K.crate(raid, term + Vector3(0.0, 0.0, 1.4), "tech", [], 180.0)
	K.fixed(raid, c + Vector3(4.6, 0.0, -7.4), ["arch_research_note", "hdd"], "tech", 180.0)
	K.crate(raid, c + Vector3(-9.8, 0.0, 4.0), "safe", [], -90.0)
	K.crate(raid, c + Vector3(-6.0, 0.0, -5.0), "supply", [], 180.0)
	K.crate(raid, c + Vector3(9.4, 0.0, 5.2), "military", [], 0.0)
	# 灯光与守卫
	K.lamp(raid, c + Vector3(-8.2, 0.0, -8.4), Color(0.7, 0.9, 1.0))
	K.lamp(raid, c + Vector3(8.4, 0.0, 2.0), Color(1.0, 0.7, 0.4))
	K.guard(raid, c + Vector3(0.6, 0.0, 2.6), "beetle", 2.2)
	K.guard(raid, c + Vector3(-5.0, 0.0, -2.0), "spitter", 2.4)
	K.label(raid, c, str(GameData.POIS.get(pid, {}).get("name", "")), 9.0)
	K.tag_boxes(raid, c, pid, 16.5)
	# 解锁关系交给行动扩展脚本：终端被打开后，铅封箱换成真正的军用储物箱
	var unlocks: Array = raid.get_meta("poi_unlocks", [])
	unlocks.append({"terminal": term + Vector3(0.0, 0.0, 1.4), "caches": sealed})
	raid.set_meta("poi_unlocks", unlocks)
