extends RefCounted
## 战区导航网格：地图建完后从物理世界里真实存在的静态碰撞体栅格化出来（不假设道路 / 街区是网格），
## 供虫群、流浪者与队友绕开建筑寻路。地图生成或碰撞后处理换了布局，只要调用 raid.rebuild_nav() 重新栅格化即可。
##
## 栅格化：遍历 raid 下所有 StaticBody3D / AnimatableBody3D 的 CollisionShape3D（只看碰撞层 1 = 地形建筑、8 = 只挡机甲的河岸），
##   盒子按朝向包围盒（OBB）、圆柱 / 胶囊 / 球按圆、其它形状按调试网格的包围盒，算出每个格子中心到形状的距离；
##   距离 < 单位半径（R_BUG / R_MECH）的格子记为不可走 —— 这就是「按单位半径腐蚀」的通行间隙。
##   竖直方向只算挡在 BLOCK_MIN_Y ~ BLOCK_MAX_Y 之间的形状：地面、路沿、低矮踏板能踩过去，悬空构件不挡路。
## 两张网格：bug（虫子：层 1，间隙 0.8 米）与 mech（机甲：层 1 + 8，间隙 1.15 米），各自一个 AStarGrid2D（C++ 实现，单次寻路很便宜）。
## 寻路预算：每个物理帧最多算 PATHS_PER_FRAME 条新路径，超出的请求返回 null 让调用方下一帧再来（150+ 只虫同时重算也不会卡帧）；
##   同一起点格 → 终点格的结果缓存约 1 秒（同群挤在一起的虫会命中缓存）。

const CELL := 1.5              ## 格子边长（米）
const R_BUG := 0.8             ## 虫子的通行间隙：格心离障碍不足这个距离就不可走（0.8 保证 0.25 米的薄墙也一定落到格心上）
const R_MECH := 1.15           ## 机甲的通行间隙（机甲胶囊半径 1.0）
const BLOCK_MIN_Y := 0.35      ## 顶面低于这个高度的形状（地面、路沿）不挡路
const BLOCK_MAX_Y := 1.8       ## 底面高于这个高度的形状（悬空构件）不挡路
const EDGE := 4.0              ## 地图边缘这一圈不可走（单位本来就被限制在 HALF - 4 以内）
const PATHS_PER_FRAME := 6
const CACHE_FRAMES := 60

var half := 180.0
var n := 240                   ## 每边格子数
var origin := Vector2(-180, -180)
var solid_bug := PackedByteArray()
var solid_mech := PackedByteArray()
var astar_bug: AStarGrid2D
var astar_mech: AStarGrid2D
var build_ms := 0.0
var shape_count := 0
var paths_computed := 0        ## 统计：累计真正跑过的 A* 次数（测试 / 性能日志用）

var _cache := {}
var _budget_frame := -1
var _budget := 0


## 从 root（raid）下的静态碰撞体建网格
func build(root: Node, half_size: float) -> void:
	var t0 := Time.get_ticks_usec()
	half = half_size
	n = int(ceil(half * 2.0 / CELL))
	origin = Vector2(-half, -half)
	var dist_bug := PackedFloat32Array()
	var dist_mech := PackedFloat32Array()
	dist_bug.resize(n * n)
	dist_mech.resize(n * n)
	dist_bug.fill(99.0)
	dist_mech.fill(99.0)
	shape_count = 0
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for ch in node.get_children():
			if ch is CharacterBody3D or ch is RigidBody3D or ch is Area3D:
				continue   # 会动的单位、触发区不进导航
			if ch is StaticBody3D or ch is AnimatableBody3D:
				var layer: int = ch.collision_layer
				if layer & (1 | 8):
					for cs in ch.get_children():
						if cs is CollisionShape3D and not cs.disabled and cs.shape != null:
							_raster(cs, (layer & 1) != 0, dist_bug, dist_mech)
			if ch.get_child_count() > 0:
				stack.append(ch)
	solid_bug.resize(n * n)
	solid_mech.resize(n * n)
	var edge_c := int(ceil(EDGE / CELL))
	for j in n:
		for i in n:
			var k := j * n + i
			var border := i < edge_c or j < edge_c or i >= n - edge_c or j >= n - edge_c
			solid_bug[k] = 1 if (border or dist_bug[k] < R_BUG) else 0
			solid_mech[k] = 1 if (border or dist_mech[k] < R_MECH) else 0
	astar_bug = _make_astar(solid_bug)
	astar_mech = _make_astar(solid_mech)
	_cache.clear()
	build_ms = (Time.get_ticks_usec() - t0) / 1000.0


