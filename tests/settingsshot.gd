extends "res://tests/lib/test_base.gd"
## 设置页截图 → review/settings.png
const START := "menu"

func run() -> void:
	await wait(2.0)
	var m = get_parent().menu
	if m == null:
		fail("没有主菜单")
		return
	m._toggle_settings()
	await wait(0.6)
	await shot("settings.png")
	m._toggle_settings()
	log_line("settingsshot ok")
