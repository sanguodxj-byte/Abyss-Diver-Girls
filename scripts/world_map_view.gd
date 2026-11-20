extends Control
## 纯二维矢量侦察图：预烘焙布局、事件驱动重绘，无 3D 视口。
signal map_selected(id: String)
signal map_locked(id: String)

const Data = preload("res://scripts/world_map_2d.gd")
const WC = preload("res://scripts/world_city.gd")
const UI = preload("res://scripts/ui.gd")
const ZOOMS := [1.0, 1.5, 2.2, 3.2, 4.8]
const HEADER_H := 48.0
const FOOTER_H := 52.0
const AMBER := Color("dcb475")
const CREAM := Color("e4e8df")
const DIM := Color("a1b5b3")
const INK := Color("16191a")
const GREEN := Color("8dddb1")
const CYAN := Color("8bcbd7")

var meta := {"maps": {}}
var selected := ""
var hover := ""
var available := {}
var quests := {}
var zoom_i := 0
var offset := Data.RECT.get_center()
var chart: ArrayMesh
var controls: HBoxContainer
var ready_map := false
var build_ms := 0.0
var _press := false
var _moved := false
var _button := 0
var _press_pos := Vector2.ZERO
var _press_world := Vector2.ZERO
var _label_rects := {}
var _occupied_rects: Array[Rect2] = []
var _visible_markers: Array[Dictionary] = []
var annotation_labels: Array[Dictionary] = []


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for id: String in GameData.map_ids():
		if WC.is_surface(id) and not bool(GameData.map_data(id).get("hidden", false)):
			meta.maps[id] = {"poly": WC.zone_poly_world(id), "origin": WC.origin(id), "name": str(GameData.map_data(id).name)}


func _ready() -> void:
	controls = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 5)
	add_child(controls)
	for spec in [["−", "ZoomOut"], ["+", "ZoomIn"], [Loc.t("选区", "Focus"), "Center"], [Loc.t("全域", "Region"), "Overview"]]:
		var b := Button.new()
		b.text = spec[0]
		b.name = spec[1]
		b.custom_minimum_size = Vector2(36, 30)
		b.add_theme_font_size_override("font_size", 12)
		for state in ["normal", "hover", "pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.065, 0.075, 0.08, 0.94) if state == "normal" else Color(0.17, 0.16, 0.13, 0.96)
			style.border_color = Color(0.36, 0.38, 0.36, 0.8) if state == "normal" else AMBER
			style.set_border_width_all(1)
			style.content_margin_left = 10
			style.content_margin_right = 10
			b.add_theme_stylebox_override(state, style)
		b.add_theme_color_override("font_color", CREAM)
		var key: String = spec[1]
		b.pressed.connect(func():
			match key:
				"ZoomOut": zoom_to(zoom_i - 1, size * 0.5)
				"ZoomIn": zoom_to(zoom_i + 1, size * 0.5)
				"Center": center_on(selected)
				"Overview": overview()
		)
		controls.add_child(b)
	resized.connect(_resize)
	visibility_changed.connect(_visibility)
	_visibility.call_deferred()


func _visibility() -> void:
	_press = false
	if is_visible_in_tree() and not ready_map:
		var started := Time.get_ticks_usec()
		chart = load(Data.PATH) as ArrayMesh
		if chart == null:
			push_error("Missing 2D region data: run --worldmap_2d_bake")
			return
		meta.maps = chart.get_meta("sectors")
		ready_map = true
		build_ms = (Time.get_ticks_usec() - started) / 1000.0
	_resize()


func _resize() -> void:
	if controls:
		controls.position = Vector2(maxf(12, size.x - controls.get_combined_minimum_size().x - 14), 12)
	request_render()


func request_render() -> void:
	_label_rects.clear()
	_visible_markers.clear()
	annotation_labels.clear()
	queue_redraw()


func _map_center() -> Vector2:
	return plot_rect().get_center()


func plot_rect() -> Rect2:
	return Rect2(Vector2(8, HEADER_H + 6), Vector2(maxf(1, size.x - 16), maxf(1, size.y - HEADER_H - FOOTER_H - 12)))


func _map_transform() -> Transform2D:
	var z := zoom()
	return Transform2D(Vector2(0, -z), Vector2(z, 0), _map_center() - Vector2(offset.y, -offset.x) * z)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("202a29"))
	if not ready_map: return
	draw_mesh(chart, null, _map_transform())
	# 薄坐标网格只用于读图，不随时间动画。
	for x in range(int(Data.RECT.position.x), int(Data.RECT.end.x), 100):
		draw_line(to_screen(Vector2(x, Data.RECT.position.y)), to_screen(Vector2(x, Data.RECT.end.y)), Color(0.62, 0.7, 0.62, 0.07), 1, true)
	for y in range(int(Data.RECT.position.y), int(Data.RECT.end.y), 100):
		draw_line(to_screen(Vector2(Data.RECT.position.x, y)), to_screen(Vector2(Data.RECT.end.x, y)), Color(0.62, 0.7, 0.62, 0.07), 1, true)
	_draw_overlay()


