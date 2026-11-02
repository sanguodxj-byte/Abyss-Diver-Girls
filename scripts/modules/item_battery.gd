extends RefCounted
## 高能电池棒：一次性灌入大额能源，应急模式下也能用。
## 能源已满时不消耗。

const FX = preload("res://scripts/modules/weapon_fx.gd")

const CELL := Color(1.0, 0.78, 0.2)


static func use(mech, _id) -> bool:
	if mech.energy >= mech.max_energy - 0.1 and mech.emergency <= 0.0:
		mech.message.emit("能源已满")
		Audio.play_sfx("use_denied")
		return false
	mech.energy = minf(mech.max_energy, mech.energy + 70.0)
	mech.emergency = 0.0
	mech.message.emit("高能电池棒接入 +70 能量")
	FX.shell(mech, CELL, 2.0, 0.4)
	var raid = mech.raid
	if raid != null and is_instance_valid(raid):
		FX.light(raid, mech.global_position + Vector3(0, 1.6, 0), CELL, 3.0, 6.0, 0.25)
		Audio.play_sfx("energy_cell_plug", mech.global_position)
	return true
