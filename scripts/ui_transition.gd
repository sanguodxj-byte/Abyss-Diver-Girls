extends Control

const UI = preload("res://scripts/ui.gd")
const K = preload("res://scripts/hub_kit.gd")
const ENTER := 0.42
const EXIT := 0.20
const SCREEN_EXIT := 0.24

var kind := "panels"
var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


static func attach(target: Node, mode: String) -> Control:
	var old := target.get_node_or_null("PageMotion")
	if old != null:
		old.get_parent().remove_child(old)
		old.queue_free()
	var effect = load("res://scripts/ui_transition.gd").new()
	effect.name = "PageMotion"
	effect.kind = mode
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.focus_mode = Control.FOCUS_NONE
	effect.clip_contents = true
	effect.z_index = 100
	target.add_child(effect)
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return effect


static func clear(target: Node) -> void:
	var effect := target.get_node_or_null("PageMotion")
	if effect != null:
		effect.get_parent().remove_child(effect)
		effect.queue_free()


func _draw() -> void:
	if progress >= 0.999:
		return
	if kind == "hatch":
		_draw_hatch()
	else:
		var regions := _regions()
		for i in regions.size():
			var delay := minf(float(i) * 0.048, 0.20)
			var opened := clampf((progress - delay) / (1.0 - delay), 0.0, 1.0)
			_draw_panel(regions[i], opened, i)


func _regions() -> Array[Rect2]:
	var result: Array[Rect2] = []
	_collect_regions(get_parent(), result)
	if result.is_empty() and kind != "result":
		result.append(Rect2(Vector2.ZERO, size))
	return result


func _collect_regions(root: Node, result: Array[Rect2]) -> void:
	for child in root.get_children():
		if child == self or (child is Control and not child.visible) or child.name == "PageMotion":
			continue
		if child is PanelContainer and child.size.x >= 100.0 and child.size.y >= 50.0:
			var global_rect: Rect2 = child.get_global_rect()
			var local_pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * global_rect.position
			var local_scale := get_global_transform_with_canvas().get_scale()
			var rect := Rect2(local_pos, global_rect.size / local_scale).intersection(Rect2(Vector2.ZERO, size))
			if rect.size.x > 1.0 and rect.size.y > 1.0:
				result.append(rect)
			continue
		_collect_regions(child, result)


func _draw_panel(rect: Rect2, opened: float, index: int) -> void:
	if rect.size.x < 2.0 or rect.size.y < 2.0 or opened >= 0.999:
		return
	var fade := clampf(1.0 - opened, 0.0, 1.0)
	draw_rect(rect, Color(0.035, 0.039, 0.044, fade * 0.38), true)
	_draw_corner_brackets(rect, Color(K.AMBER_HI.r, K.AMBER_HI.g, K.AMBER_HI.b, fade * 0.88), minf(14.0, minf(rect.size.x, rect.size.y) * 0.22))

	var bands := 2 if rect.size.y > 260.0 else 1
	for band in bands:
		var lag := float(band) * 0.06
		var phase := clampf((opened - lag) / (1.0 - lag), 0.0, 1.0)
		var h := rect.size.y / float(bands)
		var width := rect.size.x * (1.0 - phase)
		if width <= 1.0:
			continue
		var leftward := (band + index) % 2 == 0
		var x := rect.position.x if leftward else rect.end.x - width
		var cover := Rect2(x, rect.position.y + h * float(band), width, h + 0.5).intersection(rect)
		if cover.size.x <= 1.0 or cover.size.y <= 1.0:
			continue
		_draw_armor_leaf(cover, leftward, phase, band, bands)

	var trace := clampf(opened * 1.85, 0.0, 1.0)
	var trace_a := clampf((1.0 - opened) * 0.92, 0.0, 1.0)
	if trace_a > 0.02:
		draw_line(rect.position + Vector2(2.0, 1.5), rect.position + Vector2(maxf(2.0, rect.size.x * trace - 2.0), 1.5), Color(K.AMBER_HI, trace_a), 2.0)
		draw_line(Vector2(rect.end.x - maxf(2.0, rect.size.x * trace - 2.0), rect.end.y - 1.5), Vector2(rect.end.x - 2.0, rect.end.y - 1.5), Color(K.AMBER, trace_a * 0.72), 1.5)

	if opened > 0.08 and opened < 0.96 and rect.size.x > 24.0:
		var scan_t := clampf((opened - 0.08) / 0.88, 0.0, 1.0)
		var scan_y := lerpf(rect.position.y + 4.0, rect.end.y - 4.0, scan_t)
		var scan_a := sin(scan_t * PI) * 0.55
		var band_h := minf(16.0, rect.size.y * 0.18)
		var grad_top := maxf(rect.position.y + 2.0, scan_y - band_h)
		if scan_y > grad_top + 1.0:
			var pts := PackedVector2Array([
				Vector2(rect.position.x + 3.0, grad_top),
				Vector2(rect.end.x - 3.0, grad_top),
				Vector2(rect.end.x - 3.0, scan_y),
				Vector2(rect.position.x + 3.0, scan_y),
			])
			var c0 := Color(K.AMBER.r, K.AMBER.g, K.AMBER.b, 0.0)
			var c1 := Color(K.AMBER_HI.r, K.AMBER_HI.g, K.AMBER_HI.b, scan_a * 0.22)
			draw_polygon(pts, PackedColorArray([c0, c0, c1, c1]))
		draw_line(Vector2(rect.position.x + 3.0, scan_y), Vector2(rect.end.x - 3.0, scan_y), Color(K.AMBER_HI, scan_a), 1.5)


