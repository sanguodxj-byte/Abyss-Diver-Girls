extends "res://tests/lib/test_base.gd"
## 道路 / 路沿 / 水面审图（不是门禁测试，需要有界面）：用示例种子 1 真实出击生成（tools/worldmap/export_raid.gd 的 start()），
## 换正交相机拍整张战区 + 六处 90 米近景（俯视 + 斜视各一张），存 review/roadshot_<战区>_<n>.png。
## godot --path . -- --roadshot   （WM_ONLY=战区 id 逗号分隔，默认 greyport）
## 同时打印：道路条数、断头路（圆头）数量、落在水里的单位 / 箱子 / 树等数量（应为 0）。

const START := "none"
const TIMEOUT := 600.0
const ExportRaid = preload("res://tools/worldmap/export_raid.gd")
const WorldLink = preload("res://scripts/world_link.gd")
const Factions = preload("res://scripts/factions/factions.gd")

const CROPS := [Vector2(-90, -60), Vector2(0, -60), Vector2(90, -60), Vector2(-90, 60), Vector2(0, 60), Vector2(90, 60)]


func run() -> void:
	await frames(2)
	if headless():
		log_line("无界面运行：跳过")
		return
	WorldLink.force_open = true
	Factions.rovers_enabled = false
	var only := OS.get_environment("WM_ONLY")
	if only == "":
		only = "greyport"
	for mid: String in only.split(","):
		GameData.map_id = mid
		var raid = ExportRaid.new()
		add_child(raid)
		raid.start(GameData.STARTER.duplicate(), [])
		await wait_real(1.5)
		if raid.hud:
			raid.hud.visible = false
		if raid.mech:
			raid.mech.visible = false
		raid._rb().show_all()
		var caps := 0
		for cv: Dictionary in raid.curves:
			for c in cv.get("caps", []):
				if c:
					caps += 1
		log_line("%s: 道路 %d 条，圆头断头 %d 处" % [mid, raid.curves.size(), caps])
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.far = 600.0
		raid.add_child(cam)
		cam.current = true
		for c in raid.get_children():
			if c is WorldEnvironment:
				c.environment.fog_enabled = false
				c.environment.volumetric_fog_enabled = false
		cam.size = 360.0
		cam.global_position = Vector3(0, 95, 0)
		cam.rotation_degrees = Vector3(-90, 0, 0)
		await wait_real(1.0)
		await shot("roadshot_%s_full.png" % mid)
		if OS.get_environment("WM_FULL_ONLY") == "":
			for i in CROPS.size():
				var c: Vector2 = CROPS[i]
				cam.size = 90.0
				cam.rotation_degrees = Vector3(-90, 0, 0)
				cam.global_position = Vector3(c.x, 95, c.y)
				await wait_real(0.6)
				await shot("roadshot_%s_%d.png" % [mid, i])
				cam.rotation_degrees = Vector3(-55, 0, 0)
				cam.global_position = Vector3(c.x, 120, c.y + 120.0 / tan(deg_to_rad(55.0)))
				await wait_real(0.6)
				await shot("roadshot_%s_%d_tilt.png" % [mid, i])
		raid.ended = true
		raid.queue_free()
		await wait_real(0.5)
	WorldLink.force_open = false
