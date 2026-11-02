extends "res://tests/lib/test_base.gd"
## 动作自检：在空旷靶场近景逐帧截图，输出 review\anim_<动作>_<帧>.png。godot --path . -- --anim [--legs=legs_quad]
var cam: Camera3D
var raid
var focus := Vector3.ZERO
var cam_off := Vector3(0, 3.2, 8.5)
var n := 0
const ARENA := Vector3(600, 0, 600)
const SLOW := 0.12
const TIMEOUT := 600.0

func snap(tag: String) -> void:
	await shot("anim_%s_%02d.png" % [tag, n])
	n += 1

func seq(tag: String, count: int, dt: float, follow: Node3D = null) -> void:
	Engine.time_scale = SLOW
	n = 0
	for i in count:
		if follow and is_instance_valid(follow):
			focus = follow.global_position
		await snap(tag)
		await wait(dt)
	Engine.time_scale = 1.0

func _process(d: float) -> void:
	super(d)
	if cam:
		cam.global_position = focus + cam_off
		cam.look_at(focus + Vector3(0, 1.2, 0), Vector3.UP)

func run() -> void:
	var legs_id := "legs_biped"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--legs="):
			legs_id = a.substr(7)
	await wait(0.3)
	GameData.loadout = {"core":"core_std","legs":legs_id,"arm_l":"arm_mg","arm_r":"arm_shotgun","back":"back_missile","gen":"gen_reactor"}
	main.hub.deploy_requested.emit()
	await wait(1.0)
	raid = main.raid
	var m = raid.mech
	while m.input_locked:
		await wait(0.2)
	if raid.hud:
		raid.hud.visible = false
	m.max_hp = 99999.0
	m.hp = 99999.0
	m.max_energy = 99999.0
	m.energy = 99999.0
	for b in get_tree().get_nodes_in_group("bugs"):
		b.queue_free()
	for b in get_tree().get_nodes_in_group("nests"):
		b.set_process(false)
		b.set_physics_process(false)
	# 靶场地面
	var floor := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(120, 1, 120)
	cs.shape = bs
	floor.add_child(cs)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.42, 0.38, 0.32)
	fm.roughness = 0.9
	mi.material_override = fm
	mi.position.y = 0.5
	floor.add_child(mi)
	floor.position = ARENA - Vector3(0, 0.5, 0)
	raid.add_child(floor)
	floor.collision_layer = 1
	m.global_position = ARENA + Vector3(0, 0.2, 0)
	cam = Camera3D.new()
	cam.fov = 38
	add_child(cam)
	cam.current = true
	focus = m.global_position
	await wait(0.4)
	# 1 走路（侧视）
	cam_off = Vector3(0, 3.0, 10.0)
	raid.aim_override = m.global_position + Vector3(40, 1.5, 0)
	Input.action_press("move_right")
	await wait(0.6)
	await seq("walk", 12, 0.03, m)
	Input.action_release("move_right")
	await wait(0.7)
	focus = m.global_position
	await seq("stop", 1, 0.01)
	# 2 开火后坐（3/4 前视）
	cam_off = Vector3(6.0, 3.2, -6.0)
	raid.aim_override = m.global_position + Vector3(20, 1.5, -20)
	await wait(0.5)
	Input.action_press("fire_right")
	Input.action_press("fire_left")
	await seq("fire", 8, 0.03, m)
	Input.action_release("fire_right")
	Input.action_release("fire_left")
	# 3 冲刺（侧视）
	await wait(0.4)
	cam_off = Vector3(0, 3.0, 11.0)
	Input.action_press("move_left")
	await wait(0.15)
	Input.action_press("dash")
	await seq("dash", 8, 0.05, m)
	Input.action_release("dash")
	Input.action_release("move_left")
	await wait(0.5)
	# 4 受击
	cam_off = Vector3(5, 3, 8)
	focus = m.global_position
	m.take_damage(25.0)
	await seq("hurt", 5, 0.04)
	# 5 虫子
	m.input_locked = true
	m.velocity = Vector3.ZERO
	for k in ["ling", "spitter", "beetle"]:
		var dist := 9.0 if k != "spitter" else 16.0
		var b = raid.spawn_bug(k, m.global_position + Vector3(-dist, 0.3, 0))
		b.state = "chase"
		b.spawn_t = 0.7
		cam_off = Vector3(0, 2.6, 8.0) if k != "beetle" else Vector3(0, 4.0, 11.0)
		await seq(k + "_spawn", 5, 0.15, b)
		await seq(k + "_walk", 8, 0.04, b)
		var t := 0.0
		while is_instance_valid(b) and b.act == "" and t < 5.0:
			focus = b.global_position
			await get_tree().process_frame
			t += get_process_delta_time()
		cam_off = Vector3(4.5, 3.0, 7) if k != "beetle" else Vector3(7, 4.5, 9)
		await seq(k + "_attack", 10, 0.06, b)
		b.take_damage(99999.0)
		await seq(k + "_death", 6, 0.12, b)
		await wait(0.2)
