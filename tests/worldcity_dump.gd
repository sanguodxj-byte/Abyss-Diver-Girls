extends RefCounted
## 城市群布局导出（由 tests/worldmap_export.gd 调用，不单独跑）：
##   tools/worldmap/data/world/world.json        全局要素：范围、格子尺寸、河流、湖、铁路、各战区所在格子、要导出的格子列表
##   tools/worldmap/data/world/tile_<x>_<z>.json 每个 360 米格子的确定性布局（scripts/world_city.gd tile_layout）：
##                                               区块栅格（2 米一格，只取格子本身）、街区、道路、建筑轮廓、街块、田块、公园、湖
## 坐标一律是世界坐标（灰港市中心 = 0, 0），保留两位小数。

const WC = preload("res://scripts/world_city.gd")


static func _r(v: float, d := 0.01) -> float:
	return snappedf(v, d)


static func _pts(p) -> Array:
	var out: Array = []
	for q: Vector2 in p:
		out.append([_r(q.x), _r(q.y)])
	return out


static func _write(path: String, data) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "", false))
	f.close()


static func dump(host: Node) -> void:
	var dir := ProjectSettings.globalize_path("res://tools/worldmap/data/world")
	DirAccess.make_dir_recursive_absolute(dir)
	var f := WC.features()
	var wr: Rect2 = WC.WORLD_RECT
	# 范围内的格子 + 地下战区所在的格子
	var tiles: Array = []
	for tz in range(floori((wr.position.y + WC.HALF) / WC.TILE), floori((wr.end.y - 0.01 + WC.HALF) / WC.TILE) + 1):
		for tx in range(floori((wr.position.x + WC.HALF) / WC.TILE), floori((wr.end.x - 0.01 + WC.HALF) / WC.TILE) + 1):
			tiles.append(Vector2i(tx, tz))
	var zones := {}
	for mid: String in GameData.map_ids():
		var t: Vector2i = WC.tile_of(mid)
		var surface := wr.grow(-1.0).has_point(Vector2(t.x * WC.TILE, t.y * WC.TILE))
		zones[mid] = {"tile": [t.x, t.y], "surface": surface}
		if not (t in tiles):
			tiles.append(t)
	var rivers: Array = []
	for r: Dictionary in f.rivers:
		rivers.append({"name": r.name, "pts": _pts(r.pts), "w": r.w, "dry": r.dry})
	var lakes: Array = []
	for l: Vector3 in f.lakes:
		lakes.append([l.x, l.y, l.z])
	var rails: Array = []
	for r in f.rails:
		rails.append(_pts(r))
	var tl: Array = []
	for t: Vector2i in tiles:
		tl.append([t.x, t.y])
	_write(dir.path_join("world.json"), {"rect": [wr.position.x, wr.position.y, wr.size.x, wr.size.y], "tile": WC.TILE, "half": WC.HALF,
		"rast": WC.RAST, "rivers": rivers, "lakes": lakes, "rails": rails, "zones": zones, "tiles": tl})
	for t: Vector2i in tiles:
		_dump_tile(dir, t)
		await host.get_tree().process_frame


static func _dump_tile(dir: String, t: Vector2i) -> void:
	var L: Dictionary = WC.tile_layout(t)
	var rect: Rect2 = L.rect
	# 栅格：tile_layout 的栅格四周多算了 RAST_PAD，只取格子本身
	var rn: int = L.r_n
	var n := int(WC.TILE / WC.RAST)
	var pad := int(WC.RAST_PAD / WC.RAST)
	var src: PackedByteArray = L.rast
	var rast := PackedByteArray()
	rast.resize(n * n)
	for y in n:
		for x in n:
			rast[y * n + x] = src[(y + pad) * rn + x + pad]
	var nbs: Array = []
	for k: Vector2i in WC._tile_nbs(rect.grow(WC.NB * 1.5)):
		var nb: Dictionary = WC.nb_info(k)
		nbs.append({"poly": _pts(nb.poly), "kind": str(nb.kind), "ch": str(nb.ch), "inner": _pts(WC.nb_inner(nb))})
	var roads: Array = []
	for r: Dictionary in L.roads:
		roads.append({"pts": _pts(r.pts), "w": r.w, "dirt": r.dirt, "kind": r.kind, "bridge": r.bridge})
	var bldgs: Array = []
	for b: Dictionary in L.bldgs:
		bldgs.append({"c": [_r(b.c.x), _r(b.c.y)], "ang": _r(b.ang, 0.0001), "sx": _r(b.sx), "sz": _r(b.sz), "h": _r(b.h), "kind": str(b.kind), "ch": str(b.ch)})
	var blocks: Array = []
	for b: Dictionary in L.blocks:
		blocks.append({"poly": _pts(b.poly), "ch": str(b.ch), "ang": b.get("ang", 0.0)})
	var fields: Array = []
	for fd: Dictionary in L.fields:
		fields.append({"poly": _pts(fd.poly), "ang": fd.ang})
	var parks: Array = []
	for p: Vector2 in L.parks:
		parks.append([_r(p.x), _r(p.y)])
	var lakes: Array = []
	for l: Vector3 in L.lakes:
		lakes.append([l.x, l.y, l.z])
	_write(dir.path_join("tile_%d_%d.json" % [t.x, t.y]), {"nbs": nbs, "tile": [t.x, t.y], "id": L.id, "origin": [rect.position.x, rect.position.y],
		"rast_n": n, "rast_b64": Marshalls.raw_to_base64(rast), "roads": roads, "bldgs": bldgs, "blocks": blocks, "fields": fields,
		"parks": parks, "lakes": lakes})
