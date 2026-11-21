extends "res://tests/lib/test_base.gd"
## 分项性能剖析：与 perf_map 同样的出击与三个阶段，额外插入探针节点，把每帧拆成
##   物理脚本（所有 _physics_process）/ 物理引擎步进（Jolt step + 同步 + 回调）/ 逻辑脚本（_process）/ 其他（渲染、消息队列、树刷新）
## 并统计每帧物理步数（帧慢 → 下一帧补跑多步，形成连串尖刺）。Prof 打开后汇总各系统分项（Prof.add 的键）。
## godot --headless --path . -- --perf_prof [--map=ironbelt]
## --seconds=3 固定各阶段模拟时长（默认仍按帧数）；--seed=20261120 固定随机种子。
## --tag=before 保存 review/perf_prof_before.json（配置、分位数和逐帧数据）。
## --queued=1 通过正式分帧队列生成流浪者，用于长时进场尖刺检查。
const TIMEOUT := 400.0
const PHASES := [["post_drop", 90, Vector2.ZERO], ["idle", 180, Vector2.ZERO], ["walk_e", 300, Vector2(1, 0)], ["walk_n", 300, Vector2(0, -1)]]
const Prof = preload("res://scripts/prof.gd")

var _tick_start := 0   # 本物理步脚本开始
var _post_t := 0       # 上一步脚本结束
var _phys_script := 0
var _phys_engine := 0
var _ticks := 0
var _proc_start := 0
var _proc_script := 0


class Probe extends Node:
	var cb: Callable
	var phys := true
	func _physics_process(_d: float) -> void:
		if phys: cb.call()
	func _process(_d: float) -> void:
		if not phys: cb.call()


