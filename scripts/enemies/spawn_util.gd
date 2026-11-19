extends RefCounted
## 战区布置的公共步骤：先按 GameData.SPAWNS 里的密度与种类权重铺开常规虫群，再在指定区块里放下区域主/副 Boss。
## 环境规则：虫群是固定分布，不生成定时虫潮；Boss 只在地图上的菌毯/弹坑/工业要冲里伏着，等机甲靠近才苏醒。


## 铺常规虫群：分布表由 data\ext\enemies.gd 提供，这里只负责把它交给 raid 的按格生成流程
static func fill(raid, drop: Vector3) -> void:
	var sp: Dictionary = GameData.SPAWNS.get(str(raid.map_id), {})
	if sp.is_empty() or not sp.has("kinds"):
		raid.spawn_default_bugs(drop)
		return
	raid._spawn_table_bugs(drop, sp)


const A = preload("res://scripts/art.gd")


static func _far_from_list(p: Vector3, pts: Array, min_sep: float) -> bool:
	for q in pts:
		if q is Vector3 and Vector2(p.x - q.x, p.z - q.z).length() < min_sep:
			return false
	return true


## 在给定区块字符里找一个离空投点与已有 Boss 足够远、且没有被建筑占住的落点
static func spot_in_zone(raid, want: Array, min_dist: float, drop: Vector3, avoid: Array = []) -> Vector3:
	for target_z in want:
		var best := Vector3.INF
		var best_d := min_dist
		var fallback := Vector3.INF
		var fallback_d := 45.0
		for j in range(-1, 10):
			for i in range(-1, 10):
				var r: Rect2 = raid._cell_rect(i, j)
				var rc := r.get_center()
				if raid.has_method("border_dist") and raid.border_dist(rc) < -28.0:
					continue
				var t: String = str(raid.zones[j][i]) if (i >= 0 and i <= 8 and j >= 0 and j <= 8) else str(raid.zone_at(Vector3(rc.x, 0.0, rc.y)))
				if t != str(target_z):
					continue
				var p: Vector3 = raid._spot_in(r, 7.0)
				if p == Vector3.INF:
					p = raid._spot_in(r, 4.5)
				if p == Vector3.INF:
					p = raid._spot_in(r, 2.5)
				if p == Vector3.INF:
					continue
				if not _far_from_list(p, avoid, 80.0):
					continue
				var d: float = Vector2(p.x - drop.x, p.z - drop.z).length()
				if d > best_d:
					best_d = d
					best = p
				if d > fallback_d:
					fallback_d = d
					fallback = p
		if best != Vector3.INF:
			return best
		if fallback != Vector3.INF:
			return fallback
	return Vector3.INF


## 放 Boss：优先落在指定区块里，布置首领巢穴视觉地标、战利品箱与亲卫虫群
static func place_boss(raid, boss_id: String, zones: Array, min_dist: float, drop: Vector3, guards: Array = [], avoid: Array = []) -> Node:
	var p := spot_in_zone(raid, zones, min_dist, drop, avoid)
	if p == Vector3.INF:
		p = spot_in_zone(raid, ["S", "C", "I", "M", "W", "Y"], 65.0, drop, avoid)
	if p == Vector3.INF:
		p = raid._free_spot(9.0)
	if p == Vector3.INF or p == Vector3.ZERO:
		return null
	var cap: int = int(raid.MAX_BUGS) + 48
	var b = raid.spawn_bug(boss_id, Vector3(p.x, 0.5, p.z), cap)
	if b != null:
		var center := Vector3(b.position.x, 0.0, b.position.z)
		b.home = center
		b.rotation_degrees.y = rad_to_deg(atan2(drop.x - center.x, drop.z - center.z))
		if raid.mech != null:
			b.target = raid.mech
		_build_boss_lair(raid, center, boss_id)
		_spawn_guards(raid, center, guards)
	return b


