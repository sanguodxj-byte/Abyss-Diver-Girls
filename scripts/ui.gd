extends RefCounted
## 统一的像素风科幻工业 UI 主题与小部件（像素字体 + 2 倍像素格贴图，见 scripts/pixel_ui.gd、tools/pixelize_ui.py）。
## 玩家方色板：金属黑灰 + 亮橙黄（铁血紫只给敌方）。所有控件使用 assets/ui 下的贴图九宫格，不保留引擎默认样式。

const PixelTheme = preload("res://scripts/pixel_theme.gd")

const BG := Color(0.082, 0.088, 0.094, 0.96)
const BG2 := Color(0.118, 0.126, 0.134, 0.97)
const LINE := Color(0.22, 0.24, 0.26, 0.94)
const STEEL := Color(0.46, 0.49, 0.52)
const STEEL_MID := Color(0.30, 0.33, 0.35)
const ACCENT := Color(0.78, 0.48, 0.16)
const ACCENT_HI := Color(0.87, 0.59, 0.25)
const ACCENT_DIM := Color(0.78, 0.48, 0.16, 0.38)
const GOLD := Color(0.84, 0.58, 0.22)
const INFO := Color(0.58, 0.73, 0.78)
const TEXT := Color(0.88, 0.88, 0.85)
const MUTED := Color(0.56, 0.58, 0.58)
const GOOD := Color(0.46, 0.76, 0.50)
const BAD := Color(0.84, 0.33, 0.25)
const HP_C := Color(0.84, 0.33, 0.25)
const EN_C := Color(0.84, 0.58, 0.22)

static var _theme: Theme


class HazardStrip extends Control:
	func _init(h := 8) -> void:
		custom_minimum_size = Vector2(0, h)
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		load("res://scripts/ui.gd").draw_hazard(self, Rect2(Vector2.ZERO, size))


static func draw_hazard(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, Color(0.085, 0.092, 0.098, 0.96), true)
	var stripe_w := 7.0
	var period := 14.0
	var skew := r.size.y
	var idx := 0
	var x := -skew - period
	while x < r.size.x + period:
		var wear := 0.88 if (idx % 3 == 0) else (0.95 if (idx % 2 == 0) else 0.78)
		var y_col := Color(0.76 * wear, 0.46 * wear, 0.14 * wear, 0.90)
		var x0 := r.position.x + x
		var p := PackedVector2Array([
			Vector2(clampf(x0 + skew, r.position.x, r.end.x), r.position.y),
			Vector2(clampf(x0 + skew + stripe_w, r.position.x, r.end.x), r.position.y),
			Vector2(clampf(x0 + stripe_w, r.position.x, r.end.x), r.end.y),
			Vector2(clampf(x0, r.position.x, r.end.x), r.end.y),
		])
		ci.draw_colored_polygon(p, y_col)
		x += period
		idx += 1
	ci.draw_line(r.position, Vector2(r.end.x, r.position.y), Color(STEEL.r, STEEL.g, STEEL.b, 0.42), 1.0, true)
	ci.draw_line(Vector2(r.position.x, r.end.y), r.end, Color(0.24, 0.26, 0.27, 0.92), 1.0, true)


static var _tex := {}
static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load("res://assets/ui/%s.png" % name)
	return _tex[name]


## Flat HD2 StyleBox builder replacing all legacy pixel 9-patch textures
static func px_tex(name: String) -> Texture2D:
	var path := "res://assets/ui/px/%s.png" % name
	return load(path) if ResourceLoader.exists(path) else null


static func px9(name: String, mlr := 12, mtb := 12, plr := 10, ptb := 8, tint := Color(1, 1, 1)) -> StyleBox:
	return PixelTheme.px9(name, mlr, mtb, plr, ptb, tint)


## Crisp 45-degree HD2 tactical hazard bar
static func hazard_strip(h := 8) -> Control:
	return HazardStrip.new(h)


static func _is_en() -> bool:
	var ml := Engine.get_main_loop()
	if ml == null or not (ml is SceneTree):
		return false
	var loc := (ml as SceneTree).root.get_node_or_null("Loc")
	return loc != null and bool(loc.call("is_en"))


static func _lt(zh: String, en := "") -> String:
	var ml := Engine.get_main_loop()
	if ml == null or not (ml is SceneTree):
		return zh
	var loc := (ml as SceneTree).root.get_node_or_null("Loc")
	return str(loc.call("t", zh, en)) if loc != null else zh


## 铆钉铭牌标题栏（左琥珀竖条 + 工业灰黑金属片 + 标题 + 右侧附加文本）
static func plate_header(title: String, sub := "", right := "", pad := 10) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", px9("hdr_dark9", 14, 14, pad, 6))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	p.add_child(hb)
	var bar := ColorRect.new()
	bar.color = ACCENT
	bar.custom_minimum_size = Vector2(4, 15)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(bar)
	var tag_st := ColorRect.new()
	tag_st.color = STEEL
	tag_st.custom_minimum_size = Vector2(3, 9)
	tag_st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(tag_st)
	hb.add_child(label(title, 14, TEXT))
	if sub != "" and sub.to_upper() != title.to_upper():
		hb.add_child(label(sub, 12, MUTED))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	if right != "":
		hb.add_child(label(right, 13, ACCENT_HI))
	return p


## Flat geometric stylebox for dynamic progress bars & slots
static func flat_bar(bg: Color, border := LINE, bw := 1, pad := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	sb.anti_aliasing = true
	return sb


## Flat HD2 compatibility wrapper replacing old nine-patch tex9
static func tex9(name: String, margin := 12, pad := 12, tint := Color(1, 1, 1)) -> StyleBox:
	return PixelTheme.px9(name, margin, margin, pad, maxi(4, int(round(pad * 0.75))), tint)


## 按底色语义挑选 v0.8 工业像素贴图（亮橙→主按钮，半透明浅色→凹槽底，其余→钢板面板）
static func box(bg := BG, _border := LINE, _bw := 1, _top := 0, _top_c := ACCENT, _radius := 3, pad := 12) -> StyleBox:
	if bg.a > 0.8 and bg.r > 0.6 and bg.b < 0.3:
		var n := "btn9_main_h" if bg.r > 0.95 else ("btn9_main_p" if bg.r < 0.8 else "btn9_main_n")
		return px9(n, 10, 10, pad, maxi(6, int(pad * 0.65)))
	if bg.a < 0.3:
		return px9("inset9", 6, 6, pad, maxi(4, int(pad * 0.65)))
	return px9("panel9", 16, 16, pad, maxi(6, int(pad * 0.75)), Color(1, 1, 1, clampf(bg.a + 0.08, 0.78, 1.0)))


static func theme() -> Theme:
	# 所有界面统一走像素主题（scripts\pixel_theme.gd）
	return PixelTheme.build()


# ---------------------------------------------------------------- 小部件
static func label(text := "", size := 15, c := TEXT, outline := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", PixelUI.snap(size))
	l.add_theme_color_override("font_color", c)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.78))
		l.add_theme_constant_override("outline_size", 3)
	return l


## 区块标题：左侧琥珀色竖条 + 灰白铆钉标记 + 文字 + 可选副标题
static func header(title: String, sub := "", size := 17) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var bar := ColorRect.new()
	bar.color = ACCENT
	bar.custom_minimum_size = Vector2(4, 0)
	h.add_child(bar)
	var st := ColorRect.new()
	st.color = STEEL
	st.custom_minimum_size = Vector2(2, 0)
	h.add_child(st)
	h.add_child(label(title, size, TEXT))
	if sub != "":
		var s := label(sub, 12, MUTED)
		s.size_flags_vertical = Control.SIZE_SHRINK_END
		h.add_child(s)
	return h


static func panel(pad := 12, accent := true) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := px9("card9" if accent else "panel9", 10 if accent else 16, 10 if accent else 16, pad + (4 if accent else 0), maxi(6, int(pad * 0.75)))
	p.add_theme_stylebox_override("panel", sb)
	return p


