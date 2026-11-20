extends CanvasLayer
## 全局右上角 FPS 悬浮显示层（受 GameData.show_fps 控制，不拦截鼠标，暂停期间持续刷新）。

const UI = preload("res://scripts/ui.gd")

const REFRESH_INTERVAL := 0.25

var _root: Control
var _panel: PanelContainer
var _accent: ColorRect
var _val_lbl: Label
var _accum := 0.0
var _last_fps := -1


func _init() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_build_ui()
	if not GameData.show_fps_changed.is_connected(_apply_visible):
		GameData.show_fps_changed.connect(_apply_visible)
	_apply_visible(GameData.show_fps)


func _exit_tree() -> void:
	if GameData.show_fps_changed.is_connected(_apply_visible):
		GameData.show_fps_changed.disconnect(_apply_visible)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UI.theme()
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_top = 6
	_panel.offset_right = -12
	_panel.offset_bottom = 30
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.custom_minimum_size = Vector2(76, 24)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.052, 0.058, 0.066, 0.80)
	sb.border_color = Color(0.28, 0.31, 0.34, 0.88)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 7
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	_panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(_panel)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 5)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(hb)

	_accent = ColorRect.new()
	_accent.color = UI.GOOD
	_accent.custom_minimum_size = Vector2(3, 12)
	_accent.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(_accent)

	var tag := UI.label("FPS", 11, UI.MUTED, true)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(tag)

	_val_lbl = UI.label("--", 13, UI.GOOD, true)
	_val_lbl.custom_minimum_size = Vector2(30, 0)
	_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_val_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_val_lbl)


func _apply_visible(on: bool) -> void:
	visible = on
	set_process(on)
	if on:
		_accum = REFRESH_INTERVAL
		_last_fps = -1
		_refresh(0.016)


func _process(delta: float) -> void:
	_accum += delta
	if _accum < REFRESH_INTERVAL:
		return
	_accum = 0.0
	_refresh(delta)


func _refresh(delta: float) -> void:
	var fps := int(round(Engine.get_frames_per_second()))
	if fps <= 0 and delta > 0.0:
		fps = clampi(int(round(1.0 / delta)), 1, 999)
	if fps == _last_fps:
		return
	_last_fps = fps
	var col := UI.GOOD if fps >= 50 else (UI.ACCENT_HI if fps >= 30 else UI.BAD)
	if _val_lbl != null:
		_val_lbl.text = str(fps)
		_val_lbl.add_theme_color_override("font_color", col)
	if _accent != null:
		_accent.color = col
