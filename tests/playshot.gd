extends "res://tests/lib/test_base.gd"
## v0.6 战斗玩法截图：流浪者机甲小队、更多虫群、地图边缘转场口、战斗队友。
## godot --path . -- --playshot → review/v06_battle.png / v06_wide.png / v06_gate.png / v06_radar.png
const TIMEOUT := 900.0
const Factions = preload("res://scripts/factions/factions.gd")
const WorldLink = preload("res://scripts/world_link.gd")


func run() -> void:
	WorldLink.force_open = true
	Factions.rovers_enabled = false
	Factions.test_ally_squad = [{"pilot": "rei", "tier": 2}, {"pilot": "kurumi", "tier": 3}]
	GameData.map_id = "greyport"
	await wait(0.5)
	var raid = await deploy({"core": "core_std", "legs": "legs_biped", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_missile", "gen": "gen_reactor"})
	if not check(raid != null, "出击失败"):
		return
	var m = raid.mech
	var fac = raid.factions
	m.shield_time = 99999
	m.max_hp = 1e6
	m.hp = 1e6
	await until(func(): return fac.allies.size() == 2, 5.0)
	# 站到东侧转场口内侧 26 米处，转场口在画面右侧
	var link = raid.world_link
	var g: Dictionary = link.gates["E"]
	var p0: Vector3 = fac._free_near(link._edge_point("E", float(g.along), 28.0))
	m.global_position = p0
	m.velocity = Vector3.ZERO
	for i in fac.allies.size():
		var a = fac.allies[i]
		a.global_position = fac._free_near(p0 + [Vector3(-5, 0, 5), Vector3(-6, 0, -4)][i])
		a.max_hp = 1e5
		a.hp = 1e5
	# 清掉近处的自然虫群，重新摆一圈好看的混编虫群
	for b in get_tree().get_nodes_in_group("bugs"):
		if b.global_position.distance_to(p0) < 45.0:
			b.queue_free()
	await frames(2)
	var kinds := ["ling", "ling", "spitter", "mantis", "bomber", "beetle", "wasp", "ling", "crystal_bug", "mortar", "mech_beetle", "ling", "spitter", "burrower", "wasp", "ironjaw"]
	var bugs: Array = []
	for i in 30:
		var q := p0 + Vector3(-30.0 + (i % 6) * 4.2 + randf_range(-1.2, 1.2), 0.5, -12.0 + (i / 6) * 5.0 + randf_range(-1.2, 1.2))
		var b = raid.spawn_bug(kinds[i % kinds.size()], fac._free_near(q) + Vector3(0, 0.3, 0))
		if b:
			b.hp = float(b.hp) * 20.0
			bugs.append(b)
	# 流浪者小队：从画面上方偏左压过来，正好撞上虫群
	var sq: Dictionary = fac.spawn_squad(3, [p0 + Vector3(-12, 0.3, -14), p0 + Vector3(40, 0.3, -14)])
	for r in sq.get("members", []):
		r.max_hp = 1e5
		r.hp = 1e5
	raid.cam_zoom = 1.15
	raid.aim_override = p0 + Vector3(-14, 1.8, -4)
	Input.action_press("fire_left")
	Input.action_press("fire_right")
	await wait(1.6)
	await shot("v06_battle.png")
	Input.action_release("fire_left")
	Input.action_release("fire_right")
	log_line("battle: bugs=%d rovers=%d allies=%d" % [get_tree().get_nodes_in_group("bugs").size(), get_tree().get_nodes_in_group("rovers").size(), fac.allies.size()])
	# 再过一秒补一张（交火推进后）
	await wait(1.2)
	await shot("v06_wide.png")
	# 转场口特写：机甲走进光幕前
	raid.cam_zoom = 0.85
	m.global_position = fac._free_near(link._edge_point("E", float(g.along), 16.0))
	raid.aim_override = link._edge_point("E", float(g.along), 2.0) + Vector3(0, 1.8, 0)
	await wait(1.0)
	await shot("v06_gate.png")
	# HUD 雷达（流浪者菱形 / 队友三角 / 转场口箭头）放大截一张
	if raid.hud and raid.hud.radar:
		var rr: Rect2 = raid.hud.radar.get_global_rect()
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var sub := img.get_region(Rect2i(rr.grow(6.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
		if sub:
			sub.resize(sub.get_width() * 2, sub.get_height() * 2, Image.INTERPOLATE_NEAREST)
			sub.save_png(ProjectSettings.globalize_path(REVIEW_DIR).path_join("v06_radar.png"))
	Factions.test_ally_squad = null
	Factions.rovers_enabled = true
	WorldLink.force_open = false
