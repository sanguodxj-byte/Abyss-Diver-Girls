extends CanvasLayer
## 对话演出播放器：视觉小说式全屏演出。立绘与表情切换、说话人名牌、逐字中文字幕、日语配音、点击推进、
## 自动播放、快进、跳过、回看记录。
##
## 演出期间暂停游戏树并显示鼠标，结束后原样恢复；Esc 与「跳过」在打字、立绘滑入、自动等待、记录面板打开时
## 都直接结束演出，不经过任何动画或阶段条件。立绘文件缺失时画剪影占位，配音文件缺失时静默，功能照常。
## 剧情数据格式见 scripts\story\story_data.gd。

signal finished(reason: String)   ## end = 播完，skip = 跳过，escape = Esc

const UI = preload("res://scripts/ui.gd")
const AP = preload("res://scripts/asset_paths.gd")
const Growth = preload("res://scripts/progression/growth.gd")

const TEXT_SPEED := 34.0      ## 逐字速度（字/秒）
const FF_SPEED := 260.0       ## 快进时的逐字速度
const AUTO_HOLD := 1.4        ## 自动播放：一句显示完后停留的秒数
const FF_HOLD := 0.08
const SLOT_W := 500.0
const SLOT_H := 400.0
const BOX_H := 190.0

var story
var scene := {}
var scene_id := ""
var lines: Array = []

var _i := -1
var _shown := 0.0
var _typing := false
var _hold := 0.0
var _voice_len := 0.0
var _auto := false
var _ff := false
var _finished := false
var _prev_paused := false
var _prev_mouse := Input.MOUSE_MODE_HIDDEN
var _hist: Array = []
var _slots := {}          ## "left" / "right" -> {"char": id, "node": PortraitPlace, "seq": int}
var _focus_seq := 0

var _root: Control
var _backdrop: ColorRect
var _illu: TextureRect
var _stage: Control
var _box: PanelContainer
var _plate: PanelContainer
var _name_lbl: Label
var _text_lbl: Label
var _counter: Label
var _title_lbl: Label
var _chapter_lbl: Label
var _gauge: LineGauge
var _voice_bars: VoiceBars
var _btn_auto: Button
var _btn_ff: Button
var _backlog: PanelContainer
var _backlog_dim: ColorRect
var _backlog_box: VBoxContainer
var _backlog_scroll: ScrollContainer


func open(st: Node, sc: Dictionary, sid: String, start_line := 0) -> void:
	story = st
	scene = sc
	scene_id = sid
	lines = sc.get("lines", []) if typeof(sc.get("lines")) == typeof([]) else []
	_prev_paused = get_tree().paused
	_prev_mouse = Input.mouse_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 92
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	if lines.is_empty():
		_finish("end")
		return
	_i = clampi(start_line, 0, lines.size() - 1)
	for k in range(0, _i):
		_remember(_lines_line(k), true)
	_show_line(_i)
	Audio.play_ui("story_open")


func is_open() -> bool:
	return not _finished


# ============================================================ 构建
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UI.theme()
	add_child(_root)

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_input)
	_root.add_child(_backdrop)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BACKDROP_SHADER
	mat.shader = sh
	_backdrop.material = mat

	_illu = TextureRect.new()
	_illu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_illu.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_illu.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_illu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := str(scene.get("bg", ""))
	if bg != "":
		var tex := AP.illustration(bg)
		_illu.texture = tex
		_illu.modulate = Color(0.92, 0.92, 0.94, 0.9 if tex else 0.0)
	_root.add_child(_illu)

	# 下半部压暗：立绘与字幕都压在这层之上，保证中文字幕始终可读
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	grad.colors = PackedColorArray([Color(0.02, 0.02, 0.03, 0.15), Color(0.02, 0.02, 0.03, 0.55), Color(0.02, 0.02, 0.03, 0.94)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	_root.add_child(shade)

	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stage)

	_build_title()
	_build_portraits()
	_build_box()
	_build_backlog()


func _build_title() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_TOP)
	v.offset_top = 26
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(v)
	var ch_id := str(scene.get("chapter", ""))
	var ch: Dictionary = story.chapter_data(ch_id) if story != null and ch_id != "" else {}
	_chapter_lbl = UI.label(str(ch.get("title", "")), 13, UI.ACCENT, true)
	_chapter_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chapter_lbl.visible = str(ch.get("title", "")) != ""
	v.add_child(_chapter_lbl)
	_title_lbl = UI.label(str(scene.get("title", "")), 22, Color(0.96, 0.94, 0.9), true)
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title_lbl)
	var rule := ColorRect.new()
	rule.color = Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, 0.55)
	rule.custom_minimum_size = Vector2(260, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(rule)


func _build_portraits() -> void:
	for side in ["left", "right"]:
		var p := PortraitPlace.new()
		p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT if side == "left" else Control.PRESET_BOTTOM_RIGHT)
		p.offset_bottom = -BOX_H - 16.0
		p.offset_top = -BOX_H - 16.0 - SLOT_H
		if side == "left":
			p.offset_left = 24.0
			p.offset_right = 24.0 + SLOT_W
		else:
			p.offset_left = -24.0 - SLOT_W
			p.offset_right = -24.0
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.modulate.a = 0.0
		_stage.add_child(p)
		_slots[side] = {"char": "", "node": p, "seq": 0}


