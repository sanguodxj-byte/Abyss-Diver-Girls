extends RefCounted
## 遗迹 POI 与地标共用的搭建件。全部直接建在 raid.world 下，占地登记进 raid.blocks（后续摆放与撤离点会避让）。
## 墙体一律走 raid._static_box：倒角网格 + 同款做旧混凝土，碰撞体抬到机甲肩部高度，看见挡住就是挡住。
## 容器只调用 raid._place_box（loot_box.gd 自带半埋与靠近描边），这里不额外加光圈或状态灯。

const A = preload("res://scripts/art.gd")

const CONCRETE := Color(0.5, 0.47, 0.43)
const CONCRETE_DARK := Color(0.4, 0.38, 0.35)
const STEEL := Color(0.32, 0.33, 0.32)
const RUST := Color(0.4, 0.28, 0.19)


static func slab(raid, c: Vector3, size: Vector2, col := CONCRETE) -> void:
	A.add(raid.world, A.bevel_box(Vector3(size.x, 0.12, size.y), 0.05), A.concrete(col), c + Vector3(0, 0.07, 0), Vector3.ZERO, Vector3.ONE, false)


## 一段墙，p 是底面中心；rot 为绕 Y 的世界角度。占地矩形按 0/90 两档换算。
static func wall(raid, p: Vector3, size: Vector3, rot := 0.0, col := CONCRETE) -> StaticBody3D:
	var sb: StaticBody3D = raid._static_box(size, p + Vector3(0, size.y * 0.5, 0), col)
	sb.set_meta("poi_built", true)
	sb.rotation_degrees.y = rot
	var fp := size
	if absf(fmod(absf(rot), 180.0) - 90.0) < 45.0:
		fp = Vector3(size.z, size.y, size.x)
	raid.blocks.append(raid._rect_for(p, fp))
	return sb


## 带缺口与断口的墙线：沿局部 X 轴铺 c 为中心的长墙，gaps 里放 [起点, 终点] 局部坐标
static func wall_line(raid, c: Vector3, length: float, hgt: float, rot: float, gaps: Array, col := CONCRETE, seg := 3.8) -> void:
	var n := maxi(1, int(round(length / seg)))
	var step := length / n
	var dir := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(rot))
	for i in n:
		var t := -length * 0.5 + (i + 0.5) * step
		var skip := false
		for g: Array in gaps:
			if t > float(g[0]) and t < float(g[1]):
				skip = true
				break
		if skip:
			continue
		var h = hgt * raid.rng.randf_range(0.7, 1.0)
		if raid.rng.randf() < 0.14:
			h = hgt * 0.32
		var p: Vector3 = c + dir * t
		var sb := wall(raid, p, Vector3(step - 0.06, h, 0.55), rot, col)
		var chunks = 2 if raid.rng.randf() < 0.6 else 1
		for k in chunks:
			var ch = Vector3(raid.rng.randf_range(0.7, 1.8), raid.rng.randf_range(0.25, 0.8), 0.6)
			A.add(sb, A.bevel_box(ch, 0.07), A.concrete(col.darkened(0.16)), Vector3(raid.rng.randf_range(-0.8, 0.8), h * 0.5 + ch.y * 0.4, raid.rng.randf_range(-0.05, 0.05)))


static func pillar(raid, p: Vector3, rad: float, hgt: float, col := CONCRETE) -> void:
	var sb: StaticBody3D = raid._static_box(Vector3(rad * 2.0, hgt, rad * 2.0), p + Vector3(0, hgt * 0.5, 0), col)
	sb.set_meta("poi_built", true)
	A.add(sb, A.cyl(rad * 1.12, 0.22, rad * 1.12, 12), A.concrete(col.darkened(0.2), false), Vector3(0, -hgt * 0.5 + 0.12, 0))
	raid.blocks.append(raid._rect_for(p, Vector3(rad * 2.0, 1, rad * 2.0)))


