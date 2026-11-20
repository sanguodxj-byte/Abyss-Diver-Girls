extends "res://tests/lib/test_base.gd"
## 低面数整改批次 1 对比截图：godot --path . -- --lowpoly_batch1
## → review/lp1_<name>.png（左：旧模型复刻，右：新模型）
const A = preload("res://scripts/art.gd")
const DM = preload("res://scripts/modules/device_models.gd")
const HZ = preload("res://scripts/enemies/hazards.gd")
const START := "none"
const TIMEOUT := 240.0

var cam: Camera3D


func run() -> void:
	get_window().size = Vector2i(1280, 720)
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.30, 0.34, 0.44)
	sky_mat.sky_horizon_color = Color(0.70, 0.60, 0.50)
	sky_mat.ground_bottom_color = Color(0.12, 0.1, 0.1)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 35, 0)
	sun.light_energy = 1.7
	sun.light_color = Color(1.0, 0.92, 0.80)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	var g := MeshInstance3D.new()
	g.mesh = A.quad(1000, 1000)
	g.material_override = A.ground()
	add_child(g)
	cam = Camera3D.new()
	cam.fov = 38.0
	add_child(cam)
	cam.make_current()

	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)

	# ---- 1 撤离屏障（单桩特写 + 整体）
	var z := 0.0
	var old_b := _at(Vector3(-1.1, 0, z))
	_old_barrier_post(old_b)
	var new_b := _at(Vector3(1.1, 0, z))
	DM.build_barrier_post(new_b, Color(0.45, 0.95, 0.8))
	_label(Vector3(-1.1, 2.2, z), "BEFORE")
	_label(Vector3(1.1, 2.2, z), "AFTER")
	if only == "" or only == "barrier":
		await _shoot("lp1_1_barrier_post.png", Vector3(0, 1.35, z + 4.6), Vector3(0, 0.85, z))
	# 整体部署（真实逻辑脚本，半径 3）
	var bar = load("res://scripts/modules/extract_barrier.gd").new()
	bar.setup(null, 3.0, 9999.0)
	bar.position = Vector3(0, 0, z + 40.0)
	add_child(bar)
	if only == "" or only == "barrier":
		await _shoot("lp1_1b_barrier_field.png", Vector3(0, 4.2, z + 48.5), Vector3(0, 0.6, z + 40.0))

	# ---- 2 声波诱饵
	z = 80.0
	var od := _at(Vector3(-1.2, 0, z))
	_old_decoy(od)
	var dec = load("res://scripts/modules/decoy_beacon.gd").new()
	dec.setup(null)
	dec.position = Vector3(1.2, 0, z)
	dec.rotation_degrees.y = 200.0
	add_child(dec)
	dec.set_process(false)
	_label(Vector3(-1.2, 2.3, z), "BEFORE")
	_label(Vector3(1.2, 2.3, z), "AFTER")
	if only == "" or only == "decoy":
		await _shoot("lp1_2_decoy.png", Vector3(0.3, 1.6, z + 5.0), Vector3(0, 0.9, z))

	# ---- 3 阻拦网
	z = 160.0
	var ow := _at(Vector3(-5.0, 0, z))
	_old_web(ow, 4.2)
	var web = load("res://scripts/modules/slow_web.gd").new()
	web.setup(null, 4.2, 9999.0)
	web.position = Vector3(5.0, 0, z)
	add_child(web)
	_label(Vector3(-5.0, 1.6, z), "BEFORE")
	_label(Vector3(5.0, 1.6, z), "AFTER")
	if only == "" or only == "web":
		await wait_real(0.6)
		await _shoot("lp1_3_web.png", Vector3(0, 7.5, z + 12.0), Vector3(0, 0, z + 0.5))
		await _shoot("lp1_3b_web_close.png", Vector3(5.0, 1.9, z + 3.2), Vector3(5.0, 0.3, z))

	# ---- 4 首领地刺
	z = 240.0
	var os_ := _at(Vector3(-1.6, 0, z))
	_old_spike(os_, 2.9)
	var ns := _at(Vector3(1.6, 0, z))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	DM.build_spike(ns, 2.9, Color(0.75, 0.35, 1.0), rng)
	_label(Vector3(-1.6, 3.6, z), "BEFORE")
	_label(Vector3(1.6, 3.6, z), "AFTER")
	if only == "" or only == "spike":
		await _shoot("lp1_4_spike.png", Vector3(0, 2.3, z + 7.2), Vector3(0, 1.4, z))

	# ---- 5 首领齐射火箭弹（放大 3 倍便于对比，横置）
	z = 320.0
	var orr := _at(Vector3(0, 1.5, z), Vector3(0, 0, 90), 3.0)
	orr.position = Vector3(0, 2.4, z)
	_old_rocket(orr)
	var nr := _at(Vector3(0, 0.9, z), Vector3(0, 0, 90), 3.0)
	DM.build_salvo_rocket(nr)
	_label(Vector3(2.9, 2.4, z), "BEFORE")
	_label(Vector3(2.9, 0.9, z), "AFTER")
	if only == "" or only == "rocket":
		await _shoot("lp1_5_rocket.png", Vector3(0.4, 2.0, z + 5.6), Vector3(0, 1.6, z))
		await _shoot("lp1_5b_rocket_tail.png", Vector3(1.9, 1.4, z + 1.6), Vector3(1.2, 0.9, z))


