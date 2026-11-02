extends Control
## 主菜单：飞行中飞空艇座舱朝外俯瞰云海（伪天空盒 + 滚滚云海 + 座舱舷窗骨架与仪表台）+ 标题 + 核心按钮
signal start_requested

const A = preload("res://scripts/art.gd")
const UI = preload("res://scripts/ui.gd")
const MV = preload("res://scripts/mech_visual.gd")
const Growth = preload("res://scripts/progression/growth.gd")

const SKY_SHADER := """
shader_type sky;
uniform vec4 top_color : source_color = vec4(0.08, 0.14, 0.28, 1.0);
uniform vec4 horiz_color : source_color = vec4(0.96, 0.54, 0.22, 1.0);
uniform vec4 haze_color : source_color = vec4(0.85, 0.40, 0.16, 1.0);
uniform vec3 sun_dir = vec3(0.55, 0.18, -0.80);
uniform float t = 0.0;

void sky() {
	float h = clamp(EYEDIR.y * 3.2, -1.0, 1.0);
	vec3 col = mix(horiz_color.rgb, top_color.rgb, clamp(h, 0.0, 1.0));
	col = mix(col, haze_color.rgb, clamp(-h * 1.5, 0.0, 1.0));

	float sun_dot = max(dot(EYEDIR, normalize(sun_dir)), 0.0);
	float sun_disk = pow(sun_dot, 512.0) * 4.0;
	float sun_halo = pow(sun_dot, 28.0) * 0.9 + pow(sun_dot, 4.0) * 0.4;
	vec3 sun_col = vec3(1.0, 0.92, 0.72) * sun_disk + vec3(1.0, 0.65, 0.28) * sun_halo;

	// High altitude cirrus streaks
	float cirrus = sin(EYEDIR.x * 12.0 + t * 0.02) * sin(EYEDIR.z * 10.0 + EYEDIR.y * 18.0);
	cirrus = smoothstep(0.42, 0.92, cirrus) * clamp(EYEDIR.y * 2.0, 0.0, 1.0) * 0.35;
	col += vec3(1.0, 0.85, 0.68) * cirrus;

	COLOR = col + sun_col;
}
"""