func _draw_armor_leaf(cover: Rect2, leftward: bool, phase: float, band: int, bands: int) -> void:
	var seam := cover.end.x - 1.0 if leftward else cover.position.x + 1.0
	var dir := -1.0 if leftward else 1.0
	var shadow_w := minf(18.0, cover.size.x * 0.35)
	if leftward and cover.end.x + shadow_w <= size.x:
		draw_rect(Rect2(cover.end.x, cover.position.y, shadow_w, cover.size.y), Color(0.01, 0.012, 0.015, (1.0 - phase) * 0.48))
	elif not leftward and cover.position.x - shadow_w >= 0.0:
		draw_rect(Rect2(cover.position.x - shadow_w, cover.position.y, shadow_w, cover.size.y), Color(0.01, 0.012, 0.015, (1.0 - phase) * 0.48))

	draw_rect(cover, Color(0.058, 0.064, 0.070, 1.0))
	draw_style_box(K.px9("panel9", 12, 10, 0, 0), cover)

	var rail_h := minf(6.0, cover.size.y * 0.14)
	if cover.size.y > 24.0:
		var top_rail := Rect2(cover.position.x + 2.0, cover.position.y + 2.0, maxf(0.0, cover.size.x - 4.0), rail_h)
		var bot_rail := Rect2(cover.position.x + 2.0, cover.end.y - rail_h - 2.0, maxf(0.0, cover.size.x - 4.0), rail_h)
		draw_rect(top_rail, Color(0.14, 0.155, 0.17, 0.96))
		draw_rect(bot_rail, Color(0.12, 0.135, 0.15, 0.96))
		draw_line(Vector2(top_rail.position.x, top_rail.end.y), Vector2(top_rail.end.x, top_rail.end.y), Color(0.36, 0.39, 0.42, 0.82), 1.0)
		draw_line(Vector2(bot_rail.position.x, bot_rail.position.y), Vector2(bot_rail.end.x, bot_rail.position.y), Color(0.30, 0.33, 0.36, 0.78), 1.0)

	if cover.size.x > 44.0 and cover.size.y > 42.0:
		var well := Rect2(cover.position.x + 10.0, cover.position.y + rail_h + 6.0, cover.size.x - 24.0, cover.size.y - (rail_h + 6.0) * 2.0)
		if leftward:
			well.size.x = maxf(8.0, well.size.x - 6.0)
		else:
			well.position.x += 6.0
			well.size.x = maxf(8.0, well.size.x - 6.0)
		if well.size.x > 16.0 and well.size.y > 14.0:
			_draw_chamfer_plate(well, minf(6.0, minf(well.size.x, well.size.y) * 0.22), Color(0.044, 0.049, 0.054, 0.96), Color(0.24, 0.27, 0.29, 0.88))
			var rib_count := 2 if well.size.y > 88.0 else 1
			for r_idx in rib_count:
				var ry := well.position.y + well.size.y * (float(r_idx + 1) / float(rib_count + 1))
				draw_rect(Rect2(well.position.x + 6.0, ry - 2.5, maxf(0.0, well.size.x - 12.0), 5.0), Color(0.095, 0.105, 0.115, 0.95))
				draw_line(Vector2(well.position.x + 6.0, ry - 1.0), Vector2(well.end.x - 6.0, ry - 1.0), Color(0.34, 0.37, 0.40, 0.72), 1.0)
				draw_line(Vector2(well.position.x + 6.0, ry + 1.5), Vector2(well.end.x - 6.0, ry + 1.5), Color(0.02, 0.022, 0.025, 0.90), 1.0)

	if cover.size.x > 26.0 and cover.size.y > 26.0:
		var lip_w := minf(12.0, cover.size.x * 0.28)
		var lip_x := cover.end.x - lip_w - 1.0 if leftward else cover.position.x + 1.0
		var lip_r := Rect2(lip_x, cover.position.y + 2.0, lip_w, maxf(2.0, cover.size.y - 4.0))
		UI.draw_hazard(self, lip_r)
		draw_rect(lip_r, Color(0.28, 0.30, 0.33, 0.92), false, 1.0)

	if cover.size.x > 64.0 and cover.size.y > 32.0:
		var vent_count := mini(7, int((cover.size.x - 38.0) / 11.0))
		var vent_start := (cover.position.x + 16.0) if leftward else (cover.end.x - 16.0 - float(vent_count) * 11.0)
		var vy1 := cover.end.y - rail_h - 6.0
		var vy0 := vy1 - minf(10.0, cover.size.y * 0.18)
		for slot in vent_count:
			var vx := vent_start + float(slot) * 11.0
			draw_line(Vector2(vx, vy1), Vector2(vx + 5.0, vy0), Color(0.024, 0.027, 0.030, 0.95), 2.4)
			draw_line(Vector2(vx + 1.0, vy1), Vector2(vx + 6.0, vy0), Color(0.34, 0.37, 0.40, 0.55), 1.0)
		_bolt(Vector2(cover.position.x + 8.0, cover.position.y + rail_h + 7.0), 1.8)
		_bolt(Vector2(cover.end.x - 8.0, cover.position.y + rail_h + 7.0), 1.8)
		_bolt(Vector2(cover.position.x + 8.0, cover.end.y - rail_h - 7.0), 1.8)
		_bolt(Vector2(cover.end.x - 8.0, cover.end.y - rail_h - 7.0), 1.8)

	if bands > 1 and band == 0:
		draw_line(Vector2(cover.position.x + 2.0, cover.end.y - 0.5), Vector2(cover.end.x - 2.0, cover.end.y - 0.5), Color(K.AMBER, 0.65), 1.2)

	var glow_w := minf(6.0, cover.size.x)
	var glow_x := seam - glow_w if leftward else seam
	draw_rect(Rect2(glow_x, cover.position.y + 1.0, glow_w, maxf(1.0, cover.size.y - 2.0)), Color(K.AMBER_HI.r, K.AMBER_HI.g, K.AMBER_HI.b, 0.20))
	draw_line(Vector2(seam, cover.position.y + 1.0), Vector2(seam, cover.end.y - 1.0), K.AMBER_HI, 2.2)
	draw_line(Vector2(seam + dir * 2.0, cover.position.y + 3.0), Vector2(seam + dir * 2.0, cover.end.y - 3.0), Color(0.95, 0.88, 0.72, 0.75), 1.0)

	if cover.size.y > 38.0 and cover.size.x > 20.0:
		var lug_h := minf(16.0, cover.size.y * 0.28)
		var lug_y := cover.position.y + (cover.size.y - lug_h) * 0.5
		var lug_w := minf(9.0, cover.size.x * 0.35)
		var lug_x := seam - lug_w if leftward else seam
		var lug := Rect2(lug_x, lug_y, lug_w, lug_h)
		draw_rect(lug, Color(0.16, 0.18, 0.20, 1.0))
		draw_rect(lug, K.AMBER_HI, false, 1.2)


