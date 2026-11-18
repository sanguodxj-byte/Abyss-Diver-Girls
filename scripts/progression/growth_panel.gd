extends Control
## 局外成长面板：独立控件，机库界面工程师把它加为子节点并调 open() 即可，不需要改本文件。
## 接口：open() / close() / toggle() / refresh()；关闭时广播 closed。Esc 与右上角「关闭」都能退出，
## 隐藏时 visible = false，不接收任何输入；面板根节点与背景层 mouse_filter = IGNORE，只有中央面板本身拦截点击。
## 数据与结算全部走 scripts\progression\growth.gd，这里只负责显示与按钮。

signal closed

const UI = preload("res://scripts/ui.gd")
const Growth = preload("res://scripts/progression/growth.gd")

const TABS := [["facilities", "设施"], ["research", "研究"], ["pilots", "驾驶员"], ["crew", "船员"], ["voyage", "航程"]]
## 面板顶部材料栏里列出的打捞材料
const MATERIALS := ["bug_crystal", "chitin", "circuit", "wire", "bolts", "hdd"]
const STAT_NAMES := {"hp": "结构", "cargo": "货舱", "load": "承重", "energy": "能源", "drain": "耗能", "speed": "速度", "armor": "护甲"}

var _built := false
var _cur := "facilities"
var _tab_buttons := {}
var _body: VBoxContainer
var _scroll: ScrollContainer
var _money_lbl: Label
var _material_lbl: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func open() -> void:
	if not _built:
		_build()
	visible = true
	refresh()
	Audio.play_ui("ui_open")


func close() -> void:
	if not visible:
		return
	visible = false
	Audio.play_ui("ui_close")
	closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## 切到指定分页：facilities / research / pilots / crew / voyage
func show_tab(id: String) -> void:
	for t in TABS:
		if str(t[0]) == id:
			_cur = id
			refresh()
			return


func _input(e: InputEvent) -> void:
	if not visible:
		return
	if e.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


# ============================================================ 骨架
func _build() -> void:
	_built = true
	theme = UI.theme()
	# 背景压暗层只做装饰，不拦截任何输入
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.012, 0.018, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var line := ColorRect.new()
	line.color = Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, 0.18)
	line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	line.offset_top = 64
	line.offset_bottom = 65
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1080, 650)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", UI.px9("panel9", 16, 16, 16, 14))
	center.add_child(panel)
	UI.bind_fit_panel(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var head_plate := PanelContainer.new()
	head_plate.add_theme_stylebox_override("panel", UI.px9("plate9", 14, 14, 14, 8))
	root.add_child(head_plate)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head_plate.add_child(head)
	var mark := ColorRect.new()
	mark.color = UI.ACCENT
	mark.custom_minimum_size = Vector2(4, 18)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(mark)
	var title := UI.label(Loc.t("信天翁号 · 整备与航程", "Albatross · Refit & Voyage"), 24, Color(0.96, 0.92, 0.82))
	head.add_child(title)
	var sub := UI.label("ABYSS DIVER GIRLS", 12, UI.MUTED)
	sub.visible = Loc.is_en()
	sub.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(sub)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_money_lbl = UI.label("", 12, Color(0.95, 0.78, 0.36))
	head.add_child(_money_lbl)
	var close_btn := _button(Loc.t("关闭", "Close"), close)
	close_btn.custom_minimum_size = Vector2(84, 32)
	close_btn.set_meta("sfx", "")
	head.add_child(close_btn)

	root.add_child(UI.hazard_strip(8))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", 6)
	nav.custom_minimum_size = Vector2(152, 0)
	body.add_child(nav)
	var group := ButtonGroup.new()
	for t in TABS:
		var b := Button.new()
		b.text = Loc.t(str(t[1]))
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 42)
		b.add_theme_font_size_override("font_size", 12)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_stylebox_override("normal", UI.px9("nav9_n", 12, 12, 12, 6))
		b.add_theme_stylebox_override("hover", UI.px9("nav9_h", 12, 12, 12, 6))
		b.add_theme_stylebox_override("pressed", UI.px9("nav9_on", 12, 12, 12, 6))
		b.add_theme_stylebox_override("hover_pressed", UI.px9("nav9_on", 12, 12, 12, 6))
		b.add_theme_color_override("font_pressed_color", UI.GOLD)
		b.pressed.connect(_switch_tab.bind(str(t[0])))
		nav.add_child(b)
		_tab_buttons[str(t[0])] = b
	var nav_sp := Control.new()
	nav_sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_child(nav_sp)
	var nav_line := ColorRect.new()
	nav_line.color = Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, 0.35)
	nav_line.custom_minimum_size = Vector2(0, 2)
	nav.add_child(nav_line)

	var right_well := PanelContainer.new()
	right_well.add_theme_stylebox_override("panel", UI.px9("inset9", 8, 8, 12, 10))
	right_well.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(right_well)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	right_well.add_child(right)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.custom_minimum_size = Vector2(836, 0)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	_scroll.add_child(_body)

	var foot_plate := PanelContainer.new()
	foot_plate.add_theme_stylebox_override("panel", UI.px9("plate9", 12, 12, 12, 6))
	root.add_child(foot_plate)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	foot_plate.add_child(foot)
	var fbar := ColorRect.new()
	fbar.color = UI.ACCENT
	fbar.custom_minimum_size = Vector2(3, 14)
	fbar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(fbar)
	_material_lbl = UI.label("", 12, UI.MUTED)
	foot.add_child(_material_lbl)
	var fsp := Control.new()
	fsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(fsp)
	var fuse := UI.label(Loc.t("当前章节：", "Active Chapter: "), 12, UI.MUTED)
	foot.add_child(fuse)
	var fl := UI.label("", 12, UI.INFO)
	fl.name = "ChapterLabel"
	foot.add_child(fl)


