extends RefCounted
## 机库二级菜单（scripts/hub.gd）专用的像素风部件。v0.7 版式参考「逃离塔科夫」式库存界面：
## 深灰底 + 1px 橄榄灰描边 + 米白文字 + 琥珀强调；面板带标题条（中文标题 + 小号大写英文副标）与四角琥珀像素角标；
## 物品一律放在等大正方格（ItemGrid / IconCell）里：左上角短名、右下角数量、底色按稀有度、悬停出详情浮窗、可拖放。
## 头像框贴图由 tools/gen_hub_ui.py 生成，头像由 tools/gen_avatars.py 从立绘裁切生成，物品图标见 scripts/item_icons.gd。
## v0.7.1：面板 / 卡片 / 按钮 / 导航 / 物品格换成 tools/gen_tarkov_px.py 逐像素绘制的九宫格贴图（assets/ui/px，2 倍像素格，
## 与角色像素头像同尺度）：铆钉拉丝金属面板 + 凹槽内衬 + 标题铭牌 + 琥珀角标，物品格按稀有度分底板。
## 版式约定：外边距 12、栏间距 8、面板内边距 8、行距 6；字号只用 12 / 24（PixelUI 吸附）。

const UI = preload("res://scripts/ui.gd")

const M := 12          ## 屏幕外边距
const GAP := 8         ## 栏间距
const ROW := 6         ## 控件行距
const TOP_H := 36      ## 顶部细状态栏
const BOT_H := 48      ## 底部主导航栏
const CELL := 48       ## 物品格边长（图标 16px ×2）

## 塔科夫式色板：深灰底 · 橄榄灰描边 · 米白文字 · 琥珀强调
const BG0 := Color(0.043, 0.045, 0.043, 0.96)    ## 面板底
const BG1 := Color(0.075, 0.078, 0.072, 0.97)    ## 标题条 / 卡片底
const BG2 := Color(0.115, 0.118, 0.108, 1.0)     ## 按钮底
const BG3 := Color(0.16, 0.162, 0.145, 1.0)      ## 悬停
const LINE := Color(0.25, 0.26, 0.225)           ## 描边
const LINE2 := Color(0.4, 0.405, 0.35)           ## 亮描边
const CREAM := Color(0.86, 0.84, 0.75)           ## 主文字
const CREAM_DIM := Color(0.55, 0.54, 0.47)       ## 次文字
const OLIVE := Color(0.32, 0.34, 0.24)
const CELL_EMPTY := Color(0.055, 0.058, 0.054, 0.92)
const CELL_LINE := Color(0.17, 0.175, 0.155)
## 物品格底色（按稀有度，压暗的灰 / 绿 / 蓝 / 紫）
const CELL_RAR := [Color(0.15, 0.152, 0.14), Color(0.11, 0.2, 0.12), Color(0.1, 0.14, 0.24), Color(0.2, 0.11, 0.24)]
const OK_C := Color(0.45, 0.85, 0.4)
const NG_C := Color(0.95, 0.35, 0.3)

const AMBER := Color(1.0, 0.69, 0.13)
const AMBER_DK := Color(0.59, 0.38, 0.05)
const RULE := Color(1, 1, 1, 0.14)
const DIM := Color(0.48, 0.5, 0.54)

