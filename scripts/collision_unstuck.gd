extends Node
## 玩家机甲防卡死（collision_opt.gd 挂到 raid 下，不改 mech.gd）。
## 判定：按着移动键 WINDOW 秒内水平位移 < MIN_PROGRESS，且满足下列之一：
##   a) 机甲胶囊（略缩小）与静态地形重叠 —— 被挤进 / 冲进了几何体里
##   b) 八个方向都被静态地形挡住 —— 卡在窄缝 / 凹口里
##   c) 输入方向上静态地形与单位都不挡，机甲却不动 —— 被棱角勾住
## 只是顶着一面墙走（侧向能走）不算卡住；被虫子围住（单位挡路）也不算。
## 处理：a / b 在周围由近到远找一个胶囊放得下的空位（同距离优先输入方向）瞬移过去；c 沿输入方向挪一小步。

const Prof = preload("res://scripts/prof.gd")

const WINDOW := 0.6
const MIN_PROGRESS := 0.25
const STATIC_MASK := 1 | 8          ## 地形（1）+ 只挡机甲的河岸（8）
const R := 1.0                      ## 机甲胶囊半径 / 高度（mech.gd）
const H := 2.8
const LIFT := 0.3                   ## 查询胶囊抬离地面，避免碰到地面盒
const PROBE := 0.4                  ## 方向探测的位移
const SEARCH_MAX := 6.0             ## 找空位的最大半径

var raid
var nudges := 0                     ## 统计：触发次数
var last_kind := ""
var _hist: Array = []               ## [时间, 位置]
var _t := 0.0
var _cool := 0.0
var _cap: CapsuleShape3D        ## 找空位用：比机甲大 0.05，挪过去后不会还贴着几何体
var _cap_overlap: CapsuleShape3D  ## 重叠判定：比机甲小 0.02，嵌进去超过 2cm 才算
var _cap_small: CapsuleShape3D    ## 方向探测：比机甲小 0.08，贴着墙也能探测平行方向


func _ready() -> void:
	_cap = CapsuleShape3D.new()
	_cap.radius = R + 0.05
	_cap.height = H - LIFT
	_cap_overlap = CapsuleShape3D.new()
	_cap_overlap.radius = R - 0.02
	_cap_overlap.height = H - LIFT - 0.04
	_cap_small = CapsuleShape3D.new()
	_cap_small.radius = R - 0.08
	_cap_small.height = H - LIFT - 0.16


func _physics_process(delta: float) -> void:
	var _pt := Prof.t0()
	_physics_tick(delta)
	Prof.add("phys.unstuck", _pt)


func _physics_tick(dt: float) -> void:
	var m = raid.mech if raid else null
	if m == null or not is_instance_valid(m) or m.dead or m.input_locked or raid.dropping or m.dash_time > 0.0 or not m.is_inside_tree():
		_hist.clear()
		return
	var mv := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	if mv.length() < 0.1:
		_hist.clear()
		return
	mv = mv.normalized()
	_t += dt
	_cool -= dt
	var pos: Vector3 = m.global_position
	_hist.append([_t, pos])
	while _hist.size() > 1 and _t - _hist[1][0] >= WINDOW:
		_hist.pop_front()
	if _t - _hist[0][0] < WINDOW - 0.001 or _cool > 0.0:
		return
	var p0: Vector3 = _hist[0][1]
	if Vector2(pos.x - p0.x, pos.z - p0.z).length() > MIN_PROGRESS:
		return
	var kind := classify(m, mv)
	if kind == "":
		return
	var target = null
	if kind == "snag":
		var step := Vector3(mv.x, 0, mv.y) * 0.5
		if _free(m, pos + step, _cap):
			target = pos + step
	else:
		target = find_free(m, pos, mv)
	if target == null:
		return
	m.global_position = Vector3(target.x, pos.y, target.z)
	m.velocity = Vector3.ZERO
	nudges += 1
	last_kind = kind
	_hist.clear()
	_cool = 0.5


## 卡住类型："overlap" / "wedged" / "snag"；没卡住返回 ""
func classify(m, mv: Vector2) -> String:
	var pos: Vector3 = m.global_position
	if not _free(m, pos, _cap_overlap):
		return "overlap"
	var blocked := 0
	var input_free := false
	for i in 8:
		var a := TAU * i / 8.0
		var d := Vector3(cos(a), 0, sin(a))
		if not _motion_free(m, pos, d * PROBE):
			blocked += 1
	if blocked == 8:
		return "wedged"
	var dir := Vector3(mv.x, 0, mv.y)
	input_free = _motion_free(m, pos, dir * PROBE)
	# 机甲本身能走（超重 / 减速时期望速度很低，不算勾住）
	var want_speed: float = float(m.stats.get("speed", 0.0)) * float(m.speed_mult())
	if input_free and want_speed > 1.5 and not m.test_move(m.global_transform, dir * PROBE):
		return "snag"
	return ""


## 由近到远找空位：同一圈里取最贴近输入方向的
func find_free(m, pos: Vector3, mv: Vector2):
	var r := 0.4
	while r <= SEARCH_MAX:
		var best = null
		var bd := -INF
		var n := 16 if r < 3.0 else 24
		for i in n:
			var a := TAU * i / n
			var d := Vector2(cos(a), sin(a))
			var p := pos + Vector3(d.x, 0, d.y) * r
			if _free(m, p, _cap):
				var s := d.dot(mv)
				if s > bd:
					bd = s
					best = p
		if best != null:
			return best
		r += 0.4
	return null


func _query(m, pos: Vector3, shape: Shape3D) -> PhysicsShapeQueryParameters3D:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, pos + Vector3(0, LIFT + (H - LIFT) * 0.5, 0))
	q.collision_mask = STATIC_MASK
	q.exclude = [m.get_rid()]
	q.collide_with_areas = false
	return q


func _free(m, pos: Vector3, shape: Shape3D) -> bool:
	return m.get_world_3d().direct_space_state.intersect_shape(_query(m, pos, shape), 1).is_empty()


func _motion_free(m, pos: Vector3, motion: Vector3) -> bool:
	var q := _query(m, pos, _cap_small)
	q.motion = motion
	var r: PackedFloat32Array = m.get_world_3d().direct_space_state.cast_motion(q)
	return r.size() == 0 or r[0] >= 0.999
