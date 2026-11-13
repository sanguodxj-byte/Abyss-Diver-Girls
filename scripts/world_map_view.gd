extends Control
## 降落页 ① 选择战区：可缩放 / 拖动的像素大地图（v0.7.2）。
##
## 底图 assets/ui/worldmap/wm_{1,2,4}m.png 由 tools/gen_worldmap.py 用游戏地图生成代码导出的数据逐像素绘制
## （见该脚本文件头）：每个战区是从连续城市群大地图上沿道路、铁路、河流与断层截取的不规则战区多边形，与进游戏后的实际战区 1:1 对应；
## 相邻地表战区共用真实不规则封锁边界，零号深渊井画在裂谷矿区下方的不规则地下岩腔剖面。
## 本控件只在底图上实时叠加：不规则战区描边、名牌（★ 主线 / 未解锁）、悬停高亮、选中的飞空艇标记、撤离候选点、遗迹、斜向转场口，
## 未解锁战区按不规则轮廓叠斜线阴影与锁。
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
var _poly_cache := {}     ## 战区 id → 底图像素不规则多边形 PackedVector2Array
var tex := {}             ## 1 / 2 / 4 → Texture2D
var zoom_i := 0
var offset := Vector2.ZERO   ## 旋转横置底图 (0, 0) 在控件里的位置（整数像素）
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
		_poly_cache.clear()
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
	for spec in [["-", -1, Loc.t("缩小", "Zoom Out")], ["+", 1, Loc.t("放大", "Zoom In")], ["◎", 0, Loc.t("回到选中战区", "Center on Selected Sector")]]:
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
	zoom_lbl.visible = false
	zoom_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(zoom_lbl)
	resized.connect(_on_resized)


func _on_resized() -> void:
	if not _placed and size.x > 10 and size.y > 10:
		_placed = true
		center_on(selected)
	else:
		_clamp()
	queue_redraw()


# ---------------------------------------------------------------- 坐标（大地图逆时针横置 90°，长边水平铺满边框）
func min_zoom() -> float:
	var ws := world_size()
	if ws.x <= 1.0 or ws.y <= 1.0 or size.x <= 1.0 or size.y <= 1.0:
		return ZOOMS[0]
	return maxf((ceilf(size.x) + 1.0) / ws.x, (ceilf(size.y) + 1.0) / ws.y)


func zoom() -> float:
	var mz := min_zoom()
	return mz if zoom_i <= 0 else maxf(ZOOMS[zoom_i], mz)


func world_size() -> Vector2:
	return Vector2(float(meta.get("h", 1)), float(meta.get("w", 1)))


## 原竖向底图坐标 (u, v) → 逆时针旋转 90° 后的横置底图坐标 (v, W - u)
func _base_to_map(p: Vector2) -> Vector2:
	return Vector2(p.y, float(meta.get("w", 1)) - p.x)


## 横置底图像素 → 控件坐标
func to_screen(p: Vector2) -> Vector2:
	return offset + p * zoom()


func to_world(s: Vector2) -> Vector2:
	return (s - offset) / zoom()


func map_ids() -> Array:
	return (meta.get("maps", {}) as Dictionary).keys()


## 战区局部 (-180, -180) 在原竖向底图上的锚点像素坐标
func map_anchor_world(id: String) -> Vector2:
	var m: Dictionary = meta.get("maps", {}).get(id, {})
	if m.is_empty():
		return Vector2.ZERO
	return Vector2(float(m.x), float(m.y))


## 战区不规则轮廓在横置底图上的像素多边形
func map_poly_world(id: String) -> PackedVector2Array:
	if _poly_cache.has(id):
		return _poly_cache[id]
	var m: Dictionary = meta.get("maps", {}).get(id, {})
	var out := PackedVector2Array()
	if m.is_empty():
		return out
	var anc := Vector2(float(m.x), float(m.y))
	var h := float(meta.get("half", 180))
	var raw: Array = m.get("poly", [])
	if raw.size() >= 3:
		for pt in raw:
			out.append(_base_to_map(anc + Vector2(float(pt[0]) + h, float(pt[1]) + h)))
	else:
		var t := float(meta.get("tile", 360))
		out.append(_base_to_map(anc))
		out.append(_base_to_map(anc + Vector2(t, 0)))
		out.append(_base_to_map(anc + Vector2(t, t)))
		out.append(_base_to_map(anc + Vector2(0, t)))
	_poly_cache[id] = out
	return out


