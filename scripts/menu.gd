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
	sv.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
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


func _build_ui() -> void:
	var post := ColorRect.new()
	post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = POST
	post_mat = ShaderMaterial.new()
	post_mat.shader = sh
	post.material = post_mat
	add_child(post)

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
	add_child(grad)

	# 取景框角标 + 菜单游标（自绘）
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	add_child(hud)

	# 标题：生成的金属艺术字（中文 / 英文两版），带投影
	title_rect = TextureRect.new()
	title_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	title_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # 项目全局为 Nearest（像素 UI），标题是高清图需线性+mipmap
	var tsh := Shader.new()
	tsh.code = TITLE_FX
	title_mat = ShaderMaterial.new()
	title_mat.shader = tsh
	title_rect.material = title_mat
	add_child(title_rect)
	_apply_title_lang()

	# 菜单
	menu_box = VBoxContainer.new()
	menu_box.position = Vector2(96, 330)
	menu_box.add_theme_constant_override("separation", 0)
	add_child(menu_box)
	var has_save := FileAccess.file_exists(GameData.save_path)
	var items := [
		["新的游戏", "NEW GAME", func(): _open_start(), "ui_confirm", false],
		["载入游戏", "CONTINUE" if has_save else "无存档", func(): _load_game(), "ui_confirm", not has_save],
		["游戏设置", "SETTINGS", func(): _toggle_settings(), "", false],
		["退出游戏", "QUIT", func(): get_tree().quit(), "ui_cancel", false]
	]
	for i in items.size():
		var it: Array = items[i]
		var mb := _menu_button(i, it[0], it[1], it[2], it[4])
		mb.set_meta("sfx", it[3])
		menu_box.add_child(mb)

	# 左下：舱内仪表读数
	var readout := HBoxContainer.new()
	readout.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	readout.offset_left = 96
	readout.offset_top = -92
	readout.offset_bottom = -64
	readout.add_theme_constant_override("separation", 28)
	add_child(readout)
	status_dot = UI.label("●", 12, UI.GOOD)
	var live := HBoxContainer.new()
	live.add_theme_constant_override("separation", 6)
	live.add_child(status_dot)
	live.add_child(_spaced(UI.label("链路在线", 12, Color(1, 1, 1, 0.7)), 1))
	readout.add_child(live)
	for kv in [["高度", "260 m"], ["航速", "6.5 m/s"], ["航向", "074°"], ["云层", "-165 ~ -15 m"]]:
		readout.add_child(_readout(kv[0], kv[1]))

	# 弹窗遮罩
	shade = ColorRect.new()
	shade.color = Color(0.01, 0.012, 0.015, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.visible = false
	shade.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close_dialogs())
	add_child(shade)

	_build_settings()
	_build_start_panel()
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
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(c, 0.0)
	sb.border_color = c
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.content_margin_left = 8
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	pc.add_theme_stylebox_override("panel", sb)
	pc.add_child(_spaced(UI.label(text, 13, c), 2))
	return pc


func _readout(k: String, v: String) -> Control:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", -2)
	b.add_child(_spaced(UI.label(k, 11, Color(1, 1, 1, 0.42)), 2))
	b.add_child(UI.label(v, 14, Color(1, 1, 1, 0.82)))
	return b


