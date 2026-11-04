extends "res://tests/lib/test_base.gd"
## 降落页像素大地图一致性：godot --headless --path . -- --worldmap
## 1. 拼接：worldmap.json 里每个战区方块的位置符合 scripts/world_link.gd 的 LINKS 邻接（v0.8 城市群：相邻战区直接共用边界，
##    方块位置 = 城市群布局 scripts/world_city.gd 的世界坐标 − 大地图范围左上角）。
## 2. 逐战区用游戏自己的生成代码（tools/worldmap/export_raid.gd，raid.gd 子类、固定种子）真实生成一遍，与底图 wm_1m.png 比对：
##    · 撤离候选点、遗迹中心 / 类型、地标位置与大地图元数据一致（坐标映射 = 方块原点 + 世界坐标 + 180）；
##    · 每 4 米抽样：游戏里是水面（in_wet）的点在底图上是水色，是道路的点是路面色，远离河湖的点不是水色；
##    · 转场口：同一种子生成的位置落在元数据记录的范围内，去向与 LINKS 一致；
##    · 建筑：城市群布局里的建筑轮廓（确定性）在底图上画成了屋顶，并且这一局真的盖了（落在这一局的大型占地矩形里）。
## 3. 界面：降落页第 1 步是大地图，单击战区方块选中（GameData.map_id 跟着变），未解锁的点不动；缩放档位与坐标映射正确。
## 有界面运行时额外截图：hubwm_1_default / 2_hover / 3_zoom1 / 4_zoom2 / 5_locked。

const START := "hub"
const TIMEOUT := 300.0
const ExportRaid = preload("res://tools/worldmap/export_raid.gd")
const WorldLink = preload("res://scripts/world_link.gd")
const WC = preload("res://scripts/world_city.gd")
const SEED := 5

const WATER := [Color8(45, 75, 140), Color8(24, 36, 70), Color8(102, 166, 255)]
const ROAD := [Color8(52, 53, 48), Color8(64, 66, 57), Color8(120, 122, 110), Color8(130, 103, 90), Color8(115, 86, 85),
	Color8(205, 135, 20), Color8(140, 138, 120), Color8(8, 8, 10), Color8(46, 41, 40), Color8(160, 160, 145), Color8(90, 51, 35)]   ## 路面 / 路缘 / 中线 / 桥 / 平交道口铁轨
const ROOF := [Color8(118, 120, 126), Color8(143, 143, 147), Color8(89, 79, 85), Color8(150, 40, 35), Color8(187, 149, 143), Color8(90, 24, 22),
	Color8(102, 103, 89), Color8(140, 138, 120), Color8(64, 66, 57), Color8(150, 97, 13), Color8(205, 135, 20), Color8(110, 70, 14),
	Color8(90, 51, 35), Color8(130, 103, 90), Color8(57, 19, 20), Color8(78, 80, 72), Color8(120, 122, 110), Color8(52, 53, 48),
	Color8(137, 118, 122), Color8(171, 166, 166), Color8(106, 100, 108), Color8(136, 131, 132), Color8(73, 69, 70), Color8(8, 8, 10)]   ## 屋顶主色 / 亮边 / 暗边 / 描边
const DIRV := {"N": Vector2(0, -1), "S": Vector2(0, 1), "E": Vector2(1, 0), "W": Vector2(-1, 0)}

var meta := {}
var img: Image
var problems: Array = []


func p(msg: String) -> void:
	problems.append(msg)


func _in(c: Color, set_: Array) -> bool:
	for s: Color in set_:
		if c.r8 == s.r8 and c.g8 == s.g8 and c.b8 == s.b8:
			return true
	return false


