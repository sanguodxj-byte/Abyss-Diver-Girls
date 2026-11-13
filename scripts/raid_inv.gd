extends Control
## 局内战术整备、部位损管与容器搜刮终端（参考《逃离塔科夫》库存/搜刮界面）
## 支持两种进入方式：
##   1. 局内随时按 [Tab] / [I] 或点击右上角「整备 [TAB]」打开（战地整备模式）
##   2. 靠近容器按 [G] 打开（容器搜刮模式，带逐格扫描判明动画）
## 左栏：机体 6 槽挂载卡片 + 部位完好度损管条 + 故障惩罚提示 + 战地快捷抢修/充能
## 中栏：塔科夫正方格货舱（分类筛选/一键整理/拖拽/右键菜单/价值密度与任务标记）+ 1~8/T 战术胸挂快捷栏
## 右栏：容器搜刮网格（含未判明 ??? 格与扫描进度条）或战地急需物资备忘 + 物品战术检视与装备属性对比面板

const UI = preload("res://scripts/ui.gd")
const K = preload("res://scripts/hub_kit.gd")
const Icons = preload("res://scripts/item_icons.gd")
const Growth = preload("res://scripts/progression/growth.gd")

const PANEL_W := 1172
const PANEL_H := 656

const RIG_ITEMS := [
	{"key": "1", "id": "fuel_cell", "name": "燃料", "en": "Fuel"},
	{"key": "2", "id": "repair_kit", "name": "维修", "en": "Repair"},
	{"key": "3", "id": "sonic_decoy", "name": "诱饵", "en": "Decoy"},
	{"key": "4", "id": "extract_flare", "name": "烟幕", "en": "Flare"},
	{"key": "5", "id": "energy_rod", "name": "电池", "en": "Battery"},
	{"key": "6", "id": "coolant_pack", "name": "冷却", "en": "Coolant"},
	{"key": "7", "id": "extract_barrier", "name": "屏障", "en": "Barrier"},
	{"key": "8", "id": "surge_cell", "name": "超频", "en": "Surge"},
	{"key": "T", "id": "beacon", "name": "信标", "en": "Beacon"},
]

const PART_PENALTY_DESC := {
	"core": "重创：燃料自然漏损",
	"legs": "重创：移速降低 45%",
	"arm_l": "重创：散布×1.6 · 换弹变慢",
	"arm_r": "重创：散布×1.6 · 换弹变慢",
	"back": "重创：挂载冷却延长",
	"gen": "重创：回能效率减半",
}

const PART_PENALTY_EN := {
	"core": "Critical: Fuel Leak",
	"legs": "Critical: -45% Speed",
	"arm_l": "Critical: ×1.6 Spread · Slow Reload",
	"arm_r": "Critical: ×1.6 Spread · Slow Reload",
	"back": "Critical: Longer Cooldown",
	"gen": "Critical: -50% Regen",
}


func _part_penalty(slot: String) -> String:
	var zh := str(PART_PENALTY_DESC.get(slot, "机能受损"))
	var en := str(PART_PENALTY_EN.get(slot, "Function Impaired"))
	return Loc.t(zh, en)

var raid
var hud

# 顶部遥测标签
var mode_tag: PanelContainer
var mode_lbl: Label
var pilot_av: K.Avatar
var pilot_lbl: Label
var hp_lbl: Label
var en_lbl: Label
var load_lbl: Label
var cargo_top_lbl: Label
var val_top_lbl: Label

# 左栏：6 个机甲槽位卡片与损管
var slot_cards := {}
var mech_summary_lbl: Label
var btn_quick_fuel: Button
var btn_quick_repair: Button

# 中栏：货舱网格与胸挂
var cargo_bar: K.PixBar
var cargo_hdr_lbl: Label
var cat_filter := "all"
var filter_btns := {}
var cargo_grid: RaidGrid
var rig_cells := []

# 右栏上：容器搜刮 / 战地备忘
var right_top_title: Label
var right_top_en: Label
var right_top_sub: Label
var box_view: VBoxContainer
var scan_box: VBoxContainer
var scan_lbl: Label
var scan_bar: K.PixBar
var btn_take_all: Button
var box_grid: RaidGrid
var intel_view: VBoxContainer
var btn_open_near: Button
var intel_list: VBoxContainer

# 右栏下：战术检视与对比
var insp_icon: K.IconCell
var insp_name: Label
var insp_tags: Label
var insp_meta: Label
var insp_quest_lbl: Label
var insp_desc: Label
var insp_cmp_box: VBoxContainer
var insp_actions: HBoxContainer

# 选中状态：source = "slot" | "cargo" | "box" | "rig"
var sel_source := ""
var sel_slot := "core"
var sel_index := -1
var sel_id := ""

# 需求缓存：item_id -> {"quest": bool, "bounty": bool, "upgrade": String}
var _need_map := {}
var ctx_menu: PopupMenu
var _ctx_actions: Array = []


