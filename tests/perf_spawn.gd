extends "res://tests/lib/test_base.gd"
## 队友模块建模 / 合批微基准；每个配置三轮，区分首次与缓存命中。
const START := "none"
const TIMEOUT := 180.0
const MV = preload("res://scripts/mech_visual.gd")
const Mech = preload("res://scripts/mech.gd")
const Factions = preload("res://scripts/factions/factions.gd")
const Prof = preload("res://scripts/prof.gd")


func run() -> void:
	Prof.on = true
	var ring_t := Time.get_ticks_usec()
	MV.A.ring_tex()
	log_line("npc_ring_cold_ms=%.3f" % ((Time.get_ticks_usec() - ring_t) / 1000.0))
	var rows: Array = []
	for round_i in 3:
		for pilot in ["rei", "kurumi"]:
			var lo: Dictionary = Factions.pilot_loadout(pilot)
			var prebuilt := {}
			for slot in MV.SLOTS:
				var t := Time.get_ticks_usec()
				var mod := MV.build_module(slot, lo[slot], true, "42")
				var build_ms := (Time.get_ticks_usec() - t) / 1000.0
				var parts: Array = Prof.take()
				t = Time.get_ticks_usec()
				Mech._batch_visual(mod)
				var batch_ms := (Time.get_ticks_usec() - t) / 1000.0
				rows.append({"round": round_i, "pilot": pilot, "slot": slot, "build_ms": build_ms, "batch_ms": batch_ms})
				log_line("round=%d %s %s build=%.3fms batch=%.3fms nodes=%d" % [round_i, pilot, slot, build_ms, batch_ms, mod.find_children("*", "", true, false).size()])
				log_line("  %s" % str(parts[0]))
				prebuilt[slot] = mod
				await frames(1)
			var visual := MV.assemble_prebuilt(lo, prebuilt)
			if not check(visual.get_meta("modules").size() == MV.SLOTS.size(), "模块装配丢失"):
				visual.free()
				return
			visual.free()
	Prof.on = false
	var tag := "latest"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			tag = arg.substr(6).validate_filename()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_DIR))
	var file := FileAccess.open(REVIEW_DIR.path_join("perf_spawn_%s.json" % tag), FileAccess.WRITE)
	if not check(file != null, "无法保存性能采样"):
		return
	file.store_string(JSON.stringify(rows, "  "))
