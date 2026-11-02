extends CanvasLayer
## 结算界面：撤离成功 / 行动失败、带回或失去的物品与估值、用时与击杀。记账在 main.gd 完成，这里只负责显示。
## 「返回飞空艇」按钮或 Esc 发出 back_requested；整个界面不接管其他输入。

signal back_requested

const UI = preload("res://scripts/ui.gd")
const HUD = preload("res://scripts/hud.gd")

var result := {}
var _done := false


func setup(r: Dictionary) -> void:
	result = r
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var lines: Array = []
	if r.success:
		lines.append("带回物品 %d 件，估值 ¥%d（其中现金 ¥%d 已入账）" % [r.cargo.size(), GameData.value_of(r.cargo), int(r.get("gained_money", 0))])
	else:
		var lost: Array = r.loadout.values().filter(func(x): return x != "")
		lines.append("失去机甲模块 %d 件，货舱物品 %d 件（估值 ¥%d）" % [lost.size(), r.cargo.size(), GameData.value_of(r.cargo) + GameData.value_of(lost)])
		lines.append("搜救索把弹出座舱的你拽回了云端，只是那台满载物资的机甲永远留在了废土上。")
	lines.append("行动时间 %02d:%02d · 击杀 %d" % [int(r.time) / 60, int(r.time) % 60, r.kills])

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var p := PanelContainer.new()
	p.theme = UI.theme()
	p.add_theme_stylebox_override("panel", UI.box(Color(0.06, 0.07, 0.09, 0.97), UI.ACCENT_DIM if r.success else UI.BAD, 1, 3, UI.GOOD if r.success else UI.BAD, 3, 22))
	p.custom_minimum_size = Vector2(560, 0)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(HUD.label("◆ 撤离成功" if r.success else "× 行动失败", 30, Color(0.4, 1.0, 0.6) if r.success else Color(1.0, 0.4, 0.35)))
	v.add_child(HUD.label(r.reason, 16, Color(0.8, 0.8, 0.8)))
	for l in lines:
		var lb := HUD.label(l, 16)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(lb)
	var b := Button.new()
	b.text = "返回飞空艇"
	b.custom_minimum_size = Vector2(0, 44)
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
