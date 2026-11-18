extends "res://tests/lib/test_base.gd"
## 实机子弹弹道、膛口喷焰与敌我弹种可辨识度 Vulkan 截图校验：
##   godot --path . --resolution 1920x1080 -- --bullet_fx_showcase

const NpcScript = preload("res://scripts/factions/npc_mech.gd")
const TIMEOUT := 240.0

const BASE_LO := {
	"core": "core_heavy",
	"legs": "legs_biped_scout",
	"arm_l": "arm_mg",
	"arm_r": "arm_ac30",
	"back": "back_cargo",
	"gen": "gen_crystal",
}


func _switch_and_deploy(mid: String, lo := BASE_LO) -> Node:
	Engine.time_scale = 1.0
	if main.raid != null and is_instance_valid(main.raid):
		main.raid.queue_free()
		main.raid = null
		await frames(6)
	GameData.map_id = mid
	main.show_hub()
	await frames(4)
	return await deploy(lo)


func _clear_entities(keep_rovers := false) -> void:
	for b: Node in get_tree().get_nodes_in_group("bugs"):
		b.queue_free()
	if not keep_rovers:
		for r: Node in get_tree().get_nodes_in_group("rovers"):
			r.queue_free()


func _equip_pair(mech: Node, arm_l: String, arm_r: String) -> void:
	mech.equip_module_in_raid("arm_l", arm_l)
	mech.equip_module_in_raid("arm_r", arm_r)
	mech.hp = mech.max_hp
	mech.energy = mech.max_energy
	mech.arm_cd["arm_l"] = 0.0
	mech.arm_cd["arm_r"] = 0.0
	mech.reload_t["arm_l"] = 0.0
	mech.reload_t["arm_r"] = 0.0
	mech.ammo["arm_l"] = mech.mag["arm_l"]
	mech.ammo["arm_r"] = mech.mag["arm_r"]


func _aim_and_burst(raid: Node, target: Vector3, step_sec: float, shots_l: int, shots_r: int) -> void:
	Engine.time_scale = 1.0
	var mech: Node3D = raid.mech
	mech.hp = mech.max_hp
	mech.energy = mech.max_energy
	raid.aim_override = target
	await wait(0.45)
	Engine.time_scale = 0.14
	var total := maxi(shots_l, shots_r)
	for i in total:
		if i < shots_l:
			mech.arm_cd["arm_l"] = 0.0
			mech.ammo["arm_l"] = mech.mag["arm_l"]
			mech.try_fire("arm_l")
		if i < shots_r:
			mech.arm_cd["arm_r"] = 0.0
			mech.ammo["arm_r"] = mech.mag["arm_r"]
			mech.try_fire("arm_r")
		if i < total - 1:
			await wait(step_sec)
	await frames(2)


