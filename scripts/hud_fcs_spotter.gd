extends Control
## 火控光学自动标定系统（FCS Auto-Spotter）：
## - 敌对生物（虫族 / 流浪者机甲）与未搜空物资箱进入玩家视野且满足侦察有效距离与通视条件满 2.0s 后，
##   自动触发火控标定：从目标投影中心向四周平滑展开 4 条橙黄色直角边至物体实时边缘，并持续实时追踪移动。
## - 有效标定距离直接与整机侦察属性（stats.recon / recon_tag）及右键光学瞄准状态联动。

const LootScript = preload("res://scripts/loot_box.gd")

const SPOT_DELAY := 2.0            ## 目标持续留在视野中触发标定的时间（秒）
const EXPAND_DUR := 0.45           ## 4 条直角边从中心展开到物体边缘的动画时长（秒）
const GRACE_PRE := 0.35            ## 标定前短暂遮挡宽限（秒），避免路灯/柱子瞬闪清零计时
const FADE_OUT_DUR := 0.42         ## 目标脱离视野/超出侦察距离后的平滑淡出时长（秒）
const MAX_DRAWN := 24              ## 同屏最多绘制标定框上限（按距离优先）
const LOS_BUDGET_PER_FRAME := 16   ## 每帧分摊视线检测上限，保持 60FPS 零掉帧

const BASE_SPOT_RANGE := 55.0      ## recon=0 时的基础火控光学标定距离（米）
const RANGE_PER_RECON := 12.0      ## 每点侦察属性提供的额外标定距离（米）
const RECON_TAG_BONUS := 8.0       ## 装备含 [侦察] 标签组件时的额外标定距离（米）
const ADS_RANGE_MULT := 1.25       ## 右键开启光学瞄准时的远距标定增益倍率
const MAX_SPOT_RANGE := 210.0      ## 绝对距离封顶

const COL_ENEMY := Color(1.00, 0.64, 0.14, 0.95)     ## 敌对生物：锐利军工橙黄
const COL_LOOT := Color(1.00, 0.76, 0.22, 0.90)      ## 物资箱：明亮琥珀橙黄
const COL_FLASH := Color(1.00, 0.94, 0.66, 0.98)     ## 展开瞬间高亮锁定闪光
const COL_SHADOW := Color(0.02, 0.02, 0.02, 0.65)

var raid
var hud
var _entries: Dictionary = {}       ## instance_id -> tracking dict
var _draw_list: Array = []
var _los_cursor := 0
var _los_ray_q: PhysicsRayQueryParameters3D = null
var _los_exclude: Array[RID] = []
var _scan_acc := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 5


## 根据玩家机甲当前侦察属性（stats.recon / recon_tag）与瞄准状态计算实时火控有效标定距离（米）
func fcs_spot_range() -> float:
	if raid == null or raid.mech == null or not is_instance_valid(raid.mech):
		return BASE_SPOT_RANGE
	var m = raid.mech
	var recon := 0.0
	var has_tag := false
	if m.get("stats") is Dictionary:
		recon = float(m.stats.get("recon", 0.0))
		has_tag = bool(m.stats.get("recon_tag", false))
	var r := BASE_SPOT_RANGE + recon * RANGE_PER_RECON + (RECON_TAG_BONUS if has_tag else 0.0)
	if bool(m.get("is_aiming")):
		r *= ADS_RANGE_MULT
	return clampf(r, BASE_SPOT_RANGE, MAX_SPOT_RANGE)


## 供测试脚本或调试读取当前已展开标定的目标数量与条目快照
func spotted_count() -> int:
	var c := 0
	for e_v in _entries.values():
		var e: Dictionary = e_v as Dictionary
		if bool(e.get("spotted", false)) and float(e.get("fade", 0.0)) > 0.05:
			c += 1
	return c


