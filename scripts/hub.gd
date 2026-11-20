extends Control
## 飞空艇「信天翁号」主界面：二级菜单（整备 / 交易 / 降落 / 技能 / 仓库 / 图鉴）
## v0.7 版式参考「逃离塔科夫」主界面结构（保留本作像素风与世界观）：
##   顶部 36px 细状态栏（舰名 · 驾驶员等级与经验 · 主角团 · 战绩 · 杂物 · 资金 · 舰时），
##   底部 48px 等宽主导航栏（当前页琥珀顶线高亮），中间内容区外边距 12、栏间距 8。
##   整备 = 装备槽列 + 3D 机甲 + 仓库网格 + 属性汇总条；仓库 = 大网格 + 分类筛选 + 物品详情；
##   交易 = 商人头像卡横排 → 商人货架网格 / 玩家仓库网格 / 交易确认栏；降落 = 战区地图 → 确认携带 → 出发；
##   技能 = 设施卡片网格（需求红绿标识）；图鉴 = 手册式左侧分类树 + 右侧详情。
## 部件见 scripts/hub_kit.gd，物品图标见 scripts/item_icons.gd。

signal deploy_requested

const MV = preload("res://scripts/mech_visual.gd")
const MechScript = preload("res://scripts/mech.gd")
const A = preload("res://scripts/art.gd")
const UI = preload("res://scripts/ui.gd")
const K = preload("res://scripts/hub_kit.gd")
const HUD = preload("res://scripts/hud.gd")
const Growth = preload("res://scripts/progression/growth.gd")
const AssetPaths = preload("res://scripts/asset_paths.gd")
const Icons = preload("res://scripts/item_icons.gd")
const WorldLink = preload("res://scripts/world_link.gd")
const WorldMapView = preload("res://scripts/world_map_view.gd")
const PageMotion = preload("res://scripts/ui_transition.gd")
const AlbatrossAirship = preload("res://scripts/airship/airship_albatross.gd")

## 3D 机库背景与转台
var preview_root: Node3D
var airship: Node3D
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
var _settings_overlay: Control
var _settings_panel: PanelContainer
var _settings_tab := "video"
var _fps_spacer: Control

## 视图容器
var views := {}
var _view_tweens: Dictionary = {}
var _view_modes: Dictionary = {}
var _deploy_tweens: Dictionary = {}
var _deploy_modes: Dictionary = {}
var tab_bg: Control
const TAB_TINT := {
	"trade": Color(0.78, 0.48, 0.16),
	"deploy": Color(0.52, 0.56, 0.58),
	"skills": Color(0.46, 0.72, 0.50),
	"stash": Color(0.72, 0.52, 0.24),
	"codex": Color(0.48, 0.52, 0.55),
}


class Hd2Backdrop extends Control:
	var accent := Color(0.78, 0.48, 0.16)

	func set_tab(tab_key: String) -> void:
		accent = TAB_TINT.get(tab_key, Color(0.78, 0.48, 0.16))
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect_filled_grad(r)
		var step := 48.0
		var grid_c := Color(0.38, 0.41, 0.44, 0.045)
		var x := 0.0
		while x <= size.x:
			draw_line(Vector2(x, 0.0), Vector2(x, size.y), grid_c, 1.0)
			x += step
		var y := 0.0
		while y <= size.y:
			draw_line(Vector2(0.0, y), Vector2(size.x, y), grid_c, 1.0)
			y += step
		# 隔行工业校准十字线（灰黑钢线）与横向舱壁接缝
		var cross_c := Color(0.46, 0.49, 0.52, 0.09)
		var gx := step * 2.0
		while gx < size.x:
			var gy := step * 2.0
			while gy < size.y:
				draw_line(Vector2(gx - 4.0, gy), Vector2(gx + 4.0, gy), cross_c, 1.0)
				draw_line(Vector2(gx, gy - 4.0), Vector2(gx, gy + 4.0), cross_c, 1.0)
				gy += step * 2.0
			gx += step * 2.0
		draw_line(Vector2(0.0, size.y * 0.5), Vector2(size.x, size.y * 0.5), Color(0.05, 0.055, 0.06, 0.55), 2.0)
		var ac := Color(accent.r, accent.g, accent.b, 0.10)
		var sc := Color(0.38, 0.41, 0.44, 0.10)
		for k in 5:
			var ox := size.x - 240.0 + float(k) * 32.0
			draw_line(Vector2(ox, 0.0), Vector2(ox + 160.0, 160.0), ac if k % 2 == 0 else sc, 2.0, true)

	func draw_rect_filled_grad(r: Rect2) -> void:
		var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		var c0 := Color(0.062, 0.068, 0.074, 0.98)
		var c1 := Color(0.092, 0.100, 0.108, 0.98)
		draw_polygon(pts, PackedColorArray([c0, c0, c1, c1]))
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
var request_list: HBoxContainer
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
var stash_tag_box: HFlowContainer
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
func _dir_name(d: String) -> String:
	match d:
		"N": return Loc.t("北", "N")
		"S": return Loc.t("南", "S")
		"E": return Loc.t("东", "E")
		"W": return Loc.t("西", "W")
	return d
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
		"items": ["arm_mg", "arm_shotgun", "arm_flamer", "arm_laser", "legs_biped_scout", "legs_tread_light", "legs_quad_hound", "wire", "bolts"]
	},
	"shiori": {
		"name": "诗织",
		"role": "违禁生物与深渊样本商",
		"desc": "覆灭研究所的幸存学者。收购异化甲壳与虫晶活体样本，出售特种生物制剂与异化插件。",
		"items": ["chitin", "bug_crystal", "legs_hex_ant", "legs_hex_beetle", "coolant_pack", "surge_cell"]
	},
	"karasu": {
		"name": "鸦",
		"role": "重型装甲与特种弹药匠",
		"desc": "地下工坊老铁匠。追求极端防护厚度与大口径穿甲杀伤，专营防爆装甲与重型工业模块。",
		"items": ["core_heavy", "legs_tread", "legs_tread_heavy", "legs_biped_assault", "legs_quad_crab", "back_shield", "extract_barrier"]
	},
	"nihong": {
		"name": "霓虹",
		"role": "旧时代电子残骸与黑客情报商",
		"desc": "防空洞基站网瘾电波系。解码旧时代黑匣子与火控芯片，提供战区雷达情报与战术诱饵。",
		"items": ["circuit", "hdd", "legs_hex", "sonic_decoy", "beacon", "extract_flare"]
	},
	"gin": {
		"name": "银",
		"role": "灰烬商会账房与高危悬赏庄家",
		"desc": "灰烬走私财团未成年买办。左眼佩戴黄铜单片镜，专营高危死地悬赏与顶级特种机甲配额。",
		"items": ["credit_s", "credit_l", "gold", "gen_crystal", "legs_titan", "legs_tread_siege", "legs_quad_mammoth", "legs_hex_colossus", "back_missile", "energy_rod"]
	}
}

## 主角团在顶栏的身份短句
const CREW_ROLE := {
	"nao": "主力驾驶员",
	"rei": "自律驾驶员 · 部署仓甲",
	"kurumi": "自律驾驶员 · 部署仓乙",
	"lina": "运输机「格里芬」驾驶员",
	"mia": "机库整备师",
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
		"role": "机甲驾驶员（自律队友） · 16岁",
		"desc": "银白短发遮盖左眼，领口焊有蓝光单目镜头，胸前挂着三枚死难战友的狗牌。性格孤僻寡言，习惯在镜头后观察，极度看重当前小队成员的安全。"
	},
	"kurumi": {
		"name": "胡桃 · 百瀬 くるみ",
		"role": "机甲驾驶员（自律队友） · 15~16岁",
		"desc": "栗棕双马尾用黄色塑料工业扎带绑扎，鼻梁贴创可贴，亮橙工装。野路子出身，喜爱在战场捡拾废旧零件，性格活泼好胜，易害羞但极其勇猛。"
	},
	"lina": {
		"name": "莉娜 · リナ・クラウゼ",
		"role": "运输机「格里芬」驾驶员 · 17岁",
		"desc": "金短发、黑框眼镜、制服笔挺的前正规军校学员。负责后勤与战区撤离接应，平日教条爱念叨，但在极端战场危险下坚决死守悬停接回全员。"
	},
	"mia": {
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
	var _drop_hot := false    ## 指针悬停在本槽且可放置
	var _drag_valid := false  ## 本槽接受当前拖起中的物品（细描边示可装备位）

	func _ready() -> void:
		draw.connect(_hot_overlay)

	func _set_hot(v: bool) -> void:
		if _drop_hot != v:
			_drop_hot = v
			queue_redraw()

	func _set_valid(v: bool) -> void:
		if _drag_valid != v:
			_drag_valid = v
			queue_redraw()

	func _hot_overlay() -> void:
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		if _drop_hot:
			draw_rect(r, Color(0.86, 0.62, 0.18, 0.13), true)
			draw_rect(r, Color(0.86, 0.62, 0.18), false, 2.0)
		elif _drag_valid:
			draw_rect(r, Color(0.86, 0.62, 0.18, 0.45), false, 1.0)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT:
			_set_hot(false)
		elif what == NOTIFICATION_DRAG_BEGIN:
			var d = get_viewport().gui_get_drag_data()
			_set_valid(can_fn.is_valid() and d is Dictionary and bool(can_fn.call(d)))
			_set_hot(false)
		elif what == NOTIFICATION_DRAG_END:
			_set_valid(false)
			_set_hot(false)

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		var ok := can_fn.is_valid() and data is Dictionary and bool(can_fn.call(data))
		_set_hot(ok)
		return ok

	func _drop_data(_at: Vector2, data: Variant) -> void:
		_set_hot(false)
		if drop_fn.is_valid():
			drop_fn.call(data)

	func _get_drag_data(_at: Vector2) -> Variant:
		if not drag_fn.is_valid():
			return null
		var d = drag_fn.call()
		if d == null:
			return null
		set_drag_preview(K.drag_preview(str(d.get("id", "")), 1))
		return d

	func _get_tooltip(_at: Vector2) -> String:
		return "1" if tip_fn.is_valid() and tip_fn.call() != null else tooltip_text

	func _make_custom_tooltip(_t: String) -> Object:
		return tip_fn.call() if tip_fn.is_valid() else null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = K.theme()
	_build_hangar()

	# 全屏战术背板（除整备页外覆盖整个机库画幅，避免底栏上方露出 3D 机库条带）
	tab_bg = Hd2Backdrop.new()
	tab_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tab_bg)

	var content := Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_top = K.TOP_H
	content.offset_bottom = -K.BOT_H - 64
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)

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


func _exit_tree() -> void:
	if GameData.show_fps_changed.is_connected(_on_show_fps_changed):
		GameData.show_fps_changed.disconnect(_on_show_fps_changed)


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
	ship.add_child(K.tag(Loc.t("信天翁号", "ALBATROSS"), false))
	ship.add_child(UI.label(Loc.t("三号整备舱", "BAY 03"), 12, K.CREAM_DIM))
	_vsep(th)

	# 驾驶员：头像 + 名称 / 等级 + 经验条；其余主角团小头像（悬停看身份，点击打开图鉴档案）
	for cid in K.CREW:
		var av = K.Avatar.new(20, cid, "lead" if cid == Growth.PROTAGONIST else "n")
		av.mouse_filter = Control.MOUSE_FILTER_STOP
		av.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		crew_avatars[cid] = av
		th.add_child(av)
		if cid == Growth.PROTAGONIST:
			var nv := K.vbox(2)
			nv.custom_minimum_size = Vector2(118, 0)
			nv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var nh := K.hbox(6)
			nv.add_child(nh)
			lead_name_lbl = UI.label("", 12, K.AMBER_HI)
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
	junk_lbl.tooltip_text = Loc.t("仓库里的打捞杂物（升级材料）合计", "Total salvaged materials in stash (for upgrades)")
	junk_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	th.add_child(junk_lbl)
	_vsep(th)
	th.add_child(K.icon_rect(K.small_icon("money"), 16))
	money_lbl = UI.label("", 12, Color(0.74, 0.61, 0.28))
	money_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(money_lbl)
	_vsep(th)
	th.add_child(K.icon_rect(K.small_icon("clock"), 16))
	clock_lbl = UI.label("", 12, K.CREAM)
	clock_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(clock_lbl)

	var codex_btn := Button.new()
	codex_btn.text = Loc.t("图鉴", "Codex")
	codex_btn.tooltip_text = Loc.t("查看世界观、怪物、成员与战利品图鉴", "Browse crew profiles, modules, bestiary, and sector intel")
	codex_btn.custom_minimum_size = Vector2(58, 28)
	codex_btn.pressed.connect(func(): _switch_tab("codex"))
	th.add_child(codex_btn)

	var coop_button := Button.new()
	coop_button.text = Loc.t("联机小队", "Co-op Squad")
	coop_button.custom_minimum_size = Vector2(82, 28)
	coop_button.pressed.connect(func(): get_parent().show_lobby())
	th.add_child(coop_button)

	var settings_btn := Button.new()
	settings_btn.text = Loc.t("设置", "Settings")
	settings_btn.tooltip_text = Loc.t("画面、声音与语言设置", "Video, audio, and language settings")
	settings_btn.custom_minimum_size = Vector2(58, 28)
	settings_btn.pressed.connect(func(): _open_hub_settings())
	th.add_child(settings_btn)

	_fps_spacer = Control.new()
	_fps_spacer.custom_minimum_size = Vector2(82, 1)
	_fps_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_spacer.visible = GameData.show_fps
	th.add_child(_fps_spacer)
	if not GameData.show_fps_changed.is_connected(_on_show_fps_changed):
		GameData.show_fps_changed.connect(_on_show_fps_changed)
	_update_clock()


func _on_show_fps_changed(on: bool) -> void:
	if _fps_spacer != null and is_instance_valid(_fps_spacer):
		_fps_spacer.visible = on


