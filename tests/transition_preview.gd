extends "res://tests/lib/test_base.gd"

const START := "menu"
const TIMEOUT := 360.0

var assertions := 0
var clicks := 0
var chrome: Array = []


func run() -> void:
	seed(472)
	if not _expect(GameData.test_mode, "test saves are not isolated"):
		return
	await frames(30)
	await shot("transition_01_title.png")
	var old_menu: WeakRef = weakref(main.menu)
	await _click(main.menu.buttons[0])
	if not _expect(main.menu.slots_panel.visible, "new-game click did not open save slots"):
		return
	await frames(8)
	await _click(main.menu.slot_cards[1].btn)
	if not _expect(main.menu.start_panel.visible, "save-slot click did not open registration"):
		return
	await frames(8)
	await _click(_button(main.menu.start_panel, Loc.t("启程", "Launch")))
	if not _expect(main.hub != null and main.menu == null, "registration did not enter hub"):
		return
	if not _expect(is_equal_approx(main.hub.modulate.a, 1.0), "screen root fades the hatch at handoff"):
		return
	await frames(10)
	if not _motion_active(main.hub, "hatch"):
		return
	await shot("transition_hatch_check.png")
	await frames(22)
	if not _expect(old_menu.get_ref() == null, "outgoing title was not freed"):
		return
	if not _expect(main.hub.process_mode == Node.PROCESS_MODE_INHERIT, "hub process mode was not restored"):
		return
	chrome = _chrome(main.hub)
	if not _chrome_unchanged(main.hub):
		return
	await shot("transition_02_hub.png")
	await frames(22)
	for key: String in ["trade", "skills", "stash", "deploy", "codex", "maintenance"]:
		if not await _tab(key):
			return
	await _click(main.hub.nav_buttons.deploy)
	await frames(22)
	await _click(main.hub.step_btns[1])
	await frames(8)
	if not _motion_active(main.hub.deploy_pages[1], "panels"):
		return
	await frames(22)
	if not _deploy_settled(2):
		return
	await shot("transition_05_deploy_loadout.png")
	await frames(26)
	await _click(main.hub.step_btns[0])
	await frames(22)
	if not _deploy_settled(1):
		return
	await frames(26)
	await _click(main.hub.step_btns[1])
	await frames(1)
	await _click(main.hub.step_btns[0])
	await _click(main.hub.nav_buttons.trade)
	await _click(main.hub.nav_buttons.stash)
	await _click(main.hub.nav_buttons.maintenance)
	await _click(main.hub.nav_buttons.maintenance)
	await frames(22)
	if not _hub_settled("maintenance") or not _chrome_unchanged(main.hub):
		return
	if not _expect(main.hub._deploy_tweens.is_empty() and main.hub._deploy_modes.is_empty(), "nested deployment transitions did not finish"):
		return
	log_line("rapid tabs, repeated tab, nested deployment: checked")
	await _click(_button(main.hub, Loc.t("设置", "Settings")))
	await frames(4)
	if not main.hub._settings_is_open():
		await shot("transition_settings_failure.png")
	if not _expect(main.hub._settings_is_open(), "settings did not open after rapid tabs"):
		return
	await frames(24)
	await _click(_button(main.hub._settings_overlay, Loc.t("关闭", "Close")))
	await frames(24)
	if not _expect(not main.hub._settings_is_open(), "settings close button did not recover input"):
		return
	await _click(_button(main.hub, Loc.t("设置", "Settings")))
	await frames(24)
	var old_hub: WeakRef = weakref(main.hub)
	await _click(_button(main.hub._settings_overlay, Loc.t("返回主菜单", "Main Menu")))
	await frames(26)
	if not _expect(main.menu != null and main.hub == null and old_hub.get_ref() == null, "hub-to-title did not free the settings overlay"):
		return
	await _click(main.menu.buttons[2])
	await frames(2)
	if not _expect(main.menu.settings_panel.visible, "returned title does not accept settings input"):
		return
	_key(KEY_ESCAPE)
	await frames(2)
	if not _expect(not main.menu.settings_panel.visible and not main.menu.shade.visible, "Escape did not dismiss title settings"):
		return
	await frames(26)
	await _click(main.menu.buttons[1])
	await frames(4)
	await _click(main.menu.slot_cards[1].btn)
	await frames(26)
	if not _expect(main.hub != null and main.menu == null, "saved-game input did not return to hub"):
		return
	await frames(15)
	log_line("result screen uses a UI fixture; no completed raid is claimed")
	main._show_result({"success": true, "cargo": [], "loadout": {}, "time": 0, "kills": 0})
	var result: Node = main.result_layer
	await frames(2)
	if not _motion_active(result, "result"):
		return
	await frames(22)
	if not _expect(result.process_mode == Node.PROCESS_MODE_ALWAYS, "result process mode was not restored"):
		return
	await shot("transition_06_result.png")
	await frames(25)
	var old_result: WeakRef = weakref(result)
	result = null
	await _click(_button(main.result_layer, Loc.t("返回飞空艇", "Return to Airship")))
	await frames(26)
	if not _expect(main.result_layer == null and old_result.get_ref() == null and main.hub != null, "result return did not clean up"):
		return
	main._show_result({"success": false, "cargo": [], "loadout": {}, "time": 0, "kills": 0})
	await frames(2)
	_key(KEY_ESCAPE)
	if not _expect(main.result_layer == null, "Escape is blocked during result fade-in"):
		return
	await frames(26)
	if not _expect(main._screen_tweens.is_empty() and main._screen_modes.is_empty(), "screen transitions left stale process state"):
		return
	await _click(main.hub.nav_buttons.trade)
	await frames(22)
	if not _hub_settled("trade"):
		return
	await _click(main.hub.nav_buttons.maintenance)
	await frames(22)
	await shot("transition_07_restored_hub.png")
	await frames(25)
	log_line("assertions=%d input_clicks=%d renderer=%s fps=%d" % [assertions, clicks, RenderingServer.get_current_rendering_method(), Engine.get_frames_per_second()])