func run() -> void:
	await frames(2)
	var f := FileAccess.open("res://assets/ui/worldmap/worldmap.json", FileAccess.READ)
	if not check(f != null, "缺少 assets/ui/worldmap/worldmap.json"):
		return
	meta = JSON.parse_string(f.get_as_text())
	var tex: Texture2D = load("res://assets/ui/worldmap/wm_1m.png")
	if not check(tex != null, "缺少底图 wm_1m.png"):
		return
	img = tex.get_image()
	check(img.get_width() == int(meta.w) and img.get_height() == int(meta.h), "底图尺寸与元数据不一致")
	for k in [2, 4]:
		var t2: Texture2D = load("res://assets/ui/worldmap/wm_%dm.png" % k)
		check(t2 != null and t2.get_width() == int(meta.w) / k, "缺少或尺寸不对：wm_%dm.png" % k)
	_check_layout()
	WorldLink.force_open = true
	for mid: String in GameData.map_ids():
		if not check(meta.maps.has(mid), "大地图上没有战区 %s" % mid):
			continue
		await _check_map(mid)
	WorldLink.force_open = false
	await _check_ui()
	for x in problems.slice(0, 30):
		log_line("  " + str(x))
	check(problems.is_empty(), "%d 处问题，首条：%s" % [problems.size(), problems[0] if not problems.is_empty() else ""])


func _check_layout() -> void:
	var step := float(meta.tile) + float(meta.gutter)
	for a: String in WorldLink.LINKS:
		for e: String in WorldLink.LINKS[a]:
			var b: String = WorldLink.LINKS[a][e]
			if not meta.maps.has(a) or not meta.maps.has(b):
				p("LINKS %s→%s 有战区不在大地图上" % [a, b])
				continue
			var d := Vector2(float(meta.maps[b].x) - float(meta.maps[a].x), float(meta.maps[b].y) - float(meta.maps[a].y))
			if not d.is_equal_approx(DIRV[e] * step):
				p("拼接错误：%s 的 %s 边应接 %s，方块偏移 %s" % [a, e, b, d])
	# 方块互不重叠
	var ids: Array = meta.maps.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var ra := Rect2(float(meta.maps[ids[i]].x), float(meta.maps[ids[i]].y), meta.tile, meta.tile)
			var rb := Rect2(float(meta.maps[ids[j]].x), float(meta.maps[ids[j]].y), meta.tile, meta.tile)
			if ra.intersects(rb):
				p("方块重叠：%s / %s" % [ids[i], ids[j]])
	# 地表战区：方块位置就是城市群世界坐标
	var wr: Array = meta.get("world_rect", [])
	if wr.size() == 4:
		for id: String in ids:
			if not WC.is_surface(id):
				continue
			var o := WC.origin(id)
			var want := Vector2(o.x - 180.0 - float(wr[0]), o.y - 180.0 - float(wr[1]))
			if not want.is_equal_approx(Vector2(float(meta.maps[id].x), float(meta.maps[id].y))):
				p("%s 方块位置 %s 与城市群世界坐标不符（应为 %s）" % [id, Vector2(float(meta.maps[id].x), float(meta.maps[id].y)), want])
	else:
		p("worldmap.json 缺少 world_rect")
	# 转场口预算表（scripts/world_gates.gd）与现算一致
	for a: String in WorldLink.LINKS:
		for e: String in WorldLink.LINKS[a]:
			var key := "%s|%s" % [a, e]
			var want := WC.gate_compute(a, e)
			if not WC.WorldGates.GATES.has(key):
				p("world_gates.gd 缺少 %s（重新运行 -- --worldmap_export）" % key)
			elif absf(float(WC.WorldGates.GATES[key]) - want) > 0.01:
				p("world_gates.gd %s = %.1f，现算 %.1f（重新运行 -- --worldmap_export）" % [key, float(WC.WorldGates.GATES[key]), want])


func _px(m: Dictionary, x: float, z: float) -> Color:
	var px := int(floor(float(m.x) + x + 180.0))
	var py := int(floor(float(m.y) + z + 180.0))
	return img.get_pixel(clampi(px, 0, img.get_width() - 1), clampi(py, 0, img.get_height() - 1))


