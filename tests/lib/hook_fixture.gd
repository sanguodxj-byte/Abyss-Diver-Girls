extends Node
## tests\hooks.gd 用的扩展脚本样例：被临时登记进 GameData 的 RAID_SCRIPTS、AMMO、SKILLS、ITEMS，
## 每个入口被调用时在对象上打一个 meta 标记，测试据此确认 raid.gd 与 mech.gd 的扩展点都接通了。
## 同一个 use 同时充当技能脚本 use(mech, key, sk, m) 与消耗品脚本 use(mech, id) -> bool。

var raid


static func build(r, _drop: Vector3) -> void:
	r.set_meta("zz_built", true)


func setup(r) -> void:
	raid = r
	r.set_meta("zz_node_setup", true)


static func fire(mech, slot: String, _origin: Vector3, _dir: Vector3, _m: Dictionary) -> void:
	mech.set_meta("zz_fired", slot)


static func use(mech, a, sk = null, _m = null) -> bool:
	if sk == null:
		mech.set_meta("zz_item_used", str(a))
	else:
		mech.set_meta("zz_skill_used", str(a))
	return true