func _measure_local_bounds(node: Node3D, kind_t: String) -> Array:
	# 返回 [half_x, y_min, y_max, half_z]，严格在节点本地坐标系下缓存一次，零逐帧树遍历开销
	if kind_t == "loot":
		var lk := str(node.get("kind"))
		var st_d: Dictionary = LootScript.STYLE.get(lk, {})
		var sz: Vector3 = st_d.get("size", Vector3(1.4, 0.85, 1.0)) as Vector3
		var sink := 0.0 if (lk == "bug" or lk == "nest") else 0.12
		return [maxf(0.45, sz.x * 0.54), maxf(0.0, -sink), maxf(0.55, sz.y - sink + 0.10), maxf(0.45, sz.z * 0.54)]
	if kind_t == "rover":
		return [1.85, 0.0, 5.55, 1.85]
	# 敌对生物（虫族 / 首领）：优先采样可见网格实际包围盒，兜底按 data.radius / scale 推算
	var d = node.get("data")
	var rad := float(d.get("radius", 0.8)) if d is Dictionary else 0.8
	var sc := float(d.get("scale", 1.0)) if d is Dictionary else 1.0
	var vis = node.get("visual")
	if vis is Node3D and is_instance_valid(vis) and node.is_inside_tree() and (vis as Node3D).is_inside_tree():
		var inv_n: Transform3D = node.global_transform.affine_inverse()
		var lo := Vector3(1e9, 1e9, 1e9)
		var hi := Vector3(-1e9, -1e9, -1e9)
		var found := false
		var stack: Array[Node] = [vis as Node]
		while not stack.is_empty():
			var cur: Node = stack.pop_back()
			if cur is MeshInstance3D:
				var mi := cur as MeshInstance3D
				if mi.visible and mi.mesh != null and not (mi.mesh is PlaneMesh):
					var ab: AABB = mi.get_aabb()
					var xf: Transform3D = inv_n * mi.global_transform
					for ci in 8:
						var pt := xf * ab.get_endpoint(ci)
						lo.x = minf(lo.x, pt.x)
						lo.y = minf(lo.y, pt.y)
						lo.z = minf(lo.z, pt.z)
						hi.x = maxf(hi.x, pt.x)
						hi.y = maxf(hi.y, pt.y)
						hi.z = maxf(hi.z, pt.z)
					found = true
			for ch in cur.get_children():
				stack.append(ch)
		if found and hi.y > lo.y + 0.15:
			var hx := clampf(maxf(absf(lo.x), absf(hi.x)), rad * 0.65, maxf(rad * 2.4, 2.2 * sc))
			var hz := clampf(maxf(absf(lo.z), absf(hi.z)), rad * 0.65, maxf(rad * 2.4, 2.2 * sc))
			return [hx, clampf(lo.y, -0.2, 0.5), clampf(hi.y, 0.75, maxf(2.6 * sc, 2.2)), hz]
	var hr := maxf(0.65, rad * 1.15)
	return [hr, 0.0, clampf(1.35 * sc, 0.95, 7.5), hr]


func _target_center_w(node: Node3D, bounds: Array) -> Vector3:
	var y_mid := (float(bounds[1]) + float(bounds[2])) * 0.5
	return node.global_position + Vector3(0.0, y_mid, 0.0)


func _project_bounds_rect(cam: Camera3D, node: Node3D, bounds: Array, vp_sz: Vector2) -> Rect2:
	var hx: float = float(bounds[0])
	var y0: float = float(bounds[1])
	var y1: float = float(bounds[2])
	var hz: float = float(bounds[3])
	var pos: Vector3 = node.global_position
	var b: Basis = node.global_transform.basis
	var ax := Vector3(b.x.x, 0.0, b.x.z)
	ax = ax.normalized() if ax.length_squared() > 0.001 else Vector3.RIGHT
	var az := Vector3(b.z.x, 0.0, b.z.z)
	az = az.normalized() if az.length_squared() > 0.001 else Vector3.BACK
	var min_x := 1e9
	var min_y := 1e9
	var max_x := -1e9
	var max_y := -1e9
	var valid_pts := 0
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var base_p := pos + ax * (sx * hx) + az * (sz * hz)
			for yy: float in [y0, y1]:
				var wp := base_p + Vector3(0.0, yy, 0.0)
				if cam.is_position_behind(wp):
					continue
				var sp := cam.unproject_position(wp)
				min_x = minf(min_x, sp.x)
				min_y = minf(min_y, sp.y)
				max_x = maxf(max_x, sp.x)
				max_y = maxf(max_y, sp.y)
				valid_pts += 1
	if valid_pts == 0:
		return Rect2()
	# 适度外扩 4px 贴紧物体边缘，并夹紧最小/最大框尺寸确保远距清晰、贴脸不遮屏
	var pad := 4.0
	min_x -= pad
	min_y -= pad
	max_x += pad
	max_y += pad
	var cx := (min_x + max_x) * 0.5
	var cy := (min_y + max_y) * 0.5
	var w := clampf(max_x - min_x, 22.0, vp_sz.x * 0.48)
	var h := clampf(max_y - min_y, 22.0, vp_sz.y * 0.56)
	return Rect2(cx - w * 0.5, cy - h * 0.5, w, h)