func _build_box() -> void:
	_box = PanelContainer.new()
	_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_box.offset_left = 110
	_box.offset_right = -110
	_box.offset_top = -34 - BOX_H
	_box.offset_bottom = -34
	_box.add_theme_stylebox_override("panel", UI.tex9("panel9", 14, 26))
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(v)

	_text_lbl = UI.label("", 20, Color(0.95, 0.93, 0.89), true)
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_lbl.add_theme_constant_override("line_spacing", 9)
	_text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_text_lbl)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	_gauge = LineGauge.new()
	_gauge.custom_minimum_size = Vector2(0, 8)
	_gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_gauge)
	_btn_auto = _small_button("自动", func(): _toggle_auto())
	_btn_auto.toggle_mode = true
	_btn_ff = _small_button("快进", func(): _toggle_ff())
	_btn_ff.toggle_mode = true
	row.add_child(_btn_auto)
	row.add_child(_btn_ff)
	row.add_child(_small_button("记录", func(): _toggle_backlog()))
	row.add_child(_small_button("跳过", func(): _finish("skip")))
	row.add_child(_small_button("退出", func(): _finish("escape")))

	# 名牌：压在对话框上沿的贴片，左边说话人，右边台词进度
	_plate = PanelContainer.new()
	_plate.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_plate.offset_left = 140
	_plate.offset_right = -140
	_plate.offset_top = -34 - BOX_H - 14
	_plate.offset_bottom = -34 - BOX_H + 22
	_plate.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_plate.add_theme_stylebox_override("panel", UI.tex9("strip9", 8, 14))
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_plate)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 10)
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(ph)
	_name_lbl = UI.label("", 17, Color(1, 0.93, 0.8), true)
	_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(_name_lbl)
	_voice_bars = VoiceBars.new()
	_voice_bars.custom_minimum_size = Vector2(22, 16)
	_voice_bars.size_flags_vertical = Control.SIZE_SHRINK_END
	_voice_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(_voice_bars)
	var psp := Control.new()
	psp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	psp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(psp)
	_counter = UI.label("", 12, UI.MUTED)
	_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(_counter)


