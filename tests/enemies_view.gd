extends "res://tests/lib/test_base.gd"
## 模型审阅：把九种新虫与三个 Boss 按真实比例摆在同一块地面上，分别截静止姿态、前摇姿态与 Boss 特写。
## godot --path . -- --enemies_view → review\enemies_lineup.png / enemies_windup.png / enemies_telegraph.png / bosses_lineup.png / boss_<种类>.png / boss_core_<种类>.png
## 无界面运行时不出图，只跑一遍建模与姿态计算，确认没有报错。
const START := "none"
const A = preload("res://scripts/art.gd")
const HAZ = preload("res://scripts/enemies/hazards.gd")

const REGULARS := ["mantis", "bomber", "crystal_bug", "burrower", "mech_beetle", "wasp", "shielder", "mortar", "ironjaw"]
const BOSSES := ["broodmother", "king_beetle", "abyss_queen"]

var cam: Camera3D
var bugs: Array = []


func run() -> void:
	# 剧情演出会盖一层全屏画布并暂停整棵树，审阅截图里不要它
	Story.set_process(false)
	Story.data = {}
	await frames(1)
	_rig()
	var kinds := await _spawn_row(REGULARS, 2.4, 0.0)
	await wait(1.2)
	_clear_overlays()
	await shot("enemies_lineup.png")
	# 前摇姿态：把每只的行为状态推到蓄力段，跑几十帧把姿态收敛到前摇
	for i in kinds.size():
		var b = kinds[i]
		if not is_instance_valid(b):
			continue
		b.act = "wind"
		b.act_t = 0.4
		b.focus = 0.85
		for k in 40:
			b._animate(0.05, 0.55)
	await wait(0.3)
	_clear_overlays()
	await shot("enemies_windup.png")
	_free_row(kinds)
	await frames(2)
	# 逐只特写：单只摆在原点，机位按种类与体型取
	for kind: String in REGULARS + BOSSES:
		var one := _spawn_row([kind], 0.0, 0.0)
		if one.is_empty():
			continue
		var b = one[0]
		_fit(b)
		await wait(0.5)
		_clear_overlays()
		await shot("enemy_%s.png" % kind)
		_free_row(one)
		await frames(2)
	var bosses := await _spawn_row(BOSSES, 7.2, 0.0)
	cam.position = Vector3(0, 9.5, 24.0)
	cam.look_at(Vector3(0, 2.2, -1.0))
	await wait(1.0)
	_clear_overlays()
	await shot("bosses_lineup.png")
	for i in bosses.size():
		var b = bosses[i]
		if not is_instance_valid(b):
			continue
		b.visible = true
		for j in bosses.size():
			if j != i and is_instance_valid(bosses[j]):
				bosses[j].visible = false
		var sc: float = float(b.data.scale)
		cam.position = Vector3(0, 3.4 * sc, 7.4 * sc)
		cam.look_at(Vector3(0, 1.7 * sc, 0))
		# 先跑几帧程序动画，把护板、翅与足收到静止姿态，截到的才是游戏里的常态
		for k in 12:
			b._animate(0.06, 0.0)
		await wait(0.3)
		_clear_overlays()
		await shot("boss_%s.png" % str(b.kind))
		# 晶核暴露：护板张开、核心辉光抬升的样子
		if str(b.kind) in ["king_beetle", "abyss_queen"]:
			b.open_core(60.0)
			for k in 24:
				b._animate(0.06, 0.0)
			await wait(0.2)
			_clear_overlays()
			await shot("boss_core_%s.png" % str(b.kind))
			b.core_open = 0.0
			b.core_vis = 0.0
			for k in 24:
				b._animate(0.06, 0.0)
	for j in bosses.size():
		if is_instance_valid(bosses[j]):
			bosses[j].visible = true
	_free_row(bosses)
	await frames(2)
	# 前摇预告：冲锋带与范围环各一条，贴地摆开
	var lane := HAZ.Telegraph.new()
	add_child(lane)
	lane.setup_lane(self, Vector3(-9.5, 0.02, 8.0), Vector3(0.95, 0, -0.55).normalized(), 2.6, 14.0, 4.0, Color(1.0, 0.48, 0.16))
	var ring := HAZ.Telegraph.new()
	add_child(ring)
	ring.setup_ring(self, Vector3(5.0, 0.02, 5.5), 3.0, 4.0, Color(0.4, 1.0, 0.72))
	cam.position = Vector3(0, 13.5, 18.5)
	cam.look_at(Vector3(0, 0.0, 4.0))
	await wait(0.35)
	_clear_overlays()
	await shot("enemies_telegraph.png")
	lane.queue_free()
	ring.queue_free()
	log_line("model rows ok: %d + %d" % [REGULARS.size(), BOSSES.size()])


