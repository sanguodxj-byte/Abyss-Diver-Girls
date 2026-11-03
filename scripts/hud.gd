extends CanvasLayer
## 行动界面：机甲状态卡、武装卡、雷达、目标、撤离读条、搜刮面板、暂停菜单。

const UI = preload("res://scripts/ui.gd")
const HL = preload("res://scripts/hud_l.gd")
const RadioWindow = preload("res://scripts/story/radio_window.gd")

var raid
var root: Control
# L 形状态栏
var holo
var ammo_cols := {}
var skill_slots := {}
var info_lbl: Label
var ammo_lbls := {}
var energy_strip
var frame_lbl: Label
var hp_bar
var en_bar
var cargo_bar
var hp_val: Label
var en_val: Label
var cargo_val: Label
var warn_lbl: Label
# 顶部
var time_lbl: Label
var search_lbl: Label
var kills_lbl: Label
# 右上
var radar
var obj_box: VBoxContainer
# 武装
var weapon_cards := {}
var item_cards := {}
# 中央
var extract_panel: PanelContainer
var extract_bar: ProgressBar
var extract_lbl: Label
var prompt_panel: PanelContainer
var prompt_lbl: Label
var log_box: VBoxContainer
var vignette: TextureRect
var markers := {}
var crosshair
var bigmap
# 搜刮
var loot_panel: PanelContainer
var box_list: ItemList
var cargo_list: ItemList
var box_title: Label
var cargo_title: Label
var search_bar: ProgressBar
var pause_panel: PanelContainer
var hurt_t := 0.0
var smoke_rect: ColorRect
var last_toggle_frame := -1
var radio                       ## 无线电通讯小窗：剧情流程在行动中把通讯推到它上面


# ---- 结算界面与机库共用的样式与标签工厂 ----
static func style(bg := UI.BG, border := UI.LINE) -> StyleBoxFlat:
	return UI.box(bg, border, 1, 2, UI.ACCENT_DIM, 3, 16)


static func label(text := "", size := 16, c := UI.TEXT) -> Label:
	return UI.label(text, size, c, true)


func setup(r) -> void:
	raid = r
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = UI.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 受伤/应急暗角
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0.8, 0, 0, 0), Color(0.8, 0, 0, 0.0), Color(0.45, 0.02, 0.0, 0.7)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 0.5)
	gt.width = 256
	gt.height = 256
	vignette = TextureRect.new()
	vignette.texture = gt
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	# 项目全局 canvas 过滤是 Nearest：64×64 渐变被拉到全屏会变成 20×11 像素的半透明方格（战斗中受伤暗角亮起时最明显），这里必须线性过滤
	vignette.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate.a = 0.0
	# 常驻暗角（压暗四周，把视线收到画面中央），放在受伤暗角之下
	var g2 := Gradient.new()
	g2.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g2.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.0), Color(0.02, 0.02, 0.02, 0.78)])
	var gt2 := GradientTexture2D.new()
	gt2.gradient = g2
	gt2.fill = GradientTexture2D.FILL_RADIAL
	gt2.fill_from = Vector2(0.5, 0.5)
	gt2.fill_to = Vector2(1.08, 0.5)
	gt2.width = 256
	gt2.height = 256
	var vig2 := TextureRect.new()
	vig2.texture = gt2
	vig2.stretch_mode = TextureRect.STRETCH_SCALE
	vig2.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vig2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vig2)
	# 战场烟尘：屏幕空间飘移的大团烟雾（低透明度、随相机世界位置偏移，避免贴在屏幕上不动）
	smoke_rect = ColorRect.new()
	smoke_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	smoke_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec2 cam_off = vec2(0.0);
