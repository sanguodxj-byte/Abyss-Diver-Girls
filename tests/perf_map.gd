extends "res://tests/lib/test_base.gd"
## 整图性能基准：不清场，按战区的自然生成（虫群 + 流浪者 + 队友）出击，机甲先原地开火、再横穿地图，统计每帧耗时。
## godot --headless --path . -- --perf_map            默认灰港市；--perf_map --map=redlake 指定战区
## 有派系系统时默认带两名队友，并在机甲 50 米外放一支 3 台的流浪者小队横穿过来（最坏情况）；--fac=0 关掉
## 结果打印为 [perf_map] 行，并写入 review/perf_map_<战区>.json

const TIMEOUT := 300.0
const PHASES := [["idle", 240, Vector2.ZERO], ["walk_e", 300, Vector2(1, 0)], ["walk_n", 300, Vector2(0, -1)]]


func _arg(name: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.split("=", true, 1)[1]
	return def


func run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var mid := _arg("map", "greyport")
	GameData.map_id = mid
	var fac_on := _arg("fac", "1") == "1" and ResourceLoader.exists("res://scripts/factions/factions.gd")
	var F = load("res://scripts/factions/factions.gd") if fac_on else null
	if F:
		F.rovers_enabled = false
		F.test_ally_squad = [{"pilot": "rei", "tier": 2}, {"pilot": "kurumi", "tier": 2}] if _arg("allies", "1") == "1" else []
	await wait(0.3)
	var raid = await deploy({"core": "core_std", "legs": "legs_biped", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_missile", "gen": "gen_reactor"})
	if not check(raid != null, "出击失败"):
		return
	var m = raid.mech
	m.shield_time = 99999
	m.hp = 1e9
	m.max_hp = 1e9
	m.energy = 1e9
	m.max_energy = 1e9
	if F and raid.factions and _arg("rovers", "1") == "1":
		var p0: Vector3 = m.global_position
		raid.factions.spawn_squad(3, [p0 + Vector3(50, 0.3, -20), p0 + Vector3(-80, 0.3, -20)])
	if _arg("noai", "0") == "1":
		for b in get_tree().get_nodes_in_group("bugs"):
			b.set_physics_process(false)
	await frames(30)
	var report := {"map": mid, "factions": F != null}
	var all_ft: Array = []
	for ph: Array in PHASES:
		var mv: Vector2 = ph[2]
		if mv.x > 0: Input.action_press("move_right")
		if mv.y < 0: Input.action_press("move_up")
		raid.aim_override = m.global_position + Vector3(6, 1.8, -6)
		Input.action_press("fire_left")
		var r := await _sample(int(ph[1]), all_ft)
		Input.action_release("fire_left")
		Input.action_release("move_right")
		Input.action_release("move_up")
		r["bugs"] = get_tree().get_nodes_in_group("bugs").size()
		r["rovers"] = get_tree().get_nodes_in_group("rovers").size()
		r["allies"] = get_tree().get_nodes_in_group("allies").size()
		report[ph[0]] = r
		print("[perf_map] map=%s phase=%s bugs=%d rovers=%d frame_avg=%.2fms p50=%.2fms p95=%.2fms process=%.2fms physics=%.2fms nodes=%d" % [
			mid, ph[0], r.bugs, r.rovers, r.frame_avg, r.frame_p50, r.frame_p95, r.process_avg, r.physics_avg, r.nodes])
	all_ft.sort()
	var s := 0.0
	for v in all_ft:
		s += v
	report["total"] = {"frame_avg": s / all_ft.size(), "frame_p50": all_ft[all_ft.size() / 2], "frame_p95": all_ft[int(all_ft.size() * 0.95)]}
	print("[perf_map] map=%s TOTAL frame_avg=%.2fms p50=%.2fms p95=%.2fms" % [mid, report.total.frame_avg, report.total.frame_p50, report.total.frame_p95])
	if F:
		F.rovers_enabled = true
		F.test_ally_squad = null
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_DIR))
	var f := FileAccess.open(REVIEW_DIR.path_join("perf_map_%s%s.json" % [mid, "_headless" if headless() else ""]), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()


func _sample(n: int, all_ft: Array) -> Dictionary:
	var ft: Array = []
	var pr := 0.0
	var ph := 0.0
	var last := Time.get_ticks_usec()
	for i in n:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		ft.append((now - last) / 1000.0)
		if (now - last) > 45000:
			var r = main.raid
			var ch := 0
			for b in get_tree().get_nodes_in_group("bugs"):
				if b.state == "chase": ch += 1
			print("[perf_map] SPIKE %.0fms frame=%d chase=%d fx=%d world=%d dying=%d phys_ticks?" % [(now - last) / 1000.0, Engine.get_process_frames(), ch, r.fx.get_child_count(), r.world.get_child_count(), get_tree().get_node_count()])
		last = now
		pr += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		ph += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	all_ft.append_array(ft)
	ft.sort()
	var s := 0.0
	for v in ft:
		s += v
	return {
		"frame_avg": s / ft.size(), "frame_p50": ft[ft.size() / 2], "frame_p95": ft[int(ft.size() * 0.95)],
		"process_avg": pr / n, "physics_avg": ph / n,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	}
