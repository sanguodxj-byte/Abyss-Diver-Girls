extends RefCounted
## 撤离屏障：在脚下撑起一圈阻滞力场，把涌向撤离点的虫群拖慢十四秒。
## 屏障原地不动，放下后要站在它的覆盖范围里读完撤离条。

const Barrier = preload("res://scripts/modules/extract_barrier.gd")


static func use(mech, _id) -> bool:
	var raid = mech.raid
	if raid == null or not is_instance_valid(raid):
		return false
	var b = Barrier.new()
	b.setup(raid, 6.0, 14.0)
	b.position = mech.global_position
	raid.fx.add_child(b)
	mech.message.emit("撤离屏障展开")
	return true