## 单人特写的机位：距离 / 高度 / 视点高度，都乘上该种类的体型倍数
func _fit(b) -> void:
	var kind := str(b.kind)
	var sc := float(b.data.get("scale", 1.0))
	var f := [4.4, 2.0, 1.0]
	match kind:
		"mantis": f = [4.2, 1.9, 0.95]
		"bomber": f = [4.6, 2.0, 1.0]
		"crystal_bug": f = [5.6, 2.5, 1.15]
		"burrower": f = [4.6, 2.0, 1.0]
		"mech_beetle": f = [6.0, 2.7, 1.25]
		"wasp": f = [4.4, 1.15, 0.7]
		"shielder": f = [4.4, 2.1, 1.15]
		"mortar": f = [5.4, 2.2, 1.5]
		"ironjaw": f = [6.2, 2.9, 1.35]
		"broodmother": f = [6.4, 3.0, 1.15]
		"king_beetle": f = [5.8, 2.5, 1.15]
		"abyss_queen": f = [7.0, 2.6, 1.75]
	cam.position = Vector3(0, float(f[1]) * sc, float(f[0]) * sc)
	cam.look_at(Vector3(0, float(f[2]) * sc, 0))


## 藏掉根节点上的界面层，截出来的只有模型
func _clear_overlays() -> void:
	get_tree().paused = false
	for c in get_tree().root.get_children():
		if c is CanvasLayer or c is Control:
			c.visible = false


## 灯光与地面：和游戏内一样的暖色逆光 + 冷色补光，方便判断轮廓与发光件
func _rig() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.24, 0.26, 0.36)
	sky_mat.sky_horizon_color = Color(0.68, 0.5, 0.42)
	sky_mat.ground_bottom_color = Color(0.1, 0.09, 0.09)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.05
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 36, 0)
	sun.light_energy = 1.7
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.shadow_enabled = true
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-24, -150, 0)
	rim.light_energy = 0.5
	rim.light_color = Color(0.55, 0.65, 0.95)
	add_child(rim)
	var g := MeshInstance3D.new()
	g.mesh = A.quad(90, 90)
	g.material_override = A.ground()
	add_child(g)
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 34.0
	cam.position = Vector3(0, 7.0, 19.5)
	cam.look_at(Vector3(0, 1.2, 0))


## 把一串敌种按等距摆成一行；每个都是真实行为脚本 + 真实建模，物理关掉只留外观
func _spawn_row(list: Array, spacing: float, z: float) -> Array:
	var out: Array = []
	var n := list.size()
	for i in n:
		var kind: String = list[i]
		var info: Dictionary = GameData.ENEMIES.get(kind, {})
		var s: Script = load(str(info.get("script", "")))
		if s == null:
			continue
		var b = s.new()
		add_child(b)
		b.kind = kind
		b.data = info
		b.ai = str(info.get("ai", "lancer"))
		b.hover = float(info.get("hover", 0.0))
		b.set_physics_process(false)
		b._build_visual()
		b.position = Vector3((i - (n - 1) * 0.5) * spacing, 0, z)
		b.rotation_degrees.y = 168.0
		bugs.append(b)
		out.append(b)
	return out


func _free_row(list: Array) -> void:
	for b in list:
		if is_instance_valid(b):
			b.queue_free()
