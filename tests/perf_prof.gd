extends "res://tests/lib/test_base.gd"
## 分项性能剖析：与 perf_map 同样的出击与三个阶段，额外插入探针节点，把每帧拆成
##   物理脚本（所有 _physics_process）/ 物理引擎步进（Jolt step + 同步 + 回调）/ 逻辑脚本（_process）/ 其他（渲染、消息队列、树刷新）
## 并统计每帧物理步数（帧慢 → 下一帧补跑多步，形成连串尖刺）。Prof 打开后汇总各系统分项（Prof.add 的键）。
## godot --headless --path . -- --perf_prof [--map=ironbelt]
const TIMEOUT := 400.0
const PHASES := [["idle", 240, Vector2.ZERO], ["walk_e", 300, Vector2(1, 0)], ["walk_n", 300, Vector2(0, -1)]]
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
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var mid := _arg("map", "greyport")
	GameData.map_id = mid
	var F = load("res://scripts/factions/factions.gd") if ResourceLoader.exists("res://scripts/factions/factions.gd") else null
	if F:
		F.rovers_enabled = false
		F.test_ally_squad = [{"pilot": "rei", "tier": 2}, {"pilot": "kurumi", "tier": 2}]
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
	if F and raid.factions:
		var p0: Vector3 = m.global_position
		raid.factions.spawn_squad(3, [p0 + Vector3(50, 0.3, -20), p0 + Vector3(-80, 0.3, -20)])
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
	await frames(30)
	Prof.on = true
	Prof.take()
	var rows: Array = []
	var keys_tot := {}
	var keys_cnt := {}
	var keys_max := {}
	for ph: Array in PHASES:
		var mv: Vector2 = ph[2]
		if mv.x > 0: Input.action_press("move_right")
		if mv.y < 0: Input.action_press("move_up")
		raid.aim_override = m.global_position + Vector3(6, 1.8, -6)
		Input.action_press("fire_left")
		var last := Time.get_ticks_usec()
		for i in int(ph[1]):
			_phys_script = 0; _phys_engine = 0; _ticks = 0; _proc_script = 0
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			_post_t = 0
			var ft := now - last
			last = now
			var pk: Array = Prof.take()
			var row := {"ph": ph[0], "ft": ft, "ticks": _ticks, "ps": _phys_script, "pe": _phys_engine, "pr": _proc_script, "keys": pk[0], "n": pk[1]}
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
		print("[perf_prof] phase %s end: tweens=%d fx_children=%d emitting_particles=%d nodes=%d" % [ph[0], get_tree().get_processed_tweens().size(), raid.fx.get_child_count(), parts, get_tree().get_node_count()])
		if _arg("mbench", "0") == "1":
			_mbench()
	Prof.on = false
	var n := rows.size()
	var fts: Array = rows.map(func(r): return r.ft)
	fts.sort()
	var sum := func(key: String, rs: Array) -> float:
		var s := 0.0
		for r in rs: s += r[key]
		return s / maxf(rs.size(), 1) / 1000.0
	print("[perf_prof] map=%s frames=%d frame_avg=%.2f p50=%.2f p95=%.2f" % [mid, n, sum.call("ft", rows), fts[n / 2] / 1000.0, fts[int(n * 0.95)] / 1000.0])
	print("[perf_prof] per-frame avg ms: phys_script=%.2f phys_engine=%.2f process_script=%.2f other=%.2f ticks/frame=%.2f" % [
		sum.call("ps", rows), sum.call("pe", rows), sum.call("pr", rows),
		sum.call("ft", rows) - sum.call("ps", rows) - sum.call("pe", rows) - sum.call("pr", rows), sum.call("ticks", rows) * 1000.0])
	var tick_tot := 0
	for r in rows: tick_tot += r.ticks
	var spikes: Array = rows.filter(func(r): return r.ft > 45000)
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
