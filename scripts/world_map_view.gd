extends Control
## 降落页 ① 选择战区：可缩放 / 拖动的像素大地图（v0.7.2）。
##
## 底图 assets/ui/worldmap/wm_{1,2,4}m.png 由 tools/gen_worldmap.py 用游戏地图生成代码导出的数据逐像素绘制
## （见该脚本文件头）：每个战区方块与进游戏后的实际地图 1:1 对应（世界坐标 -180~180 米 → 方块内 0~360 像素），
## 方块按 scripts/world_link.gd 的 LINKS 邻接拼接；零号深渊井画在裂谷矿区下方的地下剖面。
## 本控件只在底图上实时叠加：战区描边、名牌（★ 主线 / 未解锁）、悬停高亮、选中的飞空艇标记、撤离候选点、遗迹、转场口，
## 未解锁战区叠斜线阴影与锁。
##
## 操作：滚轮 / 右上角 ＋ − 按钮缩放（档位 = 屏幕像素 / 米：0.25、0.5、1、2、3，整数倍取图保持像素清晰），
## 左键 / 右键 / 中键拖动平移，左键单击战区选中（未解锁的不能选），◎ 回到选中战区。

signal map_selected(id: String)
signal map_locked(id: String)

const META_PATH := "res://assets/ui/worldmap/worldmap.json"
const ZOOMS := [0.25, 0.5, 1.0, 2.0, 3.0]
const AMBER := Color(0.72, 0.5, 0.09)
const CREAM := Color(0.86, 0.84, 0.75)
const DIM := Color(0.55, 0.54, 0.47)
const INK := Color(0.03, 0.03, 0.04)
const GREEN := Color(0.45, 0.85, 0.4)
const CYAN := Color(0.3, 0.85, 0.95)

var meta := {}
var tex := {}             ## 1 / 2 / 4 → Texture2D
var zoom_i := 1
var offset := Vector2.ZERO   ## 底图 (0, 0) 在控件里的位置（整数像素）
var selected := ""
var hover := ""
var available := {}       ## 战区 id → 可出击
var quests := {}          ## 战区 id → 有进行中的主线
var _press := false
var _press_pos := Vector2.ZERO
var _press_off := Vector2.ZERO
var _moved := false
var _placed := false
var zoom_lbl: Label


func _init() -> void:
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	var f := FileAccess.open(META_PATH, FileAccess.READ)
	if f:
		meta = JSON.parse_string(f.get_as_text())
	for lv in [1, 2, 4]:
		var p := "res://assets/ui/worldmap/wm_%dm.png" % lv
		if ResourceLoader.exists(p):
			tex[lv] = load(p)
	# 右上角缩放按钮
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	bar.position = Vector2(-4, 4)
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(bar)
	for spec in [["-", -1, "缩小"], ["+", 1, "放大"], ["◎", 0, "回到选中战区"]]:
		var b := Button.new()
		b.text = spec[0]
		b.tooltip_text = spec[2]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(30, 28)
		var dz: int = spec[1]
		b.pressed.connect(func():
			if dz == 0:
				center_on(selected)
			else:
				zoom_to(zoom_i + dz, size * 0.5))
		b.name = "Zoom%s" % ["Out", "Center", "In"][dz + 1]
		bar.add_child(b)
	zoom_lbl = Label.new()
	zoom_lbl.add_theme_font_size_override("font_size", 12)
	zoom_lbl.add_theme_color_override("font_color", CREAM)
	zoom_lbl.add_theme_color_override("font_outline_color", INK)
	zoom_lbl.add_theme_constant_override("outline_size", 4)
	zoom_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	zoom_lbl.position = Vector2(8, -22)
	add_child(zoom_lbl)
	resized.connect(_on_resized)


func _on_resized() -> void:
	if not _placed and size.x > 10 and size.y > 10:
		_placed = true
		center_on(selected)
	else:
		_clamp()
	queue_redraw()


# ---------------------------------------------------------------- 坐标
func zoom() -> float:
	return ZOOMS[zoom_i]


func world_size() -> Vector2:
	return Vector2(float(meta.get("w", 1)), float(meta.get("h", 1)))


