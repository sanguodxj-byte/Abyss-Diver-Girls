extends Control
## 纯二维矢量侦察图：预烘焙布局、事件驱动重绘，无 3D 视口。
signal map_selected(id: String)
signal map_locked(id: String)
signal markers_changed()

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
const PIN_COLOR_ORDER := ["amber", "red", "cyan", "green", "purple"]

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
var pin_mode := false
var _press := false
var _moved := false
var _button := 0
var _press_pos := Vector2.ZERO
var _press_world := Vector2.ZERO
var _label_rects := {}
var _occupied_rects: Array[Rect2] = []
var _visible_markers: Array[Dictionary] = []
var annotation_labels: Array[Dictionary] = []
var _hover_marker_id := ""
var _pin_btn: Button
var _editor: PanelContainer
var _ed_title: Label
var _ed_input: LineEdit
var _ed_del: Button
var _ed_save: Button
var _ed_cancel: Button
var _ed_color_btns := {}
var _ed_color := "amber"
var _ed_marker_id := ""
var _ed_world := Vector2.ZERO
var _ed_sector := ""


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
	for spec in [["−", "ZoomOut"], ["+", "ZoomIn"], [Loc.t("选区", "Focus"), "Center"], [Loc.t("全域", "Region"), "Overview"], [Loc.t("打标记", "Pin"), "PinMode"]]:
		var b := Button.new()
		b.text = spec[0]
		b.name = spec[1]
		b.custom_minimum_size = Vector2(36, 30)
		b.add_theme_font_size_override("font_size", 12)
		_style_tool_btn(b, false)
		var key: String = spec[1]
		if key == "PinMode":
			_pin_btn = b
			b.tooltip_text = Loc.t("开启后左键点击地图任意区域打点写字；普通模式下也可右键直接打点", "Toggle pin mode: left-click anywhere to place & annotate (or right-click anytime)")
		b.pressed.connect(func():
			match key:
				"ZoomOut": zoom_to(zoom_i - 1, size * 0.5)
				"ZoomIn": zoom_to(zoom_i + 1, size * 0.5)
				"Center": center_on(selected)
				"Overview": overview()
				"PinMode": set_pin_mode(not pin_mode)
		)
		controls.add_child(b)
	_build_editor()
	_refresh_pin_btn()
	resized.connect(_resize)
	visibility_changed.connect(_visibility)
	_visibility.call_deferred()


func _style_tool_btn(b: Button, active: bool) -> void:
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		if active:
			style.bg_color = Color(0.26, 0.21, 0.12, 0.96) if state == "normal" else Color(0.32, 0.26, 0.14, 0.98)
			style.border_color = AMBER
		else:
			style.bg_color = Color(0.065, 0.075, 0.08, 0.94) if state == "normal" else Color(0.17, 0.16, 0.13, 0.96)
			style.border_color = Color(0.36, 0.38, 0.36, 0.8) if state == "normal" else AMBER
		style.set_border_width_all(1)
		style.content_margin_left = 10
		style.content_margin_right = 10
		b.add_theme_stylebox_override(state, style)
	b.add_theme_color_override("font_color", AMBER if active else CREAM)


func _refresh_pin_btn() -> void:
	if _pin_btn == null:
		return
	var cnt: int = GameData.map_markers.size()
	var base := Loc.t("打标记", "Pin")
	_pin_btn.text = ("%s (%d)" % [base, cnt]) if cnt > 0 else base
	_style_tool_btn(_pin_btn, pin_mode)
	if controls:
		controls.position = Vector2(maxf(12, size.x - controls.get_combined_minimum_size().x - 14), 12)


func set_pin_mode(on: bool) -> void:
	if pin_mode == on:
		return
	pin_mode = on
	if not pin_mode and _editor != null and _editor.visible and _ed_marker_id == "":
		_close_editor()
	_refresh_pin_btn()
	_update_cursor()
	request_render()