func _check_map(mid: String) -> void:
	var m: Dictionary = meta.maps[mid]
	var raid = ExportRaid.new()
	add_child(raid)
	raid.gen(mid, SEED)
	var tag := "[%s]" % mid
	# 撤离候选点 / 遗迹 / 地标
	var ex: Array = raid.MAP.extracts
	if ex.size() != m.extracts.size():
		p("%s 撤离点数量 %d ≠ 大地图 %d" % [tag, ex.size(), m.extracts.size()])
	else:
		for i in ex.size():
			if absf(float(ex[i][1]) - float(m.extracts[i].x)) > 0.01 or absf(float(ex[i][2]) - float(m.extracts[i].z)) > 0.01:
				p("%s 撤离点 %s 位置不一致" % [tag, ex[i][0]])
	if raid.poi_centers.size() != m.pois.size():
		p("%s 遗迹数量 %d ≠ 大地图 %d" % [tag, raid.poi_centers.size(), m.pois.size()])
	else:
		for i in raid.poi_centers.size():
			var c: Vector3 = raid.poi_centers[i]
			if Vector2(c.x, c.z).distance_to(Vector2(float(m.pois[i].x), float(m.pois[i].z))) > 0.2 or str(raid.poi_ids[i]) != str(m.pois[i].id):
				p("%s 遗迹 %s 位置 / 类型不一致" % [tag, raid.poi_ids[i]])
	var lms: Array = raid.get_meta("ext_landmarks", [])
	if lms.size() != m.landmarks.size():
		p("%s 地标数量不一致" % tag)
	else:
		for i in lms.size():
			var ml: Dictionary = m.landmarks[i]
			if str(ml.type) != str(lms[i].type) or float(lms[i].x) < float(ml.x_lo) - 0.1 or float(lms[i].x) > float(ml.x_hi) + 0.1 \
					or float(lms[i].z) < float(ml.z_lo) - 0.1 or float(lms[i].z) > float(ml.z_hi) + 0.1:
				p("%s 地标 %s (%.0f, %.0f) 不在大地图记录的范围内" % [tag, lms[i].type, lms[i].x, lms[i].z])
	# 转场口
	var gm := {}
	for g: Dictionary in meta.gates:
		if str(g.map) == mid:
			gm[str(g.edge)] = g
	var links: Dictionary = WorldLink.LINKS.get(mid, {})
	if gm.size() != links.size():
		p("%s 转场口 %d 处，LINKS %d 条" % [tag, gm.size(), links.size()])
	for g: Dictionary in raid.world_link.gate_list():
		var mg: Dictionary = gm.get(str(g.edge), {})
		if mg.is_empty() or str(mg.to) != str(g.to):
			p("%s %s 边转场口去向不一致" % [tag, g.edge])
		elif float(g.along) < float(mg.lo) - 0.1 or float(g.along) > float(mg.hi) + 0.1:
			p("%s %s 边转场口 %.0f 不在大地图范围 %.0f~%.0f" % [tag, g.edge, g.along, mg.lo, mg.hi])
	# 建筑占地栅格（这一局）
	var occ := PackedByteArray()
	occ.resize(360 * 360)
	var big := PackedByteArray()
	big.resize(360 * 360)
	for r: Rect2 in raid.blocks:
		var x0 := clampi(int(floor(r.position.x + 180.0)) - 1, 0, 359)
		var x1 := clampi(int(ceil(r.end.x + 180.0)) + 1, 0, 359)
		var z0 := clampi(int(floor(r.position.y + 180.0)) - 1, 0, 359)
		var z1 := clampi(int(ceil(r.end.y + 180.0)) + 1, 0, 359)
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				occ[z * 360 + x] = 1
				if r.get_area() > 10.0:
					big[z * 360 + x] = 1
	var n_w := 0
	var ok_w := 0
	var n_r := 0
	var ok_r := 0
	var n_d := 0
	var ok_d := 0
	var z := -178.0
	while z < 178.0:
		var x := -178.0
		while x < 178.0:
			var q := Vector2(x, z)
			var gi := int(z + 180.0) * 360 + int(x + 180.0)
			if occ[gi] == 0:
				var c := _px(m, x, z)
				var road: bool = raid.on_road(q, 2.0)
				var bridge := false
				for b: Array in raid.bridges:
					if raid._pdist(PackedVector2Array([b[0], b[1]]), q) < float(b[2]) * 0.5 + 2.0:
						bridge = true
				if raid.in_wet(q, -2.5) and not road and not bridge:
					n_w += 1
					if _in(c, WATER):
						ok_w += 1
				elif raid.on_road(q, -2.0) and not raid.in_river(q, 3.0):
					n_r += 1
					if _in(c, ROAD):
						ok_r += 1
					elif OS.get_environment("WM_DEBUG") != "":
						log_line("%s 路面点 (%.0f, %.0f) 颜色 %d,%d,%d" % [tag, x, z, c.r8, c.g8, c.b8])
				elif not raid.in_river(q, 4.0) and not road:
					n_d += 1
					if not _in(c, WATER):
						ok_d += 1
			x += 4.0
		z += 4.0
	var fw := float(ok_w) / maxf(1.0, n_w)
	var fr := float(ok_r) / maxf(1.0, n_r)
	var fd := float(ok_d) / maxf(1.0, n_d)
	if n_w > 0 and fw < 0.97:
		p("%s 水面抽样只有 %.1f%% 在底图上是水色（%d 点）" % [tag, fw * 100.0, n_w])
	if n_r > 0 and fr < 0.97:
		p("%s 道路抽样只有 %.1f%% 在底图上是路面色（%d 点）" % [tag, fr * 100.0, n_r])
	if fd < 0.995:
		p("%s 陆地抽样有 %.1f%% 在底图上画成了水" % [tag, (1.0 - fd) * 100.0])
	# 城市群布局里的建筑轮廓：底图上是屋顶（不是路 / 水 / 空地），且这一局真的盖了（在大型占地矩形里）
	var roof := 0
	var drawn := 0
	var hit := 0
	for b: Dictionary in WC.zone_layout(mid).bldgs:
		var u := Vector2(cos(b.ang), sin(b.ang))
		var v := Vector2(-sin(b.ang), cos(b.ang))
		var sx: float = b.sx
		var sz: float = b.sz
		var a := -sx * 0.5 + 1.5
		while a < sx * 0.5 - 1.4:
			var c := -sz * 0.5 + 1.5
			while c < sz * 0.5 - 1.4:
				var q: Vector2 = b.c + u * a + v * c
				roof += 1
				var col := _px(m, q.x, q.y)
				if _in(col, ROOF):
					drawn += 1
				var gi := clampi(int(q.y + 180.0), 0, 359) * 360 + clampi(int(q.x + 180.0), 0, 359)
				if big[gi] == 1:
					hit += 1
				c += 2.0
			a += 2.0
	var fb := float(hit) / maxf(1.0, roof)
	var fdr := float(drawn) / maxf(1.0, roof)
	if roof > 0 and fb < 0.9:
		p("%s 布局建筑只有 %.0f%% 在本局（种子 %d）的建筑占地里" % [tag, fb * 100.0, SEED])
	if roof > 0 and fdr < 0.95:
		p("%s 布局建筑只有 %.0f%% 在大地图上画成了屋顶" % [tag, fdr * 100.0])
	log_line("%s 水 %d/%d 路 %d/%d 陆 %d/%d 建筑 实建 %d/%d 画出 %d/%d 转场口 %s" % [tag, ok_w, n_w, ok_r, n_r, ok_d, n_d, hit, roof, drawn, roof, gm.keys()])
	raid.queue_free()
	await frames(1)