func _update_clock() -> void:
	if clock_lbl:
		var t := Time.get_time_dict_from_system()
		clock_lbl.text = "%02d:%02d" % [int(t.hour), int(t.minute)]


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
	# 左二 / 中间出击圆钮 / 右二，两组等宽展开，整体左右对称
	var left := K.hbox(4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_END
	h.add_child(left)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(136, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(gap)
	var right := K.hbox(4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	h.add_child(right)
	for td in [["maintenance", "整备", "LOADOUT", left], ["trade", "交易", "TRADERS", left],
			["skills", "技能", "HIDEOUT", right], ["stash", "仓库", "STASH", right]]:
		var key: String = td[0]
		var btn = K.NavButton.new(td[1], td[2], "nav_" + key)
		btn.button_group = grp
		btn.pressed.connect(func(): _switch_tab(key))
		nav_buttons[key] = btn
		td[3].add_child(btn)

	# 圆形出击钮：压在底栏中线上，直径 104，向上探出底栏
	var dep = K.DeployButton.new("出击", "SORTIE", "")
	dep.button_group = grp
	dep.pressed.connect(func(): _switch_tab("deploy"))
	nav_buttons["deploy"] = dep
	dep.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dep.offset_left = -52
	dep.offset_right = 52
	dep.offset_top = -104
	dep.offset_bottom = 0
	add_child(dep)


func _finish_page_transition(page: Control, key: Variant, hide_after: bool, tweens: Dictionary, modes: Dictionary) -> void:
	if not is_instance_valid(page):
		tweens.erase(key)
		modes.erase(key)
		return
	PageMotion.clear(page)
	if hide_after:
		page.visible = false
	page.modulate.a = 1.0
	page.process_mode = int(modes.get(key, Node.PROCESS_MODE_INHERIT))
	modes.erase(key)
	tweens.erase(key)


func _transition_page(page: Control, key: Variant, show_page: bool, changed: bool, tweens: Dictionary, modes: Dictionary, enter_delay := 0.0) -> void:
	var old_tw: Tween = tweens.get(key)
	if old_tw != null and old_tw.is_valid():
		old_tw.kill()
		if modes.has(key):
			page.process_mode = int(modes[key])
			modes.erase(key)
		tweens.erase(key)
	PageMotion.clear(page)
	if not changed:
		page.visible = show_page
		page.modulate.a = 1.0
		return
	if show_page:
		page.visible = true
	elif not page.visible:
		page.modulate.a = 1.0
		return
	modes[key] = page.process_mode
	page.process_mode = Node.PROCESS_MODE_DISABLED
	if show_page:
		page.modulate.a = 0.0
	var effect: Control = PageMotion.attach(page, "panels")
	effect.set("progress", 0.0 if show_page else 1.0)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if show_page else Tween.EASE_IN_OUT)
	tweens[key] = tw
	tw.tween_property(effect, "progress", 1.0 if show_page else 0.0, PageMotion.ENTER if show_page else PageMotion.EXIT).set_delay(enter_delay if show_page else 0.0)
	tw.tween_property(page, "modulate:a", 1.0 if show_page else 0.0, PageMotion.ENTER if show_page else PageMotion.EXIT).set_delay(enter_delay if show_page else 0.0)
	tw.finished.connect(_finish_page_transition.bind(page, key, not show_page, tweens, modes))


func _switch_tab(tab_key: String) -> void:
	var changed := tab_key != cur_tab
	cur_tab = tab_key
	for k in nav_buttons:
		nav_buttons[k].button_pressed = (k == tab_key)
	var enter_delay := 0.0
	if changed:
		for k in views:
			if k != tab_key and views[k].visible:
				enter_delay = PageMotion.EXIT
				break
	for k in views:
		var view_key := str(k)
		_transition_page(views[k], view_key, k == tab_key, changed, _view_tweens, _view_modes, enter_delay)
	if tab_bg:
		(tab_bg as Hd2Backdrop).set_tab(tab_key)
		tab_bg.visible = tab_key != "maintenance"
	if hangar_vp:
		hangar_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if tab_key == "maintenance" else SubViewport.UPDATE_DISABLED
	if explode_btn:
		explode_btn.visible = (tab_key == "maintenance")
	if tab_key == "trade":
		_trade_show("list")
	elif tab_key == "deploy":
		_deploy_show(1)
	Audio.play_ui("ui_tab")
	refresh()


func _settings_is_open() -> bool:
	return _settings_overlay != null and is_instance_valid(_settings_overlay) and _settings_overlay.visible


func get_settings_tab() -> String:
	return _settings_tab


func _open_hub_settings(initial_tab := "video") -> void:
	if _settings_overlay != null and is_instance_valid(_settings_overlay):
		if _settings_overlay.get_parent():
			_settings_overlay.get_parent().remove_child(_settings_overlay)
		_settings_overlay.queue_free()
		_settings_overlay = null
		_settings_panel = null
	_settings_tab = initial_tab
	_settings_overlay = Control.new()
	_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.z_index = 90
	_settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_settings_overlay)

	var dimmer := ColorRect.new()
	dimmer.color = Color(0.02, 0.025, 0.035, 0.76)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_overlay.add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_settings_overlay.add_child(center)

	_settings_panel = PanelContainer.new()
	_settings_panel.add_theme_stylebox_override("panel", UI.px9("panel9", 18, 18, 22, 18))
	_settings_panel.custom_minimum_size = Vector2(640, 440)
	center.add_child(_settings_panel)
	UI.bind_fit_panel(_settings_panel)

	var v := K.vbox(10)
	_settings_panel.add_child(v)
	v.add_child(UI.plate_header(Loc.t("系统设置", "Settings"), "SYSTEM SETTINGS"))
	v.add_child(K.hazard_strip(8))

	var row := K.hbox(12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)

	var nav := K.vbox(6)
	nav.custom_minimum_size = Vector2(112, 0)
	row.add_child(nav)

	var body := PanelContainer.new()
	body.add_theme_stylebox_override("panel", K.px9("inset9", 8, 8, 12, 10))
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(body)

	var pages := {}
	var tab_defs := [
		["video", Loc.t("画面", "Video")],
		["audio", Loc.t("声音", "Audio")],
		["other", Loc.t("常规", "General")],
	]
	for td in tab_defs:
		var pg := K.vbox(8)
		pg.visible = false
		body.add_child(pg)
		pages[str(td[0])] = pg

	var nav_btns := {}
	var show_page := func(key: String) -> void:
		_settings_tab = key
		for k in pages:
			(pages[k] as Control).visible = (k == key)
		for k in nav_btns:
			var b: Button = nav_btns[k]
			var on: bool = (k == key)
			b.add_theme_stylebox_override("normal", K.px9("nav9_on" if on else "nav9_n", 10, 10, 12, 6))
			b.add_theme_stylebox_override("hover", K.px9("nav9_on" if on else "nav9_h", 10, 10, 12, 6))
			b.add_theme_color_override("font_color", UI.GOLD if on else UI.TEXT)

	for td in tab_defs:
		var key: String = str(td[0])
		var b := Button.new()
		b.text = str(td[1])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(112, 34)
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("sfx", "")
		b.pressed.connect(func():
			Audio.play_ui("ui_tab")
			show_page.call(key))
		nav.add_child(b)
		nav_btns[key] = b
	show_page.call(initial_tab if pages.has(initial_tab) else "video")

	# ---- 画面 ----
	var pg_v: VBoxContainer = pages["video"]
	var fs := CheckButton.new()
	fs.text = Loc.t("全屏", "Fullscreen")
	fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs.toggled.connect(func(on): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	pg_v.add_child(fs)

	var vs := CheckButton.new()
	vs.text = Loc.t("垂直同步", "VSync")
	vs.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	vs.toggled.connect(func(on): DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED))
	pg_v.add_child(vs)

	var fps_cb := CheckButton.new()
	fps_cb.text = Loc.t("显示 FPS", "Show FPS")
	fps_cb.button_pressed = GameData.show_fps
	fps_cb.toggled.connect(func(on): GameData.set_show_fps(on))
	pg_v.add_child(fps_cb)

	pg_v.add_child(UI.label(Loc.t("画质", "Quality"), 12, K.CREAM_DIM))
	var q_opt := OptionButton.new()
	for i in GameData.QUALITY_NAMES.size():
		q_opt.add_item(str(GameData.QUALITY_NAMES[i]), i)
	q_opt.selected = GameData.quality
	q_opt.item_selected.connect(func(i):
		GameData.quality = i
		GameData.apply_quality(get_viewport())
		if hangar_vp and is_instance_valid(hangar_vp):
			GameData.apply_quality(hangar_vp, false)
		GameData.save_game())
	pg_v.add_child(q_opt)

	if not OS.has_feature("mobile"):
		pg_v.add_child(UI.label(Loc.t("渲染精度", "Render Scale"), 12, K.CREAM_DIM))
		var rs_opt := OptionButton.new()
		var rs_opts := GameData.render_scale_options()
		for i in rs_opts.size():
			rs_opt.add_item(str(rs_opts[i]), i)
		rs_opt.selected = GameData.render_scale_mode
		rs_opt.item_selected.connect(func(i):
			GameData.set_render_scale_mode(i)
			GameData.apply_quality(get_viewport())
			if hangar_vp and is_instance_valid(hangar_vp):
				GameData.apply_quality(hangar_vp, false))
		pg_v.add_child(rs_opt)

	pg_v.add_child(UI.label(Loc.t("画面风格", "Render Style"), 12, K.CREAM_DIM))
	var st_opt := OptionButton.new()
	st_opt.add_item(Loc.t("写实光影", "Realistic Lighting"), 0)
	st_opt.add_item(Loc.t("三渲二（卡通描边）", "Cel-Shaded (Toony Outline)"), 1)
	st_opt.selected = GameData.render_style
	st_opt.item_selected.connect(func(i):
		GameData.render_style = i
		GameData.save_game())
	pg_v.add_child(st_opt)

	# ---- 声音 ----
	var pg_a: VBoxContainer = pages["audio"]
	for bus in [["Master", Loc.t("主音量", "Master")], ["Music", Loc.t("音乐", "Music")], ["SFX", Loc.t("音效", "SFX")], ["Voice", Loc.t("语音", "Voice")]]:
		pg_a.add_child(UI.label(str(bus[1]), 12, K.CREAM_DIM))
		var vol := HSlider.new()
		vol.min_value = 0.0
		vol.max_value = 1.0
		vol.step = 0.05
		vol.value = Audio.get_volume(str(bus[0]))
		vol.custom_minimum_size = Vector2(0, 22)
		var bus_name := str(bus[0])
		vol.value_changed.connect(func(x): Audio.set_volume(bus_name, x))
		pg_a.add_child(vol)

	# ---- 常规 ----
	var pg_o: VBoxContainer = pages["other"]
	pg_o.add_child(UI.label(Loc.t("界面语言", "Language"), 12, K.CREAM_DIM))
	var lang_opt := OptionButton.new()
	lang_opt.add_item("简体中文", 0)
	lang_opt.add_item("English", 1)
	lang_opt.selected = 1 if Loc.is_en() else 0
	lang_opt.item_selected.connect(func(i):
		_settings_tab = "other"
		Loc.set_lang("zh" if i == 0 else "en"))
	pg_o.add_child(lang_opt)

	pg_o.add_child(UI.label(Loc.t("视角模式", "Camera Mode"), 12, K.CREAM_DIM))
	var view_opt := OptionButton.new()
	view_opt.add_item(Loc.t("第三人称", "Third-Person"), 0)
	view_opt.add_item(Loc.t("第一人称", "First-Person"), 1)
	view_opt.selected = GameData.view_mode
	view_opt.item_selected.connect(func(i):
		GameData.view_mode = i
		GameData.save_game())
	pg_o.add_child(view_opt)

	pg_o.add_child(UI.label(Loc.t("鼠标灵敏度", "Mouse Sensitivity"), 12, K.CREAM_DIM))
	var sens_sl := HSlider.new()
	sens_sl.min_value = 0.2
	sens_sl.max_value = 2.5
	sens_sl.step = 0.05
	sens_sl.value = GameData.mouse_sens
	sens_sl.custom_minimum_size = Vector2(0, 22)
	sens_sl.value_changed.connect(func(x):
		GameData.mouse_sens = x
		GameData.schedule_save())
	pg_o.add_child(sens_sl)

	# 存档位：把当前进度写入对应位做快照，不改变后续自动存档的活动位
	pg_o.add_child(UI.label(Loc.t("存档位", "Save Slots"), 12, K.CREAM_DIM))
	var slot_row := K.hbox(10)
	pg_o.add_child(slot_row)
	for i in range(1, GameData.SAVE_SLOT_COUNT + 1):
		var sv := K.vbox(3)
		slot_row.add_child(sv)
		var sb := Button.new()
		sb.text = "%d" % i
		sb.custom_minimum_size = Vector2(96, 30)
		sb.focus_mode = Control.FOCUS_NONE
		sb.set_meta("sfx", "")
		var st := UI.label("", 11, K.CREAM_DIM)
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sv.add_child(sb)
		sv.add_child(st)
		var slot_i := i
		sb.pressed.connect(func():
			GameData.save_to_slot(slot_i)
			st.text = GameData.fmt_save_time(int(Time.get_unix_time_from_system()))
			Audio.play_ui("ui_confirm"))
		st.text = GameData.fmt_save_time(int(GameData.slot_info(i).get("saved_at", 0)))

	var foot := K.hbox(8)
	v.add_child(foot)
	var b_menu := Button.new()
	b_menu.text = Loc.t("返回主菜单", "Main Menu")
	b_menu.custom_minimum_size = Vector2(130, 34)
	b_menu.set_meta("sfx", "")
	b_menu.pressed.connect(func():
		Audio.play_ui("ui_cancel")
		var p = get_parent()
		if p != null and p.has_method("show_menu"):
			p.show_menu())
	foot.add_child(b_menu)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	var b_close := K.primary(Loc.t("关闭", "Close"), 34)
	b_close.custom_minimum_size.x = 110
	b_close.set_meta("sfx", "")
	b_close.pressed.connect(func():
		Audio.play_ui("ui_close")
		if _settings_overlay != null and is_instance_valid(_settings_overlay):
			_settings_overlay.queue_free()
		_settings_overlay = null
		_settings_panel = null)
	foot.add_child(b_close)
	Audio.play_ui("ui_open")


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
	var ic = K.IconCell.new(56)
	ic.set_box_size(Vector2(96, 56))
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
		var m_mod: Dictionary = GameData.module(id)
		sub += " · " + str(GameData.SLOT_NAMES.get(str(m_mod.get("slot", "")), Loc.t("手臂", "Arm")))
		if GameData.has_recon_tag(m_mod):
			sub += Loc.t(" · [侦察]", " · [RECON]")
	nv.add_child(UI.label(sub, 12, K.CREAM_DIM))
	var r := K.Rule.new()
	r.solid = true
	v.add_child(r)
	v.add_child(K.kv(Loc.t("重量", "Weight"), "%.1f kg" % float(it.get("w", 0))))
	var gsz: Vector2i = GameData.item_grid_size(id)
	v.add_child(K.kv(Loc.t("占用格位", "Grid Size"), Loc.t("%d×%d（%d格）", "%d×%d (%d cells)") % [gsz.x, gsz.y, gsz.x * gsz.y]))
	v.add_child(K.kv(Loc.t("价值", "Value"), "¥ %s" % _fmt_money(int(it.get("v", 0))), K.AMBER_HI))
	if e.has("price"):
		v.add_child(K.kv(Loc.t("售价", "Price"), "¥ %s" % _fmt_money(int(e.price)), K.AMBER_HI))
	v.add_child(K.kv(Loc.t("仓库", "Stash"), "×%d" % GameData.count_in_stash(id)))
	if cat == "module":
		var m: Dictionary = GameData.module(id)
		var slot_s := str(m.get("slot", ""))
		if m.has("armor_class"):
			v.add_child(K.kv(Loc.t("防弹等级", "Armor Tier"), Loc.armor_tier(int(m.armor_class)), UI.GOOD if int(m.armor_class) >= 4 else UI.INFO))
		if GameData.has_recon_tag(m):
			v.add_child(K.kv(Loc.t("战术标签 [侦察]", "Trait [RECON]"), Loc.t("全局视距 +%d", "Global Sight +%d") % int(round(float(m.get("recon", 0.0)))), UI.GOOD))
		if m.has("ergo"):
			v.add_child(K.kv(Loc.t("人机工效", "Ergonomics"), "%d" % int(m.ergo), UI.GOOD if int(m.ergo) >= 65 else K.CREAM))
		if m.has("caliber"):
			v.add_child(K.kv(Loc.t("弹药规格", "Caliber"), str(m.caliber), K.CREAM))
		if m.has("pen"):
			var pc := GameData.pen_class(float(m.pen))
			v.add_child(K.kv(Loc.t("穿甲深度", "Penetration"), Loc.t("%d mm · %d级穿深", "%d mm · Tier %d Pen") % [int(m.pen), pc], UI.GOOD if pc >= 4 else UI.INFO))
		if m.has("moa"):
			v.add_child(K.kv(Loc.t("散布精度", "Dispersion"), Loc.t("%.1f 角分", "%.1f MOA") % float(m.moa), UI.INFO))
		var names := {
			"hp": Loc.t("结构耐久", "Hull HP"),
			"cargo": Loc.t("货舱扩容", "Cargo Cap"),
			"energy": Loc.t("电力容量", "Energy Cap"),
			"speed": Loc.t("巡航速度", "Cruise Speed"),
			"load": Loc.t("底盘承重", "Chassis Load"),
			"dmg": Loc.t("单发伤害", "Shot Damage"),
			"rate": Loc.t("理论射速", "Fire Rate"),
			"armor": Loc.t("附加减伤", "Dmg Reduction"),
			"range": Loc.t("武器射程", "Range"),
		}
		for k in ["hp", "armor", "energy", "speed", "load", "cargo", "dmg", "rate", "range"]:
			if m.has(k):
				if k == "speed" and slot_s == "arm":
					continue
				var val_txt := str(m[k])
				if k == "armor":
					val_txt = "%d%%" % int(round(float(m[k]) * 100.0))
				elif k == "dmg" and int(m.get("pellets", 1)) > 1:
					val_txt = "%.0f × %d (%.0f)" % [float(m.dmg), int(m.pellets), float(m.dmg) * int(m.pellets)]
				elif k == "rate":
					val_txt = Loc.t("%.1f 发/秒", "%.1f/s") % float(m.rate)
				elif k == "range":
					var rv := float(m.range)
					val_txt = "%.0f%s" % [rv, Loc.t("（远距视距）", " (Long Range)") if rv > 10.0 else (Loc.t("（标准视距）", " (Std Range)") if is_equal_approx(rv, 10.0) else Loc.t("（近距）", " (Short)"))]
				v.add_child(K.kv(names[k], val_txt, UI.GOOD if (k == "range" and float(m.range) > 10.0) else UI.INFO))
		if slot_s == "arm":
			var wpn := str(m.get("weapon", ""))
			v.add_child(K.kv(Loc.t("武器类型", "Weapon Type"), GameData.weapon_type_name(wpn), UI.ACCENT if wpn == "laser" else UI.INFO))
			if m.has("speed"):
				v.add_child(K.kv(Loc.t("弹道初速", "Muzzle Vel"), "%.0f m/s" % float(m.speed), K.CREAM_DIM))
			var en_s := str(snappedf(GameData.shot_energy_cost(m), 0.01))
			v.add_child(K.kv(Loc.t("射击资源", "Fire Resource"), Loc.t("能量 %s/发", "Energy %s/shot") % en_s, K.CREAM))
		elif m.has("eff"):
			v.add_child(K.kv(Loc.t("供电效率", "Power Eff."), Loc.t("耗电 %d%%", "%d%% Load") % int(round(float(m.eff) * 100.0)), UI.GOOD if float(m.eff) < 1.0 else K.CREAM))
		var sk := GameData.module_skill_info(id)
		if not sk.is_empty():
			v.add_child(K.kv(Loc.t("车载分系统 [%s]", "Subsystem [%s]") % str(sk.key), str(sk.name), UI.ACCENT))
			if str(sk.id) != "none":
				v.add_child(K.kv(Loc.t("冷却 / 功耗", "CD / Cost"), Loc.t("%.1f秒 · %.0f 能源", "%.1fs · %.0f EN") % [float(sk.cd), float(sk.cost)], K.CREAM_DIM))
			if str(sk.get("desc", "")) != "":
				var sd := K.wrap("▸ " + str(sk.desc), UI.INFO)
				sd.custom_minimum_size = Vector2(240, 0)
				v.add_child(sd)
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
	const RW := 300.0

	explode_btn = Button.new()
	explode_btn.text = Loc.t("◇ 拆解视图", "◇ Exploded View")
	explode_btn.custom_minimum_size = Vector2(128, 28)
	explode_btn.set_meta("sfx", "")
	explode_btn.pressed.connect(_toggle_explode)
	_at(explode_btn, v_m, [0.0, 0.0, 0.0, 0.0], [K.M + LW + K.GAP, K.GAP, K.M + LW + K.GAP + 128, K.GAP + 28])

	# 左：装备槽列
	var lp := _tpanel(v_m, Loc.t("装备", "Equipment"), "Equipment", LEFT, [K.M, K.GAP, K.M + LW, -K.GAP])
	maint_mass_lbl = lp[2]
	var v: VBoxContainer = lp[1]
	v.add_theme_constant_override("separation", 4)
	for slot in GameData.SLOTS:
		var b := DropButton.new()
		b.custom_minimum_size = Vector2(0, 64)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_open_slot_menu.bind(slot))
		b.can_fn = func(d: Dictionary): return str(d.get("kind", "")) == "stash" and GameData.slot_accepts(slot, str(d.get("id", "")))
		b.drop_fn = func(d: Dictionary): _equip_to(slot, str(d.id))
		b.drag_fn = func():
			var cur: String = GameData.loadout.get(slot, "")
			return null if cur == "" else {"kind": "slot", "slot": slot, "id": cur}
		b.tip_fn = func():
			var cur: String = GameData.loadout.get(slot, "")
			return null if cur == "" else _item_tip({"id": cur})
		v.add_child(b)
		var m := MarginContainer.new()
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for kk in [["margin_left", 6], ["margin_right", 8], ["margin_top", 6], ["margin_bottom", 6]]:
			m.add_theme_constant_override(kk[0], kk[1])
		b.add_child(m)
		var bh := K.hbox(8)
		bh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(bh)
		var ic = K.IconCell.new(48)
		ic.set_box_size(Vector2(68, 48))
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
		var en := UI.label(SLOT_EN.get(slot, str(slot).to_upper()), 12, K.CREAM_DIM)
		en.visible = false
		en.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(en)
		var nl := UI.label("", 12)
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		bv.add_child(nl)
		var st := UI.label("", 11, K.CREAM_DIM)
		st.clip_text = true
		st.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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

	# 右：仓库网格
	var rp := _tpanel(v_m, Loc.t("仓库", "Stash"), "Stash", RIGHT, [-K.M - RW, K.GAP, -K.M, -K.GAP])
	maint_count_lbl = rp[2]
	var rv: VBoxContainer = rp[1]
	var fh := K.hbox(4)
	rv.add_child(fh)
	var fg := ButtonGroup.new()
	for cf in [["all", Loc.t("全部", "All")], ["module", Loc.t("模块", "Modules")], ["other", Loc.t("物资", "Items")]]:
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
	maint_grid.show_names = true
	maint_grid.item_activated.connect(func(i):
		if i < maint_ids.size():
			_quick_equip(str(maint_ids[i])))
	maint_grid.item_context.connect(func(i):
		if i < maint_ids.size():
			_open_ctx(str(maint_ids[i]), "stash"))
	maint_grid.accept_drop = func(d: Dictionary): return str(d.get("kind", "")) == "slot"
	maint_grid.on_drop = func(d: Dictionary): _unequip(str(d.slot))
	rv.add_child(_scroll(maint_grid))

	# 中下：属性汇总条
	var sp := K.frame(6)
	_at(sp, v_m, [0.0, 1.0, 1.0, 1.0], [K.M + LW + K.GAP, -K.GAP - 76, -K.M - RW - K.GAP, -K.GAP])
	var sv := K.vbox(4)
	sp.add_child(sv)
	var shh := K.hbox(6)
	sv.add_child(shh)
	shh.add_child(UI.label(Loc.t("机体性能", "Mech Specs"), 12, K.CREAM))
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
	for k in [["hp", Loc.t("结构", "Hull"), "HP", UI.HP_C], ["armor", Loc.t("护甲", "Armor"), "ARM", K.STEEL], ["energy", Loc.t("能源", "Energy"), "EN", UI.EN_C],
			["speed", Loc.t("速度", "Speed"), "SPD", UI.INFO], ["load", Loc.t("承重", "Load"), "LOAD", K.AMBER_HI], ["cargo", Loc.t("货舱", "Cargo"), "CARGO", UI.GOOD]]:
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
		var en := UI.label(k[2], 12, K.CREAM_DIM)
		en.visible = false
		lh.add_child(en)
		var val := UI.label("", 12, K.CREAM)
		cell.add_child(val)
		var bar = K.PixBar.new(6)
		bar.color = k[3]
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(bar)
		stat_rows[k[0]] = [bar, val]


