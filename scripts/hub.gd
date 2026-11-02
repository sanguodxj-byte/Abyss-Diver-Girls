extends Control
## 飞空艇「信天翁号」机库：3D 机库背景 + 机甲组装（纸娃娃）、仓库、商店、委托、出击货舱。

signal deploy_requested

const MV = preload("res://scripts/mech_visual.gd")
const A = preload("res://scripts/art.gd")
const UI = preload("res://scripts/ui.gd")
const HUD = preload("res://scripts/hud.gd")
const Growth = preload("res://scripts/progression/growth.gd")

var preview_root: Node3D
var preview_mech: Node3D
var turntable: Node3D
var slot_buttons := {}
var slot_name_lbls := {}
var slot_stat_lbls := {}
var stat_rows := {}
var money_lbl: Label
var record_lbl: Label
var stash_list: ItemList
var cargo_list: ItemList
var shop_list: ItemList
var detail_lbl: Label
var request_lbl: Label
var cargo_lbl: Label
var deploy_btn: Button
var deploy_err: Label
var popup: PopupMenu
var popup_slot := ""
var popup_map := {}
var stash_ids: Array = []
var shop_ids: Array = []         ## 商店列表每一行对应的物品 id（GameData.shop_items() 的结果）
var selected_stash := ""
var selected_shop := -1
var drag := false
var hangar_vp: SubViewport
var exploded := false
var explode_btn: Button
var preview_cam: Camera3D
var spin := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	_build_hangar()

	# 顶栏
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UI.box(Color(0.03, 0.035, 0.05, 0.85), Color(0, 0, 0, 0), 0, 0, UI.ACCENT, 0, 14))
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 54
	add_child(top)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 14)
	top.add_child(th)
	var logo := ColorRect.new()
	logo.color = UI.ACCENT
	logo.custom_minimum_size = Vector2(6, 0)
	th.add_child(logo)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -2)
	th.add_child(tv)
	tv.add_child(UI.label("飞空艇「信天翁号」", 20, Color(1.0, 0.88, 0.66)))
	tv.add_child(UI.label("ABYSS DIVER GIRLS · 打捞团机库", 11, UI.MUTED))
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
	money_lbl = UI.label("", 18, Color(1.0, 0.85, 0.4))
	mp.add_child(money_lbl)
	var stripe := ColorRect.new()
	stripe.color = UI.ACCENT_DIM
	stripe.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	stripe.offset_top = 54
	stripe.offset_bottom = 56
	add_child(stripe)

	_build_left()
	_build_right()

	# 底部：电台对白
	var radio := PanelContainer.new()
	radio.add_theme_stylebox_override("panel", UI.box(Color(0.03, 0.04, 0.05, 0.75), Color(0, 0, 0, 0), 0, 0, UI.ACCENT, 3, 10))
	radio.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	radio.offset_bottom = -18
	radio.grow_horizontal = Control.GROW_DIRECTION_BOTH
	radio.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(radio)
	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", 8)
	radio.add_child(rh)
	rh.add_child(UI.label("◆ 电台", 12, UI.INFO))
	rh.add_child(UI.label(GameData.DISPATCH_LINES[randi() % GameData.DISPATCH_LINES.size()], 13, Color(0.78, 0.82, 0.86)))

	# 顶部中央：拆解视图（爆炸图，显示各模块的标准接口）
	explode_btn = Button.new()
	explode_btn.text = "◇ 拆解视图"
	explode_btn.custom_minimum_size = Vector2(150, 34)
	explode_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	explode_btn.offset_top = 74
	explode_btn.offset_bottom = 108
	explode_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	explode_btn.set_meta("sfx", "")   # _toggle_explode 自己播放拆解 / 组装音效
	explode_btn.pressed.connect(_toggle_explode)
	add_child(explode_btn)

	popup = PopupMenu.new()
	popup.set_meta("sfx", "")   # _on_popup 自己播放分离 / 对接音效
	popup.id_pressed.connect(_on_popup)
	add_child(popup)
	refresh()


