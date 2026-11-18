extends CanvasLayer
## 战区加载与空投/转场过程动画层（CanvasLayer layer=98）：
## 1. 出击或跨战区转场时先播放重型机库装甲舱门闭合动画（play_close）
## 2. 分阶段构建战区期间实时刷新战术雷达扫描、空投舱轨迹动画、6 槽模块自检绿灯、进度条与终端日志（set_step）
## 3. 战区构建与首帧渲染预热完成后播放舱门拉开动画（play_open），无缝切入 3D 高空坠落 / 边界推进演出

const UI = preload("res://scripts/ui.gd")
const K = preload("res://scripts/hub_kit.gd")
const Icons = preload("res://scripts/item_icons.gd")

const TIPS_ZH := [
	"战术提示：双持武器时基础视距取射程较高的一侧，装备带 [侦察] 标签的躯干可额外拉远全局视角。",
	"战术提示：战区首领在进入视野或受击前处于盘踞伏击状态，绕至其背部或待晶核暴露时开火可造成高额弱点伤害。",
	"战术提示：按 [Tab] 可随时打开战术整备终端整理货舱、战地直接换装模块或查看全身 6 部位损管状态。",
	"战术提示：按 [R] 可手动重装填双臂弹匣；交战间隙及时补满弹匣可避免火力真空。",
	"战术提示：动力炉能源耗尽后机甲将进入应急断电状态，请留意右上角能源倒计时并提前规划撤离路线。",
	"战术提示：相邻且已解锁的地表战区可通过地图边缘的蓝光转场口直接穿越，转场将完整保留机甲状态与货舱物资。",
]
const TIPS_EN := [
	"TIP: Dual-wielded weapons use the longer weapon range; equipping a [Recon] core expands your global camera view.",
	"TIP: Sector bosses ambush until sighted or struck — flank behind them or focus fire when their crystal core opens.",
	"TIP: Press [Tab] anytime to manage cargo, hot-swap modules in the field, or check all 6 damage-control zones.",
	"TIP: Press [R] to top off both arm magazines between skirmishes and avoid mid-fight dry reloads.",
	"TIP: When core energy runs dry, emergency power triggers — watch the upper-right energy readout and plan your exfil.",
	"TIP: Unlocked neighboring sectors connect via glowing blue border transit gates, preserving mech state and cargo.",
]

var map_id := "greyport"
var loadout := {}
var is_transit := false
var from_map_id := ""

var root: Control
var bg_rect: ColorRect
var body_panel: PanelContainer
var shutter_canvas: _ShutterCanvas
var radar_canvas: _RadarCanvas
var drop_canvas: _DropTelemetryCanvas
var prog_canvas: _ProgressCanvas
var stage_lbl: Label
var pct_lbl: Label
var timer_lbl: Label
var log_lbls: Array = []
var slot_status_lbls := {}

var progress := 0.0
var target_progress := 0.0
var shutter_close := 0.0
var elapsed := 0.0
var _logs: Array = []