# ============================================================ 2. 交易视图（单页：商人条 / 货架 / 仓库 / 成交栏 / 委托 / 账户）
func _build_trade_view(parent: Control) -> void:
	var v_t := _view(parent, "trade")
	trade_deal_root = Control.new()
	trade_deal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_at(trade_deal_root, v_t, FILL, [0, 0, 0, 0])
	# 单页布局：两个旧根指向同一节点，切换逻辑保持可用
	trade_list_root = trade_deal_root

	const DEAL_H := 70.0
	const BOT_H := 140.0
	const TOP_H2 := 104.0

	# ---- 商人条：头像 + 名称 + 身份 + 好感 + 供货
	var hdr := K.frame(6)
	_at(hdr, trade_deal_root, [0.0, 0.0, 1.0, 0.0], [K.M, K.GAP, -K.M, K.GAP + TOP_H2])
	var row := K.hbox(8)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hdr.add_child(row)
	for m_id in K.MERCHANT_IDS:
		var md: Dictionary = MERCHANTS[m_id]
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("normal", K.px9("merchant9", 12, 12, 6))
		b.add_theme_stylebox_override("hover", K.px9("merchant9_h", 12, 12, 6))
		b.add_theme_stylebox_override("pressed", K.px9("merchant9_on", 12, 12, 6))
		b.add_theme_stylebox_override("hover_pressed", K.px9("merchant9_on", 12, 12, 6))
		b.pressed.connect(func(): _select_merchant(m_id))
		row.add_child(b)
		merchant_cards[m_id] = b
		merchant_buttons[m_id] = b
		var mc := MarginContainer.new()
		mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for kk in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			mc.add_theme_constant_override(kk, 6)
		b.add_child(mc)
		var hh := K.hbox(8)
		hh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mc.add_child(hh)
		var av = K.Avatar.new(44, m_id, "n")
		av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hh.add_child(av)
		merchant_avatars[m_id] = av
		var vv := K.vbox(2)
		vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hh.add_child(vv)
		var nl := UI.label(Loc.merchant_info(m_id, "name", md.name), 12, UI.ACCENT)
		vv.add_child(nl)
		var rl := UI.label(Loc.merchant_info(m_id, "role", md.role), 12, K.CREAM_DIM)
		rl.clip_text = true
		rl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vv.add_child(rl)
		var aff := K.hbox(4)
		aff.mouse_filter = Control.MOUSE_FILTER_IGNORE
		aff.set_meta("merchant", m_id)
		vv.add_child(aff)
		var stock := UI.label("", 12, K.CREAM_DIM)
		vv.add_child(stock)
		b.set_meta("aff", aff)
		b.set_meta("stock", stock)
		for c in [nl, rl, stock]:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var gt := K.GAP * 2 + TOP_H2
	var gb := -(K.GAP * 3 + DEAL_H + BOT_H)

	# ---- 货架
	var sp := _tpanel(trade_deal_root, Loc.t("货架", "Offers"), "Offers", [0.0, 0.0, 0.5, 1.0], [K.M, gt, -K.GAP * 0.5, gb])
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

	# ---- 我的仓库
	var pp := _tpanel(trade_deal_root, Loc.t("我的仓库", "My Stash"), "Stash", [0.5, 0.0, 1.0, 1.0], [K.GAP * 0.5, gt, -K.M, gb])
	trade_stash_grid = _grid_widget(60, "tstash")
	trade_stash_grid.show_names = true
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

	# ---- 成交栏
	var deal := K.frame(8)
	_at(deal, trade_deal_root, [0.0, 1.0, 1.0, 1.0], [K.M, -K.GAP * 2 - BOT_H - DEAL_H, -K.M, -K.GAP * 2 - BOT_H])
	var dh := K.hbox(12)
	deal.add_child(dh)
	deal_cell = K.IconCell.new(56)
	deal_cell.set_box_size(Vector2(88, 56))
	deal_cell.tip_fn = _item_tip
	dh.add_child(deal_cell)
	var dv := K.vbox(2)
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dh.add_child(dv)
	deal_name_lbl = UI.label("—", 12, K.CREAM)
	dv.add_child(deal_name_lbl)
	deal_info_lbl = UI.label("", 12, K.CREAM_DIM)
	deal_info_lbl.clip_text = true
	deal_info_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	dv.add_child(deal_info_lbl)
	_vsep(dh, 48)
	var pv := K.vbox(2)
	pv.custom_minimum_size = Vector2(200, 0)
	pv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dh.add_child(pv)
	deal_price_lbl = UI.label("", 24, K.AMBER_HI)
	deal_price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pv.add_child(deal_price_lbl)
	deal_after_lbl = UI.label("", 12, K.CREAM_DIM)
	deal_after_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pv.add_child(deal_after_lbl)
	buy_btn = K.primary(Loc.t("买入", "Buy"), 44)
	buy_btn.custom_minimum_size.x = 110
	buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy_btn.add_theme_font_size_override("font_size", 18)
	buy_btn.set_meta("sfx", "")
	buy_btn.pressed.connect(func():
		if trade_side == "buy" and selected_shop >= 0:
			_buy(selected_shop)
		else:
			Audio.play_ui("ui_denied"))
	dh.add_child(buy_btn)
	sell_btn = Button.new()
	sell_btn.text = Loc.t("卖出", "Sell")
	sell_btn.custom_minimum_size = Vector2(110, 44)
	sell_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sell_btn.add_theme_font_size_override("font_size", 18)
	sell_btn.set_meta("sfx", "")
	sell_btn.pressed.connect(func():
		if trade_side == "sell":
			_sell_selected()
		else:
			Audio.play_ui("ui_denied"))
	dh.add_child(sell_btn)

	# ---- 底部：后勤委托 + 账户
	var rq := _tpanel(trade_deal_root, Loc.t("后勤委托", "Contracts"), "Request", [0.0, 1.0, 1.0, 1.0], [K.M, -K.GAP - BOT_H, -K.M - 380 - K.GAP, -K.GAP])
	request_list = K.hbox(12)
	request_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rq[1].add_child(request_list)

	var ac := _tpanel(trade_deal_root, Loc.t("账户", "Account"), "Account", [1.0, 1.0, 1.0, 1.0], [-K.M - 380, -K.GAP - BOT_H, -K.M, -K.GAP])
	account_box = K.vbox(2)
	ac[1].add_child(account_box)
	var asp := Control.new()
	asp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ac[1].add_child(asp)
	var sj := Button.new()
	sj.text = Loc.t("出售全部食物与杂物", "Sell All Food & Salvage")
	sj.custom_minimum_size = Vector2(0, 28)
	sj.set_meta("sfx", "")
	sj.pressed.connect(_sell_junk)
	ac[1].add_child(sj)

	_select_merchant_silent(cur_merchant)