func _build_editor() -> void:
	_editor = PanelContainer.new()
	_editor.name = "MarkerEditor"
	_editor.visible = false
	_editor.mouse_filter = Control.MOUSE_FILTER_STOP
	_editor.custom_minimum_size = Vector2(252, 0)
	var pst := StyleBoxFlat.new()
	pst.bg_color = Color(0.058, 0.072, 0.080, 0.97)
	pst.border_color = AMBER
	pst.set_border_width_all(1)
	pst.content_margin_left = 10
	pst.content_margin_right = 10
	pst.content_margin_top = 8
	pst.content_margin_bottom = 8
	_editor.add_theme_stylebox_override("panel", pst)
	add_child(_editor)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 7)
	_editor.add_child(vb)

	var top_hb := HBoxContainer.new()
	top_hb.add_theme_constant_override("separation", 6)
	vb.add_child(top_hb)
	_ed_title = Label.new()
	_ed_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ed_title.add_theme_font_size_override("font_size", 12)
	_ed_title.add_theme_color_override("font_color", AMBER)
	top_hb.add_child(_ed_title)
	var x_btn := Button.new()
	x_btn.text = "×"
	x_btn.custom_minimum_size = Vector2(22, 20)
	x_btn.add_theme_font_size_override("font_size", 12)
	_style_tool_btn(x_btn, false)
	x_btn.pressed.connect(_close_editor)
	top_hb.add_child(x_btn)

	var col_hb := HBoxContainer.new()
	col_hb.add_theme_constant_override("separation", 6)
	vb.add_child(col_hb)
	var col_lbl := Label.new()
	col_lbl.text = Loc.t("颜色", "Color")
	col_lbl.add_theme_font_size_override("font_size", 11)
	col_lbl.add_theme_color_override("font_color", DIM)
	col_hb.add_child(col_lbl)
	_ed_color_btns.clear()
	for ck: String in PIN_COLOR_ORDER:
		var cb := Button.new()
		cb.name = "Color_" + ck
		cb.custom_minimum_size = Vector2(24, 18)
		cb.focus_mode = Control.FOCUS_NONE
		var k_cap := ck
		cb.pressed.connect(func(): _set_editor_color(k_cap))
		col_hb.add_child(cb)
		_ed_color_btns[ck] = cb
	_set_editor_color("amber")

	_ed_input = LineEdit.new()
	_ed_input.name = "MarkerInput"
	_ed_input.max_length = 32
	_ed_input.custom_minimum_size = Vector2(228, 30)
	_ed_input.add_theme_font_size_override("font_size", 13)
	_ed_input.add_theme_color_override("font_color", CREAM)
	_ed_input.add_theme_color_override("font_placeholder_color", Color(0.62, 0.68, 0.66, 0.72))
	var ist := StyleBoxFlat.new()
	ist.bg_color = Color(0.09, 0.11, 0.12, 0.98)
	ist.border_color = Color(0.42, 0.46, 0.44, 0.85)
	ist.set_border_width_all(1)
	ist.content_margin_left = 8
	ist.content_margin_right = 8
	var ist_f := ist.duplicate() as StyleBoxFlat
	ist_f.border_color = AMBER
	_ed_input.add_theme_stylebox_override("normal", ist)
	_ed_input.add_theme_stylebox_override("focus", ist_f)
	_ed_input.text_submitted.connect(func(_t: String): _commit_editor())
	_ed_input.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
			_close_editor()
			_ed_input.accept_event()
	)
	vb.add_child(_ed_input)

	var act_hb := HBoxContainer.new()
	act_hb.add_theme_constant_override("separation", 6)
	vb.add_child(act_hb)
	_ed_del = Button.new()
	_ed_del.name = "MarkerDelete"
	_ed_del.custom_minimum_size = Vector2(54, 26)
	_ed_del.add_theme_font_size_override("font_size", 12)
	for st_name in ["normal", "hover", "pressed"]:
		var dst := StyleBoxFlat.new()
		dst.bg_color = Color(0.22, 0.08, 0.08, 0.94) if st_name == "normal" else Color(0.34, 0.12, 0.12, 0.98)
		dst.border_color = Color("ef5a5a")
		dst.set_border_width_all(1)
		dst.content_margin_left = 8
		dst.content_margin_right = 8
		_ed_del.add_theme_stylebox_override(st_name, dst)
	_ed_del.add_theme_color_override("font_color", Color("ff9a9a"))
	_ed_del.pressed.connect(_delete_editor_marker)
	act_hb.add_child(_ed_del)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_hb.add_child(sp)

	_ed_cancel = Button.new()
	_ed_cancel.name = "MarkerCancel"
	_ed_cancel.custom_minimum_size = Vector2(54, 26)
	_ed_cancel.add_theme_font_size_override("font_size", 12)
	_style_tool_btn(_ed_cancel, false)
	_ed_cancel.pressed.connect(_close_editor)
	act_hb.add_child(_ed_cancel)

	_ed_save = Button.new()
	_ed_save.name = "MarkerSave"
	_ed_save.custom_minimum_size = Vector2(58, 26)
	_ed_save.add_theme_font_size_override("font_size", 12)
	_style_tool_btn(_ed_save, true)
	_ed_save.pressed.connect(_commit_editor)
	act_hb.add_child(_ed_save)


