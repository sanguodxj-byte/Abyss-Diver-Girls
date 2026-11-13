extends CanvasLayer
## 结算界面：战果总评终端（撤离成功 / 行动失败、4 项核心 KPI、携行/损失物品像素网格、实战熟练度徽章）。
## 「返回飞空艇」按钮或 Esc 发出 back_requested；整个界面不接管其他输入。

signal back_requested

const UI = preload("res://scripts/ui.gd")
const K = preload("res://scripts/hub_kit.gd")

var result := {}
var _done := false


func setup(r: Dictionary) -> void:
	result = r
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var ok := bool(r.get("success", false))
	var cargo: Array = r.get("cargo", [])
	var loadout_dict: Dictionary = r.get("loadout", {})
	var lost_mods: Array = loadout_dict.values().filter(func(x): return str(x) != "")
	var cargo_val := GameData.value_of(cargo)
	var gained := int(r.get("gained_money", 0))
	var lost_val := cargo_val + GameData.value_of(lost_mods)
	var t_sec := int(r.get("time", 0))
	var kills := int(r.get("kills", 0))
	var skills: Array = r.get("skill_summary", []) if typeof(r.get("skill_summary")) == TYPE_ARRAY else []

	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.018, 0.025, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var p := PanelContainer.new()
	p.theme = K.theme()
	p.add_theme_stylebox_override("panel", K.px9("panel9", 16, 16, 16, 14))
	p.custom_minimum_size = Vector2(780, 0)
	center.add_child(p)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)

	# 1. 铆钉铭牌顶栏 + 警戒条
	v.add_child(UI.plate_header(Loc.t("行动战果报告", "After-Action Report"), "",
		(Loc.t("任务完成", "MISSION COMPLETE") if ok else Loc.t("机体失联 // 损毁报告", "MIA // LOSS REPORT"))))
	v.add_child(K.hazard_strip(8))

	# 2. 状态横幅
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", K.px9("card9_on" if ok else "card9", 10, 10, 14, 10))
	v.add_child(banner)
	var bh := VBoxContainer.new()
	bh.add_theme_constant_override("separation", 4)
	banner.add_child(bh)
	bh.add_child(UI.label(Loc.t("◆ 撤离成功", "◆ EXTRACTION COMPLETE") if ok else Loc.t("▲ 行动失利 · 机体损毁", "▲ OPERATION FAILED · MACHINE LOST"), 24, UI.GOOD if ok else UI.BAD, true))
	var reason_lbl := UI.label(Loc.t(str(r.get("reason", ""))), 12, K.CREAM)
	reason_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bh.add_child(reason_lbl)
	if not ok:
		var rescue_note := UI.label(Loc.t("搜救索把弹出座舱的你拽回了云端，只是那台满载物资的机甲永远留在了废土上。",
			"The recovery cable hauled your ejected pod back to the clouds, though that cargo-laden mech was lost to the wasteland forever."), 12, K.CREAM_DIM)
		rescue_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bh.add_child(rescue_note)

	# 3. 4 项核心 KPI 卡片
	var kpi_row := HBoxContainer.new()
	kpi_row.add_theme_constant_override("separation", 8)
	v.add_child(kpi_row)
	var kpis := [
		[Loc.t("物资估值", "Cargo Value") if ok else Loc.t("总计损失", "Total Loss"), "¥ %d" % (cargo_val if ok else lost_val), UI.GOLD if ok else UI.BAD],
		[Loc.t("现金入账", "Payout") if ok else Loc.t("模块损毁", "Modules Lost"), ("+¥ %d" % gained) if ok else (Loc.t("%d 件", "%d") % lost_mods.size()), UI.GOOD if ok else UI.BAD],
		[Loc.t("作战耗时", "Sortie Time"), "%02d:%02d" % [t_sec / 60, t_sec % 60], K.CREAM],
		[Loc.t("歼敌数量", "Hostiles Down"), (Loc.t("%d 台/只", "%d") % kills), UI.ACCENT],
	]
	for kd in kpis:
		var kc := K.card(false, 10)
		kc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kpi_row.add_child(kc)
		var kv := K.vbox(3)
		kc.add_child(kv)
		kv.add_child(UI.label(str(kd[0]), 12, K.CREAM_DIM))
		kv.add_child(UI.label(str(kd[1]), 24, kd[2], true))

	# 4. 回收/损失物品清单（ItemGrid 像素图标格子）
	var loot_hdr := K.section(Loc.t("回收货物清单", "Recovered Cargo") if ok else Loc.t("遗失装备与货物", "Lost Gear & Cargo"),
		"VALUATION", Loc.t("%d 件", "%d items") % (cargo.size() if ok else lost_mods.size() + cargo.size()))
	v.add_child(loot_hdr[0])
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", K.px9("inset9", 8, 8, 10, 8))
	v.add_child(well)
	var counts := {}
	var order: Array = []
	var src_items: Array = cargo if ok else (lost_mods + cargo)
	for iid in src_items:
		var sid := str(iid)
		if sid == "":
			continue
		if not counts.has(sid):
			order.append(sid)
		counts[sid] = int(counts.get(sid, 0)) + 1
	if order.is_empty():
		var empty_l := UI.label(Loc.t("本次行动未携行任何物品", "No cargo carried in this sortie") if ok else Loc.t("机甲无可记录损失件", "No recorded mech losses"), 12, K.CREAM_DIM)
		well.add_child(empty_l)
	else:
		var entries: Array = []
		for sid in order:
			entries.append({"id": sid, "count": counts[sid], "dim": not ok, "bad": not ok})
		var grid = K.ItemGrid.new(48)
		grid.custom_minimum_size = Vector2(0, 118)
		grid.set_entries(entries)
		well.add_child(grid)

	# 5. 实战熟练度成长
	if not skills.is_empty():
		v.add_child(K.section(Loc.t("实战熟练度成长", "Combat Proficiency"), "COMBAT PROFICIENCY", "")[0])
		var sk_flow := HFlowContainer.new()
		sk_flow.add_theme_constant_override("h_separation", 8)
		sk_flow.add_theme_constant_override("v_separation", 6)
		v.add_child(sk_flow)
		for sk in skills:
			var up := int(sk.get("levels", 0))
			var tag_c := K.card(up > 0, 8)
			sk_flow.add_child(tag_c)
			var sh := K.hbox(8)
			tag_c.add_child(sh)
			sh.add_child(UI.label(str(sk.get("name", "")), 12, UI.GOLD if up > 0 else K.CREAM))
			var xp_txt := "+%.1f %s" % [float(sk.get("xp", 0.0)), Loc.t("经验", "EXP")]
			if up > 0:
				xp_txt += "  ↑%s" % Loc.lv(int(sk.get("level", 1)))
			sh.add_child(UI.label(xp_txt, 12, UI.GOOD if up > 0 else K.CREAM_DIM))

	# 6. 返回飞空艇主按钮
	var b := K.primary(Loc.t("返回飞空艇", "Return to Airship"), 38)
	b.set_meta("sfx", "ui_confirm")
	b.pressed.connect(_back)
	v.add_child(b)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		Audio.play_ui("ui_confirm")
		_back()


func _back() -> void:
	if _done:
		return
	_done = true
	back_requested.emit()