func _init() -> void:
	layer = 98
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(target_map_id: String, lo: Dictionary, transit_state := {}) -> void:
	map_id = target_map_id if target_map_id != "" else GameData.map_id
	loadout = lo.duplicate()
	is_transit = not transit_state.is_empty()
	from_map_id = str(transit_state.get("from", ""))
	_build_ui()


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = K.theme()
	add_child(root)

	bg_rect = ColorRect.new()
	bg_rect.color = Color(0.03, 0.035, 0.045, 0.0)
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg_rect)

	# 顶部与底部重型机库装甲舱门（合拢/拉开过渡动画）
	shutter_canvas = _ShutterCanvas.new()
	shutter_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shutter_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shutter_canvas)

	# 中央战术简报与加载主面板（v0.8 工业像素面板）
	body_panel = PanelContainer.new()
	body_panel.add_theme_stylebox_override("panel", K.px9("panel9", 16, 16, 16, 14))
	body_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	body_panel.custom_minimum_size = Vector2(940, 536)
	body_panel.offset_left = -470
	body_panel.offset_right = 470
	body_panel.offset_top = -268
	body_panel.offset_bottom = 268
	body_panel.modulate.a = 0.0
	root.add_child(body_panel)
	UI.bind_fit_panel(body_panel)

	var main_v := VBoxContainer.new()
	main_v.add_theme_constant_override("separation", 10)
	body_panel.add_child(main_v)

	# 1. 顶栏：铆钉铭牌 + 行动代号 + 遥测计时 + 警戒条
	var top_plate := PanelContainer.new()
	top_plate.add_theme_stylebox_override("panel", K.px9("plate9", 14, 14, 14, 8))
	main_v.add_child(top_plate)
	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 12)
	top_plate.add_child(top_h)
	var en := Loc.is_en()
	var mode_title := ("Sector Boundary Transit" if en else "战区边界机动") if is_transit else ("Albatross Tactical Drop" if en else "信天翁号战术空投")
	var hdr := UI.header(mode_title, Loc.t("遥测同步", "TELEMETRY LINKED"), 12)
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_h.add_child(hdr)
	timer_lbl = UI.label("T+00.0s  [%s]" % Loc.t("同步", "SYNC"), 12, UI.ACCENT, true)
	top_h.add_child(timer_lbl)

	main_v.add_child(K.hazard_strip(8))

	# 2. 中部双栏：左侧战区卫星扫描 + 右侧空投轨迹与机甲 6 槽自检
	var mid_h := HBoxContainer.new()
	mid_h.add_theme_constant_override("separation", 14)
	mid_h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_v.add_child(mid_h)

	var md: Dictionary = GameData.map_data(map_id)
	var mname := str(md.get("name", map_id))
	var mtag := str(md.get("tag", Loc.t("沦陷地表战区", "Fallen Surface Sector")))
	var mdesc := str(md.get("desc", ""))
	var mhaz := str(md.get("hazard", Loc.t("异虫集群活跃，注意保持机动与弹药储备。", "Active swarm clusters — maintain mobility and ammo discipline.")))

	# ---- 左栏：目标战区情报与雷达扫描 ----
	var left_p := K.card(false, 12)
	left_p.custom_minimum_size = Vector2(415, 0)
	left_p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_h.add_child(left_p)
	var left_v := VBoxContainer.new()
	left_v.add_theme_constant_override("separation", 8)
	left_p.add_child(left_v)

	left_v.add_child(UI.header(Loc.t("目标战区 · ", "Target Sector · ") + mname, mtag, 12))

	var radar_wrap := PanelContainer.new()
	radar_wrap.add_theme_stylebox_override("panel", K.px9("inset9", 6, 6, 6, 6))
	radar_wrap.custom_minimum_size = Vector2(0, 178)
	radar_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_v.add_child(radar_wrap)
	radar_canvas = _RadarCanvas.new()
	radar_canvas.map_name = mname
	radar_canvas.is_transit = is_transit
	radar_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	radar_wrap.add_child(radar_canvas)

	var desc_l := UI.label(mdesc, 12, UI.TEXT)
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_v.add_child(desc_l)

	var haz_l := UI.label(Loc.t("▲ 战区环境：", "▲ Sector Hazard: ") + mhaz, 12, UI.EN_C)
	haz_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_v.add_child(haz_l)

	# 战区首领预警
	var boss_names: Array = []
	var sp: Dictionary = GameData.SPAWNS.get(map_id, {})
	for bk in sp.get("bosses", []):
		var binfo: Dictionary = GameData.ENEMIES.get(str(bk), {})
		if not binfo.is_empty():
			boss_names.append(str(binfo.get("name", bk)))
	var boss_txt := Loc.t("▲ 首领信标：", "▲ Boss Beacons: ") + (" / ".join(boss_names) if not boss_names.is_empty() else Loc.t("高危异虫领主反应 ×2", "Apex Swarm Lords ×2"))
	left_v.add_child(UI.label(boss_txt, 12, UI.BAD))

	# ---- 右栏：空投轨迹动态图 + 机甲系统自检 ----
	var right_p := K.card(false, 12)
	right_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_h.add_child(right_p)
	var right_v := VBoxContainer.new()
	right_v.add_theme_constant_override("separation", 8)
	right_p.add_child(right_v)

	var from_name := str(GameData.map_data(from_map_id).get("name", from_map_id))
	var right_sub := (Loc.t("从「%s」穿越边界进入「%s」", "Crossing border from %s into %s") % [from_name, mname]) if is_transit else Loc.t("高空轨道投放舱 ➔ 反推制动 ➔ 战区着陆点", "Orbital Drop Pod ➔ Retro Burn ➔ Landing Zone")
	right_v.add_child(UI.header(Loc.t("投放轨迹与火控自检", "Trajectory & Systems Check"), right_sub, 12))

	var drop_wrap := PanelContainer.new()
	drop_wrap.add_theme_stylebox_override("panel", K.px9("inset9", 6, 6, 6, 6))
	drop_wrap.custom_minimum_size = Vector2(0, 122)
	right_v.add_child(drop_wrap)
	drop_canvas = _DropTelemetryCanvas.new()
	drop_canvas.is_transit = is_transit
	drop_canvas.from_name = from_name
	drop_canvas.to_name = mname
	drop_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drop_wrap.add_child(drop_canvas)

	# 6 部位模块自检矩阵（带模块图标 + 凹槽指示灯）
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	right_v.add_child(grid)
	var slots := ["core", "legs", "arm_l", "arm_r", "back", "gen"]
	for i in slots.size():
		var sl: String = slots[i]
		var slot_box := PanelContainer.new()
		slot_box.add_theme_stylebox_override("panel", K.px9("inset9", 4, 4, 6, 3))
		slot_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(slot_box)
		var cell := HBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 6)
		slot_box.add_child(cell)
		var sname := str(GameData.SLOT_NAMES.get(sl, sl))
		var mid: String = str(loadout.get(sl, ""))
		if mid != "":
			cell.add_child(K.icon_rect(Icons.icon(mid), 24))
		else:
			cell.add_child(K.icon_rect(K.small_icon("equip"), 24))
		var mtitle := GameData.item_name(mid) if mid != "" else Loc.t("未挂载", "Empty")
		var nl := UI.label("[%s] %s" % [sname, mtitle], 12, UI.TEXT)
		nl.clip_text = true
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(nl)
		var st_l := UI.label("[%s]" % Loc.t("待检", "WAIT"), 12, UI.MUTED)
		cell.add_child(st_l)
		slot_status_lbls[sl] = {"lbl": st_l, "threshold": float(i + 1) / float(slots.size() + 1)}

	var st_stats: Dictionary = GameData.compute_stats(loadout)
	var w_rng := int(round(float(st_stats.get("weapon_range", GameData.STD_RANGE))))
	var v_rng := int(round(float(st_stats.get("view_range", GameData.STD_RANGE))))
	var rec_bonus := int(round(float(st_stats.get("recon", 0.0))))
	var stat_txt := (Loc.t("结构 %d  ·  装甲 %d%%  ·  武器射程 %d  ·  全局视距 %d%s",
		"Hull %d  ·  Armor %d%%  ·  Weapon Range %d  ·  View Range %d%s")) % [
		int(st_stats.get("hp", 100.0)),
		int(round(float(st_stats.get("armor", 0.0)) * 100.0)),
		w_rng,
		v_rng,
		(Loc.t(" ([侦察] +%d)", " ([Recon] +%d)") % rec_bonus) if rec_bonus > 0 else ""
	]
	right_v.add_child(UI.label(stat_txt, 12, UI.INFO))

	# 3. 底部：进度条 + 3 行终端自检日志 + 战术提示
	var bot_v := VBoxContainer.new()
	bot_v.add_theme_constant_override("separation", 6)
	main_v.add_child(bot_v)

	var st_row := HBoxContainer.new()
	bot_v.add_child(st_row)
	stage_lbl = UI.label(Loc.t("正在初始化战区投放序列...", "Initializing drop sequence..."), 14, UI.TEXT, true)
	stage_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st_row.add_child(stage_lbl)
	pct_lbl = UI.label("0%", 15, UI.ACCENT, true)
	st_row.add_child(pct_lbl)

	prog_canvas = _ProgressCanvas.new()
	prog_canvas.custom_minimum_size = Vector2(0, 18)
	bot_v.add_child(prog_canvas)

	var log_panel := PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", K.px9("inset9", 6, 6, 10, 6))
	bot_v.add_child(log_panel)
	var log_v := VBoxContainer.new()
	log_v.add_theme_constant_override("separation", 2)
	log_panel.add_child(log_v)
	for i in 3:
		var ll := UI.label("", 12, UI.MUTED if i < 2 else UI.GOOD)
		ll.clip_text = true
		log_v.add_child(ll)
		log_lbls.append(ll)

	var tips: Array = TIPS_EN if en else TIPS_ZH
	var tip_idx := posmod(map_id.hash() + int(Time.get_ticks_msec() / 1000), tips.size())
	var tip_l := UI.label(tips[tip_idx], 12, UI.INFO)
	tip_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bot_v.add_child(tip_l)