func _draw_hatch() -> void:
	var travel := size.x * 0.5 + 32.0
	var left_edge := size.x * 0.5 - progress * travel
	var right_edge := size.x * 0.5 + progress * travel
	var gap := right_edge - left_edge
	if gap > 0.0 and progress < 0.85:
		var glow_a := clampf((0.85 - progress) / 0.85, 0.0, 1.0)
		var seam_w := minf(26.0, gap * 0.5 + 10.0)
		draw_rect(Rect2(left_edge, 0.0, seam_w, size.y), Color(0.01, 0.012, 0.015, glow_a * 0.45))
		draw_rect(Rect2(right_edge - seam_w, 0.0, seam_w, size.y), Color(0.01, 0.012, 0.015, glow_a * 0.45))

	_draw_door(Rect2(left_edge - size.x * 0.5, 0.0, size.x * 0.5, size.y), true)
	_draw_door(Rect2(right_edge, 0.0, size.x * 0.5, size.y), false)
	_draw_hatch_gantry(left_edge, right_edge)

	var latch := clampf((0.24 - progress) / 0.24, 0.0, 1.0)
	if latch > 0.0:
		var cx := size.x * 0.5
		draw_line(Vector2(cx, 0.0), Vector2(cx, size.y), Color(K.AMBER_HI, latch * 0.85), 2.5)
		for y in [size.y * 0.20, size.y * 0.50, size.y * 0.80]:
			_draw_lock_clamp(Vector2(cx, y), latch)