func _trade_show(mode: String) -> void:
	trade_mode = mode
	if trade_deal_root:
		trade_deal_root.visible = true


func _select_merchant_silent(m_id: String) -> void:
	cur_merchant = m_id
	selected_shop = -1
	trade_side = ""
	for k in merchant_buttons:
		merchant_buttons[k].button_pressed = (k == m_id)
		merchant_avatars[k].set_state("on" if k == m_id else "n")
	var md: Dictionary = MERCHANTS.get(m_id, {})
	var m_name := Loc.merchant_info(m_id, "name", md.get("name", ""))
	if merchant_name_lbl:
		merchant_name_lbl.text = m_name
	if merchant_role_lbl:
		merchant_role_lbl.text = Loc.merchant_info(m_id, "role", md.get("role", ""))
	if merchant_desc_lbl:
		merchant_desc_lbl.text = Loc.merchant_info(m_id, "desc", str(md.get("desc", "")))
	if merchant_portrait:
		merchant_portrait.set_char(m_id, 40)
	if shop_title_lbl:
		shop_title_lbl.text = Loc.t("货架 · %s", "Stock · %s") % m_name
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
		deal_name_lbl.text = "—"
		deal_name_lbl.add_theme_color_override("font_color", K.CREAM_DIM)
		deal_info_lbl.text = ""
		deal_price_lbl.text = ""
		deal_after_lbl.text = Loc.t("余额 ¥ %s", "Balance ¥ %s") % _fmt_money(GameData.money)
		return
	var it := GameData.item(id)
	deal_cell.set_entry({"id": id, "count": GameData.count_in_stash(id)})
	deal_name_lbl.text = (Loc.t("买入  ", "Buy  ") if trade_side == "buy" else Loc.t("卖出  ", "Sell  ")) + str(it.name)
	deal_name_lbl.add_theme_color_override("font_color", GameData.RARITY_COLORS[int(it.rar)])
	deal_info_lbl.text = Loc.t("%s · %.1fkg · 仓库 ×%d · %s", "%s · %.1fkg · Stash ×%d · %s") % [GameData.CAT_NAMES.get(it.cat, ""), float(it.w), GameData.count_in_stash(id), Growth.subst(str(it.get("desc", "")))]
	deal_price_lbl.text = "¥ %s" % _fmt_money(price)
	var after := GameData.money - price if trade_side == "buy" else GameData.money + price
	deal_after_lbl.text = Loc.t("余额 ¥ %s  →  ¥ %s", "Balance ¥ %s  →  ¥ %s") % [_fmt_money(GameData.money), _fmt_money(after)]
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
		b.text = "%d   %s" % [i + 1, sd[1] if Loc.is_en() else sd[0]]
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
	var wm := _tpanel(p1, Loc.t("地区侦察图", "Regional Map"), "Region map", FILL, [K.M, top, -K.M - RW - K.GAP, -K.GAP])
	var wm_mc := wm[1].get_parent() as MarginContainer
	if wm_mc:
		for k in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			wm_mc.add_theme_constant_override(k, 0)
	world_map = WorldMapView.new()
	world_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	world_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wm[1].add_child(world_map)
	world_map.map_selected.connect(func(id: String):
		GameData.map_id = id
		Audio.play_ui("ui_tab")
		_update_map_detail())
	world_map.map_locked.connect(func(_id: String): Audio.play_ui("ui_denied"))
	_refresh_world_map()

	var bp := _tpanel(p1, Loc.t("任务简报", "Mission Briefing"), "Briefing", RIGHT, [-K.M - RW, top, -K.M, -K.GAP])
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
	_sec(bv, Loc.t("任务", "Objective"), "Objective")
	map_quest_lbl = K.wrap("", UI.INFO)
	bv.add_child(map_quest_lbl)
	_sec(bv, Loc.t("相邻战区", "Adjacent Sectors"), "Transit")
	map_link_lbl = K.wrap("", K.CREAM_DIM)
	bv.add_child(map_link_lbl)
	var bsp := Control.new()
	bsp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bv.add_child(bsp)
	bv.add_child(K.hazard_strip())
	var nx := K.primary(Loc.t("下一步 · 确认携带  →", "Next · Loadout Check  →"), 52)
	nx.add_theme_font_size_override("font_size", 18)
	nx.pressed.connect(func(): _deploy_show(2))
	bv.add_child(nx)

	# ---- 第 2 步：携带物资 + 出发
	var p2 := Control.new()
	p2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_at(p2, v_d, FILL, [0, 0, 0, 0])
	deploy_pages.append(p2)
	var lp := _tpanel(p2, Loc.t("出击准备", "Loadout Prep"), "Loadout check", FILL, [K.M, top, -K.M - RW - K.GAP, -K.GAP])
	var lv: VBoxContainer = lp[1]
	var gh := K.hbox(8)
	gh.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(gh)
	var gl := K.vbox(6)
	gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gh.add_child(gl)
	_sec(gl, Loc.t("备战物资", "Supplies"), "Supplies")
	deploy_stash_list = _grid_widget(K.CELL, "dstash")
	deploy_stash_list.show_names = true
	deploy_stash_list.item_activated.connect(func(i):
		if i >= 0 and i < deploy_stash_ids.size():
			selected_stash = deploy_stash_ids[i]
			_move_to_cargo())
	deploy_stash_list.accept_drop = func(d: Dictionary): return str(d.get("kind", "")) == "cargo"
	deploy_stash_list.on_drop = func(d: Dictionary):
		var cidx: int = int(d.get("index", -1))
		if cidx >= 0 and cidx < GameData.cargo.size():
			_cargo_back(cidx)
		else:
			_cargo_back_id(str(d.id))
	gl.add_child(_scroll(deploy_stash_list))
	var load_b := _btn(gl, Loc.t("装入出击货舱  →", "Load into Cargo  →"), func():
		var sel = deploy_stash_list.get_selected_items()
		if not sel.is_empty() and sel[0] < deploy_stash_ids.size():
			selected_stash = deploy_stash_ids[sel[0]]
			_move_to_cargo())
	load_b.custom_minimum_size = Vector2(0, 30)
	_vsep(gh, 300)
	var gr := K.vbox(6)
	gr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gh.add_child(gr)
	cargo_lbl = _sec(gr, Loc.t("出击货舱", "Sortie Cargo"), "Cargo")
	cargo_list = _grid_widget(K.CELL, "cargo")
	cargo_list.show_names = true
	cargo_list.fixed_cols = GameData.CARGO_COLS
	cargo_list.item_activated.connect(func(i):
		if i >= 0 and i < cargo_ids.size():
			_cargo_back(i))
	cargo_list.accept_drop = func(d: Dictionary): return str(d.get("kind", "")) == "dstash"
	cargo_list.on_drop = func(d: Dictionary):
		selected_stash = str(d.id)
		_move_to_cargo()
	gr.add_child(_scroll(cargo_list))
	var back_b := _btn(gr, Loc.t("←  退回仓库", "←  Return to Stash"), func():
		var sel = cargo_list.get_selected_items()
		if not sel.is_empty() and sel[0] < cargo_ids.size():
			_cargo_back(int(sel[0])))
	back_b.custom_minimum_size = Vector2(0, 30)
	squad_count_lbl = _sec(lv, Loc.t("随行队友", "Squadmates"), "Squad")
	squad_box = K.hbox(8)
	squad_box.custom_minimum_size = Vector2(0, 64)
	lv.add_child(squad_box)

	var dp := _tpanel(p2, Loc.t("出发", "Deploy"), "Deploy", RIGHT, [-K.M - RW, top, -K.M, -K.GAP])
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
	_sec(dv, Loc.t("出击检查", "Pre-Drop Checklist"), "Checklist")
	check_box = K.vbox(4)
	dv.add_child(check_box)
	var dsp := Control.new()
	dsp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(dsp)
	deploy_err = UI.label("", 12, UI.BAD)
	deploy_err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(deploy_err)
	dv.add_child(K.hazard_strip())
	deploy_btn = K.primary(Loc.t("▼  空投出击", "▼  LAUNCH SORTIE"), 60)
	deploy_btn.add_theme_font_size_override("font_size", 18)
	deploy_btn.set_meta("sfx", "ui_confirm")
	deploy_btn.pressed.connect(func(): deploy_requested.emit())
	dv.add_child(deploy_btn)
	var bk := Button.new()
	bk.text = Loc.t("←  返回选择战区", "←  Back to Sector Map")
	bk.custom_minimum_size = Vector2(0, 30)
	bk.pressed.connect(func(): _deploy_show(1))
	dv.add_child(bk)

	_update_map_detail()
	_deploy_show(1)


## 大地图的解锁 / 主线 / 选中状态（出击条件可能在别的页签里变化，切到降落页时刷新）
func _refresh_world_map() -> void:
	if world_map == null:
		return
	var map_ids: Array = world_map.map_ids()
	if not map_ids.is_empty() and not map_ids.has(GameData.map_id):
		GameData.map_id = "canyon" if (map_ids.has("canyon") and GameData.map_available("canyon")) else str(map_ids[0])
		_update_map_detail()
	var av := {}
	var qs := {}
	for id: String in GameData.map_ids():
		av[id] = GameData.map_available(id)
		qs[id] = _map_quest(id) != ""
	world_map.set_state(av, qs, GameData.map_id)


func _deploy_show(n: int) -> void:
	var changed := n != deploy_step
	deploy_step = n
	if n == 1:
		_refresh_world_map()
	var enter_delay := 0.0
	if changed:
		for i in deploy_pages.size():
			if i != n - 1 and deploy_pages[i].visible:
				enter_delay = PageMotion.EXIT
				break
	for i in deploy_pages.size():
		_transition_page(deploy_pages[i], i, i == n - 1, changed, _deploy_tweens, _deploy_modes, enter_delay)
	for i in step_btns.size():
		var b: Button = step_btns[i]
		var st := "on" if i == n - 1 else ("done" if i < n - 1 else "todo")
		var sn := "nav9_on" if st == "on" else ("nav9_n" if st == "done" else "nav9_p")
		b.add_theme_stylebox_override("normal", K.px9(sn, 12, 12, 8, 4))
		b.add_theme_stylebox_override("hover", K.px9("nav9_on" if st == "on" else "nav9_h", 12, 12, 8, 4))
		b.add_theme_color_override("font_color", K.AMBER_HI if st == "on" else (K.CREAM if st == "done" else K.CREAM_DIM))


func _map_quest(id: String) -> String:
	for ch in Growth.chapters():
		if str(ch.map) == id:
			var stt := Growth.chapter_status(str(ch.id))
			if stt == "进行中":
				return str(ch.title)
	return ""


const MAP_BOSS_IDS := {
	"greyport": ["terminus_warden", "grey_brood", "harbor_reaper"],
	"ironbelt": ["foundry_dreadnought", "iron_warden", "slag_colossus"],
	"dustfield": ["silo_warhead", "dust_matriarch", "dune_devourer", "citadel_behemoth"],
	"redlake": ["spillway_leviathan", "broodmother", "prism_archon"],
	"bayport": ["drydock_behemoth", "harbor_reaper", "slag_colossus", "sky_carrier"],
	"canyon": ["excavator_titan", "king_beetle", "gorge_tyrant"],
	"abyss_maw": ["core_overlord", "abyss_queen", "abyss_harbinger"],
}


func _update_map_detail() -> void:
	var md: Dictionary = GameData.map_data(GameData.map_id)
	map_title_lbl.text = md.get("name", "")
	map_tag_lbl.text = md.get("tag", "")
	map_desc_lbl.text = md.get("desc", "")
	var env_str: String = md.get("env", "")
	map_hazard_lbl.text = (Loc.t("环境态势：%s", "Hazard Status: %s") % env_str) if env_str != "" else ""
	map_hazard_lbl.visible = env_str != ""
	var qs: Array = []
	for ch in Growth.chapters():
		if str(ch.map) == GameData.map_id:
			qs.append(Loc.t("%s（%s）", "%s (%s)") % [str(ch.title), Loc.t(Growth.chapter_status(str(ch.id)))])
	var ex: Array = md.get("extracts", [])
	var pois: Array = md.get("pois", [])
	var q := "\n".join(qs) if not qs.is_empty() else Loc.t("自由搜刮：带回物资，活着撤离。", "Free Scavenge: haul loot out and extract alive.")
	if not ex.is_empty():
		q += Loc.t("\n撤离点 %d 处 · 重点遗迹 %d 处", "\n%d Extraction Points · %d Key POIs") % [ex.size(), pois.size()]
	var b_names: Array = []
	for eid in MAP_BOSS_IDS.get(GameData.map_id, []):
		var ename := str(GameData.ENEMIES.get(str(eid), {}).get("name", ""))
		if ename != "":
			b_names.append(ename)
	if not b_names.is_empty():
		q += Loc.t("\n首领威胁：", "\nBoss Threats: ") + " · ".join(b_names)
	map_quest_lbl.text = q
	var links: Dictionary = WorldLink.LINKS.get(GameData.map_id, {})
	var ls: Array = []
	for e: String in links:
		ls.append("%s · %s" % [_dir_name(e), str(GameData.map_data(str(links[e])).get("name", links[e]))])
	map_link_lbl.text = "  ".join(ls) if not ls.is_empty() else Loc.t("竖井战区，不与地表相连。", "Vertical shaft sector — no surface links.")
	if map_title2_lbl:
		map_title2_lbl.text = map_title_lbl.text
		map_tag2_lbl.text = map_tag_lbl.text


func _refresh_checklist(st: Dictionary, cw: float, err: String) -> void:
	if check_box == null:
		return
	for c in check_box.get_children():
		check_box.remove_child(c)
		c.queue_free()
	check_box.add_child(K.req_row(Loc.t("机体组装", "Rig Assembly"), Loc.t("完整", "Complete") if err == "" else err, err == ""))
	var used_cells: int = GameData.cargo_cells_used(GameData.cargo)
	var max_cells: int = GameData.cargo_grid_cap(float(st.cargo))
	var grid_ok: bool = GameData.can_pack_cargo(GameData.cargo, float(st.cargo))
	check_box.add_child(K.req_row(Loc.t("出击货舱", "Sortie Cargo"), "%.1f/%.0f kg · %d/%d%s" % [cw, st.cargo, used_cells, max_cells, Loc.t("格", "c")], cw <= st.cargo and grid_ok))
	var sf := GameData.speed_factor(st, cw)
	check_box.add_child(K.req_row(Loc.t("机体承重", "Chassis Load"), "%.0f / %.0f kg" % [st.mass + cw, st.load], sf > 0.99))
	var runtime: float = st.energy / max(0.01, st.drain)
	check_box.add_child(K.req_row(Loc.t("能源续航", "Power Endurance"), "%d:%02d" % [int(runtime) / 60, int(runtime) % 60], runtime >= 240.0))
	var sq := Growth.ally_squad()
	check_box.add_child(K.req_row(Loc.t("随行队友", "Squadmates"), (Loc.t("%d 名", "%d Active") % sq.size()) if not sq.is_empty() else Loc.t("单机出击", "Solo Drop"), true))
	if Growth.facility_level("kitchen") > 0:
		var ready := Growth.meal_ready() > 0
		check_box.add_child(K.req_row(Loc.t("出击餐点", "Sortie Ration"), Growth.meal_text() if ready else Loc.t("未烹制", "Not Cooked"), ready))
	check_box.add_child(K.req_row(Loc.t("驾驶员", "Pilot"), "%s %s" % [Growth.player_name(), Loc.lv(Growth.pilot_level(Growth.PROTAGONIST))], true))


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
	squad_count_lbl.text = Loc.t("部署仓 %d / %d", "Pods %d / %d") % [owned, Growth.pod_ids().size()]
	if owned == 0:
		var c := K.card()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		squad_box.add_child(c)
		var h := K.hbox(10)
		c.add_child(h)
		var t := UI.label(Loc.t("无随行机体（单机出击）", "No Active Wingmates (Solo Drop)"), 12, K.CREAM_DIM)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
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
		v.add_child(UI.label((Loc.t("%s · 随行", "%s · Active") % Loc.pod_tier_str(Growth.pod_tier(pid))) if on else Loc.t("待命", "Standby"), 12, UI.GOOD if on else K.CREAM_DIM))
		var cb := Button.new()
		cb.toggle_mode = true
		cb.button_pressed = on
		cb.text = Loc.t("随行", "Active") if on else Loc.t("待命", "Standby")
		cb.custom_minimum_size = Vector2(56, 30)
		cb.focus_mode = Control.FOCUS_NONE
		cb.tooltip_text = Loc.t("本次出击是否随行", "Toggle squadmate for this sortie")
		cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cb.toggled.connect(func(x: bool):
			Growth.set_pod_on(pid, x)
			refresh())
		h.add_child(cb)
	if sq.is_empty():
		squad_count_lbl.text += Loc.t(" · 本次单机出击", " · Solo Drop")