# ============================================================ 3D 机库
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

	# 地板：金属格栅 + 中央转台
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
	# 后墙：面板 + 编号 + 舷窗外的黄昏
	var M_WALL := A.paint(Color(0.24, 0.26, 0.3), 0.3, 0.6)
	for x in range(-5, 6):
		A.add(preview_root, A.bevel_box(Vector3(2.8, 7.5, 0.4), 0.08), M_WALL, Vector3(x * 3.0, 3.75, -9.5))
		A.add(preview_root, A.bevel_box(Vector3(0.25, 7.6, 0.6), 0.04), A.metal(Color(0.12, 0.12, 0.14)), Vector3(x * 3.0 + 1.5, 3.8, -9.3))
	for x in [-6.0, 6.0]:
		var win := A.add(preview_root, A.bevel_box(Vector3(4.2, 2.2, 0.1), 0.05), A.emit(Color(0.95, 0.55, 0.32), 0.9), Vector3(x, 4.6, -9.25), Vector3.ZERO, Vector3.ONE, false)
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
	# 两侧支架与货箱
	for sx in [-1.0, 1.0]:
		A.add(preview_root, A.bevel_box(Vector3(0.6, 8.0, 0.6), 0.08), A.paint(Color(0.85, 0.55, 0.15), 0.3, 0.5), Vector3(sx * 7.5, 4.0, -4.0))
		A.add(preview_root, A.bevel_box(Vector3(0.6, 0.6, 6.0), 0.08), A.paint(Color(0.85, 0.55, 0.15), 0.3, 0.5), Vector3(sx * 7.5, 7.7, -1.5))
		A.add(preview_root, A.bevel_box(Vector3(1.6, 1.2, 1.2), 0.08), A.paint(Color(0.3, 0.38, 0.28), 0.2, 0.7), Vector3(sx * 6.0, 0.6, -6.5))
		A.add(preview_root, A.bevel_box(Vector3(1.2, 0.9, 1.0), 0.08), A.paint(Color(0.55, 0.35, 0.18), 0.2, 0.7), Vector3(sx * 6.2, 1.65, -6.4), Vector3(0, 15, 0))
		A.add(preview_root, A.bevel_box(Vector3(1.4, 1.0, 1.0), 0.08), A.paint(Color(0.3, 0.38, 0.28), 0.2, 0.7), Vector3(sx * 7.0, 0.5, 2.0), Vector3(0, -20, 0))
	# 灯光：顶部主聚光 + 两侧轮廓光
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
	# 前方柔和补光（让涂装与掉漆细节可读）
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
	# 空气里的灰尘
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


