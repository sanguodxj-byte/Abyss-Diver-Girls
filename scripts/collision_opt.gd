extends RefCounted
## 碰撞后处理：地图（含扩展地标 / POI）全部建好之后跑一遍，减少机甲 / 虫子被布景卡住。
## 完全按场景里实际的 StaticBody3D / CollisionShape3D 工作，不依赖地图生成器摆了什么：
##   1) 小件去碰撞：水平最大尺寸 < SMALL_EXTENT，或顶高 < LOW_TOP 且最大尺寸 < LOW_MAX_EXT 的碰撞形状直接删掉（网格保留，只是能穿过）
##   2) 窄缝合并：两个障碍物之间的缝 < GAP_T（单位过不去或只能硬挤）就用一块凸体填缝，并把同一簇的碰撞形状并到一个 StaticBody3D 里；
##      簇的凸包填充率 ≥ HULL_FILL 时整簇直接换成一个凸包（顺带抹掉簇外轮廓上的凹口）
##   3) 填缝 / 凸包登记到 raid.blocks，并清空巡逻格子缓存，让后续摆放与巡逻一致地避开
##   4) 搜刮箱保护：填缝不压到箱子；若填缝会把原本走得到的箱子封死（局部洪泛判定），撤掉附近的填缝
##   5) 挂上 collision_unstuck.gd：玩家机甲被卡住时把它挪到最近的空位
## 入口：raid.gd start() 里地图建完、刷虫之前调用 optimize(raid)。

const UnstuckScript = preload("res://scripts/collision_unstuck.gd")

## ---- 阈值（单位：米）----
const UNIT_R := 1.0           ## 玩家 / NPC 机甲胶囊半径（mech.gd），也是可达性栅格的膨胀半径
const SMALL_EXTENT := 1.2     ## 水平最大尺寸小于它的碰撞体去掉碰撞：树干（0.9）、吊机细腿（0.7）、小碎块。比机甲直径（2.0）还细的东西只会“勾住”机甲
const LOW_TOP := 0.8          ## 顶高低于它的矮物（倒木 0.6、小碎石）机甲可以跨过；子弹从约 1.8m 高射出，本来就打不到这么矮的东西
const LOW_MAX_EXT := 6.0      ## 矮物去碰撞只对小于这个尺寸的生效（大块低矮平台保留）
const GAP_T := 2.6            ## 可通行阈值：机甲直径 2.0 + 0.6 余量（≈ 甲虫直径 2.7）。比它窄的缝要么过不去、要么挤进去卡住
const GAP_EPS := 0.02         ## 小于它视为已接触，不需要填缝
const FILL_REACH := 0.6       ## 填缝凸体收录“离对方不超过 缝宽 + FILL_REACH”的顶点，长条平行缝会被整条填满
const BRIDGE_HALF := 0.4      ## 两最近点之间的连接条半宽（再受两侧障碍物厚度限制，避免薄墙填缝凸出墙面）
const LOOT_CLEAR := 1.6       ## 填缝 / 凸包离搜刮箱中心至少这么远
const LOOT_REACH := 3.4       ## 搜刮交互距离 3.6（raid.nearest_box）留 0.2 余量
const LOOT_WIN := 16.0        ## 搜刮箱封死判定的局部窗口半宽（32m 见方，装得下 18m 的围墙院落）
const CELL := 0.5             ## 可达性栅格边长
const HULL_FILL := 0.85       ## 簇凸包填充率阈值
const HULL_MAX_AREA := 900.0  ## 只对凸包面积小于它的簇做整体替换（大簇保持“原形状 + 填缝”）
const GROUND_EPS := 0.15      ## 底面以下的形状（地面）不参与
const UNIT_TOP := 2.6         ## 底面高于它的形状（瞭望塔平台、吊机横梁）单位从下面走过，不参与
const HUGE_EXT := 120.0       ## 超大形状（地面盒）不参与

## 测试 A/B 用：false 时 optimize() 不改动碰撞 / 不挂防卡死节点。命令行 --collision_opt=0 / --unstuck=0 可以对任意测试关掉
static var enabled := not OS.get_cmdline_user_args().has("--collision_opt=0")
static var unstuck_enabled := not OS.get_cmdline_user_args().has("--unstuck=0")
static var merge_bodies := not OS.get_cmdline_user_args().has("--collision_merge=0")  ## 实验开关：false 时不搬形状，每块填缝单独一个静态体
static var last_stats := {}


