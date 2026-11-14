extends CanvasLayer
## 行动界面：机甲状态卡、武装卡、雷达、目标、撤离读条、搜刮面板、暂停菜单。

const Prof = preload("res://scripts/prof.gd")
const A = preload("res://scripts/art.gd")
const UI = preload("res://scripts/ui.gd")
const K = preload("res://scripts/hub_kit.gd")
const Icons = preload("res://scripts/item_icons.gd")
const HL = preload("res://scripts/hud_l.gd")
const RadioWindow = preload("res://scripts/story/radio_window.gd")
const RaidInv = preload("res://scripts/raid_inv.gd")

var raid
var root: Control
# L 形状态栏
var holo
var ammo_cols := {}
var skill_slots := {}
var energy_strip
var cargo_strip
# 右上
var radar
var inv_btn: Button
var map_btn: Button
var pause_btn: Button
var transport_panel: PanelContainer
var transport_lbl: Label
# 消耗品
var item_cards := {}
# 中央
var zone_banner: Control
var zone_sub_lbl: Label
var zone_title_lbl: Label
var _zone_tw: Tween
var _zone_active := false
var boss_panel: PanelContainer
var boss_bar: ProgressBar
var boss_lbl: Label
var boss_hp_lbl: Label
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
# 局内战术整备与搜刮面板
var loot_panel: Control
var pause_dim: ColorRect
var pause_panel: PanelContainer
var settings_panel: PanelContainer
var hurt_t := 0.0
var smoke_rect: ColorRect
var scope_rect: ColorRect
var _scope_alpha := 0.0
var last_toggle_frame := -1
var radio                       ## 无线电通讯小窗：剧情流程在行动中把通讯推到它上面
var touch_layer: Control        ## 手机端双摇杆与触控快捷按键层
var joy_left                    ## 左虚拟摇杆（移动）
var joy_right                   ## 右虚拟摇杆（瞄准 + 射击）
var _touch_revealed := false


# ---- 结算界面与机库共用的样式与标签工厂 ----
static func style(bg := UI.BG, border := UI.LINE) -> StyleBox:
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
	g2.offsets = PackedFloat32Array([0.0, 0.68, 1.0])
	g2.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.0), Color(0.02, 0.02, 0.02, 0.45)])
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
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec2 cam_off = vec2(0.0);
uniform vec4 tint : source_color = vec4(0.66, 0.63, 0.56, 1.0);
uniform float strength = 0.018;
void fragment(){
	vec2 uv = (UV * vec2(1.78, 1.0) * 2.2 + cam_off) * 0.12;
	float t = TIME * 0.003;
	float c = texture(noise_tex, uv + vec2(t, t * 0.4)).r;
	c = texture(noise_tex, uv * 0.6 + vec2(c * 0.2, -t)).r;
	float edge = smoothstep(0.18, 0.72, length(UV - vec2(0.5)));
	float m = smoothstep(0.45, 0.80, c) * edge;
	COLOR = vec4(tint.rgb, m * strength);
}
"""
	sm.shader = sh
	sm.set_shader_parameter("noise_tex", A.noise_tex("grime_raw"))
	smoke_rect.material = sm
	root.add_child(smoke_rect)
	root.add_child(vignette)
	scope_rect = ColorRect.new()
	scope_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope_rect.z_index = 15
	scope_rect.visible = false
	var scm := ShaderMaterial.new()
	var scs := Shader.new()
	scs.code = """