func _process(delta: float) -> void:
	elapsed += delta
	progress = move_toward(progress, target_progress, maxf(delta * 1.8, (target_progress - progress) * delta * 10.0))
	if timer_lbl:
		timer_lbl.text = "T+%04.1fs  [%s]" % [elapsed, Loc.t("就绪" if progress >= 0.995 else "加载中", "READY" if progress >= 0.995 else "LOADING")]
	if pct_lbl:
		pct_lbl.text = "%d%%" % clampi(int(round(progress * 100.0)), 0, 100)
	for sl in slot_status_lbls:
		var item: Dictionary = slot_status_lbls[sl]
		var l: Label = item.lbl
		var ok: bool = progress >= float(item.threshold)
		l.text = "[%s]" % Loc.t("就绪" if ok else "待检", "OK" if ok else "WAIT")
		l.add_theme_color_override("font_color", UI.GOOD if ok else UI.MUTED)
	if radar_canvas:
		radar_canvas.anim_t = elapsed
		radar_canvas.progress = progress
		radar_canvas.queue_redraw()
	if drop_canvas:
		drop_canvas.anim_t = elapsed
		drop_canvas.progress = progress
		drop_canvas.queue_redraw()
	if prog_canvas:
		prog_canvas.progress = progress
		prog_canvas.anim_t = elapsed
		prog_canvas.queue_redraw()
	if shutter_canvas:
		shutter_canvas.close_ratio = shutter_close
		shutter_canvas.queue_redraw()