func _draw_hatch_gantry(left_edge: float, right_edge: float) -> void:
	var track_h := 16.0
	var span_l := clampf(left_edge, 0.0, size.x * 0.5)
	var span_r := clampf(size.x - right_edge, 0.0, size.x * 0.5)
	for pair in [
		Rect2(0.0, 0.0, span_l, track_h),
		Rect2(right_edge, 0.0, span_r, track_h),
		Rect2(0.0, size.y - track_h, span_l, track_h),
		Rect2(right_edge, size.y - track_h, span_r, track_h),
	]:
		var r: Rect2 = pair
		if r.size.x <= 2.0:
			continue
		draw_rect(r, Color(0.04, 0.045, 0.05, 0.98))
		draw_line(Vector2(r.position.x, r.end.y - 1.0), Vector2(r.end.x, r.end.y - 1.0), Color(0.34, 0.37, 0.40, 0.9), 1.2)
		draw_line(Vector2(r.position.x, r.position.y + 1.0), Vector2(r.end.x, r.position.y + 1.0), Color(0.34, 0.37, 0.40, 0.9), 1.2)
		var step := 48.0
		var x := r.position.x + 18.0
		while x < r.end.x - 10.0:
			draw_rect(Rect2(x, r.position.y + 4.0, 14.0, r.size.y - 8.0), Color(0.18, 0.20, 0.22, 0.95))
			draw_line(Vector2(x + 2.0, r.position.y + 6.0), Vector2(x + 12.0, r.position.y + 6.0), K.AMBER, 1.5)
			x += step


func _draw_lock_clamp(center: Vector2, latch: float) -> void:
	var half_w := 48.0 * latch
	var half_h := 16.0
	var r := Rect2(center.x - half_w, center.y - half_h, half_w * 2.0, half_h * 2.0)
	if r.size.x < 4.0:
		return
	_draw_chamfer_plate(r, minf(6.0, half_w * 0.35), Color(0.13, 0.145, 0.16, 1.0), K.STEEL)
	var inner := r.grow(-4.0)
	if inner.size.x > 6.0 and inner.size.y > 6.0:
		draw_rect(inner, Color(0.06, 0.066, 0.072, 1.0))
		draw_rect(inner, Color(K.AMBER, 0.85), false, 1.2)
		var bar_w := maxf(2.0, (inner.size.x - 8.0) * latch)
		draw_rect(Rect2(center.x - bar_w * 0.5, center.y - 3.0, bar_w, 6.0), K.AMBER_HI)
	if half_w > 18.0:
		_bolt(Vector2(r.position.x + 8.0, center.y), 2.0)
		_bolt(Vector2(r.end.x - 8.0, center.y), 2.0)