## 战区不规则轮廓在控件里的屏幕坐标多边形
func map_poly(id: String) -> PackedVector2Array:
	var pw := map_poly_world(id)
	var out := PackedVector2Array()
	out.resize(pw.size())
	for i in pw.size():
		out[i] = to_screen(pw[i])
	return out


## 战区轮廓在底图上的外接矩形（像素）
func map_rect_world(id: String) -> Rect2:
	var pw := map_poly_world(id)
	if pw.is_empty():
		return Rect2()
	var x0 := pw[0].x
	var y0 := pw[0].y
	var x1 := x0
	var y1 := y0
	for p in pw:
		x0 = minf(x0, p.x); x1 = maxf(x1, p.x)
		y0 = minf(y0, p.y); y1 = maxf(y1, p.y)
	return Rect2(Vector2(x0, y0), Vector2(x1 - x0, y1 - y0))


## 战区轮廓在控件里的外接矩形
func map_rect(id: String) -> Rect2:
	var r := map_rect_world(id)
	return Rect2(to_screen(r.position), r.size * zoom())


## 游戏世界坐标 (x, z)（米）→ 控件坐标
func game_to_screen(id: String, x: float, z: float) -> Vector2:
	var h := float(meta.get("half", 180))
	return to_screen(_base_to_map(map_anchor_world(id) + Vector2(x + h, z + h)))


func map_at(s: Vector2) -> String:
	var w := to_world(s)
	for id: String in map_ids():
		var pw := map_poly_world(id)
		if pw.size() >= 3 and Geometry2D.is_point_in_polygon(w, pw):
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
		_clamp()
		queue_redraw()
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
	if ws.x <= size.x:
		offset.x = roundf((size.x - ws.x) * 0.5)
	else:
		offset.x = clampf(roundf(offset.x), ceilf(size.x - ws.x), 0.0)
	if ws.y <= size.y:
		offset.y = roundf((size.y - ws.y) * 0.5)
	else:
		offset.y = clampf(roundf(offset.y), ceilf(size.y - ws.y), 0.0)


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


func _fill_poly(poly_s: PackedVector2Array, c: Color) -> void:
	if poly_s.size() >= 3 and not Geometry2D.triangulate_polygon(poly_s).is_empty():
		draw_colored_polygon(poly_s, c)


func _poly_outline(poly_s: PackedVector2Array, c: Color, w := 2.0) -> void:
	if poly_s.size() < 3:
		return
	var closed := poly_s.duplicate()
	closed.append(poly_s[0])
	draw_polyline(closed, c, w)


func _hatch_poly(poly_s: PackedVector2Array, r: Rect2, c: Color) -> void:
	if poly_s.size() < 3:
		return
	var step := 9.0
	var k := 0.0
	while k < r.size.x + r.size.y:
		var x0 := maxf(0.0, k - r.size.y)
		var x1 := minf(r.size.x, k)
		if x1 > x0:
			var a := r.position + Vector2(x0, k - x0)
			var b := r.position + Vector2(x1, k - x1)
			for seg: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), poly_s):
				if seg.size() >= 2:
					draw_line(seg[0], seg[seg.size() - 1], c, 2.0)
		k += step


func _best_chord(poly_s: PackedVector2Array, r: Rect2, fracs: Array, want_w: float) -> Vector3:
	var best := Vector3(r.get_center().x, r.get_center().y, r.size.x * 0.6)
	var best_w := -1.0
	for tf in fracs:
		var y := lerpf(r.position.y, r.end.y, float(tf))
		var segs := Geometry2D.intersect_polyline_with_polygon(
			PackedVector2Array([Vector2(r.position.x - 4.0, y), Vector2(r.end.x + 4.0, y)]), poly_s)
		for seg: PackedVector2Array in segs:
			if seg.size() < 2:
				continue
			var x0 := minf(seg[0].x, seg[seg.size() - 1].x)
			var x1 := maxf(seg[0].x, seg[seg.size() - 1].x)
			var w := x1 - x0
			if w >= want_w:
				return Vector3((x0 + x1) * 0.5, y, w)
			if w > best_w:
				best_w = w
				best = Vector3((x0 + x1) * 0.5, y, w)
	return best


