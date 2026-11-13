extends Control
## 主菜单：贴着飞空艇舷窗俯瞰——伪天空盒 + 3D 云海层 + 云下真实 3D 城市遗迹（楼体取自战区地图）+ 标题 + 核心按钮
signal start_requested

const A = preload("res://scripts/art.gd")
const UI = preload("res://scripts/ui.gd")
const MV = preload("res://scripts/mech_visual.gd")
const Growth = preload("res://scripts/progression/growth.gd")

const MenuShip = preload("res://scripts/menu_ship.gd")

var cam: Camera3D
var toon: Node
var menu_env: Environment
var t := 0.0
var refs := {}
var settings_panel: PanelContainer
var start_panel: PanelContainer
var _dlg_name: LineEdit
var buttons: Array = []
var post_mat: ShaderMaterial


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	# 按窗口真实像素渲染（原来固定 1280×720 再放大，高分屏发糊）
	var svc := UI.HiResView.new()
	add_child(svc)
	var sv: SubViewport = svc.sv
	sv.msaa_3d = Viewport.MSAA_4X
	sv.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_build_scene(sv)
	_build_ui()


func _build_scene(sv: SubViewport) -> void:
	var root := Node3D.new()
	sv.add_child(root)
	# 伪天空盒：黄昏云海 + 云缝下依稀可见的废土（menu_sky.gdshader）
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/menu_sky.gdshader")
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.38
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.tonemap_white = 8.0
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# 舱内体积雾：只在近处，阳光穿窗形成光柱（天空不受影响）
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(1.0, 0.85, 0.7)
	env.volumetric_fog_anisotropy = 0.75
	env.volumetric_fog_length = 14.0
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.95
	we.environment = env
	menu_env = env
	root.add_child(we)
	# 太阳：低悬在窗外右前方，穿过窗框把竖梃影子投进舱内
	var L := Vector3(0.5, 0.24, -1.0).normalized()
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.72, 0.46)
	sun.light_energy = 2.4
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.light_angular_distance = 0.6
	sun.light_volumetric_fog_energy = 4.0
	sun.directional_shadow_max_distance = 30.0
	root.add_child(sun)
	sun.basis = Basis.looking_at(-L, Vector3.UP)
	# 云下城市（真实 3D 楼体 + 3D 云海层）
	var city := preload("res://scripts/menu_city.gd").new()
	root.add_child(city)
	city.setup(sky.sky_material, L)
	refs = MenuShip.build(root)
	cam = Camera3D.new()
	cam.fov = 62
	cam.near = 0.03
	cam.far = 40000.0
	var ca := CameraAttributesPractical.new()
	ca.dof_blur_near_enabled = true
	ca.dof_blur_near_distance = 0.35
	ca.dof_blur_near_transition = 0.4
	ca.dof_blur_amount = 0.04
	cam.attributes = ca
	root.add_child(cam)
	cam.current = true
	# 舱内浮尘（被阳光照亮）
	A.emitter(root, Vector3(1.0, 1.8, 1.4), {"amount": 90, "life": 9.0, "size": 0.012, "box": Vector3(4.5, 2.2, 1.8), "dir": Vector3(-1, 0.1, 0.2),
		"spread": 60.0, "vmin": 0.03, "vmax": 0.08, "gravity": Vector3(0, -0.005, 0), "c0": Color(1.0, 0.85, 0.65, 0.0), "cmid": Color(1.0, 0.88, 0.7, 0.7),
		"c1": Color(1.0, 0.85, 0.65, 0.0), "grow0": 1.0, "grow1": 1.0, "additive": true})
	toon = preload("res://scripts/toon.gd").attach(root, menu_env, cam, GameData.render_style == 1)


const POST := """
shader_type canvas_item;
uniform float t = 0.0;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment(){
	vec2 uv = UV - 0.5;
	float vig = smoothstep(0.35, 0.95, length(uv * vec2(1.25, 1.0)));
	float grain = (h(UV * 900.0 + t) - 0.5) * 0.05;
	float bars = step(0.5 - 0.045, abs(uv.y));
	COLOR = vec4(vec3(grain * 0.5), clamp(vig * 0.65 + abs(grain), 0.0, 1.0));
	COLOR = mix(COLOR, vec4(0.0, 0.0, 0.0, 1.0), bars);
}
"""


