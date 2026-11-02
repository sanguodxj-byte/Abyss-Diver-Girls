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
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/workspace/work/menu_adg.png")
	print("[menupic] DONE")
	get_tree().quit()
