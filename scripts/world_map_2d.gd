extends RefCounted
## 二维侦察图的离线矢量烘焙：纯 Mesh + 地图元数据，无 3D 场景依赖。
const WC = preload("res://scripts/world_city.gd")
const PATH := "res://assets/ui/worldmap/region_2d.res"
const RECT := Rect2(-300, -610, 1000, 1230)
const SOURCES := ["res://scripts/world_map_2d.gd", "res://scripts/world_city.gd", "res://scripts/maps.gd", "res://scripts/world_gates.gd", "res://data/ext/maps.gd"]
const COLORS := {"D": Color("3b4240"), "R": Color("39433d"), "I": Color("424642"), "H": Color("3b4447"),
	"Y": Color("3d4242"), "M": Color("3b413c"), "P": Color("303f35"), "F": Color("484738"), "W": Color("42433a"),
	"T": Color("2d3a32"), "C": Color("41403a"), "S": Color("403a3e"), "K": Color("4b4a42"), "L": Color("304240"),
	"A": Color("25383f"), "B": Color("555247")}
var tool: SurfaceTool
var sectors := {}
var _color_cache := {}
var _building_count := 0


static func signature() -> Dictionary:
	var result := {}
	for path in SOURCES: result[path] = FileAccess.get_sha256(path)
	return result


func begin() -> void:
	tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 共享顶点颜色在片元间插值，地形分区不会呈现像素格。
	var step := 10
	for y in range(int(RECT.position.y), int(RECT.end.y), step):
		for x in range(int(RECT.position.x), int(RECT.end.x), step):
			var pts := [Vector2(x, y), Vector2(x + step, y), Vector2(x + step, y + step), Vector2(x, y + step)]
			for k in [0, 1, 2, 0, 2, 3]:
				_vertex(pts[k], _ground_color(pts[k]))
	var features := WC.features()
	for river: Dictionary in features.rivers:
		_strip(river.pts, float(river.w) + 3, Color("52605a"))
		_strip(river.pts, float(river.w), Color("565044") if river.dry else Color("283f48"))
	for padding: float in [1.5, 0.0]:
		var lakes: Array[PackedVector2Array] = []
		for lake: Vector3 in features.lakes:
			var poly := WC.lake_poly(lake, 72, padding)
			var changed := true
			while changed:
				changed = false
				for i in lakes.size():
					var merged := Geometry2D.merge_polygons(poly, lakes[i])
					if merged.size() == 1:
						poly = merged[0]
						lakes.remove_at(i)
						changed = true
						break
			lakes.append(poly)
		for poly: PackedVector2Array in lakes:
			for clipped: PackedVector2Array in Geometry2D.intersect_polygons(poly, _rect_poly()):
				_poly(clipped, Color("52605a") if padding > 0 else Color("283f48"))
	var coast := PackedVector2Array()
	for y in range(int(RECT.position.y), int(RECT.end.y) + 1, 10): coast.append(Vector2(WC.coast_x(y), y))
	coast.append(RECT.end)
	coast.append(Vector2(RECT.end.x, RECT.position.y))
	_poly(coast, Color("283f48"))
	for line: PackedVector2Array in features.rails:
		_strip(line, 2.5, Color("292e2b"))
		_strip(line, 0.65, Color("817d6c"))
	for road: Dictionary in features.roads:
		var runs: Array = [road.pts]
		for id: String in GameData.map_ids():
			if not WC.is_surface(id) or bool(GameData.map_data(id).get("hidden", false)): continue
			var out: Array = []
			for run: PackedVector2Array in runs: out.append_array(Geometry2D.clip_polyline_with_polygon(run, WC.zone_poly_world(id)))
			runs = out
		for run: PackedVector2Array in runs: _road(run, float(road.w), bool(road.dirt))


