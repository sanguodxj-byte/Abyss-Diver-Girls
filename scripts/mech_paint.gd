extends RefCounted
## 机甲军工涂装与迷彩系统（B.o.T 低饱和消光防化烤漆规范）
## - 仅重绘电介质烤漆层（armor / armor_sub / armor_dark / armor_oxide / accent）
## - 严格保留裸露枪钢、镀铬液压杆、橡胶履带、黄黑警示条、光学玻璃、贴花与战术灯原始物理质感
## - 支持一键恢复「原厂标准」（零重建还原各模块出厂配色）与 9 套实战军工迷彩预设 + 自由调色

const WEAR_VALUES := [0.18, 0.54, 0.86]
const RUST_VALUES := [0.03, 0.14, 0.30]
const GRIME_VALUES := [0.24, 0.42, 0.58]

const PRESETS := [
	{
		"id": "default",
		"zh": "原厂标准",
		"en": "Factory",
		"pattern": 0,
		"primary": "#585e58",
		"secondary": "#3d423e",
		"tertiary": "#252926",
		"accent": "#d19929",
		"wear": 1,
	},
	{
		"id": "desert",
		"zh": "荒漠风暴",
		"en": "Desert CARC",
		"pattern": 1,
		"primary": "#8c7a5b",
		"secondary": "#5c4936",
		"tertiary": "#342a21",
		"accent": "#d68628",
		"wear": 1,
	},
	{
		"id": "nato",
		"zh": "北约丛林",
		"en": "Woodland",
		"pattern": 1,
		"primary": "#4d5941",
		"secondary": "#4e3c2e",
		"tertiary": "#232624",
		"accent": "#c9952c",
		"wear": 1,
	},
	{
		"id": "arctic",
		"zh": "极地雪鸮",
		"en": "Arctic M90",
		"pattern": 2,
		"primary": "#96a0a8",
		"secondary": "#586978",
		"tertiary": "#303a44",
		"accent": "#389ec4",
		"wear": 0,
	},
	{
		"id": "urban",
		"zh": "灰港折线",
		"en": "Urban M90",
		"pattern": 2,
		"primary": "#58636e",
		"secondary": "#38434f",
		"tertiary": "#20252c",
		"accent": "#de7e28",
		"wear": 1,
	},
	{
		"id": "tiger",
		"zh": "暗林虎纹",
		"en": "Tiger Stripe",
		"pattern": 3,
		"primary": "#525f44",
		"secondary": "#273226",
		"tertiary": "#3d3125",
		"accent": "#cca038",
		"wear": 1,
	},
	{
		"id": "guards",
		"zh": "铁幕近卫",
		"en": "Guards Olive",
		"pattern": 0,
		"primary": "#414f38",
		"secondary": "#2b3526",
		"tertiary": "#1e241c",
		"accent": "#ba342a",
		"wear": 1,
	},
	{
		"id": "spec_ops",
		"zh": "夜袭暗鸦",
		"en": "Spec-Ops",
		"pattern": 0,
		"primary": "#282c32",
		"secondary": "#1b1e23",
		"tertiary": "#131519",
		"accent": "#de5a24",
		"wear": 0,
	},
	{
		"id": "hazard",
		"zh": "重工工程",
		"en": "Heavy Works",
		"pattern": 3,
		"primary": "#a47e2e",
		"secondary": "#3c4045",
		"tertiary": "#23262a",
		"accent": "#e36619",
		"wear": 2,
	},
	{
		"id": "crimson",
		"zh": "赤色先锋",
		"en": "Vanguard",
		"pattern": 2,
		"primary": "#732e28",
		"secondary": "#3a3638",
		"tertiary": "#211f21",
		"accent": "#d4a43c",
		"wear": 1,
	},
]

const ARMOR_SWATCHES := [
	"#8c7a5b", "#6b563e", "#4d5941", "#384531", "#58636e", "#38434f",
	"#96a0a8", "#282c32", "#a47e2e", "#732e28", "#594e63", "#4a4843",
]

const ACCENT_SWATCHES := [
	"#d19929", "#e36619", "#ba342a", "#389ec4", "#4ea865", "#d9c79e",
	"#c44d80", "#8468c4", "#b8863b", "#5d738a", "#7a8471", "#2b2e33",
]

static var _paint_mat_cache := {}


static func default_config() -> Dictionary:
	return {
		"preset": "default",
		"pattern": 0,
		"primary": "#585e58",
		"secondary": "#3d423e",
		"accent": "#d19929",
		"wear": 1,
	}