## 在指定新地标建筑的前场/中庭竞技台布置专属驻守 Boss（找不到地标时自动退化到常规区块寻点）
static func place_boss_at_landmark(raid, boss_id: String, lm_type: String, fallback_zones: Array, drop: Vector3, guards: Array = [], avoid: Array = []) -> Node:
	var target_pos := Vector3.INF
	var made: Array = raid.get_meta("ext_landmarks", [])
	for m in made:
		if str(m.get("type", "")) == lm_type:
			var ax := float(m.get("arena_x", m.get("x", 0.0)))
			var az := float(m.get("arena_z", m.get("z", 0.0)))
			var base := Vector3(ax, 0.0, az)
			if not raid._blocked(base, 2.8, false) and Vector2(base.x - drop.x, base.z - drop.z).length() > 28.0:
				target_pos = base
			else:
				for r_try: float in [4.5, 8.5, 13.0, 18.0]:
					for k in 12:
						var ang := TAU * float(k) / 12.0
						var cand: Vector3 = raid.dry_spot(base + Vector3(cos(ang), 0.0, sin(ang)) * r_try, 2.8)
						if not raid._blocked(cand, 2.8, false) and raid.in_bounds_xz(Vector2(cand.x, cand.z), 6.0) and Vector2(cand.x - drop.x, cand.z - drop.z).length() > 28.0:
							target_pos = cand
							break
					if target_pos != Vector3.INF:
						break
			break
	if target_pos == Vector3.INF:
		return place_boss(raid, boss_id, fallback_zones, 75.0, drop, guards, avoid)
	var cap: int = int(raid.MAX_BUGS) + 48
	var b = raid.spawn_bug(boss_id, Vector3(target_pos.x, 0.5, target_pos.z), cap)
	if b != null:
		var center := Vector3(b.position.x, 0.0, b.position.z)
		b.home = center
		b.rotation_degrees.y = rad_to_deg(atan2(drop.x - center.x, drop.z - center.z))
		if raid.mech != null:
			b.target = raid.mech
		_build_boss_lair(raid, center, boss_id)
		_spawn_guards(raid, center, guards)
	return b