## 主入口。返回统计信息（也存进 last_stats）
static func optimize(raid) -> Dictionary:
	var stats := {"enabled": enabled}
	if unstuck_enabled and raid.get_node_or_null("CollisionUnstuck") == null:
		var u = UnstuckScript.new()
		u.name = "CollisionUnstuck"
		u.raid = raid
		raid.add_child(u)
	if not enabled:
		last_stats = stats
		return stats
	var t0 := Time.get_ticks_usec()
	var obs := collect(raid.world)
	stats["shapes_considered"] = obs.size()
	var loot := _loot_points(raid)
	stats["t_collect"] = (Time.get_ticks_usec() - t0) / 1000.0
	# ---- 1) 小件去碰撞 ----
	var removed := 0
	var keep: Array = []
	for o: Dictionary in obs:
		if o.ext < SMALL_EXTENT or (o.y1 < LOW_TOP and o.ext < LOW_MAX_EXT):
			var cs: CollisionShape3D = o.cs
			cs.get_parent().remove_child(cs)
			cs.free()
			removed += 1
		else:
			keep.append(o)
	obs = keep
	stats["small_removed"] = removed
	# ---- 2) 找窄缝 ----
	var parent := range(obs.size())
	var fillers: Array = []      # {poly, y1, a, b}
	var skipped_loot := 0
	for pr: Vector2i in _candidate_pairs(obs, GAP_T):
		var A: Dictionary = obs[pr.x]
		var B: Dictionary = obs[pr.y]
		var r := poly_gap(A.poly, B.poly)
		var gap: float = r[0]
		if gap >= GAP_T:
			continue
		_union(parent, pr.x, pr.y)
		if gap <= GAP_EPS:
			continue
		var f := _filler(A, B, gap, r[1], r[2])
		if f.size() < 3:
			continue
		if _near_loot(f, loot, LOOT_CLEAR):
			skipped_loot += 1
			continue
		fillers.append({"poly": f, "rect": _poly_rect(f), "y1": minf(A.y1, B.y1), "a": pr.x, "b": pr.y, "gap": gap})
	stats["t_pairs"] = (Time.get_ticks_usec() - t0) / 1000.0
	# ---- 4) 搜刮箱封死检查：填缝前走得到、填缝后走不到 → 由近到远撤掉附近的填缝 ----
	var reopened: Array = []
	if not fillers.is_empty():
		reopened = _protect_loot(obs, fillers, loot)
	stats["t_loot"] = (Time.get_ticks_usec() - t0) / 1000.0
	stats["fillers"] = fillers.size()
	stats["fillers_skipped_loot"] = skipped_loot
	stats["fillers_reopened"] = reopened.size()
	# ---- 簇 ----
	var clusters := {}
	for i in obs.size():
		var root := _find(parent, i)
		if not clusters.has(root):
			clusters[root] = {"members": [], "fillers": []}
		clusters[root].members.append(i)
	for f: Dictionary in fillers:
		clusters[_find(parent, f.a)].fillers.append(f)
	var no_hull := {}   # 撤过填缝的簇不能整体换成凸包（凸包会把撤开的缝重新封上）
	for f: Dictionary in reopened:
		no_hull[_find(parent, f.a)] = true
	var merged_bodies := 0
	var hulls := 0
	var new_rects: Array = []
	var new_polys: Array = []
	for root in clusters:
		var c: Dictionary = clusters[root]
		if c.members.size() < 2:
			continue
		var mergeable := merge_bodies
		for i: int in c.members:
			if obs[i].fixed:
				mergeable = false
		if not mergeable:
			# 有脚本的静态体（理论上不会出现）或关闭合并：不搬形状，每块填缝单独一个静态体
			for f: Dictionary in c.fillers:
				var fb := _new_body(raid.world, 1)
				_add_prism(fb, f.poly, 0.0, f.y1)
				new_polys.append(f.poly)
				merged_bodies += 1
			continue
		var layer := 0
		var ymin := INF
		var ymax := -INF
		var pts := PackedVector2Array()
		var polys: Array = []
		for i: int in c.members:
			layer |= int(obs[i].body.collision_layer)
			ymin = minf(ymin, obs[i].y0)
			ymax = maxf(ymax, obs[i].y1)
			pts.append_array(obs[i].poly)
			polys.append(obs[i].poly)
		for f: Dictionary in c.fillers:
			pts.append_array(f.poly)
			polys.append(f.poly)
		var body := _new_body(raid.world, layer)
		merged_bodies += 1
		var hull := _hull(pts)
		var harea := absf(_area(hull))
		var sum_area := 0.0   # 成员 + 填缝面积之和（重叠会重复计，是覆盖面积的上界）：不够阈值就不必采样
		for poly: PackedVector2Array in polys:
			sum_area += absf(_area(poly))
		var use_hull := not no_hull.has(root) and harea > 0.5 and sum_area >= harea * HULL_FILL and harea <= HULL_MAX_AREA and not _near_loot(hull, loot, LOOT_CLEAR) \
			and _fill_ratio(hull, polys) >= HULL_FILL
		if use_hull:
			for i: int in c.members:
				var cs: CollisionShape3D = obs[i].cs
				cs.get_parent().remove_child(cs)
				cs.free()
			_add_prism(body, hull, minf(ymin, 0.0), ymax)
			new_polys.append(hull)
			hulls += 1
		else:
			for i: int in c.members:
				var cs: CollisionShape3D = obs[i].cs
				var gt := cs.global_transform
				cs.get_parent().remove_child(cs)
				body.add_child(cs)
				cs.global_transform = gt
			for f: Dictionary in c.fillers:
				_add_prism(body, f.poly, 0.0, f.y1)
				new_polys.append(f.poly)
	stats["t_build"] = (Time.get_ticks_usec() - t0) / 1000.0
	# ---- 3) 摆放 / 巡逻数据 ----
	for p: PackedVector2Array in new_polys:
		var rr := _poly_rect(p)
		raid.blocks.append(rr)
		new_rects.append(rr)
	if "_pgrid" in raid:
		raid._pgrid = {}
	_push_units_out(raid, new_polys)
	stats["merged_bodies"] = merged_bodies
	stats["hull_clusters"] = hulls
	stats["blocks_added"] = new_rects.size()
	stats["ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	last_stats = stats
	print("[collision_opt] %s" % str(stats))
	return stats


# ================================================================ 收集
## 地图上（raid.world 之下）参与单位碰撞的静态体数量：layer 含 1 且至少有一个启用的形状
static func count_static(world: Node) -> Dictionary:
	var bodies := 0
	var shapes := 0
	for b: Node in world.find_children("*", "StaticBody3D", true, false):
		var sb := b as StaticBody3D
		if (sb.collision_layer & 1) == 0:
			continue
		var n := 0
		for ch in sb.get_children():
			if ch is CollisionShape3D and not ch.disabled and ch.shape != null:
				n += 1
		if n > 0:
			bodies += 1
			shapes += n
	return {"bodies_before": bodies, "shapes_before": shapes}


## 把每个参与单位碰撞的地面形状转成水平投影凸多边形 + 高度范围
static func collect(world: Node) -> Array:
	var out: Array = []
	for b: Node in world.find_children("*", "StaticBody3D", true, false):
		var sb := b as StaticBody3D
		if (sb.collision_layer & 1) == 0 or sb.is_in_group("lootboxes") or sb.is_in_group("nests") or sb.is_in_group("bugs"):
			continue
		var fixed := sb.get_script() != null
		for ch in sb.get_children():
			if not (ch is CollisionShape3D) or ch.disabled or ch.shape == null:
				continue
			var o := footprint(ch)
			if o.is_empty():
				continue
			if o.y1 < GROUND_EPS or o.y0 > UNIT_TOP or o.ext > HUGE_EXT:
				continue
			o["body"] = sb
			o["fixed"] = fixed
			out.append(o)
	return out


## 单个形状的投影：{cs, poly, y0, y1, ext, min_ext, rect}；不认识的形状类型返回空字典
static func footprint(cs: CollisionShape3D) -> Dictionary:
	var xf: Transform3D = cs.global_transform
	var sh: Shape3D = cs.shape
	var pts3: Array = []
	if sh is BoxShape3D:
		var h: Vector3 = (sh as BoxShape3D).size * 0.5
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					pts3.append(xf * Vector3(h.x * sx, h.y * sy, h.z * sz))
	elif sh is CylinderShape3D or sh is CapsuleShape3D or sh is SphereShape3D:
		var rad: float = sh.radius
		var hh: float = rad
		if sh is CylinderShape3D or sh is CapsuleShape3D:
			hh = sh.height * 0.5
		var k := 12
		for i in k:
			var a := TAU * i / k
			for sy in [-1.0, 1.0]:
				pts3.append(xf * Vector3(cos(a) * rad, hh * sy, sin(a) * rad))
	elif sh is ConvexPolygonShape3D:
		for p: Vector3 in (sh as ConvexPolygonShape3D).points:
			pts3.append(xf * p)
	else:
		return {}
	if pts3.is_empty():
		return {}
	var p2 := PackedVector2Array()
	var y0 := INF
	var y1 := -INF
	for p: Vector3 in pts3:
		p2.append(Vector2(p.x, p.z))
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var poly := _hull(p2)
	if poly.size() < 3:
		return {}
	var e := _obb_extents(poly)
	return {"cs": cs, "poly": poly, "y0": y0, "y1": y1, "ext": maxf(e.x, e.y), "min_ext": minf(e.x, e.y), "rect": _poly_rect(poly)}


static func _loot_points(raid) -> Array:
	var out: Array = []
	for b in raid.get_tree().get_nodes_in_group("lootboxes"):
		if b is Node3D and raid.world.is_ancestor_of(b):
			out.append(Vector2(b.global_position.x, b.global_position.z))
	return out


# ================================================================ 窄缝
## 候选对：外接矩形外扩 pad/2 后相交的形状对（16m 分桶）
static func _candidate_pairs(obs: Array, pad: float) -> Array:
	var grid := {}
	var cs := 16.0
	for i in obs.size():
		var r: Rect2 = obs[i].rect.grow(pad * 0.5)
		for gx in range(floori(r.position.x / cs), floori(r.end.x / cs) + 1):
			for gz in range(floori(r.position.y / cs), floori(r.end.y / cs) + 1):
				var key := Vector2i(gx, gz)
				if not grid.has(key):
					grid[key] = []
				grid[key].append(i)
	var seen := {}
	var out: Array = []
	for key in grid:
		var l: Array = grid[key]
		for a in l.size():
			for b in range(a + 1, l.size()):
				var i: int = mini(l[a], l[b])
				var j: int = maxi(l[a], l[b])
				var k := i * 1000003 + j
				if seen.has(k):
					continue
				seen[k] = true
				if obs[i].rect.grow(pad * 0.5).intersects(obs[j].rect.grow(pad * 0.5)):
					out.append(Vector2i(i, j))
	return out


## 两个凸多边形之间的最短距离：[距离, A 上最近点, B 上最近点]；相交时距离为 0
static func poly_gap(a: PackedVector2Array, b: PackedVector2Array) -> Array:
	if Geometry2D.is_point_in_polygon(a[0], b) or Geometry2D.is_point_in_polygon(b[0], a) or not Geometry2D.intersect_polygons(a, b).is_empty():
		return [0.0, a[0], a[0]]
	var best := INF
	var pa := Vector2.ZERO
	var pb := Vector2.ZERO
	for v: Vector2 in a:
		var q := closest_on_poly(v, b)
		var d := v.distance_to(q)
		if d < best:
			best = d
			pa = v
			pb = q
	for v: Vector2 in b:
		var q := closest_on_poly(v, a)
		var d := v.distance_to(q)
		if d < best:
			best = d
			pa = q
			pb = v
	return [best, pa, pb]


static func closest_on_poly(p: Vector2, poly: PackedVector2Array) -> Vector2:
	var best := INF
	var out := p
	var n := poly.size()
	for i in n:
		var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % n])
		var d := p.distance_squared_to(q)
		if d < best:
			best = d
			out = q
	return out