## 更新加载阶段与终端日志，并让出一帧供渲染器绘制动画与进度条
func step(ratio: float, text: String) -> void:
	target_progress = clampf(ratio, 0.0, 1.0)
	if ratio >= 1.0:
		progress = 1.0
	if stage_lbl:
		stage_lbl.text = text
	_logs.append("> [%02d%%] %s" % [int(round(target_progress * 100.0)), text])
	while _logs.size() > 3:
		_logs.pop_front()
	for i in log_lbls.size():
		var idx := _logs.size() - log_lbls.size() + i
		log_lbls[i].text = _logs[idx] if idx >= 0 else ""
	_process(0.016)
	if is_inside_tree():
		await get_tree().process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw


## 阶段一：合拢机库装甲舱门并浮现战术加载台
func play_close(dur := 0.34) -> void:
	Audio.play_sfx("drop_retro")
	var tw := create_tween()
	tw.tween_property(self, "shutter_close", 1.0, dur * 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(bg_rect, "color:a", 0.96, dur * 0.7)
	tw.tween_property(body_panel, "modulate:a", 1.0, dur * 0.45).set_trans(Tween.TRANS_SINE)
	await tw.finished
	if is_inside_tree():
		await get_tree().process_frame


## 阶段三：100% 就绪后收起面板、拉开装甲舱门并销毁加载层
func play_open(dur := 0.55) -> void:
	await step(1.0, Loc.t("机甲火控与战术系统自检完成 · 舱门解锁投放！", "Fire-control & tactical systems online — unlocking drop doors!"))
	var tw := create_tween()
	tw.tween_interval(0.12)
	tw.tween_property(body_panel, "modulate:a", 0.0, dur * 0.38).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "shutter_close", 0.0, dur * 0.68).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(bg_rect, "color:a", 0.0, dur * 0.62)
	await tw.finished
	queue_free()


