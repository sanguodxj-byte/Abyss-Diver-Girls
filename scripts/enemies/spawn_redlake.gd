extends RefCounted
## 赤湖新区的虫群布置：南部菌毯盘踞赤湖巢母（broodmother），湖畔科研区盘踞赤湖棱镜主宰（prism_archon），赤湖溢洪闸枢驻守溢洪闸枢巨鳌（spillway_leviathan）。

const Util = preload("res://scripts/enemies/spawn_util.gd")


static func spawn(raid, drop: Vector3) -> void:
	Util.fill(raid, drop)
	var avoid: Array = []
	var b1 = Util.place_boss(raid, "broodmother", ["S", "C"], 110.0, drop, ["crystal_bug", "crystal_bug", "shielder", "spitter"])
	if b1 != null:
		avoid.append(b1.position)
	var b2 = Util.place_boss(raid, "prism_archon", ["T", "M", "P", "C", "W"], 85.0, drop, ["crystal_bug", "overseer", "shielder", "spitter"], avoid)
	if b2 != null:
		avoid.append(b2.position)
	Util.place_boss_at_landmark(raid, "spillway_leviathan", "spillway_dam", ["P", "W", "T", "C"], drop, ["shielder", "crystal_bug", "mortar"], avoid)
