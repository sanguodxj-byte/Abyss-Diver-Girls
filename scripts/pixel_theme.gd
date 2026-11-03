extends RefCounted
## 全局像素 UI 主题：面板 / 按钮 / 输入框 / 下拉 / 勾选 / 滑条 / 滚动条 / 弹窗全部换成像素九宫格，
## 控件圆角一律为 0，字号只走 12 的整数倍。运行时由 PixelUI 自动加载并挂到根窗口，所有界面继承。
const FONT := "res://assets/fonts/fusion-pixel-12px-zh_hans.ttf"
const PXDIR := "res://assets/ui/px/"
static var _px9 := {}

const ACCENT := Color(0.72, 0.5, 0.09)
const TEXT := Color(0.91, 0.9, 0.86)
const MUTED := Color(0.62, 0.61, 0.58)
const BG := Color(0.07, 0.07, 0.08)
const LINE := Color(0.38, 0.36, 0.31)

static var _theme: Theme


static func build() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = load(FONT)
	t.default_font_size = 12

	# 面板与容器
	t.set_stylebox("panel", "Panel", px9("panel9", 12, 12, 10, 8))
	t.set_stylebox("panel", "PanelContainer", px9("panel9", 12, 12, 10, 8))
	t.set_stylebox("panel", "PopupPanel", px9("panel9", 12, 12, 8, 8))
	t.set_stylebox("panel", "TabContainer", px9("panel9", 12, 12, 10, 8))

	# 按钮 / 下拉 / 页签
	for c in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton"]:
		t.set_stylebox("normal", c, px9("btn9_n", 10, 10, 9, 5))
		t.set_stylebox("hover", c, px9("btn9_h", 10, 10, 9, 5))
		t.set_stylebox("pressed", c, px9("btn9_p", 10, 10, 9, 5))
		t.set_stylebox("disabled", c, px9("btn9_d", 10, 10, 9, 5))
		t.set_stylebox("focus", c, StyleBoxEmpty.new())
		t.set_color("font_color", c, TEXT)
		t.set_color("font_hover_color", c, Color(1.0, 0.9, 0.62))
		t.set_color("font_pressed_color", c, ACCENT.lightened(0.25))
		t.set_color("font_disabled_color", c, Color(0.45, 0.45, 0.48))
	t.set_icon("arrow", "OptionButton", pix_arrow())
	t.set_icon("checked", "CheckButton", pix_check(true))
	t.set_icon("unchecked", "CheckButton", pix_check(false))
	t.set_icon("checked", "CheckBox", pix_check(true))
	t.set_icon("unchecked", "CheckBox", pix_check(false))
	t.set_constant("h_separation", "CheckButton", 6)
	t.set_constant("h_separation", "CheckBox", 6)
	for s in ["tab_selected", "tab_hovered", "tab_unselected", "tab_disabled", "tab_focus"]:
		var tex := "nav9_on" if s == "tab_selected" else ("nav9_h" if s == "tab_hovered" else "nav9_n")
		t.set_stylebox(s, "TabContainer", px9(tex, 8, 8, 8, 4))
	t.set_color("font_selected_color", "TabContainer", ACCENT.lightened(0.2))
	t.set_color("font_unselected_color", "TabContainer", MUTED)

	# 输入框
	for c in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", c, px9("inset9", 6, 6, 6, 4))
		t.set_stylebox("focus", c, px9("inset9", 6, 6, 6, 4))
		t.set_color("font_color", c, TEXT)
		t.set_color("caret_color", c, ACCENT)
		t.set_color("selection_color", c, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.25))

	# 滑条：像素轨道 + 实心滑块
	var track := flat(Color(0.12, 0.12, 0.13), LINE, 1, 4)
	var fill := flat(ACCENT, ACCENT, 1, 4)
	for c in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", c, track)
		t.set_stylebox("grabber_area", c, fill)
		t.set_stylebox("grabber_area_highlight", c, fill)
		t.set_icon("grabber", c, pix_grabber())
		t.set_icon("grabber_highlight", c, pix_grabber())

	# 滚动条
	var sbg := flat(Color(0.09, 0.09, 0.1), LINE, 1, 3)
	var grb := flat(Color(0.45, 0.43, 0.38), Color(0.55, 0.53, 0.46), 1, 3)
	var grb2 := flat(ACCENT, ACCENT, 1, 3)
	for c in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", c, sbg)
		t.set_stylebox("scroll_focus", c, sbg)
		t.set_stylebox("grabber", c, grb)
		t.set_stylebox("grabber_highlight", c, grb2)
		t.set_stylebox("grabber_pressed", c, grb2)

	# 列表 / 弹窗 / 提示
	t.set_stylebox("panel", "ItemList", px9("inset9", 6, 6, 6, 4))
	t.set_stylebox("selected", "ItemList", px9("cell9_sel", 4, 4, 4, 3))
	t.set_stylebox("selected_focus", "ItemList", px9("cell9_sel", 4, 4, 4, 3))
	t.set_stylebox("hovered", "ItemList", px9("cell9_hover", 4, 4, 4, 3))
	t.set_stylebox("hovered_selected", "ItemList", px9("cell9_sel", 4, 4, 4, 3))
	t.set_stylebox("hovered_selected_focus", "ItemList", px9("cell9_sel", 4, 4, 4, 3))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", Color(1.0, 0.94, 0.78))
	t.set_color("font_hovered_color", "ItemList", Color(1.0, 0.94, 0.78))
	t.set_constant("v_separation", "ItemList", 6)
	t.set_constant("h_separation", "ItemList", 8)
	t.set_stylebox("panel", "PopupMenu", px9("panel9", 12, 12, 8, 6))
	t.set_stylebox("hover", "PopupMenu", px9("cell9_hover", 4, 4, 4, 3))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color(1.0, 0.94, 0.78))
	t.set_constant("v_separation", "PopupMenu", 6)
	t.set_stylebox("panel", "TooltipPanel", px9("tip9", 8, 8, 6, 4))
	t.set_color("font_color", "TooltipLabel", TEXT)

	# 进度条
	t.set_stylebox("background", "ProgressBar", flat(Color(0.1, 0.1, 0.11), LINE, 1, 3))
	t.set_stylebox("fill", "ProgressBar", flat(ACCENT, ACCENT, 1, 3))
	t.set_color("font_color", "ProgressBar", TEXT)
	_theme = t
	return t


