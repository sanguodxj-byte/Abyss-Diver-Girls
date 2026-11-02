extends "res://tests/lib/test_base.gd"
## 逐战区生成地图，校验遗迹 POI、地标、容器数量与可达性。godot --headless --path . -- --maps
## 每个战区真实跑一遍 raid.start()，再从遗迹院外做一次局部栅格连通填充，确认门口与院内容器走得到。

const START := "none"
const RaidScript = preload("res://scripts/raid.gd")
const MapsData = preload("res://scripts/maps.gd")
const STEP := 1.0          ## 可达性栅格边长（米）
const PAD := 1.0           ## 栅格按机甲半径收边
const MIN_BOXES := 12
const MIN_POI_BOXES := 3
const LOCAL := 46.0       ## 每处遗迹只校验周围这段范围内的连通性

var problems: Array = []


func p(msg: String) -> void:
	problems.append(msg)


func run() -> void:
	await frames(2)
	var only := OS.get_environment("MAPS_ONLY")
	for mid: String in GameData.map_ids():
		if only == "" or mid == only:
			await _check_map(mid)
	log_line("maps=%d pois=%d landmarks=%d" % [GameData.MAPS.size(), GameData.POIS.size(), _landmark_total()])
	for x in problems.slice(0, 30):
		log_line("  " + str(x))
	check(problems.is_empty(), "%d 处问题，首条：%s" % [problems.size(), problems[0] if not problems.is_empty() else ""])


