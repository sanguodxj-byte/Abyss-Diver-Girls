extends PanelContainer
## 局内无线电通讯小窗：头像、名字、中文字幕、日语配音。
## 挂在行动界面左上角、现有 HUD 元素之外的空白处（左下 L 形状态栏上方、右上雷达左侧、右下消耗品卡之外），
## 整块不接收鼠标、不暂停游戏、不改变任何现有 HUD 元素的位置与尺寸。
## 条目带优先级：正在播放时来了更高优先级的条目，当前条目立即让位；其余按优先级先后排队。
## 头像文件缺失时画剪影占位，配音文件缺失时静默，信息照常显示。

signal entry_started(id: String)
signal entry_finished(id: String)

const UI = preload("res://scripts/ui.gd")
const AP = preload("res://scripts/asset_paths.gd")
const Growth = preload("res://scripts/progression/growth.gd")

const WIDTH := 376.0
const HOLD_RATE := 0.085   ## 每条停留时长 = 字幕字数 × 该系数
const HOLD_MIN := 2.6
const HOLD_MAX := 7.2

var _queue: Array = []
var _cur: Dictionary = {}
var _t := 0.0
var _dur := 0.0
var _avatar: AvatarMark
var _name: Label
var _text: Label
var _bar: ProgressBar
var _bars: SignalBars
var _last_rect := Rect2()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(18, 16)
	custom_minimum_size = Vector2(WIDTH, 0)
	add_theme_stylebox_override("panel", UI.tex9("strip9", 8, 10))
	modulate.a = 0.0

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var back := ColorRect.new()
	back.color = Color(0.045, 0.05, 0.06, 0.88)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	move_child(back, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)

	_avatar = AvatarMark.new()
	_avatar.custom_minimum_size = Vector2(70, 70)
	_avatar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_avatar)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_name = UI.label("", 15, Color(1, 0.9, 0.72), true)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_name)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(sp)
	_bars = SignalBars.new()
	_bars.custom_minimum_size = Vector2(30, 14)
	_bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_bars)

	_text = UI.label("", 14, Color(0.93, 0.93, 0.92), true)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.max_lines_visible = 3
	_text.clip_text = true
	_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_text.custom_minimum_size = Vector2(WIDTH - 118, 52)
	_text.add_theme_constant_override("line_spacing", 3)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_text)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 3)
	_bar.max_value = 1.0
	_bar.value = 0.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	_bar.add_theme_stylebox_override("fill", UI.tex9("bar_fill9", 4, 0))
	v.add_child(_bar)


func push(entry: Dictionary) -> void:
	var id := str(entry.get("id", ""))
	if id != "" and (id == str(_cur.get("id", "")) or _queued(id)):
		return
	if not _cur.is_empty() and int(entry.get("priority", 0)) > int(_cur.get("priority", 0)):
		_cut_current()
		_queue.push_front(entry)
		_next()
		return
	var at := _queue.size()
	for i in _queue.size():
		if int(entry.get("priority", 0)) > int(_queue[i].get("priority", 0)):
			at = i
			break
	_queue.insert(at, entry)
	if _cur.is_empty():
		_next()


## 行动结束或小窗被卸下时清空；只停掉自己正在播的那句配音
func clear() -> void:
	_queue.clear()
	if not _cur.is_empty():
		if str(_cur.get("voice", "")) != "" and Audio.voice_id == str(_cur.get("voice", "")):
			Audio.stop_voice()
		_cur = {}
	modulate.a = 0.0
	_bar.value = 0.0


func _queued(id: String) -> bool:
	for q in _queue:
		if str(q.get("id", "")) == id:
			return true
	return false


func _process(delta: float) -> void:
	if _cur.is_empty():
		return
	_t += delta
	_bar.value = _t
	if _t >= _dur:
		_next()
	_last_rect = get_global_rect()