## 点到凸多边形的距离（在内部为 0）
static func dist_to_poly(p: Vector2, poly: PackedVector2Array) -> float:
	if Geometry2D.is_point_in_polygon(p, poly):
		return 0.0
	return p.distance_to(closest_on_poly(p, poly))


## 填缝凸体：靠近对方的顶点 + 它们在对方上的投影 + 两最近点之间的连接条，取凸包
static func _filler(A: Dictionary, B: Dictionary, gap: float, pa: Vector2, pb: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var reach := gap + FILL_REACH
	for pair in [[A.poly, B.poly], [B.poly, A.poly]]:
		var src: PackedVector2Array = pair[0]
		var dst: PackedVector2Array = pair[1]
		for v: Vector2 in src:
			var q := closest_on_poly(v, dst)
			if v.distance_to(q) < reach:
				pts.append(v)
				pts.append(q)
	var d := pb - pa
	if d.length() > 0.001:
		var dir := d.normalized()
		var perp := Vector2(-dir.y, dir.x)
		var half := clampf(minf(BRIDGE_HALF, minf(A.min_ext, B.min_ext) * 0.5), 0.12, BRIDGE_HALF)
		var a0 := pa - dir * 0.1
		var b0 := pb + dir * 0.1
		pts.append_array([a0 + perp * half, a0 - perp * half, b0 + perp * half, b0 - perp * half])
	var h := _hull(pts)
	if absf(_area(h)) < 0.02:
		return PackedVector2Array()
	return h


static func _near_loot(poly: PackedVector2Array, loot: Array, clear: float) -> bool:
	var r := _poly_rect(poly).grow(clear)
	for p: Vector2 in loot:
		if r.has_point(p) and dist_to_poly(p, poly) < clear:
			return true
	return false


# ================================================================ 搜刮箱可达性
## 返回撤掉的填缝（同时从 fillers 里删除）。
## 只有缝宽 ≥ 机甲直径的填缝才可能改变机甲能走到哪里（更窄的缝本来就过不去），所以只检查这些填缝附近的箱子
static func _protect_loot(obs: Array, fillers: Array, loot: Array) -> Array:
	var risky: Array = []
	for f: Dictionary in fillers:
		if f.gap >= UNIT_R * 2.0 - 0.05:
			risky.append(f)
	var removed: Array = []
	if risky.is_empty():
		return removed
	for lp: Vector2 in loot:
		var win := Rect2(lp - Vector2(LOOT_WIN, LOOT_WIN), Vector2(LOOT_WIN, LOOT_WIN) * 2.0)
		var near: Array = []
		for f: Dictionary in risky:
			if not f.has("dead") and win.intersects(f.rect):
				near.append(f)
		if near.is_empty():
			continue
		var base := raster_at(lp, obs)
		var active := range(near.size())
		var first := true
		while not active.is_empty():
			var grid := base.duplicate()
			grid.g = base.g.duplicate()
			for k: int in active:
				if not near[k].has("cells"):
					near[k]["cells"] = _cells_of(near[k].poly)
				_stamp(grid, near[k].cells)
			if escapes(grid, lp):
				break
			if first:
				first = false
				if not escapes(base, lp):
					break   # 填缝前就走不到（比如围墙院落的缺口本来就比机甲窄），保持原样
				near.sort_custom(func(x, y): return dist_to_poly(lp, x.poly) < dist_to_poly(lp, y.poly))
				continue
			var k0: int = active.pop_front()
			near[k0]["dead"] = true
			removed.append(near[k0])
	if not removed.is_empty():
		var keep: Array = fillers.filter(func(f): return not f.has("dead"))
		fillers.clear()
		fillers.append_array(keep)
	return removed


## 可达性栅格用的全局格子：原点 GO、每行 GN 格，覆盖 ±400m；每个多边形膨胀 UNIT_R 后覆盖的格子只算一次（缓存在 obs 条目的 cells 里）
const GO := Vector2(-400.0, -400.0)
const GN := 1600


## 以 lp 为中心、半宽 LOOT_WIN 的局部占用栅格：{g, nx, nz, gx0, gz0}；1 = 机甲中心不能到这里
static func raster_at(lp: Vector2, obs: Array) -> Dictionary:
	var gx0 := int((lp.x - LOOT_WIN - GO.x) / CELL)
	var gz0 := int((lp.y - LOOT_WIN - GO.y) / CELL)
	var n := int(LOOT_WIN * 2.0 / CELL)
	var g := PackedByteArray()
	g.resize(n * n)
	var grid := {"g": g, "nx": n, "nz": n, "gx0": gx0, "gz0": gz0}
	var win := Rect2(GO + Vector2(gx0, gz0) * CELL, Vector2(n, n) * CELL).grow(UNIT_R)
	for o: Dictionary in obs:
		if not win.intersects(o.rect):
			continue
		if not o.has("cells"):
			o["cells"] = _cells_of(o.poly)
		_stamp(grid, o.cells)
	return grid


static func _stamp(grid: Dictionary, cells: PackedInt32Array) -> void:
	var g: PackedByteArray = grid.g
	var nx: int = grid.nx
	var nz: int = grid.nz
	var gx0: int = grid.gx0
	var gz0: int = grid.gz0
	for idx: int in cells:
		var x := idx % GN - gx0
		var z := idx / GN - gz0
		if x >= 0 and z >= 0 and x < nx and z < nz:
			g[z * nx + x] = 1
	grid.g = g


## 膨胀 UNIT_R 后的多边形覆盖的全局格子下标。凸多边形膨胀后仍是凸的，逐行求与水平扫描线的交段直接填格子
static func _cells_of(poly: PackedVector2Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	var grown: Array = Geometry2D.offset_polygon(poly, UNIT_R, Geometry2D.JOIN_ROUND)
	for gp: PackedVector2Array in grown:
		var r := _poly_rect(gp)
		var z0 := maxi(0, int(ceil((r.position.y - GO.y) / CELL - 0.5)))
		var z1 := mini(GN - 1, int(floor((r.end.y - GO.y) / CELL - 0.5)))
		var n := gp.size()
		for z in range(z0, z1 + 1):
			var cz := GO.y + (z + 0.5) * CELL
			var xmin := INF
			var xmax := -INF
			for i in n:
				var a := gp[i]
				var b := gp[(i + 1) % n]
				if absf(b.y - a.y) < 1e-6:
					if absf(a.y - cz) < 1e-6:
						xmin = minf(xmin, minf(a.x, b.x))
						xmax = maxf(xmax, maxf(a.x, b.x))
					continue
				if (cz - a.y) * (cz - b.y) <= 0.0:
					var x := a.x + (cz - a.y) / (b.y - a.y) * (b.x - a.x)
					xmin = minf(xmin, x)
					xmax = maxf(xmax, x)
			if xmin > xmax:
				continue
			var x0 := maxi(0, int(ceil((xmin - GO.x) / CELL - 0.5)))
			var x1 := mini(GN - 1, int(floor((xmax - GO.x) / CELL - 0.5)))
			for x in range(x0, x1 + 1):
				out.append(z * GN + x)
	return out


## 从搜刮箱交互圈内的空格出发洪泛，能到窗口边缘 = 走得到
static func escapes(grid: Dictionary, lp: Vector2) -> bool:
	var g: PackedByteArray = grid.g
	var nx: int = grid.nx
	var nz: int = grid.nz
	var org := GO + Vector2(grid.gx0, grid.gz0) * CELL
	var seen := PackedByteArray()
	seen.resize(nx * nz)
	var stack := PackedInt32Array()
	stack.resize(nx * nz)
	var top := 0
	var cr := int(ceil(LOOT_REACH / CELL))
	var cx := int((lp.x - org.x) / CELL)
	var cz := int((lp.y - org.y) / CELL)
	for z in range(cz - cr, cz + cr + 1):
		for x in range(cx - cr, cx + cr + 1):
			if x < 0 or z < 0 or x >= nx or z >= nz:
				continue
			var c := org + Vector2((x + 0.5) * CELL, (z + 0.5) * CELL)
			if c.distance_to(lp) <= LOOT_REACH and g[z * nx + x] == 0:
				seen[z * nx + x] = 1
				stack[top] = z * nx + x
				top += 1
	while top > 0:
		top -= 1
		var i: int = stack[top]
		var x := i % nx
		var z := i / nx
		if x == 0 or z == 0 or x == nx - 1 or z == nz - 1:
			return true
		var j := i - 1
		if seen[j] == 0 and g[j] == 0:
			seen[j] = 1; stack[top] = j; top += 1
		j = i + 1
		if seen[j] == 0 and g[j] == 0:
			seen[j] = 1; stack[top] = j; top += 1
		j = i - nx
		if seen[j] == 0 and g[j] == 0:
			seen[j] = 1; stack[top] = j; top += 1
		j = i + nx
		if seen[j] == 0 and g[j] == 0:
			seen[j] = 1; stack[top] = j; top += 1
	return false


# ================================================================ 生成
static func _new_body(world: Node, layer: int) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = "MergedObstacle"
	b.collision_layer = layer if layer != 0 else 1
	b.collision_mask = 0
	b.set_meta("collision_opt", true)
	world.add_child(b)
	return b


## 竖直棱柱（凸）：poly 为水平投影，y0~y1 为高度
static func _add_prism(body: StaticBody3D, poly: PackedVector2Array, y0: float, y1: float) -> void:
	var pts := PackedVector3Array()
	for p: Vector2 in poly:
		pts.append(Vector3(p.x, y0, p.y))
		pts.append(Vector3(p.x, maxf(y1, y0 + 0.2), p.y))
	var sh := ConvexPolygonShape3D.new()
	sh.points = pts
	var cs := CollisionShape3D.new()
	cs.shape = sh
	body.add_child(cs)


## 新填缝 / 凸包里如果正好站着虫子或 NPC 机甲（地图生成时刷的），推到外面
static func _push_units_out(raid, polys: Array) -> void:
	if polys.is_empty():
		return
	var units: Array = raid.get_tree().get_nodes_in_group("bugs") + raid.get_tree().get_nodes_in_group("npc_mechs")
	for u in units:
		if not (u is Node3D) or not raid.world.is_ancestor_of(u):
			continue
		var p := Vector2(u.global_position.x, u.global_position.z)
		var rad := 1.0
		if "data" in u and u.data is Dictionary:
			rad = float(u.data.get("radius", 1.0))
		for poly: PackedVector2Array in polys:
			if dist_to_poly(p, poly) >= rad:
				continue
			var q := closest_on_poly(p, poly)
			var c := _centroid(poly)
			var dir := (q - c).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			p = q + dir * (rad + 0.3)
			u.global_position = Vector3(p.x, u.global_position.y, p.y)


# ================================================================ 几何小工具
static func _hull(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var h := Geometry2D.convex_hull(pts)
	if h.size() > 1 and h[0].is_equal_approx(h[h.size() - 1]):
		h.remove_at(h.size() - 1)
	return h


static func _area(poly: PackedVector2Array) -> float:
	var s := 0.0
	var n := poly.size()
	for i in n:
		s += poly[i].cross(poly[(i + 1) % n])
	return s * 0.5


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	return c / maxf(1.0, poly.size())


static func _poly_rect(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


## 最小面积外接矩形的两条边长（凸多边形，逐边旋转卡壳）
static func _obb_extents(poly: PackedVector2Array) -> Vector2:
	var best := Vector2(INF, INF)
	var n := poly.size()
	for i in n:
		var e := poly[(i + 1) % n] - poly[i]
		if e.length_squared() < 1e-8:
			continue
		var u := e.normalized()
		var v := Vector2(-u.y, u.x)
		var mnu := INF
		var mxu := -INF
		var mnv := INF
		var mxv := -INF
		for p in poly:
			mnu = minf(mnu, p.dot(u)); mxu = maxf(mxu, p.dot(u))
			mnv = minf(mnv, p.dot(v)); mxv = maxf(mxv, p.dot(v))
		var s := Vector2(mxu - mnu, mxv - mnv)
		if s.x * s.y < best.x * best.y:
			best = s
	return best


## 凸包内被成员 / 填缝覆盖的比例（0.7m 采样）
static func _fill_ratio(hull: PackedVector2Array, polys: Array) -> float:
	var r := _poly_rect(hull)
	var tot := 0
	var hit := 0
	var st := 0.7
	var y := r.position.y + st * 0.5
	while y < r.end.y:
		var x := r.position.x + st * 0.5
		while x < r.end.x:
			var p := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(p, hull):
				tot += 1
				for poly: PackedVector2Array in polys:
					if Geometry2D.is_point_in_polygon(p, poly):
						hit += 1
						break
			x += st
		y += st
	return float(hit) / maxf(1.0, tot)


static func _find(parent: Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func _union(parent: Array, a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[ra] = rb