func run() -> void:
	if headless():
		log_line("skip bullet_fx_showcase in headless")
		return

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	get_window().size = Vector2i(1920, 1080)
	await frames(4)

	# 1. 铁锈工业带日光沙地：对比旧版“白色雾团”，展示 MG(琥珀黄) + AC-30(烈焰橙红) 清晰针状曳光、抛壳与立体喷焰
	var raid := await _switch_and_deploy("ironbelt", BASE_LO)
	if not check(raid != null, "ironbelt 出击失败"):
		return
	_clear_entities()
	Engine.time_scale = 4.0
	await wait(2.8)
	Engine.time_scale = 1.0
	var mp1: Vector3 = raid.mech.global_position
	var bug1 = raid.spawn_bug("beetle", mp1 + Vector3(-9.5, 0.0, -3.5))
	if bug1:
		bug1.hp = 9999.0
	await _aim_and_burst(raid, mp1 + Vector3(-11.0, 1.4, -4.0), 0.055, 3, 3)
	await shot("bfx_01_ironbelt_mg_ac30.png")

	# 2. 灰港雨夜湿润草地/柏油路面：GAU-6 六管转管炮 + HMG-24 重机枪高频倾泻（零白雾光团）
	raid = await _switch_and_deploy("greyport", {
		"core": "core_heavy",
		"legs": "legs_biped_scout",
		"arm_l": "arm_gatling",
		"arm_r": "arm_hmg",
		"back": "back_cargo",
		"gen": "gen_crystal",
	})
	if not check(raid != null, "greyport 出击失败"):
		return
	_clear_entities()
	Engine.time_scale = 4.0
	await wait(2.8)
	Engine.time_scale = 1.0
	var mp2: Vector3 = raid.mech.global_position
	var bug2 = raid.spawn_bug("beetle", mp2 + Vector3(8.5, 0.0, -3.8))
	if bug2:
		bug2.hp = 9999.0
	await _aim_and_burst(raid, mp2 + Vector3(10.0, 1.4, -4.5), 0.042, 4, 4)
	await shot("bfx_02_greyport_gatling_hmg.png")

	# 3. 霰弹散射扇面 + CN-105 短管炮重型制退器 V 型喷焰与深红破甲弹道
	Engine.time_scale = 1.0
	_equip_pair(raid.mech, "arm_shotgun", "arm_cannon")
	await wait(0.45)
	await _aim_and_burst(raid, mp2 + Vector3(-10.5, 1.4, -3.2), 0.075, 2, 2)
	await shot("bfx_03_shotgun_cannon.png")

	# 4. 精确狙击步枪(钨金高亮) + 反器材 20mm 重炮(炽红穿甲曳光) 超高速弹道
	Engine.time_scale = 1.0
	if bug2 and is_instance_valid(bug2):
		bug2.queue_free()
	_equip_pair(raid.mech, "arm_sniper", "arm_amr")
	await wait(0.45)
	await _aim_and_burst(raid, mp2 + Vector3(-11.5, 1.4, 3.6), 0.022, 2, 2)
	await shot("bfx_04_sniper_amr.png")

	# 5. LZ-42 电磁线圈(钴蓝电浆芯) + RG-9 轨道炮(冰青 APFSDS + 三瓣铝制弹托抛飞 + 蓝色命中火花)
	Engine.time_scale = 1.0
	_equip_pair(raid.mech, "arm_laser", "arm_rail")
	var mp5: Vector3 = raid.mech.global_position
	var bug5 = raid.spawn_bug("beetle", mp5 + Vector3(9.5, 0.0, 2.8))
	if bug5:
		bug5.hp = 9999.0
	await wait(0.45)
	await _aim_and_burst(raid, mp5 + Vector3(11.0, 1.4, 3.2), 0.024, 3, 2)
	await shot("bfx_05_coil_railgun.png")

	# 6. 敌我交叉火力辨识：己方机甲暖金/橙红弹道 vs 流浪者(Rover) 警示猩红曳光交叉对射
	Engine.time_scale = 1.0
	if bug5 and is_instance_valid(bug5):
		bug5.queue_free()
	_equip_pair(raid.mech, "arm_mg", "arm_ac30")
	var mp6: Vector3 = raid.mech.global_position
	var rover: CharacterBody3D = NpcScript.new()
	raid.world.add_child(rover)
	rover.set("raid", raid)
	rover.global_position = mp6 + Vector3(9.0, 0.0, -5.0)
	rover.call("setup_npc", {
		"core": "core_std",
		"legs": "legs_tread",
		"arm_l": "arm_hmg",
		"arm_r": "arm_ac30",
		"back": "back_rack",
		"gen": "gen_reactor",
	}, "rover", 2)
	rover.set("hp", 9999.0)
	await wait(0.5)
	var p_target := mp6 + Vector3(9.0, 1.4, -2.0)
	var r_target := mp6 + Vector3(-2.0, 1.4, 1.5)
	raid.aim_override = p_target
	rover.set("ai_target", null)
	rover.set_physics_process(false)
	var r_dir: Vector3 = (r_target - rover.global_position).normalized()
	r_dir.y = 0.0
	r_dir = r_dir.normalized()
	var r_yaw := atan2(-r_dir.x, -r_dir.z)
	if rover.get("torso"):
		rover.get("torso").rotation = Vector3(0.0, r_yaw, 0.0)
	if rover.get("legs"):
		rover.get("legs").rotation = Vector3(0.0, r_yaw, 0.0)
	if rover.has_method("_vis_sync"):
		rover.call("_vis_sync")
	await frames(2)
	await wait(0.35)
	Engine.time_scale = 0.14
	var p_dir: Vector3 = (p_target - mp6).normalized()
	p_dir.y = 0.0
	p_dir = p_dir.normalized()
	var m_hmg: Dictionary = GameData.module("arm_hmg")
	var m_ac: Dictionary = GameData.module("arm_ac30")
	var r_muzzles: Dictionary = rover.get("muzzles")
	for i in 3:
		raid.mech.arm_cd["arm_l"] = 0.0
		raid.mech.arm_cd["arm_r"] = 0.0
		raid.mech.ammo["arm_l"] = raid.mech.mag["arm_l"]
		raid.mech.ammo["arm_r"] = raid.mech.mag["arm_r"]
		raid.mech.try_fire("arm_l")
		raid.mech.try_fire("arm_r")
		var r_orig_l: Vector3 = (r_muzzles["arm_l"] as Node3D).global_position if r_muzzles.has("arm_l") else rover.global_position + Vector3(0, 1.9, 0)
		var r_orig_r: Vector3 = (r_muzzles["arm_r"] as Node3D).global_position if r_muzzles.has("arm_r") else rover.global_position + Vector3(0, 1.9, 0)
		rover.call("_shot", m_hmg, r_orig_l, r_dir)
		rover.call("_shot", m_ac, r_orig_r, r_dir)
		raid.muzzle_flash(r_orig_l, Color(1.0, 0.24, 0.14), r_dir, "mg", float(m_hmg.dmg))
		raid.muzzle_flash(r_orig_r, Color(1.0, 0.24, 0.14), r_dir, "mg", float(m_ac.dmg))
		if i < 2:
			await wait(0.055)
	await frames(2)
	await shot("bfx_06_rover_crossfire.png")
	raid.aim_override = null
	Engine.time_scale = 1.0
