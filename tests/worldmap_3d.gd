extends "res://tests/lib/test_base.gd"
## 审图用（不是门禁测试，需要有界面）：逐战区用示例种子 1 真实出击生成（tools/worldmap/export_raid.gd 的 start()，
## 与游戏同一套代码，只把种子固定为 1、不刷虫），换一台正交俯视相机拍整张战区，存 review/wm3d_<战区>.png；
## 同时存这一局的游戏内小地图 review/wm3d_<战区>_mini.png。用于和大地图裁切做对照。
## godot --path . --rendering-driver opengl3 -- --worldmap_3d   （WM_ONLY=战区 id 逗号分隔）

const START := "none"
const TIMEOUT := 600.0
const ExportRaid = preload("res://tools/worldmap/export_raid.gd")
const WorldLink = preload("res://scripts/world_link.gd")
const Factions = preload("res://scripts/factions/factions.gd")


func run() -> void:
	await frames(2)
	if headless():
		log_line("无界面运行：跳过")
		return
	WorldLink.force_open = true
	Factions.rovers_enabled = false
	var only := OS.get_environment("WM_ONLY")
	for mid: String in GameData.map_ids():
		if only != "" and not (mid in only.split(",")):
			continue
		GameData.map_id = mid
		var raid = ExportRaid.new()
		add_child(raid)
		raid.start(GameData.STARTER.duplicate(), [])
		await wait_real(1.5)
		if raid.hud:
			raid.hud.visible = false
		if raid.mech:
			raid.mech.visible = false
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 360.0
		cam.far = 400.0
		raid.add_child(cam)
		cam.global_position = Vector3(0, 200, 0)
		cam.rotation_degrees = Vector3(-90, 0, 0)
		cam.current = true
		# 俯视拍图：关掉雾 / 体积雾，免得天气把地面糊掉
		for c in raid.get_children():
			if c is WorldEnvironment:
				c.environment.fog_enabled = false
				c.environment.volumetric_fog_enabled = false
		await wait_real(1.2)
		await shot("wm3d_%s.png" % mid)
		raid.map_tex.get_image().save_png(ProjectSettings.globalize_path("res://review/wm3d_%s_mini.png" % mid))
		raid.ended = true
		raid.queue_free()
		await wait_real(0.5)
	WorldLink.force_open = false