func _check_los(space: PhysicsDirectSpaceState3D, eye: Vector3, target_w: Vector3, target_node: Node3D) -> bool:
	if space == null:
		return true
	if _los_ray_q == null:
		_los_ray_q = PhysicsRayQueryParameters3D.new()
		_los_ray_q.collision_mask = 1
	_los_exclude.clear()
	if raid != null and raid.mech != null and is_instance_valid(raid.mech):
		_los_exclude.append((raid.mech as CollisionObject3D).get_rid())
	if target_node is CollisionObject3D:
		_los_exclude.append((target_node as CollisionObject3D).get_rid())
	_los_ray_q.exclude = _los_exclude
	_los_ray_q.from = eye
	_los_ray_q.to = target_w
	var hit := space.intersect_ray(_los_ray_q)
	if hit.is_empty():
		return true
	if hit.get("collider") == target_node:
		return true
	return (hit.position as Vector3).distance_squared_to(target_w) <= 1.35 * 1.35


func _is_target_alive(node: Node3D, kind_t: String) -> bool:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return false
	if kind_t == "loot":
		var it = node.get("items")
		return it is Array and not (it as Array).is_empty()
	if node.get("dying") == true or node.get("dead") == true or node.get("underground") == true:
		return false
	if node.is_in_group("boss") and not bool(node.get("awake")):
		return false
	var va = node.get("vis_anchor")
	if va != null and is_instance_valid(va) and not (va as Node3D).visible:
		return false
	return true


func _sync_candidates(eff_r: float, mp: Vector3) -> void:
	var r2_scan := (eff_r + 14.0) * (eff_r + 14.0)
	var tree := get_tree()
	if tree == null:
		return
	for grp_info in [["bugs", "enemy"], ["rovers", "rover"], ["lootboxes", "loot"]]:
		var grp: String = grp_info[0]
		var kt: String = grp_info[1]
		for n in tree.get_nodes_in_group(grp):
			if not (n is Node3D):
				continue
			var n3 := n as Node3D
			var id := n3.get_instance_id()
			if _entries.has(id):
				continue
			if n3.global_position.distance_squared_to(mp) > r2_scan:
				continue
			if not _is_target_alive(n3, kt):
				continue
			var bounds := _measure_local_bounds(n3, kt)
			_entries[id] = {
				"node": n3,
				"kind": kt,
				"bounds": bounds,
				"seen_t": 0.0,
				"lost_t": 0.0,
				"spotted": false,
				"expand_t": 0.0,
				"fade": 0.0,
				"los_ok": false,
				"los_checked": false,
				"rect": Rect2(),
				"rect_init": false,
				"dist": 0.0,
				"in_view": false,
			}