## 局内专用塔科夫网格：支持未判明（mystery）格、左上短名、右上任务/基建角标、左下重量、右下价值、Ctrl+点击与拖放
class RaidGrid extends Control:
	signal cell_selected(idx: int)
	signal cell_activated(idx: int, ctrl_held: bool)
	signal cell_context(idx: int, global_pos: Vector2)

	var inv
	var grid_kind := "cargo" # "cargo" or "box"
	var cell := 52
	var cols := 7
	var min_rows := 5
	var entries: Array = [] # [{id, real_idx, mystery, quest, upgrade, is_mod}]
	var selected := -1
	var hover := -1
	var _ox := 0.0

	func _init(owner_inv, kind: String, c_px := 52, c_cols := 7, m_rows := 5) -> void:
		inv = owner_inv
		grid_kind = kind
		cell = c_px
		cols = c_cols
		min_rows = m_rows
		mouse_filter = Control.MOUSE_FILTER_STOP
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(cols * cell, min_rows * cell)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func set_entries(arr: Array) -> void:
		entries = arr
		if selected >= entries.size():
			selected = entries.size() - 1
		_relayout()
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_relayout()
		elif what == NOTIFICATION_MOUSE_EXIT and hover != -1:
			hover = -1
			queue_redraw()

	func _relayout() -> void:
		var c := maxi(cols, int(floor(size.x / cell))) if size.x > 10.0 else cols
		cols = c
		_ox = floor((size.x - cols * cell) * 0.5) if size.x > cols * cell else 0.0
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
		return i if i >= 0 and i < entries.size() else -1

	func _cell_rect(i: int) -> Rect2:
		return Rect2(_ox + (i % cols) * cell, int(i / cols) * cell, cell, cell)

	func _draw() -> void:
		var font := get_theme_default_font()
		var rows := maxi(min_rows, int(ceil(float(maxi(entries.size(), 1)) / cols)))
		var total := rows * cols
		draw_rect(Rect2(_ox, 0, cols * cell, rows * cell), Color(0.02, 0.022, 0.02, 0.92))
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		for i in total:
			var r := _cell_rect(i)
			if i >= entries.size():
				draw_style_box(K.px9("cell9_empty", 6), r)
				continue
			var e: Dictionary = entries[i]
			var inner := Rect2(r.position + Vector2(1, 1), r.size - Vector2(1, 1))
			if bool(e.get("mystery", false)):
				draw_style_box(K.px9("cell9_empty", 6), inner)
				var is_scanning := bool(e.get("scanning", false))
				var bg_c := Color(0.22, 0.16, 0.04, 0.35 + 0.25 * pulse) if is_scanning else Color(0.08, 0.085, 0.08, 0.65)
				draw_rect(inner.grow(-3), bg_c)
				# 扫描斜纹
				var y := inner.position.y + 4.0
				while y < inner.end.y - 4.0:
					draw_rect(Rect2(inner.position.x + 4, y, inner.size.x - 8, 1), Color(1, 0.8, 0.3, 0.12 if is_scanning else 0.05))
					y += 4.0
				var q_txt := Loc.t("扫描", "SCAN") if is_scanning else "???"
				var q_col := K.AMBER.lightened(0.25 * pulse) if is_scanning else K.CREAM_DIM
				var asc := font.get_ascent(12)
				draw_string(font, Vector2(inner.position.x, inner.position.y + inner.size.y * 0.5 + asc * 0.4), q_txt, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 12, q_col)
				if is_scanning:
					draw_rect(inner.grow(-1), K.AMBER.lightened(0.2), false, 1.0)
				continue
			var id := str(e.get("id", ""))
			var it := GameData.item(id)
			var rar := clampi(int(it.get("rar", 0)), 0, 3)
			draw_style_box(K.px9("cell9_r%d" % rar, 6), inner)
			var tex: Texture2D = Icons.icon(id)
			if tex:
				var isz := Vector2(32, 32)
				var ip := (inner.position + (inner.size - isz) * 0.5).floor()
				draw_texture_rect(tex, Rect2(ip, isz), false)
			var asc := font.get_ascent(12)
			# 右上角：任务 / 基建 / 模块标记
			var badge := ""
			var badge_c := K.AMBER
			if bool(e.get("quest", false)):
				badge = "★"
				badge_c = Color(1.0, 0.84, 0.22)
			elif bool(e.get("upgrade", false)):
				badge = "▲"
				badge_c = Color(0.38, 0.92, 0.78)
			elif bool(e.get("is_mod", false)):
				badge = "⚙"
				badge_c = Color(0.88, 0.68, 0.28)
			if badge != "":
				draw_string(font, Vector2(inner.position.x, inner.position.y + 3 + asc), badge, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x - 3, 12, Color(0, 0, 0, 0.9))
				draw_string(font, Vector2(inner.position.x - 1, inner.position.y + 2 + asc), badge, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x - 3, 12, badge_c)
			# 右下角：价值或重量
			var by := inner.end.y - 2 - font.get_descent(12)
			var val := int(it.get("v", it.get("val", 0)))
			var vt := "¥%d" % val if val < 1000 else ("¥%.1fk" % (val / 1000.0))
			var vc := Color(0.82, 0.68, 0.34) if rar < 2 else Color(0.98, 0.84, 0.42)
			draw_string(font, Vector2(inner.position.x + 3, by + 1), vt, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x - 5, 12, Color(0, 0, 0, 0.88))
			draw_string(font, Vector2(inner.position.x + 2, by), vt, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x - 5, 12, vc)
			var st := 2 if i == selected else (1 if i == hover else 0)
			if st == 2:
				draw_style_box(K.px9("cell9_sel", 8), inner)
			elif st == 1:
				draw_style_box(K.px9("cell9_hover", 8), inner)
		draw_rect(Rect2(_ox, 0, cols * cell, rows * cell), K.LINE, false, 1.0)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion:
			var h := index_at(ev.position)
			if h != hover:
				hover = h
				queue_redraw()
		elif ev is InputEventMouseButton and ev.pressed:
			var i := index_at(ev.position)
			if i < 0 or i >= entries.size():
				return
			if bool(entries[i].get("mystery", false)):
				return
			if ev.button_index == MOUSE_BUTTON_LEFT:
				selected = i
				queue_redraw()
				cell_selected.emit(i)
				if ev.double_click or ev.ctrl_pressed or ev.shift_pressed:
					cell_activated.emit(i, ev.ctrl_pressed or ev.shift_pressed)
			elif ev.button_index == MOUSE_BUTTON_RIGHT:
				selected = i
				queue_redraw()
				cell_selected.emit(i)
				cell_context.emit(i, ev.global_position)

	func _get_drag_data(at: Vector2) -> Variant:
		var i := index_at(at)
		if i < 0 or i >= entries.size() or bool(entries[i].get("mystery", false)):
			return null
		var e: Dictionary = entries[i]
		var id := str(e.get("id", ""))
		var pv := TextureRect.new()
		pv.texture = Icons.icon(id)
		pv.custom_minimum_size = Vector2(36, 36)
		pv.size = Vector2(36, 36)
		pv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pv.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		set_drag_preview(pv)
		return {"kind": grid_kind, "id": id, "real_idx": int(e.get("real_idx", i))}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		if typeof(data) != TYPE_DICTIONARY:
			return false
		var k := str(data.get("kind", ""))
		if grid_kind == "cargo" and k == "box":
			return true
		if grid_kind == "box" and k == "cargo":
			return inv.raid.open_box != null
		return false

	func _drop_data(_at: Vector2, data: Variant) -> void:
		var k := str(data.get("kind", ""))
		var ridx := int(data.get("real_idx", -1))
		if grid_kind == "cargo" and k == "box":
			inv.raid.take_from_box(ridx)
		elif grid_kind == "box" and k == "cargo":
			inv.raid.put_into_box(ridx)


## 机甲部位挂载槽卡片：支持点击检视、右键换装菜单、拖放模块直接战地换装
class SlotCard extends PanelContainer:
	var inv
	var slot_id := ""
	var icon_cell: K.IconCell
	var slot_badge: PanelContainer
	var name_lbl: Label
	var weight_lbl: Label
	var spec_lbl: Label
	var part_bar: K.PixBar
	var part_lbl: Label
	var status_lbl: Label
	var _selected := false
	var _hover := false

	func _init(owner_inv, s: String) -> void:
		inv = owner_inv
		slot_id = s
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(0, 68)
		_apply_style()

		var h := K.hbox(8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(h)

		icon_cell = K.IconCell.new(48)
		icon_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(icon_cell)

		var v := K.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(v)

		var r1 := K.hbox(6)
		r1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(r1)
		slot_badge = K.tag(str(GameData.SLOT_NAMES.get(slot_id, slot_id)), false)
		slot_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r1.add_child(slot_badge)
		name_lbl = UI.label("—", 12, K.CREAM)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.clip_text = true
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		r1.add_child(name_lbl)
		weight_lbl = UI.label("0.0t", 12, K.CREAM_DIM)
		r1.add_child(weight_lbl)

		spec_lbl = UI.label("", 12, K.CREAM_DIM)
		spec_lbl.clip_text = true
		spec_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(spec_lbl)

		var r3 := K.hbox(6)
		r3.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(r3)
		part_lbl = UI.label(Loc.t("完好 100%", "Intact 100%"), 12, K.OK_C)
		part_lbl.custom_minimum_size = Vector2(68, 0)
		r3.add_child(part_lbl)
		part_bar = K.PixBar.new(8)
		part_bar.custom_minimum_size = Vector2(72, 8)
		part_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r3.add_child(part_bar)
		status_lbl = UI.label(Loc.t("正常", "Nominal"), 12, K.CREAM_DIM)
		r3.add_child(status_lbl)

		mouse_entered.connect(func():
			_hover = true
			_apply_style())
		mouse_exited.connect(func():
			_hover = false
			_apply_style())

	func set_selected(on: bool) -> void:
		_selected = on
		icon_cell.hl = on
		icon_cell.queue_redraw()
		_apply_style()

	func _apply_style() -> void:
		add_theme_stylebox_override("panel", K.card_style(_selected or _hover, 6))

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			if ev.button_index == MOUSE_BUTTON_LEFT:
				inv.select_slot(slot_id)
			elif ev.button_index == MOUSE_BUTTON_RIGHT:
				inv.select_slot(slot_id)
				inv.open_slot_context(slot_id, ev.global_position)

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		if typeof(data) != TYPE_DICTIONARY:
			return false
		var id := str(data.get("id", ""))
		return GameData.slot_accepts(slot_id, id)

	func _drop_data(_at: Vector2, data: Variant) -> void:
		var k := str(data.get("kind", ""))
		var ridx := int(data.get("real_idx", -1))
		if k == "cargo":
			inv.raid.equip_from_cargo(ridx, slot_id)
		elif k == "box":
			inv.raid.equip_from_box(ridx, slot_id)


func _init(r, h) -> void:
	raid = r
	hud = h
	name = "RaidInv"
	theme = K.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 32
	visible = false
	_build_ui()


func _build_ui() -> void:
	# 全屏战术暗色背景幕布（阻断底层 HUD 浮标与鼠标穿透）
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.018, 0.016, 0.84)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	var root_frame := K.frame(10)
	root_frame.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	center.add_child(root_frame)

	var root_v := K.vbox(8)
	root_frame.add_child(root_v)

	# ==================== 1. 顶部战术遥测栏 ====================
	var top_bar := PanelContainer.new()
	top_bar.add_theme_stylebox_override("panel", K.px9("plate9", 14, 6, 10, 6))
	root_v.add_child(top_bar)

	var top_h := K.hbox(10)
	top_bar.add_child(top_h)

	pilot_av = K.Avatar.new(28, Growth.active_pilot(), "lead")
	top_h.add_child(pilot_av)

	var title_v := K.vbox(1)
	top_h.add_child(title_v)
	var title_r1 := K.hbox(6)
	title_v.add_child(title_r1)
	mode_tag = K.tag(Loc.t("战地整备", "Field Loadout"), true)
	mode_lbl = mode_tag.get_child(0) as Label
	title_r1.add_child(mode_tag)
	pilot_lbl = UI.label(Loc.t("战术终端", "Tactical Terminal"), 12, K.CREAM)
	title_r1.add_child(pilot_lbl)
	if Loc.is_en():
		title_v.add_child(UI.label("FIELD LOADOUT, DAMAGE CONTROL & SALVAGE TERMINAL", 12, K.CREAM_DIM))

	top_h.add_child(_vdiv())
	hp_lbl = _stat_chip(top_h, Loc.t("结构", "Hull"), "100/100", K.OK_C)
	en_lbl = _stat_chip(top_h, Loc.t("能源", "Energy"), "100/100", K.AMBER.lightened(0.2))
	load_lbl = _stat_chip(top_h, Loc.t("全重", "Mass"), "35.0t (×1.00)", K.CREAM)
	cargo_top_lbl = _stat_chip(top_h, Loc.t("货舱", "Cargo"), "0.0/20kg", K.CREAM)
	val_top_lbl = _stat_chip(top_h, Loc.t("本趟估值", "Haul Value"), "¥0", Color(0.95, 0.8, 0.35))

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_h.add_child(sp)

	var btn_close := K.button(Loc.t("× 关闭 [TAB/ESC]", "× Close [TAB/ESC]"), 28)
	btn_close.pressed.connect(func():
		Audio.play_sfx("ui_Click_Confirm")
		raid.close_box())
	top_h.add_child(btn_close)

	# ==================== 2. 三栏主体 ====================
	var cols_h := K.hbox(8)
	cols_h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_child(cols_h)

	_build_left_col(cols_h)
	_build_center_col(cols_h)
	_build_right_col(cols_h)

	# 右键上下文菜单
	ctx_menu = PopupMenu.new()
	ctx_menu.id_pressed.connect(_on_ctx_menu_pressed)
	add_child(ctx_menu)