# ============================================================ 左：组装
func _build_left() -> void:
	var p := UI.panel(14)
	p.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	p.offset_left = 16
	p.offset_top = 72
	p.offset_bottom = -16
	p.offset_right = 16 + 340
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UI.header("机甲组装"))
	for slot in GameData.SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 52)
		b.pressed.connect(_open_slot_menu.bind(slot))
		v.add_child(b)
		var m := MarginContainer.new()
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_theme_constant_override("margin_left", 12)
		m.add_theme_constant_override("margin_right", 12)
		m.add_theme_constant_override("margin_top", 6)
		m.add_theme_constant_override("margin_bottom", 6)
		b.add_child(m)
		var bv := VBoxContainer.new()
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_theme_constant_override("separation", 0)
		m.add_child(bv)
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(top)
		var sl := UI.label(GameData.SLOT_NAMES[slot], 11, UI.MUTED)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(sl)
		var st := UI.label("", 11, UI.MUTED)
		top.add_child(st)
		var nl := UI.label("", 16)
		bv.add_child(nl)
		slot_buttons[slot] = b
		slot_name_lbls[slot] = nl
		slot_stat_lbls[slot] = st
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 2)
	v.add_child(gap)
	v.add_child(UI.header("机体性能", "", 15))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 5)
	v.add_child(grid)
	for k in [["hp", "结构", UI.HP_C], ["energy", "能源", UI.EN_C], ["speed", "速度", UI.INFO], ["load", "承重", Color(0.75, 0.6, 1.0)], ["cargo", "货舱", UI.GOOD]]:
		grid.add_child(UI.label(k[1], 12, UI.MUTED))
		var bar = UI.SegBar.new(k[2], 16, 8.0)
		bar.custom_minimum_size = Vector2(170, 8)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(bar)
		var val := UI.label("", 12)
		val.custom_minimum_size = Vector2(80, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(val)
		stat_rows[k[0]] = [bar, val]


# ============================================================ 右：仓库 / 商店 / 委托 / 出击
func _build_right() -> void:
	var p := UI.panel(14)
	p.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	p.offset_right = -16
	p.offset_top = 72
	p.offset_bottom = -16
	p.offset_left = -16 - 380
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)

	# 仓库
	var sv := VBoxContainer.new()
	sv.name = "仓库"
	sv.add_theme_constant_override("separation", 6)
	tabs.add_child(sv)
	stash_list = _list()
	stash_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stash_list.item_selected.connect(_on_stash_selected)
	stash_list.item_activated.connect(func(_i): _move_to_cargo())
	sv.add_child(stash_list)
	detail_lbl = UI.label("", 12, UI.MUTED)
	detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_lbl.custom_minimum_size = Vector2(0, 52)
	sv.add_child(detail_lbl)
	var mb := HBoxContainer.new()
	mb.add_theme_constant_override("separation", 6)
	sv.add_child(mb)
	_btn(mb, "装入货舱", _move_to_cargo)
	_btn(mb, "出售 1 件", _sell_selected)
	_btn(mb, "出售杂物", _sell_junk)

	# 商店
	var shv := VBoxContainer.new()
	shv.name = "商店"
	shv.add_theme_constant_override("separation", 6)
	tabs.add_child(shv)
	shop_list = _list()
	shop_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_list.item_selected.connect(func(i): selected_shop = i)
	shop_list.item_activated.connect(_buy)
	shv.add_child(shop_list)
	var sb := HBoxContainer.new()
	shv.add_child(sb)
	_btn(sb, "购买选中", func():
		if selected_shop >= 0:
			_buy(selected_shop)
		else:
			Audio.play_ui("ui_denied"))

	# 委托
	var rv := VBoxContainer.new()
	rv.name = "委托"
	rv.add_theme_constant_override("separation", 10)
	tabs.add_child(rv)
	var rp := PanelContainer.new()
	rp.add_theme_stylebox_override("panel", UI.box(Color(0.45, 0.85, 1.0, 0.06), Color(0.45, 0.85, 1.0, 0.25), 1, 0, UI.ACCENT, 3, 12))
	rv.add_child(rp)
	request_lbl = UI.label("", 14, Color(0.75, 0.92, 1.0))
	request_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rp.add_child(request_lbl)
	var rb := HBoxContainer.new()
	rb.add_theme_constant_override("separation", 6)
	rv.add_child(rb)
	_btn(rb, "提交委托", func():
		if GameData.fulfill_request():
			Audio.play_ui("request_complete")
			refresh()
		else:
			Audio.play_ui("ui_denied"))
	_btn(rb, "领取应急机架（免费）", _starter_frame)

	# 出击货舱
	var hh := HBoxContainer.new()
	v.add_child(hh)
	hh.add_child(UI.header("出击货舱", "", 15))
	cargo_lbl = UI.label("", 12, UI.MUTED)
	cargo_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cargo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hh.add_child(cargo_lbl)
	cargo_list = _list()
	cargo_list.custom_minimum_size = Vector2(0, 96)
	cargo_list.max_text_lines = 1
	cargo_list.item_activated.connect(_cargo_back)
	v.add_child(cargo_list)
	# 战区选择
	var mh := HBoxContainer.new()
	v.add_child(mh)
	mh.add_child(UI.header("出击战区", "", 15))
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 6)
	v.add_child(mrow)
	var map_desc := UI.label("", 12, UI.MUTED)
	map_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var grp := ButtonGroup.new()
	for id: String in GameData.map_ids():
		var md: Dictionary = GameData.MAPS[id]
		var b := Button.new()
		b.disabled = not GameData.map_available(id)
		b.toggle_mode = true
		b.button_group = grp
		b.text = md.name
		b.clip_text = true
		b.custom_minimum_size = Vector2(0, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_stylebox_override("normal", UI.box(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.14), 1, 0, UI.ACCENT, 0, 8))
		b.add_theme_stylebox_override("hover", UI.box(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.3), 1, 0, UI.ACCENT, 0, 8))
		b.add_theme_stylebox_override("pressed", UI.box(Color(1.0, 0.6, 0.15, 0.18), Color(1.0, 0.7, 0.3), 1, 0, UI.ACCENT, 3, 8))
		b.add_theme_color_override("font_pressed_color", Color(1.0, 0.82, 0.5))
		b.button_pressed = id == GameData.map_id
		b.toggled.connect(func(on: bool):
			if on:
				GameData.map_id = id
				map_desc.text = "%s  ·  %s" % [md.tag, md.desc])
		mrow.add_child(b)
	var cm: Dictionary = GameData.map_data(GameData.map_id)
	map_desc.text = "%s  ·  %s" % [cm.tag, cm.desc]
	map_desc.custom_minimum_size = Vector2(10, 0)
	v.add_child(map_desc)
	deploy_err = UI.label("", 13, UI.BAD)
	deploy_err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(deploy_err)
	deploy_btn = Button.new()
	deploy_btn.text = "▼  空投出击"
	deploy_btn.custom_minimum_size = Vector2(0, 54)
	deploy_btn.add_theme_font_size_override("font_size", 22)
	deploy_btn.add_theme_stylebox_override("normal", UI.box(Color(0.85, 0.48, 0.1, 0.95), Color(1, 0.75, 0.4), 1, 0, UI.ACCENT, 3, 12))
	deploy_btn.add_theme_stylebox_override("hover", UI.box(Color(1.0, 0.58, 0.16, 1.0), Color(1, 0.85, 0.6), 1, 0, UI.ACCENT, 3, 12))
	deploy_btn.add_theme_stylebox_override("pressed", UI.box(Color(0.7, 0.38, 0.08, 1.0), Color(1, 0.75, 0.4), 1, 0, UI.ACCENT, 3, 12))
	deploy_btn.add_theme_color_override("font_color", Color(0.08, 0.05, 0.02))
	deploy_btn.add_theme_color_override("font_hover_color", Color(0.05, 0.03, 0.0))
	deploy_btn.set_meta("sfx", "ui_confirm")
	deploy_btn.pressed.connect(func(): deploy_requested.emit())
	v.add_child(deploy_btn)


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
	b.set_meta("sfx", "")   # 回调里按结果播放成功或拒绝音效
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _process(delta: float) -> void:
	if turntable and preview_mech:
		if not drag:
			spin += delta * 0.35
		turntable.rotation.y = lerp_angle(turntable.rotation.y, spin, clamp(delta * 8.0, 0.0, 1.0))


