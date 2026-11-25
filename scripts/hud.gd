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
const EnemyHpBars = preload("res://scripts/hud_enemy_bars.gd")
const FcsSpotter = preload("res://scripts/hud_fcs_spotter.gd")

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
var status_root: Control
var ammo_rail: Control
var _ammo_h_l := 0.0
var _ammo_h_r := 0.0
var _ammo_layout_sig := Vector3i(-1, -1, -1)
var sys_clip: Control
var sys_col: VBoxContainer
var coop_bar: PanelContainer
var coop_lbl: Label
var vignette: TextureRect
var markers := {}
var enemy_bars
var fcs_spotter
var crosshair
var bigmap
# 局内战术整备与搜刮面板
var loot_panel: Control
var pause_dim: ColorRect
var pause_panel: PanelContainer
var settings_panel: PanelContainer
var _view_opt: OptionButton
var _fps_cb: CheckButton
var _rs_opt: OptionButton
var _radar_box: VBoxContainer
var hurt_t := 0.0
var smoke_rect: ColorRect
var scope_rect: ColorRect
var _scope_alpha := 0.0
var last_toggle_frame := -1
var radio                       ## 无线电通讯小窗：剧情流程在行动中把通讯推到它上面
var touch_layer: Control        ## 手机端双摇杆与触控快捷按键层
var joy_left                    ## 左虚拟摇杆（移动）
var joy_right                   ## 右虚拟摇杆（瞄准 + 射击）
var joy_fire                    ## 左手辅助开火钮（第一人称模式）
var touch_aim_btn               ## 触控开镜/精密瞄准开关
var touch_view_btn              ## 触控 1/3 人称切换钮
var touch_aim_on := false
var _last_touch_btn_ms := -1000
var _touch_revealed := false


# ---- 结算界面与机库共用的样式与标签工厂 ----
static func style(bg := UI.BG, border := UI.LINE) -> StyleBox:
	return UI.box(bg, border, 1, 2, UI.ACCENT_DIM, 3, 16)


static func label(text := "", size := 16, c := UI.TEXT) -> Label:
	return UI.label(text, size, c, true)


