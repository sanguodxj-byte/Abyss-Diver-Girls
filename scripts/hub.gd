extends Control
## 飞空艇「信天翁号」主界面：二级菜单导航（整备 / 交易 / 降落 / 仓库 / 图鉴）
## 3D 机库背景 + 像素风格 UI，全面兼容自动化测试与全流程巡览。

signal deploy_requested

const MV = preload("res://scripts/mech_visual.gd")
const A = preload("res://scripts/art.gd")
const UI = preload("res://scripts/ui.gd")
const HUD = preload("res://scripts/hud.gd")
const Growth = preload("res://scripts/progression/growth.gd")
const AssetPaths = preload("res://scripts/asset_paths.gd")

## 3D 机库背景与转台
var preview_root: Node3D
var preview_mech: Node3D
var turntable: Node3D
var preview_cam: Camera3D
var hangar_vp: SubViewport
var drag := false
var spin := 0.0
var exploded := false

## 顶栏与全局状态
var money_lbl: Label
var record_lbl: Label
var nav_buttons := {}
var cur_tab := "maintenance"

## 视图容器
var views := {}

## 整备视图（机甲装配、性能统计、拆解图）
var slot_buttons := {}
var slot_name_lbls := {}
var slot_stat_lbls := {}
var stat_rows := {}
var explode_btn: Button
var popup: PopupMenu
var popup_slot := ""
var popup_map := {}

## 交易视图（6位黑市商人、商人物资、委托提交）
var merchant_buttons := {}
var cur_merchant := "ajin"
var merchant_portrait: TextureRect
var merchant_name_lbl: Label
var merchant_role_lbl: Label
var merchant_desc_lbl: Label
var shop_list: ItemList
var shop_ids: Array = []
var selected_shop := -1
var request_lbl: Label
var shop_detail_lbl: Label

## 降落视图（战区选择、出击货舱、空投出击）
var map_buttons := {}
var map_title_lbl: Label
var map_tag_lbl: Label
var map_desc_lbl: Label
var map_hazard_lbl: Label
var cargo_list: ItemList
var cargo_lbl: Label
var deploy_stash_list: ItemList
var deploy_stash_ids: Array = []
var deploy_btn: Button
var deploy_err: Label

## 仓库视图（独立大仓库、分类筛选、物资出售与装载）
var stash_list: ItemList
var stash_ids: Array = []
var selected_stash := ""
var stash_filter := "all"
var stash_detail_lbl: Label
var stash_icon_rect: TextureRect
var stash_count_lbl: Label

## 图鉴视图（船员档案、机甲图鉴、深渊异体、战区档案）
var codex_tab := "crew"
var codex_list: ItemList
var codex_ids: Array = []
var codex_portrait: TextureRect
var codex_title_lbl: Label
var codex_sub_lbl: Label
var codex_detail_lbl: Label
var codex_stat_grid: GridContainer

## 6位黑市商人配置
const MERCHANTS := {
	"ajin": {
		"name": "阿堇",
		"role": "黑市杂货与生活物资商",
		"desc": "在废土穿浅色毛衣且不沾灰。掌管生活物资与日常消耗品走私，计算细致分文不差。",
		"items": ["can_food", "biscuit", "water_tab", "coffee", "fuel_cell", "repair_kit"]
	},
	"xiaoman": {
		"name": "小满",
		"role": "战地军火与废铁倒爷",
		"desc": "在战区废墟扒装备起家的二道贩子。脾气冲、心气高，专营成品枪械与实战常规武器模块。",
		"items": ["arm_mg", "arm_shotgun", "arm_flamer", "arm_laser", "wire", "bolts"]
	},
	"shiori": {
		"name": "诗织",
		"role": "违禁生物与深渊样本商",
		"desc": "覆灭研究所的幸存学者。收购异化甲壳与虫晶活体样本，出售特种生物制剂与异化插件。",
		"items": ["chitin", "bug_crystal", "coolant_pack", "surge_cell"]
	},
	"karasu": {
		"name": "鸦",
		"role": "重型装甲与特种弹药匠",
		"desc": "地下工坊老铁匠。追求极端防护厚度与大口径穿甲杀伤，专营防爆装甲与重型工业模块。",
		"items": ["core_heavy", "legs_tread", "back_shield", "extract_barrier"]
	},
	"nihong": {
		"name": "霓虹",
		"role": "旧时代电子残骸与黑客情报商",
		"desc": "防空洞基站网瘾电波系。解码旧时代黑匣子与火控芯片，提供战区雷达情报与战术诱饵。",
		"items": ["circuit", "hdd", "sonic_decoy", "beacon", "extract_flare"]
	},
	"gin": {
		"name": "银",
		"role": "灰烬商会账房与高危悬赏庄家",
		"desc": "灰烬走私财团未成年买办。左眼佩戴黄铜单片镜，专营高危死地悬赏与顶级特种机甲配额。",
		"items": ["credit_s", "credit_l", "gold", "gen_crystal", "legs_hover", "back_missile", "energy_rod"]
	}
}

## 图鉴角色档案（11 人）
const CHAR_PROFILES := {
	"nao": {
		"name": "奈绪 · 白石 奈緒",
		"role": "主力机甲驾驶员（玩家操控） · 16岁",
		"desc": "银灰长发别着金属旧发卡，身穿旧双翼骷髅徽记高领服。三无寡言，极度省电，无既往归属意识。战斗精准冷静，对感兴趣的小物件有奇特专注力。"
	},
	"rei": {
		"name": "零 · 久遠 零",
		"role": "机甲驾驶员（AI 队友） · 16岁",
		"desc": "银白短发遮盖左眼，领口焊有蓝光单目镜头，胸前挂着三枚死难战友的狗牌。性格孤僻寡言，习惯在镜头后观察，极度看重当前小队成员的安全。"
	},
	"kurumi": {
		"name": "胡桃 · 百瀬 くるみ",
		"role": "机甲驾驶员（AI 队友） · 15~16岁",
		"desc": "栗棕双马尾用黄色塑料工业扎带绑扎，鼻梁贴创可贴，亮橙工装。野路子出身，喜爱在战场捡拾废旧零件，性格活泼好胜，易害羞但极其勇猛。"
	},
	"lina": {
		"name": "莉娜 · リナ・クラウゼ",
		"role": "运输机「格里芬」驾驶员 · 17岁",
		"desc": "金短发、黑框眼镜、制服笔挺的前正规军校学员。负责后勤与战区撤离接应，平日教条爱念叨，但在极端战场危险下坚决死守悬停接回全员。"
	},
	"laojiao": {
		"name": "米娅 · ミア",
		"role": "机库整备师 · 16岁",
		"desc": "暗红低丸子头，头戴铆钉铁皮电焊面罩，口袋塞防烫手套，脸带油印。重度缺觉但技术精湛，极度珍爱机甲，视每台受损机体为必须修复的孩子。"
	},
	"ajin": {
		"name": "阿堇 · 蘇 菫",
		"role": "黑市杂货与生活物资商",
		"desc": "温和细致的黑市杂货商人。供应热食罐头、净水耗材与基础零件，在废土商圈拥有极广的生活物资渠道网络。"
	},
	"xiaoman": {
		"name": "小满 · 林 小満",
		"role": "战地军火与废铁倒爷",
		"desc": "黄色猫眼、飞行夹克二道贩子。专营战场搜刮二手火器、制式枪械与标准弹药，交易直接爽快。"
	},
	"shiori": {
		"name": "诗织 · 天城 詩織",
		"role": "违禁生物与深渊样本商",
		"desc": "前深渊生物研究所学者。肩趴发光异化甲虫，收购变异生物组织与核心虫晶，提供生物异化涂层。"
	},
	"karasu": {
		"name": "鸦 · 鴉",
		"role": "重型装甲与特种弹药匠",
		"desc": "地下私造工坊匠人。身着防爆帆布背心，胸挂重型弹壳，专精极限厚度装甲锻造与重型反甲弹药熔铸。"
	},
	"nihong": {
		"name": "霓虹 · ネオン",
		"role": "旧时代电子残骸与黑客情报商",
		"desc": "基站机房电波系黑客。挂耳式监听耳机与发光排线，收购旧时代硬盘与黑匣子，输出高价值电子战与侦察情报。"
	},
	"gin": {
		"name": "银 · 銀",
		"role": "灰烬商会账房与高危悬赏庄家",
		"desc": "灰烬走私财团未成年买办。单片黄铜放大镜与深红丝绒马甲，派发高危死地委托，兑换贵重货币与稀有机甲配额。"
	}
}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	_build_hangar()
	_build_top_bar()

	var content := Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_top = 56
	content.offset_bottom = -38
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)

	_build_maintenance_view(content)
	_build_trade_view(content)
	_build_deploy_view(content)
	_build_stash_view(content)
	_build_codex_view(content)

	_build_bottom_bar()

	popup = PopupMenu.new()
	popup.set_meta("sfx", "")
	popup.id_pressed.connect(_on_popup)
	add_child(popup)

	_switch_tab("maintenance")
	refresh()


