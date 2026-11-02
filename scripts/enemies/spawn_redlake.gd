extends RefCounted
## 赤湖新区的虫群布置：常规虫群按分布表铺开，第四章期间在菌毯/弹坑里伏着赤湖巢母。
## 巢母被打掉、章节推进到 ch4_done 之后不再出现；其余虫群分布不随章节变化。

const Util = preload("res://scripts/enemies/spawn_util.gd")


static func spawn(raid, drop: Vector3) -> void:
	Util.fill(raid, drop)
	if Story.has_flag("ch4_done"):
		return
	Util.place_boss(raid, "broodmother", ["S", "C"], 120.0, drop)
