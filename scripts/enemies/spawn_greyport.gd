extends RefCounted
## 灰港市的虫群布置：东南弹坑地盘踞灰港巢母（grey_brood），货运港盘踞灰港猎潮镰王（harbor_reaper），中央穹顶总站驻守总站巡道铁卫（terminus_warden）。

const Util = preload("res://scripts/enemies/spawn_util.gd")


static func spawn(raid, drop: Vector3) -> void:
	Util.fill(raid, drop)
	var avoid: Array = []
	var b1 = Util.place_boss(raid, "grey_brood", ["S", "C"], 100.0, drop, ["beetle", "spitter", "spitter", "wasp"])
	if b1 != null:
		avoid.append(b1.position)
	var b2 = Util.place_boss(raid, "harbor_reaper", ["H", "W", "I", "M", "C"], 85.0, drop, ["mantis", "mantis", "wasp", "spitter"], avoid)
	if b2 != null:
		avoid.append(b2.position)
	Util.place_boss_at_landmark(raid, "terminus_warden", "central_terminus", ["D", "Y", "I", "M"], drop, ["mech_beetle", "mantis", "spitter"], avoid)