# ============================================================ 顶栏与二级菜单导航
func _build_top_bar() -> void:
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UI.box(Color(0.03, 0.035, 0.05, 0.88), Color(0, 0, 0, 0), 0, 0, UI.ACCENT, 0, 10))
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 54
	add_child(top)

	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 12)
	top.add_child(th)

	var logo := ColorRect.new()
	logo.color = UI.ACCENT
	logo.custom_minimum_size = Vector2(6, 0)
	th.add_child(logo)

	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -2)
	th.add_child(tv)
	tv.add_child(UI.label("信天翁号", 18, Color(1.0, 0.88, 0.66)))
	tv.add_child(UI.label("ABYSS DIVER GIRLS", 10, UI.MUTED))

	var div1 := ColorRect.new()
	div1.color = Color(1, 1, 1, 0.1)
	div1.custom_minimum_size = Vector2(1, 24)
	div1.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(div1)

	var nav_grp := ButtonGroup.new()
	var tabs_def := [
		["maintenance", "整备"],
		["trade", "交易"],
		["deploy", "降落"],
		["stash", "仓库"],
		["codex", "图鉴"]
	]
	for td in tabs_def:
		var key: String = td[0]
		var label_str: String = td[1]
		var btn := Button.new()
		btn.text = label_str
		btn.toggle_mode = true
		btn.button_group = nav_grp
		btn.custom_minimum_size = Vector2(86, 36)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(func(): _switch_tab(key))
		nav_buttons[key] = btn
		th.add_child(btn)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(sp)

	var qb := Button.new()
	qb.text = "画质：%s" % GameData.QUALITY_NAMES[GameData.quality]
	qb.tooltip_text = "流畅：MSAA 2x + FXAA\n高：MSAA 4x + FXAA + TAA\n极致：MSAA 4x + TAA + 1.5 倍超采样"
	qb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	qb.focus_mode = Control.FOCUS_NONE
	qb.pressed.connect(func():
		GameData.quality = (GameData.quality + 1) % 3
		GameData.apply_quality(get_viewport())
		if hangar_vp:
			GameData.apply_quality(hangar_vp)
		qb.text = "画质：%s" % GameData.QUALITY_NAMES[GameData.quality]
		GameData.save_game())
	th.add_child(qb)

	record_lbl = UI.label("", 13, UI.MUTED)
	record_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(record_lbl)

	var mp := PanelContainer.new()
	mp.add_theme_stylebox_override("panel", UI.box(Color(1.0, 0.6, 0.16, 0.12), UI.ACCENT_DIM, 1, 0, UI.ACCENT, 3, 10))
	th.add_child(mp)
	money_lbl = UI.label("", 17, Color(1.0, 0.85, 0.4))
	mp.add_child(money_lbl)

	var stripe := ColorRect.new()
	stripe.color = UI.ACCENT_DIM
	stripe.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	stripe.offset_top = 54
	stripe.offset_bottom = 56
	add_child(stripe)


func _switch_tab(tab_key: String) -> void:
	cur_tab = tab_key
	for k in nav_buttons:
		nav_buttons[k].button_pressed = (k == tab_key)
	for k in views:
		views[k].visible = (k == tab_key)
	if explode_btn:
		explode_btn.visible = (tab_key == "maintenance")
	Audio.play_ui("ui_tab")
	refresh()


# ============================================================ 底栏：电台对白
func _build_bottom_bar() -> void:
	var radio := PanelContainer.new()
	radio.add_theme_stylebox_override("panel", UI.box(Color(0.03, 0.04, 0.05, 0.78), Color(0, 0, 0, 0), 0, 0, UI.ACCENT, 3, 8))
	radio.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	radio.offset_bottom = -8
	radio.grow_horizontal = Control.GROW_DIRECTION_BOTH
	radio.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(radio)

	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", 8)
	radio.add_child(rh)
	rh.add_child(UI.label("◆ 电台", 12, UI.INFO))
	rh.add_child(UI.label(GameData.DISPATCH_LINES[randi() % GameData.DISPATCH_LINES.size()], 13, Color(0.78, 0.82, 0.86)))


