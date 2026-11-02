extends RefCounted
## 统一的科幻工业风 UI 主题与小部件。
## 玩家方色板：金属黑灰 + 亮橙黄（铁血紫只给敌方）。所有控件使用 assets/ui 下的贴图九宫格，不保留引擎默认样式。

const BG := Color(0.13, 0.13, 0.13, 0.92)
const BG2 := Color(0.2, 0.2, 0.2, 0.95)
const LINE := Color(1, 1, 1, 0.08)
const ACCENT := Color(1.0, 0.69, 0.13)
const ACCENT_DIM := Color(1.0, 0.69, 0.13, 0.4)
const INFO := Color(1.0, 0.84, 0.5)
const TEXT := Color(0.93, 0.93, 0.92)
const MUTED := Color(0.62, 0.62, 0.62)
const GOOD := Color(0.4, 1.0, 0.6)
const BAD := Color(1.0, 0.38, 0.32)
const HP_C := Color(0.95, 0.35, 0.3)
const EN_C := Color(1.0, 0.78, 0.25)

static var _theme: Theme


static var _tex := {}
static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load("res://assets/ui/%s.png" % name)
	return _tex[name]


## 贴图九宫格样式
static func tex9(name: String, margin := 12, pad := 12, tint := Color(1, 1, 1)) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex(name)
	sb.set_texture_margin_all(margin)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.75
	sb.content_margin_bottom = pad * 0.75
	sb.modulate_color = tint
	return sb


## 按底色语义挑选贴图（亮橙→主按钮，半透明浅色→列表底，其余→金属面板）
static func box(bg := BG, _border := LINE, _bw := 1, _top := 0, _top_c := ACCENT, _radius := 3, pad := 12) -> StyleBox:
	if bg.a > 0.8 and bg.r > 0.6 and bg.b < 0.3:
		var n := "btn_main_h" if bg.r > 0.95 else ("btn_main_p" if bg.r < 0.8 else "btn_main_n")
		return tex9(n, 12, pad)
	if bg.a < 0.3:
		return tex9("list9", 8, pad)
	return tex9("panel9", 14, pad, Color(1, 1, 1, clampf(bg.a + 0.08, 0.6, 1.0)))


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 15
	t.set_stylebox("panel", "PanelContainer", tex9("panel9", 14, 12))
	t.set_stylebox("panel", "Panel", tex9("panel9", 14, 12))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	t.set_constant("outline_size", "Label", 0)
	t.set_constant("line_spacing", "Label", 2)
	for k in [["normal", "btn_n"], ["hover", "btn_h"], ["pressed", "btn_p"], ["disabled", "btn_d"], ["focus", "btn_h"]]:
		t.set_stylebox(k[0], "Button", tex9(k[1], 10, 12))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 0.9, 0.62))
	t.set_color("font_pressed_color", "Button", ACCENT.lightened(0.3))
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.45, 0.48))
	t.set_stylebox("panel", "ItemList", tex9("list9", 8, 6))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("selected", "ItemList", tex9("sel9", 6, 4))
	t.set_stylebox("selected_focus", "ItemList", tex9("sel9", 6, 4))
	t.set_stylebox("hovered", "ItemList", tex9("hover9", 6, 4))
	t.set_stylebox("hovered_selected", "ItemList", tex9("sel9", 6, 4))
	t.set_stylebox("hovered_selected_focus", "ItemList", tex9("sel9", 6, 4))
	t.set_stylebox("cursor", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", Color(1, 0.94, 0.78))
	t.set_color("font_hovered_color", "ItemList", Color(1, 0.94, 0.78))
	t.set_color("guide_color", "ItemList", Color(1, 1, 1, 0.04))
	t.set_constant("v_separation", "ItemList", 6)
	t.set_constant("h_separation", "ItemList", 8)
	t.set_constant("icon_margin", "ItemList", 8)
	for sbn in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sbn, tex9("scroll9", 4, 3))
		t.set_stylebox("scroll_focus", sbn, tex9("scroll9", 4, 3))
		t.set_stylebox("grabber", sbn, tex9("grab9", 4, 3))
		t.set_stylebox("grabber_highlight", sbn, tex9("grab9_h", 4, 3))
		t.set_stylebox("grabber_pressed", sbn, tex9("grab9_h", 4, 3))
	t.set_stylebox("panel", "PopupMenu", tex9("panel9", 14, 8))
	t.set_stylebox("hover", "PopupMenu", tex9("sel9", 6, 4))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color(1, 0.94, 0.78))
	t.set_constant("v_separation", "PopupMenu", 8)
	t.set_stylebox("panel", "TabContainer", tex9("panel9", 14, 10))
	t.set_stylebox("tab_selected", "TabContainer", tex9("btn_p", 10, 10))
	t.set_stylebox("tab_unselected", "TabContainer", tex9("btn_n", 10, 10))
	t.set_stylebox("tab_hovered", "TabContainer", tex9("btn_h", 10, 10))
	t.set_stylebox("tab_focus", "TabContainer", StyleBoxEmpty.new())
	t.set_color("font_selected_color", "TabContainer", ACCENT.lightened(0.2))
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", TEXT)
	t.set_font_size("font_size", "TabContainer", 15)
	t.set_stylebox("background", "ProgressBar", tex9("bar_bg9", 4, 0))
	t.set_stylebox("fill", "ProgressBar", tex9("bar_fill9", 4, 0))
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_stylebox("panel", "TooltipPanel", tex9("panel9", 14, 8))
	t.set_color("font_color", "TooltipLabel", TEXT)
	for le in ["LineEdit", "SpinBox"]:
		t.set_stylebox("normal", le, tex9("list9", 8, 6))
		t.set_stylebox("focus", le, tex9("sel9", 6, 6))
	t.set_stylebox("panel", "PanelContainer", tex9("panel9", 14, 12))
	_theme = t
	return t