# ============================================================ 刷新
func refresh() -> void:
	GameData.save_game()
	money_lbl.text = "¥ %s" % _fmt_money(GameData.money)
	record_lbl.text = "出击 %d   ·   成功撤离 %d" % [GameData.raids, GameData.extracts_ok]
	RenderingServer.global_shader_parameter_set("mech_damage", 0.0)
	if preview_mech and is_instance_valid(preview_mech):
		# 只拆装发生变化的模块（带分离 / 对接动画）
		MV.apply(preview_mech, GameData.loadout, true)
	else:
		preview_mech = MV.build(GameData.loadout)
		turntable.add_child(preview_mech)
		preview_mech.position.y = 0.2
		preview_mech.rotation.y = PI
	for slot in GameData.SLOTS:
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
	_stat("hp", st.hp, 300.0, "%d" % st.hp + ("  甲%d%%" % int(st.armor * 100) if st.armor > 0 else ""))
	_stat("energy", st.energy, 250.0, "%d · %d:%02d" % [st.energy, int(runtime) / 60, int(runtime) % 60])
	_stat("speed", st.speed * sf, 10.0, "%.1f%s" % [st.speed * sf, "" if sf > 0.99 else " ↓"])
	_stat("load", st.mass + cw, max(1.0, st.load), "%.0f/%.0f" % [st.mass + cw, st.load])
	_stat("cargo", st.cargo, 40.0, "%.0f kg" % st.cargo)
	var lr: Array = stat_rows["load"]
	lr[0].color = Color(0.75, 0.6, 1.0) if sf > 0.99 else UI.BAD

	# 仓库（同类堆叠显示）
	stash_list.clear()
	stash_ids.clear()
	var counts := {}
	for id in GameData.stash:
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
	if stash_ids.is_empty():
		stash_list.add_item("货架上空空荡荡，只剩一层陈年机油味。等下一趟潜渊带点罐头与零件回来吧。")
		stash_list.set_item_disabled(0, true)

	cargo_list.clear()
	for id in GameData.cargo:
		var it := GameData.item(id)
		cargo_list.add_item("%s  %.1fkg" % [it.name, it.w], UI.rarity_icon(int(it.rar), it.cat))
	cargo_lbl.text = "%.1f / %.0f kg" % [cw, st.cargo]
	shop_list.clear()
	shop_ids = GameData.shop_items()
	for id in shop_ids:
		var it := GameData.item(id)
		var idx := shop_list.add_item("%s    %s · ¥%d" % [it.name, GameData.CAT_NAMES.get(it.cat, ""), _price(id)], UI.rarity_icon(int(it.rar), it.cat))
		shop_list.set_item_custom_fg_color(idx, GameData.RARITY_COLORS[int(it.rar)])

	var rq := GameData.request
	if not rq.is_empty():
		request_lbl.text = "%s 的委托\n需要：%s ×%d（仓库现有 %d）\n报酬：¥%d" % [rq.who, GameData.item_name(rq.id), rq.count, GameData.count_in_stash(rq.id), rq.reward]
	var err := GameData.can_deploy(GameData.loadout)
	deploy_err.text = err
	deploy_btn.disabled = err != ""
	deploy_btn.modulate.a = 0.5 if err != "" else 1.0


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
	detail_lbl.text = "%s〔%s〕%s%s" % [it.name, GameData.RARITY_NAMES[int(it.rar)], Growth.subst(str(it.get("desc", ""))), extra]


func _move_to_cargo() -> void:
	if selected_stash == "" or not GameData.stash.has(selected_stash):
		Audio.play_ui("ui_denied")
		return
	var st := GameData.compute_stats(GameData.loadout)
	if GameData.weight_of(GameData.cargo) + float(GameData.item(selected_stash).w) > st.cargo:
		deploy_err.text = "出击货舱超出承重上限"
		Audio.play_ui("ui_denied")
		return
	GameData.stash.erase(selected_stash)
	GameData.cargo.append(selected_stash)
	Audio.play_ui("cargo_load")
	refresh()


func _cargo_back(i: int) -> void:
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
	if not changed:
		deploy_err.text = "机体状态齐备，无需申请应急机架"
	Audio.play_ui("hub_starter" if changed else "ui_denied")
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
		# 新模块的对接动画在旧模块退出后约 0.45 秒到位
		get_tree().create_timer(0.45 if cur != "" else 0.28).timeout.connect(func(): Audio.play_ui("hub_dock"))
	refresh()
