extends RefCounted
## Semi-sci-fi wasteland industrial UI theme ("半科幻废土工业风").
## Palette: Industrial grey-black (#151719 / #222629 / #303438) anodized gunmetal plates, headers,
## frames, and keycaps paired with darker weathered orange-yellow / oxidized amber (#C77A29 / #BF7424)
## over deep soot-carbon chassis wells (#0D0E10 / #151719).
## Uses cached procedural chamfered 9-patch textures (StyleBoxTexture) for genuine metalwork craft.

const FONT := "res://assets/fonts/hd2_ui_sc.ttf"

const ACCENT := Color(0.96, 0.63, 0.20)       ## #F5A133 AC6 Optical Amber
const ACCENT_HI := Color(1.00, 0.74, 0.34)    ## #FFBD57 Bright Lock-On Amber
const ACCENT_DK := Color(0.66, 0.41, 0.12)    ## #A8691F Deep Amber
const STEEL_LT := Color(0.64, 0.76, 0.84)     ## #A3C2D6 Optical Cyan-Steel Hairline
const STEEL_MID := Color(0.36, 0.44, 0.52)    ## #5C7085 Slate Reticle Frame
const TEXT := Color(0.92, 0.94, 0.96)         ## #EBF0F5 Crisp HUD Readout Ink
const MUTED := Color(0.56, 0.63, 0.69)        ## #8FA1B0 Muted Telemetry Grey-Blue
const BG := Color(0.016, 0.020, 0.026, 0.86)  ## Optical Dark Glass
const BG_CARD := Color(0.022, 0.028, 0.036, 0.88)
const BG_INSET := Color(0.012, 0.016, 0.022, 0.82)
const LINE := Color(0.46, 0.54, 0.62, 0.42)
const LINE_HI := Color(0.68, 0.80, 0.88, 0.78)

static var _built: Theme
static var _sb_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}