func _set_editor_color(ck: String) -> void:
	_ed_color = ck if GameData.MAP_MARKER_COLORS.has(ck) else "amber"
	for k: String in _ed_color_btns:
		var b: Button = _ed_color_btns[k]
		var col: Color = GameData.marker_color(k)
		for st_name in ["normal", "hover", "pressed"]:
			var st := StyleBoxFlat.new()
			st.bg_color = col if st_name == "normal" else col.lightened(0.14)
			st.border_color = Color.WHITE if k == _ed_color else Color(0.12, 0.14, 0.15, 0.9)
			st.set_border_width_all(2 if k == _ed_color else 1)
			b.add_theme_stylebox_override(st_name, st)
	if _editor != null and _editor.visible:
		request_render()


func _sector_at_world(world_pt: Vector2) -> String:
	for id: String in map_ids():
		if Geometry2D.is_point_in_polygon(world_pt, map_poly_world(id)):
			return id
	return ""


func open_marker_editor(screen_pos: Vector2, existing_id := "") -> void:
	if _editor == null or not ready_map:
		return
	var found: Dictionary = {}
	if not existing_id.is_empty():
		for m in GameData.map_markers:
			if typeof(m) == TYPE_DICTIONARY and str(m.get("id", "")) == existing_id:
				found = m
				break
	if not found.is_empty():
		_ed_marker_id = str(found.get("id", ""))
		_ed_world = Vector2(float(found.get("wx", 0.0)), float(found.get("wz", 0.0)))
		_ed_sector = str(found.get("map_id", ""))
		_set_editor_color(str(found.get("color", "amber")))
		_ed_input.text = str(found.get("text", ""))
		_ed_del.visible = true
	else:
		_ed_marker_id = ""
		_ed_world = to_world(screen_pos)
		_ed_sector = _sector_at_world(_ed_world)
		_ed_input.text = ""
		_ed_del.visible = false
	var sec_name := Loc.map_label(str(meta.maps.get(_ed_sector, {}).get("name", ""))) if meta.maps.has(_ed_sector) else Loc.t("周边区域", "Outer Area")
	var action_lbl := Loc.t("编辑标记", "Edit Pin") if not _ed_marker_id.is_empty() else Loc.t("新标记", "New Pin")
	_ed_title.text = "%s · %s" % [action_lbl, sec_name]
	_ed_input.placeholder_text = Loc.t("输入标记文字（回车保存）", "Enter note (Enter to save)")
	_ed_del.text = Loc.t("删除", "Delete")
	_ed_cancel.text = Loc.t("取消", "Cancel")
	_ed_save.text = Loc.t("保存", "Save")
	_editor.visible = true
	_editor.reset_size()
	_position_editor()
	_ed_input.grab_focus()
	_ed_input.select_all()
	request_render()


func _position_editor() -> void:
	if _editor == null or not _editor.visible:
		return
	var pr := plot_rect().grow(-8.0)
	var pop_sz := _editor.get_combined_minimum_size()
	var sp := to_screen(_ed_world)
	var px := sp.x + 16.0
	if px + pop_sz.x > pr.end.x:
		px = sp.x - pop_sz.x - 16.0
	var py := sp.y - pop_sz.y * 0.45
	px = clampf(px, pr.position.x, maxf(pr.position.x, pr.end.x - pop_sz.x))
	py = clampf(py, pr.position.y, maxf(pr.position.y, pr.end.y - pop_sz.y))
	_editor.position = Vector2(px, py)