shader_type canvas_item;
uniform float alpha = 0.0;
uniform vec2 center_px = vec2(640.0, 360.0);
uniform vec2 vp_size = vec2(1280.0, 720.0);
uniform float radius_px = 230.0;
void fragment(){
	vec2 p = UV * vp_size;
	vec2 d = p - center_px;
	float r = length(d);
	float outer = smoothstep(radius_px - 2.5, radius_px + 1.0, r);
	vec3 col = vec3(0.0);
	float a = outer * alpha;
	// 光学镜筒内壁压暗与金属环圈
	float rim = smoothstep(radius_px - 14.0, radius_px - 4.0, r) * (1.0 - outer);
	float edge_vig = smoothstep(radius_px * 0.62, radius_px - 6.0, r) * (1.0 - outer);
	a = max(a, edge_vig * 0.42 * alpha);
	col = mix(col, vec3(0.05, 0.06, 0.07), rim * (1.0 - outer));
	float bevel = exp(-pow((r - (radius_px - 6.0)) * 0.45, 2.0)) * (1.0 - outer);
	col += vec3(0.24, 0.28, 0.30) * bevel;
	a = max(a, bevel * 0.55 * alpha);
	// 镜内精确分化线与测距刻痕
	if (r < radius_px - 5.0) {
		float in_gap = step(7.5, r);
		float thin_h = (1.0 - smoothstep(0.5, 1.35, abs(d.y))) * step(abs(d.x), radius_px - 8.0) * in_gap;
		float thin_v = (1.0 - smoothstep(0.5, 1.35, abs(d.x))) * step(abs(d.y), radius_px - 8.0) * in_gap;
		float post_h = (1.0 - smoothstep(1.6, 2.8, abs(d.y))) * step(radius_px * 0.48, abs(d.x)) * step(abs(d.x), radius_px - 7.0);
		float post_v = (1.0 - smoothstep(1.6, 2.8, abs(d.x))) * step(radius_px * 0.48, abs(d.y)) * step(abs(d.y), radius_px - 7.0);
		float tx = abs(mod(abs(d.x) + 13.0, 26.0) - 13.0);
		float ty = abs(mod(abs(d.y) + 13.0, 26.0) - 13.0);
		float tick_h = (1.0 - smoothstep(0.5, 1.2, tx)) * (1.0 - smoothstep(3.5, 5.2, abs(d.y))) * step(18.0, abs(d.x)) * step(abs(d.x), radius_px * 0.46);
		float tick_v = (1.0 - smoothstep(0.5, 1.2, ty)) * (1.0 - smoothstep(3.5, 5.2, abs(d.x))) * step(18.0, abs(d.y)) * step(abs(d.y), radius_px * 0.46);
		float ring_m = exp(-pow((r - radius_px * 0.32) * 0.75, 2.0)) * 0.45;
		float center_dot = 1.0 - smoothstep(1.4, 2.5, r);
		float ret = clamp(max(max(thin_h, thin_v) * 0.65, max(max(post_h, post_v) * 0.9, max(max(tick_h, tick_v) * 0.7, max(ring_m, center_dot)))), 0.0, 1.0);
		vec3 ret_col = mix(vec3(0.04, 0.04, 0.04), vec3(0.95, 0.76, 0.34), max(center_dot, max(thin_h, thin_v) * 0.72));
		col = mix(col, ret_col, ret);
		a = max(a, ret * 0.92 * alpha);
	}
	COLOR = vec4(col, a);
}
"""
	scm.shader = scs
	scope_rect.material = scm
	root.add_child(scope_rect)

	# 驾驶舱面罩四角极简取景角标（纯视觉不拦截鼠标）
	var visor := Control.new()
	visor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visor.draw.connect(func():
		var sz := visor.size
		var pad := 10.0
		var arm := 14.0
		var col := Color(0.86, 0.72, 0.36, 0.24)
		for pt in [Vector2(pad, pad), Vector2(sz.x - pad, pad), Vector2(pad, sz.y - pad), Vector2(sz.x - pad, sz.y - pad)]:
			var sx := 1.0 if pt.x < sz.x * 0.5 else -1.0
			var sy := 1.0 if pt.y < sz.y * 0.5 else -1.0
			visor.draw_line(pt, pt + Vector2(arm * sx, 0), col, 1.5)
			visor.draw_line(pt, pt + Vector2(0, arm * sy), col, 1.5))
	root.add_child(visor)

	_touch_revealed = OS.has_feature("mobile")
	_build_status()
	_build_radar()
	_build_weapons()
	_build_touch_controls()
	_build_center()
	_build_loot_panel()
	pause_dim = ColorRect.new()
	pause_dim.color = Color(0.015, 0.018, 0.025, 0.72)
	pause_dim.z_index = 38
	pause_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_dim.visible = false
	root.add_child(pause_dim)
	_build_pause_panel()
	_build_settings_panel()

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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_cursor()


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
	# 竖轨（子弹栏）：贴在拐角上方（HD2 扁平战术装甲背板）
	var rail_w := 100.0
	var rail_h := 230.0
	var rv := Control.new()
	rv.position = Vector2(10, base_y - rail_h - 14)
	rv.size = Vector2(rail_w, rail_h + 20)
	rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rv.draw.connect(func():
		var sz := rv.size
		var ch := 10.0
		var pts := PackedVector2Array([
			Vector2(0.0, ch), Vector2(ch, 0.0), Vector2(sz.x, 0.0),
			Vector2(sz.x, sz.y), Vector2(0.0, sz.y),
		])
		rv.draw_colored_polygon(pts, Color(0.085, 0.092, 0.098, 0.93))
		var opt_pts := PackedVector2Array([
			Vector2(0.0, ch), Vector2(ch, 0.0), Vector2(sz.x, 0.0),
			Vector2(sz.x, sz.y), Vector2(0.0, sz.y), Vector2(0.0, ch),
		])
		rv.draw_polyline(opt_pts, Color(0.22, 0.24, 0.26, 0.96), 1.5, true)
		# 顶部工业灰黑护盖与做旧橙黄警示块
		rv.draw_rect(Rect2(ch, 0.0, sz.x - ch, 4.0), Color(0.20, 0.22, 0.24, 0.96))
		rv.draw_rect(Rect2(ch, 4.0, 26.0, 3.0), Color(0.78, 0.48, 0.16, 0.95))
		rv.draw_rect(Rect2(sz.x - 20.0, 4.0, 14.0, 3.0), Color(0.78, 0.48, 0.16, 0.85))
		# 铆钉与中轴隔离梁
		for rp in [Vector2(sz.x - 6.0, 10.0), Vector2(6.0, sz.y - 6.0), Vector2(sz.x - 6.0, sz.y - 6.0)]:
			rv.draw_rect(Rect2(rp - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), Color(0.44, 0.47, 0.50, 0.85))
		rv.draw_line(Vector2(sz.x * 0.5, 10.0), Vector2(sz.x * 0.5, sz.y - 10.0), Color(0.34, 0.37, 0.39, 0.82), 1.5))
	L.add_child(rv)
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
		i += 1
	# 横轨（技能栏）：从拐角右侧伸出，仅保留 SPACE（底盘机动）与 F（背部挂载）两个核心主动子系统槽
	var keys := [["space", Loc.space_key()], ["f", "F"]]
	var sw := 92.0
	var rh_w := sw * keys.size() + 26.0
	var rh := Control.new()
	rh.position = Vector2(CH - 8, 560 - 104)
	rh.size = Vector2(rh_w, 88)
	rh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rh.draw.connect(func():
		var sz := rh.size
		var ch := 10.0
		var pts := PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(sz.x - ch, 0.0), Vector2(sz.x, ch),
			Vector2(sz.x, sz.y), Vector2(0.0, sz.y),
		])
		rh.draw_colored_polygon(pts, Color(0.085, 0.092, 0.098, 0.93))
		var outline := PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(sz.x - ch, 0.0), Vector2(sz.x, ch),
			Vector2(sz.x, sz.y), Vector2(0.0, sz.y), Vector2(0.0, 0.0),
		])
		rh.draw_polyline(outline, Color(0.22, 0.24, 0.26, 0.96), 1.5, true)
		rh.draw_rect(Rect2(0.0, 0.0, sz.x - ch, 2.5), Color(0.24, 0.26, 0.28, 0.92))
		rh.draw_rect(Rect2(sz.x - 5.0, ch + 2.0, 5.0, sz.y - ch - 6.0), Color(0.78, 0.48, 0.16, 0.94))
		rh.draw_rect(Rect2(6.0, sz.y - 16.0, sz.x - 16.0, 10.0), Color(0.042, 0.047, 0.052, 0.94))
		rh.draw_rect(Rect2(6.0, sz.y - 16.0, sz.x - 16.0, 10.0), Color(0.28, 0.31, 0.33, 0.85), false, 1.0))
	L.add_child(rh)
	for j in keys.size():
		var ss = HL.SkillSlot.new()
		ss.position = rh.position + Vector2(12 + j * sw, -18)
		ss.size = Vector2(sw - 4, 100)
		L.add_child(ss)
		ss.setup(m, keys[j][0], keys[j][1])
		skill_slots[keys[j][0]] = ss
	energy_strip = HL.EnergyStrip.new()
	energy_strip.mech = m
	energy_strip.position = rh.position + Vector2(8, 88 - 13)
	energy_strip.size = Vector2(rh_w - 20.0, 6)
	energy_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	L.add_child(energy_strip)
	# 拐角：底板 + 全息投影 + 货舱条（HD2 扁平直角护框）
	var cr := Control.new()
	cr.position = Vector2(0, base_y)
	cr.size = Vector2(CH, CH)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.draw.connect(func():
		var sz := cr.size
		var ch := 12.0
		var pts := PackedVector2Array([
			Vector2(ch, 0.0), Vector2(sz.x, 0.0), Vector2(sz.x, sz.y),
			Vector2(0.0, sz.y), Vector2(0.0, ch),
		])
		cr.draw_colored_polygon(pts, Color(0.082, 0.088, 0.094, 0.95))
		var outline := PackedVector2Array([
			Vector2(ch, 0.0), Vector2(sz.x, 0.0), Vector2(sz.x, sz.y),
			Vector2(0.0, sz.y), Vector2(0.0, ch), Vector2(ch, 0.0),
		])
		cr.draw_polyline(outline, Color(0.22, 0.24, 0.26, 0.96), 1.5, true)
		# 顶部工业灰黑结构护沿 + 角部铆钉
		cr.draw_rect(Rect2(ch + 1.0, 0.0, sz.x - ch - 2.0, 3.0), Color(0.22, 0.24, 0.26, 0.96))
		cr.draw_rect(Rect2(0.0, ch + 1.0, 3.0, 28.0), Color(0.22, 0.24, 0.26, 0.85))
		cr.draw_rect(Rect2(sz.x - 28.0, 3.0, 22.0, 2.5), Color(0.78, 0.48, 0.16, 0.92))
		var well := Rect2(10.0, 12.0, sz.x - 20.0, 128.0)
		cr.draw_rect(well, Color(0.042, 0.048, 0.052, 0.96))
		cr.draw_rect(well, Color(0.30, 0.34, 0.36, 0.92), false, 1.0)
		var wc := well.position + well.size * 0.5
		cr.draw_line(Vector2(well.position.x + 8.0, wc.y), Vector2(well.end.x - 8.0, wc.y), Color(0.56, 0.62, 0.60, 0.14), 1.0)
		cr.draw_line(Vector2(wc.x, well.position.y + 8.0), Vector2(wc.x, well.end.y - 8.0), Color(0.56, 0.62, 0.60, 0.14), 1.0)
		var yc := Color(0.78, 0.48, 0.16, 0.94)
		var arm := 9.0
		cr.draw_line(well.position, well.position + Vector2(arm, 0.0), yc, 2.0, true)
		cr.draw_line(well.position, well.position + Vector2(0.0, arm), yc, 2.0, true)
		var wtr := Vector2(well.end.x, well.position.y)
		cr.draw_line(wtr, wtr + Vector2(-arm, 0.0), yc, 2.0, true)
		cr.draw_line(wtr, wtr + Vector2(0.0, arm), yc, 2.0, true)
		var wbl := Vector2(well.position.x, well.end.y)
		cr.draw_line(wbl, wbl + Vector2(arm, 0.0), yc, 2.0, true)
		cr.draw_line(wbl, wbl + Vector2(0.0, -arm), yc, 2.0, true)
		cr.draw_line(well.end, well.end + Vector2(-arm, 0.0), yc, 2.0, true)
		cr.draw_line(well.end, well.end + Vector2(0.0, -arm), yc, 2.0, true)
		cr.draw_rect(Rect2(14.0, 145.0, sz.x - 28.0, 10.0), Color(0.04, 0.045, 0.05, 0.94))
		cr.draw_rect(Rect2(14.0, 145.0, sz.x - 28.0, 10.0), Color(0.32, 0.35, 0.37, 0.72), false, 1.0))
	L.add_child(cr)
	holo = HL.HoloPortrait.new()
	holo.position = Vector2(12, base_y + 15)
	holo.size = Vector2(CH - 24, 122)
	holo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	L.add_child(holo)
	holo.setup(m)
	cargo_strip = HL.CargoStrip.new()
	cargo_strip.mech = m
	cargo_strip.position = Vector2(16, base_y + 147)
	cargo_strip.size = Vector2(CH - 32, 6)
	cargo_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	L.add_child(cargo_strip)


func _hud_icon_btn(tip: String, tex: Texture2D = null, draw_pause := false) -> Button:
	var b := Button.new()
	b.text = ""
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(36, 30)
	b.focus_mode = Control.FOCUS_NONE
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cc)
	if draw_pause:
		var ic := Control.new()
		ic.custom_minimum_size = Vector2(14, 14)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.draw.connect(func():
			ic.draw_rect(Rect2(2, 1, 4, 12), UI.TEXT)
			ic.draw_rect(Rect2(8, 1, 4, 12), UI.TEXT))
		cc.add_child(ic)
	elif tex != null:
		cc.add_child(K.icon_rect(tex, 18))
	return b


func _build_radar() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	v.offset_right = -18
	v.offset_top = 14
	v.offset_left = -258
	v.add_theme_constant_override("separation", 6)
	root.add_child(v)
	var top_bar := HBoxContainer.new()
	top_bar.alignment = BoxContainer.ALIGNMENT_END
	top_bar.add_theme_constant_override("separation", 6)
	v.add_child(top_bar)
	inv_btn = _hud_icon_btn(Loc.t("战术整备 [TAB]", "Field Loadout [TAB]"), Icons.ui_icon("nav_stash"))
	inv_btn.pressed.connect(toggle_inventory)
	top_bar.add_child(inv_btn)
	map_btn = _hud_icon_btn(Loc.t("战术地图 [M]", "Sector Map [M]"), Icons.ui_icon("nav_deploy"))
	map_btn.pressed.connect(toggle_map)
	top_bar.add_child(map_btn)
	pause_btn = _hud_icon_btn(Loc.t("暂停 [ESC]", "Pause [ESC]"), null, true)
	pause_btn.pressed.connect(toggle_pause)
	top_bar.add_child(pause_btn)
	radar = UI.Radar.new()
	radar.raid = raid
	radar.custom_minimum_size = Vector2(184, 184)
	radar.size_flags_horizontal = Control.SIZE_SHRINK_END
	radar.mouse_filter = Control.MOUSE_FILTER_STOP
	radar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	radar.gui_input.connect(func(ev: InputEvent):
		if (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
			toggle_map()
			radar.accept_event())
	v.add_child(radar)
	transport_panel = UI.panel(8)
	transport_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	transport_panel.visible = false
	v.add_child(transport_panel)
	transport_lbl = UI.label("", 12, UI.EN_C, true)
	transport_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transport_panel.add_child(transport_lbl)


func _card(key: String, item_id := "") -> Dictionary:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", K.px9("card9", 6, 6, 6, 6))
	p.custom_minimum_size = Vector2(60, 60)
	p.mouse_entered.connect(func(): p.add_theme_stylebox_override("panel", K.px9("card9_on", 6, 6, 6, 6)))
	p.mouse_exited.connect(func(): p.add_theme_stylebox_override("panel", K.px9("card9", 6, 6, 6, 6)))
	var box := Control.new()
	box.custom_minimum_size = Vector2(48, 48)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(box)
	if item_id != "":
		var ic := K.icon_rect(Icons.icon(item_id), 38)
		ic.position = Vector2(5, 5)
		ic.size = Vector2(38, 38)
		box.add_child(ic)
	var kc := UI.keycap(key, 11)
	kc.position = Vector2(-2, -2)
	kc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(kc)
	var sub := UI.label("", 12, UI.TEXT, true)
	sub.position = Vector2(18, 32)
	sub.size = Vector2(28, 16)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(sub)
	var cd = UI.CooldownTile.new()
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_child(cd)
	return {"panel": p, "sub": sub, "cd": cd}


func _build_weapons() -> void:
	# 消耗品：右下角紧凑纯图标槽（像素物品图标 + 键帽 + 数量，无文字说明，支持触控点击）
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	h.offset_right = -18
	h.offset_bottom = -18
	h.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	h.grow_vertical = Control.GROW_DIRECTION_BEGIN
	h.add_theme_constant_override("separation", 8)
	root.add_child(h)
	for kk in [["1", "fuel_cell", Loc.t("燃料电池 [1]", "Fuel Cell [1]")], ["2", "repair_kit", Loc.t("维修包 [2]", "Repair Kit [2]")], ["T", "beacon", Loc.t("呼叫运输机 [T]", "Call Dropship [T]")]]:
		var c := _card(kk[0], kk[1])
		var item_id: String = kk[1]
		c.panel.tooltip_text = kk[2]
		c.panel.mouse_filter = Control.MOUSE_FILTER_STOP
		c.panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		c.panel.gui_input.connect(func(ev: InputEvent):
			if (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
				if raid and raid.mech and not raid.mech.input_locked:
					if item_id == "beacon":
						raid.call_transport()
					else:
						raid.mech.use_item(item_id)
				c.panel.accept_event())
		h.add_child(c.panel)
		item_cards[item_id] = c


func _build_touch_controls() -> void:
	touch_layer = Control.new()
	touch_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(touch_layer)
	# 左摇杆：左下子弹轨右侧、SPACE/F 技能栏上方（左手拇指舒适区）
	joy_left = HL.TouchStick.new(Loc.t("移动", "Move"), false)
	joy_left.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	joy_left.offset_left = 148
	joy_left.offset_right = 148 + 156
	joy_left.offset_bottom = -176
	joy_left.offset_top = -176 - 156
	touch_layer.add_child(joy_left)
	# 右摇杆：右下消耗品卡上方（右手拇指瞄准与推到底自动射击）
	joy_right = HL.TouchStick.new(Loc.t("瞄准 / 射击", "Aim / Fire"), true)
	joy_right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	joy_right.offset_right = -32
	joy_right.offset_left = -32 - 156
	joy_right.offset_bottom = -94
	joy_right.offset_top = -94 - 156
	touch_layer.add_child(joy_right)
	# 右摇杆外弧快捷触控键：右手拇指不离开右半屏即可触发 SPACE 冲刺、F 机能与手动换弹
	var m = raid.mech
	var b_dash := HL.TouchBtn.new()
	b_dash.setup(m, "dash", Loc.t("冲刺", "Dash"), Loc.space_key(), 28.0)
	b_dash.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	b_dash.offset_right = -204
	b_dash.offset_left = -204 - 56
	b_dash.offset_bottom = -162
	b_dash.offset_top = -162 - 56
	touch_layer.add_child(b_dash)
	var b_ab := HL.TouchBtn.new()
	b_ab.setup(m, "ability", Loc.t("机能", "Ability"), "F", 28.0)
	b_ab.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	b_ab.offset_right = -158
	b_ab.offset_left = -158 - 56
	b_ab.offset_bottom = -232
	b_ab.offset_top = -232 - 56
	touch_layer.add_child(b_ab)
	var b_rld := HL.TouchBtn.new()
	b_rld.setup(m, "reload", Loc.t("换弹", "Reload"), "R", 25.0)
	b_rld.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	b_rld.offset_right = -212
	b_rld.offset_left = -212 - 50
	b_rld.offset_bottom = -96
	b_rld.offset_top = -96 - 50
	touch_layer.add_child(b_rld)


func is_touch_busy() -> bool:
	return (joy_left != null and joy_left.is_active()) or (joy_right != null and joy_right.is_active())


func _build_center() -> void:
	zone_banner = Control.new()
	zone_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	zone_banner.offset_left = -200
	zone_banner.offset_right = 200
	zone_banner.offset_top = 20
	zone_banner.offset_bottom = 78
	zone_banner.z_index = 18
	zone_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone_banner.visible = false
	zone_banner.draw.connect(func():
		var sz := zone_banner.size
		var slices := 24
		var sw := sz.x / float(slices)
		for k in slices:
			var t := (float(k) + 0.5) / float(slices)
			var w := pow(sin(t * PI), 1.4)
			var x := float(k) * sw
			zone_banner.draw_rect(Rect2(x, 0.0, sw + 0.6, sz.y), Color(0.056, 0.060, 0.066, 0.88 * w))
			zone_banner.draw_rect(Rect2(x, 0.0, sw + 0.6, 2.0), Color(0.28, 0.31, 0.34, 0.94 * w))
			zone_banner.draw_rect(Rect2(x, sz.y - 2.0, sw + 0.6, 2.0), Color(0.78, 0.48, 0.16, 0.82 * w))
		var cx := sz.x * 0.5
		zone_banner.draw_colored_polygon(PackedVector2Array([Vector2(cx, -4), Vector2(cx + 5, 1), Vector2(cx, 6), Vector2(cx - 5, 1)]), Color(0.78, 0.48, 0.16, 0.98))
		zone_banner.draw_colored_polygon(PackedVector2Array([Vector2(cx, -1), Vector2(cx + 2, 1), Vector2(cx, 3), Vector2(cx - 2, 1)]), Color(0.18, 0.20, 0.22, 0.96)))
	root.add_child(zone_banner)
	var zv := VBoxContainer.new()
	zv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	zv.alignment = BoxContainer.ALIGNMENT_CENTER
	zv.add_theme_constant_override("separation", 1)
	zv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone_banner.add_child(zv)
	zone_sub_lbl = UI.label(Loc.t("进入战区", "ENTERING SECTOR"), 12, UI.ACCENT_HI, true)
	zone_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zv.add_child(zone_sub_lbl)
	zone_title_lbl = UI.label("", 22, UI.TEXT, true)
	zone_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zv.add_child(zone_title_lbl)

	boss_panel = UI.panel(10)
	boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_panel.offset_top = 24
	boss_panel.custom_minimum_size = Vector2(460, 0)
	boss_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_panel.visible = false
	root.add_child(boss_panel)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 5)
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_panel.add_child(bv)
	var bh := HBoxContainer.new()
	bh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(bh)
	boss_lbl = UI.label("", 12, UI.BAD, true)
	boss_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(boss_lbl)
	boss_hp_lbl = UI.label("", 12, UI.MUTED, true)
	bh.add_child(boss_hp_lbl)
	boss_bar = ProgressBar.new()
	boss_bar.show_percentage = false
	boss_bar.custom_minimum_size = Vector2(0, 10)
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar.add_theme_stylebox_override("fill", UI.flat_bar(Color(0.86, 0.2, 0.28), Color(1.0, 0.45, 0.52), 1, 0))
	bv.add_child(boss_bar)

	extract_panel = UI.panel(12)
	extract_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	extract_panel.offset_top = 116
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
	extract_bar.add_theme_stylebox_override("fill", UI.flat_bar(UI.GOOD, Color(0, 0, 0, 0), 0, 0))
	ev.add_child(extract_bar)

	prompt_panel = PanelContainer.new()
	prompt_panel.add_theme_stylebox_override("panel", UI.tex9("prompt9", 10, 12))
	prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt_panel.offset_top = 70
	prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	prompt_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	prompt_panel.gui_input.connect(func(ev: InputEvent):
		if (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
			if raid:
				raid.interact_nearest()
			prompt_panel.accept_event())
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
	loot_panel = RaidInv.new(raid, self)
	root.add_child(loot_panel)


func _build_pause_panel() -> void:
	pause_panel = PanelContainer.new()
	pause_panel.add_theme_stylebox_override("panel", K.px9("panel9", 16, 16, 16, 14))
	pause_panel.z_index = 40   # 同上：暂停时盖住世界里的指示标签
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.custom_minimum_size = Vector2(380, 0)
	pause_panel.offset_left = -190
	pause_panel.offset_right = 190
	pause_panel.offset_top = -140
	pause_panel.offset_bottom = 140
	pause_panel.visible = false
	root.add_child(pause_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pause_panel.add_child(v)
	v.add_child(UI.plate_header(Loc.t("行动暂停", "Mission Paused"), "PAUSE"))
	v.add_child(K.hazard_strip(8))
	var b1 := K.primary(Loc.t("继续行动", "Resume"), 38)
	b1.set_meta("sfx", "")   # toggle_pause 自己播放关闭音效
	b1.pressed.connect(toggle_pause)
	v.add_child(b1)
	var bset := Button.new()
	bset.text = Loc.t("游戏设置", "Settings")
	bset.custom_minimum_size = Vector2(0, 38)
	bset.set_meta("sfx", "")
	bset.pressed.connect(_open_settings)
	v.add_child(bset)
	var b2 := Button.new()
	b2.text = Loc.t("放弃行动（失去机甲与货物）", "Abandon Sortie (Lose Mech & Cargo)")
	b2.custom_minimum_size = Vector2(0, 38)
	b2.set_meta("sfx", "ui_confirm")
	b2.add_theme_color_override("font_color", UI.BAD)
	b2.pressed.connect(func():
		pause_panel.visible = false
		raid.abandon())
	v.add_child(b2)


## 行动内设置：画面、声音与语言，暂停中打开，不压任何常驻 HUD
func _build_settings_panel(initial_tab := "video") -> void:
	settings_panel = PanelContainer.new()
	settings_panel.add_theme_stylebox_override("panel", K.px9("panel9", 16, 16, 16, 14))
	settings_panel.z_index = 50
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	settings_panel.offset_left = -310
	settings_panel.offset_right = 310
	settings_panel.offset_top = -225
	settings_panel.offset_bottom = 225
	settings_panel.visible = false
	root.add_child(settings_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	settings_panel.add_child(v)
	v.add_child(UI.plate_header(Loc.t("游戏设置", "Settings"), "SETTINGS"))
	v.add_child(K.hazard_strip(8))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", 6)
	nav.custom_minimum_size = Vector2(100, 0)
	row.add_child(nav)
	var body := PanelContainer.new()
	body.add_theme_stylebox_override("panel", K.px9("inset9", 8, 8, 12, 10))
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(body)
	var tab_defs := [
		["video", Loc.t("画面", "Video")],
		["audio", Loc.t("声音", "Audio")],
		["other", Loc.t("常规", "General")],
	]
	var pages := {}
	for td in tab_defs:
		var pg := VBoxContainer.new()
		pg.add_theme_constant_override("separation", 8)
		pg.visible = false
		body.add_child(pg)
		pages[str(td[0])] = pg
	var nav_btns := {}
	var show_page := func(key: String):
		for k in pages:
			(pages[k] as Control).visible = k == key
		for k in nav_btns:
			var b: Button = nav_btns[k]
			var on: bool = (k == key)
			b.add_theme_stylebox_override("normal", K.px9("nav9_on" if on else "nav9_n", 10, 10, 10, 6))
			b.add_theme_stylebox_override("hover", K.px9("nav9_on" if on else "nav9_h", 10, 10, 10, 6))
			b.add_theme_color_override("font_color", UI.GOLD if on else UI.TEXT)
	for td in tab_defs:
		var key: String = str(td[0])
		var b := Button.new()
		b.text = str(td[1])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(100, 34)
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("sfx", "")
		b.pressed.connect(func(): show_page.call(key))
		nav.add_child(b)
		nav_btns[key] = b
	show_page.call(initial_tab if pages.has(initial_tab) else "video")

	# ---- 画面 ----
	var pgv: VBoxContainer = pages["video"]
	var fs := CheckButton.new()
	fs.text = Loc.t("全屏", "Fullscreen")
	fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs.toggled.connect(func(on): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	pgv.add_child(fs)
	var vs := CheckButton.new()
	vs.text = Loc.t("垂直同步", "VSync")
	vs.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	vs.toggled.connect(func(on): DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED))
	pgv.add_child(vs)
	pgv.add_child(UI.label(Loc.t("画质", "Quality"), 14, UI.MUTED))
	var q := OptionButton.new()
	for i in GameData.QUALITY_NAMES.size():
		q.add_item(str(GameData.QUALITY_NAMES[i]), i)
	q.selected = GameData.quality
	q.item_selected.connect(func(i):
		GameData.quality = i
		GameData.apply_quality(get_viewport())
		GameData.save_game())
	pgv.add_child(q)

	# ---- 声音 ----
	var pgv2: VBoxContainer = pages["audio"]
	for bus in [["Master", Loc.t("主音量", "Master")], ["Music", Loc.t("音乐", "Music")], ["SFX", Loc.t("音效", "SFX")], ["Voice", Loc.t("语音", "Voice")]]:
		pgv2.add_child(UI.label(str(bus[1]), 14, UI.MUTED))
		var vol := HSlider.new()
		vol.min_value = 0
		vol.max_value = 1
		vol.step = 0.05
		vol.value = Audio.get_volume(str(bus[0]))
		vol.custom_minimum_size = Vector2(0, 22)
		var bus_name := str(bus[0])
		vol.value_changed.connect(func(x): Audio.set_volume(bus_name, x))
		pgv2.add_child(vol)

	# ---- 常规 ----
	var pgv3: VBoxContainer = pages["other"]
	pgv3.add_child(UI.label(Loc.t("界面语言", "Language"), 14, UI.MUTED))
	var lang_opt := OptionButton.new()
	lang_opt.add_item("简体中文", 0)
	lang_opt.add_item("English", 1)
	lang_opt.selected = 1 if Loc.is_en() else 0
	lang_opt.item_selected.connect(func(i):
		Loc.set_lang("zh" if i == 0 else "en")
		call_deferred("refresh_lang", true, "other"))
	pgv3.add_child(lang_opt)

	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(line)
	var back := Button.new()
	back.text = Loc.t("返回", "Back")
	back.custom_minimum_size = Vector2(120, 36)
	back.set_meta("sfx", "")
	back.pressed.connect(_close_settings)
	line.add_child(back)


func _open_settings() -> void:
	last_toggle_frame = Engine.get_process_frames()
	pause_panel.visible = false
	settings_panel.visible = true
	get_tree().paused = not Net.active()
	Audio.play_ui("ui_open")
	_update_cursor()


func _close_settings() -> void:
	last_toggle_frame = Engine.get_process_frames()
	settings_panel.visible = false
	pause_panel.visible = true
	get_tree().paused = not Net.active()
	Audio.play_ui("ui_close")
	_update_cursor()


# ============================================================ 交互
func toggle_pause() -> void:
	last_toggle_frame = Engine.get_process_frames()
	if settings_panel != null and settings_panel.visible:
		_close_settings()
		return
	pause_panel.visible = not pause_panel.visible
	get_tree().paused = pause_panel.visible and not Net.active()
	Audio.play_ui("ui_open" if pause_panel.visible else "ui_close")
	_update_cursor()


func map_open() -> bool:
	return bigmap != null and bigmap.visible


func inv_open() -> bool:
	return loot_panel != null and loot_panel.visible


func toggle_inventory() -> void:
	if pause_panel.visible or (settings_panel != null and settings_panel.visible) or raid.ended:
		return
	if map_open():
		bigmap.visible = false
	last_toggle_frame = Engine.get_process_frames()
	if loot_panel.visible:
		raid.close_box()
	else:
		raid.mech.input_locked = true
		set_prompt("")
		open_loot(raid.open_box)
		Audio.play_ui("ui_open")


func show_zone_banner(zone_name: String, delay := 0.08) -> void:
	if zone_banner == null or zone_name == "":
		return
	if _zone_tw != null and is_instance_valid(_zone_tw):
		_zone_tw.kill()
	zone_sub_lbl.text = Loc.t("进入战区", "ENTERING SECTOR")
	zone_title_lbl.text = zone_name
	_zone_active = true
	zone_banner.visible = true
	zone_banner.modulate.a = 0.0
	zone_banner.offset_top = 14
	zone_banner.offset_bottom = 72
	_zone_tw = create_tween()
	if delay > 0.0:
		_zone_tw.tween_interval(delay)
	_zone_tw.tween_property(zone_banner, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zone_tw.parallel().tween_property(zone_banner, "offset_top", 22.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zone_tw.parallel().tween_property(zone_banner, "offset_bottom", 80.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zone_tw.tween_interval(1.9)
	_zone_tw.tween_property(zone_banner, "modulate:a", 0.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_zone_tw.parallel().tween_property(zone_banner, "offset_top", 18.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_zone_tw.parallel().tween_property(zone_banner, "offset_bottom", 76.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_zone_tw.tween_callback(func():
		_zone_active = false
		if zone_banner != null:
			zone_banner.visible = false)


func on_loadout_changed() -> void:
	var m = raid.mech
	if m == null:
		return
	for slot in ["arm_l", "arm_r"]:
		if ammo_cols.has(slot):
			ammo_cols[slot].setup(m, slot)
	for pair in [["space", Loc.space_key()], ["f", "F"]]:
		var k: String = pair[0]
		if skill_slots.has(k):
			skill_slots[k].setup(m, k, pair[1])
	if holo != null:
		holo.setup(m)
	refresh_loot()


func toggle_map() -> void:
	if pause_panel.visible or (settings_panel != null and settings_panel.visible) or loot_panel.visible or raid.ended:
		return
	bigmap.visible = not bigmap.visible
	Audio.play_ui("ui_open" if bigmap.visible else "ui_close")
	last_toggle_frame = Engine.get_process_frames()
	_update_cursor()


func _update_cursor() -> void:
	var menu_open: bool = pause_panel.visible or (settings_panel != null and settings_panel.visible)
	var ui_open: bool = menu_open or loot_panel.visible or raid.ended or map_open()
	if pause_dim != null:
		pause_dim.visible = menu_open
	if zone_banner != null:
		zone_banner.visible = _zone_active and not ui_open
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	crosshair.visible = not ui_open and _scope_alpha < 0.35
	if touch_layer != null:
		touch_layer.visible = _touch_revealed and not ui_open
		if ui_open:
			if joy_left != null and joy_left.is_active():
				joy_left.release()
			if joy_right != null and joy_right.is_active():
				joy_right.release()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not _touch_revealed:
		_touch_revealed = true
		_update_cursor()


func _unhandled_input(event: InputEvent) -> void:
	if settings_panel != null and settings_panel.visible and event.is_action_pressed("pause"):
		_close_settings()
		get_viewport().set_input_as_handled()
		return
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
	if transport_panel != null:
		if raid.transport_state == "incoming":
			transport_panel.visible = true
			transport_lbl.text = "%ds" % int(ceilf(raid.transport_t))
		elif raid.transport_state == "landed":
			transport_panel.visible = true
			transport_lbl.text = "%ds · %dm" % [int(ceilf(raid.transport_t)), int(raid.transport_zone.global_position.distance_to(m.global_position))]
		else:
			transport_panel.visible = false

	for id in item_cards.keys():
		var c: Dictionary = item_cards[id]
		var n: int = m.cargo.count(id)
		c.sub.text = "%d" % n if n > 0 else ""
		c.panel.modulate.a = 1.0 if n > 0 else 0.42


func _refresh_fast(m) -> void:
	# 首领血条（仅显示已苏醒且在玩家交战/感知范围内的最近首领）
	var boss_node = null
	var best_score := 1e9
	var max_bar_d: float = maxf(raid.lose_range() * 1.35, 56.0) if (raid != null and raid.has_method("lose_range")) else 56.0
	for bn in get_tree().get_nodes_in_group("boss"):
		if bn == null or not is_instance_valid(bn) or bn.dying:
			continue
		if not bn.awake:
			continue
		var d: float = bn.global_position.distance_to(m.global_position)
		if d > max_bar_d:
			continue
		if d < best_score:
			best_score = d
			boss_node = bn
	if boss_node != null:
		boss_panel.visible = true
		boss_panel.offset_top = 88 if _zone_active else 24
		var ph_roman := "I" if int(boss_node.phase) <= 1 else ("II" if int(boss_node.phase) == 2 else "III")
		var btitle: String = str(GameData.ENEMIES.get(str(boss_node.boss_id), {}).get("name", boss_node.title)) if "boss_id" in boss_node else str(boss_node.title)
		var weak_tag := Loc.t("  [★ 晶核暴露]", "  [★ CORE EXPOSED]") if float(boss_node.core_open) > 0.0 else ""
		boss_lbl.text = Loc.t("▲ 战区首领 · %s   阶段 %s%s", "▲ Sector Boss · %s   Phase %s%s") % [btitle, ph_roman, weak_tag]
		boss_hp_lbl.text = "%d / %d" % [ceili(maxf(float(boss_node.hp), 0.0)), int(boss_node.data.get("hp", 1000.0))]
		boss_bar.max_value = 1.0
		boss_bar.value = float(boss_node.hp_ratio())
	elif boss_panel != null:
		boss_panel.visible = false

	# 撤离读条
	if raid.extract_target and not raid.ended:
		extract_panel.visible = true
		extract_panel.offset_top = 90 if _zone_active else 32
		extract_lbl.text = Loc.t("正在撤离 · %s", "Extracting · %s") % raid.extract_target.title
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
	if scope_rect != null:
		var ui_open_sc: bool = pause_panel.visible or (settings_panel != null and settings_panel.visible) or loot_panel.visible or raid.ended or map_open()
		var want_scope: bool = not ui_open_sc and m.is_scoping()
		_scope_alpha = move_toward(_scope_alpha, 1.0 if want_scope else 0.0, maxf(get_process_delta_time(), 0.016) * 9.0)
		scope_rect.visible = _scope_alpha > 0.005
		if scope_rect.visible:
			var vp_sz := get_viewport().get_visible_rect().size
			var cpx := vp_sz * 0.5
			if raid.aim_override != null or raid._joy_aim_active or is_touch_busy():
				if raid.camera != null:
					cpx = raid.camera.unproject_position(m.aim_point)
			else:
				cpx = get_viewport().get_mouse_position().clamp(Vector2.ZERO, vp_sz)
			var scm := scope_rect.material as ShaderMaterial
			scm.set_shader_parameter("alpha", _scope_alpha)
			scm.set_shader_parameter("vp_size", vp_sz)
			scm.set_shader_parameter("center_px", cpx)
			scm.set_shader_parameter("radius_px", minf(vp_sz.x, vp_sz.y) * 0.34)
	_update_markers()
	_update_cursor()


func _update_markers() -> void:
	for z in markers.keys():
		if is_instance_valid(markers[z]):
			markers[z].visible = false


func open_loot(_b) -> void:
	loot_panel.visible = true
	_update_cursor()
	refresh_loot()


func close_loot() -> void:
	loot_panel.visible = false
	_update_cursor()


func _process(_d: float) -> void:
	var _pt := Prof.t0()
	_process_impl(_d)
	Prof.add("proc.hud", _pt)


func _process_impl(_d: float) -> void:
	pass


func refresh_loot() -> void:
	if loot_panel != null and loot_panel.visible and loot_panel.has_method("refresh"):
		loot_panel.refresh()


func refresh_lang(keep_settings_open := false, settings_tab := "other") -> void:
	if raid != null and raid.has_method("refresh_lang"):
		raid.refresh_lang()
	if inv_btn != null:
		inv_btn.tooltip_text = Loc.t("战术整备 [TAB]", "Field Loadout [TAB]")
	if map_btn != null:
		map_btn.tooltip_text = Loc.t("战术地图 [M]", "Sector Map [M]")
	if pause_btn != null:
		pause_btn.tooltip_text = Loc.t("暂停 [ESC]", "Pause [ESC]")
	var tips := {
		"fuel_cell": Loc.t("燃料电池 [1]", "Fuel Cell [1]"),
		"repair_kit": Loc.t("维修包 [2]", "Repair Kit [2]"),
		"beacon": Loc.t("呼叫运输机 [T]", "Call Dropship [T]"),
	}
	for id in tips:
		if item_cards.has(id):
			item_cards[id].panel.tooltip_text = tips[id]
	if zone_sub_lbl != null:
		zone_sub_lbl.text = Loc.t("进入战区", "ENTERING SECTOR")
	if zone_title_lbl != null and raid != null and raid.MAP is Dictionary:
		zone_title_lbl.text = str(raid.MAP.get("name", ""))
	if log_box != null:
		for c in log_box.get_children():
			c.queue_free()
	if skill_slots.has("space") and raid != null and raid.mech != null:
		skill_slots["space"].setup(raid.mech, "space", Loc.space_key())
	var was_pause_vis: bool = pause_panel != null and pause_panel.visible
	if pause_panel != null and is_instance_valid(pause_panel):
		if pause_panel.get_parent():
			pause_panel.get_parent().remove_child(pause_panel)
		pause_panel.queue_free()
		pause_panel = null
	if settings_panel != null and is_instance_valid(settings_panel):
		if settings_panel.get_parent():
			settings_panel.get_parent().remove_child(settings_panel)
		settings_panel.queue_free()
		settings_panel = null
	_build_pause_panel()
	_build_settings_panel(settings_tab)
	settings_panel.visible = keep_settings_open
	pause_panel.visible = false if keep_settings_open else was_pause_vis
	var was_inv: bool = loot_panel != null and loot_panel.visible
	if loot_panel != null and is_instance_valid(loot_panel):
		if loot_panel.get_parent():
			loot_panel.get_parent().remove_child(loot_panel)
		loot_panel.queue_free()
		loot_panel = null
	_build_loot_panel()
	if was_inv:
		open_loot(raid.open_box)
	if raid != null and raid.has_method("nearest_box"):
		var nb = raid.nearest_box(3.6)
		set_prompt(nb.title if (nb != null and not was_inv) else "")
	if radio != null and is_instance_valid(radio) and radio.has_method("refresh_lang"):
		radio.refresh_lang()
	if radar != null:
		radar.queue_redraw()
	if bigmap != null:
		bigmap.queue_redraw()
	_update_cursor()
