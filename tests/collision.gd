extends "res://tests/lib/test_base.gd"
## 碰撞后处理（scripts/collision_opt.gd）与防卡死（scripts/collision_unstuck.gd）的 A/B 测试。
## 同一张地图上依次测三种状态：原始碰撞 → 后处理 → 后处理 + 防卡死，每种状态都：
##   - 统计静态碰撞体 / 形状数量、物理帧耗时（虫群活跃时）
##   - 窄缝驾驶：挑 N 处窄缝（< GAP_T）与小件，机甲从 8m 外朝缝里开 2.5s，再倒车 1.2s；
##     统计卡楔帧（同时顶着两个夹角 > 100° 的面）、停滞帧（0.5s 内位移 < 0.3m）、倒车也出不来的“困死”次数
##   - 嵌入测试：把机甲放进障碍物边缘（胶囊嵌入 0.5m）按住移动键，1.5s 内没离开原地记为卡死
##   - 搜刮箱可达：局部洪泛判定能走到的搜刮箱数量
## godot --headless --path . -- --collision            默认灰港市；--map=<id> 指定战区；--n=<窄缝数>
## 结果打印为 [collision] 行，并写入 review/collision_<战区>.json

const TIMEOUT := 900.0
const CO = preload("res://scripts/collision_opt.gd")
const UnstuckScript = preload("res://scripts/collision_unstuck.gd")

var raid
var m
var U   ## 只用来做形状查询的防卡死实例（不进场景树）
var _frozen: Array = []
var _drop := Vector3.ZERO
var _probes: Array = []     ## [body, 圆心, 相位]