uniform vec4 tint : source_color = vec4(0.66, 0.63, 0.56, 1.0);
uniform float strength = 0.34;
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
float fbm(vec2 p){ float v = 0.0; float a = 0.5; for (int k = 0; k < 5; k++){ v += a*n(p); p *= 2.03; a *= 0.5; } return v; }
void fragment(){
	vec2 uv = UV * vec2(1.78, 1.0) * 2.2 + cam_off;
	float t = TIME * 0.025;
	float c = fbm(uv + vec2(t, t*0.4));
	c = fbm(uv * 0.6 + vec2(c * 1.6, -t));
	float m = smoothstep(0.42, 0.78, c);
	COLOR = vec4(tint.rgb, m * strength);
}
"""
	sm.shader = sh
	smoke_rect.material = sm
	root.add_child(smoke_rect)
	root.add_child(vignette)

	_build_status()
	_build_top()
	_build_radar()
	_build_weapons()
	_build_center()
	_build_loot_panel()
	_build_pause_panel()

	bigmap = UI.BigMap.new()
	bigmap.raid = raid
	bigmap.z_index = 60
	root.add_child(bigmap)
	if not InputMap.has_action("map"):
		InputMap.add_action("map")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_M
		InputMap.action_add_event("map", ev)

	crosshair = UI.Crosshair.new()
	crosshair.mech = raid.mech
	root.add_child(crosshair)
	# 无线电小窗：左上角空白处，压在左下 L 形状态栏、右上雷达、右下消耗品卡之外，整块不接收鼠标
	radio = RadioWindow.new()
	radio.z_index = 20
	root.add_child(radio)
	Story.attach_radio(radio)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _exit_tree() -> void:
	if radio != null and is_instance_valid(radio):
		Story.detach_radio(radio)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ============================================================ 构建
func _build_status() -> void:
	# 左下角 L：拐角（全息投影）+ 竖线（子弹栏）+ 横线（技能栏）
	var m = raid.mech
	var L := Control.new()
	L.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	L.offset_left = 14
	L.offset_bottom = -14
	L.offset_top = -14 - 560
	L.offset_right = 14 + 620
	L.mouse_filter = Control.MOUSE_FILTER_IGNORE
	L.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(L)
	var CH := 168.0  # 拐角面板边长
	var base_y := 560.0 - CH
	# 竖轨（子弹栏）：贴在拐角上方
	var rail_w := 100.0
	var rail_h := 230.0
	var rv := TextureRect.new()
	rv.texture = UI.tex("rail_v")
	rv.stretch_mode = TextureRect.STRETCH_TILE
	rv.position = Vector2(10, base_y - rail_h + 6)
	rv.size = Vector2(76, rail_h)
	rv.scale = Vector2(rail_w / 76.0, 1.0)
	rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	L.add_child(rv)
	var cap := TextureRect.new()
	cap.texture = UI.tex("rail_v_cap")
	cap.position = Vector2(10, base_y - rail_h - 20)
	cap.size = Vector2(76, 26)
	cap.scale = Vector2(rail_w / 76.0, 1.0)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	L.add_child(cap)
	var k := rail_w / 76.0
	var i := 0
	for slot in ["arm_l", "arm_r"]:
		var col = HL.AmmoColumn.new()
		var cx: float = 10.0 + (20.0 if i == 0 else 56.0) * k
		col.position = Vector2(cx - 15.0 * k, base_y - rail_h + 8)
		col.size = Vector2(30.0 * k, rail_h - 4)
		col.bw = 30.0 * k - 4.0
		L.add_child(col)
		col.setup(m, slot)
		ammo_cols[slot] = col
		var al := UI.label("", 12, Color(0.75, 0.64, 0.36), true)
		al.position = Vector2(cx - 22, base_y - rail_h - 44)
		al.size = Vector2(44, 16)
		al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		L.add_child(al)
		ammo_lbls[slot] = al
		i += 1
	var lr := UI.label("L        R", 11, UI.MUTED, true)
	lr.position = Vector2(10 + 20 * k - 4, base_y - rail_h - 60)
	L.add_child(lr)
	# 横轨（技能栏）：从拐角右侧伸出
	var keys := [["space", "SPACE"], ["f", "F"], ["e", "E"], ["r", "R"]]
	var sw := 92.0
	var rh := TextureRect.new()
	rh.texture = UI.tex("rail_h")
	rh.stretch_mode = TextureRect.STRETCH_TILE
	rh.position = Vector2(CH - 8, 560 - 104)
	rh.size = Vector2(sw * keys.size() + 18, 88)
	rh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	L.add_child(rh)
	var hc := TextureRect.new()
	hc.texture = UI.tex("rail_h_cap")
	hc.position = rh.position + Vector2(rh.size.x, 0)
	hc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	L.add_child(hc)
	for j in keys.size():
		var ss = HL.SkillSlot.new()
		ss.position = rh.position + Vector2(12 + j * sw, -18)
		ss.size = Vector2(sw - 4, 100)
		L.add_child(ss)
		ss.setup(m, keys[j][0], keys[j][1])
		skill_slots[keys[j][0]] = ss
	energy_strip = HL.EnergyStrip.new()
	energy_strip.mech = m
	energy_strip.position = rh.position + Vector2(4, 88 - 13)
	energy_strip.size = Vector2(rh.size.x - 8, 6)
	energy_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	L.add_child(energy_strip)
	# 拐角：底板 + 全息投影 + 读数
	var cr := TextureRect.new()
	cr.texture = UI.tex("corner")
	cr.position = Vector2(0, base_y)
	cr.scale = Vector2(CH / cr.texture.get_width(), CH / cr.texture.get_height())
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	L.add_child(cr)
	holo = HL.HoloPortrait.new()
	holo.position = Vector2(12, base_y + 18)
	holo.size = Vector2(CH - 24, 100)
	L.add_child(holo)
	holo.setup(m)
	var core_id: String = raid.loadout.get("core", "")
	frame_lbl = UI.label((GameData.item_name(core_id) if core_id != "" else "无躯干"), 11, Color(0.74, 0.58, 0.28))
	frame_lbl.position = Vector2(22, base_y + 1)
	L.add_child(frame_lbl)
	info_lbl = UI.label("", 12, UI.TEXT)
	info_lbl.position = Vector2(14, base_y + CH - 46)
	info_lbl.size = Vector2(CH - 24, 38)
	info_lbl.add_theme_constant_override("line_spacing", -2)
	L.add_child(info_lbl)
	warn_lbl = UI.label("", 13, UI.EN_C, true)
	warn_lbl.position = Vector2(118, base_y - 22)
	L.add_child(warn_lbl)


func _build_top() -> void:
	var p := UI.panel(10, false)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	p.offset_top = 14
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.visible = false  # 顶部计时/搜刮/击杀面板不显示；节点保留，refresh() 仍更新其中的标签
	root.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	p.add_child(h)
	time_lbl = UI.label("00:00", 22, Color(1, 0.92, 0.8))
	h.add_child(time_lbl)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	h.add_child(tv)
	tv.add_child(UI.label("已搜刮", 11, UI.MUTED))
	search_lbl = UI.label("0", 16, UI.TEXT)
	tv.add_child(search_lbl)
	var kv := VBoxContainer.new()
	kv.add_theme_constant_override("separation", 0)
	h.add_child(kv)
	kv.add_child(UI.label("击杀", 11, UI.MUTED))
	kills_lbl = UI.label("0", 16, UI.TEXT)
	kv.add_child(kills_lbl)


func _build_radar() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	v.offset_right = -18
	v.offset_top = 14
	v.offset_left = -258
	v.add_theme_constant_override("separation", 8)
	root.add_child(v)
	radar = UI.Radar.new()
	radar.raid = raid
	radar.custom_minimum_size = Vector2(190, 190)
	radar.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.add_child(radar)
	var p := UI.panel(10)
	v.add_child(p)
	obj_box = VBoxContainer.new()
	obj_box.add_theme_constant_override("separation", 4)
	p.add_child(obj_box)


func _card(key: String, title: String, w := 118.0) -> Dictionary:
	var p := UI.panel(8, false)
	p.custom_minimum_size = Vector2(w, 58)
	var ov := Control.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	h.add_child(UI.keycap(key, 12))
	var t := UI.label(title, 13, UI.TEXT)
	t.clip_text = true
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var sub := UI.label("", 12, UI.MUTED)
	v.add_child(sub)
	var cd = UI.CooldownTile.new()
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_child(cd)
	return {"panel": p, "title": t, "sub": sub, "cd": cd}


func _build_weapons() -> void:
	# 消耗品：右下角小卡（贴图面板 + 键帽）
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	h.offset_right = -18
	h.offset_bottom = -18
	h.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	h.grow_vertical = Control.GROW_DIRECTION_BEGIN
	h.add_theme_constant_override("separation", 8)
	root.add_child(h)
	for kk in [["1", "燃料电池", "fuel_cell"], ["2", "维修包", "repair_kit"], ["T", "信标", "beacon"]]:
		var c := _card(kk[0], kk[1], 104)
		h.add_child(c.panel)
		item_cards[kk[2]] = c
	var hint := UI.label("", 12, UI.MUTED, true)
	hint.visible = false
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_right = -20
	hint.offset_bottom = -88
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(hint)


func _build_center() -> void:
	extract_panel = UI.panel(12)
	extract_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	extract_panel.offset_top = 110
	extract_panel.custom_minimum_size = Vector2(420, 0)
	extract_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	extract_panel.visible = false
	root.add_child(extract_panel)
	var ev := VBoxContainer.new()
	extract_panel.add_child(ev)
	extract_lbl = UI.label("", 17, UI.GOOD)
	extract_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev.add_child(extract_lbl)
	extract_bar = ProgressBar.new()
	extract_bar.show_percentage = false
	extract_bar.custom_minimum_size = Vector2(0, 10)
	extract_bar.add_theme_stylebox_override("fill", UI.tex9("bar_fill9", 4, 0))
	ev.add_child(extract_bar)

	prompt_panel = PanelContainer.new()
	prompt_panel.add_theme_stylebox_override("panel", UI.tex9("prompt9", 10, 12))
	prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt_panel.offset_top = 70
	prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_panel.visible = false
	root.add_child(prompt_panel)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 8)
	prompt_panel.add_child(ph)
	ph.add_child(UI.keycap("G", 14))
	prompt_lbl = UI.label("", 16, Color(1, 0.92, 0.75))
	ph.add_child(prompt_lbl)

	log_box = VBoxContainer.new()
	log_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	log_box.offset_left = 18
	log_box.offset_left = 140
	log_box.offset_bottom = -420
	log_box.offset_top = -620
	log_box.offset_right = 700
	log_box.alignment = BoxContainer.ALIGNMENT_END
	log_box.add_theme_constant_override("separation", 4)
	log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(log_box)


func _build_loot_panel() -> void:
	loot_panel = UI.panel(18)
	loot_panel.z_index = 30   # 盖住世界里投影出来的撤离点指示标签（它们在面板之后加入，默认会画在面板上面）
	loot_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	loot_panel.custom_minimum_size = Vector2(780, 420)
	loot_panel.offset_left = -390
	loot_panel.offset_right = 390
	loot_panel.offset_top = -230
	loot_panel.offset_bottom = 190
	loot_panel.visible = false
	root.add_child(loot_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	loot_panel.add_child(v)
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 18)
	v.add_child(h)
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 6)
	h.add_child(lv)
	var bh := UI.header("容器")
	box_title = bh.get_child(1)
	lv.add_child(bh)
	search_bar = ProgressBar.new()
	search_bar.show_percentage = false
	search_bar.custom_minimum_size = Vector2(0, 4)
	lv.add_child(search_bar)
	box_list = ItemList.new()
	box_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box_list.max_text_lines = 2
	box_list.fixed_icon_size = Vector2i(20, 20)
	box_list.item_clicked.connect(func(i, _p, _b): raid.take_from_box(i))
	lv.add_child(box_list)
	var arrow := UI.label("⇄", 26, UI.ACCENT)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(arrow)
	var rv := VBoxContainer.new()
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rv.add_theme_constant_override("separation", 6)
	h.add_child(rv)
	var ch := UI.header("货舱")
	cargo_title = ch.get_child(1)
	rv.add_child(ch)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 4)
	rv.add_child(sp)
	cargo_list = ItemList.new()
	cargo_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cargo_list.max_text_lines = 2
	cargo_list.fixed_icon_size = Vector2i(20, 20)
	cargo_list.item_clicked.connect(func(i, _p, _b): raid.put_into_box(i))
	rv.add_child(cargo_list)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	v.add_child(foot)
	var fs := Control.new()
	fs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(fs)
	foot.add_child(UI.keycap("G"))
	foot.add_child(UI.label("/", 13, UI.MUTED))
	foot.add_child(UI.keycap("Esc"))
	foot.add_child(UI.label("关闭", 13, UI.MUTED))


func _build_pause_panel() -> void:
	pause_panel = UI.panel(20)
	pause_panel.z_index = 40   # 同上：暂停时盖住世界里的指示标签
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.custom_minimum_size = Vector2(360, 0)
	pause_panel.offset_left = -180
	pause_panel.offset_right = 180
	pause_panel.offset_top = -110
	pause_panel.visible = false
	root.add_child(pause_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pause_panel.add_child(v)
	v.add_child(UI.header("行动暂停", "", 20))
	var b1 := Button.new()
	b1.text = "继续行动"
	b1.custom_minimum_size = Vector2(0, 40)
	b1.set_meta("sfx", "")   # toggle_pause 自己播放关闭音效
	b1.pressed.connect(toggle_pause)
	v.add_child(b1)
	var b2 := Button.new()
	b2.text = "放弃行动（失去机甲与货物）"
	b2.custom_minimum_size = Vector2(0, 40)
	b2.set_meta("sfx", "ui_confirm")
	b2.add_theme_color_override("font_color", UI.BAD)
	b2.pressed.connect(func():
		pause_panel.visible = false
		raid.abandon())
	v.add_child(b2)


# ============================================================ 交互
func toggle_pause() -> void:
	last_toggle_frame = Engine.get_process_frames()
	pause_panel.visible = not pause_panel.visible
	get_tree().paused = pause_panel.visible
	Audio.play_ui("ui_open" if pause_panel.visible else "ui_close")
	_update_cursor()


func map_open() -> bool:
	return bigmap != null and bigmap.visible


func toggle_map() -> void:
	if pause_panel.visible or loot_panel.visible or raid.ended:
		return
	bigmap.visible = not bigmap.visible
	Audio.play_ui("ui_open" if bigmap.visible else "ui_close")
	last_toggle_frame = Engine.get_process_frames()
	_update_cursor()


func _update_cursor() -> void:
	var ui_open: bool = pause_panel.visible or loot_panel.visible or raid.ended or map_open()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if ui_open else Input.MOUSE_MODE_HIDDEN
	crosshair.visible = not ui_open


func _unhandled_input(event: InputEvent) -> void:
	if pause_panel.visible and event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func msg(t: String) -> void:
	if log_box == null:
		return
	var p := PanelContainer.new()
	var sb := UI.tex9("strip9" if not t.begins_with("▲") else "strip9_warn", 8, 10)
	sb.content_margin_left = 16
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UI.label(t, 15, UI.TEXT)
	p.add_child(l)
	log_box.add_child(p)
	while log_box.get_child_count() > 5:
		log_box.get_child(0).free()
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(6.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.8)
	tw.tween_callback(p.queue_free)


func hurt() -> void:
	hurt_t = 0.35


func set_prompt(t: String) -> void:
	prompt_panel.visible = t != ""
	prompt_lbl.text = t.replace("[G] ", "")


func _fmt_time(t: float) -> String:
	return "%02d:%02d" % [int(t) / 60, int(t) % 60]


## 性能：文字/列表类信息 10 Hz 刷新即可，暗角、标记、准星仍逐帧更新。
## 原来每帧给 warn_lbl 重设颜色覆盖会触发主题变更通知和重新排版，是 HUD 最大的开销。
const TEXT_HZ := 10.0
var _text_t := 0.0

func _set_font_color(l: Label, c: Color) -> void:
	if not l.has_meta("fc") or l.get_meta("fc") != c:
		l.set_meta("fc", c)
		l.add_theme_color_override("font_color", c)


func refresh() -> void:
	var m = raid.mech
	if m == null:
		return
	_text_t -= get_process_delta_time()
	if _text_t <= 0.0:
		_text_t = 1.0 / TEXT_HZ
		_refresh_text(m)
	_refresh_fast(m)


func _refresh_text(m) -> void:
	info_lbl.text = "结构 %d%%   能源 %s\n货舱 %.0f/%.0f" % [int(m.hp / m.max_hp * 100.0), _fmt_time(m.energy_seconds_left()), m.cargo_weight(), m.cargo_cap()]
	for slot in ammo_lbls:
		var id: String = m.loadout.get(slot, "")
		ammo_lbls[slot].text = "—" if id == "" else ("∞" if m.overdrive_t > 0.0 else "%d" % m.ammo[slot])
	var sf: float = m.speed_mult()
	if m.emergency > 0.0:
		warn_lbl.text = "▲ 动力炉断电 · 应急电源剩余 %.1f 秒" % m.emergency
		_set_font_color(warn_lbl, UI.BAD)
	elif sf < 0.99:
		warn_lbl.text = "超载减速 %d%% · 货物价值 ¥%d" % [int((1.0 - sf) * 100.0), GameData.value_of(m.cargo)]
		_set_font_color(warn_lbl, UI.EN_C)
	else:
		warn_lbl.text = "货物价值 ¥%d" % GameData.value_of(m.cargo)
		_set_font_color(warn_lbl, UI.MUTED)

	time_lbl.text = _fmt_time(raid.time)
	var sc: Vector2i = raid.searched_count()
	search_lbl.text = "%d / %d" % [sc.x, sc.y]
	kills_lbl.text = str(raid.kills)

	# 目标列表
	var lines: Array = []
	for z in raid.extracts:
		lines.append([z.title, "%dm" % int(z.global_position.distance_to(m.global_position)), UI.GOOD])
	match raid.transport_state:
		"none":
			lines.append(["运输机：待命", "信标 ×%d" % m.cargo.count("beacon"), UI.MUTED])
		"incoming":
			lines.append(["运输机抵达倒计时", "%ds" % int(raid.transport_t), UI.EN_C])
		"landed":
			lines.append(["运输机已着陆 · %ds 后起飞" % int(raid.transport_t), "%dm" % int(raid.transport_zone.global_position.distance_to(m.global_position)), UI.EN_C])
		"gone":
			lines.append(["运输机已离开", "", UI.MUTED])
	while obj_box.get_child_count() < lines.size():
		var h := HBoxContainer.new()
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(6, 6)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(dot)
		var a := UI.label("", 13)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(UI.label("", 13, UI.MUTED))
		h.add_theme_constant_override("separation", 8)
		obj_box.add_child(h)
	for i in obj_box.get_child_count():
		var h: HBoxContainer = obj_box.get_child(i)
		h.visible = i < lines.size()
		if h.visible:
			h.get_child(0).color = lines[i][2]
			h.get_child(1).text = lines[i][0]
			h.get_child(2).text = lines[i][1]

	for id in item_cards.keys():
		var c: Dictionary = item_cards[id]
		var n: int = m.cargo.count(id)
		c.sub.text = "×%d" % n
		c.panel.modulate.a = 1.0 if n > 0 else 0.45


func _refresh_fast(m) -> void:
	# 撤离读条
	if raid.extract_target and not raid.ended:
		extract_panel.visible = true
		extract_lbl.text = "正在撤离 · %s" % raid.extract_target.title
		extract_bar.max_value = raid.extract_target.need
		extract_bar.value = raid.extract_progress
	else:
		extract_panel.visible = false

	var danger := 0.0
	if m.emergency > 0.0:
		danger = 0.5 + 0.3 * sin(Time.get_ticks_msec() * 0.01)
	hurt_t = max(0.0, hurt_t - get_process_delta_time())
	vignette.modulate.a = max(danger * 0.45, hurt_t * 1.2)
	if smoke_rect and raid.camera:
		var cp: Vector3 = raid.camera.global_position
		(smoke_rect.material as ShaderMaterial).set_shader_parameter("cam_off", Vector2(cp.x, cp.z) * 0.045)
	_update_markers()
	_update_cursor()


func _update_markers() -> void:
	var cam: Camera3D = raid.camera
	var vp := root.get_viewport_rect().size
	var targets: Array = raid.extracts.duplicate()
	if raid.transport_zone and raid.transport_zone.active:
		targets.append(raid.transport_zone)
	for z in targets:
		if not markers.has(z):
			var l := UI.label("", 14, z.color, true)
			root.add_child(l)
			markers[z] = l
		var l: Label = markers[z]
		var p: Vector3 = z.global_position + Vector3(0, 1, 0)
		var behind := cam.is_position_behind(p)
		var sp := cam.unproject_position(p)
		var safe := Rect2(Vector2(140, 100), vp - Vector2(140 + 300, 100 + 300))  # 避开左下 L 形状态栏与右上雷达
		var on := not behind and Rect2(Vector2.ZERO, vp).has_point(sp)
		l.visible = not on and not map_open()
		if not on:
			var c := safe.get_center()
			var d := sp - c
			if behind:
				d = -d
			var half := safe.size * 0.5
			var k: float = min(half.x / max(abs(d.x), 0.01), half.y / max(abs(d.y), 0.01))
			var pos: Vector2 = c + d * min(k, 1.0)
			var arrow := "▲" if d.y < -abs(d.x) else ("▼" if d.y > abs(d.x) else ("◀" if d.x < 0 else "▶"))
			l.text = "%s %s %dm" % [arrow, z.title.split(" ")[0], int(z.global_position.distance_to(raid.mech.global_position))]
			l.position = pos - l.size * 0.5
	for z in markers.keys():
		if not is_instance_valid(z) or not z.active:
			markers[z].visible = false


func open_loot(_b) -> void:
	loot_panel.visible = true
	_update_cursor()
	refresh_loot()


func close_loot() -> void:
	loot_panel.visible = false
	_update_cursor()


func _process(_d: float) -> void:
	if loot_panel and loot_panel.visible and raid.open_box and is_instance_valid(raid.open_box):
		var b = raid.open_box
		if b.revealed < b.items.size():
			search_bar.max_value = 1.0
			search_bar.value = b.reveal_t / 0.55
			search_bar.modulate.a = 1.0
		else:
			search_bar.modulate.a = 0.0


func refresh_loot() -> void:
	var b = raid.open_box
	if b == null:
		return
	box_title.text = b.title + ("  · 搜索中…" if b.revealed < b.items.size() else "")
	box_list.clear()
	for i in b.items.size():
		if i < b.revealed:
			var it := GameData.item(b.items[i])
			var idx := box_list.add_item("%s    %s · %.1fkg · ¥%d" % [it.name, GameData.CAT_NAMES.get(it.cat, ""), it.w, it.v], UI.rarity_icon(int(it.rar), it.cat))
			box_list.set_item_custom_fg_color(idx, GameData.RARITY_COLORS[int(it.rar)])
		else:
			var idx := box_list.add_item("？？？    正在摸索暗格……", UI.rarity_icon(0, ""))
			box_list.set_item_custom_fg_color(idx, Color(0.45, 0.45, 0.48))
	var m = raid.mech
	cargo_title.text = "货舱  %.1f / %.0f kg" % [m.cargo_weight(), m.cargo_cap()]
	cargo_list.clear()
	for i in m.cargo.size():
		var it := GameData.item(m.cargo[i])
		var idx := cargo_list.add_item("%s    %s · %.1fkg · ¥%d" % [it.name, GameData.CAT_NAMES.get(it.cat, ""), it.w, it.v], UI.rarity_icon(int(it.rar), it.cat))
		cargo_list.set_item_custom_fg_color(idx, GameData.RARITY_COLORS[int(it.rar)])
