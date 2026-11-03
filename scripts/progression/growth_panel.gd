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
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.045, 0.05, 0.065, 0.98), UI.ACCENT_DIM, 1, 4, UI.ACCENT, 3, 18))
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	root.add_child(head)
	var mark := ColorRect.new()
	mark.color = UI.ACCENT
	mark.custom_minimum_size = Vector2(4, 0)
	head.add_child(mark)
	var title := UI.label("信天翁号 · 整备与航程", 26, Color(0.74, 0.67, 0.52))
	head.add_child(title)
	var sub := UI.label("ABYSS DIVER GIRLS", 11, UI.MUTED)
	sub.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(sub)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_money_lbl = UI.label("", 18, Color(0.74, 0.61, 0.28))
	head.add_child(_money_lbl)
	var close_btn := _button("关闭", close)
	close_btn.custom_minimum_size = Vector2(84, 36)
	close_btn.set_meta("sfx", "")
	head.add_child(close_btn)

	var sep := ColorRect.new()
	sep.color = Color(1, 1, 1, 0.08)
	sep.custom_minimum_size = Vector2(0, 1)
	root.add_child(sep)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", 6)
	nav.custom_minimum_size = Vector2(152, 0)
	body.add_child(nav)
	var group := ButtonGroup.new()
	for t in TABS:
		var b := Button.new()
		b.text = str(t[1])
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 44)
		b.add_theme_font_size_override("font_size", 17)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_stylebox_override("normal", UI.box(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.12), 1, 0, UI.ACCENT, 0, 10))
		b.add_theme_stylebox_override("hover", UI.box(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.28), 1, 0, UI.ACCENT, 0, 10))
		b.add_theme_stylebox_override("pressed", UI.box(Color(0.62, 0.37, 0.09, 0.2), Color(0.74, 0.53, 0.25), 1, 0, UI.ACCENT, 3, 10))
		b.add_theme_color_override("font_pressed_color", Color(0.75, 0.63, 0.41))
		b.pressed.connect(_switch_tab.bind(str(t[0])))
		nav.add_child(b)
		_tab_buttons[str(t[0])] = b
	var nav_sp := Control.new()
	nav_sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_child(nav_sp)
	var nav_line := ColorRect.new()
	nav_line.color = Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, 0.25)
	nav_line.custom_minimum_size = Vector2(0, 2)
	nav.add_child(nav_line)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.custom_minimum_size = Vector2(856, 0)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	_scroll.add_child(_body)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	root.add_child(foot)
	var fbar := ColorRect.new()
	fbar.color = UI.ACCENT
	fbar.custom_minimum_size = Vector2(3, 0)
	foot.add_child(fbar)
	_material_lbl = UI.label("", 13, UI.MUTED)
	foot.add_child(_material_lbl)
	var fsp := Control.new()
	fsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(fsp)
	var fuse := UI.label("当前章节：", 13, UI.MUTED)
	foot.add_child(fuse)
	var fl := UI.label("", 13, UI.INFO)
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
	_material_lbl.text = "仓库材料：" + (" · ".join(mats) if not mats.is_empty() else "—")
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
	p.add_theme_stylebox_override("panel", UI.box(Color(0.06, 0.07, 0.09, 0.94), border, 1, 0, UI.ACCENT, 2, 12))
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
		var nm := str(STAT_NAMES.get(k, k))
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
	h.add_child(_label("出击食堂", 19, Color(0.74, 0.67, 0.52)))
	h.add_child(_label("厨房 Lv.%d" % lv if lv > 0 else "厨房未建造", 13, UI.MUTED))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	var btn := _button("烹制餐点", _serve_meal)
	btn.custom_minimum_size = Vector2(132, 34)
	btn.disabled = lv <= 0 or ready > 0 or _missing_items(cost)
	h.add_child(btn)
	var state := ""
	if lv <= 0:
		state = "厨房未建造"
	elif ready > 0:
		state = Growth.meal_text()
	elif _missing_items(cost):
		state = "材料不足"
	else:
		state = "未备餐"
	if ready > 0:
		v.add_child(_label(state, 14, UI.GOOD))
	elif state != "":
		v.add_child(_label(state, 14, UI.BAD if state == "材料不足" else UI.MUTED))
	v.add_child(_label("消耗：" + _items_text(cost), 12, UI.MUTED))


