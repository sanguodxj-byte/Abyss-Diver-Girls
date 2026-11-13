extends RefCounted
## 零号深渊井的虫群布置：中央母巢盘踞深渊母皇（abyss_queen），外环要塞盘踞深渊先驱魔像（abyss_harbinger），地热磁约束腔驻守地热磁暴主宰（core_overlord）。

const Util = preload("res://scripts/enemies/spawn_util.gd")


static func spawn(raid, drop: Vector3) -> void:
	Util.fill(raid, drop)
	var avoid: Array = []
	var b1 = Util.place_boss(raid, "abyss_queen", ["S", "C"], 95.0, drop, ["crystal_bug", "crystal_bug", "mech_beetle", "mortar", "ironjaw"])
	if b1 != null:
		avoid.append(b1.position)
	var b2 = Util.place_boss(raid, "abyss_harbinger", ["C", "M", "I", "W", "S"], 85.0, drop, ["aegis", "overseer", "wasp", "wasp"], avoid)
	if b2 != null:
		avoid.append(b2.position)
	Util.place_boss_at_landmark(raid, "core_overlord", "geothermal_vault", ["C", "W", "S"], drop, ["aegis", "ironjaw", "mech_beetle"], avoid)
