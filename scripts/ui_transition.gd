extends Control

const K = preload("res://scripts/hub_kit.gd")
const ENTER := 0.16
const EXIT := 0.09
const SCREEN_ENTER := 0.24
const SCREEN_EXIT := 0.16

var kind := "panels"
var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


static func attach(target: Node, mode: String) -> Control:
	clear(target)
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
	if target == null or not is_instance_valid(target):
		return
	var effect := target.get_node_or_null("PageMotion")
	if effect != null:
		if effect.get_parent() != null:
			effect.get_parent().remove_child(effect)
		effect.queue_free()


func _draw() -> void:
	if progress >= 0.999:
		return
	if kind == "hatch":
		_draw_screen_veil()
		return
	var regions := _regions()
	var total := regions.size()
	for i in total:
		var delay := minf(float(i) * 0.045, 0.18) if total > 1 else 0.0
		var opened := clampf((progress - delay) / maxf(0.01, 1.0 - delay), 0.0, 1.0)
		_draw_panel_pulse(regions[i], opened)


func _draw_screen_veil() -> void:
	var veil_a := clampf((1.0 - progress) * 0.92, 0.0, 0.92)
	if veil_a > 0.01:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.045, 0.050, 0.056, veil_a), true)
	var pulse_a := sin(clampf(progress, 0.0, 1.0) * PI) * 0.55
	if pulse_a > 0.02:
		draw_line(Vector2(0.0, float(K.TOP_H)), Vector2(size.x * progress, float(K.TOP_H)), Color(K.AMBER_HI, pulse_a), 1.5)
		draw_line(Vector2(size.x * (1.0 - progress), size.y - float(K.BOT_H)), Vector2(size.x, size.y - float(K.BOT_H)), Color(K.AMBER, pulse_a * 0.8), 1.5)


func _regions() -> Array[Rect2]:
	var result: Array[Rect2] = []
	_collect_regions(get_parent(), result)
	result.sort_custom(func(a: Rect2, b: Rect2) -> bool:
		if absf(a.position.y - b.position.y) > 36.0:
			return a.position.y < b.position.y
		return a.position.x < b.position.x)
	return result


func _collect_regions(root: Node, result: Array[Rect2]) -> void:
	if root == null:
		return
	for child in root.get_children():
		if child == self or (child is Control and not child.visible) or child.name == "PageMotion":
			continue
		if child is PanelContainer and child.size.x >= 100.0 and child.size.y >= 34.0:
			var global_rect: Rect2 = child.get_global_rect()
			var local_pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * global_rect.position
			var local_scale := get_global_transform_with_canvas().get_scale()
			var rect := Rect2(local_pos, global_rect.size / local_scale).intersection(Rect2(Vector2.ZERO, size))
			if rect.size.x > 4.0 and rect.size.y > 4.0:
				result.append(rect)
			continue
		_collect_regions(child, result)


func _draw_panel_pulse(rect: Rect2, opened: float) -> void:
	if rect.size.x < 8.0 or rect.size.y < 8.0 or opened >= 0.999:
		return
	var fade := clampf(1.0 - opened, 0.0, 1.0)
	if fade > 0.01:
		draw_rect(rect, Color(0.045, 0.050, 0.056, fade * 0.46), true)
	var flash := sin(clampf(opened, 0.0, 1.0) * PI)
	if flash <= 0.02:
		return
	draw_rect(rect.grow(-0.5), Color(K.AMBER_HI.r, K.AMBER_HI.g, K.AMBER_HI.b, flash * 0.36), false, 1.0)
	var sweep_w := rect.size.x * clampf(opened * 1.25, 0.0, 1.0)
	draw_line(rect.position + Vector2(1.0, 1.0), rect.position + Vector2(maxf(2.0, sweep_w - 1.0), 1.0), Color(K.AMBER_HI, flash * 0.85), 1.5)
	_draw_corner_ticks(rect, Color(K.AMBER_HI, flash * 0.82), minf(10.0, minf(rect.size.x, rect.size.y) * 0.18))


func _draw_corner_ticks(r: Rect2, col: Color, arm: float) -> void:
	if arm <= 2.0 or col.a <= 0.01:
		return
	var tl := r.position + Vector2(1.0, 1.0)
	var tr := Vector2(r.end.x - 1.0, r.position.y + 1.0)
	var bl := Vector2(r.position.x + 1.0, r.end.y - 1.0)
	var br := r.end - Vector2(1.0, 1.0)
	draw_line(tl, tl + Vector2(arm, 0.0), col, 1.4)
	draw_line(tl, tl + Vector2(0.0, arm), col, 1.4)
	draw_line(tr, tr - Vector2(arm, 0.0), col, 1.4)
	draw_line(tr, tr + Vector2(0.0, arm), col, 1.4)
	draw_line(bl, bl + Vector2(arm, 0.0), col, 1.4)
	draw_line(bl, bl - Vector2(0.0, arm), col, 1.4)
	draw_line(br, br - Vector2(arm, 0.0), col, 1.4)
	draw_line(br, br - Vector2(0.0, arm), col, 1.4)
