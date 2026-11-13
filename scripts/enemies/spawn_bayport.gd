extends RefCounted
## 东湾船坞港的虫群布置：集装箱港湾与防波堤游弋灰港猎潮镰王（harbor_reaper），造船厂重机区盘踞熔渣巨炮皇虫（slag_colossus），巨型潜艇干船坞驻守船坞龙门巨兽（drydock_behemoth）。

const Util = preload("res://scripts/enemies/spawn_util.gd")


static func spawn(raid, drop: Vector3) -> void:
	Util.fill(raid, drop)
	var avoid: Array = []
	var b1 = Util.place_boss(raid, "harbor_reaper", ["H", "S", "C"], 100.0, drop, ["mantis", "mantis", "spitter", "shielder"])
	if b1 != null:
		avoid.append(b1.position)
	var b2 = Util.place_boss(raid, "slag_colossus", ["I", "Y", "M", "H"], 85.0, drop, ["mortar", "mech_beetle", "ripper"], avoid)
	if b2 != null:
		avoid.append(b2.position)
	Util.place_boss_at_landmark(raid, "drydock_behemoth", "submarine_drydock", ["H", "I", "M"], drop, ["aegis", "mortar", "mantis"], avoid)
