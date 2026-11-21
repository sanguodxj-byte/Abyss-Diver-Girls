extends "res://tests/lib/test_base.gd"
## 校验出击前地区侦察图的玩家自定义打标记写字功能：
## 1) 标记模式左键点击落点 + 写字保存；2) 普通模式右键快捷落点 + 选色；3) 点击已有标记编辑与删除；
## 4) 存档读写持久化；5) 任务简报同步；6) 全域/细节倍率与中英文下无文字重叠、无越界；7) 局内坐标 1:1 映射。
## godot --headless --path . -- --map_markers

const TIMEOUT := 60.0
const WC = preload("res://scripts/world_city.gd")


func run() -> void:
	GameData.clear_map_markers()
	main.hub._switch_tab("deploy")
	await frames(15)
	var wm = main.hub.world_map
	if not check(wm != null and wm.ready_map, "地区侦察图未就绪"):
		return
	var unlocked := {}
	for id: String in wm.map_ids():
		unlocked[id] = true
	wm.set_state(unlocked, {}, "greyport")
	wm.center_on("greyport")
	await frames(2)

	# 1) 开启标记模式，左键点击灰港市区域打点写字
	wm.set_pin_mode(true)
	if not check(wm.pin_mode, "标记模式未开启"):
		return
	var target_world := WC.origin("greyport") + Vector2(36.0, -24.0)
	var target_screen: Vector2 = wm.to_screen(target_world)
	wm.click(target_screen)
	await frames(2)
	if not check(wm._editor.visible and wm._ed_marker_id == "", "标记编辑器未在新建模式打开"):
		return
	wm._set_editor_color("red")
	wm._ed_input.text = "医院高危先清怪"
	wm._commit_editor()
	await frames(2)
	if not check(GameData.map_markers.size() == 1 and not wm._editor.visible, "标记保存失败"):
		return
	var m1: Dictionary = GameData.map_markers[0]
	if not check(str(m1.map_id) == "greyport" and str(m1.text) == "医院高危先清怪" and str(m1.color) == "red", "标记字段不匹配：%s" % [m1]):
		return
	if not check(Vector2(float(m1.lx), float(m1.lz)).distance_to(Vector2(36.0, -24.0)) < 0.2, "局内局部坐标换算误差过大"):
		return
	if not check(main.hub.map_quest_lbl.text.contains("医院高危先清怪"), "任务简报未同步自定义标记"):
		return

	# 2) 退出标记模式，验证普通模式右键快捷打点写字（同时不破坏普通左键选区）
	wm.set_pin_mode(false)
	var target2_world := WC.origin("greyport") + Vector2(-42.0, 28.0)
	var target2_screen: Vector2 = wm.to_screen(target2_world)
	wm.right_click(target2_screen)
	await frames(2)
	if not check(wm._editor.visible, "普通模式右键未打开标记编辑器"):
		return
	wm._set_editor_color("cyan")
	wm._ed_input.text = "西侧撤离集合点"
	wm._commit_editor()
	await frames(2)
	if not check(GameData.map_markers.size() == 2, "右键标记保存失败"):
		return

	# 3) 点击已有标记编辑文字与颜色
	var hit_screen: Vector2 = wm.to_screen(Vector2(float(m1.wx), float(m1.wz)))
	wm.click(hit_screen)
	await frames(2)
	if not check(wm._editor.visible and wm._ed_marker_id == str(m1.id) and wm._ed_del.visible, "点击已有标记未进入编辑模式"):
		return
	wm._set_editor_color("purple")
	wm._ed_input.text = "医院二楼药房"
	wm._commit_editor()
	await frames(2)
	if not check(str(GameData.map_markers[0].text) == "医院二楼药房" and str(GameData.map_markers[0].color) == "purple", "标记编辑未生效"):
		return

	# 4) 验证缩放/中英文绘制无越界、无重叠、且悬停提示完整
	for language: String in ["zh", "en"]:
		Loc.lang = language
		for level: int in [0, 2, 4]:
			wm.zoom_to(level, wm._map_center())
			await frames(2)
			if not _check_annotations(wm):
				return
	Loc.lang = "zh"
	wm.center_on("greyport")
	await frames(2)
	var tip: String = wm._get_tooltip(wm.to_screen(Vector2(float(GameData.map_markers[0].wx), float(GameData.map_markers[0].wz))))
	if not check(tip.contains("医院二楼药房"), "自定义标记悬停提示缺失：" + tip):
		return

	# 5) 存档读写持久化验证
	GameData.save_game()
	GameData.map_markers = []
	if not check(GameData.load_game() and GameData.map_markers.size() == 2, "自定义标记存档读取失败"):
		return
	if not check(str(GameData.map_markers[0].text) == "医院二楼药房" and str(GameData.map_markers[1].text) == "西侧撤离集合点", "存档恢复后文字不一致"):
		return

	# 6) 删除标记验证
	wm.open_marker_editor(Vector2.ZERO, str(GameData.map_markers[0].id))
	await frames(1)
	wm._delete_editor_marker()
	await frames(2)
	if not check(GameData.map_markers.size() == 1 and str(GameData.map_markers[0].text) == "西侧撤离集合点", "删除标记失败"):
		return

	# 7) 切页立即关闭编辑器、完成转场后无残留且不常驻 _process
	wm.right_click(wm._map_center())
	await frames(1)
	main.hub._deploy_show(2)
	if not check(not wm._editor.visible, "切页后编辑器未立即关闭"):
		return
	if not check(await until(func(): return not wm.is_visible_in_tree(), 2), "切页转场未完成"):
		return
	if not check(not wm.is_processing(), "地图存在常驻 _process"):
		return

	GameData.clear_map_markers()
	log_line("map markers: pin mode, right-click, edit, delete, save/load persistence, briefing sync, ZH/EN layout checks passed")


func _check_annotations(wm) -> bool:
	for i in wm.annotation_labels.size():
		var rect: Rect2 = wm.annotation_labels[i].rect
		if not check(wm.plot_rect().encloses(rect), "标记文字超出可读区域"):
			return false
		for j in range(i + 1, wm.annotation_labels.size()):
			if not check(not rect.intersects(wm.annotation_labels[j].rect), "标记文字发生重叠"):
				return false
		for marker: Dictionary in wm._visible_markers:
			if not check(not rect.intersects(marker.rect), "标记文字遮挡地图点位"):
				return false
	return true