## 圆柱塔（冷却塔、烟囱、筒仓）：碰撞用圆柱体，射击时按整根塔身遮挡
static func tower(raid, p: Vector3, rad: float, hgt: float, rad_top := -1.0, col := CONCRETE) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = rad
	sh.height = hgt
	cs.shape = sh
	cs.position.y = hgt * 0.5
	sb.add_child(cs)
	raid.world.add_child(sb)
	sb.position = p
	sb.set_meta("poi_built", true)
	var rt := rad if rad_top < 0.0 else rad_top
	A.add(sb, A.cyl(rad, hgt, rt, 26), A.concrete(col, false), Vector3(0, hgt * 0.5, 0))
	for k in 3:
		A.add(sb, A.cyl(lerpf(rad, rt, float(k) / 3.0) + 0.06, 0.14, lerpf(rad, rt, float(k + 1) / 3.0) + 0.06, 26), A.concrete(col.darkened(0.3), false), Vector3(0, hgt * (0.25 + k * 0.25), 0), Vector3.ZERO, Vector3.ONE, false)
	raid.blocks.append(raid._rect_for(p, Vector3(rad * 2.0, 1, rad * 2.0)))


## 格构塔（电塔、中继塔、缆车塔）：四根收分主材 + 每层横撑与交叉斜撑 + 顶部横担
static func lattice(raid, p: Vector3, hgt: float, base: float) -> void:
	var M := A.metal(Color(0.33, 0.33, 0.31))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(base * 0.6, hgt, base * 0.6)
	cs.shape = sh
	cs.position.y = hgt * 0.5
	body.add_child(cs)
	raid.world.add_child(body)
	body.position = p
	body.set_meta("poi_built", true)
	var M2 := A.metal(Color(0.27, 0.27, 0.26))
	var top := base * 0.32
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var a := p + Vector3(sx * base * 0.5, 0, sz * base * 0.5)
			var b := p + Vector3(sx * top * 0.5, hgt, sz * top * 0.5)
			A.add(raid.world, A.tube([a, b], 0.1, 6, 2), M, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	for k in 3:
		var t := float(k) / 3.0
		var t2 := float(k + 1) / 3.0
		var r1 := lerpf(base, top, t) * 0.5
		var r2 := lerpf(base, top, t2) * 0.5
		var y1 := hgt * t
		var y2 := hgt * t2
		for sd in 4:
			var ax := Vector3(-r1, y1, -r1).rotated(Vector3.UP, PI * 0.5 * sd)
			var bx := Vector3(r1, y1, -r1).rotated(Vector3.UP, PI * 0.5 * sd)
			var cx := Vector3(-r2, y2, -r2).rotated(Vector3.UP, PI * 0.5 * sd)
			var dx := Vector3(r2, y2, -r2).rotated(Vector3.UP, PI * 0.5 * sd)
			A.add(raid.world, A.tube([p + ax, p + bx], 0.055, 4, 2), M, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			A.add(raid.world, A.tube([p + ax, p + dx], 0.05, 4, 2), M2, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			A.add(raid.world, A.tube([p + bx, p + cx], 0.05, 4, 2), M2, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(raid.world, A.bevel_box(Vector3(base * 0.9, 0.16, 0.16), 0.02), M, p + Vector3(0, hgt, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(raid.world, A.bevel_box(Vector3(0.16, 0.16, base * 0.9), 0.02), M, p + Vector3(0, hgt, 0), Vector3.ZERO, Vector3.ONE, false)
	raid.blocks.append(raid._rect_for(p, Vector3(base, 1, base)))


static func crate(raid, p: Vector3, kind := "supply", loot: Array = []) -> Node:
	var b = raid._place_box(kind, p, loot)
	return b


## 固定内容的容器：kind 取既有掉落表（决定外观），loot 写死物品 id
static func fixed(raid, p: Vector3, items: Array, kind := "tool") -> Node:
	return raid._place_box(kind, p, items.duplicate())


static func lamp(raid, p: Vector3, c := Color(1.0, 0.78, 0.45)) -> void:
	raid._poi_lamp(p, c)


static func barrel(raid, p: Vector3) -> void:
	raid._fire_barrel(p)


static func guard(raid, c: Vector3, kind := "beetle", radius := 5.0) -> void:
	var a = raid.rng.randf() * TAU
	raid.spawn_bug(kind, c + Vector3(cos(a) * radius, 0.5, sin(a) * radius))


static func label(raid, c: Vector3, text: String, hgt := 7.0) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 64
	lbl.pixel_size = 0.02
	lbl.modulate = Color(1.0, 0.85, 0.6)
	lbl.outline_size = 10
	lbl.outline_modulate = Color(0.05, 0.03, 0.02, 0.9)
	lbl.position = c + Vector3(0, hgt, 0)
	raid.world.add_child(lbl)


static func rubble(raid, p: Vector3, s: float, col := CONCRETE_DARK) -> void:
	var M := A.concrete(col, false)
	for i in 5:
		var a = raid.rng.randf() * TAU
		var d = raid.rng.randf_range(0.2, 1.0) * s
		var q = raid.rng.randf_range(0.3, 1.0) * s
		A.add(raid.world, A.bevel_box(Vector3(q, q * 0.5, q * 0.8), 0.06), M,
			p + Vector3(cos(a) * d, q * 0.22, sin(a) * d), Vector3(raid.rng.randf() * 30, raid.rng.randf() * 360, raid.rng.randf() * 30))


static func car(raid, p: Vector3, rot := 0.0) -> void:
	raid._wreck_car(p)
	raid.blocks.append(raid._rect_for(p, Vector3(3.0, 1, 3.0)))
	if rot != 0.0:
		pass


## 两点之间下垂的线缆（吊桥主索、电塔导线、龙门吊钢索）
static func cable(raid, a: Vector3, b: Vector3, sag: float, r := 0.05, col := STEEL) -> MeshInstance3D:
	var mid := (a + b) * 0.5 + Vector3(0, -sag, 0)
	var pts := [a, a.lerp(mid, 0.6) + Vector3(0, -sag * 0.25, 0), mid, b.lerp(mid, 0.6) + Vector3(0, -sag * 0.25, 0), b]
	var mi := A.add(raid.world, A.tube(pts, r, 5, 5), A.metal(col), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	return mi


static func pipe(raid, a: Vector3, b: Vector3, r := 0.22, col := RUST) -> MeshInstance3D:
	var mi := A.add(raid.world, A.tube([a, b], r, 8, 3), A.paint(col, 0.55, 0.6, {"wear": 0.5, "rust": 0.8, "panel_scale": 0.0}), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	return mi


## 桌面 + 抽屉：办公室、控制台、售票处的底子
static func desk(raid, p: Vector3, rot: float, w := 2.4, col := RUST) -> void:
	var M := A.paint(col, 0.2, 0.7, {"wear": 0.6, "rust": 0.5, "dust": 0.5, "panel_scale": 0.0})
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	A.add(n, A.bevel_box(Vector3(w, 0.1, 1.0), 0.02), M, Vector3(0, 0.86, 0))
	for sx in [-1.0, 1.0]:
		A.add(n, A.bevel_box(Vector3(0.12, 0.84, 0.9), 0.02), A.metal(STEEL), Vector3(sx * (w * 0.5 - 0.12), 0.42, 0))
	A.add(n, A.bevel_box(Vector3(w * 0.6, 0.5, 0.06), 0.01), A.paint(col.darkened(0.2), 0.3, 0.8), Vector3(0, 0.5, -0.45))
	raid.blocks.append(raid._rect_for(p, Vector3(w, 1, 1.2)))


static func shelf(raid, p: Vector3, rot: float, hgt := 2.2, w := 2.0) -> void:
	var M := A.paint(STEEL, 0.6, 0.6, {"wear": 0.5, "rust": 0.7, "panel_scale": 0.0})
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			A.add(n, A.bevel_box(Vector3(0.07, hgt, 0.07), 0.01), M, Vector3(sx * w * 0.5, hgt * 0.5, sz * 0.28))
	for k in 3:
		A.add(n, A.bevel_box(Vector3(w, 0.05, 0.62), 0.01), M, Vector3(0, 0.45 + k * 0.68, 0))
	raid.blocks.append(raid._rect_for(p, Vector3(w, 1, 0.9)))


static func bench(raid, p: Vector3, rot: float, w := 1.8) -> void:
	var M := A.paint(Color(0.32, 0.25, 0.18), 0.0, 0.85, {"wear": 0.7, "dust": 0.6, "rust": 0.4, "panel_scale": 0.0})
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	A.add(n, A.bevel_box(Vector3(w, 0.09, 0.5), 0.02), M, Vector3(0, 0.42, 0))
	A.add(n, A.bevel_box(Vector3(w, 0.5, 0.07), 0.02), M, Vector3(0, 0.68, -0.24), Vector3(-8, 0, 0))
	for sx in [-1.0, 1.0]:
		A.add(n, A.bevel_box(Vector3(0.07, 0.42, 0.44), 0.01), A.metal(STEEL), Vector3(sx * w * 0.42, 0.21, 0))


static func sign(raid, p: Vector3, rot: float, text: String, w := 3.0, hgt := 1.0) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	A.add(n, A.bevel_box(Vector3(w, hgt, 0.1), 0.02), A.paint(Color(0.12, 0.13, 0.12), 0.2, 0.7, {"wear": 0.5, "rust": 0.5, "dust": 0.5, "panel_scale": 0.0}), Vector3(0, 0, 0))
	for sx in [-1.0, 1.0]:
		A.add(n, A.cyl(0.06, 2.4, 0.06, 6), A.metal(STEEL), Vector3(sx * w * 0.36, -1.25, 0))
	A.stencil(n, text, Vector3(0, 0.02, -0.07), Vector3(0, 180, 0), 0.008, Color(0.88, 0.86, 0.78, 0.75), 48)


static func railing(raid, c: Vector3, length: float, rot: float, hgt := 1.1) -> void:
	var M := A.paint(Color(0.3, 0.31, 0.3), 0.6, 0.6, {"wear": 0.5, "rust": 0.6, "panel_scale": 0.0})
	var dir := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(rot))
	var n := maxi(2, int(length / 2.0))
	for i in n + 1:
		var t := -length * 0.5 + length * float(i) / n
		A.add(raid.world, A.cyl(0.05, hgt, 0.05, 6), M, c + dir * t + Vector3(0, hgt * 0.5, 0), Vector3.ZERO, Vector3.ONE, false)
	var bar := Node3D.new()
	raid.world.add_child(bar)
	bar.position = c + Vector3(0, hgt, 0)
	bar.rotation_degrees.y = rot
	A.add(bar, A.bevel_box(Vector3(length, 0.07, 0.07), 0.01), M, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(bar, A.bevel_box(Vector3(length, 0.05, 0.05), 0.01), M, Vector3(0, -hgt * 0.55, 0), Vector3.ZERO, Vector3.ONE, false)


## 平屋顶上的杂物：女儿墙、空调机组、通风口、检修口与短天线。
## 俯视角下屋顶占画面最大，纯平板会让建筑失去体量，这里补的件都不带碰撞。
static func roof_kit(raid, c: Vector3, size: Vector2, top: float, col := CONCRETE) -> void:
	var M := A.concrete(col.darkened(0.18), false)
	var r = raid.rng
	for seg in [[Vector3(0, top + 0.32, -size.y * 0.5), Vector3(size.x, 0.64, 0.36)], [Vector3(0, top + 0.32, size.y * 0.5), Vector3(size.x, 0.64, 0.36)],
			[Vector3(-size.x * 0.5, top + 0.32, 0), Vector3(0.36, 0.64, size.y)], [Vector3(size.x * 0.5, top + 0.32, 0), Vector3(0.36, 0.64, size.y)]]:
		A.add(raid.world, A.bevel_box(seg[1], 0.03), M, c + seg[0])
	# 空调机组：外壳 + 顶上的风扇盘
	for i in 3:
		var p := c + Vector3(r.randf_range(-size.x * 0.28, size.x * 0.28), top + 0.55, r.randf_range(-size.y * 0.26, size.y * 0.26))
		A.add(raid.world, A.bevel_box(Vector3(1.5, 1.0, 1.1), 0.06), A.paint(Color(0.48, 0.49, 0.46), 0.45, 0.6, {"wear": 0.5, "rust": 0.6, "dust": 0.4, "panel_scale": 0.8}), p)
		A.add(raid.world, A.cyl(0.42, 0.06, 0.42, 14), A.metal(Color(0.22, 0.22, 0.21)), p + Vector3(0, 0.54, 0), Vector3.ZERO, Vector3.ONE, false)
	# 通风管与检修口
	A.add(raid.world, A.cyl(0.3, 1.2, 0.3, 10), A.metal(Color(0.32, 0.31, 0.29)), c + Vector3(size.x * 0.3, top + 0.7, size.y * 0.28))
	A.add(raid.world, A.bevel_box(Vector3(1.1, 0.16, 1.1), 0.02), A.paint(Color(0.36, 0.36, 0.34), 0.5, 0.6, {"rust": 0.7}), c + Vector3(-size.x * 0.32, top + 0.12, size.y * 0.3))
	A.add(raid.world, A.cyl(0.05, 2.4, 0.03, 5), A.metal(Color(0.4, 0.4, 0.38)), c + Vector3(size.x * 0.38, top + 1.2, -size.y * 0.34))


## 台阶：沿局部 +Z 上行，p 为最下一级前缘中心
static func steps(raid, p: Vector3, n: int, rise: float, run: float, width: float, rot: float) -> void:
	var n3 := Node3D.new()
	raid.world.add_child(n3)
	n3.position = p
	n3.rotation_degrees.y = rot
	for i in n:
		A.add(n3, A.bevel_box(Vector3(width, rise, run), 0.02), A.concrete(CONCRETE, false), Vector3(0, rise * (i + 0.5), run * (i + 0.5)))


## 遮阳棚 / 碎顶：四根立柱 + 一块薄板，不挡子弹（板在 3 米以上，没有碰撞体）
static func canopy(raid, p: Vector3, size: Vector2, hgt := 3.2, rot := 0.0, col := CONCRETE_DARK) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	A.add(n, A.bevel_box(Vector3(size.x, 0.22, size.y), 0.04), A.concrete(col, false), Vector3(0, hgt, 0), Vector3.ZERO, Vector3.ONE, false)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			A.add(n, A.cyl(0.09, hgt, 0.09, 8), A.metal(STEEL), Vector3(sx * size.x * 0.42, hgt * 0.5, sz * size.y * 0.42))

## 把本次遗迹摆下的容器登记归属（meta "poi"），供行动结束、掉落与可达性检查区分哪些容器属于这处遗迹。
static func tag_boxes(raid, c: Vector3, pid: String, rad := 15.0) -> void:
	for b in raid.get_tree().get_nodes_in_group("lootboxes"):
		if b.has_meta("poi") or not is_instance_valid(b):
			continue
		if b.global_position.distance_to(c) < rad:
			b.set_meta("poi", pid)

## 只建碰撞、不建网格的挡弹件：地标已经用网格拼好外形，这里补上实体，
## 让「看起来是墙/塔/罐」的东西真的挡住子弹与机甲。rot 只影响方形件的朝向。
static func blocker(raid, p: Vector3, size: Vector3, rot := 0.0, cyl := false) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	if cyl:
		var csh := CylinderShape3D.new()
		csh.radius = size.x * 0.5
		csh.height = size.y
		cs.shape = csh
	else:
		var bsh := BoxShape3D.new()
		bsh.size = size
		cs.shape = bsh
	cs.position.y = size.y * 0.5
	sb.add_child(cs)
	raid.world.add_child(sb)
	sb.position = p
	sb.rotation_degrees.y = rot
	sb.set_meta("poi_built", true)