func _build_facility(id: String) -> void:
	var lv: int = Growth.facility_level(id)
	var mx: int = Growth.facility_max(id)
	var reason: String = Growth.can_upgrade(id)
	var v := _card(UI.ACCENT_DIM if lv > 0 else Color(1, 1, 1, 0.1))
	var h := _row(v)
	h.add_child(_label(Growth.facility_name(id), 19, Color(0.74, 0.67, 0.52)))
	h.add_child(_label("Lv.%d / %d" % [lv, mx], 13, UI.MUTED))
	h.add_child(_pips(lv, mx))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	var cost := Growth.facility_cost(id)
	if not cost.is_empty():
		var cost_lb := _label(Growth.cost_text(cost), 12, UI.MUTED if reason in ["", "已满级"] else UI.BAD)
		cost_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(cost_lb)
	var btn := _button("已满级" if reason == "已满级" else "升级", _upgrade_facility.bind(id))
	btn.custom_minimum_size = Vector2(86, 34)
	btn.disabled = reason != ""
	h.add_child(btn)
	if lv > 0:
		v.add_child(_label("当前：" + Growth.facility_effect(id), 13, Color(0.8, 0.88, 0.8)))
	var effects: Array = Growth.facility_effects(id)
	if not cost.is_empty() and lv < effects.size():
		v.add_child(_label("下一级：" + str(effects[lv]), 13, UI.ACCENT))
	if reason != "" and reason != "已满级":
		v.add_child(_label(reason, 12, UI.BAD))


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
	var head := UI.header("研究", "研究室 Lv.%d" % Growth.facility_level("lab"), 18)
	_body.add_child(head)
	for id in Growth.research_ids():
		var rid := str(id)
		var d: Dictionary = Growth.research_data(rid)
		var reason: String = Growth.can_research(rid)
		var done := reason == "已完成"
		var v := _card(Color(0.4, 1.0, 0.6, 0.45) if done else Color(1, 1, 1, 0.12))
		var h := _row(v)
		h.add_child(_label(str(d.get("name", rid)), 18, Color(0.74, 0.67, 0.52)))
		var status_color := UI.GOOD if done else (UI.ACCENT if reason == "" else (UI.BAD if reason in ["材料不足", "信用点不足"] else UI.MUTED))
		var status_text := "已完成" if done else ("可研究" if reason == "" else reason)
		h.add_child(_label(status_text, 13, status_color))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(sp)
		var btn := _button("已完成" if done else "开始研究", _do_research.bind(rid))
		btn.custom_minimum_size = Vector2(120, 34)
		btn.disabled = done or reason != ""
		h.add_child(btn)
		v.add_child(_label(str(d.get("effect", "")), 13, Color(0.82, 0.88, 0.8)))
		if done:
			continue
		var lab := int(d.get("lab", 1))
		var needs: Array = d.get("needs", [])
		var req: Array = ["研究室 Lv%d" % lab]
		for n in needs:
			var nd: Dictionary = Growth.research_data(str(n))
			req.append("前置：" + str(nd.get("name", n)))
		v.add_child(_label(" · ".join(req), 12, UI.MUTED))
		v.add_child(_label("费用：" + Growth.cost_text(d.get("cost", {})), 12,
			UI.BAD if reason in ["材料不足", "信用点不足"] else UI.MUTED))


func _do_research(id: String) -> void:
	if Growth.do_research(id):
		refresh()
	else:
		Audio.play_ui("ui_denied")