# ============================================================ 4. 技能视图（藏身处式设施卡片：飞空艇设施 / 研究 / 主角能力 / 部署仓）
func _build_skills_view(parent: Control) -> void:
	var v_k := _view(parent, "skills")
	const RW := 300.0
	const ST_H := 36.0

	var nav := K.hbox(6)
	_at(nav, v_k, [0.0, 0.0, 1.0, 0.0], [K.M, K.GAP, -K.M, K.GAP + ST_H])
	var grp := ButtonGroup.new()
	for d in [["airship", Loc.t("飞空艇设施", "Facilities"), "HIDEOUT"], ["research", Loc.t("研究课题", "Research"), "RESEARCH"], ["pilot", Loc.t("主角能力", "Proficiency & Talents"), "PILOT"], ["pods", Loc.t("部署仓 · 队友", "Deploy Pods · Squad"), "SQUAD"]]:
		var key: String = d[0]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = grp
		b.custom_minimum_size = Vector2(0, ST_H)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.text = d[1]
		b.pressed.connect(func(): _skills_show(key))
		skills_nav[key] = b
		nav.add_child(b)

	var top := K.GAP * 2 + ST_H
	var mp := _tpanel(v_k, Loc.t("飞空艇设施", "Facilities"), "Hideout", FILL, [K.M, top, -K.M - RW - K.GAP, -K.GAP])
	skills_title_lbl = mp[0].get_meta("title_lbl")
	skills_en_lbl = mp[0].get_meta("en_lbl")
	skills_en_lbl.visible = false
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

	var sp := _tpanel(v_k, Loc.t("打捞杂物", "Salvage"), "Salvage", RIGHT, [-K.M - RW, top, -K.M, -K.GAP])
	var sv: VBoxContainer = sp[1]
	salvage_box = K.vbox(4)
	sv.add_child(salvage_box)
	salvage_grid = _grid_widget(K.CELL)
	salvage_grid.min_rows = 2
	sv.add_child(salvage_grid)
	var ssp := Control.new()
	ssp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sv.add_child(ssp)


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
	salvage_box.add_child(K.kv(Loc.t("信用点", "Credits"), "¥ %s" % _fmt_money(GameData.money), K.AMBER_HI))
	var tot := 0
	var es: Array = []
	for id in Growth.material_ids():
		if not GameData.ITEMS.has(id):
			continue
		var n := Growth.material_count(str(id))
		tot += n
		es.append({"id": str(id), "count": n, "dim": n == 0, "label": K.short_name(str(id))})
	salvage_box.add_child(K.kv(Loc.t("杂物合计", "Total Salvage"), "×%d" % tot))
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
	skills_en_lbl.visible = false
	match skills_sub:
		"airship":
			skills_title_lbl.text = Loc.t("飞空艇设施", "Airship Facilities")
			skills_right_lbl.text = ""
			_skills_airship()
		"research":
			skills_title_lbl.text = Loc.t("研究课题", "Research Projects")
			skills_right_lbl.text = Loc.t("研究室 %s", "Lab %s") % Loc.lv(Growth.facility_level("lab"))
			_skills_research()
		"pilot":
			skills_title_lbl.text = Loc.t("主角能力 · 实战熟练度", "Pilot Proficiency & Talents")
			skills_right_lbl.text = Loc.t("实战使用自动升级 · 零物资消耗", "Levels via combat use · zero cost")
			_skills_pilot()
		"pods":
			skills_title_lbl.text = Loc.t("部署仓 · 战斗队友", "Deploy Pods · Combat Squad")
			skills_right_lbl.text = ""
			_skills_pods()


## 设施卡片：图标 + 名称 + 等级刻度；效果文字；「需求」列表（■ 绿 = 满足 / 红 = 不足）；操作按钮
## extra：额外需求 [[文字, 右侧文字, 是否满足], ...]（研究室等级、前置研究……）
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
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
		ph.add_child(UI.label(Loc.t("%d / %d级", "Lv.%d / %d") % [lv, mx], 12, K.CREAM_DIM))
	if on:
		h.add_child(K.tag(Loc.t("已完成", "Done") if mx == 0 else Loc.lv(lv), true))
	elif mx > 0:
		h.add_child(K.tag(Loc.lv(lv), lv > 0))
	for l in lines:
		v.add_child(K.wrap(str(l[0]), l[1]))
	var parts := Growth.cost_parts(cost)
	if not parts.is_empty() or not extra.is_empty():
		var rh := K.hbox(6)
		v.add_child(rh)
		rh.add_child(UI.label(Loc.t("需求", "Requirements"), 12, K.CREAM_DIM))
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
		v.add_child(K.req_row(Loc.t("已满级", "Maxed"), "", true))
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	var b := K.primary(btn_text if reason == "" else "%s · %s" % [btn_text, Loc.reason(reason)], 30)
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
		var lines: Array = [[Loc.t("当前　", "Current: ") + (cur if cur != "" else Loc.t("未建设", "Not Built")), K.CREAM_DIM]]
		if nxt != "":
			lines.append([Loc.t("下一级 ", "Next: ") + nxt, UI.INFO])
		var reason := Growth.can_upgrade(id)
		g.add_child(_skill_card(Growth.facility_name(id), lv, mx, lines, Growth.facility_cost(id) if lv < mx else {}, Loc.t("升级", "Upgrade") if lv > 0 else Loc.t("建设", "Build"), reason, func(): return Growth.upgrade_facility(id), false, str(id)))
	# 厨房：烹制出击餐点
	if Growth.facility_level("kitchen") > 0:
		var mc := Growth.meal_cost()
		var ready := Growth.meal_ready() > 0
		g.add_child(_skill_card(Loc.t("出击食堂 · 餐点", "Mess Hall · Ration"), 0, 0, [[Loc.t("本次出击 ", "This Sortie: ") + (Growth.meal_text() if ready else Loc.t("尚未烹制", "Not Prepared")), UI.GOOD if ready else K.CREAM_DIM]],
			mc, Loc.t("烹制餐点", "Cook Meal"), "已备好" if ready else ("" if Growth.can_afford(mc) else "材料不足"), func(): return Growth.serve_meal(), ready, "meal"))


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
			extra.append([Loc.t("研究室等级", "Lab Level"), Loc.t("%d / %d级", "Lv.%d / %d") % [lab, need_lab], lab >= need_lab])
			for n in d.get("needs", []):
				extra.append([Loc.t("前置 ", "Req ") + str(Growth.research_data(str(n)).get("name", n)), Loc.t("已完成", "Done") if Growth.research_done(str(n)) else Loc.t("未完成", "Pending"), Growth.research_done(str(n))])
		g.add_child(_skill_card(str(d.get("name", id)), 0, 0, lines, {} if done else d.get("cost", {}), Loc.t("研究", "Research"), reason, func(): return Growth.do_research(id), done, "research", extra))


func _skills_pilot() -> void:
	var pid := Growth.PROTAGONIST
	var top := K.card(false, 7)
	skills_body.add_child(top)
	var th := K.hbox(12)
	top.add_child(th)
	var pav = K.Avatar.new(72, pid, "lead")
	pav.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(pav)
	var tv := K.vbox(4)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(tv)
	var nh := K.hbox(8)
	tv.add_child(nh)
	nh.add_child(UI.label(Growth.player_name(), 20, UI.ACCENT))
	var lvl := Growth.pilot_level(pid)
	nh.add_child(K.tag(Loc.lv(lvl)))
	var sub := UI.label(Loc.t("主力机甲驾驶员", "Lead Mech Pilot"), 12, UI.INFO)
	sub.size_flags_vertical = Control.SIZE_SHRINK_END
	nh.add_child(sub)
	var sp_nh := Control.new()
	sp_nh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nh.add_child(sp_nh)
	var le := LineEdit.new()
	le.text = Growth.player_name()
	le.max_length = 8
	le.custom_minimum_size = Vector2(96, 24)
	nh.add_child(le)
	var rb := Button.new()
	rb.text = Loc.t("更名", "Rename")
	rb.custom_minimum_size = Vector2(48, 24)
	rb.pressed.connect(func():
		Growth.set_player_name(le.text)
		refresh())
	nh.add_child(rb)
	var need := Growth.pilot_xp_next(lvl)
	var xh := K.hbox(8)
	tv.add_child(xh)
	var bar = K.PixBar.new(8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.set_frac(1.0 if need <= 0 else float(Growth.pilot_xp(pid)) / need)
	xh.add_child(bar)
	xh.add_child(UI.label(Loc.t("满级", "Maxed") if need <= 0 else Loc.t("%d / %d 经验", "%d / %d EXP") % [Growth.pilot_xp(pid), need], 11, K.CREAM_DIM))
	# 右侧：塔科夫式实战熟练度总览（取代旧版花钱+杂物的模拟舱训练）
	var total_lv := 0
	var total_mx := 0
	var elite_cnt := 0
	for aid in Growth.ability_ids():
		var alv := Growth.ability_level(str(aid))
		var amx := Growth.ability_max(str(aid))
		total_lv += alv
		total_mx += amx
		if alv >= amx:
			elite_cnt += 1
	var sum_card := K.card(elite_cnt > 0, 6)
	sum_card.custom_minimum_size = Vector2(296, 0)
	var sv := K.vbox(3)
	sum_card.add_child(sv)
	var sh := K.hbox(8)
	sv.add_child(sh)
	sh.add_child(UI.label(Loc.t("实战熟练度总览", "Field Proficiency Summary"), 12, UI.ACCENT))
	var sp_f := Control.new()
	sp_f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(sp_f)
	sh.add_child(K.tag(Loc.t("总计 %d / %d级", "Total Lv.%d / %d") % [total_lv, total_mx], total_lv > 0))
	sv.add_child(K.req_row(Loc.t("精英专精 / 初段精力", "Elite / Fresh Focus"), "★%d/%d · ▲129%%" % [elite_cnt, Growth.ability_ids().size()], true))
	sv.add_child(K.wrap(Loc.t("战区移动/负重/交火/损管/搜刮自动升级（零资源消耗）", "Levels automatically via movement, load, combat, repairs & looting (zero cost)"), K.CREAM_DIM))
	th.add_child(sum_card)

	_sec(skills_body, Loc.t("实战熟练度", "Proficiency"), "Proficiency", Loc.t("实战行动自动成长 · 单局初段 129% 专注加成 / 过度重复疲劳递减", "Grows via combat action · 129% fresh focus bonus early, diminishing returns later"))
	var g := _grid(4)
	g.add_theme_constant_override("v_separation", 6)
	skills_body.add_child(g)
	for id in Growth.ability_ids():
		g.add_child(_proficiency_card(str(id)))


func _proficiency_card(id: String) -> PanelContainer:
	var d := Growth.ability_data(id)
	var lv := Growth.ability_level(id)
	var mx := Growth.ability_max(id)
	var elite := lv >= mx
	var xp := Growth.ability_xp(id)
	var need := Growth.ability_xp_next(id)
	var mult := Growth.ability_focus_mult(id)
	var c := K.card(elite or lv > 0, 6)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := K.vbox(3)
	c.add_child(v)
	var h := K.hbox(7)
	v.add_child(h)
	var ib := PanelContainer.new()
	ib.add_theme_stylebox_override("panel", K.px9("inset9", 5, 5, 3, 3))
	h.add_child(ib)
	var tr := TextureRect.new()
	var ic_key := str(d.get("icon", "gen_cell"))
	var tex := Icons.ui_icon(ic_key)
	tr.texture = tex if tex != null else Icons.facility_icon("ability")
	tr.custom_minimum_size = Vector2(28, 28)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ib.add_child(tr)
	var tv := K.vbox(1)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tv)
	var title_h := K.hbox(5)
	tv.add_child(title_h)
	var tl := UI.label(str(d.get("name", id)), 13, UI.ACCENT if elite else K.CREAM)
	tl.clip_text = true
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_h.add_child(tl)
	title_h.add_child(K.tag(Loc.t("★ 满级专精", "★ ELITE") if elite else Loc.t("%d/%d级", "Lv.%d/%d") % [lv, mx], lv > 0))
	var sub_h := K.hbox(4)
	tv.add_child(sub_h)
	var cat_lb := UI.label(str(d.get("cat", Loc.t("技能", "Skill"))), 10, K.CREAM_DIM)
	cat_lb.clip_text = true
	cat_lb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cat_lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_h.add_child(cat_lb)
	var focus_txt := "▲129%" if mult > 1.05 else ("▼50%" if mult < 0.95 else "100%")
	var focus_col := UI.INFO if mult > 1.05 else (Color(0.84, 0.44, 0.24) if mult < 0.95 else K.CREAM_DIM)
	sub_h.add_child(UI.label(focus_txt, 10, focus_col))

	var ph := K.hbox(5)
	v.add_child(ph)
	var pips = K.Pips.new(mx)
	pips.set_level(lv)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(pips)
	var sp_p := Control.new()
	sp_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(sp_p)
	ph.add_child(UI.label(Loc.t("满级", "MAX") if elite else "%.1f/%d" % [xp, int(need)], 10, UI.ACCENT if elite else K.CREAM_DIM))

	var bar = K.PixBar.new(6)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.set_frac(1.0 if elite or need <= 0.0 else clampf(xp / need, 0.0, 1.0))
	v.add_child(bar)

	v.add_child(K.wrap(Loc.t("每级：", "Per Level: ") + str(d.get("effect", "")), UI.GOOD if lv > 0 else UI.INFO))
	var el_txt := str(d.get("elite", ""))
	if el_txt != "":
		v.add_child(K.wrap(Loc.t("满级：", "Mastery: ") + el_txt, UI.ACCENT if elite else K.CREAM_DIM))
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	var how_box := PanelContainer.new()
	how_box.add_theme_stylebox_override("panel", K.px9("inset9", 5, 5, 3, 3))
	how_box.add_child(K.wrap(Loc.t("锻炼：", "Trained by: ") + str(d.get("how", "")), Color(0.76, 0.80, 0.72)))
	v.add_child(how_box)
	return c