## 键帽：[Q] 工业灰黑阳极氧化金属键帽，浅灰白丝印字标
static func keycap(key: String, size := 13, bg_alpha := 1.0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := tex9("key9", 6, 6, Color(1, 1, 1, bg_alpha))
	sb.content_margin_top = 1
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var l := label(key, size, Color(0.88, 0.89, 0.86))
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
	var color := Color(0.82, 0.54, 0.20)
	var segments := 20
	var ghost := 1.0   ## 受伤后残影
	var blink := false

	func _init(c := Color(0.82, 0.54, 0.20), seg := 20, h := 12.0) -> void:
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
			draw_rect(r, Color(0.08, 0.085, 0.09, 0.85))
			draw_rect(r, Color(0.36, 0.39, 0.40, 0.45), false, 1.0)
			if f >= t1:
				draw_rect(r, Color(color.r, color.g, color.b, a))
				draw_rect(Rect2(x, 0, w, 1.5), Color(0.92, 0.93, 0.92, 0.25 * a))
			elif f > t0:
				var part: float = (f - t0) / (t1 - t0)
				draw_rect(Rect2(x, 0, w * part, size.y), Color(color.r, color.g, color.b, a))
			if ghost > t0 and f < t1:
				var g0: float = max(f, t0)
				var g1: float = min(ghost, t1)
				if g1 > g0:
					draw_rect(Rect2(x + (g0 - t0) / (t1 - t0) * w, 0, (g1 - g0) / (t1 - t0) * w, size.y), Color(0.86, 0.88, 0.88, 0.55))
		draw_rect(Rect2(0, size.y - 1, size.x, 1), Color(0.68, 0.71, 0.72, 0.38))


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
	var _redraw_acc := 0.05

	func _init() -> void:
		custom_minimum_size = Vector2(200, 200)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(d: float) -> void:
		if not is_visible_in_tree():
			return
		_redraw_acc += d
		if _redraw_acc >= 0.05:
			_redraw_acc = 0.0
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
			cols.append(Color(0.84, 0.84, 0.84, 0.64))
		draw_polygon(pts, cols, uvs, raid.map_tex)

	func _to_screen(rel: Vector3, r: float) -> Vector2:
		var v := Vector2(rel.x, rel.z) / rng_m * r
		return v

	func _draw() -> void:
		if raid == null or raid.mech == null:
			return
		var c := size * 0.5
		var r: float = min(size.x, size.y) * 0.5 - 2.0
		draw_circle(c, r, Color(0.06, 0.068, 0.074, 0.54))
		_draw_terrain(c, r)
		for k in [0.33, 0.66]:
			draw_arc(c, r * k, 0, TAU, 48, Color(0.78, 0.48, 0.16, 0.18), 1.0, true)
		draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(0.72, 0.75, 0.76, 0.14), 1.0, true)
		draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(0.72, 0.75, 0.76, 0.14), 1.0, true)
		# 躯干朝向视界扇区
		var fwd: Vector3 = -raid.mech.torso.global_transform.basis.z
		var f := Vector2(fwd.x, fwd.z).normalized()
		var side := Vector2(-f.y, f.x)
		var base_ang := atan2(f.y, f.x)
		var fov_pts := PackedVector2Array([c])
		for i in 13:
			var a := base_ang - 0.42 + 0.84 * (float(i) / 12.0)
			fov_pts.append(c + Vector2(cos(a), sin(a)) * (r * 0.82))
		draw_colored_polygon(fov_pts, Color(0.78, 0.48, 0.16, 0.12))
		draw_line(c, fov_pts[1], Color(0.84, 0.56, 0.22, 0.34), 1.0, true)
		draw_line(c, fov_pts[fov_pts.size() - 1], Color(0.84, 0.56, 0.22, 0.34), 1.0, true)
		# 扫描线
		var t := Time.get_ticks_msec() * 0.0015
		for i in 12:
			var a := t - i * 0.04
			draw_line(c, c + Vector2(cos(a), sin(a)) * r, Color(0.82, 0.52, 0.18, 0.15 * (1.0 - i / 12.0)), 2.0, true)
		var mp: Vector3 = raid.mech.global_position
		# 重点遗迹 POI（范围内显示做旧橙黄小菱形）
		for pc: Vector3 in raid.poi_centers:
			var p := _to_screen(pc - mp, r)
			if p.length() < r - 5:
				var q := c + p
				draw_colored_polygon(PackedVector2Array([q + Vector2(0, -4), q + Vector2(4, 0), q + Vector2(0, 4), q + Vector2(-4, 0)]), Color(0.84, 0.58, 0.22, 0.90))
		# 容器
		for b in raid.get_tree().get_nodes_in_group("lootboxes"):
			if b.items.is_empty():
				continue
			var p := _to_screen(b.global_position - mp, r)
			if p.length() < r - 3:
				draw_rect(Rect2(c + p - Vector2(2, 2), Vector2(4, 4)), Color(0.76, 0.62, 0.32, 0.82))
		# 虫巢
		for n in raid.get_tree().get_nodes_in_group("nests"):
			var p := _to_screen(n.global_position - mp, r)
			if p.length() < r - 4:
				draw_circle(c + p, 4.5, Color(0.82, 0.36, 0.68, 0.9))
		# 虫子
		for b in raid.get_tree().get_nodes_in_group("bugs"):
			if bool(b.data.get("boss", false)):
				continue
			var p := _to_screen(b.global_position - mp, r)
			if p.length() < r - 2:
				draw_circle(c + p, 2.4 if b.kind != "beetle" else 3.6, Color(0.88, 0.34, 0.26, 0.95))
		# 随行队友
		if raid.factions != null and "allies" in raid.factions:
			for al in raid.factions.allies:
				if al == null or not is_instance_valid(al) or al.dead:
					continue
				var p := _to_screen(al.global_position - mp, r)
				if p.length() > r - 7:
					p = p.normalized() * (r - 7)
				draw_circle(c + p, 4.0, Color(0.58, 0.78, 0.84, 0.95))
				draw_arc(c + p, 5.5, 0, TAU, 12, Color(0, 0, 0, 0.75), 1.2, false)
		# 战区首领（超出雷达范围时贴在边缘指示方向）
		for b in raid.get_tree().get_nodes_in_group("boss"):
			if not is_instance_valid(b) or b.dying:
				continue
			var p := _to_screen(b.global_position - mp, r)
			if p.length() > r - 8:
				p = p.normalized() * (r - 8)
			var q := c + p
			var bcol := Color(0.88, 0.28, 0.28, 0.96)
			draw_arc(q, 7.5, 0, TAU, 16, Color(0.88, 0.28, 0.28, 0.55), 1.5, false)
			draw_colored_polygon(PackedVector2Array([q + Vector2(0, -5.5), q + Vector2(5.5, 0), q + Vector2(0, 5.5), q + Vector2(-5.5, 0)]), bcol)
			draw_circle(q, 2.0, Color(0.92, 0.86, 0.74, 0.95))
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
		# 玩家战前自定地图标记（同步显示在雷达上，超出范围贴边指示方向）
		var gd_mm := get_node_or_null("/root/GameData")
		if gd_mm != null and gd_mm.has_method("markers_for_map"):
			for mk: Dictionary in gd_mm.call("markers_for_map", str(raid.map_id)):
				var mk3 := Vector3(float(mk.get("lx", 0.0)), 0.0, float(mk.get("lz", 0.0)))
				var pm := _to_screen(mk3 - mp, r)
				if pm.length() > r - 8:
					pm = pm.normalized() * (r - 8)
				var qm := c + pm
				var mcol: Color = gd_mm.call("marker_color", str(mk.get("color", "amber")))
				draw_circle(qm, 4.5, Color(0, 0, 0, 0.85))
				draw_circle(qm, 3.2, mcol)
				draw_circle(qm, 1.3, Color(0.08, 0.09, 0.10))
		# 战术标点（在大地图上右键标点后同步显示在雷达上）
		if raid.has_meta("map_waypoint"):
			var wp: Vector3 = raid.get_meta("map_waypoint")
			var p := _to_screen(wp - mp, r)
			if p.length() > r - 8:
				p = p.normalized() * (r - 8)
			var q := c + p
			var wcol := Color(0.58, 0.78, 0.84, 0.96)
			draw_arc(q, 5.5, 0, TAU, 16, Color(0, 0, 0, 0.8), 2.2, false)
			draw_arc(q, 5.5, 0, TAU, 16, wcol, 1.5, false)
			draw_circle(q, 2.0, wcol)
		# 自己：朝向躯干方向的工业浅灰方向箭头
		draw_colored_polygon(PackedVector2Array([c + f * 9, c - f * 5 + side * 6, c - f * 2, c - f * 5 - side * 6]), Color(0.88, 0.89, 0.86))
		# 外圈工业灰黑机加工罗盘表圈 + 做旧橙黄刻度弧
		draw_arc(c, r + 1.0, 0, TAU, 72, Color(0.11, 0.12, 0.13, 0.76), 7.5, true)
		draw_arc(c, r + 4.5, 0, TAU, 72, Color(0.36, 0.39, 0.41, 0.82), 1.6, true)
		draw_arc(c, r - 3.0, 0, TAU, 72, Color(0.05, 0.055, 0.06, 0.72), 1.5, true)
		for k in 36:
			var a := k * TAU / 36.0
			var dd := Vector2(cos(a), sin(a))
			var big := k % 3 == 0
			var tick_col := Color(0.78, 0.48, 0.16, 0.96) if k % 9 == 0 else Color(0.42, 0.45, 0.47, 0.78)
			draw_line(c + dd * (r - (3.0 if big else 1.0)), c + dd * (r + 4.0), tick_col, 2.2 if big else 1.0, true)
		draw_arc(c, r + 1.0, -0.95, -0.25, 14, Color(0.78, 0.48, 0.16, 0.94), 2.5, true)
		draw_arc(c, r + 1.0, 2.15, 2.85, 14, Color(0.78, 0.48, 0.16, 0.94), 2.5, true)
		var ff := PixelUI.pixel_font()
		var loc := get_node_or_null("/root/Loc")
		var is_e := loc != null and bool(loc.call("is_en"))
		var n_txt := "N" if is_e else "北"
		var s_txt := "S" if is_e else "南"
		var e_txt := "E" if is_e else "东"
		var w_txt := "W" if is_e else "西"
		draw_string(ff, c + Vector2(-4 if is_e else -6, -r + 14), n_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.86, 0.58, 0.24, 0.96))
		draw_string(ff, c + Vector2(-4 if is_e else -6, r - 5), s_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.72, 0.75, 0.74, 0.72))
		draw_string(ff, c + Vector2(r - (12 if is_e else 15), 4), e_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.72, 0.75, 0.74, 0.72))
		draw_string(ff, c + Vector2(-r + (5 if is_e else 4), 4), w_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.72, 0.75, 0.74, 0.72))