static func preset_by_id(id: String) -> Dictionary:
	for p: Dictionary in PRESETS:
		if str(p.get("id", "")) == id:
			return p
	return PRESETS[0]


static func config_from_preset(id: String) -> Dictionary:
	var p := preset_by_id(id)
	return {
		"preset": str(p.get("id", "default")),
		"pattern": clampi(int(p.get("pattern", 0)), 0, 3),
		"primary": str(p.get("primary", "#585e58")),
		"secondary": str(p.get("secondary", "#3d423e")),
		"accent": str(p.get("accent", "#d19929")),
		"wear": clampi(int(p.get("wear", 1)), 0, 2),
	}


static func _sanitize_hex(raw: String, fallback: String) -> String:
	var s := raw.strip_edges()
	if not s.begins_with("#"):
		s = "#" + s
	if s.length() == 7 and s.substr(1).is_valid_hex_number(false):
		return s.to_lower()
	if s.length() == 9 and s.substr(1).is_valid_hex_number(false):
		return ("#" + s.substr(1, 6)).to_lower()
	return fallback


static func sanitize(raw) -> Dictionary:
	var def := default_config()
	if typeof(raw) != TYPE_DICTIONARY:
		return def
	var d: Dictionary = raw
	var pid := str(d.get("preset", "default"))
	var valid_pid := (pid == "custom")
	if not valid_pid:
		for p: Dictionary in PRESETS:
			if str(p.get("id", "")) == pid:
				valid_pid = true
				break
	if not valid_pid:
		pid = "default"
	return {
		"preset": pid,
		"pattern": clampi(int(d.get("pattern", 0)), 0, 3),
		"primary": _sanitize_hex(str(d.get("primary", def.primary)), str(def.primary)),
		"secondary": _sanitize_hex(str(d.get("secondary", def.secondary)), str(def.secondary)),
		"accent": _sanitize_hex(str(d.get("accent", def.accent)), str(def.accent)),
		"wear": clampi(int(d.get("wear", 1)), 0, 2),
	}


static func is_factory_default(cfg: Dictionary) -> bool:
	return str(cfg.get("preset", "default")) == "default"


static func display_name(cfg: Dictionary) -> String:
	var pid := str(cfg.get("preset", "default"))
	if pid == "custom":
		return Loc.t("自定义涂装", "Custom Paint")
	var p := preset_by_id(pid)
	return Loc.t(str(p.get("zh", "原厂标准")), str(p.get("en", "Factory")))


static func pattern_name(pat: int) -> String:
	match clampi(pat, 0, 3):
		1: return Loc.t("斑块迷彩", "Woodland")
		2: return Loc.t("折线数码", "Splinter")
		3: return Loc.t("斜切虎纹", "Tiger")
		_: return Loc.t("纯色双拼", "Solid")


static func wear_name(w: int) -> String:
	match clampi(w, 0, 2):
		0: return Loc.t("出厂新漆", "Factory New")
		2: return Loc.t("重度战损", "Scarred")
		_: return Loc.t("标准服役", "Service")


static func _tertiary_color(cfg: Dictionary, c_pri: Color, c_sec: Color) -> Color:
	var pid := str(cfg.get("preset", "default"))
	if pid != "custom" and pid != "default":
		var p := preset_by_id(pid)
		if str(p.get("tertiary", "")) != "":
			return Color.from_string(str(p.tertiary), c_pri.lerp(c_sec, 0.62).darkened(0.42))
	return c_pri.lerp(c_sec, 0.62).darkened(0.42)


static func classify_material(mat: Material) -> String:
	if not (mat is ShaderMaterial):
		return ""
	var sm := mat as ShaderMaterial
	if sm.shader == null:
		return ""
	var rp := sm.shader.resource_path
	if not (rp.contains("mech_trim") or rp.contains("mech_paint")):
		return ""
	if sm.has_meta("paint_role"):
		return str(sm.get_meta("paint_role"))
	var raw_v = sm.get_shader_parameter("raw_albedo")
	if raw_v != null and float(raw_v) >= 0.5:
		return ""
	var met_v = sm.get_shader_parameter("metal_base")
	if met_v != null and float(met_v) > 0.18:
		return ""
	var td_v = sm.get_shader_parameter("takes_damage")
	if td_v != null and float(td_v) > 0.5:
		return "armor"
	var rgh_v = sm.get_shader_parameter("rough_base")
	if rgh_v != null and float(rgh_v) >= 0.82:
		return ""
	return "accent"