## 底图像素 → 控件坐标
func to_screen(p: Vector2) -> Vector2:
	return offset + p * zoom()


func to_world(s: Vector2) -> Vector2:
	return (s - offset) / zoom()


func map_ids() -> Array:
	return (meta.get("maps", {}) as Dictionary).keys()


## 战区方块在底图上的矩形（像素）
func map_rect_world(id: String) -> Rect2:
	var m: Dictionary = meta.get("maps", {}).get(id, {})
	if m.is_empty():
		return Rect2()
	var t := float(meta.get("tile", 360))
	return Rect2(float(m.x), float(m.y), t, t)


## 战区方块在控件里的矩形
func map_rect(id: String) -> Rect2:
	var r := map_rect_world(id)
	return Rect2(to_screen(r.position), r.size * zoom())


## 游戏世界坐标 (x, z)（米）→ 控件坐标
func game_to_screen(id: String, x: float, z: float) -> Vector2:
	var r := map_rect_world(id)
	var h := float(meta.get("half", 180))
	return to_screen(r.position + Vector2(x + h, z + h))


func map_at(s: Vector2) -> String:
	var w := to_world(s)
	for id: String in map_ids():
		if map_rect_world(id).has_point(w):
			return id
	return ""


# ---------------------------------------------------------------- 状态
func set_state(avail: Dictionary, q: Dictionary, sel: String) -> void:
	available = avail
	quests = q
	selected = sel
	queue_redraw()


func select(id: String) -> void:
	selected = id
	queue_redraw()


func zoom_to(i: int, anchor: Vector2) -> void:
	i = clampi(i, 0, ZOOMS.size() - 1)
	if i == zoom_i:
		return
	var w := to_world(anchor)
	zoom_i = i
	offset = (anchor - w * zoom()).round()
	_clamp()
	queue_redraw()


func center_on(id: String) -> void:
	var r := map_rect_world(id)
	var c := r.get_center() if r.size.x > 0 else world_size() * 0.5
	offset = (size * 0.5 - c * zoom()).round()
	_clamp()
	queue_redraw()


func _clamp() -> void:
	var ws := world_size() * zoom()
	var pad := 48.0
	if ws.x + pad * 2 <= size.x:
		offset.x = roundf((size.x - ws.x) * 0.5)
	else:
		offset.x = clampf(offset.x, size.x - ws.x - pad, pad)
	if ws.y + pad * 2 <= size.y:
		offset.y = roundf((size.y - ws.y) * 0.5)
	else:
		offset.y = clampf(offset.y, size.y - ws.y - pad, pad)
	offset = offset.round()


# ---------------------------------------------------------------- 输入
func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_to(zoom_i + 1, mb.position)
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_to(zoom_i - 1, mb.position)
			accept_event()
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if mb.pressed:
				_press = true
				_moved = false
				_press_pos = mb.position
				_press_off = offset
			else:
				if _press and not _moved and mb.button_index == MOUSE_BUTTON_LEFT:
					click(mb.position)
				_press = false
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _can_pick(hover) else Control.CURSOR_ARROW
			accept_event()
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if _press:
			if not _moved and mm.position.distance_to(_press_pos) > 4.0:
				_moved = true
				mouse_default_cursor_shape = Control.CURSOR_DRAG
			if _moved:
				offset = (_press_off + mm.position - _press_pos).round()
				_clamp()
				queue_redraw()
		set_hover(map_at(mm.position))


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		set_hover("")


func set_hover(id: String) -> void:
	if id == hover:
		return
	hover = id
	if not _press:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _can_pick(id) else Control.CURSOR_ARROW
	var m: Dictionary = meta.get("maps", {}).get(id, {})
	tooltip_text = "" if m.is_empty() else ("%s%s" % [str(m.name), "" if _can_pick(id) else " · 未解锁"])
	queue_redraw()


func _can_pick(id: String) -> bool:
	return id != "" and bool(available.get(id, false))


## 单击：选中可出击的战区（测试也直接调用）
func click(s: Vector2) -> void:
	var id := map_at(s)
	if id == "":
		return
	if not _can_pick(id):
		map_locked.emit(id)
		return
	selected = id
	queue_redraw()
	map_selected.emit(id)