func _vdiv() -> ColorRect:
	var c := ColorRect.new()
	c.color = K.LINE
	c.custom_minimum_size = Vector2(1, 24)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c


func _stat_chip(parent: Container, k: String, v: String, col: Color) -> Label:
	var vb := K.vbox(0)
	vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(vb)
	vb.add_child(UI.label(k, 12, K.CREAM_DIM))
	var vl := UI.label(v, 12, col)
	vb.add_child(vl)
	return vl


# ==================== 左栏：机体挂载与部位损管 ====================
func _build_left_col(parent: Container) -> void:
	var tp := K.tpanel(Loc.t("机体挂载与损管", "Mech & Damage Control"), "MECH & PARTS", Loc.t("6 槽位", "6 Slots"), 6)
	var p: PanelContainer = tp[0]
	var body: VBoxContainer = tp[1]
	p.custom_minimum_size = Vector2(354, 0)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(p)

	var slots_v := K.vbox(4)
	slots_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(slots_v)

	for s in GameData.SLOTS:
		var card := SlotCard.new(self, s)
		slot_cards[s] = card
		slots_v.add_child(card)

	# 底部损管与战地整备栏
	var dmg_box := K.card(false, 6)
	body.add_child(dmg_box)
	var dv := K.vbox(4)
	dmg_box.add_child(dv)

	mech_summary_lbl = UI.label("", 12, K.CREAM)
	dv.add_child(mech_summary_lbl)

	var btn_r := K.hbox(6)
	dv.add_child(btn_r)
	btn_quick_fuel = K.button(Loc.t("⚡ 注入燃料 [1]", "⚡ Fuel Cell [1]"), 26)
	btn_quick_fuel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_quick_fuel.pressed.connect(func():
		raid.mech.use_consumable("fuel_cell")
		refresh())
	btn_r.add_child(btn_quick_fuel)

	btn_quick_repair = K.button(Loc.t("🔧 战地抢修 [2]", "🔧 Field Repair [2]"), 26)
	btn_quick_repair.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_quick_repair.pressed.connect(func():
		raid.mech.use_consumable("repair_kit")
		refresh())
	btn_r.add_child(btn_quick_repair)


# ==================== 中栏：货舱网格与战术胸挂 ====================
func _build_center_col(parent: Container) -> void:
	var tp := K.tpanel(Loc.t("战术货舱与胸挂", "Cargo Bay & Tactical Rig"), "CARGO BAY & RIG", "", 6)
	var p: PanelContainer = tp[0]
	var body: VBoxContainer = tp[1]
	cargo_hdr_lbl = tp[2]
	p.custom_minimum_size = Vector2(404, 0)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(p)

	# 承重条 + 分类筛选 + 整理
	var top_c := K.vbox(4)
	body.add_child(top_c)

	cargo_bar = K.PixBar.new(8)
	cargo_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_c.add_child(cargo_bar)

	var flt_h := K.hbox(4)
	top_c.add_child(flt_h)
	var cats := [["all", Loc.t("全部", "All")], ["module", Loc.t("模块", "Modules")], ["consumable", Loc.t("消耗品", "Consumables")], ["loot", Loc.t("物资", "Salvage")]]
	for pair in cats:
		var cid: String = pair[0]
		var cname: String = pair[1]
		var b := K.button(cname, 24)
		b.toggle_mode = true
		b.button_pressed = (cid == cat_filter)
		b.pressed.connect(func():
			cat_filter = cid
			for k in filter_btns:
				filter_btns[k].button_pressed = (k == cat_filter)
			refresh())
		filter_btns[cid] = b
		flt_h.add_child(b)

	var fsp := Control.new()
	fsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flt_h.add_child(fsp)

	var btn_sort := K.button(Loc.t("⇅ 整理", "⇅ Sort"), 24)
	btn_sort.pressed.connect(func(): raid.sort_cargo())
	flt_h.add_child(btn_sort)

	# 塔科夫正方格货舱（7列 × 5行起，放入 ScrollContainer）
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)

	cargo_grid = RaidGrid.new(self, "cargo", 52, 7, 6)
	cargo_grid.cell_selected.connect(_on_cargo_selected)
	cargo_grid.cell_activated.connect(_on_cargo_activated)
	cargo_grid.cell_context.connect(_on_cargo_context)
	sc.add_child(cargo_grid)

	var hint_lbl := UI.label(Loc.t("双击/Ctrl+点击快速转移或换装 · 右键菜单 · ★委托急需 ▲基建材料", "Double/Ctrl+Click: Transfer/Equip · Right-Click: Menu · ★Quest ▲Facility"), 12, K.CREAM_DIM)
	hint_lbl.clip_text = true
	body.add_child(hint_lbl)

	# 底部：1~8 + T 战术胸挂快捷栏
	var rig_sec := K.section(Loc.t("战术胸挂快捷栏", "Tactical Rig"), "TACTICAL RIG [1-8 / T]", Loc.t("点击即用", "Quick Use"))
	body.add_child(rig_sec[0])

	var rig_h := K.hbox(4)
	rig_h.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(rig_h)
	rig_cells.clear()
	for rinfo in RIG_ITEMS:
		var rc := _build_rig_slot(rinfo)
		rig_h.add_child(rc)
		rig_cells.append(rc)


func _build_rig_slot(rinfo: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(40, 50)
	p.add_theme_stylebox_override("panel", K.px9("inset9", 6, 6, 2, 2))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var v := K.vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)

	var top_r := K.hbox(2)
	top_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top_r)
	var kl := UI.label("[%s]" % str(rinfo.key), 12, K.AMBER)
	top_r.add_child(kl)
	var cl := UI.label("×0", 12, K.CREAM_DIM)
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_r.add_child(cl)

	var ic := K.icon_rect(Icons.icon(str(rinfo.id)), 24)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)

	var nl := UI.label(Loc.t(str(rinfo.name), str(rinfo.en)), 12, K.CREAM_DIM)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nl)

	p.set_meta("id", str(rinfo.id))
	p.set_meta("key", str(rinfo.key))
	p.set_meta("cnt_lbl", cl)
	p.set_meta("name_lbl", nl)
	p.set_meta("icon_rect", ic)

	p.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			var iid := str(rinfo.id)
			select_rig_item(iid)
			if ev.button_index == MOUSE_BUTTON_LEFT and (ev.double_click or ev.ctrl_pressed):
				_activate_rig_item(iid)
			elif ev.button_index == MOUSE_BUTTON_RIGHT:
				_activate_rig_item(iid)
	)
	return p


func _activate_rig_item(iid: String) -> void:
	if iid == "beacon":
		if raid.has_method("call_transport"):
			raid.call_transport()
			refresh()
	else:
		raid.mech.use_consumable(iid)
		refresh()