## 在重新运行 MV.apply + _batch_visual 之前调用：还原原始材质并清除网格级涂装元数据，确保静态合批无阻碍
static func restore_for_rebatch(visual: Node3D) -> void:
	if visual == null or not is_instance_valid(visual):
		return
	for n in visual.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		if mi.has_meta("_paint_orig_mat"):
			var orig = mi.get_meta("_paint_orig_mat")
			if orig is Material:
				mi.material_override = orig
			mi.remove_meta("_paint_orig_mat")


static func apply(visual: Node3D, raw_cfg: Dictionary, force_occ_exempt := false) -> void:
	if visual == null or not is_instance_valid(visual):
		return
	var cfg := sanitize(raw_cfg)
	var is_def := is_factory_default(cfg)
	var pat := clampi(int(cfg.pattern), 0, 3)
	var w_idx := clampi(int(cfg.wear), 0, 2)
	var wear_v: float = WEAR_VALUES[w_idx]
	var rust_v: float = RUST_VALUES[w_idx]
	var grime_v: float = GRIME_VALUES[w_idx]
	var c_pri := Color.from_string(str(cfg.primary), Color(0.35, 0.37, 0.35))
	var c_sec := Color.from_string(str(cfg.secondary), Color(0.24, 0.26, 0.24))
	var c_acc := Color.from_string(str(cfg.accent), Color(0.82, 0.60, 0.16))
	var c_ter := _tertiary_color(cfg, c_pri, c_sec)
	var sig_base := "%s|%d|%s|%s|%s|%s|%d" % [
		str(cfg.preset), pat, c_pri.to_html(false), c_sec.to_html(false),
		c_ter.to_html(false), c_acc.to_html(false), w_idx
	]
	if _paint_mat_cache.size() > 512:
		_paint_mat_cache.clear()

	for n in visual.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or mi.material_override == null:
			continue
		if not mi.has_meta("_paint_orig_mat"):
			mi.set_meta("_paint_orig_mat", mi.material_override)
		var orig: Material = mi.get_meta("_paint_orig_mat")
		if is_def:
			mi.material_override = orig
			continue
		var role := classify_material(orig)
		if role == "":
			mi.material_override = orig
			continue
		var orig_sm := orig as ShaderMaterial
		var occ_ex := force_occ_exempt
		if not occ_ex:
			var ex_v = orig_sm.get_shader_parameter("occ_exempt")
			if ex_v != null and float(ex_v) >= 0.5:
				occ_ex = true
		var ckey := "%d|%s|%s|%d" % [orig.get_instance_id(), role, sig_base, 1 if occ_ex else 0]
		var painted: ShaderMaterial = _paint_mat_cache.get(ckey)
		if painted == null:
			painted = orig_sm.duplicate() as ShaderMaterial
			var is_trim := painted.shader != null and painted.shader.resource_path.contains("mech_trim")
			match role:
				"armor":
					painted.set_shader_parameter("base_color", c_pri)
					if is_trim:
						painted.set_shader_parameter("camo_mode", pat)
						painted.set_shader_parameter("camo_col_b", c_sec)
						painted.set_shader_parameter("camo_col_c", c_ter)
				"armor_sub":
					if pat > 0 and is_trim:
						painted.set_shader_parameter("base_color", c_pri.darkened(0.16))
						painted.set_shader_parameter("camo_mode", pat)
						painted.set_shader_parameter("camo_col_b", c_sec.darkened(0.16))
						painted.set_shader_parameter("camo_col_c", c_ter.darkened(0.12))
					else:
						painted.set_shader_parameter("base_color", c_sec)
						if is_trim:
							painted.set_shader_parameter("camo_mode", 0)
				"armor_dark":
					painted.set_shader_parameter("base_color", c_ter.darkened(0.22) if pat > 0 else c_pri.lerp(c_sec, 0.5).darkened(0.42))
					if is_trim:
						painted.set_shader_parameter("camo_mode", 0)
				"armor_oxide":
					painted.set_shader_parameter("base_color", c_sec.darkened(0.18))
					if is_trim:
						painted.set_shader_parameter("camo_mode", 0)
				"accent":
					painted.set_shader_parameter("base_color", c_acc)
					if is_trim:
						painted.set_shader_parameter("camo_mode", 0)
			painted.set_shader_parameter("wear", wear_v if role != "accent" else clampf(wear_v * 0.92, 0.14, 0.78))
			painted.set_shader_parameter("rust", rust_v if role != "accent" else rust_v * 0.45)
			painted.set_shader_parameter("grime", grime_v)
			if occ_ex:
				painted.set_shader_parameter("occ_exempt", 1.0)
			_paint_mat_cache[ckey] = painted
		mi.material_override = painted
