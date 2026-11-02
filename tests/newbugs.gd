extends "res://tests/lib/test_base.gd"
## 新增虫种外观：六种新虫并排渲染 → review\newbugs.png
const BugScript = preload("res://scripts/bug.gd")
const A = preload("res://scripts/art.gd")
const START := "none"

const KINDS := ["aegis", "lancer", "overseer", "ripper", "brood", "colossus"]


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
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 36, 0)
	sun.light_energy = 1.7
	sun.light_color = Color(1.0, 0.9, 0.78)
	sun.shadow_enabled = true
	add_child(sun)
	var g := MeshInstance3D.new()
	g.mesh = A.quad(60, 60)
	g.material_override = A.ground()
	add_child(g)
	for i in KINDS.size():
		var b = BugScript.new()
		b.kind = KINDS[i]
		b.data = GameData.ENEMIES[KINDS[i]]
		add_child(b)
		b.set_physics_process(false)
		b._build_visual()
		b.position = Vector3(-9.0 + (i % 3) * 9.0, 0, -5.0 + (i / 3) * 10.0)
		b.rotation_degrees.y = 160
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 38
	cam.position = Vector3(0, 12.5, 27.0)
	cam.look_at(Vector3(0, 1.6, 0))
	await wait(1.2)
	await shot("newbugs.png")
	log_line("newbugs ok")
