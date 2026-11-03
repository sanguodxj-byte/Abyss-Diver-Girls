extends Control
## 飞空艇「信天翁号」主界面：二级菜单（整备 / 交易 / 降落 / 技能 / 仓库 / 图鉴）
## v0.7 版式参考「逃离塔科夫」主界面结构（保留本作像素风与世界观）：
##   顶部 36px 细状态栏（舰名 · 驾驶员等级与经验 · 主角团 · 战绩 · 杂物 · 资金 · 舰时 · 画质），
##   底部 48px 等宽主导航栏（当前页琥珀顶线高亮），中间内容区外边距 12、栏间距 8。
##   整备 = 装备槽列 + 3D 机甲 + 仓库网格 + 属性汇总条；仓库 = 大网格 + 分类筛选 + 物品详情；
##   交易 = 商人头像卡横排 → 商人货架网格 / 玩家仓库网格 / 交易确认栏；降落 = 战区地图 → 确认携带 → 出发；
##   技能 = 设施卡片网格（需求红绿标识）；图鉴 = 手册式左侧分类树 + 右侧详情。
## 部件见 scripts/hub_kit.gd，物品图标见 scripts/item_icons.gd。

signal deploy_requested

const MV = preload("res://scripts/mech_visual.gd")
const A = preload("res://scripts/art.gd")
const UI = preload("res://scripts/ui.gd")
const K = preload("res://scripts/hub_kit.gd")
const HUD = preload("res://scripts/hud.gd")
const Growth = preload("res://scripts/progression/growth.gd")
const AssetPaths = preload("res://scripts/asset_paths.gd")
const Icons = preload("res://scripts/item_icons.gd")
const WorldLink = preload("res://scripts/world_link.gd")
const WorldMapView = preload("res://scripts/world_map_view.gd")

## 3D 机库背景与转台
var preview_root: Node3D
var preview_mech: Node3D
var turntable: Node3D
var preview_cam: Camera3D
var hangar_vp: SubViewport
var drag := false
var spin := 0.0
var exploded := false

## 顶栏 / 底栏与全局状态
var money_lbl: Label
var junk_lbl: Label
var record_lbl: Label
var clock_lbl: Label
var nav_buttons := {}
var cur_tab := "maintenance"
var crew_avatars := {}
var lead_name_lbl: Label
var lead_sub_lbl: Label
var lead_xp_bar

## 视图容器
var views := {}
var tab_bg: TextureRect
const TAB_BG := {"trade": "bg_trade", "deploy": "bg_deploy", "skills": "bg_skills", "stash": "bg_stash", "codex": "bg_codex"}
var ctx_popup: PopupMenu
var ctx_id := ""
var ctx_from := ""

## 整备视图（装备槽、属性汇总、仓库网格）
var slot_buttons := {}
var slot_cells := {}
var slot_name_lbls := {}
var slot_stat_lbls := {}
var stat_rows := {}
var explode_btn: Button
var popup: PopupMenu
var popup_slot := ""
var popup_map := {}
var maint_grid
var maint_ids: Array = []
var maint_filter := "all"
var maint_count_lbl: Label
var maint_mass_lbl: Label
var maint_squad_lbl: Label

## 交易视图（商人卡片 → 货架 / 仓库 / 交易栏）
var trade_list_root: Control
var trade_deal_root: Control
var trade_mode := "list"
var merchant_cards := {}
var merchant_buttons := {}
var merchant_avatars := {}
var cur_merchant := "ajin"
var merchant_portrait
var merchant_name_lbl: Label
var merchant_role_lbl: Label
var merchant_desc_lbl: Label
var shop_list
var shop_ids: Array = []
var selected_shop := -1
var shop_count_lbl: Label
var shop_title_lbl: Label
var trade_stash_grid
var trade_stash_ids: Array = []
var trade_side := ""
var deal_cell
var deal_name_lbl: Label
var deal_info_lbl: Label
var deal_price_lbl: Label
var deal_after_lbl: Label
var buy_btn: Button
var sell_btn: Button
var request_lbl: Label
var request_avatar
var request_reward_lbl: Label
var account_box: VBoxContainer

## 降落视图（① 选择战区 → ② 确认携带 → ③ 出发）
var deploy_step := 1
var step_btns: Array = []
var deploy_pages: Array = []
var map_buttons := {}       ## v0.7.2 起战区改在大地图上点选（world_map），保留为空表兼容旧接口
var world_map               ## scripts/world_map_view.gd
var map_title_lbl: Label
var map_tag_lbl: Label
var map_desc_lbl: Label
var map_hazard_lbl: Label
var map_quest_lbl: Label
var map_link_lbl: Label
var map_title2_lbl: Label
var map_tag2_lbl: Label
var cargo_list
var cargo_ids: Array = []
var cargo_lbl: Label
var deploy_stash_list
var deploy_stash_ids: Array = []
var deploy_btn: Button
var deploy_err: Label
var squad_box: HBoxContainer
var squad_count_lbl: Label
var check_box: VBoxContainer

## 技能视图（飞空艇设施、研究、主角能力、部署仓）
var skills_sub := "airship"
var skills_nav := {}
var skills_body: VBoxContainer
var skills_scroll: ScrollContainer
var skills_title_lbl: Label
var skills_right_lbl: Label
var skills_en_lbl: Label
var salvage_box: VBoxContainer
var salvage_grid
var skills_msg: Label

## 仓库视图（大网格、分类筛选、物品详情）
var stash_list
var stash_ids: Array = []
var selected_stash := ""
var stash_filter := "all"
var stash_detail_lbl: Label
var stash_name_lbl: Label
var stash_tag_box: HBoxContainer
var stash_icon_rect
var stash_count_lbl: Label
var stash_kv_box: VBoxContainer
var stash_use_lbl: Label

## 图鉴视图（手册：左侧分类树、右侧详情）
var codex_tab := "crew"
var codex_tree: Tree
var codex_search: LineEdit
var codex_ids: Array = []
var codex_items := {}
var codex_portrait: TextureRect
var codex_avatar
var codex_title_lbl: Label
var codex_sub_lbl: Label
var codex_detail_lbl: Label
var codex_stat_grid: GridContainer
var codex_stat_card: PanelContainer
var codex_growth_lbl: Label
var codex_path_lbl: Label
var codex_full: TextureRect
var codex_full_box: PanelContainer

const SLOT_EN := {"core": "CORE", "legs": "LEGS", "arm_l": "L.ARM", "arm_r": "R.ARM", "back": "BACK", "gen": "POWER"}
const DIR_NAMES := {"N": "北", "S": "南", "E": "东", "W": "西"}
const ZONE_COLORS := {"D": Color(0.46, 0.43, 0.38), "R": Color(0.4, 0.37, 0.31), "I": Color(0.36, 0.35, 0.39), "H": Color(0.27, 0.34, 0.4),
	"Y": Color(0.4, 0.33, 0.27), "M": Color(0.33, 0.37, 0.25), "P": Color(0.26, 0.4, 0.25), "F": Color(0.5, 0.46, 0.28),
	"W": Color(0.42, 0.39, 0.29), "T": Color(0.19, 0.32, 0.2), "C": Color(0.3, 0.25, 0.21), "S": Color(0.42, 0.2, 0.38), "K": Color(0.25, 0.25, 0.27)}


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

## 主角团在顶栏的身份短句
const CREW_ROLE := {
	"nao": "主力驾驶员",
	"rei": "AI 驾驶员 · 部署仓 A",
	"kurumi": "AI 驾驶员 · 部署仓 B",
	"lina": "运输机「格里芬」驾驶员",
	"laojiao": "机库整备师",
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



## 可接收拖放的按钮（装备槽 / 战区卡片）：can_fn(data) -> bool、drop_fn(data)、drag_fn() -> 拖出的数据
class DropButton extends Button:
	var can_fn: Callable
	var drop_fn: Callable
	var drag_fn: Callable
	var tip_fn: Callable

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return can_fn.is_valid() and data is Dictionary and bool(can_fn.call(data))

	func _drop_data(_at: Vector2, data: Variant) -> void:
		if drop_fn.is_valid():
			drop_fn.call(data)

	func _get_drag_data(_at: Vector2) -> Variant:
		if not drag_fn.is_valid():
			return null
		var d = drag_fn.call()
		if d == null:
			return null
		var pv := TextureRect.new()
		pv.texture = load("res://scripts/item_icons.gd").icon(str(d.get("id", "")))
		pv.size = Vector2(32, 32)
		pv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pv.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		set_drag_preview(pv)
		return d

	func _get_tooltip(_at: Vector2) -> String:
		return "1" if tip_fn.is_valid() and tip_fn.call() != null else tooltip_text

	func _make_custom_tooltip(_t: String) -> Object:
		return tip_fn.call() if tip_fn.is_valid() else null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = K.theme()
	_build_hangar()

	var content := Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_top = K.TOP_H
	content.offset_bottom = -K.BOT_H
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	# 舱壁像素背景（各页签微差：交易 = 货舱集装箱、降落 = 作战室地图桌、技能 = 工坊、仓库 = 货架、图鉴 = 档案室）；
	# 整备页保留 3D 机库与机甲，不铺背景
	tab_bg = TextureRect.new()
	tab_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab_bg.stretch_mode = TextureRect.STRETCH_TILE
	tab_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tab_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tab_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(tab_bg)

	_build_maintenance_view(content)
	_build_trade_view(content)
	_build_deploy_view(content)
	_build_skills_view(content)
	_build_stash_view(content)
	_build_codex_view(content)

	_build_top_bar()
	_build_bottom_bar()

	popup = PopupMenu.new()
	popup.set_meta("sfx", "")
	popup.id_pressed.connect(_on_popup)
	add_child(popup)
	ctx_popup = PopupMenu.new()
	ctx_popup.set_meta("sfx", "")
	ctx_popup.id_pressed.connect(_on_ctx)
	add_child(ctx_popup)

	var tm := Timer.new()
	tm.wait_time = 20.0
	tm.autostart = true
	tm.timeout.connect(_update_clock)
	add_child(tm)

	_select_merchant_silent(cur_merchant)
	_switch_tab("maintenance")


## 内容区里的一个视图根节点
func _view(parent: Control, key: String) -> Control:
	var v := Control.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(v)
	views[key] = v
	return v


## 把控件按锚点与偏移摆进父节点：a = [左, 上, 右, 下] 锚点（0~1），o = [左, 上, 右, 下] 偏移
func _at(c: Control, parent: Control, a: Array, o: Array) -> Control:
	parent.add_child(c)
	c.anchor_left = a[0]
	c.anchor_top = a[1]
	c.anchor_right = a[2]
	c.anchor_bottom = a[3]
	c.offset_left = o[0]
	c.offset_top = o[1]
	c.offset_right = o[2]
	c.offset_bottom = o[3]
	return c


## 常用摆法
const FILL := [0.0, 0.0, 1.0, 1.0]
const LEFT := [0.0, 0.0, 0.0, 1.0]
const RIGHT := [1.0, 0.0, 1.0, 1.0]


## 带标题条的面板；返回 [面板, 内容 VBox, 右侧 Label]
func _tpanel(parent: Control, title: String, en: String, a: Array, o: Array, right := "") -> Array:
	var tp: Array = K.tpanel(title, en, right)
	_at(tp[0], parent, a, o)
	return tp


## 栏位：side = "left" 固定宽度靠左；"right" 固定宽度靠右；"fill" 夹在 left_w 与 right_w 之间
func _column(parent: Control, side: String, w := 0.0, left_w := 0.0, right_w := 0.0) -> PanelContainer:
	var p := K.frame(8)
	match side:
		"left":
			p.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
			p.offset_left = K.M
			p.offset_right = K.M + w
		"right":
			p.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
			p.offset_right = -K.M
			p.offset_left = -K.M - w
		_:
			p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			p.offset_left = K.M + (left_w + K.GAP if left_w > 0 else 0.0)
			p.offset_right = -K.M - (right_w + K.GAP if right_w > 0 else 0.0)
	p.offset_top = K.GAP
	p.offset_bottom = -K.GAP
	parent.add_child(p)
	return p


func _sec(parent: Control, title: String, en := "", right := "") -> Label:
	var s: Array = K.section(title, en, right)
	parent.add_child(s[0])
	return s[1]


func _vsep(parent: Control, h := 20) -> void:
	var c := ColorRect.new()
	c.color = K.LINE
	c.custom_minimum_size = Vector2(1, h)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)


func _scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


func _grid_widget(cell := K.CELL, kind := "") -> Control:
	var g = K.ItemGrid.new(cell)
	g.tip_fn = _item_tip
	g.drag_kind = kind
	return g