func _skills_pods() -> void:
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
		nh.add_child(K.tag(Loc.pod_tier_str(tier) if tier > 0 else Loc.t("未购置", "Unowned"), tier > 0))
		hv.add_child(UI.label(str(d.get("name", id)), 12, K.CREAM))
		hv.add_child(UI.label(str(d.get("role", "")), 12, UI.INFO))
		var p = K.Pips.new(Growth.POD_MAX_TIER)
		p.set_level(tier)
		hv.add_child(p)
		var tiers: Array = d.get("tiers", [])
		for i in tiers.size():
			v.add_child(K.req_row("%s　%s" % [Loc.pod_tier_str(i + 1), tiers[i]], Loc.t("已装备", "Equipped") if i < tier else (Loc.t("下一级", "Next Tier") if i == tier else Loc.t("未解锁", "Locked")), i < tier, i >= tier))
		var reason := Growth.can_buy_pod(id)
		if reason != "已满级":
			var rh := K.hbox(6)
			v.add_child(rh)
			rh.add_child(UI.label(Loc.t("需求", "Requirements"), 12, K.CREAM_DIM))
			v.add_child(K.req_list(Growth.cost_parts(Growth.pod_cost(id)), _item_name))
		var bh := K.hbox(8)
		v.add_child(bh)
		var b := K.primary((Loc.t("购置部署仓", "Purchase Deploy Pod") if tier == 0 else Loc.t("升级至 %s", "Upgrade to %s") % Loc.pod_tier_str(tier + 1)) if reason == "" else ((Loc.t("购置", "Purchase") if tier == 0 else Loc.t("升级", "Upgrade")) + " · " + Loc.reason(reason)) if reason != "已满级" else Loc.t("已满级", "Maxed"))
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
		cb.text = Loc.t("■ 随行", "■ Active") if Growth.pod_on(id) else Loc.t("待命", "Standby")
		cb.tooltip_text = Loc.t("本次出击是否随行", "Toggle squadmate for this sortie")
		cb.custom_minimum_size = Vector2(80, 32)
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(func(x: bool):
			Growth.set_pod_on(id, x)
			refresh())
		bh.add_child(cb)

	var sq := Growth.ally_squad()
	var names: Array = []
	for a in sq:
		names.append("%s %s" % [str(Growth.pilot_data(str(a.pilot)).get("name", a.pilot)), Loc.pod_tier_str(int(a.tier))])
	_sec(skills_body, Loc.t("本次随行", "Active Squad"), "Squad", Loc.t("单机出击", "Solo Drop") if names.is_empty() else " · ".join(names))
	var row := K.hbox(8)
	skills_body.add_child(row)
	var me = K.Avatar.new(40, Growth.PROTAGONIST, "lead")
	me.tooltip_text = Growth.player_name()
	me.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(me)
	for a in sq:
		row.add_child(K.Avatar.new(40, str(a.pilot), "on"))


# ============================================================ 5. 仓库视图（藏匿处：大网格 + 分类筛选 + 物品详情）
func _build_stash_view(parent: Control) -> void:
	var v_s := _view(parent, "stash")
	const RW := 380.0

	var lp := _tpanel(v_s, Loc.t("仓库"), "Stash", FILL, [K.M, K.GAP, -K.M - RW - K.GAP, -K.GAP])
	stash_count_lbl = lp[2]
	var lv: VBoxContainer = lp[1]
	var f_grp := ButtonGroup.new()
	var fh := K.hbox(4)
	lv.add_child(fh)
	for cf in [["all", Loc.t("全部", "All")], ["module", Loc.t("模块", "Modules")], ["use", Loc.t("消耗品", "Consumables")], ["food", Loc.t("食物", "Rations")], ["misc", Loc.t("杂物", "Salvage")], ["money", Loc.t("贵重品", "Valuables")]]:
		var k: String = cf[0]
		var b := Button.new()
		b.text = str(cf[1])
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
	stash_list.show_names = true
	stash_list.empty_text = Loc.t("货架空空荡荡，暂无该类物资。", "No items in this category.")
	stash_list.item_selected.connect(_on_stash_selected)
	stash_list.item_activated.connect(func(_i): _move_to_cargo())
	stash_list.item_context.connect(func(i):
		if i < stash_ids.size():
			_open_ctx(str(stash_ids[i]), "stash"))
	lv.add_child(_scroll(stash_list))

	var mb := K.hbox(6)
	lv.add_child(mb)
	_btn(mb, Loc.t("装入出击货舱", "Move to Cargo"), _move_to_cargo).custom_minimum_size.y = 30
	_btn(mb, Loc.t("出售 1 件", "Sell 1"), _sell_selected).custom_minimum_size.y = 30
	_btn(mb, Loc.t("出售全部食物与杂物", "Sell All Rations & Salvage"), _sell_junk).custom_minimum_size.y = 30

	var rp := _tpanel(v_s, Loc.t("物品详情", "Inspect"), "Inspect", RIGHT, [-K.M - RW, K.GAP, -K.M, -K.GAP])
	var rv: VBoxContainer = rp[1]
	var ih := K.hbox(10)
	rv.add_child(ih)
	stash_icon_rect = K.IconCell.new(96)
	stash_icon_rect.set_box_size(Vector2(168, 96))
	ih.add_child(stash_icon_rect)
	var nv := K.vbox(4)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ih.add_child(nv)
	stash_name_lbl = UI.label(Loc.t("未选择物品", "No Item Selected"), 13, K.CREAM)
	stash_name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nv.add_child(stash_name_lbl)
	stash_tag_box = HFlowContainer.new()
	stash_tag_box.add_theme_constant_override("h_separation", 4)
	stash_tag_box.add_theme_constant_override("v_separation", 4)
	nv.add_child(stash_tag_box)
	var r := K.Rule.new()
	r.solid = true
	rv.add_child(r)
	var insp_v := K.vbox(6)
	insp_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stash_kv_box = K.vbox(4)
	insp_v.add_child(stash_kv_box)
	stash_detail_lbl = K.wrap("", K.CREAM)
	insp_v.add_child(stash_detail_lbl)
	_sec(insp_v, Loc.t("升级用途", "Used in"), "Used in")
	stash_use_lbl = K.wrap("", K.CREAM_DIM)
	insp_v.add_child(stash_use_lbl)
	rv.add_child(_scroll(insp_v))


# ============================================================ 6. 图鉴视图（手册：左侧分类树 + 搜索，右侧详情）
func _build_codex_view(parent: Control) -> void:
	var v_c := _view(parent, "codex")
	const LW := 300.0

	var lp := _tpanel(v_c, Loc.t("手册", "Handbook"), "Handbook", LEFT, [K.M, K.GAP, K.M + LW, -K.GAP])
	var lv: VBoxContainer = lp[1]
	codex_search = LineEdit.new()
	codex_search.placeholder_text = Loc.t("搜索条目……", "Search entries...")
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

	var rpp := _tpanel(v_c, Loc.t("条目", "Entry"), "Entry", FILL, [K.M + LW + K.GAP, K.GAP, -K.M, -K.GAP])
	codex_path_lbl = rpp[2]
	var rv: VBoxContainer = rpp[1]
	var top_card := K.card(false, 10)
	rv.add_child(top_card)
	var ch := K.hbox(14)
	top_card.add_child(ch)
	codex_avatar = K.Avatar.new(128, "nao", "on")
	ch.add_child(codex_avatar)
	codex_portrait = TextureRect.new()
	codex_portrait.custom_minimum_size = Vector2(168, 104)
	codex_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	codex_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	codex_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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

	_sec(rv, Loc.t("档案简述", "Profile"), "Profile")
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
	var n := Loc.char_profile(k, "name", str(info.get("name", k)))
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
		if q != "" and text.to_lower().find(q.to_lower()) < 0:
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
	var folder := func(parent: TreeItem, text: String) -> TreeItem:
		var f := codex_tree.create_item(parent)
		f.set_text(0, text)
		f.set_custom_color(0, K.CREAM_DIM)
		f.set_selectable(0, false)
		return f
	var f_crew: TreeItem = folder.call(root, Loc.t("人物档案", "Personnel"))
	var f_c1: TreeItem = folder.call(f_crew, Loc.t("主角团", "Squad"))
	for k in K.CREW:
		add_leaf.call(f_c1, "crew", k, _char_name(k), K.avatar_tex(k, 20), K.CREAM)
	var f_c2: TreeItem = folder.call(f_crew, Loc.t("黑市商人", "Traders"))
	for k in K.MERCHANT_IDS:
		add_leaf.call(f_c2, "crew", k, _char_name(k), K.avatar_tex(k, 20), K.CREAM)
	var f_mod: TreeItem = folder.call(root, Loc.t("机甲模块", "Mech Modules"))
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
			var sname: String = str(GameData.SLOT_NAMES.get(s, Loc.t("手臂武装", "Arm Weapons") if s == "arm" else s))
			slots[s] = folder.call(f_mod, sname)
		add_leaf.call(slots[s], "module", id, str(m.name), Icons.icon(id), GameData.RARITY_COLORS[int(m.rar)])
	var f_en: TreeItem = folder.call(root, Loc.t("深渊异体", "Bestiary"))
	var f_e1: TreeItem = folder.call(f_en, Loc.t("常规群落", "Common Swarm"))
	var f_e2: TreeItem = folder.call(f_en, Loc.t("领主级", "Apex Bosses"))
	for k in GameData.ENEMIES.keys():
		var ed: Dictionary = GameData.ENEMIES[k]
		add_leaf.call(f_e2 if ed.get("boss", false) else f_e1, "enemy", k, str(ed.get("name", k)), null, UI.BAD.lerp(K.CREAM, 0.4))
	var f_map: TreeItem = folder.call(root, Loc.t("战区档案", "Sectors"))
	for id in GameData.map_ids():
		var md: Dictionary = GameData.MAPS[id]
		if bool(md.get("hidden", false)) and not Story.has_flag("ch6_done") and not Story.is_codex_unlocked("map_" + str(id)):
			continue
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
	codex_path_lbl.text = {
		"crew": Loc.t("人物档案", "Personnel"),
		"module": Loc.t("机甲模块", "Mech Modules"),
		"enemy": Loc.t("深渊异体", "Bestiary"),
		"map": Loc.t("战区档案", "Sectors"),
	}.get(tab, "")
	match tab:
		"crew":
			var p: Dictionary = CHAR_PROFILES.get(id, {})
			codex_avatar.set_char(id, 128)
			codex_full.texture = AssetPaths.portrait(id)
			codex_avatar.set_state("lead" if id == Growth.PROTAGONIST else "on")
			codex_title_lbl.text = _char_name(id)
			codex_sub_lbl.text = Growth.subst(Loc.char_profile(id, "role", str(p.get("role", ""))))
			codex_detail_lbl.text = Growth.subst(Loc.char_profile(id, "desc", str(p.get("desc", ""))))
			var g: Array = []
			if Growth.pilot_ids().has(id):
				g.append(Loc.t("驾驶员 %s", "Pilot %s") % Loc.lv(Growth.pilot_level(id)))
			for pid in Growth.pod_ids():
				if Growth.pod_pilot(pid) == id:
					g.append((Loc.t("部署仓 %s", "Pod %s") % Loc.pod_tier_str(Growth.pod_tier(pid))) if Growth.pod_tier(pid) > 0 else Loc.t("部署仓 未购置", "Pod Unowned"))
			if Growth.crew_ids().has(id):
				g.append(Loc.t("好感 %s / %d", "Affinity %s / %d") % [Loc.lv(Growth.crew_level(id)), Growth.CREW_MAX])
			codex_growth_lbl.text = "  ·  ".join(g)
		"module":
			var m: Dictionary = GameData.MODULES.get(id, {})
			codex_portrait.texture = Icons.icon(id)
			codex_portrait.visible = true
			codex_title_lbl.text = str(m.get("name", ""))
			codex_sub_lbl.text = Loc.t("%s模块 · %s · %dkg · ¥%d", "%s · %s · %dkg · ¥%d") % [GameData.SLOT_NAMES.get(m.get("slot", ""), ""), GameData.RARITY_NAMES[int(m.get("rar", 0))], int(m.get("w", 0)), int(m.get("v", 0))]
			var d_txt := Growth.subst(str(m.get("desc", Loc.t("军用标准模块。", "Standard military module."))))
			var sk := GameData.module_skill_info(id)
			var extra_lines: Array = []
			if m.has("caliber"):
				extra_lines.append(Loc.t("弹药规格：%s", "Caliber: %s") % str(m.caliber))
			if not sk.is_empty():
				var sk_line := Loc.t("【车载分系统 [%s] %s】", "[Subsystem [%s] %s]") % [str(sk.key), str(sk.name)]
				if str(sk.id) != "none":
					sk_line += Loc.t("（冷却 %.1f秒 · 功耗 %.0f 能源）", " (CD %.1fs · %.0f EN)") % [float(sk.cd), float(sk.cost)]
				if str(sk.get("desc", "")) != "":
					sk_line += "\n" + str(sk.desc)
				extra_lines.append(sk_line)
			codex_growth_lbl.text = "\n".join(extra_lines)
			codex_detail_lbl.text = d_txt
			if m.has("armor_class"):
				_stat_cell(Loc.t("防弹", "Armor Class"), Loc.armor_tier(int(m.armor_class)), UI.GOOD if int(m.armor_class) >= 4 else UI.INFO)
			if m.has("pen"):
				_stat_cell(Loc.t("穿深", "Penetration"), Loc.t("%dmm(%d级)", "%dmm (C%d)") % [int(m.pen), GameData.pen_class(float(m.pen))], UI.GOOD if int(m.pen) >= 38 else UI.INFO)
			if m.has("ergo"):
				_stat_cell(Loc.t("工效", "Ergonomics"), "%d" % int(m.ergo), UI.INFO)
			if m.has("moa"):
				_stat_cell(Loc.t("精度", "Spread"), Loc.t("%.1f 角分", "%.1f MOA") % float(m.moa), UI.INFO)
			var name_map := {
				"hp": Loc.t("结构", "Hull"),
				"energy": Loc.t("能源", "Energy"),
				"speed": Loc.t("速度", "Speed"),
				"load": Loc.t("承重", "Load"),
				"cargo": Loc.t("货舱", "Cargo"),
				"armor": Loc.t("减伤", "Mitigation"),
				"dmg": Loc.t("伤害", "Damage"),
				"rate": Loc.t("射速", "ROF"),
				"range": Loc.t("射程", "Range"),
			}
			for stat_k in ["hp", "energy", "speed", "load", "cargo", "armor", "dmg", "rate", "range"]:
				if m.has(stat_k):
					if stat_k == "speed" and str(m.get("slot", "")) == "arm":
						continue
					var v_txt := str(m[stat_k])
					if stat_k == "armor":
						v_txt = "%d%%" % int(round(float(m[stat_k]) * 100.0))
					_stat_cell(name_map[stat_k], v_txt, UI.INFO)
			if str(m.get("slot", "")) == "arm":
				var en_s := str(snappedf(GameData.shot_energy_cost(m), 0.01))
				_stat_cell(Loc.t("能耗", "Energy"), Loc.t("%s/发", "%s/shot") % en_s, UI.INFO)
		"enemy":
			var e: Dictionary = GameData.ENEMIES.get(id, {})
			codex_title_lbl.text = str(e.get("name", id))
			codex_sub_lbl.text = Loc.t("深渊异化生物 · %s", "Abyssal Xenomorph · %s") % (Loc.t("领主级", "Apex Boss") if e.get("boss", false) else Loc.t("常规群落", "Common Swarm"))
			codex_detail_lbl.text = str(e.get("desc", Loc.t("游荡在深渊裂缝周边的异化生物，极具攻击性。", "Mutated abyssal organism roaming near fissure zones. Highly aggressive.")))
			var name_map := {"hp": Loc.t("生命", "Hull"), "speed": Loc.t("移动速度", "Speed"), "armor": Loc.t("护甲值", "Armor"), "dmg": Loc.t("近战杀伤", "Damage")}
			for stat_k in ["hp", "speed", "armor", "dmg"]:
				if e.has(stat_k):
					var v_txt := str(e[stat_k])
					if stat_k == "armor":
						v_txt = "%d%%" % int(round(float(e[stat_k]) * 100.0))
					_stat_cell(name_map[stat_k], v_txt, UI.BAD)
		"map":
			var md: Dictionary = GameData.MAPS.get(id, {})
			codex_title_lbl.text = str(md.get("name", id))
			codex_sub_lbl.text = Loc.t("空投战区 · %s", "Drop Sector · %s") % str(md.get("tag", ""))
			codex_detail_lbl.text = Loc.t("%s\n\n环境特性：%s", "%s\n\nEnvironment: %s") % [str(md.get("desc", "")), str(md.get("env", Loc.t("无特殊异常", "Nominal Conditions")))]
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
	GameData.apply_quality(sv, false)
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
	env.ambient_light_energy = 0.52
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.12
	var mob := OS.has_feature("mobile")
	var mob_ren := RenderingServer.get_current_rendering_method() == "mobile"
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 0.52 if (mob and GameData.quality == 0) else 0.68
	env.glow_strength = 0.92
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.set_glow_level(1, 0.85)
	env.set_glow_level(2, 0.7)
	env.set_glow_level(3, 0.45)
	env.ssao_enabled = (not mob) and (not mob_ren)
	env.ssao_radius = 1.15
	env.ssao_intensity = 2.4
	env.ssao_detail = 0.85
	env.ssao_light_affect = 0.3
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.09, 0.12)
	env.fog_density = 0.018
	env.volumetric_fog_enabled = false
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	preview_root.add_child(we)

	# 装配完整 87.2m 信天翁号，将既有 BAY 03 重型机甲整备舱精确置于核心机库舱位（转盘与 MechPad_Anchor(0,1.56,0) 重合，世界坐标保持 0,0,0）
	airship = AlbatrossAirship.build_integrated({
		"obs2_fit_airship": true,
		"include_obs2_lights": false,
		"include_obs2_outside": false,
		"bay03_fit_airship": false,
		"include_bay03_lights": true,
		"bay03_mob": mob,
		"bay03_mob_ren": mob_ren,
		"batch_static": true,
	})
	airship.position = -AlbatrossAirship.BAY03_MOUNT_POS
	preview_root.add_child(airship)
	AlbatrossAirship.set_cutaway_mode(airship, "legacy_bay03")
	var bay_refs: Dictionary = airship.get_meta("bay03_refs")
	turntable = bay_refs["turntable"]
	preview_root.set_meta("_keep_tt", turntable)

	var key := SpotLight3D.new()
	key.position = Vector3(2.5, 9.0, 4.0)
	key.light_energy = 9.2
	key.spot_range = 20.0
	key.spot_angle = 32.0
	key.shadow_enabled = true
	key.shadow_bias = 0.02
	key.shadow_normal_bias = 1.0
	key.shadow_blur = 0.35 if (mob or mob_ren) else 1.15
	key.light_color = Color(1.0, 0.95, 0.88)
	preview_root.add_child(key)
	key.look_at_from_position(key.position, Vector3(0, 1.5, 0))

	# UPDATE_ONCE 反射探针仅启动时烘焙一次，每帧零额外开销，低画质也保留机甲金属高光质感
	var rp := ReflectionProbe.new()
	rp.update_mode = ReflectionProbe.UPDATE_ONCE
	rp.box_projection = true
	rp.size = Vector3(28, 12, 22)
	rp.position = Vector3(0, 4.0, -1.0)
	rp.intensity = 0.72
	rp.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	preview_root.add_child(rp)

	var h_lights := [
		[Vector3(-5.0, 3.5, -2.0), Color(0.32, 0.75, 1.0), 3.0, 9.5],
		[Vector3(5.0, 2.5, -2.5), Color(1.0, 0.56, 0.22), 2.5, 9.5],
		[Vector3(-2.6, 3.4, -6.6), Color(0.56, 0.72, 0.92), 1.65, 10.5],
		[Vector3(2.6, 4.4, -5.6), Color(1.0, 0.74, 0.42), 1.95, 10.5],
	]
	var max_hl := 2 if ((mob or mob_ren) and GameData.quality == 0) else h_lights.size()
	for hi in max_hl:
		var c: Array = h_lights[hi]
		var l := OmniLight3D.new()
		l.position = c[0]
		l.light_color = c[1]
		l.light_energy = c[2]
		l.omni_range = c[3]
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

	A.emitter(preview_root, Vector3(0, 3, 0), {"amount": 28, "life": 8.0, "size": 0.04, "box": Vector3(6, 3, 4), "spread": 180.0, "vmin": 0.05, "vmax": 0.15,
		"gravity": Vector3(0, -0.02, 0), "c0": Color(1, 0.9, 0.8, 0.0), "cmid": Color(1, 0.9, 0.8, 0.6), "c1": Color(1, 0.9, 0.8, 0.0), "grow0": 1.0, "grow1": 1.0})

	var cam := Camera3D.new()
	cam.position = Vector3(0, 3.1, 8.8)
	cam.fov = 40
	cam.near = 0.25
	cam.far = 45.0
	preview_root.add_child(cam)
	cam.look_at(Vector3(0, 1.9, 0))
	preview_cam = cam


