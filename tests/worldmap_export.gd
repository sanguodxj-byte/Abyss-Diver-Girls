extends "res://tests/lib/test_base.gd"
## 大地图数据导出（不是门禁测试）：godot --headless --path . -- --worldmap_export
## 对每个战区用与游戏相同的生成代码（tools/worldmap/export_raid.gd）跑 WM_SEEDS 个种子，导出
## tools/worldmap/data/<战区>.json：区块、道路、自由路、河流、湖、铁路、山脊巨石、桥、遗迹、地名、撤离候选点、地标、
## 转场口（每个种子的位置）、建筑占地统计（1 米栅格，每格被大型建筑占用的种子数）、示例种子的全部占地矩形，
## 以及示例种子的游戏内小地图 tools/worldmap/data/minimap_<战区>.png（raid._build_map_texture 原样输出）。
## 环境变量：WM_ONLY=战区 id（逗号分隔，只导出这些）；WM_SEEDS=种子数（默认 12，示例种子 = 1）。

const START := "none"
const TIMEOUT := 1200.0
const ExportRaid = preload("res://tools/worldmap/export_raid.gd")
const WorldLink = preload("res://scripts/world_link.gd")
const N := 360   ## 1 米栅格

var out_dir := ""


func run() -> void:
	await frames(2)
	WorldLink.force_open = true
	out_dir = ProjectSettings.globalize_path("res://tools/worldmap/data")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var only := OS.get_environment("WM_ONLY")
	var seeds := int(OS.get_environment("WM_SEEDS")) if OS.get_environment("WM_SEEDS") != "" else 12
	for mid: String in GameData.map_ids():
		if only != "" and not (mid in only.split(",")):
			continue
		await _export(mid, seeds)
	WorldLink.force_open = false


func _rect_arr(r: Rect2) -> Array:
	return [snappedf(r.position.x, 0.01), snappedf(r.position.y, 0.01), snappedf(r.size.x, 0.01), snappedf(r.size.y, 0.01)]


func _v2(p: Vector2) -> Array:
	return [snappedf(p.x, 0.01), snappedf(p.y, 0.01)]


func _export(mid: String, seeds: int) -> void:
	var t0 := Time.get_ticks_msec()
	var occ := PackedInt32Array()
	occ.resize(N * N)
	var occ_s := PackedInt32Array()
	occ_s.resize(N * N)
	var gates := {}
	var lm_samples: Array = []
	var data := {}
	for s in range(1, seeds + 1):
		var raid = ExportRaid.new()
		add_child(raid)
		var drop: Vector3 = raid.gen(mid, s)
		for g: Dictionary in raid.world_link.gate_list():
			if not gates.has(g.edge):
				gates[g.edge] = {"edge": g.edge, "to": g.to, "along": []}
			gates[g.edge].along.append(float(g.along))
		var lms: Array = raid.get_meta("ext_landmarks", [])
		for i in lms.size():
			if lm_samples.size() <= i:
				lm_samples.append([])
			lm_samples[i].append({"x": lms[i].x, "z": lms[i].z})
		for r: Rect2 in raid.blocks:
			var big := r.get_area() > 10.0
			var x0 := clampi(int(floor(r.position.x + 180.0)), 0, N - 1)
			var x1 := clampi(int(ceil(r.end.x + 180.0)) - 1, 0, N - 1)
			var z0 := clampi(int(floor(r.position.y + 180.0)), 0, N - 1)
			var z1 := clampi(int(ceil(r.end.y + 180.0)) - 1, 0, N - 1)
			for z in range(z0, z1 + 1):
				for x in range(x0, x1 + 1):
					if big:
						occ[z * N + x] += 1
					else:
						occ_s[z * N + x] += 1
		if s == 1:
			data = _static_data(raid, mid, drop)
			raid.map_tex.get_image().save_png(out_dir.path_join("minimap_%s.png" % mid))
		raid.queue_free()
		await frames(1)
	# 占用统计：同一格在同一种子里可能被多块重复计数，截到 seeds
	var ob := PackedByteArray()
	ob.resize(N * N)
	var obs := PackedByteArray()
	obs.resize(N * N)
	for i in N * N:
		ob[i] = mini(occ[i], seeds)
		obs[i] = mini(occ_s[i], seeds)
	data["seeds"] = seeds
	data["occ_big_b64"] = Marshalls.raw_to_base64(ob)
	data["occ_small_b64"] = Marshalls.raw_to_base64(obs)
	data["gates"] = gates.values()
	data["landmark_samples"] = lm_samples
	var f := FileAccess.open(out_dir.path_join("%s.json" % mid), FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "", false))
	f.close()
	log_line("%s seeds=%d gates=%s %.1fs" % [mid, seeds, gates.keys(), (Time.get_ticks_msec() - t0) / 1000.0])


func _static_data(raid, mid: String, drop: Vector3) -> Dictionary:
	var md: Dictionary = raid.MAP
	var roads: Array = []
	for r: Dictionary in raid.roads:
		roads.append({"rect": _rect_arr(raid._road_rect(r)), "v": r.v, "w": r.w, "dirt": r.dirt})
	var curves: Array = []
	for cv: Dictionary in raid.curves:
		var pp: Array = []
		for p: Vector2 in cv.pts:
			pp.append(_v2(p))
		curves.append({"pts": pp, "w": cv.w, "dirt": cv.dirt})
	var cells: Array = []
	for j in 9:
		var row: Array = []
		for i in 9:
			row.append(_rect_arr(raid._cell_rect(i, j)))
		cells.append(row)
	var pois: Array = []
	for i in raid.poi_centers.size():
		var c: Vector3 = raid.poi_centers[i]
		var pid := str(raid.poi_ids[i])
		pois.append({"x": c.x, "z": c.z, "id": pid, "name": str(GameData.POIS.get(pid, {}).get("name", pid))})
	var bridges: Array = []
	for b: Array in raid.bridges:
		bridges.append([_v2(b[0]), _v2(b[1]), b[2]])
	var ridges: Array = []
	for p: Vector2 in raid.ridge_pts:
		ridges.append(_v2(p))
	var rails: Array = []
	for l: Array in raid.rail_lines:
		rails.append([_v2(l[0]), _v2(l[1])])
	var lakes: Array = []
	for l: Vector3 in raid.lakes:
		lakes.append([l.x, l.y, l.z])
	var rv: Array = []
	for p: Vector2 in raid.river_pts:
		rv.append(_v2(p))
	var blocks: Array = []
	for r: Rect2 in raid.blocks:
		blocks.append(_rect_arr(r))
	var extracts: Array = []
	for e: Array in md.extracts:
		extracts.append({"name": e[0], "x": e[1], "z": e[2]})
	var lms: Array = []
	for m in raid.get_meta("ext_landmarks", []):
		lms.append(m)
	return {
		"id": mid, "name": str(md.get("name", mid)), "tag": str(md.get("tag", "")), "half": raid.HALF, "cell": raid.CELL,
		"zones": md.zones, "cells": cells, "roads": roads, "curves": curves,
		"river": {"pts": rv, "w": raid.river_w, "dry": raid.river_dry}, "lakes": lakes, "rails": rails, "ridge_pts": ridges,
		"bridges": bridges, "pois": pois, "labels": md.get("labels", []), "extracts": extracts, "landmarks": lms,
		"blocks_seed1": blocks, "drop_seed1": [drop.x, drop.z],
	}
