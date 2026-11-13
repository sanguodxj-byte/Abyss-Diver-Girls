extends "res://tests/lib/test_base.gd"
## 水面不可通行 / 不可生成：godot --headless --path . -- --water   （MAPS_ONLY=战区 id）
## 每个有水的地表战区真实跑一遍 raid.start()，检查：
##   1. 虫子、NPC 机甲、搜刮箱、虫巢、撤离点、建筑 / 树等静态障碍没有落在有水的河湖里（桥面、"water": true 的地标除外）；
##   2. 导航网格：水面格子对虫子和机甲都不可走（桥面可走）；
##   3. 物理：沿河岸 / 湖岸每隔 1.5 米从岸上把机甲胶囊朝水里推 7 米，都会被护堤挡住，进不了水（重点是桥头护栏与护堤的衔接）。

const START := "none"
const TIMEOUT := 600.0
const RaidScript = preload("res://scripts/raid.gd")
const WC = preload("res://scripts/world_city.gd")

var problems: Array = []


func p(msg: String) -> void:
	problems.append(msg)


func run() -> void:
	await frames(2)
	var only := OS.get_environment("MAPS_ONLY")
	var n := 0
	for mid: String in GameData.map_ids():
		if (only == "" and WC.is_surface(mid)) or mid == only:
			n += await _check_map(mid)
	log_line("检查了 %d 个有水的战区" % n)
	for x in problems.slice(0, 40):
		log_line("  " + str(x))
	check(problems.is_empty(), "%d 处问题，首条：%s" % [problems.size(), problems[0] if not problems.is_empty() else ""])


func _water_lm(raid, q: Vector2) -> bool:
	for e in raid.MAP.get("landmarks", []):
		if bool(e.get("water", false)) and q.distance_to(Vector2(float(e.x), float(e.z))) < float(e.get("clear", 7.0)) + 18.0:
			return true
	return false


