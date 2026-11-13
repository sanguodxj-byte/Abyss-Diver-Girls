extends "res://tests/lib/test_base.gd"
## 行动内 ESC 暂停面板与设置页：入口、返回、Esc 关闭、暂停状态保持
const START := "none"


func run() -> void:
	await frames(2)
	var raid = await deploy()
	if not check(raid != null, "出击失败"):
		return
	var hud = raid.hud
	hud.toggle_pause()
	await frames(2)
	if not check(hud.pause_panel.visible and get_tree().paused, "暂停面板没有打开"):
		return
	await shot("pause_menu.png")
	hud._open_settings()
	await frames(2)
	if not check(hud.settings_panel.visible and not hud.pause_panel.visible, "设置页没有从暂停面板打开"):
		return
	if not check(get_tree().paused, "打开设置后游戏不应恢复运行"):
		return
	await shot("pause_settings.png")
	for b in hud.settings_panel.find_children("*", "Button", true, false):
		if b is Button and b.text == "声音":
			b.pressed.emit()
			break
	await frames(2)
	await shot("pause_settings_audio.png")
	hud._close_settings()
	await frames(2)
	if not check(hud.pause_panel.visible and not hud.settings_panel.visible, "设置页返回后没有回到暂停面板"):
		return
	# 从设置页按 Esc：先回到暂停面板，游戏保持暂停
	hud._open_settings()
	await frames(2)
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await frames(2)
	if not check(hud.pause_panel.visible and not hud.settings_panel.visible and get_tree().paused, "设置页按 Esc 没有回到暂停面板"):
		return
	# 再按 Esc：关闭暂停并恢复游戏
	var esc2 := InputEventKey.new()
	esc2.physical_keycode = KEY_ESCAPE
	esc2.pressed = true
	Input.parse_input_event(esc2)
	await frames(2)
	if not check(not hud.pause_panel.visible and not get_tree().paused, "Esc 没有关闭暂停面板并恢复游戏"):
		return
	log_line("pause settings ok")