func _switch_tab(id: String) -> void:
	_cur = id
	refresh()


func refresh() -> void:
	if not _built:
		return
	Growth.ensure_defaults()
	_money_lbl.text = "¥ " + Growth.money_text(int(GameData.money))
	var mats: Array = []
	for id: String in MATERIALS:
		var n := GameData.stash.count(id)
		if n > 0:
			mats.append("%s %d" % [GameData.item_name(id), n])
	_material_lbl.text = Loc.t("仓库材料：", "Materials: ") + (" · ".join(mats) if not mats.is_empty() else "—")
	var fl := find_child("ChapterLabel", true, false)
	if fl != null:
		var cid := Growth.current_chapter()
		var ch := _chapter(cid)
		fl.text = str(ch.get("title", "—")) if not ch.is_empty() else "—"
	for id in _tab_buttons:
		(_tab_buttons[id] as Button).button_pressed = id == _cur
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match _cur:
		"research":
			_build_research()
		"pilots":
			_build_pilots()
		"crew":
			_build_crew()
		"voyage":
			_build_voyage()
		_:
			_build_facilities()


func _chapter(id: String) -> Dictionary:
	for ch in Growth.chapters():
		if str(ch.id) == id:
			return ch
	return {}


# ============================================================ 通用小件
func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 34)
	b.set_meta("sfx", "")
	b.pressed.connect(cb)
	return b


func _label(text: String, size := 14, c := UI.TEXT) -> Label:
	return UI.label(text, size, c)


func _card(border := Color(1, 1, 1, 0.12)) -> VBoxContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var highlight := border.a > 0.25 and ((border.r > 0.5 and border.g > 0.4 and border.b < 0.35) or (border.g > 0.7 and border.r < 0.6))
	p.add_theme_stylebox_override("panel", UI.px9("card9_on" if highlight else "card9", 8, 8, 12, 10))
	_body.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	p.add_child(v)
	return v