static func _hud_glass_box(bg: Color, accent: Color, left_w := 3, pad_h := 9, pad_v := 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = accent
	sb.set_border_width_all(0)
	sb.border_width_left = left_w
	sb.corner_radius_top_left = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_right = 2
	sb.content_margin_left = pad_h + left_w
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.anti_aliasing = true
	return sb


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
	vignette.visible = false
	# 常驻战地摄影机炭灰光学暗角（收束四角，强化写实工业废土胶片纵深），放在受伤暗角之下
	var g2 := Gradient.new()
	g2.offsets = PackedFloat32Array([0.0, 0.52, 0.82, 1.0])
	g2.colors = PackedColorArray([Color(0.015, 0.018, 0.022, 0.0), Color(0.015, 0.018, 0.022, 0.0), Color(0.015, 0.018, 0.022, 0.16), Color(0.010, 0.012, 0.016, 0.38)])
	var gt2 := GradientTexture2D.new()
	gt2.gradient = g2
	gt2.fill = GradientTexture2D.FILL_RADIAL
	gt2.fill_from = Vector2(0.5, 0.5)
	gt2.fill_to = Vector2(1.06, 0.5)
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
uniform float strength = 0.005;
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
	sm.set_shader_parameter("strength", 0.005)
	smoke_rect.material = sm
	smoke_rect.visible = false
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

	enemy_bars = EnemyHpBars.new()
	enemy_bars.raid = raid
	enemy_bars.hud = self
	root.add_child(enemy_bars)
	fcs_spotter = FcsSpotter.new()
	fcs_spotter.raid = raid
	fcs_spotter.hud = self
	root.add_child(fcs_spotter)

	_touch_revealed = OS.has_feature("mobile") or "--mobile" in OS.get_cmdline_user_args() or "--mobile" in OS.get_cmdline_args()
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


func notify_hit() -> void:
	if crosshair != null and is_instance_valid(crosshair) and crosshair.has_method("trigger_hit"):
		crosshair.trigger_hit()


func notify_enemy_hit(node: Node3D, prev_hp: float, cur_hp: float, max_hp: float) -> void:
	if enemy_bars != null and is_instance_valid(enemy_bars):
		enemy_bars.notify_hit(node, prev_hp, cur_hp, max_hp)


func _exit_tree() -> void:
	if GameData.show_fps_changed.is_connected(_on_show_fps_changed):
		GameData.show_fps_changed.disconnect(_on_show_fps_changed)
	if radio != null and is_instance_valid(radio):
		Story.detach_radio(radio)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ============================================================ 构建
const STATUS_H := 560.0
const CORNER_H := 168.0
const AMMO_RAIL_W := 100.0
const AMMO_TOP_PAD := 14.0
const AMMO_BOT_PAD := 6.0
const AMMO_MIN_COL_H := 28.0
const AMMO_MAX_TOTAL_H := 244.0


func _ammo_rail_max_total_h() -> float:
	var vp_h: float = get_viewport().get_visible_rect().size.y if get_viewport() != null else 720.0
	# 预留顶部无线电窗 + 系统消息区最小高度 + 底部拐角与边距，避免遮挡
	return clampf(vp_h - 470.0, 96.0, AMMO_MAX_TOTAL_H)


func _layout_ammo_rail() -> void:
	if ammo_rail == null or not is_instance_valid(ammo_rail):
		return
	var base_y := STATUS_H - CORNER_H
	var max_total_h := _ammo_rail_max_total_h()
	var max_col_h := maxf(AMMO_MIN_COL_H, max_total_h - AMMO_TOP_PAD - AMMO_BOT_PAD)
	var hs := {"arm_l": 0.0, "arm_r": 0.0}
	for slot in ["arm_l", "arm_r"]:
		var col = ammo_cols.get(slot)
		if col == null or not is_instance_valid(col):
			continue
		var col_h: float = col.preferred_height(max_col_h, AMMO_MIN_COL_H)
		if col_h > 0.0:
			col.position.y = base_y - AMMO_BOT_PAD - col_h
			col.size.y = col_h
			col._layout()
			col.queue_redraw()
			hs[slot] = col_h + AMMO_TOP_PAD + AMMO_BOT_PAD
		else:
			col.position.y = base_y
			col.size.y = 0.0
	_ammo_h_l = float(hs["arm_l"])
	_ammo_h_r = float(hs["arm_r"])
	var max_h := maxf(_ammo_h_l, _ammo_h_r)
	ammo_rail.visible = max_h > 0.5
	ammo_rail.position = Vector2(10.0, base_y - max_h)
	ammo_rail.size = Vector2(AMMO_RAIL_W, max_h)
	ammo_rail.queue_redraw()
	if raid != null and raid.mech != null:
		var vp_hi := int(round(get_viewport().get_visible_rect().size.y)) if get_viewport() != null else 720
		_ammo_layout_sig = Vector3i(int(raid.mech.mag.get("arm_l", 0)), int(raid.mech.mag.get("arm_r", 0)), vp_hi)
	if sys_clip != null and is_instance_valid(sys_clip):
		var want_bottom := -(14.0 + CORNER_H + max_h + 7.0)
		if not is_equal_approx(sys_clip.offset_bottom, want_bottom):
			sys_clip.offset_bottom = want_bottom
			_trim_log_box()


func _draw_ammo_rail() -> void:
	if ammo_rail == null:
		return
	var rv := ammo_rail
	var sz := rv.size
	var hl := _ammo_h_l
	var hr := _ammo_h_r
	var max_h := maxf(hl, hr)
	if max_h <= 0.5 or sz.y <= 0.5:
		return
	var w := sz.x
	var mid := w * 0.5
	var bg_col := Color(0.085, 0.092, 0.098, 0.68)
	var line_col := Color(0.26, 0.28, 0.30, 0.80)
	var cap_col := Color(0.20, 0.22, 0.24, 0.80)
	var warn_l := Color(0.78, 0.48, 0.16, 0.86)
	var warn_r := Color(0.78, 0.48, 0.16, 0.78)
	var rivet_col := Color(0.44, 0.47, 0.50, 0.72)
	var div_col := Color(0.34, 0.37, 0.39, 0.66)
	var pts := PackedVector2Array()
	var rivets: Array[Vector2] = []
	var draw_div := false
	var div_y0 := 10.0

	if hl > 0.5 and hr > 0.5:
		if absf(hl - hr) < 1.0:
			var ch := minf(10.0, sz.y * 0.25)
			pts = PackedVector2Array([
				Vector2(0.0, ch), Vector2(ch, 0.0), Vector2(w, 0.0),
				Vector2(w, sz.y), Vector2(0.0, sz.y),
			])
			rv.draw_colored_polygon(pts, bg_col)
			rv.draw_rect(Rect2(ch, 0.0, w - ch, 4.0), cap_col)
			rv.draw_rect(Rect2(ch, 4.0, 26.0, 3.0), warn_l)
			rv.draw_rect(Rect2(w - 20.0, 4.0, 14.0, 3.0), warn_r)
			rivets = [Vector2(w - 6.0, 10.0), Vector2(6.0, sz.y - 6.0), Vector2(w - 6.0, sz.y - 6.0)]
			draw_div = sz.y > 22.0
			div_y0 = 10.0
		elif hl > hr:
			var yr := sz.y - hr
			var ch := minf(10.0, hl * 0.25)
			pts = PackedVector2Array([
				Vector2(0.0, ch), Vector2(ch, 0.0), Vector2(mid, 0.0),
				Vector2(mid, yr), Vector2(w, yr),
				Vector2(w, sz.y), Vector2(0.0, sz.y),
			])
			rv.draw_colored_polygon(pts, bg_col)
			rv.draw_rect(Rect2(ch, 0.0, mid - ch, 4.0), cap_col)
			rv.draw_rect(Rect2(ch, 4.0, minf(22.0, mid - ch - 4.0), 3.0), warn_l)
			rv.draw_rect(Rect2(mid, yr, w - mid, 4.0), cap_col)
			rv.draw_rect(Rect2(w - 20.0, yr + 4.0, 14.0, 3.0), warn_r)
			rivets = [Vector2(mid - 6.0, 10.0), Vector2(w - 6.0, yr + 10.0), Vector2(6.0, sz.y - 6.0), Vector2(w - 6.0, sz.y - 6.0)]
			draw_div = hr > 22.0
			div_y0 = yr + 10.0
		else:
			var yl := sz.y - hl
			var ch_l := minf(10.0, hl * 0.25)
			var ch_r := minf(10.0, hr * 0.25) if yl >= 10.0 else 0.0
			if ch_r > 0.0:
				pts = PackedVector2Array([
					Vector2(0.0, yl + ch_l), Vector2(ch_l, yl), Vector2(mid, yl),
					Vector2(mid, ch_r), Vector2(mid + ch_r, 0.0), Vector2(w, 0.0),
					Vector2(w, sz.y), Vector2(0.0, sz.y),
				])
			else:
				pts = PackedVector2Array([
					Vector2(0.0, yl + ch_l), Vector2(ch_l, yl), Vector2(mid, yl),
					Vector2(mid, 0.0), Vector2(w, 0.0),
					Vector2(w, sz.y), Vector2(0.0, sz.y),
				])
			rv.draw_colored_polygon(pts, bg_col)
			rv.draw_rect(Rect2(ch_l, yl, mid - ch_l, 4.0), cap_col)
			rv.draw_rect(Rect2(ch_l, yl + 4.0, minf(22.0, mid - ch_l - 4.0), 3.0), warn_l)
			rv.draw_rect(Rect2(mid + ch_r, 0.0, w - mid - ch_r, 4.0), cap_col)
			rv.draw_rect(Rect2(w - 20.0, 4.0, 14.0, 3.0), warn_r)
			rivets = [Vector2(w - 6.0, 10.0), Vector2(mid - 6.0, yl + 10.0), Vector2(6.0, sz.y - 6.0), Vector2(w - 6.0, sz.y - 6.0)]
			draw_div = hl > 22.0
			div_y0 = yl + 10.0
	elif hl > 0.5:
		var ch := minf(10.0, sz.y * 0.25)
		pts = PackedVector2Array([
			Vector2(0.0, ch), Vector2(ch, 0.0), Vector2(mid, 0.0),
			Vector2(mid, sz.y), Vector2(0.0, sz.y),
		])
		rv.draw_colored_polygon(pts, bg_col)
		rv.draw_rect(Rect2(ch, 0.0, mid - ch, 4.0), cap_col)
		rv.draw_rect(Rect2(ch, 4.0, minf(22.0, mid - ch - 4.0), 3.0), warn_l)
		rivets = [Vector2(mid - 6.0, 10.0), Vector2(6.0, sz.y - 6.0), Vector2(mid - 4.0, sz.y - 5.0)]
	else:
		var ch := minf(10.0, sz.y * 0.25)
		pts = PackedVector2Array([
			Vector2(mid, ch), Vector2(mid + ch, 0.0), Vector2(w, 0.0),
			Vector2(w, sz.y), Vector2(mid, sz.y),
		])
		rv.draw_colored_polygon(pts, bg_col)
		rv.draw_rect(Rect2(mid + ch, 0.0, w - mid - ch, 4.0), cap_col)
		rv.draw_rect(Rect2(w - 20.0, 4.0, 14.0, 3.0), warn_r)
		rivets = [Vector2(w - 6.0, 10.0), Vector2(mid + 4.0, sz.y - 5.0), Vector2(w - 6.0, sz.y - 6.0)]

	var opt_pts := pts.duplicate()
	opt_pts.append(pts[0])
	rv.draw_polyline(opt_pts, line_col, 1.5, true)
	for rp in rivets:
		rv.draw_rect(Rect2(rp - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), rivet_col)
	if draw_div:
		rv.draw_line(Vector2(mid, div_y0), Vector2(mid, sz.y - 10.0), div_col, 1.5)


func _build_status() -> void:
	# 左下角 L：拐角（全息投影）+ 竖线（子弹栏）+ 横线（技能栏）
	var m = raid.mech
	var L := Control.new()
	L.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	L.offset_left = 14
	L.offset_bottom = -14
	L.offset_top = -14 - STATUS_H
	L.offset_right = 14 + 620
	L.mouse_filter = Control.MOUSE_FILTER_IGNORE
	L.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(L)
	status_root = L
	var CH := CORNER_H  # 拐角面板边长
	var base_y := STATUS_H - CH
	# 竖轨（子弹栏）：贴在拐角上方，按左右臂各自单弹匣容量自适应高度
	var rail_w := AMMO_RAIL_W
	var rv := Control.new()
	rv.position = Vector2(10, base_y)
	rv.size = Vector2(rail_w, 0.0)
	rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_rail = rv
	rv.draw.connect(_draw_ammo_rail)
	L.add_child(rv)
	var k := rail_w / 76.0
	var i := 0
	for slot in ["arm_l", "arm_r"]:
		var col = HL.AmmoColumn.new()
		var cx: float = 10.0 + (20.0 if i == 0 else 56.0) * k
		col.position = Vector2(cx - 15.0 * k, base_y)
		col.size = Vector2(30.0 * k, 0.0)
		col.bw = 30.0 * k - 4.0
		L.add_child(col)
		col.setup(m, slot)
		ammo_cols[slot] = col
		i += 1
	_layout_ammo_rail()
	# 横轨（技能栏）：从拐角右侧齐平伸出，包覆 SPACE（底盘机动）与 F（背部挂载）槽与底部能源条，避免双层叠色暗缝
	var keys := [["space", Loc.space_key()], ["f", "F"]]
	var sw := 92.0
	var rh_w := sw * keys.size() + 18.0
	var rh_h := 110.0
	var rh := Control.new()
	rh.position = Vector2(CH, 560 - 126)
	rh.size = Vector2(rh_w, rh_h)
	rh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rh.draw.connect(func():
		var sz := rh.size
		var ch := 10.0
		var pts := PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(sz.x - ch, 0.0), Vector2(sz.x, ch),
			Vector2(sz.x, sz.y), Vector2(0.0, sz.y),
		])
		rh.draw_colored_polygon(pts, Color(0.085, 0.092, 0.098, 0.66))
		var outline := PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(sz.x - ch, 0.0), Vector2(sz.x, ch),
			Vector2(sz.x, sz.y), Vector2(0.0, sz.y), Vector2(0.0, 0.0),
		])
		rh.draw_polyline(outline, Color(0.26, 0.28, 0.30, 0.80), 1.5, true)
		rh.draw_rect(Rect2(0.0, 0.0, sz.x - ch, 2.5), Color(0.24, 0.26, 0.28, 0.78))
		rh.draw_rect(Rect2(sz.x - 5.0, ch + 2.0, 5.0, sz.y - ch - 6.0), Color(0.78, 0.48, 0.16, 0.84))
		rh.draw_rect(Rect2(6.0, sz.y - 16.0, sz.x - 16.0, 10.0), Color(0.03, 0.035, 0.04, 0.48))
		rh.draw_rect(Rect2(6.0, sz.y - 16.0, sz.x - 16.0, 10.0), Color(0.30, 0.33, 0.35, 0.72), false, 1.0))
	L.add_child(rh)
	for j in keys.size():
		var ss = HL.SkillSlot.new()
		ss.position = rh.position + Vector2(4 + j * sw, 5)
		ss.size = Vector2(sw - 4, 96)
		L.add_child(ss)
		ss.setup(m, keys[j][0], keys[j][1])
		skill_slots[keys[j][0]] = ss
	energy_strip = HL.EnergyStrip.new()
	energy_strip.mech = m
	energy_strip.position = rh.position + Vector2(8, rh_h - 13)
	energy_strip.size = Vector2(rh_w - 20.0, 6)
	energy_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	L.add_child(energy_strip)
	# 拐角：半透明护框 + 全息投影 + 货舱条
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
		cr.draw_colored_polygon(pts, Color(0.082, 0.088, 0.094, 0.68))
		var outline := PackedVector2Array([
			Vector2(ch, 0.0), Vector2(sz.x, 0.0), Vector2(sz.x, sz.y),
			Vector2(0.0, sz.y), Vector2(0.0, ch), Vector2(ch, 0.0),
		])
		cr.draw_polyline(outline, Color(0.26, 0.28, 0.30, 0.80), 1.5, true)
		# 顶部工业灰黑结构护沿 + 角部铆钉
		cr.draw_rect(Rect2(ch + 1.0, 0.0, sz.x - ch - 2.0, 3.0), Color(0.22, 0.24, 0.26, 0.80))
		cr.draw_rect(Rect2(0.0, ch + 1.0, 3.0, 28.0), Color(0.22, 0.24, 0.26, 0.74))
		cr.draw_rect(Rect2(sz.x - 28.0, 3.0, 22.0, 2.5), Color(0.78, 0.48, 0.16, 0.84))
		var well := Rect2(10.0, 12.0, sz.x - 20.0, 128.0)
		cr.draw_rect(well, Color(0.02, 0.025, 0.03, 0.28))
		cr.draw_rect(well, Color(0.32, 0.36, 0.38, 0.78), false, 1.0)
		var wc := well.position + well.size * 0.5
		cr.draw_line(Vector2(well.position.x + 8.0, wc.y), Vector2(well.end.x - 8.0, wc.y), Color(0.56, 0.62, 0.60, 0.14), 1.0)
		cr.draw_line(Vector2(wc.x, well.position.y + 8.0), Vector2(wc.x, well.end.y - 8.0), Color(0.56, 0.62, 0.60, 0.14), 1.0)
		var yc := Color(0.78, 0.48, 0.16, 0.88)
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
		cr.draw_rect(Rect2(14.0, 145.0, sz.x - 28.0, 10.0), Color(0.03, 0.035, 0.04, 0.48))
		cr.draw_rect(Rect2(14.0, 145.0, sz.x - 28.0, 10.0), Color(0.32, 0.35, 0.37, 0.68), false, 1.0))
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
	b.add_theme_stylebox_override("normal", K.px9("btn9_n", 8, 8, 6, 4, Color(1, 1, 1, 0.70)))
	b.add_theme_stylebox_override("hover", K.px9("btn9_h", 8, 8, 6, 4, Color(1, 1, 1, 0.84)))
	b.add_theme_stylebox_override("pressed", K.px9("btn9_p", 8, 8, 6, 4, Color(1, 1, 1, 0.88)))
	b.add_theme_stylebox_override("hover_pressed", K.px9("btn9_p", 8, 8, 6, 4, Color(1, 1, 1, 0.88)))
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
	v.offset_top = 36 if GameData.show_fps else 14
	v.offset_left = -258
	v.add_theme_constant_override("separation", 6)
	root.add_child(v)
	_radar_box = v
	if not GameData.show_fps_changed.is_connected(_on_show_fps_changed):
		GameData.show_fps_changed.connect(_on_show_fps_changed)
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
			if _touch_btn_ok():
				toggle_map()
			radar.accept_event())
	v.add_child(radar)
	transport_panel = PanelContainer.new()
	transport_panel.add_theme_stylebox_override("panel", _hud_glass_box(Color(0.062, 0.068, 0.076, 0.36), UI.ACCENT, 3, 8, 4))
	transport_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	transport_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transport_panel.visible = false
	v.add_child(transport_panel)
	transport_lbl = UI.label("", 12, UI.EN_C, true)
	transport_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transport_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transport_panel.add_child(transport_lbl)