func map_ids() -> Array:
	return meta.maps.keys()

func map_poly_world(id: String) -> PackedVector2Array:
	return meta.maps.get(id, {}).get("poly", PackedVector2Array())

func map_rect_world(id: String) -> Rect2:
	return WC._poly_rect(map_poly_world(id))

func map_poly(id: String) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in map_poly_world(id):
		result.append(to_screen(p))
	return result

func map_rect(id: String) -> Rect2:
	return WC._poly_rect(map_poly(id))

func to_screen(world: Vector2) -> Vector2:
	return _map_transform() * world

func to_world(screen: Vector2) -> Vector2:
	return _map_transform().affine_inverse() * screen

func game_to_screen(id: String, x: float, z: float) -> Vector2:
	return to_screen(WC.origin(id) + Vector2(x, z))

func map_at(screen: Vector2) -> String:
	if not plot_rect().has_point(screen):
		return ""
	for id: String in _label_rects:
		if (_label_rects[id] as Rect2).has_point(screen):
			return id
	var point := to_world(screen)
	for id: String in map_ids():
		if Geometry2D.is_point_in_polygon(point, map_poly_world(id)):
			return id
	return ""

func set_state(avail: Dictionary, active_quests: Dictionary, sel: String) -> void:
	available = avail
	quests = active_quests
	selected = sel
	request_render()

func select(id: String) -> void:
	selected = id
	request_render()

func zoom_to(i: int, anchor: Vector2) -> void:
	var point := to_world(anchor)
	zoom_i = clampi(i, 0, ZOOMS.size() - 1)
	offset += point - to_world(anchor)
	_clamp()
	request_render()

func zoom() -> float:
	var fit := minf(maxf(1, plot_rect().size.x - 24) / Data.RECT.size.y, plot_rect().size.y / Data.RECT.size.x)
	return maxf(0.01, fit) * ZOOMS[zoom_i]

func center_on(id: String) -> void:
	if not meta.maps.has(id): return
	offset = WC.centroid(map_poly_world(id))
	zoom_i = maxi(2, zoom_i)
	request_render()

func overview() -> void:
	offset = Data.RECT.get_center()
	zoom_i = 0
	request_render()

func _clamp() -> void:
	offset = offset.clamp(Data.RECT.position, Data.RECT.end)

func _can_pick(id: String) -> bool:
	return not id.is_empty() and bool(available.get(id, false))

func click(screen: Vector2) -> void:
	var id := map_at(screen)
	if id.is_empty():
		return
	if not _can_pick(id):
		map_locked.emit(id)
		return
	select(id)
	map_selected.emit(id)

func set_hover(id: String) -> void:
	if hover == id:
		return
	hover = id
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _can_pick(id) else Control.CURSOR_ARROW
	request_render()