func _commit_editor() -> void:
	if _editor == null or not _editor.visible:
		return
	var txt := _ed_input.text.strip_edges()
	if _ed_marker_id.is_empty():
		var local_pos := _ed_world - WC.origin(_ed_sector) if not _ed_sector.is_empty() else Vector2.ZERO
		GameData.add_map_marker(_ed_sector, _ed_world, local_pos, txt, _ed_color)
	else:
		GameData.update_map_marker(_ed_marker_id, txt, _ed_color)
	Audio.play_ui("ui_confirm")
	_close_editor()
	_refresh_pin_btn()
	markers_changed.emit()


func _delete_editor_marker() -> void:
	if _ed_marker_id.is_empty():
		_close_editor()
		return
	GameData.remove_map_marker(_ed_marker_id)
	Audio.play_ui("ui_tab")
	_close_editor()
	_refresh_pin_btn()
	markers_changed.emit()


func close_marker_editor() -> void:
	_close_editor()


func _close_editor() -> void:
	if _editor != null:
		_editor.visible = false
	_ed_marker_id = ""
	request_render()


func _visibility() -> void:
	_press = false
	if not is_visible_in_tree():
		_close_editor()
	if is_visible_in_tree() and not ready_map:
		var started := Time.get_ticks_usec()
		chart = load(Data.PATH) as ArrayMesh
		if chart == null:
			push_error("Missing 2D region data: run --worldmap_2d_bake")
			return
		meta.maps = chart.get_meta("sectors")
		ready_map = true
		build_ms = (Time.get_ticks_usec() - started) / 1000.0
	_refresh_pin_btn()
	_resize()


func _resize() -> void:
	if controls:
		controls.position = Vector2(maxf(12, size.x - controls.get_combined_minimum_size().x - 14), 12)
	_position_editor()
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
	_refresh_pin_btn()
	request_render()

func select(id: String) -> void:
	selected = id
	request_render()

func zoom_to(i: int, anchor: Vector2) -> void:
	var point := to_world(anchor)
	zoom_i = clampi(i, 0, ZOOMS.size() - 1)
	offset += point - to_world(anchor)
	_clamp()
	_position_editor()
	request_render()

func zoom() -> float:
	var fit := minf(maxf(1, plot_rect().size.x - 24) / Data.RECT.size.y, plot_rect().size.y / Data.RECT.size.x)
	return maxf(0.01, fit) * ZOOMS[zoom_i]

func center_on(id: String) -> void:
	if not meta.maps.has(id): return
	offset = WC.centroid(map_poly_world(id))
	zoom_i = maxi(2, zoom_i)
	_position_editor()
	request_render()

func overview() -> void:
	offset = Data.RECT.get_center()
	zoom_i = 0
	_position_editor()
	request_render()

func _clamp() -> void:
	offset = offset.clamp(Data.RECT.position, Data.RECT.end)

func _can_pick(id: String) -> bool:
	return not id.is_empty() and bool(available.get(id, false))


func marker_at(screen: Vector2) -> Dictionary:
	if not plot_rect().has_point(screen):
		return {}
	for i in range(_visible_markers.size() - 1, -1, -1):
		var marker: Dictionary = _visible_markers[i]
		if str(marker.get("kind", "")) == "user_pin" and (marker.rect as Rect2).grow(5).has_point(screen):
			return marker
	for i in range(annotation_labels.size() - 1, -1, -1):
		var lbl: Dictionary = annotation_labels[i]
		if str(lbl.get("kind", "")) == "user_pin" and (lbl.rect as Rect2).has_point(screen):
			return lbl
	return {}


func click(screen: Vector2) -> void:
	if not plot_rect().has_point(screen):
		return
	var hit_pin := marker_at(screen)
	if not hit_pin.is_empty():
		open_marker_editor(screen, str(hit_pin.get("marker_id", "")))
		return
	if pin_mode:
		open_marker_editor(screen, "")
		return
	if _editor != null and _editor.visible:
		_close_editor()
		return
	var id := map_at(screen)
	if id.is_empty():
		return
	if not _can_pick(id):
		map_locked.emit(id)
		return
	select(id)
	map_selected.emit(id)