func _row(parent: Control, sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	parent.add_child(h)
	return h


func _pips(value: int, mx: int, color := UI.ACCENT, segments := 0) -> Control:
	var segs := segments if segments > 0 else maxi(1, mx)
	var bar = UI.SegBar.new(color, segs, 8.0)
	bar.custom_minimum_size = Vector2(150, 8)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.set_value(value, mx)
	return bar


func _stat_line(add: Dictionary, mult := 1.0) -> String:
	var out: Array = []
	for k in add:
		var v := float(add[k]) * mult
		var nm := Loc.t(str(STAT_NAMES.get(k, k)))
		match str(k):
			"armor":
				out.append("%s %s%%" % [nm, _num(v * 100.0)])
			"drain":
				out.append("%s %+.3f" % [nm, v])
			"speed":
				out.append("%s %s" % [nm, _num(v, 2)])
			_:
				out.append("%s %s" % [nm, _num(v)])
	return " · ".join(out)


## 数值显示：整数不带小数点，带小数的保留一位（速度保留两位）
func _num(v: float, digits := 1) -> String:
	var r := roundf(v)
	if absf(v - r) < 0.05:
		return "%+d" % int(r)
	return ("%+." + str(digits) + "f") % v


func _items_text(items: Dictionary) -> String:
	var out: Array = []
	for id in items:
		out.append("%s×%d" % [GameData.item_name(str(id)), int(items[id])])
	return " · ".join(out)


func _missing_items(items: Dictionary) -> bool:
	for id in items:
		if GameData.stash.count(str(id)) < int(items[id]):
			return true
	return false


# ============================================================ 设施
func _build_facilities() -> void:
	_build_meal()
	for id in Growth.facility_ids():
		_build_facility(str(id))


func _build_meal() -> void:
	var lv: int = Growth.facility_level("kitchen")
	var ready: int = Growth.meal_ready()
	var cost: Dictionary = Growth.meal_cost()
	var v := _card(UI.ACCENT_DIM if lv > 0 else Color(1, 1, 1, 0.1))
	var h := _row(v)
	h.add_child(_label(Loc.t("出击食堂", "Mess Hall"), 19, Color(0.88, 0.88, 0.84)))
	h.add_child(_label(Loc.t("厨房 %s", "Kitchen %s") % Loc.lv(lv) if lv > 0 else Loc.t("厨房未建造", "Kitchen Not Built"), 13, UI.MUTED))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	var btn := _button(Loc.t("烹制餐点", "Cook Meal"), _serve_meal)
	btn.custom_minimum_size = Vector2(132, 34)
	btn.disabled = lv <= 0 or ready > 0 or _missing_items(cost)
	h.add_child(btn)
	var state := ""
	if lv <= 0:
		state = Loc.t("厨房未建造", "Kitchen Not Built")
	elif ready > 0:
		state = Growth.meal_text()
	elif _missing_items(cost):
		state = Loc.t("材料不足", "Insufficient Materials")
	else:
		state = Loc.t("未备餐", "No Meal Prepared")
	if ready > 0:
		v.add_child(_label(state, 14, UI.GOOD))
	elif state != "":
		v.add_child(_label(state, 14, UI.BAD if _missing_items(cost) else UI.MUTED))
	v.add_child(_label(Loc.t("消耗：", "Cost: ") + _items_text(cost), 12, UI.MUTED))


func _build_facility(id: String) -> void:
	var lv: int = Growth.facility_level(id)
	var mx: int = Growth.facility_max(id)
	var reason: String = Growth.can_upgrade(id)
	var v := _card(UI.ACCENT_DIM if lv > 0 else Color(1, 1, 1, 0.1))
	var h := _row(v)
	h.add_child(_label(Growth.facility_name(id), 19, Color(0.88, 0.88, 0.84)))
	h.add_child(_label("%s / %d" % [Loc.lv(lv), mx], 13, UI.MUTED))
	h.add_child(_pips(lv, mx))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	var cost := Growth.facility_cost(id)
	if not cost.is_empty():
		var cost_lb := _label(Growth.cost_text(cost), 12, UI.MUTED if reason in ["", "已满级"] else UI.BAD)
		cost_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(cost_lb)
	var btn := _button(Loc.t("已满级", "Maxed") if reason == "已满级" else Loc.t("升级", "Upgrade"), _upgrade_facility.bind(id))
	btn.custom_minimum_size = Vector2(86, 34)
	btn.disabled = reason != ""
	h.add_child(btn)
	if lv > 0:
		v.add_child(_label(Loc.t("当前：", "Current: ") + Growth.facility_effect(id), 13, Color(0.80, 0.82, 0.80)))
	var effects: Array = Growth.facility_effects(id)
	if not cost.is_empty() and lv < effects.size():
		v.add_child(_label(Loc.t("下一级：", "Next: ") + str(effects[lv]), 13, UI.ACCENT))
	if reason != "" and reason != "已满级":
		v.add_child(_label(Loc.reason(reason), 12, UI.BAD))


func _upgrade_facility(id: String) -> void:
	if Growth.upgrade_facility(id):
		refresh()
	else:
		Audio.play_ui("ui_denied")


func _serve_meal() -> void:
	if Growth.serve_meal():
		refresh()
	else:
		Audio.play_ui("ui_denied")


# ============================================================ 研究
func _build_research() -> void:
	var head := UI.header(Loc.t("研究", "Research"), Loc.t("研究室 %s", "Lab %s") % Loc.lv(Growth.facility_level("lab")), 18)
	_body.add_child(head)
	for id in Growth.research_ids():
		var rid := str(id)
		var d: Dictionary = Growth.research_data(rid)
		var reason: String = Growth.can_research(rid)
		var done := reason == "已完成"
		var v := _card(UI.ACCENT_DIM if done else Color(1, 1, 1, 0.12))
		var h := _row(v)
		h.add_child(_label(str(d.get("name", rid)), 18, Color(0.88, 0.88, 0.84)))
		var status_color := UI.GOOD if done else (UI.ACCENT if reason == "" else (UI.BAD if reason in ["材料不足", "信用点不足"] else UI.MUTED))
		var status_text := Loc.t("已完成", "Completed") if done else (Loc.t("可研究", "Available") if reason == "" else Loc.reason(reason))
		h.add_child(_label(status_text, 13, status_color))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(sp)
		var btn := _button(Loc.t("已完成", "Completed") if done else Loc.t("开始研究", "Start Research"), _do_research.bind(rid))
		btn.custom_minimum_size = Vector2(120, 34)
		btn.disabled = done or reason != ""
		h.add_child(btn)
		v.add_child(_label(str(d.get("effect", "")), 13, Color(0.80, 0.82, 0.80)))
		if done:
			continue
		var lab := int(d.get("lab", 1))
		var needs: Array = d.get("needs", [])
		var req: Array = [Loc.t("研究室 %s", "Lab %s") % Loc.lv(lab)]
		for n in needs:
			var nd: Dictionary = Growth.research_data(str(n))
			req.append(Loc.t("前置：", "Req: ") + str(nd.get("name", n)))
		v.add_child(_label(" · ".join(req), 12, UI.MUTED))
		v.add_child(_label(Loc.t("费用：", "Cost: ") + Growth.cost_text(d.get("cost", {})), 12,
			UI.BAD if reason in ["材料不足", "信用点不足"] else UI.MUTED))


func _do_research(id: String) -> void:
	if Growth.do_research(id):
		refresh()
	else:
		Audio.play_ui("ui_denied")


# ============================================================ 驾驶员
func _build_pilots() -> void:
	_body.add_child(UI.header(Loc.t("实战熟练度", "Field Proficiency"), Loc.t("使用自动升级 · 零资源消耗", "Levels automatically via use · zero cost"), 18))
	var sc := _card(Color(1, 1, 1, 0.12))
	for aid in Growth.ability_ids():
		var ad: Dictionary = Growth.ability_data(str(aid))
		var alv: int = Growth.ability_level(str(aid))
		var amx: int = Growth.ability_max(str(aid))
		var need: float = Growth.ability_xp_next(str(aid))
		var r := _row(sc, 8)
		r.add_child(_label("%s %s/%d" % [str(ad.get("name", aid)), Loc.lv(alv), amx], 14, UI.ACCENT if alv >= amx else UI.TEXT))
		var eff := _label(Loc.t("%s（%s）", "%s (%s)") % [str(ad.get("effect", "")), str(ad.get("how", ""))], 12, Color(0.78, 0.84, 0.78))
		eff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(eff)
		r.add_child(_label(Loc.t("满级", "Max") if need <= 0.0 else "%.1f/%d" % [Growth.ability_xp(str(aid)), int(need)], 12, UI.MUTED))
	_body.add_child(UI.header(Loc.t("驾驶员", "Pilots"), Loc.t("经验", "XP"), 18))
	for id in Growth.pilot_ids():
		_build_pilot(str(id))


func _build_pilot(id: String) -> void:
	var d: Dictionary = Growth.pilot_data(id)
	var p: Dictionary = Growth.pilot_state(id)
	var lv: int = Growth.pilot_level(id)
	var active: String = Growth.active_pilot()
	var is_active := id == active
	var v := _card(UI.ACCENT_DIM if is_active else Color(1, 1, 1, 0.12))
	var h := _row(v)
	h.add_child(_label(str(d.get("name", id)), 21, Color(0.88, 0.88, 0.84)))
	h.add_child(_label(Loc.lv(lv), 14, UI.MUTED))
	if is_active:
		h.add_child(_label(Loc.t("出击中", "Active"), 13, UI.GOOD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	var setb := _button(Loc.t("出击中", "Active") if is_active else Loc.t("设为出击机体", "Set Active Pilot"), _set_pilot.bind(id))
	setb.custom_minimum_size = Vector2(136, 34)
	setb.disabled = is_active
	h.add_child(setb)

	var xh := _row(v, 8)
	xh.add_child(_label(Loc.t("经验", "EXP"), 12, UI.MUTED))
	var next: int = Growth.pilot_xp_next(lv)
	var bar := _pips(Growth.pilot_xp(id), maxi(1, next), UI.ACCENT, 20)
	bar.custom_minimum_size = Vector2(230, 8)
	xh.add_child(bar)
	var xp_text := Loc.t("已满级", "Maxed") if next <= 0 else "%d / %d" % [Growth.pilot_xp(id), next]
	xh.add_child(_label(xp_text, 12, UI.MUTED))
	var per := _stat_line(d.get("level_stat", {}))
	if per != "":
		v.add_child(_label(Loc.t("每级：", "Per Level: ") + per, 13, Color(0.80, 0.82, 0.80)))


func _set_pilot(id: String) -> void:
	if Growth.set_active_pilot(id):
		Audio.play_ui("grow_level")
		refresh()


# ============================================================ 船员
func _build_crew() -> void:
	_body.add_child(UI.header(Loc.t("船员", "Crew"), Loc.t("后勤委托与赠礼", "Logistics Requests & Gifts"), 18))
	for id in Growth.crew_ids():
		_build_crew_card(str(id))


func _build_crew_card(id: String) -> void:
	var d: Dictionary = Growth.crew_data(id)
	var lv: int = Growth.crew_level(id)
	var points: int = Growth.crew_points(id)
	var need: int = Growth.crew_need(lv)
	var v := _card(UI.ACCENT_DIM if lv > 0 else Color(1, 1, 1, 0.12))
	var h := _row(v)
	h.add_child(_label(str(d.get("name", id)), 20, Color(0.88, 0.88, 0.84)))
	h.add_child(_label(Loc.t("好感 %s", "Trust %s") % Loc.lv(lv), 13, UI.MUTED))
	h.add_child(_pips(lv, 5))
	h.add_child(_label(Loc.t("已满", "Max") if need <= 0 else "%d / %d" % [points, need], 12, UI.MUTED))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	var levels: Array = d.get("levels", [])
	if lv > 0 and lv <= levels.size():
		v.add_child(_label(Loc.t("支援：", "Support: ") + str(levels[lv - 1]), 13, Color(0.80, 0.82, 0.80)))
	else:
		v.add_child(_label(Loc.t("支援 —", "Support —"), 13, UI.MUTED))
	if lv < 5 and lv < levels.size():
		v.add_child(_label(Loc.t("下一级：", "Next: ") + str(levels[lv]), 12, UI.ACCENT))
	var gifts: Dictionary = Growth.gift_items(id)
	var gh := HFlowContainer.new()
	gh.add_theme_constant_override("h_separation", 6)
	gh.add_theme_constant_override("v_separation", 4)
	v.add_child(gh)
	if gifts.is_empty():
		gh.add_child(_label(Loc.t("赠礼 —", "Gifts —"), 12, UI.MUTED))
	else:
		for iid in gifts:
			var nm := GameData.item_name(str(iid))
			var b := _button(Loc.t("赠礼 %s ×%d", "Gift %s ×%d") % [nm, int(gifts[iid])], _gift.bind(id, str(iid)))
			b.custom_minimum_size = Vector2(150, 30)
			gh.add_child(b)


func _gift(char_id: String, item_id: String) -> void:
	if Growth.give_gift(char_id, item_id):
		refresh()
	else:
		Audio.play_ui("ui_denied")


# ============================================================ 航程
func _build_voyage() -> void:
	var done := 0
	var total := Growth.chapters().size()
	for ch in Growth.chapters():
		if Growth.chapter_done(str(ch.id)):
			done += 1
	_body.add_child(UI.header(Loc.t("航程", "Voyage"), "%d / %d" % [done, total], 18))
	var top := _card(UI.ACCENT_DIM)
	var cur: Dictionary = _chapter(Growth.current_chapter())
	var th := _row(top)
	th.add_child(_label(Loc.t("当前章节", "Current Chapter"), 13, UI.MUTED))
	th.add_child(_label(str(cur.get("title", "—")), 18, Color(0.88, 0.88, 0.84)))
	var ph := _row(top, 8)
	ph.add_child(_label(Loc.t("进度", "Progress"), 12, UI.MUTED))
	var bar := _pips(done, maxi(1, total), UI.ACCENT, maxi(1, total))
	bar.custom_minimum_size = Vector2(260, 8)
	ph.add_child(bar)
	var maps: Array = []
	for mid in GameData.map_ids():
		var md: Dictionary = GameData.map_data(str(mid))
		if bool(md.get("hidden", false)):
			continue
		if GameData.map_available(str(mid)):
			maps.append(str(md.get("name", mid)))
	top.add_child(_label(Loc.t("已开放战区：", "Unlocked Sectors: ") + (" · ".join(maps) if not maps.is_empty() else "—"), 12, UI.MUTED))

	for ch in Growth.chapters():
		var cid := str(ch.id)
		var status := Growth.chapter_status(cid)
		var col := UI.GOOD if status == "已完成" else (UI.ACCENT if status == "进行中" else Color(1, 1, 1, 0.3))
		var v := _card(col)
		var h := _row(v, 10)
		var mark := _label("◆" if status != "未解锁" else "◇", 15, col)
		mark.custom_minimum_size = Vector2(20, 0)
		h.add_child(mark)
		h.add_child(_label(str(ch.title), 17, Color(0.88, 0.88, 0.84) if status != "未解锁" else UI.MUTED))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(sp)
		h.add_child(_label(str(GameData.map_data(str(ch.map)).get("name", ch.map)), 12, UI.MUTED))
		h.add_child(_label(Loc.t(status), 13, col))