func _draw_door(rect: Rect2, left: bool) -> void:
	if rect.end.x < 0.0 or rect.position.x > size.x:
		return
	draw_rect(rect, Color(0.052, 0.058, 0.064, 1.0))
	draw_style_box(K.px9("panel9", 14, 12, 0, 0), rect)

	var edge := rect.end.x - 1.0 if left else rect.position.x + 1.0
	var direction := -1.0 if left else 1.0
	var strip_w := 24.0
	var strip_x := edge - strip_w if left else edge
	var strip_rect := Rect2(strip_x, 16.0, strip_w, maxf(0.0, size.y - 32.0))
	UI.draw_hazard(self, strip_rect)
	draw_rect(strip_rect, Color(0.30, 0.33, 0.36, 0.95), false, 1.2)

	var sub_rail_x := strip_x - 8.0 if left else strip_rect.end.x
	var sub_rail := Rect2(sub_rail_x, 16.0, 8.0, maxf(0.0, size.y - 32.0))
	draw_rect(sub_rail, Color(0.11, 0.12, 0.13, 0.98))
	draw_line(Vector2(sub_rail.position.x, sub_rail.position.y), Vector2(sub_rail.position.x, sub_rail.end.y), Color(0.32, 0.35, 0.38, 0.85), 1.0)
	draw_line(Vector2(sub_rail.end.x, sub_rail.position.y), Vector2(sub_rail.end.x, sub_rail.end.y), Color(0.03, 0.035, 0.04, 0.95), 1.0)
	var ry := 34.0
	while ry < size.y - 30.0:
		_bolt(Vector2(sub_rail.position.x + 4.0, ry), 1.6)
		ry += 44.0

	draw_line(Vector2(edge, 0.0), Vector2(edge, size.y), K.AMBER_HI, 2.4)
	draw_line(Vector2(edge + direction * 2.0, 0.0), Vector2(edge + direction * 2.0, size.y), Color(0.96, 0.88, 0.70, 0.72), 1.0)

	for lug_idx in 3:
		var ly := size.y * (0.20 + float(lug_idx) * 0.30)
		var lug_w := 14.0
		var lug_h := 38.0
		var lx := (edge - strip_w - 8.0 - lug_w) if left else (edge + strip_w + 8.0)
		var lug_r := Rect2(lx, ly - lug_h * 0.5, lug_w, lug_h)
		draw_rect(lug_r, Color(0.15, 0.165, 0.18, 1.0))
		draw_rect(lug_r, K.STEEL, false, 1.0)
		draw_rect(Rect2(lug_r.position.x + 3.0, ly - 5.0, lug_w - 6.0, 10.0), K.AMBER)

	var outer_pad := 24.0
	var inner_pad := strip_w + 30.0
	var bay_x := (rect.position.x + outer_pad) if left else (rect.position.x + inner_pad)
	var bay_w := rect.size.x - outer_pad - inner_pad
	if bay_w <= 40.0:
		return

	for part in 4:
		var y_center := size.y * (float(part) + 0.5) / 4.0
		var bay_h := size.y * 0.195
		var bay := Rect2(bay_x, y_center - bay_h * 0.5, bay_w, bay_h)
		_draw_chamfer_plate(bay, 10.0, Color(0.068, 0.074, 0.082, 1.0), Color(0.28, 0.31, 0.34, 0.95))

		var inset := bay.grow(-7.0)
		_draw_chamfer_plate(inset, 7.0, Color(0.045, 0.050, 0.056, 1.0), Color(0.18, 0.20, 0.22, 0.92))

		var top_bar := Rect2(inset.position.x + 8.0, inset.position.y + 6.0, maxf(0.0, inset.size.x - 16.0), 8.0)
		draw_rect(top_bar, Color(0.13, 0.145, 0.16, 0.96))
		var accent_w := minf(46.0, top_bar.size.x * 0.25)
		var accent_x := (top_bar.end.x - accent_w) if left else top_bar.position.x
		draw_rect(Rect2(accent_x, top_bar.position.y, accent_w, top_bar.size.y), K.AMBER)

		for rib_frac in [0.46, 0.72]:
			var rib_y := inset.position.y + inset.size.y * float(rib_frac)
			var rib_r := Rect2(inset.position.x + 12.0, rib_y - 3.5, maxf(0.0, inset.size.x - 24.0), 7.0)
			draw_rect(rib_r, Color(0.105, 0.115, 0.125, 0.98))
			draw_line(Vector2(rib_r.position.x, rib_r.position.y + 1.0), Vector2(rib_r.end.x, rib_r.position.y + 1.0), Color(0.36, 0.39, 0.42, 0.78), 1.0)
			draw_line(Vector2(rib_r.position.x, rib_r.end.y - 1.0), Vector2(rib_r.end.x, rib_r.end.y - 1.0), Color(0.02, 0.024, 0.028, 0.95), 1.0)

		var vent_w := minf(68.0, inset.size.x * 0.22)
		var vent_x := (inset.end.x - vent_w - 14.0) if left else (inset.position.x + 14.0)
		for slot in 5:
			var vy := inset.position.y + 24.0 + float(slot) * ((inset.size.y - 36.0) / 5.0)
			draw_line(Vector2(vent_x, vy), Vector2(vent_x + vent_w, vy), Color(0.022, 0.025, 0.028, 1.0), 3.2)
			draw_line(Vector2(vent_x, vy - 1.2), Vector2(vent_x + vent_w, vy - 1.2), Color(0.30, 0.33, 0.36, 0.55), 1.0)

		var piston_x := (inset.position.x + 22.0) if left else (inset.end.x - 36.0)
		if inset.size.x > 140.0:
			var cyl := Rect2(piston_x, inset.position.y + 22.0, 14.0, maxf(10.0, inset.size.y - 32.0))
			draw_rect(cyl, Color(0.032, 0.036, 0.040, 0.98))
			draw_rect(cyl, Color(0.24, 0.27, 0.30, 0.85), false, 1.0)
			draw_rect(Rect2(cyl.position.x + 4.0, cyl.position.y + 4.0, 6.0, cyl.size.y - 8.0), Color(0.38, 0.41, 0.44, 0.85))
			draw_rect(Rect2(cyl.position.x + 2.0, cyl.position.y + cyl.size.y * 0.45, 10.0, 8.0), K.AMBER)

		for pt in [
			Vector2(bay.position.x + 11.0, bay.position.y + 11.0),
			Vector2(bay.end.x - 11.0, bay.position.y + 11.0),
			Vector2(bay.position.x + 11.0, bay.end.y - 11.0),
			Vector2(bay.end.x - 11.0, bay.end.y - 11.0),
		]:
			_bolt(pt, 2.2)