func right_click(screen: Vector2) -> void:
	if not plot_rect().has_point(screen):
		return
	var hit_pin := marker_at(screen)
	if not hit_pin.is_empty():
		open_marker_editor(screen, str(hit_pin.get("marker_id", "")))
	else:
		open_marker_editor(screen, "")


func _update_cursor() -> void:
	if not _hover_marker_id.is_empty():
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	elif pin_mode:
		mouse_default_cursor_shape = Control.CURSOR_CROSS
	else:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _can_pick(hover) else Control.CURSOR_ARROW


func set_hover(id: String) -> void:
	if hover == id:
		return
	hover = id
	_update_cursor()
	request_render()


func _set_hover_marker(mid: String) -> void:
	if _hover_marker_id == mid:
		return
	_hover_marker_id = mid
	_update_cursor()
	request_render()


func _get_tooltip(at: Vector2) -> String:
	for i in range(_visible_markers.size() - 1, -1, -1):
		var marker: Dictionary = _visible_markers[i]
		if (marker.rect as Rect2).grow(5).has_point(at):
			if str(marker.get("kind", "")) == "user_pin":
				var s_id := str(marker.get("sector_id", ""))
				var s_nm := Loc.map_label(str(meta.maps.get(s_id, {}).get("name", ""))) if meta.maps.has(s_id) else ""
				var head := ("%s · %s" % [s_nm, str(marker.text)]) if not s_nm.is_empty() else str(marker.text)
				return head + "\n" + Loc.t("点击编辑或删除", "Click to edit or delete")
			return str(marker.text)
	for label: Dictionary in annotation_labels:
		if (label.rect as Rect2).has_point(at):
			if str(label.get("kind", "")) == "user_pin":
				return str(label.text) + "\n" + Loc.t("点击编辑或删除", "Click to edit or delete")
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
				if _press and not _moved:
					if _button == MOUSE_BUTTON_LEFT:
						click(event.position)
					elif _button == MOUSE_BUTTON_RIGHT:
						right_click(event.position)
				_press = false
			accept_event()
	elif event is InputEventMouseMotion:
		if _press:
			_moved = _moved or event.position.distance_to(_press_pos) > 4.0
			if _moved:
				offset += _press_world - to_world(event.position)
				_clamp()
				_position_editor()
				request_render()
		else:
			var hm := marker_at(event.position)
			_set_hover_marker(str(hm.get("marker_id", "")))
			set_hover(map_at(event.position))
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _editor != null and _editor.visible:
				_close_editor()
			elif pin_mode:
				set_pin_mode(false)
			else:
				return
		elif event.keycode == KEY_HOME:
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
		_set_hover_marker("")
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
			if marker.kind == "user_pin":
				var mid := str(marker.get("marker_id", ""))
				if mid == _hover_marker_id or (_editor != null and _editor.visible and mid == _ed_marker_id):
					draw_arc(marker.screen + Vector2(0, -6), 9.5, 0, TAU, 20, marker.color, 1.6, true)
			_draw_symbol(marker.screen, marker.kind, marker.color)
	if _editor != null and _editor.visible and _ed_marker_id.is_empty():
		var pp := to_screen(_ed_world)
		if plot_rect().has_point(pp):
			var pcol := GameData.marker_color(_ed_color)
			draw_arc(pp + Vector2(0, -6), 10.5, 0, TAU, 20, pcol, 1.5, true)
			_draw_symbol(pp, "user_pin", pcol)
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
	if pin_mode:
		heading += Loc.t("  ·  标记模式", "  ·  PIN MODE")
	draw_rect(Rect2(0, 0, size.x, HEADER_H), Color(0.07, 0.09, 0.09, 0.94))
	draw_string(font, Vector2(18, 29), heading, HORIZONTAL_ALIGNMENT_LEFT, maxf(0, controls.position.x - 30), 16, AMBER if pin_mode else CREAM)
	_draw_footer(font)