func _build_ui(reopen_settings := false, settings_tab := "video") -> void:
	if ui_root != null and is_instance_valid(ui_root):
		remove_child(ui_root)
		ui_root.queue_free()
	buttons.clear()
	readout_lbls.clear()
	sel = -1
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)

	var post := ColorRect.new()
	post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = POST
	post_mat = ShaderMaterial.new()
	post_mat.shader = sh
	post.material = post_mat
	ui_root.add_child(post)

	# 左侧压暗：只压文字区，窗外场景大部分保留
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0.02, 0.025, 0.03, 0.88), Color(0.02, 0.025, 0.03, 0.5), Color(0.02, 0.025, 0.03, 0.0)])
	gt.gradient = g
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	grad.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	grad.offset_right = 780
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(grad)

	# 取景框角标 + 菜单游标（自绘）
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	ui_root.add_child(hud)

	# 标题：生成的金属艺术字（中文 / 英文两版），带投影
	title_rect = TextureRect.new()
	title_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	title_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 标题按最近邻取样，配合 shader 的像素块量化
	var tsh := Shader.new()
	tsh.code = TITLE_FX
	title_mat = ShaderMaterial.new()
	title_mat.shader = tsh
	title_rect.material = title_mat
	ui_root.add_child(title_rect)
	title_lang = Loc.lang
	_apply_title_lang()

	# 菜单
	menu_box = VBoxContainer.new()
	menu_box.position = Vector2(96, 330)
	menu_box.add_theme_constant_override("separation", 0)
	ui_root.add_child(menu_box)
	var has_save := FileAccess.file_exists(GameData.save_path)
	var en := Loc.is_en()
	var items := [
		["New Game" if en else "新的游戏", "", func(): _open_start(), "", false],
		["Continue" if en else "载入游戏", ("" if has_save else ("NO SAVE" if en else "无存档")), func(): _load_game(), "", not has_save],
		["Settings" if en else "游戏设置", "", func(): _toggle_settings(), "", false],
		["Quit" if en else "退出游戏", "", func(): get_tree().quit(), "ui_cancel", false]
	]
	for i in items.size():
		var it: Array = items[i]
		var mb := _menu_button(i, it[0], it[1], it[2], it[4])
		mb.set_meta("sfx", it[3])
		mb.set_meta("sfx_hover", "")
		menu_box.add_child(mb)

	# 左下：舱内仪表读数
	var readout := HBoxContainer.new()
	readout.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	readout.offset_left = 96
	readout.offset_top = -92
	readout.offset_bottom = -64
	readout.add_theme_constant_override("separation", 28)
	ui_root.add_child(readout)
	status_dot = UI.label("●", 12, UI.GOOD)
	var live := HBoxContainer.new()
	live.add_theme_constant_override("separation", 6)
	live.add_child(status_dot)
	live.add_child(_spaced(UI.label(Loc.t("链路在线", "LINK ONLINE"), 12, Color(1, 1, 1, 0.7)), 1))
	readout.add_child(live)
	var min_w := [52.0, 66.0, 44.0, 96.0]
	var readout_def := [
		[Loc.t("高度", "ALT"), "260 m"],
		[Loc.t("航速", "SPD"), "6.5 m/s"],
		[Loc.t("航向", "HDG"), "074°"],
		[Loc.t("云层", "CLOUD"), "-165 ~ -15 m"],
	]
	for i in readout_def.size():
		var cell := _readout(readout_def[i][0], readout_def[i][1])
		readout.add_child(cell)
		var val: Label = cell.get_child(1)
		val.custom_minimum_size.x = min_w[i]
		readout_lbls.append(val)

	# 弹窗遮罩
	shade = ColorRect.new()
	shade.color = Color(0.01, 0.012, 0.015, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.visible = false
	shade.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close_dialogs())
	ui_root.add_child(shade)

	_build_settings(settings_tab)
	_build_start_panel()
	if reopen_settings:
		settings_panel.visible = true
		shade.visible = true
	_select(0, false)


