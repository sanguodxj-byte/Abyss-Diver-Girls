extends RefCounted
## 声波诱饵信标：投到准星附近，落地后按节奏鸣叫把周围虫群引走。
## 只接受机甲当前能看到的落点（最远 12 米）；信标本体被咬碎会炸出一团电磁火花。

const Decoy = preload("res://scripts/modules/decoy_beacon.gd")


static func use(mech, _id) -> bool:
	var raid = mech.raid
	if raid == null or not is_instance_valid(raid):
		return false
	var from: Vector3 = mech.global_position
	var p: Vector3 = mech.aim_point
	p.y = 0.0
	if from.distance_to(p) < 1.5:
		p = from + mech.aim_dir() * 6.0
	if from.distance_to(p) > 12.0:
		p = from + (p - from).normalized() * 12.0
	var d = Decoy.new()
	d.setup(raid)
	d.position = p
	raid.fx.add_child(d)
	mech.message.emit("声波诱饵信标已投放")
	return true