func add_sector(id: String) -> void:
	var layout := WC.zone_layout(id)
	var origin := WC.origin(id)
	var border := WC.zone_poly_world(id)
	var record := {"name": str(GameData.map_data(id).name), "origin": origin, "poly": border,
		"buildings": [], "extracts": [], "pois": [], "gates": [], "landmarks": []}
	for field: Dictionary in layout.fields:
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(WC._shift(field.poly, origin), border):
			_poly(piece, Color("514d3a"))
	for block: Dictionary in layout.blocks:
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(WC._shift(block.poly, origin), border):
			_poly(piece, Color("454d47") if str(block.ch) in ["D", "R"] else Color("464b47"))
	for road: Dictionary in layout.roads:
		for run: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(WC._shift(road.pts, origin), border):
			_road(run, float(road.w), bool(road.dirt))
	for building: Dictionary in layout.bldgs:
		var b: Dictionary = building.duplicate()
		b.c += origin
		record.buildings.append(b)
		var corners := WC.obb_corners(b.c, b.ang, b.sx, b.sz)
		_poly(corners, Color("96978a") if str(b.ch) in ["D", "R"] else Color("858c87"))
		var inset := WC.obb_corners(b.c, b.ang, maxf(0.1, b.sx - 1.5), maxf(0.1, b.sz - 1.5))
		_poly(inset, Color("6b7369") if str(b.ch) in ["D", "R"] else Color("626d69"))
		_building_count += 1
	for poi: Dictionary in layout.pois:
		var p: Vector2 = poi.c + origin
		record.pois.append({"position": p, "name": str(GameData.POIS.get(poi.id, {}).get("name", poi.id)), "id": poi.id})
		_poly(WC.obb_corners(p, 0, 21, 21), Color("645f48"))
		_poly(WC.obb_corners(p, 0, 17, 17), Color("44483e"))
	for ex: Array in GameData.map_data(id).get("extracts", []):
		record.extracts.append({"position": origin + Vector2(ex[1], ex[2]), "name": str(ex[0])})
	for entry: Dictionary in GameData.map_data(id).get("landmarks", []):
		record.landmarks.append({"position": origin + WC.landmark_spot(id, entry), "type": str(entry.type)})
	for edge: String in WC.WorldLink.LINKS.get(id, {}):
		var gate := WC.gate_info(id, edge)
		record.gates.append({"position": origin + gate.pos, "tangent": gate.tangent, "to": WC.WorldLink.LINKS[id][edge]})
	sectors[id] = record


func finish() -> ArrayMesh:
	var mesh := tool.commit()
	mesh.set_meta("sectors", sectors)
	mesh.set_meta("world_rect", RECT)
	mesh.set_meta("sources", signature())
	mesh.set_meta("building_count", _building_count)
	return mesh


func _ground_color(p: Vector2) -> Color:
	if _color_cache.has(p): return _color_cache[p]
	var sum := Color(0, 0, 0, 0)
	for off in [Vector2(-5, -5), Vector2(5, -5), Vector2(5, 5), Vector2(-5, 5)]:
		sum += COLORS.get(WC.district(p + off), COLORS.W) as Color
	var col: Color = sum * 0.25
	_color_cache[p] = col
	return col


func _road(pts: PackedVector2Array, width: float, dirt: bool) -> void:
	_strip(pts, width + 1.5, Color("73786b") if width > 9 else Color("565f55"))
	_strip(pts, width, Color("545346") if dirt else Color("303c3b"))
	if width > 10 and not dirt: _strip(pts, 0.7, Color("a2936a"))


func _strip(pts: PackedVector2Array, width: float, col: Color) -> void:
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		if not RECT.has_point(a) or not RECT.has_point(b): continue
		var va := (b - pts[maxi(0, i - 1)]).normalized()
		var vb := (pts[mini(pts.size() - 1, i + 2)] - a).normalized()
		var sa := Vector2(-va.y, va.x) * width * 0.5
		var sb := Vector2(-vb.y, vb.x) * width * 0.5
		for p in [a - sa, b - sb, b + sb, a - sa, b + sb, a + sa]: _vertex(p, col)


func _poly(pts: PackedVector2Array, col: Color) -> void:
	for idx in Geometry2D.triangulate_polygon(pts): _vertex(pts[idx], col)


func _rect_poly() -> PackedVector2Array:
	return PackedVector2Array([RECT.position, Vector2(RECT.end.x, RECT.position.y), RECT.end, Vector2(RECT.position.x, RECT.end.y)])


func _vertex(p: Vector2, col: Color) -> void:
	tool.set_color(col)
	tool.add_vertex(Vector3(p.x, p.y, 0))