func _collect_markers() -> void:
	# 玩家自定义标记在任意缩放倍率下都保持可见，便于在全域与细节图上随时查看和编辑
	for m in GameData.map_markers:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var wp := Vector2(float(m.get("wx", 0.0)), float(m.get("wz", 0.0)))
		var p := to_screen(wp)
		var rect := Rect2(p - Vector2(8, 12), Vector2(16, 15))
		if plot_rect().encloses(rect):
			_visible_markers.append({
				"screen": p,
				"rect": rect,
				"text": str(m.get("text", "")),
				"kind": "user_pin",
				"color": GameData.marker_color(str(m.get("color", "amber"))),
				"marker_id": str(m.get("id", "")),
				"sector_id": str(m.get("map_id", "")),
			})
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
	var is_pin := str(marker.kind) == "user_pin"
	var pad_x := 12.0 if is_pin else 6.0
	var extent := Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + pad_x, font.get_height(12) + 4)
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
	if is_pin:
		draw_rect(rect, Color(0.055, 0.068, 0.075, 0.90))
		draw_rect(Rect2(rect.position, Vector2(3.0, rect.size.y)), marker.color)
		draw_rect(rect, Color(marker.color.r, marker.color.g, marker.color.b, 0.45), false, 1.0)
		var pin_base := rect.position + Vector2(7, font.get_ascent(12) + 2)
		draw_string(font, pin_base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CREAM)
		annotation_labels.append({"rect": rect, "text": text, "kind": marker.kind, "marker_id": str(marker.get("marker_id", ""))})
		return
	var baseline := rect.position + Vector2(3, font.get_ascent(12) + 2)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, INK)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, marker.color)
	annotation_labels.append({"rect": rect, "text": text, "kind": marker.kind})


func _draw_symbol(p: Vector2, kind: String, color: Color) -> void:
	if kind == "user_pin":
		var head := p + Vector2(0, -6.5)
		var tip_poly := PackedVector2Array([p + Vector2(0, 1.5), head + Vector2(-5.2, 2.0), head + Vector2(5.2, 2.0)])
		draw_colored_polygon(tip_poly, INK)
		draw_circle(head, 6.2, INK, true, -1, true)
		var inner_poly := PackedVector2Array([p, head + Vector2(-4.0, 1.5), head + Vector2(4.0, 1.5)])
		draw_colored_polygon(inner_poly, color)
		draw_circle(head, 4.8, color, true, -1, true)
		draw_circle(head, 1.9, INK, true, -1, true)
		return
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
	for spec: Array in [
		["extract", GREEN, Loc.t("撤离候选点", "Extraction site")],
		["poi", AMBER, Loc.t("重点遗迹", "Point of interest")],
		["landmark", CREAM, Loc.t("地标", "Landmark")],
		["gate", CYAN, Loc.t("跨区通道", "Transit")],
		["user_pin", GameData.marker_color("amber"), Loc.t("玩家标记", "Custom pin")],
	]:
		var sym_p := Vector2(x, size.y - (31 if spec[0] == "user_pin" else 35))
		_draw_symbol(sym_p, spec[0], spec[1])
		draw_string(font, Vector2(x + 11, size.y - 31), spec[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
		x += font.get_string_size(spec[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 30
	var hint := Loc.t("单击选区 · 右键或「打标记」写备注 · 拖动平移 · 滚轮缩放", "Select sector · Right-click or Pin to annotate · Drag pan · Scroll zoom")
	if pin_mode:
		hint = Loc.t("【标记模式】左键点击地图任意区域打点写字 · 点击已有标记可编辑或删除 · Esc 退出", "[PIN MODE] Left-click anywhere to drop a note · Click existing pin to edit/delete · Esc to exit")
	elif zoom_i >= 2:
		hint = Loc.t("单击选区 · 右键打点写备注 · 点击标记可编辑 · 拖动平移 · 滚轮缩放", "Select sector · Right-click to annotate · Click pin to edit · Drag pan · Scroll zoom")
	draw_string(font, Vector2(18, size.y - 10), hint, HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 11, AMBER if pin_mode else DIM)


func _label_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.075, 0.08, 0.89)
	style.border_color = AMBER if active else Color(0.54, 0.57, 0.55, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	return style