func _check_map(mid: String) -> int:
	GameData.map_id = mid
	var raid = RaidScript.new()
	add_child(raid)
	raid.start(GameData.STARTER.duplicate(), [])
	await frames(3)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var tag := "[%s]" % mid
	var inside := func(q: Vector2) -> bool: return raid.in_bounds_xz(q, 4.0)
	var wet_any := false
	for l: Vector3 in raid.lakes:
		if inside.call(Vector2(l.x, l.y)):
			wet_any = true
			break
	if not wet_any:
		for r: Dictionary in raid.rivers:
			if r.dry:
				continue
			for pt: Vector2 in raid._dense(r.pts, 4.0):
				if inside.call(pt):
					wet_any = true
					break
			if wet_any:
				break
	if not wet_any:
		raid.ended = true
		raid.queue_free()
		await frames(2)
		return 0
	# 1. 生成物
	var cnt := {}
	for grp in ["bugs", "npc_mechs", "lootboxes", "nests"]:
		for nd in get_tree().get_nodes_in_group(grp):
			if not (nd is Node3D) or not is_instance_valid(nd):
				continue
			var q := Vector2(nd.global_position.x, nd.global_position.z)
			if inside.call(q) and raid.in_wet(q, 0.0) and not raid._on_bridge(q, 0.0) and not _water_lm(raid, q):
				p("%s %s 落在水里：%s" % [tag, grp, q])
			cnt[grp] = int(cnt.get(grp, 0)) + 1
	for z in raid.extracts:
		var q := Vector2(z.global_position.x, z.global_position.z)
		if raid.in_wet(q, 1.0):
			p("%s 撤离点落在水里：%s" % [tag, q])
	var statics := 0
	for sb in raid.world.find_children("*", "StaticBody3D", true, false):
		if (sb.collision_layer & 1) == 0:
			continue
		for cs in sb.get_children():
			if not (cs is CollisionShape3D) or cs.disabled:
				continue
			var gp: Vector3 = cs.global_position
			var q := Vector2(gp.x, gp.z)
			if inside.call(q) and raid.in_wet(q, -0.5) and not raid._on_bridge(q, 1.5) and not _water_lm(raid, q):
				statics += 1
				if statics <= 6:
					p("%s 静态障碍落在水里：%s（%s）" % [tag, q, sb.name])
	# 2. 导航
	var nav = raid.nav
	var bad_nav := 0
	var wet_cells := 0
	for j in range(0, nav.n, 2):
		for i in range(0, nav.n, 2):
			var c: Vector3 = nav.cell_center(Vector2i(i, j))
			var q := Vector2(c.x, c.z)
			if inside.call(q) and raid.in_wet(q, -0.2) and not raid._on_bridge(q, 0.5):
				wet_cells += 1
				if nav.is_free(c, false) or nav.is_free(c, true):
					bad_nav += 1
	if bad_nav > 0:
		p("%s 导航网格上有 %d 个水面格子可走" % [tag, bad_nav])
	# 3. 物理：从岸上往水里推
	var space: PhysicsDirectSpaceState3D = raid.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 1.0
	cap.height = 2.5
	var tries := 0
	var leaks := 0
	var probes: Array = []    ## [岸上起点, 朝水的方向]
	for r: Dictionary in raid.rivers:
		if r.dry:
			continue
		var pts: PackedVector2Array = raid._dense(r.pts, 1.5)
		var hw: float = float(r.w) * 0.5
		for k in range(1, pts.size() - 1):
			var t: Vector2 = (pts[k + 1] - pts[k - 1]).normalized()
			var nn := Vector2(-t.y, t.x)
			for sd in [-1.0, 1.0]:
				probes.append([pts[k] + nn * sd * (hw + 2.4), -nn * sd])
	for l: Vector3 in raid.lakes:
		var m := maxi(24, int(TAU * l.z / 1.5))
		for k in m:
			var ang := TAU * k / m
			var d := Vector2(cos(ang), sin(ang))
			var lr := WC.lake_radius(l, ang)
			probes.append([Vector2(l.x, l.y) + d * (lr + 2.4), -d])
	# 桥头：贴着护栏外侧顺着桥往河心走（护堤和护栏之间有缝就会漏）
	var bprobes: Array = []
	for br: Array in raid.bridges:
		var b0: Vector2 = br[0]
		var b1: Vector2 = br[1]
		var u := (b1 - b0).normalized()
		var v := Vector2(-u.y, u.x)
		var bmid := (b0 + b1) * 0.5
		var ln := b0.distance_to(b1)
		for sd in [-1.0, 1.0]:
			for off in [1.15, 1.6, 2.4]:
				var k := 0.0
				while k < ln * 0.5:
					for e in [b0 + u * k, b1 - u * k]:
						var s: Vector2 = e + v * sd * (float(br[2]) * 0.5 + 0.35 + float(off))
						bprobes.append([s, (bmid - e).normalized(), true])
					k += 1.0
	for pr: Array in bprobes:
		var s: Vector2 = pr[0]
		if not inside.call(s) or raid.in_wet(s, 1.0):
			continue
		probes.append(pr)
	for pr: Array in probes:
		var s: Vector2 = pr[0]
		var dir: Vector2 = pr[1]
		if not inside.call(s) or raid.in_wet(s, 1.0) or (raid._on_bridge(s, 2.0) and pr.size() < 3) or _water_lm(raid, s):
			continue
		var qp := PhysicsShapeQueryParameters3D.new()
		qp.shape = cap
		qp.collision_mask = 1 | 8
		qp.transform = Transform3D(Basis.IDENTITY, Vector3(s.x, 1.6, s.y))
		if not space.intersect_shape(qp, 1).is_empty():
			continue    # 起点本身被别的东西占着
		qp.motion = Vector3(dir.x, 0, dir.y) * 7.0
		var res: PackedFloat32Array = space.cast_motion(qp)
		tries += 1
		var end := s + dir * 7.0 * res[0]
		if raid.in_wet(end, 0.0) and not raid._on_bridge(end, 0.0):
			leaks += 1
			if leaks <= 6:
				p("%s 机甲能从 %s 走进水里（到 %s）" % [tag, s, end])
	log_line("%s 生成物 %s，水面格子 %d，岸边推入测试 %d 次，漏 %d 次，桥 %d 座" % [tag, cnt, wet_cells, tries, leaks, raid.bridges.size()])
	if tries < 20:
		p("%s 岸边推入测试样本太少（%d）" % [tag, tries])
	raid.ended = true
	raid.queue_free()
	await frames(2)
	return 1