# ---------------------------------------------------------------- 小部件
static func label(text := "", size := 15, c := TEXT, outline := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("outline_size", 5)
	return l


## 区块标题：左侧琥珀色竖条 + 文字 + 可选副标题
static func header(title: String, sub := "", size := 17) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var bar := ColorRect.new()
	bar.color = ACCENT
	bar.custom_minimum_size = Vector2(3, 0)
	h.add_child(bar)
	h.add_child(label(title, size, Color(1, 1, 1)))
	if sub != "":
		var s := label(sub, 12, MUTED)
		s.size_flags_vertical = Control.SIZE_SHRINK_END
		h.add_child(s)
	return h


static func panel(pad := 12, accent := true) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := tex9("strip9" if accent else "panel9", 8 if accent else 14, pad)
	if accent:
		sb.content_margin_left = pad + 6
	p.add_theme_stylebox_override("panel", sb)
	return p


## 键帽：[Q] 文字（贴图键帽，底部亮橙条）
static func keycap(key: String, size := 13) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := tex9("key9", 7, 6)
	sb.content_margin_top = 1
	sb.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", sb)
	var l := label(key, size, Color(1, 1, 1))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.custom_minimum_size = Vector2(24, 0)
	return p


## 稀有度色块图标（ItemList 用）
static var _icons := {}
static func rarity_icon(rar: int, cat := "") -> Texture2D:
	var key := "%d%s" % [rar, cat]
	if _icons.has(key):
		return _icons[key]
	var GD = Engine.get_main_loop().root.get_node("GameData")
	var c: Color = GD.RARITY_COLORS[rar]
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 20:
		for x in 20:
			var edge := x < 2 or y < 2 or x > 17 or y > 17
			var corner := (x < 2 and y < 2) or (x > 17 and y < 2) or (x < 2 and y > 17) or (x > 17 and y > 17)
			if corner:
				continue
			if edge:
				img.set_pixel(x, y, c)
			else:
				img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.18))
	# 中心小符号：按类别画不同形状
	var cc := c.lightened(0.2)
	match cat:
		"food":
			for y in range(6, 14):
				for x in range(6, 14):
					if Vector2(x - 9.5, y - 9.5).length() < 4.2:
						img.set_pixel(x, y, cc)
		"misc":
			for y in range(6, 14):
				for x in range(6, 14):
					if abs(x - 9.5) + abs(y - 9.5) < 4.6:
						img.set_pixel(x, y, cc)
		"use":
			for i in range(5, 15):
				img.set_pixel(i, 9, cc)
				img.set_pixel(i, 10, cc)
				img.set_pixel(9, i, cc)
				img.set_pixel(10, i, cc)
		"money":
			for y in range(7, 13):
				for x in range(5, 15):
					img.set_pixel(x, y, cc)
		"module":
			for y in range(5, 15):
				for x in range(5, 15):
					if x == 5 or x == 14 or y == 5 or y == 14 or (x > 7 and x < 12 and y > 7 and y < 12):
						img.set_pixel(x, y, cc)
		_:
			pass
	var t := ImageTexture.create_from_image(img)
	_icons[key] = t
	return t