# ---------------------------------------------------------------- 绘制
func _px(p: Vector2, c: Color, n := 2.0) -> void:
	draw_rect(Rect2(p.floor(), Vector2(n, n)), c)


func _box(r: Rect2, c: Color, w := 2.0) -> void:
	r = Rect2(r.position.floor(), r.size.floor())
	draw_rect(Rect2(r.position, Vector2(r.size.x, w)), c)
	draw_rect(Rect2(Vector2(r.position.x, r.end.y - w), Vector2(r.size.x, w)), c)
	draw_rect(Rect2(r.position, Vector2(w, r.size.y)), c)
	draw_rect(Rect2(Vector2(r.end.x - w, r.position.y), Vector2(w, r.size.y)), c)


func _hatch(r: Rect2, c: Color) -> void:
	var step := 8.0
	var k := 0.0
	while k < r.size.x + r.size.y:
		# 45° 斜线：x + y = k，裁到矩形内
		var x0 := maxf(0.0, k - r.size.y)
		var x1 := minf(r.size.x, k)
		if x1 > x0:
			draw_line(r.position + Vector2(x0, k - x0), r.position + Vector2(x1, k - x1), c, 2.0)
		k += step


func _text(font: Font, pos: Vector2, t: String, c: Color, fs := 12) -> void:
	draw_string_outline(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, INK)
	draw_string(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	if meta.is_empty():
		return
	var z := zoom()
	var lv := 4 if z <= 0.25 else (2 if z <= 0.5 else 1)
	var t: Texture2D = tex.get(lv, tex.get(1))
	if t:
		draw_texture_rect(t, Rect2(offset, t.get_size() * lv * z), false)
	var font := get_theme_default_font()
	var maps: Dictionary = meta.maps
	var h := float(meta.get("half", 180))
	# 郊野地名（只在远景显示）
	if z <= 0.5:
		for fl in meta.get("fill_labels", []):
			var p := to_screen(Vector2(float(fl[1]), float(fl[2])))
			var tw := font.get_string_size(str(fl[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			_text(font, (p - Vector2(tw * 0.5, -4)).floor(), str(fl[0]), DIM)
	# 未解锁：斜线阴影
	for id: String in maps:
		var r := map_rect(id)
		if not bool(available.get(id, false)):
			draw_rect(r, Color(0, 0, 0, 0.45))
			_hatch(r, Color(0, 0, 0, 0.5))
	# 转场口：方块边上一段青色亮条（各种子众数位置；淡色是每局可能出现的范围）
	for g: Dictionary in meta.get("gates", []):
		var id := str(g.map)
		if not maps.has(id):
			continue
		var open: bool = bool(available.get(id, false)) and bool(available.get(str(g.to), false))
		var c := CYAN if open else Color(0.42, 0.55, 0.6)
		var e := str(g.edge)
		var al := float(g.along)
		var th := maxf(4.0, floorf(4.0 * z))
		for band in [[float(g.lo) - 16.0, float(g.hi) + 16.0, Color(c.r, c.g, c.b, 0.28)], [al - 16.0, al + 16.0, INK], [al - 16.0, al + 16.0, c]]:
			var a: Vector2
			var b: Vector2
			match e:
				"N": a = game_to_screen(id, band[0], -h); b = game_to_screen(id, band[1], -h) + Vector2(0, th)
				"S": a = game_to_screen(id, band[0], h) - Vector2(0, th); b = game_to_screen(id, band[1], h)
				"W": a = game_to_screen(id, -h, band[0]); b = game_to_screen(id, -h, band[1]) + Vector2(th, 0)
				_: a = game_to_screen(id, h, band[0]) - Vector2(th, 0); b = game_to_screen(id, h, band[1])
			var rr := Rect2(a.floor(), (b - a).floor())
			if band[2] == INK:
				rr = rr.grow(2)   # 黑描边，压在灰色地面上也看得见
			draw_rect(rr, band[2])
	# 撤离候选点（绿方块）/ 遗迹（琥珀菱形）/ 地标（小米白点）
	var mk := 2.0 if z < 1.0 else 3.0
	for id: String in maps:
		if z < 0.5:
			break   # 最远一档只看战区与转场口
		var m: Dictionary = maps[id]
		if z >= 1.0:
			for lm in m.get("landmarks", []):
				var p := game_to_screen(id, float(lm.x), float(lm.z))
				_px(p - Vector2(2, 2), INK, 4)
				_px(p - Vector2(1, 1), CREAM, 2)
		for ex in m.get("extracts", []):
			var p := game_to_screen(id, float(ex.x), float(ex.z))
			_px(p - Vector2(mk * 2, mk * 2), INK, mk * 4)
			_px(p - Vector2(mk, mk), GREEN, mk * 2)
			if z >= 2.0:
				_text(font, (p + Vector2(mk * 2 + 3, 5)).floor(), str(ex.name), GREEN)
		for po in m.get("pois", []):
			var p := game_to_screen(id, float(po.x), float(po.z)).floor()
			for dy in range(-3, 4):
				var w := 3 - absi(dy)
				draw_rect(Rect2(p + Vector2(-w - 1, dy) * mk, Vector2(w * 2 + 3, 1) * mk), INK)
			for dy in range(-2, 3):
				var w := 2 - absi(dy)
				draw_rect(Rect2(p + Vector2(-w, dy) * mk, Vector2(w * 2 + 1, 1) * mk), AMBER)
			if z >= 2.0:
				_text(font, (p + Vector2(mk * 4 + 2, 5)).floor(), str(po.name), AMBER)
	# 描边 + 名牌
	for id: String in maps:
		var r := map_rect(id)
		var m: Dictionary = maps[id]
		var ok := bool(available.get(id, false))
		var col := Color(0.55, 0.42, 0.2)
		if not ok:
			col = Color(0.35, 0.35, 0.36)
		if id == hover and ok:
			col = CREAM
		if id == selected:
			col = AMBER
		_box(r.grow(2), INK, 2)
		_box(r.grow(4), col, 2 if id != selected else 3)
		if id == hover and ok and id != selected:
			draw_rect(r, Color(1, 0.95, 0.8, 0.08))
		var nm := str(m.name)
		if bool(m.get("underground", false)):
			nm += " · 地下竖井"
		var tag := ""
		if not ok:
			tag = "未解锁"
		elif bool(quests.get(id, false)):
			tag = "★ 主线"
		var tw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var tw2 := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x if tag != "" else 0.0
		var pw := tw + (tw2 + 10 if tag != "" else 0.0) + 16
		var pp := Vector2(floorf(r.get_center().x - pw * 0.5), floorf(r.position.y) + 6)
		var plate := Rect2(pp, Vector2(pw, 20))
		draw_rect(plate, Color(0.06, 0.06, 0.06, 0.92))
		_box(plate, col, 2)
		_text(font, pp + Vector2(8, 15), nm, AMBER if id == selected else (CREAM if ok else DIM))
		if tag != "":
			_text(font, pp + Vector2(8 + tw + 10, 15), tag, Color(0.95, 0.35, 0.3) if not ok else AMBER)
		if not ok:
			var lk: Texture2D = load("res://scripts/hub_kit.gd").small_icon("lock")
			if lk:
				draw_texture_rect(lk, Rect2((r.get_center() - Vector2(16, 16)).floor(), Vector2(32, 32)), false)
	# 选中战区：飞空艇「信天翁号」标记，挂在名牌右侧
	if maps.has(selected):
		var r := map_rect(selected)
		var st: Texture2D = load("res://scripts/hub_kit.gd").small_icon("ship")
		var c := Vector2(floorf(r.get_center().x), floorf(r.position.y) + 6)
		var nm := str(maps[selected].name)
		var tw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var at := c + Vector2(tw * 0.5 + 40, -14)
		if st:
			draw_texture_rect(st, Rect2(at.floor(), Vector2(24, 24)), false)
	if zoom_lbl:
		zoom_lbl.text = "比例 %s  · 1 像素 = %s 米" % ["×%s" % str(z), str(snappedf(1.0 / z, 0.01))]