func _expect(condition: bool, reason: String) -> bool:
	assertions += 1
	return check(condition, reason)


func _motion_active(target: Node, kind: String) -> bool:
	var effect := target.get_node_or_null("PageMotion") as Control
	if not _expect(effect != null, "mechanical transition is missing"):
		return false
	if not _expect(str(effect.get("kind")) == kind, "unexpected transition style"):
		return false
	if not _expect(effect.mouse_filter == Control.MOUSE_FILTER_IGNORE and effect.focus_mode == Control.FOCUS_NONE, "transition decoration intercepts input"):
		return false
	var phase := float(effect.get("progress"))
	return _expect(phase > 0.0 and phase < 1.0, "mechanical transition has no intermediate phase")


func _click(control: Control) -> void:
	if not _expect(control != null and control.is_visible_in_tree(), "click target is missing or hidden"):
		return
	if control is BaseButton and not _expect(not (control as BaseButton).disabled, "click target is disabled"):
		return
	var trace_settings: bool = control is Button and control.text == Loc.t("设置", "Settings")
	if trace_settings and not control.has_meta("transition_input_trace"):
		control.set_meta("transition_input_trace", true)
		control.button_down.connect(func(): log_line("settings button_down"))
		control.button_up.connect(func(): log_line("settings button_up"))
		control.pressed.connect(func(): log_line("settings pressed"))
	var pos := control.get_global_transform_with_canvas() * (control.size * 0.5)
	if trace_settings:
		var hovered := get_viewport().gui_get_hovered_control()
		log_line("settings click rect=%s pos=%s mode=%d can_process=%s hovered=%s" % [control.get_global_rect(), pos, control.process_mode, control.can_process(), hovered.get_path() if hovered else "none"])
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	get_viewport().push_input(motion, true)
	var down := InputEventMouseButton.new()
	down.position = pos
	down.global_position = pos
	down.button_index = MOUSE_BUTTON_LEFT
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.pressed = true
	get_viewport().push_input(down, true)
	await frames(1)
	var up := InputEventMouseButton.new()
	up.position = pos
	up.global_position = pos
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	get_viewport().push_input(up, true)
	clicks += 1


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	get_viewport().push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	get_viewport().push_input(event, true)