## 像素九宫格：中段按整像素平铺，避免最近邻拉伸把像素拉宽
static func px9(name: String, mlr: int, mtb := -1, plr := -1, ptb := -1) -> StyleBox:
	if mtb < 0:
		mtb = mlr
	if plr < 0:
		plr = mlr
	if ptb < 0:
		ptb = plr
	var key := "%s/%d/%d/%d/%d" % [name, mlr, mtb, plr, ptb]
	if _px9.has(key):
		return _px9[key]
	var path := PXDIR + name + ".png"
	var sb: StyleBox
	if not ResourceLoader.exists(path):
		sb = flat(BG, LINE, 1, plr)
	else:
		var st := StyleBoxTexture.new()
		st.texture = load(path)
		st.texture_margin_left = mlr
		st.texture_margin_right = mlr
		st.texture_margin_top = mtb
		st.texture_margin_bottom = mtb
		st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		st.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		sb = st
	sb.content_margin_left = plr
	sb.content_margin_right = plr
	sb.content_margin_top = ptb
	sb.content_margin_bottom = ptb
	_px9[key] = sb
	return sb


static func flat(bg: Color, border: Color, bw := 1, pad := 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = bw
	sb.border_width_right = bw
	sb.border_width_top = bw
	sb.border_width_bottom = bw
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.6
	sb.content_margin_bottom = pad * 0.6
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	return sb


static func _tex_from(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


## 下拉箭头：4x6 像素阶梯三角，放大 2 倍显示
static func pix_arrow() -> Texture2D:
	var img := Image.create(8, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for row in 6:
		var w := 6 - row
		for x in w:
			for py in 2:
				for px in 2:
					img.set_pixel(1 + x * 2 + px, 2 + row * 2 + py, ACCENT)
	return _tex_from(img)


## 勾选：实心方框 + 对勾像素
static func pix_check(on: bool) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 16:
		for x in 16:
			if x == 0 or y == 0 or x == 15 or y == 15:
				img.set_pixel(x, y, LINE)
			elif x < 4 or y < 4 or x > 11 or y > 11:
				continue
	img.fill_rect(Rect2i(2, 2, 12, 12), Color(0.1, 0.1, 0.11))
	if on:
		img.fill_rect(Rect2i(2, 2, 12, 12), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.9))
		var pts := [Vector2i(4, 8), Vector2i(5, 9), Vector2i(6, 10), Vector2i(7, 9), Vector2i(8, 8), Vector2i(9, 7), Vector2i(10, 6), Vector2i(11, 5)]
		for p in pts:
			for dy in 2:
				for dx in 2:
					img.set_pixel(p.x + dx, p.y + dy, Color(0.08, 0.08, 0.09))
	return _tex_from(img)


## 滑块：12x16 竖条，顶部一道高光
static func pix_grabber() -> Texture2D:
	var img := Image.create(12, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(1, 1, 10, 14), Color(0.1, 0.1, 0.11))
	img.fill_rect(Rect2i(2, 2, 8, 12), ACCENT)
	img.fill_rect(Rect2i(2, 2, 8, 3), ACCENT.lightened(0.35))
	img.fill_rect(Rect2i(3, 6, 6, 2), Color(0.08, 0.08, 0.09))
	return _tex_from(img)