## ---------- 小部件 ----------
func _spaced(l: Label, px: int) -> Label:
	var fv := FontVariation.new()
	fv.base_font = l.get_theme_font("font")
	fv.spacing_glyph = px
	l.add_theme_font_override("font", fv)
	return l


func _tag_label(text: String, c: Color) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.px9("card9", 8, 8, 8, 2, Color(c.r, c.g, c.b, 0.9)))
	pc.add_child(_spaced(UI.label(text, 12, c), 1))
	return pc


func _readout(k: String, v: String) -> Control:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", -2)
	b.add_child(_spaced(UI.label(k, 11, Color(1, 1, 1, 0.42)), 2))
	b.add_child(UI.label(v, 14, Color(1, 1, 1, 0.82)))
	return b


## 仪表读数低频漂移：每个数值在基准附近小幅随机，模拟舱内实时遥测
func _tick_readout() -> void:
	if readout_lbls.size() < 4:
		return
	var alt := 260.0 + randf_range(-3.0, 3.0)
	var spd := 6.5 + randf_range(-0.35, 0.35)
	var hdg := fposmod(74.0 + randf_range(-2.0, 2.0), 360.0)
	var c0 := -165.0 + randf_range(-6.0, 6.0)
	var c1 := -15.0 + randf_range(-6.0, 6.0)
	readout_lbls[0].text = "%d m" % roundi(alt)
	readout_lbls[1].text = "%.1f m/s" % spd
	readout_lbls[2].text = "%03d°" % int(round(hdg))
	readout_lbls[3].text = "%d ~ %d m" % [roundi(c0), roundi(c1)]


func _keycap(key: String, what: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.px9("card9", 6, 6, 10, 3))
	pc.add_child(UI.label(key, 12, UI.GOLD))
	h.add_child(pc)
	h.add_child(UI.label(what, 12, Color(0.86, 0.84, 0.78, 0.78)))
	return h


func _menu_button(idx: int, text: String, sub: String, cb: Callable, disabled: bool = false) -> Control:
	var b := Button.new()
	b.flat = true
	b.custom_minimum_size = Vector2(420, 58)
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = disabled
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -18
	row.add_theme_constant_override("separation", 16)
	b.add_child(row)
	var num := _spaced(UI.label("%02d" % (idx + 1), 12, Color(1, 1, 1, 0.35)), 1)
	num.custom_minimum_size = Vector2(22, 0)
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.size_flags_vertical = Control.SIZE_FILL
	row.add_child(num)
	var l := UI.label(text, 25, UI.TEXT if not disabled else Color(1, 1, 1, 0.3))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var sl := _spaced(UI.label(sub, 11, Color(1, 1, 1, 0.3) if not disabled else Color(1, 0.55, 0.4, 0.55)), 2)
	sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sl.size_flags_vertical = Control.SIZE_FILL
	row.add_child(sl)
	b.set_meta("parts", [row, num, l, sl])
	b.set_meta("disabled", disabled)
	b.mouse_entered.connect(func(): _select(idx, true))
	if not disabled:
		b.pressed.connect(cb)
	buttons.append(b)
	return b


func _select(i: int, sfx: bool) -> void:
	if i < 0 or i >= buttons.size():
		return
	var changed := i != sel
	sel = i
	for k in buttons.size():
		var bb: Button = buttons[k]
		var parts: Array = bb.get_meta("parts")
		var on: bool = k == sel and not bool(bb.get_meta("disabled"))
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(parts[0], "offset_left", 30.0 if on else 18.0, 0.16)
		if not bb.get_meta("disabled"):
			(parts[2] as Label).add_theme_color_override("font_color", Color(1, 0.93, 0.8) if on else UI.TEXT)
			(parts[1] as Label).add_theme_color_override("font_color", UI.ACCENT if on else Color(1, 1, 1, 0.35))
	var target := float(sel) * 58.0
	if cur_tw:
		cur_tw.kill()
	cur_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	cur_tw.tween_property(self, "cur_y", target, 0.18 if sfx else 0.0)
	if sfx and changed and Audio.has_sfx("ui_hover"):
		Audio.play_ui("ui_hover")