func _small_button(text: String, act: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(54, 26)
	b.add_theme_font_size_override("font_size", 13)
	b.set_meta("sfx", "ui_click")
	b.pressed.connect(act)
	return b


func _build_backlog() -> void:
	_backlog_dim = ColorRect.new()
	_backlog_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backlog_dim.color = Color(0.015, 0.015, 0.02, 0.62)
	_backlog_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_backlog_dim.visible = false
	_stage.add_child(_backlog_dim)
	_backlog = UI.panel(18)
	_backlog.set_anchors_preset(Control.PRESET_CENTER)
	_backlog.custom_minimum_size = Vector2(820, 470)
	_backlog.offset_left = -410
	_backlog.offset_right = 410
	_backlog.offset_top = -235
	_backlog.offset_bottom = 235
	_backlog.z_index = 5
	_backlog.visible = false
	_backlog.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.add_child(_backlog)
	var back := ColorRect.new()
	back.color = Color(0.055, 0.058, 0.07, 0.97)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backlog.add_child(back)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_backlog.add_child(v)
	v.add_child(UI.header("记录", "", 18))
	_backlog_scroll = ScrollContainer.new()
	_backlog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_backlog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_backlog_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	v.add_child(_backlog_scroll)
	_backlog_box = VBoxContainer.new()
	_backlog_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_backlog_box.add_theme_constant_override("separation", 10)
	_backlog_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backlog_scroll.add_child(_backlog_box)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	v.add_child(foot)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	foot.add_child(_small_button("关闭", func(): _toggle_backlog()))


# ============================================================ 台词
func _lines_line(i: int) -> Dictionary:
	if i < 0 or i >= lines.size():
		return {}
	var ln = lines[i]
	return ln if typeof(ln) == TYPE_DICTIONARY else {}


func _remember(ln: Dictionary, prefill := false) -> void:
	var sp := str(ln.get("speaker", ""))
	var c: Dictionary = story.character(sp) if story != null and sp != "" else {}
	_hist.append({"name": str(c.get("name_zh", "")), "text": Growth.subst(str(ln.get("zh", ""))), "narrator": sp == ""})
	if not prefill:
		_fill_backlog()


func _fill_backlog() -> void:
	if _backlog_box == null:
		return
	for ch in _backlog_box.get_children():
		ch.queue_free()
	# 最新的台词排在最上面，打开记录时不用滚动就能看到刚播过的一句
	for k in range(_hist.size() - 1, -1, -1):
		var h: Dictionary = _hist[k]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bar := ColorRect.new()
		bar.color = Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, 0.7 if not h.narrator else 0.28)
		bar.custom_minimum_size = Vector2(3, 0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bar)
		var name_l := UI.label(str(h.name) if not h.narrator else "——", 13, UI.ACCENT if not h.narrator else UI.MUTED)
		name_l.custom_minimum_size = Vector2(96, 0)
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_l)
		var t := UI.label(str(h.text), 15, UI.TEXT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(t)
		_backlog_box.add_child(row)


func _show_line(i: int) -> void:
	var ln := _lines_line(i)
	if ln.is_empty():
		_finish("end")
		return
	var sp := str(ln.get("speaker", ""))
	var c: Dictionary = story.character(sp) if story != null and sp != "" else {}
	_name_lbl.text = str(c.get("name_zh", ""))
	_plate.visible = sp != ""
	_focus(sp, str(ln.get("expr", "")))
	var zh := Growth.subst(str(ln.get("zh", "")))
	_text_lbl.text = zh
	_text_lbl.visible_characters = 0
	_shown = 0.0
	_typing = true
	_hold = 0.0
	_counter.text = "%d / %d" % [i + 1, lines.size()]
	_gauge.set_frac(float(i) / maxf(1.0, float(lines.size() - 1)))
	_voice_len = 0.0
	var v := str(ln.get("voice", ""))
	if v != "":
		_voice_len = Audio.play_voice(v)
	if _typing:
		Audio.play_ui("story_text")
	_remember(ln)
	if story != null:
		story.set_progress(scene_id, i)


## 立绘站位：同一时刻左右两席；新上场角色占用空席，两席都满时替换最久没说话的那个
func _focus(sp: String, expr: String) -> void:
	_focus_seq += 1
	if sp == "":
		for side in _slots:
			_set_dim(side, 0.0)
		return
	var slot := ""
	for side in _slots:
		if str(_slots[side].char) == sp:
			slot = side
	if slot == "":
		if str(_slots.left.char) == "":
			slot = "left"
		elif str(_slots.right.char) == "":
			slot = "right"
		else:
			slot = "left" if int(_slots.left.seq) <= int(_slots.right.seq) else "right"
		var n: PortraitPlace = _slots[slot].node
		n.set_tex(AP.portrait(sp, expr))
		_slots[slot].char = sp
		_appear(slot)
	else:
		var n: PortraitPlace = _slots[slot].node
		n.set_tex(AP.portrait(sp, expr))
	_slots[slot].seq = _focus_seq
	for side in _slots:
		_set_dim(side, 1.0 if side == slot else 0.52)


func _set_dim(side: String, a: float) -> void:
	var n: PortraitPlace = _slots[side].node
	if str(_slots[side].char) == "":
		a = 0.0
	var tw := create_tween()
	tw.tween_property(n, "modulate:a", a, 0.16)


func _appear(side: String) -> void:
	var n: PortraitPlace = _slots[side].node
	var base := n.position
	var dir := -1.0 if side == "left" else 1.0
	n.position = base + Vector2(dir * 42.0, 0)
	n.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(n, "position", base, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "modulate:a", 1.0, 0.26)


# ============================================================ 推进与输入
func _process(delta: float) -> void:
	if _finished:
		return
	var ff := _ff or Input.is_key_pressed(KEY_CTRL)
	if _typing:
		_shown += (FF_SPEED if ff else TEXT_SPEED) * delta
		_text_lbl.visible_characters = int(_shown)
		if int(_shown) >= _text_lbl.text.length():
			_typing = false
			_text_lbl.visible_characters = -1
			_hold = FF_HOLD if ff else AUTO_HOLD
	elif _auto or ff:
		if not ff and _voice_len > 0.0 and Audio.is_voice_playing():
			pass
		else:
			_hold -= delta
		if _hold <= 0.0:
			_advance()


func _advance() -> void:
	if _finished:
		return
	if _backlog.visible:
		_toggle_backlog()
		return
	var ff := _ff or Input.is_key_pressed(KEY_CTRL)
	if _typing:
		_typing = false
		_text_lbl.visible_characters = -1
		_hold = FF_HOLD if ff else AUTO_HOLD
		return
	_next()


func _next() -> void:
	if _finished:
		return
	_i += 1
	Audio.stop_voice()
	if _i >= lines.size():
		_finish("end")
		return
	_show_line(_i)


func _toggle_auto() -> void:
	_auto = _btn_auto.button_pressed
	if _auto and not _typing:
		_hold = AUTO_HOLD


func _toggle_ff() -> void:
	_ff = _btn_ff.button_pressed


func _toggle_backlog() -> void:
	_backlog.visible = not _backlog.visible
	_backlog_dim.visible = _backlog.visible
	if _backlog.visible:
		_fill_backlog()
	Audio.play_ui("ui_open" if _backlog.visible else "ui_close")


func _on_backdrop_input(event: InputEvent) -> void:
	if _finished:
		return
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	if pressed:
		_advance()
		_backdrop.accept_event()


func _input(event: InputEvent) -> void:
	if _finished or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed or k.echo:
		return
	var used := true
	match k.keycode:
		KEY_ESCAPE:
			_finish("escape")
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			_advance()
		KEY_A:
			_btn_auto.button_pressed = not _auto
			_toggle_auto()
		KEY_L:
			_toggle_backlog()
		KEY_S:
			_finish("skip")
		_:
			used = false
	if used:
		get_viewport().set_input_as_handled()


## 结束演出：恢复演出前的暂停与鼠标状态，再通知调度者；任何阶段都可调用
func _finish(reason: String) -> void:
	if _finished:
		return
	_finished = true
	Audio.stop_voice()
	Audio.play_ui("story_close")
	get_tree().paused = _prev_paused
	Input.mouse_mode = _prev_mouse
	finished.emit(reason)
	queue_free()


func _exit_tree() -> void:
	if _finished:
		return
	_finished = true
	Audio.stop_voice()
	if is_inside_tree():
		get_tree().paused = _prev_paused
	Input.mouse_mode = _prev_mouse


# ---------- 测试与外部查询 ----------
func current_line() -> int:
	return _i


func line_count() -> int:
	return lines.size()


func name_text() -> String:
	return _name_lbl.text if _name_lbl != null else ""


func visible_text() -> String:
	if _text_lbl == null:
		return ""
	var n: int = _text_lbl.visible_characters
	return _text_lbl.text if n < 0 else _text_lbl.text.substr(0, n)


func is_typing() -> bool:
	return _typing


func backlog_open() -> bool:
	return _backlog != null and _backlog.visible


func auto_on() -> bool:
	return _auto


func press(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	_input(ev)


# ============================================================ 背景与部件
const BACKDROP_SHADER := """
shader_type canvas_item;
uniform vec4 top_col : source_color = vec4(0.055, 0.062, 0.078, 1.0);
uniform vec4 bot_col : source_color = vec4(0.13, 0.108, 0.094, 1.0);
uniform vec4 glow_col : source_color = vec4(1.0, 0.62, 0.24, 1.0);
uniform float glow_amt = 0.30;
uniform vec2 glow_pos = vec2(0.5, 0.60);
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1.0,0.0)), f.x), mix(h(i+vec2(0.0,1.0)), h(i+vec2(1.0,1.0)), f.x), f.y); }
void fragment(){
	vec2 uv = UV;
	vec3 c = mix(top_col.rgb, bot_col.rgb, smoothstep(0.0, 1.0, uv.y));
	float g = exp(-length((uv - glow_pos) * vec2(1.55, 1.0)) * 2.1);
	c += glow_col.rgb * g * glow_amt;
	float fog = n2(uv * vec2(3.1, 2.2) + vec2(TIME * 0.012, 0.0));
	c += (fog - 0.5) * 0.035;
	float hatch = smoothstep(0.49, 0.51, fract((uv.x + uv.y * 0.55) * 44.0));
	c += (hatch - 0.5) * 0.016;
	c *= 1.0 - 0.045 * smoothstep(0.55, 1.0, sin(uv.y * 540.0));
	float grain = h(floor(uv * vec2(520.0, 300.0)) + vec2(fract(TIME * 0.7) * 97.0));
	c += (grain - 0.5) * 0.030;
	float v = smoothstep(0.92, 0.32, length((uv - 0.5) * vec2(1.18, 1.0)));
	c *= mix(0.52, 1.0, v);
	float line_y = 0.615;
	c += glow_col.rgb * (1.0 - smoothstep(0.0, 0.0022, abs(uv.y - line_y))) * 0.14;
	COLOR = vec4(c, 1.0);
}
"""


## 立绘位：有贴图时按高度等比铺开，没有贴图时画人形剪影占位（不写任何文字）
class PortraitPlace extends Control:
	var tex: Texture2D
	var accent := Color(1.0, 0.69, 0.13)

	func set_tex(t: Texture2D) -> void:
		if t != tex:
			tex = t
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w <= 0.0 or h <= 0.0:
			return
		var c := Vector2(w * 0.5, h * 0.55)
		for i in 4:
			draw_circle(c, minf(w, h) * (0.20 + 0.075 * i), Color(1.0, 0.72, 0.32, 0.026))
		if tex:
			var tw := float(tex.get_width())
			var th := float(tex.get_height())
			var k := minf(w / tw, h / th)
			var d := Vector2(tw * k, th * k)
			draw_texture_rect(tex, Rect2(Vector2((w - d.x) * 0.5, h - d.y), d), false)
		else:
			var cx := w * 0.5
			var hr := minf(w, h) * 0.105
			var hy := h * 0.285
			for i in 16:
				draw_circle(Vector2(cx, h * 0.56), minf(w, h) * (0.14 + 0.024 * i), Color(1.0, 0.70, 0.30, 0.006))
			var sh_y := hy + hr * 1.45
			var bust := PackedVector2Array([
				Vector2(cx - hr * 3.05, h),
				Vector2(cx - hr * 2.95, sh_y + hr * 0.75),
				Vector2(cx - hr * 1.95, sh_y + hr * 0.18),
				Vector2(cx - hr * 1.05, sh_y - hr * 0.32),
				Vector2(cx - hr * 0.60, hy + hr * 0.70),
				Vector2(cx, hy + hr * 0.50),
				Vector2(cx + hr * 0.60, hy + hr * 0.70),
				Vector2(cx + hr * 1.05, sh_y - hr * 0.32),
				Vector2(cx + hr * 1.95, sh_y + hr * 0.18),
				Vector2(cx + hr * 2.95, sh_y + hr * 0.75),
				Vector2(cx + hr * 3.05, h),
			])
			draw_colored_polygon(bust, Color(0.155, 0.165, 0.19, 0.985))
			for s in [-1.0, 1.0]:
				var a := Vector2(cx + s * hr * 1.05, sh_y - hr * 0.32)
				var b := Vector2(cx + s * hr * 1.95, sh_y + hr * 0.18)
				var c2 := Vector2(cx + s * hr * 2.55, sh_y + hr * 1.05)
				var d2 := Vector2(cx + s * hr * 1.55, sh_y + hr * 1.55)
				draw_colored_polygon(PackedVector2Array([a, b, c2, d2]), Color(0.175, 0.185, 0.21, 0.985))
				draw_line(a, b, Color(accent.r, accent.g, accent.b, 0.30), 2.0, true)
			draw_circle(Vector2(cx, hy), hr, Color(0.185, 0.195, 0.22, 0.985))
			draw_arc(Vector2(cx, hy), hr * 1.10, PI * 1.02, PI * 1.98, 26, Color(accent.r, accent.g, accent.b, 0.45), 2.5, true)
			draw_line(Vector2(cx - hr * 0.62, hy + hr * 0.05), Vector2(cx + hr * 0.62, hy + hr * 0.05),
				Color(accent.r, accent.g, accent.b, 0.35), 2.0, true)
			draw_line(Vector2(cx, hy + hr * 1.70), Vector2(cx, h), Color(1, 1, 1, 0.05), 2.0, true)
			draw_polyline(PackedVector2Array([Vector2(cx - hr * 0.60, hy + hr * 0.70), Vector2(cx, hy + hr * 1.62),
				Vector2(cx + hr * 0.60, hy + hr * 0.70)]), Color(1, 1, 1, 0.08), 2.0, true)
			draw_polyline(bust, Color(accent.r, accent.g, accent.b, 0.26), 2.0, true)
			# 无立绘文件时头顶画一枚菱形标记，是占位而不是角色本身的一部分
			var top := Vector2(cx, hy - hr * 1.95)
			draw_colored_polygon(PackedVector2Array([top + Vector2(0, -7), top + Vector2(7, 0), top + Vector2(0, 7), top + Vector2(-7, 0)]),
				Color(accent.r, accent.g, accent.b, 0.45))
		var l := 26.0
		var col := Color(accent.r, accent.g, accent.b, 0.42)
		for sx in [0.0, 1.0]:
			for sy in [0.0, 1.0]:
				var o := Vector2(sx * w, sy * h)
				var dx := -1.0 if sx > 0.0 else 1.0
				var dy := -1.0 if sy > 0.0 else 1.0
				draw_line(o, o + Vector2(dx * l, 0), col, 1.5)
				draw_line(o, o + Vector2(0, dy * l), col, 1.5)


## 台词进度：细线上的一枚菱形标记，随台词序号右移
class LineGauge extends Control:
	var frac := 0.0
	var accent := Color(1.0, 0.69, 0.13)

	func set_frac(f: float) -> void:
		if absf(f - frac) > 0.001:
			frac = f
			queue_redraw()

	func _draw() -> void:
		var y := size.y * 0.5
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.10), 1.0)
		var x := size.x * clampf(frac, 0.0, 1.0)
		draw_line(Vector2(0, y), Vector2(x, y), Color(accent.r, accent.g, accent.b, 0.5), 1.5)
		var p := Vector2(x, y)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4), p + Vector2(4, 0), p + Vector2(0, 4), p + Vector2(-4, 0)]),
			Color(accent.r, accent.g, accent.b, 0.9))


## 配音指示：有配音播放时四根竖条起伏，没有配音时只剩一条暗线
class VoiceBars extends Control:
	var t := 0.0
	var accent := Color(1.0, 0.8, 0.45)

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var on := Audio.is_voice_playing()
		var n := 4
		var w := 3.0
		var gap := (size.x - w * n) / maxf(1.0, float(n - 1))
		for i in n:
			var hh := 3.0
			if on:
				hh = 4.0 + (sin(t * 9.0 + i * 1.7) + 1.0) * 0.5 * (size.y - 6.0)
			draw_rect(Rect2(i * (w + gap), size.y * 0.5 - hh * 0.5, w, hh),
				Color(accent.r, accent.g, accent.b, 0.85 if on else 0.25))