# ============================================================ 1. 整备视图
func _build_maintenance_view(parent: Control) -> void:
	var v_m := Control.new()
	v_m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v_m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(v_m)
	views["maintenance"] = v_m

	explode_btn = Button.new()
	explode_btn.text = "◇ 拆解视图"
	explode_btn.custom_minimum_size = Vector2(150, 34)
	explode_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	explode_btn.offset_top = 18
	explode_btn.offset_bottom = 52
	explode_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	explode_btn.set_meta("sfx", "")
	explode_btn.pressed.connect(_toggle_explode)
	v_m.add_child(explode_btn)

	var p_left := UI.panel(12)
	p_left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	p_left.offset_left = 16
	p_left.offset_top = 16
	p_left.offset_bottom = -16
	p_left.offset_right = 16 + 330
	v_m.add_child(p_left)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p_left.add_child(v)
	v.add_child(UI.header("机甲组装"))

	for slot in GameData.SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 48)
		b.pressed.connect(_open_slot_menu.bind(slot))
		v.add_child(b)
		var m := MarginContainer.new()
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_theme_constant_override("margin_left", 10)
		m.add_theme_constant_override("margin_right", 10)
		m.add_theme_constant_override("margin_top", 4)
		m.add_theme_constant_override("margin_bottom", 4)
		b.add_child(m)
		var bv := VBoxContainer.new()
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_theme_constant_override("separation", -1)
		m.add_child(bv)
		var top_row := HBoxContainer.new()
		top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(top_row)
		var sl := UI.label(GameData.SLOT_NAMES[slot], 11, UI.MUTED)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(sl)
		var st := UI.label("", 11, UI.MUTED)
		top_row.add_child(st)
		var nl := UI.label("", 15)
		bv.add_child(nl)
		slot_buttons[slot] = b
		slot_name_lbls[slot] = nl
		slot_stat_lbls[slot] = st

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	v.add_child(gap)
	v.add_child(UI.header("机体性能", "", 14))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	for k in [["hp", "结构", UI.HP_C], ["energy", "能源", UI.EN_C], ["speed", "速度", UI.INFO], ["load", "承重", Color(0.75, 0.6, 1.0)], ["cargo", "货舱", UI.GOOD]]:
		grid.add_child(UI.label(k[1], 12, UI.MUTED))
		var bar = UI.SegBar.new(k[2], 16, 8.0)
		bar.custom_minimum_size = Vector2(160, 8)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(bar)
		var val := UI.label("", 12)
		val.custom_minimum_size = Vector2(76, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(val)
		stat_rows[k[0]] = [bar, val]

	var p_right := UI.panel(12)
	p_right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	p_right.offset_right = -16
	p_right.offset_top = 16
	p_right.offset_bottom = -16
	p_right.offset_left = -16 - 320
	v_m.add_child(p_right)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 10)
	p_right.add_child(rv)
	rv.add_child(UI.header("整备维护"))

	var info_p := PanelContainer.new()
	info_p.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.1), 1, 0, UI.ACCENT, 0, 10))
	rv.add_child(info_p)
	var info_v := VBoxContainer.new()
	info_v.add_theme_constant_override("separation", 6)
	info_p.add_child(info_v)
	info_v.add_child(UI.label("信天翁号 · 机库整备台", 14, UI.INFO))
	info_v.add_child(UI.label("机械师：米娅", 12, UI.MUTED))

	var act_box := VBoxContainer.new()
	act_box.add_theme_constant_override("separation", 8)
	rv.add_child(act_box)
	_btn(act_box, "领取应急机架", _starter_frame)
	_btn(act_box, "卸下全部模块", _strip_all_modules)

	var rsp := Control.new()
	rsp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(rsp)


# ============================================================ 2. 交易视图（6位黑市商人）
func _build_trade_view(parent: Control) -> void:
	var v_t := Control.new()
	v_t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v_t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(v_t)
	views["trade"] = v_t

	var p_left := UI.panel(12)
	p_left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	p_left.offset_left = 16
	p_left.offset_top = 16
	p_left.offset_bottom = -16
	p_left.offset_right = 16 + 280
	v_t.add_child(p_left)

	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	p_left.add_child(lv)
	lv.add_child(UI.header("黑市商铺"))

	var m_grp := ButtonGroup.new()
	for m_id in ["ajin", "xiaoman", "shiori", "karasu", "nihong", "gin"]:
		var m_data: Dictionary = MERCHANTS[m_id]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = m_grp
		b.text = "%s  %s" % [m_data.name, m_data.role]
		b.clip_text = true
		b.custom_minimum_size = Vector2(0, 36)
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(func(): _select_merchant(m_id))
		merchant_buttons[m_id] = b
		lv.add_child(b)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	lv.add_child(gap)
	lv.add_child(UI.header("后勤委托", "", 14))

	var rp := PanelContainer.new()
	rp.add_theme_stylebox_override("panel", UI.box(Color(0.45, 0.85, 1.0, 0.06), Color(0.45, 0.85, 1.0, 0.25), 1, 0, UI.ACCENT, 3, 10))
	lv.add_child(rp)
	request_lbl = UI.label("", 13, Color(0.75, 0.92, 1.0))
	request_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rp.add_child(request_lbl)

	_btn(lv, "提交委托", func():
		if GameData.fulfill_request():
			Audio.play_ui("request_complete")
			refresh()
		else:
			Audio.play_ui("ui_denied"))

	var p_right := UI.panel(12)
	p_right.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p_right.offset_left = 16 + 280 + 12
	p_right.offset_top = 16
	p_right.offset_bottom = -16
	p_right.offset_right = -16
	v_t.add_child(p_right)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	p_right.add_child(rv)

	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.1), 1, 0, UI.ACCENT, 0, 8))
	rv.add_child(banner)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 14)
	banner.add_child(bh)

	merchant_portrait = TextureRect.new()
	merchant_portrait.custom_minimum_size = Vector2(80, 80)
	merchant_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	merchant_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	merchant_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bh.add_child(merchant_portrait)

	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 2)
	bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(bv)
	merchant_name_lbl = UI.label("", 18, UI.ACCENT)
	bv.add_child(merchant_name_lbl)
	merchant_role_lbl = UI.label("", 12, UI.MUTED)
	bv.add_child(merchant_role_lbl)
	merchant_desc_lbl = UI.label("", 12, Color(0.8, 0.82, 0.85))
	merchant_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bv.add_child(merchant_desc_lbl)

	rv.add_child(UI.header("供货清单", "", 14))

	shop_list = _list()
	shop_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_list.item_selected.connect(func(i):
		selected_shop = i
		_on_shop_selected(i))
	shop_list.item_activated.connect(_buy)
	rv.add_child(shop_list)

	var bot_h := HBoxContainer.new()
	bot_h.add_theme_constant_override("separation", 10)
	rv.add_child(bot_h)
	shop_detail_lbl = UI.label("", 12, UI.MUTED)
	shop_detail_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bot_h.add_child(shop_detail_lbl)

	var buy_b := _btn(bot_h, "购买选中", func():
		if selected_shop >= 0:
			_buy(selected_shop)
		else:
			Audio.play_ui("ui_denied"))
	buy_b.custom_minimum_size = Vector2(140, 36)


func _select_merchant(m_id: String) -> void:
	cur_merchant = m_id
	selected_shop = -1
	for k in merchant_buttons:
		merchant_buttons[k].button_pressed = (k == m_id)
	var md: Dictionary = MERCHANTS.get(m_id, {})
	merchant_name_lbl.text = md.get("name", "")
	merchant_role_lbl.text = md.get("role", "")
	merchant_desc_lbl.text = md.get("desc", "")
	merchant_portrait.texture = AssetPaths.portrait(m_id)
	Audio.play_ui("ui_tab")
	refresh()


func _on_shop_selected(idx: int) -> void:
	if idx < 0 or idx >= shop_ids.size():
		shop_detail_lbl.text = ""
		return
	var id: String = shop_ids[idx]
	var it := GameData.item(id)
	shop_detail_lbl.text = "%s  ·  %.1fkg  ·  %s" % [it.name, float(it.w), Growth.subst(str(it.get("desc", "")))]