func _process(delta: float) -> void:
	var ui_block := false
	if raid == null or raid.camera == null or raid.mech == null or not is_instance_valid(raid.mech) or raid.ended or bool(raid.get("dropping")):
		ui_block = true
	elif hud != null:
		var pp = hud.get("pause_panel")
		var sp = hud.get("settings_panel")
		var lp = hud.get("loot_panel")
		if (pp != null and pp.visible) or (sp != null and sp.visible) or (lp != null and lp.visible) or (hud.has_method("map_open") and hud.map_open()):
			ui_block = true
	if ui_block:
		if not _draw_list.is_empty():
			_draw_list.clear()
			queue_redraw()
		return

	var cam: Camera3D = raid.camera
	var mp: Vector3 = (raid.mech as Node3D).global_position
	var eff_r := fcs_spot_range()
	var vp_sz := get_viewport_rect().size
	var w3d := (raid as Node3D).get_world_3d()
	var space: PhysicsDirectSpaceState3D = w3d.direct_space_state if w3d != null else null
	var eye_los := cam.global_position
	if raid.has_method("is_free_look_view") and not raid.is_free_look_view():
		# 俯视视角下以机甲光学塔顶为视线起点做建筑掩体通视校验
		eye_los = mp + Vector3(0.0, 4.4, 0.0)

	# 每 0.15s 增量登记进入侦察探测圈的新候选目标
	_scan_acc += delta
	if _scan_acc >= 0.15 or _entries.is_empty():
		_scan_acc = 0.0
		_sync_candidates(eff_r, mp)

	var keys: Array = _entries.keys()
	var n_keys := keys.size()
	var to_remove: Array = []
	var los_used := 0
	var start_idx := _los_cursor % maxi(1, n_keys)
	_draw_list.clear()

	for step_i in n_keys:
		var idx := (start_idx + step_i) % n_keys
		var id = keys[idx]
		var e: Dictionary = _entries[id]
		var raw_node = e.get("node")
		if not is_instance_valid(raw_node):
			to_remove.append(id)
			continue
		var node: Node3D = raw_node as Node3D
		var kt: String = str(e["kind"])
		if not _is_target_alive(node, kt):
			to_remove.append(id)
			continue
		var bounds: Array = e["bounds"] as Array
		var cw := _target_center_w(node, bounds)
		var dist_m := mp.distance_to(cw)
		e["dist"] = dist_m
		if dist_m > eff_r + 22.0 and not bool(e["spotted"]):
			to_remove.append(id)
			continue

		var in_range := dist_m <= eff_r
		var in_frustum := false
		if in_range and not cam.is_position_behind(cw):
			var sp_c := cam.unproject_position(cw)
			in_frustum = sp_c.x >= 12.0 and sp_c.x <= vp_sz.x - 12.0 and sp_c.y >= 12.0 and sp_c.y <= vp_sz.y - 12.0

		if in_frustum:
			if not bool(e["los_checked"]) or los_used < LOS_BUDGET_PER_FRAME:
				var los_pt := Vector3(cw.x, maxf(cw.y, node.global_position.y + 0.68), cw.z)
				e["los_ok"] = _check_los(space, eye_los, los_pt, node)
				e["los_checked"] = true
				los_used += 1
				_los_cursor = (idx + 1) % maxi(1, n_keys)
		else:
			e["los_ok"] = false

		var visible_now: bool = in_range and in_frustum and bool(e["los_ok"])
		e["in_view"] = visible_now

		if visible_now:
			e["lost_t"] = 0.0
			e["seen_t"] = minf(float(e["seen_t"]) + delta, SPOT_DELAY + 1.0)
			if not bool(e["spotted"]) and float(e["seen_t"]) >= SPOT_DELAY:
				e["spotted"] = true
				e["expand_t"] = 0.0
				e["fade"] = 1.0
				e["rect_init"] = false
			if bool(e["spotted"]):
				e["expand_t"] = minf(1.0, float(e["expand_t"]) + delta / EXPAND_DUR)
				e["fade"] = minf(1.0, float(e["fade"]) + delta * 5.0)
		else:
			var lt := float(e["lost_t"]) + delta
			e["lost_t"] = lt
			if bool(e["spotted"]):
				e["fade"] = maxf(0.0, float(e["fade"]) - delta / FADE_OUT_DUR)
				if float(e["fade"]) <= 0.005:
					e["spotted"] = false
					e["seen_t"] = 0.0
					e["expand_t"] = 0.0
					e["rect_init"] = false
					if dist_m > eff_r + 12.0:
						to_remove.append(id)
						continue
			else:
				if lt > GRACE_PRE:
					e["seen_t"] = maxf(0.0, float(e["seen_t"]) - delta * 2.2)

		if bool(e["spotted"]) and float(e["fade"]) > 0.01:
			var r_proj := _project_bounds_rect(cam, node, bounds, vp_sz)
			if r_proj.size.x > 1.0 and r_proj.size.y > 1.0:
				if not bool(e["rect_init"]):
					e["rect"] = r_proj
					e["rect_init"] = true
				else:
					var old_r: Rect2 = e["rect"] as Rect2
					var k_r := clampf(1.0 - exp(-26.0 * delta), 0.0, 1.0)
					e["rect"] = Rect2(
						old_r.position.lerp(r_proj.position, k_r),
						old_r.size.lerp(r_proj.size, k_r)
					)
				_draw_list.append(e)

	for id in to_remove:
		_entries.erase(id)

	if _draw_list.size() > MAX_DRAWN:
		_draw_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["dist"]) < float(b["dist"]))
		_draw_list.resize(MAX_DRAWN)

	queue_redraw()