func _card(key: String, item_id := "") -> Dictionary:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", K.px9("card9", 6, 6, 6, 6, Color(1, 1, 1, 0.70)))
	p.custom_minimum_size = Vector2(60, 60)
	p.mouse_entered.connect(func(): p.add_theme_stylebox_override("panel", K.px9("card9_on", 6, 6, 6, 6, Color(1, 1, 1, 0.84))))
	p.mouse_exited.connect(func(): p.add_theme_stylebox_override("panel", K.px9("card9", 6, 6, 6, 6, Color(1, 1, 1, 0.70))))
	var box := Control.new()
	box.custom_minimum_size = Vector2(48, 48)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(box)
	if item_id != "":
		var ic := K.icon_rect(Icons.icon(item_id), 38)
		ic.position = Vector2(5, 5)
		ic.size = Vector2(38, 38)
		box.add_child(ic)
	var kc := UI.keycap(key, 11, 0.76)
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
				if _touch_btn_ok() and raid and raid.mech and not raid.mech.input_locked:
					if item_id == "beacon":
						raid.call_transport()
					else:
						raid.mech.use_item(item_id)
				c.panel.accept_event())
		h.add_child(c.panel)
		item_cards[item_id] = c


func _touch_btn_ok() -> bool:
	var now := Time.get_ticks_msec()
	if now - _last_touch_btn_ms < 80:
		return false
	_last_touch_btn_ms = now
	return true


