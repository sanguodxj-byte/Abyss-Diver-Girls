extends "res://tests/lib/test_base.gd"
const START := "none"
const Raid = preload("res://scripts/raid.gd")
const MapEvents = preload("res://scripts/map_ext/events.gd")


func run() -> void:
	var raid := Raid.new()
	add_child(raid)
	raid.set_process(false)
	raid.map_id = "greyport"
	raid.layout = preload("res://scripts/world_city.gd").zone_layout("greyport")
	raid.world = Node3D.new()
	raid.fx = Node3D.new()
	raid.add_child(raid.world)
	raid.add_child(raid.fx)
	raid._warm_combat_fx()
	Audio.warm_combat_sfx()
	var events := MapEvents.new()
	raid.add_child(events)
	events.setup(raid)
	events.set_process(false)
	raid.dropping = false
	for kind in 3:
		var at := Vector3(kind * 12, 0, 0)
		var before := get_tree().get_nodes_in_group("lootboxes").size()
		var start := Time.get_ticks_usec()
		match kind:
			0: events._supply_drop(at)
			1: events._distress(at)
			2: events._cargo_crash(at)
		log_line("event %d launch %.2f ms" % [kind, (Time.get_ticks_usec() - start) / 1000.0])
		if kind != 1:
			if not check(events._falling.size() == 1, "空投/货柜未开始下落"): return
			events._tick(9.0)
			if not check(events._falling.is_empty(), "落地后未清理下落状态"): return
		var boxes := get_tree().get_nodes_in_group("lootboxes")
		if not check(boxes.size() - before == (2 if kind == 2 else 1), "事件奖励箱数量错误"): return
		for box in boxes:
			if not check(not box.items.is_empty(), "奖励箱没有内容"): return
		await frames(2)
	if not check(not raid.flicker_lights.is_empty(), "求救信标灯未接入"): return
	var wreck_collision := false
	for shape: CollisionShape3D in raid.world.find_children("*", "CollisionShape3D", true, false):
		if shape.shape is BoxShape3D and shape.shape.size.is_equal_approx(Vector3(2.5, 2.2, 5.6)):
			wreck_collision = shape.get_parent().collision_layer == 1
	if not check(wreck_collision, "货柜残骸缺少碰撞体"): return
	raid.queue_free()
	await frames(2)
	log_line("supply landing, distress beacon, cargo wreck, collision and reward crates passed")