func _get_tooltip(at: Vector2) -> String:
	for marker: Dictionary in _visible_markers:
		if (marker.rect as Rect2).grow(5).has_point(at):
			return str(marker.text)
	for label: Dictionary in annotation_labels:
		if (label.rect as Rect2).has_point(at):
			return str(label.text)
	var id := map_at(at)
	return "" if id.is_empty() else Loc.map_label(str(meta.maps[id].name))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_to(zoom_i + (1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1), event.position)
			accept_event()
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				grab_focus()
				_press = true
				_moved = false
				_button = event.button_index
				_press_pos = event.position
				_press_world = to_world(event.position)
			else:
				if _press and not _moved and _button == MOUSE_BUTTON_LEFT:
					click(event.position)
				_press = false
			accept_event()
	elif event is InputEventMouseMotion:
		if _press:
			_moved = _moved or event.position.distance_to(_press_pos) > 4.0
			if _moved:
				offset += _press_world - to_world(event.position)
				_clamp()
				request_render()
		else:
			set_hover(map_at(event.position))
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_HOME:
			overview()
		elif event.keycode in [KEY_LEFT, KEY_RIGHT]:
			var ids := map_ids()
			var next := posmod(ids.find(hover if not hover.is_empty() else selected) + (1 if event.keycode == KEY_RIGHT else -1), ids.size())
			center_on(ids[next])
			set_hover(ids[next])
		elif event.keycode in [KEY_ENTER, KEY_SPACE]:
			click(_map_center())
		else:
			return
		accept_event()
	elif event is InputEventMagnifyGesture:
		zoom_to(zoom_i + (1 if event.factor > 1.0 else -1), event.position)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and not _press:
		set_hover("")