# ============================================================ 顶部细状态栏
func _build_top_bar() -> void:
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", K.px9("topbar9", 8, 8, K.M, 2))
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = K.TOP_H
	add_child(top)

	var th := K.hbox(10)
	top.add_child(th)

	var ship := K.hbox(6)
	ship.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(ship)
	ship.add_child(UI.label("信天翁号", 12, Color(1.0, 0.8, 0.42)))
	ship.add_child(UI.label("ALBATROSS · BAY 03", 12, K.CREAM_DIM))
	_vsep(th)

	# 驾驶员：头像 + 名称 / 等级 + 经验条；其余主角团小头像（悬停看身份，点击打开图鉴档案）
	for cid in K.CREW:
		var av = K.Avatar.new(20, cid, "lead" if cid == Growth.PROTAGONIST else "n")
		av.mouse_filter = Control.MOUSE_FILTER_STOP
		av.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		av.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_open_codex_char(cid))
		crew_avatars[cid] = av
		th.add_child(av)
		if cid == Growth.PROTAGONIST:
			var nv := K.vbox(2)
			nv.custom_minimum_size = Vector2(118, 0)
			nv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var nh := K.hbox(6)
			nv.add_child(nh)
			lead_name_lbl = UI.label("", 12, Color(1.0, 0.85, 0.45))
			lead_name_lbl.clip_text = true
			lead_name_lbl.custom_minimum_size = Vector2(56, 0)
			lead_name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			nh.add_child(lead_name_lbl)
			nh.add_child(K.icon_rect(K.small_icon("level"), 16))
			lead_sub_lbl = UI.label("", 12, K.CREAM)
			nh.add_child(lead_sub_lbl)
			lead_xp_bar = K.PixBar.new(6)
			lead_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nv.add_child(lead_xp_bar)
			th.add_child(nv)
			_vsep(th)

	_vsep(th)
	var mid := K.hbox(6)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.clip_contents = true
	th.add_child(mid)
	# 顶栏只留状态信息，不显示任何台词

	th.add_child(K.icon_rect(K.small_icon("raid"), 16))
	record_lbl = UI.label("", 12, K.CREAM_DIM)
	record_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(record_lbl)
	_vsep(th)
	th.add_child(K.icon_rect(K.small_icon("junk"), 16))
	junk_lbl = UI.label("", 12, K.CREAM)
	junk_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	junk_lbl.tooltip_text = "仓库里的打捞杂物（升级材料）合计"
	junk_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	th.add_child(junk_lbl)
	_vsep(th)
	th.add_child(K.icon_rect(K.small_icon("money"), 16))
	money_lbl = UI.label("", 12, Color(1.0, 0.85, 0.4))
	money_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(money_lbl)
	_vsep(th)
	th.add_child(K.icon_rect(K.small_icon("clock"), 16))
	clock_lbl = UI.label("", 12, K.CREAM)
	clock_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(clock_lbl)

	var qb := Button.new()
	qb.text = "画质 %s" % GameData.QUALITY_NAMES[GameData.quality]
	qb.tooltip_text = "流畅：MSAA 2x + FXAA\n高：MSAA 4x + FXAA + TAA\n极致：MSAA 4x + TAA + 1.5 倍超采样"
	qb.custom_minimum_size = Vector2(76, 24)
	qb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	qb.focus_mode = Control.FOCUS_NONE
	qb.pressed.connect(func():
		GameData.quality = (GameData.quality + 1) % 3
		GameData.apply_quality(get_viewport())
		if hangar_vp:
			GameData.apply_quality(hangar_vp)
		qb.text = "画质 %s" % GameData.QUALITY_NAMES[GameData.quality]
		GameData.save_game())
	th.add_child(qb)
	_update_clock()


func _update_clock() -> void:
	if clock_lbl:
		var t := Time.get_time_dict_from_system()
		clock_lbl.text = "舰时 %02d:%02d" % [int(t.hour), int(t.minute)]


# ============================================================ 底部主导航栏（等宽、当前项高亮）
func _build_bottom_bar() -> void:
	var bar := PanelContainer.new()
	var sb: StyleBox = K.px9("botbar9", 12, 12, K.M, 4).duplicate()
	sb.content_margin_top = 8
	sb.content_margin_bottom = 2
	bar.add_theme_stylebox_override("panel", sb)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -K.BOT_H
	add_child(bar)

	var h := K.hbox(4)
	bar.add_child(h)
	var grp := ButtonGroup.new()
	for td in [["maintenance", "整备", "LOADOUT"], ["trade", "交易", "TRADERS"], ["deploy", "降落", "DEPLOY"],
			["skills", "技能", "HIDEOUT"], ["stash", "仓库", "STASH"], ["codex", "图鉴", "HANDBOOK"]]:
		var key: String = td[0]
		var btn = K.NavButton.new(td[1], td[2], "nav_" + key)
		btn.button_group = grp
		btn.pressed.connect(func(): _switch_tab(key))
		nav_buttons[key] = btn
		h.add_child(btn)


func _switch_tab(tab_key: String) -> void:
	var changed := tab_key != cur_tab
	cur_tab = tab_key
	for k in nav_buttons:
		nav_buttons[k].button_pressed = (k == tab_key)
	for k in views:
		views[k].visible = (k == tab_key)
	if tab_bg:
		tab_bg.texture = K.px_tex(TAB_BG.get(tab_key, "bg_base"))
		tab_bg.visible = tab_key != "maintenance"
	if explode_btn:
		explode_btn.visible = (tab_key == "maintenance")
	if changed or true:
		if tab_key == "trade":
			_trade_show("list")
		elif tab_key == "deploy":
			_deploy_show(1)
	Audio.play_ui("ui_tab")
	refresh()


func _open_codex_char(cid: String) -> void:
	codex_tab = "crew"
	_switch_tab("codex")
	_populate_codex_list()
	_codex_select("crew", cid)


## 物品悬停浮窗：名称（稀有度色）· 类别 · 重量 / 价值 / 库存 · 模块数值 · 说明
func _item_tip(e: Dictionary) -> Control:
	var id := str(e.get("id", ""))
	var it := GameData.item(id)
	var rar := int(it.get("rar", 0))
	var v := K.vbox(4)
	v.custom_minimum_size = Vector2(240, 0)
	var nh := K.hbox(8)
	v.add_child(nh)
	var ic = K.IconCell.new(40)
	ic.set_entry({"id": id, "label": ""})
	nh.add_child(ic)
	var nv := K.vbox(2)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nh.add_child(nv)
	var nl := UI.label(str(it.get("name", id)), 12, GameData.RARITY_COLORS[rar])
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nv.add_child(nl)
	var cat := str(it.get("cat", ""))
	var sub := "%s · %s" % [GameData.RARITY_NAMES[rar], GameData.CAT_NAMES.get(cat, "")]
	if cat == "module":
		sub += " · " + str(GameData.SLOT_NAMES.get(str(GameData.module(id).get("slot", "")), "手臂"))
	nv.add_child(UI.label(sub, 12, K.CREAM_DIM))
	var r := K.Rule.new()
	r.solid = true
	v.add_child(r)
	v.add_child(K.kv("重量", "%.1f kg" % float(it.get("w", 0))))
	v.add_child(K.kv("价值", "¥ %s" % _fmt_money(int(it.get("v", 0))), Color(1.0, 0.85, 0.4)))
	if e.has("price"):
		v.add_child(K.kv("售价", "¥ %s" % _fmt_money(int(e.price)), Color(1.0, 0.85, 0.4)))
	v.add_child(K.kv("仓库", "×%d" % GameData.count_in_stash(id)))
	if cat == "module":
		var m: Dictionary = GameData.module(id)
		var names := {"hp": "结构", "cargo": "货舱", "energy": "能源", "speed": "速度", "load": "承重", "dmg": "伤害", "rate": "射速", "armor": "护甲", "range": "射程"}
		for k in ["hp", "armor", "energy", "speed", "load", "cargo", "dmg", "rate", "range"]:
			if m.has(k):
				v.add_child(K.kv(names[k], str(m[k]), UI.INFO))
	var desc := Growth.subst(str(it.get("desc", "")))
	if desc != "":
		var d := K.wrap(desc, K.CREAM_DIM)
		d.custom_minimum_size = Vector2(240, 0)
		v.add_child(d)
	if e.has("hint"):
		v.add_child(UI.label(str(e.hint), 12, UI.ACCENT))
	return v


## 按 id 聚合成网格条目（数量叠加），按类别 → 价值排序
func _stack(list: Array, filter := "all") -> Array:
	var counts := {}
	var order: Array = []
	for id in list:
		var it := GameData.item(id)
		if filter != "all" and str(it.cat) != filter and not (filter == "other" and str(it.cat) != "module"):
			continue
		if not counts.has(id):
			order.append(id)
		counts[id] = counts.get(id, 0) + 1
	order.sort_custom(func(a, b):
		var ia := GameData.item(a)
		var ib := GameData.item(b)
		if ia.cat != ib.cat:
			return str(ia.cat) > str(ib.cat)
		return int(ia.v) > int(ib.v))
	var out: Array = []
	for id in order:
		out.append({"id": id, "count": counts[id]})
	return out


# ============================================================ 1. 整备视图（装备槽 · 3D 机甲 · 仓库网格 · 属性汇总条）
func _build_maintenance_view(parent: Control) -> void:
	var v_m := _view(parent, "maintenance")
	const LW := 300.0
	const RW := 372.0

	explode_btn = Button.new()
	explode_btn.text = "◇ 拆解视图"
	explode_btn.custom_minimum_size = Vector2(128, 28)
	explode_btn.set_meta("sfx", "")
	explode_btn.pressed.connect(_toggle_explode)
	_at(explode_btn, v_m, [0.0, 0.0, 0.0, 0.0], [K.M + LW + K.GAP, K.GAP, K.M + LW + K.GAP + 128, K.GAP + 28])

	# 左：装备槽列
	var lp := _tpanel(v_m, "装备", "Equipment", LEFT, [K.M, K.GAP, K.M + LW, -K.GAP])
	maint_mass_lbl = lp[2]
	var v: VBoxContainer = lp[1]
	for slot in GameData.SLOTS:
		var b := DropButton.new()
		b.custom_minimum_size = Vector2(0, 60)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_open_slot_menu.bind(slot))
		b.can_fn = func(d: Dictionary): return str(d.get("kind", "")) == "stash" and GameData.slot_accepts(slot, str(d.get("id", "")))
		b.drop_fn = func(d: Dictionary): _equip_to(slot, str(d.id))
		b.drag_fn = func():
			var cur: String = GameData.loadout.get(slot, "")
			return null if cur == "" else {"kind": "slot", "slot": slot, "id": cur}
		b.tip_fn = func():
			var cur: String = GameData.loadout.get(slot, "")
			return null if cur == "" else _item_tip({"id": cur, "hint": "点击更换 · 拖到仓库卸下"})
		v.add_child(b)
		var m := MarginContainer.new()
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for kk in [["margin_left", 6], ["margin_right", 8], ["margin_top", 5], ["margin_bottom", 5]]:
			m.add_theme_constant_override(kk[0], kk[1])
		b.add_child(m)
		var bh := K.hbox(8)
		bh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(bh)
		var ic = K.IconCell.new(48)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bh.add_child(ic)
		var bv := K.vbox(2)
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bh.add_child(bv)
		var top_row := K.hbox(6)
		top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(top_row)
		top_row.add_child(UI.label(GameData.SLOT_NAMES[slot], 12, K.CREAM_DIM))
		var en := UI.label(SLOT_EN.get(slot, str(slot).to_upper()), 12, Color(0.38, 0.38, 0.33))
		en.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(en)
		var nl := UI.label("", 12)
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		bv.add_child(nl)
		var st := UI.label("", 12, K.CREAM_DIM)
		bv.add_child(st)
		for c in [top_row, nl, st, bv]:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for c in top_row.get_children():
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_buttons[slot] = b
		slot_cells[slot] = ic
		slot_name_lbls[slot] = nl
		slot_stat_lbls[slot] = st

	var lsp := Control.new()
	lsp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(lsp)
	_sec(v, "整备台", "Mechanic")
	var mia := K.card(false, 6)
	v.add_child(mia)
	var mh := K.hbox(8)
	mia.add_child(mh)
	mh.add_child(K.Avatar.new(20, "laojiao"))
	var mv := K.vbox(0)
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mh.add_child(mv)
	mv.add_child(UI.label("米娅 · 机库整备师", 12, UI.INFO))
	var ab := K.hbox(6)
	v.add_child(ab)
	_btn(ab, "领取应急机架", _starter_frame).custom_minimum_size.y = 28
	_btn(ab, "卸下全部模块", _strip_all_modules).custom_minimum_size.y = 28

	# 右：仓库网格
	var rp := _tpanel(v_m, "仓库", "Stash", RIGHT, [-K.M - RW, K.GAP, -K.M, -K.GAP])
	maint_count_lbl = rp[2]
	var rv: VBoxContainer = rp[1]
	var fh := K.hbox(4)
	rv.add_child(fh)
	var fg := ButtonGroup.new()
	for cf in [["all", "全部"], ["module", "模块"], ["other", "物资"]]:
		var k: String = cf[0]
		var fb := K.button(cf[1], 24)
		fb.toggle_mode = true
		fb.button_group = fg
		fb.button_pressed = k == "all"
		fb.custom_minimum_size.x = 56
		fb.pressed.connect(func():
			maint_filter = k
			_populate_maint_grid())
		fh.add_child(fb)
	maint_grid = _grid_widget(K.CELL, "stash")
	maint_grid.item_activated.connect(func(i):
		if i < maint_ids.size():
			_quick_equip(str(maint_ids[i])))
	maint_grid.item_context.connect(func(i):
		if i < maint_ids.size():
			_open_ctx(str(maint_ids[i]), "stash"))
	maint_grid.accept_drop = func(d: Dictionary): return str(d.get("kind", "")) == "slot"
	maint_grid.on_drop = func(d: Dictionary): _unequip(str(d.slot))
	rv.add_child(_scroll(maint_grid))
	rv.add_child(UI.label("双击装备 · 拖动到左侧槽位 · 右键更多", 12, Color(0.4, 0.4, 0.36)))

	# 中下：属性汇总条
	var sp := K.frame(6)
	_at(sp, v_m, [0.0, 1.0, 1.0, 1.0], [K.M + LW + K.GAP, -K.GAP - 76, -K.M - RW - K.GAP, -K.GAP])
	var sv := K.vbox(4)
	sp.add_child(sv)
	var shh := K.hbox(6)
	sv.add_child(shh)
	shh.add_child(UI.label("机体性能", 12, K.CREAM))
	shh.add_child(UI.label("SPECS", 12, K.CREAM_DIM))
	var sr := K.Rule.new()
	sr.solid = true
	sr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shh.add_child(sr)
	maint_squad_lbl = UI.label("", 12, K.CREAM_DIM)
	shh.add_child(maint_squad_lbl)
	var sh := K.hbox(0)
	sv.add_child(sh)
	var first := true
	for k in [["hp", "结构", "HP", UI.HP_C], ["armor", "护甲", "ARM", Color(0.7, 0.75, 0.8)], ["energy", "能源", "EN", UI.EN_C],
			["speed", "速度", "SPD", UI.INFO], ["load", "承重", "LOAD", Color(0.75, 0.6, 1.0)], ["cargo", "货舱", "CARGO", UI.GOOD]]:
		if not first:
			_vsep(sh, 34)
		first = false
		var cell := K.vbox(2)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cm := MarginContainer.new()
		cm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cm.add_theme_constant_override("margin_left", 6)
		cm.add_theme_constant_override("margin_right", 6)
		cm.add_child(cell)
		sh.add_child(cm)
		var lh := K.hbox(4)
		cell.add_child(lh)
		lh.add_child(UI.label(k[1], 12, K.CREAM_DIM))
		var en := UI.label(k[2], 12, Color(0.38, 0.38, 0.33))
		lh.add_child(en)
		var val := UI.label("", 12, K.CREAM)
		cell.add_child(val)
		var bar = K.PixBar.new(6)
		bar.color = k[3]
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(bar)
		stat_rows[k[0]] = [bar, val]