# ============================================================ 3. 降落视图（大地图出击）
func _build_deploy_view(parent: Control) -> void:
	var v_d := Control.new()
	v_d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v_d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(v_d)
	views["deploy"] = v_d

	var p_left := UI.panel(12)
	p_left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	p_left.offset_left = 16
	p_left.offset_top = 16
	p_left.offset_bottom = -16
	p_left.offset_right = 16 + 460
	v_d.add_child(p_left)

	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	p_left.add_child(lv)
	lv.add_child(UI.header("出击战区"))

	var map_grp := ButtonGroup.new()
	var map_grid := GridContainer.new()
	map_grid.columns = 2
	map_grid.add_theme_constant_override("h_separation", 6)
	map_grid.add_theme_constant_override("v_separation", 6)
	lv.add_child(map_grid)

	for id: String in GameData.map_ids():
		var md: Dictionary = GameData.MAPS[id]
		var b := Button.new()
		b.disabled = not GameData.map_available(id)
		b.toggle_mode = true
		b.button_group = map_grp
		b.text = md.name
		b.clip_text = true
		b.custom_minimum_size = Vector2(210, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 14)
		b.button_pressed = (id == GameData.map_id)
		b.toggled.connect(func(on: bool):
			if on:
				GameData.map_id = id
				_update_map_detail())
		map_buttons[id] = b
		map_grid.add_child(b)

	var dp := PanelContainer.new()
	dp.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.1), 1, 0, UI.ACCENT, 0, 10))
	dp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(dp)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	dp.add_child(dv)

	map_title_lbl = UI.label("", 17, UI.ACCENT)
	dv.add_child(map_title_lbl)
	map_tag_lbl = UI.label("", 12, UI.INFO)
	dv.add_child(map_tag_lbl)
	map_desc_lbl = UI.label("", 13, Color(0.85, 0.88, 0.9))
	map_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(map_desc_lbl)
	map_hazard_lbl = UI.label("", 12, UI.MUTED)
	map_hazard_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(map_hazard_lbl)
	_update_map_detail()

	var p_right := UI.panel(12)
	p_right.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p_right.offset_left = 16 + 460 + 12
	p_right.offset_top = 16
	p_right.offset_bottom = -16
	p_right.offset_right = -16
	v_d.add_child(p_right)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	p_right.add_child(rv)

	var hh := HBoxContainer.new()
	rv.add_child(hh)
	hh.add_child(UI.header("出击货舱", "", 15))
	cargo_lbl = UI.label("", 12, UI.MUTED)
	cargo_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cargo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hh.add_child(cargo_lbl)

	cargo_list = _list()
	cargo_list.custom_minimum_size = Vector2(0, 140)
	cargo_list.max_text_lines = 1
	cargo_list.item_activated.connect(_cargo_back)
	rv.add_child(cargo_list)

	rv.add_child(UI.header("备战物资", "", 14))

	deploy_stash_list = _list()
	deploy_stash_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deploy_stash_list.item_activated.connect(func(i):
		if i >= 0 and i < deploy_stash_ids.size():
			selected_stash = deploy_stash_ids[i]
			_move_to_cargo())
	rv.add_child(deploy_stash_list)

	var load_b := _btn(rv, "装入出击货舱", func():
		var sel := deploy_stash_list.get_selected_items()
		if not sel.is_empty() and sel[0] < deploy_stash_ids.size():
			selected_stash = deploy_stash_ids[sel[0]]
			_move_to_cargo())
	load_b.custom_minimum_size = Vector2(0, 32)

	deploy_err = UI.label("", 13, UI.BAD)
	deploy_err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(deploy_err)

	deploy_btn = Button.new()
	deploy_btn.text = "▼  空投出击"
	deploy_btn.custom_minimum_size = Vector2(0, 52)
	deploy_btn.add_theme_font_size_override("font_size", 20)
	deploy_btn.add_theme_stylebox_override("normal", UI.box(Color(0.85, 0.48, 0.1, 0.95), Color(1, 0.75, 0.4), 1, 0, UI.ACCENT, 3, 12))
	deploy_btn.add_theme_stylebox_override("hover", UI.box(Color(1.0, 0.58, 0.16, 1.0), Color(1, 0.85, 0.6), 1, 0, UI.ACCENT, 3, 12))
	deploy_btn.add_theme_stylebox_override("pressed", UI.box(Color(0.7, 0.38, 0.08, 1.0), Color(1, 0.75, 0.4), 1, 0, UI.ACCENT, 3, 12))
	deploy_btn.add_theme_color_override("font_color", Color(0.08, 0.05, 0.02))
	deploy_btn.add_theme_color_override("font_hover_color", Color(0.05, 0.03, 0.0))
	deploy_btn.set_meta("sfx", "ui_confirm")
	deploy_btn.pressed.connect(func(): deploy_requested.emit())
	rv.add_child(deploy_btn)


func _update_map_detail() -> void:
	var md: Dictionary = GameData.map_data(GameData.map_id)
	map_title_lbl.text = md.get("name", "")
	map_tag_lbl.text = md.get("tag", "")
	map_desc_lbl.text = md.get("desc", "")
	var env_str: String = md.get("env", "")
	map_hazard_lbl.text = ("环境态势：%s" % env_str) if env_str != "" else ""


# ============================================================ 4. 仓库视图
func _build_stash_view(parent: Control) -> void:
	var v_s := Control.new()
	v_s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v_s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(v_s)
	views["stash"] = v_s

	var p_left := UI.panel(12)
	p_left.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p_left.offset_left = 16
	p_left.offset_top = 16
	p_left.offset_bottom = -16
	p_left.offset_right = -16 - 360
	v_s.add_child(p_left)

	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	p_left.add_child(lv)

	var top_h := HBoxContainer.new()
	lv.add_child(top_h)
	top_h.add_child(UI.header("物资储备"))
	stash_count_lbl = UI.label("", 12, UI.MUTED)
	stash_count_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stash_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_h.add_child(stash_count_lbl)

	var f_grp := ButtonGroup.new()
	var fh := HBoxContainer.new()
	fh.add_theme_constant_override("separation", 6)
	lv.add_child(fh)
	var cat_filters := [
		["all", "全部"],
		["module", "模块"],
		["use", "消耗品"],
		["food", "食物"],
		["misc", "杂物"],
		["money", "贵重品"]
	]
	for cf in cat_filters:
		var k: String = cf[0]
		var b := Button.new()
		b.text = cf[1]
		b.toggle_mode = true
		b.button_group = f_grp
		b.button_pressed = (k == "all")
		b.custom_minimum_size = Vector2(64, 30)
		b.pressed.connect(func():
			stash_filter = k
			_populate_stash_list())
		fh.add_child(b)

	stash_list = _list()
	stash_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stash_list.item_selected.connect(_on_stash_selected)
	stash_list.item_activated.connect(func(_i): _move_to_cargo())
	lv.add_child(stash_list)

	var mb := HBoxContainer.new()
	mb.add_theme_constant_override("separation", 6)
	lv.add_child(mb)
	_btn(mb, "装入出击货舱", _move_to_cargo)
	_btn(mb, "出售 1 件", _sell_selected)
	_btn(mb, "出售全部杂物", _sell_junk)

	var p_right := UI.panel(12)
	p_right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	p_right.offset_right = -16
	p_right.offset_top = 16
	p_right.offset_bottom = -16
	p_right.offset_left = -16 - 340
	v_s.add_child(p_right)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 10)
	p_right.add_child(rv)
	rv.add_child(UI.header("物资明细"))

	var ip := PanelContainer.new()
	ip.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.1), 1, 0, UI.ACCENT, 0, 10))
	rv.add_child(ip)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 8)
	ip.add_child(iv)

	stash_icon_rect = TextureRect.new()
	stash_icon_rect.custom_minimum_size = Vector2(64, 64)
	stash_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stash_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stash_icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	iv.add_child(stash_icon_rect)

	stash_detail_lbl = UI.label("", 13)
	stash_detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iv.add_child(stash_detail_lbl)