# ==================== 右栏：容器搜刮/战地备忘 + 战术检视对比 ====================
func _build_right_col(parent: Container) -> void:
	var right_v := K.vbox(8)
	right_v.custom_minimum_size = Vector2(376, 0)
	right_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(right_v)

	# --- 上半：容器搜刮 / 战地情报 ---
	var tp_top := K.tpanel(Loc.t("容器搜刮", "Container"), "CONTAINER", "", 6)
	var p_top: PanelContainer = tp_top[0]
	var body_top: VBoxContainer = tp_top[1]
	right_top_title = p_top.get_meta("title_lbl") as Label
	right_top_en = p_top.get_meta("en_lbl") as Label
	right_top_sub = tp_top[2]
	p_top.custom_minimum_size = Vector2(0, 236)
	right_v.add_child(p_top)

	# 1) 容器视图
	box_view = K.vbox(4)
	box_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_top.add_child(box_view)

	var box_bar := K.hbox(6)
	box_view.add_child(box_bar)
	scan_box = K.vbox(2)
	scan_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_bar.add_child(scan_box)
	scan_lbl = UI.label(Loc.t("正在扫描容器特征...", "Scanning container..."), 12, K.AMBER)
	scan_box.add_child(scan_lbl)
	scan_bar = K.PixBar.new(8)
	scan_bar.color = K.AMBER
	scan_box.add_child(scan_bar)

	btn_take_all = K.primary(Loc.t("📥 全部拿取 [%s]", "📥 Take All [%s]") % Loc.space_key(), 28)
	btn_take_all.pressed.connect(func():
		raid.take_all_from_box())
	box_bar.add_child(btn_take_all)

	var box_sc := ScrollContainer.new()
	box_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box_view.add_child(box_sc)

	box_grid = RaidGrid.new(self, "box", 52, 6, 3)
	box_grid.cell_selected.connect(_on_box_selected)
	box_grid.cell_activated.connect(_on_box_activated)
	box_grid.cell_context.connect(_on_box_context)
	box_sc.add_child(box_grid)

	# 2) 无容器时的战地急需物资备忘视图
	intel_view = K.vbox(4)
	intel_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_top.add_child(intel_view)

	btn_open_near = K.primary(Loc.t("📦 打开附近容器 [G]", "📦 Open Nearby Crate [G]"), 28)
	btn_open_near.visible = false
	btn_open_near.pressed.connect(func():
		var nb = raid.nearest_box(3.6)
		if nb:
			raid.open_container(nb))
	intel_view.add_child(btn_open_near)

	var intel_sc := ScrollContainer.new()
	intel_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	intel_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	intel_view.add_child(intel_sc)

	intel_list = K.vbox(4)
	intel_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intel_sc.add_child(intel_list)

	# --- 下半：战术检视与模块对比 ---
	var tp_bot := K.tpanel(Loc.t("战术检视与属性对比", "Tactical Inspector"), "TACTICAL INSPECTOR", "", 6)
	var p_bot: PanelContainer = tp_bot[0]
	var body_bot: VBoxContainer = tp_bot[1]
	p_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_v.add_child(p_bot)

	var ih := K.hbox(8)
	body_bot.add_child(ih)
	insp_icon = K.IconCell.new(48)
	ih.add_child(insp_icon)

	var iv := K.vbox(2)
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ih.add_child(iv)
	insp_name = UI.label(Loc.t("选择任意模块或物资检视", "Select any module or item to inspect"), 12, K.CREAM)
	iv.add_child(insp_name)
	insp_tags = UI.label("—", 12, K.CREAM_DIM)
	iv.add_child(insp_tags)
	insp_meta = UI.label("—", 12, K.AMBER)
	iv.add_child(insp_meta)

	insp_quest_lbl = UI.label("", 12, Color(1.0, 0.85, 0.25))
	insp_quest_lbl.visible = false
	body_bot.add_child(insp_quest_lbl)

	var insp_sc := ScrollContainer.new()
	insp_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	insp_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_bot.add_child(insp_sc)

	var insp_body := K.vbox(4)
	insp_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insp_sc.add_child(insp_body)

	insp_desc = K.wrap("", K.CREAM_DIM)
	insp_body.add_child(insp_desc)

	insp_cmp_box = K.vbox(2)
	insp_body.add_child(insp_cmp_box)

	insp_actions = K.hbox(6)
	body_bot.add_child(insp_actions)


# ==================== 逐帧扫描进度条更新 ====================
func _process(_delta: float) -> void:
	if not visible or raid == null:
		return
	var b = raid.open_box
	if b != null and is_instance_valid(b):
		var total: int = b.items.size()
		var rev: int = int(b.revealed)
		if rev < total:
			scan_box.visible = true
			var frac := clampf(( float(rev) + clampf(float(b.reveal_t) / 0.55, 0.0, 1.0) ) / float(maxi(total, 1)), 0.0, 1.0)
			scan_bar.set_frac(frac)
			scan_lbl.text = Loc.t("正在扫描容器特征... (%d/%d)", "Scanning container... (%d/%d)") % [rev, total]
			box_grid.queue_redraw()
		else:
			scan_box.visible = false
			scan_bar.set_frac(1.0)
			scan_lbl.text = Loc.t("扫描完成 (%d/%d)", "Scan complete (%d/%d)") % [total, total]


func _unhandled_input(ev: InputEvent) -> void:
	if not visible or raid == null:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_SPACE and raid.open_box != null:
			raid.take_all_from_box()
			get_viewport().set_input_as_handled()


# ==================== 需求分析（任务★ / 基建▲） ====================
func _rebuild_need_map() -> void:
	_need_map.clear()
	# 1. 已接取的商人递交委托
	for qid in GameData.accepted_ids():
		var base := GameData.base_id(str(qid))
		_need_map[base] = {"quest": true, "upgrade": ""}
	# 2. 飞空艇下一级设施升级材料
	for fid in Growth.facility_ids():
		var cost := Growth.facility_cost(str(fid))
		var items: Dictionary = cost.get("items", {})
		for iid in items:
			var need_cnt := int(items[iid])
			var have_cnt: int = GameData.stash.count(str(iid)) + (int(raid.mech.cargo.count(str(iid))) if raid and raid.mech else 0)
			if have_cnt < need_cnt:
				var rec: Dictionary = _need_map.get(str(iid), {"quest": false, "upgrade": ""})
				if str(rec.get("upgrade", "")) == "":
					rec["upgrade"] = "%s %s (%d/%d)" % [Growth.facility_name(str(fid)), Loc.lv(Growth.facility_level(str(fid)) + 1), have_cnt, need_cnt]
				_need_map[str(iid)] = rec