# ============================================================ 2. 交易视图：商人卡片横排 → 货架 / 仓库 / 交易确认栏
func _build_trade_view(parent: Control) -> void:
	var v_t := _view(parent, "trade")

	# ---- 商人列表
	trade_list_root = Control.new()
	trade_list_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_at(trade_list_root, v_t, FILL, [0, 0, 0, 0])
	var tp := _tpanel(trade_list_root, "商人", "Traders", [0.0, 0.0, 1.0, 0.0], [K.M, K.GAP, -K.M, K.GAP + 340], "选择一位商人开始交易")
	var row := K.hbox(8)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tp[1].add_child(row)
	for m_id in K.MERCHANT_IDS:
		var md: Dictionary = MERCHANTS[m_id]
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", K.px9("merchant9", 12, 12, 6))
		b.add_theme_stylebox_override("hover", K.px9("merchant9_h", 12, 12, 6))
		b.add_theme_stylebox_override("pressed", K.px9("merchant9_on", 12, 12, 6))
		b.add_theme_stylebox_override("hover_pressed", K.px9("merchant9_on", 12, 12, 6))
		b.pressed.connect(func(): _select_merchant(m_id))
		row.add_child(b)
		merchant_cards[m_id] = b
		var mc := MarginContainer.new()
		mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for kk in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			mc.add_theme_constant_override(kk, 8)
		b.add_child(mc)
		var cv := K.vbox(4)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mc.add_child(cv)
		var av = K.Avatar.new(128, m_id, "n")
		av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cv.add_child(av)
		var plate := PanelContainer.new()
		plate.add_theme_stylebox_override("panel", K.px9("nameplate9", 10, 6, 14, 0))
		plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(plate)
		var nl := UI.label(md.name, 24, Color(0.1, 0.065, 0.02))
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plate.add_child(nl)
		var rl := K.wrap(md.role, K.CREAM_DIM)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.custom_minimum_size = Vector2(150, 30)
		cv.add_child(rl)
		var r := K.Rule.new()
		r.solid = true
		cv.add_child(r)
		var aff := K.hbox(6)
		aff.mouse_filter = Control.MOUSE_FILTER_IGNORE
		aff.set_meta("merchant", m_id)
		cv.add_child(aff)
		var stock := UI.label("", 12, K.CREAM_DIM)
		stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(stock)
		b.set_meta("aff", aff)
		b.set_meta("stock", stock)
		for c in [nl, rl, stock]:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var rq := _tpanel(trade_list_root, "后勤委托", "Request", FILL, [K.M, K.GAP * 2 + 340, -K.M - 380 - K.GAP, -K.GAP])
	var rqv: VBoxContainer = rq[1]
	var rc := K.card(false, 10)
	rqv.add_child(rc)
	var rh := K.hbox(12)
	rc.add_child(rh)
	request_avatar = K.Avatar.new(96, "lina", "on")
	rh.add_child(request_avatar)
	var rvv := K.vbox(6)
	rvv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rh.add_child(rvv)
	request_lbl = K.wrap("", K.CREAM)
	rvv.add_child(request_lbl)
	request_reward_lbl = UI.label("", 24, Color(1.0, 0.85, 0.4))
	rvv.add_child(request_reward_lbl)
	var rsp := Control.new()
	rsp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rqv.add_child(rsp)
	var sub := K.primary("提交委托", 36)
	sub.set_meta("sfx", "")
	sub.pressed.connect(func():
		if GameData.fulfill_request():
			Audio.play_ui("request_complete")
			refresh()
		else:
			Audio.play_ui("ui_denied"))
	rqv.add_child(sub)

	var ac := _tpanel(trade_list_root, "账户", "Account", RIGHT, [-K.M - 380, K.GAP * 2 + 340, -K.M, -K.GAP])
	account_box = K.vbox(6)
	ac[1].add_child(account_box)
	var asp := Control.new()
	asp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ac[1].add_child(asp)
	var sj := Button.new()
	sj.text = "出售全部食物与杂物"
	sj.custom_minimum_size = Vector2(0, 32)
	sj.set_meta("sfx", "")
	sj.pressed.connect(_sell_junk)
	ac[1].add_child(sj)

	# ---- 与某位商人交易
	trade_deal_root = Control.new()
	trade_deal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_at(trade_deal_root, v_t, FILL, [0, 0, 0, 0])
	var hdr := K.frame(6)
	_at(hdr, trade_deal_root, [0.0, 0.0, 1.0, 0.0], [K.M, K.GAP, -K.M, K.GAP + 66])
	var hh := K.hbox(10)
	hdr.add_child(hh)
	var back := Button.new()
	back.text = "← 商人列表"
	back.custom_minimum_size = Vector2(112, 40)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func():
		_trade_show("list")
		Audio.play_ui("ui_tab"))
	hh.add_child(back)
	_vsep(hh, 40)
	for m_id in K.MERCHANT_IDS:
		var mb := Button.new()
		mb.toggle_mode = true
		mb.focus_mode = Control.FOCUS_NONE
		mb.custom_minimum_size = Vector2(52, 52)
		mb.flat = true
		mb.tooltip_text = "%s · %s" % [MERCHANTS[m_id].name, MERCHANTS[m_id].role]
		mb.pressed.connect(func(): _select_merchant(m_id))
		var av = K.Avatar.new(40, m_id)
		av.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mb.add_child(av)
		merchant_buttons[m_id] = mb
		merchant_avatars[m_id] = av
		hh.add_child(mb)
	_vsep(hh, 40)
	merchant_portrait = K.Avatar.new(40, "ajin", "on")
	merchant_portrait.visible = false
	hh.add_child(merchant_portrait)
	var mv := K.vbox(2)
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hh.add_child(mv)
	var nh := K.hbox(10)
	mv.add_child(nh)
	merchant_name_lbl = UI.label("", 24, UI.ACCENT)
	nh.add_child(merchant_name_lbl)
	merchant_role_lbl = UI.label("", 12, UI.INFO)
	merchant_role_lbl.size_flags_vertical = Control.SIZE_SHRINK_END
	nh.add_child(merchant_role_lbl)
	merchant_desc_lbl = UI.label("", 12, K.CREAM_DIM)
	merchant_desc_lbl.clip_text = true
	merchant_desc_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mv.add_child(merchant_desc_lbl)

	const DEAL_H := 76.0
	var gt := K.GAP * 2 + 66
	var sp := _tpanel(trade_deal_root, "货架", "Offers", [0.0, 0.0, 0.5, 1.0], [K.M, gt, -K.GAP * 0.5, -K.GAP * 2 - DEAL_H])
	shop_count_lbl = sp[2]
	shop_title_lbl = sp[0].get_meta("title_lbl")
	shop_list = _grid_widget(60, "shop")
	shop_list.item_selected.connect(func(i):
		selected_shop = i
		_on_shop_selected(i))
	shop_list.item_activated.connect(_buy)
	shop_list.accept_drop = func(d: Dictionary): return str(d.get("kind", "")) == "tstash"
	shop_list.on_drop = func(d: Dictionary):
		_trade_pick_sell(str(d.id))
		_sell_selected()
	sp[1].add_child(_scroll(shop_list))
	sp[1].add_child(UI.label("单击查看 · 双击直接买入 · 把仓库物品拖到这里出售", 12, Color(0.4, 0.4, 0.36)))

	var pp := _tpanel(trade_deal_root, "我的仓库", "Stash", [0.5, 0.0, 1.0, 1.0], [K.GAP * 0.5, gt, -K.M, -K.GAP * 2 - DEAL_H])
	trade_stash_grid = _grid_widget(60, "tstash")
	trade_stash_grid.item_selected.connect(func(i):
		if i < trade_stash_ids.size():
			_trade_pick_sell(str(trade_stash_ids[i])))
	trade_stash_grid.item_activated.connect(func(i):
		if i < trade_stash_ids.size():
			_trade_pick_sell(str(trade_stash_ids[i]))
			_sell_selected())
	trade_stash_grid.accept_drop = func(d: Dictionary): return str(d.get("kind", "")) == "shop"
	trade_stash_grid.on_drop = func(d: Dictionary): _buy(int(d.index))
	pp[1].add_child(_scroll(trade_stash_grid))
	pp[1].add_child(UI.label("单击选择要出售的物品 · 双击直接出售 · 把货架商品拖到这里买入", 12, Color(0.4, 0.4, 0.36)))

	# 交易确认栏
	var deal := K.frame(8)
	_at(deal, trade_deal_root, [0.0, 1.0, 1.0, 1.0], [K.M, -K.GAP - DEAL_H, -K.M, -K.GAP])
	var dh := K.hbox(12)
	deal.add_child(dh)
	deal_cell = K.IconCell.new(56)
	deal_cell.tip_fn = _item_tip
	dh.add_child(deal_cell)
	var dv := K.vbox(2)
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dh.add_child(dv)
	deal_name_lbl = UI.label("选择一件商品或仓库物品", 12, K.CREAM)
	dv.add_child(deal_name_lbl)
	deal_info_lbl = UI.label("", 12, K.CREAM_DIM)
	deal_info_lbl.clip_text = true
	deal_info_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	dv.add_child(deal_info_lbl)
	_vsep(dh, 48)
	var pv := K.vbox(2)
	pv.custom_minimum_size = Vector2(220, 0)
	pv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dh.add_child(pv)
	deal_price_lbl = UI.label("", 24, Color(1.0, 0.85, 0.4))
	deal_price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pv.add_child(deal_price_lbl)
	deal_after_lbl = UI.label("", 12, K.CREAM_DIM)
	deal_after_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pv.add_child(deal_after_lbl)
	buy_btn = K.primary("买入", 44)
	buy_btn.custom_minimum_size.x = 120
	buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy_btn.add_theme_font_size_override("font_size", 24)
	buy_btn.set_meta("sfx", "")
	buy_btn.pressed.connect(func():
		if trade_side == "buy" and selected_shop >= 0:
			_buy(selected_shop)
		else:
			Audio.play_ui("ui_denied"))
	dh.add_child(buy_btn)
	sell_btn = Button.new()
	sell_btn.text = "卖出"
	sell_btn.custom_minimum_size = Vector2(120, 44)
	sell_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sell_btn.add_theme_font_size_override("font_size", 24)
	sell_btn.set_meta("sfx", "")
	sell_btn.pressed.connect(func():
		if trade_side == "sell":
			_sell_selected()
		else:
			Audio.play_ui("ui_denied"))
	dh.add_child(sell_btn)
	_trade_show("list")


func _trade_show(mode: String) -> void:
	trade_mode = mode
	if trade_list_root:
		trade_list_root.visible = mode == "list"
		trade_deal_root.visible = mode == "deal"


func _select_merchant_silent(m_id: String) -> void:
	cur_merchant = m_id
	selected_shop = -1
	trade_side = ""
	for k in merchant_buttons:
		merchant_buttons[k].button_pressed = (k == m_id)
		merchant_avatars[k].set_state("on" if k == m_id else "n")
	var md: Dictionary = MERCHANTS.get(m_id, {})
	merchant_name_lbl.text = md.get("name", "")
	merchant_role_lbl.text = md.get("role", "")
	merchant_desc_lbl.text = str(md.get("desc", ""))
	merchant_portrait.set_char(m_id, 40)
	if shop_title_lbl:
		shop_title_lbl.text = "货架 · %s" % md.get("name", "")
	if shop_list:
		shop_list.deselect_all()
	if trade_stash_grid:
		trade_stash_grid.deselect_all()
	_update_deal()


func _select_merchant(m_id: String) -> void:
	_select_merchant_silent(m_id)
	_trade_show("deal")
	Audio.play_ui("ui_tab")
	refresh()


func _on_shop_selected(idx: int) -> void:
	if idx < 0 or idx >= shop_ids.size():
		return
	trade_side = "buy"
	if trade_stash_grid:
		trade_stash_grid.deselect_all()
	_update_deal()


func _trade_pick_sell(id: String) -> void:
	selected_stash = id
	trade_side = "sell"
	selected_shop = -1
	if shop_list:
		shop_list.deselect_all()
	_update_deal()