# ---------------------------------------------------------------- 自绘控件
## 分段能量条
class SegBar extends Control:
	var value := 1.0
	var max_value := 1.0
	var color := Color(1, 0.8, 0.2)
	var segments := 20
	var ghost := 1.0   ## 受伤后残影
	var blink := false

	func _init(c := Color(1, 0.8, 0.2), seg := 20, h := 12.0) -> void:
		color = c
		segments = seg
		custom_minimum_size = Vector2(200, h)

	func set_value(v: float, mx: float) -> void:
		value = v
		max_value = max(mx, 0.001)
		queue_redraw()

	func _process(delta: float) -> void:
		var f: float = clamp(value / max_value, 0.0, 1.0)
		if ghost > f:
			ghost = max(f, ghost - delta * 0.6)
			queue_redraw()
		else:
			ghost = f
		if blink:
			queue_redraw()

	func _draw() -> void:
		var f: float = clamp(value / max_value, 0.0, 1.0)
		var gap := 2.0
		var w: float = (size.x - gap * (segments - 1)) / segments
		var a := 1.0
		if blink:
			a = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.015)
		for i in segments:
			var x := i * (w + gap)
			var r := Rect2(x, 0, w, size.y)
			var t0 := float(i) / segments
			var t1 := float(i + 1) / segments
			draw_rect(r, Color(1, 1, 1, 0.07))
			if f >= t1:
				draw_rect(r, Color(color.r, color.g, color.b, a))
			elif f > t0:
				var part: float = (f - t0) / (t1 - t0)
				draw_rect(Rect2(x, 0, w * part, size.y), Color(color.r, color.g, color.b, a))
			if ghost > t0 and f < t1:
				var g0: float = max(f, t0)
				var g1: float = min(ghost, t1)
				if g1 > g0:
					draw_rect(Rect2(x + (g0 - t0) / (t1 - t0) * w, 0, (g1 - g0) / (t1 - t0) * w, size.y), Color(1, 1, 1, 0.45))
		draw_rect(Rect2(0, size.y - 1, size.x, 1), Color(color.r, color.g, color.b, 0.25))


## 冷却遮罩方块（武器/技能卡片用）
class CooldownTile extends Control:
	var frac := 0.0
	var color := Color(1, 0.6, 0.16)

	func set_frac(f: float) -> void:
		if abs(f - frac) > 0.001:
			frac = f
			queue_redraw()

	func _draw() -> void:
		if frac <= 0.0:
			return
		draw_rect(Rect2(0, size.y * (1.0 - frac), size.x, size.y * frac), Color(0, 0, 0, 0.55))