func _draw_overlay() -> void:
	var font := get_theme_default_font()
	_label_rects.clear()
	annotation_labels.clear()
	_occupied_rects.clear()
	_visible_markers.clear()
	# 先保留边缘工具和所有符号的空间，再排文字，避免文字挡住其他点位。
	var compass := Vector2(32, size.y - FOOTER_H - 23)
	_occupied_rects.append(Rect2(compass - Vector2(32, 20), Vector2(54, 40)))
	var bar_len := 50.0 * zoom()
	var show_scale := bar_len > 20 and bar_len < size.x * 0.3
	var scale_at := Vector2(size.x - bar_len - 24, size.y - FOOTER_H - 18)
	if show_scale:
		_occupied_rects.append(Rect2(scale_at - Vector2(8, 22), Vector2(bar_len + 16, 30)))
	_collect_markers()
	for marker: Dictionary in _visible_markers:
		_occupied_rects.append(marker.rect)
	for id: String in map_ids():
		var poly := map_poly(id)
		if id == selected or id == hover:
			draw_colored_polygon(poly, Color(0.82, 0.62, 0.29, 0.06 if id == selected else 0.035))
		var col := AMBER if id == selected else (CREAM if id == hover else Color(0.78, 0.80, 0.78, 0.54))
		if zoom_i < 2 or id == selected or id == hover:
			for i in poly.size():
				draw_dashed_line(poly[i], poly[(i + 1) % poly.size()], Color(col.r, col.g, col.b, 0.8 if id == selected else 0.28), 1.2 if id == selected else 0.7, 6.0, true, true)
	# 选区名称优先，随后才排其他地区和点位标签。
	var ids := map_ids()
	if ids.has(selected):
		ids.erase(selected)
		ids.push_front(selected)
	for id: String in ids:
		if id == selected and zoom_i >= 2: continue
		var center := to_screen(WC.centroid(map_poly_world(id)))
		var title := Loc.map_label(str(meta.maps[id].name))
		if bool(quests.get(id, false)): title = "• " + title
		if not _can_pick(id): title += Loc.t(" · 未解锁", " · Locked")
		var fs := 15 if id == selected else 13
		var extent := Vector2(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 20, 27)
		var candidates: Array[Vector2] = [center - Vector2(extent.x * 0.5, 37), center + Vector2(-extent.x * 0.5, 12)]
		var rect := _place_label(extent, candidates)
		if not rect.has_area(): continue
		var col := AMBER if id == selected else (CREAM if id == hover else DIM)
		draw_line(center, rect.get_center(), col, 1, true)
		draw_arc(center, 4, 0, TAU, 18, col, 1.2, true)
		draw_style_box(_label_style(id == selected), rect)
		draw_string(font, rect.position + Vector2(10, 19), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		_label_rects[id] = rect
		annotation_labels.append({"rect": rect, "text": title, "kind": "sector"})
	for marker: Dictionary in _visible_markers:
		if marker.kind == "gate":
			draw_line(marker.a, marker.b, INK, 7, true)
			draw_line(marker.a, marker.b, CYAN, 3, true)
		else:
			_draw_symbol(marker.screen, marker.kind, marker.color)
	for marker: Dictionary in _visible_markers:
		_draw_marker_label(font, marker)
	var north := (to_screen(offset + Vector2(0, -60)) - to_screen(offset)).normalized()
	draw_circle(compass, 17, Color(0.08, 0.15, 0.17, 0.92))
	draw_line(compass - north * 9, compass + north * 12, CREAM, 1.6, true)
	draw_string(font, compass + north * 25 + Vector2(-4, 4), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CREAM)
	if show_scale:
		draw_line(scale_at, scale_at + Vector2(bar_len, 0), CREAM, 1, true)
		for dx in [0.0, bar_len]: draw_line(scale_at + Vector2(dx, -3), scale_at + Vector2(dx, 3), CREAM, 1, true)
		draw_string(font, scale_at + Vector2(bar_len * 0.5 - 14, -6), "50 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, CREAM)
	var heading := Loc.t("地区侦察图", "REGIONAL MAP") if zoom_i < 2 or selected.is_empty() else Loc.map_label(str(meta.maps.get(selected, {}).get("name", "")))
	draw_rect(Rect2(0, 0, size.x, HEADER_H), Color(0.07, 0.09, 0.09, 0.94))
	draw_string(font, Vector2(18, 29), heading, HORIZONTAL_ALIGNMENT_LEFT, maxf(0, controls.position.x - 30), 16, CREAM)
	_draw_footer(font)


func _collect_markers() -> void:
	if zoom_i < 2 or not meta.maps.has(selected): return
	var sector: Dictionary = meta.maps[selected]
	for entry: Dictionary in sector.get("extracts", []):
		_add_marker(entry.position, Loc.map_label(str(entry.name)), "extract", GREEN)
	for entry: Dictionary in sector.get("pois", []):
		_add_marker(entry.position, Loc.map_label(str(entry.name)), "poi", AMBER)
	for entry: Dictionary in sector.get("landmarks", []):
		# 沿用战斗内战术图的地标命名，位置来自同一地区布局。
		var title := Loc.landmark_name(str(entry.type), str(UI.BigMap.LM_NAMES.get(entry.type, entry.type)))
		_add_marker(entry.position, title, "landmark", CREAM)
	for gate: Dictionary in sector.get("gates", []):
		var p := to_screen(gate.position)
		var tangent: Vector2 = gate.tangent
		var a := to_screen(gate.position - tangent * 9)
		var b := to_screen(gate.position + tangent * 9)
		var rect := Rect2(a, Vector2.ZERO).expand(b).grow(5)
		if not plot_rect().encloses(rect): continue
		var title := Loc.t("通往 ", "To ") + Loc.map_label(str(meta.maps[gate.to].name))
		_visible_markers.append({"screen": p, "rect": rect, "text": title, "kind": "gate", "color": CYAN, "a": a, "b": b})


func _add_marker(at: Vector2, title: String, kind: String, color: Color) -> void:
	var p := to_screen(at)
	var rect := Rect2(p - Vector2(7, 7), Vector2(14, 14))
	if plot_rect().encloses(rect):
		_visible_markers.append({"screen": p, "rect": rect, "text": title, "kind": kind, "color": color})


func _place_label(extent: Vector2, candidates: Array[Vector2]) -> Rect2:
	for at: Vector2 in candidates:
		var rect := Rect2(at, extent)
		if not plot_rect().encloses(rect): continue
		var clear := true
		for taken: Rect2 in _occupied_rects:
			if taken.grow(2).intersects(rect):
				clear = false
				break
		if clear:
			_occupied_rects.append(rect)
			return rect
	return Rect2()


func _draw_marker_label(font: Font, marker: Dictionary) -> void:
	var text: String = marker.text
	var extent := Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 6, font.get_height(12) + 4)
	var p: Vector2 = marker.screen
	var body: Rect2 = marker.rect
	var candidates: Array[Vector2] = [
		Vector2(body.end.x + 3, p.y - extent.y * 0.5),
		Vector2(body.position.x - extent.x - 3, p.y - extent.y * 0.5),
		Vector2(p.x - extent.x * 0.5, body.position.y - extent.y - 3),
		Vector2(p.x - extent.x * 0.5, body.end.y + 3),
		Vector2(body.end.x + 3, body.position.y - extent.y - 3),
		Vector2(body.position.x - extent.x - 3, body.position.y - extent.y - 3),
		Vector2(body.end.x + 3, body.end.y + 3),
		Vector2(body.position.x - extent.x - 3, body.end.y + 3)]
	var rect := _place_label(extent, candidates)
	if not rect.has_area(): return # 符号保留；悬停仍能查看完整名称。
	var baseline := rect.position + Vector2(3, font.get_ascent(12) + 2)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, INK)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, marker.color)
	annotation_labels.append({"rect": rect, "text": text, "kind": marker.kind})


