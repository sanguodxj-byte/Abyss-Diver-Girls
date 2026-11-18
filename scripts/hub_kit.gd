extends RefCounted
## 机库二级菜单（scripts/hub.gd）专用的像素风部件。v0.7 版式参考「逃离塔科夫」式库存界面：
## 深灰底 + 1px 橄榄灰描边 + 米白文字 + 琥珀强调；面板带标题条（中文标题 + 小号大写英文副标）与四角琥珀像素角标；
## 物品一律放在等大正方格（ItemGrid / IconCell）里：左上角短名、右下角数量、底色按稀有度、悬停出详情浮窗、可拖放。
## 头像框贴图由 tools/gen_hub_ui.py 生成，头像由 tools/gen_avatars.py 从立绘裁切生成，物品图标见 scripts/item_icons.gd。
## v0.7.1：面板 / 卡片 / 按钮 / 导航 / 物品格换成 tools/gen_tarkov_px.py 逐像素绘制的九宫格贴图（assets/ui/px，2 倍像素格，
## 与角色像素头像同尺度）：铆钉拉丝金属面板 + 凹槽内衬 + 标题铭牌 + 琥珀角标，物品格按稀有度分底板。
## 版式约定：外边距 12、栏间距 8、面板内边距 8、行距 6；字号只用 12 / 24（PixelUI 吸附）。

const UI = preload("res://scripts/ui.gd")
const GridPack = preload("res://scripts/grid_pack.gd")

const M := 12          ## 屏幕外边距
const GAP := 8         ## 栏间距
const ROW := 6         ## 控件行距
const TOP_H := 36      ## 顶部细状态栏
const BOT_H := 48      ## 底部主导航栏
const CELL := 48       ## 物品格边长（图标 16px ×2）

## Semi-sci-fi wasteland industrial hub palette: industrial grey-black + darker weathered ochre
const BG0 := Color(0.056, 0.060, 0.066, 0.97)
const BG1 := Color(0.082, 0.088, 0.094, 0.97)
const BG2 := Color(0.118, 0.126, 0.134, 0.97)
const BG3 := Color(0.165, 0.176, 0.186, 0.99)
const LINE := Color(0.22, 0.24, 0.26)
const LINE2 := Color(0.40, 0.43, 0.46)
const STEEL := Color(0.38, 0.41, 0.44)
const INK := Color(0.08, 0.09, 0.10)
const CREAM := Color(0.88, 0.88, 0.85)
const CREAM_DIM := Color(0.56, 0.58, 0.58)
const OLIVE := Color(0.20, 0.22, 0.24)
const CELL_EMPTY := Color(0.055, 0.060, 0.066, 0.94)
const CELL_LINE := Color(0.20, 0.22, 0.24)
const CELL_RAR := [Color(0.115, 0.124, 0.132), Color(0.105, 0.140, 0.112), Color(0.098, 0.130, 0.165), Color(0.175, 0.125, 0.072)]
const OK_C := Color(0.46, 0.76, 0.50)
const NG_C := Color(0.84, 0.33, 0.25)

const AMBER := Color(0.78, 0.48, 0.16)
const AMBER_HI := Color(0.87, 0.59, 0.25)
const AMBER_DK := Color(0.52, 0.31, 0.10)
const RULE := Color(0.42, 0.45, 0.48, 0.22)
const DIM := Color(0.54, 0.56, 0.57)

## 主角团（顶栏阵列顺序）与黑市商人
const CREW := ["nao", "rei", "kurumi", "lina", "mia"]
const MERCHANT_IDS := ["ajin", "xiaoman", "shiori", "karasu", "nihong", "gin"]
## 头像底色（每人一个识别色，取自立绘主色）
const TINT := {
	"nao": Color(0.42, 0.44, 0.5), "rei": Color(0.28, 0.4, 0.3), "kurumi": Color(0.62, 0.32, 0.12),
	"lina": Color(0.16, 0.22, 0.45), "mia": Color(0.45, 0.18, 0.14), "ajin": Color(0.5, 0.42, 0.32),
	"xiaoman": Color(0.12, 0.38, 0.36), "shiori": Color(0.42, 0.38, 0.5), "karasu": Color(0.22, 0.22, 0.24),
	"nihong": Color(0.5, 0.28, 0.5), "gin": Color(0.42, 0.12, 0.16),
}

static var _avatars := {}


## 头像贴图：size_px 48 → 96×96（48 像素格 ×2）；20 → 40×40；64 → 256×256（AssetPaths 约定）
static func avatar_tex(id: String, size_px := 48) -> Texture2D:
	var key := "%s@%d" % [id, size_px]
	if _avatars.has(key):
		return _avatars[key]
	var path := "res://assets/avatars/%s.png" % id
	if size_px == 48 or size_px == 20:
		path = "res://assets/avatars/px%d/%s.png" % [size_px, id]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_avatars[key] = t
	return t


# ---------------------------------------------------------------- 像素贴图（assets/ui/px）
const PXDIR := "res://assets/ui/px/"
static var _pxt := {}
static var _px9 := {}


static func px_tex(name: String) -> Texture2D:
	if not _pxt.has(name):
		var path := PXDIR + name + ".png"
		_pxt[name] = load(path) if ResourceLoader.exists(path) else null
	return _pxt[name]


## 像素九宫格：mlr / mtb 为贴图左右 / 上下边距（贴图像素 = 逻辑像素，2 倍像素格的偶数），
## plr / ptb 为内容边距；中段按整像素平铺（TILE_FIT），不拉伸像素。贴图缺失时退回平涂描边盒。
static func px9(name: String, mlr: int, mtb := -1, plr := -1, ptb := -1) -> StyleBox:
	if mtb < 0:
		mtb = mlr
	if plr < 0:
		plr = mlr
	if ptb < 0:
		ptb = plr
	return UI.PixelTheme.px9(name, mlr, mtb, plr, ptb)


static func hazard_strip(h := 8) -> Control:
	return UI.hazard_strip(h)