## 首领巢穴视觉标识与高价值战利品箱（纯视觉晶簇 + 贴花，不阻挡寻路与走位）
static func _build_boss_lair(raid, center: Vector3, boss_id: String) -> void:
	if raid.world == null:
		return
	var lair := Node3D.new()
	lair.name = "BossLair_" + boss_id
	lair.position = center
	raid.world.add_child(lair)
	var glow_c := Color(0.85, 0.25, 0.45)
	match boss_id:
		"king_beetle", "gorge_tyrant", "excavator_titan":
			glow_c = Color(1.0, 0.56, 0.16)
		"iron_warden", "terminus_warden":
			glow_c = Color(0.28, 0.82, 1.0)
		"slag_colossus", "foundry_dreadnought", "core_overlord":
			glow_c = Color(1.0, 0.44, 0.14)
		"abyss_queen", "abyss_harbinger":
			glow_c = Color(0.78, 0.28, 1.0)
		"grey_brood":
			glow_c = Color(0.45, 0.9, 0.35)
		"harbor_reaper", "spillway_leviathan", "drydock_behemoth", "sky_carrier":
			glow_c = Color(0.22, 0.92, 0.85)
		"dust_matriarch", "dune_devourer", "silo_warhead", "citadel_behemoth":
			glow_c = Color(0.95, 0.58, 0.18)
		"prism_archon":
			glow_c = Color(0.55, 0.82, 1.0)
	var is_lm_boss := boss_id in ["terminus_warden", "foundry_dreadnought", "silo_warhead", "spillway_leviathan", "excavator_titan", "core_overlord", "drydock_behemoth", "citadel_behemoth", "sky_carrier"]
	A.ground_vfx(lair, A.blob_tex(), Color(0.12, 0.12, 0.13, 0.76) if is_lm_boss else Color(0.16, 0.08, 0.18, 0.82), 16.0 if is_lm_boss else 18.0, Vector3(0, 0.092, 0), false, 0.44, false, 2)
	if is_lm_boss:
		A.add(lair, A.quad(14.0, 14.0), A.extract_pad_mat(Color(glow_c.r, glow_c.g, glow_c.b, 0.30), 0.44, 3), Vector3(0, 0.114, 0), Vector3.ZERO, Vector3.ONE, false)
		var mat_st: Material = A.paint(Color(0.24, 0.25, 0.27), 0.65, 0.50, {"rust": 0.68, "wear": 0.55})
		var mat_hz: Material = A.hazard()
		var mat_lamp: Material = A.emit(glow_c, 1.8)
		for k in 4:
			var ang_b: float = PI * 0.25 + TAU * float(k) / 4.0
			var sp_b := Vector3(cos(ang_b) * 8.6, 0.0, sin(ang_b) * 8.6)
			A.add(lair, A.bevel_box(Vector3(0.48, 1.45, 0.48), 0.04), mat_st, sp_b + Vector3(0, 0.72, 0), Vector3(0, -rad_to_deg(ang_b), 0), Vector3.ONE, false)
			A.add(lair, A.bevel_box(Vector3(0.52, 0.24, 0.52), 0.02), mat_hz, sp_b + Vector3(0, 1.15, 0), Vector3(0, -rad_to_deg(ang_b), 0), Vector3.ONE, false)
			A.add(lair, A.cyl(0.12, 0.18, 0.15, 10), mat_lamp, sp_b + Vector3(0, 1.52, 0), Vector3.ZERO, Vector3.ONE, false)
	else:
		var mat_chitin: Material = A.chitin(Color(0.2, 0.14, 0.18))
		var mat_glow: Material = A.emit(glow_c, 2.2)
		for k in 6:
			var ang: float = TAU * float(k) / 6.0 + raid.rng.randf_range(-0.18, 0.18)
			var dist: float = raid.rng.randf_range(8.5, 11.2)
			var sp := Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
			var h: float = raid.rng.randf_range(1.8, 3.1)
			var r: float = raid.rng.randf_range(0.32, 0.52)
			var tilt := Vector3(sin(ang) * 16.0, raid.rng.randf_range(0.0, 360.0), -cos(ang) * 16.0)
			A.add(lair, A.cyl(r * 0.18, h, r, 6), mat_chitin, sp + Vector3(0, h * 0.45, 0), tilt)
			A.add(lair, A.rock_mesh(0.28, 70 + k * 13), mat_glow, sp + Vector3(0, 0.36, 0), tilt * 0.5, Vector3(r * 1.4, r * 1.8, r * 1.4), false)
	var light := OmniLight3D.new()
	light.light_color = glow_c
	light.light_energy = 1.6
	light.omni_range = 16.0
	light.position = Vector3(0, 2.6, 0)
	lair.add_child(light)
	# 首领巢穴战利品箱：保险柜 + 军用箱（沿竞技台切向整齐摆放）
	var box_kinds := ["safe", "military"]
	for i in box_kinds.size():
		var ba: float = TAU * (0.35 + float(i) * 0.3)
		var raw_p := center + Vector3(cos(ba), 0.0, sin(ba)) * 5.8
		var bp: Vector3 = raid.dry_spot(raw_p, 2.2)
		if not raid._blocked(bp, 1.8, false):
			raid._place_box(box_kinds[i], Vector3(bp.x, 0.0, bp.z), [], rad_to_deg(-ba))


static func _spawn_guards(raid, center: Vector3, guards: Array) -> void:
	if guards.is_empty():
		return
	var lead = null
	var cap: int = int(raid.MAX_BUGS) + 48
	for i in guards.size():
		var kind := str(guards[i])
		var ang: float = TAU * float(i) / float(guards.size())
		var rad: float = 8.4
		var gp := center + Vector3(cos(ang) * rad, 0.5, sin(ang) * rad)
		var g = raid.spawn_bug(kind, gp, cap)
		if g == null:
			continue
		g.home = center
		if raid.mech != null:
			g.target = raid.mech
		if lead == null:
			lead = g
			g.territory = 24.0
		else:
			g.pack_leader = lead
			lead.pack.append(g)
			var n: int = lead.pack.size()
			var a := PI + (0.5 + 0.35 * n) * (1.0 if n % 2 == 0 else -1.0)
			g.follow_off = Vector3(sin(a), 0, -cos(a)) * (2.6 + 0.9 * n)