func _at(pos: Vector3, rot := Vector3.ZERO, s := 1.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = rot
	n.scale = Vector3.ONE * s
	add_child(n)
	return n


func _label(pos: Vector3, t: String) -> void:
	var l := Label3D.new()
	l.text = t
	l.font_size = 64
	l.pixel_size = 0.004
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	l.modulate = Color(1, 0.95, 0.8) if t == "AFTER" else Color(0.85, 0.85, 0.9)
	add_child(l)


func _shoot(file: String, eye: Vector3, at: Vector3) -> void:
	cam.position = eye
	cam.look_at(at, Vector3.UP)
	await wait_real(0.5)
	await shot(file)
	log_line("shot " + file)


# ---------------------------------------------------------------- 旧模型复刻（整改前代码原样）
func _old_barrier_post(p: Node3D) -> void:
	var FIELD := Color(0.45, 0.95, 0.8)
	A.add(p, A.bevel_box(Vector3(0.14, 1.42, 0.14), 0.02), A.metal(Color(0.20, 0.22, 0.22)), Vector3(0, 0.71, 0))
	A.add(p, A.bevel_box(Vector3(0.22, 0.16, 0.22), 0.02), A.metal(Color(0.14, 0.15, 0.16)), Vector3(0, 1.48, 0))
	A.add(p, A.bevel_box(Vector3(0.08, 0.18, 0.08), 0.01), A.emit(FIELD.darkened(0.15), 1.6), Vector3(0, 1.56, 0), Vector3.ZERO, Vector3.ONE, false)


func _old_decoy(p: Node3D) -> void:
	var LURE := Color(1.0, 0.72, 0.22)
	var m := A.metal(Color(0.24, 0.25, 0.27))
	for i in 3:
		var a := TAU * i / 3.0
		A.add(p, A.bevel_box(Vector3(0.07, 0.8, 0.07), 0.02), m, Vector3(cos(a) * 0.26, 0.4, sin(a) * 0.26), Vector3(sin(a) * 16.0, 0, -cos(a) * 16.0))
	A.add(p, A.cyl(0.16, 0.24, 0.2, 14), m, Vector3(0, 0.86, 0))
	A.add(p, A.cyl(0.34, 0.32, 0.1, 18), A.metal(Color(0.32, 0.33, 0.36)), Vector3(0, 1.12, 0))
	A.add(p, A.cyl(0.02, 0.6, 0.02, 6), m, Vector3(0.18, 1.5, 0))
	A.add(p, A.cyl(0.055, 0.11, 0.055, 10), A.emit(LURE, 2.6), Vector3(0.18, 1.82, 0), Vector3.ZERO, Vector3.ONE, false)


func _old_web(p: Node3D, radius: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	A.ground_vfx(p, A.grime_stain_tex(), Color(0.42, 0.78, 0.74, 0.46), radius * 2.15, Vector3(0, 0.122, 0), false, 0.44, false, 3)
	var m := A.emit(Color(0.52, 0.92, 0.88), 1.6)
	var tips: Array = []
	for i in 11:
		var a := TAU * float(i) / 11.0 + rng.randf_range(-0.22, 0.22)
		var r_len := radius * rng.randf_range(0.68, 1.04)
		var tip := Vector3(cos(a) * r_len, 0.10 + rng.randf() * 0.08, sin(a) * r_len)
		tips.append(tip)
		var mid := tip * rng.randf_range(0.38, 0.56) + Vector3(rng.randf_range(-0.25, 0.25), 0.18 + rng.randf() * 0.10, rng.randf_range(-0.25, 0.25))
		A.add(p, A.tube([Vector3(0, 0.10, 0), mid, tip], 0.036, 5, 5), m, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	for i in tips.size():
		if i % 2 == 0:
			var a_pt: Vector3 = (tips[i] as Vector3) * 0.62
			var b_pt: Vector3 = (tips[(i + 1) % tips.size()] as Vector3) * 0.58
			A.add(p, A.tube([a_pt, (a_pt + b_pt) * 0.5 + Vector3(0, 0.08, 0), b_pt], 0.024, 4, 4), m, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)


func _old_spike(p: Node3D, h: float) -> void:
	var color := Color(0.75, 0.35, 1.0)
	var m_jkt := A.metal(Color(0.24, 0.26, 0.29))
	var m_tip := A.emit(color, 1.5)
	A.add(p, A.cyl(0.30, h * 0.54, 0.44, 6), m_jkt, Vector3(0, h * 0.27, 0))
	A.add(p, A.cyl(0.04, h * 0.52, 0.28, 6), m_tip, Vector3(0, h * 0.74, 0))


func _old_rocket(body: Node3D) -> void:
	var m_st := A.metal(Color(0.20, 0.22, 0.24))
	var m_olive := A.paint(Color(0.28, 0.31, 0.24), 0.45, 0.52, {"rust": 0.42, "wear": 0.35})
	var m_haz := A.hazard()
	var m_brass := A.paint(Color(0.86, 0.66, 0.22), 0.88, 0.26, {"panel_scale": 0.0})
	var m_flame := A.emit(Color(1.0, 0.55, 0.16), 2.1)
	A.add(body, A.cyl(0.11, 0.72, 0.12, 12), m_olive, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(body, A.cyl(0.035, 0.28, 0.11, 12), m_st, Vector3(0, 0.50, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(body, A.cyl(0.016, 0.09, 0.035, 10), m_brass, Vector3(0, 0.68, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(body, A.cyl(0.125, 0.08, 0.125, 12), m_haz, Vector3(0, 0.20, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(body, A.cyl(0.09, 0.14, 0.065, 10), m_st, Vector3(0, -0.42, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(body, A.cyl(0.055, 0.10, 0.025, 8), m_flame, Vector3(0, -0.52, 0), Vector3.ZERO, Vector3.ONE, false)
	for i in 4:
		var a := TAU * float(i) / 4.0
		A.add(body, A.bevel_box(Vector3(0.026, 0.24, 0.16), 0.005), m_st, Vector3(sin(a) * 0.13, -0.32, cos(a) * 0.13), Vector3(0, rad_to_deg(a), 0), Vector3.ONE, false)
