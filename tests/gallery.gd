extends "res://tests/lib/test_base.gd"
## 模型展示截图：godot --path . -- --gallery [--view=solo0 / explode0 / dead0 / close1 / bug / bugc / bugtop / bling / mant / bbrute] [--dmg=0.75] [--nodecal]
## → review\gallery_<view>.png
const MV = preload("res://scripts/mech_visual.gd")
const A = preload("res://scripts/art.gd")
const BugScript = preload("res://scripts/bug.gd")
const START := "none"

func run() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.28, 0.3, 0.42)
	sky_mat.sky_horizon_color = Color(0.72, 0.52, 0.42)
	sky_mat.ground_bottom_color = Color(0.12, 0.1, 0.1)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 40, 0)
	sun.light_energy = 1.6
	sun.light_color = Color(1.0, 0.9, 0.78)
	sun.shadow_enabled = true
	add_child(sun)
	var g := MeshInstance3D.new()
	g.mesh = A.quad(60, 60)
	g.material_override = A.ground()
	add_child(g)
	var los := [
		{"core":"core_scout","legs":"legs_biped","arm_l":"arm_mg","arm_r":"arm_mg","back":"back_cargo","gen":"gen_cell"},
		{"core":"core_std","legs":"legs_tread","arm_l":"arm_shotgun","arm_r":"arm_laser","back":"back_missile","gen":"gen_reactor"},
		{"core":"core_heavy","legs":"legs_quad","arm_l":"arm_flamer","arm_r":"arm_mg","back":"back_shield","gen":"gen_crystal"},
		{"core":"core_std","legs":"legs_hover","arm_l":"arm_laser","arm_r":"arm_flamer","back":"back_cargo","gen":"gen_crystal"},
	]
	var mode := "mech"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--view="):
			mode = a.substr(7)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dmg="):
			RenderingServer.global_shader_parameter_set("mech_damage", float(a.substr(6)))
	var solo := -1
	var exploded := false
	if mode.begins_with("solo"):
		solo = int(mode.substr(4))
	var dead := false
	if mode.begins_with("dead"):
		solo = int(mode.substr(4))
		dead = true
	if mode.begins_with("explode"):
		solo = int(mode.substr(7))
		exploded = true
	for i in los.size():
		if solo >= 0 and i != solo:
			continue
		if mode == "bugc" or mode == "bugtop" or mode in ["mant", "bling", "bbrute"]:
			continue
		var m := MV.build(los[i])
		if exploded:
			MV.explode(m, 1.0, 0.05)
		if dead:
			get_tree().create_timer(0.3).timeout.connect(func(): MV.scatter(m))
		add_child(m)
		m.position = Vector3(-6.6 + i * 4.4, 0, 0) if solo < 0 else Vector3.ZERO
		m.rotation_degrees.y = 200 if solo < 0 else 185
	var bk := ["ling", "spitter", "beetle"]
	var one := {"bling": 0, "mant": 1, "bbrute": 2}
	if one.has(mode):
		solo = -1
	for i in (3 if solo < 0 else 0):
		if one.has(mode) and i != one[mode]:
			continue
		var b = BugScript.new()
		b.kind = bk[i]
		b.data = BugScript.KINDS[bk[i]]
		add_child(b)
		b.set_physics_process(false)
		b._build_visual()
		b.position = Vector3(-4.5 + i * 4.0, 0, 4.5)
		b.rotation_degrees.y = 160
		if "--nodecal" in OS.get_cmdline_user_args():
			b.visual.get_child(0).visible = false
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 40
	if mode == "bugc":
		cam.fov = 38
		cam.position = Vector3(-2.5, 3.6, 12.5)
		cam.look_at(Vector3(-0.5, 0.7, 4.5))
		sun.rotation_degrees = Vector3(-40, 35, 0)
	if one.has(mode):
		var fz: float = [0.55, 1.0, 1.55][one[mode]]
		for c in get_children():
			if c is BugScript:
				c.position = Vector3(0, 0, 4.5)
				c.rotation_degrees.y = 160
		cam.fov = 30
		cam.position = Vector3(-0.5, 0.9 * fz, 4.5) + (Vector3(2.4, 1.35, 11.6) - Vector3(-0.5, 0.9, 4.5)) * fz
		cam.look_at(Vector3(-0.5, 0.9 * fz, 4.5))
		sun.rotation_degrees = Vector3(-35, 60, 0)
	if mode == "bugtop":
		cam.fov = 30
		cam.position = Vector3(-0.5, 4.5 + 9.0, 4.5 + 4.6)
		cam.look_at(Vector3(-0.5, 0.5, 4.5))
		sun.rotation_degrees = Vector3(-50, 35, 0)
	if mode == "bug":
		cam.position = Vector3(0, 4.5, 10)
		cam.look_at(Vector3(0, 0.6, 4.5))
	if mode.begins_with("close"):
		var idx := int(mode.substr(5)) if mode.length() > 5 else 1
		var target := Vector3(-6.6 + idx * 4.4, 2.0, 0)
		cam.position = target + Vector3(-3.4, 0.6, 3.9)
		sun.rotation_degrees = Vector3(-38, -55, 0)
		cam.look_at(target)
	if solo >= 0:
		cam.fov = 34
		cam.position = Vector3(-3.6, 3.0, 7.4) * (1.25 if exploded else 1.0)
		cam.look_at(Vector3(0, 1.9 if not exploded else 2.3, 0))
		sun.rotation_degrees = Vector3(-38, 30, 0)
	if mode == "mech":
		cam.position = Vector3(0, 9, 14)
		cam.look_at(Vector3(0, 1.6, 0))
	await wait(1.5)
	await shot("gallery_%s.png" % mode)