func _check_ui() -> void:
	var hub = main.hub
	hub._switch_tab("deploy")
	await wait(0.6)
	var wm = hub.world_map
	if not check(wm != null and wm.is_visible_in_tree(), "降落页第 1 步没有大地图"):
		return
	check(wm.size.x > 400 and wm.size.y > 300, "大地图太小：%s" % wm.size)
	wm.zoom_to(0, wm.size * 0.5)
	await frames(2)
	var start: String = GameData.map_id
	var avail: Array = []
	var locked: Array = []
	for id: String in GameData.map_ids():
		(avail if GameData.map_available(id) else locked).append(id)
	await shot("hubwm_0_overview.png")
	for id: String in avail:
		wm.center_on(id)
		await frames(1)
		var r: Rect2 = wm.map_rect(id)
		check(wm.map_at(r.get_center()) == id, "%s 方块中心命中的战区不对" % id)
		wm.click(r.get_center())
		await frames(1)
		check(GameData.map_id == id, "单击 %s 没有选中（当前 %s）" % [id, GameData.map_id])
		check(hub.map_title_lbl.text == str(GameData.map_data(id).name), "简报标题没跟着变：%s" % hub.map_title_lbl.text)
	for id: String in locked:
		var before: String = GameData.map_id
		wm.center_on(id)
		await frames(1)
		wm.click(wm.map_rect(id).get_center())
		check(GameData.map_id == before, "单击未解锁战区 %s 不应选中" % id)
	# 缩放与坐标映射：撤离点在方块内，缩放前后方块中心不变
	GameData.map_id = start if GameData.map_available(start) else str(avail[0])
	hub._refresh_world_map()
	wm.center_on(GameData.map_id)
	wm.zoom_to(1, wm.size * 0.5)
	wm.center_on(GameData.map_id)
	await frames(2)
	await shot("hubwm_1_default.png")
	var c0: Vector2 = wm.map_rect(GameData.map_id).get_center()
	wm.zoom_to(2, c0)
	check(wm.zoom() == 1.0, "放大一档后比例应为 1")
	check(wm.map_rect(GameData.map_id).get_center().distance_to(c0) < 2.0, "以方块中心缩放后中心偏了")
	var m: Dictionary = wm.meta.maps[GameData.map_id]
	for e in m.extracts:
		check(wm.map_rect(GameData.map_id).has_point(wm.game_to_screen(GameData.map_id, float(e.x), float(e.z))), "撤离点映射到方块外")
	await frames(2)
	await shot("hubwm_3_zoom1.png")
	wm.zoom_to(3, c0)
	await frames(2)
	await shot("hubwm_4_zoom2.png")
	wm.zoom_to(1, c0)
	# 悬停：相邻战区
	var nb := ""
	for e: String in WorldLink.LINKS.get(GameData.map_id, {}):
		nb = WorldLink.LINKS[GameData.map_id][e]
		break
	if nb != "":
		# 截图演示用：暂时按「全部解锁」显示，看悬停高亮（截完按真实解锁状态恢复）
		var all := {}
		for id: String in GameData.map_ids():
			all[id] = true
		wm.set_state(all, wm.quests, GameData.map_id)
		wm.set_hover(nb)
		wm.tooltip_text = ""
		check(wm.hover == nb, "悬停状态没有更新")
		await frames(2)
		await shot("hubwm_2_hover.png")
		wm.set_hover("")
		hub._refresh_world_map()
	# 拖动平移
	var off0: Vector2 = wm.offset
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = wm.size * 0.5
	wm._gui_input(ev)
	var mv := InputEventMouseMotion.new()
	mv.position = wm.size * 0.5 - Vector2(60, 40)   # 往左上拖（选中战区居中时上沿可能已贴边，往下拖会被夹住）
	wm._gui_input(mv)
	ev = ev.duplicate()
	ev.pressed = false
	ev.position = mv.position
	var sel_before: String = GameData.map_id
	wm._gui_input(ev)
	check(wm.offset != off0, "拖动没有平移地图")
	check(GameData.map_id == sel_before, "拖动结束不应当作单击选中")
	if not locked.is_empty():
		wm.center_on(str(locked[0]))
		await frames(2)
		await shot("hubwm_5_locked.png")
	hub._deploy_show(2)
	await frames(2)
	hub._deploy_show(1)
	log_line("ui ok：可出击 %s，未解锁 %s" % [avail, locked])
