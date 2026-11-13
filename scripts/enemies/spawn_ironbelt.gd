extends RefCounted
## 铁锈工业带的虫群布置：废渣池盘踞铁锈重甲王虫（iron_warden），北段高炉盘踞熔渣巨炮皇虫（slag_colossus），二号转炉钢厂驻守转炉熔渣无畏舰（foundry_dreadnought）。

const Util = preload("res://scripts/enemies/spawn_util.gd")


static func spawn(raid, drop: Vector3) -> void:
	Util.fill(raid, drop)
	var avoid: Array = []
	var b1 = Util.place_boss(raid, "iron_warden", ["S", "C"], 105.0, drop, ["mantis", "mantis", "mech_beetle", "shielder"])
	if b1 != null:
		avoid.append(b1.position)
	var b2 = Util.place_boss(raid, "slag_colossus", ["I", "Y", "M", "W", "C"], 85.0, drop, ["mortar", "mortar", "mech_beetle", "ripper"], avoid)
	if b2 != null:
		avoid.append(b2.position)
	Util.place_boss_at_landmark(raid, "foundry_dreadnought", "converter_foundry", ["I", "Y", "W"], drop, ["aegis", "mortar", "ripper"], avoid)
