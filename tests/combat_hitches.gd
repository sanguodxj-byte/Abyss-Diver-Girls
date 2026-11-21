extends "res://tests/lib/test_base.gd"
const START := "none"
const Raid = preload("res://scripts/raid.gd")
const Bug = preload("res://scripts/bug.gd")
const Prof = preload("res://scripts/prof.gd")
const Art = preload("res://scripts/art.gd")


func run() -> void:
	var dot := Art.soft_dot()
	var texture_count := Art._tex_cache.size()
	if not check(not Art._is_cloud_tex(dot) and texture_count == Art._tex_cache.size(), "普通粒子分类触发额外贴图生成"): return
	for texture in [Art.smoke_tex(), Art.dust_tex(), Art.cloud_tex()]:
		if not check(Art._is_cloud_tex(texture), "云雾粒子分类错误"): return
	var raid := Raid.new()
	add_child(raid)
	raid.set_process(false)
	raid.world = Node3D.new()
	raid.fx = Node3D.new()
	raid.add_child(raid.world)
	raid.add_child(raid.fx)
	raid.rng.seed = 20261120
	raid.layout = preload("res://scripts/world_city.gd").zone_layout("greyport")
	raid._warm_combat_fx()
	for pool: Array in raid._tracer_pool.values():
		var unique := {}
		for p in pool:
			if not check(not p.visible and not p.is_physics_processing() and not unique.has(p.get_instance_id()), "预热弹体活动或重复入池"): return
			unique[p.get_instance_id()] = true
	for kind in ["ling", "spitter", "beetle"]:
		for repeat_i in 2:
			var bug := Bug.new()
			raid.world.add_child(bug)
			bug.setup(kind, raid, null)
			bug.set_physics_process(false)
			Prof.on = true
			var start := Time.get_ticks_usec()
			bug.take_damage(100000)
			log_line("%s %d death=%.2f ms %s" % [kind, repeat_i, (Time.get_ticks_usec() - start) / 1000.0, Prof.take()[0]])
			Prof.on = false
			if not check(bug.dying and not bug.is_in_group("bugs") and bug.collision_layer == 0, "击杀未即时移出战斗"): return
	raid.queue_free()
	await frames(2)
