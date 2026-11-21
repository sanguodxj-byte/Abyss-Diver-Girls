extends "res://tests/lib/test_base.gd"
## 随机地图实机视角拍摄测试：随机抽取战区并在战区内随机采样可通行点位，
## 全程保持与真实玩家完全一致的相机、FOV、缩放、倾角、雾效、流式视距、建筑遮挡虚化、机甲与 HUD。
##
## 用法：
##   godot --path . -- --rand_mapshot
## 可选参数（命令行 --key=val 或同名环境变量）：
##   --seed=<整数>         固定随机种子（默认按系统时间真随机）
##   --map=<id[,id]>       指定战区 id（默认从全部战区随机抽取）
##   --maps=<数量|all>     随机抽取战区数量（默认 1）
##   --count=<数量>        每个战区拍摄点位数（默认 6：首张为真实空投落点，其余为全图分散随机点）
##   --view=tps|fps|both   玩家视角模式（默认 tps，即 GameData 默认第三人称斜俯视）
## 输出：review\rand_mapshot_<战区>_<序号>_<区块>[_fps].png

const TIMEOUT := 600.0
const MIN_SPOT_DIST := 55.0
const MapsData = preload("res://scripts/maps.gd")

var _rng := RandomNumberGenerator.new()
var _seed_used := 0


func _arg(flag: String, env_key: String, def_val: String) -> String:
	var prefix := "--%s=" % flag
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	var ev := OS.get_environment(env_key)
	return ev if ev != "" else def_val


