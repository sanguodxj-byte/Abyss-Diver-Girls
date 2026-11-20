extends "res://tests/lib/test_base.gd"
const START := "hub"
const TIMEOUT := 180.0
const OUT_DIR := "C:/Users/Administrator/.gemini/antigravity/brain/c256213f-bc02-45a0-90b2-70b2657c52a2"

func _snap(name: String) -> void:
	await frames(8)
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("%s/%s" % [OUT_DIR, name])
		log_line("saved " + name)

func _shot_map(mid: String, tag: String, views: Array) -> void:
	GameData.map_id = mid
	var raid = await deploy({"core": "core_std", "legs": "legs_biped", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_missile", "gen": "gen_reactor"})
	if raid == null:
		fail("deploy failed: " + mid)
		return
	raid.hud.visible = false
	raid.mech.hp = 1e9; raid.mech.max_hp = 1e9; raid.mech.shield_time = 99999
	var cam := Camera3D.new()
	cam.fov = 44.0
	cam.near = 0.5
	cam.far = 600.0
	raid.add_child(cam)
	cam.current = true
	await frames(10)
	for v: Array in views:
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.UP)
		await _snap("mtn_%s_%s_%s.png" % [tag, mid, v[0]])
	GameData.map_id = "greyport"
	main.show_hub()
	await wait(0.4)

func run() -> void:
	var tag := "pbr1"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
	var F = load("res://scripts/factions/factions.gd")
	if F:
		F.rovers_enabled = false
		F.test_ally_squad = []
	await _shot_map("canyon", tag, [
		["gameplay_cliff", Vector3(-68, 22, -26), Vector3(-92, 5, -52)],
		["overview_k", Vector3(-20, 68, 45), Vector3(-88, 6, -65)],
		["east_wall", Vector3(88, 26, -32), Vector3(145, 7, -62)],
	])
	await _shot_map("dustfield", tag, [
		["east_cliff", Vector3(78, 24, -10), Vector3(132, 6, -42)],
	])
	await _shot_map("abyss_maw", tag, [
		["rim_wall", Vector3(-78, 26, -45), Vector3(-135, 8, -95)],
		["closeup", Vector3(-92, 16, -66), Vector3(-124, 9, -86)],
		["caldera_wide", Vector3(25, 36, 48), Vector3(-110, 12, -110)],
	])
	if F:
		F.rovers_enabled = true
		F.test_ally_squad = null
