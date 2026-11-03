extends Control
## 雷达叠加层：挂在 HUD 雷达（ui.gd 的 UI.Radar）上面，按雷达同样的比例尺补画三类标记，不改动雷达本身。
##   流浪者机甲：橙红色菱形 + 白描边（与虫群的红点区分）
##   战斗队友：青色三角
##   地图边缘转场口：超出雷达范围时贴在圆边上的青色箭头

var raid


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	# 雷达挂在容器里、尺寸由布局决定：锚点预设在加进去的那一刻拿到的是 0 尺寸，每帧对齐父节点
	var par := get_parent() as Control
	if par and (size != par.size or position != Vector2.ZERO):
		position = Vector2.ZERO
		size = par.size
	queue_redraw()


func _draw() -> void:
	if raid == null or not is_instance_valid(raid.mech):
		return
	var radar = get_parent()
	var rng_m: float = float(radar.get("rng_m")) if radar.get("rng_m") != null else 48.0
	var c := size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 2.0
	var mp: Vector3 = raid.mech.global_position
	for n in get_tree().get_nodes_in_group("rovers"):
		var p := Vector2(n.global_position.x - mp.x, n.global_position.z - mp.z) / rng_m * r
		if p.length() < r - 4:
			var q := c + p
			var pts := PackedVector2Array([q + Vector2(0, -5.5), q + Vector2(5.5, 0), q + Vector2(0, 5.5), q + Vector2(-5.5, 0)])
			draw_colored_polygon(pts, Color(1.0, 0.45, 0.1, 0.95))
			pts.append(pts[0])
			draw_polyline(pts, Color(1, 1, 1, 0.9), 1.0)
	for n in get_tree().get_nodes_in_group("allies"):
		var p := Vector2(n.global_position.x - mp.x, n.global_position.z - mp.z) / rng_m * r
		if p.length() < r - 4:
			var q := c + p
			draw_colored_polygon(PackedVector2Array([q + Vector2(0, -5), q + Vector2(4.5, 4), q + Vector2(-4.5, 4)]), Color(0.35, 0.9, 1.0, 0.95))
	if raid.world_link:
		for g in raid.world_link.gate_list():
			var gp: Vector3 = g.center
			var p := Vector2(gp.x - mp.x, gp.z - mp.z) / rng_m * r
			var col := Color(0.35, 0.85, 1.0, 0.95) if g.open else Color(0.6, 0.6, 0.65, 0.6)
			if p.length() > r - 7:
				p = p.normalized() * (r - 7)
			var q := c + p
			var d := p.normalized() if p.length() > 0.1 else Vector2.UP
			var side := Vector2(-d.y, d.x)
			draw_colored_polygon(PackedVector2Array([q + d * 6.0, q - d * 3.0 + side * 4.5, q - d * 3.0 - side * 4.5]), col)
