extends RefCounted
## 冷却剂罐：把冷却液压进动力炉回路，一段时间内整机耗能压到一半。
## 不补能源，只是把剩下的电用得更久；在撤离读条前灌一罐最划算。

const FX = preload("res://scripts/modules/weapon_fx.gd")

const COOL := Color(0.55, 0.9, 1.0)


static func use(mech, _id) -> bool:
	mech.drain_mul = 0.5
	var tok := int(mech.get_meta("_cool_tok", 0)) + 1
	mech.set_meta("_cool_tok", tok)
	var tree: SceneTree = mech.get_tree()
	var mid: int = mech.get_instance_id()
	tree.create_timer(20.0).timeout.connect(func():
		var o = instance_from_id(mid)
		if o != null and int(o.get_meta("_cool_tok", 0)) == tok:
			o.drain_mul = 1.0)
	mech.message.emit("冷却剂注入，耗能减半 20 秒")
	FX.shell(mech, COOL, 2.0, 0.5, 1.4)
	var raid = mech.raid
	if raid != null and is_instance_valid(raid):
		FX.light(raid, mech.global_position + Vector3(0, 1.6, 0), COOL, 2.2, 5.0, 0.3)
		Audio.play_sfx("coolant_vent", mech.global_position)
	return true