# ==================== 刷新主入口 ====================
func refresh() -> void:
	if raid == null or raid.mech == null:
		return
	_rebuild_need_map()
	var m = raid.mech
	var b = raid.open_box

	# 1. 顶部遥测栏
	var is_looting := (b != null and is_instance_valid(b))
	mode_lbl.text = Loc.t("容器搜刮", "Container Loot") if is_looting else Loc.t("战地整备", "Field Loadout")
	var p_id := Growth.active_pilot()
	var p_nm := str(Growth.pilot_data(p_id).get("name", Growth.player_name()))
	pilot_av.set_char(p_id, 28)
	pilot_lbl.text = "%s · %s" % [p_nm, Loc.lv(Growth.pilot_level(p_id))]

	var hp_ratio: float = float(m.hp) / maxf(1.0, float(m.max_hp))
	hp_lbl.text = "%.0f / %.0f" % [m.hp, m.max_hp]
	hp_lbl.add_theme_color_override("font_color", K.OK_C if hp_ratio > 0.6 else (K.AMBER if hp_ratio > 0.3 else K.NG_C))

	var en_ratio: float = float(m.energy) / maxf(1.0, float(m.max_energy))
	en_lbl.text = "%.0f / %.0f" % [m.energy, m.max_energy]
	en_lbl.add_theme_color_override("font_color", K.AMBER.lightened(0.25) if en_ratio > 0.3 else K.NG_C)

	var tw: float = float(m.stats.get("mass", 0.0)) + m.cargo_weight()
	var w_mult: float = m.speed_mult()
	load_lbl.text = "%.1ft (×%.2f)" % [tw, w_mult]
	load_lbl.add_theme_color_override("font_color", K.CREAM if w_mult >= 0.92 else (K.AMBER if w_mult >= 0.78 else K.NG_C))

	var cw: float = m.cargo_weight()
	var cc: float = m.cargo_cap()
	cargo_top_lbl.text = "%.1f / %.0f kg" % [cw, cc]
	cargo_top_lbl.add_theme_color_override("font_color", K.NG_C if cw > cc else (K.AMBER if cw > cc * 0.8 else K.CREAM))

	var total_val := GameData.value_of(m.cargo)
	val_top_lbl.text = "¥%s" % K._money_text(total_val)

	# 2. 左栏：6 个机甲槽位卡片与损管
	var broken_cnt := 0
	var max_pen_cls := 1
	for s in GameData.SLOTS:
		var card: SlotCard = slot_cards[s]
		var mid := str(m.loadout.get(s, ""))
		var mit := GameData.item(mid)
		if (s == "arm_l" or s == "arm_r") and mid != "":
			max_pen_cls = maxi(max_pen_cls, GameData.pen_class(float(mit.get("pen", 22.0))))
		card.icon_cell.set_entry({"id": mid} if mid != "" else {})
		card.name_lbl.text = str(mit.get("name", Loc.t("未装配", "Empty")))
		var rar := clampi(int(mit.get("rar", 0)), 0, 3)
		card.name_lbl.add_theme_color_override("font_color", GameData.RARITY_COLORS[rar])
		card.weight_lbl.text = "%.1ft" % float(mit.get("w", 0.0))
		card.spec_lbl.text = _format_slot_spec(s, mid, mit)

		var integrity: float = clampf(float(m.parts.get(s, 1.0)), 0.0, 1.0)
		card.part_bar.set_frac(integrity)
		var pct := int(round(integrity * 100.0))
		if integrity < 0.5:
			broken_cnt += 1
			card.part_bar.color = K.NG_C
			card.part_lbl.text = Loc.t("重创 %d%%", "Crit %d%%") % pct
			card.part_lbl.add_theme_color_override("font_color", K.NG_C)
			card.status_lbl.text = _part_penalty(s)
			card.status_lbl.add_theme_color_override("font_color", K.NG_C)
		elif integrity < 0.85:
			card.part_bar.color = K.AMBER
			card.part_lbl.text = Loc.t("受损 %d%%", "Dmg %d%%") % pct
			card.part_lbl.add_theme_color_override("font_color", K.AMBER)
			card.status_lbl.text = Loc.t("建议检修", "Needs Repair")
			card.status_lbl.add_theme_color_override("font_color", K.AMBER)
		else:
			card.part_bar.color = K.OK_C
			card.part_lbl.text = Loc.t("完好 %d%%", "Intact %d%%") % pct
			card.part_lbl.add_theme_color_override("font_color", K.OK_C)
			card.status_lbl.text = Loc.t("工况正常", "Nominal")
			card.status_lbl.add_theme_color_override("font_color", K.CREAM_DIM)
		card.set_selected(sel_source == "slot" and sel_slot == s)

	var vr := float(m.stats.get("view_range", GameData.STD_RANGE))
	var recon_s := Loc.t(" [侦察+%.0f]", " [Recon +%.0f]") % float(m.stats.get("recon", 0.0)) if bool(m.stats.get("recon_tag", false)) else ""
	mech_summary_lbl.text = Loc.t("装甲 %s · 穿深 %s · 视距 %.0f%s · 工效 %.0f · 重创 %d", "Armor %s · Pen C%d · View %.0f%s · Ergo %.0f · Crit %d") % [
		Loc.armor_tier(int(m.stats.get("armor_class", 2))) if not Loc.is_en() else ("C%d" % int(m.stats.get("armor_class", 2))),
		(Loc.armor_tier(max_pen_cls) if not Loc.is_en() else max_pen_cls),
		vr,
		recon_s,
		float(m.stats.get("ergo", 50.0)),
		broken_cnt
	]
	var fuel_cnt: int = m.cargo.count("fuel_cell")
	var rep_cnt: int = m.cargo.count("repair_kit")
	btn_quick_fuel.text = Loc.t("⚡ 注入燃料 [1] ×%d", "⚡ Fuel Cell [1] ×%d") % fuel_cnt
	btn_quick_fuel.disabled = fuel_cnt <= 0 or m.energy >= m.max_energy - 0.5
	btn_quick_repair.text = Loc.t("🔧 战地抢修 [2] ×%d", "🔧 Field Repair [2] ×%d") % rep_cnt
	btn_quick_repair.disabled = rep_cnt <= 0 or not m.can_use_item("repair_kit")

	# 3. 中栏：货舱网格与战术胸挂
	var c_frac := clampf(cw / maxf(1.0, cc), 0.0, 1.0)
	cargo_bar.set_frac(c_frac)
	cargo_bar.color = K.NG_C if cw > cc else (K.AMBER if c_frac > 0.78 else K.OK_C)
	cargo_hdr_lbl.text = Loc.t("%.1f / %.0f kg (%d件)", "%.1f / %.0f kg (%d items)") % [cw, cc, m.cargo.size()]

	var c_entries: Array = []
	for i in m.cargo.size():
		var cid: String = m.cargo[i]
		var cit := GameData.item(cid)
		var cat := str(cit.get("cat", "misc"))
		if not _match_cat_filter(cat):
			continue
		var need: Dictionary = _need_map.get(GameData.base_id(cid), {})
		c_entries.append({
			"id": cid,
			"real_idx": i,
			"mystery": false,
			"quest": bool(need.get("quest", false)),
			"upgrade": str(need.get("upgrade", "")) != "",
			"is_mod": cat == "module",
		})
	cargo_grid.set_entries(c_entries)
	if sel_source == "cargo":
		var found_g := -1
		for gi in c_entries.size():
			if int(c_entries[gi].real_idx) == sel_index:
				found_g = gi
				break
		cargo_grid.selected = found_g
	else:
		cargo_grid.selected = -1
	cargo_grid.queue_redraw()

	# 刷新 1~8 + T 胸挂格
	for rc in rig_cells:
		var rid := str(rc.get_meta("id"))
		var rcnt: int = m.cargo.count(rid)
		var cl: Label = rc.get_meta("cnt_lbl")
		var nl: Label = rc.get_meta("name_lbl")
		var ic: TextureRect = rc.get_meta("icon_rect")
		cl.text = "×%d" % rcnt
		cl.add_theme_color_override("font_color", K.OK_C if rcnt > 0 else K.CREAM_DIM)
		nl.add_theme_color_override("font_color", K.CREAM if rcnt > 0 else K.CREAM_DIM)
		ic.modulate = Color(1, 1, 1, 1.0 if rcnt > 0 else 0.35)
		var is_sel := (sel_source == "rig" and sel_id == rid)
		rc.add_theme_stylebox_override("panel", K.px9("card9_on" if is_sel else "inset9", 6, 6, 2, 2))

	# 4. 右栏上半：容器搜刮 or 战地备忘
	if is_looting:
		right_top_title.text = str(b.title)
		right_top_en.text = "CONTAINER LOOT"
		right_top_en.visible = Loc.is_en()
		right_top_sub.text = Loc.t("已判明 %d / %d", "Scanned %d / %d") % [int(b.revealed), b.items.size()]
		box_view.visible = true
		intel_view.visible = false
		btn_take_all.disabled = int(b.revealed) <= 0
		var b_entries: Array = []
		for i in b.items.size():
			var bid: String = b.items[i]
			var is_mys: bool = (i >= int(b.revealed))
			var need: Dictionary = _need_map.get(GameData.base_id(bid), {})
			var bit := GameData.item(bid)
			b_entries.append({
				"id": bid,
				"real_idx": i,
				"mystery": is_mys,
				"scanning": (i == int(b.revealed)),
				"quest": not is_mys and bool(need.get("quest", false)),
				"upgrade": not is_mys and str(need.get("upgrade", "")) != "",
				"is_mod": not is_mys and str(bit.get("cat", "")) == "module",
			})
		box_grid.set_entries(b_entries)
		box_grid.selected = sel_index if sel_source == "box" else -1
		box_grid.queue_redraw()
	else:
		right_top_title.text = Loc.t("战地急需物资备忘", "Field Intel & Needs")
		right_top_en.text = "FIELD INTEL & NEEDS"
		right_top_en.visible = Loc.is_en()
		right_top_sub.text = Loc.t("★委托 / ▲基建", "★Quest / ▲Facility")
		box_view.visible = false
		intel_view.visible = true
		var nb = raid.nearest_box(3.6)
		if nb != null and is_instance_valid(nb):
			btn_open_near.visible = true
			btn_open_near.text = Loc.t("📦 打开附近容器：%s [G]", "📦 Open Crate: %s [G]") % str(nb.title)
		else:
			btn_open_near.visible = false
		_refresh_intel_list()

	# 5. 右栏下半：默认选中一个有意义的条目并刷新检视面板
	_ensure_valid_selection()
	_refresh_inspector()


func _match_cat_filter(cat: String) -> bool:
	if cat_filter == "all":
		return true
	if cat_filter == "module":
		return cat == "module"
	if cat_filter == "consumable":
		return cat == "use" or cat == "food"
	return cat != "module" and cat != "use" and cat != "food"


func _is_consumable(cat: String) -> bool:
	return cat == "use" or cat == "food"