static func _make_box(bg: Color, b_all: Color, bw := 1, b_left := -1, c_left := Color(0, 0, 0, 0),
		b_top := -1, c_top := Color(0, 0, 0, 0), b_bot := -1, c_bot := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = b_all
	sb.set_border_width_all(bw)
	sb.anti_aliasing = true
	if b_left >= 0:
		sb.border_width_left = b_left
		if c_left.a > 0.0:
			sb.border_color = c_left if bw == 0 else b_all
	if b_top >= 0:
		sb.border_width_top = b_top
		if c_top.a > 0.0 and bw == 0:
			sb.border_color = c_top
	if b_bot >= 0:
		sb.border_width_bottom = b_bot
		if c_bot.a > 0.0 and bw == 0:
			sb.border_color = c_bot
	return sb


static func _hash2(x: int, y: int, seed_v: int) -> float:
	var h: int = (x * 374761393 + y * 668265263 + seed_v * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0


static func _blend_col(dst: Color, src: Color, a: float) -> Color:
	var k := clampf(a, 0.0, 1.0)
	return Color(
		lerpf(dst.r, src.r, k),
		lerpf(dst.g, src.g, k),
		lerpf(dst.b, src.b, k),
		maxf(dst.a, k * src.a)
	)


static func _plate_spec(name: String) -> Dictionary:
	# Base defaults shared by all wasteland industrial grey-black 9-patch textures
	var s := {
		"w": 64, "h": 64, "tm_lr": 8, "tm_tb": 6,
		"c_tl": 4.0, "c_tr": 1.0, "c_bl": 1.0, "c_br": 4.0,
		"fill_top": Color(0.115, 0.124, 0.132, 0.96),
		"fill_bot": Color(0.082, 0.088, 0.095, 0.96),
		"rim_hi": Color(0.36, 0.39, 0.42, 0.96),
		"rim_lo": Color(0.18, 0.20, 0.22, 0.95),
		"rim_w": 1.5,
		"inner_seam": 0.42,
		"left_bar_w": 0.0, "left_bar_col": ACCENT,
		"top_rail_h": 0.0, "top_rail_col": STEEL_LT, "top_rail_notch": Color(0, 0, 0, 0),
		"bot_rail_h": 0.0, "bot_rail_col": STEEL_LT, "bot_rail_accent": Color(0, 0, 0, 0),
		"rivets": false,
		"rivet_col": Color(0.42, 0.45, 0.48, 0.88),
		"corner_ticks": false, "tick_col": STEEL_LT,
		"hatch": false, "recessed": false, "worn": true,
		"grain": 0.018, "seed": 17, "translucent": false,
	}
	match name:
		"panel9":
			s["tm_lr"] = 12; s["tm_tb"] = 10
			s["c_tl"] = 6.0; s["c_tr"] = 2.0; s["c_bl"] = 2.0; s["c_br"] = 6.0
			s["fill_top"] = Color(0.095, 0.102, 0.110, 0.97)
			s["fill_bot"] = Color(0.068, 0.074, 0.080, 0.97)
			s["rim_hi"] = Color(0.34, 0.37, 0.40, 0.98)
			s["rim_lo"] = Color(0.16, 0.18, 0.20, 0.96)
			s["rim_w"] = 1.6
			s["top_rail_h"] = 3.0; s["top_rail_col"] = Color(0.26, 0.29, 0.31, 0.96)
			s["top_rail_notch"] = ACCENT
			s["rivets"] = true
			s["seed"] = 101
		"plate9", "nameplate9":
			s["tm_lr"] = 12; s["tm_tb"] = 6
			s["c_tl"] = 4.0; s["c_tr"] = 3.0; s["c_bl"] = 0.0; s["c_br"] = 3.0
			s["fill_top"] = Color(0.165, 0.178, 0.190, 0.98)
			s["fill_bot"] = Color(0.118, 0.128, 0.138, 0.98)
			s["rim_hi"] = Color(0.40, 0.43, 0.46, 0.98)
			s["rim_lo"] = Color(0.18, 0.20, 0.22, 0.96)
			s["left_bar_w"] = 5.0; s["left_bar_col"] = ACCENT
			s["top_rail_h"] = 1.5; s["top_rail_col"] = Color(0.34, 0.37, 0.40, 0.90)
			s["rivets"] = true
			s["seed"] = 202
		"hdr_dark9", "hdr_light9":
			s["tm_lr"] = 12; s["tm_tb"] = 6
			s["c_tl"] = 4.0; s["c_tr"] = 3.0; s["c_bl"] = 0.0; s["c_br"] = 3.0
			s["fill_top"] = Color(0.185, 0.200, 0.212, 0.99)
			s["fill_bot"] = Color(0.128, 0.138, 0.148, 0.99)
			s["rim_hi"] = Color(0.42, 0.45, 0.48, 0.98)
			s["rim_lo"] = Color(0.10, 0.11, 0.12, 0.99)
			s["left_bar_w"] = 5.0; s["left_bar_col"] = ACCENT
			s["bot_rail_h"] = 2.0; s["bot_rail_col"] = Color(0.24, 0.26, 0.28, 0.98); s["bot_rail_accent"] = ACCENT
			s["rivets"] = true; s["rivet_col"] = Color(0.46, 0.49, 0.52, 0.86)
			s["grain"] = 0.022
			s["seed"] = 205
		"topbar9":
			s["tm_lr"] = 10; s["tm_tb"] = 6
			s["c_tl"] = 0.0; s["c_tr"] = 0.0; s["c_bl"] = 0.0; s["c_br"] = 0.0
			s["fill_top"] = Color(0.108, 0.116, 0.124, 0.98)
			s["fill_bot"] = Color(0.076, 0.082, 0.088, 0.98)
			s["rim_hi"] = Color(0.24, 0.26, 0.28, 0.72)
			s["rim_lo"] = Color(0.36, 0.39, 0.42, 0.96)
			s["bot_rail_h"] = 2.5; s["bot_rail_col"] = Color(0.30, 0.33, 0.35, 0.96)
			s["bot_rail_accent"] = ACCENT
			s["rivets"] = true
			s["seed"] = 303
		"botbar9":
			s["tm_lr"] = 10; s["tm_tb"] = 6
			s["c_tl"] = 0.0; s["c_tr"] = 0.0; s["c_bl"] = 0.0; s["c_br"] = 0.0
			s["fill_top"] = Color(0.102, 0.110, 0.118, 0.98)
			s["fill_bot"] = Color(0.072, 0.078, 0.084, 0.98)
			s["rim_hi"] = Color(0.36, 0.39, 0.42, 0.96)
			s["rim_lo"] = Color(0.18, 0.20, 0.22, 0.85)
			s["top_rail_h"] = 2.5; s["top_rail_col"] = Color(0.30, 0.33, 0.35, 0.96)
			s["top_rail_notch"] = ACCENT
			s["seed"] = 304
		"inset9", "strip9":
			s["w"] = 48; s["h"] = 48; s["tm_lr"] = 6; s["tm_tb"] = 5
			s["c_tl"] = 2.0; s["c_tr"] = 2.0; s["c_bl"] = 2.0; s["c_br"] = 2.0
			s["fill_top"] = Color(0.048, 0.052, 0.058, 0.97)
			s["fill_bot"] = Color(0.066, 0.072, 0.078, 0.97)
			s["rim_hi"] = Color(0.14, 0.15, 0.17, 0.95)
			s["rim_lo"] = Color(0.28, 0.31, 0.33, 0.92)
			s["rim_w"] = 1.2
			s["recessed"] = true
			s["grain"] = 0.012
			s["seed"] = 404
		"card9", "merchant9":
			s["tm_lr"] = 8; s["tm_tb"] = 6
			s["c_tl"] = 4.0; s["c_tr"] = 0.0; s["c_bl"] = 0.0; s["c_br"] = 4.0
			s["fill_top"] = Color(0.132, 0.142, 0.150, 0.97)
			s["fill_bot"] = Color(0.098, 0.106, 0.114, 0.97)
			s["rim_hi"] = Color(0.34, 0.37, 0.40, 0.94)
			s["rim_lo"] = Color(0.18, 0.20, 0.22, 0.92)
			s["left_bar_w"] = 3.0; s["left_bar_col"] = Color(0.38, 0.41, 0.44)
			s["rivets"] = true
			s["seed"] = 505
		"merchant9_h":
			s["tm_lr"] = 8; s["tm_tb"] = 6
			s["c_tl"] = 4.0; s["c_tr"] = 0.0; s["c_bl"] = 0.0; s["c_br"] = 4.0
			s["fill_top"] = Color(0.168, 0.180, 0.190, 0.98)
			s["fill_bot"] = Color(0.124, 0.134, 0.142, 0.98)
			s["rim_hi"] = Color(0.50, 0.53, 0.56, 0.96)
			s["rim_lo"] = Color(0.28, 0.30, 0.32, 0.95)
			s["left_bar_w"] = 3.5; s["left_bar_col"] = ACCENT_HI
			s["rivets"] = true
			s["seed"] = 506
		"card9_on", "merchant9_on":
			s["tm_lr"] = 8; s["tm_tb"] = 6
			s["c_tl"] = 4.0; s["c_tr"] = 0.0; s["c_bl"] = 0.0; s["c_br"] = 4.0
			s["fill_top"] = Color(0.185, 0.138, 0.088, 0.98)
			s["fill_bot"] = Color(0.132, 0.100, 0.066, 0.98)
			s["rim_hi"] = Color(0.84, 0.56, 0.22, 0.98)
			s["rim_lo"] = Color(0.58, 0.38, 0.15, 0.96)
			s["left_bar_w"] = 4.0; s["left_bar_col"] = ACCENT_HI
			s["corner_ticks"] = true; s["tick_col"] = ACCENT_HI
			s["seed"] = 507
		"btn9_n":
			s["tm_lr"] = 8; s["tm_tb"] = 5
			s["c_tl"] = 4.0; s["c_tr"] = 1.0; s["c_bl"] = 1.0; s["c_br"] = 4.0
			s["fill_top"] = Color(0.155, 0.168, 0.178, 0.98)
			s["fill_bot"] = Color(0.114, 0.124, 0.132, 0.98)
			s["rim_hi"] = Color(0.42, 0.45, 0.48, 0.96)
			s["rim_lo"] = Color(0.20, 0.22, 0.24, 0.95)
			s["left_bar_w"] = 3.0; s["left_bar_col"] = Color(0.42, 0.45, 0.48)
			s["seed"] = 601
		"btn9_h":
			s["tm_lr"] = 8; s["tm_tb"] = 5
			s["c_tl"] = 4.0; s["c_tr"] = 1.0; s["c_bl"] = 1.0; s["c_br"] = 4.0
			s["fill_top"] = Color(0.195, 0.208, 0.220, 0.99)
			s["fill_bot"] = Color(0.142, 0.152, 0.162, 0.99)
			s["rim_hi"] = Color(0.56, 0.59, 0.62, 0.98)
			s["rim_lo"] = ACCENT
			s["left_bar_w"] = 3.5; s["left_bar_col"] = ACCENT_HI
			s["seed"] = 602
		"btn9_p":
			s["tm_lr"] = 8; s["tm_tb"] = 5
			s["c_tl"] = 4.0; s["c_tr"] = 1.0; s["c_bl"] = 1.0; s["c_br"] = 4.0
			s["fill_top"] = Color(0.14, 0.115, 0.085, 0.98)
			s["fill_bot"] = Color(0.185, 0.148, 0.102, 0.98)
			s["rim_hi"] = ACCENT
			s["rim_lo"] = STEEL_LT
			s["left_bar_w"] = 3.5; s["left_bar_col"] = ACCENT_HI
			s["recessed"] = true
			s["seed"] = 603
		"btn9_d":
			s["tm_lr"] = 8; s["tm_tb"] = 5
			s["c_tl"] = 3.0; s["c_tr"] = 1.0; s["c_bl"] = 1.0; s["c_br"] = 3.0
			s["fill_top"] = Color(0.085, 0.092, 0.098, 0.85)
			s["fill_bot"] = Color(0.068, 0.074, 0.080, 0.85)
			s["rim_hi"] = Color(0.22, 0.24, 0.26, 0.68)
			s["rim_lo"] = Color(0.14, 0.16, 0.18, 0.68)
			s["worn"] = false
			s["seed"] = 604
		"btn9_main_n":
			s["tm_lr"] = 10; s["tm_tb"] = 6
			s["c_tl"] = 5.0; s["c_tr"] = 2.0; s["c_bl"] = 2.0; s["c_br"] = 5.0
			s["fill_top"] = Color(0.80, 0.50, 0.17, 0.98)
			s["fill_bot"] = Color(0.66, 0.39, 0.11, 0.98)
			s["rim_hi"] = Color(0.92, 0.72, 0.42, 0.98)
			s["rim_lo"] = Color(0.38, 0.22, 0.06, 0.98)
			s["inner_seam"] = 0.55
			s["rivets"] = true; s["rivet_col"] = Color(0.22, 0.14, 0.06, 0.88)
			s["grain"] = 0.025
			s["seed"] = 611
		"btn9_main_h":
			s["tm_lr"] = 10; s["tm_tb"] = 6
			s["c_tl"] = 5.0; s["c_tr"] = 2.0; s["c_bl"] = 2.0; s["c_br"] = 5.0
			s["fill_top"] = Color(0.87, 0.58, 0.23, 1.0)
			s["fill_bot"] = Color(0.73, 0.45, 0.15, 1.0)
			s["rim_hi"] = Color(0.95, 0.78, 0.48, 0.98)
			s["rim_lo"] = Color(0.45, 0.27, 0.08, 0.98)
			s["inner_seam"] = 0.50
			s["rivets"] = true; s["rivet_col"] = Color(0.24, 0.16, 0.07, 0.88)
			s["grain"] = 0.025
			s["seed"] = 612
		"btn9_main_p":
			s["tm_lr"] = 10; s["tm_tb"] = 6
			s["c_tl"] = 5.0; s["c_tr"] = 2.0; s["c_bl"] = 2.0; s["c_br"] = 5.0
			s["fill_top"] = Color(0.58, 0.34, 0.09, 1.0)
			s["fill_bot"] = Color(0.70, 0.43, 0.14, 1.0)
			s["rim_hi"] = Color(0.36, 0.21, 0.06, 0.98)
			s["rim_lo"] = Color(0.88, 0.62, 0.28, 0.96)
			s["recessed"] = true
			s["rivets"] = true; s["rivet_col"] = Color(0.20, 0.12, 0.05, 0.88)
			s["seed"] = 613
		"btn9_main_d":
			s["tm_lr"] = 10; s["tm_tb"] = 6
			s["c_tl"] = 4.0; s["c_tr"] = 2.0; s["c_bl"] = 2.0; s["c_br"] = 4.0
			s["fill_top"] = Color(0.27, 0.22, 0.16, 0.84)
			s["fill_bot"] = Color(0.21, 0.17, 0.13, 0.84)
			s["rim_hi"] = Color(0.46, 0.38, 0.28, 0.72)
			s["rim_lo"] = Color(0.28, 0.23, 0.17, 0.72)
			s["seed"] = 614
		"nav9_n":
			s["tm_lr"] = 8; s["tm_tb"] = 6
			s["c_tl"] = 4.0; s["c_tr"] = 4.0; s["c_bl"] = 0.0; s["c_br"] = 0.0
			s["fill_top"] = Color(0.128, 0.138, 0.146, 0.97)
			s["fill_bot"] = Color(0.094, 0.102, 0.110, 0.97)
			s["rim_hi"] = Color(0.34, 0.37, 0.40, 0.94)
			s["rim_lo"] = Color(0.18, 0.20, 0.22, 0.92)
			s["top_rail_h"] = 2.0; s["top_rail_col"] = Color(0.32, 0.35, 0.38, 0.90)
			s["seed"] = 701
		"nav9_h":
			s["tm_lr"] = 8; s["tm_tb"] = 6
			s["c_tl"] = 4.0; s["c_tr"] = 4.0; s["c_bl"] = 0.0; s["c_br"] = 0.0
			s["fill_top"] = Color(0.165, 0.178, 0.190, 0.98)
			s["fill_bot"] = Color(0.120, 0.130, 0.140, 0.98)
			s["rim_hi"] = Color(0.52, 0.55, 0.58, 0.96)
			s["rim_lo"] = ACCENT
			s["top_rail_h"] = 2.5; s["top_rail_col"] = ACCENT
			s["seed"] = 702
		"nav9_p", "nav9_on":
			s["tm_lr"] = 8; s["tm_tb"] = 6
			s["c_tl"] = 4.0; s["c_tr"] = 4.0; s["c_bl"] = 0.0; s["c_br"] = 0.0
			s["fill_top"] = Color(0.185, 0.140, 0.090, 0.99)
			s["fill_bot"] = Color(0.130, 0.100, 0.066, 0.99)
			s["rim_hi"] = Color(0.88, 0.60, 0.25, 0.98)
			s["rim_lo"] = Color(0.58, 0.38, 0.15, 0.95)
			s["top_rail_h"] = 3.0; s["top_rail_col"] = ACCENT_HI
			s["bot_rail_h"] = 2.0; s["bot_rail_col"] = ACCENT
			s["corner_ticks"] = true; s["tick_col"] = ACCENT_HI
			s["seed"] = 703
		"cell9_empty", "slot9_empty":
			s["w"] = 48; s["h"] = 48; s["tm_lr"] = 5; s["tm_tb"] = 5
			s["c_tl"] = 2.0; s["c_tr"] = 0.0; s["c_bl"] = 0.0; s["c_br"] = 2.0
			s["fill_top"] = Color(0.058, 0.064, 0.070, 0.92)
			s["fill_bot"] = Color(0.048, 0.052, 0.058, 0.92)
			s["rim_hi"] = Color(0.20, 0.22, 0.24, 0.88)
			s["rim_lo"] = Color(0.14, 0.16, 0.18, 0.88)
			s["rim_w"] = 1.0
			s["hatch"] = true; s["corner_ticks"] = true
			s["tick_col"] = Color(0.34, 0.37, 0.40, 0.72)
			s["grain"] = 0.010
			s["seed"] = 800
		"cell9_r0":
			s["w"] = 48; s["h"] = 48; s["tm_lr"] = 5; s["tm_tb"] = 5
			s["c_tl"] = 3.0; s["c_tr"] = 0.0; s["c_bl"] = 0.0; s["c_br"] = 3.0
			s["fill_top"] = Color(0.115, 0.124, 0.132, 0.96)
			s["fill_bot"] = Color(0.088, 0.095, 0.102, 0.96)
			s["rim_hi"] = Color(0.36, 0.39, 0.42, 0.94)
			s["rim_lo"] = Color(0.20, 0.22, 0.24, 0.92)
			s["rim_w"] = 1.2
			s["left_bar_w"] = 3.0; s["left_bar_col"] = Color(0.46, 0.49, 0.52, 0.98)
			s["seed"] = 801
		"cell9_r1":
			s["w"] = 48; s["h"] = 48; s["tm_lr"] = 5; s["tm_tb"] = 5
			s["c_tl"] = 3.0; s["c_tr"] = 0.0; s["c_bl"] = 0.0; s["c_br"] = 3.0
			s["fill_top"] = Color(0.125, 0.165, 0.130, 0.95)
			s["fill_bot"] = Color(0.098, 0.132, 0.102, 0.95)
			s["rim_hi"] = Color(0.46, 0.64, 0.44, 0.94)
			s["rim_lo"] = Color(0.26, 0.40, 0.25, 0.92)
			s["rim_w"] = 1.2
			s["left_bar_w"] = 3.0; s["left_bar_col"] = Color(0.52, 0.73, 0.48, 0.98)
			s["seed"] = 802
		"cell9_r2":
			s["w"] = 48; s["h"] = 48; s["tm_lr"] = 5; s["tm_tb"] = 5
			s["c_tl"] = 3.0; s["c_tr"] = 0.0; s["c_bl"] = 0.0; s["c_br"] = 3.0
			s["fill_top"] = Color(0.115, 0.155, 0.195, 0.95)
			s["fill_bot"] = Color(0.090, 0.125, 0.158, 0.95)
			s["rim_hi"] = Color(0.42, 0.60, 0.76, 0.94)
			s["rim_lo"] = Color(0.24, 0.36, 0.48, 0.92)
			s["rim_w"] = 1.2
			s["left_bar_w"] = 3.0; s["left_bar_col"] = Color(0.46, 0.66, 0.82, 0.98)
			s["seed"] = 803
		"cell9_r3":
			s["w"] = 48; s["h"] = 48; s["tm_lr"] = 5; s["tm_tb"] = 5
			s["c_tl"] = 3.0; s["c_tr"] = 0.0; s["c_bl"] = 0.0; s["c_br"] = 3.0
			s["fill_top"] = Color(0.20, 0.145, 0.085, 0.96)
			s["fill_bot"] = Color(0.155, 0.112, 0.065, 0.96)
			s["rim_hi"] = Color(0.84, 0.56, 0.22, 0.96)
			s["rim_lo"] = Color(0.54, 0.35, 0.12, 0.94)
			s["rim_w"] = 1.3
			s["left_bar_w"] = 3.0; s["left_bar_col"] = Color(0.88, 0.62, 0.24, 0.98)
			s["seed"] = 804
		"cell9_hover":
			s["w"] = 48; s["h"] = 48; s["tm_lr"] = 5; s["tm_tb"] = 5
			s["c_tl"] = 3.0; s["c_tr"] = 0.0; s["c_bl"] = 0.0; s["c_br"] = 3.0
			s["fill_top"] = Color(0.56, 0.60, 0.63, 0.08)
			s["fill_bot"] = Color(0.56, 0.60, 0.63, 0.05)
			s["rim_hi"] = Color(0.56, 0.60, 0.63, 0.95)
			s["rim_lo"] = Color(0.38, 0.41, 0.44, 0.90)
			s["rim_w"] = 1.5; s["inner_seam"] = 0.0; s["worn"] = false; s["grain"] = 0.0
			s["translucent"] = true
			s["seed"] = 805
		"cell9_sel":
			s["w"] = 48; s["h"] = 48; s["tm_lr"] = 5; s["tm_tb"] = 5
			s["c_tl"] = 3.0; s["c_tr"] = 0.0; s["c_bl"] = 0.0; s["c_br"] = 3.0
			s["fill_top"] = Color(0.82, 0.52, 0.18, 0.13)
			s["fill_bot"] = Color(0.82, 0.52, 0.18, 0.09)
			s["rim_hi"] = ACCENT_HI
			s["rim_lo"] = ACCENT
			s["rim_w"] = 2.0; s["inner_seam"] = 0.0; s["worn"] = false; s["grain"] = 0.0
			s["corner_ticks"] = true; s["tick_col"] = ACCENT_HI
			s["translucent"] = true
			s["seed"] = 806
		"cell9_bad":
			s["w"] = 48; s["h"] = 48; s["tm_lr"] = 5; s["tm_tb"] = 5
			s["c_tl"] = 3.0; s["c_tr"] = 0.0; s["c_bl"] = 0.0; s["c_br"] = 3.0
			s["fill_top"] = Color(0.82, 0.24, 0.18, 0.20)
			s["fill_bot"] = Color(0.75, 0.20, 0.15, 0.16)
			s["rim_hi"] = Color(0.90, 0.36, 0.28, 0.95)
			s["rim_lo"] = Color(0.68, 0.22, 0.18, 0.95)
			s["rim_w"] = 1.6; s["inner_seam"] = 0.0; s["worn"] = false; s["grain"] = 0.0
			s["translucent"] = true
			s["seed"] = 807
		"tip9":
			s["w"] = 48; s["h"] = 48; s["tm_lr"] = 6; s["tm_tb"] = 6
			s["c_tl"] = 4.0; s["c_tr"] = 1.0; s["c_bl"] = 1.0; s["c_br"] = 4.0
			s["fill_top"] = Color(0.085, 0.092, 0.098, 0.98)
			s["fill_bot"] = Color(0.062, 0.068, 0.074, 0.98)
			s["rim_hi"] = STEEL_LT
			s["rim_lo"] = STEEL_MID
			s["top_rail_h"] = 2.0; s["top_rail_col"] = ACCENT
			s["seed"] = 901
		"key9":
			s["w"] = 48; s["h"] = 48; s["tm_lr"] = 5; s["tm_tb"] = 5
			s["c_tl"] = 2.5; s["c_tr"] = 2.5; s["c_bl"] = 2.0; s["c_br"] = 2.0
			s["fill_top"] = Color(0.21, 0.23, 0.25, 0.99)
			s["fill_bot"] = Color(0.14, 0.155, 0.17, 0.99)
			s["rim_hi"] = Color(0.46, 0.49, 0.52, 0.98)
			s["rim_lo"] = Color(0.09, 0.10, 0.11, 0.99)
			s["rim_w"] = 1.2; s["inner_seam"] = 0.18
			s["bot_rail_h"] = 3.0; s["bot_rail_col"] = Color(0.10, 0.11, 0.12, 0.98)
			s["bot_rail_accent"] = ACCENT
			s["grain"] = 0.015
			s["seed"] = 902
		"prompt9":
			s["tm_lr"] = 8; s["tm_tb"] = 6
			s["c_tl"] = 4.0; s["c_tr"] = 0.0; s["c_bl"] = 0.0; s["c_br"] = 4.0
			s["fill_top"] = Color(0.105, 0.112, 0.120, 0.97)
			s["fill_bot"] = Color(0.078, 0.084, 0.090, 0.97)
			s["rim_hi"] = STEEL_LT
			s["rim_lo"] = STEEL_MID
			s["left_bar_w"] = 4.0; s["left_bar_col"] = ACCENT
			s["rivets"] = true
			s["seed"] = 903
		"bar_fill9":
			s["w"] = 32; s["h"] = 32; s["tm_lr"] = 4; s["tm_tb"] = 4
			s["c_tl"] = 0.0; s["c_tr"] = 0.0; s["c_bl"] = 0.0; s["c_br"] = 0.0
			s["fill_top"] = ACCENT_HI
			s["fill_bot"] = ACCENT_DK
			s["rim_hi"] = Color(0.94, 0.78, 0.52, 0.95)
			s["rim_lo"] = Color(0.42, 0.24, 0.07, 0.95)
			s["rim_w"] = 1.0; s["inner_seam"] = 0.0
			s["seed"] = 904
		_:
			s["seed"] = 999
	return s


static func _make_plate_tex(name: String) -> ImageTexture:
	var ck := "plate_" + name
	if _tex_cache.has(ck):
		var cached: ImageTexture = _tex_cache[ck]
		return cached
	var spec := _plate_spec(name)
	var w: int = int(spec["w"])
	var h: int = int(spec["h"])
	var tm_lr: int = int(spec["tm_lr"])
	var tm_tb: int = int(spec["tm_tb"])
	var c_tl: float = minf(float(spec["c_tl"]), 6.0)
	var c_tr: float = minf(float(spec["c_tr"]), 4.0)
	var c_bl: float = minf(float(spec["c_bl"]), 4.0)
	var c_br: float = minf(float(spec["c_br"]), 6.0)
	var lbw: float = float(spec["left_bar_w"])
	var tr_notch: Color = spec["top_rail_notch"]

	var ft := Color(0.016, 0.020, 0.026, 0.84)
	var fb := Color(0.014, 0.018, 0.024, 0.90)
	var rim := Color(0.46, 0.54, 0.62, 0.46)
	var bracket_col := Color(0.70, 0.80, 0.88, 0.82)
	var draw_brackets := true
	var top_rar := Color(0, 0, 0, 0)
	var amber := Color(0.96, 0.63, 0.20, 1.0)
	var rar_cols := [
		Color(0.58, 0.64, 0.70),
		Color(0.44, 0.82, 0.56),
		Color(0.44, 0.74, 0.96),
		Color(0.96, 0.66, 0.22),
	]

	if name == "btn9_main_n":
		ft = Color(0.96, 0.63, 0.20, 0.98)
		fb = Color(0.88, 0.55, 0.16, 0.98)
		rim = Color(1.0, 0.82, 0.48, 0.95)
		c_tl = 5.0; c_br = 5.0; c_tr = 0.0; c_bl = 0.0
		draw_brackets = false
	elif name == "btn9_main_h":
		ft = Color(1.0, 0.72, 0.30, 1.0)
		fb = Color(0.94, 0.62, 0.20, 1.0)
		rim = Color(1.0, 0.90, 0.62, 1.0)
		c_tl = 5.0; c_br = 5.0; c_tr = 0.0; c_bl = 0.0
		draw_brackets = false
	elif name == "btn9_main_p":
		ft = Color(0.80, 0.50, 0.14, 1.0)
		fb = Color(0.72, 0.44, 0.12, 1.0)
		rim = amber
		c_tl = 5.0; c_br = 5.0; c_tr = 0.0; c_bl = 0.0
		draw_brackets = false
	elif name == "btn9_main_d":
		ft = Color(0.20, 0.22, 0.25, 0.80)
		fb = Color(0.16, 0.18, 0.20, 0.80)
		rim = Color(0.38, 0.42, 0.46, 0.55)
		c_tl = 5.0; c_br = 5.0; c_tr = 0.0; c_bl = 0.0
		draw_brackets = false
	elif name == "bar_fill9":
		ft = amber
		fb = Color(0.86, 0.54, 0.16, 1.0)
		rim = amber
		draw_brackets = false
	elif name == "key9":
		ft = Color(0.10, 0.13, 0.16, 0.95)
		fb = Color(0.07, 0.09, 0.12, 0.95)
		rim = Color(0.64, 0.74, 0.82, 0.72)
		draw_brackets = false
	elif name == "btn9_d":
		ft = Color(0.025, 0.030, 0.038, 0.60)
		fb = Color(0.020, 0.025, 0.032, 0.60)
		rim = Color(0.30, 0.34, 0.38, 0.35)
		draw_brackets = false
	elif name == "cell9_sel":
		ft = Color(0.96, 0.63, 0.20, 0.16)
		fb = Color(0.96, 0.63, 0.20, 0.08)
		rim = Color(0.98, 0.68, 0.24, 0.96)
		c_tl = 3.0; c_br = 3.0; c_tr = 0.0; c_bl = 0.0
		draw_brackets = false
	elif name == "cell9_hover":
		ft = Color(0.48, 0.85, 0.95, 0.12)
		fb = Color(0.48, 0.85, 0.95, 0.06)
		rim = Color(0.64, 0.82, 0.92, 0.85)
		c_tl = 3.0; c_br = 3.0; c_tr = 0.0; c_bl = 0.0
		draw_brackets = false
	elif name.ends_with("_on") or name.ends_with("_p"):
		ft = Color(0.16, 0.10, 0.03, 0.84)
		fb = Color(0.11, 0.07, 0.02, 0.86)
		rim = Color(0.96, 0.63, 0.20, 0.92)
		bracket_col = amber
		draw_brackets = true
	elif name.ends_with("_h"):
		ft = Color(0.048, 0.060, 0.076, 0.86)
		fb = Color(0.036, 0.046, 0.060, 0.88)
		rim = Color(0.64, 0.76, 0.84, 0.85)
		bracket_col = Color(0.80, 0.90, 0.96, 0.90)
	elif name in ["inset9", "strip9", "cell9_empty", "slot9_empty", "prompt9"]:
		ft = Color(0.012, 0.016, 0.022, 0.78)
		fb = Color(0.010, 0.014, 0.019, 0.82)
		rim = Color(0.42, 0.50, 0.58, 0.28)
		c_tl = 0.0; c_tr = 0.0; c_bl = 0.0; c_br = 0.0
		draw_brackets = false
	elif name == "cell9_bad":
		ft = Color(0.82, 0.22, 0.18, 0.16)
		fb = Color(0.75, 0.18, 0.14, 0.10)
		rim = Color(0.96, 0.36, 0.30, 0.92)
		bracket_col = Color(0.96, 0.36, 0.30, 0.95)
	elif name.begins_with("cell9_r"):
		var ridx := clampi(int(name.substr(7)), 0, 3)
		var rc: Color = rar_cols[ridx]
		var ml := Engine.get_main_loop()
		if ml is SceneTree:
			var gd := (ml as SceneTree).root.get_node_or_null("GameData")
			if gd != null and "RARITY_COLORS" in gd:
				rc = gd.RARITY_COLORS[ridx]
		ft = Color(rc.r * 0.14 + 0.016, rc.g * 0.14 + 0.020, rc.b * 0.14 + 0.026, 0.88)
		fb = Color(rc.r * 0.08 + 0.012, rc.g * 0.08 + 0.016, rc.b * 0.08 + 0.022, 0.92)
		rim = Color(rc.r * 0.65 + 0.20, rc.g * 0.65 + 0.22, rc.b * 0.65 + 0.25, 0.72)
		top_rar = Color(rc.r, rc.g, rc.b, 0.95)
		c_tl = 3.0; c_br = 3.0; c_tr = 0.0; c_bl = 0.0
		draw_brackets = false

	var buf := PackedByteArray()
	buf.resize(w * h * 4)
	var inv_sqrt2 := 0.70710678
	var wf := float(w)
	var hf := float(h)
	var arm := float(maxi(2, mini(tm_lr, tm_tb) - 1))

	for y in h:
		var py := float(y) + 0.5
		var vy := py / hf
		for x in w:
			var px := float(x) + 0.5
			var sd := maxf(maxf(-px, px - wf), maxf(-py, py - hf))
			if c_tl > 0.0:
				sd = maxf(sd, (c_tl - px - py) * inv_sqrt2)
			if c_tr > 0.0:
				sd = maxf(sd, (c_tr - (wf - px) - py) * inv_sqrt2)
			if c_bl > 0.0:
				sd = maxf(sd, (c_bl - px - (hf - py)) * inv_sqrt2)
			if c_br > 0.0:
				sd = maxf(sd, (c_br - (wf - px) - (hf - py)) * inv_sqrt2)

			var mask := clampf(0.5 - sd, 0.0, 1.0)
			var o := (y * w + x) * 4
			if mask <= 0.002:
				buf[o] = 0; buf[o + 1] = 0; buf[o + 2] = 0; buf[o + 3] = 0
				continue

			var depth := -sd
			var col := ft.lerp(fb, vy)

			if top_rar.a > 0.01 and py >= 1.0 and py <= 2.6 and depth >= 0.8:
				col = _blend_col(col, top_rar, top_rar.a)

			if lbw > 0.0 and px >= 1.2 and px < 3.2 and py >= 4.0 and py <= hf - 4.0 and depth >= 0.8:
				col = _blend_col(col, amber, 0.92)

			if tr_notch.a > 0.01 and py >= 1.0 and py <= 2.4 and px >= float(tm_lr) * 0.6 and px < float(tm_lr) * 1.45:
				col = _blend_col(col, amber, 0.92)

			if depth < 1.15:
				var rcov := clampf(1.15 - depth + 0.35, 0.0, 1.0)
				col = _blend_col(col, rim, rcov * rim.a)

			if draw_brackets:
				var in_l := px >= 0.5 and px <= arm
				var in_r := px >= wf - arm and px <= wf - 0.5
				var in_t := py >= 0.5 and py <= arm
				var in_b := py >= hf - arm and py <= hf - 0.5
				if (in_l or in_r) and (in_t or in_b) and depth < 1.35:
					col = _blend_col(col, bracket_col, bracket_col.a)

			buf[o] = clampi(int(roundf(col.r * 255.0)), 0, 255)
			buf[o + 1] = clampi(int(roundf(col.g * 255.0)), 0, 255)
			buf[o + 2] = clampi(int(roundf(col.b * 255.0)), 0, 255)
			buf[o + 3] = clampi(int(roundf(mask * col.a * 255.0)), 0, 255)

	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, buf)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[ck] = tex
	return tex


## Wasteland industrial StyleBoxTexture 9-patch builder.
## Preserves exact content_margin_* (plr, ptb) so layouts never shift or overflow.
static func px9(name: String, mlr: int, mtb := -1, plr := -1, ptb := -1, tint := Color(1, 1, 1, 1)) -> StyleBox:
	if mtb < 0:
		mtb = mlr
	if plr < 0:
		plr = mlr
	if ptb < 0:
		ptb = plr
	var key := "%s/%d/%d/%.2f,%.2f,%.2f,%.2f" % [name, plr, ptb, tint.r, tint.g, tint.b, tint.a]
	if _sb_cache.has(key):
		var cached: StyleBox = _sb_cache[key]
		return cached

	var spec := _plate_spec(name)
	var tex := _make_plate_tex(name)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = float(int(spec["tm_lr"]))
	sb.texture_margin_right = float(int(spec["tm_lr"]))
	sb.texture_margin_top = float(int(spec["tm_tb"]))
	sb.texture_margin_bottom = float(int(spec["tm_tb"]))
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.modulate_color = tint
	sb.content_margin_left = float(plr)
	sb.content_margin_right = float(plr)
	sb.content_margin_top = float(ptb)
	sb.content_margin_bottom = float(ptb)
	_sb_cache[key] = sb
	return sb


static func flat(bg: Color, border: Color, bw := 1, pad := 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.anti_aliasing = true
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb


static func build() -> Theme:
	if _built:
		return _built
	var t := Theme.new()
	t.default_font = PixelUI.pixel_font()
	t.default_font_size = 13

	var panel_s := px9("panel9", 14, 14, 12, 10)
	var pop_s := px9("tip9", 8, 8, 10, 8)
	t.set_stylebox("panel", "Panel", panel_s)
	t.set_stylebox("panel", "PanelContainer", panel_s)
	t.set_stylebox("panel", "PopupPanel", pop_s)
	t.set_stylebox("panel", "TabContainer", panel_s)

	for c in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", c, px9("btn9_n", 8, 8, 12, 6))
		t.set_stylebox("hover", c, px9("btn9_h", 8, 8, 12, 6))
		t.set_stylebox("pressed", c, px9("btn9_p", 8, 8, 12, 6))
		t.set_stylebox("hover_pressed", c, px9("btn9_p", 8, 8, 12, 6))
		t.set_stylebox("disabled", c, px9("btn9_d", 8, 8, 12, 6))
		t.set_stylebox("focus", c, StyleBoxEmpty.new())
		t.set_color("font_color", c, TEXT)
		t.set_color("font_hover_color", c, ACCENT_HI)
		t.set_color("font_pressed_color", c, ACCENT)
		t.set_color("font_hover_pressed_color", c, ACCENT_HI)
		t.set_color("font_disabled_color", c, Color(0.42, 0.44, 0.44))
	t.set_icon("arrow", "OptionButton", pix_arrow())

	for c in ["CheckBox", "CheckButton"]:
		t.set_stylebox("normal", c, StyleBoxEmpty.new())
		t.set_stylebox("hover", c, StyleBoxEmpty.new())
		t.set_stylebox("pressed", c, StyleBoxEmpty.new())
		t.set_stylebox("focus", c, StyleBoxEmpty.new())
		t.set_color("font_color", c, TEXT)
		t.set_color("font_hover_color", c, ACCENT_HI)
		t.set_color("font_pressed_color", c, ACCENT)
	t.set_icon("checked", "CheckBox", pix_check(true))
	t.set_icon("unchecked", "CheckBox", pix_check(false))

	for c in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", c, px9("inset9", 6, 6, 8, 6))
		t.set_stylebox("focus", c, px9("card9_on", 6, 6, 8, 6))
		t.set_stylebox("read_only", c, px9("inset9", 6, 6, 8, 6))
		t.set_color("font_color", c, TEXT)
		t.set_color("font_placeholder_color", c, MUTED)

	t.set_stylebox("slider", "HSlider", flat(Color(0.11, 0.12, 0.125), STEEL_MID, 1, 3))
	t.set_stylebox("grabber_area", "HSlider", flat(ACCENT, Color(0, 0, 0, 0), 0, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", flat(ACCENT_HI, Color(0, 0, 0, 0), 0, 3))
	var g := pix_grabber()
	t.set_icon("grabber", "HSlider", g)
	t.set_icon("grabber_highlight", "HSlider", g)
	t.set_stylebox("slider", "VSlider", flat(Color(0.11, 0.12, 0.125), STEEL_MID, 1, 3))
	t.set_stylebox("grabber_area", "VSlider", flat(ACCENT, Color(0, 0, 0, 0), 0, 3))
	t.set_icon("grabber", "VSlider", g)
	t.set_icon("grabber_highlight", "VSlider", g)

	for c in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", c, flat(Color(0.055, 0.060, 0.064, 0.92), LINE, 1, 1))
		t.set_stylebox("grabber", c, flat(Color(0.24, 0.26, 0.28), LINE_HI, 1, 1))
		t.set_stylebox("grabber_highlight", c, flat(ACCENT, ACCENT_HI, 1, 1))
		t.set_stylebox("grabber_pressed", c, flat(ACCENT_HI, STEEL_LT, 1, 1))

	t.set_stylebox("panel", "ItemList", px9("inset9", 6, 6, 4, 4))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("selected", "ItemList", px9("card9_on", 6, 6, 4, 4))
	t.set_stylebox("selected_focus", "ItemList", px9("card9_on", 6, 6, 4, 4))
	t.set_stylebox("hovered", "ItemList", flat(Color(0.85, 0.88, 0.88, 0.06), LINE_HI, 1, 4))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", ACCENT_HI)
	t.set_constant("v_separation", "ItemList", 4)

	t.set_stylebox("panel", "PopupMenu", px9("tip9", 8, 8, 8, 6))
	t.set_stylebox("hover", "PopupMenu", px9("card9_on", 6, 6, 6, 4))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", ACCENT_HI)
	t.set_constant("item_end_padding", "PopupMenu", 10)
	t.set_constant("v_separation", "PopupMenu", 6)

	t.set_stylebox("panel", "TooltipPanel", px9("tip9", 8, 8, 10, 6))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_stylebox("background", "ProgressBar", flat(BG_INSET, STEEL_MID, 1, 1))
	t.set_stylebox("fill", "ProgressBar", px9("bar_fill9", 4, 4, 0, 0))
	t.set_color("font_color", "Label", TEXT)

	_built = t
	return t


static func pix_arrow() -> Texture2D:
	if _tex_cache.has("arrow"):
		var cached: Texture2D = _tex_cache["arrow"]
		return cached
	var sz := 20
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in sz:
		for x in sz:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var d1 := absf((p.y - 7.5) - (p.x - 5.0)) * 0.7071
			var d2 := absf((p.y - 7.5) - (15.0 - p.x)) * 0.7071
			var in_x := p.x >= 4.5 and p.x <= 15.5
			var in_y := p.y >= 7.0 and p.y <= 13.5
			var sd := minf(d1 if p.x <= 10.0 else 99.0, d2 if p.x >= 10.0 else 99.0)
			if not (in_x and in_y):
				sd = 99.0
			var a := clampf(1.5 - sd, 0.0, 1.0)
			if a > 0.01:
				img.set_pixel(x, y, Color(STEEL_LT.r, STEEL_LT.g, STEEL_LT.b, a))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache["arrow"] = t
	return t


static func pix_check(on: bool) -> Texture2D:
	var k := "chk_1" if on else "chk_0"
	if _tex_cache.has(k):
		var cached: Texture2D = _tex_cache[k]
		return cached
	var sz := 20
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(2, sz - 2):
		for x in range(2, sz - 2):
			var border := x < 4 or x >= sz - 4 or y < 4 or y >= sz - 4
			if border:
				img.set_pixel(x, y, ACCENT_HI if on else LINE_HI)
			else:
				img.set_pixel(x, y, Color(0.24, 0.17, 0.09) if on else BG_INSET)
	if on:
		for y in range(6, 14):
			for x in range(6, 14):
				img.set_pixel(x, y, ACCENT_HI if (x >= 7 and x <= 12 and y >= 7 and y <= 12) else ACCENT)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache[k] = t
	return t


static func pix_grabber() -> Texture2D:
	if _tex_cache.has("grabber"):
		var cached: Texture2D = _tex_cache["grabber"]
		return cached
	var w := 14
	var h := 20
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var border := x == 1 or x == w - 2 or y == 1 or y == h - 2
			var mid_slit := (x == 6 or x == 7) and y >= 5 and y <= h - 6
			var c := Color(0.22, 0.24, 0.25) if border else (ACCENT if mid_slit else STEEL_LT)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache["grabber"] = t
	return t