func _check_map(mid: String) -> void:
	GameData.map_id = mid
	var raid = RaidScript.new()
	add_child(raid)
	raid.start(GameData.STARTER.duplicate(), [])
	await frames(2)
	var md: Dictionary = raid.MAP
	var tag := "[%s]" % mid
	if not check(not md.is_empty(), "%s 战区数据为空" % mid):
		return
	# 地形：9 行 × 9 列
	if md.zones.size() != 9:
		p("%s zones 不是 9 行" % tag)
	for row in md.zones:
		if str(row).length() != 9:
			p("%s zones 行宽不是 9：%s" % [tag, row])
	# POI：中心数、类型、脚本
	if raid.poi_centers.size() != md.pois.size():
		p("%s POI 中心 %d 与数据 %d 不一致" % [tag, raid.poi_centers.size(), md.pois.size()])
	for i in raid.poi_centers.size():
		var pid := str(raid.poi_ids[i])
		var info: Dictionary = GameData.POIS.get(pid, {})
		if info.is_empty():
			p("%s 第 %d 处 POI 类型 %s 未登记" % [tag, i, pid])
		elif info.has("script") and not ResourceLoader.exists(str(info.script)):
			p("%s POI %s 的建造脚本不存在" % [tag, pid])
		elif not info.has("script") and not (pid in MapsData.POI_ORDER):
			p("%s POI %s 没有建造脚本" % [tag, pid])
	# 地标：数据与实摆数量一致
	var made: Array = raid.get_meta("ext_landmarks", [])
	var want: int = md.get("landmarks", []).size()
	if made.size() != want:
		p("%s 地标数据 %d 处，实际摆下 %d 处" % [tag, want, made.size()])
	for m in made:
		if absf(float(m.x)) > 180.0 or absf(float(m.z)) > 180.0:
			p("%s 地标 %s 落在地图外" % [tag, m.type])
	# 容器
	var boxes := get_tree().get_nodes_in_group("lootboxes")
	var n_arch := 0
	for b in boxes:
		if b.items.is_empty():
			p("%s 有容器 %s 是空的" % [tag, b.title])
		for id: String in b.items:
			if str(GameData.item(id).get("codex", "")) != "":
				n_arch += 1
	if boxes.size() < MIN_BOXES:
		p("%s 容器只有 %d 只，少于 %d" % [tag, boxes.size(), MIN_BOXES])
	if n_arch == 0:
		p("%s 没有任何档案物件" % tag)
	# 新增遗迹的可达性：在院外找一处空地做局部连通填充，再验证门口与院内容器。
	# 空投点每局随机落点，不能拿它当唯一入口；核心表里的三类遗迹不参与判定。
	var solids := _solid_rects(raid)
	var solid := _raster(solids)
	var mine: Array = []
	for i in raid.poi_centers.size():
		if GameData.POIS.get(str(raid.poi_ids[i]), {}).has("script"):
			mine.append(raid.poi_centers[i])
	var reach_min := 9999
	for c: Vector3 in mine:
		var reach := _local_flood(c, solid)
		reach_min = mini(reach_min, reach.size())
		if reach.is_empty():
			p("%s 新增遗迹 (%d, %d) 院外没有可站立的空地" % [tag, int(c.x), int(c.z)])
			continue
		if not _near(reach, c, 6.0):
			p("%s 新增遗迹 (%d, %d) 没有能走进去的开口" % [tag, int(c.x), int(c.z)])
		var cnt := 0
		var ok := 0
		for b in boxes:
			if b.has_meta("poi") and b.global_position.distance_to(c) < 17.0:
				cnt += 1
				if _near(reach, b.global_position, 3.2):
					ok += 1
		if cnt < MIN_POI_BOXES or ok < MIN_POI_BOXES:
			p("%s 遗迹 (%d, %d) 容器 %d 只，可达 %d 只" % [tag, int(c.x), int(c.z), cnt, ok])
	# 容器不能被埋进墙体或紧贴得站不下人
	for b in boxes:
		if not b.has_meta("poi"):
			continue
		if not _clear(raid, b):
			var bp: Vector3 = b.global_position
			p("%s 容器 %s 在 (%.0f, %.0f) 落进 %s" % [tag, b.title, bp.x, bp.z, _blocker(raid, b)])
	# 天气与动态事件节点
	var wn = raid.get_node_or_null("ext_weather")
	var wpreset := str(md.get("weather", {}).get("preset", ""))
	if wn == null:
		p("%s 没有天气节点" % tag)
	elif wpreset != "" and str(wn.get_meta("preset", "")) != wpreset:
		p("%s 天气预设 %s 没有生效" % [tag, wpreset])
	if raid.get_node_or_null("ext_events") == null:
		p("%s 没有动态事件节点" % tag)
	log_line("%s pois=%d(new %d) landmarks=%d boxes=%d archive=%d local_reach=%d preset=%s" % [tag, raid.poi_centers.size(), mine.size(), made.size(), boxes.size(), n_arch, reach_min, wpreset])
	# 非无头运行时留一组巡览截图：实机画面、每处新增遗迹的俯视总览、远景与大地图；无头时跳过
	if not headless():
		await wait(5.0)
		await shot("maps_%s_play.png" % mid)
		# 总览阶段清掉虫群，机甲站到遗迹中央，镜头拉到最远、收起 HUD，能看清院落轮廓与容器分布
		for b in get_tree().get_nodes_in_group("bugs"):
			b.queue_free()
		await frames(2)
		raid.hud.visible = false
		raid.cam_zoom = 1.3
		for i in raid.poi_centers.size():
			var pinfo: Dictionary = GameData.POIS.get(str(raid.poi_ids[i]), {})
			if not pinfo.has("script"):
				continue
			var pc: Vector3 = raid.poi_centers[i]
			var pspot := pc
			if raid._blocked(pspot, 2.4, false):
				for k in 8:
					var pa := TAU * k / 8.0
					var pq := pc + Vector3(sin(pa) * 7.0, 0, cos(pa) * 7.0)
					if not raid._blocked(pq, 2.4, false):
						pspot = pq
						break
			raid.mech.hp = raid.mech.max_hp
			raid.mech.global_position = pspot + Vector3(0, 0.6, 0)
			await wait(0.8)
			await shot("maps_poi_%s.png" % str(raid.poi_ids[i]))
		raid.hud.visible = true
		raid.mech.hp = raid.mech.max_hp
		if not mine.is_empty():
			var c0: Vector3 = mine[0]
			var spot := c0 + Vector3(0, 0.6, 15.0)
			for k in 8:
				var a := TAU * k / 8.0
				var q := c0 + Vector3(sin(a) * 15.0, 0.6, cos(a) * 15.0)
				if not raid._blocked(q, 2.5, false):
					spot = q
					break
			raid.mech.global_position = spot
			await wait(1.0)
			await shot("maps_%s_poi.png" % mid)
		raid.cam_zoom = 1.3
		await wait(1.2)
		await shot("maps_%s_far.png" % mid)
		if not raid.ended:
			raid.hud.toggle_map()
			await wait(0.4)
			await shot("maps_%s_bigmap.png" % mid)
			raid.hud.toggle_map()
			await wait(0.4)
	raid.queue_free()
	await frames(3)