# ================================================================ 子画布：装甲舱门
class _ShutterCanvas extends Control:
	var close_ratio := 0.0

	func _draw() -> void:
		if close_ratio <= 0.001:
			return
		var sz := size
		var half_h := sz.y * 0.5 * clampf(close_ratio, 0.0, 1.0)
		var plate_c := Color(0.072, 0.078, 0.084, 0.98)
		var rib_c := Color(0.24, 0.26, 0.28, 0.94)
		var steel_trim := Color(0.16, 0.18, 0.20, 0.96)
		var stripe_y := 18.0

		# 上下废土重型灰白/铅灰装甲舱门
		draw_rect(Rect2(0, 0, sz.x, half_h), plate_c)
		draw_rect(Rect2(0, sz.y - half_h, sz.x, half_h), plate_c)

		# 横向工业灰黑加强筋与浅凹槽
		for r: float in [0.35, 0.7]:
			var y1: float = half_h * r
			var y2: float = sz.y - half_h * r
			draw_rect(Rect2(0, y1 - 4.0, sz.x, 8.0), steel_trim)
			draw_rect(Rect2(0, y1 - 2.0, sz.x, 3.0), rib_c)
			draw_rect(Rect2(0, y2 - 4.0, sz.x, 8.0), steel_trim)
			draw_rect(Rect2(0, y2 - 2.0, sz.x, 3.0), rib_c)

		# 门沿碳灰/做旧橙黄警示条与咬合线
		if half_h > stripe_y:
			_draw_hazard_bar(Rect2(0, half_h - stripe_y, sz.x, stripe_y))
			_draw_hazard_bar(Rect2(0, sz.y - half_h, sz.x, stripe_y))
		var seam_c := Color(0.84, 0.56, 0.22, clampf(close_ratio * 1.1, 0.0, 1.0))
		draw_line(Vector2(0, half_h), Vector2(sz.x, half_h), seam_c, 2.5)
		draw_line(Vector2(0, sz.y - half_h), Vector2(sz.x, sz.y - half_h), seam_c, 2.5)

	func _draw_hazard_bar(r: Rect2) -> void:
		draw_rect(r, Color(0.08, 0.085, 0.09, 1.0))
		var step := 28.0
		var x := r.position.x - r.size.y
		while x < r.end.x + r.size.y:
			var pts := PackedVector2Array([
				Vector2(clampf(x, r.position.x, r.end.x), r.end.y),
				Vector2(clampf(x + step * 0.5, r.position.x, r.end.x), r.end.y),
				Vector2(clampf(x + step * 0.5 + r.size.y, r.position.x, r.end.x), r.position.y),
				Vector2(clampf(x + r.size.y, r.position.x, r.end.x), r.position.y),
			])
			draw_colored_polygon(pts, Color(0.76, 0.47, 0.16, 0.90))
			x += step