func _format_slot_spec(slot: String, mid: String, mit: Dictionary) -> String:
	if mid == "" or mit.is_empty():
		return Loc.t("未安装模块", "No Module Mounted")
	match slot:
		"core":
			var r_txt := Loc.t(" · [侦察]+%.0f", " · [Recon]+%.0f") % float(mit.get("recon", 0.0)) if GameData.has_recon_tag(mit) else ""
			return Loc.t("装甲 %s · 耐久 +%d · 工效 %d%s", "Armor C%d · Hull +%d · Ergo %d%s") % [
				(Loc.armor_tier(int(mit.get("armor_class", 2))) if not Loc.is_en() else int(mit.get("armor_class", 2))),
				int(mit.get("hp", 0)),
				int(mit.get("ergo", 60)),
				r_txt
			]
		"legs":
			var sk_info := GameData.module_skill_info(mid)
			var sk_nm := str(sk_info.get("name", Loc.t("机动", "Mobility")))
			return Loc.t("装甲 %s · 航速 %.1f · 承重 %.0ft · [%s]", "Armor C%d · Speed %.1f · Load %.0ft · [%s]") % [
				(Loc.armor_tier(int(mit.get("armor_class", 2))) if not Loc.is_en() else int(mit.get("armor_class", 2))),
				float(mit.get("speed", 7.0)),
				float(mit.get("load", 20.0)),
				sk_nm
			]
		"arm_l", "arm_r":
			var wtype := str(mit.get("weapon", "mg"))
			var mag_cap := int(GameData.AMMO.get(wtype, {}).get("mag", 0))
			var cur_ammo: int = int(raid.mech.ammo.get(slot, mag_cap)) if raid and raid.mech else mag_cap
			var pel := int(mit.get("pellets", 1))
			var dmg_txt := "%d×%d" % [int(mit.get("dmg", 0)), pel] if pel > 1 else str(int(mit.get("dmg", 0)))
			var pen_cls := GameData.pen_class(float(mit.get("pen", 22.0)))
			var rng_v := int(round(float(mit.get("range", GameData.STD_RANGE))))
			return Loc.t("穿深 %s · 射程 %d · 伤 %s · 弹 %d/%d", "Pen C%d · Rng %d · Dmg %s · %d/%d") % [
				(Loc.armor_tier(pen_cls) if not Loc.is_en() else pen_cls),
				rng_v,
				dmg_txt,
				cur_ammo,
				mag_cap
			]
		"back":
			var bsk_info := GameData.module_skill_info(mid)
			var bnm := str(bsk_info.get("name", Loc.t("无主动机能", "No Active System")))
			return Loc.t("货舱 +%dkg · [%s]", "Cargo +%dkg · [%s]") % [int(mit.get("cargo", 0)), bnm]
		"gen":
			return Loc.t("能源上限 +%d · 耗能倍率 ×%.2f", "Energy +%d · Drain ×%.2f") % [int(mit.get("energy", 0)), float(mit.get("eff", 1.0))]
	return str(mit.get("desc", ""))


func _refresh_intel_list() -> void:
	for c in intel_list.get_children():
		c.queue_free()
	var any_row := false
	# 1. 已接取商人委托
	for m in GameData.QUEST_CHAINS:
		var chain: Array = GameData.QUEST_CHAINS[m]
		for i in chain.size():
			if GameData.quest_status(m, i) != 1:
				continue
			var q := GameData.quest_entry(m, i)
			if GameData.quest_type(q) == "item":
				any_row = true
				var qid := str(q.get("id", ""))
				var qneed := int(q.get("count", 1))
				var qhave: int = GameData.stash.count(qid) + int(raid.mech.cargo.count(qid))
				intel_list.add_child(K.req_row(Loc.t("★ 委托 [%s] %s", "★ Contract [%s] %s") % [str(GameData.QUEST_NAMES.get(m, m)), GameData.item_name(qid)], "%d/%d" % [qhave, qneed], qhave >= qneed))
	# 2. 飞空艇基建下一级材料
	for fid in Growth.facility_ids():
		var cost := Growth.facility_cost(str(fid))
		var items: Dictionary = cost.get("items", {})
		for iid in items:
			var need_cnt := int(items[iid])
			var have_cnt: int = GameData.stash.count(str(iid)) + int(raid.mech.cargo.count(str(iid)))
			if have_cnt < need_cnt:
				any_row = true
				intel_list.add_child(K.req_row(Loc.t("▲ %s %s 需 %s", "▲ %s %s needs %s") % [Growth.facility_name(str(fid)), Loc.lv(Growth.facility_level(str(fid)) + 1), GameData.item_name(str(iid))], "%d/%d" % [have_cnt, need_cnt], false))
	if not any_row:
		intel_list.add_child(UI.label(Loc.t("当前无急需委托或基建缺口材料，可优先搜刮高价值密度（¥/kg）物资。", "No urgent contract or facility shortages — prioritize high value-density (¥/kg) loot."), 12, K.CREAM_DIM))


# ==================== 选择与检视面板 ====================
func _ensure_valid_selection() -> void:
	var m = raid.mech
	var b = raid.open_box
	if sel_source == "box":
		if b == null or not is_instance_valid(b) or sel_index < 0 or sel_index >= int(b.revealed) or sel_index >= b.items.size():
			sel_source = ""
		else:
			sel_id = str(b.items[sel_index])
	elif sel_source == "cargo":
		if sel_index < 0 or sel_index >= m.cargo.size():
			sel_source = ""
		else:
			sel_id = str(m.cargo[sel_index])
	elif sel_source == "slot":
		sel_id = str(m.loadout.get(sel_slot, ""))
	elif sel_source == "rig":
		if sel_id == "":
			sel_source = ""

	if sel_source == "":
		if b != null and is_instance_valid(b) and int(b.revealed) > 0 and not b.items.is_empty():
			sel_source = "box"
			sel_index = 0
			sel_id = str(b.items[0])
		elif not m.cargo.is_empty():
			sel_source = "cargo"
			sel_index = 0
			sel_id = str(m.cargo[0])
		else:
			sel_source = "slot"
			sel_slot = "core"
			sel_id = str(m.loadout.get("core", ""))


func select_slot(slot: String) -> void:
	sel_source = "slot"
	sel_slot = slot
	sel_index = -1
	sel_id = str(raid.mech.loadout.get(slot, ""))
	Audio.play_sfx("ui_Click_Confirm")
	refresh()


func select_rig_item(id: String) -> void:
	sel_source = "rig"
	sel_id = id
	sel_index = raid.mech.cargo.find(id)
	Audio.play_sfx("ui_Click_Confirm")
	refresh()


func _on_cargo_selected(grid_idx: int) -> void:
	if grid_idx < 0 or grid_idx >= cargo_grid.entries.size():
		return
	var e: Dictionary = cargo_grid.entries[grid_idx]
	sel_source = "cargo"
	sel_index = int(e.real_idx)
	sel_id = str(e.id)
	Audio.play_sfx("ui_Click_Confirm")
	refresh()


func _on_cargo_activated(grid_idx: int, _ctrl_held: bool) -> void:
	if grid_idx < 0 or grid_idx >= cargo_grid.entries.size():
		return
	var e: Dictionary = cargo_grid.entries[grid_idx]
	var ridx := int(e.real_idx)
	var id := str(e.id)
	var it := GameData.item(id)
	var cat := str(it.get("cat", "misc"))
	if raid.open_box != null:
		raid.put_into_box(ridx)
	elif cat == "module":
		raid.equip_from_cargo(ridx)
	elif _is_consumable(cat):
		raid.mech.use_item_at_cargo(ridx)


func _on_box_selected(grid_idx: int) -> void:
	if grid_idx < 0 or grid_idx >= box_grid.entries.size():
		return
	var e: Dictionary = box_grid.entries[grid_idx]
	if bool(e.get("mystery", false)):
		return
	sel_source = "box"
	sel_index = int(e.real_idx)
	sel_id = str(e.id)
	Audio.play_sfx("ui_Click_Confirm")
	refresh()


func _on_box_activated(grid_idx: int, _ctrl_held: bool) -> void:
	if grid_idx < 0 or grid_idx >= box_grid.entries.size():
		return
	var e: Dictionary = box_grid.entries[grid_idx]
	if bool(e.get("mystery", false)):
		return
	raid.take_from_box(int(e.real_idx))