func _landmark_total() -> int:
	var t := 0
	for mid: String in GameData.MAPS:
		t += GameData.MAPS[mid].get("landmarks", []).size()
	return t


## 收集世界碰撞体的水平投影（只取挡得住机甲的：顶面高于 0.8 米、底面低于 2.2 米）
func _solid_rects(raid) -> Array:
	var out: Array = []
	var stack: Array = [raid.world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			if ch is CollisionShape3D:
				var body := ch.get_parent()
				if body is CollisionObject3D and (int(body.collision_layer) & 1) == 0:
					continue
				var sh = ch.shape
				if sh == null:
					continue
				var t: Transform3D = ch.global_transform
				var top := 0.0
				var bottom := 0.0
				var rx := 0.0
				var rz := 0.0
				if sh is BoxShape3D:
					var s: Vector3 = sh.size
					var hx: Vector3 = t.basis.x * (s.x * 0.5)
					var hy: Vector3 = t.basis.y * (s.y * 0.5)
					var hz: Vector3 = t.basis.z * (s.z * 0.5)
					top = t.origin.y + absf(hy.y)
					bottom = t.origin.y - absf(hy.y)
					rx = absf(hx.x) + absf(hz.x)
					rz = absf(hx.z) + absf(hz.z)
				elif sh is CylinderShape3D:
					top = t.origin.y + sh.height * 0.5
					bottom = t.origin.y - sh.height * 0.5
					rx = sh.radius
					rz = sh.radius
				elif sh is SphereShape3D:
					top = t.origin.y + sh.radius
					bottom = t.origin.y - sh.radius
					rx = sh.radius
					rz = sh.radius
				elif sh is CapsuleShape3D:
					top = t.origin.y + sh.height * 0.5 + sh.radius
					bottom = t.origin.y - sh.height * 0.5 - sh.radius
					rx = sh.radius
					rz = sh.radius
				else:
					continue
				if top <= 0.8 or bottom >= 2.2:
					continue
				out.append(Rect2(t.origin.x - rx, t.origin.z - rz, rx * 2.0, rz * 2.0))
			elif ch is Node3D:
				stack.append(ch)
	return out


## 把碰撞体投影铺成 2 米栅格（含机甲半径）
func _raster(solids: Array) -> Dictionary:
	var n := int(360.0 / STEP)
	var solid := {}
	for r: Rect2 in solids:
		var rr := r.grow(PAD)
		var x0 := maxi(0, int(floor((rr.position.x + 180.0) / STEP)))
		var x1 := mini(n - 1, int(floor((rr.end.x + 180.0) / STEP)))
		var y0 := maxi(0, int(floor((rr.position.y + 180.0) / STEP)))
		var y1 := mini(n - 1, int(floor((rr.end.y + 180.0) / STEP)))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				solid[Vector2i(x, y)] = true
	return solid


## 从遗迹外圈多个方向取种子，做局部连通填充后取并集，代表「从周围街道走进院内」
func _local_flood(center: Vector3, solid: Dictionary) -> Dictionary:
	var c := _cell(center)
	var lim := int(LOCAL / STEP)
	var merged := {}
	for ring in [14.0, 17.0, 20.0, 23.0]:
		for k in 24:
			var a := TAU * float(k) / 24.0
			var q := c + Vector2i(int(cos(a) * ring / STEP), int(sin(a) * ring / STEP))
			if solid.has(q) or merged.has(q):
				continue
			var seen := _flood_from(q, solid, c, lim)
			for cell in seen:
				merged[cell] = true
		if merged.size() > 5000:
			break
	return merged


func _flood_from(start: Vector2i, solid: Dictionary, origin: Vector2i, lim: int) -> Dictionary:
	var n := int(360.0 / STEP)
	var seen := {start: true}
	var stack: Array = [start]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c + d
			if q.x < 0 or q.y < 0 or q.x >= n or q.y >= n or seen.has(q) or solid.has(q):
				continue
			if absi(q.x - origin.x) > lim or absi(q.y - origin.y) > lim:
				continue
			seen[q] = true
			stack.append(q)
	return seen


## 埋入检查：把容器中心变换到每个碰撞体的局部空间，落在盒体/圆柱里才算埋住；
## 容器自身与其它容器的小碰撞体不参与，只判墙体和楼体。
func _blocker(raid, b) -> String:
	var p: Vector3 = b.global_position
	var stack: Array = [raid.world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			if ch is CollisionShape3D:
				if ch.get_parent() == b:
					continue
				var body := ch.get_parent()
				if body is CollisionObject3D and (int(body.collision_layer) & 1) == 0:
					continue
				var sh = ch.shape
				if sh == null:
					continue
				var t: Transform3D = ch.global_transform
				var local: Vector3 = t.affine_inverse() * p
				var hit := false
				if sh is BoxShape3D:
					hit = absf(local.x) <= sh.size.x * 0.5 and absf(local.z) <= sh.size.z * 0.5
				elif sh is CylinderShape3D or sh is SphereShape3D or sh is CapsuleShape3D:
					hit = sqrt(local.x * local.x + local.z * local.z) <= sh.radius
				if hit:
					return "%s %s @%.1f,%.1f" % [sh.get_class(), str(sh.size) if sh is BoxShape3D else str(sh.radius), t.origin.x, t.origin.z]
			elif ch is Node3D:
				stack.append(ch)
	return "?"


func _clear(raid, b) -> bool:
	var p: Vector3 = b.global_position
	var stack: Array = [raid.world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			if ch is CollisionShape3D:
				if ch.get_parent() == b:
					continue
				var body := ch.get_parent()
				if body is CollisionObject3D and (int(body.collision_layer) & 1) == 0:
					continue
				var sh = ch.shape
				if sh == null:
					continue
				var t: Transform3D = ch.global_transform
				var top := 0.0
				var bottom := 0.0
				if sh is BoxShape3D:
					var hy: Vector3 = t.basis.y * (sh.size.y * 0.5)
					top = t.origin.y + absf(hy.y)
					bottom = t.origin.y - absf(hy.y)
				elif sh is CylinderShape3D:
					top = t.origin.y + sh.height * 0.5
					bottom = t.origin.y - sh.height * 0.5
				elif sh is SphereShape3D:
					top = t.origin.y + sh.radius
					bottom = t.origin.y - sh.radius
				elif sh is CapsuleShape3D:
					top = t.origin.y + sh.height * 0.5 + sh.radius
					bottom = t.origin.y - sh.height * 0.5 - sh.radius
				else:
					continue
				if top <= 0.8 or bottom >= 2.2:
					continue
				var local: Vector3 = t.affine_inverse() * p
				if sh is BoxShape3D:
					# 容器与小型摆件之间的互相重叠不算埋进墙里
					if sh.size.x <= 2.2 and sh.size.z <= 2.2:
						continue
					if absf(local.x) <= sh.size.x * 0.5 and absf(local.z) <= sh.size.z * 0.5:
						return false
				elif sh is CylinderShape3D or sh is SphereShape3D or sh is CapsuleShape3D:
					var rad: float = sh.radius if not (sh is CylinderShape3D) else sh.radius
					if sqrt(local.x * local.x + local.z * local.z) <= rad:
						return false
			elif ch is Node3D:
				stack.append(ch)
	return true


func _cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int((p.x + 180.0) / STEP), 0, int(360.0 / STEP) - 1), clampi(int((p.z + 180.0) / STEP), 0, int(360.0 / STEP) - 1))


func _near(seen: Dictionary, p: Vector3, radius: float) -> bool:
	var c := _cell(p)
	var r := int(ceil(radius / STEP))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if seen.has(c + Vector2i(dx, dy)):
				return true
	return false
