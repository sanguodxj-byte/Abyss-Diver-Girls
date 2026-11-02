extends "res://tests/lib/test_base.gd"
## 新增模块整机预览：三套含新模型的装配并排截图 → review\modshow.png
const MV = preload("res://scripts/mech_visual.gd")
const A = preload("res://scripts/art.gd")
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
	var looks := [
		{"core": "core_fortress", "legs": "legs_titan", "arm_l": "arm_ac30", "arm_r": "arm_cannon", "back": "back_vls", "gen": "gen_turbine"},
		{"core": "core_assault", "legs": "legs_quad", "arm_l": "arm_gatling", "arm_r": "arm_rail", "back": "back_rocket", "gen": "gen_hfc"},
		{"core": "core_command", "legs": "legs_hover", "arm_l": "arm_hmg", "arm_r": "arm_slug", "back": "back_rack", "gen": "gen_diesel"},
	]
	for i in looks.size():
		var m: Node3D = MV.build(looks[i], true)
		add_child(m)
		m.position = Vector3(-5.4 + i * 5.4, 0, 0)
		m.rotation_degrees.y = 200
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 38
	cam.position = Vector3(0, 4.2, 12.5)
	cam.look_at(Vector3(0, 1.9, 0))
	await wait(1.6)
	await shot("modshow.png")
	log_line("modshow ok")
