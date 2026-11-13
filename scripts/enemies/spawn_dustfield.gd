extends RefCounted
## 尘土平原的虫群布置：南部虫巢盘踞荒原沙巢母（dust_matriarch），采石矿坑盘踞荒原噬沙钻皇（dune_devourer），洲际发射井阵地驻守井群弹道猎犬（silo_warhead）。

const Util = preload("res://scripts/enemies/spawn_util.gd")


static func spawn(raid, drop: Vector3) -> void:
	Util.fill(raid, drop)
	var avoid: Array = []
	var b1 = Util.place_boss(raid, "dust_matriarch", ["S", "C"], 105.0, drop, ["bomber", "bomber", "burrower", "lancer"])
	if b1 != null:
		avoid.append(b1.position)
	var b2 = Util.place_boss(raid, "dune_devourer", ["C", "K", "M", "W", "F"], 85.0, drop, ["burrower", "burrower", "bomber", "lancer"], avoid)
	if b2 != null:
		avoid.append(b2.position)
	Util.place_boss_at_landmark(raid, "silo_warhead", "missile_silo", ["M", "C", "F"], drop, ["lancer", "mech_beetle", "bomber"], avoid)