func _make_astar(solid: PackedByteArray) -> AStarGrid2D:
	var a := AStarGrid2D.new()
	a.region = Rect2i(0, 0, n, n)
	a.cell_size = Vector2(CELL, CELL)
	a.offset = origin + Vector2(CELL, CELL) * 0.5   # get_point_path 直接给出格心的世界 XZ 坐标
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES   # 不切墙角
	a.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	a.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	a.jumping_enabled = true   # 跳点搜索：开阔地上快一个数量级
	a.update()
	# 按行合并成连续区段批量置为障碍，比逐格调用快
	for j in n:
		var run0 := -1
		for i in n + 1:
			var s: bool = i < n and solid[j * n + i] != 0
			if s and run0 < 0:
				run0 = i
			elif not s and run0 >= 0:
				a.fill_solid_region(Rect2i(run0, j, i - run0, 1), true)
				run0 = -1
	return a


## 把一个碰撞形状写进距离场（只记录 R_MECH 以内的距离，够判断两种间隙就行）
func _raster(cs: CollisionShape3D, both: bool, dist_bug: PackedFloat32Array, dist_mech: PackedFloat32Array) -> void:
	var xf: Transform3D = cs.global_transform
	var sh: Shape3D = cs.shape
	var b := xf.basis
	var upright: bool = b.y.normalized().y > 0.97
	var kind := 0          # 0 = OBB，1 = 圆
	var c := Vector2(xf.origin.x, xf.origin.z)
	var u := Vector2(1, 0)
	var v := Vector2(0, 1)
	var hu := 0.0
	var hv := 0.0
	var rad := 0.0
	var y0 := 0.0
	var y1 := 0.0
	if sh is BoxShape3D and upright:
		var e: Vector3 = (sh as BoxShape3D).size * 0.5
		var ax := Vector2(b.x.x, b.x.z) * e.x
		var az := Vector2(b.z.x, b.z.z) * e.z
		hu = ax.length()
		hv = az.length()
		if hu < 0.001 or hv < 0.001:
			return
		u = ax / hu
		v = az / hv
		var hy: float = absf(b.y.y) * e.y
		y0 = xf.origin.y - hy
		y1 = xf.origin.y + hy
	elif (sh is CylinderShape3D or sh is CapsuleShape3D or sh is SphereShape3D) and upright:
		kind = 1
		var s := maxf(Vector2(b.x.x, b.x.z).length(), Vector2(b.z.x, b.z.z).length())
		var hy := 0.0
		if sh is CylinderShape3D:
			rad = (sh as CylinderShape3D).radius
			hy = (sh as CylinderShape3D).height * 0.5
		elif sh is CapsuleShape3D:
			rad = (sh as CapsuleShape3D).radius
			hy = (sh as CapsuleShape3D).height * 0.5
		else:
			rad = (sh as SphereShape3D).radius
			hy = rad
		rad *= s
		hy *= absf(b.y.y)
		y0 = xf.origin.y - hy
		y1 = xf.origin.y + hy
	else:
		# 倾斜的形状或其它类型：用世界包围盒的投影（偏保守）
		var bb: AABB
		if sh is BoxShape3D:
			var sz: Vector3 = (sh as BoxShape3D).size
			bb = xf * AABB(-sz * 0.5, sz)
		else:
			var dm: ArrayMesh = sh.get_debug_mesh()
			if dm == null:
				return
			bb = xf * dm.get_aabb()
		c = Vector2(bb.get_center().x, bb.get_center().z)
		hu = bb.size.x * 0.5
		hv = bb.size.z * 0.5
		y0 = bb.position.y
		y1 = bb.end.y
	if y1 < BLOCK_MIN_Y or y0 > BLOCK_MAX_Y:
		return
	shape_count += 1
	# 包围范围（加上最大间隙）
	var ext := 0.0
	if kind == 1:
		ext = rad
	else:
		ext = absf(u.x) * hu + absf(v.x) * hv
	var ext_z := rad if kind == 1 else absf(u.y) * hu + absf(v.y) * hv
	var i0 := maxi(0, floori((c.x - ext - R_MECH - origin.x) / CELL))
	var i1 := mini(n - 1, floori((c.x + ext + R_MECH - origin.x) / CELL))
	var j0 := maxi(0, floori((c.y - ext_z - R_MECH - origin.y) / CELL))
	var j1 := mini(n - 1, floori((c.y + ext_z + R_MECH - origin.y) / CELL))
	for j in range(j0, j1 + 1):
		var pz := origin.y + (j + 0.5) * CELL - c.y
		for i in range(i0, i1 + 1):
			var px := origin.x + (i + 0.5) * CELL - c.x
			var d: float
			if kind == 1:
				d = sqrt(px * px + pz * pz) - rad
			else:
				var du := absf(px * u.x + pz * u.y) - hu
				var dv := absf(px * v.x + pz * v.y) - hv
				if du > 0.0 and dv > 0.0:
					d = sqrt(du * du + dv * dv)
				else:
					d = maxf(du, dv)
			if d < R_MECH:
				var k := j * n + i
				if d < dist_mech[k]:
					dist_mech[k] = d
				if both and d < dist_bug[k]:
					dist_bug[k] = d


