extends Control
## 敌方头顶写实半透明动态血条层（工业做旧橙黄战术投影风格）：
## 在单个全屏透明 Control 上通过屏幕投影与 _draw() 批量绘制，仅追踪受击过的目标，
## 呈现纤薄半透明暗底、做旧哑光橙黄填充、受击微震与延迟掉血残影，不阻断输入。

const MAX_VISIBLE := 24
const SHOW_DURATION := 4.8
const FADE_DURATION := 0.65
const KILL_DURATION := 0.48
const TRAIL_HOLD := 0.15

# 写实半透明工业做旧橙黄调色板
const COL_BACKDROP := Color(0.04, 0.04, 0.04, 0.44)
const COL_SOFT_EDGE := Color(0.02, 0.02, 0.02, 0.28)
const COL_HAIRLINE := Color(0.66, 0.54, 0.36, 0.26)
const COL_BRACKET := Color(0.78, 0.56, 0.24, 0.46)
const COL_FILL_MAIN := Color(0.80, 0.47, 0.14, 0.74)
const COL_FILL_SHADE := Color(0.52, 0.28, 0.07, 0.72)
const COL_FILL_LOW := Color(0.76, 0.24, 0.10, 0.78)
const COL_FILL_LOW_SHADE := Color(0.46, 0.13, 0.05, 0.76)
const COL_TRAIL := Color(0.92, 0.76, 0.44, 0.48)
const COL_FLASH := Color(0.98, 0.85, 0.58, 0.85)
const COL_CURSOR := Color(0.98, 0.84, 0.54, 0.72)
const COL_WEAR := Color(0.18, 0.10, 0.03, 0.16)
const COL_MICRO_GRID := Color(0.06, 0.04, 0.02, 0.24)

var raid
var hud
var _entries := {}
var _draw_list: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 4


