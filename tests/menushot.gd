extends "res://tests/lib/test_base.gd"
## 主菜单与地图俯瞰截图：godot --path . -- --menushot → review\menushot_menu.png / menushot_play.png / menushot_top.png / menushot_mid.png
const START := "menu"

func run() -> void:
	await wait(4.0)
	await shot("menushot_menu.png")
	for child in main.menu.get_children():
		if child is VBoxContainer:
			child.visible = false
	await frames(4)
	await shot("menushot_clean_bg.png")
	for child in main.menu.get_children():
		if child is VBoxContainer:
			child.visible = true
	main.menu.start_requested.emit()
	await wait(1.0)
	var raid = await deploy()
	if not check(raid != null, "出击失败"):
		return
	await wait(1.5)
	await shot("menushot_play.png")
	var cam := Camera3D.new()
	raid.add_child(cam)
	cam.far = 1500
	cam.fov = 48
	cam.global_position = Vector3(0, 440, 0.01)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	cam.current = true
	raid.hud.visible = false
	await frames(8)
	await shot("menushot_top.png")
	cam.global_position = Vector3(-10, 75, 50)
	cam.fov = 40
	cam.look_at(Vector3(-10, 0, 0), Vector3.UP)
	await frames(8)
	await shot("menushot_mid.png")
	cam.current = false
	raid.hud.visible = true
	await frames(30)
	log_line("fps=%d nodes=%d draws=%d" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