# ---------- 查询 ----------
func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / CELL), floori((p.z - origin.y) / CELL))


func cell_center(c: Vector2i) -> Vector3:
	return Vector3(origin.x + (c.x + 0.5) * CELL, 0.0, origin.y + (c.y + 0.5) * CELL)


func _solid_c(c: Vector2i, mech: bool) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= n or c.y >= n:
		return true
	return (solid_mech if mech else solid_bug)[c.y * n + c.x] != 0


## 这个点（按单位间隙）能不能站
func is_free(p: Vector3, mech := false) -> bool:
	return not _solid_c(cell_of(p), mech)


## 两点之间能否直线走过去（沿线每半格采样一次）。起点本身贴墙（格子被间隙判成不可走）时，前 1.5 米内的障碍格忽略，
## 不然贴墙的单位永远判不出直线可走
func line_clear(a: Vector3, b: Vector3, mech := false) -> bool:
	var d := Vector2(b.x - a.x, b.z - a.z)
	var L := d.length()
	var steps := int(ceil(L / (CELL * 0.5)))
	if steps <= 0:
		return true
	var grace := 1.5
	var arr := solid_mech if mech else solid_bug
	for s in steps + 1:
		var t := float(s) / steps
		var x := a.x + d.x * t
		var z := a.z + d.y * t
		var ci := floori((x - origin.x) / CELL)
		var cj := floori((z - origin.y) / CELL)
		if ci < 0 or cj < 0 or ci >= n or cj >= n:
			return false
		if arr[cj * n + ci] != 0:
			if L * t <= grace:
				continue
			return false
		grace = -1.0   # 一旦走进可走格子，后面再碰到障碍就算挡住
	return true


## 离 c 最近的可走格（环形向外找，最多 rmax 圈）；找不到返回 (-1, -1)
func nearest_free(c: Vector2i, mech := false, rmax := 4) -> Vector2i:
	if not _solid_c(c, mech):
		return c
	for r in range(1, rmax + 1):
		var best := Vector2i(-1, -1)
		var bd := 1e9
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := Vector2i(c.x + dx, c.y + dy)
				if not _solid_c(q, mech):
					var dd := float(dx * dx + dy * dy)
					if dd < bd:
						bd = dd
						best = q
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


