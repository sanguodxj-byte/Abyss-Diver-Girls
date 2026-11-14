extends Node
## 全局平滑无衬线战术 UI 字体管理（自动加载）
## - 使用平滑抗锯齿无衬线字体（hd2_ui_sc.ttf + hd2_symbols.ttf 符号回退），不再强制量化到 12px 像素点阵

const PixelTheme = preload("res://scripts/pixel_theme.gd")
const FONT_PATH := "res://assets/fonts/hd2_ui_sc.ttf"
const SYM_PATH := "res://assets/fonts/hd2_symbols.ttf"
const BASE := 13
const FONT_KEYS := ["font_size", "normal_font_size", "bold_font_size", "italics_font_size", "mono_font_size", "title_font_size"]

static var font: FontFile


static func snap(s: int) -> int:
	return clampi(s, 11, 64)


static func pixel_font() -> FontFile:
	if font == null:
		font = load(FONT_PATH) as FontFile
		if font != null:
			font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
			font.hinting = TextServer.HINTING_LIGHT
			font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
			font.generate_mipmaps = true
			font.keep_rounding_remainders = true
			var fb: Array[Font] = []
			if ResourceLoader.exists(SYM_PATH):
				var sf: FontFile = load(SYM_PATH) as FontFile
				if sf != null:
					sf.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
					fb.append(sf)
			if ResourceLoader.exists("res://NotoSansSC-Subset.ttf"):
				var nf: Font = load("res://NotoSansSC-Subset.ttf") as Font
				if nf != null:
					fb.append(nf)
			if ResourceLoader.exists("res://assets/fonts/fusion-pixel-12px-zh_hans.ttf"):
				var pf: Font = load("res://assets/fonts/fusion-pixel-12px-zh_hans.ttf") as Font
				if pf != null:
					fb.append(pf)
			font.fallbacks = fb
	return font


func _enter_tree() -> void:
	var f: FontFile = pixel_font()
	if f != null:
		ThemeDB.fallback_font = f
	ThemeDB.fallback_font_size = BASE
	get_tree().root.theme = PixelTheme.build()
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(_n: Node) -> void:
	pass
