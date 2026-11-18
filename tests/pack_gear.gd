extends "res://tests/lib/test_base.gd"
## 15 躯干 + 10 动力炉资产包：数据注册、图标映射、英文名、稀有度第 5 档。
## godot --headless --path . -- --pack_gear

const I18nEq = preload("res://scripts/i18n/i18n_equipment.gd")
const Icons = preload("res://scripts/item_icons.gd")

const IDS := [
	"core_m1a2_sepv3", "core_t90m_proryv", "core_merkava_mk4m", "core_puma_spz",
	"core_bmpt_terminator", "core_bradley_busk", "core_ka52_alligator", "core_mi24_hind",
	"core_fennek_recon", "core_pantsir_s1", "core_patriot_mpq65", "core_krasukha_ew",
	"core_trieste_bathy", "core_abv_shredder", "core_pionier_dach",
	"gen_agt1500_turbine", "gen_mtu_mb873_v12", "gen_twin_apu_gtcp", "gen_naval_pwr_s9g",
	"gen_lfr_lead_bismuth", "gen_stirling_aip", "gen_pem_fuelcell", "gen_homopolar_pulse",
	"gen_mhd_plasma_gen", "gen_hydrothermal_hx",
]


func run() -> void:
	await wait(0.3)
	for id: String in IDS:
		if not check(GameData.MODULES.has(id), "模块未注册：%s" % id):
			return
		var script_path := ProjectSettings.globalize_path("res://scripts/modules/%s.gd" % id)
		if not check(FileAccess.file_exists(script_path), "建模脚本缺失：%s" % id):
			return
		if not check(I18nEq.MODULES_EN.has(id), "英文名缺失：%s" % id):
			return
		if not check(ResourceLoader.exists("res://assets/icons/items/%s.png" % id), "专属图标缺失（请运行 --bake_icons）：%s" % id):
			return
		var alias := str(Icons.MODULE_ICON_ALIAS.get(id, ""))
		if not check(alias != "", "图标映射缺失：%s" % id):
			return
		if not check(ResourceLoader.exists("res://assets/icons/items/%s.png" % alias), "别名图标不存在：%s -> %s" % [id, alias]):
			return
		if not check(Icons.icon(id) != null, "图标加载失败：%s" % id):
			return
	log_line("25 模块 数据/脚本/图标映射 OK")

	Loc.set_lang("en", false)
	await frames(3)
	for id: String in IDS:
		var en_name := str(I18nEq.MODULES_EN[id].get("name", ""))
		if not check(str(GameData.module(id).get("name", "")) == en_name, "英文名未生效：%s" % id):
			return
	check(GameData.RARITY_NAMES.size() >= 5 and GameData.RARITY_COLORS.size() >= 5, "稀有度第 5 档未扩展")
	check(GameData.RARITY_NAMES[4] == "Prototype", "英文第 5 档名称错误：%s" % GameData.RARITY_NAMES[4])
	Loc.set_lang("zh", false)
	await frames(3)
	check(str(GameData.module("core_m1a2_sepv3").get("name", "")).begins_with("SEP-V3"), "切回中文后名称未恢复")
	log_line("英文名 / 第 5 稀有度 OK")