# ============================================================ 5. 图鉴视图
func _build_codex_view(parent: Control) -> void:
	var v_c := Control.new()
	v_c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(v_c)
	views["codex"] = v_c

	var p_left := UI.panel(12)
	p_left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	p_left.offset_left = 16
	p_left.offset_top = 16
	p_left.offset_bottom = -16
	p_left.offset_right = 16 + 320
	v_c.add_child(p_left)

	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	p_left.add_child(lv)
	lv.add_child(UI.header("打捞档案图鉴"))

	var c_grp := ButtonGroup.new()
	var c_tabs_h := HBoxContainer.new()
	c_tabs_h.add_theme_constant_override("separation", 4)
	lv.add_child(c_tabs_h)
	var c_tabs := [
		["crew", "船员"],
		["module", "模块"],
		["enemy", "异体"],
		["map", "战区"]
	]
	for ct in c_tabs:
		var k: String = ct[0]
		var b := Button.new()
		b.text = ct[1]
		b.toggle_mode = true
		b.button_group = c_grp
		b.button_pressed = (k == "crew")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 32)
		b.pressed.connect(func():
			codex_tab = k
			_populate_codex_list())
		c_tabs_h.add_child(b)

	codex_list = _list()
	codex_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	codex_list.item_selected.connect(_on_codex_selected)
	lv.add_child(codex_list)

	var p_right := UI.panel(12)
	p_right.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p_right.offset_left = 16 + 320 + 12
	p_right.offset_top = 16
	p_right.offset_bottom = -16
	p_right.offset_right = -16
	v_c.add_child(p_right)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 10)
	p_right.add_child(rv)

	var top_card := PanelContainer.new()
	top_card.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.1), 1, 0, UI.ACCENT, 0, 10))
	rv.add_child(top_card)

	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 14)
	top_card.add_child(ch)

	codex_portrait = TextureRect.new()
	codex_portrait.custom_minimum_size = Vector2(100, 100)
	codex_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	codex_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	codex_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ch.add_child(codex_portrait)

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 2)
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch.add_child(cv)
	codex_title_lbl = UI.label("", 20, UI.ACCENT)
	cv.add_child(codex_title_lbl)
	codex_sub_lbl = UI.label("", 13, UI.INFO)
	cv.add_child(codex_sub_lbl)

	codex_stat_grid = GridContainer.new()
	codex_stat_grid.columns = 4
	codex_stat_grid.add_theme_constant_override("h_separation", 10)
	codex_stat_grid.add_theme_constant_override("v_separation", 4)
	rv.add_child(codex_stat_grid)

	rv.add_child(UI.header("档案简述", "", 14))

	var desc_p := PanelContainer.new()
	desc_p.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.08), 1, 0, UI.ACCENT, 0, 10))
	desc_p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(desc_p)

	codex_detail_lbl = UI.label("", 14, Color(0.88, 0.9, 0.92))
	codex_detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_p.add_child(codex_detail_lbl)


func _populate_codex_list() -> void:
	codex_list.clear()
	codex_ids.clear()
	match codex_tab:
		"crew":
			var keys := ["nao", "rei", "kurumi", "lina", "laojiao", "ajin", "xiaoman", "shiori", "karasu", "nihong", "gin"]
			for k in keys:
				var info: Dictionary = CHAR_PROFILES.get(k, {})
				var idx := codex_list.add_item(info.get("name", k), AssetPaths.portrait(k))
				codex_ids.append(k)
		"module":
			var m_keys := GameData.MODULES.keys()
			m_keys.sort_custom(func(a, b):
				var ma = GameData.MODULES[a]
				var mb = GameData.MODULES[b]
				if ma.slot != mb.slot:
					return str(ma.slot) < str(mb.slot)
				return int(ma.rar) > int(mb.rar))
			for id in m_keys:
				var m = GameData.MODULES[id]
				var idx := codex_list.add_item("%s  %s" % [GameData.SLOT_NAMES.get(m.slot, ""), m.name], UI.rarity_icon(int(m.rar), "module"))
				codex_list.set_item_custom_fg_color(idx, GameData.RARITY_COLORS[int(m.rar)])
				codex_ids.append(id)
		"enemy":
			for k in GameData.ENEMIES.keys():
				var ed: Dictionary = GameData.ENEMIES[k]
				var idx := codex_list.add_item("%s  %s" % [ed.get("name", k), "领主" if ed.get("boss", false) else "常规"])
				codex_ids.append(k)
		"map":
			for id in GameData.map_ids():
				var md: Dictionary = GameData.MAPS[id]
				var idx := codex_list.add_item("%s  [%s]" % [md.name, md.tag])
				codex_ids.append(id)
	if not codex_ids.is_empty():
		codex_list.select(0)
		_on_codex_selected(0)


func _on_codex_selected(idx: int) -> void:
	if idx < 0 or idx >= codex_ids.size():
		return
	var id: String = codex_ids[idx]
	for c in codex_stat_grid.get_children():
		c.queue_free()

	match codex_tab:
		"crew":
			var p: Dictionary = CHAR_PROFILES.get(id, {})
			codex_portrait.texture = AssetPaths.portrait(id)
			codex_portrait.visible = true
			codex_title_lbl.text = p.get("name", "")
			codex_sub_lbl.text = p.get("role", "")
			codex_detail_lbl.text = p.get("desc", "")
		"module":
			var m: Dictionary = GameData.MODULES.get(id, {})
			codex_portrait.texture = UI.rarity_icon(int(m.get("rar", 0)), "module")
			codex_portrait.visible = true
			codex_title_lbl.text = str(m.get("name", ""))
			codex_sub_lbl.text = "%s模块  ·  %s  ·  %dkg  ·  ¥%d" % [GameData.SLOT_NAMES.get(m.get("slot", ""), ""), GameData.RARITY_NAMES[int(m.get("rar", 0))], int(m.get("w", 0)), int(m.get("v", 0))]
			codex_detail_lbl.text = Growth.subst(str(m.get("desc", "军用标准模块。")))
			for stat_k in ["hp", "energy", "speed", "load", "cargo", "armor", "dmg", "rate", "range"]:
				if m.has(stat_k):
					var name_map := {"hp": "结构", "energy": "能源", "speed": "速度", "load": "承重", "cargo": "货舱", "armor": "护甲", "dmg": "伤害", "rate": "射速", "range": "射程"}
					codex_stat_grid.add_child(UI.label(name_map.get(stat_k, stat_k), 12, UI.MUTED))
					codex_stat_grid.add_child(UI.label(str(m[stat_k]), 12, UI.INFO))
		"enemy":
			var e: Dictionary = GameData.ENEMIES.get(id, {})
			codex_portrait.texture = null
			codex_portrait.visible = false
			codex_title_lbl.text = str(e.get("name", id))
			codex_sub_lbl.text = "深渊异化生物  ·  %s" % ("领主级" if e.get("boss", false) else "常规群落")
			codex_detail_lbl.text = str(e.get("desc", "游荡在深渊裂缝周边的异化生物，极具攻击性。"))
			for stat_k in ["hp", "speed", "armor", "dmg"]:
				if e.has(stat_k):
					var name_map := {"hp": "生命", "speed": "移动速度", "armor": "护甲值", "dmg": "近战杀伤"}
					codex_stat_grid.add_child(UI.label(name_map.get(stat_k, stat_k), 12, UI.MUTED))
					codex_stat_grid.add_child(UI.label(str(e[stat_k]), 12, UI.BAD))
		"map":
			var md: Dictionary = GameData.MAPS.get(id, {})
			codex_portrait.texture = null
			codex_portrait.visible = false
			codex_title_lbl.text = str(md.get("name", id))
			codex_sub_lbl.text = "空投战区  ·  %s" % str(md.get("tag", ""))
			codex_detail_lbl.text = "%s\n\n环境特性：%s" % [str(md.get("desc", "")), str(md.get("env", "无特殊异常"))]