func _build_touch_controls() -> void:
	touch_layer = Control.new()
	touch_layer.z_index = 22
	touch_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if OS.has_feature("mobile"):
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var win_sz: Vector2i = DisplayServer.window_get_size()
		var vis_sz: Vector2 = get_viewport().get_visible_rect().size
		if win_sz.x > 0 and win_sz.y > 0 and safe.size.x > 0 and safe.size.y > 0 and vis_sz.x > 0.0 and vis_sz.y > 0.0:
			var sx := vis_sz.x / float(win_sz.x)
			var sy := vis_sz.y / float(win_sz.y)
			touch_layer.offset_left = maxf(0.0, float(safe.position.x) * sx)
			touch_layer.offset_top = maxf(0.0, float(safe.position.y) * sy)
			touch_layer.offset_right = -maxf(0.0, float(win_sz.x - (safe.position.x + safe.size.x)) * sx)
			touch_layer.offset_bottom = -maxf(0.0, float(win_sz.y - (safe.position.y + safe.size.y)) * sy)
	touch_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(touch_layer)
	# 左摇杆：左下子弹轨右侧、SPACE/F 技能栏上方（左手拇指舒适区）
	joy_left = HL.TouchStick.new(Loc.t("移动", "Move"), false)
	joy_left.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	joy_left.offset_left = 176
	joy_left.offset_right = 176 + 268
	joy_left.offset_bottom = -146
	joy_left.offset_top = -146 - 268
	touch_layer.add_child(joy_left)
	# 右摇杆：三称下为瞄准/射击双摇杆；一称下为按住开火+拖移压枪触发区
	joy_right = HL.TouchStick.new(Loc.t("瞄准 / 射击", "Aim / Fire"), true)
	joy_right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	joy_right.offset_right = -20
	joy_right.offset_left = -20 - 268
	joy_right.offset_bottom = -82
	joy_right.offset_top = -82 - 268
	touch_layer.add_child(joy_right)
	# 右摇杆外弧快捷触控键：右手拇指不离开右半屏即可触发 SPACE 冲刺、F 机能、换弹与开镜瞄准
	var m = raid.mech
	var b_dash := HL.TouchBtn.new()
	b_dash.setup(m, "dash", Loc.t("冲刺", "Dash"), Loc.space_key(), 45.0, self)
	b_dash.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	b_dash.offset_right = -298
	b_dash.offset_left = -298 - 90
	b_dash.offset_bottom = -162
	b_dash.offset_top = -162 - 90
	touch_layer.add_child(b_dash)
	var b_ab := HL.TouchBtn.new()
	b_ab.setup(m, "ability", Loc.t("机能", "Ability"), "F", 45.0, self)
	b_ab.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	b_ab.offset_right = -274
	b_ab.offset_left = -274 - 90
	b_ab.offset_bottom = -268
	b_ab.offset_top = -268 - 90
	touch_layer.add_child(b_ab)
	var b_rld := HL.TouchBtn.new()
	b_rld.setup(m, "reload", Loc.t("换弹", "Reload"), "R", 42.0, self)
	b_rld.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	b_rld.offset_right = -264
	b_rld.offset_left = -264 - 84
	b_rld.offset_bottom = -64
	b_rld.offset_top = -64 - 84
	touch_layer.add_child(b_rld)
	touch_aim_btn = HL.TouchBtn.new()
	touch_aim_btn.setup(m, "aim", Loc.t("瞄准", "Scope"), "RMB", 42.0, self)
	touch_aim_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	touch_aim_btn.offset_right = -196
	touch_aim_btn.offset_left = -196 - 84
	touch_aim_btn.offset_bottom = -346
	touch_aim_btn.offset_top = -346 - 84
	touch_layer.add_child(touch_aim_btn)
	# 左手开火辅钮：第一人称模式下位于左摇杆右上方，避开系统日志区与左侧弹药轨
	joy_fire = HL.TouchBtn.new()
	joy_fire.setup(m, "fire", Loc.t("开火", "Fire"), "LMB", 46.0, self)
	joy_fire.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	joy_fire.offset_left = 432
	joy_fire.offset_right = 432 + 92
	joy_fire.offset_bottom = -356
	joy_fire.offset_top = -356 - 92
	joy_fire.visible = false
	touch_layer.add_child(joy_fire)
	# 顶部右侧 1/3 人称切换快捷触控钮（位于原顶栏左侧空白区）
	touch_view_btn = HL.TouchBtn.new()
	touch_view_btn.setup(m, "view", Loc.t("视角", "View"), "F5", 26.0, self)
	touch_view_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	touch_view_btn.offset_right = -146
	touch_view_btn.offset_left = -146 - 52
	touch_view_btn.offset_top = 6
	touch_view_btn.offset_bottom = 6 + 52
	touch_layer.add_child(touch_view_btn)


