extends "res://tests/lib/test_base.gd"
## 敌人视野 + 受击锁定 + 导航寻路：
##   1. 视野内但隔着墙 → 看不见；拆掉墙（视线通）→ 发现并追击
##   2. 站在 vision × 1.05 处 → 看不见；vision × 0.9 处 → 看得见
##   3. 在视野外（1.3 × vision）被打 → 锁定攻击者追击；目标拉开到 1.5 × vision 外 → 丢失、回到巡逻
##   4. 导航网格：墙后的目标，A* 路径绕过墙能到达，虫子沿路径真的走到目标身边
## godot --headless --path . -- --ai_vision

const TIMEOUT := 240.0
const Factions = preload("res://scripts/factions/factions.gd")
const EAST := Vector3(1, 0, 0)

var raid
var m


func run() -> void:
	Factions.rovers_enabled = false
	Factions.test_ally_squad = []
	GameData.map_id = "greyport"
	raid = await deploy()
	if not check(raid != null, "出击失败"):
		return
	m = raid.mech
	m.max_hp = 1e6
	m.hp = 1e6
	m.shield_time = 9999.0
	_clear_bugs()
	await frames(5)
	if not check(raid.nav != null, "没有生成导航网格"):
		return
	var pv: float = raid.player_view_range()
	var v: float = raid.vision_range()
	var lose: float = raid.lose_range()
	log_line("cam_zoom=%.2f player_view=%.1fm vision=%.1fm lose=%.1fm nav %dx%d build %.0fms shapes=%d" % [raid.cam_zoom, pv, v, lose, raid.nav.n, raid.nav.n, raid.nav.build_ms, raid.nav.shape_count])
	if not check(is_equal_approx(raid.cam_zoom, raid.ZOOM_MAX), "默认镜头不是最远一档"):
		return
	if not check(pv > 15.0 and pv < 60.0 and v < pv and v > pv * 0.8, "视野数值不合理"):
		return
	if not check(absf(lose - v * 1.5) < 0.01, "丢失距离不是 1.5 倍视野"):
		return
	# 找一块开阔地：机甲往东 1.6 × vision 都是直线可走、视线通的空地，南北各 ±12 米也空
	var c := _find_open(v * 1.6, 12.0)
	if not check(c != Vector3.INF, "找不到测试用的开阔地"):
		return
	_place_mech(c)
	await frames(10)

	# ---- 1. 隔墙看不见，拆墙后看见 ----
	var b = _spawn(c + EAST * 16.0)
	var wall = raid._static_box(Vector3(1.0, 4.0, 14.0), c + EAST * 8.0 + Vector3(0, 2.0, 0), Color(0.4, 0.4, 0.4))
	await frames(3)
	await wait(1.6)
	if not check(is_instance_valid(b) and b.state == "idle", "隔着墙 16 米也发现了机甲（state=%s）" % (b.state if is_instance_valid(b) else "freed")):
		return
	wall.queue_free()
	var ok: bool = await until(func(): return is_instance_valid(b) and b.state == "chase", 2.0)
	if not check(ok and b.target == m, "视线通、16 米（视野内）却没有发现机甲"):
		return
	log_line("wall blocks sight at 16m; detected once wall removed")
	_clear_bugs()
	await frames(3)
	_place_mech(c)

	# ---- 2. 视野边界 ----
	b = _spawn(c + EAST * (v * 1.05))
	await wait(1.6)
	if not check(is_instance_valid(b) and b.state == "idle", "vision × 1.05（%.1f 米）处也发现了机甲" % (v * 1.05)):
		return
	if not check(absf(b.aggro_range - v) < 0.01, "满视野虫种的察觉距离 %.1f 不等于 vision %.1f" % [b.aggro_range, v]):
		return
	_clear_bugs()
	await frames(3)
	b = _spawn(c + EAST * (v * 0.9))
	ok = await until(func(): return is_instance_valid(b) and b.state == "chase", 2.0)
	if not check(ok, "vision × 0.9（%.1f 米）处、视线通却没有发现机甲" % (v * 0.9)):
		return
	log_line("no detection at %.1fm (1.05x), detection at %.1fm (0.9x)" % [v * 1.05, v * 0.9])
	_clear_bugs()
	await frames(3)
	_place_mech(c)

	# ---- 3. 远处被打 → 锁定追击；拉开到 1.5 倍视野外 → 丢失 ----
	var far := c + EAST * (v * 1.3)
	b = _spawn(far)
	await wait(0.8)
	if not check(b.state == "idle", "1.3 倍视野外的虫子自己发现了机甲"):
		return
	b.aggressor = m
	b.take_damage(1.0)
	if not check(b.state == "chase" and b.target == m and b.lock_target == m, "被打后没有锁定攻击者"):
		return
	var d0: float = b.global_position.distance_to(m.global_position)
	await wait(1.5)
	var d1: float = b.global_position.distance_to(m.global_position) if is_instance_valid(b) else 999.0
	log_line("locked from %.1fm (> vision), after 1.5s at %.1fm" % [d0, d1])
	if not check(is_instance_valid(b) and b.state == "chase" and d1 < d0 - 6.0, "锁定后没有追过来（%.1f → %.1f）" % [d0, d1]):
		return
	# 机甲退到虫子 1.2 倍视野处：超出视野但没超出丢失距离，继续追
	b.velocity = Vector3.ZERO
	var bp: Vector3 = b.global_position
	_place_mech(bp - EAST * (v * 1.2))
	await wait(0.8)
	if not check(is_instance_valid(b) and b.state == "chase", "超出视野（1.2x）但没到 1.5 倍就丢了目标"):
		return
	# 拉开到 1.5 倍视野外
	var away := _far_free(b.global_position, lose * 1.25)
	if not check(away != Vector3.INF, "找不到拉开距离用的空地"):
		return
	_place_mech(away)
	ok = await until(func(): return not is_instance_valid(b) or b.state == "idle", 3.0)
	if not check(ok and is_instance_valid(b), "拉开到 %.1f 米（> 1.5x 视野）后没有丢失目标" % b.global_position.distance_to(m.global_position)):
		return
	log_line("lost target at %.1fm (> lose %.1fm), back to idle" % [b.global_position.distance_to(m.global_position), lose])
	_clear_bugs()
	await frames(3)

	# ---- 4. 寻路：墙后的目标 ----
	_place_mech(c)
	await frames(3)
	var wc := c + EAST * 14.0
	var wall2 = raid._static_box(Vector3(1.2, 4.0, 16.0), wc + Vector3(0, 2.0, 0), Color(0.4, 0.4, 0.4))
	await frames(2)
	raid.rebuild_nav()
	var A := wc + EAST * 7.0
	var B := wc - EAST * 7.0
	if not check(not raid.nav.line_clear(A, B), "导航网格没有把新墙栅格进去"):
		return
	var path = null
	for i in 5:
		path = raid.nav.request_path(A, B)
		if path != null:
			break
		await get_tree().physics_frame
	if not check(path != null and path.size() >= 2, "A* 没有给出绕墙路径"):
		return
	var plen := 0.0
	var prev := A
	for q: Vector3 in path:
		if not check(raid.nav.line_clear(prev, q), "路径有一段穿墙"):
			return
		plen += prev.distance_to(q)
		prev = q
	log_line("A* around wall: %d pts, length %.1fm vs straight %.1fm" % [path.size(), plen, A.distance_to(B)])
	if not check(Vector2(prev.x - B.x, prev.z - B.z).length() < 2.0 and plen > A.distance_to(B) + 2.0, "路径没有绕墙到达终点"):
		return
	# 虫子在墙东侧，机甲在墙西侧：受击锁定后沿路径绕过墙追到机甲身边
	_place_mech(B)
	b = _spawn(A)
	b.aggressor = m
	b.take_damage(1.0)
	ok = await until(func(): return is_instance_valid(b) and b.global_position.distance_to(m.global_position) < 5.0, 10.0)
	log_line("bug path-followed around the wall: %s (dist %.1f)" % [ok, b.global_position.distance_to(m.global_position) if is_instance_valid(b) else -1.0])
	if not check(ok, "虫子没能绕过墙追到机甲"):
		return
	wall2.queue_free()
	Factions.rovers_enabled = true
	Factions.test_ally_squad = null