func _toggle_explode() -> void:
	exploded = not exploded
	if explode_btn:
		explode_btn.text = Loc.t("◆ 组装视图", "◆ Assembled") if exploded else Loc.t("◇ 拆解视图", "◇ Exploded View")
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
	if cur_tab == "maintenance" and turntable and preview_mech:
		if not drag:
			spin += delta * 0.35
		turntable.rotation.y = lerp_angle(turntable.rotation.y, spin, clamp(delta * 8.0, 0.0, 1.0))
	if airship:
		AlbatrossAirship.spin_propellers(airship, delta, 10.0)




var _last_preview_loadout := {}

# ============================================================ 全局数据刷新与逻辑绑定
func refresh() -> void:
	GameData.save_game()
	if money_lbl:
		money_lbl.text = _fmt_money(GameData.money)
	if junk_lbl:
		var junk := 0
		for id in Growth.material_ids():
			junk += Growth.material_count(str(id))
		junk_lbl.text = "%d" % junk
	if record_lbl:
		record_lbl.text = "%d / %d" % [GameData.extracts_ok, GameData.raids]
	_refresh_crew()
	RenderingServer.global_shader_parameter_set("mech_damage", 0.0)

	if preview_mech and is_instance_valid(preview_mech):
		if GameData.loadout != _last_preview_loadout:
			_last_preview_loadout = GameData.loadout.duplicate()
			MV.apply(preview_mech, GameData.loadout, true)
			MechScript._batch_visual(preview_mech)
	elif turntable:
		_last_preview_loadout = GameData.loadout.duplicate()
		preview_mech = MV.build(GameData.loadout, true, false)
		MechScript._batch_visual(preview_mech)
		turntable.add_child(preview_mech)
		preview_mech.position.y = 0.168
		preview_mech.rotation.y = PI

	var mass := 0.0
	for slot in GameData.SLOTS:
		if not slot_name_lbls.has(slot):
			continue
		var id: String = GameData.loadout.get(slot, "")
		var nl: Label = slot_name_lbls[slot]
		var stl: Label = slot_stat_lbls[slot]
		if id == "":
			nl.text = Loc.t("— 空槽 —", "— Empty —")
			nl.add_theme_color_override("font_color", Color(0.42, 0.42, 0.38))
			stl.text = Loc.t("空位", "Vacant")
			slot_cells[slot].set_entry({})
		else:
			var m: Dictionary = GameData.module(id)
			nl.text = GameData.item_name(id)
			nl.add_theme_color_override("font_color", GameData.RARITY_COLORS[int(m.rar)])
			var sub_s := "%s · %dkg" % [GameData.RARITY_NAMES[int(m.rar)], int(m.w)]
			if m.has("armor_class"):
				sub_s += " · " + Loc.armor_tier(int(m.armor_class))
			elif m.has("range"):
				sub_s += Loc.t(" · 射程 %d", " · Range %d") % int(round(float(m.range)))
			if GameData.has_recon_tag(m):
				sub_s += Loc.t(" · 侦察", " · Recon")
			stl.text = sub_s
			slot_cells[slot].set_entry({"id": id})
			mass += float(m.w)

	var st := GameData.compute_stats(GameData.loadout)
	var cw := GameData.weight_of(GameData.cargo)
	var sf := GameData.speed_factor(st, cw)
	var runtime: float = st.energy / max(0.01, st.drain)
	if not stat_rows.is_empty():
		_stat("hp", st.hp, 300.0, "%d" % st.hp)
		_stat("armor", float(st.get("armor", 0.0)), 0.5, "%d%%" % int(round(float(st.get("armor", 0.0)) * 100)))
		_stat("energy", st.energy, 500.0, "%d · %d:%02d" % [st.energy, int(runtime) / 60, int(runtime) % 60])
		_stat("speed", st.speed * sf, 10.0, "%.1f%s" % [st.speed * sf, "" if sf > 0.99 else " ↓"])
		_stat("load", st.mass + cw, max(1.0, st.load), "%.0f / %.0f" % [st.mass + cw, st.load])
		_stat("cargo", cw, max(1.0, st.cargo), "%.1f / %.0f" % [cw, st.cargo])
		var lr: Array = stat_rows["load"]
		lr[0].color = Color(0.75, 0.6, 1.0) if sf > 0.99 else UI.BAD
		lr[1].add_theme_color_override("font_color", K.CREAM if sf > 0.99 else UI.BAD)
	if maint_mass_lbl:
		maint_mass_lbl.text = Loc.t("模块 %.0f kg", "Modules %.0f kg") % mass
	_refresh_maint_side()

	_populate_cargo()
	if cargo_lbl:
		var used_c: int = GameData.cargo_cells_used(GameData.cargo)
		var max_c: int = GameData.cargo_grid_cap(float(st.cargo))
		var grid_ok: bool = GameData.can_pack_cargo(GameData.cargo, float(st.cargo))
		cargo_lbl.text = Loc.t("%.1f / %.0f kg · %d/%d格", "%.1f / %.0f kg · %d/%d cells") % [cw, st.cargo, used_c, max_c]
		cargo_lbl.add_theme_color_override("font_color", UI.BAD if (cw > st.cargo or not grid_ok) else K.CREAM_DIM)

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

	_refresh_requests()

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
		lead_sub_lbl.text = Loc.lv(lv)
		lead_xp_bar.set_frac(1.0 if need <= 0 else float(Growth.pilot_xp(pid)) / need)
		lead_xp_bar.tooltip_text = Loc.t("满级", "MAX") if need <= 0 else Loc.t("%d / %d 经验", "%d / %d EXP") % [Growth.pilot_xp(pid), need]
	for cid in crew_avatars:
		var av = crew_avatars[cid]
		var cname_short: String = Growth.player_name() if cid == Growth.PROTAGONIST else Loc.char_profile(cid, "name", str(CHAR_PROFILES.get(cid, {}).get("name", cid))).split(" · ")[0]
		var tip := "%s · %s" % [cname_short, Loc.crew_role(cid, str(CREW_ROLE.get(cid, "")))]
		if cid == Growth.PROTAGONIST:
			var lv := Growth.pilot_level(cid)
			var need := Growth.pilot_xp_next(lv)
			tip += "\n%s · %s" % [Loc.lv(lv), Loc.t("满级", "MAX") if need <= 0 else Loc.t("%d/%d 经验", "%d/%d EXP") % [Growth.pilot_xp(cid), need]]
		for pid in Growth.pod_ids():
			if Growth.pod_pilot(pid) == cid:
				av.dim = Growth.pod_tier(pid) == 0
				tip += Loc.t("（%s）", " (%s)") % (Loc.pod_tier_str(Growth.pod_tier(pid)) if Growth.pod_tier(pid) > 0 else Loc.t("部署仓未购置", "Pod Unowned"))
				av.queue_redraw()
		if Growth.crew_ids().has(cid):
			tip += Loc.t("\n好感 %s", "\nAffinity %s") % Loc.lv(Growth.crew_level(cid))
		av.tooltip_text = tip


func _refresh_maint_side() -> void:
	if maint_squad_lbl == null:
		return
	var sq := Growth.ally_squad()
	var names: Array = []
	for a in sq:
		names.append("%s %s" % [str(Growth.pilot_data(str(a.pilot)).get("name", a.pilot)), Loc.pod_tier_str(int(a.tier))])
	var sep := ", " if Loc.is_en() else "、"
	maint_squad_lbl.text = Loc.t("随行：", "Squad: ") + (Loc.t("单机出击", "Solo Drop") if names.is_empty() else sep.join(names))


func _refresh_requests() -> void:
	if request_list == null:
		return
	for c in request_list.get_children():
		request_list.remove_child(c)
		c.queue_free()
	var m := cur_merchant
	# 双列排布：5-6 条委托在现有面板高度内全部可见，无需滚动
	var cols: Array = []
	for _i in 2:
		if not cols.is_empty():
			var ln := ColorRect.new()
			ln.color = Color(1, 1, 1, 0.22)
			ln.custom_minimum_size = Vector2(1, 0)
			ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
			request_list.add_child(ln)
		var cv := K.vbox(2)
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		request_list.add_child(cv)
		cols.append(cv)
	var qs := GameData.merchant_quests(m)
	for i in qs.size():
		var q: Dictionary = qs[i]
		var st := int(q.get("status", 0))
		var typ := GameData.quest_type(q)
		var need := int(q.count)
		var have := 0
		var prog := 0
		var ready := false
		if typ == "item":
			have = GameData.count_in_stash(str(q.get("id", "")))
			ready = have >= need
		else:
			prog = GameData.quest_progress_of(m, int(q.index))
			ready = prog >= need
		var row := K.hbox(6)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if typ == "item":
			var ic := K.IconCell.new(20)
			ic.set_entry({"id": str(q.get("id", ""))})
			row.add_child(ic)
		else:
			var pad := Control.new()
			pad.custom_minimum_size = Vector2(20, 20)
			row.add_child(pad)
		var col := Color(0.42, 0.42, 0.38) if st == 2 else (UI.GOOD if ready else K.CREAM)
		var nm := UI.label(GameData.quest_name(q), 12, col)
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.custom_minimum_size.x = 64
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(nm)
		var dt := UI.label("— " + GameData.quest_objective(q), 12, Color(0.42, 0.42, 0.38) if st == 2 else K.CREAM_DIM)
		dt.clip_text = true
		dt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		dt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dt)
		var hv_text := "—" if st == 2 else (Loc.t("仓库 %d/%d", "Stash %d/%d") % [have, need] if typ == "item" else "%d/%d" % [prog, need])
		var hv := UI.label(hv_text, 12, Color(0.42, 0.42, 0.38) if st == 2 else (UI.GOOD if ready else K.CREAM_DIM))
		hv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(hv)
		var rw := UI.label("¥ %s" % _fmt_money(int(q.reward)), 12, Color(0.74, 0.61, 0.28))
		rw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(rw)
		var b := Button.new()
		b.custom_minimum_size = Vector2(56, 20)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.set_meta("sfx", "")
		var qi := int(q.index)
		if st == 2:
			b.text = Loc.t("已完成", "Done")
			b.disabled = true
		elif st == 1:
			b.text = Loc.t("提交", "Turn In")
			b.disabled = not ready
			b.pressed.connect(func():
				if GameData.fulfill_quest(m, qi):
					Audio.play_ui("request_complete")
					refresh()
				else:
					Audio.play_ui("ui_denied"))
		else:
			b.text = Loc.t("接取", "Accept")
			b.pressed.connect(func():
				if GameData.accept_quest(m, qi):
					Audio.play_ui("ui_confirm")
					refresh()
				else:
					Audio.play_ui("ui_denied"))
		row.add_child(b)
		(cols[i % 2] as VBoxContainer).add_child(row)