func _refresh_inspector() -> void:
	for c in insp_cmp_box.get_children():
		c.queue_free()
	for c in insp_actions.get_children():
		c.queue_free()

	if sel_id == "":
		insp_icon.set_entry({})
		insp_name.text = Loc.t("未选择物品", "No Item Selected")
		insp_tags.text = "—"
		insp_meta.text = "—"
		insp_quest_lbl.visible = false
		insp_desc.text = Loc.t("点击左栏机甲部位、中栏货舱或右栏容器中的物品以查看详细战术参数与对比。", "Click any mech slot, cargo item, or container item to inspect stats and compare.")
		return

	var it := GameData.item(sel_id)
	var rar := clampi(int(it.get("rar", 0)), 0, 3)
	var cat := str(it.get("cat", "misc"))
	insp_icon.set_entry({"id": sel_id})
	insp_name.text = str(it.get("name", sel_id))
	insp_name.add_theme_color_override("font_color", GameData.RARITY_COLORS[rar])

	var cat_cn := str(GameData.CAT_NAMES.get(cat, Loc.t("物资", "Salvage")))
	if cat == "module":
		var m_slot := str(it.get("slot", ""))
		cat_cn += " · [%s]" % (Loc.t("双臂通用", "Dual-Arm") if m_slot == "arm" else str(GameData.SLOT_NAMES.get(m_slot, m_slot)))
		if GameData.has_recon_tag(it):
			cat_cn += " · [" + Loc.t("侦察", "Recon") + "]"
	var src_cn := str({
		"slot": Loc.t("当前已装备", "Equipped"),
		"cargo": Loc.t("位于货舱", "In Cargo"),
		"box": Loc.t("位于容器", "In Container"),
		"rig": Loc.t("战术胸挂", "Tactical Rig"),
	}.get(sel_source, ""))
	insp_tags.text = Loc.t("%s稀有度 · %s · %s", "%s · %s · %s") % [GameData.RARITY_NAMES[rar], cat_cn, src_cn]

	var w := float(it.get("w", 0.5))
	var val := int(it.get("v", it.get("val", 0)))
	var density := int(round(float(val) / maxf(0.1, w)))
	insp_meta.text = Loc.t("重量 %.1f %s  |  估值 ¥%s  |  价值密度 ¥%s/kg", "Weight %.1f %s  |  Value ¥%s  |  ¥%s/kg") % [
		w,
		"t" if cat == "module" else "kg",
		K._money_text(val),
		K._money_text(density)
	]

	var need: Dictionary = _need_map.get(GameData.base_id(sel_id), {})
	var need_parts: Array = []
	if bool(need.get("bounty", false)):
		need_parts.append(Loc.t("★ 本局悬赏急需", "★ Bounty Target"))
	elif bool(need.get("quest", false)):
		need_parts.append(Loc.t("★ 商人已接委托急需", "★ Active Contract"))
	if str(need.get("upgrade", "")) != "":
		need_parts.append(Loc.t("▲ 基建缺口：%s", "▲ Facility: %s") % str(need.get("upgrade", "")))
	if not need_parts.is_empty():
		insp_quest_lbl.visible = true
		insp_quest_lbl.text = " · ".join(need_parts)
	else:
		insp_quest_lbl.visible = false

	insp_desc.text = str(it.get("desc", ""))

	# 模块属性明细与对比
	if cat == "module":
		var slot := str(it.get("slot", ""))
		if sel_source == "slot":
			var integrity: float = clampf(float(raid.mech.parts.get(sel_slot, 1.0)), 0.0, 1.0)
			insp_cmp_box.add_child(K.kv(Loc.t("部位完好度", "Part Integrity"), "%d%% (%s)" % [int(round(integrity * 100.0)), Loc.t("正常", "Nominal") if integrity >= 0.5 else _part_penalty(sel_slot)], K.OK_C if integrity >= 0.5 else K.NG_C))
			_append_module_stats(insp_cmp_box, it, null)
		else:
			var target_slot := "arm_l" if slot == "arm" else slot
			if slot == "arm" and (sel_slot == "arm_l" or sel_slot == "arm_r"):
				target_slot = sel_slot
			var eq_id := str(raid.mech.loadout.get(target_slot, ""))
			var eq_it := GameData.item(eq_id) if eq_id != "" else {}
			var hdr := UI.label(Loc.t("▸ 与当前 [%s] (%s) 对比：", "▸ Compare with [%s] (%s):") % [str(GameData.SLOT_NAMES.get(target_slot, target_slot)), str(eq_it.get("name", Loc.t("无", "None")))], 12, K.AMBER)
			insp_cmp_box.add_child(hdr)
			_append_module_stats(insp_cmp_box, it, eq_it)

	# 底部快捷操作按钮
	_build_inspector_buttons(cat, it)


func _append_module_stats(box: VBoxContainer, it: Dictionary, cmp_it) -> void:
	var is_arm := (str(it.get("slot", "")) == "arm")
	var fields := [
		["armor_class", Loc.t("装甲等级", "Armor Class"), "Class %d" if Loc.is_en() else "%d级防护", false],
		["recon", Loc.t("侦察视距", "Recon View"), "+%d", false],
		["pen", Loc.t("穿甲深度", "Penetration"), "%.0fmm", false],
		["range", Loc.t("武器射程", "Weapon Range"), "%d", false],
		["dmg", Loc.t("单发伤害", "Damage"), "%d", false],
		["cd", Loc.t("射击间隔", "Fire Delay"), "%.2fs", true],
		["spread", Loc.t("基础散布", "Base Spread"), "%.2f", true],
		["hp", Loc.t("结构耐久", "Hull"), "+%d", false],
		["speed", Loc.t("弹头初速", "Muzzle Vel.") if is_arm else Loc.t("机动航速", "Cruise Speed"), "%.0fm/s" if is_arm else "%.1f", false],
		["load", Loc.t("底盘承重", "Chassis Load"), "%.0ft", false],
		["cargo", Loc.t("货舱扩容", "Cargo Cap"), "+%dkg", false],
		["energy", Loc.t("能源上限", "Energy Cap"), "+%d", false],
		["eff", Loc.t("耗能倍率", "Power Drain"), "×%.2f", true],
		["ergo", Loc.t("人机工效", "Ergonomics"), "%d", false],
		["w", Loc.t("模块全重", "Module Weight"), "%.1ft", true],
	]
	for f in fields:
		var key: String = f[0]
		if not it.has(key) and (cmp_it == null or not cmp_it.has(key)):
			continue
		if key == "recon" and float(it.get("recon", 0.0)) <= 0.0 and (cmp_it == null or float(cmp_it.get("recon", 0.0)) <= 0.0):
			continue
		var label_txt: String = f[1]
		var fmt: String = f[2]
		var lower_better: bool = f[3]
		var v_new := float(it.get(key, 0.0))
		var val_str := (fmt % int(v_new)) if fmt.find("d") >= 0 else (fmt % v_new)
		var col := K.CREAM
		if cmp_it != null and not cmp_it.is_empty():
			var v_old := float(cmp_it.get(key, 0.0))
			var diff := v_new - v_old
			if absf(diff) > 0.005:
				var sign_s := "+" if diff > 0 else ""
				var d_str := ("%s%d" % [sign_s, int(round(diff))]) if fmt.find("d") >= 0 else ("%s%.2f" % [sign_s, diff])
				val_str += " (%s)" % d_str
				var is_good := (diff < 0.0) if lower_better else (diff > 0.0)
				col = K.OK_C if is_good else K.NG_C
		box.add_child(K.kv(label_txt, val_str, col))