func _draw_chamfer_plate(r: Rect2, cut: float, fill: Color, border: Color) -> void:
	var c := clampf(cut, 1.0, minf(r.size.x, r.size.y) * 0.45)
	var pts := PackedVector2Array([
		Vector2(r.position.x + c, r.position.y),
		Vector2(r.end.x - c, r.position.y),
		Vector2(r.end.x, r.position.y + c),
		Vector2(r.end.x, r.end.y - c),
		Vector2(r.end.x - c, r.end.y),
		Vector2(r.position.x + c, r.end.y),
		Vector2(r.position.x, r.end.y - c),
		Vector2(r.position.x, r.position.y + c),
	])
	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, border, 1.2, true)
	draw_line(pts[0], pts[1], Color(0.46, 0.49, 0.52, border.a * 0.85), 1.2)


func _draw_corner_brackets(r: Rect2, col: Color, arm: float) -> void:
	if arm <= 2.0:
		return
	var tl := r.position + Vector2(1.0, 1.0)
	var tr := Vector2(r.end.x - 1.0, r.position.y + 1.0)
	var bl := Vector2(r.position.x + 1.0, r.end.y - 1.0)
	var br := r.end - Vector2(1.0, 1.0)
	draw_line(tl, tl + Vector2(arm, 0.0), col, 1.6)
	draw_line(tl, tl + Vector2(0.0, arm), col, 1.6)
	draw_line(tr, tr - Vector2(arm, 0.0), col, 1.6)
	draw_line(tr, tr + Vector2(0.0, arm), col, 1.6)
	draw_line(bl, bl + Vector2(arm, 0.0), col, 1.6)
	draw_line(bl, bl - Vector2(0.0, arm), col, 1.6)
	draw_line(br, br - Vector2(arm, 0.0), col, 1.6)
	draw_line(br, br - Vector2(0.0, arm), col, 1.6)


func _bolt(at: Vector2, radius: float) -> void:
	draw_circle(at, radius + 1.2, Color(0.022, 0.025, 0.028, 1.0))
	draw_circle(at, radius, Color(0.38, 0.41, 0.44, 1.0))
	draw_arc(at, radius, PI * 0.8, PI * 1.8, 8, Color(0.56, 0.60, 0.64, 0.85), 1.0)
	draw_line(at - Vector2(radius * 0.68, 0.0), at + Vector2(radius * 0.68, 0.0), Color(0.10, 0.12, 0.14, 1.0), 1.0)