## 交易确认栏：选中物品、单价、交易后余额
func _update_deal() -> void:
	if deal_cell == null:
		return
	var id := ""
	var price := 0
	if trade_side == "buy" and selected_shop >= 0 and selected_shop < shop_ids.size():
		id = shop_ids[selected_shop]
		price = _price(id)
	elif trade_side == "sell" and selected_stash != "" and GameData.stash.has(selected_stash):
		id = selected_stash
		price = int(GameData.item(id).v)
	else:
		trade_side = ""
	buy_btn.disabled = trade_side != "buy" or GameData.money < price
	sell_btn.disabled = trade_side != "sell"
	if id == "":
		deal_cell.set_entry({})
		deal_name_lbl.text = "选择一件商品（买入）或仓库物品（卖出）"
		deal_name_lbl.add_theme_color_override("font_color", K.CREAM_DIM)
		deal_info_lbl.text = "商人收购价 = 物品价值；商人售价为价值 ×1.25。"
		deal_price_lbl.text = ""
		deal_after_lbl.text = "余额 ¥ %s" % _fmt_money(GameData.money)
		return
	var it := GameData.item(id)
	deal_cell.set_entry({"id": id, "count": GameData.count_in_stash(id)})
	deal_name_lbl.text = ("买入  " if trade_side == "buy" else "卖出  ") + str(it.name)
	deal_name_lbl.add_theme_color_override("font_color", GameData.RARITY_COLORS[int(it.rar)])
	deal_info_lbl.text = "%s · %.1fkg · 仓库 ×%d · %s" % [GameData.CAT_NAMES.get(it.cat, ""), float(it.w), GameData.count_in_stash(id), Growth.subst(str(it.get("desc", "")))]
	deal_price_lbl.text = "¥ %s" % _fmt_money(price)
	var after := GameData.money - price if trade_side == "buy" else GameData.money + price
	deal_after_lbl.text = "余额 ¥ %s  →  ¥ %s" % [_fmt_money(GameData.money), _fmt_money(after)]
	deal_after_lbl.add_theme_color_override("font_color", UI.BAD if after < 0 else K.CREAM_DIM)


# ============================================================ 3. 降落视图：① 选择战区 → ② 确认携带 → ③ 出发
func _build_deploy_view(parent: Control) -> void:
	var v_d := _view(parent, "deploy")
	const RW := 400.0
	const ST_H := 36.0

	# 步骤条
	var steps := K.hbox(6)
	_at(steps, v_d, [0.0, 0.0, 1.0, 0.0], [K.M, K.GAP, -K.M, K.GAP + ST_H])
	for i in 3:
		var sd: Array = [["选择战区", "SELECT ZONE"], ["确认携带", "LOADOUT CHECK"], ["出发", "DEPLOY"]][i]
		var b := Button.new()
		b.text = "%d   %s   %s" % [i + 1, sd[0], sd[1]]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, ST_H)
		var n := i + 1
		b.pressed.connect(func(): _deploy_show(mini(n, 2)))
		steps.add_child(b)
		step_btns.append(b)
		if i < 2:
			var ar := UI.label("→", 12, K.CREAM_DIM)
			ar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			steps.add_child(ar)

	var top := K.GAP * 2 + ST_H
	# ---- 第 1 步：世界地图 + 简报
	var p1 := Control.new()
	p1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_at(p1, v_d, FILL, [0, 0, 0, 0])
	deploy_pages.append(p1)
	var wm := _tpanel(p1, "战区大地图", "World map", FILL, [K.M, top, -K.M - RW - K.GAP, -K.GAP], "绿 = 撤离候选点 · 琥珀 = 遗迹 · 青 = 转场口")
	world_map = WorldMapView.new()
	world_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	world_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wm[1].add_child(world_map)
	world_map.map_selected.connect(func(id: String):
		GameData.map_id = id
		Audio.play_ui("ui_tab")
		_update_map_detail())
	world_map.map_locked.connect(func(_id: String): Audio.play_ui("ui_error"))
	_refresh_world_map()

	var bp := _tpanel(p1, "任务简报", "Briefing", RIGHT, [-K.M - RW, top, -K.M, -K.GAP])
	var bv: VBoxContainer = bp[1]
	var tth := K.hbox(10)
	bv.add_child(tth)
	map_title_lbl = UI.label("", 24, UI.ACCENT)
	tth.add_child(map_title_lbl)
	map_tag_lbl = UI.label("", 12, UI.INFO)
	map_tag_lbl.size_flags_vertical = Control.SIZE_SHRINK_END
	tth.add_child(map_tag_lbl)
	var r1 := K.Rule.new()
	r1.solid = true
	bv.add_child(r1)
	map_desc_lbl = K.wrap("", K.CREAM)
	bv.add_child(map_desc_lbl)
	map_hazard_lbl = K.wrap("", K.CREAM_DIM)
	bv.add_child(map_hazard_lbl)
	_sec(bv, "任务", "Objective")
	map_quest_lbl = K.wrap("", UI.INFO)
	bv.add_child(map_quest_lbl)
	_sec(bv, "相邻战区", "Transit")
	map_link_lbl = K.wrap("", K.CREAM_DIM)
	bv.add_child(map_link_lbl)
	var bsp := Control.new()
	bsp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bv.add_child(bsp)
	bv.add_child(K.hazard_strip())
	var nx := K.primary("下一步 · 确认携带  →", 52)
	nx.add_theme_font_size_override("font_size", 24)
	nx.pressed.connect(func(): _deploy_show(2))
	bv.add_child(nx)

	# ---- 第 2 步：携带物资 + 出发
	var p2 := Control.new()
	p2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_at(p2, v_d, FILL, [0, 0, 0, 0])
	deploy_pages.append(p2)
	var lp := _tpanel(p2, "出击准备", "Loadout check", FILL, [K.M, top, -K.M - RW - K.GAP, -K.GAP])
	var lv: VBoxContainer = lp[1]
	var gh := K.hbox(8)
	gh.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(gh)
	var gl := K.vbox(6)
	gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gh.add_child(gl)
	_sec(gl, "备战物资", "Supplies", "消耗品与食物")
	deploy_stash_list = _grid_widget(K.CELL, "dstash")
	deploy_stash_list.item_activated.connect(func(i):
		if i >= 0 and i < deploy_stash_ids.size():
			selected_stash = deploy_stash_ids[i]
			_move_to_cargo())
	deploy_stash_list.accept_drop = func(d: Dictionary): return str(d.get("kind", "")) == "cargo"
	deploy_stash_list.on_drop = func(d: Dictionary): _cargo_back_id(str(d.id))
	gl.add_child(_scroll(deploy_stash_list))
	var load_b := _btn(gl, "装入出击货舱  →", func():
		var sel = deploy_stash_list.get_selected_items()
		if not sel.is_empty() and sel[0] < deploy_stash_ids.size():
			selected_stash = deploy_stash_ids[sel[0]]
			_move_to_cargo())
	load_b.custom_minimum_size = Vector2(0, 30)
	_vsep(gh, 300)
	var gr := K.vbox(6)
	gr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gh.add_child(gr)
	cargo_lbl = _sec(gr, "出击货舱", "Cargo")
	cargo_list = _grid_widget(K.CELL, "cargo")
	cargo_list.item_activated.connect(func(i):
		if i >= 0 and i < cargo_ids.size():
			_cargo_back_id(str(cargo_ids[i])))
	cargo_list.accept_drop = func(d: Dictionary): return str(d.get("kind", "")) == "dstash"
	cargo_list.on_drop = func(d: Dictionary):
		selected_stash = str(d.id)
		_move_to_cargo()
	gr.add_child(_scroll(cargo_list))
	var back_b := _btn(gr, "←  退回仓库", func():
		var sel = cargo_list.get_selected_items()
		if not sel.is_empty() and sel[0] < cargo_ids.size():
			_cargo_back_id(str(cargo_ids[sel[0]])))
	back_b.custom_minimum_size = Vector2(0, 30)
	squad_count_lbl = _sec(lv, "随行队友", "Squad")
	squad_box = K.hbox(8)
	squad_box.custom_minimum_size = Vector2(0, 64)
	lv.add_child(squad_box)

	var dp := _tpanel(p2, "出发", "Deploy", RIGHT, [-K.M - RW, top, -K.M, -K.GAP])
	var dv: VBoxContainer = dp[1]
	var t2 := K.hbox(10)
	dv.add_child(t2)
	map_title2_lbl = UI.label("", 24, UI.ACCENT)
	t2.add_child(map_title2_lbl)
	map_tag2_lbl = UI.label("", 12, UI.INFO)
	map_tag2_lbl.size_flags_vertical = Control.SIZE_SHRINK_END
	t2.add_child(map_tag2_lbl)
	var r2 := K.Rule.new()
	r2.solid = true
	dv.add_child(r2)
	_sec(dv, "出击检查", "Checklist")
	check_box = K.vbox(4)
	dv.add_child(check_box)
	var dsp := Control.new()
	dsp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(dsp)
	deploy_err = UI.label("", 12, UI.BAD)
	deploy_err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(deploy_err)
	dv.add_child(K.hazard_strip())
	deploy_btn = K.primary("▼  空投出击", 60)
	deploy_btn.add_theme_font_size_override("font_size", 24)
	deploy_btn.set_meta("sfx", "ui_confirm")
	deploy_btn.pressed.connect(func(): deploy_requested.emit())
	dv.add_child(deploy_btn)
	var bk := Button.new()
	bk.text = "←  返回选择战区"
	bk.custom_minimum_size = Vector2(0, 30)
	bk.pressed.connect(func(): _deploy_show(1))
	dv.add_child(bk)

	_update_map_detail()
	_deploy_show(1)


## 大地图的解锁 / 主线 / 选中状态（出击条件可能在别的页签里变化，切到降落页时刷新）
func _refresh_world_map() -> void:
	if world_map == null:
		return
	var av := {}
	var qs := {}
	for id: String in GameData.map_ids():
		av[id] = GameData.map_available(id)
		qs[id] = _map_quest(id) != ""
	world_map.set_state(av, qs, GameData.map_id)


func _deploy_show(n: int) -> void:
	deploy_step = n
	if n == 1:
		_refresh_world_map()
	for i in deploy_pages.size():
		deploy_pages[i].visible = (i == n - 1)
	for i in step_btns.size():
		var b: Button = step_btns[i]
		var st := "on" if i == n - 1 else ("done" if i < n - 1 else "todo")
		var sn := "nav9_on" if st == "on" else ("nav9_n" if st == "done" else "nav9_p")
		b.add_theme_stylebox_override("normal", K.px9(sn, 12, 12, 8, 4))
		b.add_theme_stylebox_override("hover", K.px9("nav9_on" if st == "on" else "nav9_h", 12, 12, 8, 4))
		b.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42) if st == "on" else (K.CREAM if st == "done" else K.CREAM_DIM))


func _map_quest(id: String) -> String:
	for ch in Growth.chapters():
		if str(ch.map) == id:
			var stt := Growth.chapter_status(str(ch.id))
			if stt == "进行中":
				return str(ch.title)
	return ""


func _update_map_detail() -> void:
	var md: Dictionary = GameData.map_data(GameData.map_id)
	map_title_lbl.text = md.get("name", "")
	map_tag_lbl.text = md.get("tag", "")
	map_desc_lbl.text = md.get("desc", "")
	var env_str: String = md.get("env", "")
	map_hazard_lbl.text = ("环境态势：%s" % env_str) if env_str != "" else ""
	map_hazard_lbl.visible = env_str != ""
	var qs: Array = []
	for ch in Growth.chapters():
		if str(ch.map) == GameData.map_id:
			qs.append("%s（%s）" % [str(ch.title), Growth.chapter_status(str(ch.id))])
	var ex: Array = md.get("extracts", [])
	var q := "\n".join(qs) if not qs.is_empty() else "自由搜刮：带回物资，活着撤离。"
	if not ex.is_empty():
		q += "\n撤离点 %d 处（地图上绿色方点）" % ex.size()
	map_quest_lbl.text = q
	var links: Dictionary = WorldLink.LINKS.get(GameData.map_id, {})
	var ls: Array = []
	for e: String in links:
		ls.append("%s · %s" % [DIR_NAMES.get(e, e), str(GameData.map_data(str(links[e])).get("name", links[e]))])
	map_link_lbl.text = "  ".join(ls) if not ls.is_empty() else "竖井战区，不与地表相连。"
	if map_title2_lbl:
		map_title2_lbl.text = map_title_lbl.text
		map_tag2_lbl.text = map_tag_lbl.text


func _refresh_checklist(st: Dictionary, cw: float, err: String) -> void:
	if check_box == null:
		return
	for c in check_box.get_children():
		check_box.remove_child(c)
		c.queue_free()
	check_box.add_child(K.req_row("机体组装", "完整" if err == "" else err, err == ""))
	check_box.add_child(K.req_row("出击货舱", "%.1f / %.0f kg" % [cw, st.cargo], cw <= st.cargo))
	var sf := GameData.speed_factor(st, cw)
	check_box.add_child(K.req_row("机体承重", "%.0f / %.0f" % [st.mass + cw, st.load], sf > 0.99))
	var runtime: float = st.energy / max(0.01, st.drain)
	check_box.add_child(K.req_row("能源续航", "%d:%02d" % [int(runtime) / 60, int(runtime) % 60], runtime >= 240.0))
	var sq := Growth.ally_squad()
	check_box.add_child(K.req_row("随行队友", ("%d 名" % sq.size()) if not sq.is_empty() else "单机出击", true))
	if Growth.facility_level("kitchen") > 0:
		var ready := Growth.meal_ready() > 0
		check_box.add_child(K.req_row("出击餐点", Growth.meal_text() if ready else "未烹制", ready))
	check_box.add_child(K.req_row("驾驶员", "%s Lv%d" % [Growth.player_name(), Growth.pilot_level(Growth.PROTAGONIST)], true))


