extends "res://tests/lib/test_base.gd"
## 地表、烟尘与战术地面特效实机 Vulkan 截图校验：
##   godot --path . --resolution 1920x1080 -- --ground_fx_showcase

const Hazards = preload("res://scripts/enemies/hazards.gd")
const TIMEOUT := 240.0

const DEFAULT_LO := {
	"core": "core_heavy",
	"legs": "legs_biped_scout",
	"arm_l": "arm_ac30",
	"arm_r": "arm_mg",
	"back": "back_cargo",
	"gen": "gen_reactor",
}


func _switch_and_deploy(mid: String, lo := DEFAULT_LO) -> Node:
	if main.raid != null and is_instance_valid(main.raid):
		main.raid.queue_free()
		main.raid = null
		await frames(6)
	GameData.map_id = mid
	main.show_hub()
	await frames(4)
	return await deploy(lo)


func _clear_bugs() -> void:
	for b: Node in get_tree().get_nodes_in_group("bugs"):
		b.queue_free()


func run() -> void:
	if headless():
		log_line("skip ground_fx_showcase in headless")
		return

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	get_window().size = Vector2i(1920, 1080)
	await frames(4)

	# 1. 铁锈工业带：无缝地表细节、道路肩角/建筑基础 AO、缩尺膛口硝烟与清晰中心视野
	var raid := await _switch_and_deploy("ironbelt")
	if not check(raid != null, "ironbelt 出击失败"):
		return
	_clear_bugs()
	await wait(2.0)
	var m1: Node3D = raid.mech
	raid.aim_override = m1.global_position + Vector3(-8.5, 1.5, -5.5)
	Input.action_press("move_right")
	Input.action_press("fire_left")
	Input.action_press("fire_right")
	await wait(0.32)
	await shot("gfx_01_ironbelt_ground_muzzle.png")
	Input.action_release("move_right")
	Input.action_release("fire_left")
	Input.action_release("fire_right")
	raid.aim_override = null

	# 2. 灰港空投着陆瞬间：贴地风切沙尘环、3D 岩石碎屑、星状陨石坑与背部喷汽
	if main.raid != null and is_instance_valid(main.raid):
		main.raid.queue_free()
		main.raid = null
		await frames(6)
	GameData.map_id = "greyport"
	GameData.loadout = DEFAULT_LO.duplicate()
	main.show_hub()
	await frames(4)
	main.hub.deploy_requested.emit()
	var ok_raid: bool = await until(func(): return main.raid != null and main.raid.mech != null, 8.0)
	if not check(ok_raid, "greyport 空投初始化失败"):
		return
	raid = main.raid
	Engine.time_scale = 0.20
	var gt := 0.0
	while gt < 1.92:
		await get_tree().process_frame
		gt += get_process_delta_time()
	await shot("gfx_02_greyport_drop_impact.png")
	Engine.time_scale = 1.0
	await until(func(): return not raid.mech.input_locked, 15.0)
	_clear_bugs()

	# 3. 灰港雨夜实体湿润地面水洼反光、风向雨丝与地面溅水花
	raid.cam_zoom = 1.12
	await wait(1.5)
	await shot("gfx_03_greyport_wet_puddles.png")
	raid.cam_zoom = 1.0

	# 4. 爆炸火球 / 立体翻涌黑烟 / 贴地扬尘冲击环 + 径向溅射焦痕陨石坑
	var mp: Vector3 = raid.mech.global_position
	raid.explode_fx(mp + Vector3(-4.8, 0.0, -3.2), 3.6, Color(1.0, 0.58, 0.2))
	await wait(0.68)
	raid.explode_fx(mp + Vector3(4.8, 0.0, -2.4), 3.2, Color(1.0, 0.62, 0.22))
	await wait(0.20)
	await shot("gfx_04_explosions_craters.png")

	# 5. 峡谷日光高对比：SDF 抗锯齿战术预警环、滚动箭头激光冲锋带、有机制毒酸液池
	raid = await _switch_and_deploy("canyon")
	if not check(raid != null, "canyon 出击失败"):
		return
	_clear_bugs()
	await wait(0.8)
	var mp5: Vector3 = raid.mech.global_position
	var tr_ring := Hazards.Telegraph.new()
	raid.fx.add_child(tr_ring)
	tr_ring.setup_ring(raid, mp5 + Vector3(-5.2, 0.0, -2.5), 3.4, 3.0, Color(1.0, 0.42, 0.16))
	var tr_lane := Hazards.Telegraph.new()
	raid.fx.add_child(tr_lane)
	tr_lane.setup_lane(raid, mp5 + Vector3(2.4, 0.0, 3.8), Vector3(-0.32, 0.0, -1.0), 2.5, 9.2, 3.0, Color(1.0, 0.48, 0.16))
	var mk := Hazards.Mark.new()
	raid.fx.add_child(mk)
	mk.setup(raid, mp5 + Vector3(5.6, 0.0, -3.0), 2.3, 3.0, Color(1.0, 0.28, 0.18))
	var pool := Hazards.AcidPool.new()
	raid.fx.add_child(pool)
	pool.setup(raid, mp5 + Vector3(-2.0, 0.0, 4.2), 3.1, 8.0, 0.0, Color(0.42, 0.90, 0.16))
	await wait(1.05)
	await shot("gfx_05_tactical_telegraphs_acid.png")

	# 6. 沙尘荒原：跳跃喷口起落微尘与淡出焦痕 + 风掠沙尘气团
	raid = await _switch_and_deploy("dustfield")
	if not check(raid != null, "dustfield 出击失败"):
		return
	_clear_bugs()
	await wait(0.9)
	Input.action_press("dash")
	await frames(2)
	Input.action_release("dash")
	await wait(0.72)
	await shot("gfx_06_dustfield_sandstorm.png")