func _build_inspector_buttons(cat: String, it: Dictionary) -> void:
	if sel_source == "box":
		var b_take := K.primary(Loc.t("📥 拿取至货舱", "📥 Move to Cargo"), 26)
		b_take.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_take.pressed.connect(func(): raid.take_from_box(sel_index))
		insp_actions.add_child(b_take)
		if cat == "module":
			var m_slot := str(it.get("slot", ""))
			if m_slot == "arm":
				var b_el := K.button(Loc.t("⚙ 换左臂", "⚙ Left Arm"), 26)
				b_el.pressed.connect(func(): raid.equip_from_box(sel_index, "arm_l"))
				insp_actions.add_child(b_el)
				var b_er := K.button(Loc.t("⚙ 换右臂", "⚙ Right Arm"), 26)
				b_er.pressed.connect(func(): raid.equip_from_box(sel_index, "arm_r"))
				insp_actions.add_child(b_er)
			else:
				var b_eq := K.button(Loc.t("⚙ 直接换装", "⚙ Equip"), 26)
				b_eq.pressed.connect(func(): raid.equip_from_box(sel_index, m_slot))
				insp_actions.add_child(b_eq)
		elif _is_consumable(cat) and raid.mech.can_use_item(sel_id):
			var b_use := K.button(Loc.t("💊 直接使用", "💊 Use"), 26)
			b_use.pressed.connect(func(): raid.use_from_box(sel_index))
			insp_actions.add_child(b_use)
	elif sel_source == "cargo":
		if cat == "module":
			var m_slot := str(it.get("slot", ""))
			if m_slot == "arm":
				var b_el := K.primary(Loc.t("⚙ 换装左臂", "⚙ Equip Left Arm"), 26)
				b_el.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b_el.pressed.connect(func(): raid.equip_from_cargo(sel_index, "arm_l"))
				insp_actions.add_child(b_el)
				var b_er := K.button(Loc.t("⚙ 换装右臂", "⚙ Equip Right Arm"), 26)
				b_er.pressed.connect(func(): raid.equip_from_cargo(sel_index, "arm_r"))
				insp_actions.add_child(b_er)
			else:
				var b_eq := K.primary(Loc.t("⚙ 战地换装 [%s]", "⚙ Field Equip [%s]") % str(GameData.SLOT_NAMES.get(m_slot, m_slot)), 26)
				b_eq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b_eq.pressed.connect(func(): raid.equip_from_cargo(sel_index, m_slot))
				insp_actions.add_child(b_eq)
		elif _is_consumable(cat):
			var b_use := K.primary(Loc.t("💊 立即使用", "💊 Use Now"), 26)
			b_use.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b_use.disabled = not (raid.mech.can_use_item(sel_id) if sel_id != "beacon" else true)
			b_use.pressed.connect(func():
				if sel_id == "beacon":
					raid.call_transport()
					refresh()
				else:
					raid.mech.use_item_at_cargo(sel_index))
			insp_actions.add_child(b_use)
		if raid.open_box != null:
			var b_put := K.button(Loc.t("📤 移入容器", "📤 Put in Crate"), 26)
			b_put.pressed.connect(func(): raid.put_into_box(sel_index))
			insp_actions.add_child(b_put)
		var b_drop := K.button(Loc.t("🗑 丢弃", "🗑 Drop"), 26)
		b_drop.pressed.connect(func(): raid.discard_from_cargo(sel_index))
		insp_actions.add_child(b_drop)
	elif sel_source == "slot":
		# 列出货舱或容器中可替换同槽位模块的快捷按钮
		var compat := _find_compatible_modules(sel_slot)
		if not compat.is_empty():
			var first: Dictionary = compat[0]
			var eq_id := str(raid.mech.loadout.get(sel_slot, ""))
			var prefix := Loc.t("⚙ 更换完好备件：", "⚙ Swap Intact Spare: ") if str(first.id) == eq_id else Loc.t("⚙ 换装：", "⚙ Equip: ")
			var b_swap := K.primary(prefix + str(GameData.item(str(first.id)).name), 26)
			b_swap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b_swap.pressed.connect(func():
				if str(first.src) == "cargo":
					raid.equip_from_cargo(int(first.idx), sel_slot)
				else:
					raid.equip_from_box(int(first.idx), sel_slot))
			insp_actions.add_child(b_swap)
		else:
			insp_actions.add_child(UI.label(Loc.t("货舱/容器中暂无同槽位可替换模块", "No compatible replacement modules in cargo or crate"), 12, K.CREAM_DIM))
	elif sel_source == "rig":
		var cnt: int = raid.mech.cargo.count(sel_id)
		var b_use := K.primary(Loc.t("💊 使用 %s (×%d)", "💊 Use %s (×%d)") % [str(it.get("name", sel_id)), cnt], 26)
		b_use.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_use.disabled = cnt <= 0
		b_use.pressed.connect(func(): _activate_rig_item(sel_id))
		insp_actions.add_child(b_use)


func _find_compatible_modules(slot: String) -> Array:
	var out: Array = []
	var eq_id := str(raid.mech.loadout.get(slot, ""))
	var part_damaged := float(raid.mech.parts.get(slot, 1.0)) < 0.99
	for i in raid.mech.cargo.size():
		var cid: String = raid.mech.cargo[i]
		if GameData.slot_accepts(slot, cid) and (cid != eq_id or part_damaged):
			out.append({"src": "cargo", "idx": i, "id": cid})
	if raid.open_box != null and is_instance_valid(raid.open_box):
		for i in mini(int(raid.open_box.revealed), raid.open_box.items.size()):
			var bid: String = raid.open_box.items[i]
			if GameData.slot_accepts(slot, bid) and (bid != eq_id or part_damaged):
				out.append({"src": "box", "idx": i, "id": bid})
	return out


# ==================== 右键战术菜单 ====================
func _on_cargo_context(grid_idx: int, gpos: Vector2) -> void:
	if grid_idx < 0 or grid_idx >= cargo_grid.entries.size():
		return
	var e: Dictionary = cargo_grid.entries[grid_idx]
	var ridx := int(e.real_idx)
	var id := str(e.id)
	var it := GameData.item(id)
	var cat := str(it.get("cat", "misc"))
	_ctx_actions.clear()
	ctx_menu.clear()

	_add_ctx(Loc.t("🔍 检视物品详情", "🔍 Inspect Item"), func(): _on_cargo_selected(grid_idx))
	if cat == "module":
		var m_slot := str(it.get("slot", ""))
		if m_slot == "arm":
			_add_ctx(Loc.t("⚙ 战地换装至 [左臂武装]", "⚙ Equip to [Left Arm]"), func(): raid.equip_from_cargo(ridx, "arm_l"))
			_add_ctx(Loc.t("⚙ 战地换装至 [右臂武装]", "⚙ Equip to [Right Arm]"), func(): raid.equip_from_cargo(ridx, "arm_r"))
		else:
			_add_ctx(Loc.t("⚙ 战地换装至 [%s]", "⚙ Equip to [%s]") % str(GameData.SLOT_NAMES.get(m_slot, m_slot)), func(): raid.equip_from_cargo(ridx, m_slot))
	elif _is_consumable(cat):
		_add_ctx(Loc.t("💊 立即使用", "💊 Use Now"), func():
			if id == "beacon":
				raid.call_transport()
				refresh()
			else:
				raid.mech.use_item_at_cargo(ridx))
	if raid.open_box != null:
		_add_ctx(Loc.t("📤 移入当前容器 [Ctrl+点击]", "📤 Put in Crate [Ctrl+Click]"), func(): raid.put_into_box(ridx))
	_add_ctx(Loc.t("🗑 丢弃物资", "🗑 Drop Item"), func(): raid.discard_from_cargo(ridx))
	_popup_ctx(gpos)


func _on_box_context(grid_idx: int, gpos: Vector2) -> void:
	if grid_idx < 0 or grid_idx >= box_grid.entries.size():
		return
	var e: Dictionary = box_grid.entries[grid_idx]
	if bool(e.get("mystery", false)):
		return
	var ridx := int(e.real_idx)
	var id := str(e.id)
	var it := GameData.item(id)
	var cat := str(it.get("cat", "misc"))
	_ctx_actions.clear()
	ctx_menu.clear()

	_add_ctx(Loc.t("📥 拿取至货舱 [双击/Ctrl+点击]", "📥 Move to Cargo [Double/Ctrl+Click]"), func(): raid.take_from_box(ridx))
	if cat == "module":
		var m_slot := str(it.get("slot", ""))
		if m_slot == "arm":
			_add_ctx(Loc.t("⚙ 直接换装至 [左臂武装]", "⚙ Equip to [Left Arm]"), func(): raid.equip_from_box(ridx, "arm_l"))
			_add_ctx(Loc.t("⚙ 直接换装至 [右臂武装]", "⚙ Equip to [Right Arm]"), func(): raid.equip_from_box(ridx, "arm_r"))
		else:
			_add_ctx(Loc.t("⚙ 直接战地换装至 [%s]", "⚙ Equip to [%s]") % str(GameData.SLOT_NAMES.get(m_slot, m_slot)), func(): raid.equip_from_box(ridx, m_slot))
	elif _is_consumable(cat) and raid.mech.can_use_item(id):
		_add_ctx(Loc.t("💊 直接使用", "💊 Use"), func(): raid.use_from_box(ridx))
	_popup_ctx(gpos)


func open_slot_context(slot: String, gpos: Vector2) -> void:
	_ctx_actions.clear()
	ctx_menu.clear()
	_add_ctx(Loc.t("🔍 检视 [%s] 详情", "🔍 Inspect [%s]") % str(GameData.SLOT_NAMES.get(slot, slot)), func(): select_slot(slot))
	var compat := _find_compatible_modules(slot)
	for c in compat:
		var nm := str(GameData.item(str(c.id)).name)
		var tag_s := Loc.t("货舱", "Cargo") if str(c.src) == "cargo" else Loc.t("容器", "Crate")
		_add_ctx(Loc.t("⚙ 换装 (%s)：%s", "⚙ Equip (%s): %s") % [tag_s, nm], func():
			if str(c.src) == "cargo":
				raid.equip_from_cargo(int(c.idx), slot)
			else:
				raid.equip_from_box(int(c.idx), slot))
	_popup_ctx(gpos)


func _add_ctx(label: String, fn: Callable) -> void:
	var idx := _ctx_actions.size()
	_ctx_actions.append(fn)
	ctx_menu.add_item(label, idx)


func _popup_ctx(gpos: Vector2) -> void:
	if _ctx_actions.is_empty():
		return
	ctx_menu.position = Vector2i(int(gpos.x), int(gpos.y))
	ctx_menu.popup()


func _on_ctx_menu_pressed(id: int) -> void:
	if id >= 0 and id < _ctx_actions.size():
		_ctx_actions[id].call()