func _refresh_squad() -> void:
	if squad_box == null:
		return
	for c in squad_box.get_children():
		c.queue_free()
	var sq := Growth.ally_squad()
	var owned := 0
	for pid in Growth.pod_ids():
		if Growth.pod_tier(pid) > 0:
			owned += 1
	squad_count_lbl.text = "部署仓 %d / %d" % [owned, Growth.pod_ids().size()]
	if owned == 0:
		var c := K.card()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		squad_box.add_child(c)
		var h := K.hbox(10)
		c.add_child(h)
		var t := K.wrap("尚未购置部署仓。在「技能 › 部署仓」购买后，零 / 胡桃会随机甲一同空投。", K.CREAM_DIM)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
		var b := Button.new()
		b.text = "前往购置"
		b.custom_minimum_size = Vector2(88, 30)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func():
			_switch_tab("skills")
			_skills_show("pods"))
		h.add_child(b)
		return
	for pid in Growth.pod_ids():
		if Growth.pod_tier(pid) <= 0:
			continue
		var on := Growth.pod_on(pid)
		var c := K.card(on, 6)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		squad_box.add_child(c)
		var h := K.hbox(8)
		c.add_child(h)
		var av = K.Avatar.new(40, Growth.pod_pilot(pid), "on" if on else "n")
		av.dim = not on
		h.add_child(av)
		var v := K.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(v)
		v.add_child(UI.label(str(Growth.pilot_data(Growth.pod_pilot(pid)).get("name", pid)), 12, K.CREAM if on else K.CREAM_DIM))
		v.add_child(UI.label(("T%d · 随行" % Growth.pod_tier(pid)) if on else "待命", 12, UI.GOOD if on else K.CREAM_DIM))
		var cb := Button.new()
		cb.toggle_mode = true
		cb.button_pressed = on
		cb.text = "随行" if on else "待命"
		cb.custom_minimum_size = Vector2(56, 30)
		cb.focus_mode = Control.FOCUS_NONE
		cb.tooltip_text = "本次出击是否随行"
		cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cb.toggled.connect(func(x: bool):
			Growth.set_pod_on(pid, x)
			refresh())
		h.add_child(cb)
	if sq.is_empty():
		squad_count_lbl.text += " · 本次单机出击"


# ============================================================ 4. 技能视图（藏身处式设施卡片：飞空艇设施 / 研究 / 主角能力 / 部署仓）
func _build_skills_view(parent: Control) -> void:
	var v_k := _view(parent, "skills")
	const RW := 300.0
	const ST_H := 36.0

	var nav := K.hbox(6)
	_at(nav, v_k, [0.0, 0.0, 1.0, 0.0], [K.M, K.GAP, -K.M - RW - K.GAP, K.GAP + ST_H])
	var grp := ButtonGroup.new()
	for d in [["airship", "飞空艇设施", "HIDEOUT"], ["research", "研究课题", "RESEARCH"], ["pilot", "主角能力", "PILOT"], ["pods", "部署仓 · 队友", "SQUAD"]]:
		var key: String = d[0]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = grp
		b.custom_minimum_size = Vector2(0, ST_H)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.text = "%s   %s" % [d[1], d[2]]
		b.pressed.connect(func(): _skills_show(key))
		skills_nav[key] = b
		nav.add_child(b)

	var top := K.GAP * 2 + ST_H
	var mp := _tpanel(v_k, "飞空艇设施", "Hideout", FILL, [K.M, top, -K.M - RW - K.GAP, -K.GAP])
	skills_title_lbl = mp[0].get_meta("title_lbl")
	skills_en_lbl = mp[0].get_meta("en_lbl")
	skills_right_lbl = mp[2]
	var rv: VBoxContainer = mp[1]
	skills_scroll = ScrollContainer.new()
	skills_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	skills_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(skills_scroll)
	skills_body = K.vbox(8)
	skills_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_scroll.add_child(skills_body)
	skills_msg = UI.label("", 12, K.CREAM_DIM)
	rv.add_child(skills_msg)

	var sp := _tpanel(v_k, "打捞杂物", "Salvage", RIGHT, [-K.M - RW, K.GAP, -K.M, -K.GAP])
	var sv: VBoxContainer = sp[1]
	salvage_box = K.vbox(4)
	sv.add_child(salvage_box)
	salvage_grid = _grid_widget(K.CELL)
	salvage_grid.min_rows = 2
	sv.add_child(salvage_grid)
	var ssp := Control.new()
	ssp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sv.add_child(ssp)
	sv.add_child(K.wrap("升级花费信用点与仓库里的打捞杂物，杂物从仓库直接扣除。需求行绿色 = 已满足，红色 = 不足。", K.CREAM_DIM))


func _skills_show(sub: String) -> void:
	skills_sub = sub
	for k in skills_nav:
		skills_nav[k].button_pressed = (k == sub)
	if skills_scroll:
		skills_scroll.scroll_vertical = 0
	if cur_tab == "skills":
		_rebuild_skills()


func _item_name(id: String) -> String:
	return GameData.item_name(id)


func _refresh_salvage() -> void:
	if salvage_box == null:
		return
	for c in salvage_box.get_children():
		c.queue_free()
	salvage_box.add_child(K.kv("信用点", "¥ %s" % _fmt_money(GameData.money), Color(1.0, 0.85, 0.4)))
	var tot := 0
	var es: Array = []
	for id in Growth.material_ids():
		if not GameData.ITEMS.has(id):
			continue
		var n := Growth.material_count(str(id))
		tot += n
		es.append({"id": str(id), "count": n, "dim": n == 0, "label": K.short_name(str(id))})
	salvage_box.add_child(K.kv("杂物合计", "×%d" % tot))
	salvage_grid.set_entries(es)


func _rebuild_skills() -> void:
	if skills_body == null:
		return
	for c in skills_body.get_children():
		skills_body.remove_child(c)
		c.queue_free()
	_refresh_salvage()
	for k in skills_nav:
		skills_nav[k].button_pressed = (k == skills_sub)
	match skills_sub:
		"airship":
			skills_title_lbl.text = "飞空艇设施"
			skills_en_lbl.text = "HIDEOUT"
			skills_right_lbl.text = "设施加成对出击机体生效"
			_skills_airship()
		"research":
			skills_title_lbl.text = "研究课题"
			skills_en_lbl.text = "RESEARCH"
			skills_right_lbl.text = "研究室 Lv%d" % Growth.facility_level("lab")
			_skills_research()
		"pilot":
			skills_title_lbl.text = "主角能力"
			skills_en_lbl.text = "PILOT"
			skills_right_lbl.text = "仅作用于主角机体"
			_skills_pilot()
		"pods":
			skills_title_lbl.text = "部署仓 · 战斗队友"
			skills_en_lbl.text = "DEPLOY PODS"
			skills_right_lbl.text = "随你一同空投的 AI 驾驶员"
			_skills_pods()


## 设施卡片：图标 + 名称 + 等级刻度；效果文字；「需求」列表（■ 绿 = 满足 / 红 = 不足）；操作按钮
## extra：额外需求 [[文字, 右侧文字, 是否满足], ...]（研究室等级、前置研究、天赋点……）
func _skill_card(title: String, lv: int, mx: int, lines: Array, cost: Dictionary, btn_text: String, reason: String, cb: Callable, on := false, icon := "", extra: Array = []) -> PanelContainer:
	var c := K.card(on, 8)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := K.vbox(6)
	c.add_child(v)
	var h := K.hbox(8)
	v.add_child(h)
	if icon != "":
		var ib := PanelContainer.new()
		ib.add_theme_stylebox_override("panel", K.px9("inset9", 6, 6, 4, 4))
		h.add_child(ib)
		var tr := TextureRect.new()
		tr.texture = Icons.facility_icon(icon)
		tr.custom_minimum_size = Vector2(32, 32)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ib.add_child(tr)
	var tv := K.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tv)
	var t := UI.label(title, 12, K.CREAM)
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(t)
	if mx > 0:
		var ph := K.hbox(6)
		tv.add_child(ph)
		var p = K.Pips.new(mx)
		p.set_level(lv)
		ph.add_child(p)
		ph.add_child(UI.label("Lv%d / %d" % [lv, mx], 12, K.CREAM_DIM))
	if on:
		h.add_child(K.tag("已完成" if mx == 0 else "Lv%d" % lv, true))
	elif mx > 0:
		h.add_child(K.tag("Lv%d" % lv, lv > 0))
	for l in lines:
		v.add_child(K.wrap(str(l[0]), l[1]))
	var parts := Growth.cost_parts(cost)
	if not parts.is_empty() or not extra.is_empty():
		var rh := K.hbox(6)
		v.add_child(rh)
		rh.add_child(UI.label("需求", 12, K.CREAM_DIM))
		rh.add_child(UI.label("REQUIREMENTS", 12, Color(0.38, 0.38, 0.33)))
		var rr := K.Rule.new()
		rr.solid = true
		rr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rh.add_child(rr)
		var rl := K.vbox(3)
		v.add_child(rl)
		for e in extra:
			rl.add_child(K.req_row(str(e[0]), str(e[1]), bool(e[2])))
		if not parts.is_empty():
			rl.add_child(K.req_list(parts, _item_name))
	elif mx > 0 and lv >= mx:
		v.add_child(K.req_row("已满级", "", true))
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	var b := K.primary(btn_text if reason == "" else "%s · %s" % [btn_text, reason], 30)
	b.disabled = reason != ""
	b.set_meta("sfx", "")
	b.pressed.connect(func():
		if cb.call():
			refresh()
		else:
			Audio.play_ui("ui_denied"))
	v.add_child(b)
	return c


func _grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return g


func _skills_airship() -> void:
	var g := _grid(3)
	skills_body.add_child(g)
	for id in Growth.facility_ids():
		var lv := Growth.facility_level(id)
		var mx := Growth.facility_max(id)
		var effects := Growth.facility_effects(id)
		var cur := Growth.facility_effect(id)
		var nxt := str(effects[lv]) if lv < effects.size() else ""
		var lines: Array = [["当前　" + (cur if cur != "" else "未建设"), K.CREAM_DIM]]
		if nxt != "":
			lines.append(["下一级 " + nxt, UI.INFO])
		var reason := Growth.can_upgrade(id)
		g.add_child(_skill_card(Growth.facility_name(id), lv, mx, lines, Growth.facility_cost(id) if lv < mx else {}, "升级" if lv > 0 else "建设", reason, func(): return Growth.upgrade_facility(id), false, str(id)))
	# 厨房：烹制出击餐点
	if Growth.facility_level("kitchen") > 0:
		var mc := Growth.meal_cost()
		var ready := Growth.meal_ready() > 0
		g.add_child(_skill_card("出击食堂 · 餐点", 0, 0, [["本次出击 " + (Growth.meal_text() if ready else "尚未烹制"), UI.GOOD if ready else K.CREAM_DIM]],
			mc, "烹制餐点", "已备好" if ready else ("" if Growth.can_afford(mc) else "材料不足"), func(): return Growth.serve_meal(), ready, "meal"))


func _skills_research() -> void:
	var g := _grid(3)
	skills_body.add_child(g)
	var lab := Growth.facility_level("lab")
	for id in Growth.research_ids():
		var d := Growth.research_data(id)
		var done := Growth.research_done(id)
		var reason := "已完成" if done else Growth.can_research(id)
		var lines: Array = [[str(d.get("effect", "")), UI.INFO if not done else UI.GOOD]]
		var extra: Array = []
		if not done:
			var need_lab := int(d.get("lab", 1))
			extra.append(["研究室等级", "Lv%d / %d" % [lab, need_lab], lab >= need_lab])
			for n in d.get("needs", []):
				extra.append(["前置 " + str(Growth.research_data(str(n)).get("name", n)), "已完成" if Growth.research_done(str(n)) else "未完成", Growth.research_done(str(n))])
		g.add_child(_skill_card(str(d.get("name", id)), 0, 0, lines, {} if done else d.get("cost", {}), "研究", reason, func(): return Growth.do_research(id), done, "research", extra))