func _refresh_trade_list() -> void:
	for m_id in merchant_cards:
		var b: Button = merchant_cards[m_id]
		var aff: HBoxContainer = b.get_meta("aff")
		for c in aff.get_children():
			aff.remove_child(c)
			c.queue_free()
		aff.alignment = BoxContainer.ALIGNMENT_CENTER
		if Growth.crew_ids().has(m_id):
			aff.add_child(UI.label(Loc.t("好感", "Trust"), 12, K.CREAM_DIM))
			var p = K.Pips.new(Growth.CREW_MAX)
			p.set_level(Growth.crew_level(m_id))
			aff.add_child(p)
			aff.add_child(UI.label(Loc.lv(Growth.crew_level(m_id)), 12, UI.ACCENT))
		else:
			aff.add_child(UI.label(Loc.t("好感 —  尚无往来", "Trust — Unacquainted"), 12, Color(0.42, 0.42, 0.38)))
		var n := 0
		for id in MERCHANTS[m_id].get("items", []):
			if GameData.ITEMS.has(id):
				n += 1
		(b.get_meta("stock") as Label).text = Loc.t("供货 %d 种", "%d Offers") % n
	if account_box:
		for c in account_box.get_children():
			account_box.remove_child(c)
			c.queue_free()
		account_box.add_child(K.kv(Loc.t("信用点", "Credits"), "¥ %s" % _fmt_money(GameData.money), Color(0.74, 0.61, 0.28)))
		account_box.add_child(K.kv(Loc.t("仓库物品", "Stash Items"), Loc.t("%d 件", "%d items") % GameData.stash.size()))
		account_box.add_child(K.kv(Loc.t("仓库估值", "Stash Value"), "¥ %s" % _fmt_money(GameData.value_of(GameData.stash))))
		var junk := 0
		for id in GameData.stash:
			var c: String = GameData.item(id).cat
			if c == "food" or c == "misc":
				junk += int(GameData.item(id).v)
		account_box.add_child(K.kv(Loc.t("食物与杂物可售", "Sellable Rations & Salvage"), "¥ %s" % _fmt_money(junk)))


func _populate_stash_list() -> void:
	if not stash_list:
		return
	var es := _stack(GameData.stash, stash_filter)
	stash_ids.clear()
	for e in es:
		stash_ids.append(e.id)
	stash_list.set_entries(es)
	if stash_count_lbl:
		stash_count_lbl.text = Loc.t("%d 件 · %.1f kg · 估值 ¥%s", "%d items · %.1f kg · Value ¥%s") % [GameData.stash.size(), GameData.weight_of(GameData.stash), _fmt_money(GameData.value_of(GameData.stash))]
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
			e["hint"] = ""
	maint_grid.set_entries(es)
	if maint_count_lbl:
		maint_count_lbl.text = Loc.t("%d 件 · %.1f kg", "%d items · %.1f kg") % [GameData.stash.size(), GameData.weight_of(GameData.stash)]


func _populate_deploy_stash() -> void:
	if not deploy_stash_list:
		return
	var es: Array = []
	deploy_stash_ids.clear()
	for e in _stack(GameData.stash):
		var it := GameData.item(e.id)
		if it.cat == "use" or it.cat == "food":
			e["hint"] = ""
			es.append(e)
			deploy_stash_ids.append(e.id)
	deploy_stash_list.empty_text = Loc.t("仓库里没有消耗品或食物。", "No consumables or rations in stash.")
	deploy_stash_list.set_entries(es)


func _populate_cargo() -> void:
	if not cargo_list:
		return
	var st := GameData.compute_stats(GameData.loadout)
	var crows: int = GameData.cargo_grid_rows(float(st.cargo))
	cargo_list.fixed_cols = GameData.CARGO_COLS
	cargo_list.min_rows = crows
	cargo_list.cap_rows = crows
	GameData.pack_cargo_inplace(GameData.cargo, float(st.cargo))
	var es: Array = []
	cargo_ids.clear()
	for id in GameData.cargo:
		cargo_ids.append(id)
		es.append({"id": id, "count": 1, "hint": ""})
	cargo_list.empty_text = Loc.t("货舱是空的：从左侧装入消耗品与食物。", "Cargo bay empty: load consumables and rations from the left.")
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
		es.append({"id": id, "price": p, "bad": GameData.money < p, "hint": "¥%s" % _fmt_money(p)})
		shop_ids.append(id)
	shop_list.set_entries(es)
	if selected_shop >= 0 and selected_shop < shop_ids.size():
		shop_list.select(selected_shop)
	if shop_count_lbl:
		shop_count_lbl.text = Loc.t("%d 种商品", "%d Offers") % shop_ids.size()
	if trade_stash_grid:
		var ts := _stack(GameData.stash)
		trade_stash_ids.clear()
		for e in ts:
			trade_stash_ids.append(e.id)
			e["hint"] = Loc.t("收购价 ¥%s", "Sell ¥%s") % _fmt_money(int(GameData.item(e.id).v))
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
	stash_kv_box.add_child(K.kv(Loc.t("重量", "Weight"), "%.1f kg" % float(it.w)))
	var gsz: Vector2i = GameData.item_grid_size(selected_stash)
	stash_kv_box.add_child(K.kv(Loc.t("占用格位", "Grid Size"), Loc.t("%d×%d（%d格）", "%d×%d (%d cells)") % [gsz.x, gsz.y, gsz.x * gsz.y]))
	stash_kv_box.add_child(K.kv(Loc.t("价值", "Value"), "¥ %s" % _fmt_money(int(it.v)), Color(0.74, 0.61, 0.28)))
	stash_kv_box.add_child(K.kv(Loc.t("库存", "In Stash"), "×%d" % GameData.count_in_stash(selected_stash)))
	stash_kv_box.add_child(K.kv(Loc.t("合计重量", "Total Weight"), "%.1f kg" % (float(it.w) * GameData.count_in_stash(selected_stash))))
	if it.cat == "module":
		var m: Dictionary = GameData.module(selected_stash)
		var slot_s := str(m.get("slot", ""))
		if GameData.has_recon_tag(m):
			stash_tag_box.add_child(K.tag(Loc.t("侦察", "Recon"), true))
		stash_kv_box.add_child(K.kv(Loc.t("安装槽位", "Mount Slot"), str(GameData.SLOT_NAMES.get(slot_s, Loc.t("手臂武装", "Arm Weapons")))))
		if m.has("armor_class"):
			stash_kv_box.add_child(K.kv(Loc.t("防弹等级", "Armor Class"), Loc.armor_tier(int(m.armor_class)), UI.GOOD if int(m.armor_class) >= 4 else UI.INFO))
		if GameData.has_recon_tag(m):
			stash_kv_box.add_child(K.kv(Loc.t("侦察视距 [侦察]", "Recon View [Recon]"), "+%d" % int(round(float(m.get("recon", 0.0)))), UI.GOOD))
		if m.has("ergo"):
			stash_kv_box.add_child(K.kv(Loc.t("人机工效", "Ergonomics"), "%d" % int(m.ergo), UI.GOOD if int(m.ergo) >= 65 else K.CREAM))
		if m.has("caliber"):
			stash_kv_box.add_child(K.kv(Loc.t("弹药规格", "Caliber"), str(m.caliber), K.CREAM))
		if m.has("pen"):
			var pc := GameData.pen_class(float(m.pen))
			stash_kv_box.add_child(K.kv(Loc.t("穿甲深度", "Penetration"), Loc.t("%d mm · %d级穿深", "%d mm · Class %d Pen") % [int(m.pen), pc], UI.GOOD if pc >= 4 else UI.INFO))
		if m.has("moa"):
			stash_kv_box.add_child(K.kv(Loc.t("散布精度", "Spread"), Loc.t("%.1f 角分", "%.1f MOA") % float(m.moa), UI.INFO))
		var names := {
			"hp": Loc.t("结构耐久", "Hull Integrity"),
			"cargo": Loc.t("货舱扩容", "Cargo Cap"),
			"energy": Loc.t("电力容量", "Power Cap"),
			"speed": Loc.t("巡航速度", "Cruise Speed"),
			"load": Loc.t("底盘承重", "Chassis Load"),
			"dmg": Loc.t("单发伤害", "Damage"),
			"rate": Loc.t("理论射速", "Fire Rate"),
			"armor": Loc.t("附加减伤", "Mitigation"),
			"range": Loc.t("武器射程", "Weapon Range"),
		}
		for k in ["hp", "armor", "energy", "speed", "load", "cargo", "dmg", "rate", "range"]:
			if m.has(k):
				if k == "speed" and slot_s == "arm":
					continue
				var v_txt := str(m[k])
				if k == "armor":
					v_txt = "%d%%" % int(round(float(m[k]) * 100.0))
				elif k == "dmg" and int(m.get("pellets", 1)) > 1:
					v_txt = "%.0f × %d (%.0f)" % [float(m.dmg), int(m.pellets), float(m.dmg) * int(m.pellets)]
				elif k == "range":
					var rv := float(m.range)
					v_txt = "%.0f%s" % [rv, Loc.t("（远距视距）", " (Long)") if rv > 10.0 else (Loc.t("（标准视距）", " (Standard)") if is_equal_approx(rv, 10.0) else Loc.t("（近距）", " (Short)"))]
				stash_kv_box.add_child(K.kv(names[k], v_txt, UI.GOOD if (k == "range" and float(m.range) > 10.0) else UI.INFO))
		if slot_s == "arm":
			if m.has("speed"):
				stash_kv_box.add_child(K.kv(Loc.t("弹道初速", "Muzzle Vel."), "%.0f m/s" % float(m.speed), K.CREAM_DIM))
			var en_s := str(snappedf(GameData.shot_energy_cost(m), 0.01))
			stash_kv_box.add_child(K.kv(Loc.t("射击资源", "Fire Resource"), Loc.t("能量 %s/发", "Energy %s/shot") % en_s, K.CREAM))
		var sk := GameData.module_skill_info(selected_stash)
		if not sk.is_empty():
			stash_kv_box.add_child(K.kv(Loc.t("车载分系统 [%s]", "Subsystem [%s]") % str(sk.key), str(sk.name), UI.ACCENT))
			if str(sk.id) != "none":
				stash_kv_box.add_child(K.kv(Loc.t("冷却 / 功耗", "CD / Drain"), Loc.t("%.1f秒 · %.0f 能源", "%.1fs · %.0f EN") % [float(sk.cd), float(sk.cost)], K.CREAM_DIM))
	if stash_detail_lbl:
		stash_detail_lbl.text = Growth.subst(str(it.get("desc", "")))
	if stash_icon_rect:
		stash_icon_rect.set_entry({"id": selected_stash, "count": GameData.count_in_stash(selected_stash)})
	if stash_use_lbl:
		var uses := Growth.material_uses(selected_stash)
		var sep := ", " if Loc.is_en() else "、"
		stash_use_lbl.text = (Loc.t("可用于：", "Used for: ") + sep.join(uses)) if not uses.is_empty() else Loc.t("当前没有升级项目需要这件物资。", "Not required by any current facility or research upgrade.")
		stash_use_lbl.add_theme_color_override("font_color", UI.INFO if not uses.is_empty() else K.CREAM_DIM)


func _move_to_cargo() -> void:
	if selected_stash == "" or not GameData.stash.has(selected_stash):
		Audio.play_ui("ui_denied")
		return
	var st := GameData.compute_stats(GameData.loadout)
	if GameData.weight_of(GameData.cargo) + float(GameData.item(selected_stash).w) > st.cargo:
		if deploy_err:
			deploy_err.text = Loc.t("出击货舱超出承重上限", "Cargo bay capacity exceeded")
			deploy_err.visible = true
		Audio.play_ui("ui_denied")
		return
	var next_c: Array = GameData.cargo.duplicate()
	next_c.append(selected_stash)
	if not GameData.can_pack_cargo(next_c, float(st.cargo)):
		if deploy_err:
			deploy_err.text = Loc.t("出击货舱格位不足", "Cargo bay grid space full")
			deploy_err.visible = true
		Audio.play_ui("ui_denied")
		return
	GameData.stash.erase(selected_stash)
	GameData.cargo.append(selected_stash)
	GameData.pack_cargo_inplace(GameData.cargo, float(st.cargo))
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
	var locked: Array = GameData.accepted_ids()
	for id in GameData.stash:
		var c: String = GameData.item(id).cat
		if (c == "food" or c == "misc") and not locked.has(id):
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
			deal_info_lbl.text = Loc.t("账户信用点不足", "Insufficient credits")
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
		deploy_err.text = Loc.t("机体状态齐备，无需申请应急机架", "Rig already operational — emergency frame not needed")
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
			popup.add_icon_item(Icons.icon(id), Loc.t("装备  %s（%s）", "Equip  %s (%s)") % [GameData.item_name(id), GameData.RARITY_NAMES[int(GameData.item(id).rar)]], n)
			popup_map[n] = id
			n += 1
	if GameData.loadout.get(slot, "") != "":
		popup.add_item(Loc.t("卸下到仓库", "Unequip to Stash"), 999)
	if n == 0 and GameData.loadout.get(slot, "") == "":
		popup.add_item(Loc.t("仓库里没有可用的%s模块", "No compatible %s module in stash") % GameData.SLOT_NAMES[slot], 998)
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
				ctx_popup.add_item(Loc.t("装备到 %s", "Equip to %s") % GameData.SLOT_NAMES[slot], GameData.SLOTS.find(slot))
	if it.cat == "use" or it.cat == "food":
		ctx_popup.add_item(Loc.t("装入出击货舱", "Move to Cargo"), 100)
	ctx_popup.add_item(Loc.t("出售 1 件（¥%s）", "Sell 1 (¥%s)") % _fmt_money(int(it.v)), 101)
	if cur_tab != "stash":
		ctx_popup.add_item(Loc.t("在仓库页查看", "Inspect in Stash"), 102)
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