## 大地图（M 打开）：战术终端双栏布局（左侧可缩放/平移地形图 + 坐标网格 + 智能避让标注 + 右侧战术态势与图例面板）
class BigMap extends Control:
	var raid
	const AMBER := Color(0.78, 0.48, 0.16)
	const GOLD := Color(0.86, 0.59, 0.25)
	const CYAN := Color(0.58, 0.76, 0.82)
	const BOSS_C := Color(0.86, 0.32, 0.30)
	const NEST_C := Color(0.82, 0.36, 0.68)
	const LM_NAMES := {
		"broken_bridge": "灰港断桥", "radio_mast": "旧城广播塔", "elevated_road": "高架残段", "central_terminus": "中央穹顶总站",
		"gantry": "运河龙门吊", "blast_furnace": "一号钢厂高炉", "gas_holder": "煤气罐区", "converter_foundry": "二号转炉钢厂",
		"windmill": "风车阵", "pylon_row": "高压电塔列", "silo": "农场筒仓", "missile_silo": "洲际发射井阵地",
		"boardwalk": "赤湖观景栈桥", "observation_tower": "环湖观景塔", "spillway_dam": "赤湖溢洪闸枢",
		"submarine_drydock": "巨型潜艇干船坞",
		"cable_tower": "峡谷缆车塔", "ore_silos": "矿场筒仓", "rope_bridge": "悬崖索桥", "bucket_excavator": "斗轮挖掘机平台",
		"coolant_channel": "冷却渠", "crystal_cluster": "晶脉簇", "drill_derrick": "钻井残台", "geothermal_vault": "地热磁约束腔",
	}
	var map_zoom := 1.0
	var map_pan := Vector2.ZERO   ## 视野中心世界坐标 (x, z)
	var _dragging := false
	var _drag_moved := false
	var _drag_start := Vector2.ZERO
	var _pan_start := Vector2.ZERO
	var _hover_pos := Vector2(-9999, -9999)
	var _last_rect := Rect2()
	var _last_console := Rect2()
	var _btn_rects := {}          ## "zin" / "zout" / "zrst" / "close" -> Rect2

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		visible = false

	func _clamp_pan() -> void:
		if raid == null:
			return
		var H: float = raid.HALF
		var half_span: float = H / map_zoom
		var lim := maxf(0.0, H - half_span)
		map_pan.x = clampf(map_pan.x, -lim, lim)
		map_pan.y = clampf(map_pan.y, -lim, lim)

	func _zoom_at(new_z: float, screen_pt: Vector2) -> void:
		new_z = clampf(snappedf(new_z, 0.25), 1.0, 3.0)
		if is_equal_approx(new_z, map_zoom):
			return
		if _last_rect.size.x > 10.0 and _last_rect.has_point(screen_pt):
			var w_before := _m2w(screen_pt, _last_rect)
			map_zoom = new_z
			_clamp_pan()
			var w_after := _m2w(screen_pt, _last_rect)
			map_pan += Vector2(w_before.x - w_after.x, w_before.z - w_after.z)
		else:
			map_zoom = new_z
		_clamp_pan()
		queue_redraw()

	func _gui_input(ev: InputEvent) -> void:
		if not visible:
			return
		if ev is InputEventMouseMotion:
			var mm := ev as InputEventMouseMotion
			_hover_pos = mm.position
			if _dragging:
				if not _drag_moved and mm.position.distance_to(_drag_start) > 5.0:
					_drag_moved = true
				if _drag_moved and _last_rect.size.x > 10.0 and raid != null:
					var m_per_px: float = (raid.HALF * 2.0 / map_zoom) / _last_rect.size.x
					map_pan = _pan_start - (mm.position - _drag_start) * m_per_px
					_clamp_pan()
			queue_redraw()
			return
		if ev is InputEventScreenTouch and ev.pressed:
			if raid and raid.hud:
				raid.hud.toggle_map()
			accept_event()
			return
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at(map_zoom + 0.25, mb.position)
				accept_event()
				return
			if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at(map_zoom - 0.25, mb.position)
				accept_event()
				return
			if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
				if _last_rect.has_point(mb.position) and raid != null:
					var wp := _m2w(mb.position, _last_rect)
					if raid.has_meta("map_waypoint"):
						var cur_wp: Vector3 = raid.get_meta("map_waypoint")
						if _w2m(cur_wp, _last_rect).distance_to(mb.position) < 16.0:
							raid.remove_meta("map_waypoint")
							queue_redraw()
							accept_event()
							return
					raid.set_meta("map_waypoint", wp)
					queue_redraw()
				elif raid and raid.hud:
					raid.hud.toggle_map()
				accept_event()
				return
			if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
				if mb.pressed:
					for k: String in _btn_rects:
						if (_btn_rects[k] as Rect2).has_point(mb.position):
							match k:
								"zin": _zoom_at(map_zoom + 0.5, _last_rect.get_center())
								"zout": _zoom_at(map_zoom - 0.5, _last_rect.get_center())
								"zrst":
									map_zoom = 1.0
									map_pan = Vector2.ZERO
									queue_redraw()
								"wp_clr":
									if raid and raid.has_meta("map_waypoint"):
										raid.remove_meta("map_waypoint")
										queue_redraw()
								"close":
									if raid and raid.hud:
										raid.hud.toggle_map()
							accept_event()
							return
					_dragging = true
					_drag_moved = false
					_drag_start = mb.position
					_pan_start = map_pan
				else:
					var was_drag := _drag_moved
					_dragging = false
					_drag_moved = false
					if not was_drag and mb.button_index == MOUSE_BUTTON_LEFT:
						# 点击控制台外侧，或在 1x 视野下直接左键点击地图关闭（兼容快速开关习惯）
						if not _last_console.has_point(mb.position) or map_zoom <= 1.01:
							if raid and raid.hud:
								raid.hud.toggle_map()
				accept_event()

	func _process(_d: float) -> void:
		if visible:
			queue_redraw()

	func _w2m(p: Vector3, rect: Rect2) -> Vector2:
		var H: float = raid.HALF
		var span: float = (H * 2.0) / map_zoom
		var min_w := map_pan - Vector2(span * 0.5, span * 0.5)
		return rect.position + Vector2((p.x - min_w.x) / span, (p.z - min_w.y) / span) * rect.size

	func _m2w(s: Vector2, rect: Rect2) -> Vector3:
		var H: float = raid.HALF
		var span: float = (H * 2.0) / map_zoom
		var min_w := map_pan - Vector2(span * 0.5, span * 0.5)
		var uv := (s - rect.position) / rect.size
		return Vector3(clampf(min_w.x + uv.x * span, -H, H), 0.0, clampf(min_w.y + uv.y * span, -H, H))

	func _grid_code(p: Vector3) -> String:
		var H: float = raid.HALF
		var letters := "ABCDEFGHI"
		var cx := clampi(int((p.x + H) / (H * 2.0) * 9.0), 0, 8)
		var cy := clampi(int((p.z + H) / (H * 2.0) * 9.0), 0, 8)
		return "%s%d" % [letters[cx], cy + 1]

	func _draw_text_shadow(f: Font, pos: Vector2, txt: String, fs: int, col: Color, bg_pill := false) -> void:
		var sz := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		if bg_pill:
			var pr := Rect2(pos.x - 4, pos.y - fs + 1, sz.x + 8, fs + 4)
			draw_rect(pr, Color(0.03, 0.035, 0.045, 0.82))
			draw_rect(pr, Color(col.r, col.g, col.b, 0.35), false, 1.0)
		for o in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_string(f, pos + o, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.88))
		draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

	## 智能标签排布：尝试锚点四周候选方位并夹在地图框内，自动避开已绘制的重要图标与文字
	func _place_label(f: Font, anchor: Vector2, txt: String, fs: int, col: Color, rect: Rect2, placed: Array, pad_r := 11.0, centered := false, allow_skip := false, bg_pill := false) -> void:
		if not rect.grow(-2.0).has_point(anchor):
			return
		var sz := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var tw := sz.x
		var th := float(fs + 2)
		var inner := rect.grow(-6.0)
		var cands: Array = []
		if centered:
			cands = [
				Vector2(anchor.x - tw * 0.5, anchor.y - th * 0.5),
				Vector2(anchor.x - tw * 0.5, anchor.y - pad_r - th - 4.0),
				Vector2(anchor.x - tw * 0.5, anchor.y + pad_r + 6.0),
				Vector2(anchor.x + pad_r + 6.0, anchor.y - th * 0.5),
				Vector2(anchor.x - pad_r - tw - 6.0, anchor.y - th * 0.5),
				Vector2(anchor.x - tw * 0.5, anchor.y - pad_r - th - 20.0),
				Vector2(anchor.x - pad_r - tw - 14.0, anchor.y - pad_r - th - 10.0),
				Vector2(anchor.x + pad_r + 14.0, anchor.y - pad_r - th - 10.0),
			]
		else:
			# 靠近右边界时优先往左放，靠近左边界时优先往右放
			var prefer_left := anchor.x + pad_r + tw > inner.end.x
			if prefer_left:
				cands = [
					Vector2(anchor.x - pad_r - tw, anchor.y - th * 0.5),
					Vector2(anchor.x - tw * 0.5, anchor.y - pad_r - th),
					Vector2(anchor.x - tw * 0.5, anchor.y + pad_r + 2.0),
					Vector2(anchor.x + pad_r, anchor.y - th * 0.5),
					Vector2(anchor.x - pad_r - tw, anchor.y - pad_r - th),
					Vector2(anchor.x - pad_r - tw, anchor.y + pad_r + 2.0),
				]
			else:
				cands = [
					Vector2(anchor.x + pad_r, anchor.y - th * 0.5),
					Vector2(anchor.x - pad_r - tw, anchor.y - th * 0.5),
					Vector2(anchor.x - tw * 0.5, anchor.y - pad_r - th),
					Vector2(anchor.x - tw * 0.5, anchor.y + pad_r + 2.0),
					Vector2(anchor.x + pad_r, anchor.y - pad_r - th),
					Vector2(anchor.x + pad_r, anchor.y + pad_r + 2.0),
				]
		var best_box := Rect2()
		var best_pen := INF
		for c_tl: Vector2 in cands:
			var cx := clampf(c_tl.x, inner.position.x, maxf(inner.position.x, inner.end.x - tw))
			var cy := clampf(c_tl.y, inner.position.y, maxf(inner.position.y, inner.end.y - th))
			var box := Rect2(Vector2(cx, cy), Vector2(tw, th)).grow(2.0)
			var pen := 0.0
			for pr: Rect2 in placed:
				if box.intersects(pr):
					var inter := box.intersection(pr)
					pen += inter.size.x * inter.size.y + 200.0
			if pen < best_pen:
				best_pen = pen
				best_box = Rect2(Vector2(cx, cy), Vector2(tw, th))
				if pen == 0.0:
					break
		if allow_skip and best_pen > 120.0:
			return
		placed.append(best_box.grow(2.0))
		_draw_text_shadow(f, Vector2(best_box.position.x, best_box.position.y + fs - 2.0), txt, fs, col, bg_pill)

	func _draw_btn(f: Font, r: Rect2, label: String, active := false) -> void:
		var hov := r.has_point(_hover_pos)
		var btex := "btn9_main_n" if active else ("btn9_h" if hov else "btn9_n")
		draw_style_box(PixelTheme.px9(btex, 8, 8, 0, 0), r)
		var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var tc := Color(0.08, 0.06, 0.04) if active else (GOLD if hov else Color(0.90, 0.91, 0.89))
		draw_string(f, Vector2(r.get_center().x - tw * 0.5, r.position.y + r.size.y * 0.5 + 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tc)

	func _draw() -> void:
		if raid == null or raid.map_tex == null or raid.mech == null:
			return
		_clamp_pan()
		var f := PixelUI.pixel_font()
		# 全屏深炭灰遮罩
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.045, 0.050, 0.054, 0.92))
		var side_w := 252.0
		var gap := 20.0
		var map_side: float = minf(size.y - 132.0, size.x - side_w - gap - 108.0)
		map_side = maxf(320.0, map_side)
		var total_w := map_side + gap + side_w
		var start_x := floorf((size.x - total_w) * 0.5)
		var start_y := floorf((size.y - map_side) * 0.5 + 12.0)
		var rect := Rect2(Vector2(start_x, start_y), Vector2(map_side, map_side))
		var side_rect := Rect2(Vector2(rect.end.x + gap, rect.position.y - 6.0), Vector2(side_w, map_side + 12.0))
		var console_rect := Rect2(Vector2(rect.position.x - 38.0, rect.position.y - 58.0), Vector2(total_w + 56.0, map_side + 98.0))
		_last_rect = rect
		_last_console = console_rect

		# 战术终端总外框 + 铆钉顶栏 + 警戒斜纹
		draw_style_box(PixelTheme.px9("panel9", 16, 16, 0, 0), console_rect)
		var hdr_rect := Rect2(console_rect.position + Vector2(8, 8), Vector2(console_rect.size.x - 16.0, 32.0))
		draw_style_box(PixelTheme.px9("plate9", 14, 14, 0, 0), hdr_rect)
		load("res://scripts/ui.gd").draw_hazard(self, Rect2(console_rect.position + Vector2(8, 42), Vector2(console_rect.size.x - 16.0, 5.0)))
		# 地图视口凹槽外框
		draw_style_box(PixelTheme.px9("inset9", 6, 6, 0, 0), rect.grow(8))

		# 地形底图（按当前缩放与平移裁切 UV 区域绘制，严丝合缝不越界）
		var H: float = raid.HALF
		var span: float = (H * 2.0) / map_zoom
		var min_w := map_pan - Vector2(span * 0.5, span * 0.5)
		var tex_sz: Vector2 = raid.map_tex.get_size()
		var src_pos := Vector2((min_w.x + H) / (H * 2.0) * tex_sz.x, (min_w.y + H) / (H * 2.0) * tex_sz.y)
		var src_sz: Vector2 = tex_sz / map_zoom
		draw_texture_rect_region(raid.map_tex, rect, Rect2(src_pos, src_sz))

		# 9x9 战术网格（40m 格）+ 顶部/左侧动态坐标标尺
		var letters := "ABCDEFGHI"
		for i in 10:
			var wx := -H + i * (H * 2.0 / 9.0)
			var sx := _w2m(Vector3(wx, 0, 0), rect).x
			if sx >= rect.position.x - 0.5 and sx <= rect.end.x + 0.5:
				draw_line(Vector2(sx, rect.position.y), Vector2(sx, rect.end.y), Color(1, 1, 1, 0.07), 1.0)
			var wz := -H + i * (H * 2.0 / 9.0)
			var sy := _w2m(Vector3(0, 0, wz), rect).y
			if sy >= rect.position.y - 0.5 and sy <= rect.end.y + 0.5:
				draw_line(Vector2(rect.position.x, sy), Vector2(rect.end.x, sy), Color(1, 1, 1, 0.07), 1.0)
		for i in 9:
			var cx_w := -H + (i + 0.5) * (H * 2.0 / 9.0)
			var sx := _w2m(Vector3(cx_w, 0, 0), rect).x
			if sx >= rect.position.x + 10.0 and sx <= rect.end.x - 10.0:
				draw_string(f, Vector2(sx - 4, rect.position.y - 12), letters[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.86, 0.84, 0.76, 0.72))
			var cz_w := -H + (i + 0.5) * (H * 2.0 / 9.0)
			var sy := _w2m(Vector3(0, 0, cz_w), rect).y
			if sy >= rect.position.y + 10.0 and sy <= rect.end.y - 10.0:
				draw_string(f, Vector2(rect.position.x - 22, sy + 5), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.86, 0.84, 0.76, 0.72))

		var loc := get_node_or_null("/root/Loc")
		var is_e := loc != null and bool(loc.call("is_en"))

		# 已占用矩形表（用于标签防重叠）与悬停候选表
		var placed: Array = []
		var hover_items: Array = []   ## [{pos, r, title, sub, col}]
		var mp: Vector3 = raid.mech.global_position
		var c_mech := _w2m(mp, rect)
		if rect.has_point(c_mech):
			placed.append(Rect2(c_mech - Vector2(14, 14), Vector2(28, 28)))

		# 1. 虫巢（底图先画圆环，不遮挡高层文字）
		for n in raid.get_tree().get_nodes_in_group("nests"):
			var q := _w2m(n.global_position, rect)
			if not rect.grow(-4.0).has_point(q):
				continue
			draw_circle(q, 5.5, Color(NEST_C.r, NEST_C.g, NEST_C.b, 0.88))
			draw_arc(q, 8.5, 0, TAU, 20, Color(NEST_C.r, NEST_C.g, NEST_C.b, 0.48), 1.5, false)
			placed.append(Rect2(q - Vector2(8, 8), Vector2(16, 16)))
			hover_items.append({"pos": q, "r": 12.0, "title": "Swarm Hive" if is_e else "虫巢母体",
				"sub": ("%s · Dist %dm" if is_e else "%s · 距离 %dm") % [_grid_code(n.global_position), int(n.global_position.distance_to(mp))], "col": NEST_C})

		# 2. 战区首领（最高优先级威胁标注）
		var boss_nodes: Array = []
		for b in raid.get_tree().get_nodes_in_group("boss"):
			if is_instance_valid(b) and not b.dying:
				boss_nodes.append(b)
		for b in boss_nodes:
			var q := _w2m(b.global_position, rect)
			if not rect.grow(-2.0).has_point(q):
				continue
			var bpulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005)
			draw_arc(q, 11.0 + bpulse * 5.0, 0, TAU, 24, Color(BOSS_C.r, BOSS_C.g, BOSS_C.b, 0.58 * (1.0 - bpulse * 0.5)), 2.0, false)
			var dm := PackedVector2Array([q + Vector2(0, -10), q + Vector2(10, 0), q + Vector2(0, 10), q + Vector2(-10, 0)])
			draw_colored_polygon(dm, BOSS_C)
			dm.append(dm[0])
			draw_polyline(dm, Color(0, 0, 0, 0.9), 1.8)
			draw_circle(q, 3.2, Color(1.0, 0.92, 0.75))
			placed.append(Rect2(q - Vector2(12, 12), Vector2(24, 24)))
			var btitle := str(loc.call("t", str(b.title))) if loc else str(b.title)
			var blabel := ("Boss · " if is_e else "首领 · ") + btitle
			_place_label(f, q, blabel, 12, Color(1.0, 0.52, 0.58), rect, placed, 13.0, false, false, true)
			var hp_pct := int(roundf(float(b.hp_ratio()) * 100.0)) if b.has_method("hp_ratio") else 100
			hover_items.append({"pos": q, "r": 15.0, "title": blabel,
				"sub": ("%s · Hull %d%% · Dist %dm" if is_e else "%s · 结构 %d%% · 距离 %dm") % [_grid_code(b.global_position), hp_pct, int(b.global_position.distance_to(mp))], "col": BOSS_C})

		# 3. 撤离点 / 运输机
		var zs: Array = raid.extracts.duplicate()
		if raid.transport_zone and raid.transport_zone.active:
			zs.append(raid.transport_zone)
		for z in zs:
			var q := _w2m(z.global_position, rect)
			if not rect.grow(-2.0).has_point(q):
				continue
			var col: Color = z.color
			var dm := PackedVector2Array([q + Vector2(0, -9), q + Vector2(9, 0), q + Vector2(0, 9), q + Vector2(-9, 0)])
			draw_colored_polygon(dm, col)
			dm.append(dm[0])
			draw_polyline(dm, Color(0, 0, 0, 0.85), 1.6)
			draw_circle(q, 2.2, Color(0.95, 1.0, 0.95))
			placed.append(Rect2(q - Vector2(11, 11), Vector2(22, 22)))
			var label: String = str(loc.call("map_label", str(z.title))) if loc else str(z.title)
			_place_label(f, q, label, 12, col.lightened(0.18), rect, placed, 12.0, false, false, true)
			hover_items.append({"pos": q, "r": 14.0, "title": label,
				"sub": ("%s · Extract · Dist %dm" if is_e else "%s · 撤离点 · 距离 %dm") % [_grid_code(z.global_position), int(z.global_position.distance_to(mp))], "col": col})

		# 4. 战区转场口（边界连通口）
		if raid.world_link != null and raid.world_link.has_method("gate_list"):
			for g: Dictionary in raid.world_link.gate_list():
				var gp: Vector3 = g.center
				var q := _w2m(gp, rect)
				if not rect.grow(2.0).has_point(q):
					continue
				q = q.clamp(rect.position + Vector2(8, 8), rect.end - Vector2(8, 8))
				var open := bool(g.open)
				var gcol := CYAN if open else Color(0.62, 0.65, 0.70)
				draw_rect(Rect2(q - Vector2(6, 6), Vector2(12, 12)), Color(0.05, 0.07, 0.09, 0.92))
				draw_rect(Rect2(q - Vector2(6, 6), Vector2(12, 12)), gcol, false, 1.8)
				draw_circle(q, 2.5, gcol)
				placed.append(Rect2(q - Vector2(9, 9), Vector2(18, 18)))
				var gname := str(loc.call("map_label", str(g.name))) if loc else str(g.name)
				var glbl := (("▸ To %s" if is_e else "▸ 通往 %s") % gname) if open else ("🔒 %s" % gname)
				_place_label(f, q, glbl, 12, gcol, rect, placed, 10.0, true, false, true)
				hover_items.append({"pos": q, "r": 14.0, "title": ("Transit · " if is_e else "转场口 · ") + gname,
					"sub": (("%s · Open · Dist %dm" if is_e else "%s · 可通行 · 距离 %dm") if open else ("%s · Locked · Dist %dm" if is_e else "%s · 尚未解锁 · 距离 %dm")) % [_grid_code(gp), int(gp.distance_to(mp))], "col": gcol})

		# 5. 重点遗迹 POI（琥珀双层菱形 + 金色名称，包含核心三处与扩展遗迹）
		var poi_landmark_names := {"虫巢": true, "Swarm Hive": true, "Hive": true}
		for i in raid.poi_centers.size():
			var pc: Vector3 = raid.poi_centers[i]
			var pid := str(raid.poi_ids[i]) if i < raid.poi_ids.size() else ""
			var pinfo: Dictionary = GameData.POIS.get(pid, {})
			var pname := str(pinfo.get("name", pid))
			poi_landmark_names[pname] = true
			var q := _w2m(pc, rect)
			if not rect.grow(-4.0).has_point(q):
				continue
			var dm := PackedVector2Array([q + Vector2(0, -7.5), q + Vector2(7.5, 0), q + Vector2(0, 7.5), q + Vector2(-7.5, 0)])
			draw_colored_polygon(dm, Color(0.12, 0.09, 0.04, 0.92))
			var dm_in := PackedVector2Array([q + Vector2(0, -5.5), q + Vector2(5.5, 0), q + Vector2(0, 5.5), q + Vector2(-5.5, 0)])
			draw_colored_polygon(dm_in, GOLD)
			draw_circle(q, 1.8, Color(0.12, 0.09, 0.04))
			placed.append(Rect2(q - Vector2(9, 9), Vector2(18, 18)))
			_place_label(f, q, pname, 12, Color(0.89, 0.64, 0.30), rect, placed, 10.0, false, false, false)
			hover_items.append({"pos": q, "r": 13.0, "title": ("Key Ruin · " if is_e else "重点遗迹 · ") + pname,
				"sub": ("%s · High-Value Loot · Dist %dm" if is_e else "%s · 高价值物资区 · 距离 %dm") % [_grid_code(pc), int(pc.distance_to(mp))], "col": GOLD})

		# 6. 地标建筑（米白方框准星 + 名称）
		for lm: Dictionary in raid.get_meta("ext_landmarks", []):
			var ltype := str(lm.get("type", ""))
			var lname: String = str(loc.call("landmark_name", ltype, LM_NAMES.get(ltype, ltype))) if loc else str(LM_NAMES.get(ltype, ltype))
			poi_landmark_names[lname] = true
			var lp := Vector3(float(lm.get("x", 0.0)), 0.0, float(lm.get("z", 0.0)))
			var q := _w2m(lp, rect)
			if not rect.grow(-4.0).has_point(q):
				continue
			draw_rect(Rect2(q - Vector2(4.5, 4.5), Vector2(9, 9)), Color(0.06, 0.06, 0.07, 0.9))
			draw_rect(Rect2(q - Vector2(3.5, 3.5), Vector2(7, 7)), Color(0.88, 0.85, 0.76), false, 1.5)
			draw_circle(q, 1.5, Color(0.88, 0.85, 0.76))
			placed.append(Rect2(q - Vector2(7, 7), Vector2(14, 14)))
			_place_label(f, q, lname, 12, Color(0.88, 0.85, 0.76, 0.92), rect, placed, 8.0, false, false, false)
			hover_items.append({"pos": q, "r": 11.0, "title": ("Landmark · " if is_e else "地标 · ") + lname,
				"sub": ("%s · Dist %dm" if is_e else "%s · 距离 %dm") % [_grid_code(lp), int(lp.distance_to(mp))], "col": Color(0.88, 0.85, 0.76)})

		# 7. 街区与地貌背景名（去重已作为 POI/地标绘制的同名项，并自动避让高层图标与文字）
		for l: Array in raid.map_labels:
			var nm: String = str(loc.call("map_label", str(l[0]))) if loc else str(l[0])
			if poi_landmark_names.has(nm):
				continue
			var q := _w2m(Vector3(float(l[1]), 0, float(l[2])), rect)
			if not rect.grow(-8.0).has_point(q):
				continue
			_place_label(f, q, nm, 12, Color(0.84, 0.81, 0.73, 0.74), rect, placed, 4.0, true, true, false)

		# 7.5 玩家出击前自定义标记（同步显示备注文字与测距）
		var gd_bm := get_node_or_null("/root/GameData")
		if gd_bm != null and gd_bm.has_method("markers_for_map"):
			for mk: Dictionary in gd_bm.call("markers_for_map", str(raid.map_id)):
				var mkp := Vector3(float(mk.get("lx", 0.0)), 0.0, float(mk.get("lz", 0.0)))
				var q := _w2m(mkp, rect)
				if not rect.grow(-2.0).has_point(q):
					continue
				var mcol: Color = gd_bm.call("marker_color", str(mk.get("color", "amber")))
				var mtxt := str(mk.get("text", ""))
				var head := q + Vector2(0, -6.5)
				draw_colored_polygon(PackedVector2Array([q + Vector2(0, 1.5), head + Vector2(-5.2, 2.0), head + Vector2(5.2, 2.0)]), Color(0.05, 0.06, 0.07, 0.92))
				draw_circle(head, 6.0, Color(0.05, 0.06, 0.07, 0.92))
				draw_colored_polygon(PackedVector2Array([q, head + Vector2(-4.0, 1.5), head + Vector2(4.0, 1.5)]), mcol)
				draw_circle(head, 4.6, mcol)
				draw_circle(head, 1.8, Color(0.08, 0.09, 0.10))
				placed.append(Rect2(q - Vector2(8, 12), Vector2(16, 15)))
				if not mtxt.is_empty():
					_place_label(f, q, mtxt, 12, mcol.lightened(0.12), rect, placed, 11.0, false, false, true)
				hover_items.append({"pos": q, "r": 13.0, "title": ("Custom Pin · " if is_e else "自定标记 · ") + mtxt,
					"sub": ("%s · Pre-Raid Note · Dist %dm" if is_e else "%s · 战前备注 · 距离 %dm") % [_grid_code(mkp), int(mkp.distance_to(mp))], "col": mcol})

		# 8. 战术标点（右键标点 + 玩家牵引虚线）
		if raid.has_meta("map_waypoint"):
			var wp: Vector3 = raid.get_meta("map_waypoint")
			var q := _w2m(wp, rect)
			if rect.has_point(q) and rect.has_point(c_mech):
				var d_vec := q - c_mech
				var steps := mini(60, maxi(4, int(d_vec.length() / 8.0)))
				for s_i in steps:
					if s_i % 2 == 0:
						draw_line(c_mech + d_vec * (float(s_i) / steps), c_mech + d_vec * (float(s_i + 1) / steps), Color(CYAN.r, CYAN.g, CYAN.b, 0.55), 1.5)
			if rect.grow(-2.0).has_point(q):
				var wp_pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.007)
				draw_arc(q, 8.0 + wp_pulse * 4.0, 0, TAU, 20, Color(CYAN.r, CYAN.g, CYAN.b, 0.7 * (1.0 - wp_pulse * 0.5)), 1.8, false)
				draw_line(q - Vector2(9, 0), q + Vector2(9, 0), CYAN, 1.5)
				draw_line(q - Vector2(0, 9), q + Vector2(0, 9), CYAN, 1.5)
				draw_circle(q, 2.5, Color(1, 1, 1))
				var wp_lbl := ("Waypoint · %dm" if is_e else "战术标点 · %dm") % int(wp.distance_to(mp))
				_place_label(f, q, wp_lbl, 12, CYAN, rect, placed, 11.0, false, false, true)

		# 9. 随行队友与我方机甲
		if raid.factions != null and "allies" in raid.factions:
			for al in raid.factions.allies:
				if al == null or not is_instance_valid(al) or al.dead:
					continue
				var aq := _w2m(al.global_position, rect)
				if rect.grow(-2.0).has_point(aq):
					draw_circle(aq, 5.5, Color(0, 0, 0, 0.8))
					draw_circle(aq, 4.0, CYAN)
					var aname := str(al.pilot_name) if "pilot_name" in al else ("Ally" if is_e else "友军")
					_place_label(f, aq, aname, 12, CYAN, rect, placed, 8.0, false, false, false)

		if rect.grow(-2.0).has_point(c_mech):
			var fwd: Vector3 = -raid.mech.torso.global_transform.basis.z
			var fv := Vector2(fwd.x, fwd.z).normalized()
			var sd := Vector2(-fv.y, fv.x)
			var base_ang := atan2(fv.y, fv.x)
			var cone := PackedVector2Array([c_mech])
			for i in 11:
				var a := base_ang - 0.40 + 0.80 * (float(i) / 10.0)
				cone.append(c_mech + Vector2(cos(a), sin(a)) * 34.0)
			draw_colored_polygon(cone, Color(AMBER.r, AMBER.g, AMBER.b, 0.18))
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
			draw_arc(c_mech, 10.0 + pulse * 6.0, 0, TAU, 24, Color(AMBER.r, AMBER.g, AMBER.b, 0.65 * (1.0 - pulse)), 2.0, false)
			draw_colored_polygon(PackedVector2Array([c_mech + fv * 11, c_mech - fv * 6 + sd * 7, c_mech - fv * 2, c_mech - fv * 6 - sd * 7]), Color(0, 0, 0, 0.82))
			draw_colored_polygon(PackedVector2Array([c_mech + fv * 9, c_mech - fv * 5 + sd * 6, c_mech - fv * 2, c_mech - fv * 5 - sd * 6]), AMBER)

		# 顶栏：战区名称 + 当前网格/位置 + 缩放控制条（放在铆钉顶栏之内，严格按 12px 像素字号）
		var cur_grid := _grid_code(mp)
		var cur_dist: String = str(loc.call("map_label", raid.district_at(mp))) if loc else raid.district_at(mp)
		var map_title := str(loc.call("map_label", str(raid.MAP.name))) if loc else str(raid.MAP.name)
		draw_rect(Rect2(console_rect.position.x + 18.0, console_rect.position.y + 17.0, 4.0, 14.0), AMBER)
		draw_string(f, Vector2(console_rect.position.x + 28.0, console_rect.position.y + 29.0), ("Sector Map · " if is_e else "战区战术图 · ") + map_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.97, 0.95, 0.88))
		draw_string(f, Vector2(console_rect.position.x + 220.0, console_rect.position.y + 29.0), ("Grid [%s] · %s" if is_e else "坐标 [%s] · %s") % [cur_grid, cur_dist], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)

		_btn_rects.clear()
		var bx := console_rect.end.x - 150.0
		var by := console_rect.position.y + 13.0
		_btn_rects["zout"] = Rect2(bx, by, 28, 22)
		_btn_rects["zin"] = Rect2(bx + 32, by, 28, 22)
		_btn_rects["zrst"] = Rect2(bx + 64, by, 36, 22)
		_btn_rects["close"] = Rect2(bx + 104, by, 30, 22)
		_draw_btn(f, _btn_rects["zout"], "−")
		_draw_btn(f, _btn_rects["zin"], "＋")
		_draw_btn(f, _btn_rects["zrst"], "%.1fx" % map_zoom, map_zoom > 1.01)
		_draw_btn(f, _btn_rects["close"], "×")

		# 底栏：操作提示 + 动态比例尺
		var px_per_m := (rect.size.x * map_zoom) / (H * 2.0)
		var scale_m := 50.0 if map_zoom < 1.8 else 25.0
		var sb_len := scale_m * px_per_m
		var sb := Vector2(rect.end.x - sb_len - 4.0, rect.end.y + 18)
		draw_line(sb, sb + Vector2(sb_len, 0), Color(0.9, 0.88, 0.82, 0.8), 2.0)
		draw_line(sb - Vector2(0, 4), sb + Vector2(0, 4), Color(0.9, 0.88, 0.82, 0.8), 1.5)
		draw_line(sb + Vector2(sb_len, -4), sb + Vector2(sb_len, 4), Color(0.9, 0.88, 0.82, 0.8), 1.5)
		draw_string(f, sb + Vector2(sb_len * 0.5 - 14, 15), "%dm" % int(scale_m), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.86, 0.84, 0.78, 0.75))
		draw_string(f, Vector2(rect.position.x, rect.end.y + 24),
			"Wheel: Zoom · Drag: Pan · Right-Click: Waypoint · Click Blank / M / Esc: Close" if is_e else "滚轮：缩放 · 拖拽：平移 · 右键：战术标点 · 点击空白 / M / Esc：关闭",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.75, 0.72, 0.72))

		# 右侧战术态势与图例面板（inset9 凹槽底板 + 12px 整数像素字体）
		draw_style_box(PixelTheme.px9("inset9", 6, 6, 0, 0), side_rect)
		var sx := side_rect.position.x + 14.0
		var sy := side_rect.position.y + 22.0
		draw_rect(Rect2(sx, sy - 10, 3, 12), AMBER)
		draw_string(f, Vector2(sx + 8, sy), "TELEMETRY" if is_e else "战场态势", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
		sy += 20.0
		var sc: Vector2i = raid.searched_count() if raid.has_method("searched_count") else Vector2i.ZERO
		var mins := int(raid.time) / 60
		var secs := int(raid.time) % 60
		draw_string(f, Vector2(sx, sy), ("Time: %02d:%02d   Kills: %d" if is_e else "行动用时：%02d:%02d   击杀：%d") % [mins, secs, int(raid.kills)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.88, 0.88, 0.85))
		sy += 17.0
		draw_string(f, Vector2(sx, sy), ("Looted: %d / %d crates" if is_e else "物资搜刮：%d / %d 处容器") % [sc.x, sc.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.88, 0.88, 0.85))
		sy += 14.0
		draw_line(Vector2(sx, sy), Vector2(side_rect.end.x - 14, sy), Color(1, 1, 1, 0.1), 1.0)
		sy += 18.0

		# 首领与撤离情报
		draw_rect(Rect2(sx, sy - 10, 3, 12), BOSS_C)
		draw_string(f, Vector2(sx + 8, sy), "OBJECTIVES & EVAC" if is_e else "首领与撤离点", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.92, 0.86))
		sy += 20.0
		if boss_nodes.is_empty():
			draw_string(f, Vector2(sx, sy), "✦ Sector Bosses: Cleared" if is_e else "✦ 区域首领：已肃清", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.58, 0.62, 0.58))
			sy += 17.0
		else:
			for b in boss_nodes:
				var b_grid := _grid_code(b.global_position)
				var b_dist := int(b.global_position.distance_to(mp))
				var bt := str(loc.call("t", str(b.title))) if loc else str(b.title)
				draw_string(f, Vector2(sx, sy), "✦ %s [%s] · %dm" % [bt, b_grid, b_dist], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.48, 0.54))
				sy += 17.0
		for z in zs:
			var z_grid := _grid_code(z.global_position)
			var z_dist := int(z.global_position.distance_to(mp))
			var zt := str(loc.call("map_label", str(z.title))) if loc else str(z.title)
			draw_string(f, Vector2(sx, sy), "◆ %s [%s] · %dm" % [zt.split("·")[-1].strip_edges(), z_grid, z_dist], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, z.color.lightened(0.15))
			sy += 17.0
		sy += 6.0
		draw_line(Vector2(sx, sy), Vector2(side_rect.end.x - 14, sy), Color(1, 1, 1, 0.1), 1.0)
		sy += 18.0

		# 悬停情报 / 鼠标坐标测距
		draw_rect(Rect2(sx, sy - 10, 3, 12), CYAN)
		draw_string(f, Vector2(sx + 8, sy), "CURSOR" if is_e else "光标侦察", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CYAN)
		sy += 20.0
		var hov_hit := {}
		var best_hd := 999.0
		for hi: Dictionary in hover_items:
			var hd := (hi.pos as Vector2).distance_to(_hover_pos)
			if hd <= float(hi.r) and hd < best_hd:
				best_hd = hd
				hov_hit = hi
		if not hov_hit.is_empty():
			draw_string(f, Vector2(sx, sy), str(hov_hit.title), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, hov_hit.col)
			sy += 17.0
			draw_string(f, Vector2(sx, sy), str(hov_hit.sub), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.78, 0.80, 0.82))
			sy += 18.0
		elif rect.has_point(_hover_pos):
			var mw := _m2w(_hover_pos, rect)
			var hdist: String = str(loc.call("map_label", str(raid.district_at(mw)))) if loc else str(raid.district_at(mw))
			draw_string(f, Vector2(sx, sy), ("Grid [%s] · %s" if is_e else "坐标 [%s] · %s") % [_grid_code(mw), hdist], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.88, 0.82))
			sy += 17.0
			draw_string(f, Vector2(sx, sy), ("From Mech %dm" if is_e else "距机甲 %dm") % int(mw.distance_to(mp)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.68, 0.70, 0.72))
			sy += 18.0
		else:
			draw_string(f, Vector2(sx, sy), "Hover map markers for details" if is_e else "移至地图要素查看详情", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.57, 0.60))
			sy += 35.0
		if raid.has_meta("map_waypoint"):
			var wp: Vector3 = raid.get_meta("map_waypoint")
			var clr_r := Rect2(sx, sy - 12, side_w - 28, 22)
			_btn_rects["wp_clr"] = clr_r
			_draw_btn(f, clr_r, ("Clear WP [%s · %dm]" if is_e else "清除标点 [%s · %dm]") % [_grid_code(wp), int(wp.distance_to(mp))])
			sy += 26.0
		draw_line(Vector2(sx, sy), Vector2(side_rect.end.x - 14, sy), Color(1, 1, 1, 0.1), 1.0)
		sy += 18.0

		# 图例说明
		draw_rect(Rect2(sx, sy - 10, 3, 12), GOLD)
		draw_string(f, Vector2(sx + 8, sy), "LEGEND" if is_e else "战术图例", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
		sy += 20.0
		var legends := [
			[AMBER, "▲  Allied Mech & FOV" if is_e else "▲  我方机甲与视界扇区"],
			[BOSS_C, "✦  Sector Boss (High Threat)" if is_e else "✦  区域首领（高危目标）"],
			[ Color(0.45, 0.92, 0.55), "◆  Extract / Evac Zone" if is_e else "◆  撤离点 / 运输机着陆区"],
			[GOLD, "❖  Key Ruin (High-Value)" if is_e else "❖  重点遗迹（高价值物资）"],
			[CYAN, "▸  Sector Transit Gate" if is_e else "▸  相邻战区转场口"],
			[Color(0.88, 0.85, 0.76), "▪  Landmark & Terrain" if is_e else "▪  地标建筑与地形参照"],
			[Color("f0b95a"), "▼  Custom Pre-Raid Pin" if is_e else "▼  玩家战前自定义标记"],
			[NEST_C, "●  Swarm Hive Core" if is_e else "●  异化虫巢母体"],
		]
		for lg: Array in legends:
			if sy + 12.0 > side_rect.end.y - 6.0:
				break
			draw_string(f, Vector2(sx, sy), str(lg[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, lg[0])
			sy += 17.5



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
	var hit_t := 0.0
	var _aim_vis := 0.0
	var _lock_px := Vector2.ZERO
	var _lock_hp := -1.0
	var _lock_show := false
	var _init_done := false
	const AMBER := Color(0.78, 0.48, 0.16)
	const HIT_COL := Color(1.0, 0.46, 0.16)
	const STEEL := Color(0.84, 0.86, 0.86, 0.95)
	const SHADOW := Color(0, 0, 0, 0.58)

	func trigger_hit() -> void:
		hit_t = 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(d: float) -> void:
		var vp_sz := get_viewport_rect().size
		var m := get_viewport().get_mouse_position().clamp(Vector2.ZERO, vp_sz)
		var fp_on := false
		if mech and is_instance_valid(mech):
			fp_on = mech.raid != null and ((mech.raid.has_method("is_free_look_view") and mech.raid.is_free_look_view()) or (mech.raid.has_method("is_first_person") and mech.raid.is_first_person()))
			var cam0 := get_viewport().get_camera_3d()
			if fp_on:
				if cam0 and mech.raid.aim_override != null and not cam0.is_position_behind(mech.aim_point):
					m = cam0.unproject_position(mech.aim_point).clamp(Vector2.ZERO, vp_sz)
				else:
					m = vp_sz * 0.5
			else:
				var joy_on: bool = (mech.raid != null and (bool(mech.raid.get("_joy_aim_active")) or mech.raid.aim_override != null)) or (mech.raid != null and mech.raid.hud != null and mech.raid.hud.is_touch_busy())
				if cam0 and joy_on:
					var ap := Vector3(mech.aim_point.x, mech.aim_point.y, mech.aim_point.z)
					if not cam0.is_position_behind(ap):
						m = cam0.unproject_position(ap).clamp(Vector2.ZERO, vp_sz)
		if not _init_done:
			pos = m
			pip = m
			_init_done = true
		# 外圈准星零延迟紧跟鼠标指针（消除俯视射击拖泥带水感），内圈弹着点 pip 独立展示躯干转向惯性
		pos = m
		spin += d * 0.6
		if hit_t > 0.0:
			hit_t = maxf(0.0, hit_t - d * 4.5)
		if mech and is_instance_valid(mech):
			var want_aim := 0.0
			if mech.raid != null and mech.raid.has_method("is_over_shoulder") and mech.raid.is_over_shoulder() and "_ots_aim_blend" in mech.raid:
				want_aim = clampf(float(mech.raid.get("_ots_aim_blend")), 0.0, 1.0)
			else:
				want_aim = 1.0 if bool(mech.get("is_aiming")) else 0.0
			_aim_vis = lerpf(_aim_vis, want_aim, clampf(1.0 - exp(-14.0 * d), 0.0, 1.0))
			var r := 0.0
			for k in mech.recoil:
				r = maxf(r, mech.recoil[k])
			bloom = maxf(bloom - d * 3.0, r)
			var cam := get_viewport().get_camera_3d()
			_lock_show = false
			if cam and mech.torso:
				var w: Vector3
				if mech.has_method("fire_control_world_point"):
					w = mech.fire_control_world_point()
				elif fp_on:
					var sc_m: float = float(mech.MECH_VIS_SCALE) if "MECH_VIS_SCALE" in mech else 1.8
					var origin3: Vector3 = mech.torso.global_position + Vector3(0.0, 0.28 * sc_m, 0.0)
					var dist3 := clampf(mech.aim_point.distance_to(origin3), 4.0, 140.0)
					w = origin3 + mech.aim_dir() * dist3
				else:
					var o: Vector3 = mech.global_position
					var dist := clampf(Vector2(mech.aim_point.x - o.x, mech.aim_point.z - o.z).length(), 0.0, 80.0)
					w = o + mech.aim_dir() * dist
					w.y = mech.aim_point.y
				if not cam.is_position_behind(w):
					var up := cam.unproject_position(w).clamp(Vector2(-160, -160), vp_sz + Vector2(160, 160))
					pip = pip.lerp(up, 1.0 - exp(-30.0 * d))
				# 越肩/第一人称实况敌方锁定菱框与血条投影
				var le = mech.get("aim_locked_enemy")
				if fp_on and le != null and is_instance_valid(le) and (le is Node3D) and le.get("dying") != true and le.get("dead") != true:
					var l3 := le as Node3D
					var lpos: Vector3 = mech.raid._target_visual_center(l3) if (mech.raid != null and mech.raid.has_method("_target_visual_center")) else (l3.global_position + Vector3(0.0, 1.5, 0.0))
					if not cam.is_position_behind(lpos):
						_lock_px = cam.unproject_position(lpos)
						var hp_v = l3.get("hp")
						var mhp_v = l3.get("max_hp")
						_lock_hp = clampf(float(hp_v) / maxf(1.0, float(mhp_v)), 0.0, 1.0) if (hp_v != null and mhp_v != null) else -1.0
						_lock_show = true
		else:
			_aim_vis = 0.0
			_lock_show = false
		queue_redraw()

	func _seg(a: Vector2, b: Vector2, c: Color, w: float) -> void:
		draw_line(a, b, SHADOW, w + 2.0, false)
		draw_line(a, b, c, w, false)

	func _draw() -> void:
		var p := pos
		var vp_sz := get_viewport_rect().size
		var locked: bool = mech != null and is_instance_valid(mech) and bool(mech.get("aim_target_locked"))
		var white := Color(1.0, 0.56, 0.18, 0.96) if locked else STEEL
		var gap := lerpf(15.5, 8.2, _aim_vis) + bloom * lerpf(9.0, 4.2, _aim_vis)
		var arm := lerpf(7.0, 5.5, _aim_vis)
		# 右键火控光学外框（极简军工四角镜框 + 水平/垂直密位标尺，不遮挡外围视野但瞄准状态一目了然）
		if _aim_vis > 0.04:
			var a_fcs := _aim_vis * 0.58
			var f_col := Color(1.0, 0.64, 0.24, a_fcs) if locked else Color(0.84, 0.90, 0.92, a_fcs)
			var f_sh := Color(0.0, 0.0, 0.0, a_fcs * 0.65)
			# 密位测距十字延展线
			for sgn: float in [-1.0, 1.0]:
				var h0 := p + Vector2(sgn * (gap + 14.0), 0.0)
				var h1 := p + Vector2(sgn * (gap + 44.0), 0.0)
				draw_line(h0, h1, f_sh, 3.0, false)
				draw_line(h0, h1, f_col, 1.2, false)
				for tk: float in [22.0, 32.0, 42.0]:
					var tx: float = p.x + sgn * (gap + tk)
					draw_line(Vector2(tx, p.y - 3.0), Vector2(tx, p.y + 3.0), f_col, 1.0, false)
				var v0 := p + Vector2(0.0, sgn * (gap + 14.0))
				var v1 := p + Vector2(0.0, sgn * (gap + 32.0))
				draw_line(v0, v1, f_sh, 3.0, false)
				draw_line(v0, v1, f_col, 1.2, false)
			# 视野中心 62% 区域的四角火控光学框
			var hw := minf(vp_sz.x * 0.30, 340.0) * lerpf(1.12, 1.0, _aim_vis)
			var hh := minf(vp_sz.y * 0.29, 200.0) * lerpf(1.12, 1.0, _aim_vis)
			var clen := 22.0
			for sx: float in [-1.0, 1.0]:
				for sy: float in [-1.0, 1.0]:
					var c_pt := p + Vector2(sx * hw, sy * hh)
					draw_line(c_pt, c_pt + Vector2(-sx * clen, 0.0), f_sh, 3.4, false)
					draw_line(c_pt, c_pt + Vector2(0.0, -sy * clen), f_sh, 3.4, false)
					draw_line(c_pt, c_pt + Vector2(-sx * clen, 0.0), f_col, 1.4, false)
					draw_line(c_pt, c_pt + Vector2(0.0, -sy * clen), f_col, 1.4, false)
		# 实况敌方锁定菱框与紧凑血条（越肩/第一人称锁敌即时视觉反馈）
		if _lock_show:
			var lp := _lock_px
			var lr := lerpf(16.0, 12.5, _aim_vis)
			var lcol := Color(1.0, 0.56, 0.16, lerpf(0.76, 0.96, _aim_vis))
			var pts := PackedVector2Array([
				lp + Vector2(0.0, -lr), lp + Vector2(lr, 0.0),
				lp + Vector2(0.0, lr), lp + Vector2(-lr, 0.0), lp + Vector2(0.0, -lr)
			])
			for pi in 4:
				draw_line(pts[pi], pts[pi + 1], Color(0.0, 0.0, 0.0, 0.55), 3.2, false)
				draw_line(pts[pi], pts[pi + 1], lcol, 1.5, false)
			if _lock_hp >= 0.0:
				var bw := 32.0
				var bh := 3.5
				var bx := lp.x - bw * 0.5
				var by := lp.y - lr - 9.0
				draw_rect(Rect2(bx - 1.0, by - 1.0, bw + 2.0, bh + 2.0), Color(0.0, 0.0, 0.0, 0.65), true)
				draw_rect(Rect2(bx, by, bw * _lock_hp, bh), Color(1.0, 0.38, 0.18, 0.92), true)
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
		if _aim_vis > 0.25:
			draw_circle(p, 1.8, white)
		# 命中提示：自然收缩的四角斜向角标
		if hit_t > 0.0:
			var h_ease := pow(hit_t, 1.85)
			var h_alpha := clampf(hit_t * 1.65, 0.0, 1.0)
			var h_col := Color(HIT_COL.r, HIT_COL.g, HIT_COL.b, h_alpha)
			var h_shd := Color(0, 0, 0, 0.62 * h_alpha)
			var r_in := 6.5 + 13.5 * h_ease
			var r_out := r_in + 6.5 + 2.5 * h_ease
			for k in 4:
				var ang := PI * 0.25 + k * PI * 0.5
				var dir := Vector2(cos(ang), sin(ang))
				var a := p + dir * r_in
				var b := p + dir * r_out
				draw_line(a, b, h_shd, 4.2, false)
				draw_line(a, b, h_col, 2.2, false)
		# 慢速旋转的刻度弧
		var R := gap + 12.0
		for k in 3:
			var a0 := spin + k * TAU / 3.0
			draw_arc(p, R, a0, a0 + 0.7, 10, Color(0.84, 0.86, 0.86, 0.24), 1.5, false)
			var tip := p + Vector2(cos(a0), sin(a0)) * R
			draw_line(tip, tip + Vector2(cos(a0), sin(a0)) * 4.0, Color(0.84, 0.86, 0.86, 0.40), 1.5, false)
		# 弹着点（躯干真实朝向）+ 牵引线
		var off := pip - p
		var aligned := off.length() < 6.0
		if not aligned:
			var n := mini(int(off.length() / 7.0), 48)
			for i in n:
				if i % 2 == 0:
					draw_line(p + off * (float(i) / n), p + off * (float(i + 1) / n), Color(AMBER.r, AMBER.g, AMBER.b, 0.62), 1.5, false)
		var pc := Color(0.87, 0.59, 0.25) if not aligned else Color(0.76, 0.58, 0.30)
		draw_arc(pip, 5.5, 0, TAU, 20, SHADOW, 4.0, false)
		draw_arc(pip, 5.5, 0, TAU, 20, pc, 2.0, false)
		if aligned:
			draw_circle(pip, 2.0, pc)
		if mech == null or not is_instance_valid(mech):
			return
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
			draw_arc(p, rr, a0, a0 + PI * 0.56, 14, Color(0, 0, 0, 0.35), 4.0, false)
			draw_arc(p, rr, a0, a0 + PI * 0.56 * (1.0 - fr), 14, Color(AMBER.r, AMBER.g, AMBER.b, 0.9), 2.0, false)
			i += 1
		# 越肩模式极简激光测距、火控倍率与肩位微标（B.o.T 风格军工火控准星信息）
		if mech.raid != null and mech.raid.has_method("is_over_shoulder") and mech.raid.is_over_shoulder():
			var fnt := ThemeDB.fallback_font
			if fnt != null:
				var d_m: float = float(mech.raid.get("_ots_aim_dist")) if "_ots_aim_dist" in mech.raid else 0.0
				var sh_s := "R" if float(mech.raid.get("ots_shoulder_side")) > 0.0 else "L"
				var dist_s := ("%03dm" % int(roundf(d_m))) if d_m > 0.5 else "---m"
				var pfx := ""
				if locked:
					pfx = "LOCK 2.1x  " if _aim_vis > 0.35 else "LOCK  "
				elif _aim_vis > 0.35:
					pfx = "FCS 3.3x  " if (mech.has_method("is_scoping") and mech.is_scoping()) else "FCS 2.1x  "
				var txt := "%s%s  %s" % [pfx, dist_s, sh_s]
				var tcol := Color(1.0, 0.62, 0.22, 0.96) if locked else (Color(0.92, 0.96, 0.96, 0.90) if _aim_vis > 0.35 else Color(0.84, 0.87, 0.88, 0.72))
				var fsz := 11
				var tw := fnt.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
				var tp := Vector2(p.x - tw * 0.5, p.y + gap + (38.0 if _aim_vis > 0.35 else 22.0))
				draw_string(fnt, tp + Vector2(1.0, 1.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color(0, 0, 0, 0.68))
				draw_string(fnt, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, tcol)


## 高清 3D 子视口：项目用 canvas_items 拉伸、基准分辨率 1280×720。
## 普通的 SubViewportContainer(stretch=true) 只按 1280×720 渲染再放大到实际窗口，
## 加上全局 Nearest 过滤，2K/4K 屏上就是又糊又锯齿。这里让子视口按窗口的真实像素渲染，再 1:1 贴回屏幕。
class HiResView extends Control:
	var box: SubViewportContainer
	var sv: SubViewport

	func _init() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_PASS
		box = SubViewportContainer.new()
		box.stretch = false
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(box)
		sv = SubViewport.new()
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		sv.set_meta("_hires_owner", weakref(self))
		box.add_child(sv)

	func _ready() -> void:
		resized.connect(_fit)
		get_viewport().size_changed.connect(_fit)
		_fit.call_deferred()

	## 逻辑像素 → 物理像素的倍率（窗口 2560 宽、基准 1280 时为 2）
	func pixel_scale() -> float:
		var k := get_viewport().get_final_transform().get_scale().x
		return maxf(k, 0.25)

	func prepare_for_window_size(win_px: Vector2i) -> void:
		if not is_inside_tree() or win_px.x <= 0 or win_px.y <= 0:
			return
		_fit(true, win_px)

	func _fit(allow_auto_scale := true, override_px := Vector2i.ZERO) -> void:
		if not is_inside_tree():
			return
		var k := pixel_scale()
		var ctrl_sz := size
		if ctrl_sz.x <= 0.5 or ctrl_sz.y <= 0.5:
			var vr := get_viewport_rect().size
			if vr.x <= 0.5 or vr.y <= 0.5:
				return
			ctrl_sz = vr
		var px: Vector2i = override_px if (override_px.x > 0 and override_px.y > 0) else Vector2i(maxi(1, int(round(ctrl_sz.x * k))), maxi(1, int(round(ctrl_sz.y * k))))
		if OS.has_feature("web") or OS.has_feature("mobile"):
			GameData.apply_quality(sv, allow_auto_scale, px, true)
			if sv.size != px:
				sv.size = px
			box.size = Vector2(px)
			box.scale = Vector2(ctrl_sz.x / float(px.x), ctrl_sz.y / float(px.y))
			box.position = Vector2.ZERO
			return
		# 桌面端直接把 SubViewport 尺寸设为缩放后的 3D 目标分辨率（由 SubViewportContainer 线性合成到原生 4K 窗口，
		# UI 文本仍保持 100% 原生 4K）：彻底避免为菜单/机库分配原生 4K SubViewport + 4K FSR 中间缓冲及切全屏 VMA 显存暴涨。
		var sc := GameData.compute_desktop_scale(px, allow_auto_scale)
		var sv_px := Vector2i(maxi(1, int(round(px.x * sc))), maxi(1, int(round(px.y * sc))))
		GameData.apply_quality(sv, allow_auto_scale, sv_px, true)
		if sv.size != sv_px:
			sv.size = sv_px
		box.size = Vector2(sv_px)
		box.scale = Vector2(ctrl_sz.x / float(sv_px.x), ctrl_sz.y / float(sv_px.y))
		box.position = Vector2.ZERO


static func fit_centered_panel(p: Control, margin := 14.0) -> void:
	if p == null or not is_instance_valid(p) or not p.is_inside_tree():
		return
	var vp := p.get_viewport()
	if vp == null:
		return
	var vs := vp.get_visible_rect().size
	if vs.x <= 0.0 or vs.y <= 0.0 or p.size.x <= 0.0 or p.size.y <= 0.0:
		return
	var max_w := maxf(vs.x - margin * 2.0, 200.0)
	var max_h := maxf(vs.y - margin * 2.0, 200.0)
	var s := minf(1.0, minf(max_w / p.size.x, max_h / p.size.y))
	p.pivot_offset = p.size * 0.5
	p.scale = Vector2(s, s)


static func bind_fit_panel(p: Control, margin := 14.0) -> void:
	var binding := _PanelFitBinding.new()
	binding.margin = margin
	binding.fit_panel = fit_centered_panel
	p.add_child(binding)


## 回调由随面板销毁的节点持有，避免根视口长期保留捕获已释放面板的 lambda。
class _PanelFitBinding extends Node:
	var margin := 14.0
	var fit_panel: Callable
	var _queued := false

	func _ready() -> void:
		var panel := get_parent() as Control
		panel.resized.connect(_request_fit)
		panel.visibility_changed.connect(_request_fit)
		get_viewport().size_changed.connect(_request_fit)
		_request_fit()

	func _request_fit() -> void:
		if _queued: return
		_queued = true
		_fit.call_deferred()

	func _fit() -> void:
		_queued = false
		if is_inside_tree():
			fit_panel.call(get_parent() as Control, margin)
