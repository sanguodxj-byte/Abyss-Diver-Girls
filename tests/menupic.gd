extends Node
## 主菜单截图（不依赖 test_base，Godot 4.4 可跑）：-- --menupic → /workspace/work/menu_adg.png；HIDE_UI=1 时隐藏界面
const START := "menu"
func _ready() -> void:
	await get_tree().create_timer(float(OS.get_environment("WAIT")) if OS.get_environment("WAIT") != "" else 5.0).timeout
	var m = get_parent().menu
	if OS.get_environment("HIDE_UI") == "1":
		for c in m.get_children():
			if c is CanvasItem and not (c is SubViewportContainer):
				c.visible = false
	if OS.get_environment("LANG_T") != "":
		m.title_lang = OS.get_environment("LANG_T")
		m._apply_title_lang()
	if OS.get_environment("GLINT") != "":
		m.t = float(OS.get_environment("GLINT"))
	if OS.get_environment("OPEN") == "start":
		m._open_start()
	if OS.get_environment("OPEN") == "settings":
		m._toggle_settings()
	for _i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "/workspace/work/menu_adg.png")
	print("[menupic] DONE")
	get_tree().quit()
