extends Node
## 局内派系调度：「流浪者」机甲小队与玩家的 AI 战斗队友。由 raid.gd 在出击（或转场进入）时创建为行动场景的子节点。
##
## 流浪者：2~4 台随机拼装、锈红涂装的机甲组成小队，从地图边缘的道路口进入，沿道路（或经过一处遗迹）穿到另一侧边缘离开。
##   行进时保持楔形队形、等掉队的成员；任一成员交战（玩家、队友或虫群进入射程）全队停下来打，安静 3 秒后继续赶路。
##   同时最多 MAX_SQUADS 支，离开或全灭后 45~90 秒再来一支。击毁掉落军械箱（rover 掉落表 + 一半概率拆下一件模块）。
## 战斗队友：出击时读 scripts/progression/growth.gd 的 static func ally_squad() -> [{"pilot", "tier"}]（函数不存在视为空），
##   每项生成一台跟随玩家的友方机甲，tier 1~3 提高结构与伤害；跨图转场时随玩家一起过去（保留剩余结构）。
## 测试可写 test_ally_squad 注入队友列表、把 rovers_enabled 设为 false 关掉流浪者。

const Prof = preload("res://scripts/prof.gd")

const Npc = preload("res://scripts/factions/npc_mech.gd")
const RadarOverlay = preload("res://scripts/factions/radar_overlay.gd")

const MAX_SQUADS := 2
const FIRST_SQUAD := Vector2(10.0, 22.0)    ## 开局后第一支小队进场的时间窗（秒）
const NEXT_SQUAD := Vector2(45.0, 90.0)
const ALLY_SLOTS := [Vector3(-5.5, 0, 4.5), Vector3(5.5, 0, 4.5), Vector3(0, 0, 8.0), Vector3(-9.0, 0, 1.0), Vector3(9.0, 0, 1.0)]
const FORMATION := [Vector3.ZERO, Vector3(-4.0, 0, 4.5), Vector3(4.0, 0, 4.5), Vector3(0, 0, 9.0)]

## 驾驶员的惯用装配（模块不存在时逐槽退回初始装配）
const PILOT_LOADOUT := {
	"nao": {"core": "core_std", "legs": "legs_biped", "arm_l": "arm_mg", "arm_r": "arm_shotgun", "back": "back_cargo", "gen": "gen_reactor"},
	"rei": {"core": "core_scout", "legs": "legs_reverse", "arm_l": "arm_laser", "arm_r": "arm_laser", "back": "back_jump", "gen": "gen_crystal"},
	"kurumi": {"core": "core_heavy", "legs": "legs_tread", "arm_l": "arm_flamer", "arm_r": "arm_mg", "back": "back_shield", "gen": "gen_fission"},
	"lina": {"core": "core_std", "legs": "legs_quad", "arm_l": "arm_flak", "arm_r": "arm_mg", "back": "back_repair", "gen": "gen_reactor"},
	"laojiao": {"core": "core_heavy", "legs": "legs_titan", "arm_l": "arm_shotgun", "arm_r": "arm_shotgun", "back": "back_shield", "gen": "gen_fission"},
}

static var test_ally_squad = null    ## 测试注入：Array 时代替 growth.gd 的 ally_squad()
static var rovers_enabled := true

var raid
var squads: Array = []        ## {members: Array, route: Array[Vector3], idx: int, calm: float, fighting: bool}
var allies: Array = []
var next_t := 0.0
var clock := 0.0
var rng := RandomNumberGenerator.new()
var overlay
var _allies_pending: Array = []


func setup(r, drop: Vector3) -> void:
	raid = r
	rng.randomize()
	next_t = rng.randf_range(FIRST_SQUAD.x, FIRST_SQUAD.y)
	if raid.hud and raid.hud.radar:
		overlay = RadarOverlay.new()
		overlay.raid = raid
		raid.hud.radar.add_child(overlay)
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var list: Array = []
	if raid.transit.has("allies"):
		list = raid.transit.allies
	else:
		list = ally_squad()
	_allies_pending = list.duplicate(true)
	if not raid.transit.is_empty():
		_spawn_allies(drop)


## 读成长系统的队友编成：函数还不存在（或返回的不是数组）时视为没有队友
static func ally_squad() -> Array:
	if test_ally_squad is Array:
		return test_ally_squad
	var path := "res://scripts/progression/growth.gd"
	if not ResourceLoader.exists(path):
		return []
	var s = load(path)
	if s == null:
		return []
	var has := false
	if s.has_method("ally_squad"):
		has = true
	else:
		for m in s.get_script_method_list():
			if m.name == "ally_squad":
				has = true
				break
	if not has:
		return []
	var out = s.call("ally_squad")
	return out if out is Array else []