const CLOUD_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled;
uniform vec4 cloud_light : source_color = vec4(0.98, 0.85, 0.68, 1.0);
uniform vec4 cloud_shadow : source_color = vec4(0.38, 0.28, 0.34, 1.0);
uniform vec4 cloud_ambient : source_color = vec4(0.85, 0.50, 0.28, 1.0);
uniform float t = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	v += 0.5000 * noise(p); p *= 2.02;
	v += 0.2500 * noise(p); p *= 2.03;
	v += 0.1250 * noise(p); p *= 2.01;
	v += 0.0625 * noise(p);
	return v;
}
void fragment() {
	vec2 uv = UV * 24.0 + vec2(0.0, t * 0.15);
	float n = fbm(uv);
	float n2 = fbm(uv * 2.5 + vec2(t * 0.08, 0.0));
	float billow = clamp(n * 0.65 + n2 * 0.35, 0.0, 1.0);

	vec3 col = mix(cloud_shadow.rgb, cloud_light.rgb, smoothstep(0.28, 0.75, billow));
	col = mix(col, cloud_ambient.rgb, 0.30);

	ALBEDO = col;
	ROUGHNESS = 0.95;
	ALPHA = 0.98;
}
"""

var cam: Camera3D
var toon: Node
var menu_env: Environment
var cabin: Node3D
var wing_beacon: OmniLight3D
var skybox_mat: ShaderMaterial
var cloud_mat: ShaderMaterial
var escort_ship: Node3D
var cloud_nodes: Array = []
var t := 0.0
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

	# 1. 环境与伪天空盒
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sh_sky := Shader.new()
	sh_sky.code = SKY_SHADER
	skybox_mat = ShaderMaterial.new()
	skybox_mat.shader = sh_sky
	sky.sky_material = skybox_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.15
	env.tonemap_white = 10.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.8
	env.ssil_enabled = true
	env.ssil_intensity = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.08
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = Color(0.92, 0.58, 0.30)
	env.fog_density = 0.0008
	env.fog_depth_begin = 35.0
	env.fog_depth_end = 280.0
	env.volumetric_fog_enabled = false
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.94
	we.environment = env
	menu_env = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.72, 0.45)
	sun.light_energy = 2.8
	sun.rotation_degrees = Vector3(-12, -145, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	root.add_child(sun)

	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.40, 0.50, 0.75)
	rim.light_energy = 0.6
	rim.rotation_degrees = Vector3(-30, 45, 0)
	root.add_child(rim)

	# 2. 滚滚云海（下方大面积横向流动云海平面）
	var cloud_mesh := PlaneMesh.new()
	cloud_mesh.size = Vector2(800, 800)
	var sh_cloud := Shader.new()
	sh_cloud.code = CLOUD_SHADER
	cloud_mat = ShaderMaterial.new()
	cloud_mat.shader = sh_cloud
	var cloud_inst := MeshInstance3D.new()
	cloud_inst.mesh = cloud_mesh
	cloud_inst.material_override = cloud_mat
	cloud_inst.position = Vector3(0, -6.5, -60.0)
	cloud_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cloud_inst)

	# 3. 立体云团群（从飞空艇舷窗下方向后快速漂移，产生飞行速度感与真实视差）
	var cloud_pbr := StandardMaterial3D.new()
	cloud_pbr.albedo_color = Color(0.95, 0.82, 0.70, 0.85)
	cloud_pbr.roughness = 0.95
	cloud_pbr.emission_enabled = true
	cloud_pbr.emission = Color(0.85, 0.45, 0.22)
	cloud_pbr.emission_energy_multiplier = 0.35
	cloud_pbr.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 22:
		var s := rng.randf_range(12.0, 32.0)
		var puff := MeshInstance3D.new()
		var sm_puff := SphereMesh.new()
		sm_puff.radius = s * 0.5
		sm_puff.height = s * 0.6
		puff.mesh = sm_puff
		puff.material_override = cloud_pbr
		puff.position = Vector3(rng.randf_range(-140, 160), rng.randf_range(-22, -10), rng.randf_range(-220, 20))
		puff.set_meta("base_z", puff.position.z)
		puff.set_meta("speed", rng.randf_range(28.0, 48.0))
		root.add_child(puff)
		cloud_nodes.append(puff)

	# 4. 僚舰（右侧前方伴随飞行的巡防飞空艇，朝向航向前方）
	escort_ship = Node3D.new()
	escort_ship.position = Vector3(34.0, 6.0, -52.0)
	escort_ship.rotation_degrees = Vector3(0, 8, 0)
	root.add_child(escort_ship)
	var hull_mat := A.paint(Color(0.24, 0.26, 0.28), 0.35, 0.65, {"panel_scale": 0.6})
	# 艇身主气囊（沿 Z 轴布置）
	A.add(escort_ship, A.capsule(2.6, 22.0), hull_mat, Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, false)
	# 艇腹吊舱
	A.add(escort_ship, A.bevel_box(Vector3(2.2, 1.6, 7.0), 0.15), hull_mat, Vector3(0, -2.2, 1.0), Vector3.ZERO, Vector3.ONE, false)
	# 尾翼十字稳定翼
	A.add(escort_ship, A.bevel_box(Vector3(6.8, 0.15, 3.2), 0.04, 0.6), hull_mat, Vector3(0, 0, 8.5), Vector3.ZERO, Vector3.ONE, false)
	A.add(escort_ship, A.bevel_box(Vector3(0.15, 6.8, 3.2), 0.04, 0.6), hull_mat, Vector3(0, 0, 8.5), Vector3.ZERO, Vector3.ONE, false)
	# 舷窗发光与尾喷
	for k in 4:
		A.add(escort_ship, A.sphere(0.2, -1, 6), A.emit(Color(1.0, 0.75, 0.35), 4.5), Vector3(-1.2, -2.0, -1.5 + k * 1.6), Vector3.ZERO, Vector3.ONE, false)
	A.add(escort_ship, A.sphere(0.45, -1, 6), A.emit(Color(0.3, 0.8, 1.0), 6.0), Vector3(0, -0.6, 11.2), Vector3.ZERO, Vector3.ONE, false)

	# 5. 飞空艇座舱（观察桥楼内景骨架结构：无遮挡全景观察舷窗、仪表台、右侧外露机翼与涡轮引擎）
	cabin = Node3D.new()
	root.add_child(cabin)
	var frame_mat := A.paint(Color(0.15, 0.16, 0.19), 0.15, 0.85, {"panel_scale": 0.5})

	# 舷窗顶部框架与顶棚（保持高位，不遮挡天空视线）
	A.add(cabin, A.bevel_box(Vector3(8.0, 0.35, 3.2), 0.06), frame_mat, Vector3(0.0, 2.65, 0.4), Vector3(8, 0, 0))
	# 舷窗左侧 A 柱（退至画面左侧，留出主视口）
	A.add(cabin, A.bevel_box(Vector3(0.35, 3.2, 0.35), 0.05), frame_mat, Vector3(-2.6, 1.6, 0.2), Vector3(0, 20, 16))
	# 舷窗右侧 A 柱（分隔正向大视窗与右侧外探机翼舷窗）
	A.add(cabin, A.bevel_box(Vector3(0.32, 3.2, 0.35), 0.05), frame_mat, Vector3(1.85, 1.6, 0.1), Vector3(0, -18, -14))

	# 仪表操作台（下方斜面控制台）
	var dash_mat := A.paint(Color(0.12, 0.13, 0.15), 0.1, 0.9)
	A.add(cabin, A.bevel_box(Vector3(6.2, 0.5, 1.4), 0.05), dash_mat, Vector3(0.1, 0.68, -0.3), Vector3(18, 0, 0))
	# 仪表盘发光屏与战术仪表
	A.add(cabin, A.bevel_box(Vector3(0.85, 0.04, 0.55), 0.02), A.emit(Color(0.20, 0.85, 0.70), 2.2), Vector3(-0.95, 0.82, -0.2), Vector3(18, 8, 0))
	A.add(cabin, A.bevel_box(Vector3(0.75, 0.04, 0.45), 0.02), A.emit(Color(1.0, 0.72, 0.30), 1.6), Vector3(0.95, 0.82, -0.2), Vector3(18, -8, 0))
	for led in 6:
		var c_led := Color(0.25, 1.0, 0.45) if led % 2 == 0 else Color(1.0, 0.55, 0.2)
		A.add(cabin, A.sphere(0.022, -1, 4), A.emit(c_led, 2.5), Vector3(-0.25 + led * 0.1, 0.78, -0.42), Vector3.ZERO, Vector3.ONE, false)

	# 舱内微弱暖色顶光
	var cabin_light := OmniLight3D.new()
	cabin_light.light_color = Color(1.0, 0.68, 0.35)
	cabin_light.light_energy = 0.9
	cabin_light.omni_range = 3.2
	cabin_light.position = Vector3(0, 2.3, 0.5)
	cabin.add_child(cabin_light)

	# 右侧舷窗外探出的飞空艇主翼与涡轮推进器
	var wing := Node3D.new()
	wing.position = Vector3(3.2, 0.5, -3.0)
	wing.rotation_degrees = Vector3(0, -8, 3)
	cabin.add_child(wing)
	var wing_mat := A.paint(Color(0.20, 0.22, 0.25), 0.3, 0.7)
	A.add(wing, A.bevel_box(Vector3(3.6, 0.22, 1.6), 0.08, 0.75), wing_mat, Vector3(1.5, 0, 0))
	# 涡轮机舱
	var nacelle := A.cyl(0.60, 3.0, 0.60, 14)
	A.add(wing, nacelle, wing_mat, Vector3(1.6, -0.45, 0.2), Vector3(90, 0, 0))
	# 翼尖频闪防撞信号灯
	wing_beacon = OmniLight3D.new()
	wing_beacon.light_color = Color(1.0, 0.25, 0.18)
	wing_beacon.light_energy = 3.5
	wing_beacon.omni_range = 6.0
	wing_beacon.position = Vector3(3.4, 0.15, 0)
	wing.add_child(wing_beacon)
	A.add(wing, A.sphere(0.08, -1, 6), A.emit(Color(1.0, 0.25, 0.18), 5.0), Vector3(3.4, 0.15, 0), Vector3.ZERO, Vector3.ONE, false)

	# 舷窗外流动的冷凝气流与风痕粒子
	A.emitter(cabin, Vector3(0.5, 1.4, -4.5), {
		"amount": 45, "life": 0.6, "size": 0.04, "box": Vector3(4.5, 2.0, 1.0),
		"dir": Vector3(0, 0, 1.0), "spread": 2.0, "vmin": 16.0, "vmax": 24.0,
		"c0": Color(1.0, 0.95, 0.9, 0.0), "cmid": Color(1.0, 0.9, 0.82, 0.45),
		"c1": Color(1.0, 0.85, 0.75, 0.0), "grow0": 1.0, "grow1": 1.0, "additive": true
	})

	# 7. 摄像机：置于座舱内，朝向舷窗外开阔的云海与落日地平线
	cam = Camera3D.new()
	cam.fov = 42
	root.add_child(cam)
	cam.position = Vector3(-0.25, 1.45, 0.95)
	cam.look_at(Vector3(0.35, 1.25, -16.0), Vector3.UP)
	var ca := CameraAttributesPractical.new()
	ca.dof_blur_far_enabled = false
	cam.attributes = ca
	cam.current = true
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
	if skybox_mat:
		skybox_mat.set_shader_parameter("t", t)
	if cloud_mat:
		cloud_mat.set_shader_parameter("t", t)

	# 飞空艇航行中的重工业机体呼吸感与气流颠簸
	if cabin:
		cabin.rotation.z = sin(t * 0.45) * 0.012 + sin(t * 1.1) * 0.003
		cabin.rotation.x = sin(t * 0.32) * 0.007
		cabin.position.y = sin(t * 0.70) * 0.035

	# 摄像机微调伴随感
	if cam:
		cam.position.y = 1.42 + sin(t * 0.85) * 0.012
		cam.position.x = -0.35 + sin(t * 0.45) * 0.008

	# 翼尖频闪信号灯（每 1.2 秒闪一次）
	if wing_beacon:
		wing_beacon.light_energy = 3.5 if fmod(t, 1.2) < 0.12 else 0.0

	# 僚舰编队浮动
	if escort_ship:
		escort_ship.position.y = 15.0 + sin(t * 0.6 + 1.0) * 0.7
		escort_ship.rotation.z = sin(t * 0.4 + 0.5) * 0.02

	# 立体云块向后掠过飞空艇
	for puff: Node3D in cloud_nodes:
		var spd: float = puff.get_meta("speed", 36.0)
		puff.position.z += spd * delta
		if puff.position.z > 30.0:
			puff.position.z = -220.0


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE and settings_panel.visible:
		_toggle_settings()
