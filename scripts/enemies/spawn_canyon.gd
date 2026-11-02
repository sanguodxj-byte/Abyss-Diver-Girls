extends RefCounted
## 裂谷矿区的虫群布置：常规虫群按分布表铺开；第五章打通后，铁甲王虫守在虫巢裂隙与弹坑谷深处。
## ch6_done 之后不再出现，避免已经通关的存档每次下矿都要再打一次。

const Util = preload("res://scripts/enemies/spawn_util.gd")


static func spawn(raid, drop: Vector3) -> void:
	Util.fill(raid, drop)
	if Story.has_flag("ch6_done"):
		return
	if not Story.has_flag("ch5_done"):
		return
	Util.place_boss(raid, "king_beetle", ["S", "C"], 130.0, drop)