# ============================================================ 驾驶员
func _build_pilots() -> void:
	_body.add_child(UI.header("驾驶员", "经验与天赋", 18))
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
	h.add_child(_label(str(d.get("name", id)), 21, Color(0.74, 0.67, 0.52)))
	h.add_child(_label("Lv.%d" % lv, 14, UI.MUTED))
	if is_active:
		h.add_child(_label("出击中", 13, UI.GOOD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	h.add_child(_label("天赋点 %d" % Growth.pilot_points(id), 13, UI.INFO))
	var setb := _button("出击中" if is_active else "设为出击机体", _set_pilot.bind(id))
	setb.custom_minimum_size = Vector2(136, 34)
	setb.disabled = is_active
	h.add_child(setb)

	var xh := _row(v, 8)
	xh.add_child(_label("经验", 12, UI.MUTED))
	var next: int = Growth.pilot_xp_next(lv)
	var bar := _pips(Growth.pilot_xp(id), maxi(1, next), UI.ACCENT, 20)
	bar.custom_minimum_size = Vector2(230, 8)
	xh.add_child(bar)
	var xp_text := "已满级" if next <= 0 else "%d / %d" % [Growth.pilot_xp(id), next]
	xh.add_child(_label(xp_text, 12, UI.MUTED))
	var per := _stat_line(d.get("level_stat", {}))
	if per != "":
		v.add_child(_label("每级：" + per, 13, Color(0.8, 0.88, 0.8)))
	var th := _row(v, 8)
	th.add_child(_label("天赋", 14, UI.MUTED))
	var tl := ColorRect.new()
	tl.color = Color(1, 1, 1, 0.08)
	tl.custom_minimum_size = Vector2(0, 1)
	v.add_child(tl)
	for t in d.get("talents", []):
		var tid := str(t.id)
		var reason: String = Growth.can_learn_talent(id, tid)
		var learned := reason == "已习得"
		var tr := _row(v, 8)
		tr.add_child(_label(str(t.get("name", tid)), 15, UI.ACCENT if learned else UI.TEXT))
		tr.add_child(_label("Lv.%d" % int(t.get("level", 1)), 12, UI.MUTED))
		var eff := _label(str(t.get("effect", "")), 12, Color(0.8, 0.88, 0.8))
		eff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tr.add_child(eff)
		tr.add_child(_label("天赋点 %d" % int(t.get("points", 1)), 12, UI.MUTED))
		var tb := _button("已习得" if learned else "习得", _learn_talent.bind(id, tid))
		tb.custom_minimum_size = Vector2(80, 30)
		tb.disabled = reason != ""
		tr.add_child(tb)


func _set_pilot(id: String) -> void:
	if Growth.set_active_pilot(id):
		Audio.play_ui("grow_level")
		refresh()


func _learn_talent(pid: String, tid: String) -> void:
	if Growth.learn_talent(pid, tid):
		refresh()
	else:
		Audio.play_ui("ui_denied")


# ============================================================ 船员
func _build_crew() -> void:
	_body.add_child(UI.header("船员", "后勤委托与赠礼", 18))
	for id in Growth.crew_ids():
		_build_crew_card(str(id))


func _build_crew_card(id: String) -> void:
	var d: Dictionary = Growth.crew_data(id)
	var lv: int = Growth.crew_level(id)
	var points: int = Growth.crew_points(id)
	var need: int = Growth.crew_need(lv)
	var v := _card(UI.ACCENT_DIM if lv > 0 else Color(1, 1, 1, 0.12))
	var h := _row(v)
	h.add_child(_label(str(d.get("name", id)), 20, Color(0.74, 0.67, 0.52)))
	h.add_child(_label("好感 Lv.%d" % lv, 13, UI.MUTED))
	h.add_child(_pips(lv, 5))
	h.add_child(_label("已满" if need <= 0 else "%d / %d" % [points, need], 12, UI.MUTED))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	var levels: Array = d.get("levels", [])
	if lv > 0 and lv <= levels.size():
		v.add_child(_label("支援：" + str(levels[lv - 1]), 13, Color(0.8, 0.88, 0.8)))
	else:
		v.add_child(_label("支援 —", 13, UI.MUTED))
	if lv < 5 and lv < levels.size():
		v.add_child(_label("下一级：" + str(levels[lv]), 12, UI.ACCENT))
	var gifts: Dictionary = Growth.gift_items(id)
	var gh := HFlowContainer.new()
	gh.add_theme_constant_override("h_separation", 6)
	gh.add_theme_constant_override("v_separation", 4)
	v.add_child(gh)
	if gifts.is_empty():
		gh.add_child(_label("赠礼 —", 12, UI.MUTED))
	else:
		for iid in gifts:
			var nm := GameData.item_name(str(iid))
			var b := _button("赠礼 %s ×%d" % [nm, int(gifts[iid])], _gift.bind(id, str(iid)))
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
	_body.add_child(UI.header("航程", "%d / %d" % [done, total], 18))
	var top := _card(UI.ACCENT_DIM)
	var cur: Dictionary = _chapter(Growth.current_chapter())
	var th := _row(top)
	th.add_child(_label("当前章节", 13, UI.MUTED))
	th.add_child(_label(str(cur.get("title", "—")), 18, Color(0.74, 0.67, 0.52)))
	var ph := _row(top, 8)
	ph.add_child(_label("进度", 12, UI.MUTED))
	var bar := _pips(done, maxi(1, total), UI.ACCENT, maxi(1, total))
	bar.custom_minimum_size = Vector2(260, 8)
	ph.add_child(bar)
	var maps: Array = []
	for mid in GameData.map_ids():
		if GameData.map_available(str(mid)):
			maps.append(str(GameData.map_data(str(mid)).get("name", mid)))
	top.add_child(_label("已开放战区：" + (" · ".join(maps) if not maps.is_empty() else "—"), 12, UI.MUTED))

	for ch in Growth.chapters():
		var cid := str(ch.id)
		var status := Growth.chapter_status(cid)
		var col := UI.GOOD if status == "已完成" else (UI.ACCENT if status == "进行中" else Color(1, 1, 1, 0.3))
		var v := _card(col)
		var h := _row(v, 10)
		var mark := _label("◆" if status != "未解锁" else "◇", 15, col)
		mark.custom_minimum_size = Vector2(20, 0)
		h.add_child(mark)
		h.add_child(_label(str(ch.title), 17, Color(0.74, 0.67, 0.52) if status != "未解锁" else UI.MUTED))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(sp)
		h.add_child(_label(str(GameData.map_data(str(ch.map)).get("name", ch.map)), 12, UI.MUTED))
		h.add_child(_label(status, 13, col))