func _physics_process(delta: float) -> void:
	var _pt := Prof.t0()
	_physics_tick(delta)
	Prof.add("phys.factions", _pt)


func _physics_tick(delta: float) -> void:
	if raid == null or raid.ended:
		return
	if raid.dropping:
		return
	if not _allies_pending.is_empty() and allies.is_empty():
		_spawn_allies(raid.mech.global_position)
	clock += delta
	_update_allies(delta)
	for sq in squads.duplicate():
		_update_squad(sq, delta)
	if rovers_enabled and squads.size() < MAX_SQUADS and clock >= next_t:
		next_t = clock + rng.randf_range(NEXT_SQUAD.x, NEXT_SQUAD.y)
		spawn_squad()


# ================================================================ 战斗队友
func _spawn_allies(at: Vector3) -> void:
	var list := _allies_pending
	_allies_pending = []
	for i in list.size():
		var e: Dictionary = list[i] if list[i] is Dictionary else {}
		var pilot := str(e.get("pilot", ""))
		var tier := clampi(int(e.get("tier", 1)), 1, 3)
		var lo: Dictionary = e.get("loadout", {}) if e.get("loadout") is Dictionary else {}
		if lo.is_empty():
			lo = pilot_loadout(pilot)
		var n = Npc.new()
		n.raid = raid
		n.pilot = pilot
		raid.add_child(n)
		n.setup_npc(lo, "ally", tier)
		if e.has("hp"):
			n.hp = clampf(float(e.hp), 1.0, n.max_hp)
		n.slot_i = i
		var off: Vector3 = ALLY_SLOTS[i % ALLY_SLOTS.size()]
		n.global_position = _free_near(at + off)
		allies.append(n)
		if raid.transit.is_empty():
			# 队友跟着玩家一起空投：从高处落下
			var land: Vector3 = n.global_position
			n.global_position = land + Vector3(0, 18, 0)
			var tw := n.create_tween()
			tw.tween_interval(0.15 * i)
			tw.tween_property(n, "global_position", land + Vector3(0, 0.2, 0), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(func():
				if is_instance_valid(n):
					n.slam = 0.8
					raid.explode_fx(land, 2.5, Color(0.8, 0.7, 0.55)))
	if not allies.is_empty() and raid.hud:
		raid.hud.msg("战斗队友 %d 台已随行，自动跟随并攻击虫群与流浪者" % allies.size())


static func pilot_loadout(pilot: String) -> Dictionary:
	var base: Dictionary = PILOT_LOADOUT.get(pilot, PILOT_LOADOUT.nao)
	var lo := {}
	for slot in ["core", "legs", "arm_l", "arm_r", "back", "gen"]:
		var id := str(base.get(slot, ""))
		lo[slot] = id if GameData.is_module(id) else str(GameData.STARTER.get(slot, ""))
	return lo


func _update_allies(_delta: float) -> void:
	var m = raid.mech
	if not Npc._ok(m):
		return
	var yaw: float = m.legs.rotation.y if m.legs else 0.0
	for a in allies.duplicate():
		if not is_instance_valid(a) or a.dead:
			allies.erase(a)
			continue
		var off: Vector3 = ALLY_SLOTS[a.slot_i % ALLY_SLOTS.size()].rotated(Vector3.UP, yaw)
		a.goal = m.global_position + off
		a.goal_scale = 1.0
		# 掉队太远（卡在建筑后面）且不在画面里：直接补位到玩家身后
		if a.global_position.distance_to(m.global_position) > 70.0:
			a.global_position = _free_near(m.global_position + off * 1.6)
			a.velocity = Vector3.ZERO


## 转场时带走的队友状态
func ally_state() -> Array:
	var out: Array = []
	for a in allies:
		if is_instance_valid(a) and not a.dead:
			out.append({"pilot": a.pilot, "tier": a.tier, "hp": a.hp, "loadout": a.loadout.duplicate()})
	return out


# ================================================================ 流浪者小队
## 生成一支小队；返回小队字典（找不到合适的进场路线时返回空字典）
func spawn_squad(n := -1, route: Array = []) -> Dictionary:
	if route.is_empty():
		route = make_route()
	if route.size() < 2:
		return {}
	# 路点夹进地图内（出口在边界上，离边 6 米即视为到达）
	var H: float = raid.HALF - 6.0
	var clamped: Array = []
	for q: Vector3 in route:
		clamped.append(Vector3(clampf(q.x, -H, H), q.y, clampf(q.z, -H, H)))
	route = clamped
	if n < 0:
		n = rng.randi_range(2, 4)
	var sq := {"members": [], "route": route, "idx": 1, "calm": 99.0, "fighting": false}
	var start: Vector3 = route[0]
	var dir: Vector3 = (route[1] - route[0])
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
	var yaw := atan2(-dir.x, -dir.z)
	for i in n:
		var r = Npc.new()
		r.raid = raid
		raid.add_child(r)
		r.setup_npc(rover_loadout(rng), "rover", 1)
		r.squad = sq
		r.slot_i = i
		r.global_position = _free_near(start + FORMATION[i % FORMATION.size()].rotated(Vector3.UP, yaw))
		r.legs.rotation.y = yaw
		r.torso.rotation.y = yaw
		sq.members.append(r)
	squads.append(sq)
	return sq


func _update_squad(sq: Dictionary, delta: float) -> void:
	var alive: Array = []
	for r in sq.members:
		if is_instance_valid(r) and not r.dead:
			alive.append(r)
	sq.members = alive
	if alive.is_empty():
		squads.erase(sq)
		return
	var fighting := false
	for r in alive:
		if Npc._ok(r.ai_target):
			fighting = true
	if fighting:
		sq.calm = 0.0
	else:
		sq.calm += delta
	sq.fighting = fighting or sq.calm < 3.0
	var lead = alive[0]
	if sq.fighting:
		# 交战：没有目标的成员向打得最凶的队友靠拢，不再赶路
		for r in alive:
			r.goal = lead.global_position if r != lead else lead.global_position
			r.goal_scale = 0.8
		return
	var route: Array = sq.route
	if sq.idx >= route.size():
		_try_leave(sq)
		return
	var wp: Vector3 = route[sq.idx]
	var lp: Vector3 = lead.global_position
	if Vector2(wp.x - lp.x, wp.z - lp.z).length() < 7.0:
		sq.idx += 1
		if sq.idx >= route.size():
			_try_leave(sq)
			return
		wp = route[sq.idx]
	var dir := wp - lp
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
	var yaw := atan2(-dir.x, -dir.z)
	# 有成员掉队超过 14 米时队首放慢等人
	var lag := 0.0
	for i in alive.size():
		if i == 0:
			continue
		var want: Vector3 = lp + FORMATION[i % FORMATION.size()].rotated(Vector3.UP, yaw)
		lag = maxf(lag, alive[i].global_position.distance_to(want))
	lead.goal = wp
	lead.goal_scale = 0.45 if lag > 14.0 else 0.7
	for i in alive.size():
		if i == 0:
			continue
		alive[i].goal = lp + FORMATION[i % FORMATION.size()].rotated(Vector3.UP, yaw)
		alive[i].goal_scale = 0.85


## 走到出口：玩家不在附近就悄悄离场（释放节点），否则在边上待命
func _try_leave(sq: Dictionary) -> void:
	var m = raid.mech
	for r in sq.members:
		if Npc._ok(m) and r.global_position.distance_to(m.global_position) < 50.0:
			return
	for r in sq.members:
		r.queue_free()
	squads.erase(sq)


## 随机拼装一台流浪者：每个槽位在现有模块里抽（稀有度 ≤2，武器排除近战 / 抛射类），背部 60% 概率挂件
static func rover_loadout(r: RandomNumberGenerator) -> Dictionary:
	var pools := {"core": [], "legs": [], "arm": [], "back": [], "gen": []}
	for id in GameData.MODULES:
		var m: Dictionary = GameData.MODULES[id]
		var slot := str(m.get("slot", ""))
		if not pools.has(slot) or int(m.get("rar", 0)) > 2:
			continue
		if slot == "arm":
			var w := str(m.get("weapon", ""))
			if w in ["mortar", "grenade", "drill"] or float(m.get("range", 0.0)) < 9.0:
				continue
			if not GameData.AMMO.has(w):
				continue
		pools[slot].append(id)
	var lo := {}
	for slot in ["core", "legs", "arm_l", "arm_r", "back", "gen"]:
		var key: String = "arm" if slot.begins_with("arm") else slot
		var pool: Array = pools[key]
		if pool.is_empty() or (slot == "back" and r.randf() > 0.6):
			lo[slot] = str(GameData.STARTER.get(slot, "")) if slot != "back" else ""
			continue
		lo[slot] = str(pool[r.randi() % pool.size()])
	if lo.arm_l == "" and lo.arm_r == "":
		lo.arm_l = "arm_mg"
	return lo


## 进场路线：沿一条通到地图边缘的道路走；格网道路有六成概率在路口拐上另一条通边缘的路，
## 只有一端通边缘的路先走到另一头的遗迹再折向最近的边缘路口。入口选离玩家 90 米以外的那一端。
func make_route() -> Array:
	var H: float = raid.HALF - 6.0
	var paths: Array = []
	for r: Dictionary in raid.roads:
		var a := Vector2(r.c, maxf(r.a, -H)) if r.v else Vector2(maxf(r.a, -H), r.c)
		var b := Vector2(r.c, minf(r.b, H)) if r.v else Vector2(minf(r.b, H), r.c)
		if a.distance_to(b) > 60.0:
			paths.append({"pts": [a, b], "grid": true, "v": r.v, "c": r.c, "lo": maxf(r.a, -H), "hi": minf(r.b, H)})
	for cv: Dictionary in raid.curves:
		var pts: Array = []
		for q: Vector2 in cv.pts:
			pts.append(Vector2(clampf(q.x, -H, H), clampf(q.y, -H, H)))
		if pts.size() >= 2:
			paths.append({"pts": pts, "grid": false})
	var mp: Vector3 = raid.mech.global_position if Npc._ok(raid.mech) else Vector3.ZERO
	var player := Vector2(mp.x, mp.z)
	var cands: Array = []
	for p: Dictionary in paths:
		var pts: Array = p.pts
		for end in [0, 1]:
			var s: Vector2 = pts[0] if end == 0 else pts[-1]
			if _at_edge(s, H) and s.distance_to(player) > 90.0:
				var seq: Array = pts.duplicate()
				if end == 1:
					seq.reverse()
				cands.append({"path": p, "seq": seq})
	if cands.is_empty():
		# 没有通边缘的路：从离玩家最远的一条边的中点横穿
		var edges := [Vector2(0, -H), Vector2(0, H), Vector2(-H, 0), Vector2(H, 0)]
		edges.sort_custom(func(x, y): return x.distance_to(player) > y.distance_to(player))
		return [_v3(edges[0]), Vector3.ZERO, _v3(-edges[0])]
	var pick: Dictionary = cands[rng.randi() % cands.size()]
	var seq: Array = pick.seq
	var out: Array = [seq[0]]
	if pick.path.grid and rng.randf() < 0.6:
		# 在路口拐弯：找一条与之垂直、在路口处相交、另一头通边缘的格网路
		var turns: Array = []
		for q: Dictionary in paths:
			if not q.get("grid", false) or q.v == pick.path.v:
				continue
			if q.c < pick.path.lo or q.c > pick.path.hi or pick.path.c < q.lo or pick.path.c > q.hi:
				continue
			var cross := Vector2(pick.path.c, q.c) if pick.path.v else Vector2(q.c, pick.path.c)
			if cross.distance_to(seq[0]) < 50.0:
				continue
			for e in q.pts:
				if _at_edge(e, H) and e.distance_to(cross) > 50.0:
					turns.append([cross, e])
		if not turns.is_empty():
			var t: Array = turns[rng.randi() % turns.size()]
			out.append(t[0])
			out.append(t[1])
			return _to3(out)
	for i in range(1, seq.size()):
		out.append(seq[i])
	if not _at_edge(out[-1], H) and not raid.poi_centers.is_empty():
		var poi: Vector3 = raid.poi_centers[rng.randi() % raid.poi_centers.size()]
		out.append(Vector2(poi.x, poi.z))
		var best := Vector2(0, H)
		var bd := INF
		for p: Dictionary in paths:
			for e in [p.pts[0], p.pts[-1]]:
				if _at_edge(e, H) and e.distance_to(seq[0]) > 80.0 and e.distance_to(Vector2(poi.x, poi.z)) < bd:
					bd = e.distance_to(Vector2(poi.x, poi.z))
					best = e
		out.append(best)
	return _to3(out)


static func _at_edge(p: Vector2, h: float) -> bool:
	return absf(p.x) >= h - 8.0 or absf(p.y) >= h - 8.0


static func _v3(p: Vector2) -> Vector3:
	return Vector3(p.x, 0, p.y)


static func _to3(a: Array) -> Array:
	var out: Array = []
	for p: Vector2 in a:
		out.append(Vector3(p.x, 0.3, p.y))
	return out


func _free_near(p: Vector3) -> Vector3:
	var H: float = raid.HALF - 6.0
	for i in 12:
		var q := p + (Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * 2.5 * i if i > 0 else Vector3.ZERO)
		q.x = clampf(q.x, -H, H)
		q.z = clampf(q.z, -H, H)
		if not raid._blocked(q, 1.6, false):
			return Vector3(q.x, 0.3, q.z)
	return Vector3(clampf(p.x, -H, H), 0.3, clampf(p.z, -H, H))