var ui_root: Control
var hud: Control
var title_rect: TextureRect
var title_mat: ShaderMaterial
var title_lang := ""
const MENU_CFG := "user://menu.cfg"
const TITLE_FX := """
shader_type canvas_item;
// 标题：金属原图按 6×6 像素块取样（像素化），带下方柔和投影
uniform float block = 6.0;
void fragment() {
	vec2 g = TEXTURE_PIXEL_SIZE * block;
	vec2 quv = floor(UV / g) * g + g * 0.5;
	vec4 c = texture(TEXTURE, quv);
	vec2 px = TEXTURE_PIXEL_SIZE * vec2(6.0, 9.0);
	float sh = texture(TEXTURE, UV - px).a;
	vec4 shadow = vec4(0.0, 0.0, 0.0, sh * 0.45);
	COLOR = mix(shadow, vec4(c.rgb, 1.0), c.a);
}
"""


func _apply_title_lang() -> void:
	if title_lang == "":
		var loc := get_node_or_null("/root/Loc")
		title_lang = str(loc.get("lang")) if loc != null else ("zh" if OS.get_locale_language() == "zh" else "en")
	var zh := title_lang == "zh"
	title_rect.texture = load("res://assets/title_%s.png" % ("zh" if zh else "en"))
	var w := 560.0 if zh else 500.0
	var tsz: Vector2 = title_rect.texture.get_size()
	title_rect.position = Vector2(84, 300 - w * tsz.y / tsz.x - 24)
	title_rect.size = Vector2(w, w * tsz.y / tsz.x)
var menu_box: VBoxContainer
var status_dot: Label
var shade: ColorRect
var readout_lbls: Array[Label] = []
var readout_t := 0.0
var sel := -1
var cur_y := 0.0:
	set(v):
		cur_y = v
		if hud:
			hud.queue_redraw()
var cur_tw: Tween


func _draw_hud() -> void:
	var sz := hud.size
	var bar := sz.y * 0.045
	# 取景角标
	var m := 34.0
	var arm := 26.0
	var c := Color(1, 1, 1, 0.32)
	for corner in [Vector2(m, bar + m * 0.6), Vector2(sz.x - m, bar + m * 0.6), Vector2(m, sz.y - bar - m * 0.6), Vector2(sz.x - m, sz.y - bar - m * 0.6)]:
		var sx := 1.0 if corner.x < sz.x * 0.5 else -1.0
		var sy := 1.0 if corner.y < sz.y * 0.5 else -1.0
		hud.draw_line(corner, corner + Vector2(arm * sx, 0), c, 1.5)
		hud.draw_line(corner, corner + Vector2(0, arm * sy), c, 1.5)
	# 菜单分隔线 + 游标
	if menu_box == null or buttons.is_empty():
		return
	var o := menu_box.position
	for k in buttons.size() + 1:
		hud.draw_line(o + Vector2(0, k * 58.0), o + Vector2(420, k * 58.0), Color(1, 1, 1, 0.07 if k > 0 and k < buttons.size() else 0.14), 1.0)
	if sel >= 0 and not buttons[sel].get_meta("disabled"):
		var y := o.y + cur_y
		var sk := 14.0
		var pts := PackedVector2Array([Vector2(o.x, y + 1), Vector2(o.x + 420 + sk, y + 1), Vector2(o.x + 420, y + 57), Vector2(o.x, y + 57)])
		var cols := PackedColorArray([Color(1, 0.69, 0.13, 0.26), Color(1, 0.69, 0.13, 0.0), Color(1, 0.69, 0.13, 0.0), Color(1, 0.69, 0.13, 0.2)])
		hud.draw_polygon(pts, cols)
		hud.draw_rect(Rect2(o.x, y + 1, 4, 56), UI.ACCENT)
		# 右侧箭头
		var ax := o.x + 432.0
		var ay := y + 29.0
		hud.draw_colored_polygon(PackedVector2Array([Vector2(ax, ay - 6), Vector2(ax + 7, ay), Vector2(ax, ay + 6)]), UI.ACCENT)