func _arg(name: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.split("=", true, 1)[1]
	return def


func _probe(prio: int, phys: bool, cb: Callable) -> void:
	var p := Probe.new()
	p.cb = cb
	p.phys = phys
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	if phys:
		p.process_physics_priority = prio
		p.set_process(false)
	else:
		p.process_priority = prio
		p.set_physics_process(false)
	get_tree().root.add_child(p)


func run() -> void:
	Engine.max_fps = 0
	var sample_seed := int(_arg("seed", "20261120"))
	seed(sample_seed)
	var phase_seconds := maxf(0.0, float(_arg("seconds", "0")))
	var vsync_on := _arg("vsync", "0") == "1"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_on else DisplayServer.VSYNC_DISABLED)
	if not headless() and _arg("win", "max") == "max":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	if not headless():
		var requested_size := DisplayServer.window_get_size()
		if _arg("win", "max") == "keep":
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_position(Vector2i(60, 60))
		get_window().unresizable = true
		# Windows 切换不可调整大小的边框可能改变客户区尺寸，恢复实际请求值。
		DisplayServer.window_set_size(requested_size)
		await frames(2)
	var q_arg := _arg("quality", "")
	if q_arg != "":
		GameData.quality = int(q_arg)
		GameData.apply_quality(get_viewport())
	var mid := _arg("map", "greyport")
	GameData.map_id = mid
	var vp_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	var F = load("res://scripts/factions/factions.gd") if ResourceLoader.exists("res://scripts/factions/factions.gd") else null
	if F:
		F.rovers_enabled = _arg("rovers", "1") == "1"
		F.test_ally_squad = [{"pilot": "rei", "tier": 2}, {"pilot": "kurumi", "tier": 2}]
	if _arg("async", "1") == "1" and not headless():
		main.RaidScript.force_async_load = true
	await wait(0.3)
	seed(sample_seed)
	var deploy_start := Time.get_ticks_usec()
	var raid = await deploy({"core": "core_std", "legs": "legs_biped", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_missile", "gen": "gen_reactor"})
	var deploy_ms := (Time.get_ticks_usec() - deploy_start) / 1000.0
	main.RaidScript.force_async_load = false
	if not check(raid != null, "出击失败"):
		return
	var m = raid.mech
	m.shield_time = 99999
	m.hp = 1e9
	m.max_hp = 1e9
	m.energy = 1e9
	m.max_energy = 1e9
	if F and raid.factions:
		var p0: Vector3 = m.global_position
		var route: Array = [p0 + Vector3(50, 0.3, -20), p0 + Vector3(-80, 0.3, -20)]
		if _arg("queued", "0") == "1":
			raid.factions._enqueue_squad(3, route)
		else:
			raid.factions.spawn_squad(3, route)
	_probe(-1000000, true, func():
		var now := Time.get_ticks_usec()
		if _post_t > 0: _phys_engine += now - _post_t
		_tick_start = now
		_ticks += 1)
	_probe(1000000, true, func():
		var now := Time.get_ticks_usec()
		_phys_script += now - _tick_start
		_post_t = now)
	_probe(-1000000, false, func(): _proc_start = Time.get_ticks_usec())
	_probe(1000000, false, func(): _proc_script += Time.get_ticks_usec() - _proc_start)
	if _arg("novis", "0") == "1":
		# 消融实验：把虫子的外观子树摘出场景树（不渲染、不传播变换），看物理脚本 / 引擎时间各降多少
		for b in get_tree().get_nodes_in_group("bugs"):
			if b.visual and b.visual.get_parent() == b:
				b.remove_child(b.visual)
	Prof.on = true
	Prof.take()
	var rows: Array = []
	var phase_states: Array = []
	var keys_tot := {}
	var keys_cnt := {}
	var keys_max := {}
	var sample_window := DisplayServer.window_get_size()
	var window_changed := false
	var vp_cur := get_viewport()
	var rt_px := Vector2i(int(round(vp_cur.size.x * vp_cur.scaling_3d_scale)), int(round(vp_cur.size.y * vp_cur.scaling_3d_scale)))
	print("[perf_prof] config: screen=%s win=%s rt_px=%s scale=%.2f msaa=%d ui_vp=%s quality=%d vsync=%d renderer=%s" % [
		str(DisplayServer.screen_get_size()), str(DisplayServer.window_get_size()), str(rt_px), vp_cur.scaling_3d_scale, int(vp_cur.msaa_3d),
		str(vp_cur.get_visible_rect().size), GameData.quality, int(DisplayServer.window_get_vsync_mode()), RenderingServer.get_current_rendering_method()])
	for ph: Array in PHASES:
		var mv: Vector2 = ph[2]
		if mv.x > 0: Input.action_press("move_right")
		if mv.y < 0: Input.action_press("move_up")
		raid.aim_override = m.global_position + Vector3(6, 1.8, -6)
		Input.action_press("fire_left")
		var last := Time.get_ticks_usec()
		var phase_tick := Engine.get_physics_frames()
		var target_ticks := maxi(1, roundi(phase_seconds * Engine.physics_ticks_per_second))
		var frame_i := 0
		while (Engine.get_physics_frames() - phase_tick < target_ticks) if phase_seconds > 0.0 else (frame_i < int(ph[1])):
			frame_i += 1
			_phys_script = 0; _phys_engine = 0; _ticks = 0; _proc_script = 0
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			if not window_changed and DisplayServer.window_get_size() != sample_window:
				print("[perf_prof] INVALID window changed %s -> %s" % [sample_window, DisplayServer.window_get_size()])
				window_changed = true
			_post_t = 0
			var ft := now - last
			last = now
			var gpu_us := int(RenderingServer.viewport_get_measured_render_time_gpu(vp_rid) * 1000.0)
			var rcpu_us := int((RenderingServer.viewport_get_measured_render_time_cpu(vp_rid) + RenderingServer.get_frame_setup_time_cpu()) * 1000.0)
			var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			var objs := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			var pk: Array = Prof.take()
			var row := {"ph": ph[0], "ft": ft, "ticks": _ticks, "ps": _phys_script, "pe": _phys_engine, "pr": _proc_script, "gpu": gpu_us, "rcpu": rcpu_us, "dc": dc, "objs": objs, "prims": prims, "keys": pk[0], "n": pk[1]}
			rows.append(row)
			for k in pk[0]:
				keys_tot[k] = keys_tot.get(k, 0) + pk[0][k]
				keys_cnt[k] = keys_cnt.get(k, 0) + pk[1][k]
				keys_max[k] = maxi(keys_max.get(k, 0), pk[0][k])
		Input.action_release("fire_left")
		Input.action_release("move_right")
		Input.action_release("move_up")
		var parts := 0
		for c in raid.fx.get_children():
			if c is CPUParticles3D and c.emitting: parts += 1
		var ph_rows: Array = rows.filter(func(r): return r.ph == ph[0])
		var ph_ft := 0.0
		var ph_gpu := 0.0
		var ph_rcpu := 0.0
		for r in ph_rows:
			ph_ft += r.ft
			ph_gpu += r.gpu
			ph_rcpu += r.rcpu
		var ph_n := maxf(ph_rows.size(), 1)
		print("[perf_prof] phase %s end: avg_ft=%.2fms (%.1f fps) gpu=%.2fms rcpu=%.2fms eng_fps=%d tweens=%d fx_children=%d emitting_particles=%d nodes=%d" % [
			ph[0], ph_ft / ph_n / 1000.0, 1000000.0 * ph_n / maxf(ph_ft, 1.0), ph_gpu / ph_n / 1000.0, ph_rcpu / ph_n / 1000.0,
			int(Engine.get_frames_per_second()), get_tree().get_processed_tweens().size(), raid.fx.get_child_count(), parts, get_tree().get_node_count()])
		if _arg("mbench", "0") == "1":
			_mbench()
		phase_states.append({"phase": ph[0], "bugs": get_tree().get_nodes_in_group("bugs").size(),
			"allies": get_tree().get_nodes_in_group("allies").size(), "rovers": get_tree().get_nodes_in_group("rovers").size(),
			"pending_spawns": raid.factions._spawn_jobs.size() if raid.factions else 0})
	Prof.on = false
	if not check(not window_changed, "采样期间窗口尺寸改变，本轮性能数据无效"):
		return
	var n := rows.size()
	var fts: Array = rows.map(func(r): return r.ft)
	fts.sort()
	var sum := func(key: String, rs: Array) -> float:
		var s := 0.0
		for r in rs: s += r[key]
		return s / maxf(rs.size(), 1) / 1000.0
	print("[perf_prof] map=%s frames=%d frame_avg=%.2f (%.1f fps) p50=%.2f p95=%.2f gpu_avg=%.2fms rcpu_avg=%.2fms draw_calls=%.0f objs=%.0f prims=%.0f" % [
		mid, n, sum.call("ft", rows), 1000.0 / maxf(sum.call("ft", rows), 0.01), fts[n / 2] / 1000.0, fts[int(n * 0.95)] / 1000.0,
		sum.call("gpu", rows), sum.call("rcpu", rows), sum.call("dc", rows) * 1000.0, sum.call("objs", rows) * 1000.0, sum.call("prims", rows) * 1000.0])
	print("[perf_prof] per-frame avg ms: phys_script=%.2f phys_engine=%.2f process_script=%.2f other=%.2f ticks/frame=%.2f" % [
		sum.call("ps", rows), sum.call("pe", rows), sum.call("pr", rows),
		sum.call("ft", rows) - sum.call("ps", rows) - sum.call("pe", rows) - sum.call("pr", rows), sum.call("ticks", rows) * 1000.0])
	var tick_tot := 0
	for r in rows: tick_tot += r.ticks
	var spikes: Array = rows.filter(func(r): return r.ft > 45000)
	# 在计时结束后回读一次实际图像，避免 ViewportTexture 的逻辑缩放尺寸混入 GPU 分辨率记录。
	var render_size := Vector2i.ZERO if headless() else get_viewport().get_texture().get_image().get_size()
	var report := {
		"map": mid, "seed": sample_seed, "phase_seconds": phase_seconds, "headless": headless(),
		"queued": _arg("queued", "0") == "1",
		"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"gpu": RenderingServer.get_video_adapter_name(), "quality": GameData.quality,
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"viewport": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"render_target": [render_size.x, render_size.y],
		"scale_3d": get_viewport().scaling_3d_scale,
		"deploy_ms": deploy_ms, "frames": n, "frame_avg_ms": sum.call("ft", rows),
		"p50_ms": fts[n / 2] / 1000.0, "p95_ms": fts[int(n * 0.95)] / 1000.0,
		"p99_ms": fts[int(n * 0.99)] / 1000.0, "max_ms": fts[-1] / 1000.0,
		"spikes_33ms": rows.filter(func(r): return r.ft > 33333).size(),
		"spikes_16ms": rows.filter(func(r): return r.ft > 16667).size(),
		"spikes_45ms": spikes.size(), "gpu_avg_ms": sum.call("gpu", rows),
		"keys_total_us": keys_tot, "keys_max_us": keys_max, "rows": rows,
		"phase_states": phase_states,
	}
	var out_path := REVIEW_DIR.path_join("perf_prof_%s.json" % _arg("tag", "latest").validate_filename())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_DIR))
	var out := FileAccess.open(out_path, FileAccess.WRITE)
	if not check(out != null, "无法保存性能采样：" + out_path):
		return
	out.store_string(JSON.stringify(report))
	out.close()
	print("[perf_prof] spikes>45ms=%d >100ms=%d  per-tick avg: phys_script=%.2fms phys_engine=%.2fms" % [spikes.size(), rows.filter(func(r): return r.ft > 100000).size(),
		sum.call("ps", rows) * n / maxf(tick_tot, 1), sum.call("pe", rows) * n / maxf(tick_tot, 1)])
	if not spikes.is_empty():
		print("[perf_prof] spike frames avg: ft=%.1f ticks=%.2f phys_script=%.1f phys_engine=%.1f process=%.1f" % [sum.call("ft", spikes), sum.call("ticks", spikes) * 1000.0, sum.call("ps", spikes), sum.call("pe", spikes), sum.call("pr", spikes)])
	var ks: Array = keys_tot.keys()
	ks.sort_custom(func(a, b): return keys_tot[a] > keys_tot[b])
	for k in ks:
		var sp_tot := 0
		for r in spikes: sp_tot += r.keys.get(k, 0)
		print("[perf_prof] key %-28s avg/frame=%.3fms calls/frame=%.1f max_frame=%.1fms spike_avg=%.2fms" % [k, keys_tot[k] / 1000.0 / n, float(keys_cnt[k]) / n, keys_max[k] / 1000.0, sp_tot / 1000.0 / maxf(spikes.size(), 1)])
	# 最慢 8 帧明细
	rows.sort_custom(func(a, b): return a.ft > b.ft)
	for r in rows.slice(0, 8):
		var top: Array = r.keys.keys()
		top.sort_custom(func(a, b): return r.keys[a] > r.keys[b])
		var s := ""
		for k in top.slice(0, 5): s += " %s=%.1f" % [k, r.keys[k] / 1000.0]
		print("[perf_prof] slow %s ft=%.1f ticks=%d ps=%.1f pe=%.1f pr=%.1f |%s" % [r.ph, r.ft / 1000.0, r.ticks, r.ps / 1000.0, r.pe / 1000.0, r.pr / 1000.0, s])
	if F:
		F.rovers_enabled = true
		F.test_ally_squad = null


## 剖析用：同一帧内对 NPC 连续调 move_and_slide，看单次真实耗时（排除“首次查询要刷新宽相”等一次性开销）
func _mbench() -> void:
	for n in get_tree().get_nodes_in_group("npc_mechs"):
		var ts: Array = []
		var p0: Vector3 = n.global_position
		var v0: Vector3 = n.velocity
		var tp := Time.get_ticks_usec()
		n.global_position = p0
		var tpd := Time.get_ticks_usec() - tp
		print("[perf_prof] mbench npc set_pos(dirty subtree)=%.3fms" % (tpd / 1000.0))
		for i in 30:
			n.velocity = Vector3(4, -1, 2)
			var t := Time.get_ticks_usec()
			n.move_and_slide()
			ts.append(Time.get_ticks_usec() - t)
			n.global_position = p0
		n.velocity = v0
		print("[perf_prof] mbench npc first=%.3f median=%.3f max=%.3f coll=%d" % [ts[0] / 1000.0, ts[15] / 1000.0, ts.max() / 1000.0, n.get_slide_collision_count()])
