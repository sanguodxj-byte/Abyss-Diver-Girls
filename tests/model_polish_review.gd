extends "res://tests/lib/test_base.gd"
## 核对近景模型和远景建筑轮廓。有图形界面时额外输出同机位预览。
## godot --headless --path . -- --model_polish_review

const START := "none"
const A = preload("res://scripts/art.gd")
const HS = preload("res://scripts/hs.gd")
const Raid = preload("res://scripts/raid.gd")
const Landmarks = preload("res://scripts/map_ext/landmarks.gd")
const BossLandmarks = preload("res://scripts/map_ext/landmarks_boss.gd")
const MapEvents = preload("res://scripts/map_ext/events.gd")
const Nest = preload("res://scripts/nest.gd")


func run() -> void:
	var raid := Raid.new()
	raid.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(raid)
	raid.world = Node3D.new()
	raid.add_child(raid.world)
	raid.rng.seed = 8

	Landmarks._coolant_channel(raid, Vector3.ZERO, 0.0)
	var canal := raid.world.get_node("CoolingCanal") as Node3D
	if not check(raid.blocks.size() == 4, "冷却渠的两侧通行缺口与挡墙数发生变化"):
		return
	var canal_meshes := canal.find_children("*", "MeshInstance3D", true, false)
	for part: MeshInstance3D in canal_meshes:
		if not check(part.mesh.get_aabb().size.z < 8.0, "冷却渠仍含单片通长底板或墙体"):
			return
	log_line("cooling canal pieces=%d collision sections=%d" % [canal_meshes.size(), raid.blocks.size()])

	var size := Vector3(3.6, 4.5, 7.6)
	raid._building(Vector3.ZERO, size)
	var narrow := raid.world.get_child(raid.world.get_child_count() - 1) as StaticBody3D
	var shape := (narrow.get_child(0) as CollisionShape3D).shape as BoxShape3D
	if not check(shape.size.is_equal_approx(Vector3(size.x, 5.0, size.z)), "窄楼碰撞占地或原高度规则发生变化"):
		return
	var narrow_meshes: Array[Dictionary] = []
	for key in raid._inst:
		var entry: Dictionary = raid._inst[key]
		for i in entry.own.size():
			if entry.own[i] == narrow:
				narrow_meshes.append({"mesh": entry.mesh, "mat": entry.mat, "xf": entry.xf[i]})
	if not check(narrow.has_meta("occ_vis_aabb") and narrow_meshes.size() > 3, "窄楼未接入带立面结构的预制件"):
		return
	log_line("narrow building combined surfaces=%d" % narrow_meshes.size())

	var far_mesh := HS.distant_building_mesh()
	var far_centered := HS.distant_building_mesh(true)
	if not check(far_mesh.get_faces().size() == 28 * 3, "远景建筑网格应保持 28 个三角面"):
		return
	if not check(far_centered.get_aabb().position.y >= -0.001 and far_centered.get_aabb().size.is_equal_approx(Vector3.ONE), "远景体块接地或尺寸错误"):
		return

	var fragments: Array[Mesh] = [
		raid._casing_mesh(true, false), raid._casing_mesh(true, true), raid._debris_mesh("metal"),
		raid._debris_mesh("chitin"), raid._debris_mesh("rock"), raid._sabot_petal_mesh(),
	]
	for mesh in fragments:
		var mat := mesh.surface_get_material(0) as StandardMaterial3D
		if not check(mat != null and mat.albedo_texture != null, "弹壳或碎屑缺少表面贴图"):
			return

	var nest := Nest.new()
	raid.add_child(nest)
	nest.setup(raid)
	nest.hide()
	var cargo := MapEvents._build_wreck_visual()
	raid.add_child(cargo)
	cargo.hide()
	var terrain := raid.world
	raid.world = Node3D.new()
	raid.add_child(raid.world)
	BossLandmarks._spillway_dam(raid, Vector3(-22, 0, 0), 0.0)
	BossLandmarks._bucket_excavator(raid, Vector3(17, 0, 0), 42.0)
	var industry := raid.world
	industry.hide()

	raid.world = Node3D.new()
	raid.add_child(raid.world)
	raid._inst.clear()
	var wagon_seeds := [2, 0] # 分别生成罐车与敞车。
	for i in wagon_seeds.size():
		var x := -2.8 + i * 5.6
		raid.rail_polys.append(PackedVector2Array([Vector2(x, -12), Vector2(x, 12)]))
		raid.rng.seed = wagon_seeds[i]
		raid._wagon(Vector3(x, 0, 0), false)
	raid._build_rails()
	raid._bake_static(Vector3.ZERO)
	var rails := raid.world
	rails.hide()

	raid.world = Node3D.new()
	raid.add_child(raid.world)
	Landmarks._boardwalk(raid, Vector3(-12, 0, 0), 0.0)
	Landmarks._rope_bridge(raid, Vector3(10, 0, 0), 22.0)
	var bridges := raid.world
	bridges.hide()
	if headless():
		return

	var cam := _preview_camera(raid)
	var ground := A.add(raid, A.quad(100, 100), A.rock_mat(Color(0.26, 0.23, 0.25)), Vector3(0, -0.02, 0))
	cam.size = 77
	cam.position = Vector3(31, 70, 48)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	await frames(4)
	await shot("polished_coolant_channel.png")

	terrain.hide()
	var house := Node3D.new()
	raid.add_child(house)
	for entry in narrow_meshes:
		var mi := MeshInstance3D.new()
		mi.mesh = entry.mesh
		mi.material_override = entry.mat
		mi.transform = entry.xf
		house.add_child(mi)
	ground.material_override = A.gravel_mat(Color(0.38, 0.34, 0.28))
	cam.size = 13
	cam.position = Vector3(10, 12, 14)
	cam.look_at(Vector3(0, 1.8, 0), Vector3.UP)
	await frames(4)
	await shot("polished_narrow_building.png")

	house.hide()
	nest.position.x = -4.4
	nest.show()
	cargo.position.x = 4.1
	cargo.rotation_degrees.y = 162
	cargo.show()
	cam.size = 16
	cam.position = Vector3(2.1, 11.0, 15.0)
	cam.look_at(Vector3(0, 1.1, 0), Vector3.UP)
	await frames(4)
	await shot("polished_nest_and_cargo.png")

	nest.hide()
	cargo.hide()
	industry.show()
	cam.size = 77
	cam.position = Vector3(8, 58, 57)
	cam.look_at(Vector3(-3, 4, -3), Vector3.UP)
	await frames(4)
	await shot("polished_industrial_landmarks.png")

	industry.hide()
	rails.show()
	cam.size = 20
	cam.position = Vector3(16, 20, 10)
	cam.look_at(Vector3(0, 0.9, 0), Vector3.UP)
	await frames(3)
	await shot("polished_railway.png")

	rails.hide()
	bridges.show()
	cam.size = 58
	cam.position = Vector3(12, 31, 18)
	cam.look_at(Vector3(0, 1.4, 0), Vector3.UP)
	await frames(3)
	await shot("polished_walkways.png")

	bridges.hide()
	for i in fragments.size():
		var rotation := Vector3(60, 21, -27)
		if i < 2:
			rotation.y = -69
		elif i == fragments.size() - 1:
			rotation = Vector3(35, -26, 8)
		A.add(raid, fragments[i], null, Vector3(-3.75 + i * 1.5, 0.65, 0), rotation, Vector3.ONE * 11.0)
	cam.size = 9.2
	cam.position = Vector3(0.5, 3.1, 6.2)
	cam.look_at(Vector3(0, 0.55, 0), Vector3.UP)
	await frames(4)
	await shot("polished_fragments.png")


func _preview_camera(raid: Node3D) -> Camera3D:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.18, 0.20, 0.24)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.78, 0.85, 1.0)
	env.environment.ambient_light_energy = 0.55
	raid.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -28, 0)
	sun.light_energy = 1.65
	sun.shadow_enabled = true
	raid.add_child(sun)
	var cam := Camera3D.new()
	raid.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.make_current()
	return cam