static func icon_rect(tex: Texture2D, px := 32) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(px, px)
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## Crisp 32x32 flat anti-aliased vector small icons (status bar & map markers)
static func small_icon(key: String) -> Texture2D:
	var ck := "@s32_" + key
	if _pxt.has(ck):
		var cached: Texture2D = _pxt[ck]
		return cached
	var sz := 32
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ctr := Vector2(16.0, 16.0)
	var icons_lib := load("res://scripts/item_icons.gd")
	var col_y := AMBER_HI
	var col_w := STEEL
	var col_c := Color(0.58, 0.73, 0.78, 1.0)
	var col_g := OK_C
	for y in sz:
		for x in sz:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var dst := Color(0, 0, 0, 0)
			match key:
				"money":
					var outer: float = absf((p - ctr).length() - 10.5) - 1.6
					var inner: float = icons_lib._sd_hex(p, ctr, 5.0)
					dst = icons_lib._blend(dst, col_y, minf(outer, inner))
				"junk":
					var hex_o: float = icons_lib._sd_hex(p, ctr, 10.5)
					var r1: float = maxf(hex_o, -((p - ctr).length() - 4.0))
					dst = icons_lib._blend(dst, col_w, r1)
				"level":
					var d1: float = icons_lib._sd_seg(p, Vector2(7, 21), Vector2(16, 11), 2.0)
					var d2: float = icons_lib._sd_seg(p, Vector2(16, 11), Vector2(25, 21), 2.0)
					var d3: float = icons_lib._sd_seg(p, Vector2(10, 26), Vector2(16, 19), 1.6)
					var d4: float = icons_lib._sd_seg(p, Vector2(16, 19), Vector2(22, 26), 1.6)
					dst = icons_lib._blend(dst, col_y, minf(minf(d1, d2), minf(d3, d4)))
				"raid":
					var ring: float = absf((p - ctr).length() - 9.0) - 1.5
					var h1: float = icons_lib._sd_seg(p, Vector2(4, 16), Vector2(11, 16), 1.3)
					var h2: float = icons_lib._sd_seg(p, Vector2(21, 16), Vector2(28, 16), 1.3)
					var v1: float = icons_lib._sd_seg(p, Vector2(16, 4), Vector2(16, 11), 1.3)
					var v2: float = icons_lib._sd_seg(p, Vector2(16, 21), Vector2(16, 28), 1.3)
					var dot := (p - ctr).length() - 2.4
					dst = icons_lib._blend(dst, col_w, minf(ring, minf(minf(h1, h2), minf(v1, v2))))
					dst = icons_lib._blend(dst, col_y, dot)
				"clock":
					var ring: float = absf((p - ctr).length() - 10.5) - 1.6
					var h1: float = icons_lib._sd_seg(p, ctr, Vector2(16, 9), 1.5)
					var h2: float = icons_lib._sd_seg(p, ctr, Vector2(22, 18), 1.5)
					dst = icons_lib._blend(dst, col_w, minf(ring, minf(h1, h2)))
				"extract":
					var dm := absf(p.x - 16.0) + absf(p.y - 16.0) - 10.0
					var dm2 := absf(p.x - 16.0) + absf(p.y - 16.0) - 6.5
					dst = icons_lib._blend(dst, col_g, maxf(dm, -dm2))
					dst = icons_lib._blend(dst, col_g, (p - ctr).length() - 2.8)
				"poi":
					var dm := absf(p.x - 16.0) + absf(p.y - 16.0) - 10.0
					dst = icons_lib._blend(dst, col_y, dm)
				"ship":
					var s1: float = icons_lib._sd_tri(p, Vector2(16, 5), Vector2(7, 25), Vector2(25, 25))
					var s2: float = icons_lib._sd_tri(p, Vector2(16, 19), Vector2(11, 27), Vector2(21, 27))
					dst = icons_lib._blend(dst, col_y, maxf(s1, -s2))
				"lock":
					var shackle: float = maxf(absf((p - Vector2(16, 12)).length() - 5.0) - 1.5, p.y - 15.0)
					var body: float = icons_lib._sd_box(p, Vector2(16, 20), Vector2(7.0, 6.0))
					dst = icons_lib._blend(dst, col_w, minf(shackle, body))
				"quest":
					var t1: float = icons_lib._sd_tri(p, Vector2(16, 4), Vector2(19, 16), Vector2(13, 16))
					var t2: float = icons_lib._sd_tri(p, Vector2(16, 28), Vector2(13, 16), Vector2(19, 16))
					var t3: float = icons_lib._sd_tri(p, Vector2(4, 16), Vector2(16, 13), Vector2(16, 19))
					var t4: float = icons_lib._sd_tri(p, Vector2(28, 16), Vector2(16, 19), Vector2(16, 13))
					dst = icons_lib._blend(dst, col_y, minf(minf(t1, t2), minf(t3, t4)))
				"equip":
					var box: float = icons_lib._sd_box(p, ctr, Vector2(9.5, 9.5))
					var inb: float = icons_lib._sd_box(p, ctr, Vector2(6.0, 6.0))
					dst = icons_lib._blend(dst, col_c, maxf(box, -inb))
					dst = icons_lib._blend(dst, col_y, icons_lib._sd_box(p, ctr, Vector2(3.0, 3.0)))
				_:
					var hd: float = icons_lib._sd_hex(p, ctr, 9.0)
					dst = icons_lib._blend(dst, col_y, hd)
			img.set_pixel(x, y, dst)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_pxt[ck] = tex
	return tex