func _clear_bugs() -> void:
	for n in get_tree().get_nodes_in_group("bugs") + get_tree().get_nodes_in_group("nests"):
		n.remove_from_group("bugs")
		n.queue_free()


func _place_mech(p: Vector3) -> void:
	m.global_position = Vector3(p.x, 0.3, p.z)
	m.velocity = Vector3.ZERO


## 在场上不动的满视野虫子（镰爪虫，数据表察觉距离 20 = 满视野）
func _spawn(p: Vector3):
	var b = raid.spawn_bug("mantis", Vector3(p.x, 0.5, p.z), 9999)
	b.territory = 0.5
	b.patrol_speed = 0.0
	b.spawn_t = 0.0
	return b


## 开阔地：从 c 往东 len 米、南北 ±side 米内的平行线都直线可走、视线通
func _find_open(length: float, side: float) -> Vector3:
	var nav = raid.nav
	var H: float = raid.HALF - 10.0
	var z := -H
	while z < H:
		var x := -H
		while x < H - length:
			var c := Vector3(x, 0, z)
			var good := true
			var off := -side
			while off <= side and good:
				var a := c + Vector3(0, 0, off)
				good = nav.is_free(a) and nav.line_clear(a, a + EAST * length) and raid.has_los(a, a + EAST * length)
				off += 3.0
			if good:
				return c
			x += 6.0
		z += 6.0
	return Vector3.INF


## 离 from 至少 dist 米、机甲能站的空地
func _far_free(from: Vector3, dist: float) -> Vector3:
	for k in 64:
		var a := TAU * k / 64.0
		for extra in [0.0, 10.0, 20.0]:
			var p: Vector3 = from + Vector3(cos(a), 0, sin(a)) * (dist + extra)
			if absf(p.x) < raid.HALF - 10.0 and absf(p.z) < raid.HALF - 10.0 and raid.nav.is_free(p, true):
				return p
	return Vector3.INF
