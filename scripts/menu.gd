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
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(svc)
	var sv := SubViewport.new()
	sv.msaa_3d = Viewport.MSAA_4X
	svc.add_child(sv)
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

	# 左侧暗角渐变
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.03, 0.03, 0.04, 0.92))
	g.set_color(1, Color(0.03, 0.03, 0.04, 0.0))
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	grad.offset_right = 720
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grad)

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	v.offset_left = 90
	v.offset_top = -250
	v.offset_bottom = 250
	v.add_theme_constant_override("separation", 8)
	add_child(v)

	var title := UI.label("Abyss Diver Girls", 60, Color(0.97, 0.94, 0.88), true)
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	v.add_child(title)

	var bar := ColorRect.new()
	bar.color = UI.ACCENT
	bar.custom_minimum_size = Vector2(120, 4)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(bar)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 28)
	v.add_child(sp)

	# 核心一级按钮：新的游戏、载入游戏、游戏设置、退出游戏
	var has_save := FileAccess.file_exists(GameData.save_path)
	var items := [
		["新的游戏", "", func(): _open_start(), "ui_confirm", false],
		["载入游戏", "", func(): _load_game(), "ui_confirm", not has_save],
		["游戏设置", "", func(): _toggle_settings(), "", false],
		["退出游戏", "", func(): get_tree().quit(), "ui_cancel", false]
	]
	for it in items:
		var mb := _menu_button(it[0], it[1], it[2], it[4])
		mb.set_meta("sfx", it[3])
		v.add_child(mb)

	_build_settings()
	_build_start_panel()


func _menu_button(text: String, hint: String, cb: Callable, disabled: bool = false) -> Control:
	var b := Button.new()
	b.flat = true
	b.custom_minimum_size = Vector2(380, 56)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = disabled

	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0, 0, 0, 0)
	sb_n.content_margin_left = 22
	var sb_h := StyleBoxFlat.new()
	sb_h.bg_color = Color(1.0, 0.69, 0.13, 0.14)
	sb_h.border_color = UI.ACCENT
	sb_h.border_width_left = 4
	sb_h.content_margin_left = 22

	b.add_theme_stylebox_override("normal", sb_n)
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("pressed", sb_h)
	b.add_theme_stylebox_override("focus", sb_n)

	var h := VBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 22
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 0)
	b.add_child(h)

	var l := UI.label(text, 24, UI.TEXT if not disabled else UI.MUTED)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	if hint != "":
		var hl := UI.label(hint, 12, UI.MUTED)
		hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(hl)

	if not disabled:
		b.mouse_entered.connect(func():
			l.add_theme_color_override("font_color", UI.ACCENT)
			var tw := create_tween()
			tw.tween_property(h, "offset_left", 34.0, 0.12))
		b.mouse_exited.connect(func():
			l.add_theme_color_override("font_color", UI.TEXT)
			var tw := create_tween()
			tw.tween_property(h, "offset_left", 22.0, 0.12))
		b.pressed.connect(cb)
	else:
		b.mouse_filter = Control.MOUSE_FILTER_STOP

	buttons.append(b)
	return b


## 新的游戏：驾驶员登记
func _build_start_panel() -> void:
	start_panel = UI.panel(18)
	start_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	start_panel.custom_minimum_size = Vector2(420, 0)
	start_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	start_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	start_panel.visible = false
	add_child(start_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	start_panel.add_child(v)
	v.add_child(UI.label("驾驶员登记", 22, UI.ACCENT))
	v.add_child(UI.label("姓名", 14, UI.MUTED))
	_dlg_name = LineEdit.new()
	_dlg_name.max_length = 8
	_dlg_name.text_submitted.connect(func(_t): _confirm_start())
	v.add_child(_dlg_name)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	v.add_child(line)
	var ok := Button.new()
	ok.text = "启程"
	ok.pressed.connect(_confirm_start)
	line.add_child(ok)
	var cancel := Button.new()
	cancel.text = "返回"
	cancel.pressed.connect(_close_start)
	line.add_child(cancel)


func _open_start() -> void:
	_dlg_name.text = Growth.player_name()
	start_panel.visible = true
	Audio.play_ui("ui_open")


func _close_start() -> void:
	start_panel.visible = false
	Audio.play_ui("ui_cancel")


func _confirm_start() -> void:
	Growth.set_player_name(_dlg_name.text)
	GameData.new_game()
	start_panel.visible = false
	Audio.play_ui("ui_confirm")
	start_requested.emit()


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
	settings_panel = UI.panel(18)
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	settings_panel.custom_minimum_size = Vector2(420, 0)
	settings_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	settings_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	settings_panel.visible = false
	add_child(settings_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	settings_panel.add_child(v)
	v.add_child(UI.label("游戏设置", 22, UI.ACCENT))
	var fs := CheckButton.new()
	fs.text = "全屏"
	fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs.toggled.connect(func(on): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	v.add_child(fs)
	var vs := CheckButton.new()
	vs.text = "垂直同步"
	vs.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	vs.toggled.connect(func(on): DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED))
	v.add_child(vs)
	v.add_child(UI.label("画面风格", 14, UI.MUTED))
	var st := OptionButton.new()
	st.add_item("写实光影", 0)
	st.add_item("三渲二（卡通描边）", 1)
	st.selected = GameData.render_style
	st.item_selected.connect(func(i):
		GameData.render_style = i
		GameData.save_game()
		if toon:
			toon.set_enabled(i == 1))
	v.add_child(st)
	v.add_child(UI.label("主音量", 14, UI.MUTED))
	var vol := HSlider.new()
	vol.min_value = 0
	vol.max_value = 1
	vol.step = 0.05
	vol.value = Audio.get_volume("Master")
	vol.value_changed.connect(func(x): Audio.set_volume("Master", x))
	v.add_child(vol)
	var close := Button.new()
	close.text = "返回"
	close.set_meta("sfx", "")
	close.pressed.connect(_toggle_settings)
	v.add_child(close)


func _toggle_settings() -> void:
	settings_panel.visible = not settings_panel.visible
	Audio.play_ui("ui_open" if settings_panel.visible else "ui_cancel")


func _process(delta: float) -> void:
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
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE and settings_panel.visible:
		_toggle_settings()