## 雷达小地图
class Radar extends Control:
	var raid
	var rng_m := 48.0

	func _init() -> void:
		custom_minimum_size = Vector2(200, 200)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	## 地形：以机甲为中心，从地形图取样贴成圆形
	func _draw_terrain(c: Vector2, r: float) -> void:
		if raid.map_tex == null:
			return
		var mp: Vector3 = raid.mech.global_position
		var H: float = raid.HALF
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		var cols := PackedColorArray()
		for i in 48:
			var a := TAU * i / 48.0
			var d := Vector2(cos(a), sin(a))
			pts.append(c + d * r)
			var w := Vector2(mp.x, mp.z) + d * rng_m
			uvs.append((w + Vector2(H, H)) / (H * 2.0))
			cols.append(Color(0.75, 0.75, 0.75, 0.9))
		draw_polygon(pts, cols, uvs, raid.map_tex)

	func _to_screen(rel: Vector3, r: float) -> Vector2:
		var v := Vector2(rel.x, rel.z) / rng_m * r
		return v

	func _draw() -> void:
		if raid == null or raid.mech == null:
			return
		var c := size * 0.5
		var r: float = min(size.x, size.y) * 0.5 - 2.0
		draw_circle(c, r, Color(0.035, 0.035, 0.04, 0.86))
		_draw_terrain(c, r)
		for k in [0.33, 0.66]:
			draw_arc(c, r * k, 0, TAU, 48, Color(1.0, 0.72, 0.2, 0.12), 1.0, true)
		draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(1.0, 0.72, 0.2, 0.08))
		draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(1.0, 0.72, 0.2, 0.08))
		# 扫描线
		var t := Time.get_ticks_msec() * 0.0015
		for i in 12:
			var a := t - i * 0.04
			draw_line(c, c + Vector2(cos(a), sin(a)) * r, Color(1.0, 0.72, 0.2, 0.12 * (1.0 - i / 12.0)), 2.0)
		var mp: Vector3 = raid.mech.global_position
		# 容器
		for b in raid.get_tree().get_nodes_in_group("lootboxes"):
			if b.items.is_empty():
				continue
			var p := _to_screen(b.global_position - mp, r)
			if p.length() < r - 3:
				draw_rect(Rect2(c + p - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.85, 0.4, 0.75))
		# 虫巢
		for n in raid.get_tree().get_nodes_in_group("nests"):
			var p := _to_screen(n.global_position - mp, r)
			if p.length() < r - 4:
				draw_circle(c + p, 4.5, Color(0.95, 0.35, 0.85, 0.9))
		# 虫子
		for b in raid.get_tree().get_nodes_in_group("bugs"):
			var p := _to_screen(b.global_position - mp, r)
			if p.length() < r - 2:
				draw_circle(c + p, 2.4 if b.kind != "beetle" else 3.6, Color(1.0, 0.3, 0.25, 0.95))
		# 撤离点：超出范围就贴在边缘
		var zs: Array = raid.extracts.duplicate()
		if raid.transport_zone and raid.transport_zone.active:
			zs.append(raid.transport_zone)
		for z in zs:
			var p := _to_screen(z.global_position - mp, r)
			if p.length() > r - 8:
				p = p.normalized() * (r - 8)
			var q := c + p
			var col: Color = z.color
			draw_colored_polygon(PackedVector2Array([q + Vector2(0, -7), q + Vector2(7, 0), q + Vector2(0, 7), q + Vector2(-7, 0)]), col)
			draw_polyline(PackedVector2Array([q + Vector2(0, -7), q + Vector2(7, 0), q + Vector2(0, 7), q + Vector2(-7, 0), q + Vector2(0, -7)]), Color(0, 0, 0, 0.6), 1.0)
		# 自己：朝向躯干方向的箭头
		var fwd: Vector3 = -raid.mech.torso.global_transform.basis.z
		var f := Vector2(fwd.x, fwd.z).normalized()
		var side := Vector2(-f.y, f.x)
		draw_colored_polygon(PackedVector2Array([c + f * 9, c - f * 5 + side * 6, c - f * 2, c - f * 5 - side * 6]), Color(1, 1, 1))
		# 金属外圈 + 刻度（玩家方：黑灰 + 亮橙黄）
		draw_arc(c, r + 1, 0, TAU, 72, Color(0.2, 0.21, 0.24), 8.0, true)
		draw_arc(c, r + 4.5, 0, TAU, 72, Color(0.48, 0.5, 0.55), 1.2, true)
		draw_arc(c, r - 3, 0, TAU, 72, Color(0, 0, 0, 0.8), 1.5, true)
		for k in 36:
			var a := k * TAU / 36.0
			var dd := Vector2(cos(a), sin(a))
			var big := k % 3 == 0
			draw_line(c + dd * (r - (3.0 if big else 1.0)), c + dd * (r + 4), Color(1.0, 0.69, 0.13) if k % 9 == 0 else Color(0.75, 0.76, 0.8, 0.7), 2.0 if big else 1.0)
		draw_arc(c, r + 1, -0.9, -0.3, 12, Color(1.0, 0.69, 0.13), 3.0, true)
		draw_arc(c, r + 1, 2.2, 2.8, 12, Color(1.0, 0.69, 0.13), 3.0, true)
		draw_string(ThemeDB.fallback_font, c + Vector2(-4, -r + 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.72, 0.2, 0.6))