## 申请一条从 from 到 to 的路径（世界坐标折线，不含起点，已做拉直）。
## 本帧寻路预算用完时返回 null（调用方下一帧再来）；到不了时返回到达最接近终点处的部分路径，完全无路返回空数组
func request_path(from: Vector3, to: Vector3, mech := false):
	var c0 := nearest_free(cell_of(from), mech)
	var c1 := nearest_free(cell_of(to), mech, 6)
	if c0.x < 0:
		return PackedVector3Array()
	if c1.x < 0:
		c1 = cell_of(to)
		c1 = Vector2i(clampi(c1.x, 0, n - 1), clampi(c1.y, 0, n - 1))
	var key: int = (((c0.y * n + c0.x) << 17) | (c1.y * n + c1.x)) * 2 + (1 if mech else 0)
	var f := Engine.get_physics_frames()
	var hit = _cache.get(key)
	if hit != null and f - int(hit[0]) < CACHE_FRAMES:
		return hit[1]
	if f != _budget_frame:
		_budget_frame = f
		_budget = PATHS_PER_FRAME
	if _budget <= 0:
		return null
	_budget -= 1
	paths_computed += 1
	var a: AStarGrid2D = astar_mech if mech else astar_bug
	var raw: PackedVector2Array = a.get_point_path(c0, c1, true)
	var pts := PackedVector3Array()
	for q in raw:
		pts.append(Vector3(q.x, 0.0, q.y))
	pts = _smooth(from, pts, mech)
	if _cache.size() > 600:
		_cache.clear()
	_cache[key] = [f, pts]
	return pts


## 拉直：从当前点出发，跳到最远的、直线可达的路点（最多往前看 12 个）
func _smooth(from: Vector3, pts: PackedVector3Array, mech: bool) -> PackedVector3Array:
	if pts.size() <= 2:
		return pts
	var out := PackedVector3Array()
	var cur := from
	var i := 0
	while i < pts.size():
		var best := i
		var lim := mini(pts.size() - 1, i + 12)
		for j in range(lim, i, -1):
			if line_clear(cur, pts[j], mech):
				best = j
				break
		out.append(pts[best])
		cur = pts[best]
		i = best + 1
	return out


# ---------- 寻路跟随器：每个单位一份 ----------
## 用法：dir = agent.steer(raid.nav, 自己位置, 目标点, delta, 是否机甲, 重算周期)
## 直线可走（格子上无障碍）时直接朝目标；否则沿 A* 折线走。重算按周期 × 随机系数错开，目标移动 3 米以上或卡住时提前重算
class Agent:
	var path := PackedVector3Array()
	var idx := 0
	var timer := 0.0
	var goal := Vector3.INF
	var direct := true
	var force_path := false    ## 卡住时置位：网格说直线可走、但物理上过不去（网格外的碰撞），改走 A*

	func reset() -> void:
		path = PackedVector3Array()
		idx = 0
		timer = 0.0
		goal = Vector3.INF
		direct = true
		force_path = false

	## 卡住了：下一帧重算，并且这一轮不信任直线
	func stuck() -> void:
		timer = 0.0
		force_path = true

	func steer(nav, pos: Vector3, to: Vector3, delta: float, mech: bool, period: float) -> Vector3:
		var w := Vector3(to.x - pos.x, 0.0, to.z - pos.z)
		if nav == null or w.length_squared() < 0.04:
			return w.normalized() if w.length_squared() > 0.0001 else Vector3.ZERO
		timer -= delta
		var moved := goal == Vector3.INF or Vector2(goal.x - to.x, goal.z - to.z).length_squared() > 9.0
		if timer <= 0.0 or (moved and not direct):
			direct = not force_path and nav.line_clear(pos, to, mech)
			if direct:
				path = PackedVector3Array()
				goal = to
				timer = period * randf_range(0.8, 1.2)
			else:
				var p = nav.request_path(pos, to, mech)
				if p == null:
					timer = 0.0          # 本帧预算用完：先沿旧路 / 直线走，下一帧再申请
				else:
					path = p
					idx = 0
					goal = to
					force_path = false
					timer = period * randf_range(0.8, 1.2)
		if direct or path.is_empty():
			return w.normalized()
		while idx < path.size():
			var q: Vector3 = path[idx]
			if Vector2(q.x - pos.x, q.z - pos.z).length_squared() > 1.44:
				break
			idx += 1
		if idx >= path.size():
			return w.normalized()
		var s: Vector3 = path[idx] - pos
		s.y = 0.0
		return s.normalized() if s.length_squared() > 0.0001 else w.normalized()
