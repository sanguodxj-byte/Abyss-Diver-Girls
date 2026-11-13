extends RefCounted
## 裂谷矿区的虫群布置：裂隙虫巢盘踞裂谷铁甲王虫（king_beetle），矿坑盘踞裂谷碎岩暴君（gorge_tyrant），斗轮挖掘机平台驻守斗轮裂岩泰坦（excavator_titan）。

const Util = preload("res://scripts/enemies/spawn_util.gd")


static func spawn(raid, drop: Vector3) -> void:
	Util.fill(raid, drop)
	var avoid: Array = []
	var b1 = Util.place_boss(raid, "king_beetle", ["S", "C"], 115.0, drop, ["ironjaw", "burrower", "burrower", "mech_beetle"])
	if b1 != null:
		avoid.append(b1.position)
	var b2 = Util.place_boss(raid, "gorge_tyrant", ["I", "M", "Y", "W", "C"], 85.0, drop, ["ripper", "ripper", "ironjaw", "mortar"], avoid)
	if b2 != null:
		avoid.append(b2.position)
	Util.place_boss_at_landmark(raid, "excavator_titan", "bucket_excavator", ["I", "M", "C", "W"], drop, ["ironjaw", "ripper", "mortar"], avoid)