# ================================================================ 子画布：卫星雷达扫描
class _RadarCanvas extends Control:
	var anim_t := 0.0
	var progress := 0.0
	var map_name := ""
	var is_transit := false

	func _draw() -> void:
		var sz := size
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.06, 0.065, 0.065, 0.96))
		var grid_c := Color(0.55, 0.62, 0.58, 0.14)
		var step := 24.0
		var x := step
		while x < sz.x:
			draw_line(Vector2(x, 0), Vector2(x, sz.y), grid_c, 1.0)
			x += step
		var y := step
		while y < sz.y:
			draw_line(Vector2(0, y), Vector2(sz.x, y), grid_c, 1.0)
			y += step

		var c := sz * 0.5
		var max_r := minf(sz.x, sz.y) * 0.42
		for frac in [0.35, 0.68, 1.0]:
			draw_arc(c, max_r * frac, 0.0, TAU, 48, Color(0.68, 0.72, 0.70, 0.28), 1.2)
		draw_line(Vector2(c.x - max_r * 1.15, c.y), Vector2(c.x + max_r * 1.15, c.y), Color(0.68, 0.72, 0.70, 0.22), 1.0)
		draw_line(Vector2(c.x, c.y - max_r * 1.15), Vector2(c.x, c.y + max_r * 1.15), Color(0.68, 0.72, 0.70, 0.22), 1.0)

		# 旋转扫描扇区
		var ang := anim_t * 2.4
		for i in 12:
			var a0 := ang - float(i) * 0.045
			var a1 := a0 - 0.045
			var alpha := (1.0 - float(i) / 12.0) * 0.22
			var pts := PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * max_r, c + Vector2(cos(a1), sin(a1)) * max_r])
			draw_colored_polygon(pts, Color(0.46, 0.72, 0.58, alpha))
		draw_line(c, c + Vector2(cos(ang), sin(ang)) * max_r, Color(0.58, 0.82, 0.66, 0.85), 1.8)

		# 首领高危热点（铁锈红）与撤离点（工业灰白/浅绿）与着陆点（做旧橙黄）
		var pulse := 0.5 + 0.5 * sin(anim_t * 6.0)
		for bp: Vector2 in [Vector2(-0.48, -0.36), Vector2(0.52, 0.28)]:
			var p: Vector2 = c + bp * max_r
			draw_circle(p, 4.0 + pulse * 2.5, Color(0.80, 0.26, 0.20, 0.30))
			draw_circle(p, 3.2, Color(0.84, 0.32, 0.24, 0.95))
		for ep: Vector2 in [Vector2(-0.62, 0.55), Vector2(0.65, -0.48)]:
			var p: Vector2 = c + ep * max_r
			draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(0.48, 0.74, 0.52, 0.88))
		var lz := c + (Vector2(-0.75, 0.0) if is_transit else Vector2(0.08, 0.12)) * max_r
		draw_arc(lz, 6.5 + (1.0 - progress) * 8.0, 0.0, TAU, 24, Color(0.84, 0.54, 0.20, 0.92), 1.6)
		draw_circle(lz, 3.0, Color(0.88, 0.62, 0.28, 1.0))

		# 横向地形扫描线
		var scan_y := fposmod(anim_t * 58.0, sz.y)
		draw_line(Vector2(0, scan_y), Vector2(sz.x, scan_y), Color(0.80, 0.50, 0.18, 0.36), 1.2)