func toggle_touch_aim() -> void:
	touch_aim_on = not touch_aim_on


func clear_touch_aim() -> void:
	touch_aim_on = false


func is_touch_aiming() -> bool:
	return _touch_revealed and touch_aim_on


func is_touch_firing() -> bool:
	if not _touch_revealed:
		return false
	var r_fire: bool = joy_right != null and joy_right.is_firing()
	var l_fire: bool = joy_fire != null and joy_fire.visible and joy_fire.is_held()
	return r_fire or l_fire


func is_touch_busy() -> bool:
	return (joy_left != null and joy_left.is_active()) or (joy_right != null and joy_right.is_active()) or (joy_fire != null and joy_fire.is_held())


func _build_center() -> void:
	zone_banner = Control.new()
	zone_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	zone_banner.offset_left = -230
	zone_banner.offset_right = 230
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
			zone_banner.draw_rect(Rect2(x, 0.0, sw + 0.6, sz.y), Color(0.056, 0.060, 0.066, 0.42 * w))
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

	boss_panel = PanelContainer.new()
	boss_panel.add_theme_stylebox_override("panel", _hud_glass_box(Color(0.068, 0.062, 0.066, 0.40), UI.BAD, 3, 10, 6))
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
	boss_bar.add_theme_stylebox_override("background", UI.flat_bar(Color(0.04, 0.045, 0.052, 0.56), Color(0.30, 0.33, 0.35, 0.65), 1, 1))
	boss_bar.add_theme_stylebox_override("fill", UI.flat_bar(Color(0.86, 0.2, 0.28, 0.88), Color(1.0, 0.45, 0.52, 0.85), 1, 0))
	bv.add_child(boss_bar)

	extract_panel = PanelContainer.new()
	extract_panel.add_theme_stylebox_override("panel", _hud_glass_box(Color(0.058, 0.072, 0.064, 0.38), UI.GOOD, 3, 12, 6))
	extract_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	extract_panel.offset_top = 116
	extract_panel.custom_minimum_size = Vector2(420, 0)
	extract_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	extract_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	extract_panel.visible = false
	root.add_child(extract_panel)
	var ev := VBoxContainer.new()
	ev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	extract_panel.add_child(ev)
	extract_lbl = UI.label("", 15, UI.GOOD, true)
	extract_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	extract_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ev.add_child(extract_lbl)
	extract_bar = ProgressBar.new()
	extract_bar.show_percentage = false
	extract_bar.custom_minimum_size = Vector2(0, 10)
	extract_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	extract_bar.add_theme_stylebox_override("background", UI.flat_bar(Color(0.04, 0.045, 0.052, 0.56), Color(0.30, 0.33, 0.35, 0.65), 1, 1))
	extract_bar.add_theme_stylebox_override("fill", UI.flat_bar(Color(UI.GOOD.r, UI.GOOD.g, UI.GOOD.b, 0.88), Color(0, 0, 0, 0), 0, 0))
	ev.add_child(extract_bar)

	prompt_panel = PanelContainer.new()
	prompt_panel.add_theme_stylebox_override("panel", UI.tex9("prompt9", 10, 12, Color(1, 1, 1, 0.72)))
	prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt_panel.offset_top = 70
	prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	prompt_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	prompt_panel.gui_input.connect(func(ev: InputEvent):
		if (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
			if _touch_btn_ok() and raid:
				raid.interact_nearest()
			prompt_panel.accept_event())
	prompt_panel.visible = false
	root.add_child(prompt_panel)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 8)
	prompt_panel.add_child(ph)
	ph.add_child(UI.keycap("G", 14, 0.78))
	prompt_lbl = UI.label("", 16, Color(1, 0.92, 0.75))
	ph.add_child(prompt_lbl)

	sys_clip = Control.new()
	sys_clip.anchor_left = 0.0
	sys_clip.anchor_right = 0.0
	sys_clip.anchor_top = 0.0
	sys_clip.anchor_bottom = 1.0
	sys_clip.offset_left = 18.0
	sys_clip.offset_right = 374.0
	sys_clip.offset_top = 134.0
	var init_rail_h := ammo_rail.size.y if ammo_rail != null else 0.0
	sys_clip.offset_bottom = -(14.0 + CORNER_H + init_rail_h + 7.0)
	sys_clip.clip_contents = true
	sys_clip.z_index = 18
	sys_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sys_clip)

	sys_col = VBoxContainer.new()
	sys_col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sys_col.add_theme_constant_override("separation", 4)
	sys_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sys_clip.add_child(sys_col)

	coop_bar = PanelContainer.new()
	coop_bar.add_theme_stylebox_override("panel", _sys_msg_style("normal"))
	coop_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	coop_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coop_bar.visible = false
	coop_lbl = UI.label("", 12, UI.TEXT, true)
	coop_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coop_bar.add_child(coop_lbl)
	sys_col.add_child(coop_bar)

	log_box = VBoxContainer.new()
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.alignment = BoxContainer.ALIGNMENT_END
	log_box.add_theme_constant_override("separation", 4)
	log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sys_col.add_child(log_box)


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
	UI.bind_fit_panel(settings_panel)
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
	fs.toggled.connect(func(on):
		GameData.set_fullscreen(on))
	pgv.add_child(fs)
	var vs := CheckButton.new()
	vs.text = Loc.t("垂直同步", "VSync")
	vs.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	vs.toggled.connect(func(on): DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED))
	pgv.add_child(vs)
	var fps_cb := CheckButton.new()
	fps_cb.text = Loc.t("显示 FPS", "Show FPS")
	fps_cb.button_pressed = GameData.show_fps
	fps_cb.toggled.connect(func(on): GameData.set_show_fps(on))
	pgv.add_child(fps_cb)
	_fps_cb = fps_cb
	pgv.add_child(UI.label(Loc.t("画质", "Quality"), 14, UI.MUTED))
	var q := OptionButton.new()
	for i in GameData.QUALITY_NAMES.size():
		q.add_item(str(GameData.QUALITY_NAMES[i]), i)
	q.selected = GameData.quality
	q.item_selected.connect(func(i):
		GameData.quality = i
		GameData.apply_quality(get_viewport())
		if raid != null and is_instance_valid(raid):
			var r_we: WorldEnvironment = null
			for c in raid.get_children():
				if c is WorldEnvironment:
					r_we = c
					break
			if r_we != null and r_we.environment != null:
				GameData.apply_env_quality(r_we.environment, raid._sun_light)
		GameData.save_game())
	pgv.add_child(q)
	if not OS.has_feature("mobile"):
		pgv.add_child(UI.label(Loc.t("渲染精度", "Render Scale"), 14, UI.MUTED))
		var rs := OptionButton.new()
		var rs_opts := GameData.render_scale_options()
		for i in rs_opts.size():
			rs.add_item(str(rs_opts[i]), i)
		rs.selected = GameData.render_scale_mode
		rs.item_selected.connect(func(i):
			GameData.set_render_scale_mode(i)
			GameData.apply_quality(get_viewport()))
		pgv.add_child(rs)
		_rs_opt = rs

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

	pgv3.add_child(UI.label(Loc.t("视角模式", "Camera Mode"), 14, UI.MUTED))
	_view_opt = OptionButton.new()
	_view_opt.add_item(Loc.t("斜俯视", "Top-Down"), 0)
	_view_opt.add_item(Loc.t("第一人称", "First-Person"), 1)
	_view_opt.add_item(Loc.t("第三人称越肩", "Over-the-Shoulder"), 2)
	_view_opt.selected = clampi(raid.view_mode if (raid != null and "view_mode" in raid) else GameData.view_mode, 0, 2)
	_view_opt.item_selected.connect(func(i):
		if raid != null and raid.has_method("set_view_mode"):
			raid.set_view_mode(i, true)
		else:
			GameData.view_mode = i
			GameData.save_game())
	pgv3.add_child(_view_opt)

	pgv3.add_child(UI.label(Loc.t("鼠标灵敏度", "Mouse Sensitivity"), 14, UI.MUTED))
	var sens := HSlider.new()
	sens.min_value = 0.2
	sens.max_value = 2.5
	sens.step = 0.05
	sens.value = GameData.mouse_sens
	sens.custom_minimum_size = Vector2(0, 22)
	sens.value_changed.connect(func(x):
		GameData.mouse_sens = x
		GameData.schedule_save())
	pgv3.add_child(sens)

	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(line)
	var back := Button.new()
	back.text = Loc.t("返回", "Back")
	back.custom_minimum_size = Vector2(120, 36)
	back.set_meta("sfx", "")
	back.pressed.connect(_close_settings)
	line.add_child(back)