func _arg(name: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.split("=", true, 1)[1]
	return def


func run() -> void:
	var mid := _arg("map", "greyport")
	var n_sites := int(_arg("n", "30"))
	GameData.map_id = mid
	var F = load("res://scripts/factions/factions.gd") if ResourceLoader.exists("res://scripts/factions/factions.gd") else null
	if F:
		F.rovers_enabled = false
		F.test_ally_squad = []
	CO.enabled = false
	CO.unstuck_enabled = false
	await wait(0.3)
	raid = await deploy({"core": "core_std", "legs": "legs_biped", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_missile", "gen": "gen_reactor"})
	CO.enabled = true
	CO.unstuck_enabled = true
	if F:
		F.rovers_enabled = true
		F.test_ally_squad = null
	if not check(raid != null, "出击失败"):
		return
	m = raid.mech
	m.shield_time = 99999
	m.hp = 1e9
	m.max_hp = 1e9
	m.energy = 1e9
	m.max_energy = 1e9
	U = UnstuckScript.new()
	U._ready()
	_drop = m.global_position
	Engine.max_physics_steps_per_frame = 16
	var report := {"map": mid}

	# ---------- 选测试点（按原始碰撞） ----------
	var sites := _pick_sites(n_sites)
	var embeds := _pick_embeds(12)
	_make_probes(sites)
	log_line("sites=%d embeds=%d probes=%d" % [sites.size(), embeds.size(), _probes.size()])
	if not check(sites.size() >= 5, "地图上找不到足够的窄缝测试点"):
		return

	# ---------- A：原始 ----------
	report["base"] = await _measure_state("base", sites, embeds)
	# ---------- B：后处理（不挂防卡死） ----------
	CO.unstuck_enabled = false
	var st: Dictionary = CO.optimize(raid)
	CO.unstuck_enabled = true
	report["opt_stats"] = st
	report["opt"] = await _measure_state("opt", sites, embeds)
	# ---------- C：后处理 + 防卡死 ----------
	var u = UnstuckScript.new()
	u.name = "CollisionUnstuck"
	u.raid = raid
	raid.add_child(u)
	report["opt_unstuck"] = await _measure_state("opt_unstuck", sites, embeds)
	report["opt_unstuck"]["nudges"] = u.nudges
	Engine.time_scale = 1.0

	for k in ["base", "opt", "opt_unstuck"]:
		var r: Dictionary = report[k]
		log_line("%-11s bodies=%d shapes=%d physics=%.3fms probe=%.3fms probe_physics=%.3fms wedge_frames=%d stall_frames=%d trapped=%d/%d passed=%d embed_stuck=%d/%d deep_stuck=%d/%d pocket_stuck=%d loot_reach=%d/%d" % [
			k, r.bodies, r.shapes, r.physics_ms, r.probe_ms, r.probe_physics_ms, r.wedge_frames, r.stall_frames, r.trapped, r.trials, r.passed, r.embed_stuck, r.embeds, r.deep_stuck, r.embeds, r.pocket_stuck, r.loot_reach, r.loot_total])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_DIR))
	var f := FileAccess.open(REVIEW_DIR.path_join("collision_%s.json" % mid), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	var b: Dictionary = report.base
	var o: Dictionary = report.opt_unstuck
	check(report.opt.bodies < b.bodies, "后处理没有减少静态碰撞体")
	check(o.trapped <= b.trapped, "后处理 + 防卡死后困死次数反而增加：%d → %d" % [b.trapped, o.trapped])
	check(o.wedge_frames <= b.wedge_frames, "后处理后卡楔帧反而增加：%d → %d" % [b.wedge_frames, o.wedge_frames])
	check(o.embed_stuck == 0, "防卡死没有把嵌进障碍物的机甲挪出来：%d/%d" % [o.embed_stuck, o.embeds])
	check(o.deep_stuck == 0, "防卡死没有把深嵌进障碍物的机甲挪出来：%d/%d" % [o.deep_stuck, o.embeds])
	check(o.pocket_stuck == 0, "防卡死没有把困在窄坑里的机甲挪出来")
	check(report.opt.loot_reach >= b.loot_reach, "后处理封死了原本走得到的搜刮箱：%d → %d" % [b.loot_reach, report.opt.loot_reach])


# ================================================================ 一种状态的全部测量
func _measure_state(tag: String, sites: Array, embeds: Array) -> Dictionary:
	var r := {}
	var c: Dictionary = CO.count_static(raid.world)
	r["bodies"] = c.bodies_before
	r["shapes"] = c.shapes_before
	# 物理耗时 1：虫群照常活动，机甲放回空投点（虫群状态有随机性，只作参考）
	_place(_drop)
	_thaw()
	Engine.time_scale = 1.0
	await frames(10)
	var phs: Array = []
	for i in 240:
		await get_tree().physics_frame
		phs.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	r["physics_ms"] = _median(phs)
	_freeze()
	# 物理耗时 2：虫群移出地图，80 个探针胶囊在障碍物密集处绕圈 move_and_slide（三种状态完全相同的负载）
	var pr := await _run_probes(240)
	r["probe_ms"] = pr.x
	r["probe_physics_ms"] = pr.y
	Engine.time_scale = 4.0
	# 窄缝驾驶
	var wedge := 0
	var stall := 0
	var trapped := 0
	var passed := 0
	for s: Dictionary in sites:
		var t: Dictionary = await _drive(s.start, s.target)
		wedge += t.wedge
		stall += t.stall
		if t.passed:
			passed += 1
		var back: Vector3 = m.global_position
		await _steer(s.start, 1.2)
		if Vector2(m.global_position.x - back.x, m.global_position.z - back.z).length() < 1.0 and back.distance_to(s.start) > 1.5:
			trapped += 1
	r["wedge_frames"] = wedge
	r["stall_frames"] = stall
	r["trapped"] = trapped
	r["passed"] = passed
	r["trials"] = sites.size()
	# 嵌入
	var es := 0
	for e: Dictionary in embeds:
		_place(e.pos)
		await get_tree().physics_frame
		var p0: Vector3 = m.global_position
		await _steer(e.pos + e.dir * 6.0, 1.5)
		if Vector2(m.global_position.x - p0.x, m.global_position.z - p0.z).length() < 0.6:
			es += 1
	r["embed_stuck"] = es
	r["embeds"] = embeds.size()
	# 深嵌：机甲中心压进障碍物边缘 0.3m
	var ds := 0
	for e: Dictionary in embeds:
		_place(e.pos - e.dir * 0.8)
		await get_tree().physics_frame
		var p0: Vector3 = m.global_position
		await _steer(e.pos + e.dir * 6.0, 1.5)
		if Vector2(m.global_position.x - p0.x, m.global_position.z - p0.z).length() < 0.6:
			ds += 1
			if _arg("debug", "0") == "1":
				log_line("deep stuck at %s (start %s) y=%.2f floor=%s cls=%s free=%s" % [m.global_position, p0, m.global_position.y, m.is_on_floor(),
					U.classify(m, Vector2(e.dir.x, e.dir.z)), U._free(m, m.global_position, U._cap_small)])
				_press_toward(e.pos + e.dir * 6.0)
				await get_tree().physics_frame
				await get_tree().physics_frame
				for k in m.get_slide_collision_count():
					var sc: KinematicCollision3D = m.get_slide_collision(k)
					log_line("   slide: %s n=%s depth=%.3f pos=%s" % [sc.get_collider(), sc.get_normal(), sc.get_depth(), sc.get_position()])
				var q := PhysicsShapeQueryParameters3D.new()
				var cap := CapsuleShape3D.new()
				cap.radius = 1.0
				cap.height = 2.8
				q.shape = cap
				q.transform = Transform3D(Basis.IDENTITY, m.global_position + Vector3(0, 1.4, 0))
				q.collision_mask = 0xFFFF
				q.exclude = [m.get_rid()]
				for h in m.get_world_3d().direct_space_state.intersect_shape(q, 8):
					log_line("   overlap: %s layer=%d" % [h.collider, h.collider.collision_layer if "collision_layer" in h.collider else -1])
				log_line("   vel=%s dir=%s" % [m.velocity, e.dir])
				_release()
	r["deep_stuck"] = ds
	# 窄坑：地图外临时搭一个内宽 2.3m 的四面围墙小坑，机甲在坑里按住右
	r["pocket_stuck"] = await _pocket_test()
	Engine.time_scale = 1.0
	_release()
	# 搜刮箱可达
	var lr := _loot_reach()
	r["loot_reach"] = lr.x
	r["loot_total"] = lr.y
	log_line("%s done %s" % [tag, str(r)])
	return r


func _pocket_test() -> int:
	var P := Vector3(650, 0, 650)
	var parts: Array = []
	parts.append(raid._static_box(Vector3(30, 1, 30), P - Vector3(0, 0.5, 0), Color(0.5, 0.5, 0.5)))
	var w := 2.3
	var t := 0.6
	for sd in [-1.0, 1.0]:
		parts.append(raid._static_box(Vector3(w + t * 2, 3.0, t), P + Vector3(0, 1.5, sd * (w + t) * 0.5), Color.WHITE))
		parts.append(raid._static_box(Vector3(t, 3.0, w + t * 2), P + Vector3(sd * (w + t) * 0.5, 1.5, 0), Color.WHITE))
	_place(P)
	await get_tree().physics_frame
	await _steer(P + Vector3(10, 0, 0), 2.0)
	var stuck := 1 if Vector2(m.global_position.x - P.x, m.global_position.z - P.z).length() < 1.5 else 0
	for b in parts:
		b.queue_free()
	await get_tree().physics_frame
	return stuck


## 朝 target 开 2.5s：统计卡楔帧 / 停滞帧，是否到达
func _drive(start: Vector3, target: Vector3) -> Dictionary:
	_place(start)
	await get_tree().physics_frame
	var hist: Array = []
	var wedge := 0
	var stall := 0
	var ticks := int(2.5 * Engine.physics_ticks_per_second)
	var passed := false
	for i in ticks:
		_press_toward(target)
		await get_tree().physics_frame
		var p: Vector3 = m.global_position
		hist.append(p)
		if hist.size() > 30:
			hist.pop_front()
			if Vector2(p.x - hist[0].x, p.z - hist[0].z).length() < 0.3:
				stall += 1
		var ns: Array = []
		for k in m.get_slide_collision_count():
			var nn: Vector3 = m.get_slide_collision(k).get_normal()
			nn.y = 0.0
			if nn.length() > 0.3:
				ns.append(nn.normalized())
		var wedged := false
		for a in ns.size():
			for b in range(a + 1, ns.size()):
				if ns[a].dot(ns[b]) < -0.17:
					wedged = true
		if wedged:
			wedge += 1
			if _arg("debug", "0") == "1" and wedge % 40 == 1:
				var info: Array = []
				for k in m.get_slide_collision_count():
					var sc: KinematicCollision3D = m.get_slide_collision(k)
					var col = sc.get_collider()
					info.append("%s L%d n=%s" % [col.name, col.collision_layer if "collision_layer" in col else -1, sc.get_normal().snapped(Vector3.ONE * 0.01)])
				log_line("wedge at %s : %s" % [m.global_position.snapped(Vector3.ONE * 0.1), ", ".join(info)])
		if Vector2(p.x - target.x, p.z - target.z).length() < 2.0:
			passed = true
			break
	_release()
	return {"wedge": wedge, "stall": stall, "passed": passed}


func _steer(target: Vector3, sec: float) -> void:
	var ticks := int(sec * Engine.physics_ticks_per_second)
	for i in ticks:
		_press_toward(target)
		await get_tree().physics_frame
	_release()


func _press_toward(target: Vector3) -> void:
	var d := Vector2(target.x - m.global_position.x, target.z - m.global_position.z)
	if d.length() < 0.2:
		_release()
		return
	d = d.normalized()
	_set_axis("move_right", "move_left", d.x)
	_set_axis("move_down", "move_up", d.y)


func _set_axis(pos: String, neg: String, v: float) -> void:
	if v > 0.01:
		Input.action_press(pos, v)
	else:
		Input.action_release(pos)
	if v < -0.01:
		Input.action_press(neg, -v)
	else:
		Input.action_release(neg)


func _release() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


func _place(p: Vector3) -> void:
	m.global_position = Vector3(p.x, 0.05, p.z)
	m.velocity = Vector3.ZERO


# ================================================================ 测试点
## 窄缝：原始碰撞里缝宽在 (0.3, GAP_T) 的障碍物对，以及小件（会被去碰撞的形状）。
## 起点在缝中点沿“缝的走向”8m 外的空地，终点在另一侧 8m
func _pick_sites(n: int) -> Array:
	var obs: Array = CO.collect(raid.world)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261104
	var cands: Array = []
	var pairs: Array = CO._candidate_pairs(obs, CO.GAP_T)
	for pr: Vector2i in pairs:
		var A: Dictionary = obs[pr.x]
		var B: Dictionary = obs[pr.y]
		if A.ext < CO.SMALL_EXTENT or B.ext < CO.SMALL_EXTENT:
			continue
		var g: Array = CO.poly_gap(A.poly, B.poly)
		if g[0] > 0.3 and g[0] < CO.GAP_T:
			var mid: Vector2 = (g[1] + g[2]) * 0.5
			var across: Vector2 = (g[2] - g[1]).normalized()
			cands.append([mid, Vector2(-across.y, across.x)])
	var small: Array = []
	for o: Dictionary in obs:
		if o.ext < CO.SMALL_EXTENT:
			small.append([CO._centroid(o.poly), Vector2.from_angle(rng.randf() * TAU)])
	_shuffle(cands, rng)
	_shuffle(small, rng)
	var picked: Array = []
	var chosen: Array = cands.slice(0, int(n * 0.75)) + small.slice(0, n - mini(cands.size(), int(n * 0.75)))
	for c: Array in chosen:
		var mid: Vector2 = c[0]
		var ax: Vector2 = c[1]
		for sgn in [1.0, -1.0]:
			var s := Vector3(mid.x - ax.x * 8.0 * sgn, 0, mid.y - ax.y * 8.0 * sgn)
			var t := Vector3(mid.x + ax.x * 8.0 * sgn, 0, mid.y + ax.y * 8.0 * sgn)
			if absf(s.x) > raid.HALF - 6 or absf(s.z) > raid.HALF - 6:
				continue
			if U._free(m, s, U._cap) and not raid.in_wet(Vector2(s.x, s.z), 1.5):
				picked.append({"start": s, "target": t})
				break
	return picked


## 嵌入：厚度 ≥ 3m 的大障碍物（会保留碰撞）边缘外 0.5m 处（胶囊嵌入 0.5m），按住朝外的方向；太薄的墙深嵌时会被推到墙另一侧，不适合做这个测试
func _pick_embeds(n: int) -> Array:
	var obs: Array = CO.collect(raid.world)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_shuffle(obs, rng)
	var out: Array = []
	for o: Dictionary in obs:
		if out.size() >= n:
			break
		if o.min_ext < 3.0 or o.y1 < 1.5:
			continue
		var poly: PackedVector2Array = o.poly
		var i := rng.randi() % poly.size()
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var mid := (a + b) * 0.5
		var c: Vector2 = CO._centroid(poly)
		var outd := (mid - c).normalized()
		var p := mid + outd * 0.5
		if absf(p.x) > raid.HALF - 8 or absf(p.y) > raid.HALF - 8 or raid.in_wet(p, 2.0):
			continue
		# 外面 3m 要是空地（否则本来就是夹缝，不算单纯嵌入）
		if not U._free(m, Vector3(p.x + outd.x * 2.5, 0, p.y + outd.y * 2.5), U._cap):
			continue
		out.append({"pos": Vector3(p.x, 0, p.y), "dir": Vector3(outd.x, 0, outd.y)})
	return out


func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


## 能走到的搜刮箱：局部 32m 窗口洪泛（与 collision_opt 的封死判定同一套栅格）
func _loot_reach() -> Vector2i:
	var obs: Array = CO.collect(raid.world)
	var ok := 0
	var tot := 0
	for lp: Vector2 in CO._loot_points(raid):
		tot += 1
		if CO.escapes(CO.raster_at(lp, obs), lp):
			ok += 1
	return Vector2i(ok, tot)


# ================================================================ 物理探针
func _make_probes(sites: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var centers: Array = []
	for s: Dictionary in sites:
		centers.append((s.start + s.target) * 0.5)
	var obs: Array = CO.collect(raid.world)
	_shuffle(obs, rng)
	for o: Dictionary in obs:
		if centers.size() >= 80:
			break
		var c: Vector2 = CO._centroid(o.poly)
		if absf(c.x) < raid.HALF - 10 and absf(c.y) < raid.HALF - 10:
			centers.append(Vector3(c.x, 0, c.y))
	for c: Vector3 in centers:
		var b := CharacterBody3D.new()
		b.collision_layer = 64
		b.collision_mask = 1 | 8
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.8
		cap.height = 2.0
		cs.shape = cap
		cs.position.y = 1.0
		b.add_child(cs)
		raid.add_child(b)
		_probes.append([b, c, rng.randf() * TAU])
		b.process_mode = Node.PROCESS_MODE_DISABLED


## 返回 (探针 move_and_slide 每物理帧耗时, 引擎物理帧耗时) 毫秒，取中位数
func _run_probes(ticks: int) -> Vector2:
	for p: Array in _probes:
		p[0].process_mode = Node.PROCESS_MODE_INHERIT
		p[0].global_position = p[1] + Vector3(4.0 * cos(p[2]), 0.05, 4.0 * sin(p[2]))
		p[0].velocity = Vector3.ZERO
	var us: Array = []
	var ph: Array = []
	for i in ticks:
		await get_tree().physics_frame
		var t0 := Time.get_ticks_usec()
		var tt := i / 60.0
		for p: Array in _probes:
			var b: CharacterBody3D = p[0]
			var a: float = p[2] + tt * 1.4
			var tgt: Vector3 = p[1] + Vector3(4.0 * cos(a), 0, 4.0 * sin(a))
			var v := tgt - b.global_position
			v.y = 0.0
			b.velocity = v.normalized() * 6.0 + Vector3(0, -1.0, 0)
			b.move_and_slide()
		us.append((Time.get_ticks_usec() - t0) / 1000.0)
		ph.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	for p: Array in _probes:
		p[0].process_mode = Node.PROCESS_MODE_DISABLED
		p[0].global_position = Vector3(0, -800, 0)
	return Vector2(_median(us), _median(ph))


## 中位数：机器上同时跑着别的进程时平均值会被个别长帧拉高
func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


# ================================================================ 虫群冻结（驾驶测试时不挡路）
func _freeze() -> void:
	_frozen.clear()
	for b in get_tree().get_nodes_in_group("bugs") + get_tree().get_nodes_in_group("npc_mechs"):
		if not is_instance_valid(b) or b == m:
			continue
		_frozen.append([b, b.global_position])
		b.process_mode = Node.PROCESS_MODE_DISABLED
		b.global_position = b.global_position + Vector3(0, -500, 0)


func _thaw() -> void:
	for e: Array in _frozen:
		if is_instance_valid(e[0]):
			e[0].global_position = e[1]
			e[0].process_mode = Node.PROCESS_MODE_INHERIT
	_frozen.clear()