## 主角团（顶栏阵列顺序）与黑市商人
const CREW := ["nao", "rei", "kurumi", "lina", "laojiao"]
const MERCHANT_IDS := ["ajin", "xiaoman", "shiori", "karasu", "nihong", "gin"]
## 头像底色（每人一个识别色，取自立绘主色）
const TINT := {
	"nao": Color(0.42, 0.44, 0.5), "rei": Color(0.28, 0.4, 0.3), "kurumi": Color(0.62, 0.32, 0.12),
	"lina": Color(0.16, 0.22, 0.45), "laojiao": Color(0.45, 0.18, 0.14), "ajin": Color(0.5, 0.42, 0.32),
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
	var key := "%s/%d/%d/%d/%d" % [name, mlr, mtb, plr, ptb]
	if _px9.has(key):
		return _px9[key]
	var t := px_tex(name)
	var sb: StyleBox
	if t == null:
		sb = flat(BG1, LINE, 1, plr)
	else:
		var st := StyleBoxTexture.new()
		st.texture = t
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


## 警示黄黑条（横向平铺，高 10）
static func hazard_strip(h := 10) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = px_tex("hazard")
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.custom_minimum_size = Vector2(0, h)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## 像素图标（图集格，按 px 逻辑像素显示：16 格图标用 32 = 2 倍；8 格小图标用 16）
static func icon_rect(tex: Texture2D, px := 32) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(px, px)
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## 8×8 小图标（顶栏状态、地图标记）
static func small_icon(key: String) -> Texture2D:
	var PXA = load("res://scripts/px_atlas.gd")
	var ck := "@s_" + key
	if _pxt.has(ck):
		return _pxt[ck]
	var t: Texture2D = null
	if PXA.SMALL.has(key) and px_tex("atlas8") != null:
		var at := AtlasTexture.new()
		at.atlas = px_tex("atlas8")
		at.region = Rect2(int(PXA.SMALL[key]) * 8, 0, 8, 8)
		at.filter_clip = true
		t = at
	_pxt[ck] = t
	return t


# ---------------------------------------------------------------- 样式与主题
## 平涂描边盒（像素风：直角、无抗锯齿）
static func flat(bg: Color, border := LINE, bw := 1, pad := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.anti_aliasing = false
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
	t.set_color("font_hover_color", "Button", Color(1, 0.96, 0.86))
	t.set_color("font_pressed_color", "Button", AMBER.lightened(0.25))
	t.set_color("font_hover_pressed_color", "Button", AMBER.lightened(0.35))
	t.set_color("font_disabled_color", "Button", Color(0.36, 0.36, 0.33))
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
	t.set_stylebox("hovered", "Tree", flat(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("cursor", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("cursor_unfocused", "Tree", StyleBoxEmpty.new())
	t.set_color("font_color", "Tree", CREAM)
	t.set_color("font_selected_color", "Tree", AMBER.lightened(0.3))
	t.set_color("guide_color", "Tree", Color(1, 1, 1, 0.04))
	t.set_color("relationship_line_color", "Tree", LINE)
	t.set_constant("draw_relationship_lines", "Tree", 1)
	t.set_constant("v_separation", "Tree", 6)
	t.set_constant("item_margin", "Tree", 14)
	t.set_constant("inner_item_margin_left", "Tree", 4)
	t.set_font_size("font_size", "Tree", 12)
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


## 带标题条的面板：返回 [面板, 内容 VBox, 标题条右侧 Label]
static func tpanel(title: String, en := "", right := "", pad := 8) -> Array:
	var p := TPanel.new()
	p.add_theme_stylebox_override("panel", px9("panel9", 16, 16, 8, 8))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", px9("plate9", 14, 6, 12, 4))
	v.add_child(head)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 6)
	head.add_child(hh)
	var blk := ColorRect.new()
	blk.color = AMBER
	blk.custom_minimum_size = Vector2(2, 12)
	blk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hh.add_child(blk)
	var tl := UI.label(title, 12, CREAM)
	hh.add_child(tl)
	var el := UI.label(en.to_upper(), 12, CREAM_DIM)
	hh.add_child(el)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hh.add_child(sp)
	var rl := UI.label(right, 12, CREAM_DIM)
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


## 小标签（等级、稀有度、状态）
static func tag(text: String, amber := true) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := flat(AMBER if amber else Color(0.2, 0.205, 0.185), Color(0, 0, 0, 0), 0, 4)
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", sb)
	var l := UI.label(text, 12, Color(0.08, 0.05, 0.02) if amber else CREAM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


## 分区小标题：小琥珀方块 + 标题 + 大写英文副标 + 细线，右侧可放计数文字（返回 [行, 右侧 Label]）
static func section(title: String, en := "", right := "") -> Array:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var blk := ColorRect.new()
	blk.color = AMBER
	blk.custom_minimum_size = Vector2(4, 4)
	blk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(blk)
	h.add_child(UI.label(title, 12, CREAM))
	if en != "":
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
		f.add_child(UI.label("已满级", 12, UI.GOOD))
		return f
	for p in parts:
		var ok: bool = int(p.have) >= int(p.need)
		var t := ""
		if str(p.id) == "money":
			t = "¥%s" % _money_text(int(p.need))
		else:
			t = "%s %d/%d" % [str(item_name.call(str(p.id))), int(p.have), int(p.need)]
		f.add_child(UI.label(t, 12, (Color(1.0, 0.85, 0.4) if str(p.id) == "money" else UI.TEXT) if ok else UI.BAD))
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
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.42, 0.28))
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
		v.add_child(req_row("已满级", "", true))
		return v
	for p in parts:
		var ok: bool = int(p.have) >= int(p.need)
		if str(p.id) == "money":
			v.add_child(req_row("信用点", "¥%s" % _money_text(int(p.need)), ok))
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
static var _re_model: RegEx


static func short_name(id: String) -> String:
	var gd = Engine.get_main_loop().root.get_node_or_null("GameData")
	var base := id if gd == null else str(gd.base_id(id))
	if gd != null:
		var it: Dictionary = gd.item(id)
		if it.has("short"):
			return str(it.short)
	if ABBR.has(base):
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
	n = re.sub(n.replace("旧世界", ""), "", true).strip_edges()
	return n.substr(0, 3)


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
		custom_minimum_size = Vector2(8, 2)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if solid:
			draw_rect(Rect2(0, 0, size.x, 1), Color(0.25, 0.26, 0.225))
			return
		var x := 0.0
		while x < size.x:
			draw_rect(Rect2(x, 0, 2, 2), color)
			x += 4.0


## 等级刻度：max 个方块，前 level 个点亮
class Pips extends Control:
	var level := 0
	var max_level := 5
	var on_c := Color(1.0, 0.69, 0.13)

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
			draw_rect(r, Color(0, 0, 0, 0.7))
			draw_rect(r.grow(-2), on_c if i < level else Color(1, 1, 1, 0.12))


## 像素进度条（经验）
class PixBar extends Control:
	var frac := 0.0
	var color := Color(1.0, 0.69, 0.13)

	func _init(h := 8) -> void:
		custom_minimum_size = Vector2(40, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func set_frac(f: float) -> void:
		frac = clampf(f, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.75))
		var inner := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		draw_rect(inner, Color(1, 1, 1, 0.08))
		var w := floorf(inner.size.x * frac / 2.0) * 2.0
		draw_rect(Rect2(inner.position, Vector2(w, inner.size.y)), color)
		var x := inner.position.x + 8.0
		while x < inner.end.x:
			draw_rect(Rect2(x, inner.position.y, 2, inner.size.y), Color(0, 0, 0, 0.35))
			x += 10.0


## 像素头像框：底色 + 头像（最近邻）+ 九宫格框；state: "n" 普通 / "on" 选中 / "lead" 主角
class Avatar extends Control:
	var char_id := ""
	var tex: Texture2D
	var state := "n"
	var dim := false
	var _frames := {}

	func _init(px := 48, id := "", st := "n") -> void:
		## px 为头像内容边长（逻辑像素，40 / 96 / 128 与贴图像素格对齐）；框体额外占 6px 一圈
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

	func _frame() -> StyleBoxTexture:
		var n := "avf9" if state == "n" else ("avf9_on" if state == "on" else "avf9_lead")
		if not _frames.has(n):
			var sb := StyleBoxTexture.new()
			sb.texture = load("res://assets/ui/%s.png" % n)
			sb.set_texture_margin_all(8)
			sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
			sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
			_frames[n] = sb
		return _frames[n]

	func _draw() -> void:
		var r := Rect2(Vector2(6, 6), size - Vector2(12, 12))
		var tint: Color = load("res://scripts/hub_kit.gd").TINT.get(char_id, Color(0.3, 0.3, 0.32))
		draw_rect(r, tint.darkened(0.55))
		# 底色上的像素斜纹
		var y := r.position.y
		while y < r.end.y:
			draw_rect(Rect2(r.position.x, y, r.size.x, 2), Color(tint.r, tint.g, tint.b, 0.18))
			y += 6.0
		if tex:
			draw_texture_rect(tex, r, false, Color(1, 1, 1, 0.45 if dim else 1.0))
		draw_style_box(_frame(), Rect2(Vector2.ZERO, size))


# ---------------------------------------------------------------- 物品格
## 画一个物品格：e = {id, count, price, dim, bad, label}；e 为空时画空格。state：0 普通 / 1 悬停 / 2 选中
## 底板按稀有度取 cell9_r0..r3；bad（不满足要求，如钱不够）叠红色斜纹框；选中 / 悬停叠琥珀 / 米白角框。
static func draw_cell(ci: CanvasItem, r: Rect2, e: Dictionary, font: Font, state := 0) -> void:
	if e.is_empty():
		ci.draw_style_box(px9("cell9_empty", 6), r)
		if state == 1:
			ci.draw_style_box(px9("cell9_hover", 8), r)
		return
	var gd = Engine.get_main_loop().root.get_node("GameData")
	var id := str(e.get("id", ""))
	var it: Dictionary = gd.item(id)
	var rar := clampi(int(it.get("rar", 0)), 0, 3)
	ci.draw_style_box(px9("cell9_r%d" % rar, 6), r)
	var tex: Texture2D = load("res://scripts/item_icons.gd").icon(id)
	if tex:
		var side := minf(r.size.x, r.size.y)
		var sc := 2 if side < 72.0 else maxi(2, int(floor((side - 24.0) / 16.0)))
		var isz := Vector2(16 * sc, 16 * sc)
		var ip := (r.position + (r.size - isz) * 0.5 + Vector2(0, 3)).floor()
		ip = Vector2(floorf(ip.x / 2.0) * 2.0, floorf(ip.y / 2.0) * 2.0)
		ci.draw_texture_rect(tex, Rect2(ip, isz), false, Color(1, 1, 1, 0.45 if e.get("dim", false) else 1.0))
	var asc := font.get_ascent(12)
	var tw := r.size.x - 8
	var nm := fit_text(font, str(e.get("label", short_name(id))), tw)
	ci.draw_string(font, r.position + Vector2(5, 4 + asc), nm, HORIZONTAL_ALIGNMENT_LEFT, tw, 12, Color(0, 0, 0, 0.85))
	ci.draw_string(font, r.position + Vector2(4, 3 + asc), nm, HORIZONTAL_ALIGNMENT_LEFT, tw, 12, CREAM)
	var by := r.end.y - 3 - font.get_descent(12)
	if e.has("price"):
		var pt := "¥%s" % _money_text(int(e.price))
		var pc := Color(1.0, 0.82, 0.4) if not e.get("bad", false) else Color(1.0, 0.55, 0.48)
		ci.draw_string(font, Vector2(r.position.x + 4, by + 1), pt, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 7, 12, Color(0, 0, 0, 0.85))
		ci.draw_string(font, Vector2(r.position.x + 3, by), pt, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 7, 12, pc)
	elif int(e.get("count", 1)) > 1:
		var ct := str(int(e.count))
		ci.draw_string(font, Vector2(r.position.x + 3, by + 1), ct, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 7, 12, Color(0, 0, 0, 0.85))
		ci.draw_string(font, Vector2(r.position.x + 2, by), ct, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 7, 12, Color(1, 1, 1))
	if e.get("dim", false):
		ci.draw_rect(r.grow(-2), Color(0, 0, 0, 0.35))
	if e.get("bad", false):
		ci.draw_style_box(px9("cell9_bad", 8), r)
	if state == 2:
		ci.draw_style_box(px9("cell9_sel", 8), r)
	elif state == 1:
		ci.draw_style_box(px9("cell9_hover", 8), r)


## 等大正方格物品网格（塔科夫式仓库）：列数随宽度自适应，空位也画出格子；
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
	var min_rows := 1
	var tip_fn: Callable
	var drag_kind := ""
	var accept_drop: Callable
	var on_drop: Callable
	var empty_text := ""
	var _ox := 0.0

	func _init(cell_px := 48) -> void:
		cell = cell_px
		mouse_filter = Control.MOUSE_FILTER_STOP
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(cell, cell)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

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
		elif what == NOTIFICATION_MOUSE_EXIT and hover != -1:
			hover = -1
			queue_redraw()

	func _relayout() -> void:
		var c := maxi(1, int(floor(size.x / cell)))
		if size.x < 1.0:
			c = maxi(1, int(floor(custom_minimum_size.x / cell)))
		cols = c
		_ox = floor((size.x - cols * cell) * 0.5) if size.x > 0 else 0.0
		var rows := maxi(min_rows, int(ceil(float(entries.size()) / cols)))
		var h := float(rows * cell)
		if absf(custom_minimum_size.y - h) > 0.5:
			custom_minimum_size.y = h
		queue_redraw()

	func index_at(p: Vector2) -> int:
		var c := int(floor((p.x - _ox) / cell))
		var r := int(floor(p.y / cell))
		if c < 0 or c >= cols or r < 0:
			return -1
		var i := r * cols + c
		return i if i < entries.size() else -1

	func _cell_rect(i: int) -> Rect2:
		return Rect2(_ox + (i % cols) * cell, floor(i / cols) * cell, cell, cell)

	func _draw() -> void:
		var font := get_theme_default_font()
		var rows := maxi(int(ceil(size.y / cell)), int(ceil(float(entries.size()) / cols)))
		var total := rows * cols
		# 网格外框（凹槽内衬）
		draw_rect(Rect2(_ox, 0, cols * cell, rows * cell), Color(0.02, 0.022, 0.02, 0.9))
		for i in total:
			var e: Dictionary = entries[i] if i < entries.size() else {}
			var st := 2 if i == selected else (1 if i == hover else 0)
			var r := _cell_rect(i)
			r = Rect2(r.position + Vector2(1, 1), r.size - Vector2(1, 1)) if not e.is_empty() else r
			load("res://scripts/hub_kit.gd").draw_cell(self, r, e, font, st)
		draw_rect(Rect2(_ox, 0, cols * cell, rows * cell), Color(0.03, 0.03, 0.035), false, 1.0)
		if entries.is_empty() and empty_text != "":
			draw_string(font, Vector2(_ox + 8, cell * 0.5 + 4), empty_text, HORIZONTAL_ALIGNMENT_LEFT, cols * cell - 16, 12, Color(0.55, 0.54, 0.47))

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
				selected = i
				queue_redraw()
				if ev.double_click:
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
		var pv := TextureRect.new()
		pv.texture = load("res://scripts/item_icons.gd").icon(str(e.id))
		pv.custom_minimum_size = Vector2(32, 32)
		pv.size = Vector2(32, 32)
		pv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pv.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		set_drag_preview(pv)
		return {"kind": drag_kind, "id": str(e.id), "index": i}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return accept_drop.is_valid() and data is Dictionary and bool(accept_drop.call(data))

	func _drop_data(_at: Vector2, data: Variant) -> void:
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
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	func set_entry(e: Dictionary) -> void:
		entry = e
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if entry.is_empty():
			draw_style_box(load("res://scripts/hub_kit.gd").px9("slot9_empty", 6), r)
			return
		load("res://scripts/hub_kit.gd").draw_cell(self, r, entry, get_theme_default_font(), 2 if hl else 0)

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
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
			icon_rect = K.icon_rect(tex, 40)
			icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(icon_rect)
		cn_lbl = Label.new()
		cn_lbl.text = cn
		cn_lbl.add_theme_font_size_override("font_size", 12)
		cn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cn_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(cn_lbl)
		en_lbl = Label.new()
		en_lbl.text = en_text
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

	func _draw() -> void:
		var c := size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 2.0
		var on := button_pressed
		var fill: Color = BG2
		if button_down:
			fill = BG0
		elif _hot:
			fill = BG3
		# 外圈：选中琥珀，悬停亮描边，常态橄榄灰
		_disc(c, r, AMBER if on else (LINE2 if _hot else LINE))
		_disc(c, r - 2.0, fill)
		if on:
			_disc(c, r - 5.0, AMBER_DK)
			_disc(c, r - 7.0, fill)
		# 四个方向的短齿，像素感与页签描边呼应
		for a in [0.0, PI * 0.5, PI, PI * 1.5]:
			var d := Vector2(cos(a), sin(a))
			var t := c + d * (r - 1.0)
			draw_rect(Rect2(t.x - 3, t.y - 3, 6, 6), Color(0.04, 0.04, 0.05))

	func _tint() -> void:
		var on := button_pressed
		cn_lbl.add_theme_color_override("font_color", AMBER if on else CREAM)
		en_lbl.add_theme_color_override("font_color", AMBER_DK if on else CREAM_DIM)
		if icon_rect:
			icon_rect.modulate = Color(1, 1, 1) if on else Color(0.8, 0.8, 0.76)
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
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
		cn_lbl = Label.new()
		cn_lbl.text = cn
		cn_lbl.add_theme_font_size_override("font_size", 12)
		cn_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cn_lbl.name = "CN"
		v.add_child(cn_lbl)
		en_lbl = Label.new()
		en_lbl.text = en_text
		en_lbl.add_theme_font_size_override("font_size", 12)
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
		cn_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4) if on else Color(0.86, 0.84, 0.75))
		en_lbl.add_theme_color_override("font_color", Color(0.75, 0.55, 0.2) if on else Color(0.45, 0.44, 0.39))
		if icon_rect:
			icon_rect.modulate = Color(1, 1, 1) if on else Color(0.78, 0.78, 0.74)