# ============================================================ 3D 机库背景
func _build_hangar() -> void:
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_PASS
	svc.gui_input.connect(_on_view_input)
	add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	svc.add_child(sv)
	hangar_vp = sv
	GameData.apply_quality(sv)
	preview_root = Node3D.new()
	sv.add_child(preview_root)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.2, 0.22, 0.32)
	sky_mat.sky_horizon_color = Color(0.85, 0.55, 0.38)
	sky_mat.ground_bottom_color = Color(0.05, 0.05, 0.06)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.035)
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true
	env.ssao_intensity = 2.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.09, 0.12)
	env.fog_density = 0.02
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.8, 0.8, 0.85)
	var we := WorldEnvironment.new()
	we.environment = env
	preview_root.add_child(we)

	var M_FLOOR := A.metal(Color(0.16, 0.17, 0.19))
	for x in range(-4, 5):
		for z in range(-4, 3):
			A.add(preview_root, A.bevel_box(Vector3(2.9, 0.2, 2.9), 0.05), M_FLOOR, Vector3(x * 3.0, -0.1, z * 3.0))
	A.add(preview_root, A.bevel_box(Vector3(27, 0.04, 0.5), 0.01), A.hazard(), Vector3(0, 0.01, 5.0))
	turntable = Node3D.new()
	preview_root.add_child(turntable)
	A.add(preview_root, A.cyl(3.0, 0.16, 3.1, 48), A.metal(Color(0.22, 0.23, 0.26)), Vector3(0, 0.08, 0))
	A.add(preview_root, A.torus(2.9, 3.05, 64), A.emit(UI.ACCENT, 1.3), Vector3(0, 0.17, 0), Vector3.ZERO, Vector3(1, 0.2, 1), false)
	A.add(preview_root, A.cyl(2.4, 0.04, 2.4, 48), A.metal(Color(0.12, 0.12, 0.14)), Vector3(0, 0.18, 0))

	var M_WALL := A.paint(Color(0.24, 0.26, 0.3), 0.3, 0.6)
	for x in range(-5, 6):
		A.add(preview_root, A.bevel_box(Vector3(2.8, 7.5, 0.4), 0.08), M_WALL, Vector3(x * 3.0, 3.75, -9.5))
		A.add(preview_root, A.bevel_box(Vector3(0.25, 7.6, 0.6), 0.04), A.metal(Color(0.12, 0.12, 0.14)), Vector3(x * 3.0 + 1.5, 3.8, -9.3))
	for x in [-6.0, 6.0]:
		A.add(preview_root, A.bevel_box(Vector3(4.2, 2.2, 0.1), 0.05), A.emit(Color(0.95, 0.55, 0.32), 0.9), Vector3(x, 4.6, -9.25), Vector3.ZERO, Vector3.ONE, false)
		A.add(preview_root, A.bevel_box(Vector3(4.6, 0.2, 0.3), 0.04), A.metal(), Vector3(x, 5.75, -9.2))
		A.add(preview_root, A.bevel_box(Vector3(4.6, 0.2, 0.3), 0.04), A.metal(), Vector3(x, 3.45, -9.2))
		A.add(preview_root, A.bevel_box(Vector3(0.12, 2.2, 0.2), 0.02), A.metal(), Vector3(x, 4.6, -9.2))
		var wl := OmniLight3D.new()
		wl.light_color = Color(1.0, 0.6, 0.35)
		wl.light_energy = 1.5
		wl.omni_range = 8.0
		wl.position = Vector3(x, 4.6, -8.0)
		preview_root.add_child(wl)

	var bay := Label3D.new()
	bay.text = "BAY 03"
	bay.font_size = 160
	bay.pixel_size = 0.01
	bay.modulate = Color(1.0, 0.6, 0.16, 0.55)
	bay.outline_size = 0
	bay.shaded = true
	bay.position = Vector3(0, 6.2, -9.25)
	preview_root.add_child(bay)
	A.add(preview_root, A.bevel_box(Vector3(14, 0.3, 0.3), 0.05), A.hazard(), Vector3(0, 1.0, -9.2))

	for sx in [-1.0, 1.0]:
		A.add(preview_root, A.bevel_box(Vector3(0.6, 8.0, 0.6), 0.08), A.paint(Color(0.85, 0.55, 0.15), 0.3, 0.5), Vector3(sx * 7.5, 4.0, -4.0))
		A.add(preview_root, A.bevel_box(Vector3(0.6, 0.6, 6.0), 0.08), A.paint(Color(0.85, 0.55, 0.15), 0.3, 0.5), Vector3(sx * 7.5, 7.7, -1.5))
		A.add(preview_root, A.bevel_box(Vector3(1.6, 1.2, 1.2), 0.08), A.paint(Color(0.3, 0.38, 0.28), 0.2, 0.7), Vector3(sx * 6.0, 0.6, -6.5))
		A.add(preview_root, A.bevel_box(Vector3(1.2, 0.9, 1.0), 0.08), A.paint(Color(0.55, 0.35, 0.18), 0.2, 0.7), Vector3(sx * 6.2, 1.65, -6.4), Vector3(0, 15, 0))
		A.add(preview_root, A.bevel_box(Vector3(1.4, 1.0, 1.0), 0.08), A.paint(Color(0.3, 0.38, 0.28), 0.2, 0.7), Vector3(sx * 7.0, 0.5, 2.0), Vector3(0, -20, 0))

	var key := SpotLight3D.new()
	key.position = Vector3(2.5, 9.0, 4.0)
	key.light_energy = 9.0
	key.spot_range = 20.0
	key.spot_angle = 32.0
	key.shadow_enabled = true
	key.light_color = Color(1.0, 0.95, 0.88)
	preview_root.add_child(key)
	key.look_at_from_position(key.position, Vector3(0, 1.5, 0))

	for c in [[Vector3(-5, 3.5, -2), Color(0.3, 0.75, 1.0), 3.0], [Vector3(5, 2.5, -2.5), Color(1.0, 0.55, 0.2), 2.5]]:
		var l := OmniLight3D.new()
		l.position = c[0]
		l.light_color = c[1]
		l.light_energy = c[2]
		l.omni_range = 9.0
		preview_root.add_child(l)

	var front := SpotLight3D.new()
	front.position = Vector3(-1.5, 3.2, 7.0)
	front.light_energy = 3.0
	front.spot_range = 14.0
	front.spot_angle = 30.0
	front.light_color = Color(0.85, 0.9, 1.0)
	preview_root.add_child(front)
	front.look_at_from_position(front.position, Vector3(0, 2.0, 0))

	var fillv := DirectionalLight3D.new()
	fillv.rotation_degrees = Vector3(-30, 160, 0)
	fillv.light_energy = 0.25
	fillv.light_color = Color(0.6, 0.7, 1.0)
	preview_root.add_child(fillv)

	A.emitter(preview_root, Vector3(0, 3, 0), {"amount": 60, "life": 8.0, "size": 0.04, "box": Vector3(6, 3, 4), "spread": 180.0, "vmin": 0.05, "vmax": 0.15,
		"gravity": Vector3(0, -0.02, 0), "c0": Color(1, 0.9, 0.8, 0.0), "cmid": Color(1, 0.9, 0.8, 0.6), "c1": Color(1, 0.9, 0.8, 0.0), "grow0": 1.0, "grow1": 1.0})

	var cam := Camera3D.new()
	cam.position = Vector3(0, 3.1, 8.8)
	cam.fov = 40
	preview_root.add_child(cam)
	cam.look_at(Vector3(0, 1.9, 0))
	preview_cam = cam