# ================================================================ 子画布：空投/转场轨迹图
class _DropTelemetryCanvas extends Control:
	var anim_t := 0.0
	var progress := 0.0
	var is_transit := false
	var from_name := ""
	var to_name := ""

	func _draw() -> void:
		var sz := size
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.07, 0.075, 0.08, 0.96))
		var p0 := Vector2(36.0, 24.0)
		var p1 := Vector2(sz.x * 0.46, 32.0)
		var p2 := Vector2(sz.x * 0.72, sz.y - 34.0)
		var p3 := Vector2(sz.x - 42.0, sz.y - 24.0)
		if is_transit:
			p0 = Vector2(42.0, sz.y * 0.52)
			p1 = Vector2(sz.x * 0.38, sz.y * 0.42)
			p2 = Vector2(sz.x * 0.66, sz.y * 0.58)
			p3 = Vector2(sz.x - 42.0, sz.y * 0.52)

		# 地面基线
		draw_line(Vector2(16, sz.y - 22), Vector2(sz.x - 16, sz.y - 22), Color(0.36, 0.39, 0.42, 0.30), 1.2)

		# 轨迹虚线与已完成高亮段
		var segs := 28
		var prev := p0
		for i in range(1, segs + 1):
			var u := float(i) / float(segs)
			var pt := _bezier(p0, p1, p2, p3, u)
			var active := u <= progress
			var col := Color(0.82, 0.52, 0.18, 0.94) if active else Color(0.34, 0.37, 0.40, 0.35)
			if i % 2 == 1 or active:
				draw_line(prev, pt, col, 2.2 if active else 1.2)
			prev = pt

		# 起点（信天翁号母舰 / 原战区）与终点（LZ 着陆点 / 目标战区）
		draw_circle(p0, 4.5, Color(0.46, 0.49, 0.52, 0.94))
		draw_circle(p3, 5.0, Color(0.46, 0.72, 0.48, 0.95))

		# 当前空投舱/机甲位置游标与尾焰
		var cur := _bezier(p0, p1, p2, p3, clampf(progress, 0.0, 1.0))
		var pulse := 1.0 + 0.35 * sin(anim_t * 12.0)
		draw_circle(cur, 7.0 * pulse, Color(0.82, 0.48, 0.16, 0.35))
		draw_circle(cur, 4.0, Color(0.89, 0.64, 0.30, 1.0))

		var font := PixelUI.pixel_font()
		if font:
			var loc := get_node_or_null("/root/Loc")
			var is_e := loc != null and bool(loc.call("is_en"))
			var alt := int(round(lerpf(4200.0, 0.0, clampf(progress, 0.0, 1.0))))
			var vel := int(round(lerpf(280.0, 18.0, progress)))
			var pct := int(round(progress * 100.0))
			var top_txt := (("Progress %d%%  ·  Transit Gate Clear" if is_e else "推进距离 %d%%  ·  边界通道畅通") % pct) if is_transit else (("ALT %04dm  ·  VEL %d m/s" if is_e else "高度 %04dm  ·  速度 %d m/s") % [alt, vel])
			draw_string(font, Vector2(18, 20), top_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.87, 0.59, 0.25))
			draw_string(font, Vector2(sz.x - 110, sz.y - 8), "LZ LOCKED" if is_e else "着陆点锁定", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.48, 0.74, 0.52))

	static func _bezier(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
		var u := 1.0 - t
		return u * u * u * a + 3.0 * u * u * t * b + 3.0 * u * t * t * c + t * t * t * d


# ================================================================ 子画布：战术分段进度条
class _ProgressCanvas extends Control:
	var progress := 0.0
	var anim_t := 0.0

	func _draw() -> void:
		var sz := size
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.058, 0.062, 0.068, 0.97))
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.32, 0.35, 0.38, 0.36), false, 1.0)
		var pad := 3.0
		var inner := Rect2(pad, pad, maxf(0.0, sz.x - pad * 2.0), maxf(0.0, sz.y - pad * 2.0))
		var fill_w := inner.size.x * clampf(progress, 0.0, 1.0)
		if fill_w > 0.5:
			draw_rect(Rect2(inner.position, Vector2(fill_w, inner.size.y)), Color(0.78, 0.48, 0.16, 0.95))
			var head_w := minf(14.0, fill_w)
			draw_rect(Rect2(inner.position.x + fill_w - head_w, inner.position.y, head_w, inner.size.y), Color(0.90, 0.89, 0.84, 0.96))
		# 分段刻度线
		var segs := 20
		for i in range(1, segs):
			var x := inner.position.x + inner.size.x * (float(i) / float(segs))
			draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color(0.05, 0.05, 0.06, 0.75), 1.5)