func _show(entry: Dictionary) -> void:
	_cur = entry
	_t = 0.0
	var sp := str(entry.get("speaker", ""))
	_name.text = str(entry.get("name", ""))
	var zh := Growth.subst(str(entry.get("zh", "")))
	_text.text = zh
	_avatar.set_char(sp, str(entry.get("expr", "")))
	_dur = clampf(zh.length() * HOLD_RATE + 1.2, HOLD_MIN, HOLD_MAX)
	var v := str(entry.get("voice", ""))
	if v != "":
		var l := Audio.play_voice(v)
		if l > 0.0:
			_dur = maxf(_dur, l + 0.7)
	Audio.play_ui("comm_open")
	_bar.max_value = _dur
	_bar.value = 0.0
	_bars.reset()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	entry_started.emit(str(entry.get("id", "")))


func _next() -> void:
	if not _cur.is_empty():
		entry_finished.emit(str(_cur.get("id", "")))
	_cur = {}
	if _queue.is_empty():
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.24)
		return
	_show(_queue.pop_front())


func _cut_current() -> void:
	if _cur.is_empty():
		return
	entry_finished.emit(str(_cur.get("id", "")))
	_cur = {}


# ---------- 测试与外部查询 ----------
func busy() -> bool:
	return not _cur.is_empty()


func current_id() -> String:
	return str(_cur.get("id", ""))


func current_text() -> String:
	return _text.text


func current_name() -> String:
	return _name.text


func queued_count() -> int:
	return _queue.size()


## 小窗在屏幕上的矩形（用于校验没有压住其它 HUD 元素）
func window_rect() -> Rect2:
	return get_global_rect()


## 无线电头像：有文件时按正方形裁切，缺文件时画剪影占位
class AvatarMark extends Control:
	var tex: Texture2D
	var accent := Color(0.72, 0.5, 0.09)

	func set_char(cid: String, expr: String) -> void:
		tex = AP.avatar(cid, expr) if cid != "" else null
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w <= 0.0 or h <= 0.0:
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.065, 0.075, 0.95))
		if tex:
			var s := minf(w / float(tex.get_width()), h / float(tex.get_height()))
			var d := Vector2(float(tex.get_width()), float(tex.get_height())) * s
			draw_texture_rect(tex, Rect2((size - d) * 0.5, d), false)
		else:
			var c := Vector2(w * 0.5, h * 0.56)
			var hr := minf(w, h) * 0.16
			draw_circle(Vector2(c.x, h * 0.36), hr, Color(0.16, 0.17, 0.19, 0.98))
			draw_colored_polygon(PackedVector2Array([
				Vector2(c.x - hr * 2.0, h * 0.92),
				Vector2(c.x - hr * 1.3, h * 0.56),
				Vector2(c.x, h * 0.48),
				Vector2(c.x + hr * 1.3, h * 0.56),
				Vector2(c.x + hr * 2.0, h * 0.92),
			]), Color(0.15, 0.16, 0.18, 0.98))
		draw_rect(Rect2(Vector2.ZERO, size), Color(accent.r, accent.g, accent.b, 0.34), false, 1.0)
		var l := 10.0
		var col := Color(accent.r, accent.g, accent.b, 0.7)
		for sx in [0.0, 1.0]:
			for sy in [0.0, 1.0]:
				var o := Vector2(sx * w, sy * h)
				var dx := -1.0 if sx > 0.0 else 1.0
				var dy := -1.0 if sy > 0.0 else 1.0
				draw_line(o + Vector2(0, dy), o + Vector2(dx * l, dy), col, 2.0)
				draw_line(o + Vector2(dx, 0), o + Vector2(dx, dy * l), col, 2.0)


## 信号强度条：条目播放期间起伏，空转时压平
class SignalBars extends Control:
	var t := 0.0
	var active := true
	var accent := Color(0.74, 0.57, 0.3)

	func reset() -> void:
		t = 0.0

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var n := 5
		var w := 3.0
		var gap := (size.x - w * n) / maxf(1.0, float(n - 1))
		for i in n:
			var k := float(i + 1) / n
			var hh := size.y * k
			if active:
				hh *= 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 6.0 + i * 0.9))
			draw_rect(Rect2(i * (w + gap), size.y - hh, w, hh),
				Color(accent.r, accent.g, accent.b, 0.75 if active else 0.25))