func _draw_symbol(p: Vector2, kind: String, color: Color) -> void:
	draw_circle(p, 6, INK, true, -1, true)
	match kind:
		"poi":
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4), p + Vector2(4, 0), p + Vector2(0, 4), p + Vector2(-4, 0)]), color)
		"landmark":
			draw_rect(Rect2(p - Vector2(3.5, 3.5), Vector2(7, 7)), color, false, 1.4)
		"gate":
			draw_line(p - Vector2(0, 5), p + Vector2(0, 5), color, 3, true)
		_:
			draw_circle(p, 3.2, color, true, -1, true)


func _draw_footer(font: Font) -> void:
	draw_rect(Rect2(0, size.y - FOOTER_H, size.x, FOOTER_H), Color(0.055, 0.065, 0.07, 0.96))
	draw_line(Vector2(0, size.y - FOOTER_H), Vector2(size.x, size.y - FOOTER_H), Color(0.4, 0.48, 0.45, 0.3), 1)
	var x := 22.0
	for spec: Array in [["extract", GREEN, Loc.t("撤离候选点", "Extraction site")], ["poi", AMBER, Loc.t("重点遗迹", "Point of interest")], ["landmark", CREAM, Loc.t("地标", "Landmark")], ["gate", CYAN, Loc.t("跨区通道", "Transit")]]:
		_draw_symbol(Vector2(x, size.y - 35), spec[0], spec[1])
		draw_string(font, Vector2(x + 11, size.y - 31), spec[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
		x += font.get_string_size(spec[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 34
	var hint := Loc.t("单击选区 · 拖动平移 · 滚轮缩放 · 放大查看点位", "Select sector · Drag to pan · Scroll to zoom · Zoom in for sites")
	if zoom_i >= 2:
		hint = Loc.t("单击选区 · 拖动平移 · 滚轮缩放 · 悬停查看名称", "Select sector · Drag to pan · Scroll to zoom · Hover for names")
	draw_string(font, Vector2(18, size.y - 10), hint, HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 11, DIM)


func _label_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.075, 0.08, 0.89)
	style.border_color = AMBER if active else Color(0.54, 0.57, 0.55, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	return style
