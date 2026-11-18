extends "res://tests/lib/test_base.gd"
## Meshy Boss 实机渲染多动作视觉验收：生成 excavator_titan 并截取待机/行走/斗轮挥砍/射击/震地/核心暴露/死亡 7 张实机截图。
## godot --path . -- --boss_meshy_view → review\boss_meshy_*.png
const START := "none"
const A = preload("res://scripts/art.gd")

var cam: Camera3D


func run() -> void:
	Story.set_process(false)
	Story.data = {}
	await frames(2)
	_rig()

	var info: Dictionary = GameData.ENEMIES.get("excavator_titan", {})
	if not check(not info.is_empty(), "GameData.ENEMIES 缺少 excavator_titan"):
		return
	var scr: Script = load(str(info.get("script", "")))
	if not check(scr != null, "无法加载 excavator_titan 行为脚本"):
		return
	var b = scr.new()
	add_child(b)
	b.setup("excavator_titan", null, null)
	b.set_physics_process(false)
	b.global_position = Vector3.ZERO
	if not check(b.has_meta("glb_rig"), "excavator_titan 未启用 GLB 骨骼模型适配器"):
		return
	var rig: Dictionary = b.get_meta("glb_rig")
	var ap: AnimationPlayer = rig.get("ap")
	if not check(is_instance_valid(ap), "excavator_titan 缺少 AnimationPlayer"):
		return
	log_line("excavator_titan anims=%s" % [ap.get_animation_list()])
	for req: String in ["idle", "walk", "charge", "claw", "shoot", "stomp", "roar", "hit", "dead"]:
		if not check(ap.has_animation(req), "缺少动作剪辑: %s" % req):
			return

	# 1. 待机 (idle)
	b.awake = false
	b.act = ""
	for _k in 10:
		b._animate(0.05, 0.0)
		await frames(1)
	await _snap("boss_meshy_idle.png")

	# 2. 行走 (walk)
	b.awake = true
	rig["awaken_t"] = 0.0
	b.act = ""
	for _k in 24:
		b._animate(0.05, 1.0)
		await frames(1)
	await _snap("boss_meshy_walk.png")

	# 3. 斗轮挥砍 (claw)
	b.act = "claw"
	for _k in 18:
		b._animate(0.05, 0.0)
		await frames(1)
	await _snap("boss_meshy_claw.png")

	# 4. 重炮/火箭齐射 (shoot)
	b.act = "salvo"
	for _k in 16:
		b._animate(0.05, 0.0)
		await frames(1)
	await _snap("boss_meshy_shoot.png")

	# 5. 蓄力震地砸击 (stomp)
	b.act = "stomp"
	for _k in 24:
		b._animate(0.05, 0.0)
		await frames(1)
	await _snap("boss_meshy_stomp.png")

	# 6. 三阶段核心暴露 + 咆哮 (roar + core)
	b.act = "core"
	b.open_core(60.0)
	for _k in 22:
		b._animate(0.05, 0.0)
		await frames(1)
	await _snap("boss_meshy_core.png")

	# 7. 击破死亡倒地 (dead)
	b.core_open = 0.0
	b.core_vis = 0.0
	b.act = ""
	b._die()
	await wait(2.85)
	await _snap("boss_meshy_dead.png")

	b.queue_free()
	log_line("boss_meshy_view captured 7 shots ok")


func _snap(file: String) -> void:
	get_tree().paused = false
	for c in get_tree().root.get_children():
		if c is CanvasLayer or c is Control:
			c.visible = false
	await frames(2)
	await shot(file)


func _rig() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.24, 0.28, 0.38)
	sky_mat.sky_horizon_color = Color(0.68, 0.54, 0.44)
	sky_mat.ground_bottom_color = Color(0.12, 0.11, 0.10)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.1
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -145, 0)
	sun.light_energy = 1.8
	sun.light_color = Color(1.0, 0.94, 0.85)
	sun.shadow_enabled = true
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-24, 30, 0)
	rim.light_energy = 0.55
	rim.light_color = Color(0.55, 0.68, 0.96)
	add_child(rim)
	var g := MeshInstance3D.new()
	g.mesh = A.quad(90, 90)
	g.material_override = A.ground()
	add_child(g)
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 34.0
	cam.position = Vector3(3.8, 4.8, -12.6)
	cam.look_at(Vector3(0, 3.0, 0))
