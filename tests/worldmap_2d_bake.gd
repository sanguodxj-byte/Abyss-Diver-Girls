extends "res://tests/lib/test_base.gd"
const START := "none"
const TIMEOUT := 180.0
const Data = preload("res://scripts/world_map_2d.gd")

func run() -> void:
	var builder := Data.new()
	builder.begin()
	for id: String in GameData.map_ids():
		if not Data.WC.is_surface(id) or bool(GameData.map_data(id).get("hidden", false)): continue
		builder.add_sector(id)
		log_line("baked " + id)
		await frames(1)
	var mesh := builder.finish()
	check(ResourceSaver.save(mesh, Data.PATH, ResourceSaver.FLAG_COMPRESS) == OK, "二维地图资源保存失败")
	log_line("sectors=%d buildings=%d vertices=%d" % [builder.sectors.size(), mesh.get_meta("building_count"), mesh.surface_get_array_len(0)])