## 大地图（M 打开）：整张地形图 + 区域名 + 坐标网格 + 撤离点 / 运输机 / 虫巢 / 自己
class BigMap extends Control:
	var raid
	const AMBER := Color(1.0, 0.69, 0.13)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		visible = false

	func _process(_d: float) -> void:
		if visible:
			queue_redraw()

	func _w2m(p: Vector3, rect: Rect2) -> Vector2:
		var H: float = raid.HALF
		return rect.position + Vector2((p.x + H) / (H * 2.0), (p.z + H) / (H * 2.0)) * rect.size

	func _draw() -> void:
		if raid == null or raid.map_tex == null or raid.mech == null:
			return
		var f := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.025, 0.82))
		var side: float = minf(size.y - 120.0, size.x - 120.0)
		var rect := Rect2((size - Vector2(side, side)) * 0.5 + Vector2(0, 10), Vector2(side, side))
		# 外框
		draw_rect(rect.grow(10), Color(0.12, 0.125, 0.14))
		draw_rect(rect.grow(10), Color(0.45, 0.47, 0.52), false, 1.5)
		draw_texture_rect(raid.map_tex, rect, false)
		# 网格 + 坐标
		var H: float = raid.HALF
		var letters := "ABCDEFGHI"
		var cs: float = side / 9.0
		for i in 9:
			draw_string(f, Vector2(rect.position.x + (i + 0.5) * cs - 4, rect.position.y - 16), letters[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.55))
			draw_string(f, Vector2(rect.position.x - 24, rect.position.y + (i + 0.5) * cs + 5), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.55))
		for i in 10:
			var t: float = i * cs
			draw_line(Vector2(rect.position.x + t, rect.position.y), Vector2(rect.position.x + t, rect.end.y), Color(1, 1, 1, 0.06), 1.0)
			draw_line(Vector2(rect.position.x, rect.position.y + t), Vector2(rect.end.x, rect.position.y + t), Color(1, 1, 1, 0.06), 1.0)
		# 地名
		for l: Array in raid.map_labels:
			var nm: String = l[0]
			var q := _w2m(Vector3(l[1], 0, l[2]), rect)
			var tw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			var tp := q - Vector2(tw * 0.5, -5)
			for o in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_string(f, tp + o, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0, 0, 0, 0.75))
			draw_string(f, tp, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.95, 0.85, 0.85))
		# 虫巢
		for n in raid.get_tree().get_nodes_in_group("nests"):
			var q := _w2m(n.global_position, rect)
			draw_circle(q, 6.0, Color(0.95, 0.35, 0.85, 0.9))
			draw_arc(q, 9.0, 0, TAU, 20, Color(0.95, 0.35, 0.85, 0.5), 1.5, true)
		# 撤离点 / 运输机
		var zs: Array = raid.extracts.duplicate()
		if raid.transport_zone and raid.transport_zone.active:
			zs.append(raid.transport_zone)
		for z in zs:
			var q := _w2m(z.global_position, rect)
			var col: Color = z.color
			var dm := PackedVector2Array([q + Vector2(0, -9), q + Vector2(9, 0), q + Vector2(0, 9), q + Vector2(-9, 0)])
			draw_colored_polygon(dm, col)
			dm.append(dm[0])
			draw_polyline(dm, Color(0, 0, 0, 0.8), 1.5)
			var label: String = str(z.title)
			draw_string(f, q + Vector2(13, 5) + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.8))
			draw_string(f, q + Vector2(13, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
		# 自己
		var mp: Vector3 = raid.mech.global_position
		var c := _w2m(mp, rect)
		var fwd: Vector3 = -raid.mech.torso.global_transform.basis.z
		var fv := Vector2(fwd.x, fwd.z).normalized()
		var sd := Vector2(-fv.y, fv.x)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		draw_arc(c, 10.0 + pulse * 6.0, 0, TAU, 24, Color(AMBER.r, AMBER.g, AMBER.b, 0.6 * (1.0 - pulse)), 2.0, true)
		draw_colored_polygon(PackedVector2Array([c + fv * 11, c - fv * 6 + sd * 7, c - fv * 2, c - fv * 6 - sd * 7]), Color(0, 0, 0, 0.7))
		draw_colored_polygon(PackedVector2Array([c + fv * 9, c - fv * 5 + sd * 6, c - fv * 2, c - fv * 5 - sd * 6]), AMBER)
		# 标题 / 图例 / 比例尺
		draw_string(f, Vector2(rect.position.x, rect.position.y - 40), "战区地图 · " + str(raid.MAP.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.9))
		var cur: String = raid.district_at(mp)
		draw_string(f, Vector2(rect.position.x + 230, rect.position.y - 40), "当前位置：" + cur, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, AMBER)
		var px_per_m := side / (H * 2.0)
		var sb := Vector2(rect.end.x - 50.0 * px_per_m, rect.end.y + 24)
		draw_line(sb, sb + Vector2(50.0 * px_per_m, 0), Color(1, 1, 1, 0.7), 2.0)
		draw_string(f, sb + Vector2(0, 16), "50m", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.6))
		draw_string(f, Vector2(rect.position.x, rect.end.y + 30), "M / Esc 关闭", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.45))