func _skills_pilot() -> void:
	var pid := Growth.PROTAGONIST
	var top := K.card(false, 10)
	skills_body.add_child(top)
	var th := K.hbox(14)
	top.add_child(th)
	var pav = K.Avatar.new(96, pid, "lead")
	pav.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(pav)
	var tv := K.vbox(6)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(tv)
	var nh := K.hbox(10)
	tv.add_child(nh)
	nh.add_child(UI.label(Growth.player_name(), 24, UI.ACCENT))
	var lvl := Growth.pilot_level(pid)
	nh.add_child(K.tag("Lv%d" % lvl))
	var sub := UI.label("主力机甲驾驶员 · 天赋点 %d" % Growth.pilot_points(pid), 12, UI.INFO)
	sub.size_flags_vertical = Control.SIZE_SHRINK_END
	nh.add_child(sub)
	var need := Growth.pilot_xp_next(lvl)
	var xh := K.hbox(8)
	tv.add_child(xh)
	var bar = K.PixBar.new(10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.set_frac(1.0 if need <= 0 else float(Growth.pilot_xp(pid)) / need)
	xh.add_child(bar)
	xh.add_child(UI.label("满级" if need <= 0 else "%d / %d EXP" % [Growth.pilot_xp(pid), need], 12, K.CREAM_DIM))
	var rn := K.hbox(6)
	tv.add_child(rn)
	var le := LineEdit.new()
	le.text = Growth.player_name()
	le.max_length = 8
	le.custom_minimum_size = Vector2(160, 28)
	rn.add_child(le)
	var rb := Button.new()
	rb.text = "更名"
	rb.custom_minimum_size = Vector2(64, 28)
	rb.pressed.connect(func():
		Growth.set_player_name(le.text)
		refresh())
	rn.add_child(rb)
	# 模拟舱训练（钱 + 杂物换经验）
	var reason := Growth.can_train()
	var tc := _skill_card("模拟舱训练", 0, 0, [["经验 +%d（直接结算升级）" % Growth.training_xp(), UI.INFO]], Growth.training_cost(), "开始训练", reason, func(): return not Growth.train_protagonist().is_empty(), false, "training")
	tc.size_flags_horizontal = Control.SIZE_FILL
	tc.custom_minimum_size = Vector2(260, 0)
	th.add_child(tc)

	_sec(skills_body, "能力强化", "Upgrade", "信用点 + 打捞杂物")
	var g := _grid(3)
	skills_body.add_child(g)
	for id in Growth.ability_ids():
		var d := Growth.ability_data(id)
		var alv := Growth.ability_level(id)
		var mx := Growth.ability_max(id)
		var lines: Array = [["每级 " + str(d.get("effect", "")), UI.INFO]]
		g.add_child(_skill_card(Growth.ability_name(id), alv, mx, lines, Growth.ability_cost(id) if alv < mx else {}, "强化", Growth.can_upgrade_ability(id), func(): return Growth.upgrade_ability(id), false, "ability"))

	_sec(skills_body, "驾驶天赋", "Talents", "升级获得天赋点")
	var tg := _grid(4)
	skills_body.add_child(tg)
	var pts := Growth.pilot_points(pid)
	for t in Growth.pilot_data(pid).get("talents", []):
		var tid := str(t.id)
		var learned := Growth.talent_learned(pid, tid)
		var why := "已习得" if learned else Growth.can_learn_talent(pid, tid)
		var extra: Array = [] if learned else [["驾驶员等级", "Lv%d / %d" % [lvl, int(t.level)], lvl >= int(t.level)], ["天赋点", "%d / %d" % [pts, int(t.points)], pts >= int(t.points)]]
		tg.add_child(_skill_card(str(t.name), 0, 0, [[str(t.effect), UI.INFO]], {}, "习得", why, func(): return Growth.learn_talent(pid, tid), learned, "talent", extra))


func _skills_pods() -> void:
	skills_body.add_child(K.wrap("每个部署仓搭载一名 AI 驾驶员与她的机甲，随你一同空投。部署仓等级（T1~T3）决定队友机体强度；勾选「随行」的队友参与本次出击。", K.CREAM_DIM))
	var g := _grid(2)
	skills_body.add_child(g)
	for id in Growth.pod_ids():
		var d := Growth.pod_data(id)
		var tier := Growth.pod_tier(id)
		var pil := Growth.pod_pilot(id)
		var c := K.card(Growth.pod_on(id), 10)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(c)
		var v := K.vbox(6)
		c.add_child(v)
		var h := K.hbox(12)
		v.add_child(h)
		var av = K.Avatar.new(96, pil, "on" if tier > 0 else "n")
		av.dim = tier == 0
		h.add_child(av)
		var hv := K.vbox(6)
		hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(hv)
		var nh := K.hbox(8)
		hv.add_child(nh)
		nh.add_child(UI.label(str(Growth.pilot_data(pil).get("name", pil)), 24, UI.ACCENT if tier > 0 else K.CREAM))
		nh.add_child(K.tag("T%d" % tier if tier > 0 else "未购置", tier > 0))
		hv.add_child(UI.label(str(d.get("name", id)), 12, K.CREAM))
		hv.add_child(UI.label(str(d.get("role", "")), 12, UI.INFO))
		var p = K.Pips.new(Growth.POD_MAX_TIER)
		p.set_level(tier)
		hv.add_child(p)
		var tiers: Array = d.get("tiers", [])
		for i in tiers.size():
			v.add_child(K.req_row("T%d　%s" % [i + 1, tiers[i]], "已装备" if i < tier else ("下一级" if i == tier else "未解锁"), i < tier, i >= tier))
		var reason := Growth.can_buy_pod(id)
		if reason != "已满级":
			var rh := K.hbox(6)
			v.add_child(rh)
			rh.add_child(UI.label("需求", 12, K.CREAM_DIM))
			rh.add_child(UI.label("REQUIREMENTS", 12, Color(0.38, 0.38, 0.33)))
			v.add_child(K.req_list(Growth.cost_parts(Growth.pod_cost(id)), _item_name))
		var bh := K.hbox(8)
		v.add_child(bh)
		var b := K.primary(("购置部署仓" if tier == 0 else "升级至 T%d" % (tier + 1)) if reason == "" else (("购置" if tier == 0 else "升级") + " · " + reason) if reason != "已满级" else "已满级")
		b.disabled = reason != ""
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("sfx", "")
		b.pressed.connect(func():
			if Growth.buy_pod(id):
				refresh()
			else:
				Audio.play_ui("ui_denied"))
		bh.add_child(b)
		var cb := Button.new()
		cb.toggle_mode = true
		cb.disabled = tier == 0
		cb.button_pressed = Growth.pod_on(id)
		cb.text = "■ 随行" if Growth.pod_on(id) else "待命"
		cb.tooltip_text = "本次出击是否随行"
		cb.custom_minimum_size = Vector2(80, 32)
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(func(x: bool):
			Growth.set_pod_on(id, x)
			refresh())
		bh.add_child(cb)

	var sq := Growth.ally_squad()
	var names: Array = []
	for a in sq:
		names.append("%s T%d" % [str(Growth.pilot_data(str(a.pilot)).get("name", a.pilot)), int(a.tier)])
	_sec(skills_body, "本次随行", "Squad", "单机出击" if names.is_empty() else " · ".join(names))
	var row := K.hbox(8)
	skills_body.add_child(row)
	var me = K.Avatar.new(40, Growth.PROTAGONIST, "lead")
	me.tooltip_text = Growth.player_name()
	me.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(me)
	for a in sq:
		row.add_child(K.Avatar.new(40, str(a.pilot), "on"))
	var hint := K.wrap("队友机体由战斗系统按部署仓等级生成：T1 标准、T2 强化、T3 王牌。" if not sq.is_empty() else "购置部署仓后，队友会出现在这里并随你一同空投。", K.CREAM_DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hint)


# ============================================================ 5. 仓库视图（藏匿处：大网格 + 分类筛选 + 物品详情）
func _build_stash_view(parent: Control) -> void:
	var v_s := _view(parent, "stash")
	const RW := 320.0

	var lp := _tpanel(v_s, "仓库", "Stash", FILL, [K.M, K.GAP, -K.M - RW - K.GAP, -K.GAP])
	stash_count_lbl = lp[2]
	var lv: VBoxContainer = lp[1]
	var f_grp := ButtonGroup.new()
	var fh := K.hbox(4)
	lv.add_child(fh)
	for cf in [["all", "全部", "ALL"], ["module", "模块", "MODULE"], ["use", "消耗品", "USE"], ["food", "食物", "FOOD"], ["misc", "杂物", "SALVAGE"], ["money", "贵重品", "VALUABLE"]]:
		var k: String = cf[0]
		var b := Button.new()
		b.text = "%s %s" % [cf[1], cf[2]]
		b.toggle_mode = true
		b.button_group = f_grp
		b.button_pressed = (k == "all")
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 28)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			stash_filter = k
			_populate_stash_list())
		fh.add_child(b)

	stash_list = _grid_widget(56, "stash")
	stash_list.empty_text = "货架空空荡荡，暂无该类物资。"
	stash_list.item_selected.connect(_on_stash_selected)
	stash_list.item_activated.connect(func(_i): _move_to_cargo())
	stash_list.item_context.connect(func(i):
		if i < stash_ids.size():
			_open_ctx(str(stash_ids[i]), "stash"))
	lv.add_child(_scroll(stash_list))

	var mb := K.hbox(6)
	lv.add_child(mb)
	_btn(mb, "装入出击货舱", _move_to_cargo).custom_minimum_size.y = 30
	_btn(mb, "出售 1 件", _sell_selected).custom_minimum_size.y = 30
	_btn(mb, "出售全部食物与杂物", _sell_junk).custom_minimum_size.y = 30

	var rp := _tpanel(v_s, "物品详情", "Inspect", RIGHT, [-K.M - RW, K.GAP, -K.M, -K.GAP])
	var rv: VBoxContainer = rp[1]
	var ih := K.hbox(10)
	rv.add_child(ih)
	stash_icon_rect = K.IconCell.new(96)
	ih.add_child(stash_icon_rect)
	var nv := K.vbox(4)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ih.add_child(nv)
	stash_name_lbl = UI.label("未选择物品", 12, K.CREAM)
	stash_name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nv.add_child(stash_name_lbl)
	stash_tag_box = K.hbox(4)
	nv.add_child(stash_tag_box)
	var r := K.Rule.new()
	r.solid = true
	rv.add_child(r)
	stash_kv_box = K.vbox(4)
	rv.add_child(stash_kv_box)
	stash_detail_lbl = K.wrap("", K.CREAM)
	rv.add_child(stash_detail_lbl)
	_sec(rv, "升级用途", "Used in")
	stash_use_lbl = K.wrap("", K.CREAM_DIM)
	rv.add_child(stash_use_lbl)


# ============================================================ 6. 图鉴视图（手册：左侧分类树 + 搜索，右侧详情）
func _build_codex_view(parent: Control) -> void:
	var v_c := _view(parent, "codex")
	const LW := 320.0

	var lp := _tpanel(v_c, "手册", "Handbook", LEFT, [K.M, K.GAP, K.M + LW, -K.GAP])
	var lv: VBoxContainer = lp[1]
	codex_search = LineEdit.new()
	codex_search.placeholder_text = "搜索条目……"
	codex_search.custom_minimum_size = Vector2(0, 28)
	codex_search.text_changed.connect(func(_t): _populate_codex_list())
	lv.add_child(codex_search)
	codex_tree = Tree.new()
	codex_tree.hide_root = true
	codex_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	codex_tree.item_selected.connect(func():
		var it := codex_tree.get_selected()
		if it and it.get_metadata(0) is Array:
			var md: Array = it.get_metadata(0)
			codex_tab = str(md[0])
			_show_codex(str(md[0]), str(md[1])))
	lv.add_child(codex_tree)

	var rpp := _tpanel(v_c, "条目", "Entry", FILL, [K.M + LW + K.GAP, K.GAP, -K.M, -K.GAP])
	codex_path_lbl = rpp[2]
	var rv: VBoxContainer = rpp[1]
	var top_card := K.card(false, 10)
	rv.add_child(top_card)
	var ch := K.hbox(14)
	top_card.add_child(ch)
	codex_avatar = K.Avatar.new(128, "nao", "on")
	ch.add_child(codex_avatar)
	codex_portrait = TextureRect.new()
	codex_portrait.custom_minimum_size = Vector2(80, 80)
	codex_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	codex_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	codex_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	codex_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ch.add_child(codex_portrait)
	var cv := K.vbox(6)
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ch.add_child(cv)
	codex_title_lbl = UI.label("", 24, UI.ACCENT)
	codex_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(codex_title_lbl)
	codex_sub_lbl = UI.label("", 12, UI.INFO)
	codex_sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(codex_sub_lbl)
	var r := K.Rule.new()
	r.solid = true
	cv.add_child(r)
	codex_growth_lbl = K.wrap("", K.CREAM_DIM)
	cv.add_child(codex_growth_lbl)

	codex_stat_card = K.card()
	rv.add_child(codex_stat_card)
	codex_stat_grid = GridContainer.new()
	codex_stat_grid.columns = 6
	codex_stat_grid.add_theme_constant_override("h_separation", 12)
	codex_stat_grid.add_theme_constant_override("v_separation", 4)
	codex_stat_card.add_child(codex_stat_grid)

	_sec(rv, "档案简述", "Profile")
	var desc_p := K.card(false, 10)
	desc_p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(desc_p)
	var dh := K.hbox(16)
	desc_p.add_child(dh)
	codex_detail_lbl = K.wrap("", K.CREAM)
	codex_detail_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	codex_detail_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dh.add_child(codex_detail_lbl)
	## 人物立绘：1024 → 256 正好 1/4，最近邻缩小不丢像素格
	codex_full = TextureRect.new()
	codex_full.custom_minimum_size = Vector2(256, 256)
	codex_full.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	codex_full.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	codex_full.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	codex_full_box = PanelContainer.new()
	codex_full_box.add_theme_stylebox_override("panel", K.px9("inset9", 6, 6, 4, 4))
	codex_full_box.size_flags_vertical = Control.SIZE_SHRINK_END
	codex_full_box.add_child(codex_full)
	dh.add_child(codex_full_box)


func _char_name(k: String) -> String:
	var info: Dictionary = CHAR_PROFILES.get(k, {})
	var n := str(info.get("name", k))
	if k == Growth.PROTAGONIST and Growth.player_name() != Growth.DEFAULT_PLAYER_NAME:
		n = Growth.player_name()
	return n