func notify_hit(node: Node3D, prev_hp: float, cur_hp: float, max_hp: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	var id := node.get_instance_id()
	var cap := maxf(max_hp, 1.0)
	var cur_r := clampf(cur_hp / cap, 0.0, 1.0)
	var prev_r := clampf(prev_hp / cap, 0.0, 1.0)
	var dead_now := cur_hp <= 0.0
	var is_new := not _entries.has(id)
	var e: Dictionary
	if is_new:
		e = {
			"node": node,
			"max_hp": cap,
			"disp_hp": prev_r,
			"trail_hp": prev_r,
			"target_hp": cur_r,
			"trail_hold": TRAIL_HOLD,
			"hit_flash": 1.0,
			"pop_t": 0.0,
			"shake_dir": Vector2(1.0 if randf() > 0.5 else -1.0, randf_range(-0.35, 0.35)).normalized(),
			"ttl": KILL_DURATION if dead_now else SHOW_DURATION,
			"dead": dead_now,
			"dead_t": 0.0,
			"bar_y": _resolve_bar_y(node),
			"bar_w": _resolve_bar_w(node),
			"last_pos": node.global_position,
			"vis_y": _resolve_vis_y(node),
		}
		_entries[id] = e
	else:
		e = _entries[id]
		e["max_hp"] = cap
		e["target_hp"] = cur_r
		e["trail_hp"] = maxf(float(e["trail_hp"]), prev_r)
		e["trail_hold"] = TRAIL_HOLD
		e["hit_flash"] = 1.0
		e["shake_dir"] = Vector2(1.0 if randf() > 0.5 else -1.0, randf_range(-0.35, 0.35)).normalized()
		if dead_now:
			e["dead"] = true
			e["ttl"] = minf(float(e["ttl"]), KILL_DURATION)
		elif not bool(e["dead"]):
			e["ttl"] = SHOW_DURATION
		e["last_pos"] = node.global_position
		e["vis_y"] = _resolve_vis_y(node)


func _resolve_bar_y(node: Node3D) -> float:
	if node.has_method("_head_bar_y"):
		return float(node.call("_head_bar_y"))
	if node.is_in_group("rovers"):
		return 4.65
	if node.is_in_group("nests"):
		return 3.85
	return 2.6


func _resolve_bar_w(node: Node3D) -> float:
	if node.is_in_group("nests"):
		return 64.0
	if node.is_in_group("rovers"):
		return 56.0
	var d = node.get("data")
	var sc := float(d.get("scale", 1.0)) if d is Dictionary else 1.0
	return clampf(38.0 + sc * 14.0, 44.0, 68.0)


func _resolve_vis_y(node: Node3D) -> float:
	var vis = node.get("visual")
	if vis is Node3D and is_instance_valid(vis):
		return (vis as Node3D).position.y
	return 0.0


func _process(delta: float) -> void:
	if _entries.is_empty():
		if not _draw_list.is_empty():
			_draw_list.clear()
			queue_redraw()
		return
	var paused_or_ui := false
	if raid == null or raid.camera == null or raid.ended:
		paused_or_ui = true
	elif hud != null:
		var pp = hud.get("pause_panel")
		var sp = hud.get("settings_panel")
		var lp = hud.get("loot_panel")
		if (pp != null and pp.visible) or (sp != null and sp.visible) or (lp != null and lp.visible) or (hud.has_method("map_open") and hud.map_open()):
			paused_or_ui = true

	var cam: Camera3D = raid.camera if raid != null else null
	var vp_sz := get_viewport_rect().size
	var to_remove: Array = []
	_draw_list.clear()

	for id in _entries.keys():
		var e: Dictionary = _entries[id]
		var node = e["node"]
		var valid := node != null and is_instance_valid(node)
		if valid:
			var n3 := node as Node3D
			e["last_pos"] = n3.global_position
			e["vis_y"] = _resolve_vis_y(n3)
			var is_dying: bool = (node.get("dying") == true) or (node.get("dead") == true)
			var raw_hp = node.get("hp")
			var cur_hp := float(raw_hp) if raw_hp != null else 0.0
			if is_dying or cur_hp <= 0.0:
				e["target_hp"] = 0.0
				if not bool(e["dead"]):
					e["dead"] = true
					e["ttl"] = KILL_DURATION
			else:
				var cap := maxf(float(e["max_hp"]), cur_hp)
				e["max_hp"] = cap
				var r := clampf(cur_hp / cap, 0.0, 1.0)
				e["target_hp"] = r
				if r > float(e["trail_hp"]):
					e["trail_hp"] = move_toward(float(e["trail_hp"]), r, delta * 2.5)
		else:
			e["target_hp"] = 0.0
			if not bool(e["dead"]):
				e["dead"] = true
				e["ttl"] = KILL_DURATION

		e["pop_t"] = minf(1.0, float(e["pop_t"]) + delta * 6.5)
		e["hit_flash"] = maxf(0.0, float(e["hit_flash"]) - delta * 6.2)

		var target_r := float(e["target_hp"])
		var disp_r := float(e["disp_hp"])
		var disp_spd := 20.0 if bool(e["dead"]) else 14.0
		disp_r = lerpf(disp_r, target_r, 1.0 - exp(-disp_spd * delta))
		if absf(disp_r - target_r) < 0.002:
			disp_r = target_r
		e["disp_hp"] = disp_r

		var hold := float(e["trail_hold"])
		if hold > 0.0:
			e["trail_hold"] = maxf(0.0, hold - delta)
		else:
			var trail_r := float(e["trail_hp"])
			var tr_spd := 5.0 if bool(e["dead"]) else 2.6
			trail_r = lerpf(trail_r, disp_r, 1.0 - exp(-tr_spd * delta))
			if trail_r < disp_r or absf(trail_r - disp_r) < 0.002:
				trail_r = disp_r
			e["trail_hp"] = trail_r

		if bool(e["dead"]):
			e["dead_t"] = float(e["dead_t"]) + delta
		e["ttl"] = float(e["ttl"]) - delta
		if float(e["ttl"]) <= 0.0:
			to_remove.append(id)
			continue

		if paused_or_ui or cam == null:
			continue
		if valid and node.get("underground") == true:
			continue
		if valid and node.get("vis_anchor") != null and is_instance_valid(node.vis_anchor) and not node.vis_anchor.visible:
			continue

		var world_p: Vector3 = e["last_pos"] + Vector3(0.0, float(e["vis_y"]) + float(e["bar_y"]), 0.0)
		var dist := cam.global_position.distance_to(world_p)
		if dist > 68.0 or cam.is_position_behind(world_p):
			continue
		var sp := cam.unproject_position(world_p)
		if sp.x < -90.0 or sp.x > vp_sz.x + 90.0 or sp.y < -60.0 or sp.y > vp_sz.y + 60.0:
			continue
		e["screen_pos"] = sp
		e["dist"] = dist
		_draw_list.append(e)

	for id in to_remove:
		_entries.erase(id)

	if _draw_list.size() > MAX_VISIBLE:
		_draw_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["dist"]) < float(b["dist"]))
		_draw_list.resize(MAX_VISIBLE)
	elif _draw_list.size() > 1:
		# 远先近后绘制，保证近处目标血条压在远处之上
		_draw_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["dist"]) > float(b["dist"]))

	queue_redraw()


