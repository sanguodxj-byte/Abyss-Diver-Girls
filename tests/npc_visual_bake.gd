extends "res://tests/lib/test_base.gd"
const START := "none"
const TIMEOUT := 300.0
const Cache = preload("res://scripts/npc_visual_cache.gd")
const Factions = preload("res://scripts/factions/factions.gd")
const MV = preload("res://scripts/mech_visual.gd")
const Mech = preload("res://scripts/mech.gd")


func run() -> void:
	var choices := {}
	for slot in MV.SLOTS:
		choices[slot] = Factions.rover_pools()["arm" if slot.begins_with("arm_") else slot].duplicate()
	for pilot in Factions.PILOT_LOADOUT:
		for slot in MV.SLOTS:
			var id: String = Factions.pilot_loadout(pilot)[slot]
			if not id.is_empty() and not choices[slot].has(id): choices[slot].append(id)
	var modules := {}
	for slot in MV.SLOTS:
		for id: String in choices[slot]:
			var root := MV.build_module(slot, id, true, Cache.SERIAL)
			if not check(root != null, "模块无法构建：" + id): return
			Mech._batch_visual(root)
			modules[slot + ":" + id] = Cache.pack(root)
			root.free()
			await frames(1)
		log_line("baked %s (%d total)" % [slot, modules.size()])
	var library := Resource.new()
	library.set_meta("modules", modules)
	library.set_meta("sources", Cache.signature())
	if not check(ResourceSaver.save(library, Cache.PATH, ResourceSaver.FLAG_COMPRESS) == OK, "无法保存 NPC 模块"): return
	log_line("baked %d modules" % modules.size())