func _keycap(key: String, what: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.08)
	sb.border_color = Color(1, 1, 1, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	pc.add_theme_stylebox_override("panel", sb)
	pc.add_child(UI.label(key, 11, Color(1, 1, 1, 0.85)))
	h.add_child(pc)
	h.add_child(UI.label(what, 12, Color(1, 1, 1, 0.55)))
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


var hud: Control
var title_rect: TextureRect
var title_mat: ShaderMaterial
var title_lang := ""
const MENU_CFG := "user://menu.cfg"
const TITLE_FX := """
shader_type canvas_item;
// 标题：金属原图 + 下方柔和投影，画面静止不叠加任何扫光
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * vec2(6.0, 9.0);
	float sh = texture(TEXTURE, UV - px).a;
	vec4 shadow = vec4(0.0, 0.0, 0.0, sh * 0.45);
	COLOR = mix(shadow, vec4(c.rgb, 1.0), c.a);
}
"""


func _apply_title_lang() -> void:
	if title_lang == "":
		var cf := ConfigFile.new()
		if cf.load(MENU_CFG) == OK:
			title_lang = str(cf.get_value("menu", "title_lang", ""))
		if title_lang == "":
			title_lang = "zh" if OS.get_locale_language() == "zh" else "en"
	var zh := title_lang == "zh"
	title_rect.texture = load("res://assets/title_%s.png" % ("zh" if zh else "en"))
	var w := 560.0 if zh else 500.0
	var tsz: Vector2 = title_rect.texture.get_size()
	title_rect.position = Vector2(84, 300 - w * tsz.y / tsz.x - 24)
	title_rect.size = Vector2(w, w * tsz.y / tsz.x)
var menu_box: VBoxContainer
var status_dot: Label
var shade: ColorRect
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
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.06, 0.068, 0.96)
	sb.border_color = Color(1, 1, 1, 0.1)
	sb.set_border_width_all(1)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 24
	sb.content_margin_bottom = 26
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 24
	pc.add_theme_stylebox_override("panel", sb)
	pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pc.custom_minimum_size = Vector2(480, 0)
	pc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pc.grow_vertical = Control.GROW_DIRECTION_BOTH
	pc.visible = false
	add_child(pc)
	pc.draw.connect(func():
		pc.draw_rect(Rect2(0, 0, 120, 3), UI.ACCENT)
		pc.draw_rect(Rect2(pc.size.x - 10, pc.size.y - 10, 6, 6), Color(1, 1, 1, 0.25)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	pc.add_child(v)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	v.add_child(hb)
	var cl := _spaced(UI.label(code, 11, UI.ACCENT), 2)
	cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cl.size_flags_vertical = Control.SIZE_FILL
	hb.add_child(cl)
	hb.add_child(UI.label(title, 24, Color(0.97, 0.95, 0.9)))
	var div := ColorRect.new()
	div.color = Color(1, 1, 1, 0.08)
	div.custom_minimum_size = Vector2(0, 1)
	v.add_child(div)
	return [pc, v]


func _field_label(t: String) -> Label:
	return _spaced(UI.label(t, 12, Color(1, 1, 1, 0.5)), 2)


func _btn(text: String, primary: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(140, 42)
	b.focus_mode = Control.FOCUS_NONE
	var n := StyleBoxFlat.new()
	var h := StyleBoxFlat.new()
	if primary:
		n.bg_color = UI.ACCENT
		h.bg_color = UI.ACCENT.lightened(0.18)
		b.add_theme_color_override("font_color", Color(0.08, 0.07, 0.05))
		b.add_theme_color_override("font_hover_color", Color(0.08, 0.07, 0.05))
		b.add_theme_color_override("font_pressed_color", Color(0.08, 0.07, 0.05))
	else:
		n.bg_color = Color(1, 1, 1, 0.0)
		n.border_color = Color(1, 1, 1, 0.3)
		n.set_border_width_all(1)
		h.bg_color = Color(1, 1, 1, 0.08)
		h.border_color = Color(1, 1, 1, 0.55)
		h.set_border_width_all(1)
	for s2 in [n, h]:
		s2.content_margin_left = 18
		s2.content_margin_right = 18
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", n)
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(cb)
	return b


func _line_edit() -> LineEdit:
	var e := LineEdit.new()
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0, 0, 0, 0.35)
	n.border_color = Color(1, 1, 1, 0.18)
	n.border_width_bottom = 2
	n.content_margin_left = 12
	n.content_margin_right = 12
	n.content_margin_top = 8
	n.content_margin_bottom = 8
	var f := n.duplicate()
	f.border_color = UI.ACCENT
	e.add_theme_stylebox_override("normal", n)
	e.add_theme_stylebox_override("focus", f)
	e.add_theme_font_size_override("font_size", 20)
	e.add_theme_color_override("caret_color", UI.ACCENT)
	return e


## 新的游戏：驾驶员登记
func _build_start_panel() -> void:
	var d := _dialog("驾驶员登记", "// 01")
	start_panel = d[0]
	var v: VBoxContainer = d[1]
	v.add_child(_field_label("姓名"))
	_dlg_name = _line_edit()
	_dlg_name.max_length = 8
	_dlg_name.placeholder_text = "最多 8 个字"
	_dlg_name.text_submitted.connect(func(_t): _confirm_start())
	v.add_child(_dlg_name)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	v.add_child(sp)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(line)
	line.add_child(_btn("返回", false, _close_start))
	line.add_child(_btn("启程", true, _confirm_start))


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


func _build_settings() -> void:
	var d := _dialog("游戏设置", "// 03")
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

	# 右：页面内容
	var body := PanelContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(body)
	var pages := {}
	for key in ["画面", "声音", "其他"]:
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
			nav_btns[k].add_theme_color_override("font_color", UI.ACCENT if k == key else UI.TEXT)
	for key in ["画面", "声音", "其他"]:
		var b := Button.new()
		b.text = key
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(108, 32)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): show_page.call(key))
		nav.add_child(b)
		nav_btns[key] = b
	show_page.call("画面")

	# ---- 画面 ----
	var pg: VBoxContainer = pages["画面"]
	var fs := CheckButton.new()
	fs.text = "全屏"
	fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs.toggled.connect(func(on): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	pg.add_child(fs)
	var vs := CheckButton.new()
	vs.text = "垂直同步"
	vs.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	vs.toggled.connect(func(on): DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED))
	pg.add_child(vs)
	pg.add_child(_field_label("画质"))
	var q := OptionButton.new()
	for i in GameData.QUALITY_NAMES.size():
		q.add_item(GameData.QUALITY_NAMES[i], i)
	q.selected = GameData.quality
	q.item_selected.connect(func(i):
		GameData.quality = i
		GameData.apply_quality(get_viewport())
		GameData.save_game())
	pg.add_child(q)
	pg.add_child(_field_label("画面风格"))
	var st := OptionButton.new()
	st.add_item("写实光影", 0)
	st.add_item("三渲二（卡通描边）", 1)
	st.selected = GameData.render_style
	st.item_selected.connect(func(i):
		GameData.render_style = i
		GameData.save_game()
		if toon:
			toon.set_enabled(i == 1))
	pg.add_child(st)

	# ---- 声音 ----
	pg = pages["声音"]
	for bus in [["Master", "主音量"], ["Music", "音乐"], ["SFX", "音效"], ["Voice", "语音"]]:
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
	pg = pages["其他"]
	pg.add_child(_field_label("标题语言"))
	var tl := OptionButton.new()
	tl.add_item("中文", 0)
	tl.add_item("English", 1)
	tl.selected = 0 if title_lang == "zh" else 1
	tl.item_selected.connect(func(i):
		title_lang = "zh" if i == 0 else "en"
		var cf := ConfigFile.new()
		cf.load(MENU_CFG)
		cf.set_value("menu", "title_lang", title_lang)
		cf.save(MENU_CFG)
		_apply_title_lang())
	pg.add_child(tl)

	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(line)
	var close := _btn("返回", false, _toggle_settings)
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