func _on_show_fps_changed(on: bool) -> void:
	if _radar_box != null and is_instance_valid(_radar_box):
		_radar_box.offset_top = 36 if on else 14


func _open_settings() -> void:
	last_toggle_frame = Engine.get_process_frames()
	if _fps_cb != null and is_instance_valid(_fps_cb):
		_fps_cb.set_pressed_no_signal(GameData.show_fps)
	if _rs_opt != null and is_instance_valid(_rs_opt):
		_rs_opt.selected = GameData.render_scale_mode
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


func show_zone_banner(zone_name: String, delay := 0.08, sub_text := "") -> void:
	if zone_banner == null or zone_name == "":
		return
	if _zone_tw != null and is_instance_valid(_zone_tw):
		_zone_tw.kill()
	zone_sub_lbl.text = sub_text if sub_text != "" else Loc.t("进入战区", "ENTERING SECTOR")
	zone_title_lbl.text = zone_name
	_zone_active = true
	# 地区横幅固定占顶部首位，首领血条与撤离条统一顺延到其下方，杜绝二者互斥错位重叠
	var base_y := 20.0
	var h := 58.0
	zone_banner.visible = true
	zone_banner.modulate.a = 0.0
	zone_banner.offset_top = base_y - 8.0
	zone_banner.offset_bottom = base_y - 8.0 + h
	_zone_tw = create_tween()
	if delay > 0.0:
		_zone_tw.tween_interval(delay)
	_zone_tw.tween_property(zone_banner, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zone_tw.parallel().tween_property(zone_banner, "offset_top", base_y, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zone_tw.parallel().tween_property(zone_banner, "offset_bottom", base_y + h, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zone_tw.tween_interval(1.9)
	_zone_tw.tween_property(zone_banner, "modulate:a", 0.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_zone_tw.parallel().tween_property(zone_banner, "offset_top", base_y - 4.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_zone_tw.parallel().tween_property(zone_banner, "offset_bottom", base_y - 4.0 + h, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
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
	_layout_ammo_rail()
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


func _is_free_look() -> bool:
	if raid == null:
		return false
	if raid.has_method("is_free_look_view"):
		return raid.is_free_look_view()
	return raid.has_method("is_first_person") and raid.is_first_person()


func sync_view_mode_ui() -> void:
	if _view_opt != null and is_instance_valid(_view_opt) and raid != null and "view_mode" in raid:
		_view_opt.select(clampi(int(raid.view_mode), 0, 2))
	var fp_on := _is_free_look()
	if joy_right != null and is_instance_valid(joy_right):
		joy_right.fp_mode = fp_on
		joy_right.queue_redraw()
	if joy_fire != null and is_instance_valid(joy_fire):
		joy_fire.visible = fp_on
		if not fp_on and joy_fire.is_held():
			joy_fire.release()


func _update_cursor() -> void:
	var story_open: bool = Story.get("flow") != null and Story.flow.is_playing()
	var menu_open: bool = pause_panel.visible or (settings_panel != null and settings_panel.visible)
	var ui_open: bool = menu_open or loot_panel.visible or raid.ended or map_open() or story_open
	if pause_dim != null:
		pause_dim.visible = menu_open
	if zone_banner != null:
		zone_banner.visible = _zone_active and not ui_open
	var want_capture: bool = (not ui_open) and (not get_tree().paused) and raid != null and raid.has_method("should_capture_mouse") and raid.should_capture_mouse()
	var target_mode := Input.MOUSE_MODE_CAPTURED if want_capture else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != target_mode:
		Input.mouse_mode = target_mode
	crosshair.visible = not ui_open and _scope_alpha < 0.35
	if touch_layer != null:
		touch_layer.visible = _touch_revealed and not ui_open
		var fp_on := _is_free_look()
		if joy_right != null and is_instance_valid(joy_right):
			joy_right.fp_mode = fp_on
		if joy_fire != null and is_instance_valid(joy_fire):
			joy_fire.visible = fp_on
		if ui_open:
			touch_aim_on = false
			if joy_left != null and joy_left.is_active():
				joy_left.release()
			if joy_right != null and joy_right.is_active():
				joy_right.release()
			if joy_fire != null and joy_fire.is_held():
				joy_fire.release()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not _touch_revealed:
		_touch_revealed = true
		_update_cursor()
	if event.is_action_pressed("toggle_view") and not event.is_echo():
		var menu_open: bool = pause_panel.visible or (settings_panel != null and settings_panel.visible)
		if not menu_open and raid != null and not raid.ended and raid.has_method("toggle_view_mode"):
			raid.toggle_view_mode()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("swap_shoulder") and not event.is_echo():
		var story_open: bool = Story.get("flow") != null and Story.flow.is_playing()
		var ui_open: bool = pause_panel.visible or (settings_panel != null and settings_panel.visible) or loot_panel.visible or map_open() or story_open
		if not ui_open and raid != null and not raid.ended and raid.has_method("toggle_ots_shoulder") and raid.has_method("is_over_shoulder") and raid.is_over_shoulder():
			raid.toggle_ots_shoulder()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if settings_panel != null and settings_panel.visible and event.is_action_pressed("pause"):
		_close_settings()
		get_viewport().set_input_as_handled()
		return
	if pause_panel.visible and event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
		return


static func _sys_msg_style(tier: String) -> StyleBoxFlat:
	match tier:
		"warn":
			return _hud_glass_box(Color(0.13, 0.052, 0.045, 0.36), Color(0.86, 0.34, 0.22, 0.82), 3, 9, 4)
		"skill":
			return _hud_glass_box(Color(0.105, 0.085, 0.052, 0.35), Color(0.87, 0.59, 0.25, 0.84), 3, 9, 4)
		_:
			return _hud_glass_box(Color(0.062, 0.068, 0.076, 0.32), Color(0.78, 0.48, 0.16, 0.78), 3, 9, 4)


func _trim_log_box() -> void:
	if log_box == null:
		return
	var vp_h: float = get_viewport().get_visible_rect().size.y if get_viewport() != null else 720.0
	var top_off: float = sys_clip.offset_top if sys_clip != null else 134.0
	var bot_off: float = absf(sys_clip.offset_bottom) if sys_clip != null else (14.0 + CORNER_H + AMMO_MAX_TOTAL_H + 7.0)
	var avail_h: float = sys_clip.size.y if (sys_clip != null and sys_clip.size.y > 40.0) else (vp_h - bot_off - top_off)
	if coop_bar != null and coop_bar.visible:
		avail_h -= maxf(26.0, coop_bar.get_combined_minimum_size().y) + 4.0
	while log_box.get_child_count() > 1:
		var total_h := 0.0
		var cnt := 0
		for c in log_box.get_children():
			if c.is_queued_for_deletion():
				continue
			var ch := maxf(float(c.get_meta("est_h", 26.0)), (c as Control).get_combined_minimum_size().y)
			total_h += ch
			cnt += 1
		if cnt > 1:
			total_h += 4.0 * float(cnt - 1)
		if cnt <= 5 and total_h <= avail_h:
			break
		var old: Node = log_box.get_child(0)
		log_box.remove_child(old)
		old.free()


func set_coop_status(t: String, warn := false) -> void:
	if coop_bar == null:
		return
	var clean := t.strip_edges()
	var want_vis := clean != ""
	var prev_warn: bool = bool(coop_bar.get_meta("warn", false))
	if coop_bar.visible == want_vis and coop_lbl.text == clean and prev_warn == warn:
		return
	coop_bar.visible = want_vis
	if want_vis:
		coop_lbl.text = clean
		_set_font_color(coop_lbl, Color(0.96, 0.78, 0.72, 0.97) if warn else UI.TEXT)
		if prev_warn != warn:
			coop_bar.set_meta("warn", warn)
			coop_bar.add_theme_stylebox_override("panel", _sys_msg_style("warn" if warn else "normal"))
	_trim_log_box()


func msg(t: String) -> void:
	var clean := t.strip_edges()
	if log_box == null or clean == "":
		return
	var tier := "warn" if clean.begins_with("▲") else ("skill" if clean.begins_with("◆") else "normal")
	var tc := Color(0.96, 0.78, 0.72, 0.97) if tier == "warn" else (Color(0.95, 0.85, 0.64, 0.97) if tier == "skill" else Color(0.90, 0.90, 0.87, 0.96))
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sys_msg_style(tier))
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UI.label(clean, 13, tc, true)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := PixelUI.pixel_font()
	var fs := PixelUI.snap(13)
	var raw_w := f.get_string_size(clean, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if f != null else float(clean.length() * 13)
	const MAX_TW := 326.0
	if raw_w > MAX_TW:
		l.custom_minimum_size = Vector2(MAX_TW, 0)
		l.size = Vector2(MAX_TW, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.max_lines_visible = 2
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.add_theme_constant_override("line_spacing", 2)
		p.set_meta("est_h", 44.0)
	else:
		p.set_meta("est_h", 26.0)
	p.add_child(l)
	log_box.add_child(p)
	_trim_log_box()
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.14)
	tw.tween_interval(4.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.65)
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


var _last_boss_txt := ""
var _last_boss_hp_txt := ""
var _last_extract_txt := ""


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
		if not boss_panel.visible:
			boss_panel.visible = true
		var want_btop := 88.0 if _zone_active else 24.0
		if not is_equal_approx(boss_panel.offset_top, want_btop):
			boss_panel.offset_top = want_btop
		var ph_roman := "I" if int(boss_node.phase) <= 1 else ("II" if int(boss_node.phase) == 2 else "III")
		var btitle: String = str(GameData.ENEMIES.get(str(boss_node.boss_id), {}).get("name", boss_node.title)) if "boss_id" in boss_node else str(boss_node.title)
		var weak_tag := Loc.t("  [★ 晶核暴露]", "  [★ CORE EXPOSED]") if float(boss_node.core_open) > 0.0 else ""
		var new_boss_txt: String = Loc.t("▲ 战区首领 · %s   阶段 %s%s", "▲ Sector Boss · %s   Phase %s%s") % [btitle, ph_roman, weak_tag]
		if new_boss_txt != _last_boss_txt:
			_last_boss_txt = new_boss_txt
			boss_lbl.text = new_boss_txt
		var new_hp_txt: String = "%d / %d" % [ceili(maxf(float(boss_node.hp), 0.0)), int(boss_node.data.get("hp", 1000.0))]
		if new_hp_txt != _last_boss_hp_txt:
			_last_boss_hp_txt = new_hp_txt
			boss_hp_lbl.text = new_hp_txt
		if boss_bar.max_value != 1.0:
			boss_bar.max_value = 1.0
		var br: float = float(boss_node.hp_ratio())
		if absf(boss_bar.value - br) > 0.0005:
			boss_bar.value = br
	elif boss_panel != null and boss_panel.visible:
		boss_panel.visible = false

	# 撤离读条（顺延排在地区横幅与首领血条之下，避免三者同屏重叠）
	if raid.extract_target and not raid.ended:
		if not extract_panel.visible:
			extract_panel.visible = true
		var boss_on := boss_panel != null and boss_panel.visible
		var want_etop := (154.0 if boss_on else 90.0) if _zone_active else (92.0 if boss_on else 32.0)
		if not is_equal_approx(extract_panel.offset_top, want_etop):
			extract_panel.offset_top = want_etop
		var new_ext_txt: String = Loc.t("正在撤离 · %s", "Extracting · %s") % raid.extract_target.title
		if new_ext_txt != _last_extract_txt:
			_last_extract_txt = new_ext_txt
			extract_lbl.text = new_ext_txt
		extract_bar.max_value = raid.extract_target.need
		extract_bar.value = raid.extract_progress
	elif extract_panel.visible:
		extract_panel.visible = false

	var danger := 0.0
	if m.emergency > 0.0:
		danger = 0.5 + 0.3 * sin(Time.get_ticks_msec() * 0.01)
	hurt_t = max(0.0, hurt_t - get_process_delta_time())
	var vig_a := maxf(danger * 0.45, hurt_t * 1.2)
	var want_vig := vig_a > 0.005
	if vignette.visible != want_vig:
		vignette.visible = want_vig
	if want_vig:
		vignette.modulate.a = vig_a
	if smoke_rect and raid.camera:
		var sm := smoke_rect.material as ShaderMaterial
		var sv = sm.get_shader_parameter("strength") if sm != null else null
		var want_smk := sv != null and float(sv) > 0.01
		if smoke_rect.visible != want_smk:
			smoke_rect.visible = want_smk
		if want_smk:
			var cp: Vector3 = raid.camera.global_position
			var cam_off := Vector2(cp.x, cp.z) * 0.045
			if _is_free_look():
				cam_off += Vector2(-raid.fp_yaw * 0.35, raid.fp_pitch * 0.25)
			sm.set_shader_parameter("cam_off", cam_off)
	if scope_rect != null:
		var story_sc: bool = Story.get("flow") != null and Story.flow.is_playing()
		var ui_open_sc: bool = pause_panel.visible or (settings_panel != null and settings_panel.visible) or loot_panel.visible or raid.ended or map_open() or story_sc
		var want_scope: bool = not ui_open_sc and m.is_scoping()
		_scope_alpha = move_toward(_scope_alpha, 1.0 if want_scope else 0.0, maxf(get_process_delta_time(), 0.016) * 9.0)
		scope_rect.visible = _scope_alpha > 0.005
		if scope_rect.visible:
			var vp_sz := get_viewport().get_visible_rect().size
			var cpx := vp_sz * 0.5
			var fp_on := _is_free_look()
			if fp_on:
				if raid.aim_override != null and raid.camera != null and not raid.camera.is_position_behind(m.aim_point):
					cpx = raid.camera.unproject_position(m.aim_point).clamp(Vector2.ZERO, vp_sz)
				else:
					cpx = vp_sz * 0.5
			elif raid.aim_override != null or raid._joy_aim_active or is_touch_busy():
				if raid.camera != null:
					cpx = raid.camera.unproject_position(m.aim_point)
			else:
				cpx = get_viewport().get_mouse_position().clamp(Vector2.ZERO, vp_sz)
			var scm := scope_rect.material as ShaderMaterial
			scm.set_shader_parameter("alpha", _scope_alpha)
			scm.set_shader_parameter("vp_size", vp_sz)
			scm.set_shader_parameter("center_px", cpx)
			scm.set_shader_parameter("radius_px", minf(vp_sz.x, vp_sz.y) * 0.34)
	var vp_hi := int(round(get_viewport().get_visible_rect().size.y)) if get_viewport() != null else 720
	var cur_sig := Vector3i(int(m.mag.get("arm_l", 0)), int(m.mag.get("arm_r", 0)), vp_hi)
	if cur_sig != _ammo_layout_sig:
		for slot in ["arm_l", "arm_r"]:
			if ammo_cols.has(slot) and ammo_cols[slot].mag != int(m.mag.get(slot, 0)):
				ammo_cols[slot].mag = int(m.mag.get(slot, 0))
		_layout_ammo_rail()
	if sys_clip != null:
		var min_top := 134.0
		if radio != null and is_instance_valid(radio) and radio.size.y > 0.0:
			min_top = maxf(min_top, radio.position.y + radio.size.y + 7.0)
		if not is_equal_approx(sys_clip.offset_top, min_top):
			sys_clip.offset_top = min_top
			_trim_log_box()
	_update_markers()


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
	_update_cursor()


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
