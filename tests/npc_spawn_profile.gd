extends "res://tests/lib/test_base.gd"
const START := "none"
const Cache = preload("res://scripts/npc_visual_cache.gd")
const MV = preload("res://scripts/mech_visual.gd")
const Npc = preload("res://scripts/factions/npc_mech.gd")
const Factions = preload("res://scripts/factions/factions.gd")
const Prof = preload("res://scripts/prof.gd")


func run() -> void:
	Cache.prepare()
	Npc.warm_shared_visuals(Cache.materials(), Factions.rover_pools().core)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261120
	for i in 8:
		var lo := Factions.pilot_loadout("rei" if i == 0 else "kurumi") if i < 2 else Factions.rover_loadout(rng)
		var parts := {}
		for slot in MV.SLOTS:
			var id: String = lo[slot]
			if not id.is_empty(): parts[slot] = Cache.instantiate(slot, id, "42")
		var visual := MV.assemble_prebuilt(lo, parts)
		var npc := Npc.new()
		add_child(npc)
		npc.set_physics_process(false)
		Prof.on = true
		var start := Time.get_ticks_usec()
		npc.setup_npc(lo, "ally" if i < 2 else "rover", 1, visual)
		log_line("setup %d %.2f ms %s" % [i, (Time.get_ticks_usec() - start) / 1000.0, Prof.take()[0]])
		Prof.on = false
		npc.free()
		await frames(1)