## 手册分类树：人物（主角团 / 商人）、机甲模块（按槽位）、深渊异体（常规 / 领主）、战区；搜索框按名称过滤
func _populate_codex_list() -> void:
	if codex_tree == null:
		return
	codex_tree.clear()
	codex_ids.clear()
	codex_items.clear()
	var q := codex_search.text.strip_edges() if codex_search else ""
	var root := codex_tree.create_item()
	var folders := {}
	var add_leaf := func(parent: TreeItem, tab: String, id: String, text: String, icon: Texture2D, col: Color) -> void:
		if q != "" and text.find(q) < 0:
			return
		var it := codex_tree.create_item(parent)
		it.set_text(0, text)
		if icon:
			it.set_icon(0, icon)
			it.set_icon_max_width(0, 20)
		it.set_custom_color(0, col)
		it.set_metadata(0, [tab, id])
		codex_items["%s/%s" % [tab, id]] = it
		if tab == codex_tab:
			codex_ids.append(id)
	var folder := func(parent: TreeItem, text: String, en: String) -> TreeItem:
		var f := codex_tree.create_item(parent)
		f.set_text(0, "%s  %s" % [text, en])
		f.set_custom_color(0, K.CREAM_DIM)
		f.set_selectable(0, false)
		return f
	var f_crew: TreeItem = folder.call(root, "人物档案", "PERSONNEL")
	var f_c1: TreeItem = folder.call(f_crew, "主角团", "CREW")
	for k in K.CREW:
		add_leaf.call(f_c1, "crew", k, _char_name(k), K.avatar_tex(k, 20), K.CREAM)
	var f_c2: TreeItem = folder.call(f_crew, "黑市商人", "TRADERS")
	for k in K.MERCHANT_IDS:
		add_leaf.call(f_c2, "crew", k, _char_name(k), K.avatar_tex(k, 20), K.CREAM)
	var f_mod: TreeItem = folder.call(root, "机甲模块", "MODULES")
	var slots := {}
	var m_keys := GameData.MODULES.keys()
	m_keys.sort_custom(func(a, b):
		var ma = GameData.MODULES[a]
		var mb = GameData.MODULES[b]
		if ma.slot != mb.slot:
			return str(ma.slot) < str(mb.slot)
		return int(ma.rar) > int(mb.rar))
	for id in m_keys:
		var m = GameData.MODULES[id]
		var s := str(m.slot)
		if not slots.has(s):
			slots[s] = folder.call(f_mod, str(GameData.SLOT_NAMES.get(s, "手臂武装" if s == "arm" else s)), str(SLOT_EN.get(s, s)).to_upper())
		add_leaf.call(slots[s], "module", id, str(m.name), Icons.icon(id), GameData.RARITY_COLORS[int(m.rar)])
	var f_en: TreeItem = folder.call(root, "深渊异体", "BESTIARY")
	var f_e1: TreeItem = folder.call(f_en, "常规群落", "COMMON")
	var f_e2: TreeItem = folder.call(f_en, "领主级", "BOSS")
	for k in GameData.ENEMIES.keys():
		var ed: Dictionary = GameData.ENEMIES[k]
		add_leaf.call(f_e2 if ed.get("boss", false) else f_e1, "enemy", k, str(ed.get("name", k)), null, UI.BAD.lerp(K.CREAM, 0.4))
	var f_map: TreeItem = folder.call(root, "战区档案", "LOCATIONS")
	for id in GameData.map_ids():
		var md: Dictionary = GameData.MAPS[id]
		add_leaf.call(f_map, "map", id, str(md.name), null, K.CREAM)
	# 只展开当前分类，其余折叠（搜索时全部展开）
	for f in [f_crew, f_mod, f_en, f_map]:
		f.collapsed = q == "" and not ((f == f_crew and codex_tab == "crew") or (f == f_mod and codex_tab == "module") or (f == f_en and codex_tab == "enemy") or (f == f_map and codex_tab == "map"))
	for s in slots:
		slots[s].collapsed = false
	if not codex_ids.is_empty():
		_codex_select(codex_tab, str(codex_ids[0]))


func _codex_select(tab: String, id: String) -> void:
	var it: TreeItem = codex_items.get("%s/%s" % [tab, id])
	if it == null:
		return
	var p := it.get_parent()
	while p:
		p.collapsed = false
		p = p.get_parent()
	it.select(0)
	codex_tree.scroll_to_item(it)
	_show_codex(tab, id)


## 兼容旧接口：按当前分类的序号显示
func _on_codex_selected(idx: int) -> void:
	if idx >= 0 and idx < codex_ids.size():
		_codex_select(codex_tab, str(codex_ids[idx]))


func _stat_cell(k: String, v: String, c: Color) -> void:
	codex_stat_grid.add_child(UI.label(k, 12, K.CREAM_DIM))
	codex_stat_grid.add_child(UI.label(v, 12, c))


func _show_codex(tab: String, id: String) -> void:
	for c in codex_stat_grid.get_children():
		codex_stat_grid.remove_child(c)
		c.queue_free()
	codex_avatar.visible = tab == "crew"
	codex_portrait.visible = false
	codex_growth_lbl.text = ""
	codex_full_box.visible = tab == "crew"
	codex_path_lbl.text = {"crew": "人物档案", "module": "机甲模块", "enemy": "深渊异体", "map": "战区档案"}.get(tab, "")
	match tab:
		"crew":
			var p: Dictionary = CHAR_PROFILES.get(id, {})
			codex_avatar.set_char(id, 128)
			codex_full.texture = AssetPaths.portrait(id)
			codex_avatar.set_state("lead" if id == Growth.PROTAGONIST else "on")
			codex_title_lbl.text = _char_name(id)
			codex_sub_lbl.text = Growth.subst(str(p.get("role", "")))
			codex_detail_lbl.text = Growth.subst(str(p.get("desc", "")))
			var g: Array = []
			if Growth.pilot_ids().has(id):
				g.append("驾驶员 Lv%d" % Growth.pilot_level(id))
			for pid in Growth.pod_ids():
				if Growth.pod_pilot(pid) == id:
					g.append(("部署仓 T%d" % Growth.pod_tier(pid)) if Growth.pod_tier(pid) > 0 else "部署仓 未购置")
			if Growth.crew_ids().has(id):
				g.append("好感 Lv%d / %d" % [Growth.crew_level(id), Growth.CREW_MAX])
			codex_growth_lbl.text = "  ·  ".join(g)
		"module":
			var m: Dictionary = GameData.MODULES.get(id, {})
			codex_portrait.texture = Icons.icon(id)
			codex_portrait.visible = true
			codex_title_lbl.text = str(m.get("name", ""))
			codex_sub_lbl.text = "%s模块 · %s · %dkg · ¥%d" % [GameData.SLOT_NAMES.get(m.get("slot", ""), ""), GameData.RARITY_NAMES[int(m.get("rar", 0))], int(m.get("w", 0)), int(m.get("v", 0))]
			codex_detail_lbl.text = Growth.subst(str(m.get("desc", "军用标准模块。")))
			var name_map := {"hp": "结构", "energy": "能源", "speed": "速度", "load": "承重", "cargo": "货舱", "armor": "护甲", "dmg": "伤害", "rate": "射速", "range": "射程"}
			for stat_k in ["hp", "energy", "speed", "load", "cargo", "armor", "dmg", "rate", "range"]:
				if m.has(stat_k):
					_stat_cell(name_map[stat_k], str(m[stat_k]), UI.INFO)
		"enemy":
			var e: Dictionary = GameData.ENEMIES.get(id, {})
			codex_title_lbl.text = str(e.get("name", id))
			codex_sub_lbl.text = "深渊异化生物 · %s" % ("领主级" if e.get("boss", false) else "常规群落")
			codex_detail_lbl.text = str(e.get("desc", "游荡在深渊裂缝周边的异化生物，极具攻击性。"))
			var name_map := {"hp": "生命", "speed": "移动速度", "armor": "护甲值", "dmg": "近战杀伤"}
			for stat_k in ["hp", "speed", "armor", "dmg"]:
				if e.has(stat_k):
					_stat_cell(name_map[stat_k], str(e[stat_k]), UI.BAD)
		"map":
			var md: Dictionary = GameData.MAPS.get(id, {})
			codex_title_lbl.text = str(md.get("name", id))
			codex_sub_lbl.text = "空投战区 · %s" % str(md.get("tag", ""))
			codex_detail_lbl.text = "%s\n\n环境特性：%s" % [str(md.get("desc", "")), str(md.get("env", "无特殊异常"))]
	codex_stat_card.visible = codex_stat_grid.get_child_count() > 0



# ============================================================ 3D 机库背景
func _build_hangar() -> void:
	# 按窗口真实像素渲染（原来固定 1280×720 再放大，高分屏发糊）
	var svc := UI.HiResView.new()
	svc.gui_input.connect(_on_view_input)
	add_child(svc)
	var sv: SubViewport = svc.sv
	sv.own_world_3d = true
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
	if junk_lbl:
		var junk := 0
		for id in Growth.material_ids():
			junk += Growth.material_count(str(id))
		junk_lbl.text = "杂物 ×%d" % junk
	if record_lbl:
		record_lbl.text = "出击 %d · 撤离 %d" % [GameData.raids, GameData.extracts_ok]
	_refresh_crew()
	RenderingServer.global_shader_parameter_set("mech_damage", 0.0)

	if preview_mech and is_instance_valid(preview_mech):
		MV.apply(preview_mech, GameData.loadout, true)
	elif turntable:
		preview_mech = MV.build(GameData.loadout)
		turntable.add_child(preview_mech)
		preview_mech.position.y = 0.2
		preview_mech.rotation.y = PI

	var mass := 0.0
	for slot in GameData.SLOTS:
		if not slot_name_lbls.has(slot):
			continue
		var id: String = GameData.loadout.get(slot, "")
		var nl: Label = slot_name_lbls[slot]
		var stl: Label = slot_stat_lbls[slot]
		if id == "":
			nl.text = "— 空槽 —"
			nl.add_theme_color_override("font_color", Color(0.42, 0.42, 0.38))
			stl.text = "点击或拖入模块"
			slot_cells[slot].set_entry({})
		else:
			var m: Dictionary = GameData.module(id)
			nl.text = GameData.item_name(id)
			nl.add_theme_color_override("font_color", GameData.RARITY_COLORS[int(m.rar)])
			stl.text = "%s · %dkg" % [GameData.RARITY_NAMES[int(m.rar)], int(m.w)]
			slot_cells[slot].set_entry({"id": id})
			mass += float(m.w)

	var st := GameData.compute_stats(GameData.loadout)
	var cw := GameData.weight_of(GameData.cargo)
	var sf := GameData.speed_factor(st, cw)
	var runtime: float = st.energy / max(0.01, st.drain)
	if not stat_rows.is_empty():
		_stat("hp", st.hp, 300.0, "%d" % st.hp)
		_stat("armor", float(st.get("armor", 0.0)), 0.5, "%d%%" % int(round(float(st.get("armor", 0.0)) * 100)))
		_stat("energy", st.energy, 250.0, "%d · %d:%02d" % [st.energy, int(runtime) / 60, int(runtime) % 60])
		_stat("speed", st.speed * sf, 10.0, "%.1f%s" % [st.speed * sf, "" if sf > 0.99 else " ↓"])
		_stat("load", st.mass + cw, max(1.0, st.load), "%.0f / %.0f" % [st.mass + cw, st.load])
		_stat("cargo", cw, max(1.0, st.cargo), "%.1f / %.0f" % [cw, st.cargo])
		var lr: Array = stat_rows["load"]
		lr[0].color = Color(0.75, 0.6, 1.0) if sf > 0.99 else UI.BAD
		lr[1].add_theme_color_override("font_color", K.CREAM if sf > 0.99 else UI.BAD)
	if maint_mass_lbl:
		maint_mass_lbl.text = "模块 %.0f kg" % mass
	_refresh_maint_side()

	_populate_cargo()
	if cargo_lbl:
		cargo_lbl.text = "%.1f / %.0f kg" % [cw, st.cargo]
		cargo_lbl.add_theme_color_override("font_color", UI.BAD if cw > st.cargo else K.CREAM_DIM)

	var err := GameData.can_deploy(GameData.loadout)
	if deploy_err:
		deploy_err.text = err
		deploy_err.visible = err != ""
	if deploy_btn:
		deploy_btn.disabled = (err != "")
	_refresh_checklist(st, cw, err)
	_refresh_squad()

	_populate_stash_list()
	_populate_maint_grid()
	_populate_deploy_stash()
	_refresh_shop()
	_refresh_trade_list()
	_update_deal()

	var rq := GameData.request
	if request_lbl and not rq.is_empty():
		var have := GameData.count_in_stash(rq.id)
		request_lbl.text = "%s 的委托\n需要 %s ×%d（仓库现有 %d）" % [rq.who, GameData.item_name(rq.id), rq.count, have]
		request_lbl.add_theme_color_override("font_color", UI.GOOD if have >= int(rq.count) else K.CREAM)
		request_reward_lbl.text = "报酬 ¥ %s" % _fmt_money(int(rq.reward))
		var who := str(rq.get("char", ""))
		if who == "":
			who = str((Growth.tables().get("WHO_CHAR", {}) as Dictionary).get(str(rq.who), "lina"))
		request_avatar.set_char(who, 96)

	if codex_tree and codex_items.is_empty():
		_populate_codex_list()
	if cur_tab == "skills":
		_rebuild_skills()


