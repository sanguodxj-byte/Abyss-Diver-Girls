extends "res://tests/lib/test_base.gd"
const START := "none"
const Raid = preload("res://scripts/raid.gd")
const Enemy = preload("res://scripts/enemies/enemy.gd")
const Bug = preload("res://scripts/bug.gd")
const Art = preload("res://scripts/art.gd")


class Remains extends Node3D:
	var data := {"boss": false}
	var vis_anchor: Node3D


func run() -> void:
	var raid := Raid.new()
	add_child(raid)
	raid.set_process(false)
	raid.fx = Node3D.new()
	raid.world = Node3D.new()
	raid.add_child(raid.fx)
	raid.add_child(raid.world)
	var enemy := Enemy.new()
	enemy.raid = raid
	raid.world.add_child(enemy)
	enemy.set_physics_process(false)
	for i in 20:
		enemy._dash_trail(Vector3(i, 0, 0), Vector3.FORWARD)
	await wait_real(1.5)
	log_line("dash particles after 1.5s=%d" % raid.fx.get_child_count())
	var trails_released := raid.fx.get_child_count() == 0
	var refs: Array[WeakRef] = []
	for i in 64:
		var corpse := Remains.new()
		raid.world.add_child(corpse)
		refs.append(weakref(corpse))
		raid._register_corpse(corpse)
	await frames(3)
	var survivors := 0
	for ref in refs:
		if ref.get_ref() != null: survivors += 1
	log_line("retained corpse nodes=%d, visible budget=%d" % [survivors, raid._corpses.size()])
	var bounded_corpses := survivors == raid._corpses.size()
	# 无炮管虫也必须在倒地动画后释放护盾并停用处理。
	var bug := Bug.new()
	bug.setup("ling", raid, null)
	raid.world.add_child(bug)
	bug.set_physics_process(false)
	if not check(bug.gun == null, "测试虫种应无炮管"): return
	var shield := Node3D.new()
	bug.add_child(shield)
	bug.set_meta("shield_fx", shield)
	var shield_ref: WeakRef = weakref(shield)
	bug._die()
	await wait_real(0.8)
	var finalized := shield_ref.get_ref() == null and not bug.is_processing()
	log_line("non-gun corpse finalized=%s" % finalized)
	raid.queue_free()
	await frames(3)
	if not check(trails_released, "冲刺烟迹超过寿命后仍保留持续发射节点"): return
	if not check(bounded_corpses, "隐藏的超额尸体仍占用节点与资源"): return
	if not check(finalized, "无炮管虫倒地后没有执行残骸收尾"): return
	log_line("short-lived dash and bounded corpse lifetime passed")