func _draw_corner(p: Vector2, sx: float, sy: float, arm_x: float, arm_y: float, col: Color, sh_col: Color, lw: float) -> void:
	var px := p + Vector2(sx * arm_x, 0.0)
	var py := p + Vector2(0.0, sy * arm_y)
	draw_line(p, px, sh_col, lw + 2.2, false)
	draw_line(p, py, sh_col, lw + 2.2, false)
	draw_line(p, px, col, lw, false)
	draw_line(p, py, col, lw, false)


func _draw() -> void:
	if _draw_list.is_empty():
		return
	var fnt := ThemeDB.fallback_font
	for e_v in _draw_list:
		var e: Dictionary = e_v as Dictionary
		var rect: Rect2 = e["rect"] as Rect2
		var fade := float(e["fade"])
		var t_exp := clampf(float(e["expand_t"]), 0.0, 1.0)
		var is_loot := str(e["kind"]) == "loot"

		# 缓出展开 + 末段轻微机械到位弹性（从目标中心向外舒展至物体真实四边角）
		var inv_t := 1.0 - t_exp
		var ease_out := 1.0 - inv_t * inv_t * inv_t
		var overshoot := sin(t_exp * PI) * 0.045 * (1.0 - t_exp * 0.4)
		var scale_f := clampf(ease_out + overshoot, 0.0, 1.06)

		var center := rect.position + rect.size * 0.5
		var half := rect.size * 0.5 * scale_f
		var x0 := center.x - half.x
		var x1 := center.x + half.x
		var y0 := center.y - half.y
		var y1 := center.y + half.y

		var base_c := COL_LOOT if is_loot else COL_ENEMY
		var flash_w := (1.0 - ease_out) * 0.72
		var c := base_c.lerp(COL_FLASH, flash_w)
		c.a *= fade * clampf(t_exp * 3.5 + 0.25, 0.0, 1.0)
		var sh := COL_SHADOW
		sh.a *= fade * clampf(t_exp * 3.5 + 0.25, 0.0, 1.0)

		var arm_x := clampf(half.x * 2.0 * 0.28, 6.0, 22.0) * clampf(ease_out * 1.15, 0.30, 1.0)
		var arm_y := clampf(half.y * 2.0 * 0.28, 6.0, 22.0) * clampf(ease_out * 1.15, 0.30, 1.0)
		var lw := 2.2 if not is_loot else 2.0

		# 四个橙黄色直角边（左上 / 右上 / 左下 / 右下）
		_draw_corner(Vector2(x0, y0),  1.0,  1.0, arm_x, arm_y, c, sh, lw)
		_draw_corner(Vector2(x1, y0), -1.0,  1.0, arm_x, arm_y, c, sh, lw)
		_draw_corner(Vector2(x0, y1),  1.0, -1.0, arm_x, arm_y, c, sh, lw)
		_draw_corner(Vector2(x1, y1), -1.0, -1.0, arm_x, arm_y, c, sh, lw)

		# 展开完成后在左上角显示极简火控测距标示
		if fnt != null and t_exp > 0.68:
			var vp_sz := get_viewport_rect().size
			var tag_a := clampf((t_exp - 0.68) / 0.32, 0.0, 1.0) * fade * 0.92
			var d_m := int(roundf(float(e["dist"])))
			var tag := ("BOX %02dm" % d_m) if is_loot else ("TGT %02dm" % d_m)
			var tc := Color(c.r, c.g, c.b, tag_a)
			var ts := Color(0.0, 0.0, 0.0, tag_a * 0.72)
			var tp := Vector2(clampf(x0 + 1.0, 4.0, vp_sz.x - 66.0), clampf(y0 - 4.0, 14.0, vp_sz.y - 4.0))
			draw_string(fnt, tp + Vector2(1.0, 1.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ts)
			draw_string(fnt, tp, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, tc)