func _refresh_crew() -> void:
	if lead_name_lbl:
		var pid := Growth.PROTAGONIST
		var lv := Growth.pilot_level(pid)
		var need := Growth.pilot_xp_next(lv)
		lead_name_lbl.text = Growth.player_name()
		lead_sub_lbl.text = "Lv%d" % lv
		lead_xp_bar.set_frac(1.0 if need <= 0 else float(Growth.pilot_xp(pid)) / need)
		lead_xp_bar.tooltip_text = "满级" if need <= 0 else "%d / %d EXP" % [Growth.pilot_xp(pid), need]
	for cid in crew_avatars:
		var av = crew_avatars[cid]
		var tip := "%s · %s" % [Growth.player_name() if cid == Growth.PROTAGONIST else str(CHAR_PROFILES.get(cid, {}).get("name", cid)).split(" · ")[0], CREW_ROLE.get(cid, "")]
		if cid == Growth.PROTAGONIST:
			var lv := Growth.pilot_level(cid)
			var need := Growth.pilot_xp_next(lv)
			tip += "\nLv%d · %s · 天赋点 %d" % [lv, "满级" if need <= 0 else "%d/%d EXP" % [Growth.pilot_xp(cid), need], Growth.pilot_points(cid)]
		for pid in Growth.pod_ids():
			if Growth.pod_pilot(pid) == cid:
				av.dim = Growth.pod_tier(pid) == 0
				tip += "（%s）" % (("T%d" % Growth.pod_tier(pid)) if Growth.pod_tier(pid) > 0 else "部署仓未购置")
				av.queue_redraw()
		if Growth.crew_ids().has(cid):
			tip += "\n好感 Lv%d" % Growth.crew_level(cid)
		av.tooltip_text = tip


func _refresh_maint_side() -> void:
	if maint_squad_lbl == null:
		return
	var sq := Growth.ally_squad()
	var names: Array = []
	for a in sq:
		names.append("%s T%d" % [str(Growth.pilot_data(str(a.pilot)).get("name", a.pilot)), int(a.tier)])
	maint_squad_lbl.text = "随行：" + ("单机出击" if names.is_empty() else "、".join(names))


func _refresh_trade_list() -> void:
	for m_id in merchant_cards:
		var b: Button = merchant_cards[m_id]
		var aff: HBoxContainer = b.get_meta("aff")
		for c in aff.get_children():
			aff.remove_child(c)
			c.queue_free()
		aff.alignment = BoxContainer.ALIGNMENT_CENTER
		if Growth.crew_ids().has(m_id):
			aff.add_child(UI.label("好感", 12, K.CREAM_DIM))
			var p = K.Pips.new(Growth.CREW_MAX)
			p.set_level(Growth.crew_level(m_id))
			aff.add_child(p)
			aff.add_child(UI.label("Lv%d" % Growth.crew_level(m_id), 12, UI.ACCENT))
		else:
			aff.add_child(UI.label("好感 —  尚无往来", 12, Color(0.42, 0.42, 0.38)))
		var n := 0
		for id in MERCHANTS[m_id].get("items", []):
			if GameData.ITEMS.has(id):
				n += 1
		(b.get_meta("stock") as Label).text = "供货 %d 种" % n
	if account_box:
		for c in account_box.get_children():
			account_box.remove_child(c)
			c.queue_free()
		account_box.add_child(K.kv("信用点", "¥ %s" % _fmt_money(GameData.money), Color(1.0, 0.85, 0.4)))
		account_box.add_child(K.kv("仓库物品", "%d 件" % GameData.stash.size()))
		account_box.add_child(K.kv("仓库估值", "¥ %s" % _fmt_money(GameData.value_of(GameData.stash))))
		var junk := 0
		for id in GameData.stash:
			var c: String = GameData.item(id).cat
			if c == "food" or c == "misc":
				junk += int(GameData.item(id).v)
		account_box.add_child(K.kv("食物与杂物可售", "¥ %s" % _fmt_money(junk)))


func _populate_stash_list() -> void:
	if not stash_list:
		return
	var es := _stack(GameData.stash, stash_filter)
	stash_ids.clear()
	for e in es:
		stash_ids.append(e.id)
	stash_list.set_entries(es)
	if stash_count_lbl:
		stash_count_lbl.text = "%d 件 · %.1f kg · 估值 ¥%s" % [GameData.stash.size(), GameData.weight_of(GameData.stash), _fmt_money(GameData.value_of(GameData.stash))]
	var i := stash_ids.find(selected_stash)
	stash_list.select(i)


func _populate_maint_grid() -> void:
	if maint_grid == null:
		return
	var es := _stack(GameData.stash, maint_filter)
	maint_ids.clear()
	for e in es:
		maint_ids.append(e.id)
		if GameData.is_module(str(e.id)):
			e["hint"] = "双击装备 · 拖到左侧槽位"
	maint_grid.set_entries(es)
	if maint_count_lbl:
		maint_count_lbl.text = "%d 件 · %.1f kg" % [GameData.stash.size(), GameData.weight_of(GameData.stash)]


func _populate_deploy_stash() -> void:
	if not deploy_stash_list:
		return
	var es: Array = []
	deploy_stash_ids.clear()
	for e in _stack(GameData.stash):
		var it := GameData.item(e.id)
		if it.cat == "use" or it.cat == "food":
			e["hint"] = "双击或拖到右侧装入货舱"
			es.append(e)
			deploy_stash_ids.append(e.id)
	deploy_stash_list.empty_text = "仓库里没有消耗品或食物。"
	deploy_stash_list.set_entries(es)


func _populate_cargo() -> void:
	if not cargo_list:
		return
	var es := _stack(GameData.cargo)
	cargo_ids.clear()
	for e in es:
		cargo_ids.append(e.id)
		e["hint"] = "双击或拖回左侧退回仓库"
	cargo_list.empty_text = "货舱是空的：从左侧装入消耗品与食物。"
	cargo_list.set_entries(es)


func _refresh_shop() -> void:
	if not shop_list:
		return
	shop_ids.clear()
	var es: Array = []
	var md: Dictionary = MERCHANTS.get(cur_merchant, {})
	for id in md.get("items", []):
		if not GameData.ITEMS.has(id):
			continue
		var p := _price(id)
		es.append({"id": id, "price": p, "bad": GameData.money < p, "hint": "双击买入 · ¥%s" % _fmt_money(p)})
		shop_ids.append(id)
	shop_list.set_entries(es)
	if selected_shop >= 0 and selected_shop < shop_ids.size():
		shop_list.select(selected_shop)
	if shop_count_lbl:
		shop_count_lbl.text = "%d 种商品" % shop_ids.size()
	if trade_stash_grid:
		var ts := _stack(GameData.stash)
		trade_stash_ids.clear()
		for e in ts:
			trade_stash_ids.append(e.id)
			e["hint"] = "收购价 ¥%s · 双击卖出" % _fmt_money(int(GameData.item(e.id).v))
		trade_stash_grid.set_entries(ts)
		if trade_side == "sell":
			trade_stash_grid.select(trade_stash_ids.find(selected_stash))


func _stat(k: String, v: float, mx: float, txt: String) -> void:
	var row: Array = stat_rows[k]
	row[0].set_frac(v / maxf(0.001, mx))
	row[1].text = txt


func _fmt_money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func _price(id: String) -> int:
	return int(GameData.item(id).v * 1.25)


func _on_stash_selected(i: int) -> void:
	if i < 0 or i >= stash_ids.size():
		return
	selected_stash = stash_ids[i]
	if stash_list and stash_list.selected != i:
		stash_list.select(i)
	var it := GameData.item(selected_stash)
	var rar := int(it.rar)
	stash_name_lbl.text = str(it.name)
	stash_name_lbl.add_theme_color_override("font_color", GameData.RARITY_COLORS[rar])
	for c in stash_tag_box.get_children():
		c.queue_free()
	stash_tag_box.add_child(K.tag(GameData.RARITY_NAMES[rar], rar > 0))
	stash_tag_box.add_child(K.tag(str(GameData.CAT_NAMES.get(it.cat, "?")), false))
	for c in stash_kv_box.get_children():
		stash_kv_box.remove_child(c)
		c.queue_free()
	stash_kv_box.add_child(K.kv("重量", "%.1f kg" % float(it.w)))
	stash_kv_box.add_child(K.kv("价值", "¥ %s" % _fmt_money(int(it.v)), Color(1.0, 0.85, 0.4)))
	stash_kv_box.add_child(K.kv("库存", "×%d" % GameData.count_in_stash(selected_stash)))
	stash_kv_box.add_child(K.kv("合计重量", "%.1f kg" % (float(it.w) * GameData.count_in_stash(selected_stash))))
	if it.cat == "module":
		var m: Dictionary = GameData.module(selected_stash)
		stash_kv_box.add_child(K.kv("槽位", str(GameData.SLOT_NAMES.get(str(m.get("slot", "")), "手臂武装"))))
		var names := {"hp": "结构", "cargo": "货舱", "energy": "能源", "speed": "速度", "load": "承重", "dmg": "伤害", "rate": "射速", "armor": "护甲"}
		for k in ["hp", "cargo", "energy", "speed", "load", "dmg", "rate", "armor"]:
			if m.has(k):
				stash_kv_box.add_child(K.kv(names[k], str(m[k]), UI.INFO))
	if stash_detail_lbl:
		stash_detail_lbl.text = Growth.subst(str(it.get("desc", "")))
	if stash_icon_rect:
		stash_icon_rect.set_entry({"id": selected_stash, "count": GameData.count_in_stash(selected_stash)})
	if stash_use_lbl:
		var uses := Growth.material_uses(selected_stash)
		stash_use_lbl.text = ("可用于：" + "、".join(uses)) if not uses.is_empty() else "当前没有升级项目需要这件物资。"
		stash_use_lbl.add_theme_color_override("font_color", UI.INFO if not uses.is_empty() else K.CREAM_DIM)


func _move_to_cargo() -> void:
	if selected_stash == "" or not GameData.stash.has(selected_stash):
		Audio.play_ui("ui_denied")
		return
	var st := GameData.compute_stats(GameData.loadout)
	if GameData.weight_of(GameData.cargo) + float(GameData.item(selected_stash).w) > st.cargo:
		if deploy_err:
			deploy_err.text = "出击货舱超出承重上限"
			deploy_err.visible = true
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


func _cargo_back_id(id: String) -> void:
	_cargo_back(GameData.cargo.find(id))


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
		if deal_info_lbl:
			deal_info_lbl.text = "账户信用点不足"
		Audio.play_ui("ui_denied")
		return
	GameData.money -= p
	GameData.stash.append(id)
	selected_shop = i
	trade_side = "buy"
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
			popup.add_icon_item(Icons.icon(id), "装备  %s（%s）" % [GameData.item_name(id), GameData.RARITY_NAMES[int(GameData.item(id).rar)]], n)
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
	if id == 999:
		_unequip(popup_slot)
	elif popup_map.has(id):
		_equip_to(popup_slot, str(popup_map[id]))


## 把仓库里的模块装到槽位（原模块退回仓库）
func _equip_to(slot: String, new_id: String) -> void:
	if not GameData.stash.has(new_id) or not GameData.slot_accepts(slot, new_id):
		Audio.play_ui("ui_denied")
		return
	var cur: String = GameData.loadout.get(slot, "")
	GameData.stash.erase(new_id)
	if cur != "":
		GameData.stash.append(cur)
		Audio.play_ui("hub_detach")
	GameData.loadout[slot] = new_id
	get_tree().create_timer(0.45 if cur != "" else 0.28).timeout.connect(func(): Audio.play_ui("hub_dock"))
	refresh()


func _unequip(slot: String) -> void:
	var cur: String = GameData.loadout.get(slot, "")
	if cur == "":
		return
	GameData.loadout[slot] = ""
	GameData.stash.append(cur)
	Audio.play_ui("hub_detach")
	refresh()


## 双击模块：装到第一个能装的槽位（优先空槽）
func _quick_equip(id: String) -> void:
	if not GameData.is_module(id):
		selected_stash = id
		return
	var target := ""
	for slot in GameData.SLOTS:
		if GameData.slot_accepts(slot, id):
			if GameData.loadout.get(slot, "") == "":
				target = slot
				break
			if target == "":
				target = slot
	if target == "":
		Audio.play_ui("ui_denied")
		return
	_equip_to(target, id)


## 右键菜单：装备 / 装入货舱 / 出售 / 在仓库页查看
func _open_ctx(id: String, from: String) -> void:
	ctx_id = id
	ctx_from = from
	selected_stash = id
	ctx_popup.clear()
	var it := GameData.item(id)
	if GameData.is_module(id):
		for slot in GameData.SLOTS:
			if GameData.slot_accepts(slot, id):
				ctx_popup.add_item("装备到 %s" % GameData.SLOT_NAMES[slot], GameData.SLOTS.find(slot))
	if it.cat == "use" or it.cat == "food":
		ctx_popup.add_item("装入出击货舱", 100)
	ctx_popup.add_item("出售 1 件（¥%s）" % _fmt_money(int(it.v)), 101)
	if cur_tab != "stash":
		ctx_popup.add_item("在仓库页查看", 102)
	ctx_popup.popup(Rect2i(Vector2i(get_global_mouse_position()), Vector2i(200, 0)))


func _on_ctx(n: int) -> void:
	if n >= 0 and n < GameData.SLOTS.size():
		_equip_to(GameData.SLOTS[n], ctx_id)
	elif n == 100:
		selected_stash = ctx_id
		_move_to_cargo()
	elif n == 101:
		selected_stash = ctx_id
		_sell_selected()
	elif n == 102:
		_switch_tab("stash")
		var i := stash_ids.find(ctx_id)
		if i >= 0:
			_on_stash_selected(i)


func _list() -> ItemList:
	var l := ItemList.new()
	l.max_text_lines = 2
	l.fixed_icon_size = Vector2i(20, 20)
	return l


func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 32)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.set_meta("sfx", "")
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
