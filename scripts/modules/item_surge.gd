extends RefCounted
## 超频电芯：把超额电流硬灌进动力炉，立刻补一大截能源。
## 代价是回路发烫，接下来十秒耗能上升；能源已满时不消耗。

const FX = preload("res://scripts/modules/weapon_fx.gd")

const SURGE := Color(1.0, 0.72, 0.25)


static func use(mech, _id) -> bool:
	if mech.energy >= mech.max_energy - 0.1 and mech.emergency <= 0.0:
		mech.message.emit("能源已满")
		Audio.play_sfx("use_denied")
		return false
	mech.energy = minf(mech.max_energy, mech.energy + 85.0)
	mech.emergency = 0.0
	mech.drain_mul = 1.8
	var tok := int(mech.get_meta("_surge_tok", 0)) + 1
	mech.set_meta("_surge_tok", tok)
	var tree: SceneTree = mech.get_tree()
	var mid: int = mech.get_instance_id()
	tree.create_timer(10.0).timeout.connect(func():
		var o = instance_from_id(mid)
		if o != null and int(o.get_meta("_surge_tok", 0)) == tok:
			o.drain_mul = 1.0)
	mech.message.emit("超频电芯接入 +85 能量，回路过热带电 10 秒")
	FX.shell(mech, SURGE, 2.1, 0.6)
	var raid = mech.raid
	if raid != null and is_instance_valid(raid):
		FX.light(raid, mech.global_position + Vector3(0, 1.6, 0), SURGE, 3.4, 6.0, 0.3)
		Audio.play_sfx("energy_cell_plug", mech.global_position)
	return true
