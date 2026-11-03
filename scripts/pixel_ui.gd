extends Node
## 像素风 UI 统一处理（自动加载）
## - 全局像素字体 fusion-pixel 12px：字号只允许 12 的整数倍，否则字形会被非整数缩放，笔画粗细不均
## - 任何控件上的字号覆盖在入树时统一吸附到 12 / 24 / 36
## - 关闭全局字体抗锯齿，保证硬边

const FONT_PATH := "res://assets/fonts/fusion-pixel-12px-zh_hans.ttf"
const BASE := 12
const FONT_KEYS := ["font_size", "normal_font_size", "bold_font_size", "italics_font_size", "mono_font_size", "title_font_size"]

static var font: FontFile


static func snap(s: int) -> int:
	## 11~19 → 12，20~31 → 24，32~43 → 36 …
	if s < 20:
		return BASE
	return int(floor((s + 4) / float(BASE))) * BASE


static func pixel_font() -> FontFile:
	if font == null:
		font = load(FONT_PATH)
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font.hinting = TextServer.HINTING_NONE
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		font.generate_mipmaps = false
		font.keep_rounding_remainders = false
		# 像素字体缺的极少数符号（∞ ⚠ 鹭）回退到原 Noto 子集
		font.fallbacks = [load("res://NotoSansSC-Subset.ttf")]
	return font


func _enter_tree() -> void:
	var f := pixel_font()
	ThemeDB.fallback_font = f
	ThemeDB.fallback_font_size = BASE
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is Control:
		_snap_control(n)
		# 不少界面在 add_child 之后才设置字号，下一帧再吸附一次
		# 传实例 id 而不是节点本身：同一帧里先建后删的控件（界面重建）在延迟调用时已释放
		_snap_deferred.call_deferred(n.get_instance_id())


func _snap_deferred(id: int) -> void:
	var c := instance_from_id(id) as Control
	if c != null:
		_snap_control(c)


func _snap_control(c: Control) -> void:
	if not is_instance_valid(c):
		return
	for k in FONT_KEYS:
		if c.has_theme_font_size_override(k):
			var s := c.get_theme_font_size(k)
			var t := snap(s)
			if t != s:
				c.add_theme_font_size_override(k, t)
	# 描边宽度保持整数像素
	if c.has_theme_constant_override("outline_size"):
		var o := c.get_theme_constant("outline_size")
		if o > 0:
			c.add_theme_constant_override("outline_size", clampi(int(round(o / 2.0)) * 2, 2, 8))
