extends "res://tests/lib/test_base.gd"
## 清理超额尸体不能吞掉自爆虫死亡后已经点燃的引信。
const START := "none"
const Raid = preload("res://scripts/raid.gd")
const Enemy = preload("res://scripts/enemies/enemy.gd")


class BlastRaid extends Raid:
	var blasts := 0
	func on_bug_killed(b) -> void:
		_register_corpse(b)
	func explode(_p: Vector3, _radius: float, _dmg: float, _sfx := "explosion", _notify_hit := false) -> void:
		blasts += 1
	func bug_foes() -> Array:
		return []


func run() -> void:
	var raid := BlastRaid.new()
	add_child(raid)
	raid.set_process(false)
	raid.world = Node3D.new()
	raid.fx = Node3D.new()
	raid.add_child(raid.world)
	raid.add_child(raid.fx)
	for i in 22:
		var bomber := Enemy.new()
		bomber.setup("bomber", raid, null)
		raid.world.add_child(bomber)
		bomber.position.x = i * 12.0
		bomber.set_physics_process(false)
		bomber.drop_chance = 0.0
		bomber.pool_dur = 0.0
		bomber._on_killed()
	await wait_real(1.0)
	log_line("22 killed bombers, delayed blasts=%d, retained corpses=%d" % [raid.blasts, raid._corpses.size()])
	if not check(raid.blasts == 22, "超额尸体清理取消了已经点燃的引信"): return
	var last := Enemy.new()
	last.setup("bomber", raid, null)
	raid.world.add_child(last)
	last.set_physics_process(false)
	last.drop_chance = 0.0
	last._on_killed()
	raid.queue_free()
	await wait_real(0.6)