# ---------------------------------------------------------------- 样式与主题
static func flat(bg: Color, border := LINE, bw := 1, pad := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.anti_aliasing = true
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = maxi(2, pad - 2)
	sb.content_margin_bottom = maxi(2, pad - 2)
	return sb


static var _theme: Theme

## 机库主题：在 UI.theme() 的像素字体之上，把按钮 / 列表 / 树 / 输入框 / 浮窗换成塔科夫式平涂描边
static func theme() -> Theme:
	if _theme:
		return _theme
	var t: Theme = UI.theme().duplicate()
	t.set_stylebox("normal", "Button", px9("btn9_n", 8, 8, 10, 8))
	t.set_stylebox("hover", "Button", px9("btn9_h", 8, 8, 10, 8))
	t.set_stylebox("pressed", "Button", px9("btn9_p", 8, 8, 10, 8))
	t.set_stylebox("hover_pressed", "Button", px9("btn9_p", 8, 8, 10, 8))
	t.set_stylebox("disabled", "Button", px9("btn9_d", 8, 8, 10, 8))
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", AMBER_HI)
	t.set_color("font_pressed_color", "Button", AMBER)
	t.set_color("font_hover_pressed_color", "Button", AMBER_HI)
	t.set_color("font_disabled_color", "Button", Color(0.42, 0.44, 0.44))
	t.set_stylebox("panel", "PanelContainer", px9("panel9", 16, 16, 12, 10))
	t.set_stylebox("panel", "PopupMenu", px9("tip9", 6, 6, 8, 6))
	t.set_stylebox("hover", "PopupMenu", px9("card9_on", 6, 6, 4, 2))
	t.set_color("font_color", "PopupMenu", CREAM)
	t.set_stylebox("panel", "TooltipPanel", px9("tip9", 6, 6, 8, 6))
	t.set_color("font_color", "TooltipLabel", CREAM)
	for le in ["LineEdit"]:
		t.set_stylebox("normal", le, px9("inset9", 6, 6, 6, 4))
		t.set_stylebox("focus", le, px9("card9_on", 6, 6, 6, 4))
		t.set_color("font_color", le, CREAM)
		t.set_color("font_placeholder_color", le, CREAM_DIM)
	t.set_stylebox("panel", "Tree", px9("inset9", 6, 6, 4, 4))
	t.set_stylebox("focus", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("selected", "Tree", px9("card9_on", 6, 6, 2, 2))
	t.set_stylebox("selected_focus", "Tree", px9("card9_on", 6, 6, 2, 2))
	t.set_stylebox("hovered", "Tree", flat(Color(0.85, 0.88, 0.88, 0.06), Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("cursor", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("cursor_unfocused", "Tree", StyleBoxEmpty.new())
	t.set_color("font_color", "Tree", CREAM)
	t.set_color("font_selected_color", "Tree", AMBER_HI)
	t.set_color("guide_color", "Tree", Color(0.8, 0.82, 0.82, 0.06))
	t.set_color("relationship_line_color", "Tree", LINE2)
	t.set_constant("draw_relationship_lines", "Tree", 1)
	t.set_constant("v_separation", "Tree", 6)
	t.set_constant("item_margin", "Tree", 14)
	t.set_constant("inner_item_margin_left", "Tree", 4)
	t.set_font_size("font_size", "Tree", 13)
	t.set_stylebox("panel", "ItemList", px9("inset9", 6, 6, 4, 4))
	t.set_stylebox("selected", "ItemList", px9("card9_on", 6, 6, 2, 2))
	t.set_stylebox("selected_focus", "ItemList", px9("card9_on", 6, 6, 2, 2))
	t.set_stylebox("hovered", "ItemList", flat(Color(1, 1, 1, 0.05), LINE, 1, 2))
	_theme = t
	return t


# ---------------------------------------------------------------- 面板与卡片
## 面板：拉丝金属九宫格（四角琥珀角标、铆钉、凹槽内衬都在贴图 panel9 里）。ticks 保留为兼容字段
class TPanel extends PanelContainer:
	var ticks := true


static func frame(pad := 8) -> PanelContainer:
	var p := TPanel.new()
	p.add_theme_stylebox_override("panel", px9("panel9", 16, 16, pad + 4, pad + 2))
	return p


## 铆钉工业印记：做旧橙黄锁块 + 工业灰黑斜切角片与铆钉
class HeaderStamp extends Control:
	var compact := false

	func _init(is_compact := false) -> void:
		compact = is_compact
		custom_minimum_size = Vector2(9, 11) if compact else Vector2(12, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var h := size.y
		var w := size.x
		var bw := 3.0 if compact else 4.0
		draw_rect(Rect2(0.0, 1.0, bw, h - 2.0), AMBER)
		var gx := bw + 2.0
		var gw := w - gx
		var pts := PackedVector2Array([
			Vector2(gx, 1.0),
			Vector2(gx + gw, 1.0),
			Vector2(gx + gw, h - 4.0),
			Vector2(gx + gw - 3.0, h - 1.0),
			Vector2(gx, h - 1.0),
		])
		draw_colored_polygon(pts, Color(0.18, 0.20, 0.22) if not compact else Color(0.22, 0.24, 0.26))
		draw_circle(Vector2(gx + gw * 0.5, h * 0.5), 1.1, Color(0.54, 0.57, 0.59) if not compact else Color(0.84, 0.86, 0.85))


## 带标题条的面板：返回 [面板, 内容 VBox, 标题条右侧 Label]
static func tpanel(title: String, en := "", right := "", pad := 8) -> Array:
	var p := TPanel.new()
	p.add_theme_stylebox_override("panel", px9("panel9", 16, 16, 8, 8))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", px9("hdr_dark9", 14, 6, 12, 4))
	v.add_child(head)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 6)
	head.add_child(hh)
	hh.add_child(HeaderStamp.new(false))
	var tl := UI.label(title, 12, CREAM)
	hh.add_child(tl)
	var el := UI.label(en.to_upper(), 12, CREAM_DIM)
	el.visible = (not UI._is_en()) and en != "" and en.to_upper() != title.to_upper()
	hh.add_child(el)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hh.add_child(sp)
	var rl := UI.label(right, 12, Color(0.76, 0.77, 0.74))
	hh.add_child(rl)
	var m := MarginContainer.new()
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for k in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(k, maxi(0, pad - 2))
	v.add_child(m)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", ROW)
	m.add_child(body)
	p.set_meta("title_lbl", tl)
	p.set_meta("en_lbl", el)
	return [p, body, rl]


static func card_style(on := false, pad := 8) -> StyleBox:
	return px9("card9_on" if on else "card9", 6, 6, pad, maxi(2, pad - 2))


static func card(on := false, pad := 8) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_style(on, pad))
	return p


## 小标签：amber = 做旧橙黄警戒牌，false = 工业灰黑金属铭牌
static func tag(text: String, amber := true) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := flat(AMBER if amber else Color(0.18, 0.20, 0.22, 0.98), Color(0.36, 0.39, 0.42) if not amber else AMBER_DK, 1, 5)
	sb.content_margin_top = 0
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	var l := UI.label(text, 12, INK if amber else Color(0.84, 0.85, 0.83))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


## 分区小标题：工业印记 + 标题 + 大写英文副标 + 细线，右侧可放计数文字（返回 [行, 右侧 Label]）
static func section(title: String, en := "", right := "") -> Array:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(HeaderStamp.new(true))
	h.add_child(UI.label(title, 12, CREAM))
	if en != "" and (not UI._is_en()) and en.to_upper() != title.to_upper():
		h.add_child(UI.label(en.to_upper(), 12, CREAM_DIM))
	var r := Rule.new()
	r.solid = true
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(r)
	var rl := UI.label(right, 12, CREAM_DIM)
	h.add_child(rl)
	return [h, rl]


static func spacer(h := 4) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func vbox(sep := ROW) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func wrap(text := "", c := UI.TEXT) -> Label:
	var l := UI.label(text, 12, c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## 文字左、数值右的一行
static func kv(k: String, v: String, vc := UI.TEXT) -> HBoxContainer:
	var h := hbox(6)
	var a := UI.label(k, 12, UI.MUTED)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	var b := UI.label(v, 12, vc)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(b)
	return h


## 费用行：¥ 金额 + 每种材料「名称 有/需」，不够的标红；满级时显示「已满级」
static func cost_row(parts: Array, item_name: Callable) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 10)
	f.add_theme_constant_override("v_separation", 2)
	if parts.is_empty():
		f.add_child(UI.label(UI._lt("已满级", "MAX LEVEL"), 12, UI.GOOD))
		return f
	for p in parts:
		var ok: bool = int(p.have) >= int(p.need)
		var t := ""
		if str(p.id) == "money":
			t = "¥%s" % _money_text(int(p.need))
		else:
			t = "%s %d/%d" % [str(item_name.call(str(p.id))), int(p.have), int(p.need)]
		f.add_child(UI.label(t, 12, (Color(0.74, 0.61, 0.28) if str(p.id) == "money" else UI.TEXT) if ok else UI.BAD))
	return f


static func _money_text(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


## 主操作按钮（琥珀底、深色字）
static func primary(text: String, h := 32) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_stylebox_override("normal", px9("btn9_main_n", 8, 8, 12, 10))
	b.add_theme_stylebox_override("hover", px9("btn9_main_h", 8, 8, 12, 10))
	b.add_theme_stylebox_override("pressed", px9("btn9_main_p", 8, 8, 12, 10))
	b.add_theme_stylebox_override("hover_pressed", px9("btn9_main_p", 8, 8, 12, 10))
	b.add_theme_stylebox_override("disabled", px9("btn9_main_d", 8, 8, 12, 10))
	b.add_theme_color_override("font_color", Color(0.08, 0.05, 0.02))
	b.add_theme_color_override("font_hover_color", Color(0.05, 0.03, 0.0))
	b.add_theme_color_override("font_pressed_color", Color(0.05, 0.03, 0.0))
	b.add_theme_color_override("font_disabled_color", Color(0.50, 0.42, 0.30))
	return b


## 次级按钮：描边 + 小号大写英文副标（第二个 Label 挂在按钮右侧）
static func button(text: String, h := 28) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, h)
	b.focus_mode = Control.FOCUS_NONE
	return b


## 需求行：■ 满足（绿）/ 不足（红）+ 文字，右侧「有 / 需」
static func req_row(text: String, have: String, ok: bool, neutral := false) -> HBoxContainer:
	var h := hbox(6)
	var dot := ColorRect.new()
	dot.color = (OK_C if ok else NG_C) if not neutral else Color(0.38, 0.38, 0.33)
	dot.custom_minimum_size = Vector2(6, 6)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	var a := UI.label(text, 12, (CREAM if ok else Color(0.95, 0.62, 0.55)) if not neutral else CREAM_DIM)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.clip_text = true
	a.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(a)
	if have != "":
		h.add_child(UI.label(have, 12, (OK_C if ok else NG_C) if not neutral else CREAM_DIM))
	return h


## 费用 → 需求行列表（金额一行 + 每种材料一行）
static func req_list(parts: Array, item_name: Callable) -> VBoxContainer:
	var v := vbox(3)
	if parts.is_empty():
		v.add_child(req_row(UI._lt("已满级", "Maxed"), "", true))
		return v
	for p in parts:
		var ok: bool = int(p.have) >= int(p.need)
		if str(p.id) == "money":
			v.add_child(req_row(UI._lt("信用点", "Credits"), "¥%s" % _money_text(int(p.need)), ok))
		else:
			v.add_child(req_row(str(item_name.call(str(p.id))), "%d / %d" % [int(p.have), int(p.need)], ok))
	return v


## 物品短名（格子左上角，48 格里最多约 3 个汉字宽）：
## 物品数据里的 short 字段 → ABBR 缩写表 → 型号（SC-1、MK-II、HMG-24）→ 去掉「旧世界」与括号后的前 3 个字。
## 绘制时再按实际像素宽度裁到格子内（fit_text），不会溢出到相邻格。
const ABBR := {
	"credit_s": "芯片S", "credit_l": "芯片L", "gold": "金条", "energy_rod": "电池棒", "extract_flare": "烟幕",
	"extract_barrier": "屏障", "sonic_decoy": "诱饵", "coolant_pack": "冷却剂", "surge_cell": "超频芯", "fuel_cell": "燃料",
	"repair_kit": "维修包", "beacon": "信标", "water_tab": "净水片", "can_food": "罐头", "biscuit": "饼干", "coffee": "咖啡豆",
	"bug_crystal": "虫晶", "chitin": "虫甲", "circuit": "电路板", "wire": "铜线", "bolts": "螺栓", "hdd": "硬盘", "toy": "玩具",
	"arch_blueprint": "蓝图", "arch_child_drawing": "儿童画", "arch_deep_record": "钻探录", "arch_duty_log": "值班志",
	"arch_flight_log": "航行志", "arch_letter": "信件", "arch_manifest": "货单", "arch_observation": "水质录", "arch_photo": "照片",
	"arch_research_note": "观测记", "arch_shift_log": "班次卡", "arch_tape": "磁带",
	"gift_chart": "图册", "gift_cocoa": "可可粉", "gift_flask": "酒壶", "gift_watch": "怀表", "gift_wrench": "扳手",
}
const ABBR_EN := {
	"credit_s": "CHIPS", "credit_l": "CHIPL", "gold": "GOLD", "energy_rod": "ROD", "extract_flare": "SMOKE",
	"extract_barrier": "WALL", "sonic_decoy": "DECOY", "coolant_pack": "COOL", "surge_cell": "SURGE", "fuel_cell": "CELL",
	"repair_kit": "KIT", "beacon": "BEACN", "water_tab": "TABS", "can_food": "MEAT", "biscuit": "RATS", "coffee": "BEANS",
	"bug_crystal": "CRYS", "chitin": "CHITN", "circuit": "PCB", "wire": "WIRE", "bolts": "BOLTS", "hdd": "HDD", "toy": "TOY",
	"arch_blueprint": "PLAN", "arch_child_drawing": "DRAW", "arch_deep_record": "DRILL", "arch_duty_log": "DUTY",
	"arch_flight_log": "FLGT", "arch_letter": "MAIL", "arch_manifest": "LIST", "arch_observation": "WATR", "arch_photo": "PHOT",
	"arch_research_note": "NOTE", "arch_shift_log": "CARD", "arch_tape": "TAPE",
	"gift_chart": "MAP", "gift_cocoa": "COCOA", "gift_flask": "FLASK", "gift_watch": "WATCH", "gift_wrench": "WRNCH",
}
static var _re_model: RegEx


static func short_name(id: String) -> String:
	var gd = Engine.get_main_loop().root.get_node_or_null("GameData")
	var base := id if gd == null else str(gd.base_id(id))
	var en := UI._is_en()
	if en and ABBR_EN.has(base):
		return ABBR_EN[base]
	if gd != null:
		var it: Dictionary = gd.item(id)
		if it.has("short") and not en:
			return str(it.short)
	if not en and ABBR.has(base):
		return ABBR[base]
	var n := id if gd == null else str(gd.item_name(id))
	if _re_model == null:
		_re_model = RegEx.new()
		_re_model.compile("[A-Z]{1,4}-?(?:[0-9]{1,3}[A-Z]?|[IVX]{1,4}(?![A-Za-z]))")
	var m := _re_model.search(n)
	if m:
		return m.get_string()
	var re := RegEx.new()
	re.compile("[（(].*?[)）]")
	n = re.sub(n.replace("旧世界", "").replace("Old-World ", ""), "", true).strip_edges()
	return n.substr(0, 5 if en else 3)


## 拖起预览：琥珀描边底板 + 物品图标（中心对在指针上），count > 1 时右下角带数量角标
static func drag_preview(id: String, count := 1) -> Control:
	var gd: Node = Engine.get_main_loop().root.get_node("GameData")
	var gsz: Vector2i = gd.item_grid_size(id)
	var sz := Vector2(clampf(36.0 * float(gsz.x), 44.0, 148.0), clampf(36.0 * float(gsz.y), 44.0, 104.0))
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := Control.new()
	inner.position = -sz * 0.5
	inner.size = sz
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(inner)
	var fr := PanelContainer.new()
	fr.add_theme_stylebox_override("panel", px9("card9_on", 6))
	fr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(fr)
	var tr := TextureRect.new()
	tr.texture = load("res://scripts/item_icons.gd").icon(id)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.offset_left = 4.0
	tr.offset_top = 4.0
	tr.offset_right = -4.0
	tr.offset_bottom = -4.0
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fr.add_child(tr)
	if count > 1:
		var lb := Label.new()
		lb.text = "×%d" % int(count)
		lb.add_theme_font_size_override("font_size", 12)
		lb.add_theme_color_override("font_color", AMBER_HI)
		lb.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		lb.add_theme_constant_override("shadow_offset_x", 1)
		lb.add_theme_constant_override("shadow_offset_y", 1)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		lb.offset_left = -44.0
		lb.offset_top = -20.0
		lb.offset_right = -3.0
		lb.offset_bottom = -3.0
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(lb)
	return root


## 按像素宽度裁字（不加省略号：格子里宁可少一个字也不压到邻格）
static func fit_text(font: Font, text: String, width: float, fs := 12) -> String:
	var t := text
	while t.length() > 1 and font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		t = t.substr(0, t.length() - 1)
	return t


# ---------------------------------------------------------------- 自绘部件
## 像素虚线（2px 点、2px 空）
class Rule extends Control:
	var color := RULE
	var solid := false

	func _init() -> void:
		custom_minimum_size = Vector2(8, 4)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if solid:
			draw_rect(Rect2(0, 1.5, size.x, 1.0), Color(0.28, 0.31, 0.33, 0.88))
			draw_rect(Rect2(0, 0.0, 2.0, 4.0), Color(0.46, 0.49, 0.52, 0.88))
			if size.x > 16.0:
				draw_rect(Rect2(size.x - 2.0, 0.0, 2.0, 4.0), Color(0.46, 0.49, 0.52, 0.88))
			return
		var x := 0.0
		while x < size.x:
			draw_rect(Rect2(x, 1.0, 3, 1.5), color)
			x += 6.0


## 等级刻度：max 个方块，前 level 个点亮
class Pips extends Control:
	var level := 0
	var max_level := 5
	var on_c := AMBER_HI

	func _init(mx := 5) -> void:
		max_level = mx
		custom_minimum_size = Vector2(mx * 10, 8)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func set_level(v: int) -> void:
		level = v
		queue_redraw()

	func _draw() -> void:
		for i in max_level:
			var r := Rect2(i * 10, 0, 8, 8)
			draw_rect(r, Color(0.055, 0.060, 0.066, 0.94))
			draw_rect(r, Color(0.36, 0.39, 0.41, 0.88), false, 1.0)
			if i < level:
				draw_rect(r.grow(-2), on_c)
				draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(4, 1)), Color(0.95, 0.92, 0.84, 0.40))
			else:
				draw_rect(r.grow(-2), Color(0.32, 0.35, 0.37, 0.22))


## 工业机械仪表进度条
class PixBar extends Control:
	var frac := 0.0
	var color := AMBER

	func _init(h := 8) -> void:
		custom_minimum_size = Vector2(40, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func set_frac(f: float) -> void:
		frac = clampf(f, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.075, 0.082, 0.088, 0.95))
		var inner := Rect2(Vector2(1.5, 1.5), size - Vector2(3, 3))
		draw_rect(inner, Color(0.78, 0.80, 0.81, 0.07))
		var w: float = inner.size.x * frac
		if w > 0.5:
			draw_rect(Rect2(inner.position, Vector2(w, inner.size.y)), color)
			draw_rect(Rect2(inner.position, Vector2(w, 1.2)), Color(0.92, 0.93, 0.92, 0.30))
		for q in [0.25, 0.5, 0.75]:
			var tx: float = inner.position.x + inner.size.x * q
			draw_line(Vector2(tx, 1.0), Vector2(tx, size.y - 1.0), Color(0.05, 0.055, 0.06, 0.65), 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.42, 0.45, 0.47, 0.92), false, 1.0)


## 角色头像框：保持像素头像 TEXTURE_FILTER_NEAREST，外框采用废土工业灰白边框与做旧橙黄角标
class Avatar extends Control:
	var char_id := ""
	var tex: Texture2D
	var state := "n"
	var dim := false

	func _init(px := 48, id := "", st := "n") -> void:
		custom_minimum_size = Vector2(px + 12, px + 12)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		state = st
		if id != "":
			set_char(id, px)

	func set_char(id: String, px := -1) -> void:
		char_id = id
		var inner := int(custom_minimum_size.x - 12) if px < 0 else px
		var src := 20 if inner <= 40 else (48 if inner <= 96 else 64)
		tex = load("res://scripts/hub_kit.gd").avatar_tex(id, src)
		queue_redraw()

	func set_state(st: String) -> void:
		state = st
		queue_redraw()

	func _draw() -> void:
		var outer := Rect2(Vector2.ZERO, size)
		var r := Rect2(Vector2(5, 5), size - Vector2(10, 10))
		var tint: Color = load("res://scripts/hub_kit.gd").TINT.get(char_id, Color(0.3, 0.3, 0.32))
		draw_rect(outer, Color(0.085, 0.092, 0.098, 0.97))
		draw_rect(r, tint.darkened(0.62))
		var y := r.position.y
		while y < r.end.y:
			draw_rect(Rect2(r.position.x, y, r.size.x, 1.0), Color(tint.r, tint.g, tint.b, 0.14))
			y += 4.0
		if tex:
			draw_texture_rect(tex, r, false, Color(1, 1, 1, 0.45 if dim else 1.0))
		var is_hi: bool = state == "on" or state == "lead"
		var bcol: Color = AMBER if is_hi else Color(0.36, 0.39, 0.41, 0.94)
		draw_rect(r.grow(1.0), bcol, false, 1.5 if is_hi else 1.0)
		var arm: float = minf(10.0, size.x * 0.18)
		var ccol: Color = AMBER_HI if state == "lead" else (AMBER if state == "on" else Color(0.48, 0.51, 0.54, 0.88))
		var bw: float = 2.0 if is_hi else 1.4
		for pt in [Vector2(1, 1), Vector2(size.x - 1, 1), Vector2(1, size.y - 1), Vector2(size.x - 1, size.y - 1)]:
			var sx: float = 1.0 if pt.x < size.x * 0.5 else -1.0
			var sy: float = 1.0 if pt.y < size.y * 0.5 else -1.0
			draw_line(pt, pt + Vector2(arm * sx, 0), ccol, bw)
			draw_line(pt, pt + Vector2(0, arm * sy), ccol, bw)


# ---------------------------------------------------------------- 物品格
## 画一个物品格：e = {id, count, price, dim, bad, label}；e 为空时画空格。state：0 普通 / 1 悬停 / 2 选中
## 底板按稀有度取 cell9_r0..r3；bad（不满足要求，如钱不够）叠红色斜纹框；选中 / 悬停叠琥珀 / 米白角框。
## name_top = true 时物品名以稀有度色画在格子顶部居中（左右居中、上对齐），图标在名称条下方的剩余区域居中。
static func draw_cell(ci: CanvasItem, r: Rect2, e: Dictionary, font: Font, state := 0, name_top := false) -> void:
	if e.is_empty():
		ci.draw_style_box(px9("cell9_empty", 6), r)
		if state == 1:
			ci.draw_style_box(px9("cell9_hover", 8), r)
		return
	var gd: Node = Engine.get_main_loop().root.get_node("GameData")
	var id := str(e.get("id", ""))
	var it: Dictionary = gd.item(id)
	var rar := clampi(int(it.get("rar", 0)), 0, 3)
	ci.draw_style_box(px9("cell9_r%d" % rar, 6), r)
	var gsz: Vector2i = e["grid_size"] if e.has("grid_size") and e["grid_size"] is Vector2i else gd.item_grid_size(id)
	var show_grid: bool = not bool(e.get("compact", false)) and (gsz.x > 1 or gsz.y > 1) and (r.size.x >= 72.0 or r.size.y >= 72.0)
	var name_h := 0.0
	if name_top:
		var nm := fit_text(font, str(it.get("name", id)), r.size.x - 4.0, 10)
		var na := r.position.y + 2.0 + font.get_ascent(10)
		ci.draw_string(font, Vector2(r.position.x + 2.0, na + 1.0), nm, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 4.0, 10, Color(0, 0, 0, 0.9))
		ci.draw_string(font, Vector2(r.position.x + 1.0, na), nm, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 4.0, 10, GameData.RARITY_COLORS[rar])
		name_h = 13.0
	var icon_r := Rect2(r.position.x, r.position.y + name_h, r.size.x, r.size.y - name_h)
	if show_grid:
		var cw_g: float = r.size.x / float(gsz.x)
		var ch_g: float = r.size.y / float(gsz.y)
		for gx: int in range(1, gsz.x):
			var lx: float = r.position.x + cw_g * float(gx)
			ci.draw_line(Vector2(lx, r.position.y + 3.0), Vector2(lx, r.end.y - 3.0), Color(1, 1, 1, 0.06), 1.0)
		for gy: int in range(1, gsz.y):
			var ly: float = r.position.y + ch_g * float(gy)
			ci.draw_line(Vector2(r.position.x + 3.0, ly), Vector2(r.end.x - 3.0, ly), Color(1, 1, 1, 0.06), 1.0)
	var tex: Texture2D = load("res://scripts/item_icons.gd").icon(id)
	if tex:
		var pad_x: float = clampf(icon_r.size.x * 0.06, 3.0, 8.0)
		var pad_y: float = clampf(icon_r.size.y * 0.06, 3.0, 8.0)
		var avail := Vector2(maxf(8.0, icon_r.size.x - pad_x * 2.0), maxf(8.0, icon_r.size.y - pad_y * 2.0))
		var tw: float = maxf(1.0, float(tex.get_width()))
		var th: float = maxf(1.0, float(tex.get_height()))
		var sc_f: float = minf(avail.x / tw, avail.y / th)
		var isz := Vector2(tw * sc_f, th * sc_f)
		var ip := icon_r.position + (icon_r.size - isz) * 0.5
		ci.draw_texture_rect(tex, Rect2(ip, isz), false, Color(1, 1, 1, 0.45 if e.get("dim", false) else 1.0))
	if show_grid:
		var sz_txt := "%d×%d" % [gsz.x, gsz.y]
		if name_top:
			# 名称占顶行时，尺寸角标让位到左下角
			var bs := r.end.y - 3.0 - font.get_descent(11)
			ci.draw_string(font, Vector2(r.position.x + 4.0, bs + 1.0), sz_txt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 10.0, 11, Color(0, 0, 0, 0.85))
			ci.draw_string(font, Vector2(r.position.x + 3.0, bs), sz_txt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 10.0, 11, Color(0.78, 0.80, 0.81, 0.92))
		else:
			var ta := r.position.y + 2.0 + font.get_ascent(11)
			ci.draw_string(font, Vector2(r.position.x + 6.0, ta + 1.0), sz_txt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 10.0, 11, Color(0, 0, 0, 0.85))
			ci.draw_string(font, Vector2(r.position.x + 5.0, ta), sz_txt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 10.0, 11, Color(0.78, 0.80, 0.81, 0.92))
	var by := r.end.y - 3 - font.get_descent(12)
	if e.has("price"):
		var pt := "¥%s" % _money_text(int(e.price))
		var pc := AMBER_HI if not e.get("bad", false) else NG_C
		ci.draw_string(font, Vector2(r.position.x + 4, by + 1), pt, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 7, 12, Color(0, 0, 0, 0.85))
		ci.draw_string(font, Vector2(r.position.x + 3, by), pt, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 7, 12, pc)
	elif int(e.get("count", 1)) > 1:
		var ct := str(int(e.count))
		ci.draw_string(font, Vector2(r.position.x + 3, by + 1), ct, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 7, 12, Color(0, 0, 0, 0.85))
		ci.draw_string(font, Vector2(r.position.x + 2, by), ct, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 7, 12, CREAM)
	if e.get("dim", false):
		ci.draw_rect(r.grow(-2), Color(0, 0, 0, 0.35))
	if e.get("bad", false):
		ci.draw_style_box(px9("cell9_bad", 8), r)
	if state == 2:
		ci.draw_style_box(px9("cell9_sel", 8), r)
	elif state == 1:
		ci.draw_style_box(px9("cell9_hover", 8), r)
	if state == 1 or state == 2:
		var ccol: Color = AMBER_HI if state == 2 else STEEL
		var arm: float = minf(8.0, minf(r.size.x, r.size.y) * 0.24)
		for pt in [r.position + Vector2(1, 1), Vector2(r.end.x - 1, r.position.y + 1), Vector2(r.position.x + 1, r.end.y - 1), r.end - Vector2(1, 1)]:
			var sx: float = 1.0 if pt.x < r.get_center().x else -1.0
			var sy: float = 1.0 if pt.y < r.get_center().y else -1.0
			ci.draw_line(pt, pt + Vector2(arm * sx, 0), ccol, 1.6)
			ci.draw_line(pt, pt + Vector2(0, arm * sy), ccol, 1.6)


## 物品网格（支持 1×1 与语义多格 gw × gh，按列排布，空位也画出格子）；
## 单击选中（item_selected）、双击（item_activated）、右键（item_context）、悬停浮窗（tip_fn）、拖放（drag_kind / accept_drop / on_drop）。
class ItemGrid extends Control:
	signal item_selected(index: int)
	signal item_activated(index: int)
	signal item_context(index: int)

	var cell := 48
	var entries: Array = []
	var selected := -1
	var hover := -1
	var cols := 1
	var fixed_cols := 0
	var min_rows := 1
	var cap_rows := 0
	var tip_fn: Callable
	var drag_kind := ""
	var accept_drop: Callable
	var on_drop: Callable
	var empty_text := ""
	var show_names := false
	var _drag_kind := ""    ## 正在进行的全局拖曳 kind（空 = 无拖曳）
	var _drag_valid := false ## 本网格接受当前拖曳（整格描边示可放置）
	var _drop_hot := false   ## 指针悬停在本网格上且可放置
	var _ox := 0.0
	var _rects: Array = []
	var _cell_map := PackedInt32Array()
	var _rows_used := 0

	func _init(cell_px := 48) -> void:
		cell = cell_px
		mouse_filter = Control.MOUSE_FILTER_STOP
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(cell, cell)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func set_entries(arr: Array) -> void:
		entries = arr
		if selected >= entries.size():
			selected = -1
		_relayout()
		queue_redraw()

	## 兼容旧 ItemList 接口（测试会调用 select / get_selected_items）
	func select(i: int, _single := true) -> void:
		selected = i
		queue_redraw()

	func deselect_all() -> void:
		selected = -1
		queue_redraw()

	func get_selected_items() -> PackedInt32Array:
		return PackedInt32Array([selected]) if selected >= 0 and selected < entries.size() else PackedInt32Array()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_relayout()
		elif what == NOTIFICATION_MOUSE_EXIT:
			if hover != -1:
				hover = -1
				queue_redraw()
			_set_hot(false)
		elif what == NOTIFICATION_DRAG_BEGIN:
			var d = get_viewport().gui_get_drag_data()
			_drag_kind = str(d.get("kind", "")) if d is Dictionary else ""
			_drag_valid = accept_drop.is_valid() and _drag_kind != "" and bool(accept_drop.call(d))
			_set_hot(false)
			queue_redraw()
		elif what == NOTIFICATION_DRAG_END:
			_drag_kind = ""
			_drag_valid = false
			_set_hot(false)
			queue_redraw()

	func _set_hot(v: bool) -> void:
		if _drop_hot != v:
			_drop_hot = v
			queue_redraw()

	func _entry_size(e: Dictionary) -> Vector2i:
		if e.has("grid_size") and e["grid_size"] is Vector2i:
			return e["grid_size"]
		var loop := Engine.get_main_loop()
		var gd: Node = loop.root.get_node_or_null("GameData") if loop != null else null
		return gd.item_grid_size(str(e.get("id", ""))) if gd != null else Vector2i(1, 1)

	func _relayout() -> void:
		if fixed_cols > 0:
			cols = fixed_cols
		else:
			var c := maxi(1, int(floor(size.x / cell)))
			if size.x < 1.0:
				c = maxi(1, int(floor(custom_minimum_size.x / cell)))
			cols = c
		_ox = maxf(0.0, floorf((size.x - float(cols * cell)) * 0.5)) if size.x > 0.0 else 0.0
		var sizes: Array = []
		for e_v in entries:
			var e: Dictionary = e_v
			sizes.append(_entry_size(e))
		var pk: Dictionary = GridPack.pack(sizes, cols, 0)
		_rects = pk.get("placements", [])
		_rows_used = int(pk.get("rows_used", 0))
		_cell_map = pk.get("cell_to_idx", PackedInt32Array())
		var rows: int = maxi(min_rows, maxi(cap_rows, _rows_used))
		var h: float = float(rows * cell)
		var min_w: float = float(fixed_cols * cell) if fixed_cols > 0 else custom_minimum_size.x
		if absf(custom_minimum_size.y - h) > 0.5 or absf(custom_minimum_size.x - min_w) > 0.5:
			custom_minimum_size = Vector2(min_w, h)
		queue_redraw()

	func index_at(p: Vector2) -> int:
		var c := int(floor((p.x - _ox) / cell))
		var r := int(floor(p.y / cell))
		if c < 0 or c >= cols or r < 0:
			return -1
		var idx_pos: int = r * cols + c
		if idx_pos < 0 or idx_pos >= _cell_map.size():
			return -1
		return int(_cell_map[idx_pos])

	func _cell_rect(i: int) -> Rect2:
		if i >= 0 and i < _rects.size():
			var rc: Rect2i = _rects[i]
			if rc.position.x >= 0:
				return Rect2(_ox + float(rc.position.x * cell), float(rc.position.y * cell), float(rc.size.x * cell), float(rc.size.y * cell))
		return Rect2(_ox + float((i % cols) * cell), float(int(i / cols) * cell), float(cell), float(cell))

	func _draw() -> void:
		var font := get_theme_default_font()
		var rows: int = maxi(min_rows, maxi(cap_rows, _rows_used))
		if cap_rows <= 0:
			rows = maxi(rows, int(ceil(size.y / float(cell))))
		draw_rect(Rect2(_ox, 0, float(cols * cell), float(rows * cell)), Color(0.06, 0.065, 0.07, 0.92))
		var empty_e: Dictionary = {}
		for gy: int in rows:
			for gx: int in cols:
				var idx_pos: int = gy * cols + gx
				var occ_idx: int = int(_cell_map[idx_pos]) if idx_pos >= 0 and idx_pos < _cell_map.size() else -1
				if occ_idx < 0:
					var cr := Rect2(_ox + float(gx * cell), float(gy * cell), float(cell), float(cell))
					load("res://scripts/hub_kit.gd").draw_cell(self, cr, empty_e, font, 0)
		for i: int in entries.size():
			if i >= _rects.size():
				continue
			var rc: Rect2i = _rects[i]
			if rc.position.x < 0:
				continue
			var r := Rect2(_ox + float(rc.position.x * cell) + 1.0, float(rc.position.y * cell) + 1.0, float(rc.size.x * cell) - 1.0, float(rc.size.y * cell) - 1.0)
			var st: int = 2 if i == selected else (1 if i == hover else 0)
			load("res://scripts/hub_kit.gd").draw_cell(self, r, entries[i], font, st, show_names)
			if cap_rows > 0 and rc.position.y + rc.size.y > cap_rows:
				draw_rect(r.grow(-2), Color(0.85, 0.15, 0.15, 0.25))
		draw_rect(Rect2(_ox, 0, float(cols * cell), float(rows * cell)), LINE, false, 1.0)
		if _drag_valid:
			# 拖曳落点反馈：可放置时整格琥珀描边，悬停时加强
			var gr := Rect2(_ox, 0, float(cols * cell), float(rows * cell))
			draw_rect(gr, Color(AMBER.r, AMBER.g, AMBER.b, 0.14 if _drop_hot else 0.05), true)
			draw_rect(gr, AMBER if _drop_hot else Color(AMBER.r, AMBER.g, AMBER.b, 0.45), false, 2.0 if _drop_hot else 1.0)
		if entries.is_empty() and empty_text != "":
			draw_string(font, Vector2(_ox + 8, cell * 0.5 + 4), empty_text, HORIZONTAL_ALIGNMENT_LEFT, float(cols * cell - 16), 12, CREAM_DIM)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion:
			var h := index_at(ev.position)
			if h != hover:
				hover = h
				queue_redraw()
		elif ev is InputEventMouseButton and ev.pressed:
			var i := index_at(ev.position)
			if i < 0:
				return
			if ev.button_index == MOUSE_BUTTON_LEFT:
				var was_sel := (selected == i)
				selected = i
				queue_redraw()
				if ev.double_click or was_sel:
					item_activated.emit(i)
				else:
					item_selected.emit(i)
			elif ev.button_index == MOUSE_BUTTON_RIGHT:
				selected = i
				queue_redraw()
				item_selected.emit(i)
				item_context.emit(i)

	func _get_tooltip(at: Vector2) -> String:
		var i := index_at(at)
		return str(i) if i >= 0 and tip_fn.is_valid() else ""

	func _make_custom_tooltip(for_text: String) -> Object:
		if not tip_fn.is_valid() or not for_text.is_valid_int():
			return null
		var i := int(for_text)
		if i < 0 or i >= entries.size():
			return null
		return tip_fn.call(entries[i])

	func _get_drag_data(at: Vector2) -> Variant:
		if drag_kind == "":
			return null
		var i := index_at(at)
		if i < 0:
			return null
		var e: Dictionary = entries[i]
		set_drag_preview(load("res://scripts/hub_kit.gd").drag_preview(str(e.id), int(e.get("count", 1))))
		return {"kind": drag_kind, "id": str(e.id), "index": i}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		var ok := accept_drop.is_valid() and data is Dictionary and bool(accept_drop.call(data))
		_set_hot(ok)
		return ok

	func _drop_data(_at: Vector2, data: Variant) -> void:
		_set_hot(false)
		if on_drop.is_valid():
			on_drop.call(data)


## 单个物品格（装备槽、物品详情大图标）；entry 为空时画空槽
class IconCell extends Control:
	var entry: Dictionary = {}
	var hl := false
	var tip_fn: Callable

	func _init(px := 48) -> void:
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_PASS
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	func set_box_size(sz: Vector2) -> void:
		custom_minimum_size = sz
		queue_redraw()

	func set_entry(e: Dictionary) -> void:
		entry = e
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if entry.is_empty():
			draw_style_box(load("res://scripts/hub_kit.gd").px9("slot9_empty", 6), r)
			return
		var ce: Dictionary = entry.duplicate()
		ce["compact"] = true
		load("res://scripts/hub_kit.gd").draw_cell(self, r, ce, get_theme_default_font(), 2 if hl else 0)

	func _get_tooltip(_at: Vector2) -> String:
		return "1" if tip_fn.is_valid() and not entry.is_empty() else ""

	func _make_custom_tooltip(_t: String) -> Object:
		return tip_fn.call(entry) if tip_fn.is_valid() and not entry.is_empty() else null


## 底部主导航按钮：等宽，像素图标 + 中文标题 / 小号大写英文；四态贴图 nav9_n（常态）/ nav9_h（悬停）/ nav9_p（按下瞬间）/ nav9_on（当前页）
## 底部居中的大圆钮：与其他页签同一套像素材质与文字层级，只是外框为圆形
class DeployButton extends Button:
	var cn_lbl: Label
	var en_lbl: Label
	var icon_rect: TextureRect
	var _hot := false
	var _tw: Tween

	func _init(cn := "出击", en_text := "SORTIE", icon_key := "nav_deploy") -> void:
		toggle_mode = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(112, 112)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(v)
		var K = load("res://scripts/hub_kit.gd")
		var tex: Texture2D = load("res://scripts/item_icons.gd").ui_icon(icon_key) if icon_key != "" else null
		if tex:
			icon_rect = K.icon_rect(tex, 42)
			icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(icon_rect)
		var is_e: bool = UI._is_en()
		cn_lbl = Label.new()
		cn_lbl.text = en_text if (is_e and en_text != "") else cn
		cn_lbl.add_theme_font_size_override("font_size", 14)
		cn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cn_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(cn_lbl)
		en_lbl = Label.new()
		en_lbl.text = en_text
		en_lbl.visible = false
		en_lbl.add_theme_font_size_override("font_size", 12)
		en_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		en_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(en_lbl)
		resized.connect(func(): pivot_offset = size * 0.5)
		mouse_entered.connect(func(): _hot = true; _spring(1.04))
		mouse_exited.connect(func(): _hot = false; _spring(1.0))
		button_down.connect(func(): _spring(0.96); queue_redraw())
		button_up.connect(func(): _spring(1.04 if _hot else 1.0); queue_redraw())
		toggled.connect(func(_on): _tint())
		_tint()
		pivot_offset = custom_minimum_size * 0.5
		_spring(1.0, true)

	func _spring(to: float, instant := false) -> void:
		if _tw and _tw.is_valid():
			_tw.kill()
		if instant:
			scale = Vector2.ONE * to
			return
		_tw = create_tween()
		_tw.tween_property(self, "scale", Vector2.ONE * to, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _disc(c: Vector2, r: float, col: Color) -> void:
		var y := -r
		while y < r:
			var w: float = floor(sqrt(maxf(r * r - y * y, 0.0)) / 2.0) * 2.0
			draw_rect(Rect2(c.x - w, c.y + y, w * 2.0, 2.0), col)
			y += 2.0

	func _dashed_ring(c: Vector2, r: float, col: Color) -> void:
		var n := 36
		for i in range(0, n, 2):
			draw_arc(c, r - 1.0, TAU * i / n, TAU * (i + 1) / n, 4, col, 2.0, true)

	func _draw() -> void:
		var c := size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 3.0
		var on := button_pressed
		# 1. 重型工业灰黑机加工外法兰盘 + 8 颗沉头铆钉
		var bezel := PackedVector2Array()
		var n_oct := 16
		for i in n_oct:
			var ang := TAU * float(i) / float(n_oct) + PI / 16.0
			bezel.append(c + Vector2(cos(ang), sin(ang)) * r)
		var bezel_col := Color(0.20, 0.22, 0.24, 0.98) if not (_hot or on) else Color(0.28, 0.30, 0.33, 0.99)
		draw_colored_polygon(bezel, bezel_col)
		bezel.append(bezel[0])
		draw_polyline(bezel, Color(0.08, 0.09, 0.10, 0.96), 2.0, true)
		# 2. 中环：做旧橙黄/炭黑径向警示刻度环
		var mid_r := r - 4.5
		draw_circle(c, mid_r, Color(0.09, 0.10, 0.11, 0.98))
		var segs := 24
		for i in segs:
			var a0 := TAU * float(i) / float(segs)
			var a1 := TAU * float(i + 0.58) / float(segs)
			var wc := AMBER_HI if (on or _hot) else AMBER
			if i % 3 == 0:
				wc = wc.darkened(0.14)
			draw_arc(c, mid_r - 2.6, a0, a1, 4, wc, 4.0, true)
		# 3. 中心机械舱门内盘
		var core_r := r - 10.5
		var fill: Color = Color(0.095, 0.102, 0.110, 0.98)
		if button_down:
			fill = Color(0.10, 0.105, 0.11, 0.98)
		elif _hot:
			fill = Color(0.24, 0.18, 0.11, 0.98)
		elif on:
			fill = Color(0.26, 0.19, 0.105, 0.98)
		draw_circle(c, core_r, fill)
		draw_arc(c, core_r, 0, TAU, 48, AMBER_HI if (on or _hot) else STEEL, 2.0, true)
		draw_arc(c, core_r - 3.5, PI * 0.15, PI * 0.85, 16, Color(STEEL.r, STEEL.g, STEEL.b, 0.25), 1.0, true)
		draw_arc(c, core_r - 3.5, -PI * 0.85, -PI * 0.15, 16, Color(STEEL.r, STEEL.g, STEEL.b, 0.40), 1.0, true)
		# 4. 法兰盘四向锁定槽口与 8 颗铆钉
		for k in 8:
			var a := TAU * float(k) / 8.0 + PI / 8.0
			var rp := c + Vector2(cos(a), sin(a)) * (r - 2.4)
			draw_circle(rp, 2.0, Color(0.08, 0.09, 0.10, 0.96))
			draw_circle(rp, 1.1, Color(0.52, 0.55, 0.58, 0.92))
		for a in [0.0, PI * 0.5, PI, PI * 1.5]:
			var d := Vector2(cos(a), sin(a))
			draw_line(c + d * (core_r - 2.0), c + d * (r + 1.5), AMBER_HI if (on or _hot) else STEEL, 3.0, true)

	func _tint() -> void:
		var on := button_pressed
		cn_lbl.add_theme_color_override("font_color", AMBER_HI if on else CREAM)
		en_lbl.add_theme_color_override("font_color", AMBER if on else CREAM_DIM)
		if icon_rect:
			icon_rect.modulate = Color(1, 1, 1) if on else Color(0.88, 0.90, 0.89)
		queue_redraw()


class NavButton extends Button:
	var en := ""
	var cn_lbl: Label
	var en_lbl: Label
	var icon_rect: TextureRect

	func _init(cn := "", en_text := "", icon_key := "") -> void:
		text = ""
		en = en_text
		toggle_mode = true
		focus_mode = Control.FOCUS_NONE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_styles(false)
		button_down.connect(func(): _styles(true))
		button_up.connect(func(): _styles(false))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(h)
		var K = load("res://scripts/hub_kit.gd")
		var tex: Texture2D = load("res://scripts/item_icons.gd").ui_icon(icon_key) if icon_key != "" else null
		if tex:
			icon_rect = K.icon_rect(tex, 32)
			h.add_child(icon_rect)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(v)
		var is_e: bool = UI._is_en()
		cn_lbl = Label.new()
		cn_lbl.text = en_text if (is_e and en_text != "") else cn
		cn_lbl.add_theme_font_size_override("font_size", 14)
		cn_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cn_lbl.name = "CN"
		v.add_child(cn_lbl)
		en_lbl = Label.new()
		en_lbl.text = en_text
		en_lbl.visible = false
		en_lbl.add_theme_font_size_override("font_size", 11)
		en_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		en_lbl.name = "EN"
		v.add_child(en_lbl)
		toggled.connect(func(_on): _tint())
		_tint()

	func _styles(down: bool) -> void:
		var K = load("res://scripts/hub_kit.gd")
		add_theme_stylebox_override("normal", K.px9("nav9_n", 12, 12, 6, 4))
		add_theme_stylebox_override("hover", K.px9("nav9_p" if down else "nav9_h", 12, 12, 6, 4))
		add_theme_stylebox_override("pressed", K.px9("nav9_p" if down else "nav9_on", 12, 12, 6, 4))
		add_theme_stylebox_override("hover_pressed", K.px9("nav9_p" if down else "nav9_on", 12, 12, 6, 4))

	func _tint() -> void:
		var on := button_pressed
		cn_lbl.add_theme_color_override("font_color", AMBER_HI if on else CREAM)
		en_lbl.add_theme_color_override("font_color", AMBER if on else CREAM_DIM)
		if icon_rect:
			icon_rect.modulate = Color(1, 1, 1) if on else Color(0.86, 0.88, 0.88)