const LM_NAMES := {
	"broken_bridge": "灰港断桥", "radio_mast": "旧城广播塔", "elevated_road": "高架残段", "central_terminus": "中央穹顶总站",
	"gantry": "运河龙门吊", "blast_furnace": "一号钢厂高炉", "gas_holder": "煤气罐区", "converter_foundry": "二号转炉钢厂",
	"windmill": "风车阵", "pylon_row": "高压电塔列", "silo": "农场筒仓", "missile_silo": "洲际发射井阵地",
	"boardwalk": "赤湖观景栈桥", "observation_tower": "环湖观景塔", "spillway_dam": "赤湖溢洪闸枢",
	"submarine_drydock": "巨型潜艇干船坞",
	"cable_tower": "峡谷缆车塔", "ore_silos": "矿场筒仓", "rope_bridge": "悬崖索桥", "bucket_excavator": "斗轮挖掘机平台",
	"coolant_channel": "冷却渠", "crystal_cluster": "晶脉簇", "drill_derrick": "钻井残台", "geothermal_vault": "地热磁约束腔",
}


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
	var w0 := float(meta.get("w", 1))
	if t:
		var xf := Transform2D(Vector2(0.0, -z), Vector2(z, 0.0), offset + Vector2(0.0, w0 * z))
		draw_set_transform_matrix(xf)
		draw_texture_rect(t, Rect2(Vector2.ZERO, t.get_size() * lv), false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	var font := get_theme_default_font()
	var maps: Dictionary = meta.maps
	var h := float(meta.get("half", 180))
	var polys := {}
	var rects := {}
	for id: String in maps:
		polys[id] = map_poly(id)
		rects[id] = map_rect(id)
	# 郊野地名（只在远景显示，自动避开不规则战区轮廓）
	if z <= 0.5:
		for fl in meta.get("fill_labels", []):
			var fname: String = Loc.map_label(str(fl[0]))
			var p := to_screen(_base_to_map(Vector2(float(fl[1]), float(fl[2]))))
			var tw := font.get_string_size(fname, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var lbox := Rect2(p - Vector2(tw * 0.5 + 4, 10), Vector2(tw + 8, 18))
			var hit_zone := false
			var pts := [lbox.position, lbox.end, Vector2(lbox.position.x, lbox.end.y), Vector2(lbox.end.x, lbox.position.y), lbox.get_center()]
			for zid: String in maps:
				if not (rects[zid] as Rect2).grow(8).intersects(lbox):
					continue
				var zp: PackedVector2Array = polys[zid]
				for qp: Vector2 in pts:
					if zp.size() >= 3 and Geometry2D.is_point_in_polygon(qp, zp):
						hit_zone = true
						break
				if hit_zone:
					break
			if not hit_zone:
				_text(font, (p - Vector2(tw * 0.5, -4)).floor(), fname, DIM)
	# 未解锁：按不规则轮廓填充暗幕与斜线阴影
	for id: String in maps:
		if not bool(available.get(id, false)):
			var zp: PackedVector2Array = polys[id]
			_fill_poly(zp, Color(0, 0, 0, 0.45))
			_hatch_poly(zp, rects[id], Color(0, 0, 0, 0.52))
	# 不规则战区封锁边界：先画普通战区，再叠悬停与当前选中战区，保证共用边界高亮完整
	var order: Array = []
	for id: String in maps:
		if id != hover and id != selected:
			order.append(id)
	if hover != "" and hover != selected and maps.has(hover):
		order.append(hover)
	if selected != "" and maps.has(selected):
		order.append(selected)
	for id: String in order:
		var zp: PackedVector2Array = polys[id]
		var ok := bool(available.get(id, false))
		var col := Color(0.58, 0.44, 0.2)
		if not ok:
			col = Color(0.36, 0.36, 0.38)
		if id == hover and ok:
			col = CREAM
		if id == selected:
			col = AMBER
		if id == hover and ok and id != selected:
			_fill_poly(zp, Color(1, 0.95, 0.8, 0.09))
		elif id == selected:
			_fill_poly(zp, Color(1.0, 0.78, 0.25, 0.05))
		var lw := 3.0 if id == selected else 2.0
		_poly_outline(zp, INK, lw + 3.0)
		_poly_outline(zp, col, lw)
	# 转场口：沿真实不规则封锁边界方向的青色亮条
	for g: Dictionary in meta.get("gates", []):
		var id := str(g.map)
		if not maps.has(id):
			continue
		var open: bool = bool(available.get(id, false)) and bool(available.get(str(g.to), false))
		var c := CYAN if open else Color(0.42, 0.55, 0.6)
		var th := maxf(4.0, floorf(4.0 * z))
		if g.has("x"):
			var p := game_to_screen(id, float(g.x), float(g.z))
			var tg := Vector2(float(g.get("tz", 0.0)), -float(g.get("tx", 1.0))).normalized()
			var span := maxf(7.0, 16.0 * z)
			var range_half := maxf(span, (float(g.hi) - float(g.lo)) * 0.5 * z + span)
			if range_half > span + 2.0:
				draw_line(p - tg * range_half, p + tg * range_half, Color(c.r, c.g, c.b, 0.28), th + 2.0)
			draw_line(p - tg * (span + 2.0), p + tg * (span + 2.0), INK, th + 4.0)
			draw_line(p - tg * span, p + tg * span, c, th)
		else:
			var e := str(g.edge)
			var al := float(g.along)
			for band in [[float(g.lo) - 16.0, float(g.hi) + 16.0, Color(c.r, c.g, c.b, 0.28)], [al - 16.0, al + 16.0, INK], [al - 16.0, al + 16.0, c]]:
				var a: Vector2
				var b: Vector2
				match e:
					"N": a = game_to_screen(id, band[0], -h); b = game_to_screen(id, band[1], -h)
					"S": a = game_to_screen(id, band[0], h); b = game_to_screen(id, band[1], h)
					"W": a = game_to_screen(id, -h, band[0]); b = game_to_screen(id, -h, band[1])
					_: a = game_to_screen(id, h, band[0]); b = game_to_screen(id, h, band[1])
				var p0 := Vector2(minf(a.x, b.x), minf(a.y, b.y)).floor()
				var sz := (b - a).abs().floor()
				if sz.x < th:
					sz.x = th
				if sz.y < th:
					sz.y = th
				var rr := Rect2(p0, sz)
				if band[2] == INK:
					rr = rr.grow(2)
				draw_rect(rr, band[2])
	# 撤离候选点（绿方块）/ 遗迹（琥珀菱形）/ 地标（米白方点）
	var mk := 2.0 if z < 1.0 else 3.0
	for id: String in maps:
		if zoom_i == 0 or z < 0.5:
			break   # 最远一档只看战区轮廓与转场口
		var m: Dictionary = maps[id]
		var r: Rect2 = rects[id]
		var ok := bool(available.get(id, false))
		var show_lbl := z >= 2.0 and (ok or id == hover or id == selected)
		var alpha := 1.0 if (ok or id == hover or id == selected) else 0.52
		var placed_lbls: Array = []
		for ex in m.get("extracts", []):
			var p := game_to_screen(id, float(ex.x), float(ex.z))
			var gc := Color(GREEN.r, GREEN.g, GREEN.b, alpha)
			_px(p - Vector2(mk * 2, mk * 2), INK, mk * 4)
			_px(p - Vector2(mk, mk), gc, mk * 2)
			if show_lbl:
				var ename: String = Loc.map_label(str(ex.name))
				var etw := font.get_string_size(ename, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
				var lx := p.x + mk * 2 + 4.0
				if lx + etw > r.end.x - 6.0:
					lx = p.x - etw - mk * 2 - 4.0
				lx = clampf(lx, r.position.x + 6.0, maxf(r.position.x + 6.0, r.end.x - etw - 6.0))
				var ly := clampf(p.y + 5.0, r.position.y + 42.0, r.end.y - 8.0)
				placed_lbls.append(Rect2(lx - 2, ly - 12, etw + 4, 15))
				_text(font, Vector2(lx, ly).floor(), ename, GREEN)
		for po in m.get("pois", []):
			var p := game_to_screen(id, float(po.x), float(po.z)).floor()
			var ac := Color(AMBER.r, AMBER.g, AMBER.b, alpha)
			for dy in range(-3, 4):
				var w := 3 - absi(dy)
				draw_rect(Rect2(p + Vector2(-w - 1, dy) * mk, Vector2(w * 2 + 3, 1) * mk), INK)
			for dy in range(-2, 3):
				var w := 2 - absi(dy)
				draw_rect(Rect2(p + Vector2(-w, dy) * mk, Vector2(w * 2 + 1, 1) * mk), ac)
			if show_lbl:
				var pname: String = Loc.map_label(str(po.name))
				var ptw := font.get_string_size(pname, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
				var lx := p.x + mk * 4 + 3.0
				if lx + ptw > r.end.x - 6.0:
					lx = p.x - ptw - mk * 4 - 3.0
				lx = clampf(lx, r.position.x + 6.0, maxf(r.position.x + 6.0, r.end.x - ptw - 6.0))
				var ly := clampf(p.y + 5.0, r.position.y + 42.0, r.end.y - 8.0)
				var pbox := Rect2(lx - 2, ly - 12, ptw + 4, 15)
				for eb: Rect2 in placed_lbls:
					if pbox.intersects(eb):
						ly = clampf(p.y - 10.0, r.position.y + 42.0, r.end.y - 8.0)
						pbox = Rect2(lx - 2, ly - 12, ptw + 4, 15)
						break
				placed_lbls.append(pbox)
				_text(font, Vector2(lx, ly).floor(), pname, AMBER)
		if z >= 1.0:
			var cc := Color(CREAM.r, CREAM.g, CREAM.b, alpha)
			for lm in m.get("landmarks", []):
				var p := game_to_screen(id, float(lm.x), float(lm.z))
				_px(p - Vector2(3, 3), INK, 6)
				_px(p - Vector2(2, 2), cc, 4)
				if show_lbl:
					var ltype := str(lm.get("type", ""))
					var lname: String = Loc.landmark_name(ltype, str(LM_NAMES.get(ltype, "")))
					if lname != "":
						var ltw := font.get_string_size(lname, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
						var lx := p.x + 6.0
						if lx + ltw > r.end.x - 6.0:
							lx = p.x - ltw - 6.0
						lx = clampf(lx, r.position.x + 6.0, maxf(r.position.x + 6.0, r.end.x - ltw - 6.0))
						var ly := clampf(p.y + 4.0, r.position.y + 42.0, r.end.y - 8.0)
						var lbox := Rect2(lx - 2, ly - 12, ltw + 4, 15)
						var hit := false
						for eb: Rect2 in placed_lbls:
							if lbox.intersects(eb):
								hit = true
								break
						if not hit:
							placed_lbls.append(lbox)
							_text(font, Vector2(lx, ly).floor(), lname, CREAM)
	# 名牌（按战区不规则轮廓的上部内部弦居中摆放，杜绝名牌落到相邻战区或互相碰撞）
	var sel_plate := Rect2()
	var sel_chord_r := 0.0
	for id: String in order:
		var zp: PackedVector2Array = polys[id]
		var r: Rect2 = rects[id]
		var m: Dictionary = maps[id]
		var ok := bool(available.get(id, false))
		var col := Color(0.58, 0.44, 0.2)
		if not ok:
			col = Color(0.36, 0.36, 0.38)
		if id == hover and ok:
			col = CREAM
		if id == selected:
			col = AMBER
		var nm := Loc.map_label(str(m.name))
		if bool(m.get("underground", false)) and z >= 0.5:
			nm += Loc.t(" · 地下竖井", " · Underground Shaft")
		var tag := ""
		if not ok:
			tag = Loc.t("未解锁", "Locked")
		elif bool(quests.get(id, false)):
			tag = Loc.t("★ 主线", "★ Main Quest")
		var tw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var tw2 := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x if tag != "" else 0.0
		var pw := tw + (tw2 + 10 if tag != "" else 0.0) + 16
		var top_ch := _best_chord(zp, r, [0.16, 0.22, 0.28, 0.35], pw + 12.0)
		var compact := pw > top_ch.z - 8.0
		if compact:
			var pw_top := minf(maxf(44.0, top_ch.z - 4.0), tw + 12.0)
			var pp := Vector2(floorf(top_ch.x - pw_top * 0.5), floorf(top_ch.y - 9.0))
			var plate := Rect2(pp, Vector2(pw_top, 18))
			draw_rect(plate, Color(0.06, 0.06, 0.06, 0.92))
			_box(plate, col, 2)
			_text(font, Vector2(floorf(top_ch.x - tw * 0.5), pp.y + 14), nm, AMBER if id == selected else (CREAM if ok else DIM))
			if id == selected:
				sel_plate = plate
				sel_chord_r = top_ch.x + top_ch.z * 0.5
			if tag != "":
				var bot_ch := _best_chord(zp, r, [0.82, 0.75, 0.68], tw2 + 14.0)
				var pw_bot := minf(maxf(38.0, bot_ch.z - 6.0), tw2 + 10.0)
				var bp := Vector2(floorf(bot_ch.x - pw_bot * 0.5), floorf(bot_ch.y - 8.0))
				var bplate := Rect2(bp, Vector2(pw_bot, 16))
				draw_rect(bplate, Color(0.06, 0.06, 0.06, 0.90))
				_box(bplate, col, 1)
				_text(font, Vector2(floorf(bot_ch.x - tw2 * 0.5), bp.y + 12), tag, Color(0.95, 0.35, 0.3) if not ok else AMBER)
		else:
			var pp := Vector2(floorf(top_ch.x - pw * 0.5), floorf(top_ch.y - 10.0))
			var plate := Rect2(pp, Vector2(pw, 20))
			draw_rect(plate, Color(0.06, 0.06, 0.06, 0.92))
			_box(plate, col, 2)
			_text(font, pp + Vector2(8, 15), nm, AMBER if id == selected else (CREAM if ok else DIM))
			if tag != "":
				_text(font, pp + Vector2(8 + tw + 10, 15), tag, Color(0.95, 0.35, 0.3) if not ok else AMBER)
			if id == selected:
				sel_plate = plate
				sel_chord_r = top_ch.x + top_ch.z * 0.5
		if not ok:
			var lk: Texture2D = load("res://scripts/hub_kit.gd").small_icon("lock")
			if lk:
				var lsz := 24.0 if (zoom_i == 0 or z < 0.5) else 32.0
				var mid_ch := _best_chord(zp, r, [0.50, 0.44, 0.56], lsz + 8.0)
				draw_texture_rect(lk, Rect2((Vector2(mid_ch.x, mid_ch.y) - Vector2(lsz * 0.5, lsz * 0.5)).floor(), Vector2(lsz, lsz)), false)
	# 选中战区：飞空艇「信天翁号」标记，紧贴名牌右侧且不越出当前战区不规则右边界
	if maps.has(selected):
		var st: Texture2D = load("res://scripts/hub_kit.gd").small_icon("ship")
		if st and sel_plate.size.x > 0:
			var at: Vector2
			if sel_plate.end.x + 26.0 <= sel_chord_r - 2.0:
				at = Vector2(sel_plate.end.x + 4.0, sel_plate.position.y - 2.0)
			else:
				at = Vector2(floorf(sel_plate.get_center().x - 12.0), sel_plate.end.y + 3.0)
			draw_texture_rect(st, Rect2(at.floor(), Vector2(24, 24)), false)
	# 左上角方位指示标（大地图逆时针横置 90° 后，左侧为正北）
	var cmp_txt := Loc.t("◀ 北  ·  ▲ 东", "◀ N  ·  ▲ E")
	var cmp_w := font.get_string_size(cmp_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var cmp_rect := Rect2(8, 8, ceilf(cmp_w) + 14.0, 20.0)
	draw_rect(cmp_rect, Color(0.06, 0.06, 0.06, 0.88))
	_box(cmp_rect, AMBER, 1.0)
	_text(font, Vector2(15, 22), cmp_txt, CREAM)
	if zoom_lbl:
		zoom_lbl.text = ""