func _toggle_explode() -> void:
	exploded = not exploded
	if explode_btn:
		explode_btn.text = "◆ 组装视图" if exploded else "◇ 拆解视图"
	Audio.play_ui("hub_explode" if exploded else "hub_assemble")
	if preview_mech:
		MV.explode(preview_mech, 1.0 if exploded else 0.0, 0.6)
	if preview_cam:
		var to := Vector3(0, 4.4, 14.5) if exploded else Vector3(0, 3.1, 8.8)
		var look := Vector3(0, 2.7, 0) if exploded else Vector3(0, 1.9, 0)
		var tw := create_tween()
		tw.tween_method(func(t: float):
			preview_cam.position = preview_cam.position.lerp(to, t)
			preview_cam.look_at(look), 0.0, 1.0, 0.6)


func _on_view_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		drag = e.pressed
	elif e is InputEventMouseMotion and drag:
		spin += e.relative.x * 0.01


func _process(delta: float) -> void:
	if turntable and preview_mech:
		if not drag:
			spin += delta * 0.35
		turntable.rotation.y = lerp_angle(turntable.rotation.y, spin, clamp(delta * 8.0, 0.0, 1.0))


# ============================================================ 全局数据刷新与逻辑绑定
func refresh() -> void:
	GameData.save_game()
	if money_lbl:
		money_lbl.text = "¥ %s" % _fmt_money(GameData.money)
	if record_lbl:
		record_lbl.text = "出击 %d  ·  成功撤离 %d" % [GameData.raids, GameData.extracts_ok]
	RenderingServer.global_shader_parameter_set("mech_damage", 0.0)

	if preview_mech and is_instance_valid(preview_mech):
		MV.apply(preview_mech, GameData.loadout, true)
	elif turntable:
		preview_mech = MV.build(GameData.loadout)
		turntable.add_child(preview_mech)
		preview_mech.position.y = 0.2
		preview_mech.rotation.y = PI

	for slot in GameData.SLOTS:
		if not slot_name_lbls.has(slot):
			continue
		var id: String = GameData.loadout.get(slot, "")
		var nl: Label = slot_name_lbls[slot]
		var stl: Label = slot_stat_lbls[slot]
		if id == "":
			nl.text = "— 空 —"
			nl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.48))
			stl.text = ""
		else:
			var m: Dictionary = GameData.module(id)
			nl.text = GameData.item_name(id)
			nl.add_theme_color_override("font_color", GameData.RARITY_COLORS[int(m.rar)])
			stl.text = "%s · %dkg" % [GameData.RARITY_NAMES[int(m.rar)], int(m.w)]

	var st := GameData.compute_stats(GameData.loadout)
	var cw := GameData.weight_of(GameData.cargo)
	var sf := GameData.speed_factor(st, cw)
	var runtime: float = st.energy / max(0.01, st.drain)
	if not stat_rows.is_empty():
		_stat("hp", st.hp, 300.0, "%d" % st.hp + ("  甲%d%%" % int(st.armor * 100) if st.armor > 0 else ""))
		_stat("energy", st.energy, 250.0, "%d · %d:%02d" % [st.energy, int(runtime) / 60, int(runtime) % 60])
		_stat("speed", st.speed * sf, 10.0, "%.1f%s" % [st.speed * sf, "" if sf > 0.99 else " ↓"])
		_stat("load", st.mass + cw, max(1.0, st.load), "%.0f/%.0f" % [st.mass + cw, st.load])
		_stat("cargo", st.cargo, 40.0, "%.0f kg" % st.cargo)
		var lr: Array = stat_rows["load"]
		lr[0].color = Color(0.75, 0.6, 1.0) if sf > 0.99 else UI.BAD

	if cargo_list:
		cargo_list.clear()
		for id in GameData.cargo:
			var it := GameData.item(id)
			cargo_list.add_item("%s  %.1fkg" % [it.name, it.w], UI.rarity_icon(int(it.rar), it.cat))
	if cargo_lbl:
		cargo_lbl.text = "%.1f / %.0f kg" % [cw, st.cargo]

	var err := GameData.can_deploy(GameData.loadout)
	if deploy_err:
		deploy_err.text = err
	if deploy_btn:
		deploy_btn.disabled = (err != "")
		deploy_btn.modulate.a = 0.5 if err != "" else 1.0

	_populate_stash_list()
	_populate_deploy_stash()
	_refresh_shop()

	var rq := GameData.request
	if request_lbl and not rq.is_empty():
		request_lbl.text = "%s 的委托\n需要：%s ×%d（现有 %d）\n报酬：¥%d" % [rq.who, GameData.item_name(rq.id), rq.count, GameData.count_in_stash(rq.id), rq.reward]

	if codex_list and codex_list.item_count == 0:
		_populate_codex_list()


func _populate_stash_list() -> void:
	if not stash_list:
		return
	stash_list.clear()
	stash_ids.clear()
	var counts := {}
	for id in GameData.stash:
		var it := GameData.item(id)
		if stash_filter != "all" and it.cat != stash_filter:
			continue
		counts[id] = counts.get(id, 0) + 1

	var keys := counts.keys()
	keys.sort_custom(func(a, b):
		var ia := GameData.item(a)
		var ib := GameData.item(b)
		if ia.cat != ib.cat:
			return str(ia.cat) > str(ib.cat)
		return int(ia.v) > int(ib.v))

	for id in keys:
		var it := GameData.item(id)
		var idx := stash_list.add_item("%s ×%d    %s · %.1fkg · ¥%d" % [it.name, counts[id], GameData.CAT_NAMES.get(it.cat, "?"), it.w, it.v], UI.rarity_icon(int(it.rar), it.cat))
		stash_list.set_item_custom_fg_color(idx, GameData.RARITY_COLORS[int(it.rar)])
		stash_ids.append(id)

	if stash_count_lbl:
		stash_count_lbl.text = "共 %d 件物资" % GameData.stash.size()

	if stash_ids.is_empty():
		stash_list.add_item("货架空空荡荡，暂无该类物资。")
		stash_list.set_item_disabled(0, true)


func _populate_deploy_stash() -> void:
	if not deploy_stash_list:
		return
	deploy_stash_list.clear()
	deploy_stash_ids.clear()
	var counts := {}
	for id in GameData.stash:
		var it := GameData.item(id)
		if it.cat == "use" or it.cat == "food":
			counts[id] = counts.get(id, 0) + 1
	for id in counts:
		var it := GameData.item(id)
		var idx := deploy_stash_list.add_item("%s ×%d  (%.1fkg)" % [it.name, counts[id], it.w], UI.rarity_icon(int(it.rar), it.cat))
		deploy_stash_list.set_item_custom_fg_color(idx, GameData.RARITY_COLORS[int(it.rar)])
		deploy_stash_ids.append(id)