func _pick_maps() -> Array[String]:
	var all_ids: Array[String] = []
	for k in GameData.MAPS.keys():
		all_ids.append(str(k))
	all_ids.sort()
	var map_arg := _arg("map", "MAP", "").strip_edges()
	if map_arg != "":
		var picked: Array[String] = []
		for raw: String in map_arg.split(","):
			var mid := raw.strip_edges()
			if mid == "":
				continue
			if not check(GameData.MAPS.has(mid), "没有这个战区：%s" % mid):
				return []
			picked.append(mid)
		return picked
	var maps_arg := _arg("maps", "MAPS", "1").strip_edges().to_lower()
	var want_n := all_ids.size() if maps_arg == "all" else clampi(int(maps_arg), 1, all_ids.size())
	# Fisher-Yates 洗牌，确保同 seed 下确定性复现
	for i in range(all_ids.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := all_ids[i]
		all_ids[i] = all_ids[j]
		all_ids[j] = tmp
	var out: Array[String] = []
	for i in want_n:
		out.append(all_ids[i])
	return out


func _probe_ground(raid: Node, p: Vector3) -> Dictionary:
	if not raid.in_bounds(p, 16.0):
		return {"ok": false}
	if raid._blocked(p, 2.2, false):
		return {"ok": false}
	var sp: PhysicsDirectSpaceState3D = (raid as Node3D).get_world_3d().direct_space_state
	var dq := PhysicsRayQueryParameters3D.create(Vector3(p.x, 30.0, p.z), Vector3(p.x, -2.0, p.z), 1)
	var hit: Dictionary = sp.intersect_ray(dq)
	if hit.is_empty():
		return {"ok": false}
	var gp: Vector3 = hit.position
	var gn: Vector3 = hit.normal
	if gp.y < -0.5 or gp.y > 0.65 or gn.y < 0.92:
		return {"ok": false}
	var eye := Vector3(p.x, gp.y + 1.4, p.z)
	for d: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var hq := PhysicsRayQueryParameters3D.create(eye, eye + d * 2.1, 1)
		if not sp.intersect_ray(hq).is_empty():
			return {"ok": false}
	return {"ok": true, "pos": Vector3(p.x, gp.y, p.z)}


func _best_open_dir(raid: Node, p: Vector3) -> Vector3:
	var sp: PhysicsDirectSpaceState3D = (raid as Node3D).get_world_3d().direct_space_state
	var eye := Vector3(p.x, p.y + 1.8, p.z)
	var scored: Array = []
	for k in 12:
		var ang := TAU * float(k) / 12.0
		var d := Vector3(cos(ang), 0.0, sin(ang))
		var rq := PhysicsRayQueryParameters3D.create(eye, eye + d * 36.0, 1)
		var hit: Dictionary = sp.intersect_ray(rq)
		var dist := 36.0 if hit.is_empty() else eye.distance_to(hit.position)
		scored.append({"dir": d, "dist": dist})
	scored.sort_custom(func(a, b): return a.dist > b.dist)
	var top_n := mini(4, scored.size())
	return scored[_rng.randi_range(0, top_n - 1)].dir


func _sample_spots(raid: Node, count: int) -> Array[Dictionary]:
	var spots: Array[Dictionary] = []
	var drop_p: Vector3 = raid.mech.global_position
	var drop_z: String = str(raid.zone_at(drop_p))
	spots.append({"pos": drop_p, "tag": "drop", "zone": drop_z, "is_drop": true})
	if count <= 1:
		return spots
	var half: float = maxf(float(raid.HALF) - 18.0, 40.0)
	var pool: Array[Vector3] = []
	# 混合全图均匀随机点、道路沿线随机点与 POI 周边随机点，保证街区/道路/建筑/野外全覆盖
	for _i in 220:
		pool.append(Vector3(_rng.randf_range(-half, half), 0.0, _rng.randf_range(-half, half)))
	for pc in raid.poi_centers:
		for _j in 3:
			var ang := _rng.randf() * TAU
			var rad := _rng.randf_range(8.0, 22.0)
			pool.append(Vector3(pc.x + cos(ang) * rad, 0.0, pc.z + sin(ang) * rad))
	if raid.curves.size() > 0:
		for _k in 40:
			var cv: Dictionary = raid.curves[_rng.randi_range(0, raid.curves.size() - 1)]
			var pts: PackedVector2Array = cv.get("pts", PackedVector2Array())
			if pts.size() >= 2:
				var idx := _rng.randi_range(0, pts.size() - 2)
				var pt: Vector2 = pts[idx].lerp(pts[idx + 1], _rng.randf())
				pool.append(Vector3(pt.x, 0.0, pt.y))
	for i in range(pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp

	var used_zones := {}
	used_zones[drop_z] = true
	var passes := [
		{"min_d": MIN_SPOT_DIST, "new_zone": true},
		{"min_d": MIN_SPOT_DIST, "new_zone": false},
		{"min_d": 32.0, "new_zone": false},
		{"min_d": 16.0, "new_zone": false},
	]
	for cfg: Dictionary in passes:
		if spots.size() >= count:
			break
		var min_d: float = cfg.min_d
		var want_new: bool = cfg.new_zone
		for cand: Vector3 in pool:
			if spots.size() >= count:
				break
			var far_ok := true
			for s: Dictionary in spots:
				var sp_pos: Vector3 = s.pos
				if Vector2(cand.x - sp_pos.x, cand.z - sp_pos.z).length() < min_d:
					far_ok = false
					break
			if not far_ok:
				continue
			var z: String = str(raid.zone_at(cand))
			if want_new and used_zones.has(z):
				continue
			var pr := _probe_ground(raid, cand)
			if not pr.ok:
				continue
			used_zones[z] = true
			spots.append({"pos": pr.pos, "tag": z.to_lower(), "zone": z, "is_drop": false})
	return spots


func _keep_player_healthy(raid: Node) -> void:
	var m = raid.mech
	if m == null or not is_instance_valid(m):
		return
	m.hp = m.max_hp
	m.energy = m.max_energy
	m.hurt_flash = 0.0
	m.shield_time = 0.0
	if m.shield_mesh != null and is_instance_valid(m.shield_mesh):
		m.shield_mesh.visible = false
	for k in m.parts.keys():
		m.parts[k] = 1.0
	if raid.hud != null and is_instance_valid(raid.hud):
		raid.hud.hurt_t = 0.0


func _settle_tps(raid: Node, spot: Dictionary, look_dir: Vector3) -> bool:
	if raid.view_mode != 0:
		raid.set_view_mode(0, false)
	var m = raid.mech
	if not bool(spot.get("is_drop", false)):
		var p: Vector3 = spot.pos
		m.global_position = Vector3(p.x, p.y + 0.15, p.z)
		m.velocity = Vector3.ZERO
	raid.aim_override = m.global_position + look_dir * 6.0 + Vector3(0.0, 1.8, 0.0)
	var stable := 0
	var t := 0.0
	var rb = raid._rb()
	while t < 6.0:
		_keep_player_healthy(raid)
		await get_tree().process_frame
		t += get_process_delta_time()
		var want_cam: Vector3 = raid.cam_focus + raid.CAM_OFFSET * raid._eff_zoom
		var cam_ok: bool = raid.camera.global_position.distance_to(want_cam) < 0.35
		var stream_ok: bool = (rb == null or not rb._pending)
		if cam_ok and stream_ok:
			stable += 1
			if stable >= 12:
				return true
		else:
			stable = 0
	return false


func _settle_fps(raid: Node, spot: Dictionary, look_dir: Vector3) -> bool:
	if raid.view_mode != 1:
		raid.set_view_mode(1, false)
	var m = raid.mech
	var p: Vector3 = spot.pos
	if not bool(spot.get("is_drop", false)):
		m.global_position = Vector3(p.x, p.y + 0.15, p.z)
		m.velocity = Vector3.ZERO
	raid.aim_override = null
	raid.fp_yaw = atan2(-look_dir.x, -look_dir.z)
	raid.fp_pitch = deg_to_rad(-2.0)
	var stable := 0
	var t := 0.0
	var rb = raid._rb()
	while t < 5.0:
		_keep_player_healthy(raid)
		await get_tree().process_frame
		t += get_process_delta_time()
		var stream_ok: bool = (rb == null or not rb._pending)
		if stream_ok:
			stable += 1
			if stable >= 12:
				return true
		else:
			stable = 0
	return false


func _verify_player_perspective(raid: Node, mode: int, label: String) -> bool:
	var cam: Camera3D = raid.camera
	if not check(cam != null and cam.current, "%s: 玩家主相机未激活" % label):
		return false
	if not check(cam.projection == Camera3D.PROJECTION_PERSPECTIVE, "%s: 相机不是透视投影" % label):
		return false
	if not check(raid.view_mode == mode, "%s: 视角模式不匹配（got=%d want=%d）" % [label, raid.view_mode, mode]):
		return false
	if not check(raid.hud != null and raid.hud.visible, "%s: 玩家 HUD 未显示" % label):
		return false
	if not check(raid.mech != null and raid.mech.visible, "%s: 玩家机甲不可见" % label):
		return false
	var rb = raid._rb()
	if not check(rb != null and not rb._all_shown, "%s: 流式裁剪应保持玩家实机状态（未调用 show_all）" % label):
		return false
	if mode == 0:
		if not check(absf(cam.fov - 40.0) < 0.1, "%s: 第三人称 FOV 偏离玩家默认值（got=%.2f）" % [label, cam.fov]):
			return false
		if not check(absf(raid.cam_zoom - raid.ZOOM_MAX) < 0.002, "%s: 第三人称缩放偏离玩家默认值（got=%.4f want=%.4f）" % [label, raid.cam_zoom, raid.ZOOM_MAX]):
			return false
		var want_fwd: Vector3 = (-raid.CAM_OFFSET).normalized()
		var got_fwd: Vector3 = -cam.global_transform.basis.z
		if not check(got_fwd.dot(want_fwd) > 0.999, "%s: 相机俯角/朝向偏离玩家默认视角（dot=%.5f）" % [label, got_fwd.dot(want_fwd)]):
			return false
		var want_cam: Vector3 = raid.cam_focus + raid.CAM_OFFSET * raid._eff_zoom
		var err_m := cam.global_position.distance_to(want_cam)
		if not check(err_m < 0.5, "%s: 相机尚未收敛到玩家跟随位（err=%.2fm）" % [label, err_m]):
			return false
	else:
		if not check(absf(cam.fov - raid.FP_FOV_STD) < 0.15, "%s: 第一人称 FOV 偏离玩家默认值（got=%.2f）" % [label, cam.fov]):
			return false
		if not check(absf(cam.near - 0.08) < 0.01, "%s: 第一人称近裁剪面偏离玩家默认值（got=%.3f）" % [label, cam.near]):
			return false
	return true


func _capture_and_verify(fname: String) -> bool:
	await shot(fname)
	if headless():
		return true
	var full := ProjectSettings.globalize_path(REVIEW_DIR).path_join(fname)
	if not check(FileAccess.file_exists(full), "截图文件未生成：%s" % fname):
		return false
	var f := FileAccess.open(full, FileAccess.READ)
	var sz := f.get_length() if f != null else 0
	if not check(sz > 8192, "截图文件过小（%d B）：%s" % [sz, fname]):
		return false
	return true


func run() -> void:
	var seed_arg := _arg("seed", "SEED", "").strip_edges()
	if seed_arg != "":
		_seed_used = int(seed_arg)
	else:
		_seed_used = int(Time.get_unix_time_from_system()) ^ int(Time.get_ticks_usec() & 0x7fffffff)
	_rng.seed = _seed_used

	var count := clampi(int(_arg("count", "COUNT", "6")), 1, 20)
	var view_arg := _arg("view", "VIEW", "tps").strip_edges().to_lower()
	if not check(view_arg in ["tps", "fps", "both"], "无效的 --view 参数：%s（可选 tps / fps / both）" % view_arg):
		return

	var maps := _pick_maps()
	if maps.is_empty():
		return

	var keep_map := GameData.map_id
	var keep_view := GameData.view_mode
	var keep_lo := GameData.loadout.duplicate()
	if keep_lo.is_empty():
		keep_lo = GameData.STARTER.duplicate()
	GameData.view_mode = 1 if view_arg == "fps" else 0
	log_line("seed=%d maps=%s count=%d view=%s headless=%s" % [_seed_used, str(maps), count, view_arg, str(headless())])

	var total_shots := 0
	for m_idx in maps.size():
		var mid: String = maps[m_idx]
		if m_idx > 0:
			main.show_hub()
			await wait(0.45)
		GameData.map_id = mid
		await wait(0.3)
		var raid = await deploy(keep_lo)
		if not check(raid != null and raid.mech != null, "战区 %s 出击失败" % mid):
			return
		var spots := _sample_spots(raid, count)
		if not check(spots.size() >= mini(count, 2), "战区 %s 采样点不足：%d" % [mid, spots.size()]):
			return
		var map_name := str(GameData.MAPS.get(mid, {}).get("name", mid))
		log_line("map=%s(%s) sampled=%d drop=(%.1f, %.1f) zoom=%.3f fov=%.1f" % [
			mid, map_name, spots.size(), raid.mech.global_position.x, raid.mech.global_position.z, raid.cam_zoom, raid.camera.fov])

		for s_idx in spots.size():
			var spot: Dictionary = spots[s_idx]
			var look_dir := _best_open_dir(raid, spot.pos)
			var tag := str(spot.tag)
			var zname := str(MapsData.ZONE_NAMES.get(str(spot.zone), str(spot.zone)))
			if view_arg == "tps" or view_arg == "both":
				var ok_tps := await _settle_tps(raid, spot, look_dir)
				if not check(ok_tps, "%s#%02d 第三人称相机或流式分块未收敛" % [mid, s_idx + 1]):
					return
				var label_tps := "%s#%02d(tps)" % [mid, s_idx + 1]
				if not _verify_player_perspective(raid, 0, label_tps):
					return
				var fname := "rand_mapshot_%s_%02d_%s.png" % [mid, s_idx + 1, tag]
				if not await _capture_and_verify(fname):
					return
				total_shots += 1
				log_line("shot %s pos=(%.1f, %.1f) zone=%s cam=(%.1f, %.1f, %.1f) fps=%d" % [
					fname, raid.mech.global_position.x, raid.mech.global_position.z, zname,
					raid.camera.global_position.x, raid.camera.global_position.y, raid.camera.global_position.z,
					Engine.get_frames_per_second()])
			if view_arg == "fps" or view_arg == "both":
				var ok_fps := await _settle_fps(raid, spot, look_dir)
				if not check(ok_fps, "%s#%02d 第一人称流式分块未收敛" % [mid, s_idx + 1]):
					return
				var label_fps := "%s#%02d(fps)" % [mid, s_idx + 1]
				if not _verify_player_perspective(raid, 1, label_fps):
					return
				var fname_fp := "rand_mapshot_%s_%02d_%s_fps.png" % [mid, s_idx + 1, tag]
				if not await _capture_and_verify(fname_fp):
					return
				total_shots += 1
				log_line("shot %s pos=(%.1f, %.1f) zone=%s yaw=%.1fdeg fps=%d" % [
					fname_fp, raid.mech.global_position.x, raid.mech.global_position.z, zname,
					rad_to_deg(raid.fp_yaw), Engine.get_frames_per_second()])

		raid.aim_override = null

	GameData.map_id = keep_map
	GameData.view_mode = keep_view
	log_line("completed total_shots=%d seed=%d maps=%s" % [total_shots, _seed_used, str(maps)])