## ---------- 弹窗 ----------
func _dialog(title: String, code: String) -> Array:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.px9("panel9", 16, 16, 18, 16))
	pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pc.custom_minimum_size = Vector2(490, 0)
	pc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pc.grow_vertical = Control.GROW_DIRECTION_BOTH
	pc.visible = false
	add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pc.add_child(v)
	v.add_child(UI.plate_header(title, code))
	v.add_child(UI.hazard_strip(8))
	return [pc, v]


func _dialog_to_ui(title: String, code: String) -> Array:
	var res := _dialog(title, code)
	var pc: PanelContainer = res[0]
	if ui_root != null and is_instance_valid(ui_root):
		remove_child(pc)
		ui_root.add_child(pc)
	return res


func _field_label(t: String) -> Label:
	return _spaced(UI.label(t, 12, UI.MUTED), 1)


func _btn(text: String, primary: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(140, 38)
	b.focus_mode = Control.FOCUS_NONE
	if primary:
		b.add_theme_stylebox_override("normal", UI.px9("btn9_main_n", 10, 10, 16, 6))
		b.add_theme_stylebox_override("hover", UI.px9("btn9_main_h", 10, 10, 16, 6))
		b.add_theme_stylebox_override("pressed", UI.px9("btn9_main_p", 10, 10, 16, 6))
		b.add_theme_stylebox_override("disabled", UI.px9("btn9_main_d", 10, 10, 16, 6))
		b.add_theme_color_override("font_color", Color(0.08, 0.06, 0.04))
		b.add_theme_color_override("font_hover_color", Color(0.08, 0.06, 0.04))
		b.add_theme_color_override("font_pressed_color", Color(0.08, 0.06, 0.04))
	else:
		b.add_theme_stylebox_override("normal", UI.px9("btn9_n", 10, 10, 16, 6))
		b.add_theme_stylebox_override("hover", UI.px9("btn9_h", 10, 10, 16, 6))
		b.add_theme_stylebox_override("pressed", UI.px9("btn9_p", 10, 10, 16, 6))
		b.add_theme_stylebox_override("disabled", UI.px9("btn9_d", 10, 10, 16, 6))
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(cb)
	return b


func _line_edit() -> LineEdit:
	var e := LineEdit.new()
	e.custom_minimum_size = Vector2(0, 40)
	e.add_theme_stylebox_override("normal", UI.px9("inset9", 6, 6, 12, 8))
	e.add_theme_stylebox_override("focus", UI.px9("card9_on", 8, 8, 12, 8))
	e.add_theme_font_size_override("font_size", 12)
	e.add_theme_color_override("caret_color", UI.ACCENT)
	return e


## 新的游戏：驾驶员登记
func _build_start_panel() -> void:
	var en := Loc.is_en()
	var d := _dialog_to_ui(Loc.t("驾驶员登记", "Pilot Registration"), "// 01")
	start_panel = d[0]
	var v: VBoxContainer = d[1]
	v.add_child(_field_label(Loc.t("姓名", "Callsign")))
	_dlg_name = _line_edit()
	_dlg_name.max_length = 12 if en else 8
	_dlg_name.placeholder_text = Loc.t("最多 8 个字", "Up to 12 chars")
	_dlg_name.text_submitted.connect(func(_t): _confirm_start())
	v.add_child(_dlg_name)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	v.add_child(sp)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(line)
	line.add_child(_btn(Loc.t("返回", "Back"), false, _close_start))
	line.add_child(_btn(Loc.t("启程", "Launch"), true, _confirm_start))


func _open_start() -> void:
	_dlg_name.text = Growth.player_name()
	start_panel.visible = true
	shade.visible = true
	_dlg_name.grab_focus()
	Audio.play_ui("ui_open")


func _close_start() -> void:
	start_panel.visible = false
	shade.visible = settings_panel.visible
	Audio.play_ui("ui_cancel")


func _confirm_start() -> void:
	Growth.set_player_name(_dlg_name.text)
	GameData.new_game()
	start_panel.visible = false
	shade.visible = false
	Audio.play_ui("ui_confirm")
	start_requested.emit()


func _close_dialogs() -> void:
	if start_panel.visible:
		_close_start()
	elif settings_panel.visible:
		_toggle_settings()


## 载入游戏
func _load_game() -> void:
	if not FileAccess.file_exists(GameData.save_path):
		Audio.play_ui("ui_denied")
		return
	if GameData.load_game():
		Audio.play_ui("ui_confirm")
		start_requested.emit()
	else:
		Audio.play_ui("ui_denied")


func _build_settings(initial_tab := "video") -> void:
	var d := _dialog_to_ui(Loc.t("游戏设置", "Settings"), "// 03")
	settings_panel = d[0]
	var v: VBoxContainer = d[1]
	settings_panel.custom_minimum_size = Vector2(640, 430)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)

	# 左：分页导航
	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", 4)
	nav.custom_minimum_size = Vector2(108, 0)
	row.add_child(nav)

	# 右：页面内容（inset9 凹槽底板）
	var body := PanelContainer.new()
	body.add_theme_stylebox_override("panel", UI.px9("inset9", 8, 8, 16, 14))
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(body)
	var pages := {}
	var tab_defs := [
		["video", Loc.t("画面", "Video")],
		["audio", Loc.t("声音", "Audio")],
		["other", Loc.t("其他", "Other")],
	]
	for td in tab_defs:
		var key: String = td[0]
		var pg := VBoxContainer.new()
		pg.add_theme_constant_override("separation", 8)
		pg.visible = false
		body.add_child(pg)
		pages[key] = pg

	var nav_btns := {}
	var show_page := func(key: String):
		for k in pages:
			pages[k].visible = k == key
		for k in nav_btns:
			var b: Button = nav_btns[k]
			var on: bool = (k == key)
			b.add_theme_stylebox_override("normal", UI.px9("nav9_on" if on else "nav9_n", 10, 10, 12, 6))
			b.add_theme_stylebox_override("hover", UI.px9("nav9_on" if on else "nav9_h", 10, 10, 12, 6))
			b.add_theme_color_override("font_color", UI.GOLD if on else UI.TEXT)
	for td in tab_defs:
		var key: String = td[0]
		var b := Button.new()
		b.text = td[1]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(108, 34)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(func(): show_page.call(key))
		nav.add_child(b)
		nav_btns[key] = b
	show_page.call(initial_tab if pages.has(initial_tab) else "video")

	# ---- 画面 ----
	var pg: VBoxContainer = pages["video"]
	var fs := CheckButton.new()
	fs.text = Loc.t("全屏", "Fullscreen")
	fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs.toggled.connect(func(on): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	pg.add_child(fs)
	var vs := CheckButton.new()
	vs.text = Loc.t("垂直同步", "VSync")
	vs.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	vs.toggled.connect(func(on): DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED))
	pg.add_child(vs)
	pg.add_child(_field_label(Loc.t("画质", "Quality")))
	var q := OptionButton.new()
	for i in GameData.QUALITY_NAMES.size():
		q.add_item(GameData.QUALITY_NAMES[i], i)
	q.selected = GameData.quality
	q.item_selected.connect(func(i):
		GameData.quality = i
		GameData.apply_quality(get_viewport())
		GameData.save_game())
	pg.add_child(q)
	pg.add_child(_field_label(Loc.t("画面风格", "Render Style")))
	var st := OptionButton.new()
	st.add_item(Loc.t("写实光影", "Realistic Lighting"), 0)
	st.add_item(Loc.t("三渲二（卡通描边）", "Cel-Shaded (Toony Outline)"), 1)
	st.selected = GameData.render_style
	st.item_selected.connect(func(i):
		GameData.render_style = i
		GameData.save_game()
		if toon:
			toon.set_enabled(i == 1))
	pg.add_child(st)

	# ---- 声音 ----
	pg = pages["audio"]
	for bus in [["Master", Loc.t("主音量", "Master")], ["Music", Loc.t("音乐", "Music")], ["SFX", Loc.t("音效", "SFX")], ["Voice", Loc.t("语音", "Voice")]]:
		pg.add_child(_field_label(bus[1]))
		var vol := HSlider.new()
		vol.min_value = 0
		vol.max_value = 1
		vol.step = 0.05
		vol.value = Audio.get_volume(bus[0])
		vol.custom_minimum_size = Vector2(0, 22)
		vol.value_changed.connect(func(x): Audio.set_volume(bus[0], x))
		pg.add_child(vol)

	# ---- 其他 ----
	pg = pages["other"]
	pg.add_child(_field_label(Loc.t("界面语言", "Language")))
	var tl := OptionButton.new()
	tl.add_item("简体中文", 0)
	tl.add_item("English", 1)
	tl.selected = 1 if Loc.is_en() else 0
	tl.item_selected.connect(func(i):
		var new_lang := "zh" if i == 0 else "en"
		title_lang = new_lang
		Loc.set_lang(new_lang)
		call_deferred("_build_ui", true, "other"))
	pg.add_child(tl)

	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(line)
	var close := _btn(Loc.t("返回", "Back"), false, _toggle_settings)
	close.set_meta("sfx", "")
	line.add_child(close)