func _refresh_shop() -> void:
	if not shop_list:
		return
	shop_list.clear()
	shop_ids.clear()
	var md: Dictionary = MERCHANTS.get(cur_merchant, {})
	var merchant_items: Array = md.get("items", [])
	for id in merchant_items:
		if not GameData.ITEMS.has(id):
			continue
		var it := GameData.item(id)
		var p := _price(id)
		var idx := shop_list.add_item("%s    %s · ¥%d" % [it.name, GameData.CAT_NAMES.get(it.cat, ""), p], UI.rarity_icon(int(it.rar), it.cat))
		shop_list.set_item_custom_fg_color(idx, GameData.RARITY_COLORS[int(it.rar)])
		shop_ids.append(id)


func _stat(k: String, v: float, mx: float, txt: String) -> void:
	var row: Array = stat_rows[k]
	row[0].set_value(v, mx)
	row[1].text = txt


func _fmt_money(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func _price(id: String) -> int:
	return int(GameData.item(id).v * 1.25)


func _on_stash_selected(i: int) -> void:
	if i >= stash_ids.size():
		return
	selected_stash = stash_ids[i]
	var it := GameData.item(selected_stash)
	var extra := ""
	if it.cat == "module":
		var m: Dictionary = GameData.module(selected_stash)
		var parts: Array = []
		for k in ["hp", "cargo", "energy", "speed", "load", "dmg", "rate", "armor"]:
			if m.has(k):
				parts.append("%s %s" % [{"hp": "结构", "cargo": "货舱", "energy": "能源", "speed": "速度", "load": "承重", "dmg": "伤害", "rate": "射速", "armor": "护甲"}[k], str(m[k])])
		extra = "\n" + "  ·  ".join(parts)
	var txt := "%s〔%s〕\n重量: %.1fkg  ·  价值: ¥%d\n%s%s" % [it.name, GameData.RARITY_NAMES[int(it.rar)], it.w, it.v, Growth.subst(str(it.get("desc", ""))), extra]
	if stash_detail_lbl:
		stash_detail_lbl.text = txt
	if stash_icon_rect:
		stash_icon_rect.texture = UI.rarity_icon(int(it.rar), it.cat)


func _move_to_cargo() -> void:
	if selected_stash == "" or not GameData.stash.has(selected_stash):
		Audio.play_ui("ui_denied")
		return
	var st := GameData.compute_stats(GameData.loadout)
	if GameData.weight_of(GameData.cargo) + float(GameData.item(selected_stash).w) > st.cargo:
		if deploy_err:
			deploy_err.text = "出击货舱超出承重上限"
		Audio.play_ui("ui_denied")
		return
	GameData.stash.erase(selected_stash)
	GameData.cargo.append(selected_stash)
	Audio.play_ui("cargo_load")
	refresh()


func _cargo_back(i: int) -> void:
	if i < 0 or i >= GameData.cargo.size():
		return
	var id: String = GameData.cargo[i]
	GameData.cargo.remove_at(i)
	GameData.stash.append(id)
	Audio.play_ui("cargo_unload")
	refresh()


func _sell_selected() -> void:
	if selected_stash == "" or not GameData.stash.has(selected_stash):
		Audio.play_ui("ui_denied")
		return
	GameData.stash.erase(selected_stash)
	GameData.money += int(GameData.item(selected_stash).v)
	Audio.play_ui("shop_sell")
	refresh()


func _sell_junk() -> void:
	var keep: Array = []
	var gain := 0
	for id in GameData.stash:
		var c: String = GameData.item(id).cat
		if (c == "food" or c == "misc") and not (not GameData.request.is_empty() and id == GameData.request.id):
			gain += int(GameData.item(id).v)
		else:
			keep.append(id)
	GameData.stash = keep
	GameData.money += gain
	Audio.play_ui("shop_sell" if gain > 0 else "ui_denied")
	refresh()


func _buy(i: int) -> void:
	if i < 0 or i >= shop_ids.size():
		return
	var id: String = shop_ids[i]
	var p := _price(id)
	if GameData.money < p:
		if deploy_err:
			deploy_err.text = "账户信用点不足"
		Audio.play_ui("ui_denied")
		return
	GameData.money -= p
	GameData.stash.append(id)
	Audio.play_ui("shop_buy")
	refresh()


func _starter_frame() -> void:
	var changed := false
	for slot in ["core", "legs", "gen", "arm_l"]:
		if GameData.loadout.get(slot, "") == "" and not (slot == "arm_l" and GameData.loadout.get("arm_r", "") != ""):
			GameData.loadout[slot] = GameData.STARTER[slot]
			changed = true
	if not changed and deploy_err:
		deploy_err.text = "机体状态齐备，无需申请应急机架"
	Audio.play_ui("hub_starter" if changed else "ui_denied")
	refresh()


func _strip_all_modules() -> void:
	var changed := false
	for slot in GameData.SLOTS:
		var cur: String = GameData.loadout.get(slot, "")
		if cur != "":
			GameData.loadout[slot] = ""
			GameData.stash.append(cur)
			changed = true
	if changed:
		Audio.play_ui("hub_detach")
	refresh()


func _open_slot_menu(slot: String) -> void:
	popup.clear()
	popup_map.clear()
	popup_slot = slot
	var seen := {}
	var n := 0
	for id in GameData.stash:
		if GameData.slot_accepts(slot, id) and not seen.has(id):
			seen[id] = true
			popup.add_icon_item(UI.rarity_icon(int(GameData.item(id).rar), "module"), "装备  %s（%s）" % [GameData.item_name(id), GameData.RARITY_NAMES[int(GameData.item(id).rar)]], n)
			popup_map[n] = id
			n += 1
	if GameData.loadout.get(slot, "") != "":
		popup.add_item("卸下到仓库", 999)
	if n == 0 and GameData.loadout.get(slot, "") == "":
		popup.add_item("仓库里没有可用的%s模块" % GameData.SLOT_NAMES[slot], 998)
		popup.set_item_disabled(popup.item_count - 1, true)
	var b: Button = slot_buttons[slot]
	popup.popup(Rect2i(Vector2i(b.global_position + Vector2(b.size.x + 6, 0)), Vector2i(300, 0)))


func _on_popup(id: int) -> void:
	var cur: String = GameData.loadout.get(popup_slot, "")
	if id == 999:
		GameData.loadout[popup_slot] = ""
		GameData.stash.append(cur)
		Audio.play_ui("hub_detach")
	elif popup_map.has(id):
		var new_id: String = popup_map[id]
		GameData.stash.erase(new_id)
		if cur != "":
			GameData.stash.append(cur)
			Audio.play_ui("hub_detach")
		GameData.loadout[popup_slot] = new_id
		get_tree().create_timer(0.45 if cur != "" else 0.28).timeout.connect(func(): Audio.play_ui("hub_dock"))
	refresh()


func _list() -> ItemList:
	var l := ItemList.new()
	l.max_text_lines = 2
	l.fixed_icon_size = Vector2i(20, 20)
	return l


func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 34)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.set_meta("sfx", "")
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