## 机甲火控准星：
## - 外框（四角括号 + 刻度弧）以阻尼跟随鼠标，有拖曳感；开火时括号外扩（后坐散布）
## - 内圈“弹着点”= 躯干真实朝向投影，躯干转向有惯性，所以它会滞后追赶外框，二者之间有牵引虚线
## - 两侧弧条显示左右武器冷却；右下角显示测距
class Crosshair extends Control:
	var mech
	var pos := Vector2.ZERO
	var pip := Vector2.ZERO
	var bloom := 0.0
	var spin := 0.0
	var _init_done := false
	const AMBER := Color(1.0, 0.69, 0.13)
	const SHADOW := Color(0, 0, 0, 0.55)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(d: float) -> void:
		var m := get_viewport().get_mouse_position()
		if not _init_done:
			pos = m
			pip = m
			_init_done = true
		pos = pos.lerp(m, 1.0 - exp(-16.0 * d))
		spin += d * 0.6
		if mech and is_instance_valid(mech):
			var r := 0.0
			for k in mech.recoil:
				r = maxf(r, mech.recoil[k])
			bloom = maxf(bloom - d * 3.0, r)
			var cam := get_viewport().get_camera_3d()
			if cam and mech.torso:
				var o: Vector3 = mech.global_position
				var dist := Vector2(mech.aim_point.x - o.x, mech.aim_point.z - o.z).length()
				var w: Vector3 = o + mech.aim_dir() * dist
				w.y = 1.8
				if not cam.is_position_behind(w):
					pip = pip.lerp(cam.unproject_position(w), 1.0 - exp(-30.0 * d))
		queue_redraw()

	func _seg(a: Vector2, b: Vector2, c: Color, w: float) -> void:
		draw_line(a, b, SHADOW, w + 2.0, true)
		draw_line(a, b, c, w, true)

	func _draw() -> void:
		var p := pos
		var white := Color(0.95, 0.95, 0.92, 0.95)
		var gap := 15.0 + bloom * 9.0
		var arm := 7.0
		# 四角括号
		for k in 4:
			var ang := PI * 0.25 + k * PI * 0.5
			var c := p + Vector2(cos(ang), sin(ang)) * gap
			var hx := Vector2(-signf(cos(ang)) * arm, 0)
			var hy := Vector2(0, -signf(sin(ang)) * arm)
			_seg(c, c + hx, white, 2.0)
			_seg(c, c + hy, white, 2.0)
		# 中心十字点
		for dv in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			_seg(p + dv * 3.0, p + dv * 6.0, white, 1.5)
		# 慢速旋转的刻度弧
		var R := gap + 12.0
		for k in 3:
			var a0 := spin + k * TAU / 3.0
			draw_arc(p, R, a0, a0 + 0.7, 10, Color(1, 1, 1, 0.22), 1.5, true)
			var tip := p + Vector2(cos(a0), sin(a0)) * R
			draw_line(tip, tip + Vector2(cos(a0), sin(a0)) * 4.0, Color(1, 1, 1, 0.35), 1.5, true)
		# 弹着点（躯干真实朝向）+ 牵引线
		var off := pip - p
		var aligned := off.length() < 6.0
		if not aligned:
			var n := int(off.length() / 7.0)
			for i in n:
				if i % 2 == 0:
					draw_line(p + off * (float(i) / n), p + off * (float(i + 1) / n), Color(AMBER.r, AMBER.g, AMBER.b, 0.55), 1.5, true)
		var pc := AMBER if not aligned else Color(1.0, 0.85, 0.45)
		draw_arc(pip, 5.5, 0, TAU, 20, SHADOW, 4.0, true)
		draw_arc(pip, 5.5, 0, TAU, 20, pc, 2.0, true)
		if aligned:
			draw_circle(pip, 2.0, pc)
		if mech == null or not is_instance_valid(mech):
			return
		# 测距
		var dist := Vector2(mech.aim_point.x - mech.global_position.x, mech.aim_point.z - mech.global_position.z).length()
		var f := ThemeDB.fallback_font
		var tp := p + Vector2(gap + 8.0, gap + 14.0)
		draw_string(f, tp + Vector2(1, 1), "%03dm" % int(dist), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, SHADOW)
		draw_string(f, tp, "%03dm" % int(dist), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.7))
		# 左右武器冷却弧
		var cds: Dictionary = mech.arm_cd
		var GD = Engine.get_main_loop().root.get_node("GameData")
		var i := 0
		for slot in ["arm_l", "arm_r"]:
			var id: String = mech.loadout.get(slot, "")
			if id == "":
				i += 1
				continue
			var rate: float = float(GD.module(id).get("rate", 1.0))
			var fr: float = clamp(cds.get(slot, 0.0) * rate, 0.0, 1.0)
			var rr := gap + 5.0
			var a0 := PI * 0.72 if i == 0 else -PI * 0.28
			draw_arc(p, rr, a0, a0 + PI * 0.56, 14, Color(0, 0, 0, 0.35), 4.0, true)
			draw_arc(p, rr, a0, a0 + PI * 0.56 * (1.0 - fr), 14, Color(AMBER.r, AMBER.g, AMBER.b, 0.9), 2.0, true)
			i += 1