func _draw() -> void:
	if _draw_list.is_empty():
		return
	var now_s := Time.get_ticks_msec() * 0.001
	for e: Dictionary in _draw_list:
		var sp: Vector2 = e["screen_pos"]
		var dist := float(e["dist"])
		var dist_fade := clampf(1.0 - (dist - 48.0) / 20.0, 0.0, 1.0)
		var ttl := float(e["ttl"])
		var ttl_fade := clampf(ttl / (KILL_DURATION * 0.72 if bool(e["dead"]) else FADE_DURATION), 0.0, 1.0)
		var pop := float(e["pop_t"])
		var ease_pop := 1.0 - pow(1.0 - pop, 3.0)
		var alpha := clampf(ease_pop * 1.6, 0.0, 1.0) * ttl_fade * dist_fade
		if alpha <= 0.01:
			continue

		var scale_k := clampf(29.0 / maxf(dist, 14.0), 0.76, 1.06)
		var w := roundf(float(e["bar_w"]) * scale_k * lerpf(0.72, 1.0, ease_pop))
		var h := roundf(4.0 * clampf(scale_k, 0.85, 1.08))

		var hf := float(e["hit_flash"])
		var shake := Vector2.ZERO
		if hf > 0.01:
			var s_amp := hf * 1.25
			var osc := sin(now_s * 78.0 + float(e["bar_w"]))
			shake = (e["shake_dir"] as Vector2) * (osc * s_amp)
		var center := Vector2(roundf(sp.x + shake.x), roundf(sp.y + shake.y))
		var left := center.x - w * 0.5
		var top := center.y - h * 0.5
		var right := left + w
		var bot := top + h

		# 1. 半透明柔和外晕与炭黑磨砂底槽（无硬粗框）
		draw_rect(Rect2(left - 2.0, top - 1.5, w + 4.0, h + 3.0), _a(COL_SOFT_EDGE, alpha), true)
		draw_rect(Rect2(left - 1.0, top - 0.5, w + 2.0, h + 1.0), _a(COL_BACKDROP, alpha), true)

		# 2. 延迟扣血半透明残影（Trail）
		var disp_r := clampf(float(e["disp_hp"]), 0.0, 1.0)
		var trail_r := clampf(float(e["trail_hp"]), disp_r, 1.0)
		if trail_r > disp_r + 0.003:
			var tx0 := left + w * disp_r
			var tw := w * (trail_r - disp_r)
			var tr_c := COL_TRAIL.lerp(COL_FLASH, hf * 0.45)
			draw_rect(Rect2(tx0, top, tw, h), _a(tr_c, alpha), true)

		# 3. 半透明工业做旧橙黄主填充（克制纵深暗渡 + 轻度做旧蚀斑）
		if disp_r > 0.002:
			var fw := maxf(1.0, w * disp_r)
			var low_k := clampf((0.30 - disp_r) / 0.30, 0.0, 1.0)
			var pulse_low := (0.5 + 0.5 * sin(now_s * 6.5)) * low_k * 0.14
			var c_main := COL_FILL_MAIN.lerp(COL_FILL_LOW, low_k)
			var c_shade := COL_FILL_SHADE.lerp(COL_FILL_LOW_SHADE, low_k)
			if hf > 0.01 or pulse_low > 0.01:
				var boost := clampf(hf * 0.36 + pulse_low, 0.0, 0.48)
				c_main = c_main.lerp(COL_FLASH, boost)
			draw_rect(Rect2(left, top, fw, h), _a(c_main, alpha), true)
			var shade_h := maxf(1.0, floorf(h * 0.38))
			draw_rect(Rect2(left, bot - shade_h, fw, shade_h), _a(c_shade, alpha), true)

			# 极轻半透明做旧斑驳与微刻格栅
			for patch in [[0.11, 0.09], [0.46, 0.07], [0.74, 0.09]]:
				var px := left + w * float(patch[0])
				var pw := w * float(patch[1])
				if px < left + fw - 1.5:
					draw_rect(Rect2(px, top, minf(pw, left + fw - px), h), _a(COL_WEAR, alpha), true)
			for q_i in [1, 2, 3]:
				var qx := left + w * (float(q_i) * 0.25)
				if qx < left + fw - 1.0:
					draw_line(Vector2(qx, top), Vector2(qx, bot), _a(COL_MICRO_GRID, alpha), 1.0, false)

			# 1px 战术前端刻度线
			if fw >= 2.0 and disp_r < 0.998:
				draw_line(Vector2(left + fw, top - 0.5), Vector2(left + fw, bot + 0.5), _a(COL_CURSOR, alpha), 1.0, false)

		# 4. 极细半透明框线与左右战术定位卡口
		var hc := COL_HAIRLINE.lerp(COL_FLASH, hf * 0.40)
		draw_rect(Rect2(left - 1.0, top - 0.5, w + 2.0, h + 1.0), _a(hc, alpha), false, 1.0)
		var bc := COL_BRACKET.lerp(COL_FLASH, hf * 0.45)
		draw_line(Vector2(left - 2.0, top - 1.5), Vector2(left - 2.0, bot + 1.5), _a(bc, alpha), 1.0, false)
		draw_line(Vector2(right + 2.0, top - 1.5), Vector2(right + 2.0, bot + 1.5), _a(bc, alpha), 1.0, false)


static func _a(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * alpha)
