extends "res://tests/lib/test_base.gd"
const TIMEOUT := 120.0
const Data = preload("res://scripts/world_map_2d.gd")
const WC = preload("res://scripts/world_city.gd")

func run() -> void:
	main.hub._switch_tab("deploy")
	await frames(15)
	var wm = main.hub.world_map
	if not check(wm.ready_map and wm.chart is ArrayMesh, "二维地图未加载"):
		return
	if not check(wm.find_children("*", "SubViewport", true, false).is_empty() and wm.find_children("*", "Node3D", true, false).is_empty(), "二维地图仍加载 3D 内容"):
		return
	if not check(wm.chart.get_meta("sources") == Data.signature(), "二维地图数据过期，请重建"):
		return
	var count := 0
	for id: String in wm.map_ids():
		var record: Dictionary = wm.meta.maps[id]
		var layout := WC.zone_layout(id)
		if not check(record.poly == WC.zone_poly_world(id) and record.buildings.size() == layout.bldgs.size(), "地区轮廓/建筑数量不一致"):
			return
		for i in record.buildings.size():
			var actual: Dictionary = layout.bldgs[i]
			var baked: Dictionary = record.buildings[i]
			if not check(baked.c.is_equal_approx(actual.c + WC.origin(id)) and is_equal_approx(baked.ang, actual.ang) and is_equal_approx(baked.sx, actual.sx) and is_equal_approx(baked.sz, actual.sz), "建筑轮廓位置不一致"):
				return
		for gate: Dictionary in record.gates:
			var matching := false
			for other: Dictionary in wm.meta.maps[gate.to].gates:
				if str(other.to) == id and gate.position.distance_to(other.position) < 0.05: matching = true
			if not check(matching, "转场口未连接：" + id): return
		var landmarks: Array = GameData.map_data(id).get("landmarks", [])
		if not check(record.landmarks.size() == landmarks.size(), "地标数量不一致：" + id): return
		for i in landmarks.size():
			var expected: Vector2 = WC.origin(id) + WC.landmark_spot(id, landmarks[i])
			if not check(record.landmarks[i].position.is_equal_approx(expected), "地标位置不一致：" + id): return
		count += record.buildings.size()
	var unlocked := {}
	for id: String in wm.map_ids(): unlocked[id] = true
	unlocked.canyon = false
	wm.set_state(unlocked, {"greyport": true}, "greyport")
	for id: String in wm.map_ids():
		wm.center_on(id)
		await frames(1)
		var point: Vector2 = WC.centroid(WC.zone_poly_world(id))
		var screen: Vector2 = wm.to_screen(point)
		if not check(wm.to_world(screen).distance_to(point) < 0.01 and wm.map_at(screen) == id, "坐标/命中失败：" + id): return
		var previous: String = GameData.map_id
		wm.click(screen)
		if not check(GameData.map_id == (previous if id == "canyon" else id), "选区或锁定失败"): return
		if id != "canyon" and not check(main.hub.map_title_lbl.text == str(GameData.map_data(id).name), "简报未同步"): return
	# 对真实绘制结果验收：六区、两种语言、全域/细节/最大倍率。
	for language: String in ["zh", "en"]:
		Loc.lang = language
		for id: String in wm.map_ids():
			wm.select(id)
			wm.center_on(id)
			for level: int in [0, 2, 4]:
				wm.zoom_to(level, wm._map_center())
				await frames(2)
				if not _check_annotations(wm): return
				if level >= 2:
					for entry: Dictionary in wm.meta.maps[id].landmarks:
						var p: Vector2 = wm.to_screen(entry.position)
						if not wm.plot_rect().encloses(Rect2(p - Vector2(7, 7), Vector2(14, 14))): continue
						var found := false
						for marker: Dictionary in wm._visible_markers:
							if marker.kind == "landmark" and marker.screen.distance_to(p) < 0.01:
								found = not str(marker.text).is_empty() and not str(marker.text).contains("_") and wm._get_tooltip(p) == str(marker.text)
						if not check(found, "可见地标或名称提示缺失：" + id): return
	Loc.lang = "zh"
	wm.overview()
	wm.select("greyport")
	wm.center_on("greyport")
	var anchor: Vector2 = wm.size * Vector2(0.6, 0.55)
	var point: Vector2 = wm.to_world(anchor)
	wm.zoom_to(3, anchor)
	if not check(wm.to_world(anchor).distance_to(point) < 0.01, "缩放锚点漂移"): return
	var off: Vector2 = wm.offset
	var previous: String = GameData.map_id
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = wm.size * 0.5
	down.pressed = true
	wm._gui_input(down)
	var motion := InputEventMouseMotion.new()
	motion.position = down.position + Vector2(48, 32)
	wm._gui_input(motion)
	down.pressed = false
	down.position = motion.position
	wm._gui_input(down)
	if not check(wm.offset.distance_to(off) > 10 and GameData.map_id == previous, "拖动平移或防误选失败"): return
	GameData.map_id = "greyport"
	main.hub._update_map_detail()
	main.hub._refresh_world_map()
	wm.center_on("greyport")
	wm.zoom_to(2, wm.size * 0.5)
	await frames(8)
	await shot("map2d_greyport.png")
	wm.overview()
	await frames(8)
	await shot("map2d_overview.png")
	Loc.lang = "en"
	wm.center_on("ironbelt")
	wm.select("ironbelt")
	await frames(3)
	await shot("map2d_ironbelt_en.png")
	Loc.lang = "zh"
	wm.select("greyport")
	wm.overview()
	main.hub._deploy_show(2)
	if not check(await until(func(): return not wm.is_visible_in_tree(), 2), "确认携带转场未完成"): return
	main.hub._deploy_show(1)
	if not check(await until(func(): return wm.is_visible_in_tree(), 2), "无法返回地图"): return
	await frames(8)
	if not check(not wm.is_processing() and wm.selected == GameData.map_id, "地图有常驻更新或返回丢失选择"): return
	log_line("2D sectors=%d buildings=%d load_ms=%.2f; coordinates, selection, locks, zoom, pan, briefing, page flow, landmark tooltips and label placement (6 sectors / 2 languages / 3 zooms) passed" % [wm.map_ids().size(), count, wm.build_ms])


func _check_annotations(wm) -> bool:
	if not check(not wm.annotation_labels.is_empty(), "没有绘制地图文字"): return false
	for i in wm.annotation_labels.size():
		var rect: Rect2 = wm.annotation_labels[i].rect
		if not check(wm.plot_rect().encloses(rect), "文字超出可读区域"): return false
		for j in range(i + 1, wm.annotation_labels.size()):
			if not check(not rect.intersects(wm.annotation_labels[j].rect), "地图文字重叠"): return false
		for marker: Dictionary in wm._visible_markers:
			if not check(not rect.intersects(marker.rect), "文字遮挡地图点位"): return false
	return true
