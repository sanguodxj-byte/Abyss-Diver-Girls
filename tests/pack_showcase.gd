extends "res://tests/lib/test_base.gd"
## 新装备包展示截图：新核心 + 新动力炉整机、仓库图标映射、英文名。
## godot --path . -- --pack_showcase → review/pack_showcase_mech.png / _stash.png / _en.png
const START := "hub"
const TIMEOUT := 150.0

const IDS := [
	"core_m1a2_sepv3", "core_t90m_proryv", "core_merkava_mk4m", "core_puma_spz",
	"core_bmpt_terminator", "core_bradley_busk",
	"core_fennek_recon", "core_pantsir_s1", "core_patriot_mpq65", "core_krasukha_ew",
	"core_abv_shredder", "core_pionier_dach",
	"gen_agt1500_turbine", "gen_mtu_mb873_v12", "gen_twin_apu_gtcp",
	"gen_lfr_lead_bismuth", "gen_pem_fuelcell", "gen_homopolar_pulse",
	"gen_mhd_plasma_gen", "gen_hydrothermal_hx",
]


func run() -> void:
	await wait(1.4)
	var hub = main.hub
	GameData.loadout = {
		"core": "core_m1a2_sepv3", "legs": "legs_tread_heavy",
		"arm_l": "arm_ac30", "arm_r": "arm_gau8",
		"back": "back_vls", "gen": "gen_lfr_lead_bismuth",
	}
	for id: String in IDS:
		if not GameData.stash.has(id):
			GameData.stash.append(id)
	hub.refresh()
	hub._switch_tab("maintenance")
	await wait(1.2)
	await shot("pack_showcase_mech.png")

	hub._switch_tab("stash")
	await wait(0.9)
	if not hub.stash_ids.is_empty():
		var idx: int = hub.stash_ids.find("core_m1a2_sepv3")
		if idx < 0:
			idx = 0
		hub.stash_list.select(idx)
		hub._on_stash_selected(idx)
		await wait(0.5)
	await shot("pack_showcase_stash.png")

	Loc.set_lang("en", false)
	await wait(1.0)
	hub = main.hub
	if hub != null:
		hub.refresh()
		hub._switch_tab("stash")
		await wait(0.6)
		await shot("pack_showcase_en.png")
	Loc.set_lang("zh", false)
	await wait(0.6)
	hub = main.hub
	if hub != null:
		hub.refresh()