func _button(root: Node, text: String) -> Button:
	for child in root.get_children():
		if child is Button and child.text == text and child.is_visible_in_tree():
			return child as Button
		var found := _button(child, text)
		if found != null:
			return found
	return null


func _tab(key: String) -> bool:
	var hub = main.hub
	var previous: String = hub.cur_tab
	if hub.nav_buttons.has(key):
		await _click(hub.nav_buttons[key])
	else:
		await _click(_button(hub, Loc.t("图鉴", "Codex")))
	await frames(2)
	if not _expect(hub.cur_tab == key, "tab click did not select " + key):
		return false
	var incoming: Control = hub.views[key]
	var outgoing: Control = hub.views[previous]
	if not _expect(incoming.visible and is_zero_approx(incoming.modulate.a), "tab entry overlaps the outgoing page: " + key):
		return false
	if not _motion_active(outgoing, "panels"):
		return false
	if not _chrome_unchanged(hub):
		return false
	await frames(6)
	if not _expect(not outgoing.visible, "tab entry did not follow the completed exit: " + key):
		return false
	if not _motion_active(incoming, "panels"):
		return false
	await shot("transition_motion_%s.png" % key)
	await frames(22)
	if not _hub_settled(key):
		return false
	if key == "trade":
		await shot("transition_03_trade.png")
	elif key == "deploy":
		await shot("transition_04_deploy_map.png")
	await frames(26)
	return true


func _hub_settled(selected: String) -> bool:
	var hub = main.hub
	if not _expect(hub.cur_tab == selected, "unexpected selected tab"):
		return false
	for key in hub.views:
		var page: Control = hub.views[key]
		if not _expect(page.visible == (key == selected), "settled tab visibility is wrong: " + str(key)):
			return false
		if not _expect(is_equal_approx(page.modulate.a, 1.0) and page.process_mode == Node.PROCESS_MODE_INHERIT, "settled tab opacity/process mode is wrong: " + str(key)):
			return false
		if not _expect(page.get_node_or_null("PageMotion") == null, "settled tab retains a transition plate: " + str(key)):
			return false
	return _expect(hub._view_tweens.is_empty() and hub._view_modes.is_empty(), "tab transition state did not clear")


func _deploy_settled(step: int) -> bool:
	if not _expect(main.hub.deploy_step == step, "unexpected deployment step"):
		return false
	for i in main.hub.deploy_pages.size():
		var page: Control = main.hub.deploy_pages[i]
		if not _expect(page.visible == (i == step - 1) and is_equal_approx(page.modulate.a, 1.0) and page.process_mode == Node.PROCESS_MODE_INHERIT, "deployment page did not settle"):
			return false
	return _expect(main.hub._deploy_tweens.is_empty() and main.hub._deploy_modes.is_empty(), "deployment transition state did not clear")


func _chrome(hub: Control) -> Array:
	var out: Array = []
	for child in hub.get_children():
		if child is Control and child.name != "PageMotion":
			out.append([child, Rect2(child.position, child.size), child.scale, child.z_index, child.mouse_filter])
	for button in hub.nav_buttons.values():
		out.append([button, Rect2(button.position, button.size), button.scale, button.z_index, button.mouse_filter])
	return out


func _chrome_unchanged(hub: Control) -> bool:
	for saved: Array in chrome:
		var control: Control = saved[0]
		var same_scale: bool = control == hub.nav_buttons.deploy or control.scale.is_equal_approx(saved[2])
		if not _expect(Rect2(control.position, control.size).is_equal_approx(saved[1]) and same_scale and control.z_index == saved[3] and control.mouse_filter == saved[4] and is_equal_approx(control.modulate.a, 1.0), "persistent UI geometry, opacity, or input filter changed: %s (alpha=%f)" % [control.get_path(), control.modulate.a]):
			return false
	return true
