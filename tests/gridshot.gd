extends "res://tests/lib/test_base.gd"
## 回归截图：战斗中受伤暗角 + 连续开火（炮口火光）时画面不应出现半透明方格。
## godot --path . -- --gridshot → review/gridshot.png
const TIMEOUT := 900.0

func run() -> void:
	await wait(0.5)
	var raid = await deploy({"core": "core_std", "legs": "legs_biped", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_missile", "gen": "gen_reactor"})
	var m = raid.mech
	m.shield_time = 99999
	for i in 6:
		raid.spawn_bug("ling", m.global_position + Vector3(4 + i, 0.5, -6 - i))
	raid.aim_override = m.global_position + Vector3(6, 1.8, -6)
	Input.action_press("fire_left")
	Input.action_press("fire_right")
	await wait(0.6)
	raid.hud.hurt_t = 0.6
	await frames(2)
	await shot("gridshot.png")
	Input.action_release("fire_left")
	Input.action_release("fire_right")
