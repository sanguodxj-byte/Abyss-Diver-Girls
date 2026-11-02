extends "res://tests/lib/test_base.gd"
## 截图：godot --path . -- --shot → review\shot_hub.png / shot_raid.png / shot_loot.png / shot_raid2.png
func run() -> void:
	await wait(1.5)
	await shot("shot_hub.png")
	GameData.loadout = {"core":"core_std","legs":"legs_biped","arm_l":"arm_mg","arm_r":"arm_mg","back":"back_missile","gen":"gen_reactor"}
	main.hub.deploy_requested.emit()
	await wait(3.0)
	var raid = main.raid
	if not check(raid != null and raid.mech != null, "出击失败"):
		return
	raid.aim_override = raid.mech.global_position + Vector3(6, 1.8, -6)
	raid.spawn_bug("ling", raid.mech.global_position + Vector3(5, 0.5, -6))
	raid.spawn_bug("spitter", raid.mech.global_position + Vector3(-6, 0.5, -5))
	raid.spawn_bug("beetle", raid.mech.global_position + Vector3(0, 0.5, -9))
	raid.spawn_bug("ling", raid.mech.global_position + Vector3(3, 0.5, -7))
	raid.spawn_bug("ling", raid.mech.global_position + Vector3(-3, 0.5, -8))
	raid.spawn_bug("spitter", raid.mech.global_position + Vector3(7, 0.5, -3))
	var mm = raid.mech
	mm.hp = mm.max_hp * 0.82
	mm.parts.legs = 0.62
	mm.parts.arm_r = 0.38
	mm.parts.gen = 0.18
	mm.parts.back = 0.0
	mm.skill_e_cd = 6.3
	mm.skill_r_cd = 0.0
	Input.action_press("fire_right")
	Input.action_press("fire_left")
	await wait(0.6)
	await shot("shot_raid.png")
	Input.action_release("fire_left")
	Input.action_release("fire_right")
	var box = raid.nearest_box(999)
	raid.mech.global_position = box.global_position + Vector3(2, 0.5, 0)
	await wait(0.5)
	raid.open_container(box)
	await wait(1.6)
	await shot("shot_loot.png")
	raid.close_box()
	# 第二张：遗迹全景
	var lbls = raid.world.get_children().filter(func(n): return n is Label3D)
	if lbls.size() > 0:
		raid.mech.global_position = Vector3(lbls[0].position.x + 4, 0.5, lbls[0].position.z + 9)
		raid.aim_override = raid.mech.global_position + Vector3(-5, 1.8, -3)
	await wait(1.2)
	Input.action_press("fire_right")
	await wait(0.15)
	await shot("shot_raid2.png")
	Input.action_release("fire_right")
