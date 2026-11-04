extends "res://tests/lib/test_base.gd"
## 大地图数据导出（不是门禁测试）：godot --headless --path . -- --worldmap_export
## 1. 城市群布局（scripts/world_city.gd，确定性）：大地图范围内每个 360 米格子写到 tools/worldmap/data/world/（见 tests/worldcity_dump.gd）。
## 2. 每个战区用与游戏相同的生成代码（tools/worldmap/export_raid.gd）跑 WM_SEEDS 个种子，导出 tools/worldmap/data/<战区>.json：
##    遗迹、地名、撤离候选点、地标（每个种子的位置）、转场口（每个种子的位置）、山脊巨石、示例种子的空投点与小型杂物占地，
##    以及示例种子的游戏内小地图 tools/worldmap/data/minimap_<战区>.png（raid._build_map_texture 原样输出）。
## 环境变量：WM_ONLY=战区 id（逗号分隔，只导出这些战区；城市群格子照常导出）；WM_SEEDS=种子数（默认 8，示例种子 = 1）。

const START := "none"
const TIMEOUT := 1200.0
const ExportRaid = preload("res://tools/worldmap/export_raid.gd")
const WorldLink = preload("res://scripts/world_link.gd")
const WC = preload("res://scripts/world_city.gd")
const Dump = preload("res://tests/worldcity_dump.gd")

var out_dir := ""


func run() -> void:
	await frames(2)
	WorldLink.force_open = true
	out_dir = ProjectSettings.globalize_path("res://tools/worldmap/data")
	DirAccess.make_dir_recursive_absolute(out_dir)
	await Dump.dump(self)
	_write_gates()
	var only := OS.get_environment("WM_ONLY")
	var seeds := int(OS.get_environment("WM_SEEDS")) if OS.get_environment("WM_SEEDS") != "" else 8
	for mid: String in GameData.map_ids():
		if only != "" and not (mid in only.split(",")):
			continue
		await _export(mid, seeds)
	WorldLink.force_open = false


## 转场口预算表：scripts/world_gates.gd（world_city.gd gate_along 先查它，免得开局为算转场口去生成相邻战区的整格布局）
func _write_gates() -> void:
	var lines: Array = []
	var keys: Array = []
	for a: String in WorldLink.LINKS:
		for e: String in WorldLink.LINKS[a]:
			keys.append("%s|%s" % [a, e])
	keys.sort()
	for key: String in keys:
		var pr: PackedStringArray = key.split("|")
		lines.append('\t"%s": %.2f,' % [key, WC.gate_compute(pr[0], pr[1])])
	var src := "extends RefCounted\n## 自动生成（tests/worldmap_export.gd），勿手改：各战区转场口沿边位置（米），即 world_city.gd gate_compute 的结果。\n" \
		+ "## 城市群布局改动后重新运行 -- --worldmap_export；tests/worldmap.gd 会校验这张表与现算一致。\n\nconst GATES := {\n" + "\n".join(lines) + "\n}\n"
	var f := FileAccess.open("res://scripts/world_gates.gd", FileAccess.WRITE)
	f.store_string(src)
	f.close()
	log_line("world_gates.gd: %d 处" % keys.size())


func _v2(p: Vector2) -> Array:
	return [snappedf(p.x, 0.01), snappedf(p.y, 0.01)]


func _export(mid: String, seeds: int) -> void:
	var t0 := Time.get_ticks_msec()
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
		if s == 1:
			data = _static_data(raid, mid, drop)
			raid.map_tex.get_image().save_png(out_dir.path_join("minimap_%s.png" % mid))
		raid.queue_free()
		await frames(1)
	data["seeds"] = seeds
	data["gates"] = gates.values()
	data["landmark_samples"] = lm_samples
	var f := FileAccess.open(out_dir.path_join("%s.json" % mid), FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "", false))
	f.close()
	log_line("%s seeds=%d gates=%s %.1fs" % [mid, seeds, gates.keys(), (Time.get_ticks_msec() - t0) / 1000.0])


func _static_data(raid, mid: String, drop: Vector3) -> Dictionary:
	var md: Dictionary = raid.MAP
	var pois: Array = []
	for i in raid.poi_centers.size():
		var c: Vector3 = raid.poi_centers[i]
		var pid := str(raid.poi_ids[i])
		pois.append({"x": c.x, "z": c.z, "id": pid, "name": str(GameData.POIS.get(pid, {}).get("name", pid))})
	var ridges: Array = []
	for p: Vector2 in raid.ridge_pts:
		ridges.append(_v2(p))
	var small: Array = []
	for r: Rect2 in raid.blocks:
		if r.get_area() <= 10.0:
			small.append([snappedf(r.position.x, 0.01), snappedf(r.position.y, 0.01), snappedf(r.size.x, 0.01), snappedf(r.size.y, 0.01)])
	var extracts: Array = []
	for e: Array in md.extracts:
		extracts.append({"name": e[0], "x": e[1], "z": e[2]})
	var lms: Array = []
	for m in raid.get_meta("ext_landmarks", []):
		lms.append(m)
	var o := WC.origin(mid)
	var tt := WC.tile_of(mid)
	var parent := ""
	if not WC.is_surface(mid):
		parent = "canyon"
	return {
		"id": mid, "name": str(md.get("name", mid)), "tag": str(md.get("tag", "")), "half": raid.HALF, "tile": [tt.x, tt.y],
		"origin_world": [o.x, o.y], "surface": WC.is_surface(mid), "shaft_parent": parent,
		"zones": md.zones, "pois": pois, "labels": md.get("labels", []), "extracts": extracts, "landmarks": lms,
		"ridge_pts": ridges, "small_seed1": small, "drop_seed1": [drop.x, drop.z],
	}