func _toggle_settings() -> void:
	settings_panel.visible = not settings_panel.visible
	shade.visible = settings_panel.visible or start_panel.visible
	Audio.play_ui("ui_open" if settings_panel.visible else "ui_cancel")


func _process(delta: float) -> void:
	if status_dot:
		status_dot.modulate.a = 0.45 + 0.55 * absf(sin(t * 1.6))
	t += delta
	readout_t -= delta
	if readout_t <= 0.0:
		readout_t = randf_range(1.0, 2.2)
		_tick_readout()
	if post_mat:
		post_mat.set_shader_parameter("t", fmod(t, 10.0))
	var sway := sin(t * 0.35) * 0.6 + sin(t * 0.13) * 0.4
	# 贴窗视角：镜头几乎贴着玻璃，窗框和仪表台只占画面边缘
	cam.position = Vector3(0.75 + sin(t * 0.07) * 0.04, 1.82 + sin(t * 0.4) * 0.02, 1.1)
	cam.look_at(Vector3(1.6 + sin(t * 0.05) * 0.15, 0.9, -6.0), Vector3.UP)
	cam.rotate_object_local(Vector3.FORWARD, deg_to_rad(sway * 0.6))
	if refs.has("lamp"):
		refs.lamp.rotation.z = sin(t * 0.35 - 0.6) * 0.05
		refs.lamp.rotation.x = sin(t * 0.27) * 0.03
	if refs.has("prop"):
		refs.prop.rotation.x += delta * 14.0
	if refs.has("clouds"):
		for c in refs.clouds:
			c.position.x -= delta * 4.0
			if c.position.x < -280.0:
				c.position.x += 560.0
	if refs.has("needles"):
		for i in refs.needles.size():
			var nd = refs.needles[i]
			if nd:
				nd.rotation.z = deg_to_rad(-40.0 + i * 55.0) + sin(t * (0.6 + i * 0.37)) * 0.05


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	if e.keycode == KEY_ESCAPE:
		if start_panel.visible or settings_panel.visible:
			_close_dialogs()
		return
	if start_panel.visible or settings_panel.visible:
		return
	if e.keycode == KEY_UP or e.keycode == KEY_W:
		_step(-1)
	elif e.keycode == KEY_DOWN or e.keycode == KEY_S:
		_step(1)
	elif e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER or e.keycode == KEY_SPACE:
		if sel >= 0 and not buttons[sel].get_meta("disabled"):
			buttons[sel].emit_signal("pressed")


func _step(dir: int) -> void:
	var i := sel
	for _k in buttons.size():
		i = posmod(i + dir, buttons.size())
		if not buttons[i].get_meta("disabled"):
			_select(i, true)
			return
